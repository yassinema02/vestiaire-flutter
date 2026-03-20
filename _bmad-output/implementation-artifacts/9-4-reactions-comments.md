# Story 9.4: Reactions & Comments

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to react to and comment on my friends' OOTD posts,
So that I can engage with their style and give feedback.

## Acceptance Criteria

1. Given I am viewing an OOTD post in the feed (OotdPostCard or OotdPostDetailScreen), when I tap the Fire icon, then my reaction is toggled (added if not present, removed if already reacted). The toggle is optimistic: the UI updates the icon fill/color and count immediately, then syncs with the server via `POST /v1/squads/posts/:postId/reactions` (toggle). If the server call fails, the UI reverts. The reaction state is stored in `ootd_reactions` with a UNIQUE constraint on `(post_id, user_id)`. (FR-SOC-09)

2. Given I am viewing the post detail screen (OotdPostDetailScreen), when I tap the comment icon or a "Add comment" input area, then I see a text input field (max 200 chars, with character counter). When I submit a comment, it is saved to `ootd_comments` via `POST /v1/squads/posts/:postId/comments` with `{ text }`. The new comment appears immediately in the comments list below the post. (FR-SOC-10)

3. Given a user comments on my post, when the comment is saved, then I (the post author) receive a push notification with the commenter's name and a preview of the comment text. Notification delivery respects the user's `notification_preferences.social` toggle and quiet hours. (FR-SOC-10)

4. Given I am the post author viewing comments on my post, when I long-press or swipe a comment, then I see a "Delete" option. Tapping it calls `DELETE /v1/squads/posts/:postId/comments/:commentId` and removes the comment from the UI. Given I am the comment author, I can also delete my own comment the same way. Non-authors/non-post-owners cannot delete other users' comments. (FR-SOC-11)

5. Given the `ootd_reactions` and `ootd_comments` tables exist, when the API returns post data (getPost, listFeedPosts, listSquadPosts), then `reactionCount` and `commentCount` reflect actual counts from these tables. The `hasReacted` boolean field indicates whether the current user has reacted to each post. (FR-SOC-09, FR-SOC-10)

6. Given a database migration is needed, when migration 027 runs, then it creates `ootd_reactions` and `ootd_comments` tables in `app_public` schema with RLS policies ensuring: users can see reactions/comments on posts visible to them (via squad membership), users can only create reactions/comments as themselves, users can delete their own reactions/comments, and post authors can delete any comment on their post. (FR-SOC-09, FR-SOC-10, FR-SOC-11)

7. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (906+ API tests, 1367+ Flutter tests) and new tests cover: reaction toggle endpoint, comment CRUD endpoints, reaction/comment service logic (validation, authorization, toggle semantics), OotdPostCard reaction interaction, OotdPostDetailScreen comments UI (list, add, delete), notification trigger on new comment, and updated post query counts.

## Tasks / Subtasks

- [x] Task 1: Database migration -- create ootd_reactions and ootd_comments tables (AC: 1, 2, 6)
  - [x] 1.1: Create `infra/sql/migrations/027_ootd_reactions_comments.sql` that creates:
    - `app_public.ootd_reactions`: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE`, `user_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, UNIQUE constraint on `(post_id, user_id)`.
    - `app_public.ootd_comments`: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE`, `author_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `text VARCHAR(200) NOT NULL`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, `deleted_at TIMESTAMPTZ` (soft delete).
    - Indexes: `idx_ootd_reactions_post_id` on `ootd_reactions(post_id)`, `idx_ootd_reactions_user_id` on `ootd_reactions(user_id)`, `idx_ootd_comments_post_id` on `ootd_comments(post_id)`, `idx_ootd_comments_author_id` on `ootd_comments(author_id)`, `idx_ootd_comments_deleted_at` on `ootd_comments(deleted_at)`.
    - Column comments on all fields.
  - [x] 1.2: Create RLS policies in `infra/sql/policies/027_ootd_reactions_comments_rls.sql`:
    - `ootd_reactions` SELECT: user can see reactions on posts visible to them (via squad membership join).
    - `ootd_reactions` INSERT: authenticated user can insert where `user_id` matches their profile ID.
    - `ootd_reactions` DELETE: user can delete their own reactions only.
    - `ootd_comments` SELECT: user can see comments on posts visible to them (via squad membership join), WHERE `deleted_at IS NULL`.
    - `ootd_comments` INSERT: authenticated user can insert where `author_id` matches their profile ID.
    - `ootd_comments` DELETE: comment author can soft-delete their own comment, OR post author can soft-delete any comment on their post.
    - Enable RLS on both tables.

