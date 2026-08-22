# Phase 6: Foundation Info & Settings Polish - Pattern Map

**Mapped:** 2026-08-20
**Files analyzed:** 8 primary (spec, API method, password form, 5 screens)
**Analogs found:** 8 / 8 (100% match rate)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/api/publicapi.yml` | config | spec-update | N/A (schema file) | — |
| `lib/api/public_api.dart` (add `changePassword` method) | service | request-response | `public_api.dart` — existing `login()` / `register()` methods | exact |
| `lib/features/profile/{change_password_form.dart \| profile_screen.dart}` | component | request-response | `lib/features/auth/login_screen.dart` — form validation + error handling | exact |
| `lib/features/tracks/track_list_screen.dart` | component | display | `lib/features/tracks/track_list_screen.dart` — existing list with trailing widget | exact |
| `lib/features/tracks/track_detail_screen.dart` | component | display | `lib/features/tracks/track_detail_screen.dart` — existing detail screen | exact |
| `lib/features/setlists/setlist_list_screen.dart` | component | display | `lib/features/setlists/setlist_list_screen.dart` — existing list with trailing widget | exact |
| `lib/features/setlists/setlist_detail_screen.dart` | component | display | `lib/features/setlists/setlist_detail_screen.dart` — existing detail screen | exact |
| `lib/features/bands/bands_screen.dart` | component | display | `lib/features/bands/bands_screen.dart` — existing list + `band_detail_screen.dart` for ownership helpers | exact |

---

## Pattern Assignments

### `lib/api/publicapi.yml` (config, spec-update)

**Scope:** OpenAPI 3.0 YAML schema file defining request/response shapes.

**Changes:**
1. Add `currentPassword` field to `ChangeUserPasswordRequestBody` schema
2. Add `key` (optional String) to `TrackListItem` schema
3. Add `eventLocation` (optional String) to `SetlistListItem` schema
4. Add `ownerId` (String, required) to `BandListItem` schema

**Pattern:** All four additions are client-first extensions (spec precedes backend implementation). Fields are either optional or added to existing request bodies. No changes to response envelope or cache keys.

**Example (schema fragment):**
```yaml
ChangeUserPasswordRequestBody:
  type: object
  required:
    - password
  properties:
    currentPassword:
      type: string
      description: Current password (client-first field, for validation)
    password:
      type: string
      description: New password

TrackListItem:
  type: object
  properties:
    # ... existing id, title, artist, durationSeconds
    key:
      type: string
      nullable: true
      description: Musical key (e.g., 'C', 'Cm', 'F#')
```

---

### `lib/api/public_api.dart` (service, request-response)

**Analog:** `lib/api/public_api.dart` (existing `login()` and `register()` methods)

**Add method signature:**

```dart
/// Changes the current user's password. Requires authentication (valid token).
/// Returns nothing on success (204 no content).
///
/// Throws [ApiException] on error:
/// - 400 + code `invalid_input` → current password is incorrect
/// - Other 4xx/5xx → see exception message
Future<void> changePassword({
  required String currentPassword,
  required String newPassword,
}) async {
  await _client.send(
    'POST',
    '/api/me/password',
    body: {
      'currentPassword': currentPassword,
      'password': newPassword,
    },
  );
}
```

**Follows pattern from login/register (lines 29-40, 14-25):**
- Method is async and returns a Future
- Takes required named parameters
- Calls `_client.send()` with HTTP verb, path, and body
- Throws ApiException on non-2xx response (ApiClient handles this)
- No response parsing needed (endpoint returns 204 no content)

**Key differences from login:**
- Requires authentication (`_client.send` automatically injects token)
- Expects 400 + `invalid_input` code on wrong current password (not 401)
- Returns `void` (no token or id returned)

---

### `lib/features/profile/change_password_form.dart` or integrated into `profile_screen.dart` (component, request-response)

**Analog:** `lib/features/auth/login_screen.dart` (lines 1-180)

**Overall pattern:**
- ConsumerStatefulWidget with local form state management
- TextFormField widgets with validators
- Form submission with error handling
- Loading state during async call

**Imports pattern** (lines 1-5 from login_screen.dart):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';  // Or public_api provider
```

