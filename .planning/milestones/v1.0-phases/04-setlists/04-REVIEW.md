---
phase: 04-setlists
reviewed: 2026-08-17T06:22:03Z
depth: standard
files_reviewed: 27
files_reviewed_list:
  - lib/api/public_api.dart
  - lib/cache/cache_service.dart
  - lib/features/bands/band_detail_screen.dart
  - lib/features/setlists/add_setlist_tracks_dialog.dart
  - lib/features/setlists/confirm_delete_setlist_dialog.dart
  - lib/features/setlists/create_setlist_screen.dart
  - lib/features/setlists/edit_setlist_screen.dart
  - lib/features/setlists/setlist_detail_screen.dart
  - lib/features/setlists/setlist_formatting.dart
  - lib/features/setlists/setlist_list_screen.dart
  - lib/features/setlists/setlists_screen.dart
  - lib/features/songs/tracks_screen.dart
  - lib/navigation/root_scaffold.dart
  - lib/providers/navigation_provider.dart
  - lib/providers/navigation_provider.g.dart
  - lib/providers/setlists_provider.dart
  - lib/providers/setlists_provider.g.dart
  - test/cache/cache_service_test.dart
  - test/features/setlists/add_setlist_tracks_dialog_test.dart
  - test/features/setlists/confirm_delete_setlist_dialog_test.dart
  - test/features/setlists/create_setlist_screen_test.dart
  - test/features/setlists/edit_setlist_screen_test.dart
  - test/features/setlists/setlist_detail_screen_test.dart
  - test/features/setlists/setlist_list_screen_test.dart
  - test/features/setlists/setlists_screen_test.dart
  - test/providers/auth_provider_test.dart
  - test/widget_test.dart
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-08-17T06:22:03Z
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

Reviewed the full Setlists feature slice: `PublicApi` endpoints, the Hive-backed `CacheService`, the four `setlists_provider.dart` notifiers (`SetlistListData`, `SetlistDetailData`, `SelectedSetlistBandIdFilter`, `UserSetlistsListData`), and every setlist screen/dialog plus their widget tests. The implementation is generally solid — the cache-first + silent-background-refresh pattern is consistently applied, the `_version`-guard mechanism correctly prevents stale background fetches from clobbering local mutations (well covered by dedicated WR-02 tests), and the `PUT`-with-explicit-`null` semantics for clearable fields are handled and tested correctly for both `updateSetlist` and `updateBandTrack`.

No security vulnerabilities, crashes, or data-loss risks were found. The main correctness gap is that **none of the band-scoped setlist mutation flows (create/edit/delete/add-track/remove-track/reorder) invalidate or refresh the global cross-band `userSetlistsListDataProvider`** — once a user has visited the "Setlists" tab, that cache goes stale after any mutation performed from inside a band and there is no in-app way to force a resync short of an app restart. A few smaller robustness/quality issues are noted below.

## Warnings

### WR-01: Global cross-band Setlists tab cache never invalidated after band-scoped mutations

**File:** `lib/features/setlists/create_setlist_screen.dart:62`, `lib/features/setlists/edit_setlist_screen.dart:78-98`, `lib/features/setlists/confirm_delete_setlist_dialog.dart:44-50`, `lib/features/setlists/add_setlist_tracks_dialog.dart:55-64`, `lib/features/setlists/setlist_detail_screen.dart:41-53,104-119`

**Issue:** Every mutation path (create, edit, delete, add tracks, remove track, reorder) only ever invalidates/refreshes `setlistListDataProvider(bandId)` and/or `setlistDetailDataProvider(bandId, setlistId)` (see e.g. `CreateSetlistScreen._submit` invalidating only `setlistListDataProvider(widget.bandId)`, or `ConfirmDeleteSetlistDialog._delete` patching/invalidating only the band-scoped list). None of them ever touch `userSetlistsListDataProvider` (`setlists_provider.dart:271-345`), which backs the global, cross-band "Setlists" tab (`setlists_screen.dart`).

