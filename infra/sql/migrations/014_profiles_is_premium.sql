-- Migration 014: Add is_premium column to profiles table
-- Story 4.5: AI Usage Limits Enforcement
--
-- This column is the server-side source of truth for premium status.
-- Story 7.1 (RevenueCat integration) will update this column via a webhook.
-- For now, it defaults to false for all users and can be toggled manually.

ALTER TABLE app_public.profiles ADD COLUMN is_premium BOOLEAN NOT NULL DEFAULT false;

-- Partial index: only premium users are indexed, keeping the index small.
CREATE INDEX idx_profiles_is_premium ON app_public.profiles(is_premium) WHERE is_premium = true;

-- Composite index on ai_usage_log for efficient daily count queries.
-- Covers the exact query pattern: WHERE profile_id = $1 AND feature = $2 AND status = $3 AND created_at >= $4
CREATE INDEX idx_ai_usage_log_daily_count ON app_public.ai_usage_log(profile_id, feature, status, created_at DESC);
