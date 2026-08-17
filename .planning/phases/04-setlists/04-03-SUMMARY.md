---
phase: 04-setlists
plan: 03
subsystem: ui
tags: [flutter, riverpod, setlists, tracks]

# Dependency graph
requires:
  - phase: 04-setlists (04-01, 04-02)
    provides: SetlistListData/SetlistDetailData providers, setlist detail screen with edit/delete
provides:
  - "addSetlistTracks (bulk POST) and removeSetlistTrack (DELETE) on PublicApi"
  - "AddSetlistTracksDialog multi-select bulk-add picker"
  - "SetlistDetailScreen edit-mode toggle (_editMode) with per-row remove icon and Add-tracks entry point"
affects: [04-04 (drag-and-drop reordering extends the edit-mode scaffolding this plan built)]

# Actuals (#2632)
actuals:
  tokens: 7600
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Add/remove-track mutations always call the existing provider refresh() (network refetch) rather than local-splice/recompute, since server owns post-mutation durationSeconds/track count (SETL-09)"
    - "Edit-mode toggle (_editMode bool on a ConsumerStatefulWidget) gates both the remove-icon trailing slot and the Add-tracks entry point; Plan 04's drag-and-drop reuses this same toggle without rework"

key-files:
  created:
    - lib/features/setlists/add_setlist_tracks_dialog.dart
    - test/features/setlists/add_setlist_tracks_dialog_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - test/features/setlists/setlist_detail_screen_test.dart

key-decisions:
  - "SetlistDetailScreen converted from ConsumerWidget to ConsumerStatefulWidget to hold _editMode state, per plan instruction"
  - "Track row's trailing slot: Text(duration) in read-only mode is replaced entirely by IconButton(remove) in edit mode; duration text was moved into the subtitle alongside artist ('$artist • $duration') to free the trailing slot"

patterns-established:
  - "Edit-mode remove icon uses Icons.remove_circle_outline with colorScheme.error, tooltip 'Remove' — no confirmation dialog (contrast with setlist deletion's D-18 confirm dialog)"

requirements-completed: [SETL-06, SETL-07]

coverage:
  - id: D1
    description: "Band member can add one or more of the band's existing tracks to a setlist via a multi-select checklist dialog, submitting the whole selection in a single bulk POST call"
    requirement: SETL-06
    verification:
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#submitting with 2 tracks checked calls addSetlistTracks once with exactly those trackIds"
        status: pass
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#excludes already-in-setlist tracks from the checklist"
        status: pass
      - kind: unit
        ref: 'test/features/setlists/add_setlist_tracks_dialog_test.dart#shows "No more tracks available" when every band track is already in the setlist'
        status: pass
    human_judgment: false
  - id: D2
    description: "Band member can remove a single track from a setlist via an explicit per-row remove icon, with no confirmation dialog"
    requirement: SETL-07
    verification:
      - kind: unit
        ref: "test/features/setlists/setlist_detail_screen_test.dart#tapping a row's remove icon calls removeSetlistTrack with that trackId and refreshes via a second getSetlist call"
        status: pass
    human_judgment: false
  - id: D3
    description: "SetlistDetailScreen gains a toggleable Edit mode gating remove icons and the Add-tracks entry point"
    verification:
      - kind: unit
        ref: "test/features/setlists/setlist_detail_screen_test.dart#tapping Edit reveals a remove icon on every track row and the Add tracks button; tapping Done hides them again"
        status: pass
      - kind: unit
        ref: "test/features/setlists/setlist_detail_screen_test.dart#the Add tracks button is absent outside edit mode and present inside it"
        status: pass
    human_judgment: false
  - id: D4
    description: "Post-mutation state (track list + duration) always comes from a fresh server refetch, never client-side math"
    verification:
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#submitting with 2 tracks checked calls addSetlistTracks once with exactly those trackIds (asserts second GET setlist call)"
        status: pass
      - kind: unit
        ref: "test/features/setlists/setlist_detail_screen_test.dart#tapping a row's remove icon calls removeSetlistTrack with that trackId and refreshes via a second getSetlist call"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-17
status: complete
---

# Phase 04 Plan 03: Setlist Track Management Summary

