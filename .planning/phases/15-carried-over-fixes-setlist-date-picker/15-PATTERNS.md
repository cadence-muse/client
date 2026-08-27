# Phase 15: Carried-Over Fixes & Setlist Date Picker - Pattern Map

**Mapped:** 2026-08-27
**Files analyzed:** 3 (code) + 1 (documentation)
**Analogs found:** 3 / 3 (100% match — all modifications are to existing screens)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/setlists/create_setlist_screen.dart` | component (screen) | CRUD | `lib/features/setlists/create_setlist_screen.dart` (same file) | exact |
| `lib/features/setlists/edit_setlist_screen.dart` | component (screen) | CRUD | `lib/features/setlists/edit_setlist_screen.dart` (same file) | exact |
| `lib/features/bands/band_detail_screen.dart` | component (screen) | request-response | `lib/features/bands/band_detail_screen.dart` (same file) | exact |
| `.planning/milestones/v1.0-phases/02-bands/02-VERIFICATION.md` | documentation | N/A | N/A (documentation audit update only) | N/A |

---

## Pattern Assignments

### `lib/features/setlists/create_setlist_screen.dart` (component, CRUD)

**Analog:** `lib/features/setlists/create_setlist_screen.dart` (SELF) — modify existing date field at lines 130–137

**Imports pattern** (lines 1–11):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/setlists_provider.dart';
import '../../providers/tracks_provider.dart';
import 'setlist_detail_screen.dart';
import 'setlist_formatting.dart' show maxSetlistTracks;
```
*(All imports already present; may need `import 'package:flutter/services.dart'` if not already there for future platform channel use, but not required for Material showDatePicker)*

**Date controller initialization** (lines 27, 38–39):
```dart
final _dateController = TextEditingController();

// In EditSetlistScreen (similar pattern):
late final _dateController = TextEditingController(
  text: widget.currentSetlist['eventDate'] as String?,
);
```

**Current date field to replace** (lines 130–137):
```dart
TextFormField(
  controller: _dateController,
  decoration: InputDecoration(
    labelText: l10n.commonDateLabel,
    hintText: l10n.createSetlistDateHint,
    border: const OutlineInputBorder(),
  ),
),
```

**New pattern for date field (read-only + picker + clear button):**

Replace the above with:
```dart
TextFormField(
  controller: _dateController,
  readOnly: true,
  onTap: () => _showDatePickerDialog(context),
  decoration: InputDecoration(
    labelText: l10n.commonDateLabel,
    border: const OutlineInputBorder(),
    suffixIcon: _dateController.text.isNotEmpty
        ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _dateController.clear()),
          )
        : null,
  ),
),
```

**Helper method to add** (in `_CreateSetlistScreenState`):
```dart
Future<void> _showDatePickerDialog(BuildContext context) async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year - 5, now.month, now.day);
  final lastDate = DateTime(now.year + 2, now.month, now.day);
  
  // Parse existing date if editing
  DateTime? initialDate = today;
  if (_dateController.text.isNotEmpty) {
    try {
      initialDate = DateTime.parse(_dateController.text);
    } catch (_) {
      initialDate = now;
    }
  }
  
  final selected = await showDatePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDate: initialDate,
  );
  
  if (selected != null) {
    setState(() {
      // Format as YYYY-MM-DD (ISO 8601 date-only format)
      _dateController.text = selected.toIso8601String().split('T')[0];
    });
  }
}
```

**Form submission pattern** (lines 41–93, unchanged — handle empty date as null):
```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isSubmitting = true;
    _errorMessage = null;
  });

  final name = _nameController.text.trim();
  final location = _locationController.text.trim();
  final date = _dateController.text.trim();  // ← already handles empty

  try {
    final response = await ref
        .read(publicApiProvider)
        .createSetlist(
          bandId: widget.bandId,
          name: name,
          eventLocation: location.isEmpty ? null : location,
          eventDate: date.isEmpty ? null : date,  // ← empty → null
          trackIds: _selectedTrackIds.isEmpty
              ? null
              : _selectedTrackIds.toList(),
        );
    // ... success handling unchanged
  } on ApiException catch (e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _errorMessage = e.localizedMessage(l10n));
  } catch (_) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _errorMessage = l10n.createSetlistFailedError);
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
```

**Error handling pattern** (lines 82–92):
- ✅ Already present and correct
- Catches `ApiException` for HTTP errors, generic `catch (_)` for unexpected errors
- Sets `_errorMessage` for display and shows success SnackBar + navigate on success

---

### `lib/features/setlists/edit_setlist_screen.dart` (component, CRUD)

**Analog:** `lib/features/setlists/edit_setlist_screen.dart` (SELF) — modify existing date field at lines 151–159

**Date controller initialization** (lines 38–40, ALREADY INITIALIZES FROM CURRENT SETLIST):
```dart
late final _dateController = TextEditingController(
  text: widget.currentSetlist['eventDate'] as String?,
);
```

**Current date field to replace** (lines 151–159):
```dart
TextFormField(
  controller: _dateController,
  textInputAction: TextInputAction.done,
  onFieldSubmitted: (_) => _submit(),
  decoration: InputDecoration(
    labelText: l10n.commonDateLabel,
    border: const OutlineInputBorder(),
  ),
),
```