- [x] Task 2: API -- Add reaction and comment methods to ootd-repository.js (AC: 1, 2, 4, 5)
  - [x] 2.1: In `apps/api/src/modules/squads/ootd-repository.js`, add methods:
    - `toggleReaction(authContext, postId)` -- looks up profile ID, checks if reaction exists via `SELECT` on `ootd_reactions` WHERE `post_id` AND `user_id`. If exists, `DELETE` the row and return `{ reacted: false }`. If not, `INSERT` and return `{ reacted: true }`. Use a transaction.
    - `getReactionCount(postId)` -- `SELECT COUNT(*) FROM ootd_reactions WHERE post_id = $1`. Returns integer.
    - `hasUserReacted(postId, profileId)` -- `SELECT 1 FROM ootd_reactions WHERE post_id = $1 AND user_id = $2 LIMIT 1`. Returns boolean.
    - `createComment(authContext, postId, { text })` -- looks up profile ID, inserts into `ootd_comments` with `post_id`, `author_id`, `text`. Returns the created comment with author profile info.
    - `listComments(authContext, postId, { limit, cursor })` -- paginated comments for a post, ordered by `created_at ASC` (oldest first). Joins author profile info (display_name, photo_url). Filters `deleted_at IS NULL`. Default limit 50.
    - `softDeleteComment(authContext, commentId)` -- sets `deleted_at = NOW()` on `ootd_comments` WHERE `id = commentId`.
    - `getCommentById(commentId)` -- returns comment row with author_id and post_id for authorization checks.
  - [x] 2.2: Update `mapPostRow(row)` to use actual counts: replace hardcoded `reactionCount: 0` and `commentCount: 0` with `row.reaction_count ?? 0` and `row.comment_count ?? 0`. Add `hasReacted: row.has_reacted ?? false`.
  - [x] 2.3: Add `mapCommentRow(row)` mapping: `id`, `postId`, `authorId`, `text`, `createdAt`, `authorDisplayName`, `authorPhotoUrl`.
  - [x] 2.4: Update `getPostById`, `listPostsForSquad`, and `listPostsForUser` SQL queries to include:
    - Subquery for reaction count: `(SELECT COUNT(*) FROM app_public.ootd_reactions WHERE post_id = op.id) AS reaction_count`
    - Subquery for comment count: `(SELECT COUNT(*) FROM app_public.ootd_comments WHERE post_id = op.id AND deleted_at IS NULL) AS comment_count`
    - Subquery for has_reacted: `(SELECT EXISTS(SELECT 1 FROM app_public.ootd_reactions WHERE post_id = op.id AND user_id = $PROFILE_ID_PARAM)) AS has_reacted`
    - This requires resolving the profile ID at the start of each method (already done in `listPostsForUser`, add to others).

- [x] Task 3: API -- Add reaction and comment methods to ootd-service.js (AC: 1, 2, 3, 4, 5)
  - [x] 3.1: In `apps/api/src/modules/squads/ootd-service.js`, add methods:
    - `toggleReaction(authContext, { postId })` -- verifies post exists and is visible to user (call `ootdRepo.getPostById`; 404 if not found). Delegates to `ootdRepo.toggleReaction()`. Returns `{ reacted, reactionCount }` (fetch count after toggle).
    - `createComment(authContext, { postId, text })` -- validates text (required, string, 1-200 chars, trimmed). Verifies post exists and is visible. Creates comment via `ootdRepo.createComment()`. **Triggers notification** to post author (if commenter is not the author): call notification service to send push with `{ title: "{commenterName} commented on your OOTD", body: text.substring(0, 100) }`. Returns created comment.
    - `listComments(authContext, { postId, limit, cursor })` -- verifies post exists and is visible. Delegates to `ootdRepo.listComments()`. Default limit 50, max 100.
    - `deleteComment(authContext, { postId, commentId })` -- loads comment via `ootdRepo.getCommentById()`. Verifies caller is either the comment author OR the post author (load post to check). Throws 403 otherwise. Calls `ootdRepo.softDeleteComment()`.
  - [x] 3.2: Add `validateCommentInput({ text })` -- validates text is a non-empty string, max 200 chars. Throws 400 on failure. Returns `{ text: text.trim() }`.

- [x] Task 4: API -- Wire reaction and comment endpoints in main.js (AC: 1, 2, 4)
  - [x] 4.1: In `apps/api/src/main.js`, add routes (all require `requireAuth`). Place BEFORE the existing `ootdPostIdMatch` regex routes:
    - `POST /v1/squads/posts/:postId/reactions` -- `ootdService.toggleReaction(authContext, { postId })` -> 200. Use regex: `/^\/v1\/squads\/posts\/([^/]+)\/reactions$/`.
    - `POST /v1/squads/posts/:postId/comments` -- `ootdService.createComment(authContext, { postId, text: body.text })` -> 201. Use regex: `/^\/v1\/squads\/posts\/([^/]+)\/comments$/`.
    - `GET /v1/squads/posts/:postId/comments` -- `ootdService.listComments(authContext, { postId, limit, cursor })` -> 200. Same regex.
    - `DELETE /v1/squads/posts/:postId/comments/:commentId` -- `ootdService.deleteComment(authContext, { postId, commentId })` -> 204. Use regex: `/^\/v1\/squads\/posts\/([^/]+)\/comments\/([^/]+)$/`.
  - [x] 4.2: Route ordering: the reaction/comment routes use longer paths (`/posts/:id/reactions`, `/posts/:id/comments`, `/posts/:id/comments/:id`) so they MUST be matched BEFORE the existing `ootdPostIdMatch` (`/posts/:postId`) regex. Insert the new regex declarations and route handlers above the existing `const ootdPostIdMatch = ...` line.

