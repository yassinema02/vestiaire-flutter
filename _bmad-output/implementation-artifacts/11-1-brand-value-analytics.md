# Story 11.1: Brand Value Analytics

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Premium User,
I want to see which clothing brands offer me the best cost-per-wear,
so that I know where to invest my shopping budget in the future.

## Acceptance Criteria

1. Given I am a Premium user and have items with `brand` metadata and wear logs, when I scroll down the Analytics dashboard (existing `AnalyticsDashboardScreen`), then I see a new "Brand Value" section below the existing "Wear Frequency" section. The section displays a ranked list of brands sorted by lowest average CPW (best value first). Each row shows: rank number, brand name, average CPW (formatted with currency symbol), total spent (sum of `purchase_price` for that brand), total wears (sum of `wear_count`), and item count. Only brands with 3 or more items are included. (FR-BRD-01, FR-BRD-03)

2. Given I am viewing the "Brand Value" section, when the data loads, then above the ranked list I see summary metrics in a compact row: "Best Value Brand" (brand with lowest avg CPW) and "Most Invested Brand" (brand with highest total spent). Each metric shows the brand name and its key value. (FR-BRD-01)

3. Given I am viewing the "Brand Value" section, when I tap a category filter chip, then I can filter the brand rankings by garment category. Filter options include: "All" (default, selected), plus each category present in the user's wardrobe (e.g., "Tops", "Bottoms", "Outerwear"). Only categories that have at least one branded item appear as filter chips. When a category filter is active, only items in that category contribute to the brand CPW, total spent, and total wears calculations. The minimum 3-items threshold still applies per brand within the filtered category. (FR-BRD-02)

4. Given I tap a category filter, when the filter changes, then only the "Brand Value" section re-fetches data via `GET /v1/analytics/brand-value?category=<category>`. The rest of the analytics dashboard does not re-fetch. The selected filter chip is visually highlighted. (FR-BRD-02)

5. Given I am a Free user viewing the Analytics dashboard, when the "Brand Value" section would render, then instead a `PremiumGateCard` is displayed with title "Brand Value Analytics", subtitle "Discover which brands give you the best value for money", icon `Icons.diamond_outlined`, and a "Go Premium" CTA that calls `subscriptionService.presentPaywallIfNeeded()`. Free users do NOT trigger the brand value API call. (FR-BRD-01, Premium gating per architecture)

