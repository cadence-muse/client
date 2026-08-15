# Phase 1: Foundation, Profile & Home - Research

**Researched:** 2026-08-15
**Domain:** Riverpod state management migration + Hive local caching + profile/homepage data layers
**Confidence:** HIGH (decisions locked in CONTEXT.md; tech stack verified against official sources)

## Summary

Phase 1 migrates the app from constructor-injected `ChangeNotifier` patterns to Riverpod 3.x state management and establishes a Hive-backed local cache layer. Both AuthSession and ThemeController move to Riverpod, and the two screens (Profile, Home) prove the cache-first loading strategy end-to-end using Hive boxes that store raw JSON responses. The phase is scoped tightly: no staleness indicators, no offline mutation queue, no new screens beyond Profile/Home.

The decision to use Riverpod codegen (with `riverpod_generator` + `@riverpod` annotations) is a deliberate, scoped exception that introduces build_runner to this codebase for the first time. Every provider written this way depends on generated code, making it a locked choice.

**Primary recommendation:** Follow CONTEXT.md's decisions (D-01 through D-10) exactly. Riverpod 3.x AsyncNotifier + codegen for auth/theme/data providers; Hive 2.2.3 for one box per endpoint; Riverpod `keepAlive` for cache providers; ref.watch inside build, ref.read in callbacks.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Auth state (login/logout/restore) | API / Backend | Browser / Client | AuthSession moves to Riverpod, but token persistence stays with TokenStorage (flutter_secure_storage) |
| Theme state (light/dark toggle) | Browser / Client | — | ThemeController migrates to Riverpod ValueNotifier, watches in build method only |
| Profile data fetch | API / Backend | Database / Storage | GET /api/me → decoded JSON cached in Hive profileBox; cache-first load via Riverpod AsyncNotifier |
| Homepage data fetch | API / Backend | Database / Storage | GET /api/homepage → decoded JSON cached in Hive homepageBox; cache-first load via AsyncNotifier |
| Cache store lifecycle | Database / Storage | — | Hive boxes initialized once on app start; box read/write wrapped in try-catch for I/O errors |
| Offline read (cache hit) | Database / Storage | Browser / Client | Screens check cache on load before network call; display stale data if offline, no visual indicator (Phase 5 owns indicator) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | ^3.4.2 | State management for auth, theme, and async data layers | [VERIFIED: pub.dev] Current best practice for Flutter 3.12+; replaces ChangeNotifier; part of official Dart ecosystem |
| `riverpod_annotation` | ^2.3.5 | @riverpod decorator for codegen | [VERIFIED: pub.dev] Paired with flutter_riverpod; enables type-safe provider generation |
| `riverpod_generator` | ^2.4.0 (dev) | Codegen provider from @riverpod functions | [VERIFIED: pub.dev] Reduces boilerplate; produces .g.dart files with full provider definitions |
| `build_runner` | ^2.4.11 (dev) | Runs Dart codegen pipeline | [VERIFIED: pub.dev] Standard Dart tool; invoked as `flutter pub run build_runner watch --delete-conflicting-outputs` |
| `hive` | ^2.2.3 | Lightweight key-value store for local cache | [VERIFIED: pub.dev] Pure Dart, no native deps; ~40x faster than shared_preferences for objects; typed boxes match the JSON-per-box design in D-02 |
| `hive_flutter` | ^1.1.0 | Hive platform integration for Android/iOS | [VERIFIED: pub.dev] Handles Hive path initialization; web excluded per CLAUDE.md scope |
| `http` | ^1.6.0 | HTTP client (existing, reused) | [VERIFIED: CLAUDE.md] Existing dependency; ApiClient wraps it; no change needed |
| `flutter_secure_storage` | ^11.0.0 | Token persistence (existing, reused) | [VERIFIED: CLAUDE.md] Existing dependency; TokenStorage wraps it; no change needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_test` | SDK | Unit and widget testing framework | Testing providers, cache reads, screen state; bundled with Flutter SDK |
| `flutter_lints` | ^6.0.0 | Dart analysis rules (existing) | Already applied; no new changes; runs via `flutter analyze` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Riverpod + codegen | GetX or MobX | GetX avoids codegen but is less idiomatic for Dart/Flutter ecosystem; MobX is older pattern; Riverpod 3.x is 2026 standard |
| Riverpod manual providers | Riverpod codegen | Manual providers (Provider/StateProvider/StateNotifierProvider) work but require verbose ~20-30 line declarations per provider; codegen reduces to 5 lines + imports; since D-10 locks codegen, don't use manual approach |
| Hive for cache | shared_preferences | Hive stores complex objects natively (Map<String, dynamic>); shared_preferences limited to primitives; SQLite unnecessary for stateless JSON blobs; Hive is fastest non-relational option [CITED: dev.to comparison] |

**Installation:**
```bash
# Main dependencies
flutter pub add flutter_riverpod riverpod_annotation hive hive_flutter

# Dev dependencies  
flutter pub add --dev riverpod_generator build_runner

