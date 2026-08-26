# Phase 14: API Error Localization - Pattern Map

**Mapped:** 2026-08-26
**Files analyzed:** 22 (1 extension target, 2 ARB files, 2 existing overrides, 17 simple catch sites)
**Analogs found:** 22 / 22 (100% coverage)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/api/api_exception.dart` | exception extension | utility | `lib/features/auth/login_screen.dart:52-77` (conditional error wrapping) | pattern-match |
| `lib/l10n/app_en.arb` | localization config | static | `lib/l10n/app_en.arb:68-79` (existing `commonX` error messages) | exact |
| `lib/l10n/app_ru.arb` | localization config | static | `lib/l10n/app_ru.arb:68-79` (existing Russian error messages) | exact |
| `lib/features/auth/login_screen.dart` | screen with override | request-response | self (already has conditional code + statusCode checks) | self-analog |
| `lib/features/profile/change_password_screen.dart` | screen with override | request-response | self (already has conditional code check) | self-analog |
| `lib/features/bands/create_band_screen.dart` | screen catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/bands/edit_band_screen.dart` | screen catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/bands/confirm_leave_band_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/bands/confirm_delete_band_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/bands/confirm_remove_member_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/bands/confirm_rotate_invite_code_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/bands/confirm_transfer_ownership_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/bands/join_band_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/tracks/create_track_screen.dart` | screen catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/tracks/edit_track_screen.dart` | screen catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/tracks/confirm_delete_track_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/setlists/create_setlist_screen.dart` | screen catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/setlists/edit_setlist_screen.dart` | screen catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/setlists/setlist_detail_screen.dart` | screen catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/setlists/confirm_delete_setlist_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |
| `lib/features/setlists/add_setlist_tracks_dialog.dart` | dialog catch site | request-response | `lib/features/auth/login_screen.dart:78-79` (simple catch) | exact |

## Pattern Assignments

### `lib/api/api_exception.dart` (exception extension, utility)

**Analog:** `lib/features/auth/login_screen.dart` (conditional error wrapping pattern, lines 52-77)

**Existing ApiException class structure** (lines 5-32):
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

**Error override pattern** (from `LoginScreen` lines 52-59, shows the wrapping pattern this extension will replace):
```dart
on ApiException catch (e) {
  if (e.statusCode == 400 && e.code == 'already_exists') {
    throw ApiException(
      statusCode: e.statusCode,
      code: e.code,
      message: l10n.loginUsernameTakenError,
    );
  }
  rethrow;
}
```

**Imports for extension target** (lines 1-3):
```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
```

---

### `lib/l10n/app_en.arb` (localization config, static)

**Analog:** `lib/l10n/app_en.arb` (existing `commonX` shared-message pattern, lines 66-79)

**Existing shared-error pattern** (lines 68-79):
```json
"commonRetry": "Retry",
"commonConnectionError": "Please check your connection and try again.",
"commonRequiresConnection": "Requires connection",
...
"commonCancel": "Cancel",
"commonDelete": "Delete",
"commonSomethingWentWrong": "Something went wrong. Please try again.",
```

**Existing screen-specific overrides** (show the tone/style to match for generic defaults):
```json
"loginUsernameTakenError": "This username is already taken",
"loginInvalidCredentialsError": "Invalid credentials",
"changePasswordIncorrectCurrentError": "Current password is incorrect",
```

**Tone reference** — terse, literal, no softening/apologetic phrasing per D-02.

---

### `lib/l10n/app_ru.arb` (localization config, static)

**Analog:** `lib/l10n/app_ru.arb` (existing `commonX` shared-message pattern, lines 66-79)

**Existing shared-error pattern** (lines 68-79):
```json
"commonRetry": "Повторить",
"commonConnectionError": "Проверьте подключение к интернету и попробуйте снова.",
"commonRequiresConnection": "Требуется подключение",
...
"commonCancel": "Отмена",
"commonDelete": "Удалить",
"commonSomethingWentWrong": "Что-то пошло не так. Попробуйте ещё раз.",
```

**Existing screen-specific overrides** (Russian equivalents):
```json
"loginUsernameTakenError": "Это имя пользователя уже занято",
"loginInvalidCredentialsError": "Неверные учётные данные",
"changePasswordIncorrectCurrentError": "Current password is incorrect", [sic — to be filled in]
```

**Tone reference** — direct, literal Russian phrasing matching existing error copy.

---

### `lib/features/auth/login_screen.dart` (screen with existing overrides, request-response)

**Analog:** self (contains both existing override patterns for `already_exists` and `loginInvalidCredentialsError`)

**Imports pattern** (lines 1-6):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
```

**Existing `already_exists` override (registration)** (lines 49-60):
```dart
try {
  await publicApi.register(username: username, password: password);
} on ApiException catch (e) {
  if (e.statusCode == 400 && e.code == 'already_exists') {
    throw ApiException(
      statusCode: e.statusCode,
      code: e.code,
      message: l10n.loginUsernameTakenError,
    );
  }
  rethrow;
}
```

**Existing `401` statusCode override (login)** (lines 68-77):
```dart
on ApiException catch (e) {
  if (e.statusCode == 401) {
    throw ApiException(
      statusCode: e.statusCode,
      code: e.code,
      message: l10n.loginInvalidCredentialsError,
    );
  }
  rethrow;
}
```

**Fallback catch for all ApiExceptions** (lines 78-79):
```dart
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);
}
```

**Error message display pattern** (lines 146-154):
```dart
if (_errorMessage != null) ...[
  const SizedBox(height: 16),
  Text(
    _errorMessage!,
    style: TextStyle(
      color: Theme.of(context).colorScheme.error,
    ),
  ),
],
```

---

### `lib/features/profile/change_password_screen.dart` (screen with existing override, request-response)

