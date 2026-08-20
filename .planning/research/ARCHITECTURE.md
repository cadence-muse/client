# Architecture Patterns: v1.1 UI Improvements Integration

**Project:** Cadence (v1.1 milestone)  
**Researched:** 2026-08-20  
**Focus:** Integration of 7 changes into existing Riverpod+Hive+ApiClient architecture  
**Confidence:** HIGH (pattern leverages existing code, no new infrastructure)

---

## Executive Summary

The v1.1 changes integrate cleanly with the existing Riverpod+Hive foundation, requiring no rewrite of the provider layer's interface or Hive schema. The cache-first pattern flips to online-first at the AsyncNotifier `build()` level (routing through different fetch paths based on connectivity), eliminating the silent background-refresh race condition entirely. The `{data, syncedAt}` envelope persists (offline-fallback text needs the timestamp), but `SyncStatusBadge`'s per-minute timer is removed, replaced by a static "You're offline" banner shown only when offline AND cache exists. Ownership gating simplifies from a tri-state pattern to a dual-gate approach: `_isMemberResolved()` gates the now-any-member mutation UI, while `_isOwnerFromMembers()` (computed from the `role` field in `Band.members[]`) gates owner-only tools. The `searchQuery` parameter integrates as an optional argument to `PublicApi.listBandTracks()`, with local filtering in v1.1 (backend filtering ready for v1.2 without client changes).

---

## Question 1: Cache-First → Online-First Pattern (Clean, Incremental Flip)

### Current State (v1.0): Cache-First with Background Refresh

**Strategy:** Return cached data immediately on cache hit, kick off silent background refresh, fetch inline on miss.

All 10 cache keys use this pattern via `ProfileData`, `BandsListData`, etc.:

```dart
@override
Future<Map<String, dynamic>> build() async {
  final cache = ref.watch(cacheServiceProvider);
  final cached = await cache.readProfile();
  if (cached != null) {
    ref.read(profileSyncedAtProvider.notifier).set(await cache.readProfileSyncedAt());
    unawaited(_refresh()); // Silent background refresh, no error surfaced
    return cached;
  }
  return _fetchAndCache(); // Inline fetch on cache miss
}
```

**Problem:** `_refresh()` captures the provider state at fetch-start, but a local mutation (e.g., `setBands()`) that lands while the fetch is in flight gets silently overwritten by the background-fetched result. Solution (v1.0): `_version` guard — background refresh discards its result if version changed during the fetch (WR-02).

### v1.1 Requirement: Online-First (Always Fetch Fresh When Online)

**Online:** Always fetch fresh from API (no cache shortcut).  
**Offline:** Return cache (or error if cache missing).

**Why the change?** Removes the background-refresh race entirely—no more mutations being silently reverted by a background fetch. Simpler logic, no `_version` guard needed for refreshes.

### Solution: Conditional Routing in `build()`

Add `isOnlineProvider` dependency; route to online or offline path:

```dart
@riverpod
class ProfileData extends _$ProfileData {
  Future<void>? _inFlightRefresh;
  int _version = 0; // Still needed for user-initiated refresh() only

  @override
  Future<Map<String, dynamic>> build() async {
    final isOnline = ref.watch(isOnlineProvider);
    
    if (isOnline) {
      return _fetchAndCacheOnline();
    } else {
      return _loadOfflineCache();
    }
  }

  Future<Map<String, dynamic>> _fetchAndCacheOnline() async {
    // Fetch fresh, cache it, return
    final profile = await ref.read(apiClientProvider).send('GET', '/api/me');
    final data = profile!;
    await ref.read(cacheServiceProvider).writeProfile(data);
    ref.read(profileSyncedAtProvider.notifier).set(DateTime.now());
    return data;
  }

  Future<Map<String, dynamic>> _loadOfflineCache() async {
    // Serve cache or error
    final cached = await ref.read(cacheServiceProvider).readProfile();
    if (cached != null) {
      ref.read(profileSyncedAtProvider.notifier).set(
        await ref.read(cacheServiceProvider).readProfileSyncedAt(),
      );
      return cached;
    }
    throw OfflineNoCacheException('Profile data not available offline');
  }

  // User-initiated refresh (still needed for pull-to-refresh, explicit button)
  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCacheOnline();
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
    }
  }

  // Local mutations still bump _version to guard against future refresh()
  void setProfile(Map<String, dynamic> profile) {
    _version++;
    state = AsyncData(profile);
    unawaited(ref.read(cacheServiceProvider).writeProfile(profile));
    ref.read(profileSyncedAtProvider.notifier).set(DateTime.now());
  }
}
```

