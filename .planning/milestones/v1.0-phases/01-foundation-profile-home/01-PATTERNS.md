# Phase 1: Foundation, Profile & Home - Pattern Map

**Mapped:** 2026-08-15
**Files analyzed:** 14 (new/modified)
**Analogs found:** 12 / 14 (exact + role match)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/providers/auth_provider.dart` | service/provider | request-response | `lib/api/auth_session.dart` | exact (migrate ChangeNotifier → Riverpod Notifier) |
| `lib/providers/profile_provider.dart` | service/provider | CRUD + streaming | N/A (codegen pattern from RESEARCH.md) | reference |
| `lib/providers/homepage_provider.dart` | service/provider | CRUD + streaming | N/A (codegen pattern from RESEARCH.md) | reference |
| `lib/providers/theme_provider.dart` | service/provider | request-response | `lib/theme/theme_controller.dart` | exact (migrate ValueNotifier → Riverpod) |
| `lib/cache/cache_service.dart` | utility | file-I/O | N/A (new Hive setup) | reference |
| `lib/features/profile/profile_screen.dart` | component | request-response | `lib/features/profile/profile_screen.dart` (current) | exact (convert to ConsumerWidget) |
| `lib/features/home/home_screen.dart` | component | request-response | `lib/features/home/home_screen.dart` (current) | exact (convert to ConsumerWidget) |
| `lib/features/auth/auth_gate.dart` | component | request-response | `lib/features/auth/auth_gate.dart` (current) | exact (convert to ConsumerWidget) |
| `lib/app.dart` | component/root | configuration | `lib/app.dart` (current) | exact (use Riverpod providers) |
| `lib/main.dart` | config | initialization | `lib/main.dart` (current) | exact (wrap with ProviderScope) |
| `pubspec.yaml` | config | configuration | `pubspec.yaml` (current) | exact (add dependencies) |
| `test/providers/auth_provider_test.dart` | test | unit | `test/widget_test.dart` (mocking pattern) | partial |
| `test/providers/profile_provider_test.dart` | test | unit | `test/widget_test.dart` (ProviderContainer pattern) | partial |
| `test/features/profile/profile_screen_test.dart` | test | widget | `test/widget_test.dart` (widget test pattern) | partial |

## Pattern Assignments

### `lib/providers/auth_provider.dart` (service/provider, request-response)

**Analog:** `lib/api/auth_session.dart`

**State enum pattern** (lines 5-5):
```dart
enum AuthStatus { unknown, authenticated, unauthenticated }
```

**ChangeNotifier state pattern** (lines 12-21 from auth_session.dart, now migrates to Riverpod Notifier):
```dart
class AuthSession extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _token;

  AuthStatus get status => _status;
  String? get token => _token;
```

**AuthSession restore/signIn/signOut methods** (lines 24-43 from auth_session.dart, ported to Riverpod):
```dart
Future<void> restore() async {
  _token = await tokenStorage.read();
  _status = _token == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
  notifyListeners();
}

Future<void> signIn(String token) async {
  _token = token;
  _status = AuthStatus.authenticated;
  await tokenStorage.write(token);
  notifyListeners();
}

Future<void> signOut() async {
  if (_status == AuthStatus.unauthenticated) return;
  _token = null;
  _status = AuthStatus.unauthenticated;
  await tokenStorage.delete();
  notifyListeners();
}
```

**Riverpod migration pattern** (from RESEARCH.md Pattern 2):
- Replace `ChangeNotifier` with `@riverpod` class extending `_$AuthSession`
- Replace `notifyListeners()` with `state = AsyncData(value)`
- Use `@override Future<String?> build()` for initialization
- Use `ref.watch(tokenStorageProvider)` instead of constructor injection
- Use `riverpod_generator` codegen (`part 'auth_provider.g.dart'`)

**Error handling pattern** (from api_client.dart lines 52-54):
```dart
if (response.statusCode == 403) {
  await authSession.signOut();
  throw ApiException.fromResponse(response);
}
```

---

### `lib/providers/profile_provider.dart` (service/provider, CRUD + streaming)

**Pattern source:** RESEARCH.md Pattern 1 (AsyncNotifier cache-first loading)

**Riverpod AsyncNotifier structure** (codegen):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'profile_provider.g.dart';

@riverpod
class ProfileData extends _$ProfileData {
  @override
  Future<Map<String, dynamic>> build() async {
    // Cache-first: try reading from Hive cache
    final cached = await CacheService.instance.readProfile();
    if (cached != null) {
      _refreshInBackground();
      return cached;
    }
    // No cache; fetch from network
    return _fetchProfile();
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _fetchProfile();
      state = AsyncData(fresh);
    } catch (e) {
      // Log error; keep cached data
    }
  }

  Future<Map<String, dynamic>> _fetchProfile() async {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.send('GET', '/api/me', requireAuth: true);
    if (response != null) {
      await CacheService.instance.writeProfile(response);
      return response;
    }
    throw ApiException(statusCode: 500, message: 'Empty response');
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchProfile);
  }
}
```

