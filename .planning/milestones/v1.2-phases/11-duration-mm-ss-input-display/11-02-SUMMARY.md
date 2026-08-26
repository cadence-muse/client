---
phase: 11-duration-mm-ss-input-display
plan: 02
subsystem: ui
tags: [flutter, dart, formatting, duration, setlists]

# Dependency graph
requires:
  - phase: 11-duration-mm-ss-input-display (11-01, parallel wave 1)
    provides: nothing directly consumed — this plan reuses the pre-existing (pre-phase) DurationFormatting.asMinutesSeconds extension from lib/features/tracks/track_formatting.dart, unmodified by either plan
provides:
  - Unified mm:ss duration format across every setlist screen (list rows, detail rows, setlist totals with track counts)
  - Retirement of the words-based DurationFormatting.asMinutesAndSeconds extension in setlist_formatting.dart
affects: [11-duration-mm-ss-input-display, any future setlist/track duration display work]

# Actuals (#2632)
actuals:
  tokens: 8500
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Duration display consolidation: retire a feature-local words-format extension in favor of importing the already-proven track_formatting.dart's asMinutesSeconds, rather than maintaining two parallel duration formatters"

key-files:
  created: []
  modified:
    - lib/features/setlists/setlist_formatting.dart
    - lib/features/setlists/setlist_list_screen.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - test/features/setlists/setlists_screen_test.dart
    - test/features/setlists/setlist_list_screen_test.dart
    - test/features/setlists/setlist_detail_screen_test.dart

key-decisions:
  - "Applied deviation Rule 3 (auto-fix blocking issue): the plan split lib changes across two tasks (setlist_formatting.dart in Task 1, the two screens in Task 2), but deleting the asMinutesAndSeconds extension in Task 1 breaks compilation of setlist_list_screen.dart/setlist_detail_screen.dart (Task 2's files) until they're also migrated — both files reference the deleted extension. Implemented both screens' lib edits before running Task 1's verify command (so it could compile), then staged and committed strictly per the plan's task file lists (Task 1: setlist_formatting.dart + its test; Task 2: the two screens + their tests) — commit history still matches the plan's task boundaries exactly."

requirements-completed: [DUR-03]

coverage:
  - id: D1
    description: "setlist_formatting.dart's tracksAndDuration() and the words-based asMinutesAndSeconds extension retired; unified mm:ss format via asMinutesSeconds"
    requirement: "DUR-03"
    verification:
      - kind: unit
        ref: "test/features/setlists/setlists_screen_test.dart#populated cross-band list renders each row's band-name subtitle, name title, and tracksAndDuration trailing text"
        status: pass
    human_judgment: false
  - id: D2
    description: "setlist_list_screen.dart and setlist_detail_screen.dart render all duration values (list row, setlist total, per-track in both edit-mode and read-only track lists) via asMinutesSeconds, with the null-fallback ('—') preserved for missing per-track durations"
    requirement: "DUR-03"
    verification:
      - kind: integration
        ref: "test/features/setlists/setlist_list_screen_test.dart#setlist list shows duration text regardless of track count"
        status: pass
      - kind: integration
        ref: "test/features/setlists/setlist_detail_screen_test.dart#a full BandSetlist response renders name/location/date/duration/tracks"
        status: pass
      - kind: integration
        ref: "flutter test test/features/setlists/ (full setlists suite, 85 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "mm:ss duration text does not overflow/truncate at typical mobile column widths, including unbounded-minute values like '120:30' (backstop truth)"
    requirement: "DUR-03"
    verification: []
    human_judgment: true
    rationale: "Layout overflow/truncation at real device widths requires visual verification — no widget test asserts pixel-level text overflow for arbitrary duration string lengths; the existing SizedBox(width: 150) trailing constraint in setlist_list_screen.dart is unchanged by this plan, so any overflow risk is pre-existing and out of this plan's scope, but confirming it renders cleanly needs a human look."

duration: 12min
completed: 2026-08-25
status: complete
---

# Phase 11 Plan 02: Setlist Duration Format Unification Summary

**Retired setlist_formatting.dart's words-based `asMinutesAndSeconds` extension; every setlist screen (list rows, detail rows, setlist totals) now renders duration via the pre-existing `track_formatting.dart` `asMinutesSeconds` mm:ss extension.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-25T10:37:00Z
- **Completed:** 2026-08-25T10:49:48Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Deleted the `DurationFormatting.asMinutesAndSeconds` extension from `setlist_formatting.dart`; `tracksAndDuration()` now imports and calls `track_formatting.dart`'s `asMinutesSeconds`
- Migrated `setlist_list_screen.dart`'s row-trailing duration text to `asMinutesSeconds`
- Migrated all three `setlist_detail_screen.dart` duration call sites (setlist total, edit-mode per-track, read-only per-track) to `asMinutesSeconds`, preserving the `?? '—'` null-fallback for missing track durations exactly
- Zero remaining references to the retired words-based format anywhere in `lib/` (confirmed via `grep -rn "asMinutesAndSeconds" lib/`)

