---
type: quick
slug: 260828-mhu-fix-metronome-now-it-plays-accent-click-
autonomous: true
files_modified:
  - test/features/metronome/metronome_state_test.dart
  - lib/providers/metronome_provider.dart
must_haves:
  truths:
    - "A full 4/4 bar of metronome playback triggers exactly 1 accent tick followed by exactly 3 secondary ticks before the next accent — never 4 secondary ticks / 5 sounds per bar"
    - "The regression test exercises the real production call chain (MetronomeState notifier -> MetronomeAudioService -> TickSoundPlayer.play()), not a reimplementation of the counting logic"
  artifacts:
    - test/features/metronome/metronome_state_test.dart
  key_links:
    - "MetronomeState._maybeTick's `state.currentBeat == 0` accent check and `(state.currentBeat + 1) % 4` cycling -> MetronomeAudioService.playTick(isAccent) -> spy TickSoundPlayer.play() call sequence asserted by the new regression test"
---

<objective>
Diagnose and close out the reported bug: "metronome plays accent click and then 4 secondary,
but it should be 1 accent and 3 secondary" (5 sounds per 4/4 bar instead of the correct 4).

Purpose: Lock in the correct 1-accent+3-secondary beat sequence with an automated regression test
that exercises the real production call chain end-to-end, and fix the underlying scheduling logic
in `lib/providers/metronome_provider.dart` if that test actually reproduces the bug.

**Important context for the executor:** a throwaway diagnostic test built during planning — using
the exact production wiring (`MetronomeState` notifier -> `MetronomeAudioService` ->
`TickSoundPlayer`, with only the leaf platform-channel player swapped for a spy) — observed the
call sequence `[accent, regular, regular, regular]` repeated exactly across 3 simulated bars at
120 BPM, with no 5th click ever appearing before the next accent. `lib/providers/metronome_provider.dart`'s
`_maybeTick()` already reads `isAccent = state.currentBeat == 0` before advancing
`(state.currentBeat + 1) % 4`, which is mathematically a correct 1-of-4 accent cycle, and this is
the only place `playTick(...)` is called anywhere in `lib/`. `git log` shows this modulo has been
`% 4` since the feature's original commit (`46b247e`) — it was never `% 5` or any other value.
This does NOT mean there is nothing to do: Task 1 writes the real regression test from scratch (do
not skip re-verifying this), and Task 2 branches on what that test actually shows when run fresh —
fix the code if it fails, or close out with clear documentation (and a stale-build note for the
user) if it passes exactly as described above.
</objective>

<execution_context>
@/home/bulat.khafizov/.claude/plugins/marketplaces/gsd-core/gsd-core/workflows/execute-plan.md
@/home/bulat.khafizov/.claude/plugins/marketplaces/gsd-core/gsd-core/templates/summary.md
</execution_context>

<context>
@/home/bulat.khafizov/projects/personal/cadence/client/.planning/STATE.md
@/home/bulat.khafizov/projects/personal/cadence/client/lib/providers/metronome_provider.dart
@/home/bulat.khafizov/projects/personal/cadence/client/lib/features/metronome/audio/metronome_audio_service.dart
@/home/bulat.khafizov/projects/personal/cadence/client/lib/features/metronome/audio/tick_sound_player.dart
@/home/bulat.khafizov/projects/personal/cadence/client/test/features/metronome/metronome_state_test.dart

Beat-scheduling logic lives entirely in `MetronomeState._maybeTick()`
(`lib/providers/metronome_provider.dart` lines ~115-147): a `Timer.periodic(10ms)` polls a
`Stopwatch` and, once `elapsedMilliseconds >= _nextTickDueMs`, reads
`isAccent = state.currentBeat == 0`, calls `MetronomeAudioService.playTick(isAccent)`, then
advances `state.currentBeat` via `(state.currentBeat + 1) % 4`. `MetronomeAudioService.playTick`
(`lib/features/metronome/audio/metronome_audio_service.dart` line ~64) routes to
`_accentPlayer.play()` or `_regularPlayer.play()` based on that flag — no other call site in `lib/`
invokes `playTick`.

