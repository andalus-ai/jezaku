import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_debug_log.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_debug_log_controls.dart';

void main() {
  testWidgets('switch toggles the log and buttons forward actions',
      (tester) async {
    final log = ARDebugLog(
      sink: InMemoryARDebugLogSink(),
      printer: (_) {},
      flushDelay: const Duration(days: 1),
    );
    var copied = 0;
    var cleared = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ARDebugLogControls(
            log: log,
            onCopy: () => copied++,
            onClear: () => cleared++,
          ),
        ),
      ),
    );

    expect(log.enabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('ar_debug_log_switch')));
    await tester.pump();
    expect(log.enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('ar_debug_log_copy_button')));
    await tester.tap(find.byKey(const ValueKey('ar_debug_log_clear_button')));
    expect(copied, 1);
    expect(cleared, 1);

    await tester.tap(find.byKey(const ValueKey('ar_debug_log_switch')));
    await tester.pump();
    expect(log.enabled, isFalse);
    log.dispose();
  });
}
