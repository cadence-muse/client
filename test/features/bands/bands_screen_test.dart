import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_avatar.dart';
import 'package:cadence/features/bands/bands_screen.dart';
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
      child: const MaterialApp(home: BandsScreen()),
    );
  }

  testWidgets('populated list renders a ListTile with BandAvatar per band', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([
      {'id': 'a', 'name': 'The Testers'},
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'a', 'name': 'The Testers'},
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text('The Testers'), findsOneWidget);
    expect(find.byType(BandAvatar), findsOneWidget);

    // Drain the background refresh build() fires on a cache hit so no
    // dangling Future is left pending when the test body returns.
    await tester.pumpAndSettle();
  });

  testWidgets('empty list shows "No bands yet" empty state', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': []}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text('No bands yet'), findsOneWidget);
    expect(
      find.text(
        'Create a band or ask a bandmate for an invite code to join one.',
      ),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
  });
}
