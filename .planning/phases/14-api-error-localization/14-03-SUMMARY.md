---
phase: 14-api-error-localization
plan: 03
subsystem: ui
tags: [flutter, dart, i18n, error-handling, riverpod]

# Dependency graph
requires:
  - phase: 14-01
    provides: "ApiExceptionLocalization extension (`localizedMessage`) on ApiException, with an `overrides` named parameter, and the 5 `commonErrorX` ARB keys"
provides:
  - "3 remaining Tracks-feature catch sites (create/edit/delete) now call `e.localizedMessage(l10n)`"
  - "login_screen.dart's already_exists override and change_password_screen.dart's invalid_input override refactored onto `localizedMessage`'s `overrides` parameter (D-04), retiring the last 2 bespoke if/else error-handling blocks in the app"
  - "test/features/auth/login_screen_test.dart — first-ever test coverage for LoginScreen"
affects: [14-04]

# Actuals (#2632)
actuals:
  tokens: 2946
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Screen-specific error overrides route through `ApiExceptionLocalization.localizedMessage`'s `overrides: {code: message}` map parameter rather than bespoke if/else blocks on `e.statusCode`/`e.code`"

key-files:
  created:
    - test/features/auth/login_screen_test.dart
  modified:
    - lib/features/tracks/create_track_screen.dart
    - lib/features/tracks/edit_track_screen.dart
    - lib/features/tracks/confirm_delete_track_dialog.dart
    - lib/features/auth/login_screen.dart
    - lib/features/profile/change_password_screen.dart
    - test/features/tracks/create_track_screen_test.dart
    - test/features/profile/change_password_screen_test.dart

key-decisions:
  - "Task 2 followed the plan's RED/GREEN TDD flow: wrote the 3 new-behavior tests first (already_exists override, not_found generic-message expansion for both login and change-password, and the untouched 401 path), confirmed the 2 new-behavior assertions failed pre-refactor, then implemented the refactor and confirmed all 13 tests passed."
  - "login_screen.dart's inner register() try/catch/rethrow was removed entirely rather than kept as a pass-through — the ApiException now propagates directly to the outer catch, which applies the already_exists override via the `overrides` map. The separate 401 statusCode-driven login() try/catch block was left completely untouched, per the plan's explicit scope boundary."

patterns-established:
  - "Any future screen-specific ApiException override should be added via the `overrides` map at the outer catch site, not a nested try/catch/rethrow or an inline statusCode/code conditional."

requirements-completed: [I18N-05]

coverage:
  - id: D1
    description: "create_track_screen.dart, edit_track_screen.dart, and confirm_delete_track_dialog.dart show the shared localized generic message for known ApiException error codes instead of raw server text"
    requirement: "I18N-05"
    verification:
      - kind: unit
        ref: "test/features/tracks/create_track_screen_test.dart#a createBandTrack() failure with a known error code shows the localized generic message, not raw server text"
        status: pass
    human_judgment: false
  - id: D2
    description: "login_screen.dart's already_exists override and change_password_screen.dart's invalid_input override are refactored onto localizedMessage's overrides parameter with unchanged wording; a different known code on either screen now shows the shared generic message; the 401 statusCode-driven login path is unaffected"
    requirement: "I18N-05"
    verification:
      - kind: unit
        ref: "test/features/auth/login_screen_test.dart#registering with an already-taken username still shows the loginUsernameTakenError override, not the generic already_exists message"
        status: pass
      - kind: unit
        ref: "test/features/auth/login_screen_test.dart#registering and hitting a different known code (not_found) now shows the shared generic localized message -- new behavior this phase adds"
        status: pass
      - kind: unit
        ref: "test/features/auth/login_screen_test.dart#logging in with wrong credentials (401) still shows loginInvalidCredentialsError -- the untouched statusCode-driven path"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#400 invalid_input shows \"Current password is incorrect\" inline error"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#a different known code (not_found) now shows the shared generic localized message, not raw server text -- new behavior this phase adds"
        status: pass
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart#500 server_error shows the raw e.message verbatim"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-26
status: complete
---

# Phase 14 Plan 03: Tracks Catch-Site Wiring and Login/Change-Password Overrides Refactor Summary

