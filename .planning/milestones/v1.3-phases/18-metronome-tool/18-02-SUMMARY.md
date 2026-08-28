---
phase: 18-metronome-tool
plan: 02
subsystem: metronome
tags: [flutter, custom-painter, gesture, drag-dial, i18n]

requires:
  - phase: 18-metronome-tool
    provides: "Metronome playback engine (audioplayers + Stopwatch/Timer beat scheduler), MetronomeState Riverpod family provider with setBpm's clamped [40,300] choke point, MetronomeScreen scaffold with a plain BPM Text stub"
provides:
  - "MetronomeDial: large round drag-to-rotate BPM selector (CustomPainter + GestureDetector, greenfield UI pattern for this codebase)"
  - "angleToBpm(degrees): pure, directly-testable 270-degree-sweep angle-to-BPM mapping function with dead-zone clamping"
  - "Quick-adjust +/-1/+/-5 IconButton row, bound-disabled at 40/300, routed through the same setBpm choke point as the dial"
  - "4 new ARB tooltip keys (en-dash BPM deltas), regenerated AppLocalizations"
affects: []

actuals:
  tokens: 7022
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "CustomPainter + GestureDetector (onPanStart AND onPanUpdate wired to the same handler) for a drag/rotate dial control -- first such pattern in this codebase, reusable for any future rotary/dial UI"
    - "angleToBpm as a standalone top-level pure function, kept separate from the widget's raw atan2/normalization code, so the angle-to-value mapping is unit-testable without pumping a widget tree"
    - "Widget tests reading a CustomPainter-rendered numeric value via the owning StatelessWidget's own field (tester.widget<MetronomeDial>(...).bpm), not find.text() -- canvas-painted text is invisible to Flutter's Text-widget finders"

key-files:
  created:
    - lib/features/metronome/metronome_dial.dart
    - test/features/metronome/metronome_dial_test.dart
    - test/features/metronome/metronome_screen_test.dart
  modified:
    - lib/features/metronome/metronome_screen.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_ru.arb
    - lib/generated/app_localizations.dart
    - lib/generated/app_localizations_en.dart
    - lib/generated/app_localizations_ru.dart
    - test/integration/metronome_e2e_test.dart

key-decisions:
  - "The dial's BPM number/unit label is painted directly onto the CustomPainter's Canvas via TextPainter, not rendered as a Flutter Text widget -- matches the plan's explicit painter constructor signature (bpm/ringColor/numberStyle/unitStyle only, no BuildContext available inside paint()). Consequence: widget tests read the value via MetronomeDial.bpm (the owning widget's own field), not find.text() -- documented in both new test files and propagated as a required fix to the pre-existing e2e test below."
  - "'BPM' unit label text is a hardcoded literal string inside the painter (not threaded through as a localized parameter) -- matches the existing i18n precedent that metronomeBpmUnitLabel/commonTempoLabel already render identically as literal 'BPM' in both English and Russian ARB files, so no localization value would differ."

patterns-established:
  - "Dial diameter response formula min(MediaQuery width * 0.8, 320.0), verified by widget tests at two MediaQuery sizes reading CustomPaint.size directly -- reusable for any future responsive square control."

requirements-completed: [METR-04]

