import assert from "node:assert/strict";
import test from "node:test";
import {
  classifyByKeywords,
  createEventClassificationService
} from "../../../src/modules/calendar/event-classification-service.js";

function createMockGeminiClient({ shouldFail = false, isAvailable = true, responseJson = null } = {}) {
  const calls = [];
  const defaultResponse = {
    eventType: "work",
    formalityScore: 6
  };

  return {
    calls,
    isAvailable() {
      return isAvailable;
    },
    async getGenerativeModel(modelName) {
      calls.push({ method: "getGenerativeModel", modelName });
      return {
        async generateContent(request) {
          calls.push({ method: "generateContent", request });
          if (shouldFail) {
            throw new Error("Gemini API error: rate limit exceeded");
          }
          return {
            response: {
              candidates: [
                {
                  content: {
                    parts: [
                      {
                        text: JSON.stringify(responseJson ?? defaultResponse)
                      }
                    ]
                  }
                }
              ],
              usageMetadata: {
                promptTokenCount: 50,
                candidatesTokenCount: 20
              }
            }
          };
        }
      };
    }
  };
}

function createMockAiUsageLogRepo() {
  const calls = [];
  return {
    calls,
    async logUsage(authContext, params) {
      calls.push({ method: "logUsage", authContext, params });
      return { id: "log-1", ...params };
    }
  };
}

const testAuthContext = { userId: "firebase-user-123" };

// --- classifyByKeywords tests ---

test("classifyByKeywords returns 'work' for 'Sprint Planning' title", () => {
  const result = classifyByKeywords("Sprint Planning", "");
  assert.equal(result.eventType, "work");
  assert.equal(result.formalityScore, 5);
  assert.equal(result.confidence, "high");
});

test("classifyByKeywords returns 'social' for 'Birthday dinner with friends' title", () => {
  const result = classifyByKeywords("Birthday dinner with friends", "");
  assert.equal(result.eventType, "social");
  assert.equal(result.formalityScore, 3);
  assert.equal(result.confidence, "high");
});

test("classifyByKeywords returns 'active' for 'Yoga class' title", () => {
  const result = classifyByKeywords("Yoga class", "");
  assert.equal(result.eventType, "active");
  assert.equal(result.formalityScore, 1);
  assert.equal(result.confidence, "high");
});

test("classifyByKeywords returns 'formal' for 'Wedding reception' title", () => {
  const result = classifyByKeywords("Wedding reception", "");
  assert.equal(result.eventType, "formal");
  assert.equal(result.formalityScore, 8);
  assert.equal(result.confidence, "high");
});

test("classifyByKeywords returns 'casual' with low confidence for 'Doctor appointment' title", () => {
  const result = classifyByKeywords("Doctor appointment", "");
  assert.equal(result.eventType, "casual");
  assert.equal(result.formalityScore, 2);
  assert.equal(result.confidence, "low");
});

test("classifyByKeywords checks description when title has no keywords", () => {
  const result = classifyByKeywords("Appointment at 3pm", "Meet at the gym lobby");
  assert.equal(result.eventType, "active");
  assert.equal(result.formalityScore, 1);
});

// --- classifyWithAI tests ---

test("classifyWithAI calls Gemini and returns valid classification", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: { eventType: "social", formalityScore: 4 }
  });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const service = createEventClassificationService({ geminiClient, aiUsageLogRepo });

  const result = await service.classifyWithAI(testAuthContext, {
    title: "Coffee with Sarah",
    description: "",
    location: "Starbucks",
    startTime: "2026-03-15T10:00:00Z"
  });

  assert.equal(result.eventType, "social");
  assert.equal(result.formalityScore, 4);
  assert.equal(result.classificationSource, "ai");
});

test("classifyWithAI logs usage to ai_usage_log", async () => {
  const geminiClient = createMockGeminiClient();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const service = createEventClassificationService({ geminiClient, aiUsageLogRepo });

  await service.classifyWithAI(testAuthContext, {
    title: "Team standup",
    description: "",
    location: "",
    startTime: "2026-03-15T09:00:00Z"
  });

  assert.equal(aiUsageLogRepo.calls.length, 1);
  assert.equal(aiUsageLogRepo.calls[0].params.feature, "event_classification");
  assert.equal(aiUsageLogRepo.calls[0].params.status, "success");
});

test("classifyWithAI returns keyword fallback when Gemini fails", async () => {
  const geminiClient = createMockGeminiClient({ shouldFail: true });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const service = createEventClassificationService({ geminiClient, aiUsageLogRepo });

  const result = await service.classifyWithAI(testAuthContext, {
    title: "Doctor appointment",
    description: "",
    location: "",
    startTime: "2026-03-15T14:00:00Z"
  });

  // Should fall back to keyword (casual for doctor appointment)
  assert.equal(result.eventType, "casual");
  assert.equal(result.classificationSource, "keyword");

  // Should log the failure
  const failureLogs = aiUsageLogRepo.calls.filter(c => c.params.status === "failure");
  assert.equal(failureLogs.length, 1);
});

// --- classifyEvent orchestrator tests ---

test("classifyEvent uses keyword result when confidence is high", async () => {
  const geminiClient = createMockGeminiClient();
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const service = createEventClassificationService({ geminiClient, aiUsageLogRepo });

  const result = await service.classifyEvent(testAuthContext, {
    title: "Sprint Planning",
    description: "",
    location: "",
    startTime: "2026-03-15T10:00:00Z"
  });

  assert.equal(result.eventType, "work");
  assert.equal(result.classificationSource, "keyword");
  // Gemini should NOT have been called
  assert.equal(geminiClient.calls.length, 0);
});

test("classifyEvent calls AI when keyword confidence is low", async () => {
  const geminiClient = createMockGeminiClient({
    responseJson: { eventType: "social", formalityScore: 5 }
  });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const service = createEventClassificationService({ geminiClient, aiUsageLogRepo });

  const result = await service.classifyEvent(testAuthContext, {
    title: "Doctor appointment",
    description: "",
    location: "",
    startTime: "2026-03-15T14:00:00Z"
  });

  assert.equal(result.eventType, "social");
  assert.equal(result.classificationSource, "ai");
  // Gemini should have been called
  assert.ok(geminiClient.calls.length > 0);
});

test("classifyEvent returns keyword result when AI is unavailable", async () => {
  const geminiClient = createMockGeminiClient({ isAvailable: false });
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const service = createEventClassificationService({ geminiClient, aiUsageLogRepo });

  const result = await service.classifyEvent(testAuthContext, {
    title: "Doctor appointment",
    description: "",
    location: "",
    startTime: "2026-03-15T14:00:00Z"
  });

  assert.equal(result.eventType, "casual");
  assert.equal(result.classificationSource, "keyword");
});

// --- Formality score defaults ---

test("formality score defaults: work=5, social=3, active=1, formal=8, casual=2", () => {
  assert.equal(classifyByKeywords("Meeting", "").formalityScore, 5);
  assert.equal(classifyByKeywords("Birthday party", "").formalityScore, 3);
  assert.equal(classifyByKeywords("Gym session", "").formalityScore, 1);
  assert.equal(classifyByKeywords("Wedding ceremony", "").formalityScore, 8);
  assert.equal(classifyByKeywords("Something random", "").formalityScore, 2);
});
