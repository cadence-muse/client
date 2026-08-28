import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/home/home_screen.dart';
import 'package:cadence/features/metronome/beat_indicator.dart';
import 'package:cadence/features/metronome/metronome_dial.dart';
import 'package:cadence/features/metronome/metronome_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../test_strings.dart';

/// Test-only [AudioCache] double. `audioplayers`' real [AudioCache] loads
/// each asset via `rootBundle` (works fine in `flutter test`) but then
/// copies it into the OS temp directory via `path_provider` and a real
/// [LocalFileSystem] write -- both hang indefinitely in this sandboxed test
/// environment (no `path_provider` platform channel handler, and no
/// permission to write outside the project directory). [getTempDir] is
/// itself `@visibleForTesting` on the real class specifically to support
/// swapping it out like this.
class _FakeAudioCache extends AudioCache {
  @override
  Future<String> getTempDir() async {
    final dir = Directory(
      '${Directory.current.path}/.dart_tool/test_audio_cache',
    );
    dir.createSync(recursive: true);
    return dir.path;
  }
}

/// `audioplayers`' real platform channel (`xyz.luan/audioplayers`) has no
/// native counterpart in a plain `flutter test` run -- an unmocked
/// `MethodChannel.invokeMethod` call hangs forever rather than throwing (no
/// response ever arrives), which would hang this widget test's
/// `pumpAndSettle` indefinitely. Swapping in this fake
/// [AudioplayersPlatformInterface] (the package's own supported test-double
/// seam, see its doc comment on `AudioplayersPlatformInterface.instance`)
/// lets [MetronomeAudioService.initialize] complete immediately with
/// `assetsLoaded == true`, without touching production code or the
/// [TickSoundPlayer] abstraction it's built on.
///
/// Each player's "prepared" event is emitted synchronously from
/// [setSourceUrl] (rather than relying on any real timing) because
/// `AudioPlayer.setSourceAsset` blocks on exactly that event before
/// resolving -- see `_completePrepared` in the `audioplayers` package
/// source.
class _FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final Map<String, StreamController<AudioEvent>> _controllers = {};

  StreamController<AudioEvent> _controllerFor(String playerId) => _controllers
      .putIfAbsent(playerId, () => StreamController<AudioEvent>.broadcast());

  @override
  Future<void> create(String playerId) async {}

  @override
  Future<void> dispose(String playerId) async {}

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> stop(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
  }) async {
    _controllerFor(playerId).add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes) async {
    _controllerFor(playerId).add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<int?> getDuration(String playerId) async => null;

  @override
  Future<int?> getCurrentPosition(String playerId) async => null;

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      _controllerFor(playerId).stream;
}

void main() {
  AudioplayersPlatformInterface.instance = _FakeAudioplayersPlatform();
  AudioCache.instance = _FakeAudioCache();
  // The real LocalFileSystem write (of the asset bytes into the temp dir
  // above) also hangs in this sandbox -- an in-memory filesystem sidesteps
  // real disk I/O entirely while still exercising AudioCache's real
  // asset-copy code path. `fileSystem` is `@visibleForTesting` on the real
  // class for exactly this purpose.
  AudioCache.fileSystem = MemoryFileSystem();

  ApiClient buildApiClient(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return ApiClient(
      baseUrl: 'http://localhost',
      getToken: () => 'test-token',
      onUnauthorized: () async {},
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/band/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        return handler(request);
      }),
    );
  }

  Widget wrap(ApiClient apiClient, CacheService cacheService) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        isOnlineProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ru')],
        home: HomeScreen(),
      ),
    );
  }

  testWidgets(
    'Homepage "Metronome" button opens MetronomeScreen at 120 BPM, then '
    'Play starts an audible+visual 4/4 beat cycle (METR-01/METR-03)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({'username': 'alice', 'bandsCount': 0});
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'username': 'alice', 'bandsCount': 0}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(ElevatedButton, tester.strings.homeMetronomeButton),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MetronomeScreen), findsOneWidget);
      // Plan 18-02: the BPM number is now painted directly onto a Canvas by
      // MetronomeDialPainter, not rendered as a Flutter Text widget -- read
      // the rendered value off MetronomeDial's own `bpm` property instead of
      // find.text('120').
      expect(tester.widget<MetronomeDial>(find.byType(MetronomeDial)).bpm, 120);

      // Tap the Play FAB -- icon swaps to pause after one pump.
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      // Sample currentBeat over 4 sequential beat intervals (500ms each at
      // 120 BPM) and assert the beat actually cycles over time.
      final observedBeats = <int>[];
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        observedBeats.add(
          tester.widget<BeatIndicator>(find.byType(BeatIndicator)).currentBeat,
        );
      }
      expect(observedBeats.toSet().length, greaterThan(1));
    },
  );
}
