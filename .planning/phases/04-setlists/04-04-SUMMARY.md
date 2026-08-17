---
phase: 04-setlists
plan: 04
subsystem: ui
tags: [flutter, riverpod, reorderablelistview, dart]

# Dependency graph
requires:
  - phase: 04-01
    provides: SetlistDetailData provider (cache-first setlist detail, WR-02 _version guard)
  - phase: 04-02
    provides: SetlistDetailScreen's edit-mode toggle (_editMode) and delete-tile Column structure
  - phase: 04-03
    provides: add/remove-track flow this plan's edit-mode track list sits alongside
provides:
  - "PublicApi.reorderSetlistTracks (PUT .../tracks/reorder, full-replace trackIds)"
  - "SetlistDetailData.reorderTracks (local-patch, no-refetch mutation method)"
  - "SetlistDetailScreen edit-mode track list rendered via ReorderableListView.builder with drag handles"
affects: [04-05]

# Actuals (#2632)
actuals:
  tokens: 6315
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Column with an Expanded child that swaps between a plain ListView (read-only) and a ReorderableListView (edit mode), keeping header/toggle/delete-tile as non-reorderable Column siblings — avoids nested-scrollable/header-footer complications"
    - "onReorderItem (not onReorder) is this SDK's non-deprecated ReorderableListView callback — newIndex is already adjusted for the removed item, no manual -1 correction needed"

key-files:
  created: []
  modified:
    - lib/api/public_api.dart
    - lib/providers/setlists_provider.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - test/features/setlists/setlist_detail_screen_test.dart
    - test/providers/setlists_provider_test.dart

key-decisions:
  - "Used Flutter SDK's built-in ReorderableListView/ReorderableDragStartListener instead of a pub.dev package (04-RESEARCH.md's reorderable_grid_view/flutter_reorderable_list recommendation) — no new dependency, per the plan's deliberate deviation"
  - "Wired ReorderableListView's onReorderItem callback, not the plan's originally-cited onReorder — this project's installed Flutter 3.44.9 SDK deprecates onReorder (deprecated_member_use lint) in favor of onReorderItem, which already adjusts newIndex for the removed item, so no manual newIndex > oldIndex ? newIndex - 1 : newIndex correction is applied"

patterns-established:
  - "Edit-mode track lists that need drag-reorder split their Column into a padded, non-scrollable header section and an Expanded scrollable section that swaps list-widget type by mode, rather than embedding everything in one ListView"

requirements-completed: [SETL-08]

coverage:
  - id: D1
    description: "Drag-and-drop reorders a setlist's tracks; the new order is submitted via PUT .../tracks/reorder immediately on drop, with all original track ids preserved (none dropped) and a local state patch on success"
    requirement: SETL-08
    verification:
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#SetlistDetailData reorderTracks() reorders the tracks list to match the given trackIds, preserving each track's full map (not just its id)"
        status: pass
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#SetlistDetailData reorderTracks() is a local patch only — it never triggers a network call"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#invoking the ReorderableListView's onReorderItem callback directly submits reorderSetlistTracks with all original track ids present, in the new order (D-14)"
        status: pass
    human_judgment: true
    rationale: "The real drag gesture (finger press-hold-drag on a ReorderableListView row) is explicitly flagged manual-only in 04-VALIDATION.md's Manual-Only Verifications table — automated coverage substitutes a direct onReorderItem callback invocation, which proves the data transform and API call but not the actual gesture-recognition/visual-drag UX."
  - id: D2
    description: "A failed reorder call shows 'Failed to reorder tracks. Refreshing...' and resyncs the on-screen order with a full refresh() rather than leaving a stale/guessed order visible"
    requirement: SETL-08
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#a failing reorderSetlistTracks call shows the 'Failed to reorder tracks. Refreshing...' SnackBar and resyncs via a second getSetlist call"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-08-17
status: complete
---

# Phase 4 Plan 4: Setlist Track Reordering Summary

**Drag-and-drop setlist track reordering via Flutter SDK's ReorderableListView, submitting `PUT .../tracks/reorder` immediately on drop with a local-only state patch on success — zero new pub.dev dependencies.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-17T05:39:27Z (approx, from STATE.md)
- **Completed:** 2026-08-17
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- `PublicApi.reorderSetlistTracks` added — `PUT /api/band/{bandId}/setlist/{setlistId}/tracks/reorder` with a full-replace `trackIds` body
- `SetlistDetailData.reorderTracks` added — patches the cached setlist's `tracks` order locally (rebuilding each track's full map by id, in the new order) with no network refetch, since reordering doesn't change `durationSeconds` or track count
- `SetlistDetailScreen`'s edit-mode track list now renders via `ReorderableListView.builder` with `ReorderableDragStartListener`-wrapped drag handles coexisting with the existing per-row remove icon; `_handleReorder` fires the PUT immediately on drop (D-14, no "Save order" batching) and on failure shows a snackbar + resyncs via `refresh()`
- Automated test coverage for the data transform (`reorderTracks`), the no-network-call guarantee, the callback-driven API call with all-tracks-preserved assertion, and the failure/resync path — the real drag gesture remains an explicit manual-only UAT item per 04-VALIDATION.md

