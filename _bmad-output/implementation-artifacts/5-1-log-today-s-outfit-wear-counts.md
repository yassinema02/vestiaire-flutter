# Story 5.1: Log Today's Outfit & Wear Counts

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to log what I am wearing today quickly,
so that I can build my wear history and accurately track the value of my wardrobe.

## Acceptance Criteria

1. Given I am on the Home screen, when I tap a "Log Today's Outfit" button, then a bottom sheet opens showing two modes: "Select Items" (grid of my wardrobe items with multi-select checkboxes) and "Select Outfit" (list of previously saved outfits). The button is always visible below the outfit suggestion area. (FR-LOG-01, FR-LOG-02)

2. Given I am in "Select Items" mode on the wear-log bottom sheet, when I tap one or more wardrobe items and confirm, then a wear log is created via `POST /v1/wear-logs` with today's date and the selected item IDs, each item's `wear_count` is incremented atomically via a database RPC function (`increment_wear_counts`), each item's `last_worn_date` is set to today, and the UI updates optimistically (success snackbar shown immediately, server call in background). (FR-LOG-01, FR-LOG-03, FR-LOG-04, FR-LOG-05)

3. Given I am in "Select Outfit" mode on the wear-log bottom sheet, when I tap a previously saved outfit and confirm, then a wear log is created with all items from that outfit, `wear_count` is incremented for each item atomically, `last_worn_date` is updated for each item, and the outfit ID is recorded on the wear log as the source. (FR-LOG-02, FR-LOG-05)

4. Given I have already logged an outfit today, when I tap "Log Today's Outfit" again and log more items, then a second wear log is created for today (multiple logs per day are supported), and `wear_count` on any newly logged items increments again. Previously logged items that appear in this new log also get incremented again. (FR-LOG-03)

5. Given I log an outfit, when the API processes the request, then a row is inserted into `wear_logs` (id, profile_id, logged_date, outfit_id nullable, photo_url nullable, created_at) and one row per item is inserted into `wear_log_items` (id, wear_log_id, item_id). The `wear_count` and `last_worn_date` updates on `items` happen inside the same database transaction via an RPC function to prevent race conditions. (FR-LOG-04, FR-LOG-05)

6. Given the API call to create a wear log fails (network error, server error), when the optimistic UI has already shown success, then the app shows a retry snackbar "Failed to save wear log. Tap to retry." and the local optimistic state is reverted if the retry is dismissed.

7. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (307 API tests, 751 Flutter tests) and new tests cover: wear-log repository CRUD, RPC wear count increment, API endpoint validation, mobile WearLogService, LogOutfitBottomSheet widget, HomeScreen integration, ApiClient methods, and edge cases.

## Tasks / Subtasks

- [x] Task 1: Database - Create migration 015_wear_logs.sql (AC: 5)
  - [x] 1.1: Create `apps/api/infra/sql/migrations/015_wear_logs.sql` (actually `infra/sql/migrations/015_wear_logs.sql` per project structure). The migration creates:
    - `wear_logs` table: `id UUID PK DEFAULT gen_random_uuid()`, `profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE`, `logged_date DATE NOT NULL DEFAULT CURRENT_DATE`, `outfit_id UUID REFERENCES outfits(id) ON DELETE SET NULL` (nullable -- null when logging individual items), `photo_url TEXT` (nullable, optional photo), `created_at TIMESTAMPTZ DEFAULT now()`.
    - Enable RLS on `wear_logs` with same pattern as outfits: `USING (profile_id IN (SELECT id FROM app_public.profiles WHERE firebase_uid = current_setting('app.current_user_id', true)))`.
    - Index: `CREATE INDEX idx_wear_logs_profile_date ON app_public.wear_logs(profile_id, logged_date DESC)`.
    - `wear_log_items` table: `id UUID PK DEFAULT gen_random_uuid()`, `wear_log_id UUID NOT NULL REFERENCES wear_logs(id) ON DELETE CASCADE`, `item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE`, `created_at TIMESTAMPTZ DEFAULT now()`, `UNIQUE(wear_log_id, item_id)`.
    - Enable RLS on `wear_log_items` with join-through pattern: `USING (wear_log_id IN (SELECT wl.id FROM app_public.wear_logs wl JOIN app_public.profiles p ON p.id = wl.profile_id WHERE p.firebase_uid = current_setting('app.current_user_id', true)))`.
    - Index: `CREATE INDEX idx_wear_log_items_wear_log ON app_public.wear_log_items(wear_log_id)`.
    - Index: `CREATE INDEX idx_wear_log_items_item ON app_public.wear_log_items(item_id)` (for per-item wear history lookups).
  - [x] 1.2: Add `wear_count INTEGER NOT NULL DEFAULT 0` and `last_worn_date DATE` columns to `app_public.items` via ALTER TABLE in the same migration. These columns are referenced by the item repository's `mapItemRow` and `computeNeglectStatus` functions already (they read `row.wear_count` and `row.last_worn_date` with fallback defaults).
  - [x] 1.3: Create the atomic RPC function `app_public.increment_wear_counts(p_item_ids UUID[], p_date DATE)` that: (a) updates `SET wear_count = wear_count + 1, last_worn_date = p_date, updated_at = NOW()` for all items matching `id = ANY(p_item_ids)`, (b) returns the count of updated rows. This function runs inside the caller's transaction and respects RLS since the caller sets `app.current_user_id`.
  - [x] 1.4: Run the migration locally and verify tables, columns, indexes, RLS policies, and RPC function are created.

