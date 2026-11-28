import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps corner radii on the design-system scale (`JzRadius`).
///
/// A literal such as `BorderRadius.circular(8)` is an unnamed copy of a token
/// value; use `JzRadius.sm` so a design-system change reaches every screen.
/// Values off the scale (3, 5, 6, 14, 18, 99 …) are not flagged — decide
/// whether they should snap to a token before touching them.
///
/// Exempt until the library that owns them can import `jezaku_ds` or a size
/// ceiling allows it:
/// * `part of` files (they share their library's imports; add the import to
///   the owning library, then migrate the part);
/// * [exemptFiles].
const exemptFiles = <String>{
  // At its size-guard ceiling: one more import line would breach it. Migrate
  // when the file is next split.
  'lib/features/ar_viewer/screens/ar_viewer_screen.dart',
};

final _tokenRadius = RegExp(r'BorderRadius\.circular\((4|8|12|16|24|999)\)');

void main() {
  test('corner radii on the design-system scale use JzRadius', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final path = entity.path.replaceAll(r'\', '/');
      if (exemptFiles.contains(path)) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (RegExp(r'^part of ', multiLine: true).hasMatch(source)) {
        continue;
      }
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (_tokenRadius.hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use JzRadius.xs/sm/md/lg/xl/pill:\n${offenders.join('\n')}',
    );
  });
}
