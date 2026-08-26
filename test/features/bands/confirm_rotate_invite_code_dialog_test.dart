import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/confirm_rotate_invite_code_dialog.dart';
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
                            builder: (_) => const ConfirmRotateInviteCodeDialog(
                              bandId: 'b1',
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

  testWidgets('Cancel pops without calling rotateInviteCode', (tester) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      return http.Response(jsonEncode({'newInviteCode': 'zzz-999'}), 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openDialog(tester);
    await tester.tap(find.widgetWithText(TextButton, tester.strings.commonCancel));
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(find.byType(ConfirmRotateInviteCodeDialog), findsNothing);
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets(
    'confirming Rotate sends POST /api/band/b1/rotate-invite-code and pops '
    'the dialog on a 200 success response',
    (tester) async {
      String? requestPath;
      String? requestMethod;
      final apiClient = buildApiClient((request) async {
        requestPath = request.url.path;
        requestMethod = request.method;
        return http.Response(jsonEncode({'newInviteCode': 'zzz-999'}), 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonRotate),
      );
      await tester.pumpAndSettle();

      expect(requestMethod, 'POST');
      expect(requestPath, '/api/band/b1/rotate-invite-code');
      expect(find.byType(ConfirmRotateInviteCodeDialog), findsNothing);
      expect(find.text('Detail'), findsOneWidget);
    },
  );

  testWidgets('the Rotate button is disabled while offline', (tester) async {
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'newInviteCode': 'zzz-999'}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, isOnline: false));
    await openDialog(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'the Rotate button shows a spinner and is disabled while submitting',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode({'newInviteCode': 'zzz-999'}), 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonRotate),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'an ApiException on rotate shows an inline error inside the dialog, '
    'keeps it open, and re-enables the Rotate button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Rotate failed'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonRotate),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rotate failed'), findsOneWidget);
      expect(find.byType(ConfirmRotateInviteCodeDialog), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a known-error-code rotate failure renders the localized message, not '
    'the raw server text',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'operation_rejected',
            'message': 'raw server text',
          }),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonRotate),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.commonErrorOperationRejected),
        findsOneWidget,
      );
      expect(find.text('raw server text'), findsNothing);
    },
  );

  testWidgets(
    'the dialog\'s fixed two-sentence body renders without an overflow '
    'exception at max OS text-scale (backstop)',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'newInviteCode': 'zzz-999'}), 200);
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
      expect(find.byType(ConfirmRotateInviteCodeDialog), findsOneWidget);
    },
  );
}
