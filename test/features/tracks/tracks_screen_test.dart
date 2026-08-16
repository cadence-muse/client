import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/songs/tracks_screen.dart';
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
      child: const MaterialApp(home: TracksScreen()),
    );
  }

  testWidgets(
    'zero bands renders the empty state with no dropdown present',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.text('No tracks'), findsOneWidget);
      expect(
        find.text('Create tracks in a band to see them here.'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButton<String?>), findsNothing);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'populated cross-band list renders each row\'s band badge, title, '
    'artist, and duration',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'Band One'},
        {'id': 'b2', 'name': 'Band Two'},
      ]);
      await cacheService.writeUserTracks(null, [
        {
          'id': 't1',
          'title': 'Track One',
          'artist': 'Artist One',
          'durationSeconds': 125,
          'bandId': 'b1',
          'bandName': 'Band One',
        },
        {
          'id': 't2',
          'title': 'Track Two',
          'artist': 'Artist Two',
          'durationSeconds': 200,
          'bandId': 'b2',
          'bandName': 'Band Two',
        },
      ]);

      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 'b1', 'name': 'Band One'},
                {'id': 'b2', 'name': 'Band Two'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't1',
                'title': 'Track One',
                'artist': 'Artist One',
                'durationSeconds': 125,
                'bandId': 'b1',
                'bandName': 'Band One',
              },
              {
                'id': 't2',
                'title': 'Track Two',
                'artist': 'Artist Two',
                'durationSeconds': 200,
                'bandId': 'b2',
                'bandName': 'Band Two',
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      // Two pumps: one for bandsListDataProvider's cache-hit resolution,
      // one for userTracksListDataProvider's — the latter's Expanded subtree
      // isn't built until the former resolves non-empty.
      await tester.pump();
      await tester.pump();

      expect(find.text('Band One'), findsWidgets);
      expect(find.text('Band Two'), findsWidgets);
      expect(find.text('Track One'), findsOneWidget);
      expect(find.text('Track Two'), findsOneWidget);
      expect(find.text('Artist One'), findsOneWidget);
      expect(find.text('Artist Two'), findsOneWidget);
      expect(find.text('2:05'), findsOneWidget);
      expect(find.text('3:20'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'selecting a band in the dropdown re-fetches with that bandId as a '
    'query parameter',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'Band One'},
        {'id': 'b2', 'name': 'Band Two'},
      ]);
      await cacheService.writeUserTracks(null, [
        {
          'id': 't1',
          'title': 'Track One',
          'artist': 'Artist One',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);

      String? capturedBandIdFilter;
      var sawFilterRequest = false;
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 'b1', 'name': 'Band One'},
                {'id': 'b2', 'name': 'Band Two'},
              ],
            }),
            200,
          );
        }
        if (request.url.queryParameters.containsKey('bandId')) {
          sawFilterRequest = true;
          capturedBandIdFilter = request.url.queryParameters['bandId'];
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't1',
                'title': 'Track One',
                'artist': 'Artist One',
                'bandId': 'b1',
                'bandName': 'Band One',
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Band One').last);
      await tester.pumpAndSettle();

      expect(sawFilterRequest, isTrue);
      expect(capturedBandIdFilter, 'b1');
    },
  );

  testWidgets(
    'network failure with no cache shows "Couldn\'t load tracks" + Retry',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'Band One'},
      ]);

      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 'b1', 'name': 'Band One'},
              ],
            }),
            200,
          );
        }
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
}
