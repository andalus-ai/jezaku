import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/trails/models/ar_trail_route.dart';

void main() {
  test('route service builds shared leg and effort labels', () {
    const service = ARTrailRouteService();

    final route = service.routeFor(
      points: const [
        ARTrailRoutePoint(
          memoryId: 'anchor_courtyard',
          title: 'Courtyard sketch',
          latitude: -6.9175,
          longitude: 107.6191,
          distanceFromOriginMeters: 12.5,
          bearingFromOriginDegrees: 0,
          isWallLinked: true,
        ),
        ARTrailRoutePoint(
          memoryId: 'anchor_rooftop',
          title: 'Rooftop sunset',
          latitude: -6.9180,
          longitude: 107.6205,
          distanceFromOriginMeters: 31,
          bearingFromOriginDegrees: 90,
          isWallLinked: true,
        ),
        ARTrailRoutePoint(
          memoryId: 'anchor_private',
          title: 'Family checkpoint',
          latitude: -6.9162,
          longitude: 107.6179,
          distanceFromOriginMeters: 54,
          bearingFromOriginDegrees: 317,
          isPrivate: true,
          isWallLinked: true,
        ),
        ARTrailRoutePoint(
          memoryId: 'anchor_mural',
          title: 'Hidden mural frame',
          latitude: -6.9194,
          longitude: 107.6187,
          distanceFromOriginMeters: 88,
          bearingFromOriginDegrees: 180,
          isWallLinked: true,
        ),
      ],
    );

    expect(route.stopCount, 4);
    expect(route.legs, hasLength(3));
    expect(route.legs.first.nextStopLabel, 'Next Rooftop sunset - 164 m E');
    expect(route.legAfterPoint('anchor_rooftop')?.nextStopLabel,
        'Next Family checkpoint - 350 m NW');
    expect(route.routeDistanceMeters, closeTo(893.26, 0.01));
    expect(route.routeEffortLabel, '893 m - 12 min walk');
    expect(
      route.remainingDistanceMetersFrom('anchor_rooftop'),
      closeTo(716.52, 0.01),
    );
    expect(
      route.remainingEffortLabelFrom('anchor_rooftop'),
      '717 m remaining - 9 min walk',
    );
    expect(route.remainingEffortLabelFrom('anchor_mural'), 'Route complete');
    expect(route.routeContextLabel, 'Route N to S - 4 wall stops');
    expect(route.advisoryLabel, '1 private');
  });

  test('route service supports route-only distance without an approach leg',
      () {
    const service = ARTrailRouteService();

    final route = service.routeFor(
      approachDistanceMeters: 0,
      points: const [
        ARTrailRoutePoint(
          memoryId: 'anchor_courtyard',
          title: 'Courtyard sketch',
          latitude: -6.9175,
          longitude: 107.6191,
        ),
        ARTrailRoutePoint(
          memoryId: 'anchor_private',
          title: 'Family checkpoint',
          latitude: -6.9162,
          longitude: 107.6179,
        ),
      ],
    );

    expect(route.routeDistanceMeters, closeTo(196.07, 0.01));
    expect(route.walkTimeLabel, '3 min walk');
    expect(route.farthestLabel, 'Farthest 0 m');
  });
}
