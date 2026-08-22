---
phase: 10-searchable-setlist-track-picker
plan: 01
subsystem: ui
tags: [flutter, dart, riverpod, setlists, search, offline-cache]

# Dependency graph
requires:
  - phase: 07-offline-read-cache
    provides: isOnlineProvider, trackListDataProvider, CacheService offline read pattern
provides:
  - "Optional searchQuery query parameter on ListBandTracks (publicapi.yml + PublicApi.listBandTracks)"
  - "Search TextField in AddSetlistTracksDialog with 300ms debounced online request (forward-compatible wire traffic, discarded result)"
  - "trackMatchesSearchQuery(): case-insensitive title/artist substring filter, applied offline only"
  - "Distinct 'No tracks match your search' empty state, never conflated with 'No more tracks available'"
affects: [setlists, tracks, offline-cache]

# Actuals (#2632)
actuals:
  tokens: 4479
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Debounced network call fired directly via publicApiProvider (not trackListDataProvider) to avoid polluting the shared cache with search-variant keys; result intentionally discarded via .catchError()"
    - "Offline-only client-side substring filtering, applied to a var-reassigned local list to preserve original relative order"

key-files:
  created:
    - test/features/setlists/search_filter_test.dart
  modified:
    - lib/api/publicapi.yml
    - lib/api/public_api.dart
    - lib/features/setlists/add_setlist_tracks_dialog.dart
    - test/api/public_api_test.dart
    - test/features/setlists/add_setlist_tracks_dialog_test.dart

key-decisions:
  - "D-03/D-04 (from 10-CONTEXT.md): searchQuery is sent over the wire (not doc-only), debounced 300ms, only while online; response discarded since the backend currently ignores the field."
  - "D-05/D-06: online search visibly does nothing to the displayed list this milestone — an accepted product tradeoff, not a bug."
  - "Debounced request goes through publicApiProvider directly, never through trackListDataProvider, so the shared multi-consumer cache is never keyed by search-query variants."

patterns-established:
  - "Client-side spec extensions to publicapi.yml document explicitly in the field's `description` that the backend currently ignores the field, so spec readers don't mistake it for already-implemented server-side behavior."

requirements-completed: [SETL-12]

coverage:
  - id: D1
    description: "ListBandTracks documents an optional searchQuery query parameter in publicapi.yml, stating the backend currently ignores it"
    requirement: "SETL-12"
    verification:
      - kind: unit
        ref: "grep -A 20 'operationId: ListBandTracks' lib/api/publicapi.yml | grep -c 'name: searchQuery' == 1"
        status: pass
    human_judgment: false
  - id: D2
    description: "PublicApi.listBandTracks() accepts an optional searchQuery and wire-encodes it as a query parameter only when non-empty"
    requirement: "SETL-12"
    verification:
      - kind: unit
        ref: "test/api/public_api_test.dart#listBandTracks group (2 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "AddSetlistTracksDialog renders a search TextField above the checklist and debounces a discarded online listBandTracks(searchQuery:) request 300ms after the last keystroke, without altering the displayed list"
    requirement: "SETL-12"
    verification:
      - kind: integration
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#renders a search TextField..., #while online, typing in the search field sends exactly one debounced GET request..."
        status: pass
    human_judgment: false
  - id: D4
    description: "trackMatchesSearchQuery() case-insensitive title/artist substring match, including empty-query and exact-match adjacency edges"
    requirement: "SETL-12"
    verification:
      - kind: unit
        ref: "test/features/setlists/search_filter_test.dart (5 tests)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Offline typing immediately narrows the checklist to matches with no debounce delay, preserves order, and a zero-match offline search shows a distinct 'No tracks match your search' message never conflated with 'No more tracks available'"
    requirement: "SETL-12"
    verification:
      - kind: integration
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#offline: typing a search query..., #offlineEmptySearchMessage:..., #clearSearchFilter:..."
        status: pass
    human_judgment: false
  - id: D6
    description: "Selecting and submitting tracks while a search query is active still calls addSetlistTracks with exactly the checked trackIds, online or offline"
    requirement: "SETL-12"
    verification:
      - kind: integration
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#addTracksWithSearchActive:..."
        status: pass
    human_judgment: false

# Metrics
duration: ~15min
completed: 2026-08-22
status: complete
---

# Phase 10 Plan 01: Searchable Setlist Track Picker Summary

**Search TextField added to AddSetlistTracksDialog: offline substring filtering on title/artist, plus a forward-compatible debounced `searchQuery` wire parameter on `ListBandTracks` that the backend currently ignores online.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-08-22T07:31Z (approx., session start)
- **Completed:** 2026-08-22T07:39Z
- **Tasks:** 2
- **Files modified:** 5 modified, 1 created

