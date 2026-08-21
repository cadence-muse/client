import 'dart:async';
import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/create_band_screen.dart';
import 'package:cadence/features/home/home_screen.dart';
import 'package:cadence/features/setlists/create_setlist_screen.dart';
import 'package:cadence/features/tracks/create_track_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/homepage_provider.dart';
import 'package:cadence/providers/navigation_provider.dart';
import 'package:cadence/widgets/offline_no_cache_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  // Routes `/api/band/list` to [bands] before delegating to [handler] for
  // everything else (`/api/homepage`, etc.) — since Task 1 wires "Add
  // Song"/"Add Setlist" to a band-picker backed by bandsListDataProvider,
  // any test that opens the picker needs the mock handler to answer that
  // path too, mirroring bands_screen_test.dart's per-path routing.
  ApiClient buildApiClient(
    Future<http.Response> Function(http.Request) handler, {
    List<Map<String, dynamic>> bands = const [],
  }) {
    return ApiClient(
      baseUrl: 'http://localhost',
      getToken: () => 'test-token',
      onUnauthorized: () async {},
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/band/list') {
          return http.Response(jsonEncode({'items': bands}), 200);
        }
        return handler(request);
      }),
    );
  }

  // Defaults isOnlineProvider to true so pre-existing tests keep exercising
  // the "online" path unless a test explicitly overrides it — under
  // online-first, HomepageData.build() reads isOnlineProvider directly, and
  // leaving it unmocked resolves to the fail-safe `false` default per
  // connectivity_provider.dart's doc comment, silently exercising the
  // offline branch in every test.
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
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets(
    'bandsCount 0 renders Quick Actions with Add Song/Add Setlist disabled '
    'and Add Band enabled (D-02/D-09/D-10)',
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
      // Online-first: build() fetches from the network before rendering
      // data, so a single frame no longer guarantees it has landed.
      await tester.pumpAndSettle();

      expect(find.text('Welcome, alice'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);

      final addBand = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add Band'),
      );
      expect(addBand.onPressed, isNotNull);

      final addSong = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add Song'),
      );
      expect(addSong.onPressed, isNull);

      final addSetlist = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Add Setlist'),
      );
      expect(addSetlist.onPressed, isNull);
    },
  );

  testWidgets(
    'bandsCount > 0 renders Quick Actions with all three buttons enabled '
    '(D-03/D-10)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({'username': 'alice', 'bandsCount': 2});

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'username': 'alice', 'bandsCount': 2}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, alice'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);

      for (final label in ['Add Band', 'Add Song', 'Add Setlist']) {
        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, label),
        );
        expect(button.onPressed, isNotNull, reason: '$label should be enabled');
      }
    },
  );

  testWidgets(
    'no cache and network failure shows "Couldn\'t load home" + Retry',
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

      expect(find.text("Couldn't load home"), findsOneWidget);
      expect(
        find.text('Please check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'username longer than 20 characters truncates to a single line with ellipsis',
    (tester) async {
      const longUsername = 'a_very_long_username_that_exceeds_twenty_chars';
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({
        'username': longUsername,
        'bandsCount': 3,
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'username': longUsername, 'bandsCount': 3}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(
        find.text('Welcome, $longUsername'),
      );
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'offline with no cache shows OfflineNoCacheView, with no Retry button '
    '(D-06)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'username': 'unused', 'bandsCount': 0}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineNoCacheView), findsOneWidget);
      expect(find.text('No cached data'), findsOneWidget);
      expect(find.text('Connect to the internet to load this'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing);
    },
  );

  testWidgets('switching to the Home tab a second time triggers a second '
      'GET /api/homepage call (D-01 tab-switch refetch)', (tester) async {
    final cacheService = CacheService.inMemory();
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      if (request.url.path == '/api/homepage') {
        callCount++;
      }
      return http.Response(
        jsonEncode({'username': 'alice', 'bandsCount': 1}),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();
    final initialCallCount = callCount;
    expect(initialCallCount, 1);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );

    // First selection of the Home tab (index 0) — no-op since it's already
    // 0, so switch away and back to actually trigger the listener.
    container.read(selectedTabIndexProvider.notifier).setIndex(1);
    container.read(selectedTabIndexProvider.notifier).setIndex(0);
    await tester.pumpAndSettle();
    expect(callCount, initialCallCount + 1);
  });

  testWidgets(
    "AppBar's LinearProgressIndicator shows only while refreshing with data "
    'already present, not during the initial cold-start load (D-08/D-09)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final firstFetchGate = Completer<void>();
      final secondFetchGate = Completer<void>();
      final apiClient = buildApiClient((request) async {
        callCount++;
        await (callCount == 1 ? firstFetchGate : secondFetchGate).future;
        return http.Response(
          jsonEncode({'username': 'alice', 'bandsCount': 1}),
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
      expect(find.text('Quick Actions'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      // container.refresh() (unlike invalidate()) synchronously invalidates
      // and re-reads in one step, matching D-08's "in-flight with data
      // already present" state deterministically for this assertion.
      container.refresh(homepageDataProvider);
      await tester.pump();

      // D-08: refreshing with data already present keeps old content
      // visible and shows the subtle indicator instead of the full-screen
      // spinner.
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      secondFetchGate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets('tapping "Add Band" navigates to CreateBandScreen (HOME-01)', (
    tester,
  ) async {
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

    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Band'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateBandScreen), findsOneWidget);
  });

  testWidgets(
    'tapping "Add Song" with bandsCount > 0 opens a bottom sheet listing '
    'each seeded band by name, and selecting one navigates to '
    'CreateTrackScreen carrying that band\'s id (HOME-02)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({'username': 'alice', 'bandsCount': 2});
      final apiClient = buildApiClient(
        (request) async {
          return http.Response(
            jsonEncode({'username': 'alice', 'bandsCount': 2}),
            200,
          );
        },
        bands: [
          {'id': 'a', 'name': 'The Testers'},
          {'id': 'b', 'name': 'The Others'},
        ],
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Song'));
      await tester.pumpAndSettle();

      expect(find.text('The Testers'), findsOneWidget);
      expect(find.text('The Others'), findsOneWidget);

      await tester.tap(find.text('The Testers'));
      await tester.pumpAndSettle();

      final screen = tester.widget<CreateTrackScreen>(
        find.byType(CreateTrackScreen),
      );
      expect(screen.bandId, 'a');
    },
  );

  testWidgets(
    'tapping "Add Setlist" with bandsCount > 0 opens a bottom sheet listing '
    'each seeded band by name, and selecting one navigates to '
    'CreateSetlistScreen carrying that band\'s id (HOME-02)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({'username': 'alice', 'bandsCount': 2});
      final apiClient = buildApiClient(
        (request) async {
          return http.Response(
            jsonEncode({'username': 'alice', 'bandsCount': 2}),
            200,
          );
        },
        bands: [
          {'id': 'a', 'name': 'The Testers'},
          {'id': 'b', 'name': 'The Others'},
        ],
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Setlist'));
      await tester.pumpAndSettle();

      expect(find.text('The Testers'), findsOneWidget);
      expect(find.text('The Others'), findsOneWidget);

      await tester.tap(find.text('The Others'));
      await tester.pumpAndSettle();

      final screen = tester.widget<CreateSetlistScreen>(
        find.byType(CreateSetlistScreen),
      );
      expect(screen.bandId, 'b');
    },
  );
}
