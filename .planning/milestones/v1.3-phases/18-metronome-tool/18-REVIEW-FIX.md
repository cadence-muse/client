---
phase: 18-metronome-tool
fixed_at: 2026-08-28T07:15:00Z
review_path: .planning/phases/18-metronome-tool/18-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 18: Code Review Fix Report

**Fixed at:** 2026-08-28T07:15:00Z
**Source review:** .planning/phases/18-metronome-tool/18-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (3 Critical, 3 Warning -- IN-01 excluded per `critical_warning` scope)
- Fixed: 6
- Skipped: 0

**Verification:** All fixes were applied and verified inside the isolated worktree at
`.claude/worktrees/rf-18-122248-1787900448` (branch `gsd-reviewfix/18-122248`), which was
fast-forwarded into `main` and removed after the run. `flutter analyze` (whole project, run
after all 6 commits) reported no issues. `dart analyze` was also run per-file immediately
after each edit. The full required test scope (`test/features/metronome/`,
`test/integration/metronome_e2e_test.dart`, `test/features/tracks/track_detail_screen_test.dart`
-- 33 tests total) passed after all fixes were applied.

## Fixed Issues

### CR-01: `dispose()` throws `LateInitializationError` when one tick asset fails to initialize

**Files modified:** `lib/features/metronome/audio/metronome_audio_service.dart`
**Commit:** a5d22d9
**Applied fix:** Replaced the single sequential try/catch around both players' `initialize()`
calls with independent initialization via `Future.wait`, so a failure in one player's
`initialize()` can never skip the other's call (which previously left its `late final`
`AudioPlayer` field permanently unset). Also hardened `dispose()` to `unawaited(...).catchError`
on both players so a partial-init failure can never make teardown throw. Verified with
`dart analyze` (clean) and `flutter test test/features/metronome/metronome_audio_service_test.dart`
(2/2 passed).

### CR-02: Asset-load failure never reaches the screen's error UI

**Files modified:** `lib/features/metronome/metronome_screen.dart`
**Commit:** 7a1187c
**Applied fix:** Changed the `data:` branch of `audioAsync.when(...)` to check
`service.assetsLoaded` on the resolved service and route to the existing `_buildError` view
when it's `false`, instead of unconditionally calling `_buildContent`. This makes the
already-built, already-localized error/retry UI (`metronomeErrorMessage`/`commonRetry`)
reachable on a genuine asset-load failure, replacing the previous silently-inaudible-but-
fully-interactive failure mode. Verified with `dart analyze` (clean) and
`flutter test test/features/metronome/metronome_screen_test.dart` (4/4 passed).

### CR-03: Play FAB is not gated on audio-load state

**Files modified:** `lib/features/metronome/metronome_screen.dart`
**Commit:** 08152d3
**Applied fix:** Gated `floatingActionButton` on `audioAsync.hasValue`, matching how `body` is
already gated, so the Play/Pause FAB is `null` (hidden) while the audio service is still
loading or in an error state. Prevents a user from starting the beat timer before
`metronomeAudioServiceProvider` resolves, which previously silently dropped the first
tick(s)' sound. Verified with `dart analyze` (clean) and the full metronome + integration +
track-detail test suite (33/33 passed).

### WR-01: `MetronomeDialPainter.shouldRepaint` ignores color/style changes

**Files modified:** `lib/features/metronome/metronome_dial.dart`
**Commit:** bd5719c
**Applied fix:** Extended `shouldRepaint` to also compare `ringColor`, `numberStyle`, and
`unitStyle` against the previous delegate, not just `bpm`, so a theme change (e.g.
dark/light toggle) with an unchanged BPM value now correctly triggers a repaint. Verified
with `dart analyze` (clean) and `flutter test test/features/metronome/metronome_dial_test.dart`
(9/9 passed).

### WR-02: Tick scheduling drifts under real-clock jitter

**Files modified:** `lib/providers/metronome_provider.dart`
**Commit:** 8087833
**Applied fix (requires human verification):** Reworked `_maybeTick()`'s scheduling so that,
after the deliberately-immediate first tick of a play session (anchored once to its actual
fire time via a new `_firstTickScheduled` flag), every subsequent `_nextTickDueMs` advances
from the *previous scheduled* due time (`_nextTickDueMs += intervalMs`) rather than from
whatever elapsed time the current poll happened to observe. This prevents a late real-clock
10ms poll from pushing all later ticks later too (the compounding drift the review
described). `intervalMs` is still re-read fresh from `state.bpm` on every check, so D-04's
"tempo change takes effect on the very next tick" behavior is preserved.

This is flagged **"fixed: requires human verification"** per the fixer's logic-bug policy:
the review's own diagnosis explicitly notes the drift only manifests under real-clock
jitter, which is invisible to the fake-clock (`FakeAsync`) tests in this repo. The initial,
simpler version of this fix (a bare `_nextTickDueMs += intervalMs` from a `0` starting
anchor) broke `metronome_state_test.dart` Test 1 and Test 5 -- it caused a double-tick
within a single `tester.pump()` window because the schedule landed exactly on the pump's
round-number boundary. The final version (anchoring the first tick to its actual fire time,
then accumulating from there) was verified to reproduce the exact original schedule under
the deterministic fake clock (all 7 `metronome_state_test.dart` + 1 `metronome_e2e_test.dart`
tests pass), but the anti-drift behavior under genuine real-clock jitter cannot be exercised
by this repo's test suite and should be manually verified on a real device over an extended
play session (e.g. several minutes at a fixed BPM, checking the metronome doesn't measurably
slow down).

### WR-03: Dead normalization branch in the dial's gesture handler

**Files modified:** `lib/features/metronome/metronome_dial.dart`
**Commit:** 24c4339
**Applied fix:** Removed the unreachable `if (degrees <= -180) degrees += 360;` branch and
replaced it with a comment explaining why `degrees` can never reach `<= -180` after the
first fold (the review's alternative suggestion of a single `((degrees + 180) % 360) - 180`
rewrite was not used, since it would produce different behavior at the discontinuity itself
-- removing the dead branch was the more minimal, behavior-preserving fix). Verified with
`dart analyze` (clean) and `flutter test test/features/metronome/metronome_dial_test.dart`
(9/9 passed, including the discontinuity-boundary Test 6).

## Skipped Issues

None -- all 6 in-scope findings were fixed.

---

_Fixed: 2026-08-28T07:15:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
