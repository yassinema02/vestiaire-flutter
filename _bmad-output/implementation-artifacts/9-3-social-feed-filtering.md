# Story 9.3: Social Feed & Filtering

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to scroll through a feed of my friends' outfits and filter by squad,
So that I can see their daily styles and stay inspired.

## Acceptance Criteria

1. Given I belong to squads with active OOTD posts, when I open the Social tab (SquadListScreen), then I see a "Feed" entry point (tab, button, or top-level section) that navigates to a full-screen `OotdFeedScreen` showing a chronological (newest-first) feed of OOTD posts from ALL my joined squads. Each post card shows: author avatar + display name, post photo (full-width, aspect-ratio preserved), optional caption, tagged item chips (thumbnails + names), relative timestamp ("2h ago"), and reaction count + comment count (tappable placeholders -- actual interaction comes in Story 9.4). (FR-SOC-07)

2. Given I am viewing the feed, when I tap a squad filter dropdown/chip bar at the top, then I can select "All Squads" (default) or a specific squad name. Selecting a specific squad re-fetches the feed with `GET /v1/squads/:id/posts` showing only posts shared to that squad. Selecting "All Squads" re-fetches with `GET /v1/squads/posts/feed`. The current filter selection is visually indicated (highlighted chip or dropdown value). (FR-SOC-08)

