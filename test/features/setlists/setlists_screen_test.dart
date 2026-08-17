import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/setlist_detail_screen.dart';
import 'package:cadence/features/setlists/setlists_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/widgets/sync_status_badge.dart';
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
      child: const MaterialApp(home: SetlistsScreen()),
    );
  }

  testWidgets(
    'zero bands renders the empty state with no dropdown and no button',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.text('No setlists'), findsOneWidget);
      expect(
        find.text('Create setlists in a band to see them here.'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButton<String?>), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'populated cross-band list renders each row\'s band-name subtitle, '
    'name title, and tracksAndDuration trailing text',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'Band One'},
        {'id': 'b2', 'name': 'Band Two'},
      ]);
      await cacheService.writeUserSetlists(null, [
        {
          'id': 's1',
          'name': 'Setlist One',
          'tracksCount': 8,
          'durationSeconds': 2555,
          'bandId': 'b1',
          'bandName': 'Band One',
        },
        {
          'id': 's2',
          'name': 'Setlist Two',
          'tracksCount': 1,
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
                'id': 's1',
                'name': 'Setlist One',
                'tracksCount': 8,
                'durationSeconds': 2555,
                'bandId': 'b1',
                'bandName': 'Band One',
              },
              {
                'id': 's2',
                'name': 'Setlist Two',
                'tracksCount': 1,
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
      // one for userSetlistsListDataProvider's — the latter's Expanded
      // subtree isn't built until the former resolves non-empty.
      await tester.pump();
      await tester.pump();

      expect(find.text('Setlist One'), findsOneWidget);
      expect(find.text('Setlist Two'), findsOneWidget);
      expect(find.text('Band One'), findsWidgets);
      expect(find.text('Band Two'), findsWidgets);
      expect(find.text('8 tracks, 42m 35s'), findsOneWidget);
      expect(find.text('1 track, 3m 20s'), findsOneWidget);

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
      await cacheService.writeUserSetlists(null, [
        {
          'id': 's1',
          'name': 'Setlist One',
          'tracksCount': 1,
          'durationSeconds': 200,
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
                'id': 's1',
                'name': 'Setlist One',
                'tracksCount': 1,
                'durationSeconds': 200,
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
    'network failure with no cache shows "Failed to load setlists. Tap to '
    'try again." + Retry',
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

      expect(
        find.text('Failed to load setlists. Tap to try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a row navigates to SetlistDetailScreen using the row\'s own '
    'bandId/id fields, not the currently-selected filter',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'Band One'},
        {'id': 'b2', 'name': 'Band Two'},
      ]);
      await cacheService.writeUserSetlists(null, [
        {
          'id': 's2',
          'name': 'Setlist Two',
          'tracksCount': 1,
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
        if (request.url.path.contains('/setlist/list')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's2',
                  'name': 'Setlist Two',
                  'tracksCount': 1,
                  'durationSeconds': 200,
                  'bandId': 'b2',
                  'bandName': 'Band Two',
                },
              ],
            }),
            200,
          );
        }
        // SetlistDetailScreen's underlying setlistDetailDataProvider fetch.
        return http.Response(
          jsonEncode({
            'id': 's2',
            'name': 'Setlist Two',
            'durationSeconds': 200,
            'tracks': <Map<String, dynamic>>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Setlist Two'));
      await tester.pumpAndSettle();

      expect(find.byType(SetlistDetailScreen), findsOneWidget);
      final detailScreen = tester.widget<SetlistDetailScreen>(
        find.byType(SetlistDetailScreen),
      );
      expect(detailScreen.bandId, 'b2');
      expect(detailScreen.setlistId, 's2');
    },
  );

  testWidgets(
    'SyncStatusBadge is present once the global list loads; no '
    'FloatingActionButton is present (SETL-10 is view-only)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'Band One'},
      ]);
      await cacheService.writeUserSetlists(null, [
        {
          'id': 's1',
          'name': 'Setlist One',
          'tracksCount': 1,
          'durationSeconds': 200,
          'bandId': 'b1',
          'bandName': 'Band One',
        },
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
          jsonEncode({
            'items': [
              {
                'id': 's1',
                'name': 'Setlist One',
                'tracksCount': 1,
                'durationSeconds': 200,
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
      await tester.pump();

      expect(find.byType(SyncStatusBadge), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.pumpAndSettle();
    },
  );
}
