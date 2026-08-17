---
phase: 05-offline-trust-connectivity-ux
reviewed: 2026-08-17T15:38:38Z
depth: standard
files_reviewed: 51
files_reviewed_list:
  - lib/cache/cache_service.dart
  - lib/features/bands/band_detail_screen.dart
  - lib/features/bands/bands_screen.dart
  - lib/features/bands/confirm_delete_band_dialog.dart
  - lib/features/bands/confirm_leave_band_dialog.dart
  - lib/features/bands/confirm_remove_member_dialog.dart
  - lib/features/bands/create_band_screen.dart
  - lib/features/bands/edit_band_screen.dart
  - lib/features/bands/join_band_dialog.dart
  - lib/features/home/home_screen.dart
  - lib/features/profile/profile_screen.dart
  - lib/features/setlists/add_setlist_tracks_dialog.dart
  - lib/features/setlists/confirm_delete_setlist_dialog.dart
  - lib/features/setlists/create_setlist_screen.dart
  - lib/features/setlists/edit_setlist_screen.dart
  - lib/features/setlists/setlist_detail_screen.dart
  - lib/features/setlists/setlist_list_screen.dart
  - lib/features/setlists/setlists_screen.dart
  - lib/features/songs/tracks_screen.dart
  - lib/features/tracks/confirm_delete_track_dialog.dart
  - lib/features/tracks/create_track_screen.dart
  - lib/features/tracks/edit_track_screen.dart
  - lib/features/tracks/track_detail_screen.dart
  - lib/features/tracks/track_list_screen.dart
  - lib/navigation/root_scaffold.dart
  - lib/providers/bands_provider.dart
  - lib/providers/bands_provider.g.dart
  - lib/providers/connectivity_provider.dart
  - lib/providers/homepage_provider.dart
  - lib/providers/profile_provider.dart
  - lib/providers/setlists_provider.dart
  - lib/providers/setlists_provider.g.dart
  - lib/providers/tracks_provider.dart
  - lib/widgets/offline_banner.dart
  - lib/widgets/sync_status_badge.dart
  - test/features/bands/band_detail_screen_test.dart
  - test/features/bands/bands_screen_test.dart
  - test/features/bands/create_band_screen_test.dart
  - test/features/bands/edit_band_screen_test.dart
  - test/features/bands/join_band_dialog_test.dart
  - test/features/setlists/add_setlist_tracks_dialog_test.dart
  - test/features/setlists/confirm_delete_setlist_dialog_test.dart
  - test/features/setlists/create_setlist_screen_test.dart
  - test/features/setlists/edit_setlist_screen_test.dart
  - test/features/setlists/setlist_detail_screen_test.dart
  - test/features/setlists/setlist_list_screen_test.dart
  - test/features/setlists/setlists_screen_test.dart
  - test/offline_cross_tab_test.dart
  - test/providers/band_detail_provider_test.dart
  - test/providers/bands_provider_test.dart
  - test/providers/setlists_provider_test.dart
  - test/regression/offline_trust_regression_test.dart
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-08-17T15:38:38Z
**Depth:** standard
**Files Reviewed:** 51
**Status:** issues_found

## Summary

The phase implements offline read-caching (Hive-backed, one box per endpoint), a device-connectivity signal, staleness badges, an offline banner, and per-entity connectivity gating for mutation entry points across bands/tracks/setlists. The cache-first provider pattern (cache hit → immediate return + silent background refresh; the `_version` counter guarding against a slower background fetch clobbering a faster local mutation) is applied consistently and correctly across `bands_provider.dart`, `tracks_provider.dart`, and `setlists_provider.dart`, and is well covered by the provider tests (`bands_provider_test.dart`, `band_detail_provider_test.dart`, `setlists_provider_test.dart`). Screen-level `isOnlineProvider` gating of FABs, edit icons, and delete/remove tiles is likewise applied consistently and is exercised by good live-reactivity tests (e.g. connectivity dropping mid-dialog, mid-edit-mode).

