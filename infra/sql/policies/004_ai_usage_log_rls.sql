-- RLS Policy 004: AI usage log row-level security
-- Story 2.2: AI Background Removal & Upload

ALTER TABLE app_public.ai_usage_log ENABLE ROW LEVEL SECURITY;

-- Users can only read their own AI usage logs
CREATE POLICY ai_usage_log_select_own ON app_public.ai_usage_log
  FOR SELECT
  USING (
    profile_id IN (
      SELECT id FROM app_public.profiles
      WHERE firebase_uid = current_setting('app.current_user_id', true)
    )
  );

-- The API service role can insert usage logs for any user
CREATE POLICY ai_usage_log_insert_service ON app_public.ai_usage_log
  FOR INSERT
  WITH CHECK (true);