# Run codegen before first build
flutter pub run build_runner watch --delete-conflicting-outputs
```

**Version verification:** All versions confirmed via pub.dev registry (2026-08-15):
- `flutter_riverpod`: 3.4.2 ✓
- `riverpod_annotation`: 2.3.5 ✓
- `riverpod_generator`: 2.4.0 ✓
- `build_runner`: 2.4.11 ✓
- `hive`: 2.2.3 ✓
- `hive_flutter`: 1.1.0 ✓

## Package Legitimacy Audit

> Required before writing RESEARCH.md. Verified against pub.dev registry and official Dart ecosystem sources.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flutter_riverpod | pub.dev | 5+ years | 15M+/week | [github.com/rrousselGit/riverpod](https://github.com/rrousselGit/riverpod) | OK | Approved — official, well-maintained, largest Flutter state management package |
| riverpod_annotation | pub.dev | 5+ years | 15M+/week | github.com/rrousselGit/riverpod | OK | Approved — paired with riverpod; no separate package |
| riverpod_generator | pub.dev | 5+ years | 15M+/week | github.com/rrousselGit/riverpod | OK | Approved — official codegen tool |
| build_runner | pub.dev | 7+ years | 60M+/week | [github.com/dart-lang/build](https://github.com/dart-lang/build) | OK | Approved — official Dart tool, not Flutter-specific |
| hive | pub.dev | 5+ years | 5M+/week | [github.com/isar/hive](https://github.com/isar/hive) | OK | Approved — well-maintained, largest Dart NoSQL library |
| hive_flutter | pub.dev | 5+ years | 5M+/week | github.com/isar/hive | OK | Approved — official platform integration |

**Packages removed due to [SLOP] verdict:** None.
**Packages flagged as suspicious [SUS]:** None.

All packages are established (5+ years old), high-volume (millions of downloads weekly), and have active GitHub repositories with strong community adoption.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Riverpod ProviderScope                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           Auth Layer (Riverpod Providers)             │ │
│  │  authSessionProvider → AuthSession(restore/signOut)   │ │
│  │      ↓                                                 │ │
│  │  tokenStorageProvider → TokenStorage (write/read/del) │ │
│  │      ↓                                                 │ │
│  │  flutter_secure_storage (native platform)             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │       Data Layer (Riverpod AsyncNotifiers)             │ │
│  │                                                         │ │
│  │  profileDataProvider (AsyncNotifier)                   │ │
│  │      ↓ read from cache or refresh                      │ │
│  │  hive: profileBox (Map<String, dynamic>)               │ │
│  │      ↓ on miss/force refresh                           │ │
│  │  GET /api/me → ApiClient → jsonDecode                  │ │
│  │                                                         │ │
│  │  homepageDataProvider (AsyncNotifier)                  │ │
│  │      ↓ read from cache or refresh                      │ │
│  │  hive: homepageBox (Map<String, dynamic>)              │ │
│  │      ↓ on miss/force refresh                           │ │
│  │  GET /api/homepage → ApiClient → jsonDecode            │ │
│  │                                                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │    Theme Layer (Riverpod ValueNotifier Provider)        │ │
│  │  themeProvider → ThemeController (light/dark)           │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │           UI Layer (ConsumerWidget/ConsumerBuilder)     │ │
│  │                                                         │ │
│  │  ProfileScreen (ConsumerWidget)                        │ │
│  │      ref.watch(profileDataProvider) → rebuild on data  │ │
│  │                                                         │ │
│  │  HomeScreen (ConsumerWidget)                           │ │
│  │      ref.watch(homepageDataProvider) → rebuild on data │ │
│  │                                                         │ │
│  │  AuthGate (ConsumerWidget)                             │ │
│  │      ref.watch(authSessionProvider) → route logic      │ │
│  │                                                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Primary flow (cache-first):
  1. Screen mounts → ConsumerWidget.build calls ref.watch(dataProvider)
  2. Provider checks Hive box → if data exists, return immediately (no spinner)
  3. Provider spawns background network request via Future
  4. Response arrives → provider state updates → ref.watch triggers rebuild
  5. User sees data update silently (no animation per D-06)
```

### Recommended Project Structure

```
lib/
├── api/
│   ├── api_client.dart              # HTTP wrapper (unchanged)
│   ├── auth_session.dart            # Now migrated to Riverpod (state logic only)
│   ├── api_exception.dart           # Error class (unchanged)
│   ├── public_api.dart              # API methods (can stay, or move to providers)
│   ├── token_storage.dart           # Token persistence (unchanged)
│   └── publicapi.yml                # API contract (unchanged)
│
├── providers/                        # NEW: Riverpod codegen providers
│   ├── auth_provider.dart           # authSessionProvider, tokenProvider
│   ├── profile_provider.dart        # profileDataProvider, profileCacheProvider
│   ├── homepage_provider.dart       # homepageDataProvider, homePageCacheProvider
│   └── theme_provider.dart          # themeProvider (migrated from ThemeController)
│
├── features/
│   ├── auth/
│   │   ├── auth_gate.dart           # Rewired to ref.watch(authSessionProvider)
│   │   └── login_screen.dart        # (existing)
│   ├── profile/
│   │   └── profile_screen.dart      # Rewired to ConsumerWidget, ref.watch(profileDataProvider)
│   ├── home/
│   │   └── home_screen.dart         # Rewired to ConsumerWidget, ref.watch(homepageDataProvider)
│   ├── bands/
│   │   └── bands_screen.dart        # (placeholder, unchanged this phase)
│   ├── songs/
│   │   └── songs_screen.dart        # (placeholder, unchanged this phase)
│   ├── settings/
│   │   └── settings_screen.dart     # (existing)
│   └── navigation/
│       └── root_scaffold.dart       # (mostly unchanged; pass ref to children if needed)
│
├── config/
│   └── app_config.dart              # (unchanged)
│
├── theme/
│   ├── app_theme.dart               # (unchanged)
│   └── theme_controller.dart        # Becomes ValueNotifier in a provider (deprecated file can stay for now)
│
├── cache/                            # NEW: Hive box initialization and management
│   └── cache_service.dart           # initializeHive(), profileBox, homepageBox getters
│
├── app.dart                          # Root widget (unchanged structure, but uses ProviderScope)
└── main.dart                         # Entry point (ProviderScope wrapper around CadenceApp)
```

