---
phase: 03-tracks
reviewed: 2026-08-16T08:32:00Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - lib/api/api_client.dart
  - lib/api/public_api.dart
  - lib/cache/cache_service.dart
  - lib/features/bands/band_detail_screen.dart
  - lib/features/songs/tracks_screen.dart
  - lib/features/tracks/confirm_delete_track_dialog.dart
  - lib/features/tracks/create_track_screen.dart
  - lib/features/tracks/edit_track_screen.dart
  - lib/features/tracks/track_detail_screen.dart
  - lib/features/tracks/track_formatting.dart
  - lib/features/tracks/track_list_screen.dart
  - lib/navigation/root_scaffold.dart
  - lib/providers/tracks_provider.dart
  - test/cache/cache_service_test.dart
  - test/features/tracks/confirm_delete_track_dialog_test.dart
  - test/features/tracks/create_track_screen_test.dart
  - test/features/tracks/edit_track_screen_test.dart
  - test/features/tracks/track_detail_screen_test.dart
  - test/features/tracks/track_list_screen_test.dart
  - test/features/tracks/tracks_screen_test.dart
  - test/providers/auth_provider_test.dart
  - test/providers/tracks_provider_test.dart
findings:
  critical: 3
  warning: 2
  info: 1
  total: 6
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-08-16T08:32:00Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Reviewed the track CRUD feature set (per-band track catalog, global cross-band Tracks tab, cache-first Riverpod providers, and their tests). The cache-first/version-guard pattern in `tracks_provider.dart` is solid and well tested (the WR-02 race-condition regression tests actually exercise the race). However, three correctness bugs were found that will reliably reproduce for real users: an edit-screen crash risk from an unconstrained server field feeding a constrained dropdown, a data-loss bug where users cannot clear previously-set optional track fields, and a global-tab staleness bug where track mutations made from a band's screens never propagate to the cross-band Tracks tab. There are also a dead no-op button and unvalidated numeric input that silently drops user intent.

## Critical Issues

### CR-01: EditTrackScreen's key dropdown crashes for any track whose `key` isn't one of the 24 client-defined values

**File:** `lib/features/tracks/edit_track_screen.dart:46, 178-186`
**Issue:** `_selectedKey` is seeded directly from server/cache data (`widget.currentTrack['key'] as String?`) and passed as `initialValue` to `DropdownButtonFormField<String>`, whose `items` is the fixed 24-entry `musicalKeys` list. `track_formatting.dart`'s own doc comment states the API's `key` field is an unconstrained string with "no server-side enum." `DropdownButton`/`DropdownButtonFormField` assert that `value` is either `null` or exactly matches one of the supplied items — any track whose `key` was set to something outside `musicalKeys` (e.g. via another client, a future web client, or directly via the API) will throw an assertion failure the moment `EditTrackScreen` builds, blocking editing of that track entirely.
**Fix:** Fall back gracefully when the current key isn't in the known list — e.g. append it as an extra `DropdownMenuItem` when not found, or don't pre-select it:
```dart
late String? _selectedKey = musicalKeys.contains(widget.currentTrack['key'])
    ? widget.currentTrack['key'] as String?
    : null;
```
(and, if the app wants to preserve the unrecognized value in this edit, surface it separately rather than silently dropping it in the dropdown).

### CR-02: Editing a track cannot clear previously-set optional fields (durationSeconds, tempo, key, notes)

**File:** `lib/features/tracks/edit_track_screen.dart:60-88`, `lib/api/public_api.dart:156-178`
**Issue:** `EditTrackScreen._submit()` computes `durationSeconds`/`tempo` via `int.tryParse` (null when the field is empty) and `notes` as `null` when the trimmed text is empty, then passes them straight to `PublicApi.updateBandTrack`. But `updateBandTrack`'s request body only includes a field `if (x != null)`. So if a user clears the Duration, Tempo, or Notes field (or otherwise wants to unset the Key) intending to remove the value, the PUT request omits that key entirely — the server (per the doc comment on `updateBandTrack`, this is a merge/partial-update semantics) keeps the old value. The user sees the field appear cleared in the form only until they leave and come back (worse: the local `updateFields` merge in `tracks_provider.dart:196-205` has the same `if (x != null)` guard the caller applies, so even the local cache silently keeps stale data). This is a guaranteed reproduction for any "clear this field" edit — not an edge case. `test/features/tracks/edit_track_screen_test.dart` has no test covering clearing an existing value, which is why this shipped unnoticed.
**Fix:** Distinguish "unchanged" from "explicitly cleared" — e.g. track which fields the user actually touched/cleared and send an explicit clear signal (empty string / sentinel) for those, or change `updateBandTrack` to always send all fields from the edit form (not just non-null ones) since `EditTrackScreen` always has a full snapshot of the current track to submit against.

