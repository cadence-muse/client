---
phase: 04-setlists
plan: 01
subsystem: ui
tags: [flutter, riverpod, hive, setlists, cache-first]

# Dependency graph
requires:
  - phase: 03-tracks
    provides: TrackListData/TrackDetailData family-provider shape, CacheService _KeyValueStore generalization, create/detail screen structure
provides:
  - setlistsBox cache-store on CacheService (readBandSetlists/writeBandSetlists/readSetlistDetail/writeSetlistDetail)
  - PublicApi.listBandSetlists/getSetlist/createSetlist
  - SetlistListData/SetlistDetailData family AsyncNotifiers (cache-first, no local-mutation method yet)
  - SetlistListScreen/CreateSetlistScreen/SetlistDetailScreen, reachable from BandDetailScreen's new "Setlists" entry
  - setlist_formatting.dart (asMinutesAndSeconds words format, pluralizeTracks, tracksAndDuration, formatEventDate)
affects: [04-setlists-plan-02, 04-setlists-plan-03, 04-setlists-plan-04, 04-setlists-plan-05]

actuals:
  tokens: 23334
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "SetlistListData/SetlistDetailData mirror TrackListData/TrackDetailData's cache-first family-provider shape exactly, including a non-final _version guard with no local-mutation method yet (extended in Plans 02-04)"
    - "Setlist duration formatting is words-based ('42m 35s', setlist_formatting.dart) — a deliberate divergence from Track's 'mm:ss' (track_formatting.dart), per each feature's own UI-SPEC"

key-files:
  created:
    - lib/providers/setlists_provider.dart
    - lib/features/setlists/setlist_formatting.dart
    - lib/features/setlists/setlist_list_screen.dart
    - lib/features/setlists/create_setlist_screen.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - test/providers/setlists_provider_test.dart
    - test/features/setlists/setlist_list_screen_test.dart
    - test/features/setlists/create_setlist_screen_test.dart
    - test/features/setlists/setlist_detail_screen_test.dart
  modified:
    - lib/cache/cache_service.dart
    - lib/api/public_api.dart
    - lib/features/bands/band_detail_screen.dart
    - test/cache/cache_service_test.dart
    - test/providers/auth_provider_test.dart

key-decisions:
  - "SetlistListData/SetlistDetailData carry the WR-02 _version guard field-for-field per TrackListData/TrackDetailData, even though no local-mutation method exists yet in this plan (add/remove/reorder land in Plans 02-04) — kept non-final to match the shape those later plans will extend, per 03-01's precedent"
  - "The 'Setlists' BandDetailScreen entry is placed before the isOwner-gated blocks, visible to every band member — SETL-01/02/03 carry no owner qualifier"
  - "CreateSetlistScreen's track checklist falls back to 'No tracks in this band yet' on both an empty trackListDataProvider result and a load error, keeping the 'Add tracks (optional)' heading visible in both cases — the plan only specified the empty-list case, but treating a failed fetch the same way avoids a raw AsyncError leaking into the create form"

requirements-completed: [SETL-01, SETL-02, SETL-03, SETL-09]

coverage:
  - id: D1
    description: "Band member views a band's setlist list (name, track-count-plus-duration, event date or 'No date set' placeholder) via a new 'Setlists' entry on Band Detail"
    requirement: SETL-01
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_list_screen_test.dart#a cached setlist with no eventDate shows \"No date set\""
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_list_screen_test.dart#track-count pluralization: 1 track is singular, 8 tracks is plural"
        status: pass
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#SetlistListData cache-hit returns cached data immediately with a silent background refresh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Band member creates a setlist via full-screen form (name required, location/date/tracks optional) and lands on its detail screen"
    requirement: SETL-02
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/create_setlist_screen_test.dart#submitting with only a name filled in sends null eventLocation/eventDate/trackIds and pushReplacements to SetlistDetailScreen"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/create_setlist_screen_test.dart#the exact trackIds list sent matches the checked boxes"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/create_setlist_screen_test.dart#empty name is rejected without an API call"
        status: pass
    human_judgment: false
  - id: D3
    description: "Band member views a setlist's full detail: ordered tracks and server-computed running duration"
    requirement: SETL-03
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#a full BandSetlist response renders name/location/date/duration/tracks"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#zero tracks shows \"No tracks in this setlist\" and \"Duration: 0m 0s\""
        status: pass
    human_judgment: true
    rationale: "SETL-03's edge probe returned unclassified in RESEARCH/VALIDATION (flagged for manual review, not auto-backstopped) — automated coverage proves the populated/empty/conditional-field states, but the overall detail-view UX needs human sign-off per the plan's own Flagged Assumptions."
  - id: D4
    description: "Displayed running duration is always the server's durationSeconds value, never client-summed from individual track durations"
    requirement: SETL-09
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#a full BandSetlist response renders name/location/date/duration/tracks"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_list_screen_test.dart#track-count pluralization: 1 track is singular, 8 tracks is plural"
        status: pass
    human_judgment: true
    rationale: "SETL-09's edge probe also returned unclassified per the plan's Flagged Assumptions; the no-client-math guarantee is structurally enforced (screens render durationSeconds verbatim, no summation code exists) and covered by the threat register's T-04-04 mitigation, but flagged here for the same manual-review reason as D3."

