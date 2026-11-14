import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps screens from growing back into multi-thousand-line files.
///
/// Files over [defaultMaxLines] must be listed in [knownLargeFiles] with a
/// ceiling that only ever goes down. When you split one, lower or remove its
/// entry.
const defaultMaxLines = 1800;

const knownLargeFiles = <String, int>{
  // Still holds the ~4,000-line _ARViewerScreenState. Splitting that class
  // (e.g. into mixins on ConsumerState) is the next step.
  'lib/features/ar_viewer/screens/ar_viewer_screen.dart': 3700,
};

void main() {
  test('source files stay under their line ceilings', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll(r'\', '/');
      final lines = entity.readAsLinesSync().length;
      final ceiling = knownLargeFiles[path] ?? defaultMaxLines;
      if (lines > ceiling) {
        offenders.add('$path has $lines lines (limit $ceiling)');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
