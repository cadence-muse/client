---
phase: 17-api-contract-sync
plan: 02

subsystem: ui
tags: [flutter, riverpod, setlists, search]

# Dependency graph
requires:
  - phase: 17-01
    provides: (independent — wave 1, no dependency)
provides:
  - "AddSetlistTracksDialog renders live server search results while online instead of discarding the debounced listBandTracks() response (D-03)"
affects: [setlists, api-contract-sync]

# Actuals (#2632)
actuals:
  tokens: 2200
  tasks: 2
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Debounced network response captured via _serverSearchResults state field and rendered in build() rather than discarded"

key-files:
  created: []
  modified:
    - lib/features/setlists/add_setlist_tracks_dialog.dart
    - test/features/setlists/add_setlist_tracks_dialog_test.dart

key-decisions:
  - "_serverSearchResults defaults to null (no completed server search yet), distinguishing 'never searched' from 'searched, zero results' — the latter renders addSetlistTracksNoMatch, the former the unfiltered list"
  - "A failed debounced search request leaves _serverSearchResults and the displayed list unchanged — no new error state introduced; the dialog's existing tracksAsync.when error branch already owns the 'couldn't load tracks at all' case"
  - "Empty-state gate dropped its !isOnline condition so a zero-result online server search and a zero-match offline substring filter share the same addSetlistTracksNoMatch copy"

patterns-established:
  - "Pattern 1: Debounced search responses that must reach the UI should be captured into nullable state (null = 'no search yet') and consumed in build(), not chained with a discarding .catchError"

requirements-completed: [API-01]

coverage:
  - id: D1
    description: "AddSetlistTracksDialog renders the debounced online server search response instead of discarding it (D-03)"
    requirement: "API-01"
    verification:
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#while online, typing in the search field sends exactly one debounced GET request carrying the typed searchQuery after 300ms, and the checklist renders the server's search response instead of the unfiltered list (D-03)"
        status: pass
    human_judgment: false
  - id: D2
    description: "currentTrackIds exclusion applies to server search results, not just the initial unfiltered load"
    requirement: "API-01"
    verification:
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#while online, currentTrackIds exclusion also applies to server search results, not just the initial load"
        status: pass
    human_judgment: false
  - id: D3
    description: "Online zero-result server search shows addSetlistTracksNoMatch, same copy as the offline zero-match case"
    requirement: "API-01"
    verification:
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#while online, a server search that returns zero results shows the same \"no match\" copy as the offline zero-match case"
        status: pass
    human_judgment: false
  - id: D4
    description: "Offline substring filtering (trackMatchesSearchQuery) is unchanged, zero network calls attempted"
    requirement: "API-01"
    verification:
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#offline: typing a search query immediately narrows the checklist to title/artist matches, with no debounce delay"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-27
status: complete
---

# Phase 17 Plan 2: Setlist Track Picker Online Search Fix (D-03) Summary

**Fixed `AddSetlistTracksDialog`'s D-03 discard bug: the debounced `listBandTracks(searchQuery:)` response now renders in the checklist instead of being thrown away, with `currentTrackIds` exclusion preserved and offline substring filtering untouched.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-27T18:04:00Z
- **Completed:** 2026-08-27T18:29:07Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `_onSearchChanged`'s debounced online `listBandTracks(searchQuery:)` response is now captured into `_serverSearchResults` state and rendered by `build()`, replacing the prior `.catchError((_) => <Map<String, dynamic>>[])` discard
- Server search results still exclude `currentTrackIds` — an already-in-setlist track can't reappear just because it matched a search
- A zero-result online server search shows `addSetlistTracksNoMatch` (same copy as offline), not `addSetlistTracksNoneAvailable`
- Offline substring filtering (`trackMatchesSearchQuery`) is unchanged and verified to still work with zero network calls

## Task Commits

Each task was committed atomically (Task 1 is `tdd="true"`, followed RED→GREEN):

1. **Task 1 (RED): failing test for server search rendering** - `0f7b3f8` (test)
2. **Task 1 (GREEN): render server search results instead of discarding them** - `c1f2c26` (feat)
3. **Task 2: edge-case coverage — currentTrackIds exclusion, online zero-results copy** - `f58da92` (test)

**Plan metadata:** committed alongside this SUMMARY

_Task 1 carried `tdd="true"`: the D-05 test was rewritten first (RED, confirmed failing against the unmodified discard behavior), then the dialog source was changed to make it pass (GREEN)._

## Files Created/Modified
- `lib/features/setlists/add_setlist_tracks_dialog.dart` - Added `_serverSearchResults` state; `_onSearchChanged` now stores (not discards) the debounced search response; `build()`'s `availableTracks` prefers server results while online; empty-state gate covers online zero-results too
- `test/features/setlists/add_setlist_tracks_dialog_test.dart` - Rewrote the D-05 "unfiltered while online" test to assert D-03 server-result rendering; added two new tests for `currentTrackIds` exclusion on server results and online zero-match copy

## Decisions Made
- `_serverSearchResults` defaults to `null` ("no completed server search yet") rather than an empty list, so the unfiltered list still shows before the first debounced response lands
- Failed debounced search requests are swallowed silently (`.catchError((_) {})`) — no new error UI, consistent with the plan's explicit behavior spec
- Dropped the `!isOnline` gate on the "no match" empty-state branch since online zero-result searches now need the same copy

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 17 wave 1 plan 17-02 complete; API-01's setlist-track-picker portion is done
- `flutter analyze` clean, full test suite (463 tests) passes with zero regressions
- No blockers for sibling wave-1 plans or subsequent phase 17 plans

---
*Phase: 17-api-contract-sync*
*Completed: 2026-08-27*
