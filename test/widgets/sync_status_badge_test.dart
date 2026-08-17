import 'package:cadence/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(DateTime? syncedAt) {
    return MaterialApp(
      home: Scaffold(body: SyncStatusBadge(syncedAt: syncedAt)),
    );
  }

  testWidgets('syncedAt null renders no icon/text', (tester) async {
    await tester.pumpWidget(wrap(null));

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('syncedAt 5 minutes ago renders nothing', (tester) async {
    await tester.pumpWidget(
      wrap(DateTime.now().subtract(const Duration(minutes: 5))),
    );

    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('syncedAt exactly 10 minutes ago renders "Synced 10m ago"', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(DateTime.now().subtract(const Duration(minutes: 10))),
    );

    expect(find.textContaining('Synced 10m ago'), findsOneWidget);
  });

  testWidgets(
    'syncedAt 29 minutes ago renders in onSurfaceVariant color (not error)',
    (tester) async {
      await tester.pumpWidget(
        wrap(DateTime.now().subtract(const Duration(minutes: 29))),
      );

      final context = tester.element(find.byType(SyncStatusBadge));
      final colorScheme = Theme.of(context).colorScheme;

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, colorScheme.onSurfaceVariant);
      expect(icon.icon, Icons.cloud_done);
    },
  );

  testWidgets(
    'syncedAt exactly 30 minutes ago renders in error color',
    (tester) async {
      await tester.pumpWidget(
        wrap(DateTime.now().subtract(const Duration(minutes: 30))),
      );

      final context = tester.element(find.byType(SyncStatusBadge));
      final colorScheme = Theme.of(context).colorScheme;

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, colorScheme.error);
      expect(icon.icon, Icons.warning_amber);
    },
  );
}