coverage:
  - id: D1
    description: "angleToBpm pure function: 270-degree sweep, [40,300] clamp, dead-zone-safe at both sides of the atan2 discontinuity (D-06, RESEARCH.md Pitfall 4)"
    requirement: METR-04
    verification:
      - kind: unit
        ref: "test/features/metronome/metronome_dial_test.dart#angleToBpm group (Tests 1-6)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Dragging the dial updates the displayed BPM live, on every onPanUpdate frame, before gesture completion (D-07)"
    requirement: METR-04
    verification:
      - kind: widget
        ref: "test/features/metronome/metronome_dial_test.dart#dragging updates the displayed BPM live..."
        status: pass
    human_judgment: false
  - id: D3
    description: "Dial diameter equals min(80% screen width, 320px), square, at both a narrow and a wide MediaQuery size"
    requirement: METR-04
    verification:
      - kind: widget
        ref: "test/features/metronome/metronome_dial_test.dart#dial diameter equals min(width*0.8, 320)..."
        status: pass
      - kind: widget
        ref: "test/features/metronome/metronome_dial_test.dart#dial diameter caps at 320 on a wide ~800px surface"
        status: pass
    human_judgment: false
  - id: D4
    description: "Quick-adjust +/-1/+/-5 buttons change BPM by exactly that delta and disable correctly at the 40/300 bounds"
    requirement: METR-04
    verification:
      - kind: widget
        ref: "test/features/metronome/metronome_screen_test.dart#tapping +1/+5/-1/-5 changes BPM by exactly that delta"
        status: pass
      - kind: widget
        ref: "test/features/metronome/metronome_screen_test.dart#at bpm == 40, -1 and -5 are disabled..."
        status: pass
      - kind: widget
        ref: "test/features/metronome/metronome_screen_test.dart#at bpm == 300, +1 and +5 are disabled..."
        status: pass
    human_judgment: false
  - id: D5
    description: "Quick-adjust button tooltips match UI-SPEC's exact copy (en-dash, not hyphen-minus)"
    requirement: METR-04
    verification:
      - kind: widget
        ref: "test/features/metronome/metronome_screen_test.dart#each button tooltip matches the exact UI-SPEC copy"
        status: pass
    human_judgment: false
  - id: D6
    description: "On-device drag feel, gesture responsiveness/sensitivity curve, and visual dial appearance (styling within Claude's discretion)"
    verification: []
    human_judgment: true
    rationale: "Automated widget tests exercise the gesture math and callback wiring deterministically (via TestGesture) but cannot judge subjective drag responsiveness/feel or the ring/typography's visual appearance on a real device -- requires human sign-off, same as Plan 18-01's D4 deferred the analogous on-device audio-visual sync feel."
duration: ~35min
completed: 2026-08-28
status: complete
---

# Phase 18 Plan 2: Metronome Dial + Quick-Adjust Buttons Summary

**Large round drag-to-rotate BPM dial (CustomPainter + GestureDetector, 270-degree sweep clamped to [40,300]) replacing Plan 18-01's plain BPM-number stub, plus flanking +/-1/+/-5 quick-adjust buttons -- both routed through the existing setBpm clamp choke point.**

## Performance
- **Duration:** ~35min
- **Started:** 2026-08-28T06:15:00Z (approx, session continuation)
- **Completed:** 2026-08-28T06:50:10Z
- **Tasks:** 2
- **Files modified:** 10 (3 created, 7 modified)

## Accomplishments
- Built `MetronomeDial` (D-05): a greenfield `CustomPainter` + `GestureDetector` drag/rotate control -- no prior dial/drag pattern existed anywhere in this codebase. `angleToBpm(degrees)` is a standalone pure function covering all 6 of the plan's specified behavior cases, including both sides of the raw `atan2` discontinuity inside the dial's dead zone (RESEARCH.md Pitfall 4).
- Wired both `onPanStart` and `onPanUpdate` to the same handler so the dial jumps to the touch-down angle immediately and updates live on every drag frame (D-07), verified by a widget test asserting the rendered BPM changes mid-gesture, before `gesture.up()`.
- Verified the dial's responsive sizing formula (`min(80% screen width, 320px)`, square) at two different `MediaQuery` sizes, confirming the 320px cap actually clamps on a wide surface.
- Added the 4-button quick-adjust row (`[-5, -1, +1, +5]`, D-05/METR-04), sharing `Icons.remove`/`Icons.add` between the ±5/±1 pairs and differentiating them by position, `iconSize` (28 vs 20), and tooltip text -- every button routes through `notifier.setBpm`, the same clamped `[40,300]` choke point the dial itself uses.
- Added 4 new ARB tooltip keys with the UI-SPEC's exact en-dash copy (`–5 BPM`, not a hyphen-minus), regenerated via `flutter gen-l10n`.
- Combined with Plan 18-01, all four phase requirements (METR-01 through METR-04) and all 11 CONTEXT.md decisions (D-01 through D-11) are now implemented and test-covered.

## Task Commits
1. **Task 1: Drag-to-rotate BPM dial (METR-04, D-05, D-06, D-07)** - `3586d05` (feat)
2. **Task 2: Quick-adjust +/-1 and +/-5 BPM buttons (METR-04)** - `79c4585` (feat)

**Plan metadata:** commit follows this SUMMARY.md's own commit below.

