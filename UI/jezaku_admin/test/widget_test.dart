import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:jezaku_admin/main.dart';

void main() {
  testWidgets('shows the Jezaku Admin overview without fake live data',
      (WidgetTester tester) async {
    await tester.view.setPhysicalSize(const Size(1200, 900));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    expect(find.text('Jezaku Admin'), findsOneWidget);
    expect(find.text('Platform overview'), findsOneWidget);
    expect(find.text('Backend integrations are not connected'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Not available'), findsNWidgets(3));
    expect(find.text('You have pushed the button this many times:'), findsNothing);
  });

  testWidgets('navigation opens an explicit not-implemented state',
      (WidgetTester tester) async {
    await tester.view.setPhysicalSize(const Size(1200, 900));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('People & Access').first);
    await tester.pumpAndSettle();

    expect(find.text('People & Access'), findsWidgets);
    expect(find.text('Not implemented'), findsOneWidget);
    expect(
      find.textContaining('documented, authorized management contract'),
      findsOneWidget,
    );
  });

  testWidgets('compact layout exposes navigation through the drawer',
      (WidgetTester tester) async {
    await tester.view.setPhysicalSize(const Size(420, 850));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('People & Access'), findsOneWidget);
    expect(find.text('Trust & Safety'), findsOneWidget);
  });
}
