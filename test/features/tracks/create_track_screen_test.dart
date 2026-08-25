import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/tracks/create_track_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/tracks_provider.dart';
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
    ApiClient apiClient, {
    CacheService? cacheService,
    bool isOnline = true,
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateTrackScreen(bandId: 'b1'),
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

  Future<void> openCreateTrackScreen(WidgetTester tester) async {
    // The Duration field's helperText (added for DUR-04) grows the form's
    // total height past the default 800x600 test viewport, pushing the
    // Save button below the visible area and causing tap() to miss it.
    // Widen the viewport so the whole form is on-screen without scrolling.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.pumpAndSettle();
  }

  Future<void> enterTitleAndArtist(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'My Song');
    await tester.enterText(fields.at(1), 'My Artist');
  }

  testWidgets(
    'submitting title+artist sends the exact JSON request body and pops back to the list',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/track') {
          requestBody = request.body;
          return http.Response(jsonEncode({'id': 't1'}), 201);
        }
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateTrackScreen(tester);
      await enterTitleAndArtist(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
      await tester.pumpAndSettle();

      expect(
        requestBody,
        jsonEncode({'title': 'My Song', 'artist': 'My Artist'}),
      );
      expect(find.text('My Song added!'), findsOneWidget);
      expect(find.byType(CreateTrackScreen), findsNothing);
    },
  );

  testWidgets(
    'CR-03: creating a track invalidates the global Tracks tab so it '
    'refetches',
    (tester) async {
      var trackListCallCount = 0;
      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/track') {
          return http.Response(jsonEncode({'id': 't1'}), 201);
        }
        if (request.url.path == '/api/track/list') {
          trackListCallCount++;
        }
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });
      final cacheService = CacheService.inMemory();
      await cacheService.writeUserTracks(null, []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            cacheServiceProvider.overrideWithValue(cacheService),
            isOnlineProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                // Watching userTracksListDataProvider here (as the real
                // global Tracks tab would) is what makes
                // ref.exists(userTracksListDataProvider) true inside the
                // mutation flow below.
                ref.watch(userTracksListDataProvider);
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateTrackScreen(bandId: 'b1'),
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final callCountBeforeMutation = trackListCallCount;

      await openCreateTrackScreen(tester);
      await enterTitleAndArtist(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
      await tester.pumpAndSettle();

      expect(trackListCallCount, greaterThan(callCountBeforeMutation));
    },
  );

  testWidgets(
    'empty title and artist are rejected without an API call',
    (tester) async {
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(jsonEncode({'id': 't1'}), 201);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateTrackScreen(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
      await tester.pump();

      expect(callCount, 0);
      expect(find.text('Enter a track title'), findsOneWidget);
      expect(find.text('Enter an artist name'), findsOneWidget);
    },
  );

  testWidgets(
    'DUR-04: typing "230" into Duration auto-formats to "2:30" and submits '
    'durationSeconds 150',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/track') {
          requestBody = request.body;
          return http.Response(jsonEncode({'id': 't1'}), 201);
        }
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateTrackScreen(tester);
      await enterTitleAndArtist(tester);
      await tester.enterText(find.byType(TextFormField).at(2), '230');
      await tester.pump();

      expect(find.text('2:30'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
      await tester.pumpAndSettle();

      expect(
        requestBody,
        jsonEncode({
          'title': 'My Song',
          'artist': 'My Artist',
          'durationSeconds': 150,
        }),
      );
    },
  );

  testWidgets(
    'DUR-02: Duration formatted to "5:60" is rejected on submit with the '
    'seconds-range error, no API call',
    (tester) async {
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(jsonEncode({'id': 't1'}), 201);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateTrackScreen(tester);
      await enterTitleAndArtist(tester);
      await tester.enterText(find.byType(TextFormField).at(2), '560');
      await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
      await tester.pump();

      expect(callCount, 0);
      expect(
        find.text('Seconds must be 0–59 (e.g. 2:30, not 2:75)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a createBandTrack() failure renders an inline error and re-enables the '
    'Save track button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Title is required'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateTrackScreen(tester);
      await enterTitleAndArtist(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a non-ApiException failure (e.g. offline) shows the generic fallback '
    'message and re-enables the Save track button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        throw const SocketException('Network is unreachable');
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateTrackScreen(tester);
      await enterTitleAndArtist(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'the Save track button is disabled while offline, even with a valid '
    'filled form',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'id': 't1'}), 201);
      });

      await tester.pumpWidget(wrap(apiClient, isOnline: false));
      await openCreateTrackScreen(tester);
      await enterTitleAndArtist(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'the Save track button is enabled while online with a valid filled '
    'form',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'id': 't1'}), 201);
      });

      await tester.pumpWidget(wrap(apiClient, isOnline: true));
      await openCreateTrackScreen(tester);
      await enterTitleAndArtist(tester);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );
}
