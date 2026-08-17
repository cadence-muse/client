---
phase: 04-setlists
reviewed: 2026-08-17T00:00:00Z
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
  - test/providers/setlists_provider_test.dart
  - test/widget_test.dart
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-08-17T00:00:00Z
**Depth:** standard
**Files Reviewed:** 27
**Status:** issues_found

## Summary

Reviewed the setlists feature end-to-end: `PublicApi` setlist methods, the Hive-backed `CacheService` setlist boxes, the `SetlistListData`/`SetlistDetailData`/`UserSetlistsListData` Riverpod notifiers, and every setlist screen/dialog (list, detail with edit-mode drag-reorder, create, edit, delete-confirm, add-tracks, and the new global cross-band `SetlistsScreen`), plus their tests and the bottom-nav wiring that surfaces the new tab.

The implementation is largely solid and well-tested — the WR-02 stale-refresh race guards, the D-14 reorder-index handling, and the D-17 explicit-null-on-clear semantics are all correctly implemented and covered by targeted tests. However, one systemic gap stands out: **every setlist-mutating flow (create, edit, delete, add-tracks, remove-track, reorder) updates only the band-scoped `setlistListDataProvider`/`setlistDetailDataProvider`, never the global `userSetlistsListDataProvider` that backs the new cross-band Setlists tab** — a pattern the sibling Tracks feature (`create_track_screen.dart`, `edit_track_screen.dart`) explicitly implements but which was not carried over here. Because `RootScaffold` uses an `IndexedStack` that keeps every tab's screen (and therefore its providers) alive for the lifetime of the app session, and neither the band-scoped nor global setlist screens offer a pull-to-refresh, this isn't a transient race — it's a persistent stale-data bug for the rest of the session once the Setlists tab has been visited.

A secondary gap: `_removeTrack` in `SetlistDetailScreen` is the only mutation entry point in this phase with no `_isSubmitting`-style guard, so rapid double-taps on the remove icon can fire duplicate `removeSetlistTrack` requests.

## Critical Issues

### CR-01: Setlist mutations never invalidate/refresh the global cross-band Setlists tab

**File:** `lib/features/setlists/create_setlist_screen.dart:62`, `lib/features/setlists/edit_setlist_screen.dart:78-98`, `lib/features/setlists/confirm_delete_setlist_dialog.dart:44-50`, `lib/features/setlists/add_setlist_tracks_dialog.dart:55-64`, `lib/features/setlists/setlist_detail_screen.dart:41-53` (`_removeTrack`)

**Issue:** Every setlist mutation flow patches or invalidates only the band-scoped providers — `setlistListDataProvider(bandId)` and/or `setlistDetailDataProvider(bandId, setlistId)`. None of them touch `userSetlistsListDataProvider`, the provider backing `SetlistsScreen` (`lib/features/setlists/setlists_screen.dart`), the global cross-band "Setlists" bottom-nav tab introduced in this phase (SETL-10).

This is a proven regression versus the established sibling pattern: `lib/features/tracks/create_track_screen.dart:81-82` and `lib/features/tracks/edit_track_screen.dart:138-139` explicitly guard-and-invalidate `userTracksListDataProvider` after a track mutation. The equivalent call for setlists (`ref.exists(userSetlistsListDataProvider) ? ref.invalidate(userSetlistsListDataProvider) : null` or an inline patch) is missing from every setlist mutation site.

The impact is not a transient race that self-heals on next navigation: `RootScaffold` (`lib/navigation/root_scaffold.dart:29`) uses `IndexedStack(index: selectedIndex, children: screens)`, which — per the project's own test comment in `test/widget_test.dart:70-73` ("RootScaffold's IndexedStack mounts ProfileScreen and BandsScreen … even while the Bands tab is visible") — builds and keeps **every** tab's widget subtree mounted for the app's lifetime, not just the active one. Once a user has visited the Setlists tab, `userSetlistsListDataProvider` stays alive (it's `@riverpod` `AutoDispose`, but never loses its last listener because the watching widget never unmounts) and is never rebuilt. There is also no pull-to-refresh on either `SetlistsScreen` or `SetlistListScreen` (confirmed via `grep -rn RefreshIndicator lib/features/setlists lib/features/songs` returning no matches), and the only manual-refresh affordance is the error-state Retry button, which isn't shown once data has successfully loaded once.

Concretely: a user creates, renames, deletes, or edits the tracks of a setlist from within a band, then switches to the global Setlists tab — it will keep showing the pre-mutation list/detail for the rest of the session (stale name, stale track count/duration, a deleted setlist still listed, a newly-created setlist absent), with no way to force a refresh short of restarting the app.

