# Story 7.3: AI Resale Listing Generation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want the AI to write a Vinted/Depop-optimized listing for an item I want to sell,
so that I save time on copywriting and improve my chances of a sale.

## Acceptance Criteria

1. Given I am on the item detail screen for a specific wardrobe item, when I tap "Generate Resale Listing", then the app calls `POST /v1/resale/generate` with the item ID, and the API invokes Gemini 2.0 Flash to analyze the item's metadata (category, color, material, pattern, style, brand), original image, purchase price, wear count, and CPW data, returning a structured listing containing: a catchy title, a detailed description, a condition estimate (New/Like New/Good/Fair), and targeted hashtags. (FR-RSL-02)

2. Given the API receives a resale listing generation request, when it processes the request, then it enforces usage limits via `premiumGuard.checkUsageQuota(authContext, { feature: "resale_listing", freeLimit: 2, period: "month" })`. Free users are limited to 2 generations per month; premium users get unlimited generations. If the free limit is reached, the API returns 429 with `{ error: "Rate Limit Exceeded", code: "RATE_LIMIT_EXCEEDED", message: "Free tier limit: 2 resale listings per month", monthlyLimit: 2, used: 2, remaining: 0, resetsAt: "<first of next month>" }`. (FR-RSL-02, NFR-SEC-05)

3. Given the generation succeeds, when the API returns the response, then it returns HTTP 200 with `{ listing: { title: string, description: string, conditionEstimate: string, hashtags: string[], platform: string }, item: { id, name, category, brand, photoUrl }, generatedAt: string }`. The listing is stored in a new `resale_listings` table for history. (FR-RSL-02)

4. Given the generation succeeds, when the mobile client displays the result, then the ResaleListingScreen shows: the item image, the generated title (editable), the generated description (editable), the condition estimate, the hashtags as chips, and action buttons: "Copy to Clipboard" and "Share". (FR-RSL-02, FR-RSL-03)

5. Given I tap "Copy to Clipboard", when the listing text is assembled, then the clipboard receives a formatted string: `"[title]\n\n[description]\n\nCondition: [conditionEstimate]\n\n[hashtags joined with spaces]"` and the app shows a brief "Copied!" snackbar confirmation. (FR-RSL-03)

6. Given I tap "Share", when the system share sheet opens, then the same formatted listing text is shared via the platform share sheet, allowing the user to send it to Vinted, Depop, or any other app. (FR-RSL-03)

7. Given the item's `resale_status` is currently NULL, when I generate a resale listing, then the item's `resale_status` is updated to `'listed'` in the `items` table and the "Circular Seller" badge eligibility is checked via `badgeService.checkAndAward(authContext, 'circular_seller')`. (FR-RSL-04, FR-GAM-04)

8. Given the Gemini call fails (network error, rate limit, timeout, unparseable response), when the API handles the error, then it returns HTTP 500 with `{ error: "Resale listing generation failed", code: "GENERATION_FAILED" }`, logs the failure to `ai_usage_log` with status "failure", and the mobile client shows an error message: "Unable to generate listing. Please try again." with a retry button. (NFR-REL-03)

9. Given the API processes a resale listing generation request, when the Gemini call completes, then the API logs the request to `ai_usage_log` with `feature = "resale_listing"`, model name, input/output tokens, latency in ms, estimated cost, and status "success" or "failure". (NFR-OBS-02)

10. Given the mobile app renders the "Generate Resale Listing" button on the item detail screen, when the user is a free-tier user who has used their 2 monthly listings, then the button shows "Go Premium for Unlimited Listings" and tapping it calls `subscriptionService.presentPaywallIfNeeded()` via the existing `PremiumGateCard` pattern. (FR-RSL-02)

11. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (639+ API tests, 1087+ Flutter tests) and new tests cover: resale listing generation API endpoint (success, failure, rate limits), Gemini prompt construction and response parsing, resale listing model, ResaleListingScreen widget, item detail screen integration, clipboard/share actions, badge eligibility check, and `resale_listings` table migration.

## Tasks / Subtasks

- [x] Task 1: Database migration for `resale_listings` table and `resale_status` column on `items` (AC: 3, 7)
  - [x] 1.1: Create `infra/sql/migrations/022_resale_listings.sql`. Create `app_public.resale_listings` table: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `profile_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE`, `title TEXT NOT NULL`, `description TEXT NOT NULL`, `condition_estimate TEXT NOT NULL CHECK (condition_estimate IN ('New', 'Like New', 'Good', 'Fair'))`, `hashtags TEXT[] DEFAULT '{}'`, `platform TEXT DEFAULT 'general'`, `created_at TIMESTAMPTZ DEFAULT now()`. Add RLS policy: `CREATE POLICY resale_listings_user_policy ON app_public.resale_listings FOR ALL USING (profile_id IN (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id', true)))`. Add index: `CREATE INDEX idx_resale_listings_profile ON app_public.resale_listings(profile_id, created_at DESC)`. Add index: `CREATE INDEX idx_resale_listings_item ON app_public.resale_listings(item_id)`.
  - [x] 1.2: In the same migration, add `resale_status` column to `items`: `ALTER TABLE app_public.items ADD COLUMN IF NOT EXISTS resale_status TEXT CHECK (resale_status IN ('listed', 'sold', 'donated')) DEFAULT NULL`. Add SQL comment: `-- Tracks resale lifecycle: NULL (not for sale), listed (generated listing), sold (item sold), donated (item donated). FR-RSL-04`.
  - [x] 1.3: Add index on `resale_status` for future filtering: `CREATE INDEX idx_items_resale_status ON app_public.items(resale_status) WHERE resale_status IS NOT NULL`.

