import assert from "node:assert/strict";
import test from "node:test";
import { createAiUsageLogRepository } from "../../../src/modules/ai/ai-usage-log-repository.js";

test("createAiUsageLogRepository requires pool", () => {
  assert.throws(
    () => createAiUsageLogRepository({}),
    { message: "pool is required" }
  );
});

test("logUsage inserts a row with correct fields", async () => {
  let capturedQuery;
  let capturedValues;
  const queryResults = [
    // set_config
    { rows: [] },
    // profile lookup
    { rows: [{ id: "profile-uuid-1" }] },
    // INSERT
    {
      rows: [
        {
          id: "log-1",
          profile_id: "profile-uuid-1",
          feature: "background_removal",
          model: "gemini-2.0-flash",
          input_tokens: 100,
          output_tokens: 50,
          latency_ms: 1200,
          estimated_cost_usd: 0.000023,
          status: "success",
          error_message: null
        }
      ]
    }
  ];
  let queryIndex = 0;

  const mockPool = {
    async connect() {
      return {
        async query(sql, params) {
          if (sql === "begin" || sql === "commit" || sql === "rollback") {
            return { rows: [] };
          }
          if (sql.includes("INSERT INTO")) {
            capturedQuery = sql;
            capturedValues = params;
          }
          return queryResults[queryIndex++] ?? { rows: [] };
        },
        release() {}
      };
    }
  };

  const repo = createAiUsageLogRepository({ pool: mockPool });

  const result = await repo.logUsage(
    { userId: "firebase-user-123" },
    {
      feature: "background_removal",
      model: "gemini-2.0-flash",
      inputTokens: 100,
      outputTokens: 50,
      latencyMs: 1200,
      estimatedCostUsd: 0.000023,
      status: "success"
    }
  );

  assert.ok(capturedQuery.includes("INSERT INTO app_public.ai_usage_log"));
  assert.equal(capturedValues[0], "profile-uuid-1");
  assert.equal(capturedValues[1], "background_removal");
  assert.equal(capturedValues[2], "gemini-2.0-flash");
  assert.equal(capturedValues[3], 100);
  assert.equal(capturedValues[4], 50);
  assert.equal(capturedValues[5], 1200);
  assert.equal(capturedValues[6], 0.000023);
  assert.equal(capturedValues[7], "success");
  assert.equal(capturedValues[8], null);
  assert.equal(result.id, "log-1");
});

test("logUsage includes error_message on failure", async () => {
  let capturedValues;
  const queryResults = [
    { rows: [] },
    { rows: [{ id: "profile-uuid-1" }] },
    { rows: [{ id: "log-2", status: "failure", error_message: "API timeout" }] }
  ];
  let queryIndex = 0;

  const mockPool = {
    async connect() {
      return {
        async query(sql, params) {
          if (sql === "begin" || sql === "commit" || sql === "rollback") {
            return { rows: [] };
          }
          if (sql.includes("INSERT INTO")) {
            capturedValues = params;
          }
          return queryResults[queryIndex++] ?? { rows: [] };
        },
        release() {}
      };
    }
  };

  const repo = createAiUsageLogRepository({ pool: mockPool });

  await repo.logUsage(
    { userId: "firebase-user-123" },
    {
      feature: "background_removal",
      model: "gemini-2.0-flash",
      status: "failure",
      errorMessage: "API timeout"
    }
  );

  assert.equal(capturedValues[7], "failure");
  assert.equal(capturedValues[8], "API timeout");
});
