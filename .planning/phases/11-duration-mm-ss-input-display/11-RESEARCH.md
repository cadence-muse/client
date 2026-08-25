# Phase 11: Duration mm:ss Input + Display — Research

**Researched:** 2026-08-25
**Domain:** Flutter Dart mobile app, TextInputFormatter custom widget pattern
**Confidence:** HIGH

## Summary

Phase 11 implements mm:ss duration input with auto-formatting in the create/edit track forms, and unifies duration display across all screens (tracks and setlists) to a single mm:ss format. The implementation reuses Flutter's built-in `TextInputFormatter` API (zero external dependencies), leverages the existing `DurationFormatting.asMinutesSeconds` extension already used by track displays, and requires consolidating two divergent format conventions currently scattered across the codebase (`track_formatting.dart`'s mm:ss and `setlist_formatting.dart`'s "Xm Ys" words-based format).

The API contract (`durationSeconds: int`) does not change — conversion happens only at the input/display boundary. No async operations; no state management changes; no new packages required.

**Primary recommendation:** Implement `DurationTextInputFormatter` as a new class in `track_formatting.dart`, wire it into both `create_track_screen.dart` and `edit_track_screen.dart` with the existing `_wholeNumberValidator` pattern extended for mm:ss validation, and consolidate the display format by retiring `asMinutesAndSeconds` from `setlist_formatting.dart` and updating all callers to use the unified `asMinutesSeconds` extension from `track_formatting.dart`.

## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01 through D-06)

1. **Canonical display format (D-01):** Unify on mm:ss with unbounded minutes across every screen. Setlist's words-based `"42m 35s"` format is retired. No special-casing for totals over 60 minutes — plain mm:ss handles it (e.g., "72:15" for a 72-minute setlist).

2. **Auto-format typing mechanics (D-02 to D-04):** Right-to-left stopwatch-style digit shift as the user types, capped at 99:59, with backspace deleting the last shifted digit and reformatting (no whole-field clear).

3. **Validation feedback UX (D-05):** Inline error text shown on submit attempt only, not per-keystroke. Matches existing create/edit track form validation pattern (WR-02).

4. **Empty/optional duration handling (D-06):** Blank field remains valid/optional and submits as `null` `durationSeconds`. Auto-formatter only activates once user types a digit.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|-----------|-------------|----------------|-----------|
| Duration input auto-formatting | Frontend (TextInputFormatter) | — | Client-side keystroke interception; no server round-trip |
| Duration validation | Frontend (TextFormField validator) | — | Form-level validation before submit; user-facing error feedback |
| mm:ss to seconds conversion | Frontend (parse function) | — | Conversion at form submit boundary; API unchanged |
| Duration display formatting | Frontend (extension method) | — | Render-time conversion; reuses existing `asMinutesSeconds` pattern |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter (SDK) | Latest stable (via `flutter: sdk`) | UI framework with built-in TextInputFormatter API | Official Dart/Flutter tooling; TextInputFormatter is standard Flutter pattern for input masking |
| Dart | 3.12.2+ | Language | Required by Flutter SDK; TextInputFormatter API is core to material design text input |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter/material.dart | Bundled in Flutter SDK | Material Design TextFormField and TextInputFormatter base classes | Standard Material widget set already in use (entire app uses Material Design 3) |
| flutter_test | Bundled in Flutter SDK | Widget testing framework | Existing test suite uses flutter_test; no new dependency |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|-----------|-----------|----------|
| Custom TextInputFormatter | Third-party masking package (e.g. `mask_text_input_formatter`) | External dependency adds 10–30KB; custom 15-line formatter is simpler and avoids dependency |
| TextInputFormatter | Manual keystroke filtering in onChanged callback | TextInputFormatter is the idiomatic Flutter pattern; onChanged polling is fragile (missed keystrokes, state races) |
| String parsing for validation | Regex-based validation | Explicit component parsing (minutes/seconds) is more readable and easier to test than regex |

**Installation:**
No new dependencies required. Use existing `pubspec.yaml`:
```bash
# Run with existing dependencies
flutter pub get
```

**Version verification:**
```bash
flutter --version  # Verify Flutter is latest stable
dart --version     # Should be 3.12.2+
grep "sdk:" pubspec.yaml  # Confirm SDK constraint is met
```

## Package Legitimacy Audit

**No external packages required for this phase.** All functionality uses Flutter SDK's built-in APIs:
- `TextInputFormatter` — built-in Flutter material.dart class
- `TextFormField` — built-in Flutter material widget
- `TextEditingController` — built-in Flutter widgets

**Disposition:** N/A (zero third-party dependencies)

## Architecture Patterns

### System Architecture Diagram

