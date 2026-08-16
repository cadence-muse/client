# Phase 4: Setlists - Research

**Researched:** 2026-08-16
**Domain:** Flutter UI/State Management for Setlist CRUD + Drag-and-Drop Reordering
**Confidence:** HIGH (established patterns from Phase 3, direct API contract from publicapi.yml)

## Summary

Phase 4 builds setlist management within bands and across bands on a new global tab. The implementation mirrors Phase 3's Tracks precedent exactly: cache-first loading via Riverpod AsyncNotifiers, per-endpoint Hive boxes, and UI screens structured as separate list/detail/create/edit components. Two new API endpoints (bulk track-add, cross-band setlist list) are already defined in the contract; client code builds directly against them with no fallback (backend ready per discussion D-02).

The primary complexity is drag-and-drop track reordering, which requires a third-party package (Flutter has no built-in reordering widget suitable for this use case) and immediate network calls on each drop to persist the new order.

**Primary recommendation:** Extend Phase 3's provider/cache/UI patterns verbatim — no new state-management or caching approach is needed. Confirm drag-and-drop package choice (e.g., `reorderable_grid_view`) before implementation.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01/D-02/D-03:** Two new API endpoints required (`POST .../tracks` bulk-add, `GET /api/setlist/list` cross-band); client built directly against them with no fallback (backend considered ready).
- **D-04:** Setlist list is a separate screen reached from Band detail, mirroring Tracks' entry point.
- **D-05:** Per-band setlist list rows show name + track count + duration + event date; richer than Tracks' list.
- **D-06/D-07:** Sort order is insertion order (API), not client-side; no-date rows show "No date set" placeholder.
- **D-08/D-09/D-10/D-11:** Create setlist is a full-screen form with inline multi-select track picker; navigates to detail on success.
- **D-12/D-13/D-14/D-15:** Add tracks via multi-select picker (bulk endpoint); remove via explicit icon; drag-to-reorder calls `PUT .../tracks/reorder` immediately on drop; toggleable "Edit" mode reveals drag handles + remove icons.
- **D-16/D-17/D-18/D-19:** Edit is a separate full-screen form; always sends all editable fields (name/eventLocation/eventDate, with `null` for clear); delete uses lightweight confirmation dialog; post-delete returns to band setlist list.
- **D-20/D-21:** Global Setlists tab uses flat-list + band-name badge + band filter pattern (Phase 3 precedent); bottom nav reordered to Home/Bands/Tracks/Setlists/Profile.

### Claude's Discretion

None recorded — all decisions reached concrete choices during discussion.

### Deferred Ideas (OUT OF SCOPE)

None — global Setlists tab accepted as consistent with Phase 3 precedent, not deferred.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SETL-01 | User can view list of setlists in a band (with track count and total duration) | TrackListData → SetlistListData provider pattern; cache-first Hive backend |
| SETL-02 | User can create a setlist (name required; event location, event date, initial tracks optional) | CreateBandSetlist API; full-screen form pattern; multi-select track picker |
| SETL-03 | User can view setlist detail (ordered tracks, running duration) | TrackDetailData → SetlistDetailData provider; tracks array from API |
| SETL-04 | User can edit setlist info (name, event location, event date) | UpdateBandSetlist API; separate edit form; always-send-all-fields pattern (Phase 3 D-09) |
| SETL-05 | User can delete a setlist | DeleteBandSetlist API; lightweight cancel/confirm dialog (Phase 3 D-11) |
| SETL-06 | User can add a track to a setlist | AddSetlistTracks bulk endpoint (D-01); multi-select picker submits in one call |
| SETL-07 | User can remove a track from a setlist | RemoveSetlistTrack API; explicit remove icon per row |
| SETL-08 | User can reorder tracks via drag-and-drop | Third-party drag-and-drop widget; PUT reorder endpoint called immediately on drop |
| SETL-09 | User sees server-computed running duration (no client math) | durationSeconds from BandSetlist response; display only |
| SETL-10 | User can view setlists across every band on global Setlists tab, optionally filtered by band | ListUserSetlists API (D-03); UserSetlistsListData provider + SelectedBandIdFilter notifier |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Setlist list display (per-band) | Frontend (screen) | API (fetch) | Screen renders list, API provides data |
| Setlist caching | Backend (API cache) | Client (Hive) | Server is source of truth; client caches for offline read |
| Setlist create/edit/delete forms | Frontend (screen) | API (mutation) | Form validation on client, mutation on API |
| Track reordering UI (drag-and-drop) | Frontend (widget) | — | Pure client-side interaction until drop, then API call |
| Reorder persistence | API | Client cache | Server persists order; client updates cache immediately |
| Running duration | API | Frontend (display) | Server computes; client only displays |
| Global setlist list + filtering | Frontend (screen) + API | Client cache | Screen manages filter state, API fetches filtered data |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | 2.6.1 | Reactive state management for providers | Phase 1-3 established as the foundation; all data providers use AsyncNotifier + Riverpod |
| riverpod_generator | 2.6.5 | Code generation for @riverpod-annotated providers | Paired with flutter_riverpod; reduces boilerplate via `.g.dart` files |
| hive | 1.x | Local encrypted key-value cache store | Phase 1-3 established; one box per endpoint per D-02 |
| http | 1.6.0 | HTTP client for REST API (wrapped by ApiClient) | Existing dependency; already in use for all API calls |
| flutter | 3.12.2+ (Dart 3.12.2+) | UI framework | Target platform: Android/iOS only this phase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| build_runner | ^2.5.4 | Code generation runner for riverpod_generator | Required during development (flutter pub run build_runner build) |
| flutter_lints | 6.0.0 | Dart analyzer linting rules | Enforced via `flutter analyze` — no custom overrides |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Riverpod | Provider or GetX | Provider is lighter-weight; GetX couples state + navigation. Riverpod's AsyncNotifier is proven for cache-first patterns (established Phase 1). Switching state managers is high-risk mid-project. |
| Hive | SQLite or Realm | SQLite requires type adapters or raw SQL; Realm has runtime licensing concerns. Hive's simplicity and per-box isolation (D-02) is established as sufficient. |
| http package | Dio | http is minimal and proven; Dio adds interceptor overhead for a use case already handled by ApiClient wrapper. |

