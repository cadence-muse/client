import 'package:cadence/features/metronome/audio/metronome_audio_service.dart';
import 'package:cadence/features/metronome/audio/tick_sound_player.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [TickSoundPlayer] double -- tracks play-call count and whether
/// [initialize] should throw, with no real audioplayers platform channel
/// touched.
class FakeTickSoundPlayer implements TickSoundPlayer {
  FakeTickSoundPlayer({this.initializeThrows = false});

  final bool initializeThrows;
  int playCount = 0;

  @override
  Future<void> initialize() async {
    if (initializeThrows) {
      throw Exception('fake load failure');
    }
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test(
    'playTick routes to the correct player (Test 7)',
    () async {
      final accentPlayer = FakeTickSoundPlayer();
      final regularPlayer = FakeTickSoundPlayer();
      final service = MetronomeAudioService(
        accentPlayer: accentPlayer,
        regularPlayer: regularPlayer,
      );
      await service.initialize();
      expect(service.assetsLoaded, isTrue);

      await service.playTick(true);
      expect(accentPlayer.playCount, 1);
      expect(regularPlayer.playCount, 0);

      await service.playTick(false);
      expect(accentPlayer.playCount, 1);
      expect(regularPlayer.playCount, 1);
    },
  );

  test(
    'graceful degradation on load failure -- initialize does not rethrow, '
    'assetsLoaded stays false, playTick no-ops (Test 8)',
    () async {
      final accentPlayer = FakeTickSoundPlayer(initializeThrows: true);
      final regularPlayer = FakeTickSoundPlayer();
      final service = MetronomeAudioService(
        accentPlayer: accentPlayer,
        regularPlayer: regularPlayer,
      );

      // Must not throw.
      await service.initialize();
      expect(service.assetsLoaded, isFalse);

      await service.playTick(true);
      await service.playTick(false);
      expect(accentPlayer.playCount, 0);
      expect(regularPlayer.playCount, 0);
    },
  );
}
