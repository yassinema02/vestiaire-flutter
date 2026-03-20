import assert from "node:assert/strict";
import test from "node:test";
import {
  createGapAnalysisService,
  detectCategoryGaps,
  detectWeatherGaps,
  detectFormalityGaps,
  detectColorGaps,
  buildGapPrompt,
  SEVERITY_ORDER,
} from "../../../src/modules/analytics/gap-analysis-service.js";

const testAuthContext = { userId: "firebase-user-123" };

function createMockGeminiClient({
  available = true,
  responseText = '{"recommendations":[]}',
  shouldFail = false,
  failMessage = "Gemini error",
} = {}) {
  const calls = [];
  return {
    calls,
    isAvailable() { return available; },
    async getGenerativeModel(model) {
      return {
        async generateContent(opts) {
          calls.push({ model, opts });
          if (shouldFail) throw new Error(failMessage);
          return {
            response: {
              candidates: [{ content: { parts: [{ text: responseText }] } }],
              usageMetadata: { promptTokenCount: 100, candidatesTokenCount: 50 },
            },
          };
        },
      };
    },
  };
}

function createMockRepository(data = {}) {
  return {
    async getGapAnalysisData() {
      return data;
    },
  };
}

function createMockAiUsageLogRepo() {
  const logs = [];
  return {
    logs,
    async logUsage(authContext, entry) {
      logs.push(entry);
    },
  };
}

// --- Factory tests ---

test("createGapAnalysisService returns object with analyzeGaps method", () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient(),
    analyticsRepository: createMockRepository(),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  assert.equal(typeof service.analyzeGaps, "function");
});

// --- Empty wardrobe tests ---

test("analyzeGaps returns empty gaps when totalItems < 5", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient(),
    analyticsRepository: createMockRepository({ totalItems: 3, gaps: [], recommendations: [] }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  assert.deepEqual(result.gaps, []);
  assert.equal(result.totalItems, 3);
});

// --- Category gap detection ---

test("detects Critical gap when a core category is completely missing", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 5 },
        { category: "bottoms", count: 3 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 10 }],
      colorDistribution: [{ color: "black", count: 5 }, { color: "blue", count: 5 }],
      occasionCoverage: [{ occasion: "everyday", count: 5 }, { occasion: "work", count: 5 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const outerwearGap = result.gaps.find((g) => g.id === "gap-category-missing-outerwear");
  assert.ok(outerwearGap, "Should detect missing outerwear");
  assert.equal(outerwearGap.severity, "critical");
  assert.equal(outerwearGap.dimension, "category");
});