## Files Created/Modified
- `lib/features/metronome/metronome_dial.dart` - `angleToBpm(degrees)` pure function, `MetronomeDialPainter` (CustomPainter drawing the ring + BPM number/unit label), `MetronomeDial` (StatelessWidget wrapping the drag gesture)
- `lib/features/metronome/metronome_screen.dart` - Swapped the plain BPM `Text` pair for `MetronomeDial`; added `_buildQuickAdjustRow` with the 4 bound-disabled IconButtons
- `lib/l10n/app_en.arb`, `lib/l10n/app_ru.arb` - 4 new tooltip keys (`metronomeMinus5Tooltip`/`metronomeMinus1Tooltip`/`metronomePlus1Tooltip`/`metronomePlus5Tooltip`)
- `lib/generated/app_localizations*.dart` - Regenerated via `flutter gen-l10n` (tracked, not gitignored, in this repo)
- `test/features/metronome/metronome_dial_test.dart` - 6 `angleToBpm` behavior tests + 3 widget tests (live drag update, diameter at 2 sizes)
- `test/features/metronome/metronome_screen_test.dart` - Delta/bound/tooltip coverage for the quick-adjust buttons
- `test/integration/metronome_e2e_test.dart` - Fixed a pre-existing `find.text('120')` assertion broken by Task 1's Text-to-CustomPainter swap (see Deviations below)

## Decisions Made
- **Canvas-painted BPM number, not a `Text` widget:** the plan's `MetronomeDialPainter` constructor signature (`bpm`, `ringColor`, `numberStyle`, `unitStyle` -- no `BuildContext`) required painting the number/unit label directly via `TextPainter` inside `paint()`. This means the rendered value is invisible to `find.text()` in widget tests -- all three affected test files (two new, one pre-existing) instead read `MetronomeDial.bpm` off the widget itself via `tester.widget<MetronomeDial>(...)`.
- **Literal `'BPM'` string in the painter, not a threaded localized parameter:** matches the established precedent that `metronomeBpmUnitLabel`/`commonTempoLabel` already render identically as `'BPM'` in both English and Russian ARB files -- no localization value would ever differ, so no parameter was needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pre-existing e2e test's `find.text('120')` broken by the Task-1-mandated widget swap**
- **Found during:** Full-suite regression run (`flutter test`) after Task 2
- **Issue:** `test/integration/metronome_e2e_test.dart` (written in Plan 18-01, not in this plan's `files_modified` list) asserted `find.text('120')` against the old plain-`Text` BPM stub. Task 1's explicit, plan-mandated swap to a `CustomPainter`-rendered BPM number broke this assertion -- a direct regression caused by this plan's own required change, not a pre-existing unrelated issue.
- **Fix:** Replaced the assertion with `expect(tester.widget<MetronomeDial>(find.byType(MetronomeDial)).bpm, 120)`, matching the pattern established in this plan's own new test files.
- **Files modified:** `test/integration/metronome_e2e_test.dart`
- **Verification:** `flutter test test/integration/metronome_e2e_test.dart` passes; full-suite `flutter test` passes (510/510).
- **Commit:** `79c4585` (bundled into Task 2's commit, since it was discovered during Task 2's regression check)

## Issues Encountered
None beyond the one deviation documented above.

## User Setup Required
None -- no external service configuration required.

## Next Phase Readiness
Phase 18 (Metronome Tool) is complete after this plan: METR-01 through METR-04 are all implemented and test-covered across Plans 18-01 and 18-02. `flutter analyze` is clean and the full test suite (510 tests) passes. On-device drag feel and dial visual appearance (D6 above) are flagged for human sign-off, matching Plan 18-01's analogous audio-visual-sync deferral -- both are UI/UX judgment calls outside what an automated widget test can assess, not blocking gates for this plan.

---
*Phase: 18-metronome-tool*
*Completed: 2026-08-28*

## Self-Check: PASSED

- FOUND: lib/features/metronome/metronome_dial.dart
- FOUND: test/features/metronome/metronome_dial_test.dart
- FOUND: test/features/metronome/metronome_screen_test.dart
- FOUND: .planning/phases/18-metronome-tool/18-02-SUMMARY.md
- FOUND commit: 3586d05 (Task 1)
- FOUND commit: 79c4585 (Task 2)
- FOUND commit: efe5280 (plan metadata)