**API call pattern** (from api_client.dart lines 32-62):
```dart
Future<Map<String, dynamic>?> send(
  String method,
  String path, {
  Map<String, dynamic>? body,
  bool requireAuth = true,
}) async {
  final uri = Uri.parse('$baseUrl$path');
  final headers = {'Content-Type': 'application/json'};
  
  // ... token injection, request sending ...
  
  if (response.statusCode == 403) {
    await authSession.signOut();
    throw ApiException.fromResponse(response);
  }
  if (response.statusCode >= 400) {
    throw ApiException.fromResponse(response);
  }
  
  if (response.body.isEmpty) return null;
  return jsonDecode(response.body) as Map<String, dynamic>;
}
```

**Error handling pattern** (from api_exception.dart lines 8-24):
```dart
factory ApiException.fromResponse(http.Response response) {
  if (response.body.isNotEmpty) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return ApiException(
          statusCode: response.statusCode,
          code: body['code'] as String?,
          message: (body['message'] as String?) ?? 'Request failed',
        );
      }
    } catch (_) {
      // Response body isn't the expected JSON error shape
    }
  }
  return ApiException(statusCode: response.statusCode, message: 'Request failed');
}
```

---

### `lib/providers/homepage_provider.dart` (service/provider, CRUD + streaming)

**Analog:** Identical structure to `profile_provider.dart`

**Riverpod AsyncNotifier structure** (codegen):
```dart
@riverpod
class HomepageData extends _$HomepageData {
  @override
  Future<Map<String, dynamic>> build() async {
    // Cache-first
    final cached = await CacheService.instance.readHomepage();
    if (cached != null) {
      _refreshInBackground();
      return cached;
    }
    return _fetchHomepage();
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _fetchHomepage();
      state = AsyncData(fresh);
    } catch (e) {
      // Log error; keep cached data
    }
  }

  Future<Map<String, dynamic>> _fetchHomepage() async {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.send('GET', '/api/homepage', requireAuth: true);
    if (response != null) {
      await CacheService.instance.writeHomepage(response);
      return response;
    }
    throw ApiException(statusCode: 500, message: 'Empty response');
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchHomepage);
  }
}
```

---

### `lib/providers/theme_provider.dart` (service/provider, request-response)

**Analog:** `lib/theme/theme_controller.dart`

**ValueNotifier current pattern** (lines 1-7):
```dart
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  void setThemeMode(ThemeMode mode) => value = mode;
}
```

**Riverpod migration pattern** (from RESEARCH.md Pattern 2):
```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';

part 'theme_provider.g.dart';

@riverpod
class ThemeController extends _$ThemeController {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}
```

**Key difference from ChangeNotifier:**
- Replace `ValueNotifier<T>` with `@riverpod class ThemeController extends _$ThemeController`
- Replace `value = X` assignments with `state = X`
- No manual `notifyListeners()` — Riverpod automatically rebuilds watchers
- Use `ref.watch(themeProvider)` in widgets instead of `ListenableBuilder(listenable: themeController)`

---

### `lib/cache/cache_service.dart` (utility, file-I/O)

**Pattern source:** RESEARCH.md Example 4 (Hive initialization)

