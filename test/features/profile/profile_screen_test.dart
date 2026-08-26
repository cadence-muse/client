import 'dart:async';
import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/profile/profile_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/navigation_provider.dart';
import 'package:cadence/providers/profile_provider.dart';
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
  // the "online" path unless a test explicitly overrides it — under
  // online-first, ProfileData.build() reads isOnlineProvider directly, and
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
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ru')],
        home: ProfileScreen(),
      ),
    );
  }

  testWidgets('online + no cache renders the fresh network data', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'id': 'u1', 'username': 'freshuser'}),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    // Online-first: build() fetches from the network before rendering data,
    // so a single frame no longer guarantees it has landed.
    await tester.pumpAndSettle();

    expect(find.text('freshuser'), findsOneWidget);
  });

  testWidgets(
    'no cache and network failure shows error state with Retry button',
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

      expect(find.text(tester.strings.profileErrorTitle), findsOneWidget);
      expect(find.text(tester.strings.commonConnectionError), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a stale seeded cache is ignored in favor of the fresh network fetch',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'oldname'});

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'newname'}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('newname'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'tapping refresh twice quickly triggers exactly one network call',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'user'});

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode({'id': 'u1', 'username': 'user'}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      // Let build()'s own online-first fetch complete before measuring the
      // refresh button's own dedup behavior.
      await tester.pumpAndSettle();
      callCount = 0;

      await tester.tap(find.byTooltip(tester.strings.commonRefresh));
      await tester.tap(find.byTooltip(tester.strings.commonRefresh));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    },
  );

  testWidgets(
    'username longer than 20 characters truncates to a single line with ellipsis',
    (tester) async {
      const longUsername = 'a_very_long_username_that_exceeds_twenty_chars';
      final cacheService = CacheService.inMemory();

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 'u1', 'username': longUsername}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text(longUsername));
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
          jsonEncode({'id': 'u1', 'username': 'unused'}),
          200,
        );
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

  testWidgets('switching to the Profile tab a second time triggers a second '
      'GET /api/me call (D-01 tab-switch refetch)', (tester) async {
    final cacheService = CacheService.inMemory();
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      if (request.url.path == '/api/me') {
        callCount++;
      }
      return http.Response(jsonEncode({'id': 'u1', 'username': 'user'}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();
    final initialCallCount = callCount;
    expect(initialCallCount, 1);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileScreen)),
    );

    // First selection of the Profile tab (index 4).
    container.read(selectedTabIndexProvider.notifier).setIndex(4);
    await tester.pumpAndSettle();
    expect(callCount, initialCallCount + 1);

    // Switch away, then re-select the Profile tab a second time.
    container.read(selectedTabIndexProvider.notifier).setIndex(0);
    container.read(selectedTabIndexProvider.notifier).setIndex(4);
    await tester.pumpAndSettle();
    expect(callCount, initialCallCount + 2);
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
        return http.Response(jsonEncode({'id': 'u1', 'username': 'user'}), 200);
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
      expect(find.text('user'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileScreen)),
      );
      // container.refresh() (unlike invalidate()) synchronously invalidates
      // and re-reads in one step, matching D-08's "in-flight with data
      // already present" state deterministically for this assertion.
      container.refresh(profileDataProvider);
      await tester.pump();

      // D-08: refreshing with data already present keeps old content
      // visible and shows the subtle indicator instead of the full-screen
      // spinner.
      expect(find.text('user'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      secondFetchGate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );
}
