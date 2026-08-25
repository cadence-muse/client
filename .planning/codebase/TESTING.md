# Testing Patterns

**Analysis Date:** 2026-08-25

## Test Framework

**Runner:**
- `flutter_test` (built-in Flutter testing framework)
- No external test runner (Vitest, Jest, etc.)
- Config: No separate test config file; Flutter defaults are used

**Assertion Library:**
- `flutter_test` provides `expect(actual, matcher)` API
- Common matchers: `findsOneWidget`, `findsWidgets`, `findsNothing`, `isNull`, `isNotNull`, `isEmpty`

**Run Commands:**
```bash
flutter test                           # Run all tests
flutter test test/providers/           # Run tests in specific directory
flutter test test/providers/auth_provider_test.dart  # Run single test file
flutter test --coverage               # Generate coverage report
```

**Coverage Report Location:**
- Generated at: `coverage/lcov.info` (if `--coverage` flag used)
- No coverage requirements enforced in CI yet

## Test File Organization

**Location:**
- Colocated in `test/` directory (mirrors `lib/` structure)
- Example: source at `lib/providers/auth_provider.dart` → test at `test/providers/auth_provider_test.dart`
- Widget tests in `test/features/` (e.g., `test/features/setlists/setlists_screen_test.dart`)
- Provider unit tests in `test/providers/` (e.g., `test/providers/auth_provider_test.dart`)
- API tests in `test/api/` (e.g., `test/api/public_api_test.dart`)
- Cache tests in `test/cache/` (e.g., `test/cache/cache_service_test.dart`)
- Regression tests in `test/regression/` (e.g., `test/regression/offline_trust_regression_test.dart`)

**Naming:**
- File names match source file with `_test.dart` suffix: `auth_provider_test.dart`, `cache_service_test.dart`
- Test names are descriptive sentences explaining what's being tested (not short names like `testLogin()`)

**Directory Structure:**
```
test/
├── api/
│   └── public_api_test.dart
├── cache/
│   └── cache_service_test.dart
├── features/
│   └── setlists/
│       ├── add_setlist_tracks_dialog_test.dart
│       ├── edit_setlist_screen_test.dart
│       ├── setlist_detail_screen_test.dart
│       └── setlists_screen_test.dart
├── providers/
│   ├── auth_provider_test.dart
│   ├── bands_provider_test.dart
│   ├── connectivity_provider_test.dart
│   ├── homepage_provider_test.dart
│   ├── profile_provider_test.dart
│   ├── setlists_provider_test.dart
│   ├── theme_provider_test.dart
│   └── tracks_provider_test.dart
├── regression/
│   └── offline_trust_regression_test.dart
├── widgets/
│   └── offline_banner_test.dart
├── offline_cross_tab_test.dart
└── widget_test.dart
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  setUp(() {
    // Initialize shared test infrastructure (mocks, Hive, temp dirs)
  });

  tearDown(() {
    // Clean up (dispose containers, close Hive, delete temp dirs)
  });

  group('ClassName', () {
    test('specific behavior under condition', () async {
      // Arrange
      final container = buildContainer();
      
      // Act
      await container.read(authSessionProvider.notifier).signIn('token');
      
      // Expect
      expect(container.read(authSessionProvider).value, 'token');
    });

    test('another specific behavior', () async {
      // Arrange, Act, Expect...
    });
  });

  testWidgets('widget behavior under condition', (WidgetTester tester) async {
    // Arrange: set up mocks, FlutterSecureStoragePlatform.instance
    FlutterSecureStoragePlatform.instance = _FakeSecureStorage();
    
    // Act: pump widget, interact
    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.tap(find.text('Button'));
    await tester.pumpAndSettle();
    
    // Expect: verify widgets, state
    expect(find.text('Expected text'), findsOneWidget);
  });
}
```

**Test Grouping:**
- Use `group()` to organize related tests under a class/function name
- Example: `group('AuthSession', () { ... })`
- Unrelated tests placed directly in `main()` or in separate groups

**Patterns:**
- AAA (Arrange-Act-Assert): Set up test doubles → invoke code → verify results
- Descriptive test names as complete sentences (not abbreviated)
- Async tests marked with `async`/`await` where applicable
- Widget tests use `WidgetTester tester` parameter, passed test builder

## Test Structure Examples

**Unit Test (Provider):**
```dart
// From test/providers/auth_provider_test.dart (lines 297-331)
test(
  'build() restores the previously written token from TokenStorage on cold start',
  () async {
    await TokenStorage().write('seed-token');
    
    final container = buildContainer();
    
    final token = await container.read(authSessionProvider.future);
    
    expect(token, 'seed-token');
  },
);
```