## Task Commits

Each task was committed atomically:

1. **Task 1: Drag-and-drop reorder via ReorderableListView (immediate PUT on drop)** - `5024a26` (feat)
2. **Task 2: Reorder test coverage (provider-level + callback-level, no gesture simulation)** - `f103901` (test)

## Files Created/Modified
- `lib/api/public_api.dart` - Added `reorderSetlistTracks({bandId, setlistId, trackIds})`
- `lib/providers/setlists_provider.dart` - Added `SetlistDetailData.reorderTracks(trackIds)` (local patch, `_version++` WR-02 guard, cache write)
- `lib/features/setlists/setlist_detail_screen.dart` - Edit-mode track rendering switched from a plain row-list to `ReorderableListView.builder`; `_buildContent` restructured into a `Column` with a non-scrollable header section and an `Expanded` child that swaps between `ListView` (read-only) and `ReorderableListView` (edit mode); new `_handleReorder(oldIndex, newIndex)` method
- `test/providers/setlists_provider_test.dart` - Extended with 2 `reorderTracks` unit tests (data transform + no-network-call)
- `test/features/setlists/setlist_detail_screen_test.dart` - Extended with 2 widget tests (success callback invocation, failure+resync)

## Decisions Made
- No new pub.dev dependency added — Flutter SDK's built-in `ReorderableListView`/`ReorderableDragStartListener` fully covers this plain-vertical-list drag-and-drop case, deliberately deviating from 04-RESEARCH.md's `reorderable_grid_view`/`flutter_reorderable_list` recommendation (documented in the plan's objective as an intentional deviation, not a gap)
- Wired `onReorderItem` instead of the plan-cited `onReorder` — see Deviations below

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug/lint] Used `onReorderItem` instead of the plan's cited `onReorder` callback**
- **Found during:** Task 1 (initial `flutter analyze` run after wiring `ReorderableListView`)
- **Issue:** The plan's `<read_first>` and `<action>` sections cite `ReorderableListView`'s `onReorder(oldIndex, newIndex)` callback with a manual `newIndex > oldIndex ? newIndex - 1 : newIndex` adjustment. This project's installed Flutter 3.44.9 SDK (`packages/flutter/lib/src/material/reorderable_list.dart` / `src/widgets/reorderable_list.dart`) has since deprecated `onReorder` in favor of `onReorderItem` (identical `ReorderCallback` signature, but `newIndex` already accounts for the removed item at `oldIndex` — no manual adjustment needed or correct). Using `onReorder` produced a `deprecated_member_use` info-level `flutter analyze` finding, which would have violated the task's explicit acceptance criterion ("`flutter analyze` reports zero new errors/warnings attributable to the files touched by this task"). `ReorderableListView` also asserts exactly one of `onReorder`/`onReorderItem` may be supplied, so this isn't an additive fix — it's a substitution.
- **Fix:** Wired `onReorderItem: _handleReorder` and removed the manual `newIndex -= 1` adjustment from `_handleReorder`, per the SDK's own migration guidance in the deprecation doc comment. Task 2's tests correspondingly extract and invoke `onReorderItem` (not `onReorder`) directly, matching the plan's "automated substitute for a simulated drag gesture" intent — same callback contract (`(oldIndex, newIndex) -> void`), same assertions (all original track ids present, in the new order).
- **Files modified:** `lib/features/setlists/setlist_detail_screen.dart`, `test/features/setlists/setlist_detail_screen_test.dart`
- **Verification:** `flutter analyze` reports "No issues found!"; full `flutter test` suite (201 tests) passes.
- **Committed in:** `5024a26` (Task 1), `f103901` (Task 2 test extraction)

---

**Total deviations:** 1 auto-fixed (1 bug/lint fix)
**Impact on plan:** Purely a callback-name/adjustment substitution forced by SDK deprecation between when the plan's `read_first` guidance was written and this project's currently-installed Flutter SDK. No functional or UX change — `onReorderItem`'s contract is behaviorally identical to `onReorder` plus the manual adjustment the plan specified. No scope creep.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SETL-08 (drag-and-drop track reordering) is complete; Phase 4's per-band track-management trio (SETL-06/07/08, add/remove/reorder) is now fully implemented across Plans 02-04
- `04-VALIDATION.md`'s SETL-08 automated row is closed and green; the real-gesture check remains an explicit manual-only UAT item (drag a track, confirm order updates and PUT fires)
- Plan 05 (global cross-band Setlists tab) has no blockers from this plan

---
*Phase: 04-setlists*
*Completed: 2026-08-17*
