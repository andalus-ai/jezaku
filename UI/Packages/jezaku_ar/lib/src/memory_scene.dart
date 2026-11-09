import 'dart:math' as math;

import 'package:ar_engine/ar_engine.dart';

import 'capabilities.dart';
import 'geo_anchor.dart';
import 'geo_projector.dart';
import 'memory_model_descriptor.dart';
import 'memory_photo_frame.dart';

class JejakuPlacedMemory {
  const JejakuPlacedMemory({
    required this.memory,
    required this.anchorId,
    required this.nodeId,
    this.fingerprint = '',
    this.anchorFingerprint = '',
    this.nodeFingerprint = '',
  });

  final JejakuGeoAnchor memory;
  final String anchorId;
  final String nodeId;
  final String fingerprint;
  final String anchorFingerprint;
  final String nodeFingerprint;
}

class JejakuMemorySceneSyncResult {
  const JejakuMemorySceneSyncResult({
    this.added = const <JejakuPlacedMemory>[],
    this.updated = const <JejakuPlacedMemory>[],
    this.removed = const <JejakuPlacedMemory>[],
    this.active = const <JejakuPlacedMemory>[],
    this.placementReadiness,
  });

  final List<JejakuPlacedMemory> added;
  final List<JejakuPlacedMemory> updated;
  final List<JejakuPlacedMemory> removed;
  final List<JejakuPlacedMemory> active;
  final ARSessionReadiness? placementReadiness;

  bool get hasChanges {
    return added.isNotEmpty || updated.isNotEmpty || removed.isNotEmpty;
  }

  bool get isPlacementDeferred {
    final readiness = placementReadiness;
    return readiness != null && !readiness.canPlaceAnchors;
  }
}

class JejakuMemoryNodeFactory {
  const JejakuMemoryNodeFactory({
    this.widthMeters = 0.42,
    this.heightMeters = 0.28,
    this.forwardOffsetMeters = 1.2,
    this.photoFrameStyle = const JejakuHangingPhotoFrameStyle(),
  });

  final double widthMeters;
  final double heightMeters;
  final double forwardOffsetMeters;
  final JejakuHangingPhotoFrameStyle photoFrameStyle;

  ARNode build(JejakuGeoAnchor memory) {
    final modelDescriptor =
        JejakuMemoryModelDescriptor.tryFromMetadata(memory.metadata);
    if (modelDescriptor != null) {
      return _buildModelNode(memory, modelDescriptor);
    }

    final hasPhotoTexture = memory.metadata['photoTextureBytes'] != null;
    final hasLocalSurfacePose = memory.metadata['localAnchorPose'] is Map;
    final hasLocalHangingFramePose =
        _localPoseSurfaceType(memory) == 'hangingPhotoFrame';
    final sessionRelativePosition = _sessionRelativePosition(memory);
    final hasSessionPlacement = sessionRelativePosition != null;
    final nodeId = 'jejaku_memory_${memory.id}';
    final frameStyle = JejakuHangingPhotoFrameStyle.fromMetadata(
      memory.metadata,
      fallback: photoFrameStyle,
    );
    final photoSizeMeters = ARVector3(widthMeters, 0.01, heightMeters);
    return frameStyle.buildNode(
      id: nodeId,
      photoSizeMeters: photoSizeMeters,
      position: hasSessionPlacement
          ? sessionRelativePosition
          : hasLocalSurfacePose
              ? const ARVector3(0, 0.012, 0)
              : ARVector3(0, 0, -forwardOffsetMeters),
      rotation: hasLocalSurfacePose && !hasLocalHangingFramePose
          ? const ARQuaternion.identity()
          : ARQuaternion.axisAngle(ARVector3.right, math.pi / 2),
      photoMaterial: ARMaterial(
        baseColor: hasPhotoTexture
            ? const ARMaterialColor(r: 1, g: 1, b: 1)
            : memory.accentColor,
        roughness: 0.38,
        opacity: hasPhotoTexture ? 1 : 0.92,
        blendMode: hasPhotoTexture ? ARBlendMode.opaque : ARBlendMode.alpha,
        doubleSided: true,
      ),
      metadata: <String, Object?>{
        'package': 'jezaku_ar',
        'kind': 'geo_memory',
        'placementMode': hasLocalSurfacePose
            ? 'local_surface_pose'
            : hasSessionPlacement
                ? (memory.metadata['sessionPlacementMode'] as String?) ??
                    'hanging_photo_frame'
                : 'geo_projection',
        'memoryId': memory.id,
        'visualForwardOffsetMeters': forwardOffsetMeters,
        'title': memory.title,
        'caption': memory.caption,
        'latitude': memory.latitude,
        'longitude': memory.longitude,
        'altitudeMeters': memory.altitudeMeters,
        'headingDegrees': memory.headingDegrees,
        'correctionEastMeters': memory.correctionEastMeters,
        'correctionNorthMeters': memory.correctionNorthMeters,
        'correctionUpMeters': memory.correctionUpMeters,
        'isPrivate': memory.isPrivate,
        ...memory.metadata,
      },
    );
  }

