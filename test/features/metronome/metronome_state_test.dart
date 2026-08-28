import 'package:cadence/features/metronome/audio/metronome_audio_service.dart';
import 'package:cadence/features/metronome/audio/tick_sound_player.dart';
import 'package:cadence/providers/metronome_provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// No-op [TickSoundPlayer] double -- lets [MetronomeAudioService] initialize
/// and "play" without ever touching the real audioplayers platform channel.
class FakeTickSoundPlayer implements TickSoundPlayer {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> dispose() async {}
}

/// Spy [TickSoundPlayer] double -- records which sound was played (by
/// [label]) into a shared [calls] list, letting a test assert the exact
/// accent/regular call sequence produced by the real
/// `MetronomeState` -> `MetronomeAudioService` -> `TickSoundPlayer.play()`
/// chain, rather than reimplementing the beat-counting logic separately.
class SpyTickSoundPlayer implements TickSoundPlayer {
  SpyTickSoundPlayer(this.calls, this.label);

  final List<String> calls;
  final String label;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> play() {
    calls.add(label);
    return Future.value();
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  /// Every test builds its own [ProviderContainer] with
  /// [metronomeAudioServiceProvider] overridden to a fake-backed service --
  /// no test touches the real audioplayers platform channel.
  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        metronomeAudioServiceProvider.overrideWith((ref) async {
          final service = MetronomeAudioService(
            accentPlayer: FakeTickSoundPlayer(),
            regularPlayer: FakeTickSoundPlayer(),
          );
          await service.initialize();
          return service;
        }),
      ],
    );
  }

  /// [metronomeStateProvider] is `autoDispose` (matching the screen's
  /// `ref.watch` keeping it alive only while mounted) -- a bare
  /// `container.read()` with no active listener is eligible for disposal on
  /// the very next scheduled microtask, cancelling the beat [Timer] before
  /// it can fire again. Tests hold this subscription for their duration to
  /// mirror what `MetronomeScreen`'s own `ref.watch` does in production.
  ProviderSubscription<MetronomeData> keepAlive(
    ProviderContainer container,
    int initialBpm,
  ) {
    return container.listen(
      metronomeStateProvider(initialBpm),
      (previous, next) {},
    );
  }

  testWidgets('ticks play in sequence (Test 1)', (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);
    keepAlive(container, 120);

    container.read(metronomeStateProvider(120).notifier).togglePlay();

    final observed = <int>[];
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      observed.add(container.read(metronomeStateProvider(120)).currentBeat);
    }

    expect(observed, [1, 2, 3, 0]);

    // Stop playback before the test ends -- otherwise the beat Timer is
    // still running when flutter_test's teardown checks for pending timers.
    container.read(metronomeStateProvider(120).notifier).togglePlay();
  });

  testWidgets('setBpm clamps to 40 lower bound (Test 2)', (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);
    keepAlive(container, 120);

    container.read(metronomeStateProvider(120).notifier).setBpm(10);

    expect(container.read(metronomeStateProvider(120)).bpm, 40);
  });

  testWidgets('setBpm clamps to 300 upper bound (Test 3)', (tester) async {
    final container = buildContainer();
    addTearDown(container.dispose);
    keepAlive(container, 120);

    container.read(metronomeStateProvider(120).notifier).setBpm(999);

    expect(container.read(metronomeStateProvider(120)).bpm, 300);
  });

  testWidgets(
    'opens paused regardless of initialBpm (Test 4, D-08)',
    (tester) async {
      final container = buildContainer();
      addTearDown(container.dispose);
      keepAlive(container, 250);

      expect(container.read(metronomeStateProvider(250)).isPlaying, isFalse);
    },
  );

  testWidgets(
    'tempo change takes effect on next tick, not next bar (Test 5, D-04)',
    (tester) async {
      final container = buildContainer();
      addTearDown(container.dispose);
      keepAlive(container, 120);

      final notifier = container.read(metronomeStateProvider(120).notifier);
      notifier.togglePlay();

      // 500ms/tick at 120 BPM -- one tick fires.
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(metronomeStateProvider(120)).currentBeat, 1);

      // Speed up to 240 BPM (250ms/tick) mid-play.
      notifier.setBpm(240);

      // Only 250ms (not the old 500ms interval) -- the faster interval
      // applies immediately, not after the old interval elapses.
      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(metronomeStateProvider(120)).currentBeat, 2);

      // Stop playback before the test ends -- otherwise the beat Timer is
      // still running when flutter_test's teardown checks for pending
      // timers.
      notifier.togglePlay();
    },
  );

  testWidgets(
    'backgrounding the app while playing stops playback (Test 6, '
    'PROHIBIT-BG-AUDIO)',
    (tester) async {
      final container = buildContainer();
      addTearDown(container.dispose);
      keepAlive(container, 120);

      container.read(metronomeStateProvider(120).notifier).togglePlay();
      expect(container.read(metronomeStateProvider(120)).isPlaying, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(container.read(metronomeStateProvider(120)).isPlaying, isFalse);
    },
  );

  testWidgets(
    'plays exactly 1 accent + 3 secondary ticks per 4/4 bar, not 5 '
    '(regression)',
    (tester) async {
      final calls = <String>[];
      final container = ProviderContainer(
        overrides: [
          metronomeAudioServiceProvider.overrideWith((ref) async {
            final service = MetronomeAudioService(
              accentPlayer: SpyTickSoundPlayer(calls, 'accent'),
              regularPlayer: SpyTickSoundPlayer(calls, 'regular'),
            );
            await service.initialize();
            return service;
          }),
        ],
      );
      addTearDown(container.dispose);
      keepAlive(container, 120);
      container.listen(metronomeAudioServiceProvider, (_, _) {});
      await container.read(metronomeAudioServiceProvider.future);

      container.read(metronomeStateProvider(120).notifier).togglePlay();

      // 500ms/tick at 120 BPM -- 12 ticks covers exactly 3 full 4/4 bars.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Stop playback before the test ends -- otherwise the beat Timer is
      // still running when flutter_test's teardown checks for pending
      // timers.
      container.read(metronomeStateProvider(120).notifier).togglePlay();

      expect(calls, [
        'accent', 'regular', 'regular', 'regular', //
        'accent', 'regular', 'regular', 'regular', //
        'accent', 'regular', 'regular', 'regular', //
      ]);
    },
  );
}