One genuine security-relevant defect was found in `CacheService.clearAll()` (no per-store error isolation, unlike every other method in the same class), which can leave stale, un-partitioned cache data from a previous user readable by the next user on a shared device if a single Hive box's `.clear()` call fails. Three further correctness/consistency issues were found: an inconsistently-applied connectivity gate on three screens' empty-state "Create" buttons (the equivalent FAB is gated, the empty-state button is not), a narrow but real concurrent-modification data-loss window in `SetlistDetailData.reorderTracks()`, and two minor code-quality/documentation smells in `cache_service.dart`/`tracks_provider.dart`/`setlists_provider.dart`.

## Critical Issues

### CR-01: `CacheService.clearAll()` has no per-store error isolation — a single Hive failure during sign-out can leak a previous user's cached data to the next session

**File:** `lib/cache/cache_service.dart:513-519`

**Issue:** Every other public method in `CacheService` (`writeProfile`, `writeHomepage`, `writeBands`, `writeBandDetail`, `writeBandTracks`, `writeBandTrackDetail`, `writeUserTracks`, `writeBandSetlists`, `writeSetlistDetail`, `writeUserSetlists`, and all the `readX...` accessors) wraps its Hive call in `try { ... } catch (_) { }` — the file's own established, deliberate convention (documented inline as "Non-critical cache write failure; swallow..."). `clearAll()` is the one method that breaks this pattern:

```dart
Future<void> clearAll() async {
  await _profileStore.clear();
  await _homepageStore.clear();
  await _bandsStore.clear();
  await _tracksStore.clear();
  await _setlistsStore.clear();
}
```

If `_profileStore.clear()` throws (Hive I/O error, disk-full, corrupted box, concurrent-access exception — all realistic on a mobile device), the four subsequent `.clear()` calls never run, so `_homepageStore`, `_bandsStore`, `_tracksStore`, and `_setlistsStore` are left populated with the outgoing user's data.

This is a real security/privacy issue, not just a robustness nit, because none of the cache keys in this file are scoped per-user (`_bandsKey = 'bands'`, `_homepageKey = 'homepage'`, etc. are global constants — see lines 132-134). The *only* thing that prevents one user's cached bands/tracks/setlists from being visible to the next person who signs in on the same device (a shared/family tablet, a band's shared rehearsal-space device) is `AuthSession.signOut()` (`lib/providers/auth_provider.dart:41-46`) successfully awaiting `clearAll()` before the new user's session starts. Because `signOut()` is invoked fire-and-forget from `ProfileScreen`'s "Log out" `onTap` (`ref.read(authSessionProvider.notifier).signOut()`, not awaited), an exception thrown out of `clearAll()` also means `state = const AsyncData(null)` on line 45 of `auth_provider.dart` is never reached — the token was already deleted from secure storage, but `AuthSession`'s in-memory state still reports the old (now invalid) session, so the UI doesn't reliably drop to the login screen either, on top of the cache-leak risk.

**Fix:** Isolate each box's `.clear()` independently, matching the rest of the class's convention, so one failing box never blocks the others:
```dart
Future<void> clearAll() async {
  for (final store in [
    _profileStore,
    _homepageStore,
    _bandsStore,
    _tracksStore,
    _setlistsStore,
  ]) {
    try {
      await store.clear();
    } catch (_) {
      // Best-effort: a failure to clear one box must not prevent clearing
      // the others (privacy-relevant on sign-out — see CR-01).
    }
  }
}
```

## Warnings

### WR-01: Empty-state "Create"/"Add" buttons bypass `isOnlineProvider` gating, unlike the equivalent FAB on the same screen

**File:** `lib/features/bands/bands_screen.dart:96-101`, `lib/features/tracks/track_list_screen.dart:73-80`, `lib/features/setlists/setlist_list_screen.dart:73-80`

