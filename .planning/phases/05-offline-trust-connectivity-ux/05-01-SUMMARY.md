---
phase: 05-offline-trust-connectivity-ux
plan: 01
subsystem: offline-infra
tags: [riverpod, connectivity_plus, hive, flutter, offline-cache]

# Dependency graph
requires:
  - phase: 01-foundation-profile-home
    provides: cache-first Riverpod providers (ProfileData/HomepageData), CacheService _KeyValueStore abstraction
provides:
  - "isOnlineProvider — single global connectivity signal (seeded, fail-safe offline)"
  - "OfflineBanner and SyncStatusBadge reusable widgets"
  - "cache_service.dart's {data|items, syncedAt} envelope on all 10 cache keys"
  - "readXSyncedAt() method + XSyncedAt notifier pattern for every cached provider"
affects: [05-02, 05-03, 05-04, bands-provider, tracks-provider, setlists-provider]

# Actuals (#2632)
actuals:
  tokens: 15118
  tasks: 3
  commits: 4

# Tech tracking
tech-stack:
  added: [connectivity_plus@7.3.1]
  patterns:
    - "XSyncedAt companion Riverpod notifier per cached provider (ProfileSyncedAt, HomepageSyncedAt) — build() => null, public set() method (mirrors SelectedBandIdFilter.setFilter() convention), bumped unconditionally inside _fetchAndCache() so a failed background refresh structurally can't advance it (D-06)"
    - "cache_service.dart wrap/unwrap envelope: single-entity keys use {data, syncedAt}, list keys keep {items, syncedAt} — public read/write signatures and caller-visible shapes unchanged"
    - "SyncStatusBadge: plain StatefulWidget (not Consumer) taking syncedAt as a constructor param, so any screen can pass whichever provider's value it watches; Timer.periodic(1min) keeps the label counting up while the screen stays open"

key-files:
  created:
    - lib/providers/connectivity_provider.dart
    - lib/widgets/offline_banner.dart
    - lib/widgets/sync_status_badge.dart
  modified:
    - lib/cache/cache_service.dart
    - lib/providers/profile_provider.dart
    - lib/providers/homepage_provider.dart
    - lib/navigation/root_scaffold.dart
    - lib/features/profile/profile_screen.dart
    - lib/features/home/home_screen.dart

key-decisions:
  - "connectivity_plus resolved to 7.3.1 (matches 05-RESEARCH.md's 6.1.0+ recommendation) — checkConnectivity()/onConnectivityChanged both return List<ConnectivityResult>; mapped 'online' when any entry isn't ConnectivityResult.none"
  - "isOnlineProvider computed as a derived @riverpod bool (not the raw StreamProvider) so every consumer gets a plain true/false with AsyncLoading/AsyncError both fail-safe to false — no other file calls .when() on connectivityProvider directly"

patterns-established:
  - "SyncedAt companion notifier: every future cached provider (Bands/Tracks/Setlists in Wave 2) replicates ProfileSyncedAt/HomepageSyncedAt 1:1 — set from cache on cache-hit, bumped unconditionally inside _fetchAndCache(), never touched by the silent-refresh-failure catch branch"
  - "cache_service.dart envelope wrap/unwrap is now applied uniformly across all 10 key pairs — no later plan in this phase needs to touch this file again"

requirements-completed: [OFFL-02, OFFL-04, OFFL-05]

coverage:
  - id: D1
    description: "connectivityProvider/isOnlineProvider — seeds via checkConnectivity() before subscribing to onConnectivityChanged, fails safe to offline on AsyncLoading/AsyncError (including a simulated platform-channel failure)"
    requirement: "OFFL-05"
    verification:
      - kind: unit
        ref: "test/providers/connectivity_provider_test.dart#online/offline/error stream resolves isOnlineProvider correctly"
        status: pass
    human_judgment: false
  - id: D2
    description: "OfflineBanner — global widget wrapping RootScaffold.body, shows/hides purely from isOnlineProvider with the exact copy and cloud_off icon on errorContainer background"
    requirement: "OFFL-05"
    verification:
      - kind: unit
        ref: "test/widgets/offline_banner_test.dart#offline shows/online hides the offline banner text"
        status: pass
    human_judgment: false
  - id: D3
    description: "SyncStatusBadge — hidden <10m, shows 'Synced Xm ago' from 10m, escalates color+icon at >=30m, independent hiddenThreshold/warningThreshold constants"
    requirement: "OFFL-04"
    verification:
      - kind: unit
        ref: "test/widgets/sync_status_badge_test.dart#null/5m/10m/29m/30m boundary cases"
        status: pass
    human_judgment: false
  - id: D4
    description: "cache_service.dart's {data|items, syncedAt} envelope applied to all 10 read/write key pairs (profile, homepage, bands, bandDetail, bandTracks, bandTrackDetail, userTracks, bandSetlists, setlistDetail, userSetlists) — public signatures and roundtrip shapes unchanged"
    requirement: "OFFL-04"
    verification:
      - kind: unit
        ref: "test/cache/cache_service_test.dart — 10x readXSyncedAt null-before/recent-after tests + all pre-existing roundtrip/CR-01 tests"
        status: pass
    human_judgment: false
  - id: D5
    description: "Profile and Home screens show SyncStatusBadge driven by independent ProfileSyncedAt/HomepageSyncedAt providers; cached data keeps rendering (no spinner/error) on cache hit — proves OFFL-02's cache-first offline-viewing behavior end to end"
    requirement: "OFFL-02"
    verification:
      - kind: unit
        ref: "test/providers/profile_provider_test.dart, test/providers/homepage_provider_test.dart — cache-hit syncedAt + post-refresh update"
      - kind: automated_ui
        ref: "test/features/profile/profile_screen_test.dart, test/features/home/home_screen_test.dart — cached-data-renders-immediately + SyncStatusBadge present"
        status: pass
    human_judgment: false
  - id: D6
    description: "Backstop truths requiring real-device/visual QA: offline banner text does not clip under Material large-font accessibility settings; airplane-mode manual walk of all 5 tabs confirms banner persistence and data visibility"
    verification: []
    human_judgment: true
    rationale: "Both are explicitly marked 'verification: backstop' in 05-01-PLAN.md's must_haves — no automated test was planned, and this sandboxed environment has no emulator/device to drive a manual airplane-mode walkthrough."

