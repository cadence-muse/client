import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/tracks/edit_track_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const currentTrack = {
    'id': 't1',
    'title': 'Old Title',
    'artist': 'Old Artist',
    'durationSeconds': 200,
    'tempo': 120,
    'key': 'C',
    'notes': 'Old notes',
  };

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
    Map<String, dynamic>? trackOverride,
  }) {
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
                    builder: (_) => EditTrackScreen(
                      bandId: 'b1',
                      trackId: 't1',
                      currentTrack: trackOverride ?? currentTrack,
                    ),
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

  Future<void> openEditTrackScreen(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts pre-populated with currentTrack\'s values', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openEditTrackScreen(tester);

    final fields = find
        .byType(TextFormField)
        .evaluate()
        .map((e) => (e.widget as TextFormField).controller!.text)
        .toList();
    expect(fields, ['Old Title', 'Old Artist', '200', '120', 'Old notes']);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets(
    'CR-01: a track whose key is not in musicalKeys builds without '
    'throwing and leaves the key dropdown unselected',
    (tester) async {
      final trackWithUnknownKey = {
        ...currentTrack,
        'key': 'F#m(maj7)',
      };
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(
        wrap(apiClient, trackOverride: trackWithUnknownKey),
      );
      await openEditTrackScreen(tester);

      expect(tester.takeException(), isNull);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, isNull);
    },
  );

  testWidgets('Save button is disabled while submitting', (tester) async {
    final apiClient = buildApiClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openEditTrackScreen(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'submitting a changed title calls updateBandTrack with the exact '
    'request body and pops back',
    (tester) async {
      String? requestPath;
      String? requestMethod;
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        requestPath = request.url.path;
        requestMethod = request.method;
        requestBody = request.body;
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditTrackScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'New Title');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(requestMethod, 'PUT');
      expect(requestPath, '/api/band/b1/track/t1');
      expect(
        requestBody,
        jsonEncode({
          'title': 'New Title',
          'artist': 'Old Artist',
          'durationSeconds': 200,
          'tempo': 120,
          'key': 'C',
          'notes': 'Old notes',
        }),
      );
      expect(find.byType(EditTrackScreen), findsNothing);
    },
  );

  testWidgets(
    'empty title and artist are rejected without an API call',
    (tester) async {
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditTrackScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      expect(callCount, 0);
      expect(find.text('Enter a track title'), findsOneWidget);
      expect(find.text('Enter an artist name'), findsOneWidget);
    },
  );

  testWidgets(
    'an updateBandTrack() failure renders an inline error and re-enables '
    'the Save button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Title is required'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditTrackScreen(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a non-ApiException failure (e.g. offline) shows the generic fallback '
    'message and re-enables the Save button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        throw const SocketException('Network is unreachable');
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditTrackScreen(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
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