**Wired create/edit/delete-track error catch sites to the shared `localizedMessage` extension, then refactored login's `already_exists` and change-password's `invalid_input` overrides onto the same `overrides` parameter mechanism (D-04), retiring the last 2 bespoke error-handling implementations in the app and adding LoginScreen's first-ever test coverage.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-26T18:10:00Z
- **Completed:** 2026-08-26T18:35:00Z
- **Tasks:** 2
- **Files modified:** 7 (+ 1 created)

## Accomplishments
- All 3 remaining Tracks-feature `on ApiException catch (e)` sites (create, edit, delete) now show the shared ARB-localized generic message for known error codes, matching the pattern established in 14-02.
- `login_screen.dart`'s `already_exists` override and `change_password_screen.dart`'s `invalid_input` override both now route through `localizedMessage`'s `overrides` parameter, with their exact pre-existing wording preserved.
- `login_screen.dart`'s nested `try { register() } on ApiException catch (e) { ... rethrow; }` wrapper is gone — the exception now propagates directly to one outer catch, same call shape as every other screen in the app.
- A previously-uncovered error code (`not_found`) on both login (registration) and change-password now shows the shared generic localized message instead of raw server text — the intentional I18N-05 behavior expansion for the 18 previously-unmapped codes on these 2 screens.
- `login_screen.dart` has automated test coverage for the first time in the project (`test/features/auth/login_screen_test.dart`, 3 tests), including a regression test proving the untouched 401 statusCode-driven path still works.

## Task Commits

Each task was committed atomically (task 2 used TDD RED/GREEN commits per plan's `tdd="true"`):

1. **Task 1: Wire create/edit/delete-track catch sites** - `f83d468` (feat)
2. **Task 2 (RED): Add failing tests for login/change-password overrides refactor** - `681f66b` (test)
2. **Task 2 (GREEN): Refactor login/change-password overrides onto localizedMessage (D-04)** - `a87a2fb` (feat)

_Note: this executor ran as a parallel worktree agent — the orchestrator applies the final `docs({phase}-{plan}): complete plan` metadata commit centrally after merge, not this agent._

## Files Created/Modified
- `lib/features/tracks/create_track_screen.dart` - `on ApiException catch (e)` now calls `e.localizedMessage(l10n)`
- `lib/features/tracks/edit_track_screen.dart` - same swap
- `lib/features/tracks/confirm_delete_track_dialog.dart` - same swap
- `test/features/tracks/create_track_screen_test.dart` - new `invalid_input` regression test
- `lib/features/auth/login_screen.dart` - removed inner register() try/catch/rethrow; outer catch now calls `e.localizedMessage(l10n, overrides: {'already_exists': l10n.loginUsernameTakenError})`; 401 login() path untouched
- `lib/features/profile/change_password_screen.dart` - replaced inline statusCode/code conditional with `e.localizedMessage(l10n, overrides: {'invalid_input': l10n.changePasswordIncorrectCurrentError})`
- `test/features/auth/login_screen_test.dart` - **new file**, LoginScreen's first test coverage (3 tests: already_exists override, not_found generic-message expansion, untouched 401 path)
- `test/features/profile/change_password_screen_test.dart` - added a `not_found` generic-message regression test; the 2 pre-existing tests (line 264 `invalid_input`, line 298 `server_error` fallback) kept passing unmodified

## Decisions Made
- Followed the plan's TDD gate sequence for Task 2: RED commit (`681f66b`) with the 2 new-behavior tests failing as expected against the pre-refactor code, then GREEN commit (`a87a2fb`) implementing the refactor with all 13 tests passing. No REFACTOR-phase commit was needed — `dart format` was applied inline during GREEN, before the commit, so no separate cleanup commit exists.
- `dart format` reformatted `change_password_screen.dart`'s multi-line `overrides` map onto 3 lines (project's dartfmt line-length convention) — applied before committing, not treated as a separate deviation since it's mechanical formatter output with no logic change.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 3 Tracks catch sites and both Auth/Profile overrides are now on the single consistent `localizedMessage` call shape. Combined with 14-01/14-02, every in-scope catch site in the app (Bands, Tracks, Auth, Profile) uses the shared mechanism except the Setlists feature, which is 14-04's scope.
- No blockers for 14-04.

## Self-Check: PASSED

All 9 claimed files verified tracked in git (`git ls-files`); all 4 commit hashes (`f83d468`, `681f66b`, `a87a2fb`, `26eaa96`) verified present in `git log`.

---
*Phase: 14-api-error-localization*
*Completed: 2026-08-26*
