---
phase: 07-cache-behavior-flip-online-first
plan: 04
subsystem: ui
tags: [riverpod, flutter, offline-cache, connectivity_plus, hive, setlists]

# Dependency graph
requires:
  - phase: 07-cache-behavior-flip-online-first
    provides: "OfflineNoCacheException, OfflineNoCacheView, and the online-first provider/screen template established by 07-01's Bands tracer"
provides:
  - "SetlistListData/SetlistDetailData/UserSetlistsListData online-first build() (D-01/D-03/D-06), mirroring 07-01's BandsListData/BandDetailData template one entity level down"
  - "SetlistsScreen tab-switch-refetch + AppBar in-flight indicator (D-01/D-08/D-09), tab index 3"
  - "SetlistListScreen/SetlistDetailScreen pushed-route OfflineNoCacheView wiring with no tab-switch/indicator wiring (D-02)"
affects: [07-05]

# Actuals (#2632)
actuals:
  tokens: 22673
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Online-first provider build() applied to all three setlist providers in one file: watch isOnlineProvider; online tries _fetchAndCache(...) first (ignoring a populated cache), catches and falls back to cache silently (D-03), rethrows only if no cache; offline reads cache or throws OfflineNoCacheException (D-06)"
    - "Tab-switch refetch on the one cross-band tab screen (SetlistsScreen, tab index 3): ref.listen<int>(selectedTabIndexProvider, ...) invalidating userSetlistsListDataProvider, registered before the bands.isEmpty early-return"
    - "Pushed-route screens (SetlistListScreen/SetlistDetailScreen) get badge removal + OfflineNoCacheView only — no tab-switch listener, no AppBar.bottom indicator (D-02), confirmed by their family/autoDispose providers already rebuilding fresh on every Navigator.push"

key-files:
  created: []
  modified:
    - lib/providers/setlists_provider.dart
    - lib/features/setlists/setlists_screen.dart
    - lib/features/setlists/setlist_list_screen.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - test/providers/setlists_provider_test.dart
    - test/features/setlists/setlists_screen_test.dart
    - test/features/setlists/setlist_list_screen_test.dart
    - test/features/setlists/setlist_detail_screen_test.dart

key-decisions:
  - "SetlistDetailScreen's updateFields()/reorderTracks() local-mutation methods (beyond the usual removeFromList/setBands shape) were left completely untouched — only build() changed, per the plan's explicit scope boundary"
  - "UserSetlistsListData's build() keeps `final bandIdFilter = ref.watch(selectedSetlistBandIdFilterProvider);` as its first line unchanged, then applies the online-first branch using bandIdFilter as the fetch/cache key — identical shape to UserTracksListData's filter-provider pattern"
  - "Detail screens get no AppBar in-flight indicator, matching 07-01's BandDetailScreen precedent: their autoDispose family providers always start with hasValue == false on mount, so isLoading && hasValue never fires in practice"

requirements-completed: [OFFL-07, OFFL-08]