- [x] Task 2: API -- Create resale listing generation service (AC: 1, 3, 8, 9)
  - [x] 2.1: Create `apps/api/src/modules/resale/resale-listing-service.js` with `createResaleListingService({ geminiClient, itemRepo, aiUsageLogRepo, pool })`. Follow the exact factory pattern of `createCategorizationService` in `apps/api/src/modules/ai/categorization-service.js`.
  - [x] 2.2: Implement `async generateListing(authContext, { itemId })` method. Steps: (a) check `geminiClient.isAvailable()` -- if false, throw `{ statusCode: 503, message: "AI service unavailable" }`, (b) fetch the item via `itemRepo.getItem(authContext, itemId)` -- if not found or not owned, throw 404, (c) fetch additional item data (wear_count, last_worn_date, purchase_price) with a direct query: `SELECT wear_count, last_worn_date, purchase_price, currency FROM app_public.items WHERE id = $1` (these fields aren't all in mapItemRow output but are needed for the Gemini prompt), (d) build the Gemini prompt (see Task 2.4), (e) call Gemini 2.0 Flash with `responseMimeType: "application/json"`, (f) parse and validate response, (g) persist listing to `resale_listings` table, (h) update item `resale_status` to `'listed'` if currently NULL (do NOT overwrite 'sold' or 'donated'), (i) log usage to `ai_usage_log`, (j) return the listing object with item metadata.
  - [x] 2.3: For the image analysis, download the item's image (use `photoUrl` or `originalPhotoUrl`) and convert to base64 for the Gemini call. Follow the exact same pattern as `categorization-service.js` for fetching and encoding the image.
  - [x] 2.4: Construct the Gemini prompt:
    ```
    You are a resale listing copywriter specializing in Vinted and Depop. Generate an optimized listing for this clothing item.

    ITEM METADATA:
    - Category: {category}
    - Primary Color: {color}
    - Secondary Colors: {secondaryColors}
    - Pattern: {pattern}
    - Material: {material}
    - Style: {style}
    - Brand: {brand || "Unbranded"}
    - Season: {season}
    - Occasion: {occasion}
    - Purchase Price: {purchasePrice} {currency}
    - Times Worn: {wearCount}
    - Days Since Last Worn: {daysSinceLastWorn}

    RULES:
    1. Title: Catchy, SEO-friendly, max 80 chars. Include brand if known, category, and a selling point.
    2. Description: 3-5 sentences. Highlight condition, material quality, versatility, and styling tips. Be honest but positive.
    3. Condition Estimate: Based on wear count and age. "New" (0 wears), "Like New" (1-5 wears), "Good" (6-20 wears), "Fair" (20+ wears).
    4. Hashtags: 5-10 relevant hashtags (without # prefix) for Vinted/Depop SEO. Include brand, category, style, color, and trending fashion tags.

    Analyze the item image for additional details about condition, quality, and visual appeal.

    Return ONLY valid JSON:
    {
      "title": "Catchy listing title",
      "description": "Detailed listing description...",
      "conditionEstimate": "one of: New, Like New, Good, Fair",
      "hashtags": ["hashtag1", "hashtag2", ...],
      "platform": "general"
    }
    ```
  - [x] 2.5: Parse and validate the Gemini response: (a) extract JSON from `response.candidates[0].content.parts[0].text`, (b) `JSON.parse`, (c) validate `title` is non-empty string (max 80 chars, truncate if longer), (d) validate `description` is non-empty string, (e) validate `conditionEstimate` is one of `['New', 'Like New', 'Good', 'Fair']` -- default to `'Good'` if invalid, (f) validate `hashtags` is array of strings -- default to empty array if invalid, filter to max 10. (g) Set `platform` to `'general'` if missing.
  - [x] 2.6: Persist the listing: INSERT INTO `app_public.resale_listings` with RLS context set via `set_config('app.current_user_id', authContext.userId, true)`. Return the inserted row's `id`.
  - [x] 2.7: Log AI usage following the `categorization-service.js` pattern: extract `usageMetadata` from Gemini response, compute `estimateCost()`, call `aiUsageLogRepo.logUsage(authContext, { feature: "resale_listing", model: "gemini-2.0-flash", inputTokens, outputTokens, latencyMs, estimatedCostUsd, status: "success" })`. On failure, log with `status: "failure"`.
  - [x] 2.8: Error handling: wrap the entire method in try/catch. On Gemini failure, log usage with "failure" status and re-throw with `{ statusCode: 500, message: "Resale listing generation failed" }`.

- [x] Task 3: API -- Add `POST /v1/resale/generate` endpoint with premium gating (AC: 1, 2, 3, 8)
  - [x] 3.1: Add route `POST /v1/resale/generate` to `apps/api/src/main.js`. Place it after the subscription/billing routes and before `notFound`. The route: authenticates the user via `requireAuth`, reads the request body (`{ itemId }`), calls `premiumGuard.checkUsageQuota(authContext, { feature: "resale_listing", freeLimit: FREE_LIMITS.RESALE_LISTING_MONTHLY, period: "month" })`, if `!allowed` returns 429 with the quota details, otherwise calls `resaleListingService.generateListing(authContext, { itemId: body.itemId })`, and returns 200 with the result.
  - [x] 3.2: Wire up `resaleListingService` in `createRuntime()`: instantiate `createResaleListingService({ geminiClient, itemRepo: itemRepository, aiUsageLogRepo, pool })` and add it to the runtime object. Import `FREE_LIMITS` from `premium-guard.js`. Destructure `resaleListingService` in `handleRequest`.
  - [x] 3.3: After successful generation, log the AI usage to `ai_usage_log` with feature `"resale_listing"` (this is done inside the service in Task 2.7, so the route handler just returns the result).
  - [x] 3.4: After successful generation, check badge eligibility: call `badgeService.checkAndAward(authContext, 'circular_seller')` best-effort (try/catch, do NOT block response). The "Circular Seller" badge requires 1+ item listed for resale.

- [x] Task 4: API -- Update items repository to include `resale_status` (AC: 7)
  - [x] 4.1: Update `mapItemRow` in `apps/api/src/modules/items/repository.js` to include: `resaleStatus: row.resale_status ?? null`.
  - [x] 4.2: Update `updateItem` to support `resaleStatus` field: add `resale_status` to the dynamic SET clause.
  - [x] 4.3: Update `listItems` to support filtering by `resaleStatus` if provided.

- [x] Task 5: Mobile -- Create ResaleListing model (AC: 3, 4)
  - [x] 5.1: Create `apps/mobile/lib/src/features/resale/models/resale_listing.dart` with a `ResaleListing` class. Fields: `String id`, `String title`, `String description`, `String conditionEstimate`, `List<String> hashtags`, `String platform`, `DateTime generatedAt`. Include `factory ResaleListing.fromJson(Map<String, dynamic> json)` and `Map<String, dynamic> toJson()`.
  - [x] 5.2: Create `ResaleListingResult` class in the same file. Fields: `ResaleListing listing`, `ResaleListingItem item`. Include `factory ResaleListingResult.fromJson(Map<String, dynamic> json)`.
  - [x] 5.3: Create `ResaleListingItem` helper class. Fields: `String id`, `String? name`, `String? category`, `String? brand`, `String? photoUrl`. Include `fromJson`.

- [x] Task 6: Mobile -- Create ResaleListingService (AC: 1, 2, 10)
  - [x] 6.1: Create `apps/mobile/lib/src/features/resale/services/resale_listing_service.dart` with a `ResaleListingService` class. Constructor accepts `ApiClient`.
  - [x] 6.2: Implement `Future<ResaleListingResult?> generateListing(String itemId)` that: (a) calls `_apiClient.authenticatedPost("/v1/resale/generate", body: { "itemId": itemId })`, (b) parses the response into `ResaleListingResult`, (c) returns `null` on any error. On 429 error, rethrow as a specific `UsageLimitException` so the UI can show the paywall.
  - [x] 6.3: Add `Future<Map<String, dynamic>> generateResaleListing(Map<String, dynamic> body)` to `apps/mobile/lib/src/core/networking/api_client.dart`. Calls `authenticatedPost("/v1/resale/generate", body: body)`.

- [x] Task 7: Mobile -- Create ResaleListingScreen (AC: 4, 5, 6)
  - [x] 7.1: Create `apps/mobile/lib/src/features/resale/screens/resale_listing_screen.dart` with a `ResaleListingScreen` StatefulWidget. Constructor accepts `WardrobeItem item` and optional `ResaleListingService? resaleListingService` and `SubscriptionService? subscriptionService`.
  - [x] 7.2: Screen layout following Vibrant Soft-UI design system: (a) AppBar with "Resale Listing" title and back button. (b) Item image at top (200px height, rounded corners, `CachedNetworkImage`). (c) Loading state: shimmer placeholder matching listing layout while generating. (d) Success state: editable `TextFormField` for title (max 80 chars), editable `TextFormField` for description (multiline, max 500 chars), condition estimate as a read-only chip with color coding (New=#10B981, Like New=#3B82F6, Good=#F59E0B, Fair=#EF4444), hashtags as a horizontal `Wrap` of `Chip` widgets, two action buttons at bottom: "Copy to Clipboard" (`Icons.content_copy`, outlined style) and "Share" (`Icons.share`, filled #4F46E5 style). (e) Error state: error message with "Try Again" button.
  - [x] 7.3: Implement `_copyToClipboard()`: format listing as `"$title\n\n$description\n\nCondition: $conditionEstimate\n\n${hashtags.map((h) => '#$h').join(' ')}"`, copy via `Clipboard.setData(ClipboardData(text: formatted))`, show `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied to clipboard!')))`.
  - [x] 7.4: Implement `_shareListing()`: use same formatted text, call `Share.share(formatted)` from the `share_plus` package (already a dependency if available) OR use `Clipboard.setData` + system share sheet via `Share.share` from platform channels. If `share_plus` is NOT already a dependency, use the platform's native share sheet via a method channel or add `share_plus` as the first new dependency in this story.
  - [x] 7.5: Add `Semantics` labels: "Resale listing for [item name]" on the screen, "Copy listing to clipboard" on copy button, "Share listing" on share button, "Listing title" on title field, "Listing description" on description field.
  - [x] 7.6: On `initState`, automatically trigger `_generateListing()` which calls the service and transitions from loading to success/error state. Use `mounted` guard before `setState`.

- [x] Task 8: Mobile -- Integrate resale listing into item detail screen (AC: 1, 10)
  - [x] 8.1: Update the item detail screen (likely `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart` or equivalent) to add a "Generate Resale Listing" button. Place it in the actions section, below existing action buttons. Style: outlined button with `Icons.sell` icon, text "Generate Resale Listing", full width, 44px height, #4F46E5 border color.
  - [x] 8.2: When tapped, check if the user can generate (use cached premium state or make a lightweight check). Navigate to `ResaleListingScreen(item: currentItem)` via `Navigator.push`.
  - [x] 8.3: If the item already has `resaleStatus == 'listed'`, show the button as "Regenerate Listing" with a subtle "(already listed)" label. Still allow regeneration.
  - [x] 8.4: If the item has `resaleStatus == 'sold'` or `resaleStatus == 'donated'`, hide the generate button (item is no longer available for listing).
  - [x] 8.5: After returning from `ResaleListingScreen`, refresh the item detail to reflect any `resaleStatus` change.

- [x] Task 9: Mobile -- Update WardrobeItem model for `resaleStatus` (AC: 7)
  - [x] 9.1: Update `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`: Add field `String? resaleStatus`. Add `fromJson` parsing: `resaleStatus: json["resaleStatus"] as String? ?? json["resale_status"] as String?`. Add to `toJson`. Add getters: `bool get isListedForResale => resaleStatus == 'listed'`, `bool get isSold => resaleStatus == 'sold'`, `bool get isDonated => resaleStatus == 'donated'`.

- [x] Task 10: Mobile -- Handle usage limit exceeded with paywall (AC: 2, 10)
  - [x] 10.1: In `ResaleListingScreen`, when `ResaleListingService.generateListing` throws a `UsageLimitException` (429 response), display a `PremiumGateCard` (from `apps/mobile/lib/src/core/widgets/premium_gate_card.dart`) with `title: "Resale Listing Limit Reached"`, `subtitle: "Free users get 2 AI listings per month. Go Premium for unlimited."`, `icon: Icons.sell`, `subscriptionService: widget.subscriptionService`. This replaces the loading/error state.
  - [x] 10.2: After a successful paywall purchase (listen via `subscriptionService.addCustomerInfoUpdateListener`), auto-retry the generation.

- [x] Task 11: API -- Unit tests for resale listing generation service (AC: 1, 3, 8, 9, 11)
  - [x] 11.1: Create `apps/api/test/modules/resale/resale-listing-service.test.js`:
    - `generateListing` calls Gemini with correct prompt containing item metadata and image.
    - `generateListing` returns validated listing with title, description, conditionEstimate, hashtags.
    - `generateListing` persists listing to `resale_listings` table.
    - `generateListing` updates item `resale_status` to 'listed' when NULL.
    - `generateListing` does NOT overwrite `resale_status` when already 'sold' or 'donated'.
    - `generateListing` throws 503 when Gemini is unavailable.
    - `generateListing` logs successful usage to `ai_usage_log` with feature "resale_listing".
    - `generateListing` logs failure to `ai_usage_log` when Gemini call fails.
    - `generateListing` handles unparseable Gemini JSON gracefully.
    - `generateListing` validates conditionEstimate against allowed values, defaults to 'Good'.
    - `generateListing` truncates title to 80 chars if too long.
    - `generateListing` caps hashtags at 10.
    - `generateListing` throws 404 when item not found or not owned.

- [x] Task 12: API -- Integration tests for `POST /v1/resale/generate` endpoint (AC: 1, 2, 3, 8, 11)
  - [x] 12.1: Create `apps/api/test/modules/resale/resale-generation.test.js`:
    - `POST /v1/resale/generate` requires authentication (401 without token).
    - `POST /v1/resale/generate` returns 200 with listing on success.
    - `POST /v1/resale/generate` returns correct response structure (listing, item, generatedAt).
    - `POST /v1/resale/generate` returns 429 when free user exceeds monthly limit.
    - `POST /v1/resale/generate` allows unlimited for premium user.
    - `POST /v1/resale/generate` returns 404 for non-existent item.
    - `POST /v1/resale/generate` returns 503 when Gemini is unavailable.
    - `POST /v1/resale/generate` returns 500 when Gemini call fails.
    - `POST /v1/resale/generate` checks badge eligibility after success.

- [x] Task 13: Mobile -- Unit tests for ResaleListing model (AC: 3, 11)
  - [x] 13.1: Create `apps/mobile/test/features/resale/models/resale_listing_test.dart`:
    - `ResaleListing.fromJson()` correctly parses all fields.
    - `ResaleListing.toJson()` serializes all fields.
    - `ResaleListingResult.fromJson()` parses listing and item.
    - `ResaleListingItem.fromJson()` handles null brand and photoUrl.

- [x] Task 14: Mobile -- Unit tests for ResaleListingService (AC: 1, 2, 11)
  - [x] 14.1: Create `apps/mobile/test/features/resale/services/resale_listing_service_test.dart`:
    - `generateListing` calls API with correct item ID.
    - `generateListing` returns parsed ResaleListingResult on success.
    - `generateListing` returns null on API error (non-429).
    - `generateListing` throws UsageLimitException on 429 response.

- [x] Task 15: Mobile -- Widget tests for ResaleListingScreen (AC: 4, 5, 6, 11)
  - [x] 15.1: Create `apps/mobile/test/features/resale/screens/resale_listing_screen_test.dart`:
    - Shows loading shimmer during generation.
    - Displays listing title, description, condition, and hashtags on success.
    - "Copy to Clipboard" button copies formatted text.
    - "Share" button triggers share action.
    - Error state shows "Try Again" button.
    - Usage limit exceeded shows PremiumGateCard.
    - Semantics labels present for all interactive elements.

- [x] Task 16: Mobile -- Widget tests for item detail screen resale integration (AC: 1, 10, 11)
  - [x] 16.1: Update item detail screen tests:
    - "Generate Resale Listing" button is visible for items with null resaleStatus.
    - "Regenerate Listing" button shown for items with resaleStatus 'listed'.
    - Button hidden for items with resaleStatus 'sold' or 'donated'.
    - Tapping button navigates to ResaleListingScreen.

- [x] Task 17: Mobile -- Update WardrobeItem model tests (AC: 7, 11)
  - [x] 17.1: Update `apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart`:
    - `WardrobeItem.fromJson` parses `resaleStatus` field.
    - `isListedForResale`, `isSold`, `isDonated` getters work correctly.

- [x] Task 18: Regression testing (AC: all)
  - [x] 18.1: Run `flutter analyze` -- zero new issues.
  - [x] 18.2: Run `flutter test` -- all existing 1087+ tests plus new tests pass.
  - [x] 18.3: Run `npm --prefix apps/api test` -- all existing 639+ API tests plus new tests pass.
  - [x] 18.4: Verify existing item detail screen functionality is preserved (all existing buttons and actions still work).
  - [x] 18.5: Verify existing premium gating (outfit generation, AI analytics summary) still works.
  - [x] 18.6: Verify wardrobe grid and filtering still works with the new `resale_status` column.

## Dev Notes

- This is the THIRD story in Epic 7 (Resale Integration & Subscription). It introduces AI-powered resale listing generation, building on the premium infrastructure from Stories 7.1 (RevenueCat subscription) and 7.2 (premium guard, usage quota enforcement, PremiumGateCard widget). The `premiumGuard.checkUsageQuota` with `period: "month"` and `FREE_LIMITS.RESALE_LISTING_MONTHLY = 2` is already built and exported from Story 7.2 -- use it directly.
- The primary FRs covered are FR-RSL-02 (AI-powered resale listing generation) and FR-RSL-03 (copy/share listing). FR-RSL-04 (resale_status tracking) is partially covered by setting status to 'listed' on generation.
- **FR-RSL-01 (identify resale candidates) is OUT OF SCOPE.** Epic 13 handles smart resale suggestions and monthly prompts.
- **FR-RSL-04 (full resale lifecycle: listed -> sold) is partially OUT OF SCOPE.** This story only sets `resale_status = 'listed'`. Story 7.4 handles the full status tracking and history.
- **FR-RSL-05, FR-RSL-06 (monthly resale prompts) are OUT OF SCOPE.** Epic 13 handles these.
- **FR-RSL-07, FR-RSL-08 (resale history and earnings chart) are OUT OF SCOPE.** Story 7.4 handles these.
- **FR-RSL-09 (Circular Champion badge for 10+ sold) is OUT OF SCOPE.** That requires tracking sold status (Story 7.4). This story only awards the "Circular Seller" badge (1+ listed).
- **FR-RSL-10 (resale status sync back to items table) is COVERED** for the 'listed' status change. Full sync is Story 7.4.

### Design Decision: Separate `resale_listings` Table vs. Inline on Items

A dedicated `resale_listings` table is used (rather than JSONB on the items table) because: (1) a user may regenerate listings multiple times, and we want to keep history; (2) the listing data is a separate domain entity; (3) Story 7.4 will add `resale_history` for sold items which references `resale_listings`. The `items.resale_status` column is the lightweight state tracker while `resale_listings` holds the full content.

### Design Decision: Usage Limit Enforcement Pattern

This story uses `premiumGuard.checkUsageQuota(authContext, { feature: "resale_listing", freeLimit: 2, period: "month" })` which was already built in Story 7.2. The `checkUsageQuota` method queries `ai_usage_log` for the count of successful "resale_listing" entries in the current month. This means the service MUST log to `ai_usage_log` with `feature: "resale_listing"` and `status: "success"` for the count to work. The quota check happens in the route handler BEFORE calling the service, matching the pattern from outfit generation limits.

### Design Decision: Condition Estimate Logic

The Gemini prompt includes wear count data to help estimate condition, but the AI makes the final call based on both metadata and visual image analysis. The prompt provides guidelines: New (0 wears), Like New (1-5), Good (6-20), Fair (20+). The AI may override based on visual inspection (e.g., visible wear). The response is validated against the 4 allowed values.

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/022_resale_listings.sql` (resale_listings table, resale_status column on items)
  - `apps/api/src/modules/resale/resale-listing-service.js` (listing generation service)
  - `apps/api/test/modules/resale/resale-listing-service.test.js`
  - `apps/api/test/modules/resale/resale-generation.test.js` (integration tests)
- New mobile files:
  - `apps/mobile/lib/src/features/resale/models/resale_listing.dart` (ResaleListing, ResaleListingResult, ResaleListingItem)
  - `apps/mobile/lib/src/features/resale/services/resale_listing_service.dart` (ResaleListingService)
  - `apps/mobile/lib/src/features/resale/screens/resale_listing_screen.dart` (ResaleListingScreen)
  - `apps/mobile/test/features/resale/models/resale_listing_test.dart`
  - `apps/mobile/test/features/resale/services/resale_listing_service_test.dart`
  - `apps/mobile/test/features/resale/screens/resale_listing_screen_test.dart`
- Modified API files:
  - `apps/api/src/main.js` (add POST /v1/resale/generate route, wire up resaleListingService in createRuntime, add to handleRequest destructuring)
  - `apps/api/src/modules/items/repository.js` (add resaleStatus to mapItemRow, updateItem, listItems filter)
- Modified mobile files:
  - `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` (add resaleStatus field, getters)
  - `apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart` (add "Generate Resale Listing" button)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add generateResaleListing method)
  - `apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart` (add resaleStatus tests)

### Technical Requirements

- **New API endpoint:** `POST /v1/resale/generate` -- accepts `{ itemId: string }`, returns `{ listing: {...}, item: {...}, generatedAt: "..." }` with HTTP 200. Requires authentication. Rate-limited: 2/month free, unlimited premium.
- **Gemini 2.0 Flash model identifier:** `gemini-2.0-flash` -- same model used for categorization and outfit generation.
- **Gemini JSON mode:** Use `generationConfig: { responseMimeType: "application/json" }` for structured output.
- **AI usage logging:** Feature name = `"resale_listing"`. Log to `ai_usage_log` with the same fields as categorization (model, tokens, latency, cost, status). CRITICAL: the feature name must match exactly because `premiumGuard.checkUsageQuota` counts by feature name.
- **Database tables:** `resale_listings` in `app_public` schema with RLS. `items.resale_status` column with CHECK constraint.
- **Badge check:** After successful generation, call `badgeService.checkAndAward(authContext, 'circular_seller')` best-effort. The badge definition already exists in migration 019 (`circular_seller`: "List 1 or more items for resale").
- **Image for Gemini:** Use the item's `photoUrl` (background-removed version if available) or `originalPhotoUrl` as fallback. Download and base64-encode for the multimodal Gemini call. Follow the exact same image handling pattern as `categorization-service.js`.

### Architecture Compliance

- **AI calls are brokered only by Cloud Run:** The mobile client sends the item ID to the API; the API fetches the item data, calls Gemini, and returns the result. The mobile client NEVER calls Gemini directly.
- **Server authority for premium gating:** Usage quota check happens server-side via `premiumGuard.checkUsageQuota`. The mobile client's premium state cache is for UI hints only.
- **Server authority for resale state:** The `resale_status` update happens server-side. The mobile client does not directly modify resale state.
- **Database boundary owns canonical state:** `resale_listings` stores persistent listing history. RLS enforces user-scoped access.
- **Mobile boundary owns presentation:** `ResaleListingScreen` handles all presentation: loading, success, error, clipboard, share.
- **Epic 7 component mapping:** `mobile/features/resale`, `api/modules/resale`, `api/modules/billing` -- matches the architecture's epic-to-component mapping.

### Library / Framework Requirements

- **API:** No new dependencies. Uses existing `@google-cloud/vertexai` (via shared `geminiClient`), `pg` (via pool), existing AI module, existing `premium-guard.js`.
- **Mobile:** May need `share_plus` package for the share sheet functionality. Check if already in `pubspec.yaml`. If not, add `share_plus: ^7.0.0` (latest stable). This would be the ONLY new dependency. For clipboard, use `dart:services` (`Clipboard.setData`), which requires no new package.

### File Structure Requirements

- `resale-listing-service.js` goes in `apps/api/src/modules/resale/` -- a new module directory for resale functionality. This matches the architecture's `api/modules/resale` component mapping.
- Mobile resale feature goes in `apps/mobile/lib/src/features/resale/` with `models/`, `services/`, and `screens/` subdirectories. This matches the architecture's `mobile/features/resale` component mapping.
- Migration file: `022_resale_listings.sql` -- follows sequential numbering after `021_premium_subscription.sql`.
- Test files mirror source structure under `apps/api/test/modules/resale/` and `apps/mobile/test/features/resale/`.

### Testing Requirements

- **Resale listing service unit tests** must verify: Gemini prompt contains item metadata and image, response parsing and validation, persistence to `resale_listings`, `resale_status` update logic, 503 on Gemini unavailable, AI usage logging (success and failure), unparseable JSON handling, conditionEstimate validation, title truncation, hashtag capping, 404 on missing item.
- **Endpoint integration tests** must verify: authentication required, success response structure, 429 on free user limit exceeded, unlimited for premium user, 404 for non-existent item, 503 on Gemini unavailable, 500 on Gemini failure, badge check after success.
- **Mobile model tests** must verify: serialization round-trip, null handling for optional fields.
- **Mobile service tests** must verify: API call with correct item ID, success parsing, null on non-429 error, UsageLimitException on 429.
- **ResaleListingScreen widget tests** must verify: loading state, success display, clipboard copy, share action, error state with retry, usage limit exceeded shows PremiumGateCard, Semantics labels.
- **Item detail integration tests** must verify: button visibility based on resale status, navigation to ResaleListingScreen.
- **Regression:**
  - `flutter analyze` (zero new issues)
  - `flutter test` (all existing 1087+ tests plus new tests pass)
  - `npm --prefix apps/api test` (all existing 639+ API tests plus new tests pass)

### Previous Story Intelligence

- **Story 7.2** (done) established: `premiumGuard` in `apps/api/src/modules/billing/premium-guard.js` with `checkPremium()`, `requirePremium()`, `checkUsageQuota()`, and `FREE_LIMITS` constants (including `RESALE_LISTING_MONTHLY = 2`). `PremiumGateCard` in `apps/mobile/lib/src/core/widgets/premium_gate_card.dart`. `PremiumState` / `isPremiumCached` in `SubscriptionService`. 639 API tests, 1087 Flutter tests.
- **Story 7.1** (done) established: `subscription-sync-service.js` in `apps/api/src/modules/billing/`, `SubscriptionService` on mobile with `presentPaywallIfNeeded()`, `addCustomerInfoUpdateListener()`, `syncWithBackend()`. RevenueCat paywall integration.
- **Story 2.3** (done) established: `categorization-service.js` pattern -- the EXACT pattern to follow for the resale listing service: Gemini call with JSON mode, image base64 encoding, structured response parsing, validation, AI usage logging. The `taxonomy.js` file for valid values. Fire-and-forget was used for categorization but resale listing is synchronous request-response.
- **Story 4.1** (done) established: `outfit-generation-service.js` -- another Gemini service pattern. Synchronous request-response (like resale listing). The response enrichment pattern (adding item metadata to the response).
- **Story 2.6** (done) established: item detail screen with action buttons -- this is where the "Generate Resale Listing" button will be added.
- **Story 6.4** (done) established: `badgeService.checkAndAward(authContext, badgeKey)` pattern for checking and awarding badges. The 'circular_seller' badge already exists in the `badges` table (migration 019).
- **`createRuntime()` currently returns (as of Story 7.2, 28 services):** `config`, `pool`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `classificationService`, `calendarService`, `outfitGenerationService`, `outfitRepository`, `usageLimitService`, `wearLogRepository`, `analyticsRepository`, `analyticsSummaryService`, `aiUsageLogRepo`, `geminiClient`, `userStatsRepo`, `badgeService`, `challengeService`, `challengeRepository`, `scheduleService`, `notificationService`, `subscriptionSyncService`, `premiumGuard`. This story adds `resaleListingService`.
- **`handleRequest` destructuring** currently includes all 28 services. This story adds `resaleListingService`.
- **`mapError` function** handles 400, 401, 403, 404, 429, 500, 503. No changes needed.
- **Key patterns from previous stories:**
  - Factory pattern for all API services: `createXxxService({ deps })`.
  - DI via constructor parameters for mobile.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repositories.
  - Semantics labels on all interactive elements.
  - Best-effort for non-critical operations (try/catch, do not break primary flow).

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client. All AI calls go through the Cloud Run API.
- DO NOT create a new Gemini client. Reuse the existing `geminiClient` singleton from `createRuntime()`.
- DO NOT implement the full resale lifecycle (listed -> sold -> history). That is Story 7.4. This story only generates listings and sets `resale_status = 'listed'`.
- DO NOT implement resale candidate identification or monthly prompts. That is Epic 13.
- DO NOT log AI usage with a feature name other than `"resale_listing"`. The `checkUsageQuota` counts by this exact feature name in `ai_usage_log`.
- DO NOT enforce usage limits inside the service. The route handler calls `premiumGuard.checkUsageQuota` BEFORE calling the service. The service focuses on generation and logging.
- DO NOT overwrite `resale_status` if it is already `'sold'` or `'donated'`. Only set to `'listed'` when the current value is NULL.
- DO NOT block the response on badge checks. Use try/catch around `badgeService.checkAndAward` -- if it fails, log and continue.
- DO NOT add the `resale_listings` table without RLS. All user-facing tables require RLS.
- DO NOT skip AI usage logging on failure. Both success and failure must be logged for observability.
- DO NOT parse the Gemini response without JSON mode. Use `responseMimeType: 'application/json'`.
- DO NOT add `wearCount` and `lastWornDate` to `mapItemRow` in this story -- they are only used internally by `computeNeglectStatus` and by analytics queries with their own mapping. Instead, do a direct query for the additional fields needed for the Gemini prompt.
- DO NOT break existing wardrobe grid filtering or item detail screen. The `resale_status` column is nullable and additive.

### Out of Scope

- **Resale candidate identification** (FR-RSL-01): Epic 13, Story 13.2.
- **Full resale lifecycle tracking** (FR-RSL-04 full, FR-RSL-07, FR-RSL-08, FR-RSL-10): Story 7.4.
- **Monthly resale prompts** (FR-RSL-05, FR-RSL-06): Epic 13.
- **Circular Champion badge** (FR-RSL-09, 10+ sold): Story 7.4 (requires tracking sold status).
- **Earnings chart** (FR-RSL-08): Story 7.4.
- **Donation tracking** (FR-DON-01 to FR-DON-05): Epic 13.
- **Estimated sale price**: Out of scope for this story; the AI focuses on listing quality, not pricing.

### References

- [Source: epics.md - Story 7.3: AI Resale Listing Generation]
- [Source: epics.md - Epic 7: Resale Integration & Subscription]
- [Source: prd.md - FR-RSL-02: AI-powered resale listings optimized for Vinted/Depop]
- [Source: prd.md - FR-RSL-03: Copy listing text to clipboard or share via system share sheet]
- [Source: prd.md - FR-RSL-04: Items track resale_status with CHECK constraint]
- [Source: prd.md - Free tier: 2 resale listings/month]
- [Source: prd.md - Premium tier: unlimited AI]
- [Source: architecture.md - AI Orchestration: resale listing generation, Gemini 2.0 Flash]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Data Architecture: resale_listings, resale_history tables]
- [Source: architecture.md - Server authority for sensitive rules: resale state changes]
- [Source: architecture.md - Gated features include resale listing generation]
- [Source: architecture.md - Epic 7 -> mobile/features/resale, api/modules/resale, api/modules/billing]
- [Source: architecture.md - check constraints for enumerations like resale_status]
- [Source: functional-requirements.md - FR-RSL-01 through FR-RSL-10]
- [Source: 7-2-premium-feature-access-enforcement.md - premiumGuard, checkUsageQuota, FREE_LIMITS.RESALE_LISTING_MONTHLY, PremiumGateCard]
- [Source: 7-1-premium-subscription-purchase.md - SubscriptionService, presentPaywallIfNeeded, addCustomerInfoUpdateListener]
- [Source: 2-3-ai-item-categorization-tagging.md - categorization-service.js pattern, Gemini JSON mode, image base64, AI usage logging]
- [Source: 4-1-daily-ai-outfit-generation.md - outfit-generation-service.js, synchronous Gemini request-response pattern]
- [Source: apps/api/src/modules/billing/premium-guard.js - checkUsageQuota, FREE_LIMITS]
- [Source: apps/api/src/modules/ai/categorization-service.js - Gemini call pattern, image handling, taxonomy validation]
- [Source: apps/api/src/modules/items/repository.js - mapItemRow, updateItem, listItems]
- [Source: apps/api/src/main.js - createRuntime, handleRequest, mapError, route patterns]
- [Source: apps/mobile/lib/src/core/widgets/premium_gate_card.dart - PremiumGateCard widget]
- [Source: apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart - WardrobeItem model]
- [Source: infra/sql/migrations/019_badges.sql - circular_seller badge definition]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed share_plus API: v10 uses `Share.share(text)` not `SharePlus.instance.share(ShareParams(...))`.
- Fixed mock service in widget tests: extended class requires real ApiClient in constructor, solved by providing a dummy ApiClient.
- Fixed Completer-based loading state test to avoid fake_async timer conflicts.
- Fixed scroll-to-visible in item detail screen tests for the resale button.

### Completion Notes List

- Task 1: Created migration 022 with resale_listings table (RLS, indexes) and items.resale_status column.
- Task 2: Created resale-listing-service.js following categorization-service.js factory pattern. Includes Gemini prompt, image analysis, response validation, persistence, AI usage logging.
- Task 3: Added POST /v1/resale/generate route with premiumGuard.checkUsageQuota gating, badge check, and full error handling.
- Task 4: Updated items repository: added resaleStatus to mapItemRow, updateItem, listItems filter.
- Task 5: Created ResaleListing, ResaleListingResult, ResaleListingItem models with fromJson/toJson.
- Task 6: Created ResaleListingService with UsageLimitException for 429 handling. Added generateResaleListing to ApiClient.
- Task 7: Created ResaleListingScreen with loading/success/error/usageLimitExceeded states, editable fields, copy/share actions, condition chips, hashtag display.
- Task 8: Integrated "Generate Resale Listing" button into item detail screen with status-dependent visibility.
- Task 9: Added resaleStatus field + isListedForResale/isSold/isDonated getters to WardrobeItem model.
- Task 10: Implemented PremiumGateCard display on UsageLimitException in ResaleListingScreen.
- Tasks 11-17: All tests written and passing: 27 new API tests (666 total), 36 new Flutter tests (1123 total).
- Task 18: flutter analyze: 0 new issues. All 666 API tests pass. All 1123 Flutter tests pass.

### Change Log

- 2026-03-19: Story 7.3 implementation complete. Added AI resale listing generation with Gemini 2.0 Flash, premium gating (2/month free), copy/share actions, and full test coverage.

### File List

New files:
- infra/sql/migrations/022_resale_listings.sql
- apps/api/src/modules/resale/resale-listing-service.js
- apps/api/test/modules/resale/resale-listing-service.test.js
- apps/api/test/modules/resale/resale-generation.test.js
- apps/mobile/lib/src/features/resale/models/resale_listing.dart
- apps/mobile/lib/src/features/resale/services/resale_listing_service.dart
- apps/mobile/lib/src/features/resale/screens/resale_listing_screen.dart
- apps/mobile/test/features/resale/models/resale_listing_test.dart
- apps/mobile/test/features/resale/services/resale_listing_service_test.dart
- apps/mobile/test/features/resale/screens/resale_listing_screen_test.dart

Modified files:
- apps/api/src/main.js (added resale route, resaleListingService in createRuntime and handleRequest)
- apps/api/src/modules/items/repository.js (added resaleStatus to mapItemRow, updateItem, listItems)
- apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart (added resaleStatus field and getters)
- apps/mobile/lib/src/features/wardrobe/screens/item_detail_screen.dart (added resale listing button)
- apps/mobile/lib/src/core/networking/api_client.dart (added generateResaleListing method)
- apps/mobile/pubspec.yaml (added share_plus dependency)
- apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart (added resaleStatus tests)
- apps/mobile/test/features/wardrobe/screens/item_detail_screen_test.dart (added resale integration tests)
