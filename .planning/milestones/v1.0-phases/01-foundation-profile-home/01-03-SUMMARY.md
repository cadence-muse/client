---
phase: 01-foundation-profile-home
plan: 03
subsystem: state-management
tags: [riverpod, hive, flutter, cache, home-screen]

# Dependency graph
requires:
  - phase: 01-foundation-profile-home (01-01)
    provides: "Riverpod+Hive cache-first pattern (CacheService seam, ProfileData AsyncNotifier, apiClientProvider/cacheServiceProvider) proven end-to-end on Profile"
provides:
  - "homepageDataProvider (HomepageData AsyncNotifier): cache-first GET /api/homepage with deduped refresh()"
  - "CacheService.readHomepage()/writeHomepage(), homepageBox as a second Hive box alongside profileBox (D-02)"
  - "Working Home screen: populated/empty/error states, pluralized + comma-grouped bandsCount, long-username ellipsis"
  - "Generalized CacheService key-value store abstraction (_KeyValueStore/_HiveStore/_InMemoryStore) proven to back 2 independent boxes — the exact proof point Phase 2's bandsBox needs"
affects: [bands, tracks, setlists, phase-5-offline-ux]

# Actuals (#2632)
actuals:
  tokens: 6549
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CacheService backing-store abstraction generalized from a single-box shape (_ProfileStore) to a per-box _KeyValueStore, so each new cached endpoint (D-02) adds one more store instance instead of a new class hierarchy"
    - "HomepageData AsyncNotifier is structurally identical to ProfileData — cache-first build() + deduped refresh() — confirming the pattern generalizes cleanly to a second endpoint"

key-files:
  created:
    - lib/providers/homepage_provider.dart
    - test/cache/cache_service_test.dart
    - test/providers/homepage_provider_test.dart
    - test/features/home/home_screen_test.dart
  modified:
    - lib/cache/cache_service.dart
    - lib/features/home/home_screen.dart
    - test/providers/auth_provider_test.dart

key-decisions:
  - "Renamed CacheService's internal _ProfileStore/_HiveProfileStore/_InMemoryProfileStore to _KeyValueStore/_HiveStore/_InMemoryStore (same shape, endpoint-agnostic name) since the abstraction now backs two independent boxes (profileBox, homepageBox) instead of one — see Deviations"
  - "homepage_provider_test.dart's dedup test keeps a live container.listen() subscription on the (autoDispose) provider before exercising refresh() twice — without it, the provider's zero-listener autoDispose window let it get recreated between reads, which looked like a broken dedup until isolated"

patterns-established: []

requirements-completed: [USER-02, OFFL-01]