**Hive initialization structure**:
```dart
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static late final CacheService _instance;
  late final Box<Map<String, dynamic>> _profileBox;
  late final Box<Map<String, dynamic>> _homepageBox;

  static Future<void> initialize() async {
    await Hive.initFlutter();
    _instance = CacheService._();
    _instance._profileBox = await Hive.openBox<Map<String, dynamic>>('profileBox');
    _instance._homepageBox = await Hive.openBox<Map<String, dynamic>>('homepageBox');
  }

  static CacheService get instance => _instance;

  CacheService._();

  Future<Map<String, dynamic>?> readProfile() async {
    try {
      return _profileBox.get('profile');
    } catch (e) {
      return null;
    }
  }

  Future<void> writeProfile(Map<String, dynamic> data) async {
    try {
      await _profileBox.put('profile', data);
    } catch (e) {
      // Log error; non-critical cache write
    }
  }

  Future<Map<String, dynamic>?> readHomepage() async {
    try {
      return _homepageBox.get('homepage');
    } catch (e) {
      return null;
    }
  }

  Future<void> writeHomepage(Map<String, dynamic> data) async {
    try {
      await _homepageBox.put('homepage', data);
    } catch (e) {
      // Log error
    }
  }

  Future<void> clearAll() async {
    await _profileBox.clear();
    await _homepageBox.clear();
  }
}
```

**Error handling pattern**:
- All Hive I/O wrapped in try-catch
- Cache miss returns `null` (not throw)
- Cache write errors silently logged (non-critical)
- App falls back to network fetch on cache read failure

---

### `lib/features/profile/profile_screen.dart` (component, request-response)

**Analog:** Current `lib/features/profile/profile_screen.dart` + LoginScreen error handling pattern

**Current pattern** (lines 7-55):
```dart
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.themeController, required this.authSession});

  final ThemeController themeController;
  final AuthSession authSession;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(...),
    );
  }
}
```

**Migration to ConsumerWidget** (from RESEARCH.md Pattern 3):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);
    final authNotifier = ref.read(authSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(profileDataProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _buildProfileContent(context, profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(
          context,
          error,
          () => ref.invalidate(profileDataProvider),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, Map<String, dynamic> profile) {
    final username = profile['username'] as String? ?? 'Unknown';
    final id = profile['id'] as String? ?? '';
    
    return ListView(...);
  }

  Widget _buildErrorState(BuildContext context, Object error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Couldn\'t load profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Please check your connection and try again.'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
```

**AsyncValue.when pattern** (from RESEARCH.md Pattern 3):
- `data`: widget rebuilds with deserialized data
- `loading`: show CircularProgressIndicator
- `error`: show error message + retry button via `ref.invalidate(provider)`

**Error handling from LoginScreen** (lines 71-76):
```dart
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```

---

### `lib/features/home/home_screen.dart` (component, request-response)

**Analog:** Current `lib/features/home/home_screen.dart`

**Current pattern** (lines 1-13):
```dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Home')),
    );
  }
}
```

**Migration to ConsumerWidget** (identical structure to ProfileScreen):
```dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homepageAsync = ref.watch(homepageDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: homepageAsync.when(
        data: (data) => _buildContent(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, st) => _buildErrorState(context, () => ref.invalidate(homepageDataProvider)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final username = data['username'] as String? ?? 'Unknown';
    final bandsCount = data['bandsCount'] as int? ?? 0;
    
    return ListView(...);
  }

  Widget _buildErrorState(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [...],
      ),
    );
  }
}
```

---

### `lib/features/auth/auth_gate.dart` (component, request-response)

**Analog:** Current `lib/features/auth/auth_gate.dart`

**Current pattern** (lines 11-50):
```dart
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authSession,
    required this.publicApi,
    required this.builder,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.authSession.restore();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authSession,
      builder: (context, _) {
        switch (widget.authSession.status) {
          case AuthStatus.unknown:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.unauthenticated:
            return LoginScreen(publicApi: widget.publicApi);
          case AuthStatus.authenticated:
            return widget.builder(context);
        }
      },
    );
  }
}
```

**Migration to ConsumerWidget** (idiomatic Riverpod pattern):
```dart
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AuthSession.build() triggers restore() automatically via AsyncNotifier
    final authAsync = ref.watch(authSessionProvider);

    return authAsync.when(
      data: (token) {
        if (token == null) {
          return LoginScreen();
        } else {
          return builder(context);
        }
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, st) => Scaffold(
        body: Center(child: Text('Auth error: $error')),
      ),
    );
  }
}
```

**Key changes from ListenableBuilder pattern:**
- No StatefulWidget + initState call
- `ref.watch(authSessionProvider)` returns `AsyncValue<String?>` (token or null)
- `.when()` covers loading/error/data states
- Automatic rebuild on token change

---

### `lib/app.dart` (component/root, configuration)

**Analog:** Current `lib/app.dart`

**Current pattern** (lines 10-45):
```dart
class CadenceApp extends StatelessWidget {
  const CadenceApp({
    super.key,
    required this.themeController,
    required this.authSession,
    required this.publicApi,
  });