- [x] Task 5: API -- Notification trigger for new comments (AC: 3)
  - [x] 5.1: Check if a notification utility/service already exists in `apps/api/src/modules/notifications/` or as a helper. If it exists, use it. If not, create a lightweight `sendPushNotification(profileId, { title, body })` utility that:
    - Looks up the user's `push_token` and `notification_preferences` from `app_public.profiles`.
    - Checks `notification_preferences.social === true` (skip if false).
    - Checks quiet hours (default 22:00-07:00) -- skip if within quiet hours.
    - Sends via Firebase Cloud Messaging (FCM) using the admin SDK or HTTP API. If FCM is not yet configured in the API, stub the function with a log message and a TODO for Story 9.6. The important thing is the notification check logic and the call site in `createComment`.
  - [x] 5.2: In `ootdService.createComment`, after successfully creating the comment, look up the post author's profile ID. If `authContext.userId !== postAuthorId`, call the notification utility. Do NOT block the comment response on notification delivery -- fire and forget (catch and log errors).

- [x] Task 6: Mobile -- Update OotdPost model to include hasReacted (AC: 1, 5)
  - [x] 6.1: In `apps/mobile/lib/src/features/squads/models/ootd_post.dart`, add `final bool hasReacted;` field. Update constructor to include `this.hasReacted = false`. Update `fromJson` to parse `json["hasReacted"] as bool? ?? false`.

- [x] Task 7: Mobile -- Add reaction and comment methods to OotdService and ApiClient (AC: 1, 2, 4)
  - [x] 7.1: In `apps/mobile/lib/src/features/squads/services/ootd_service.dart`, add:
    - `Future<Map<String, dynamic>> toggleReaction(String postId)` -- calls `_apiClient.toggleOotdReaction(postId)`. Returns `{ reacted: bool, reactionCount: int }`.
    - `Future<OotdComment> createComment(String postId, { required String text })` -- calls `_apiClient.createOotdComment(postId, { "text": text })`. Returns parsed `OotdComment`.
    - `Future<Map<String, dynamic>> listComments(String postId, { int limit = 50, String? cursor })` -- calls `_apiClient.listOotdComments(postId, limit: limit, cursor: cursor)`. Returns `{ comments: List<OotdComment>, nextCursor: String? }`.
    - `Future<void> deleteComment(String postId, String commentId)` -- calls `_apiClient.deleteOotdComment(postId, commentId)`.
  - [x] 7.2: In `apps/mobile/lib/src/core/networking/api_client.dart`, add after the `// --- OOTD Posts ---` block:
    - `Future<Map<String, dynamic>> toggleOotdReaction(String postId)` -- `authenticatedPost("/v1/squads/posts/$postId/reactions")`.
    - `Future<Map<String, dynamic>> createOotdComment(String postId, Map<String, dynamic> body)` -- `authenticatedPost("/v1/squads/posts/$postId/comments", body: body)`.
    - `Future<Map<String, dynamic>> listOotdComments(String postId, { int limit = 50, String? cursor })` -- `authenticatedGet(...)`.
    - `Future<void> deleteOotdComment(String postId, String commentId)` -- `authenticatedDelete("/v1/squads/posts/$postId/comments/$commentId")`.

- [x] Task 8: Mobile -- Create OotdComment model (AC: 2)
  - [x] 8.1: Create `apps/mobile/lib/src/features/squads/models/ootd_comment.dart` with `OotdComment` class: `String id`, `String postId`, `String authorId`, `String text`, `DateTime createdAt`, `String? authorDisplayName`, `String? authorPhotoUrl`. Factory `fromJson(Map<String, dynamic> json)`.

- [x] Task 9: Mobile -- Update OotdPostCard with interactive reaction toggle (AC: 1)
  - [x] 9.1: In `apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart`:
    - Change `onReactionTap` callback type from `VoidCallback?` to accept a reaction toggle handler. Or, add an `OotdService` parameter and handle the toggle internally. Recommended approach: keep the callback but add `bool hasReacted` display state.
    - Add a new constructor parameter: `bool hasReacted` (from `post.hasReacted`).
    - Update the fire icon to show filled/colored when `hasReacted` is true (orange/red fill) vs outline when false.
    - **Optimistic UI**: On tap, immediately toggle the icon state and increment/decrement the count in local state. Then call the reaction callback. If callback signals failure (e.g., via a returned Future), revert the state.
    - Convert from StatefulWidget (it already is) to manage local `_hasReacted` and `_reactionCount` state variables initialized from `widget.post`.
  - [x] 9.2: Update Semantics label to include reaction state: "Reacted" or "Not reacted" + count.

