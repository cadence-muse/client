---
phase: 05-offline-trust-connectivity-ux
plan: 05
subsystem: testing
tags: [flutter_test, riverpod, regression-guard, offline-cache]

# Dependency graph
requires:
  - phase: 05-offline-trust-connectivity-ux
    provides: "05-01 through 05-04: isOnlineProvider/OfflineBanner/SyncStatusBadge, cache_service.dart's {data|items, syncedAt} envelope + readXSyncedAt() methods, and the SyncStatusBadge + isOnlineProvider gating wired into every Profile/Home/Bands/Tracks/Setlists screen and mutation control"
provides:
  - "test/regression/offline_trust_regression_test.dart — deterministic static-content regression guard: 10 cached screens must contain 'SyncStatusBadge', 19 mutation-control files must contain 'isOnlineProvider', root_scaffold.dart must contain 'OfflineBanner', cache_service.dart must expose all 10 readXSyncedAt() names"
  - "test/offline_cross_tab_test.dart — one running CadenceApp instance proving the offline banner shows exactly once on every one of the 5 bottom-nav tabs and disappears app-wide when connectivity returns"
affects: []

# Actuals (#2632)
actuals:
  tokens: 2995
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Static file-content regression guard: pure dart:io File(path).readAsStringSync().contains(substring) over explicit path lists (not a recursive Directory.listSync() scan) — appropriate when the property under test is per-file-and-substring rather than tree-wide, mirroring test/providers/auth_provider_test.dart's OFFL-06 guard's dart:io-only, no-widget-pumping approach"
    - "Cross-tab live-transition test: isOnlineProvider.overrideWithValue(bool) driven across two tester.pumpWidget() calls (not connectivityProvider.overrideWith(Stream)) — the reliable way to force a provider-value change to propagate across a full second pumpWidget() in Riverpod 2.6.1"

key-files:
  created:
    - test/regression/offline_trust_regression_test.dart
    - test/offline_cross_tab_test.dart
  modified: []

key-decisions:
  - "Task 2 drives the offline->online transition through isOnlineProvider.overrideWithValue(bool) instead of the plan's literal connectivityProvider.overrideWith((ref) => Stream.value(status)) — verified empirically (see Deviations) that the latter does not reliably propagate across a second tester.pumpWidget() call in this Riverpod version, matching 05-04-SUMMARY.md's documented overrideWith-vs-overrideWithValue finding"
  - "Task 2's MockClient handler extends test/widget_test.dart's shape with /api/track/list and /api/setlist/list cases — with 1 band seeded, both global Tracks and Setlists tabs' filter dropdown triggers their cross-band list fetch on first build, which the pre-existing widget_test.dart handler (2-endpoint switch) doesn't cover"
  - "Cross-tab test taps scoped to find.descendant(of: find.byType(NavigationBar), matching: find.text(label)) rather than a bare find.text(label) — the AppBar title on Bands/Tracks/Setlists screens duplicates the tab's own label text once that tab is selected, making a bare text finder ambiguous"

patterns-established:
  - "Any future cross-cutting 'is this true everywhere' aggregate claim (spanning N already-implemented files) gets its own explicit-path-list regression guard rather than resting on each contributing plan's isolated test coverage — this plan's two files are the template for the next one"

requirements-completed: [OFFL-02, OFFL-03, OFFL-04, OFFL-05]

coverage:
  - id: D1
    description: "Static regression guard: all 10 cached screens (Profile, Home, Bands list/detail, Tracks global/per-band-list/detail, Setlists global/per-band-list/detail) contain the SyncStatusBadge substring"
    requirement: "OFFL-04"
    verification:
      - kind: unit
        ref: "test/regression/offline_trust_regression_test.dart#every cached screen renders SyncStatusBadge (OFFL-04 regression guard)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Static regression guard: all 19 mutation-control files across Bands/Tracks/Setlists contain the isOnlineProvider substring"
    requirement: "OFFL-03"
    verification:
      - kind: unit
        ref: "test/regression/offline_trust_regression_test.dart#every mutation control references isOnlineProvider (OFFL-03 regression guard)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Static regression guard: root_scaffold.dart references OfflineBanner, and cache_service.dart exposes all 10 readXSyncedAt() accessor names"
    requirement: "OFFL-05"
    verification:
      - kind: unit
        ref: "test/regression/offline_trust_regression_test.dart#RootScaffold renders the global OfflineBanner (OFFL-05 regression guard), cache_service.dart exposes a readXSyncedAt() accessor for all 10 cache keys (OFFL-04 regression guard)"
        status: pass
    human_judgment: false
  - id: D4
    description: "One running CadenceApp instance: the offline banner shows exactly once on every one of the 5 bottom-nav tabs (Home/Bands/Tracks/Setlists/Profile) while isOnlineProvider is false, and disappears app-wide once connectivity returns — proving it is RootScaffold's single global signal, not 5 independently-wired per-tab instances"
    requirement: "OFFL-05"
    verification:
      - kind: automated_ui
        ref: "test/offline_cross_tab_test.dart#OFFL-05 / ROADMAP Phase 5 success criterion #3: the offline banner is reachable from, and stays consistent across, every one of the 5 bottom-nav tabs"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-08-17
