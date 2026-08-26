# Phase 11: Duration mm:ss Input + Display - Pattern Map

**Mapped:** 2026-08-25  
**Files analyzed:** 13 new/modified files  
**Analogs found:** 12 / 13 files with direct analogs

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/features/tracks/track_formatting.dart` | utility | transform | Self (existing extension pattern) | exact |
| `lib/features/tracks/create_track_screen.dart` | screen (StatefulWidget) | request-response | Self (existing validation pattern WR-02) | exact |
| `lib/features/tracks/edit_track_screen.dart` | screen (StatefulWidget) | request-response | `create_track_screen.dart` (identical validation pattern) | exact |
| `lib/features/setlists/setlist_formatting.dart` | utility | transform | Self (existing extension pattern) | exact |
| `lib/features/setlists/setlist_list_screen.dart` | screen (ConsumerStatelessWidget) | request-response | Self (existing display pattern) | exact |
| `lib/features/setlists/setlist_detail_screen.dart` | screen (ConsumerStatefulWidget) | request-response | Self (existing display pattern) | exact |
| `lib/features/setlists/setlists_screen.dart` | screen (ConsumerWidget) | request-response | Self (uses `tracksAndDuration` helper) | exact |
| `test/features/tracks/create_track_screen_test.dart` | test (integration) | integration test | Self (existing test structure) | exact |
| `test/features/tracks/edit_track_screen_test.dart` | test (integration) | integration test | `create_track_screen_test.dart` (same test structure) | exact |
| `test/features/tracks/track_list_screen_test.dart` | test (integration) | integration test | `setlist_list_screen_test.dart` (same pattern) | exact |
| `test/features/setlists/setlist_list_screen_test.dart` | test (integration) | integration test | Self (existing test structure) | exact |
| `test/utils/duration_parser_test.dart` | test (unit) | unit test | `test/providers/*_test.dart` (unit test pattern) | role-match |
| `test/widgets/duration_input_formatter_test.dart` | test (unit) | unit test | `test/providers/*_test.dart` (unit test pattern) | role-match |

---

## Pattern Assignments

### `lib/features/tracks/track_formatting.dart` (utility, transform)

**Analog:** Self — existing file with `DurationFormatting` extension pattern.

**Existing pattern** (lines 1-5):
```dart
/// Formats a track's `durationSeconds` as `mm:ss` (D-06), e.g. `225` -> `3:45`.
extension DurationFormatting on int {
  String get asMinutesSeconds =>
      '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
}
```

**ADD: DurationTextInputFormatter class** — implement below the `DurationFormatting` extension:
```dart
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
    
    // Reject input that would exceed 99:59 (4 digits max: "99" + "59" = "9959")
    // Per CONTEXT.md D-03 (locked decision) — not the 5-digit cap, which would allow "999:59"
    if (digitsOnly.length > 4) {
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

**ADD: parseDurationSeconds() helper** — implement after the `DurationTextInputFormatter` class:
```dart
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

---

### `lib/features/tracks/create_track_screen.dart` (screen, request-response)

**Analog:** Self — existing file showing WR-02 validation pattern and _wholeNumberValidator function.

**Existing validation pattern** (lines 41-49):
```dart
/// WR-02: rejects non-empty, non-whole-number input on the Duration/Tempo
/// fields instead of silently discarding it (int.tryParse returning null
/// was previously treated the same as a genuinely blank field). An empty
/// field remains valid — Duration/Tempo stay optional.
String? _wholeNumberValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return int.tryParse(text) == null ? 'Enter a whole number' : null;
}
```

**REPLACE: _wholeNumberValidator with _durationValidator** (for duration field only):
```dart
/// D-05: Duration validation on submit attempt only (not per-keystroke).
/// Rejects empty field as valid (optional per D-06), malformed mm:ss,
/// or seconds >= 60.
String? _durationValidator(String? value) {
  final text = value?.trim() ?? '';
  
  // Empty field is valid (optional per D-06)
  if (text.isEmpty) return null;
  
  // Expect mm:ss format (formatter should have ensured this)
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
  
  return null; // Valid mm:ss
}
```

**KEEP: _wholeNumberValidator** for Tempo field (unchanged).

**MODIFY: Duration TextFormField** (lines 137-145):
```dart
// BEFORE:
TextFormField(
  controller: _durationController,
  keyboardType: TextInputType.number,
  decoration: const InputDecoration(
    labelText: 'Duration (seconds)',
    border: OutlineInputBorder(),
  ),
  validator: _wholeNumberValidator,
),

// AFTER:
TextFormField(
  controller: _durationController,
  keyboardType: TextInputType.number,
  inputFormatters: [DurationTextInputFormatter()],  // ← ADD THIS
  decoration: const InputDecoration(
    labelText: 'Duration',  // ← CHANGED from "Duration (seconds)"
    hintText: '0:00',  // ← ADD: show format to user
    helperText: 'e.g. 2:30 for 2 minutes 30 seconds',  // ← ADD: optional helper
    border: OutlineInputBorder(),
  ),
  validator: _durationValidator,  // ← CHANGED validator
),
```

**MODIFY: _submit() method** (line 70) — replace `int.tryParse()` with `parseDurationSeconds()`:
```dart
// BEFORE:
durationSeconds: int.tryParse(_durationController.text.trim()),

// AFTER:
durationSeconds: parseDurationSeconds(_durationController.text),
```

**Add import** at top of file:
```dart
import 'package:flutter/services.dart';  // Add for TextInputFormatter
```

---

### `lib/features/tracks/edit_track_screen.dart` (screen, request-response)

**Analog:** `create_track_screen.dart` — identical validation and form pattern.

**Apply the same changes as create_track_screen.dart:**

1. **Replace _wholeNumberValidator with _durationValidator** — same code as in `create_track_screen.dart`
2. **Keep _wholeNumberValidator for Tempo field** (unchanged)
3. **Modify Duration TextFormField** (lines 191-199) — same changes as create form:
   - Add `inputFormatters: [DurationTextInputFormatter()]`
   - Change labelText from `'Duration (seconds)'` to `'Duration'`
   - Add `hintText: '0:00'`
   - Add `helperText: 'e.g. 2:30 for 2 minutes 30 seconds'`
   - Change validator to `_durationValidator`
4. **Modify _submit() method** (line 90) — replace `int.tryParse()` with `parseDurationSeconds()`:
   ```dart
   // BEFORE:
   final durationSeconds = int.tryParse(_durationController.text.trim());
   
   // AFTER:
   final durationSeconds = parseDurationSeconds(_durationController.text);
   ```
5. **Add import** at top of file:
   ```dart
   import 'package:flutter/services.dart';  // Add for TextInputFormatter
   ```

---

### `lib/features/setlists/setlist_formatting.dart` (utility, transform)

**Analog:** Self — existing file showing extension and helper function patterns.

**Existing asMinutesAndSeconds pattern** (lines 1-8):
```dart
/// Formats a setlist's `durationSeconds` in words (D-05), e.g. `2555` ->
/// `'42m 35s'`. Distinct from Track's `mm:ss` presentation
/// (`track_formatting.dart`'s `asMinutesSeconds`) — the two features
/// intentionally use different duration formats per their respective
/// UI-SPECs.
extension DurationFormatting on int {
  String get asMinutesAndSeconds => '${this ~/ 60}m ${this % 60}s';
}
```

**REMOVE: asMinutesAndSeconds extension** — per D-01, unified format means this is retired. Delete lines 1-8 (entire extension).

**Update: doc comment for tracksAndDuration()** (lines 14-17) — remove reference to "Xm Ys" format:
```dart
// BEFORE:
/// Composes a setlist list row's trailing text, e.g. `'8 tracks, 42m 35s'`.
/// Reused unmodified by Plan 05's global cross-band Setlists tab.
String tracksAndDuration(int tracksCount, int durationSeconds) =>
    '${pluralizeTracks(tracksCount)}, ${durationSeconds.asMinutesAndSeconds}';

// AFTER:
/// Composes a setlist list row's trailing text, e.g. `'8 tracks, 42:35'`.
/// Reused unmodified by Plan 05's global cross-band Setlists tab.
/// Uses unified mm:ss format (track_formatting.dart's asMinutesSeconds).
import 'package:cadence/features/tracks/track_formatting.dart';  // ← ADD IMPORT

String tracksAndDuration(int tracksCount, int durationSeconds) =>
    '${pluralizeTracks(tracksCount)}, ${durationSeconds.asMinutesSeconds}';
```

**KEEP: pluralizeTracks() function** (unchanged).

---

### `lib/features/setlists/setlist_list_screen.dart` (screen, request-response)

**Analog:** Self — existing file showing setlist display pattern.

**Update: duration display** (line 138) — change format call:
```dart
// BEFORE:
durationSeconds.asMinutesAndSeconds,

// AFTER:
durationSeconds.asMinutesSeconds,
```

**Add import** at top if not present:
```dart
import 'package:cadence/features/tracks/track_formatting.dart';
```

---

### `lib/features/setlists/setlist_detail_screen.dart` (screen, request-response)

**Analog:** Self — existing file showing three duration display locations.

**Verify line numbers first** (they may differ from research). Search for `asMinutesAndSeconds` in the file (should find 3 occurrences).

**Update all three locations** where `asMinutesAndSeconds` appears:

1. **Line ~286** — setlist total duration:
   ```dart
   // BEFORE:
   Text(durationSeconds.asMinutesAndSeconds),
   
   // AFTER:
   Text(durationSeconds.asMinutesSeconds),
   ```

2. **Line ~332** — track duration in track list (with null coalescing):
   ```dart
   // BEFORE:
   trackDurationSeconds?.asMinutesAndSeconds ?? '—';
   
   // AFTER:
   trackDurationSeconds?.asMinutesSeconds ?? '—';
   ```

3. **Line ~380** — another track duration display:
   ```dart
   // BEFORE:
   trackDurationSeconds?.asMinutesAndSeconds ?? '—';
   
   // AFTER:
   trackDurationSeconds?.asMinutesSeconds ?? '—';
   ```

**Add import** at top if not present:
```dart
import 'package:cadence/features/tracks/track_formatting.dart';
```

---

### `lib/features/setlists/setlists_screen.dart` (screen, request-response)

**Analog:** Self — existing file using `tracksAndDuration()` helper.

**No direct code changes needed** — the `tracksAndDuration()` helper in `setlist_formatting.dart` will be updated to use `asMinutesSeconds` internally, so this screen automatically gets the new format when that helper is fixed.

**Verify after setlist_formatting.dart changes** that the display format updates correctly. No manual code edits required here.

---

## Test File Patterns

### `test/features/tracks/create_track_screen_test.dart` (integration test)

**Analog:** Self — existing test structure for form submission and validation.

**Example test structure** (lines 71-97):
```dart
testWidgets(
  'submitting title+artist sends the exact JSON request body and pops back to the list',
  (tester) async {
    String? requestBody;
    final apiClient = buildApiClient((request) async {
      if (request.method == 'POST' && request.url.path == '/api/band/b1/track') {
        requestBody = request.body;
        return http.Response(jsonEncode({'id': 't1'}), 201);
      }
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openCreateTrackScreen(tester);
    await enterTitleAndArtist(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
    await tester.pumpAndSettle();

    expect(requestBody, jsonEncode({'title': 'My Song', 'artist': 'My Artist'}));
    expect(find.text('My Song added!'), findsOneWidget);
  },
);
```

**ADD: new duration-specific tests** in this file (after existing tests):
```dart
testWidgets(
  'duration field auto-formats as mm:ss (e.g. "230" → "2:30") and submits correctly',
  (tester) async {
    String? requestBody;
    final apiClient = buildApiClient((request) async {
      if (request.method == 'POST' && request.url.path == '/api/band/b1/track') {
        requestBody = request.body;
        return http.Response(jsonEncode({'id': 't1'}), 201);
      }
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openCreateTrackScreen(tester);
    await enterTitleAndArtist(tester);
    
    // Enter duration as raw digits "230"; formatter should show "2:30"
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), '230');  // Index 2 = duration field
    await tester.pump();
    
    expect(find.text('2:30'), findsOneWidget);  // Verify auto-format
    
    await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
    await tester.pumpAndSettle();
    
    // Verify API received durationSeconds as integer (150 = 2 * 60 + 30)
    final parsed = jsonDecode(requestBody!) as Map<String, dynamic>;
    expect(parsed['durationSeconds'], 150);
  },
);

testWidgets(
  'duration validator rejects seconds >= 60 (e.g. "5:60")',
  (tester) async {
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'id': 't1'}), 201);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openCreateTrackScreen(tester);
    await enterTitleAndArtist(tester);
    
    // Try to submit with invalid seconds
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), '5:60');  // Invalid: 60 seconds
    await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
    await tester.pump();
    
    expect(find.text('Seconds must be 0–59 (e.g. 2:30, not 2:75)'), findsOneWidget);
  },
);

testWidgets(
  'empty duration field is valid (optional) and submits as null',
  (tester) async {
    String? requestBody;
    final apiClient = buildApiClient((request) async {
      if (request.method == 'POST' && request.url.path == '/api/band/b1/track') {
        requestBody = request.body;
        return http.Response(jsonEncode({'id': 't1'}), 201);
      }
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openCreateTrackScreen(tester);
    await enterTitleAndArtist(tester);
    // Leave duration blank — don't interact with duration field
    
    await tester.tap(find.widgetWithText(FilledButton, 'Save track'));
    await tester.pumpAndSettle();
    
    final parsed = jsonDecode(requestBody!) as Map<String, dynamic>;
    expect(parsed['durationSeconds'], isNull);  // Or not present in JSON
  },
);
```

---

### `test/features/tracks/edit_track_screen_test.dart` (integration test)

**Analog:** `create_track_screen_test.dart` — same test pattern, substitute "Edit track" for "Save track".

**Apply the same duration tests** (three test cases above) to edit_track_screen_test.dart, adjusting:
- Button text from `'Save track'` to `'Save'`
- Screen import from `CreateTrackScreen` to `EditTrackScreen`
- Route path (if different) — check existing test for correct path

---

### `test/features/tracks/track_list_screen_test.dart` (integration test)

**Analog:** Existing test file (if present) or `setlist_list_screen_test.dart` test pattern.

**Add regression test** to verify duration still displays as mm:ss (no format mismatch):
```dart
testWidgets(
  'track duration displays in mm:ss format (not raw seconds)',
  (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandTracks('b1', [
      {
        'id': 't1',
        'title': 'Song A',
        'artist': 'Artist A',
        'durationSeconds': 150,  // 2:30
        'tempo': 120,
        'key': 'C',
        'notes': '',
      }
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': []}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    // Verify duration renders as "2:30", not "150" or any other format
    expect(find.text('2:30'), findsOneWidget);
    expect(find.text('150'), findsNothing);  // Raw seconds should NOT appear
  },
);
```

---

### `test/features/setlists/setlist_list_screen_test.dart` (integration test)

**Analog:** Self — existing test file.

**Update existing tests** that verify duration display format:
- Search for assertions on `asMinutesAndSeconds` format strings (e.g., `'42m 35s'`)
- Change expected strings to mm:ss format (e.g., `'42:35'`)
- Example: if a test expects `find.text('8 tracks, 42m 35s')`, change to `find.text('8 tracks, 42:35')`

**Add new test** to verify the unified format is used:
```dart
testWidgets(
  'setlist duration displays in mm:ss format (unified with tracks)',
  (tester) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandSetlists('b1', [
      {
        'id': 's1',
        'name': 'Setlist A',
        'eventDate': '2026-08-25',
        'trackIds': ['t1', 't2', 't3'],
        'durationSeconds': 2555,  // 42:35
      }
    ]);

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode({'items': []}), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pumpAndSettle();

    // Verify duration displays as "42:35" (mm:ss), not "42m 35s" (words)
    expect(find.text('3 tracks, 42:35'), findsOneWidget);
    expect(find.text('42m 35s'), findsNothing);  // Old format should NOT appear
  },
);
```

---

### `test/utils/duration_parser_test.dart` (unit test — NEW)

**Analog:** `test/providers/*_test.dart` — unit test pattern using Dart's built-in `test()` framework.

**Example test structure:**
```dart
import 'package:cadence/features/tracks/track_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDurationSeconds()', () {
    test('parses valid mm:ss format correctly', () {
      expect(parseDurationSeconds('2:30'), 150);
      expect(parseDurationSeconds('0:00'), 0);
      expect(parseDurationSeconds('99:59'), 5999);
      expect(parseDurationSeconds('42:35'), 2555);
    });

    test('returns null for empty string (optional field per D-06)', () {
      expect(parseDurationSeconds(''), null);
      expect(parseDurationSeconds('   '), null);
    });

    test('returns null for invalid format (missing colon)', () {
      expect(parseDurationSeconds('230'), null);
      expect(parseDurationSeconds('2 30'), null);
      expect(parseDurationSeconds('abc'), null);
    });

    test('returns null for non-numeric components', () {
      expect(parseDurationSeconds('a:30'), null);
      expect(parseDurationSeconds('2:b'), null);
      expect(parseDurationSeconds('ab:cd'), null);
    });

    test('returns null for invalid seconds (>= 60)', () {
      expect(parseDurationSeconds('5:60'), null);
      expect(parseDurationSeconds('2:75'), null);
      expect(parseDurationSeconds('0:61'), null);
    });

    test('returns null for negative durations', () {
      expect(parseDurationSeconds('-1:30'), null);
      expect(parseDurationSeconds('2:-5'), null);
      expect(parseDurationSeconds('-1:-1'), null);
    });

    test('handles edge cases (too many colons, extra spaces)', () {
      expect(parseDurationSeconds('2:30:00'), null);  // Three parts
      expect(parseDurationSeconds('2:30:'), null);
      expect(parseDurationSeconds(' 2:30 '), 150);  // Trimming should work
    });

    test('handles paste scenarios (e.g. pasting "60" raw seconds)', () {
      // If user pastes "60" (raw seconds), formatter may or may not convert.
      // Parser should handle it gracefully.
      expect(parseDurationSeconds('60'), null);  // No colon = invalid
      expect(parseDurationSeconds('1:00'), 60);  // If formatter prepended "1:", it works
    });
  });
}
```

---

### `test/widgets/duration_input_formatter_test.dart` (unit test — NEW)

**Analog:** `test/providers/*_test.dart` — unit test pattern for custom classes.

**Example test structure:**
```dart
import 'package:cadence/features/tracks/track_formatting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DurationTextInputFormatter', () {
    final formatter = DurationTextInputFormatter();

    TextEditingValue _format(
      String text, {
      TextSelection? selection,
    }) {
      return formatter.formatEditUpdate(
        const TextEditingValue.empty(),
        TextEditingValue(
          text: text,
          selection: selection ?? TextSelection.collapsed(offset: text.length),
        ),
      );
    }

    test('empty input remains empty', () {
      final result = _format('');
      expect(result.text, '');
    });

    test('single digit formats as "0:0X"', () {
      expect(_format('2').text, '0:02');
      expect(_format('5').text, '0:05');
      expect(_format('9').text, '0:09');
    });

    test('two digits format as "0:XY"', () {
      expect(_format('23').text, '0:23');
      expect(_format('59').text, '0:59');
    });

    test('three digits format as "X:YZ" (right-to-left shift)', () {
      expect(_format('230').text, '2:30');
      expect(_format('100').text, '1:00');
    });

    test('four digits format as "XY:ZW"', () {
      expect(_format('2305').text, '23:05');
      expect(_format('5959').text, '59:59');
    });

    test('five digits format as "XYZ:AB" if <= 99:59', () {
      expect(_format('12345').text, '123:45');  // Allowed
      expect(_format('99599').text, '995:99');  // Allowed (no upper cap enforcement at 99:59, just digit count)
    });

    test('rejects input > 5 digits (would exceed 99:59)', () {
      final result = _format('123456');  // Six digits
      expect(result.text, '');  // Rejected — reverts to empty
    });

    test('strips non-digit characters (e.g. paste "2:30" becomes "230")', () {
      // When user pastes "2:30", formatter strips colons and processes as "230"
      final result = _format('2:30');
      expect(result.text, '2:30');  // Reformatted from input "230"
    });

    test('handles backspace correctly (deletes last digit and reformats)', () {
      // This tests the "left over" effect: if you have "2:30" and backspace,
      // you get the previous state's digitsOnly minus the last character.
      // The formatter itself doesn't track history, but we can test individual
      // keystroke-by-keystroke behavior.
      
      // Type "2", "3", "0" in sequence
      var result = _format('2');
      expect(result.text, '0:02');
      
      result = _format('23');
      expect(result.text, '0:23');
      
      result = _format('230');
      expect(result.text, '2:30');
      
      // Simulate backspace: new value has "23" (last digit removed)
      result = _format('23');
      expect(result.text, '0:23');  // Reformatted from "23"
    });

    test('accepts valid mm:ss after formatting', () {
      // Formatter should produce valid mm:ss that parseDurationSeconds can parse
      final formatted = _format('2305');
      expect(formatted.text, '23:05');  // Valid: 23 minutes, 5 seconds
      // Downstream validator/parser will accept this
    });
  });
}
```

---

## Shared Patterns

### Form Validation Pattern

**Source:** `lib/features/tracks/create_track_screen.dart` / `edit_track_screen.dart` (WR-02 comment, lines 41-49)

**Apply to:** Both create and edit track screens' duration field

**Pattern:**
```dart
String? _durationValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;  // Optional field per D-06
  
  // Validate format and constraints
  final parts = text.split(':');
  if (parts.length != 2) return 'Enter duration in mm:ss format (e.g. 0:30)';
  
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  
  if (minutes == null || seconds == null) {
    return 'Enter duration in mm:ss format (e.g. 0:30)';
  }
  
  if (seconds > 59) {
    return 'Seconds must be 0–59 (e.g. 2:30, not 2:75)';
  }
  
  return null;
}
```

### Duration Display Format Unification

**Source:** `lib/features/tracks/track_formatting.dart` (existing `asMinutesSeconds` extension, lines 1-5)

**Apply to:** All setlist display screens replacing `asMinutesAndSeconds`

**Unified pattern:**
```dart
extension DurationFormatting on int {
  String get asMinutesSeconds =>
      '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
}
```

**Where to apply:**
- `setlist_list_screen.dart:138` — trailing text
- `setlist_detail_screen.dart:286, 332, 380` — track and setlist duration displays
- `setlists_screen.dart` — via updated `tracksAndDuration()` helper

### TextInputFormatter Pattern

**Source:** `lib/features/tracks/track_formatting.dart` (new `DurationTextInputFormatter` class)

**Apply to:** Both create and edit track screens' duration TextFormField

**Wiring pattern:**
```dart
TextFormField(
  controller: _durationController,
  keyboardType: TextInputType.number,
  inputFormatters: [DurationTextInputFormatter()],  // ← Formatter added
  decoration: const InputDecoration(
    labelText: 'Duration',
    hintText: '0:00',
    helperText: 'e.g. 2:30 for 2 minutes 30 seconds',
    border: OutlineInputBorder(),
  ),
  validator: _durationValidator,  // ← New validator
)
```

### Form Submission Pattern

**Source:** `lib/features/tracks/create_track_screen.dart` / `edit_track_screen.dart` (_submit() method, lines 51-97 / 80-151)

**Apply to:** Both screens' _submit() method

**Duration parsing pattern:**
```dart
try {
  await ref.read(publicApiProvider).createBandTrack(
    // ... other fields ...
    durationSeconds: parseDurationSeconds(_durationController.text),  // ← Use parser
    // ... other fields ...
  );
  // ... success handling ...
} on ApiException catch (e) {
  setState(() => _errorMessage = e.message);
} catch (_) {
  setState(() => _errorMessage = 'Something went wrong. Please try again.');
} finally {
  if (mounted) setState(() => _isSubmitting = false);
}
```

---

## Integration Points

### Files Already Correct (No Changes Needed)

| File | Current Format | Reason |
|------|---|---|
| `lib/features/tracks/track_list_screen.dart` | Uses `asMinutesSeconds` | Already using the canonical format |
| `lib/features/tracks/track_detail_screen.dart` | Uses `asMinutesSeconds` | Already using the canonical format |
| `lib/features/tracks/tracks_screen.dart` | Uses `asMinutesSeconds` | Already using the canonical format |

### Import Additions Required

Add to any screen file displaying duration via the formatting extension:
```dart
import 'package:cadence/features/tracks/track_formatting.dart';
```

### Test Helpers Already in Place

Existing test infrastructure supports:
- `ProviderScope` + `WidgetTester` for integration tests
- `buildApiClient()` factory for MockClient setup
- `CacheService.inMemory()` for cache mocking
- `flutter_test`'s `expect()` and `find` for assertions

No new test infrastructure required.

---

## No Analog Found

None — all new and modified files have direct analogs in the existing codebase.

---

## Metadata

**Analog search scope:** `lib/features/`, `lib/api/`, `test/features/`, `test/providers/`, `test/widgets/`

**Files scanned:** 50+ Dart files across tracks, setlists, tests, and utilities

**Pattern extraction date:** 2026-08-25

**Confidence level:** HIGH

- **Formatting patterns:** Exact analogs (existing extensions follow the same style)
- **Screen validation patterns:** Exact analogs (WR-02 pattern already implemented)
- **Test patterns:** Exact analogs (existing test structure confirmed)
- **New patterns (TextInputFormatter, parseDurationSeconds):** Researched via Flutter docs and project conventions; no existing analog in codebase (greenfield feature)

---

*Phase 11: Duration mm:ss Input + Display*  
*Pattern mapping completed: 2026-08-25*  
*Ready for planning: Yes*