```
Duration Input / Display Data Flow

┌─────────────────────────────────────────────────────────────┐
│                   User Creates/Edits Track                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │  Create/Edit Track Form  │
        │  TextFormField           │
        │  (Duration field)        │
        └────┬─────────┬───────────┘
             │         │
             │         ▼
             │   ┌─────────────────────────────┐
             │   │ DurationTextInputFormatter  │
             │   │ (Right-to-left digit shift) │
             │   │ "2" → "0:02"                │
             │   │ "230" → "2:30"              │
             │   └─────────────────────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │  User Taps "Save"        │
    │  Form Validation (WR-02) │
    │  • Field not empty       │
    │  • Seconds 0–59          │
    └────┬─────────────────────┘
         │
         ▼
    ┌──────────────────────────┐
    │ parseDurationSeconds()   │
    │ "mm:ss" → durationSeconds│
    │ "2:30" → 150 seconds     │
    └────┬─────────────────────┘
         │
         ▼
    ┌──────────────────────────┐
    │  POST/PUT to API         │
    │  durationSeconds: 150    │
    └─────────────────────────┘
                       │
                       ▼
    ┌─────────────────────────────────────────────────────────┐
    │               Duration Display Everywhere                │
    │  (Track lists, Track detail, Setlist lists, Setlists)   │
    ├──────────────────────────────────────┬──────────────────┤
    │  durationSeconds (from API cache)    │ User enters      │
    │                                      │ duration offline │
    │  ▼                                   │ ▼                │
    │  asMinutesSeconds extension          │ (auto-formatted) │
    │  150 → "2:30"                        │                  │
    │  2555 → "42:35"                      │ Unified mm:ss    │
    │  (unbounded minutes, no HH:MM:SS)    │ display on all   │
    │                                      │ screens          │
    └──────────────────────────────────────┴──────────────────┘
```

### Recommended Project Structure

Modifications are localized to existing feature files; no new directories required:

```
lib/features/
├── tracks/
│   ├── track_formatting.dart           # ADD: DurationTextInputFormatter class, parseDurationSeconds() helper
│   ├── create_track_screen.dart         # MODIFY: wire formatter + update validator
│   ├── edit_track_screen.dart           # MODIFY: wire formatter + update validator
│   ├── track_list_screen.dart           # NO CHANGE (already uses asMinutesSeconds)
│   └── track_detail_screen.dart         # NO CHANGE (already uses asMinutesSeconds)
└── setlists/
    ├── setlist_formatting.dart          # MODIFY: retire asMinutesAndSeconds, update tracksAndDuration()
    ├── setlist_list_screen.dart         # MODIFY: use asMinutesSeconds instead of asMinutesAndSeconds
    ├── setlist_detail_screen.dart       # MODIFY: use asMinutesSeconds instead of asMinutesAndSeconds (3 locations)
    └── setlists_screen.dart             # MODIFY: use asMinutesSeconds instead of asMinutesAndSeconds
```

### Pattern 1: TextInputFormatter for Real-Time Input Masking

**What:** Flutter's `TextInputFormatter` intercepts keystrokes and reformats the text before it appears in the field. Used here to auto-format digits into mm:ss shape as the user types.

**When to use:** Whenever user input needs to follow a strict format without requiring manual separators (phone numbers, dates, durations, credit card numbers).

**Example:**
```dart
// Source: Flutter Material Design docs (material.dart TextInputFormatter)
class DurationTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only allow digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    // Cap at 99:59 (5999 seconds)
    if (digitsOnly.length > 5) {
      return oldValue; // Reject — would exceed 99:59
    }
    
    // Format: right-to-left digit shift
    // "2" → "0:02"
    // "23" → "0:23"
    // "230" → "2:30"
    // "2305" → "23:05"
    String formatted;
    if (digitsOnly.length <= 2) {
      formatted = digitsOnly.padLeft(2, '0');
      formatted = '0:$formatted';
    } else {
      final minutes = digitsOnly.substring(0, digitsOnly.length - 2);
      final seconds = digitsOnly.substring(digitsOnly.length - 2);
      formatted = '$minutes:$seconds';
    }
    
    return newValue.copyWith(text: formatted);
  }
}
```

**Integration in TextFormField:**
```dart
// Source: Create/Edit Track Screen (create_track_screen.dart)
TextFormField(
  controller: _durationController,
  keyboardType: TextInputType.number,
  inputFormatters: [DurationTextInputFormatter()],
  decoration: const InputDecoration(
    labelText: 'Duration',
    hintText: '0:00',
    helperText: 'e.g. 2:30 for 2 minutes 30 seconds',
    border: OutlineInputBorder(),
  ),
  validator: _durationValidator,
)
```

