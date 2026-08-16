import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/setlist_detail_screen.dart';
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
        home: SetlistDetailScreen(bandId: 'b1', setlistId: 's1'),
      ),
    );
  }

  testWidgets(
    'shows a centered CircularProgressIndicator while getSetlist is pending',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
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
    'no cache and network failure shows the single-line Setlist error copy '
    '+ Retry',
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

      expect(
        find.text('Failed to load setlists. Tap to try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'a full BandSetlist response renders name/location/date/duration/tracks',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Full Setlist',
            'durationSeconds': 2555,
            'eventLocation': 'The Venue',
            'eventDate': '2026-09-01',
            'tracks': [
              {
                'trackId': 't1',
                'position': 0,
                'title': 'Song One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Song Two',
                'artist': 'Artist Two',
                'durationSeconds': 200,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      // Appears twice: once in the AppBar title, once in the body heading.
      expect(find.text('Full Setlist'), findsNWidgets(2));
      expect(find.text('The Venue'), findsOneWidget);
      expect(find.text('Sep 1, 2026'), findsOneWidget);
      expect(find.text('Duration: 42m 35s'), findsOneWidget);
      expect(find.text('Tracks (2)'), findsOneWidget);
      expect(find.text('Song One'), findsOneWidget);
      expect(find.text('Song Two'), findsOneWidget);
      expect(find.text('Artist One'), findsOneWidget);
      expect(find.text('Artist Two'), findsOneWidget);
    },
  );

  testWidgets(
    'eventLocation/eventDate are omitted entirely (no placeholder) when both '
    'are null',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Minimal Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('No date set'), findsNothing);
      expect(find.text('No tracks in this setlist'), findsOneWidget);
    },
  );

  testWidgets(
    'zero tracks shows "No tracks in this setlist" and "Duration: 0m 0s"',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Empty Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('No tracks in this setlist'), findsOneWidget);
      expect(find.text('Duration: 0m 0s'), findsOneWidget);
    },
  );
}
