import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/tracks/create_track_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
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

  Widget wrap(ApiClient apiClient, {CacheService? cacheService}) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(
          cacheService ?? CacheService.inMemory(),
        ),
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
}
