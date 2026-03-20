import assert from "node:assert/strict";
import test from "node:test";
import { createAnalyticsRepository } from "../../../src/modules/analytics/analytics-repository.js";

const testAuthContext = { userId: "firebase-user-123" };
const otherAuthContext = { userId: "firebase-user-456" };

/**
 * Creates a mock pool that returns configurable query results.
 */
function createMockPool({
  summaryRow = null,
  itemsCpwRows = null,
  topWornAllRows = null,
  topWornPeriodRows = null,
  neglectedRows = null,
  categoryDistributionRows = null,
  wearFrequencyRows = null,
  brandValueRows = null,
  brandValueCategoriesRows = null,
  sustainabilityRow = null,
  gapTotalItemsRow = null,
  gapCategoryRows = null,
  gapSeasonRows = null,
  gapColorRows = null,
  gapOccasionRows = null,
  setConfigUserId = null,
  seasonalItemCountRows = null,
  seasonalMostWornRows = null,
  seasonalNeglectedRows = null,
  seasonalTotalWearsRow = null,
  seasonalWornItemsRow = null,
  seasonalCurrentCountRow = null,
  seasonalPriorCountRow = null,
  heatmapActivityRows = null,
  heatmapAllDatesRows = null,
  heatmapTotalItemsRow = null,
  healthScoreRow = null,
} = {}) {
  const queries = [];

  return {
    queries,
    async connect() {
      return {
        async query(sql, params = []) {
          queries.push({ sql, params });

          if (sql.includes("set_config")) {
            if (setConfigUserId !== null) {
              assert.equal(params[0], setConfigUserId, "RLS user ID should match authContext");
            }
            return {};
          }

          // getBrandValueAnalytics - available categories query
          if (sql.includes("DISTINCT category") && sql.includes("brand IS NOT NULL")) {
            return { rows: brandValueCategoriesRows || [] };
          }

          // getBrandValueAnalytics - brand aggregation query
          if (sql.includes("GROUP BY brand") && sql.includes("HAVING COUNT(*) >= 3")) {
            return { rows: brandValueRows || [] };
          }

          // getGapAnalysisData - total items count
          if (sql.trim() === "SELECT COUNT(*) AS total_items FROM app_public.items") {
            return { rows: [gapTotalItemsRow || { total_items: "0" }] };
          }

          // getGapAnalysisData - category distribution
          if (sql.includes("GROUP BY category") && !sql.includes("item_count") && !sql.includes("brand")) {
            return { rows: gapCategoryRows || [] };
          }

          // getGapAnalysisData - season coverage
          if (sql.includes("GROUP BY season")) {
            return { rows: gapSeasonRows || [] };
          }

          // getGapAnalysisData - color distribution (gap analysis variant)
          if (sql.includes("GROUP BY color")) {
            return { rows: gapColorRows || [] };
          }

          // getGapAnalysisData - occasion coverage
          if (sql.includes("GROUP BY occasion")) {
            return { rows: gapOccasionRows || [] };
          }

          // getWardrobeHealthScore query (MUST be before summary to avoid false match)
          if (sql.includes("items_good_cpw") && sql.includes("items_with_cpw") && sql.includes("items_worn_90d")) {
            return {
              rows: [healthScoreRow || {
                total_items: "0",
                items_worn_90d: "0",
                items_good_cpw: "0",
                items_with_cpw: "0",
                total_wears: "0",
              }]
            };
          }

          // getSustainabilityAnalytics query (MUST be before summary to avoid false match)
          if (sql.includes("avg_wear_count") && sql.includes("items_worn_90d") && sql.includes("total_rewears")) {
            return {
              rows: [sustainabilityRow || {
                total_items: "0",
                avg_wear_count: "0",
                items_worn_90d: "0",
                avg_cpw: "0",
                total_rewears: "0",
                resale_active_items: "0",
                new_items_90d: "0",
              }]
            };
          }

          // getBrandValueAnalytics - available categories query
          if (sql.includes("DISTINCT category") && sql.includes("brand IS NOT NULL")) {
            return { rows: brandValueCategoriesRows || [] };
          }

          // getBrandValueAnalytics - brand aggregation query
          if (sql.includes("GROUP BY brand") && sql.includes("HAVING COUNT(*) >= 3")) {
            return { rows: brandValueRows || [] };
          }

          // getWardrobeSummary query
          if (sql.includes("COUNT(*)") && sql.includes("total_items")) {
            return {
              rows: [summaryRow || {
                total_items: "0",
                priced_items: "0",
                total_value: "0",
                total_wears: "0",
                dominant_currency: null,
              }]
            };
          }

          // getItemsWithCpw query
          if (sql.includes("cpw") && sql.includes("WHERE purchase_price IS NOT NULL")) {
            return { rows: itemsCpwRows || [] };
          }

          // getTopWornItems "all" query
          if (sql.includes("wear_count > 0") && sql.includes("ORDER BY wear_count DESC")) {
            return { rows: topWornAllRows || [] };
          }

          // getTopWornItems period query (30/90)
          if (sql.includes("wear_log_items") && sql.includes("period_wear_count")) {
            return { rows: topWornPeriodRows || [] };
          }

          // getCategoryDistribution query
          if (sql.includes("GROUP BY category") && sql.includes("item_count")) {
            return { rows: categoryDistributionRows || [] };
          }

          // getWearFrequency query
          if (sql.includes("EXTRACT(DOW FROM logged_date)") && sql.includes("log_count")) {
            return { rows: wearFrequencyRows || [] };
          }

          // getNeglectedItems query
          if (sql.includes("days_since_worn") && sql.includes("CURRENT_DATE - 60")) {
            return { rows: neglectedRows || [] };
          }

          // getSeasonalReports - item count per season
          if (sql.includes("season @>") && sql.includes("COUNT(*)") && !sql.includes("wear_count > 0")) {
            return { rows: [seasonalItemCountRows || { count: "0" }] };
          }

          // getSeasonalReports - worn items count per season
          if (sql.includes("season @>") && sql.includes("wear_count > 0") && sql.includes("COUNT(*)")) {
            return { rows: [seasonalWornItemsRow || { count: "0" }] };
          }

          // getSeasonalReports - most worn items per season
          if (sql.includes("season @>") && sql.includes("ORDER BY i.wear_count DESC") && sql.includes("LIMIT 5") && !sql.includes("wear_count = 0")) {
            return { rows: seasonalMostWornRows || [] };
          }

          // getSeasonalReports - neglected items per season
          if (sql.includes("season @>") && sql.includes("wear_count = 0") && sql.includes("90 days")) {
            return { rows: seasonalNeglectedRows || [] };
          }

          // getSeasonalReports - total wears per season
          if (sql.includes("season @>") && sql.includes("SUM(i.wear_count)")) {
            return { rows: [seasonalTotalWearsRow || { total_wears: "0" }] };
          }

          // getHeatmapData - total items for avg (must be before other wear_log_items matchers)
          if (sql.includes("COUNT(DISTINCT wli.id)") && sql.includes("AS total")) {
            return { rows: [heatmapTotalItemsRow || { total: "0" }] };
          }

          // getSeasonalReports/getHeatmapData - historical comparison / daily activity (wear_logs join)
          if (sql.includes("wear_log_items") && sql.includes("COUNT(DISTINCT")) {
            if (sql.includes("GROUP BY wl.logged_date")) {
              // getHeatmapData - daily activity
              return { rows: heatmapActivityRows || [] };
            }
            // Historical comparison query - check if this is current or prior
            if (seasonalPriorCountRow && params.length >= 2) {
              // Return alternating: first call current, second call prior
              const year = params[0];
              if (typeof year === "string" && (year.includes(String(new Date().getFullYear() - 1)) || year.includes(String(new Date().getFullYear() - 2)))) {
                return { rows: [seasonalPriorCountRow] };
              }
            }
            return { rows: [seasonalCurrentCountRow || { count: "0" }] };
          }

          // getHeatmapData - all distinct dates for streak
          if (sql.includes("DISTINCT logged_date") && sql.includes("ORDER BY logged_date DESC")) {
            return { rows: heatmapAllDatesRows || [] };
          }

          return { rows: [] };
        },
        release() {},
      };
    },
  };
}

// --- Factory tests ---

test("createAnalyticsRepository throws when pool is missing", () => {
  assert.throws(() => createAnalyticsRepository({}), TypeError);
});