- [x] Task 10: Mobile -- Update OotdPostDetailScreen with comments UI (AC: 2, 4, 5)
  - [x] 10.1: In `apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart`:
    - Add `OotdService` as a required constructor parameter (it may need to be added or made required if currently optional).
    - Below the engagement section, add a "Comments" section.
    - **Comments list**: Load comments via `ootdService.listComments(postId)` on init. Display each comment as a row: author avatar (32px), author name (bold, 14px), comment text (14px), relative timestamp (12px). Use `formatRelativeTime` from `time_utils.dart`.
    - **Delete comment**: Long-press on a comment shows a bottom sheet with "Delete Comment" option. Show this option only if current user is the comment author OR the post author. On confirm, call `ootdService.deleteComment(postId, commentId)` and remove from the local list.
    - **Add comment input**: At the bottom of the screen (or below the comments list), add a `TextField` with `maxLength: 200`, hint "Add a comment...", and a send button (Icons.send). On submit, call `ootdService.createComment(postId, text: text)`. On success, add the new comment to the local list and clear the input. On failure, show error SnackBar.
    - **Empty comments state**: If no comments, show "No comments yet -- be the first!".
    - **Reaction toggle**: Make the fire icon in the engagement section interactive (same optimistic toggle pattern as OotdPostCard). Call `ootdService.toggleReaction(postId)`.
  - [x] 10.2: Add `Semantics` labels on: each comment row ("Comment by {author}: {text}"), delete action, comment input field, send button.

- [x] Task 11: Mobile -- Update OotdFeedScreen to pass reaction/comment handlers (AC: 1)
  - [x] 11.1: In `apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart`:
    - Pass `onReactionTap` callback to each `OotdPostCard` that calls `ootdService.toggleReaction(post.id)` and updates the post in the local `_posts` list with the new reaction state/count.
    - Pass `onCommentTap` callback that navigates to `OotdPostDetailScreen` (scrolled to comments section, or just to the detail screen).
    - Pass `post.hasReacted` to `OotdPostCard`.
  - [x] 11.2: When returning from `OotdPostDetailScreen`, refresh the post's reaction/comment counts in the feed (either by re-fetching the post or by receiving updated counts via navigation result).

- [x] Task 12: Mobile -- Update SquadDetailScreen inline feed for reactions (AC: 1)
  - [x] 12.1: In `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart`:
    - Pass `onReactionTap` and `onCommentTap` callbacks to inline `OotdPostCard` widgets, using the same pattern as OotdFeedScreen.

- [x] Task 13: API -- Unit tests for reaction and comment service methods (AC: 1, 2, 3, 4, 7)
  - [x] 13.1: Add tests to `apps/api/test/modules/squads/ootd-service.test.js` (or create a new `ootd-reactions-comments.test.js`):
    - `toggleReaction` adds reaction when not present, returns `{ reacted: true, reactionCount: 1 }`.
    - `toggleReaction` removes reaction when already present, returns `{ reacted: false, reactionCount: 0 }`.
    - `toggleReaction` returns 404 for non-existent post.
    - `createComment` creates comment with valid text.
    - `createComment` returns 400 for empty text.
    - `createComment` returns 400 for text > 200 chars.
    - `createComment` returns 404 for non-existent post.
    - `createComment` triggers notification to post author (verify call).
    - `createComment` does NOT trigger notification when commenter is the author.
    - `listComments` returns paginated comments ordered by created_at ASC.
    - `listComments` excludes soft-deleted comments.
    - `deleteComment` soft-deletes when caller is comment author.
    - `deleteComment` soft-deletes when caller is post author.
    - `deleteComment` returns 403 when caller is neither comment author nor post author.
    - `deleteComment` returns 404 for non-existent comment.
    - `validateCommentInput` rejects empty string.
    - `validateCommentInput` rejects text > 200 chars.

- [x] Task 14: API -- Integration tests for reaction and comment endpoints (AC: 1, 2, 4, 7)
  - [x] 14.1: Add tests to `apps/api/test/modules/squads/ootd-endpoint.test.js` (or create new file):
    - POST /v1/squads/posts/:postId/reactions returns 200 with `{ reacted: true }` on first call.
    - POST /v1/squads/posts/:postId/reactions returns 200 with `{ reacted: false }` on second call (toggle off).
    - POST /v1/squads/posts/:postId/reactions returns 401 without auth.
    - POST /v1/squads/posts/:postId/reactions returns 404 for invalid post.
    - POST /v1/squads/posts/:postId/comments returns 201 with created comment.
    - POST /v1/squads/posts/:postId/comments returns 400 for empty text.
    - POST /v1/squads/posts/:postId/comments returns 400 for text > 200 chars.
    - POST /v1/squads/posts/:postId/comments returns 401 without auth.
    - GET /v1/squads/posts/:postId/comments returns 200 with paginated comments.
    - DELETE /v1/squads/posts/:postId/comments/:commentId returns 204 for comment author.
    - DELETE /v1/squads/posts/:postId/comments/:commentId returns 204 for post author.
    - DELETE /v1/squads/posts/:postId/comments/:commentId returns 403 for non-author.
    - DELETE /v1/squads/posts/:postId/comments/:commentId returns 401 without auth.
    - GET /v1/squads/posts/feed includes correct reactionCount, commentCount, hasReacted fields.

