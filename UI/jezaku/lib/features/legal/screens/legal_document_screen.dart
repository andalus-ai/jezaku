import 'package:material_ui/material_ui.dart';
import 'package:jezaku_ds/jezaku_ds.dart' show JzRadius;
import 'package:jejaku/features/legal/content/legal_documents.dart';
import 'package:jejaku/features/legal/models/legal_document.dart';

/// Lists the policies; each opens a [LegalDocumentScreen].
class LegalHubScreen extends StatelessWidget {
  const LegalHubScreen({super.key});

  static const _icons = <LegalDocumentId, IconData>{
    LegalDocumentId.terms: Icons.description_outlined,
    LegalDocumentId.privacy: Icons.privacy_tip_outlined,
    LegalDocumentId.community: Icons.diversity_3_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms and policies')),
      body: ListView(
        children: [
          for (final document in legalDocuments)
            ListTile(
              key: ValueKey('legal_${document.id.slug}_tile'),
              leading: Icon(_icons[document.id]),
              title: Text(document.title),
              subtitle: Text(document.summary),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LegalDocumentScreen(document: document),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            key: ValueKey('legal_${document.id.slug}_document'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(document.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(document.versionLabel, style: theme.textTheme.bodySmall),
              if (document.isDraft) ...[
                const SizedBox(height: 12),
                const _DraftNotice(),
              ],
              for (final section in document.sections) ...[
                const SizedBox(height: 24),
                Text(section.heading, style: theme.textTheme.titleMedium),
                for (final paragraph in section.paragraphs) ...[
                  const SizedBox(height: 8),
                  Text(paragraph, style: theme.textTheme.bodyMedium),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('legal_draft_notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(JzRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Draft text, not yet reviewed by a lawyer.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
