import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/profile/profile_screen.dart';
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
      child: const MaterialApp(home: ProfileScreen()),
    );
  }

  testWidgets('cached data present renders immediately with no spinner', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeProfile({'id': 'u1', 'username': 'cacheduser'});

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'id': 'u1', 'username': 'cacheduser'}),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('cacheduser'), findsOneWidget);

    // Drain the background refresh build() fires on a cache hit so no
    // dangling Future is left pending when the test body returns.
    await tester.pumpAndSettle();
  });

  testWidgets(
    'no cache and network failure shows error state with Retry button',
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

      expect(find.text("Couldn't load profile"), findsOneWidget);
      expect(
        find.text('Please check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'background refresh silently replaces displayed data with no spinner',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'oldname'});

      final apiClient = buildApiClient((request) async {
        // Small delay so the cached "oldname" frame is observable before the
        // background refresh (fired from build() on the cache hit) replaces it.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'newname'}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.text('oldname'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('newname'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'tapping refresh twice quickly triggers exactly one network call',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'user'});

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode({'id': 'u1', 'username': 'user'}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      // Let the initial background refresh (fired from the cache-hit build())
      // complete before measuring the refresh button's own dedup behavior.
      await tester.pumpAndSettle();
      callCount = 0;

      await tester.tap(find.byTooltip('Refresh'));
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    },
  );

  testWidgets(
    'username longer than 20 characters truncates to a single line with ellipsis',
    (tester) async {
      const longUsername = 'a_very_long_username_that_exceeds_twenty_chars';
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': longUsername});

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 'u1', 'username': longUsername}),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      final textWidget = tester.widget<Text>(find.text(longUsername));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      // Drain the background refresh build() fires on a cache hit so no
      // dangling Future is left pending when the test body returns.
      await tester.pumpAndSettle();
    },
  );
}
