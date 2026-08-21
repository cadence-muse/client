import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/confirm_transfer_ownership_dialog.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
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
                    builder: (detailContext) => Scaffold(
                      appBar: AppBar(title: const Text('Detail')),
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => showDialog<void>(
                            context: detailContext,
                            builder: (_) => const ConfirmTransferOwnershipDialog(
                              bandId: 'b1',
                              memberUserId: 'u2',
                              memberUsername: 'bob',
                              bandName: 'The Testers',
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

  testWidgets('Cancel pops without calling transferOwnership', (
    tester,
  ) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(find.byType(ConfirmTransferOwnershipDialog), findsNothing);
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets(
    'the dialog body states the self-effect: "You will no longer be the '
    'owner of The Testers." (D-04)',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);

      expect(
        find.textContaining(
          'You will no longer be the owner of The Testers.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'confirming Transfer sends POST /api/band/b1/transfer-ownership with '
    'body {userId: u2} and pops the dialog on a 200 no-body success '
    'response',
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
      await openDialog(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
      await tester.pumpAndSettle();

      expect(requestMethod, 'POST');
      expect(requestPath, '/api/band/b1/transfer-ownership');
      expect(requestBody, '{"userId":"u2"}');
      expect(find.byType(ConfirmTransferOwnershipDialog), findsNothing);
      expect(find.text('Detail'), findsOneWidget);
    },
  );
}
