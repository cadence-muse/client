---
phase: 15-carried-over-fixes-setlist-date-picker
plan: 01
subsystem: ui
tags: [flutter, showDatePicker, forms, riverpod, widget-tests]

# Dependency graph
requires: []
provides:
  - "CreateSetlistScreen and EditSetlistScreen date fields use the native Flutter showDatePicker instead of raw text entry"
  - "Shared readOnly + onTap + clear-icon TextFormField pattern for date fields (first showDatePicker use in the codebase)"
affects: [setlist-forms, date-input]

# Actuals (#2632)
actuals:
  tokens: 2858
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "readOnly TextFormField + onTap opening showDatePicker(), with a suffixIcon clear (X) IconButton that appears only when the controller has text"
    - "DateTime.parse wrapped in try/catch with a `now` fallback when seeding initialDate from a persisted, potentially-malformed date string"

key-files:
  created: []
  modified:
    - lib/features/setlists/create_setlist_screen.dart
    - lib/features/setlists/edit_setlist_screen.dart
    - test/features/setlists/create_setlist_screen_test.dart
    - test/features/setlists/edit_setlist_screen_test.dart

key-decisions:
  - "Followed D-01–D-04 from 15-CONTEXT.md exactly: readOnly field, X suffixIcon clear, firstDate/lastDate = now ∓ (5,2) years, initialDate from existing eventDate on edit (parse-failure falls back to now) or today otherwise."
  - "Used toIso8601String().split('T')[0] for the YYYY-MM-DD wire format instead of adding the intl package, per the plan's explicit no-new-dependency instruction."
  - "Dropped EditSetlistScreen's textInputAction/onFieldSubmitted on the date field since a readOnly field never receives an IME submit event."

patterns-established:
  - "showDatePicker pattern (readOnly field, onTap handler, firstDate/lastDate bounds, clear-icon suffix) — reusable for any future date-input field in the app."

requirements-completed: [SETL-13]

coverage:
  - id: D1
    description: "CreateSetlistScreen's date field is readOnly and tapping it opens showDatePicker bounded to now ∓ (5, 2) years with initialDate: now; a picked date round-trips into the create request as YYYY-MM-DD; the clear icon empties the field and the request omits eventDate."
    requirement: "SETL-13"
    verification:
      - kind: unit
        ref: "test/features/setlists/create_setlist_screen_test.dart#tapping the date field opens the native date picker dialog"
        status: pass
      - kind: unit
        ref: "test/features/setlists/create_setlist_screen_test.dart#confirming the picker with today unchanged sets the date field to today's ISO date"
        status: pass
      - kind: unit
        ref: "test/features/setlists/create_setlist_screen_test.dart#after a date is set, the clear icon empties the field and the request sends no eventDate"
        status: pass
    human_judgment: false
  - id: D2
    description: "EditSetlistScreen's date field mirrors the same readOnly/picker/clear pattern, additionally pre-populating initialDate from the existing eventDate (or falling back to now on a malformed persisted date) and preserving the existing explicit-null-on-clear submission behavior."
    requirement: "SETL-13"
    verification:
      - kind: unit
        ref: "test/features/setlists/edit_setlist_screen_test.dart#confirming the picker with the existing date unchanged keeps the date field showing the setlist's eventDate"
        status: pass
      - kind: unit
        ref: "test/features/setlists/edit_setlist_screen_test.dart#a malformed persisted eventDate falls back to today as initialDate without throwing"
        status: pass
      - kind: unit
        ref: "test/features/setlists/edit_setlist_screen_test.dart#with a pre-populated date, the clear icon empties the field and saving sends eventDate: null"
        status: pass
      - kind: unit
        ref: "test/features/setlists/edit_setlist_screen_test.dart#clearing the date field also sends an explicit null instead of omitting the key"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-08-27
status: complete
---

# Phase 15 Plan 01: Setlist Date Picker Summary