- [x] Task 15: Mobile -- Widget tests for reaction and comment interactions (AC: 1, 2, 4, 7)
  - [x] 15.1: Update `apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart`:
    - Fire icon shows filled/colored when hasReacted is true.
    - Fire icon shows outline when hasReacted is false.
    - Tapping fire icon triggers onReactionTap callback.
    - Optimistic count update on reaction tap.
  - [x] 15.2: Update `apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart`:
    - Comments list renders when comments exist.
    - Empty comments shows "No comments yet" message.
    - Adding a comment calls createComment and adds to list.
    - Comment input enforces 200 char max.
    - Delete comment shows confirmation for comment author.
    - Delete comment shows confirmation for post author.
    - Delete comment hidden for non-author/non-post-owner.
    - Reaction toggle works on detail screen.
  - [x] 15.3: Create `apps/mobile/test/features/squads/models/ootd_comment_test.dart`:
    - `OotdComment.fromJson` parses all fields correctly.
    - Handles null authorDisplayName and authorPhotoUrl.

- [x] Task 16: Mobile -- Update OotdService and ApiClient tests (AC: 7)
  - [x] 16.1: Update `apps/mobile/test/features/squads/services/ootd_service_test.dart`:
    - `toggleReaction` calls correct API endpoint.
    - `createComment` calls correct API endpoint with text body.
    - `listComments` calls correct API endpoint with pagination params.
    - `deleteComment` calls correct DELETE endpoint.
  - [x] 16.2: Update `apps/mobile/test/core/networking/api_client_test.dart`:
    - `toggleOotdReaction` calls POST /v1/squads/posts/:postId/reactions.
    - `createOotdComment` calls POST /v1/squads/posts/:postId/comments.
    - `listOotdComments` calls GET /v1/squads/posts/:postId/comments.
    - `deleteOotdComment` calls DELETE /v1/squads/posts/:postId/comments/:commentId.

- [x] Task 17: Regression testing (AC: all)
  - [x] 17.1: Run `flutter analyze` -- zero new issues.
  - [x] 17.2: Run `flutter test` -- all existing 1367+ tests plus new tests pass.
  - [x] 17.3: Run `npm --prefix apps/api test` -- all existing 906+ API tests plus new tests pass.
  - [x] 17.4: Verify existing feed, post detail, post card, squad list, and squad detail flows still work.
  - [x] 17.5: Verify post creation flow still works (no regression from updated models/services).

## Dev Notes

- This is Story 9.4 in Epic 9 (Social OOTD Feed / Style Squads). It builds on Story 9.1 (squad infrastructure, done), Story 9.2 (OOTD post creation + API, done), and Story 9.3 (feed display + post detail, done). This story adds interactive reactions (fire emoji toggle) and text comments to OOTD posts.
- **FRs covered:** FR-SOC-09 (fire reaction toggle with count), FR-SOC-10 (text comments, max 200 chars, notification to post author), FR-SOC-11 (delete comments: post author deletes any, users delete their own).
- This story spans **both API and mobile**. New database tables, API endpoints, and mobile UI updates are required.

### Current State of the Codebase

- The `OotdPostCard` widget already has `onReactionTap` and `onCommentTap` VoidCallback parameters (from Story 9.3) but they are currently no-ops.
- `reactionCount` and `commentCount` in `mapPostRow` (ootd-repository.js, line 24-25) are **hardcoded to 0**. This must be updated to use actual subquery counts.
- The `OotdPost` model already has `reactionCount` and `commentCount` fields parsing from JSON. A `hasReacted` field must be added.
- The `OotdPostDetailScreen` shows engagement counts as static text. It needs to become interactive with a comments list and input.
- `OotdService` on mobile already has CRUD methods for posts. Reaction and comment methods must be added.
- `ApiClient` already has OOTD post methods. Reaction and comment methods must be added alongside.

### Database Schema Design

```sql
-- ootd_reactions (toggle-based, one per user per post)
CREATE TABLE app_public.ootd_reactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

-- ootd_comments (text comments with soft delete)
CREATE TABLE app_public.ootd_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES app_public.ootd_posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  text VARCHAR(200) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);
```

### API Endpoint Summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /v1/squads/posts/:postId/reactions | Yes | Toggle fire reaction |
| POST | /v1/squads/posts/:postId/comments | Yes | Create comment |
| GET | /v1/squads/posts/:postId/comments | Yes | List comments (paginated) |
| DELETE | /v1/squads/posts/:postId/comments/:commentId | Yes | Delete comment |

### Route Ordering in main.js