test("detects Important gap when a category is underrepresented", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 20,
      categoryDistribution: [
        { category: "tops", count: 10 },
        { category: "bottoms", count: 5 },
        { category: "outerwear", count: 1 }, // 5% < 10%
        { category: "dresses", count: 2 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 20 }],
      colorDistribution: [{ color: "black", count: 10 }, { color: "blue", count: 10 }],
      occasionCoverage: [{ occasion: "everyday", count: 10 }, { occasion: "work", count: 10 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const outerwearGap = result.gaps.find((g) => g.id === "gap-category-underrepresented-outerwear");
  assert.ok(outerwearGap, "Should detect underrepresented outerwear");
  assert.equal(outerwearGap.severity, "important");
});

// --- Weather coverage gaps ---

test("detects Critical gap when a season has zero items (wardrobe 10+)", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 12,
      categoryDistribution: [
        { category: "tops", count: 4 },
        { category: "bottoms", count: 4 },
        { category: "outerwear", count: 2 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [
        { season: "summer", count: 6 },
        { season: "spring", count: 6 },
      ],
      colorDistribution: [{ color: "black", count: 6 }, { color: "blue", count: 6 }],
      occasionCoverage: [{ occasion: "everyday", count: 6 }, { occasion: "work", count: 6 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const winterGap = result.gaps.find((g) => g.id === "gap-weather-no-winter");
  assert.ok(winterGap, "Should detect no winter items");
  assert.equal(winterGap.severity, "critical");
  assert.equal(winterGap.dimension, "weather");
});

test("detects Important gap when a season is underrepresented", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 20,
      categoryDistribution: [
        { category: "tops", count: 8 },
        { category: "bottoms", count: 6 },
        { category: "outerwear", count: 3 },
        { category: "shoes", count: 3 },
      ],
      seasonCoverage: [
        { season: "summer", count: 10 },
        { season: "spring", count: 8 },
        { season: "winter", count: 1 }, // 5% < 10%
        { season: "fall", count: 1 }, // 5% < 10%
      ],
      colorDistribution: [{ color: "black", count: 10 }, { color: "blue", count: 10 }],
      occasionCoverage: [{ occasion: "everyday", count: 10 }, { occasion: "work", count: 10 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const winterGap = result.gaps.find((g) => g.id === "gap-weather-limited-winter");
  assert.ok(winterGap, "Should detect limited winter coverage");
  assert.equal(winterGap.severity, "important");
});

// --- Formality spectrum gaps ---

test("detects Important gap when formal wear is missing (wardrobe 10+)", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 12,
      categoryDistribution: [
        { category: "tops", count: 4 },
        { category: "bottoms", count: 4 },
        { category: "outerwear", count: 2 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 12 }],
      colorDistribution: [{ color: "black", count: 6 }, { color: "blue", count: 6 }],
      occasionCoverage: [
        { occasion: "everyday", count: 8 },
        { occasion: "work", count: 4 },
      ],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const formalGap = result.gaps.find((g) => g.id === "gap-formality-no-formal");
  assert.ok(formalGap, "Should detect no formal wear");
  assert.equal(formalGap.severity, "important");
  assert.equal(formalGap.dimension, "formality");
});

test("detects Important gap when work wear is missing (wardrobe 10+)", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 4 },
        { category: "bottoms", count: 3 },
        { category: "outerwear", count: 2 },
        { category: "shoes", count: 1 },
      ],
      seasonCoverage: [{ season: "all", count: 10 }],
      colorDistribution: [{ color: "black", count: 5 }, { color: "blue", count: 5 }],
      occasionCoverage: [
        { occasion: "everyday", count: 8 },
        { occasion: "formal", count: 2 },
      ],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const workGap = result.gaps.find((g) => g.id === "gap-formality-no-work");
  assert.ok(workGap, "Should detect no work items");
  assert.equal(workGap.severity, "important");
});

test("detects Important gap when only 1 occasion type exists", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 8,
      categoryDistribution: [
        { category: "tops", count: 4 },
        { category: "bottoms", count: 4 },
      ],
      seasonCoverage: [{ season: "all", count: 8 }],
      colorDistribution: [{ color: "black", count: 4 }, { color: "blue", count: 4 }],
      occasionCoverage: [
        { occasion: "everyday", count: 8 },
      ],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const diversityGap = result.gaps.find((g) => g.id === "gap-formality-limited-diversity");
  assert.ok(diversityGap, "Should detect limited occasion diversity");
  assert.equal(diversityGap.severity, "important");
});

// --- Color range gaps ---