**Async Test with Network Mock:**
```dart
// From test/providers/auth_provider_test.dart (lines 352-372)
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
```

**Widget Test:**
```dart
// From test/features/setlists/setlists_screen_test.dart (lines 53-72)
testWidgets(
  'zero bands renders the empty state with no dropdown and no button',
  (tester) async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    expect(find.text('No setlists'), findsOneWidget);
    expect(
      find.text('Create setlists in a band to see them here.'),
      findsOneWidget,
    );
    expect(find.byType(DropdownButton<String?>), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  },
);
```

## Mocking

**Framework:**
- No dedicated mocking library (like Mockito)
- Custom fake implementations using abstract base classes and mixins
- `http/testing.dart` for HTTP request mocking via `MockClient`
- `plugin_platform_interface` for Flutter plugin mocks

**Custom Fakes (Doubles):**
```dart
// From test/widget_test.dart (lines 17-62)
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

  // ... other methods ...
}
```

**Spy Doubles (Records Calls):**
```dart
// From test/providers/auth_provider_test.dart (lines 66-78)
class _FakeCacheService implements CacheService {
  final Map<String, dynamic> _profile = {};
  final Map<String, dynamic> _homepage = {};
  int clearAllCallCount = 0;  // Records how many times clearAll was called
  bool get clearAllCalled => clearAllCallCount > 0;

  @override
  Future<void> clearAll() async {
    clearAllCallCount++;  // Increment spy counter
    _profile.clear();
    _homepage.clear();
    // ... other clears ...
  }
}
```

**HTTP Mocking:**
```dart
// From test/widget_test.dart (lines 84-106)
httpClient: MockClient((request) async {
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
}),
```

**Riverpod Provider Overrides:**
```dart
// From test/providers/auth_provider_test.dart (lines 275-291)
final container = ProviderContainer(
  overrides: [
    cacheServiceProvider.overrideWithValue(
      fakeCacheService ?? _FakeCacheService(),
    ),
    apiClientProvider.overrideWith(
      (ref) => ApiClient(
        baseUrl: 'http://localhost',
        getToken: () => ref.read(authSessionProvider).value,
        onUnauthorized: () =>
            ref.read(authSessionProvider.notifier).signOut(),
        httpClient: MockClient(
          apiHandler ?? (request) async => http.Response('', 200),
        ),
      ),
    ),
  ],
);
addTearDown(container.dispose);  // Clean up after test
```

**What to Mock:**
- Platform-level storage (`FlutterSecureStoragePlatform`)
- HTTP client (`http.Client` via `MockClient`)
- External services (`CacheService` via `_FakeCacheService`)
- Riverpod providers via `.overrideWithValue()` or `.overrideWith()`
- ProviderContainer for unit testing providers in isolation

**What NOT to Mock:**
- Real Riverpod provider implementations (use `.g.dart` generated code)
- Core Dart/Flutter types (String, List, Map, etc.)
- Flutter widgets (use `WidgetTester.pumpWidget()` instead)
- Cache operations when testing cache-dependent behavior (use real Hive with temp dir in setUp/tearDown)

## Fixtures and Test Data

**Test Data:**
- Inline JSON strings encoded at call site: `jsonEncode({'id': 'b1', 'name': 'B.A.T.H.'})`
- No separate fixtures directory
- Mock data constructed dynamically per test to keep tests isolated

**Test Infrastructure:**
- Temporary directories created in `setUp()`: `tempDir = await Directory.systemTemp.createTemp()`
- Cleaned up in `tearDown()`: `await tempDir.delete(recursive: true)`
- Hive initialized per test: `Hive.init(tempDir.path)`
- In-memory cache available for widget tests: `CacheService.inMemory()`

**Helper Builders:**
```dart
// From test/features/setlists/setlists_screen_test.dart (lines 21-30)
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

// From test/features/setlists/setlists_screen_test.dart (lines 38-51)
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
    child: const MaterialApp(home: SetlistsScreen()),
  );
}
```

**ProviderContainer Factory:**
```dart
// From test/providers/auth_provider_test.dart (lines 271-295)
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
          onUnauthorized: () =>
              ref.read(authSessionProvider.notifier).signOut(),
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
```

## Coverage

**Requirements:** None enforced in CI yet

**View Coverage:**
```bash
flutter test --coverage    # Generate coverage/lcov.info
lcov --list coverage/lcov.info  # View per-file coverage summary (if lcov installed)
```

## Test Types