**Key changes:**
- Delete `_refresh()` (background silent refresh) — no longer needed.
- Delete all `unawaited(_refresh())` calls from `build()`.
- Add `isOnlineProvider` watch in `build()`.
- Keep `_version` for user-initiated `refresh()` only (guards against a user tapping refresh twice while online, or refreshing offline after going back online).
- Keep `*SyncedAt` providers (needed for offline-fallback banner text).

### Riverpod Invalidation on Connectivity Change

When `isOnlineProvider` changes (device goes online/offline), Riverpod automatically re-runs `build()` on all watching providers. No manual invalidation needed—the `ref.watch(isOnlineProvider)` line in `build()` is the dependency hook.

```dart
// When device goes offline, Riverpod auto-runs all providers watching isOnlineProvider
// build() is called again, this time isOnline == false, so _loadOfflineCache() is used
// When device comes back online, build() is called again, isOnline == true, _fetchAndCacheOnline() is used
```

### Applied to All 10 Cache Keys

| Provider | Cache Key | Template | Notes |
|----------|-----------|----------|-------|
| `ProfileData` | `profile` | Simple | No family |
| `HomepageData` | `homepage` | Simple | No family |
| `BandsListData` | `bands` | List + mutations | `setBands()`, `renameBand()` |
| `BandDetailData(bandId)` | `bands-{id}` | Family + mutations | `updateName()` |
| `TracksData(bandId)` | `tracks-{bandId}` | Family + mutations | Create/update/delete track |
| `SetlistsData(bandId)` | `setlists-{bandId}` | Family + mutations | Create/update/delete setlist |
| `TrackListData` | `tracks-list` | Simple list | Cross-band, no mutations |
| `SetlistListData` | `setlists-list` | Simple list | Cross-band, no mutations |
| `TrackDetailData(trackId)` | `track-{id}` (if exists) | Family + mutations | Verify existence |
| `SetlistDetailData(setlistId)` | `setlist-{id}` (if exists) | Family + mutations | Verify existence |

---

## Question 2: `{data, syncedAt}` Envelope — Simplified Purpose, Unchanged Schema

### Current Envelope (v1.0)

Hive stores `{data, syncedAt}` for all 10 cache keys:

```dart
await _box.put('profile', {
  'data': profileJson,
  'syncedAt': DateTime.now().toIso8601String(),
});
```

Read via sibling `*SyncedAt` providers:

```dart
@riverpod
class ProfileSyncedAt extends _$ProfileSyncedAt {
  @override
  DateTime? build() => null;
  
  void set(DateTime? value) => state = value;
}
```

Used by `SyncStatusBadge` to render "Synced Xm ago" + time-aging timer that updates every minute.

### Answer: Envelope Stays, Purpose Simplifies

**Keep the envelope?** YES. Why:
1. Offline-fallback banner needs timestamp for "Last synced 2h ago" text.
2. Future v1.2 may add offline-write-queue — `syncedAt` marks when cache was last known-good.
3. Zero refactor cost — envelope is already in place.

**What changes?** How it's *used* by the UI:
- **Before (v1.0):** Time-periodic timer refreshes UI every minute, escalating color from onSurfaceVariant to error at 30m.
- **After (v1.1):** Static display, no timer, no escalation. Shown only in offline banner, not as a separate badge on every screen.

