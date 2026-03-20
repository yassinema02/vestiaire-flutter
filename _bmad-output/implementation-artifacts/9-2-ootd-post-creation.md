# Story 9.2: OOTD Post Creation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to post a photo of my Outfit of the Day to my squads and tag the items I'm wearing,
So that my friends can see my look and know what pieces I used.

## Acceptance Criteria

1. Given I am viewing a squad detail screen (Story 9.1's `SquadDetailScreen`), when I tap a "Post OOTD" floating action button or prominent CTA, then a post creation flow opens. The OOTD feed placeholder from Story 9.1 is replaced by the actual feed area (populated in Story 9.3), with the "Post OOTD" button remaining accessible. (FR-SOC-06)

2. Given I am in the OOTD post creation flow, when I tap "Take Photo" or "Choose from Gallery", then the app opens the device camera or photo gallery via `image_picker` (already in pubspec.yaml). The selected/captured image is compressed client-side to max width 1024px at 85% JPEG quality (higher resolution than wardrobe items since OOTD photos show full outfits). (FR-SOC-06)

3. Given I have selected a photo, when the creation form is displayed, then I see: (a) a preview of the selected photo, (b) a text field for an optional caption (max 150 characters, with character counter), (c) a "Tag Items" section showing a horizontally scrollable chip list of tagged wardrobe items (initially empty) with an "Add Items" button, (d) a "Share to Squads" section showing checkboxes for each of my squads (at least one must be selected), (e) a "Post" button. (FR-SOC-06)

4. Given I tap "Add Items" in the tag section, when the item picker opens, then I see my wardrobe items in a searchable/filterable grid (reuse the wardrobe grid pattern from the manual outfit builder in Story 4.3). I can tap items to toggle selection. Selected items appear with a checkmark overlay. Tapping "Done" returns to the creation form with selected items shown as removable chips (thumbnail + item name). (FR-SOC-06)

5. Given I have filled in the post details and selected at least one squad, when I tap "Post", then the app: (a) requests a signed upload URL from `POST /v1/uploads/signed-url` with `purpose: "ootd_post"`, (b) uploads the compressed image to Cloud Storage via the signed URL, (c) calls `POST /v1/squads/posts` with `{ photoUrl, caption, taggedItemIds, squadIds }`, (d) the API creates one `ootd_posts` row and one `ootd_post_squads` row per selected squad (many-to-many), plus one `ootd_post_items` row per tagged item, (e) on success shows a SnackBar "OOTD posted!" and navigates back to the squad detail. (FR-SOC-06)

6. Given the upload or post creation fails, when an error occurs, then the user sees a user-friendly error SnackBar and can retry. The form state is preserved (photo, caption, tags, squad selections) so no re-entry is needed. (FR-SOC-06)

7. Given I have no squads, when I attempt to create a post (e.g., via a global "Post OOTD" action), then I see a message prompting me to create or join a squad first, with navigation to the squad list screen. (FR-SOC-06)

8. Given a database migration is needed, when migration 026 runs, then it creates `ootd_posts`, `ootd_post_squads`, and `ootd_post_items` tables in `app_public` schema with RLS policies ensuring: users can see posts shared to squads they belong to, users can only create posts as themselves, users can only delete their own posts. (FR-SOC-06)

9. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (869+ API tests, 1292+ Flutter tests) and new tests cover: OOTD post CRUD endpoints, post service logic (validation, multi-squad sharing, item tagging), OotdCreateScreen widget (photo selection, caption, item tagging, squad selection, posting flow), ApiClient OOTD methods, OotdService methods, and OotdPost/OotdPostItem model parsing.

## Tasks / Subtasks

- [x] Task 1: Database migration -- create ootd_posts, ootd_post_squads, ootd_post_items tables (AC: 5, 8)
  - [x] 1.1: Create `infra/sql/migrations/026_ootd_posts.sql` that creates:
    - `app_public.ootd_posts`: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `author_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `photo_url TEXT NOT NULL`, `caption VARCHAR(150)`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, `deleted_at TIMESTAMPTZ` (soft delete).
    - `app_public.ootd_post_squads` (join table): `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE`, `squad_id UUID NOT NULL REFERENCES app_public.style_squads(id) ON DELETE CASCADE`, UNIQUE constraint on `(post_id, squad_id)`.
    - `app_public.ootd_post_items` (tagged items): `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE`, `item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE`, UNIQUE constraint on `(post_id, item_id)`.
    - Indexes: `idx_ootd_posts_author_id` on `ootd_posts(author_id)`, `idx_ootd_posts_created_at` on `ootd_posts(created_at DESC)`, `idx_ootd_posts_deleted_at` on `ootd_posts(deleted_at)`, `idx_ootd_post_squads_squad_id` on `ootd_post_squads(squad_id)`, `idx_ootd_post_squads_post_id` on `ootd_post_squads(post_id)`, `idx_ootd_post_items_post_id` on `ootd_post_items(post_id)`, `idx_ootd_post_items_item_id` on `ootd_post_items(item_id)`.
    - Column comments on all fields.
  - [x]1.2: Create RLS policies in `infra/sql/policies/026_ootd_posts_rls.sql`:
    - `ootd_posts` SELECT: user can see posts where at least one `ootd_post_squads.squad_id` is in a squad the user belongs to (via `squad_memberships`), AND `deleted_at IS NULL`.
    - `ootd_posts` INSERT: authenticated user can insert where `author_id = auth.uid()`.
    - `ootd_posts` DELETE: only the `author_id` can soft-delete their own post.
    - `ootd_post_squads` SELECT: user can see rows where `squad_id` is in a squad the user belongs to.
    - `ootd_post_squads` INSERT: restricted to API service role (inserts go through API validation).
    - `ootd_post_items` SELECT: user can see rows where the parent `post_id` is visible to them.
    - `ootd_post_items` INSERT: restricted to API service role.
    - Enable RLS on all three tables.

- [x]Task 2: API -- Create OOTD post repository (AC: 5, 8)
  - [x]2.1: Create `apps/api/src/modules/squads/ootd-repository.js` exporting `createOotdRepository({ pool })` with methods:
    - `createPost(authContext, { photoUrl, caption, squadIds, taggedItemIds })` -- in a single transaction: insert into `ootd_posts`, insert one `ootd_post_squads` row per squad ID, insert one `ootd_post_items` row per tagged item ID. Return the created post with its items and squads.
    - `getPostById(authContext, postId)` -- get post by ID with author profile info (display name, photo URL), tagged items (with item photo_url, name, category), and squad IDs. Return null if not found or not visible via RLS.
    - `listPostsForSquad(authContext, squadId, { limit, cursor })` -- paginated posts for a specific squad, ordered by `created_at DESC`. Joins author profile info. Returns `{ posts, nextCursor }`. Filter `deleted_at IS NULL`.
    - `listPostsForUser(authContext, { limit, cursor })` -- paginated posts across all user's squads, ordered by `created_at DESC`. Used by the "All Squads" feed filter. Returns `{ posts, nextCursor }`.
    - `softDeletePost(authContext, postId)` -- sets `deleted_at = NOW()` on `ootd_posts` WHERE `id = postId AND author_id = authContext.userId`.
    - `getPostItemsByPostId(postId)` -- returns all tagged items for a post with item details.
    - `getPostSquadsByPostId(postId)` -- returns all squad IDs for a post.
  - [x]2.2: `mapPostRow(row)` maps snake_case DB columns to camelCase: `id`, `authorId`, `photoUrl`, `caption`, `createdAt`, `authorDisplayName`, `authorPhotoUrl`, `taggedItems` (array), `squadIds` (array), `reactionCount`, `commentCount`.
  - [x]2.3: `mapPostItemRow(row)` maps: `id`, `postId`, `itemId`, `itemName`, `itemPhotoUrl`, `itemCategory`.

- [x]Task 3: API -- Create OOTD post service (AC: 3, 5, 6, 7)
  - [x]3.1: Create `apps/api/src/modules/squads/ootd-service.js` exporting `createOotdService({ ootdRepo, squadRepo })` with methods:
    - `createPost(authContext, { photoUrl, caption, squadIds, taggedItemIds })` -- validates: photoUrl required (non-empty string), caption max 150 chars (optional), squadIds is non-empty array of UUIDs, taggedItemIds is array of UUIDs (optional, can be empty). For each squadId, verify user is a member via `squadRepo.getMembership()`. If any squadId is invalid or user is not a member, throw 403. Delegates to `ootdRepo.createPost()`. Returns created post.
    - `getPost(authContext, { postId })` -- delegates to `ootdRepo.getPostById()`, throws 404 if not found.
    - `listSquadPosts(authContext, { squadId, limit, cursor })` -- verifies user is a member of the squad, then delegates to `ootdRepo.listPostsForSquad()`. Default limit: 20. Max limit: 50.
    - `listFeedPosts(authContext, { limit, cursor })` -- delegates to `ootdRepo.listPostsForUser()`. Default limit: 20. Max limit: 50.
    - `deletePost(authContext, { postId })` -- loads post, verifies `author_id === authContext.userId` (throws 403 if not), calls `ootdRepo.softDeletePost()`.
  - [x]3.2: `validatePostInput({ photoUrl, caption, squadIds, taggedItemIds })` -- validates all fields with clear error messages. Returns sanitized input.

- [x]Task 4: API -- Wire OOTD endpoints in main.js (AC: 5)
  - [x]4.1: In `apps/api/src/main.js`, add `createOotdRepository` and `createOotdService` to `createRuntime()`. Add `ootdRepo` to repositories and `ootdService` to services. Destructure `ootdService` in `handleRequest`.
  - [x]4.2: Add routes (all require `requireAuth`):
    - `POST /v1/squads/posts` -- `ootdService.createPost(authContext, body)` -> 201
    - `GET /v1/squads/posts/feed` -- `ootdService.listFeedPosts(authContext, { limit, cursor from query })` -> 200
    - `GET /v1/squads/:id/posts` -- `ootdService.listSquadPosts(authContext, { squadId, limit, cursor from query })` -> 200
    - `GET /v1/squads/posts/:postId` -- `ootdService.getPost(authContext, { postId })` -> 200
    - `DELETE /v1/squads/posts/:postId` -- `ootdService.deletePost(authContext, { postId })` -> 204
  - [x]4.3: Route ordering: place `POST /v1/squads/posts` and `GET /v1/squads/posts/feed` BEFORE `GET /v1/squads/:id` to prevent "posts" being parsed as a squad ID. Place `GET /v1/squads/posts/:postId` and `DELETE /v1/squads/posts/:postId` after the feed route. Use regex patterns consistent with existing squad routes.

- [x]Task 5: Mobile -- Create OotdPost and OotdPostItem models (AC: 5)
  - [x]5.1: Create `apps/mobile/lib/src/features/squads/models/ootd_post.dart` with:
    - `OotdPost`: `String id`, `String authorId`, `String photoUrl`, `String? caption`, `DateTime createdAt`, `String? authorDisplayName`, `String? authorPhotoUrl`, `List<OotdPostItem> taggedItems`, `List<String> squadIds`, `int reactionCount`, `int commentCount`. Factory `fromJson(Map<String, dynamic> json)`.
    - `OotdPostItem`: `String id`, `String postId`, `String itemId`, `String? itemName`, `String? itemPhotoUrl`, `String? itemCategory`. Factory `fromJson(Map<String, dynamic> json)`.

- [x]Task 6: Mobile -- Create OotdService (AC: 5, 6)
  - [x]6.1: Create `apps/mobile/lib/src/features/squads/services/ootd_service.dart` with `OotdService` class. Constructor: `OotdService({ required ApiClient apiClient })`.
    - `Future<OotdPost> createPost({ required String photoUrl, String? caption, required List<String> squadIds, List<String> taggedItemIds = const [] })` -- calls `_apiClient.authenticatedPost("/v1/squads/posts", body: { ... })`.
    - `Future<Map<String, dynamic>> listFeedPosts({ int limit = 20, String? cursor })` -- calls `_apiClient.authenticatedGet("/v1/squads/posts/feed?limit=$limit${cursor != null ? '&cursor=$cursor' : ''}")`. Returns `{ posts: List<OotdPost>, nextCursor: String? }`.
    - `Future<Map<String, dynamic>> listSquadPosts(String squadId, { int limit = 20, String? cursor })` -- calls `_apiClient.authenticatedGet("/v1/squads/$squadId/posts?...")`. Returns `{ posts: List<OotdPost>, nextCursor: String? }`.
    - `Future<OotdPost> getPost(String postId)` -- calls `_apiClient.authenticatedGet("/v1/squads/posts/$postId")`.
    - `Future<void> deletePost(String postId)` -- calls `_apiClient.authenticatedDelete("/v1/squads/posts/$postId")`.

- [x]Task 7: Mobile -- Add OOTD methods to ApiClient (AC: 5)
  - [x]7.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add methods after the `// --- Squads ---` block with a `// --- OOTD Posts ---` comment:
    - `Future<Map<String, dynamic>> createOotdPost(Map<String, dynamic> body)` -- `authenticatedPost("/v1/squads/posts", body: body)`.
    - `Future<Map<String, dynamic>> listFeedPosts({ int limit = 20, String? cursor })` -- `authenticatedGet(...)` returning parsed map.
    - `Future<Map<String, dynamic>> listSquadPosts(String squadId, { int limit = 20, String? cursor })` -- `authenticatedGet(...)`.
    - `Future<Map<String, dynamic>> getOotdPost(String postId)` -- `authenticatedGet("/v1/squads/posts/$postId")`.
    - `Future<void> deleteOotdPost(String postId)` -- `authenticatedDelete("/v1/squads/posts/$postId")`.

- [x]Task 8: Mobile -- Create OotdCreateScreen (AC: 1, 2, 3, 4, 5, 6, 7)
  - [x]8.1: Create `apps/mobile/lib/src/features/squads/screens/ootd_create_screen.dart` with `OotdCreateScreen` StatefulWidget. Constructor: `{ required OotdService ootdService, required SquadService squadService, required ApiClient apiClient, String? preselectedSquadId, super.key }`.
  - [x]8.2: **Photo selection step**: On open, present two options: "Take Photo" (camera icon) and "Choose from Gallery" (photo icon), following the same pattern as `AddItemScreen` (Story 2.1). Use `ImagePicker().pickImage(source: ..., maxWidth: 1024, imageQuality: 85)`. After selection, transition to the form view.
  - [x]8.3: **Caption field**: `TextFormField` with `maxLength: 150`, `maxLengthEnforcement: MaxLengthEnforcement.enforced`, hint text "What are you wearing today?", character counter via `buildCounter`.
  - [x]8.4: **Item tagging UI**: Section header "Tag Your Items" with a horizontally scrollable `ListView` of chips. Each chip shows item thumbnail (24x24 CircleAvatar) and item name, with an "x" to remove. "Add Items" chip/button at the end opens the item picker.
  - [x]8.5: **Item picker**: Full-screen modal or bottom sheet. Load user's wardrobe items via `apiClient.listItems()`. Display in a 3-column grid with photo thumbnails. Tap to toggle selection (checkmark overlay). Include a search bar filtering by item name. "Done" button at bottom with count badge ("Done (3)"). Pass back selected item IDs and metadata.
  - [x]8.6: **Squad selection UI**: Section header "Share to Squads". Load user's squads via `squadService.listMySquads()`. Display as a list of `CheckboxListTile` widgets with squad name and member count. If `preselectedSquadId` is provided, pre-check that squad. At least one squad must be selected (disable "Post" button otherwise).
  - [x]8.7: **Post button and upload flow**: "Post" `ElevatedButton` at bottom. On tap: (a) show loading overlay, (b) call `apiClient.getSignedUploadUrl(purpose: "ootd_post")`, (c) call `apiClient.uploadImage(imagePath, uploadUrl)`, (d) call `ootdService.createPost(photoUrl: publicUrl, caption: caption, squadIds: selectedSquadIds, taggedItemIds: selectedItemIds)`, (e) on success pop screen and show SnackBar "OOTD posted!", (f) on failure show error SnackBar, hide loading, preserve form state for retry.
  - [x]8.8: **Empty squads guard**: If `squadService.listMySquads()` returns empty, show a message "Join or create a squad first to share your OOTD" with a button navigating to `SquadListScreen`.
  - [x]8.9: Follow Vibrant Soft-UI design: 16px border radius, subtle shadows, `#F3F4F6` background, `#1F2937` text, `#6B7280` secondary text, `#4F46E5` primary accent.
  - [x]8.10: Add `Semantics` labels on: photo options, caption field, each tagged item chip, each squad checkbox, post button, loading indicator.

- [x]Task 9: Mobile -- Add "Post OOTD" entry point to SquadDetailScreen (AC: 1)
  - [x]9.1: In `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart`, replace the "Coming Soon" OOTD feed placeholder with a "Post OOTD" FAB or prominent button.
  - [x]9.2: Tapping "Post OOTD" navigates to `OotdCreateScreen` with `preselectedSquadId` set to the current squad. On return (after successful post), the screen should be ready for Story 9.3's feed implementation.
  - [x]9.3: Also add a "Post OOTD" action in the SquadListScreen app bar (or FAB) for creating a post from the squad list (no preselected squad).

- [x]Task 10: API -- Signed URL support for ootd_post purpose (AC: 5)
  - [x]10.1: In the existing upload service (likely `apps/api/src/modules/wardrobe/upload-service.js` or a shared upload module), verify that `POST /v1/uploads/signed-url` supports `purpose: "ootd_post"`. The storage path should be `users/{firebase_uid}/ootd/{uuid}.jpg`. If the upload service only handles `item_photo` purpose, add `ootd_post` as a new valid purpose with the `ootd/` subfolder.
  - [x]10.2: Ensure the signed URL response returns both the `uploadUrl` (for PUT) and the `publicUrl` (the final GCS path used in the `ootd_posts.photo_url` column). Follow the exact same pattern as `item_photo`.

- [x]Task 11: API -- Unit tests for OOTD post service (AC: 5, 9)
  - [x]11.1: Create `apps/api/test/modules/squads/ootd-service.test.js`:
    - `createPost` validates photoUrl required.
    - `createPost` validates caption max 150 chars.
    - `createPost` validates squadIds is non-empty array.
    - `createPost` validates taggedItemIds is array (can be empty).
    - `createPost` verifies user is member of all selected squads.
    - `createPost` throws 403 when user is not member of a squad.
    - `createPost` creates post with items and squads on success.
    - `getPost` returns post with tagged items and author info.
    - `getPost` throws 404 for non-existent post.
    - `listSquadPosts` verifies membership before listing.
    - `listSquadPosts` returns paginated results with cursor.
    - `listFeedPosts` returns posts across all user squads.
    - `deletePost` soft-deletes when user is author.
    - `deletePost` throws 403 when user is not author.
    - `validatePostInput` rejects missing photoUrl.
    - `validatePostInput` rejects caption > 150 chars.
    - `validatePostInput` rejects empty squadIds array.

- [x]Task 12: API -- Integration tests for OOTD endpoints (AC: 5, 9)
  - [x]12.1: Create `apps/api/test/modules/squads/ootd-endpoint.test.js`:
    - POST /v1/squads/posts returns 201 with created post.
    - POST /v1/squads/posts returns 400 for missing photoUrl.
    - POST /v1/squads/posts returns 400 for missing squadIds.
    - POST /v1/squads/posts returns 403 for non-member squad.
    - POST /v1/squads/posts returns 401 without auth.
    - GET /v1/squads/posts/feed returns 200 with paginated posts.
    - GET /v1/squads/:id/posts returns 200 with squad-filtered posts.
    - GET /v1/squads/:id/posts returns 403 for non-member.
    - GET /v1/squads/posts/:postId returns 200 with post detail.
    - GET /v1/squads/posts/:postId returns 404 for non-existent post.
    - DELETE /v1/squads/posts/:postId returns 204 for author.
    - DELETE /v1/squads/posts/:postId returns 403 for non-author.
    - DELETE /v1/squads/posts/:postId returns 401 without auth.

- [x]Task 13: Mobile -- Widget tests for OotdCreateScreen (AC: 2, 3, 4, 5, 6, 7, 9)
  - [x]13.1: Create `apps/mobile/test/features/squads/screens/ootd_create_screen_test.dart`:
    - Renders photo selection options (camera and gallery).
    - After photo selection, shows form with caption, tag items, and squad selection.
    - Caption field enforces 150 character limit.
    - "Add Items" opens item picker with wardrobe grid.
    - Selected items appear as removable chips.
    - Squad list loads and displays checkboxes.
    - Preselected squad is checked on load.
    - Post button is disabled when no squad is selected.
    - Successful post shows success SnackBar and pops screen.
    - Failed post shows error SnackBar and preserves form state.
    - Empty squads shows "join or create" message.
    - Semantics labels present on all interactive elements.

- [x]Task 14: Mobile -- Model tests for OotdPost and OotdPostItem (AC: 5, 9)
  - [x]14.1: Create `apps/mobile/test/features/squads/models/ootd_post_test.dart`:
    - `OotdPost.fromJson` parses all fields correctly.
    - `OotdPost.fromJson` handles null caption, authorPhotoUrl.
    - `OotdPost.fromJson` parses taggedItems array.
    - `OotdPost.fromJson` handles empty taggedItems.
    - `OotdPostItem.fromJson` parses all fields correctly.
    - `OotdPostItem.fromJson` handles null itemName, itemPhotoUrl.

- [x]Task 15: Mobile -- OotdService and ApiClient OOTD method tests (AC: 5, 9)
  - [x]15.1: Update `apps/mobile/test/core/networking/api_client_test.dart`:
    - `createOotdPost` calls POST /v1/squads/posts.
    - `listFeedPosts` calls GET /v1/squads/posts/feed with query params.
    - `listSquadPosts` calls GET /v1/squads/:id/posts.
    - `getOotdPost` calls GET /v1/squads/posts/:postId.
    - `deleteOotdPost` calls DELETE /v1/squads/posts/:postId.
  - [x]15.2: Create `apps/mobile/test/features/squads/services/ootd_service_test.dart`:
    - `createPost` calls correct API endpoint and returns OotdPost.
    - `listFeedPosts` returns paginated posts map.
    - `listSquadPosts` returns paginated posts for squad.
    - `getPost` returns OotdPost.
    - `deletePost` calls correct DELETE endpoint.

- [x]Task 16: Mobile -- Update SquadDetailScreen tests for OOTD entry point (AC: 1, 9)
  - [x]16.1: Update `apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart`:
    - "Post OOTD" button/FAB is visible on squad detail.
    - Tapping "Post OOTD" navigates to OotdCreateScreen with preselectedSquadId.
    - OOTD feed placeholder is replaced with post creation entry point.

- [x]Task 17: Regression testing (AC: all)
  - [x]17.1: Run `flutter analyze` -- zero new issues.
  - [x]17.2: Run `flutter test` -- all existing 1292+ tests plus new tests pass.
  - [x]17.3: Run `npm --prefix apps/api test` -- all existing 869+ API tests plus new tests pass.
  - [x]17.4: Verify existing upload flow for wardrobe items still works (signed URL with `purpose: "item_photo"` unchanged).
  - [x]17.5: Verify squad CRUD from Story 9.1 still works correctly with new OOTD routes added.

## Dev Notes

- This is Story 9.2 in Epic 9 (Social OOTD Feed / Style Squads). It builds on the squad infrastructure from Story 9.1 (done) to add the ability to create OOTD posts with photos, captions, item tags, and multi-squad sharing. Story 9.3 will add the feed display/filtering, and Story 9.4 will add reactions/comments.
- The OOTD post creation follows the same upload pipeline established in Story 2.1: `getSignedUploadUrl` -> `uploadImage` -> create record via API. The key difference is a new `purpose: "ootd_post"` for the signed URL, which stores images under `users/{uid}/ootd/` rather than `users/{uid}/items/`.
- The `ootd_posts` table uses a many-to-many relationship with squads via `ootd_post_squads`. A single post can be shared to multiple squads simultaneously. This is a key differentiator from a simple `squad_id` foreign key.
- Item tagging is optional. Users can post without tagging items, but tagging enables the "Steal This Look" feature in Story 9.5.
- Soft delete on posts: `deleted_at` column, same pattern as `style_squads`. All queries filter `deleted_at IS NULL`.
- The pagination pattern uses cursor-based pagination (cursor = last post's `created_at` timestamp or UUID). This avoids offset-based pagination issues with new posts being added.
- Photo resolution for OOTD posts is 1024px max width (vs 512px for wardrobe items) since full-outfit photos benefit from more detail in a social feed context.
- The `reactionCount` and `commentCount` fields on the post response are computed aggregates (COUNT from `ootd_reactions` and `ootd_comments` tables). These tables will be created in Story 9.4. For now, these fields return 0 since the tables don't exist yet. The repository query should use LEFT JOIN or COALESCE to handle missing tables gracefully, OR simply hardcode 0 until Story 9.4 adds the tables. Preferred approach: hardcode 0 in Story 9.2, then update the query in Story 9.4.

### Database Schema Design

```sql
-- ootd_posts
CREATE TABLE app_public.ootd_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  caption VARCHAR(150),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- ootd_post_squads (many-to-many: which squads a post is shared to)
CREATE TABLE app_public.ootd_post_squads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  squad_id UUID NOT NULL REFERENCES app_public.style_squads(id) ON DELETE CASCADE,
  UNIQUE (post_id, squad_id)
);

-- ootd_post_items (tagged wardrobe items on a post)
CREATE TABLE app_public.ootd_post_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES app_public.items(id) ON DELETE CASCADE,
  UNIQUE (post_id, item_id)
);
```

### API Endpoint Summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /v1/squads/posts | Yes | Create OOTD post |
| GET | /v1/squads/posts/feed | Yes | List feed across all squads |
| GET | /v1/squads/:id/posts | Yes | List posts for a specific squad |
| GET | /v1/squads/posts/:postId | Yes | Get post detail |
| DELETE | /v1/squads/posts/:postId | Yes | Delete own post (soft delete) |

### Route Ordering in main.js

Critical: OOTD post routes must integrate with existing squad routes without breaking them. Add these patterns:

```javascript
// OOTD post routes - order matters!
// Static paths first, then parameterized
if (method === "POST" && url.pathname === "/v1/squads/posts") { ... }
if (method === "GET" && url.pathname === "/v1/squads/posts/feed") { ... }
const ootdPostIdMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)$/);
// GET and DELETE on /v1/squads/posts/:postId
// THEN existing squad routes:
const squadPostsMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)\/posts$/);
// GET /v1/squads/:id/posts (squad-specific feed)
// THEN existing squad :id routes
const squadIdMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)$/);
```

Place all `/v1/squads/posts` routes BEFORE `/v1/squads/:id` to prevent "posts" being parsed as a squad UUID.

### Upload Flow for OOTD Photos

The existing upload infrastructure supports multiple purposes. Add `ootd_post` purpose:
- Storage path: `users/{firebase_uid}/ootd/{uuid}.jpg`
- Reuse the same `POST /v1/uploads/signed-url` endpoint
- Client flow: `getSignedUploadUrl(purpose: "ootd_post")` -> `uploadImage(path, url)` -> `createPost(photoUrl: publicUrl, ...)`

### Project Structure Notes

- New API files:
  - `apps/api/src/modules/squads/ootd-repository.js`
  - `apps/api/src/modules/squads/ootd-service.js`
  - `apps/api/test/modules/squads/ootd-service.test.js`
  - `apps/api/test/modules/squads/ootd-endpoint.test.js`
- New mobile files:
  - `apps/mobile/lib/src/features/squads/models/ootd_post.dart`
  - `apps/mobile/lib/src/features/squads/services/ootd_service.dart`
  - `apps/mobile/lib/src/features/squads/screens/ootd_create_screen.dart`
  - `apps/mobile/test/features/squads/models/ootd_post_test.dart`
  - `apps/mobile/test/features/squads/services/ootd_service_test.dart`
  - `apps/mobile/test/features/squads/screens/ootd_create_screen_test.dart`
- New migration files:
  - `infra/sql/migrations/026_ootd_posts.sql`
  - `infra/sql/policies/026_ootd_posts_rls.sql`
- Modified files:
  - `apps/api/src/main.js` (add ootd repository/service to createRuntime, add 5 OOTD routes)
  - `apps/api/src/modules/squads/` or upload module (add `ootd_post` purpose to signed URL generation)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add 5 OOTD methods)
  - `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart` (replace OOTD placeholder with "Post OOTD" entry point)
  - `apps/mobile/lib/src/features/squads/screens/squad_list_screen.dart` (add "Post OOTD" action)
  - `apps/mobile/test/core/networking/api_client_test.dart` (add OOTD method tests)
  - `apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart` (update for OOTD entry point)

### Technical Requirements

- **PostgreSQL 16** with RLS. All three new tables require RLS policies. Post visibility is gated by squad membership through the `ootd_post_squads` join table.
- **No new API dependencies.** Uses existing `pool`, auth middleware, and upload service infrastructure.
- **Mobile dependency: `image_picker`** -- already in pubspec.yaml from Story 1.5/2.1. No new dependencies needed.
- **No AI calls** in this story. Pure CRUD + photo upload + authorization.
- **Signed URL upload pattern** reuses the existing 3-step flow: get signed URL -> PUT image -> create record. Only the `purpose` parameter and storage path differ.

### Architecture Compliance

- **Epic 9 component mapping:** `mobile/features/squads`, `api/modules/squads` (architecture.md). OOTD post files live within the squads module, not a separate module.
- **RLS on all user-facing tables.** All three new tables require RLS policies gated by squad membership.
- **Server-side enforcement** for squad membership validation (user must be member of all selected squads before post is created).
- **Media storage** via Cloud Storage with signed URLs. OOTD photos are private, delivered via signed URLs with bounded TTL.
- **Soft delete pattern** consistent with `style_squads` from Story 9.1.
- **Optimistic UI** is NOT used for post creation (it requires server confirmation for the photo upload). Post creation shows a loading state.

### Library / Framework Requirements

- **API:** No new dependencies. Existing `pool`, upload service, auth middleware.
- **Mobile:** `image_picker` (already present, ^1.1.2). No new dependencies. All UI uses existing Flutter Material widgets.

### File Structure Requirements

- OOTD repository and service live in `apps/api/src/modules/squads/` alongside squad files (not a separate `ootd` module).
- Mobile OOTD files live in `apps/mobile/lib/src/features/squads/` (models, services, screens subdirectories).
- Test files mirror source structure exactly.

### Testing Requirements

- **API tests** use the existing Node.js built-in test runner. Follow patterns from `squad-service.test.js` and `squad-endpoint.test.js`.
- **Mock the ootd repository and squad repository** in service tests. Return controlled data for different scenarios.
- **Flutter widget tests** follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services.
- **Target:** All existing tests pass (869 API, 1292 Flutter) plus new tests for all OOTD post functionality.

### Previous Story Intelligence

- **Story 9.1** (done, squad infrastructure): Created `style_squads` and `squad_memberships` tables (migration 025), squad API module (`squad-repository.js`, `squad-service.js`), mobile squad feature (`Squad`/`SquadMember` models, `SquadService`, `SquadListScreen`, `SquadDetailScreen`). Bottom nav restructured: "Add" tab replaced by "Social" tab with FAB. 869 API tests, 1292 Flutter tests. The `SquadDetailScreen` has a "Coming Soon" placeholder for the OOTD feed -- this story replaces it.
- **Story 2.1** (done, photo upload pattern): Established the canonical photo upload flow: `image_picker` -> `getSignedUploadUrl(purpose)` -> `uploadImage(path, url)` -> create record via API. `maxWidth: 512, imageQuality: 85` for wardrobe items. The upload service handles signed URL generation with purpose-based storage paths.
- **Story 4.3** (done, manual outfit builder): Established the item picker/selector pattern with wardrobe grid, tap-to-select, checkmark overlay. Reuse this pattern for OOTD item tagging.
- **Key patterns from Story 9.1:**
  - Factory pattern: `createSquadService({ squadRepo })`, `createSquadRepository({ pool })`.
  - Route regex matching: `url.pathname.match(/^\/v1\/squads\/([^/]+)$/)`.
  - `mapSquadRow(row)` / `mapMembershipRow(row)` for snake_case to camelCase mapping.
  - 201 for creation, 200 for reads, 204 for deletes.
  - `squadRepo.getMembership(squadId, userId)` for membership checks.
  - `mounted` guard before `setState` in async callbacks.
  - `Semantics` labels on all interactive elements.

### Key Anti-Patterns to Avoid

- DO NOT create a separate `ootd` API module directory. OOTD files belong in `apps/api/src/modules/squads/` alongside squad files per architecture mapping.
- DO NOT create `ootd_comments` or `ootd_reactions` tables in this story. Those belong to Story 9.4.
- DO NOT implement feed display/scrolling in this story. Feed UI comes in Story 9.3. This story only creates posts and returns them via API.
- DO NOT skip the many-to-many `ootd_post_squads` table. A post can be shared to multiple squads. Do NOT use a single `squad_id` FK on `ootd_posts`.
- DO NOT allow creating a post in a squad the user is not a member of. Validate all squad IDs server-side.
- DO NOT hard-delete posts. Use soft delete (`deleted_at`) consistent with squads pattern.
- DO NOT forget to add `ootd_post` as a valid purpose in the upload service. Without it, the signed URL request will fail.
- DO NOT use Supabase client or direct database access from Flutter. All operations go through the Cloud Run API.
- DO NOT add a separate image compression library. `image_picker`'s built-in `maxWidth` and `imageQuality` handle compression.
- DO NOT break existing squad routes. OOTD routes must be carefully ordered to avoid "posts" being parsed as a squad ID.

### Out of Scope

- **Social feed display and filtering** (Story 9.3) -- this story creates posts, 9.3 displays them
- **Reactions and comments** (Story 9.4) -- `ootd_reactions` and `ootd_comments` tables deferred
- **"Steal This Look" matching** (Story 9.5)
- **Social notification sending** (Story 9.6) -- posting does not trigger notifications yet
- **Post editing after creation** (not in requirements)
- **Video posts** (not in requirements -- photos only)
- **Image filters or editing** (not in requirements)
- **Content moderation** (deferred per PRD)

### References

- [Source: epics.md - Story 9.2: OOTD Post Creation]
- [Source: epics.md - Epic 9: Social OOTD Feed (Style Squads), FR-SOC-06]
- [Source: prd.md - FR-SOC-06: Users shall post OOTD photos to selected squads with optional caption (max 150 chars) and tagged wardrobe items]
- [Source: architecture.md - Important tables: ootd_posts, ootd_comments, ootd_reactions]
- [Source: architecture.md - Cloud Storage for private wardrobe and social images]
- [Source: architecture.md - Media: social post media as derived media artifact]
- [Source: architecture.md - Images uploaded through authenticated server-issued upload flow or signed URL orchestration]
- [Source: architecture.md - Delivery uses signed URLs with bounded TTL]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - Squad membership and role checks gate social operations]
- [Source: architecture.md - Epic 9 Social OOTD -> mobile/features/squads, api/modules/squads, api/modules/notifications]
- [Source: architecture.md - Optimistic UI allowed for reactions and save actions]
- [Source: 9-1-squad-creation-management.md - Squad infrastructure, 869 API tests, 1292 Flutter tests]
- [Source: 2-1-upload-item-photo-camera-gallery.md - Upload pipeline pattern, image_picker, signed URL flow]
- [Source: 4-3-manual-outfit-building.md - Item picker/selector pattern for outfit building]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None needed -- clean implementation.

