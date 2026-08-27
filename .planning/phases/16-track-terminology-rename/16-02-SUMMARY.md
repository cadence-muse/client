---
phase: 16-track-terminology-rename
plan: 02
subsystem: testing
tags: [flutter, dart, flutter_test]

# Dependency graph
requires:
  - phase: 16-track-terminology-rename
    provides: "lib/features/tracks/tracks_screen.dart (moved from lib/features/songs/), homeAddTrackButton ARB key — established by Plan 16-01"
provides:
  - "7 test files' 'Song'-named sample track-title fixtures (Song One/Two/Three, Cached Song, My Song, bare Song) renamed to their Track equivalents"
  - "Phase-wide closing audit confirming zero surviving 'song' references in lib/ or test/ except the deferred publicapi.yml Songs tag"
affects: [17-api-contract-sync]

# Actuals (#2632)
actuals:
  tokens: 4483
  tasks: 2
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - test/providers/setlists_provider_test.dart
    - test/features/setlists/setlist_detail_screen_test.dart
    - test/features/tracks/track_list_screen_test.dart
    - test/features/tracks/confirm_delete_track_dialog_test.dart
    - test/features/tracks/create_track_screen_test.dart
    - test/features/tracks/track_detail_screen_test.dart
    - test/cache/cache_service_test.dart

key-decisions:
  - "Pure string-literal sed replacements (Song One -> Track One, Song Two -> Track Two, Song Three -> Track Three, Cached Song -> Cached Track, My Song -> My Track, bare 'Song' -> 'Track') kept every fixture value and its matching find.text/expect assertion in sync automatically, since the same literal appears in both places in each file."

patterns-established: []

requirements-completed: [RENAME-01]

coverage:
  - id: D1
    description: "All 51 'Song'-named sample track-title fixtures across the 7 targeted test files renamed to their 'Track' equivalents, with every fixture value and its matching find.text/expect assertion kept in sync"
    requirement: "RENAME-01"
    verification:
      - kind: unit
        ref: "flutter test test/providers/setlists_provider_test.dart test/features/setlists/setlist_detail_screen_test.dart test/features/tracks/track_list_screen_test.dart test/features/tracks/confirm_delete_track_dialog_test.dart test/features/tracks/create_track_screen_test.dart test/features/tracks/track_detail_screen_test.dart test/cache/cache_service_test.dart (93 tests)"
        status: pass
      - kind: other
        ref: "grep -rliE song across the 7 files (zero matches)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Phase-wide closing audit: zero 'song' references in lib/ or test/ except the deferred publicapi.yml Songs tag, lib/features/songs/ does not exist, flutter analyze clean, full flutter test suite green — closing all 4 ROADMAP Phase 16 success criteria"
    requirement: "RENAME-01"
    verification:
      - kind: other
        ref: "grep -rliE song lib test --include=*.dart --include=*.arb (excluding lib/api/publicapi.yml) — zero matches"
        status: pass
      - kind: other
        ref: "test ! -e lib/features/songs"
        status: pass
      - kind: other
        ref: "flutter analyze — No issues found!"
        status: pass
      - kind: unit
        ref: "flutter test (full suite, 461 tests)"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-08-27
status: complete
---

# Phase 16 Plan 02: Test-Fixture Song-to-Track Rename and Closing Audit Summary

