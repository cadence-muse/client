---
phase: 04-setlists
plan: 05
subsystem: ui
tags: [flutter, riverpod, hive, cache-first, bottom-nav]

# Dependency graph
requires:
  - phase: 04-setlists
    provides: setlist_formatting.dart's tracksAndDuration helper, SetlistDetailScreen (04-01); SelectedBandIdFilter/UserTracksListData pattern precedent from Phase 3
provides:
  - "GET /api/setlist/list client method (PublicApi.listUserSetlists)"
  - "CacheService.readUserSetlists/writeUserSetlists (user_setlists_* Hive keys)"
  - "SelectedSetlistBandIdFilter and UserSetlistsListData Riverpod providers"
  - "SetlistsScreen — the global, cross-band Setlists tab (SETL-10)"
  - "Bottom-nav reordered to Home/Bands/Tracks/Setlists/Profile (D-21)"
affects: [phase-05-offline-staleness]

# Actuals (#2632)
actuals:
  tokens: 10400
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Global cross-band tab pattern (flat list + band-name-badge subtitle + filter dropdown skipped on zero bands) applied a second time (Tracks in Phase 3, Setlists here) — confirms the pattern generalizes cleanly for any future per-band-to-cross-band feature."

key-files:
  created:
    - lib/features/setlists/setlists_screen.dart
    - test/features/setlists/setlists_screen_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/cache/cache_service.dart
    - lib/providers/setlists_provider.dart
    - lib/navigation/root_scaffold.dart
    - lib/features/songs/tracks_screen.dart
    - lib/providers/navigation_provider.dart
    - test/providers/setlists_provider_test.dart
    - test/cache/cache_service_test.dart
    - test/providers/auth_provider_test.dart
    - test/widget_test.dart

key-decisions:
  - "SelectedSetlistBandIdFilter distinctly named (not SelectedBandIdFilter) per the plan's naming-deviation note, to avoid a Dart ambiguous-import compile error in add_setlist_tracks_dialog.dart, which imports both tracks_provider.dart and setlists_provider.dart."
  - "Global setlists tab is add-alongside, not a promotion of the per-band setlist model — the per-band (bandId, setlistId) identity remains primary since every mutation endpoint is band-scoped."

patterns-established: []

requirements-completed: [SETL-10]

coverage:
  - id: D1
    description: "Global Setlists tab shows a flat list of every setlist across every band the user belongs to, with a band-name badge subtitle and track-count-plus-duration trailing text"
    requirement: "SETL-10"
    verification:
      - kind: unit
        ref: "test/features/setlists/setlists_screen_test.dart#populated cross-band list renders each row's band-name subtitle, name title, and tracksAndDuration trailing text"
        status: pass
    human_judgment: false
  - id: D2
    description: "Filter dropdown narrows the global list to one band via a query parameter; dropdown is skipped entirely (no button) when the user belongs to zero bands"
    requirement: "SETL-10"
    verification:
      - kind: unit
        ref: "test/features/setlists/setlists_screen_test.dart#selecting a band in the dropdown re-fetches with that bandId as a query parameter"
        status: pass
      - kind: unit
        ref: "test/features/setlists/setlists_screen_test.dart#zero bands renders the empty state with no dropdown and no button"
        status: pass
    human_judgment: false
  - id: D3
    description: "Bottom nav reordered to Home/Bands/Tracks/Setlists/Profile (D-21)"
    verification:
      - kind: unit
        ref: "test/widget_test.dart#bottom navigation switches between tabs"
        status: pass
    human_judgment: false
  - id: D4
    description: "Cache-first UserSetlistsListData provider (cache-hit + background refresh, no-cache network failure, refresh dedup, filter-change rebuild) and user_setlists_* Hive round-trip"
    requirement: "SETL-10"
    verification:
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#UserSetlistsListData"
        status: pass
      - kind: unit
        ref: "test/cache/cache_service_test.dart#writeUserSetlists/readUserSetlists round-trip both a null filter (user_setlists_all key) and a specific bandIdFilter (user_setlists_{id} key), without colliding with each other or with band-scoped setlistsBox entries"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-08-17