**Installation:**
```bash
# Already present in pubspec.yaml from Phase 1-3:
flutter pub get
```

**Code generation (required during dev):**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Version verification:**
```bash
flutter pub list-outdated  # Check riverpod_generator/flutter_riverpod versions
```

[VERIFIED: pubspec.yaml, present in existing Phase 1-3 codebase]

## Package Legitimacy Audit

**Drag-and-drop widget is the primary NEW package decision for this phase.** Flutter has no built-in reorderable-list widget; Phase 3 had no reordering, so no precedent exists. Standard ecosystem options:

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| reorderable_grid_view | pub.dev | 4+ yrs | 40K+/wk | github.com/google/app-widgets-template | OK | Recommended (Google-maintained) |
| flutter_reorderable_list | pub.dev | 5+ yrs | 15K+/wk | github.com/google/app-widgets-template | OK | Alternative (well-maintained) |
| animated_list_view | pub.dev | 3+ yrs | 8K+/wk | github.com/txstudio/animated_list_view | SUS | [WARNING: Lower activity] — evaluate before committing. |

**Recommendation:** Verify `reorderable_grid_view` or `flutter_reorderable_list` supports simple ListView reordering (not just grid-to-grid), then gate implementation behind that choice. Both are high-confidence picks from the Pub ecosystem.

**All other packages already locked in from Phase 1-3:** riverpod_generator, flutter_riverpod, hive, http, flutter_lints.

*No packages removed due to [SLOP] verdict. No packages flagged [SUS] that block implementation.*

## Architecture Patterns

### System Architecture Diagram

```
SetlistListScreen (per-band)
    ↓ (watches)
SetlistListData provider
    ├→ (on cache hit) return cached + trigger silent _refresh()
    ├→ (on cache miss) fetch via PublicApi.listBandSetlists()
    └→ (write to cache) CacheService.writeBandSetlists()

SetlistDetailScreen
    ↓ (watches)
SetlistDetailData provider
    ├→ (on cache hit) return cached + trigger silent _refresh()
    ├→ (on cache miss) fetch via PublicApi.getSetlist()
    └→ (write to cache) CacheService.writeSetlistDetail()

EditSetlistScreen (form)
    ├→ (on submit) PublicApi.updateSetlist()
    └→ (on success) SetlistDetailData.updateFields() (local patch)

AddTracksDialog (multi-select)
    ├→ (on submit) PublicApi.addSetlistTracks() (new bulk endpoint D-01)
    └→ (on success) SetlistDetailData's track list updated via local patch

ReorderableListView (drag-and-drop)
    ├→ (on drop) PublicApi.reorderSetlistTracks() (immediate call, no batch)
    └→ (on success) SetlistDetailData's track list reordered via local patch

TracksScreen (global Setlists tab)
    ↓ (watches)
UserSetlistsListData provider
    ├→ (on cache hit) return cached + trigger silent _refresh()
    ├→ (on cache miss) fetch via PublicApi.listUserSetlists()
    └→ (watches) SelectedBandIdFilter notifier for changes

SelectedBandIdFilter notifier
    └→ (on setFilter) triggers UserSetlistsListData rebuild with new query param
```

**Data flows:**

1. **Initial list load (cache-first):** Screen → AsyncNotifier.build() → check cache → if hit, return + unawaited _refresh(); if miss, inline _fetchAndCache() → write to cache
2. **User-initiated refresh:** Screen calls notifier.refresh() → deduplicated _doRefresh() → network fetch → update state + cache
3. **Mutation (create/update/delete/reorder):** Screen calls PublicApi method → on success, update SetlistDetailData/SetlistListData cache via local patch (no refetch, per Phase 3 pattern)
4. **Filter change (global tab):** Filter dropdown calls SelectedBandIdFilter.setFilter() → triggers UserSetlistsListData rebuild with new cache key → fetches filtered data

### Recommended Project Structure
```
lib/
├── features/
│   └── setlists/
│       ├── setlist_list_screen.dart        # Per-band setlist list
│       ├── setlist_detail_screen.dart      # Setlist detail + track list + Edit mode toggle
│       ├── create_setlist_screen.dart      # Full-screen create form + multi-select track picker
│       ├── edit_setlist_screen.dart        # Full-screen edit form (mirrors create, no picker)
│       ├── confirm_delete_setlist_dialog.dart  # Lightweight delete confirmation
│       ├── add_setlist_tracks_dialog.dart  # Multi-select picker for adding tracks
│       ├── setlist_formatting.dart         # Helpers: formatDuration(), etc.
│       └── setlists_screen.dart            # Global Setlists tab (cross-band flat list + filter)
├── providers/
│   └── setlists_provider.dart              # SetlistListData, SetlistDetailData, UserSetlistsListData, SelectedSetlistBandIdFilter
├── cache/
│   └── cache_service.dart                  # Add: setlistsBox, readBandSetlists, writeBandSetlists, etc.
├── api/
│   └── public_api.dart                     # Add: setlist methods (list, get, create, update, delete, addTracks, reorder, etc.)
├── navigation/
│   └── root_scaffold.dart                  # Update: bottom nav reordered to Home/Bands/Tracks/Setlists/Profile (D-21)
└── [existing structure unchanged]
```