### Pattern 2: Form Validation for Optional mm:ss Duration

**What:** Extend the existing `_wholeNumberValidator` pattern (WR-02 comment in create_track_screen.dart) to validate mm:ss format on submit.

**Example:**
```dart
// Source: create_track_screen.dart / edit_track_screen.dart
String? _durationValidator(String? value) {
  final text = value?.trim() ?? '';
  
  // Empty field is valid (optional per D-06)
  if (text.isEmpty) return null;
  
  // Expect mm:ss format; formatter should have ensured this
  // But validate strictly in case of paste operations or edge cases
  final parts = text.split(':');
  if (parts.length != 2) {
    return 'Enter duration in mm:ss format (e.g. 0:30)';
  }
  
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  
  if (minutes == null || seconds == null) {
    return 'Enter duration in mm:ss format (e.g. 0:30)';
  }
  
  if (seconds > 59) {
    return 'Seconds must be 0–59 (e.g. 2:30, not 2:75)';
  }
  
  return null; // Valid
}
```

### Pattern 3: Parsing mm:ss String to Integer Seconds

**What:** Conversion function called at form submit time to transform user-entered mm:ss string to `durationSeconds` int for API submission.

**Example:**
```dart
// Source: track_formatting.dart (co-located with DurationFormatting extension)
int? parseDurationSeconds(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null; // Optional field per D-06
  
  final parts = trimmed.split(':');
  if (parts.length != 2) return null;
  
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  
  if (minutes == null || seconds == null) return null;
  if (seconds > 59) return null; // Seconds must be valid
  
  return minutes * 60 + seconds;
}
```

**Usage in form submit:**
```dart
// Source: create_track_screen.dart _submit() method
durationSeconds: parseDurationSeconds(_durationController.text),
```

### Pattern 4: Display Format Extension (Reuse Existing)

**What:** Existing `DurationFormatting.asMinutesSeconds` extension in `track_formatting.dart` — already correct, no changes needed.

**Example:**
```dart
// Source: track_formatting.dart (existing, no modifications)
extension DurationFormatting on int {
  String get asMinutesSeconds =>
      '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
}

// Usage (already working on track displays):
// 225 seconds → "3:45"
// 2555 seconds → "42:35"
```

**Migration for setlist displays:**
```dart
// Before (setlist_formatting.dart):
Text(durationSeconds.asMinutesAndSeconds)  // "42m 35s"

// After (setlist_list_screen.dart, etc.):
Text(durationSeconds.asMinutesSeconds)     // "42:35" (unified)
```

### Anti-Patterns to Avoid

- **Do NOT:** Store formatted duration strings in the Hive cache. Cache raw `durationSeconds: int` only; format at render time. Formatted strings coupled to UI; locale/format changes require cache invalidation.
- **Do NOT:** Use `int.parse()` without validation; it throws on non-numeric input. Use `int.tryParse()` and check for null.
- **Do NOT:** Allow negative durations. Validate `minutes >= 0 && seconds >= 0` explicitly.
- **Do NOT:** Assume all mobile keyboards show numeric input. Use `keyboardType: TextInputType.number` to hint correctly.
- **Do NOT:** Test duration input only with single-digit manual keypresses. Test paste operations: pasting "60", "5:60", "abc:def" must all be handled gracefully.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Text input masking / auto-formatting | Custom keystroke-by-keystroke state machine | `TextInputFormatter` (Flutter built-in) | TextInputFormatter handles edge cases (selection, deletion, paste, undo) that ad-hoc state machines miss. Leverages platform-native behavior. |
| Duration parsing with validation | Manual string splitting + component checking | `parseDurationSeconds()` helper (provided in research) | Centralized, testable, one source of truth. Easy to audit for edge cases. |
| Duration display formatting | Multiple format helpers across codebase | Single `asMinutesSeconds` extension (reuse track_formatting.dart) | One canonical format prevents divergence. Easier to maintain. Consistent UX. |
| Locale-dependent duration display | Date/time format strings | Duration is locale-agnostic (mm:ss format same in all languages). Format at render time, never cache formatted strings. | Duration is numeric, not language-dependent. Cached data stays raw `durationSeconds: int`. |

**Key insight:** Custom input formatting is error-prone because it must handle paste, undo, selection boundaries, and backspace — all edge cases that `TextInputFormatter` handles natively. A 15-line custom formatter is preferable to a fragile 200-line state machine.

## Runtime State Inventory

This is a greenfield feature (no existing duration input to migrate). No runtime state to inventory.

## Common Pitfalls

### Pitfall 1: Format Mismatch Between Input and Display

**What goes wrong:** Duration input auto-formats to "3:45" (mm:ss). But somewhere on screen, duration is displayed as "3m 45s" (words format). User sees two different representations of the same duration and is confused.