  final ThemeController themeController;
  final AuthSession authSession;
  final PublicApi publicApi;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Cadence',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.value,
          home: AuthGate(
            authSession: authSession,
            publicApi: publicApi,
            builder: (context) => RootScaffold(
              themeController: themeController,
              authSession: authSession,
            ),
          ),
        );
      },
    );
  }
}
```

**Migration to ConsumerWidget**:
```dart
class CadenceApp extends ConsumerWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme mode from provider
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Cadence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: AuthGate(
        builder: (context) => const RootScaffold(),
      ),
    );
  }
}
```

**Key changes:**
- Remove constructor parameters (all injected via Riverpod)
- Use `ref.watch(themeProvider)` for theme mode
- `AuthGate` no longer takes `authSession`/`publicApi` (injected via providers)
- `RootScaffold` no longer takes `themeController`/`authSession` (access via Riverpod)

---

### `lib/main.dart` (config, initialization)

**Analog:** Current `lib/main.dart`

**Current pattern** (lines 11-23):
```dart
void main() {
  final authSession = AuthSession(tokenStorage: TokenStorage());
  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl, authSession: authSession);
  final publicApi = PublicApi(apiClient);

  runApp(
    CadenceApp(
      themeController: ThemeController(),
      authSession: authSession,
      publicApi: publicApi,
    ),
  );
}
```

**Migration to ProviderScope** (from RESEARCH.md Example 4):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cache/cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive boxes BEFORE runApp
  await CacheService.initialize();
  
  runApp(
    const ProviderScope(
      child: CadenceApp(),
    ),
  );
}
```

**Key changes:**
- `WidgetsFlutterBinding.ensureInitialized()` before async operations
- `await CacheService.initialize()` to open Hive boxes
- `ProviderScope` wraps entire app (root of Riverpod dependency tree)
- No manual dependency construction (all injected via providers)

---

### `pubspec.yaml` (config, configuration)

**Analog:** Current `pubspec.yaml`

**Current dependencies** (lines 10-15):
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.6.0
  flutter_secure_storage: ^11.0.0
```

**Additions for Phase 1**:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.6.0
  flutter_secure_storage: ^11.0.0
  flutter_riverpod: ^3.4.2        # NEW: State management
  riverpod_annotation: ^2.3.5     # NEW: @riverpod decorator
  hive: ^2.2.3                    # NEW: Local cache
  hive_flutter: ^1.1.0            # NEW: Hive platform integration

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_secure_storage_platform_interface: ^2.0.3
  plugin_platform_interface: ^2.1.8
  riverpod_generator: ^2.4.0      # NEW: Codegen for @riverpod
  build_runner: ^2.4.11           # NEW: Dart build system
```

---

## Shared Patterns

### Error Handling (ApiException)

**Source:** `lib/api/api_exception.dart` (lines 5-32)

**Apply to:** All provider data fetch methods + ProfileScreen/HomeScreen error states

```dart
class ApiException implements Exception {
  ApiException({required this.statusCode, this.code, required this.message});

  factory ApiException.fromResponse(http.Response response) {
    if (response.body.isNotEmpty) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return ApiException(
            statusCode: response.statusCode,
            code: body['code'] as String?,
            message: (body['message'] as String?) ?? 'Request failed',
          );
        }
      } catch (_) {
        // Response body isn't the expected JSON error shape
      }
    }
    return ApiException(statusCode: response.statusCode, message: 'Request failed');
  }

  final int statusCode;
  final String? code;
  final String message;

  @override
  String toString() => message;
}
```

**Usage in providers:**
```dart
try {
  final response = await apiClient.send('GET', '/api/me', requireAuth: true);
  return response;
} catch (e) {
  rethrow;  // Let AsyncNotifier state machine handle it
}
```

**Usage in screens:**
```dart
error: (error, stackTrace) => _buildErrorState(
  context,
  error,
  () => ref.invalidate(profileDataProvider),
),
```

### API Client Token Injection

**Source:** `lib/api/api_client.dart` (lines 24-62)

**Apply to:** All network calls via `ApiClient.send()`