The existing test file `test/features/metronome/metronome_state_test.dart` already has a
`FakeTickSoundPlayer` (a no-op double) and a `buildContainer()`/`keepAlive()` pattern used by all
6 existing tests — follow these same conventions for the new spy and test rather than inventing a
new structure. Note `metronomeAudioServiceProvider` is itself `autoDispose`: a test must
`container.listen(metronomeAudioServiceProvider, (_, __) {})` AND
`await container.read(metronomeAudioServiceProvider.future);` before calling `togglePlay()`, or the
service never finishes initializing and `_maybeTick()`'s `ref.read(...).valueOrNull` stays null the
whole test (confirmed during planning — omitting this makes the spy record zero calls, not a
failing assertion, which would silently defeat the regression test).

`flutter` is at `/home/bulat.khafizov/software/flutter/bin/flutter`.
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add a real-call-chain regression test pinning the 1-accent+3-secondary bar sequence</name>
  <files>test/features/metronome/metronome_state_test.dart</files>
  <behavior>
    - Test: playing for 3 full bars (12 ticks) at 120 BPM produces the exact spy call sequence
      `['accent', 'regular', 'regular', 'regular']` repeated 3 times (12 entries total) — proving
      each bar is exactly 1 accent + 3 secondary, with the next bar's accent immediately following
      the 3rd secondary (never a 4th secondary before it).
  </behavior>
  <action>
    In `test/features/metronome/metronome_state_test.dart`, add a `SpyTickSoundPlayer implements
    TickSoundPlayer` class alongside the existing `FakeTickSoundPlayer` — its constructor takes a
    shared `List&lt;String&gt; calls` and a `String label`, `initialize()`/`dispose()` are no-ops
    like `FakeTickSoundPlayer`, and `play()` does `calls.add(label); return Future.value();`.

    Add a new `testWidgets` case (e.g. `'plays exactly 1 accent + 3 secondary ticks per 4/4 bar,
    not 5 (regression)'`). Build a `ProviderContainer` overriding `metronomeAudioServiceProvider`
    with a `MetronomeAudioService` constructed from two `SpyTickSoundPlayer`s sharing one `calls`
    list — `accentPlayer: SpyTickSoundPlayer(calls, 'accent')`,
    `regularPlayer: SpyTickSoundPlayer(calls, 'regular')` — mirroring `buildContainer()`'s override
    shape. `keepAlive()` the state provider per the file's existing pattern, additionally
    `container.listen(metronomeAudioServiceProvider, (_, __) {})`, then
    `await container.read(metronomeAudioServiceProvider.future);` before calling `togglePlay()`
    (see the `<context>` note on why this ordering is required).

    Call `togglePlay()`, then loop `await tester.pump(const Duration(milliseconds: 500))` 12 times
    (3 full bars at 120 BPM = 500ms/beat), then call `togglePlay()` again to stop playback (same
    teardown pattern as the file's other tests, so no pending Timer trips `flutter_test`'s
    teardown check). Assert `calls` equals exactly
    `['accent', 'regular', 'regular', 'regular', 'accent', 'regular', 'regular', 'regular',
    'accent', 'regular', 'regular', 'regular']`.
  </action>
  <verify>
    <automated>cd /home/bulat.khafizov/projects/personal/cadence/client && flutter test test/features/metronome/metronome_state_test.dart</automated>
  </verify>
  <done>
    The new regression test exists in `metronome_state_test.dart`, exercises the real
    `MetronomeState` notifier -> `MetronomeAudioService` -> `TickSoundPlayer.play()` chain (only
    the leaf player is a spy), and its actual pass/fail result is known (run it — do not assume
    the outcome).
  </done>
