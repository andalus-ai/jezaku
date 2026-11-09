import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  const projector = JejakuGeoProjector();
  const origin = JejakuGeoOrigin(
    latitude: -6.9175,
    longitude: 107.6191,
    altitudeMeters: 700,
  );

  test('same coordinate projects to origin', () {
    const anchor = JejakuGeoAnchor(
      id: 'same',
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 700,
    );

    expect(
      projector.toLocalPosition(origin: origin, anchor: anchor),
      const ARVector3.zero(),
    );
  });

  test('longitude delta projects east on X axis', () {
    const anchor = JejakuGeoAnchor(
      id: 'east',
      latitude: -6.9175,
      longitude: 107.6192,
      altitudeMeters: 700,
    );

    final position = projector.toLocalPosition(origin: origin, anchor: anchor);

    expect(position.x, greaterThan(0));
    expect(position.y, closeTo(0, 1e-9));
  });

  test('latitude delta projects north onto negative Z axis', () {
    const anchor = JejakuGeoAnchor(
      id: 'north',
      latitude: -6.9174,
      longitude: 107.6191,
      altitudeMeters: 700,
    );

    final position = projector.toLocalPosition(origin: origin, anchor: anchor);

    expect(position.z, lessThan(0));
    expect(position.x.abs(), lessThan(0.001));
  });

  test('altitude delta projects onto Y axis', () {
    const anchor = JejakuGeoAnchor(
      id: 'up',
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 712.5,
    );

    final position = projector.toLocalPosition(origin: origin, anchor: anchor);

    expect(position.y, closeTo(12.5, 1e-9));
  });

  test('manual correction offsets are applied in local AR axes', () {
    const anchor = JejakuGeoAnchor(
      id: 'corrected',
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 700,
      correctionEastMeters: 1.5,
      correctionNorthMeters: -0.5,
      correctionUpMeters: 0.3,
    );

    final position = projector.toLocalPosition(origin: origin, anchor: anchor);

    expect(position.x, closeTo(1.5, 1e-9));
    expect(position.y, closeTo(0.3, 1e-9));
    expect(position.z, closeTo(0.5, 1e-9));
  });

  test('pose input includes manual correction offsets', () {
    const anchor = JejakuGeoAnchor(
      id: 'corrected_pose',
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 700,
      correctionEastMeters: -2,
      correctionNorthMeters: 3,
      correctionUpMeters: 1,
    );

    final pose = projector.toPoseInput(origin: origin, anchor: anchor);

    expect(pose.x, closeTo(-2, 1e-9));
    expect(pose.y, closeTo(1, 1e-9));
    expect(pose.z, closeTo(-3, 1e-9));
  });

  test('heading uses AR convention where north faces forward', () {
    const north = JejakuGeoAnchor(
      id: 'north',
      latitude: -6.9175,
      longitude: 107.6191,
    );
    const east = JejakuGeoAnchor(
      id: 'east',
      latitude: -6.9175,
      longitude: 107.6191,
      headingDegrees: 90,
    );

    final northForward =
        projector.toLocalRotation(north).rotateVector(ARVector3.forward);
    final eastForward =
        projector.toLocalRotation(east).rotateVector(ARVector3.forward);

    expect(northForward.z, closeTo(-1, 1e-9));
    expect(eastForward.x, closeTo(1, 1e-9));
    expect(eastForward.z, closeTo(0, 1e-9));
  });

  test('pose input preserves projected position and quaternion', () {
    const anchor = JejakuGeoAnchor(
      id: 'pose',
      latitude: -6.9175,
      longitude: 107.6191,
      altitudeMeters: 701,
      headingDegrees: 180,
    );

    final pose = projector.toPoseInput(origin: origin, anchor: anchor);

    expect(pose.y, closeTo(1, 1e-9));
    expect(
      math.sqrt(
        pose.qx * pose.qx +
            pose.qy * pose.qy +
            pose.qz * pose.qz +
            pose.qw * pose.qw,
      ),
      closeTo(1, 1e-9),
    );
  });
}
