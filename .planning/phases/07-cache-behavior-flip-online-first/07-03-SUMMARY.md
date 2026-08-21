---
phase: 07-cache-behavior-flip-online-first
plan: 03
subsystem: ui
tags: [riverpod, flutter, offline-cache, connectivity_plus, hive, tracks]

# Dependency graph
requires:
  - phase: 07-cache-behavior-flip-online-first
    provides: "07-01's online-first provider `build()` shape, tab-switch-refetch listener pattern, AppBar in-flight indicator pattern, shared `OfflineNoCacheException`/`OfflineNoCacheView` artifacts"
provides:
  - "TrackListData/TrackDetailData/UserTracksListData (lib/providers/tracks_provider.dart) rewritten online-first: online always fetches fresh, D-03 silent cache fallback on fetch failure, D-06 OfflineNoCacheException when offline with nothing cached"
  - "TracksScreen (cross-band tab, index 2) wired with D-01 tab-switch-refetch, D-08/D-09 AppBar in-flight indicator, D-06 OfflineNoCacheView error branch"
  - "TrackListScreen/TrackDetailScreen (pushed routes) wired with D-06 OfflineNoCacheView error branch only, per D-02 no new tab-switch/indicator wiring needed"
  - "SyncStatusBadge removed from all 3 track screens (3 of the phase's 10 remaining call-sites)"
affects: [07-05]

# Actuals (#2632)
actuals:
  tokens: 23406
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Applied 07-01's online-first provider build() shape verbatim to all 3 remaining track providers, including the two family providers (TrackListData(bandId), TrackDetailData(bandId, trackId)) and the one non-family, filter-watching provider (UserTracksListData watches selectedBandIdFilterProvider first, then applies the same online-first branch)"
    - "TracksScreen lifts its data provider's ref.watch() from a nested _buildTracksBody helper up to the top-level build() so the AppBar's in-flight indicator can read isLoading/hasValue — the tab-switch listener is registered before the screen's pre-existing bands.isEmpty early return so a tab-switch always retriggers a fetch regardless of that state"

key-files:
  created: []
  modified:
    - lib/providers/tracks_provider.dart
    - lib/features/songs/tracks_screen.dart
    - lib/features/tracks/track_list_screen.dart
    - lib/features/tracks/track_detail_screen.dart
    - test/providers/tracks_provider_test.dart
    - test/features/tracks/tracks_screen_test.dart
    - test/features/tracks/track_list_screen_test.dart
    - test/features/tracks/track_detail_screen_test.dart
    - test/features/setlists/add_setlist_tracks_dialog_test.dart

key-decisions:
  - "TracksScreen's zero-bands early return is unrelated to this refactor and stays as-is, but the D-01 tab-switch listener is registered before it so a tab-switch always attempts a refetch even while bands.isEmpty is true (matches the plan's explicit instruction)"
  - "UserTracksListData's pre-existing final int _version = 0 field (never mutated — no local-mutation method exists on this provider) is preserved as-is per the plan's explicit instruction, even though the version-guard comparison is trivially always-true"
  - "TrackListScreen/TrackDetailScreen get no AppBar.bottom in-flight indicator and no tab-switch listener, mirroring 07-01's BandDetailScreen precedent exactly (D-02: autoDispose family providers already rebuild fresh on every Navigator.push)"

requirements-completed: [OFFL-07, OFFL-08]

