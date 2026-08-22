---
phase: 09-homepage-quick-actions
plan: 01
subsystem: ui
tags: [flutter, riverpod, material-design, bottom-sheet, navigation]

# Dependency graph
requires:
  - phase: 06
    provides: bandsListDataProvider (online-first cached band list), reused as-is for the picker's data source
provides:
  - "HomeScreen unified welcome-card + Quick Actions layout for zero-bands and populated states"
  - "showBandPickerSheet() shared band-picker bottom sheet (lib/features/home/band_picker_sheet.dart)"
  - "Add Band / Add Song / Add Setlist quick actions wired to CreateBandScreen/CreateTrackScreen/CreateSetlistScreen"
affects: []

# Actuals (#2632)
actuals:
  tokens: 8900
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared band-picker as a standalone show*() top-level function (mirrors join_band_dialog.dart), using a Consumer inside showModalBottomSheet's builder to watch bandsListDataProvider reactively for loading/error/data states"
    - "Post-sheet navigation performed from the outer BuildContext (never the sheet's own context), after checking context.mounted, mirroring join_band_dialog.dart's pop-then-push pattern"

key-files:
  created:
    - lib/features/home/band_picker_sheet.dart
    - test/features/home/band_picker_sheet_test.dart
  modified:
    - lib/features/home/home_screen.dart
    - test/features/home/home_screen_test.dart

key-decisions:
  - "D-01/D-02/D-03: Home's _buildContent restructured into one unified layout (welcome card + Quick Actions header + 3-button row) for both zero-bands and populated states, replacing the old bandsCount==0-only empty-state block and the old populated-state band-count text entirely."
  - "D-05/D-06/D-07/D-08: band-picker is a bottom sheet backed directly by bandsListDataProvider (no new provider), always opens regardless of band count (including exactly 1), and a dismiss-without-selection is a silent no-op."
  - "D-09/D-10: all 3 quick-action buttons always render; only Add Song/Add Setlist's onPressed flips between null and the picker callback based on bandsCount."
  - "D-11: Add Band pushes CreateBandScreen directly; Add Song/Add Setlist push CreateTrackScreen/CreateSetlistScreen(bandId) only after a picker selection, from the outer context per join_band_dialog.dart's established pattern."
  - "Task 2 required no production-code changes -- Task 1's implementation already satisfied D-07/D-08/D-09 as designed, so Task 2 was test-only (new edge-case coverage plus the plan's own Rule-1-style rewrite of stale pre-Phase-9 assertions, folded into Task 1's commit since those assertions targeted layout Task 1 itself removed)."

patterns-established:
  - "Standalone show*() bottom-sheet functions that need reactive provider data inside showModalBottomSheet's builder wrap the content in a Consumer, rather than trying to reuse the caller's WidgetRef directly (which would not re-trigger the sheet's own rebuild on state changes)."

requirements-completed: [HOME-01, HOME-02]