The new routes have paths like `/v1/squads/posts/:postId/reactions` and `/v1/squads/posts/:postId/comments/:commentId` which are LONGER than the existing `/v1/squads/posts/:postId` pattern. They MUST be matched BEFORE the existing `ootdPostIdMatch` regex. Insert the new regex declarations and handlers above the line `const ootdPostIdMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)$/);` in main.js.

```javascript
// Reaction and comment routes (BEFORE ootdPostIdMatch)
const ootdReactionMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)\/reactions$/);
const ootdCommentMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)\/comments$/);
const ootdCommentIdMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)\/comments\/([^/]+)$/);

// Handle DELETE comment BEFORE general comment routes (specific before general)
if (req.method === "DELETE" && ootdCommentIdMatch) { ... }
if (req.method === "POST" && ootdReactionMatch) { ... }
if (req.method === "POST" && ootdCommentMatch) { ... }
if (req.method === "GET" && ootdCommentMatch) { ... }

// THEN existing post routes
const ootdPostIdMatch = url.pathname.match(/^\/v1\/squads\/posts\/([^/]+)$/);
```

### Optimistic UI for Reactions

Architecture.md explicitly allows optimistic UI for reactions: "Optimistic UI is allowed for wear logging, badge/streak feedback, reactions, and save actions." Implementation pattern:

```dart
// In OotdPostCard state
bool _hasReacted;
int _reactionCount;

void _onReactionTap() async {
  // Optimistic update
  setState(() {
    _hasReacted = !_hasReacted;
    _reactionCount += _hasReacted ? 1 : -1;
  });

  try {
    final result = await widget.onReactionTap?.call();
    // Optionally sync with server count
  } catch (e) {
    // Revert on failure
    if (mounted) {
      setState(() {
        _hasReacted = !_hasReacted;
        _reactionCount += _hasReacted ? 1 : -1;
      });
    }
  }
}
```

### Notification Pattern for Comments

The notification on new comment should:
1. Look up post author's profile ID from the post.
2. Skip if commenter IS the post author (no self-notification).
3. Check `notification_preferences.social` is true.
4. Check quiet hours (22:00-07:00 default).
5. Send FCM push if all checks pass.
6. Fire-and-forget: do NOT await or block the comment API response.

If FCM is not yet wired in the API (Story 9.6 is "Social Notification Preferences"), create a stub utility that logs the notification intent and returns. The important logic is the preference/quiet-hours check and the call site. Story 9.6 will implement full notification delivery.

### Project Structure Notes

- New API files: NONE (all changes in existing files: `ootd-repository.js`, `ootd-service.js`, `main.js`)
- New mobile files:
  - `apps/mobile/lib/src/features/squads/models/ootd_comment.dart`
  - `apps/mobile/test/features/squads/models/ootd_comment_test.dart`
- Modified API files:
  - `apps/api/src/modules/squads/ootd-repository.js` (add reaction/comment methods, update mapPostRow, update SQL queries)
  - `apps/api/src/modules/squads/ootd-service.js` (add reaction/comment service methods, validation)
  - `apps/api/src/main.js` (add 4 new routes)
  - Possibly `apps/api/src/modules/notifications/` (stub notification utility if not exists)
- New migration files:
  - `infra/sql/migrations/027_ootd_reactions_comments.sql`
  - `infra/sql/policies/027_ootd_reactions_comments_rls.sql`
- Modified mobile files:
  - `apps/mobile/lib/src/features/squads/models/ootd_post.dart` (add `hasReacted` field)
  - `apps/mobile/lib/src/features/squads/services/ootd_service.dart` (add reaction/comment methods)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add reaction/comment API methods)
  - `apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart` (interactive reaction toggle with optimistic UI)
  - `apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart` (comments list, add/delete comments, interactive reaction)
  - `apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart` (pass reaction/comment handlers to cards)
  - `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart` (pass reaction/comment handlers to inline cards)
- Modified test files:
  - `apps/api/test/modules/squads/ootd-service.test.js` or new `ootd-reactions-comments.test.js`
  - `apps/api/test/modules/squads/ootd-endpoint.test.js` (add reaction/comment endpoint tests)
  - `apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart` (reaction interaction)
  - `apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart` (comments UI)
  - `apps/mobile/test/features/squads/services/ootd_service_test.dart` (reaction/comment methods)
  - `apps/mobile/test/core/networking/api_client_test.dart` (reaction/comment API methods)

### Alignment with Unified Project Structure

- Reactions/comments are part of the squads feature -- all code stays in `apps/api/src/modules/squads/` and `apps/mobile/lib/src/features/squads/`.
- New model `OotdComment` goes in `apps/mobile/lib/src/features/squads/models/` alongside existing `OotdPost` and `Squad` models.
- No new API module directories needed. Extend existing `ootd-repository.js` and `ootd-service.js`.
- Test files mirror source structure exactly.

### Technical Requirements