  ARNode _buildModelNode(
    JejakuGeoAnchor memory,
    JejakuMemoryModelDescriptor model,
  ) {
    final validationReport = model.validationReport;
    final renderAsset = model.renderAsset;
    final renderProfile = renderAsset.renderProfile();
    final placement = model.placement;
    final fallbackSizeMeters = model.safeFallbackSizeMeters;
    final hasLocalSurfacePose = memory.metadata['localAnchorPose'] is Map;
    final sessionRelativePosition = _sessionRelativePosition(memory);
    final basePosition = sessionRelativePosition ??
        (hasLocalSurfacePose
            ? const ARVector3.zero()
            : placement.defaultProjectionPosition(forwardOffsetMeters));
    final placementMode = hasLocalSurfacePose
        ? 'local_surface_pose'
        : sessionRelativePosition != null
            ? (memory.metadata['sessionPlacementMode'] as String?) ??
                'hanging_model_object'
            : 'geo_projection';
    final node = ARNode.model(
      id: 'jejaku_memory_${memory.id}',
      asset: renderAsset,
      position: placement.resolvePosition(
        basePosition: basePosition,
        fallbackSizeMeters: fallbackSizeMeters,
      ),
      rotation: placement.rotation ?? const ARQuaternion.identity(),
      scale: placement.scale,
      material: model.material ??
          ARMaterial(
            baseColor: memory.accentColor,
            roughness: 0.52,
            doubleSided: true,
          ),
      metadata: <String, Object?>{
        'package': 'jezaku_ar',
        'kind': 'geo_memory_model',
        'placementMode': placementMode,
        'memoryId': memory.id,
        'visualForwardOffsetMeters': placement.forwardOffsetOr(
          forwardOffsetMeters,
        ),
        'title': memory.title,
        'caption': memory.caption,
        'latitude': memory.latitude,
        'longitude': memory.longitude,
        'altitudeMeters': memory.altitudeMeters,
        'headingDegrees': memory.headingDegrees,
        'correctionEastMeters': memory.correctionEastMeters,
        'correctionNorthMeters': memory.correctionNorthMeters,
        'correctionUpMeters': memory.correctionUpMeters,
        'isPrivate': memory.isPrivate,
        ...memory.metadata,
        'modelPlacement': placement.toMetadata(),
        'modelPlacementAnchorAlignment': placement.anchorAlignment.name,
        'modelPlacementFacingMode': placement.facingMode.name,
        'modelPlacementHasExplicitPosition': placement.hasExplicitPosition,
        'modelAsset': renderAsset.toMap(),
        'modelPath': renderAsset.path,
        'modelFormat': renderAsset.format.name,
        'modelValidationIsValid': validationReport.isValid,
        'modelValidationSummary': validationReport.summaryLabel,
        'modelValidationIssueLabels': validationReport.issueLabels,
        'modelValidationErrorLabels': validationReport.errorLabels,
        'modelValidationWarningLabels': validationReport.warningLabels,
        'modelUsesAndroidPrimitiveFallback':
            validationReport.usesAndroidPrimitiveFallback,
        'modelRenderProfileSummary': renderProfile.summaryLabel,
        'modelRenderProfileLabels': renderProfile.platformLabels,
        'modelRenderProfileNotes': renderProfile.noteLabels,
        'modelAndroidRenderMode': renderProfile.android.mode.name,
        'modelIosRenderMode': renderProfile.ios.mode.name,
        'modelUsesAnyPrimitiveFallback': renderProfile.usesAnyPrimitiveFallback,
        'modelRequiresPreparation': renderProfile.requiresPreparation,
      },
    );
    return node.copyWith(
      primitiveShape: model.fallbackShape,
      primitiveSize: fallbackSizeMeters ?? node.primitiveSize,
    );
  }

