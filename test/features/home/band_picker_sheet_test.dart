import 'dart:async';
import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/home/band_picker_sheet.dart';
import 'package:cadence/features/setlists/create_setlist_screen.dart';
import 'package:cadence/features/tracks/create_track_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
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

  // Mirrors join_band_dialog_test.dart's harness pattern for testing a
  // standalone show*() function: a trigger button + Consumer supplies the
  // WidgetRef, isOnlineProvider defaults to true so the picker's data
  // provider exercises the online-first fetch path unless a test overrides
  // it.
  Widget wrap(
    ApiClient apiClient,
    CacheService cacheService, {
    bool isOnline = true,
    bool forTrack = true,
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
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Builder(
              builder: (innerContext) => ElevatedButton(
                onPressed: () =>
                    showBandPickerSheet(innerContext, ref, forTrack: forTrack),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a loading spinner while bands are still loading', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    final gate = Completer<http.Response>();
    final apiClient = buildApiClient((request) async => gate.future);

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.tap(find.text('Open'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete(http.Response(jsonEncode({'items': <dynamic>[]}), 200));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'shows a short generic error message on a bandsListDataProvider error, '
    'with no interpolated exception/stack-trace text (V7)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'network_error', 'message': 'offline'}),
          500,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await openSheet(tester);

      expect(find.text(tester.strings.bandPickerErrorMessage), findsOneWidget);
      expect(find.textContaining('network_error'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    },
  );

  testWidgets('renders one ListTile per band, showing the band name only', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([
      {'id': 'a', 'name': 'The Testers'},
      {'id': 'b', 'name': 'The Others'},
    ]);
    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'a', 'name': 'The Testers'},
            {'id': 'b', 'name': 'The Others'},
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await openSheet(tester);

    expect(find.text('The Testers'), findsOneWidget);
    expect(find.text('The Others'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets(
    'selecting a band with forTrack true navigates to CreateTrackScreen '
    'carrying that band\'s id',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers'},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers'},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, forTrack: true));
      await openSheet(tester);
      await tester.tap(find.text('The Testers'));
      await tester.pumpAndSettle();

      final screen = tester.widget<CreateTrackScreen>(
        find.byType(CreateTrackScreen),
      );
      expect(screen.bandId, 'a');
    },
  );

  testWidgets(
    'selecting a band with forTrack false navigates to CreateSetlistScreen '
    'carrying that band\'s id',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers'},
      ]);
      // CreateSetlistScreen (mounted after selection) additionally fetches
      // this band's track list -- route by path so that fetch resolves to
      // an empty list rather than reusing the band-list shape.
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 'a', 'name': 'The Testers'},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, forTrack: false));
      await openSheet(tester);
      await tester.tap(find.text('The Testers'));
      await tester.pumpAndSettle();

      final screen = tester.widget<CreateSetlistScreen>(
        find.byType(CreateSetlistScreen),
      );
      expect(screen.bandId, 'a');
    },
  );

  testWidgets(
    'a band name longer than the picker ListTile width truncates to one '
    'line with ellipsis',
    (tester) async {
      const longName = 'A Band Name That Is Definitely Over Thirty Chars';
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': longName},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': longName},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await openSheet(tester);

      final textWidget = tester.widget<Text>(find.text(longName));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'with isOnline false and bands pre-seeded in the cache, opening the '
    'picker still lists the cached bands (Phase 7 online-first fallback)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
      ]);
      final apiClient = buildApiClient((request) async {
        throw StateError('Unexpected network call while offline');
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await openSheet(tester);

      expect(find.text('Cached Band'), findsOneWidget);
    },
  );
}
