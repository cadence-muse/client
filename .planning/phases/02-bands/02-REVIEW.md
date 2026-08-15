---
phase: 02-bands
reviewed: 2026-08-15T00:00:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - lib/api/public_api.dart
  - lib/cache/cache_service.dart
  - lib/features/bands/band_avatar.dart
  - lib/features/bands/band_detail_screen.dart
  - lib/features/bands/bands_screen.dart
  - lib/features/bands/confirm_delete_band_dialog.dart
  - lib/features/bands/confirm_leave_band_dialog.dart
  - lib/features/bands/confirm_remove_member_dialog.dart
  - lib/features/bands/create_band_screen.dart
  - lib/features/bands/edit_band_screen.dart
  - lib/features/bands/join_band_dialog.dart
  - lib/providers/bands_provider.dart
  - lib/providers/bands_provider.g.dart
  - test/features/bands/band_detail_screen_test.dart
  - test/features/bands/bands_screen_test.dart
  - test/features/bands/create_band_screen_test.dart
  - test/features/bands/edit_band_screen_test.dart
  - test/features/bands/join_band_dialog_test.dart
  - test/providers/auth_provider_test.dart
  - test/providers/band_detail_provider_test.dart
  - test/providers/bands_provider_test.dart
  - test/widget_test.dart
findings:
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-08-15T00:00:00Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Reviewed the Phase 2 (bands) implementation: `PublicApi`'s new band endpoints, the Hive-backed `CacheService` additions for bands (`readBands`/`writeBands`/`readBandDetail`/`writeBandDetail`), the `BandsListData`/`BandDetailData` Riverpod notifiers, all band screens/dialogs, and the accompanying tests.

The most serious finding is a **cache-layer type bug that will crash the "offline read cache" feature in production** — the actual milestone deliverable for this phase — while remaining completely invisible to the test suite, because every test uses the in-memory cache double (`CacheService.inMemory()`) instead of the real Hive-backed store, so the serialization round-trip that triggers the bug never runs in CI. I reproduced the crash with a standalone Dart script mirroring Hive's real deserialization behavior (`hive: ^2.2.3`'s `BinaryReaderImpl.readMap()`/`readList()` return untyped `Map<dynamic, dynamic>`/`List<dynamic>`), confirmed below.

Beyond that, there are real state-consistency gaps around band renaming (stale list view, and a demonstrated race between background refresh and local edits — the race is explicitly worked around with a `Future.delayed` in one of the provider tests rather than fixed in the provider itself) and a systemic gap in mutation error handling across every dialog/screen in this phase.

## Critical Issues

### CR-01: Reading cached bands/band-detail from the real Hive store throws an uncaught `TypeError`, defeating the entire offline-read-cache feature

**File:** `lib/cache/cache_service.dart:23-27` (`_HiveStore.get`), `lib/cache/cache_service.dart:136-144` (`readBands`), `lib/cache/cache_service.dart:155-161` (`readBandDetail`)

**Issue:**

`_HiveStore.get()` does a **shallow** conversion of the value read back from the box:

```dart
Map<String, dynamic>? get(String key) {
  final raw = _box.get(key);
  return raw == null ? null : Map<String, dynamic>.from(raw);
}
```

`Map<String, dynamic>.from(raw)` only fixes the *top-level* map's static type. Hive's binary reader (`hive: ^2.2.3`, `lib/src/binary/binary_reader_impl.dart`) deserializes nested collections as **untyped** `Map<dynamic, dynamic>` (`readMap()` builds `<dynamic, dynamic>{}`) and `List<dynamic>` (`readList()`), regardless of what generic types were used when the value was originally written. So for a cached bands list, `cached['items']` is a `List<dynamic>` whose elements are `Map<dynamic, dynamic>`, not `Map<String, dynamic>`.

`readBands()` then does:
```dart
return (cached['items'] as List).cast<Map<String, dynamic>>();
```
`List.cast<T>()` is **lazy** — it returns a `CastList` view and performs no element-wise type check at call time, so this line does not throw inside the `try`/`catch` that's supposed to make cache reads "non-critical." The `TypeError` is deferred until something actually accesses an element — e.g. `bands_screen.dart:102` (`final band = bands[index];`) or `join_band_dialog.dart:91-93` (`.map((band) => band['id'] as String)` over `cachedBands`) — by which point it's completely outside `CacheService`'s error handling and propagates as an unhandled exception into the widget tree (crash / red error screen).

The same root cause affects `readBandDetail()`: the returned map's own nested `members` list is deserialized the same way, and `band_detail_screen.dart:82` does `(band['members'] as List).cast<Map<String, dynamic>>()` on it with the identical failure mode.

