import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/tracks/track_list_screen.dart';
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
    bool isOnline = true,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        isOnlineProvider.overrideWithValue(isOnline),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        home: const TrackListScreen(bandId: 'b1'),
      ),
    );
  }

  testWidgets(
    'populated list renders title, artist, and mm:ss duration for a cached track',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {
          'id': 't1',
          'title': 'Cached Song',
          'artist': 'Cached Artist',
          'durationSeconds': 225,
        },
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't1',
                'title': 'Cached Song',
                'artist': 'Cached Artist',
                'durationSeconds': 225,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('Cached Song'), findsOneWidget);
      expect(find.text('Cached Artist'), findsOneWidget);
      expect(find.text('3:45'), findsOneWidget);
    },
  );

  testWidgets('empty list shows "No tracks yet" empty state', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandTracks('b1', []);

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': []}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text(tester.strings.trackListEmptyTitle), findsOneWidget);
    expect(find.text(tester.strings.trackListEmptyDescription), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, tester.strings.trackListAddButton),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
  });

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

      expect(find.text(tester.strings.commonCouldntLoadTracks), findsOneWidget);
      expect(find.text(tester.strings.commonConnectionError), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'long track title and artist truncate to a single line with ellipsis',
    (tester) async {
      const longTitle = 'A Track Title That Is Definitely Over Thirty Chars';
      const longArtist = 'An Artist Name That Is Definitely Over Thirty Long';
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': longTitle, 'artist': longArtist},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 't1', 'title': longTitle, 'artist': longArtist},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      final titleWidget = tester.widget<Text>(find.text(longTitle));
      expect(titleWidget.maxLines, 1);
      expect(titleWidget.overflow, TextOverflow.ellipsis);

      final artistWidget = tester.widget<Text>(find.text(longArtist));
      expect(artistWidget.maxLines, 1);
      expect(artistWidget.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'the Add-track FAB is disabled with a "Requires connection" tooltip '
    'while offline',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', []);

      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': []}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);
      expect(fab.tooltip, tester.strings.commonRequiresConnection);
    },
  );

  testWidgets(
    'a cached track with a key shows the music_note icon, key value, and '
    'timer icon',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {
          'id': 't1',
          'title': 'Cached Song',
          'artist': 'Cached Artist',
          'durationSeconds': 225,
          'key': 'C',
        },
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't1',
                'title': 'Cached Song',
                'artist': 'Cached Artist',
                'durationSeconds': 225,
                'key': 'C',
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
    },
  );

  testWidgets('a cached track with no key entry omits the music_note icon but '
      'still shows the timer icon', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandTracks('b1', [
      {
        'id': 't1',
        'title': 'Cached Song',
        'artist': 'Cached Artist',
        'durationSeconds': 225,
      },
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 't1',
              'title': 'Cached Song',
              'artist': 'Cached Artist',
              'durationSeconds': 225,
            },
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.music_note), findsNothing);
    expect(find.byIcon(Icons.timer), findsOneWidget);
  });

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
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing);
    },
  );

  testWidgets(
    'the Add-track FAB is enabled with an "Add track" tooltip while online',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', []);

      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': []}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: true));
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNotNull);
      expect(fab.tooltip, tester.strings.trackListAddButton);
    },
  );
}
