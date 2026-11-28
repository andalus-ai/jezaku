import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_admin/widgets/admin_activity_timeline.dart';
import 'package:jezaku_admin/widgets/admin_filter_panel.dart';
import 'package:jezaku_admin/widgets/admin_form_section.dart';
import 'package:jezaku_admin/widgets/admin_workflow_review.dart';
import 'package:jezaku_admin/widgets/admin_confirm_dialog.dart';
import 'package:jezaku_admin/widgets/admin_data_table.dart';
import 'package:jezaku_admin/widgets/admin_detail_scaffold.dart';
import 'package:jezaku_admin/widgets/admin_feedback_state.dart';

class _Record {
  const _Record(this.name, this.status);
  final String name;
  final String status;
}

Widget _table() {
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
            searchText: (record) => '${record.name} ${record.status}',
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

    await tester.pumpWidget(_table());
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

    await tester.pumpWidget(_table());

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


  testWidgets('filter panel applies draft selections only on apply', (tester) async {
    Set<String>? applied;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminFilterPanel(
          groups: const [
            AdminFilterGroup(label: 'Status', options: [
              AdminFilterOption(value: 'active', label: 'Active'),
              AdminFilterOption(value: 'pending', label: 'Pending'),
            ]),
          ],
          selectedValues: const {},
          onApply: (values) => applied = values,
        ),
      ),
    ));
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(applied, isNull);
    await tester.tap(find.text('Apply filters'));
    expect(applied, contains('active'));
  });

  testWidgets('required validated field reports missing value', (tester) async {
    final key = GlobalKey<FormState>();
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: key,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AdminValidatedTextField(controller: controller, label: 'Operator name', required: true),
          ),
        ),
      ),
    ));
    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Operator name is required'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('workflow review requires a reason before confirmation', (tester) async {
    String? result = 'not-set';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await showAdminWorkflowReview(
                context,
                title: 'suspension',
                consequence: 'The operator will lose access.',
                scope: 'Workspace Alpha',
                items: const [AdminReviewItem(label: 'Account', value: 'operator-1')],
              );
            },
            child: const Text('Review'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review suspension'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm review'));
    expect(button.onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), 'Incident response');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm review'));
    await tester.pumpAndSettle();
    expect(result, 'Incident response');
  });

  testWidgets('activity timeline shows actor and event reference', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminActivityTimeline(entries: [
          AdminActivityEntry(
            title: 'Policy updated',
            actor: 'Operator A',
            timestamp: DateTime(2026, 11, 28, 10),
            description: 'Updated review policy',
            reference: 'audit-123',
            severity: AdminActivitySeverity.warning,
          ),
        ]),
      ),
    ));
    expect(find.text('Policy updated'), findsOneWidget);
    expect(find.textContaining('Operator A'), findsOneWidget);
    expect(find.text('Reference: audit-123'), findsOneWidget);
  });


  testWidgets('unsaved changes guard lets operator keep editing or discard', (tester) async {
    var discard = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => discard = await confirmAdminDiscardChanges(context),
            child: const Text('Leave form'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Leave form'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(discard, isFalse);
  });
