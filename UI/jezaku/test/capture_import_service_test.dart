import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/camera/services/capture_import_service.dart';

void main() {
  test('recent imports provide EXIF-backed capture metadata', () {
    final candidates = const CaptureImportService().recentImports();

    expect(candidates, hasLength(3));
    expect(candidates.first.title, 'Museum hallway EXIF');
    expect(candidates.first.snapshot.locationLabel, '-6.9177, 107.6193');
    expect(candidates.first.snapshot.altitudeLabel, '713.8 m');
    expect(candidates.first.snapshot.compassLabel, '248 deg W');
    expect(candidates.first.snapshot.accuracyLabel, '+/- 4.6 m');
    expect(
      candidates.first.snapshot.captureSource,
      'Photo EXIF + compass fallback',
    );
    expect(
      candidates.first.metadataSummary,
      '-6.9177, 107.6193 | +/- 4.6 m',
    );
  });
}
