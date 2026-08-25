import 'dart:async';
import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/setlist_detail_screen.dart';
import 'package:cadence/features/setlists/setlists_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/bands_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/navigation_provider.dart';
import 'package:cadence/providers/setlists_provider.dart';
import 'package:cadence/widgets/offline_no_cache_view.dart';
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

  // Defaults isOnlineProvider to true so pre-existing tests keep exercising
  // the online path unless a test explicitly overrides it — real-app
  // connectivity_plus resolves AsyncLoading/AsyncError to `false` in this
  // sandboxed test environment with no platform-channel mock, which would
  // otherwise disable both bandsListDataProvider's and
  // userSetlistsListDataProvider's online-first fetch by default.
  Widget wrap(
    ApiClient apiClient,
    CacheService cacheService, {
    bool isOnline = true,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        isOnlineProvider.overrideWithValue(isOnline),
      ],
      child: const MaterialApp(home: SetlistsScreen()),
    );
  }

  testWidgets(
    'zero bands renders the empty state with no dropdown and no button',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('No setlists'), findsOneWidget);
      expect(
        find.text('Create setlists in a band to see them here.'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButton<String?>), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    },
  );

  testWidgets(
    'populated cross-band list renders each row\'s band-name subtitle, '
    'name title, and tracksAndDuration trailing text',
    (tester) async {
      final cacheService = CacheService.inMemory();
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
      await tester.pumpAndSettle();

      expect(find.text('Setlist One'), findsOneWidget);
      expect(find.text('Setlist Two'), findsOneWidget);
      expect(find.text('Band One'), findsWidgets);
      expect(find.text('Band Two'), findsWidgets);
      expect(find.text('8 tracks, 42:35'), findsOneWidget);
      expect(find.text('1 track, 3:20'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a band in the dropdown re-fetches with that bandId as a '
    'query parameter',
    (tester) async {
      final cacheService = CacheService.inMemory();

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
    'no FloatingActionButton is present (SETL-10 is view-only)',
    (tester) async {
      final cacheService = CacheService.inMemory();
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
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets(
    'offline with no cache shows OfflineNoCacheView, with no Retry button '
    '(D-06)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'Band One'},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(
        wrap(apiClient, cacheService, isOnline: false),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OfflineNoCacheView), findsOneWidget);
      expect(find.text('No cached data'), findsOneWidget);
      expect(
        find.text('Connect to the internet to load this'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing);
    },
  );

  testWidgets(
    'switching to the Setlists tab a second time triggers a second '
    'listUserSetlists() network call (D-01 tab-switch refetch)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      var setlistsCallCount = 0;
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
        setlistsCallCount++;
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
      await tester.pumpAndSettle();
      final initialCallCount = setlistsCallCount;
      expect(initialCallCount, 1);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetlistsScreen)),
      );

      // First selection of the Setlists tab (index 3).
      container.read(selectedTabIndexProvider.notifier).setIndex(3);
      await tester.pumpAndSettle();
      expect(setlistsCallCount, initialCallCount + 1);

      // Switch away, then re-select the Setlists tab a second time.
      container.read(selectedTabIndexProvider.notifier).setIndex(0);
      container.read(selectedTabIndexProvider.notifier).setIndex(3);
      await tester.pumpAndSettle();
      expect(setlistsCallCount, initialCallCount + 2);
    },
  );

  testWidgets(
    "AppBar's LinearProgressIndicator shows only while refreshing with data "
    'already present, not once settled (D-08)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      var setlistsCallCount = 0;
      final refetchGate = Completer<void>();
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
        setlistsCallCount++;
        if (setlistsCallCount > 1) {
          await refetchGate.future;
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
      await tester.pumpAndSettle();

      expect(find.text('Setlist One'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetlistsScreen)),
      );
      // container.refresh() (unlike invalidate()) synchronously invalidates
      // and re-reads in one step, matching D-08's "in-flight with data
      // already present" state deterministically for this assertion.
      container.refresh(userSetlistsListDataProvider);
      await tester.pump();

      // D-08: refreshing with data already present keeps old content
      // visible and shows the subtle indicator instead of the full-screen
      // spinner.
      expect(find.text('Setlist One'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      refetchGate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'CR-02 regression: filtered band disappearing from the bands list '
    'falls back to "All bands" instead of crashing the DropdownButton',
    (tester) async {
      final cacheService = CacheService.inMemory();
      var bandsIncludeB1 = true;

      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/list') {
          return http.Response(
            jsonEncode({
              'items': [
                if (bandsIncludeB1) {'id': 'b1', 'name': 'Band One'},
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
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Band One').last);
      await tester.pumpAndSettle();

      // Band One is now the persisted filter selection.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetlistsScreen)),
      );
      expect(container.read(selectedSetlistBandIdFilterProvider), 'b1');
      expect(
        tester
            .widget<DropdownButton<String?>>(
              find.byType(DropdownButton<String?>),
            )
            .value,
        'b1',
      );

      bandsIncludeB1 = false;
      container.invalidate(bandsListDataProvider);
      // pumpAndSettle rethrows any exception raised during the rebuild —
      // without the CR-02 fix, DropdownButton's "exactly one item with
      // this value" assertion fires here.
      await tester.pumpAndSettle();

      // The persisted filter selection is untouched (still 'b1'), but the
      // rendered dropdown clamps to `null` ("All bands") since 'b1' no
      // longer matches any item.
      expect(container.read(selectedSetlistBandIdFilterProvider), 'b1');
      expect(
        tester
            .widget<DropdownButton<String?>>(
              find.byType(DropdownButton<String?>),
            )
            .value,
        isNull,
      );
    },
  );
}
