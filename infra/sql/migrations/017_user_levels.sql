-- Migration 017: Add level columns to user_stats and create recalculate_user_level RPC
-- Epic 6: Gamification & Engagement
-- Story 6.2: User Progression Levels
--
-- Extends the user_stats table with level tracking columns and creates
-- the recalculate_user_level RPC for atomic level recalculation.

-- 1. Add level columns to user_stats
ALTER TABLE app_public.user_stats ADD COLUMN current_level INTEGER NOT NULL DEFAULT 1;
ALTER TABLE app_public.user_stats ADD COLUMN current_level_name TEXT NOT NULL DEFAULT 'Closet Rookie';

-- 2. RPC function: recalculate_user_level
-- Counts items, determines level from thresholds, upserts user_stats, returns old/new level.
-- Levels only go UP, never down (no downgrade).
CREATE OR REPLACE FUNCTION app_public.recalculate_user_level(p_profile_id UUID)
RETURNS TABLE(
  current_level INTEGER,
  current_level_name TEXT,
  previous_level INTEGER,
  previous_level_name TEXT,
  leveled_up BOOLEAN,
  item_count INTEGER,
  next_level_threshold INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_item_count INTEGER;
  v_new_level INTEGER;
  v_new_level_name TEXT;
  v_previous_level INTEGER;
  v_previous_level_name TEXT;
  v_next_threshold INTEGER;
BEGIN
  -- Count items for this profile
  SELECT COUNT(*)::INTEGER INTO v_item_count
  FROM app_public.items
  WHERE profile_id = p_profile_id;

  -- Determine level from thresholds
  IF v_item_count >= 200 THEN
    v_new_level := 6;
    v_new_level_name := 'Style Master';
    v_next_threshold := NULL;
  ELSIF v_item_count >= 100 THEN
    v_new_level := 5;
    v_new_level_name := 'Style Expert';
    v_next_threshold := 200;
  ELSIF v_item_count >= 50 THEN
    v_new_level := 4;
    v_new_level_name := 'Wardrobe Pro';
    v_next_threshold := 100;
  ELSIF v_item_count >= 25 THEN
    v_new_level := 3;
    v_new_level_name := 'Fashion Explorer';
    v_next_threshold := 50;
  ELSIF v_item_count >= 10 THEN
    v_new_level := 2;
    v_new_level_name := 'Style Starter';
    v_next_threshold := 25;
  ELSE
    v_new_level := 1;
    v_new_level_name := 'Closet Rookie';
    v_next_threshold := 10;
  END IF;

  -- Read current stored level (if exists)
  SELECT us.current_level, us.current_level_name
  INTO v_previous_level, v_previous_level_name
  FROM app_public.user_stats us
  WHERE us.profile_id = p_profile_id;

  -- Default previous level if no row exists
  IF v_previous_level IS NULL THEN
    v_previous_level := 1;
    v_previous_level_name := 'Closet Rookie';
  END IF;

  -- No downgrade: keep current level if calculated level is lower
  IF v_new_level < v_previous_level THEN
    v_new_level := v_previous_level;
    v_new_level_name := v_previous_level_name;
    -- Recalculate next_threshold for the kept level
    IF v_new_level = 1 THEN v_next_threshold := 10;
    ELSIF v_new_level = 2 THEN v_next_threshold := 25;
    ELSIF v_new_level = 3 THEN v_next_threshold := 50;
    ELSIF v_new_level = 4 THEN v_next_threshold := 100;
    ELSIF v_new_level = 5 THEN v_next_threshold := 200;
    ELSE v_next_threshold := NULL;
    END IF;
  END IF;

  -- Upsert user_stats with level data
  INSERT INTO app_public.user_stats (profile_id, current_level, current_level_name)
  VALUES (p_profile_id, v_new_level, v_new_level_name)
  ON CONFLICT (profile_id)
  DO UPDATE SET
    current_level = v_new_level,
    current_level_name = v_new_level_name,
    updated_at = now();

  -- Return results
  current_level := v_new_level;
  current_level_name := v_new_level_name;
  previous_level := v_previous_level;
  previous_level_name := v_previous_level_name;
  leveled_up := v_new_level > v_previous_level;
  item_count := v_item_count;
  next_level_threshold := v_next_threshold;
  RETURN NEXT;
END;
$$;
