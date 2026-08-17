---
phase: 02-bands
plan: 01
subsystem: ui
tags: [riverpod, hive, flutter, bands, cache-first]

requires:
  - phase: 01-foundation-profile-home
    provides: Riverpod migration (OFFL-06) and cache-first CacheService/HomepageData pattern proven on profile/homepage
provides:
  - PublicApi.listBands() (GET /api/band/list)
  - CacheService bandsBox (readBands/writeBands, cleared on signOut)
  - BandsListData cache-first Riverpod AsyncNotifier provider
  - BandAvatar (deterministic color-by-name avatar widget)
  - BandsScreen rewritten as ConsumerWidget with loading/error/empty/populated states
affects: [02-02 (band detail), 02-03 (create/join band), band list caching pattern for future band-scoped endpoints]

actuals:
  tokens: 6656
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Third Hive box (bandsBox) added to CacheService's existing _KeyValueStore abstraction, proving the per-endpoint-box pattern generalizes to a third domain (D-02)"
    - "BandsListData mirrors HomepageData's cache-first AsyncNotifier shape exactly (build()/_fetchAndCache()/_refresh()/refresh()/_doRefresh() with in-flight refresh dedup)"

key-files:
  created:
    - lib/providers/bands_provider.dart
    - lib/providers/bands_provider.g.dart
    - lib/features/bands/band_avatar.dart
    - test/providers/bands_provider_test.dart
    - test/features/bands/bands_screen_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/cache/cache_service.dart
    - lib/features/bands/bands_screen.dart
    - test/widget_test.dart
    - test/providers/auth_provider_test.dart

key-decisions:
  - "band.dart's Band stub (name/genre/memberCount) deleted with no typed replacement — screens use raw Map<String, dynamic> per Phase 1's no-typed-model pattern (D-03), since BandListItem's real schema is just id+name"
  - "BandAvatar kept as its own dedicated widget file (not inlined in ListTile.leading) per D-06, so a future milestone can swap in a real image avatar by editing only this file"

requirements-completed: [BAND-01]

coverage:
  - id: D1
    description: "BandsScreen renders the current user's real GET /api/band/list bands as a ListView of BandAvatar + name + chevron rows, cache-first via the new bandsBox"
    requirement: BAND-01
    verification:
      - kind: unit
        ref: "test/providers/bands_provider_test.dart#cache-hit returns cached data immediately with a silent background refresh"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#populated list renders a ListTile with BandAvatar per band"
        status: pass
    human_judgment: false
  - id: D2
    description: "Empty/loading/error states (No bands yet, spinner on cache-miss, Couldn't load bands + Retry)"
    requirement: BAND-01
    verification:
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#empty list shows \"No bands yet\" empty state"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#no cache and network failure shows \"Couldn't load bands\" + Retry"
        status: pass
    human_judgment: false
  - id: D3
    description: "BAND-01 edge probes: zero-one-many, adjacency (same name, different id, not merged), ordering (no client re-sort), long-name truncation, refresh dedup"
    requirement: BAND-01
    verification:
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#two bands with the same name but different ids render as two separate ListTiles"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#band name longer than 30 characters truncates to a single line with ellipsis"
        status: pass
      - kind: unit
        ref: "test/providers/bands_provider_test.dart#two rapid refresh() calls trigger exactly one network call"
        status: pass
      - kind: unit
        ref: "test/providers/bands_provider_test.dart#no cache and network failure yields AsyncError"
        status: pass
    human_judgment: true
    rationale: "Visual confirmation that the real Bands tab (running app, real backend) shows actual band data instead of the old B.A.T.H. mock is a functional/UX check best done in end-of-phase UAT (workflow.human_verify_mode=end-of-phase) rather than a mid-flight halt — no dev server/URL exists for this native mobile screen to inspect outside the app itself."

duration: 25min
completed: 2026-08-15
status: complete
---

# Phase 2 Plan 1: Bands List (BAND-01) Summary

**GET /api/band/list wired end-to-end — PublicApi method, new bandsBox Hive cache, BandsListData cache-first Riverpod provider, and a real BandsScreen — replacing the hardcoded "B.A.T.H." mock list**

## Performance

- **Duration:** 25 min
- **Tasks:** 2
- **Files modified:** 11 (6 created, 5 modified/deleted)

## Accomplishments
- `PublicApi.listBands()` calls `GET /api/band/list` and unwraps `items` into `List<Map<String, dynamic>>`
- `CacheService` extended with a third `bandsBox` (readBands/writeBands, cleared in `clearAll()` on sign-out)
- `BandsListData` (`@riverpod` AsyncNotifier) mirrors `HomepageData`'s cache-first pattern field-for-field: cache-hit returns immediately with silent background refresh; cache-miss fetches inline; `refresh()` dedupes concurrent calls
- `BandAvatar` — dedicated widget, deterministic color-by-name circle avatar
- `BandsScreen` rewritten as a `ConsumerWidget` with loading/error/empty/populated states, `ListView.separated` of `ListTile(leading: BandAvatar, title: name, trailing: chevron)`, no client-side re-sort, keyed by `BandListItem.id`
- `lib/features/bands/band.dart` (the old `Band` mock model) deleted
- Full edge-state coverage: no-cache network failure -> AsyncError + Retry UI, refresh() dedup, long-name ellipsis truncation, same-name-different-id non-merging (2 distinct rows)

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end GET /api/band/list — API, cache, provider, and list screen (BAND-01)** - `e5689ae` (feat)
2. **Task 2: Edge-state test coverage — error/refresh-dedup/overflow/adjacency (BAND-01)** - `bc91abb` (test)