**Why it happens:** Codebase has two divergent format conventions: `track_formatting.dart`'s `asMinutesSeconds` (mm:ss) and `setlist_formatting.dart`'s `asMinutesAndSeconds` (words). When duration input is added, if the developer assumes one format but displays use the other, the mismatch is visible.

**How to avoid:** Audit all duration display code before writing the input formatter (grep for `asMinutesSeconds`, `asMinutesAndSeconds`, `formatDuration`, `durationSeconds` in all template strings). Consolidate into one canonical format. Update all callers to use the unified format. Verify no divergent formats remain.

**Warning signs:** `grep -r "asMinutesAndSeconds" lib/` returns matches in setlist files; `grep -r "asMinutesSeconds" lib/` returns matches in track files. This is the evidence that two formats coexist.

**Codebase evidence (VERIFIED from actual files):**
- Track displays use `asMinutesSeconds`: `track_list_screen.dart:120`, `track_detail_screen.dart:96`, `tracks_screen.dart:145` [VERIFIED: these files confirm mm:ss format]
- Setlist displays use `asMinutesAndSeconds`: `setlist_list_screen.dart:138`, `setlist_detail_screen.dart:286, 332, 380`, `tracksAndDuration()` helper in `setlist_formatting.dart:17` [VERIFIED: these files confirm words format]

### Pitfall 2: Invalid Duration Input Accepted ("5:60", "-1:30", etc.)

**What goes wrong:** User enters "5:60" (5 minutes, 60 seconds — invalid). Validator doesn't reject it. App submits durationSeconds: 360 (6 minutes). User intended "5 minutes" but track is stored with wrong duration.

**Why it happens:** Duration parsing with basic split + int.tryParse is lenient. No explicit component validation (seconds must be 0–59). Exception handling masks the real problem.

**How to avoid:** Implement strict validation:
1. Expect exactly 2 parts split by `:`
2. Both parts parse as non-negative integers
3. Seconds component < 60 (critical)
4. Optional: cap minutes at sensible max (e.g., 999)

Add comprehensive test cases: `""`, `":"`, `"0:0"`, `"5:60"`, `"abc:def"`, `"-1:00"`, paste `"60"`. All invalid inputs must be rejected with user-friendly error messages.

**Warning signs:** Manual testing shows "5:60" is silently accepted or auto-corrected to "6:00" (user confusion).

### Pitfall 3: Paste Operations Bypass TextInputFormatter

**What goes wrong:** User copies "2:30" and pastes it into the duration field. The formatter didn't intercept the paste. Field shows "2:30". But if they paste "60" (raw seconds), the formatter doesn't convert it to "1:00", and validator sees unparseable input.

**Why it happens:** `TextInputFormatter` controls keystroke-by-keystroke input, but paste is a bulk operation. Depending on Flutter/platform, paste may or may not trigger `formatEditUpdate()` for each character. The formatter must handle both keystroke and paste flows.

**How to avoid:** The `DurationTextInputFormatter` processes the final text, not individual keystrokes — so paste of "2:30" is handled correctly (parsed as digits, reformatted). Paste of "60" (raw seconds) is also handled (treated as digits, formatted to "1:00" if it's 2 digits).

Test paste operations explicitly: paste "2:30", paste "60", paste "abc", paste "5:60". Verify formatter handles all correctly (first two should be accepted/reformatted, last two rejected or reformatted without error).

### Pitfall 4: Backspace Behavior Unexpected

**What goes wrong:** User types "2:30", then backspaces once. They expect "2:3" but the field shows "0:23" (the formatter deletes the last digit and reformats from right-to-left). User is confused by the non-intuitive behavior.

**Why it happens:** Right-to-left digit shift (stopwatch-style) means each keystroke and backspace affects the full number, not just the current position. This is powerful but non-obvious.

**How to avoid:** This is intentional per D-04. Document it in UI (helper text: "Auto-formats as you type"). Test with actual users: is the right-to-left shift intuitive? If not, consider a different approach (left-to-right digit entry with manual colon, or separate MM and SS fields). For Phase 11, assume D-04's approach is correct and test it during verification.

**Warning signs:** User feedback: "backspace didn't work as expected; the whole field reformatted."

### Pitfall 5: Max Duration Cap at 99:59

**What goes wrong:** User tries to enter a 120-minute track (2 hours). Attempts to type "120:00" or "12000". Formatter caps at "99:59" and rejects further digits. User doesn't understand why they can't enter the value.

**Why it happens:** D-03 caps at 99:59. This is a business decision (no setlist longer than 1h 39m in practice). But the UI doesn't explain the cap, so users find it confusing when their input is silently rejected.

**How to avoid:** This is a design trade-off per D-03. Helper text could say "Duration capped at 99:59" but that's verbose. Rely on the fact that no real-world tracks exceed 2 hours; cap is safety measure more than UX feature. If user tries to exceed cap, formatter silently rejects the keystroke (field doesn't update). Test this behavior and decide if it's acceptable UX or if validation error message should be shown instead.