3. Given I am viewing the feed, when I scroll to the bottom of the loaded posts, then the app automatically loads the next page using cursor-based pagination (cursor = last post's created_at or ID). A loading spinner appears at the bottom while fetching. When no more posts exist, the spinner is replaced by an "end of feed" indicator. The initial page loads within 2 seconds (NFR-PERF-06). Default page size: 20, max: 50. (FR-SOC-07, NFR-PERF-06)

4. Given I belong to squads but no posts exist yet, when I open the feed, then I see an empty state with an illustration/icon, text "No posts yet -- be the first to share your OOTD!", and a "Post OOTD" CTA button navigating to `OotdCreateScreen`. (FR-SOC-07)

5. Given I am viewing a post in the feed, when I tap the post photo or a "View" action, then I navigate to a `OotdPostDetailScreen` showing the full post with: larger photo, author info, caption, all tagged items (tappable, navigating to item detail if it's the user's own item), reaction/comment counts, and a "Delete" option if I am the post author (calls `DELETE /v1/squads/posts/:postId`). (FR-SOC-07)

6. Given I am viewing the squad detail screen (SquadDetailScreen), when the screen loads, then the existing "Post OOTD" button (from Story 9.2) is supplemented by an inline feed of that squad's posts below the members section, using the same feed card component as the main feed but pre-filtered to that squad (`GET /v1/squads/:id/posts`). This replaces any remaining placeholder content. (FR-SOC-07, FR-SOC-08)

7. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (906+ API tests, 1322+ Flutter tests) and new tests cover: OotdFeedScreen widget (feed rendering, pagination, empty state, squad filter, pull-to-refresh), OotdPostDetailScreen widget (post detail, delete own post, tagged items), OotdPostCard widget (card rendering, author info, caption, tagged items, timestamps), SquadDetailScreen feed integration, and any new API-side changes.

## Tasks / Subtasks

- [x] Task 1: Mobile -- Create OotdPostCard reusable widget (AC: 1, 6)
  - [x] 1.1: Create `apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart` with `OotdPostCard` StatelessWidget. Constructor: `{ required OotdPost post, VoidCallback? onTap, VoidCallback? onReactionTap, VoidCallback? onCommentTap, super.key }`.
  - [x] 1.2: Card layout (top to bottom):
    - **Author row**: `CircleAvatar` (author photo or initials fallback, 36px), display name (bold, 14px), relative timestamp (12px, secondary color). Use the same relative time formatting from `SquadListScreen` (e.g., "2h ago", "Yesterday", "Mar 15").
    - **Photo**: Full-width `Image.network(post.photoUrl)` with aspect ratio preserved via `AspectRatio` or `FittedBox`. Use `fit: BoxFit.cover` with max height constraint (400px) to prevent excessively tall images. Show a shimmer/placeholder while loading.
    - **Caption** (if present): Text below the photo, 14px, max 3 lines with "See more" expansion.
    - **Tagged items**: Horizontally scrollable `ListView` of chips. Each chip shows item thumbnail (20x20 `CircleAvatar`) and item name (12px). If no tagged items, hide this section.
    - **Engagement row**: Row with fire icon + reaction count (left) and comment icon + comment count (right). Both tappable via callbacks. These are display-only in this story; interaction logic comes in Story 9.4.
  - [x] 1.3: Follow Vibrant Soft-UI design: `Card` with 16px border radius, subtle elevation (2px), white background, 12px padding. `#1F2937` primary text, `#6B7280` secondary text, `#4F46E5` accent for interactive elements.
  - [x] 1.4: Add `Semantics` labels: post card ("Post by {authorName}"), author row, photo ("OOTD photo by {authorName}"), each tagged item chip, reaction button ("Reactions: {count}"), comment button ("Comments: {count}").

- [x] Task 2: Mobile -- Create OotdFeedScreen with pagination and filtering (AC: 1, 2, 3, 4)
  - [x] 2.1: Create `apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart` with `OotdFeedScreen` StatefulWidget. Constructor: `{ required OotdService ootdService, required SquadService squadService, String? initialSquadFilter, super.key }`.
  - [x] 2.2: **State variables**: `List<OotdPost> _posts`, `bool _isLoading`, `bool _isLoadingMore`, `bool _hasMore`, `String? _cursor`, `String? _selectedSquadId` (null = all squads), `List<Squad> _squads` (for filter dropdown).
  - [x] 2.3: **initState**: Load squads via `squadService.listMySquads()` (for filter options) and initial posts via `_loadPosts()` in parallel. If `initialSquadFilter` is provided, set `_selectedSquadId`.
  - [x] 2.4: **_loadPosts({bool refresh = false})**: If `refresh`, reset `_cursor` and `_posts`. Call `ootdService.listSquadPosts(_selectedSquadId, limit: 20, cursor: _cursor)` if a specific squad is selected, or `ootdService.listFeedPosts(limit: 20, cursor: _cursor)` for all squads. Parse response `{ posts, nextCursor }`. Append posts to `_posts`, set `_cursor = nextCursor`, set `_hasMore = nextCursor != null`. Guard with `mounted` before `setState`.
  - [x] 2.5: **Feed body**: `RefreshIndicator` wrapping a `ListView.builder` with `itemCount: _posts.length + (_hasMore ? 1 : 1)`. For each post, render `OotdPostCard`. Last item: if `_hasMore`, show `CircularProgressIndicator` and trigger `_loadPosts()` if not already loading (infinite scroll). If `!_hasMore && _posts.isNotEmpty`, show "You're all caught up!" text. Use `ScrollController` and listen for scroll position near bottom to trigger pagination.
  - [x] 2.6: **Squad filter UI**: Below the app bar, a horizontally scrollable row of `FilterChip` or `ChoiceChip` widgets. First chip: "All Squads" (selected when `_selectedSquadId == null`). Subsequent chips: one per squad with squad name. Tapping a chip updates `_selectedSquadId` and calls `_loadPosts(refresh: true)`.
  - [x] 2.7: **Empty state**: When `_posts.isEmpty && !_isLoading`, show centered content with `Icons.photo_camera_outlined` (64px, secondary), "No posts yet", "Be the first to share your OOTD!", and "Post OOTD" `ElevatedButton` navigating to `OotdCreateScreen`.
  - [x] 2.8: **App bar**: Title "Feed". Back button if pushed onto stack, or integrate as a tab/section. Optional "Post OOTD" action button (Icons.add_a_photo) in app bar.
  - [x] 2.9: **Pull-to-refresh**: `RefreshIndicator.onRefresh` calls `_loadPosts(refresh: true)`.
  - [x] 2.10: **Error handling**: On load failure, show SnackBar with error message. If initial load fails, show retry button in body area.
  - [x] 2.11: Add `Semantics` labels: feed list ("OOTD Feed"), each filter chip ("Filter: {squadName}"), empty state elements, loading indicators.

- [x] Task 3: Mobile -- Create OotdPostDetailScreen (AC: 5)
  - [x] 3.1: Create `apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart` with `OotdPostDetailScreen` StatefulWidget. Constructor: `{ required String postId, required OotdService ootdService, super.key }`.
  - [x] 3.2: On `initState`, load post via `ootdService.getPost(postId)`.
  - [x] 3.3: **Layout**: `SingleChildScrollView` with:
    - **Author header**: Avatar (48px), display name (16px bold), relative timestamp (14px secondary).
    - **Photo**: Full-width `Image.network` with aspect ratio preserved. Tappable for full-screen zoom (optional, use `InteractiveViewer`).
    - **Caption**: Full text (no truncation), 16px.
    - **Tagged items section**: "Tagged Items" header. Vertical list of item rows: item photo (40x40), item name, item category. Tappable -- navigate to item detail if the item belongs to the current user (check `post.authorId == currentUserId`).
    - **Engagement section**: Fire reaction count and comment count. Display only in this story; Story 9.4 adds interaction.
    - **Delete action**: If current user is the post author, show "Delete Post" button (destructive, red) in app bar overflow menu or at bottom. Confirmation dialog. On confirm, call `ootdService.deletePost(postId)`. Navigate back on success with SnackBar "Post deleted".
  - [x] 3.4: **Loading state**: `CircularProgressIndicator` while fetching.
  - [x] 3.5: **Error state**: If post not found (404), show "Post not found" message with back button.
  - [x] 3.6: Add `Semantics` labels: post detail view, author info, photo, each tagged item, delete button, engagement counts.

- [x] Task 4: Mobile -- Integrate feed into SquadDetailScreen (AC: 6)
  - [x] 4.1: In `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart`, below the members section:
    - Add a "Recent Posts" section header with a "See All" link.
    - Load the squad's posts via `ootdService.listSquadPosts(squadId, limit: 5)` on init (alongside existing squad/member loads).
    - Display up to 5 recent posts using `OotdPostCard` widgets.
    - "See All" navigates to `OotdFeedScreen` with `initialSquadFilter: squadId`.
  - [x] 4.2: If no posts exist for the squad, show a subtle inline message: "No posts yet -- share your first OOTD!" with the existing "Post OOTD" button.
  - [x] 4.3: Tapping a post card navigates to `OotdPostDetailScreen`.
  - [x] 4.4: Ensure `OotdService` is passed through to `SquadDetailScreen` (it was already added in Story 9.2 as an optional parameter -- make it required if needed, or use the existing optional flow).

- [x] Task 5: Mobile -- Add Feed entry point to SquadListScreen / Social tab (AC: 1)
  - [x] 5.1: In `apps/mobile/lib/src/features/squads/screens/squad_list_screen.dart`, add a "Feed" button or tab at the top of the screen. Options (choose one that fits best with existing design):
    - **Option A (Preferred)**: Add a segmented control / `TabBar` at the top: "My Squads" | "Feed". "My Squads" shows the existing squad list. "Feed" shows `OotdFeedScreen` inline or navigates to it.
    - **Option B**: Add a "Feed" icon button in the app bar (e.g., `Icons.dynamic_feed`) that navigates to `OotdFeedScreen`.
  - [x] 5.2: If using Option A with TabBar: use `DefaultTabController` with 2 tabs. "My Squads" tab renders the existing squad list body. "Feed" tab renders `OotdFeedScreen` with `initialSquadFilter: null`.
  - [x] 5.3: Pass `OotdService` and `SquadService` to `OotdFeedScreen`. These services should already be available in `SquadListScreen` from Story 9.2.

- [x] Task 6: Mobile -- Relative time formatting utility (AC: 1)
  - [x] 6.1: Check if a relative time formatting utility already exists (used in `SquadListScreen` for last activity). If yes, extract it to a shared utility file `apps/mobile/lib/src/core/utils/time_utils.dart` if not already shared. If it's already shared, reuse it.
  - [x] 6.2: The utility should handle: "Just now" (< 1 min), "Xm ago" (< 1 hour), "Xh ago" (< 24 hours), "Yesterday", date string for older. Use this in `OotdPostCard` and `OotdPostDetailScreen`.

- [x] Task 7: Mobile -- Widget tests for OotdPostCard (AC: 1, 7)
  - [x] 7.1: Create `apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart`:
    - Renders author name and avatar.
    - Renders post photo.
    - Renders caption when present.
    - Hides caption section when caption is null.
    - Renders tagged item chips when items present.
    - Hides tagged items section when no items.
    - Renders reaction count and comment count.
    - Renders relative timestamp.
    - Tapping card triggers onTap callback.
    - Semantics labels present on card, photo, author, items, engagement.

- [x] Task 8: Mobile -- Widget tests for OotdFeedScreen (AC: 1, 2, 3, 4, 7)
  - [x] 8.1: Create `apps/mobile/test/features/squads/screens/ootd_feed_screen_test.dart`:
    - Renders loading spinner on initial load.
    - Renders feed with post cards when posts available.
    - Renders empty state when no posts.
    - Empty state "Post OOTD" button is tappable.
    - Squad filter chips render with "All Squads" and squad names.
    - Tapping a squad filter chip reloads feed.
    - Tapping "All Squads" chip reloads unfiltered feed.
    - Pull-to-refresh triggers reload.
    - Scroll to bottom triggers pagination (loading more indicator appears).
    - "You're all caught up" message when no more posts.
    - Error state shows retry option.
    - Semantics labels on feed, filters, empty state.

- [x] Task 9: Mobile -- Widget tests for OotdPostDetailScreen (AC: 5, 7)
  - [x] 9.1: Create `apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart`:
    - Renders loading spinner while fetching post.
    - Renders author info, photo, caption, tagged items.
    - Delete button visible when current user is author.
    - Delete button hidden when current user is NOT author.
    - Delete triggers confirmation dialog, then API call.
    - Post not found shows error message.
    - Tagged items are displayed with name and photo.
    - Semantics labels on all elements.

- [x] Task 10: Mobile -- Update SquadDetailScreen tests for inline feed (AC: 6, 7)
  - [x] 10.1: Update `apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart`:
    - Recent posts section renders when posts exist.
    - Post cards display in squad detail.
    - "See All" link navigates to OotdFeedScreen.
    - Empty posts shows "No posts yet" inline message.
    - Tapping a post card navigates to OotdPostDetailScreen.

- [x] Task 11: Mobile -- Update SquadListScreen tests for feed entry point (AC: 1, 7)
  - [x] 11.1: Update `apps/mobile/test/features/squads/screens/squad_list_screen_test.dart`:
    - Feed tab/button is visible.
    - Tapping feed navigates to or shows OotdFeedScreen.
    - If using TabBar: both "My Squads" and "Feed" tabs render correctly.

- [x] Task 12: Regression testing (AC: all)
  - [x] 12.1: Run `flutter analyze` -- zero new issues.
  - [x] 12.2: Run `flutter test` -- all existing 1322+ tests plus new tests pass.
  - [x] 12.3: Run `npm --prefix apps/api test` -- all existing 906+ API tests pass (no API changes expected in this story).
  - [x] 12.4: Verify existing squad list, squad detail, and OOTD creation flows still work.
  - [x] 12.5: Verify existing navigation (5 tabs: Home, Wardrobe, Social, Outfits, Profile) still works.

## Dev Notes

- This is Story 9.3 in Epic 9 (Social OOTD Feed / Style Squads). It builds on Story 9.1 (squad infrastructure, done) and Story 9.2 (OOTD post creation, done) to add the feed display, squad filtering, post detail view, and integration into existing screens. This is a **mobile-only story** -- all API endpoints needed already exist from Story 9.2.
- The API endpoints for feed and posts are ALREADY IMPLEMENTED in Story 9.2:
  - `GET /v1/squads/posts/feed` -- paginated feed across all squads (cursor-based)
  - `GET /v1/squads/:id/posts` -- paginated posts for a specific squad (cursor-based)
  - `GET /v1/squads/posts/:postId` -- single post detail
  - `DELETE /v1/squads/posts/:postId` -- soft delete own post
  - The mobile `OotdService` already has `listFeedPosts()`, `listSquadPosts()`, `getPost()`, `deletePost()` methods.
  - The mobile `ApiClient` already has `listFeedPosts()`, `listSquadPosts()`, `getOotdPost()`, `deleteOotdPost()` methods.
- No new database migrations. No new API endpoints. No new API service methods. This is purely a Flutter UI story consuming existing APIs.
- The `OotdPost` model already exists (`apps/mobile/lib/src/features/squads/models/ootd_post.dart`) with all needed fields: `id`, `authorId`, `photoUrl`, `caption`, `createdAt`, `authorDisplayName`, `authorPhotoUrl`, `taggedItems`, `squadIds`, `reactionCount`, `commentCount`.
- `reactionCount` and `commentCount` will return 0 from the API until Story 9.4 creates the `ootd_reactions` and `ootd_comments` tables. The feed UI should display these counts (showing 0) and have tappable areas that do nothing yet (callbacks exist but are no-ops until 9.4).
- Performance target NFR-PERF-06: OOTD feed load time < 2 seconds. The API already supports cursor-based pagination. On the mobile side, ensure the initial page request is fast by: (a) not loading images eagerly (use `Image.network` lazy loading), (b) keeping default page size at 20, (c) showing shimmer placeholders while images load.
- Photo display: OOTD photos are stored at 1024px max width (from Story 9.2). Use `Image.network` with `cacheWidth` to avoid decoding at full resolution on smaller screens. Consider `CachedNetworkImage` if `cached_network_image` is in pubspec.yaml, otherwise standard `Image.network` is fine.

### Cursor-Based Pagination Pattern

The API returns:
```json
{
  "posts": [...],
  "nextCursor": "2026-03-18T10:30:00Z" // or null if no more posts
}
```

On the mobile side:
```dart
final result = await ootdService.listFeedPosts(limit: 20, cursor: _cursor);
final newPosts = (result['posts'] as List).map((p) => OotdPost.fromJson(p)).toList();
final nextCursor = result['nextCursor'] as String?;
```

### Infinite Scroll Pattern

Use a `ScrollController` with a listener:
```dart
_scrollController.addListener(() {
  if (_scrollController.position.pixels >=
      _scrollController.position.maxScrollExtent - 200) {
    if (!_isLoadingMore && _hasMore) {
      _loadPosts(); // appends to existing list
    }
  }
});
```

### Project Structure Notes

- New mobile files:
  - `apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart`
  - `apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart`
  - `apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart`
  - `apps/mobile/lib/src/core/utils/time_utils.dart` (if not already existing)
  - `apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart`
  - `apps/mobile/test/features/squads/screens/ootd_feed_screen_test.dart`
  - `apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart`
- Modified mobile files:
  - `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart` (add inline feed below members)
  - `apps/mobile/lib/src/features/squads/screens/squad_list_screen.dart` (add Feed entry point / TabBar)
  - `apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart` (add feed integration tests)
  - `apps/mobile/test/features/squads/screens/squad_list_screen_test.dart` (add feed entry point tests)
- NO new API files or modified API files.
- NO new migration files.

### Alignment with Unified Project Structure

- All new widgets go in `apps/mobile/lib/src/features/squads/widgets/` -- a new `widgets/` subdirectory alongside existing `models/`, `services/`, `screens/`.
- Screens follow the same pattern as `OotdCreateScreen` from Story 9.2: StatefulWidget with service injection via constructor.
- Test files mirror source structure: `test/features/squads/widgets/`, `test/features/squads/screens/`.
- Shared utility goes in `apps/mobile/lib/src/core/utils/` following existing core utility patterns.

### Technical Requirements

- **Flutter / Dart**: No new dependencies. Uses existing `Image.network`, `ListView.builder`, `RefreshIndicator`, `ScrollController`, `FilterChip`/`ChoiceChip`, `CircleAvatar`, `Card` -- all standard Material widgets.
- **Check for `cached_network_image`** in pubspec.yaml. If present, use `CachedNetworkImage` for post photos to improve scroll performance. If not present, use standard `Image.network` (do NOT add a new dependency for this story).
- **No AI calls** in this story. Pure UI rendering consuming existing REST APIs.
- **Signed URLs for images**: OOTD post photos use signed URLs with bounded TTL. The `photoUrl` field in `OotdPost` already contains the full URL. If URLs expire, the API should refresh them on re-fetch. The mobile client just renders the URL.

### Architecture Compliance

- **Epic 9 component mapping:** `mobile/features/squads` (architecture.md). All feed UI lives within the squads feature module.
- **Optimistic UI** is NOT used for feed loading (server is source of truth for post data). Optimistic UI IS appropriate for reactions (Story 9.4), but not for feed content.
- **Accessibility**: `Semantics` labels on all interactive elements, 44x44 touch targets, text scaling support. VoiceOver should announce post author, content summary, and available actions.
- **Performance**: Cursor-based pagination prevents offset drift. Lazy image loading prevents memory issues. `ListView.builder` ensures only visible items are rendered. Target < 2 second initial feed load (NFR-PERF-06).

### Library / Framework Requirements

- **Mobile**: No new dependencies. All UI uses existing Flutter Material widgets and existing services/models from Stories 9.1 and 9.2.
- **API**: No changes needed. All endpoints already exist.

### File Structure Requirements

- `apps/mobile/lib/src/features/squads/widgets/` -- new directory for reusable squad/OOTD widgets (starting with `OotdPostCard`).
- Screens in `apps/mobile/lib/src/features/squads/screens/` follow existing patterns.
- Test files mirror source structure exactly.

### Testing Requirements

- **Flutter widget tests** follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services.
- **Mock `OotdService`** and `SquadService` in widget tests. Return controlled data for different scenarios (posts loaded, empty feed, error states, pagination).
- **No new API tests** needed -- all endpoints already tested in Story 9.2 (906 API tests).
- **Target**: All existing tests pass (906 API, 1322 Flutter) plus new widget tests for feed, post card, post detail, and screen integration.

### Previous Story Intelligence

- **Story 9.2** (done): Created `OotdPost` model, `OotdService` (with `listFeedPosts`, `listSquadPosts`, `getPost`, `deletePost`), `ApiClient` OOTD methods, `OotdCreateScreen`, signed URL upload for `ootd_post` purpose. OOTD API routes wired in `main.js`. 906 API tests, 1322 Flutter tests. The `SquadDetailScreen` now has a "Post OOTD" button (replaced placeholder). The `SquadListScreen` has a "Post OOTD" icon in the app bar.
- **Story 9.1** (done): Created squad infrastructure (tables, API, mobile service/screens). Bottom nav has Social tab. `SquadListScreen` shows squad list. `SquadDetailScreen` shows squad detail with members. `SquadService.listMySquads()` returns all user's squads.
- **Story 4.2** (done, outfit swipe UI): Established swipeable card UI pattern. Not directly applicable here (feed is vertical scroll, not swipe), but card design patterns are relevant.
- **Key patterns to follow:**
  - `mounted` guard before `setState` in ALL async callbacks.
  - Factory DI via constructor parameters for all screens and services.
  - `Semantics` labels on all interactive elements.
  - Vibrant Soft-UI design: 16px border radius, `#F3F4F6` background, `#1F2937` text, `#6B7280` secondary, `#4F46E5` accent.
  - `RefreshIndicator` for pull-to-refresh on list screens (used in wardrobe grid, outfit history).
  - `ListView.builder` for efficient list rendering (used everywhere).

### Key Anti-Patterns to Avoid

- DO NOT create new API endpoints. All needed endpoints exist from Story 9.2. This is a mobile-only story.
- DO NOT create new database migrations. All tables exist from Stories 9.1 and 9.2.
- DO NOT implement reaction or comment interaction. Story 9.4 handles that. Display the counts (0 for now) and have tappable areas with no-op callbacks.
- DO NOT implement "Steal This Look" on posts. That is Story 9.5.
- DO NOT add `cached_network_image` or any new dependency unless it is ALREADY in pubspec.yaml.
- DO NOT use `FutureBuilder` for the feed -- use StatefulWidget with explicit state management for better control over pagination and refresh.
- DO NOT use offset-based pagination. The API uses cursor-based pagination -- use `cursor` parameter.
- DO NOT forget `mounted` guard before `setState` in async callbacks (common Flutter mistake).
- DO NOT create a separate navigation route for the feed if it can be integrated as a tab in `SquadListScreen`. Keep navigation simple.
- DO NOT hardcode colors -- use the existing Vibrant Soft-UI color constants if they exist in a theme file. If no theme constants exist, use the literal hex values documented above.
- DO NOT skip pull-to-refresh. Users expect to be able to refresh a social feed by pulling down.
- DO NOT skip the empty state. An empty feed without guidance is a poor UX.
- DO NOT use Supabase client or direct database access from Flutter. All operations go through the Cloud Run API via `OotdService`.

### Out of Scope

- **Reactions and comments interaction** (Story 9.4) -- display counts only
- **"Steal This Look" matcher** (Story 9.5)
- **Social notification sending** (Story 9.6)
- **Post editing** (not in requirements)
- **Video posts** (not in requirements)
- **Real-time feed updates / WebSocket** (use pull-to-refresh)
- **Feed caching / offline support** (deferred, feed requires network)
- **Content moderation** (deferred per PRD)

### References

- [Source: epics.md - Story 9.3: Social Feed & Filtering]
- [Source: epics.md - Epic 9: Social OOTD Feed (Style Squads), FR-SOC-07, FR-SOC-08]
- [Source: prd.md - FR-SOC-07: The Social tab shall display a chronological feed of OOTD posts from all joined squads]
- [Source: prd.md - FR-SOC-08: Users shall filter the feed by specific squad]
- [Source: prd.md - NFR-PERF-06: OOTD feed load time < 2 seconds]
- [Source: architecture.md - Navigation: Social tab replacing Add tab with Squads destination]
- [Source: architecture.md - Optimistic UI allowed for reactions and save actions (not for feed content)]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - Squad membership and role checks gate social operations]
- [Source: architecture.md - Accessibility: Semantics, 44x44 touch targets, text scaling]
- [Source: architecture.md - Epic 9 Social OOTD -> mobile/features/squads, api/modules/squads]
- [Source: 9-2-ootd-post-creation.md - OotdPost model, OotdService, API endpoints, 906 API tests, 1322 Flutter tests]
- [Source: 9-1-squad-creation-management.md - Squad infrastructure, SquadService, SquadListScreen, SquadDetailScreen]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None -- clean implementation without blocking issues.

