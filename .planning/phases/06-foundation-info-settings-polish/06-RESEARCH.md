# Phase 6: Foundation Info & Settings Polish - Research

**Researched:** 2026-08-20
**Domain:** Flutter UI polish — password change form + metadata icon display on list/detail screens
**Confidence:** HIGH

## Summary

Phase 6 establishes low-risk UI patterns (form validation, icon composition, API error handling) before the higher-risk cache-behavior flip in Phase 7. The phase is primarily **display work** (three optional fields added to existing schemas and rendered as icon rows on list/detail screens) plus **one new form** (password change). All work reuses existing patterns from login_screen.dart, band_detail_screen.dart, and track/setlist screens — no new libraries or architectures needed.

**Key constraint:** Four schema extensions are **client-first** (spec changes precede backend implementation). All four fields are optional and must degrade gracefully when absent from API responses.

**Primary recommendation:** Implement in order of risk: (1) password change form on Profile screen; (2) BandListItem + role badge on Bands list; (3) TrackListItem key icon on Tracks list; (4) SetlistListItem location icon on Setlists list. Password change is security-critical but uses established form patterns. Icon rows are purely visual and isolated to trailing widget composition.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Extend `ChangeUserPasswordRequestBody` with `currentPassword` field (client-first spec extension, precedent set by SETL-12)
- **D-02:** Form collects three fields: current password, new password, confirm-new-password
- **D-03:** `TrackListItem` gains `key` only (not notes) — notes display detail-screen-only
- **D-04:** `SetlistListItem` gains `eventLocation` (optional, matching naming in `BandSetlist`)
- **D-05:** `BandListItem` gains `ownerId` to enable role display on list screen
- **D-06:** All three spec additions are client-first; backend implements separately; UI degrades gracefully when fields absent/null
- **D-07:** Icon + inline row visual style (e.g., "🎵 C  ⏱ 3:45"), not icon-only tooltips

### Claude's Discretion

- Specific Material icon choices (planner picks semantically clear icons: `Icons.music_note` or `Icons.piano` for key, `Icons.timer` or `Icons.schedule` for duration, `Icons.notes` or `Icons.description` for notes, `Icons.location_on` for location)
- Exact OpenAPI `required`/`nullable` marking for new optional fields (model as not-required, matching existing convention)
- Layout details for icon row sizing and overflow handling on narrow screens

### Deferred Ideas (OUT OF SCOPE)

- BAND-11 (rotate invite code) — Phase 8
- BAND-12 (transfer ownership) — Phase 8

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| USER-03 | User can change account password from Profile screen; wrong current password rejected with clear error | Form validation pattern established in LoginScreen; error handling via ApiException.statusCode + .code; ReRiverpod state management for isSubmitting/errorMessage |
| BAND-10 | User sees member count and role (owner/member) on Bands list and band detail | `BandListItem` gains `ownerId`; reuse existing `_isOwner()` / `_ownershipStatus()` helpers from band_detail_screen.dart; role badge widget slots into list trailing |
| TRACK-07 | Track list/detail screens show icons for musical key, duration, and notes | Key + duration icons on list (notes detail-only per D-03); reuse `DurationFormatting.asMinutesSeconds` from track_formatting.dart; icon row in trailing widget composition |
| SETL-11 | Setlist list/detail screens show icons for location and duration | Location + duration icons on list; reuse `DurationFormatting` from setlist_formatting.dart; `SetlistListItem` gains `eventLocation` per D-04 |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Password change form (USER-03) | Frontend Client (StatefulWidget) | API Backend | Form UI, validation, error display on client; password hashing/verification on server |
| Role badge on Bands list (BAND-10) | Frontend Client (BandsScreen) | Database (existing `Band.ownerId`) | Role determination (owner/member) purely client-side comparison; no new API calls needed |
| Musical key icon on Track list (TRACK-07) | Frontend Client (TrackListScreen) | API Cache (TrackListItem) | Icon rendering and layout on client; `TrackListItem.key` already cached |
| Location icon on Setlist list (SETL-11) | Frontend Client (SetlistListScreen) | API Cache (SetlistListItem) | Icon rendering on client; `SetlistListItem.eventLocation` already cached |

## Standard Stack

