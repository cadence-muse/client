import 'dart:async';
import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/songs/tracks_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/bands_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/navigation_provider.dart';
import 'package:cadence/providers/tracks_provider.dart';
import 'package:cadence/widgets/offline_no_cache_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../test_strings.dart';

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
  // the "online" path unless a test explicitly overrides it — real-app
  // connectivity_plus resolves AsyncLoading/AsyncError to `false` in this
  // sandboxed test environment with no platform-channel mock, which would
  // otherwise silently switch every existing test to the offline branch.
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
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ru')],
        home: TracksScreen(),
      ),
    );
  }

  testWidgets('zero bands renders the empty state with no dropdown present', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      if (request.url.path == '/api/band/list') {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      }
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    expect(find.text(tester.strings.tracksTabEmptyTitle), findsOneWidget);
    expect(
      find.text(tester.strings.tracksTabEmptyDescription),
      findsOneWidget,
    );
    expect(find.byType(DropdownButton<String?>), findsNothing);
  });

  testWidgets(
    'populated cross-band list renders each row\'s band badge, title, '
    'artist, and duration',
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
      await tester.pumpAndSettle();

      expect(find.text('Band One'), findsWidgets);
      expect(find.text('Band Two'), findsWidgets);
      expect(find.text('Track One'), findsOneWidget);
      expect(find.text('Track Two'), findsOneWidget);
      expect(find.text('Artist One'), findsOneWidget);
      expect(find.text('Artist Two'), findsOneWidget);
      expect(find.text('2:05'), findsOneWidget);
      expect(find.text('3:20'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets(
    'selecting a band in the dropdown re-fetches with that bandId as a '
    'query parameter',
    (tester) async {
      final cacheService = CacheService.inMemory();

      var sawFilterRequest = false;
      String? capturedBandIdFilter;
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

      expect(
        find.text(tester.strings.commonCouldntLoadTracks),
        findsOneWidget,
      );
      expect(
        find.text(tester.strings.commonConnectionError),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsOneWidget,
      );
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

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineNoCacheView), findsOneWidget);
      expect(find.text('No cached data'), findsOneWidget);
      expect(find.text('Connect to the internet to load this'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsNothing,
      );
    },
  );

  testWidgets('switching to the Tracks tab a second time triggers a second '
      'listUserTracks() network call (D-01 tab-switch refetch)', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([
      {'id': 'b1', 'name': 'Band One'},
    ]);
    var callCount = 0;
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
      callCount++;
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
    await tester.pumpAndSettle();
    final initialCallCount = callCount;
    expect(initialCallCount, 1);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TracksScreen)),
    );

    // First selection of the Tracks tab (index 2).
    container.read(selectedTabIndexProvider.notifier).setIndex(2);
    await tester.pumpAndSettle();
    expect(callCount, initialCallCount + 1);

    // Switch away, then re-select the Tracks tab a second time.
    container.read(selectedTabIndexProvider.notifier).setIndex(0);
    container.read(selectedTabIndexProvider.notifier).setIndex(2);
    await tester.pumpAndSettle();
    expect(callCount, initialCallCount + 2);
  });

  testWidgets(
    "AppBar's LinearProgressIndicator shows only while refreshing with data "
    'already present, not during the initial cold-start load (D-08/D-09)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'Band One'},
      ]);
      var callCount = 0;
      final firstFetchGate = Completer<void>();
      final secondFetchGate = Completer<void>();
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
        callCount++;
        await (callCount == 1 ? firstFetchGate : secondFetchGate).future;
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

      // D-09: cold start (no data yet) only shows the full-screen spinner,
      // not the AppBar's thin progress indicator. The fetch is deliberately
      // held open by firstFetchGate so this state is observable.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      firstFetchGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Track One'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TracksScreen)),
      );
      // container.refresh() (unlike invalidate()) synchronously invalidates
      // and re-reads in one step, matching D-08's "in-flight with data
      // already present" state deterministically for this assertion.
      container.refresh(userTracksListDataProvider);
      await tester.pump();

      // D-08: refreshing with data already present keeps old content
      // visible and shows the subtle indicator instead of the full-screen
      // spinner.
      expect(find.text('Track One'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      secondFetchGate.complete();
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
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Band One').last);
      await tester.pumpAndSettle();

      // Band One is now the persisted filter selection.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TracksScreen)),
      );
      expect(container.read(selectedBandIdFilterProvider), 'b1');
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
      expect(container.read(selectedBandIdFilterProvider), 'b1');
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
