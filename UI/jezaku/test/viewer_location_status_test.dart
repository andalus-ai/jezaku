import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/services/viewer_location_status.dart';

ViewerLocation _live(double? accuracy) => ViewerLocation(
      latitude: -6.9,
      longitude: 107.6,
      accuracyMeters: accuracy,
      isLive: true,
    );

void main() {
  test('fallback origin is reported as unavailable, not as a GPS fix', () {
    final status = describeViewerLocation(ViewerLocation.fallback);

    expect(status.level, ViewerLocationStatusLevel.unavailable);
    expect(status.label, 'Location unavailable');
  });

  test('live accuracy maps to levels and a rounded label', () {
    expect(describeViewerLocation(_live(3.4)).label, 'GPS ±3 m');
    expect(describeViewerLocation(_live(3.4)).level,
        ViewerLocationStatusLevel.good);
    expect(describeViewerLocation(_live(10)).level,
        ViewerLocationStatusLevel.good);
    expect(describeViewerLocation(_live(18)).level,
        ViewerLocationStatusLevel.fair);
    expect(describeViewerLocation(_live(30)).level,
        ViewerLocationStatusLevel.fair);
    expect(describeViewerLocation(_live(45)).level,
        ViewerLocationStatusLevel.poor);
  });

  test('live fix without usable accuracy is fair, never invented', () {
    for (final accuracy in <double?>[null, double.nan, -1]) {
      final status = describeViewerLocation(_live(accuracy));
      expect(status.label, 'GPS active');
      expect(status.level, ViewerLocationStatusLevel.fair);
    }
  });
}
