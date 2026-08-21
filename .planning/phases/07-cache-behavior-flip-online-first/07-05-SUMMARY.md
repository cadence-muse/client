---
phase: 07-cache-behavior-flip-online-first
plan: 05
subsystem: testing
tags: [flutter, riverpod, offline-cache, regression-guard, dead-code-removal]

# Dependency graph
requires:
  - phase: 07-cache-behavior-flip-online-first
    provides: "SyncStatusBadge removed from all 10 screen call sites and OfflineNoCacheException wired in its place (07-01 through 07-04)"
provides:
  - "SyncStatusBadge widget and its dedicated test fully deleted from the repository (OFFL-08)"
  - "test/regression/offline_trust_regression_test.dart rewritten to assert the phase's actual final state (no badge, universal OfflineNoCacheException wiring) instead of the retired Phase-5 badge-presence claim"
affects: []

# Actuals (#2632)
actuals:
  tokens: 2576
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Aggregate cross-cutting regression guard rewritten in place rather than deleted-and-recreated: same file-list constant (renamed screensWithBadge -> cachedScreens), same test-file structure, only the per-file assertion inverted (absence-of-string + presence-of-string instead of a single presence check)"

key-files:
  created: []
  modified:
    - test/regression/offline_trust_regression_test.dart
    - .planning/phases/07-cache-behavior-flip-online-first/deferred-items.md

key-decisions:
  - "Task 1's literal <verify> command (grep -rn \"SyncStatusBadge\" lib/ test/ returning zero matches) is structurally impossible to satisfy after Task 2, because a test that asserts a string's absence must contain that string as a literal to check against (contents.contains('SyncStatusBadge')) plus explanatory doc comments referencing the retired class by name. Resolved by scoping the zero-matches check to exclude offline_trust_regression_test.dart itself (grep --exclude=offline_trust_regression_test.dart lib/ test/ returns zero matches), which is the substantive claim the plan's OFFL-08 truth actually requires -- no application or other test code references the deleted class. The regression test's own self-referential mentions (doc comments + the one check-string literal) are the unavoidable byproduct of writing an absence-assertion test, not a violation of OFFL-08."

requirements-completed: [OFFL-07, OFFL-08]

coverage:
  - id: D1
    description: "SyncStatusBadge widget (lib/widgets/sync_status_badge.dart) and its dedicated unit test (test/widgets/sync_status_badge_test.dart) are fully deleted from the repository, with zero remaining references in any application or test file"
    requirement: "OFFL-08"
    verification:
      - kind: unit
        ref: "test ! -f lib/widgets/sync_status_badge.dart && test ! -f test/widgets/sync_status_badge_test.dart"
        status: pass
      - kind: other
        ref: "grep -rl SyncStatusBadge lib/features/ (precondition check, zero matches before deletion)"
        status: pass
      - kind: other
        ref: "grep -rn SyncStatusBadge lib/ test/ --exclude=offline_trust_regression_test.dart (zero matches after deletion)"
        status: pass
    human_judgment: false
  - id: D2
    description: "test/regression/offline_trust_regression_test.dart's first test asserts the phase's actual final state -- every one of the 10 cached screens has no SyncStatusBadge reference AND wires OfflineNoCacheException -- replacing the retired Phase-5 'every cached screen renders SyncStatusBadge' claim. The other 3 tests in the file (connectivity gate, readSyncedAt accessors, RootScaffold/OfflineBanner) are unchanged."
    requirement: "OFFL-07"
    verification:
      - kind: unit
        ref: "flutter test test/regression/offline_trust_regression_test.dart (all 4 tests pass)"
        status: pass
    human_judgment: false
  - id: D3
    description: "flutter analyze reports zero warnings/errors across the full lib/ and test/ trees after this plan's deletions and rewrite"
    requirement: "OFFL-08"
    verification:
      - kind: other
        ref: "flutter analyze (repo-wide, both after Task 1 and after Task 2)"
        status: pass
    human_judgment: false

duration: ~15min
completed: 2026-08-21
status: complete
---

# Phase 07 Plan 05: Close Out Phase 7 — Delete SyncStatusBadge, Rewrite Regression Guard Summary

**Deleted the now-fully-unused `SyncStatusBadge` widget and its test, and rewrote the cross-cutting `offline_trust_regression_test.dart` guard so it asserts the phase's real final state (badge gone, `OfflineNoCacheException` wired everywhere) instead of the retired Phase-5 badge-presence claim — closing out Phase 7's OFFL-07/OFFL-08 requirements.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-08-21
- **Tasks:** 2
- **Files modified:** 4 (0 created, 2 deleted, 2 modified)

## Accomplishments

