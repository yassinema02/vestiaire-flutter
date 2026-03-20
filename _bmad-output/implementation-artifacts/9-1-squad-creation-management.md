# Story 9.1: Squad Creation & Management

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a User,
I want to create a private Style Squad and invite my friends,
So that we have a secure, intimate space to share our outfits.

## Acceptance Criteria

1. Given I am on the Social tab (new bottom navigation destination), when the tab is empty (no squads), then I see an empty state with a "Create Squad" CTA button and an illustration/icon explaining what squads are. The Social tab replaces the dedicated "Add" tab per architecture.md: "Social can be introduced post-MVP by replacing the dedicated `Add` tab with a floating action and adding a `Squads` destination when social becomes active." A floating action button (FAB) is added to the main shell for quick item/outfit creation (previously handled by the Add tab). (FR-SOC-01)

2. Given I tap "Create Squad", when I fill in the squad name (required, 1-50 chars) and optional description (max 200 chars), then the app calls `POST /v1/squads` which: (a) validates the input, (b) generates a unique 8-character alphanumeric invite code, (c) creates a `style_squads` row with `name`, `description`, `invite_code`, `created_by = user_id`, (d) creates a `squad_memberships` row with `role = 'admin'` for the creator, (e) returns the created squad with invite code. The squad appears in my squads list. (FR-SOC-01)

