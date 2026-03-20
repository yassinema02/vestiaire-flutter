# Story 4.6: Recency Bias Mitigation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want the AI to avoid suggesting clothes I've worn too recently,
so that my daily looks remain varied and I don't look like I wear the same thing every day.

## Acceptance Criteria

1. Given the AI is generating an outfit via `POST /v1/outfits/generate`, when compiling the Gemini prompt, then the API queries the `outfits` table (joined with `outfit_items`) for outfits saved in the last 7 days (by `created_at`) for the authenticated user, extracts the distinct item IDs from those outfits, and includes them in the Gemini prompt as "recently worn items" with an instruction to avoid them (FR-OUT-11).

2. Given the user has saved outfits in the last 7 days, when the Gemini prompt is constructed, then it includes a new section: `RECENTLY WORN ITEMS (avoid unless necessary): [list of item IDs and names]` and an additional rule: "Avoid using items from the RECENTLY WORN list. Only include a recently worn item if the wardrobe is too small (fewer than 10 items) or if the item is essential for a complete outfit." (FR-OUT-11).

3. Given the user has NO saved outfits in the last 7 days, when the Gemini prompt is constructed, then the "RECENTLY WORN ITEMS" section is omitted entirely, and the prompt is identical to the current behavior. The generation does NOT fail due to missing recency data (FR-OUT-11).

4. Given the user has a small wardrobe (fewer than 10 categorized items), when the Gemini prompt is constructed and there are recently worn items, then the recency section is still included BUT the instruction explicitly says "The wardrobe is small, so re-using recently worn items is acceptable." This allows the AI more flexibility when the wardrobe is limited (FR-OUT-11).

5. Given the recency query runs, when it fetches recent outfit items, then it executes an efficient query joining `outfits` and `outfit_items` with a date filter (`created_at >= NOW() - INTERVAL '7 days'`), scoped to the authenticated user via RLS. The query uses the existing `idx_outfits_profile` index for performance.

6. Given the recency data is fetched, when the data is passed to the prompt builder, then only distinct item IDs are included (no duplicates if the same item appeared in multiple recent outfits). Each item in the recency list includes: `id`, `name`, `category`, and `color` for AI context.

7. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (281 API tests, 727 Flutter tests) and new tests cover: recent outfit items query in the outfit repository, prompt construction with recently worn items, prompt construction without recently worn items, prompt construction with small wardrobe, integration of recency data into the generate endpoint, and all edge cases.

## Tasks / Subtasks

- [x] Task 1: API - Add `getRecentOutfitItemIds` method to outfit repository (AC: 1, 5, 6)
  - [x] 1.1: Open `apps/api/src/modules/outfits/outfit-repository.js`. Add a new method `async getRecentOutfitItems(authContext, { days = 7 })` to the returned object from `createOutfitRepository`. This method: (a) gets a client from the pool, (b) sets the RLS context via `set_config('app.current_user_id', authContext.userId, true)`, (c) queries: `SELECT DISTINCT i.id, i.name, i.category, i.color FROM app_public.outfit_items oi JOIN app_public.outfits o ON o.id = oi.outfit_id JOIN app_public.items i ON i.id = oi.item_id WHERE o.created_at >= NOW() - INTERVAL '1 day' * $1 ORDER BY i.name` with `[days]` as parameter. The query uses the existing RLS on `outfits` and `outfit_items` to scope to the authenticated user. (d) Returns an array of `{ id, name, category, color }` objects. (e) Wraps in try/catch/finally with `client.release()`.
  - [x] 1.2: The method returns an empty array `[]` if no outfits exist in the time window. It does NOT throw on empty results.
  - [x] 1.3: Export the `RECENCY_WINDOW_DAYS = 7` constant from the repository for use in tests and easy future adjustment.

- [x] Task 2: API - Update outfit generation service to accept and use recency data (AC: 1, 2, 3, 4, 6)
  - [x] 2.1: Update `createOutfitGenerationService` factory function signature in `apps/api/src/modules/outfits/outfit-generation-service.js`: add `outfitRepo` to the destructured options: `createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo, outfitRepo })`.
  - [x] 2.2: Update the `generateOutfits` method: after fetching and filtering categorized items (current Step 2-3), add a new step: call `outfitRepo.getRecentOutfitItems(authContext, { days: 7 })` to get the recently worn item IDs. Store the result in `recentItems`.
  - [x] 2.3: Pass `recentItems` and `categorizedItems.length` (total wardrobe size) to the `buildPrompt` function: update the function signature to `buildPrompt(outfitContext, serializedItems, { recentItems = [], wardrobeSize = 0 })`.
  - [x] 2.4: If `outfitRepo` is null or undefined (for backward compatibility in existing tests), skip the recency query and pass an empty array to `buildPrompt`. This ensures existing tests that don't inject `outfitRepo` still work.