**Issue:** On `BandsScreen`, `TrackListScreen`, and `SetlistListScreen`, the FloatingActionButton is correctly gated:
```dart
floatingActionButton: FloatingActionButton(
  onPressed: isOnline ? () => Navigator.of(context).push(...) : null,
  tooltip: isOnline ? 'Add setlist' : 'Requires connection',
  ...
```
but the functionally-identical "Create Band" / "Add track" / "Add setlist" `ElevatedButton` shown in each screen's *empty-state* body is not gated at all:
```dart
// bands_screen.dart _buildContent(), empty-state branch
ElevatedButton(
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CreateBandScreen()),
  ),
  child: const Text('Create Band'),
),
```
Tapping it while offline unconditionally navigates to the create screen. The create screen's own Save/Create button is properly gated (so no invalid mutation can actually happen), but the user is allowed to fill out an entire form only to discover at submit time that the action requires connectivity — directly contrary to this phase's stated goal (a band member "at a venue, in a basement" should get feedback about connectivity *before* investing effort, matching the FAB's behavior on the exact same screen).

This gap is also invisible to the phase's own regression guard (`test/regression/offline_trust_regression_test.dart`'s `mutationControlsWithConnectivityGate` check), because that guard only asserts the string `isOnlineProvider` appears somewhere in the file (true, since the FAB references it) — it doesn't verify every mutation-triggering `onPressed` is actually gated. None of `bands_screen_test.dart`, `track_list_screen_test.dart`, or `setlist_list_screen_test.dart`'s offline tests exercise the empty-state button specifically (only the FAB is tested offline/online in each file).

**Fix:** Gate the empty-state buttons the same way the FAB is gated, e.g. in `bands_screen.dart`:
```dart
Widget _buildContent(BuildContext context, List<Map<String, dynamic>> bands, bool isOnline) {
  ...
  ElevatedButton(
    onPressed: isOnline
        ? () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateBandScreen()),
          )
        : null,
    child: const Text('Create Band'),
  ),
```
(and thread `isOnline` through to `_buildContent` the same way `TrackListScreen`/`SetlistListScreen` already thread it to their FAB); apply the equivalent change to `track_list_screen.dart` and `setlist_list_screen.dart`.

### WR-02: `SetlistDetailData.reorderTracks()` can silently drop tracks added between the drag gesture and the reorder network response

**File:** `lib/providers/setlists_provider.dart:264-285`, `lib/features/setlists/setlist_detail_screen.dart:114-177`

**Issue:** `_handleReorder()` in `setlist_detail_screen.dart` computes `trackIds` from a synchronous `ref.read()` snapshot taken *before* the `await ... .reorderSetlistTracks(...)` network round trip:
```dart
final tracks = (current.valueOrNull?['tracks'] as List?)?.cast<Map<String, dynamic>>();
final reordered = List<Map<String, dynamic>>.of(tracks)..removeAt(oldIndex)..insert(newIndex, tracks[oldIndex]);
final trackIds = [for (final track in reordered) track['trackId'] as String];
...
await ref.read(publicApiProvider).reorderSetlistTracks(..., trackIds: trackIds);
await ref.read(setlistDetailDataProvider(...).notifier).reorderTracks(trackIds);
```
`reorderTracks(trackIds)` then rebuilds the tracks list *only* from that stale `trackIds` list, filtered against whatever `state.valueOrNull['tracks']` happens to be at the moment it runs:
```dart
Future<void> reorderTracks(List<String> trackIds) async {
  final current = state.valueOrNull;
  final oldTracks = (current['tracks'] as List<dynamic>).cast<Map<String, dynamic>>();
  final trackMap = {for (final t in oldTracks) t['trackId'] as String: t};
  final reordered = [
    for (final id in trackIds)
      if (trackMap.containsKey(id)) trackMap[id]!,
  ];
  ...
  final updated = {...current, 'tracks': reordered};
  state = AsyncData(updated);
  await ref.read(cacheServiceProvider).writeSetlistDetail(bandId, setlistId, updated);
```
If the unrelated silent background refresh (`_refresh()`, fired automatically from `build()` on every cache hit) resolves during the reorder's network round trip and replaces `state` with fresher server data — e.g. because another band member added a track to this setlist from a different device in that window — `reorderTracks()` only iterates the *old, locally-captured* `trackIds`, so any track present in the fresher `state` but absent from that stale list is silently excluded from `updated['tracks']`. The result is written straight to the persisted Hive cache (`writeSetlistDetail`), so the dropped track disappears from both the in-memory state and the on-disk cache until the next full refresh corrects it.

This requires a specific timing collision (background refresh completing mid-drag-reorder, combined with a genuine concurrent server-side change), so it's narrow, but it is a real, reproducible data-loss path introduced by this phase's cache-mirroring code, not a pre-existing issue.

