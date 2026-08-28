import 'package:audioplayers/audioplayers.dart';

/// A single preloaded tick sound, playable with low latency for rapid
/// retriggering (D-01). One instance per sound (accent/regular) — reusing a
/// single [AudioPlayer] for both would cut off the previous sound on rapid
/// retrigger (18-RESEARCH.md Anti-Patterns).
abstract class TickSoundPlayer {
  /// Loads the underlying asset. Any failure propagates uncaught -- the
  /// caller ([MetronomeAudioService]) owns the single try/catch around both
  /// players' initialization.
  Future<void> initialize();

  /// Plays this tick sound from the start.
  Future<void> play();

  /// Releases the underlying player resources.
  Future<void> dispose();
}

/// [TickSoundPlayer] backed by `audioplayers` in [PlayerMode.lowLatency] --
/// the platform's rapid-fire sound API (SoundPool on Android, AVAudioPlayer
/// on iOS), suited to a metronome's repeated short-sound use case (D-01).
class AudioPlayersTickSoundPlayer implements TickSoundPlayer {
  AudioPlayersTickSoundPlayer(this._assetPath);

  /// Relative asset key (e.g. `'audio/metronome_accent.wav'`), matching the
  /// `pubspec.yaml` assets root -- not the on-disk `assets/audio/...` path.
  final String _assetPath;

  late final AudioPlayer _player;

  /// On web, the default [ReleaseMode.release] tears down and recreates the
  /// underlying `<audio>` element (`audioplayers_web`'s `WrappedPlayer`)
  /// after every completed tick -- an unawaited async reload before the next
  /// `play()`/`resume()` -- producing an extra perceived click / timing lag.
  /// [ReleaseMode.stop] keeps the buffered element intact across repeated
  /// retriggers instead, matching this metronome's rapid-retrigger use case,
  /// and is a no-op-safe config on native platforms (SoundPool/AVAudioPlayer
  /// via [PlayerMode.lowLatency] don't hit this teardown path).
  @override
  Future<void> initialize() async {
    _player = AudioPlayer();
    await _player.setPlayerMode(PlayerMode.lowLatency);
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(AssetSource(_assetPath));
  }

  @override
  Future<void> play() async {
    await _player.resume();
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
  }
}