coverage:
  - id: D1
    description: "Tapping 'Add Band' on the Homepage navigates directly to CreateBandScreen, with no picker, regardless of bandsCount"
    requirement: "HOME-01"
    verification:
      - kind: unit
        ref: "test/features/home/home_screen_test.dart#tapping \"Add Band\" navigates to CreateBandScreen (HOME-01)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tapping 'Add Song' with bandsCount > 0 opens a band-picker bottom sheet listing every band by name only; selecting a band navigates to CreateTrackScreen carrying that band's id"
    requirement: "HOME-02"
    verification:
      - kind: unit
        ref: "test/features/home/home_screen_test.dart#tapping \"Add Song\" with bandsCount > 0 opens a bottom sheet listing each seeded band by name, and selecting one navigates to CreateTrackScreen carrying that band's id (HOME-02)"
        status: pass
      - kind: unit
        ref: "test/features/home/band_picker_sheet_test.dart#selecting a band with forTrack true navigates to CreateTrackScreen carrying that band's id"
        status: pass
    human_judgment: false
  - id: D3
    description: "Tapping 'Add Setlist' with bandsCount > 0 opens the same band-picker; selecting a band navigates to CreateSetlistScreen carrying that band's id"
    requirement: "HOME-02"
    verification:
      - kind: unit
        ref: "test/features/home/home_screen_test.dart#tapping \"Add Setlist\" with bandsCount > 0 opens a bottom sheet listing each seeded band by name, and selecting one navigates to CreateSetlistScreen carrying that band's id (HOME-02)"
        status: pass
      - kind: unit
        ref: "test/features/home/band_picker_sheet_test.dart#selecting a band with forTrack false navigates to CreateSetlistScreen carrying that band's id"
        status: pass
    human_judgment: false
  - id: D4
    description: "'Add Song'/'Add Setlist' render visibly but disabled when bandsCount == 0; 'Add Band' stays enabled; all three enabled when bandsCount > 0"
    requirement: "HOME-02"
    verification:
      - kind: unit
        ref: "test/features/home/home_screen_test.dart#bandsCount 0 renders Quick Actions with Add Song/Add Setlist disabled and Add Band enabled (D-02/D-09/D-10)"
        status: pass
      - kind: unit
        ref: "test/features/home/home_screen_test.dart#bandsCount > 0 renders Quick Actions with all three buttons enabled (D-03/D-10)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Band-picker always opens even with exactly one band (no auto-skip); dismissing without a selection closes it with no error/snackbar, leaving the user on Home"
    verification:
      - kind: unit
        ref: "test/features/home/home_screen_test.dart#bandsCount == 1 still opens the band-picker sheet rather than auto-navigating straight to the create screen (D-07)"
        status: pass
      - kind: unit
        ref: "test/features/home/home_screen_test.dart#dismissing the band-picker without selecting closes it, leaves the user on Home, with no error or SnackBar (D-08)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Picker handles bandsListDataProvider's loading/error/data states, honors the offline cache fallback, and truncates long band names with an ellipsis"
    verification:
      - kind: unit
        ref: "test/features/home/band_picker_sheet_test.dart#shows a loading spinner while bands are still loading"
        status: pass
      - kind: unit
        ref: "test/features/home/band_picker_sheet_test.dart#shows a short generic error message on a bandsListDataProvider error, with no interpolated exception/stack-trace text (V7)"
        status: pass
      - kind: unit
        ref: "test/features/home/band_picker_sheet_test.dart#with isOnline false and bands pre-seeded in the cache, opening the picker still lists the cached bands (Phase 7 online-first fallback)"
        status: pass
      - kind: unit
        ref: "test/features/home/band_picker_sheet_test.dart#a band name longer than the picker ListTile width truncates to one line with ellipsis"
        status: pass
    human_judgment: false
  - id: D7
    description: "Quick-action button row and band-picker sheet render correctly across light/dark theme and at minimum mobile widths (visual/backstop checks from 09-UI-SPEC.md's Design Verification Checklist)"
    verification: []
    human_judgment: true
    rationale: "09-UI-SPEC.md flags 2 backstop items (button-row overflow at minimum mobile widths, sheet scroll behavior for long band lists) as visual tests requiring human confirmation -- not verifiable by widget-test assertions alone."

# Metrics
duration: 25min
completed: 2026-08-22
status: complete
---

# Phase 9 Plan 1: Homepage Quick Actions Summary

**Home screen restructured into a unified welcome-card + Quick Actions layout with three buttons (Add Band/Song/Setlist); Add Song and Add Setlist open a shared `band_picker_sheet.dart` bottom sheet backed by `bandsListDataProvider` before handing off to the existing create screens.**

## Performance

- **Duration:** 25 min
- **Tasks:** 2 completed
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments

