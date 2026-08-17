---
phase: 04-setlists
plan: 02
subsystem: ui
tags: [flutter, riverpod, setlists, crud]

# Dependency graph
requires:
  - phase: 04-setlists
    provides: SetlistListData/SetlistDetailData family AsyncNotifiers (04-01), PublicApi.listBandSetlists/getSetlist/createSetlist (04-01), SetlistDetailScreen's read-only structure (04-01)
provides:
  - PublicApi.updateSetlist/deleteSetlist
  - SetlistDetailData.updateFields(patch) / SetlistListData.removeFromList(setlistId) local-mutation methods
  - EditSetlistScreen / ConfirmDeleteSetlistDialog, reachable from SetlistDetailScreen's new AppBar edit icon and bottom Delete ListTile
affects: [04-setlists-plan-03, 04-setlists-plan-04, 04-setlists-plan-05]

actuals:
  tokens: 15461
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "SetlistListData/SetlistDetailData's _version WR-02 guard fields are no longer `// ignore: prefer_final_fields` — the guard is now non-trivially used by this plan's local-mutation methods, matching TrackListData/TrackDetailData's final state"
    - "updateSetlist unconditionally sends eventLocation/eventDate (including explicit null) rather than using the ?key omit-if-null body syntax, mirroring 03-04's updateBandTrack CR-02 fix for the identical nullable-optional-field shape"

key-files:
  created:
    - lib/features/setlists/edit_setlist_screen.dart
    - lib/features/setlists/confirm_delete_setlist_dialog.dart
    - test/features/setlists/edit_setlist_screen_test.dart
    - test/features/setlists/confirm_delete_setlist_dialog_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/providers/setlists_provider.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - test/providers/setlists_provider_test.dart
    - test/features/setlists/setlist_detail_screen_test.dart

key-decisions:
  - "Edit and delete are built without any ownership gate — BandSetlist/SetlistListItem carry no ownerId and SETL-04/SETL-05 carry no owner qualifier, matching TRACK-04/TRACK-05's precedent exactly (per the plan's objective note)"
  - "ConfirmDeleteSetlistDialog's title is the fixed copy 'Delete setlist?' (per 04-UI-SPEC.md), not an interpolated setlist name like ConfirmDeleteTrackDialog's 'Delete {title}?' — the widget still accepts a required setlistName parameter to match the plan's constructor shape, even though the dialog body doesn't render it"

requirements-completed: [SETL-04, SETL-05]

coverage:
  - id: D5
    description: "Band member edits a setlist's name/location/date via a pre-populated full-screen form; clearing a field sends an explicit null (not an omitted key), and the change is reflected on the detail screen without a redundant network refetch"
    requirement: SETL-04
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/edit_setlist_screen_test.dart#D-17: clearing the location field sends an explicit null instead of omitting the key"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/edit_setlist_screen_test.dart#submitting a changed name calls updateSetlist with the exact request body and pops back"
        status: pass
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#SetlistDetailData a local updateFields() mutation is not clobbered by a slower in-flight background refresh (WR-02)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Band member deletes a setlist via a lightweight Cancel/Delete confirm dialog, landing back on the band's setlist list (double-pop: dialog -> detail -> list)"
    requirement: SETL-05
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/confirm_delete_setlist_dialog_test.dart#Delete calls deleteSetlist(bandId, setlistId) and double-pops back to the list"
        status: pass
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#SetlistListData a local removeFromList() mutation is not reverted by a slower in-flight background refresh that still includes the removed setlist (WR-02)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-16
status: complete
---

# Phase 4 Plan 2: Setlist Edit + Delete Summary

**Per-band setlist info CRUD closed out with an EditSetlistScreen (name/location/date, D-17 always-send-all-fields) and a Cancel/Delete confirm dialog (D-18/D-19), both ungated, mirroring Phase 3's Track edit/delete pattern exactly**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-16T22:19:00Z
- **Completed:** 2026-08-16T22:24:43Z
- **Tasks:** 2
- **Files modified:** 9 (2 created, 3 modified for Task 1; 2 created, 2 modified for Task 2)