  String? _localPoseSurfaceType(JejakuGeoAnchor memory) {
    final raw = memory.metadata['localAnchorPose'];
    if (raw is! Map) {
      return null;
    }
    final surfaceType = raw['surfaceType'];
    return surfaceType is String ? surfaceType : null;
  }

  ARVector3? _sessionRelativePosition(JejakuGeoAnchor memory) {
    final raw = memory.metadata['sessionRelativePosition'];
    if (raw is! Map) {
      return null;
    }
    final x = _mapDouble(raw, 'x');
    final y = _mapDouble(raw, 'y');
    final z = _mapDouble(raw, 'z');
    if (x == null || y == null || z == null) {
      return null;
    }
    return ARVector3(x, y, z);
  }

  double? _mapDouble(Map<dynamic, dynamic> map, String key) {
    final value = map[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value);
    }
    return null;
  }
}

class JejakuMemoryARScene {
  JejakuMemoryARScene({
    required ARController controller,
    JejakuGeoProjector projector = const JejakuGeoProjector(),
    JejakuMemoryNodeFactory nodeFactory = const JejakuMemoryNodeFactory(),
    bool preferNativeGeospatialAnchors = true,
  })  : _controller = controller,
        _projector = projector,
        _nodeFactory = nodeFactory,
        _preferNativeGeospatialAnchors = preferNativeGeospatialAnchors;

  final ARController _controller;
  final JejakuGeoProjector _projector;
  final JejakuMemoryNodeFactory _nodeFactory;
  final bool _preferNativeGeospatialAnchors;
  final Map<String, JejakuPlacedMemory> _placedByMemoryId =
      <String, JejakuPlacedMemory>{};

  List<JejakuPlacedMemory> get placedMemories {
    return List<JejakuPlacedMemory>.unmodifiable(_placedByMemoryId.values);
  }

  JejakuPlacedMemory? getPlacedMemory(String memoryId) {
    return _placedByMemoryId[memoryId];
  }

  Future<JejakuARCapabilities> get capabilities {
    return JejakuARCapabilities.fromController(_controller);
  }

  Future<JejakuPlacedMemory> placeMemory({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor memory,
  }) async {
    await removeMemory(memory.id);
    return _placeNewMemory(origin: origin, memory: memory);
  }

  Future<JejakuPlacedMemory> placeMemoryAtAnchor({
    required ARAnchor anchor,
    required JejakuGeoAnchor memory,
  }) async {
    await removeMemory(memory.id);
    return _attachMemoryToAnchor(anchor: anchor, memory: memory);
  }

  Future<List<JejakuPlacedMemory>> placeMemories({
    required JejakuGeoOrigin origin,
    required Iterable<JejakuGeoAnchor> memories,
  }) async {
    final placed = <JejakuPlacedMemory>[];
    for (final memory in memories) {
      placed.add(await placeMemory(origin: origin, memory: memory));
    }
    return placed;
  }