**New pattern for date field** (same as create_setlist_screen, but use existing date as initialDate):
```dart
TextFormField(
  controller: _dateController,
  readOnly: true,
  onTap: () => _showDatePickerDialog(context),
  decoration: InputDecoration(
    labelText: l10n.commonDateLabel,
    border: const OutlineInputBorder(),
    suffixIcon: _dateController.text.isNotEmpty
        ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => setState(() => _dateController.clear()),
          )
        : null,
  ),
),
```

**Helper method to add** (in `_EditSetlistScreenState`, use existing date if present):
```dart
Future<void> _showDatePickerDialog(BuildContext context) async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year - 5, now.month, now.day);
  final lastDate = DateTime(now.year + 2, now.month, now.day);
  
  // Parse existing date from controller (already pre-populated on init)
  DateTime initialDate = now;
  if (_dateController.text.isNotEmpty) {
    try {
      initialDate = DateTime.parse(_dateController.text);
    } catch (_) {
      initialDate = now;
    }
  }
  
  final selected = await showDatePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDate: initialDate,
  );
  
  if (selected != null) {
    setState(() {
      _dateController.text = selected.toIso8601String().split('T')[0];
    });
  }
}
```

**Form submission pattern** (lines 52–115, unchanged):
```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  final l10n = AppLocalizations.of(context)!;

  setState(() {
    _isSubmitting = true;
    _errorMessage = null;
  });

  final name = _nameController.text.trim();
  final locationText = _locationController.text.trim();
  final dateText = _dateController.text.trim();  // ← already handles empty
  final eventLocation = locationText.isEmpty ? null : locationText;
  final eventDate = dateText.isEmpty ? null : dateText;  // ← empty → null

  try {
    await ref
        .read(publicApiProvider)
        .updateSetlist(
          bandId: widget.bandId,
          setlistId: widget.setlistId,
          name: name,
          eventLocation: eventLocation,
          eventDate: eventDate,  // ← may be null
        );
    // ... cache invalidation unchanged
  } on ApiException catch (e) {
    setState(() => _errorMessage = e.localizedMessage(l10n));
  } catch (_) {
    setState(() => _errorMessage = l10n.editSetlistFailedError);
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
```

---

### `lib/features/bands/band_detail_screen.dart` (component, request-response)

**Analog:** `lib/features/bands/band_detail_screen.dart` (SELF) — modify copy button at lines 255–265, leave rotate button gated

**CURRENT PATTERN (lines 255–265)** — **TO MODIFY (BAND-13 D-05):**
```dart
Tooltip(
  message: isOnline
      ? l10n.bandDetailCopyTooltip
      : l10n.commonRequiresConnection,
  child: IconButton(
    icon: const Icon(Icons.content_copy),
    onPressed: isOnline
        ? () => _copyInviteCode(context, inviteCode)
        : null,
  ),
),
```

**REPLACE WITH** (remove `isOnline` gate only from copy button):
```dart
Tooltip(
  message: l10n.bandDetailCopyTooltip,
  child: IconButton(
    icon: const Icon(Icons.content_copy),
    onPressed: () => _copyInviteCode(context, inviteCode),
  ),
),
```

**Reference pattern — ROTATE/REGENERATE button (lines 266–283)** — **STAYS GATED**:
```dart
if (isOwner == true)
  Tooltip(
    message: isOnline
        ? l10n.commonRotate
        : l10n.commonRequiresConnection,
    child: IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: isOnline
          ? () => showDialog<void>(
              context: context,
              builder: (_) => ConfirmRotateInviteCodeDialog(
                bandId: bandId,
                bandName: name,
              ),
            )
          : null,
    ),
  ),
```
*(This remains unchanged — only copy button loses its gate)*

**Reference pattern — EDIT button in AppBar (lines 62–79)** — **STAYS GATED**:
```dart
Tooltip(
  message: isOnline
      ? l10n.commonEdit
      : l10n.commonRequiresConnection,
  child: IconButton(
    icon: const Icon(Icons.edit),
    onPressed: isOnline
        ? () => Navigator.of(context).push(...)
        : null,
  ),
),
```

**_copyInviteCode method** (lines 364–371, unchanged):
```dart
Future<void> _copyInviteCode(BuildContext context, String inviteCode) async {
  final l10n = AppLocalizations.of(context)!;
  await Clipboard.setData(ClipboardData(text: inviteCode));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.bandDetailCopiedSnackbar)));
}
```
*(Unchanged; already handles clipboard copy + SnackBar correctly)*

**Localization strings** (from `lib/l10n/app_en.arb`):
```json
"bandDetailCopyTooltip": "Copy",
"bandDetailCopiedSnackbar": "Copied!",
"commonDateLabel": "Date",
"createSetlistDateHint": "YYYY-MM-DD"
```

---

## Shared Patterns

### isOnline Gating (Band Actions)

**Source:** `lib/features/bands/band_detail_screen.dart` (multiple uses)

