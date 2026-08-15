import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/edit_band_screen.dart';
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

  Widget wrap(
    ApiClient apiClient, {
    CacheService? cacheService,
    String bandId = 'b1',
    String currentName = 'The Testers',
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(
          cacheService ?? CacheService.inMemory(),
        ),
      ],
      child: MaterialApp(
        home: EditBandScreen(bandId: bandId, currentName: currentName),
      ),
    );
  }

  /// Wraps [EditBandScreen] behind a "Home" route so a successful
  /// `Navigator.pop()` back to the caller can actually be observed.
  Widget wrapWithHomeRoute(
    ApiClient apiClient, {
    CacheService? cacheService,
    String bandId = 'b1',
    String currentName = 'The Testers',
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
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditBandScreen(
                      bandId: bandId,
                      currentName: currentName,
                    ),
                  ),
                ),
                child: const Text('Open Edit'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens with the name field pre-filled with currentName', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, currentName: 'The Testers'));

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, 'The Testers');
  });

  testWidgets('empty/whitespace-only name is rejected without an API call', (
    tester,
  ) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(callCount, 0);
    expect(find.text('Enter a band name'), findsOneWidget);
  });

  testWidgets('submitting a valid new name calls updateBand and pops back', (
    tester,
  ) async {
    String? requestMethod;
    String? requestPath;
    String? requestBody;
    final apiClient = buildApiClient((request) async {
      requestMethod = request.method;
      requestPath = request.url.path;
      requestBody = request.body;
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrapWithHomeRoute(apiClient));
    await tester.tap(find.widgetWithText(FilledButton, 'Open Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(EditBandScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'New Name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(requestMethod, 'PUT');
    expect(requestPath, '/api/band/b1');
    expect(requestBody, jsonEncode({'name': 'New Name'}));
    expect(find.byType(EditBandScreen), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Open Edit'), findsOneWidget);
  });

  testWidgets(
    'an updateBand() failure renders an inline error and re-enables the '
    'Save button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Name is taken'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is taken'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a long/multi-byte-script band name is accepted by the field without a '
    'layout exception',
    (tester) async {
      const longName = 'Группа Very Long Название 乐队名称超过三十个字符长度测试';
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), longName);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsOneWidget);
    },
  );

  testWidgets(
    'submitting the same unchanged name still calls updateBand() exactly '
    'once per tap and pops successfully',
    (tester) async {
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response('', 200);
      });

      await tester.pumpWidget(
        wrapWithHomeRoute(apiClient, currentName: 'The Testers'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Open Edit'));
      await tester.pumpAndSettle();

      // No change to the pre-filled text — submit as-is.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(find.byType(EditBandScreen), findsNothing);
    },
  );
}
