import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/setlists_provider.dart';
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

  group('SetlistListData', () {
    test(
      'cache-hit returns cached data immediately with a silent background refresh',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandSetlists('b1', [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
          },
        ]);

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Cached Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(
          setlistListDataProvider('b1').future,
        );

        expect(data, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
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
        container.read(setlistListDataProvider('b1').future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(setlistListDataProvider('b1')).hasError, isTrue);
    });

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': 'Setlist',
          'tracksCount': 1,
          'durationSeconds': 200,
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
                'id': 's1',
                'name': 'Setlist',
                'tracksCount': 1,
                'durationSeconds': 200,
              },
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(setlistListDataProvider('b1'), (_, _) {});
      await container.read(setlistListDataProvider('b1').future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      callCount = 0;

      final notifier = container.read(setlistListDataProvider('b1').notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test(
      'a local removeFromList() mutation is not reverted by a slower '
      'in-flight background refresh that still includes the removed '
      'setlist (WR-02)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandSetlists('b1', [
          {
            'id': 's1',
            'name': 'Setlist One',
            'tracksCount': 1,
            'durationSeconds': 200,
          },
          {
            'id': 's2',
            'name': 'Setlist Two',
            'tracksCount': 2,
            'durationSeconds': 400,
          },
        ]);

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Setlist One',
                  'tracksCount': 1,
                  'durationSeconds': 200,
                },
                {
                  'id': 's2',
                  'name': 'Setlist Two',
                  'tracksCount': 2,
                  'durationSeconds': 400,
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistListDataProvider('b1'), (_, _) {});

        // build()'s cache hit fires an unawaited background refresh whose
        // (delayed) response hasn't arrived yet.
        await container.read(setlistListDataProvider('b1').future);

        container
            .read(setlistListDataProvider('b1').notifier)
            .removeFromList('s2');

        // Let the delayed background refresh's response resolve.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final finalState = container
            .read(setlistListDataProvider('b1'))
            .valueOrNull;
        expect(finalState, [
          {
            'id': 's1',
            'name': 'Setlist One',
            'tracksCount': 1,
            'durationSeconds': 200,
          },
        ]);
      },
    );

    test(
      'on a cache hit, setlistListSyncedAtProvider resolves to the '
      "pre-seeded cache's syncedAt before the background refresh settles, "
      'then updates to a later value once the background refresh completes',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandSetlists('b1', [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
          },
        ]);
        final seededSyncedAt = await cacheService.readBandSetlistsSyncedAt(
          'b1',
        );

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Fresh Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistListDataProvider('b1'), (_, _) {});
        container.listen(setlistListSyncedAtProvider('b1'), (_, _) {});

        await container.read(setlistListDataProvider('b1').future);

        expect(
          container.read(setlistListSyncedAtProvider('b1')),
          seededSyncedAt,
        );

        // Drain the background refresh fired from build()'s cache hit.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final refreshedSyncedAt = container.read(
          setlistListSyncedAtProvider('b1'),
        );
        expect(refreshedSyncedAt, isNotNull);
        expect(refreshedSyncedAt!.isAfter(seededSyncedAt!), isTrue);
      },
    );
  });

  group('SetlistDetailData', () {
    test(
      'cache-hit returns cached data immediately with a silent background refresh',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 600,
          'tracks': [
            {
              'trackId': 't1',
              'position': 0,
              'title': 'Track One',
              'artist': 'Artist',
            },
          ],
        });

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Cached Setlist',
              'durationSeconds': 600,
              'tracks': [
                {
                  'trackId': 't1',
                  'position': 0,
                  'title': 'Track One',
                  'artist': 'Artist',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(
          setlistDetailDataProvider('b1', 's1').future,
        );

        expect(data['name'], 'Cached Setlist');
        expect((data['tracks'] as List), hasLength(1));
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
        container.read(setlistDetailDataProvider('b1', 's1').future),
        throwsA(isA<ApiException>()),
      );
      expect(
        container.read(setlistDetailDataProvider('b1', 's1')).hasError,
        isTrue,
      );
    });

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeSetlistDetail('b1', 's1', {
        'id': 's1',
        'name': 'Setlist',
        'durationSeconds': 200,
        'tracks': <Map<String, dynamic>>[],
      });

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 200,
            'tracks': <Map<String, dynamic>>[],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
      await container.read(setlistDetailDataProvider('b1', 's1').future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      callCount = 0;

      final notifier = container.read(
        setlistDetailDataProvider('b1', 's1').notifier,
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
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 200,
          'tracks': <Map<String, dynamic>>[],
        });

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Cached Setlist',
              'durationSeconds': 200,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});

        // build()'s cache hit fires an unawaited background refresh whose
        // (delayed) response hasn't arrived yet.
        await container.read(setlistDetailDataProvider('b1', 's1').future);

        container
            .read(setlistDetailDataProvider('b1', 's1').notifier)
            .updateFields({'name': 'Locally Renamed Setlist'});

        // Let the delayed background refresh's response resolve.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final finalState = container
            .read(setlistDetailDataProvider('b1', 's1'))
            .valueOrNull;
        expect(finalState, {
          'id': 's1',
          'name': 'Locally Renamed Setlist',
          'durationSeconds': 200,
          'tracks': <Map<String, dynamic>>[],
        });
      },
    );

    test(
      'reorderTracks() reorders the tracks list to match the given trackIds, '
      'preserving each track\'s full map (not just its id)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Setlist',
          'durationSeconds': 600,
          'tracks': [
            {
              'trackId': 'A',
              'position': 0,
              'title': 'Track A',
              'artist': 'Artist A',
              'durationSeconds': 200,
            },
            {
              'trackId': 'B',
              'position': 1,
              'title': 'Track B',
              'artist': 'Artist B',
              'durationSeconds': 200,
            },
            {
              'trackId': 'C',
              'position': 2,
              'title': 'Track C',
              'artist': 'Artist C',
              'durationSeconds': 200,
            },
          ],
        });

        // Matches the cached payload exactly — build()'s unawaited
        // background refresh (fired on the cache hit below) must not
        // corrupt the tracks list this test asserts against once it
        // resolves.
        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Setlist',
              'durationSeconds': 600,
              'tracks': [
                {
                  'trackId': 'A',
                  'position': 0,
                  'title': 'Track A',
                  'artist': 'Artist A',
                  'durationSeconds': 200,
                },
                {
                  'trackId': 'B',
                  'position': 1,
                  'title': 'Track B',
                  'artist': 'Artist B',
                  'durationSeconds': 200,
                },
                {
                  'trackId': 'C',
                  'position': 2,
                  'title': 'Track C',
                  'artist': 'Artist C',
                  'durationSeconds': 200,
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
        await container.read(setlistDetailDataProvider('b1', 's1').future);
        // Let the background refresh resolve before mutating, so it can't
        // race with reorderTracks()'s state write below.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await container
            .read(setlistDetailDataProvider('b1', 's1').notifier)
            .reorderTracks(['C', 'A', 'B']);

        final tracks =
            container
                    .read(setlistDetailDataProvider('b1', 's1'))
                    .valueOrNull!['tracks']
                as List;
        expect(tracks, [
          {
            'trackId': 'C',
            'position': 2,
            'title': 'Track C',
            'artist': 'Artist C',
            'durationSeconds': 200,
          },
          {
            'trackId': 'A',
            'position': 0,
            'title': 'Track A',
            'artist': 'Artist A',
            'durationSeconds': 200,
          },
          {
            'trackId': 'B',
            'position': 1,
            'title': 'Track B',
            'artist': 'Artist B',
            'durationSeconds': 200,
          },
        ]);
      },
    );

    test(
      'reorderTracks() is a local patch only — it never triggers a network '
      'call',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Setlist',
          'durationSeconds': 400,
          'tracks': [
            {
              'trackId': 'A',
              'position': 0,
              'title': 'Track A',
              'artist': 'Artist A',
            },
            {
              'trackId': 'B',
              'position': 1,
              'title': 'Track B',
              'artist': 'Artist B',
            },
          ],
        });

        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Setlist',
              'durationSeconds': 400,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
        // build()'s cache hit fires an unawaited background refresh — let it
        // resolve before resetting callCount so it isn't misattributed to
        // reorderTracks() below.
        await container.read(setlistDetailDataProvider('b1', 's1').future);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        callCount = 0;

        await container
            .read(setlistDetailDataProvider('b1', 's1').notifier)
            .reorderTracks(['B', 'A']);

        expect(callCount, 0);
      },
    );

    test(
      'on a cache hit, setlistDetailSyncedAtProvider resolves to the '
      "pre-seeded cache's syncedAt before the background refresh settles, "
      'then updates to a later value once the background refresh completes',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 600,
          'tracks': <Map<String, dynamic>>[],
        });
        final seededSyncedAt = await cacheService.readSetlistDetailSyncedAt(
          'b1',
          's1',
        );

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Fresh Setlist',
              'durationSeconds': 600,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
        container.listen(
          setlistDetailSyncedAtProvider('b1', 's1'),
          (_, _) {},
        );

        await container.read(setlistDetailDataProvider('b1', 's1').future);

        expect(
          container.read(setlistDetailSyncedAtProvider('b1', 's1')),
          seededSyncedAt,
        );

        // Drain the background refresh fired from build()'s cache hit.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final refreshedSyncedAt = container.read(
          setlistDetailSyncedAtProvider('b1', 's1'),
        );
        expect(refreshedSyncedAt, isNotNull);
        expect(refreshedSyncedAt!.isAfter(seededSyncedAt!), isTrue);
      },
    );
  });

  group('UserSetlistsListData', () {
    test(
      'cache-hit returns cached data immediately with a silent background refresh',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserSetlists(null, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Cached Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                  'bandId': 'b1',
                  'bandName': 'Band One',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(userSetlistsListDataProvider.future);

        expect(data, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
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
        container.read(userSetlistsListDataProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(userSetlistsListDataProvider).hasError, isTrue);
    });

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeUserSetlists(null, [
        {
          'id': 's1',
          'name': 'Setlist',
          'tracksCount': 1,
          'durationSeconds': 200,
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
                'id': 's1',
                'name': 'Setlist',
                'tracksCount': 1,
                'durationSeconds': 200,
                'bandId': 'b1',
                'bandName': 'Band One',
              },
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(userSetlistsListDataProvider, (_, _) {});
      await container.read(userSetlistsListDataProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      callCount = 0;

      final notifier = container.read(userSetlistsListDataProvider.notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test(
      'on a cache hit, userSetlistsSyncedAtProvider resolves to the '
      "pre-seeded cache's syncedAt before the background refresh settles, "
      'then updates to a later value once the background refresh completes',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserSetlists(null, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);
        final seededSyncedAt = await cacheService.readUserSetlistsSyncedAt(
          null,
        );

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Fresh Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                  'bandId': 'b1',
                  'bandName': 'Band One',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(userSetlistsListDataProvider, (_, _) {});
        container.listen(userSetlistsSyncedAtProvider, (_, _) {});

        await container.read(userSetlistsListDataProvider.future);

        expect(container.read(userSetlistsSyncedAtProvider), seededSyncedAt);

        // Drain the background refresh fired from build()'s cache hit.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final refreshedSyncedAt = container.read(userSetlistsSyncedAtProvider);
        expect(refreshedSyncedAt, isNotNull);
        expect(refreshedSyncedAt!.isAfter(seededSyncedAt!), isTrue);
      },
    );

    test(
      'changing selectedSetlistBandIdFilterProvider triggers a rebuild whose '
      'listUserSetlists call receives the new bandIdFilter',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserSetlists(null, [
          {
            'id': 's1',
            'name': 'Setlist One',
            'tracksCount': 1,
            'durationSeconds': 200,
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
                  'id': 's2',
                  'name': 'Setlist Two',
                  'tracksCount': 1,
                  'durationSeconds': 200,
                  'bandId': 'band-x',
                  'bandName': 'Band X',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(userSetlistsListDataProvider, (_, _) {});
        await container.read(userSetlistsListDataProvider.future);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        capturedBandIdFilters.clear();

        container
            .read(selectedSetlistBandIdFilterProvider.notifier)
            .setFilter('band-x');
        await container.read(userSetlistsListDataProvider.future);

        expect(capturedBandIdFilters, contains('band-x'));
      },
    );
  });
}
