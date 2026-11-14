import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/widgets/memory_empty_state.dart';

Widget _host({
  required bool hasAnyMemories,
  VoidCallback? onCapture,
  VoidCallback? onResetFilter,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MemoryEmptyState(
        hasAnyMemories: hasAnyMemories,
        onCapture: onCapture ?? () {},
        onResetFilter: onResetFilter ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('first run invites the first capture', (tester) async {
    var captures = 0;
    await tester.pumpWidget(
      _host(hasAnyMemories: false, onCapture: () => captures++),
    );

    expect(find.text('No memories yet'), findsOneWidget);
    await tester.tap(find.text('Capture a memory'));
    expect(captures, 1);
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('filtered empty offers a way back', (tester) async {
    var resets = 0;
    await tester.pumpWidget(
      _host(hasAnyMemories: true, onResetFilter: () => resets++),
    );

    expect(find.text('Nothing matches this filter'), findsOneWidget);
    await tester.tap(find.text('Show all'));
    expect(resets, 1);
    expect(find.text('Capture a memory'), findsNothing);
  });

  testWidgets('fits a short panel without overflowing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 160,
            child: MemoryEmptyState(
              hasAnyMemories: false,
              onCapture: () {},
              onResetFilter: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