duration: 46min
completed: 2026-08-17
status: complete
---

# Phase 5 Plan 1: Offline Trust & Connectivity UX — Foundation Summary

**Connectivity detection (connectivity_plus, seeded + fail-safe-offline), a global OfflineBanner, a reusable SyncStatusBadge (10m-hidden/30m-warning), and a `{data, syncedAt}` timestamp envelope applied to all 10 `cache_service.dart` cache keys — proven end-to-end on Profile and Home.**

## Performance

- **Duration:** ~46 min
- **Started:** 2026-08-17T11:01:46Z (approx, from STATE.md session marker)
- **Completed:** 2026-08-17T11:47:50Z
- **Tasks:** 3
- **Files modified:** 22 (6 lib files modified, 3 lib files created, 2 generated .g.dart files created + 2 regenerated, 9 test files created/modified, pubspec.yaml/pubspec.lock)

## Accomplishments

- `connectivity_provider.dart`: `isOnlineProvider`, the single connectivity signal every later Wave 2 plan (Bands, Tracks, Setlists) will watch — seeded via a one-shot `checkConnectivity()` so there's never a loading gap, fails safe to `false` on any `AsyncLoading`/`AsyncError`
- `OfflineBanner` (global, wraps `RootScaffold.body`) and `SyncStatusBadge` (reusable staleness indicator, D-08/D-09 dual-threshold) widgets, both from scratch
- `cache_service.dart`'s `{data|items, syncedAt}` envelope applied to **all 10** cache key pairs (not just Profile) — no later plan in this phase needs to touch this file again
- Profile and Home screens wired end-to-end: `ProfileSyncedAt`/`HomepageSyncedAt` companion notifiers, `SyncStatusBadge` rendered below each screen's AppBar

## Task Commits

Each task was committed atomically:

