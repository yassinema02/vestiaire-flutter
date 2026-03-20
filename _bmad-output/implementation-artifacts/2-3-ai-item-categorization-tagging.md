# Story 2.3: AI Item Categorization & Tagging

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want the AI to automatically identify and tag my clothing item with category, color, material, pattern, style, season, and occasion,
so that I don't have to manually enter all the details and my wardrobe is immediately searchable and useful for outfit generation.

## Acceptance Criteria

1. Given my clothing image has been uploaded and background removal is complete (or skipped/failed), when the item creation pipeline runs, then the Cloud Run API calls Gemini 2.0 Flash vision analysis to extract structured metadata: `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, and `occasion` tags.
2. Given the Gemini vision analysis returns results, when the API processes the response, then each field is validated against the fixed taxonomy (see Dev Notes for valid values) and any unrecognized values fall back to safe defaults (`category: 'other'`, `color: 'unknown'`, `pattern: 'solid'`, `material: 'unknown'`, `style: 'casual'`, `season: ['all']`, `occasion: ['everyday']`).
3. Given the categorization succeeds, when the item record is updated, then all extracted metadata fields are persisted to the `items` table and the `categorization_status` is set to `'completed'`.
4. Given the categorization fails (Gemini timeout, rate limit, API error, or unparseable response), when the error occurs, then the API logs the failure to `ai_usage_log`, sets `categorization_status` to `'failed'`, and does NOT block item creation or background removal -- the item remains usable with null metadata fields.
5. Given categorization is processing, when the mobile client polls or receives the updated item, then the client displays a shimmer/skeleton overlay on the metadata area (reusing the existing shimmer pattern from Story 2.2) until categorization completes.
6. Given categorization completes (success or failure), when the mobile client fetches the item, then the `categorization_status` field indicates `'completed'`, `'failed'`, or `'pending'` so the client can show appropriate UI (populated tags, "Retry" option, or loading state).
7. Given categorization failed, when the user views the item in the wardrobe grid, then they see a subtle indicator (info icon overlay) and a long-press context menu option "Retry Categorization" that calls `POST /v1/items/:id/categorize`.
8. Given the API processes a categorization request, when the Gemini call is made, then the API logs the request to `ai_usage_log` with feature `'categorization'`, model name, token count, latency, and cost estimate.
9. Given the `GET /v1/items` response, when the mobile client receives item data, then the response includes all new categorization fields (`category`, `color`, `secondaryColors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorizationStatus`) and the `WardrobeItem` model exposes these fields.

## Tasks / Subtasks

- [x] Task 1: Database migration for categorization columns (AC: 1, 2, 3, 4, 6)
  - [x]1.1: Create `infra/sql/migrations/008_items_categorization.sql`: ALTER TABLE `app_public.items` ADD COLUMN `category` TEXT DEFAULT NULL, ADD COLUMN `color` TEXT DEFAULT NULL, ADD COLUMN `secondary_colors` TEXT[] DEFAULT NULL, ADD COLUMN `pattern` TEXT DEFAULT NULL, ADD COLUMN `material` TEXT DEFAULT NULL, ADD COLUMN `style` TEXT DEFAULT NULL, ADD COLUMN `season` TEXT[] DEFAULT NULL, ADD COLUMN `occasion` TEXT[] DEFAULT NULL, ADD COLUMN `categorization_status` TEXT CHECK (`categorization_status` IN ('pending', 'completed', 'failed')) DEFAULT NULL. Add CHECK constraints on `category` and `color` against the fixed taxonomy values (see Dev Notes). Add an index on `category` for future filtering (Story 2.5).
  - [x]1.2: Add SQL comments on each new column documenting the taxonomy values and purpose.

- [x] Task 2: Create the categorization service on the API (AC: 1, 2, 4, 8)
  - [x]2.1: Create `apps/api/src/modules/ai/categorization-service.js`: Export `createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo })`. The service has a single method `categorizeItem(authContext, { itemId, imageUrl })` that: (a) calls Gemini 2.0 Flash with the item image and a structured extraction prompt (see Dev Notes for prompt), (b) parses the JSON response, (c) validates each field against the fixed taxonomy with safe defaults, (d) updates the item record with the extracted metadata and `categorization_status: 'completed'`, (e) logs the AI call to `ai_usage_log`.
  - [x]2.2: Implement taxonomy validation in the service: define `VALID_CATEGORIES`, `VALID_COLORS`, `VALID_PATTERNS`, `VALID_MATERIALS`, `VALID_STYLES`, `VALID_SEASONS`, `VALID_OCCASIONS` as const arrays. For each AI response field, check inclusion in the valid set; if not found, use the safe default. For array fields (`secondary_colors`, `season`, `occasion`), filter to only valid values.
  - [x]2.3: Implement error handling: on Gemini failure, log to `ai_usage_log` with status `'failure'`, update item `categorization_status` to `'failed'`, and return `{ status: 'failed' }`. Do NOT throw -- the caller should not be blocked.
  - [x]2.4: If `geminiClient.isAvailable()` returns false, skip categorization and return `{ status: 'skipped' }` without changing the item. Log a warning.

- [x] Task 3: Integrate categorization into the item creation pipeline (AC: 1, 3, 4)
  - [x]3.1: Modify `apps/api/src/modules/items/service.js`: After the existing background removal fire-and-forget, add a categorization fire-and-forget call. The categorization should run AFTER background removal completes (chain the promise) so it uses the cleaned image when available. If background removal is skipped/disabled, categorize using the original image. Set `categorization_status = 'pending'` on item creation.
  - [x]3.2: Wire up the `categorizationService` in `createRuntime()` in `main.js`: create the categorization service and pass it to the items service.

- [x] Task 4: API endpoint for retry categorization (AC: 7, 8)
  - [x]4.1: Add route `POST /v1/items/:id/categorize` in `apps/api/src/main.js`. This endpoint: authenticates the user, looks up the item (ensuring ownership via auth context), and triggers `categorizationService.categorizeItem(authContext, { itemId, imageUrl: item.photoUrl })`. Returns `{ status: 'processing' }` immediately (202 Accepted).

- [x] Task 5: Update items repository to support categorization fields (AC: 3, 6, 9)
  - [x]5.1: Update `mapItemRow` in `apps/api/src/modules/items/repository.js` to include: `category`, `color`, `secondaryColors` (from `secondary_colors`), `pattern`, `material`, `style`, `season`, `occasion`, `categorizationStatus` (from `categorization_status`).
  - [x]5.2: Update `updateItem` method to support the new fields in the dynamic SET clause: `category`, `color`, `secondary_colors`, `pattern`, `material`, `style`, `season`, `occasion`, `categorization_status`.
  - [x]5.3: Update `createItem` method to accept and insert `categorization_status` in the INSERT statement.

- [x] Task 6: Update mobile WardrobeItem model (AC: 5, 6, 9)
  - [x]6.1: Update `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`: Add fields `category` (String?), `color` (String?), `secondaryColors` (List<String>?), `pattern` (String?), `material` (String?), `style` (String?), `season` (List<String>?), `occasion` (List<String>?), `categorizationStatus` (String?). Add `fromJson` parsing for all new fields. Add getters: `isCategorizationPending`, `isCategorizationFailed`, `isCategorizationCompleted`.
  - [x]6.2: Add a `displayLabel` getter that returns `name ?? category ?? 'Item'` for use in the wardrobe grid and semantics labels.

- [x] Task 7: Update mobile WardrobeScreen to show categorization status (AC: 5, 6, 7)
  - [x]7.1: Update `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`: For items with `categorizationStatus == 'pending'`, show a small shimmer overlay on the bottom portion of the grid cell (where metadata tags will appear in Story 2.4's review screen). Reuse the existing shimmer animation pattern from Story 2.2.
  - [x]7.2: For items with `categorizationStatus == 'failed'`, show a small info icon badge overlay (distinct from the bg removal failed badge). Add a long-press context menu option "Retry Categorization" that calls `apiClient.retryCategorization(itemId)`.
  - [x]7.3: For items with `categorizationStatus == 'completed'`, display the `category` as a small label/chip at the bottom of the grid cell image (e.g., "Jacket", "Dress") with a semi-transparent dark scrim behind the text for contrast (WCAG AA compliance).
  - [x]7.4: Extend the existing polling mechanism: if any visible items have `categorizationStatus == 'pending'` OR `bgRemovalStatus == 'pending'`, poll for updates. The existing polling logic already handles `bgRemovalStatus`; extend the condition to also check `categorizationStatus`.

- [x] Task 8: Update mobile ApiClient (AC: 7)
  - [x]8.1: Add `retryCategorization(String itemId)` method to `apps/mobile/lib/src/core/networking/api_client.dart` that calls `POST /v1/items/$itemId/categorize`. Returns the response map.

- [x] Task 9: Widget tests for updated mobile functionality (AC: all)
  - [x]9.1: Update `apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart`: Test `WardrobeItem.fromJson` with all new categorization fields. Test `isCategorizationPending`, `isCategorizationFailed`, `isCategorizationCompleted` getters. Test `displayLabel` getter returns name when available, category when name is null, 'Item' when both are null. Test `secondaryColors`, `season`, `occasion` parse as List<String>.
  - [x]9.2: Update `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`: Test that items with `categorizationStatus == 'pending'` show shimmer overlay. Test that items with `categorizationStatus == 'failed'` show info icon badge. Test that items with `categorizationStatus == 'completed'` show category label chip. Test that long-press on failed categorization item shows "Retry Categorization" option. Test that polling is triggered when items have `categorizationStatus == 'pending'`.
  - [x]9.3: Test `ApiClient.retryCategorization` calls the correct endpoint `POST /v1/items/{id}/categorize`.

- [x] Task 10: API tests for categorization (AC: 1, 2, 4, 8)
  - [x]10.1: Create `apps/api/test/modules/ai/categorization-service.test.js`: Test that `categorizeItem` calls Gemini with image data and structured prompt. Test successful extraction populates all taxonomy fields. Test taxonomy validation: invalid category falls back to 'other', invalid color falls back to 'unknown'. Test array field validation: invalid season values are filtered out. Test failure path: Gemini call fails, logs error, sets categorization_status to 'failed'. Test skipped path: when Gemini is not available, returns 'skipped'.
  - [x]10.2: Update `apps/api/test/modules/items/service.test.js`: Test that `createItemForUser` sets `categorization_status` to `'pending'` and fires categorization asynchronously after background removal.
  - [x]10.3: Test the `POST /v1/items/:id/categorize` endpoint returns 202, triggers categorization, and returns error for items not owned by the user.

- [x] Task 11: Regression testing (AC: all)
  - [x]11.1: Run `flutter analyze` -- zero issues.
  - [x]11.2: Run `flutter test` -- all existing + new tests pass.
  - [x]11.3: Run `npm --prefix apps/api test` -- all existing + new tests pass.
  - [x]11.4: Verify the existing AddItemScreen upload flow still works end-to-end (camera + gallery paths).
  - [x]11.5: Verify `GET /v1/items` returns backward-compatible response (new categorization fields are nullable, old clients can ignore them).
  - [x]11.6: Verify background removal still works independently of categorization.

## Dev Notes

- This is the THIRD story in Epic 2 (Digital Wardrobe Core). It builds on Stories 2.1 (upload pipeline, wardrobe grid, WardrobeItem model) and 2.2 (AI module, Gemini client, background removal, ai_usage_log, shimmer/polling patterns). Reuse everything established in those stories.
- The categorization service follows the exact same pattern as `background-removal-service.js`: receive image, call Gemini, parse response, update item, log usage. The key difference is that categorization extracts structured JSON metadata rather than a processed image.
- Categorization should be CHAINED after background removal (not parallel). Use the cleaned image when available because a clean white background significantly improves Gemini's accuracy for clothing detection. If background removal is disabled or failed, use the original image.
- The Gemini prompt for categorization must request structured JSON output. Use `responseType: 'application/json'` (Gemini's JSON mode) to ensure parseable output.

### Fixed Taxonomy (CRITICAL -- validate ALL AI output against these)

**Categories:** `tops`, `bottoms`, `dresses`, `outerwear`, `shoes`, `bags`, `accessories`, `activewear`, `swimwear`, `underwear`, `sleepwear`, `suits`, `other`

**Colors:** `black`, `white`, `gray`, `navy`, `blue`, `light-blue`, `red`, `burgundy`, `pink`, `orange`, `yellow`, `green`, `olive`, `teal`, `purple`, `beige`, `brown`, `tan`, `cream`, `gold`, `silver`, `multicolor`, `unknown`

**Patterns:** `solid`, `striped`, `plaid`, `floral`, `polka-dot`, `geometric`, `abstract`, `animal-print`, `camouflage`, `paisley`, `tie-dye`, `color-block`, `other`

**Materials:** `cotton`, `polyester`, `silk`, `wool`, `linen`, `denim`, `leather`, `suede`, `cashmere`, `nylon`, `velvet`, `chiffon`, `satin`, `fleece`, `knit`, `mesh`, `tweed`, `corduroy`, `synthetic-blend`, `unknown`

**Styles:** `casual`, `formal`, `smart-casual`, `business`, `sporty`, `bohemian`, `streetwear`, `minimalist`, `vintage`, `classic`, `trendy`, `preppy`, `other`

**Seasons (array):** `spring`, `summer`, `fall`, `winter`, `all`

**Occasions (array):** `everyday`, `work`, `formal`, `party`, `date-night`, `outdoor`, `sport`, `beach`, `travel`, `lounge`

### Gemini Categorization Prompt

```
Analyze this clothing item image and extract the following metadata as JSON.
Return ONLY valid JSON with these exact keys:
{
  "category": "one of: tops, bottoms, dresses, outerwear, shoes, bags, accessories, activewear, swimwear, underwear, sleepwear, suits, other",
  "color": "primary color, one of: black, white, gray, navy, blue, light-blue, red, burgundy, pink, orange, yellow, green, olive, teal, purple, beige, brown, tan, cream, gold, silver, multicolor, unknown",
  "secondary_colors": ["array of additional colors from the same color list, empty if solid color"],
  "pattern": "one of: solid, striped, plaid, floral, polka-dot, geometric, abstract, animal-print, camouflage, paisley, tie-dye, color-block, other",
  "material": "best guess, one of: cotton, polyester, silk, wool, linen, denim, leather, suede, cashmere, nylon, velvet, chiffon, satin, fleece, knit, mesh, tweed, corduroy, synthetic-blend, unknown",
  "style": "one of: casual, formal, smart-casual, business, sporty, bohemian, streetwear, minimalist, vintage, classic, trendy, preppy, other",
  "season": ["array of suitable seasons: spring, summer, fall, winter, all"],
  "occasion": ["array of suitable occasions: everyday, work, formal, party, date-night, outdoor, sport, beach, travel, lounge"]
}
```

### Categorization Pipeline Flow

1. `POST /v1/items` creates item with `categorization_status: 'pending'`
2. Background removal fires (fire-and-forget)
3. When bg removal resolves (success or failure), categorization fires using the best available image (cleaned or original)
4. Categorization calls Gemini with JSON mode, parses response, validates against taxonomy
5. Item is updated with metadata fields + `categorization_status: 'completed'`
6. Mobile polling picks up the update and displays category label

### Project Structure Notes

- New files:
  - `infra/sql/migrations/008_items_categorization.sql`
  - `apps/api/src/modules/ai/categorization-service.js`
  - `apps/api/test/modules/ai/categorization-service.test.js`
- Modified files:
  - `apps/api/src/main.js` (add categorization service to runtime, add POST /v1/items/:id/categorize route)
  - `apps/api/src/modules/items/service.js` (chain categorization after bg removal)
  - `apps/api/src/modules/items/repository.js` (new columns in mapItemRow, updateItem, createItem)
  - `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart` (add categorization fields)
  - `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart` (category labels, categorization status indicators, extended polling)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add retryCategorization method)
  - `apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart`
  - `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`
  - `apps/mobile/test/core/networking/api_client_test.dart`
  - `apps/api/test/modules/items/service.test.js`

### Technical Requirements

- Gemini 2.0 Flash model identifier: `gemini-2.0-flash` (same model as background removal, accessed via the existing `geminiClient`).
- Use Gemini's JSON mode (`responseMimeType: 'application/json'`) for the categorization call to get structured output. The `generateContent` call should include `generationConfig: { responseMimeType: 'application/json' }`.
- The categorization service imports the existing `geminiClient` singleton -- do NOT create a new Gemini client.
- PostgreSQL arrays: use `TEXT[]` for `secondary_colors`, `season`, `occasion`. In the API, these map to JavaScript arrays. In the repository, use `$1::text[]` parameterized queries for array inserts/updates.

### Architecture Compliance

- AI calls are brokered ONLY by Cloud Run (architecture: "AI calls are brokered only by Cloud Run"). The mobile client never calls Gemini directly.
- All AI workloads route through Vertex AI / Gemini 2.0 Flash (architecture: "Single AI provider").
- AI orchestration includes taxonomy validation, safe defaults on failure, retry/backoff, and per-user logging (architecture: AI Orchestration Guardrails).
- RLS on `items` table ensures users only see/modify their own items.
- New categorization fields are additive and nullable -- backward compatible with existing clients.
- The `categorization-service.js` lives in the `apps/api/src/modules/ai/` directory alongside the existing `background-removal-service.js` and `gemini-client.js` (architecture: Epic-to-Component Mapping).

### Library / Framework Requirements

- API: No new dependencies. Uses existing `@google-cloud/vertexai` (via the shared `geminiClient`), `pg` (database), existing AI module.
- Mobile: No new dependencies. Reuses existing shimmer animation pattern, polling mechanism, and context menu from Story 2.2.

### File Structure Requirements

- The `apps/api/src/modules/ai/` directory already contains `gemini-client.js`, `background-removal-service.js`, `ai-usage-log-repository.js`. Add `categorization-service.js` here.
- Migration file follows sequential numbering: 008 (after existing 007_ai_usage_log.sql).
- No new RLS policies needed -- the existing `items` RLS policy (003_items_rls.sql) already covers the items table.

### Testing Requirements

- API tests use Node.js built-in test runner (`node --test`). Follow patterns in `apps/api/test/modules/ai/background-removal-service.test.js`.
- Mock the Gemini client in categorization service tests. Do NOT make real API calls in tests.
- Test taxonomy validation exhaustively: test every field with valid value, invalid value, and missing value.
- Test the promise chaining: categorization should fire after background removal resolves.
- Flutter widget tests follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock ApiClient.
- Target: all existing tests continue to pass (211 Flutter tests, 64 API tests from Story 2.2).

### Previous Story Intelligence

- Story 2.2 established: `apps/api/src/modules/ai/` directory with `gemini-client.js` (shared singleton), `background-removal-service.js` (pattern to follow), `ai-usage-log-repository.js` (shared logging). `WardrobeItem` model with `fromJson`, `isProcessing`, `isFailed`, `isCompleted` getters. Shimmer animation using `AnimationController` + `ShaderMask`. Polling with `Timer.periodic(Duration(seconds: 3))` capped at 10 retries. Long-press context menu for failed items. 211 Flutter tests, 64 API tests.
- Story 2.2 key pattern: Fire-and-forget in item service uses `.catch(err => console.error(...))`. The background removal service updates the item via `itemRepo.updateItem()` and logs via `aiUsageLogRepo.logUsage()`.
- Story 2.2 key pattern: The `mapItemRow` function maps snake_case DB columns to camelCase JS properties. Extend this for the new columns.
- Story 2.2 key pattern: The `updateItem` method in items repository builds a dynamic SET clause from provided fields. Extend this to include the categorization fields.
- Story 2.1 established: `AddItemScreen` with camera/gallery, 3-step upload pipeline, `MainShellScreen` with 5-tab navigation, `WardrobeScreen` with basic grid.
- Items table current columns after Story 2.2: `id`, `profile_id`, `photo_url`, `original_photo_url`, `name`, `bg_removal_status`, `created_at`, `updated_at`.

### Key Anti-Patterns to Avoid

- DO NOT call Gemini from the mobile client. All AI calls go through the Cloud Run API.
- DO NOT block item creation on categorization. The `POST /v1/items` endpoint must return immediately. Categorization is async.
- DO NOT create a new Gemini client. Reuse the existing `geminiClient` singleton from `modules/ai/gemini-client.js`.
- DO NOT run categorization in parallel with background removal. Chain it AFTER bg removal so the cleaned image is used.
- DO NOT use free-text for taxonomy fields. Always validate against the fixed taxonomy arrays and fall back to safe defaults.
- DO NOT add manual metadata editing UI in this story. That is Story 2.4 (Tag Cloud UI, manual editing).
- DO NOT break the existing `POST /v1/items` or `GET /v1/items` API contracts. New fields are additive and nullable.
- DO NOT require GCP credentials for local dev to work. Gracefully degrade when `GCP_PROJECT_ID` is not set (same pattern as bg removal).
- DO NOT add a third-party package for shimmer on mobile. Reuse the existing shimmer implementation from Story 2.2.
- DO NOT parse the Gemini response without JSON mode. Use `responseMimeType: 'application/json'` in generationConfig to get reliable structured output.

### Implementation Guidance

- **Categorization service structure:** Follow `background-removal-service.js` exactly. Create `createCategorizationService({ geminiClient, itemRepo, aiUsageLogRepo })` returning `{ categorizeItem(authContext, { itemId, imageUrl }) }`.
- **Gemini JSON mode call:**
  ```javascript
  const model = await geminiClient.getGenerativeModel('gemini-2.0-flash');
  const result = await model.generateContent({
    contents: [{ role: 'user', parts: [{ inlineData: { mimeType: 'image/jpeg', data: base64Image } }, { text: CATEGORIZATION_PROMPT }] }],
    generationConfig: { responseMimeType: 'application/json' }
  });
  const parsed = JSON.parse(result.response.candidates[0].content.parts[0].text);
  ```
- **Chaining after bg removal in item service:**
  ```javascript
  const bgPromise = backgroundRemovalService
    .removeBackground(authContext, { itemId: item.id, imageUrl: item.photoUrl })
    .catch(err => { console.error('[bg-removal] Failed:', err.message); return { cleanedImageUrl: null }; });

  bgPromise.then(bgResult => {
    const imageForCategorization = bgResult?.cleanedImageUrl || item.photoUrl;
    categorizationService.categorizeItem(authContext, { itemId: item.id, imageUrl: imageForCategorization })
      .catch(err => console.error('[categorization] Failed:', err.message));
  });
  ```
- **PostgreSQL array insert:** `$1::text[]` with JavaScript arrays serialized as `'{value1,value2}'` or use the pg driver's native array support.
- **WardrobeItem model update:** Add nullable fields with `fromJson` parsing. For array fields, cast: `(json['season'] as List<dynamic>?)?.map((e) => e as String).toList()`.
- **Category label on grid cell:** Use a `Positioned` widget at the bottom of the `Stack` with a `Container` that has a dark semi-transparent background (`Colors.black54`) and white text. 10-12px font size, 4px horizontal padding.

### References

- [Source: epics.md - Story 2.3: AI Item Categorization & Tagging]
- [Source: epics.md - Epic 2: Digital Wardrobe Core]
- [Source: architecture.md - AI Orchestration: Vertex AI / Gemini 2.0 Flash, taxonomy validation, safe defaults]
- [Source: architecture.md - Data Architecture: JSONB for structured AI output, arrays for multi-value taxonomy]
- [Source: architecture.md - Epic-to-Component Mapping: Epic 2 -> api/modules/ai, mobile/features/wardrobe]
- [Source: prd.md - FR-WRD-05: Auto-categorize using Gemini vision: category, color, secondary colors, pattern, material, style, season, occasion]
- [Source: prd.md - FR-WRD-06: Validate against fixed taxonomy with fallback to safe defaults]
- [Source: prd.md - NFR-OBS-02: AI API costs logged per-user in ai_usage_log]
- [Source: prd.md - NFR-SEC-01: All API keys stored server-side only]
- [Source: ux-design-specification.md - "Magic, Not Manual" principle: AI does heavy lifting for categorization]
- [Source: ux-design-specification.md - Micro-animations during AI categorization to feel magical]
- [Source: ux-design-specification.md - Tag Cloud pattern for editing item metadata (Story 2.4)]
- [Source: ux-design-specification.md - Always provide manual fallback on AI failure]
- [Source: ux-design-specification.md - Semantics labels: AI-generated descriptions as semanticLabels for screen readers]
- [Source: 2-2-ai-background-removal-upload.md - AI module structure, Gemini client, bg removal service pattern, shimmer, polling]
- [Source: 2-1-upload-item-photo-camera-gallery.md - Upload pipeline, WardrobeScreen grid, WardrobeItem model]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None required.

### Completion Notes List

- All 11 tasks completed successfully with full test coverage.
- API tests: 81 passing (was 64 before story, +17 new tests for categorization service, item service integration, taxonomy validation).
- Flutter tests: 233 passing (was 211 before story, +22 new tests for WardrobeItem model, WardrobeScreen categorization UI, ApiClient retryCategorization).
- Flutter analyze: zero issues.
- Categorization service follows exact same pattern as background-removal-service.js.
- Categorization is chained AFTER background removal using promise chaining.
- All AI output validated against fixed taxonomy with safe defaults.
- Backward compatible: all new fields are nullable/additive.

### File List

**New files:**
- `infra/sql/migrations/008_items_categorization.sql`
- `apps/api/src/modules/ai/categorization-service.js`
- `apps/api/test/modules/ai/categorization-service.test.js`

**Modified files:**
- `apps/api/src/main.js`
- `apps/api/src/modules/items/service.js`
- `apps/api/src/modules/items/repository.js`
- `apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`
- `apps/mobile/lib/src/features/wardrobe/screens/wardrobe_screen.dart`
- `apps/mobile/lib/src/core/networking/api_client.dart`
- `apps/mobile/test/features/wardrobe/models/wardrobe_item_test.dart`
- `apps/mobile/test/features/wardrobe/screens/wardrobe_screen_test.dart`
- `apps/mobile/test/core/networking/api_client_test.dart`
- `apps/api/test/modules/items/service.test.js`