**Fix:** Either (a) have `reorderTracks()` union any tracks present in `current['tracks']` but absent from `trackIds` back onto the end of `reordered` (never silently drop unknown-but-present tracks), or (b) capture and compare a version/`_version`-like guard so `reorderTracks()` no-ops (falls back to a full `refresh()`, which `_handleReorder`'s catch branch already does for a failed submit) if `state` changed underneath it between the drag and the submit.

### WR-03: `CacheService`'s three `_bandDetailKey`/`_bandTracksKey`/`_bandSetlistsKey` helpers are identical, duplicated string-key generators

**File:** `lib/cache/cache_service.dart:267`, `:304`, `:426`

**Issue:** All three private static helpers produce the exact same key format from the exact same input:
```dart
static String _bandDetailKey(String bandId) => 'band_$bandId';     // line 267 — _bandsStore
static String _bandTracksKey(String bandId) => 'band_$bandId';      // line 304 — _tracksStore
static String _bandSetlistsKey(String bandId) => 'band_$bandId';    // line 426 — _setlistsStore
```
This is currently safe only because each is paired with a *different* Hive box (`_bandsStore`/`_tracksStore`/`_setlistsStore` respectively), so there's no actual key collision today. But the duplication is a maintenance trap: a future edit that reuses one of these helpers against the wrong store (or that consolidates two of the five boxes into one, which is a plausible future refactor given they're already parallel-structured) would silently start colliding cache entries across unrelated entities, and nothing in the code signals that these three methods must never be pointed at the same box.

**Fix:** Collapse to one shared private helper (e.g. `static String _bandScopedKey(String bandId) => 'band_$bandId';`) reused by all three read/write method pairs, or add an explicit doc comment on each noting "intentionally identical format — safe only because each pairs with a distinct Hive box; do not reuse across stores."

## Info

### IN-01: `UserTracksListData._version` / `UserSetlistsListData._version` doc comment is copy-pasted and inaccurate for a field that's never mutated

**File:** `lib/providers/tracks_provider.dart:291-296`, `lib/providers/setlists_provider.dart:336-341`

**Issue:** Both classes declare:
```dart
/// Monotonic counter bumped by every local-mutation method.
/// [_refresh]/[_doRefresh] capture this before their network await and
/// discard a fetched result if it changed while the fetch was in flight —
/// ...
final int _version = 0;
```
copied verbatim from sibling classes (`TrackListData`, `BandsListData`, `SetlistListData`) that do have local-mutation methods (`removeFromList`, `renameBand`, etc.) which increment `_version`. `UserTracksListData` and `UserSetlistsListData` have no such mutation methods at all, so `_version` is declared `final` and is, correctly, never bumped — but the doc comment claims behavior ("bumped by every local-mutation method") that doesn't apply to this class, which will mislead a future reader into thinking a mutation method was accidentally omitted, or into "fixing" the `final` by making it mutable without adding the corresponding bump call.

**Fix:** Replace the copy-pasted doc comment with one accurate for this class, e.g. "Always `0` — `UserTracksListData` has no local-mutation methods, so the version-guard pattern used by sibling cache-first notifiers doesn't apply here; kept only so `_refresh`/`_doRefresh` can share the same shape as `TrackListData`."

### IN-02: `_HiveStore._deepConvert` recursion has no cycle/depth guard, undocumented as an accepted risk

**File:** `lib/cache/cache_service.dart:37-47`

**Issue:** `_deepConvert` recurses through arbitrarily deep `Map`/`List` structures with no depth limit:
```dart
static dynamic _deepConvert(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key as String, _deepConvert(val)));
  }
  if (value is List) {
    return value.map(_deepConvert).toList();
  }
  return value;
}
```
Since the data only ever originates from this app's own `writeX()` calls (JSON decoded from the public API, which has bounded, known-shape responses per `publicapi.yml`), a pathological depth is not realistically reachable today, so this isn't exploitable in practice. Still, it's worth a one-line comment noting the assumption ("bounded by API response shapes; not designed to handle arbitrarily-nested/attacker-controlled input"), since the method is otherwise carefully documented (see the large doc comment directly above it) but doesn't call out this specific limit.

**Fix:** Add a short note to the existing doc comment acknowledging the assumption, or (if ever exposed to less-trusted input) add an explicit depth cap that throws/returns null past a sane limit rather than recursing unbounded.

---

_Reviewed: 2026-08-17T15:38:38Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