**Renamed all 51 arbitrary "Song"-named sample track-title fixtures across 7 test files to their "Track" equivalents, then ran a full-tree audit confirming zero surviving "song" references anywhere in `lib/` or `test/` except the deferred `publicapi.yml` Songs tag, a clean `flutter analyze`, and a green 461-test `flutter test` suite.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-08-27T13:52:00Z
- **Completed:** 2026-08-27T14:00:39Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- `test/providers/setlists_provider_test.dart`: "Song One"/"Song Two" fixture titles -> "Track One"/"Track Two" (5 occurrences)
- `test/features/setlists/setlist_detail_screen_test.dart`: "Song One"/"Two"/"Three" fixtures and their matching `find.text` assertions -> "Track One"/"Two"/"Three" (19 occurrences)
- `test/features/tracks/track_list_screen_test.dart`: "Cached Song" fixtures and assertion -> "Cached Track" (7 occurrences)
- `test/features/tracks/confirm_delete_track_dialog_test.dart`: "My Song" `trackTitle` -> "My Track" (2 occurrences)
- `test/features/tracks/create_track_screen_test.dart`: "My Song" entered text, JSON fixture, and snackbar assertion argument -> "My Track" (4 occurrences)
- `test/features/tracks/track_detail_screen_test.dart`: bare "Song" fixtures -> "Track" (6 occurrences)
- `test/cache/cache_service_test.dart`: "Song One"/"Song Two" fixtures and result assertions -> "Track One"/"Track Two" (8 occurrences)
- Closing audit (Task 2, no source edits) confirmed: zero "song" references remain in `lib/` or `test/` except `lib/api/publicapi.yml`'s deferred `Songs` tag; `lib/features/songs/` does not exist; `flutter analyze` reports no issues; the full `flutter test` suite (461 tests) passes

## Task Commits

Each task was committed atomically:

1. **Task 1: Rename "Song"-named test fixture data to "Track" equivalents across 7 test files** - `0752bd0` (test)
2. **Task 2: Phase-wide closing audit — zero "song" references, full suite green, no stale artifacts** - no commit (verification-only task; performed zero source edits, per its own `<action>` spec)

_Note: this is a worktree-isolated parallel execution — no separate plan-metadata commit is made here; STATE.md/ROADMAP.md updates are owned by the orchestrator after the wave merges._

## Files Created/Modified
- `test/providers/setlists_provider_test.dart` - "Song One"/"Song Two" fixture titles renamed to "Track One"/"Track Two"
- `test/features/setlists/setlist_detail_screen_test.dart` - "Song One"/"Two"/"Three" fixtures and matching `find.text` assertions renamed to "Track" equivalents
- `test/features/tracks/track_list_screen_test.dart` - "Cached Song" fixtures and assertion renamed to "Cached Track"
- `test/features/tracks/confirm_delete_track_dialog_test.dart` - "My Song" `trackTitle` renamed to "My Track"
- `test/features/tracks/create_track_screen_test.dart` - "My Song" entered text, JSON fixture, and snackbar assertion argument renamed to "My Track"
- `test/features/tracks/track_detail_screen_test.dart` - bare "Song" fixtures renamed to "Track"
- `test/cache/cache_service_test.dart` - "Song One"/"Song Two" fixtures and result assertions renamed to "Track One"/"Track Two"

## Decisions Made
- Used targeted `sed` replacements per file (exact phrase matches: "Song One", "Song Two", "Song Three", "Cached Song", "My Song", bare `'Song'`) rather than a blanket `song`->`track` substitution, since each fixture literal and its matching assertion use the identical string — a single find/replace pass kept both in sync automatically with zero risk of touching non-title fields (artist, id, band name) or assertion structure.

## Deviations from Plan

None - plan executed exactly as written. Both tasks matched their `<action>` and `<acceptance_criteria>` blocks precisely; no Rule 1-4 auto-fixes were needed.

## Issues Encountered

None. The `NO_PROXY=127.0.0.1,localhost`/`no_proxy=127.0.0.1,localhost` environment workaround documented in Plan 16-01's Summary (required for `flutter_tester`'s localhost websocket to work in this sandbox) was applied proactively for both the targeted 7-file test run and the full-suite run; both completed without the 503 proxy-interception failure.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

RENAME-01 is fully closed: no file under `lib/` or `test/` contains "song" (case-insensitive) except `lib/api/publicapi.yml`'s explicitly deferred `Songs` tag (per D-04, untouched — Phase 17's API Contract Sync will address it), `lib/features/songs/` does not exist, `flutter analyze` is clean, and the full 461-test `flutter test` suite is green. Phase 17 can proceed against a fully Track-named client codebase.

---
*Phase: 16-track-terminology-rename*
*Completed: 2026-08-27*
