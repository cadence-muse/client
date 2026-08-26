---
phase: 13-string-extraction-screen-localization
plan: 12
subsystem: ui
tags: [flutter, l10n, intl, riverpod, arb]

# Dependency graph
requires:
  - phase: 13-01
    provides: ARB keys (createTrack*, editTrackAppBarTitle, tracksTab*, common* shared keys) and test_strings.dart's tester.strings extension
provides:
  - create_track_screen.dart and edit_track_screen.dart fully localized (AppBar title, all field labels, all validator messages, save button, snackbar)
  - lib/features/songs/tracks_screen.dart (global cross-band Tracks tab, last of the 5 bottom-nav tabs) fully localized
  - All three widget test files migrated to assert against tester.strings.* instead of hardcoded English literals
affects: [13-string-extraction-screen-localization (remaining plans), any future i18n work touching Tracks/Songs domain]

# Actuals (#2632)
actuals:
  tokens: 10158
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Validator methods on ConsumerState (_durationValidator/_wholeNumberValidator) that run outside build()'s scope derive their own `final l10n = AppLocalizations.of(context)!;` as the first line, using the State's own `context` getter, instead of trying to close over a build()-scoped l10n."
    - "Multi-method ConsumerWidget screens (tracks_screen.dart) re-derive `l10n` locally in each method that has its own `context` parameter (_buildFilterDropdown/_buildEmptyState/_buildError), rather than threading a single l10n instance through as an extra parameter."

key-files:
  created: []
  modified:
    - lib/features/tracks/create_track_screen.dart
    - test/features/tracks/create_track_screen_test.dart
    - lib/features/tracks/edit_track_screen.dart
    - test/features/tracks/edit_track_screen_test.dart
    - lib/features/songs/tracks_screen.dart
    - test/features/tracks/tracks_screen_test.dart

key-decisions:
  - "edit_track_screen.dart's bare 'Save' button reuses the shared commonSave key, not createTrackSaveButton (which is the compound 'Save track' text unique to the create screen) — per plan's explicit distinction."
  - "tracks_screen.dart's AppBar title reuses navTracks (shared with the nav bar's 'Tracks' label) rather than a screen-specific key, and its dropdown's 'All bands' entry reuses commonAllBandsFilter (exact-match with setlists_screen.dart)."

requirements-completed: [I18N-04]