- `HomeScreen._buildContent` now renders one layout for both zero-bands and populated states: a rounded welcome card (room reserved for a future avatar), a "Quick Actions" header, and a `Wrap` row of three `ElevatedButton.icon` widgets (D-01/D-02/D-03/D-10).
- New `lib/features/home/band_picker_sheet.dart` exports `showBandPickerSheet()`, a shared bottom-sheet band picker backed directly by `bandsListDataProvider` (no new provider/fetch), rendering loading/error/data states and truncating long band names.
- "Add Band" always pushes `CreateBandScreen` directly; "Add Song"/"Add Setlist" are disabled until `bandsCount > 0`, then open the picker and push `CreateTrackScreen(bandId)`/`CreateSetlistScreen(bandId)` from the outer context on selection.
- Picker always opens regardless of band count (no single-band auto-skip, D-07); dismissing it without a selection is a silent no-op (D-08); the picker's error branch shows a short generic message with no interpolated exception text (V7).

## Task Commits

Each task was committed atomically:

1. **Task 1: Home quick-actions layout + band-picker end-to-end (HOME-01, HOME-02 happy path)** - `866dc56` (feat)
2. **Task 2: Edge cases, offline picker, and pre-existing test repair (D-03/D-07/D-08/D-09 coverage)** - `76483cd` (test)

## Files Created/Modified

- `lib/features/home/band_picker_sheet.dart` - New shared band-picker bottom sheet function (`showBandPickerSheet`)
- `lib/features/home/home_screen.dart` - Restructured `_buildContent` into the welcome card + Quick Actions + button row layout
- `test/features/home/band_picker_sheet_test.dart` - New widget tests for the picker's loading/error/data states, navigation, long-name truncation, and offline cache fallback
- `test/features/home/home_screen_test.dart` - Rewrote stale pre-Phase-9 assertions (old empty-state/band-count text) against the new layout; added HOME-01/HOME-02 navigation tests and D-07/D-08 edge-case tests

## Decisions Made

- Extracted the band-picker into its own file (`band_picker_sheet.dart`) rather than a private method in `home_screen.dart`, mirroring `join_band_dialog.dart`'s standalone-function pattern for a cleaner, independently-testable unit.
- Inside `showModalBottomSheet`'s builder, wrapped the content in a `Consumer` (rather than reusing the caller's `WidgetRef` directly) so the sheet correctly reacts to `bandsListDataProvider`'s loading/error/data transitions.
- Rewrote the four pre-Phase-9 `home_screen_test.dart` assertions that targeted the removed empty-state block and band-count display text, replacing them with assertions against the new unified layout (Quick Actions header, button enabled/disabled state) — done in Task 1 rather than deferred to Task 2, since Task 1's own `<verify>` step requires the full file to pass.

## Deviations from Plan

None - plan executed exactly as written. Task 2 required no production-code changes since Task 1's implementation already satisfied D-07/D-08/D-09; per the plan's own text, Task 2 was test-only.

## Issues Encountered

- Initial `band_picker_sheet_test.dart` test for the "Add Setlist" navigation path crashed with a type error, because `CreateSetlistScreen` (mounted after band selection) additionally fetches that band's track list on build, and the test's mock HTTP handler answered every request with the band-list JSON shape (missing `title`/`artist` fields tracks expect). Fixed by routing the mock handler by request path (`/api/band/list` vs. everything else) so the track-list fetch resolves to an empty list instead of a mismatched shape.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 9 (Homepage Quick Actions) is fully implemented: HOME-01 and HOME-02 happy paths and edge cases are covered by 19 passing widget tests in `test/features/home/`, and the full suite (406 tests total, all passing) shows no regressions elsewhere. `flutter analyze` is clean repo-wide. No blockers for subsequent phases; `bands_screen.dart`'s own FAB + Create/Join menu was left untouched per D-04, and no new refresh wiring was needed on Home per D-12.

---
*Phase: 9-Homepage Quick Actions*
*Completed: 2026-08-22*

## Self-Check: PASSED

- FOUND: lib/features/home/band_picker_sheet.dart
- FOUND: lib/features/home/home_screen.dart
- FOUND: test/features/home/band_picker_sheet_test.dart
- FOUND: test/features/home/home_screen_test.dart
- FOUND: .planning/phases/09-homepage-quick-actions/09-01-SUMMARY.md
- FOUND commit: 866dc56 (Task 1)
- FOUND commit: 76483cd (Task 2)