duration: 55min
completed: 2026-08-16
status: complete
---

# Phase 4 Plan 1: Setlist View + Create Tracer Summary

**Per-band setlist list/create/detail stood up end-to-end (Hive cache, Riverpod family providers, three screens) mirroring Phase 3's Track pattern, with a words-based `'42m 35s'` duration format distinct from Track's `mm:ss`**

## Performance

- **Duration:** 55 min
- **Started:** 2026-08-16T19:04:29Z
- **Completed:** 2026-08-16T19:59:00Z
- **Tasks:** 2
- **Files modified:** 16 (11 created, 5 modified)

## Accomplishments
- `CacheService` gained a fifth backing store (`_setlistsStore`/`setlistsBox`) with `readBandSetlists`/`writeBandSetlists`/`readSetlistDetail`/`writeSetlistDetail`, wired through the constructor, `inMemory()`, `initialize()`, and `clearAll()`
- `PublicApi` gained `listBandSetlists`, `getSetlist`, and `createSetlist` (the last using the existing `?value` null-aware body-entry syntax from `createBandTrack`)
- `SetlistListData`/`SetlistDetailData` (`lib/providers/setlists_provider.dart`) mirror `TrackListData`/`TrackDetailData`'s cache-first shape field-for-field, including the WR-02 `_version` guard with no local-mutation method yet
- `SetlistListScreen`, `CreateSetlistScreen`, and `SetlistDetailScreen` implement the per-band list/create/detail flow, reachable via a new non-owner-gated "Setlists" entry on `BandDetailScreen`
- `setlist_formatting.dart` introduces the phase's words-based duration format (`'42m 35s'`) plus `pluralizeTracks`/`tracksAndDuration`/`formatEventDate` — deliberately distinct from Track's `mm:ss`
- Full test coverage for both tasks: Hive round-trips, provider cache-first/refresh-dedup behavior, and widget-level empty/error/populated/validation/submit-in-flight states

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end — view, create, and inspect a band's setlists** - `1310dd4` (feat)
2. **Task 2: Setlist cache-store coverage + edge-state tests** - `f27013d` (test)

_Note: Task 1 is a `type="tracer"` task; its own `<verify>` references the test files created in Task 2, so both tasks were executed and verified together in this single-plan worktree run (no interim checkpoint — this plan carries `autonomous: true` and no `checkpoint:*` task)._

## Files Created/Modified
- `lib/cache/cache_service.dart` - `_setlistsStore` backing store + `readBandSetlists`/`writeBandSetlists`/`readSetlistDetail`/`writeSetlistDetail`/`_setlistDetailKey`
- `lib/api/public_api.dart` - `listBandSetlists`/`getSetlist`/`createSetlist`
- `lib/providers/setlists_provider.dart` - `SetlistListData`/`SetlistDetailData` family AsyncNotifiers
- `lib/features/setlists/setlist_formatting.dart` - `asMinutesAndSeconds`, `pluralizeTracks`, `tracksAndDuration`, `formatEventDate`
- `lib/features/setlists/setlist_list_screen.dart` - per-band setlist list, empty/error states, FAB
- `lib/features/setlists/create_setlist_screen.dart` - full-screen create form with inline track multi-select
- `lib/features/setlists/setlist_detail_screen.dart` - read-only detail (name/location/date/duration/ordered tracks)
- `lib/features/bands/band_detail_screen.dart` - new "Setlists" `ListTile`, not owner-gated
- `test/cache/cache_service_test.dart` - real-Hive round-trip tests for the new setlistsBox methods
- `test/providers/setlists_provider_test.dart` - cache-first/refresh-dedup coverage for both providers
- `test/features/setlists/setlist_list_screen_test.dart` - empty/error/date-placeholder/pluralization/truncation
- `test/features/setlists/create_setlist_screen_test.dart` - validation/error-copy/empty-tracks/spinner/request-body assertions
- `test/features/setlists/setlist_detail_screen_test.dart` - loading/error/populated/conditional-field/zero-tracks
- `test/providers/auth_provider_test.dart` - extended `_FakeCacheService` double with the four new setlist methods (interface now requires them)

