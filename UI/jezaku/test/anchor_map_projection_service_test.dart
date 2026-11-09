import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/services/anchor_map_projection_service.dart';
import 'package:jejaku/features/home/services/sample_anchor_service.dart';

void main() {
  test('pointsFor projects anchors by nearby distance and bearing', () {
    final anchors = const SampleAnchorService().nearbyAnchors();

    final points = const AnchorMapProjectionService().pointsFor(
      anchors: anchors,
      originLatitude: -6.9175,
      originLongitude: 107.6191,
      radiusMeters: 100,
    );

    expect(points, hasLength(4));
    expect(
      points.map((point) => point.memory.title),
      [
        'Courtyard sketch',
        'Rooftop sunset',
        'Family checkpoint',
        'Hidden mural frame',
      ],
    );
    expect(points.first.distanceLabel, '12.5 m');
    expect(points.first.radiusFraction, closeTo(0.125, 0.001));
    expect(points.first.directionLabel, 'N');
    expect(points.first.eastFraction, closeTo(0, 0.001));
    expect(points.first.northFraction, closeTo(0.125, 0.001));
    expect(points[2].memory.isPrivate, isTrue);
    expect(points.last.radiusFraction, closeTo(0.88, 0.001));
  });

  test('pointsFor falls back to geodesic distance when labels are unknown', () {
    final anchors = const SampleAnchorService().nearbyAnchors();

    final points = const AnchorMapProjectionService().pointsFor(
      anchors: [anchors[1].copyWith(distanceLabel: 'near the rooftop')],
      originLatitude: -6.9175,
      originLongitude: 107.6191,
      radiusMeters: 200,
    );

    expect(points.single.distanceMeters, greaterThan(150));
    expect(points.single.directionLabel, 'E');
    expect(points.single.radiusFraction, lessThanOrEqualTo(1));
  });
}