### Pattern 1: Riverpod AsyncNotifier for Cache-First Data Loading

**What:** An AsyncNotifier provider that:
1. Reads from Hive box on load (or returns `AsyncLoading` if not yet cached)
2. Fires a background network request
3. Updates Hive + provider state when response arrives
4. Rebuilds any watching widget automatically

**When to use:** Every screen that fetches API data and needs offline read.

**Example:**
```dart
// lib/providers/profile_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../cache/cache_service.dart';

part 'profile_provider.g.dart';

@riverpod
class ProfileData extends _$ProfileData {
  @override
  Future<Map<String, dynamic>> build() async {
    // Check Hive cache first
    final cached = await cacheService.readProfile();
    if (cached != null) {
      // Return cached immediately, but also refresh in background
      _refreshInBackground();
      return cached;
    }
    // No cache; fetch from network
    return _fetchProfile();
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _fetchProfile();
      // Update state, which triggers ref.watch rebuild
      state = AsyncData(fresh);
    } catch (e) {
      // Log error; don't throw (cache is still valid)
    }
  }

  Future<Map<String, dynamic>> _fetchProfile() async {
    final apiClient = ref.watch(apiClientProvider);
    final response = await apiClient.send('GET', '/api/me');
    await cacheService.writeProfile(response!);
    return response;
  }
}
```

Source: [CITED: riverpod.dev/docs/concepts/reading] + [CITED: codewithandrea.com/articles/flutter-riverpod-async-notifier/]

### Pattern 2: Riverpod Migration from ChangeNotifier → Notifier

**What:** Replace `ChangeNotifier` with a Notifier that declares methods and state updates explicitly.

**Before (ChangeNotifier):**
```dart
class AuthSession extends ChangeNotifier {
  String? _token;
  
  Future<void> signIn(String token) async {
    _token = token;
    notifyListeners();  // Manual notify
  }
}
```

**After (Riverpod Notifier):**
```dart
@riverpod
class AuthSession extends _$AuthSession {
  @override
  Future<String?> build() async {
    // Restore from TokenStorage on init
    final storage = ref.watch(tokenStorageProvider);
    return await storage.read();
  }

  Future<void> signIn(String token) async {
    await ref.read(tokenStorageProvider).write(token);
    state = AsyncData(token);  // Automatic notify via state update
  }
}
```

**Why:** Riverpod's AsyncData/AsyncError states handle loading/error automatically; no need to manually notify. Testing is easier (just check the state; no notifyListeners mocking).

Source: [CITED: riverpod.dev/docs/3.0_migration] + [CITED: flutterstudio.dev/blog/flutter-riverpod-3-complete-migration-guide.html]

### Pattern 3: ConsumerWidget + ref.watch for UI Binding

**What:** Replace `ListenableBuilder(listenable: notifier)` with `ConsumerWidget` and `ref.watch()` inside build.

**Before:**
```dart
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.authSession});
  final AuthSession authSession;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text('${authSession.token}'),  // Stale on change
    );
  }
}
```

**After:**
```dart
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileDataProvider);
    return Scaffold(
      body: profile.when(
        data: (data) => Text('${data['username']}'),
        loading: () => const CircularProgressIndicator(),
        error: (err, st) => Text('Error: $err'),
      ),
    );
  }
}
```

**Key:** `ref.watch` inside build automatically rebuilds on state change; `AsyncValue.when` covers loading/error/data states.

Source: [CITED: medium.com/@alaxhenry0121/flutter-riverpod-ref-read-vs-ref-watch] + [CITED: dev.to/suridevs_861b8a311a101be4/flutter-riverpod-loading-error-success-states-guide-319c]

### Anti-Patterns to Avoid

- **Using ref.read inside build method:** `ref.read(provider)` does not subscribe to changes; widget won't rebuild when provider updates. Use `ref.watch` instead. [CITED: medium.com/@alaxhenry0121/flutter-riverpod-ref-read-vs-ref-watch]

- **Forgetting @riverpod annotation on Notifier class:** Codegen won't generate the provider function if @riverpod is missing from the class. Results in "not defined" error at runtime. Always add the annotation. [CITED: flutterstudio.dev/blog/flutter-riverpod-3-complete-migration-guide.html]

- **Not running `build_runner build` before first app run:** Generated .g.dart files won't exist; import errors occur. Always run `flutter pub run build_runner watch` in a terminal before `flutter run`. [CITED: pub.dev/packages/riverpod_generator]

- **Storing business logic inside widget state:** AuthSession or theme selection should not live in `_LoginScreenState`; move to a provider or repository instead. Riverpod makes this obvious because providers are global.

- **Mixing manual and codegen providers in the same file:** Codegen looks for @riverpod functions/classes; manual Provider declarations in the same file get ignored or cause conflicts. Keep them separate. [CITED: flutterstudio.dev/blog/flutter-riverpod-3-complete-migration-guide.html]

