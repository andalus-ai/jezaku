import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

enum ARMemoryCloudAnchorResolutionFailureReason {
  expired,
  resolveReturnedNull,
  nativeError,
  unsupportedCapability;
}

class ARMemoryCloudAnchorResolutionReport {
  const ARMemoryCloudAnchorResolutionReport({
    this.resolvedMemoryIds = const <String>{},
    this.unresolvedMemoryIds = const <String>{},
    this.expiredMemoryIds = const <String>{},
    this.failureReasons =
        const <String, ARMemoryCloudAnchorResolutionFailureReason>{},
  });

  final Set<String> resolvedMemoryIds;
  final Set<String> unresolvedMemoryIds;
  final Set<String> expiredMemoryIds;
  final Map<String, ARMemoryCloudAnchorResolutionFailureReason> failureReasons;

  bool get hasUnresolvedRecords => unresolvedMemoryIds.isNotEmpty;

  bool get hasFailures => failureReasons.isNotEmpty;

  ARMemoryCloudAnchorResolutionFailureReason? reasonFor(String memoryId) {
    return failureReasons[memoryId];
  }

  Set<String> memoryIdsForReason(
    ARMemoryCloudAnchorResolutionFailureReason reason,
  ) {
    return Set<String>.unmodifiable(
      failureReasons.entries
          .where((entry) => entry.value == reason)
          .map((entry) => entry.key),
    );
  }
}

class ARMemorySceneSyncOutcome {
  const ARMemorySceneSyncOutcome({
    required this.scene,
    this.cloudAnchors = const ARMemoryCloudAnchorResolutionReport(),
    this.modelPreflight = const JejakuMemoryModelPreflightReport(),
  });

  final JejakuMemorySceneSyncResult scene;
  final ARMemoryCloudAnchorResolutionReport cloudAnchors;
  final JejakuMemoryModelPreflightReport modelPreflight;
}

class ARMemorySessionPlacement {
  const ARMemorySessionPlacement({
    required this.anchorPose,
    required this.nodePosition,
    this.mode = 'hanging_photo_frame',
  });

  final ARPoseInput anchorPose;
  final ARVector3 nodePosition;
  final String mode;

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'sessionAnchorPose': anchorPose.toMap(),
      'sessionRelativePosition': nodePosition.toMap(),
      'sessionPlacementMode': mode,
    };
  }
}

class ARMemorySceneSyncService {
  const ARMemorySceneSyncService();

  Future<ARMemorySceneSyncOutcome> sync({
    required JejakuMemoryARScene scene,
    required JejakuGeoOrigin origin,
    required Iterable<AnchorMemory> memories,
    JejakuMemoryCloudAnchorManager? cloudAnchorManager,
    ARSessionReadiness? placementReadiness,
    Map<String, Uint8List> mediaPreviewBytesByMemoryId =
        const <String, Uint8List>{},
    Map<String, String> mediaIdsByMemoryId = const <String, String>{},
    Map<String, ARMemorySessionPlacement> sessionPlacementsByMemoryId =
        const <String, ARMemorySessionPlacement>{},
    JejakuMemoryModelCachePreflight? modelPreflight,
    DateTime? nativeSessionStartedAt,
    DateTime? now,
  }) async {
    final memoryList = List<AnchorMemory>.unmodifiable(memories);
    final sceneAnchors = [
      for (final memory in memoryList)
        _toSceneAnchor(
          memory: memory,
          mediaPreviewBytes: mediaPreviewBytesByMemoryId[memory.id],
          resolvedMediaId: mediaIdsByMemoryId[memory.id],
          sessionPlacement: sessionPlacementsByMemoryId[memory.id],
          nativeSessionStartedAt: nativeSessionStartedAt,
        ),
    ];
    final modelPreflightOutput = await _preflightModelAnchors(
      sceneAnchors,
      modelPreflight,
    );
    final geoAnchors = modelPreflightOutput.anchors;
    if (placementReadiness != null && !placementReadiness.canPlaceAnchors) {
      final sceneResult = await scene.syncMemories(
        origin: origin,
        memories: geoAnchors,
        placementReadiness: placementReadiness,
      );
      return ARMemorySceneSyncOutcome(
        scene: sceneResult,
        modelPreflight: modelPreflightOutput.report,
      );
    }

    final cloudAnchorResolution = cloudAnchorManager == null
        ? const _CloudAnchorResolution()
        : await _resolveCloudAnchors(
            manager: cloudAnchorManager,
            memories: memoryList,
            now: now,
          );
    final sceneResult = await scene.syncMemories(
      origin: origin,
      memories: geoAnchors,
      resolvedAnchors: cloudAnchorResolution.resolvedAnchors,
      placementReadiness: placementReadiness,
    );
    return ARMemorySceneSyncOutcome(
      scene: sceneResult,
      cloudAnchors: cloudAnchorResolution.report,
      modelPreflight: modelPreflightOutput.report,
    );
  }

