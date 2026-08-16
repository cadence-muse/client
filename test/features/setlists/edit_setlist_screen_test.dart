import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/edit_setlist_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const currentSetlist = {
    'id': 's1',
    'name': 'Old Name',
    'eventLocation': 'Old Venue',
    'eventDate': '2026-09-01',
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
    Map<String, dynamic>? setlistOverride,
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
                    builder: (_) => EditSetlistScreen(
                      bandId: 'b1',
                      setlistId: 's1',
                      currentSetlist: setlistOverride ?? currentSetlist,
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

  Future<void> openEditSetlistScreen(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts pre-populated with currentSetlist\'s values', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openEditSetlistScreen(tester);

    final fields = find
        .byType(TextFormField)
        .evaluate()
        .map((e) => (e.widget as TextFormField).controller!.text)
        .toList();
    expect(fields, ['Old Name', 'Old Venue', '2026-09-01']);
  });

  testWidgets(
    'empty name is rejected without an API call',
    (tester) async {
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      expect(callCount, 0);
      expect(find.text('Name is required'), findsOneWidget);
    },
  );

  testWidgets(
    'submitting a changed name calls updateSetlist with the exact request '
    'body and pops back',
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
      await openEditSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'New Name');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(requestMethod, 'PUT');
      expect(requestPath, '/api/band/b1/setlist/s1');
      expect(
        requestBody,
        jsonEncode({
          'name': 'New Name',
          'eventLocation': 'Old Venue',
          'eventDate': '2026-09-01',
        }),
      );
      expect(find.byType(EditSetlistScreen), findsNothing);
    },
  );

  testWidgets(
    'D-17: clearing the location field sends an explicit null instead of '
    'omitting the key',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        requestBody = request.body;
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);
      // TextFormFields in order: Name(0), Location(1), Date(2).
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
      expect(decoded.containsKey('eventLocation'), isTrue);
      expect(decoded['eventLocation'], isNull);
      expect(decoded['eventDate'], '2026-09-01');
    },
  );

  testWidgets(
    'clearing the date field also sends an explicit null instead of '
    'omitting the key',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        requestBody = request.body;
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
      expect(decoded.containsKey('eventDate'), isTrue);
      expect(decoded['eventDate'], isNull);
    },
  );

  testWidgets('Save button is disabled while submitting', (tester) async {
    final apiClient = buildApiClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openEditSetlistScreen(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'an updateSetlist() failure renders an inline error and re-enables the '
    'Save button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Name is required'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
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
      await openEditSetlistScreen(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to save setlist. Try again.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );
}