status: complete
---

# Phase 5 Plan 5: Offline Trust & Connectivity UX — Cross-Cutting Regression Verification Summary

**A deterministic static-content regression guard proving all 10 cached screens render `SyncStatusBadge` and all 19 mutation-control files reference `isOnlineProvider`, plus one real running-app test proving the offline banner is a single consistent app-wide signal across all 5 bottom-nav tabs.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-08-17T15:10:25+03:00 (base commit `881852a`)
- **Completed:** 2026-08-17T15:19:26+03:00
- **Tasks:** 2
- **Files modified:** 2 (both new test files; no `lib/` changes — pure verification over 05-01 through 05-04's already-implemented behavior)

## Accomplishments

- `test/regression/offline_trust_regression_test.dart`: a 4-test static file-content scan proving, in one deterministic re-runnable pass, that the ROADMAP's "verified consistently across profile, bands, tracks, and setlists" claim holds across every one of the 10 cached screens (`SyncStatusBadge`), all 19 mutation-control files (`isOnlineProvider`), `RootScaffold` (`OfflineBanner`), and `cache_service.dart` (all 10 `readXSyncedAt()` accessors) — mirrors Phase 1's OFFL-06 `Directory.listSync()`-based guard's pure-`dart:io` approach
- `test/offline_cross_tab_test.dart`: one real running `CadenceApp` instance, offline, tapped through all 5 bottom-nav tabs, asserting the offline banner text is found exactly once per tab (never missing, never duplicated), then rebuilt online and confirmed the banner is gone everywhere — proves ROADMAP Phase 5 success criterion #3 (banner reachable from, and stays visible across, every tab without re-mounting/flickering)
- Both tests pass on first run since no `lib/` code changed in this plan — the deliverable is the cross-cutting verification itself, over behavior 05-01 through 05-04 already built and each individually tested

## Task Commits

Each task was committed atomically:

1. **Task 1: Static regression guard — every cached screen has the badge, every mutation control has the connectivity gate** - `104b726` (test)
2. **Task 2: Cross-tab offline banner consistency — one running app, all 5 tabs** - `365ae92` (test)

**Plan metadata:** (this commit, once created)

_Note: Task 1 carries `tdd="true"` in the plan frontmatter, but its `<files>` list contains only the test file itself — no `lib/` source file. Per the MVP+TDD gate's own Behavior-Adding-Task predicate (tdd="true" AND `<behavior>` block AND non-test source files in `<files>`), this task is a pure verification task, not a RED/GREEN cycle over new behavior: the assertions describe behavior 05-01 through 05-04 already implemented, so the test passed on its first run with no implementation step in between. See "Deviations from Plan" below._

## Files Created/Modified

- `test/regression/offline_trust_regression_test.dart` - 4 tests: 10-screen `SyncStatusBadge` scan, 19-file `isOnlineProvider` scan, `RootScaffold`/`OfflineBanner` scan, `cache_service.dart` 10-accessor scan
- `test/offline_cross_tab_test.dart` - 1 test: offline banner found exactly once per tab across all 5 tabs, then absent once online

## Decisions Made

- Task 2 drives the offline→online transition through `isOnlineProvider.overrideWithValue(bool)` rather than the plan's literal `connectivityProvider.overrideWith((ref) => Stream.value(status))` — see Deviations below for the empirical reasoning
- Task 2's `MockClient` handler adds `/api/track/list` and `/api/setlist/list` cases beyond `test/widget_test.dart`'s existing 2-endpoint switch, since seeding 1 band (needed so the filter dropdowns render) causes both global tabs to fetch their cross-band list endpoint on first build
- Tab taps in Task 2 are scoped via `find.descendant(of: find.byType(NavigationBar), matching: find.text(label))` rather than a bare `find.text(label)`, since Bands/Tracks/Setlists screens' own `AppBar` titles duplicate their tab's label text once selected

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `connectivityProvider.overrideWith(...)` does not reliably propagate across a second `tester.pumpWidget()` call**
- **Found during:** Task 2 — writing the offline→online transition assertion per the plan's literal `<action>` text
- **Issue:** The plan specifies driving the transition via `connectivityProvider.overrideWith((ref) => Stream.value(ConnectivityStatus.online))` on a rebuilt `ProviderScope`, passed to a second `tester.pumpWidget()` call. Verified via three isolated diagnostic probes (constructed and discarded, not committed) that this override is silently ignored on the second pump — the banner remained visible after the "online" rebuild even though a fresh `ProviderContainer` built directly with the same override correctly resolved `isOnlineProvider` to `true`. This is the same underlying Riverpod 2.6.1 behavior 05-04-SUMMARY.md documented: `ProviderContainer.updateOverrides()`/a re-pumped `ProviderScope` reliably rebuilds listeners only for `overrideWithValue`, not function-based `overrideWith`. `AutoDisposeStreamProvider` (what `connectivityProvider` generates to) has no `overrideWithValue` method at all in this Riverpod version — only `overrideWith` — so there was no direct fix at that provider.
- **Fix:** Switched Task 2's `buildApp()` helper to override `isOnlineProvider` (a plain `AutoDisposeProvider<bool>`, which does support `overrideWithValue`) directly instead of `connectivityProvider`. `isOnlineProvider` is the exact signal `OfflineBanner` and every gated screen actually watches — one layer downstream of `connectivityProvider` — so the test's intent (drive the online/offline signal, confirm banner reachability across all tabs) is preserved unchanged; only the override mechanism differs from the plan's literal instruction.
- **Files modified:** `test/offline_cross_tab_test.dart`
- **Verification:** `flutter test test/offline_cross_tab_test.dart` passes (1/1); full `flutter test` suite (284 tests) passes; `flutter analyze` reports zero issues.
- **Committed in:** `365ae92` (Task 2)

---

**Total deviations:** 1 auto-fixed (bug in the plan's literal override-mechanism instruction, discovered via empirical diagnostic probing)
**Impact on plan:** Necessary to make Task 2's `<verify>` actually pass — no scope creep, the fix only changes which provider the test overrides, not the test's intent or assertions. Diagnostic probe files used to isolate the root cause were not committed.

## Issues Encountered

- Task 1 (`tdd="true"`) had no implementation step to pair with a RED/GREEN cycle — its `<files>` list names only the test file, and every assertion describes behavior 05-01 through 05-04 already built and individually tested. The test passed on its first run; this is expected for a pure cross-cutting verification task, not a TDD violation (see the note under Task Commits).
- Diagnosed a Riverpod 2.6.1-specific gotcha (function-based `overrideWith` not propagating across a second `pumpWidget()`) via three throwaway diagnostic probe tests, none of which were committed — see Deviations above.
- No other issues — `flutter test` (284 tests, full suite) and `flutter analyze` (zero issues) both pass at the end of every task.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- This is the final plan of Phase 5 (offline-trust-connectivity-ux). Both regression guards are in place and passing: any future change that silently drops a staleness badge, a connectivity gate, the global banner, or a `syncedAt` accessor will fail `test/regression/offline_trust_regression_test.dart` loudly, naming the exact file. Any future change that breaks the banner's app-wide consistency across tabs will fail `test/offline_cross_tab_test.dart`.
- Manual/backstop verification items flagged `human_judgment: true` across 05-01 through 05-04 (real airplane-mode device walkthroughs, large-font accessibility text clipping, in-flight-request completion on connectivity drop) remain unautomated in this sandboxed environment — carried forward as the phase's outstanding backstop truths, not blocking for this plan's own completion.

---
*Phase: 05-offline-trust-connectivity-ux*
*Completed: 2026-08-17*

## Self-Check: PASSED

Both created files verified present on disk (`test/regression/offline_trust_regression_test.dart`, `test/offline_cross_tab_test.dart`); both commit hashes (`104b726`, `365ae92`) verified present in `git log --oneline --all`.
