import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/confirm_delete_setlist_dialog.dart';
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
                    builder: (detailContext) => Scaffold(
                      appBar: AppBar(title: const Text('Detail')),
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => showDialog<void>(
                            context: detailContext,
                            builder: (_) => const ConfirmDeleteSetlistDialog(
                              bandId: 'b1',
                              setlistId: 's1',
                              setlistName: 'My Setlist',
                            ),
                          ),
                          child: const Text('Open dialog'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open detail'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open dialog'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancel pops without calling deleteSetlist', (tester) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      return http.Response('', 204);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(find.byType(ConfirmDeleteSetlistDialog), findsNothing);
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets(
    'Delete calls deleteSetlist(bandId, setlistId) and double-pops back to '
    'the list',
    (tester) async {
      String? requestPath;
      String? requestMethod;
      final apiClient = buildApiClient((request) async {
        requestPath = request.url.path;
        requestMethod = request.method;
        return http.Response('', 204);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(requestMethod, 'DELETE');
      expect(requestPath, '/api/band/b1/setlist/s1');
      expect(find.text('Detail'), findsNothing);
      expect(
        find.widgetWithText(ElevatedButton, 'Open detail'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the Delete button is disabled while submitting', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('', 204);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'an ApiException on delete shows an inline error inside the dialog and '
    'keeps it open',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'bad_request',
            'message': 'Cannot delete setlist',
          }),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot delete setlist'), findsOneWidget);
      expect(find.byType(ConfirmDeleteSetlistDialog), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a non-ApiException failure (e.g. offline) shows the generic fallback '
    'message and re-enables the Delete button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        throw Exception('boom');
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete failed. Try again.'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );
}
