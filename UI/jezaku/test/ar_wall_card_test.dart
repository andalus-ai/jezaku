import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/theme/jejaku_theme.dart';
import 'package:jejaku/app/theme/jezaku_status_colors.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/widgets/ar_wall_card.dart';
import 'package:material_ui/material_ui.dart';

ARWall _wall({bool isPublic = true, bool isActive = false}) => ARWall(
      id: 'w1',
      title: 'Town wall',
      description: 'Shared by the neighbourhood',
      distanceLabel: '40 m',
      memberCount: 3,
      itemCount: 0,
      isPublic: isPublic,
      isActive: isActive,
      items: const [],
    );

Future<void> _pump(WidgetTester tester, ThemeData theme, ARWall wall) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ARWallCard(wall: wall, onTap: () {}),
        ),
      ),
    ),
  );
}

// The card is one tappable node, so the icon's label is merged into a longer
// semantics label and cannot be matched exactly; assert on the icon itself.
final _activeIndicator = find.byWidgetPredicate(
  (widget) => widget is Icon && widget.semanticLabel == 'Active wall',
);

/// The badge's filled background, found from its label.
Color _badgeColor(WidgetTester tester, String label) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  for (final brightness in Brightness.values) {
    final theme =
        brightness == Brightness.dark ? JejakuTheme.dark() : JejakuTheme.light();
    final status = JezakuStatusColors.forBrightness(brightness);

    group('ARWallCard in ${brightness.name} theme', () {
      testWidgets('public badge uses the success colour and a text label',
          (tester) async {
        await _pump(tester, theme, _wall());

        expect(find.text('Public'), findsOneWidget);
        expect(_badgeColor(tester, 'Public'), status.success);
      });

      testWidgets('group badge uses the warning colour and a text label',
          (tester) async {
        await _pump(tester, theme, _wall(isPublic: false));

        expect(find.text('Group'), findsOneWidget);
        expect(_badgeColor(tester, 'Group'), status.warning);
      });

      testWidgets('badge label is readable on its background', (tester) async {
        await _pump(tester, theme, _wall());

        final label = tester.widget<Text>(find.text('Public'));
        expect(
          label.style!.color,
          JezakuStatusColors.onColor(status.success),
        );
      });

      testWidgets('active wall labels its active indicator "Active wall"',
          (tester) async {
        await _pump(tester, theme, _wall(isActive: true));

        expect(_activeIndicator, findsOneWidget);
      });

      testWidgets('inactive wall has no active indicator', (tester) async {
        await _pump(tester, theme, _wall());

        expect(_activeIndicator, findsNothing);
      });
    });
  }
}
