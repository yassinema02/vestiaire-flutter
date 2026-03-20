-- Migration 016: Create user_stats table and gamification RPC functions
-- Epic 6: Gamification & Engagement
-- Story 6.1: Style Points Rewards
--
-- Creates the user_stats table for tracking gamification state (points, streaks),
-- RLS policies for data isolation, and RPC functions for atomic point awards.

-- 1. user_stats table
CREATE TABLE IF NOT EXISTS app_public.user_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL UNIQUE REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  total_points INTEGER NOT NULL DEFAULT 0,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  last_streak_date DATE,
  streak_freeze_used_at DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for efficient profile lookups
CREATE INDEX idx_user_stats_profile ON app_public.user_stats(profile_id);

-- 2. RLS policy
ALTER TABLE app_public.user_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_stats_isolation ON app_public.user_stats
  FOR ALL
  USING (profile_id IN (
    SELECT id FROM app_public.profiles
    WHERE firebase_uid = current_setting('app.current_user_id', true)
  ));

-- 3. RPC function: award_style_points (simple atomic point award with upsert)
CREATE OR REPLACE FUNCTION app_public.award_style_points(p_profile_id UUID, p_points INTEGER)
RETURNS TABLE(total_points INTEGER)
LANGUAGE sql
AS $$
  INSERT INTO app_public.user_stats (profile_id, total_points)
  VALUES (p_profile_id, p_points)
  ON CONFLICT (profile_id)
  DO UPDATE SET
    total_points = app_public.user_stats.total_points + EXCLUDED.total_points,
    updated_at = now()
  RETURNING app_public.user_stats.total_points;
$$;

-- 4. RPC function: award_points_with_streak (point award with streak tracking)
CREATE OR REPLACE FUNCTION app_public.award_points_with_streak(
  p_profile_id UUID,
  p_base_points INTEGER,
  p_is_first_log_today BOOLEAN,
  p_is_streak_day BOOLEAN
)
RETURNS TABLE(total_points INTEGER, points_awarded INTEGER, current_streak INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
  v_bonus_points INTEGER := 0;
  v_total_award INTEGER;
  v_total_points INTEGER;
  v_current_streak INTEGER;
BEGIN
  -- Calculate bonus points
  IF p_is_first_log_today THEN
    v_bonus_points := v_bonus_points + 2;
  END IF;
  IF p_is_streak_day THEN
    v_bonus_points := v_bonus_points + 3;
  END IF;

  v_total_award := p_base_points + v_bonus_points;

  -- Upsert user_stats with points and optional streak update
  INSERT INTO app_public.user_stats (profile_id, total_points, current_streak, longest_streak, last_streak_date)
  VALUES (
    p_profile_id,
    v_total_award,
    CASE WHEN p_is_streak_day THEN 2 ELSE 1 END,
    CASE WHEN p_is_streak_day THEN 2 ELSE 1 END,
    CASE WHEN p_is_streak_day THEN CURRENT_DATE ELSE NULL END
  )
  ON CONFLICT (profile_id)
  DO UPDATE SET
    total_points = app_public.user_stats.total_points + v_total_award,
    current_streak = CASE
      WHEN p_is_streak_day THEN app_public.user_stats.current_streak + 1
      ELSE app_public.user_stats.current_streak
    END,
    longest_streak = CASE
      WHEN p_is_streak_day THEN GREATEST(app_public.user_stats.longest_streak, app_public.user_stats.current_streak + 1)
      ELSE app_public.user_stats.longest_streak
    END,
    last_streak_date = CASE
      WHEN p_is_streak_day THEN CURRENT_DATE
      ELSE app_public.user_stats.last_streak_date
    END,
    updated_at = now()
  RETURNING
    app_public.user_stats.total_points,
    v_total_award,
    app_public.user_stats.current_streak
  INTO v_total_points, v_total_award, v_current_streak;

  total_points := v_total_points;
  points_awarded := v_total_award;
  current_streak := v_current_streak;
  RETURN NEXT;
END;
$$;
