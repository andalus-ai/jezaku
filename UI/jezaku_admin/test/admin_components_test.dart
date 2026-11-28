import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_admin/widgets/admin_confirm_dialog.dart';
import 'package:jezaku_admin/widgets/admin_data_table.dart';
import 'package:jezaku_admin/widgets/admin_detail_scaffold.dart';
import 'package:jezaku_admin/widgets/admin_feedback_state.dart';

class _Record {
  const _Record(this.name, this.status);
  final String name;
  final String status;
}

Widget _table({required Size size}) {
  const records = [
    _Record('Charlie', 'Active'),
    _Record('Alpha', 'Pending'),
    _Record('Bravo', 'Active'),
  ];
  return MaterialApp(
    home: Scaffold(
      body: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AdminDataTable<_Record>(
            items: records,
            pageSize: 2,
            searchText: (record) => '\${record.name} \${record.status}',
            columns: [
              AdminTableColumn<_Record>(
                label: 'Name',
                cellBuilder: (_, record) => Text(record.name),
                compare: (a, b) => a.name.compareTo(b.name),
              ),
              AdminTableColumn<_Record>(
                label: 'Status',
                cellBuilder: (_, record) => Text(record.status),
              ),
            ],
            mobileCardBuilder: (_, record) => ListTile(title: Text(record.name), subtitle: Text(record.status)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('search filters rows and pagination reports result count', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_table(size: const Size(1100, 800)));
    expect(find.text('1–2 of 3'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Charlie'), findsNothing);
    expect(find.text('1–1 of 1'), findsOneWidget);
  });

  testWidgets('narrow layout uses record cards instead of data table', (tester) async {
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_table(size: const Size(420, 850)));

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('destructive confirmation requires exact typed phrase', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              confirmed = await showAdminConfirmDialog(
                context,
                confirmation: const AdminConfirmation(
                  title: 'Suspend operator',
                  description: 'This removes current access.',
                  destructive: true,
                  scopeLabel: 'Production workspace',
                  requireTypedConfirmation: 'SUSPEND',
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final confirm = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'));
    expect(confirm.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'SUSPEND');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });

  testWidgets('feedback state distinguishes forbidden access', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AdminFeedbackState(kind: AdminFeedbackKind.forbidden),
      ),
    ));
    expect(find.text('Access not permitted'), findsOneWidget);
  });

  testWidgets('detail scaffold switches tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminDetailScaffold(
          title: 'Operator detail',
          subtitle: 'Scoped access record',
          status: const Chip(label: Text('Active')),
          tabs: const [Tab(text: 'Summary'), Tab(text: 'Audit')],
          tabViews: const [Text('Summary content'), Text('Audit content')],
        ),
      ),
    ));

    expect(find.text('Summary content'), findsOneWidget);
    await tester.tap(find.text('Audit'));
    await tester.pumpAndSettle();
    expect(find.text('Audit content'), findsOneWidget);
  });
}