- [x] Task 3: API - Update `buildPrompt` to include recency context (AC: 2, 3, 4)
  - [x] 3.1: Update the `buildPrompt` function in `outfit-generation-service.js`. After the `WARDROBE ITEMS` section and before `RULES:`, add a conditional `RECENTLY WORN ITEMS` section. Only include this section if `recentItems.length > 0`.
  - [x] 3.2: The recency section format:
    ```
    RECENTLY WORN ITEMS (avoid these unless the wardrobe is too small):
    [{ "id": "uuid", "name": "Navy Blazer", "category": "blazer", "color": "navy" }, ...]
    ```
  - [x] 3.3: Add a new rule to the RULES section (insert as rule 8, after the existing rule 7):
    - If `recentItems.length > 0` AND `wardrobeSize >= 10`: Add `"8. Avoid using items from the RECENTLY WORN list unless absolutely necessary for a complete outfit. Prefer items that haven't been worn recently to keep the wardrobe rotation varied."`
    - If `recentItems.length > 0` AND `wardrobeSize < 10`: Add `"8. The wardrobe is small (fewer than 10 items), so re-using recently worn items is acceptable. Still try to vary selections where possible."`
    - If `recentItems.length === 0`: Do NOT add rule 8. The prompt remains identical to the current behavior.
  - [x] 3.4: Ensure the prompt template string handles the conditional sections cleanly without extra blank lines when recency data is absent.

- [x] Task 4: API - Wire `outfitRepo` into outfit generation service in main.js (AC: 1)
  - [x] 4.1: Update `apps/api/src/main.js`: modify the `createOutfitGenerationService` call in `createRuntime()` to pass `outfitRepo: outfitRepository` as the fourth dependency: `createOutfitGenerationService({ geminiClient, itemRepo, aiUsageLogRepo, outfitRepo: outfitRepository })`.
  - [x] 4.2: No other changes needed in `main.js`. The route handler for `POST /v1/outfits/generate` does not change -- the recency logic is encapsulated inside the generation service.

- [x] Task 5: API - Unit tests for `getRecentOutfitItems` (AC: 1, 5, 6, 7)
  - [x] 5.1: Create `apps/api/test/modules/outfits/outfit-repository-recency.test.js`:
    - `getRecentOutfitItems` returns empty array when no outfits exist.
    - `getRecentOutfitItems` returns item IDs from outfits created within the last 7 days.
    - `getRecentOutfitItems` does NOT return item IDs from outfits older than 7 days.
    - `getRecentOutfitItems` returns distinct item IDs (no duplicates when same item in multiple outfits).
    - `getRecentOutfitItems` includes name, category, and color for each item.
    - `getRecentOutfitItems` respects RLS (only returns items for the authenticated user).
    - `getRecentOutfitItems` accepts a custom `days` parameter.
    - `RECENCY_WINDOW_DAYS` constant is exported and equals 7.

- [x] Task 6: API - Unit tests for updated prompt construction (AC: 2, 3, 4, 7)
  - [x] 6.1: Update `apps/api/test/modules/outfits/outfit-generation-service.test.js`:
    - `buildPrompt` includes "RECENTLY WORN ITEMS" section when recentItems is non-empty.
    - `buildPrompt` does NOT include "RECENTLY WORN ITEMS" section when recentItems is empty.
    - `buildPrompt` includes "Avoid using items from the RECENTLY WORN list" rule when wardrobeSize >= 10 and recentItems is non-empty.
    - `buildPrompt` includes "wardrobe is small" instruction when wardrobeSize < 10 and recentItems is non-empty.
    - `buildPrompt` does NOT include rule 8 when recentItems is empty (backward compatible).
    - `generateOutfits` calls `outfitRepo.getRecentOutfitItems` when outfitRepo is provided.
    - `generateOutfits` works correctly when outfitRepo is null (backward compatibility).
    - `generateOutfits` passes recentItems and wardrobeSize to buildPrompt.

