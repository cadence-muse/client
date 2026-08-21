---
phase: 06-foundation-info-settings-polish
plan: 01
subsystem: auth
tags: [flutter, riverpod, openapi, forms, validation]

requires: []
provides:
  - "PublicApi.changePassword (POST /api/me/password), wired end-to-end from Profile -> ChangePasswordScreen"
  - "ChangeUserPasswordRequestBody.currentPassword (client-first spec addition, D-01)"
  - "TrackListItem.key, SetlistListItem.eventLocation, BandListItem.ownerId (client-first optional schema fields, D-03/D-04/D-05)"
affects: [06-02, 06-03, 06-04]

actuals:
  tokens: 4990
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Client-first OpenAPI spec extension: add optional/required fields to publicapi.yml ahead of backend support, degrade gracefully when server omits them (mirrors SETL-12 precedent)"
    - "ChangePasswordScreen mirrors LoginScreen's ConsumerStatefulWidget form pattern (GlobalKey<FormState>, disposed TextEditingControllers, _isSubmitting/_errorMessage state, onChanged error-clear)"

key-files:
  created:
    - lib/features/profile/change_password_screen.dart
    - test/features/profile/change_password_screen_test.dart
  modified:
    - lib/api/publicapi.yml
    - lib/api/public_api.dart
    - lib/features/profile/profile_screen.dart

key-decisions:
  - "ChangeUserPasswordRequestBody.currentPassword is required (not just optional) since the client always collects and sends it per D-01"
  - "Branch on 400 + code=='invalid_input' for wrong-current-password, never on 401 -- publicapi.yml's BadRequest response is the only documented error path for this operation, contradicting 06-UI-SPEC.md's '401' wording (a documentation slip against the source-of-truth spec)"
  - "TrackListItem/SetlistListItem/BandListItem's three new fields are all optional (absent from required), no nullable:true -- that flag is reserved for update-request bodies where null means 'clear', not read-only list-item responses"

patterns-established:
  - "TDD tracer task: RED commit (failing test against nonexistent screen) followed by a separate GREEN commit (full implementation) for tdd=\"true\" tasks, even when tracer-tagged"

requirements-completed: [USER-03]

coverage:
  - id: D1
    description: "Password change screen: 3 obscured fields, validators for required/length/match, submit blocked until valid"
    requirement: USER-03
    verification:
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#renders 3 obscured password fields with expected labels"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#empty current password shows required error, no API call"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#new password under 8 chars shows length error"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#mismatched confirm shows Passwords don't match error"
        status: pass
    human_judgment: false
  - id: D2
    description: "Valid submit calls changePassword, shows success SnackBar, and pops back to Profile"
    requirement: USER-03
    verification:
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#valid submit calls changePassword, shows SnackBar, and pops back"
        status: pass
    human_judgment: false
  - id: D3
    description: "400 invalid_input shows 'Current password is incorrect'; other errors show raw e.message; button disables in-flight; error clears on edit"
    requirement: USER-03
    verification:
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#400 invalid_input shows \"Current password is incorrect\" inline error"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#500 server_error shows the raw e.message verbatim"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#while in flight, submit button is disabled and shows a spinner"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#typing in a field after an error clears the error text"
        status: pass
    human_judgment: false
  - id: D4
    description: "publicapi.yml extended with TrackListItem.key, SetlistListItem.eventLocation, BandListItem.ownerId (all optional), unblocking Wave 2"
    verification:
      - kind: other
        ref: "awk-scoped grep check in 06-01-PLAN.md Task 2 <verify> -- prints PASS"
        status: pass
    human_judgment: false

duration: ~15min
completed: 2026-08-21
status: complete
---

# Phase 06 Plan 01: Password Change & List-Item Schema Extensions Summary

**Password change end-to-end on the Profile screen (USER-03), plus three client-first `publicapi.yml` field additions (`TrackListItem.key`, `SetlistListItem.eventLocation`, `BandListItem.ownerId`) that unblock Wave 2's display plans.**

## Performance

- **Duration:** ~15 min (commit span; not separately instrumented)
- **Completed:** 2026-08-21
- **Tasks:** 2 completed
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- `ChangeUserPasswordRequestBody` gains a required `currentPassword` field (client-first, D-01) alongside the pre-existing `password`
- `PublicApi.changePassword({currentPassword, newPassword})` added, POSTs to `/api/me/password`
- `ChangePasswordScreen` built from scratch: 3 obscured `TextFormField`s (Current/New/Confirm password), field validators matching 06-UI-SPEC.md's exact copy, in-flight spinner, success SnackBar + pop, and a 400+`invalid_input` -> "Current password is incorrect" branch (explicitly not a 401 check, per the spec's actual `BadRequest`-only contract)
- `ProfileScreen` wired with a new "Change password" `ListTile` between "Settings" and "Log out"
- `TrackListItem.key`, `SetlistListItem.eventLocation`, `BandListItem.ownerId` added to `publicapi.yml` as optional (non-required) properties, unblocking Plans 06-02/06-03/06-04 in Wave 2