coverage:
  - id: D1
    description: "SetlistListData.build(bandId) is online-first: fetches fresh when online (ignoring a populated cache), falls back to cache silently on a failed online fetch, and throws OfflineNoCacheException when offline with nothing cached"
    requirement: "OFFL-07"
    verification:
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#SetlistListData online + no cache / online + stale cache present / online + fetch throws + cache present / online + fetch throws + no cache / offline + cache present / offline + no cache"
        status: pass
    human_judgment: false
  - id: D2
    description: "SetlistDetailData.build(bandId, setlistId) mirrors the same online-first contract, with _version guard, updateFields(), and reorderTracks() all preserved unchanged"
    requirement: "OFFL-07"
    verification:
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#SetlistDetailData online + no cache / online + stale cache present / online + fetch throws + cache present / online + fetch throws + no cache / offline + cache present / offline + no cache / reorderTracks() reorders.../ reorderTracks() is a local patch only"
        status: pass
    human_judgment: false
  - id: D3
    description: "UserSetlistsListData.build() (cross-band, filterable) is online-first with the same 6-case contract, preserving the selectedSetlistBandIdFilterProvider-driven cache/fetch key"
    requirement: "OFFL-07"
    verification:
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#UserSetlistsListData online + no cache / online + stale cache present / online + fetch throws + cache present / online + fetch throws + no cache / offline + cache present / offline + no cache / changing selectedSetlistBandIdFilterProvider..."
        status: pass
    human_judgment: false
  - id: D4
    description: "SetlistsScreen refetches on every re-selection of the Setlists tab (D-01, index 3), shows a subtle AppBar LinearProgressIndicator only when refreshing with data present (D-08), and renders OfflineNoCacheView (no Retry) on OfflineNoCacheException instead of SyncStatusBadge"
    requirement: "OFFL-08"
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlists_screen_test.dart#switching to the Setlists tab a second time triggers a second listUserSetlists() network call (D-01 tab-switch refetch) / AppBar's LinearProgressIndicator shows only while refreshing with data already present, not once settled (D-08) / offline with no cache shows OfflineNoCacheView, with no Retry button (D-06)"
        status: pass
    human_judgment: false
  - id: D5
    description: "SetlistListScreen and SetlistDetailScreen render OfflineNoCacheView on OfflineNoCacheException, render cached data offline when cache exists, no longer render SyncStatusBadge, and SetlistDetailScreen's reorder/remove-track/add-tracks flows are unaffected"
    requirement: "OFFL-08"
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_list_screen_test.dart#offline with no cache shows OfflineNoCacheView.../ offline with cache present renders the cached setlist data (D-06); test/features/setlists/setlist_detail_screen_test.dart#offline with no cache shows OfflineNoCacheView.../ with isOnlineProvider false, the Edit IconButton is disabled.../ tapping a row's remove icon calls removeSetlistTrack.../ invoking the ReorderableListView's onReorderItem callback directly submits reorderSetlistTracks..."
        status: pass
    human_judgment: false

duration: ~35min
completed: 2026-08-21
status: complete
---

# Phase 07 Plan 04: Online-First Setlists (Tab + Pushed Routes) Summary

**All three setlist providers (SetlistListData, SetlistDetailData, UserSetlistsListData) and their three screens (SetlistsScreen tab, SetlistListScreen, SetlistDetailScreen) flipped from cache-first to online-first, mirroring 07-01's Bands tracer pattern one entity level down**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-08-21
- **Tasks:** 2
- **Files modified:** 8 (0 created, 8 modified)

## Accomplishments

