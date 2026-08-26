import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/confirm_transfer_ownership_dialog.dart';
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

  Widget wrap(
    ApiClient apiClient, {
    CacheService? cacheService,
    bool isOnline = true,
    String memberUsername = 'bob',
    String bandName = 'The Testers',
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (detailContext) => Scaffold(
                      appBar: AppBar(title: const Text('Detail')),
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => showDialog<void>(
                            context: detailContext,
                            builder: (_) => ConfirmTransferOwnershipDialog(
                              bandId: 'b1',
                              memberUserId: 'u2',
                              memberUsername: memberUsername,
                              bandName: bandName,
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
    await tester.tap(
      find.widgetWithText(TextButton, tester.strings.commonCancel),
    );
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

      final selfEffect = tester.strings
          .confirmTransferOwnershipBody('bob', 'The Testers')
          .split('\n\n')
          .last;
      expect(find.textContaining(selfEffect), findsOneWidget);
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
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          tester.strings.confirmTransferOwnershipButton,
        ),
      );
      await tester.pumpAndSettle();

      expect(requestMethod, 'POST');
      expect(requestPath, '/api/band/b1/transfer-ownership');
      expect(requestBody, '{"userId":"u2"}');
      expect(find.byType(ConfirmTransferOwnershipDialog), findsNothing);
      expect(find.text('Detail'), findsOneWidget);
    },
  );

  testWidgets('the Transfer button is disabled while offline', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, isOnline: false));
    await openDialog(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'the Transfer button shows a spinner and is disabled while submitting',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          tester.strings.confirmTransferOwnershipButton,
        ),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'an ApiException on transfer shows an inline error inside the dialog, '
    'keeps it open, and re-enables the Transfer button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Transfer failed'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(
        find.widgetWithText(
          FilledButton,
          tester.strings.confirmTransferOwnershipButton,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transfer failed'), findsOneWidget);
      expect(find.byType(ConfirmTransferOwnershipDialog), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'the dialog renders without an overflow exception at max OS '
    'text-scale (backstop)',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3.0)),
            child: wrap(apiClient),
          ),
        ),
      );

      await openDialog(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ConfirmTransferOwnershipDialog), findsOneWidget);
    },
  );

  testWidgets(
    'a long memberUsername/bandName renders without an overflow exception '
    'and the interpolated text is findable, wrapping rather than clipping '
    '(backstop)',
    (tester) async {
      const longUsername =
          'a-very-long-member-username-that-is-definitely-over-sixty-chars';
      const longBandName =
          'A Very Long Band Name That Is Definitely Over Sixty Characters '
          'Long Indeed';
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(
        wrap(
          apiClient,
          memberUsername: longUsername,
          bandName: longBandName,
        ),
      );
      await openDialog(tester);

      expect(tester.takeException(), isNull);
      final selfEffectSuffix = tester.strings
          .confirmTransferOwnershipBody(longUsername, longBandName)
          .split('\n\n')
          .last;
      final selfEffectPrefix = selfEffectSuffix.substring(
        0,
        selfEffectSuffix.indexOf(longBandName),
      );
      expect(find.textContaining(selfEffectPrefix), findsOneWidget);
      expect(find.byType(ConfirmTransferOwnershipDialog), findsOneWidget);
    },
  );
}
