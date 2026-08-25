# Coding Conventions

**Analysis Date:** 2026-08-25

## Naming Patterns

**Files:**
- Dart files use snake_case: `auth_provider.dart`, `api_client.dart`, `token_storage.dart`
- Screen files end with `_screen`: `login_screen.dart`, `bands_screen.dart`, `setlists_screen.dart`
- Generated files end with `.g.dart`: `auth_provider.g.dart` (Riverpod generator output)
- Test files named after subject with directory structure mirroring source: `test/providers/auth_provider_test.dart`

**Classes:**
- All classes use PascalCase: `AuthSession`, `ApiClient`, `LoginScreen`, `OfflineNoCacheException`
- Private internal State classes prefixed with underscore: `_LoginScreenState`, `_FakeCacheService`
- Exception classes named explicitly: `ApiException`, `OfflineNoCacheException`

**Functions/Methods:**
- All methods use camelCase: `signIn()`, `signOut()`, `restore()`, `register()`, `login()`, `send()`, `setThemeMode()`
- Private methods prefixed with underscore: `_submit()`, `_toggleMode()`, `_fetchAndCache()`, `_deepConvert()`
- Async methods return `Future`: `Future<String?>`, `Future<void>`, `Future<List<Map<String, dynamic>>>`

**Variables/Properties:**
- Public properties: camelCase (`baseUrl`, `authSession`, `httpClient`)
- Private properties: prefix with underscore and camelCase (`_httpClient`, `_formKey`, `_usernameController`, `_errorMessage`, `_isSubmitting`)
- Mutable state in StatefulWidget: `_token`, `_status`, `_version`
- Static constants: UPPER_SNAKE_CASE for stored keys/strings (`_tokenKey = 'auth_token'`), but config values may use camelCase (`apiBaseUrl`)

**Enumerations:**
- Enum cases use lowercase: `ThemeMode.system`, `_AuthMode.login`, `_AuthMode.signUp`
- Private enums for local widget state: `enum _AuthMode { login, signUp }`
- Public enums for API/domain state: `enum AuthStatus { unknown, authenticated, unauthenticated }`

**Named Parameters:**
- Preferred for multi-parameter functions: `register(username: username, password: password)`
- Constructor parameters follow: `{super.key, required this.field}`

## Code Style

**Formatting:**
- Dart's built-in formatter (dartfmt) is the standard
- Apply via `flutter format lib/` and `flutter analyze`
- Line length: follows Dart conventions (typically 80-120 characters)
- Indentation: 2 spaces (Flutter default)

**Linting:**
- Tool: `flutter_lints` 6.0.0 (extends `package:flutter_lints/flutter.yaml`)
- Config: `analysis_options.yaml` at repository root
- Run: `flutter analyze`
- All default flutter_lints rules are enabled with no custom overrides

**Widget Constructors:**
- Always use `const` when possible: `const HomeScreen({super.key})`, `const CadenceApp({super.key, ...})`
- Improves performance and widget tree stability
- Private state class: `@override ConsumerState<LoginScreen> createState() => _LoginScreenState();`

**No Aliases:**
- All imports use explicit relative paths from root: `import 'package:cadence/...'` for package-relative
- Relative `../` paths used for cross-directory imports within lib/
- No import/export aliases configured

## Import Organization

**Order (strictly observed):**
1. Dart imports: `import 'dart:async';`, `import 'dart:io';`, `import 'dart:convert';`
2. Flutter imports: `import 'package:flutter/material.dart';`, `import 'package:flutter/foundation.dart';`
3. External packages: `import 'package:flutter_riverpod/flutter_riverpod.dart';`, `import 'package:hive/hive.dart';`
4. Relative package imports: `import 'package:cadence/...'`
5. Relative path imports: `import '../api/api_client.dart';`

Example from `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'cache/cache_service.dart';
```

## Error Handling