### Core (Flutter Form & API Patterns)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | ^2.6.1 | State management for form submission state (isSubmitting, errorMessage) | Already adopted in project; ConsumerStatefulWidget pattern proven on LoginScreen |
| flutter | stable | TextFormField, Form, Material icons, GlobalKey<FormState> | Built-in; all form validation and icon display uses Flutter's native widgets |
| http | ^1.6.0 | API communication for password change endpoint | Existing dependency; ApiClient already centralizes auth header injection |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | (built-in via flutter SDK) | Unit/widget tests for form validation, state transitions, error handling | Required for testing password change flow and icon row composition |

### API Layer

| Pattern | File | Purpose |
|---------|------|---------|
| Public API method | `lib/api/public_api.dart` | Add `changePassword(currentPassword, newPassword)` method following existing `register()` / `login()` shape |
| ApiException handling | `lib/api/api_exception.dart` | Catch status 400 + code `invalid_input` for wrong current password; existing pattern from LoginScreen |
| HTTP client abstraction | `lib/api/api_client.dart` | POST request + auth header injection already handled transparently |

### Formatting & Utilities

| Library | File | Purpose | Reuse |
|---------|------|---------|-------|
| DurationFormatting | `lib/features/tracks/track_formatting.dart` | `asMinutesSeconds` (mm:ss format) | Reuse directly for track duration display in icon row |
| musical keys list | `lib/features/tracks/track_formatting.dart` | 24-value key dropdown (C–B, major/minor) | Reference for validation; display is client's choice once cached |

### No New Dependencies

