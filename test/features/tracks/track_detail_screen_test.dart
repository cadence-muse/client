import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/tracks/edit_track_screen.dart';
import 'package:cadence/features/tracks/track_detail_screen.dart';
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
        home: const TrackDetailScreen(bandId: 'b1', trackId: 't1'),
      ),
    );
  }

  testWidgets(
    'shows a centered CircularProgressIndicator while getBandTrack is pending',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({'id': 't1', 'title': 'Track', 'artist': 'Artist'}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

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
    'offline with no cache shows OfflineNoCacheView, with no Retry button '
    '(D-06)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 't1', 'title': 'Track', 'artist': 'Artist'}),
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

  testWidgets(
    'a full BandTrack response renders title/artist/duration/tempo/key/notes',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Full Track',
            'artist': 'Full Artist',
            'durationSeconds': 225,
            'tempo': 120,
            'key': 'C',
            'notes': 'Some notes',
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      // Appears twice: once in the AppBar title, once in the body heading.
      expect(find.text('Full Track'), findsNWidgets(2));
      expect(find.text('Full Artist'), findsOneWidget);
      expect(find.text('3:45'), findsOneWidget);
      expect(
        find.text(tester.strings.trackDetailTempoLine(120)),
        findsOneWidget,
      );
      expect(find.text('C'), findsOneWidget);
      expect(find.text('Some notes'), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.byIcon(Icons.notes), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the notes row shows the full untruncated notes text in a '
    'SnackBar',
    (tester) async {
      final longNotes =
          'This is a very long notes string that goes on and on and on '
          'and on and on and on and on and on and on and on and on and '
          'on and on and on and on and on to exceed two hundred '
          'characters in total length for the truncation test case.';
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Full Track',
            'artist': 'Full Artist',
            'durationSeconds': 225,
            'notes': longNotes,
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(longNotes),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the Edit IconButton is absent while trackAsync is loading', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return http.Response(
        jsonEncode({'id': 't1', 'title': 'Track', 'artist': 'Artist'}),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.byIcon(Icons.edit), findsNothing);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'tapping Edit pushes EditTrackScreen with the currently-loaded track '
    'map passed as currentTrack',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Full Track',
            'artist': 'Full Artist',
            'durationSeconds': 225,
            'tempo': 120,
            'key': 'C',
            'notes': 'Some notes',
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byType(EditTrackScreen), findsOneWidget);
      final editScreen = tester.widget<EditTrackScreen>(
        find.byType(EditTrackScreen),
      );
      expect(editScreen.bandId, 'b1');
      expect(editScreen.trackId, 't1');
      expect(editScreen.currentTrack, {
        'id': 't1',
        'title': 'Full Track',
        'artist': 'Full Artist',
        'durationSeconds': 225,
        'tempo': 120,
        'key': 'C',
        'notes': 'Some notes',
      });
    },
  );

  testWidgets(
    'the Edit IconButton is disabled and the Delete ListTile is disabled '
    'with "Requires connection" tooltip while offline',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTrackDetail('b1', 't1', {
        'id': 't1',
        'title': 'Track',
        'artist': 'Artist',
      });
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 't1', 'title': 'Track', 'artist': 'Artist'}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      final editButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.edit),
          matching: find.byType(IconButton),
        ),
      );
      expect(editButton.onPressed, isNull);
      expect(editButton.tooltip, tester.strings.commonRequiresConnection);

      final deleteTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, tester.strings.commonDelete),
      );
      expect(deleteTile.enabled, isFalse);
      expect(deleteTile.onTap, isNull);
    },
  );

  testWidgets(
    'the Edit IconButton and Delete ListTile are enabled while online',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 't1', 'title': 'Track', 'artist': 'Artist'}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: true));
      await tester.pumpAndSettle();

      final editButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.edit),
          matching: find.byType(IconButton),
        ),
      );
      expect(editButton.onPressed, isNotNull);
      expect(editButton.tooltip, tester.strings.trackDetailEditTooltip);

      final deleteTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, tester.strings.commonDelete),
      );
      expect(deleteTile.enabled, isTrue);
      expect(deleteTile.onTap, isNotNull);
    },
  );
}