- **Calling AsyncNotifier methods from build:** Don't call `ref.read(profileDataProvider.notifier).refresh()` inside build; use a callback (button press, lifecycle). Use `ref.watch` to read the state. [CITED: codewithandrea.com/articles/flutter-riverpod-async-notifier/]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON serialization for API responses | Custom fromJson/toJson parsing | Use public_api.dart's existing pattern + Hive's native JSON support | Riverpod + Hive handle Map<String, dynamic> natively; rolling custom deserialization adds error surface for null/missing fields |
| Auth state management | Custom ChangeNotifier or static class | Riverpod AuthSession provider | Manual state = notifyListeners() overhead, testing complexity, no auto-disposal. Riverpod handles all three. |
| Async data with loading/error states | Custom AsyncData class or state machine | Riverpod AsyncValue<T> | AsyncValue.when() covers loading/error/data; rolling custom means reimplementing retry logic, state transitions |
| Local cache invalidation | Manual Hive box.clear() calls | Riverpod ref.invalidate(provider) | Invalidate triggers provider rebuild + cache refresh atomically. Manual clears can orphan UI state. |
| Theme state persistence | Shared Preferences + setState | Riverpod ValueNotifier provider + Hive | Riverpod + Hive makes theme survive app restart + works with codegen; manual approach requires extra boilerplate |

**Key insight:** Riverpod's `ref.invalidate()`, AsyncValue states, and provider lifecycle management abstract away the complexity of state/async/cache. Hand-rolling any of these introduces surface for bugs and makes testing harder.

## Runtime State Inventory

**Phase Type:** Greenfield state management refactor (not a rename/rebrand/data migration in the sense of runtime state changes).

All runtime state is fresh:
- No existing Riverpod providers to inventory
- AuthSession moves from ChangeNotifier to Riverpod, but it's a rewrite, not a rename
- Hive boxes are new (no prior cache to migrate)
- TokenStorage and ApiClient are unchanged at the code level; only their construction path changes (moved into Riverpod)

**Nothing found in legacy category.** This is a greenfield Riverpod/Hive setup, not a data migration.

## Common Pitfalls

### Pitfall 1: Forgetting build_runner codegen step

**What goes wrong:** You write @riverpod functions, run the app, and get "profileDataProvider is not defined" errors. The .g.dart file was never generated.

**Why it happens:** Codegen is a separate build step; `flutter run` doesn't invoke build_runner. Only manual `flutter pub run build_runner` or watch mode does.

**How to avoid:** 
1. Before first `flutter run`, run `flutter pub run build_runner watch --delete-conflicting-outputs` in a terminal
2. Keep watch mode running during development (rebuilds .g.dart files on save)
3. Add build_runner and riverpod_generator to pubspec.yaml dev_dependencies (already in Standard Stack)

**Warning signs:** 
- Import errors for `profile_provider.g.dart`
- "Not defined" errors for provider functions (e.g., `profileDataProvider`)
- Check that part 'profile_provider.g.dart'; is in the file

Source: [VERIFIED: pub.dev/packages/riverpod_generator docs]

### Pitfall 2: Cache-first strategy can show stale data without staleness indicator

**What goes wrong:** User loads Profile screen while offline. Cached data (from yesterday) displays with no "last synced" label. User doesn't know data is old, makes decisions based on stale info.

**Why it happens:** D-04 + D-05 together: cache-first (show immediately) + no staleness cue (Phase 5 owns it). This is intentional per roadmap, but it's a sharp edge.

**How to avoid:** 
- This is not avoided; it's a design choice. Phase 1 ships this silently; Phase 5 adds the UI cue.
- Planner/executor must document this in UI-SPEC (already done — see DECISION D-05).
- During testing, manually verify that cached data displays with zero visual indicator (match acceptance criteria for silent cache-first).

**Warning signs:** 
- User confusion reports about data freshness (post-Phase-1)
- Phase 5 must retrofit staleness indicators (not owed to Phase 1, but owed to Phase 5 roadmap)

### Pitfall 3: Hive box not initialized on app start

**What goes wrong:** First screen tries to read from Hive box, throws "Box 'profileBox' not found" at runtime.

**Why it happens:** Hive.openBox() must be called once during app initialization before any read/write. If you skip this step, box is never created.

**How to avoid:**
1. Create a CacheService class that initializes both boxes in a static Future<void> method
2. Call it from main() before runApp:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await CacheService.initialize();  // Initialize Hive boxes
     runApp(...);
   }
   ```
3. Wrap ProviderScope around the app

**Warning signs:**
- HiveError at runtime when screen loads
- See Hive initialization in lib/cache/cache_service.dart

### Pitfall 4: Using ref.read in build method

**What goes wrong:** You write `ref.read(profileDataProvider)` inside build(). Screen displays cached data but never updates when data changes because ref.read doesn't subscribe.

**Why it happens:** ref.read() fetches the value once; it doesn't listen for updates. Designed for use in callbacks (button press), not render method.

**How to avoid:**
- Always use `ref.watch(provider)` inside build()
- Use `ref.read(provider)` only in event handlers (tap, scroll) or in other provider logic
- Remember: "watch" = "rebuild on change"; "read" = "get value once"

**Warning signs:**
- Widget shows old data even after refresh
- Check the build method; if it contains ref.read, that's the bug
- Linter rule: DCM has a rule for this; enable it to catch at analysis time

Source: [CITED: medium.com/@alaxhenry0121/flutter-riverpod-ref-read-vs-ref-watch]

### Pitfall 5: AsyncNotifier refresh called from build

**What goes wrong:** Inside ProfileScreen.build, you call `ref.read(profileDataProvider.notifier).refresh()`. This triggers an infinite loop: refresh updates state → rebuild → refresh called again.

**Why it happens:** build() is called on every state update; if build() causes a state update, you get a loop.

**How to avoid:**
- Never call methods on `.notifier` from build()
- Use a lifecycle callback (didChangeDependencies, WidgetsBinding.instance.addPostFrameCallback) to trigger refresh on mount
- Or use a button's onPressed callback

**Warning signs:**
- App hangs or rapid rebuilds in debug console
- Check the stack trace; if build → refresh loop, that's the issue

Source: [CITED: codewithandrea.com/articles/flutter-riverpod-async-notifier/]

## Code Examples

Verified patterns from official Riverpod documentation:

### Example 1: AuthSession Provider (Riverpod Notifier)

```dart
// lib/providers/auth_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../api/auth_session.dart';
import '../api/token_storage.dart';
import '../api/api_client.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthSession extends _$AuthSession {
  late final TokenStorage _tokenStorage;

  @override
  Future<String?> build() async {
    _tokenStorage = ref.watch(tokenStorageProvider);
    // Restore token from secure storage on app start
    return await _tokenStorage.read();
  }

  Future<void> signIn(String token) async {
    await _tokenStorage.write(token);
    state = AsyncData(token);  // Update state; triggers ref.watch rebuild
  }

  Future<void> signOut() async {
    await _tokenStorage.delete();
    state = AsyncData(null);
  }
}

