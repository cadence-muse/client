---
phase: 11-duration-mm-ss-input-display
plan: 01
subsystem: ui
tags: [flutter, forms, input-formatting, validation, tracks]

# Dependency graph
requires: []
provides:
  - "DurationTextInputFormatter (TextInputFormatter) and parseDurationSeconds() in lib/features/tracks/track_formatting.dart"
  - "Create/Edit Track forms accept and validate mm:ss Duration input instead of raw seconds"
affects: [11-02-setlists, 12-locale-i18n-infrastructure]

# Actuals (#2632)
actuals:
  tokens: 4946
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TextInputFormatter subclass shapes keystrokes for real-time mm:ss auto-format; independent parse function re-validates at submit time so paste/programmatic input can't bypass the formatter"
    - "_durationValidator duplicated per-screen-file (not extracted to shared helper), matching the existing _wholeNumberValidator per-file convention"

key-files:
  created:
    - test/widgets/duration_input_formatter_test.dart
    - test/utils/duration_parser_test.dart
  modified:
    - lib/features/tracks/track_formatting.dart
    - lib/features/tracks/create_track_screen.dart
    - lib/features/tracks/edit_track_screen.dart
    - test/features/tracks/create_track_screen_test.dart
    - test/features/tracks/edit_track_screen_test.dart

key-decisions:
  - "Digit cap set to 4 (not 5) per the plan's explicit correction of RESEARCH.md's example, matching D-03's literal '99:59 maximum'"
  - "parseDurationSeconds() and _durationValidator independently re-check seconds >= 60 and negative values at submit time, not trusting the formatter's shape-only output (T-11-01 mitigation)"

patterns-established:
  - "mm:ss input-boundary conversion: TextInputFormatter for live shaping + a separate parse function for submit-time validation, kept in sync but never merged into one component"

requirements-completed: [DUR-01, DUR-02, DUR-04]

coverage:
  - id: D1
    description: "Typing digits into the Duration field on create/edit track forms auto-formats them into mm:ss shape in real time via DurationTextInputFormatter, with a 4-digit cap enforcing the 99:59 maximum"
    requirement: "DUR-04"
    verification:
      - kind: unit
        ref: "test/widgets/duration_input_formatter_test.dart#DurationTextInputFormatter"
        status: pass
      - kind: integration
        ref: "test/features/tracks/create_track_screen_test.dart#DUR-04: typing \"230\" into Duration auto-formats to \"2:30\" and submits durationSeconds 150"
        status: pass
      - kind: integration
        ref: "test/features/tracks/edit_track_screen_test.dart#DUR-04: editing Duration to \"420\" renders \"4:20\" and submits durationSeconds 260"
        status: pass
    human_judgment: false
  - id: D2
    description: "Backspacing on a formatted Duration value deletes the last shifted digit and reformats from the remaining digits, not a whole-field clear"
    requirement: "DUR-04"
    verification:
      - kind: unit
        ref: "test/widgets/duration_input_formatter_test.dart#backspace: oldValue \"2:30\", newValue \"2:3\" (last char removed) -> reformats to \"0:23\""
        status: pass
    human_judgment: false
  - id: D3
    description: "Blank Duration field remains valid and submits durationSeconds as null"
    requirement: "DUR-04"
    verification:
      - kind: unit
        ref: "test/utils/duration_parser_test.dart#\"\" -> null"
        status: pass
      - kind: integration
        ref: "test/features/tracks/create_track_screen_test.dart#submitting title+artist sends the exact JSON request body and pops back to the list"
        status: pass
      - kind: integration
        ref: "test/features/tracks/edit_track_screen_test.dart#CR-02: clearing optional fields sends explicit null instead of omitting them"
        status: pass
    human_judgment: false
  - id: D4
    description: "An invalid mm:ss value at submit time (seconds >= 60, malformed/incomplete text) is rejected with inline error text below the field and blocks submission"
    requirement: "DUR-02"
    verification:
      - kind: unit
        ref: "test/utils/duration_parser_test.dart#parseDurationSeconds()"
        status: pass
      - kind: integration
        ref: "test/features/tracks/create_track_screen_test.dart#DUR-02: Duration formatted to \"5:60\" is rejected on submit with the seconds-range error, no API call"
        status: pass
      - kind: integration
        ref: "test/features/tracks/edit_track_screen_test.dart#DUR-02: Duration formatted to \"5:60\" is rejected on submit with the seconds-range error, no PUT call"
        status: pass
    human_judgment: false
  - id: D5
    description: "A valid mm:ss Duration submits the correct durationSeconds integer on the wire via parseDurationSeconds(); the API contract (durationSeconds: int) itself is unchanged"
    requirement: "DUR-01"
    verification:
      - kind: unit
        ref: "test/utils/duration_parser_test.dart#\"2:30\" -> 150 / \"99:59\" -> 5999"
        status: pass
      - kind: integration
        ref: "test/features/tracks/create_track_screen_test.dart#DUR-04: typing \"230\" into Duration auto-formats to \"2:30\" and submits durationSeconds 150"
        status: pass
    human_judgment: false
  - id: D6
    description: "The Edit Track form pre-populates the Duration field with the existing track's duration formatted as mm:ss (durationSeconds 200 -> '3:20'), not raw seconds"
    requirement: "DUR-01"
    verification:
      - kind: integration
        ref: "test/features/tracks/edit_track_screen_test.dart#starts pre-populated with currentTrack's values"
        status: pass
    human_judgment: false
  - id: D7
    description: "Duration input field displays and edits its mm:ss value without visible cutoff/overflow at typical mobile screen widths, including at the 99:59 cap"
    verification: []
    human_judgment: true
    rationale: "Visual layout at mobile screen widths (must-have backstop truth) requires a human to view the running app; no automated screenshot/visual-regression check exists for this field in the current test suite."

