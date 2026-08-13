# Coding Conventions

**Analysis Date:** 2026-08-13

## Naming Patterns

**Files:**
- Dart files use snake_case: `auth_session.dart`, `api_client.dart`, `token_storage.dart`
- Screen files end with `_screen`: `login_screen.dart`, `home_screen.dart`, `bands_screen.dart`
- Directories group by feature or layer: `lib/features/`, `lib/api/`, `lib/theme/`, `lib/navigation/`, `lib/config/`

**Classes:**
- Use PascalCase for all classes: `AuthSession`, `ApiClient`, `TokenStorage`, `AuthGate`, `LoginScreen`
- Internal State classes prefixed with underscore: `_AuthGateState`, `_LoginScreenState`, `_RootScaffoldState`
- Exception classes named explicitly: `ApiException`
- Enum cases use lowercase: `AuthStatus.unknown`, `AuthStatus.authenticated`, `AuthStatus.unauthenticated`, `_AuthMode.login`, `_AuthMode.signUp`

**Functions and Methods:**
- Use camelCase for all functions and methods: `signIn()`, `signOut()`, `restore()`, `register()`, `login()`, `send()`, `setThemeMode()`
- Private methods prefixed with underscore: `_submit()`, `_toggleMode()`
- Named parameters preferred for clarity: `register(username: username, password: password)`

**Variables:**
- Use camelCase for local variables and properties: `_token`, `_status`, `_storage`, `_errorMessage`, `_isSubmitting`, `baseUrl`, `authSession`
- Private/internal variables prefixed with underscore: `_httpClient`, `_formKey`, `_usernameController`, `_passwordController`
- Static constants use UPPER_SNAKE_CASE: `_tokenKey = 'auth_token'` (when stored as String constant)

**Constants:**
- Configuration values exposed as static constants: `AppConfig.apiBaseUrl`
- Private constants prefixed with underscore: `const _tokenKey = 'auth_token'`

## Code Style

**Formatting:**
- Dart's built-in formatter (dartfmt) is the standard - apply via `flutter analyze` and `flutter format`
- Line length: follows Dart conventions (typically 80-120 characters)
- Indentation: 2 spaces (Flutter default)
- No explicit import/export aliases - use full relative paths

**Linting:**
- Tool: `flutter_lints` 6.0.0 (extends `package:flutter_lints/flutter.yaml`)
- Config: `analysis_options.yaml` at repository root
- Run with: `flutter analyze`
- Default flutter_lints rules are used with no overrides

**Const Constructors:**
- All Widget constructors use `const` when possible: `const HomeScreen({super.key})`, `const CadenceApp({super.key, ...})`
- Improves performance and tree stability

## Import Organization

**Order:**
1. Dart imports: `import 'dart:convert';`, `import 'dart:async';`
2. Flutter imports: `import 'package:flutter/material.dart';`, `import 'package:flutter/foundation.dart'`
3. Package imports: `import 'package:http/http.dart' as http;`, `import 'package:flutter_secure_storage/flutter_secure_storage.dart'`
4. Relative imports: `import '../api/auth_session.dart';`, `import 'login_screen.dart';`

**Path Aliases:**
- Not used in current codebase
- All imports use explicit relative paths from root: `import 'package:cadence/...'` for package-relative, or relative `../` paths

**Example from `lib/app.dart`:**
```dart
import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/auth_session.dart';
import 'api/public_api.dart';
import 'api/token_storage.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'theme/theme_controller.dart';
```

## Error Handling

**Exception Types:**
- Use `ApiException` for HTTP-level errors with statusCode, code, and message
- Can be constructed manually or via factory: `ApiException.fromResponse(response)`
- Implements `Exception` interface

**Error Flow:**
- Exceptions caught at the UI layer in screen state (`LoginScreen._submit()`)
- Specific status codes handled with custom messages: 403 (unauthorized), 401 (invalid credentials), 400 (already_exists)
- Re-throw pattern used to propagate unexpected errors up the stack
- Error state stored in widget state: `_errorMessage` displayed to user

**Pattern Example from `lib/features/auth/login_screen.dart`:**
```dart
try {
  await widget.publicApi.register(username: username, password: password);
} on ApiException catch (e) {
  if (e.statusCode == 400 && e.code == 'already_exists') {
    throw ApiException(...);  // Convert to user-friendly message
  }
  rethrow;
}
```

**Fallback Handling:**
- JSON parsing failures silently caught and fallback to generic message: `catch (_) { ... }`
- Non-empty checks before parsing: `if (response.body.isNotEmpty)`

## Logging

**Framework:** No explicit logging framework (console use only via `print()`)

**Patterns:**
- Current codebase does not use `print()` for debugging
- Console/debug output not visible in final product

**Recommendation:** If logging becomes needed, consider `package:logger` or `package:talker`

## Comments

**When to Comment:**
- Document public API behavior with doc comments (triple slash)
- Explain "why" rather than "what" in complex logic
- Mark edge cases and platform-specific behaviors
- Document deprecated patterns

**JSDoc/TSDoc (Dart Doc):**
- Use `///` for public API documentation on classes, functions
- Include examples and parameter descriptions when behavior is non-obvious
- Document factory constructors and notable parameters

**Example from `lib/api/api_client.dart`:**
```dart
/// Thin HTTP wrapper around `lib/api/publicapi.yml`.
///
/// Attaches the session cookie the API expects (`cadencesession`, see
/// `components.securitySchemes.cookieAuth` in the spec) to authenticated
/// requests, and signs the user out whenever a request comes back with a
/// 403, since that means the session is no longer valid.
```

**Example from `lib/api/public_api.dart`:**
```dart
/// Returns the new user's id. Note the API doesn't log the user in on
/// register, so callers should follow up with [login].
```

## Function Design

**Size:** Functions generally kept under 30-40 lines for readability

**Parameters:**
- Use named parameters for multi-parameter functions
- Required parameters marked with `required` keyword
- Constructor parameters follow: `{super.key, required this.field}`
- Type annotations always explicit

**Return Values:**
- Functions return typed values (not `dynamic`)
- Futures used for async operations: `Future<String?>`, `Future<void>`
- Nullable returns marked with `?`: `String?`, `Future<Map<String, dynamic>?>`

**Example from `lib/api/api_client.dart`:**
```dart
Future<Map<String, dynamic>?> send(
  String method,
  String path, {
  Map<String, dynamic>? body,
  bool requireAuth = true,
}) async { ... }
```

## Module Design

**Exports:**
- No barrel files (`index.dart` re-exports) used in current codebase
- Each file imports directly what it needs from other modules

**File Organization:**
- Single responsibility: each file contains one main class or tightly related set of classes
- Related functionality grouped in directories: `lib/api/`, `lib/features/auth/`, `lib/theme/`

**Layer Pattern:**
- **API Layer** (`lib/api/`): HTTP client, authentication, token storage, exceptions
- **Features** (`lib/features/`): Screen components and feature-specific UI logic
- **Config** (`lib/config/`): Application-wide configuration (e.g., API base URL)
- **Theme** (`lib/theme/`): Theming and appearance logic
- **Navigation** (`lib/navigation/`): Navigation structure and root layout

**Example from `lib/api/public_api.dart`:**
```dart
class PublicApi {
  PublicApi(this._client);
  final ApiClient _client;
  
  Future<String> register({required String username, required String password}) async { ... }
  Future<void> login({required String username, required String password}) async { ... }
}
```

---

*Convention analysis: 2026-08-13*