test("detects Important gap when only 1 color group represented", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 8,
      categoryDistribution: [
        { category: "tops", count: 4 },
        { category: "bottoms", count: 4 },
      ],
      seasonCoverage: [{ season: "all", count: 8 }],
      colorDistribution: [{ color: "black", count: 4 }, { color: "white", count: 4 }], // all neutrals
      occasionCoverage: [{ occasion: "everyday", count: 4 }, { occasion: "work", count: 4 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const colorGap = result.gaps.find((g) => g.id === "gap-color-limited-variety");
  assert.ok(colorGap, "Should detect limited color variety");
  assert.equal(colorGap.severity, "important");
  assert.equal(colorGap.dimension, "color");
});

test("detects Optional gap when 4+ color groups empty (wardrobe 15+)", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 20,
      categoryDistribution: [
        { category: "tops", count: 8 },
        { category: "bottoms", count: 6 },
        { category: "outerwear", count: 3 },
        { category: "shoes", count: 3 },
      ],
      seasonCoverage: [{ season: "all", count: 20 }],
      colorDistribution: [
        { color: "black", count: 10 }, // neutrals
        { color: "blue", count: 10 }, // cool
      ],
      occasionCoverage: [{ occasion: "everyday", count: 10 }, { occasion: "work", count: 10 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const paletteGap = result.gaps.find((g) => g.id === "gap-color-palette-limited");
  assert.ok(paletteGap, "Should detect limited palette");
  assert.equal(paletteGap.severity, "optional");
});

// --- Limits and sorting ---

test("gaps are limited to 10 maximum", async () => {
  // Create a wardrobe that triggers many gaps
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 20,
      categoryDistribution: [
        { category: "tops", count: 20 },
        // Missing: bottoms, outerwear, dresses, shoes -> 4 critical gaps
      ],
      seasonCoverage: [
        { season: "summer", count: 20 },
        // Missing: spring, fall, winter -> 3 critical gaps (total >= 10)
      ],
      colorDistribution: [{ color: "black", count: 20 }],
      occasionCoverage: [
        { occasion: "everyday", count: 20 },
        // Missing: formal, work -> 2 important gaps
      ],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  assert.ok(result.gaps.length <= 10, `Should have at most 10 gaps, got ${result.gaps.length}`);
});

test("gaps are sorted by severity priority (critical > important > optional)", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 20,
      categoryDistribution: [
        { category: "tops", count: 10 },
        { category: "bottoms", count: 5 },
        { category: "shoes", count: 3 },
        { category: "outerwear", count: 1 }, // underrepresented -> important
        // Missing: dresses -> critical
      ],
      seasonCoverage: [{ season: "all", count: 20 }],
      colorDistribution: [{ color: "black", count: 20 }], // only neutrals
      occasionCoverage: [{ occasion: "everyday", count: 10 }, { occasion: "work", count: 10 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);

  // Verify severity ordering
  let prevOrder = -1;
  for (const gap of result.gaps) {
    const order = SEVERITY_ORDER[gap.severity];
    assert.ok(order >= prevOrder, `Gaps should be sorted: ${gap.severity} came after a higher priority gap`);
    prevOrder = order;
  }
});

// --- Gemini enrichment ---

test("Gemini called with correct prompt containing wardrobe summary and gaps", async () => {
  const geminiClient = createMockGeminiClient({
    responseText: JSON.stringify({
      recommendations: [
        { gapId: "gap-category-missing-dresses", recommendation: "Consider adding a black cocktail dress" },
      ],
    }),
  });
  const service = createGapAnalysisService({
    geminiClient,
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 5 },
        { category: "bottoms", count: 3 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 10 }],
      colorDistribution: [{ color: "black", count: 5 }, { color: "blue", count: 5 }],
      occasionCoverage: [{ occasion: "everyday", count: 5 }, { occasion: "work", count: 5 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  await service.analyzeGaps(testAuthContext);
  assert.ok(geminiClient.calls.length > 0, "Should have called Gemini");
  const prompt = geminiClient.calls[0].opts.contents[0].parts[0].text;
  assert.ok(prompt.includes("Total items: 10"), "Prompt should include total items");
  assert.ok(prompt.includes("DETECTED GAPS"), "Prompt should include gaps section");
  assert.ok(prompt.includes("wardrobe advisor"), "Prompt should include system instruction");
});

test("Gemini recommendations are matched to gaps by gapId", async () => {
  const geminiClient = createMockGeminiClient({
    responseText: JSON.stringify({
      recommendations: [
        { gapId: "gap-category-missing-dresses", recommendation: "Add a versatile wrap dress" },
        { gapId: "gap-category-missing-outerwear", recommendation: "Get a navy trench coat" },
      ],
    }),
  });
  const service = createGapAnalysisService({
    geminiClient,
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 5 },
        { category: "bottoms", count: 3 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 10 }],
      colorDistribution: [{ color: "black", count: 5 }, { color: "blue", count: 5 }],
      occasionCoverage: [{ occasion: "everyday", count: 5 }, { occasion: "work", count: 5 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  const dressGap = result.gaps.find((g) => g.id === "gap-category-missing-dresses");
  assert.equal(dressGap.recommendation, "Add a versatile wrap dress");
  const outerwearGap = result.gaps.find((g) => g.id === "gap-category-missing-outerwear");
  assert.equal(outerwearGap.recommendation, "Get a navy trench coat");
});

test("Gemini failure does NOT fail the analysis -- gaps returned with null recommendations", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ shouldFail: true, failMessage: "Gemini timeout" }),
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 5 },
        { category: "bottoms", count: 3 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 10 }],
      colorDistribution: [{ color: "black", count: 5 }, { color: "blue", count: 5 }],
      occasionCoverage: [{ occasion: "everyday", count: 5 }, { occasion: "work", count: 5 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  assert.ok(result.gaps.length > 0, "Should still return gaps");
  for (const gap of result.gaps) {
    assert.equal(gap.recommendation, null, `Gap ${gap.id} should have null recommendation`);
  }
});

// --- AI usage logging ---

test("AI usage logged for success with feature gap_analysis", async () => {
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({
      responseText: JSON.stringify({ recommendations: [] }),
    }),
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 5 },
        { category: "bottoms", count: 3 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 10 }],
      colorDistribution: [{ color: "black", count: 5 }, { color: "blue", count: 5 }],
      occasionCoverage: [{ occasion: "everyday", count: 5 }, { occasion: "work", count: 5 }],
    }),
    aiUsageLogRepo,
  });
  await service.analyzeGaps(testAuthContext);
  const successLog = aiUsageLogRepo.logs.find((l) => l.status === "success");
  assert.ok(successLog, "Should log success");
  assert.equal(successLog.feature, "gap_analysis");
  assert.equal(successLog.model, "gemini-2.0-flash");
});