# Metrics
duration: ~25min
completed: 2026-08-25
status: complete
---

# Phase 11 Plan 01: mm:ss Duration Input on Create/Edit Track Forms Summary

**DurationTextInputFormatter auto-shapes digit keystrokes into mm:ss (capped at 99:59) while parseDurationSeconds() independently re-validates at submit time, wired end-to-end into both Create and Edit Track forms.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-25 (approx.)
- **Completed:** 2026-08-25T10:52:24Z
- **Tasks:** 2
- **Files modified:** 5 (3 lib, 2 test) + 2 new test files

## Accomplishments
- `DurationTextInputFormatter` (a `TextInputFormatter`) shapes raw digit keystrokes into `mm:ss` live as the user types, caps at 4 digits (99:59 max per D-03), and reformats correctly on backspace
- `parseDurationSeconds()` parses/validates `mm:ss` text into a `durationSeconds` int, independently re-checking `seconds >= 60` and negative values so a bypass via paste or programmatic text assignment is still caught (T-11-01 mitigation)
- Create Track form's Duration field: auto-formats, shows `'0:00'` hint and helper copy, validates via `_durationValidator`, submits the parsed integer
- Edit Track form's Duration field mirrors the same behavior and additionally pre-populates from the existing track's `durationSeconds` as `mm:ss` (e.g. `200` -> `'3:20'`) instead of raw seconds
- Old WR-02 non-numeric-Duration test (which no longer described actual field behavior post-formatter) replaced with DUR-04/DUR-02 formatter-aware tests in both screen test files

## Task Commits

Each task followed the RED-GREEN TDD cycle with atomic commits:

1. **Task 1 (tracer): DurationTextInputFormatter + parseDurationSeconds wired into Create Track form**
   - `f840be6` - test(11-01): add failing test for DurationTextInputFormatter/parseDurationSeconds (RED)
   - `7ffb567` - feat(11-01): wire DurationTextInputFormatter + parseDurationSeconds into Create Track form (GREEN)
2. **Task 2: Wire into Edit Track form, with mm:ss pre-population**
   - `e1ec93a` - test(11-01): add failing tests for Edit Track form mm:ss Duration wiring (RED)
   - `575ed79` - feat(11-01): wire DurationTextInputFormatter + parseDurationSeconds into Edit Track form (GREEN)

No REFACTOR commits were needed — both GREEN commits landed clean (`flutter analyze` clean, no follow-up cleanup required).

## Files Created/Modified
- `lib/features/tracks/track_formatting.dart` - Added `DurationTextInputFormatter` class and top-level `parseDurationSeconds()` function
- `lib/features/tracks/create_track_screen.dart` - Duration field wired to formatter/validator/parser; `labelText`, `hintText`, `helperText` updated per UI-SPEC
- `lib/features/tracks/edit_track_screen.dart` - Same wiring, plus `_durationController` pre-populates via `.asMinutesSeconds`
- `test/widgets/duration_input_formatter_test.dart` - New: unit tests for `DurationTextInputFormatter.formatEditUpdate`
- `test/utils/duration_parser_test.dart` - New: unit tests for `parseDurationSeconds()`
- `test/features/tracks/create_track_screen_test.dart` - WR-02 non-numeric test replaced with DUR-04/DUR-02 tests; test viewport widened (see Deviations)
- `test/features/tracks/edit_track_screen_test.dart` - Pre-population expectation updated (`'200'` -> `'3:20'`); DUR-04/DUR-02 tests added; test viewport widened