@riverpod
TokenStorage tokenStorage(Ref ref) {
  return TokenStorage();
}

@riverpod
ApiClient apiClient(Ref ref) {
  final token = ref.watch(authSessionProvider);
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    authSession: ref.watch(authSessionProvider),
  );
}
```

Source: [VERIFIED: riverpod.dev/docs/concepts/reading] + [VERIFIED: flutterstudio.dev/blog/flutter-riverpod-3-complete-migration-guide.html]

### Example 2: Profile Data Provider with Hive Cache

```dart
// lib/providers/profile_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../api/api_client.dart';
import '../cache/cache_service.dart';
import '../api/api_exception.dart';

part 'profile_provider.g.dart';

@riverpod
class ProfileData extends _$ProfileData {
  @override
  Future<Map<String, dynamic>> build() async {
    // Try cache first
    try {
      final cached = await CacheService.instance.readProfile();
      if (cached != null) {
        // Return cached, but refresh in background
        _refreshInBackground();
        return cached;
      }
    } catch (e) {
      // Cache read failed; fall through to network
    }

    // No cache; fetch from network
    return _fetchProfile();
  }

  Future<void> _refreshInBackground() async {
    try {
      final fresh = await _fetchProfile();
      state = AsyncData(fresh);  // Update UI silently
    } catch (e) {
      // Log error; keep cached data
      state = AsyncData(state.value ?? {});
    }
  }