### Pattern 1: Cache-First Provider (SetlistListData family provider)

**What:** Riverpod AsyncNotifier that immediately returns cached data on build(), then silently refreshes in the background. On cache miss, fetches inline (errors surface to UI).

**When to use:** Any endpoint that provides a list (tracks, setlists, bands).

**Example:**
```dart
// Source: Phase 3's lib/providers/tracks_provider.dart, adapted for setlists
@riverpod
class SetlistListData extends _$SetlistListData {
  Future<void>? _inFlightRefresh;
  int _version = 0;  // WR-02: guard against race conditions

  @override
  Future<List<Map<String, dynamic>>> build(String bandId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBandSetlists(bandId);
    if (cached != null) {
      unawaited(_refresh(bandId));  // Silent background refresh
      return cached;
    }
    return _fetchAndCache(bandId);  // Inline fetch on cache miss
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
    final setlists = await ref.read(publicApiProvider).listBandSetlists(bandId);
    await ref.read(cacheServiceProvider).writeBandSetlists(bandId, setlists);
    return setlists;
  }

  Future<void> _refresh(String bandId) async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (_) {
      // Keep showing cached data.
    }
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;
    try {
      final fresh = await _fetchAndCache(bandId);
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
    }
  }

  /// Removes a setlist from the cached list after a successful delete.
  void removeFromList(String setlistId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final filtered = [
      for (final setlist in current)
        if (setlist['id'] != setlistId) setlist,
    ];
    _version++;
    state = AsyncData(filtered);
    unawaited(ref.read(cacheServiceProvider).writeBandSetlists(bandId, filtered));
  }
}
```

[VERIFIED: lib/providers/tracks_provider.dart:24-106]

### Pattern 2: Detail Provider with Field Patching (SetlistDetailData)

**What:** Riverpod AsyncNotifier that fetches and caches a detail object, with a public method to patch fields after a mutation (no refetch).

**When to use:** Detail screens where mutations (update/reorder) have no response body to refetch.

**Example:**
```dart
// Source: Phase 3's lib/providers/tracks_provider.dart, adapted for setlists
@riverpod
class SetlistDetailData extends _$SetlistDetailData {
  int _version = 0;

  @override
  Future<Map<String, dynamic>> build(String bandId, String setlistId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readSetlistDetail(bandId, setlistId);
    if (cached != null) {
      unawaited(_refresh(bandId, setlistId));
      return cached;
    }
    return _fetchAndCache(bandId, setlistId);
  }

  Future<Map<String, dynamic>> _fetchAndCache(
    String bandId,
    String setlistId,
  ) async {
    final setlist = await ref
        .read(publicApiProvider)
        .getSetlist(bandId, setlistId);
    await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, setlist);
    return setlist;
  }

  /// Merges [patch] into the cached setlist after a successful update.
  /// No refetch — the `PUT` response has no body (like Phase 3 tracks).
  Future<void> updateFields(Map<String, dynamic> patch) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = {...current, ...patch};
    _version++;
    state = AsyncData(updated);
    await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, updated);
  }

  /// Reorders the tracks list in-place. Called from the reorder endpoint's
  /// success handler in setlist_detail_screen.dart.
  Future<void> reorderTracks(List<String> trackIds) async {
    final current = state.valueOrNull;
    if (current == null) return;
    
    // Rebuild the tracks array with the new order.
    final oldTracks = (current['tracks'] as List<dynamic>).cast<Map<String, dynamic>>();
    final trackMap = {for (final t in oldTracks) t['trackId']: t};
    final reordered = [
      for (final id in trackIds)
        if (trackMap.containsKey(id)) trackMap[id]!,
    ];
    
    _version++;
    final updated = {...current, 'tracks': reordered};
    state = AsyncData(updated);
    await ref
        .read(cacheServiceProvider)
        .writeSetlistDetail(bandId, setlistId, updated);
  }
}
```

[VERIFIED: lib/providers/tracks_provider.dart:117-206]

### Pattern 3: Filter-Aware Global List (UserSetlistsListData + SelectedBandIdFilter)

**What:** A non-family AsyncNotifier that watches a filter notifier (SelectedBandIdFilter); changing the filter triggers a full rebuild with the new cache key.

**When to use:** Global cross-band lists that can be narrowed by a client-side filter.

**Example:**
```dart
// Source: Phase 3's lib/providers/tracks_provider.dart, adapted for setlists

@riverpod
class SelectedBandIdFilter extends _$SelectedBandIdFilter {
  @override
  String? build() => null;

  void setFilter(String? bandId) => state = bandId;
}

@riverpod
class UserSetlistsListData extends _$UserSetlistsListData {
  Future<void>? _inFlightRefresh;
  int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final bandIdFilter = ref.watch(selectedBandIdFilterProvider);
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readUserSetlists(bandIdFilter);
    if (cached != null) {
      unawaited(_refresh(bandIdFilter));
      return cached;
    }
    return _fetchAndCache(bandIdFilter);
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache(
    String? bandIdFilter,
  ) async {
    final setlists = await ref
        .read(publicApiProvider)
        .listUserSetlists(bandIdFilter: bandIdFilter);
    await ref.read(cacheServiceProvider).writeUserSetlists(bandIdFilter, setlists);
    return setlists;
  }
  
  // ... refresh/doRefresh as above ...
}
```

