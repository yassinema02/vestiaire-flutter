-- Migration 019: Badge Achievement System
-- Creates badges catalog table, user_badges junction table,
-- seeds 15 badge definitions, and the evaluate_badges RPC.

-- ============================================================
-- 1. badges table (public catalog of badge definitions)
-- ============================================================
CREATE TABLE app_public.badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_name TEXT NOT NULL,
  icon_color TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('streak', 'wardrobe', 'sustainability', 'social', 'special')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: all authenticated users can read badge definitions (public catalog)
ALTER TABLE app_public.badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY badges_select_all_authenticated
  ON app_public.badges
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================
-- 2. user_badges table (junction: user <-> earned badges)
-- ============================================================
CREATE TABLE app_public.user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  badge_id UUID NOT NULL REFERENCES app_public.badges(id) ON DELETE CASCADE,
  awarded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(profile_id, badge_id)
);

-- RLS: users can read only their own badges
ALTER TABLE app_public.user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_badges_select_own
  ON app_public.user_badges
  FOR SELECT
  TO authenticated
  USING (
    profile_id = (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id')
    )
  );

-- Index for efficient lookups by profile
CREATE INDEX idx_user_badges_profile ON app_public.user_badges(profile_id);

-- ============================================================
-- 3. Seed 15 badge definitions
-- ============================================================
INSERT INTO app_public.badges (key, name, description, icon_name, icon_color, category, sort_order) VALUES
  ('first_step',        'First Step',         'Upload your first wardrobe item',                    'star',                  '#FBBF24', 'wardrobe',       1),
  ('closet_complete',   'Closet Complete',     'Reach 50 items in your wardrobe',                   'checkroom',             '#2563EB', 'wardrobe',       2),
  ('week_warrior',      'Week Warrior',        'Maintain a 7-day outfit logging streak',            'local_fire_department', '#F97316', 'streak',         3),
  ('streak_legend',     'Streak Legend',        'Maintain a 30-day outfit logging streak',           'local_fire_department', '#EF4444', 'streak',         4),
  ('early_bird',        'Early Bird',           'Log an outfit before 8 AM',                         'wb_sunny',              '#FBBF24', 'special',        5),
  ('rewear_champion',   'Rewear Champion',      'Achieve 50 total re-wears across all items',        'recycling',             '#10B981', 'sustainability', 6),
  ('circular_seller',   'Circular Seller',      'List 1 or more items for resale',                   'sell',                  '#8B5CF6', 'sustainability', 7),
  ('circular_champion', 'Circular Champion',    'Sell 10 or more items',                             'sell',                  '#8B5CF6', 'sustainability', 8),
  ('generous_giver',    'Generous Giver',       'Donate 20 or more items',                           'volunteer_activism',    '#EC4899', 'sustainability', 9),
  ('monochrome_master', 'Monochrome Master',    'Log 5 single-color outfits',                        'palette',               '#6B7280', 'special',       10),
  ('rainbow_warrior',   'Rainbow Warrior',      'Own items in 7 or more colors',                     'palette',               '#EF4444', 'wardrobe',      11),
  ('og_member',         'OG Member',            'Be a member for 365 days or more',                  'verified',              '#2563EB', 'special',       12),
  ('weather_warrior',   'Weather Warrior',      'Log outfits in all 4 season types',                 'thunderstorm',          '#0EA5E9', 'special',       13),
  ('style_guru',        'Style Guru',           'Reach level 5 "Style Expert"',                      'school',                '#8B5CF6', 'wardrobe',      14),
  ('eco_warrior',       'Eco Warrior',          'Achieve a sustainability score of 80 or higher',    'eco',                   '#10B981', 'sustainability',15);