**Pattern:** Wrap interactive buttons with `Tooltip + disabled state gating`
```dart
final isOnline = ref.watch(isOnlineProvider);
final l10n = AppLocalizations.of(context)!;

Tooltip(
  message: isOnline ? '' : l10n.commonRequiresConnection,
  child: IconButton(
    icon: const Icon(Icons.edit),
    onPressed: isOnline ? () => _doAction() : null,
  ),
),
```

**Apply to:** All band mutation actions (edit, delete, rotate invite, remove member, leave, transfer ownership)

**Exception for BAND-13:** Copy button loses this gate entirely — Tooltip shows "Copy" always, `onPressed` always enabled.

---

### Form Error Handling Pattern

**Source:** `lib/features/setlists/create_setlist_screen.dart` (lines 82–92) and `lib/features/bands/create_band_screen.dart` (lines 53–56)

**Pattern:**
```dart
try {
  await ref.read(publicApiProvider).doSomething(...);
  // ... success handling
} on ApiException catch (e) {
  if (!mounted) return;
  final l10n = AppLocalizations.of(context)!;
  setState(() => _errorMessage = e.localizedMessage(l10n));
} catch (_) {
  if (!mounted) return;
  final l10n = AppLocalizations.of(context)!;
  setState(() => _errorMessage = l10n.commonFallbackError);
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```

**Apply to:** All create/edit mutation screens (setlists, bands, tracks)

---

### TextFormField with Network Dependency

**Source:** `lib/features/setlists/create_setlist_screen.dart` (lines 233–249) and `lib/features/bands/create_band_screen.dart` (lines 99–115)

**Pattern:** Submit button gated behind `isOnline` check + loading spinner
```dart
Tooltip(
  message: isOnline ? '' : l10n.commonRequiresConnection,
  child: FilledButton(
    onPressed: (_isSubmitting || !isOnline) ? null : _submit,
    child: _isSubmitting
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            isOnline
                ? l10n.commonCreate
                : l10n.commonRequiresConnection,
          ),
  ),
),
```

**Apply to:** All form screens with network operations

---

## QA-01 Verification Audit

**No code changes — documentation audit only.**

Update `.planning/milestones/v1.0-phases/02-bands/02-VERIFICATION.md` in place:

| Gap | Current Status (to update) | Evidence |
|-----|---------------------------|----------|
| Hive deep-convert | ✅ Resolved | `_deepConvert()` method at `lib/cache/cache_service.dart:37` |
| Mutation error handling | ✅ Resolved | Generic fallback `catch (_)` present in mutation screens (create/edit band/setlist, confirm dialogs) |
| Band-rename list propagation | ✅ Resolved | `ref.exists(bandsListDataProvider)` guard with `renameBand()` patch in `lib/features/bands/edit_band_screen.dart:68–70` |
| Background-refresh version guard | ✅ Resolved | `_version` counter + `capturedVersion` comparison in `lib/providers/bands_provider.dart` (BandsListData ~lines 36–145, BandDetailData ~lines 172–247) |

**Executor must independently re-verify each artifact before writing the update, including mutation sites in:**
- `lib/features/bands/confirm_delete_band_dialog.dart`
- `lib/features/bands/confirm_leave_band_dialog.dart`
- `lib/features/bands/confirm_remove_member_dialog.dart`

---

## Implementation Notes for Executor

### Date Picker Specifics

1. **Date format:** API expects `YYYY-MM-DD` (ISO 8601 date-only). Use `selected.toIso8601String().split('T')[0]` to format picker result.

2. **Date range:** 
   - `firstDate` = today − 5 years
   - `lastDate` = today + 2 years
   - Enforce via `DateTime(now.year ± N, now.month, now.day)` bounds

3. **Initialization:**
   - **Creating:** `initialDate = today`
   - **Editing:** `initialDate = parse(_dateController.text)` if not empty, else today

4. **Clear button:**
   - Show only when field is non-empty: `_dateController.text.isNotEmpty`
   - Clears controller: `_dateController.clear()`
   - Submits as `null` to API (existing logic already handles empty string → null)

5. **Localization:** `showDatePicker()` respects `Locale.of(context)` automatically (Phase 12 locale infrastructure).

### Copy Button Modification

1. **Only change:** Remove `isOnline` gate from copy button (lines 255–265).
2. **Keep unchanged:** All other band actions (rotate, edit, delete, leave, remove-member) remain gated.
3. **Test:** Copy works offline, shows "Copied!" snackbar, does not require network.

### Verification Audit

1. Re-check each of the 4 gaps in current code (don't trust prior notes).
2. Update `.planning/milestones/v1.0-phases/02-bands/02-VERIFICATION.md` frontmatter (`status`, `score`) and gap descriptions with current line numbers.
3. Confirm no new gaps have appeared.

---

## Metadata

**Analog search scope:** `lib/features/setlists/`, `lib/features/bands/`, `lib/l10n/`

**Files scanned:** 8 (3 target screens + 5 reference screens/locale files)

**Pattern extraction date:** 2026-08-27

**Coverage:** 100% — all modifications are in-place edits of existing screens with established patterns already present
