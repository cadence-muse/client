---
type: quick
slug: 260828-mzk-fix-metronome-web-extra-click-audioplaye
autonomous: true
files_modified:
  - lib/features/metronome/audio/tick_sound_player.dart
must_haves:
  truths:
    - "AudioPlayersTickSoundPlayer.initialize() configures ReleaseMode.stop on the underlying audioplayers AudioPlayer, for both the accent and regular tick players (both are AudioPlayersTickSoundPlayer instances sharing this one method) -- so the web platform's <audio> element is kept alive across repeated tick playback instead of being torn down and rebuilt after every completed tick"
    - "The existing metronome test suite (state, audio-service, screen, dial) still passes unmodified after the change -- no regression"
  artifacts:
    - lib/features/metronome/audio/tick_sound_player.dart
  key_links:
    - "AudioPlayersTickSoundPlayer.initialize() -> AudioPlayer.setReleaseMode(ReleaseMode.stop) -> (web only, audioplayers_web's WrappedPlayer) onEnded no longer calls release()/recreateNode() on tick completion, so the next resume() plays the already-buffered element instead of an unawaited async reload"
---

<objective>
Fix the web-only metronome bug where a 4/4 bar plays 5 audible clicks instead of 4: on
`audioplayers_web`, the default `ReleaseMode.release` causes the underlying `<audio>`
`AudioElement` to be destroyed every time a tick sound finishes, forcing the next `resume()` to
`recreateNode()` and reload the asset from scratch (async, unawaited) before playing -- a web-only
timing artifact perceived as an extra click. Native mobile players (`SoundPool`/`AVAudioPlayer` via
`PlayerMode.lowLatency`) don't hit this path, which is why this reproduces only on web.

This is a follow-up to quick task 260828-mhu, which proved the Dart-level beat-counting logic
(`MetronomeState._maybeTick()`) is already correct (1 accent + 3 secondary per bar) and confirmed
the "5 sounds per bar" symptom does not reproduce in that state machine -- the user then confirmed
it only reproduces on the web build, pointing at the audio-playback layer instead.

Purpose: Keep the buffered `<audio>` element alive across repeated tick retriggers on web (and be a
no-op-safe config on native) by explicitly setting `ReleaseMode.stop` -- "Stops audio playback but
keep all resources intact. Use this if you intend to play again later" (audioplayers'
`ReleaseMode` doc), which is exactly this metronome's rapid-retrigger use case.

Output: `lib/features/metronome/audio/tick_sound_player.dart` updated so
`AudioPlayersTickSoundPlayer.initialize()` calls `setReleaseMode(ReleaseMode.stop)` on its
`AudioPlayer`, applying to both the accent and regular tick sound players.

**Known limitation (read before writing the SUMMARY):** No automated test can directly observe
this call reaching the real `audioplayers` platform channel. `AudioPlayersTickSoundPlayer._player`
is a `late final AudioPlayer` created internally inside `initialize()` -- there is no seam to
inject a fake/spy `AudioPlayer`. Every existing metronome test
(`metronome_state_test.dart`, `metronome_audio_service_test.dart`) already avoids the real
`audioplayers` platform channel entirely by testing through hand-rolled `TickSoundPlayer` doubles
(`FakeTickSoundPlayer`/`SpyTickSoundPlayer`) -- confirmed by reading both files during planning.
Building real platform-channel test infra for `audioplayers` would additionally require mocking its
`MethodChannel`/`EventChannel` handshake and synthesizing an `audio.onPrepared` event just to get
`setSourceAsset()` to complete -- disproportionate for a one-line config call and out of scope here
(constraints explicitly allow a lighter-weight assertion instead of forcing this). Verification for
this plan is therefore: (1) a grep-level presence check that the fix line exists, (2) the full
existing metronome test suite passing with no regressions, and (3) `flutter analyze` clean. A
real-device/real-browser web-build check is called out as a human-verification step.
</objective>

<execution_context>
@/home/bulat.khafizov/.claude/plugins/marketplaces/gsd-core/gsd-core/workflows/execute-plan.md
@/home/bulat.khafizov/.claude/plugins/marketplaces/gsd-core/gsd-core/templates/summary.md
</execution_context>

<context>
@/home/bulat.khafizov/projects/personal/cadence/client/.planning/STATE.md
@/home/bulat.khafizov/projects/personal/cadence/client/lib/features/metronome/audio/tick_sound_player.dart
@/home/bulat.khafizov/projects/personal/cadence/client/lib/features/metronome/audio/metronome_audio_service.dart

`MetronomeAudioService` (`lib/features/metronome/audio/metronome_audio_service.dart`) constructs
exactly two `AudioPlayersTickSoundPlayer` instances -- `accentPlayer` from
`'audio/metronome_accent.wav'` and `regularPlayer` from `'audio/metronome_regular.wav'` -- both
inside the `metronomeAudioService` riverpod provider (bottom of that file). Both share the same
`AudioPlayersTickSoundPlayer.initialize()` method body in `tick_sound_player.dart`, so a single edit
to that method fixes both players; no per-instance duplication is needed.

`AudioPlayersTickSoundPlayer.initialize()` currently reads (verified by direct read during
planning):

```
Future<void> initialize() async {
  _player = AudioPlayer();
  await _player.setPlayerMode(PlayerMode.lowLatency);
  await _player.setSource(AssetSource(_assetPath));
}
```