## Accomplishments
- `ListBandTracks` in `publicapi.yml` documents an optional `searchQuery` query parameter, explicitly noting the backend currently ignores it (D-03)
- `PublicApi.listBandTracks()` accepts and wire-encodes an optional `searchQuery`
- `AddSetlistTracksDialog` renders a search `TextField` (hint "Search by title or artist", search icon) above the existing checklist, debouncing a discarded online request 300ms after the last keystroke (D-04)
- Offline typing immediately (no debounce) narrows the checklist via a new top-level `trackMatchesSearchQuery()` function (case-insensitive title/artist substring, D-02), preserving list order
- A distinct "No tracks match your search" empty state appears only for an offline zero-match search, never conflated with the pre-existing "No more tracks available" message (D-07)
- Selecting and submitting tracks with an active search query still calls `addSetlistTracks` with exactly the checked `trackIds`, online or offline (D-05/D-06 regression coverage)

## Task Commits

Each task was committed atomically (Task 2 followed the RED→GREEN TDD cycle):

1. **Task 1: Wire the online search request end-to-end — spec + API + debounced field** - `d901b61` (feat)
2. **Task 2 (RED): failing tests for offline substring filtering** - `1d6b61c` (test)
3. **Task 2 (GREEN): implement offline substring filtering + distinct empty state** - `4085301` (feat)

_No REFACTOR commit — the GREEN implementation required no cleanup pass._

## Files Created/Modified
- `lib/api/publicapi.yml` - `ListBandTracks` gains an optional `searchQuery` query parameter, description states the backend currently ignores it
- `lib/api/public_api.dart` - `listBandTracks(bandId, {searchQuery})` wire-encodes `searchQuery` as a query parameter when non-empty
- `lib/features/setlists/add_setlist_tracks_dialog.dart` - new top-level `trackMatchesSearchQuery()`; `_searchController`/`_searchQuery`/`_debounceTimer` fields; `dispose()` override; `_onSearchChanged()`; search `TextField`; offline filter applied to `availableTracks`; distinct empty-search-state branch
- `test/api/public_api_test.dart` - new `listBandTracks` group (searchQuery present/absent cases)
- `test/features/setlists/add_setlist_tracks_dialog_test.dart` - 6 new tests: search field rendering, debounced online request, offline immediate filtering, distinct empty-search message, clearing the filter, add-with-search-active regression
- `test/features/setlists/search_filter_test.dart` (new) - 5 pure unit tests for `trackMatchesSearchQuery`

## Decisions Made
- The debounced online request is fired directly via `ref.read(publicApiProvider).listBandTracks(...)`, deliberately not through `trackListDataProvider`, so the shared cache (used by 6+ other call sites, keyed only by `bandId`) is never polluted with search-variant keys. Its result is discarded via `.catchError((_) => <Map<String, dynamic>>[])` — a typed empty-list fallback rather than the plan's literal `.catchError((_) {})`, to keep the `Future<List<Map<String, dynamic>>>` contract type-safe and avoid a possible runtime type error from returning `null` where a non-nullable `T` is expected. Purely a safer restatement of the same "discard the result" intent — no behavior change.
- `_onSearchChanged` only arms the debounce `Timer` when `ref.read(isOnlineProvider)` is true, so offline typing never schedules a pointless network timer.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Used a typed `.catchError()` fallback instead of the plan's literal `(_) {}`**
- **Found during:** Task 1 (debounced online search request)
- **Issue:** The plan's action text specifies `.catchError((_) {})` on a call to `listBandTracks(...)`, which returns `Future<List<Map<String, dynamic>>>`. Returning `null` from a `catchError` handler on a `Future<T>` with non-nullable `T` risks the future completing with a value that violates its own type contract, which can surface as an uncaught runtime `TypeError`.
- **Fix:** Used `.catchError((_) => <Map<String, dynamic>>[])`, an empty list matching the declared return type, preserving the plan's intent (discard the result/error) without the type risk.
- **Files modified:** `lib/features/setlists/add_setlist_tracks_dialog.dart`
- **Verification:** `flutter analyze` reports 0 issues; the online debounce test (`while online, typing in the search field sends exactly one debounced GET request...`) exercises this exact code path and passes.
- **Committed in:** `d901b61` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug-prevention)
**Impact on plan:** No scope creep — a narrow type-safety correction to an inline callback, functionally identical to the plan's intent.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SETL-12 fully implemented and tested; `flutter test` (419 tests) and `flutter analyze` (0 issues) both pass repo-wide.
- Backend `searchQuery` filtering is still unimplemented server-side — the client is forward-compatible wiring only (already flagged in STATE.md Blockers/Concerns for Phase 10; no new blocker introduced).
- No other plans in this phase depend on this plan's output (single-plan phase).

---
*Phase: 10-searchable-setlist-track-picker*
*Completed: 2026-08-22*
