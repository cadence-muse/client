---
phase: 01-foundation-profile-home
plan: 02
subsystem: state-management
tags: [riverpod, testing, auth, theme]

# Dependency graph
requires: ["01-01"]
provides:
  - "test/providers/auth_provider_test.dart — unit coverage for AuthSession restore/signIn/signOut, incl. the cache-clear-on-signOut privacy mitigation"
  - "test/providers/theme_provider_test.dart — unit coverage for ThemeController"
  - "Automated regression guard proving lib/ contains no ChangeNotifier/ValueNotifier subclass"
affects: [01-03-foundation-profile-home, bands, tracks, setlists]

# Actuals (#2632)
actuals:
  tokens: 1565
  tasks: 1
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ProviderContainer(overrides: [...]) unit tests for @riverpod Notifiers, no widget/pump required"
    - "Fake service classes (implements X) used as ProviderScope overrides to spy on side effects (e.g. _FakeCacheService.clearAllCallCount)"
    - "Directory('lib').listSync(recursive: true) + string-contains assertion as a portable in-test alternative to shelling out to grep"

key-files:
  created:
    - test/providers/auth_provider_test.dart
    - test/providers/theme_provider_test.dart
  modified: []

key-decisions:
  - "Implemented the OFFL-06 regression guard as a pure-Dart Directory.listSync() + string search inside a test() block instead of Process.runSync('grep', ...) — avoids depending on grep being on PATH in every test environment and keeps the guard self-contained in the test file itself"

patterns-established:
  - "Provider unit tests use ProviderContainer directly (no ConsumerWidget/pumpWidget) for pure-logic Notifiers that have no UI dependency"

requirements-completed: [OFFL-06]

coverage:
  - id: D1
    description: "AuthSession.build() restores the correct token from TokenStorage on cold start, verified with no ChangeNotifier involved"
    requirement: OFFL-06
    verification:
      - kind: automated_unit
        ref: "test/providers/auth_provider_test.dart#build() restores the previously written token from TokenStorage on cold start"
        status: pass
      - kind: automated_unit
        ref: "test/providers/auth_provider_test.dart#build() resolves to null when no token was ever written"
        status: pass
    human_judgment: false
  - id: D2
    description: "AuthSession.signIn() persists the token via TokenStorage.write() and updates provider state to AsyncData(token)"
    requirement: OFFL-06
    verification:
      - kind: automated_unit
        ref: "test/providers/auth_provider_test.dart#signIn() persists the token via TokenStorage and updates state to AsyncData(token)"
        status: pass
    human_judgment: false
  - id: D3
    description: "AuthSession.signOut() calls TokenStorage.delete() and CacheService.clearAll() (proven via a fake CacheService spy), updates state to AsyncData(null) — closes 01-01's D7 gap"
    requirement: OFFL-06
    verification:
      - kind: automated_unit
        ref: "test/providers/auth_provider_test.dart#signOut() clears the token, clears the cache via CacheService.clearAll(), and updates state to AsyncData(null)"
        status: pass
    human_judgment: false
  - id: D4
    description: "ThemeController.build() defaults to ThemeMode.system and setThemeMode() updates state without any ValueNotifier involved"
    requirement: OFFL-06
    verification:
      - kind: automated_unit
        ref: "test/providers/theme_provider_test.dart#build() defaults to ThemeMode.system"
        status: pass
      - kind: automated_unit
        ref: "test/providers/theme_provider_test.dart#setThemeMode() updates the provider state"
        status: pass
    human_judgment: false
  - id: D5
    description: "lib/ contains no ChangeNotifier/ValueNotifier subclass — automated regression guard (not just code review), verified to actually fail when the pattern is reintroduced"
    requirement: OFFL-06
    verification:
      - kind: automated_unit
        ref: "test/providers/auth_provider_test.dart#lib/ contains no ChangeNotifier or ValueNotifier subclass (OFFL-06 regression guard)"
        status: pass
    human_judgment: false