**Unit Tests (test/):**
- Scope: Single provider, service, or utility function
- Framework: `test()` or provider-specific patterns
- Approach: Mock all external dependencies, verify state transitions and method calls
- Example: `test/providers/auth_provider_test.dart` tests AuthSession's signIn/signOut logic in isolation
- Test count: ~40+ unit tests across providers, API, cache

**Integration Tests (test/features/):**
- Scope: Widget + provider interaction + HTTP mocking
- Framework: `testWidgets()`
- Approach: Build real widget tree with mocked HTTP client, simulate user interactions
- Example: `test/features/setlists/setlists_screen_test.dart` tests SetlistsScreen rendering with various band/setlist states
- Test count: ~20+ widget tests across features

**Regression Tests (test/regression/):**
- Scope: Named requirements mapping (e.g., WR-01, D-01, D-03)
- Framework: `testWidgets()` or `test()`
- Approach: Verify specific behavioral requirements from design docs
- Example: `test/regression/offline_trust_regression_test.dart` verifies offline-first caching behavior (D-01/D-03/D-06)
- Approach used to prevent regressions when refactoring core offline logic

**Cross-Tab Tests:**
- Scope: State synchronization across multiple app tabs
- Framework: `testWidgets()`
- Example: `test/offline_cross_tab_test.dart` verifies that cache updates in one tab reflect in another

## Common Patterns

**Async Testing:**
```dart
// Use async/await pattern in tests
test('async operation completes successfully', () async {
  final container = buildContainer();
  
  await container.read(authSessionProvider.notifier).signIn('token');
  
  expect(container.read(authSessionProvider).value, 'token');
});

// Widget tests use WidgetTester which is async-aware
testWidgets('widget test async pattern', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();  // Wait for all animations
  expect(find.text('Done'), findsOneWidget);
});
```

**Error Testing:**
```dart
// From test/providers/auth_provider_test.dart (lines 373-393)
test(
  'signOut() completes local sign-out even when the logout network call '
  'throws (offline/unreachable backend)',
  () async {
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
  },
);
```

**Spy/Assertion on Call Count:**
```dart
// From test/providers/auth_provider_test.dart (lines 335-348)
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
    expect(fakeCacheService.clearAllCallCount, 1);  // Spy assertion
  },
);
```

**Widget Interaction:**
```dart
// From test/widget_test.dart (lines 117-122)
await tester.tap(find.text('Bands'));  // Simulate user tap
await tester.pumpAndSettle();          // Let animations finish

expect(find.text('B.A.T.H.'), findsOneWidget);  // Verify result
```

**Reentrancy/Edge Case Testing:**
```dart
// From test/providers/auth_provider_test.dart (lines 395-414)
test(
  'signOut() completes exactly once (no unbounded recursion) when the '
  'logout call itself gets a 403, which triggers onUnauthorized -> '
  'signOut() from inside the in-flight logout call',
  () async {
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
    expect(fakeCacheService.clearAllCallCount, 1);  // Not 2+ (no recursion)
  },
);
```

**Regression Guard (Codebase-Level Assertion):**
```dart
// From test/providers/auth_provider_test.dart (lines 417-440)
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
```

## Special Test Patterns

**Cache Roundtrip Testing:**
```dart
// From test/cache/cache_service_test.dart (lines 21-28)
test('writeProfile then readProfile roundtrips the same map', () async {
  final cache = CacheService.instance;
  await cache.writeProfile({'id': 'u1', 'username': 'alice'});

  final result = await cache.readProfile();

  expect(result, {'id': 'u1', 'username': 'alice'});
});
```

**Hive Persistence Verification (Forces Disk Read):**
```dart
// From test/cache/cache_service_test.dart (lines 68-99)
test(
  'readBandDetail after a real Hive close+reopen returns fully typed '
  'nested collections (CR-01)',
  () async {
    var cache = CacheService.instance;
    await cache.writeBandDetail('b1', {
      'id': 'b1',
      'name': 'The Testers',
      'ownerId': 'u1',
      'inviteCode': 'ABC123',
      'members': [
        {'id': 'u1', 'username': 'alice'},
        {'id': 'u2', 'username': 'bob'},
      ],
    });

    // Force real disk deserialization by closing and reopening
    await Hive.close();
    Hive.init(tempDir.path);
    await CacheService.initialize();
    cache = CacheService.instance;

    final result = await cache.readBandDetail('b1');

    expect(result, isNotNull);
    final members = (result!['members'] as List)
        .cast<Map<String, dynamic>>();
    expect(members[0]['username'], 'alice');
  },
);
```

---

*Testing analysis: 2026-08-25*
