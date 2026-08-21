---
phase: 07-cache-behavior-flip-online-first
plan: 02
subsystem: ui
tags: [riverpod, flutter, offline-cache, connectivity_plus]

# Dependency graph
requires:
  - phase: 07-cache-behavior-flip-online-first (plan 07-01)
    provides: OfflineNoCacheException, OfflineNoCacheView, reworded OfflineBanner copy, the online-first build() template and tab-switch-refetch/in-flight-indicator screen template
provides:
  - "HomepageData.build() and ProfileData.build() rewritten online-first (no _version guard variant of the 07-01 template)"
  - "HomeScreen (tab index 0) and ProfileScreen (tab index 4) tab-switch-refetch + AppBar in-flight indicator + OfflineNoCacheView wiring"
  - "SyncStatusBadge removed from 2 more of its 10 call-sites (Home, Profile) — 4 of 10 done after 07-01+07-02"
affects: [07-05]

# Actuals (#2632)
actuals:
  tokens: 13105
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "No-_version-guard variant of the 07-01 online-first build() template — HomepageData/ProfileData have no local-mutation methods to race against, so the online-first shape is identical minus the _version capture/compare step"

key-files:
  created: []
  modified:
    - lib/providers/homepage_provider.dart
    - lib/features/home/home_screen.dart
    - lib/providers/profile_provider.dart
    - lib/features/profile/profile_screen.dart
    - test/providers/homepage_provider_test.dart
    - test/features/home/home_screen_test.dart
    - test/providers/profile_provider_test.dart
    - test/features/profile/profile_screen_test.dart

key-decisions:
  - "Applied 07-01's online-first build() template verbatim to Homepage/Profile, omitting the _version guard entirely (not just leaving it unused) — neither provider has local-mutation methods (setBands/renameBand-equivalents) to race against a slow background fetch, so there's nothing for a version counter to protect"
  - "wrap()/buildContainer() test helpers in all 4 test files now default isOnlineProvider to true, matching 07-01's bands_screen_test.dart fix for the same reason: online-first build() reads isOnlineProvider directly, and an unmocked provider resolves to the fail-safe false default, silently exercising the offline branch in every pre-existing test"

requirements-completed: [OFFL-07, OFFL-08]

coverage:
  - id: D1
    description: "HomepageData.build() is online-first: fetches fresh when online (ignoring a populated cache on the happy path), falls back to cache silently on a failed online fetch, and throws OfflineNoCacheException when offline with nothing cached"
    requirement: "OFFL-07"
    verification:
      - kind: unit
        ref: "test/providers/homepage_provider_test.dart#online + no cache / online + stale cache present / online + fetch throws + cache present / online + fetch throws + no cache / offline + cache present / offline + no cache"
        status: pass
    human_judgment: false
  - id: D2
    description: "ProfileData.build() mirrors the same online-first contract as HomepageData"
    requirement: "OFFL-07"
    verification:
      - kind: unit
        ref: "test/providers/profile_provider_test.dart#online + no cache / online + stale cache present / online + fetch throws + cache present / online + fetch throws + no cache / offline + cache present / offline + no cache"
        status: pass
    human_judgment: false
  - id: D3
    description: "HomeScreen refetches on every re-selection of the Home tab (D-01), shows a subtle AppBar LinearProgressIndicator only when refreshing with data present (D-08/D-09), and renders OfflineNoCacheView (no Retry) on OfflineNoCacheException instead of SyncStatusBadge"
    requirement: "OFFL-08"
    verification:
      - kind: automated_ui
        ref: "test/features/home/home_screen_test.dart#switching to the Home tab a second time triggers a second GET /api/homepage call (D-01 tab-switch refetch) / AppBar's LinearProgressIndicator shows only while refreshing with data already present... / offline with no cache shows OfflineNoCacheView, with no Retry button (D-06)"
        status: pass
    human_judgment: false
  - id: D4
    description: "ProfileScreen refetches on every re-selection of the Profile tab (D-01), shows the same AppBar in-flight indicator, and renders OfflineNoCacheView on OfflineNoCacheException instead of SyncStatusBadge"
    requirement: "OFFL-08"
    verification:
      - kind: automated_ui
        ref: "test/features/profile/profile_screen_test.dart#switching to the Profile tab a second time triggers a second GET /api/me call (D-01 tab-switch refetch) / AppBar's LinearProgressIndicator shows only while refreshing with data already present... / offline with no cache shows OfflineNoCacheView, with no Retry button (D-06)"
        status: pass
    human_judgment: false

duration: ~15min
completed: 2026-08-21
status: complete
---

# Phase 07 Plan 02: Online-First Home + Profile Tabs Summary

**Home and Profile tabs flipped from cache-first to online-first by applying 07-01's exact template minus the `_version` guard — neither provider has local-mutation methods to race**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-08-21
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- `HomepageData.build()` and `ProfileData.build()` are online-first: online always fetches fresh (ignoring a populated cache on the happy path), a failed online fetch falls back to cache silently (D-03), and offline-with-nothing-cached throws the shared `OfflineNoCacheException` (D-06) reused unchanged from 07-01
- `HomeScreen` refetches on every re-selection of the Home tab (tab index 0) via a `selectedTabIndexProvider` listener (D-01), shows a subtle `AppBar` `LinearProgressIndicator` only while refreshing with data already present (D-08), and keeps the existing cold-start full-screen spinner untouched (D-09)
- `ProfileScreen` gets the identical treatment for the Profile tab (tab index 4)
- `SyncStatusBadge` removed from both Home and Profile screens (2 more of its 10 total call-sites; 4 of 10 removed after 07-01+07-02)

