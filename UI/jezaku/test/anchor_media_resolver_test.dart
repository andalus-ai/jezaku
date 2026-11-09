import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_repository.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';

void main() {
  test('resolves stored media by attachment id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final storedAttachment =
        container.read(anchorMediaRepositoryProvider).storeAttachment(
              AnchorMediaAttachment(
                type: AnchorMediaType.arSnapshot,
                bytes: Uint8List.fromList(<int>[1, 2, 3]),
              ),
              storedAt: DateTime(2026, 5, 30, 12),
            );
    final memory = _memory(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        mediaId: storedAttachment.mediaId,
        storagePath: storedAttachment.storagePath,
        storedAt: storedAttachment.storedAt,
      ),
    );

    final resolved = container.read(anchorResolvedMediaProvider(memory));

    expect(resolved?.mediaId, 'media_arSnapshot_0001');
    expect(resolved?.storagePath, 'jejaku://media/media_arSnapshot_0001');
    expect(resolved?.storedByteLength, 3);
    expect(resolved?.previewBytes?.toList(), [1, 2, 3]);
    expect(resolved?.hasCachedPreview, isTrue);
    expect(resolved?.isPreviewCacheMissing, isFalse);
    expect(resolved?.availabilityLabel, 'Preview cached');
  });

  test('keeps recordings as icon previews even when stored metadata exists',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final storedAttachment =
        container.read(anchorMediaRepositoryProvider).storeAttachment(
              const AnchorMediaAttachment(
                type: AnchorMediaType.arRecording,
                filePath: '/tmp/ar_clip.mp4',
                duration: Duration(milliseconds: 1500),
                frameCount: 45,
              ),
            );
    final memory = _memory(mediaAttachment: storedAttachment);

    final resolved = container.read(anchorResolvedMediaProvider(memory));

    expect(resolved?.type, AnchorMediaType.arRecording);
    expect(resolved?.canPreviewAsImage, isFalse);
    expect(resolved?.previewBytes, isNull);
    expect(resolved?.availabilityLabel, 'Screen recording reference stored');
  });

  test('updates resolved previews after cached media is cleared', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(anchorMediaRepositoryProvider);
    final storedAttachment = repository.storeAttachment(
      AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );
    final memory = _memory(
      mediaAttachment: AnchorMediaAttachment(
        type: AnchorMediaType.arSnapshot,
        mediaId: storedAttachment.mediaId,
      ),
    );
    final resolvedProvider = anchorResolvedMediaProvider(memory);

    expect(container.read(resolvedProvider)?.previewBytes, isNotNull);

    repository.clearCachedMedia();

    expect(container.read(resolvedProvider)?.previewBytes, isNull);
    expect(container.read(resolvedProvider)?.mediaId, storedAttachment.mediaId);
    expect(container.read(resolvedProvider)?.hasCachedPreview, isFalse);
    expect(container.read(resolvedProvider)?.isPreviewCacheMissing, isTrue);
    expect(
      container.read(resolvedProvider)?.availabilityLabel,
      'Preview cache missing',
    );
  });
}

AnchorMemory _memory({required AnchorMediaAttachment mediaAttachment}) {
  return AnchorMemory(
    id: 'anchor_media_resolver',
    title: 'Resolved media',
    caption: 'Preview through repository.',
    distanceLabel: '7 m',
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
