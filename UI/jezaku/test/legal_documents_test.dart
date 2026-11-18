import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/legal/content/legal_documents.dart';
import 'package:jejaku/features/legal/models/legal_document.dart';
import 'package:jejaku/features/legal/screens/legal_document_screen.dart';
import 'package:jejaku/features/settings/screens/settings_screen.dart';

void main() {
  group('legal content', () {
    test('has one document per id with real content', () {
      expect(
        legalDocuments.map((document) => document.id),
        unorderedEquals(LegalDocumentId.values),
      );
      for (final document in legalDocuments) {
        expect(document.title, isNotEmpty);
        expect(document.version, isNotEmpty);
        expect(document.effectiveDate, matches(r'^\d{4}-\d{2}-\d{2}$'));
        expect(document.sections, isNotEmpty);
        for (final section in document.sections) {
          expect(section.heading, isNotEmpty);
          expect(section.paragraphs, isNotEmpty);
          expect(section.paragraphs.every((text) => text.trim().isNotEmpty),
              isTrue);
        }
      }
    });

    test('lookup returns the matching document', () {
      for (final id in LegalDocumentId.values) {
        expect(legalDocumentFor(id).id, id);
      }
    });

    test('slugs are unique', () {
      final slugs = LegalDocumentId.values.map((id) => id.slug).toSet();
      expect(slugs.length, LegalDocumentId.values.length);
    });
  });

  group('legal screens', () {
    testWidgets('the hub lists every policy and opens it', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LegalHubScreen()));

      for (final document in legalDocuments) {
        expect(find.byKey(ValueKey('legal_${document.id.slug}_tile')),
            findsOneWidget);
      }

      await tester.tap(find.byKey(const ValueKey('legal_privacy_tile')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('legal_privacy_document')),
          findsOneWidget);
      expect(find.text('Where your data is kept'), findsOneWidget);
    });

    testWidgets('a draft document says it is a draft', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LegalDocumentScreen(
            document: legalDocumentFor(LegalDocumentId.terms),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('legal_draft_notice')), findsOneWidget);
      expect(find.text('Version 0.1 - effective 2026-11-18'), findsOneWidget);
    });

    testWidgets('a reviewed document has no draft notice', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalDocumentScreen(
            document: LegalDocument(
              id: LegalDocumentId.terms,
              title: 'Terms',
              version: '1.0',
              effectiveDate: '2027-01-01',
              summary: 's',
              sections: [LegalSection(heading: 'h', paragraphs: ['p'])],
              isDraft: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('legal_draft_notice')), findsNothing);
    });

    testWidgets('settings links to the policies', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const SettingsScreen(),
            onGenerateRoute: AppRoutes.onGenerateRoute,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('legal_tile')));
      await tester.tap(find.byKey(const ValueKey('legal_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Terms of use'), findsOneWidget);
      expect(find.text('Community guidelines'), findsOneWidget);
    });
  });
}