## Accomplishments
- `PublicApi` gained `updateSetlist({bandId, setlistId, name, eventLocation, eventDate})` and `deleteSetlist(bandId, setlistId)`, with `updateSetlist` unconditionally sending `eventLocation`/`eventDate` (including explicit `null` for a cleared field) — the identical CR-02 fix pattern from `updateBandTrack`
- `SetlistDetailData.updateFields(patch)` and `SetlistListData.removeFromList(setlistId)` local-mutation methods added, field-for-field mirrors of `TrackDetailData.updateFields`/`TrackListData.removeFromList`, both properly bumping the previously-unused `_version` WR-02 guard
- `EditSetlistScreen` (new): pre-filled 3-field form (name required, location/date optional), always sends all three fields on submit, merges the result into `SetlistDetailData`'s cache with no redundant refetch (`UpdateBandSetlist`'s `'200'` has no body), invalidates the list provider so row data stays fresh
- `ConfirmDeleteSetlistDialog` (new): lightweight Cancel/Delete dialog, deletes then double-pops back to `SetlistListScreen`
- `SetlistDetailScreen` extended with an AppBar edit `IconButton` (visible only once loaded) and a bottom Delete `ListTile`, both ungated per TRACK-04/TRACK-05's precedent
- Full test coverage: pre-filled values, empty-name validation, D-17's explicit-null-on-clear for both location and date, submit-in-flight spinners, `ApiException`/fallback error states for both the edit form and delete dialog, plus the two new WR-02 local-mutation-not-clobbered provider tests

## Task Commits

Each task was committed atomically:

1. **Task 1: Edit setlist (full-screen form + cache merge) and Delete setlist (confirm dialog)** - `255bd96` (feat)
2. **Task 2: Edit/delete test coverage (incl. WR-02 local-mutation guards)** - `64f9ec3` (test)

## Files Created/Modified
- `lib/api/public_api.dart` - `updateSetlist`/`deleteSetlist`
- `lib/providers/setlists_provider.dart` - `SetlistDetailData.updateFields`/`SetlistListData.removeFromList`, `_version` guards de-annotated (now genuinely used)
- `lib/features/setlists/edit_setlist_screen.dart` (new) - `EditSetlistScreen`
- `lib/features/setlists/confirm_delete_setlist_dialog.dart` (new) - `ConfirmDeleteSetlistDialog`
- `lib/features/setlists/setlist_detail_screen.dart` - AppBar edit `IconButton` + bottom Delete `ListTile`
- `test/features/setlists/edit_setlist_screen_test.dart` (new) - pre-filled/validation/D-17-null/spinner/error tests
- `test/features/setlists/confirm_delete_setlist_dialog_test.dart` (new) - confirm/cancel/double-pop/spinner/error tests
- `test/providers/setlists_provider_test.dart` - two new WR-02 local-mutation tests
- `test/features/setlists/setlist_detail_screen_test.dart` - edit icon visibility + edit/delete tap-through tests

## Decisions Made
- No ownership gating on edit/delete, per the plan's objective note (mirrors TRACK-04/TRACK-05, `BandSetlist`/`SetlistListItem` carry no `ownerId`).
- `ConfirmDeleteSetlistDialog` keeps a fixed `'Delete setlist?'` title (per 04-UI-SPEC.md's Copywriting Contract) rather than interpolating the setlist name into the title the way `ConfirmDeleteTrackDialog` does — `setlistName` remains a required constructor parameter to match the plan's specified shape, even though the current dialog body doesn't render it.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `SetlistDetailData.updateFields`/`SetlistListData.removeFromList` are now proven local-mutation methods other setlist-track mutations (Plans 03/04 — add/remove/reorder tracks within a setlist) can extend or reuse the same pattern for.
- `flutter analyze` is clean and the full `flutter test` suite (188 tests) passes with zero regressions.

---
*Phase: 04-setlists*
*Completed: 2026-08-16*

## Self-Check: PASSED

All 9 files listed in "Files Created/Modified" (plus this SUMMARY.md) verified present on disk. Both task commit hashes (`255bd96`, `64f9ec3`) verified present in `git log --oneline --all`.
