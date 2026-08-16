import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/tracks_provider.dart';
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

  group('TrackListData', () {
    test(
      'cache-hit returns cached data immediately with a silent background refresh',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandTracks('b1', [
          {'id': 't1', 'title': 'Cached Track', 'artist': 'Cached Artist'},
        ]);

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Cached Track', 'artist': 'Cached Artist'},
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(trackListDataProvider('b1').future);

        expect(data, [
          {'id': 't1', 'title': 'Cached Track', 'artist': 'Cached Artist'},
        ]);
      },
    );

    test('no cache and network failure yields AsyncError', () async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'network_error', 'message': 'offline'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      await expectLater(
        container.read(trackListDataProvider('b1').future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(trackListDataProvider('b1')).hasError, isTrue);
    });

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Track', 'artist': 'Artist'},
      ]);

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 't1', 'title': 'Track', 'artist': 'Artist'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(trackListDataProvider('b1'), (_, _) {});
      await container.read(trackListDataProvider('b1').future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      callCount = 0;

      final notifier = container.read(trackListDataProvider('b1').notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });
  });

  group('TrackDetailData', () {
    test(
      'cache-hit returns cached data immediately with a silent background refresh',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandTrackDetail('b1', 't1', {
          'id': 't1',
          'title': 'Cached Track',
          'artist': 'Cached Artist',
        });

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 't1',
              'title': 'Cached Track',
              'artist': 'Cached Artist',
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(
          trackDetailDataProvider('b1', 't1').future,
        );

        expect(data, {
          'id': 't1',
          'title': 'Cached Track',
          'artist': 'Cached Artist',
        });
      },
    );

    test('no cache and network failure yields AsyncError', () async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'network_error', 'message': 'offline'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      await expectLater(
        container.read(trackDetailDataProvider('b1', 't1').future),
        throwsA(isA<ApiException>()),
      );
      expect(
        container.read(trackDetailDataProvider('b1', 't1')).hasError,
        isTrue,
      );
    });

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTrackDetail('b1', 't1', {
        'id': 't1',
        'title': 'Track',
        'artist': 'Artist',
      });

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({'id': 't1', 'title': 'Track', 'artist': 'Artist'}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(trackDetailDataProvider('b1', 't1'), (_, _) {});
      await container.read(trackDetailDataProvider('b1', 't1').future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      callCount = 0;

      final notifier = container.read(
        trackDetailDataProvider('b1', 't1').notifier,
      );
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });
  });
}