- `SetlistListData.build(bandId)`, `SetlistDetailData.build(bandId, setlistId)`, and `UserSetlistsListData.build()` are all online-first: online always fetches fresh (ignoring a populated cache on the happy path), a failed online fetch falls back to cache silently (D-03), and offline-with-nothing-cached throws the shared `OfflineNoCacheException` (D-06)
- All three now-dead `_refresh()` private methods removed; `_version` guards, `refresh()`/`_doRefresh()` dedup, and every local-mutation method (`removeFromList`, `updateFields`, `reorderTracks`) preserved completely unchanged
- `SetlistsScreen` (cross-band tab, index 3) refetches on every re-selection of the Setlists tab via a `selectedTabIndexProvider` listener (D-01), shows a subtle `AppBar` `LinearProgressIndicator` only while refreshing with data already present (D-08), and keeps the existing cold-start full-screen spinner untouched (D-09)
- `SetlistListScreen`/`SetlistDetailScreen` (pushed routes, family providers) get the same offline-no-cache treatment with no new tab-switch/in-flight-indicator wiring, per D-02's confirmation that their `autoDispose` family providers already rebuild fresh on every `Navigator.push`
- `SyncStatusBadge` removed from all 3 setlist screens (the final 2 of the 8 remaining call-sites from 07-01's tally — Home/Profile/Track/2 setlist screens land in sibling 07-02/07-03 plans; `sync_status_badge.dart` itself is deleted in the wave-3 cleanup plan 07-05)
- `SetlistDetailScreen`'s edit-mode/reorder/remove-track/add-tracks logic verified unaffected — all pre-existing behavioral tests for those flows still pass unmodified in intent

## Task Commits

Each task was committed atomically:

1. **Task 1: setlists_provider.dart — SetlistListData, SetlistDetailData, UserSetlistsListData online-first** - `7bb2ca2` (feat)
2. **Task 2: Setlist screens — SetlistsScreen (tab), SetlistListScreen + SetlistDetailScreen (pushed routes)** - `08d841f` (feat)

_Note: both tasks carried `tdd="true"`; tests and implementation were written together per task rather than as separate RED/GREEN commits, matching this plan's `type="execute"` (not `type="tdd"`) frontmatter — no plan-level RED/GREEN gate applies here._

## Files Created/Modified

- `lib/providers/setlists_provider.dart` - `SetlistListData.build()`, `SetlistDetailData.build()`, and `UserSetlistsListData.build()` all rewritten online-first; 3 dead `_refresh()` methods removed
- `lib/features/setlists/setlists_screen.dart` - Tab-switch listener (tab index 3), AppBar progress indicator, `OfflineNoCacheView` error branch, `SyncStatusBadge` removed; `_buildSetlistsBody` simplified to drop the `Column([SyncStatusBadge, Expanded])` wrapper
- `lib/features/setlists/setlist_list_screen.dart` - `OfflineNoCacheView` error branch, `SyncStatusBadge` removed, no tab-switch/indicator wiring (D-02)
- `lib/features/setlists/setlist_detail_screen.dart` - Same badge-removal + `OfflineNoCacheView` edits inside `_SetlistDetailScreenState.build()`; edit-mode/reorder/remove-track/add-tracks methods untouched
- `test/providers/setlists_provider_test.dart` - Rewritten for the 6 online-first provider cases × 3 providers, preserving every `_version`-guard/dedup/local-mutation/`reorderTracks` test
- `test/features/setlists/setlists_screen_test.dart` - Offline-no-cache view test, tab-switch-refetch test, AppBar-indicator test replace the old `SyncStatusBadge` presence test; `wrap()` gained the default-true `isOnlineProvider` override
- `test/features/setlists/setlist_list_screen_test.dart` - Added offline-no-cache and offline-with-cache tests; the "no cache and network failure" test now explicitly forces `isOnline: true` (it exercises the online-fetch-fails path, not the offline-no-cache path)
- `test/features/setlists/setlist_detail_screen_test.dart` - Removed `SyncStatusBadge` import/assertion; the three pre-existing `isOnline: false` tests (Edit button, edit-mode entry, Delete tile) now seed cache first since online-first throws `OfflineNoCacheException` on offline-with-no-cache instead of silently fetching regardless of connectivity like the old cache-first `build()` did; added a new offline-no-cache `OfflineNoCacheView` test

## Decisions Made

- **`SetlistDetailScreen`'s `updateFields()`/`reorderTracks()` local-mutation methods left untouched:** the plan explicitly scoped Task 1 to `build()` changes only for this provider, since it uniquely has two local-mutation methods beyond the usual one — both stayed byte-for-byte identical apart from surrounding context.
- **No AppBar in-flight indicator on `SetlistListScreen`/`SetlistDetailScreen`:** matches 07-01's `BandDetailScreen` precedent — D-02 confirms these `autoDispose` family providers always rebuild with `hasValue == false` on mount, so `isLoading && hasValue` never realistically fires; adding the indicator would have been dead/no-op code.
- **`setlist_list_screen_test.dart`'s "no cache and network failure" test updated to force `isOnline: true`:** this test's intent is to exercise the online-fetch-throws-with-no-cache -> `AsyncError` path (D-03's negative case), which requires explicit online state now that offline-with-no-cache has its own distinct `OfflineNoCacheException` branch (D-06) that would otherwise short-circuit the test before ever reaching the network mock.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed three `setlist_detail_screen_test.dart` tests that would have broken under online-first semantics**
- **Found during:** Task 2, while porting `setlist_detail_screen_test.dart`'s existing `isOnline: false` tests
- **Issue:** Three pre-existing tests (`Edit IconButton disabled/enabled`, `_editMode initially false`, `Delete ListTile disabled`) passed `isOnline: false` with **no cache seeded**, relying on the old cache-first `build()` ignoring `isOnlineProvider` entirely and fetching from the network regardless of connectivity state. Under online-first, offline-with-no-cache now throws `OfflineNoCacheException` instead of fetching, so these tests would have rendered `OfflineNoCacheView` instead of the setlist content they assert against.
- **Fix:** Seeded `cacheService.writeSetlistDetail(...)` with matching data before each of the three affected `pumpWidget()` calls, so the offline branch takes the "offline + cache present" path instead of "offline + no cache."
- **Files modified:** `test/features/setlists/setlist_detail_screen_test.dart`
- **Verification:** All three tests pass; `flutter test test/features/setlists/setlist_detail_screen_test.dart` green.
- **Committed in:** `08d841f` (Task 2 commit)

**2. [Rule 1 - Bug] Fixed `setlist_list_screen_test.dart`'s "no cache and network failure" test**
- **Found during:** Task 2 plan-level verification run
- **Issue:** This test relied on the (pre-change) default connectivity resolution in the test sandbox, which resolves `isOnlineProvider` to `false` (fail-safe offline, no platform-channel mock). Under the old cache-first provider this didn't matter (connectivity was never checked); under online-first, offline-with-no-cache now throws `OfflineNoCacheException` instead of surfacing the intended `ApiException` -> `AsyncError` -> "Failed to load setlists" + Retry state the test asserts against.
- **Fix:** Added an explicit `isOnline: true` override to this test's `wrap()` call, since its intent is specifically the online-fetch-fails path (D-03's negative branch), not the offline-no-cache path (D-06).
- **Files modified:** `test/features/setlists/setlist_list_screen_test.dart`
- **Verification:** Test passes; full plan verification suite green (67/67 tests).
- **Committed in:** `08d841f` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (Rule 1 bugs, both pre-existing test assumptions invalidated by the online-first behavior change, not new code defects).
**Impact on plan:** No scope creep — both fixes were necessary to keep pre-existing test intent intact under the new online-first contract; no production code changed as a result.

## Issues Encountered

- **`setlists_screen_test.dart`'s AppBar in-flight indicator test needed a network-call-count gate rather than a raw `Completer`-per-fetch pattern:** unlike `BandsScreen` (which only watches one online-first provider), `SetlistsScreen` also watches `bandsListDataProvider` for its band-filter dropdown. Gating the *first* setlists fetch (as 07-01's `bands_screen_test.dart` does for its own single provider) would have raced against `bandsListDataProvider`'s independent, ungated resolution and made the cold-start assertion unreliable. The test was restructured to settle both providers first via `pumpAndSettle()`, then use `container.refresh(userSetlistsListDataProvider)` + a call-count-based gate (`setlistsCallCount > 1`) to deterministically observe only the D-08 "refreshing with data present" state, skipping the racier D-09 cold-start assertion that 07-01's tracer test covers once at the pattern-establishing level.
- **Three `setlist_detail_screen_test.dart` offline tests silently relied on cache-first's connectivity-blind fetch:** see Deviations above — these were pre-existing tests whose passing depended on an implementation detail (offline state being irrelevant to the old provider) that online-first correctly changes. Fixing them by seeding cache is the intended migration path per the plan's `<action>` block, not a workaround.

## Next Phase Readiness

- All three setlist providers and all three setlist screens are online-first with full test coverage (67 tests: 29 provider + 38 screen), matching 07-01's tracer pattern exactly.
- `SyncStatusBadge` now has 0 remaining call-sites in `lib/features/setlists/` — combined with 07-01's Bands removal, this plan closes out the Setlists half of the 10-call-site tally from `07-RESEARCH.md`; Home/Profile/Track call-sites belong to sibling plans 07-02/07-03.
- No blockers for 07-05 (the final wave-3 cleanup plan that deletes `sync_status_badge.dart` itself once all screen rewrites across 07-01–07-04 have landed).

---
*Phase: 07-cache-behavior-flip-online-first*
*Completed: 2026-08-21*

## Self-Check: PASSED

All 8 files listed under "Files Created/Modified" verified present on disk. Both task commit hashes (`7bb2ca2`, `08d841f`) verified present in `git log`.
