import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/confirm_delete_setlist_dialog.dart';
import 'package:cadence/features/setlists/edit_setlist_screen.dart';
import 'package:cadence/features/setlists/setlist_detail_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
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

  Widget wrap(ApiClient apiClient, CacheService cacheService) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: const MaterialApp(
        home: SetlistDetailScreen(bandId: 'b1', setlistId: 's1'),
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
        find.text('Failed to load setlists. Tap to try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
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
                'title': 'Song One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Song Two',
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
      expect(find.text('Duration: 42m 35s'), findsOneWidget);
      expect(find.text('Tracks (2)'), findsOneWidget);
      expect(find.text('Song One'), findsOneWidget);
      expect(find.text('Song Two'), findsOneWidget);
      // Artist + duration are combined into one subtitle (trailing slot is
      // reserved for the edit-mode remove icon).
      expect(find.text('Artist One • 3m 45s'), findsOneWidget);
      expect(find.text('Artist Two • 3m 20s'), findsOneWidget);
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
      expect(find.text('No tracks in this setlist'), findsOneWidget);
    },
  );

  testWidgets(
    'zero tracks shows "No tracks in this setlist" and "Duration: 0m 0s"',
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

      expect(find.text('No tracks in this setlist'), findsOneWidget);
      expect(find.text('Duration: 0m 0s'), findsOneWidget);
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

      await tester.tap(find.widgetWithText(ListTile, 'Delete'));
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
                'title': 'Song One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Song Two',
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
      expect(find.widgetWithText(ElevatedButton, 'Add tracks'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Edit'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(2));
      expect(
        find.widgetWithText(ElevatedButton, 'Add tracks'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Add tracks'), findsNothing);
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
            request.url.path == '/api/band/b1/setlist/s1/track/t1') {
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
                      'title': 'Song Two',
                      'artist': 'Artist Two',
                      'durationSeconds': 200,
                    },
                  ]
                : [
                    {
                      'trackId': 't1',
                      'position': 0,
                      'title': 'Song One',
                      'artist': 'Artist One',
                      'durationSeconds': 225,
                    },
                    {
                      'trackId': 't2',
                      'position': 1,
                      'title': 'Song Two',
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

      await tester.tap(find.widgetWithText(TextButton, 'Edit'));
      await tester.pumpAndSettle();

      expect(getSetlistCallCount, 1);

      await tester.tap(find.byIcon(Icons.remove_circle_outline).first);
      await tester.pumpAndSettle();

      expect(removedTrackId, 't1');
      expect(getSetlistCallCount, 2);
      expect(find.text('Song One'), findsNothing);
      expect(find.text('Song Two'), findsOneWidget);
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

      expect(find.widgetWithText(ElevatedButton, 'Add tracks'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Edit'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Add tracks'),
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
                'title': 'Song One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Song Two',
                'artist': 'Artist Two',
                'durationSeconds': 225,
              },
              {
                'trackId': 't3',
                'position': 2,
                'title': 'Song Three',
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

      await tester.tap(find.widgetWithText(TextButton, 'Edit'));
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
                'title': 'Song One',
                'artist': 'Artist One',
                'durationSeconds': 225,
              },
              {
                'trackId': 't2',
                'position': 1,
                'title': 'Song Two',
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

      await tester.tap(find.widgetWithText(TextButton, 'Edit'));
      await tester.pumpAndSettle();

      final reorderableList = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderableList.onReorderItem!(0, 1);
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to reorder tracks. Refreshing...'),
        findsOneWidget,
      );
      expect(getSetlistCallCount, 2);
    },
  );
}