## Decisions Made
- Digit cap set to 4 (not 5) per the plan's explicit correction of `11-RESEARCH.md`'s formatter example — 5 digits would allow values like `999:59`, contradicting D-03's literal "99:59 maximum" (which is exactly 4 digits: `9959`)
- `_durationValidator` duplicated per-screen-file rather than extracted to a shared helper, matching the codebase's existing `_wholeNumberValidator` per-file convention

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Duration field's new `helperText` pushed the Save button below the default test viewport**
- **Found during:** Task 1 (running the Create Track form's GREEN-phase tests)
- **Issue:** Adding `helperText: 'e.g. 2:30 for 2 minutes 30 seconds'` to the Duration field (required by the plan/UI-SPEC) grew the form's total rendered height past the `flutter_test` default 800x600 viewport. `tester.tap()` on the Save/Save track button then missed its target (`Offset(400.0, 604.0)` fell just outside the 600px-tall viewport), causing `requestBody` to stay `null` and breaking 6+ pre-existing tests in `create_track_screen_test.dart` that were unrelated to Duration itself.
- **Fix:** Widened the test viewport (`tester.view.physicalSize = const Size(800, 1400)`, `devicePixelRatio = 1.0`, with `addTearDown` resets) inside the shared `openCreateTrackScreen`/`openEditTrackScreen` helpers in both screen test files, so the whole form fits on-screen without requiring a scroll-then-tap in every test body.
- **Files modified:** `test/features/tracks/create_track_screen_test.dart`, `test/features/tracks/edit_track_screen_test.dart`
- **Verification:** All 27 tests pass in `create_track_screen_test.dart` + `duration_input_formatter_test.dart` + `duration_parser_test.dart`; all 14 tests pass in `edit_track_screen_test.dart`
- **Committed in:** `7ffb567` (Task 1 GREEN commit), `575ed79` (Task 2 GREEN commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix, self-caused by the plan's own UI change)
**Impact on plan:** Necessary to keep the full pre-existing test suite green after the required `helperText` addition. No scope creep — fix is confined to the shared test-setup helper, does not alter test assertions or production behavior.

## Issues Encountered
- `gsd-tools requirements mark-complete DUR-01 DUR-02 DUR-04` reported `not_found` for all three IDs — REQUIREMENTS.md's traceability table carries `Status: Mapped` (the roadmap-creation-time value) for these rows, and the tool's Status-flip guard only transitions `Pending`/`Gaps Found` -> `Complete` (by design, to avoid silently overwriting an unexpected state). Since this is v1.2's first phase to execute, no prior phase established a `Mapped` -> `Pending` transition at execution-start. Left REQUIREMENTS.md unmodified rather than hand-editing the table outside the tool's consistency checks (checkbox + table row must not diverge) — DUR-01/DUR-02/DUR-04 remain visibly unchecked in REQUIREMENTS.md despite being implemented and tested in this plan. Flagging for the orchestrator/user to reconcile (either a one-time manual `Mapped` -> `Pending` edit, or a future `gsd-tools` change to accept `Mapped` as a valid pre-Complete state).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `flutter test test/features/tracks/` passes with 0 failures (56 tests total across the tracks feature directory)
- `flutter analyze` clean project-wide
- Ready for the plan-level cross-plan verification (`flutter test`) once 11-02-PLAN.md (wave 1, independent, touches `lib/features/setlists/*`) has also landed — no file overlap between the two plans
- D7 (visual no-cutoff/overflow check at mobile widths) is a human-judgment item — flagged in `coverage:` for `verify-work` UAT, not resolved by this plan's automated tests

---
*Phase: 11-duration-mm-ss-input-display*
*Completed: 2026-08-25*

## Self-Check: PASSED

All key files confirmed present on disk (track_formatting.dart, create_track_screen.dart, edit_track_screen.dart, duration_input_formatter_test.dart, duration_parser_test.dart, create_track_screen_test.dart, edit_track_screen_test.dart). All 5 plan commits (f840be6, 7ffb567, e1ec93a, 575ed79, f824f52) confirmed present in `git log`. `flutter test test/features/tracks/` passes (56/56). `flutter analyze` clean.