- [x] Task 2: API - Create wear-log repository (AC: 2, 3, 4, 5)
  - [x] 2.1: Create `apps/api/src/modules/wear-logs/wear-log-repository.js` with `createWearLogRepository({ pool })` factory. Follow the same pattern as `createOutfitRepository` and `createItemRepository`.
  - [x] 2.2: Add `async createWearLog(authContext, { itemIds, outfitId = null, photoUrl = null, loggedDate = null })` method that: (a) gets a client from pool, (b) sets RLS context, (c) looks up profile_id, (d) inserts into `wear_logs` (profile_id, logged_date, outfit_id, photo_url) RETURNING *, (e) inserts into `wear_log_items` for each item_id, (f) calls `SELECT app_public.increment_wear_counts($1::uuid[], $2::date)` with the item IDs array and logged_date, (g) commits, (h) returns the wear log with items. All within a single transaction.
  - [x] 2.3: Add `async listWearLogs(authContext, { startDate, endDate })` method that queries wear_logs joined with wear_log_items for a date range, scoped by RLS. Returns array of wear log objects with nested item IDs.
  - [x] 2.4: Add `async getWearLogsForDate(authContext, date)` method -- convenience method for checking if a log exists for today. Returns array of wear logs for a specific date.
  - [x] 2.5: Add `mapWearLogRow(row)` helper that maps snake_case DB rows to camelCase API response format.
  - [x] 2.6: Validate that `itemIds` is a non-empty array of UUID strings. Throw 400 if empty or invalid.

- [x] Task 3: API - Create wear-log routes in main.js (AC: 2, 3, 4, 5, 6)
  - [x] 3.1: Add `import { createWearLogRepository } from "./modules/wear-logs/wear-log-repository.js"` to `main.js`.
  - [x] 3.2: In `createRuntime()`, instantiate `const wearLogRepository = createWearLogRepository({ pool })` and add to the returned object.
  - [x] 3.3: Add `wearLogRepository` to the `handleRequest` destructuring.
  - [x] 3.4: Add route `POST /v1/wear-logs`: validate body has `items` (non-empty array of UUIDs, max 20), optional `outfitId` (UUID string), optional `photoUrl` (string), optional `loggedDate` (ISO date string, defaults to today). Call `wearLogRepository.createWearLog(authContext, { itemIds: body.items, outfitId: body.outfitId, photoUrl: body.photoUrl, loggedDate: body.loggedDate })`. Return 201 with `{ wearLog }`.
  - [x] 3.5: Add route `GET /v1/wear-logs?start=YYYY-MM-DD&end=YYYY-MM-DD`: require `start` and `end` query params. Call `wearLogRepository.listWearLogs(authContext, { startDate, endDate })`. Return 200 with `{ wearLogs }`.

