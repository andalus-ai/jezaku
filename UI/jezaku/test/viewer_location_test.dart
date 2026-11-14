import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/services/anchor_map_projection_service.dart';
import 'package:jejaku/features/home/services/anchor_spatial_journey_service.dart';
import 'package:jejaku/features/home/services/sample_anchor_service.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';

class _FakeViewerLocationSource implements ViewerLocationSource {
  final controller = StreamController<ViewerLocation>.broadcast();

  @override
  Stream<ViewerLocation> watch() => controller.stream;
}

ViewerLocation _live(double latitude, double longitude) => ViewerLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: 4,
      isLive: true,
    );

void main() {
  late _FakeViewerLocationSource source;
  late ProviderContainer container;

  setUp(() {
    source = _FakeViewerLocationSource();
    container = ProviderContainer(
      overrides: [viewerLocationSourceProvider.overrideWithValue(source)],
    );
    addTearDown(() async {
      container.dispose();
      await source.controller.close();
    });
  });

  test('starts at the fallback origin and is not live', () {
    final location = container.read(viewerLocationProvider);

    expect(location, ViewerLocation.fallback);
    expect(location.isLive, isFalse);
    expect(location.latitude, viewerLatitude);
    expect(location.longitude, viewerLongitude);
  });

  test('default source never goes live', () async {
    final plain = ProviderContainer();
    addTearDown(plain.dispose);

    plain.read(viewerLocationProvider);
    await Future<void>.delayed(Duration.zero);

    expect(plain.read(viewerLocationProvider), ViewerLocation.fallback);
  });

  test('live fixes replace the fallback origin', () async {
    container.read(viewerLocationProvider);

    source.controller.add(_live(-6.9000, 107.6000));
    await Future<void>.delayed(Duration.zero);

    final location = container.read(viewerLocationProvider);
    expect(location.isLive, isTrue);
    expect(location.latitude, -6.9000);
    expect(location.accuracyMeters, 4);
  });

  test('jitter under the minimum move distance is ignored', () async {
    container.read(viewerLocationProvider);

    source.controller.add(_live(-6.9000, 107.6000));
    await Future<void>.delayed(Duration.zero);
    // About 1 m north.
    source.controller.add(_live(-6.89999, 107.6000));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(viewerLocationProvider).latitude, -6.9000);

    // About 111 m north.
    source.controller.add(_live(-6.8990, 107.6000));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(viewerLocationProvider).latitude, -6.8990);
  });

  test('distanceToMemoryMeters uses the label only for the fallback origin',
      () {
    final rooftop = const SampleAnchorService().nearbyAnchors()[1];

    expect(
      ViewerLocation.fallback.distanceToMemoryMeters(rooftop),
      31,
    );
    expect(
      _live(-6.9175, 107.6191).distanceToMemoryMeters(rooftop),
      closeTo(164, 10),
    );
  });

  test('projection can measure from coordinates instead of labels', () {
    final rooftop = const SampleAnchorService().nearbyAnchors()[1];

    final byLabel = const AnchorMapProjectionService().pointsFor(
      anchors: [rooftop],
      originLatitude: -6.9175,
      originLongitude: 107.6191,
      radiusMeters: 200,
    );
    final byCoordinates = const AnchorMapProjectionService().pointsFor(
      anchors: [rooftop],
      originLatitude: -6.9175,
      originLongitude: 107.6191,
      radiusMeters: 200,
      useCoordinateDistance: true,
    );

    expect(byLabel.single.distanceMeters, 31);
    expect(byCoordinates.single.distanceMeters, closeTo(164, 10));
  });

  test('journey steps forward the coordinate-distance flag', () {
    final rooftop = const SampleAnchorService().nearbyAnchors()[1];

    final steps = const AnchorSpatialJourneyService().stepsFor(
      anchors: [rooftop],
      originLatitude: -6.9175,
      originLongitude: 107.6191,
      radiusMeters: 200,
      useCoordinateDistance: true,
    );

    expect(steps.single.point.distanceMeters, closeTo(164, 10));
  });

  test('spatialJourneyProvider re-measures once the viewer goes live',
      () async {
    final before = container.read(spatialJourneyProvider);
    final rooftopBefore =
        before.firstWhere((step) => step.memory.id == 'anchor_rooftop');
    expect(rooftopBefore.point.distanceMeters, 31);

    source.controller.add(_live(-6.9175, 107.6191));
    await Future<void>.delayed(Duration.zero);

    final rooftopAfter = container
        .read(spatialJourneyProvider)
        .firstWhere((step) => step.memory.id == 'anchor_rooftop');
    expect(rooftopAfter.point.distanceMeters, closeTo(164, 10));
  });
}