## Task Commits

Each task was committed atomically (Task 1 followed the RED -> GREEN TDD gate since it carries `tdd="true"`):

1. **Task 1 RED: failing test for password change screen** - `f64e8c1` (test)
2. **Task 1 GREEN: password change end-to-end (USER-03)** - `cb0ef92` (feat)
3. **Task 2: extend TrackListItem/SetlistListItem/BandListItem schemas** - `e98e250` (feat)

_Note: Task 1 is `type="tracer" tdd="true"` -- RED and GREEN were committed separately per the TDD execution flow rather than as one combined commit._

## Files Created/Modified
- `lib/api/publicapi.yml` - `ChangeUserPasswordRequestBody.currentPassword` (required); `TrackListItem.key`, `SetlistListItem.eventLocation`, `BandListItem.ownerId` (all optional)
- `lib/api/public_api.dart` - `changePassword({required currentPassword, required newPassword})` method
- `lib/features/profile/change_password_screen.dart` - New `ChangePasswordScreen` `ConsumerStatefulWidget`
- `lib/features/profile/profile_screen.dart` - "Change password" `ListTile` added, navigates to `ChangePasswordScreen`
- `test/features/profile/change_password_screen_test.dart` - 9 widget tests covering rendering, validation, success, both error branches, in-flight state, and error-clear-on-edit

## Decisions Made
- `currentPassword` is `required` in the schema (not merely optional) since the client always sends it, per D-01 and the plan's `<action>` instructions.
- Branch strictly on `statusCode == 400 && code == 'invalid_input'` for the wrong-current-password case -- confirmed against `publicapi.yml`'s actual `responses` block for `ChangeUserPassword` (only `'200'`/`'400'` documented, no `'401'`), overriding 06-UI-SPEC.md's "Server returns 401" line, which the plan itself flags as a documentation slip against the source-of-truth spec.
- Kept all three new list-item fields optional/non-required with no `nullable: true` -- that flag is this spec's convention for update-request bodies signaling "clear this field," not for read-only list response fields, which the codebase already models as plain optional properties (e.g. `TrackListItem.durationSeconds`).

## Deviations from Plan

**1. [Rule 1 - Bug] Fixed `TextFormField.obscureText` test assertion**
- **Found during:** Task 1 (writing the rendering test)
- **Issue:** `TextFormField` does not expose `obscureText` as a public field on itself -- it's forwarded internally to the `TextField` it builds. The original test attempted `tester.widgetList<TextFormField>(...).obscureText`, which fails to compile.
- **Fix:** Asserted on the rendered `TextField` descendants instead (`find.byType(TextField)`, checking `.obscureText` there).
- **Files modified:** `test/features/profile/change_password_screen_test.dart`
- **Verification:** All 9 tests pass; `flutter analyze` clean.
- **Committed in:** `cb0ef92` (part of the GREEN commit, discovered during RED -> GREEN transition)

**2. [Rule 3 - Blocking] Added missing `apiClientProvider` import**
- **Found during:** Task 1 GREEN verification
- **Issue:** The test file initially omitted `import 'package:cadence/providers/auth_provider.dart'`, causing an "Undefined name 'apiClientProvider'" compile error.
- **Fix:** Added the import (mirrors `profile_screen_test.dart`'s import list).
- **Files modified:** `test/features/profile/change_password_screen_test.dart`
- **Verification:** Compiles and all 9 tests pass.
- **Committed in:** `cb0ef92`

---

**Total deviations:** 2 auto-fixed (2 blocking/bug, both within the test file itself, discovered during the RED->GREEN TDD cycle)
**Impact on plan:** Both fixes were narrow test-authoring corrections with no change to production behavior or scope.

## Issues Encountered
None beyond the two auto-fixed deviations above.

## Next Phase Readiness
- Wave 2 plans (06-02 Band, 06-03 Track, 06-04 Setlist display work) can now consume `BandListItem.ownerId`, `TrackListItem.key`, and `SetlistListItem.eventLocation` directly from `publicapi.yml` -- no further spec changes needed from them, and they have zero file overlap with each other or with this plan.
- No blockers identified.

---
*Phase: 06-foundation-info-settings-polish*
*Completed: 2026-08-21*
