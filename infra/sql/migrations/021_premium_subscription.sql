-- Migration 021: Premium Subscription (RevenueCat integration)
-- Adds premium_source and premium_expires_at columns to profiles,
-- creates sync_premium_from_revenuecat RPC, and updates check_trial_expiry RPC.

-- ============================================================
-- 1. Add premium_source column to profiles
-- ============================================================
ALTER TABLE app_public.profiles
  ADD COLUMN premium_source TEXT CHECK (premium_source IN ('trial', 'revenuecat'));

-- ============================================================
-- 2. Add premium_expires_at column to profiles
-- ============================================================
ALTER TABLE app_public.profiles
  ADD COLUMN premium_expires_at TIMESTAMPTZ;

-- ============================================================
-- 3. Back-fill existing premium trial users
-- ============================================================
UPDATE app_public.profiles
SET premium_source = 'trial'
WHERE is_premium = true AND premium_trial_expires_at IS NOT NULL;

-- ============================================================
-- 4. Index for premium_source lookups
-- ============================================================
CREATE INDEX idx_profiles_premium_source
  ON app_public.profiles(premium_source)
  WHERE premium_source IS NOT NULL;

-- ============================================================
-- 5. sync_premium_from_revenuecat RPC
-- ============================================================
CREATE OR REPLACE FUNCTION app_public.sync_premium_from_revenuecat(
  p_firebase_uid TEXT,
  p_is_premium BOOLEAN,
  p_expires_at TIMESTAMPTZ
)
RETURNS TABLE(is_premium BOOLEAN, premium_source TEXT, premium_expires_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_profile_id UUID;
  v_current_source TEXT;
  v_trial_expires TIMESTAMPTZ;
BEGIN
  -- Look up profile by firebase_uid
  SELECT p.id, p.premium_source, p.premium_trial_expires_at
  INTO v_profile_id, v_current_source, v_trial_expires
  FROM app_public.profiles p
  WHERE p.firebase_uid = p_firebase_uid;

  IF v_profile_id IS NULL THEN
    RETURN;
  END IF;

  IF p_is_premium = true THEN
    -- Grant premium from revenuecat
    RETURN QUERY
    UPDATE app_public.profiles
    SET is_premium = true,
        premium_source = 'revenuecat',
        premium_expires_at = p_expires_at
    WHERE id = v_profile_id
    RETURNING profiles.is_premium, profiles.premium_source, profiles.premium_expires_at;
  ELSE
    -- Only downgrade if current source is revenuecat
    IF v_current_source = 'revenuecat' THEN
      -- Check if there is an active trial to fall back to
      IF v_trial_expires IS NOT NULL AND v_trial_expires > NOW() THEN
        -- Fall back to trial
        RETURN QUERY
        UPDATE app_public.profiles
        SET is_premium = true,
            premium_source = 'trial',
            premium_expires_at = NULL
        WHERE id = v_profile_id
        RETURNING profiles.is_premium, profiles.premium_source, profiles.premium_expires_at;
      ELSE
        -- Full downgrade
        RETURN QUERY
        UPDATE app_public.profiles
        SET is_premium = false,
            premium_source = NULL,
            premium_expires_at = NULL
        WHERE id = v_profile_id
        RETURNING profiles.is_premium, profiles.premium_source, profiles.premium_expires_at;
      END IF;
    ELSE
      -- premium_source is 'trial' or NULL -- do NOT downgrade
      RETURN QUERY
      SELECT p.is_premium, p.premium_source, p.premium_expires_at
      FROM app_public.profiles p
      WHERE p.id = v_profile_id;
    END IF;
  END IF;
END;
$$;

-- ============================================================
-- 6. Update check_trial_expiry RPC to also clear premium_source
-- ============================================================
CREATE OR REPLACE FUNCTION app_public.check_trial_expiry(p_profile_id UUID)
RETURNS TABLE(is_premium BOOLEAN, premium_trial_expires_at TIMESTAMPTZ, trial_expired BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trial_expires TIMESTAMPTZ;
  v_is_premium BOOLEAN;
  v_premium_source TEXT;
BEGIN
  SELECT p.premium_trial_expires_at, p.is_premium, p.premium_source
  INTO v_trial_expires, v_is_premium, v_premium_source
  FROM app_public.profiles p
  WHERE p.id = p_profile_id;

  IF v_trial_expires IS NOT NULL AND v_trial_expires < NOW() AND v_premium_source = 'trial' THEN
    UPDATE app_public.profiles
    SET is_premium = false, premium_trial_expires_at = NULL, premium_source = NULL
    WHERE id = p_profile_id AND premium_source = 'trial';

    is_premium := false;
    premium_trial_expires_at := NULL;
    trial_expired := true;
    RETURN NEXT;
    RETURN;
  END IF;

  is_premium := v_is_premium;
  premium_trial_expires_at := v_trial_expires;
  trial_expired := false;
  RETURN NEXT;
  RETURN;
END;
$$;
