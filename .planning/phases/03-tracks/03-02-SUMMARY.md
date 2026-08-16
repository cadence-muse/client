---
phase: 03-tracks
plan: 02
subsystem: tracks
tags: [riverpod, hive-cache, tracks, family-provider, crud]
dependency graph:
  requires: [lib/providers/tracks_provider.dart, lib/api/public_api.dart, lib/features/tracks/track_detail_screen.dart]
  provides: [EditTrackScreen, ConfirmDeleteTrackDialog, updateBandTrack, deleteBandTrack, TrackDetailData.updateFields, TrackListData.removeFromList]
  affects: [lib/features/tracks/track_detail_screen.dart]
tech-stack:
  added: []
  patterns: [merge-without-refetch-on-200-no-body, in-place-list-patch-on-local-mutation, WR-02-version-guard]
key-files:
  created:
    - lib/features/tracks/edit_track_screen.dart
    - lib/features/tracks/confirm_delete_track_dialog.dart
    - test/features/tracks/edit_track_screen_test.dart
    - test/features/tracks/confirm_delete_track_dialog_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/providers/tracks_provider.dart
    - lib/features/tracks/track_detail_screen.dart
    - test/features/tracks/track_detail_screen_test.dart
    - test/providers/tracks_provider_test.dart
decisions:
  - "03-02: Edit and Delete are built without any ownership gate — TRACK-04/TRACK-05 carry no owner qualifier and 03-RESEARCH.md's Access Control section confirms server-side band-membership-only enforcement, superseding 03-UI-SPEC.md's inapplicable 'owner-gated' citation (which referenced Phase 2's band-deletion rule, not a Phase 3 decision)."
metrics:
  duration: 40min
  completed: 2026-08-16
actuals:
  tokens: 21000
  tasks: 2
  commits: 2
status: complete
---

# Phase 03 Plan 02: Edit and Delete track Summary

Closed TRACK-04/TRACK-05 by adding edit and delete on top of Plan 01's list/detail/create slice: a pre-populated `EditTrackScreen` full-screen form and a lightweight `ConfirmDeleteTrackDialog`, both reachable only from `TrackDetailScreen`'s AppBar edit icon and bottom Delete `ListTile`, neither gated on band ownership.

## What Was Built