coverage:
  - id: D1
    description: "Home screen renders the real welcome message and bandsCount fetched from GET /api/homepage, cache-first"
    requirement: USER-02
    verification:
      - kind: automated_ui
        ref: "test/features/home/home_screen_test.dart#bandsCount 1 shows \"1 band\" (singular)"
        status: pass
      - kind: unit
        ref: "test/providers/homepage_provider_test.dart#cache-hit returns cached data immediately with a silent background refresh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Home screen displays a 'No bands yet' empty state (heading, body, 'Create Band' button) when bandsCount is 0"
    requirement: USER-02
    verification:
      - kind: automated_ui
        ref: "test/features/home/home_screen_test.dart#bandsCount 0 shows \"No bands yet\" + \"Create Band\""
        status: pass
    human_judgment: false
  - id: D3
    description: "Home screen displays exactly '1 band' (singular) when bandsCount is 1, '2 bands' when bandsCount is 2, and '1,250 bands' (comma-grouped, no abbreviation) for large counts, with no client-side rounding/truncation applied to the server integer"
    requirement: USER-02
    verification:
      - kind: automated_ui
        ref: "test/features/home/home_screen_test.dart#bandsCount 2 shows \"2 bands\" (plural)"
        status: pass
      - kind: automated_ui
        ref: "test/features/home/home_screen_test.dart#bandsCount 1250 shows \"1,250 bands\" (comma-grouped, exact)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Tapping the Home refresh icon twice in quick succession triggers exactly one GET /api/homepage network call"
    requirement: OFFL-01
    verification:
      - kind: unit
        ref: "test/providers/homepage_provider_test.dart#two rapid refresh() calls trigger exactly one network call"
        status: pass
    human_judgment: false
  - id: D5
    description: "First-ever Home load with no cache and no connectivity shows the 'Couldn't load home' / 'Please check your connection and try again.' error state with a Retry button"
    requirement: OFFL-01
    verification:
      - kind: automated_ui
        ref: "test/features/home/home_screen_test.dart#no cache and network failure shows \"Couldn't load home\" + Retry"
        status: pass
      - kind: unit
        ref: "test/providers/homepage_provider_test.dart#no cache and network failure yields AsyncError"
        status: pass
    human_judgment: false
  - id: D6
    description: "Home screen truncates a username longer than 20 characters in the welcome message to a single line with an ellipsis"
    requirement: USER-02
    verification:
      - kind: automated_ui
        ref: "test/features/home/home_screen_test.dart#username longer than 20 characters truncates to a single line with ellipsis"
        status: pass
    human_judgment: false
  - id: D7
    description: "CacheService.clearAll() empties both profileBox and homepageBox"
    requirement: OFFL-01
    verification:
      - kind: unit
        ref: "test/cache/cache_service_test.dart#clearAll() empties both profileBox and homepageBox"
        status: pass
    human_judgment: false
  - id: D8
    description: "readProfile/writeProfile and readHomepage/writeHomepage roundtrip through real Hive (not the in-memory test double)"
    requirement: OFFL-01
    verification:
      - kind: unit
        ref: "test/cache/cache_service_test.dart#writeProfile then readProfile roundtrips the same map"
        status: pass
      - kind: unit
        ref: "test/cache/cache_service_test.dart#writeHomepage then readHomepage roundtrips the same map"
        status: pass
    human_judgment: false
  - id: D9
    description: "On screen load with a warm cache, Home screen shows cached data immediately with no loading spinner, and a background refresh updates the display silently in place"
    requirement: OFFL-01
    verification:
      - kind: unit
        ref: "test/providers/homepage_provider_test.dart#cache-hit returns cached data immediately with a silent background refresh"
        status: pass
    human_judgment: true
    rationale: "The provider-level test proves cache-first return + a background refresh fires and completes (no error surfaced), matching the code path ProfileData's equivalent (already human-verified in 01-01) uses. It does not itself assert 'no spinner is rendered mid-refresh' at the widget layer the way profile_screen_test.dart's dedicated test does — home_screen_test.dart's other cases cover the populated-render path but this specific silent-swap framing is asserted at the provider layer here, not re-verified at the widget layer, per the plan's 'backstop' verification designation for this truth."
---

# Phase 1 Plan 3: Home Screen — Cache-First GET /api/homepage Summary

**Wired the Home tab to real `GET /api/homepage` data using the exact cache-first Riverpod+Hive pattern proven for Profile in 01-01, adding a second per-endpoint Hive box (`homepageBox`) and completing OFFL-01 test coverage for both Phase 1 endpoints.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-08-15T11:05:00Z
- **Completed:** 2026-08-15T11:45:00Z
- **Tasks:** 2
- **Files modified:** 8 (4 created, 4 modified)

