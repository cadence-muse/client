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

    test(
      'a local removeFromList() mutation is not reverted by a slower '
      'in-flight background refresh that still includes the removed track '
      '(WR-02)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandTracks('b1', [
          {'id': 't1', 'title': 'Track One', 'artist': 'Artist'},
          {'id': 't2', 'title': 'Track Two', 'artist': 'Artist'},
        ]);

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist'},
                {'id': 't2', 'title': 'Track Two', 'artist': 'Artist'},
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(trackListDataProvider('b1'), (_, _) {});

        // build()'s cache hit fires an unawaited background refresh whose
        // (delayed) response hasn't arrived yet.
        await container.read(trackListDataProvider('b1').future);

        container.read(trackListDataProvider('b1').notifier).removeFromList('t2');

        // Let the delayed background refresh's response resolve.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final finalState = container.read(trackListDataProvider('b1')).valueOrNull;
        expect(finalState, [
          {'id': 't1', 'title': 'Track One', 'artist': 'Artist'},
        ]);
      },
    );
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

    test(
      'a local updateFields() mutation is not clobbered by a slower '
      'in-flight background refresh (WR-02)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandTrackDetail('b1', 't1', {
          'id': 't1',
          'title': 'Cached Track',
          'artist': 'Cached Artist',
        });

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
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
        container.listen(trackDetailDataProvider('b1', 't1'), (_, _) {});

        // build()'s cache hit fires an unawaited background refresh whose
        // (delayed) response hasn't arrived yet.
        await container.read(trackDetailDataProvider('b1', 't1').future);

        container
            .read(trackDetailDataProvider('b1', 't1').notifier)
            .updateFields({'title': 'Locally Renamed Track'});

        // Let the delayed background refresh's response resolve.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final finalState = container
            .read(trackDetailDataProvider('b1', 't1'))
            .valueOrNull;
        expect(finalState, {
          'id': 't1',
          'title': 'Locally Renamed Track',
          'artist': 'Cached Artist',
        });
      },
    );
  });

  group('UserTracksListData', () {
    test(
      'cache-hit returns cached data immediately with a silent background refresh',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserTracks(null, [
          {
            'id': 't1',
            'title': 'Cached Track',
            'artist': 'Cached Artist',
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 't1',
                  'title': 'Cached Track',
                  'artist': 'Cached Artist',
                  'bandId': 'b1',
                  'bandName': 'Band One',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(userTracksListDataProvider.future);

        expect(data, [
          {
            'id': 't1',
            'title': 'Cached Track',
            'artist': 'Cached Artist',
            'bandId': 'b1',
            'bandName': 'Band One',
          },
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
        container.read(userTracksListDataProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(userTracksListDataProvider).hasError, isTrue);
    });

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeUserTracks(null, [
        {
          'id': 't1',
          'title': 'Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't1',
                'title': 'Track',
                'artist': 'Artist',
                'bandId': 'b1',
                'bandName': 'Band One',
              },
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(userTracksListDataProvider, (_, _) {});
      await container.read(userTracksListDataProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      callCount = 0;

      final notifier = container.read(userTracksListDataProvider.notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test(
      'changing selectedBandIdFilterProvider triggers a rebuild whose '
      'listUserTracks call receives the new bandIdFilter',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserTracks(null, [
          {
            'id': 't1',
            'title': 'Track One',
            'artist': 'Artist',
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);
        // No cache seeded for 'band-x' — forces build() to hit the network
        // inline (rather than a background refresh) so capturing the
        // request's query parameter is deterministic.

        final capturedBandIdFilters = <String?>[];
        final apiClient = buildApiClient((request) async {
          capturedBandIdFilters.add(request.url.queryParameters['bandId']);
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 't2',
                  'title': 'Track Two',
                  'artist': 'Artist',
                  'bandId': 'band-x',
                  'bandName': 'Band X',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(userTracksListDataProvider, (_, _) {});
        await container.read(userTracksListDataProvider.future);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        capturedBandIdFilters.clear();

        container
            .read(selectedBandIdFilterProvider.notifier)
            .setFilter('band-x');
        await container.read(userTracksListDataProvider.future);

        expect(capturedBandIdFilters, contains('band-x'));
      },
    );
  });
}