**Class structure and lifecycle** (lines 9-30 from login_screen.dart):
```dart
class ChangePasswordForm extends ConsumerStatefulWidget {
  const ChangePasswordForm({super.key});

  @override
  ConsumerState<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
```

**Form submission pattern** (lines 32-80 from login_screen.dart, adapted):
```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isSubmitting = true;
    _errorMessage = null;
  });

  final currentPassword = _currentPasswordController.text;
  final newPassword = _newPasswordController.text;

  try {
    final publicApi = ref.read(publicApiProvider);
    await publicApi.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      Navigator.of(context).pop();
    }
  } on ApiException catch (e) {
    if (e.statusCode == 400 && e.code == 'invalid_input') {
      setState(() => _errorMessage = 'Current password is incorrect');
    } else {
      setState(() => _errorMessage = e.message);
    }
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
```

**TextFormField validators** (lines 116-141 from login_screen.dart):
```dart
TextFormField(
  controller: _currentPasswordController,
  obscureText: true,
  decoration: const InputDecoration(
    labelText: 'Current password',
    border: OutlineInputBorder(),
  ),
  validator: (value) => (value?.isEmpty ?? true) ? 'Required' : null,
),
TextFormField(
  controller: _newPasswordController,
  obscureText: true,
  decoration: const InputDecoration(
    labelText: 'New password',
    hintText: 'At least 8 characters',
    border: OutlineInputBorder(),
  ),
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Required';
    if ((value?.length ?? 0) < 8) return 'At least 8 characters';
    return null;
  },
),
TextFormField(
  controller: _confirmPasswordController,
  obscureText: true,
  decoration: const InputDecoration(
    labelText: 'Confirm new password',
    border: OutlineInputBorder(),
  ),
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Required';
    if (value != _newPasswordController.text) {
      return "Passwords don't match";
    }
    return null;
  },
),
```

**Error display and submit button** (lines 142-161 from login_screen.dart):
```dart
if (_errorMessage != null) ...[
  const SizedBox(height: 16),
  Text(
    _errorMessage!,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
      : const Text('Change password'),
),
```

---

### `lib/features/tracks/track_list_screen.dart` (component, display)

**Analog:** `lib/features/tracks/track_list_screen.dart` (existing file, lines 51-114)

**Change location:** ListTile trailing widget (currently line 102)

**Current pattern** (line 102):
```dart
trailing: Text(durationSeconds?.asMinutesSeconds ?? '—'),
```

**New pattern (icon row with key + duration):**

Replace trailing with:
```dart
trailing: SizedBox(
  width: 130,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (track['key'] != null) ...[
        Icon(Icons.music_note, size: 14),
        const SizedBox(width: 3),
        Text(
          track['key'] as String,
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 8),
      ],
      if (durationSeconds != null) ...[
        Icon(Icons.timer, size: 14),
        const SizedBox(width: 3),
        Text(
          durationSeconds.asMinutesSeconds,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ],
  ),
),
```

**Key pattern details:**
- Defensively cast: `track['key'] as String?` returns null if missing (not crash)
- Guard with `if (track['key'] != null)` before rendering icon
- Use `SizedBox(width: 130)` to constrain on narrow screens (per RESEARCH.md Pitfall 2)
- Icons: `Icons.music_note` (14px), `Icons.timer` (14px)
- Text: 11px font, maxLines 1 with ellipsis on key field
- Spacing: 3px after icon, 8px between icon pairs
- Row uses `mainAxisSize: MainAxisSize.min` to fit content, not expand greedily

**Reuses:**
- `DurationFormatting.asMinutesSeconds` extension from `track_formatting.dart` (line 9, already imported)

---

### `lib/features/tracks/track_detail_screen.dart` (component, display)

**Analog:** `lib/features/tracks/track_detail_screen.dart` (lines 67-124)

**Change location:** Content display area within `_buildContent` (lines 67-124)

