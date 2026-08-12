import 'package:flutter_test/flutter_test.dart';

import 'package:cadence/app.dart';
import 'package:cadence/theme/theme_controller.dart';

void main() {
  testWidgets('bottom navigation switches between tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(CadenceApp(themeController: ThemeController()));

    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Bands'));
    await tester.pumpAndSettle();

    expect(find.text('The Night Owls'), findsOneWidget);
  });
}