```dart
class ApiClient {
  ApiClient({required this.baseUrl, required this.authSession, http.Client? httpClient})
    : _httpClient = httpClient ?? createHttpClient();

  final String baseUrl;
  final AuthSession authSession;
  final http.Client _httpClient;

  Future<Map<String, dynamic>?> send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {'Content-Type': 'application/json'};

    final token = authSession.token;
    if (requireAuth && token != null && !kIsWeb) {
      headers['Cookie'] = 'cadencesession=$token';
    }

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 403) {
      await authSession.signOut();
      throw ApiException.fromResponse(response);
    }
    if (response.statusCode >= 400) {
      throw ApiException.fromResponse(response);
    }

    if (response.body.isEmpty) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
```

**Note:** Token source changes from `authSession.token` (in old code) to `ref.watch(apiClientProvider)` (in Riverpod), but the injection mechanism stays identical.

### Imports Organization Pattern

**Source:** Existing project files

**Apply to:** All new provider files

```dart
// Step 1: Dart/Flutter core imports
import 'dart:convert';
import 'package:flutter/material.dart';

// Step 2: Riverpod + codegen
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'profile_provider.g.dart';  // MUST be present for codegen

// Step 3: Local API layer imports
import '../api/api_client.dart';
import '../api/api_exception.dart';

// Step 4: Local cache/service imports
import '../cache/cache_service.dart';
```

### Hive Box Error Handling

**Source:** RESEARCH.md Example 4

**Apply to:** All cache read/write operations in CacheService

```dart
Future<Map<String, dynamic>?> readProfile() async {
  try {
    return _profileBox.get('profile');
  } catch (e) {
    // Log error; return null (cache miss treated same as no data)
    return null;
  }
}

Future<void> writeProfile(Map<String, dynamic> data) async {
  try {
    await _profileBox.put('profile', data);
  } catch (e) {
    // Log error; don't throw (non-critical cache write)
    // App continues with network-only data
  }
}
```

### ref.watch vs ref.read Pattern

**Source:** RESEARCH.md Pattern 3 + Anti-Patterns

**Apply to:** All ConsumerWidget builds and provider methods

```dart
// DO: Use ref.watch() inside build() — subscribes to changes
@override
Widget build(BuildContext context, WidgetRef ref) {
  final profileAsync = ref.watch(profileDataProvider);
  return profileAsync.when(...);  // Rebuilds when provider changes
}

// DON'T: Use ref.read() inside build() — no subscription
@override
Widget build(BuildContext context, WidgetRef ref) {
  final profile = ref.read(profileDataProvider);  // BUG: won't update
  return Text('${profile}');  // Stale data
}

// DO: Use ref.read() in callbacks and other provider methods
ElevatedButton(
  onPressed: () {
    ref.read(profileDataProvider.notifier).refresh();  // OK in callback
  },
  child: Text('Refresh'),
)
```

### Test Mocking Pattern (TokenStorage)

**Source:** `test/widget_test.dart` (lines 11-46)

**Apply to:** All provider tests needing fake TokenStorage/SecureStorage

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
}

void main() {
  test('AuthSession restores token', () async {
    FlutterSecureStoragePlatform.instance = _FakeSecureStorage();
    final authSession = AuthSession(tokenStorage: TokenStorage());
    await authSession.signIn('test-token');
    
    expect(authSession.token, 'test-token');
  });
}
```

---

## No Analog Found

Files using purely new patterns (codegen-based, Hive-specific) with no direct analog:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/providers/profile_provider.dart` | service/provider | CRUD + streaming | AsyncNotifier cache-first pattern new to codebase; reference RESEARCH.md Pattern 1 + Example 2 |
| `lib/providers/homepage_provider.dart` | service/provider | CRUD + streaming | AsyncNotifier cache-first pattern new to codebase; reference RESEARCH.md Pattern 1 + Example 2 |
| `lib/cache/cache_service.dart` | utility | file-I/O | Hive-backed local cache new to codebase; reference RESEARCH.md Example 4 |

All other files have direct analogs (existing code being migrated) or use shared patterns already established.

---

## Metadata

**Analog search scope:** `/lib/api/`, `/lib/features/`, `/lib/theme/`, `/lib/config/`, `/lib/navigation/`, `/test/`
**Files scanned:** 20 core files
**Pattern extraction date:** 2026-08-15
**Classification timestamp:** Phase 1 Ready for Planning

---

*Pattern mapping for Phase 1 — Foundation, Profile & Home*
*Generated: 2026-08-15*
*Framework: Flutter 3.12+ / Dart 3.12+ on Android/iOS*