- [x] Task 4: API - Unit tests for wear-log repository (AC: 2, 3, 4, 5, 7)
  - [x] 4.1: Create `apps/api/test/modules/wear-logs/wear-log-repository.test.js`:
    - `createWearLog` inserts a wear log with items and returns the created record.
    - `createWearLog` increments `wear_count` on each item atomically.
    - `createWearLog` updates `last_worn_date` on each item.
    - `createWearLog` with outfitId sets the outfit reference.
    - `createWearLog` without outfitId sets outfit_id to null.
    - `createWearLog` with empty itemIds array throws 400.
    - `createWearLog` respects RLS (user A cannot log user B's items).
    - `createWearLog` supports multiple logs per day.
    - `createWearLog` increments wear_count again for items logged multiple times.
    - `listWearLogs` returns logs within date range.
    - `listWearLogs` does not return logs outside date range.
    - `listWearLogs` returns empty array for dates with no logs.
    - `getWearLogsForDate` returns logs for specific date.
    - `increment_wear_counts` RPC updates correct rows and returns count.

- [x] Task 5: API - Integration tests for wear-log endpoints (AC: 2, 3, 4, 5, 6, 7)
  - [x] 5.1: Create `apps/api/test/modules/wear-logs/wear-log-endpoints.test.js`:
    - `POST /v1/wear-logs` creates a wear log and returns 201.
    - `POST /v1/wear-logs` returns 400 if items array is empty.
    - `POST /v1/wear-logs` returns 400 if items array exceeds 20.
    - `POST /v1/wear-logs` returns 401 if unauthenticated.
    - `POST /v1/wear-logs` with outfitId links the outfit.
    - `POST /v1/wear-logs` increments wear_count on items (verified via GET /v1/items).
    - `POST /v1/wear-logs` updates last_worn_date on items (verified via GET /v1/items).
    - `GET /v1/wear-logs` returns logs within date range.
    - `GET /v1/wear-logs` returns 400 if start or end missing.
    - `GET /v1/wear-logs` returns 401 if unauthenticated.
    - `GET /v1/wear-logs` returns empty array for no logs.

- [x] Task 6: Mobile - Create WearLog model (AC: 2, 3, 4)
  - [x] 6.1: Create `apps/mobile/lib/src/features/analytics/models/wear_log.dart` with a `WearLog` class containing: `id` (String), `profileId` (String), `loggedDate` (String, ISO date), `outfitId` (String?), `photoUrl` (String?), `itemIds` (List<String>), `createdAt` (String?).
  - [x] 6.2: Add `factory WearLog.fromJson(Map<String, dynamic> json)` following the dual-key pattern (camelCase + snake_case) used by `WardrobeItem`.
  - [x] 6.3: Add `Map<String, dynamic> toJson()` for serialization.

- [x] Task 7: Mobile - Add wear-log methods to ApiClient (AC: 2, 3)
  - [x] 7.1: Add `Future<Map<String, dynamic>> createWearLog({ required List<String> itemIds, String? outfitId, String? photoUrl, String? loggedDate })` to `ApiClient`. Calls `POST /v1/wear-logs` with body `{ "items": itemIds, "outfitId": outfitId, "photoUrl": photoUrl, "loggedDate": loggedDate }`.
  - [x] 7.2: Add `Future<Map<String, dynamic>> listWearLogs({ required String startDate, required String endDate })` to `ApiClient`. Calls `GET /v1/wear-logs?start=$startDate&end=$endDate`.

- [x] Task 8: Mobile - Create WearLogService (AC: 2, 3, 6)
  - [x] 8.1: Create `apps/mobile/lib/src/features/analytics/services/wear_log_service.dart` with a `WearLogService` class. Constructor accepts `ApiClient`.
  - [x] 8.2: Add `Future<WearLog> logItems(List<String> itemIds)` that calls `apiClient.createWearLog(itemIds: itemIds)` and returns a parsed `WearLog`.
  - [x] 8.3: Add `Future<WearLog> logOutfit(String outfitId, List<String> itemIds)` that calls `apiClient.createWearLog(itemIds: itemIds, outfitId: outfitId)` and returns a parsed `WearLog`.
  - [x] 8.4: Add `Future<List<WearLog>> getLogsForDateRange(String startDate, String endDate)` that calls `apiClient.listWearLogs(startDate: startDate, endDate: endDate)`.

- [x] Task 9: Mobile - Create LogOutfitBottomSheet widget (AC: 1, 2, 3, 4)
  - [x] 9.1: Create `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart`. This is a modal bottom sheet with two tabs: "Select Items" and "Select Outfit".
  - [x] 9.2: "Select Items" tab: displays a scrollable grid of wardrobe items (loaded via `ApiClient.listItems()`). Each item shows a thumbnail (photo_url), name/category label, and a selectable checkbox overlay. Multiple items can be selected. A "Log X Items" button at the bottom confirms the selection.
  - [x] 9.3: "Select Outfit" tab: displays a list of saved outfits (loaded via `ApiClient.listOutfits()`). Each outfit row shows the outfit name, item count, and occasion. Tapping an outfit selects it. A "Log Outfit" button at the bottom confirms.
  - [x] 9.4: Constructor accepts: `required WearLogService wearLogService`, `ApiClient? apiClient` (for loading items/outfits), `VoidCallback? onLogged` (called after successful log).
  - [x] 9.5: When "Log X Items" or "Log Outfit" is tapped: close the bottom sheet, immediately show a success snackbar ("Outfit logged! +X items tracked"), call the WearLogService in the background. If the API call fails, show a retry snackbar.
  - [x] 9.6: Add `Semantics` labels: "Select items to log", "Select outfit to log", "Log X items button", "Log outfit button".
  - [x] 9.7: Item grid uses 3-column layout with 4px spacing. Each item cell is 44x44 minimum touch target. Selected items show a checkmark overlay with the app's primary color (#4F46E5) border.

- [x] Task 10: Mobile - Integrate LogOutfitBottomSheet into HomeScreen (AC: 1)
  - [x] 10.1: Update `HomeScreen` constructor: add optional `WearLogService? wearLogService` parameter.
  - [x] 10.2: Add a "Log Today's Outfit" button to the HomeScreen below the outfit suggestion/swipe area. Style: `VestiaireSecondaryButton` with an icon (e.g., `Icons.check_circle_outline`). Visible in all weather states (loaded, error, denied).
  - [x] 10.3: Tapping the button opens `LogOutfitBottomSheet` via `showModalBottomSheet`. Pass `wearLogService` and `apiClient`.
  - [x] 10.4: The `onLogged` callback triggers a state refresh to update any displayed wear counts.

- [x] Task 11: Mobile - Unit tests for WearLog model and WearLogService (AC: 7)
  - [x] 11.1: Create `apps/mobile/test/features/analytics/models/wear_log_test.dart`:
    - `WearLog.fromJson` parses camelCase keys.
    - `WearLog.fromJson` parses snake_case keys.
    - `WearLog.fromJson` handles null optional fields.
    - `toJson` produces correct output.
  - [x] 11.2: Create `apps/mobile/test/features/analytics/services/wear_log_service_test.dart`:
    - `logItems` calls createWearLog with correct item IDs.
    - `logOutfit` calls createWearLog with outfitId and item IDs.
    - `getLogsForDateRange` calls listWearLogs with date params.
    - Error propagation from ApiClient to service.

- [x] Task 12: Mobile - Widget tests for LogOutfitBottomSheet (AC: 1, 2, 3, 4, 7)
  - [x] 12.1: Create `apps/mobile/test/features/analytics/widgets/log_outfit_bottom_sheet_test.dart`:
    - Renders "Select Items" tab by default.
    - Displays wardrobe items in grid with selectable checkboxes.
    - Selecting items updates the "Log X Items" button count.
    - Switching to "Select Outfit" tab shows saved outfits.
    - Tapping an outfit enables the "Log Outfit" button.
    - Confirming calls WearLogService.logItems with selected IDs.
    - Confirming outfit calls WearLogService.logOutfit with outfit ID and its item IDs.
    - onLogged callback fires after successful log.
    - Semantics labels present.
    - Empty wardrobe shows "Add items to your wardrobe first" message.
    - Empty outfits list shows "No saved outfits yet" message.

- [x] Task 13: Mobile - Widget test for HomeScreen integration (AC: 1, 7)
  - [x] 13.1: Update `apps/mobile/test/features/home/screens/home_screen_test.dart`:
    - "Log Today's Outfit" button renders on HomeScreen.
    - Tapping the button opens LogOutfitBottomSheet.
    - All existing HomeScreen tests continue to pass with new optional wearLogService parameter defaulting to null.

- [x] Task 14: Mobile - ApiClient tests for new methods (AC: 7)
  - [x] 14.1: Update `apps/mobile/test/core/networking/api_client_test.dart`:
    - `createWearLog` sends POST /v1/wear-logs with correct body.
    - `createWearLog` with outfitId includes it in the body.
    - `listWearLogs` sends GET /v1/wear-logs with start and end params.

- [x] Task 15: Regression testing (AC: all)
  - [x] 15.1: Run `flutter analyze` -- zero issues.
  - [x] 15.2: Run `flutter test` -- all existing 751 + new Flutter tests pass.
  - [x] 15.3: Run `npm --prefix apps/api test` -- all existing 307 + new API tests pass.
  - [x] 15.4: Verify existing item detail screen still shows wear_count and cost-per-wear correctly (now backed by real DB columns instead of defaulting to 0/null).
  - [x] 15.5: Verify existing neglect detection still works correctly with the new `last_worn_date` column providing real data.
  - [x] 15.6: Verify existing outfit generation recency query (Story 4.6) still works -- it uses the `outfits` table, not `wear_logs`. No conflict.

## Dev Notes

- This is the **FIRST story in Epic 5** (Wardrobe Analytics & Wear Logging). It establishes the foundational wear logging infrastructure that Stories 5.2-5.7 build upon.
- This story implements **FR-LOG-01** through **FR-LOG-05**. FR-LOG-06 (evening reminder) is Story 5.2. FR-LOG-07 (calendar view) is Story 5.3.
- **The `wear_count` and `last_worn_date` columns do not exist yet on the `items` table.** The item repository (`apps/api/src/modules/items/repository.js`) already reads `row.wear_count` and `row.last_worn_date` with fallback defaults (0 and null), so adding the columns is backward-compatible. The `computeNeglectStatus` function already uses `last_worn_date` when available.
- **The WardrobeItem model on mobile** (`apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart`) already has `wearCount` and `lastWornDate` fields with defaults. No model changes needed on mobile.
- **Atomic wear count increment is critical.** FR-LOG-05 explicitly requires "database RPC to prevent race conditions." The `increment_wear_counts` PostgreSQL function updates all items in a single SQL statement inside the transaction, preventing concurrent log operations from producing incorrect counts.

### Design Decision: Wear Logs vs Direct Item Updates

A dedicated `wear_logs` + `wear_log_items` table pair is created rather than just incrementing `wear_count` directly because:
1. **Audit trail:** Each wear event is recorded with date, items, and optional photo. This enables Story 5.3 (monthly calendar view) and Story 5.5 (analytics).
2. **Multiple logs per day:** FR-LOG-03 requires supporting multiple wear logs per day (morning outfit + evening outfit).
3. **Outfit association:** FR-LOG-02 requires linking a wear log to a previously saved outfit.
4. **Future features:** Epic 6 gamification (streak tracking in Story 6.3) needs dated wear log records to calculate streaks.

### Design Decision: Optimistic UI with Retry

The UX design specification explicitly calls for optimistic UI on wear logging: "When the user swipes right to log an outfit, trigger the success animation immediately on the client side while the database update happens asynchronously in the background." This story applies the same pattern to the "Log Today's Outfit" flow. If the API call fails, a retry snackbar is shown.

### Design Decision: Bottom Sheet with Tabs

The epics specify "select individual items or a previously saved outfit." A modal bottom sheet with two tabs (Select Items / Select Outfit) provides a clean UX that doesn't navigate away from the Home screen, keeping the logging flow as low-friction as possible (aligning with the "Zero-Friction Wear Logging" UX principle).

### Project Structure Notes

- New API files:
  - `infra/sql/migrations/015_wear_logs.sql` (migration for wear_logs, wear_log_items, items columns, RPC)
  - `apps/api/src/modules/wear-logs/wear-log-repository.js` (repository with CRUD and RPC call)
  - `apps/api/test/modules/wear-logs/wear-log-repository.test.js`
  - `apps/api/test/modules/wear-logs/wear-log-endpoints.test.js`
- Modified API files:
  - `apps/api/src/main.js` (add wearLogRepository, new routes)
- New mobile files:
  - `apps/mobile/lib/src/features/analytics/models/wear_log.dart` (data model)
  - `apps/mobile/lib/src/features/analytics/services/wear_log_service.dart` (service layer)
  - `apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart` (bottom sheet UI)
  - `apps/mobile/test/features/analytics/models/wear_log_test.dart`
  - `apps/mobile/test/features/analytics/services/wear_log_service_test.dart`
  - `apps/mobile/test/features/analytics/widgets/log_outfit_bottom_sheet_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add createWearLog, listWearLogs)
  - `apps/mobile/lib/src/features/home/screens/home_screen.dart` (add Log Today button, wearLogService param)
  - `apps/mobile/test/core/networking/api_client_test.dart` (new method tests)
  - `apps/mobile/test/features/home/screens/home_screen_test.dart` (button + bottom sheet integration tests)

### Technical Requirements

- **Database migration 015:** Creates `wear_logs` and `wear_log_items` tables, adds `wear_count` and `last_worn_date` columns to `items`, creates `increment_wear_counts` RPC function. All tables have RLS enabled.
- **RPC function `increment_wear_counts`:** Takes `UUID[]` and `DATE` params. Updates all matching items in a single statement: `UPDATE app_public.items SET wear_count = wear_count + 1, last_worn_date = $2, updated_at = NOW() WHERE id = ANY($1)`. Returns row count.
- **API endpoint `POST /v1/wear-logs`:** Accepts `{ items: string[], outfitId?: string, photoUrl?: string, loggedDate?: string }`. Items array must have 1-20 UUIDs. Returns 201 with the created wear log.
- **API endpoint `GET /v1/wear-logs`:** Accepts query params `start` and `end` (YYYY-MM-DD). Returns wear logs with nested item IDs for the date range.
- **Optimistic UI pattern:** The mobile client shows success immediately, then reconciles with the server response. On failure, retry snackbar with local state reversion.

### Architecture Compliance

- **Server authority for wear counts:** The `wear_count` increment happens server-side via RPC inside a database transaction. The mobile client does NOT directly increment counts -- it calls the API, which delegates to the atomic RPC. This prevents race conditions from concurrent log operations.
- **RLS enforces data isolation:** All wear log queries are scoped by the authenticated user's profile via RLS policies, following the same pattern as outfits and items.
- **Mobile boundary owns presentation:** The bottom sheet, item grid, optimistic UI, and success animations are mobile-only concerns. The API returns raw data.
- **No new AI calls:** This story is purely CRUD + transactional. No Gemini involvement.
- **Existing table relationships preserved:** `wear_logs.outfit_id` references `outfits(id) ON DELETE SET NULL` so deleting an outfit doesn't lose the wear history. `wear_log_items.item_id` references `items(id) ON DELETE CASCADE` so deleting an item removes associated wear log entries.

### Library / Framework Requirements

- No new dependencies on API or mobile. All functionality uses existing packages:
  - API: `pg` (PostgreSQL client), `node:http` (server) -- already in use
  - Mobile: `http` (HTTP client), `flutter/material.dart` -- already in use
- Existing packages reused:
  - `ApiClient` for HTTP calls
  - `SharedPreferences` (if caching needed -- not required for V1)
  - Material bottom sheet, grid, checkbox widgets

### File Structure Requirements

- New API module directory: `apps/api/src/modules/wear-logs/` following the existing module pattern (outfits, items, calendar, etc.)
- New mobile feature directory: `apps/mobile/lib/src/features/analytics/` -- this is the start of the analytics feature module per the architecture's Epic-to-Component mapping (`mobile/features/analytics`).
- Test files mirror source structure under `apps/api/test/modules/wear-logs/` and `apps/mobile/test/features/analytics/`.

### Testing Requirements

- API unit tests must verify:
  - `createWearLog` inserts into wear_logs + wear_log_items correctly
  - `increment_wear_counts` RPC increments atomically
  - `last_worn_date` is updated on all logged items
  - Multiple logs per day are supported
  - RLS scoping prevents cross-user access
  - Input validation (empty items, max 20 items)
  - `listWearLogs` date range filtering
- API integration tests must verify:
  - `POST /v1/wear-logs` returns 201 with correct response shape
  - `POST /v1/wear-logs` actually increments `wear_count` (verified via `GET /v1/items`)
  - `GET /v1/wear-logs` returns correct date-filtered results
  - Auth required on all endpoints
- Mobile unit tests must verify:
  - WearLog model JSON parsing (camelCase + snake_case)
  - WearLogService delegates to ApiClient correctly
- Mobile widget tests must verify:
  - LogOutfitBottomSheet renders tabs, item grid, outfit list
  - Selection and confirmation triggers service calls
  - HomeScreen shows Log Today button and opens bottom sheet
- Regression:
  - `flutter analyze` (zero issues)
  - `flutter test` (all existing 751 + new tests pass)
  - `npm --prefix apps/api test` (all existing 307 + new tests pass)

### Previous Story Intelligence

- **Story 4.7** (final Epic 4 story) completed with 307 API tests and 751 Flutter tests. All must continue to pass.
- **Story 4.6** established: recency bias mitigation queries the `outfits` table for recently worn items. This story creates a separate `wear_logs` table. In the future, Story 4.6's recency query can be enhanced to UNION with `wear_logs` for more accurate data, but that is out of scope for this story.
- **Story 4.7** established: `MorningNotificationService` and `MorningNotificationPreferences` in `apps/mobile/lib/src/core/notifications/`. These are unrelated to wear logging but the HomeScreen now has these optional params.
- **Story 2.7** established: `neglect_status` computation in `computeNeglectStatus()` in `apps/api/src/modules/items/repository.js`. It already checks `row.last_worn_date` with fallback to `created_at`. Adding the real `last_worn_date` column means neglect detection becomes accurate based on actual wear data.
- **HomeScreen constructor (as of Story 4.7):** `locationService` (required), `weatherService` (required), `sharedPreferences`, `weatherCacheService`, `outfitContextService`, `calendarService`, `calendarPreferencesService`, `calendarEventService`, `outfitGenerationService`, `outfitPersistenceService`, `onNavigateToAddItem`, `apiClient`, `morningNotificationService`, `morningNotificationPreferences`. This story adds `wearLogService` (optional).
- **VestiaireApp constructor (as of Story 4.7):** `config` (required), `authService`, `sessionManager`, `apiClient`, `notificationService`, `locationService`, `weatherService`, `subscriptionService`, `morningNotificationService`, `morningNotificationPreferences`. No changes needed in `app.dart` for this story -- the WearLogService is created locally in the HomeScreen or passed via MainShellScreen.
- **`createRuntime()` in main.js currently returns:** `config`, `pool`, `authService`, `profileService`, `itemService`, `uploadService`, `backgroundRemovalService`, `categorizationService`, `calendarEventRepo`, `classificationService`, `calendarService`, `outfitGenerationService`, `outfitRepository`, `usageLimitService`. This story adds `wearLogRepository`.
- **`handleRequest` destructuring** needs `wearLogRepository` added.
- **Key pattern from prior stories:** DI via optional constructor parameters with null defaults for test injection. Follow this for WearLogService.
- **Key pattern from Story 4.4:** Outfit repository CRUD follows the `pool.connect()` -> `set_config` -> `begin` -> query -> `commit` -> `release` pattern. The wear-log repository must follow the same pattern.

### Key Anti-Patterns to Avoid

- DO NOT increment `wear_count` via application-level read-modify-write. Use the database RPC function `increment_wear_counts` for atomicity. Concurrent log operations (e.g., user quickly double-taps) must not cause lost updates.
- DO NOT create a separate API service layer for wear logs. The repository handles the transaction directly (same pattern as outfit-repository). A service layer is unnecessary overhead for pure CRUD.
- DO NOT store wear counts only in `wear_logs` -- the `items.wear_count` column must be updated as a denormalized counter for efficient display on item detail and wardrobe grid screens. The `wear_logs` table provides the audit trail.
- DO NOT block the HomeScreen UI while waiting for the API response. Use optimistic UI: show success immediately, call API in background, revert on failure.
- DO NOT modify the existing `outfits` or `outfit_items` tables. Wear logging is a separate concern. The `outfit_id` on `wear_logs` is a reference, not a modification.
- DO NOT implement evening reminders (FR-LOG-06) in this story. That is Story 5.2.
- DO NOT implement the monthly calendar view (FR-LOG-07) in this story. That is Story 5.3.
- DO NOT add analytics dashboard features. Those are Stories 5.4-5.7.
- DO NOT create a `wear_logs` service on mobile that caches data locally. V1 is purely API-backed. Local caching can be added later if needed for offline support.

### Out of Scope

- **Evening wear-log reminders (FR-LOG-06):** Story 5.2.
- **Monthly calendar view (FR-LOG-07):** Story 5.3.
- **Analytics dashboard (FR-ANA-*):** Stories 5.4-5.7.
- **Gamification / streak tracking:** Epic 6.
- **Optional photo capture on wear log:** The schema supports `photo_url` on `wear_logs` but the UI does not include a camera button in V1. The field is nullable and ready for a future enhancement.
- **Wear log deletion/editing:** Not required by any FR. Users can log multiple times but cannot undo a log in V1.
- **Offline wear logging:** Requires local queue and sync logic. Out of scope for V1.

### References

- [Source: epics.md - Story 5.1: Log Today's Outfit & Wear Counts]
- [Source: epics.md - FR-LOG-01 through FR-LOG-05]
- [Source: prd.md - FR-LOG-01: Users shall log outfits worn today via "Log Today's Outfit" flow on Home screen]
- [Source: prd.md - FR-LOG-05: Wear count on each item shall be incremented atomically via database RPC]
- [Source: architecture.md - Data Architecture: wear_logs, wear_log_items tables]
- [Source: architecture.md - Database rules: atomic RPCs for wear counts]
- [Source: architecture.md - Epic 5 Analytics & Wear Logging -> mobile/features/analytics, api/modules/analytics, infra/sql/functions]
- [Source: ux-design-specification.md - Zero-Friction Wear Logging: Tapping "I wore this" directly from daily suggestion]
- [Source: ux-design-specification.md - Optimistic UI: trigger success animation immediately while DB update happens in background]
- [Source: apps/api/src/modules/items/repository.js - computeNeglectStatus uses row.wear_count and row.last_worn_date]
- [Source: apps/mobile/lib/src/features/wardrobe/models/wardrobe_item.dart - wearCount, lastWornDate fields already exist]
- [Source: apps/api/src/modules/outfits/outfit-repository.js - createOutfitRepository pattern for repository factory]
- [Source: infra/sql/migrations/013_outfits.sql - RLS policy pattern for outfits and outfit_items]
- [Source: 4-6-recency-bias-mitigation.md - outfits as proxy for recently worn items, future UNION with wear_logs]
- [Source: 4-7-morning-outfit-notifications.md - HomeScreen constructor params, DI pattern]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed UUID validation in repository tests: initial test item IDs ("item-1") were not valid UUIDs, switched to zero-padded UUIDs.
- Fixed flutter analyze unused import warning in home_screen_test.dart.
- Fixed HomeScreen integration test: "Log Today's Outfit" button needed scroll-to-visible due to being below the fold.

### Completion Notes List

- Task 1: Created migration 015_wear_logs.sql with wear_logs, wear_log_items tables, RLS policies, indexes, items table columns (wear_count, last_worn_date), and increment_wear_counts RPC function.
- Task 2: Created wear-log-repository.js following the outfit-repository pattern. Includes createWearLog (with full transaction, RPC call), listWearLogs (date range), getWearLogsForDate, and mapWearLogRow.
- Task 3: Added wearLogRepository to createRuntime() and handleRequest() in main.js. Added POST /v1/wear-logs and GET /v1/wear-logs routes with validation.
- Task 4: Created 19 unit tests for wear-log repository covering CRUD, RPC calls, validation, RLS, multiple logs per day, transaction rollback.
- Task 5: Created 11 integration tests for wear-log endpoints covering 201/400/401 responses, outfit linking, wear count increment, date range queries.
- Task 6: Created WearLog model with fromJson (dual-key camelCase/snake_case) and toJson.
- Task 7: Added createWearLog and listWearLogs methods to ApiClient.
- Task 8: Created WearLogService with logItems, logOutfit, and getLogsForDateRange methods.
- Task 9: Created LogOutfitBottomSheet with tabbed UI (Select Items grid + Select Outfit list), optimistic UI pattern, success/retry snackbars, semantics labels.
- Task 10: Integrated LogOutfitBottomSheet into HomeScreen with optional wearLogService parameter and "Log Today's Outfit" button.
- Task 11: Created 5 WearLog model tests and 4 WearLogService tests.
- Task 12: Created 9 LogOutfitBottomSheet widget tests.
- Task 13: Added 3 HomeScreen integration tests for wear log button.
- Task 14: Added 3 ApiClient tests for createWearLog and listWearLogs methods.
- Task 15: Full regression pass -- 337 API tests, 775 Flutter tests, 0 analyze issues.

### Implementation Plan

- Database: Migration 015 adds wear_logs + wear_log_items tables with RLS, adds wear_count/last_worn_date to items, creates atomic increment_wear_counts RPC.
- API: New wear-log module follows existing repository pattern (pool.connect -> set_config -> begin -> query -> commit -> release). Routes added to main.js.
- Mobile: New analytics feature module with WearLog model, WearLogService, and LogOutfitBottomSheet. HomeScreen gains optional wearLogService parameter.
- Optimistic UI: Bottom sheet closes immediately with success snackbar, API call runs in background, retry snackbar on failure.

### Change Log

- 2026-03-17: Story 5.1 implemented -- wear logging infrastructure (database, API, mobile UI, tests). 30 new API tests, 24 new Flutter tests. All 337 API + 775 Flutter tests pass.

### File List

New files:
- infra/sql/migrations/015_wear_logs.sql
- apps/api/src/modules/wear-logs/wear-log-repository.js
- apps/api/test/modules/wear-logs/wear-log-repository.test.js
- apps/api/test/modules/wear-logs/wear-log-endpoints.test.js
- apps/mobile/lib/src/features/analytics/models/wear_log.dart
- apps/mobile/lib/src/features/analytics/services/wear_log_service.dart
- apps/mobile/lib/src/features/analytics/widgets/log_outfit_bottom_sheet.dart
- apps/mobile/test/features/analytics/models/wear_log_test.dart
- apps/mobile/test/features/analytics/services/wear_log_service_test.dart
- apps/mobile/test/features/analytics/widgets/log_outfit_bottom_sheet_test.dart

Modified files:
- apps/api/src/main.js (added wearLogRepository import, instantiation, routes)
- apps/mobile/lib/src/core/networking/api_client.dart (added createWearLog, listWearLogs methods)
- apps/mobile/lib/src/features/home/screens/home_screen.dart (added wearLogService param, Log Today button, bottom sheet integration)
- apps/mobile/test/core/networking/api_client_test.dart (added wear log method tests)
- apps/mobile/test/features/home/screens/home_screen_test.dart (added Log Today button integration tests)