  Future<JejakuMemorySceneSyncResult> syncMemories({
    required JejakuGeoOrigin origin,
    required Iterable<JejakuGeoAnchor> memories,
    Map<String, ARAnchor> resolvedAnchors = const <String, ARAnchor>{},
    ARSessionReadiness? placementReadiness,
  }) async {
    final desired = _deduplicateMemories(memories);
    final desiredIds = desired.map((memory) => memory.id).toSet();
    final added = <JejakuPlacedMemory>[];
    final updated = <JejakuPlacedMemory>[];
    final removed = <JejakuPlacedMemory>[];

    if (placementReadiness != null && !placementReadiness.canPlaceAnchors) {
      for (final existingId in _placedByMemoryId.keys.toList()) {
        if (!desiredIds.contains(existingId)) {
          final removedMemory = await removeMemory(existingId);
          if (removedMemory != null) {
            removed.add(removedMemory);
          }
        }
      }
      return JejakuMemorySceneSyncResult(
        removed: List<JejakuPlacedMemory>.unmodifiable(removed),
        active: [
          for (final memory in desired)
            if (_placedByMemoryId[memory.id] != null)
              _placedByMemoryId[memory.id]!,
        ],
        placementReadiness: placementReadiness,
      );
    }

    for (final memory in desired) {
      final existing = _placedByMemoryId[memory.id];
      final resolvedAnchor = resolvedAnchors[memory.id];
      final desiredAnchorFingerprint = _syncAnchorFingerprint(
        origin: origin,
        memory: memory,
        resolvedAnchor: resolvedAnchor,
      );
      if (existing == null) {
        added.add(
          await _placeSyncedMemory(
            origin: origin,
            memory: memory,
            resolvedAnchor: resolvedAnchor,
          ),
        );
      } else if (existing.anchorFingerprint != desiredAnchorFingerprint) {
        await removeMemory(memory.id);
        updated.add(
          await _placeSyncedMemory(
            origin: origin,
            memory: memory,
            resolvedAnchor: resolvedAnchor,
          ),
        );
      } else if (existing.nodeFingerprint != _nodeFingerprint(memory)) {
        updated.add(
          await _updatePlacedMemoryNode(
            existing: existing,
            memory: memory,
          ),
        );
      }
    }

    for (final existingId in _placedByMemoryId.keys.toList()) {
      if (!desiredIds.contains(existingId)) {
        final removedMemory = await removeMemory(existingId);
        if (removedMemory != null) {
          removed.add(removedMemory);
        }
      }
    }

    return JejakuMemorySceneSyncResult(
      added: List<JejakuPlacedMemory>.unmodifiable(added),
      updated: List<JejakuPlacedMemory>.unmodifiable(updated),
      removed: List<JejakuPlacedMemory>.unmodifiable(removed),
      active: [
        for (final memory in desired)
          if (_placedByMemoryId[memory.id] != null)
            _placedByMemoryId[memory.id]!,
      ],
      placementReadiness: placementReadiness,
    );
  }

  List<JejakuGeoAnchor> _deduplicateMemories(
    Iterable<JejakuGeoAnchor> memories,
  ) {
    final memoryById = <String, JejakuGeoAnchor>{};
    for (final memory in memories) {
      memoryById[memory.id] = memory;
    }
    return List<JejakuGeoAnchor>.unmodifiable(memoryById.values);
  }

  Future<JejakuPlacedMemory?> removeMemory(String memoryId) async {
    final existing = _placedByMemoryId[memoryId];
    if (existing == null) {
      return null;
    }
    await _controller.removeNode(existing.nodeId);
    await _controller.removeAnchor(existing.anchorId);
    _placedByMemoryId.remove(memoryId);
    return existing;
  }

  Future<void> clear() async {
    for (final memoryId in _placedByMemoryId.keys.toList()) {
      await removeMemory(memoryId);
    }
  }

  Future<JejakuPlacedMemory> _placeNewMemory({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor memory,
  }) async {
    final anchor = await _addAnchorForMemory(origin: origin, memory: memory);
    try {
      final node = _nodeFactory.build(memory);
      final nodeId = await _controller.addNode(node, anchorId: anchor.id);

      final placed = JejakuPlacedMemory(
        memory: memory,
        anchorId: anchor.id,
        nodeId: nodeId,
        fingerprint: _fingerprint(origin: origin, memory: memory),
        anchorFingerprint: _anchorFingerprint(origin: origin, memory: memory),
        nodeFingerprint: _nodeFingerprint(memory),
      );
      _placedByMemoryId[memory.id] = placed;
      return placed;
    } catch (_) {
      await _removeAnchorBestEffort(anchor.id);
      rethrow;
    }
  }