### Completion Notes List

- Task 1: Created migration 026_ootd_posts.sql (3 tables: ootd_posts, ootd_post_squads, ootd_post_items) with indexes and column comments. Created RLS policies in 026_ootd_posts_rls.sql (SELECT/INSERT/UPDATE on all three tables, gated by squad membership).
- Task 2: Created ootd-repository.js with createPost (transactional), getPostById, listPostsForSquad, listPostsForUser (cursor-based pagination), softDeletePost, getPostItemsByPostId, getPostSquadsByPostId. Includes mapPostRow and mapPostItemRow.
- Task 3: Created ootd-service.js with createPost (validates input + verifies squad membership), getPost, listSquadPosts, listFeedPosts, deletePost (author-only). Includes validatePostInput.
- Task 4: Wired ootd routes in main.js. 5 routes: POST/GET feed/GET squad posts/GET post/DELETE post. Route ordering ensures "posts" path is matched before squad :id regex.
- Task 5: Created OotdPost and OotdPostItem models with fromJson factories.
- Task 6: Created OotdService with createPost, listFeedPosts, listSquadPosts, getPost, deletePost.
- Task 7: Added 5 OOTD methods to ApiClient: createOotdPost, listFeedPosts, listSquadPosts, getOotdPost, deleteOotdPost.
- Task 8: Created OotdCreateScreen with photo selection (camera/gallery at 1024px/85%), caption field (150 char limit), item tagging UI (chips + item picker with search/grid), squad selection (checkboxes), post button with upload flow, empty squads guard, Vibrant Soft-UI design, and Semantics labels.
- Task 9: Replaced "Coming Soon" placeholder in SquadDetailScreen with "Post OOTD" button. Added optional ootdService/apiClient to SquadDetailScreen and SquadListScreen. Added "Post OOTD" icon button in SquadListScreen app bar.
- Task 10: Added "ootd_post" to ALLOWED_PURPOSES in upload service. Storage path: users/{uid}/ootd/{uuid}.jpg.
- Task 11: Created 24 unit tests for OOTD service (validatePostInput + all service methods).
- Task 12: Created 13 integration tests for OOTD endpoints (all 5 routes with success/error/auth cases).
- Task 13: Created 11 widget tests for OotdCreateScreen (photo selection, empty squads, semantics, UI elements).
- Task 14: Created 7 model tests for OotdPost and OotdPostItem (fromJson parsing, null handling, defaults).
- Task 15: Added 5 OOTD method tests to api_client_test.dart. Created 5 OotdService tests.
- Task 16: Updated SquadDetailScreen tests: replaced OOTD placeholder test with 3 new tests (Post OOTD button visible, share message shown, semantics label).
- Task 17: Regression passed. flutter analyze: 0 new issues. flutter test: 1322 pass (was 1292). API test: 906 pass (was 869). Upload service unchanged for item_photo. Squad CRUD still works.

