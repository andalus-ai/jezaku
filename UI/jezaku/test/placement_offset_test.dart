import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/placement_offset.dart';

void main() {
  PlacementOffset offset(double e, double n, [double u = 0]) =>
      PlacementOffset(eastMeters: e, northMeters: n, upMeters: u);

  group('applyTo', () {
    test('no correction leaves the point where it is', () {
      final moved = PlacementOffset.zero.applyTo(latitude: -6.9, longitude: 107.6);

      expect(moved.latitude, -6.9);
      expect(moved.longitude, 107.6);
    });

    test('north moves latitude by about 1 / 111 320 degree per metre', () {
      final moved = offset(0, 111.32).applyTo(latitude: 10, longitude: 20);

      expect(moved.latitude, closeTo(10.001, 1e-9));
      expect(moved.longitude, 20);
    });

    test('east moves longitude further the closer to a pole', () {
      final equator = offset(100, 0).applyTo(latitude: 0, longitude: 0);
      final north = offset(100, 0).applyTo(latitude: 60, longitude: 0);

      expect(equator.longitude, closeTo(100 / 111320, 1e-9));
      // cos(60 degrees) = 0.5: twice the degrees for the same distance.
      expect(north.longitude, closeTo(2 * 100 / 111320, 1e-9));
    });

    test('west and south move the other way', () {
      final moved = offset(-50, -50).applyTo(latitude: 0, longitude: 0);

      expect(moved.latitude, lessThan(0));
      expect(moved.longitude, lessThan(0));
    });

    test('crossing the date line stays within -180..180', () {
      final moved = offset(5000, 0).applyTo(latitude: 0, longitude: 179.99);

      expect(moved.longitude, inInclusiveRange(-180, 180));
      expect(moved.longitude, lessThan(0));
    });

    test('near a pole only latitude changes, and it stays in range', () {
      final moved = offset(100, 1000).applyTo(latitude: 89.95, longitude: 10);

      expect(moved.longitude, 10);
      expect(moved.latitude, lessThanOrEqualTo(90));
    });

    test('a point that is not a number is returned as it is', () {
      final moved = offset(1, 1).applyTo(latitude: double.nan, longitude: 1);

      expect(moved.latitude.isNaN, isTrue);
      expect(moved.longitude, 1);
    });
  });

  group('raiseAltitude', () {
    test('adds the upward correction', () {
      expect(offset(0, 0, 1.5).raiseAltitude(700), 701.5);
    });

    test('an unknown altitude stays unknown', () {
      expect(offset(0, 0, 1.5).raiseAltitude(null), isNull);
      expect(offset(0, 0, 1.5).raiseAltitude(double.nan)!.isNaN, isTrue);
    });
  });

  test('offsets with the same numbers are equal', () {
    expect(offset(1, 2, 3), offset(1, 2, 3));
    expect(offset(1, 2, 3).hashCode, offset(1, 2, 3).hashCode);
    expect(offset(1, 2, 3), isNot(offset(1, 2, 4)));
  });
}