### Offline-Fallback Banner (Replaces `SyncStatusBadge`)

New widget `OfflineFallbackBanner` (no timer, no escalation):

```dart
class OfflineFallbackBanner extends StatelessWidget {
  const OfflineFallbackBanner({super.key, required this.syncedAt, required this.isOnline});

  final DateTime? syncedAt;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    if (isOnline || syncedAt == null) {
      return const SizedBox.shrink(); // Hidden if online OR no cache (no syncedAt means no cache)
    }

    final age = DateTime.now().difference(syncedAt);
    final ageText = age.inHours > 0
        ? '${age.inHours}h ago'
        : '${age.inMinutes}m ago';

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You\'re offline. Last synced $ageText.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Key differences from `SyncStatusBadge`:**
- No `Timer.periodic` (no time-aging).
- No warning-color escalation.
- Static text computed once in `build()`.
- Shown/hidden based on `isOnline` && `syncedAt != null`.

### Schema: No Changes Needed

Internal Hive structure stays the same:

```dart
// cache_service.dart — unchanged
await _profileBox.put('profile', {
  'data': freshData,
  'syncedAt': DateTime.now().toIso8601String(),
});
```

No migration. Existing v1.0 cache remains readable.

### Practical Changes Summary

| Aspect | Before (v1.0) | After (v1.1) | Change |
|--------|---------------|--------------|--------|
| Hive envelope | `{data, syncedAt}` | `{data, syncedAt}` | None |
| Envelope reading | Cache hit + background refresh | Offline fallback only | Same code, different trigger |
| `*SyncedAt` providers | 10 per cache key | 10 per cache key | Persist, simpler purpose |
| UI refresh on `syncedAt` change | Time-periodic (timer) + provider invalidation | One-time display (no timer) | Simplifies |
| Staleness badge | `SyncStatusBadge` (10 call-sites) | Removed | Delete widget + 10 removals |
| Offline banner | None | `OfflineFallbackBanner` (10 call-sites) | New widget + 10 additions |

---

## Question 3: Owner-Only UI Gates — Dual-Gate Pattern (Simpler than Tri-State)

### Current Pattern (v1.0): Tri-State Ownership Check

`band_detail_screen.dart`:

```dart
/// Returns true (owner), false (resolved non-owner), or null (profile loading).
static bool? _ownershipStatus(
  AsyncValue<Map<String, dynamic>> profileAsync,
  String? ownerId,
) {
  return profileAsync.maybeWhen(
    data: (profile) => _isOwner(profile['id'] as String?, ownerId),
    orElse: () => null,
  );
}

static bool _isOwner(String? currentUserId, String? ownerId) =>
    currentUserId != null && ownerId != null && currentUserId == ownerId;

// UI: if (isOwner == true) showOwnerButton(); if (isOwner != null) showMemberUI();
```

**Why tri-state?** Avoid rendering owner-only actions before profile loads (null state). Once loaded, definitively true/false.

### v1.1 Schema Changes

1. Mutation endpoints loosen: **any member** can now edit/delete band/track/setlist (not owner-only).
2. New fields: `Band.membersCount`, `Band.members[].id`, `Band.members[].role: 'owner'|'member'`.
3. Owner-only endpoints remain owner-only: `POST /api/band/{id}/rotate-invite-code`, `POST /api/band/{id}/transfer-ownership`.

### Solution: Dual-Gate Pattern (Not a Tri-State Replacement)

**Gate 1: Mutation visibility** → "any authenticated member"

Replace tri-state with simple member-resolved check:

```dart
/// Returns true only if profile is loaded (user is authenticated).
/// Gates edit/delete UI that's now available to any member.
static bool _isMemberResolved(AsyncValue<Map<String, dynamic>> profileAsync) {
  return profileAsync.maybeWhen(
    data: (_) => true, // Profile loaded = user authenticated
    orElse: () => false,
  );
}