  Future<_ModelAnchorPreflightOutput> _preflightModelAnchors(
    List<JejakuGeoAnchor> anchors,
    JejakuMemoryModelCachePreflight? modelPreflight,
  ) async {
    if (modelPreflight == null || anchors.isEmpty) {
      return _ModelAnchorPreflightOutput(
        anchors: anchors,
        report: const JejakuMemoryModelPreflightReport(),
      );
    }
    final report = await modelPreflight.prepareMemoriesWithReport(anchors);
    return _ModelAnchorPreflightOutput(
      anchors: [
        for (final result in report.results) result.preparedMemory,
      ],
      report: report,
    );
  }

  String fingerprint({
    required JejakuGeoOrigin origin,
    required Iterable<AnchorMemory> memories,
    Map<String, Uint8List> mediaPreviewBytesByMemoryId =
        const <String, Uint8List>{},
    Map<String, String> mediaIdsByMemoryId = const <String, String>{},
    Map<String, ARMemorySessionPlacement> sessionPlacementsByMemoryId =
        const <String, ARMemorySessionPlacement>{},
    DateTime? nativeSessionStartedAt,
  }) {
    return <String>[
      '${origin.latitude}:${origin.longitude}:${origin.altitudeMeters}',
      for (final memory in memories)
        _memoryFingerprint(
          memory,
          mediaPreviewBytes: mediaPreviewBytesByMemoryId[memory.id],
          resolvedMediaId: mediaIdsByMemoryId[memory.id],
          sessionPlacement: sessionPlacementsByMemoryId[memory.id],
          nativeSessionStartedAt: nativeSessionStartedAt,
        ),
    ].join('||');
  }

  String _memoryFingerprint(
    AnchorMemory memory, {
    Uint8List? mediaPreviewBytes,
    String? resolvedMediaId,
    ARMemorySessionPlacement? sessionPlacement,
    DateTime? nativeSessionStartedAt,
  }) {
    final anchor = _toSceneAnchor(
      memory: memory,
      mediaPreviewBytes: mediaPreviewBytes,
      resolvedMediaId: resolvedMediaId,
      sessionPlacement: sessionPlacement,
      nativeSessionStartedAt: nativeSessionStartedAt,
    );
    final metadata = anchor.metadata.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <Object?>[
      anchor.id,
      anchor.latitude,
      anchor.longitude,
      anchor.altitudeMeters,
      anchor.headingDegrees,
      anchor.pitchDegrees,
      anchor.rollDegrees,
      anchor.correctionEastMeters,
      anchor.correctionNorthMeters,
      anchor.correctionUpMeters,
      anchor.title,
      anchor.caption,
      anchor.isPrivate,
      for (final entry in metadata)
        '${entry.key}:${_fingerprintValue(entry.value)}',
    ].join('|');
  }

  Object? _fingerprintValue(Object? value) {
    if (value is Uint8List) {
      return 'bytes:${value.lengthInBytes}';
    }
    return value;
  }