</task>

<task type="auto">
  <name>Task 2: Fix the beat-scheduling logic if the regression test fails, or close out with findings if it passes</name>
  <files>lib/providers/metronome_provider.dart</files>
  <action>
    Run the test added in Task 1 and read its actual output.

    If it FAILS: the assertion failure shows the actual observed call sequence. Use it to locate
    the true off-by-one in `MetronomeState._maybeTick()` — most likely candidates are the
    `state.currentBeat == 0` accent check, the `(state.currentBeat + 1) % 4` modulo, or
    `togglePlay()`'s initial-tick scheduling (`_nextTickDueMs = 0` / `_firstTickScheduled`) in
    `lib/providers/metronome_provider.dart`. Correct whichever is wrong so a full bar always
    produces exactly 1 accent tick followed by exactly 3 secondary ticks, then re-run Task 1's test
    until it passes.

    If it PASSES: make no changes to `lib/providers/metronome_provider.dart`. This confirms the
    currently-committed beat-scheduling logic (last touched by commit `8087833`, "fix(18): WR-02
    anchor tick scheduling to prevent real-clock drift") already produces the correct 1-accent +
    3-secondary sequence, and the specific "5 sounds per bar" symptom does not reproduce against
    this code. Note this finding for the SUMMARY.

    Regardless of which branch was taken, run the full metronome test surface to confirm no
    regression: `metronome_state_test.dart`, `metronome_audio_service_test.dart`,
    `metronome_screen_test.dart`, `metronome_dial_test.dart`, and
    `test/integration/metronome_e2e_test.dart`.
  </action>
  <verify>
    <automated>cd /home/bulat.khafizov/projects/personal/cadence/client && flutter test test/features/metronome/ test/integration/metronome_e2e_test.dart</automated>
    <human-check>If Task 1's test passed without any code change (bug did not reproduce), do a full rebuild + reinstall of the app on the affected device (not hot reload — hot reload can leave a stale Timer/isolate state) and re-verify the beat count by ear before re-filing this as a bug.</human-check>
  </verify>
  <done>
    All metronome tests (`test/features/metronome/`, `test/integration/metronome_e2e_test.dart`)
    pass, including the new regression test from Task 1. If a fix was required, the SUMMARY names
    the exact line(s) changed in `lib/providers/metronome_provider.dart` and why. If no fix was
    required, the SUMMARY states plainly that investigation (backed by the new regression test)
    found the current beat-scheduling logic already correct, and recommends a full rebuild/reinstall
    for re-verification.
  </done>
</task>

</tasks>

<verification>
1. `flutter test test/features/metronome/metronome_state_test.dart` passes, including the new
   regression test asserting the exact `[accent, regular, regular, regular]` x3 call sequence.
2. `flutter test test/features/metronome/ test/integration/metronome_e2e_test.dart` passes in full
   (no regression in sibling metronome tests).
3. `flutter analyze` reports no new issues introduced by this change.
4. The plan's SUMMARY states explicitly whether `lib/providers/metronome_provider.dart` was
   modified, and if so, exactly what changed and why.
</verification>

<success_criteria>
- A permanent automated regression test pins the correct 1-accent+3-secondary bar sequence against
  the real production notifier/audio-service call chain.
- If the bug reproduced under test, `lib/providers/metronome_provider.dart`'s beat-scheduling logic
  is fixed so a 4/4 bar always plays exactly 1 accent + 3 secondary ticks (4 total, never 5).
- If the bug did not reproduce, this is documented clearly with a concrete rebuild/reinstall
  recommendation rather than silently closing the task.
- No regression in the existing metronome test suite (state, audio service, screen, dial, e2e).
</success_criteria>

<output>
Create `.planning/quick/260828-mhu-fix-metronome-now-it-plays-accent-click-/260828-mhu-SUMMARY.md`
when done, with `status: complete` in frontmatter.
</output>