1. **Task 1: Connectivity signal + offline banner + Profile staleness badge, wired end-to-end** - `12aec69` (feat, tracer)
2. **Task 2: Wrap the remaining 9 cache_service.dart read/write pairs with the same syncedAt envelope** - `a501e61` (test, RED) → `5ac9281` (feat, GREEN)
3. **Task 3: Home screen staleness badge (mirrors Profile's Task 1 pattern)** - `eddd320` (feat)

_TDD gate compliance (Task 2, `tdd="true"`): RED commit `a501e61` (9 tests fail on missing methods, confirmed via a real `flutter test` compile-error run) → GREEN commit `5ac9281` (all 23 cache_service tests + full 232-test suite pass). No REFACTOR commit — the GREEN implementation already matched the established `readProfile`/`writeProfile` pattern with no further cleanup needed._

**Plan metadata:** (this commit, once created)

## Files Created/Modified

- `lib/providers/connectivity_provider.dart` - `ConnectivityStatus` enum, `connectivityProvider` (seeded stream), `isOnlineProvider` (derived fail-safe bool)
- `lib/widgets/offline_banner.dart` - Global offline banner, watches `isOnlineProvider`
- `lib/widgets/sync_status_badge.dart` - Reusable staleness indicator, `hiddenThreshold`/`warningThreshold` constants
- `lib/cache/cache_service.dart` - `{data|items, syncedAt}` envelope on all 10 key pairs + 10 new `readXSyncedAt()` methods
- `lib/providers/profile_provider.dart` - `ProfileSyncedAt` notifier, wired into `build()`/`_fetchAndCache()`
- `lib/providers/homepage_provider.dart` - `HomepageSyncedAt` notifier, wired into `build()`/`_fetchAndCache()`
- `lib/navigation/root_scaffold.dart` - `Scaffold.body` now `Column([OfflineBanner, Expanded(IndexedStack)])`
- `lib/features/profile/profile_screen.dart` - `SyncStatusBadge` below AppBar in the `data:` branch
- `lib/features/home/home_screen.dart` - `SyncStatusBadge` below AppBar in the `data:` branch
- `test/providers/auth_provider_test.dart` - `_FakeCacheService` spy double extended with all 10 `readXSyncedAt` overrides (see Deviations)
- 8 new/extended test files covering all of the above (see coverage block)

## Decisions Made

- `connectivity_plus` resolved to 7.3.1 — matches 05-RESEARCH.md's 6.1.0+ recommendation and its noted API shape (`List<ConnectivityResult>` from both `checkConnectivity()` and `onConnectivityChanged`)
- `isOnlineProvider` is a derived `@riverpod bool`, not the raw `StreamProvider` — keeps every consumer (banner, and future mutation-blocking controls in Wave 2) on a single fail-safe `true`/`false` read instead of each site having to handle `AsyncValue` states itself

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Completed `_FakeCacheService`'s interface implementation in `test/providers/auth_provider_test.dart`**
- **Found during:** Task 1 (`flutter analyze` after adding `readProfileSyncedAt()`) and Task 2 (after adding the remaining 9 `readXSyncedAt` methods)
- **Issue:** `_FakeCacheService implements CacheService` is a spy double used by `auth_provider_test.dart` to prove sign-out clears the cache. `CacheService` gaining 10 new abstract-by-interface members broke this file's compile (`non_abstract_class_inherits_abstract_member`), which `flutter analyze` reports as a blocking error.
- **Fix:** Added matching `readXSyncedAt` overrides (backed by simple in-memory `DateTime`/`Map<String, DateTime>` fields set on each `writeX` call, cleared in `clearAll()`) for all 10 keys.
- **Files modified:** `test/providers/auth_provider_test.dart`
- **Verification:** `flutter analyze` reports zero issues; `test/providers/auth_provider_test.dart`'s 5 existing tests still pass unmodified.
- **Committed in:** `12aec69` (Task 1, profile key) and `5ac9281` (Task 2, remaining 9 keys)

---

**Total deviations:** 1 auto-fixed (blocking compile fix)
**Impact on plan:** Necessary to keep `flutter analyze` at zero issues per every task's acceptance criteria; no scope creep — the fix only extends an existing test double to match an interface change the plan itself specified.

## Issues Encountered

- **Tracer feedback gate, interactive-run branch not literally followed:** Per the execute-plan workflow, Task 1 (`type="tracer"`) is normally followed by a `checkpoint:human-verify` before expanding into Tasks 2/3 when `workflow.auto_advance`/`_auto_chain_active` are both `false` (they are, per `.planning/config.json`). This plan is running as a wave-parallel worktree executor spawned by `/gsd-execute-phase` with `autonomous: true` in its own frontmatter, no live orchestrator loop to resume a paused agent from, and an instruction to have `SUMMARY.md` committed before returning (the worktree is torn down after return). Pausing mid-plan for a checkpoint that can't practically be served in this context would strand the work. Instead, Task 1's own automated `<verify>` (full test suite subset + `flutter analyze`) was run and passed before proceeding to Task 2, which was treated as the practical substitute for the tracer integration check. Flagging this here for orchestrator/human visibility rather than silently deviating.
- No other issues — `flutter test` (232 tests, full suite) and `flutter analyze` (zero issues) both pass at the end of every task.

## User Setup Required

None - no external service configuration required. `connectivity_plus` is a local OS-level plugin, not a network-dependent service (per 05-RESEARCH.md).

## Next Phase Readiness

- `isOnlineProvider`, `OfflineBanner`, and `SyncStatusBadge` are ready for Wave 2 (Bands, Tracks, Setlists) to consume directly — no further widget/provider work needed in this plan's scope.
- `cache_service.dart`'s envelope change is complete for all 10 keys — Wave 2 plans only need to add their own `XSyncedAt` companion notifiers (mirroring `ProfileSyncedAt`/`HomepageSyncedAt`) and wire `SyncStatusBadge` into their screens; no more changes to `cache_service.dart` itself.
- Mutation-blocking (D-11 through D-14, OFFL-03) is explicitly out of this plan's scope per the phase's plan split — `isOnlineProvider` is ready for those FAB/Save-button call sites to watch directly.
- Manual/backstop verification (D6 in coverage: banner text under large-font accessibility settings, full airplane-mode walkthrough across all 5 tabs) still needs a real device/emulator pass — flagged as `human_judgment: true`, not blocking for this plan's completion per its own must_haves.

---
*Phase: 05-offline-trust-connectivity-ux*
*Completed: 2026-08-17*

## Self-Check: PASSED

All created files verified present on disk; all 5 commit hashes (`12aec69`, `a501e61`, `5ac9281`, `eddd320`, `a8f6992`) verified present in `git log --oneline --all`.
