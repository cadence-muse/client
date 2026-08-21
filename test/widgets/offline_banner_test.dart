import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(bool isOnline) {
    return ProviderScope(
      overrides: [isOnlineProvider.overrideWithValue(isOnline)],
      child: const MaterialApp(home: Scaffold(body: OfflineBanner())),
    );
  }

  testWidgets('offline shows the offline banner text', (tester) async {
    await tester.pumpWidget(wrap(false));

    expect(
      find.text('Showing cached data — may be out of date'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('online hides the offline banner text', (tester) async {
    await tester.pumpWidget(wrap(true));

    expect(
      find.text('Showing cached data — may be out of date'),
      findsNothing,
    );
  });
}
