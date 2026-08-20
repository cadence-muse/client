# Pitfalls Research

**Domain:** Flutter offline read-caching + ChangeNotifier→Provider/Riverpod migration (brownfield, band repertoire app)
**Researched:** 2026-08-14 (v1.0) + 2026-08-20 (v1.1 additions)
**Confidence:** MEDIUM-HIGH (cross-checked against official Riverpod docs, current Flutter/Drift community guidance, and this repo's own `ARCHITECTURE.md`/`CONCERNS.md`)

## Critical Pitfalls

### Pitfall 1: Collapsing API DTO, cache entity, and domain model into one class

**What goes wrong:**
A single `Band`/`Track`/`Setlist` class is used simultaneously as the JSON-decoded API response, the local DB row, and the UI-facing model. The first time the backend adds/renames/nullifies a field (or the local schema needs a column the API doesn't have, e.g. `cachedAt`), the single class breaks in three places at once — JSON decode, DB (de)serialization, and every widget that reads it.

**Why it happens:**
It's the fastest way to get CRUD screens working, and this codebase already has a `Band` stub in `bands_screen.dart` with no separation of concerns to build from. Under time pressure it's tempting to reuse the OpenAPI-generated/hand-written response model as the Drift/sqflite row type directly.

**How to avoid:**
Keep three thin layers even if they look identical at first: API DTO (matches `publicapi.yml` exactly, owned by the API layer), cache row (owned by the DB layer, includes cache-only metadata like `cachedAt`/`bandId` scoping), and domain model (what screens consume). A mapper function converts DTO → domain and cache-row → domain. This is more boilerplate on day one but is what prevents the "rename a field, break three layers" failure mode described by current Flutter offline-first guidance.

**Warning signs:**
- A model class has both `fromJson`/`toJson` (API) and `fromMap`/`toMap` (DB) methods on the same class.
- Adding a cache-only field (e.g., `lastSyncedAt`) requires touching API request/response code.
- Nullability differs between what the API guarantees and what the DB migration allows.

**Phase to address:**
Cache-layer foundation phase (before band/track/setlist CRUD screens are wired to real data).

---

### Pitfall 2: Cache not scoped/cleared per user and per band → data bleed on logout or band switch

**What goes wrong:**
Local cache (sqflite/Drift/Hive) is a single unscoped store. A user logs out and a different account logs in on the same device, or a user who belongs to multiple bands switches bands — and sees the previous user's or previous band's tracks/setlists because cache rows aren't keyed by `userId`/`bandId` and nothing clears them on `signOut()`.

**Why it happens:**
`AuthSession.signOut()` already exists and is called from multiple paths (manual logout, 403 auto-logout in `ApiClient`) but has no hook today to clear anything beyond the token (`CONCERNS.md` flags `AuthSession` as fragile with "multiple paths modify state"). It's easy to wire the cache layer without ever touching `signOut()`.

**How to avoid:**
Every cache write includes the owning `bandId` (and ideally `userId`) as part of the key/row. Add a `clearAll()`/`clearForUser()` method on the cache layer and call it from `AuthSession.signOut()` (or a listener on auth state transitioning to `unauthenticated`). Treat this as a required part of the auth/cache integration, not an afterthought.

**Warning signs:**
- Cache queries don't filter by band ID anywhere in the DB layer.
- No test exists for "log out, log in as different user, verify band list is empty/refetched."
- `signOut()` implementation only touches `TokenStorage`.

**Phase to address:**
Cache-layer foundation phase; verified again in the offline-read-integration phase once real multi-band data exists.

---

### Pitfall 3: Stale-cache UX indistinguishable from fresh data (breaks the app's core value prop)

**What goes wrong:**
The app's stated core value is "a band member can open the app without signal and still see tonight's setlist." If the cached setlist looks identical to a freshly-fetched one — no "offline" banner, no "last updated" timestamp — a user at a venue with no signal has no way to know the setlist they're viewing might be missing a same-day edit made by a bandmate before they lost signal.

**Why it happens:**
Read-through caching ("show cached data while fetching, silently replace when the network call succeeds") is the easy implementation and looks correct in a demo where network is always available. The staleness problem is invisible until someone is actually offline in the field — exactly the scenario this feature exists for.

**How to avoid:**
Every cached screen surfaces two signals: (1) an explicit offline/stale indicator (banner or badge) when data being shown came from cache rather than network, and (2) a "last synced" timestamp on band/track/setlist detail views. Distinguish "no connectivity, showing cache" from "connectivity present but request failed" — these need different messaging (see Pitfall 8).

**Warning signs:**
- No `cachedAt`/`lastSyncedAt` field exists anywhere in the cache schema.
- UI has no offline banner or stale-data affordance in the design.
- Manual test: put device in airplane mode, reopen a screen previously viewed online — indistinguishable from the online state.

**Phase to address:**
Offline-read-integration phase (this is a UX requirement, not just a data-layer requirement — should be in the plan's acceptance criteria, not bolted on after).

---

### Pitfall 4: Successful online mutations don't invalidate/update the read cache

**What goes wrong:**
User edits a track's title while online. The API call succeeds. But the local cache used for offline reads still has the old title, because the CRUD mutation path and the cache-read path were built independently. Next time the user opens the app offline, they see stale (pre-edit) data even though they made the edit online themselves, minutes ago.

**Why it happens:**
This milestone explicitly scopes out "offline writes / mutation queue" (see `PROJECT.md` Out of Scope), which can lead to the mistaken conclusion that mutations don't need to touch the cache layer at all. But "read-only cache" means *writes require connectivity*, not *writes never touch the cache*. If a successful online mutation doesn't update (or invalidate) the corresponding cache row, users see regressions ("my edit disappeared") the next time they're offline.

**How to avoid:**
Every successful create/update/delete call updates the local cache row (or invalidates it, forcing a refetch on next online view) as part of the same repository method — not as a separate, easily-forgotten step. Treat "mutation success → cache write" as part of the definition of done for every CRUD endpoint, the same way `flutter analyze`/`flutter test` are.

**Warning signs:**
- Mutation methods (`updateTrack`, `deleteBand`, etc.) call `ApiClient` directly with no call into the cache/repository layer.
- No test exercises "edit online, go offline, verify edit is visible."
- Cache is only ever written from the "list"/"get" API response handlers.

**Phase to address:**
Band/track/setlist CRUD phase, verified in offline-read-integration phase.

---

### Pitfall 5: Cache schema migrations skipped or destructive, causing crashes/data loss on app update

**What goes wrong:**
sqflite/Drift's schema versioning (`onUpgrade`/`MigrationStrategy`) is skipped during initial development because there's only ever one schema version in dev. Then a field is added or renamed post-launch, the DB version bump has no migration path, and existing installs either crash on the next open or silently lose their cache (and thus their offline data) on update.

**Why it happens:**
During active development it's common to just uninstall/reinstall the app (wiping the DB) instead of writing a migration, so the discipline of "every schema change needs a migration step" never gets exercised until it's needed for real users — by which point it's easy to forget.

**How to avoid:**
From the very first schema version, treat every column/table change as requiring an explicit migration step (even if trivial), and add a test that constructs the DB at each prior schema version and runs the upgrade path. Never drop/rename a column in place — add new, migrate data, drop old in a later version if needed.

**Warning signs:**
- Database class has a single hardcoded `schemaVersion` and no `onUpgrade`/migration steps defined.
- "Just delete the app and reinstall" is the team's answer to a local schema change during testing.
- No migration test exists in the test suite.

**Phase to address:**
Cache-layer foundation phase (bake the migration discipline in before any schema changes happen, not after the first one is needed).

---

### Pitfall 6: Riverpod `autoDispose` (or naive Provider scoping) fights the offline-caching goal

**What goes wrong:**
`RootScaffold` already keeps all four tab screens alive via `IndexedStack` (flagged in `ARCHITECTURE.md`/`CONCERNS.md` as a memory-cost anti-pattern, but also a caching *asset*). If band/track/setlist providers are declared with Riverpod's `autoDispose` (a common "best practice" default) or are instantiated per-screen instead of at a shared scope, switching tabs disposes and recreates the provider — triggering a fresh network/cache read every tab switch, flickering loading states, and partially defeating the point of caching offline-viewable data.

**Why it happens:**
`autoDispose` is Riverpod's recommended default for most guides (avoids leaks for provider instances tied to a route/screen that goes away), but this app's IndexedStack navigation keeps screens mounted, and "data users should still see when offline" is exactly the case where you want state retained across tab switches, not disposed.

**How to avoid:**
Deliberately choose `keepAlive`/non-autoDispose (or manual `ref.keepAlive()`) for band/track/setlist providers whose data should persist across tab switches and app backgrounding, reserving `autoDispose` for screen-local/transient state (e.g., a single "edit track" form). Document this choice explicitly since it goes against generic Riverpod tutorials.

**Warning signs:**
- Every provider uses `autoDispose` "because that's the Riverpod default."
- Switching tabs shows a loading spinner every time, even for data fetched moments ago.
- Network requests fire on every tab switch in dev logs, not just on cold start/pull-to-refresh.

**Phase to address:**
State-management migration phase (decide the provider lifetime policy up front) and offline-read-integration phase (verify tab-switch behavior).

---

### Pitfall 7: Partial migration leaves two competing sources of truth for auth/session state

**What goes wrong:**
`AuthSession` (existing `ChangeNotifier`, consumed via `ListenableBuilder`/constructor injection in `AuthGate`) gets wrapped in a `ChangeNotifierProvider`/`Provider.value` as a quick migration shim while new band/track/setlist state is built natively in Provider/Riverpod. Now two different reactivity mechanisms both claim to represent "is the user logged in," and a 403 auto-logout event may update one but not trigger a rebuild in a widget subscribed via the other path, or double-rebuilds occur because both the old `ListenableBuilder` and the new provider watch the same underlying object.

**Why it happens:**
Migrating "the thing that already works" (auth) feels risky, so teams often leave `AuthSession` untouched and only migrate *new* screens to Provider/Riverpod, planning to migrate auth "later." This is exactly the widely-documented Provider→Riverpod migration trap: it's rarely a mechanical drop-in, because Riverpod's provider graph is global/declarative while Provider is scoped to the widget tree, and mixing the two mental models around the single most safety-critical piece of state (auth) is the highest-risk place to do it.

**How to avoid:**
Pick one interim rule and apply it consistently for the whole migration window: either (a) migrate `AuthSession` itself as step one, exposing auth state through the new library from day one, so every subsequently-built feature has one consistent way to read "am I logged in" and "what's my token" — or (b) explicitly keep `AuthSession` on `ChangeNotifier`/constructor injection for the full milestone and only use Provider/Riverpod for the new band/track/setlist state, with a documented single bridge point (e.g., one `Provider.value` wired once at the root) rather than ad hoc wrapping in multiple places. Do not do both migrated-and-not-migrated auth access patterns across different screens.

**Warning signs:**
- Some screens read auth state via `context.watch<AuthSession>()`/Riverpod provider, others still receive `authSession` via constructor.
- 403 auto-logout is manually verified working in one screen but not others.
- No single PR/commit "migrates auth"; it's touched piecemeal across multiple feature PRs.

**Phase to address:**
State-management migration phase — should be resolved explicitly, before or alongside the first Provider/Riverpod-based feature screen, not left as an implicit side effect of adding new screens.

---

### Pitfall 8: Choosing `ChangeNotifierProvider` as the "easy" Riverpod migration path creates immediate tech debt

**What goes wrong:**
Because `AuthSession`/`ThemeController` are already `ChangeNotifier`/`ValueNotifier`, the path of least resistance when adopting Riverpod is to wrap them in `ChangeNotifierProvider` and call the migration "done." As of Riverpod 3, `ChangeNotifierProvider` (along with `StateProvider`/`StateNotifierProvider`) is explicitly legacy — kept only as a compatibility bridge — with the documented recommendation to use `Notifier`/`AsyncNotifier` instead. Building new (non-legacy) code on top of a legacy compatibility shim means re-migrating twice: once from ChangeNotifier→ChangeNotifierProvider, then again from ChangeNotifierProvider→Notifier/AsyncNotifier.

**Why it happens:**
`ChangeNotifierProvider` is the shortest bridge from the current codebase and shows up in almost every "Provider to Riverpod" migration tutorial as the first step, without always flagging that it's meant to be transitional, not a destination.

**How to avoid:**
If choosing Riverpod, target `Notifier`/`AsyncNotifier` directly for any *new* state (band/track/setlist repositories, cache-backed lists) rather than routing through `ChangeNotifierProvider`. Reserve `ChangeNotifierProvider` (if used at all) strictly as a temporary bridge for the existing `AuthSession`/`ThemeController` classes during the transition window, with a follow-up task to retire it — don't build new features against it.

**Warning signs:**
- New repository/cache-backed providers are implemented as `ChangeNotifier` + `ChangeNotifierProvider` "to match the existing style."
- Async loading/error states are hand-rolled with nullable fields instead of Riverpod's `AsyncValue`.

**Phase to address:**
State-management migration phase (pick the target Riverpod API surface up front, if Riverpod is the chosen library).

---

### Pitfall 9: Testing regressions from breaking constructor injection without replacing it

**What goes wrong:**
`ARCHITECTURE.md` explicitly notes the current constructor-injection pattern exists partly *because* "this makes testing easier." Once band/track/setlist screens depend on Provider/Riverpod for state, existing and new widget tests either (a) fail to compile/run because a `ProviderScope`/`Provider` ancestor is missing in the test harness, or (b) "pass" but are actually hitting the real `ApiClient`/network layer because no override/mock was registered, making tests slow, flaky, or silently no-ops in CI.

**Why it happens:**
Provider/Riverpod require every widget test to pump the widget inside the right ancestor (`ProviderScope` with `overrides`, or `MultiProvider`) — this is easy to forget when copy-pasting `testWidgets` boilerplate from before the migration, and Flutter widget tests don't fail loudly when async network calls hang; they just time out or leave the test in a loading state that passes for the wrong reason.

**How to avoid:**
Standardize one test helper (e.g., a `pumpCadenceApp(tester, overrides: [...])` function) that always wires the required `ProviderScope`/mock repositories, and require every new band/track/setlist test to use it. For Riverpod, override repository/cache providers with fakes in every test — never let a widget test reach the real `ApiClient`. Add this helper in the same phase the migration happens, not retroactively.

**Warning signs:**
- Widget tests take noticeably longer after the migration (real network calls in test runs).
- New tests are copy-pasted from pre-migration tests and fail with "No ProviderScope found"/"could not find Provider above this widget" errors.
- CI test suite has flaky failures correlated with network timeouts.

**Phase to address:**
State-management migration phase (build the test harness alongside the migration itself) and each subsequent CRUD phase (enforce use of the harness).

---

## v1.1 UI Improvements: New Pitfalls

**Focus:** Adding cache-first-to-online-first flip, ownership gates removal, ownership mutations, and search integration to the existing Riverpod + Hive architecture.

### Pitfall 10: In-Flight Fetch Overwrites Local Mutation During Online-First Transition

**What goes wrong:**
The app flips from cache-first (return cached data immediately, refresh in background) to online-first (always fetch fresh when online, fall back to cache when offline). The refactoring changes provider `build()` methods but doesn't update the `_version` guard logic. Result: when transitioning from offline to online, a provider returns cache immediately, kicks off a background fetch, and a concurrent user mutation (e.g., `updateBand()`) succeeds on the server but gets silently overwritten in the UI when the background fetch completes with stale data.

**Root cause:** The `_version` guard is designed to prevent **concurrent** background refreshes from clobbering local edits. But during the online-first transition, the cache read and the user mutation can race without proper sequencing:
1. `build()` → cache hit → return cached data
2. `_refresh()` launched (captures `_version = 0`)
3. User taps Edit Band → mutation captures same `_version = 0`, updates UI immediately
4. Background fetch completes **before** the mutation's network request, checks `if (_version == capturedVersion)` → passes (both are 0)
5. Stale data overwrites the local edit in state

**Consequences:**
- User edits appear in the UI, then silently revert when a background refresh completes
- "My edit just disappeared" — violates user trust
- Especially common after app cold-start (lots of cache hits) or on slow networks

**Prevention:**
1. **Stash in-flight mutations:** Before launching a background refresh, check if there's an in-flight mutation request. If one exists, wait for it to complete before refreshing.
   ```dart
   Future<void>? _inFlightMutation;
   
   Future<void> updateBand(String bandId, String newName) async {
     _inFlightMutation = _doUpdate(bandId, newName);
     await _inFlightMutation;
     _inFlightMutation = null;
   }
   
   Future<void> _refresh() async {
     if (_inFlightMutation != null) {
       await _inFlightMutation;
       return; // Mutation already refreshed state
     }
     // ... proceed with background fetch
   }
   ```

2. **Bump `_version` synchronously at mutation start:** Increment before any await, so the background refresh's captured version is always stale by the time it checks.
   ```dart
   Future<void> updateBand(String bandId, String newName) async {
     _version++; // Bump immediately
     await ref.read(publicApiProvider).updateBand(bandId, newName);
     // ... update state
   }
   ```

3. **Test mutation + refresh race:** Add an integration test with `Future.delayed` to stall the background fetch while a mutation is in-flight. Verify the mutation survives the refresh.

**Detection:**
- Enable state-change logging in `_refresh()` and mutation methods; watch for mutations being overwritten by fetches
- QA: edit a band immediately after app launch (cache hit + background refresh in flight) and verify the change persists
- Test: mock the network to have a 2-second fetch latency; initiate a mutation while a refresh is in progress

**Phase:** v1.1 Feature Dev (address during online-first flip)

---

### Pitfall 11: Removing UI Gate Without Removing Implicit Permission Checks Elsewhere

**What goes wrong:**
The schema now allows any band member to edit/delete bands, tracks, and setlists (not just owners). You remove the `if (isOwner == true)` UI gates from Edit/Delete buttons. However, other parts of the architecture still assume owner-only writes:
- Mutation endpoint names or doc comments still say "owner-only"
- Cache invalidation logic skips refreshing certain data after a non-owner mutation, assuming it couldn't have happened
- Some screens still render member-vs-owner UI differently based on hardcoded assumptions

**Consequences:**
- Non-owner edits succeed on the server but don't invalidate the cache
- Global Tracks/Setlists tabs show stale data after a non-owner mutation
- Inconsistency: server reflects the change, app's UI/cache doesn't

**Prevention:**
1. **Audit all mutation endpoints:** Grep for "owner" comments/variable names; update any that assume owner-only behavior.
2. **Expand cache invalidation:** Any mutation (band, track, setlist) should invalidate global cross-band lists and home page, regardless of who made the mutation.
   ```dart
   // Always invalidate, not conditionally
   ref.invalidate(bandsListDataProvider);
   ref.invalidate(tracksListDataProvider); // Global list
   ref.invalidate(setlistsListDataProvider); // Global list
   ```

3. **Test non-owner mutations:** Add integration tests where a non-owner edits a band/track/setlist and verify the global lists reflect it immediately.

4. **Check UI rendering:** Confirm screens no longer special-case ownership for edit/delete visibility.

**Detection:**
- Static: grep for `isOwner` usage; each occurrence should be a legitimate gate (e.g., "remove member" is owner-only, but "edit band name" is not)
- Dynamic: run tests; failures after removing UI gates indicate implicit assumptions elsewhere
- QA: invite a non-owner to edit something and verify it appears in another member's app without manual refresh

**Phase:** v1.1 Feature Dev (address when removing ownership gates)

---

### Pitfall 12: Transfer Ownership Without Invalidating Current Session's Owner Status

**What goes wrong:**
User transfers band ownership to Alice via `POST /api/band/{bandId}/transfer-ownership`. The API call succeeds, and the app updates the band detail cache with the new `ownerId`. However, the user's `ProfileData` (from `GET /api/me`) is not invalidated. The UI still shows the old profile (user was an owner), and any owner-gated checks that read profile data fail silently.

**Root cause:** Ownership mutations only invalidate the local band cache, not the global profile provider. If the profile API returns an `isOwnerOfBands` flag or a list of owned-band IDs, those are now stale.

**Consequences:**
- Stale user session: app believes the user still owns a band after transferring it
- Future permission checks based on profile data fail silently
- User confusion: "I transferred ownership but I can still edit?"

**Prevention:**
1. **Always invalidate profile after ownership mutations:**
   ```dart
   Future<void> transferOwnership(String bandId, String newOwnerId) async {
     await ref.read(publicApiProvider).transferOwnership(bandId, newOwnerId);
     ref.invalidate(bandDetailDataProvider(bandId));
     ref.invalidate(bandsListDataProvider);
     ref.invalidate(profileDataProvider); // Critical
   }
   ```

2. **Centralize ownership mutations:** Create a mixin or extension that ensures every ownership-touching mutation invalidates both the band cache AND the profile cache.

3. **Test permission flips:** After transfer-ownership, attempt a future owner-only operation; confirm the server rejects it with 403 (and the client handles it correctly).

**Detection:**
- Add logging to `ProfileData.build()` to track invalidations vs. loads
- After transfer-ownership, check that the profile provider's state is `AsyncLoading` or fresh `AsyncData`, not stale `AsyncData`
- QA: transfer ownership, then attempt an owner-only action; confirm the server rejects with 403

**Phase:** v1.1 Feature Dev (address during ownership mutation implementation)

---

### Pitfall 13: Search Field Unimplemented on Backend During Transition

**What goes wrong:**
v1.1 extends `publicapi.yml` to add `searchQuery` to `ListBandTracks` and `ListSetlists` endpoints. The client implements the search UI immediately (searchable setlist track picker). But the backend hasn't implemented the field yet. During the transition:

1. Client sends `POST /api/band/{bandId}/track/list` with `{ searchQuery: "Intro" }`
2. Server doesn't recognize the field: either silently ignores it (returns all tracks) or rejects with 400
3. User sees all 50 tracks when typing "Intro" (search looks broken) or the app crashes on 400

**Root cause:** Schema extends faster than the backend. The client assumes the field exists and is honored.

**Consequences:**
- Search UI appears broken (no filtering)
- App crashes if backend returns 400 with strict validation
- User frustration; low confidence in the feature

**Prevention:**
1. **Graceful degradation:** Check API version/capability before sending `searchQuery`. Omit the field if not supported.
   ```dart
   final body = {
     'bandId': bandId,
     if (searchQuery != null && _supportsSearch) 'searchQuery': searchQuery,
   };
   ```

2. **Version negotiation:** Implement a capability check on app startup (e.g., `GET /api/version` or a feature flag in the homepage response). Cache the result.

3. **Catch 400 explicitly:** If the backend may reject the request, fall back gracefully:
   ```dart
   try {
     return await listBandTracks(bandId, searchQuery: searchQuery);
   } on ApiException catch (e) {
     if (e.statusCode == 400) {
       return await listBandTracks(bandId); // No search
     }
     rethrow;
   }
   ```

4. **Test the transition:** Add a test double simulating the backend without search support. Verify the app degrades gracefully.

5. **Handle empty strings:** Confirm `searchQuery: ""` returns all results, not an error.

**Detection:**
- Static: check `publicapi.yml` for `searchQuery`; verify client handles missing-field 400s
- Dynamic: test against a backend that doesn't support the field; confirm no crash
- QA: type into the search field; if the backend doesn't support it, verify the UI degrades gracefully (shows all results or disables search)

**Phase:** v1.1 Feature Dev (address during search implementation)

---

### Pitfall 14: Cache Invalidation Incomplete During Online-First Flip

**What goes wrong:**
The app flips from cache-first to online-first. Existing cache invalidation logic (built around staleness assumptions) is not updated. Example: A provider invalidates `bandsListDataProvider` after creating a band. In cache-first mode, invalidation triggered a silent background refresh. In online-first mode, invalidation triggers an **immediate** fetch, which may show a loading spinner where it previously showed stale data. Or: a provider invalidates but doesn't re-validate, leaving a gap.

**Consequences:**
- Frequent loading spinners during otherwise-fast UX flows (e.g., create band → navigate to it)
- Inconsistent invalidation: some mutations invalidate, others don't
- User frustration with perceived slowness

**Prevention:**
1. **Audit all invalidation calls:**
   ```bash
   grep -r "ref.invalidate" lib/providers/ --include="*.dart"
   ```
   Confirm each is still the right behavior in online-first mode.

2. **Prefer targeted cache updates:** Instead of invalidating (forces re-fetch), update the cache in place when possible:
   ```dart
   // Before (cache-first):
   Future<void> createBand(String name) async {
     final newBand = await ref.read(publicApiProvider).createBand(name);
     ref.invalidate(bandsListDataProvider); // Forces re-fetch
   }

   // After (online-first):
   Future<void> createBand(String name) async {
     final newBand = await ref.read(publicApiProvider).createBand(name);
     ref.read(bandsListDataProvider.notifier).addBand(newBand);
   }
   ```

3. **Test online-first UX:** With network present, mutations shouldn't trigger unnecessary loading spinners. Measure time to navigate after a mutation; if >1s, a cache invalidation may be forcing an unnecessary re-fetch.

**Detection:**
- QA: create a band, track, or setlist and measure time to navigate to it. Should be <500ms with fast network; if >1s, a cache invalidation is forcing an unnecessary re-fetch.

**Phase:** v1.1 Feature Dev (address during online-first flip)

---

### Pitfall 15: Cache Behavior Flip Without Consistent Refetch Guards

**What goes wrong:**
The app flips from cache-first to online-first across **all** data providers. But only **some** providers are updated; others continue with cache-first behavior. Result: inconsistency. `BandsListData` fetches fresh when online, but `ProfileData` still returns cache and refreshes in background. User edits their profile (name, password), and the profile provider's background refresh overwrites the change before the mutation request completes.

**Root cause:** The cache-behavior flip is a **systematic** change across 5+ providers. If even one is missed, it continues with the old cache-first behavior.

**Consequences:**
- Some screens show stale data indefinitely (the ones still using cache-first)
- Others show fresh data (the ones flipped to online-first)
- User can't predict whether data is fresh or stale
- Especially problematic for mutation results

**Prevention:**
1. **Implement an online-first mixin or base class:**
   ```dart
   mixin OnlineFirstProvider {
     bool shouldFetchFresh(WidgetRef ref) => ref.watch(isOnlineProvider);
     Future<T?> loadWithOfflineFallback<T>({
       required Future<T?> Function() readCache,
       required Future<T> Function() fetchFresh,
     }) async {
       if (!shouldFetchFresh(ref)) return await readCache();
       return await fetchFresh();
     }
   }
   ```

2. **Document the pattern:** Add a comment at the top of each provider explaining its cache behavior (online-first, offline fallback).

3. **Test all providers offline:** Create a test scenario where `isOnlineProvider` returns false. Verify all data providers return cached data (or AsyncError if there's no cache).

4. **Audit the migration:** After flipping all providers, grep for `cache-first` or `_refresh()` patterns to catch any that weren't updated.

**Detection:**
- Static: audit all `lib/providers/*.dart` files; confirm each implements online-first (checks `isOnlineProvider` or similar)
- Dynamic: toggle offline mode and verify all screens show consistent data (either all cached or all error states)

**Phase:** v1.1 Feature Dev (address during online-first flip)

---

### Pitfall 16: Ownership Mutations Without Refreshing Sibling Member Lists

**What goes wrong:**
When transferring ownership, the band's `members` list in the cache may include the previous owner with the old role. The mutation succeeds, but the member list shown on the detail screen is stale: it still shows Alice as an owner, not Bob.

**Root cause:** The API's `GET /api/band/{bandId}` returns both `ownerId` (top-level) and `members` list (nested, with each member's `role`). If the backend update doesn't atomically update both, or if the client doesn't re-fetch soon enough, the list becomes inconsistent.

**Consequences:**
- Member list shows the wrong owner role
- UI can render owner-gated actions for the wrong person
- User confusion

**Prevention:**
1. **Always re-fetch the full band detail after ownership mutations:**
   ```dart
   Future<void> transferOwnership(String bandId, String newOwnerId) async {
     await ref.read(publicApiProvider).transferOwnership(bandId, newOwnerId);
     ref.invalidate(bandDetailDataProvider(bandId)); // Force re-fetch
     ref.invalidate(bandsListDataProvider);
   }
   ```

2. **Validate member roles in tests:** After transferring ownership, verify the band detail's `members` list reflects the new owner's role correctly.

**Detection:**
- QA: transfer ownership and check the member list; confirm the new owner's role is updated immediately
- Test: mock the API to return inconsistent `ownerId` and `members` roles; verify the app handles it gracefully

**Phase:** v1.1 Feature Dev (address during ownership mutation implementation)

---

### Pitfall 17: Riverpod Invalidation Cascade Without Explicit Family Dependencies

**What goes wrong:**
After implementing ownership mutations, you invalidate `bandDetailDataProvider(bandId)`. But you forgot that this is a family provider — invalidating a specific key doesn't invalidate all instances. So if the user is an owner of two bands and transfers ownership of one, the other remains stale.

**Root cause:** Riverpod family providers require explicit key invalidation. Invalidating the base provider doesn't cascade.

**Prevention:**
1. **Invalidate the family base if you need all instances:**
   ```dart
   // Invalidates ALL instances of bandDetailDataProvider
   ref.invalidate(bandDetailDataProvider);
   ```

2. **Be explicit about which instances to invalidate:**
   ```dart
   // Only invalidate the specific band
   ref.invalidate(bandDetailDataProvider(bandId));
   
   // If you need to invalidate all bands:
   for (final band in ref.watch(bandsListDataProvider).value ?? []) {
     ref.invalidate(bandDetailDataProvider(band['id'] as String));
   }
   ```

**Detection:**
- Add logging to provider `build()` methods: "Provider built for key: $key"
- After an ownership mutation, check logs; confirm all affected instances are re-built

**Phase:** v1.1 Feature Dev (address during ownership mutation implementation)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Reuse API DTO class as the Drift/sqflite row type | Faster to wire first cached screen | Breaks in 3 places on next schema change (Pitfall 1) | Never for band/track/setlist; maybe acceptable for a throwaway spike |
| Wrap `AuthSession` in `ChangeNotifierProvider` and stop there | Fastest visible "migration done" | Builds on a legacy-marked Riverpod API; second migration needed later (Pitfall 8) | Only if Provider (not Riverpod) is the final chosen library |
| Skip cache invalidation on mutations, rely on next `GET` to refresh | Ships CRUD faster | Users see stale data offline right after their own edits (Pitfall 4) | Never — this directly undermines the milestone's core value prop |
| Delete-and-reinstall app instead of writing DB migrations during dev | Saves time short-term | No migration muscle memory; first real migration is unpracticed and risky (Pitfall 5) | Only in the very first days before any real users/testers install a build |
| Use `autoDispose` everywhere "because it's the Riverpod default" | Avoids thinking about lifetimes upfront | Defeats caching purpose on IndexedStack tab switches (Pitfall 6) | Fine for screen-local form/UI state, never for cached list/detail data |
| Don't update provider caching behavior during online-first flip | Faster refactoring | Some providers cache-first, others online-first; inconsistent stale data (Pitfall 15) | Never — consistency is essential for user trust |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| sqflite / Drift on multi-platform builds | Cache code compiles unconditionally into the web build (sqflite has no web support; Drift needs a different backend on web) | Gate the cache layer behind the same conditional-import pattern already used for `http_client_factory_*.dart`; web build gets a no-op/stub cache implementation this milestone |
| connectivity_plus | Treating "has a network interface" as "has internet access" — device on Wi-Fi with no internet reports "connected," so the app tries a live fetch, fails, and shows a generic error instead of falling back to cache | Combine interface-level connectivity with a lightweight reachability check (or simply: always attempt the network call and fall back to cache on failure, rather than gating on connectivity status alone) |
| `ApiClient` 403 auto-logout + cache | 403-triggered `signOut()` clears the token but leaves cached band/track/setlist data behind for the next login | Wire cache clearing into the same `signOut()` path used by both manual logout and 403 auto-logout (see Pitfall 2) |
| Riverpod `ProviderScope` placement | `ProviderScope` added below `AuthGate` or per-screen instead of once at the true app root | Single `ProviderScope` wraps `CadenceApp` (or above it in `main.dart`), matching the existing single-root DI pattern already used for `AuthSession`/`ApiClient` |
| Online-first + in-flight mutations | Flipping to online-first without updating `_version` guard logic or adding `_inFlightMutation` stashing | Implement in-flight mutation guards and/or synchronous `_version` bumping before the online-first flip (Pitfall 10) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Parsing large cached JSON/DB result sets synchronously on the UI thread | Jank/frame drops when opening a band with many tracks/setlists after being offline | Keep decode work in the DB layer's async calls; use `compute()`/isolate for genuinely large payloads only if profiling shows it's needed | Noticeable once a band has on the order of hundreds of tracks; low risk at typical band-repertoire scale but worth a note |
| Unbounded local cache growth | App storage grows every time any band/track/setlist is viewed, never pruned | Evict cache rows for bands the user is no longer a member of; consider a simple TTL/last-accessed prune on app start | Matters more for users who join/leave many bands over time than for a single steady band |
| `IndexedStack` + per-tab providers all fetching on cold start | All four tabs' data (and their providers) load simultaneously at app launch even though only one tab is visible | Fetch lazily on first build of each tab's provider (still keep-alive afterward, per Pitfall 6), not eagerly at app root | Already flagged in `CONCERNS.md`; will get worse once tabs have real cache+network fetches instead of placeholders |
| Online-first invalidations trigger unnecessary re-fetches | Frequent loading spinners during UX flows (create → navigate) | Prefer targeted cache updates over full invalidations when mutation response contains the new data (Pitfall 14) | Noticeable after the online-first flip if not addressed |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|-----------|
| Storing cached band/track/setlist data in plaintext sqflite/Drift while auth token uses `flutter_secure_storage` | Inconsistent security posture — repertoire data is lower-sensitivity than the token, but on a lost/shared device other band members' data is exposed without at-rest protection | Acceptable to leave cache unencrypted for read-only, low-sensitivity repertoire data *if explicitly decided*, but don't accidentally cache anything auth-adjacent (e.g., don't let a `/api/me` response with more fields than expected get cached wholesale without review) |
| Cache surviving `signOut()` and being readable by the next logged-in user on a shared device | Cross-user data leakage (see Pitfall 2), which is also a privacy issue for band members' data | Clear cache on logout, as prevention for Pitfall 2 already covers |
| Profile cache stale after ownership transfer | User still sees ownership status even though they transferred it; future permission checks fail silently | Invalidate profile provider after ownership mutations (Pitfall 12) |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| No distinction between "offline, showing cache" and "online, request failed" | User can't tell if a blank/error screen means "no signal" (expected, cache should show instead) or "something is actually broken" | Always attempt cache-first or cache-fallback display; reserve error UI for the case where there's no cache to fall back to |
| Cached data shown with no recency indicator | User at a gig doesn't know if the setlist shown reflects a same-day change by a bandmate | Show "last updated Xm/h ago" per screen/entity, per Pitfall 3 |
| Mutation UI (edit/delete) available while offline with no clear disabled/explanatory state | User taps "Save" on an edit while offline, gets a confusing network error instead of understanding upfront that edits need connectivity | Since mutations require connectivity this milestone, disable or clearly label mutation actions when offline, rather than letting the user attempt and fail |
| Search field appears broken (returns all results) during backend transition | User types into search, sees everything, thinks the feature doesn't work | Implement version check or graceful degradation for unimplemented search field (Pitfall 13) |

## "Looks Done But Isn't" Checklist

- [ ] **Offline caching:** Often missing per-band/per-user cache scoping — verify switching bands or logging in as a different user doesn't show stale/wrong data (Pitfall 2)
- [ ] **Offline caching:** Often missing cache invalidation on successful mutations — verify editing a track online, then going offline, shows the edit (Pitfall 4)
- [ ] **Offline caching:** Often missing schema migration path — verify the app upgrades cleanly from schema v1 to v2 without crashing or wiping local data (Pitfall 5)
- [ ] **State management migration:** Often leaves auth state on two competing reactivity mechanisms — verify 403 auto-logout correctly propagates to every screen, old and new (Pitfall 7)
- [ ] **State management migration:** Often breaks widget tests silently — verify tests actually mock/override providers rather than hitting real `ApiClient` (Pitfall 9)
- [ ] **Offline UX:** Often missing a visible "stale/offline" indicator — verify a manual airplane-mode test shows an explicit signal, not data that looks indistinguishable from live (Pitfall 3)
- [ ] **Online-first flip:** All providers updated consistently to online-first (not a mix of online-first and cache-first); no in-flight mutation race conditions (Pitfalls 10, 15)
- [ ] **Ownership gates removed:** UI gates gone but cache invalidation and permission checks updated everywhere (Pitfall 11)
- [ ] **Ownership mutations:** Profile provider invalidated after transfer-ownership or rotate-invite-code (Pitfall 12)
- [ ] **Search implementation:** Backend-unimplemented field handled gracefully with version check or fallback (Pitfall 13)

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| Collapsed DTO/cache/domain model (Pitfall 1) | MEDIUM | Introduce mapper functions and split the class retroactively; touches every call site but is mechanical, not a rewrite |
| Cache not scoped per user/band (Pitfall 2) | LOW–MEDIUM | Add `bandId`/`userId` columns via a schema migration (exercises Pitfall 5's discipline), backfill or clear existing cache once |
| Missing stale-data UX (Pitfall 3) | LOW | Additive UI work — add a `cachedAt` field to the domain model and a banner/badge widget; no architectural change needed if the cache layer already exists |
| Mutations not invalidating cache (Pitfall 4) | LOW–MEDIUM | Add cache-write calls to existing mutation methods; straightforward if the repository pattern from Pitfall 1 was followed, painful if screens call `ApiClient` directly |
| Missing schema migrations discovered post-launch (Pitfall 5) | HIGH | Requires either a destructive migration (data loss, acceptable pre-1.0) or a careful staged migration; much cheaper to prevent than fix after real users have data |
| Two competing auth state sources (Pitfall 7) | MEDIUM–HIGH | Requires picking one and re-wiring every screen that reads auth state the "wrong" way; cheaper the earlier it's caught |
| In-flight mutation race condition (Pitfall 10) | MEDIUM | Add `_inFlightMutation` guard or synchronous `_version` bump; touches mutation methods but is mechanical |
| Ownership gate removal without full audit (Pitfall 11) | MEDIUM | Audit all cache invalidation, permission checks, and UI logic; update as needed; add non-owner mutation tests |
| Profile stale after ownership transfer (Pitfall 12) | LOW | Add `ref.invalidate(profileDataProvider)` to ownership mutation methods; mechanical fix |
| Search field unimplemented transition (Pitfall 13) | LOW | Add version check or 400-handling fallback; toggle-able feature gate if needed |
| Cache invalidation over-aggressive (Pitfall 14) | LOW | Replace full invalidations with targeted updates where mutation response has new data; touches mutation methods |
| Inconsistent cache-first/online-first mix (Pitfall 15) | MEDIUM | Audit all providers; ensure all use online-first (or all use cache-first, but that's not the target); systematic refactoring |
| Family provider invalidation incomplete (Pitfall 17) | LOW | Ensure ownership mutations invalidate both the specific band detail AND the bands list; mechanical fix |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| Collapsed DTO/cache/domain models | Cache-layer foundation phase | Code review: DTO, cache row, and domain model are distinct types with explicit mappers |
| Cache not scoped/cleared per user+band | Cache-layer foundation phase | Test: log out → log in as different user → previously cached band data not visible |
| Stale-cache UX indistinguishable from fresh | Offline-read-integration phase | Manual test: airplane mode shows explicit stale/offline indicator with timestamp |
| Mutations don't invalidate cache | Band/track/setlist CRUD phase | Test: edit online → go offline → edited value is what's shown |
| Skipped/destructive schema migrations | Cache-layer foundation phase | Test: construct DB at prior schema version, run upgrade, assert data preserved |
| `autoDispose` fighting cache goal | State-management migration phase | Manual test: switch tabs repeatedly, verify no redundant network calls/loading flicker for recently-viewed data |
| Two competing auth state sources | State-management migration phase | Test: trigger 403 from any screen, verify all screens (old and new state-management style) reflect logout |
| `ChangeNotifierProvider` used for new state | State-management migration phase | Code review: new band/track/setlist providers use `Notifier`/`AsyncNotifier` (if Riverpod chosen), not `ChangeNotifierProvider` |
| Testing regressions from missing provider overrides | State-management migration phase | CI: widget test suite run time doesn't regress; no test reaches real `ApiClient` (verify via a deliberately-broken base URL in test config) |
| In-flight mutation race (Pitfall 10) | v1.1 Feature Dev (online-first flip) | Test: mutation + background refresh race; verify mutation survives refresh |
| Ownership gate removal without full audit (Pitfall 11) | v1.1 Feature Dev (gate removal) | Test: non-owner edits band/track/setlist; verify global lists update without manual refresh |
| Profile stale after ownership transfer (Pitfall 12) | v1.1 Feature Dev (ownership mutations) | Test: transfer ownership; attempt owner-only action; server should reject with 403 |
| Unimplemented search field (Pitfall 13) | v1.1 Feature Dev (search implementation) | Test against backend without search support; verify graceful degradation |
| Cache invalidation over-aggressive (Pitfall 14) | v1.1 Feature Dev (online-first flip) | QA: mutation → navigate; measure time; should be <500ms on fast network |
| Inconsistent cache-first/online-first (Pitfall 15) | v1.1 Feature Dev (online-first flip) | Test: toggle offline mode; verify all screens show consistent data (cached or error) |
| Family invalidation incomplete (Pitfall 17) | v1.1 Feature Dev (ownership mutations) | Test: transfer ownership of two bands; verify both are refreshed |

## Sources

- [Offline-First Capabilities in Flutter — Medium](https://medium.com/@aloaderemi1/offline-first-flutter-29b24dbf4272) — MEDIUM confidence (community blog)
- [Integrating Local Databases in Flutter Using Drift — Vibe Studio](https://vibe-studio.ai/insights/integrating-local-databases-in-flutter-using-drift) — MEDIUM confidence
- [Building Offline-First Flutter Apps with Drift — The Complete 2026 Guide — Flutter Studio](https://flutterstudio.dev/blog/offline-first-flutter-drift.html) — MEDIUM confidence
- [Offline-First Apps: Caching Strategies with Hive and Drift — Vibe Studio](https://vibe-studio.ai/insights/offline-first-apps-caching-strategies-with-hive-and-drift-in-flutter) — MEDIUM confidence
- [Offline-First Architecture in Flutter, Part 1 — DEV Community](https://dev.to/anurag_dev/implementing-offline-first-architecture-in-flutter-part-1-local-storage-with-conflict-resolution-4mdl) — MEDIUM confidence
- [Migrating from 2.0 to 3.0 — Riverpod official docs](https://riverpod.dev/docs/3.0_migration) — HIGH confidence (official)
- [From `ChangeNotifier` — Riverpod official docs](https://riverpod.dev/docs/migration/from_change_notifier) — HIGH confidence (official)
- [Provider vs Riverpod — Riverpod official docs](https://riverpod.dev/docs/from_provider/provider_vs_riverpod) — HIGH confidence (official)
- [flutter_riverpod changelog — pub.dev](https://pub.dev/packages/flutter_riverpod/changelog) — HIGH confidence (official package registry)
- [Flutter Riverpod 3 Complete Migration Guide — Flutter Studio](https://flutterstudio.dev/blog/flutter-riverpod-3-complete-migration-guide.html) — MEDIUM confidence
- [Provider to Riverpod AsyncNotifier: A Real Migration — DEV Community](https://dev.to/devsnake/provider-to-riverpod-asyncnotifier-a-real-migration-with-before-after-code-ff5) — MEDIUM confidence
- [Detecting Offline Status in Flutter — Medium](https://mobterest.medium.com/detecting-offline-status-in-flutter-a-guide-to-network-connectivity-monitoring-6025463c815a) — MEDIUM confidence
- [Flutter Connectivity Done Right — ASOasis](https://asoasis.tech/articles/2026-04-24-2053-flutter-connectivity-check-network-status/) — MEDIUM confidence
- This repository's `.planning/codebase/ARCHITECTURE.md`, `PROJECT.md`, and v1.0 audit findings — HIGH confidence (primary source, this codebase)
- This repository's existing providers (`bands_provider.dart`, `tracks_provider.dart`, `setlists_provider.dart`, `profile_provider.dart`) and cache service (`cache_service.dart`) — HIGH confidence (codebase implementation)

---
*Pitfalls research for: Flutter offline read-caching + Provider/Riverpod migration + v1.1 UI Improvements (Cadence)*
*Last updated: 2026-08-20 (v1.1 additions)*
