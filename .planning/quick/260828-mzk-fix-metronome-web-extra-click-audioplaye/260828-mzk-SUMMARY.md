---
phase: quick-260828-mzk
plan: 260828-mzk
subsystem: audio
tags: [flutter, audioplayers, metronome, web]

# Dependency graph
requires:
  - phase: quick-260828-mhu
    provides: Confirmed the Dart-level beat-counting logic (MetronomeState._maybeTick()) is correct (1 accent + 3 secondary per bar); the "5 sounds per bar" symptom was isolated to the web build only, pointing at the audio-playback layer
provides:
  - AudioPlayersTickSoundPlayer.initialize() sets ReleaseMode.stop, keeping the buffered <audio> element alive across repeated tick retriggers on web instead of tearing it down/rebuilding after every completed tick
affects: [metronome]

# Actuals (#2632)
actuals:
  tokens: 313
  tasks: 1
  commits: 1

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "audioplayers ReleaseMode.stop for rapid-retrigger sound players: keeps platform resources (and on web, the underlying <audio> element) alive between play() calls instead of the default ReleaseMode.release teardown/rebuild cycle"

key-files:
  created: []
  modified:
    - lib/features/metronome/audio/tick_sound_player.dart

key-decisions:
  - "Inserted setReleaseMode(ReleaseMode.stop) between the existing setPlayerMode and setSource calls in AudioPlayersTickSoundPlayer.initialize() -- confirmed via reading audioplayers 5.2.1 and audioplayers_web 4.1.0 source during planning that call ordering relative to setPlayerMode/setSource has no effect, since WrappedPlayer reads the release-mode field live at tick-completion time, not at setSource time"
  - "No test seam exists to directly observe the real audioplayers platform-channel call (AudioPlayer is created internally, late final, no injection point) -- verification relies on a grep-level presence check, the full existing test suite (which uses hand-rolled TickSoundPlayer doubles and never touches the real platform channel), and a human web-build re-check, not a new automated behavioral test"

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "AudioPlayersTickSoundPlayer.initialize() calls _player.setReleaseMode(ReleaseMode.stop), applying to both the accent and regular tick sound players via the shared method"
    verification:
      - kind: other
        ref: "grep -q 'setReleaseMode(ReleaseMode.stop)' lib/features/metronome/audio/tick_sound_player.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Full existing metronome test suite (state, audio-service, screen, dial) still passes with no regression"
    verification:
      - kind: unit
        ref: "flutter test test/features/metronome/ (22 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "flutter analyze reports no new issues"
    verification:
      - kind: other
        ref: "flutter analyze"
        status: pass
    human_judgment: false
  - id: D4
    description: "An actual Flutter web build plays exactly 4 clicks per 4/4 bar (1 accent + 3 secondary), with no extra/lagged click, confirming the ReleaseMode.stop fix resolves the reported web-only 5-click symptom"
    verification: []
    human_judgment: true
    rationale: "No automated seam exists to observe the real audioplayers platform-channel/web <audio> element behavior (AudioPlayer is created internally inside initialize(), late final, no injection point); the fix is confirmed correct by source inspection of audioplayers/audioplayers_web during planning, but the actual perceived-audio behavior on a real web build requires a human to rebuild (not hot reload) and listen."

# Metrics
duration: 8min
completed: 2026-08-28
status: complete
---

# Quick Task 260828-mzk: Metronome Web Extra-Click Fix Summary

**Set `ReleaseMode.stop` on the shared tick `AudioPlayer` so `audioplayers_web` keeps the buffered `<audio>` element alive across repeated tick retriggers instead of tearing it down and reloading it after every completed tick.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-08-28T13:38:00Z (approx)
- **Completed:** 2026-08-28T13:46:00Z (approx)
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- `AudioPlayersTickSoundPlayer.initialize()` now calls `await _player.setReleaseMode(ReleaseMode.stop);` between the existing `setPlayerMode(PlayerMode.lowLatency)` and `setSource(AssetSource(_assetPath))` calls
- Added a factual doc comment on `initialize()` explaining the web-specific mechanism (`audioplayers_web`'s `WrappedPlayer` tearing down/recreating the `<audio>` element on `onEnded` under the default `ReleaseMode.release`) and why `ReleaseMode.stop` fixes it, while being a no-op-safe config on native
- This single edit covers both the accent and regular tick players, since `MetronomeAudioService` constructs both as `AudioPlayersTickSoundPlayer` instances sharing this one `initialize()` method
- Ran the full `test/features/metronome/` suite (state, audio-service, screen, dial) -- all 22 tests pass, no regressions
- Ran `flutter analyze` -- no issues found

## Task Commits

Each task was committed atomically:

1. **Task 1: Configure ReleaseMode.stop on the tick AudioPlayer to stop the web teardown/rebuild cycle** - `84bcad4` (fix)

**Plan metadata:** committed separately by the orchestrator (docs-only files not committed by this executor per task constraints)

## Files Created/Modified
- `lib/features/metronome/audio/tick_sound_player.dart` - Added `setReleaseMode(ReleaseMode.stop)` call and explanatory doc comment in `AudioPlayersTickSoundPlayer.initialize()`

## Decisions Made
- Call placement: between `setPlayerMode` and `setSource`, matching `audioplayers`' own test-suite ordering convention (mode, then release mode, then source). Confirmed via source reading during planning that this ordering has no functional effect either way -- `setReleaseMode()` just records the mode field, and `WrappedPlayer` reads it live at each tick-completion event, not at `setSource` time.
- No test double/injection seam was added for the real `audioplayers` `AudioPlayer` (it's created internally as `late final` inside `initialize()`). Building real platform-channel mock infrastructure just to assert this one config call was judged disproportionate, per the plan's explicit Known Limitation -- verification instead relies on grep + full regression suite + human web-build check (see D4 above).

## Deviations from Plan

None - plan executed exactly as written. Single task, single edit, verification ran exactly as specified in `<verify>`.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

**Human verification still needed (per plan's Known Limitation and coverage item D4):** Please do a full Flutter web build (not hot reload -- a stale web `<audio>` element can survive hot reload) and play the metronome for several bars, confirming exactly 4 clicks per 4/4 bar (1 accent + 3 secondary) with no extra/lagged click, matching the native-platform behavior already confirmed correct in quick task 260828-mhu.

## Next Phase Readiness
- Fix is committed and covered by the existing regression suite (including the 260828-mhu real-call-chain accent-pattern test, which continues to pass unaffected).
- No blockers, pending the human web-build confirmation above.

---
*Phase: quick-260828-mzk*
*Completed: 2026-08-28*

## Self-Check: PASSED
- FOUND: lib/features/metronome/audio/tick_sound_player.dart
- FOUND: commit 84bcad4
- FOUND: .planning/quick/260828-mzk-fix-metronome-web-extra-click-audioplaye/260828-mzk-SUMMARY.md