- [x] Task 7: API - Integration tests for recency-aware generation endpoint (AC: 1, 2, 3, 7)
  - [x] 7.1: Create `apps/api/test/modules/outfits/outfit-generation-recency.test.js`:
    - `POST /v1/outfits/generate` includes recently worn items in Gemini prompt when user has recent outfits.
    - `POST /v1/outfits/generate` does NOT include recency section when user has no recent outfits.
    - `POST /v1/outfits/generate` still succeeds when recency query returns empty results.
    - `POST /v1/outfits/generate` includes small-wardrobe instruction when user has < 10 items.
    - `POST /v1/outfits/generate` response structure is unchanged (no new fields in response body).

- [x] Task 8: Regression testing (AC: all)
  - [x] 8.1: Run `npm --prefix apps/api test` -- all existing (281) + new API tests pass.
  - [x] 8.2: Run `flutter test` -- all existing 727 Flutter tests pass (no Flutter changes in this story).
  - [x] 8.3: Run `flutter analyze` -- zero issues.
  - [x] 8.4: Verify existing outfit generation tests still pass with the updated `buildPrompt` signature (backward compatible via default parameters).
  - [x] 8.5: Verify the Gemini prompt format is valid and parseable (no formatting corruption from conditional sections).

## Dev Notes

- This story implements **FR-OUT-11**: "The system shall avoid suggesting recently worn items unless the wardrobe is small." It is a purely API-side prompt enhancement with NO mobile UI changes.
- The recency data source is the `outfits` table (saved outfits from Story 4.2), NOT a dedicated `wear_logs` table. The `wear_logs` table does not exist yet -- it will be created in Epic 5 (Story 5.1). When wear logging is implemented, this recency query can be enhanced to also consider `wear_logs` data, but for now, saved outfits serve as the proxy for "recently worn."
- **FR-PSH-04 (morning outfit notifications) is OUT OF SCOPE.** Story 4.7 covers this.
- **No mobile changes are needed.** The recency logic is entirely server-side. The mobile client sends the same `OutfitContext` payload and receives the same response shape. The AI simply produces more varied suggestions.

### Design Decision: Outfits as Proxy for Wear Logs

Since `wear_logs` do not exist yet, saved outfits (`outfits` table) are the best available proxy for "recently worn items." The reasoning:
1. When a user swipes right on a suggestion (Story 4.2), the outfit is saved to the `outfits` table with `created_at = now()`.
2. Manually built outfits (Story 4.3) are also saved to the `outfits` table.
3. The `created_at` timestamp on saved outfits is a reasonable approximation of "when the user planned to wear this."
4. When Epic 5 introduces `wear_logs`, this query can be updated to UNION with `wear_logs` + `wear_log_items` for more accurate recency data.

### Design Decision: 7-Day Window

A 7-day recency window was chosen because:
1. The epics file specifies "items logged as worn in the last 7 days."
2. A week-long window captures a full weekly outfit rotation cycle.
3. The `RECENCY_WINDOW_DAYS` constant makes this easily adjustable.

### Design Decision: Small Wardrobe Threshold (10 items)

The epics file says "unless the user's wardrobe is smaller than 10 items." This threshold is used to relax the recency constraint so users with limited wardrobes still get useful suggestions rather than having the AI struggle to avoid all their recently worn items.

### Project Structure Notes

- Modified API files:
  - `apps/api/src/modules/outfits/outfit-repository.js` (add `getRecentOutfitItems` method, export `RECENCY_WINDOW_DAYS`)
  - `apps/api/src/modules/outfits/outfit-generation-service.js` (accept `outfitRepo`, update `buildPrompt` signature, add recency section to prompt)
  - `apps/api/src/main.js` (pass `outfitRepo: outfitRepository` to `createOutfitGenerationService`)
- New API test files:
  - `apps/api/test/modules/outfits/outfit-repository-recency.test.js`
  - `apps/api/test/modules/outfits/outfit-generation-recency.test.js`
- Modified API test files:
  - `apps/api/test/modules/outfits/outfit-generation-service.test.js` (add prompt recency tests)
- NO new mobile files.
- NO modified mobile files.

### Technical Requirements

