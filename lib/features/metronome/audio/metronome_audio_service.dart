import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tick_sound_player.dart';

part 'metronome_audio_service.g.dart';

/// Wraps the two tick [TickSoundPlayer]s (accent/regular) behind a single
/// asset-load lifecycle (D-01/D-03). Degrades gracefully on load failure
/// (V7/T-18-02) -- [playTick] simply no-ops rather than throwing, so a
/// broken audio asset never crashes the beat loop or surfaces a raw
/// exception/asset path to the user.
class MetronomeAudioService {
  // Named external parameters (accentPlayer/regularPlayer) intentionally
  // differ from the private field names they populate, so the
  // `prefer_initializing_formals` suggestion (which would rename the public
  // parameters to `_accentPlayer`/`_regularPlayer`) doesn't apply here.
  MetronomeAudioService({
    required TickSoundPlayer accentPlayer,
    required TickSoundPlayer regularPlayer,
    // ignore: prefer_initializing_formals
  }) : _accentPlayer = accentPlayer,
       // ignore: prefer_initializing_formals
       _regularPlayer = regularPlayer;

  final TickSoundPlayer _accentPlayer;
  final TickSoundPlayer _regularPlayer;

  bool _assetsLoaded = false;

  /// Exposed read-only for tests -- true once both tick assets have loaded
  /// successfully.
  bool get assetsLoaded => _assetsLoaded;

  Future<void> initialize() async {
    // Initialize both players independently (via Future.wait) rather than
    // sequentially under one try/catch -- a failure in one must not skip the
    // other's initialize() call, which would leave its `late final` player
    // field unset and make dispose() throw later.
    final results = await Future.wait([
      _initPlayer(_accentPlayer),
      _initPlayer(_regularPlayer),
    ]);
    _assetsLoaded = results.every((ok) => ok);
  }

  Future<bool> _initPlayer(TickSoundPlayer player) async {
    try {
      await player.initialize();
      return true;
    } catch (e) {
      // T-18-02: never rethrow, never surface the raw exception/asset path
      // to the user -- the UI-SPEC error copy is fixed and generic.
      debugPrint('MetronomeAudioService: failed to load tick asset: $e');
      return false;
    }
  }

  /// No-ops if assets failed to load. Failures during playback (a mid-play
  /// plugin hiccup) are caught and logged, never rethrown -- a single bad
  /// tick must not crash the beat loop.
  Future<void> playTick(bool isAccent) async {
    if (!_assetsLoaded) return;
    try {
      await (isAccent ? _accentPlayer : _regularPlayer).play();
    } catch (e) {
      debugPrint('MetronomeAudioService: failed to play tick: $e');
    }
  }

  void dispose() {
    // Defensive against a player whose initialize() never completed --
    // dispose() must never throw (T-18-02's graceful-degradation contract
    // applies to teardown too, not just playback).
    unawaited(_accentPlayer.dispose().catchError((_) {}));
    unawaited(_regularPlayer.dispose().catchError((_) {}));
  }
}

@riverpod
Future<MetronomeAudioService> metronomeAudioService(
  MetronomeAudioServiceRef ref,
) async {
  final service = MetronomeAudioService(
    accentPlayer: AudioPlayersTickSoundPlayer('audio/metronome_accent.wav'),
    regularPlayer: AudioPlayersTickSoundPlayer('audio/metronome_regular.wav'),
  );
  await service.initialize();
  ref.onDispose(service.dispose);
  return service;
}