- **PostgreSQL 16** with RLS. Both new tables require RLS policies. Reactions use UNIQUE constraint for idempotent toggle. Comments use soft delete for audit trail.
- **Flutter / Dart**: No new dependencies. Uses existing Material widgets (TextField, InkWell, ListView, CircleAvatar, BottomSheet). Uses existing `formatRelativeTime` from `time_utils.dart`.
- **No new Flutter dependencies**. All UI uses existing widgets and patterns.
- **No new API dependencies**. Uses existing pool, auth middleware, error handling patterns.
- **Optimistic UI** for reactions ONLY. Comments use standard async pattern (show loading, then update on success).

### Architecture Compliance

- **Optimistic UI for reactions**: Explicitly allowed by architecture.md.
- **RLS on all user-facing tables**: Both `ootd_reactions` and `ootd_comments` require RLS policies.
- **Squad membership gates social operations**: Reaction/comment endpoints must verify the user can see the post (which implicitly checks squad membership via existing `getPostById` RLS).
- **Server-side enforcement**: Comment text validation (200 char max), authorization checks (delete permissions), and notification preference checks all happen server-side.
- **Accessibility**: Semantics labels on all interactive elements, 44x44 touch targets for reaction/comment actions.
- **Soft delete for comments**: Preserves data integrity. Hard delete for reactions (toggle semantics, no audit needed).

### Library / Framework Requirements

- **API**: No new dependencies. Extends existing Node.js modules with same patterns.
- **Mobile**: No new dependencies. All UI uses existing Flutter Material widgets and services.

### File Structure Requirements

- New model in `apps/mobile/lib/src/features/squads/models/ootd_comment.dart`.
- All other changes are modifications to existing files.
- Migration in `infra/sql/migrations/027_ootd_reactions_comments.sql`.
- RLS policies in `infra/sql/policies/027_ootd_reactions_comments_rls.sql`.

### Testing Requirements

- **API tests** follow existing patterns from `ootd-service.test.js` and `ootd-endpoint.test.js`. Mock the ootd repository in service tests.
- **Flutter widget tests** follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services.
- **Mock `OotdService`** in widget tests for reaction toggle and comment operations.
- **Target**: All existing tests pass (906 API, 1367 Flutter) plus new tests for reactions, comments, and notification trigger.

### Previous Story Intelligence

- **Story 9.3** (done): Created `OotdPostCard` (StatefulWidget with `onReactionTap`/`onCommentTap` callbacks, currently no-ops), `OotdFeedScreen` (with cursor-based pagination, squad filter chips, pull-to-refresh), `OotdPostDetailScreen` (full post detail with engagement counts display-only), `time_utils.dart` shared utility. 1367 Flutter tests, 906 API tests. Key patterns: `mounted` guard, factory DI, Semantics labels, Vibrant Soft-UI design.
- **Story 9.2** (done): Created OOTD post infrastructure: `ootd_posts`, `ootd_post_squads`, `ootd_post_items` tables (migration 026). `ootd-repository.js` with `mapPostRow` (hardcoded `reactionCount: 0`, `commentCount: 0`), `ootd-service.js` with post CRUD. `OotdPost` model with `reactionCount`/`commentCount` fields. `OotdService` and `ApiClient` OOTD methods. `ootd_post` purpose for signed URL uploads.
- **Story 9.1** (done): Squad infrastructure: `style_squads`, `squad_memberships` tables (migration 025). `squad-repository.js` with `getProfileIdForUser`, `getMembership`. 7 squad API routes in main.js. Bottom nav restructured with Social tab.
- **Story 1.6** (done): Established `push_token` and `notification_preferences` JSONB on `profiles` table. `notification_preferences` includes `"social": true` default. This is used for comment notification preference check.

### Key Anti-Patterns to Avoid

- DO NOT create separate reaction count columns on `ootd_posts`. Use subquery counts from `ootd_reactions` and `ootd_comments` tables for accuracy.
- DO NOT use INSERT/DELETE pair for reaction toggle. Use a single transaction that checks existence and toggles atomically.
- DO NOT block the comment API response on notification delivery. Fire-and-forget with error logging.
- DO NOT allow direct database access from Flutter. All operations go through the Cloud Run API via OotdService.
- DO NOT forget to update the existing `mapPostRow` to use actual counts instead of hardcoded 0.
- DO NOT forget route ordering: reaction/comment routes MUST be matched before the existing `ootdPostIdMatch` regex.
- DO NOT implement real-time comment updates (WebSocket). Use local state management -- add new comments to the list on creation, remove on deletion.
- DO NOT add the `hasReacted` field without default value. The API must compute it per-request using the authenticated user's profile ID.
- DO NOT skip the `mounted` guard before `setState` in async callbacks (optimistic UI revert).
- DO NOT use Supabase client or direct database access from Flutter.
- DO NOT create a separate notification module/service for this story if one does not exist yet. A stub utility is sufficient; Story 9.6 implements full notification infrastructure.
- DO NOT implement comment editing (not in requirements).
- DO NOT implement reaction types (only fire emoji per FR-SOC-09).
- DO NOT implement threaded/nested comments (flat list only per requirements).

### Out of Scope

