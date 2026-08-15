import 'dart:io';

import 'package:cadence/api/token_storage.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Spy double for [CacheService] that records whether [clearAll] fired,
/// so tests can prove the sign-out privacy mitigation (cache clear on
/// sign-out) actually runs without depending on real Hive storage.
class _FakeCacheService implements CacheService {
  final Map<String, dynamic> _profile = {};
  int clearAllCallCount = 0;
  bool get clearAllCalled => clearAllCallCount > 0;

  @override
  Future<Map<String, dynamic>?> readProfile() async => _profile.isEmpty
      ? null
      : Map<String, dynamic>.from(_profile);

  @override
  Future<void> writeProfile(Map<String, dynamic> data) async {
    _profile
      ..clear()
      ..addAll(data);
  }

  @override
  Future<void> clearAll() async {
    clearAllCallCount++;
    _profile.clear();
  }
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = _FakeSecureStorage();
  });

  ProviderContainer buildContainer({_FakeCacheService? fakeCacheService}) {
    final container = ProviderContainer(
      overrides: [
        cacheServiceProvider.overrideWithValue(
          fakeCacheService ?? _FakeCacheService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AuthSession', () {
    test(
      'build() restores the previously written token from TokenStorage on cold start',
      () async {
        await TokenStorage().write('seed-token');

        final container = buildContainer();

        final token = await container.read(authSessionProvider.future);

        expect(token, 'seed-token');
      },
    );

    test('build() resolves to null when no token was ever written', () async {
      final container = buildContainer();

      final token = await container.read(authSessionProvider.future);

      expect(token, isNull);
    });

    test(
      'signIn() persists the token via TokenStorage and updates state to AsyncData(token)',
      () async {
        final container = buildContainer();
        await container.read(authSessionProvider.future);

        await container
            .read(authSessionProvider.notifier)
            .signIn('new-token');

        expect(container.read(authSessionProvider).value, 'new-token');
        expect(await TokenStorage().read(), 'new-token');
      },
    );

    test(
      'signOut() clears the token, clears the cache via CacheService.clearAll(), '
      'and updates state to AsyncData(null)',
      () async {
        final fakeCacheService = _FakeCacheService();
        final container = buildContainer(fakeCacheService: fakeCacheService);
        await container.read(authSessionProvider.future);
        await container.read(authSessionProvider.notifier).signIn('new-token');

        await container.read(authSessionProvider.notifier).signOut();

        expect(container.read(authSessionProvider).value, isNull);
        expect(await TokenStorage().read(), isNull);
        expect(fakeCacheService.clearAllCallCount, 1);
      },
    );
  });

  test(
    'lib/ contains no ChangeNotifier or ValueNotifier subclass (OFFL-06 regression guard)',
    () {
      final matches = <String>[];
      final libDir = Directory('lib');
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final contents = entity.readAsStringSync();
        if (contents.contains('extends ChangeNotifier') ||
            contents.contains('extends ValueNotifier')) {
          matches.add(entity.path);
        }
      }

      expect(
        matches,
        isEmpty,
        reason:
            'Found ChangeNotifier/ValueNotifier subclass(es) under lib/: $matches. '
            'The Riverpod migration (OFFL-06) requires all state to live in '
            '@riverpod Notifiers instead.',
      );
    },
  );
}
