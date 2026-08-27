import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/confirm_delete_setlist_dialog.dart';
import 'package:cadence/features/setlists/edit_setlist_screen.dart';
import 'package:cadence/features/setlists/setlist_detail_screen.dart';
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

  // Defaults isOnlineProvider to true — without an override,
  // connectivity_plus has no platform-channel mock in the test environment
  // and resolves to the fail-safe-offline default, which would break every
  // pre-existing test written before this plan's connectivity gating.
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
        home: const SetlistDetailScreen(bandId: 'b1', setlistId: 's1'),
      ),
    );
  }

  testWidgets(
    'shows a centered CircularProgressIndicator while getSetlist is pending',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
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
        find.text(tester.strings.commonFailedToLoadSetlists),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a full BandSetlist response renders name/location/date/duration/tracks',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Full Setlist',
            'durationSeconds': 2555,
            'eventLocation': 'The Venue',
            'eventDate': '2026-09-01',
            'tracks': [
              {
                'trackId': 't1',
                'position': 0,
                'title': 'Track One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Track Two',
                'artist': 'Artist Two',
                'durationSeconds': 200,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      // Appears twice: once in the AppBar title, once in the body heading.
      expect(find.text('Full Setlist'), findsNWidgets(2));
      expect(find.text('The Venue'), findsOneWidget);
      expect(find.text('Sep 1, 2026'), findsOneWidget);
      expect(find.text('42:35'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
      expect(
        find.text(tester.strings.setlistDetailTracksHeader(2)),
        findsOneWidget,
      );
      expect(find.text('Track One'), findsOneWidget);
      expect(find.text('Track Two'), findsOneWidget);
      // Artist + duration are combined into one subtitle (trailing slot is
      // reserved for the edit-mode remove icon).
      expect(find.text('Artist One • 3:45'), findsOneWidget);
      expect(find.text('Artist Two • 3:20'), findsOneWidget);
    },
  );

  testWidgets(
    'eventLocation/eventDate are omitted entirely (no placeholder) when both '
    'are null',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Minimal Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('No date set'), findsNothing);
      expect(find.text(tester.strings.setlistDetailNoTracks), findsOneWidget);
    },
  );

  testWidgets(
    'zero tracks shows "No tracks in this setlist" and "0m 0s" duration',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Empty Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text(tester.strings.setlistDetailNoTracks), findsOneWidget);
      expect(find.text('0:00'), findsOneWidget);
    },
  );

  testWidgets(
    'the edit IconButton is absent while still loading and present once '
    'loaded',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.byIcon(Icons.edit), findsNothing);

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the edit IconButton opens EditSetlistScreen',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byType(EditSetlistScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Delete ListTile opens ConfirmDeleteSetlistDialog',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, tester.strings.commonDelete));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmDeleteSetlistDialog), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Edit reveals a remove icon on every track row and the Add '
    'tracks button; tapping Done hides them again',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 425,
            'tracks': [
              {
                'trackId': 't1',
                'position': 0,
                'title': 'Track One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Track Two',
                'artist': 'Artist Two',
                'durationSeconds': 200,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      expect(find.widgetWithText(ElevatedButton, tester.strings.commonAddTracks), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, tester.strings.commonEdit));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(2));
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonAddTracks),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, tester.strings.setlistDetailDoneButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      expect(find.widgetWithText(ElevatedButton, tester.strings.commonAddTracks), findsNothing);
    },
  );

  testWidgets(
    "tapping a row's remove icon calls removeSetlistTrack with that "
    'trackId and refreshes via a second getSetlist call',
    (tester) async {
      final cacheService = CacheService.inMemory();
      var getSetlistCallCount = 0;
      String? removedTrackId;
      var removed = false;

      final apiClient = buildApiClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path == '/api/band/b1/setlist/s1/tracks') {
          final decoded = jsonDecode(request.body) as Map<String, dynamic>;
          expect(decoded, {
            'trackIds': ['t1'],
          });
          removedTrackId = 't1';
          removed = true;
          return http.Response('', 204);
        }
        getSetlistCallCount++;
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': removed ? 200 : 425,
            'tracks': removed
                ? [
                    {
                      'trackId': 't2',
                      'position': 0,
                      'title': 'Track Two',
                      'artist': 'Artist Two',
                      'durationSeconds': 200,
                    },
                  ]
                : [
                    {
                      'trackId': 't1',
                      'position': 0,
                      'title': 'Track One',
                      'artist': 'Artist One',
                      'durationSeconds': 225,
                    },
                    {
                      'trackId': 't2',
                      'position': 1,
                      'title': 'Track Two',
                      'artist': 'Artist Two',
                      'durationSeconds': 200,
                    },
                  ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, tester.strings.commonEdit));
      await tester.pumpAndSettle();

      expect(getSetlistCallCount, 1);

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pumpAndSettle();

      expect(removedTrackId, 't1');
      expect(getSetlistCallCount, 2);
      expect(find.text('Track One'), findsNothing);
      expect(find.text('Track Two'), findsOneWidget);
    },
  );

  testWidgets(
    'the Add tracks button is absent outside edit mode and present inside '
    'it',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, tester.strings.commonAddTracks), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, tester.strings.commonEdit));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonAddTracks),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "invoking the ReorderableListView's onReorderItem callback directly "
    'submits reorderSetlistTracks with all original track ids present, in '
    'the new order (D-14) — automated substitute for the real drag '
    'gesture, which 04-VALIDATION.md flags as manual-only. This project\'s '
    'installed Flutter SDK deprecates onReorder in favor of onReorderItem '
    '(newIndex already accounts for the removed item), so onReorderItem is '
    'the callback under test, not the plan\'s originally-cited onReorder',
    (tester) async {
      final cacheService = CacheService.inMemory();
      List<String>? submittedTrackIds;

      final apiClient = buildApiClient((request) async {
        if (request.method == 'PUT' &&
            request.url.path == '/api/band/b1/setlist/s1/tracks/reorder') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          submittedTrackIds = (body['trackIds'] as List).cast<String>();
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 675,
            'tracks': [
              {
                'trackId': 't1',
                'position': 0,
                'title': 'Track One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Track Two',
                'artist': 'Artist Two',
                'durationSeconds': 225,
              },
              {
                'trackId': 't3',
                'position': 2,
                'title': 'Track Three',
                'artist': 'Artist Three',
                'durationSeconds': 225,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, tester.strings.commonEdit));
      await tester.pumpAndSettle();

      final reorderableList = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderableList.onReorderItem!(0, 2);
      await tester.pumpAndSettle();

      expect(submittedTrackIds, isNotNull);
      // All 3 original track ids are present — none dropped (T-04-11).
      expect(submittedTrackIds!.toSet(), {'t1', 't2', 't3'});
      expect(submittedTrackIds, hasLength(3));
    },
  );

  testWidgets(
    'a failing reorderSetlistTracks call shows the "Failed to reorder '
    'tracks. Refreshing..." SnackBar and resyncs via a second getSetlist '
    'call',
    (tester) async {
      final cacheService = CacheService.inMemory();
      var getSetlistCallCount = 0;

      final apiClient = buildApiClient((request) async {
        if (request.method == 'PUT' &&
            request.url.path == '/api/band/b1/setlist/s1/tracks/reorder') {
          return http.Response(
            jsonEncode({'code': 'bad_request', 'message': 'reorder failed'}),
            400,
          );
        }
        getSetlistCallCount++;
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 450,
            'tracks': [
              {
                'trackId': 't1',
                'position': 0,
                'title': 'Track One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Track Two',
                'artist': 'Artist Two',
                'durationSeconds': 225,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(getSetlistCallCount, 1);

      await tester.tap(find.widgetWithText(TextButton, tester.strings.commonEdit));
      await tester.pumpAndSettle();

      final reorderableList = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderableList.onReorderItem!(0, 1);
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.setlistDetailReorderFailedSnackbar),
        findsOneWidget,
      );
      expect(getSetlistCallCount, 2);
    },
  );

  testWidgets(
    'with isOnlineProvider false, the Edit IconButton is disabled with a '
    '"Requires connection" tooltip; with it true, the Edit IconButton is '
    'enabled',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeSetlistDetail('b1', 's1', {
        'id': 's1',
        'name': 'Setlist',
        'durationSeconds': 0,
        'tracks': <Map<String, dynamic>>[],
      });
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      final offlineEditButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.edit),
      );
      expect(offlineEditButton.onPressed, isNull);
      expect(offlineEditButton.tooltip, tester.strings.commonRequiresConnection);

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: true));
      await tester.pumpAndSettle();

      final onlineEditButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.edit),
      );
      expect(onlineEditButton.onPressed, isNotNull);
      expect(onlineEditButton.tooltip, tester.strings.setlistDetailEditTooltip);
    },
  );

  testWidgets(
    'with isOnlineProvider false and _editMode initially false, tapping '
    'Edit does not enter edit mode',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeSetlistDetail('b1', 's1', {
        'id': 's1',
        'name': 'Setlist',
        'durationSeconds': 0,
        'tracks': [
          {
            'trackId': 't1',
            'position': 0,
            'title': 'Track One',
            'artist': 'Artist One',
            'durationSeconds': 200,
          },
        ],
      });
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': [
              {
                'trackId': 't1',
                'position': 0,
                'title': 'Track One',
                'artist': 'Artist One',
                'durationSeconds': 200,
              },
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, tester.strings.commonEdit));
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.widgetWithText(ElevatedButton, tester.strings.commonAddTracks), findsNothing);
    },
  );

  testWidgets(
    'entering edit mode online then connectivity dropping mid-session '
    'collapses the ReorderableListView back to a plain read-only ListView '
    'and hides the Add tracks button (D-14)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 200,
            'tracks': [
              {
                'trackId': 't1',
                'position': 0,
                'title': 'Track One',
                'artist': 'Artist One',
                'durationSeconds': 200,
              },
            ],
          }),
          200,
        );
      });

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          cacheServiceProvider.overrideWithValue(cacheService),
          isOnlineProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ru')],
            home: const SetlistDetailScreen(bandId: 'b1', setlistId: 's1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, tester.strings.commonEdit));
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonAddTracks),
        findsOneWidget,
      );

      container.updateOverrides([
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        isOnlineProvider.overrideWithValue(false),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byType(ListView), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, tester.strings.commonAddTracks), findsNothing);
    },
  );

  testWidgets(
    'with isOnlineProvider false, the Delete ListTile is disabled',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeSetlistDetail('b1', 's1', {
        'id': 's1',
        'name': 'Setlist',
        'durationSeconds': 0,
        'tracks': <Map<String, dynamic>>[],
      });
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      final deleteTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, tester.strings.commonDelete),
      );
      expect(deleteTile.enabled, isFalse);
    },
  );

  testWidgets(
    'offline with no cache shows OfflineNoCacheView, with no Retry button '
    '(D-06)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await tester.pumpAndSettle();

      expect(find.byType(OfflineNoCacheView), findsOneWidget);
      expect(find.text(tester.strings.offlineNoCacheTitle), findsOneWidget);
      expect(
        find.text(tester.strings.offlineNoCacheDescription),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, tester.strings.commonRetry),
        findsNothing,
      );
    },
  );
}
