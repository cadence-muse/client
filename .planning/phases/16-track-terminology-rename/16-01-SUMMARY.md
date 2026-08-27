---
phase: 16-track-terminology-rename
plan: 01
subsystem: ui
tags: [flutter, dart, l10n, arb, gen-l10n, riverpod]

# Dependency graph
requires: []
provides:
  - "lib/features/tracks/tracks_screen.dart (TracksScreen moved from lib/features/songs/, no content change)"
  - "homeAddTrackButton ARB key/generated getter (EN 'Add Track', RU 'Добавить трек'), replacing homeAddSongButton"
  - "lib/features/songs/ directory fully removed from the repo"
affects: [17-api-contract-sync]

# Actuals (#2632)
actuals:
  tokens: 2673
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - lib/features/tracks/tracks_screen.dart
    - lib/navigation/root_scaffold.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_ru.arb
    - lib/generated/app_localizations.dart
    - lib/generated/app_localizations_en.dart
    - lib/generated/app_localizations_ru.dart
    - lib/features/home/home_screen.dart
    - lib/features/home/band_picker_sheet.dart
    - test/features/tracks/tracks_screen_test.dart
    - test/regression/offline_trust_regression_test.dart
    - test/features/home/home_screen_test.dart

key-decisions:
  - "flutter test's default reporter interleaves 'in-progress' status lines under concurrency, making the same test name appear to print multiple times mid-run — verified this is a reporter artifact, not duplicate execution, by re-running each affected file individually and confirming a single pass per test with a matching final count."
  - "Environment's HTTP_PROXY/HTTPS_PROXY was intercepting flutter_tester's localhost websocket handshake (503 from the proxy), causing every flutter test invocation to fail at load time regardless of code changes; setting NO_PROXY=127.0.0.1,localhost (no_proxy too) resolved it. Not a plan deviation — an execution-environment prerequisite, undone at the shell level and not committed to any file."

patterns-established: []

requirements-completed: [RENAME-01]

coverage:
  - id: D1
    description: "lib/features/songs/ is gone; TracksScreen lives at lib/features/tracks/tracks_screen.dart, wired through root_scaffold.dart and both dependent tests"
    requirement: "RENAME-01"
    verification:
      - kind: unit
        ref: "test/features/tracks/tracks_screen_test.dart (8 tests)"
        status: pass
      - kind: unit
        ref: "test/regression/offline_trust_regression_test.dart (3 tests)"
        status: pass
      - kind: other
        ref: "flutter analyze lib/navigation/root_scaffold.dart lib/features/tracks/tracks_screen.dart test/features/tracks/tracks_screen_test.dart test/regression/offline_trust_regression_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "homeAddSongButton ARB key renamed to homeAddTrackButton (EN 'Add Track', RU 'Добавить трек'), regenerated into lib/generated/app_localizations*.dart with no stale getter, and every 'Add Song' comment/string in the Home feature and its test swept to 'Add Track'"
    requirement: "RENAME-01"
    verification:
      - kind: unit
        ref: "test/features/home/home_screen_test.dart (12 tests)"
        status: pass
      - kind: other
        ref: "grep -rliE song lib/l10n lib/generated/app_localizations*.dart lib/features/home (zero matches)"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-08-27
status: complete
---

# Phase 16 Plan 01: Songs-to-Tracks Directory Move and homeAddSongButton Rename Summary

**Moved `lib/features/songs/tracks_screen.dart` into `lib/features/tracks/`, and renamed the ARB key `homeAddSongButton` to `homeAddTrackButton` (regenerating localization output), eliminating the last "song" references outside `publicapi.yml`.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-08-27T13:45:02Z
- **Completed:** 2026-08-27T13:52:46Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- `lib/features/songs/` no longer exists on disk; `TracksScreen` (content unchanged) now lives at `lib/features/tracks/tracks_screen.dart`, wired through `root_scaffold.dart`'s import and both of its dependent test files
- `homeAddSongButton` ARB key renamed to `homeAddTrackButton` in `app_en.arb`/`app_ru.arb` ("Add Track" / "Добавить трек"), with `flutter gen-l10n` regenerating all three `lib/generated/app_localizations*.dart` files and removing the stale getter
- Every "Add Song" comment/string swept to "Add Track" across `home_screen.dart`, `band_picker_sheet.dart`, and `home_screen_test.dart` (including the `addSong` local variable renamed to `addTrack`)
- Zero "song" references remain in `lib/l10n/`, the generated localization files, or `lib/features/home/`

