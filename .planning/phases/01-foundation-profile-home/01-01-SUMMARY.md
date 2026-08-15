---
phase: 01-foundation-profile-home
plan: 01
subsystem: state-management
tags: [riverpod, hive, flutter, cache, auth]

# Dependency graph
requires: []
provides:
  - "Riverpod-native app shell (main/app/auth_gate/login_screen/root_scaffold/settings_screen) — no ChangeNotifier/ValueNotifier remaining"
  - "authSessionProvider (AuthSession Notifier) replacing the old ChangeNotifier AuthSession, with signOut() clearing all cache boxes"
  - "apiClientProvider/publicApiProvider/tokenStorageProvider — ApiClient/PublicApi/TokenStorage construction moved inside ProviderScope"
  - "Hive-backed CacheService (profileBox) with cacheServiceProvider seam, testable via CacheService.inMemory()"
  - "ProfileData AsyncNotifier: cache-first GET /api/me with deduped refresh() and silent background updates"
  - "Working Profile screen proving the Riverpod+Hive walking skeleton end-to-end"
affects: [01-02-foundation-profile-home, 01-03-foundation-profile-home, bands, tracks, setlists]

# Actuals (#2632)
actuals:
  tokens: 18180
  tasks: 1
  commits: 1

# Tech tracking
tech-stack:
  added: [flutter_riverpod 2.6.1, riverpod_annotation 2.6.1, riverpod_generator 2.6.5, build_runner 2.5.4, hive 2.2.3, hive_flutter 1.1.0]
  patterns:
    - "Codegen'd Riverpod Notifiers (@riverpod class X extends _$X) replacing ChangeNotifier/ValueNotifier"
    - "Cache-first AsyncNotifier: build() returns cached data immediately + fires unawaited background refresh; refresh() dedupes concurrent calls via a nullable in-flight Future field"
    - "CacheService backing-store seam (_ProfileStore interface, Hive-backed in prod, in-memory in tests) for ProviderScope-override testability without real file I/O"
    - "ApiClient decoupled from AuthSession via getToken()/onUnauthorized() callback fields instead of a concrete dependency"

key-files:
  created:
    - lib/cache/cache_service.dart
    - lib/providers/auth_provider.dart
    - lib/providers/theme_provider.dart
    - lib/providers/profile_provider.dart
    - test/features/profile/profile_screen_test.dart
  modified:
    - lib/api/api_client.dart
    - lib/api/public_api.dart
    - lib/main.dart
    - lib/app.dart
    - lib/features/auth/auth_gate.dart
    - lib/features/auth/login_screen.dart
    - lib/navigation/root_scaffold.dart
    - lib/features/profile/profile_screen.dart
    - lib/features/settings/settings_screen.dart
    - test/widget_test.dart
    - pubspec.yaml

key-decisions:
  - "Resolved flutter_riverpod/riverpod_generator/build_runner to 2.6.1/2.6.5/2.5.4 instead of the plan's stated 3.4.2/4.0.8/2.16.0 — the 3.x/4.x lines conflict transitively with flutter_test SDK's pinned meta/test_api versions in this environment; used riverpod 2.x's per-provider *Ref typedefs (e.g. TokenStorageRef) instead of the 3.x generic Ref parameter type"
  - "Added a CacheService backing-store abstraction (_ProfileStore, Hive-backed in prod / in-memory in tests) so widget tests never touch real Hive file I/O — async dart:io file operations hang indefinitely inside the flutter_tester engine in this sandbox (confirmed via isolated repro: plain dart run completes async file I/O instantly, flutter test never does), so real-Hive-backed tests were not viable here; production CacheService.initialize() is unchanged (still Hive-backed)"

patterns-established:
  - "Riverpod AsyncNotifier cache-first pattern: build() checks cache -> returns cached + unawaited background refresh, or fetches inline (surfacing ApiException as AsyncError) on a cache miss"
  - "Provider seams (cacheServiceProvider, apiClientProvider) overridden via ProviderScope in tests instead of constructor injection"

requirements-completed: [USER-01, OFFL-01, OFFL-06]

