import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_detail_screen.dart';
import 'package:cadence/features/bands/join_band_dialog.dart';
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

  // Defaults isOnlineProvider to true so pre-existing tests (which predate
  // OFFL-03's connectivity gating) keep exercising the "online" path unless a
  // test explicitly overrides it — real-app connectivity_plus resolves
  // AsyncLoading/AsyncError to `false` in this sandboxed test environment
  // with no platform-channel mock, which would otherwise disable the Join
  // button by default.
  Widget wrap(
    ApiClient apiClient,
    CacheService cacheService, {
    bool isOnline = true,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
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
      if (request.method == 'POST' && request.url.path == '/api/band/join') {
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
    await tester.tap(
      find.widgetWithText(FilledButton, tester.strings.joinBandButton),
    );
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
        if (request.method == 'POST' && request.url.path == '/api/band/join') {
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
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.joinBandButton),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BandDetailScreen), findsOneWidget);
      expect(
        find.text(tester.strings.joinBandSuccessSnackbar('New Band')),
        findsOneWidget,
      );
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
        if (request.method == 'POST' && request.url.path == '/api/band/join') {
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
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.joinBandButton),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BandDetailScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(tester.strings.joinBandAmbiguousSnackbar),
        findsOneWidget,
      );
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
        if (request.method == 'POST' && request.url.path == '/api/band/join') {
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
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.joinBandButton),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BandDetailScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text(tester.strings.joinBandAmbiguousSnackbar),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a joinBand() failure with a known error code shows the localized '
    'generic message, not raw server text',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/band/join') {
          return http.Response(
            jsonEncode({'code': 'not_found', 'message': 'Invalid invite code'}),
            400,
          );
        }
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'BADCODE');
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.joinBandButton),
      );
      await tester.pumpAndSettle();

      expect(find.text(tester.strings.commonErrorNotFound), findsOneWidget);
      expect(find.text('Invalid invite code'), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a non-ApiException failure (e.g. offline) shows the generic fallback '
    'message and re-enables the Join button',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/band/join') {
          throw const SocketException('Network is unreachable');
        }
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.joinBandButton),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.commonSomethingWentWrong),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Join button is disabled and reads "Requires connection" while offline',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.pump();

      final offlineButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(offlineButton.onPressed, isNull);
      expect(
        find.text(tester.strings.commonRequiresConnection),
        findsOneWidget,
      );
    },
  );

  testWidgets('Join button is enabled while online', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await openDialog(tester);
    await tester.enterText(find.byType(TextFormField), 'ABC123');
    await tester.pump();

    final onlineButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(onlineButton.onPressed, isNotNull);
    expect(find.text(tester.strings.joinBandButton), findsOneWidget);
  });

  testWidgets(
    'a long/pasted invite code does not break the TextField\'s layout',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });
      const longCode = 'AAAAAAAAAA-BBBBBBBBBB-CCCCCCCCCC-DDDDDDDDDD-EEEEEEEEEE';

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField), longCode);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(longCode), findsOneWidget);
    },
  );
}