**Reproduced** with a script that mirrors Hive's actual deserialization shape:
```
cached[items] runtime type: List<dynamic>
cached[items][0] runtime type: _Map<dynamic, dynamic>
cast() call itself succeeded (lazy, no error yet)
CRASH on element access: type '_Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>' in type cast
```

This will reproduce on every real device the moment a band list or band detail is written to Hive and then re-read on a subsequent app start (the exact "open the app without signal and still see your band's tracks/setlist" scenario this milestone exists to support). It is invisible in this PR's test suite because every test (`test/features/bands/*_test.dart`, `test/providers/bands_provider_test.dart`, `test/providers/band_detail_provider_test.dart`) constructs `CacheService.inMemory()`, whose `_InMemoryStore` stores/returns the original Dart objects with no (de)serialization round-trip — so the type-widening Hive performs on nested collections never happens in tests.

**Fix:** Recursively normalize values read out of Hive before returning them, e.g.:

```dart
class _HiveStore implements _KeyValueStore {
  _HiveStore(this._box);

  final Box<Map> _box;

  @override
  Map<String, dynamic>? get(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return _deepConvert(raw) as Map<String, dynamic>;
  }

  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k as String, _deepConvert(v)));
    }
    if (value is List) {
      return value.map(_deepConvert).toList();
    }
    return value;
  }

  @override
  Future<void> put(String key, Map<String, dynamic> value) =>
      _box.put(key, value);

  @override
  Future<void> clear() => _box.clear();
}
```

Also add a widget/provider test that exercises the real `_HiveStore` (e.g. via `Hive.init()` against a temp directory, as opposed to `CacheService.inMemory()`) so this class of bug is caught by CI going forward — right now nothing in the suite ever touches the real Hive read path for bands.

## Warnings

### WR-01: Renaming a band via `EditBandScreen` leaves `BandsScreen` showing the stale old name

**File:** `lib/features/bands/edit_band_screen.dart:48-61`, `lib/providers/bands_provider.dart:146-158` (`BandDetailData.updateName`)

**Issue:** `EditBandScreen._submit()` merges the new name into `bandDetailDataProvider(bandId)` only:
```dart
if (ref.exists(bandDetailDataProvider(widget.bandId))) {
  await ref
      .read(bandDetailDataProvider(widget.bandId).notifier)
      .updateName(name);
}
```
It never touches `bandsListDataProvider`. Elsewhere in this same phase, every other mutation that should affect the list (`ConfirmDeleteBandDialog._delete()`, `ConfirmLeaveBandDialog._leave()`) explicitly calls `ref.invalidate(bandsListDataProvider)` before navigating back, with a comment citing this exact concern ("so the Bands list re-fetches ... rather than serving stale cached data"). The rename path misses this. Since `BandsScreen` stays mounted inside `RootScaffold`'s `IndexedStack` (per `test/widget_test.dart`'s own comment: "mounts ... BandsScreen ... even while the Bands tab is visible"), `bandsListDataProvider` typically stays alive with its old, now-stale, band name and won't refetch on its own — the user has to manually pull-to-refresh or leave/return to the app before the Bands list catches up. No test in this PR exercises the round-trip (rename → navigate back to Bands list).

**Fix:** Either invalidate `bandsListDataProvider` after a successful rename (simplest, consistent with delete/leave), or patch the cached list entry in place (mirroring `BandsListData.setBands()`), e.g. add a `renameBand(bandId, newName)` method to `BandsListData` and call it from `EditBandScreen._submit()`.

### WR-02: Unguarded race between silent background refresh and local state writes can silently revert a user's edit

**File:** `lib/providers/bands_provider.dart:46-53` & `:79-81` (`BandsListData._refresh` / `setBands`), `lib/providers/bands_provider.dart:116-123` & `:151-157` (`BandDetailData._refresh` / `updateName`)

**Issue:** Both notifiers fire an `unawaited` background `_refresh()` on every cache hit in `build()`. That refresh unconditionally overwrites `state` with whatever it eventually fetches:
```dart
Future<void> _refresh(String bandId) async {
  try {
    final fresh = await _fetchAndCache(bandId);
    state = AsyncData(fresh);
  } catch (_) {}
}
```
There's no ordering/version guard against a more-recent, explicit local write (`updateName()` after an edit, or `setBands()` after a join) that happened while that background fetch was still in flight. Whichever assignment to `state` lands *last* wins — if the background refresh (kicked off when the screen first opened, before the user edited anything) happens to resolve *after* `updateName()`/`setBands()` runs, it silently clobbers the just-applied local change back to the older data.