**Bulk add-tracks picker (`AddSetlistTracksDialog`), per-row track removal, and a toggleable Edit mode on `SetlistDetailScreen` — both mutations always re-fetch via the existing provider `refresh()` rather than computing duration/track-count client-side.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-17T00:00:00Z (approx)
- **Completed:** 2026-08-17
- **Tasks:** 2
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- `PublicApi.addSetlistTracks` (bulk `POST .../setlist/{id}/tracks`) and `PublicApi.removeSetlistTrack` (`DELETE .../track/{trackId}`)
- `AddSetlistTracksDialog`: multi-select checklist excluding tracks already in the setlist, submits the whole selection in one bulk call, shows "No more tracks available" when nothing is left to add, disables + spinners while submitting
- `SetlistDetailScreen` converted to `ConsumerStatefulWidget` with an `Edit`/`Done` toggle (`_editMode`) that reveals a per-row remove icon and an "Add tracks" button, both hidden in the default read-only view
- Both add and remove flows call the existing `SetlistDetailData.refresh()` / guarded `SetlistListData.refresh()` — no local splice or recomputed duration, keeping the server the sole source of post-mutation `durationSeconds`/track array (SETL-09)

## Task Commits

1. **Task 1: Add tracks (bulk picker) + Remove track (row icon) + Edit-mode toggle** - `cd9ba88` (feat)
2. **Task 2: Add/remove/edit-mode test coverage** - `2093fe8` (test)

_No plan-metadata commit — this executor ran in worktree isolation mode; the orchestrator handles STATE.md/ROADMAP.md updates centrally after merge._

## Files Created/Modified
- `lib/api/public_api.dart` - Added `addSetlistTracks` (bulk) and `removeSetlistTrack` methods
- `lib/features/setlists/add_setlist_tracks_dialog.dart` (new) - Multi-select bulk-add picker dialog
- `lib/features/setlists/setlist_detail_screen.dart` - `ConsumerWidget` → `ConsumerStatefulWidget`; `_editMode` toggle, remove-icon rows, Add-tracks entry point, `_removeTrack()` method
- `test/features/setlists/add_setlist_tracks_dialog_test.dart` (new) - 6 tests covering exclusion filter, empty state, exact bulk payload, error paths, spinner
- `test/features/setlists/setlist_detail_screen_test.dart` - 3 new tests (edit-mode toggle, remove-track, Add-tracks visibility) + 1 pre-existing assertion updated for the new combined subtitle text

## Decisions Made
- Track row's trailing slot repurposed: duration moved into the subtitle (`'$artist • $duration'`) in both modes, freeing the trailing slot exclusively for the edit-mode remove icon — matches the plan's explicit instruction.
- No confirmation dialog on remove-track (plan's flagged interpretive assumption, consistent with D-13's "no swipe-to-dismiss" wording not requiring a confirm step, and contrasted with setlist deletion's D-18 confirm dialog).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a pre-existing test assertion broken by the plan's own row-shape change**
- **Found during:** Task 2 (extending `setlist_detail_screen_test.dart`)
- **Issue:** Task 1's plan-mandated change moved artist+duration into a single combined subtitle (`'$artist • $duration'`), which broke the pre-existing "a full BandSetlist response renders name/location/date/duration/tracks" test's `find.text('Artist One')` / `find.text('Artist Two')` assertions (previously artist and duration were separate Text widgets).
- **Fix:** Updated the two assertions to `find.text('Artist One • 3m 45s')` / `find.text('Artist Two • 3m 20s')` matching the new combined subtitle text.
- **Files modified:** test/features/setlists/setlist_detail_screen_test.dart
- **Verification:** Full test suite (197 tests) passes with zero regressions.
- **Committed in:** 2093fe8 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix to a pre-existing test broken by an intentional, plan-specified UI change)
**Impact on plan:** No scope creep — fix was required to keep the pre-existing test suite green after the plan's own row-shape change.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SETL-06/SETL-07 closed; `_editMode` scaffolding (remove-icon row shape, toggle state) is in place for Plan 04 (drag-and-drop reordering, SETL-08) to extend with drag handles without reworking the toggle itself.
- No blockers identified.

---
*Phase: 04-setlists*
*Completed: 2026-08-17*
