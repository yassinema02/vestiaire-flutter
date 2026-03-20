import { VALID_CATEGORIES } from "../ai/taxonomy.js";

/**
 * Repository for wardrobe analytics data access.
 *
 * Provides aggregated wardrobe value metrics and per-item CPW calculations.
 * All queries are RLS-scoped via set_config('app.current_user_id').
 */

/**
 * @param {object} options
 * @param {import('pg').Pool} options.pool - PostgreSQL connection pool.
 */
export function createAnalyticsRepository({ pool }) {
  if (!pool) {
    throw new TypeError("pool is required");
  }

  return {
    /**
     * Get wardrobe summary analytics for the authenticated user.
     *
     * Returns total items, priced items count, total value, total wears
     * across priced items, average CPW, and dominant currency.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} Summary analytics object.
     */
    async getWardrobeSummary(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT
            COUNT(*) AS total_items,
            COUNT(purchase_price) AS priced_items,
            COALESCE(SUM(purchase_price), 0) AS total_value,
            COALESCE(SUM(CASE WHEN purchase_price IS NOT NULL THEN wear_count ELSE 0 END), 0) AS total_wears,
            MODE() WITHIN GROUP (ORDER BY currency) FILTER (WHERE currency IS NOT NULL) AS dominant_currency
          FROM app_public.items`
        );

        const row = result.rows[0];
        const totalItems = parseInt(row.total_items, 10);
        const pricedItems = parseInt(row.priced_items, 10);
        const totalValue = parseFloat(row.total_value);
        const totalWears = parseInt(row.total_wears, 10);
        const dominantCurrency = row.dominant_currency || null;
        const averageCpw = totalWears > 0 ? totalValue / totalWears : null;

        return {
          totalItems,
          pricedItems,
          totalValue,
          totalWears,
          averageCpw,
          dominantCurrency,
        };
      } finally {
        client.release();
      }
    },

    /**
     * Get items with pre-computed CPW for the authenticated user.
     *
     * Returns only items that have a purchase_price set, sorted by CPW
     * descending (worst value first). Items with zero wears have null CPW
     * and appear first.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<Array<object>>} Array of item CPW objects.
     */
    async getItemsWithCpw(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT
            id, name, category, photo_url, purchase_price, currency, wear_count,
            CASE WHEN wear_count > 0 AND purchase_price IS NOT NULL
              THEN purchase_price / wear_count
              ELSE NULL
            END AS cpw
          FROM app_public.items
          WHERE purchase_price IS NOT NULL
          ORDER BY cpw DESC NULLS FIRST`
        );

        return result.rows.map((row) => ({
          id: row.id,
          name: row.name,
          category: row.category,
          photoUrl: row.photo_url,
          purchasePrice: parseFloat(row.purchase_price),
          currency: row.currency,
          wearCount: parseInt(row.wear_count, 10),
          cpw: row.cpw != null ? parseFloat(row.cpw) : null,
        }));
      } finally {
        client.release();
      }
    },
    /**
     * Get top worn items for the authenticated user.
     *
     * Supports three periods: "all" (uses wear_count column),
     * "30" or "90" (counts wear_log_items within date range).
     * Returns at most 10 items sorted by wear count descending.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} options
     * @param {string} [options.period="all"] - "all", "30", or "90".
     * @returns {Promise<Array<object>>} Array of top worn item objects.
     */
    async getTopWornItems(authContext, { period = "all" } = {}) {
      const validPeriods = ["all", "30", "90"];
      if (!validPeriods.includes(period)) {
        const error = new Error("Invalid period. Must be 'all', '30', or '90'");
        error.statusCode = 400;
        throw error;
      }

      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        if (period === "all") {
          const result = await client.query(
            `SELECT id, name, category, photo_url, wear_count, last_worn_date
             FROM app_public.items
             WHERE wear_count > 0
             ORDER BY wear_count DESC, last_worn_date DESC NULLS LAST
             LIMIT 10`
          );

          return result.rows.map((row) => ({
            id: row.id,
            name: row.name,
            category: row.category,
            photoUrl: row.photo_url,
            wearCount: parseInt(row.wear_count, 10),
            lastWornDate: row.last_worn_date,
          }));
        }

        // Period is "30" or "90"
        const days = parseInt(period, 10);
        const result = await client.query(
          `SELECT i.id, i.name, i.category, i.photo_url,
                  i.wear_count AS total_wear_count, i.last_worn_date,
                  COUNT(wli.id) AS period_wear_count
           FROM app_public.items i
           JOIN app_public.wear_log_items wli ON wli.item_id = i.id
           JOIN app_public.wear_logs wl ON wl.id = wli.wear_log_id
           WHERE wl.logged_date >= CURRENT_DATE - $1::integer
           GROUP BY i.id
           ORDER BY period_wear_count DESC, i.last_worn_date DESC NULLS LAST
           LIMIT 10`,
          [days]
        );

        return result.rows.map((row) => ({
          id: row.id,
          name: row.name,
          category: row.category,
          photoUrl: row.photo_url,
          wearCount: parseInt(row.total_wear_count, 10),
          lastWornDate: row.last_worn_date,
          periodWearCount: parseInt(row.period_wear_count, 10),
        }));
      } finally {
        client.release();
      }
    },

    /**
     * Get neglected items for the authenticated user.
     *
     * Returns items not worn in 60+ days, or items never worn that were
     * created 60+ days ago, sorted by staleness (longest neglected first).
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<Array<object>>} Array of neglected item objects.
     */
    /**
     * Get category distribution for the authenticated user.
     *
     * Returns array of categories with item counts and percentages,
     * sorted by item count descending.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<Array<object>>} Array of { category, itemCount, percentage }.
     */
    async getCategoryDistribution(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT category, COUNT(*) AS item_count
           FROM app_public.items
           GROUP BY category
           ORDER BY item_count DESC`
        );

        if (result.rows.length === 0) {
          return [];
        }

        const totalItems = result.rows.reduce(
          (sum, row) => sum + parseInt(row.item_count, 10),
          0
        );

        return result.rows.map((row) => ({
          category: row.category,
          itemCount: parseInt(row.item_count, 10),
          percentage:
            Math.round(
              (parseInt(row.item_count, 10) / totalItems) * 100 * 10
            ) / 10,
        }));
      } finally {
        client.release();
      }
    },

    /**
     * Get wear frequency by day of week for the authenticated user.
     *
     * Returns 7 elements (Mon-Sun) with wear log counts per day.
     * Uses all-time data.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<Array<object>>} Array of { day, dayIndex, logCount }.
     */
    async getWearFrequency(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT EXTRACT(DOW FROM logged_date) AS day_of_week, COUNT(*) AS log_count
           FROM app_public.wear_logs
           GROUP BY day_of_week
           ORDER BY day_of_week`
        );

        const dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        // Initialize all 7 days with 0 counts (ISO order: Mon=0 through Sun=6)
        const days = dayNames.map((day, index) => ({
          day,
          dayIndex: index,
          logCount: 0,
        }));

        // Map PostgreSQL DOW (0=Sun, 1=Mon, ..., 6=Sat) to ISO index
        for (const row of result.rows) {
          const pgDow = parseInt(row.day_of_week, 10);
          // pgDow 0=Sun -> ISO index 6, pgDow 1=Mon -> ISO index 0, etc.
          const isoIndex = pgDow === 0 ? 6 : pgDow - 1;
          days[isoIndex].logCount = parseInt(row.log_count, 10);
        }

        return days;
      } finally {
        client.release();
      }
    },

    /**
     * Get brand value analytics for the authenticated user.
     *
     * Returns brands ranked by average CPW (best value first), with optional
     * category filtering. Only brands with 3+ items are included.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} options
     * @param {string|null} [options.category=null] - Optional category filter.
     * @returns {Promise<object>} Brand value analytics object.
     */
    async getBrandValueAnalytics(authContext, { category = null } = {}) {
      if (category != null && !VALID_CATEGORIES.includes(category)) {
        const error = new Error("Invalid category");
        error.statusCode = 400;
        throw error;
      }

      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Build brand aggregation query
        const params = [authContext.userId];
        let whereClause = "WHERE brand IS NOT NULL AND brand != ''";
        if (category != null) {
          params.push(category);
          whereClause += ` AND category = $${params.length}`;
        }

        const brandQuery = `
          SELECT
            brand,
            COUNT(*) AS item_count,
            SUM(CASE WHEN purchase_price IS NOT NULL THEN purchase_price ELSE 0 END) AS total_spent,
            SUM(wear_count) AS total_wears,
            AVG(CASE WHEN purchase_price IS NOT NULL AND wear_count > 0 THEN purchase_price / wear_count ELSE NULL END) AS avg_cpw,
            COUNT(CASE WHEN purchase_price IS NOT NULL THEN 1 END) AS priced_items,
            MODE() WITHIN GROUP (ORDER BY currency) FILTER (WHERE currency IS NOT NULL) AS dominant_currency
          FROM app_public.items
          ${whereClause}
          GROUP BY brand
          HAVING COUNT(*) >= 3
          ORDER BY avg_cpw ASC NULLS LAST
        `;

        const brandResult = await client.query(brandQuery);

        // Query available categories for filter chips
        const categoriesResult = await client.query(
          `SELECT DISTINCT category FROM app_public.items
           WHERE brand IS NOT NULL AND brand != '' AND category IS NOT NULL
           ORDER BY category`
        );

        const brands = brandResult.rows.map((row) => ({
          brand: row.brand,
          itemCount: parseInt(row.item_count, 10),
          totalSpent: parseFloat(row.total_spent),
          totalWears: parseInt(row.total_wears, 10),
          avgCpw: row.avg_cpw != null ? parseFloat(row.avg_cpw) : null,
          pricedItems: parseInt(row.priced_items, 10),
          dominantCurrency: row.dominant_currency || null,
        }));

        const availableCategories = categoriesResult.rows.map((row) => row.category);

        // Compute bestValueBrand: first brand with non-null avgCpw (already sorted ASC)
        const bestValueBrand = brands.find((b) => b.avgCpw != null)
          ? { brand: brands.find((b) => b.avgCpw != null).brand, avgCpw: brands.find((b) => b.avgCpw != null).avgCpw, currency: brands.find((b) => b.avgCpw != null).dominantCurrency }
          : null;

        // Compute mostInvestedBrand: brand with highest totalSpent
        let mostInvestedBrand = null;
        if (brands.length > 0) {
          const topSpender = brands.reduce((max, b) => b.totalSpent > max.totalSpent ? b : max, brands[0]);
          mostInvestedBrand = { brand: topSpender.brand, totalSpent: topSpender.totalSpent, currency: topSpender.dominantCurrency };
        }

        return {
          brands,
          availableCategories,
          bestValueBrand,
          mostInvestedBrand,
        };
      } finally {
        client.release();
      }
    },

    /**
     * Get sustainability analytics for the authenticated user.
     *
     * Computes a composite sustainability score (0-100) based on 5 weighted
     * factors, CO2 savings, and percentile. All data comes from existing
     * items table columns — no new tables needed.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} Sustainability analytics object.
     */
    async getSustainabilityAnalytics(authContext) {
      const CO2_PER_REWEAR_KG = 0.5;
      const CO2_PER_KM_DRIVEN = 0.21;

      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT
            COUNT(*) AS total_items,
            COALESCE(AVG(wear_count), 0) AS avg_wear_count,
            COUNT(*) FILTER (WHERE last_worn_date >= CURRENT_DATE - INTERVAL '90 days') AS items_worn_90d,
            COALESCE(AVG(CASE WHEN purchase_price IS NOT NULL AND wear_count > 0 THEN purchase_price / wear_count ELSE NULL END), 0) AS avg_cpw,
            COALESCE(SUM(CASE WHEN wear_count > 1 THEN wear_count - 1 ELSE 0 END), 0) AS total_rewears,
            COUNT(*) FILTER (WHERE resale_status IN ('listed', 'sold', 'donated')) AS resale_active_items,
            COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - INTERVAL '90 days') AS new_items_90d
          FROM app_public.items`
        );

        const row = result.rows[0];
        const totalItems = parseInt(row.total_items, 10);
        const avgWearCount = parseFloat(row.avg_wear_count);
        const itemsWorn90d = parseInt(row.items_worn_90d, 10);
        const avgCpw = parseFloat(row.avg_cpw);
        const totalRewears = parseInt(row.total_rewears, 10);
        const resaleActiveItems = parseInt(row.resale_active_items, 10);
        const newItems90d = parseInt(row.new_items_90d, 10);

        // Compute 5 factor scores (each 0-100)
        const avgWearScore = Math.min(100, (avgWearCount / 20) * 100);
        const utilizationScore = totalItems > 0 ? (itemsWorn90d / totalItems) * 100 : 0;
        const cpwScore = avgCpw > 0 ? Math.min(100, (5 / avgCpw) * 100) : 0;
        const resaleScore = Math.min(100, (resaleActiveItems / Math.max(totalItems, 1)) * 500);
        const newPurchaseScore = totalItems > 0
          ? Math.max(0, 100 - (newItems90d / Math.max(totalItems, 1)) * 200)
          : 100;

        // Composite score (weighted sum, clamped 0-100)
        const rawScore = avgWearScore * 0.30 +
          utilizationScore * 0.25 +
          cpwScore * 0.20 +
          resaleScore * 0.15 +
          newPurchaseScore * 0.10;
        const score = Math.max(0, Math.min(100, Math.round(rawScore)));

        // CO2 savings
        const co2SavedKg = Math.round(totalRewears * CO2_PER_REWEAR_KG * 10) / 10;
        const co2CarKmEquivalent = Math.round((co2SavedKg / CO2_PER_KM_DRIVEN) * 10) / 10;

        // Percentile (deterministic)
        const percentile = Math.max(1, 100 - score);

        return {
          score,
          factors: {
            avgWearScore: Math.round(avgWearScore * 10) / 10,
            utilizationScore: Math.round(utilizationScore * 10) / 10,
            cpwScore: Math.round(cpwScore * 10) / 10,
            resaleScore: Math.round(resaleScore * 10) / 10,
            newPurchaseScore: Math.round(newPurchaseScore * 10) / 10,
          },
          co2SavedKg,
          co2CarKmEquivalent,
          percentile,
          totalRewears,
          totalItems,
          badgeAwarded: false,
        };
      } finally {
        client.release();
      }
    },

    /**
     * Get wardrobe composition data for gap analysis.
     *
     * Returns category distribution, season coverage, color distribution,
     * occasion coverage, and total item count. If fewer than 5 items,
     * returns early with empty gaps array.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} Gap analysis data object.
     */
    async getGapAnalysisData(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Total items count
        const totalResult = await client.query(
          "SELECT COUNT(*) AS total_items FROM app_public.items"
        );
        const totalItems = parseInt(totalResult.rows[0].total_items, 10);

        if (totalItems < 5) {
          return { totalItems, gaps: [], recommendations: [] };
        }

        // Category distribution
        const categoryResult = await client.query(
          "SELECT category, COUNT(*) AS count FROM app_public.items WHERE category IS NOT NULL GROUP BY category"
        );

        // Season coverage
        const seasonResult = await client.query(
          "SELECT season, COUNT(*) AS count FROM app_public.items GROUP BY season"
        );

        // Color distribution
        const colorResult = await client.query(
          "SELECT color, COUNT(*) AS count FROM app_public.items WHERE color IS NOT NULL GROUP BY color"
        );

        // Occasion coverage
        const occasionResult = await client.query(
          "SELECT occasion, COUNT(*) AS count FROM app_public.items WHERE occasion IS NOT NULL GROUP BY occasion"
        );

        return {
          totalItems,
          categoryDistribution: categoryResult.rows.map((row) => ({
            category: row.category,
            count: parseInt(row.count, 10),
          })),
          seasonCoverage: seasonResult.rows.map((row) => ({
            season: row.season,
            count: parseInt(row.count, 10),
          })),
          colorDistribution: colorResult.rows.map((row) => ({
            color: row.color,
            count: parseInt(row.count, 10),
          })),
          occasionCoverage: occasionResult.rows.map((row) => ({
            occasion: row.occasion,
            count: parseInt(row.count, 10),
          })),
        };
      } finally {
        client.release();
      }
    },

    async getNeglectedItems(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT id, name, category, photo_url, purchase_price, currency,
                  wear_count, last_worn_date, created_at,
                  CASE WHEN last_worn_date IS NOT NULL
                    THEN CURRENT_DATE - last_worn_date
                    ELSE CURRENT_DATE - created_at::date
                  END AS days_since_worn
           FROM app_public.items
           WHERE (last_worn_date IS NOT NULL AND last_worn_date < CURRENT_DATE - 60)
              OR (last_worn_date IS NULL AND wear_count = 0 AND created_at < CURRENT_DATE - 60)
           ORDER BY COALESCE(last_worn_date, created_at::date) ASC`
        );

        return result.rows.map((row) => {
          const wearCount = parseInt(row.wear_count, 10);
          const purchasePrice = row.purchase_price != null ? parseFloat(row.purchase_price) : null;
          return {
            id: row.id,
            name: row.name,
            category: row.category,
            photoUrl: row.photo_url,
            purchasePrice,
            currency: row.currency,
            wearCount,
            lastWornDate: row.last_worn_date,
            daysSinceWorn: parseInt(row.days_since_worn, 10),
            cpw: (purchasePrice != null && wearCount > 0) ? purchasePrice / wearCount : null,
          };
        });
      } finally {
        client.release();
      }
    },

    /**
     * Get seasonal reports for the authenticated user.
     *
     * Returns data for all 4 meteorological seasons: item counts,
     * most worn items, neglected items, readiness scores, historical
     * comparison, and optional transition alert.
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} Seasonal reports object.
     */
    async getSeasonalReports(authContext) {
      // Meteorological season boundaries
      const SEASON_BOUNDARIES = [
        { season: "spring", startMonth: 3, startDay: 1, endMonth: 5, endDay: 31 },
        { season: "summer", startMonth: 6, startDay: 1, endMonth: 8, endDay: 31 },
        { season: "fall", startMonth: 9, startDay: 1, endMonth: 11, endDay: 30 },
        { season: "winter", startMonth: 12, startDay: 1, endMonth: 2, endDay: 28 },
      ];

      const now = new Date();
      const currentMonth = now.getMonth() + 1; // 1-indexed

      // Determine current season
      let currentSeason;
      if (currentMonth >= 3 && currentMonth <= 5) currentSeason = "spring";
      else if (currentMonth >= 6 && currentMonth <= 8) currentSeason = "summer";
      else if (currentMonth >= 9 && currentMonth <= 11) currentSeason = "fall";
      else currentSeason = "winter";

      // Calculate next season boundary for transition alert
      const SEASON_ORDER = ["spring", "summer", "fall", "winter"];
      const NEXT_BOUNDARIES = [
        { month: 3, day: 1, season: "spring" },
        { month: 6, day: 1, season: "summer" },
        { month: 9, day: 1, season: "fall" },
        { month: 12, day: 1, season: "winter" },
      ];

      let transitionAlert = null;
      for (const boundary of NEXT_BOUNDARIES) {
        const boundaryDate = new Date(now.getFullYear(), boundary.month - 1, boundary.day);
        if (boundaryDate <= now) {
          // Try next year for this boundary
          const nextYearDate = new Date(now.getFullYear() + 1, boundary.month - 1, boundary.day);
          const daysUntil = Math.ceil((nextYearDate - now) / (1000 * 60 * 60 * 24));
          if (daysUntil <= 14) {
            transitionAlert = { upcomingSeason: boundary.season, daysUntil };
            break;
          }
        } else {
          const daysUntil = Math.ceil((boundaryDate - now) / (1000 * 60 * 60 * 24));
          if (daysUntil <= 14) {
            transitionAlert = { upcomingSeason: boundary.season, daysUntil };
            break;
          }
        }
      }

      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Get total items count
        const totalResult = await client.query(
          "SELECT COUNT(*) AS total_items FROM app_public.items"
        );
        const totalItems = parseInt(totalResult.rows[0].total_items, 10);

        const seasons = [];
        for (const seasonDef of SEASON_BOUNDARIES) {
          const seasonName = seasonDef.season;

          // Item count for this season (includes all-season items)
          const itemCountResult = await client.query(
            `SELECT COUNT(*) AS count FROM app_public.items
             WHERE (season @> ARRAY[$1]::text[] OR season @> ARRAY['all-season']::text[])`,
            [seasonName]
          );
          const seasonItemCount = parseInt(itemCountResult.rows[0].count, 10);

          // Most worn items for this season
          const mostWornResult = await client.query(
            `SELECT i.id, i.name, i.photo_url, i.category, i.wear_count
             FROM app_public.items i
             WHERE (i.season @> ARRAY[$1]::text[] OR i.season @> ARRAY['all-season']::text[])
             ORDER BY i.wear_count DESC
             LIMIT 5`,
            [seasonName]
          );

          // Neglected items for this season
          const neglectedResult = await client.query(
            `SELECT i.id, i.name, i.photo_url, i.category, i.wear_count
             FROM app_public.items i
             WHERE (i.season @> ARRAY[$1]::text[] OR i.season @> ARRAY['all-season']::text[])
               AND (i.wear_count = 0 OR i.last_worn_date < CURRENT_DATE - INTERVAL '90 days')
             ORDER BY i.wear_count ASC, i.last_worn_date ASC NULLS FIRST
             LIMIT 5`,
            [seasonName]
          );

          // Total wears for this season
          const totalWearsResult = await client.query(
            `SELECT COALESCE(SUM(i.wear_count), 0) AS total_wears
             FROM app_public.items i
             WHERE (i.season @> ARRAY[$1]::text[] OR i.season @> ARRAY['all-season']::text[])`,
            [seasonName]
          );
          const totalWears = parseInt(totalWearsResult.rows[0].total_wears, 10);

          // Count of items actually worn (wear_count > 0)
          const wornItemsResult = await client.query(
            `SELECT COUNT(*) AS count FROM app_public.items
             WHERE (season @> ARRAY[$1]::text[] OR season @> ARRAY['all-season']::text[])
               AND wear_count > 0`,
            [seasonName]
          );
          const seasonWornItems = parseInt(wornItemsResult.rows[0].count, 10);

          // Readiness score (1-10)
          const readinessScore = Math.min(
            10,
            Math.max(
              1,
              Math.round(
                (seasonItemCount / Math.max(totalItems, 1)) * 20 +
                (seasonWornItems / Math.max(seasonItemCount, 1)) * 5
              )
            )
          );

          // Historical comparison: current season vs same season last year
          const currentYear = now.getFullYear();
          let currentSeasonStart, currentSeasonEnd;
          let priorSeasonStart, priorSeasonEnd;

          if (seasonDef.season === "winter") {
            // Winter spans Dec-Feb, handle year wrap
            if (currentMonth === 12) {
              currentSeasonStart = `${currentYear}-12-01`;
              currentSeasonEnd = `${currentYear + 1}-02-28`;
              priorSeasonStart = `${currentYear - 1}-12-01`;
              priorSeasonEnd = `${currentYear}-02-28`;
            } else {
              // Jan or Feb
              currentSeasonStart = `${currentYear - 1}-12-01`;
              currentSeasonEnd = `${currentYear}-02-28`;
              priorSeasonStart = `${currentYear - 2}-12-01`;
              priorSeasonEnd = `${currentYear - 1}-02-28`;
            }
          } else {
            const startMonth = String(seasonDef.startMonth).padStart(2, "0");
            const endMonth = String(seasonDef.endMonth).padStart(2, "0");
            const endDay = String(seasonDef.endDay).padStart(2, "0");
            currentSeasonStart = `${currentYear}-${startMonth}-01`;
            currentSeasonEnd = `${currentYear}-${endMonth}-${endDay}`;
            priorSeasonStart = `${currentYear - 1}-${startMonth}-01`;
            priorSeasonEnd = `${currentYear - 1}-${endMonth}-${endDay}`;
          }

          const currentCountResult = await client.query(
            `SELECT COUNT(DISTINCT wli.item_id) AS count
             FROM app_public.wear_logs wl
             JOIN app_public.wear_log_items wli ON wl.id = wli.wear_log_id
             WHERE wl.logged_date >= $1 AND wl.logged_date <= $2`,
            [currentSeasonStart, currentSeasonEnd]
          );
          const currentCount = parseInt(currentCountResult.rows[0].count, 10);

          const priorCountResult = await client.query(
            `SELECT COUNT(DISTINCT wli.item_id) AS count
             FROM app_public.wear_logs wl
             JOIN app_public.wear_log_items wli ON wl.id = wli.wear_log_id
             WHERE wl.logged_date >= $1 AND wl.logged_date <= $2`,
            [priorSeasonStart, priorSeasonEnd]
          );
          const priorYearCount = parseInt(priorCountResult.rows[0].count, 10);

          let historicalComparison;
          if (priorYearCount > 0) {
            const percentChange = Math.round(
              ((currentCount - priorYearCount) / priorYearCount) * 100
            );
            const direction = percentChange >= 0 ? "more" : "fewer";
            const absPercent = Math.abs(percentChange);
            historicalComparison = {
              percentChange,
              comparisonText: `${percentChange >= 0 ? "+" : ""}${percentChange}% ${direction} items worn vs last ${seasonName}`,
            };
          } else {
            historicalComparison = {
              percentChange: null,
              comparisonText: `First ${seasonName} tracked -- keep logging to see trends!`,
            };
          }

          seasons.push({
            season: seasonName,
            itemCount: seasonItemCount,
            totalWears,
            mostWorn: mostWornResult.rows.map((row) => ({
              id: row.id,
              name: row.name,
              photoUrl: row.photo_url,
              category: row.category,
              wearCount: parseInt(row.wear_count, 10),
            })),
            neglected: neglectedResult.rows.map((row) => ({
              id: row.id,
              name: row.name,
              photoUrl: row.photo_url,
              category: row.category,
              wearCount: parseInt(row.wear_count, 10),
            })),
            readinessScore,
            historicalComparison,
          });
        }

        // Add readinessScore to transition alert if present
        if (transitionAlert) {
          const alertSeason = seasons.find(
            (s) => s.season === transitionAlert.upcomingSeason
          );
          transitionAlert.readinessScore = alertSeason
            ? alertSeason.readinessScore
            : 1;
        }

        return {
          seasons,
          currentSeason,
          transitionAlert,
          totalItems,
        };
      } finally {
        client.release();
      }
    },

    /**
     * Get heatmap data for the authenticated user.
     *
     * Returns daily wear activity within the specified date range
     * and streak statistics computed from the full wear log history.
     *
     * @param {object} authContext - Must have userId.
     * @param {object} options
     * @param {string} options.startDate - Start date (YYYY-MM-DD).
     * @param {string} options.endDate - End date (YYYY-MM-DD).
     * @returns {Promise<object>} Heatmap data object.
     */
    async getHeatmapData(authContext, { startDate, endDate }) {
      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        // Daily activity within range
        const activityResult = await client.query(
          `SELECT wl.logged_date, COUNT(DISTINCT wli.item_id) AS items_count
           FROM app_public.wear_logs wl
           JOIN app_public.wear_log_items wli ON wl.id = wli.wear_log_id
           WHERE wl.logged_date >= $1 AND wl.logged_date <= $2
           GROUP BY wl.logged_date
           ORDER BY wl.logged_date`,
          [startDate, endDate]
        );

        const dailyActivity = activityResult.rows.map((row) => ({
          date: row.logged_date instanceof Date
            ? row.logged_date.toISOString().split("T")[0]
            : String(row.logged_date),
          itemsCount: parseInt(row.items_count, 10),
        }));

        // Streak statistics from full history
        const allDatesResult = await client.query(
          `SELECT DISTINCT logged_date FROM app_public.wear_logs ORDER BY logged_date DESC`
        );

        const allDates = allDatesResult.rows.map((row) => {
          const d = row.logged_date instanceof Date
            ? row.logged_date
            : new Date(row.logged_date);
          return d.toISOString().split("T")[0];
        });

        // Compute streaks
        let currentStreak = 0;
        let longestStreak = 0;
        const totalDaysLogged = allDates.length;

        if (allDates.length > 0) {
          // Current streak: consecutive days ending today (or most recent)
          const today = new Date();
          today.setHours(0, 0, 0, 0);
          const todayStr = today.toISOString().split("T")[0];

          // Walk backwards from today
          let streak = 0;
          let checkDate = new Date(today);

          // If the most recent logged date is today or yesterday, start counting
          const mostRecentDate = allDates[0];
          const mostRecentDateObj = new Date(mostRecentDate + "T00:00:00");
          const diffDays = Math.round((today - mostRecentDateObj) / (1000 * 60 * 60 * 24));

          if (diffDays <= 1) {
            // Start from most recent date and walk backwards
            checkDate = new Date(mostRecentDateObj);
            const dateSet = new Set(allDates);
            while (dateSet.has(checkDate.toISOString().split("T")[0])) {
              streak++;
              checkDate.setDate(checkDate.getDate() - 1);
            }
          }
          currentStreak = streak;

          // Longest streak: walk all dates sorted ascending
          const sortedDates = [...allDates].sort();
          let tempStreak = 1;
          longestStreak = 1;
          for (let i = 1; i < sortedDates.length; i++) {
            const prev = new Date(sortedDates[i - 1] + "T00:00:00");
            const curr = new Date(sortedDates[i] + "T00:00:00");
            const diff = Math.round((curr - prev) / (1000 * 60 * 60 * 24));
            if (diff === 1) {
              tempStreak++;
              longestStreak = Math.max(longestStreak, tempStreak);
            } else {
              tempStreak = 1;
            }
          }
        }

        // Average items per day
        let avgItemsPerDay = 0;
        if (totalDaysLogged > 0) {
          const totalItemsResult = await client.query(
            `SELECT COUNT(DISTINCT wli.id) AS total
             FROM app_public.wear_log_items wli
             JOIN app_public.wear_logs wl ON wl.id = wli.wear_log_id`
          );
          const totalItemsLogged = parseInt(totalItemsResult.rows[0].total, 10);
          avgItemsPerDay = Math.round((totalItemsLogged / totalDaysLogged) * 10) / 10;
        }

        return {
          dailyActivity,
          streakStats: {
            currentStreak,
            longestStreak,
            totalDaysLogged,
            avgItemsPerDay,
          },
        };
      } finally {
        client.release();
      }
    },

    /**
     * Get wardrobe health score for the authenticated user.
     *
     * Computes a composite health score (0-100) based on 3 weighted factors:
     * - Utilization (50%): % of items worn in last 90 days
     * - CPW efficiency (30%): % of priced+worn items with CPW < 5
     * - Size utilization (20%): avg wears per item relative to 10
     *
     * @param {object} authContext - Must have userId.
     * @returns {Promise<object>} Health score object.
     */
    async getWardrobeHealthScore(authContext) {
      const client = await pool.connect();
      try {
        await client.query(
          "SELECT set_config('app.current_user_id', $1, true)",
          [authContext.userId]
        );

        const result = await client.query(
          `SELECT
            COUNT(*) AS total_items,
            COUNT(*) FILTER (WHERE last_worn_date >= CURRENT_DATE - INTERVAL '90 days') AS items_worn_90d,
            COUNT(*) FILTER (WHERE purchase_price IS NOT NULL AND wear_count > 0 AND (purchase_price / wear_count) < 5) AS items_good_cpw,
            COUNT(*) FILTER (WHERE purchase_price IS NOT NULL AND wear_count > 0) AS items_with_cpw,
            COALESCE(SUM(wear_count), 0) AS total_wears
          FROM app_public.items`
        );

        const row = result.rows[0];
        const totalItems = parseInt(row.total_items, 10);
        const itemsWorn90d = parseInt(row.items_worn_90d, 10);
        const itemsGoodCpw = parseInt(row.items_good_cpw, 10);
        const itemsWithCpw = parseInt(row.items_with_cpw, 10);
        const totalWears = parseInt(row.total_wears, 10);

        // Factor scores (each 0-100)
        const utilizationScore = totalItems > 0 ? (itemsWorn90d / totalItems) * 100 : 0;
        const cpwScore = itemsWithCpw > 0 ? (itemsGoodCpw / itemsWithCpw) * 100 : 0;
        const sizeUtilizationScore = totalItems > 0 ? Math.min(100, (totalWears / totalItems) * 10) : 0;

        // Composite score (weighted sum, clamped 0-100)
        const rawScore = utilizationScore * 0.50 + cpwScore * 0.30 + sizeUtilizationScore * 0.20;
        const score = Math.max(0, Math.min(100, Math.round(rawScore)));

        // Percentile (deterministic)
        const percentile = Math.max(1, 100 - score);

        // Color tier
        let colorTier;
        if (score >= 80) colorTier = "green";
        else if (score >= 50) colorTier = "yellow";
        else colorTier = "red";

        // Recommendation
        let recommendation;
        if (totalItems === 0) {
          recommendation = "Add items to your wardrobe to start tracking your health score!";
        } else if (totalWears === 0) {
          recommendation = "Start logging your outfits to see your wardrobe health improve!";
        } else if (score >= 80) {
          recommendation = "Great job! Keep wearing your wardrobe evenly to maintain your Green status.";
        } else {
          // Find lowest-scoring factor
          const factors = [
            { name: "utilization", value: utilizationScore },
            { name: "cpw", value: cpwScore },
            { name: "sizeUtilization", value: sizeUtilizationScore },
          ];
          factors.sort((a, b) => a.value - b.value);
          const lowestFactor = factors[0].name;

          if (lowestFactor === "utilization") {
            const itemsNeeded = Math.ceil(totalItems * 0.8 - itemsWorn90d);
            recommendation = `Wear ${Math.max(1, itemsNeeded)} more items this month to reach Green status`;
          } else if (lowestFactor === "cpw") {
            recommendation = "Focus on wearing your pricier items to lower their cost-per-wear";
          } else {
            const itemsToDeclutter = Math.max(0, totalItems - Math.ceil(totalWears / 8));
            recommendation = itemsToDeclutter > 0
              ? `Declutter ${itemsToDeclutter} items to improve your wardrobe efficiency`
              : "Keep wearing your items regularly to improve your wardrobe efficiency";
          }
        }

        return {
          score,
          factors: {
            utilizationScore: Math.round(utilizationScore * 10) / 10,
            cpwScore: Math.round(cpwScore * 10) / 10,
            sizeUtilizationScore: Math.round(sizeUtilizationScore * 10) / 10,
          },
          percentile,
          recommendation,
          totalItems,
          itemsWorn90d,
          colorTier,
        };
      } finally {
        client.release();
      }
    },
  };
}
