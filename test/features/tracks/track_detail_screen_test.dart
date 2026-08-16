import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/tracks/edit_track_screen.dart';
import 'package:cadence/features/tracks/track_detail_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient buildApiClient(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return ApiClient(
      baseUrl: 'http://localhost',
      getToken: () => 'test-token',
      onUnauthorized: () async {},
      httpClient: MockClient(handler),
    );
  }

  Widget wrap(ApiClient apiClient, CacheService cacheService) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: const MaterialApp(
        home: TrackDetailScreen(bandId: 'b1', trackId: 't1'),
      ),
    );
  }

  testWidgets(
    'shows a centered CircularProgressIndicator while getBandTrack is pending',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({'id': 't1', 'title': 'Song', 'artist': 'Artist'}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'no cache and network failure shows "Couldn\'t load tracks" + Retry',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'network_error', 'message': 'offline'}),
          500,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load tracks"), findsOneWidget);
      expect(
        find.text('Please check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'a full BandTrack response renders title/artist/duration/tempo/key/notes',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Full Track',
            'artist': 'Full Artist',
            'durationSeconds': 225,
            'tempo': 120,
            'key': 'C',
            'notes': 'Some notes',
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      // Appears twice: once in the AppBar title, once in the body heading.
      expect(find.text('Full Track'), findsNWidgets(2));
      expect(find.text('Full Artist'), findsOneWidget);
      expect(find.text('Duration: 3:45'), findsOneWidget);
      expect(find.text('Tempo: 120 BPM'), findsOneWidget);
      expect(find.text('Key: C'), findsOneWidget);
      expect(find.text('Notes: Some notes'), findsOneWidget);
    },
  );

  testWidgets(
    'the Edit IconButton is absent while trackAsync is loading',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({'id': 't1', 'title': 'Song', 'artist': 'Artist'}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.byIcon(Icons.edit), findsNothing);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'tapping Edit pushes EditTrackScreen with the currently-loaded track '
    'map passed as currentTrack',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Full Track',
            'artist': 'Full Artist',
            'durationSeconds': 225,
            'tempo': 120,
            'key': 'C',
            'notes': 'Some notes',
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byType(EditTrackScreen), findsOneWidget);
      final editScreen = tester.widget<EditTrackScreen>(
        find.byType(EditTrackScreen),
      );
      expect(editScreen.bandId, 'b1');
      expect(editScreen.trackId, 't1');
      expect(editScreen.currentTrack, {
        'id': 't1',
        'title': 'Full Track',
        'artist': 'Full Artist',
        'durationSeconds': 225,
        'tempo': 120,
        'key': 'C',
        'notes': 'Some notes',
      });
    },
  );
}
