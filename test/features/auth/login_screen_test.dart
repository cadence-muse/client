import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/auth/login_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
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

  Widget wrap(ApiClient apiClient) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(CacheService.inMemory()),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ru')],
        home: LoginScreen(),
      ),
    );
  }

  Future<void> fillCredentials(
    WidgetTester tester, {
    String username = 'newuser',
    String password = 'password123',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, tester.strings.loginUsernameLabel),
      username,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tester.strings.loginPasswordLabel),
      password,
    );
  }

  testWidgets(
    'registering with an already-taken username still shows the '
    'loginUsernameTakenError override, not the generic already_exists '
    'message',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/register') {
          return http.Response(
            jsonEncode({'code': 'already_exists', 'message': 'raw'}),
            400,
          );
        }
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.tap(
        find.widgetWithText(TextButton, tester.strings.loginToggleToSignUp),
      );
      await tester.pump();
      await fillCredentials(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.loginSignUpButton),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.loginUsernameTakenError),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'registering and hitting a different known code (not_found) now shows '
    'the shared generic localized message -- new behavior this phase adds',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/register') {
          return http.Response(
            jsonEncode({'code': 'not_found', 'message': 'raw'}),
            400,
          );
        }
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.tap(
        find.widgetWithText(TextButton, tester.strings.loginToggleToSignUp),
      );
      await tester.pump();
      await fillCredentials(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.loginSignUpButton),
      );
      await tester.pumpAndSettle();

      expect(find.text(tester.strings.commonErrorNotFound), findsOneWidget);
    },
  );

  testWidgets(
    'logging in with wrong credentials (400 invalid_input, per '
    'publicapi.yml -- /api/login never returns 401) shows '
    'loginInvalidCredentialsError',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/login') {
          return http.Response(
            jsonEncode({'code': 'invalid_input', 'message': 'bad login'}),
            400,
          );
        }
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await fillCredentials(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.loginLogInButton),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.loginInvalidCredentialsError),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'logging in with a short (7-char) but non-empty password reaches the '
    'server -- proven by a mocked 400 invalid_input surfacing '
    'loginInvalidCredentialsError, not a client-side commonAtLeast8Chars '
    'validator error (D-04)',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/login') {
          return http.Response(
            jsonEncode({'code': 'invalid_input', 'message': 'bad login'}),
            400,
          );
        }
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await fillCredentials(tester, password: 'short12');
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.loginLogInButton),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.loginInvalidCredentialsError),
        findsOneWidget,
      );
      expect(find.text(tester.strings.commonAtLeast8Chars), findsNothing);
    },
  );

  testWidgets(
    'logging in with an empty password shows commonFieldRequired and does '
    'not reach the server (login-mode length check is skipped entirely)',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await fillCredentials(tester, password: '');
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.loginLogInButton),
      );
      await tester.pump();

      expect(find.text(tester.strings.commonFieldRequired), findsOneWidget);
      expect(find.text(tester.strings.commonAtLeast8Chars), findsNothing);
    },
  );

  testWidgets(
    'signing up with a short (7-char) password still shows '
    'commonAtLeast8Chars (D-04 must not relax signup enforcement)',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.tap(
        find.widgetWithText(TextButton, tester.strings.loginToggleToSignUp),
      );
      await tester.pump();
      await fillCredentials(tester, password: 'short12');
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.loginSignUpButton),
      );
      await tester.pump();

      expect(find.text(tester.strings.commonAtLeast8Chars), findsOneWidget);
    },
  );

  testWidgets(
    'signing up with an empty password shows commonAtLeast8Chars, not '
    'commonFieldRequired -- the length check runs before the empty check '
    'in signup mode',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.tap(
        find.widgetWithText(TextButton, tester.strings.loginToggleToSignUp),
      );
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, tester.strings.loginUsernameLabel),
        'newuser',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.loginSignUpButton),
      );
      await tester.pump();

      expect(find.text(tester.strings.commonAtLeast8Chars), findsOneWidget);
    },
  );
}