Ordering was confirmed safe by reading `audioplayers` 5.2.1's source
(`~/.pub-cache/hosted/pub.dev/audioplayers-5.2.1/lib/src/audioplayer.dart`) and
`audioplayers_web` 4.1.0's `WrappedPlayer` (`~/.pub-cache/hosted/pub.dev/audioplayers_web-4.1.0/lib/wrapped_player.dart`):
`AudioPlayer.setReleaseMode()` only synchronously records the mode and awaits the player's creation
completer before forwarding to the platform -- it has no ordering dependency on `setPlayerMode` or
`setSource`. On web, `WrappedPlayer`'s `onEnded` handler reads `_currentReleaseMode` live (the field
`setReleaseMode` writes to) at the moment each tick finishes, not a value captured earlier at
`setSource` time -- so placing the new call anywhere in `initialize()` before the player is first
played is equally correct. Insert it between the existing `setPlayerMode` and `setSource` calls
(grouping the two player-wide config calls together, source-load last), matching the order
`audioplayers`' own test suite exercises these setters in (mode, then release mode).

`flutter` is at `/home/bulat.khafizov/software/flutter/bin/flutter`.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Configure ReleaseMode.stop on the tick AudioPlayer to stop the web teardown/rebuild cycle</name>
  <files>lib/features/metronome/audio/tick_sound_player.dart</files>
  <action>
    In `AudioPlayersTickSoundPlayer.initialize()` (`lib/features/metronome/audio/tick_sound_player.dart`),
    insert `await _player.setReleaseMode(ReleaseMode.stop);` as a new statement between the existing
    `await _player.setPlayerMode(PlayerMode.lowLatency);` line and the existing
    `await _player.setSource(AssetSource(_assetPath));` line. No new import is needed --
    `ReleaseMode` is already exported by the file's existing
    `import 'package:audioplayers/audioplayers.dart';`.

    Add a `///` doc comment directly above `initialize()` (this override currently has no doc
    comment of its own, only inheriting `TickSoundPlayer.initialize()`'s interface doc) explaining:
    on the web platform, the default `ReleaseMode.release` tears down and recreates the underlying
    `<audio>` element after every completed tick (an unawaited async reload before the next play),
    producing an extra perceived click / timing lag; `ReleaseMode.stop` keeps the buffered element
    intact across repeated retriggers instead, matching this metronome's rapid-retrigger use
    case, and is a no-op-safe config on native platforms. Keep this comment factual and specific
    (name the web mechanism), not generic.

    This single edit applies to both the accent and regular tick players -- do not duplicate the
    change per-instance; `MetronomeAudioService`'s two `AudioPlayersTickSoundPlayer` constructions
    both route through this one `initialize()` method.

    Do not touch `metronome_audio_service.dart`, the beat-scheduling provider, or any test file --
    this fix is scoped entirely to the one config call inside `tick_sound_player.dart`.
  </action>
  <verify>
    <automated>cd /home/bulat.khafizov/projects/personal/cadence/client && grep -q "setReleaseMode(ReleaseMode.stop)" lib/features/metronome/audio/tick_sound_player.dart && flutter test test/features/metronome/ && flutter analyze</automated>
    <human-check>Rebuild and run an actual Flutter web build (not hot reload -- a stale web `<audio>` element can survive hot reload), play the metronome for several bars, and confirm exactly 4 clicks per 4/4 bar (1 accent + 3 secondary), with no extra/lagged click -- matching the native-platform behavior already confirmed correct in quick task 260828-mhu.</human-check>
  </verify>
  <done>
    `AudioPlayersTickSoundPlayer.initialize()` calls `_player.setReleaseMode(ReleaseMode.stop)`
    (covering both the accent and regular tick players via the shared method). `flutter analyze`
    reports no new issues. The full `test/features/metronome/` suite (state, audio-service, screen,
    dial) still passes -- proving no regression/compile break, though (per the Known Limitation in
    `<objective>`) these tests use hand-rolled doubles and don't exercise the real `audioplayers`
    platform channel, so the release-mode teardown-avoidance behavior itself is confirmed by source
    inspection during planning and the human web-build check above, not by an automated behavioral
    test.
  </done>
</task>

</tasks>

<verification>
1. `grep -q "setReleaseMode(ReleaseMode.stop)" lib/features/metronome/audio/tick_sound_player.dart`
   confirms the fix line exists in `AudioPlayersTickSoundPlayer.initialize()`.
2. `flutter test test/features/metronome/` passes in full -- no regression in the state, audio
   service, screen, or dial test files.
3. `flutter analyze` reports no new issues introduced by this change.
4. Human-check: an actual Flutter web build plays exactly 4 clicks per 4/4 bar with no extra/lagged
   click.
</verification>

<success_criteria>
- `AudioPlayersTickSoundPlayer.initialize()` explicitly sets `ReleaseMode.stop` on its
  `AudioPlayer`, applying to both the accent and regular tick sound players.
- No regression in the existing metronome test suite.
- `flutter analyze` is clean.
- The SUMMARY documents the Known Limitation (no automated seam to observe the raw `audioplayers`
  platform-channel call) and explicitly asks for the human web-build re-check before this is
  considered fully closed out.
</success_criteria>

<output>
Create `.planning/quick/260828-mzk-fix-metronome-web-extra-click-audioplaye/260828-mzk-SUMMARY.md`
when done, with `status: complete` in frontmatter.
</output>
