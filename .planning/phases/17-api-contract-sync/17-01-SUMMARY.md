---
phase: 17-api-contract-sync
plan: 01
subsystem: api
tags: [flutter, riverpod, http, search, debounce, l10n]

# Dependency graph
requires:
  - phase: 16-track-terminology-rename
    provides: lib/features/tracks/tracks_screen.dart and lib/features/setlists/setlists_screen.dart already renamed off "song" terminology
provides:
  - GET-based listUserTracks/listUserSetlists matching publicapi.yml's ListUserTracks/ListUserSetlists get: operations
  - Working debounced, online-gated, cross-band search on the Tracks and Setlists tabs
affects: [17-02, api-contract-sync verification]

# Actuals (#2632)
actuals:
  tokens: 10100
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ConsumerStatefulWidget search box: TextEditingController + debounce Timer + online-gated direct publicApiProvider call, bypassing the cached list provider entirely (mirrors AddSetlistTracksDialog's D-02/D-03/D-04 pattern) — now proven on two tab screens, reusable for any future search box"

key-files:
  created: []
  modified:
    - lib/api/public_api.dart
    - lib/features/tracks/tracks_screen.dart
    - lib/features/setlists/setlists_screen.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_ru.arb
    - lib/generated/app_localizations.dart
    - lib/generated/app_localizations_en.dart
    - lib/generated/app_localizations_ru.dart
    - test/api/public_api_test.dart
    - test/features/tracks/tracks_screen_test.dart
    - test/features/setlists/setlists_screen_test.dart
    - test/providers/tracks_provider_test.dart
    - test/providers/setlists_provider_test.dart

key-decisions:
  - "listUserTracks/listUserSetlists migrated from POST+body to GET+queryParameters, mirroring listBandTracks's existing shape exactly, since publicapi.yml defines ListUserTracks/ListUserSetlists as get: operations with BandIdFilter/SearchQuery query parameters"
  - "Search results are fetched directly via publicApiProvider (bypassing userTracksListDataProvider/userSetlistsListDataProvider and cacheServiceProvider), so the shared on-disk cache is never keyed by search variants and no search history is persisted anywhere"
  - "A failed debounced search request leaves the previously-displayed list unchanged with no new error UI, distinct from the tab's existing full-list-load error+Retry treatment"

patterns-established:
  - "Debounced online-gated search box (TextEditingController + 300ms Timer + isOnlineProvider gate + direct publicApiProvider call) is now the standard shape for any future cross-band search UI, proven on both Tracks and Setlists tabs"

requirements-completed: [API-01]

coverage:
  - id: D1
    description: "listUserTracks/listUserSetlists send GET with searchQuery/bandId as query parameters, matching publicapi.yml's get: operation definitions"
    requirement: API-01
    verification:
      - kind: unit
        ref: "test/api/public_api_test.dart#listUserTracks/listUserSetlists groups (GET method + query-parameter assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tracks tab has a working, debounced (300ms), online-gated search box: typing sends a GET to /api/track/list with searchQuery, replaces the displayed list on success, leaves it unchanged on failure"
    requirement: API-01
    verification:
      - kind: automated_ui
        ref: "test/features/tracks/tracks_screen_test.dart#online typing sends exactly one debounced GET..."
        status: pass
      - kind: automated_ui
        ref: "test/features/tracks/tracks_screen_test.dart#online search returning zero results shows commonNoSearchResults"
        status: pass
    human_judgment: false
  - id: D3
    description: "Setlists tab mirrors the Tracks tab's search behavior exactly (debounced GET to /api/setlist/list, offline substring fallback by name, empty-results copy)"
    requirement: API-01
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlists_screen_test.dart#online typing sends exactly one debounced GET..."
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlists_screen_test.dart#online search returning zero results shows commonNoSetlistSearchResults"
        status: pass
    human_judgment: false
  - id: D4
    description: "Offline typing on both tabs narrows the currently-cached list via case-insensitive substring matching, with zero network calls attempted"
    requirement: API-01
    verification:
      - kind: automated_ui
        ref: "test/features/tracks/tracks_screen_test.dart#offline typing filters the cached list immediately with zero additional network calls"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlists_screen_test.dart#offline typing filters the cached list immediately by setlist name with zero additional network calls"
        status: pass
    human_judgment: false
  - id: D5
    description: "Manual smoke: search 'wonder' on the Tracks/Setlists tabs while online shows a real network request with searchQuery=wonder in the URL, observable in devtools"
    verification: []
    human_judgment: true
    rationale: "Plan's <verification> block lists this as a manual devtools smoke test; the automated widget tests assert the equivalent request.url.queryParameters['searchQuery'] value against the mocked ApiClient, which proves the same wire behavior but is not a substitute for an actual devtools observation against a live/backend server."

# Metrics
duration: 25min
completed: 2026-08-27
status: complete
---

# Phase 17 Plan 01: API Contract Sync — GET Search Migration Summary

**Migrated `listUserTracks`/`listUserSetlists` from POST+body to GET+query-parameters and wired real debounced, online-gated search onto the global Tracks and Setlists tabs.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-27T18:07:00Z (approx.)
- **Completed:** 2026-08-27T18:32:00Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments
- `PublicApi.listUserTracks`/`listUserSetlists` now send `GET` with `bandId`/`searchQuery` as query parameters, matching `publicapi.yml`'s `ListUserTracks`/`ListUserSetlists` `get:` operations and mirroring `listBandTracks`'s exact shape
- `TracksScreen` converted to `ConsumerStatefulWidget` with a debounced (300ms), online-gated search box: typing sends a `listUserTracks` call directly via `publicApiProvider` and replaces the displayed list on success; offline typing filters the cached list immediately via the existing `trackMatchesSearchQuery` helper with zero network calls
- `SetlistsScreen` mirrors `TracksScreen`'s pattern exactly, including a new `_setlistMatchesSearchQuery` name-only offline matcher
- Added `commonNoSearchResults`/`commonNoSetlistSearchResults` ARB keys (EN/RU), shown when an active search yields zero results — distinct from the tabs' true empty-band-state copy
- Fixed two pre-existing provider tests that asserted the now-retired `POST` contract

## Task Commits

Each task was committed atomically:

1. **Task 1: GET migration + Tracks tab search, end-to-end** - `81847d9` (feat)
2. **Task 2: Setlists tab search — mirror Task 1's pattern** - `a4a3a8b` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `lib/api/public_api.dart` - `listUserTracks`/`listUserSetlists` migrated to GET+queryParameters
- `lib/features/tracks/tracks_screen.dart` - Converted to `ConsumerStatefulWidget` with debounced search box
- `lib/features/setlists/setlists_screen.dart` - Converted to `ConsumerStatefulWidget` with debounced search box, mirrors TracksScreen
- `lib/l10n/app_en.arb` / `lib/l10n/app_ru.arb` - Added `commonNoSearchResults`/`commonNoSetlistSearchResults`
- `lib/generated/app_localizations*.dart` - Regenerated via `flutter gen-l10n`
- `test/api/public_api_test.dart` - `listUserTracks`/`listUserSetlists` groups updated to assert GET + query-parameter contract
- `test/features/tracks/tracks_screen_test.dart` - New tests for search TextField, debounced online search, empty-results copy, offline filtering
- `test/features/setlists/setlists_screen_test.dart` - Same coverage mirrored for Setlists
- `test/providers/tracks_provider_test.dart` / `test/providers/setlists_provider_test.dart` - Fixed stale `POST` method assertions

## Decisions Made
- `listUserTracks`/`listUserSetlists` migrated to GET+query-parameters, mirroring `listBandTracks`'s exact shape — required by `publicapi.yml`'s `get:` operation definitions for `ListUserTracks`/`ListUserSetlists`
- Search calls bypass the cached list providers and cache service entirely (direct `publicApiProvider` calls), keeping the on-disk cache free of search-variant keys, matching the plan's privacy prohibition (no persisted search-query text)
- A failed debounced search request silently leaves the previous list displayed — no new error UI, distinct from the tab's existing full-list-load error treatment

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed two pre-existing provider tests asserting the retired POST contract**
- **Found during:** Task 2 (full-suite regression run)
- **Issue:** `test/providers/tracks_provider_test.dart` and `test/providers/setlists_provider_test.dart` each had a test asserting `capturedMethods, everyElement('POST')` for `listUserTracks`/`listUserSetlists` calls — directly broken by Task 1's GET migration
- **Fix:** Updated both assertions to `everyElement('GET')`
- **Files modified:** `test/providers/tracks_provider_test.dart`, `test/providers/setlists_provider_test.dart`
- **Verification:** Full suite (471 tests) passes with zero regressions
- **Committed in:** `a4a3a8b` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — direct consequence of the planned wire-contract change, scope-bound to the two call sites this plan touches)
**Impact on plan:** Necessary to keep the full suite green after the planned GET migration. No scope creep.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- API-01 requirement complete: GET migration + working search on both cross-band tabs
- `flutter analyze` clean repo-wide; full test suite (471 tests) passes with zero regressions
- Manual devtools smoke test (search "wonder" showing `searchQuery=wonder` in a live network request) is the one item not automatable from this sandbox — automated widget tests prove the equivalent request shape against a mocked `ApiClient`

## Self-Check: PASSED

- `lib/api/public_api.dart` — FOUND
- `lib/features/tracks/tracks_screen.dart` — FOUND
- `lib/features/setlists/setlists_screen.dart` — FOUND
- Commit `81847d9` — FOUND in `git log --oneline --all`
- Commit `a4a3a8b` — FOUND in `git log --oneline --all`
- `flutter analyze` — No issues found
- `flutter test` (full suite) — 471 tests passed

---
*Phase: 17-api-contract-sync*
*Completed: 2026-08-27*
