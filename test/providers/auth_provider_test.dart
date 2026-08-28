import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/token_storage.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Map<String, dynamic> _homepage = {};
  List<Map<String, dynamic>>? _bands;
  final Map<String, Map<String, dynamic>> _bandDetails = {};
  final Map<String, List<Map<String, dynamic>>> _bandTracks = {};
  final Map<String, Map<String, dynamic>> _trackDetails = {};
  final Map<String, List<Map<String, dynamic>>> _userTracks = {};
  final Map<String, List<Map<String, dynamic>>> _bandSetlists = {};
  final Map<String, Map<String, dynamic>> _setlistDetails = {};
  final Map<String, List<Map<String, dynamic>>> _userSetlists = {};
  int clearAllCallCount = 0;
  bool get clearAllCalled => clearAllCallCount > 0;

  @override
  Future<Map<String, dynamic>?> readProfile() async =>
      _profile.isEmpty ? null : Map<String, dynamic>.from(_profile);

  @override
  Future<bool> writeProfile(Map<String, dynamic> data) async {
    _profile
      ..clear()
      ..addAll(data);
    return true;
  }

  @override
  Future<Map<String, dynamic>?> readHomepage() async =>
      _homepage.isEmpty ? null : Map<String, dynamic>.from(_homepage);

  @override
  Future<bool> writeHomepage(Map<String, dynamic> data) async {
    _homepage
      ..clear()
      ..addAll(data);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>?> readBands() async =>
      _bands == null ? null : List<Map<String, dynamic>>.from(_bands!);

  @override
  Future<bool> writeBands(List<Map<String, dynamic>> data) async {
    _bands = List<Map<String, dynamic>>.from(data);
    return true;
  }

  @override
  Future<Map<String, dynamic>?> readBandDetail(String bandId) async =>
      _bandDetails.containsKey(bandId)
      ? Map<String, dynamic>.from(_bandDetails[bandId]!)
      : null;

  @override
  Future<bool> writeBandDetail(String bandId, Map<String, dynamic> data) async {
    _bandDetails[bandId] = Map<String, dynamic>.from(data);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>?> readBandTracks(String bandId) async =>
      _bandTracks.containsKey(bandId)
      ? List<Map<String, dynamic>>.from(_bandTracks[bandId]!)
      : null;

  @override
  Future<bool> writeBandTracks(
    String bandId,
    List<Map<String, dynamic>> data,
  ) async {
    _bandTracks[bandId] = List<Map<String, dynamic>>.from(data);
    return true;
  }

  @override
  Future<Map<String, dynamic>?> readBandTrackDetail(
    String bandId,
    String trackId,
  ) async {
    final key = '${bandId}_$trackId';
    return _trackDetails.containsKey(key)
        ? Map<String, dynamic>.from(_trackDetails[key]!)
        : null;
  }

  @override
  Future<bool> writeBandTrackDetail(
    String bandId,
    String trackId,
    Map<String, dynamic> data,
  ) async {
    _trackDetails['${bandId}_$trackId'] = Map<String, dynamic>.from(data);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>?> readUserTracks(
    String? bandIdFilter,
  ) async {
    final key = bandIdFilter ?? 'all';
    return _userTracks.containsKey(key)
        ? List<Map<String, dynamic>>.from(_userTracks[key]!)
        : null;
  }

  @override
  Future<bool> writeUserTracks(
    String? bandIdFilter,
    List<Map<String, dynamic>> data,
  ) async {
    final key = bandIdFilter ?? 'all';
    _userTracks[key] = List<Map<String, dynamic>>.from(data);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>?> readBandSetlists(String bandId) async =>
      _bandSetlists.containsKey(bandId)
      ? List<Map<String, dynamic>>.from(_bandSetlists[bandId]!)
      : null;

  @override
  Future<bool> writeBandSetlists(
    String bandId,
    List<Map<String, dynamic>> data,
  ) async {
    _bandSetlists[bandId] = List<Map<String, dynamic>>.from(data);
    return true;
  }

  @override
  Future<Map<String, dynamic>?> readSetlistDetail(
    String bandId,
    String setlistId,
  ) async {
    final key = '${bandId}_$setlistId';
    return _setlistDetails.containsKey(key)
        ? Map<String, dynamic>.from(_setlistDetails[key]!)
        : null;
  }

  @override
  Future<bool> writeSetlistDetail(
    String bandId,
    String setlistId,
    Map<String, dynamic> data,
  ) async {
    _setlistDetails['${bandId}_$setlistId'] = Map<String, dynamic>.from(data);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>?> readUserSetlists(
    String? bandIdFilter,
  ) async {
    final key = bandIdFilter ?? 'all';
    return _userSetlists.containsKey(key)
        ? List<Map<String, dynamic>>.from(_userSetlists[key]!)
        : null;
  }

  @override
  Future<bool> writeUserSetlists(
    String? bandIdFilter,
    List<Map<String, dynamic>> data,
  ) async {
    final key = bandIdFilter ?? 'all';
    _userSetlists[key] = List<Map<String, dynamic>>.from(data);
    return true;
  }

  @override
  Future<void> clearAll() async {
    clearAllCallCount++;
    _profile.clear();
    _homepage.clear();
    _bands = null;
    _bandDetails.clear();
    _bandTracks.clear();
    _trackDetails.clear();
    _userTracks.clear();
    _bandSetlists.clear();
    _setlistDetails.clear();
    _userSetlists.clear();
  }
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = _FakeSecureStorage();
  });

  // Defaults to a handler returning `200` with an empty body for any
  // request, so the existing signIn/build tests (which never touch the
  // network) are unaffected. Wires getToken/onUnauthorized to
  // authSessionProvider itself, mirroring the real apiClientProvider in
  // lib/providers/auth_provider.dart, so tests can exercise the logout
  // call's Authorization header and the onUnauthorized -> signOut() path.
  ProviderContainer buildContainer({
    _FakeCacheService? fakeCacheService,
    Future<http.Response> Function(http.Request)? apiHandler,
  }) {
    final container = ProviderContainer(
      overrides: [
        cacheServiceProvider.overrideWithValue(
          fakeCacheService ?? _FakeCacheService(),
        ),
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'http://localhost',
            getToken: () => ref.read(authSessionProvider).value,
            onUnauthorized: () => ref
                .read(authSessionProvider.notifier)
                .signOut(sessionExpired: true),
            httpClient: MockClient(
              apiHandler ?? (request) async => http.Response('', 200),
            ),
          ),
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

        await container.read(authSessionProvider.notifier).signIn('new-token');

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

    test(
      'signOut() sends exactly one POST /api/logout with the Authorization '
      'header set to the still-active token before clearing local state',
      () async {
        http.Request? capturedRequest;
        final container = buildContainer(
          apiHandler: (request) async {
            capturedRequest = request;
            return http.Response('', 200);
          },
        );
        await container.read(authSessionProvider.future);
        await container.read(authSessionProvider.notifier).signIn('new-token');

        await container.read(authSessionProvider.notifier).signOut();

        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.method, 'POST');
        expect(capturedRequest!.url.path, '/api/logout');
        expect(capturedRequest!.headers['Authorization'], 'new-token');
      },
    );

    test('signOut() completes local sign-out even when the logout network call '
        'throws (offline/unreachable backend)', () async {
      final fakeCacheService = _FakeCacheService();
      final container = buildContainer(
        fakeCacheService: fakeCacheService,
        apiHandler: (request) async =>
            throw const SocketException('no network'),
      );
      await container.read(authSessionProvider.future);
      await container.read(authSessionProvider.notifier).signIn('new-token');

      await container.read(authSessionProvider.notifier).signOut();

      expect(container.read(authSessionProvider).value, isNull);
      expect(await TokenStorage().read(), isNull);
      expect(fakeCacheService.clearAllCallCount, 1);
    });

    test('signOut() completes exactly once (no unbounded recursion) when the '
        'logout call itself gets a 403, which triggers onUnauthorized -> '
        'signOut() from inside the in-flight logout call', () async {
      final fakeCacheService = _FakeCacheService();
      final container = buildContainer(
        fakeCacheService: fakeCacheService,
        apiHandler: (request) async => http.Response('', 403),
      );
      await container.read(authSessionProvider.future);
      await container.read(authSessionProvider.notifier).signIn('new-token');

      await container.read(authSessionProvider.notifier).signOut();

      expect(container.read(authSessionProvider).value, isNull);
      expect(await TokenStorage().read(), isNull);
      expect(fakeCacheService.clearAllCallCount, 1);
    });

    test(
      'signOut() does not clear the app_locale SharedPreferences key (D-04)',
      () async {
        SharedPreferences.setMockInitialValues({'app_locale': 'ru'});
        final container = buildContainer();
        await container.read(authSessionProvider.future);
        await container.read(authSessionProvider.notifier).signIn('new-token');

        await container.read(authSessionProvider.notifier).signOut();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_locale'), 'ru');
      },
    );

    test('consumeSessionExpired() returns true exactly once after '
        'signOut(sessionExpired: true), then false on a second call', () async {
      final container = buildContainer();
      await container.read(authSessionProvider.future);
      await container.read(authSessionProvider.notifier).signIn('token');

      await container
          .read(authSessionProvider.notifier)
          .signOut(sessionExpired: true);

      final notifier = container.read(authSessionProvider.notifier);
      expect(notifier.consumeSessionExpired(), isTrue);
      expect(notifier.consumeSessionExpired(), isFalse);
    });

    test('consumeSessionExpired() returns false after a manual signOut() '
        '(default sessionExpired: false)', () async {
      final container = buildContainer();
      await container.read(authSessionProvider.future);
      await container.read(authSessionProvider.notifier).signIn('token');

      await container.read(authSessionProvider.notifier).signOut();

      expect(
        container.read(authSessionProvider.notifier).consumeSessionExpired(),
        isFalse,
      );
    });

    test('signOut(sessionExpired: true) completes exactly once (no unbounded '
        'recursion) when the logout call itself gets a 401, and '
        'consumeSessionExpired() still ends up true', () async {
      final fakeCacheService = _FakeCacheService();
      final container = buildContainer(
        fakeCacheService: fakeCacheService,
        apiHandler: (request) async => http.Response('', 401),
      );
      await container.read(authSessionProvider.future);
      await container.read(authSessionProvider.notifier).signIn('new-token');

      await container
          .read(authSessionProvider.notifier)
          .signOut(sessionExpired: true);

      expect(container.read(authSessionProvider).value, isNull);
      expect(await TokenStorage().read(), isNull);
      expect(fakeCacheService.clearAllCallCount, 1);
      expect(
        container.read(authSessionProvider.notifier).consumeSessionExpired(),
        isTrue,
      );
    });
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