## Decisions Made
- `SetlistListData`/`SetlistDetailData`'s `_version` field is annotated `// ignore: prefer_final_fields` — it's intentionally non-final (per 03-01's established precedent for fields that will gain a local-mutation method in a later plan), and `flutter analyze` would otherwise flag it as an info-level lint on an otherwise-clean run
- `CreateSetlistScreen`'s track checklist shows `'No tracks in this band yet'` on both an empty track list and a `trackListDataProvider` load error, not just the empty-list case the plan explicitly described — prevents a raw `AsyncError` widget from surfacing inside the create form (Rule 1, minor UX robustness fix)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Extended `test/providers/auth_provider_test.dart`'s `_FakeCacheService` double**
- **Found during:** Task 1 (`flutter analyze` after adding the four new `CacheService` methods)
- **Issue:** `_FakeCacheService implements CacheService` no longer satisfied the interface once `readBandSetlists`/`writeBandSetlists`/`readSetlistDetail`/`writeSetlistDetail` were added to `CacheService`, breaking analysis on an unrelated existing test file
- **Fix:** Added the four missing method overrides (backed by in-memory maps, same pattern as the existing `_bandTracks`/`_trackDetails` fields) and extended `clearAll()` to clear them
- **Files modified:** `test/providers/auth_provider_test.dart`
- **Verification:** `flutter analyze` clean; `flutter test test/providers/auth_provider_test.dart` passes (5/5)
- **Committed in:** `1310dd4` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary compile-fix for an existing test double affected by the new `CacheService` interface surface. No scope creep.

## Issues Encountered
- `flutter pub run build_runner build --delete-conflicting-outputs` regenerated `lib/providers/tracks_provider.g.dart`'s `userTracksListDataProvider` content hash (cosmetic codegen churn from the same generator run, unrelated to any `tracks_provider.dart` source change) — included in the Task 1 commit since it's a byproduct of the required codegen pass, not a manual edit.
- `test/features/setlists/create_setlist_screen_test.dart`'s initial `defaultHandler` was a sync `http.Response Function(http.Request)` instead of the required `Future<http.Response> Function(http.Request)`, and the submit-in-flight spinner test's mock handler didn't distinguish the `POST .../setlist` create call from the subsequent `GET .../setlist/{id}` detail fetch (causing a `'Null' is not a subtype of 'String'` cast crash after navigation) — both fixed before the Task 2 commit; not carried forward as deviations since they were caught and corrected within the same authoring pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `SetlistListData`/`SetlistDetailData`, `CacheService`'s setlist methods, and `PublicApi`'s setlist methods are all in place for Plans 02-04 (track add/remove/reorder, edit/delete setlist) to extend with local-mutation methods on the existing providers, following the `TrackListData.removeFromList()`/`TrackDetailData.updateFields()` precedent.
- Plan 05's global cross-band Setlists tab can reuse `setlist_formatting.dart`'s `tracksAndDuration`/`formatEventDate` unmodified.
- No blockers. `flutter analyze` clean and all 170 project tests pass (including the 40 new/modified setlist-related tests) with zero regressions.

---
*Phase: 04-setlists*
*Completed: 2026-08-16*

## Self-Check: PASSED

All 14 files listed in "Files Created/Modified" (plus this SUMMARY.md) verified present on disk. Both task commit hashes (`1310dd4`, `f27013d`) verified present in `git log --oneline --all`.
