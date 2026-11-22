import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/settings/widgets/settings_section_header.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('section header is announced as a header', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SettingsSectionHeader(title: 'Notifications')),
      ),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(SettingsSectionHeader)),
      matchesSemantics(isHeader: true, label: 'Notifications'),
    );
    handle.dispose();
  });
}
