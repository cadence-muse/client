import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/profile/change_password_screen.dart';
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
      child: const MaterialApp(home: ChangePasswordScreen()),
    );
  }

  /// Mounts a fake root screen with a button that pushes
  /// [ChangePasswordScreen] on top of it, mirroring
  /// `band_detail_screen_test.dart`'s `wrapWithListRoot` pattern, so a
  /// successful submit's pop-back is observable.
  Widget wrapWithListRoot(ApiClient apiClient, CacheService cacheService) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
                child: const Text('Profile root'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String current = 'oldpassword',
    String next = 'newpassword123',
    String confirm = 'newpassword123',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      current,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      next,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      confirm,
    );
  }

  testWidgets('renders 3 obscured password fields with expected labels', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));

    expect(
      find.widgetWithText(TextFormField, 'Current password'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'New password'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNWidgets(3));

    // TextFormField doesn't expose obscureText as a public field on itself
    // (it's forwarded internally to the TextField it builds), so assert on
    // the rendered TextField descendants instead.
    expect(find.byType(TextField), findsNWidgets(3));
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.obscureText, isTrue);
    }
  });

  testWidgets('empty current password shows required error, no API call', (
    tester,
  ) async {
    var calls = 0;
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      calls++;
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await fillForm(tester, current: '');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pump();

    expect(find.text('This field is required'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('new password under 8 chars shows length error', (tester) async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await fillForm(tester, next: 'short', confirm: 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pump();

    expect(find.text('At least 8 characters'), findsOneWidget);
  });

  testWidgets("mismatched confirm shows Passwords don't match error", (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await fillForm(
      tester,
      next: 'newpassword123',
      confirm: 'differentpassword',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pump();

    expect(find.text("Passwords don't match"), findsOneWidget);
  });

  testWidgets(
    'valid submit calls changePassword, shows SnackBar, and pops back',
    (tester) async {
      final requests = <http.Request>[];
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        requests.add(request);
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrapWithListRoot(apiClient, cacheService));
      await tester.tap(find.text('Profile root'));
      await tester.pumpAndSettle();

      await fillForm(
        tester,
        current: 'oldpassword',
        next: 'newpassword123',
        confirm: 'newpassword123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/me/password');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['currentPassword'], 'oldpassword');
      expect(body['password'], 'newpassword123');

      expect(find.text('Password changed successfully'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.text('Profile root'), findsOneWidget);
    },
  );

  testWidgets(
    '400 invalid_input shows "Current password is incorrect" inline error',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'invalid_input',
            'message': 'current password does not match',
          }),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await fillForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(find.text('Current password is incorrect'), findsOneWidget);
      expect(find.text('current password does not match'), findsNothing);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('500 server_error shows the raw e.message verbatim', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'code': 'server_error', 'message': 'Something broke'}),
        500,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();

    expect(find.text('Something broke'), findsOneWidget);
  });

  testWidgets(
    'while in flight, submit button is disabled and shows a spinner',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await fillForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets('typing in a field after an error clears the error text', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'code': 'invalid_input', 'message': 'nope'}),
        400,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await fillForm(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'oldpassword2',
    );
    await tester.pump();

    expect(find.text('Current password is incorrect'), findsNothing);
  });
}
