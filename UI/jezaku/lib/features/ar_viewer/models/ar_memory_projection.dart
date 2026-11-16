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


/// Reuses immutable geographic inputs while the same AnchorMemory instances
/// remain in the source collection. Viewer pose changes still run projection,
/// but avoid rebuilding every JejakuGeoAnchor and its metadata map.
class ARMemoryProjectionCache {
  List<AnchorMemory> _memories = const <AnchorMemory>[];
  Map<String, AnchorMemory> _memoryById = const <String, AnchorMemory>{};
  List<JejakuGeoAnchor> _geoAnchors = const <JejakuGeoAnchor>[];
  bool _hasSnapshot = false;

  ({Map<String, AnchorMemory> memoryById, List<JejakuGeoAnchor> geoAnchors})
      resolve(Iterable<AnchorMemory> memories) {
    final nextMemories = memories.toList(growable: false);
    var unchanged = _hasSnapshot && nextMemories.length == _memories.length;
    if (unchanged) {
      for (var index = 0; index < nextMemories.length; index++) {
        if (!identical(nextMemories[index], _memories[index])) {
          unchanged = false;
          break;
        }
      }
    }

    if (!unchanged) {
      final memoryById = <String, AnchorMemory>{};
      final geoAnchors = <JejakuGeoAnchor>[];
      for (final memory in nextMemories) {
        memoryById[memory.id] = memory;
        geoAnchors.add(memory.toJejakuGeoAnchor());
      }
      _memories = nextMemories;
      _memoryById = memoryById;
      _geoAnchors = geoAnchors;
      _hasSnapshot = true;
    }

    return (memoryById: _memoryById, geoAnchors: _geoAnchors);
  }

  void clear() {
    _memories = const <AnchorMemory>[];
    _memoryById = const <String, AnchorMemory>{};
    _geoAnchors = const <JejakuGeoAnchor>[];
    _hasSnapshot = false;
  }
}

({Map<String, AnchorMemory> memoryById, List<JejakuGeoAnchor> geoAnchors})
    _buildProjectionInputs(Iterable<AnchorMemory> memories) {
  final memoryById = <String, AnchorMemory>{};
  final geoAnchors = <JejakuGeoAnchor>[];
  for (final memory in memories) {
    memoryById[memory.id] = memory;
    geoAnchors.add(memory.toJejakuGeoAnchor());
  }
  return (memoryById: memoryById, geoAnchors: geoAnchors);
}

List<ARMemoryProjection> projectAnchorMemories({
  required Iterable<AnchorMemory> memories,
  required JejakuViewerPose viewerPose,
  JejakuViewProjector projector = const JejakuViewProjector(),
  bool onlyInRange = true,
  ARMemoryProjectionCache? cache,
}) {
  // A cache hit avoids rebuilding geographic inputs and metadata maps when
  // only the viewer pose (heading, pitch, or viewport) changes.
  final inputs = cache?.resolve(memories) ?? _buildProjectionInputs(memories);
  final memoryById = inputs.memoryById;
  final geoAnchors = inputs.geoAnchors;
  final projections = projector.projectAnchors(
    viewerPose: viewerPose,
    anchors: geoAnchors,
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