- **No new database migration.** The `outfits`, `outfit_items`, and `items` tables already exist. The recency query joins these existing tables.
- **No new API endpoint.** The existing `POST /v1/outfits/generate` endpoint behavior is enhanced internally.
- **No response format change.** The API response shape `{ suggestions: [...], generatedAt: "...", usage: {...} }` is unchanged. Recency mitigation only affects prompt construction.
- **Recency query:** `SELECT DISTINCT i.id, i.name, i.category, i.color FROM app_public.outfit_items oi JOIN app_public.outfits o ON o.id = oi.outfit_id JOIN app_public.items i ON i.id = oi.item_id WHERE o.created_at >= NOW() - INTERVAL '1 day' * $1 ORDER BY i.name`. Uses existing RLS policies and the `idx_outfits_profile` index.
- **Prompt enhancement:** Adds a conditional "RECENTLY WORN ITEMS" section and a conditional rule 8 to the Gemini prompt. The prompt remains identical to current behavior when no recent outfits exist.
- **Backward compatibility:** The `outfitRepo` parameter in `createOutfitGenerationService` is optional. If not provided, the service skips the recency query and behaves exactly as before. This ensures existing unit tests that don't inject `outfitRepo` continue to pass without modification.

### Architecture Compliance

- **Server authority for recency data:** The API queries the database for recent outfits. The mobile client does not send recency data -- it is derived server-side from the authoritative `outfits` table.
- **AI boundary owns inference only:** The recency data is included in the prompt as context. The AI decides how to use it. The API does NOT hard-filter items from the wardrobe list -- it trusts the AI to balance recency avoidance with outfit quality.
- **Single AI provider:** No new Gemini calls. The existing outfit generation call is enhanced with richer context.
- **No mobile boundary changes:** The mobile client is unaware of recency mitigation. The improvement is transparent.

### Previous Story Intelligence

- **Story 4.5** completed with 281 API tests and 727 Flutter tests. All must continue to pass.
- **Story 4.5** established: `usage-limit-service.js`, 429 handling, `is_premium` column, `UsageLimitCard`, `UsageIndicator`. None of these are modified by this story.
- **Story 4.2** established: `SwipeableOutfitStack`, `OutfitPersistenceService`, outfit save flow via `POST /v1/outfits`. Saved outfits populate the `outfits` table, which is the data source for this story's recency query.
- **Story 4.4** established: outfit CRUD (list, update, delete, get), `outfit-repository.js` with `createOutfitRepository`. This story adds a new method to this existing repository.
- **Story 4.1** established: `outfit-generation-service.js` with `buildPrompt`, `serializeItemsForPrompt`, `validateAndEnrichResponse`, `generateOutfits`. This story modifies `buildPrompt` and `generateOutfits`.
- **`createRuntime()` currently returns:** `config`, `pool`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `classificationService`, `calendarService`, `outfitGenerationService`, `outfitRepository`, `usageLimitService`. This story does NOT add new services -- it passes the existing `outfitRepository` into `outfitGenerationService`.
- **`handleRequest` destructuring** currently includes: `config`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `calendarService`, `outfitGenerationService`, `outfitRepository`, `usageLimitService`. No changes needed.
- **`buildPrompt` current signature:** `buildPrompt(outfitContext, serializedItems)`. This story changes it to `buildPrompt(outfitContext, serializedItems, { recentItems = [], wardrobeSize = 0 })`. Default parameters ensure backward compatibility.
- **Exported functions from outfit-generation-service.js:** `buildPrompt`, `validateAndEnrichResponse`, `serializeItemsForPrompt`. The `buildPrompt` export allows direct unit testing of the recency prompt enhancement.
- **Key learning from Story 4.1:** The Gemini prompt structure must remain clean and parseable. Conditional sections should not introduce empty lines or formatting artifacts that confuse the AI.
- **Key learning from Story 4.5:** Services can be optional in the factory pattern (`if (outfitRepo)` guard). This pattern is already used for `usageLimitService` in `main.js` (`if (usageLimitService)`).

### Key Anti-Patterns to Avoid