  JejakuGeoAnchor _toSceneAnchor({
    required AnchorMemory memory,
    Uint8List? mediaPreviewBytes,
    String? resolvedMediaId,
    ARMemorySessionPlacement? sessionPlacement,
    DateTime? nativeSessionStartedAt,
  }) {
    final canUseLocalPose = _canUseLocalAnchorPose(
      memory,
      nativeSessionStartedAt: nativeSessionStartedAt,
    );
    final anchor = memory.toJejakuGeoAnchor(
      mediaPreviewBytes: mediaPreviewBytes,
      resolvedMediaId: resolvedMediaId,
      includePhotoTexture: true,
      includeLocalAnchorPose: canUseLocalPose,
    );
    if (canUseLocalPose || sessionPlacement == null) {
      return anchor;
    }
    return anchor.copyWith(
      metadata: <String, Object?>{
        ...anchor.metadata,
        ...sessionPlacement.toMetadata(),
      },
    );
  }

  bool _canUseLocalAnchorPose(
    AnchorMemory memory, {
    required DateTime? nativeSessionStartedAt,
  }) {
    final localPose = memory.captureMetadata.localAnchorPose;
    final poseCapturedAt = localPose?.capturedAt?.toUtc();
    final sessionStartedAt = nativeSessionStartedAt?.toUtc();
    if (localPose == null ||
        poseCapturedAt == null ||
        sessionStartedAt == null) {
      return false;
    }
    return !poseCapturedAt.isBefore(
      sessionStartedAt.subtract(const Duration(seconds: 5)),
    );
  }

  Future<_CloudAnchorResolution> _resolveCloudAnchors({
    required JejakuMemoryCloudAnchorManager manager,
    required Iterable<AnchorMemory> memories,
    DateTime? now,
  }) async {
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final anchors = <String, ARAnchor>{};
    final resolvedMemoryIds = <String>{};
    final unresolvedMemoryIds = <String>{};
    final expiredMemoryIds = <String>{};
    final failureReasons =
        <String, ARMemoryCloudAnchorResolutionFailureReason>{};

    for (final memory in memories) {
      final record = memory.toJejakuCloudAnchor();
      if (record == null) {
        continue;
      }
      if (_isExpired(record, effectiveNow)) {
        expiredMemoryIds.add(memory.id);
        failureReasons[memory.id] =
            ARMemoryCloudAnchorResolutionFailureReason.expired;
        continue;
      }
      try {
        final resolved = await manager.resolveMemoryAnchor(record);
        if (resolved != null) {
          anchors[memory.id] = resolved.anchor;
          resolvedMemoryIds.add(memory.id);
        } else {
          unresolvedMemoryIds.add(memory.id);
          failureReasons[memory.id] =
              ARMemoryCloudAnchorResolutionFailureReason.resolveReturnedNull;
        }
      } on Object {
        unresolvedMemoryIds.add(memory.id);
        failureReasons[memory.id] =
            ARMemoryCloudAnchorResolutionFailureReason.nativeError;
        // Cloud anchor resolution is best effort; geospatial placement remains.
      }
    }

    return _CloudAnchorResolution(
      resolvedAnchors: Map<String, ARAnchor>.unmodifiable(anchors),
      report: ARMemoryCloudAnchorResolutionReport(
        resolvedMemoryIds: Set<String>.unmodifiable(resolvedMemoryIds),
        unresolvedMemoryIds: Set<String>.unmodifiable(unresolvedMemoryIds),
        expiredMemoryIds: Set<String>.unmodifiable(expiredMemoryIds),
        failureReasons: Map<String,
                ARMemoryCloudAnchorResolutionFailureReason>.unmodifiable(
            failureReasons),
      ),
    );
  }

  bool _isExpired(JejakuMemoryCloudAnchor record, DateTime now) {
    final expiresAt = record.expiresAt;
    return expiresAt != null && !expiresAt.toUtc().isAfter(now);
  }
}

class _ModelAnchorPreflightOutput {
  const _ModelAnchorPreflightOutput({
    required this.anchors,
    required this.report,
  });

  final List<JejakuGeoAnchor> anchors;
  final JejakuMemoryModelPreflightReport report;
}

class _CloudAnchorResolution {
  const _CloudAnchorResolution({
    this.resolvedAnchors = const <String, ARAnchor>{},
    this.report = const ARMemoryCloudAnchorResolutionReport(),
  });

  final Map<String, ARAnchor> resolvedAnchors;
  final ARMemoryCloudAnchorResolutionReport report;
}