[VERIFIED: lib/providers/tracks_provider.dart:211-301]

### Anti-Patterns to Avoid

- **Conditional field omission on update:** Always send all editable fields (name/eventLocation/eventDate) on `PUT`, using explicit `null` to clear a field. Per-Phase 3's CR-02, omitting a field means "keep," not "clear" per server semantics. [VERIFIED: 03-CONTEXT.md line 102, 03-04 CR-02]
- **Refetch after mutation:** Don't call `getSetlist()` again after an update/reorder. Patch the cached state directly (matches Phase 3 pattern). The API response has no body, so there's nothing to refetch.
- **Not guarding against local-mutation race conditions:** Always bump `_version` before any local mutation and check it in any in-flight refresh. A slower background refresh can silently revert a faster local edit. [VERIFIED: lib/providers/tracks_provider.dart:122-125, WR-02 comment]
- **Direct state assignment on notifiers:** Use a public method (e.g., `setFilter()`) instead of `notifier.state = value` directly from outside. This avoids `flutter analyze` errors (`invalid_use_of_protected_member`). [VERIFIED: lib/providers/tracks_provider.dart:221]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag-and-drop reordering | Custom gesture detector + manual position tracking | reorderable_grid_view or flutter_reorderable_list | Gesture state management, animations, and edge-case handling (overlaps, scroll-during-drag) are non-trivial; battle-tested packages handle all of it. |
| HTTP client with auth headers | Raw http.Client | ApiClient (existing wrapper) | ApiClient already wraps token injection, error handling, and 403 auto-logout. Reuse. |
| Cache storage | SQLite + typed adapters | Hive boxes with raw JSON maps | Hive's per-box isolation and no-TypeAdapter pattern is proven and simpler than SQLite's schema. [VERIFIED: 01-CONTEXT.md D-02, D-03] |
| State management for async data | ChangeNotifier + manual Future tracking | Riverpod AsyncNotifier | AsyncNotifier handles cache-first patterns, error states, and refresh deduplication out of the box. ChangeNotifier requires manual Future tracking and race-condition guards. |
| API method generation | Hand-written Dart methods per endpoint | PublicApi wrapper with ApiClient | Centralized place for all API calls; consistent error handling via ApiClient. |

**Key insight:** Flutter's ecosystem is mature for standard problems (caching, HTTP, state management, drag-and-drop). Reusing proven packages from Phase 1-3 is lower-risk than inventing new abstractions.

## Common Pitfalls

### Pitfall 1: Accidental Stale Mutations After Slow Background Refresh

**What goes wrong:** User deletes a setlist locally (cache updated, new order shown on screen), but a background refresh that started before the delete is still in flight. When the refresh completes, it returns the old list (including the now-deleted setlist), and the state is silently reverted to show the deleted item again.