3. Given I have created a squad with an invite code, when I tap "Invite Friends", then I see the invite code displayed prominently with a "Copy" button that copies the code to clipboard, and a "Share" button that opens the native share sheet (via `share_plus` or Flutter's `Share.share`) with a pre-formatted invite message containing the code. Users can join by entering the code on their Social tab. (FR-SOC-02)

4. Given another user has an invite code, when they tap "Join Squad" on the Social tab and enter the code, then the app calls `POST /v1/squads/join` with `{ "inviteCode": "ABCD1234" }` which: (a) looks up the squad by invite code, (b) checks the squad has fewer than 20 members, (c) checks the user is not already a member, (d) creates a `squad_memberships` row with `role = 'member'`, (e) returns the squad details. If the squad is full (20 members), the API returns 422 with `{ error: "Squad Full", code: "SQUAD_FULL" }`. If the code is invalid, 404 with `{ error: "Not Found", code: "INVALID_INVITE_CODE" }`. (FR-SOC-02, FR-SOC-03)

5. Given I belong to one or more squads, when I open the Social tab, then I see a list of my squads with name, member count, and last activity timestamp. Tapping a squad opens the squad detail screen showing members list, squad description, and (in future stories) the OOTD feed. Users can belong to multiple squads simultaneously. (FR-SOC-04)

6. Given I am the admin of a squad, when I view the squad members list, then I see a "Remove" action (swipe or tap icon) next to each non-admin member. Tapping "Remove" calls `DELETE /v1/squads/:squadId/members/:memberId` which removes the member's `squad_memberships` row. The removed member no longer sees the squad. (FR-SOC-05)

7. Given I am a non-admin member of a squad, when I view the squad members list, then I do NOT see the "Remove" action on other members. I see a "Leave Squad" option that calls `DELETE /v1/squads/:squadId/members/me` to remove my own membership. (FR-SOC-05)

8. Given the admin leaves or is the only member, when the admin leaves, then the squad is soft-deleted (or ownership transfers to the next oldest member if one exists). If the squad has no members, it is marked as `deleted_at = NOW()` and excluded from all queries. (FR-SOC-05)

9. Given a database migration is needed, when migration 025 runs, then it creates `style_squads` and `squad_memberships` tables in `app_public` schema with RLS policies ensuring users can only see squads they are members of, and only admins can remove members. (FR-SOC-01, FR-SOC-05)

10. Given all changes are made, when I run the full test suite, then all existing tests continue to pass (828+ API tests, 1254+ Flutter tests) and new tests cover: squad CRUD endpoints (create, join, list, get, leave, remove member), squad service logic (invite code generation, member limit enforcement, role-based authorization), SquadListScreen widget (empty state, squad cards, create/join flows), SquadDetailScreen widget (members list, admin actions, leave), ApiClient squad methods, SquadService methods, and Squad/SquadMembership model parsing.

## Tasks / Subtasks

- [x] Task 1: Database migration -- create style_squads and squad_memberships tables (AC: 2, 4, 9)
  - [x] 1.1: Create `infra/sql/migrations/025_style_squads.sql` that creates:
    - `app_public.style_squads`: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `name VARCHAR(50) NOT NULL`, `description VARCHAR(200)`, `invite_code VARCHAR(8) NOT NULL UNIQUE`, `created_by UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`, `deleted_at TIMESTAMPTZ` (soft delete).
    - `app_public.squad_memberships`: `id UUID DEFAULT gen_random_uuid() PRIMARY KEY`, `squad_id UUID NOT NULL REFERENCES app_public.style_squads(id) ON DELETE CASCADE`, `user_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE`, `role VARCHAR(10) NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member'))`, `joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`. Add UNIQUE constraint on `(squad_id, user_id)`.
    - Indexes: `idx_squad_memberships_user_id` on `squad_memberships(user_id)`, `idx_squad_memberships_squad_id` on `squad_memberships(squad_id)`, `idx_style_squads_invite_code` on `style_squads(invite_code)`, `idx_style_squads_deleted_at` on `style_squads(deleted_at)`.
    - Column comments on all fields.
  - [x] 1.2: Create RLS policies in `infra/sql/policies/025_style_squads_rls.sql`:
    - `style_squads` SELECT: user can see squads where they have a membership AND `deleted_at IS NULL`.
    - `style_squads` INSERT: any authenticated user can create.
    - `style_squads` UPDATE: only the `created_by` user (admin) can update.
    - `squad_memberships` SELECT: user can see memberships for squads they belong to.
    - `squad_memberships` INSERT: restricted to API service role (joins go through API validation, not direct inserts).
    - `squad_memberships` DELETE: admin can delete any membership in their squad; member can delete only their own.
    - Enable RLS on both tables: `ALTER TABLE app_public.style_squads ENABLE ROW LEVEL SECURITY; ALTER TABLE app_public.squad_memberships ENABLE ROW LEVEL SECURITY;`

- [x] Task 2: API -- Create squad repository (AC: 2, 4, 5, 6, 7, 8)
  - [x] 2.1: Create `apps/api/src/modules/squads/squad-repository.js` exporting `createSquadRepository({ pool })` with methods:
    - `createSquad(authContext, { name, description, inviteCode })` -- inserts into `style_squads` and `squad_memberships` (admin role) in a single transaction. Returns the created squad.
    - `getSquadByInviteCode(inviteCode)` -- looks up squad by `invite_code` WHERE `deleted_at IS NULL`. Returns squad or null.
    - `getSquadById(authContext, squadId)` -- gets squad by ID with RLS (user must be a member). Returns squad or null.
    - `listSquadsForUser(authContext)` -- returns all squads for the authenticated user with member count and last activity, WHERE `deleted_at IS NULL`, ordered by `updated_at DESC`.
    - `getSquadMemberCount(squadId)` -- returns count of memberships for a squad.
    - `addMember(squadId, userId, role)` -- inserts into `squad_memberships`.
    - `removeMember(squadId, memberId)` -- deletes from `squad_memberships` WHERE `squad_id` and `user_id`.
    - `getMembership(squadId, userId)` -- returns the membership row or null.
    - `listMembers(authContext, squadId)` -- returns all members with profile info (display name, photo URL) for a squad.
    - `softDeleteSquad(squadId)` -- sets `deleted_at = NOW()` on `style_squads`.
    - `transferOwnership(squadId, newOwnerId)` -- updates `created_by` on `style_squads` and swaps roles in `squad_memberships`.
  - [x] 2.2: `mapSquadRow(row)` maps snake_case DB columns to camelCase: `id`, `name`, `description`, `inviteCode`, `createdBy`, `createdAt`, `updatedAt`, `memberCount`, `lastActivity`.
  - [x] 2.3: `mapMembershipRow(row)` maps: `id`, `squadId`, `userId`, `role`, `joinedAt`, `displayName`, `photoUrl`.

- [x] Task 3: API -- Create squad service (AC: 2, 3, 4, 5, 6, 7, 8)
  - [x] 3.1: Create `apps/api/src/modules/squads/squad-service.js` exporting `createSquadService({ squadRepo })` with methods:
    - `createSquad(authContext, { name, description })` -- validates input (name: 1-50 chars required; description: max 200 chars optional), generates a unique 8-char alphanumeric invite code via `generateInviteCode()`, calls `squadRepo.createSquad()`. Returns created squad.
    - `joinSquad(authContext, { inviteCode })` -- validates code format, looks up squad by invite code, checks member count < 20, checks user not already a member, adds member with 'member' role. Returns squad.
    - `listMySquads(authContext)` -- delegates to `squadRepo.listSquadsForUser()`.
    - `getSquad(authContext, { squadId })` -- delegates to `squadRepo.getSquadById()`, throws 404 if not found.
    - `listMembers(authContext, { squadId })` -- verifies user is a member, then returns member list.
    - `removeMember(authContext, { squadId, memberId })` -- verifies caller is admin of the squad, verifies target is not the admin, removes member. Throws 403 if not admin.
    - `leaveSquad(authContext, { squadId })` -- removes caller's membership. If caller is admin: transfers ownership to next oldest member, or soft-deletes squad if no members remain.
  - [x] 3.2: `generateInviteCode()` -- generates 8-char uppercase alphanumeric string. Uses `crypto.randomBytes(6).toString('base64url').slice(0, 8).toUpperCase()`. Retries up to 3 times on unique constraint violation.
  - [x] 3.3: `validateSquadInput({ name, description })` -- validates name (string, 1-50 chars, trimmed) and description (string or null, max 200 chars). Throws 400 on validation failure.

- [x] Task 4: API -- Wire squad endpoints in main.js (AC: 2, 3, 4, 5, 6, 7)
  - [x] 4.1: In `apps/api/src/main.js`, add `createSquadRepository` and `createSquadService` to `createRuntime()`. Add `squadRepo` to repositories and `squadService` to services. Destructure `squadService` in `handleRequest`.
  - [x] 4.2: Add routes (all require `requireAuth`):
    - `POST /v1/squads` -- `squadService.createSquad(authContext, body)` -> 201
    - `GET /v1/squads` -- `squadService.listMySquads(authContext)` -> 200
    - `POST /v1/squads/join` -- `squadService.joinSquad(authContext, body)` -> 200
    - `GET /v1/squads/:id` -- `squadService.getSquad(authContext, { squadId })` -> 200
    - `GET /v1/squads/:id/members` -- `squadService.listMembers(authContext, { squadId })` -> 200
    - `DELETE /v1/squads/:id/members/me` -- `squadService.leaveSquad(authContext, { squadId })` -> 204
    - `DELETE /v1/squads/:id/members/:memberId` -- `squadService.removeMember(authContext, { squadId, memberId })` -> 204
  - [x] 4.3: Route ordering: place `POST /v1/squads/join` BEFORE `GET /v1/squads/:id` to prevent "join" being parsed as a squad ID. Place `DELETE /v1/squads/:id/members/me` BEFORE `DELETE /v1/squads/:id/members/:memberId` to prevent "me" being parsed as a member ID.

- [x] Task 5: Mobile -- Create Squad and SquadMembership models (AC: 2, 4, 5)
  - [x] 5.1: Create `apps/mobile/lib/src/features/squads/models/squad.dart` with:
    - `Squad`: `String id`, `String name`, `String? description`, `String inviteCode`, `String createdBy`, `DateTime createdAt`, `int memberCount`, `DateTime? lastActivity`. Factory `fromJson(Map<String, dynamic> json)`.
    - `SquadMember`: `String id`, `String squadId`, `String userId`, `String role`, `DateTime joinedAt`, `String? displayName`, `String? photoUrl`. Factory `fromJson(Map<String, dynamic> json)`. Getter `bool get isAdmin => role == 'admin';`.

- [x] Task 6: Mobile -- Create SquadService (AC: 2, 3, 4, 5, 6, 7)
  - [x] 6.1: Create `apps/mobile/lib/src/features/squads/services/squad_service.dart` with `SquadService` class. Constructor: `SquadService({ required ApiClient apiClient })`.
    - `Future<Squad> createSquad({ required String name, String? description })` -- calls `_apiClient.authenticatedPost("/v1/squads", body: { "name": name, "description": description })`.
    - `Future<List<Squad>> listMySquads()` -- calls `_apiClient.authenticatedGet("/v1/squads")`, parses list.
    - `Future<Squad> joinSquad({ required String inviteCode })` -- calls `_apiClient.authenticatedPost("/v1/squads/join", body: { "inviteCode": inviteCode })`.
    - `Future<Squad> getSquad(String squadId)` -- calls `_apiClient.authenticatedGet("/v1/squads/$squadId")`.
    - `Future<List<SquadMember>> listMembers(String squadId)` -- calls `_apiClient.authenticatedGet("/v1/squads/$squadId/members")`.
    - `Future<void> leaveSquad(String squadId)` -- calls `_apiClient.authenticatedDelete("/v1/squads/$squadId/members/me")`.
    - `Future<void> removeMember(String squadId, String memberId)` -- calls `_apiClient.authenticatedDelete("/v1/squads/$squadId/members/$memberId")`.

- [x] Task 7: Mobile -- Add squad methods to ApiClient (AC: 2, 3, 4, 5, 6, 7)
  - [x] 7.1: In `apps/mobile/lib/src/core/networking/api_client.dart`, add methods:
    - `Future<Map<String, dynamic>> createSquad(Map<String, dynamic> body)` -- `authenticatedPost("/v1/squads", body: body)`.
    - `Future<List<dynamic>> listSquads()` -- `authenticatedGet("/v1/squads")` returning parsed list.
    - `Future<Map<String, dynamic>> joinSquad(Map<String, dynamic> body)` -- `authenticatedPost("/v1/squads/join", body: body)`.
    - `Future<Map<String, dynamic>> getSquad(String squadId)` -- `authenticatedGet("/v1/squads/$squadId")`.
    - `Future<List<dynamic>> listSquadMembers(String squadId)` -- `authenticatedGet("/v1/squads/$squadId/members")`.
    - `Future<void> leaveSquad(String squadId)` -- `authenticatedDelete("/v1/squads/$squadId/members/me")`.
    - `Future<void> removeSquadMember(String squadId, String memberId)` -- `authenticatedDelete("/v1/squads/$squadId/members/$memberId")`.
  - [x] 7.2: Place these methods adjacent to each other, after the shopping scan methods, with a `// --- Squads ---` comment block.

- [x] Task 8: Mobile -- Update bottom navigation to include Social tab (AC: 1)
  - [x] 8.1: In the main app shell (likely `apps/mobile/lib/src/app/` or `apps/mobile/lib/src/core/navigation/`), update the bottom navigation bar:
    - Replace the "Add" tab with a "Social" tab (icon: `Icons.groups` or `Icons.people`, label: "Social").
    - Add a FloatingActionButton (FAB) to the main shell for quick item/outfit creation (the functionality previously on the Add tab). The FAB should be centered/docked or positioned bottom-right with `Icons.add`.
    - The Social tab navigates to `SquadListScreen`.
  - [x] 8.2: Ensure the navigation index mapping is updated. The canonical order becomes: `Home`, `Wardrobe`, `Social`, `Outfits`, `Profile`. Verify all existing navigation references still work (e.g., "Go to Wardrobe" buttons in other screens).

- [x] Task 9: Mobile -- Create SquadListScreen (AC: 1, 2, 3, 4, 5)
  - [x] 9.1: Create `apps/mobile/lib/src/features/squads/screens/squad_list_screen.dart` with `SquadListScreen` StatefulWidget. Constructor: `{ required SquadService squadService, super.key }`.
  - [x] 9.2: On `initState`, call `squadService.listMySquads()` to load squads.
  - [x] 9.3: **Empty state** (no squads): Center-aligned content with `Icons.groups` (64px, secondary color), title "Your Style Squads", subtitle "Create a squad or join one with an invite code to start sharing outfits with friends.", two buttons: "Create Squad" (primary, `ElevatedButton`) and "Join Squad" (outlined, `OutlinedButton`).
  - [x] 9.4: **Squad list**: `ListView.builder` with cards. Each card shows squad name (bold, 16px), member count ("X members", 14px secondary), last activity time (relative, e.g., "2h ago", 12px). Tapping navigates to `SquadDetailScreen`.
  - [x] 9.5: **App bar actions**: "+" icon button in app bar opens a bottom sheet with "Create Squad" and "Join Squad" options.
  - [x] 9.6: **Create Squad flow**: Bottom sheet or dialog with `TextFormField` for name (required, max 50), `TextFormField` for description (optional, max 200), and "Create" button. On success, refresh list and navigate to squad detail.
  - [x] 9.7: **Join Squad flow**: Bottom sheet or dialog with `TextFormField` for invite code (8 chars), "Join" button. On success, refresh list and navigate to squad detail. On error (invalid code, squad full), show SnackBar with error message.
  - [x] 9.8: Follow Vibrant Soft-UI design: 16px border radius, subtle shadows, `#F3F4F6` background, `#1F2937` text, `#6B7280` secondary text, `#4F46E5` primary accent.
  - [x] 9.9: Add `Semantics` labels on: each squad card ("Squad: name, X members"), create button, join button, empty state elements.

- [x] Task 10: Mobile -- Create SquadDetailScreen (AC: 5, 6, 7, 8)
  - [x] 10.1: Create `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart` with `SquadDetailScreen` StatefulWidget. Constructor: `{ required String squadId, required SquadService squadService, super.key }`.
  - [x] 10.2: On `initState`, call `squadService.getSquad(squadId)` and `squadService.listMembers(squadId)` in parallel.
  - [x] 10.3: **Header section**: Squad name (title), description (subtitle), invite code with copy button, "Share Invite" button.
  - [x] 10.4: **Members section**: `ListView` of members. Each member row shows: `CircleAvatar` with photo (or initials fallback), display name, role badge ("Admin" chip for admins), joined date.
  - [x] 10.5: **Admin actions**: If current user is admin, show swipe-to-dismiss or trailing icon button (`Icons.remove_circle_outline`) on non-admin members. Tapping triggers confirmation dialog, then calls `squadService.removeMember(squadId, memberId)`. Refresh members list on success.
  - [x] 10.6: **Leave action**: "Leave Squad" button (destructive, red text) in the app bar overflow menu or at the bottom. Triggers confirmation dialog. On confirm, calls `squadService.leaveSquad(squadId)`. Navigates back to squad list on success.
  - [x] 10.7: **Placeholder for feed**: Below members, show a "Coming Soon" section or divider indicating "OOTD Feed will appear here" (Story 9.2/9.3 will populate this).
  - [x] 10.8: `Semantics` labels on: member rows, remove/leave buttons, invite code, share button.

- [x] Task 11: API -- Unit tests for squad service (AC: 2, 3, 4, 6, 7, 8, 10)
  - [x] 11.1: Create `apps/api/test/modules/squads/squad-service.test.js`:
    - `createSquad` validates name (required, 1-50 chars), description (optional, max 200 chars).
    - `createSquad` generates 8-char invite code and creates squad + admin membership.
    - `createSquad` rejects empty name with 400.
    - `createSquad` rejects name > 50 chars with 400.
    - `joinSquad` finds squad by invite code and adds member.
    - `joinSquad` returns 404 for invalid invite code.
    - `joinSquad` returns 422 when squad has 20 members (SQUAD_FULL).
    - `joinSquad` returns 409 when user is already a member.
    - `listMySquads` returns all squads for user with member count.
    - `getSquad` returns squad details for member.
    - `getSquad` returns 404 for non-member.
    - `removeMember` removes member when caller is admin.
    - `removeMember` returns 403 when caller is not admin.
    - `removeMember` returns 403 when trying to remove the admin.
    - `leaveSquad` removes caller's membership.
    - `leaveSquad` transfers ownership when admin leaves with remaining members.
    - `leaveSquad` soft-deletes squad when last member leaves.
    - `validateSquadInput` rejects invalid input shapes.
    - `generateInviteCode` produces 8-char alphanumeric strings.

- [x] Task 12: API -- Integration tests for squad endpoints (AC: 2, 3, 4, 5, 6, 7, 8, 10)
  - [x] 12.1: Create `apps/api/test/modules/squads/squad-endpoint.test.js`:
    - POST /v1/squads returns 201 with created squad and invite code.
    - POST /v1/squads returns 400 for missing name.
    - POST /v1/squads returns 401 without auth.
    - GET /v1/squads returns 200 with user's squads list.
    - GET /v1/squads returns empty array for user with no squads.
    - POST /v1/squads/join returns 200 with squad on valid code.
    - POST /v1/squads/join returns 404 for invalid code.
    - POST /v1/squads/join returns 422 for full squad.
    - POST /v1/squads/join returns 409 for already-member.
    - GET /v1/squads/:id returns 200 for member.
    - GET /v1/squads/:id returns 404 for non-member (RLS).
    - GET /v1/squads/:id/members returns 200 with member list.
    - DELETE /v1/squads/:id/members/me returns 204 on leave.
    - DELETE /v1/squads/:id/members/:memberId returns 204 on admin remove.
    - DELETE /v1/squads/:id/members/:memberId returns 403 for non-admin.
    - DELETE /v1/squads/:id/members/:memberId returns 401 without auth.

- [x] Task 13: Mobile -- Widget tests for SquadListScreen (AC: 1, 2, 3, 4, 5, 10)
  - [x] 13.1: Create `apps/mobile/test/features/squads/screens/squad_list_screen_test.dart`:
    - Renders empty state with "Create Squad" and "Join Squad" buttons when no squads.
    - Renders squad cards with name, member count, and last activity.
    - Tapping "Create Squad" opens create dialog/bottom sheet.
    - Create form validates name is required.
    - Successful creation refreshes list.
    - Tapping "Join Squad" opens join dialog/bottom sheet.
    - Join with valid code refreshes list.
    - Join with invalid code shows error SnackBar.
    - Join with full squad shows error SnackBar.
    - Tapping squad card navigates to detail screen.
    - Semantics labels present on squad cards and buttons.

- [x] Task 14: Mobile -- Widget tests for SquadDetailScreen (AC: 5, 6, 7, 8, 10)
  - [x] 14.1: Create `apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart`:
    - Displays squad name, description, and invite code.
    - Displays members list with names, photos, and role badges.
    - Admin sees remove button on non-admin members.
    - Non-admin does NOT see remove button.
    - Remove member triggers confirmation dialog and API call.
    - Leave squad triggers confirmation dialog and navigates back.
    - Copy invite code button copies to clipboard.
    - Share invite button triggers share sheet.
    - Semantics labels on member rows and action buttons.

- [x] Task 15: Mobile -- Model tests for Squad and SquadMember (AC: 5, 10)
  - [x] 15.1: Create `apps/mobile/test/features/squads/models/squad_test.dart`:
    - `Squad.fromJson` parses all fields correctly.
    - `Squad.fromJson` handles null description and lastActivity.
    - `SquadMember.fromJson` parses all fields correctly.
    - `SquadMember.isAdmin` returns true for admin role.
    - `SquadMember.isAdmin` returns false for member role.

- [x] Task 16: Mobile -- ApiClient and SquadService tests (AC: 2, 3, 4, 10)
  - [x] 16.1: Update `apps/mobile/test/core/networking/api_client_test.dart`:
    - `createSquad` calls POST /v1/squads.
    - `listSquads` calls GET /v1/squads.
    - `joinSquad` calls POST /v1/squads/join.
    - `getSquad` calls GET /v1/squads/:id.
    - `listSquadMembers` calls GET /v1/squads/:id/members.
    - `leaveSquad` calls DELETE /v1/squads/:id/members/me.
    - `removeSquadMember` calls DELETE /v1/squads/:id/members/:memberId.
  - [x] 16.2: Create `apps/mobile/test/features/squads/services/squad_service_test.dart`:
    - `createSquad` calls correct API endpoint and returns Squad.
    - `listMySquads` returns list of Squads.
    - `joinSquad` calls correct endpoint with invite code.
    - `leaveSquad` calls correct DELETE endpoint.
    - `removeMember` calls correct DELETE endpoint with member ID.

- [x] Task 17: Mobile -- Navigation integration tests (AC: 1, 10)
  - [x] 17.1: Update existing navigation tests to verify:
    - Bottom navigation now has 5 tabs: Home, Wardrobe, Social, Outfits, Profile.
    - "Add" tab is no longer present.
    - FAB is visible for quick item/outfit creation.
    - Social tab navigates to SquadListScreen.
    - Existing "Go to Wardrobe" and similar navigation CTAs still work with updated tab indices.

- [x] Task 18: Regression testing (AC: all)
  - [x] 18.1: Run `flutter analyze` -- zero new issues.
  - [x] 18.2: Run `flutter test` -- all existing 1254+ tests plus new tests pass.
  - [x] 18.3: Run `npm --prefix apps/api test` -- all existing 828+ API tests plus new tests pass.
  - [x] 18.4: Verify all existing bottom navigation behavior still works (tab indices updated correctly).
  - [x] 18.5: Verify existing notification preferences still show "social" toggle (from Story 1.6 migration 005).

## Dev Notes

- This is the FIRST story in Epic 9 (Social OOTD Feed / Style Squads). It establishes the social infrastructure: database tables, API module, mobile feature module, and bottom navigation restructuring. Stories 9.2-9.6 will build on this foundation to add OOTD posting, feed, reactions, "Steal This Look", and notification preferences.
- The `squads` API module and mobile feature module are GREENFIELD -- no existing files. Create all directories and files from scratch following established patterns from previous epics.
- The bottom navigation change (replacing "Add" tab with "Social") is a significant UX shift. Per architecture.md: "Social can be introduced post-MVP by replacing the dedicated `Add` tab with a floating action and adding a `Squads` destination when social becomes active." The FAB replaces the Add tab's functionality.
- Invite codes use 8-character uppercase alphanumeric strings generated via `crypto.randomBytes`. The invite code column has a UNIQUE constraint. The service retries code generation up to 3 times on collision (extremely unlikely with 36^8 = 2.8 trillion combinations).
- Squad size limit is 20 members (FR-SOC-03). This is enforced server-side by counting memberships before inserting a new one.
- Notification preferences already include a "social" category toggle (from migration 005, Story 1.6). The `notification_preferences` JSONB on `profiles` has `"social": true` by default. Story 9.6 will implement the actual social notification sending logic, but the preference infrastructure already exists.
- Soft delete on squads: when all members leave or the squad is disbanded, set `deleted_at` rather than hard deleting. This preserves data integrity for any future analytics or recovery needs. All queries filter by `deleted_at IS NULL`.

### Database Schema Design

```sql
-- style_squads
CREATE TABLE app_public.style_squads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  description VARCHAR(200),
  invite_code VARCHAR(8) NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- squad_memberships
CREATE TABLE app_public.squad_memberships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  squad_id UUID NOT NULL REFERENCES app_public.style_squads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_public.profiles(id) ON DELETE CASCADE,
  role VARCHAR(10) NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (squad_id, user_id)
);
```

### API Endpoint Summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /v1/squads | Yes | Create squad |
| GET | /v1/squads | Yes | List my squads |
| POST | /v1/squads/join | Yes | Join via invite code |
| GET | /v1/squads/:id | Yes | Get squad detail |
| GET | /v1/squads/:id/members | Yes | List squad members |
| DELETE | /v1/squads/:id/members/me | Yes | Leave squad |
| DELETE | /v1/squads/:id/members/:memberId | Yes | Remove member (admin) |

### Route Ordering in main.js

Critical: `POST /v1/squads/join` must be matched BEFORE `GET /v1/squads/:id` (otherwise "join" would be parsed as a squad ID). Similarly, `DELETE /v1/squads/:id/members/me` must be matched BEFORE `DELETE /v1/squads/:id/members/:memberId`. Use the same regex-based URL matching pattern as existing routes. Example:

```javascript
// Squads routes - order matters!
if (method === "POST" && url.pathname === "/v1/squads/join") { ... }
if (method === "POST" && url.pathname === "/v1/squads") { ... }
if (method === "GET" && url.pathname === "/v1/squads") { ... }
const squadIdMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)$/);
const squadMembersMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)\/members$/);
const squadMembersMeMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)\/members\/me$/);
const squadMemberIdMatch = url.pathname.match(/^\/v1\/squads\/([^/]+)\/members\/([^/]+)$/);
// Check /members/me BEFORE /members/:memberId
```

### Invite Code Generation

```javascript
import crypto from "node:crypto";

function generateInviteCode() {
  return crypto.randomBytes(6).toString("base64url").slice(0, 8).toUpperCase();
}
```

### Project Structure Notes

- New API files:
  - `apps/api/src/modules/squads/squad-repository.js`
  - `apps/api/src/modules/squads/squad-service.js`
  - `apps/api/test/modules/squads/squad-service.test.js`
  - `apps/api/test/modules/squads/squad-endpoint.test.js`
- New mobile files:
  - `apps/mobile/lib/src/features/squads/models/squad.dart`
  - `apps/mobile/lib/src/features/squads/services/squad_service.dart`
  - `apps/mobile/lib/src/features/squads/screens/squad_list_screen.dart`
  - `apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart`
  - `apps/mobile/test/features/squads/models/squad_test.dart`
  - `apps/mobile/test/features/squads/services/squad_service_test.dart`
  - `apps/mobile/test/features/squads/screens/squad_list_screen_test.dart`
  - `apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart`
- New migration files:
  - `infra/sql/migrations/025_style_squads.sql`
  - `infra/sql/policies/025_style_squads_rls.sql`
- Modified files:
  - `apps/api/src/main.js` (add squad repository, service to createRuntime; add 7 squad routes to handleRequest)
  - `apps/mobile/lib/src/core/networking/api_client.dart` (add 7 squad methods)
  - `apps/mobile/lib/src/app/` or `apps/mobile/lib/src/core/navigation/` (update bottom nav: replace Add tab with Social, add FAB)
  - `apps/mobile/test/core/networking/api_client_test.dart` (add squad method tests)
  - Navigation-related test files (update tab indices and expectations)

### Technical Requirements

- **PostgreSQL 16** with RLS. Both new tables require RLS policies. The `squad_memberships` table is the gatekeeper -- if a user has no membership row, they cannot see the squad.
- **No new dependencies on API.** Uses existing `node:crypto` for invite code generation. Uses existing `pool` for database access. Follows the same factory pattern as all other services.
- **Mobile dependency consideration:** `share_plus` package for native share sheet. Check if already in `pubspec.yaml`. If not, add `share_plus: ^10.x`. Alternatively, use Flutter's built-in `Share.share` if `share_plus` is already present or use `Clipboard.setData` for copy-only (no new dependency needed for clipboard).
- **No AI calls** in this story. Pure CRUD + authorization logic.
- **`authenticatedDelete`** method on ApiClient: verify this method exists. It was established in earlier stories (account deletion in 1-7). If it does not exist, add it following the same pattern as `authenticatedGet`/`authenticatedPost`/`authenticatedPut`/`authenticatedPatch`.

### Architecture Compliance

- **Epic 9 component mapping:** `mobile/features/squads`, `api/modules/squads`, `api/modules/notifications` (architecture.md). This story creates the first two. Notifications module usage comes in Story 9.6.
- **RLS on all user-facing tables.** Both `style_squads` and `squad_memberships` require RLS policies.
- **Squad membership gates social operations.** This is explicitly stated in architecture.md under Authorization model.
- **Server-side enforcement** for member limits (20), role-based access (admin vs member), and input validation.
- **Bottom navigation restructure** follows architecture.md guidance for post-MVP Social tab introduction.
- **Media/storage** not needed in this story (no photos uploaded for squads themselves). OOTD post photos come in Story 9.2.

### Library / Framework Requirements

- **API:** No new dependencies. `node:crypto` (built-in), existing `pool`, existing auth middleware.
- **Mobile:** Potentially `share_plus` for native share sheet (check if already present). `flutter/services.dart` for `Clipboard` (built-in). All UI uses existing Flutter Material widgets.

### File Structure Requirements

- `apps/api/src/modules/squads/` -- new directory, follows same pattern as `apps/api/src/modules/shopping/`.
- `apps/mobile/lib/src/features/squads/` -- new directory with `models/`, `services/`, `screens/` subdirectories.
- Test files mirror source structure exactly.

### Testing Requirements

- **API tests** use the existing Node.js built-in test runner. Follow patterns from `shopping-scan-service.test.js` and `shopping-scan-endpoint.test.js`.
- **Mock the squad repository** in service tests. Return controlled data for different scenarios.
- **Flutter widget tests** follow existing patterns: `setupFirebaseCoreMocks()` + `Firebase.initializeApp()` + mock services.
- **Target:** All existing tests pass (828 API, 1254 Flutter) plus new tests for all squad functionality.

### Previous Story Intelligence

- **Story 8.5** (done, last completed): 828 API tests, 1254 Flutter tests. Established `createShoppingScanService` with insight generation, `MatchInsightScreen`, wishlist toggle. `createRuntime()` returns 33 services. `handleRequest` destructures all services.
- **Story 1.6** (done, notification infrastructure): Established `push_token` and `notification_preferences` on `profiles` table. The `notification_preferences` JSONB includes `"social": true` by default. This is the preference toggle that Story 9.6 will use for social notification delivery.
- **Story 1.7** (done, account deletion): Established `authenticatedDelete` pattern on ApiClient and the `DELETE` HTTP method handling in the API. The cascade delete on `profiles(id)` will automatically clean up squad memberships when a user deletes their account.
- **Key patterns from all previous stories:**
  - Factory pattern for API services: `createXxxService({ deps })`.
  - Factory pattern for API repositories: `createXxxRepository({ pool })`.
  - DI via constructor parameters for mobile services and screens.
  - `mounted` guard before `setState` in async callbacks.
  - camelCase mapping in API repositories via `mapXxxRow`.
  - Semantics labels on all interactive elements.
  - Route regex matching in `main.js` with `url.pathname.match(...)`.
  - 201 for resource creation, 200 for reads, 204 for deletes, 400/401/403/404/409/422 for errors.

### Key Anti-Patterns to Avoid

- DO NOT create squad-related tables without RLS policies. Both tables MUST have RLS enabled and policies defined.
- DO NOT allow direct membership inserts from the client. All joins go through the API which validates member count and duplicate membership.
- DO NOT hard-delete squads. Use soft delete (`deleted_at`) to preserve data integrity.
- DO NOT skip route ordering. `POST /v1/squads/join` MUST come before `GET /v1/squads/:id` in the route matching.
- DO NOT create a new notifications module in this story. Notification sending logic belongs in Story 9.6.
- DO NOT create OOTD-related tables in this story. The `ootd_posts`, `ootd_comments`, and `ootd_reactions` tables are for Stories 9.2-9.4.
- DO NOT forget to update existing navigation tests after replacing the Add tab with Social.
- DO NOT create a separate "Add Item" screen to replace the Add tab -- use a FAB on the main shell that triggers the same flow.
- DO NOT skip the UNIQUE constraint on `(squad_id, user_id)` in `squad_memberships`. This prevents duplicate memberships.
- DO NOT trust client-side role checks alone. The API must verify admin role server-side before allowing member removal.
- DO NOT use Supabase client or any direct database access from Flutter. All operations go through the Cloud Run API.

### Out of Scope

- **OOTD post creation and feed** (Story 9.2, 9.3)
- **Reactions and comments** (Story 9.4)
- **"Steal This Look" matching** (Story 9.5)
- **Social notification sending** (Story 9.6) -- preference infrastructure already exists from Story 1.6
- **Squad photo/avatar upload** (not in requirements)
- **Squad name editing after creation** (not in requirements, can be added later)
- **Blocking/reporting squad members** (deferred per PRD content moderation note)
- **Real-time updates** (WebSocket/SSE for live member joins) -- use pull-to-refresh

### References

- [Source: epics.md - Story 9.1: Squad Creation & Management]
- [Source: epics.md - Epic 9: Social OOTD Feed (Style Squads), FR-SOC-01 through FR-SOC-05]
- [Source: prd.md - FR-SOC-01: Users shall create Style Squads (private groups) with a name, optional description, and unique invite code]
- [Source: prd.md - FR-SOC-02: Users shall invite others to squads via invite code, SMS, or username search]
- [Source: prd.md - FR-SOC-03: Squad size shall be limited to 20 members]
- [Source: prd.md - FR-SOC-04: Users shall belong to multiple squads simultaneously]
- [Source: prd.md - FR-SOC-05: Squad admins shall be able to remove members]
- [Source: architecture.md - Navigation: Social can be introduced post-MVP by replacing the dedicated Add tab with a floating action and adding a Squads destination]
- [Source: architecture.md - Important tables: style_squads, squad_memberships, ootd_posts, ootd_comments, ootd_reactions]
- [Source: architecture.md - Squad membership and role checks gate social operations]
- [Source: architecture.md - Epic 9 Social OOTD -> mobile/features/squads, api/modules/squads, api/modules/notifications]
- [Source: architecture.md - RLS on all user-facing tables]
- [Source: architecture.md - Optimistic UI is allowed for reactions and save actions]
- [Source: infra/sql/migrations/005_push_notifications.sql - notification_preferences JSONB with "social": true default]
- [Source: 8-5-shopping-match-insight-display.md - 828 API tests, 1254 Flutter tests baseline]
- [Source: 1-6-push-notification-permissions-preferences.md - notification preference infrastructure with social category]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

None required. Implementation proceeded without blocking issues.

### Completion Notes List

- Created style_squads and squad_memberships tables with migration 025, including all specified columns, constraints, indexes, and column comments.
- Created RLS policies for both tables: SELECT (membership-gated), INSERT (authenticated), UPDATE (admin-only), DELETE (admin or self).
- Implemented squad-repository.js with 12 methods: createSquad, getSquadByInviteCode, getSquadById, listSquadsForUser, getSquadMemberCount, addMember, removeMember, getMembership, listMembers, softDeleteSquad, transferOwnership, getProfileIdForUser.
- Implemented squad-service.js with 7 methods: createSquad, joinSquad, listMySquads, getSquad, listMembers, removeMember, leaveSquad. Includes generateInviteCode and validateSquadInput.
- Wired 7 squad routes in main.js with correct route ordering (POST /v1/squads/join before GET /v1/squads/:id, DELETE /members/me before /members/:memberId).
- Created Squad and SquadMember Dart models with fromJson factories and isAdmin getter.
- Created SquadService Dart class for API communication.
- Added 7 squad methods to ApiClient (createSquad, listSquads, joinSquad, getSquad, listSquadMembers, leaveSquad, removeSquadMember).
- Restructured bottom navigation: replaced "Add" tab with "Social" tab (Icons.groups), added FAB for item creation.
- Created SquadListScreen with empty state (illustration, CTA buttons), squad list cards, create/join bottom sheet flows, relative time formatting, Semantics labels.
- Created SquadDetailScreen with header section (name, description, invite code with copy/share), members list with admin role badges, remove member action (admin-only), leave squad action, OOTD feed placeholder.
- 41 new API tests: 22 squad-service unit tests + 16 squad-endpoint integration tests + 3 mapRow tests.
- 38 new Flutter tests: 8 model tests + 7 service tests + 7 ApiClient method tests + 8 SquadListScreen widget tests + 8 SquadDetailScreen widget tests.
- Updated existing navigation tests (main_shell_screen_test.dart, widget_test.dart) to reflect Social tab replacing Add tab.
- Final test counts: 869 API tests (all pass), 1292 Flutter tests (all pass). Zero new analyzer issues.

### Change Log

- 2026-03-19: Story 9.1 implementation complete. Created social infrastructure: DB tables, API module, mobile feature module, bottom nav restructuring. (Claude Opus 4.6)

### File List

New files:
- infra/sql/migrations/025_style_squads.sql
- infra/sql/policies/025_style_squads_rls.sql
- apps/api/src/modules/squads/squad-repository.js
- apps/api/src/modules/squads/squad-service.js
- apps/api/test/modules/squads/squad-service.test.js
- apps/api/test/modules/squads/squad-endpoint.test.js
- apps/mobile/lib/src/features/squads/models/squad.dart
- apps/mobile/lib/src/features/squads/services/squad_service.dart
- apps/mobile/lib/src/features/squads/screens/squad_list_screen.dart
- apps/mobile/lib/src/features/squads/screens/squad_detail_screen.dart
- apps/mobile/test/features/squads/models/squad_test.dart
- apps/mobile/test/features/squads/services/squad_service_test.dart
- apps/mobile/test/features/squads/screens/squad_list_screen_test.dart
- apps/mobile/test/features/squads/screens/squad_detail_screen_test.dart

Modified files:
- apps/api/src/main.js (added squad imports, createRuntime squad services, handleRequest destructure, 7 squad routes)
- apps/mobile/lib/src/core/networking/api_client.dart (added 7 squad methods)
- apps/mobile/lib/src/features/shell/screens/main_shell_screen.dart (replaced Add tab with Social tab, added FAB)
- apps/mobile/test/core/networking/api_client_test.dart (added squad method tests to TestableApiClient)
- apps/mobile/test/features/shell/screens/main_shell_screen_test.dart (updated for Social tab, FAB, removed Add tab expectations)
- apps/mobile/test/widget_test.dart (updated to expect Social instead of Add tab)
