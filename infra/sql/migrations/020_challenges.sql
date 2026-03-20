-- Migration 020: Challenge Rewards (Premium Trial)
-- Creates challenges catalog table, user_challenges junction table,
-- seeds Closet Safari challenge, adds premium_trial_expires_at to profiles,
-- and creates grant_premium_trial, check_trial_expiry, and increment_challenge_progress RPCs.

-- ============================================================
-- 1. challenges table (public catalog of challenge definitions)
-- ============================================================
CREATE TABLE app_public.challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  target_count INTEGER NOT NULL,
  time_limit_days INTEGER NOT NULL,
  reward_type TEXT NOT NULL CHECK (reward_type IN ('premium_trial')),
  reward_value INTEGER NOT NULL,
  icon_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: all authenticated users can read challenge definitions (public catalog)
ALTER TABLE app_public.challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY challenges_select_all_authenticated
  ON app_public.challenges
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================
-- 2. user_challenges table (junction: user <-> challenge state)
-- ============================================================
CREATE TABLE app_public.user_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  challenge_id UUID NOT NULL REFERENCES app_public.challenges(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'expired', 'skipped')),
  accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  current_progress INTEGER NOT NULL DEFAULT 0,
  UNIQUE(profile_id, challenge_id)
);

-- RLS: users can read and update only their own challenge rows
ALTER TABLE app_public.user_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_challenges_select_own
  ON app_public.user_challenges
  FOR SELECT
  TO authenticated
  USING (
    profile_id = (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id')
    )
  );

CREATE POLICY user_challenges_update_own
  ON app_public.user_challenges
  FOR UPDATE
  TO authenticated
  USING (
    profile_id = (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id')
    )
  );

-- Index for efficient lookups by profile
CREATE INDEX idx_user_challenges_profile ON app_public.user_challenges(profile_id);

-- ============================================================
-- 3. Seed Closet Safari challenge
-- ============================================================
INSERT INTO app_public.challenges (key, name, description, target_count, time_limit_days, reward_type, reward_value, icon_name)
VALUES ('closet_safari', 'Closet Safari', 'Upload 20 items in 7 days to unlock 1 month Premium free', 20, 7, 'premium_trial', 30, 'explore');

-- ============================================================
-- 4. Add premium_trial_expires_at column to profiles
-- ============================================================
ALTER TABLE app_public.profiles ADD COLUMN premium_trial_expires_at TIMESTAMPTZ;

-- ============================================================
-- 5. grant_premium_trial RPC
-- ============================================================
CREATE OR REPLACE FUNCTION app_public.grant_premium_trial(p_profile_id UUID, p_days INTEGER)
RETURNS TABLE(is_premium BOOLEAN, premium_trial_expires_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  UPDATE app_public.profiles
  SET is_premium = true,
      premium_trial_expires_at = NOW() + (p_days || ' days')::INTERVAL
  WHERE id = p_profile_id
  RETURNING profiles.is_premium, profiles.premium_trial_expires_at;
END;
$$;

-- ============================================================
-- 6. check_trial_expiry RPC
-- ============================================================
CREATE OR REPLACE FUNCTION app_public.check_trial_expiry(p_profile_id UUID)
RETURNS TABLE(is_premium BOOLEAN, premium_trial_expires_at TIMESTAMPTZ, trial_expired BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_trial_expires TIMESTAMPTZ;
  v_is_premium BOOLEAN;
BEGIN
  SELECT p.premium_trial_expires_at, p.is_premium
  INTO v_trial_expires, v_is_premium
  FROM app_public.profiles p
  WHERE p.id = p_profile_id;

  IF v_trial_expires IS NOT NULL AND v_trial_expires < NOW() THEN
    UPDATE app_public.profiles
    SET is_premium = false, premium_trial_expires_at = NULL
    WHERE id = p_profile_id;

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

-- ============================================================
-- 7. increment_challenge_progress RPC
-- ============================================================
CREATE OR REPLACE FUNCTION app_public.increment_challenge_progress(p_profile_id UUID, p_challenge_key TEXT)
RETURNS TABLE(challenge_key TEXT, current_progress INTEGER, target_count INTEGER, completed BOOLEAN, reward_granted BOOLEAN, time_remaining_seconds INTEGER)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_challenge_id UUID;
  v_target_count INTEGER;
  v_reward_value INTEGER;
  v_uc_id UUID;
  v_status TEXT;
  v_expires_at TIMESTAMPTZ;
  v_current_progress INTEGER;
  v_completed BOOLEAN := false;
  v_reward_granted BOOLEAN := false;
BEGIN
  -- Look up the challenge by key
  SELECT c.id, c.target_count, c.reward_value
  INTO v_challenge_id, v_target_count, v_reward_value
  FROM app_public.challenges c
  WHERE c.key = p_challenge_key;

  IF v_challenge_id IS NULL THEN
    RETURN;
  END IF;

  -- Look up user_challenges for this profile+challenge where status = 'active'
  SELECT uc.id, uc.status, uc.expires_at, uc.current_progress
  INTO v_uc_id, v_status, v_expires_at, v_current_progress
  FROM app_public.user_challenges uc
  WHERE uc.profile_id = p_profile_id AND uc.challenge_id = v_challenge_id AND uc.status = 'active';

  IF v_uc_id IS NULL THEN
    RETURN;
  END IF;

  -- If expired, set status to 'expired' and return
  IF v_expires_at < NOW() THEN
    UPDATE app_public.user_challenges
    SET status = 'expired'
    WHERE id = v_uc_id;

    challenge_key := p_challenge_key;
    current_progress := v_current_progress;
    target_count := v_target_count;
    completed := false;
    reward_granted := false;
    time_remaining_seconds := 0;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Increment current_progress
  v_current_progress := v_current_progress + 1;

  -- Check if completed
  IF v_current_progress >= v_target_count THEN
    UPDATE app_public.user_challenges
    SET current_progress = v_current_progress,
        status = 'completed',
        completed_at = now()
    WHERE id = v_uc_id;

    -- Grant premium trial
    PERFORM app_public.grant_premium_trial(p_profile_id, v_reward_value);

    v_completed := true;
    v_reward_granted := true;
  ELSE
    UPDATE app_public.user_challenges
    SET current_progress = v_current_progress
    WHERE id = v_uc_id;
  END IF;

  challenge_key := p_challenge_key;
  current_progress := v_current_progress;
  target_count := v_target_count;
  completed := v_completed;
  reward_granted := v_reward_granted;
  time_remaining_seconds := GREATEST(EXTRACT(EPOCH FROM (v_expires_at - NOW()))::INTEGER, 0);
  RETURN NEXT;
  RETURN;
END;
$$;