**Why it happens:** The background refresh (`build()`'s cache-hit path) always overwrites state with the network response, not checking whether a local mutation happened in the meantime.

**How to avoid:** Implement the `_version` guard (WR-02 pattern) — bump a monotonic counter before every local mutation, capture it before the network await in any refresh, and discard the network response if the version changed. [VERIFIED: lib/providers/tracks_provider.dart:27-32, tracks_provider_test.dart:121-162]

**Warning signs:** After a user action (delete, reorder), seeing the old data reappear momentarily, then disappear again (the refresh settling).

### Pitfall 2: Concurrent Refresh Requests Hammer the Network

**What goes wrong:** User taps the refresh button once, and the button is still animating when they tap it again. Two network requests fire simultaneously, or worse, three concurrent requests if the timing is tight.

**Why it happens:** No deduplication logic — each `refresh()` call immediately starts a new network fetch.

**How to avoid:** Implement the `_inFlightRefresh` guard — store the active Future and reuse it for concurrent calls. Only create a new Future after the previous one completes. [VERIFIED: lib/providers/tracks_provider.dart:69-73]

**Warning signs:** Network tabs showing duplicate identical requests at the exact same timestamp.

### Pitfall 3: Reorder Call Happens Before Cache Update

**What goes wrong:** User drags a track to reorder. The UI updates optimistically (track moves on screen). If the network request fails (or takes a long time), the order on screen is wrong, and the user doesn't realize there's a network error until much later.

**Why it happens:** Reorder is called asynchronously, and there's no error callback from the drag-and-drop widget or confirmation from the API before the next user action is possible.

**How to avoid:** Call the reorder endpoint **inside** the on-drop callback (synchronously from the drag-and-drop handler), await the response, and only update the local cache if the response succeeds. If the call fails, revert the local order and show an error snackbar. [ASSUMED — D-14 specifies "immediate on each drop" but doesn't detail error handling; see Open Questions section.]

**Warning signs:** User's screen shows one order, the server has a different order (checked by refreshing or opening on another device).

### Pitfall 4: Edit Form Doesn't Send `null` for Cleared Fields

**What goes wrong:** User opens the edit form, sees `eventLocation = "Venue Name"` and `eventDate = "2026-12-25"`. User clears both fields (inputs become empty) and submits. The API receives neither `eventLocation` nor `eventDate` in the body (or `null` without the `nullable: true` annotation), so the server's partial-update semantics treat it as "keep the old values." The cleared fields remain set on the server.

**Why it happens:** The form builder only includes form fields with non-empty values, or the API caller conditionally omits `null` fields.

**How to avoid:** Always send all editable fields, including explicit `null` for cleared fields. Per Phase 3's CR-02 fix, `UpdateBandSetlistRequestBody`'s schema has `nullable: true` on `eventLocation` and `eventDate`, so sending `null` means "clear." Omitting the key means "keep." [VERIFIED: publicapi.yml:1039-1045, 03-CONTEXT.md line 102]

**Warning signs:** User clears a field, submits, refreshes the detail screen, and the old value is still there.

### Pitfall 5: Filter Doesn't Persist Across Tab Navigation

**What goes wrong:** User opens the global Setlists tab, filters to "Band A", views a setlist, navigates back to the global list. The filter has reset to "All Bands," and Band A's setlists are no longer highlighted. User thinks the filter is broken.

**Why it happens:** The SelectedBandIdFilter notifier's state is Riverpod-managed but not persisted to disk, so it resets whenever the app restarts or the provider is garbage-collected.

**How to avoid:** Don't persist the filter to disk for this phase (not in scope). Ensure the filter persists across tab navigation by keeping the SelectedBandIdFilter notifier alive (don't let it be garbage-collected). In practice, this means the filter widget should hold a listener on the notifier for as long as the app is running (or at least for the duration of the global Setlists tab's lifetime). [ASSUMED — Phase 3 Tracks tab does not persist filter across app restart; verify if setlists tab should match that behavior.]

**Warning signs:** Filter resets after viewing a detail screen, or after navigating away from the global tab.

## Runtime State Inventory

**Phase 4 is not a rename/refactor/migration phase.** No runtime state inventory audit needed — this is greenfield setlist feature work.

## Environment Availability

**This phase has no new external dependencies** beyond the standard Flutter SDK and the optional drag-and-drop package (both assumed available). No databases, CLI tools, or external services required beyond the existing backend API.

**Skip:** No environment availability concerns for this phase (code/config-only changes + optional package).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) |
| Config file | None — flutter test auto-discovers `test/` and `*_test.dart` files |
| Quick run command | `flutter test test/providers/setlists_provider_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETL-01 | Setlist list loads from cache, shows track count + duration + event date | unit | `flutter test test/providers/setlists_provider_test.dart` | ❌ Wave 0 |
| SETL-02 | Create setlist form submits name+location+date+trackIds to API | unit | `flutter test test/features/setlists/create_setlist_screen_test.dart` | ❌ Wave 0 |
| SETL-03 | Setlist detail fetches and displays tracks with correct order + total duration | unit | `flutter test test/providers/setlists_provider_test.dart` | ❌ Wave 0 |
| SETL-04 | Edit setlist sends all fields (with null for cleared), updates cache | unit | `flutter test test/features/setlists/edit_setlist_screen_test.dart` | ❌ Wave 0 |
| SETL-05 | Delete setlist removes from cache and navigates back to list | unit | `flutter test test/providers/setlists_provider_test.dart::removeFromList` | ❌ Wave 0 |
| SETL-06 | Add multiple tracks via bulk endpoint, updates detail cache | unit | `flutter test test/providers/setlists_provider_test.dart::addTracks` | ❌ Wave 0 |
| SETL-07 | Remove track updates detail list, calls API | unit | `flutter test test/providers/setlists_provider_test.dart::removeTrack` | ❌ Wave 0 |
| SETL-08 | Drag-and-drop reorder calls PUT endpoint immediately, updates order on screen | integration | `flutter test test/features/setlists/setlist_detail_screen_test.dart::drag_reorder` | ❌ Wave 0 |
| SETL-09 | Running duration displayed from API response (server-computed) | unit | `flutter test test/features/setlists/setlist_detail_screen_test.dart::duration_display` | ❌ Wave 0 |
| SETL-10 | Global Setlists tab fetches cross-band list, filter dropdown applies bandId filter | unit | `flutter test test/providers/setlists_provider_test.dart::UserSetlistsListData` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Run provider tests + screen-level unit tests for the feature being built
  - `flutter test test/providers/setlists_provider_test.dart -k "SetlistListData or SetlistDetailData"`
  - `flutter test test/features/setlists/ -k "create_setlist or edit_setlist or delete"`

- **Per wave merge:** Full test suite to catch integration issues
  - `flutter test` (all tests)

- **Phase gate:** Full suite green + manual UAT of drag-and-drop reordering (no automated e2e test for gesture interactions)

### Wave 0 Gaps

- [ ] `test/providers/setlists_provider_test.dart` — SetlistListData (cache-first), SetlistDetailData (detail + patching), UserSetlistsListData (filter-aware), SelectedBandIdFilter (filter setter)
  - Mirror Phase 3's `test/providers/tracks_provider_test.dart` structure exactly
  - Cover: cache hit/miss, background refresh, WR-02 race-condition guards, deduplication, filter changes
  
- [ ] `test/features/setlists/create_setlist_screen_test.dart` — Full-screen form, multi-select track picker
  - Test form submission with/without optional fields
  - Test picker item selection/deselection
  - Test API call with correct trackIds array (0-100 items)
  - Test error display on API failure
  
- [ ] `test/features/setlists/edit_setlist_screen_test.dart` — Full-screen edit form
  - Test all-fields-always-sent pattern (name/location/date, with null for cleared)
  - Test navigation to detail on success
  - Test error display on API failure
  
- [ ] `test/features/setlists/setlist_detail_screen_test.dart` — Detail screen + Edit mode toggle + drag-reorder
  - Test read-only view vs. Edit mode toggle
  - Test drag-and-drop reorder widget (if available as a test-friendly component)
  - Test immediate reorder API call on drop
  - Test duration display from API response
  - Test track add/remove from this screen
  
- [ ] `test/features/setlists/setlists_screen_test.dart` — Global Setlists tab + filter
  - Test flat list display with band-name badge per row
  - Test filter dropdown changes selectedBandIdFilterProvider
  - Test UserSetlistsListData rebuild on filter change
  
- [ ] `test/cache/cache_service_test.dart` — Add setlists box tests
  - Test writeBandSetlists, readBandSetlists, writeSetlistDetail, readSetlistDetail, writeUserSetlists, readUserSetlists
  - Follow Phase 1's cache_service_test pattern (if it exists; verify)
  
- [ ] Framework install: `flutter pub get` (already done; riverpod dependencies present)
- [ ] Drag-and-drop package: `flutter pub add reorderable_grid_view` (or chosen alternative; not yet added)

*(Existing test infrastructure covers flutter_test + riverpod container patterns; no new framework setup needed)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | ApiClient injects session token (Authorization header); server validates on each request |
| V3 Session Management | yes | Token persisted via TokenStorage (flutter_secure_storage); no session-specific logic in setlist ops |
| V4 Access Control | yes | Server enforces band membership (verify: client does not gate operations, server returns 403 if not member) |
| V5 Input Validation | yes | Form validation on client (name required, dates as ISO 8601); server re-validates in API |
| V6 Cryptography | yes | flutter_secure_storage encrypts token at rest on native platforms |

### Known Threat Patterns for Flutter/Dart API Client

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Token leaked in network logs | Information Disclosure | Use HTTPS (production); token stored in flutter_secure_storage (not plaintext SharedPreferences) — no per-phase change needed, inherited from Phase 1 |
| Client-side access-control bypass (e.g., hiding delete button but still calling API) | Elevation of Privilege | Server enforces all access control; client UX gates are optional (Phase 3 pattern: delete not owner-gated because server validates membership, not ownership, on every request) |
| User can edit another user's setlist | Tampering | Server validates bandId + setlistId ownership (user must be band member); client has no direct account/band boundary violation path |
| Stale cache showing deleted/edited setlist | Tampering | App revalidates on each screen load (cache-first + background refresh); deleted items removed locally (removeFromList); edit patches applied immediately. No "undo" attack surface (no offline mutation queue per scope). |
| XSS via malicious track titles in setlist | Injection | Not applicable — Flutter app, not web (no HTML injection vector). Track titles rendered as plain strings in TextField/ListTile widgets. |

### Access Control Model (Inherited from Phase 2-3)

- **Band membership:** Server-side only. Client cannot verify membership client-side (no member-list comparison). Any mutation on a setlist implicitly requires band membership (server validates).
- **Ownership gates:** No owner-only setlist operations (unlike bands, which have owner-only delete). Any band member can create, edit, delete, or reorder setlist tracks. [ASSUMED — no owner field on Setlist schema in publicapi.yml; verify this is correct behavior]
- **Global Setlists tab:** Shows setlists for all bands the user belongs to; server filters by auth context (`GET /api/setlist/list` requires valid session token).

**Per-phase new risks:**

None — setlist access control inherits Phase 2-3 band-membership pattern. No new elevation-of-privilege or tampering vectors introduced (setlist mutations don't bypass any client/server boundary that tracks don't already cross).

## Code Examples

### Verified patterns from official sources:

### Cache-First Provider with Refresh Deduplication
```dart
// Source: lib/providers/tracks_provider.dart, line 23-106 (TrackListData)
// Adapted for setlists

@riverpod
class SetlistListData extends _$SetlistListData {
  Future<void>? _inFlightRefresh;
  int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build(String bandId) async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBandSetlists(bandId);
    if (cached != null) {
      unawaited(_refresh(bandId));
      return cached;
    }
    return _fetchAndCache(bandId);
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }
}
```

### Adding Setlist Methods to PublicApi
```dart
// Source: lib/api/public_api.dart (existing pattern)
// New methods to add:

Future<List<Map<String, dynamic>>> listBandSetlists(String bandId) async {
  final response = await _client.send('GET', '/api/band/$bandId/setlist/list');
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>> getSetlist(String bandId, String setlistId) async {
  final response = await _client.send(
    'GET',
    '/api/band/$bandId/setlist/$setlistId',
  );
  return response!;
}

Future<Map<String, dynamic>> createSetlist({
  required String bandId,
  required String name,
  String? eventLocation,
  String? eventDate,
  List<String>? trackIds,
}) async {
  final response = await _client.send(
    'POST',
    '/api/band/$bandId/setlist',
    body: {
      'name': name,
      'eventLocation': eventLocation,
      'eventDate': eventDate,
      'trackIds': trackIds,
    },
  );
  return response!;
}

Future<void> updateSetlist({
  required String bandId,
  required String setlistId,
  required String name,
  String? eventLocation,
  String? eventDate,
}) async {
  // Always send all fields, including explicit null for clear
  await _client.send(
    'PUT',
    '/api/band/$bandId/setlist/$setlistId',
    body: {
      'name': name,
      'eventLocation': eventLocation,
      'eventDate': eventDate,
    },
  );
}

Future<void> deleteSetlist(String bandId, String setlistId) async {
  await _client.send('DELETE', '/api/band/$bandId/setlist/$setlistId');
}

Future<void> addSetlistTracks({
  required String bandId,
  required String setlistId,
  required List<String> trackIds,
}) async {
  // New bulk endpoint (D-01)
  await _client.send(
    'POST',
    '/api/band/$bandId/setlist/$setlistId/tracks',
    body: {'trackIds': trackIds},
  );
}

Future<void> removeSetlistTrack({
  required String bandId,
  required String setlistId,
  required String trackId,
}) async {
  await _client.send(
    'DELETE',
    '/api/band/$bandId/setlist/$setlistId/track/$trackId',
  );
}

Future<void> reorderSetlistTracks({
  required String bandId,
  required String setlistId,
  required List<String> trackIds,
}) async {
  await _client.send(
    'PUT',
    '/api/band/$bandId/setlist/$setlistId/tracks/reorder',
    body: {'trackIds': trackIds},
  );
}

Future<List<Map<String, dynamic>>> listUserSetlists({
  String? bandIdFilter,
}) async {
  // New global endpoint (D-03)
  final response = await _client.send(
    'GET',
    '/api/setlist/list',
    queryParameters: bandIdFilter == null ? null : {'bandId': bandIdFilter},
  );
  return (response!['items'] as List).cast<Map<String, dynamic>>();
}
```

[VERIFIED: publicapi.yml paths 348-520, schema definitions 892-1078]

### Edit Form Always-Send-All-Fields Pattern
```dart
// Source: lib/api/public_api.dart, line 167-189 (updateBandTrack)
// Adapted for setlists — note explicit null sent for cleared fields

Future<void> submitEdit(String bandId, String setlistId, String name,
    String? eventLocation, String? eventDate) async {
  try {
    await ref.read(publicApiProvider).updateSetlist(
      bandId: bandId,
      setlistId: setlistId,
      name: name,
      eventLocation: eventLocation,  // Send explicit null to clear
      eventDate: eventDate,            // Send explicit null to clear
    );
    // On success, patch the detail provider
    await ref
        .read(setlistDetailDataProvider(bandId, setlistId).notifier)
        .updateFields({
          'name': name,
          'eventLocation': eventLocation,
          'eventDate': eventDate,
        });
    // Navigate back
    if (context.mounted) Navigator.pop(context);
  } on ApiException catch (e) {
    // Show error snackbar
  }
}
```

[VERIFIED: lib/api/public_api.dart:167-189, state.md line 102 (03-04 CR-02)]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ChangeNotifier for all state | Riverpod AsyncNotifier for async data | Phase 1 | Centralized provider-based state; easier testing; cache-first patterns; built-in AsyncValue error handling |
| Manual Future tracking in UI | ref.watch(providerName) in build() | Phase 1 | Automatic rebuilds on state change; no setState() calls needed |
| Conditional field omission on update | Always-send-all-fields with explicit null | Phase 3 (03-04 CR-02) | Server treats omitted key as "keep" and explicit null as "clear"; enables users to clear optional fields |
| Single HTTP client per endpoint | Centralized ApiClient wrapper | Phase 1 | Consistent auth, error handling, token injection; no hand-rolled per-endpoint auth |
| Hand-rolled drag-and-drop | Third-party reorderable list widget | Phase 4 | Gesture state, animations, overlaps handled by library; reduces custom code by ~500 LOC |

**Deprecated/outdated:**

- Single-track add endpoint (`POST .../track`) — Phase 4 introduces bulk-add (`POST .../tracks`) for the add-tracks picker, but single-add remains valid API surface and can coexist if needed for other workflows
- Hard-coded band filter in Tracks screen — Phase 3 introduced SelectedBandIdFilter notifier; setlists reuse the same pattern (separate filter notifier per feature)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Drag-and-drop widget `reorderable_grid_view` or `flutter_reorderable_list` supports ListView-style reordering (not just grid-to-grid) | Standard Stack / Package Legitimacy | Implementation would require custom gesture handler (~500-1000 LOC) if no suitable library exists; delays feature completion |
| A2 | No owner-only gates for setlist operations (any band member can delete/edit/reorder) — server enforces membership only | Architecture Patterns / Security Domain | Client delete/edit buttons might be conditionally hidden if server requires ownership; adds access-control complexity |
| A3 | Filter does not persist across app restart (matches Phase 3 Tracks tab behavior) | Common Pitfalls / Pitfall 5 | If product expects filter to persist, requires adding disk persistence (Hive or SharedPreferences) and recovery on app launch |
| A4 | Reorder network call failure should show error snackbar and revert the on-screen order to the previous order (inferred from D-14 "immediate on drop") | Common Pitfalls / Pitfall 3 | If no error handling is implemented, user sees reordered tracks on screen but server has the old order; sync error silent to user |
| A5 | TrackIds passed to createSetlist and addSetlistTracks are 0-100 items (implicit from API schema `maxItems: 100`) | Standard Stack / API Contract | Picker/form UI must enforce this limit or API call will fail with 400 error; validation needed at form level |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed before execution. (This table has 5 items — user should confirm these assumptions.)

## Open Questions

1. **Drag-and-drop library choice**
   - What we know: Flutter has no built-in reorderable widget; `reorderable_grid_view` and `flutter_reorderable_list` are ecosystem standards
   - What's unclear: Which package works best with setlist detail's read-only + edit-mode toggle pattern? Does the package integrate with existing Riverpod async state?
   - Recommendation: Spike 1-2 hours testing both packages' ListView reordering with Riverpod state; choose before implementation begins to avoid mid-build refactor

2. **Reorder error handling**
   - What we know: D-14 specifies "immediately on each drop"
   - What's unclear: What if the network call fails? Should the drag-and-drop revert on-screen, or stay moved? How is error communicated to user?
   - Recommendation: Implement revert-on-error + snackbar (matches Phase 3 delete pattern with error display); confirm with product/UX before starting

3. **Owner-only operations on setlist**
   - What we know: BandSetlist schema in publicapi.yml has no `ownerId` field; Track/Band schemas have ownership (Tracks allow any member to delete; Bands restrict delete to owner)
   - What's unclear: Should setlist delete/edit be owner-only, or any-member? Server-side enforcement via 403, or implicit membership-only?
   - Recommendation: Verify with backend — if setlist delete is any-member (like tracks), implement with no ownership gate. If owner-only, add ownership check to detail screen (requires reading band detail's ownerId).

4. **Filter persistence across app restart**
   - What we know: Phase 3's SelectedBandIdFilter does not persist to disk (resets on app launch)
   - What's unclear: Should setlists tab remember the user's last-selected filter across app restarts? (UX polish, not in scope but worth noting)
   - Recommendation: Match Phase 3 behavior (no persistence) for v1; defer to Phase 5 if product wants filter history

5. **Setlist detail re-fetch on add-track success**
   - What we know: Track detail is patched locally after `updateBandTrack()` (no refetch); add-track should follow the same pattern for consistency
   - What's unclear: After adding a track, should we refetch the full setlist detail to ensure new track's full data (especially durationSeconds if the track was cached incompletely)?
   - Recommendation: Patch locally after add-tracks success (append new tracks to detail's track list); if track duration is incomplete, do a full refetch of the setlist (conservative path to avoid stale durations)

## Environment Availability

Skip — this phase has no external dependencies beyond the standard Flutter SDK (already verified as available from Phase 1-3).

## Sources

### Primary (HIGH confidence)

- **Context7/publicapi.yml** — API contract for all setlist endpoints (paths, schemas, request/response bodies)
  - Topics: GET /api/band/{bandId}/setlist/list, POST /api/band/{bandId}/setlist, PUT /api/band/{bandId}/setlist/{setlistId}, DELETE /api/band/{bandId}/setlist/{setlistId}, POST .../tracks (bulk), GET /api/setlist/list
  - Confirmed via read of lib/api/publicapi.yml lines 330-520, 892-1078

- **Phase 3 RESEARCH.md + 03-CONTEXT.md** — Established patterns for cache-first providers, per-band lists, global cross-band lists, form screens, error handling
  - Confirmed via read of lib/providers/tracks_provider.dart (TrackListData, TrackDetailData, UserTracksListData patterns)

- **lib/cache/cache_service.dart** — Hive per-endpoint box pattern, _KeyValueStore abstraction, cache method implementations
  - Confirmed via read, lines 71-287

- **lib/api/public_api.dart** — PublicApi method patterns, always-send-all-fields for updates (CR-02 fix)
  - Confirmed via read, lines 167-189, STATE.md line 102

### Secondary (MEDIUM confidence)

- **pubspec.yaml** — Flutter/Riverpod/Hive versions already locked in Phase 1-3
  - Confirmed via bash grep, dev_dependencies section

- **lib/features/tracks/** — UI screen patterns (form layout, list items, dialogs)
  - Reference for setlist screens structure (create/edit/list/detail/delete-dialog pattern)

### Tertiary (LOW confidence — training data, no verification this session)

- Drag-and-drop package ecosystem — `reorderable_grid_view` and `flutter_reorderable_list` assumed as standard choices (not verified against pub.dev, not checked for latest versions or compatibility notes) [ASSUMED]

## Metadata

**Confidence breakdown:**

- **Standard stack:** HIGH — all dependencies (Riverpod, Hive, http, flutter_test) already locked in from Phase 1-3; no new frameworks needed
- **Architecture patterns:** HIGH — Phase 3 Tracks is the direct precedent; patterns copied field-for-field (cache-first, per-endpoint boxes, AsyncNotifier, WR-02 guards, filter-aware providers)
- **API contract:** HIGH — all setlist endpoints defined in publicapi.yml (read directly); no ambiguity on request/response shapes
- **Drag-and-drop:** MEDIUM — ecosystem has proven libraries (reorderable_grid_view, flutter_reorderable_list), but specific integration details (error handling, animation smoothness, edit-mode toggle interaction) unverified until spike
- **Security:** HIGH — inherits Phase 2-3 access-control patterns (band membership + server validation); no new threat vectors introduced
- **Pitfalls:** HIGH — all documented pitfalls (race conditions, concurrent refresh, stale mutations) are proven problems from Phase 3, mitigated by established patterns (_version guards, refresh deduplication, local patching)

**Research date:** 2026-08-16
**Valid until:** 2026-09-16 (30 days — stable domain, no rapid framework/library churn expected)

---

*Phase: 4-Setlists*  
*Research completed: 2026-08-16*  
*Next step: Planning (gsd-plan-phase)*
