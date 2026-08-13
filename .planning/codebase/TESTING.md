# Testing Patterns

**Analysis Date:** 2026-08-13

## Test Framework

**Runner:**
- `flutter_test` (included with Flutter SDK)
- Config: `pubspec.yaml` lists `flutter_test` under `dev_dependencies`

**Assertion Library:**
- Built-in Flutter test assertions (`expect`, `findsOneWidget`, `findsWidgets`, etc.)
- Uses Matcher pattern for flexible assertions

**Run Commands:**
```bash
flutter test                              # Run all tests
flutter test test/widget_test.dart        # Run a single test file
flutter test --plain-name "test name"     # Run a single test by name
```

## Test File Organization

**Location:**
- Widget/integration tests co-located in `test/` directory
- Mirror structure to `lib/` (current: only `test/widget_test.dart`)

**Naming:**
- Test files end with `_test.dart`: `widget_test.dart`
- Test functions use descriptive names: `'bottom navigation switches between tabs'`

**Structure:**
```
cadence-client/
├── lib/
│   ├── api/
│   ├── features/
│   └── ...
└── test/
    └── widget_test.dart         # Widget and integration tests
```

## Test Structure

**Suite Organization:**
```dart
void main() {
  testWidgets('bottom navigation switches between tabs', (WidgetTester tester) async {
    // Setup
    FlutterSecureStoragePlatform.instance = _FakeSecureStorage();

    final authSession = AuthSession(tokenStorage: TokenStorage());
    final apiClient = ApiClient(baseUrl: 'http://localhost', authSession: authSession);
    await authSession.signIn('test-token');

    // Pump widget into test harness
    await tester.pumpWidget(
      CadenceApp(
        themeController: ThemeController(),
        authSession: authSession,
        publicApi: PublicApi(apiClient),
      ),
    );
    await tester.pumpAndSettle();

    // Assertions and interactions
    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Bands'));
    await tester.pumpAndSettle();

    expect(find.text('The Night Owls'), findsOneWidget);
  });
}
```

**Patterns:**
- Setup phase: Instantiate mocks, prepare dependencies, inject into widget tree
- Pump phase: `tester.pumpWidget()` renders the widget, `tester.pumpAndSettle()` waits for animations
- Interaction phase: `tester.tap()`, `tester.enterText()` simulate user actions
- Assertion phase: `expect(find.xxx, ...)` verify expected results

## Mocking

**Framework:** 
- No external mocking library used
- Mocks implemented as fake/stub classes extending platform interfaces
- Uses `plugin_platform_interface` for mock registration

**Patterns:**
Platform interface mocking with `MockPlatformInterfaceMixin`:
```dart
class _FakeSecureStorage extends FlutterSecureStoragePlatform with MockPlatformInterfaceMixin {
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
  Future<String?> read({required String key, required Map<String, String> options}) async =>
      _values[key];

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _values.remove(key);
  }

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      _values.containsKey(key);

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async =>
      Map.of(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async => _values.clear();
}
```

**What to Mock:**
- Platform-level dependencies: `FlutterSecureStorage`, HTTP clients
- External services that are not under test
- Use `FlutterSecureStoragePlatform.instance = mockInstance` to inject

**What NOT to Mock:**
- Flutter framework components (Widget, State, Scaffold, etc.)
- Business logic classes under test (AuthSession, ApiClient business methods)
- Let integration tests use real instances to validate full flows

## Fixtures and Factories

**Test Data:**
No fixtures or factory pattern currently used in `test/widget_test.dart`.

**Current Approach:**
- Hardcoded test data in test function: `'test-token'` for auth, `'The Night Owls'` for band name
- Objects constructed inline: `AuthSession(tokenStorage: TokenStorage())`, `ApiClient(baseUrl: 'http://localhost', authSession: authSession)`

**Location:**
- If factories needed: add to `test/fixtures/` or `test/factories/` directory

## Coverage

**Requirements:** No coverage enforced currently

**View Coverage:**
Currently not set up. To enable:
```bash
flutter test --coverage                   # Generate coverage report
```

Creates `coverage/lcov.info` with coverage data.

## Test Types

**Widget Tests:**
- Location: `test/widget_test.dart`
- Scope: Test UI interactions and navigation (e.g., bottom navigation switching)
- Approach: Use `WidgetTester` to pump widgets, tap buttons, find elements, and verify results
- Example: `testWidgets('bottom navigation switches between tabs', ...)`

**Integration Tests:**
- Location: Would be in `integration_test/` directory (not currently present)
- Scope: Test full user flows across multiple screens
- Not currently used in this project

**Unit Tests:**
- Location: Not currently present
- Scope: Test individual functions, classes, and business logic in isolation
- Could be added alongside widget tests or in separate `test/unit/` subdirectory
- Example needed: Tests for `ApiException.fromResponse()`, `AuthSession.restore()`, `TokenStorage` methods

## Common Patterns

**Async Testing:**
```dart
testWidgets('description', (WidgetTester tester) async {
  // All test functions are async
  await tester.pumpWidget(...);           // Wait for widget render
  await tester.pumpAndSettle();           // Wait for animations to settle
  await authSession.signIn('token');      // Wait for async operations
});
```

**Widget Finders:**
```dart
find.text('Home')                  # Find by text content
find.text('Home'), findsWidgets    # Multiple matches expected
find.text('The Night Owls'), findsOneWidget  # Exactly one match expected
find.byIcon(Icons.home)            # Find by icon
find.byType(FloatingActionButton)  # Find by widget type
```

**Interactions:**
```dart
await tester.tap(find.text('Bands'));     # Tap a widget
await tester.enterText(find.byType(TextField), 'text');  # Enter text
await tester.pumpAndSettle();              # Wait for animations
```

**Error Testing:**
Patterns not yet established. When adding error tests:
- Mock API to return specific error responses
- Verify error messages displayed to user
- Test retry logic if implemented

---

*Testing analysis: 2026-08-13*