test("AI usage logged for failure when Gemini fails", async () => {
  const aiUsageLogRepo = createMockAiUsageLogRepo();
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ shouldFail: true }),
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 5 },
        { category: "bottoms", count: 3 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 10 }],
      colorDistribution: [{ color: "black", count: 5 }, { color: "blue", count: 5 }],
      occasionCoverage: [{ occasion: "everyday", count: 5 }, { occasion: "work", count: 5 }],
    }),
    aiUsageLogRepo,
  });
  await service.analyzeGaps(testAuthContext);
  const failLog = aiUsageLogRepo.logs.find((l) => l.status === "failure");
  assert.ok(failLog, "Should log failure");
  assert.equal(failLog.feature, "gap_analysis");
});

// --- Deterministic IDs ---

test("each gap has a deterministic id", async () => {
  const makeService = () => createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 5 },
        { category: "bottoms", count: 3 },
        { category: "shoes", count: 2 },
      ],
      seasonCoverage: [{ season: "all", count: 10 }],
      colorDistribution: [{ color: "black", count: 5 }, { color: "blue", count: 5 }],
      occasionCoverage: [{ occasion: "everyday", count: 5 }, { occasion: "work", count: 5 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });

  const result1 = await makeService().analyzeGaps(testAuthContext);
  const result2 = await makeService().analyzeGaps(testAuthContext);

  assert.equal(result1.gaps.length, result2.gaps.length);
  for (let i = 0; i < result1.gaps.length; i++) {
    assert.equal(result1.gaps[i].id, result2.gaps[i].id, "Gap IDs should be deterministic");
  }
});

// --- Well-balanced wardrobe ---

test("works correctly with a well-balanced wardrobe (few or no gaps)", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 30,
      categoryDistribution: [
        { category: "tops", count: 8 },
        { category: "bottoms", count: 6 },
        { category: "outerwear", count: 4 },
        { category: "dresses", count: 4 },
        { category: "shoes", count: 5 },
        { category: "accessories", count: 3 },
      ],
      seasonCoverage: [
        { season: "spring", count: 8 },
        { season: "summer", count: 8 },
        { season: "fall", count: 7 },
        { season: "winter", count: 7 },
      ],
      colorDistribution: [
        { color: "black", count: 6 },
        { color: "blue", count: 5 },
        { color: "red", count: 4 },
        { color: "brown", count: 5 },
        { color: "purple", count: 4 },
        { color: "light-blue", count: 6 },
      ],
      occasionCoverage: [
        { occasion: "everyday", count: 10 },
        { occasion: "work", count: 8 },
        { occasion: "formal", count: 5 },
        { occasion: "party", count: 4 },
        { occasion: "outdoor", count: 3 },
      ],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  assert.ok(result.gaps.length <= 2, `Well-balanced wardrobe should have few gaps, got ${result.gaps.length}`);
});

// --- Gemini unavailable ---

test("Gemini unavailable still returns rule-based gaps", async () => {
  const service = createGapAnalysisService({
    geminiClient: createMockGeminiClient({ available: false }),
    analyticsRepository: createMockRepository({
      totalItems: 10,
      categoryDistribution: [
        { category: "tops", count: 10 },
      ],
      seasonCoverage: [{ season: "summer", count: 10 }],
      colorDistribution: [{ color: "black", count: 10 }],
      occasionCoverage: [{ occasion: "everyday", count: 10 }],
    }),
    aiUsageLogRepo: createMockAiUsageLogRepo(),
  });
  const result = await service.analyzeGaps(testAuthContext);
  assert.ok(result.gaps.length > 0, "Should return rule-based gaps even without Gemini");
  for (const gap of result.gaps) {
    assert.equal(gap.recommendation, null, "No recommendations without Gemini");
  }
});
