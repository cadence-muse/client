---
phase: quick-260827-uqv
plan: fix-a-bug-search-bar-in-setlists-says-se
subsystem: ui
tags: [flutter, i18n, l10n, gen-l10n, arb]

# Dependency graph
requires:
  - phase: Phase 17
    provides: Setlists tab search field wired to shared addSetlistTracksSearchHint l10n key
provides:
  - New setlistsTabSearchHint l10n key ("Search by name" / "Поиск по названию") scoped to the Setlists tab
  - Setlists tab search field now describes its actual search semantics (name only)
affects: [setlists, i18n]

# Actuals (#2632)
actuals:
  tokens: 1062
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - lib/l10n/app_en.arb
    - lib/l10n/app_ru.arb
    - lib/generated/app_localizations.dart
    - lib/generated/app_localizations_en.dart
    - lib/generated/app_localizations_ru.dart
    - lib/features/setlists/setlists_screen.dart
    - test/features/setlists/setlists_screen_test.dart

key-decisions:
  - "New key placed near setlistsTabEmptyTitle/setlistsTabEmptyDescription (not next to addSetlistTracksSearchHint) to match this screen's existing naming convention."
  - "No @setlistsTabSearchHint metadata block added, matching the precedent set by the existing addSetlistTracksSearchHint key (no metadata block either)."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "Setlists tab search field hint now reads 'Search by name' instead of the misleading 'Search by title or artist'"
    verification:
      - kind: unit
        ref: "test/features/setlists/setlists_screen_test.dart#renders a search TextField above the setlist list"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tracks tab and Add-tracks-to-setlist dialog search hints remain unchanged (still 'Search by title or artist')"
    verification:
      - kind: unit
        ref: "test/features/tracks/tracks_screen_test.dart (full suite)"
        status: pass
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#renders a search TextField with the title/artist hint above the track checklist"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-08-27
status: complete
---

# Quick Task 260827-uqv: Setlists search hint copy fix Summary

**Setlists tab search field now says "Search by name" via a new `setlistsTabSearchHint` l10n key, instead of the misleading shared "Search by title or artist" hint.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Added `setlistsTabSearchHint` ("Search by name" / "Поиск по названию") to both ARB source files, placed alongside the screen's other `setlistsTab*` keys.
- Regenerated all three generated l10n files via `flutter gen-l10n` (no hand-editing needed).
- Wired `setlists_screen.dart`'s search `TextField` hint to the new key; `tracks_screen.dart` and `add_setlist_tracks_dialog.dart` untouched and still use `addSetlistTracksSearchHint`.
- Updated the corresponding test assertion; full regression run across `setlists_screen_test.dart`, `tracks_screen_test.dart`, and `add_setlist_tracks_dialog_test.dart` (44 tests) plus the broader `test/features/setlists/` + `tracks_screen_test.dart` suite (112 tests) all pass. `flutter analyze` clean.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add setlistsTabSearchHint l10n key and wire it into the Setlists tab search field** - `feeff43` (fix)
2. **Task 2: Update the Setlists screen test to assert the new hint and confirm no regressions** - `d02b9a4` (test)

_Docs commit (SUMMARY.md/STATE.md) handled separately by the orchestrator._

## Files Created/Modified
- `lib/l10n/app_en.arb` - Added `setlistsTabSearchHint`: "Search by name"
- `lib/l10n/app_ru.arb` - Added `setlistsTabSearchHint`: "Поиск по названию"
- `lib/generated/app_localizations.dart` - Regenerated abstract getter via `flutter gen-l10n`
- `lib/generated/app_localizations_en.dart` - Regenerated concrete getter
- `lib/generated/app_localizations_ru.dart` - Regenerated concrete getter
- `lib/features/setlists/setlists_screen.dart` - Search `TextField` hintText now uses `l10n.setlistsTabSearchHint`
- `test/features/setlists/setlists_screen_test.dart` - Assertion updated to `tester.strings.setlistsTabSearchHint`

## Decisions Made
- Placed the new key near `setlistsTabEmptyTitle`/`setlistsTabEmptyDescription` per plan instruction, keeping this screen's keys grouped together rather than next to the semantically different `addSetlistTracksSearchHint`.
- Skipped adding an `@setlistsTabSearchHint` metadata block, matching the existing `addSetlistTracksSearchHint` key's precedent (no metadata block).

## Deviations from Plan

None - plan executed exactly as written. `flutter gen-l10n` was available in this environment and worked directly (no hand-editing of generated files required).

## Issues Encountered

None. One transient false-negative during verification: a `grep` invocation using a relative path right after a concurrent `flutter test` run appeared to show stale (pre-edit) file content; re-running the same check with an absolute path and via the `Read` tool confirmed the file and git history were correct all along (git diff against HEAD was clean). No actual regression occurred.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Resolves the non-blocking Phase 17 review finding (17-REVIEW.md WR-02, logged in STATE.md Blockers/Concerns) — that entry should be considered closed by this quick task.
- No blockers introduced for Phase 18 (Metronome Tool), which is unrelated to this change.

---
*Phase: quick-260827-uqv*
*Completed: 2026-08-27*

## Self-Check: PASSED

All created/modified files present on disk in the worktree; both task commits (`feeff43`, `d02b9a4`) confirmed in git log.