## Task Commits

Each task was committed atomically:

1. **Task 1: Merge lib/features/songs/ into lib/features/tracks/, wired through navigation and its dependent tests** - `b214972` (feat)
2. **Task 2: Rename homeAddSongButton ARB key to homeAddTrackButton and sweep "Add Song" comments** - `b03651d` (feat)

_Note: this is a worktree-isolated parallel execution — no separate plan-metadata commit is made here; STATE.md/ROADMAP.md updates are owned by the orchestrator after the wave merges._

## Files Created/Modified
- `lib/features/tracks/tracks_screen.dart` - moved from `lib/features/songs/tracks_screen.dart`, content unchanged
- `lib/navigation/root_scaffold.dart` - import updated to `../features/tracks/tracks_screen.dart`
- `lib/l10n/app_en.arb` / `lib/l10n/app_ru.arb` - `homeAddSongButton` -> `homeAddTrackButton`
- `lib/generated/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart` - regenerated via `flutter gen-l10n`
- `lib/features/home/home_screen.dart` - button now reads `l10n.homeAddTrackButton`; "Add Song" comments swept to "Add Track"
- `lib/features/home/band_picker_sheet.dart` - doc comment "Add Song" -> "Add Track"
- `test/features/tracks/tracks_screen_test.dart` - import path updated
- `test/regression/offline_trust_regression_test.dart` - `cachedScreens` path literal updated
- `test/features/home/home_screen_test.dart` - `homeAddSongButton` references, `addSong` variable, and description strings renamed to Track equivalents

## Decisions Made
- No architectural decisions — pure rename/cleanup as scoped. See `key-decisions` in frontmatter for two execution-environment notes (test reporter interleaving artifact, and a local `NO_PROXY` fix required to run `flutter test` at all in this sandboxed environment — neither is a code change).

## Deviations from Plan

None - plan executed exactly as written. Both tasks matched their `<action>` and `<acceptance_criteria>` blocks precisely; no Rule 1-4 auto-fixes were needed.

## Issues Encountered

The sandboxed execution environment's `HTTP_PROXY`/`HTTPS_PROXY` env vars intercepted `flutter_tester`'s localhost websocket handshake, causing every `flutter test` invocation to fail at load time with a `WebSocketException: ... HTTP status code: 503`, regardless of code correctness. Confirmed this was environment-wide (reproduced on an untouched test file) rather than caused by this plan's changes, then resolved by exporting `NO_PROXY=127.0.0.1,localhost` (and lowercase `no_proxy`) for the `flutter test` invocations. This is a shell-session-local fix, not a code or config change, and is not part of the committed diff.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`lib/features/songs/` is fully gone and `homeAddTrackButton` is the live key everywhere it's used, closing out RENAME-01's client-code rename sweep for this plan's scope (directory move + last surviving user-facing "Add Song" string). Phase 17 (API Contract Sync) can proceed against the renamed files without needing to touch this rename again. `lib/api/publicapi.yml`'s `Songs` tag is untouched per this plan's prohibition — still explicitly deferred to Phase 17.

---
*Phase: 16-track-terminology-rename*
*Completed: 2026-08-27*

## Self-Check: PASSED

- FOUND: lib/features/tracks/tracks_screen.dart
- FOUND: lib/features/songs removed
- FOUND: .planning/phases/16-track-terminology-rename/16-01-SUMMARY.md
- FOUND: commit b214972
- FOUND: commit b03651d
- FOUND: commit 62ee2aa