## Task Commits

Each task was committed atomically:

1. **Task 1: Home tab — HomepageData + HomeScreen online-first** - `c25e50a` (feat)
2. **Task 2: Profile tab — ProfileData + ProfileScreen online-first** - `fd6671b` (feat)

_Note: both tasks carried `tdd="true"`; tests and implementation were written together per task rather than as separate RED/GREEN commits, matching this plan's `type="execute"` (not `type="tdd"`) frontmatter — no plan-level RED/GREEN gate applies here._

## Files Created/Modified

- `lib/providers/homepage_provider.dart` - `HomepageData.build()` rewritten online-first; dead `_refresh()` private method removed
- `lib/features/home/home_screen.dart` - Tab-switch listener, AppBar progress indicator, `OfflineNoCacheView` error branch, `SyncStatusBadge` removed
- `lib/providers/profile_provider.dart` - `ProfileData.build()` rewritten online-first; dead `_refresh()` private method removed
- `lib/features/profile/profile_screen.dart` - Tab-switch listener, AppBar progress indicator, `OfflineNoCacheView` error branch, `SyncStatusBadge` removed
- `test/providers/homepage_provider_test.dart` - Rewritten for the 6 online-first provider cases + preserved refresh-dedup/syncedAt tests
- `test/features/home/home_screen_test.dart` - Offline-no-cache view test, tab-switch-refetch test, AppBar-indicator test replace the old `SyncStatusBadge` test; single-`pump()` assertions switched to `pumpAndSettle()` where the happy path now requires a genuine network round-trip
- `test/providers/profile_provider_test.dart` - Same rewrite pattern applied to `ProfileData`
- `test/features/profile/profile_screen_test.dart` - Same test-suite rewrite pattern applied to `ProfileScreen`; the old "cached data present renders immediately with no spinner" and "background refresh silently replaces displayed data with no spinner" tests were replaced (that scenario — instant cache display, then a delayed silent background swap — no longer exists under online-first, where the happy path always fetches first)

## Decisions Made

- **No `_version` guard, by design, not by oversight:** 07-01's `bands_provider.dart` template includes a `_version` monotonic counter guarding `_doRefresh()` against a slow background fetch clobbering a local mutation. `HomepageData`/`ProfileData` have no local-mutation methods (`bands_provider.dart`'s `setBands()`/`renameBand()` equivalents don't exist here — nothing to protect). Per the plan's own `<action>` block ("this provider has no `_version` field — nothing to capture/compare"), the guard was omitted entirely rather than added as dead code, matching 07-RESEARCH.md's Pattern 1 note that homepage/profile are "read-mostly."
- **`isOnlineProvider` default-true fix applied to all 4 test files:** mirroring 07-01's `bands_screen_test.dart` fix, every `wrap()`/`buildContainer()` helper here now overrides `isOnlineProvider` to `true` by default. Without this, `HomepageData`/`ProfileData.build()`'s new `ref.watch(isOnlineProvider)` call resolves to the fail-safe `false` default (no platform-channel mock in the test sandbox), silently exercising the offline branch in every pre-existing test that didn't already override it.

## Deviations from Plan

### Auto-fixed Issues

None — no Rule 1/2/3 auto-fixes were required; the plan's `<action>` blocks were followed as specified for both tasks.

**Total deviations:** 0.
**Impact on plan:** None — plan executed as written.

## Issues Encountered

None specific to this plan's own files. See `deferred-items.md` (in this phase directory) for 3 pre-existing full-suite `flutter test` failures discovered while running the complete regression suite as a sanity check — none touch this plan's files (confirmed via `git diff <base> HEAD --stat`, which shows only the 8 files listed above), and all are either intentionally deferred to 07-05 (the `SyncStatusBadge` regression-guard rewrite, by design per 07-05-PLAN.md) or pre-existing gaps from 07-01's Bands-tab rollout, out of this plan's scope per the Scope Boundary rule. This plan's own `<verification>` block (the 4 homepage/profile test files + full-tree `flutter analyze`) is fully green.

## Next Phase Readiness

- The online-first pattern is now proven against 2 of 10 providers with no `_version` guard (the simplest variant), in addition to 07-01's 2 providers with the guard — plans 07-03 (Tracks) and 07-04 (Setlists) can mirror either template as appropriate.
- `SyncStatusBadge` still has 6 remaining call-sites (Tracks×2, Setlists×2, Track/Setlist detail) — final removal of the widget itself remains plan 07-05's job (wave 3, after all screen rewrites land).
- No blockers for 07-03/07-04; 07-05 depends on all of 07-01 through 07-04 landing first, which this plan (07-02) now satisfies its share of.

---
*Phase: 07-cache-behavior-flip-online-first*
*Completed: 2026-08-21*

## Self-Check: PASSED

All 8 files listed under "Files Created/Modified" verified present on disk. Both task commit hashes (`c25e50a`, `fd6671b`) verified present in `git log`.