_Note: Task 1 is a `tracer` task; its `<verify>` (`flutter test test/providers/bands_provider_test.dart test/features/bands/bands_screen_test.dart`) was run and passed before proceeding to Task 2's expansion coverage._

## Files Created/Modified
- `lib/api/public_api.dart` - Added `listBands()`
- `lib/cache/cache_service.dart` - Added `bandsBox`/`readBands()`/`writeBands()`, cleared in `clearAll()`
- `lib/providers/bands_provider.dart` - New `BandsListData` cache-first provider (+ generated `bands_provider.g.dart`)
- `lib/features/bands/band_avatar.dart` - New `BandAvatar` widget
- `lib/features/bands/bands_screen.dart` - Rewritten as `ConsumerWidget` against real data
- `lib/features/bands/band.dart` - Deleted (mock `Band` model)
- `test/providers/bands_provider_test.dart` - 3 tests (cache-hit, error, refresh-dedup)
- `test/features/bands/bands_screen_test.dart` - 5 tests (populated, empty, error, long-name, adjacency)
- `test/widget_test.dart` - Fixed to mock `/api/band/list` and `/api/homepage` per-path and override `cacheServiceProvider`, since the real `BandsScreen` now depends on both providers instead of rendering a static mock
- `test/providers/auth_provider_test.dart` - `_FakeCacheService` extended with `readBands`/`writeBands` to satisfy the widened `CacheService` interface

## Decisions Made
- `band.dart`'s `Band` stub deleted with no typed replacement — screens consume raw `Map<String, dynamic>` per Phase 1's D-03 no-typed-model convention, since `BandListItem`'s real schema (id + name only) doesn't match the removed mock's fields (name/genre/memberCount)
- `BandAvatar` kept in its own file (D-06) rather than inlined into `ListTile.leading`, so a future milestone can add a real image avatar without touching `BandsScreen`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `test/widget_test.dart`'s full-app integration test broke on the `bands_screen.dart` rewrite**
- **Found during:** Task 1 (post-implementation full-suite regression check)
- **Issue:** The pre-existing "bottom navigation switches between tabs" test asserted `find.text('B.A.T.H.')` against the old hardcoded `_mockBands` list, and didn't override `cacheServiceProvider`, relying on the old `BandsScreen` never touching `CacheService.instance`. The new `ConsumerWidget` `BandsScreen` depends on `bandsListDataProvider` -> `cacheServiceProvider`, so the uninitialized real `CacheService.instance` singleton threw and the mock HTTP client returned the same generic `{'id','username'}` body for every path (including `/api/homepage`, which needs `bandsCount`), causing a type-cast crash.
- **Fix:** Added `cacheServiceProvider.overrideWithValue(CacheService.inMemory())`; made the `MockClient` handler branch per `request.url.path` (`/api/band/list` -> `{'items':[{'id':'b1','name':'B.A.T.H.'}]}`, `/api/homepage` -> `{'username','bandsCount'}`, default -> `/api/me` shape).
- **Files modified:** test/widget_test.dart
- **Verification:** `flutter test test/widget_test.dart` passes
- **Committed in:** e5689ae (Task 1 commit)

**2. [Rule 1 - Bug] `test/providers/auth_provider_test.dart`'s `_FakeCacheService` failed to compile against the widened `CacheService` interface**
- **Found during:** Task 1 (post-implementation full-suite regression check)
- **Issue:** `CacheService` gained abstract-equivalent `readBands()`/`writeBands()` methods; the hand-written `_FakeCacheService implements CacheService` double in this test file didn't implement them, breaking compilation.
- **Fix:** Added `readBands()`/`writeBands()` implementations backed by an in-memory `List<Map<String, dynamic>>?` field, cleared alongside `_profile`/`_homepage` in `clearAll()`.
- **Files modified:** test/providers/auth_provider_test.dart
- **Verification:** `flutter test test/providers/auth_provider_test.dart` passes (5/5)
- **Committed in:** e5689ae (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — pre-existing tests broken by the interface change this task's `CacheService`/`BandsScreen` changes required)
**Impact on plan:** Both fixes were required for the plan's own acceptance criteria (`flutter analyze` clean, no new errors) and to keep the existing regression suite green. No scope creep beyond what BAND-01's own changes necessitated.

## Issues Encountered
None beyond the deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `BandsListData`/`bandsBox`/`PublicApi.listBands()` are ready for 02-02 (band detail) to build on — the same `AsyncNotifier` cache-first shape and per-endpoint Hive box pattern should be reused for `BandDetailData`.
- `BandsScreen`'s `ListTile` has no `onTap` wired yet (navigation to detail is explicitly deferred to 02-02 per the plan).
- The empty-state Column has no CTA button yet (deferred to 02-03 once Create Band exists).
- No blockers.

---
*Phase: 02-bands*
*Completed: 2026-08-15*

## Self-Check: PASSED

All created/modified files exist on disk; `lib/features/bands/band.dart` confirmed deleted; both task commits (`e5689ae`, `bc91abb`) found in git log.