## Accomplishments
- Generalized `CacheService`'s internal store abstraction to back two independent Hive boxes (`profileBox`, `homepageBox`), proving D-02's "one box per endpoint" pattern generalizes — the exact proof point Phase 2's `bandsBox` needs
- Added `readHomepage()`/`writeHomepage()` to `CacheService`, extended `clearAll()` to clear both boxes
- Built `lib/providers/homepage_provider.dart`: `HomepageData` `AsyncNotifier`, structurally identical to `ProfileData` — cache-first `GET /api/homepage` with a silent background refresh and a deduped user-initiated `refresh()`
- Rewrote `lib/features/home/home_screen.dart` as a `ConsumerWidget`: populated (welcome message + pluralized/comma-grouped band count), empty (`bandsCount == 0` → "No bands yet" + "Create Band" navigating to `BandsScreen`), and error ("Couldn't load home" + Retry) states
- Added `test/cache/cache_service_test.dart` (real Hive, temp-dir backed — no fakes), `test/providers/homepage_provider_test.dart` (cache-hit, no-cache+failure, refresh-dedup), and `test/features/home/home_screen_test.dart` (0/1/2/1250 band counts, error, long-username truncation) — 14 new tests, all passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Home screen — cache-first GET /api/homepage, real UI** - `33c8a9c` (feat)
2. **Task 2: Test coverage — cache_service (both boxes), homepage_provider, home_screen** - `015e865` (test)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
- `lib/cache/cache_service.dart` - Added `homepageBox`/`readHomepage()`/`writeHomepage()`; generalized the internal store abstraction (`_KeyValueStore`/`_HiveStore`/`_InMemoryStore`) to back two boxes; `clearAll()` now clears both
- `lib/providers/homepage_provider.dart` - `HomepageData` `AsyncNotifier` / `homepageDataProvider`, cache-first `GET /api/homepage` with deduped `refresh()`
- `lib/providers/homepage_provider.g.dart` - Riverpod codegen output
- `lib/features/home/home_screen.dart` - `ConsumerWidget` rendering real homepage data: populated/empty/error states, pluralization + comma-grouping, long-username ellipsis
- `test/cache/cache_service_test.dart` - Real Hive-backed roundtrip coverage for both boxes plus `clearAll()`
- `test/providers/homepage_provider_test.dart` - Cache-first + refresh-dedup unit coverage for `HomepageData`
- `test/features/home/home_screen_test.dart` - Widget-level coverage of populated/empty/error/pluralization/overflow/truncation states
- `test/providers/auth_provider_test.dart` - `_FakeCacheService` extended with `readHomepage`/`writeHomepage` stubs (required since it `implements CacheService`)

## Decisions Made
- Followed the codebase's already-established `CacheService` backing-store abstraction (introduced as a deviation in 01-01) rather than the plan's literal "add a `Box<Map> _homepageBox` field" instruction, since the abstraction is what actually makes `CacheService.inMemory()` (used throughout the test suite) possible — see Deviations.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Generalized `CacheService`'s internal store abstraction instead of adding a second raw `Box<Map>` field**
- **Found during:** Task 1
- **Issue:** The plan's action text (written against `01-PATTERNS.md`'s original scaffold) instructs adding a literal `Box<Map> _homepageBox` field to `CacheService`. But 01-01-PLAN.md's actual execution deviated from that scaffold: `CacheService` is built around a `_ProfileStore` abstraction (`_HiveProfileStore` in prod, `_InMemoryProfileStore` for tests) specifically so `CacheService.inMemory()` can back `cacheServiceProvider` overrides in widget tests without real Hive/file I/O (see 01-01-SUMMARY.md Deviation #2). Implementing the plan literally would have either broken that testability seam or required a parallel, inconsistent pattern for the new box.
- **Fix:** Generalized the abstraction from a single-box shape (`_ProfileStore`) to a per-box `_KeyValueStore`, renaming `_HiveProfileStore`→`_HiveStore` and `_InMemoryProfileStore`→`_InMemoryStore` (same interface, endpoint-agnostic name). `CacheService` now holds two independent store instances (`_profileStore`, `_homepageStore`), one per Hive box, matching D-02's "one box per endpoint" intent while keeping the exact same `CacheService.inMemory()` testability seam 01-01 established.
- **Files modified:** `lib/cache/cache_service.dart`
- **Verification:** `flutter analyze` clean; `test/cache/cache_service_test.dart` proves real-Hive roundtrips for both boxes independently and that `clearAll()` empties both.
- **Committed in:** `33c8a9c` (Task 1 commit)