coverage:
  - id: D1
    description: "create_track_screen.dart fully localized (AppBar, field labels, validators, save button, added-snackbar) and its test asserts via tester.strings"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "test/features/tracks/create_track_screen_test.dart (9 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "edit_track_screen.dart fully localized (AppBar, field labels, validators, save button) and its test asserts via tester.strings"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "test/features/tracks/edit_track_screen_test.dart (15 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "lib/features/songs/tracks_screen.dart (global cross-band Tracks tab) fully localized (AppBar, filter dropdown, empty state, error state) and its test asserts via tester.strings"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "test/features/tracks/tracks_screen_test.dart (9 tests)"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-26
status: complete
---

# Phase 13 Plan 12: Track Create/Edit Forms + Global Tracks Tab Localization Summary

**create_track_screen.dart, edit_track_screen.dart, and the global cross-band tracks_screen.dart (last of the 5 bottom-nav tabs) fully localized via AppLocalizations, with all three widget test files migrated to tester.strings assertions.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-26T06:25:56Z (approx, per plan dispatch)
- **Completed:** 2026-08-26
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- `create_track_screen.dart`: AppBar title, all 6 field labels, all validator error messages (title/artist/duration format/negative/seconds-range/whole-number), duration helper text, save button, requires-connection tooltip/label, added-snackbar, and generic error fallback all now route through `AppLocalizations`.
- `edit_track_screen.dart`: identical substitution set as create, with the bare "Save" button correctly reusing the shared `commonSave` key (not the compound `createTrackSaveButton`) and no added-snackbar (edit has none).
- `lib/features/songs/tracks_screen.dart`: AppBar title (reusing `navTracks`), filter dropdown's "All bands" entry (reusing `commonAllBandsFilter`), empty-state title/description/view-bands-button, and error-state title/description/retry-button all localized — completing the localization of the last of the 5 `IndexedStack`-kept-alive bottom-nav tabs.
- All three test files migrated from hardcoded `find.text('...')` English literals to `tester.strings.keyName` assertions (test fixtures — track/band/artist names — stay hardcoded, per plan).

## Task Commits

Each task was committed atomically:

1. **Task 1: create_track_screen.dart + test** - `6fd26a9` (feat)
2. **Task 2: edit_track_screen.dart + test** - `ee2929f` (feat)
3. **Task 3: lib/features/songs/tracks_screen.dart (global tab) + test** - `5d565a4` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `lib/features/tracks/create_track_screen.dart` - Localized AppBar, field labels, validators, save button, snackbar, error fallback
- `test/features/tracks/create_track_screen_test.dart` - Migrated to `tester.strings.*`; added `localizationsDelegates`/`supportedLocales` to both inline `MaterialApp`s in the test file
- `lib/features/tracks/edit_track_screen.dart` - Localized AppBar, field labels, validators, save button, error fallback
- `test/features/tracks/edit_track_screen_test.dart` - Migrated to `tester.strings.*`; added `localizationsDelegates`/`supportedLocales` to both inline `MaterialApp`s in the test file
- `lib/features/songs/tracks_screen.dart` - Localized AppBar, filter dropdown, empty state, error state
- `test/features/tracks/tracks_screen_test.dart` - Migrated to `tester.strings.*`; added `localizationsDelegates`/`supportedLocales` to the test file's `MaterialApp`

## Decisions Made
- `edit_track_screen.dart`'s bare "Save" button uses `commonSave`, not `createTrackSaveButton` — the two screens' save buttons render different text ("Save" vs "Save track") and the plan explicitly called out this distinction to prevent an incorrect key reuse.
- `tracks_screen.dart`'s AppBar title reuses `navTracks` (identical text to the nav-bar tab label) instead of a new screen-specific key, per the plan's explicit reuse instruction.
- Validator methods (`_durationValidator`, `_wholeNumberValidator`) on both track screens derive `l10n` locally as their first statement (`AppLocalizations.of(context)!`), using the enclosing `State`'s own `context` getter, since these methods run during `Form.validate()` outside `build()`'s scope and can't close over a `build()`-local `l10n`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added `localizationsDelegates`/`supportedLocales` to all three test files' `MaterialApp` widgets**
- **Found during:** Task 1 (running `flutter test test/features/tracks/create_track_screen_test.dart` for the first time)
- **Issue:** The plan's action text covered app-code and test-assertion migration but didn't mention that the tests' `MaterialApp` widgets needed `localizationsDelegates`/`supportedLocales` configured. Without them, `AppLocalizations.of(context)` returns `null` inside the widget under test, and the null-check operator (`!`) throws, failing every test. This is the established pattern already used by other already-migrated test files in the codebase (e.g. `test/features/bands/create_band_screen_test.dart`).
- **Fix:** Added the standard 4-delegate list (`AppLocalizations.delegate`, `GlobalMaterialLocalizations.delegate`, `GlobalWidgetsLocalizations.delegate`, `GlobalCupertinoLocalizations.delegate`) and `supportedLocales: [Locale('en'), Locale('ru')]` to every `MaterialApp` instance across the three test files — including the two inline `MaterialApp`s inside `create_track_screen_test.dart`'s and `edit_track_screen_test.dart`'s CR-03 tests that don't use the shared `wrap()` helper.
- **Files modified:** test/features/tracks/create_track_screen_test.dart, test/features/tracks/edit_track_screen_test.dart, test/features/tracks/tracks_screen_test.dart
- **Verification:** All 33 tests across the three files pass (`flutter test test/features/tracks/create_track_screen_test.dart test/features/tracks/edit_track_screen_test.dart test/features/tracks/tracks_screen_test.dart`).
- **Committed in:** 6fd26a9 (Task 1), ee2929f (Task 2), 5d565a4 (Task 3) — each file's fix landed in its own task's commit.

---

**Total deviations:** 1 auto-fixed (1 blocking, applied identically across all 3 tasks)
**Impact on plan:** Necessary for the tests to function at all once `AppLocalizations.of(context)` calls were introduced into the app code; matches the codebase's own established test-infrastructure pattern. No scope creep.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All 3 files' `l10n.` substitution counts exceed their plan-specified minimums (create: 20 ≥ 16, edit: 19 ≥ 15, tracks_screen: 8 ≥ 8).
- `flutter analyze` on all three lib files: no issues found.
- Combined with 13-11, the entire Tracks/Songs domain's localization sweep is complete, and the last of the 5 bottom-nav tabs (global Tracks tab) is now localized.
- No blockers for subsequent 13-xx plans.

---
*Phase: 13-string-extraction-screen-localization*
*Completed: 2026-08-26*