**Current detail display** (lines 97-104):
```dart
if (key != null) ...[
  const SizedBox(height: 16),
  Text('Key: $key'),
],
if (notes != null && notes.isNotEmpty) ...[
  const SizedBox(height: 16),
  Text('Notes: $notes'),
],
```

**Add icon rows (option: inline icons with labels):**

Replace with icon row pattern:
```dart
if (key != null) ...[
  const SizedBox(height: 16),
  Row(
    children: [
      Icon(Icons.music_note, size: 16),
      const SizedBox(width: 4),
      Text('Key: $key'),
    ],
  ),
],
if (notes != null && notes.isNotEmpty) ...[
  const SizedBox(height: 16),
  Row(
    children: [
      Icon(Icons.description, size: 16),
      const SizedBox(width: 4),
      Expanded(child: Text('Notes: $notes')),
    ],
  ),
],
```

**Or alternatively: compact icon row as per RESEARCH.md pattern:**

```dart
if (key != null || notes != null) ...[
  const SizedBox(height: 16),
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (key != null) ...[
        Icon(Icons.music_note, size: 16),
        const SizedBox(width: 4),
        Text(key),
        const SizedBox(width: 12),
      ],
      if (notes != null && notes.isNotEmpty) ...[
        Icon(Icons.description, size: 16),
        const SizedBox(width: 4),
        Expanded(child: Text(notes)),
      ],
    ],
  ),
],
```

**Icon choices:**
- Key: `Icons.music_note` (musical note icon)
- Notes: `Icons.description` or `Icons.notes`

---

### `lib/features/setlists/setlist_list_screen.dart` (component, display)

**Analog:** `lib/features/setlists/setlist_list_screen.dart` (lines 51-111)

**Change location:** ListTile trailing widget (currently line 99)

**Current pattern** (line 99):
```dart
trailing: Text(tracksAndDuration(tracksCount, durationSeconds)),
```

**New pattern (icon row with location + duration):**

Replace trailing with:
```dart
trailing: SizedBox(
  width: 140,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (setlist['eventLocation'] != null) ...[
        Icon(Icons.location_on, size: 14),
        const SizedBox(width: 3),
        Text(
          setlist['eventLocation'] as String,
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 8),
      ],
      if (durationSeconds != null) ...[
        Icon(Icons.timer, size: 14),
        const SizedBox(width: 3),
        Text(
          durationSeconds.asMinutesSeconds,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ],
  ),
),
```

**Key pattern details:**
- Defensively cast: `setlist['eventLocation'] as String?`
- Guard with `if (setlist['eventLocation'] != null)` before rendering
- Use `SizedBox(width: 140)` for location + duration combo (wider than key-only)
- Icons: `Icons.location_on` (14px), `Icons.timer` (14px)
- Text: 11px font, maxLines 1 with ellipsis on location
- Spacing: 3px after icon, 8px between icon pairs

