---
phase: 07-cache-behavior-flip-online-first
reviewed: 2026-08-22T00:00:00Z
depth: standard
files_reviewed: 34
files_reviewed_list:
  - lib/features/bands/band_detail_screen.dart
  - lib/features/bands/bands_screen.dart
  - lib/features/home/home_screen.dart
  - lib/features/profile/profile_screen.dart
  - lib/features/setlists/setlist_detail_screen.dart
  - lib/features/setlists/setlist_list_screen.dart
  - lib/features/setlists/setlists_screen.dart
  - lib/features/songs/tracks_screen.dart
  - lib/features/tracks/track_detail_screen.dart
  - lib/features/tracks/track_list_screen.dart
  - lib/providers/bands_provider.dart
  - lib/providers/homepage_provider.dart
  - lib/providers/offline_no_cache_exception.dart
  - lib/providers/profile_provider.dart
  - lib/providers/setlists_provider.dart
  - lib/providers/tracks_provider.dart
  - lib/widgets/offline_banner.dart
  - lib/widgets/offline_no_cache_view.dart
  - test/features/bands/band_detail_screen_test.dart
  - test/features/bands/bands_screen_test.dart
  - test/features/home/home_screen_test.dart
  - test/features/profile/profile_screen_test.dart
  - test/features/setlists/add_setlist_tracks_dialog_test.dart
  - test/features/setlists/setlist_detail_screen_test.dart
  - test/features/setlists/setlist_list_screen_test.dart
  - test/features/setlists/setlists_screen_test.dart
  - test/features/tracks/track_detail_screen_test.dart
  - test/features/tracks/track_list_screen_test.dart
  - test/features/tracks/tracks_screen_test.dart
  - test/offline_cross_tab_test.dart
  - test/providers/band_detail_provider_test.dart
  - test/providers/bands_provider_test.dart
  - test/providers/homepage_provider_test.dart
  - test/providers/profile_provider_test.dart
  - test/providers/setlists_provider_test.dart
  - test/providers/tracks_provider_test.dart
  - test/regression/offline_trust_regression_test.dart
  - test/widgets/offline_banner_test.dart
findings:
  critical: 2
  warning: 3
  info: 3
  total: 8
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-08-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 34 (plus `lib/cache/cache_service.dart` and `lib/providers/connectivity_provider.dart` read as call-chain context)
**Status:** issues_found

## Summary

This phase flips six data providers (`BandsListData`/`BandDetailData`,
`TrackListData`/`TrackDetailData`, `SetlistListData`/`SetlistDetailData`,
plus the non-family `HomepageData`/`ProfileData`/`UserTracksListData`/
`UserSetlistsListData`) to an online-first fetch with a silent cache
fallback (D-03) and a dedicated `OfflineNoCacheException` empty state
(D-06). The screen-level wiring (error branches, connectivity gating,
offline banner) is consistent and well covered by the accompanying tests.

However, two cross-cutting defects undermine the core trust guarantee this
phase exists to deliver ("what you see offline is what you actually have"):

1. The `_version` guard documented and tested as protecting a local
   mutation from being clobbered by a slower in-flight `refresh()` (WR-02)
   only protects in-memory `state` — the on-disk cache write inside
   `_fetchAndCache` is unconditional, so the persisted cache **can** still
   be silently reverted by a stale background fetch even while the visible
   UI is correct. This is untested (every WR-02 test only asserts
   in-memory `state`, never `cacheService.readX()` afterwards) and directly
   contradicts this phase's offline-trust premise.
2. `TracksScreen`/`SetlistsScreen`'s band-filter `DropdownButton` can be
   given a `value` that no longer exists in `items` once the filtered band
   disappears from `bandsListDataProvider` (band deleted/left/ownership
   changed elsewhere), because the filter-selection providers are never
   reset. This trips Flutter's `DropdownButton` constructor assertion
   ("There should be exactly one item with [DropdownButton]'s value") —
   a crash in debug/profile builds and any `flutter test` run that
   reaches this state.

