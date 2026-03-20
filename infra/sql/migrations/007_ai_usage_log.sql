-- Migration 007: Create AI usage log table
-- Story 2.2: AI Background Removal & Upload

CREATE TABLE app_public.ai_usage_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  feature TEXT NOT NULL,
  model TEXT NOT NULL,
  input_tokens INTEGER,
  output_tokens INTEGER,
  latency_ms INTEGER,
  estimated_cost_usd NUMERIC(10,6),
  status TEXT NOT NULL CHECK (status IN ('success', 'failure')),
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_usage_log_profile_id ON app_public.ai_usage_log(profile_id);
CREATE INDEX idx_ai_usage_log_feature ON app_public.ai_usage_log(feature);
CREATE INDEX idx_ai_usage_log_created_at ON app_public.ai_usage_log(created_at);