**Fix:** Mirror the Tracks feature's pattern at every setlist mutation site, e.g. in `create_setlist_screen.dart`:
```dart
ref.invalidate(setlistListDataProvider(widget.bandId));
if (ref.exists(userSetlistsListDataProvider)) {
  ref.invalidate(userSetlistsListDataProvider);
}
```
and analogously in `edit_setlist_screen.dart`, `confirm_delete_setlist_dialog.dart`, `add_setlist_tracks_dialog.dart`, and `setlist_detail_screen.dart`'s `_removeTrack` (and, for consistency, after a successful `_handleReorder`, since track order technically doesn't change `tracksCount`/`durationSeconds` shown in the global list but the pattern should still be uniform). Add a regression test analogous to the existing `userTracksListDataProvider` invalidation coverage in the tracks feature to lock this in.

## Warnings

### WR-01: `_removeTrack` has no in-flight submission guard, unlike every other mutation flow in this phase

**File:** `lib/features/setlists/setlist_detail_screen.dart:30-65`

**Issue:** Every other mutating action introduced in this phase (`CreateSetlistScreen._submit`, `EditSetlistScreen._submit`, `ConfirmDeleteSetlistDialog._delete`, `AddSetlistTracksDialog._submit`) tracks an `_isSubmitting` flag and disables its trigger control while a request is in flight. `_removeTrack` does not: the `IconButton`'s `onPressed: () => _removeTrack(trackId)` (line 274) stays enabled throughout the async call, so a rapid double-tap fires two concurrent `removeSetlistTrack` calls for the same track. The second call will typically 404 against the server (track already removed), surfacing an unnecessary "Failed to remove track. Try again." snackbar to the user for an action that actually already succeeded, and triggers a redundant pair of `refresh()` calls.

**Fix:** Track per-track (or single) in-flight state and disable the remove icon while a removal is pending, e.g.:
```dart
final Set<String> _removingTrackIds = {};

Future<void> _removeTrack(String trackId) async {
  if (_removingTrackIds.contains(trackId)) return;
  setState(() => _removingTrackIds.add(trackId));
  try {
    ...
  } finally {
    if (mounted) setState(() => _removingTrackIds.remove(trackId));
  }
}
```
and gate `onPressed` on `_removingTrackIds.contains(trackId) ? null : () => _removeTrack(trackId)`.

### WR-02: Track-list load failures inside the setlist create/add-tracks flows are silently reported as "no tracks" instead of surfacing the real error

**File:** `lib/features/setlists/create_setlist_screen.dart:178-181`, `lib/features/setlists/add_setlist_tracks_dialog.dart:153-156`

**Issue:** Both `CreateSetlistScreen` and `AddSetlistTracksDialog` render `trackListDataProvider`'s `error` branch as the exact same copy used for a genuinely empty track list ("No tracks in this band yet" / "No more tracks available"). In an app whose stated core value is working reliably with no network signal (`.claude/CLAUDE.md`'s "A band member can open the app without signal … and still see their band's tracks"), this actively misleads the user: a first-time load with no cache and no connectivity looks identical to "this band genuinely has zero tracks," when in fact the correct action is "check your connection and retry," not "add tracks manually via a different flow."

**Fix:** Distinguish the error case from the true-empty case, e.g.:
```dart
error: (error, stackTrace) => const Padding(
  padding: EdgeInsets.symmetric(vertical: 8),
  child: Text("Couldn't load tracks. Check your connection and try again."),
),
```
(Retry affordance is optional given the dialog/form context, but the copy should not claim there are no tracks when the fetch simply failed.)

## Info

### IN-01: `UserSetlistsListData._version` is dead/misleading — declared `final`, never incremented, comment claims otherwise

**File:** `lib/providers/setlists_provider.dart:280`

**Issue:** `SetlistListData._version` (line 32) and `SetlistDetailData._version` (line 129) are mutable `int` fields bumped by their respective local-mutation methods (`removeFromList`, `updateFields`, `reorderTracks`) to guard against a slower in-flight background refresh clobbering a just-applied local mutation (WR-02). `UserSetlistsListData._version` (line 280) carries the identical doc comment ("Monotonic counter bumped by every local-mutation method … otherwise a slower background refresh could silently revert a local mutation that landed first (WR-02)") but is declared `final int _version = 0;` and `UserSetlistsListData` has no local-mutation methods at all — the field is copy-pasted vestigial code that can never do what its comment claims.

**Fix:** Either remove the field and its stale comment entirely (since `UserSetlistsListData` has no mutation methods to race-guard), or drop the misleading copy-pasted doc comment if the field is being kept as a forward-compatible placeholder.

---

_Reviewed: 2026-08-17T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
