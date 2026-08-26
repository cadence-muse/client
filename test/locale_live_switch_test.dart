import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/token_storage.dart';
import 'package:cadence/app.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/home/home_screen.dart';
import 'package:cadence/features/settings/settings_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_strings.dart';

/// Copied from `test/offline_cross_tab_test.dart` — a fake secure-storage
/// backend so `TokenStorage` never touches the real platform channel in
/// tests.
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
  /// Mirrors `test/offline_cross_tab_test.dart`'s `MockClient` handler
  /// shape — 1 band seeded via `/api/band/list` so the app boots cleanly.
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
      default:
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'testuser'}),
          200,
        );
    }
  }

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        cacheServiceProvider.overrideWithValue(CacheService.inMemory()),
        apiClientProvider.overrideWithValue(
          ApiClient(
            baseUrl: 'http://localhost',
            getToken: () => 'test-token',
            onUnauthorized: () async {},
            httpClient: MockClient(handler),
          ),
        ),
        isOnlineProvider.overrideWithValue(true),
      ],
      child: const CadenceApp(),
    );
  }

  Future<void> goToSettings(WidgetTester tester) async {
    // The nav-bar's Profile label is now localized (13-07); evaluate
    // tester.strings fresh at call time so this helper works whether the
    // app's active locale is English (first call) or a persisted Russian
    // (post-restart calls in I18N-03), rather than a hardcoded literal.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(tester.strings.navProfile),
      ),
    );
    await tester.pumpAndSettle();

    // profile_screen.dart's "Settings" menu item is localized (13-06), so
    // this must also read off the live locale rather than a hardcoded
    // English literal -- otherwise post-restart calls in I18N-03 (locale
    // persisted as Russian) fail to find the tile.
    await tester.tap(find.text(tester.strings.profileSettingsLabel));
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = _FakeSecureStorage();
  });

  testWidgets(
    'I18N-01/02: fresh install defaults to English; switching to Russian '
    'in Settings applies live',
    (tester) async {
      await TokenStorage().write('test-token');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await goToSettings(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);

      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();

      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Язык'), findsOneWidget);
    },
  );

  testWidgets(
    'I18N-02 success criterion 5: an IndexedStack tab kept alive in the '
    'background reports the new locale once navigated to',
    (tester) async {
      await TokenStorage().write('test-token');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Home (index 0) is the tab visible from app start, so it is already
      // mounted-but-inactive once we navigate away below. Assert its
      // AppBar renders the real English title (13-05 localized
      // home_screen.dart) before the switch, not just the ambient locale.
      // Scoped to AppBar since the nav-bar's Home label (13-07) renders the
      // identical English text "Home", which would otherwise be ambiguous.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(tester.strings.homeAppBarTitle),
        ),
        findsOneWidget,
      );

      await goToSettings(tester);

      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();

      // Pop Settings back to Profile.
      Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
      await tester.pumpAndSettle();

      // Navigate back to the Home tab, which was kept alive (but inactive)
      // in the background while the language switch happened. The nav-bar
      // label itself is now localized (13-07), so this must be evaluated
      // fresh right before the tap -- tester.strings reads off whichever
      // locale is CURRENTLY active (Russian, at this point in the test),
      // not a value captured earlier.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tester.strings.navHome),
        ),
      );
      await tester.pumpAndSettle();

      // Cheap sanity check: the ambient locale value changed.
      expect(
        Localizations.localeOf(
          tester.element(find.byType(HomeScreen)),
        ).languageCode,
        'ru',
      );
      // The real proof: the previously-inactive Home tab actually
      // re-rendered its text content in Russian, not just the ambient
      // Localizations value. Scoped to AppBar for the same reason as above.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(tester.strings.homeAppBarTitle),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'I18N-03: selecting Russian persists across a simulated app restart',
    (tester) async {
      await TokenStorage().write('test-token');

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await goToSettings(tester);
      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();

      // Simulate closing and reopening the app: a brand-new ProviderScope
      // / CadenceApp pump, backed by the same (not reset) SharedPreferences
      // mock store. Pumping an unrelated widget first forces Flutter to
      // fully tear down the old element tree (disposing its ProviderScope
      // container and Navigator stack) rather than reusing it — otherwise
      // the still-pushed SettingsScreen route (and its ProviderContainer)
      // would simply survive the second pumpWidget() call, which is not a
      // real restart.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await goToSettings(tester);

      expect(find.text('Настройки'), findsOneWidget);
    },
  );
}