**Warning signs:** User report: "I tried to enter 120 minutes but the app won't let me."

## Code Examples

### Example 1: DurationTextInputFormatter Implementation

```dart
// Source: Flutter Material Design (TextInputFormatter base class)
// Implementation for track_formatting.dart
import 'package:flutter/services.dart';

class DurationTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Extract only digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Empty input is valid (optional field)
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    
    // Reject input that would exceed 99:59 (5999 seconds)
    // Max 5 digits: "99:59" has only digits "99" and "59" = 4 digits
    // "100:00" would be 5 digits "10000" — reject
    if (digitsOnly.length > 5) {
      return oldValue; // Reject this keystroke; revert to old value
    }
    
    // Format with right-to-left digit shift (stopwatch style)
    String formatted;
    if (digitsOnly.length <= 2) {
      // "2" → "0:02", "23" → "0:23"
      formatted = '0:${digitsOnly.padLeft(2, '0')}';
    } else {
      // "230" → "2:30", "2305" → "23:05"
      final minutes = digitsOnly.substring(0, digitsOnly.length - 2);
      final seconds = digitsOnly.substring(digitsOnly.length - 2);
      formatted = '$minutes:$seconds';
    }
    
    return newValue.copyWith(text: formatted);
  }
}
```

### Example 2: Duration Validator for Form Submit

```dart
// Source: create_track_screen.dart / edit_track_screen.dart
// Extends existing WR-02 pattern
String? _durationValidator(String? value) {
  final text = value?.trim() ?? '';
  
  // Empty field is valid (optional per D-06)
  if (text.isEmpty) return null;
  
  // Expect mm:ss format (formatter should enforce this)
  final parts = text.split(':');
  if (parts.length != 2) {
    return 'Enter duration in mm:ss format (e.g. 0:30)';
  }
  
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  
  // Both components must be valid integers
  if (minutes == null || seconds == null) {
    return 'Enter duration in mm:ss format (e.g. 0:30)';
  }
  
  // Seconds must be in valid range (critical validation)
  if (seconds > 59) {
    return 'Seconds must be 0–59 (e.g. 2:30, not 2:75)';
  }
  
  // Optional: reject negative durations (shouldn't happen with digit-only input)
  if (minutes < 0 || seconds < 0) {
    return 'Duration cannot be negative';
  }
  
  return null; // Valid mm:ss
}
```

### Example 3: Parsing Helper Function

```dart
// Source: track_formatting.dart (co-located with DurationFormatting extension)
/// Converts mm:ss string (e.g. "2:30") to integer seconds (e.g. 150).
/// Returns null for empty string or invalid format (matches D-06 optional behavior).
int? parseDurationSeconds(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null; // Optional field per D-06
  
  final parts = trimmed.split(':');
  if (parts.length != 2) return null; // Expected "mm:ss"
  
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  
  if (minutes == null || seconds == null) return null;
  if (seconds > 59) return null; // Seconds validation
  if (minutes < 0 || seconds < 0) return null; // No negative durations
  
  return minutes * 60 + seconds;
}
```

### Example 4: Usage in Create Track Form

```dart
// Source: create_track_screen.dart _submit() method
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return; // Runs _durationValidator
  
  // ... (existing code for title, artist, etc.)
  
  try {
    await ref.read(publicApiProvider).createBandTrack(
      bandId: widget.bandId,
      title: title,
      artist: artist,
      durationSeconds: parseDurationSeconds(_durationController.text),  // ← USE PARSER HERE
      tempo: int.tryParse(_tempoController.text.trim()),
      key: _selectedKey,
      notes: notes.isEmpty ? null : notes,
    );
    // ... (existing success handling)
  } on ApiException catch (e) {
    // ... (existing error handling)
  }
}
```

### Example 5: TextFormField Wiring

```dart
// Source: create_track_screen.dart (replace existing Duration field)
TextFormField(
  controller: _durationController,
  keyboardType: TextInputType.number,
  inputFormatters: [DurationTextInputFormatter()],  // ← ADD FORMATTER
  decoration: const InputDecoration(
    labelText: 'Duration',  // ← CHANGED from "Duration (seconds)"
    hintText: '0:00',  // ← ADDED: show format to user
    helperText: 'e.g. 2:30 for 2 minutes 30 seconds',  // ← ADDED: optional helper
    border: OutlineInputBorder(),
  ),
  validator: _durationValidator,  // ← CHANGED from _wholeNumberValidator
),
```

