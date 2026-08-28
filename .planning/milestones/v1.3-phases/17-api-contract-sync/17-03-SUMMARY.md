---
phase: 17-api-contract-sync
plan: 03
subsystem: auth
tags: [flutter, validation, login, forms]

requires:
  - phase: 17-api-contract-sync (17-02, ChangePasswordScreen validator reference/D-05)
    provides: the already-correct new-password validator shape used as the ordering contrast in this plan's tests
provides:
  - "LoginScreen's password TextFormField validator gates the 8-char minimum on signup mode only"
  - "4 new widget tests proving login/signup mode-specific validator behavior"
affects: [auth, login-screen, password-validation]

actuals:
  tokens: 1180
  tasks: 1
  commits: 1

tech-stack:
  added: []
  patterns:
    - "Mode-gated validator: check the length constraint only when isSignUp is true, fall back to a simple emptiness check otherwise"

key-files:
  created: []
  modified:
    - lib/features/auth/login_screen.dart
    - test/features/auth/login_screen_test.dart

key-decisions:
  - "Length-check runs before the empty-check in the validator (matches the plan's specified order), so an empty password in signup mode surfaces commonAtLeast8Chars rather than commonFieldRequired -- verified explicitly by test case 4"

patterns-established: []

requirements-completed: [API-02]

coverage:
  - id: D1
    description: "LoginScreen's password validator gates the 8-character minimum length check on signup mode (_AuthMode.signUp), no longer blocking login attempts with short-but-valid legacy passwords"
    requirement: "API-02"
    verification:
      - kind: unit
        ref: "test/features/auth/login_screen_test.dart#logging in with a short (7-char) but non-empty password reaches the server -- proven by a mocked 401 surfacing loginInvalidCredentialsError, not a client-side commonAtLeast8Chars validator error (D-04)"
        status: pass
      - kind: unit
        ref: "test/features/auth/login_screen_test.dart#logging in with an empty password shows commonFieldRequired and does not reach the server (login-mode length check is skipped entirely)"
        status: pass
      - kind: unit
        ref: "test/features/auth/login_screen_test.dart#signing up with a short (7-char) password still shows commonAtLeast8Chars (D-04 must not relax signup enforcement)"
        status: pass
      - kind: unit
        ref: "test/features/auth/login_screen_test.dart#signing up with an empty password shows commonAtLeast8Chars, not commonFieldRequired -- the length check runs before the empty check in signup mode"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-27
status: complete
---

# Phase 17 Plan 03: Gate Password Length Validator to Signup Mode Summary

**LoginScreen's shared password validator now only enforces the 8-character minimum in signup mode, so login attempts with short legacy passwords reach the server instead of being blocked client-side.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-27T18:10:00Z
- **Completed:** 2026-08-27T18:25:00Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- `LoginScreen`'s password `TextFormField` validator now checks `isSignUp && (value == null || value.length < 8)` first (returns `commonAtLeast8Chars`), then falls back to a plain emptiness check (`commonFieldRequired`) — the length gate no longer applies unconditionally to both login and signup modes
- Added 4 widget tests: login-mode short-but-nonempty password reaches the server (mocked 401 → `loginInvalidCredentialsError`), login-mode empty password shows `commonFieldRequired`, signup-mode short password still shows `commonAtLeast8Chars`, signup-mode empty password shows `commonAtLeast8Chars` (not `commonFieldRequired`, proving check order)
- `ChangePasswordScreen`'s new-password validator is confirmed untouched — not present in this plan's `git diff --stat`

## Task Commits

Each task was committed atomically:

1. **Task 1: Gate the password length validator to signup mode** - `b7ac5a0` (fix)

**Plan metadata:** (this commit, follows)

## Files Created/Modified
- `lib/features/auth/login_screen.dart` - Password validator now gates the 8-char minimum on `isSignUp`
- `test/features/auth/login_screen_test.dart` - 4 new widget tests covering login/signup mode validator behavior

## Decisions Made
- Kept the length-check-before-empty-check order specified in the plan (rather than empty-check-first) so signup mode's empty-password case surfaces `commonAtLeast8Chars`, matching the plan's `<behavior>` spec exactly and confirmed by a dedicated test.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `flutter analyze` clean (0 issues), `flutter test` full suite passes (465/465, zero regressions)
- API-02 requirement complete: `minLength: 8` password validation now correctly scoped to signup only, matching `publicapi.yml`'s `RegisterRequestBody.password` schema
- No blockers for remaining Phase 17 plans

## Self-Check: PASSED

- FOUND: lib/features/auth/login_screen.dart
- FOUND: test/features/auth/login_screen_test.dart
- FOUND: .planning/phases/17-api-contract-sync/17-03-SUMMARY.md
- FOUND: commit b7ac5a0 (task 1)
- FOUND: commit 25c4404 (plan metadata)

---
*Phase: 17-api-contract-sync*
*Completed: 2026-08-27*
