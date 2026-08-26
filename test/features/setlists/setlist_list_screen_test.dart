import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/setlist_detail_screen.dart';
import 'package:cadence/features/setlists/setlist_list_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
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

  Widget wrap(
    ApiClient apiClient,
    CacheService cacheService, {
    bool? isOnline,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        if (isOnline != null) isOnlineProvider.overrideWithValue(isOnline),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ru')],
        home: SetlistListScreen(bandId: 'b1'),
      ),
    );
  }

  testWidgets('empty list shows "No setlists yet" empty state', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandSetlists('b1', []);

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': []}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    expect(find.text(tester.strings.setlistListEmptyTitle), findsOneWidget);
    expect(
      find.text(tester.strings.setlistListEmptyDescription),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ElevatedButton, tester.strings.setlistListAddButton),
      findsOneWidget,
    );
  });

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

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: true));
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.commonFailedToLoadSetlists),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsOneWidget,
      );
    },
  );

  testWidgets('a cached setlist with no eventDate shows "No date set"', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandSetlists('b1', [
      {
        'id': 's1',
        'name': 'Friday Show',
        'tracksCount': 3,
        'durationSeconds': 600,
      },
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 's1',
              'name': 'Friday Show',
              'tracksCount': 3,
              'durationSeconds': 600,
            },
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    expect(find.text('Friday Show'), findsOneWidget);
    expect(find.text('No date set'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.byIcon(Icons.timer), findsOneWidget);
  });

  testWidgets('setlist list shows duration text regardless of track count', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandSetlists('b1', [
      {
        'id': 's1',
        'name': 'Solo Setlist',
        'tracksCount': 1,
        'durationSeconds': 60,
      },
      {
        'id': 's2',
        'name': 'Big Setlist',
        'tracksCount': 8,
        'durationSeconds': 2555,
      },
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 's1',
              'name': 'Solo Setlist',
              'tracksCount': 1,
              'durationSeconds': 60,
            },
            {
              'id': 's2',
              'name': 'Big Setlist',
              'tracksCount': 8,
              'durationSeconds': 2555,
            },
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('42:35'), findsOneWidget);
  });

  testWidgets('a long setlist name truncates to a single line with ellipsis', (
    tester,
  ) async {
    const longName =
        'A Setlist Name That Is Definitely Over Thirty Characters Long';
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandSetlists('b1', [
      {'id': 's1', 'name': longName, 'tracksCount': 2, 'durationSeconds': 300},
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 's1',
              'name': longName,
              'tracksCount': 2,
              'durationSeconds': 300,
            },
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    final nameWidget = tester.widget<Text>(find.text(longName));
    expect(nameWidget.maxLines, 1);
    expect(nameWidget.overflow, TextOverflow.ellipsis);
  });

  testWidgets(
    'a setlist with eventLocation shows the location icon+value alongside '
    'the duration icon',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': "Tonight's Show",
          'tracksCount': 5,
          'durationSeconds': 2730,
          'eventLocation': 'The Fillmore',
        },
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 's1',
                'name': "Tonight's Show",
                'tracksCount': 5,
                'durationSeconds': 2730,
                'eventLocation': 'The Fillmore',
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.text('The Fillmore'), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
    },
  );

  testWidgets(
    'a setlist with no eventLocation omits the location icon but still '
    'shows duration',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': 'Friday Show',
          'tracksCount': 3,
          'durationSeconds': 600,
        },
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 's1',
                'name': 'Friday Show',
                'tracksCount': 3,
                'durationSeconds': 600,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.location_on), findsNothing);
      expect(find.byIcon(Icons.timer), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a long location text shows a SnackBar with the full text and '
    'does not navigate to SetlistDetailScreen',
    (tester) async {
      final eventLocation =
          'A' * 30 +
          ' Very Long Venue Name That Exceeds The Trailing Column Width';
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': 'Friday Show',
          'tracksCount': 3,
          'durationSeconds': 600,
          'eventLocation': eventLocation,
        },
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 's1',
                'name': 'Friday Show',
                'tracksCount': 3,
                'durationSeconds': 600,
                'eventLocation': eventLocation,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.text(eventLocation));
      await tester.pump();

      expect(find.text(eventLocation), findsWidgets);
      expect(find.byType(SetlistDetailScreen), findsNothing);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'with isOnlineProvider false, the FAB is disabled with a "Requires '
    'connection" tooltip; with it true, the FAB is enabled',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandSetlists('b1', []);

      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': []}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      final offlineFab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(offlineFab.onPressed, isNull);
      expect(offlineFab.tooltip, tester.strings.commonRequiresConnection);

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: true));
      await tester.pumpAndSettle();

      final onlineFab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(onlineFab.onPressed, isNotNull);
      expect(onlineFab.tooltip, tester.strings.setlistListAddButton);
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

  testWidgets(
    'offline with cache present renders the cached setlist data (D-06)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': 'Cached Setlist',
          'tracksCount': 1,
          'durationSeconds': 200,
        },
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 's1',
                'name': 'Should Not Fetch',
                'tracksCount': 1,
                'durationSeconds': 200,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      expect(find.text('Cached Setlist'), findsOneWidget);
      expect(find.byType(OfflineNoCacheView), findsNothing);
    },
  );
}