coverage:
  - id: D1
    description: "Profile screen renders the authenticated user's real username and id, fetched from GET /api/me, cache-first"
    requirement: USER-01
    verification:
      - kind: automated_ui
        ref: "test/features/profile/profile_screen_test.dart#cached data present renders immediately with no spinner"
        status: pass
      - kind: automated_ui
        ref: "test/features/profile/profile_screen_test.dart#no cache and network failure shows error state with Retry button"
        status: pass
    human_judgment: false
  - id: D2
    description: "Username longer than 20 characters truncates to a single line with an ellipsis"
    requirement: USER-01
    verification:
      - kind: automated_ui
        ref: "test/features/profile/profile_screen_test.dart#username longer than 20 characters truncates to a single line with ellipsis"
        status: pass
    human_judgment: false
  - id: D3
    description: "First-ever Profile load with no cache and no connectivity shows the error state with a Retry button"
    requirement: OFFL-01
    verification:
      - kind: automated_ui
        ref: "test/features/profile/profile_screen_test.dart#no cache and network failure shows error state with Retry button"
        status: pass
    human_judgment: false
  - id: D4
    description: "Tapping the Profile refresh icon twice in quick succession triggers exactly one GET /api/me network call"
    requirement: OFFL-01
    verification:
      - kind: automated_ui
        ref: "test/features/profile/profile_screen_test.dart#tapping refresh twice quickly triggers exactly one network call"
        status: pass
    human_judgment: false
  - id: D5
    description: "No ChangeNotifier or ValueNotifier subclass exists anywhere under lib/; AuthSession and theme state are Riverpod @riverpod-generated Notifiers"
    requirement: OFFL-06
    verification:
      - kind: other
        ref: "grep -rn \"extends ChangeNotifier\\|extends ValueNotifier\" lib/  (zero matches)"
        status: pass
    human_judgment: false
  - id: D6
    description: "The auth token is never written into a Hive box; cache_service.dart stores only decoded response JSON, token stays exclusively in flutter_secure_storage"
    requirement: OFFL-01
    verification:
      - kind: other
        ref: "grep -n \"token\" lib/cache/cache_service.dart  (zero matches)"
        status: pass
    human_judgment: false
  - id: D7
    description: "AuthSession.signOut() clears all Hive cache boxes via cacheServiceProvider so a different user signing in afterward sees no residual cached data"
    requirement: OFFL-01
    verification: []
    human_judgment: true
    rationale: "Implemented (auth_provider.dart AuthSession.signOut() calls ref.read(cacheServiceProvider).clearAll()) but no automated test in this plan exercises signOut()'s cache-clear path — 01-02-PLAN.md's auth_provider_test.dart is the planned coverage for this. Verified only via code inspection here."
  - id: D8
    description: "On screen load with a warm cache, Profile screen shows cached data immediately with no loading spinner, and a background refresh updates the display silently in place with no animation or toast"
    requirement: OFFL-01
    verification:
      - kind: automated_ui
        ref: "test/features/profile/profile_screen_test.dart#background refresh silently replaces displayed data with no spinner"
        status: pass
    human_judgment: false

# Metrics
duration: ~35min
completed: 2026-08-15
status: complete
---

# Phase 1 Plan 1: Riverpod + Hive Walking Skeleton Summary

**Migrated the app shell off ChangeNotifier/ValueNotifier onto codegen'd Riverpod Notifiers, stood up a Hive-backed cache-store pattern, and proved both end-to-end on a real GET /api/me-backed Profile screen.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-15T07:40:00Z
- **Completed:** 2026-08-15T08:05:44Z
- **Tasks:** 1 (single tracer task, per plan design)
- **Files modified:** 23 (11 created, 10 modified, 2 deleted)

## Accomplishments
- Migrated `AuthSession` and `ThemeController` from `ChangeNotifier`/`ValueNotifier` to codegen'd Riverpod `@riverpod` Notifiers (`authSessionProvider`, `themeControllerProvider`)
- Moved `ApiClient`/`PublicApi`/`TokenStorage` construction inside `ProviderScope`; `ApiClient` now depends on `getToken()`/`onUnauthorized()` callbacks instead of a concrete `AuthSession`
- Built `CacheService` (Hive-backed `profileBox`) with a `cacheServiceProvider` seam, plus a `CacheService.inMemory()` test double so widget tests don't need real file I/O
- Built `ProfileData` `AsyncNotifier`: cache-first `GET /api/me`, silent background refresh, and a deduped `refresh()` for the UI refresh button
- Rewired `main.dart`/`app.dart`/`auth_gate.dart`/`login_screen.dart`/`root_scaffold.dart`/`profile_screen.dart`/`settings_screen.dart` onto `ConsumerWidget`/`ConsumerStatefulWidget` + `ref.watch`; deleted the now-superseded `auth_session.dart` and `theme_controller.dart`
- Added `test/features/profile/profile_screen_test.dart` covering cache-first render, error+retry, silent background refresh, refresh dedup, and long-username truncation — all passing alongside the existing `widget_test.dart`

## Task Commits

Each task was committed atomically:

1. **Task 1: Riverpod + Hive walking skeleton — Profile end-to-end** - `d02c9d1` (feat)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
- `lib/cache/cache_service.dart` - Hive-backed `CacheService` with a swappable `_ProfileStore` backing (Hive in prod, in-memory for tests), `cacheServiceProvider`
- `lib/providers/auth_provider.dart` - `tokenStorageProvider`, `apiClientProvider`, `publicApiProvider`, `AuthSession` Riverpod Notifier / `authSessionProvider`
- `lib/providers/theme_provider.dart` - `ThemeController` Riverpod Notifier / `themeControllerProvider`
- `lib/providers/profile_provider.dart` - `ProfileData` `AsyncNotifier` / `profileDataProvider`, cache-first with deduped refresh
- `lib/api/api_client.dart` - `authSession` field replaced with `getToken`/`onUnauthorized` callback fields
- `lib/api/public_api.dart` - `login()` now returns the token (`Future<String>`) instead of signing in internally
- `lib/main.dart` - `ProviderScope` root, `Hive.initFlutter()` + `CacheService.initialize()` before `runApp`
- `lib/app.dart` - `ConsumerWidget`, no constructor params, watches `themeControllerProvider`
- `lib/features/auth/auth_gate.dart` - `ConsumerWidget` watching `authSessionProvider`
- `lib/features/auth/login_screen.dart` - `ConsumerStatefulWidget`, reads `publicApiProvider`/`authSessionProvider`
- `lib/navigation/root_scaffold.dart` - no constructor params, `ProfileScreen()` takes no args
- `lib/features/profile/profile_screen.dart` - `ConsumerWidget` rendering real `profileDataProvider` data with loading/error/populated states
- `lib/features/settings/settings_screen.dart` - `ConsumerWidget` watching `themeControllerProvider`
- `test/widget_test.dart` - rewritten for `ProviderScope` + mocked `apiClientProvider`
- `test/features/profile/profile_screen_test.dart` - new end-to-end tracer verify
- `pubspec.yaml` - added `flutter_riverpod`, `riverpod_annotation`, `hive`, `hive_flutter`, `riverpod_generator`, `build_runner`
- `lib/api/auth_session.dart` - deleted (superseded by `auth_provider.dart`'s `AuthSession`)
- `lib/theme/theme_controller.dart` - deleted (superseded by `theme_provider.dart`'s `ThemeController`)

## Decisions Made
- Resolved to `flutter_riverpod`/`riverpod_generator`/`build_runner` 2.x versions instead of the plan's stated 3.x/4.x figures — see Deviations below.
- Added a `_ProfileStore` backing-store abstraction inside `CacheService` (not in the original plan text) so tests can use `CacheService.inMemory()` instead of real Hive file I/O — see Deviations below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Downgraded Riverpod/build_runner package versions due to SDK-constraint conflicts**
- **Found during:** Task 1, `flutter pub get`
- **Issue:** The plan's stated versions (`flutter_riverpod: ^3.4.2`, `riverpod_annotation: ^4.0.6`, `riverpod_generator: ^4.0.8`, `build_runner: ^2.16.0`) fail to resolve: `build_runner >=2.15.2` requires `meta ^1.18.3`, but `flutter_test` (SDK) pins `meta 1.18.0`; separately, `riverpod_generator >=4.0.6`'s `analyzer ^13.0.0` requirement transitively conflicts with `flutter_test`'s pinned `test_api`/`matcher` versions. Neither is a "different package" — this is version-resolution against this environment's Flutter/Dart SDK (3.44.9 / 3.12.2), not a legitimacy concern (all packages remain the same ones from the plan's Package Legitimacy Audit).
- **Fix:** Used `flutter pub add` to let pub resolve maximal mutually-compatible versions: `flutter_riverpod ^2.6.1`, `riverpod_annotation ^2.6.1`, `riverpod_generator ^2.6.5`, `build_runner ^2.5.4` (hive/hive_flutter resolved at the plan's stated `2.2.3`/`1.1.0`, unchanged). Adjusted provider code to Riverpod 2.x's per-provider generated `*Ref` typedefs (e.g. `TokenStorageRef`, `ApiClientRef`, `CacheServiceRef`) instead of the plan's Riverpod-3.x-only generic `Ref` parameter type — the `@riverpod` class-based Notifiers (`AuthSession`, `ThemeController`, `ProfileData`) needed no change, since their `ref` field type is inherited from the generated base class either way.
- **Files modified:** `pubspec.yaml`, `pubspec.lock`, `lib/cache/cache_service.dart`, `lib/providers/auth_provider.dart`
- **Verification:** `dart run build_runner build --delete-conflicting-outputs` succeeds; `flutter analyze` clean.
- **Committed in:** `d02c9d1` (Task 1 commit)

**2. [Rule 3 - Blocking] Widget-test environment cannot complete async `dart:io` file operations**
- **Found during:** Task 1, running `flutter test test/features/profile/profile_screen_test.dart`
- **Issue:** The plan's step 4 designed `cache_service.dart` around a real `Hive.openBox` and instructed the test to call `Hive.init(tempDir.path)` + `CacheService.initialize()` directly. In this sandbox, any `async` `dart:io` file operation (e.g. `Directory.systemTemp.createTemp()`, `File.writeAsString()`) hangs indefinitely when run inside the `flutter_tester` engine (`flutter test`), even though the identical async operations complete instantly under plain `dart run`. Isolated with a series of minimal repro tests (a bare `Directory.createTemp()` call inside `testWidgets` never returned; sync `createSync()` worked fine) — this is an environment/engine limitation, not a bug in the app code.
- **Fix:** Refactored `CacheService` to hold a swappable `_ProfileStore` backing interface: `_HiveProfileStore` (production, unchanged behavior) and `_InMemoryProfileStore` (a plain-`Map` test double, exposed via `@visibleForTesting factory CacheService.inMemory()`). `test/features/profile/profile_screen_test.dart` overrides `cacheServiceProvider` directly with `CacheService.inMemory()` instead of touching real Hive/temp-directory I/O — this is exactly the seam the plan's own step 4 called out ("this is the seam that makes profile_provider.dart and auth_provider.dart testable via ProviderScope overrides"), just realized via `cacheServiceProvider.overrideWithValue(...)` instead of real-Hive-in-a-temp-dir.
- **Files modified:** `lib/cache/cache_service.dart`, `test/features/profile/profile_screen_test.dart`
- **Verification:** `flutter test` (whole suite) passes in ~1s with no hangs; `flutter analyze` clean; production `CacheService.initialize()` path (real Hive) is unchanged and still exercised by `lib/main.dart` at app runtime.
- **Committed in:** `d02c9d1` (Task 1 commit)

**3. [Rule 1 - Bug] Fixed a test race between cache display and background refresh**
- **Found during:** Task 1, `flutter test` (after fixing deviation #2)
- **Issue:** The "background refresh silently replaces displayed data" test asserted the stale cached value (`oldname`) was visible immediately after the first `pump()`, but with the in-memory cache store the background refresh (fired via `unawaited(_refresh())` in `build()`) could resolve fast enough to already show `newname` by the first pump, making the assertion flaky/failing.
- **Fix:** Added a small `Future.delayed(50ms)` to that test's mocked network handler, matching the pattern already used in the refresh-dedup test, so the "before" frame is reliably observable.
- **Files modified:** `test/features/profile/profile_screen_test.dart`
- **Verification:** Test passes consistently across repeated runs.
- **Committed in:** `d02c9d1` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (2 blocking, 1 bug)
**Impact on plan:** All three were necessary to get a genuinely working, testable Riverpod + Hive foundation in this environment. No scope creep — the `CacheService` backing-store seam is additive testability infrastructure directly serving the plan's own stated intent (D-09/D-10 in `01-CONTEXT.md`), not a design change to the cache's on-device behavior.

## Issues Encountered
See Deviations above — the two blocking issues (package version resolution, async file I/O hang under `flutter_tester`) were both environment-specific constraints discovered and resolved during verification, not design gaps in the plan.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `authSessionProvider`, `apiClientProvider`, `publicApiProvider`, `tokenStorageProvider`, `cacheServiceProvider`, and the `_ProfileStore` testability pattern are all available for 01-02 (Bands/Tracks/Setlists groundwork) and 01-03 (Home screen tracer) to build on directly.
- 01-02-PLAN.md's `auth_provider_test.dart` should cover `AuthSession.signOut()`'s cache-clearing path (D7 above), which this plan implemented but did not itself test.
- Manual airplane-mode spot-check of the Profile screen (the plan's `<human-check>`) is deferred to end-of-phase per `human_verify_mode: end-of-phase` in `.planning/config.json` — not blocking for this plan's completion.

---
*Phase: 01-foundation-profile-home*
*Completed: 2026-08-15*

## Self-Check: PASSED

- All 15 created/modified files listed above confirmed present on disk.
- Both deleted files (`lib/api/auth_session.dart`, `lib/theme/theme_controller.dart`) confirmed absent.
- Task commit `d02c9d1` confirmed present in git log.
- `flutter analyze`: no issues found.
- `flutter test` (full suite): 6/6 passing.
- `grep -rn "extends ChangeNotifier\|extends ValueNotifier" lib/`: zero matches.
- `grep -rln "authSession:" lib/`: zero matches.