- DO NOT hard-filter recently worn items from the wardrobe list sent to Gemini. The AI should have access to ALL items and use its judgment about recency. Hard-filtering could result in incomplete outfit options if the wardrobe is small.
- DO NOT create a new `wear_logs` table in this story. Wear logging is Epic 5. Use the existing `outfits` table as a proxy.
- DO NOT modify the API response format. The recency enhancement is internal to prompt construction. The response shape is unchanged.
- DO NOT make any mobile changes. This story is purely API-side.
- DO NOT make `outfitRepo` a required parameter in `createOutfitGenerationService`. Keep it optional with a guard check for backward compatibility with existing tests.
- DO NOT query items directly from `outfit_items` without joining through `outfits` (the date filter is on `outfits.created_at`).
- DO NOT include the full item metadata (material, pattern, season, etc.) in the recency list. Only `id`, `name`, `category`, and `color` are needed -- the full metadata is already in the WARDROBE ITEMS section.
- DO NOT add a new Gemini API call for recency analysis. The recency data is included in the existing outfit generation prompt.

### Out of Scope

- **Morning outfit notifications** (Story 4.7): Not related to recency bias.
- **Wear logging** (Epic 5): The `wear_logs` table does not exist yet. This story uses saved outfits as a recency proxy.
- **Mobile UI changes**: No UI indicates recency mitigation. The improvement is transparent to the user.
- **Premium-specific recency behavior**: Both free and premium users benefit from recency mitigation equally.
- **User-configurable recency window**: The 7-day window is server-side only. No user setting to change it.

### References

- [Source: epics.md - Story 4.6: Recency Bias Mitigation]
- [Source: epics.md - FR-OUT-11: The system shall avoid suggesting recently worn items unless the wardrobe is small]
- [Source: prd.md - FR-OUT-01: Generate outfit suggestions using Gemini AI considering wardrobe, weather, calendar events, preferences, and wear history]
- [Source: architecture.md - AI Orchestration: outfit generation, Gemini 2.0 Flash]
- [Source: architecture.md - AI calls are brokered only by Cloud Run]
- [Source: architecture.md - Data Architecture: outfits, outfit_items tables]
- [Source: 4-1-daily-ai-outfit-generation.md - FR-OUT-11 is OUT OF SCOPE, deferred to Story 4.6]
- [Source: 4-1-daily-ai-outfit-generation.md - buildPrompt function, Gemini prompt structure]
- [Source: apps/api/src/modules/outfits/outfit-generation-service.js - buildPrompt, generateOutfits, serializeItemsForPrompt]
- [Source: apps/api/src/modules/outfits/outfit-repository.js - createOutfitRepository, existing outfit CRUD methods]
- [Source: apps/api/src/main.js - createRuntime, POST /v1/outfits/generate route handler]
- [Source: infra/sql/migrations/013_outfits.sql - outfits + outfit_items table schema, RLS policies, indexes]

## Dev Agent Record

### Implementation Summary
- Added `getRecentOutfitItems` method to outfit repository that queries distinct items from outfits saved within a configurable time window (default 7 days), scoped by RLS.
- Exported `RECENCY_WINDOW_DAYS = 7` constant for reuse and future adjustability.
- Updated `buildPrompt` signature to accept optional `{ recentItems, wardrobeSize }` with defaults for backward compatibility.
- Added conditional "RECENTLY WORN ITEMS" section and rule 8 to Gemini prompt, with different wording for small wardrobes (< 10 items).
- Updated `createOutfitGenerationService` to accept optional `outfitRepo` dependency; skips recency query when not provided.
- Wired `outfitRepository` into `outfitGenerationService` in `main.js`.

### Test Results
- API tests: 307 pass, 0 fail (281 existing + 26 new)
- Flutter tests: 727 pass, 0 fail (no changes)
- Flutter analyze: 0 issues

## File List

### Modified Files
- `apps/api/src/modules/outfits/outfit-repository.js` - Added `getRecentOutfitItems` method, exported `RECENCY_WINDOW_DAYS`
- `apps/api/src/modules/outfits/outfit-generation-service.js` - Updated `buildPrompt` with recency section, updated `createOutfitGenerationService` to accept `outfitRepo`
- `apps/api/src/main.js` - Wired `outfitRepo: outfitRepository` into `createOutfitGenerationService`
- `apps/api/test/modules/outfits/outfit-generation-service.test.js` - Added 9 recency bias tests for buildPrompt and generateOutfits

### New Files
- `apps/api/test/modules/outfits/outfit-repository-recency.test.js` - 11 unit tests for `getRecentOutfitItems`
- `apps/api/test/modules/outfits/outfit-generation-recency.test.js` - 6 integration tests for recency-aware generation