### CR-03: Track create/edit/delete never invalidate the global cross-band Tracks tab, leaving it stale for the rest of the session

**File:** `lib/features/tracks/create_track_screen.dart:64`, `lib/features/tracks/edit_track_screen.dart:110-112`, `lib/features/tracks/confirm_delete_track_dialog.dart:44-50`, `lib/providers/tracks_provider.dart:229-301`
**Issue:** All three track-mutation flows only touch `trackListDataProvider(bandId)` (and, for edit, `trackDetailDataProvider`) — none of them invalidate or patch `userTracksListDataProvider`, which backs `TracksScreen` (the global "Tracks" tab, TRACK-06). Since `RootScaffold` (`lib/navigation/root_scaffold.dart:20-28`) keeps all four tab screens alive simultaneously via `IndexedStack`, `TracksScreen`'s `ConsumerWidget.build` keeps `userTracksListDataProvider` subscribed (and therefore not auto-disposed) for the app's lifetime once the tab has been visited once. The practical effect: create/edit/delete a track from inside a band's `TrackListScreen`/`TrackDetailScreen`, then switch to the "Tracks" tab — the new/edited/deleted track's title, artist, duration, or presence is stale until something else happens to change `selectedBandIdFilterProvider` (which forces a rebuild). A newly created track won't appear; a deleted track keeps showing; an edited title/artist/duration keeps showing the old value.
**Fix:** Invalidate (or patch) `userTracksListDataProvider` alongside `trackListDataProvider` in all three mutation flows, e.g.:
```dart
if (ref.exists(userTracksListDataProvider)) {
  ref.invalidate(userTracksListDataProvider);
}
```

## Warnings

### WR-01: "View bands" button in the empty Tracks tab does nothing

**File:** `lib/features/songs/tracks_screen.dart:132-137`
**Issue:** When the user has zero bands, `_buildEmptyState` renders a `View bands` `ElevatedButton` with `onPressed: () {}` — a no-op. The button is visually interactive but tapping it has no effect, which reads as broken to a user (there's no bottom-nav-index API plumbed through to let it switch to the Bands tab). No test exercises tapping it, which is presumably why this shipped.
**Fix:** Either wire it to switch `RootScaffold`'s selected tab index (would need a way to reach `_RootScaffoldState` or lift tab-switching into a provider), or remove the button until that plumbing exists.

### WR-02: Duration/Tempo fields silently drop non-numeric input with no user feedback

**File:** `lib/features/tracks/create_track_screen.dart:59-60`, `lib/features/tracks/edit_track_screen.dart:70-71`
**Issue:** `int.tryParse(_durationController.text.trim())` / `int.tryParse(_tempoController.text.trim())` are used directly as the submitted value, with no `validator` on the `TextFormField`s. If a user's input can't parse as an int (e.g. a stray non-digit character slips in on a platform where `TextInputType.number` doesn't hard-block it, or a negative sign is entered awkwardly), the field is treated as if the user left it blank — silently discarding what they typed with no error message, and (per CR-02) silently failing to update/clear it server-side either.
**Fix:** Add a `validator` that rejects non-empty-but-unparsable input, e.g.:
```dart
validator: (value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return int.tryParse(text) == null ? 'Enter a whole number' : null;
},
```

## Info

### IN-01: Cache key builders use naive string concatenation, which could theoretically collide

**File:** `lib/cache/cache_service.dart:251-252` (`_trackDetailKey`), `lib/cache/cache_service.dart:278-279` (`_userTracksKey`)
**Issue:** `_trackDetailKey(bandId, trackId) => 'detail_${bandId}_$trackId'` has no separator disambiguation — `bandId='b'`, `trackId='1_2'` produces the same key as `bandId='b_1'`, `trackId='2'`. Similarly `_userTracksKey` falls back to the literal string `'all'` for a null filter, which would collide with a real band whose id happened to be `'all'`. In practice band/track ids are server-generated UUIDs (hyphens, not underscores), so this is low risk today, and mirrors the pre-existing `_bandDetailKey` pattern already in the codebase — noted for awareness, not requiring action.
**Fix:** Not required given current ID format; if IDs ever become user-influenced strings, use a fixed-width separator or hash-based key instead.

---

_Reviewed: 2026-08-16T08:32:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
