import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jezaku_admin/main.dart';
import 'package:jezaku_admin/widgets/admin_feedback_state.dart';
import 'package:jezaku_ds/jezaku_ds.dart';

void main() {
  testWidgets('shows the redesigned overview without simulated live data',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    expect(find.text('JEZAKU'), findsOneWidget);
    expect(find.text('Platform overview'), findsOneWidget);
    expect(
      find.text('Backend integrations are not connected'),
      findsOneWidget,
    );
    expect(find.text('Unavailable'), findsNWidgets(4));
    expect(find.text('Activity feed unavailable'), findsOneWidget);
    expect(find.text('You have pushed the button this many times:'), findsNothing);
  });

  testWidgets('navigation opens an explicit not-implemented state',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
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
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('People & Access'), findsOneWidget);
    expect(find.text('Trust & Safety'), findsOneWidget);
  });

  testWidgets('theme control switches between light and dark themes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());

    expect(
      Theme.of(tester.element(find.text('Platform overview'))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('Platform overview'))).brightness,
      Brightness.dark,
    );
    expect(find.byTooltip('Switch to light theme'), findsOneWidget);
  });

  testWidgets('global search finds management destinations',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byTooltip('Search management areas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'spatial');
    await tester.pumpAndSettle();

    expect(find.text('Spatial Operations'), findsOneWidget);
  });
}


testWidgets('admin feedback retry uses the shared JzDS action', (tester) async {
  var retries = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminFeedbackState(
          kind: AdminFeedbackKind.error,
          onRetry: () => retries++,
        ),
      ),
    ),
  );

  expect(find.byType(JzButton), findsOneWidget);
  await tester.tap(find.text('Try again'));
  expect(retries, 1);
});
