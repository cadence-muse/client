import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/profile_provider.dart';
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
    'on a cache hit, profileSyncedAtProvider resolves to the pre-seeded '
    "cache's syncedAt before the background refresh settles, then updates "
    'to a later value once the background refresh completes',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'cacheduser'});
      final seededSyncedAt = await cacheService.readProfileSyncedAt();

      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'freshuser'}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      // Keep both (autoDispose) providers alive across the gaps below,
      // mirroring the persistent subscription a widget's ref.watch would
      // hold in production (ProfileScreen watches both).
      container.listen(profileDataProvider, (_, _) {});
      container.listen(profileSyncedAtProvider, (_, _) {});

      await container.read(profileDataProvider.future);

      expect(container.read(profileSyncedAtProvider), seededSyncedAt);

      // Drain the background refresh fired from build()'s cache hit.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final refreshedSyncedAt = container.read(profileSyncedAtProvider);
      expect(refreshedSyncedAt, isNotNull);
      expect(refreshedSyncedAt!.isAfter(seededSyncedAt!), isTrue);
    },
  );
}
