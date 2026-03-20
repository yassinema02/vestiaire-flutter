/**
 * Repository for logging AI usage across all features.
 *
 * This is a shared repository used by background removal, categorization,
 * outfit generation, and all other AI features.
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createAiUsageLogRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Log an AI usage event.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} params
     * @param {string} params.feature - Feature name (e.g. 'background_removal').
     * @param {string} params.model - Model name (e.g. 'gemini-2.0-flash').
     * @param {number} [params.inputTokens] - Input token count.
     * @param {number} [params.outputTokens] - Output token count.
     * @param {number} [params.latencyMs] - Latency in milliseconds.
     * @param {number} [params.estimatedCostUsd] - Estimated cost in USD.
     * @param {string} params.status - 'success' or 'failure'.
     * @param {string} [params.errorMessage] - Error message on failure.
     */
    async logUsage(authContext, {
      feature,
      model,
      inputTokens = null,
      outputTokens = null,
      latencyMs = null,
      estimatedCostUsd = null,
      status,
      errorMessage = null
    }) {
      const client = await pool.connect();

      try {
        await client.query("begin");
        await client.query(
          "select set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Look up the profile ID for the authenticated user
        const profileResult = await client.query(
          "select id from app_public.profiles where firebase_uid = $1 limit 1",
          [authContext.userId]
        );

        if (profileResult.rows.length === 0) {
          throw new Error("Profile not found for authenticated user");
        }

        const profileId = profileResult.rows[0].id;

        const result = await client.query(
          `INSERT INTO app_public.ai_usage_log
             (profile_id, feature, model, input_tokens, output_tokens, latency_ms, estimated_cost_usd, status, error_message)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           RETURNING *`,
          [profileId, feature, model, inputTokens, outputTokens, latencyMs, estimatedCostUsd, status, errorMessage]
        );

        await client.query("commit");
        return result.rows[0];
      } catch (error) {
        await client.query("rollback");
        throw error;
      } finally {
        client.release();
      }
    }
  };
}
