import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/token_storage.dart';
import 'package:cadence/app.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Copied from `test/widget_test.dart` — a fake secure-storage backend so
/// `TokenStorage` never touches the real platform channel in tests.
class _FakeSecureStorage extends FlutterSecureStoragePlatform
    with MockPlatformInterfaceMixin {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();
}

void main() {
  const bannerText = 'Showing cached data — may be out of date';
  const tabLabels = ['Home', 'Bands', 'Tracks', 'Setlists', 'Profile'];

  /// Mirrors `test/widget_test.dart`'s `MockClient` handler shape, extended
  /// with `/api/track/list` and `/api/setlist/list` — with 1 band seeded via
  /// `/api/band/list`, the global Tracks and Setlists tabs both fetch their
  /// cross-band list endpoint on first build (their filter dropdown renders
  /// once `bands` is non-empty).
  Future<http.Response> handler(http.Request request) async {
    switch (request.url.path) {
      case '/api/band/list':
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'b1', 'name': 'B.A.T.H.', 'membersCount': 1},
            ],
          }),
          200,
        );
      case '/api/homepage':
        return http.Response(
          jsonEncode({'username': 'testuser', 'bandsCount': 1}),
          200,
        );
      case '/api/track/list':
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      case '/api/setlist/list':
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      default:
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'testuser'}),
          200,
        );
    }
  }

  testWidgets(
    'OFFL-05 / ROADMAP Phase 5 success criterion #3: the offline banner is '
    'reachable from, and stays consistent across, every one of the 5 '
    'bottom-nav tabs',
    (tester) async {
      FlutterSecureStoragePlatform.instance = _FakeSecureStorage();
      await TokenStorage().write('test-token');

      final cacheService = CacheService.inMemory();
      final apiClient = ApiClient(
        baseUrl: 'http://localhost',
        getToken: () => 'test-token',
        onUnauthorized: () async {},
        httpClient: MockClient(handler),
      );

      // `connectivityProvider.overrideWith(...)` (function-based override on
      // an AutoDisposeStreamProvider) does not reliably re-trigger a rebuild
      // across a second `tester.pumpWidget()` call in this Riverpod version
      // (2.6.1) — matching 05-04-SUMMARY.md's documented finding that only
      // `overrideWithValue` reliably rebuilds listeners on override change.
      // `isOnlineProvider` (a plain `AutoDisposeProvider<bool>`) supports
      // `overrideWithValue` directly, so the online/offline transition is
      // driven through it instead, one layer downstream of
      // `connectivityProvider` but the exact same signal every gated screen
      // and the `OfflineBanner` itself watches.
      Widget buildApp(ConnectivityStatus status) {
        return ProviderScope(
          overrides: [
            cacheServiceProvider.overrideWithValue(cacheService),
            apiClientProvider.overrideWithValue(apiClient),
            isOnlineProvider.overrideWithValue(
              status == ConnectivityStatus.online,
            ),
          ],
          child: const CadenceApp(),
        );
      }

      // Offline: the banner must show, exactly once, on every tab.
      await tester.pumpWidget(buildApp(ConnectivityStatus.offline));
      await tester.pumpAndSettle();

      for (final label in tabLabels) {
        // A plain `find.text(label)` is ambiguous once a tab is selected —
        // its own AppBar title text can match the nav label too (e.g. both
        // say "Home"). Scope the finder to the NavigationBar itself so the
        // tap always targets the nav destination, not the screen content.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(bannerText),
          findsOneWidget,
          reason:
              'Offline banner missing (or duplicated) on the $label tab '
              'while isOnlineProvider is false',
        );
      }

      // Online: rebuild with a fresh connectivity override and confirm the
      // banner is gone on the currently-visible (Profile, last tab tapped)
      // tab.
      await tester.pumpWidget(buildApp(ConnectivityStatus.online));
      await tester.pumpAndSettle();

      expect(find.text(bannerText), findsNothing);
    },
  );
}
