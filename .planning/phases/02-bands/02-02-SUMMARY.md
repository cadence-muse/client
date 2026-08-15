---
phase: 02-bands
plan: 02
subsystem: ui
tags: [riverpod, hive, flutter, bands, family-provider, cache-first]

requires:
  - phase: 02-bands
    provides: "02-01: BandsListData cache-first provider, bandsBox Hive cache, BandAvatar widget, BandsScreen ListTile shell"
provides:
  - PublicApi.getBand(String bandId) (GET /api/band/{bandId})
  - CacheService.readBandDetail(bandId)/writeBandDetail(bandId, data) (band_<id>-keyed entries in the existing bandsBox)
  - BandDetailData — first family Riverpod AsyncNotifier in the project (bandDetailDataProvider(bandId))
  - BandDetailScreen (name/avatar/members/invite code + copy-to-clipboard)
  - BandsScreen ListTile.onTap navigation wiring to BandDetailScreen
affects: [02-04 (edit/delete band), 02-05 (owner-gated remove-member — reuses BandDetailScreen's members section and ownerId already flowing through BandDetailData)]

actuals:
  tokens: 6200
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "First family AsyncNotifier provider (@riverpod class BandDetailData extends _$BandDetailData with build(String bandId)) — riverpod_generator auto-detects the extra build() parameter as the family key, proving the family pattern generalizes from BandsListData's non-family shape"
    - "Per-band detail cached as keyed entries (band_<id>) inside the SAME bandsBox from 02-01, rather than a new Hive box — proves RESEARCH.md's one-box-keyed-entries recommendation for sub-resource caching"

key-files:
  created:
    - lib/features/bands/band_detail_screen.dart
    - test/providers/band_detail_provider_test.dart
    - test/features/bands/band_detail_screen_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/cache/cache_service.dart
    - lib/providers/bands_provider.dart
    - lib/providers/bands_provider.g.dart
    - lib/features/bands/bands_screen.dart
    - test/providers/auth_provider_test.dart

key-decisions:
  - "AsyncValue.value rethrows on AsyncError — BandDetailScreen's AppBar title needed bandAsync.valueOrNull?['name'] instead of .value, otherwise reading the title crashed the widget before the body's own .when() error branch ever got a chance to render the Retry UI"
  - "band_<id> key format inside the shared bandsBox (not a second box) — mirrors 02-01's RESEARCH.md guidance and keeps the per-endpoint-box pattern (D-02) intact while adding a second data shape (single detail map vs. list) into the same box"

requirements-completed: [BAND-03, BAND-07]

coverage:
  - id: D1
    description: "BandDetailScreen renders GET /api/band/{bandId} results: band name heading + BandAvatar, Members section (usernames), Invite code section with working Copy-to-clipboard (Copied! snackbar)"
    requirement: BAND-03
    verification:
      - kind: unit
        ref: "test/providers/band_detail_provider_test.dart#cache-hit returns cached detail map immediately with a silent background refresh"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#populated screen renders name, BandAvatar, member username, and invite code with Copy"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#tapping Copy places the trimmed invite code on the clipboard and shows a Copied! snackbar"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cache-first loading/error states: spinner only on true cache-miss, cached data shown immediately with silent background refresh, network failure with no cache shows Couldn't load band details + Retry"
    requirement: BAND-03
    verification:
      - kind: unit
        ref: "test/providers/band_detail_provider_test.dart#no cache and network failure yields AsyncError"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#cached data present renders immediately with no spinner"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#background refresh silently replaces displayed data with no spinner"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#no cache and network failure shows \"Couldn't load band details\" + Retry"
        status: pass
    human_judgment: false
  - id: D3
    description: "BAND-03 edge probes: empty-members graceful fallback, long band-name ellipsis truncation"
    requirement: BAND-03
    verification:
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#empty members array renders a graceful \"No members\" fallback"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#band name longer than 30 characters truncates to a single line with ellipsis"
        status: pass
    human_judgment: false
  - id: D4
    description: "Tapping a band row on BandsScreen navigates to BandDetailScreen with the tapped band's id"
    requirement: BAND-03
    verification:
      - kind: other
        ref: "grep -n \"onTap\" lib/features/bands/bands_screen.dart"
        status: pass
    human_judgment: true
    rationale: "Wiring presence is proven by grep (the plan's own acceptance criterion), but the full tap-to-navigate visual flow on the real app isn't covered by an automated integration test in this plan — best confirmed in end-of-phase UAT alongside 02-01's equivalent judgment call for the Bands tab."
  - id: D5
    description: "UI-SPEC backstop dimensions not independently tested: many-members ListView scroll without breakage, ~36-char invite-code UUID wrap/fit across screen widths in monospace, member row shows no Remove icon this plan, Members section label wording at 0/1/many"
    verification: []
    human_judgment: true
    rationale: "Plan classified these as backstop (visual/layout) verification, not requiring dedicated automated tests. Best confirmed visually in end-of-phase UAT."

duration: 20min
completed: 2026-08-15
status: complete
---

# Phase 2 Plan 2: Band Detail (BAND-03, BAND-07) Summary

**GET /api/band/{bandId} wired end-to-end — PublicApi method, per-band-keyed entries in the existing bandsBox, the project's first family Riverpod provider (BandDetailData), and a real BandDetailScreen with working copy-to-clipboard invite code**

## Performance

- **Duration:** 20 min
- **Tasks:** 2
- **Files modified:** 9 (3 created, 6 modified)

## Accomplishments
- `PublicApi.getBand(bandId)` calls `GET /api/band/{bandId}` and returns the full `Band` map unwrapped (no `items` unwrapping, unlike `listBands()`)
- `CacheService` extended with `readBandDetail`/`writeBandDetail`, keyed `band_<id>` inside the SAME `bandsBox` from 02-01 (no second Hive box)
- `BandDetailData` — the project's first family `@riverpod` `AsyncNotifier` (`build(String bandId)`), mirroring `BandsListData`'s cache-first shape field-for-field: cache-hit returns immediately with silent background refresh; cache-miss fetches inline; `refresh()` dedupes concurrent calls
- `BandDetailScreen` — name heading (ellipsis-truncated) + `BandAvatar`, Members section (usernames, "No members" fallback when empty), Invite code section in monospace with a working Copy button (`Clipboard.setData` + "Copied!" snackbar)
- `BandsScreen`'s `ListTile` now navigates to `BandDetailScreen(bandId: ...)` on tap
- Full edge-state coverage: no-cache network failure → `AsyncError` + Retry UI, cache-hit-no-spinner, silent background refresh, empty-members fallback, long-name ellipsis truncation

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end GET /api/band/{bandId} — per-band cache, detail provider, and detail screen (BAND-03, BAND-07)** - `bfbb4e6` (feat)
2. **Task 2: Edge-state test coverage — loading/error/empty-members/overflow (BAND-03, BAND-07)** - `2f534f2` (test)

_Note: Task 1 is a `tracer` task; its `<verify>` (`flutter test test/providers/band_detail_provider_test.dart test/features/bands/band_detail_screen_test.dart`) was run and passed before proceeding to Task 2's expansion coverage._

## Files Created/Modified
- `lib/api/public_api.dart` - Added `getBand(bandId)`
- `lib/cache/cache_service.dart` - Added `readBandDetail`/`writeBandDetail`, keyed into the existing `bandsBox`
- `lib/providers/bands_provider.dart` - New `BandDetailData` family cache-first provider (+ generated `bands_provider.g.dart`)
- `lib/features/bands/band_detail_screen.dart` - New `BandDetailScreen`
- `lib/features/bands/bands_screen.dart` - Added `ListTile.onTap` navigation to `BandDetailScreen`
- `test/providers/band_detail_provider_test.dart` - 2 tests (cache-hit, error)
- `test/features/bands/band_detail_screen_test.dart` - 7 tests (populated, copy, no-spinner-cache-hit, background-refresh, empty-members, error, long-name)
- `test/providers/auth_provider_test.dart` - `_FakeCacheService` extended with `readBandDetail`/`writeBandDetail` to satisfy the widened `CacheService` interface (same pattern as 02-01's `readBands`/`writeBands` fix)

## Decisions Made
- `BandDetailScreen`'s `AppBar` title reads `bandAsync.valueOrNull?['name']` rather than `.value` — `AsyncValue.value` rethrows the underlying error when the async state is `AsyncError`, which crashed the widget on the error path before its own `.when()` error branch could render the Retry UI. Caught via the "no cache and network failure" screen test.
- Per-band detail cached as `band_<id>` keyed entries inside 02-01's existing `bandsBox`, not a new box — proves RESEARCH.md's one-box-keyed-entries recommendation extends cleanly to a second data shape (single map vs. list) in the same box.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `AsyncValue.value` rethrow crashed `BandDetailScreen` on the error path**
- **Found during:** Task 1 (post-implementation `flutter test` run)
- **Issue:** `bandAsync.value?['name']` used in the `AppBar` title threw the underlying `ApiException` whenever `bandDetailDataProvider` was in an `AsyncError` state, since Riverpod's `AsyncValue.value` getter rethrows on error by default. This crashed the widget build entirely before the body's `.when(error: ...)` branch ever rendered the "Couldn't load band details" + Retry UI.
- **Fix:** Changed to `bandAsync.valueOrNull?['name']`, which returns `null` on error instead of rethrowing.
- **Files modified:** lib/features/bands/band_detail_screen.dart
- **Verification:** `flutter test test/features/bands/band_detail_screen_test.dart` (error-state test) passes
- **Committed in:** bfbb4e6 (Task 1 commit)

**2. [Rule 1 - Bug] `test/providers/auth_provider_test.dart`'s `_FakeCacheService` failed to compile against the widened `CacheService` interface**
- **Found during:** Task 1 (post-implementation `flutter analyze` run)
- **Issue:** `CacheService` gained `readBandDetail`/`writeBandDetail`; the hand-written `_FakeCacheService implements CacheService` double didn't implement them, breaking compilation (same class of issue 02-01 hit with `readBands`/`writeBands`).
- **Fix:** Added `readBandDetail`/`writeBandDetail` implementations backed by an in-memory `Map<String, Map<String, dynamic>>` field, cleared alongside the others in `clearAll()`.
- **Files modified:** test/providers/auth_provider_test.dart
- **Verification:** `flutter analyze` clean; `flutter test test/providers/auth_provider_test.dart` passes (5/5)
- **Committed in:** bfbb4e6 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — one a real crash bug caught by this task's own error-state test, one a pre-existing test double broken by the interface widening this task's `CacheService` changes required)
**Impact on plan:** Both fixes were required for the plan's own acceptance criteria (`flutter analyze` clean, all tests pass). No scope creep beyond what BAND-03/BAND-07's own changes necessitated.

## Issues Encountered
None beyond the deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `BandDetailData`/per-band `bandsBox` entries/`PublicApi.getBand()` are ready for 02-04 (edit/delete band) and 02-05 (owner-gated remove-member) to build on — `ownerId` is already flowing through `BandDetailData` into the screen (unused this plan, per the threat model's T-02-01 disposition: no owner-gated UI decision is made here, that lands in 02-05).
- `BandDetailScreen`'s Members section has no Remove icon yet (explicitly deferred to 02-05 per the plan).
- No blockers.

---
*Phase: 02-bands*
*Completed: 2026-08-15*

## Self-Check: PASSED

All created/modified files exist on disk; both task commits (`bfbb4e6`, `2f534f2`) found in git log; `flutter analyze` clean; `flutter test` full suite (44 tests) passes.
