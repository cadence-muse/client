import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_detail_screen.dart';
import 'package:cadence/features/bands/join_band_dialog.dart';
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
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Builder(
              builder: (innerContext) => ElevatedButton(
                onPressed: () => showJoinBandDialog(innerContext, ref),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('invite-code field is empty and autofocused on open', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await openDialog(tester);

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, isEmpty);

    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.focusNode.hasFocus, isTrue);
  });

  testWidgets('submitting a code calls joinBand with the code trimmed', (
    tester,
  ) async {
    String? joinRequestBody;
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([
      {'id': 'a', 'name': 'Existing Band'},
    ]);

    final apiClient = buildApiClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/band/join') {
        joinRequestBody = request.body;
        return http.Response('', 200);
      }
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'a', 'name': 'Existing Band'},
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await openDialog(tester);
    await tester.enterText(find.byType(TextFormField), '  ABC123  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();

    expect(joinRequestBody, jsonEncode({'inviteCode': 'ABC123'}));
  });

  testWidgets(
    'exactly one new band id navigates to that band\'s detail screen',
    (tester) async {
      final cacheService = CacheService.inMemory();
      // Keyed on whether the join POST has fired yet (not call count) so
      // any concurrent/background GET /api/band/list calls — e.g. the
      // provider's own cache-miss fetch or silent refresh — stay consistent
      // with real join state instead of racing on ordering.
      var joined = false;

      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/band/join') {
          joined = true;
          return http.Response('', 200);
        }
        if (request.method == 'GET' && request.url.path == '/api/band/list') {
          final items = joined
              ? [
                  {'id': 'a', 'name': 'Existing Band'},
                  {'id': 'b', 'name': 'New Band'},
                ]
              : [
                  {'id': 'a', 'name': 'Existing Band'},
                ];
          return http.Response(jsonEncode({'items': items}), 200);
        }
        return http.Response(
          jsonEncode({
            'id': 'b',
            'name': 'New Band',
            'members': <Map<String, dynamic>>[],
            'inviteCode': 'xyz789',
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(find.byType(BandDetailScreen), findsOneWidget);
      expect(find.text("You've joined New Band!"), findsOneWidget);
    },
  );

  testWidgets(
    'an ambiguous diff (0 new ids) falls back to the refreshed Bands list',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Existing Band'},
      ]);

      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/band/join') {
          return http.Response('', 200);
        }
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Existing Band'},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(find.byType(BandDetailScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Joined band!'), findsOneWidget);
    },
  );

  testWidgets(
    'an ambiguous diff (2+ new ids) falls back to the refreshed Bands list',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Existing Band'},
      ]);

      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/band/join') {
          return http.Response('', 200);
        }
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Existing Band'},
              {'id': 'b', 'name': 'New Band 1'},
              {'id': 'c', 'name': 'New Band 2'},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(find.byType(BandDetailScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Joined band!'), findsOneWidget);
    },
  );
}