# Metrics
duration: ~15min
completed: 2026-08-15
status: complete
---

# Phase 1 Plan 2: AuthSession/ThemeController Provider Unit Tests Summary

**Added `ProviderContainer`-based unit tests for `AuthSession` and `ThemeController`, including a spy-verified test of the cache-clear-on-signOut privacy mitigation and an automated regression guard proving no `ChangeNotifier`/`ValueNotifier` remains under `lib/`.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-15T08:17:13Z
- **Completed:** 2026-08-15T08:19:24Z
- **Tasks:** 1
- **Files modified:** 2 (both created)

## Accomplishments
- `test/providers/auth_provider_test.dart`: cold-start restore (seeded token / no token), `signIn()` persistence, and `signOut()` clearing the token AND invoking `CacheService.clearAll()` exactly once (via `_FakeCacheService` spy with `clearAllCallCount`) — this closes the gap 01-01-SUMMARY.md flagged as D7 (implemented but untested)
- `test/providers/theme_provider_test.dart`: default `ThemeMode.system`, `setThemeMode()` state update
- Automated OFFL-06 regression guard: a `test()` in `auth_provider_test.dart` walks `lib/` recursively and asserts no file contains `extends ChangeNotifier` or `extends ValueNotifier`; manually verified it goes red when the pattern is reintroduced (temporarily added a probe `ChangeNotifier` subclass, confirmed the test failed with the exact filename in the failure message, then removed it) and green again afterward
- Reused the `_FakeSecureStorage` pattern from `test/widget_test.dart` (copied, per the plan's explicit guidance) so `TokenStorage` never touches a real platform channel

## Task Commits

Each task was committed atomically:

1. **Task 1: Unit-test AuthSession and ThemeController Riverpod providers** - `4aa55c2` (test)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
- `test/providers/auth_provider_test.dart` - `AuthSession` unit coverage: cold-start restore, signIn, signOut (incl. cache-clear spy), plus the ChangeNotifier/ValueNotifier regression guard
- `test/providers/theme_provider_test.dart` - `ThemeController` unit coverage: default mode, setThemeMode

## Decisions Made
- Implemented the regression guard as a pure-Dart `Directory.listSync()` + string-contains check instead of `Process.runSync('grep', ...)` — the plan offered both as alternatives; the pure-Dart version has no dependency on `grep` being present in the test-runner's PATH, so it's more portable across CI/sandbox environments.

## Deviations from Plan

None - plan executed exactly as written. Both plan-offered implementation strategies for the regression guard (`Process.runSync('grep', ...)` vs. a pure-Dart directory walk) were anticipated in the plan itself; choosing the pure-Dart alternative is not a deviation, just the plan's own documented fallback.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 01-01-SUMMARY.md's D7 gap (untested `signOut()` cache-clear path) is now closed with an automated test.
- `test/providers/` directory now exists as the established location for Riverpod provider unit tests going forward (bands/tracks/setlists providers in later phases can follow this pattern).
- OFFL-06 requirement is now backed by both the original 01-01 implementation and this plan's automated regression coverage — future phases introducing new state should extend `test/providers/` rather than reintroducing ChangeNotifier/ValueNotifier.

---
*Phase: 01-foundation-profile-home*
*Completed: 2026-08-15*

## Self-Check: PASSED

- `test/providers/auth_provider_test.dart` confirmed present on disk.
- `test/providers/theme_provider_test.dart` confirmed present on disk.
- Task commit `4aa55c2` confirmed present in git log.
- `flutter test test/providers/auth_provider_test.dart test/providers/theme_provider_test.dart`: 7/7 passing.
- `flutter test` (full suite): all passing, no regressions.
- `flutter analyze`: no issues found.
- Regression guard manually verified to fail red when a `ChangeNotifier` subclass is reintroduced under `lib/`, and pass green again once removed.