// UI: if (_isMemberResolved(profileAsync)) showEditButton();
```

**Gate 2: Owner tools** → "only if current user is band owner"

Compute from `Band.members[].role` (new schema field):

```dart
/// Checks if current user is band owner by looking up their role in members list.
/// Used to gate owner-only tools (rotate-invite-code, transfer-ownership).
static bool? _isOwnerFromMembers(
  AsyncValue<Map<String, dynamic>> profileAsync,
  Map<String, dynamic> band,
) {
  return profileAsync.maybeWhen(
    data: (profile) {
      final userId = profile['id'] as String?;
      if (userId == null) return null;
      
      final members = band['members'] as List? ?? [];
      for (final member in members.cast<Map<String, dynamic>>()) {
        if (member['id'] == userId) {
          return member['role'] == 'owner';
        }
      }
      return null; // User not in members list (shouldn't happen)
    },
    orElse: () => null,
  );
}

// UI: final isOwner = _isOwnerFromMembers(profileAsync, band);
//     if (isOwner == true) showRotateInviteCodeButton();
```

**Why this is better than tri-state:**
- Cleaner semantics: `_isMemberResolved()` is boolean (authenticated), `_isOwnerFromMembers()` is tri-state (computed from role).
- Decouples "user is authenticated" from "user is band owner."
- Reuses schema-provided `role` field instead of comparing IDs.
- Two separate concerns, two separate checks (no confusion).

### Applied to All Mutation Endpoints

| Endpoint | v1.0 Gate | v1.1 Gate | How |
|----------|-----------|-----------|-----|
| `PUT /api/band/{id}` | owner-only | any member | Use `_isMemberResolved()` |
| `DELETE /api/band/{id}` | owner-only | any member | Use `_isMemberResolved()` |
| `PUT /api/track/{id}` | owner-only | any member | Use `_isMemberResolved()` |
| `DELETE /api/track/{id}` | owner-only | any member | Use `_isMemberResolved()` |
| `PUT /api/setlist/{id}` | owner-only | any member | Use `_isMemberResolved()` |
| `DELETE /api/setlist/{id}` | owner-only | any member | Use `_isMemberResolved()` |
| `POST /api/band/{id}/rotate-invite-code` | owner-only | **owner-only** | Use `_isOwnerFromMembers()` (new) |
| `POST /api/band/{id}/transfer-ownership` | owner-only | **owner-only** | Use `_isOwnerFromMembers()` (new) |

### Member-Count Display

Use `Band.membersCount` directly (no gate, purely informational):

```dart
Text('${band["membersCount"] as int} members')
```

### Migration Path

1. Add `_isMemberResolved()` helper to all screens that gate mutations.
2. Add `_isOwnerFromMembers()` helper to screens with owner tools.
3. Replace all `_isOwner(profileId, ownerId)` calls with `_isMemberResolved(profileAsync)`.
4. Delete all references to `Band.ownerId` in UI (stays in schema for future use, not used in v1.1).
5. Keep tri-state logic only for owner-tools gates; remove everywhere else.

---

## Question 4: `searchQuery` Parameter Integration

### Current API Shape (v1.0)

```yaml
/api/track/list:
  post:
    operationId: ListBandTracks
    parameters:
      - name: bandId
        in: query
    requestBody:
      content:
        application/json:
          schema:
            type: object
            properties: {} # Empty
```

### v1.1 Schema Extension

```yaml
/api/track/list:
  post:
    operationId: ListBandTracks
    parameters:
      - name: bandId
        in: query
    requestBody:
      content:
        application/json:
          schema:
            type: object
            properties:
              searchQuery:
                type: string
                description: "Optional substring match filter"
