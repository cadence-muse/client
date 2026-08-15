import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/home/home_screen.dart';
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
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('bandsCount 0 shows "No bands yet" + "Create Band"', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeHomepage({'username': 'alice', 'bandsCount': 0});

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'username': 'alice', 'bandsCount': 0}),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text('No bands yet'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Create Band'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('bandsCount 1 shows "1 band" (singular)', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeHomepage({'username': 'alice', 'bandsCount': 1});

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'username': 'alice', 'bandsCount': 1}),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text('1 band'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('bandsCount 2 shows "2 bands" (plural)', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeHomepage({'username': 'alice', 'bandsCount': 2});

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'username': 'alice', 'bandsCount': 2}),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text('2 bands'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('bandsCount 1250 shows "1,250 bands" (comma-grouped, exact)', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeHomepage({
      'username': 'alice',
      'bandsCount': 1250,
    });

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'username': 'alice', 'bandsCount': 1250}),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text('1,250 bands'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'no cache and network failure shows "Couldn\'t load home" + Retry',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'network_error', 'message': 'offline'}),
          500,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load home"), findsOneWidget);
      expect(
        find.text('Please check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'username longer than 20 characters truncates to a single line with ellipsis',
    (tester) async {
      const longUsername = 'a_very_long_username_that_exceeds_twenty_chars';
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({
        'username': longUsername,
        'bandsCount': 3,
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'username': longUsername, 'bandsCount': 3}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      final textWidget = tester.widget<Text>(
        find.text('Welcome, $longUsername'),
      );
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      await tester.pumpAndSettle();
    },
  );
}
