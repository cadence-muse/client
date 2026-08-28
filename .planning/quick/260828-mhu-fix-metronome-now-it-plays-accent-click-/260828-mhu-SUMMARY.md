---
phase: quick-260828-mhu
plan: 260828-mhu
subsystem: testing
tags: [flutter, riverpod, metronome, regression-test]

# Dependency graph
requires: []
provides:
  - Permanent regression test pinning the correct 1-accent + 3-secondary bar sequence against the real MetronomeState -> MetronomeAudioService -> TickSoundPlayer chain
affects: [metronome]

# Actuals (#2632)
actuals:
  tokens: 725
  tasks: 2
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SpyTickSoundPlayer double: shared calls list + label, mirrors FakeTickSoundPlayer's no-op initialize/dispose but records play() invocations for exact-sequence assertions"

key-files:
  created: []
  modified:
    - test/features/metronome/metronome_state_test.dart

key-decisions:
  - "No production code change: the new regression test exercising the real notifier -> audio-service -> player chain over 3 full bars passed on first run, proving lib/providers/metronome_provider.dart's existing _maybeTick() beat-scheduling logic already produces exactly 1 accent + 3 secondary ticks per bar"

patterns-established:
  - "SpyTickSoundPlayer(calls, label) pattern for asserting exact call sequences through Riverpod-overridden async providers in flutter_test"

requirements-completed: []

coverage:
  - id: D1
    description: "Regression test locks in the correct 1-accent+3-secondary bar sequence using the real production call chain (MetronomeState -> MetronomeAudioService -> TickSoundPlayer.play())"
    verification:
      - kind: unit
        ref: "test/features/metronome/metronome_state_test.dart#plays exactly 1 accent + 3 secondary ticks per 4/4 bar, not 5 (regression)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Full metronome test suite (state, audio service, screen, dial, e2e) has no regressions"
    verification:
      - kind: unit
        ref: "flutter test test/features/metronome/ test/integration/metronome_e2e_test.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Reported '5 sounds per bar' symptom does not reproduce against the current committed beat-scheduling code; user should confirm via a full rebuild/reinstall (not hot reload) before re-filing"
    verification: []
    human_judgment: true
    rationale: "Whether a stale build was the actual cause of the originally reported symptom requires the user to rebuild/reinstall on the affected device and re-listen; this cannot be automated."

# Metrics
duration: 12min
completed: 2026-08-28
status: complete
---

# Quick Task 260828-mhu: Metronome Accent-Pattern Regression Test Summary

**Added a real-call-chain regression test that pins the 1-accent + 3-secondary bar sequence; the test passed immediately, proving the beat-scheduling code was already correct and no fix was needed.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-28T00:00:00Z (approx)
- **Completed:** 2026-08-28
- **Tasks:** 2 (1 code change, 1 verification-only)
- **Files modified:** 1

## Accomplishments
- Added `SpyTickSoundPlayer`, a `TickSoundPlayer` double that records `play()` calls into a shared list (alongside the existing no-op `FakeTickSoundPlayer`)
- Added a regression test simulating 3 full 4/4 bars at 120 BPM through the real `MetronomeState` notifier -> `MetronomeAudioService` -> `TickSoundPlayer.play()` chain, asserting the exact spy call sequence `[accent, regular, regular, regular]` repeated 3 times
- Ran the new test fresh (not assumed): it passed on the first run, confirming `lib/providers/metronome_provider.dart`'s `_maybeTick()` (`isAccent = state.currentBeat == 0`, `(state.currentBeat + 1) % 4`) already produces exactly 1 accent + 3 secondary ticks per bar — the reported "5 sounds per bar" symptom did not reproduce
- Ran the full metronome test surface (`metronome_state_test.dart`, `metronome_audio_service_test.dart`, `metronome_screen_test.dart`, `metronome_dial_test.dart`, `metronome_e2e_test.dart`) — all 23 tests pass, no regressions
- Ran `flutter analyze` — no issues found

## Task Commits

Each task was committed atomically:

1. **Task 1: Add a real-call-chain regression test pinning the 1-accent+3-secondary bar sequence** - `b0fe328` (test)
2. **Task 2: Fix the beat-scheduling logic if the regression test fails, or close out with findings if it passes** - no commit (no code change required; test passed, confirming `lib/providers/metronome_provider.dart` was already correct)

**Plan metadata:** committed separately by the orchestrator (docs-only files not committed by this executor per task constraints)

## Files Created/Modified
- `test/features/metronome/metronome_state_test.dart` - Added `SpyTickSoundPlayer` double and a new regression test asserting the exact accent/regular call sequence over 3 bars

## Decisions Made
- No change made to `lib/providers/metronome_provider.dart`. The plan's Task 2 branched explicitly on the test's real outcome (not an assumption): the regression test passed on first run with the exact expected sequence `[accent, regular, regular, regular]` x3, confirming the currently-committed beat-scheduling logic (`isAccent = state.currentBeat == 0`, `(state.currentBeat + 1) % 4`, last touched by commit `8087833`) is already correct. Per the plan's explicit instruction for this branch, no code was modified.

## Deviations from Plan

None - plan executed exactly as written. Task 1 added the regression test as specified; Task 2's "if it PASSES" branch was taken (no code change) exactly as the plan anticipated as one of its two possible outcomes.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

**Recommendation for the user (per Task 2's `<done>` criteria):** Since the regression test proves the current code already produces the correct 1-accent + 3-secondary sequence, the originally reported "5 sounds per bar" symptom likely stemmed from a stale build. Please do a full rebuild + reinstall of the app on the affected device (not hot reload, which can leave a stale `Timer`/isolate state) and re-verify the beat count by ear. If the symptom persists after a clean rebuild, re-file with device/OS details so the investigation can look beyond `lib/providers/metronome_provider.dart` (e.g., a stale/cached asset, a duplicate `Timer`, or a platform-channel issue in `audioplayers`).

## Next Phase Readiness
- Regression test is now permanent in `test/features/metronome/metronome_state_test.dart`, guarding against any future regression of the beat-scheduling sequence.
- No blockers.

---
*Phase: quick-260828-mhu*
*Completed: 2026-08-28*

## Self-Check: PASSED
- FOUND: test/features/metronome/metronome_state_test.dart
- FOUND: commit b0fe328
- FOUND: .planning/quick/260828-mhu-fix-metronome-now-it-plays-accent-click-/260828-mhu-SUMMARY.md
