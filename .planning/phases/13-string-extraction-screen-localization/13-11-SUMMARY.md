---
phase: 13-string-extraction-screen-localization
plan: 11
subsystem: ui
tags: [flutter, i18n, l10n, intl, tracks]

requires:
  - phase: 13-string-extraction-screen-localization
    provides: "ARB keys (app_en.arb/app_ru.arb) for the Tracks feature, plus test_strings.dart's tester.strings extension, both landed by 13-01"
provides:
  - "track_list_screen.dart, track_detail_screen.dart, and confirm_delete_track_dialog.dart fully localized via AppLocalizations"
  - "Their three widget test files migrated to assert against tester.strings.* instead of hardcoded English"
affects: [14-api-error-localization]

actuals:
  tokens: 7031
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "final l10n = AppLocalizations.of(context)! derived per-build-method (build(), _buildContent(), _buildError()) since each has its own context"
    - "Widget tests wrap MaterialApp with AppLocalizations.delegate + Global*Localizations.delegate + supportedLocales [en, ru] so tester.strings can resolve the live AppLocalizations instance"

key-files:
  created: []
  modified:
    - lib/features/tracks/track_list_screen.dart
    - test/features/tracks/track_list_screen_test.dart
    - lib/features/tracks/track_detail_screen.dart
    - test/features/tracks/track_detail_screen_test.dart
    - lib/features/tracks/confirm_delete_track_dialog.dart
    - test/features/tracks/confirm_delete_track_dialog_test.dart

key-decisions:
  - "trackListAddButton reused for both the FAB tooltip and the empty-state button label per D-01, matching the plan's artifact spec"
  - "OfflineNoCacheView's own copy ('No cached data', 'Connect to the internet to load this') was left hardcoded in track_list_screen_test.dart and track_detail_screen_test.dart — that widget is out of this plan's file scope (not localized by 13-01 Task 2's ARB additions), so migrating its test assertions belongs to whichever plan localizes that shared widget"

patterns-established: []

requirements-completed: [I18N-04]

coverage:
  - id: D1
    description: "track_list_screen.dart fully localized (AppBar title, FAB tooltip/empty-state button, empty state copy, error state copy) via AppLocalizations"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "test/features/tracks/track_list_screen_test.dart (9 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "track_detail_screen.dart fully localized (fallback title, edit tooltip, tempo line, delete label, error state copy) via AppLocalizations"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "test/features/tracks/track_detail_screen_test.dart (9 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "confirm_delete_track_dialog.dart fully localized (title interpolation, body copy, cancel/delete buttons, requires-connection tooltip, generic error fallback) via AppLocalizations"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "test/features/tracks/confirm_delete_track_dialog_test.dart (7 tests)"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-26
status: complete
---

# Phase 13 Plan 11: Tracks Screens Localization Summary

**Localized the per-band Tracks feature's list, detail, and delete-confirm screens to route every visible string through `AppLocalizations`, using ARB keys already landed by 13-01.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3/3 completed
- **Files modified:** 6

## Accomplishments
- `track_list_screen.dart` — AppBar title, FAB tooltip/empty-state button label, empty-state title/description, and error-state copy all route through `l10n`.
- `track_detail_screen.dart` — fallback title, edit-tooltip, tempo line (ICU `{tempo}` interpolation), delete label, and error-state copy all route through `l10n`.
- `confirm_delete_track_dialog.dart` — dialog title (`{trackTitle}` interpolation), body copy, cancel/delete button labels, requires-connection tooltip/label, and the generic catch-all error message all route through `l10n`.
- All three widget test files migrated to assert against `tester.strings.*` and had their `MaterialApp` wrappers extended with `AppLocalizations.delegate` + the three `Global*Localizations` delegates + `supportedLocales: [en, ru]` (previously missing, needed for `AppLocalizations.of(context)` to resolve at all).

## Task Commits

Each task was committed atomically:

1. **Task 1: track_list_screen.dart + test** - `8889a0f` (feat)
2. **Task 2: track_detail_screen.dart + test** - `8f09d91` (feat)
3. **Task 3: confirm_delete_track_dialog.dart + test** - `9ce8e01` (feat)

## Files Created/Modified
- `lib/features/tracks/track_list_screen.dart` - AppBar/FAB/empty-state/error-state strings localized
- `test/features/tracks/track_list_screen_test.dart` - assertions migrated to `tester.strings`, `MaterialApp` wrapper given localization delegates
- `lib/features/tracks/track_detail_screen.dart` - fallback title/tooltip/tempo-line/delete-label/error-state strings localized
- `test/features/tracks/track_detail_screen_test.dart` - assertions migrated to `tester.strings`, `MaterialApp` wrapper given localization delegates
- `lib/features/tracks/confirm_delete_track_dialog.dart` - title interpolation/body/buttons/tooltip/error-fallback strings localized
- `test/features/tracks/confirm_delete_track_dialog_test.dart` - assertions migrated to `tester.strings` (two `MaterialApp` instances), both given localization delegates

## Decisions Made
- Reused `trackListAddButton` for both the FAB tooltip and the empty-state button label, per plan's D-01 and the pre-landed ARB artifact spec — no new key needed.
- Left `OfflineNoCacheView`'s own hardcoded copy (`'No cached data'`, `'Connect to the internet to load this'`) untouched in the two test files that exercise it — that widget's file is outside this plan's `files_modified` scope; it wasn't localized by 13-01 Task 2's ARB additions, so its test assertions stay hardcoded until whichever future plan localizes that shared widget.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Test `MaterialApp` widgets lacked localization delegates**
- **Found during:** Task 1 (first test run after migrating `track_list_screen_test.dart` to `tester.strings`)
- **Issue:** The plan's action text only said to add `import '../../test_strings.dart'` and swap `find.text('...')` calls to `tester.strings.keyName`, but none of the three test files' `MaterialApp` wrappers had `localizationsDelegates`/`supportedLocales` configured. Without them, `AppLocalizations.of(context)` throws (`No element` / widget build failures), since the screens under test now call `AppLocalizations.of(context)!` directly. All 9 tests in `track_list_screen_test.dart` failed on the first run with this exact symptom.
- **Fix:** Added `AppLocalizations.delegate`, `GlobalMaterialLocalizations.delegate`, `GlobalWidgetsLocalizations.delegate`, `GlobalCupertinoLocalizations.delegate` and `supportedLocales: [Locale('en'), Locale('ru')]` to every `MaterialApp` in all three test files (including the second inline `MaterialApp` in `confirm_delete_track_dialog_test.dart`'s CR-03 test) — matching the pattern already used in `band_detail_screen_test.dart` from 13-01.
- **Files modified:** `test/features/tracks/track_list_screen_test.dart`, `test/features/tracks/track_detail_screen_test.dart`, `test/features/tracks/confirm_delete_track_dialog_test.dart`
- **Verification:** `flutter test` on each file — all tests pass after the fix.
- **Committed in:** `8889a0f`, `8f09d91`, `9ce8e01` (part of each task's commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking issue, repeated across all 3 test files as the same root cause)
**Impact on plan:** Necessary for the plan's own stated verification (`flutter test`) to pass at all; no scope creep beyond wiring up already-required test infrastructure.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
All three per-band Tracks screens and their tests are fully localized and passing. No hardcoded English remains in `track_list_screen.dart`, `track_detail_screen.dart`, or `confirm_delete_track_dialog.dart` (other than test fixtures and `OfflineNoCacheView`'s own out-of-scope copy). Ready for the next wave's plans in Phase 13.

---
*Phase: 13-string-extraction-screen-localization*
*Completed: 2026-08-26*
