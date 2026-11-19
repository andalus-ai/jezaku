import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/viewer_geo.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

CaptureSensorSnapshot _snapshot({
  double latitude = -6.9,
  double longitude = 107.6,
  double altitude = 700,
  double heading = 90,
}) {
  return CaptureSensorSnapshot(
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitude,
    headingDegrees: heading,
    pitchDegrees: 0,
    rollDegrees: 0,
    gpsAccuracyMeters: 5,
    anchorType: 'test',
    captureSource: 'test',
  );
}

void main() {
  const fallback = JejakuGeoOrigin(latitude: 1, longitude: 2, altitudeMeters: 3);

  group('heading math', () {
    test('normalizeHeading wraps into [0, 360)', () {
      expect(ViewerGeo.normalizeHeading(0), 0);
      expect(ViewerGeo.normalizeHeading(360), 0);
      expect(ViewerGeo.normalizeHeading(725), 5);
      expect(ViewerGeo.normalizeHeading(-10), 350);
      expect(ViewerGeo.normalizeHeading(-370), 350);
    });

    test('headingDelta takes the short way round', () {
      expect(ViewerGeo.headingDelta(350, 10), 20);
      expect(ViewerGeo.headingDelta(10, 350), -20);
      expect(ViewerGeo.headingDelta(90, 90), 0);
      expect(ViewerGeo.headingDelta(0, 180).abs(), 180);
    });
  });

  group('origins', () {
    test('about one degree of latitude is about 111 km', () {
      const a = JejakuGeoOrigin(latitude: 0, longitude: 0);
      const b = JejakuGeoOrigin(latitude: 1, longitude: 0);
      expect(ViewerGeo.originDistanceMeters(a, b), closeTo(111319, 100));
    });

    test('origins within 1.5 m horizontally and vertically are the same', () {
      const a = JejakuGeoOrigin(latitude: -6.9, longitude: 107.6, altitudeMeters: 700);
      // 0.00001 degrees of latitude is about 1.1 m.
      const near = JejakuGeoOrigin(latitude: -6.89999, longitude: 107.6, altitudeMeters: 700.5);
      const far = JejakuGeoOrigin(latitude: -6.8999, longitude: 107.6, altitudeMeters: 700);
      const high = JejakuGeoOrigin(latitude: -6.9, longitude: 107.6, altitudeMeters: 702);
      expect(ViewerGeo.sameOrigin(a, near), isTrue);
      expect(ViewerGeo.sameOrigin(a, far), isFalse);
      expect(ViewerGeo.sameOrigin(a, high), isFalse);
    });
  });

  group('snapshots', () {
    test('a valid snapshot becomes the origin', () {
      final origin = ViewerGeo.originFor(_snapshot(), fallback: fallback);
      expect(origin.latitude, -6.9);
      expect(origin.longitude, 107.6);
      expect(origin.altitudeMeters, 700);
    });

    test('non-finite or out-of-range positions fall back', () {
      for (final bad in [
        _snapshot(latitude: double.nan),
        _snapshot(longitude: double.infinity),
        _snapshot(altitude: double.nan),
        _snapshot(latitude: 91),
        _snapshot(longitude: -181),
      ]) {
        expect(ViewerGeo.usesDeviceLocation(bad), isFalse);
        expect(ViewerGeo.originFor(bad, fallback: fallback), same(fallback));
      }
    });

    test('orientation needs a finite heading', () {
      expect(ViewerGeo.usesDeviceOrientation(_snapshot()), isTrue);
      expect(ViewerGeo.usesDeviceOrientation(_snapshot(heading: double.nan)), isFalse);
    });
  });

  group('isSameScenePlace', () {
    const origin = JejakuGeoOrigin(
      latitude: -6.2,
      longitude: 106.8,
      altitudeMeters: 10,
    );
    JejakuGeoOrigin shifted(double northMeters) => JejakuGeoOrigin(
          latitude: origin.latitude + northMeters / 111320,
          longitude: origin.longitude,
          altitudeMeters: origin.altitudeMeters,
        );

    test('ignores indoor GPS jitter that sameOrigin would flag', () {
      final jittered = shifted(4);

      expect(ViewerGeo.sameOrigin(origin, jittered), isFalse);
      expect(ViewerGeo.isSameScenePlace(origin, jittered), isTrue);
    });

    test('detects real movement', () {
      expect(ViewerGeo.isSameScenePlace(origin, shifted(25)), isFalse);
    });

    test('detects a large altitude change', () {
      final higher = JejakuGeoOrigin(
        latitude: origin.latitude,
        longitude: origin.longitude,
        altitudeMeters: origin.altitudeMeters + 15,
      );

      expect(ViewerGeo.isSameScenePlace(origin, higher), isFalse);
    });
  });
}
