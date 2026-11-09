import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/ar_viewer/services/ar_runtime_permission_service.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jejaku/features/camera/models/capture_minimap_dot.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/models/imported_capture_candidate.dart';
import 'package:jejaku/features/camera/services/capture_import_service.dart';
import 'package:jejaku/features/camera/services/capture_minimap_service.dart';
import 'package:jejaku/features/camera/services/safe_capture_preview_service.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:jejaku/features/camera/widgets/live_camera_preview.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:jejaku/features/trails/models/ar_trail_route.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final ARRuntimePermissionService _arPermissionService =
      const ARRuntimePermissionService();
  final GlobalKey<LiveCameraPreviewState> _liveCameraPreviewKey =
      GlobalKey<LiveCameraPreviewState>();
  late Future<ARRuntimePermissions> _arPermissionsFuture;
  bool _didAutoRequestARPermissions = false;
  bool _isCockpitVisible = false;
  bool _isGridVisible = false;
  bool _isLevelVisible = false;
  bool _isMinimapExpanded = false;
  _CaptureMinimapFilter _minimapFilter = _CaptureMinimapFilter.all;
  bool _isCaptured = false;
  bool _isCapturing = false;
  double _exposure = 0;

  @override
  void initState() {
    super.initState();
    _arPermissionsFuture = _checkARRuntimePermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _autoRequestARRuntimePermissions();
        ref.read(captureSessionProvider.notifier).clearDraft();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<ARRuntimePermissions> _checkARRuntimePermissions() async {
    final permissions = await _arPermissionService.check();
    if (mounted && permissions.cameraGranted) {
      ref.invalidate(arViewerCapabilitiesProvider);
      ref.invalidate(arViewerSessionPlanProvider);
      ref.invalidate(arViewerSessionConfigProvider);
    }
    return permissions;
  }

  Future<ARRuntimePermissions> _loadARRuntimePermissions() async {
    final permissions = await _arPermissionService.request();
    if (mounted && permissions.cameraGranted) {
      ref.invalidate(arViewerCapabilitiesProvider);
      ref.invalidate(arViewerSessionPlanProvider);
      ref.invalidate(arViewerSessionConfigProvider);
    }
    return permissions;
  }

  void _autoRequestARRuntimePermissions() {
    if (_didAutoRequestARPermissions ||
        !_arPermissionService.usesMobileRuntimePermissions) {
      return;
    }
    _didAutoRequestARPermissions = true;
    unawaited(_requestARRuntimePermissionsAfterFirstFrame());
  }

  Future<void> _requestARRuntimePermissionsAfterFirstFrame() async {
    final current = await _arPermissionService.check();
    if (!mounted || (current.cameraGranted && current.locationGranted)) {
      return;
    }
    setState(() {
      _arPermissionsFuture = _loadARRuntimePermissions();
    });
  }

  void _retryARRuntimePermissions() {
    setState(() {
      _arPermissionsFuture = _loadARRuntimePermissions();
    });
  }

  void _openARRuntimePermissionSettings() {
    unawaited(_arPermissionService.openSettings());
  }

  @override
  Widget build(BuildContext context) {
    final captureSession = ref.watch(captureSessionProvider);
    final anchors = ref.watch(nearbyAnchorsProvider);
    final walls = ref.watch(arWallsProvider);
    final wallLinkedMemoryIds = {
      for (final wall in walls) ...wall.linkedMemoryIds,
    };
    final wallTitlesByMemoryId = _wallTitlesByMemoryId(walls);
    final projectedObjects = _captureProjectedObjects(
      anchors,
      captureSession.previewSnapshot,
    );
    final minimapTop = MediaQuery.sizeOf(context).height < 700 ? 156.0 : 238.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildPreview(),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: _CaptureARObjectsOverlay(
                  anchors: projectedObjects,
                  wallTitlesByMemoryId: wallTitlesByMemoryId,
                ),
              ),
            ),
            if (_isCockpitVisible && _isGridVisible)
              const Positioned.fill(child: _CameraGrid()),
            if (_isCockpitVisible && _isLevelVisible)
              const Align(
                alignment: Alignment.center,
                child: _LevelIndicator(),
              ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _buildTopControls(),
            ),
            if (_isCockpitVisible)
              Positioned(
                top: 72,
                left: 16,
                right: 16,
                child: _CaptureTelemetry(
                  snapshot: captureSession.previewSnapshot,
                  statusLabel: captureSession.statusLabel,
                ),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: _buildBottomControls(captureSession),
            ),
            if (_isCockpitVisible)
              Positioned(
                top: minimapTop,
                right: 16,
                child: _CaptureMinimap(
                  snapshot: captureSession.previewSnapshot,
                  anchors: anchors,
                  wallLinkedMemoryIds: wallLinkedMemoryIds,
                  wallTitlesByMemoryId: wallTitlesByMemoryId,
                  isExpanded: _isMinimapExpanded,
                  selectedFilter: _minimapFilter,
                  onFilterChanged: (filter) {
                    setState(() => _minimapFilter = filter);
                  },
                  onToggle: () {
                    setState(() => _isMinimapExpanded = !_isMinimapExpanded);
                  },
                  onStartTrail: _openMinimapTrail,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return FutureBuilder<ARRuntimePermissions>(
      future: _arPermissionsFuture,
      builder: (context, permissionSnapshot) {
        final permissions = permissionSnapshot.data;
        if (permissions == null) {
          return _buildPreviewFallback(message: 'Preparing camera access');
        }
        if (!permissions.cameraGranted) {
          return _buildPreviewFallback(
            message: permissions.guidanceLabel,
            actionLabel: permissions.shouldOpenSettings
                ? 'Open settings'
                : 'Grant access',
            onAction: permissions.shouldOpenSettings
                ? _openARRuntimePermissionSettings
                : _retryARRuntimePermissions,
          );
        }
        return LiveCameraPreview(
          key: _liveCameraPreviewKey,
          fallback: _buildPreviewFallback(message: 'Preparing camera'),
          onError: (_) {
            if (!mounted) {
              return;
            }
            setState(() {});
          },
        );
      },
    );
  }

  List<ARMemoryProjection> _captureProjectedObjects(
    List<AnchorMemory> anchors,
    CaptureSensorSnapshot snapshot,
  ) {
    final projected = projectAnchorMemories(
      memories: anchors,
      viewerPose: JejakuViewerPose(
        origin: JejakuGeoOrigin(
          latitude: snapshot.latitude,
          longitude: snapshot.longitude,
          altitudeMeters: snapshot.altitudeMeters,
        ),
        headingDegrees: snapshot.headingDegrees,
        pitchDegrees: snapshot.pitchDegrees,
        horizontalFovDegrees: 118,
        verticalFovDegrees: 56,
        maxDistanceMeters: 100,
      ),
      onlyInRange: false,
    );
    return projected.take(5).toList(growable: false);
  }

  Widget _buildPreviewFallback({
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1F2937),
            Color(0xFF030712),
          ],
        ),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _isCaptured
              ? const Icon(
                  Icons.check_circle,
                  key: ValueKey('captured'),
                  color: Colors.white,
                  size: 88,
                )
              : Column(
                  key: const ValueKey('preview'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_camera,
                      color: Colors.white70,
                      size: 72,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'AR Camera Preview',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: onAction,
                        child: Text(actionLabel),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Row(
      children: [
        _RoundCameraButton(
          tooltip: 'Close',
          icon: Icons.close,
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        _RoundCameraButton(
          tooltip: _isCockpitVisible ? 'Hide navigation' : 'Show navigation',
          icon: _isCockpitVisible
              ? Icons.dashboard_customize
              : Icons.dashboard_customize_outlined,
          onPressed: () {
            setState(() {
              _isCockpitVisible = !_isCockpitVisible;
              if (_isCockpitVisible && !_isGridVisible && !_isLevelVisible) {
                _isLevelVisible = true;
              }
            });
          },
        ),
        if (_isCockpitVisible) ...[
          const SizedBox(width: 8),
          _RoundCameraButton(
            tooltip: 'Toggle grid',
            icon: _isGridVisible ? Icons.grid_on : Icons.grid_off,
            onPressed: () => setState(() => _isGridVisible = !_isGridVisible),
          ),
          const SizedBox(width: 8),
          _RoundCameraButton(
            tooltip: 'Toggle level',
            icon: _isLevelVisible ? Icons.explore : Icons.explore_off,
            onPressed: () => setState(() => _isLevelVisible = !_isLevelVisible),
          ),
          const SizedBox(width: 8),
          _RoundCameraButton(
            tooltip: 'Camera settings',
            icon: Icons.tune,
            onPressed: _showCameraSettings,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomControls(CaptureSessionState captureSession) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isCockpitVisible) ...[
          Row(
            children: [
              const Icon(Icons.exposure, color: Colors.white70, size: 18),
              Expanded(
                child: Slider(
                  value: _exposure,
                  min: -1,
                  max: 1,
                  onChanged: (value) => setState(() => _exposure = value),
                ),
              ),
              Text(
                _exposure.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: _showAnchorSetup,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withValues(alpha: 0.24),
              ),
              icon: const Icon(Icons.view_in_ar, size: 18),
              label: Text('Anchor: ${captureSession.anchorPlanLabel}'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CameraModeButton(
              icon: Icons.photo_library_outlined,
              label: 'Import',
              onPressed: _showImportPicker,
            ),
            IconButton(
              tooltip: 'Capture memory',
              onPressed: _isCapturing ? null : _capture,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(76),
                backgroundColor:
                    _isCaptured ? Colors.greenAccent : Colors.white,
                foregroundColor: Colors.black,
                shape: const CircleBorder(),
                side: const BorderSide(color: Colors.white, width: 4),
              ),
              icon: Icon(
                _isCapturing
                    ? Icons.hourglass_top
                    : _isCaptured
                        ? Icons.check
                        : Icons.camera_alt,
                size: 30,
              ),
            ),
            _CameraModeButton(
              icon: Icons.view_in_ar,
              label: 'Anchor',
              onPressed: _showAnchorSetup,
            ),
          ],
        ),
      ],
    );
  }

  void _capture() {
    if (_isCapturing) {
      return;
    }
    final snapshot = ref.read(captureSessionProvider).previewSnapshot;
    if (snapshot.captureReadinessLevel == CaptureReadinessLevel.calibrate) {
      _showCalibrationCapturePrompt(snapshot);
      return;
    }

    unawaited(_stageCurrentCapture());
  }

  Future<void> _stageCurrentCapture() async {
    if (_isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    final capturedAt = DateTime.now();

    try {
      final sessionController = ref.read(captureSessionProvider.notifier);
      await sessionController.refreshPreviewFromDeviceSensors();
      if (!mounted) {
        return;
      }
      final previewBytes = await _captureRenderedPreview();
      if (!mounted) {
        return;
      }
      ref.read(captureSessionProvider.notifier).stageCurrentCapture(
            capturedAt: capturedAt,
            bytes: previewBytes,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _isCaptured = true;
        _isCapturing = false;
      });
      Navigator.pushReplacementNamed(context, AppRoutes.publish);
    } finally {
      if (mounted && _isCapturing) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<Uint8List?> _captureRenderedPreview() async {
    final previewBytes = await _liveCameraPreviewKey.currentState
        ?.captureJpeg()
        .timeout(const Duration(milliseconds: 1900), onTimeout: () => null);
    if (previewBytes != null && previewBytes.isNotEmpty) {
      return previewBytes;
    }
    final snapshot = ref.read(captureSessionProvider).previewSnapshot;
    return const SafeCapturePreviewService().renderPreview(
      snapshot: snapshot,
      capturedAt: DateTime.now(),
    );
  }

  void _showCalibrationCapturePrompt(CaptureSensorSnapshot snapshot) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${snapshot.captureReadinessLabel} before anchoring. '
            '${snapshot.captureGuidanceLabel}',
          ),
          action: SnackBarAction(
            label: 'Capture anyway',
            onPressed: () => unawaited(_stageCurrentCapture()),
          ),
        ),
      );
  }

  void _showCameraSettings() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Cockpit navigation'),
                value: _isCockpitVisible,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() => _isCockpitVisible = value);
                },
              ),
              SwitchListTile(
                title: const Text('Grid'),
                value: _isGridVisible,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() => _isGridVisible = value);
                },
              ),
              SwitchListTile(
                title: const Text('Level assist'),
                value: _isLevelVisible,
                onChanged: (value) {
                  Navigator.pop(context);
                  setState(() => _isLevelVisible = value);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImportPicker() {
    final candidates = ref.read(captureImportServiceProvider).recentImports();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import Photo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a photo with location metadata to stage an AR anchor.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final candidate = candidates[index];
                      return _ImportCandidateTile(
                        candidate: candidate,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _stageImportedCapture(candidate);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _stageImportedCapture(ImportedCaptureCandidate candidate) {
    ref.read(captureSessionProvider.notifier).stageImportedCapture(
          candidate.snapshot,
          capturedAt: candidate.capturedAt,
        );
    setState(() => _isCaptured = true);
    Navigator.pushReplacementNamed(context, AppRoutes.publish);
  }

  void _showAnchorSetup() {
    var selectedPreset = ref.read(captureSessionProvider).anchorPreset;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anchor Setup',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose the radius before capturing this AR memory.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final preset in CaptureAnchorPreset.values)
                            ListTile(
                              key: ValueKey('anchor_preset_${preset.name}'),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(_iconForAnchorPreset(preset)),
                              title: Text(preset.planLabel),
                              subtitle: Text(preset.description),
                              selected: selectedPreset == preset,
                              trailing: selectedPreset == preset
                                  ? const Icon(Icons.check_circle)
                                  : const Icon(Icons.circle_outlined),
                              onTap: () {
                                setSheetState(() => selectedPreset = preset);
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('use_anchor_preset_button'),
                        onPressed: () {
                          ref
                              .read(captureSessionProvider.notifier)
                              .setAnchorPreset(selectedPreset);
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Anchor set to ${selectedPreset.planLabel}.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Use Anchor'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconForAnchorPreset(CaptureAnchorPreset preset) {
    return switch (preset) {
      CaptureAnchorPreset.tight => Icons.center_focus_strong,
      CaptureAnchorPreset.standard => Icons.radar,
      CaptureAnchorPreset.area => Icons.crop_free,
      CaptureAnchorPreset.perimeter => Icons.explore_outlined,
    };
  }

  void _openMinimapTrail(List<CaptureMinimapDot> dots) {
    if (dots.isEmpty) {
      return;
    }

    final memoryIds = [for (final dot in dots) dot.memoryId];
    final wallRouteLabel = _wallRouteLabelFor(
      dots: dots,
      wallTitlesByMemoryId: _wallTitlesByMemoryId(ref.read(arWallsProvider)),
    );
    final trailTitle = wallRouteLabel == null
        ? 'Capture perimeter trail'
        : '$wallRouteLabel trail';

    Navigator.pushNamed(
      context,
      AppRoutes.arViewer,
      arguments: ARViewerArgs.trail(
        ARTrailSession.fromMemoryIds(
          title: trailTitle,
          memoryIds: memoryIds,
          source: ARTrailSource.camera,
        ),
      ),
    );
  }
}

class _ImportCandidateTile extends StatelessWidget {
  const _ImportCandidateTile({
    required this.candidate,
    required this.onTap,
  });

  final ImportedCaptureCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.photo_library_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(candidate.title),
      subtitle: Text(
        '${candidate.description}\n${candidate.metadataSummary}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _CaptureARObjectsOverlay extends StatelessWidget {
  const _CaptureARObjectsOverlay({
    required this.anchors,
    required this.wallTitlesByMemoryId,
  });

  final List<ARMemoryProjection> anchors;
  final Map<String, List<String>> wallTitlesByMemoryId;

  @override
  Widget build(BuildContext context) {
    if (anchors.isEmpty) {
      return const SizedBox.shrink();
    }
    final hasVisibleProjection = anchors.any(
      (anchor) => anchor.projection.isVisible,
    );
    return Stack(
      children: [
        for (var index = anchors.length - 1; index >= 0; index--)
          _CaptureProjectedObject(
            anchor: anchors[index],
            wallTitlesByMemoryId: wallTitlesByMemoryId,
            forceCenter: !hasVisibleProjection && index == 0,
          ),
      ],
    );
  }
}

class _CaptureProjectedObject extends StatelessWidget {
  const _CaptureProjectedObject({
    required this.anchor,
    required this.wallTitlesByMemoryId,
    required this.forceCenter,
  });

  final ARMemoryProjection anchor;
  final Map<String, List<String>> wallTitlesByMemoryId;
  final bool forceCenter;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: forceCenter
          ? const Alignment(0, -0.12)
          : Alignment(
              anchor.projection.alignmentX,
              anchor.projection.alignmentY,
            ),
      child: Opacity(
        opacity:
            forceCenter ? 0.96 : anchor.projection.opacity.clamp(0.64, 1.0),
        child: Transform.scale(
          scale: forceCenter ? 1.0 : anchor.projection.scale,
          child: _CaptureARObjectCard(
            anchor: anchor,
            wallTitles: wallTitlesByMemoryId[anchor.memory.id] ?? const [],
          ),
        ),
      ),
    );
  }
}

class _CaptureARObjectCard extends ConsumerWidget {
  const _CaptureARObjectCard({
    required this.anchor,
    required this.wallTitles,
  });

  final ARMemoryProjection anchor;
  final List<String> wallTitles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = anchor.memory;
    final attachment = memory.mediaAttachment;
    final resolvedMedia = ref.watch(anchorResolvedMediaProvider(memory));
    final previewBytes = resolvedMedia?.previewBytes;
    final isWall = wallTitles.isNotEmpty;
    final borderColor =
        isWall ? Colors.amberAccent.shade100 : Colors.cyanAccent.shade100;

    return Container(
      key: ValueKey('camera_ar_object_${memory.id}'),
      width: 174,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 104,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewBytes != null)
                  Image.memory(
                    previewBytes,
                    key: ValueKey('camera_ar_object_media_${memory.id}'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _CaptureARObjectPlaceholder(
                        attachment: attachment,
                        isWall: isWall,
                      );
                    },
                  )
                else
                  _CaptureARObjectPlaceholder(
                    key: ValueKey('camera_ar_object_media_${memory.id}'),
                    attachment: attachment,
                    isWall: isWall,
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _CaptureARObjectDistanceBadge(anchor: anchor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
            child: Row(
              children: [
                Icon(
                  isWall
                      ? Icons.view_column_outlined
                      : attachment == null
                          ? Icons.view_in_ar
                          : anchorMediaIconFor(attachment.type),
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isWall ? wallTitles.first : memory.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureARObjectPlaceholder extends StatelessWidget {
  const _CaptureARObjectPlaceholder({
    super.key,
    required this.attachment,
    required this.isWall,
  });

  final AnchorMediaAttachment? attachment;
  final bool isWall;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isWall
              ? const [Color(0xFF78350F), Color(0xFF111827)]
              : const [Color(0xFF075985), Color(0xFF111827)],
        ),
      ),
      child: Center(
        child: Icon(
          isWall
              ? Icons.view_column_outlined
              : attachment == null
                  ? Icons.view_in_ar
                  : anchorMediaIconFor(attachment!.type),
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class _CaptureARObjectDistanceBadge extends StatelessWidget {
  const _CaptureARObjectDistanceBadge({required this.anchor});

  final ARMemoryProjection anchor;

  @override
  Widget build(BuildContext context) {
    final projection = anchor.projection;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${projection.distanceLabel} • ${projection.directionLabel}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CaptureTelemetry extends StatelessWidget {
  const _CaptureTelemetry({
    required this.snapshot,
    required this.statusLabel,
  });

  final CaptureSensorSnapshot snapshot;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TelemetryBadge(
                    icon: Icons.radio_button_checked,
                    label: statusLabel,
                  ),
                  _TelemetryBadge(
                    icon: Icons.verified_outlined,
                    label: snapshot.qualityLabel,
                  ),
                  _TelemetryBadge(
                    icon: Icons.insights_outlined,
                    label: snapshot.placementConfidencePercentLabel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CaptureReadinessPanel(snapshot: snapshot),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TelemetryMetric(
                    icon: Icons.place_outlined,
                    label: 'Lat/Long',
                    value: snapshot.locationLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.terrain_outlined,
                    label: 'Altitude',
                    value: snapshot.altitudeLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.navigation,
                    label: 'Direction',
                    value: snapshot.compassLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.gps_fixed,
                    label: 'Accuracy',
                    value: snapshot.accuracyLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.screen_rotation_alt_outlined,
                    label: 'Pitch/Roll',
                    value: snapshot.attitudeLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.auto_graph_outlined,
                    label: 'Confidence',
                    value: snapshot.placementConfidenceLabel,
                  ),
                  _TelemetryMetric(
                    icon: Icons.sensors_outlined,
                    label: 'Source',
                    value: snapshot.captureSource,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureReadinessPanel extends StatelessWidget {
  const _CaptureReadinessPanel({required this.snapshot});

  final CaptureSensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (snapshot.captureReadinessLevel) {
      CaptureReadinessLevel.ready => Colors.greenAccent,
      CaptureReadinessLevel.steady => Colors.amberAccent,
      CaptureReadinessLevel.calibrate => Colors.orangeAccent,
    };

    return DecoratedBox(
      key: const ValueKey('capture_readiness_panel'),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _iconForReadiness(snapshot.captureReadinessLevel),
                  color: accentColor,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    snapshot.captureReadinessLabel,
                    key: const ValueKey('capture_readiness_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.captureGuidanceLabel,
              key: const ValueKey('capture_guidance_label'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SensorStatusChip(
                  key: const ValueKey('capture_gps_status_chip'),
                  icon: Icons.gps_fixed,
                  label: snapshot.gpsStabilityLabel,
                ),
                _SensorStatusChip(
                  key: const ValueKey('capture_compass_status_chip'),
                  icon: Icons.explore_outlined,
                  label: snapshot.compassStabilityLabel,
                ),
                _SensorStatusChip(
                  key: const ValueKey('capture_tilt_status_chip'),
                  icon: Icons.screen_rotation_alt_outlined,
                  label: snapshot.attitudeStabilityLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForReadiness(CaptureReadinessLevel level) {
    return switch (level) {
      CaptureReadinessLevel.ready => Icons.check_circle_outline,
      CaptureReadinessLevel.steady => Icons.motion_photos_pause_outlined,
      CaptureReadinessLevel.calibrate => Icons.warning_amber_outlined,
    };
  }
}

class _SensorStatusChip extends StatelessWidget {
  const _SensorStatusChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryBadge extends StatelessWidget {
  const _TelemetryBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryMetric extends StatelessWidget {
  const _TelemetryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 126, maxWidth: 178),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, List<String>> _wallTitlesByMemoryId(Iterable<ARWall> walls) {
  final titlesByMemoryId = <String, List<String>>{};
  for (final wall in walls) {
    for (final memoryId in wall.linkedMemoryIds) {
      titlesByMemoryId.update(
        memoryId,
        (titles) => [...titles, wall.title],
        ifAbsent: () => [wall.title],
      );
    }
  }
  return titlesByMemoryId;
}

String? _wallRouteLabelFor({
  required List<CaptureMinimapDot> dots,
  required Map<String, List<String>> wallTitlesByMemoryId,
}) {
  if (dots.length < 2) {
    return null;
  }

  final wallStopCounts = <String, int>{};
  for (final dot in dots) {
    final titles = wallTitlesByMemoryId[dot.memoryId] ?? const <String>[];
    for (final title in titles.toSet()) {
      wallStopCounts.update(title, (count) => count + 1, ifAbsent: () => 1);
    }
  }

  if (wallStopCounts.isEmpty) {
    return null;
  }

  final wallsByCoverage = wallStopCounts.entries.toList()
    ..sort((a, b) {
      final countComparison = b.value.compareTo(a.value);
      if (countComparison != 0) {
        return countComparison;
      }
      return a.key.compareTo(b.key);
    });
  final primaryWall = wallsByCoverage.first.key;
  final extraWallCount = wallsByCoverage.length - 1;
  if (extraWallCount == 0) {
    return primaryWall;
  }

  return '$primaryWall + $extraWallCount '
      'wall${extraWallCount == 1 ? '' : 's'}';
}

enum _CaptureMinimapFilter {
  all,
  privateAnchors,
  publicAnchors,
  wallLinked,
  qualityIssues,
}

extension _CaptureMinimapFilterDetails on _CaptureMinimapFilter {
  String get label {
    return switch (this) {
      _CaptureMinimapFilter.all => 'All',
      _CaptureMinimapFilter.publicAnchors => 'Public',
      _CaptureMinimapFilter.privateAnchors => 'Private',
      _CaptureMinimapFilter.wallLinked => 'Walls',
      _CaptureMinimapFilter.qualityIssues => 'Quality',
    };
  }

  bool matches(CaptureMinimapDot dot, Set<String> wallLinkedMemoryIds) {
    return switch (this) {
      _CaptureMinimapFilter.all => true,
      _CaptureMinimapFilter.publicAnchors => !dot.isPrivate,
      _CaptureMinimapFilter.privateAnchors => dot.isPrivate,
      _CaptureMinimapFilter.wallLinked =>
        wallLinkedMemoryIds.contains(dot.memoryId),
      _CaptureMinimapFilter.qualityIssues => dot.hasRecordingQualityIssue,
    };
  }

  String countLabel(int count) {
    return switch (this) {
      _CaptureMinimapFilter.all => '$count in range',
      _CaptureMinimapFilter.publicAnchors => '$count public',
      _CaptureMinimapFilter.privateAnchors => '$count private',
      _CaptureMinimapFilter.wallLinked => '$count with walls',
      _CaptureMinimapFilter.qualityIssues => '$count quality',
    };
  }
}

class _CaptureMinimap extends StatelessWidget {
  const _CaptureMinimap({
    required this.snapshot,
    required this.anchors,
    required this.wallLinkedMemoryIds,
    required this.wallTitlesByMemoryId,
    required this.isExpanded,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onToggle,
    required this.onStartTrail,
  });

  static const _radiusMeters = 100.0;

  final CaptureSensorSnapshot snapshot;
  final List<AnchorMemory> anchors;
  final Set<String> wallLinkedMemoryIds;
  final Map<String, List<String>> wallTitlesByMemoryId;
  final bool isExpanded;
  final _CaptureMinimapFilter selectedFilter;
  final ValueChanged<_CaptureMinimapFilter> onFilterChanged;
  final VoidCallback onToggle;
  final ValueChanged<List<CaptureMinimapDot>> onStartTrail;

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      return _RoundCameraButton(
        tooltip: 'Show minimap',
        icon: Icons.radar,
        onPressed: onToggle,
      );
    }

    const minimapService = CaptureMinimapService();
    final allDots = minimapService.dotsFor(
      snapshot: snapshot,
      anchors: anchors,
      radiusMeters: _radiusMeters,
    );
    final dots = [
      for (final dot in allDots)
        if (selectedFilter.matches(dot, wallLinkedMemoryIds)) dot,
    ];
    final filterCounts = {
      for (final filter in _CaptureMinimapFilter.values)
        filter: allDots
            .where((dot) => filter.matches(dot, wallLinkedMemoryIds))
            .length,
    };
    final trailSummary = minimapService.trailSummaryFor(
      dots,
      wallLinkedMemoryIds: wallLinkedMemoryIds,
    );
    final wallRouteLabel = _wallRouteLabelFor(
      dots: dots,
      wallTitlesByMemoryId: wallTitlesByMemoryId,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: SizedBox(
        width: 168,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Nearby media',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimize minimap',
                    onPressed: onToggle,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    iconSize: 16,
                    color: Colors.white,
                    icon: const Icon(Icons.close_fullscreen),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  const Text(
                    '100 m radius',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  Text(
                    selectedFilter.countLabel(dots.length),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _MinimapFilterChips(
                selectedFilter: selectedFilter,
                counts: filterCounts,
                onSelected: onFilterChanged,
              ),
              const SizedBox(height: 8),
              SizedBox.square(
                dimension: 104,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MinimapPainter(
                          dots: dots,
                          wallLinkedMemoryIds: wallLinkedMemoryIds,
                          headingDegrees: snapshot.headingDegrees,
                          colorScheme: colorScheme,
                          radiusMeters: _radiusMeters,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _MinimapDotHitTargets(
                        dots: dots,
                        radiusMeters: _radiusMeters,
                        onTap: (dot) => _showDotPreview(context, dot),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailSummary != null) ...[
                const SizedBox(height: 8),
                _MinimapTrailSummaryPanel(
                  summary: trailSummary,
                  wallRouteLabel: wallRouteLabel,
                ),
              ],
              if (dots.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Nearest ${dots.first.title} - '
                  '${dots.first.distanceLabel} ${dots.first.directionLabel}',
                  key: const ValueKey('minimap_nearest_dot_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  'No dots match this filter',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 10,
                  ),
                ),
              ],
              if (dots.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('minimap_start_ar_trail_button'),
                    onPressed: () => _showTrailPreview(
                      context,
                      dots: dots,
                      summary: trailSummary,
                      wallRouteLabel: wallRouteLabel,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.route_outlined, size: 16),
                    label: Text(
                      '${trailSummary?.stopCount ?? dots.length} stop AR trail',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _MinimapLegend(color: Colors.white, label: 'You'),
                  _MinimapLegend(color: Colors.lightBlueAccent, label: 'Media'),
                  _MinimapLegend(
                    color: Colors.deepOrangeAccent,
                    label: 'Quality',
                  ),
                  _MinimapLegend(color: Colors.amberAccent, label: 'Private'),
                  _MinimapLegend(color: Colors.cyanAccent, label: 'Wall'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrailPreview(
    BuildContext context, {
    required List<CaptureMinimapDot> dots,
    required CaptureMinimapTrailSummary? summary,
    required String? wallRouteLabel,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final route = summary?.route ??
            const ARTrailRouteService().routeFor(
              points: _trailRoutePointsForDots(dots),
            );

        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.route_outlined,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Preview AR trail',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          if (wallRouteLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              wallRouteLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                avatar: const Icon(
                                  Icons.flag_outlined,
                                  size: 18,
                                ),
                                label: Text('${dots.length} stops'),
                              ),
                              if (summary != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.directions_walk,
                                    size: 18,
                                  ),
                                  label: Text(summary.routeEffortLabel),
                                ),
                              if (summary != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.explore_outlined,
                                    size: 18,
                                  ),
                                  label: Text(summary.routeContextLabel),
                                ),
                              if (summary != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.privacy_tip_outlined,
                                    size: 18,
                                  ),
                                  label: Text(summary.advisoryLabel),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          for (var index = 0; index < dots.length; index++) ...[
                            _TrailPreviewStopTile(
                              stopNumber: index + 1,
                              dot: dots[index],
                              wallTitles:
                                  wallTitlesByMemoryId[dots[index].memoryId] ??
                                      const <String>[],
                            ),
                            if (index < dots.length - 1) ...[
                              _TrailPreviewLegTile(
                                leg: route.legs[index],
                              ),
                              const Divider(height: 1),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('minimap_confirm_ar_trail_button'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onStartTrail(dots);
                      },
                      icon: const Icon(Icons.view_in_ar),
                      label: const Text('Start AR trail'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDotPreview(BuildContext context, CaptureMinimapDot dot) {
    final wallTitles = wallTitlesByMemoryId[dot.memoryId] ?? const <String>[];
    final turnLabel = dot.turnLabelFrom(snapshot.headingDegrees);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      dot.hasRecordingQualityIssue
                          ? Icons.warning_amber_rounded
                          : dot.needsCalibrationReview
                              ? Icons.warning_amber
                              : dot.isPrivate
                                  ? Icons.lock_outline
                                  : Icons.photo_outlined,
                      color: dot.hasRecordingQualityIssue ||
                              dot.needsCalibrationReview
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dot.title,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  dot.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.near_me_outlined, size: 18),
                      label: Text(dot.distanceLabel),
                    ),
                    Chip(
                      avatar: const Icon(Icons.explore_outlined, size: 18),
                      label: Text(dot.bearingLabel),
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.screen_rotation_alt_outlined,
                        size: 18,
                      ),
                      label: Text(turnLabel),
                    ),
                    Chip(
                      avatar: Icon(
                        dot.isPrivate ? Icons.lock_outline : Icons.public,
                        size: 18,
                      ),
                      label: Text(dot.isPrivate ? 'Private' : 'Public'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.gps_fixed, size: 18),
                      label: Text(dot.anchorHealthLabel),
                    ),
                    if (dot.mediaTypeLabel != null)
                      Chip(
                        avatar: const Icon(Icons.perm_media_outlined, size: 18),
                        label: Text(dot.mediaTypeLabel!),
                      ),
                    if (dot.recordingQualitySummaryLabel != null)
                      Chip(
                        avatar: const Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                        ),
                        label: Text(dot.recordingQualitySummaryLabel!),
                      ),
                    Chip(
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
                      label: Text(dot.locationLabel),
                    ),
                    for (final wallTitle in wallTitles)
                      Chip(
                        avatar: const Icon(Icons.grid_view, size: 18),
                        label: Text(wallTitle),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.pushNamed(
                            context,
                            AppRoutes.memoryDetails,
                            arguments: dot.memoryId,
                          );
                        },
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Open details'),
                      ),
                    ),
                    if (dot.hasArExperience) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            Navigator.pushNamed(
                              context,
                              AppRoutes.arViewer,
                              arguments: dot.memoryId,
                            );
                          },
                          icon: const Icon(Icons.view_in_ar),
                          label: const Text('View AR'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

List<ARTrailRoutePoint> _trailRoutePointsForDots(
  List<CaptureMinimapDot> dots,
) {
  return [
    for (final dot in dots)
      ARTrailRoutePoint(
        memoryId: dot.memoryId,
        title: dot.title,
        latitude: dot.latitude,
        longitude: dot.longitude,
        distanceFromOriginMeters: dot.distanceMeters,
        bearingFromOriginDegrees: dot.bearingDegrees,
        isPrivate: dot.isPrivate,
        needsCalibrationReview: dot.needsCalibrationReview,
      ),
  ];
}

class _TrailPreviewStopTile extends StatelessWidget {
  const _TrailPreviewStopTile({
    required this.stopNumber,
    required this.dot,
    required this.wallTitles,
  });

  final int stopNumber;
  final CaptureMinimapDot dot;
  final List<String> wallTitles;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusLabel = dot.hasRecordingQualityIssue
        ? 'Quality issue'
        : dot.needsCalibrationReview
            ? 'Review placement'
            : dot.isPrivate
                ? 'Private stop'
                : 'Public stop';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text('$stopNumber'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stop $stopNumber ${dot.title}',
                  key: ValueKey('trail_preview_stop_${dot.memoryId}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dot.distanceLabel} ${dot.directionLabel} - '
                  '${dot.anchorHealthLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      avatar: Icon(
                        dot.hasRecordingQualityIssue
                            ? Icons.warning_amber_rounded
                            : dot.isPrivate
                                ? Icons.lock_outline
                                : Icons.public,
                        size: 16,
                      ),
                      label: Text(statusLabel),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (dot.recordingQualitySummaryLabel != null)
                      Chip(
                        avatar: const Icon(
                          Icons.speed,
                          size: 16,
                        ),
                        label: Text(dot.recordingQualitySummaryLabel!),
                        visualDensity: VisualDensity.compact,
                      ),
                    for (final wallTitle in wallTitles)
                      Chip(
                        avatar: const Icon(Icons.grid_view, size: 16),
                        label: Text(wallTitle),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrailPreviewLegTile extends StatelessWidget {
  const _TrailPreviewLegTile({
    required this.leg,
  });

  final ARTrailRouteLeg leg;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 40, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(
            Icons.turn_slight_right,
            color: colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              leg.nextStopLabel,
              key: ValueKey(
                'trail_preview_leg_'
                '${leg.from.memoryId}_${leg.to.memoryId}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimapFilterChips extends StatelessWidget {
  const _MinimapFilterChips({
    required this.selectedFilter,
    required this.counts,
    required this.onSelected,
  });

  final _CaptureMinimapFilter selectedFilter;
  final Map<_CaptureMinimapFilter, int> counts;
  final ValueChanged<_CaptureMinimapFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('minimap_filter_chips'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _CaptureMinimapFilter.values) ...[
            _MinimapFilterPill(
              filter: filter,
              count: counts[filter] ?? 0,
              selected: selectedFilter == filter,
              onSelected: () => onSelected(filter),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _MinimapFilterPill extends StatelessWidget {
  const _MinimapFilterPill({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final _CaptureMinimapFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected ? Colors.black : Colors.white;
    final backgroundColor =
        selected ? Colors.white : Colors.white.withValues(alpha: 0.1);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Show ${filter.label} minimap items, $count available',
      child: GestureDetector(
        key: ValueKey('minimap_filter_${filter.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onSelected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Text(
              '${filter.label} $count',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimapTrailSummaryPanel extends StatelessWidget {
  const _MinimapTrailSummaryPanel({
    required this.summary,
    required this.wallRouteLabel,
  });

  final CaptureMinimapTrailSummary summary;
  final String? wallRouteLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (wallRouteLabel != null)
                    Text(
                      wallRouteLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  Text(
                    summary.startLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${summary.farthestLabel} - ${summary.advisoryLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    summary.routeContextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimapDotHitTargets extends StatelessWidget {
  const _MinimapDotHitTargets({
    required this.dots,
    required this.radiusMeters,
    required this.onTap,
  });

  final List<CaptureMinimapDot> dots;
  final double radiusMeters;
  final ValueChanged<CaptureMinimapDot> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            for (final dot in dots.reversed)
              _MinimapDotHitTarget(
                dot: dot,
                point: _minimapOffsetFor(
                  size: size,
                  radiusFraction: dot.radiusFractionFor(radiusMeters),
                  bearingDegrees: dot.bearingDegrees,
                ),
                onTap: () => onTap(dot),
              ),
          ],
        );
      },
    );
  }
}

class _MinimapDotHitTarget extends StatelessWidget {
  const _MinimapDotHitTarget({
    required this.dot,
    required this.point,
    required this.onTap,
  });

  final CaptureMinimapDot dot;
  final Offset point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: point.dx - 14,
      top: point.dy - 14,
      child: Semantics(
        button: true,
        label: 'Preview ${dot.title}',
        child: Listener(
          key: ValueKey('minimap_dot_${dot.memoryId}'),
          behavior: HitTestBehavior.opaque,
          onPointerUp: (_) => onTap(),
          child: const SizedBox.square(dimension: 28),
        ),
      ),
    );
  }
}

class _MinimapLegend extends StatelessWidget {
  const _MinimapLegend({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 6),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 9),
        ),
      ],
    );
  }
}

class _MinimapPainter extends CustomPainter {
  const _MinimapPainter({
    required this.dots,
    required this.wallLinkedMemoryIds,
    required this.headingDegrees,
    required this.colorScheme,
    required this.radiusMeters,
  });

  final List<CaptureMinimapDot> dots;
  final Set<String> wallLinkedMemoryIds;
  final double headingDegrees;
  final ColorScheme colorScheme;
  final double radiusMeters;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final headingPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.86)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final centerPaint = Paint()..color = Colors.white;

    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.5, ringPaint);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ringPaint,
    );

    if (dots.length > 1) {
      final routePath = Path();
      for (var index = 0; index < dots.length; index++) {
        final dot = dots[index];
        final point = _minimapOffsetFor(
          size: size,
          radiusFraction: dot.radiusFractionFor(radiusMeters),
          bearingDegrees: dot.bearingDegrees,
        );
        if (index == 0) {
          routePath.moveTo(point.dx, point.dy);
        } else {
          routePath.lineTo(point.dx, point.dy);
        }
      }

      final routeShadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final routePaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(routePath, routeShadowPaint);
      canvas.drawPath(routePath, routePaint);
    }

    if (headingDegrees.isFinite) {
      final headingOffset = _offsetFor(
        center: center,
        radius: radius * 0.76,
        bearingDegrees: headingDegrees,
      );
      canvas.drawLine(center, headingOffset, headingPaint);
    }
    canvas.drawCircle(center, 5, centerPaint);

    for (final dot in dots) {
      final point = _minimapOffsetFor(
        size: size,
        radiusFraction: dot.radiusFractionFor(radiusMeters),
        bearingDegrees: dot.bearingDegrees,
      );
      final fillPaint = Paint()
        ..color = dot.hasRecordingQualityIssue
            ? Colors.deepOrangeAccent
            : dot.needsCalibrationReview
                ? colorScheme.error
                : dot.isPrivate
                    ? Colors.amberAccent
                    : Colors.lightBlueAccent;
      final strokePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final wallLinkedPaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      if (wallLinkedMemoryIds.contains(dot.memoryId)) {
        canvas.drawCircle(point, 8, wallLinkedPaint);
      }
      if (dot.hasRecordingQualityIssue) {
        final qualityRingPaint = Paint()
          ..color = Colors.deepOrangeAccent.withValues(alpha: 0.82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(point, 8.5, qualityRingPaint);
      }
      canvas.drawCircle(point, 5, fillPaint);
      canvas.drawCircle(point, 5, strokePaint);
    }
  }

  Offset _offsetFor({
    required Offset center,
    required double radius,
    required double bearingDegrees,
  }) {
    final radians = bearingDegrees * math.pi / 180;
    return center +
        Offset(math.sin(radians) * radius, -math.cos(radians) * radius);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.dots != dots ||
        oldDelegate.wallLinkedMemoryIds != wallLinkedMemoryIds ||
        oldDelegate.headingDegrees != headingDegrees ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.radiusMeters != radiusMeters;
  }
}

Offset _minimapOffsetFor({
  required Size size,
  required double radiusFraction,
  required double bearingDegrees,
}) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = (math.min(size.width, size.height) / 2 - 8) * radiusFraction;
  final radians = bearingDegrees * math.pi / 180;
  return center +
      Offset(math.sin(radians) * radius, -math.cos(radians) * radius);
}

class _RoundCameraButton extends StatelessWidget {
  const _RoundCameraButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _CameraModeButton extends StatelessWidget {
  const _CameraModeButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _CameraGrid extends StatelessWidget {
  const _CameraGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CameraGridPainter());
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    for (final dx in [size.width / 3, size.width * 2 / 3]) {
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }
    for (final dy in [size.height / 3, size.height * 2 / 3]) {
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LevelIndicator extends StatelessWidget {
  const _LevelIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white30),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.horizontal_rule, color: Colors.greenAccent),
          SizedBox(width: 8),
          Text('Level', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