**Exception Types:**
- Use `ApiException` for HTTP-level errors with `statusCode`, `code`, and `message` fields
- Construct manually: `ApiException(statusCode: 403, code: 'unauthorized', message: '...')`
- Construct via factory: `ApiException.fromResponse(response)` parses JSON error shape
- Implements `Exception` interface, toStringifies to `message`

**Catching and Transformation:**
- Caught at UI layer in screen state (`LoginScreen._submit()`)
- Status-code-specific messages: `403` → "unauthorized", `401` → "Invalid credentials", `400` + `already_exists` → "This username is already taken"
- Re-throw pattern to propagate unexpected errors up the stack (see `lib/features/auth/login_screen.dart` lines 48-75)
- Displayed to user via state: `_errorMessage` shown in UI

**Parsing Resilience:**
- JSON parsing failures silently caught and fallback to generic message: `catch (_) { ... }` (see `lib/api/api_exception.dart` line 19)
- Non-empty checks before parsing: `if (response.body.isNotEmpty)` (see `lib/api/api_exception.dart` line 9)
- Status code 403 triggers automatic `signOut()` before throwing (see `lib/api/api_client.dart` lines 56-59)

**Offline/Network Errors:**
- Caught as `SocketException` in best-effort server-side logout path (see `lib/providers/auth_provider.dart` lines 51-62)
- Swallowed without re-throw to allow local sign-out to complete regardless of network outcome

## Logging

**Current Practice:**
- No `print()` statements in production code
- Console/debug output not used for diagnostics
- Error states communicated to user via UI (`_errorMessage` displayed in screens)

**Comments serve as inline documentation** where diagnostic info is needed:
- Explain edge cases: "Without this guard, that nested call would see `state.value` still non-null and re-attempt `logout()`" (line 36-40 in `auth_provider.dart`)
- Document workarounds: "This milestone has no offline mutation queue (see CLAUDE.md), so any failure here (offline, timeout, 403, etc.) is swallowed" (line 52-57 in `auth_provider.dart`)

## Comments

