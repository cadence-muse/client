import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_strings.dart';

void main() {
  Widget wrap(bool isOnline) {
    return ProviderScope(
      overrides: [isOnlineProvider.overrideWithValue(isOnline)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        // The offline case renders the banner's own Text, but the online
        // case renders nothing (SizedBox.shrink()) -- `tester.strings`
        // needs at least one Text widget in the pumped tree to read
        // AppLocalizations off of, so this always-present anchor keeps it
        // usable in both states without affecting the findsOneWidget /
        // findsNothing assertions below (it never matches
        // offlineBannerMessage).
        home: Scaffold(
          body: Column(
            children: [const OfflineBanner(), const Text('anchor')],
          ),
        ),
      ),
    );
  }

  testWidgets('offline shows the offline banner text', (tester) async {
    await tester.pumpWidget(wrap(false));

    expect(
      find.text(tester.strings.offlineBannerMessage),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('online hides the offline banner text', (tester) async {
    await tester.pumpWidget(wrap(true));

    expect(
      find.text(tester.strings.offlineBannerMessage),
      findsNothing,
    );
  });
}
