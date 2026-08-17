import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_detail_screen.dart';
import 'package:cadence/features/bands/create_band_screen.dart';
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

  // Defaults isOnlineProvider to true so pre-existing tests (which predate
  // OFFL-03's connectivity gating) keep exercising the "online" path unless a
  // test explicitly overrides it — real-app connectivity_plus resolves
  // AsyncLoading/AsyncError to `false` in this sandboxed test environment
  // with no platform-channel mock, which would otherwise disable the Create
  // button by default.
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
      child: const MaterialApp(home: CreateBandScreen()),
    );
  }

  testWidgets('starts with an empty name field', (tester) async {
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'id': 'b1'}), 201);
    });

    await tester.pumpWidget(wrap(apiClient));

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('Create button is disabled while submitting', (tester) async {
    final apiClient = buildApiClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (request.method == 'POST' && request.url.path == '/api/band') {
        return http.Response(jsonEncode({'id': 'b1'}), 201);
      }
      return http.Response(
        jsonEncode({
          'id': 'b1',
          'name': 'The Testers',
          'members': <Map<String, dynamic>>[],
          'inviteCode': 'abc123',
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient));
    await tester.enterText(find.byType(TextFormField), 'The Testers');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'submitting a valid name calls createBand and navigates to BandDetailScreen',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        if (request.method == 'POST' && request.url.path == '/api/band') {
          requestBody = request.body;
          return http.Response(jsonEncode({'id': 'b1'}), 201);
        }
        return http.Response(
          jsonEncode({
            'id': 'b1',
            'name': 'The Testers',
            'members': <Map<String, dynamic>>[],
            'inviteCode': 'abc123',
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), 'The Testers');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(requestBody, jsonEncode({'name': 'The Testers'}));
      expect(find.byType(BandDetailScreen), findsOneWidget);
      expect(find.text('The Testers created!'), findsOneWidget);
    },
  );

  testWidgets('empty/whitespace-only name is rejected without an API call', (
    tester,
  ) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      return http.Response(jsonEncode({'id': 'b1'}), 201);
    });

    await tester.pumpWidget(wrap(apiClient));
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pump();

    expect(callCount, 0);
    expect(find.text('Enter a band name'), findsOneWidget);
  });

  testWidgets(
    'a createBand() failure renders an inline error and re-enables the '
    'Create button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Name is taken'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), 'The Testers');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Name is taken'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a non-ApiException failure (e.g. offline) shows the generic fallback '
    'message and re-enables the Create button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        throw const SocketException('Network is unreachable');
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), 'The Testers');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Create button is disabled and reads "Requires connection" while '
    'offline; enabled with a valid form while online',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'id': 'b1'}), 201);
      });

      await tester.pumpWidget(wrap(apiClient, isOnline: false));
      await tester.enterText(find.byType(TextFormField), 'The Testers');
      await tester.pump();

      final offlineButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(offlineButton.onPressed, isNull);
      expect(find.text('Requires connection'), findsOneWidget);

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), 'The Testers');
      await tester.pump();

      final onlineButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(onlineButton.onPressed, isNotNull);
      expect(find.text('Create'), findsOneWidget);
    },
  );

  testWidgets(
    'a band name longer than 30 characters does not break the '
    "TextFormField's layout",
    (tester) async {
      const longName =
          'A Band Name That Is Definitely Over Thirty Characters Long';
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'id': 'b1'}), 201);
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), longName);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsOneWidget);
    },
  );
}
