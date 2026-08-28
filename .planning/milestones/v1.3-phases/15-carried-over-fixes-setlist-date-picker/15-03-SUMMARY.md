---
phase: 15-carried-over-fixes-setlist-date-picker
plan: 03
subsystem: ui
tags: [flutter, date-picker, setlists, regression-fix]

# Dependency graph
requires:
  - phase: 15-01
    provides: "The date-picker pattern (firstDate/lastDate window computation, DateTime.parse try/catch fallback) this plan expands with clamping"
provides:
  - "EditSetlistScreen._showDatePickerDialog clamps a successfully-parsed initialDate into [firstDate, lastDate] before calling showDatePicker(), eliminating an AssertionError crash for out-of-range persisted eventDate values"
affects: [setlists, edit-setlist-screen]

# Actuals (#2632)
actuals:
  tokens: 574
  tasks: 1
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Post-parse range clamping: after DateTime.parse succeeds, clamp the value into the UI widget's valid window ([firstDate, lastDate]) before passing it to an API that asserts the invariant, rather than relying solely on catch-block fallback for malformed input."

key-files:
  created: []
  modified:
    - lib/features/setlists/edit_setlist_screen.dart
    - test/features/setlists/edit_setlist_screen_test.dart

key-decisions:
  - "Clamped rather than fell back to `now` for out-of-range dates, per 15-VERIFICATION.md Gap 1 / 15-REVIEW.md CR-01 recommendation — clamping preserves the user's intent to land near their persisted date, while falling back to `now` would silently discard it."
  - "Did not touch CreateSetlistScreen — it always seeds initialDate: now, which is within [firstDate, lastDate] by construction, so it has no equivalent gap (explicitly out of scope per 15-REVIEW.md WR-01)."

requirements-completed: [SETL-13]

coverage:
  - id: D1
    description: "EditSetlistScreen's date picker no longer throws AssertionError for a persisted eventDate more than 5 years in the past (or 2 years in the future); the value is clamped to the nearest bound"
    requirement: "SETL-13"
    verification:
      - kind: unit
        ref: "test/features/setlists/edit_setlist_screen_test.dart#a persisted eventDate more than 5 years in the past clamps initialDate to firstDate without throwing"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-27
status: complete
---

# Phase 15 Plan 3: EditSetlistScreen Date Clamp Fix Summary

**Clamped `EditSetlistScreen._showDatePickerDialog`'s parsed `initialDate` into `[firstDate, lastDate]`, fixing an `AssertionError` crash for any setlist dated more than 5 years in the past or 2 years in the future.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-08-27T00:00:00Z (approx.)
- **Completed:** 2026-08-27
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Closed Gap 1 from `15-VERIFICATION.md` (same root cause as code review CR-01): a persisted `eventDate` outside the date picker's `[firstDate, lastDate]` window no longer crashes `EditSetlistScreen` with `AssertionError`.
- Added a regression test proving both the no-throw behavior and the exact clamp-to-`firstDate` outcome for a 2020-01-01 eventDate.
- Verified via TDD: reproduced the crash with a failing test first (RED), confirmed the exact `AssertionError` and stack trace, then implemented the minimal fix (GREEN).

## Task Commits

Each task was committed atomically (TDD RED → GREEN):

1. **Task 1 (RED): add failing regression test** - `5178711` (test)
2. **Task 1 (GREEN): clamp initialDate into valid range** - `2c43ce1` (fix)

**Plan metadata:** commit not yet made (see final commit step)

## Files Created/Modified
- `lib/features/setlists/edit_setlist_screen.dart` - `_showDatePickerDialog`'s try-block now clamps a successfully-parsed `initialDate` into `[firstDate, lastDate]` via `isBefore`/`isAfter` checks, positioned after `DateTime.parse` and before `showDatePicker()`. The existing `catch (_) { initialDate = now; }` fallback and empty-controller `else` branch are unchanged.
- `test/features/setlists/edit_setlist_screen_test.dart` - New `testWidgets` case (`'a persisted eventDate more than 5 years in the past clamps initialDate to firstDate without throwing'`) inserted between the existing "confirming the picker with the existing date unchanged" and "a malformed persisted eventDate falls back to today" tests. Uses `eventDate: '2020-01-01'`, asserts `tester.takeException()` is `null` after opening the picker, then confirms with `OK` and asserts the date field's text equals `firstDate` (`now.year - 5, now.month, now.day`) formatted as `YYYY-MM-DD`.

## Decisions Made
- Clamped out-of-range dates into the valid window rather than falling back to `now`, matching the exact fix recommended in `15-VERIFICATION.md` Gap 1 and `15-REVIEW.md` CR-01.
- Left `CreateSetlistScreen`, the missing `mounted` guard after `await showDatePicker`, and the duplicated date-window computation untouched — explicitly out of scope per `15-REVIEW.md` WR-01, WR-02, IN-01; none of these are the verification blocker this plan closes.

## Deviations from Plan

None - plan executed exactly as written. The only environment-level friction was a corporate `HTTP_PROXY`/`HTTPS_PROXY` misrouting the Flutter test harness's loopback WebSocket connection (unrelated to the code change); working around it required setting `NO_PROXY=127.0.0.1,localhost` for the `flutter test` invocation. This is a local environment/tooling detail, not a code deviation, and required no file changes.

## Issues Encountered
- Local `flutter test` runs initially failed with `WebSocketException ... HTTP status code: 503` due to the machine's global `HTTP_PROXY`/`HTTPS_PROXY` environment variables capturing the test harness's `127.0.0.1` loopback connection. Resolved by exporting `NO_PROXY=127.0.0.1,localhost` before invoking `flutter test`. Confirmed this was environmental (not a regression) by reproducing the same failure on an unrelated pre-existing test file before making any code changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- SETL-13 success criterion 3 (native date picker, no crash) fully satisfied per `15-VERIFICATION.md`.
- `flutter test test/features/setlists/edit_setlist_screen_test.dart` passes with 0 failures (14/14 tests, including the new regression test).
- `flutter analyze` reports no issues on both touched files.
- No blockers for subsequent phase 15 plans or phase 16.

---
*Phase: 15-carried-over-fixes-setlist-date-picker*
*Completed: 2026-08-27*
