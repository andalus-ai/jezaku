/// Which policy a [LegalDocument] is.
enum LegalDocumentId {
  terms('terms'),
  privacy('privacy'),
  community('community');

  const LegalDocumentId(this.slug);

  final String slug;
}

class LegalSection {
  const LegalSection({required this.heading, required this.paragraphs});

  final String heading;
  final List<String> paragraphs;
}

/// A policy shown in the app. The text lives in `legal_documents.dart` so it
/// can be replaced by reviewed copy without touching any screen.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.summary,
    required this.sections,
    this.isDraft = true,
  });

  final LegalDocumentId id;
  final String title;

  /// Bumped whenever the meaning changes, so acceptance can be re-requested.
  final String version;

  /// ISO date (`YYYY-MM-DD`).
  final String effectiveDate;
  final String summary;
  final List<LegalSection> sections;

  /// True until a lawyer has reviewed the text. The screen says so.
  final bool isDraft;

  String get versionLabel => 'Version $version - effective $effectiveDate';
}
