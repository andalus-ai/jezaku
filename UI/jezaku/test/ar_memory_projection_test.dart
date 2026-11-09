import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  test('AnchorMemory adapter forwards manual correction to jezaku_ar', () {
    const memory = AnchorMemory(
      id: 'calibrated_memory',
      title: 'Calibrated memory',
      caption: 'Aligned by hand.',
      distanceLabel: '12 m',
      capturedAgo: 'Just now',
      locationLabel: '-6.9175, 107.6191',
      latitude: -6.9175,
      longitude: 107.6191,
      reactions: 0,
      captureMetadata: AnchorCaptureMetadata(
        altitudeMeters: 714,
        headingDegrees: 245,
        pitchDegrees: -2,
        rollDegrees: 0.4,
        gpsAccuracyMeters: 3.2,
        anchorType: 'Manually calibrated geo anchor',
        captureSource: 'GPS + compass + gyro',
        correctionEastMeters: 1.5,
        correctionNorthMeters: -0.5,
        correctionUpMeters: 0.3,
      ),
    );

    final anchor = memory.toJejakuGeoAnchor();
    final projection = const JejakuViewProjector().projectAnchor(
      viewerPose: const JejakuViewerPose(
        origin: JejakuGeoOrigin(
          latitude: -6.9175,
          longitude: 107.6191,
          altitudeMeters: 714,
        ),
      ),
      anchor: anchor,
    );

    expect(anchor.metadata['hasManualCorrection'], isTrue);
    expect(projection.localPosition, const ARVector3(1.5, 0.3, 0.5));
  });

  test('AnchorMemory adapter forwards 3D model attachment to jezaku_ar', () {
    final asset = ARModelAsset.fromPath(
      'assets/models/waypoint_marker.obj',
      fallbackSizeMeters: const ARVector3(0.45, 0.32, 0.45),
    );
    final memory = AnchorMemory(
      id: 'model_memory',
      title: 'Model memory',
      caption: 'Placed as a 3D object.',
      distanceLabel: '12 m',
      capturedAgo: 'Just now',
      locationLabel: '-6.9175, 107.6191',
      latitude: -6.9175,
      longitude: 107.6191,
      reactions: 0,
      captureMetadata: const AnchorCaptureMetadata(
        altitudeMeters: 714,
        headingDegrees: 245,
        pitchDegrees: -2,
        rollDegrees: 0.4,
        gpsAccuracyMeters: 3.2,
        anchorType: '3D model anchor',
        captureSource: 'Model import',
      ),
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arModel,
        modelAsset: asset,
      ),
    );

    final anchor = memory.toJejakuGeoAnchor();
    final node = const JejakuMemoryNodeFactory().build(anchor);

    expect(anchor.metadata['mediaType'], 'arModel');
    expect(anchor.metadata['photoFrame'], isNull);
    expect(anchor.metadata['modelPath'], 'assets/models/waypoint_marker.obj');
    expect(anchor.metadata['modelFormat'], 'obj');
    expect(node.isModelNode, isTrue);
    expect(node.modelAsset, asset);
    expect(node.primitiveSize, const ARVector3(0.45, 0.32, 0.45));
  });

  test('AnchorMemory adapter round-trips Jejaku cloud anchor records', () {
    const memory = AnchorMemory(
      id: 'cloud_memory',
      title: 'Cloud memory',
      caption: 'Persistent AR anchor.',
      distanceLabel: '8 m',
      capturedAgo: 'Today',
      locationLabel: '-6.9175, 107.6191',
      latitude: -6.9175,
      longitude: 107.6191,
      reactions: 0,
      captureMetadata: AnchorCaptureMetadata(
        altitudeMeters: 714,
        headingDegrees: 245,
        pitchDegrees: -2,
        rollDegrees: 0.4,
        gpsAccuracyMeters: 2.8,
        anchorType: 'Native cloud anchor',
        captureSource: 'ARCore Cloud Anchor',
      ),
    );
    final record = JejakuMemoryCloudAnchor(
      memoryId: memory.id,
      localAnchorId: 'anchor_0',
      cloudAnchorId: 'cloud_0',
      expiresAt: DateTime.utc(2026, 6, 4),
    );

    final updated = memory.withJejakuCloudAnchor(record);
    final geoAnchor = updated.toJejakuGeoAnchor();
    final restored = updated.toJejakuCloudAnchor();

    expect(updated.captureMetadata.hasCloudAnchor, isTrue);
    expect(geoAnchor.metadata['localAnchorId'], 'anchor_0');
    expect(geoAnchor.metadata['cloudAnchorId'], 'cloud_0');
    expect(
        geoAnchor.metadata['cloudAnchorExpiresAt'], '2026-06-04T00:00:00.000Z');
    expect(restored?.memoryId, memory.id);
    expect(restored?.localAnchorId, 'anchor_0');
    expect(restored?.cloudAnchorId, 'cloud_0');
    expect(restored?.expiresAt, DateTime.utc(2026, 6, 4));
    expect(
      () => memory.withJejakuCloudAnchor(
        const JejakuMemoryCloudAnchor(
          memoryId: 'other_memory',
          localAnchorId: 'anchor_0',
          cloudAnchorId: 'cloud_0',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('projectAnchorMemories can keep out-of-range anchors for HUD fallback',
      () {
    const distantMemory = AnchorMemory(
      id: 'distant_memory',
      title: 'Distant memory',
      caption: 'Still useful as an edge indicator.',
      distanceLabel: '600 m',
      capturedAgo: 'Today',
      locationLabel: '-6.9120, 107.6191',
      latitude: -6.9120,
      longitude: 107.6191,
      reactions: 0,
      captureMetadata: AnchorCaptureMetadata(
        altitudeMeters: 714,
        headingDegrees: 0,
        pitchDegrees: 0,
        rollDegrees: 0,
        gpsAccuracyMeters: 4,
        anchorType: 'Hybrid geo/orientation',
        captureSource: 'GPS + compass + gyro',
      ),
    );
    const viewerPose = JejakuViewerPose(
      origin: JejakuGeoOrigin(
        latitude: -6.9175,
        longitude: 107.6191,
        altitudeMeters: 714,
      ),
      maxDistanceMeters: 50,
    );

    final filtered = projectAnchorMemories(
      memories: const [distantMemory],
      viewerPose: viewerPose,
    );
    final fallback = projectAnchorMemories(
      memories: const [distantMemory],
      viewerPose: viewerPose,
      onlyInRange: false,
    );

    expect(filtered, isEmpty);
    expect(fallback.single.memory.id, distantMemory.id);
    expect(fallback.single.projection.isWithinRange, isFalse);
  });
}