coverage:
  - id: D1
    description: "TrackListData.build(bandId) and TrackDetailData.build(bandId, trackId) are online-first: fetch fresh when online (ignoring a populated cache on the happy path), fall back to cache silently on a failed online fetch (D-03), and throw OfflineNoCacheException when offline with nothing cached (D-06); _version guards, dedup, and local-mutation methods (removeFromList, updateFields) preserved unchanged"
    requirement: "OFFL-07"
    verification:
      - kind: unit
        ref: "test/providers/tracks_provider_test.dart#TrackListData/TrackDetailData online + no cache / online + stale cache present / online + fetch throws + cache present / online + fetch throws + no cache / offline + cache present / offline + no cache / WR-02 refresh dedup / syncedAt tests"
        status: pass
    human_judgment: false
  - id: D2
    description: "UserTracksListData.build() applies the same online-first contract while still watching selectedBandIdFilterProvider first, so changing the cross-band filter still triggers a fresh fetch with the new bandIdFilter"
    requirement: "OFFL-07"
    verification:
      - kind: unit
        ref: "test/providers/tracks_provider_test.dart#UserTracksListData online + no cache / ... / offline + no cache / changing selectedBandIdFilterProvider triggers a rebuild whose listUserTracks call receives the new bandIdFilter / syncedAt"
        status: pass
    human_judgment: false
  - id: D3
    description: "TracksScreen refetches on every re-selection of the Tracks tab (D-01, tab index 2), shows a subtle AppBar LinearProgressIndicator only when refreshing with data present (D-08/D-09), and renders OfflineNoCacheView (no Retry) on OfflineNoCacheException instead of SyncStatusBadge"
    requirement: "OFFL-08"
    verification:
      - kind: automated_ui
        ref: "test/features/tracks/tracks_screen_test.dart#switching to the Tracks tab a second time triggers a second listUserTracks() network call (D-01 tab-switch refetch) / AppBar's LinearProgressIndicator shows only while refreshing with data already present.../ offline with no cache shows OfflineNoCacheView, with no Retry button (D-06)"
        status: pass
    human_judgment: false
  - id: D4
    description: "TrackListScreen and TrackDetailScreen render OfflineNoCacheView on OfflineNoCacheException, render cached data offline when cache exists, and no longer render SyncStatusBadge, with no new tab-switch/in-flight-indicator wiring (D-02)"
    requirement: "OFFL-08"
    verification:
      - kind: automated_ui
        ref: "test/features/tracks/track_list_screen_test.dart#offline with no cache shows OfflineNoCacheView, with no Retry button (D-06) / test/features/tracks/track_detail_screen_test.dart#offline with no cache shows OfflineNoCacheView, with no Retry button (D-06) / the Edit IconButton is disabled and the Delete ListTile is disabled with 'Requires connection' tooltip while offline (offline + cache present)"
        status: pass
    human_judgment: false

duration: ~15min
completed: 2026-08-21
status: complete
---

# Phase 07 Plan 03: Online-First Tracks Providers & Screens Summary

**All three track providers (TrackListData, TrackDetailData, UserTracksListData) and their three screens flipped from cache-first to online-first using 07-01's proven pattern, with the cross-band Tracks tab getting D-01 tab-switch-refetch wiring and the two pushed-route screens getting none per D-02**

## Performance

- **Duration:** ~15 min (base 15:04:48 -> Task 2 commit 15:20:14)
- **Completed:** 2026-08-21
- **Tasks:** 2
- **Files modified:** 9 (0 created, 9 modified)

## Accomplishments

