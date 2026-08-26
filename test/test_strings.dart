import 'package:cadence/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exposes the live [AppLocalizations] instance off the pumped widget tree
/// via `tester.strings.someKey`, so widget tests assert against the same
/// ARB-backed strings the app itself renders instead of hardcoded English
/// literals (D-05/D-06/D-08). Because this returns the live instance, its
/// ICU plural methods (`memberCount`/`trackCount`/`slotCount`) are
/// automatically available as `tester.strings.memberCount(n)` with no extra
/// wiring.
extension StringsExtension on WidgetTester {
  AppLocalizations get strings {
    final textFinder = find.byType(Text);
    if (textFinder.evaluate().isEmpty) {
      throw StateError(
        'tester.strings could not find any Text widget in the pumped tree '
        'to read AppLocalizations off of -- every in-scope screen/dialog '
        'renders at least one Text widget, so this usually means the tree '
        'was not pumped yet or the screen under test rendered nothing.',
      );
    }
    // Element implements BuildContext directly (it IS a BuildContext, not a
    // wrapper with a `.context` field), so it is passed straight through.
    return AppLocalizations.of(element(textFinder.first))!;
  }
}