status: complete
---

# Phase 4 Plan 5: Global Setlists Tab Summary

**Global cross-band Setlists tab (`SetlistsScreen`) with band-filter dropdown, backed by a new `GET /api/setlist/list` client method and cache-first `UserSetlistsListData` provider, plus the D-21 bottom-nav reorder to Home/Bands/Tracks/Setlists/Profile.**

## Performance

- **Duration:** 35 min
- **Tasks:** 2
- **Files modified:** 14 (2 created, 12 modified)

## Accomplishments
- `PublicApi.listUserSetlists({bandIdFilter})` — `GET /api/setlist/list`, optional `bandId` query filter, mirrors `listUserTracks` exactly.
- `CacheService.readUserSetlists`/`writeUserSetlists` — new `user_setlists_{filter}` Hive keys inside the existing `setlistsBox`, verified not to collide with per-band `band_{id}`/`detail_{bandId}_{setlistId}` entries.
- `SelectedSetlistBandIdFilter` and `UserSetlistsListData` Riverpod providers — cache-first, background-refresh, refresh-dedup shape identical to `UserTracksListData`, distinctly named to avoid an ambiguous-import collision.
- `SetlistsScreen` — new global tab: skips the filter dropdown entirely with zero bands (shows the empty state directly, no button per the Copywriting Contract), otherwise shows a `DropdownButton` + `ListView.separated` of every setlist across every band, band-name-badge subtitle, `tracksAndDuration` trailing text, tap-through to `SetlistDetailScreen`.
- `root_scaffold.dart` reordered to Home/Bands/Tracks/Setlists/Profile (D-21), new `Icons.playlist_play_outlined`/`Icons.playlist_play` destination.
- Closed out SETL-10 — the full Phase 4 requirement set (SETL-01 through SETL-10) is now complete across Plans 01-05.

## Task Commits

Each task was committed atomically:

1. **Task 1: Global Setlists tab — cross-band list + band filter + nav reorder** - `c4ce7ea` (feat), plus `9ca4f2e` (fix — blocking analyzer fix on a test double)
2. **Task 2: Global setlists test coverage + cache round-trip** - `8c004ba` (test)

_Note: Task 1's commit was followed by a small blocking-issue fix commit (Rule 3) required to keep `flutter analyze` clean._

## Files Created/Modified
- `lib/api/public_api.dart` - Added `listUserSetlists({bandIdFilter})`
- `lib/cache/cache_service.dart` - Added `readUserSetlists`/`writeUserSetlists`/`_userSetlistsKey`
- `lib/providers/setlists_provider.dart` - Added `SelectedSetlistBandIdFilter`, `UserSetlistsListData`
- `lib/features/setlists/setlists_screen.dart` (new) - `SetlistsScreen` global tab widget
- `lib/navigation/root_scaffold.dart` - Reordered `screens`/`NavigationDestination` list (D-21), new import
- `lib/features/songs/tracks_screen.dart` - Fixed "View bands" WR-01 button's hardcoded tab index (2 -> 1)
- `lib/providers/navigation_provider.dart` - Updated stale tab-index doc comment to match D-21's new order
- `test/features/setlists/setlists_screen_test.dart` (new) - 5 widget tests
- `test/providers/setlists_provider_test.dart` - Added `UserSetlistsListData` group (4 tests)
- `test/cache/cache_service_test.dart` - Added `user_setlists` round-trip test
- `test/providers/auth_provider_test.dart` - Implemented the two new `CacheService` methods on `_FakeCacheService`
- `test/widget_test.dart` - Fixed stale hardcoded Bands tab index (2 -> 1)