**Analog:** self (contains existing override pattern for `invalid_input`)

**Imports pattern** (lines 1-6):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
```

**Existing `invalid_input` override** (lines 62-67):
```dart
on ApiException catch (e) {
  setState(() {
    _errorMessage = (e.statusCode == 400 && e.code == 'invalid_input')
        ? l10n.changePasswordIncorrectCurrentError
        : e.message;
  });
}
```

**Error message display pattern** (lines 137-143):
```dart
if (_errorMessage != null) ...[
  const SizedBox(height: 16),
  Text(
    _errorMessage!,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  ),
],
```

---

### Simple Catch Sites (17 screens/dialogs: CreateBandScreen, EditBandScreen, ConfirmLeaveBandDialog, etc.)

**Analog:** `lib/features/auth/login_screen.dart` (fallback catch pattern, lines 78-79)

**Imports pattern** (common across all catch sites):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';  // or band/track/setlist providers
```

**Basic ApiException catch pattern** (from `CreateBandScreen` lines 53-59):
```dart
try {
  final response = await ref.read(publicApiProvider).createBand(name: name);
  // ... success handling ...
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);
} catch (_) {
  setState(() => _errorMessage = l10n.commonSomethingWentWrong);
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```

**Basic ApiException catch pattern** (from `ConfirmLeaveBandDialog` lines 58-64):
```dart
try {
  // ... API call ...
  ref.invalidate(bandsListDataProvider);
  if (!mounted) return;
  Navigator.of(context).pop();
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);
} catch (_) {
  setState(() => _errorMessage = l10n.commonSomethingWentWrong);
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```

**Error message display pattern** (consistent across all catch sites, from `ConfirmLeaveBandDialog` lines 79-85):
```dart
if (_errorMessage != null) ...[
  const SizedBox(height: 16),
  Text(
    _errorMessage!,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  ),
],
```

---

## Shared Patterns

### ApiException Lookup via Extension

**Source:** `lib/api/api_exception.dart` + design from D-03/D-04

**Apply to:** All 22 files (extension definition + all catch sites)

**Shape** (per D-03 — extension taking `AppLocalizations` parameter):
```dart
extension ApiExceptionLocalization on ApiException {
  String localizedMessage(
    AppLocalizations l10n, {
    String? Function(String code)? codeOverride,
  }) {
    // If code is recognized and no override provided, return generic localized message
    // If codeOverride is provided and matches code, use it
    // Otherwise, fall back to e.message (raw server text) per D-05
  }
}
```

**Call shape at catch sites** (replaces `e.message`):
```dart
setState(() => _errorMessage = e.localizedMessage(l10n));
```

**Override call shape for screens with existing overrides**:
```dart
if (e.statusCode == 400 && e.code == 'already_exists') {
  // Either: use extension with codeOverride param, or use new unified error message
  // Exact mechanism: see D-04 implementation discretion
}
```

### Error Code Enum (reference from API contract)

**Source:** `lib/api/publicapi.yml` lines 655-682 (`BadRequestResponseBody`/`ErrorCode`)

**The 5 known error codes** (400 responses only, per I18N-05 requirements):
- `invalid_input`
- `not_found`
- `permission_denied`
- `operation_rejected`
- `already_exists`

### Localization Pipeline Integration

**Source:** Phase 12 infrastructure (`LocaleController`, ARB/gen-l10n pipeline)

**Apply to:** All string additions to `app_en.arb` / `app_ru.arb`

**Regeneration step** (existing Phases 12-13 pattern):
```bash
flutter gen-l10n
```

**Output files** (auto-generated, do not edit):
- `lib/generated/app_localizations.dart`
- `lib/generated/app_localizations_en.dart`
- `lib/generated/app_localizations_ru.dart`

**Live-switch behavior:** LocaleController already watches `Locale` changes; new error strings automatically re-render via `AppLocalizations.of(context)!` refresh.

### Test Strings Utility (optional extension)

**Source:** `test/test_strings.dart` (Phase 13 pattern)

**Apply if needed:** Extend `StringsExtension` if widget tests assert on new generic error messages

**Current pattern** (lines 12-27):
```dart
extension StringsExtension on WidgetTester {
  AppLocalizations get strings {
    final textFinder = find.byType(Text);
    if (textFinder.evaluate().isEmpty) {
      throw StateError('...');
    }
    return AppLocalizations.of(element(textFinder.first))!;
  }
}
```

**Usage in tests** (existing pattern):
```dart
expect(find.text(tester.strings.commonSomethingWentWrong), findsOneWidget);
```

New error strings automatically available as `tester.strings.commonInvalidInput`, etc. — no changes to utility needed.

---

## No Analog Found

None — all files have close analogs in current codebase.

---

## Metadata

**Analog search scope:** 
- `lib/api/` — exception classes, API patterns
- `lib/features/auth/`, `lib/features/bands/`, `lib/features/tracks/`, `lib/features/setlists/` — screen/dialog error handling
- `lib/l10n/` — ARB localization structure
- `test/` — test utilities
- `lib/generated/` — localization output (reference only)

**Files scanned:** 22 screens/dialogs + 2 ARB files + 1 exception class + 1 test utility

**Pattern extraction date:** 2026-08-26

**Key findings:**
- 100% of catch sites follow identical structure: `on ApiException catch (e) { setState(() => _errorMessage = e.message); }`
- All catch sites display error in error-colored Text widget, conditional on `_errorMessage != null`
- Two existing overrides (LoginScreen + ChangePasswordScreen) serve as examples of the conditional-check pattern the extension will replace
- ARB files follow flat `commonX` namespace for shared strings; tone is terse/literal per D-02
- Localization pipeline (gen-l10n) auto-generates `AppLocalizations` methods from ARB keys