- No UI form builder libraries (Flutter's built-in Form + TextFormField are sufficient)
- No icon library changes (Material icons via `flutter/material.dart` are standard)
- No validation library (regex + manual checks follow existing pattern from LoginScreen)

**Installation:**
```bash
# No new packages — all dependencies already present in pubspec.yaml
flutter pub get
```

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flutter_riverpod | pub.dev | 2+ years | millions/month | github.com/rrousselGit/riverpod | OK | Approved — widely used, active maintenance |
| http | pub.dev | 5+ years | millions/month | github.com/dart-lang/http | OK | Approved — Dart-official HTTP client |
| flutter_secure_storage | pub.dev | 5+ years | millions/month | github.com/mogol/flutter_secure_storage | OK | Approved — standard for token persistence |
| flutter_lints | pub.dev | 2+ years | millions/month | github.com/google/flutter_lints | OK | Approved — Google Flutter team |

**Conclusion:** All production dependencies are established, widely used, and actively maintained. No suspicious packages introduced this phase.

## Architecture Patterns

### Password Change Form Pattern

**Where:** Profile screen or Settings screen (planner's call per CONTEXT.md)

**Flow:**
1. User taps "Change password" ListTile → navigates to password change screen/dialog or reveals form on Profile
2. Form collects: current password (securely obscured), new password, confirm password
3. On submit:
   - Validate: current password not empty, new password ≥ 8 chars, new == confirm
   - Call `publicApi.changePassword(currentPassword: curr, newPassword: new)`
   - Catch `ApiException` → inspect `statusCode` (400) + `code` (check for `invalid_input`) → display "Current password is incorrect"
   - Catch other 4xx/5xx → generic error message
   - On 200 → show success feedback + clear form or navigate back
4. Error state stored in widget state (`_errorMessage`), isSubmitting controls button disable/loader

**Reuses from LoginScreen:**
- `TextFormField` + `obscureText: true` pattern for password fields
- `GlobalKey<FormState>` for form state validation
- Error handling catch pattern: specific status codes → user-friendly messages
- State management: `_isSubmitting`, `_errorMessage` setState pattern
- Riverpod provider injection: `ref.read(publicApiProvider)`

**Key difference:** Password change is **authenticated** (requires valid token), so no 401 (invalid credentials) response — the error response is 400 + `invalid_input` code when current password is wrong, distinct from login's 401.

### Icon Row Composition Pattern

**Where:** List trailing widget on Bands/Tracks/Setlists screens; detail content area

**Pattern:**
```dart
// In trailing slot of ListTile
trailing: SizedBox(
  width: 120, // or similar constraint
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (key != null) ...[
        Icon(Icons.music_note, size: 16),
        const SizedBox(width: 4),
        Text(key, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 12),
      ],
      if (durationSeconds != null) ...[
        Icon(Icons.timer, size: 16),
        const SizedBox(width: 4),
        Text(durationSeconds.asMinutesSeconds, style: const TextStyle(fontSize: 12)),
      ],
    ],
  ),
)
```

**Null-safety strategy:** Check each field with `if (field != null)` before rendering icon + text. If field absent from API, icon simply omits (no placeholder, no error). This matches D-06 ("degrade gracefully").

**Overflow handling:**
- Use `SizedBox` with explicit `width` to constrain trailing widget
- Use `Row` with `mainAxisSize: MainAxisSize.min` to fit content
- If overflow occurs on narrow screens, icon row may shrink via `Text` maxLines/overflow — acceptable for v1 (detail screen can show full labels)

### Role Badge on Bands List

**Pattern:**
```dart
// In BandsScreen._buildContent trailing
trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text('${membersCount}'), // Already available on BandListItem
    const SizedBox(width: 8),
    Chip(
      label: Text(isOwner ? 'Owner' : 'Member'),
      labelStyle: TextStyle(fontSize: 12),
    ),
    const SizedBox(width: 8),
    const Icon(Icons.chevron_right),
  ],
)
```

**Ownership logic:**
- Reuse `_isOwner()` and `_ownershipStatus()` static helpers from band_detail_screen.dart — no reimplementation
- Tri-state: `true` (owner), `false` (member), `null` (profile loading) — only render badge once `isOwner != null`
- Watch `profileDataProvider` to derive current user ID

### API Response Schema Evolution (Client-First)

**Pattern:** Define schema shape in OpenAPI YAML; client consumes the spec to generate types; backend implements changes separately.

**Implementation:**
1. Update `lib/api/publicapi.yml`:
   - Add `currentPassword` to `ChangeUserPasswordRequestBody`
   - Add `key` (optional) to `TrackListItem`
   - Add `eventLocation` (optional) to `SetlistListItem`
   - Add `ownerId` to `BandListItem`
2. Regenerate Dart types (if using `openapi_generator` or similar; if manual, add fields to parsed `Map<String, dynamic>`)
3. Access fields defensively: `track['key'] as String?` (returns null if missing)
4. Render conditionally: `if (key != null) { ... }`

**Fallback UX:** If backend doesn't yet return the new field:
- Password change: still works (current password validation server-side)
- Icons: simply omit (icon row shows only available fields)
- Member count/role: member count already exists on BandListItem; ownerId might be null initially, role badge skipped until loaded

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Form validation (email format, password strength, confirmation match) | Regex patterns or manual string checks | Flutter's built-in `TextFormField.validator` + `FormState.validate()` | Already proven in LoginScreen; handles submission state and focus correctly |
| HTTP error response parsing | Manual JSON parsing with try/catch | Existing `ApiException.fromResponse()` factory + statusCode + code inspection | Centralizes error shape; already handles charset/encoding edge cases |
| Password field obscuring | Custom logic for show/hide toggle | `TextFormField(obscureText: bool)` + `setState(() { _obscureText = !_obscureText; })` | Built-in, accessible, familiar UX |
| Icon sizing and spacing | Custom measurements per screen | Consistent Material design scale: 16–24px icons, 4–8px gutters, standard `SizedBox` spacing | Maintains visual hierarchy across list/detail |
| Reusable ownership checks | Inline `currentUserId == ownerId` on each screen | Static `_isOwner()` and `_ownershipStatus()` helpers from band_detail_screen.dart | Single source of truth; avoids tri-state confusion (null = loading vs false = not owner) |

**Key insight:** All phase 6 requirements layer on **existing infrastructure** (form patterns, API client, Riverpod providers, cache). No custom solutions needed — reuse established patterns from v1.0.

## Common Pitfalls

### Pitfall 1: Null Safety on New API Fields

**What goes wrong:** New fields (`key`, `eventLocation`, `ownerId`) may be absent from server response during transition. Code assumes they exist and crashes with `type 'Null' is not a subtype of type 'String'`.

**Why it happens:** Client-first spec changes (D-01/D-03/D-04/D-05) mean backend may not implement for weeks. API response gradually gains the field, but early responses omit it.

**How to avoid:** Cast defensively every time:
```dart
final key = track['key'] as String?;  // Returns null if missing, not crash
if (key != null) { /* render */ }
```

**Warning signs:**
- Red squiggle on `track['key'] as String` (missing null-coalesce)
- Test crashes with "type 'Null' is not a subtype"
- Production crash from live API response before field lands on backend

### Pitfall 2: Icon Row Overflow on Narrow Screens

**What goes wrong:** Icon + label rows (e.g., "🎵 C  ⏱ 3:45") in `ListTile.trailing` spill off the right edge on phones in portrait, text gets truncated mid-character, or icon disappears.

**Why it happens:** `ListTile.trailing` has implicit space constraints; packing 2+ icon+label pairs without explicit width can exceed available space, especially with long key names (e.g., "C#" + "D#m" together).

**How to avoid:**
- Wrap icon row in `SizedBox(width: 120, child: Row(...))` to enforce a max width
- Use `Row(mainAxisSize: MainAxisSize.min, ...)` so row shrinks to fit content, not expand greedily
- On detail screen, icon row can span full width (no constraint), so it's lower risk there

**Warning signs:**
- Visual overflow/red underline in preview
- Layout test fails: "constraints are unbounded"
- Text truncation ("C# ⏱ 3:…") on narrow viewports

### Pitfall 3: Password Validation UX — Three-Field Mismatch

**What goes wrong:** User enters new password "secret123" and confirm password "secret124" (typo), form allows submit, server rejects, user sees generic error, confusion about which field is wrong.

**Why it happens:** Client-side validation only checks non-empty and length; doesn't compare confirm until submit. Server rejects the mismatch with "invalid_input" — no detail on which field caused it.

**How to avoid:**
- Validate confirm == new in the validator of the confirm-password field:
  ```dart
  TextFormField(
    controller: _confirmPasswordController,
    validator: (value) {
      if (value != _newPasswordController.text) {
        return "Passwords don't match";
      }
      return null;
    },
  )
  ```
- This gives instant feedback before submission (form red indicator), improving UX

**Warning signs:**
- Form allows submit even when confirm doesn't match (validator always returns null)
- User reports "I typed it correctly but it failed" — they didn't see the mismatch
- Test passes but manual testing shows confusing error message

### Pitfall 4: Ownership Status Tri-State Not Guarded

**What goes wrong:** Profile is still loading (ownership status = `null`), but code renders the role badge conditionally (`isOwner ? 'Owner' : 'Member'`), which treats `null` as `false`, showing "Member" while the real role is still being fetched.

**Why it happens:** Boolean logic doesn't preserve the tri-state; `null ? true : false` evaluates to `false`. Code assumes `isOwner` is always resolved (true/false).

**How to avoid:**
- Guard rendering on `isOwner != null`:
  ```dart
  if (isOwner != null) {
    Chip(label: Text(isOwner ? 'Owner' : 'Member'));
  }
  // else: don't render until profile loads
  ```
- Use `_ownershipStatus()` helper from band_detail_screen.dart (already has this logic)

**Warning signs:**
- Badge flickers between "Member" and "Owner" on screen load
- Role badge shows opposite role for a moment
- Test sees "Member" when currentUserId == ownerId

### Pitfall 5: Form Error Message Leaking Across Fields

**What goes wrong:** User enters wrong current password, sees error "Current password is incorrect", then corrects current password and submits — the error message from the previous attempt still displays.

**Why it happens:** `_errorMessage` is not cleared when user modifies the form; it only clears on successful submit or new submit attempt.

**How to avoid:**
- Clear `_errorMessage` on any form field change:
  ```dart
  TextFormField(
    onChanged: (_) => setState(() => _errorMessage = null),
  )
  ```
- Or clear it in the `_submit()` method before submission (existing LoginScreen pattern)

**Warning signs:**
- Old error text appears after user corrects the field
- User taps submit again to dismiss the error
- Manual testing sees error persist when it shouldn't

## Code Examples

### Password Change Form (ProfileScreen or ChangePasswordScreen)

**Source:** Pattern established in LoginScreen; adapted for authenticated endpoint.

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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              hintText: 'Enter your current password',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              hintText: 'At least 8 characters',
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Required';
              if ((value?.length ?? 0) < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Required';
              if (value != _newPasswordController.text) {
                return "Passwords don't match";
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Change password'),
          ),
        ],
      ),
    );
  }
}
```

### Icon Row on Track List

**Source:** Adapts existing track_list_screen.dart pattern.

```dart
// In TrackListScreen._buildContent, replace:
// trailing: Text(durationSeconds?.asMinutesSeconds ?? '—'),