```

### PublicApi.listBandTracks() Update

**Before:**

```dart
Future<List<Map<String, dynamic>>> listBandTracks(String bandId) async {
  final response = await _client.send(
    'POST',
    '/api/track/list',
    queryParams: {'bandId': bandId},
    body: {},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**After (backward-compatible):**

```dart
Future<List<Map<String, dynamic>>> listBandTracks(
  String bandId, {
  String? searchQuery,
}) async {
  final body = <String, dynamic>{};
  if (searchQuery != null && searchQuery.isNotEmpty) {
    body['searchQuery'] = searchQuery;
  }
  
  final response = await _client.send(
    'POST',
    '/api/track/list',
    queryParams: {'bandId': bandId},
    body: body,
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

**Backward-compatible:** Calling `listBandTracks(bandId)` (no search) works; sends empty body, matching v1.0.

### Setlist Track Picker (Local Search in v1.1)

New UI component: `SetlistTrackPickerScreen` with local search (backend filtering added in v1.2).

```dart
class SetlistTrackPickerScreen extends ConsumerStatefulWidget {
  const SetlistTrackPickerScreen({
    super.key,
    required this.bandId,
    required this.onTracksSelected,
  });

  final String bandId;
  final Function(List<String>) onTracksSelected; // Track IDs to add

  @override
  ConsumerState<SetlistTrackPickerScreen> createState() => _SetlistTrackPickerScreenState();
}

class _SetlistTrackPickerScreenState extends ConsumerState<SetlistTrackPickerScreen> {
  final _searchController = TextEditingController();
  final _selected = <String>{};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksDataProvider(widget.bandId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Tracks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search tracks...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _selected.isNotEmpty
                ? () {
                    widget.onTracksSelected(_selected.toList());
                    Navigator.pop(context);
                  }
                : null,
            child: const Text('Add'),
          ),
        ],
      ),
      body: tracksAsync.when(
        data: (tracks) {
          final filtered = _searchQuery.isEmpty
              ? tracks
              : tracks
                  .where((t) =>
                      (t['name'] as String)
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                  .toList();

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final track = filtered[index];
              final trackId = track['id'] as String;
              return CheckboxListTile(
                title: Text(track['name'] as String),
                subtitle: Text(track['duration'] as String? ?? ''),
                value: _selected.contains(trackId),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selected.add(trackId);
                    } else {
                      _selected.remove(trackId);
                    }
                  });
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, st) => Center(
          child: Text('Error: ${error.toString()}'),
        ),
      ),
    );
  }
}
```

**v1.1 approach:** Local filtering in the widget (no provider change needed).

**v1.2+ approach (when backend implements searchQuery):**

Add family parameter to `TracksData`:

```dart
@riverpod
class TracksData extends _$TracksData {
  @override
  Future<List<Map<String, dynamic>>> build(
    String bandId, {
    String? searchQuery,
  }) async {
    // Online/offline logic...
    return ref.read(publicApiProvider).listBandTracks(
      bandId,
      searchQuery: searchQuery,
    );
  }
}

