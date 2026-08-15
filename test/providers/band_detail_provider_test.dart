import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/bands_provider.dart';
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

  ProviderContainer buildContainer(
    ApiClient apiClient,
    CacheService cacheService,
  ) {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'cache-hit returns cached detail map immediately with a silent background refresh',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', {
        'id': 'b1',
        'name': 'Cached Band',
        'ownerId': 'u1',
        'members': [
          {'id': 'u1', 'username': 'alice'},
        ],
        'inviteCode': 'abc-123',
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'b1',
            'name': 'Cached Band',
            'ownerId': 'u1',
            'members': [
              {'id': 'u1', 'username': 'alice'},
            ],
            'inviteCode': 'abc-123',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandDetailDataProvider('b1').future);

      expect(data['id'], 'b1');
      expect(data['name'], 'Cached Band');
    },
  );
}