Both are reachable through ordinary, realistic user flows (rapid
delete-while-refreshing; leaving a band while it's the active list filter)
and neither is covered by the existing test suite.

## Critical Issues

### CR-01: WR-02's local-mutation protection guards in-memory state but not the persisted cache — a stale background refresh can silently revert the on-disk cache

**File:** `lib/providers/tracks_provider.dart:88-93,104-117,209-223,234-247`
**File:** `lib/providers/setlists_provider.dart:86-93,104-117,208-222,233-246`
**File:** `lib/providers/bands_provider.dart:96-101,112-125,235-240,251-264`

**Issue:** Every `_doRefresh()` captures `_version` before its network
await and only uses it to decide whether to commit the fetch result to
in-memory `state`:

```dart
Future<void> _doRefresh() async {
  final capturedVersion = _version;
  try {
    final fresh = await _fetchAndCache(bandId);   // <-- cache already written here
    if (_version == capturedVersion) {
      state = AsyncData(fresh);                    // <-- only *this* is version-gated
    }
  } catch (e, st) { ... }
}
```

But `_fetchAndCache` itself writes to `CacheService` **unconditionally**,
before `_doRefresh` ever checks the version:

```dart
Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
  final tracks = await ref.read(publicApiProvider).listBandTracks(bandId);
  await ref.read(cacheServiceProvider).writeBandTracks(bandId, tracks); // unconditional
  ref.read(trackListSyncedAtProvider(bandId).notifier).set(DateTime.now());
  return tracks;
}
```

Sequence that reproduces silent cache corruption (mirrors the existing
`tracks_provider_test.dart` WR-02 test, lines 234-292, but checks the
cache instead of `state`):

1. `refresh()` is triggered (e.g. pull-to-refresh) and its GET is in
   flight.
2. Before that GET resolves, `removeFromList('t2')` runs: bumps
   `_version`, sets `state = AsyncData([t1])`, and correctly writes
   `[t1]` to the cache.
3. The earlier, slower `refresh()` GET resolves with `[t1, t2]` (the
   pre-deletion server snapshot, or simply a slower response race).
   `_fetchAndCache` writes `[t1, t2]` to the cache — **overwriting** step
   2's correct write — and bumps `syncedAt` to "just synced".
4. `_doRefresh` then checks the version, sees it changed, and correctly
   skips `state = AsyncData(fresh)` — so the *visible* UI still shows
   `[t1]`.

The user sees the deletion take effect immediately and permanently in the
running app, but the persisted cache now silently contains the
already-deleted track again. If the app is force-closed and reopened
offline (or any other in-memory state is lost — e.g. `autoDispose`
providers being recreated), the deleted item reappears. This defeats the
explicit purpose of the `_version` guard (documented in this exact file as
preventing "a slower background refresh could silently revert a local
edit that landed first (WR-02)") and undermines the offline-cache-trust
guarantee this phase (D-03/D-06) is built around.

The same shape applies to every provider with both a local-mutation method
and a `_doRefresh`: `BandsListData` (`setBands`/`renameBand`/
`patchBandOwner`), `BandDetailData` (`updateName`/`rotateInviteCode`),
`TrackListData` (`removeFromList`), `TrackDetailData` (`updateFields`),
`SetlistListData` (`removeFromList`), `SetlistDetailData`
(`updateFields`/`reorderTracks`).

**Fix:** Gate the cache write (and `syncedAt` bump) on the same version
check as the state commit, not just the state assignment — e.g. move the
version check inside `_fetchAndCache`, or restructure `_doRefresh` so the
network call and the cache/state commit are one atomic, version-checked
step:

```dart
Future<void> _doRefresh() async {
  final capturedVersion = _version;
  try {
    final tracks = await ref.read(publicApiProvider).listBandTracks(bandId);
    if (_version != capturedVersion) return; // stale — discard entirely, don't touch cache
    await ref.read(cacheServiceProvider).writeBandTracks(bandId, tracks);
    ref.read(trackListSyncedAtProvider(bandId).notifier).set(DateTime.now());
    state = AsyncData(tracks);
  } catch (e, st) {
    if (state.value == null) state = AsyncError(e, st);
  }
}
```

Add a regression test asserting `cacheService.readX(...)` (not just
`state`) after the WR-02 race for at least one provider of each shape
(list + detail) to prevent this regressing again.

### CR-02: Stale band-filter selection crashes `DropdownButton` on `TracksScreen`/`SetlistsScreen` after the filtered band disappears from the bands list

**File:** `lib/features/songs/tracks_screen.dart:65-86`
**File:** `lib/features/setlists/setlists_screen.dart:62-89`
**File:** `lib/providers/tracks_provider.dart:270-284` (`SelectedBandIdFilter`)
**File:** `lib/providers/setlists_provider.dart:301-323` (`SelectedSetlistBandIdFilter`)

**Issue:** `selectedBandIdFilterProvider`/`selectedSetlistBandIdFilterProvider`
persist a chosen `bandId` and are never cleared or validated against the
current `bands` list. `_buildFilterDropdown` feeds that persisted value
straight into `DropdownButton.value`:

```dart
final selectedBandId = ref.watch(selectedBandIdFilterProvider);
return DropdownButton<String?>(
  isExpanded: true,
  value: selectedBandId,
  items: [
    const DropdownMenuItem<String?>(value: null, child: Text('All bands')),
    for (final band in bands)
      DropdownMenuItem<String?>(value: band['id'] as String, child: Text(band['name'] as String)),
  ],
  ...
);
```

`DropdownButton`'s constructor asserts `value == null || exactly one item
has that value` (`packages/flutter/lib/src/material/dropdown.dart:1027-1039`,
message: `"There should be exactly one item with [DropdownButton]'s value"`).
Reproduction:

1. User is a member of bands A and B. On the Tracks (or Setlists) tab,
   they filter to band A — `selectedBandIdFilterProvider` is set to A's
   id.
2. They leave band A, or band A is deleted, or they lose owner access via
   another screen — any of these call
   `ref.invalidate(bandsListDataProvider)` (see
   `confirm_leave_band_dialog.dart`, `confirm_delete_band_dialog.dart`,
   `create_band_screen.dart`, `join_band_dialog.dart`), so
   `bandsListDataProvider` refetches and no longer contains band A.
3. Returning to (or already sitting on) the Tracks/Setlists tab,
   `bands` no longer contains A, but `selectedBandIdFilterProvider` is
   still `A`'s id. `DropdownButton`'s `value` (`A`) now matches zero
   items in `items` (`[null, B]`) — the constructor assertion fires.

This is a hard crash in debug/profile builds and in `flutter test` (both
run with assertions enabled); in a release build (assertions stripped) it
degrades to an unselected/undefined dropdown state instead of crashing,
but the underlying data-model inconsistency is the same either way. No
existing test (`tracks_screen_test.dart`, `setlists_screen_test.dart`)
exercises "filtered band disappears from the list", so this is currently
unguarded.

**Fix:** Fall back to `null` ("All bands") whenever the persisted filter
no longer matches an available band, either by clamping the value used
for the `DropdownButton` or by resetting the filter provider when the
band list changes:

```dart
Widget _buildFilterDropdown(
  BuildContext context,
  WidgetRef ref,
  List<Map<String, dynamic>> bands,
) {
  final selectedBandId = ref.watch(selectedBandIdFilterProvider);
  final availableIds = {for (final band in bands) band['id'] as String};
  final effectiveValue =
      availableIds.contains(selectedBandId) ? selectedBandId : null;
  return DropdownButton<String?>(
    isExpanded: true,
    value: effectiveValue,
    ...
  );
}
```
(Or, better, invalidate/reset `selectedBandIdFilterProvider` inside a
`ref.listen(bandsListDataProvider, ...)` callback when the currently
selected id drops out of the fetched list, so `notifier.setFilter` state
and the rendered dropdown never diverge.)

## Warnings

### WR-01: `refresh()`'s in-flight dedup can silently swallow a follow-up refetch triggered by a second, independent mutation

**File:** `lib/features/setlists/setlist_detail_screen.dart:47-91` (`_removeTrack`)
**File:** `lib/providers/setlists_provider.dart:98-102,227-231` (`refresh()`)

**Issue:** `refresh()` dedupes concurrent calls by reusing the same
in-flight `Future`:

```dart
Future<void> refresh() {
  return _inFlightRefresh ??= _doRefresh().whenComplete(
    () => _inFlightRefresh = null,
  );
}
```

This is correct for "user taps refresh twice quickly" (its documented
intent), but `SetlistDetailScreen._removeTrack` also calls `.refresh()`
as its post-mutation resync step, and `_removeTrack` has no cross-track
lock — only same-track double-taps are guarded via `_removingTrackIds`.
If a user removes two *different* tracks in quick succession:

1. Remove track `t1` succeeds; its `.refresh()` call starts a GET and
   sets `_inFlightRefresh`.
2. Before that GET resolves, remove track `t2` succeeds; its `.refresh()`
   call reuses the *same* in-flight future (`_inFlightRefresh ??= ...`)
   instead of issuing a fresh GET.
3. The single GET in flight was issued right after `t1`'s deletion but
   before (or racing) `t2`'s deletion reached the server, so its response
   may still include `t2`.

The screen can end up still showing `t2` after both removals report
success, requiring a manual re-entry into the screen to self-correct.

**Fix:** Either give `refresh()` a "re-run once more after the current
one completes if requested while in flight" semantics (a pending-request
flag checked in `whenComplete`), or have mutation call sites that need a
guaranteed post-mutation resync bypass the dedup (call `_doRefresh()`
directly, or track a separate "dirty" flag consumed by the in-flight
call before it clears `_inFlightRefresh`).

### WR-02: `syncedAt` is bumped even when the paired cache write silently failed

**File:** `lib/cache/cache_service.dart:146-156` (representative `writeProfile`, same shape repeated for all 10 `writeX` methods)
**File:** `lib/providers/tracks_provider.dart:88-93,209-223,354-363`
**File:** `lib/providers/setlists_provider.dart:86-93,208-222,405-416`
**File:** `lib/providers/bands_provider.dart:96-101,235-240`
**File:** `lib/providers/homepage_provider.dart:77-84`
**File:** `lib/providers/profile_provider.dart:77-84`

**Issue:** Every `CacheService.writeX` method swallows its own
exceptions:

```dart
Future<void> writeBandTracks(String bandId, List<Map<String, dynamic>> data) async {
  try {
    await _tracksStore.put(_bandTracksKey(bandId), {
      'items': data,
      'syncedAt': DateTime.now().toIso8601String(),
    });
  } catch (_) {
    // Non-critical cache write failure; swallow and keep serving the
    // in-memory/network data instead.
  }
}
```

Every provider's `_fetchAndCache` then unconditionally sets its own
in-memory `XSyncedAtProvider` to `DateTime.now()` right after `await`ing
that write, with no way to know whether the write actually succeeded:

```dart
Future<List<Map<String, dynamic>>> _fetchAndCache(String bandId) async {
  final tracks = await ref.read(publicApiProvider).listBandTracks(bandId);
  await ref.read(cacheServiceProvider).writeBandTracks(bandId, tracks); // may have silently no-op'd
  ref.read(trackListSyncedAtProvider(bandId).notifier).set(DateTime.now()); // still claims success
  return tracks;
}
```

If the on-disk write fails (full disk, Hive box corruption, etc.), the
running app still reports "just synced" via the `XSyncedAtProvider`
family even though the persisted cache didn't actually change. This is
lower severity than CR-01 because it doesn't corrupt visible data in the
current session, but it's a real correctness gap in a signal whose entire
purpose is to tell the user how fresh their offline data is.

**Fix:** Have `writeX` methods surface success/failure (e.g. return
`bool` or rethrow) so callers only bump `syncedAt` after a confirmed
write, or read back `readXSyncedAt()` after the write instead of stamping
`DateTime.now()` unconditionally.

### WR-03: The entire `XSyncedAt` provider family is defined, tested, and continuously updated but never consumed by any screen

**File:** `lib/providers/bands_provider.dart:19-25,30-35`
**File:** `lib/providers/tracks_provider.dart:18-24,144-150,286-298`
**File:** `lib/providers/setlists_provider.dart:17-23,140-150,325-336`
**File:** `lib/providers/homepage_provider.dart:15-21`
**File:** `lib/providers/profile_provider.dart:15-21`

**Issue:** `BandsListSyncedAt`, `BandDetailSyncedAt`, `TrackListSyncedAt`,
`TrackDetailSyncedAt`, `UserTracksSyncedAt`, `SetlistListSyncedAt`,
`SetlistDetailSyncedAt`, `UserSetlistsSyncedAt`, `HomepageSyncedAt`, and
`ProfileSyncedAt` are ten separate notifier classes, each `.set(...)` on
every fetch/mutation across all six data providers — but
`grep -rl "SyncedAtProvider" lib/features` returns nothing: no screen in
this phase (or anywhere else in `lib/`) ever `watch`es or `read`s any of
them. They exist only as tested, maintained infrastructure with no UI
consumer.

**Fix:** Either wire a "last synced" indicator into the offline-state UI
(the natural place given `OfflineBanner`/`OfflineNoCacheView` already
exist), or remove the unused provider family and its associated
`cache.readXSyncedAt()` plumbing until there's an actual consumer, to
avoid maintaining dead surface area indefinitely.

## Info

### IN-01: `TrackDetailScreen`/`SetlistDetailScreen` reuse their list-screen's plural error copy

**File:** `lib/features/tracks/track_detail_screen.dart:163-167`
**File:** `lib/features/setlists/setlist_detail_screen.dart:436-439`

**Issue:** `TrackDetailScreen._buildError` shows `"Couldn't load tracks"`
— identical to `TrackListScreen`'s error text — even though it's
displaying a single track. `SetlistDetailScreen._buildError` similarly
shows `"Failed to load setlists. Tap to try again."` for a single
setlist. `BandDetailScreen`, by contrast, correctly differentiates with
`"Couldn't load band details"` vs `BandsScreen`'s `"Couldn't load
bands"`.
**Fix:** Give the two detail screens their own singular copy, e.g.
`"Couldn't load track"` / `"Couldn't load setlist"`.

### IN-02: Setlist screens use an older, inconsistent error-state layout

**File:** `lib/features/setlists/setlist_list_screen.dart:157-174`
**File:** `lib/features/setlists/setlist_detail_screen.dart:429-446`
**File:** `lib/features/setlists/setlists_screen.dart:172-189`

**Issue:** All three setlist screens' `_buildError` use a single
`Text('Failed to load setlists. Tap to try again.')` + Retry button,
while every other screen touched by this phase (`BandsScreen`,
`TrackListScreen`, `TrackDetailScreen`, `HomeScreen`, `ProfileScreen`,
`BandDetailScreen`, `TracksScreen`) uses a headline + explanatory
subtitle + Retry button pattern (`"Couldn't load X"` /
`"Please check your connection and try again."`). Visually and
tonally inconsistent within the same phase's UI.
**Fix:** Align the setlist screens' error state to the shared
headline+subtitle+Retry pattern used everywhere else.

### IN-03: `data!` force-unwrap in `HomepageData`/`ProfileData`'s fetch path

**File:** `lib/providers/homepage_provider.dart:77-84`
**File:** `lib/providers/profile_provider.dart:77-84`

**Issue:**
```dart
Future<Map<String, dynamic>> _fetchAndCache() async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.send('GET', '/api/homepage');
  final homepage = data!;
  ...
}
```
`ApiClient.send` is typed `Future<Map<String, dynamic>?>` — if the server
ever returns an empty/`null`-decoded body (e.g. an unexpected `204`),
this throws a raw `TypeError` from the `!` operator. It happens to be
caught by the surrounding `try/catch` in `build()` and treated as a
generic online-fetch failure, so it's not a crash today, but the intent
("no body means something's wrong") is expressed implicitly via a null
assertion rather than an explicit, self-documenting check.
**Fix:** Replace with an explicit null check that throws a descriptive
exception, e.g. `if (data == null) throw StateError('Empty /api/homepage response');`.

---

_Reviewed: 2026-08-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