  Future<ARAnchor> _addAnchorForMemory({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor memory,
  }) async {
    final sessionPoseInput = _sessionAnchorPoseInput(memory);
    if (sessionPoseInput != null) {
      final anchor = await _controller.addAnchorAtPose(sessionPoseInput);
      return anchor.copyWith(
        metadata: <String, dynamic>{
          ...anchor.metadata,
          ...memory.toARGeospatialAnchor().toAnchorMetadata(
                nativeGeospatial: false,
              ),
          'sessionCameraPlacement': true,
        },
      );
    }
    final localPoseInput = _localSurfacePoseInput(memory);
    if (localPoseInput != null) {
      final anchor = await _controller.addAnchorAtPose(localPoseInput);
      return anchor.copyWith(
        metadata: <String, dynamic>{
          ...anchor.metadata,
          ...memory.toARGeospatialAnchor().toAnchorMetadata(
                nativeGeospatial: false,
              ),
          'localSurfacePose': true,
        },
      );
    }
    if (_preferNativeGeospatialAnchors) {
      try {
        return await _controller.addGeospatialAnchor(
          memory.toARGeospatialAnchor(),
          origin: origin.toARGeoOrigin(),
        );
      } on Object {
        // If Earth/VPS/geospatial tracking is unavailable, keep the AR visual
        // path alive by placing the same memory in local world space.
      }
    }
    return _addLocalProjectionAnchor(origin: origin, memory: memory);
  }

  ARPoseInput? _sessionAnchorPoseInput(JejakuGeoAnchor memory) {
    final pose = memory.metadata['sessionAnchorPose'];
    if (pose is! Map) {
      return null;
    }
    return _poseInputFromMap(pose);
  }

  ARPoseInput? _localSurfacePoseInput(JejakuGeoAnchor memory) {
    final pose = memory.metadata['localAnchorPose'];
    if (pose is! Map) {
      return null;
    }
    return _poseInputFromMap(pose);
  }

  ARPoseInput? _poseInputFromMap(Map<dynamic, dynamic> pose) {
    final position = pose['position'];
    final rotation = pose['rotation'];
    if (position is Map && rotation is Map) {
      final x = _poseDouble(position, 'x');
      final y = _poseDouble(position, 'y');
      final z = _poseDouble(position, 'z');
      final qx = _poseDouble(rotation, 'x');
      final qy = _poseDouble(rotation, 'y');
      final qz = _poseDouble(rotation, 'z');
      final qw = _poseDouble(rotation, 'w', fallback: 1);
      if (x == null ||
          y == null ||
          z == null ||
          qx == null ||
          qy == null ||
          qz == null ||
          qw == null) {
        return null;
      }
      return ARPoseInput(
        x: x,
        y: y,
        z: z,
        qx: qx,
        qy: qy,
        qz: qz,
        qw: qw,
      );
    }
    final x = _poseDouble(pose, 'x');
    final y = _poseDouble(pose, 'y');
    final z = _poseDouble(pose, 'z');
    final qx = _poseDouble(pose, 'qx');
    final qy = _poseDouble(pose, 'qy');
    final qz = _poseDouble(pose, 'qz');
    final qw = _poseDouble(pose, 'qw', fallback: 1);
    if (x == null ||
        y == null ||
        z == null ||
        qx == null ||
        qy == null ||
        qz == null ||
        qw == null) {
      return null;
    }
    return ARPoseInput(
      x: x,
      y: y,
      z: z,
      qx: qx,
      qy: qy,
      qz: qz,
      qw: qw,
    );
  }