**Doc Comments (///):**
- Used for public API behavior (classes, methods, notable properties)
- Explain "why" rather than "what" when behavior is non-obvious
- Mark edge cases: "Reentrancy guard for [signOut]..." (line 36 in `auth_provider.dart`)
- Document deprecated patterns or migration paths
- Include examples for complex behavior
- Parameter descriptions when defaults are non-obvious

Examples:
```dart
/// Thrown by an online-first provider's `build()` when the device is
/// offline and there is no cached data for the requested resource (D-06).
class OfflineNoCacheException implements Exception { ... }

/// Encapsulates token persistence using flutter_secure_storage.
/// [read] and [write] handle platform-level errors internally.
class TokenStorage { ... }
```

**Inline Comments (//):**
- Explain "why" rather than "what": "D-03: online but the fetch itself failed — fall back to cache silently" (line 47 in `bands_provider.dart`)
- Mark behavioral contracts: "WR-02: capture this before network await" (line 35)
- Reference design docs: "(D-01/D-03/D-06)" for offline-first patterns
- Document platform differences or workarounds
- Explain reentrancy guards and deduplication logic

Example from `bands_provider.dart` lines 35-36:
```dart
/// Monotonic counter bumped by every local-mutation method ([setBands],
/// [renameBand]). [refresh]/[_doRefresh] capture this before their
/// network await and discard a fetched result if it changed while the
/// fetch was in flight — otherwise a slower background refresh could
/// silently revert a local edit that landed first (WR-02).
int _version = 0;
```

## Function Design

**Parameters:**
- Type annotations always explicit: `Future<void> signOut()`, `String? Function() getToken`
- Named parameters used for multi-parameter functions
- Required parameters marked with `required` keyword
- Constructor parameters follow pattern: `{super.key, required this.field}`

**Return Values:**
- Functions return typed values (not `dynamic`)
- Futures used for async operations: `Future<String?>`, `Future<void>`, `Future<List<Map<String, dynamic>>>`
- Nullable returns marked with `?`: `String?`, `Future<Map<String, dynamic>?>`

**Size Guidelines:**
- Methods tend to be 20-50 lines for state management
- Complex logic (like `_doRefresh()` in providers) documented with inline comments explaining each phase
- Extracted helper methods for common patterns: `_fetchAndCache()`, `_deepConvert()`, `_toggleMode()`

**Patterns:**
- Constructor injection for dependencies: `ApiClient({required this.baseUrl, required this.getToken, ...})`
- Callback injection for decoupling: `getToken`, `onUnauthorized` passed to `ApiClient`
- Deduplication via closure variables: `_inFlightRefresh ??= _doRefresh().whenComplete(...)`
- Version counters for stale-response detection: `_version++` after mutations, checked in `_doRefresh()`

## Module Design

**File Organization:**
- Single responsibility: each file contains one main class (exception: test doubles and helpers)
- Related functionality grouped in directories: `lib/api/`, `lib/features/auth/`, `lib/theme/`
- No barrel files (`index.dart` re-exports) used
- Each file imports directly what it needs from other modules

**Directory Structure:**
- `lib/api/`: HTTP client, API methods, authentication, token storage, exceptions
- `lib/features/`: Feature screens and feature-specific UI logic (one subdirectory per feature: `auth/`, `bands/`, `setlists/`, etc.)
- `lib/config/`: Application-wide configuration (AppConfig with build-time env var injection)
- `lib/theme/`: Theming and appearance logic (AppTheme, ThemeController)
- `lib/navigation/`: Navigation structure and root layout (RootScaffold, routing)
- `lib/providers/`: Riverpod state management (auth, connectivity, data providers)
- `lib/cache/`: Local caching via Hive (CacheService)
- `lib/widgets/`: Reusable UI components (OfflineBanner, OfflineNoCacheView)

**Provider Naming:**
- Class-based providers end with descriptor: `AuthSession`, `BandsListData`, `BandDetailData`, `ThemeController`
- Function-based providers end with descriptor: `publicApiProvider`, `apiClientProvider`, `tokenStorageProvider`
- Generated code placed in `.g.dart` files via riverpod_generator

**Exports and Visibility:**
- No re-exports; each file stands alone
- Private classes/enums/methods prefixed with underscore
- Public API (classes, methods, exceptions) left unprefixed
- Test doubles placed in test files, not in lib/

## Patterns and Principles

**Reactive State (Riverpod):**
- State managed via @riverpod class notifiers (e.g., `AuthSession extends _$AuthSession`)
- UI watches via `ref.watch(provider)` for reactive updates
- Mutators invoked via `ref.read(provider.notifier).method()`
- AsyncData/AsyncError/AsyncLoading for async data providers

**Offline-First:**
- Online-first fetch pattern: attempt network first, fall back to cache on error, throw `OfflineNoCacheException` if offline and no cache
- Comments reference design document: "(D-01/D-03/D-06)" for offline requirements
- Version counters prevent stale responses from reverting local mutations (WR-02 gap closure)

**Deduplication:**
- Refresh deduplication: `_inFlightRefresh ??= _doRefresh().whenComplete(() => _inFlightRefresh = null)`
- Reentrancy guard: `_loggingOut` flag prevents recursive logout on 403 during logout call

**Decoupling:**
- Callback injection: `getToken` and `onUnauthorized` passed to ApiClient, decoupling from AuthSession
- ProviderContainer overrides in tests allow full control of dependencies without service locators

## Static Analysis

**Running Checks:**
```bash
flutter analyze              # Run all lints and analyzer checks
flutter format lib/          # Auto-format all Dart files
flutter test                 # Run all tests
```

**Fixes Applied Automatically:**
- `flutter format` enforces indentation (2 spaces), line breaks, const usage
- `flutter analyze` catches unused imports, type mismatches, lint violations

---

*Convention analysis: 2026-08-25*