### Example 6: Display Format (Existing, No Changes)

```dart
// Source: track_formatting.dart (EXISTING — reuse as-is)
extension DurationFormatting on int {
  String get asMinutesSeconds =>
      '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
}

// Already used correctly in track displays:
// track_list_screen.dart:120
// track_detail_screen.dart:96
// tracks_screen.dart:145

// Adoption for setlist displays (CHANGE these):
// setlist_list_screen.dart:138 — change .asMinutesAndSeconds to .asMinutesSeconds
// setlist_detail_screen.dart:286, 332, 380 — same change
// tracksAndDuration() helper in setlist_formatting.dart:17 — change reference
```

## Validation Architecture

| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in, no new dependency) |
| Config file | `test/widget_test.dart` (existing test structure) |
| Quick run command | `flutter test test/features/tracks/` (tests for track forms) |
| Full suite command | `flutter test` (entire test suite, 401+ tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DUR-01 | Track duration entered as mm:ss in create/edit forms; converts to durationSeconds at submit | Integration | `flutter test test/features/tracks/create_track_screen_test.dart` (coverage of duration field only) | ❌ Wave 0 — new test file required |
| DUR-02 | Invalid mm:ss values rejected with validation feedback (seconds ≥ 60, negative, malformed/incomplete) | Unit | `flutter test test/utils/duration_parser_test.dart` (edge case coverage) | ❌ Wave 0 — new test file for parseDurationSeconds() |
| DUR-03 | Track and setlist duration display uses consistent mm:ss format across all screens | Widget | `flutter test test/features/setlists/setlist_list_screen_test.dart` (display format verification) | ❌ Wave 0 — new test file required |
| DUR-04 | Duration input auto-formats as user types (e.g. "230" → "2:30") | Unit | `flutter test test/widgets/duration_input_formatter_test.dart` (formatter keystroke simulation) | ❌ Wave 0 — new test file for DurationTextInputFormatter |

### Sampling Rate

- **Per task commit:** `flutter test test/features/tracks/ test/features/setlists/` (duration-related screens only)
- **Per wave merge:** `flutter test` (full suite to catch regressions in existing track/setlist tests)
- **Phase gate:** Full suite green + manual testing of duration input UX (auto-format feedback, validation error copy, paste operations)

### Wave 0 Gaps

- [ ] `test/features/tracks/create_track_screen_test.dart` — integration test covering DUR-01 (duration field accepts mm:ss, submits as durationSeconds)
- [ ] `test/features/tracks/edit_track_screen_test.dart` — same as create, for edit flow
- [ ] `test/utils/duration_parser_test.dart` — unit tests for `parseDurationSeconds()` covering DUR-02 edge cases (`""`, `":"`, `"0:0"`, `"5:60"`, `"abc:def"`, `"-1:00"`, `"999:59"`, paste scenarios)
- [ ] `test/widgets/duration_input_formatter_test.dart` — unit tests for `DurationTextInputFormatter` covering DUR-04 keystroke simulation (`"2"` → `"0:02"`, `"230"` → `"2:30"`, backspace behavior, paste operations)
- [ ] `test/features/setlists/setlist_list_screen_test.dart` — widget test verifying DUR-03 (setlist duration displayed as mm:ss, not "Xm Ys", after format unification)
- [ ] `test/features/tracks/track_list_screen_test.dart` — verify track duration still displays as mm:ss (regression test for format consolidation)
- [ ] Update existing `test/features/tracks/` tests if any assert on the old "Duration (seconds)" label or test Duration field directly (search for `_durationController`, `"Duration (seconds)"`, `"whole number"` in test files)
- [ ] Formatter test infrastructure: `flutter test` supports `TextInputFormatter` testing via `TextEditingController.text` manipulation and `formatEditUpdate()` direct calls

**Framework install:**
```bash
flutter test --help  # Verify flutter test works
flutter test test/features/tracks/  # Run subset of tests
flutter test  # Run full suite
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Duration entered as raw seconds (e.g., user types "150" to mean "2:30") | Duration entered as mm:ss with auto-formatting (e.g., user types "230" → field shows "2:30") | Phase 11 (this phase) | UX improvement: users think in minutes:seconds, not raw seconds; auto-format reduces manual colon entry |
| Setlist duration displayed as "42m 35s" (words format) | Setlist duration displayed as "42:35" (mm:ss format, unified with tracks) | Phase 11 (this phase) | Consistency: all screens use same duration format; reduces cognitive load; matches track displays |
| Two separate `DurationFormatting` extensions (track vs. setlist) | Single `DurationFormatting.asMinutesSeconds` extension reused across codebase | Phase 11 (this phase) | Maintainability: one format convention; easier to change format globally if needed |
| Manual integer parsing in form submit (e.g., `int.tryParse()` with no validation) | Centralized `parseDurationSeconds()` helper with strict validation | Phase 11 (this phase) | Robustness: validation in one place; testable; edge cases documented |

**Deprecated/outdated:**
- `asMinutesAndSeconds` extension in `setlist_formatting.dart`: Retired in Phase 11. Callers migrated to `asMinutesSeconds`. Grep should return zero matches post-Phase 11.
- Raw-seconds duration input in create/edit forms: Replaced by mm:ss input with auto-formatting. Users never type raw seconds again.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `DurationTextInputFormatter` using `TextEditingValue.copyWith()` correctly handles both keystroke and paste input | Standard Stack / Code Examples | If paste is not intercepted/reformatted, pasted values bypass formatter; user pastes "60" expecting "1:00" but field shows "60:00" (parse error) |
| A2 | Flutter's `TextInputFormatter` API is stable and widely used in production Flutter apps | Standard Stack | If API is unstable or deprecated, custom solution may be required; but TextInputFormatter is core to Material Design and stable since Flutter 1.0 |
| A3 | `int.tryParse()` handles all edge cases (empty string, non-numeric, etc.) as expected | Code Examples | If behavior differs across Dart versions, validation edge cases may slip; but tryParse is well-documented and stable |
| A4 | Existing `DurationFormatting.asMinutesSeconds` extension works correctly for unbounded minutes (e.g., "72:15" for 72-min setlist) | Architecture Patterns | If extension has a bug or edge case, display format may be wrong; but extension is already in use for track displays and working |
| A5 | Form validation pattern (WR-02 `_wholeNumberValidator`) can be extended to `_durationValidator` without breaking existing validation flow | Code Examples | If validator ordering or error display changes, new validator may not show errors correctly; but existing pattern is proven in track/tempo fields |
| A6 | No external packages (mask_text_input_formatter, etc.) are preferred per CONTEXT.md D-02 and CLAUDE.md "minimize dependencies" | Standard Stack | If custom formatter is too complex or error-prone, third-party package may become necessary; but 15-line formatter is simple and tested |
| A7 | Setlist displays currently use `asMinutesAndSeconds` in exactly the locations identified by grep (setlist_list_screen.dart:138, setlist_detail_screen.dart:286/332/380, tracksAndDuration() helper) | Architecture Patterns | If grep results are incomplete, format migration may miss locations; UI will show mixed formats in production; but grep results were verified against actual files |
| A8 | `parseDurationSeconds()` helper correctly converts "mm:ss" to seconds for all valid inputs (0:00 to 99:59) | Code Examples | If conversion is wrong, API receives incorrect durationSeconds; tracks stored with wrong duration | Tested thoroughly in Wave 0 unit tests |
| A9 | Backspace behavior (right-to-left digit deletion + reformat) per D-04 is acceptable UX | Common Pitfalls | If users find right-to-left shift confusing, manual testing will reveal dissatisfaction; but this is a locked decision and will be tested during verification |

---

## Open Questions

1. **Paste handling behavior — does TextInputFormatter intercept paste on all platforms?**
   - What we know: Android and iOS have different paste behaviors; Web may use a different input mechanism.
   - What's unclear: Does `TextEditingValue.copyWith()` in `formatEditUpdate()` capture pasted text on all platforms?
   - Recommendation: Test paste operations during Wave 0 widget test (iOS simulator, Android emulator, and if web is in scope, web browser). If formatter doesn't intercept paste on a specific platform, add a platform-specific workaround or document the limitation.

2. **Max duration cap at 99:59 — should validation error be shown if user tries to exceed?**
   - What we know: D-03 caps at 99:59. Formatter silently rejects keystrokes that would exceed.
   - What's unclear: Should user see an error message ("Duration capped at 99:59") or is silent rejection (field doesn't update) acceptable?
   - Recommendation: Test with actual users during verification phase. If silent rejection is confusing, add a `helperText` ("Max 99:59") or show a tooltip on rejection. This is a UX call, not a technical decision.

3. **Internationalization of validation error copy — when Phase 12 (i18n) ships, these error messages need to be localized.**
   - What we know: Phase 11 is i18n-independent (CONTEXT.md D-01 notes Phase 11 has no dependency on Phase 12).
   - What's unclear: Should Phase 11's error messages be hardcoded English now, or set up as i18n keys to be filled in by Phase 12?
   - Recommendation: Hardcode English now; Phase 12 will extract these strings to ARB files as part of the string-extraction sweep (no special handling needed). This keeps Phase 11 self-contained.

---

## Environment Availability

No external services or CLI tools required for this phase. All functionality is client-side.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | UI framework | ✓ | Latest stable | — |
| Dart SDK | Language | ✓ | 3.12.2+ | — |
| flutter_test | Widget/Unit tests | ✓ | Built-in | — |

**Missing dependencies:** None.

---

## Security Domain

**Applicable ASVS Categories**

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | Strict mm:ss format validation (seconds 0–59, no negative durations) |
| V6 Cryptography | no | Duration is numeric, no cryptographic operations |
| V1 Architecture | partially | Input validation at form boundary before API submission (no data tampering via malformed input) |

### Known Threat Patterns for Duration Input

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Negative duration input (e.g., "-1:30") | Tampering | Validate minutes >= 0 and seconds >= 0; reject negative input |
| Seconds ≥ 60 (e.g., "5:60") | Tampering | Validate seconds < 60 in both formatter and validator |
| Excessively large durations (e.g., "999999:59") | Denial of Service (memory/storage) | Cap at 99:59 via formatter; API contract caps durationSeconds as int (max ~2.1 billion seconds = ~68 years, acceptable) |
| API injection via duration field (e.g., SQL if backend is vulnerable) | Injection | Not applicable — `durationSeconds` is an int, not a string. Backend receives integer value only. No SQL injection vector via this field. |
| Bypass of input validation via paste (e.g., paste "5:60" and formatter doesn't catch it) | Tampering | Comprehensive validator covers both keystroke and paste cases; test paste operations in Wave 0 |

---

## Sources

### Primary (HIGH confidence)
- [Flutter TextInputFormatter Documentation](https://api.flutter.dev/flutter/services/TextInputFormatter-class.html) — Official API reference, shows `formatEditUpdate()` signature and behavior
- [Flutter Material TextFormField](https://api.flutter.dev/flutter/material/TextFormField-class.html) — Official Material widget; `inputFormatters` parameter accepts list of `TextInputFormatter`
- [Cadence codebase](file:///home/bulat.khafizov/projects/personal/cadence/client) — Verified existing duration formatting patterns and create/edit track form structure
  - `lib/features/tracks/track_formatting.dart` — existing `DurationFormatting.asMinutesSeconds` extension [VERIFIED: lines 1–5]
  - `lib/features/setlists/setlist_formatting.dart` — existing `asMinutesAndSeconds` extension [VERIFIED: lines 1–18]
  - `lib/features/tracks/create_track_screen.dart` — existing form structure, `_wholeNumberValidator` pattern [VERIFIED: lines 19–97, 137–145]
  - `lib/features/tracks/edit_track_screen.dart` — identical form structure [VERIFIED: lines 29–78, 191–199]
  - Grep results for duration display across all screens [VERIFIED: 11-RESEARCH.md "Codebase evidence" section]

### Secondary (MEDIUM confidence)
- [Flutter Testing Documentation](https://docs.flutter.dev/testing/overview) — Widget and unit test patterns for `TextInputFormatter` testing
- [PITFALLS.md](file:///home/bulat.khafizov/projects/personal/cadence/client/.planning/research/PITFALLS.md) — Project-specific pitfalls research, Pitfall #5 (Duration Input Parsing) and Pitfall #9 (Duration Display Format Mismatch) [CITED: .planning/research/PITFALLS.md]
- [SUMMARY.md](file:///home/bulat.khafizov/projects/personal/cadence/client/.planning/research/SUMMARY.md) — Phase B recommendations and architecture approach [CITED: .planning/research/SUMMARY.md]

### Tertiary (LOW confidence)
- General Flutter best practices for text input masking (training knowledge, not verified this session) [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Flutter's TextInputFormatter is core, stable, and widely used. Zero external dependencies required. Verified against current project pubspec.yaml.
- Architecture: HIGH — Patterns mirror existing create/edit form structure (WR-02 validator pattern, TextFormField wiring) and existing duration formatting (asMinutesSeconds extension). No new state management or dependency injection needed.
- Code examples: HIGH — All examples are based on Flutter official documentation and verified against actual codebase patterns.
- Pitfalls: HIGH — Based on research team's analysis of this specific codebase (401 tests, Riverpod architecture, Hive cache, existing duration format divergence) and general Flutter input-masking patterns.

**Research date:** 2026-08-25
**Valid until:** 2026-09-25 (stable feature, no rapid API changes expected in Flutter core)
**Reviewed against CONTEXT.md:** Yes — all locked decisions (D-01 through D-06) addressed and reflected in research

---

*Phase 11: Duration mm:ss Input + Display*
*Research completed: 2026-08-25*
*Ready for planning: Yes*