// Widget:
final tracksAsync = ref.watch(
  tracksDataProvider(bandId, searchQuery: _searchQuery),
);
```

But v1.1 doesn't need this; local filtering is sufficient.

---

## Component Boundaries & Integration Summary

### New Components

| Component | Purpose | Type | Status |
|-----------|---------|------|--------|
| `OfflineFallbackBanner` | Static offline banner (replaces SyncStatusBadge) | Widget | New |
| `OfflineNoCacheException` | Error type for offline + no cache | Exception | New |
| `_isMemberResolved()` | Gate any-member mutation UI | Helper | New |
| `_isOwnerFromMembers()` | Gate owner-only tools | Helper | New |
| `SetlistTrackPickerScreen` | Searchable track picker | Screen | New |
| `ChangePasswordScreen` | Change password form | Screen | New |
| `RotateInviteCodeDialog` | Rotate band invite code | Dialog | New |
| `TransferOwnershipDialog` | Transfer band ownership | Dialog | New |

### Modified Components

| Component | Change | Impact |
|-----------|--------|--------|
| All 10 cache providers | Online-first routing + remove `_refresh()` | Logic change, same interface |
| `SyncStatusBadge` | Removed | Delete widget, 10 call-sites |
| `PublicApi.listBandTracks()` | Add optional `searchQuery` param | Backward-compatible |
| All mutation screens | Replace tri-state gating with dual-gate | UI logic change |
| `publicapi.yml` | Add `searchQuery` to `/api/track/list` body | Schema extension (client-side) |

### Removed Components

| Component | Why |
|-----------|-----|
| `SyncStatusBadge` widget | Replaced by `OfflineFallbackBanner` |
| `_refresh()` in all cache providers | Online-first eliminates background-refresh race |
| Tri-state `_isOwner()` pattern (old use) | Replaced by simpler `_isMemberResolved()` + `_isOwnerFromMembers()` |

---

## Feature Build Order & Dependencies

### Phase 1: Foundation (No blocking dependencies)

1. **Change password form** — Isolated, just adds `POST /api/me/password` to PublicApi.
2. **Band member count + role display** — Read-only, uses existing `Band` fields.
3. **Icons display** — Read-only, purely UI improvements.

**Risk:** Low. **Duration:** 1–2 days.

### Phase 2: Gating Refactor (Light risk, foundation for Phase 3)

4. **Remove owner-only gates** — Refactor all gating helpers.
5. **Owner tools** — Add rotate-invite + transfer-ownership endpoints, wire dialogs.

**Risk:** Medium (gating logic touches many screens, but changes are localized). **Duration:** 2–3 days.

### Phase 3: Cache Flip (High-risk, touches all screens)

6. **Online-first cache refactor** — Update all 10 providers, remove `SyncStatusBadge`, add `OfflineFallbackBanner`.

**Risk:** HIGH (every cached screen affected). **Mitigation:** Feature-flag, test offline thoroughly. **Duration:** 3–5 days.

### Phase 4: Search & Polish

7. **Setlist track picker + search** — Add `searchQuery` to PublicApi, build picker screen, local filtering.

**Risk:** Low. **Duration:** 1–2 days.

**Rationale:**
- Phases 1–2 establish patterns and de-risk via smaller changes.
- Phase 3 last (cache-flip is highest-touch, do it when team is confident).
- Phase 4 is independent polish, ship last.

---

## Validation Checklist

**Provider layer:**
- [ ] All 10 cache providers migrated to online-first pattern.
- [ ] `isOnlineProvider` watched in each provider's `build()`.
- [ ] Background `_refresh()` deleted from all providers.
- [ ] `_version` guard retained for user-initiated `refresh()` only.
- [ ] `*SyncedAt` providers unchanged (still track cache timestamps).

**UI layer:**
- [ ] `SyncStatusBadge` widget deleted (10 call-sites).
- [ ] `OfflineFallbackBanner` added (10 call-sites).
- [ ] `OfflineNoCacheException` thrown when offline + no cache.
- [ ] Gating refactored: `_isMemberResolved()` + `_isOwnerFromMembers()`.
- [ ] Owner-only endpoints gated with `_isOwnerFromMembers() == true`.
- [ ] Any-member endpoints gated with `_isMemberResolved() == true`.

**API layer:**
- [ ] `PublicApi.listBandTracks()` accepts optional `searchQuery`.
- [ ] `publicapi.yml` extended with `searchQuery` field.
- [ ] `POST /api/me/password` added to PublicApi.
- [ ] `POST /api/band/{id}/rotate-invite-code` added.
- [ ] `POST /api/band/{id}/transfer-ownership` added.

**Testing:**
- [ ] Offline + cache-hit → data + banner.
- [ ] Offline + cache-miss → error (no banner).
- [ ] Online → always fresh data (no banner).
- [ ] Connectivity flip (offline → online) triggers provider re-run.
- [ ] Member-count and role display correct.
- [ ] Owner tools hidden for non-owners.
- [ ] Mutation buttons visible for any authenticated member.
- [ ] Track picker search filters locally.

---

## Risk & Mitigation

### Risk: Cache Flip Correctness (HIGH)

**Issue:** Online-first flip requires updating all 10 providers. Partial migration (some online-first, some cache-first) causes inconsistency.

**Mitigation:**
- Feature-flag via provider: `useOnlineFirstProvider` (simple bool).
- Migrate all 10 in one commit.
- Test offline via airplane mode + simulator.
- Add debug screen showing cache mode per provider.

### Risk: Offline Banner Logic (MEDIUM)

**Issue:** Banner shown when offline AND cache exists, but not when cache missing. Requires careful state handling.

**Mitigation:**
- `OfflineFallbackBanner` checks `isOnline` and `syncedAt != null`.
- Provider's `.when()` handles error state (no cache, no banner).
- Test permutations: online-hit, online-miss, offline-hit, offline-miss.

### Risk: Owner-Gating Edge Cases (MEDIUM)

**Issue:** Replacing tri-state with dual-gate could miss an edge case (owner-tool rendered to non-owner).

**Mitigation:**
- Guard all owner-tool buttons with `_isOwnerFromMembers() == true`.
- Test: owner can see rotate/transfer, member cannot.
- Walk through all owner-tool UI before shipping.

### Risk: Backend Not Yet Implementing searchQuery (LOW)

**Issue:** v1.1 uses local filtering; backend `searchQuery` param added in v1.2.

**Mitigation:**
- v1.1 local filtering is sufficient (acceptable perf for typical band sizes).
- v1.2 backend change is transparent to client (optional param already in place).
- No client-side code breakage.

---

## Summary Table

| Question | Answer | Complexity | Risk |
|----------|--------|------------|------|
| 1. Cache flip | Online-first guard in `build()`, no schema change | Medium | High (all screens) |
| 2. Envelope fate | Stays unchanged; SyncStatusBadge removed, OfflineFallbackBanner added | Low | Low |
| 3. Owner gates | Dual-gate (`_isMemberResolved()` + `_isOwnerFromMembers()`) replaces tri-state | Medium | Medium |
| 4. searchQuery integration | Optional param to `PublicApi.listBandTracks()`, local filtering in picker | Low | Low |

---

## Architecture Diagram (v1.1)

```
┌───────────────────────────────────────────────────────┐
│  UI Layer (features/*)                                │
│  • Removed: SyncStatusBadge (10 call-sites)           │
│  • Added: OfflineFallbackBanner (10 call-sites)       │
│  • Added: SetlistTrackPickerScreen (local search)     │
│  • Changed: Gating from tri-state to dual-gate        │
└─────────────────────┬─────────────────────────────────┘
                      │ watch
                      ▼
┌───────────────────────────────────────────────────────┐
│  Providers Layer (providers/*)                         │
│  • ProfileData, BandsListData, BandDetailData, etc.   │
│  • CHANGED: online-first routing in build()           │
│  • REMOVED: _refresh() + _doRefresh() background      │
│  • KEPT: _version guard for user-initiated refresh()  │
│  • KEPT: *SyncedAt providers (offline banner text)    │
└─────────────────────┬─────────────────────────────────┘
                      │ read/watch
                      ▼
┌───────────────────────────────────────────────────────┐
│  API + Cache Layer                                    │
│  • PublicApi: listBandTracks(searchQuery?) added      │
│  • CacheService: no schema changes                    │
│  • ApiClient: no changes                              │
└───────────────────────────────────────────────────────┘
```

---

## Sources

- **Existing codebase:** `lib/cache/cache_service.dart`, `lib/providers/profile_provider.dart`, `lib/features/bands/band_detail_screen.dart` — HIGH confidence, ground truth for v1.0 patterns.
- **PROJECT.md:** v1.1 milestone scope and schema changes (commit fe72e78) — HIGH confidence.
- **Riverpod docs:** Auto-invalidation via `ref.watch()` dependency — HIGH confidence, official docs.
- **Flutter best practices:** Online-first vs cache-first patterns — MEDIUM confidence, community discussion + official guidance.

---

*Architecture research for: Cadence v1.1 UI Improvements milestone*  
*Researched: 2026-08-20*