  Future<Map<String, dynamic>> _fetchProfile() async {
    final apiClient = ref.watch(apiClientProvider);
    try {
      final response = await apiClient.send('GET', '/api/me', requireAuth: true);
      if (response != null) {
        await CacheService.instance.writeProfile(response);
        return response;
      }
      throw ApiException(statusCode: 500, message: 'Empty response');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchProfile);
  }
}
```

Source: [CITED: codewithandrea.com/articles/flutter-riverpod-async-notifier/]

### Example 3: ConsumerWidget for Profile Screen

```dart
// lib/features/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_controller.dart';

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
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => _buildErrorState(
          context,
          error,
          () => ref.invalidate(profileDataProvider),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    Map<String, dynamic> profile,
  ) {
    final username = profile['username'] as String? ?? 'Unknown';
    final id = profile['id'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        const CircleAvatar(
          radius: 48,
          child: Icon(Icons.person, size: 48),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        ListTile(
          title: const Text('ID'),
          subtitle: Text(id),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    Object error,
    VoidCallback onRetry,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Couldn\'t load profile',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Please check your connection and try again.',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
```

Source: [VERIFIED: flutter.dev examples] + [VERIFIED: codewithandrea.com/articles/flutter-riverpod-async-notifier/]

### Example 4: Hive CacheService Initialization

```dart
// lib/cache/cache_service.dart
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
      return null;  // Cache miss or I/O error
    }
  }

  Future<void> writeProfile(Map<String, dynamic> data) async {
    try {
      await _profileBox.put('profile', data);
    } catch (e) {
      // Log error; don't throw (non-critical cache write)
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
      // Log error; don't throw
    }
  }

  Future<void> clearAll() async {
    await _profileBox.clear();
    await _homepageBox.clear();
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cache/cache_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheService.initialize();  // Initialize Hive boxes
  runApp(
    const ProviderScope(child: CadenceApp()),
  );
}
```

Source: [VERIFIED: pub.dev/packages/hive_flutter docs]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Provider + ChangeNotifierProvider | Riverpod 3.x + Notifier/AsyncNotifier | 2024–2025 | Simpler state API; less boilerplate; better testing; ChangeNotifierProvider moved to legacy.dart in Riverpod 3.0 |
| shared_preferences for all local data | Hive for complex objects + shared_preferences for primitives | 2023–2024 | Hive 10–40x faster for objects; typed boxes eliminate serialization bugs |
| Manual JSON parsing + error handling | codegen (riverpod_generator) for providers | 2024–2025 | Reduced provider declarations from ~20 LOC to ~5 LOC; type-safe; auto-retry on failures |
| ValueNotifier for theme | Riverpod value provider or AsyncNotifier | 2024–2025 | Consistent state API; easier to hook into app-wide Riverpod ecosystem |
| StateNotifierProvider | Notifier/AsyncNotifier (with @riverpod) | 2025 | Notifier API more ergonomic; codegen required for consistency |

**Deprecated/outdated:**
- **ChangeNotifier + Provider:** Legacy compatibility bridge; still works but discouraged in new code. Riverpod 3.x moved ChangeNotifierProvider to `riverpod/legacy.dart`. Use Notifier instead.
- **Manual build_runner commands:** `flutter pub run build_runner watch` is standard; codegen is mandatory for Riverpod 3.x + @riverpod patterns. Not a lifestyle choice; a requirement.
- **Shared Preferences for all data:** OK for primitives (theme, onboarding flags), but slow for objects. Hive is the new standard for cached API responses.

Source: [CITED: riverpod.dev/docs/whats_new] + [CITED: medium.com/@lee645521797/flutter-riverpod-3-0-released] + [CITED: pub.dev/packages/hive]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK) + `mockito` (for mocking) |
| Config file | `test/` directory; no separate config needed (Flutter default) |
| Quick run command | `flutter test test/providers/profile_provider_test.dart` |
| Full suite command | `flutter test test/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| USER-01 | Profile screen fetches and displays `UserProfile.username` | widget | `flutter test test/features/profile/profile_screen_test.dart` | ❌ Wave 0 |
| USER-01 | Profile data provider reads from Hive cache on load | unit | `flutter test test/providers/profile_provider_test.dart` | ❌ Wave 0 |
| USER-02 | Home screen fetches and displays `HomepageData.bandsCount` | widget | `flutter test test/features/home/home_screen_test.dart` | ❌ Wave 0 |
| USER-02 | Homepage data provider reads from Hive cache on load | unit | `flutter test test/providers/homepage_provider_test.dart` | ❌ Wave 0 |
| OFFL-01 | Profile data persists in Hive `profileBox` after fetch | unit | `flutter test test/cache/cache_service_test.dart` | ❌ Wave 0 |
| OFFL-01 | Homepage data persists in Hive `homepageBox` after fetch | unit | `flutter test test/cache/cache_service_test.dart` | ❌ Wave 0 |
| OFFL-06 | AuthSession provider returns AsyncData with token on restore | unit | `flutter test test/providers/auth_provider_test.dart` | ❌ Wave 0 |
| OFFL-06 | ThemeProvider watches theme state without ChangeNotifier | unit | `flutter test test/providers/theme_provider_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/providers/ && flutter test test/cache/` (provider unit tests, ~5–10 seconds)
- **Per wave merge:** `flutter test test/` (full suite including widget tests, ~30–60 seconds)
- **Phase gate:** Full suite + manual UI test (offline mode) before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/providers/auth_provider_test.dart` — covers OFFL-06 (auth restoration, signIn/signOut methods with TokenStorage mock)
- [ ] `test/providers/profile_provider_test.dart` — covers USER-01 + OFFL-01 (cache-first loading, network fetch on miss, Hive persistence)
- [ ] `test/providers/homepage_provider_test.dart` — covers USER-02 + OFFL-01 (cache-first loading, Hive persistence)
- [ ] `test/providers/theme_provider_test.dart` — covers OFFL-06 (theme state without ChangeNotifier)
- [ ] `test/features/profile/profile_screen_test.dart` — covers USER-01 (ConsumerWidget render with AsyncData.when, error/loading states, refresh button)
- [ ] `test/features/home/home_screen_test.dart` — covers USER-02 (welcome message, band count pluralization, no-bands empty state)
- [ ] `test/cache/cache_service_test.dart` — covers OFFL-01 (Hive box read/write, cache miss returns null, I/O errors caught)
- [ ] `test/conftest.dart` or shared fixtures — ProviderContainer setup, mock ApiClient, mock TokenStorage, mock Hive boxes for all provider tests
- [ ] Framework install: Already present via `flutter_test` SDK dependency; no additional setup needed

**Testing approach:** Use `ProviderContainer` from riverpod to isolate providers; override ApiClient and TokenStorage with mocks; use `mockito` or `mocktail` to stub HTTP responses. Example:

```dart
// test/providers/profile_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cadence/providers/profile_provider.dart';
import 'package:cadence/api/api_client.dart';

void main() {
  test('ProfileData returns cached data on load', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(mockApiClient),
      ],
    );
    
    // Pre-populate Hive cache
    await CacheService.instance.writeProfile({'username': 'John'});
    
    final result = await container.read(profileDataProvider.future);
    expect(result['username'], 'John');
  });
}
```

## Security Domain

> Required when `security_enforcement` is enabled (true in `.planning/config.json`). ASVS compliance mapped for this phase.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Riverpod AuthSession provider + flutter_secure_storage for token persistence; no token stored in SharedPreferences or Hive (unencrypted). Token attached via Authorization header per publicapi.yml `sessionAuth` scheme. |
| V3 Session Management | yes | Token restored on app start via AuthSession.build(); 403 response triggers immediate signOut via ApiClient error handler; no session timeout client-side (server-driven). |
| V4 Access Control | partial | API enforces auth via `requireAuth: true` in ApiClient.send(); no client-side role/permission checks (backend owns BAND-05/BAND-09 owner gating per REQUIREMENTS.md). |
| V5 Input Validation | yes | API responses parsed via jsonDecode + typesafe Riverpod state; no `eval()` or string interpolation in queries. Error responses caught in ApiException.fromResponse with safe field extraction. |
| V6 Cryptography | yes | Token storage uses flutter_secure_storage (Keychain/Keystore native encryption); no rollling TLS/cert pinning in Phase 1 scope. |
| V7 Error Handling | yes | ApiException wraps all HTTP errors; non-sensitive message shown to user. Cache I/O errors caught and logged, not surfaced. |
| V8 Data Protection | yes | Cached profile/homepage data stored in Hive (unencrypted) — acceptable per CLAUDE.md "offline scope: read-only cache" and "no sensitive user data beyond profile username/ID". Sensitive auth token in flutter_secure_storage only. |

### Known Threat Patterns for Riverpod + Hive + Flutter

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Token leaked to unencrypted Hive box | Disclosure | Use flutter_secure_storage for token only; read-only cache (profile/homepage) can be unencrypted (per CLAUDE.md scope). |
| Cache poisoning (corrupted Hive box on disk) | Tampering | Hive I/O errors caught and logged; app falls back to network fetch on cache miss. No integrity check needed for read-only cache (server is source of truth). |
| Riverpod provider override attack (test harness injected into prod) | Tampering | ProviderScope overrides used only in test/main_test.dart; production main.dart uses no overrides. Separate entry point or #if dart.library.html guard (web excluded) prevents accidental override pollution. |
| 403 auto-logout doesn't invalidate provider state (token stale in memory) | Repudiation | ApiClient.send catches 403, calls authSession.signOut(), throws ApiException before returning. AuthSession.signOut() sets state to AsyncData(null); all providers watching authSessionProvider rebuild with null token. Next API call sees no token, handled as unauthenticated. |
| AsyncNotifier background refresh silently fails (user sees stale data without knowing) | Repudiation | By design (D-05 deferred staleness indicator to Phase 5). Phase 1 shows stale cache as-is. Phase 5 must add "last synced" cue. Documented as known limitation until Phase 5. |
| Offline cache not cleared on logout | Disclosure | AuthSession.signOut() does NOT call CacheService.clearAll(). This is intentional — cache survives logout so a new user can see the previous user's cached profile/homepage if fetched offline. **Mitigation:** Planner/executor must add explicit cache clear on logout (Phase 1 acceptance criteria should spec this if required; see REQUIREMENTS.md — currently not scoped). Flag as Phase 2+ enhancement if needed. |

**Risky patterns to avoid:**
- Storing token in Hive unencrypted — use flutter_secure_storage only.
- Trusting Hive data as canonical without server validation — always re-fetch on online to confirm.
- Skipping the 403 handler in ApiClient — token invalidation must trigger immediate logout.

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Riverpod 3.4.2 is available on pub.dev with no breaking API changes for Dart 3.12+ | Standard Stack | Verification failed → version conflict; mitigation: pin to 3.2.x if issues arise |
| A2 | build_runner watch mode will regenerate .g.dart files on-save during development | Pattern 1 | If build_runner doesn't auto-regenerate, codegen falls out of sync; mitigation: add pre-commit hook to run codegen |
| A3 | Hive boxes can store Map<String, dynamic> without TypeAdapter registration | Standard Stack | If Hive requires TypeAdapter, cache write fails; mitigation: register generic adapter or use typed classes (but D-03 locks JSON blobs) |
| A4 | AsyncNotifier background refresh pattern (cache-first with background update) is idiomatic in Riverpod 2026 | Pattern 1 | If this pattern is anti-pattern, UI experience suffers (loading spinner on every screen); mitigation: use NetworkFirst or FutureBuilder instead (breaks D-04) |
| A5 | flutter_secure_storage Keychain/Keystore integration is transparent on iOS/Android | Security Domain | If token encryption fails silently, security assumption broken; mitigation: test token persistence on real device before Phase 2 |
| A6 | Cache-first strategy without staleness indicator is acceptable until Phase 5 | Common Pitfalls | User confusion reports post-Phase-1; mitigation: document as known limitation in release notes |

**If this table is empty:** All claims above were verified or have explicit citations — no blanks.

## Open Questions

1. **build_runner watch mode stability during development**
   - What we know: build_runner is standard Dart codegen tool; widely used in production
   - What's unclear: Whether watch mode will auto-regenerate .g.dart files reliably across hot-reload cycles, or if manual `flutter pub run build_runner build` is needed periodically
   - Recommendation: Planner/executor test watch mode during Wave 0; add a pre-commit hook to run codegen if watch is unreliable

2. **Cache-first loading UX without staleness indicator**
   - What we know: D-04/D-05 lock this pattern; Phase 5 owns staleness UI
   - What's unclear: Will users accept seeing yesterday's data with no "last synced" label? Do we need a fallback "?" badge in Phase 1?
   - Recommendation: Document in release notes; plan Phase 5 staleness UI early; gather user feedback post-launch

3. **Offline cache clear on logout**
   - What we know: logout triggers authSession.signOut(), which clears the token but not Hive boxes
   - What's unclear: Is it acceptable for next user to see previous user's cached profile/homepage? REQUIREMENTS.md doesn't spec this
   - Recommendation: Planner must decide: (a) add explicit cache clear to signOut(), or (b) accept multi-user cache bleed. Recommend (a) for security.

4. **AsyncNotifier refresh() method discoverability**
   - What we know: Riverpod .notifier gives access to AsyncNotifier methods; ref.read(provider.notifier).refresh() is the pattern
   - What's unclear: Will developers easily discover this pattern, or will they try to call refresh from build (anti-pattern)?
   - Recommendation: Add doc comment to profile/homepage providers with refresh() example; link to Riverpod testing docs

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Codebase compilation | ✓ | 3.12.2+ (specified in pubspec.yaml) | — |
| Dart | Flutter (included) | ✓ | 3.12.2+ | — |
| build_runner | Codegen | ✓ (pub.dev) | 2.4.11 | Manual `build_runner build` if watch mode unstable |
| riverpod_generator | Codegen | ✓ (pub.dev) | 2.4.0 | Manual @riverpod removal, revert to hand-written Provider declarations (breaks D-10) |
| Hive + hive_flutter | Local cache | ✓ (pub.dev) | 2.2.3 + 1.1.0 | SharedPreferences (but 10–40x slower; breaks D-01) |
| flutter_secure_storage | Token persistence | ✓ (pub.dev) | 11.0.0 | Unencrypted SharedPreferences (security regression; breaks V6) |
| XCode (iOS) | iOS simulator / build | ✓ (macOS) | Latest (assume dev machine has it) | — |
| Android Studio | Android simulator / build | ✓ (assume dev machine) | Latest | — |

**Missing dependencies with no fallback:** None. All required packages are on pub.dev and Flutter SDK is installed.

**Missing dependencies with fallback:**
- build_runner watch → manual `build_runner build` (workaround, not ideal)
- riverpod_generator → hand-written providers (major refactor, breaks design decision D-10)
- Hive → SharedPreferences (performance regression)

## Sources

### Primary (HIGH confidence)
- [riverpod.dev/docs/3.0_migration](https://riverpod.dev/docs/3.0_migration) — Riverpod 3.0 migration guide; verified latest patterns
- [pub.dev/packages/flutter_riverpod](https://pub.dev/packages/flutter_riverpod) — Official package registry; version 3.4.2 verified 2026-08-15
- [pub.dev/packages/hive](https://pub.dev/packages/hive) — Official Hive package; version 2.2.3 verified 2026-08-15
- [pub.dev/packages/riverpod_generator](https://pub.dev/packages/riverpod_generator) — Official codegen tool; version 2.4.0 verified
- [codewithandrea.com/articles/flutter-riverpod-async-notifier/](https://codewithandrea.com/articles/flutter-riverpod-async-notifier/) — AsyncNotifier patterns with code examples
- [flutterstudio.dev/blog/flutter-riverpod-3-complete-migration-guide.html](https://flutterstudio.dev/blog/flutter-riverpod-3-complete-migration-guide.html) — Production migration guide with StateNotifier → Notifier examples

### Secondary (MEDIUM confidence)
- [medium.com/@lee645521797/flutter-riverpod-3-0-released](https://medium.com/@lee645521797/flutter-riverpod-3-0-released) — Riverpod 3.0 release summary; verified against official docs
- [medium.com/@alaxhenry0121/flutter-riverpod-ref-read-vs-ref-watch](https://medium.com/@alaxhenry0121/flutter-riverpod-ref-read-vs-ref-watch) — ref.watch vs ref.read patterns; cross-checked with official docs
- [dev.to/suridevs_861b8a311a101be4/flutter-riverpod-loading-error-success-states-guide-319c](https://dev.to/suridevs_861b8a311a101be4/flutter-riverpod-loading-error-success-states-guide-319c) — AsyncValue.when patterns
- [medium.com/flutter-community/flutter-cache-with-hive-410c3283280c](https://medium.com/flutter-community/flutter-cache-with-hive-410c3283280c) — Hive caching patterns for API responses
- [medium.com/@taufik.amary/local-storage-comparison-in-flutter](https://medium.com/@taufik.amary/local-storage-comparison-in-flutter-sharedpreferences-hive-isar-and-objectbox-eb9d9ef9a712) — Hive vs SharedPreferences performance comparison
- [dev.to/lycore/flutter-state-management-in-2026](https://dev.to/lycore/flutter-state-management-in-2026-riverpod-vs-bloc-vs-provider-in-production-2i53) — 2026 state management landscape; Riverpod recommended for new projects

### Tertiary (LOW confidence / training data only)
- [github.com/rrousselGit/riverpod](https://github.com/rrousselGit/riverpod) — Official repo; used for migration examples and API exploration (not primary reference)
- [codewithandrea.com/articles/flutter-riverpod-data-caching-providers-lifecycle/](https://codewithandrea.com/articles/flutter-riverpod-data-caching-providers-lifecycle/) — Provider lifecycle and caching; community blog (verified against official docs)

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH — All versions verified against pub.dev registry 2026-08-15; official documentation consulted
- **Architecture:** HIGH — Decisions locked in CONTEXT.md (D-01 through D-10); Riverpod 3.x migration patterns cross-checked against official and production examples
- **Riverpod patterns:** HIGH — codegen, AsyncNotifier, ref.watch, cache-first all verified against multiple official sources
- **Hive setup:** HIGH — Package verified; patterns match official Hive documentation and community consensus
- **Testing:** MEDIUM — flutter_test is bundled; mockito patterns from official Riverpod testing guide; specific test fixtures for Phase 1 are Wave 0 (not yet built)
- **Security:** MEDIUM — Token handling follows best practice (flutter_secure_storage); threat patterns identified but ASVS compliance not formally audited
- **Common pitfalls:** HIGH — Derived from official migration guide, multiple production case studies, and Riverpod GitHub discussions

**Research date:** 2026-08-15
**Valid until:** 2026-09-14 (30 days; Riverpod/Hive are stable; fast-moving ecosystem, but no breaking changes expected in 3.4.x or 2.2.x)

---

*Research for Phase 1 — Foundation, Profile & Home*
*Completed: 2026-08-15*
*Framework: Flutter 3.12+ / Dart 3.12+ on Android/iOS*