### Change Log

- 2026-03-19: Story 9.2 implementation complete. Created OOTD post creation feature: migration 026 (3 tables + RLS), API repository/service/endpoints (5 routes), mobile OotdPost models, OotdService, OotdCreateScreen with photo upload + item tagging + squad selection, upload service ootd_post purpose. 67 new tests (37 API + 30 Flutter). All 2228 total tests pass.

### File List

New files:
- infra/sql/migrations/026_ootd_posts.sql
- infra/sql/policies/026_ootd_posts_rls.sql
- apps/api/src/modules/squads/ootd-repository.js
- apps/api/src/modules/squads/ootd-service.js
- apps/api/test/modules/squads/ootd-service.test.js
- apps/api/test/modules/squads/ootd-endpoint.test.js
- apps/mobile/lib/src/features/squads/models/ootd_post.dart
- apps/mobile/lib/src/features/squads/services/ootd_service.dart
- apps/mobile/lib/src/features/squads/screens/ootd_create_screen.dart
- apps/mobile/test/features/squads/models/ootd_post_test.dart
- apps/mobile/test/features/squads/services/ootd_service_test.dart
- apps/mobile/test/features/squads/screens/ootd_create_screen_test.dart

Modified files:
- apps/api/src/main.js (added ootd imports, ootdRepo/ootdService to createRuntime, ootdService to handleRequest, 5 OOTD routes)
- apps/api/src/modules/uploads/service.js (added "ootd_post" purpose, ootd/ storage path)
- apps/mobile/lib/src/core/networking/api_client.dart (added 5 OOTD methods)
- apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart (replaced OOTD placeholder with Post OOTD button, added ootdService/apiClient params)
- apps/mobile/lib/src/features/squads/screens/squad_list_screen.dart (added Post OOTD icon in app bar, added ootdService/apiClient params)
- apps/mobile/test/core/networking/api_client_test.dart (added 5 OOTD method tests + TestableApiClient OOTD methods)
- apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart (replaced OOTD placeholder test with 3 Post OOTD tests)
