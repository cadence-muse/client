# Phase 2: Bands - Pattern Map

**Mapped:** 2026-08-15
**Files analyzed:** 8 new/modified files
**Analogs found:** 8 / 8 with strong matches

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/bands/bands_screen.dart` | component | request-response | `lib/features/home/home_screen.dart` | exact |
| `lib/features/bands/band_detail_screen.dart` | component | request-response | `lib/features/profile/profile_screen.dart` | exact |
| `lib/features/bands/create_band_screen.dart` | component | request-response | `lib/features/auth/login_screen.dart` | role-match |
| `lib/features/bands/join_band_dialog.dart` | component | request-response | `lib/features/auth/login_screen.dart` | role-match |
| `lib/features/bands/band_avatar.dart` | component | render | `lib/features/profile/profile_screen.dart` (CircleAvatar pattern) | partial |
| `lib/providers/bands_provider.dart` | provider | CRUD | `lib/providers/homepage_provider.dart` | exact |
| `lib/api/public_api.dart` (modify) | service | CRUD | `lib/api/public_api.dart` (existing register/login) | exact |
| `lib/cache/cache_service.dart` (modify) | service | file-I/O | `lib/cache/cache_service.dart` (existing readProfile/writeProfile) | exact |

## Pattern Assignments

### `lib/features/bands/bands_screen.dart` (component, request-response)

**Analog:** `lib/features/home/home_screen.dart`

**Imports pattern** (lines 1-5):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/homepage_provider.dart';
```

**ConsumerWidget pattern** (lines 7-11):
```dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

**Provider watch pattern with async handling** (lines 12-31):
```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homepageDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(homepageDataProvider.notifier).refresh(),
          ),
        ],
      ),
      body: homeAsync.when(
        data: (data) => _buildContent(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildError(context, () => ref.invalidate(homepageDataProvider)),
      ),
    );
  }
```

**Empty state pattern** (lines 38-66):
```dart
  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final bandsCount = data['bandsCount'] as int;

    if (bandsCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No bands yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create or join a band to get started.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BandsScreen()),
                ),
                child: const Text('Create Band'),
              ),
            ],
          ),
        ),
      );
    }
    // ... normal content
  }
```

**Error state pattern** (lines 95-118):
```dart
  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load home",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
```

---

### `lib/features/bands/band_detail_screen.dart` (component, request-response)

**Analog:** `lib/features/profile/profile_screen.dart`

**Imports pattern** (lines 1-6):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../settings/settings_screen.dart';
```

**ConsumerWidget with provider watch** (lines 8-31):
```dart
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(profileDataProvider.notifier).refresh(),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _buildContent(context, ref, profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildError(context, () => ref.invalidate(profileDataProvider)),
      ),
    );
  }
```

**Content builder with ListView** (lines 35-79):
```dart
  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> profile,
  ) {
    final username = profile['username'] as String? ?? '';
    final id = profile['id'] as String? ?? '';

    return ListView(
      children: [
        const SizedBox(height: 24),
        const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        ListTile(title: const Text('ID'), subtitle: Text(id)),
        // ... actions as ListTiles
      ],
    );
  }
```

---

### `lib/features/bands/create_band_screen.dart` (component, request-response)

**Analog:** `lib/features/auth/login_screen.dart`

**Form-based StatefulWidget pattern** (lines 9-14):
```dart
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}
```

**Form field validation and error handling** (lines 16-80):
```dart
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      final publicApi = ref.read(publicApiProvider);
      // ... API call
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
```

**Form UI with validation** (lines 98-174):
```dart
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter a username'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
```

---

### `lib/features/bands/join_band_dialog.dart` (component, request-response)

**Analog:** Dialog pattern from `lib/features/auth/login_screen.dart` + Form handling

Use same form validation and error handling as `CreateBandScreen`, but present as a dialog instead of full screen. Reference `login_screen.dart` lines 98-174 for form structure, adapt to single text field for invite code.

**Dialog entry pattern:**
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Join Band'),
    content: // ... TextField with validation
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _isSubmitting ? null : _submit,
        child: const Text('Join'),
      ),
    ],
  ),
);
```

---

### `lib/features/bands/band_avatar.dart` (component, render)

**Analog:** CircleAvatar pattern from `lib/features/profile/profile_screen.dart` and `lib/features/bands/bands_screen.dart`

**Avatar widget pattern** (from bands_screen.dart line 24 and profile_screen.dart line 46):
```dart
// Simple circle avatar with text
CircleAvatar(child: Text(band.name[0]))