  double? _poseDouble(Map<dynamic, dynamic> pose, String key,
      {double? fallback}) {
    final value = pose[key];
    if (value is num) {
      return value.toDouble();
    }
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  Future<ARAnchor> _addLocalProjectionAnchor({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor memory,
  }) async {
    final pose = _projector.toPoseInput(origin: origin, anchor: memory);
    final anchor = await _controller.addAnchorAtPose(pose);
    return anchor.copyWith(
      metadata: <String, dynamic>{
        ...anchor.metadata,
        ...memory.toARGeospatialAnchor().toAnchorMetadata(
              nativeGeospatial: false,
            ),
        'localGeospatialProjection': true,
      },
    );
  }

  Future<JejakuPlacedMemory> _attachMemoryToAnchor({
    required ARAnchor anchor,
    required JejakuGeoAnchor memory,
  }) async {
    final node = _nodeFactory.build(memory);
    final nodeId = await _controller.addNode(node, anchorId: anchor.id);
    final placed = JejakuPlacedMemory(
      memory: memory,
      anchorId: anchor.id,
      nodeId: nodeId,
      fingerprint: _resolvedAnchorFingerprint(
        anchor: anchor,
        memory: memory,
      ),
      anchorFingerprint: _resolvedAnchorFingerprint(
        anchor: anchor,
        memory: memory,
      ),
      nodeFingerprint: _nodeFingerprint(memory),
    );
    _placedByMemoryId[memory.id] = placed;
    return placed;
  }

  Future<JejakuPlacedMemory> _placeSyncedMemory({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor memory,
    ARAnchor? resolvedAnchor,
  }) {
    if (resolvedAnchor != null) {
      return _attachMemoryToAnchor(anchor: resolvedAnchor, memory: memory);
    }
    return _placeNewMemory(origin: origin, memory: memory);
  }

  Future<void> _removeAnchorBestEffort(String anchorId) async {
    try {
      await _controller.removeAnchor(anchorId);
    } on Object {
      // Placement failed; the next session reset will clear any stale anchor.
    }
  }

  Future<JejakuPlacedMemory> _updatePlacedMemoryNode({
    required JejakuPlacedMemory existing,
    required JejakuGeoAnchor memory,
  }) async {
    final node = _nodeFactory.build(memory).copyWith(id: existing.nodeId);
    await _controller.updateNode(node);
    final placed = JejakuPlacedMemory(
      memory: memory,
      anchorId: existing.anchorId,
      nodeId: existing.nodeId,
      fingerprint: _joinFingerprints(
        existing.anchorFingerprint,
        _nodeFingerprint(memory),
      ),
      anchorFingerprint: existing.anchorFingerprint,
      nodeFingerprint: _nodeFingerprint(memory),
    );
    _placedByMemoryId[memory.id] = placed;
    return placed;
  }

  String _fingerprint({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor memory,
  }) {
    return _joinFingerprints(
      _anchorFingerprint(origin: origin, memory: memory),
      _nodeFingerprint(memory),
    );
  }

  String _joinFingerprints(String anchor, String node) {
    return '$anchor||$node';
  }

  String _anchorFingerprint({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor memory,
  }) {
    return <Object?>[
      origin.latitude,
      origin.longitude,
      origin.altitudeMeters,
      memory.id,
      memory.latitude,
      memory.longitude,
      memory.altitudeMeters,
      memory.headingDegrees,
      memory.pitchDegrees,
      memory.rollDegrees,
      memory.correctionEastMeters,
      memory.correctionNorthMeters,
      memory.correctionUpMeters,
      memory.metadata['localAnchorPose'],
      memory.metadata['sessionAnchorPose'],
      memory.metadata['sessionRelativePosition'],
    ].join('|');
  }

  String _syncAnchorFingerprint({
    required JejakuGeoOrigin origin,
    required JejakuGeoAnchor memory,
    ARAnchor? resolvedAnchor,
  }) {
    if (resolvedAnchor != null) {
      return _resolvedAnchorFingerprint(anchor: resolvedAnchor, memory: memory);
    }
    return _anchorFingerprint(origin: origin, memory: memory);
  }

  String _nodeFingerprint(JejakuGeoAnchor memory) {
    final metadata = memory.metadata.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <Object?>[
      memory.id,
      memory.title,
      memory.caption,
      memory.isPrivate,
      for (final entry in metadata) '${entry.key}:${entry.value}',
    ].join('|');
  }

  String _resolvedAnchorFingerprint({
    required ARAnchor anchor,
    required JejakuGeoAnchor memory,
  }) {
    return <Object?>[
      'resolved',
      anchor.id,
      anchor.metadata['cloudAnchorId'],
      memory.id,
    ].join('|');
  }
}
