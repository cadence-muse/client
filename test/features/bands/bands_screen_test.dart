import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_avatar.dart';
import 'package:cadence/features/bands/bands_screen.dart';
import 'package:cadence/features/bands/create_band_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  // Routes `/api/me` to [profile] before delegating to [handler] for
  // everything else (band-list GET, mutations, etc.) -- since BandsScreen
  // now watches `profileDataProvider`, every mock handler must be able to
  // answer `GET /api/me` or the profile provider will error/hang.
  ApiClient buildApiClient(
    Future<http.Response> Function(http.Request) handler, {
    Map<String, dynamic> profile = const {'id': 'u1', 'username': 'tester'},
  }) {
    return ApiClient(
      baseUrl: 'http://localhost',
      getToken: () => 'test-token',
      onUnauthorized: () async {},
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/me') {
          return http.Response(jsonEncode(profile), 200);
        }
        return handler(request);
      }),
    );
  }

  // Defaults isOnlineProvider to true so pre-existing tests (which predate
  // OFFL-03's connectivity gating) keep exercising the "online" path unless a
  // test explicitly overrides it — real-app connectivity_plus resolves
  // AsyncLoading/AsyncError to `false` in this sandboxed test environment
  // with no platform-channel mock, which would otherwise disable every
  // mutation entry point by default.
  Widget wrap(
    ApiClient apiClient,
    CacheService cacheService, {
    bool isOnline = true,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        isOnlineProvider.overrideWithValue(isOnline),
      ],
      child: const MaterialApp(home: BandsScreen()),
    );
  }

  testWidgets('populated list renders a ListTile with BandAvatar per band', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([
      {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
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

  testWidgets(
    'no cache and network failure shows "Couldn\'t load bands" + Retry',
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

      expect(find.text("Couldn't load bands"), findsOneWidget);
      expect(
        find.text('Please check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'band name longer than 30 characters truncates to a single line with ellipsis',
    (tester) async {
      const longName = 'A Band Name That Is Definitely Over Thirty Chars';
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': longName, 'membersCount': 1},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': longName, 'membersCount': 1},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      final textWidget = tester.widget<Text>(find.text(longName));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'two bands with the same name but different ids render as two separate ListTiles',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Same', 'membersCount': 1},
        {'id': 'b', 'name': 'Same', 'membersCount': 1},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Same', 'membersCount': 1},
              {'id': 'b', 'name': 'Same', 'membersCount': 1},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(2));

      await tester.pumpAndSettle();
    },
  );

  testWidgets('SyncStatusBadge is present once the bands list loads', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([
      {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
    ]);
    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.byType(SyncStatusBadge), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('FAB is disabled and tooltipped while offline', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService, isOnline: false));
    await tester.pump();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNull);
    expect(fab.tooltip, 'Requires connection');

    await tester.pumpAndSettle();
  });

  testWidgets('FAB is enabled while online', (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNotNull);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'tapping the FAB shows a bottom sheet with exactly "Create band" and '
    '"Join with code"',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Create band'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Join with code'),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsNWidgets(2));
    },
  );

  testWidgets('tapping "Create band" in the FAB menu navigates to CreateBandScreen', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Create band'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateBandScreen), findsOneWidget);
  });

  testWidgets('tapping "Join with code" in the FAB menu opens the join dialog', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([]);
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Join with code'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Join a band'), findsOneWidget);
  });

  testWidgets(
    'tapping the empty-state "Create Band" button navigates to CreateBandScreen',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([]);
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Band'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateBandScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a band whose ownerId matches the current profile shows '
    '"N member(s) • Owner" in trailing (BAND-10)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 1, 'ownerId': 'u1'},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'a',
                'name': 'The Testers',
                'membersCount': 1,
                'ownerId': 'u1',
              },
            ],
          }),
          200,
        );
      }, profile: {'id': 'u1', 'username': 'tester'});

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('1 member • Owner'), findsOneWidget);
    },
  );

  testWidgets(
    'a band whose ownerId does not match the current profile shows '
    '"N member(s) • Member" in trailing (BAND-10)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 1, 'ownerId': 'u1'},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'a',
                'name': 'The Testers',
                'membersCount': 1,
                'ownerId': 'u1',
              },
            ],
          }),
          200,
        );
      }, profile: {'id': 'u2', 'username': 'tester'});

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('1 member • Member'), findsOneWidget);
    },
  );

  testWidgets(
    'a band with no ownerId key shows just the member count, with no '
    'bullet or role (BAND-10 graceful degradation)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 1},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('1 member'), findsOneWidget);
    },
  );

  testWidgets(
    'a band with membersCount 5 shows the plural "5 members" (BAND-10)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'The Testers', 'membersCount': 5},
      ]);
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'The Testers', 'membersCount': 5},
            ],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('5 members'), findsOneWidget);
    },
  );
}