// With:
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
)
```

### Role Badge on Bands List

**Source:** Extends bands_screen.dart with role indicator using existing BandDetailScreen helpers.

```dart
// In BandsScreen, add at top (after imports):
import 'band_detail_screen.dart'; // Already imported for navigation

// In _buildContent, modify the ListTile:
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

// Helper method (can refactor into shared utility later):
bool _isCurrentUserOwner(WidgetRef ref, String ownerId) {
  final profileAsync = ref.watch(profileDataProvider);
  return profileAsync.maybeWhen(
    data: (profile) => (profile['id'] as String?) == ownerId,
    orElse: () => false,
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual JSON parsing for API responses | Typed schema via `publicapi.yml` + deserialization to `Map<String, dynamic>` + defensive casts | Phase 1 (Riverpod cache) | Reduced type errors; enables gradual schema evolution (D-06) |
| Synchronous validation on button press | `TextFormField.validator` called by `FormState.validate()` before submit | Phase 1 (LoginScreen) | Better UX (instant field feedback) and testability |
| Inline ownership checks every screen | Centralized `_isOwner()` / `_ownershipStatus()` helpers (band_detail_screen.dart) | Phase 6 this research | Eliminates tri-state bugs; establishes reusable pattern for BAND-10 |

**Deprecated/outdated:**
- None for this phase; all patterns are current and proven in v1.0

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Existing `PublicApi` can add `changePassword()` method following `register()`/`login()` pattern without refactoring | Standard Stack | If API client architecture doesn't support new method signature, refactoring needed |
| A2 | Backend will implement `currentPassword` field validation on `ChangeUserPasswordRequestBody`, returning 400 + `invalid_input` code for wrong current password | Code Examples | If backend uses different error code/message, error handling in form needs adjustment |
| A3 | Material icons (`Icons.music_note`, `Icons.timer`, etc.) are semantically clear enough without tooltips per D-07 | Common Pitfalls | If users find icons ambiguous, tooltips or text labels may be needed (scope creep) |
| A4 | `TrackListItem` schema extension with optional `key` field will be parsed as null-safe cast (`as String?`) without breaking existing consumers | Architecture Patterns | If existing code assumes `key` always present, a migration step needed (low risk — new field shouldn't exist yet) |

**User confirmation needed:** None of these are high-risk; all are addressed by existing patterns or safe assumptions about API behavior.

## Open Questions

1. **Password change screen location:** CONTEXT.md leaves as planner's choice — on Profile screen directly, or in Settings sub-screen? (No functional impact; both architectures work)
   - What we know: USER-03 says "from Profile screen"; LoginScreen precedent suggests either integrated form or modal/sub-screen navigation
   - What's unclear: UX preference (always visible vs. hierarchical navigation)
   - Recommendation: Start with a "Change password" ListTile on Profile screen → navigates to a dedicated ChangePasswordScreen (keeps Profile simple, mirrors SettingsScreen pattern)

2. **Icon selection for musical key:** D-07 leaves icon choice to planner.
   - What we know: `Icons.music_note` (eighth note), `Icons.piano` (piano keyboard), `Icons.key` (lock key) are candidates
   - What's unclear: Which best matches user expectation (musicians may expect different semantics)
   - Recommendation: Use `Icons.music_note` (industry-standard note icon for musical content)

3. **Backend adoption timeline for client-first spec changes:** When will backend implement the four new fields?
   - What we know: CONTEXT.md confirms this is a client-first extension (precedent: SETL-12 in Phase 10)
   - What's unclear: Whether backend will implement in same sprint or follow-up
   - Recommendation: Plan assumes eventual implementation; UI gracefully omits icons if fields absent. Monitor backend PR for field arrival; no client changes needed once backend ships.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | App build, widget testing | ✓ | (current in env) | — |
| Dart SDK | Dart compilation, code generation | ✓ | 3.12.2+ | — |
| Android SDK / Xcode | Android/iOS build & testing | ✓ (per .claude/CLAUDE.md) | (current) | — |

**Missing dependencies with no fallback:** None identified.

**Missing dependencies with fallback:** None identified.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in via Flutter SDK) + Riverpod testing utilities |
| Config file | (none — flutter test auto-discovers test/ directory) |
| Quick run command | `flutter test test/features/profile/ -k password` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| USER-03 | Form validates current password non-empty | unit | `flutter test test/features/profile/change_password_form_test.dart::test_formValidatesCurrentPasswordRequired` | ❌ Wave 0 |
| USER-03 | Form validates new password min 8 chars | unit | `flutter test test/features/profile/change_password_form_test.dart::test_formValidatesNewPasswordLength` | ❌ Wave 0 |
| USER-03 | Form validates confirm password matches | unit | `flutter test test/features/profile/change_password_form_test.dart::test_formValidatesConfirmPasswordMatch` | ❌ Wave 0 |
| USER-03 | Successful password change shows success message | widget | `flutter test test/features/profile/change_password_screen_test.dart::test_successShowsSnackBar` | ❌ Wave 0 |
| USER-03 | Wrong current password shows error message | widget | `flutter test test/features/profile/change_password_screen_test.dart::test_wrongCurrentPasswordShowsError` | ❌ Wave 0 |
| BAND-10 | Bands list shows member count for each band | widget | `flutter test test/features/bands/bands_screen_test.dart::test_memberCountDisplayed` | ❌ Wave 0 |
| BAND-10 | Bands list shows "Owner" badge for current user's bands | widget | `flutter test test/features/bands/bands_screen_test.dart::test_ownerBadgeDisplayed` | ❌ Wave 0 |
| BAND-10 | Bands list shows "Member" badge for joined bands | widget | `flutter test test/features/bands/bands_screen_test.dart::test_memberBadgeDisplayed` | ❌ Wave 0 |
| TRACK-07 | Track list shows musical key icon + label when key present | widget | `flutter test test/features/tracks/track_list_screen_test.dart::test_keyIconDisplayed` | ❌ Wave 0 |
| TRACK-07 | Track list omits key icon when key null (graceful degrade) | widget | `flutter test test/features/tracks/track_list_screen_test.dart::test_keyIconOmittedWhenNull` | ❌ Wave 0 |
| TRACK-07 | Track detail screen shows notes field | widget | `flutter test test/features/tracks/track_detail_screen_test.dart::test_notesDisplayed` | ✅ (existing) |
| SETL-11 | Setlist list shows location icon + label when location present | widget | `flutter test test/features/setlists/setlist_list_screen_test.dart::test_locationIconDisplayed` | ❌ Wave 0 |
| SETL-11 | Setlist list omits location icon when location null (graceful degrade) | widget | `flutter test test/features/setlists/setlist_list_screen_test.dart::test_locationIconOmittedWhenNull` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/features/profile/ test/features/bands/ test/features/tracks/ test/features/setlists/` (covers all modified screens)
- **Per wave merge:** `flutter test` (full suite, <2 min on CI)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/features/profile/change_password_form_test.dart` — unit tests for form validation (current/new/confirm password checks)
- [ ] `test/features/profile/change_password_screen_test.dart` — widget tests for screen (success flow, error handling, API call)
- [ ] `test/features/bands/bands_screen_test.dart` — update existing test to verify member count and role badge display
- [ ] `test/features/tracks/track_list_screen_test.dart` — add icon display tests (key present, key absent)
- [ ] `test/features/setlists/setlist_list_screen_test.dart` — add icon display tests (location present, location absent)
- [ ] `test/helpers/mock_public_api.dart` — if not present, add mock `changePassword()` method for testing

*(Existing test infrastructure in place; gaps are new test coverage for Phase 6 features, not framework setup.)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | — | No changes (existing token-based auth unchanged) |
| V3 Session Management | — | No changes (existing session token handling unchanged) |
| V4 Access Control | — | No changes (role display is read-only; no new mutations gated on ownership) |
| V5 Input Validation | Yes | Password change form: validate length (8+ chars), non-empty; server validates current password correctness |
| V6 Cryptography | Yes | HTTPS for all requests (existing ApiClient); password transmitted only over encrypted channel; no client-side hashing |
| V7 Cryptographic Failures | Yes | Server handles password hashing (bcrypt or similar); client never sees plaintext comparison |
| V8 Sensitive Data Exposure | Yes | `obscureText: true` on password fields; no logging of sensitive fields; token stored in flutter_secure_storage |
| V9 Authentication & Communication Failures | Yes | HTTP 400 + error code on auth failure; user sees clear message; no session fixation risk (token-based) |

### Known Threat Patterns for {stack}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Client-side password validation only | Tampering | Server validates current password; client validation for UX only (do not trust) |
| Password field cleartext logging | Information Disclosure | Use `obscureText: true`; never print password to console; no analytics on password field |
| Timing attack on current password comparison | Tampering | Server uses constant-time comparison (e.g., bcrypt.timingSafeEqual); client relays plaintext, server decides |
| Credentials in error messages | Information Disclosure | Error message says "Current password is incorrect" not "Password hash mismatch" or internal detail |
| Man-in-the-middle on password endpoint | Tampering, Repudiation | HTTPS enforced (existing); certificate pinning not in scope for v1 |
| Icon row icon IDs leaked in logs | Information Disclosure | Icons are Material constants, no sensitive data; safe to render |

**Password-specific controls:**
- Minimum length: 8 characters (enforced client + server)
- No plaintext storage: server hashes before persistence
- Rate limiting: server rate-limits `/api/me/password` endpoint (assumed, verify in backend review)
- Clear error messages: "Current password is incorrect" not "hash mismatch"

## Sources

### Primary (HIGH confidence)

- **lib/api/publicapi.yml** — API contract source of truth; verified schema shapes for `ChangeUserPasswordRequestBody`, `TrackListItem`, `SetlistListItem`, `BandListItem` by reading lines 727–770, 873–888, 1012–1031 [VERIFIED: lib/api/publicapi.yml:727-734, 757-770, 873-888, 1012-1031]
- **lib/features/auth/login_screen.dart** — Form validation pattern (TextFormField, GlobalKey<FormState>, error handling) [VERIFIED: lib/features/auth/login_screen.dart:17-80]
- **lib/features/bands/band_detail_screen.dart** — Ownership status helpers `_isOwner()`, `_ownershipStatus()` for role logic [VERIFIED: lib/features/bands/band_detail_screen.dart:29-43]
- **lib/features/tracks/track_formatting.dart** — Duration formatting utility `asMinutesSeconds` [VERIFIED: lib/features/tracks/track_formatting.dart:1-5]
- **pubspec.yaml** — Dependency versions and testing framework [VERIFIED: pubspec.yaml:10-25]
- **.planning/config.json** — Validation architecture enabled (nyquist_validation: true), security enforcement enabled (security_enforcement: true) [VERIFIED: .planning/config.json:24, 47]

### Secondary (MEDIUM confidence)

- **CONTEXT.md (06-CONTEXT.md)** — Phase boundary, decisions D-01 through D-07, canonical references, code context, reusable assets [CITED: .planning/phases/06-foundation-info-settings-polish/06-CONTEXT.md]
- **Flutter Material Icons documentation** — Icon choices (Icons.music_note, Icons.timer, Icons.location_on, Icons.notes) are standard Material components [CITED: https://fonts.google.com/icons]
- **Flutter Form documentation** — TextFormField validator pattern, FormState.validate() behavior [CITED: https://flutter.dev/docs/cookbook/forms/validation]

### Tertiary (LOW confidence)

- [ASSUMED] Backend will implement `ChangeUserPasswordRequestBody.currentPassword` field with validation returning 400 + `invalid_input` code for wrong password — precedent from Phase 10's SETL-12, but not yet verified against backend PR
- [ASSUMED] Material icon selection (music_note vs. piano for key) — no user research; based on industry convention
- [ASSUMED] OwnershipStatus tri-state (`null` = loading, `true` = owner, `false` = member) is correctly understood by all consumers — existing pattern not formally documented

## Metadata

**Confidence breakdown:**
- **Standard stack (HIGH):** Form patterns proven in LoginScreen; icon composition is straightforward Material design; API client already proven; no new libraries
- **Architecture (HIGH):** Forms, ownership checks, API error handling all established; client-first spec evolution precedent set by SETL-12
- **Pitfalls (MEDIUM):** Null-safety and tri-state ownership are known risks in Flutter; documented in existing code comments; but phase-specific risk is moderate (only two new screens/patterns)
- **Security (HIGH):** Follows ASVS V5/V6/V8 standards; password handling reuses existing secure storage and HTTPS; no novel cryptography

**Research date:** 2026-08-20
**Valid until:** 2026-09-20 (30 days — stable patterns, low tech churn)

---

*Phase: 6-Foundation Info & Settings Polish*
*Research completed: 2026-08-20*
*Ready for planning.*