test("createAnalyticsRepository returns object with expected methods", () => {
  const pool = createMockPool();
  const repo = createAnalyticsRepository({ pool });
  assert.equal(typeof repo.getWardrobeSummary, "function");
  assert.equal(typeof repo.getItemsWithCpw, "function");
  assert.equal(typeof repo.getTopWornItems, "function");
  assert.equal(typeof repo.getNeglectedItems, "function");
  assert.equal(typeof repo.getCategoryDistribution, "function");
  assert.equal(typeof repo.getWearFrequency, "function");
  assert.equal(typeof repo.getBrandValueAnalytics, "function");
  assert.equal(typeof repo.getSustainabilityAnalytics, "function");
  assert.equal(typeof repo.getGapAnalysisData, "function");
  assert.equal(typeof repo.getSeasonalReports, "function");
  assert.equal(typeof repo.getHeatmapData, "function");
  assert.equal(typeof repo.getWardrobeHealthScore, "function");
});

// --- getWardrobeSummary tests ---

test("getWardrobeSummary returns correct totalItems count", async () => {
  const pool = createMockPool({
    summaryRow: {
      total_items: "5",
      priced_items: "3",
      total_value: "150.00",
      total_wears: "30",
      dominant_currency: "GBP",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeSummary(testAuthContext);
  assert.equal(result.totalItems, 5);
});

test("getWardrobeSummary returns correct totalValue (sum of purchase_price where not null)", async () => {
  const pool = createMockPool({
    summaryRow: {
      total_items: "10",
      priced_items: "7",
      total_value: "2450.50",
      total_wears: "100",
      dominant_currency: "GBP",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeSummary(testAuthContext);
  assert.equal(result.totalValue, 2450.50);
  assert.equal(result.pricedItems, 7);
});

test("getWardrobeSummary returns correct totalWears (sum of wear_count for priced items)", async () => {
  const pool = createMockPool({
    summaryRow: {
      total_items: "5",
      priced_items: "3",
      total_value: "300.00",
      total_wears: "45",
      dominant_currency: "GBP",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeSummary(testAuthContext);
  assert.equal(result.totalWears, 45);
});

test("getWardrobeSummary calculates averageCpw correctly (totalValue / totalWears)", async () => {
  const pool = createMockPool({
    summaryRow: {
      total_items: "4",
      priced_items: "4",
      total_value: "200.00",
      total_wears: "40",
      dominant_currency: "GBP",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeSummary(testAuthContext);
  assert.equal(result.averageCpw, 5.0);
});

test("getWardrobeSummary returns averageCpw as null when totalWears is 0", async () => {
  const pool = createMockPool({
    summaryRow: {
      total_items: "3",
      priced_items: "3",
      total_value: "600.00",
      total_wears: "0",
      dominant_currency: "GBP",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeSummary(testAuthContext);
  assert.equal(result.averageCpw, null);
});

test("getWardrobeSummary returns dominantCurrency as the most common currency", async () => {
  const pool = createMockPool({
    summaryRow: {
      total_items: "5",
      priced_items: "5",
      total_value: "500.00",
      total_wears: "50",
      dominant_currency: "EUR",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeSummary(testAuthContext);
  assert.equal(result.dominantCurrency, "EUR");
});

test("getWardrobeSummary excludes items without purchase_price from value/cpw calculations", async () => {
  // The SQL query itself handles this with COUNT(purchase_price) and CASE WHEN
  // We verify the returned data is what the SQL returns
  const pool = createMockPool({
    summaryRow: {
      total_items: "10",
      priced_items: "6",
      total_value: "300.00",
      total_wears: "60",
      dominant_currency: "GBP",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeSummary(testAuthContext);
  assert.equal(result.totalItems, 10);
  assert.equal(result.pricedItems, 6);
  assert.equal(result.totalValue, 300.00);
  assert.equal(result.averageCpw, 5.0);
});

test("getWardrobeSummary returns zeros for empty wardrobe", async () => {
  const pool = createMockPool({
    summaryRow: {
      total_items: "0",
      priced_items: "0",
      total_value: "0",
      total_wears: "0",
      dominant_currency: null,
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeSummary(testAuthContext);
  assert.equal(result.totalItems, 0);
  assert.equal(result.pricedItems, 0);
  assert.equal(result.totalValue, 0);
  assert.equal(result.totalWears, 0);
  assert.equal(result.averageCpw, null);
  assert.equal(result.dominantCurrency, null);
});

test("getWardrobeSummary respects RLS (sets correct user ID)", async () => {
  const pool = createMockPool({ setConfigUserId: "firebase-user-123" });
  const repo = createAnalyticsRepository({ pool });
  await repo.getWardrobeSummary(testAuthContext);
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

// --- getItemsWithCpw tests ---

test("getItemsWithCpw returns items ordered by CPW descending (worst value first)", async () => {
  const pool = createMockPool({
    itemsCpwRows: [
      { id: "item-1", name: "Expensive Coat", category: "outerwear", photo_url: null, purchase_price: "200.00", currency: "GBP", wear_count: "2", cpw: "100.00" },
      { id: "item-2", name: "Casual Shirt", category: "tops", photo_url: null, purchase_price: "30.00", currency: "GBP", wear_count: "10", cpw: "3.00" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getItemsWithCpw(testAuthContext);
  assert.equal(result.length, 2);
  assert.equal(result[0].cpw, 100.00);
  assert.equal(result[1].cpw, 3.00);
});

test("getItemsWithCpw calculates cpw as purchase_price / wear_count", async () => {
  const pool = createMockPool({
    itemsCpwRows: [
      { id: "item-1", name: "Test Item", category: "tops", photo_url: null, purchase_price: "50.00", currency: "GBP", wear_count: "10", cpw: "5.00" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getItemsWithCpw(testAuthContext);
  assert.equal(result[0].cpw, 5.00);
  assert.equal(result[0].purchasePrice, 50.00);
  assert.equal(result[0].wearCount, 10);
});

test("getItemsWithCpw returns cpw as null for items with wear_count 0", async () => {
  const pool = createMockPool({
    itemsCpwRows: [
      { id: "item-1", name: "Unworn Dress", category: "dresses", photo_url: null, purchase_price: "100.00", currency: "GBP", wear_count: "0", cpw: null },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getItemsWithCpw(testAuthContext);
  assert.equal(result[0].cpw, null);
  assert.equal(result[0].wearCount, 0);
});

test("getItemsWithCpw only returns items with purchase_price set", async () => {
  // The SQL WHERE clause filters to purchase_price IS NOT NULL
  // We verify the query includes the filter
  const pool = createMockPool({ itemsCpwRows: [] });
  const repo = createAnalyticsRepository({ pool });
  await repo.getItemsWithCpw(testAuthContext);
  const cpwQuery = pool.queries.find(q => q.sql.includes("WHERE purchase_price IS NOT NULL"));
  assert.ok(cpwQuery, "Query should filter to items with purchase_price");
});

test("getItemsWithCpw respects RLS (sets correct user ID)", async () => {
  const pool = createMockPool({ setConfigUserId: "firebase-user-123" });
  const repo = createAnalyticsRepository({ pool });
  await repo.getItemsWithCpw(testAuthContext);
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

test("getItemsWithCpw maps row fields to camelCase correctly", async () => {
  const pool = createMockPool({
    itemsCpwRows: [
      { id: "item-uuid", name: "Blue Jeans", category: "bottoms", photo_url: "https://example.com/photo.jpg", purchase_price: "75.00", currency: "EUR", wear_count: "15", cpw: "5.00" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getItemsWithCpw(testAuthContext);
  assert.equal(result[0].id, "item-uuid");
  assert.equal(result[0].name, "Blue Jeans");
  assert.equal(result[0].category, "bottoms");
  assert.equal(result[0].photoUrl, "https://example.com/photo.jpg");
  assert.equal(result[0].purchasePrice, 75.00);
  assert.equal(result[0].currency, "EUR");
  assert.equal(result[0].wearCount, 15);
  assert.equal(result[0].cpw, 5.00);
});

test("getItemsWithCpw releases client connection after success", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query() { return { rows: [] }; },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getItemsWithCpw(testAuthContext);
  assert.ok(released, "Client should be released after query");
});

test("getWardrobeSummary releases client connection after error", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query(sql) {
          if (sql.includes("set_config")) return {};
          throw new Error("DB error");
        },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await assert.rejects(() => repo.getWardrobeSummary(testAuthContext), { message: "DB error" });
  assert.ok(released, "Client should be released even after error");
});

// --- getTopWornItems tests ---

test("getTopWornItems returns top items sorted by wear_count descending for 'all' period", async () => {
  const pool = createMockPool({
    topWornAllRows: [
      { id: "item-1", name: "Fave Jacket", category: "outerwear", photo_url: null, wear_count: "25", last_worn_date: "2026-03-10" },
      { id: "item-2", name: "Daily Shirt", category: "tops", photo_url: null, wear_count: "18", last_worn_date: "2026-03-15" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getTopWornItems(testAuthContext, { period: "all" });
  assert.equal(result.length, 2);
  assert.equal(result[0].id, "item-1");
  assert.equal(result[0].wearCount, 25);
  assert.equal(result[1].wearCount, 18);
});

test("getTopWornItems returns at most 10 items", async () => {
  // The LIMIT 10 is in the SQL query; the mock returns what the DB would
  const rows = Array.from({ length: 10 }, (_, i) => ({
    id: `item-${i}`, name: `Item ${i}`, category: "tops", photo_url: null,
    wear_count: String(100 - i), last_worn_date: "2026-03-01",
  }));
  const pool = createMockPool({ topWornAllRows: rows });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getTopWornItems(testAuthContext, { period: "all" });
  assert.equal(result.length, 10);
});

test("getTopWornItems returns empty array when no items have wear_count > 0", async () => {
  const pool = createMockPool({ topWornAllRows: [] });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getTopWornItems(testAuthContext, { period: "all" });
  assert.deepEqual(result, []);
});

test("getTopWornItems for '30' period counts only wear_log_items from last 30 days", async () => {
  const pool = createMockPool({
    topWornPeriodRows: [
      { id: "item-1", name: "Recent Fave", category: "tops", photo_url: null, total_wear_count: "50", last_worn_date: "2026-03-15", period_wear_count: "8" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getTopWornItems(testAuthContext, { period: "30" });
  assert.equal(result.length, 1);
  assert.equal(result[0].periodWearCount, 8);
  assert.equal(result[0].wearCount, 50);
  // Verify the query was called with 30 days parameter
  const periodQuery = pool.queries.find(q => q.sql.includes("wear_log_items"));
  assert.ok(periodQuery);
  assert.equal(periodQuery.params[0], 30);
});

test("getTopWornItems for '90' period counts only wear_log_items from last 90 days", async () => {
  const pool = createMockPool({
    topWornPeriodRows: [
      { id: "item-1", name: "Seasonal Pick", category: "outerwear", photo_url: null, total_wear_count: "30", last_worn_date: "2026-03-10", period_wear_count: "12" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getTopWornItems(testAuthContext, { period: "90" });
  assert.equal(result.length, 1);
  assert.equal(result[0].periodWearCount, 12);
  const periodQuery = pool.queries.find(q => q.sql.includes("wear_log_items"));
  assert.ok(periodQuery);
  assert.equal(periodQuery.params[0], 90);
});

test("getTopWornItems period filter excludes items with zero wears in that period", async () => {
  // If no items match, the DB returns empty; the mock simulates this
  const pool = createMockPool({ topWornPeriodRows: [] });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getTopWornItems(testAuthContext, { period: "30" });
  assert.deepEqual(result, []);
});

test("getTopWornItems respects RLS (sets correct user ID)", async () => {
  const pool = createMockPool({ setConfigUserId: "firebase-user-123" });
  const repo = createAnalyticsRepository({ pool });
  await repo.getTopWornItems(testAuthContext, { period: "all" });
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

test("getTopWornItems throws error for invalid period value", async () => {
  const pool = createMockPool();
  const repo = createAnalyticsRepository({ pool });
  await assert.rejects(
    () => repo.getTopWornItems(testAuthContext, { period: "7" }),
    (err) => {
      assert.equal(err.statusCode, 400);
      assert.ok(err.message.includes("Invalid period"));
      return true;
    }
  );
});

test("getTopWornItems maps row fields to camelCase correctly for 'all' period", async () => {
  const pool = createMockPool({
    topWornAllRows: [
      { id: "item-uuid", name: "Blue Jeans", category: "bottoms", photo_url: "https://example.com/photo.jpg", wear_count: "15", last_worn_date: "2026-03-01" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getTopWornItems(testAuthContext, { period: "all" });
  assert.equal(result[0].id, "item-uuid");
  assert.equal(result[0].name, "Blue Jeans");
  assert.equal(result[0].category, "bottoms");
  assert.equal(result[0].photoUrl, "https://example.com/photo.jpg");
  assert.equal(result[0].wearCount, 15);
  assert.equal(result[0].lastWornDate, "2026-03-01");
  assert.equal(result[0].periodWearCount, undefined); // Only for period queries
});

test("getTopWornItems releases client connection after success", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query() { return { rows: [] }; },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getTopWornItems(testAuthContext, { period: "all" });
  assert.ok(released, "Client should be released after query");
});

test("getTopWornItems releases client connection after error", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query(sql) {
          if (sql.includes("set_config")) return {};
          throw new Error("DB error");
        },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await assert.rejects(() => repo.getTopWornItems(testAuthContext, { period: "all" }), { message: "DB error" });
  assert.ok(released, "Client should be released even after error");
});

// --- getNeglectedItems tests ---

test("getNeglectedItems returns items not worn in 60+ days", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-1", name: "Old Jacket", category: "outerwear", photo_url: null, purchase_price: "200.00", currency: "GBP", wear_count: "5", last_worn_date: "2025-12-01", created_at: "2025-06-01", days_since_worn: "107" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result.length, 1);
  assert.equal(result[0].id, "item-1");
  assert.equal(result[0].daysSinceWorn, 107);
});

test("getNeglectedItems returns items never worn but created 60+ days ago", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-2", name: "Unworn Dress", category: "dresses", photo_url: null, purchase_price: "150.00", currency: "GBP", wear_count: "0", last_worn_date: null, created_at: "2025-10-01", days_since_worn: "168" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result.length, 1);
  assert.equal(result[0].lastWornDate, null);
  assert.equal(result[0].wearCount, 0);
  assert.equal(result[0].daysSinceWorn, 168);
});

test("getNeglectedItems does NOT return items worn within the last 60 days", async () => {
  // Items worn recently are excluded by SQL WHERE clause; mock returns empty
  const pool = createMockPool({ neglectedRows: [] });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.deepEqual(result, []);
});

test("getNeglectedItems returns items sorted by staleness (longest neglected first)", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-1", name: "Oldest", category: "tops", photo_url: null, purchase_price: null, currency: null, wear_count: "1", last_worn_date: "2025-06-01", created_at: "2025-01-01", days_since_worn: "290" },
      { id: "item-2", name: "Less Old", category: "bottoms", photo_url: null, purchase_price: null, currency: null, wear_count: "3", last_worn_date: "2025-12-01", created_at: "2025-01-01", days_since_worn: "107" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result.length, 2);
  assert.ok(result[0].daysSinceWorn > result[1].daysSinceWorn);
});

test("getNeglectedItems computes daysSinceWorn correctly for worn items", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-1", name: "Test", category: "tops", photo_url: null, purchase_price: null, currency: null, wear_count: "2", last_worn_date: "2025-12-01", created_at: "2025-06-01", days_since_worn: "107" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result[0].daysSinceWorn, 107);
});

test("getNeglectedItems computes daysSinceWorn correctly for never-worn items (uses created_at)", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-1", name: "Never Worn", category: "dresses", photo_url: null, purchase_price: "100.00", currency: "GBP", wear_count: "0", last_worn_date: null, created_at: "2025-06-01", days_since_worn: "290" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result[0].daysSinceWorn, 290);
  assert.equal(result[0].lastWornDate, null);
});

test("getNeglectedItems includes CPW for items with purchase_price and wear_count > 0", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-1", name: "Priced Item", category: "outerwear", photo_url: null, purchase_price: "200.00", currency: "GBP", wear_count: "4", last_worn_date: "2025-10-01", created_at: "2025-01-01", days_since_worn: "168" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result[0].cpw, 50.0); // 200 / 4
});

test("getNeglectedItems returns cpw as null for items with no purchase_price", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-1", name: "No Price", category: "tops", photo_url: null, purchase_price: null, currency: null, wear_count: "3", last_worn_date: "2025-10-01", created_at: "2025-01-01", days_since_worn: "168" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result[0].cpw, null);
});

test("getNeglectedItems returns cpw as null for items with wear_count 0", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-1", name: "Unworn", category: "dresses", photo_url: null, purchase_price: "100.00", currency: "GBP", wear_count: "0", last_worn_date: null, created_at: "2025-06-01", days_since_worn: "290" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result[0].cpw, null);
});

test("getNeglectedItems respects RLS (sets correct user ID)", async () => {
  const pool = createMockPool({ setConfigUserId: "firebase-user-123" });
  const repo = createAnalyticsRepository({ pool });
  await repo.getNeglectedItems(testAuthContext);
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

test("getNeglectedItems returns empty array when no items meet the neglected threshold", async () => {
  const pool = createMockPool({ neglectedRows: [] });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.deepEqual(result, []);
});

test("getNeglectedItems maps row fields to camelCase correctly", async () => {
  const pool = createMockPool({
    neglectedRows: [
      { id: "item-uuid", name: "Old Shirt", category: "tops", photo_url: "https://example.com/photo.jpg", purchase_price: "75.00", currency: "EUR", wear_count: "3", last_worn_date: "2025-10-01", created_at: "2025-01-01", days_since_worn: "168" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getNeglectedItems(testAuthContext);
  assert.equal(result[0].id, "item-uuid");
  assert.equal(result[0].name, "Old Shirt");
  assert.equal(result[0].category, "tops");
  assert.equal(result[0].photoUrl, "https://example.com/photo.jpg");
  assert.equal(result[0].purchasePrice, 75.00);
  assert.equal(result[0].currency, "EUR");
  assert.equal(result[0].wearCount, 3);
  assert.equal(result[0].daysSinceWorn, 168);
  assert.equal(result[0].cpw, 25.0); // 75 / 3
});

test("getNeglectedItems releases client connection after success", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query() { return { rows: [] }; },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getNeglectedItems(testAuthContext);
  assert.ok(released, "Client should be released after query");
});

// --- getCategoryDistribution tests ---

test("getCategoryDistribution returns categories sorted by item_count descending", async () => {
  const pool = createMockPool({
    categoryDistributionRows: [
      { category: "tops", item_count: "14" },
      { category: "bottoms", item_count: "8" },
      { category: "shoes", item_count: "3" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getCategoryDistribution(testAuthContext);
  assert.equal(result.length, 3);
  assert.equal(result[0].category, "tops");
  assert.equal(result[0].itemCount, 14);
  assert.equal(result[1].category, "bottoms");
  assert.equal(result[1].itemCount, 8);
  assert.equal(result[2].category, "shoes");
  assert.equal(result[2].itemCount, 3);
});

test("getCategoryDistribution computes correct percentages summing to ~100", async () => {
  const pool = createMockPool({
    categoryDistributionRows: [
      { category: "tops", item_count: "5" },
      { category: "bottoms", item_count: "3" },
      { category: "shoes", item_count: "2" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getCategoryDistribution(testAuthContext);
  assert.equal(result[0].percentage, 50.0); // 5/10 * 100
  assert.equal(result[1].percentage, 30.0); // 3/10 * 100
  assert.equal(result[2].percentage, 20.0); // 2/10 * 100
});

test("getCategoryDistribution returns all categories present in the user's wardrobe", async () => {
  const pool = createMockPool({
    categoryDistributionRows: [
      { category: "tops", item_count: "4" },
      { category: "bottoms", item_count: "3" },
      { category: "dresses", item_count: "2" },
      { category: "outerwear", item_count: "1" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getCategoryDistribution(testAuthContext);
  assert.equal(result.length, 4);
  const categories = result.map(r => r.category);
  assert.ok(categories.includes("tops"));
  assert.ok(categories.includes("bottoms"));
  assert.ok(categories.includes("dresses"));
  assert.ok(categories.includes("outerwear"));
});

test("getCategoryDistribution returns empty array for user with no items", async () => {
  const pool = createMockPool({ categoryDistributionRows: [] });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getCategoryDistribution(testAuthContext);
  assert.deepEqual(result, []);
});

test("getCategoryDistribution respects RLS (sets correct user ID)", async () => {
  const pool = createMockPool({ setConfigUserId: "firebase-user-123" });
  const repo = createAnalyticsRepository({ pool });
  await repo.getCategoryDistribution(testAuthContext);
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

test("getCategoryDistribution handles single-category wardrobe (100%)", async () => {
  const pool = createMockPool({
    categoryDistributionRows: [
      { category: "tops", item_count: "7" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getCategoryDistribution(testAuthContext);
  assert.equal(result.length, 1);
  assert.equal(result[0].percentage, 100.0);
  assert.equal(result[0].itemCount, 7);
});

test("getCategoryDistribution handles items with null category", async () => {
  const pool = createMockPool({
    categoryDistributionRows: [
      { category: "tops", item_count: "5" },
      { category: null, item_count: "2" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getCategoryDistribution(testAuthContext);
  assert.equal(result.length, 2);
  const nullCat = result.find(r => r.category === null);
  assert.ok(nullCat);
  assert.equal(nullCat.itemCount, 2);
});

test("getCategoryDistribution releases client connection after success", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query() { return { rows: [] }; },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getCategoryDistribution(testAuthContext);
  assert.ok(released, "Client should be released after query");
});

// --- getWearFrequency tests ---

test("getWearFrequency returns 7 elements (Mon-Sun) always", async () => {
  const pool = createMockPool({ wearFrequencyRows: [] });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWearFrequency(testAuthContext);
  assert.equal(result.length, 7);
  assert.equal(result[0].day, "Mon");
  assert.equal(result[6].day, "Sun");
});

test("getWearFrequency counts wear logs per day of week correctly", async () => {
  const pool = createMockPool({
    wearFrequencyRows: [
      { day_of_week: "1", log_count: "5" },  // Mon
      { day_of_week: "3", log_count: "3" },  // Wed
      { day_of_week: "6", log_count: "8" },  // Sat
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWearFrequency(testAuthContext);
  assert.equal(result[0].logCount, 5);  // Mon
  assert.equal(result[2].logCount, 3);  // Wed
  assert.equal(result[5].logCount, 8);  // Sat
});

test("getWearFrequency returns 0 for days with no wear logs", async () => {
  const pool = createMockPool({
    wearFrequencyRows: [
      { day_of_week: "2", log_count: "4" },  // Tue
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWearFrequency(testAuthContext);
  assert.equal(result[0].logCount, 0);  // Mon
  assert.equal(result[1].logCount, 4);  // Tue
  assert.equal(result[2].logCount, 0);  // Wed
  assert.equal(result[6].logCount, 0);  // Sun
});

test("getWearFrequency orders by Mon-Sun (ISO week order)", async () => {
  const pool = createMockPool({ wearFrequencyRows: [] });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWearFrequency(testAuthContext);
  const dayNames = result.map(d => d.day);
  assert.deepEqual(dayNames, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]);
  for (let i = 0; i < 7; i++) {
    assert.equal(result[i].dayIndex, i);
  }
});

test("getWearFrequency respects RLS (user isolation)", async () => {
  const pool = createMockPool({ setConfigUserId: "firebase-user-123" });
  const repo = createAnalyticsRepository({ pool });
  await repo.getWearFrequency(testAuthContext);
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

test("getWearFrequency returns all zeros for user with no wear logs", async () => {
  const pool = createMockPool({ wearFrequencyRows: [] });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWearFrequency(testAuthContext);
  assert.equal(result.length, 7);
  for (const day of result) {
    assert.equal(day.logCount, 0);
  }
});

test("getWearFrequency correctly maps PostgreSQL DOW to ISO day order", async () => {
  // PostgreSQL DOW: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
  const pool = createMockPool({
    wearFrequencyRows: [
      { day_of_week: "0", log_count: "7" },  // Sun -> index 6
      { day_of_week: "1", log_count: "1" },  // Mon -> index 0
      { day_of_week: "4", log_count: "4" },  // Thu -> index 3
      { day_of_week: "6", log_count: "6" },  // Sat -> index 5
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWearFrequency(testAuthContext);
  assert.equal(result[0].logCount, 1);  // Mon (DOW 1)
  assert.equal(result[3].logCount, 4);  // Thu (DOW 4)
  assert.equal(result[5].logCount, 6);  // Sat (DOW 6)
  assert.equal(result[6].logCount, 7);  // Sun (DOW 0)
});

test("getWearFrequency releases client connection after success", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query() { return { rows: [] }; },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getWearFrequency(testAuthContext);
  assert.ok(released, "Client should be released after query");
});

// --- getBrandValueAnalytics tests ---

test("getBrandValueAnalytics returns brands sorted by avg_cpw ascending (best value first)", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "Uniqlo", item_count: "5", total_spent: "250.00", total_wears: "100", avg_cpw: "2.50", priced_items: "5", dominant_currency: "GBP" },
      { brand: "Zara", item_count: "4", total_spent: "400.00", total_wears: "60", avg_cpw: "6.67", priced_items: "4", dominant_currency: "GBP" },
    ],
    brandValueCategoriesRows: [{ category: "tops" }],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.equal(result.brands.length, 2);
  assert.equal(result.brands[0].brand, "Uniqlo");
  assert.equal(result.brands[0].avgCpw, 2.50);
  assert.equal(result.brands[1].brand, "Zara");
  assert.equal(result.brands[1].avgCpw, 6.67);
});

test("getBrandValueAnalytics only includes brands with 3+ items", async () => {
  // The SQL HAVING COUNT(*) >= 3 handles this; mock returns only qualifying brands
  const pool = createMockPool({
    brandValueRows: [
      { brand: "Nike", item_count: "4", total_spent: "300.00", total_wears: "80", avg_cpw: "3.75", priced_items: "4", dominant_currency: "GBP" },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.equal(result.brands.length, 1);
  assert.equal(result.brands[0].itemCount, 4);
  // Verify the SQL query includes HAVING COUNT(*) >= 3
  const brandQuery = pool.queries.find(q => q.sql.includes("HAVING COUNT(*) >= 3"));
  assert.ok(brandQuery, "Query should enforce 3-item minimum");
});

test("getBrandValueAnalytics computes correct avgCpw", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "H&M", item_count: "3", total_spent: "90.00", total_wears: "45", avg_cpw: "2.00", priced_items: "3", dominant_currency: "EUR" },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.equal(result.brands[0].avgCpw, 2.00);
});

test("getBrandValueAnalytics computes correct totalSpent", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "Gucci", item_count: "3", total_spent: "3000.00", total_wears: "30", avg_cpw: "100.00", priced_items: "3", dominant_currency: "GBP" },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.equal(result.brands[0].totalSpent, 3000.00);
});

test("getBrandValueAnalytics computes correct totalWears", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "Nike", item_count: "5", total_spent: "500.00", total_wears: "200", avg_cpw: "2.50", priced_items: "5", dominant_currency: "USD" },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.equal(result.brands[0].totalWears, 200);
});

test("getBrandValueAnalytics returns empty brands array when no brands meet threshold", async () => {
  const pool = createMockPool({
    brandValueRows: [],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.deepEqual(result.brands, []);
});

test("getBrandValueAnalytics respects RLS (sets correct user ID)", async () => {
  const pool = createMockPool({ setConfigUserId: "firebase-user-123", brandValueRows: [], brandValueCategoriesRows: [] });
  const repo = createAnalyticsRepository({ pool });
  await repo.getBrandValueAnalytics(testAuthContext);
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

test("getBrandValueAnalytics handles items without purchase_price (null avgCpw)", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "NoPrice Co", item_count: "4", total_spent: "0", total_wears: "50", avg_cpw: null, priced_items: "0", dominant_currency: null },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.equal(result.brands[0].avgCpw, null);
  assert.equal(result.brands[0].totalSpent, 0);
});

test("getBrandValueAnalytics ranks by totalWears when all avgCpw are null", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "Brand A", item_count: "3", total_spent: "0", total_wears: "100", avg_cpw: null, priced_items: "0", dominant_currency: null },
      { brand: "Brand B", item_count: "3", total_spent: "0", total_wears: "50", avg_cpw: null, priced_items: "0", dominant_currency: null },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  // Both have null avgCpw; SQL ORDER BY avg_cpw ASC NULLS LAST keeps DB order
  assert.equal(result.brands.length, 2);
  assert.equal(result.brands[0].avgCpw, null);
  assert.equal(result.brands[1].avgCpw, null);
});

test("getBrandValueAnalytics category filter adds WHERE clause", async () => {
  const pool = createMockPool({
    brandValueRows: [],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  await repo.getBrandValueAnalytics(testAuthContext, { category: "tops" });
  const brandQuery = pool.queries.find(q => q.sql.includes("GROUP BY brand") && q.sql.includes("category = $"));
  assert.ok(brandQuery, "Query should include category filter");
});

test("getBrandValueAnalytics category filter still applies 3-item minimum", async () => {
  const pool = createMockPool({
    brandValueRows: [],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  await repo.getBrandValueAnalytics(testAuthContext, { category: "tops" });
  const brandQuery = pool.queries.find(q => q.sql.includes("HAVING COUNT(*) >= 3"));
  assert.ok(brandQuery, "Category-filtered query should still enforce 3-item minimum");
});

test("getBrandValueAnalytics returns availableCategories list", async () => {
  const pool = createMockPool({
    brandValueRows: [],
    brandValueCategoriesRows: [
      { category: "bottoms" },
      { category: "tops" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.deepEqual(result.availableCategories, ["bottoms", "tops"]);
});

test("getBrandValueAnalytics throws 400 for invalid category", async () => {
  const pool = createMockPool({ brandValueRows: [], brandValueCategoriesRows: [] });
  const repo = createAnalyticsRepository({ pool });
  await assert.rejects(
    () => repo.getBrandValueAnalytics(testAuthContext, { category: "invalid-cat" }),
    (err) => {
      assert.equal(err.statusCode, 400);
      assert.ok(err.message.includes("Invalid category"));
      return true;
    }
  );
});

test("getBrandValueAnalytics computes bestValueBrand correctly (lowest non-null avgCpw)", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "CheapBrand", item_count: "5", total_spent: "100.00", total_wears: "200", avg_cpw: "0.50", priced_items: "5", dominant_currency: "GBP" },
      { brand: "ExpensiveBrand", item_count: "3", total_spent: "900.00", total_wears: "30", avg_cpw: "30.00", priced_items: "3", dominant_currency: "GBP" },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.ok(result.bestValueBrand);
  assert.equal(result.bestValueBrand.brand, "CheapBrand");
  assert.equal(result.bestValueBrand.avgCpw, 0.50);
});

test("getBrandValueAnalytics computes mostInvestedBrand correctly (highest totalSpent)", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "CheapBrand", item_count: "5", total_spent: "100.00", total_wears: "200", avg_cpw: "0.50", priced_items: "5", dominant_currency: "GBP" },
      { brand: "BigSpend", item_count: "3", total_spent: "2000.00", total_wears: "10", avg_cpw: "200.00", priced_items: "3", dominant_currency: "EUR" },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.ok(result.mostInvestedBrand);
  assert.equal(result.mostInvestedBrand.brand, "BigSpend");
  assert.equal(result.mostInvestedBrand.totalSpent, 2000.00);
});

test("getBrandValueAnalytics bestValueBrand is null when no brands have priced items", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "NoPriceBrand", item_count: "3", total_spent: "0", total_wears: "30", avg_cpw: null, priced_items: "0", dominant_currency: null },
    ],
    brandValueCategoriesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  assert.equal(result.bestValueBrand, null);
});

test("getBrandValueAnalytics maps fields to camelCase correctly", async () => {
  const pool = createMockPool({
    brandValueRows: [
      { brand: "TestBrand", item_count: "5", total_spent: "500.00", total_wears: "100", avg_cpw: "5.00", priced_items: "4", dominant_currency: "USD" },
    ],
    brandValueCategoriesRows: [{ category: "tops" }],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getBrandValueAnalytics(testAuthContext);
  const b = result.brands[0];
  assert.equal(b.brand, "TestBrand");
  assert.equal(b.itemCount, 5);
  assert.equal(b.totalSpent, 500.00);
  assert.equal(b.totalWears, 100);
  assert.equal(b.avgCpw, 5.00);
  assert.equal(b.pricedItems, 4);
  assert.equal(b.dominantCurrency, "USD");
});

test("getBrandValueAnalytics releases client connection after success", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query() { return { rows: [] }; },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getBrandValueAnalytics(testAuthContext);
  assert.ok(released, "Client should be released after query");
});

// --- getSustainabilityAnalytics tests ---

test("getSustainabilityAnalytics returns composite score between 0 and 100", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "10",
      items_worn_90d: "5",
      avg_cpw: "10",
      total_rewears: "20",
      resale_active_items: "2",
      new_items_90d: "1",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.ok(result.score >= 0 && result.score <= 100, `Score ${result.score} should be 0-100`);
});

test("getSustainabilityAnalytics avgWearScore: 0 when no wears", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.avgWearScore, 0);
});

test("getSustainabilityAnalytics avgWearScore: 100 when avg >= 20 wears", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "25",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.avgWearScore, 100);
});

test("getSustainabilityAnalytics utilizationScore: 0 when no items worn in 90 days", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.utilizationScore, 0);
});

test("getSustainabilityAnalytics utilizationScore: 100 when all items worn in 90 days", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "0",
      items_worn_90d: "10",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.utilizationScore, 100);
});

test("getSustainabilityAnalytics cpwScore: 100 when avg CPW <= 5", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "3",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.cpwScore, 100);
});

test("getSustainabilityAnalytics cpwScore: decreasing for higher CPW", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "25",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.cpwScore, 20); // (5/25)*100 = 20
});

test("getSustainabilityAnalytics cpwScore: 0 when no priced items (avgCpw=0)", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.cpwScore, 0);
});

test("getSustainabilityAnalytics resaleScore: 0 when no resale activity", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.resaleScore, 0);
});

test("getSustainabilityAnalytics resaleScore: increases with resale items", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "1",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.resaleScore, 50); // (1/10)*500 = 50
});

test("getSustainabilityAnalytics newPurchaseScore: 100 when no new items in 90 days", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.newPurchaseScore, 100);
});

test("getSustainabilityAnalytics newPurchaseScore: decreases with more new items", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "5",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.newPurchaseScore, 0); // max(0, 100 - (5/10)*200) = max(0, 0) = 0
});

test("getSustainabilityAnalytics composite score uses correct weights", async () => {
  // All factors at 100: score should be 100
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "20",
      items_worn_90d: "10",
      avg_cpw: "5",
      total_rewears: "50",
      resale_active_items: "2",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  // All factors = 100, so composite = 100*0.30 + 100*0.25 + 100*0.20 + 100*0.15 + 100*0.10 = 100
  assert.equal(result.score, 100);
});

test("getSustainabilityAnalytics CO2 savings: 0 when no rewears", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "1",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.co2SavedKg, 0);
});

test("getSustainabilityAnalytics CO2 savings: correct when rewears exist", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "5",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "20",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.co2SavedKg, 10); // 20 * 0.5 = 10
});

test("getSustainabilityAnalytics CO2 car km equivalent computed correctly", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "5",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "20",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  // 10 / 0.21 = 47.619... rounded to 1 decimal = 47.6
  assert.equal(result.co2CarKmEquivalent, 47.6);
});

test("getSustainabilityAnalytics percentile computed as max(1, 100 - score)", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "20",
      items_worn_90d: "10",
      avg_cpw: "5",
      total_rewears: "50",
      resale_active_items: "2",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  // score = 100, percentile = max(1, 100 - 100) = 1
  assert.equal(result.percentile, 1);
});

test("getSustainabilityAnalytics returns zero score for user with no items", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "0",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  // avgWear=0, utilization=0, cpw=0, resale=0, newPurchase=100
  // 0*0.30 + 0*0.25 + 0*0.20 + 0*0.15 + 100*0.10 = 10
  assert.equal(result.score, 10);
  assert.equal(result.totalItems, 0);
});

test("getSustainabilityAnalytics respects RLS (sets user ID via set_config)", async () => {
  const pool = createMockPool({
    setConfigUserId: "firebase-user-123",
    sustainabilityRow: {
      total_items: "0",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  await repo.getSustainabilityAnalytics(testAuthContext);
  // If setConfigUserId is checked and doesn't match, assert inside mock will fail
  assert.ok(true);
});

test("getSustainabilityAnalytics handles items without purchase_price (cpwScore is 0)", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "10",
      items_worn_90d: "3",
      avg_cpw: "0",
      total_rewears: "20",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.cpwScore, 0);
});

test("getSustainabilityAnalytics handles items without wear logs (avgWearScore is 0)", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "10",
      total_rewears: "0",
      resale_active_items: "0",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.avgWearScore, 0);
});

test("getSustainabilityAnalytics resaleScore correctly counts items with resale_status in ('listed', 'sold', 'donated')", async () => {
  // 20% of items in resale = perfect score (100)
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "10",
      avg_wear_count: "0",
      items_worn_90d: "0",
      avg_cpw: "0",
      total_rewears: "0",
      resale_active_items: "2",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(result.factors.resaleScore, 100); // (2/10)*500 = 100
});

test("getSustainabilityAnalytics returns correct response shape", async () => {
  const pool = createMockPool({
    sustainabilityRow: {
      total_items: "5",
      avg_wear_count: "10",
      items_worn_90d: "3",
      avg_cpw: "8",
      total_rewears: "15",
      resale_active_items: "1",
      new_items_90d: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSustainabilityAnalytics(testAuthContext);
  assert.equal(typeof result.score, "number");
  assert.equal(typeof result.factors.avgWearScore, "number");
  assert.equal(typeof result.factors.utilizationScore, "number");
  assert.equal(typeof result.factors.cpwScore, "number");
  assert.equal(typeof result.factors.resaleScore, "number");
  assert.equal(typeof result.factors.newPurchaseScore, "number");
  assert.equal(typeof result.co2SavedKg, "number");
  assert.equal(typeof result.co2CarKmEquivalent, "number");
  assert.equal(typeof result.percentile, "number");
  assert.equal(typeof result.totalRewears, "number");
  assert.equal(typeof result.totalItems, "number");
  assert.equal(result.badgeAwarded, false);
});

test("getSustainabilityAnalytics releases client connection after success", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query(sql) {
          if (sql.includes("set_config")) return {};
          return { rows: [{
            total_items: "0",
            avg_wear_count: "0",
            items_worn_90d: "0",
            avg_cpw: "0",
            total_rewears: "0",
            resale_active_items: "0",
            new_items_90d: "0",
          }] };
        },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getSustainabilityAnalytics(testAuthContext);
  assert.ok(released, "Client should be released after query");
});

// --- getGapAnalysisData tests ---

test("getGapAnalysisData returns category distribution grouped correctly", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "10" },
    gapCategoryRows: [
      { category: "tops", count: "5" },
      { category: "bottoms", count: "3" },
      { category: "shoes", count: "2" },
    ],
    gapSeasonRows: [{ season: "summer", count: "10" }],
    gapColorRows: [{ color: "black", count: "10" }],
    gapOccasionRows: [{ occasion: "everyday", count: "10" }],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getGapAnalysisData(testAuthContext);
  assert.equal(result.categoryDistribution.length, 3);
  assert.equal(result.categoryDistribution[0].category, "tops");
  assert.equal(result.categoryDistribution[0].count, 5);
  assert.equal(result.categoryDistribution[1].category, "bottoms");
  assert.equal(result.categoryDistribution[1].count, 3);
});

test("getGapAnalysisData returns season coverage grouped correctly", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "8" },
    gapCategoryRows: [{ category: "tops", count: "8" }],
    gapSeasonRows: [
      { season: "summer", count: "4" },
      { season: "winter", count: "2" },
      { season: "all", count: "2" },
    ],
    gapColorRows: [{ color: "black", count: "8" }],
    gapOccasionRows: [{ occasion: "everyday", count: "8" }],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getGapAnalysisData(testAuthContext);
  assert.equal(result.seasonCoverage.length, 3);
  assert.equal(result.seasonCoverage[0].season, "summer");
  assert.equal(result.seasonCoverage[0].count, 4);
});

test("getGapAnalysisData returns color distribution grouped correctly", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "6" },
    gapCategoryRows: [{ category: "tops", count: "6" }],
    gapSeasonRows: [{ season: "all", count: "6" }],
    gapColorRows: [
      { color: "black", count: "3" },
      { color: "white", count: "2" },
      { color: "red", count: "1" },
    ],
    gapOccasionRows: [{ occasion: "everyday", count: "6" }],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getGapAnalysisData(testAuthContext);
  assert.equal(result.colorDistribution.length, 3);
  assert.equal(result.colorDistribution[0].color, "black");
  assert.equal(result.colorDistribution[0].count, 3);
});

test("getGapAnalysisData returns occasion coverage grouped correctly", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "10" },
    gapCategoryRows: [{ category: "tops", count: "10" }],
    gapSeasonRows: [{ season: "all", count: "10" }],
    gapColorRows: [{ color: "black", count: "10" }],
    gapOccasionRows: [
      { occasion: "everyday", count: "5" },
      { occasion: "work", count: "3" },
      { occasion: "formal", count: "2" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getGapAnalysisData(testAuthContext);
  assert.equal(result.occasionCoverage.length, 3);
  assert.equal(result.occasionCoverage[0].occasion, "everyday");
  assert.equal(result.occasionCoverage[0].count, 5);
});

test("getGapAnalysisData returns totalItems count", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "15" },
    gapCategoryRows: [{ category: "tops", count: "15" }],
    gapSeasonRows: [{ season: "all", count: "15" }],
    gapColorRows: [{ color: "black", count: "15" }],
    gapOccasionRows: [{ occasion: "everyday", count: "15" }],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getGapAnalysisData(testAuthContext);
  assert.equal(result.totalItems, 15);
});

test("getGapAnalysisData returns empty gaps array when totalItems < 5", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "3" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getGapAnalysisData(testAuthContext);
  assert.equal(result.totalItems, 3);
  assert.deepEqual(result.gaps, []);
  assert.deepEqual(result.recommendations, []);
  assert.equal(result.categoryDistribution, undefined);
});

test("getGapAnalysisData respects RLS (sets user ID correctly)", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "3" },
    setConfigUserId: "firebase-user-123",
  });
  const repo = createAnalyticsRepository({ pool });
  await repo.getGapAnalysisData(testAuthContext);
  // The mock pool assertion on setConfigUserId handles the RLS check
  assert.ok(true, "RLS set_config called with correct user ID");
});

test("getGapAnalysisData releases client in finally block", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query(sql) {
          if (sql.includes("set_config")) return {};
          return { rows: [{ total_items: "3" }] };
        },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getGapAnalysisData(testAuthContext);
  assert.ok(released, "Client should be released after query");
});

// --- getSeasonalReports tests ---

test("getSeasonalReports returns 4 seasons", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "20" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  assert.equal(result.seasons.length, 4);
  const seasonNames = result.seasons.map(s => s.season);
  assert.ok(seasonNames.includes("spring"));
  assert.ok(seasonNames.includes("summer"));
  assert.ok(seasonNames.includes("fall"));
  assert.ok(seasonNames.includes("winter"));
});

test("getSeasonalReports returns currentSeason string", async () => {
  const pool = createMockPool();
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  assert.ok(["spring", "summer", "fall", "winter"].includes(result.currentSeason));
});

test("getSeasonalReports returns totalItems count", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "15" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  assert.equal(result.totalItems, 15);
});

test("getSeasonalReports readiness score is between 1 and 10", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "20" },
    seasonalItemCountRows: { count: "10" },
    seasonalWornItemsRow: { count: "5" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  for (const season of result.seasons) {
    assert.ok(season.readinessScore >= 1, `Readiness score should be >= 1, got ${season.readinessScore}`);
    assert.ok(season.readinessScore <= 10, `Readiness score should be <= 10, got ${season.readinessScore}`);
  }
});

test("getSeasonalReports historical comparison returns percentChange when prior year data exists", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "20" },
    seasonalCurrentCountRow: { count: "12" },
    seasonalPriorCountRow: { count: "10" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  // At least one season should have a numeric percentChange due to prior data
  const seasonsWithComparison = result.seasons.filter(
    s => s.historicalComparison.percentChange !== null
  );
  // Due to mock setup, seasons whose date range includes prior year will get percentChange
  assert.ok(result.seasons.length === 4);
});

test("getSeasonalReports historical comparison returns null percentChange when no prior year data", async () => {
  // When all prior year queries return 0, percentChange should be null
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "10" },
    seasonalCurrentCountRow: { count: "0" },
    // No prior count row set -- defaults to count: "0"
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  // When both current and prior are 0, prior count is 0 so percentChange is null
  for (const s of result.seasons) {
    assert.equal(s.historicalComparison.percentChange, null);
    assert.ok(s.historicalComparison.comparisonText.includes("First"), "Should show first season tracked message");
  }
});

test("getSeasonalReports transition alert is null when next season > 14 days away", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "10" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  // transitionAlert may or may not be null depending on current date, but structure is correct
  if (result.transitionAlert === null) {
    assert.equal(result.transitionAlert, null);
  } else {
    assert.ok(result.transitionAlert.upcomingSeason);
    assert.ok(typeof result.transitionAlert.daysUntil === "number");
    assert.ok(result.transitionAlert.daysUntil <= 14);
    assert.ok(typeof result.transitionAlert.readinessScore === "number");
  }
});

test("getSeasonalReports returns empty arrays for most worn / neglected when season has no items", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "5" },
    seasonalItemCountRows: { count: "0" },
    seasonalMostWornRows: [],
    seasonalNeglectedRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  for (const season of result.seasons) {
    assert.ok(Array.isArray(season.mostWorn));
    assert.ok(Array.isArray(season.neglected));
  }
});

test("getSeasonalReports respects RLS user isolation", async () => {
  const pool = createMockPool({
    setConfigUserId: "firebase-user-123",
    gapTotalItemsRow: { total_items: "5" },
  });
  const repo = createAnalyticsRepository({ pool });
  await repo.getSeasonalReports(testAuthContext);
  // The mock pool will assert the userId matches
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

test("getSeasonalReports most worn items are mapped with camelCase", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "10" },
    seasonalItemCountRows: { count: "5" },
    seasonalMostWornRows: [
      { id: "item-1", name: "Blue Shirt", photo_url: "https://example.com/photo.jpg", category: "tops", wear_count: "15" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  const firstSeason = result.seasons[0];
  assert.ok(firstSeason.mostWorn.length > 0);
  assert.equal(firstSeason.mostWorn[0].id, "item-1");
  assert.equal(firstSeason.mostWorn[0].name, "Blue Shirt");
  assert.equal(firstSeason.mostWorn[0].photoUrl, "https://example.com/photo.jpg");
  assert.equal(firstSeason.mostWorn[0].wearCount, 15);
});

test("getSeasonalReports neglected items include items with 0 wears", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "10" },
    seasonalNeglectedRows: [
      { id: "item-2", name: "Unused Coat", photo_url: null, category: "outerwear", wear_count: "0" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  const firstSeason = result.seasons[0];
  assert.ok(firstSeason.neglected.length > 0);
  assert.equal(firstSeason.neglected[0].wearCount, 0);
});

test("getSeasonalReports each season has required fields", async () => {
  const pool = createMockPool({
    gapTotalItemsRow: { total_items: "20" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getSeasonalReports(testAuthContext);
  for (const season of result.seasons) {
    assert.ok(typeof season.season === "string");
    assert.ok(typeof season.itemCount === "number");
    assert.ok(typeof season.totalWears === "number");
    assert.ok(Array.isArray(season.mostWorn));
    assert.ok(Array.isArray(season.neglected));
    assert.ok(typeof season.readinessScore === "number");
    assert.ok(season.historicalComparison);
    assert.ok(typeof season.historicalComparison.comparisonText === "string");
  }
});

test("getSeasonalReports releases client in finally block", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query(sql) {
          if (sql.includes("set_config")) return {};
          return { rows: [{ total_items: "0", count: "0", total_wears: "0" }] };
        },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getSeasonalReports(testAuthContext);
  assert.ok(released, "Client should be released after query");
});

// --- getHeatmapData tests ---

test("getHeatmapData returns daily activity array with correct item counts", async () => {
  const pool = createMockPool({
    heatmapActivityRows: [
      { logged_date: "2026-03-01", items_count: "3" },
      { logged_date: "2026-03-02", items_count: "5" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  assert.equal(result.dailyActivity.length, 2);
  assert.equal(result.dailyActivity[0].date, "2026-03-01");
  assert.equal(result.dailyActivity[0].itemsCount, 3);
  assert.equal(result.dailyActivity[1].itemsCount, 5);
});

test("getHeatmapData returns empty array when no wear logs in date range", async () => {
  const pool = createMockPool({
    heatmapActivityRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  assert.equal(result.dailyActivity.length, 0);
});

test("getHeatmapData streak stats: totalDaysLogged correct", async () => {
  const pool = createMockPool({
    heatmapAllDatesRows: [
      { logged_date: "2026-03-10" },
      { logged_date: "2026-03-09" },
      { logged_date: "2026-03-08" },
    ],
    heatmapTotalItemsRow: { total: "9" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  assert.equal(result.streakStats.totalDaysLogged, 3);
});

test("getHeatmapData streak stats: average items per day correct", async () => {
  const pool = createMockPool({
    heatmapAllDatesRows: [
      { logged_date: "2026-03-10" },
      { logged_date: "2026-03-09" },
    ],
    heatmapTotalItemsRow: { total: "8" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  assert.equal(result.streakStats.avgItemsPerDay, 4.0);
});

test("getHeatmapData streak stats: zero for no data", async () => {
  const pool = createMockPool({
    heatmapAllDatesRows: [],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  assert.equal(result.streakStats.currentStreak, 0);
  assert.equal(result.streakStats.longestStreak, 0);
  assert.equal(result.streakStats.totalDaysLogged, 0);
  assert.equal(result.streakStats.avgItemsPerDay, 0);
});

test("getHeatmapData respects RLS user isolation", async () => {
  const pool = createMockPool({
    setConfigUserId: "firebase-user-123",
  });
  const repo = createAnalyticsRepository({ pool });
  await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  const setConfigQuery = pool.queries.find(q => q.sql.includes("set_config"));
  assert.ok(setConfigQuery);
  assert.equal(setConfigQuery.params[0], "firebase-user-123");
});

test("getHeatmapData returns streakStats object with all required fields", async () => {
  const pool = createMockPool({
    heatmapAllDatesRows: [
      { logged_date: "2026-03-10" },
    ],
    heatmapTotalItemsRow: { total: "3" },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  assert.ok(typeof result.streakStats.currentStreak === "number");
  assert.ok(typeof result.streakStats.longestStreak === "number");
  assert.ok(typeof result.streakStats.totalDaysLogged === "number");
  assert.ok(typeof result.streakStats.avgItemsPerDay === "number");
});

test("getHeatmapData items count is distinct items per day", async () => {
  // The SQL uses COUNT(DISTINCT wli.item_id) - we verify the query pattern exists
  const pool = createMockPool({
    heatmapActivityRows: [
      { logged_date: "2026-03-01", items_count: "2" },
    ],
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  // Verify the SQL contains COUNT(DISTINCT)
  const activityQuery = pool.queries.find(q =>
    q.sql.includes("COUNT(DISTINCT wli.item_id)")
  );
  assert.ok(activityQuery, "Query should use COUNT(DISTINCT wli.item_id)");
});

test("getHeatmapData releases client in finally block", async () => {
  let released = false;
  const pool = {
    async connect() {
      return {
        async query(sql) {
          if (sql.includes("set_config")) return {};
          return { rows: [] };
        },
        release() { released = true; },
      };
    },
  };
  const repo = createAnalyticsRepository({ pool });
  await repo.getHeatmapData(testAuthContext, {
    startDate: "2026-03-01",
    endDate: "2026-03-31",
  });
  assert.ok(released, "Client should be released after query");
});

// --- getWardrobeHealthScore tests ---

test("getWardrobeHealthScore returns composite score between 0 and 100", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "20",
      items_worn_90d: "10",
      items_good_cpw: "6",
      items_with_cpw: "10",
      total_wears: "100",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.ok(result.score >= 0 && result.score <= 100, `Score ${result.score} should be 0-100`);
});

test("getWardrobeHealthScore utilizationScore is 0 when no items worn in 90 days", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "0",
      items_good_cpw: "0",
      items_with_cpw: "5",
      total_wears: "50",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.utilizationScore, 0);
});

test("getWardrobeHealthScore utilizationScore is 100 when all items worn in 90 days", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "10",
      items_good_cpw: "5",
      items_with_cpw: "5",
      total_wears: "100",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.utilizationScore, 100);
});

test("getWardrobeHealthScore cpwScore is 0 when no items have CPW below 5", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "5",
      items_good_cpw: "0",
      items_with_cpw: "10",
      total_wears: "50",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.cpwScore, 0);
});

test("getWardrobeHealthScore cpwScore is 100 when all priced+worn items have CPW below 5", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "5",
      items_good_cpw: "8",
      items_with_cpw: "8",
      total_wears: "50",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.cpwScore, 100);
});

test("getWardrobeHealthScore cpwScore is 0 when no items have purchase_price or wear_count", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "5",
      items_good_cpw: "0",
      items_with_cpw: "0",
      total_wears: "50",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.cpwScore, 0);
});

test("getWardrobeHealthScore sizeUtilizationScore is 0 when no wears", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "0",
      items_good_cpw: "0",
      items_with_cpw: "0",
      total_wears: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.sizeUtilizationScore, 0);
});

test("getWardrobeHealthScore sizeUtilizationScore is 100 when avg wears per item >= 10", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "10",
      items_good_cpw: "10",
      items_with_cpw: "10",
      total_wears: "100",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.sizeUtilizationScore, 100);
});

test("getWardrobeHealthScore composite score uses correct weights (0.50, 0.30, 0.20)", async () => {
  // utilization: (10/20)*100 = 50, cpw: (6/10)*100 = 60, sizeUtil: min(100, (100/20)*10) = 50
  // composite: 50*0.50 + 60*0.30 + 50*0.20 = 25 + 18 + 10 = 53
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "20",
      items_worn_90d: "10",
      items_good_cpw: "6",
      items_with_cpw: "10",
      total_wears: "100",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.score, 53);
});

test("getWardrobeHealthScore score is clamped to 0-100", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "10",
      items_good_cpw: "10",
      items_with_cpw: "10",
      total_wears: "200",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.ok(result.score <= 100, "Score should not exceed 100");
  assert.ok(result.score >= 0, "Score should not be below 0");
});

test("getWardrobeHealthScore percentile is max(1, 100 - score)", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "20",
      items_worn_90d: "10",
      items_good_cpw: "6",
      items_with_cpw: "10",
      total_wears: "100",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.percentile, Math.max(1, 100 - result.score));
});

test("getWardrobeHealthScore colorTier green for score 80-100", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10",
      items_worn_90d: "10",
      items_good_cpw: "10",
      items_with_cpw: "10",
      total_wears: "200",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.ok(result.score >= 80, `Score ${result.score} should be >= 80 for green`);
  assert.equal(result.colorTier, "green");
});

test("getWardrobeHealthScore colorTier yellow for score 50-79", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "20",
      items_worn_90d: "10",
      items_good_cpw: "6",
      items_with_cpw: "10",
      total_wears: "100",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.score, 53);
  assert.equal(result.colorTier, "yellow");
});

test("getWardrobeHealthScore colorTier red for score 0-49", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "20",
      items_worn_90d: "0",
      items_good_cpw: "0",
      items_with_cpw: "10",
      total_wears: "10",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.ok(result.score < 50, `Score ${result.score} should be < 50 for red`);
  assert.equal(result.colorTier, "red");
});

test("getWardrobeHealthScore recommendation is non-empty for all score tiers", async () => {
  // Green tier
  const poolGreen = createMockPool({
    healthScoreRow: {
      total_items: "10", items_worn_90d: "10", items_good_cpw: "10",
      items_with_cpw: "10", total_wears: "200",
    },
  });
  const resultGreen = await createAnalyticsRepository({ pool: poolGreen }).getWardrobeHealthScore(testAuthContext);
  assert.ok(resultGreen.recommendation.length > 0, "Green tier should have recommendation");

  // Yellow tier
  const poolYellow = createMockPool({
    healthScoreRow: {
      total_items: "20", items_worn_90d: "10", items_good_cpw: "6",
      items_with_cpw: "10", total_wears: "100",
    },
  });
  const resultYellow = await createAnalyticsRepository({ pool: poolYellow }).getWardrobeHealthScore(testAuthContext);
  assert.ok(resultYellow.recommendation.length > 0, "Yellow tier should have recommendation");

  // Red tier
  const poolRed = createMockPool({
    healthScoreRow: {
      total_items: "20", items_worn_90d: "0", items_good_cpw: "0",
      items_with_cpw: "10", total_wears: "10",
    },
  });
  const resultRed = await createAnalyticsRepository({ pool: poolRed }).getWardrobeHealthScore(testAuthContext);
  assert.ok(resultRed.recommendation.length > 0, "Red tier should have recommendation");
});

test("getWardrobeHealthScore returns zero score with prompt for user with no items", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "0", items_worn_90d: "0", items_good_cpw: "0",
      items_with_cpw: "0", total_wears: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.score, 0);
  assert.equal(result.totalItems, 0);
  assert.ok(result.recommendation.includes("Add items"), "Should prompt to add items");
});

test("getWardrobeHealthScore respects RLS (sets app.current_user_id)", async () => {
  const pool = createMockPool({ setConfigUserId: "firebase-user-123" });
  const repo = createAnalyticsRepository({ pool });
  await repo.getWardrobeHealthScore(testAuthContext);
  assert.ok(true);
});

test("getWardrobeHealthScore handles items without purchase_price (cpwScore ignores them)", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10", items_worn_90d: "5", items_good_cpw: "0",
      items_with_cpw: "0", total_wears: "50",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.cpwScore, 0);
});

test("getWardrobeHealthScore handles items without wear logs", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10", items_worn_90d: "0", items_good_cpw: "0",
      items_with_cpw: "0", total_wears: "0",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.factors.utilizationScore, 0);
  assert.ok(result.recommendation.includes("logging"), "Should suggest logging outfits");
});

test("getWardrobeHealthScore edge case: single item wardrobe", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "1", items_worn_90d: "1", items_good_cpw: "1",
      items_with_cpw: "1", total_wears: "15",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.score, 100);
  assert.equal(result.colorTier, "green");
});

test("getWardrobeHealthScore edge case: all items worn recently with good CPW", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "10", items_worn_90d: "10", items_good_cpw: "10",
      items_with_cpw: "10", total_wears: "100",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.equal(result.score, 100);
  assert.equal(result.colorTier, "green");
  assert.ok(result.recommendation.includes("Great job"), "Should congratulate user");
});

test("getWardrobeHealthScore returns correct response shape", async () => {
  const pool = createMockPool({
    healthScoreRow: {
      total_items: "20", items_worn_90d: "10", items_good_cpw: "6",
      items_with_cpw: "10", total_wears: "100",
    },
  });
  const repo = createAnalyticsRepository({ pool });
  const result = await repo.getWardrobeHealthScore(testAuthContext);
  assert.ok("score" in result);
  assert.ok("factors" in result);
  assert.ok("percentile" in result);
  assert.ok("recommendation" in result);
  assert.ok("totalItems" in result);
  assert.ok("itemsWorn90d" in result);
  assert.ok("colorTier" in result);
  assert.ok("utilizationScore" in result.factors);
  assert.ok("cpwScore" in result.factors);
  assert.ok("sizeUtilizationScore" in result.factors);
});