**2. [Rule 3 - Blocking] Updated `test/providers/auth_provider_test.dart`'s `_FakeCacheService` to implement the two new `CacheService` methods**
- **Found during:** Task 1, `flutter analyze` after adding `readHomepage`/`writeHomepage` to `CacheService`
- **Issue:** `test/providers/auth_provider_test.dart`'s `_FakeCacheService implements CacheService` — since `CacheService` is a concrete class (not an interface), `implements` requires every public method to be overridden. Adding `readHomepage()`/`writeHomepage()` to `CacheService` broke that file's compile (missing overrides), even though the file isn't in this plan's `files_modified` list.
- **Fix:** Added `readHomepage()`/`writeHomepage()` stubs to `_FakeCacheService`, backed by a second in-memory map, and extended its `clearAll()` fake to clear both — mirroring the shape `CacheService` itself now has.
- **Files modified:** `test/providers/auth_provider_test.dart`
- **Verification:** `flutter test test/providers/auth_provider_test.dart` passes (all 5 cases, including the pre-existing `signOut()` cache-clear test).
- **Committed in:** `33c8a9c` (Task 1 commit)

**3. [Rule 1 - Bug] Fixed a false-positive refresh-dedup failure caused by `AutoDispose` provider recreation between test reads**
- **Found during:** Task 2, `flutter test test/providers/homepage_provider_test.dart` (first attempt at the "two rapid refresh() calls" case)
- **Issue:** `homepageDataProvider` is Riverpod's default `AutoDisposeAsyncNotifierProvider` (same as `profileDataProvider`/`authSessionProvider`). A `ProviderContainer.read(...)` call with no persistent listener leaves the provider eligible for immediate autodispose; between reading `.future` and later reading `.notifier`, the provider could be disposed and silently rebuilt, producing a fresh `HomepageData` instance whose `_inFlightRefresh` dedup field started `null` again — making a correctly-implemented dedup (isolated and confirmed correct with a standalone Dart repro) appear to fire two network calls in the test.
- **Fix:** Added `container.listen(homepageDataProvider, (_, _) {});` before exercising `refresh()`, keeping the provider alive across the test's `await`/delay boundaries — the same guarantee a widget's `ref.watch(homepageDataProvider)` provides in production and in `profile_screen_test.dart`'s equivalent widget-level dedup test.
- **Files modified:** `test/providers/homepage_provider_test.dart`
- **Verification:** Test passes consistently across repeated runs; isolated standalone-Dart repro confirmed the dedup logic itself was already correct.
- **Committed in:** `015e865` (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 bug in this file's structure, 1 blocking, 1 test-infra bug)
**Impact on plan:** All three keep the plan's stated behavior/contract intact — no scope creep. The first two are necessary to preserve 01-01's already-established testability pattern; the third fixed a test-only false negative, not application code.

## Issues Encountered
See Deviations above. No issues required design changes or user input.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `homepageDataProvider`, `CacheService.readHomepage()`/`writeHomepage()`, and the generalized `_KeyValueStore` abstraction are all available for Phase 2 (Bands) to add a third box (`bandsBox`) following the identical pattern.
- Phase 1's two endpoints (Profile, Home) now both have cache-first Riverpod coverage and real-Hive-backed cache tests, completing OFFL-01 and USER-02 for this phase.
- Manual airplane-mode spot-check of the Home screen (mirroring Profile's deferred check) remains deferred to end-of-phase per `human_verify_mode: end-of-phase` in `.planning/config.json` — not blocking for this plan's completion.

---
*Phase: 01-foundation-profile-home*
*Completed: 2026-08-15*

## Self-Check: PASSED

- All 8 created/modified source/test files confirmed present on disk.
- Both task commits (`33c8a9c`, `015e865`) confirmed present in git log.
- `flutter analyze`: no issues found.
- `flutter test`: full suite passes (27 tests, including the 14 new tests from this plan).