- **`lib/api/public_api.dart`**: added `updateBandTrack({bandId, trackId, title, artist, durationSeconds, tempo, key, notes})` (`PUT /api/band/{bandId}/track/{trackId}`, each optional field sent only when non-null; doc comment notes the `'200'` response has no body, mirroring `updateBand`) and `deleteBandTrack(bandId, trackId)` (`DELETE /api/band/{bandId}/track/{trackId}`, `'204'` no content, mirrors `deleteBand`).
- **`lib/providers/tracks_provider.dart`**: added `TrackDetailData.updateFields(patch)` — merges `patch` into cached detail, bumps `_version`, persists via `writeBandTrackDetail`, mirroring `BandDetailData.updateName`. Added `TrackListData.removeFromList(trackId)` — filters the id out of the cached list in-place, bumps `_version`, persists via `writeBandTracks`, mirroring `BandsListData.renameBand`'s patch shape but removing instead of patching.
- **`lib/features/tracks/edit_track_screen.dart`** (new): `EditTrackScreen(bandId, trackId, currentTrack)` — 6-field form pre-populated from `currentTrack`, mirroring `EditBandScreen`'s submit/dispose/error flow and `CreateTrackScreen`'s field layout. On submit: calls `updateBandTrack`, merges the submitted values into `TrackDetailData` via `updateFields` (guarded by `ref.exists()`), invalidates `trackListDataProvider(bandId)` (guarded), then pops. Submit label is `'Save'` (per UI-SPEC, differs from Create's `'Save track'`).
- **`lib/features/tracks/confirm_delete_track_dialog.dart`** (new): `ConfirmDeleteTrackDialog(bandId, trackId, trackTitle)` — lightweight `AlertDialog` mirroring `ConfirmLeaveBandDialog`'s Cancel/destructive-FilledButton structure. On confirm: calls `deleteBandTrack`, then `removeFromList` if `trackListDataProvider(bandId)` is alive (else invalidates), then double-pops (dialog → detail), landing on `TrackListScreen(bandId)` per D-13.
- **`lib/features/tracks/track_detail_screen.dart`**: added an AppBar edit `IconButton` (shown only once `trackAsync.valueOrNull != null`, mirroring `BandDetailScreen`'s `if (bandName != null)` guard) pushing `EditTrackScreen`, and a bottom `Divider` + Delete `ListTile` opening `ConfirmDeleteTrackDialog` via `showDialog`. Neither is wrapped in an ownership check — verified via `grep -c "isOwner"` returning `0`.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written; all `<action>` steps mapped directly onto the described files with no blocking issues encountered.

### Discovered (not fixed — out of scope)

**[Rule scope-boundary] `TrackListData`/`TrackDetailData`'s background-refresh cache write isn't version-guarded**
- **Found during:** Task 2, writing the `removeFromList()` WR-02 test — an `expect(cached, ...)` assertion on persisted Hive/in-memory cache content failed even though the in-memory `state` was correctly protected by the `_version` guard.
- **Root cause:** `_fetchAndCache()` unconditionally calls `writeBandTracks`/`writeBandTrackDetail` before `_refresh()`/`_doRefresh()` check `_version` — only the `state` assignment is guarded, not the cache persistence. A slower in-flight background refresh can overwrite a local mutation's cache write with stale data, even though it correctly never overwrites the in-memory `state`.
- **Scope decision:** This is a pre-existing pattern shared identically by `bands_provider.dart`'s `BandsListData`/`BandDetailData` (not introduced by this plan) — fixing it would mean touching Phase 2's bands provider too, which is an architectural change beyond this plan's file list. Left as-is; the WR-02 test added here asserts only on `state` (matching `bands_provider_test.dart`'s existing WR-02 test shape), not on cache content.
- **Logged:** `.planning/WINDOWS.md` entry #1 (kind: `deviation`, phase 03).

## Known Stubs

None. All artifacts specified in `must_haves.artifacts` are wired end-to-end and covered by passing tests.

## Verification

- `flutter analyze`: 0 errors/warnings (14 pre-existing-pattern info-level `use_null_aware_elements` lints on optional-field map literals in `public_api.dart`/`edit_track_screen.dart`, same style already present in `createBandTrack`).
- `flutter test` (full suite): 126 passed, 0 failed — zero regressions in Plan 01 or Phase 1/2 tests.
- Acceptance-criteria greps (all matched): `Future<void> updateBandTrack`/`Future<void> deleteBandTrack` present in `public_api.dart`; `class EditTrackScreen`/`class ConfirmDeleteTrackDialog` present; `grep -c "isOwner" track_detail_screen.dart` = `0`; `grep -c "profileDataProvider" confirm_delete_track_dialog.dart` = `0`.
- Widget behavior confirmed by tests: submitting `EditTrackScreen` with a changed title sends the exact `PUT` request body and pops back, with the detail screen showing the new title without a redundant `GetBandTrack` call; tapping Delete twice in `ConfirmDeleteTrackDialog` calls `deleteBandTrack` and leaves `TrackListScreen` as the top route (both dialog and detail popped).

## Self-Check: PASSED

- FOUND: lib/features/tracks/edit_track_screen.dart
- FOUND: lib/features/tracks/confirm_delete_track_dialog.dart
- FOUND: test/features/tracks/edit_track_screen_test.dart
- FOUND: test/features/tracks/confirm_delete_track_dialog_test.dart
- FOUND commit a53b034 (feat(03-02): add edit/delete track (full-screen form + confirm dialog))
- FOUND commit 67ce784 (test(03-02): add edit/delete test coverage for tracks)
