-- Migration 023: Resale history table and badge eligibility updates. Story 7.4: Resale Status & History Tracking. FR-RSL-04, FR-RSL-07, FR-RSL-08, FR-RSL-09, FR-RSL-10

-- ============================================================
-- 1. resale_history table
-- ============================================================
CREATE TABLE app_public.resale_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE,
  resale_listing_id UUID REFERENCES app_public.resale_listings(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('sold', 'donated')),
  sale_price NUMERIC(10,2) DEFAULT 0,
  sale_currency TEXT DEFAULT 'GBP',
  sale_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE app_public.resale_history ENABLE ROW LEVEL SECURITY;

-- RLS policy: users can only access their own resale history
CREATE POLICY resale_history_user_policy ON app_public.resale_history
  FOR ALL
  USING (profile_id IN (
    SELECT id FROM app_public.profiles
    WHERE firebase_uid = current_setting('app.current_user_id', true)
  ));

-- Indexes
CREATE INDEX idx_resale_history_profile ON app_public.resale_history(profile_id, created_at DESC);
CREATE INDEX idx_resale_history_item ON app_public.resale_history(item_id);

-- ============================================================
-- 2. Update check_badge_eligibility (evaluate_badges) function
--    Replace placeholder logic for circular_seller and circular_champion
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

      WHEN 'circular_seller' THEN
        SELECT COUNT(*) >= 1 INTO v_earned
        FROM app_public.items WHERE profile_id = p_profile_id AND resale_status IS NOT NULL;

      WHEN 'circular_champion' THEN
        SELECT COUNT(*) >= 10 INTO v_earned
        FROM app_public.items WHERE profile_id = p_profile_id AND resale_status = 'sold';

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