6. Given I have fewer than 3 items for any single brand, when the "Brand Value" section loads, then it shows an empty state: "Add more branded items to see brand analytics! Brands need at least 3 items to appear." with an `Icons.loyalty_outlined` icon (32px, #9CA3AF). (FR-BRD-03)

7. Given I have brands meeting the threshold but none of the branded items have `purchase_price` set, when the "Brand Value" section loads, then brands are still shown ranked by total wears, but CPW and total spent display "N/A". A note appears: "Add purchase prices to see cost-per-wear by brand." (FR-BRD-01)

8. Given the API call to fetch brand value data fails, when the analytics screen loads, then the existing error-retry pattern from Story 5.4 handles the failure gracefully -- the entire dashboard shows an error state with a "Retry" button. (FR-BRD-01)

9. Given I tap a brand row in the ranked list, when the tap is registered, then I navigate to a filtered view of my wardrobe showing only items from that brand (push `WardrobeScreen` with `brand` filter pre-applied). (FR-BRD-01)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (1046+ API tests, 1476+ Flutter tests) and new tests cover: brand value repository method, API endpoint (auth, premium gating, category filter, min 3 items), mobile BrandValueSection widget (premium/free states, ranked list, category filters, empty state, item tap, no-price state), dashboard integration, and edge cases.

## Tasks / Subtasks

- [x] Task 1: API - Add brand value analytics method to analytics repository (AC: 1, 2, 3, 6, 7)
  - [x] 1.1: In `apps/api/src/modules/analytics/analytics-repository.js`, add `async getBrandValueAnalytics(authContext, { category = null })` method following the identical connection/RLS pattern as existing methods: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
  - [x] 1.2: SQL query (no category filter): `SELECT brand, COUNT(*) AS item_count, SUM(CASE WHEN purchase_price IS NOT NULL THEN purchase_price ELSE 0 END) AS total_spent, SUM(wear_count) AS total_wears, AVG(CASE WHEN purchase_price IS NOT NULL AND wear_count > 0 THEN purchase_price / wear_count ELSE NULL END) AS avg_cpw, COUNT(CASE WHEN purchase_price IS NOT NULL THEN 1 END) AS priced_items, MODE() WITHIN GROUP (ORDER BY currency) FILTER (WHERE currency IS NOT NULL) AS dominant_currency FROM app_public.items WHERE brand IS NOT NULL AND brand != '' GROUP BY brand HAVING COUNT(*) >= 3 ORDER BY avg_cpw ASC NULLS LAST`. When `category` param is provided, add `AND category = $2` to the WHERE clause.
  - [x] 1.3: Validate `category` parameter if provided: check against `VALID_CATEGORIES` from `apps/api/src/modules/ai/taxonomy.js`. If invalid, throw a 400 error.
  - [x] 1.4: Also query available categories for filter chips: `SELECT DISTINCT category FROM app_public.items WHERE brand IS NOT NULL AND brand != '' AND category IS NOT NULL ORDER BY category`. Return as `availableCategories` array.
  - [x] 1.5: Return object: `{ brands: [{ brand, itemCount, totalSpent, totalWears, avgCpw, pricedItems, dominantCurrency }], availableCategories: [string], bestValueBrand: { brand, avgCpw, currency } | null, mostInvestedBrand: { brand, totalSpent, currency } | null }`. Compute `bestValueBrand` and `mostInvestedBrand` from the brands array in JS (first brand with non-null avgCpw is best value since sorted by avgCpw ASC; brand with highest totalSpent is most invested). Map snake_case to camelCase.

- [x] Task 2: API - Add brand value route with premium gating (AC: 1, 3, 4, 5, 8)
  - [x] 2.1: In `apps/api/src/main.js`, add route `GET /v1/analytics/brand-value?category=<optional>`. Requires authentication (401 if unauthenticated). Before calling the repository, call `premiumGuard.requirePremium(authContext)` to enforce premium-only access (returns 403 with `PREMIUM_REQUIRED` for free users). Extract optional `category` query param. Call `analyticsRepository.getBrandValueAnalytics(authContext, { category })`. Return 200 with `{ brands: [...], availableCategories: [...], bestValueBrand: {...}, mostInvestedBrand: {...} }`.
  - [x] 2.2: For invalid category, return 400 with `{ error: "Invalid category" }`. Place route after existing analytics routes in main.js.

- [x] Task 3: API - Unit tests for brand value repository method (AC: 1, 2, 3, 6, 7, 10)
  - [x] 3.1: In `apps/api/test/modules/analytics/analytics-repository.test.js`, add tests for `getBrandValueAnalytics`:
    - Returns brands sorted by avg_cpw ascending (best value first).
    - Only includes brands with 3+ items (excludes brands with 1-2 items).
    - Computes correct avgCpw as average of (purchase_price / wear_count) per item.
    - Computes correct totalSpent as sum of purchase_price.
    - Computes correct totalWears as sum of wear_count.
    - Returns empty brands array when no brands meet the 3-item threshold.
    - Respects RLS (user A cannot see user B's brand data).
    - Handles items without purchase_price: avgCpw is null when no priced items, totalSpent is 0.
    - Returns brands ranked by totalWears when all avgCpw values are null (no prices).
    - Category filter correctly restricts to specified category.
    - Category filter still applies 3-item minimum per brand within the category.
    - Returns availableCategories list of distinct categories with branded items.
    - Throws 400 for invalid category parameter.
    - Computes bestValueBrand correctly (lowest non-null avgCpw).
    - Computes mostInvestedBrand correctly (highest totalSpent).
    - bestValueBrand is null when no brands have priced items.

- [x] Task 4: API - Integration tests for brand value endpoint (AC: 1, 3, 5, 8, 10)
  - [x] 4.1: In `apps/api/test/modules/analytics/analytics-endpoints.test.js`, add tests:
    - `GET /v1/analytics/brand-value` returns 200 with brands array for premium user.
    - `GET /v1/analytics/brand-value` returns 401 if unauthenticated.
    - `GET /v1/analytics/brand-value` returns 403 with `PREMIUM_REQUIRED` for free user.
    - `GET /v1/analytics/brand-value?category=tops` returns filtered brand data.
    - `GET /v1/analytics/brand-value?category=invalid` returns 400.
    - `GET /v1/analytics/brand-value` returns empty brands array for user with no qualifying brands.
    - Response includes `availableCategories`, `bestValueBrand`, `mostInvestedBrand` fields.

- [x] Task 5: Mobile - Add brand value API method to ApiClient (AC: 1, 3)
  - [x] 5.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add `Future<Map<String, dynamic>> getBrandValueAnalytics({String? category})` method. Calls `GET /v1/analytics/brand-value` (appending `?category=$category` if non-null) using `_authenticatedGet`. Returns response JSON map. Throws `ApiException` on error (including 403 for non-premium).

- [x] Task 6: Mobile - Create BrandValueSection widget (AC: 1, 2, 3, 4, 5, 6, 7, 9)
  - [x] 6.1: Create `apps/mobile/lib/src/features/analytics/widgets/brand_value_section.dart` with `BrandValueSection` StatefulWidget. Constructor accepts: `required bool isPremium`, `required List<Map<String, dynamic>> brands`, `required List<String> availableCategories`, `required Map<String, dynamic>? bestValueBrand`, `required Map<String, dynamic>? mostInvestedBrand`, `required String selectedCategory`, `required ValueChanged<String> onCategoryChanged`, `required ValueChanged<Map<String, dynamic>> onBrandTap`, `SubscriptionService? subscriptionService`.
  - [x] 6.2: **Premium gate (free users):** If `!isPremium`, render `PremiumGateCard(title: "Brand Value Analytics", subtitle: "Discover which brands give you the best value for money", icon: Icons.diamond_outlined, subscriptionService: subscriptionService)`. Do NOT render the brand list or filters.
  - [x] 6.3: **Section header:** "Brand Value" (16px bold, #1F2937) with a small info icon tooltip explaining "Brands ranked by average cost-per-wear. Minimum 3 items per brand."
  - [x] 6.4: **Summary metrics row:** Two compact cards showing "Best Value" and "Most Invested" brands. Each card: brand name (14px bold, #1F2937), key metric below (12px, #6B7280). Use the same card styling as `SummaryCardsRow` (rounded container, #F9FAFB background, 12px radius). Show "N/A" if `bestValueBrand` or `mostInvestedBrand` is null.
  - [x] 6.5: **Category filter chips:** Horizontal scrollable row of `ChoiceChip`s: "All" (default), plus each category from `availableCategories`. Capitalize category names for display (e.g., "tops" -> "Tops"). Tapping a chip calls `onCategoryChanged` with the category value (or "all" for the All chip). Selected chip uses primary color (#4F46E5).
  - [x] 6.6: **Ranked brand list:** Each row: rank number in circular badge (#4F46E5 background, white text, 24x24), brand name (14px bold, #1F2937), avg CPW with currency (14px, color-coded: green < 5, yellow 5-20, red > 20, grey if null), total spent (12px, #6B7280), total wears (12px, #6B7280), item count (12px, #6B7280). Each row is an `InkWell` calling `onBrandTap`. Minimum 44x44 touch target.
  - [x] 6.7: **Empty state:** When `brands` is empty, show "Add more branded items to see brand analytics! Brands need at least 3 items to appear." with `Icons.loyalty_outlined` (32px, #9CA3AF).
  - [x] 6.8: **No-price state:** When brands exist but all have null `avgCpw`, show brands ranked by total wears. Display "N/A" for CPW and total spent. Show note: "Add purchase prices to see cost-per-wear by brand."
  - [x] 6.9: Add `Semantics` labels: "Brand value analytics, [count] brands", "Rank [n], [brand name], average cost per wear [amount], [total wears] wears", "Filter by category [category name]".

- [x] Task 7: Mobile - Integrate BrandValueSection into AnalyticsDashboardScreen (AC: 1, 2, 3, 4, 5, 8)
  - [x] 7.1: In `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart`, add state fields: `List<Map<String, dynamic>>? _brandValueBrands`, `List<String>? _brandValueCategories`, `Map<String, dynamic>? _bestValueBrand`, `Map<String, dynamic>? _mostInvestedBrand`, `String _brandValueCategory = "all"`.
  - [x] 7.2: Update `_loadAnalytics()`: After the existing 6 parallel fetches, add a conditional 7th fetch for brand value analytics ONLY if the user is premium. Check premium status using `subscriptionService?.isPremiumCached ?? false`. If premium, call `apiClient.getBrandValueAnalytics()` and store results. If not premium, skip the call (set brand value state fields to null/empty). This avoids a wasted 403 for free users. Update `Future.wait` to include the 7th call conditionally.
  - [x] 7.3: Add a `_loadBrandValue(String category)` method for when the user changes the category filter. This only re-fetches `getBrandValueAnalytics(category: category == "all" ? null : category)`. Sets `_brandValueCategory = category` and updates brand value state fields.
  - [x] 7.4: In the `CustomScrollView` slivers, after the existing `WearFrequencySection` sliver, add a `SliverToBoxAdapter` wrapping `BrandValueSection(isPremium: subscriptionService?.isPremiumCached ?? false, brands: _brandValueBrands ?? [], availableCategories: _brandValueCategories ?? [], bestValueBrand: _bestValueBrand, mostInvestedBrand: _mostInvestedBrand, selectedCategory: _brandValueCategory, onCategoryChanged: _loadBrandValue, onBrandTap: _navigateToBrandWardrobe, subscriptionService: subscriptionService)`.
  - [x] 7.5: Add `_navigateToBrandWardrobe(Map<String, dynamic> brand)` method: navigates to `WardrobeScreen` with `brand` filter pre-applied. Use `Navigator.push` with `MaterialPageRoute` to `WardrobeScreen` passing the brand name as a filter parameter. Reuse the existing filter mechanism from Story 2.5 (`WardrobeScreen` accepts optional `initialFilters`).
  - [x] 7.6: If `subscriptionService` is not already a constructor parameter on `AnalyticsDashboardScreen`, add it as an optional parameter `SubscriptionService? subscriptionService`. It was already added in Story 7.2 for the AI Insights premium gate.

- [x] Task 8: Mobile - Widget tests for BrandValueSection (AC: 1, 2, 3, 5, 6, 7, 9, 10)
  - [x] 8.1: Create `apps/mobile/test/features/analytics/widgets/brand_value_section_test.dart`:
    - Renders PremiumGateCard when isPremium is false.
    - Does NOT render brand list when isPremium is false.
    - Renders section header "Brand Value" when isPremium is true.
    - Renders summary metrics row with best value and most invested brands.
    - Renders category filter chips including "All" and available categories.
    - Tapping a category chip calls onCategoryChanged with correct value.
    - Renders ranked brand list with rank numbers, brand names, CPW, total spent, wears.
    - CPW color coding: green < 5, yellow 5-20, red > 20.
    - Tapping a brand row calls onBrandTap.
    - Empty state shows correct prompt when brands list is empty.
    - No-price state shows "N/A" for CPW and total spent, ranks by wears.
    - Summary metrics show "N/A" when bestValueBrand or mostInvestedBrand is null.
    - Semantics labels present on all key elements.

- [x] Task 9: Mobile - Update AnalyticsDashboardScreen tests (AC: 1, 4, 5, 8, 10)
  - [x] 9.1: In `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart`, add tests:
    - Dashboard renders BrandValueSection below WearFrequencySection for premium user.
    - Dashboard renders PremiumGateCard for brand value for free user.
    - Changing brand value category filter triggers isolated re-fetch of brand value only.
    - Dashboard error state still works (handles 7 API calls for premium, 6 for free).
    - Mock API returns brand value data for premium user.
    - Mock API does NOT call brand value endpoint for free user.

- [x] Task 10: Regression testing (AC: all)
  - [x] 10.1: Run `flutter analyze` -- zero new issues.
  - [x] 10.2: Run `flutter test` -- all existing 1476+ Flutter tests plus new tests pass.
  - [x] 10.3: Run `npm --prefix apps/api test` -- all existing 1046+ API tests plus new tests pass.
  - [x] 10.4: Verify existing AnalyticsDashboardScreen tests pass with the new section added (mock API updated).
  - [x] 10.5: Verify existing premium gating tests continue to pass.
  - [x] 10.6: Verify WardrobeScreen brand filter navigation works correctly.

## Dev Notes

- This is the **first story in Epic 11** (Advanced Analytics 2.0). It adds brand-level value analytics to the existing Analytics dashboard, building on the analytics infrastructure established in Stories 5.4-5.7.
- This story implements **FR-BRD-01** (brand value section with brand name, avg CPW, total spent, total wears ranked by best value), **FR-BRD-02** (filterable by category), and **FR-BRD-03** (minimum 3 items per brand).
- **Premium-gated feature.** Per architecture: "Gated features include... advanced analytics." Per Story 7.2 premium matrix: "Advanced analytics (brand, sustainability, gap, seasonal): Premium-only." The `premiumGuard.requirePremium()` utility (created in Story 7.2) is used for server-side gating. Client-side uses `PremiumGateCard` (created in Story 7.2) for the free-user experience.
- **Extends the existing analytics repository.** Stories 5.4-5.6 established `analytics-repository.js` with 6 methods. This story adds `getBrandValueAnalytics` as the 7th method, following the identical connection/RLS/camelCase pattern.
- **Extends the existing AnalyticsDashboardScreen.** The brand value section is added as a sliver in the existing `CustomScrollView`, below the `WearFrequencySection`. The dashboard now conditionally fetches 7 endpoints (6 free + 1 premium) for premium users, or 6 for free users.
- **No new database migration needed.** All required data already exists: `items.brand` (TEXT, nullable, from Story 2.4 migration 009), `items.purchase_price`, `items.currency`, `items.wear_count`, `items.category`. The brand column is populated via manual metadata entry (Story 2.4) or AI categorization could optionally extract it.
- **No new dependencies needed.** Uses existing packages: `fl_chart` is NOT needed (this is a ranked list, not a chart). Uses `ChoiceChip` for category filters (same as Story 5.5 TopWornSection).

### Design Decision: Server-Side Brand Aggregation with Category Filter

Brand analytics are computed server-side via SQL GROUP BY with HAVING clause for the 3-item minimum. The optional `category` query parameter applies a WHERE filter before aggregation, so the 3-item minimum applies per brand within the filtered category. This follows the established "server authority for analytics data" pattern from Stories 5.4-5.6.

### Design Decision: Conditional Premium-Only Fetch

The brand value API call is only made when the user is premium (`subscriptionService.isPremiumCached`). Free users see a `PremiumGateCard` without any API call, avoiding a wasted 403 roundtrip. This matches the pattern established in Story 5.7 where free users see the AI Insights teaser without calling the AI summary endpoint.

### Design Decision: Category Filter Re-Fetches Independently

When the user taps a category filter chip, only the `getBrandValueAnalytics` endpoint is re-called (not the entire dashboard). This matches the pattern from Story 5.5 where the top-worn period filter re-fetches only its own data via `_loadTopWorn()`.

### Design Decision: Brand Tap Navigates to Filtered Wardrobe

Tapping a brand row navigates to the existing `WardrobeScreen` with the `brand` filter pre-applied (Story 2.5 established server-side filtering by brand via `GET /v1/items?brand=<brand>`). This provides drill-down from analytics to the actual items without creating a new screen.

### Design Decision: No Chart for Brand Rankings

The brand value section uses a ranked list (similar to TopWornSection from Story 5.5) rather than a chart. A list better communicates brand names, multiple metrics per brand, and supports tap-to-navigate interaction. Charts are reserved for distribution/frequency data (Story 5.6).

### Project Structure Notes

- Modified API files:
  - `apps/api/src/modules/analytics/analytics-repository.js` (add `getBrandValueAnalytics` method)
  - `apps/api/src/main.js` (add `GET /v1/analytics/brand-value` route with premium guard)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/widgets/brand_value_section.dart` (brand value widget)
  - `apps/mobile/test/features/analytics/widgets/brand_value_section_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (add brand value state, conditional fetch, new sliver, `_loadBrandValue`, `_navigateToBrandWardrobe`)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add `getBrandValueAnalytics` method)
  - `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (add brand value tests, update mock)
- Modified API test files:
  - `apps/api/test/modules/analytics/analytics-repository.test.js` (add tests for `getBrandValueAnalytics`)
  - `apps/api/test/modules/analytics/analytics-endpoints.test.js` (add tests for new endpoint)
- No SQL migration files.
- Analytics feature module directory structure after this story:
  ```
  apps/mobile/lib/src/features/analytics/
  ├── models/
  │   └── wear_log.dart (Story 5.1)
  ├── screens/
  │   ├── analytics_dashboard_screen.dart (modified)
  │   └── wear_calendar_screen.dart (Story 5.3)
  ├── services/
  │   └── wear_log_service.dart (Story 5.1)
  └── widgets/
      ├── ai_insights_section.dart (Story 5.7)
      ├── brand_value_section.dart (NEW)
      ├── category_distribution_section.dart (Story 5.6)
      ├── cpw_item_row.dart (Story 5.4)
      ├── day_detail_bottom_sheet.dart (Story 5.3)
      ├── log_outfit_bottom_sheet.dart (Story 5.1)
      ├── month_summary_row.dart (Story 5.3)
      ├── neglected_items_section.dart (Story 5.5)
      ├── summary_cards_row.dart (Story 5.4)
      ├── top_worn_section.dart (Story 5.5)
      └── wear_frequency_section.dart (Story 5.6)
  ```

### Technical Requirements

- **Analytics repository extension:** Add `getBrandValueAnalytics` method to the existing `createAnalyticsRepository` return object. Same pattern: `pool.connect()` -> `client.query("SELECT set_config('app.current_user_id', $1, true)", [authContext.userId])` -> query -> `client.release()` in try/finally.
- **SQL aggregation:** `GROUP BY brand HAVING COUNT(*) >= 3`. Use `AVG(CASE WHEN purchase_price IS NOT NULL AND wear_count > 0 THEN purchase_price / wear_count ELSE NULL END)` for average CPW (excludes items without prices or wears from the average). `ORDER BY avg_cpw ASC NULLS LAST` ranks brands with pricing data first.
- **Category filter:** Parameterized WHERE clause: `AND category = $2` when category is provided. Validate against `VALID_CATEGORIES` from taxonomy.js to prevent injection.
- **Premium gating:** Use `premiumGuard.requirePremium(authContext)` from `apps/api/src/modules/billing/premium-guard.js` (Story 7.2). This throws 403 with `PREMIUM_REQUIRED` code for free users. Client-side uses `PremiumGateCard` from `apps/mobile/lib/src/core/widgets/premium_gate_card.dart` (Story 7.2).
- **CPW color coding:** Reuse the same thresholds from Story 5.4: green < 5, yellow 5-20, red > 20. Define as constants (they already exist in `CpwItemRow`; extract or duplicate for `BrandValueSection`).
- **Currency formatting:** Reuse the same pattern from `SummaryCardsRow` (Story 5.4): map dominant currency (GBP -> "£", EUR -> "€", USD -> "$") via `intl` package `NumberFormat.currency()`. Format CPW to 2 decimal places, total spent with no decimals.
- **Category filter chips:** `ChoiceChip` from `material.dart` -- same pattern as `TopWornSection` (Story 5.5). Capitalize category names for display using `category[0].toUpperCase() + category.substring(1)`.
- **Brand row layout:** Similar to `CpwItemRow` (Story 5.4) and `TopWornSection` rows (Story 5.5). Rank badge: circular container (#4F46E5 background, white text). Brand name bold, metrics in secondary text.
- **Brand wardrobe navigation:** `Navigator.push(MaterialPageRoute(builder: (_) => WardrobeScreen(...)))` with brand filter. Story 2.5 established `WardrobeScreen` accepts filter parameters and calls `GET /v1/items?brand=<brand>` with server-side filtering.

### Architecture Compliance

- **Server authority for analytics data:** Brand aggregations (avg CPW, total spent, total wears, 3-item minimum) are computed server-side via SQL. The client displays pre-computed results.
- **RLS enforces data isolation:** Brand value endpoint is RLS-scoped via `set_config`. A user can only see their own brand analytics.
- **Premium gating enforced server-side:** `premiumGuard.requirePremium()` checks `profiles.is_premium` with lazy subscription expiry. Client-side gate is for UX only; the API is the authoritative gate.
- **Mobile boundary owns presentation:** The API returns raw data (brand names, counts, averages). The client handles layout (ranked list, filter chips, color coding, currency formatting).
- **No new AI calls:** This story is purely data aggregation + UI display.
- **API module placement:** New method goes in existing `apps/api/src/modules/analytics/analytics-repository.js`. New route goes in `apps/api/src/main.js`.
- **JSON REST over HTTPS:** `GET /v1/analytics/brand-value?category=<optional>` follows the existing analytics endpoint naming convention.

### Library / Framework Requirements

- No new dependencies. All functionality uses packages already in `pubspec.yaml`:
  - `flutter/material.dart` -- `ChoiceChip`, `InkWell`, `CustomScrollView`, `SliverToBoxAdapter`
  - `intl: ^0.19.0` -- currency formatting
  - `cached_network_image` -- not needed (brand rows don't have thumbnails)
- API side: no new npm dependencies. Uses existing `pool` from `pg` and `premiumGuard` from billing module.

### File Structure Requirements

- New mobile widget goes in `apps/mobile/lib/src/features/analytics/widgets/` alongside existing analytics widgets.
- Test file mirrors source structure under `apps/mobile/test/features/analytics/widgets/`.
- API tests extend existing test files in `apps/api/test/modules/analytics/`.

### Testing Requirements

- **API repository tests** must verify:
  - Brand rankings sorted by avg CPW ascending
  - 3-item minimum threshold enforced
  - Correct avg CPW, total spent, total wears calculations
  - Category filter restricts aggregation scope
  - Category filter still applies 3-item minimum within category
  - Available categories list populated correctly
  - bestValueBrand and mostInvestedBrand computed correctly
  - Handles brands with no priced items (null CPW)
  - RLS enforcement (user isolation)
  - Edge cases: empty wardrobe, no branded items, all brands < 3 items, invalid category
- **API endpoint tests** must verify:
  - 200 responses with correct JSON structure for premium user
  - 401 for unauthenticated requests
  - 403 with PREMIUM_REQUIRED for free user
  - 400 for invalid category parameter
  - Category filter works correctly
  - Empty results for qualifying edge cases
- **Mobile widget tests** must verify:
  - PremiumGateCard renders for free users
  - Brand list renders for premium users with correct data
  - Summary metrics render best value and most invested brands
  - Category filter chips render and trigger callbacks
  - CPW color coding matches thresholds
  - Brand tap triggers navigation callback
  - Empty state renders correctly
  - No-price state renders correctly
  - Semantics labels present
- **Dashboard integration tests** must verify:
  - BrandValueSection appears below WearFrequencySection for premium
  - PremiumGateCard appears for free user
  - Category filter triggers isolated re-fetch
  - Premium user triggers 7 parallel API calls; free user triggers 6
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1476+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 1046+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 5.6** (done) established: `CategoryDistributionSection` and `WearFrequencySection` in analytics widgets. Dashboard fetches 6 endpoints in parallel via `Future.wait`. `fl_chart` dependency for charts. Category color map. Test baselines at that point: 419 API tests, 922 Flutter tests.
- **Story 5.7** (done) established: `AiInsightsSection` with premium/free-teaser states. `analytics-summary-service.js` with premium check. Pattern for premium-only analytics: free users see teaser, premium users get data. `GET /v1/analytics/ai-summary` endpoint. `aiUsageLogRepo` usage logging.
- **Story 7.2** (done) established: `PremiumGateCard` reusable widget at `apps/mobile/lib/src/core/widgets/premium_gate_card.dart`. `premiumGuard` utility at `apps/api/src/modules/billing/premium-guard.js` with `checkPremium()` and `requirePremium()` methods. `PremiumState` class, `isPremiumCached` getter on `SubscriptionService`. Premium gating matrix documented: "Advanced analytics (brand, sustainability, gap, seasonal): Premium-only." `subscriptionService.presentPaywallIfNeeded()` for paywall CTA.
- **Story 5.5** (done) established: `TopWornSection` with `ChoiceChip` period filters and ranked list pattern. `_loadTopWorn(period)` for isolated re-fetch on filter change. Pattern for section-specific re-fetch without refreshing entire dashboard.
- **Story 5.4** (done) established: `AnalyticsDashboardScreen`, `SummaryCardsRow`, `CpwItemRow`. CPW color thresholds (green < 5, yellow 5-20, red > 20). Currency formatting pattern. `_navigateToItemDetail` for item tap navigation. `analytics-repository.js` with factory pattern.
- **Story 2.5** (done) established: `WardrobeScreen` with server-side filtering. `GET /v1/items` supports `brand` filter parameter. This enables the brand-tap-to-wardrobe navigation.
- **Story 2.4** (done) established: `items.brand` column (TEXT, nullable) via migration 009. `WardrobeItem.brand` field in the mobile model. Brand is optional user-entered metadata.
- **AnalyticsDashboardScreen constructor (as of Story 7.2):** Includes `subscriptionService` as an optional parameter (added for AI Insights premium gate wiring).
- **Key patterns from prior stories:**
  - DI via optional constructor parameters with null defaults for test injection.
  - Error states with retry button (existing dashboard pattern).
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repository methods.
  - Semantics labels on all interactive elements (minimum 44x44 touch targets).
  - Section headers: 16px bold, #1F2937.
  - Empty state icons: 32px, #9CA3AF with descriptive text.
  - `ChoiceChip` for filters with primary color (#4F46E5) highlight.
  - `PremiumGateCard` for free-user premium feature gates.
- **Items table columns (current):** `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`, `brand`, `purchase_price`, `purchase_date`, `currency`, `is_favorite`, `neglect_status`, `wear_count`, `last_worn_date`, `created_at`, `updated_at`.
- **Current test baselines (from Story 10.3):** 1046+ API tests, 1476+ Flutter tests.

### Key Anti-Patterns to Avoid

- DO NOT compute brand analytics client-side by fetching all items via `GET /v1/items` and aggregating in Dart. Use the dedicated server-side endpoint.
- DO NOT skip premium gating. This is an "advanced analytics" feature that MUST be premium-only per the architecture and Story 7.2 premium matrix.
- DO NOT call the brand value API for free users. Check `isPremiumCached` before making the call. Free users see `PremiumGateCard` only.
- DO NOT re-fetch the entire dashboard when only the brand category filter changes. Use the isolated `_loadBrandValue(category)` pattern.
- DO NOT add charting libraries or use `fl_chart` for this section. Brand rankings are a list, not a chart.
- DO NOT create a new screen for brand analytics. It is a section within the existing `AnalyticsDashboardScreen`.
- DO NOT modify the `items` table schema or any existing migration files.
- DO NOT modify existing API endpoints or repository methods. Only add new methods.
- DO NOT use `setState` inside `async` gaps without checking `mounted` first.
- DO NOT lower the 3-item brand minimum threshold. FR-BRD-03 explicitly requires 3+ items.
- DO NOT include brands with empty string or null `brand` values. The SQL WHERE clause must filter these out: `WHERE brand IS NOT NULL AND brand != ''`.
- DO NOT create a separate brand analytics service. The analytics repository method is sufficient for this data aggregation story (no AI involved).
- DO NOT forget to capitalize category names for display in filter chips.
- DO NOT hardcode the currency symbol. Use the `dominantCurrency` from the brand data response.

### Out of Scope

- **Sustainability Scoring & CO2 Savings (FR-SUS-*):** Story 11.2.
- **Wardrobe Gap Analysis (FR-GAP-*):** Story 11.3.
- **Seasonal Reports & Heatmaps (FR-SEA-*, FR-HMP-*):** Story 11.4.
- **Brand logo/icon display:** No FR requires brand logos. Use text-only display.
- **Brand comparison across users:** No social/community analytics in this story.
- **Historical brand value tracking (trends over time):** Not required by any FR.
- **Brand recommendations or suggestions:** Not part of FR-BRD-01/02/03.
- **Offline analytics viewing:** Out of scope for V1.
- **Export/share brand analytics:** Not required by any FR.
- **Tab restructuring of analytics dashboard:** The vertical scroll pattern continues.
- **AI-powered brand analysis or recommendations:** No Gemini usage in this story.

### References

- [Source: epics.md - Story 11.1: Brand Value Analytics]
- [Source: epics.md - FR-BRD-01: The analytics dashboard shall include a "Brand Value" section showing: brand name, average CPW, total spent, and total wears, ranked by best value]
- [Source: epics.md - FR-BRD-02: Brand analytics shall be filterable by category (e.g., "Best value sneakers brand")]
- [Source: epics.md - FR-BRD-03: Brands shall only appear with a minimum of 3 items]
- [Source: architecture.md - Gated features include... advanced analytics]
- [Source: architecture.md - Epic 11 Advanced Analytics -> mobile/features/analytics, api/modules/analytics, api/modules/ai]
- [Source: architecture.md - Server authority for sensitive rules: analytics computed server-side]
- [Source: architecture.md - API style: JSON REST over HTTPS]
- [Source: 7-2-premium-feature-access-enforcement.md - premiumGuard utility, PremiumGateCard widget, premium gating matrix: "Advanced analytics: Premium-only"]
- [Source: 5-7-ai-generated-analytics-summary.md - AiInsightsSection with premium/free-teaser pattern, premium analytics endpoint pattern]
- [Source: 5-5-top-worn-neglected-items-analytics.md - ChoiceChip filter pattern, isolated section re-fetch pattern, ranked list pattern]
- [Source: 5-4-basic-wardrobe-value-analytics.md - AnalyticsDashboardScreen, analytics-repository.js factory pattern, CPW color thresholds, currency formatting]
- [Source: 5-6-category-distribution-charts.md - WearFrequencySection (section above brand value), dashboard with 6 parallel API calls]
- [Source: 2-5-wardrobe-grid-filtering.md - WardrobeScreen with server-side brand filter, GET /v1/items?brand=<brand>]
- [Source: 2-4-manual-metadata-editing-creation.md - items.brand column (TEXT, nullable), migration 009]
- [Source: apps/api/src/modules/analytics/analytics-repository.js - existing 6 analytics methods]
- [Source: apps/api/src/modules/billing/premium-guard.js - requirePremium(), checkPremium()]
- [Source: apps/mobile/lib/src/core/widgets/premium_gate_card.dart - PremiumGateCard widget]
- [Source: apps/api/src/modules/ai/taxonomy.js - VALID_CATEGORIES for category filter validation]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

### Completion Notes List

- Implemented `getBrandValueAnalytics` method in analytics-repository.js with SQL GROUP BY brand, HAVING COUNT(*) >= 3, optional category filter, bestValueBrand/mostInvestedBrand computation.
- Added `GET /v1/analytics/brand-value` route in main.js with premiumGuard.requirePremium() gating, category query param, 400 for invalid category.
- Added 18 unit tests for getBrandValueAnalytics in analytics-repository.test.js covering sorting, threshold, RLS, null CPW, category filter, bestValueBrand/mostInvestedBrand, invalid category.
- Added 7 integration tests for the brand-value endpoint in analytics-endpoints.test.js covering 200/401/403/400 responses, category filter, empty results, response structure.
- Added `getBrandValueAnalytics` method to ApiClient.dart with optional category parameter.
- Created BrandValueSection widget with premium gate, section header, summary metrics, category filter chips, ranked brand list with CPW color coding, empty state, no-price state, semantics labels.
- Integrated BrandValueSection into AnalyticsDashboardScreen with conditional 7th API call for premium users, _loadBrandValue for category filter re-fetch, _navigateToBrandWardrobe for brand tap navigation.
- Added 15 widget tests for BrandValueSection covering premium/free states, summary metrics, category filters, CPW color coding, brand tap, empty state, no-price state, semantics.
- Added 6 dashboard integration tests covering premium/free rendering, category filter isolated re-fetch, free user skips brand value API call, error state with 7 calls, premium data loading.
- All 1084 API tests pass (1059 baseline + 25 new). All 1514 Flutter tests pass (1493 baseline + 21 new). Zero new flutter analyze issues.

### Change Log

- 2026-03-19: Implemented Story 11.1 Brand Value Analytics - added GET /v1/analytics/brand-value endpoint (premium-gated), BrandValueSection widget, conditional 7th API call for premium users, 46 new tests.

### File List

- `apps/api/src/modules/analytics/analytics-repository.js` (modified: added getBrandValueAnalytics method, import VALID_CATEGORIES)
- `apps/api/src/main.js` (modified: added GET /v1/analytics/brand-value route with premium guard)
- `apps/api/test/modules/analytics/analytics-repository.test.js` (modified: added 18 getBrandValueAnalytics tests, updated mock pool)
- `apps/api/test/modules/analytics/analytics-endpoints.test.js` (modified: added 7 brand-value endpoint tests, added premiumGuard to buildContext)
- `apps/mobile/lib/src/core/networking/api_client.dart` (modified: added getBrandValueAnalytics method)
- `apps/mobile/lib/src/features/analytics/widgets/brand_value_section.dart` (new: BrandValueSection widget)
- `apps/mobile/lib/src/features/analytics/screens/analytics_dashboard_screen.dart` (modified: added brand value state, conditional 7th fetch, BrandValueSection sliver, _loadBrandValue, _navigateToBrandWardrobe)
- `apps/mobile/test/features/analytics/widgets/brand_value_section_test.dart` (new: 15 widget tests)
- `apps/mobile/test/features/analytics/screens/analytics_dashboard_screen_test.dart` (modified: added 6 brand value integration tests, updated mock HTTP client)