-- ============================================================
-- 4. evaluate_badges RPC
-- ============================================================
CREATE OR REPLACE FUNCTION app_public.evaluate_badges(p_profile_id UUID)
RETURNS TABLE(badge_key TEXT, badge_name TEXT, badge_description TEXT, badge_icon_name TEXT, badge_icon_color TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_badge_id UUID;
  v_earned BOOLEAN;
BEGIN
  -- Iterate over each badge definition
  FOR v_badge_id, badge_key, badge_name, badge_description, badge_icon_name, badge_icon_color IN
    SELECT b.id, b.key, b.name, b.description, b.icon_name, b.icon_color
    FROM app_public.badges b
    ORDER BY b.sort_order
  LOOP
    v_earned := FALSE;

    -- Check each badge criterion
    CASE badge_key
      WHEN 'first_step' THEN
        SELECT COUNT(*) >= 1 INTO v_earned
        FROM app_public.items WHERE profile_id = p_profile_id;

      WHEN 'closet_complete' THEN
        SELECT COUNT(*) >= 50 INTO v_earned
        FROM app_public.items WHERE profile_id = p_profile_id;

      WHEN 'week_warrior' THEN
        SELECT COALESCE(current_streak >= 7 OR longest_streak >= 7, FALSE) INTO v_earned
        FROM app_public.user_stats WHERE profile_id = p_profile_id;

      WHEN 'streak_legend' THEN
        SELECT COALESCE(current_streak >= 30 OR longest_streak >= 30, FALSE) INTO v_earned
        FROM app_public.user_stats WHERE profile_id = p_profile_id;

      WHEN 'early_bird' THEN
        SELECT COUNT(*) >= 1 INTO v_earned
        FROM app_public.wear_logs
        WHERE profile_id = p_profile_id AND EXTRACT(HOUR FROM created_at) < 8;

      WHEN 'rewear_champion' THEN
        SELECT COALESCE(SUM(wear_count), 0) >= 50 INTO v_earned
        FROM app_public.items
        WHERE profile_id = p_profile_id AND wear_count > 1;

      WHEN 'monochrome_master' THEN
        SELECT COUNT(*) >= 5 INTO v_earned
        FROM app_public.outfits o
        WHERE o.profile_id = p_profile_id
          AND (
            SELECT COUNT(DISTINCT i.color)
            FROM app_public.outfit_items oi
            JOIN app_public.items i ON i.id = oi.item_id
            WHERE oi.outfit_id = o.id
          ) = 1;

      WHEN 'rainbow_warrior' THEN
        SELECT COUNT(DISTINCT color) >= 7 INTO v_earned
        FROM app_public.items WHERE profile_id = p_profile_id;

      WHEN 'og_member' THEN
        SELECT created_at <= NOW() - INTERVAL '365 days' INTO v_earned
        FROM app_public.profiles WHERE id = p_profile_id;

      WHEN 'style_guru' THEN
        SELECT COALESCE(current_level >= 5, FALSE) INTO v_earned
        FROM app_public.user_stats WHERE profile_id = p_profile_id;

      -- TODO: Enable when Epic 7/11/13 tables exist
      WHEN 'circular_seller' THEN
        v_earned := FALSE;

      WHEN 'circular_champion' THEN
        v_earned := FALSE;

      WHEN 'generous_giver' THEN
        v_earned := FALSE;

      WHEN 'weather_warrior' THEN
        v_earned := FALSE;

      WHEN 'eco_warrior' THEN
        v_earned := FALSE;

      ELSE
        v_earned := FALSE;
    END CASE;

    -- If criterion met, try to insert (idempotent via ON CONFLICT DO NOTHING)
    IF v_earned THEN
      INSERT INTO app_public.user_badges (profile_id, badge_id)
      VALUES (p_profile_id, v_badge_id)
      ON CONFLICT (profile_id, badge_id) DO NOTHING;

      -- Only return if it was newly inserted (not already existing)
      IF FOUND THEN
        RETURN NEXT;
      END IF;
    END IF;
  END LOOP;

  RETURN;
END;
$$;
