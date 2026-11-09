import 'dart:typed_data';

import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

extension AnchorMemoryGeoAnchor on AnchorMemory {
  JejakuGeoAnchor toJejakuGeoAnchor({
    Uint8List? mediaPreviewBytes,
    String? resolvedMediaId,
    bool includePhotoTexture = false,
    bool includeLocalAnchorPose = false,
  }) {
    final attachment = mediaAttachment;
    final canRenderPhotoTexture = attachment != null &&
        attachment.type != AnchorMediaType.arRecording &&
        attachment.type != AnchorMediaType.arModel;
    final textureBytes = canRenderPhotoTexture && includePhotoTexture
        ? mediaPreviewBytes ?? attachment.bytes
        : null;
    final mediaId = resolvedMediaId ?? attachment?.mediaId;

    return JejakuGeoAnchor(
      id: id,
      title: title,
      caption: caption,
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: captureMetadata.altitudeMeters,
      headingDegrees: captureMetadata.headingDegrees,
      pitchDegrees: captureMetadata.pitchDegrees,
      rollDegrees: captureMetadata.rollDegrees,
      correctionEastMeters: captureMetadata.correctionEastMeters,
      correctionNorthMeters: captureMetadata.correctionNorthMeters,
      correctionUpMeters: captureMetadata.correctionUpMeters,
      isPrivate: isPrivate,
      metadata: <String, Object?>{
        'distanceLabel': distanceLabel,
        'capturedAgo': capturedAgo,
        'capturedAt': capturedAt?.toIso8601String(),
        'locationLabel': locationLabel,
        'gpsAccuracyMeters': captureMetadata.gpsAccuracyMeters,
        'hasManualCorrection': captureMetadata.hasManualCorrection,
        'correctionEastMeters': captureMetadata.correctionEastMeters,
        'correctionNorthMeters': captureMetadata.correctionNorthMeters,
        'correctionUpMeters': captureMetadata.correctionUpMeters,
        'anchorType': captureMetadata.anchorType,
        'captureSource': captureMetadata.captureSource,
        'localAnchorId': captureMetadata.localAnchorId,
        if (includeLocalAnchorPose && captureMetadata.localAnchorPose != null)
          'localAnchorPose': captureMetadata.localAnchorPose!.toMap(),
        'cloudAnchorId': captureMetadata.cloudAnchorId,
        'cloudAnchorExpiresAt':
            captureMetadata.cloudAnchorExpiresAt?.toIso8601String(),
        if (attachment != null) 'mediaType': attachment.type.name,
        if (mediaId != null && mediaId.trim().isNotEmpty)
          'mediaId': mediaId.trim(),
        if (attachment?.storagePath != null)
          'mediaStoragePath': attachment!.storagePath,
        if (attachment?.modelAsset != null) ...{
          'modelAsset': attachment!.modelAsset!.toMap(),
          'modelPath': attachment.modelAsset!.path,
          'modelFormat': attachment.modelAsset!.format.name,
          'modelSource': attachment.modelAsset!.source.name,
          if (attachment.modelAsset!.fallbackSizeMeters != null)
            'modelFallbackSizeMeters':
                attachment.modelAsset!.fallbackSizeMeters!.toMap(),
        },
        if (canRenderPhotoTexture) 'photoFrame': true,
        if (textureBytes != null && textureBytes.isNotEmpty) ...{
          'photoTextureBytes': textureBytes,
          'photoTextureByteLength': textureBytes.lengthInBytes,
          'photoTextureKey':
              '${mediaId?.trim().isNotEmpty == true ? mediaId!.trim() : id}:${textureBytes.lengthInBytes}',
        },
      },
    );
  }

  JejakuMemoryCloudAnchor? toJejakuCloudAnchor() {
    final localAnchorId = captureMetadata.localAnchorId;
    final cloudAnchorId = captureMetadata.cloudAnchorId;
    if (localAnchorId == null || cloudAnchorId == null) {
      return null;
    }
    return JejakuMemoryCloudAnchor(
      memoryId: id,
      localAnchorId: localAnchorId,
      cloudAnchorId: cloudAnchorId,
      expiresAt: captureMetadata.cloudAnchorExpiresAt,
    );
  }

  AnchorMemory withJejakuCloudAnchor(JejakuMemoryCloudAnchor record) {
    if (record.memoryId != id) {
      throw ArgumentError.value(
        record.memoryId,
        'record.memoryId',
        'Must match the memory id.',
      );
    }
    return copyWith(
      captureMetadata: captureMetadata.copyWith(
        localAnchorId: record.localAnchorId,
        cloudAnchorId: record.cloudAnchorId,
        cloudAnchorExpiresAt: record.expiresAt,
      ),
    );
  }
}

class ARMemoryProjection {
  const ARMemoryProjection({
    required this.memory,
    required this.projection,
  });

  final AnchorMemory memory;
  final JejakuAnchorProjection projection;
}

List<ARMemoryProjection> projectAnchorMemories({
  required Iterable<AnchorMemory> memories,
  required JejakuViewerPose viewerPose,
  JejakuViewProjector projector = const JejakuViewProjector(),
  bool onlyInRange = true,
}) {
  final memoryById = <String, AnchorMemory>{
    for (final memory in memories) memory.id: memory,
  };
  final projections = projector.projectAnchors(
    viewerPose: viewerPose,
    anchors: memories.map((memory) => memory.toJejakuGeoAnchor()),
    onlyInRange: onlyInRange,
  );

  return [
    for (final projection in projections)
      ARMemoryProjection(
        memory: memoryById[projection.anchor.id]!,
        projection: projection,
      ),
  ];
}