- **"Steal This Look" matcher** (Story 9.5)
- **Full social notification delivery infrastructure** (Story 9.6) -- only stub/basic FCM push here
- **Comment editing** (not in requirements)
- **Multiple reaction types** (only fire emoji per FR-SOC-09)
- **Threaded/nested comments** (flat list only)
- **Real-time updates** (WebSocket/SSE) -- use local state management
- **Comment pagination on mobile** (50 comments per page is sufficient for squad-sized groups of max 20 members)
- **Reaction animation** (nice-to-have, not required)
- **Content moderation** (deferred per PRD)

### References

- [Source: epics.md - Story 9.4: Reactions & Comments]
- [Source: epics.md - Epic 9: Social OOTD Feed (Style Squads), FR-SOC-09, FR-SOC-10, FR-SOC-11]
- [Source: prd.md - FR-SOC-09: Users shall react to posts with a fire emoji toggle with reaction count display]
- [Source: prd.md - FR-SOC-10: Users shall comment on posts (text only, max 200 chars) with notification to post author]
- [Source: prd.md - FR-SOC-11: Post authors shall delete any comment on their post; users shall delete their own comments]
- [Source: architecture.md - Important tables: ootd_comments, ootd_reactions]
- [Source: architecture.md - Optimistic UI allowed for reactions and save actions]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - Squad membership and role checks gate social operations]
- [Source: architecture.md - Notification scheduling and preference enforcement]
- [Source: architecture.md - Epic 9 Social OOTD -> mobile/features/squads, api/modules/squads, api/modules/notifications]
- [Source: 9-3-social-feed-filtering.md - OotdPostCard with onReactionTap/onCommentTap callbacks, OotdFeedScreen, OotdPostDetailScreen, 1367 Flutter tests, 906 API tests]
- [Source: 9-2-ootd-post-creation.md - ootd-repository.js mapPostRow hardcoded counts, ootd-service.js, OotdPost model, OotdService, migration 026]
- [Source: 9-1-squad-creation-management.md - squad-repository.js getProfileIdForUser, getMembership, migration 025, 7 squad routes in main.js]
- [Source: 1-6-push-notification-permissions-preferences.md - notification_preferences JSONB with "social": true default on profiles]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

- Fixed 2 Flutter test failures: fire icon off-screen in detail screen test (added scroll), pending timer in optimistic count test (removed unnecessary delay).

### Completion Notes List

- Task 1: Created migration 027 with ootd_reactions (UNIQUE on post_id+user_id) and ootd_comments (soft delete) tables, plus indexes and RLS policies for both.
- Tasks 2-4: Added 7 repository methods (toggleReaction, getReactionCount, hasUserReacted, createComment, listComments, softDeleteComment, getCommentById), updated mapPostRow with real counts, added mapCommentRow. Added 4 service methods with validation and authorization. Wired 4 new routes in main.js before ootdPostIdMatch.
- Task 5: Implemented stub notification utility with social preference check, quiet hours check, and fire-and-forget call in createComment. Full FCM delivery deferred to Story 9.6.
- Tasks 6-8: Added hasReacted to OotdPost model, created OotdComment model, added reaction/comment methods to OotdService and ApiClient.
- Tasks 9-12: Updated OotdPostCard with optimistic reaction toggle (red/indigo icon coloring), updated OotdPostDetailScreen with comments list, add/delete comment UI, interactive reaction toggle, comment input (200 char max). Updated OotdFeedScreen and SquadDetailScreen to pass reaction/comment handlers.
- Tasks 13-16: Added 17 API service tests, 15 API endpoint tests, 4 OotdPostCard interaction tests, 7 detail screen comment/reaction tests, 3 OotdComment model tests, 4 OotdService method tests, 4 ApiClient method tests.
- Task 17: All regressions pass. 939 API tests (906 baseline + 33 new), 1387 Flutter tests (1367 baseline + 20 new). Zero new analyzer issues.

### Change Log

- 2026-03-19: Implemented Story 9.4 - Reactions & Comments (FR-SOC-09, FR-SOC-10, FR-SOC-11)

### File List

New files:
- infra/sql/migrations/027_ootd_reactions_comments.sql
- infra/sql/policies/027_ootd_reactions_comments_rls.sql
- apps/mobile/lib/src/features/squads/models/ootd_comment.dart
- apps/mobile/test/features/squads/models/ootd_comment_test.dart

Modified files:
- apps/api/src/modules/squads/ootd-repository.js
- apps/api/src/modules/squads/ootd-service.js
- apps/api/src/main.js
- apps/api/test/modules/squads/ootd-service.test.js
- apps/api/test/modules/squads/ootd-endpoint.test.js
- apps/mobile/lib/src/features/squads/models/ootd_post.dart
- apps/mobile/lib/src/features/squads/services/ootd_service.dart
- apps/mobile/lib/src/core/networking/api_client.dart
- apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart
- apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart
- apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart
- apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart
- apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart
- apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart
- apps/mobile/test/features/squads/services/ootd_service_test.dart
- apps/mobile/test/core/networking/api_client_test.dart
