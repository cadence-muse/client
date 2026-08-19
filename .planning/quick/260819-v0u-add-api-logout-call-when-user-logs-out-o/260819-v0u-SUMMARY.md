---
phase: quick
plan: 260819-v0u
subsystem: auth
tags: [flutter, riverpod, http, api-client, auth]

requires:
  - phase: null
    provides: Existing PublicApi/AuthSession/ApiClient auth surface (Riverpod-based, from earlier milestone work)
provides:
  - PublicApi.logout() wrapping POST /api/logout
  - AuthSession.signOut() best-effort backend logout call with reentrancy guard
affects: [auth, profile]

actuals:
  tokens: 2053
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Best-effort network call in signOut(): fire before local state clear (while token still attached), swallow all errors in try/catch/finally, local clear always runs unconditionally afterward"
    - "Reentrancy guard on a Riverpod Notifier instance (_loggingOut bool, set before the network attempt, reset in finally) to prevent unbounded recursion when ApiClient.onUnauthorized calls back into the same method that's mid-flight"

key-files:
  created: []
  modified:
    - lib/api/public_api.dart
    - lib/providers/auth_provider.dart
    - test/providers/auth_provider_test.dart

key-decisions:
  - "logout() call fires before the local token/cache clear in signOut(), not after — ApiClient's getToken callback reads authSessionProvider's current value, so the token must still be attached when the request goes out"
  - "All logout() failures (network error, offline, any ApiException including 403) are swallowed via try/catch — matches the milestone's no-offline-mutation-queue scope; local sign-out must never be blocked by backend reachability"
  - "_loggingOut reentrancy guard added because a 403 on the logout call itself trips ApiClient.onUnauthorized -> signOut(), which without a guard would see state.value still non-null and re-attempt logout() from inside the still-running outer call"

patterns-established:
  - "Fire-and-forget backend calls from a state-clearing method: attempt inside try, swallow errors in catch, use finally only for guard-flag reset (not for the state clear itself, which stays outside the try so it isn't skipped by a thrown reentrancy return)"

requirements-completed: []

coverage:
  - id: D1
    description: "PublicApi.logout() calls POST /api/logout matching publicapi.yml's Logout operation (sessionAuth, no body, no response schema)"
    verification:
      - kind: unit
        ref: "test/providers/auth_provider_test.dart#signOut() sends exactly one POST /api/logout with the Authorization header set to the still-active token before clearing local state"
        status: pass
    human_judgment: false
  - id: D2
    description: "AuthSession.signOut() completes local sign-out (token clear, cache clear, state -> AsyncData(null)) even when the logout call fails (offline/network error)"
    verification:
      - kind: unit
        ref: "test/providers/auth_provider_test.dart#signOut() completes local sign-out even when the logout network call throws (offline/unreachable backend)"
        status: pass
    human_judgment: false
  - id: D3
    description: "A 403 on the logout call itself does not cause unbounded recursion through ApiClient.onUnauthorized -> signOut() (reentrancy guard)"
    verification:
      - kind: unit
        ref: "test/providers/auth_provider_test.dart#signOut() completes exactly once (no unbounded recursion) when the logout call itself gets a 403, which triggers onUnauthorized -> signOut() from inside the in-flight logout call"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-08-19
status: complete
---

# Quick Task 260819-v0u: Add POST /api/logout call on sign-out Summary

**AuthSession.signOut() now fires a best-effort POST /api/logout before clearing local token/cache state, guarded against unbounded recursion when the logout call itself 403s.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-19T22:25:08+03:00 (plan pre-dispatch commit)
- **Completed:** 2026-08-19T22:28:47+03:00
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added `PublicApi.logout()`, wrapping `POST /api/logout` per `publicapi.yml`'s `Logout` operation (sessionAuth, no body, no response schema), matching the existing no-body method conventions (`joinBand`/`deleteBand`/`removeMember`)
- Wired it into `AuthSession.signOut()` as a best-effort call: fires while the token is still attached (before local state is cleared), any failure (network error, offline, 403, or any other `ApiException`) is swallowed, and the existing local clear (`TokenStorage.delete()`, `CacheService.clearAll()`, `state = AsyncData(null)`) always completes exactly once
- Added an instance-level `_loggingOut` reentrancy guard on `AuthSession`, since a 403 on the logout call itself trips `ApiClient.onUnauthorized` — wired to `signOut()` — from inside the in-flight call; without the guard this would recurse without a depth bound
- Extended `test/providers/auth_provider_test.dart`'s `buildContainer()` to override `apiClientProvider` via `overrideWith`, wiring a `MockClient`-backed `ApiClient` whose `getToken`/`onUnauthorized` mirror the real provider (reads/writes `authSessionProvider`), and added three new tests covering the logout call itself, the offline fallback, and the 403-reentrancy guard

## Task Commits

Each task was committed atomically, with Task 2 following the RED/GREEN TDD cycle:

1. **Task 1: Add PublicApi.logout()** - `935404b` (feat)
2. **Task 2: Call logout best-effort from AuthSession.signOut()** - RED `c92a399` (test), GREEN `ee9d408` (feat)
3. **Task 3: Cover logout wiring with tests** - `6a55de3` (test)

_Note: Task 2 (tdd="true") intentionally split into a failing test commit (RED) followed by the implementation commit (GREEN), per the TDD execution protocol. Task 3 then extended the same test file with the two remaining assertions (offline fallback, 403-reentrancy) from the plan._

## Files Created/Modified
- `lib/api/public_api.dart` - Added `logout()` method (POST /api/logout, no body); updated class doc comment to reflect the backend call
- `lib/providers/auth_provider.dart` - `AuthSession.signOut()` now calls `publicApiProvider.logout()` best-effort before the local clear; added `_loggingOut` reentrancy guard field
- `test/providers/auth_provider_test.dart` - `buildContainer()` now overrides `apiClientProvider` with a `MockClient`-backed `ApiClient` wired to `authSessionProvider`; added 3 new tests (logout call assertion, offline fallback, 403-reentrancy)

## Decisions Made
- `logout()` fires before the local token/cache clear, not after, because `ApiClient`'s `getToken` callback reads `authSessionProvider`'s live value — clearing first would send the request unauthenticated
- All `logout()` failures are swallowed (bare `catch (_) {}`) rather than logged or surfaced, matching the milestone's stated no-offline-mutation-queue / no-conflict-resolution scope from CLAUDE.md
- The reentrancy guard resets in a `finally` block scoped only around the network attempt — the local clear itself sits outside the try/finally so it isn't accidentally skipped

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Profile screen's existing "Log out" call site (`authSessionProvider.notifier.signOut()`) required no changes — the new backend call is fully internal to `signOut()`.
- `lib/api/publicapi.yml` already had the `Logout` operation defined (pre-existing uncommitted change on the main checkout, out of scope here) — this task only wires the client against that contract.

## Self-Check: PASSED

- FOUND: lib/api/public_api.dart (logout() present)
- FOUND: lib/providers/auth_provider.dart (_loggingOut guard present)
- FOUND: test/providers/auth_provider_test.dart (3 new tests present)
- FOUND commit 935404b
- FOUND commit c92a399
- FOUND commit ee9d408
- FOUND commit 6a55de3

---
*Quick task: 260819-v0u*
*Completed: 2026-08-19*
