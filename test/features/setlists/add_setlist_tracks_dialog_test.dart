import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/add_setlist_tracks_dialog.dart';
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

  // Defaults isOnlineProvider to true — without an override, connectivity_plus
  // has no platform-channel mock in the test environment and resolves to the
  // fail-safe-offline default, which would break every pre-existing test
  // written before this plan's connectivity gating.
  Widget wrap(
    ApiClient apiClient, {
    required Set<String> currentTrackIds,
    bool isOnline = true,
    CacheService? cacheService,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(
          cacheService ?? CacheService.inMemory(),
        ),
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AddSetlistTracksDialog(
                    bandId: 'b1',
                    setlistId: 's1',
                    currentTrackIds: currentTrackIds,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('excludes already-in-setlist tracks from the checklist', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      if (request.url.path == '/api/band/b1/track/list') {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
              {'id': 't2', 'title': 'Track Two', 'artist': 'Artist Two'},
              {'id': 't3', 'title': 'Track Three', 'artist': 'Artist Three'},
            ],
          }),
          200,
        );
      }
      return http.Response('', 204);
    });

    await tester.pumpWidget(wrap(apiClient, currentTrackIds: {'t1'}));
    await openDialog(tester);

    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text('Track One'), findsNothing);
    expect(find.text('Track Two'), findsOneWidget);
    expect(find.text('Track Three'), findsOneWidget);
  });

  testWidgets(
    'shows "No more tracks available" when every band track is already in '
    'the setlist',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
              ],
            }),
            200,
          );
        }
        return http.Response('', 204);
      });

      await tester.pumpWidget(wrap(apiClient, currentTrackIds: {'t1'}));
      await openDialog(tester);

      expect(find.text(tester.strings.addSetlistTracksNoneAvailable), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    },
  );

  testWidgets(
    'submitting with 2 tracks checked calls addSetlistTracks once with '
    'exactly those trackIds',
    (tester) async {
      String? addRequestBody;
      var addCallCount = 0;

      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
                {'id': 't2', 'title': 'Track Two', 'artist': 'Artist Two'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/setlist/s1/tracks') {
          addCallCount++;
          addRequestBody = request.body;
          return http.Response('', 204);
        }
        // GET /api/band/b1/setlist/s1 — the post-add detail refresh().
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'S',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, currentTrackIds: {}));
      await openDialog(tester);
      await tester.tap(find.text('Track One'));
      await tester.tap(find.text('Track Two'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.addSetlistTracksSubmitButton));
      await tester.pumpAndSettle();

      expect(addCallCount, 1);
      final decoded = jsonDecode(addRequestBody!) as Map<String, dynamic>;
      expect(decoded['trackIds'], ['t1', 't2']);
    },
  );

  testWidgets(
    'an addSetlistTracks() ApiException failure renders an inline error and '
    'keeps the dialog open',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/setlist/s1/tracks') {
          return http.Response(
            jsonEncode({'code': 'bad_request', 'message': 'Too many tracks'}),
            400,
          );
        }
        return http.Response('', 204);
      });

      await tester.pumpWidget(wrap(apiClient, currentTrackIds: {}));
      await openDialog(tester);
      await tester.tap(find.text('Track One'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.addSetlistTracksSubmitButton));
      await tester.pumpAndSettle();

      expect(find.text('Too many tracks'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  testWidgets('a non-ApiException failure shows the generic fallback message', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      if (request.url.path == '/api/band/b1/track/list') {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
            ],
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/band/b1/setlist/s1/tracks') {
        throw const SocketException('Network is unreachable');
      }
      return http.Response('', 204);
    });

    await tester.pumpWidget(wrap(apiClient, currentTrackIds: {}));
    await openDialog(tester);
    await tester.tap(find.text('Track One'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, tester.strings.addSetlistTracksSubmitButton));
    await tester.pumpAndSettle();

    expect(
      find.text(tester.strings.addSetlistTracksFailedError),
      findsOneWidget,
    );
  });

  testWidgets(
    'the Add button disables and shows a spinner while the request is in '
    'flight',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/setlist/s1/tracks') {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'S',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, currentTrackIds: {}));
      await openDialog(tester);
      await tester.tap(find.text('Track One'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.addSetlistTracksSubmitButton));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'with tracks selected and isOnlineProvider false, the Add button is '
    'disabled with a "Requires connection" label',
    (tester) async {
      // TrackListData is online-first (07-03): offline with nothing cached
      // throws OfflineNoCacheException instead of populating the checklist,
      // so this test — which exercises the Add button's connectivity gate,
      // not data availability — seeds the cache the offline branch reads.
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
      ]);
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
              ],
            }),
            200,
          );
        }
        return http.Response('', 204);
      });

      await tester.pumpWidget(
        wrap(
          apiClient,
          currentTrackIds: {},
          isOnline: false,
          cacheService: cacheService,
        ),
      );
      await openDialog(tester);
      await tester.tap(find.text('Track One'));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(
        find.text(tester.strings.commonRequiresConnection),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'with tracks selected and isOnlineProvider true, the Add button is '
    'enabled',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
              ],
            }),
            200,
          );
        }
        return http.Response('', 204);
      });

      await tester.pumpWidget(
        wrap(apiClient, currentTrackIds: {}, isOnline: true),
      );
      await openDialog(tester);
      await tester.tap(find.text('Track One'));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'with zero tracks selected and isOnlineProvider true, the Add button '
    'stays disabled (existing empty-selection guard preserved)',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
              ],
            }),
            200,
          );
        }
        return http.Response('', 204);
      });

      await tester.pumpWidget(
        wrap(apiClient, currentTrackIds: {}, isOnline: true),
      );
      await openDialog(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'renders a search TextField with the title/artist hint above the track '
    'checklist',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
              ],
            }),
            200,
          );
        }
        return http.Response('', 204);
      });

      await tester.pumpWidget(wrap(apiClient, currentTrackIds: {}));
      await openDialog(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text(tester.strings.addSetlistTracksSearchHint),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'while online, typing in the search field sends exactly one debounced '
    'GET request carrying the typed searchQuery after 300ms, and the '
    'checklist still shows every available track unfiltered (D-05)',
    (tester) async {
      final capturedRequests = <http.Request>[];
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          capturedRequests.add(request);
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
                {'id': 't2', 'title': 'Track Two', 'artist': 'Artist Two'},
              ],
            }),
            200,
          );
        }
        return http.Response('', 204);
      });

      await tester.pumpWidget(wrap(apiClient, currentTrackIds: {}));
      await openDialog(tester);

      expect(capturedRequests, hasLength(1));

      await tester.enterText(find.byType(TextField), 'wonder');
      await tester.pump(const Duration(milliseconds: 100));
      expect(capturedRequests, hasLength(1));

      await tester.pump(const Duration(milliseconds: 250));
      expect(capturedRequests, hasLength(2));
      expect(
        capturedRequests.last.url.queryParameters['searchQuery'],
        'wonder',
      );
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
    },
  );

  testWidgets(
    'offline: typing a search query immediately narrows the checklist to '
    'title/artist matches, with no debounce delay',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Wonderwall', 'artist': 'Oasis'},
        {'id': 't2', 'title': 'Yellow', 'artist': 'Coldplay'},
      ]);
      final apiClient = buildApiClient(
        (request) async => http.Response('', 204),
      );

      await tester.pumpWidget(
        wrap(
          apiClient,
          currentTrackIds: {},
          isOnline: false,
          cacheService: cacheService,
        ),
      );
      await openDialog(tester);

      expect(find.byType(CheckboxListTile), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'wonder');
      await tester.pump();

      expect(find.byType(CheckboxListTile), findsNWidgets(1));
      expect(find.text('Wonderwall'), findsOneWidget);
      expect(find.text('Yellow'), findsNothing);
    },
  );

  testWidgets(
    'offlineEmptySearchMessage: offline search with zero matches shows "No '
    'tracks match your search" instead of "No more tracks available"',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Wonderwall', 'artist': 'Oasis'},
      ]);
      final apiClient = buildApiClient(
        (request) async => http.Response('', 204),
      );

      await tester.pumpWidget(
        wrap(
          apiClient,
          currentTrackIds: {},
          isOnline: false,
          cacheService: cacheService,
        ),
      );
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'nothing matches this');
      await tester.pump();

      expect(find.text(tester.strings.addSetlistTracksNoMatch), findsOneWidget);
      expect(find.text(tester.strings.addSetlistTracksNoneAvailable), findsNothing);
    },
  );

  testWidgets(
    'clearSearchFilter: clearing the search field after a filtered search '
    'redisplays the full offline track list',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Wonderwall', 'artist': 'Oasis'},
        {'id': 't2', 'title': 'Yellow', 'artist': 'Coldplay'},
      ]);
      final apiClient = buildApiClient(
        (request) async => http.Response('', 204),
      );

      await tester.pumpWidget(
        wrap(
          apiClient,
          currentTrackIds: {},
          isOnline: false,
          cacheService: cacheService,
        ),
      );
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'wonder');
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsNWidgets(1));

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
    },
  );

  testWidgets(
    'addTracksWithSearchActive: online, typing a non-empty search query '
    'does not prevent selecting and submitting tracks — addSetlistTracks '
    'is still called with exactly the selected trackIds',
    (tester) async {
      String? addRequestBody;
      var addCallCount = 0;

      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
                {'id': 't2', 'title': 'Track Two', 'artist': 'Artist Two'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/setlist/s1/tracks') {
          addCallCount++;
          addRequestBody = request.body;
          return http.Response('', 204);
        }
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'S',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, currentTrackIds: {}));
      await openDialog(tester);

      await tester.enterText(find.byType(TextField), 'search text');
      await tester.pump();

      await tester.tap(find.text('Track One'));
      await tester.tap(find.text('Track Two'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.addSetlistTracksSubmitButton));
      await tester.pumpAndSettle();

      expect(addCallCount, 1);
      final decoded = jsonDecode(addRequestBody!) as Map<String, dynamic>;
      expect(decoded['trackIds'], ['t1', 't2']);
    },
  );
}
