---
phase: 06-foundation-info-settings-polish
plan: 03
subsystem: ui
tags: [flutter, riverpod, icons, material3]

requires:
  - phase: 06-01
    provides: "TrackListItem.key field added to the tracks provider/cache layer"
provides:
  - "Track list row icon pattern (SizedBox-constrained trailing Row) reused by Plan 06-04 for Setlists"
  - "Track detail unprefixed icon+value row pattern (duration/key) reused by Plan 06-04"
  - "Notes tap-to-expand SnackBar pattern for truncated long-text fields"
affects: [06-04-setlist-metadata-icons]

actuals:
  tokens: 2240
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Trailing icon-row pattern on list screens: SizedBox(width: N, child: Row(mainAxisSize: min, mainAxisAlignment: end, ...)) with conditional spread (if (x != null) ...[...]) for optional fields"
    - "Detail-screen unprefixed icon+value Row (Icon + SizedBox(width: 8) + Text) replacing label-prefixed Text for icon-carried meaning"
    - "Tap-to-expand pattern: GestureDetector wrapping a maxLines/ellipsis Text, showing the full untruncated string via ScaffoldMessenger SnackBar on tap"

key-files:
  created: []
  modified:
    - lib/features/tracks/track_list_screen.dart
    - lib/features/tracks/track_detail_screen.dart
    - test/features/tracks/track_list_screen_test.dart
    - test/features/tracks/track_detail_screen_test.dart

key-decisions:
  - "Test for tap-to-expand SnackBar asserts via find.descendant(of: find.byType(SnackBar), matching: find.text(...)) rather than a bare find.text(...) findsOneWidget, because the same untruncated notes string is also present (as Text.data) in the still-mounted body row underneath the truncation — a bare findsOneWidget would (and did, on first run) find both and fail with 'too many'."

patterns-established:
  - "Icon-row trailing pattern (list) and unprefixed icon+value row pattern (detail) are the template Plan 06-04 mirrors for Setlist location/duration icons."

requirements-completed: [TRACK-07]

coverage:
  - id: D1
    description: "Track list rows show a key icon+value only when key is present, and a duration icon+value always"
    requirement: "TRACK-07"
    verification:
      - kind: unit
        ref: "test/features/tracks/track_list_screen_test.dart#a cached track with a key shows the music_note icon, key value, and timer icon"
        status: pass
      - kind: unit
        ref: "test/features/tracks/track_list_screen_test.dart#a cached track with no key entry omits the music_note icon but still shows the timer icon"
        status: pass
    human_judgment: false
  - id: D2
    description: "Track detail screen shows unprefixed icon rows for duration (always) and key (when present), and a notes row that truncates to 2 lines with tap-to-expand SnackBar"
    requirement: "TRACK-07"
    verification:
      - kind: unit
        ref: "test/features/tracks/track_detail_screen_test.dart#a full BandTrack response renders title/artist/duration/tempo/key/notes"
        status: pass
      - kind: unit
        ref: "test/features/tracks/track_detail_screen_test.dart#tapping the notes row shows the full untruncated notes text in a SnackBar"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-21
status: complete
---

# Phase 06 Plan 03: Track List/Detail Metadata Icons Summary

**Track list rows and the Track detail screen both show icon-based key/duration/notes indicators (Icons.music_note/Icons.timer/Icons.notes), replacing prefixed "Duration:"/"Key:"/"Notes:" text, with tap-to-expand for long notes.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-08-21
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Track list trailing area now shows a key icon+value (only when `track['key']` is present) followed by a duration icon+value (always), inside a width-constrained trailing Row
- Track detail screen replaced label-prefixed `Text('Duration: ...')`/`Text('Key: ...')` with unprefixed icon+value Rows; Tempo left untouched (out of TRACK-07 scope)
- Track detail notes now render with a notes icon, truncate to 2 lines with an ellipsis, and expand to the full untruncated text in a SnackBar on tap
- Added/updated 6 tests across both screens' test files; all 47 tests in `test/features/tracks/` pass and `flutter analyze` reports zero issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Track list -- key + duration icon row** - `b52a4b6` (feat)
2. **Task 2: Track detail -- icon rows for duration/key, notes with truncation + tap-to-expand** - `1a5ce2d` (feat)

## Files Created/Modified
- `lib/features/tracks/track_list_screen.dart` - Trailing `Text` duration replaced with a `SizedBox(width: 130)`-constrained `Row` showing key icon+value (conditional) and duration icon+value (always)
- `lib/features/tracks/track_detail_screen.dart` - Duration/key `Text` rows replaced with unprefixed `Icon` + `Text` `Row`s; notes row wrapped in `GestureDetector` showing a `SnackBar` with the full text on tap, truncated to 2 lines otherwise
- `test/features/tracks/track_list_screen_test.dart` - Added 2 tests: key-present row shows music_note+text+timer; key-absent row omits music_note but keeps timer
- `test/features/tracks/track_detail_screen_test.dart` - Updated the full-response test's assertions from prefixed strings (`'Duration: 3:45'`, `'Key: C'`, `'Notes: Some notes'`) to bare values plus icon presence assertions; added a new test tapping the notes icon and asserting the full long-notes string appears inside the `SnackBar`

## Decisions Made
- The new tap-to-expand test asserts via `find.descendant(of: find.byType(SnackBar), matching: find.text(longNotes))` instead of a bare `find.text(longNotes)`, because the body's truncated notes `Text` widget still carries the full string as its `data` (Flutter's `maxLines`/`overflow` only affect rendering, not the widget's text value) — a bare assertion found 2 matching widgets and failed. This is a corrected test-assertion detail, not a change to production behavior; the plan's intent (full text visible in the SnackBar) is preserved.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the tap-to-expand test's widget finder to avoid a false ambiguous-match failure**
- **Found during:** Task 2 (writing the tap-to-expand test)
- **Issue:** The plan's literal instruction (`find.text(<the full long notes string>)` `findsOneWidget`) fails because the already-rendered, truncated notes `Text` widget in the body has the same full string as its `data` property, so two widgets match the same text.
- **Fix:** Scoped the finder to the `SnackBar` ancestor: `find.descendant(of: find.byType(SnackBar), matching: find.text(longNotes))`, `findsOneWidget`.
- **Files modified:** test/features/tracks/track_detail_screen_test.dart
- **Verification:** `flutter test test/features/tracks/track_detail_screen_test.dart` passes (8/8).
- **Committed in:** 1a5ce2d (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix in test assertion)
**Impact on plan:** No production-code impact; the fix is scoped entirely to test-assertion precision. No scope creep.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Establishes the icon-row display pattern (trailing `SizedBox`-constrained `Row` on list screens, unprefixed icon+text rows on detail screens, tap-to-expand for truncated long text) that Plan 06-04 mirrors for Setlists (location/duration icons).
- No blockers.

---
*Phase: 06-foundation-info-settings-polish*
*Completed: 2026-08-21*