**Reuses:**
- `DurationFormatting.asMinutesAndSeconds` extension from `setlist_formatting.dart` (line 7)
- Or switch to `asMinutesSeconds` from track_formatting to match track list style (planner's choice)

---

### `lib/features/setlists/setlist_detail_screen.dart` (component, display)

**Analog:** `lib/features/setlists/setlist_detail_screen.dart` (existing detail screen structure)

**Pattern:** Similar to track detail screen, add location + duration icons to detail content area.

**Expected additions to detail display:**
```dart
if (setlist['eventLocation'] != null) ...[
  const SizedBox(height: 16),
  Row(
    children: [
      Icon(Icons.location_on, size: 16),
      const SizedBox(width: 4),
      Text('Location: ${setlist['eventLocation']}'),
    ],
  ),
],
if (durationSeconds != null) ...[
  const SizedBox(height: 16),
  Row(
    children: [
      Icon(Icons.timer, size: 16),
      const SizedBox(width: 4),
      Text('Duration: ${durationSeconds.asMinutesAndSeconds}'),
    ],
  ),
],
```

**Icon choices:**
- Location: `Icons.location_on`
- Duration: `Icons.timer` or `Icons.schedule`

---

### `lib/features/bands/bands_screen.dart` (component, display)

**Analog:** `lib/features/bands/bands_screen.dart` (list pattern, lines 108-125) + `lib/features/bands/band_detail_screen.dart` (ownership helpers, lines 29-43)

**Change location:** ListTile trailing widget (currently line 117)

**Current pattern** (lines 114-123):
```dart
ListTile(
  leading: BandAvatar(bandName: name),
  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.of(context).push(...),
)
```

**New pattern (with role badge and member count):**

Import ownership helpers from band_detail_screen (if not already imported):
```dart
import 'band_detail_screen.dart';
```

Modify ListTile:
```dart
ListTile(
  leading: BandAvatar(bandName: name),
  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
  subtitle: Text('${band['membersCount'] as int} members'),
  trailing: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (band['ownerId'] != null) ...[
          Chip(
            label: Text(
              _isCurrentUserOwner(ref, band['ownerId'] as String)
                  ? 'Owner'
                  : 'Member',
              style: const TextStyle(fontSize: 12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(width: 8),
        ],
        const Icon(Icons.chevron_right),
      ],
    ),
  ),
  onTap: () => Navigator.of(context).push(...),
)
```

**Ownership status helper** (add to BandsScreen class, or extract to shared utility):

```dart
bool _isCurrentUserOwner(WidgetRef ref, String ownerId) {
  final profileAsync = ref.watch(profileDataProvider);
  return profileAsync.maybeWhen(
    data: (profile) => (profile['id'] as String?) == ownerId,
    orElse: () => false,
  );
}
```

**Alternative: Reuse helpers directly from BandDetailScreen:**

```dart
trailing: Padding(
  padding: const EdgeInsets.symmetric(vertical: 8.0),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (band['ownerId'] != null) ...[
        Chip(
          label: Text(
            BandDetailScreen._isOwner(
              ref.watch(profileDataProvider).valueOrNull?['id'] as String?,
              band['ownerId'] as String,
            )
                ? 'Owner'
                : 'Member',
            style: const TextStyle(fontSize: 12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        const SizedBox(width: 8),
      ],
      const Icon(Icons.chevron_right),
    ],
  ),
),
```

**Key pattern details:**
- `membersCount` already exists on `BandListItem` (no change needed, just display)
- `ownerId` is a new field on `BandListItem`; defensively cast: `band['ownerId'] as String?`
- Guard with `if (band['ownerId'] != null)` before rendering badge
- Ownership check: compare current user id (from `profileDataProvider`) to `ownerId`
- Render "Owner" if match, "Member" if not, skip badge entirely if `ownerId` null
- Chip styling: 12px text, symmetric horizontal padding
- Row spacing: 8px between chip and chevron icon

**Reuses:**
- `BandDetailScreen._isOwner()` static helper (band_detail_screen.dart, lines 29-30)
- `profileDataProvider` Riverpod provider (already injected in context)

---

## Shared Patterns

### Form Validation Pattern (Password Change)

**Source:** `lib/features/auth/login_screen.dart` (lines 116-141)

**Apply to:** ChangePasswordForm and any similar forms

Follows Flutter's built-in Form + TextFormField pattern:
- Wrap in `Form(key: _formKey, child: Column(...))`
- Use `TextFormField` with `validator` callback
- Call `_formKey.currentState!.validate()` before submit
- Validators return null (valid) or error string (invalid)
- For confirm password, validate against another field:
  ```dart
  validator: (value) {
    if (value != _newPasswordController.text) {
      return "Passwords don't match";
    }
    return null;
  }
  ```

### API Error Handling Pattern (Authenticated Endpoints)

**Source:** `lib/features/auth/login_screen.dart` (lines 44-79) + `lib/api/api_exception.dart`

**Apply to:** ChangePasswordForm submit logic

Pattern for catching and translating API errors:
```dart
try {
  await publicApi.changePassword(currentPassword: curr, newPassword: new);
  // Success: show snackbar, navigate back
} on ApiException catch (e) {
  if (e.statusCode == 400 && e.code == 'invalid_input') {
    setState(() => _errorMessage = 'Current password is incorrect');
  } else {
    setState(() => _errorMessage = e.message);
  }
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```

**Specifics:**
- Catch `ApiException` (not generic `Exception`)
- Inspect `statusCode` and `code` fields for specific error types
- Translate code into user-friendly message
- Fall back to `e.message` for unexpected errors
- Always clear `_isSubmitting` in finally block, checking `mounted` first

### Icon Row Display Pattern (List Trailing Widgets)

**Source:** RESEARCH.md Code Examples § "Icon Row on Track List" (lines 474-502)

**Apply to:** TrackListScreen, SetlistListScreen list trailing widgets

Pattern for displaying optional metadata as icon + text pairs:
```dart
trailing: SizedBox(
  width: <width>,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      if (<field1> != null) ...[
        Icon(<icon1>, size: 14),
        const SizedBox(width: 3),
        Text(<field1>, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 8),
      ],
      if (<field2> != null) ...[
        Icon(<icon2>, size: 14),
        const SizedBox(width: 3),
        Text(<field2>, style: const TextStyle(fontSize: 11)),
      ],
    ],
  ),
)
```

**Specifics:**
- SizedBox width constrains on narrow screens (prevent overflow)
- Defensive null-check: `field as Type?` in extraction, `if (field != null)` in rendering
- Icon size: 14px (smaller than detail screens' 16px)
- Text size: 11px (smaller than default 14px)
- Spacing: 3px icon-to-text, 8px pair-to-pair
- Row: `mainAxisSize: MainAxisSize.min`, `mainAxisAlignment: MainAxisAlignment.end`

### Ownership Status Tri-State Pattern

**Source:** `lib/features/bands/band_detail_screen.dart` (lines 29-43)

**Apply to:** BandsScreen role badge display

Pattern for safe ownership check with loading state:
```dart
static bool _isOwner(String? currentUserId, String? ownerId) =>
    currentUserId != null && ownerId != null && currentUserId == ownerId;

static bool? _ownershipStatus(
  AsyncValue<Map<String, dynamic>> profileAsync,
  String? ownerId,
) {
  return profileAsync.maybeWhen(
    data: (profile) => _isOwner(profile['id'] as String?, ownerId),
    orElse: () => null,
  );
}
```

**Specifics:**
- `_isOwner()` returns false (not null) if either id is null — safe boolean
- `_ownershipStatus()` returns tri-state: `true` (owner), `false` (member, resolved), `null` (loading)
- When rendering, guard on `isOwner != null` to avoid showing "Member" during profile load
- Pattern prevents flicker (null → false → true) that confuses users

---

## No Analog Found

All files have clear existing analogs in the codebase. No gaps identified.

---

## Metadata

**Analog search scope:** 
- Searched: `lib/features/auth/`, `lib/features/tracks/`, `lib/features/setlists/`, `lib/features/bands/`, `lib/features/profile/`, `lib/api/`
- Framework: Flutter + Riverpod (both established in codebase)
- Pattern maturity: All analogs are proven, actively used patterns from v1.0

**Pattern extraction date:** 2026-08-20

**Key patterns identified:**
1. **Form submission pattern** — TextFormField + validator + ApiException catch (proven in LoginScreen)
2. **Icon row composition** — Optional fields, null-safety, responsive sizing (new pattern, established in research)
3. **Ownership tri-state** — Safe boolean checks with loading state guard (proven in BandDetailScreen)
4. **List trailing widgets** — Material design icons + text pairs with proper spacing (new pattern, follows Material conventions)
5. **API method shape** — Named parameters, async, throws ApiException (proven across PublicApi)
6. **Client-first spec evolution** — Defensive casting, graceful degradation when fields absent (precedent: SETL-12)

**Confidence:** HIGH — All patterns reuse proven infrastructure (Flutter, Riverpod, ApiClient); no novel architectures or libraries needed.