// Or with icon
const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48))
```

Create a reusable `BandAvatar` widget that:
- Accepts `bandName` (String) as parameter
- Renders first letter of band name in a CircleAvatar
- Uses deterministic color based on band name hash (mentioned in RESEARCH.md as best practice)
- Matches theme colors (light/dark mode)

---

### `lib/providers/bands_provider.dart` (provider, CRUD)

**Analog:** `lib/providers/homepage_provider.dart` and `lib/providers/profile_provider.dart`

**Imports pattern** (homepage_provider.dart lines 1-8):
```dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import '../cache/cache_service.dart';

part 'bands_provider.g.dart';
```

**Cache-first AsyncNotifier pattern for list** (homepage_provider.dart lines 22-77):
```dart
/// Cache-first `GET /api/band/list` data.
@riverpod
class BandsListData extends _$BandsListData {
  Future<void>? _inFlightRefresh;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBands();
    if (cached != null) {
      unawaited(_refresh());
      return cached;
    }
    return _fetchAndCache();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache() async {
    final apiClient = ref.read(apiClientProvider);
    final data = await apiClient.send('GET', '/api/band/list');
    final bands = (data!['items'] as List).cast<Map<String, dynamic>>();
    await ref.read(cacheServiceProvider).writeBands(bands);
    return bands;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _fetchAndCache();
      state = AsyncData(fresh);
    } catch (_) {
      // Keep showing cached data.
    }
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    try {
      final fresh = await _fetchAndCache();
      state = AsyncData(fresh);
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
    }
  }
}
```

**Cache-first AsyncNotifier pattern for per-band detail:**
Same structure as BandsListData, but parameterized by bandId. Copy pattern above and adapt:
- Method names: `readBandDetail(bandId)`, `writeBandDetail(bandId, data)`
- Endpoint: `/api/band/{bandId}` (no `items` wrapper in response)
- Return type: `Map<String, dynamic>` (single band object, not list)

---

### `lib/api/public_api.dart` (modify, service/CRUD)

**Analog:** Existing `lib/api/public_api.dart` (lines 1-39)

**Existing pattern** (lines 1-39):
```dart
import 'api_client.dart';

class PublicApi {
  PublicApi(this._client);

  final ApiClient _client;