## Task Commits

Each task was committed atomically:

1. **Task 1: Retire asMinutesAndSeconds, migrate tracksAndDuration() to unified mm:ss** - `55960fa` (feat)
2. **Task 2: Migrate setlist_list_screen.dart and setlist_detail_screen.dart duration displays to asMinutesSeconds** - `91b46ef` (feat)

## Files Created/Modified
- `lib/features/setlists/setlist_formatting.dart` - Removed `asMinutesAndSeconds` extension; `tracksAndDuration()` now uses `asMinutesSeconds` via a new import
- `lib/features/setlists/setlist_list_screen.dart` - Duration trailing text now uses `asMinutesSeconds`
- `lib/features/setlists/setlist_detail_screen.dart` - Setlist total and both per-track duration call sites now use `asMinutesSeconds`, null-fallback unchanged
- `test/features/setlists/setlists_screen_test.dart` - Duration assertions updated to mm:ss (`'42:35'`, `'3:20'`)
- `test/features/setlists/setlist_list_screen_test.dart` - Duration assertions updated to mm:ss (`'10:00'`, `'1:00'`, `'42:35'`)
- `test/features/setlists/setlist_detail_screen_test.dart` - Duration assertions updated to mm:ss (`'42:35'`, `'3:45'`, `'3:20'`, `'0:00'`)

## Decisions Made
- Applied deviation Rule 3 to resolve a cross-task compile dependency the plan didn't call out: Task 1 deletes the extension that Task 2's files (`setlist_list_screen.dart`, `setlist_detail_screen.dart`) still reference, so Task 1's own `<verify>` command cannot compile until Task 2's lib edits also land. Implemented both screens' code changes before running Task 1's verify, then staged/committed strictly along the plan's declared per-task file boundaries — the resulting two commits match the plan's task structure exactly, only the *order of implementation* (not commit content) was adjusted.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Cross-task compile dependency between Task 1 and Task 2**
- **Found during:** Task 1 (running its `<verify>` command)
- **Issue:** Task 1 deletes `DurationFormatting.asMinutesAndSeconds` from `setlist_formatting.dart`, but `setlist_list_screen.dart` and `setlist_detail_screen.dart` (Task 2's files) still called `.asMinutesAndSeconds` directly on `int`, which only resolved because the extension was previously imported transitively. After Task 1's deletion, both screens failed to compile, which broke `setlists_screen_test.dart`'s widget tree (it renders `SetlistsScreen` -> `SetlistDetailScreen`).
- **Fix:** Implemented Task 2's screen migrations (import `track_formatting.dart`, swap `.asMinutesAndSeconds` -> `.asMinutesSeconds` at all 4 call sites) before finalizing Task 1's verify, so the whole `lib/` tree compiled. Commits were still split and staged exactly along the plan's per-task file lists.
- **Files modified:** `lib/features/setlists/setlist_list_screen.dart`, `lib/features/setlists/setlist_detail_screen.dart` (implemented early, committed under Task 2 as planned)
- **Verification:** `flutter test test/features/setlists/setlists_screen_test.dart` (10/10 pass) after both tasks' lib changes were in place; `flutter test test/features/setlists/` (85/85 pass) after both commits landed
- **Committed in:** `91b46ef` (Task 2 commit, per plan's file assignment)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep — the fix was strictly the migration work Task 2 already specified, just implemented earlier in sequence than the plan's task ordering implied. Commit boundaries and content match the plan exactly.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- DUR-03 is complete: `grep -rn "asMinutesAndSeconds" lib/` returns zero matches; every setlist screen renders duration via `asMinutesSeconds`.
- `flutter test test/features/setlists/` is green (85/85).
- Spot regression check on unmodified `test/features/tracks/track_list_screen_test.dart` and `test/features/tracks/track_detail_screen_test.dart` also passes (18/18) — no regression from the shared `asMinutesSeconds` extension.
- Once `11-01-PLAN.md` (parallel wave 1, independent) also lands, the plan's `<verification>` full-suite check (`flutter test`) should be run to confirm phase-level green.
- No blockers for the remaining Phase 11 work.

---
*Phase: 11-duration-mm-ss-input-display*
*Completed: 2026-08-25*