- Confirmed zero remaining `SyncStatusBadge` references in `lib/features/` (precondition check) before deleting `lib/widgets/sync_status_badge.dart` and its dedicated unit test `test/widgets/sync_status_badge_test.dart` — the widget's own test had nothing left to test once the widget itself was gone
- `flutter analyze` stayed clean (zero warnings/errors) across the full `lib/`/`test/` tree after the deletion
- Rewrote `offline_trust_regression_test.dart`'s first test (renamed `screensWithBadge` → `cachedScreens`) to assert, per file across the same 10 cached screens: absence of `'SyncStatusBadge'` AND presence of `'OfflineNoCacheException'` — proving both OFFL-08's badge removal and OFFL-07's universal offline-no-cache wiring hold simultaneously across every screen
- Left the other 3 tests in the file (`mutationControlsWithConnectivityGate`, `readSyncedAtMethodNames`, `RootScaffold`/`OfflineBanner`) byte-for-byte unchanged — confirmed still true and unaffected by this phase
- All 4 tests in the rewritten file pass; full `flutter test` run afterward shows 368 total tests with only the 3 pre-existing, out-of-scope failures already logged in `deferred-items.md` (0 new failures introduced)

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete SyncStatusBadge and confirm zero dangling references** - `714105a` (feat)
2. **Task 2: Rewrite the OFFL-07/OFFL-08 aggregate regression guard** - `8a4e41f` (feat)

## Files Created/Modified

- `lib/widgets/sync_status_badge.dart` - Deleted (widget fully unused after 07-01 through 07-04)
- `test/widgets/sync_status_badge_test.dart` - Deleted (dedicated unit test for the deleted widget)
- `test/regression/offline_trust_regression_test.dart` - First test rewritten to assert OFFL-07/OFFL-08's aggregate final-state claim instead of the retired OFFL-04 badge-presence claim; other 3 tests unchanged
- `.planning/phases/07-cache-behavior-flip-online-first/deferred-items.md` - Logged resolution of the previously-expected-red regression test and reconfirmed the 2 remaining pre-existing, out-of-scope failures

## Decisions Made

- **Scoped the phase-level `grep -rn "SyncStatusBadge"` zero-matches claim to exclude `offline_trust_regression_test.dart` itself:** the plan's Task 1 `<verify>`/`<acceptance_criteria>` literally requires a repo-wide zero-match grep "including the regression test — updated in Task 2," but a test that asserts a string's absence must contain that string as a literal to check against, plus explanatory doc comments naming the retired class. This is a structural impossibility in the plan's literal wording, not a code defect. The substantive OFFL-08 claim — no *application* or *other test* code references `SyncStatusBadge` — is fully verified via `grep -rn "SyncStatusBadge" lib/ test/ --exclude=offline_trust_regression_test.dart`, which returns zero matches. See key-decisions in frontmatter for full detail.

## Deviations from Plan

None (Rule 1-3 auto-fixes) — plan executed as written for both tasks' `<action>` content. The one documented decision above is a plan-wording clarification (the literal `<verify>` command in Task 1 cannot be satisfied after Task 2 by construction), not a deviation from the plan's intent, which the SUMMARY documents transparently per the "Decisions Made" section rather than as an auto-fixed bug.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 7 (Cache Behavior Flip — Online-First) is complete: all 5 plans (07-01 through 07-05) executed and merged. OFFL-07 (online-first fetch behavior) and OFFL-08 (offline banner + badge removal) both hold across all 10 cached screens, verified by the rewritten aggregate regression guard.
- `SyncStatusBadge` has zero references anywhere in the repository outside `offline_trust_regression_test.dart`'s own self-referential doc comments and check-string literal (unavoidable for an absence-assertion test).
- 3 pre-existing test failures remain, all out of scope for this plan and already logged in `deferred-items.md`: `band_detail_screen_test.dart` (2 tests, 07-01's Bands offline-disabled-tiles wiring) and `widget_test.dart`'s "bottom navigation switches between tabs" (missing `isOnlineProvider` override in a full-`CadenceApp` test, also from 07-01's online-first rollout). None block Phase 7 closure; they are candidates for a future gap-closure plan if picked up.
- Ready for the orchestrator to update STATE.md/ROADMAP.md and proceed to the next phase.

---
*Phase: 07-cache-behavior-flip-online-first*
*Completed: 2026-08-21*

## Self-Check: PASSED

Both deleted files (`lib/widgets/sync_status_badge.dart`, `test/widgets/sync_status_badge_test.dart`) confirmed absent via `test ! -f`. Both task commit hashes (`714105a`, `8a4e41f`) confirmed present in `git log --oneline -5`. Rewritten regression test file (`test/regression/offline_trust_regression_test.dart`) confirmed present and passing (4/4 tests). Full `flutter test` run shows 368 total, 3 pre-existing/out-of-scope failures, 0 new failures.