This isn't hypothetical: `test/providers/band_detail_provider_test.dart:142-151` explicitly works around this exact race with a real `Future.delayed(50ms)` rather than the provider itself preventing it:
> "a real (not just microtask-tick) delay is needed so it reliably completes before the baseline below is captured — otherwise it can race past `updateName()` and clobber the merged name back to the stale network value."

In other words, the test suite proves the race exists and papers over it with a sleep instead of the production code guarding against it. A user who edits a band's name right after opening `BandDetailScreen` (i.e. while the cache-hit's background refresh is still in flight) can have their own rename silently disappear from the UI.

**Fix:** Track whether a local mutation happened after a given refresh was kicked off (e.g. a monotonically increasing `_version` counter captured when `_refresh`/`_doRefresh` starts, only applying `state = AsyncData(fresh)` if no newer local write has occurred since), or simply cancel/ignore an in-flight background refresh's result once `updateName()`/`setBands()` has been called.

### WR-03: Every band mutation flow only catches `ApiException`, so any other failure is unhandled and shown to the user as if nothing happened

**File:** `lib/features/bands/create_band_screen.dart:52-56`, `lib/features/bands/edit_band_screen.dart:64-68`, `lib/features/bands/confirm_delete_band_dialog.dart:58-62`, `lib/features/bands/confirm_leave_band_dialog.dart:55-59`, `lib/features/bands/confirm_remove_member_dialog.dart:52-56`, `lib/features/bands/join_band_dialog.dart:117-121`

**Issue:** All six mutation call sites follow the same pattern:
```dart
try {
  ...
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```
Any exception that isn't an `ApiException` — a `SocketException`/timeout from a genuinely offline device (the exact condition this app is designed to be used in), a `FormatException` from an unexpected response body, or (per CR-01) a `TypeError` surfacing from a corrupted cache read that happens to be reached from one of these flows — is not caught. `_isSubmitting` is still reset via `finally`, so the button silently re-enables with `_errorMessage` still `null`: the user sees the spinner disappear and nothing else, with no indication anything failed, and no way to know whether to retry.

**Fix:** Add a fallback `catch (e)` (or `on Object catch (e)`) alongside the existing `on ApiException` branch in each of these six call sites, setting a generic `_errorMessage` (e.g. `'Something went wrong. Please try again.'`) so failures are never silently swallowed.

## Info

### IN-01: `ConfirmLeaveBandDialog` force-unwraps the current user's profile id

**File:** `lib/features/bands/confirm_leave_band_dialog.dart:43`

**Issue:** `ref.read(profileDataProvider).value!['id'] as String` relies on a documented-but-unenforced invariant ("this dialog is only reachable once `profileDataProvider` has resolved"). That invariant currently holds because `BandDetailScreen` keeps `profileDataProvider` alive via `ref.watch`, but it's fragile — any future refactor that opens this dialog from a different context, or that changes `BandDetailScreen`'s watch to a `read`, turns this into an uncaught `TypeError` with no user-facing error message (same failure mode as WR-03).

**Fix:** Guard defensively instead of asserting via `!`, e.g. bail out with an inline error message if `.value` is `null`, rather than trusting a cross-file invariant that isn't enforced by the type system.

### IN-02: Deleting or leaving a band never removes its cached detail entry from Hive

**File:** `lib/cache/cache_service.dart:172` (`_bandDetailKey`), `lib/features/bands/confirm_delete_band_dialog.dart:49-52`, `lib/features/bands/confirm_leave_band_dialog.dart:44-49`

**Issue:** `CacheService` has no method to remove a single `band_$bandId` entry, and neither `ConfirmDeleteBandDialog._delete()` nor `ConfirmLeaveBandDialog._leave()` calls one — they only invalidate `bandsListDataProvider`. The now-irrelevant `band_$bandId` entry is left behind in `bandsBox` indefinitely (only removed by `CacheService.clearAll()` on sign-out). Not user-visible today since band ids aren't reused, but it's an unbounded accumulation of dead cache entries with no cleanup path.

**Fix:** Add a `CacheService.removeBandDetail(bandId)` and call it from both dialogs after a successful delete/leave.

### IN-03: Invite code is trimmed twice

**File:** `lib/features/bands/join_band_dialog.dart:86`, `lib/api/public_api.dart:72`

**Issue:** `_JoinBandDialogState._submit()` does `_codeController.text.trim()` before calling `publicApi.joinBand(inviteCode: inviteCode)`, and `PublicApi.joinBand()` trims again (`inviteCode.trim()`). Harmless but redundant — pick one layer to own trimming.

**Fix:** Drop the trim from one of the two call sites (keeping it in `PublicApi.joinBand()` is safer since it protects any future caller).

---

_Reviewed: 2026-08-15T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