## Decisions Made
- Named the new filter provider `SelectedSetlistBandIdFilter` (not `SelectedBandIdFilter`) per the plan's explicit naming-deviation note — `add_setlist_tracks_dialog.dart` imports both `tracks_provider.dart` and `setlists_provider.dart`, and a duplicate top-level identifier across both would be a Dart ambiguous-import compile error.
- Followed the plan's literal instruction to skip the filter dropdown entirely (not just hide it) when the user belongs to zero bands, matching the Copywriting Contract's "Empty state button | Not shown" — deliberately not copying Track's "View bands" CTA.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed stale hardcoded Bands tab index in `tracks_screen.dart`'s "View bands" button**
- **Found during:** Task 1 (nav reorder)
- **Issue:** `tracks_screen.dart`'s zero-bands empty-state "View bands" button called `setIndex(2)`, which was Bands' index under the old Home/Tracks/Bands/Profile order. After this task's D-21 reorder to Home/Bands/Tracks/Setlists/Profile, index 2 is now Tracks — tapping "View bands" would have re-selected the Tracks tab itself instead of switching to Bands.
- **Fix:** Updated the call to `setIndex(1)` (Bands' new index) and corrected the inline comment.
- **Files modified:** `lib/features/songs/tracks_screen.dart`
- **Verification:** `flutter analyze` clean; `test/widget_test.dart`'s WR-01 test (updated in the same deviation, see #2 below) passes.
- **Committed in:** `c4ce7ea` (Task 1 commit)

**2. [Rule 1 - Bug] Fixed stale hardcoded tab-index assertion in `test/widget_test.dart`**
- **Found during:** Task 2 (full-suite regression run)
- **Issue:** `test/widget_test.dart`'s WR-01 test asserted `NavigationBar.selectedIndex == 2` after tapping "View bands" — a regression surfaced directly by this task's nav reorder (see deviation #1), caught by the full `flutter test` run before commit.
- **Fix:** Updated the expected index to `1`.
- **Files modified:** `test/widget_test.dart`
- **Verification:** Full `flutter test` suite passes (211 tests, zero regressions).
- **Committed in:** `8c004ba` (Task 2 commit)

**3. [Rule 3 - Blocking] Implemented `CacheService`'s new methods on the `_FakeCacheService` test double**
- **Found during:** Task 1 (post-implementation `flutter analyze`)
- **Issue:** `test/providers/auth_provider_test.dart`'s `_FakeCacheService implements CacheService` broke with a `non_abstract_class_inherits_abstract_member` analyzer error once `readUserSetlists`/`writeUserSetlists` were added to the `CacheService` interface.
- **Fix:** Added both methods (and a `clearAll()` clear-out) to `_FakeCacheService`, mirroring the existing `_userTracks` map pattern.
- **Files modified:** `test/providers/auth_provider_test.dart`
- **Verification:** `flutter analyze` clean; `auth_provider_test.dart` passes.
- **Committed in:** `9ca4f2e` (Task 1 follow-up fix commit)

---

**Total deviations:** 3 auto-fixed (2 Rule 1 bug fixes, 1 Rule 3 blocking fix)
**Impact on plan:** All three fixes are direct, necessary consequences of this task's own nav-reorder and interface changes — no scope creep. Without them `flutter analyze` and the full test suite would not have passed.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 4's full requirement set (SETL-01 through SETL-10) is complete across Plans 01-05.
- `flutter analyze` clean; full `flutter test` suite passes (211 tests, zero regressions across Phase 1/2/3 and Plans 04-01 through 04-04).
- No blockers for Phase 5 (offline staleness UI, OFFL-02/03/04/05), which is out of this phase's scope by design.

---
*Phase: 04-setlists*
*Completed: 2026-08-17*

## Self-Check: PASSED

All files listed under "Files Created/Modified" verified present on disk. All three task commits (`c4ce7ea`, `9ca4f2e`, `8c004ba`) verified present in git history.
