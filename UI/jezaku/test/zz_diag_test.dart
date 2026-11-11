// TEMPORARY diagnostic for CI; remove before merge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/main.dart';

void _dump(WidgetTester tester, String label) {
  debugPrint('DIAG [$label] snackbars=${find.byType(SnackBar).evaluate().length} '
      'banners=${find.byType(MaterialBanner).evaluate().length}');
  for (final e in find.byType(IconButton).evaluate()) {
    final w = e.widget as IconButton;
    final box = e.renderObject as RenderBox?;
    if (box == null || !box.attached) continue;
    final p = box.localToGlobal(Offset.zero);
    debugPrint('DIAG [$label] IconButton tooltip=${w.tooltip} '
        'enabled=${w.onPressed != null} at=${p.dx.round()},${p.dy.round()}');
  }
}

void main() {
  testWidgets('DIAG wall tap', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const ProviderScope(child: JejakuApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Courtyard sketch'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Virtual walls'), 300);
    _dump(tester, 'wall');
    final key = find.byKey(const ValueKey('memory_wall_open_wall_reunion'));
    debugPrint('DIAG target at ${tester.getCenter(key)}');
    final hits = <String>[];
    final hit = tester.binding.hitTestDispatcher;
    debugPrint('DIAG dispatcher ${hit.runtimeType}');
    for (final e in find.byType(Scaffold).evaluate()) {
      final box = e.renderObject as RenderBox;
      debugPrint('DIAG scaffold size=${box.size} at=${box.localToGlobal(Offset.zero)}');
    }
    debugPrint('DIAG hits=$hits');
  });
}
