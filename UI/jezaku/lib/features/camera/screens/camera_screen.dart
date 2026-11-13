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

part 'camera_parts/camera_capture_overlays.dart';
part 'camera_parts/camera_controls.dart';
part 'camera_parts/camera_minimap.dart';
part 'camera_parts/camera_minimap_widgets.dart';
part 'camera_parts/camera_telemetry.dart';

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
