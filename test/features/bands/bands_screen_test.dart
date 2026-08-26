import 'dart:async';
import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_avatar.dart';
import 'package:cadence/features/bands/bands_screen.dart';
import 'package:cadence/features/bands/create_band_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/bands_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/navigation_provider.dart';
import 'package:cadence/widgets/offline_no_cache_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../test_strings.dart';

void main() {
  // Routes `/api/me` to [profile] before delegating to [handler] for
  // everything else (band-list GET, mutations, etc.) -- since BandsScreen
  // now watches `profileDataProvider`, every mock handler must be able to
  // answer `GET /api/me` or the profile provider will error/hang.
  ApiClient buildApiClient(
    Future<http.Response> Function(http.Request) handler, {
    Map<String, dynamic> profile = const {'id': 'u1', 'username': 'tester'},
  }) {
    return ApiClient(
      baseUrl: 'http://localhost',
      getToken: () => 'test-token',
      onUnauthorized: () async {},
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(profile), 200);
        }
        return handler(request);
      }),
    );
  }

  // Defaults isOnlineProvider to true so pre-existing tests (which predate
  // OFFL-03's connectivity gating) keep exercising the "online" path unless a
  // test explicitly overrides it — real-app connectivity_plus resolves
  // AsyncLoading/AsyncError to `false` in this sandboxed test environment
  // with no platform-channel mock, which would otherwise disable every
  // mutation entry point by default.
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
        home: BandsScreen(),
      ),
    );
  }

  testWidgets('populated list renders a ListTile with BandAvatar per band', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([
      {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    // Online-first: build() fetches from the network before rendering data,
    // so a single frame no longer guarantees it has landed.
    await tester.pumpAndSettle();

    expect(find.text('The Testers'), findsOneWidget);
    expect(find.byType(BandAvatar), findsOneWidget);
  });

  testWidgets('empty list shows "No bands yet" empty state', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': []}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    expect(find.text(tester.strings.bandsEmptyTitle), findsOneWidget);
    expect(find.text(tester.strings.bandsEmptyDescription), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'no cache and network failure shows "Couldn\'t load bands" + Retry',
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

      expect(find.text(tester.strings.bandsErrorTitle), findsOneWidget);
      expect(find.text(tester.strings.commonConnectionError), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'band name longer than 30 characters truncates to a single line with ellipsis',
    (tester) async {
      const longName = 'A Band Name That Is Definitely Over Thirty Chars';
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': longName, 'membersCount': 1},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': longName, 'membersCount': 1},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text(longName));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'two bands with the same name but different ids render as two separate ListTiles',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Same', 'membersCount': 1},
        {'id': 'b', 'name': 'Same', 'membersCount': 1},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Same', 'membersCount': 1},
              {'id': 'b', 'name': 'Same', 'membersCount': 1},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(2));
    },
  );

  testWidgets(
    'offline with no cache shows OfflineNoCacheView, with no Retry button '
    '(D-06)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(
        wrap(apiClient, cacheService, isOnline: false),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OfflineNoCacheView), findsOneWidget);
      // OfflineNoCacheView itself isn't migrated to AppLocalizations until
      // 13-08, so it still renders literal English here.
      expect(find.text('No cached data'), findsOneWidget);
      expect(
        find.text('Connect to the internet to load this'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsNothing,
      );
    },
  );

  testWidgets(
    'switching to the Bands tab a second time triggers a second '
    'listBands() network call (D-01 tab-switch refetch)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/list') {
          callCount++;
        }
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
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
        tester.element(find.byType(BandsScreen)),
      );

      // First selection of the Bands tab (index 1).
      container.read(selectedTabIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();
      expect(callCount, initialCallCount + 1);

      // Switch away, then re-select the Bands tab a second time.
      container.read(selectedTabIndexProvider.notifier).setIndex(0);
      container.read(selectedTabIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();
      expect(callCount, initialCallCount + 2);
    },
  );

  testWidgets(
    "AppBar's LinearProgressIndicator shows only while refreshing with data "
    'already present, not during the initial cold-start load (D-08/D-09)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final firstFetchGate = Completer<void>();
      final secondFetchGate = Completer<void>();
      final apiClient = buildApiClient((request) async {
        if (request.url.path != '/api/band/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        callCount++;
        await (callCount == 1 ? firstFetchGate : secondFetchGate).future;
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
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
      expect(find.text('The Testers'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BandsScreen)),
      );
      // container.refresh() (unlike invalidate()) synchronously invalidates
      // and re-reads in one step, matching D-08's "in-flight with data
      // already present" state deterministically for this assertion.
      container.refresh(bandsListDataProvider);
      await tester.pump();

      // D-08: refreshing with data already present keeps old content
      // visible and shows the subtle indicator instead of the full-screen
      // spinner.
      expect(find.text('The Testers'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      secondFetchGate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets('FAB is disabled and tooltipped while offline', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
    await tester.pump();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNull);
    expect(fab.tooltip, tester.strings.commonRequiresConnection);

    await tester.pumpAndSettle();
  });

  testWidgets('FAB is enabled while online', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNotNull);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'tapping the FAB shows a bottom sheet with exactly "Create band" and '
    '"Join with code"',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ListTile, tester.strings.bandsCreateMenuItem),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ListTile, tester.strings.bandsJoinMenuItem),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsNWidgets(2));
    },
  );

  testWidgets('tapping "Create band" in the FAB menu navigates to CreateBandScreen', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ListTile, tester.strings.bandsCreateMenuItem),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CreateBandScreen), findsOneWidget);
  });

  testWidgets('tapping "Join with code" in the FAB menu opens the join dialog', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ListTile, tester.strings.bandsJoinMenuItem),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    // 'Join a band' is join_band_dialog.dart's own copy -- that file isn't
    // migrated until 13-04, so it still renders literal English here.
    expect(find.text('Join a band'), findsOneWidget);
  });

  testWidgets(
    'tapping the empty-state "Create Band" button navigates to CreateBandScreen',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(ElevatedButton, tester.strings.bandsCreateBandButton),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CreateBandScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a band whose ownerId matches the current profile shows '
    '"N member(s) • Owner" in trailing (BAND-10)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 1, 'ownerId': 'u1'},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'a',
                'name': 'The Testers',
                'membersCount': 1,
                'ownerId': 'u1',
              },
            ],
          }),
          200,
        );
      }, profile: {'id': 'u1', 'username': 'tester'});

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${tester.strings.memberCount(1)} • ${tester.strings.bandRoleOwner}',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a band whose ownerId does not match the current profile shows '
    '"N member(s) • Member" in trailing (BAND-10)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 1, 'ownerId': 'u1'},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'a',
                'name': 'The Testers',
                'membersCount': 1,
                'ownerId': 'u1',
              },
            ],
          }),
          200,
        );
      }, profile: {'id': 'u2', 'username': 'tester'});

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${tester.strings.memberCount(1)} • ${tester.strings.bandRoleMember}',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a band with no ownerId key shows just the member count, with no '
    'bullet or role (BAND-10 graceful degradation)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text(tester.strings.memberCount(1)), findsOneWidget);
    },
  );

  testWidgets(
    'a band with membersCount 5 shows the plural "5 members" (BAND-10)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 5},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 5},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text(tester.strings.memberCount(5)), findsOneWidget);
    },
  );

  testWidgets(
    'patchBandOwner() flips the trailing Owner/Member badge immediately, '
    'without a tab-switch or additional network fetch (D-10)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 1, 'ownerId': 'u1'},
      ]);
      var bandListCallCount = 0;
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/list') {
          bandListCallCount++;
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'a',
                'name': 'The Testers',
                'membersCount': 1,
                'ownerId': 'u1',
              },
            ],
          }),
          200,
        );
      }, profile: {'id': 'u1', 'username': 'tester'});

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${tester.strings.memberCount(1)} • ${tester.strings.bandRoleOwner}',
        ),
        findsOneWidget,
      );
      final callCountBeforePatch = bandListCallCount;

      // Simulates the exact patch a real ConfirmTransferOwnershipDialog
      // triggers (D-10) — invoked directly on the already-alive notifier
      // rather than via a real transfer flow, since that flow lives on
      // BandDetailScreen, not BandsScreen.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BandsScreen)),
      );
      container
          .read(bandsListDataProvider.notifier)
          .patchBandOwner('a', 'someOtherUserId');
      await tester.pump();

      expect(
        find.text(
          '${tester.strings.memberCount(1)} • ${tester.strings.bandRoleMember}',
        ),
        findsOneWidget,
      );
      expect(bandListCallCount, callCountBeforePatch);
    },
  );

  testWidgets(
    'memberCount(2) and memberCount(4) render the Russian "few" plural '
    'form',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 2},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 2},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            cacheServiceProvider.overrideWithValue(cacheService),
            isOnlineProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BandsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 участника'), findsOneWidget);

      final cacheService4 = CacheService.inMemory();
      await cacheService4.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 4},
      ]);
      final apiClient4 = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 4},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient4),
            cacheServiceProvider.overrideWithValue(cacheService4),
            isOnlineProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BandsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 участника'), findsOneWidget);
    },
  );

  testWidgets(
    'memberCount(11) renders the Russian "many" plural form (not "few")',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 11},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 11},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            cacheServiceProvider.overrideWithValue(cacheService),
            isOnlineProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const BandsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('11 участников'), findsOneWidget);
    },
  );
}
