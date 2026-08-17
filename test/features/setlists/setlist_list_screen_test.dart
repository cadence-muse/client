import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/setlist_list_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
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
      child: const MaterialApp(home: SetlistListScreen(bandId: 'b1')),
    );
  }

  testWidgets('empty list shows "No setlists yet" empty state', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandSetlists('b1', []);

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': []}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text('No setlists yet'), findsOneWidget);
    expect(
      find.text('Create a setlist or ask a bandmate to add one.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Add setlist'), findsOneWidget);

    await tester.pumpAndSettle();
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
    'a cached setlist with no eventDate shows "No date set"',
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
      await tester.pump();

      expect(find.text('Friday Show'), findsOneWidget);
      expect(find.text('No date set'), findsOneWidget);
      expect(find.text('3 tracks, 10m 0s'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'track-count pluralization: 1 track is singular, 8 tracks is plural',
    (tester) async {
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
      await tester.pump();

      expect(find.text('1 track, 1m 0s'), findsOneWidget);
      expect(find.text('8 tracks, 42m 35s'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a long setlist name truncates to a single line with ellipsis',
    (tester) async {
      const longName =
          'A Setlist Name That Is Definitely Over Thirty Characters Long';
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': longName,
          'tracksCount': 2,
          'durationSeconds': 300,
        },
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
      await tester.pump();

      final nameWidget = tester.widget<Text>(find.text(longName));
      expect(nameWidget.maxLines, 1);
      expect(nameWidget.overflow, TextOverflow.ellipsis);

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

      await tester.pumpWidget(
        wrap(apiClient, cacheService, isOnline: false),
      );
      await tester.pump();

      final offlineFab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(offlineFab.onPressed, isNull);
      expect(offlineFab.tooltip, 'Requires connection');

      await tester.pumpAndSettle();

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: true));
      await tester.pump();

      final onlineFab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(onlineFab.onPressed, isNotNull);
      expect(onlineFab.tooltip, 'Add setlist');

      await tester.pumpAndSettle();
    },
  );
}
