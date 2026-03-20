-- Migration 018: Streak management RPC functions
-- Epic 6: Gamification & Engagement
-- Story 6.3: Streak Tracking & Freezes
--
-- Creates the evaluate_streak RPC function for atomic streak evaluation
-- and the is_streak_freeze_available helper function.
--
-- NOTE: No new columns are added to user_stats. The streak columns
-- (current_streak, longest_streak, last_streak_date, streak_freeze_used_at)
-- were all created in migration 016 (Story 6.1).
--
-- WEEK BOUNDARY: PostgreSQL's date_trunc('week', date) returns Monday 00:00:00
-- of the week containing the given date, per ISO 8601 convention.
-- This means the streak freeze resets every Monday at midnight.
-- This is locale-independent in PostgreSQL as date_trunc('week', ...) always
-- uses ISO 8601 Monday-based weeks.

-- 1. Helper function: is_streak_freeze_available
-- Determines if the weekly freeze is available based on streak_freeze_used_at
-- and the current Monday-Sunday week boundary.
CREATE OR REPLACE FUNCTION app_public.is_streak_freeze_available(
  p_freeze_used_at DATE,
  p_reference_date DATE
)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT p_freeze_used_at IS NULL OR p_freeze_used_at < date_trunc('week', p_reference_date)::DATE;
$$;

-- 2. RPC function: evaluate_streak
-- Atomically evaluates and updates streak state for a user.
-- Handles: continuation, freeze application, reset, idempotency, first-ever log.
CREATE OR REPLACE FUNCTION app_public.evaluate_streak(
  p_profile_id UUID,
  p_logged_date DATE
)
RETURNS TABLE(
  current_streak INTEGER,
  longest_streak INTEGER,
  last_streak_date DATE,
  streak_freeze_used_at DATE,
  streak_extended BOOLEAN,
  is_new_streak BOOLEAN,
  freeze_used BOOLEAN,
  streak_freeze_available BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_current_streak INTEGER;
  v_longest_streak INTEGER;
  v_last_streak_date DATE;
  v_freeze_used_at DATE;
  v_streak_extended BOOLEAN := FALSE;
  v_is_new_streak BOOLEAN := FALSE;
  v_freeze_used BOOLEAN := FALSE;
  v_freeze_available BOOLEAN;
  v_row_exists BOOLEAN;
BEGIN
  -- Upsert user_stats row if not exists
  INSERT INTO app_public.user_stats (profile_id, total_points, current_streak, longest_streak)
  VALUES (p_profile_id, 0, 0, 0)
  ON CONFLICT (profile_id) DO NOTHING;

  -- Read current state (with row lock for atomicity)
  SELECT us.current_streak, us.longest_streak, us.last_streak_date, us.streak_freeze_used_at
  INTO v_current_streak, v_longest_streak, v_last_streak_date, v_freeze_used_at
  FROM app_public.user_stats us
  WHERE us.profile_id = p_profile_id
  FOR UPDATE;

  -- Calculate freeze availability
  v_freeze_available := app_public.is_streak_freeze_available(v_freeze_used_at, p_logged_date);

  -- Case (a): Already logged today -- idempotent, no change
  IF v_last_streak_date = p_logged_date THEN
    current_streak := v_current_streak;
    longest_streak := v_longest_streak;
    last_streak_date := v_last_streak_date;
    streak_freeze_used_at := v_freeze_used_at;
    streak_extended := FALSE;
    is_new_streak := FALSE;
    freeze_used := FALSE;
    streak_freeze_available := v_freeze_available;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Case (b): Streak continues (last_streak_date = yesterday)
  IF v_last_streak_date = p_logged_date - 1 THEN
    v_current_streak := v_current_streak + 1;
    v_longest_streak := GREATEST(v_longest_streak, v_current_streak);
    v_last_streak_date := p_logged_date;
    v_streak_extended := TRUE;
    v_is_new_streak := FALSE;

  -- Case (c): Missed exactly 1 day (last_streak_date = 2 days ago) AND freeze available
  ELSIF v_last_streak_date = p_logged_date - 2 AND v_freeze_available THEN
    -- Consume freeze for the missed day
    v_freeze_used_at := p_logged_date - 1;  -- the missed day
    v_freeze_available := FALSE;
    v_freeze_used := TRUE;

    -- Advance last_streak_date through the missed day, then continue streak
    v_current_streak := v_current_streak + 1;
    v_longest_streak := GREATEST(v_longest_streak, v_current_streak);
    v_last_streak_date := p_logged_date;
    v_streak_extended := TRUE;
    v_is_new_streak := FALSE;

  -- Case (d): Streak is broken (gap > 1 day, or gap = 1 day with no freeze)
  ELSE
    v_current_streak := 1;
    v_last_streak_date := p_logged_date;
    v_is_new_streak := TRUE;
    v_streak_extended := FALSE;
  END IF;

  -- Update user_stats
  UPDATE app_public.user_stats
  SET
    current_streak = v_current_streak,
    longest_streak = v_longest_streak,
    last_streak_date = v_last_streak_date,
    streak_freeze_used_at = v_freeze_used_at,
    updated_at = now()
  WHERE app_public.user_stats.profile_id = p_profile_id;

  -- Recalculate freeze availability after potential update
  v_freeze_available := app_public.is_streak_freeze_available(v_freeze_used_at, p_logged_date);

  -- Return results
  current_streak := v_current_streak;
  longest_streak := v_longest_streak;
  last_streak_date := v_last_streak_date;
  streak_freeze_used_at := v_freeze_used_at;
  streak_extended := v_streak_extended;
  is_new_streak := v_is_new_streak;
  freeze_used := v_freeze_used;
  streak_freeze_available := v_freeze_available;
  RETURN NEXT;
END;
$$;
