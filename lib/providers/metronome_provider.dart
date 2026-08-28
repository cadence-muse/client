import 'dart:async';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/metronome/audio/metronome_audio_service.dart';

part 'metronome_provider.g.dart';

/// Immutable metronome playback state (D-06/D-08).
class MetronomeData {
  const MetronomeData({
    required this.bpm,
    required this.isPlaying,
    required this.currentBeat,
  });

  /// Beats per minute, always clamped to [40, 300] (D-06).
  final int bpm;

  /// Whether the beat loop is currently running.
  final bool isPlaying;

  /// Position within the 4/4 bar, 0-3. Beat 0 is the accented beat (D-03).
  final int currentBeat;

  MetronomeData copyWith({int? bpm, bool? isPlaying, int? currentBeat}) =>
      MetronomeData(
        bpm: bpm ?? this.bpm,
        isPlaying: isPlaying ?? this.isPlaying,
        currentBeat: currentBeat ?? this.currentBeat,
      );
}

/// Metronome beat-scheduling state, keyed as a Riverpod family by
/// [initialBpm] -- the Homepage's default 120 and a track's own tempo each
/// get an independent instance (PROHIBIT-STATE-BLEED notwithstanding, see
/// 18-01-PLAN.md's threat register).
///
/// D-08: always opens paused regardless of [initialBpm]. D-04/Pitfall 3:
/// `state.bpm` is read fresh on every tick check (never cached), so a
/// `setBpm()` call between two ticks changes what the very next check reads
/// -- tempo changes take effect immediately on the next tick, not the next
/// bar.
@riverpod
class MetronomeState extends _$MetronomeState {
  Timer? _checkTimer;
  Stopwatch? _stopwatch;
  int _nextTickDueMs = 0;

  @override
  MetronomeData build(int initialBpm) {
    ref.onDispose(() {
      _checkTimer?.cancel();
      _stopwatch?.stop();
    });
    return MetronomeData(
      bpm: initialBpm.clamp(40, 300),
      isPlaying: false,
      currentBeat: 0,
    );
  }

  /// The single choke point for BPM writes (D-06/T-18-01) -- every code path
  /// that changes BPM must go through here so the clamp is unconditional.
  void setBpm(int newBpm) {
    state = state.copyWith(bpm: newBpm.clamp(40, 300));
  }

  void togglePlay() {
    if (!state.isPlaying) {
      state = state.copyWith(isPlaying: true);
      // clock.stopwatch() (package:clock) rather than a bare Stopwatch() --
      // behaviorally identical in production (backed by the real system
      // clock) but lets `flutter test`'s AutomatedTestWidgetsFlutterBinding
      // swap in a fake, pump()-driven clock so elapsed-time checks below
      // advance deterministically with `tester.pump(duration)` instead of
      // real wall-clock time.
      _stopwatch = clock.stopwatch()..start();
      // Fires the first tick almost immediately.
      _nextTickDueMs = 0;
      _checkTimer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => _maybeTick(),
      );
    } else {
      _checkTimer?.cancel();
      _stopwatch?.stop();
      // currentBeat is intentionally left as-is so a resumed play continues
      // visually where it left off.
      state = state.copyWith(isPlaying: false);
    }
  }

  void _maybeTick() {
    // Read state.bpm fresh on every call -- never cache it (Pitfall 3). bpm
    // already denotes quarter-note beats per minute in 4/4, so each of the
    // 4 in-bar ticks fires at this same interval; only currentBeat cycles
    // modulo 4 to track bar position.
    final intervalMs = (60000 / state.bpm).round();
    if (_stopwatch!.elapsedMilliseconds >= _nextTickDueMs) {
      final isAccent = state.currentBeat == 0;
      unawaited(
        ref.read(metronomeAudioServiceProvider).valueOrNull?.playTick(
              isAccent,
            ) ??
            Future.value(),
      );
      state = state.copyWith(currentBeat: (state.currentBeat + 1) % 4);
      // Scheduling the next tick relative to right now (not a fixed
      // bar-start offset) is what makes D-04's "tempo changes take effect
      // immediately on the next tick" true.
      _nextTickDueMs = _stopwatch!.elapsedMilliseconds + intervalMs;
    }
  }
}