- `TrackListData.build(bandId)`, `TrackDetailData.build(bandId, trackId)`, and `UserTracksListData.build()` are all online-first: online always fetches fresh (ignoring a populated cache on the happy path), a failed online fetch falls back to cache silently (D-03), and offline-with-nothing-cached throws the shared `OfflineNoCacheException` (D-06) — `_version` guards, `_inFlightRefresh` dedup, and local-mutation methods (`removeFromList`, `updateFields`) preserved unchanged; the three now-dead `_refresh()` helpers were deleted
- `TracksScreen` (cross-band tab, index 2) refetches on every re-selection of the Tracks tab via a `selectedTabIndexProvider` listener (D-01), shows a subtle `AppBar` `LinearProgressIndicator` only while refreshing with data already present (D-08), keeps the existing cold-start full-screen spinner untouched (D-09), and renders `OfflineNoCacheView` on `OfflineNoCacheException`
- `TrackListScreen`/`TrackDetailScreen` (pushed routes, family providers) get the offline-no-cache treatment with no new tab-switch/in-flight-indicator wiring, per D-02
- `SyncStatusBadge` removed from all 3 track screens (3 of the phase's remaining 8 call-sites at plan start; final widget deletion itself is 07-05's job per 07-RESEARCH.md's resolved open question #4)

## Task Commits

Each task was committed atomically:

1. **Task 1: tracks_provider.dart — TrackListData, TrackDetailData, UserTracksListData online-first** - `612cfa2` (feat)
2. **Task 2: Track screens — TracksScreen (tab), TrackListScreen + TrackDetailScreen (pushed routes)** - `081b15f` (feat)

_Note: both tasks carried `tdd="true"`; tests and implementation were written together per task rather than as separate RED/GREEN commits, matching this plan's `type="execute"` (not `type="tdd"`) frontmatter — no plan-level RED/GREEN gate applies here._

## Files Created/Modified

- `lib/providers/tracks_provider.dart` - `TrackListData.build()`, `TrackDetailData.build()`, `UserTracksListData.build()` rewritten online-first; dead `_refresh(...)` private methods removed; added `connectivity_provider.dart`/`offline_no_cache_exception.dart` imports
- `lib/features/songs/tracks_screen.dart` - Watch lifted to `build()`, tab-switch listener (index 2), AppBar progress indicator, `OfflineNoCacheView` error branch, `SyncStatusBadge` removed
- `lib/features/tracks/track_list_screen.dart` - `OfflineNoCacheView` error branch, `SyncStatusBadge` removed, no new wiring (D-02)
- `lib/features/tracks/track_detail_screen.dart` - `OfflineNoCacheView` error branch, `SyncStatusBadge` removed, no new wiring (D-02)
- `test/providers/tracks_provider_test.dart` - Rewritten for the 6 online-first cases per provider (18 tests), preserved `_version`-guard/dedup/local-mutation/syncedAt test intent
- `test/features/tracks/tracks_screen_test.dart` - `wrap()` now overrides `isOnlineProvider` (default true, matching 07-02's pattern); offline-no-cache view test, tab-switch-refetch test, AppBar-indicator test added; several assertions switched from `pump()` to `pumpAndSettle()`
- `test/features/tracks/track_list_screen_test.dart` - Offline-no-cache view test added; several assertions switched to `pumpAndSettle()`
- `test/features/tracks/track_detail_screen_test.dart` - Offline-no-cache view test added; the pre-existing offline-mutation-gate test now seeds a cache (see Deviations)
- `test/features/setlists/add_setlist_tracks_dialog_test.dart` - Deviation fix (see below)

## Decisions Made

- **TracksScreen's zero-bands early return kept as-is, listener registered before it:** the plan explicitly calls this out — the tab-switch listener must fire regardless of the bands-empty state, so `ref.listen(selectedTabIndexProvider, ...)` sits at the very top of `build()`, ahead of the `bands.isEmpty` branch.
- **`UserTracksListData._version` left as a never-mutated `final int`:** per the plan's explicit instruction to preserve this pre-existing pattern as-is (no local-mutation method exists on this provider, so the guard is trivially always-true) rather than "fixing" it as an unrelated architectural change.
- **No `AppBar.bottom` indicator or tab-switch listener on `TrackListScreen`/`TrackDetailScreen`:** verified true in practice (both always start with `hasValue == false` on `Navigator.push`, so `isLoading && hasValue` never fires), mirroring 07-01's `BandDetailScreen` precedent exactly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `add_setlist_tracks_dialog_test.dart`'s offline Add-button test, broken by this plan's Task 1**
- **Found during:** Full-suite verification after Task 2
- **Issue:** `test/features/setlists/add_setlist_tracks_dialog_test.dart`'s "with tracks selected and isOnlineProvider false, the Add button is disabled with a 'Requires connection' label" test relied on `TrackListData` fetching inline regardless of connectivity state (the pre-online-first cache-first contract had no connectivity check at all). Once `TrackListData.build()` became online-first (this plan's Task 1), offline with nothing cached now throws `OfflineNoCacheException` instead of populating the checklist, so the test's `tester.tap(find.text('Track One'))` could no longer find that widget.
- **Fix:** Added an optional `cacheService` parameter to the test file's `wrap()` helper and seeded the offline branch's cache (`writeBandTracks('b1', [...])`) in that one test, so the checklist still renders while exercising the connectivity-gated Add button as originally intended — data availability and connectivity gating are now independently controlled, matching the new online-first contract.
- **Files modified:** `test/features/setlists/add_setlist_tracks_dialog_test.dart`
- **Commit:** `081b15f`

### Out-of-Scope Discoveries (not fixed, logged for visibility)

**2. `test/regression/offline_trust_regression_test.dart` — "every cached screen renders SyncStatusBadge" now fails for all 5 of this plan's + 07-01's/07-02's flipped screens.** This phase-level regression guard from Phase 5 asserts the now-obsolete claim that every cached screen renders `SyncStatusBadge`. `07-05-PLAN.md` (wave 3, after all screen rewrites land) explicitly rewrites this test's assertion to the new aggregate claim (absence of `SyncStatusBadge`, presence of `OfflineNoCacheException` references) — out of scope for this plan per 07-RESEARCH.md's resolved open question #4.

**3. `test/widget_test.dart` — "bottom navigation switches between tabs" fails with `isOnlineProvider` unresolved.** This top-level legacy widget test (Phase 1 vintage) predates connectivity gating entirely and doesn't override `isOnlineProvider`; `connectivity_plus` resolves to the fail-safe-offline default in this sandboxed test environment with no cache seeded, so `BandsListData` (flipped online-first by 07-01) throws `OfflineNoCacheException` and the assertion `find.text('B.A.T.H.')` fails. This is 100% pre-existing — the test only navigates Home→Bands, never touches the Tracks tab this plan modifies, and `lib/features/bands/bands_screen.dart` was not touched by this plan. Confirmed present before this plan's Task 1 (inherited from the 07-01 merge at `94e6719`). Not listed in any Phase 7 plan's `files_modified`, so no plan currently owns fixing it — flagging here for the orchestrator/user's awareness since it is a legitimate gap in the phase's overall test coverage plan.

---

**Total deviations:** 1 auto-fixed bug (Rule 1), 2 out-of-scope discoveries logged (not fixed).
**Impact on plan:** None on shipped functionality for this plan's own scope — all of this plan's declared verification (`tracks_provider_test.dart`, `tracks_screen_test.dart`, `track_list_screen_test.dart`, `track_detail_screen_test.dart`, full-tree `flutter analyze`) passes clean.

## Issues Encountered

- **Widget-test timing under online-first (mirrors 07-01/07-02):** several existing widget tests asserted on data immediately after a single `tester.pump()`, which worked under the old cache-first contract but is no longer reliable once the happy path always goes through a genuine network fetch first. These were switched to `await tester.pumpAndSettle()` across all three screen test files.
- **`TrackDetailScreen`'s pre-existing offline-mutation-gate test had no seeded cache:** "the Edit IconButton is disabled and the Delete ListTile is disabled... while offline" previously worked because the old cache-first `build()` always fetched inline regardless of connectivity. Under online-first, offline + no cache now throws `OfflineNoCacheException` before the Edit/Delete controls ever render. Fixed by seeding `cacheService.writeBandTrackDetail('b1', 't1', {...})` before pumping — this is a within-plan-scope fix (the test file was already in this plan's declared `files` list), not a separate deviation.

## Next Phase Readiness

- The online-first pattern is now proven against 2 of the phase's 3 remaining families (Bands from 07-01, Tracks from this plan) — 07-04 (Setlists) can mirror the exact same shape, including the family-provider (`SetlistDetailData`) and filter-watching non-family-provider (`UserSetlistsListData`) variants this plan already validated for Tracks.
- `SyncStatusBadge` now has at most 5 remaining call-sites (Setlists x3 pending 07-04, plus whatever 07-02 left for Home/Profile) — 07-05's final widget deletion + regression-guard rewrite is unblocked once 07-02/07-04 land.
- Two out-of-scope test gaps flagged above (`offline_trust_regression_test.dart`, `test/widget_test.dart`) — the former is explicitly 07-05's job; the latter has no current owner in the Phase 7 roadmap and should be surfaced to the user/orchestrator.
- No blockers for 07-04 or 07-05.

---
*Phase: 07-cache-behavior-flip-online-first*
*Completed: 2026-08-21*

## Self-Check: PASSED

All 9 files listed under "Files Created/Modified" verified present on disk. Both task commit hashes (`612cfa2`, `081b15f`) verified present in `git log`.