  Future<String> register({
    required String username,
    required String password,
  }) async {
    final response = await _client.send(
      'POST',
      '/api/register',
      body: {'username': username, 'password': password},
      requireAuth: false,
    );
    return response!['id'] as String;
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.send(
      'POST',
      '/api/login',
      body: {'username': username, 'password': password},
      requireAuth: false,
    );
    return response!['token'] as String;
  }
}
```

**Add band methods following same pattern:**
- `listBands()` → GET `/api/band/list` → return `List<Map<String, dynamic>>` (extract `items` from response)
- `createBand({required String name})` → POST `/api/band` → return `Map<String, dynamic>` (created band)
- `getBand(String bandId)` → GET `/api/band/{bandId}` → return `Map<String, dynamic>` (full band detail)
- `updateBand({required String bandId, required String name})` → PUT `/api/band/{bandId}` → return `void`
- `deleteBand(String bandId)` → DELETE `/api/band/{bandId}` → return `void`
- `joinBand({required String inviteCode})` → POST `/api/band/join` → return `void` (inviteCode trimmed before send)
- `removeMember({required String bandId, required String userId})` → DELETE `/api/band/{bandId}/remove-member/{userId}` → return `void`

All follow the same wrapping of `_client.send()` pattern.

---

### `lib/cache/cache_service.dart` (modify, service/file-I/O)

**Analog:** Existing `lib/cache/cache_service.dart` (lines 60-127)

**Existing pattern for read/write** (lines 92-127):
```dart
  static const _profileKey = 'profile';
  static const _homepageKey = 'homepage';

  Future<Map<String, dynamic>?> readProfile() async {
    try {
      return _profileStore.get(_profileKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeProfile(Map<String, dynamic> data) async {
    try {
      await _profileStore.put(_profileKey, data);
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }

  Future<Map<String, dynamic>?> readHomepage() async {
    try {
      return _homepageStore.get(_homepageKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeHomepage(Map<String, dynamic> data) async {
    try {
      await _homepageStore.put(_homepageKey, data);
    } catch (_) {
      // Non-critical cache write failure; swallow and keep serving the
      // in-memory/network data instead.
    }
  }
```

**Add bands methods following same pattern:**

In constructor and `initialize()`:
- Add `_bandsStore` (new Hive box `bandsBox`)
- Keep single box for both list and per-band detail (using keys `'bands'` for list, `'band_{bandId}'` for detail)

New methods:
```dart
  static const _bandsListKey = 'bands';
  
  Future<List<Map<String, dynamic>>?> readBands() async {
    try {
      final raw = _bandsStore.get(_bandsListKey);
      if (raw == null) return null;
      final items = raw['items'] as List?;
      if (items == null) return null;
      return items.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBands(List<Map<String, dynamic>> data) async {
    try {
      await _bandsStore.put(_bandsListKey, {'items': data});
    } catch (_) {
      // Non-critical cache write failure; swallow
    }
  }

  Future<Map<String, dynamic>?> readBandDetail(String bandId) async {
    try {
      return _bandsStore.get('band_$bandId');
    } catch (_) {
      return null;
    }
  }

  Future<void> writeBandDetail(String bandId, Map<String, dynamic> data) async {
    try {
      await _bandsStore.put('band_$bandId', data);
    } catch (_) {
      // Non-critical cache write failure; swallow
    }
  }
```

Update `clearAll()` (line 129-132) to include `_bandsStore.clear()`.

---

## Shared Patterns

### Error Handling (All screens and services)

**Source:** `lib/api/api_exception.dart` (lines 5-32) and `lib/features/auth/login_screen.dart` (lines 75-76)

**ApiException contract:**
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
        // Response body isn't the expected JSON error shape; fall through.
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

**Apply to:** All mutation actions in band screens (create, join, update, delete, leave, remove member)

**Catch pattern:**
```dart
  try {
    // ... API call
  } on ApiException catch (e) {
    setState(() => _errorMessage = e.message);
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
```

---

### Provider Declaration Pattern (All new providers)

**Source:** `lib/providers/auth_provider.dart` (lines 11-23)

**Pattern for new providers:**
```dart
@riverpod
CacheService cacheService(CacheServiceRef ref) => CacheService.instance;

@riverpod
ApiClient apiClient(ApiClientRef ref) => ApiClient(
  baseUrl: AppConfig.apiBaseUrl,
  getToken: () => ref.read(authSessionProvider).value,
  onUnauthorized: () => ref.read(authSessionProvider.notifier).signOut(),
);

@riverpod
PublicApi publicApi(PublicApiRef ref) =>
    PublicApi(ref.watch(apiClientProvider));
```

**Apply to:** Register `BandsListData` and `BandDetailData` providers (auto-generated via codegen, part of `bands_provider.dart`).

---

### Async Value Handling Pattern (.when())

**Source:** `lib/features/home/home_screen.dart` (lines 25-31) and `lib/features/profile/profile_screen.dart` (lines 26-31)

**Pattern:**
```dart
  final dataAsync = ref.watch(someProvider);

  return Scaffold(
    body: dataAsync.when(
      data: (data) => _buildContent(context, data),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          _buildError(context, () => ref.invalidate(someProvider)),
    ),
  );
```

**Apply to:** All screens watching async providers (bands list, band detail)

---

### Navigation After Mutation

**Source:** `lib/features/auth/login_screen.dart` (lines 59-74)

**Pattern for successful mutation:**
```dart
  try {
    final token = await publicApi.login(username: username, password: password);
    await ref.read(authSessionProvider.notifier).signIn(token);
    // Navigation happens implicitly via AuthGate watching authSessionProvider
  } on ApiException catch (e) {
    setState(() => _errorMessage = e.message);
  }
```

**Apply to:** After successful create/join, use `Navigator.push()` to detail screen; after delete/leave, use `Navigator.pop()` back to list.

---

## No Analog Found

All files have strong analogs in Phase 1 codebase. No pattern gaps identified.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | — |

---

## Metadata

**Analog search scope:** `lib/features/`, `lib/providers/`, `lib/api/`, `lib/cache/`
**Files scanned:** 8 core Phase 1 files (screens, providers, API layer, cache service)
**Pattern extraction date:** 2026-08-15
**Confidence:** HIGH — All Phase 2 patterns mirror or extend Phase 1 established patterns

**Key insights:**
1. **Cache-first pattern:** `HomepageData` and `ProfileData` are the templates for `BandsListData` and per-band detail providers
2. **Screen structure:** Use ConsumerWidget with `.when()` for async data, separate `_buildContent()` and `_buildError()` methods
3. **Form handling:** LoginScreen's validation + error display pattern applies directly to CreateBandScreen and JoinBandDialog
4. **API wrapping:** PublicApi's simple `send()` wrapper pattern extends seamlessly to new band endpoints
5. **Cache service:** Per-endpoint boxes with read/write error swallowing is proven; just add `bandsBox` (or key-based within existing box)

---

*Phase: 2-Bands*
*Patterns mapped: 2026-08-15*
*Ready for planning*
