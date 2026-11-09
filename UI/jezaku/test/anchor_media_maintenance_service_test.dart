import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_maintenance_service.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';

void main() {
  test('plans and purges only unreferenced cached media', () {
    final repository = InMemoryAnchorMediaRepository();
    const service = AnchorMediaMaintenanceService();

    final referenced = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
    );
    final orphaned = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.cameraPhoto,
        bytes: Uint8List.fromList(<int>[5, 6, 7]),
      ),
    );
    final memory = _memory(
      id: 'referenced_memory',
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        mediaId: referenced.mediaId,
      ),
    );

    final plan = service.plan(
      memories: [memory],
      repository: repository,
    );

    expect(plan.referencedMediaIds, {referenced.mediaId});
    expect(plan.orphanedMedia.map((media) => media.id), [orphaned.mediaId]);
    expect(plan.orphanedMediaCount, 1);
    expect(plan.orphanedByteLength, 3);
    expect(plan.orphanedMediaLabel, '1 unused media item');

    final result = service.purgeUnreferencedMedia(
      memories: [memory],
      repository: repository,
    );

    expect(result.removedAny, isTrue);
    expect(result.removedMediaCount, 1);
    expect(result.releasedByteLength, 3);
    expect(repository.mediaById(orphaned.mediaId!), isNull);
    expect(repository.mediaById(referenced.mediaId!), isNotNull);
  });

  test('keeps cached media referenced by more than one memory', () {
    final repository = InMemoryAnchorMediaRepository();
    const service = AnchorMediaMaintenanceService();

    final referenced = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );
    final memories = [
      _memory(
        id: 'first',
        mediaAttachment: AnchorMediaAttachment(
          type: AnchorMediaType.arSnapshot,
          mediaId: referenced.mediaId,
        ),
      ),
      _memory(
        id: 'second',
        mediaAttachment: AnchorMediaAttachment(
          type: AnchorMediaType.arSnapshot,
          mediaId: referenced.mediaId,
        ),
      ),
    ];

    final result = service.purgeUnreferencedMedia(
      memories: memories,
      repository: repository,
    );

    expect(result.removedAny, isFalse);
    expect(repository.mediaById(referenced.mediaId!), isNotNull);
  });
}

AnchorMemory _memory({
  required String id,
  required AnchorMediaAttachment mediaAttachment,
}) {
  return AnchorMemory(
    id: id,
    title: 'Media maintenance',
    caption: 'Repository maintenance fixture.',
    distanceLabel: '5 m',
    capturedAgo: 'Just now',
    locationLabel: '-6.9175, 107.6191',
    latitude: -6.9175,
    longitude: 107.6191,
    reactions: 0,
    captureMetadata: const AnchorCaptureMetadata(
      altitudeMeters: 714.2,
      headingDegrees: 245,
      pitchDegrees: -2,
      rollDegrees: 0.4,
      gpsAccuracyMeters: 3.2,
      anchorType: 'Hybrid geo/orientation',
      captureSource: 'GPS + compass + gyro',
    ),
    mediaAttachment: mediaAttachment,
  );
}