### Completion Notes List

- Created `OotdPostCard` reusable StatefulWidget with author row, CachedNetworkImage photo, expandable caption, tagged item chips, and tappable engagement row. Follows Vibrant Soft-UI design with full Semantics labels.
- Created `OotdFeedScreen` with cursor-based pagination, squad filter ChoiceChips, pull-to-refresh, empty state with CTA, error state with retry, and infinite scroll via ScrollController. Supports embedded mode for TabBarView.
- Created `OotdPostDetailScreen` with full post detail view, InteractiveViewer for photo zoom, tagged items list, delete confirmation dialog (author-only), loading/error states, and Semantics labels throughout.
- Integrated inline feed into `SquadDetailScreen` showing up to 5 recent posts with "See All" navigation to filtered OotdFeedScreen. Empty state shows "No posts yet" with OOTD CTA. Posts loaded in parallel with squad/member data.
- Added "My Squads" | "Feed" TabBar to `SquadListScreen` (Option A). Tabs only shown when ootdService is available. Feed tab embeds OotdFeedScreen in embedded mode. SquadDetailScreen now receives ootdService/apiClient passthrough.
- Created shared `formatRelativeTime()` utility in `time_utils.dart` with testable `now` parameter. Handles: Just now, Xm ago, Xh ago, Yesterday, and date format. Replaced inline _formatRelativeTime in SquadListScreen.
- All 45 new Flutter tests pass (10 OotdPostCard, 12 OotdFeedScreen, 8 OotdPostDetailScreen, 8 SquadDetailScreen additions, 4 SquadListScreen additions, 7 time_utils unit tests).
- Full regression: 1367 Flutter tests pass (1322 baseline + 45 new), 906 API tests pass, 0 new analyze issues.

### Change Log

- 2026-03-19: Story 9.3 implemented -- Social Feed & Filtering (all 12 tasks complete)

### File List

New files:
- apps/mobile/lib/src/core/utils/time_utils.dart
- apps/mobile/lib/src/features/squads/widgets/ootd_post_card.dart
- apps/mobile/lib/src/features/squads/screens/ootd_feed_screen.dart
- apps/mobile/lib/src/features/squads/screens/ootd_post_detail_screen.dart
- apps/mobile/test/core/utils/time_utils_test.dart
- apps/mobile/test/features/squads/widgets/ootd_post_card_test.dart
- apps/mobile/test/features/squads/screens/ootd_feed_screen_test.dart
- apps/mobile/test/features/squads/screens/ootd_post_detail_screen_test.dart

Modified files:
- apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart
- apps/mobile/lib/src/features/squads/screens/squad_list_screen.dart
- apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart
- apps/mobile/test/features/squads/screens/squad_list_screen_test.dart