Because `RootScaffold` keeps every tab mounted inside an `IndexedStack` (`root_scaffold.dart:29`), once a user has opened the Setlists tab (populating and pinning `userSetlistsListDataProvider`'s cache), any subsequent create/edit/delete/add-track/remove-track/reorder performed from inside a band's `SetlistDetailScreen`/`SetlistListScreen` leaves that tab showing stale data (wrong name, wrong track/duration count, or a setlist that no longer exists) until the app is restarted — there is no refresh affordance on `SetlistsScreen` itself. This mirrors an equivalent gap that likely exists for `userTracksListDataProvider` in the Tracks feature, but is definitively present here.

**Fix:** After each successful mutation, also invalidate the global list when it's alive, mirroring the existing `ref.exists(...)` guard pattern already used for the band-scoped list, e.g.:
```dart
if (ref.exists(userSetlistsListDataProvider)) {
  ref.invalidate(userSetlistsListDataProvider);
}
```
Add this alongside every existing `setlistListDataProvider`/`setlistDetailDataProvider` invalidate/refresh call site listed above.

### WR-02: Track-list load failures are silently rendered as "no tracks" rather than surfaced as errors

**File:** `lib/features/setlists/create_setlist_screen.dart:178-181`, `lib/features/setlists/add_setlist_tracks_dialog.dart:153-156`

**Issue:** Both the "Add tracks (optional)" section of `CreateSetlistScreen` and the `AddSetlistTracksDialog` picker treat an `AsyncError` from `trackListDataProvider(bandId)` identically to a legitimately empty track list:
```dart
error: (error, stackTrace) => const Padding(
  padding: EdgeInsets.symmetric(vertical: 8),
  child: Text('No tracks in this band yet'), // or 'No more tracks available'
),
```
If the network call to fetch the band's tracks fails (offline, 5xx, etc.) while creating/editing a setlist, the user sees "No tracks in this band yet" / "No more tracks available" with no indication that anything went wrong or any way to retry — they'll reasonably conclude the band simply has no tracks, when in fact the fetch failed.

**Fix:** Distinguish the error case from the empty-list case, e.g. show a short inline "Couldn't load tracks" message (optionally with a retry affordance calling `ref.invalidate(trackListDataProvider(bandId))`), rather than reusing the empty-state copy.

### WR-03: No client-side enforcement of the documented 100-track cap for bulk track operations

**File:** `lib/api/public_api.dart:295-337` (doc), `lib/features/setlists/add_setlist_tracks_dialog.dart:165-167`, `lib/features/setlists/create_setlist_screen.dart` (track checklist), `lib/features/setlists/setlist_detail_screen.dart:89-136` (`_handleReorder`)

**Issue:** `addSetlistTracks`/`reorderSetlistTracks`'s doc comments both note the server enforces a 100-`trackId` max (`AddSetlistTracksRequestBody`/`ReorderSetlistTracksRequestBody`), but none of the three call sites that submit a full or partial track-id list (`AddSetlistTracksDialog._submit`, `CreateSetlistScreen._submit`, `SetlistDetailScreen._handleReorder`) guard against exceeding it. For `_handleReorder` specifically this is a real (if edge-case) functional break: `trackIds` there is always the *entire* current track list, so any setlist that has grown past 100 tracks will have **every** future drag-to-reorder deterministically fail — and the failure is shown as "Failed to reorder tracks. Refreshing..." (`setlist_detail_screen.dart:122-126`), which reads as a transient/network hiccup rather than a permanent size-limit issue, silently making reordering unusable for large setlists with no path to recovery.

**Fix:** At minimum, surface a clearer message when a reorder/add fails specifically due to the size cap (e.g. inspect the `ApiException`'s `code`, if the API exposes one for this case) instead of the generic "try again" copy; ideally, disable/guard the add-tracks selection past the 100 remaining-slot boundary.

### WR-04: `_removeTrack` has no in-flight guard against rapid repeated taps

**File:** `lib/features/setlists/setlist_detail_screen.dart:30-65`

**Issue:** Unlike every other mutating action in this feature (`_submit` in the create/edit screens, `_delete` in the confirm dialog, `_submit` in the add-tracks dialog — all of which track `_isSubmitting` and disable their trigger while a request is in flight), `_removeTrack` has no equivalent guard. The remove `IconButton` (`setlist_detail_screen.dart:268-275`) stays enabled for the full duration of the `removeSetlistTrack` + `refresh()` round trip, so a fast double-tap can fire two overlapping `DELETE` requests for the same track.

**Fix:** Track an in-flight trackId (or a simple `bool` per-row/screen) and disable the remove `IconButton` while a removal for that track is pending, consistent with the pattern used everywhere else in this feature.

## Info

### IN-01: `UserSetlistsListData._version` is declared `final` and is dead weight

**File:** `lib/providers/setlists_provider.dart:280`

**Issue:** `SetlistListData` and `SetlistDetailData` both declare `int _version = 0;` (mutable) and bump it in every local-mutation method to guard against a slower in-flight background refresh clobbering a local mutation (WR-02 pattern, doc'd and tested). `UserSetlistsListData` copies the same field and doc comment ("Monotonic counter bumped by every local-mutation method... otherwise a slower background refresh could silently revert a local mutation that landed first") but declares it `final int _version = 0;` (`setlists_provider.dart:280`) and — correctly, given it's `final` — never has a mutation method to bump it. The field and its doc comment are therefore pure copy-paste vestige: always `0`, comparison against itself is always true, and the guard does nothing useful in this class today.

**Fix:** Either delete the unused `_version` field and its stale doc comment from `UserSetlistsListData` (it currently has no local-mutation methods that would need it), or note explicitly in the comment that it's intentionally inert pending a future local-patch method, to avoid a future contributor copy-pasting the `final` typo into a class that *does* need the mutable guard.

### IN-02: `_handleReorder` reads live provider state instead of the frame's rendered snapshot

**File:** `lib/features/setlists/setlist_detail_screen.dart:89-99`

**Issue:** `_handleReorder(oldIndex, newIndex)` re-reads `ref.read(setlistDetailDataProvider(...))` fresh at call time rather than using the `tracks` list that was actually rendered when the drag started. `oldIndex`/`newIndex` are indices into the widget tree built from a specific `tracks` snapshot; if the silent background refresh in `build()` (or a `refresh()` call) resolves and replaces `state` with a differently-sized list in the (small) window between the drag starting and `onReorderItem` firing, `tracks[oldIndex]`/`removeAt(oldIndex)` could throw a `RangeError` against the newly-read, differently-shaped list. No test exercises a concurrent background-refresh-during-drag scenario.

**Fix:** Capture the `tracks` list once at the top of `_buildContent`/pass it into the drag callback instead of re-reading provider state inside `_handleReorder`, or bounds-check `oldIndex`/`newIndex` against the freshly-read list length before mutating.

### IN-03: Duplicate `_bandTracksKey`/`_bandSetlistsKey`/`_bandDetailKey` all return the identical string shape

**File:** `lib/cache/cache_service.dart:206, 230, 308`

**Issue:** `_bandDetailKey`, `_bandTracksKey`, and `_bandSetlistsKey` are all implemented identically as `'band_$bandId'`. This is safe today only because each is scoped to its own `_KeyValueStore`/Hive box (`_bandsStore`, `_tracksStore`, `_setlistsStore` respectively) — but the three near-identical private helper functions with no distinguishing content are easy to misread as interchangeable, and a future refactor that consolidates stores (or adds a new box-sharing entity) could silently introduce a key collision.

**Fix:** No functional change needed given the current one-box-per-entity design, but consider a short comment on at least one of the three noting that the shared `'band_$bandId'` shape is safe specifically because each is namespaced to a distinct Hive box, to head off a future incorrect consolidation.

---

_Reviewed: 2026-08-17T06:22:03Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