**Replaced raw-text `eventDate` entry in both setlist forms with Flutter's native `showDatePicker`, bounded to a 5-years-back/2-years-forward range, with pre-population and a malformed-date fallback on the edit form.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-27T00:00:00Z (approx, worktree session)
- **Completed:** 2026-08-27
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- `CreateSetlistScreen`'s date `TextFormField` is now `readOnly: true`, tapping it opens `showDatePicker` with `firstDate`/`lastDate` = now ∓ (5, 2) years and `initialDate: now`; a picked date is written as `YYYY-MM-DD` via `toIso8601String().split('T')[0]`
- `EditSetlistScreen` mirrors the identical pattern, additionally resolving `initialDate` from the setlist's existing `eventDate` via `DateTime.parse` wrapped in try/catch, falling back to `now` on any parse failure (T-15-01)
- Both screens gained a clear (X) `suffixIcon` that appears once a date is set and empties `_dateController` on tap, preserving the existing optional-date (`eventDate: null`) submission behavior
- 6 new widget tests added (3 per screen) covering picker-open, date round-trip, malformed-date fallback (edit only), and clear-icon behavior
- Fixed one pre-existing test (`edit_setlist_screen_test.dart`'s "clearing the date field...") that used `enterText` on the now-`readOnly` field — updated to drive the clear icon instead

## Task Commits

Each task was committed atomically:

1. **Task 1: CreateSetlistScreen — readOnly date field wired to showDatePicker end-to-end** - `55e0529` (feat)
2. **Task 2: EditSetlistScreen — mirror the picker pattern with existing-date pre-population** - `42a0d3d` (feat)

**Plan metadata:** committed alongside this SUMMARY (worktree mode)

## Files Created/Modified
- `lib/features/setlists/create_setlist_screen.dart` - date field readOnly + onTap + `_showDatePickerDialog`, clear-icon suffixIcon
- `lib/features/setlists/edit_setlist_screen.dart` - same pattern, plus `initialDate` resolved from existing `eventDate` with parse-failure fallback; dropped `textInputAction`/`onFieldSubmitted`
- `test/features/setlists/create_setlist_screen_test.dart` - 3 new widget tests (picker opens, date round-trips, clear-icon nulls eventDate)
- `test/features/setlists/edit_setlist_screen_test.dart` - 3 new widget tests (initialDate pre-population, malformed-date backstop, clear-icon nulls eventDate) + 1 pre-existing test fixed to use the clear icon

## Decisions Made
- Followed D-01–D-04 from `15-CONTEXT.md` exactly — no deviation in picker bounds, defaults, or clear-icon behavior.
- Used `toIso8601String().split('T')[0]` for the wire format rather than adding the `intl` package, per the plan's explicit instruction.
- Left `hintText: l10n.createSetlistDateHint` untouched on `CreateSetlistScreen` per UI-SPEC's explicit deferral of hint-text cleanup to a future iteration.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a pre-existing test broken by the mandated `readOnly` change**
- **Found during:** Task 2 (EditSetlistScreen implementation)
- **Issue:** The pre-existing test `'clearing the date field also sends an explicit null instead of omitting the key'` used `tester.enterText(find.byType(TextFormField).at(2), '')` to clear the date field. Once the field became `readOnly: true` (required by D-01/SETL-13), `enterText` could no longer type into it, so the field retained its pre-populated value and the test's `expect(decoded['eventDate'], isNull)` assertion failed.
- **Fix:** Updated the test to tap the clear (X) `IconButton` instead of using `enterText`, matching the new supported interaction path. Behavior under test (explicit `null` on clear) is unchanged — only the interaction mechanism was fixed.
- **Files modified:** `test/features/setlists/edit_setlist_screen_test.dart`
- **Verification:** `flutter test test/features/setlists/edit_setlist_screen_test.dart` — all 13 tests pass, including this one.
- **Committed in:** `42a0d3d` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Direct, necessary consequence of the plan-mandated `readOnly` change on a test file explicitly listed in the plan's `files_modified`. No scope creep — the fix only updates the interaction mechanism of an existing assertion, not its intent.

## Issues Encountered
- The sandboxed shell environment has `HTTP_PROXY`/`HTTPS_PROXY` set without `NO_PROXY`, which caused `flutter test`'s local VM-service WebSocket handshake (loopback `127.0.0.1`) to be routed through the proxy and rejected with HTTP 503, failing every `flutter test` invocation regardless of code changes (reproduced on the pre-existing, unmodified test files too). Resolved locally per test run by exporting `NO_PROXY=127.0.0.1,localhost,::1` / `no_proxy=127.0.0.1,localhost,::1` before invoking `flutter test`. This is an environment/session-local workaround, not a code change — no files were modified to fix it.

## Next Phase Readiness
- SETL-13 fully delivered: both setlist forms use the native date picker exclusively; no raw-text date entry path remains in either screen.
- `flutter analyze` clean on all 4 touched files; full `flutter test` suite (459 tests) passes with 0 failures.
- Plan 15-02 (BAND-13 invite-code copy fix + QA-01 verification re-stamp) is independent of this plan's changes and unaffected.

---
*Phase: 15-carried-over-fixes-setlist-date-picker*
*Completed: 2026-08-27*

## Self-Check: PASSED

All created/modified files verified present on disk; commits `55e0529`, `42a0d3d`, `25ed5ba` verified present in `git log`.
