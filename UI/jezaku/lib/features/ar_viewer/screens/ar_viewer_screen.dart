import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';
import 'package:jejaku/features/ar_viewer/services/ar_model_asset_cache_provider.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_hosting_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_maintenance_policy.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_retry_policy.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_runtime_permission_service.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capture_provider.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jejaku/features/ar_viewer/states/ar_scene_diagnostics_provider.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:jejaku/features/home/models/anchor_journey_step.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';
import 'package:jejaku/features/home/services/anchor_spatial_journey_service.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/states/ar_trail_session_providers.dart';
import 'package:jejaku/features/trails/widgets/ar_trail_snackbars.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

enum _TrailLaunchConflictChoice {
  resumeCurrent,
  replace,
  cancel,
}

enum _ARHudPreset {
  defaultView,
  minimal,
  manual,
}

class ARViewerScreen extends ConsumerStatefulWidget {
  const ARViewerScreen({
    super.key,
    this.focusedMemoryId,
    this.journeyMemoryIds = const [],
    this.journeyTitle,
    this.sourceWallId,
    this.trailSession,
    this.resumeExistingProgress = false,
  });

  final String? focusedMemoryId;
  final List<String> journeyMemoryIds;
  final String? journeyTitle;
  final String? sourceWallId;
  final ARTrailSession? trailSession;
  final bool resumeExistingProgress;

  @override
  ConsumerState<ARViewerScreen> createState() => _ARViewerScreenState();
}

class _ARViewerScreenState extends ConsumerState<ARViewerScreen> {
  static const _viewerOrigin = JejakuGeoOrigin(
    latitude: -6.91755,
    longitude: 107.61905,
    altitudeMeters: 714,
  );
  static const _screenRecordingConfig = ARRecordingConfig(
    fps: 30,
    videoBitrateKbps: 6000,
    includeAudio: false,
    includeUIOverlay: true,
    outputFormat: 'mp4',
  );
  static const _nativeSessionHealthPolicy =
      ARSessionHealthPolicy.placementReadiness;
  static const _screenRecordingMaxPixelRatio = 1.5;
  static int _diagnosticsSessionSerial = 0;

  bool _showAnchors = true;
  bool _showRadar = true;
  bool _showInfoDashboard = true;
  bool _showRecordingPanel = false;
  bool _isRadarExpanded = true;
  double _headingDegrees = 56;
  bool _didApplyInitialFocus = false;
  bool _isResolvingTrailLaunch = false;
  _ARHudPreset _hudPreset = _ARHudPreset.defaultView;
  late String? _focusedMemoryId;
  late ARTrailSession? _trailSession;
  final ARMemoryCloudAnchorHostingService _cloudAnchorHostingService =
      const ARMemoryCloudAnchorHostingService();
  final ARMemoryCloudAnchorMaintenancePolicy _cloudAnchorMaintenancePolicy =
      const ARMemoryCloudAnchorMaintenancePolicy();
  final ARMemoryCloudAnchorRetryPolicy _cloudAnchorRetryPolicy =
      const ARMemoryCloudAnchorRetryPolicy();
  final ARMemorySceneSyncService _nativeSceneSyncService =
      const ARMemorySceneSyncService();
  final ARRuntimePermissionService _arPermissionService =
      const ARRuntimePermissionService();
  late final String _diagnosticsSessionId = _createDiagnosticsSessionId();
  late final DateTime _diagnosticsSessionStartedAt = DateTime.now().toUtc();
  late final ARMemorySceneDiagnosticsController _diagnosticsController;
  late Future<ARRuntimePermissions> _arPermissionsFuture;
  bool _didAutoRequestARPermissions = false;
  JejakuMemoryARScene? _nativeMemoryScene;
  JejakuMemoryCloudAnchorManager? _nativeCloudAnchorManager;
  List<AnchorMemory> _latestNativeSceneMemories = const <AnchorMemory>[];
  List<ARMemoryProjection> _latestNativeSceneProjections =
      const <ARMemoryProjection>[];
  final Map<String, ARMemorySessionPlacement> _nativeSessionPlacementCache =
      <String, ARMemorySessionPlacement>{};
  String? _nativeSceneFingerprint;
  bool _nativeSceneSyncScheduled = false;
  bool _nativeSceneSyncing = false;
  bool _nativeSceneRefreshQueued = false;
  bool _nativeSceneDiagnosticsResetScheduled = false;
  bool _nativeCloudAnchorsEnabled = false;
  final bool _resolvedSessionCloudAnchorsEnabled = false;
  bool _nativeMemoryPlacementAllowed = false;
  bool _isRefreshingViewerPose = false;
  JejakuGeoOrigin _latestNativeSceneOrigin = _viewerOrigin;
  Set<String> _unsupportedNativeSessionFeatureKeys = const <String>{};
  ARSessionReadiness? _latestSessionReadiness;
  final Set<String> _cloudAnchorHostInFlightMemoryIds = <String>{};
  final GlobalKey _arVisualOverlayRecordingBoundaryKey = GlobalKey(
    debugLabel: 'ar_visual_overlay_recording_boundary',
  );
  late final ARViewerCaptureController _captureController;
  ARController? _arController;
  DateTime? _cloudAnchorMaintenanceCheckAt;
  Timer? _cloudAnchorMaintenanceTimer;
  Timer? _viewerPoseRefreshTimer;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ARCamera>? _arCameraSubscription;
  ARCamera? _latestARCamera;
  DateTime? _lastARCameraFrameAt;
  DateTime? _lastARHeadingUpdateAt;
  ARMemoryCloudAnchorRetryState _cloudAnchorRetryState =
      const ARMemoryCloudAnchorRetryState();
  Timer? _cloudAnchorRetryTimer;

  static String _createDiagnosticsSessionId() {
    final serial = _diagnosticsSessionSerial++;
    return 'ar_viewer_${DateTime.now().microsecondsSinceEpoch}_$serial';
  }

  @override
  void initState() {
    super.initState();
    _diagnosticsController =
        ref.read(arMemorySceneDiagnosticsProvider.notifier);
    _captureController = ref.read(arViewerCaptureProvider.notifier);
    _arPermissionsFuture = _checkARRuntimePermissions();
    final initialHeading =
        ref.read(captureSessionProvider).previewSnapshot.headingDegrees;
    if (initialHeading.isFinite) {
      _headingDegrees = _normalizeHeading(initialHeading);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _autoRequestARRuntimePermissions();
      if (ref.read(arViewerLivePoseTrackingProvider)) {
        _startViewerPoseTracking();
      }
      _diagnosticsController.startSession(
        _diagnosticsSessionId,
        startedAt: _diagnosticsSessionStartedAt,
      );
    });
    _trailSession = widget.trailSession ?? _legacyTrailSession();
    _focusedMemoryId = widget.focusedMemoryId ??
        _trailSession?.initialMemoryId ??
        (_journeyMemoryIds.isEmpty ? null : _journeyMemoryIds.first);
    final trailSession = _trailSession;
    if (trailSession != null && trailSession.canStart) {
      _isResolvingTrailLaunch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_resolveInitialTrailLaunch(trailSession));
      });
    }
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

  void _showHudSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateHud(VoidCallback update) {
              setState(update);
              setSheetState(() {});
            }

            void applyPreset(_ARHudPreset preset) {
              updateHud(() {
                _hudPreset = preset;
                switch (preset) {
                  case _ARHudPreset.defaultView:
                    _showAnchors = true;
                    _showRadar = true;
                    _showInfoDashboard = true;
                    _showRecordingPanel = false;
                    _isRadarExpanded = true;
                  case _ARHudPreset.minimal:
                    _showAnchors = true;
                    _showRadar = false;
                    _showInfoDashboard = false;
                    _showRecordingPanel = false;
                  case _ARHudPreset.manual:
                    break;
                }
              });
            }

            void setManual(VoidCallback update) {
              updateHud(() {
                _hudPreset = _ARHudPreset.manual;
                update();
              });
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'AR HUD settings',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<_ARHudPreset>(
                      key: const ValueKey('ar_hud_preset_segments'),
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _ARHudPreset.defaultView,
                          label: Text('Default'),
                        ),
                        ButtonSegment(
                          value: _ARHudPreset.minimal,
                          label: Text('Minimal'),
                        ),
                        ButtonSegment(
                          value: _ARHudPreset.manual,
                          label: Text('Manual'),
                        ),
                      ],
                      selected: {_hudPreset},
                      onSelectionChanged: (selection) {
                        applyPreset(selection.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: const ValueKey('ar_hud_anchor_switch'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.view_in_ar),
                      title: const Text('Anchor overlays'),
                      value: _showAnchors,
                      onChanged: (value) => setManual(() {
                        _showAnchors = value;
                      }),
                    ),
                    SwitchListTile(
                      key: const ValueKey('ar_hud_radar_switch'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.radar),
                      title: const Text('Radar'),
                      value: _showRadar,
                      onChanged: (value) => setManual(() {
                        _showRadar = value;
                        if (value) {
                          _isRadarExpanded = true;
                        }
                      }),
                    ),
                    SwitchListTile(
                      key: const ValueKey('ar_hud_dashboard_switch'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.space_dashboard_outlined),
                      title: const Text('Info dashboard'),
                      value: _showInfoDashboard,
                      onChanged: (value) => setManual(() {
                        _showInfoDashboard = value;
                      }),
                    ),
                    SwitchListTile(
                      key: const ValueKey('ar_hud_recording_switch'),
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.video_settings_outlined),
                      title: const Text('Recording panel'),
                      subtitle: const Text('Hidden by default'),
                      value: _showRecordingPanel,
                      onChanged: (value) => setManual(() {
                        _showRecordingPanel = value;
                      }),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const ValueKey('ar_hud_settings_done_button'),
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Done'),
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

  void _startViewerPoseTracking() {
    _viewerPoseRefreshTimer?.cancel();
    _viewerPoseRefreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refreshViewerPoseFromDeviceSensors()),
    );
    unawaited(_refreshViewerPoseFromDeviceSensors());
    _startCompassTracking();
    unawaited(_startPositionTracking());
  }

  void _startCompassTracking() {
    _compassSubscription?.cancel();
    final events = FlutterCompass.events;
    if (events == null) {
      return;
    }
    _compassSubscription = events.listen(
      (event) {
        final heading = event.headingForCameraMode ?? event.heading;
        if (heading == null || !heading.isFinite) {
          return;
        }
        _applyLiveHeading(_normalizeHeading(heading));
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _startPositionTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(milliseconds: 700), onTimeout: () => false);
      if (!mounted || !serviceEnabled) {
        return;
      }
      var permission = await Geolocator.checkPermission()
          .timeout(const Duration(milliseconds: 700));
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 2));
      }
      if (!mounted ||
          permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1,
        ),
      ).listen(
        _applyLivePosition,
        onError: (_) {},
        cancelOnError: false,
      );
    } on Object {
      // The periodic sensor refresh remains as a slower fallback.
    }
  }

  void _applyLiveHeading(double headingDegrees) {
    final lastARFrameAt = _lastARCameraFrameAt;
    if (lastARFrameAt != null &&
        DateTime.now().toUtc().difference(lastARFrameAt) <
            const Duration(milliseconds: 900)) {
      return;
    }
    if (!mounted ||
        _headingDeltaDegrees(_headingDegrees, headingDegrees).abs() < 0.5) {
      return;
    }
    ref.read(captureSessionProvider.notifier).updatePreviewPose(
          headingDegrees: headingDegrees,
          captureSource: 'Live AR compass/location',
        );
    setState(() => _headingDegrees = headingDegrees);
  }

  void _applyLivePosition(Position position) {
    if (!mounted) {
      return;
    }
    final beforeOrigin = _viewerOriginFor(
      ref.read(captureSessionProvider).previewSnapshot,
    );
    ref.read(captureSessionProvider.notifier).updatePreviewPose(
          latitude: position.latitude,
          longitude: position.longitude,
          altitudeMeters: position.altitude.isFinite
              ? position.altitude
              : beforeOrigin.altitudeMeters,
          gpsAccuracyMeters:
              position.accuracy.isFinite ? position.accuracy : null,
          captureSource: 'Live AR compass/location',
        );
    final afterOrigin = _viewerOriginFor(
      ref.read(captureSessionProvider).previewSnapshot,
    );
    if (!_sameGeoOrigin(beforeOrigin, afterOrigin)) {
      setState(() => _nativeSceneFingerprint = null);
      _scheduleNativeSceneSync();
    }
  }

  Future<void> _refreshViewerPoseFromDeviceSensors() async {
    if (_isRefreshingViewerPose || !mounted) {
      return;
    }
    _isRefreshingViewerPose = true;
    final beforeOrigin = _viewerOriginFor(
      ref.read(captureSessionProvider).previewSnapshot,
    );
    try {
      final snapshot = await ref
          .read(captureSessionProvider.notifier)
          .refreshPreviewFromDeviceSensors();
      if (!mounted) {
        return;
      }
      final afterOrigin = _viewerOriginFor(snapshot);
      final hasDeviceHeading =
          _usesDeviceOrientation(snapshot) && snapshot.headingDegrees.isFinite;
      final normalizedHeading = hasDeviceHeading
          ? _normalizeHeading(snapshot.headingDegrees)
          : _headingDegrees;
      final shouldUpdateHeading = hasDeviceHeading &&
          _headingDeltaDegrees(_headingDegrees, normalizedHeading).abs() > 0.5;
      final shouldRefreshNativeScene = !_sameGeoOrigin(
        beforeOrigin,
        afterOrigin,
      );
      if (shouldUpdateHeading || shouldRefreshNativeScene) {
        setState(() {
          if (shouldUpdateHeading) {
            _headingDegrees = normalizedHeading;
          }
          if (shouldRefreshNativeScene) {
            _nativeSceneFingerprint = null;
          }
        });
        if (shouldRefreshNativeScene) {
          _scheduleNativeSceneSync();
        }
      }
    } finally {
      _isRefreshingViewerPose = false;
    }
  }

  JejakuGeoOrigin _viewerOriginFor(CaptureSensorSnapshot snapshot) {
    if (!_usesDeviceLocation(snapshot)) {
      return _viewerOrigin;
    }
    return JejakuGeoOrigin(
      latitude: snapshot.latitude,
      longitude: snapshot.longitude,
      altitudeMeters: snapshot.altitudeMeters,
    );
  }

  bool _usesDeviceLocation(CaptureSensorSnapshot snapshot) {
    return snapshot.latitude.isFinite &&
        snapshot.longitude.isFinite &&
        snapshot.altitudeMeters.isFinite &&
        snapshot.latitude.abs() <= 90 &&
        snapshot.longitude.abs() <= 180;
  }

  bool _usesDeviceOrientation(CaptureSensorSnapshot snapshot) {
    return snapshot.headingDegrees.isFinite;
  }

  Future<void> _resolveInitialTrailLaunch(ARTrailSession trailSession) async {
    if (!mounted || !trailSession.canStart) {
      return;
    }

    final controller = ref.read(activeARTrailProgressProvider.notifier);
    if (widget.resumeExistingProgress) {
      controller.resume(
        trailSession,
        currentMemoryId: _focusedMemoryId,
      );
      _isResolvingTrailLaunch = false;
      return;
    }

    final activeProgress = ref.read(activeARTrailProgressProvider);
    if (activeProgress == null || activeProgress.isFinished) {
      controller.start(
        trailSession,
        currentMemoryId: _focusedMemoryId,
      );
      _isResolvingTrailLaunch = false;
      return;
    }

    if (activeProgress.session.hasSameRouteAs(trailSession)) {
      _resumeProgressInViewer(activeProgress);
      controller.resume(
        activeProgress.session,
        currentMemoryId: activeProgress.currentMemoryId,
      );
      return;
    }

    final choice = await _showTrailLaunchConflictDialog(
      activeProgress: activeProgress,
      requestedTrail: trailSession,
    );
    if (!mounted) {
      return;
    }

    switch (choice) {
      case _TrailLaunchConflictChoice.resumeCurrent:
        _resumeProgressInViewer(activeProgress);
        return;
      case _TrailLaunchConflictChoice.replace:
        controller.start(
          trailSession,
          currentMemoryId: _focusedMemoryId,
        );
        _isResolvingTrailLaunch = false;
        return;
      case _TrailLaunchConflictChoice.cancel:
      case null:
        _isResolvingTrailLaunch = false;
        await Navigator.of(context).maybePop();
        return;
    }
  }

  Future<_TrailLaunchConflictChoice?> _showTrailLaunchConflictDialog({
    required ARTrailProgress activeProgress,
    required ARTrailSession requestedTrail,
  }) {
    return showDialog<_TrailLaunchConflictChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          key: const ValueKey('ar_trail_conflict_dialog'),
          title: const Text('Active trail in progress'),
          content: Text(
            'You are already on "${activeProgress.session.title}" at '
            '${activeProgress.currentStopLabel} '
            '(${activeProgress.progressLabel}). Start '
            '"${requestedTrail.title}" instead?',
          ),
          actions: [
            TextButton(
              key: const ValueKey('ar_trail_conflict_cancel_button'),
              onPressed: () => Navigator.of(context).pop(
                _TrailLaunchConflictChoice.cancel,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('ar_trail_conflict_replace_button'),
              onPressed: () => Navigator.of(context).pop(
                _TrailLaunchConflictChoice.replace,
              ),
              child: const Text('Replace'),
            ),
            FilledButton(
              key: const ValueKey('ar_trail_conflict_resume_button'),
              onPressed: () => Navigator.of(context).pop(
                _TrailLaunchConflictChoice.resumeCurrent,
              ),
              child: const Text('Resume current'),
            ),
          ],
        );
      },
    );
  }

  void _resumeProgressInViewer(ARTrailProgress progress) {
    if (!mounted) {
      return;
    }
    setState(() {
      _trailSession = progress.session;
      _focusedMemoryId = progress.currentMemoryId;
      _didApplyInitialFocus = false;
      _isResolvingTrailLaunch = false;
    });
  }

  @override
  void dispose() {
    _arController = null;
    _nativeMemoryScene = null;
    _nativeCloudAnchorManager = null;
    _latestARCamera = null;
    _lastARHeadingUpdateAt = null;
    _nativeSessionPlacementCache.clear();
    _scheduleCaptureDetach();
    _nativeSceneRefreshQueued = false;
    _nativeSceneDiagnosticsResetScheduled = false;
    _cancelCloudAnchorMaintenance();
    _cancelCloudAnchorRetry();
    _viewerPoseRefreshTimer?.cancel();
    _viewerPoseRefreshTimer = null;
    unawaited(_compassSubscription?.cancel());
    _compassSubscription = null;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    unawaited(_arCameraSubscription?.cancel());
    _arCameraSubscription = null;
    _cloudAnchorHostInFlightMemoryIds.clear();
    final diagnosticsController = _diagnosticsController;
    final diagnosticsSessionId = _diagnosticsSessionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        diagnosticsController.endSession(diagnosticsSessionId);
      } catch (_) {
        // The provider may already be gone when the whole scope is disposed.
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchors = ref.watch(nearbyAnchorsProvider);
    final captureSession = ref.watch(captureSessionProvider);
    final viewerOrigin = _viewerOriginFor(captureSession.previewSnapshot);
    final arCapabilities = ref.watch(arViewerCapabilitiesProvider);
    final arSessionPlan = ref.watch(arViewerSessionPlanProvider);
    final sceneDiagnostics = _sceneDiagnosticsForSession(
      ref.watch(arMemorySceneDiagnosticsProvider),
    );
    final arCapture = ref.watch(arViewerCaptureProvider);
    final trailProgress = ref.watch(activeARTrailProgressProvider);
    final viewerPose = JejakuViewerPose(
      origin: viewerOrigin,
      headingDegrees: _headingDegrees,
      pitchDegrees: -2,
      horizontalFovDegrees: 118,
      verticalFovDegrees: 52,
      maxDistanceMeters: 260,
    );
    final projectedAnchors = projectAnchorMemories(
      memories: anchors,
      viewerPose: viewerPose,
      onlyInRange: false,
    );
    final trailStopNumbers = _trailStopNumbers();
    final activeProjectedAnchors = _activeProjectedAnchors(
      projectedAnchors,
      trailStopNumbers,
    );
    final focusedAnchor = _focusedAnchor(activeProjectedAnchors);
    final linkedWalls = focusedAnchor == null
        ? const <ARWall>[]
        : ref.watch(memoryLinkedWallsProvider(focusedAnchor.memory.id));
    final journeySteps = _journeyMemoryIds.isEmpty
        ? ref.watch(spatialJourneyProvider)
        : _customJourneySteps(anchors, viewerOrigin);
    final journeyStep = focusedAnchor == null
        ? null
        : _journeyStepFor(journeySteps, focusedAnchor.memory.id);
    final walls = ref.watch(arWallsProvider);
    final wallTitlesByMemoryId = _wallTitlesByMemoryId(walls);
    final routeWalls = _routeWalls(walls);
    final sourceWall = _sourceWall(walls, routeWalls: routeWalls);
    final extraWalls = sourceWall == null
        ? const <ARWall>[]
        : [
            for (final wall in routeWalls)
              if (wall.id != sourceWall.id) wall,
          ];
    _maybeApplyInitialFocus(focusedAnchor);
    _maybeScheduleNativeSceneSync(
      activeProjectedAnchors,
      arCapabilities,
      viewerOrigin: viewerOrigin,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildCameraBackdrop(),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                key: _arVisualOverlayRecordingBoundaryKey,
                child: Stack(
                  children: [
                    if (_showAnchors)
                      ..._buildAnchorOverlays(
                        activeProjectedAnchors,
                        focusedMemoryId: _focusedMemoryId,
                        trailStopNumbers: trailStopNumbers,
                        wallTitlesByMemoryId: wallTitlesByMemoryId,
                      ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Row(
                        children: [
                          _GlassIconButton(
                            tooltip: 'Back',
                            icon: Icons.arrow_back,
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          const SizedBox(width: 8),
                          _GlassIconButton(
                            key: const ValueKey('ar_hud_settings_button'),
                            tooltip: 'HUD settings',
                            icon: Icons.tune,
                            onPressed: () => _showHudSettingsSheet(context),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Row(
                        children: [
                          _GlassIconButton(
                            tooltip: 'Recenter anchors',
                            icon: Icons.my_location,
                            onPressed: () =>
                                _recenterOnNearest(activeProjectedAnchors),
                          ),
                          const SizedBox(width: 8),
                          _GlassIconButton(
                            tooltip: 'Toggle anchors',
                            icon: _showAnchors
                                ? Icons.visibility
                                : Icons.visibility_off,
                            onPressed: () =>
                                setState(() => _showAnchors = !_showAnchors),
                          ),
                        ],
                      ),
                    ),
                    if (_showRadar)
                      Positioned(
                        top: 72,
                        left: 16,
                        child: _ARRadar(
                          anchors: activeProjectedAnchors,
                          focusedMemoryId: _focusedMemoryId,
                          headingDegrees: _headingDegrees,
                          trailStopNumbers: trailStopNumbers,
                          isExpanded: _isRadarExpanded,
                          onToggle: () {
                            setState(
                              () => _isRadarExpanded = !_isRadarExpanded,
                            );
                          },
                          onFocus: _recenterOnAnchor,
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 20,
                      child: _buildBottomPanel(
                        context,
                        activeProjectedAnchors,
                        anchors.length,
                        focusedAnchor,
                        linkedWalls,
                        journeyStep,
                        _journeyTitle,
                        sourceWall,
                        extraWalls,
                        trailStopNumbers,
                        arCapabilities,
                        arSessionPlan,
                        arCapture,
                        sceneDiagnostics,
                        trailProgress,
                        showInfoDashboard: _showInfoDashboard,
                        showRecordingPanel: _showRecordingPanel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraBackdrop() {
    return FutureBuilder<ARRuntimePermissions>(
      future: _arPermissionsFuture,
      builder: (context, permissionSnapshot) {
        final permissions = permissionSnapshot.data;
        if (permissions == null) {
          return _buildProjectionBackdrop(statusLabel: 'Requesting camera');
        }
        if (!permissions.cameraGranted) {
          return _buildProjectionBackdrop(
            statusLabel: permissions.statusLabel,
            message: permissions.guidanceLabel,
            actionLabel: permissions.shouldOpenSettings
                ? 'Open settings'
                : 'Grant access',
            onAction: permissions.shouldOpenSettings
                ? _openARRuntimePermissionSettings
                : _retryARRuntimePermissions,
          );
        }
        final sessionConfig = ref.watch(arViewerSessionConfigProvider);
        return sessionConfig.when(
          data: (config) {
            return Stack(
              children: [
                Positioned.fill(
                  child: ARWidget(
                    key: const ValueKey('native_ar_hanging_photo_view'),
                    config: config.copyWith(
                      geospatialEnabled: false,
                      depthEnabled: false,
                      occlusionEnabled: false,
                      targetFrameRate: 30,
                    ),
                    resolveConfigAgainstCapabilities: true,
                    consumeGestures: false,
                    loadingWidget: _buildProjectionBackdrop(
                      statusLabel: 'Starting AR camera',
                    ),
                    errorBuilder: (context, error) => _buildProjectionBackdrop(
                      statusLabel: 'AR camera unavailable',
                      message: '$error',
                      actionLabel: 'Retry',
                      onAction: _refreshNativeScene,
                    ),
                    onARViewCreated: _handleNativeARViewCreated,
                    onSessionConfigResolved: _handleNativeSessionConfigResolved,
                    onSessionHealthChanged: _handleNativeSessionHealthChanged,
                    onSessionHealthAssessmentChanged:
                        _handleNativeSessionHealthAssessmentChanged,
                    onSessionDiagnosticsReportChanged:
                        _handleNativeSessionDiagnosticsReportChanged,
                    sessionHealthPolicy: _nativeSessionHealthPolicy,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _ArReticlePainter()),
                  ),
                ),
              ],
            );
          },
          loading: () => _buildProjectionBackdrop(
            statusLabel: 'Preparing AR session',
          ),
          error: (error, _) => _buildProjectionBackdrop(
            statusLabel: 'AR session unavailable',
            message: '$error',
            actionLabel: 'Retry',
            onAction: () {
              ref.invalidate(arViewerCapabilitiesProvider);
              ref.invalidate(arViewerSessionPlanProvider);
              ref.invalidate(arViewerSessionConfigProvider);
            },
          ),
        );
      },
    );
  }

  void _handleNativeARViewCreated(ARController controller) {
    if (!mounted) {
      return;
    }
    _arCameraSubscription?.cancel();
    _arCameraSubscription = controller.onCameraUpdate.listen(
      _handleNativeCameraUpdate,
      onError: (_) {},
      cancelOnError: false,
    );
    unawaited(_captureController.attachController(controller));
    setState(() {
      _arController = controller;
      _nativeMemoryScene = JejakuMemoryARScene(
        controller: controller,
        preferNativeGeospatialAnchors: false,
      );
      _nativeCloudAnchorManager = JejakuMemoryCloudAnchorManager(
        controller: controller,
      );
      _nativeMemoryPlacementAllowed = false;
      _latestSessionReadiness = null;
      _nativeSceneFingerprint = null;
    });
    _nativeSessionPlacementCache.clear();
    _lastARHeadingUpdateAt = null;
    _scheduleNativeSceneSync();
  }

  void _handleNativeCameraUpdate(ARCamera camera) {
    final now = DateTime.now().toUtc();
    _lastARCameraFrameAt = now;
    final hadTrackingCamera = _latestARCamera?.isTracking == true;
    _latestARCamera = camera;
    if (!mounted || !camera.isTracking) {
      return;
    }
    if (!hadTrackingCamera && _nativeMemoryScene != null) {
      _nativeSceneFingerprint = null;
      _scheduleNativeSceneSync();
    }
    final heading = _headingFromARCamera(camera);
    if (heading == null) {
      return;
    }
    final headingDelta = _headingDeltaDegrees(_headingDegrees, heading).abs();
    if (headingDelta < 0.35) {
      return;
    }
    final lastHeadingUpdateAt = _lastARHeadingUpdateAt;
    if (lastHeadingUpdateAt != null &&
        now.difference(lastHeadingUpdateAt) <
            const Duration(milliseconds: 120) &&
        headingDelta < 3) {
      return;
    }
    _lastARHeadingUpdateAt = now;
    ref.read(captureSessionProvider.notifier).updatePreviewPose(
          headingDegrees: heading,
          captureSource: 'ARCore camera pose',
        );
    setState(() => _headingDegrees = heading);
  }

  double? _headingFromARCamera(ARCamera camera) {
    final forward = camera.pose.rotation.rotateVector(ARVector3.forward);
    final horizontalLength =
        math.sqrt(forward.x * forward.x + forward.z * forward.z);
    if (horizontalLength < 0.001) {
      return null;
    }
    final radians = math.atan2(forward.x, -forward.z);
    return _normalizeHeading(radians * 180 / math.pi);
  }

  void _handleNativeSessionConfigResolved(
    ARSessionConfigResolution resolution,
  ) {
    _unsupportedNativeSessionFeatureKeys =
        Set<String>.unmodifiable(resolution.unsupportedFeatureKeys);
    _diagnosticsController.updateSessionConfigResolutionForSession(
      _diagnosticsSessionId,
      resolution,
    );
  }

  void _handleNativeSessionHealthChanged(ARSessionHealthSnapshot health) {
    _diagnosticsController.updateSessionHealthForSession(
      _diagnosticsSessionId,
      health,
    );
  }

  void _handleNativeSessionHealthAssessmentChanged(
    ARSessionHealthAssessment assessment,
  ) {
    final readiness = assessment.readiness;
    final didReadinessChange = _latestSessionReadiness != readiness;
    _latestSessionReadiness = readiness;
    if (didReadinessChange) {
      _nativeSceneFingerprint = null;
    }
    _diagnosticsController.updateSessionHealthAssessmentForSession(
      _diagnosticsSessionId,
      assessment,
    );
    _captureController.updateAssessment(assessment);
    if (_nativeMemoryScene != null) {
      _nativeMemoryPlacementAllowed = true;
      _scheduleNativeSceneSync();
    }
  }

  void _handleNativeSessionDiagnosticsReportChanged(
    ARDiagnosticsReport report,
  ) {
    _diagnosticsController.updateSessionDiagnosticsReportForSession(
      _diagnosticsSessionId,
      report,
    );
  }

  Map<String, Uint8List> _mediaPreviewBytesByMemoryId(
    Iterable<AnchorMemory> memories,
  ) {
    final result = <String, Uint8List>{};
    for (final memory in memories) {
      final resolvedMedia = ref.read(anchorResolvedMediaProvider(memory));
      final previewBytes = resolvedMedia?.previewBytes;
      if (previewBytes != null && previewBytes.isNotEmpty) {
        result[memory.id] = previewBytes;
      }
    }
    return Map<String, Uint8List>.unmodifiable(result);
  }

  Map<String, String> _mediaIdsByMemoryId(Iterable<AnchorMemory> memories) {
    final result = <String, String>{};
    for (final memory in memories) {
      final resolvedMedia = ref.read(anchorResolvedMediaProvider(memory));
      final mediaId = resolvedMedia?.mediaId?.trim();
      if (mediaId != null && mediaId.isNotEmpty) {
        result[memory.id] = mediaId;
      }
    }
    return Map<String, String>.unmodifiable(result);
  }

  Map<String, ARMemorySessionPlacement> _nativeSessionPlacementsByMemoryId(
    Iterable<ARMemoryProjection> projections,
  ) {
    final projectionList = List<ARMemoryProjection>.unmodifiable(projections);
    final activeMemoryIds = {
      for (final projected in projectionList) projected.memory.id,
    };
    _nativeSessionPlacementCache.removeWhere(
      (memoryId, _) => !activeMemoryIds.contains(memoryId),
    );

    final camera = _latestARCamera;
    final frameAt = _lastARCameraFrameAt;
    if (camera == null ||
        !camera.isTracking ||
        frameAt == null ||
        DateTime.now().toUtc().difference(frameAt) >
            const Duration(seconds: 2)) {
      return Map<String, ARMemorySessionPlacement>.unmodifiable(
        _nativeSessionPlacementCache,
      );
    }

    for (final projected in projectionList) {
      final memory = projected.memory;
      if (_hasSameSessionLocalPose(memory)) {
        _nativeSessionPlacementCache.remove(memory.id);
        continue;
      }
      if (_nativeSessionPlacementCache.containsKey(memory.id)) {
        continue;
      }
      final projection = projected.projection;
      final isFocused = memory.id == _focusedMemoryId;
      if (!projection.isInFront && !isFocused) {
        continue;
      }

      final headingDegrees = (isFocused && !projection.isInFront)
          ? 0.0
          : projection.relativeHeadingDegrees.clamp(-72.0, 72.0).toDouble();
      final pitchDegrees =
          projection.relativePitchDegrees.clamp(-22.0, 22.0).toDouble();
      final distanceMeters = projection.distanceMeters.isFinite
          ? projection.distanceMeters
          : projection.horizontalDistanceMeters;
      final renderDistance = distanceMeters.isFinite
          ? distanceMeters.clamp(1.35, 8.0).toDouble()
          : 1.8;
      final yaw = headingDegrees * math.pi / 180;
      final pitch = pitchDegrees * math.pi / 180;
      final cosPitch = math.cos(pitch);
      final nodePosition = ARVector3(
        math.sin(yaw) * renderDistance * cosPitch,
        math.sin(pitch) * renderDistance,
        -math.cos(yaw) * renderDistance * cosPitch,
      );

      _nativeSessionPlacementCache[memory.id] = ARMemorySessionPlacement(
        anchorPose: _hangingFrameAnchorPose(camera, nodePosition),
        nodePosition: const ARVector3.zero(),
        mode: 'hanging_photo_frame',
      );
    }
    return Map<String, ARMemorySessionPlacement>.unmodifiable(
      _nativeSessionPlacementCache,
    );
  }

  ARPoseInput _hangingFrameAnchorPose(
    ARCamera camera,
    ARVector3 cameraRelativePosition,
  ) {
    final yawRotation = _cameraYawRotation(camera);
    final position = camera.pose.position;
    final framePosition =
        position + yawRotation.rotateVector(cameraRelativePosition);
    return ARPoseInput(
      x: framePosition.x,
      y: framePosition.y,
      z: framePosition.z,
      qx: yawRotation.x,
      qy: yawRotation.y,
      qz: yawRotation.z,
      qw: yawRotation.w,
    );
  }

  ARQuaternion _cameraYawRotation(ARCamera camera) {
    final forward = camera.pose.rotation.rotateVector(ARVector3.forward);
    final horizontalForward = ARVector3(forward.x, 0, forward.z);
    if (horizontalForward.lengthSquared < 0.000001) {
      return const ARQuaternion.identity();
    }
    return ARQuaternion.fromToRotation(
      ARVector3.forward,
      horizontalForward.normalized,
    ).normalized;
  }

  bool _hasSameSessionLocalPose(AnchorMemory memory) {
    final capturedAt = memory.captureMetadata.localAnchorPose?.capturedAt;
    if (capturedAt == null) {
      return false;
    }
    return !capturedAt.toUtc().isBefore(
          _diagnosticsSessionStartedAt.subtract(const Duration(seconds: 5)),
        );
  }

  void _maybeScheduleNativeSceneSync(
    List<ARMemoryProjection> anchors,
    AsyncValue<JejakuARCapabilities> arCapabilities, {
    required JejakuGeoOrigin viewerOrigin,
  }) {
    final nativeProjections = _nativeSceneVisualProjections(anchors);
    _latestNativeSceneMemories = [
      for (final anchor in nativeProjections) anchor.memory,
    ];
    _latestNativeSceneProjections = List<ARMemoryProjection>.unmodifiable(
      nativeProjections,
    );
    if (!_sameGeoOrigin(_latestNativeSceneOrigin, viewerOrigin)) {
      _latestNativeSceneOrigin = viewerOrigin;
      _nativeSessionPlacementCache.clear();
      _nativeSceneFingerprint = null;
    }
    final bool? canStartSession = arCapabilities.when(
      data: (capabilities) {
        final canPersistCloudAnchors = capabilities.canPersistCloudAnchors &&
            _resolvedSessionCloudAnchorsEnabled;
        if (_nativeCloudAnchorsEnabled != canPersistCloudAnchors) {
          _nativeSceneFingerprint = null;
        }
        if (!canPersistCloudAnchors) {
          _cancelCloudAnchorMaintenance();
          _cancelCloudAnchorRetry();
        }
        _nativeCloudAnchorsEnabled = canPersistCloudAnchors;
        return capabilities.canStartSession;
      },
      error: (_, __) {
        _nativeCloudAnchorsEnabled = false;
        _cancelCloudAnchorMaintenance();
        _cancelCloudAnchorRetry();
        return false;
      },
      loading: () => null,
    );
    if (canStartSession != true || _nativeMemoryScene == null) {
      _nativeMemoryPlacementAllowed = false;
      if (canStartSession == false) {
        final hadNativeSession =
            _nativeMemoryScene != null || _nativeCloudAnchorManager != null;
        _arController = null;
        _nativeMemoryScene = null;
        _nativeCloudAnchorManager = null;
        _nativeSessionPlacementCache.clear();
        if (hadNativeSession) {
          _scheduleCaptureDetach();
        }
        _cancelCloudAnchorMaintenance();
        _cancelCloudAnchorRetry();
        _cloudAnchorHostInFlightMemoryIds.clear();
        _nativeSceneFingerprint = null;
        _scheduleNativeSceneDiagnosticsReset();
      }
      return;
    }
    if (_latestSessionReadiness == null) {
      _nativeMemoryPlacementAllowed = false;
      _cancelCloudAnchorMaintenance();
      _cancelCloudAnchorRetry();
      return;
    }
    final mediaPreviewBytesByMemoryId = _mediaPreviewBytesByMemoryId(
      _latestNativeSceneMemories,
    );
    final mediaIdsByMemoryId = _mediaIdsByMemoryId(_latestNativeSceneMemories);
    final sessionPlacementsByMemoryId = _nativeSessionPlacementsByMemoryId(
      _latestNativeSceneProjections,
    );
    final fingerprint = _nativeSceneSyncService.fingerprint(
      origin: _latestNativeSceneOrigin,
      memories: _latestNativeSceneMemories,
      mediaPreviewBytesByMemoryId: mediaPreviewBytesByMemoryId,
      mediaIdsByMemoryId: mediaIdsByMemoryId,
      sessionPlacementsByMemoryId: sessionPlacementsByMemoryId,
      nativeSessionStartedAt: _diagnosticsSessionStartedAt,
    );
    if (_isNativePlacementPaused) {
      _nativeMemoryPlacementAllowed = true;
      _cancelCloudAnchorMaintenance();
      _cancelCloudAnchorRetry();
      if (fingerprint != _nativeSceneFingerprint) {
        _scheduleNativeSceneSync();
      }
      return;
    }
    _nativeMemoryPlacementAllowed = true;
    _scheduleCloudAnchorMaintenance();
    if (fingerprint == _nativeSceneFingerprint) {
      return;
    }
    _scheduleNativeSceneSync();
  }

  bool get _isNativePlacementPaused {
    final readiness = _latestSessionReadiness;
    return readiness != null && !readiness.canPlaceAnchors;
  }

  List<ARMemoryProjection> _nativeSceneVisualProjections(
    List<ARMemoryProjection> anchors,
  ) {
    if (anchors.isEmpty) {
      return const <ARMemoryProjection>[];
    }
    final selected = <ARMemoryProjection>[];
    final focusedMemoryId = _focusedMemoryId;
    if (focusedMemoryId != null) {
      for (final anchor in anchors) {
        if (anchor.memory.id == focusedMemoryId) {
          selected.add(anchor);
          break;
        }
      }
    }
    for (final anchor in anchors) {
      if (selected.length >= 3) {
        break;
      }
      if (selected.any((item) => item.memory.id == anchor.memory.id)) {
        continue;
      }
      if (anchor.projection.isInFront || selected.isEmpty) {
        selected.add(anchor);
      }
    }
    return List<ARMemoryProjection>.unmodifiable(selected);
  }

  void _scheduleCaptureDetach() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_detachCaptureControllerSafely());
    });
  }

  Future<void> _detachCaptureControllerSafely() async {
    try {
      await _captureController.detachController();
    } catch (_) {
      // The provider scope may already be gone during route teardown.
    }
  }

  void _scheduleNativeSceneSync() {
    if (_nativeSceneSyncScheduled) {
      return;
    }
    _nativeSceneSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nativeSceneSyncScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_syncNativeScene());
    });
  }

  Future<void> _syncNativeScene() async {
    if (!_nativeMemoryPlacementAllowed) {
      return;
    }
    if (_nativeSceneSyncing) {
      return;
    }
    _nativeSceneSyncing = true;
    String? attemptedFingerprint;
    try {
      while (mounted) {
        final scene = _nativeMemoryScene;
        if (scene == null) {
          return;
        }
        final memories = List<AnchorMemory>.unmodifiable(
          _latestNativeSceneMemories,
        );
        final origin = _latestNativeSceneOrigin;
        final mediaPreviewBytesByMemoryId = _mediaPreviewBytesByMemoryId(
          memories,
        );
        final mediaIdsByMemoryId = _mediaIdsByMemoryId(memories);
        final sessionPlacementsByMemoryId = _nativeSessionPlacementsByMemoryId(
          _latestNativeSceneProjections,
        );
        final fingerprint = _nativeSceneSyncService.fingerprint(
          origin: origin,
          memories: memories,
          mediaPreviewBytesByMemoryId: mediaPreviewBytesByMemoryId,
          mediaIdsByMemoryId: mediaIdsByMemoryId,
          sessionPlacementsByMemoryId: sessionPlacementsByMemoryId,
          nativeSessionStartedAt: _diagnosticsSessionStartedAt,
        );
        if (fingerprint == _nativeSceneFingerprint) {
          return;
        }
        attemptedFingerprint = fingerprint;
        final placementReadiness = _nativeScenePlacementReadinessForSync();
        final outcome = await _nativeSceneSyncService.sync(
          scene: scene,
          origin: origin,
          memories: memories,
          cloudAnchorManager:
              _nativeCloudAnchorsEnabled ? _nativeCloudAnchorManager : null,
          placementReadiness: placementReadiness,
          mediaPreviewBytesByMemoryId: mediaPreviewBytesByMemoryId,
          mediaIdsByMemoryId: mediaIdsByMemoryId,
          sessionPlacementsByMemoryId: sessionPlacementsByMemoryId,
          modelPreflight: ref.read(arMemoryModelPreflightProvider),
          nativeSessionStartedAt: _diagnosticsSessionStartedAt,
        );
        if (!mounted || scene != _nativeMemoryScene) {
          return;
        }
        final hostingResult = outcome.scene.isPlacementDeferred
            ? const ARMemoryCloudAnchorHostingResult()
            : await _maybeHostCloudAnchors(
                sceneResult: outcome.scene,
                memories: memories,
              );
        if (!mounted || scene != _nativeMemoryScene) {
          return;
        }
        final retryDecision = outcome.scene.isPlacementDeferred
            ? null
            : _scheduleCloudAnchorRetry({
                ...outcome.cloudAnchors.unresolvedMemoryIds,
                ...hostingResult.failedMemoryIds,
              });
        if (outcome.scene.isPlacementDeferred) {
          _cancelCloudAnchorRetry();
        }
        _publishNativeSceneDiagnostics(
          ARMemorySceneDiagnostics.fromSync(
            sessionId: _diagnosticsSessionId,
            scene: outcome.scene,
            memories: memories,
            resolution: outcome.cloudAnchors,
            hosting: hostingResult,
            modelPreflight: outcome.modelPreflight,
            cloudAnchorsEnabled: _nativeCloudAnchorsEnabled,
            syncedAt: DateTime.now(),
            nextCloudAnchorRetryDelay: retryDecision?.delay,
            cloudAnchorRetryAttempt: _cloudAnchorRetryState.attempt,
            nextCloudAnchorMaintenanceAt: _cloudAnchorMaintenanceCheckAt,
            sessionStartedAt: _diagnosticsSessionStartedAt,
            unsupportedSessionFeatureKeys: _unsupportedNativeSessionFeatureKeys,
          ),
        );
        _nativeSceneFingerprint = fingerprint;
      }
    } catch (error) {
      // The projection HUD remains the fallback if native scene placement fails.
      _nativeSceneFingerprint = attemptedFingerprint;
      _publishNativeSceneFailure(error);
    } finally {
      _nativeSceneSyncing = false;
      final shouldRefreshAgain = _nativeSceneRefreshQueued;
      _nativeSceneRefreshQueued = false;
      if (shouldRefreshAgain && mounted && _nativeMemoryScene != null) {
        _scheduleNativeSceneSync();
      }
    }
  }

  ARSessionReadiness? _nativeScenePlacementReadinessForSync() {
    final readiness = _latestSessionReadiness;
    if (readiness == null) {
      return null;
    }
    if (readiness.canPlaceAnchors) {
      return null;
    }
    return readiness;
  }

  Future<ARMemoryCloudAnchorHostingResult> _maybeHostCloudAnchors({
    required JejakuMemorySceneSyncResult sceneResult,
    required List<AnchorMemory> memories,
  }) async {
    if (sceneResult.isPlacementDeferred) {
      return const ARMemoryCloudAnchorHostingResult();
    }
    if (!_nativeCloudAnchorsEnabled) {
      return const ARMemoryCloudAnchorHostingResult();
    }
    final manager = _nativeCloudAnchorManager;
    if (manager == null) {
      return const ARMemoryCloudAnchorHostingResult();
    }

    final hostable = [
      for (final placed in sceneResult.active)
        if (!_cloudAnchorHostInFlightMemoryIds.contains(placed.memory.id))
          placed,
    ];
    if (hostable.isEmpty) {
      return const ARMemoryCloudAnchorHostingResult();
    }

    _cloudAnchorHostInFlightMemoryIds.addAll(
      hostable.map((placed) => placed.memory.id),
    );
    ARMemoryCloudAnchorHostingResult hostingResult =
        const ARMemoryCloudAnchorHostingResult();
    try {
      hostingResult =
          await _cloudAnchorHostingService.hostMissingCloudAnchorsWithReport(
        manager: manager,
        memories: memories,
        placedMemories: hostable,
      );
      if (mounted && hostingResult.records.isNotEmpty) {
        final controller = ref.read(nearbyAnchorsProvider.notifier);
        for (final record in hostingResult.records) {
          controller.attachCloudAnchorRecord(
            memoryId: record.memoryId,
            localAnchorId: record.localAnchorId,
            cloudAnchorId: record.cloudAnchorId,
            expiresAt: record.expiresAt,
          );
        }
      }
    } catch (_) {
      final failedMemoryIds = {
        for (final placed in hostable) placed.memory.id,
      };
      hostingResult = ARMemoryCloudAnchorHostingResult(
        failedMemoryIds: failedMemoryIds,
        failureReasons: <String, ARMemoryCloudAnchorHostingFailureReason>{
          for (final memoryId in failedMemoryIds)
            memoryId: ARMemoryCloudAnchorHostingFailureReason.nativeError,
        },
      );
      // Native cloud persistence is opportunistic; placement still works.
    } finally {
      _cloudAnchorHostInFlightMemoryIds.removeAll(
        hostable.map((placed) => placed.memory.id),
      );
    }
    return hostingResult;
  }

  ARMemoryCloudAnchorRetryDecision? _scheduleCloudAnchorRetry(
    Set<String> memoryIds,
  ) {
    if (memoryIds.isEmpty) {
      _cancelCloudAnchorRetry();
      return null;
    }
    if (_cloudAnchorRetryTimer?.isActive == true &&
        _cloudAnchorRetryState.tracksSameFailures(memoryIds)) {
      return null;
    }

    final decision = _cloudAnchorRetryPolicy.next(
      memoryIds: memoryIds,
      current: _cloudAnchorRetryState,
    );
    if (!decision.shouldRetry) {
      _cancelCloudAnchorRetry();
      return decision;
    }
    _cloudAnchorRetryState = decision.state;
    _cloudAnchorRetryTimer?.cancel();
    _cloudAnchorRetryTimer = Timer(decision.delay!, () {
      _cloudAnchorRetryTimer = null;
      if (!mounted || _nativeMemoryScene == null) {
        return;
      }
      _nativeSceneFingerprint = null;
      _scheduleNativeSceneSync();
    });
    return decision;
  }

  void _cancelCloudAnchorRetry() {
    _cloudAnchorRetryTimer?.cancel();
    _cloudAnchorRetryTimer = null;
    _cloudAnchorRetryState = const ARMemoryCloudAnchorRetryState();
  }

  void _scheduleCloudAnchorMaintenance() {
    if (!_nativeCloudAnchorsEnabled || _nativeMemoryScene == null) {
      _cancelCloudAnchorMaintenance();
      return;
    }

    final now = DateTime.now().toUtc();
    final plan = _cloudAnchorMaintenancePolicy.plan(
      memories: _latestNativeSceneMemories,
      now: now,
    );
    if (plan.hasDueMemories) {
      _cancelCloudAnchorMaintenance();
      _nativeSceneFingerprint = null;
      _scheduleNativeSceneSync();
      return;
    }

    final nextCheckAt = plan.nextCheckAt;
    if (nextCheckAt == null) {
      _cancelCloudAnchorMaintenance();
      return;
    }
    if (_cloudAnchorMaintenanceTimer?.isActive == true &&
        _cloudAnchorMaintenanceCheckAt == nextCheckAt) {
      return;
    }

    _cloudAnchorMaintenanceCheckAt = nextCheckAt;
    _cloudAnchorMaintenanceTimer?.cancel();
    _cloudAnchorMaintenanceTimer = Timer(plan.delayFrom(now)!, () {
      _cloudAnchorMaintenanceTimer = null;
      _cloudAnchorMaintenanceCheckAt = null;
      if (!mounted ||
          !_nativeCloudAnchorsEnabled ||
          _nativeMemoryScene == null) {
        return;
      }
      _nativeSceneFingerprint = null;
      _scheduleNativeSceneSync();
    });
  }

  void _cancelCloudAnchorMaintenance() {
    _cloudAnchorMaintenanceTimer?.cancel();
    _cloudAnchorMaintenanceTimer = null;
    _cloudAnchorMaintenanceCheckAt = null;
  }

  void _publishNativeSceneDiagnostics(ARMemorySceneDiagnostics diagnostics) {
    if (!mounted) {
      return;
    }
    final current = _sceneDiagnosticsForSession(
      ref.read(arMemorySceneDiagnosticsProvider),
    );
    final next = current.hasNativeSceneFailure &&
            diagnostics.isNativePlacementDeferred &&
            !diagnostics.hasNativeSceneFailure
        ? diagnostics.copyWith(
            nativeSceneFailureMessage: current.nativeSceneFailureMessage,
            nativeSceneFailedAt: current.nativeSceneFailedAt,
          )
        : diagnostics;
    _diagnosticsController.updateForSession(_diagnosticsSessionId, next);
  }

  void _publishNativeSceneFailure(Object error) {
    if (!mounted) {
      return;
    }
    final providerDiagnostics = ref.read(arMemorySceneDiagnosticsProvider);
    final failed = _sceneDiagnosticsForSession(
      providerDiagnostics,
    ).withNativeSceneFailure(
      error: error,
      failedAt: DateTime.now(),
    );
    _diagnosticsController.update(failed);
  }

  ARMemorySceneDiagnostics _sceneDiagnosticsForSession(
    ARMemorySceneDiagnostics diagnostics,
  ) {
    if (diagnostics.sessionId == _diagnosticsSessionId) {
      return diagnostics;
    }
    return ARMemorySceneDiagnostics.sessionStarted(
      sessionId: _diagnosticsSessionId,
      startedAt: _diagnosticsSessionStartedAt,
    );
  }

  void _scheduleNativeSceneDiagnosticsReset() {
    if (_nativeSceneDiagnosticsResetScheduled) {
      return;
    }
    _nativeSceneDiagnosticsResetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nativeSceneDiagnosticsResetScheduled = false;
      if (!mounted) {
        return;
      }
      _resetNativeSceneDiagnostics();
    });
  }

  void _resetNativeSceneDiagnostics() {
    if (!mounted) {
      return;
    }
    _diagnosticsController.resetSession(_diagnosticsSessionId);
  }

  void _refreshNativeScene() {
    _nativeSessionPlacementCache.clear();
    _nativeSceneFingerprint = null;
    _cancelCloudAnchorRetry();
    if (_nativeMemoryScene == null) {
      _nativeSceneRefreshQueued = false;
      _resetNativeSceneDiagnostics();
      return;
    }
    if (_nativeSceneSyncing) {
      _nativeSceneRefreshQueued = true;
      return;
    }
    _scheduleNativeSceneSync();
  }

  Widget _buildProjectionBackdrop({
    required String statusLabel,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF111827),
            Color(0xFF0F172A),
            Color(0xFF020617),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ArReticlePainter()),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar, color: Colors.white54, size: 96),
                SizedBox(height: 12),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 128),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusLabel,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
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
        ],
      ),
    );
  }

  List<Widget> _buildAnchorOverlays(
    List<ARMemoryProjection> anchors, {
    required String? focusedMemoryId,
    required Map<String, int> trailStopNumbers,
    required Map<String, List<String>> wallTitlesByMemoryId,
  }) {
    return [
      for (final anchor in anchors.reversed)
        Align(
          alignment: anchor.memory.id == focusedMemoryId
              ? const Alignment(0, -0.1)
              : Alignment(
                  anchor.projection.alignmentX,
                  anchor.projection.alignmentY,
                ),
          child: Opacity(
            opacity: anchor.memory.id == focusedMemoryId
                ? 1.0
                : anchor.projection.opacity.clamp(0.48, 1.0),
            child: Transform.scale(
              scale: anchor.memory.id == focusedMemoryId
                  ? 1.0
                  : anchor.projection.scale,
              child: _AnchorBubble(
                anchor: anchor,
                isFocused: anchor.memory.id == focusedMemoryId,
                stopNumber: trailStopNumbers[anchor.memory.id],
                wallTitles:
                    wallTitlesByMemoryId[anchor.memory.id] ?? const <String>[],
                onTap: () => _recenterOnAnchor(anchor),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildBottomPanel(
    BuildContext context,
    List<ARMemoryProjection> anchors,
    int totalAnchors,
    ARMemoryProjection? focusedAnchor,
    List<ARWall> linkedWalls,
    AnchorJourneyStep? journeyStep,
    String? journeyTitle,
    ARWall? sourceWall,
    List<ARWall> extraWalls,
    Map<String, int> trailStopNumbers,
    AsyncValue<JejakuARCapabilities> arCapabilities,
    AsyncValue<JejakuARSessionPlan> arSessionPlan,
    ARViewerCaptureState arCapture,
    ARMemorySceneDiagnostics sceneDiagnostics,
    ARTrailProgress? trailProgress, {
    required bool showInfoDashboard,
    required bool showRecordingPanel,
  }) {
    final isWallTrail = trailStopNumbers.isNotEmpty;
    final hudAnchors = isWallTrail
        ? anchors
            .where((anchor) => trailStopNumbers.containsKey(anchor.memory.id))
            .toList()
        : anchors;
    final displayTotal = isWallTrail ? hudAnchors.length : totalAnchors;
    final visibleCount = hudAnchors.where((anchor) {
      return anchor.projection.isVisible;
    }).length;
    final reliableCount = hudAnchors.where((anchor) {
      return anchor.projection.assessment.isReliable;
    }).length;
    final reviewCount = hudAnchors.where((anchor) {
      return anchor.memory.needsCalibrationReview;
    }).length;
    final missingTrailAnchor = _firstMissingTrailAnchor(
      trailProgress,
      anchors,
    );
    final sourceWallStopCount = sourceWall?.linkedMemoryIds
        .where((memoryId) => trailStopNumbers.containsKey(memoryId))
        .length;

    final showCaptureControls =
        showRecordingPanel || arCapture.recordingState != ARRecordingState.idle;
    final captureReadinessTrend = _captureReadinessTrend(
      sceneDiagnostics,
      arCapture,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showInfoDashboard && focusedAnchor != null) ...[
          _FocusedAnchorPanel(
            anchor: focusedAnchor,
            linkedWalls: linkedWalls,
            onDetails: () => Navigator.pushNamed(
              context,
              AppRoutes.memoryDetails,
              arguments: focusedAnchor.memory.id,
            ),
            onCalibrate: () => Navigator.pushNamed(
              context,
              AppRoutes.memoryCalibration,
              arguments: focusedAnchor.memory.id,
            ),
            onOpenWall: (wall) => Navigator.pushNamed(
              context,
              AppRoutes.virtualWallDetails,
              arguments: wall.id,
            ),
            onRecenter: () => _recenterOnAnchor(focusedAnchor),
          ),
          const SizedBox(height: 12),
        ],
        if (showInfoDashboard &&
            journeyStep != null &&
            journeyStep.total > 1) ...[
          _ARJourneyPanel(
            step: journeyStep,
            title: journeyTitle,
            trailProgress: trailProgress,
            headingDegrees: _headingDegrees,
            sourceWall: sourceWall,
            sourceWallStopCount: sourceWallStopCount,
            extraWalls: extraWalls,
            missingStopMemory: missingTrailAnchor?.memory,
            missingStopSpatialLabel: _missingStopSpatialLabel(
              missingTrailAnchor,
            ),
            onOpenSourceWall: sourceWall == null
                ? null
                : () => Navigator.pushNamed(
                      context,
                      AppRoutes.virtualWallDetails,
                      arguments: sourceWall.id,
                    ),
            onOpenExtraWall: (wall) => Navigator.pushNamed(
              context,
              AppRoutes.virtualWallDetails,
              arguments: wall.id,
            ),
            onPrevious: journeyStep.previousMemory == null
                ? null
                : () => _recenterOnMemoryId(
                      anchors,
                      journeyStep.previousMemory!.id,
                    ),
            onNext: journeyStep.nextMemory == null
                ? null
                : () => _recenterOnMemoryId(
                      anchors,
                      journeyStep.nextMemory!.id,
                    ),
            onOpenMissingStop: missingTrailAnchor == null
                ? null
                : (memoryId) => _recenterOnMemoryId(anchors, memoryId),
            onFinish: _finishTrail,
          ),
          const SizedBox(height: 12),
        ],
        if (showInfoDashboard) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _HudPill(
                icon: Icons.navigation,
                label:
                    '${_headingDegrees.round()} deg ${_poseSourceShortLabel()}',
                color: Colors.cyanAccent.shade100,
                tooltip: _poseSourceDetailLabel(),
              ),
              _HudPill(
                icon: Icons.photo_camera,
                label: isWallTrail
                    ? '$visibleCount/$displayTotal trail in view'
                    : '$visibleCount/$displayTotal in view',
                color: Colors.greenAccent.shade100,
              ),
              _HudPill(
                icon: Icons.verified,
                label: '$reliableCount reliable',
                color: Colors.amberAccent.shade100,
              ),
              if (sceneDiagnostics.hasSessionHealth)
                _HudPill(
                  key: const ValueKey('ar_session_health_hud'),
                  icon: _sessionHealthIcon(sceneDiagnostics),
                  label: sceneDiagnostics.sessionHealthHudLabel,
                  color: _sessionHealthColor(sceneDiagnostics),
                  tooltip: sceneDiagnostics.sessionHealthDetailLabel,
                ),
              if (reviewCount > 0)
                _HudPill(
                  icon: Icons.warning_amber,
                  label: '$reviewCount review',
                  color: Colors.redAccent.shade100,
                ),
              _HudPill(
                key: const ValueKey('ar_scene_diagnostics_hud'),
                icon: _sceneDiagnosticsIcon(sceneDiagnostics),
                label: sceneDiagnostics.hudStatusLabel,
                color: _sceneDiagnosticsColor(sceneDiagnostics),
                tooltip: sceneDiagnostics.detailStatusLabel,
                onTap: () => _showSceneDiagnosticsSheet(
                  context,
                  sceneDiagnostics,
                  anchors,
                  latestCaptureDiagnostics: ref
                      .read(captureSessionProvider.notifier)
                      .latestArDiagnostics,
                ),
              ),
              ..._capabilityHudPills(arSessionPlan, sceneDiagnostics),
            ],
          ),
          if (showCaptureControls) const SizedBox(height: 12),
        ],
        if (showCaptureControls) ...[
          _ARCaptureControls(
            state: arCapture,
            readinessTrend: captureReadinessTrend,
            onSnapshot: _captureARSnapshot,
            onRecord: _toggleARRecording,
            onPause: _pauseARRecording,
            onResume: _resumeARRecording,
            onCancel: _cancelARRecording,
          ),
        ],
        if (showInfoDashboard) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAnchorSheet(
                    context,
                    _sheetAnchors(anchors),
                    focusedMemoryId: _focusedMemoryId,
                    isWallTrail: _journeyMemoryIds.isNotEmpty,
                  ),
                  icon: const Icon(Icons.list),
                  label: const Text('List'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.camera);
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Capture'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openPublishAndFocusPublishedMemory() async {
    final result = await Navigator.pushNamed<Object?>(
      context,
      AppRoutes.publish,
    );
    if (!mounted || result is! String || result.isEmpty) {
      return;
    }
    setState(() {
      _focusedMemoryId = result;
      _didApplyInitialFocus = false;
      _nativeSceneFingerprint = null;
    });
    _scheduleNativeSceneSync();
  }

  Future<void> _captureARSnapshot() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _refreshViewerPoseFromDeviceSensors();
      final localPose = await _captureHangingPhotoLocalPose();
      final snapshot = await _captureController.captureSnapshot();
      Uint8List? stagedBytes = snapshot.bytes;
      var stagedAt = snapshot.capturedAt;
      var message = snapshot.succeeded
          ? 'AR snapshot staged for publishing'
          : snapshot.errorMessage ?? 'AR snapshot unavailable';
      if (!snapshot.succeeded) {
        stagedBytes = await _captureARVisualFrame();
        stagedAt = DateTime.now().toUtc();
        if (stagedBytes != null) {
          message = 'AR visual snapshot staged for publishing';
        }
      }
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text(message)),
        );
      if (stagedBytes != null) {
        final diagnostics = _captureDiagnosticsSnapshot(stagedAt);
        ref.read(captureSessionProvider.notifier).stageARSnapshot(
          capturedAt: stagedAt,
          bytes: stagedBytes,
          localPose: localPose,
          arDiagnostics: <String, Object?>{
            ...diagnostics,
            if (localPose != null) ...{
              'localSurfacePose': localPose.toMap(),
              'localSurfacePoseLabel': localPose.surfaceLabel,
            },
          },
        );
        await _openPublishAndFocusPublishedMemory();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('AR snapshot failed: $error')),
        );
    }
  }

  Future<AnchorLocalPose?> _captureHangingPhotoLocalPose() async {
    final controller = _arController;
    final camera = _latestARCamera;
    if (controller == null || camera == null || !camera.isTracking) {
      debugPrint(
        '[AR_HANGING_FRAME] capture_pose skipped: '
        'controller=${controller != null} camera=${camera != null} '
        'tracking=${camera?.isTracking}',
      );
      return null;
    }
    try {
      final hits = await controller.hitTest(0.5, 0.5).timeout(
            const Duration(milliseconds: 700),
          );
      final hit = _bestHangingPhotoHit(hits);
      final cameraPosition = camera.pose.position;
      final cameraForward = camera.pose.rotation.rotateVector(
        ARVector3.forward,
      );
      final horizontalForward = ARVector3(cameraForward.x, 0, cameraForward.z);
      if (horizontalForward.lengthSquared < 0.000001) {
        debugPrint(
          '[AR_HANGING_FRAME] capture_pose skipped: '
          'camera horizontal forward too small '
          'forward=${_formatARVector(cameraForward)}',
        );
        return null;
      }
      final forward = horizontalForward.normalized;
      const fallbackDistance = 1.5;
      final fallbackPosition = cameraPosition + forward * fallbackDistance;
      final useSurfacePosition =
          hit != null && _isVerticalHangingSurfaceHit(hit);
      final position =
          useSurfacePosition ? hit.worldPose.position : fallbackPosition;
      final rotation = _cameraYawRotation(camera);
      final distance = useSurfacePosition
          ? hit.distance
          : ARVector3.distance(cameraPosition, position);
      debugPrint(
        '[AR_HANGING_FRAME] capture_pose saved '
        'hits=${hits.length} '
        'selected=${_formatHangingFrameHit(hit)} '
        'usedVerticalSurface=$useSurfacePosition '
        'camera=${_formatARVector(cameraPosition)} '
        'forward=${_formatARVector(forward)} '
        'position=${_formatARVector(position)} '
        'rotation=${_formatARQuaternion(rotation)} '
        'distance=${distance.toStringAsFixed(3)}',
      );
      return AnchorLocalPose(
        x: position.x,
        y: position.y,
        z: position.z,
        qx: rotation.x,
        qy: rotation.y,
        qz: rotation.z,
        qw: rotation.w,
        planeId: useSurfacePosition
            ? (hit.planeId?.trim().isEmpty == true ? null : hit.planeId)
            : null,
        surfaceType: 'hangingPhotoFrame',
        distanceMeters: distance,
        confidence: useSurfacePosition ? hit.confidence : 0.72,
        capturedAt: DateTime.now().toUtc(),
      );
    } on Object catch (error) {
      debugPrint('[AR_HANGING_FRAME] capture_pose failed: $error');
      return null;
    }
  }

  ARHitTestResult? _bestHangingPhotoHit(List<ARHitTestResult> hits) {
    for (final hit in hits) {
      if (_isVerticalHangingSurfaceHit(hit)) {
        return hit;
      }
    }
    return hits.isEmpty ? null : hits.first;
  }

  bool _isVerticalHangingSurfaceHit(ARHitTestResult hit) {
    if (hit.type == ARHitTestResultType.estimatedVerticalPlane) {
      return true;
    }
    if (!hit.isOnPlane) {
      return false;
    }
    final normal = hit.worldPose.rotation.rotateVector(ARVector3.up);
    return normal.dot(ARVector3.up).abs() < 0.45;
  }

  String _formatHangingFrameHit(ARHitTestResult? hit) {
    if (hit == null) {
      return 'none';
    }
    final normal = hit.worldPose.rotation.rotateVector(ARVector3.up);
    return '${hit.type.name}'
        '/plane=${hit.planeId ?? '-'}'
        '/dist=${hit.distance.toStringAsFixed(3)}'
        '/conf=${hit.confidence.toStringAsFixed(2)}'
        '/normal=${_formatARVector(normal)}';
  }

  String _formatARVector(ARVector3 value) {
    return '(${value.x.toStringAsFixed(3)},'
        '${value.y.toStringAsFixed(3)},'
        '${value.z.toStringAsFixed(3)})';
  }

  String _formatARQuaternion(ARQuaternion value) {
    return '(${value.x.toStringAsFixed(3)},'
        '${value.y.toStringAsFixed(3)},'
        '${value.z.toStringAsFixed(3)},'
        '${value.w.toStringAsFixed(3)})';
  }

  Future<Uint8List?> _captureARVisualFrame() async {
    final overlayImage = await _captureAROverlayImage();
    if (overlayImage == null) {
      return null;
    }
    ui.Image? cameraImage;
    ui.Image? composedImage;
    try {
      cameraImage = await _captureNativeCameraImage();
      final outputImage = cameraImage == null
          ? overlayImage
          : await _composeARVisualFrame(
              cameraImage: cameraImage,
              overlayImage: overlayImage,
            );
      if (!identical(outputImage, overlayImage)) {
        composedImage = outputImage;
      }
      final data = await outputImage.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      composedImage?.dispose();
      cameraImage?.dispose();
      overlayImage.dispose();
    }
  }

  Future<ui.Image?> _captureAROverlayImage() async {
    if (!mounted) {
      return null;
    }
    final boundaryContext = _arVisualOverlayRecordingBoundaryKey.currentContext;
    final renderObject = boundaryContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      return null;
    }
    if (renderObject.debugNeedsPaint) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return null;
      }
    }
    final view = View.maybeOf(context);
    final rawPixelRatio = view?.devicePixelRatio ?? 1.0;
    final pixelRatio =
        rawPixelRatio.clamp(1.0, _screenRecordingMaxPixelRatio).toDouble();
    return renderObject.toImage(pixelRatio: pixelRatio);
  }

  Future<ui.Image?> _captureNativeCameraImage() async {
    final controller = _arController;
    if (controller == null) {
      return null;
    }
    try {
      final cameraBytes = await controller.captureSnapshot();
      if (cameraBytes == null || cameraBytes.isEmpty) {
        return null;
      }
      return _decodeImage(cameraBytes);
    } on Object {
      return null;
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<ui.Image> _composeARVisualFrame({
    required ui.Image cameraImage,
    required ui.Image overlayImage,
  }) async {
    final width = overlayImage.width;
    final height = overlayImage.height;
    final outputRect = Offset.zero & Size(width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final sourceSize = Size(
      cameraImage.width.toDouble(),
      cameraImage.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.cover, sourceSize, outputRect.size);
    final sourceRect =
        Alignment.center.inscribe(fitted.source, Offset.zero & sourceSize);
    final destinationRect =
        Alignment.center.inscribe(fitted.destination, outputRect);

    canvas
      ..drawImageRect(cameraImage, sourceRect, destinationRect, Paint())
      ..drawImageRect(
        overlayImage,
        Rect.fromLTWH(
          0,
          0,
          overlayImage.width.toDouble(),
          overlayImage.height.toDouble(),
        ),
        outputRect,
        Paint(),
      );
    final picture = recorder.endRecording();
    try {
      return picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  Future<void> _toggleARRecording() async {
    final state = ref.read(arViewerCaptureProvider);
    if (state.recordingState == ARRecordingState.recording ||
        state.recordingState == ARRecordingState.paused) {
      await _stopARRecording();
      return;
    }
    if (state.recordingState != ARRecordingState.idle) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _captureController.startRecording(
        config: _screenRecordingConfig,
        frameSource: _captureARVisualFrame,
      );
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('AR screen recording started')),
        );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('AR screen recording failed: $error')),
        );
    }
  }

  Future<void> _pauseARRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _captureController.pauseRecording();
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('AR screen recording paused')),
        );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('AR screen recording pause failed: $error')),
        );
    }
  }

  Future<void> _resumeARRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _captureController.resumeRecording();
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('AR screen recording resumed')),
        );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('AR screen recording resume failed: $error')),
        );
    }
  }

  Future<void> _stopARRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final recording = await _captureController.stopRecording();
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              recording.succeeded
                  ? 'AR screen recording staged for publishing'
                  : recording.result.errorMessage ??
                      'AR screen recording not saved',
            ),
          ),
        );
      final filePath = recording.result.filePath;
      if (recording.succeeded && filePath != null) {
        await _refreshViewerPoseFromDeviceSensors();
        if (!mounted) {
          return;
        }
        final capturedAt = DateTime.now().toUtc();
        ref.read(captureSessionProvider.notifier).stageARRecording(
              capturedAt: capturedAt,
              filePath: filePath,
              duration: recording.result.duration,
              frameCount: recording.result.frameCount,
              targetFps: _screenRecordingConfig.fps,
              videoBitrateKbps: _screenRecordingConfig.videoBitrateKbps,
              outputFormat: _screenRecordingConfig.outputFormat,
              includesUIOverlay: _screenRecordingConfig.includeUIOverlay,
              includesAudio: _screenRecordingConfig.includeAudio,
              fileSizeBytes: recording.result.fileSizeBytes,
              arDiagnostics: _captureDiagnosticsSnapshot(capturedAt),
            );
        await _openPublishAndFocusPublishedMemory();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('AR screen recording stop failed: $error')),
        );
    }
  }

  Future<void> _cancelARRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _captureController.cancelRecording();
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('AR screen recording discarded')),
        );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('AR screen recording cancel failed: $error')),
        );
    }
  }

  Map<String, Object?> _captureDiagnosticsSnapshot(DateTime capturedAt) {
    final diagnostics = ref.read(arMemorySceneDiagnosticsProvider);
    final unsupportedFeatureKeys =
        diagnostics.unsupportedSessionFeatureKeys.toList()..sort();
    final sessionReadiness = diagnostics.sessionReadiness;
    final nativePlacementReadiness = diagnostics.nativePlacementReadiness;
    final sessionHealthAssessment = diagnostics.sessionHealthAssessment;
    final sessionDiagnosticsReport = diagnostics.sessionDiagnosticsReport;
    final captureState = ref.read(arViewerCaptureProvider);
    final captureCapability = captureState.captureCapability;
    final latestReportDiff = _latestSessionDiagnosticsReportDiff(diagnostics);
    final captureReadinessTrend = _captureReadinessTrend(
      diagnostics,
      captureState,
    );
    return ARCaptureDiagnostics(
      capturedAt: capturedAt,
      source: 'jezaku_ar_viewer',
      sessionId: diagnostics.sessionId,
      sessionStartedAt: diagnostics.sessionStartedAt,
      lastSyncedAt: diagnostics.lastSyncedAt,
      hudStatusLabel: diagnostics.hudStatusLabel,
      detailStatusLabel: diagnostics.detailStatusLabel,
      syncStatusLabel: diagnostics.syncStatusLabel,
      sessionHealthStatusLabel: diagnostics.sessionHealthStatusLabel,
      sessionReadinessLabel: diagnostics.sessionReadinessLabel,
      nativePlacementStatusLabel: diagnostics.nativePlacementStatusLabel,
      cloudAnchorStatusLabel: diagnostics.cloudAnchorStatusLabel,
      cloudAnchorsEnabled: diagnostics.cloudAnchorsEnabled,
      activeMemoryCount: diagnostics.activeMemoryCount,
      sceneChangeCount: diagnostics.sceneChangeCount,
      hasNativeSceneFailure: diagnostics.hasNativeSceneFailure,
      hasCloudAnchorFailures: diagnostics.hasCloudAnchorFailures,
      unsupportedSessionFeatureKeys: unsupportedFeatureKeys,
      nativeSceneFailureMessage: diagnostics.nativeSceneFailureMessage,
      sessionReadiness: sessionReadiness,
      nativePlacementReadiness: nativePlacementReadiness,
      sessionHealthAssessment: sessionHealthAssessment,
      captureCapability: captureCapability,
      extra: <String, Object?>{
        if (sessionDiagnosticsReport != null)
          'sessionDiagnosticsReport': sessionDiagnosticsReport.toSyncableMap(),
        if (latestReportDiff != null)
          'sessionDiagnosticsReportDiff': latestReportDiff.toMap(),
        if (captureReadinessTrend != null)
          'captureReadinessTrendLabel': captureReadinessTrend.label,
        'runtimeDiagnosticsStatusLabel':
            diagnostics.runtimeDiagnosticsStatusLabel,
        'runtimeDiagnosticsDetailLabel':
            diagnostics.runtimeDiagnosticsDetailLabel,
        'hasRuntimeDiagnosticsIssue': diagnostics.hasRuntimeDiagnosticsIssue,
        if (diagnostics.runtimeDiagnosticsCode != null)
          'runtimeDiagnosticsCode': diagnostics.runtimeDiagnosticsCode,
        if (diagnostics.runtimeDiagnosticsSource != null)
          'runtimeDiagnosticsSource': diagnostics.runtimeDiagnosticsSource,
        if (diagnostics.runtimeDiagnosticsBackendLabel != null)
          'runtimeDiagnosticsBackendLabel':
              diagnostics.runtimeDiagnosticsBackendLabel,
        if (diagnostics.runtimeDiagnosticsGuidanceLabel != null)
          'runtimeDiagnosticsGuidanceLabel':
              diagnostics.runtimeDiagnosticsGuidanceLabel,
        if (diagnostics.hasModelPreflight)
          'modelPreflight': diagnostics.modelPreflight.toMap(),
      },
    ).toMap();
  }

  IconData _sceneDiagnosticsIcon(ARMemorySceneDiagnostics diagnostics) {
    if (diagnostics.hasNativeSceneFailure) {
      return Icons.error_outline;
    }
    if (diagnostics.hasCloudAnchorFailures) {
      return Icons.warning_amber;
    }
    if (diagnostics.hasSessionConfigDowngrades) {
      return Icons.tune;
    }
    if (diagnostics.hasCloudAnchorRetryScheduled) {
      return Icons.sync;
    }
    if (diagnostics.hasSyncedScene) {
      return Icons.view_in_ar;
    }
    return Icons.hourglass_empty;
  }

  Color _sceneDiagnosticsColor(ARMemorySceneDiagnostics diagnostics) {
    if (diagnostics.hasNativeSceneFailure) {
      return Colors.redAccent.shade100;
    }
    if (diagnostics.hasCloudAnchorFailures) {
      return Colors.redAccent.shade100;
    }
    if (diagnostics.hasSessionConfigDowngrades) {
      return Colors.amberAccent.shade100;
    }
    if (diagnostics.hasCloudAnchorRetryScheduled) {
      return Colors.blueAccent.shade100;
    }
    if (diagnostics.hasSyncedScene) {
      return Colors.cyanAccent.shade100;
    }
    return Colors.white70;
  }

  IconData _sessionHealthIcon(ARMemorySceneDiagnostics diagnostics) {
    final assessment = diagnostics.sessionHealthAssessment;
    if (assessment == null) {
      return Icons.sensors_off;
    }
    if (assessment.hasIssue(ARSessionHealthIssue.noCameraFrame)) {
      return Icons.sensors_off;
    }
    if (assessment.hasIssue(ARSessionHealthIssue.sessionStopped)) {
      return Icons.portable_wifi_off;
    }
    if (assessment.hasIssue(ARSessionHealthIssue.sessionPaused)) {
      return Icons.pause_circle_outline;
    }
    if (assessment.severity == ARSessionHealthSeverity.warning) {
      return Icons.warning_amber;
    }
    return Icons.sensors;
  }

  Color _sessionHealthColor(ARMemorySceneDiagnostics diagnostics) {
    final assessment = diagnostics.sessionHealthAssessment;
    if (assessment == null) {
      return Colors.white70;
    }
    return switch (assessment.severity) {
      ARSessionHealthSeverity.good => Colors.greenAccent.shade100,
      ARSessionHealthSeverity.warning => Colors.amberAccent.shade100,
      ARSessionHealthSeverity.blocked => assessment.hasIssue(
          ARSessionHealthIssue.sessionStopped,
        )
            ? Colors.redAccent.shade100
            : Colors.amberAccent.shade100,
    };
  }

  List<Widget> _capabilityHudPills(
    AsyncValue<JejakuARSessionPlan> arSessionPlan,
    ARMemorySceneDiagnostics sceneDiagnostics,
  ) {
    return arSessionPlan.when(
      data: (plan) {
        final capabilities = plan.capabilities;
        final placementReadiness = sceneDiagnostics.nativePlacementReadiness;
        final isPlacementPaused = capabilities.canPlaceMemories &&
            placementReadiness != null &&
            !placementReadiness.canPlaceAnchors;
        final placementLabel = isPlacementPaused
            ? 'Place paused'
            : capabilities.usesNativeGeospatial
                ? 'Geo AR'
                : capabilities.canPlaceMemories
                    ? 'Local AR'
                    : 'AR off';
        final placementIcon = isPlacementPaused
            ? Icons.motion_photos_pause_outlined
            : capabilities.usesNativeGeospatial
                ? Icons.public
                : capabilities.canPlaceMemories
                    ? Icons.map_outlined
                    : Icons.portable_wifi_off;
        final placementColor = isPlacementPaused
            ? _sessionHealthColor(sceneDiagnostics)
            : capabilities.canPlaceMemories
                ? Colors.cyanAccent.shade100
                : Colors.white70;
        final placementTooltip =
            isPlacementPaused ? placementReadiness.detailLabel : null;
        final recordingLabel = capabilities.recordingMode ==
                JejakuARRecordingMode.nativeEncode
            ? 'Screen rec'
            : capabilities.recordingMode == JejakuARRecordingMode.dartFallback
                ? 'Screen fallback'
                : 'No rec';
        final recordingTooltip = capabilities.recordingMode ==
                JejakuARRecordingMode.nativeEncode
            ? 'Native MP4 screen recording with AR visual overlay'
            : capabilities.recordingMode == JejakuARRecordingMode.dartFallback
                ? 'Dart fallback screen recording with AR visual overlay'
                : null;

        final downgradeLabels = plan.unsupportedFeatureLabels;
        final downgradeTooltip = downgradeLabels.isEmpty
            ? null
            : 'Disabled native features: ${downgradeLabels.join(', ')}';

        return [
          _HudPill(
            icon: placementIcon,
            label: placementLabel,
            color: placementColor,
            tooltip: placementTooltip,
          ),
          _HudPill(
            icon: Icons.videocam_outlined,
            label: recordingLabel,
            color: capabilities.canRecord
                ? Colors.greenAccent.shade100
                : Colors.white70,
            tooltip: recordingTooltip,
          ),
          if (plan.hasNativeDowngrades)
            _HudPill(
              icon: Icons.tune,
              label: 'AR limited',
              color: Colors.amberAccent.shade100,
              tooltip: downgradeTooltip,
            ),
        ];
      },
      error: (_, __) => [
        _HudPill(
          icon: Icons.map_outlined,
          label: 'Local AR',
          color: Colors.cyanAccent.shade100,
        ),
        const _HudPill(
          icon: Icons.videocam_outlined,
          label: 'No rec',
          color: Colors.white70,
        ),
      ],
      loading: () => [
        _HudPill(
          icon: Icons.sensors,
          label: 'AR check',
          color: Colors.blueAccent.shade100,
        ),
        _HudPill(
          icon: Icons.videocam_outlined,
          label: 'Rec check',
          color: Colors.blueAccent.shade100,
        ),
      ],
    );
  }

  void _showSceneDiagnosticsSheet(
    BuildContext context,
    ARMemorySceneDiagnostics diagnostics,
    List<ARMemoryProjection> anchors, {
    ARCaptureDiagnostics? latestCaptureDiagnostics,
  }) {
    final cloudAnchorIssues = diagnostics.cloudAnchorIssuesFor(
      anchors.map((anchor) => anchor.memory),
    );
    final anchorMemoryIds = {
      for (final anchor in anchors) anchor.memory.id,
    };
    final latestCaptureSurfaceLabel = _captureDiagnosticsExtraString(
      latestCaptureDiagnostics,
      'localSurfacePoseLabel',
    );
    final latestCaptureDedicatedLabels = <String?>{
      latestCaptureDiagnostics?.captureCapabilityLabel,
      latestCaptureDiagnostics?.captureReadinessGuidanceLabel,
    };
    final latestCaptureDetailLabels = latestCaptureDiagnostics?.metadataLabels
            .skip(1)
            .where((label) => !latestCaptureDedicatedLabels.contains(label))
            .take(4)
            .toList() ??
        const <String>[];
    final latestCaptureSessionDiagnosticsReport =
        _captureSessionDiagnosticsReport(latestCaptureDiagnostics);
    final latestCaptureSessionDiagnosticsLatestWarning =
        latestCaptureSessionDiagnosticsReport?.latestWarning;
    final sessionDiagnosticsReport = diagnostics.sessionDiagnosticsReport;
    final sessionDiagnosticsReportFacetLabels = sessionDiagnosticsReport
            ?.queryResult
            .facetLabels(limitPerKind: 2)
            .take(3)
            .toList() ??
        const <String>[];
    final sessionDiagnosticsLatestWarning =
        sessionDiagnosticsReport?.latestWarning;
    final sessionDiagnosticsHistoryReports = diagnostics
        .sessionDiagnosticsReportHistory.reversed
        .take(3)
        .toList(growable: false);
    final sessionDiagnosticsLatestDiff =
        _latestSessionDiagnosticsReportDiff(diagnostics);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Native scene diagnostics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close diagnostics',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        _sceneDiagnosticsIcon(diagnostics),
                        size: 16,
                      ),
                      label: Text(diagnostics.hudStatusLabel),
                      backgroundColor: _sceneDiagnosticsColor(diagnostics),
                    ),
                    const SizedBox(height: 8),
                    _DiagnosticsRow(
                      icon: Icons.timeline,
                      label: 'Session',
                      value: diagnostics.sessionStatusLabel,
                    ),
                    _DiagnosticsRow(
                      icon: _sessionHealthIcon(diagnostics),
                      label: 'Tracking',
                      value: diagnostics.sessionHealthStatusLabel,
                      valueColor: diagnostics.hasSessionHealthIssue
                          ? _sessionHealthColor(diagnostics)
                          : null,
                    ),
                    if (diagnostics.sessionReadiness != null)
                      _DiagnosticsRow(
                        icon: Icons.fact_check_outlined,
                        label: 'Readiness',
                        value: diagnostics.sessionReadinessLabel,
                        valueColor: diagnostics.isSessionReadyForPlacement
                            ? null
                            : _sessionHealthColor(diagnostics),
                      ),
                    _DiagnosticsRow(
                      icon: Icons.add_location_alt_outlined,
                      label: 'Placement',
                      value: diagnostics.nativePlacementStatusLabel,
                      valueColor: diagnostics.isNativePlacementDeferred
                          ? _sessionHealthColor(diagnostics)
                          : null,
                    ),
                    if (diagnostics.hasSessionHealthIssue &&
                        diagnostics.sessionHealthGuidance != null)
                      _DiagnosticsRow(
                        icon: Icons.tips_and_updates_outlined,
                        label: 'Guidance',
                        value: diagnostics.sessionHealthGuidanceLabel,
                        valueColor: _sessionHealthColor(diagnostics),
                      ),
                    _DiagnosticsRow(
                      icon: Icons.tune,
                      label: 'Config',
                      value: diagnostics.sessionConfigStatusLabel,
                      valueColor: diagnostics.hasSessionConfigDowngrades
                          ? Colors.amberAccent.shade100
                          : null,
                    ),
                    _DiagnosticsRow(
                      icon: Icons.sensors,
                      label: 'Sync',
                      value: diagnostics.syncStatusLabel,
                      valueColor: diagnostics.hasNativeSceneFailure
                          ? Colors.redAccent.shade100
                          : null,
                    ),
                    if (diagnostics.hasNativeSceneFailure)
                      _DiagnosticsRow(
                        icon: Icons.error_outline,
                        label: 'Native error',
                        value: diagnostics.nativeSceneFailureMessage ??
                            'Unknown native scene sync error',
                        valueColor: Colors.redAccent.shade100,
                      ),
                    _DiagnosticsRow(
                      icon: Icons.view_in_ar,
                      label: 'Scene',
                      value: diagnostics.sceneChangeLabel,
                    ),
                    if (diagnostics.hasModelPreflight)
                      _DiagnosticsRow(
                        icon: Icons.view_in_ar_outlined,
                        label: 'Models',
                        value: diagnostics.modelPreflightStatusLabel,
                        valueColor: diagnostics.hasModelPreflightIssues
                            ? Colors.amberAccent.shade100
                            : null,
                      ),
                    if (diagnostics.modelPreflight.hasRevalidatedModels)
                      _DiagnosticsRow(
                        icon: Icons.cached_outlined,
                        label: 'Model net',
                        value: _modelPreflightRevalidationLabel(diagnostics),
                      ),
                    if (diagnostics.modelPreflight.hasStaleCacheFallbacks)
                      _DiagnosticsRow(
                        icon: Icons.cloud_off_outlined,
                        label: 'Model cache',
                        value: _modelPreflightStaleCacheFallbackLabel(
                          diagnostics,
                        ),
                        valueColor: Colors.amberAccent.shade100,
                      ),
                    _DiagnosticsRow(
                      icon: Icons.cloud_queue,
                      label: 'Cloud',
                      value: diagnostics.cloudAnchorStatusLabel,
                      valueColor: diagnostics.hasCloudAnchorFailures
                          ? Colors.redAccent.shade100
                          : null,
                    ),
                    _DiagnosticsRow(
                      icon: Icons.sync,
                      label: 'Retry',
                      value: diagnostics.retryStatusLabel,
                    ),
                    _DiagnosticsRow(
                      icon: Icons.event_available,
                      label: 'Care',
                      value: diagnostics.maintenanceStatusLabel,
                    ),
                    if (sessionDiagnosticsReport != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Live session report',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DiagnosticsRow(
                        icon: Icons.monitor_heart_outlined,
                        label: 'Report',
                        value: sessionDiagnosticsReport.statusLabel,
                        valueColor: _sessionDiagnosticsReportWarningColor(
                          sessionDiagnosticsReport,
                        ),
                      ),
                      _DiagnosticsRow(
                        icon: Icons.memory_outlined,
                        label: 'Runtime',
                        value: diagnostics.runtimeDiagnosticsStatusLabel,
                        valueColor: diagnostics.hasRuntimeDiagnosticsIssue
                            ? _sessionDiagnosticsReportWarningColor(
                                sessionDiagnosticsReport,
                              )
                            : null,
                      ),
                      if (diagnostics.hasRuntimeDiagnosticsIssue)
                        _DiagnosticsRow(
                          icon: Icons.info_outline,
                          label: 'Runtime detail',
                          value: diagnostics.runtimeDiagnosticsDetailLabel,
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            sessionDiagnosticsReport,
                          ),
                        ),
                      if (diagnostics.runtimeDiagnosticsGuidanceLabel != null)
                        _DiagnosticsRow(
                          icon: Icons.tips_and_updates_outlined,
                          label: 'Runtime action',
                          value: diagnostics.runtimeDiagnosticsGuidanceLabel!,
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            sessionDiagnosticsReport,
                          ),
                        ),
                      _DiagnosticsRow(
                        icon: Icons.event_note_outlined,
                        label: 'Events',
                        value: _sessionDiagnosticsReportEventLabel(
                          sessionDiagnosticsReport,
                        ),
                      ),
                      _DiagnosticsRow(
                        icon: Icons.schedule,
                        label: 'Generated',
                        value: _formatDiagnosticsTime(
                          sessionDiagnosticsReport.generatedAt,
                        ),
                      ),
                      if (diagnostics.hasSessionDiagnosticsReportHistory)
                        _DiagnosticsRow(
                          icon: Icons.history,
                          label: 'History',
                          value: diagnostics
                              .sessionDiagnosticsReportHistoryStatusLabel,
                        ),
                      if (sessionDiagnosticsLatestDiff != null &&
                          sessionDiagnosticsLatestDiff.hasChanges)
                        _DiagnosticsRow(
                          icon: Icons.compare_arrows,
                          label: 'Trend',
                          value: sessionDiagnosticsLatestDiff.statusLabel,
                          valueColor: _sessionDiagnosticsReportDiffColor(
                            sessionDiagnosticsLatestDiff,
                          ),
                        ),
                      for (var index = 0;
                          index < sessionDiagnosticsHistoryReports.length;
                          index += 1)
                        _DiagnosticsRow(
                          icon: Icons.timeline,
                          label: _sessionDiagnosticsHistoryRowLabel(index),
                          value: _sessionDiagnosticsHistoryReportLabel(
                            sessionDiagnosticsHistoryReports[index],
                          ),
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            sessionDiagnosticsHistoryReports[index],
                          ),
                        ),
                      if (sessionDiagnosticsLatestWarning != null)
                        _DiagnosticsRow(
                          icon: Icons.warning_amber,
                          label: 'Latest warning',
                          value: sessionDiagnosticsLatestWarning.displayLabel,
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            sessionDiagnosticsReport,
                          ),
                        ),
                      for (final label in sessionDiagnosticsReportFacetLabels)
                        _DiagnosticsRow(
                          icon: Icons.label_outline,
                          label: 'Facet',
                          value: label,
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey(
                            'ar_scene_diagnostics_session_report_copy_button',
                          ),
                          onPressed: () => _copySessionDiagnosticsReport(
                            sessionDiagnosticsReport,
                          ),
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Copy session report'),
                        ),
                      ),
                    ],
                    if (latestCaptureDiagnostics != null) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Last capture diagnostics',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DiagnosticsRow(
                        icon: Icons.add_a_photo_outlined,
                        label: 'Capture',
                        value: latestCaptureDiagnostics.summaryLabel,
                        valueColor: latestCaptureDiagnostics
                                    .hasNativeSceneFailure ||
                                latestCaptureDiagnostics.hasCloudAnchorFailures
                            ? Colors.redAccent.shade100
                            : null,
                      ),
                      _DiagnosticsRow(
                        icon: Icons.schedule,
                        label: 'Captured',
                        value: _formatDiagnosticsTime(
                          latestCaptureDiagnostics.capturedAt,
                        ),
                      ),
                      if (latestCaptureDiagnostics.captureCapabilityLabel !=
                          null)
                        _DiagnosticsRow(
                          icon: Icons.verified_outlined,
                          label: 'Capture gate',
                          value:
                              latestCaptureDiagnostics.captureCapabilityLabel!,
                        ),
                      if (latestCaptureDiagnostics
                              .captureReadinessGuidanceLabel !=
                          null)
                        _DiagnosticsRow(
                          icon: Icons.tips_and_updates_outlined,
                          label: 'Capture hint',
                          value: latestCaptureDiagnostics
                              .captureReadinessGuidanceLabel!,
                        ),
                      _DiagnosticsRow(
                        icon: Icons.input,
                        label: 'Source',
                        value: latestCaptureDiagnostics.source,
                      ),
                      if (latestCaptureSurfaceLabel != null)
                        _DiagnosticsRow(
                          icon: Icons.wallpaper_outlined,
                          label: 'Surface',
                          value: latestCaptureSurfaceLabel,
                        ),
                      for (final label in latestCaptureDetailLabels)
                        _DiagnosticsRow(
                          icon: Icons.label_outline,
                          label: 'Detail',
                          value: label,
                        ),
                      if (latestCaptureSessionDiagnosticsReport != null) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Captured session report',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DiagnosticsRow(
                          icon: Icons.monitor_heart_outlined,
                          label: 'Report',
                          value:
                              latestCaptureSessionDiagnosticsReport.statusLabel,
                          valueColor: _sessionDiagnosticsReportWarningColor(
                            latestCaptureSessionDiagnosticsReport,
                          ),
                        ),
                        _DiagnosticsRow(
                          icon: Icons.event_note_outlined,
                          label: 'Events',
                          value: _sessionDiagnosticsReportEventLabel(
                            latestCaptureSessionDiagnosticsReport,
                          ),
                        ),
                        _DiagnosticsRow(
                          icon: Icons.schedule,
                          label: 'Generated',
                          value: _formatDiagnosticsTime(
                            latestCaptureSessionDiagnosticsReport.generatedAt,
                          ),
                        ),
                        if (latestCaptureSessionDiagnosticsLatestWarning !=
                            null)
                          _DiagnosticsRow(
                            icon: Icons.warning_amber,
                            label: 'Latest warning',
                            value: latestCaptureSessionDiagnosticsLatestWarning
                                .displayLabel,
                            valueColor: _sessionDiagnosticsReportWarningColor(
                              latestCaptureSessionDiagnosticsReport,
                            ),
                          ),
                      ],
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey(
                            'ar_scene_diagnostics_capture_copy_button',
                          ),
                          onPressed: () => _copyCaptureDiagnostics(
                            latestCaptureDiagnostics,
                          ),
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Copy capture diagnostics'),
                        ),
                      ),
                    ],
                    if (cloudAnchorIssues.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Affected anchors',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          for (final issue in cloudAnchorIssues.take(6))
                            _DiagnosticsIssueTile(
                              issue: issue,
                              onTap: anchorMemoryIds.contains(issue.memoryId)
                                  ? () {
                                      Navigator.pop(context);
                                      _recenterOnMemoryId(
                                        anchors,
                                        issue.memoryId,
                                      );
                                    }
                                  : null,
                            ),
                        ],
                      ),
                      if (cloudAnchorIssues.length > 6) ...[
                        const SizedBox(height: 8),
                        Text(
                          '+${cloudAnchorIssues.length - 6} more affected',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey(
                          'ar_scene_diagnostics_bundle_copy_button',
                        ),
                        onPressed: () => _copySceneDiagnosticsBundle(
                          diagnostics,
                          latestCaptureDiagnostics: latestCaptureDiagnostics,
                        ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Copy diagnostics bundle'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey(
                          'ar_scene_diagnostics_copy_button',
                        ),
                        onPressed: () => _copySceneDiagnostics(diagnostics),
                        icon: const Icon(Icons.content_copy),
                        label: const Text('Copy diagnostics'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey(
                          'ar_scene_diagnostics_refresh_button',
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _refreshNativeScene();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(diagnostics.refreshActionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _copySceneDiagnosticsBundle(
    ARMemorySceneDiagnostics diagnostics, {
    ARCaptureDiagnostics? latestCaptureDiagnostics,
  }) async {
    final bundle = ARSceneDiagnosticsExportBundle.fromDiagnostics(
      sceneDiagnostics: diagnostics,
      latestCaptureDiagnostics: latestCaptureDiagnostics,
    );
    final payload = const JsonEncoder.withIndent('  ').convert(
      bundle.toMap(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    ref.read(arSceneDiagnosticsExportBundleCacheStoreProvider).saveBundle(
          bundle,
        );
    ref.invalidate(arSceneDiagnosticsExportBundleCacheProvider);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR diagnostics bundle copied')),
      );
  }

  Future<void> _copySceneDiagnostics(
    ARMemorySceneDiagnostics diagnostics,
  ) async {
    final payload = const JsonEncoder.withIndent('  ').convert(
      diagnostics.toMap(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR diagnostics copied')),
      );
  }

  Future<void> _copyCaptureDiagnostics(
    ARCaptureDiagnostics diagnostics,
  ) async {
    final payload = const JsonEncoder.withIndent('  ').convert(
      diagnostics.toSyncableMap() ?? diagnostics.toMap(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR capture diagnostics copied')),
      );
  }

  Future<void> _copySessionDiagnosticsReport(
    ARDiagnosticsReport report,
  ) async {
    final payload = const JsonEncoder.withIndent('  ').convert(
      report.toSyncableMap(),
    );
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('AR session report copied')),
      );
  }

  String _formatDiagnosticsTime(DateTime timestamp) {
    final utc = timestamp.toUtc();
    return '${utc.year}-${_twoDigits(utc.month)}-${_twoDigits(utc.day)} '
        '${_twoDigits(utc.hour)}:${_twoDigits(utc.minute)} UTC';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _sessionDiagnosticsReportEventLabel(ARDiagnosticsReport report) {
    final timelineCount = report.timelineEventCount;
    final matchCount = report.matchCount;
    final timelineLabel = timelineCount == 1 ? 'event' : 'events';
    if (!report.query.hasFilters || timelineCount == matchCount) {
      return '$timelineCount timeline $timelineLabel';
    }
    final matchLabel = matchCount == 1 ? 'match' : 'matches';
    return '$matchCount $matchLabel from $timelineCount timeline $timelineLabel';
  }

  String _sessionDiagnosticsHistoryRowLabel(int index) {
    return switch (index) {
      0 => 'Latest',
      1 => 'Previous',
      _ => 'Earlier',
    };
  }

  String _sessionDiagnosticsHistoryReportLabel(ARDiagnosticsReport report) {
    final labels = <String>[
      _formatDiagnosticsTime(report.generatedAt),
      report.statusLabel,
      _sessionDiagnosticsReportEventLabel(report),
    ];
    final latestWarning = report.latestWarning?.displayLabel;
    if (latestWarning != null && latestWarning.isNotEmpty) {
      labels.add(latestWarning);
    }
    return labels.join(' - ');
  }

  String _modelPreflightRevalidationLabel(
    ARMemorySceneDiagnostics diagnostics,
  ) {
    final modelPreflight = diagnostics.modelPreflight;
    final count = modelPreflight.revalidatedCount;
    final countLabel = count == 1 ? '1 network model' : '$count network models';
    final ids = modelPreflight.revalidatedMemoryIds.toList()..sort();
    if (ids.isEmpty) {
      return '$countLabel revalidated';
    }
    return '$countLabel revalidated: ${ids.join(', ')}';
  }

  String _modelPreflightStaleCacheFallbackLabel(
    ARMemorySceneDiagnostics diagnostics,
  ) {
    final modelPreflight = diagnostics.modelPreflight;
    final count = modelPreflight.staleCacheFallbackCount;
    final countLabel = count == 1 ? '1 network model' : '$count network models';
    final ids = modelPreflight.staleCacheFallbackMemoryIds.toList()..sort();
    if (ids.isEmpty) {
      return '$countLabel used stale cache';
    }
    return '$countLabel used stale cache: ${ids.join(', ')}';
  }

  ARDiagnosticsReportDiff? _latestSessionDiagnosticsReportDiff(
    ARMemorySceneDiagnostics diagnostics,
  ) {
    final history = diagnostics.sessionDiagnosticsReportHistory;
    if (history.length < 2) {
      return null;
    }
    return history.last.diffFrom(history[history.length - 2]);
  }

  Color? _sessionDiagnosticsReportWarningColor(ARDiagnosticsReport report) {
    return switch (report.latestWarning?.severity) {
      ARSessionHealthSeverity.blocked => Colors.redAccent.shade100,
      ARSessionHealthSeverity.warning => Colors.amberAccent.shade100,
      _ => null,
    };
  }

  Color? _sessionDiagnosticsReportDiffColor(ARDiagnosticsReportDiff diff) {
    return switch (diff.direction) {
      ARDiagnosticsReportDiffDirection.worsened => Colors.redAccent.shade100,
      ARDiagnosticsReportDiffDirection.mixed => Colors.amberAccent.shade100,
      ARDiagnosticsReportDiffDirection.improved => Colors.greenAccent.shade100,
      _ => null,
    };
  }

  _CaptureReadinessTrend? _captureReadinessTrend(
    ARMemorySceneDiagnostics diagnostics,
    ARViewerCaptureState captureState,
  ) {
    if (!captureState.hasController || !captureState.canCaptureSnapshot) {
      return null;
    }
    final diff = _latestSessionDiagnosticsReportDiff(diagnostics);
    if (diff == null || !diff.hasChanges) {
      return null;
    }
    if (captureState.activeReadiness?.isBlocked == true) {
      return null;
    }

    final healthDelta = diff.sessionHealthDelta;
    if (healthDelta.isBetter && captureState.hasReadinessWarning) {
      final readinessLabel =
          healthDelta.current?.readiness.label ?? diff.statusLabel;
      return _CaptureReadinessTrend(
        label: 'AR improving: $readinessLabel',
        color: Colors.greenAccent.shade100,
      );
    }
    if (diff.direction == ARDiagnosticsReportDiffDirection.improved &&
        captureState.hasReadinessWarning) {
      return _CaptureReadinessTrend(
        label: 'AR improving: ${diff.statusLabel}',
        color: Colors.greenAccent.shade100,
      );
    }
    final shouldWarn =
        diff.direction == ARDiagnosticsReportDiffDirection.worsened ||
            (diff.direction == ARDiagnosticsReportDiffDirection.mixed &&
                diff.hasNewWarnings);
    if (!shouldWarn) {
      return null;
    }
    final hasBlockedWarning = diff.blockedDelta > 0 ||
        diff.newWarnings.any((event) => event.isBlocked);
    return _CaptureReadinessTrend(
      label: 'Capture caution: ${diff.statusLabel}',
      color: hasBlockedWarning
          ? Colors.redAccent.shade100
          : Colors.amberAccent.shade100,
    );
  }

  String? _captureDiagnosticsExtraString(
    ARCaptureDiagnostics? diagnostics,
    String key,
  ) {
    final value = diagnostics?.extra[key];
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  ARDiagnosticsReport? _captureSessionDiagnosticsReport(
    ARCaptureDiagnostics? diagnostics,
  ) {
    return ARDiagnosticsReport.tryFromMap(
      diagnostics?.extra['sessionDiagnosticsReport'],
    );
  }

  void _recenterOnNearest(List<ARMemoryProjection> anchors) {
    final focusedAnchor = _focusedAnchor(anchors);
    if (focusedAnchor != null) {
      _recenterOnAnchor(focusedAnchor);
      return;
    }
    if (anchors.isEmpty) {
      return;
    }
    _recenterOnAnchor(anchors.first);
  }

  void _recenterOnAnchor(ARMemoryProjection anchor) {
    setState(() {
      _focusedMemoryId = anchor.memory.id;
      _headingDegrees = anchor.projection.bearingDegrees;
    });
    _nativeSessionPlacementCache.remove(anchor.memory.id);
    _nativeSceneFingerprint = null;
    _scheduleNativeSceneSync();
    _trackTrailFocus(anchor.memory.id);
  }

  void _recenterOnMemoryId(
    List<ARMemoryProjection> anchors,
    String memoryId,
  ) {
    for (final anchor in anchors) {
      if (anchor.memory.id == memoryId) {
        _recenterOnAnchor(anchor);
        return;
      }
    }
    setState(() => _focusedMemoryId = memoryId);
    _trackTrailFocus(memoryId);
  }

  void _showAnchorSheet(
    BuildContext context,
    List<ARMemoryProjection> anchors, {
    required String? focusedMemoryId,
    required bool isWallTrail,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.56,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isWallTrail
                              ? 'Wall trail stops'
                              : 'Projected anchors',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isWallTrail)
                        Chip(
                          key: const ValueKey('ar_trail_sheet_count'),
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.route_outlined, size: 16),
                          label: Text('${anchors.length} stops'),
                          backgroundColor: Colors.cyanAccent.shade100,
                        ),
                    ],
                  ),
                  if (isWallTrail && _journeyTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _journeyTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (var index = 0; index < anchors.length; index++)
                          _ProjectedAnchorTile(
                            key: ValueKey(
                              'ar_anchor_sheet_tile_${anchors[index].memory.id}',
                            ),
                            anchor: anchors[index],
                            isFocused:
                                anchors[index].memory.id == focusedMemoryId,
                            stopNumber: isWallTrail ? index + 1 : null,
                            onFocus: () {
                              Navigator.pop(context);
                              _recenterOnAnchor(anchors[index]);
                            },
                          ),
                      ],
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

  List<ARMemoryProjection> _sheetAnchors(List<ARMemoryProjection> anchors) {
    final memoryIds = _journeyMemoryIds;
    if (memoryIds.isEmpty) {
      return anchors;
    }

    final anchorsById = <String, ARMemoryProjection>{
      for (final anchor in anchors) anchor.memory.id: anchor,
    };

    return [
      for (final memoryId in memoryIds)
        if (anchorsById[memoryId] != null) anchorsById[memoryId]!,
    ];
  }

  Map<String, int> _trailStopNumbers() {
    final memoryIds = _journeyMemoryIds;
    if (memoryIds.isEmpty) {
      return const {};
    }

    return {
      for (var index = 0; index < memoryIds.length; index++)
        memoryIds[index]: index + 1,
    };
  }

  List<ARMemoryProjection> _activeProjectedAnchors(
    List<ARMemoryProjection> anchors,
    Map<String, int> trailStopNumbers,
  ) {
    if (trailStopNumbers.isEmpty) {
      final active = anchors.take(8).toList(growable: true);
      final focusedMemoryId = _focusedMemoryId;
      if (focusedMemoryId != null &&
          !active.any((anchor) => anchor.memory.id == focusedMemoryId)) {
        for (final anchor in anchors) {
          if (anchor.memory.id == focusedMemoryId) {
            active.add(anchor);
            break;
          }
        }
      }
      return active;
    }

    final anchorsById = <String, ARMemoryProjection>{
      for (final anchor in anchors) anchor.memory.id: anchor,
    };

    return [
      for (final memoryId in _journeyMemoryIds)
        if (anchorsById[memoryId] != null) anchorsById[memoryId]!,
    ];
  }

  ARMemoryProjection? _firstMissingTrailAnchor(
    ARTrailProgress? progress,
    List<ARMemoryProjection> anchors,
  ) {
    if (progress == null) {
      return null;
    }

    final anchorsById = <String, ARMemoryProjection>{
      for (final anchor in anchors) anchor.memory.id: anchor,
    };
    for (final memoryId in progress.session.memoryIds) {
      if (!progress.completedMemoryIds.contains(memoryId)) {
        return anchorsById[memoryId];
      }
    }
    return null;
  }

  String? _missingStopSpatialLabel(ARMemoryProjection? anchor) {
    if (anchor == null) {
      return null;
    }
    return '${anchor.projection.distanceLabel} ${anchor.projection.directionLabel}';
  }

  String _poseSourceShortLabel() {
    final lastARFrameAt = _lastARCameraFrameAt;
    if (lastARFrameAt != null &&
        DateTime.now().toUtc().difference(lastARFrameAt) <
            const Duration(seconds: 2)) {
      return 'AR';
    }
    return 'GPS';
  }

  String _poseSourceDetailLabel() {
    final lastARFrameAt = _lastARCameraFrameAt;
    if (lastARFrameAt == null) {
      return 'Waiting for AR camera pose; using compass/GPS fallback.';
    }
    final ageMs = DateTime.now()
        .toUtc()
        .difference(lastARFrameAt)
        .inMilliseconds
        .clamp(0, 9999);
    if (ageMs < 2000) {
      return 'Radar heading follows ARCore camera pose.';
    }
    return 'AR camera pose stale (${ageMs}ms); using compass/GPS fallback.';
  }

  ARMemoryProjection? _focusedAnchor(List<ARMemoryProjection> anchors) {
    final focusedMemoryId = _focusedMemoryId;
    if (focusedMemoryId == null) {
      return null;
    }
    for (final anchor in anchors) {
      if (anchor.memory.id == focusedMemoryId) {
        return anchor;
      }
    }
    return null;
  }

  ARWall? _sourceWall(
    List<ARWall> walls, {
    required List<ARWall> routeWalls,
  }) {
    final sourceWallId = _sourceWallId;
    if (sourceWallId != null) {
      for (final wall in walls) {
        if (wall.id == sourceWallId) {
          return wall;
        }
      }
      return null;
    }

    final trailSession = _trailSession;
    if (trailSession == null || trailSession.source != ARTrailSource.camera) {
      return null;
    }

    return routeWalls.isEmpty ? null : routeWalls.first;
  }

  List<ARWall> _routeWalls(List<ARWall> walls) {
    final routeMemoryIds = _journeyMemoryIds.toSet();
    if (routeMemoryIds.isEmpty) {
      return const [];
    }

    final wallsByRouteCoverage = [
      for (final wall in walls)
        (
          wall: wall,
          stopCount: wall.linkedMemoryIds
              .where((memoryId) => routeMemoryIds.contains(memoryId))
              .length,
        ),
    ].where((entry) => entry.stopCount > 0).toList()
      ..sort((a, b) {
        final stopComparison = b.stopCount.compareTo(a.stopCount);
        if (stopComparison != 0) {
          return stopComparison;
        }
        return a.wall.title.compareTo(b.wall.title);
      });
    return [for (final entry in wallsByRouteCoverage) entry.wall];
  }

  List<AnchorJourneyStep> _customJourneySteps(
    List<AnchorMemory> anchors,
    JejakuGeoOrigin viewerOrigin,
  ) {
    final memoryIds = _journeyMemoryIds;
    final anchorsById = <String, AnchorMemory>{
      for (final anchor in anchors) anchor.id: anchor,
    };
    final journeyAnchors = [
      for (final memoryId in memoryIds)
        if (anchorsById[memoryId] != null) anchorsById[memoryId]!,
    ];

    return const AnchorSpatialJourneyService().stepsFor(
      anchors: journeyAnchors,
      originLatitude: viewerOrigin.latitude,
      originLongitude: viewerOrigin.longitude,
      radiusMeters: 100,
      preserveAnchorOrder: true,
    );
  }

  AnchorJourneyStep? _journeyStepFor(
    List<AnchorJourneyStep> steps,
    String memoryId,
  ) {
    for (final step in steps) {
      if (step.memory.id == memoryId) {
        return step;
      }
    }
    return null;
  }

  void _maybeApplyInitialFocus(ARMemoryProjection? focusedAnchor) {
    if (_didApplyInitialFocus || focusedAnchor == null) {
      return;
    }
    _didApplyInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _recenterOnAnchor(focusedAnchor);
    });
  }

  List<String> get _journeyMemoryIds {
    return _trailSession?.memoryIds ?? widget.journeyMemoryIds;
  }

  String? get _journeyTitle {
    return _trailSession?.title ?? widget.journeyTitle;
  }

  String? get _sourceWallId {
    return _trailSession?.sourceWallId ?? widget.sourceWallId;
  }

  ARTrailSession? _legacyTrailSession() {
    if (widget.journeyMemoryIds.isEmpty) {
      return null;
    }

    return ARTrailSession.fromMemoryIds(
      title: widget.journeyTitle ?? 'AR trail',
      memoryIds: widget.journeyMemoryIds,
      source: widget.sourceWallId == null
          ? ARTrailSource.custom
          : ARTrailSource.virtualWall,
      focusedMemoryId: widget.focusedMemoryId,
      sourceWallId: widget.sourceWallId,
    );
  }

  void _finishTrail() {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context);
    final progress = container.read(activeARTrailProgressProvider);
    if (progress == null) {
      navigator.maybePop();
      return;
    }

    final session = progress.session;
    final unlocks =
        container.read(activeARTrailProgressProvider.notifier).finish();

    showARTrailCompletionSnackBar(
      messenger: messenger,
      unlocks: unlocks,
      isSaved: container.read(savedARTrailsProvider.notifier).isSaved(session),
      onSave: () {
        final saveUnlocks =
            container.read(savedARTrailsProvider.notifier).save(session);
        showARTrailSavedSnackBar(
          messenger: messenger,
          unlocks: saveUnlocks,
          onReplay: () => navigator.pushNamed(
            AppRoutes.arViewer,
            arguments: ARViewerArgs.trail(session),
          ),
        );
      },
    );
    navigator.maybePop();
  }

  void _trackTrailFocus(String memoryId) {
    if (_isResolvingTrailLaunch) {
      return;
    }
    final trailSession = _trailSession;
    if (trailSession == null || !trailSession.memoryIds.contains(memoryId)) {
      return;
    }
    ref.read(activeARTrailProgressProvider.notifier).focusMemory(memoryId);
  }
}

bool _sameGeoOrigin(JejakuGeoOrigin left, JejakuGeoOrigin right) {
  return _geoOriginDistanceMeters(left, right) < 1.5 &&
      (left.altitudeMeters - right.altitudeMeters).abs() < 1.5;
}

double _geoOriginDistanceMeters(JejakuGeoOrigin left, JejakuGeoOrigin right) {
  const earthRadiusMeters = 6378137.0;
  final originLat = left.latitude * math.pi / 180;
  final deltaLat = (right.latitude - left.latitude) * math.pi / 180;
  final deltaLon = (right.longitude - left.longitude) * math.pi / 180;
  final east = deltaLon * math.cos(originLat) * earthRadiusMeters;
  final north = deltaLat * earthRadiusMeters;
  return math.sqrt(east * east + north * north);
}

double _headingDeltaDegrees(double from, double to) {
  return ((to - from + 540) % 360) - 180;
}

double _normalizeHeading(double headingDegrees) {
  final normalized = headingDegrees % 360;
  return normalized < 0 ? normalized + 360 : normalized;
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

class _AnchorBubble extends ConsumerWidget {
  const _AnchorBubble({
    required this.anchor,
    required this.isFocused,
    required this.stopNumber,
    required this.wallTitles,
    required this.onTap,
  });

  final ARMemoryProjection anchor;
  final bool isFocused;
  final int? stopNumber;
  final List<String> wallTitles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memory = anchor.memory;
    final projection = anchor.projection;
    final resolvedMedia = ref.watch(anchorResolvedMediaProvider(memory));
    final qualityColor = memory.needsCalibrationReview
        ? Colors.redAccent.shade100
        : _qualityColor(projection.quality);
    final stopNumber = this.stopNumber;
    final showMediaPlane =
        memory.mediaAttachment != null || wallTitles.isNotEmpty;

    return Semantics(
      button: true,
      label: stopNumber == null
          ? 'Focus ${memory.title}'
          : 'Focus ${memory.title}, stop $stopNumber',
      child: GestureDetector(
        key: ValueKey('ar_anchor_bubble_${memory.id}'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showMediaPlane) ...[
              _AnchorMediaPlane(
                anchor: anchor,
                resolvedMedia: resolvedMedia,
                wallTitles: wallTitles,
                isFocused: isFocused,
                qualityColor: qualityColor,
              ),
              const SizedBox(height: 6),
            ],
            _AnchorStatusChip(
              anchor: anchor,
              isFocused: isFocused,
              stopNumber: stopNumber,
              qualityColor: qualityColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnchorMediaPlane extends StatelessWidget {
  const _AnchorMediaPlane({
    required this.anchor,
    required this.resolvedMedia,
    required this.wallTitles,
    required this.isFocused,
    required this.qualityColor,
  });

  final ARMemoryProjection anchor;
  final AnchorResolvedMedia? resolvedMedia;
  final List<String> wallTitles;
  final bool isFocused;
  final Color qualityColor;

  @override
  Widget build(BuildContext context) {
    final memory = anchor.memory;
    final attachment = memory.mediaAttachment;
    final previewBytes = resolvedMedia?.previewBytes;
    final width = isFocused ? 218.0 : 188.0;
    final previewHeight = isFocused ? 130.0 : 108.0;

    return Container(
      key: ValueKey('ar_floating_anchor_${memory.id}'),
      width: width,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFocused ? Colors.cyanAccent.shade100 : qualityColor,
          width: isFocused ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: previewHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewBytes != null)
                  Image.memory(
                    previewBytes,
                    key: ValueKey('ar_floating_media_${memory.id}'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _AnchorMediaPlaceholder(
                        memory: memory,
                        attachment: attachment,
                      );
                    },
                  )
                else
                  _AnchorMediaPlaceholder(
                    key: ValueKey('ar_floating_media_${memory.id}'),
                    memory: memory,
                    attachment: attachment,
                  ),
                if (wallTitles.isNotEmpty)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: _AnchorWallBadge(
                      key: ValueKey('ar_floating_virtual_wall_${memory.id}'),
                      title: wallTitles.first,
                      extraCount: wallTitles.length - 1,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            child: Row(
              children: [
                Icon(
                  attachment == null
                      ? Icons.view_in_ar
                      : anchorMediaIconFor(attachment.type),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    attachment?.type.label ??
                        (wallTitles.isNotEmpty ? 'Virtual wall' : 'AR memory'),
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

class _AnchorMediaPlaceholder extends StatelessWidget {
  const _AnchorMediaPlaceholder({
    super.key,
    required this.memory,
    required this.attachment,
  });

  final AnchorMemory memory;
  final AnchorMediaAttachment? attachment;

  @override
  Widget build(BuildContext context) {
    final isRecording = attachment?.type == AnchorMediaType.arRecording;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueGrey.shade900,
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          isRecording ? Icons.video_file_outlined : Icons.photo_outlined,
          color: Colors.white70,
          size: 38,
        ),
      ),
    );
  }
}

class _AnchorWallBadge extends StatelessWidget {
  const _AnchorWallBadge({
    super.key,
    required this.title,
    required this.extraCount,
  });

  final String title;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    final label = extraCount <= 0 ? title : '$title +$extraCount';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_week, color: Colors.cyanAccent, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnchorStatusChip extends StatelessWidget {
  const _AnchorStatusChip({
    required this.anchor,
    required this.isFocused,
    required this.stopNumber,
    required this.qualityColor,
  });

  final ARMemoryProjection anchor;
  final bool isFocused;
  final int? stopNumber;
  final Color qualityColor;

  @override
  Widget build(BuildContext context) {
    final memory = anchor.memory;
    final projection = anchor.projection;
    final foreground = projection.isVisible ? Colors.black87 : Colors.white;
    final secondary = projection.isVisible
        ? Colors.black54
        : Colors.white.withValues(alpha: 0.72);

    return Container(
      width: 164,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: projection.isVisible
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFocused
              ? Colors.cyanAccent.shade100
              : projection.isVisible
                  ? qualityColor
                  : Colors.white30,
          width: isFocused ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (stopNumber == null)
                Icon(
                  isFocused
                      ? Icons.center_focus_strong
                      : memory.needsCalibrationReview
                          ? Icons.warning_amber
                          : projection.isVisible
                              ? Icons.photo
                              : projection.relativeHeadingDegrees > 0
                                  ? Icons.keyboard_arrow_right
                                  : Icons.keyboard_arrow_left,
                  color: foreground,
                  size: 16,
                )
              else
                Container(
                  key: ValueKey('ar_anchor_bubble_stop_${memory.id}'),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isFocused
                        ? Colors.cyanAccent.shade100
                        : Colors.black.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                  child: Text(
                    '$stopNumber',
                    style: TextStyle(
                      color: isFocused ? Colors.black87 : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  memory.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${projection.distanceLabel} • ${projection.directionLabel} • '
            '${memory.anchorHealthLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: secondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectedAnchorTile extends StatelessWidget {
  const _ProjectedAnchorTile({
    super.key,
    required this.anchor,
    required this.isFocused,
    required this.stopNumber,
    required this.onFocus,
  });

  final ARMemoryProjection anchor;
  final bool isFocused;
  final int? stopNumber;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final projection = anchor.projection;
    final memory = anchor.memory;
    final qualityColor = memory.needsCalibrationReview
        ? Colors.redAccent.shade100
        : _qualityColor(projection.quality);
    final stabilityLabel = memory.anchorHealthLabel;
    final stopNumber = this.stopNumber;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onFocus,
      leading: stopNumber == null
          ? Icon(
              projection.isVisible
                  ? Icons.center_focus_strong
                  : Icons.navigation,
              color: projection.isVisible ? qualityColor : Colors.white54,
            )
          : CircleAvatar(
              key: ValueKey('ar_trail_stop_marker_${memory.id}'),
              radius: 15,
              backgroundColor:
                  isFocused ? Colors.cyanAccent.shade100 : Colors.white12,
              child: Text(
                '$stopNumber',
                style: TextStyle(
                  color: isFocused ? Colors.black87 : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      title: Text(
        memory.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${stopNumber == null ? '' : 'Stop $stopNumber • '}'
        '${projection.distanceLabel} • ${projection.directionLabel} • '
        '${projection.assessment.label} '
        '${(projection.confidenceScore * 100).round()}% • $stabilityLabel',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: memory.needsCalibrationReview
          ? TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.memoryCalibration,
                  arguments: memory.id,
                );
              },
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Calibrate'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent.shade100,
              ),
            )
          : isFocused
              ? Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.center_focus_strong, size: 16),
                  label: const Text('Focused'),
                  backgroundColor: Colors.cyanAccent.shade100,
                )
              : memory.isPrivate
                  ? const Icon(Icons.lock, color: Colors.orangeAccent, size: 18)
                  : null,
    );
  }
}

class _ARRadar extends StatelessWidget {
  const _ARRadar({
    required this.anchors,
    required this.focusedMemoryId,
    required this.headingDegrees,
    required this.trailStopNumbers,
    required this.isExpanded,
    required this.onToggle,
    required this.onFocus,
  });

  static const _radiusMeters = 260.0;

  final List<ARMemoryProjection> anchors;
  final String? focusedMemoryId;
  final double headingDegrees;
  final Map<String, int> trailStopNumbers;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<ARMemoryProjection> onFocus;

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      return _GlassIconButton(
        tooltip: 'Show AR radar',
        icon: Icons.radar,
        onPressed: onToggle,
      );
    }

    final isWallTrail = trailStopNumbers.isNotEmpty;
    final focusedAnchor = _focusedAnchor();
    final visibleCount =
        anchors.where((anchor) => anchor.projection.isVisible).length;

    return DecoratedBox(
      key: ValueKey(isWallTrail ? 'ar_trail_radar' : 'ar_anchor_radar'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: SizedBox(
        width: 172,
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
                  Expanded(
                    child: Text(
                      isWallTrail ? 'Trail radar' : 'Anchor radar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimize AR radar',
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
              Text(
                isWallTrail
                    ? '$visibleCount/${anchors.length} stops in view'
                    : '$visibleCount/${anchors.length} anchors in view',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (focusedAnchor != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Focused ${focusedAnchor.memory.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox.square(
                dimension: 108,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ARRadarPainter(
                          hasTrail: isWallTrail,
                          visibleCount: visibleCount,
                          anchorCount: anchors.length,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: _ARRadarDotHitTargets(
                        anchors: anchors,
                        focusedMemoryId: focusedMemoryId,
                        headingDegrees: headingDegrees,
                        trailStopNumbers: trailStopNumbers,
                        radiusMeters: _radiusMeters,
                        onFocus: onFocus,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _ARRadarLegend(color: Colors.white, label: 'You'),
                  _ARRadarLegend(
                    color: Colors.lightBlueAccent,
                    label: 'Visible',
                  ),
                  _ARRadarLegend(color: Colors.white54, label: 'Off-screen'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ARMemoryProjection? _focusedAnchor() {
    final focusedMemoryId = this.focusedMemoryId;
    if (focusedMemoryId == null) {
      return null;
    }
    for (final anchor in anchors) {
      if (anchor.memory.id == focusedMemoryId) {
        return anchor;
      }
    }
    return null;
  }
}

class _ARRadarDotHitTargets extends StatelessWidget {
  const _ARRadarDotHitTargets({
    required this.anchors,
    required this.focusedMemoryId,
    required this.headingDegrees,
    required this.trailStopNumbers,
    required this.radiusMeters,
    required this.onFocus,
  });

  final List<ARMemoryProjection> anchors;
  final String? focusedMemoryId;
  final double headingDegrees;
  final Map<String, int> trailStopNumbers;
  final double radiusMeters;
  final ValueChanged<ARMemoryProjection> onFocus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            for (final anchor in anchors.reversed)
              _ARRadarDotHitTarget(
                anchor: anchor,
                point: _arRadarOffsetFor(
                  size: size,
                  radiusFraction: _radarRadiusFraction(anchor, radiusMeters),
                  bearingDegrees: _relativeBearingDegrees(
                    anchor.projection.bearingDegrees,
                    headingDegrees,
                  ),
                ),
                isFocused: anchor.memory.id == focusedMemoryId,
                stopNumber: trailStopNumbers[anchor.memory.id],
                onTap: () => onFocus(anchor),
              ),
          ],
        );
      },
    );
  }
}

class _ARRadarDotHitTarget extends StatelessWidget {
  const _ARRadarDotHitTarget({
    required this.anchor,
    required this.point,
    required this.isFocused,
    required this.stopNumber,
    required this.onTap,
  });

  final ARMemoryProjection anchor;
  final Offset point;
  final bool isFocused;
  final int? stopNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = _radarDotColor(anchor, isFocused);
    final stopNumber = this.stopNumber;

    return Positioned(
      left: point.dx - 13,
      top: point.dy - 13,
      child: Semantics(
        button: true,
        label: stopNumber == null
            ? 'Focus ${anchor.memory.title} from radar'
            : 'Focus ${anchor.memory.title}, trail stop $stopNumber',
        child: GestureDetector(
          key: ValueKey('ar_radar_dot_${anchor.memory.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox.square(
            dimension: 26,
            child: Center(
              child: Container(
                width: isFocused ? 20 : 16,
                height: isFocused ? 20 : 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFocused ? Colors.black87 : Colors.black54,
                    width: isFocused ? 2 : 1.2,
                  ),
                ),
                child: stopNumber == null
                    ? null
                    : Text(
                        '$stopNumber',
                        style: TextStyle(
                          color: isFocused ? Colors.black87 : Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ARRadarLegend extends StatelessWidget {
  const _ARRadarLegend({
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

class _ARRadarPainter extends CustomPainter {
  const _ARRadarPainter({
    required this.hasTrail,
    required this.visibleCount,
    required this.anchorCount,
  });

  final bool hasTrail;
  final int visibleCount;
  final int anchorCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 9;
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final trailPaint = Paint()
      ..color = Colors.cyanAccent.shade100.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final fovPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final centerPaint = Paint()..color = Colors.white;

    final fovPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi * 0.74,
        math.pi * 0.48,
        false,
      )
      ..close();
    canvas.drawPath(fovPath, fovPaint);

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

    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius * 0.78),
      trailPaint,
    );
    if (hasTrail && anchorCount > 1) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 2),
        -math.pi / 2,
        (visibleCount / anchorCount).clamp(0.0, 1.0) * math.pi * 2,
        false,
        trailPaint,
      );
    }
    canvas.drawCircle(center, 5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _ARRadarPainter oldDelegate) {
    return oldDelegate.hasTrail != hasTrail ||
        oldDelegate.visibleCount != visibleCount ||
        oldDelegate.anchorCount != anchorCount;
  }
}

class _ARJourneyPanel extends StatelessWidget {
  const _ARJourneyPanel({
    required this.step,
    required this.title,
    required this.trailProgress,
    required this.headingDegrees,
    required this.sourceWall,
    required this.sourceWallStopCount,
    required this.extraWalls,
    required this.missingStopMemory,
    required this.missingStopSpatialLabel,
    required this.onOpenSourceWall,
    required this.onOpenExtraWall,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenMissingStop,
    required this.onFinish,
  });

  final AnchorJourneyStep step;
  final String? title;
  final ARTrailProgress? trailProgress;
  final double headingDegrees;
  final ARWall? sourceWall;
  final int? sourceWallStopCount;
  final List<ARWall> extraWalls;
  final AnchorMemory? missingStopMemory;
  final String? missingStopSpatialLabel;
  final VoidCallback? onOpenSourceWall;
  final ValueChanged<ARWall> onOpenExtraWall;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<String>? onOpenMissingStop;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final trailProgress = this.trailProgress;
    final sourceWall = this.sourceWall;
    final onOpenSourceWall = this.onOpenSourceWall;
    final isSourceTrail = title != null;
    final isAtRouteEnd = isSourceTrail && step.nextMemory == null;
    final hasReachedAllStops = _hasReachedAllTrailStops(
      trailProgress,
      step.total,
    );
    final isTrailComplete = isAtRouteEnd && hasReachedAllStops;
    final hasUnreachedStopsAtEnd = isAtRouteEnd && !hasReachedAllStops;
    final unreachedStopCount = _unreachedTrailStopCount(
      trailProgress,
      step.total,
    );

    return DecoratedBox(
      key: const ValueKey('ar_journey_panel'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.route_outlined, color: Colors.cyanAccent.shade100),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? 'Journey ${step.progressLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    !isSourceTrail
                        ? '${step.spatialLabel} from your position'
                        : isTrailComplete
                            ? '${step.progressLabel} - Trail complete'
                            : hasUnreachedStopsAtEnd
                                ? '${step.progressLabel} - '
                                    '${_unreachedStopsLabel(unreachedStopCount)}'
                                : '${step.progressLabel} - ${step.spatialLabel} '
                                    'from your position',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (sourceWall != null) ...[
                    const SizedBox(height: 4),
                    _JourneySourceWallChip(
                      wall: sourceWall,
                      stopCount: sourceWallStopCount,
                      totalStops: step.total,
                      extraWallCount: extraWalls.length,
                      onTap: onOpenSourceWall,
                    ),
                    if (extraWalls.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _JourneyExtraWallsRow(
                        walls: extraWalls,
                        onOpenWall: onOpenExtraWall,
                      ),
                    ],
                  ],
                  if (isSourceTrail) ...[
                    const SizedBox(height: 6),
                    _TrailProgressTimeline(
                      step: step,
                      progress: trailProgress,
                    ),
                  ],
                  if (isSourceTrail && trailProgress != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Session ${trailProgress.progressLabel}',
                      key: const ValueKey('ar_journey_session_progress'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (isSourceTrail &&
                      !isTrailComplete &&
                      !hasUnreachedStopsAtEnd) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.nextLegLabel,
                      key: const ValueKey('ar_journey_route_progress'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.cyanAccent.shade100,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.remainingEffortLabel,
                      key: const ValueKey('ar_journey_remaining_effort'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (isSourceTrail &&
                      !isTrailComplete &&
                      !hasUnreachedStopsAtEnd) ...[
                    const SizedBox(height: 6),
                    _NextStopDirectionCue(
                      step: step,
                      headingDegrees: headingDegrees,
                    ),
                  ],
                  if (isSourceTrail && hasUnreachedStopsAtEnd) ...[
                    const SizedBox(height: 6),
                    _TrailIncompleteCue(
                      remainingStopCount: unreachedStopCount,
                      missingStopMemory: missingStopMemory,
                      missingStopSpatialLabel: missingStopSpatialLabel,
                      onOpenMissingStop: onOpenMissingStop,
                    ),
                  ],
                  if (isSourceTrail && isTrailComplete) ...[
                    const SizedBox(height: 6),
                    _TrailCompletionCue(stopCount: step.total),
                  ],
                ],
              ),
            ),
            if (sourceWall != null && onOpenSourceWall != null)
              IconButton(
                key: const ValueKey('ar_journey_open_wall_button'),
                tooltip: 'Open source wall',
                onPressed: onOpenSourceWall,
                icon: const Icon(Icons.grid_view),
                color: Colors.white,
              ),
            if (isTrailComplete)
              IconButton(
                key: const ValueKey('ar_journey_finish_button'),
                tooltip: 'Finish trail',
                onPressed: onFinish,
                icon: const Icon(Icons.check_circle_outline),
                color: Colors.greenAccent.shade100,
              ),
            IconButton(
              key: const ValueKey('ar_journey_previous_button'),
              tooltip: 'Previous journey stop',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              color: Colors.white,
            ),
            IconButton(
              key: const ValueKey('ar_journey_next_button'),
              tooltip: 'Next journey stop',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneySourceWallChip extends StatelessWidget {
  const _JourneySourceWallChip({
    required this.wall,
    required this.stopCount,
    required this.totalStops,
    required this.extraWallCount,
    required this.onTap,
  });

  final ARWall wall;
  final int? stopCount;
  final int totalStops;
  final int extraWallCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final coverageLabel = _wallCoverageLabel(
      stopCount: stopCount,
      totalStops: totalStops,
      extraWallCount: extraWallCount,
    );
    final label = coverageLabel == null
        ? 'Wall context ${wall.title}'
        : 'Wall context ${wall.title} - $coverageLabel';
    final foreground = Colors.cyanAccent.shade100;

    return Tooltip(
      message: 'Open ${wall.title}',
      child: Semantics(
        button: onTap != null,
        label: label,
        child: GestureDetector(
          key: const ValueKey('ar_journey_source_wall_chip'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view, color: foreground, size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  key: const ValueKey('ar_journey_source_wall_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyExtraWallsRow extends StatelessWidget {
  const _JourneyExtraWallsRow({
    required this.walls,
    required this.onOpenWall,
  });

  final List<ARWall> walls;
  final ValueChanged<ARWall> onOpenWall;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('ar_journey_extra_walls_row'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Text(
            'Also',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          for (var index = 0; index < walls.length; index++) ...[
            _JourneyExtraWallChip(
              wall: walls[index],
              onTap: () => onOpenWall(walls[index]),
            ),
            if (index < walls.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _JourneyExtraWallChip extends StatelessWidget {
  const _JourneyExtraWallChip({
    required this.wall,
    required this.onTap,
  });

  final ARWall wall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open ${wall.title}',
      child: GestureDetector(
        key: ValueKey('ar_journey_extra_wall_${wall.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Text(
              wall.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _wallCoverageLabel({
  required int? stopCount,
  required int totalStops,
  required int extraWallCount,
}) {
  final resolvedStopCount = stopCount;
  if (resolvedStopCount == null || resolvedStopCount <= 0 || totalStops <= 0) {
    return null;
  }

  final stopLabel = resolvedStopCount == 1 ? 'stop' : 'stops';
  final coverageLabel = '$resolvedStopCount/$totalStops $stopLabel';
  if (extraWallCount <= 0) {
    return coverageLabel;
  }

  final wallLabel = extraWallCount == 1 ? 'wall' : 'walls';
  return '$coverageLabel + $extraWallCount $wallLabel';
}

bool _hasReachedAllTrailStops(
  ARTrailProgress? progress,
  int totalStops,
) {
  return progress == null || progress.completedStopCount >= totalStops;
}

int _unreachedTrailStopCount(
  ARTrailProgress? progress,
  int totalStops,
) {
  if (progress == null) {
    return 0;
  }
  final remainingStopCount = totalStops - progress.completedStopCount;
  return remainingStopCount < 0 ? 0 : remainingStopCount;
}

String _unreachedStopsLabel(int count) {
  final stopLabel = count == 1 ? 'stop' : 'stops';
  return '$count $stopLabel left';
}

class _TrailProgressTimeline extends StatelessWidget {
  const _TrailProgressTimeline({
    required this.step,
    required this.progress,
  });

  final AnchorJourneyStep step;
  final ARTrailProgress? progress;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      for (var index = 0; index < step.total; index++)
        _timelineStatusFor(index, step.index),
    ];

    return SingleChildScrollView(
      key: const ValueKey('ar_journey_timeline'),
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          for (var index = 0; index < step.total; index++) ...[
            _TrailTimelineStop(
              stopNumber: index + 1,
              status: statuses[index],
            ),
            if (index < step.total - 1)
              _TrailTimelineConnector(_isConnectorCompleted(statuses, index)),
          ],
        ],
      ),
    );
  }

  _TrailTimelineStatus _timelineStatusFor(int index, int currentIndex) {
    if (index == currentIndex) {
      return _TrailTimelineStatus.current;
    }
    final progress = this.progress;
    if (progress != null && index < progress.session.memoryIds.length) {
      final memoryId = progress.session.memoryIds[index];
      if (progress.completedMemoryIds.contains(memoryId)) {
        return _TrailTimelineStatus.completed;
      }
      if (index < currentIndex) {
        return _TrailTimelineStatus.missing;
      }
      return _TrailTimelineStatus.upcoming;
    }
    if (index < currentIndex) {
      return _TrailTimelineStatus.completed;
    }
    return _TrailTimelineStatus.upcoming;
  }

  bool _isConnectorCompleted(
    List<_TrailTimelineStatus> statuses,
    int index,
  ) {
    return _isReachedTimelineStatus(statuses[index]) &&
        _isReachedTimelineStatus(statuses[index + 1]);
  }

  bool _isReachedTimelineStatus(_TrailTimelineStatus status) {
    return status == _TrailTimelineStatus.completed ||
        status == _TrailTimelineStatus.current;
  }
}

class _TrailIncompleteCue extends StatelessWidget {
  const _TrailIncompleteCue({
    required this.remainingStopCount,
    required this.missingStopMemory,
    required this.missingStopSpatialLabel,
    required this.onOpenMissingStop,
  });

  final int remainingStopCount;
  final AnchorMemory? missingStopMemory;
  final String? missingStopSpatialLabel;
  final ValueChanged<String>? onOpenMissingStop;

  @override
  Widget build(BuildContext context) {
    final stopLabel = _unreachedStopsLabel(remainingStopCount);
    final missingStop = missingStopMemory;
    final missingStopLabel = _nextMissingStopLabel(
      missingStop,
      missingStopSpatialLabel,
    );
    final openMissingStop = onOpenMissingStop;
    final canOpenMissingStop = missingStop != null && openMissingStop != null;

    return DecoratedBox(
      key: const ValueKey('ar_journey_route_incomplete'),
      decoration: BoxDecoration(
        color: Colors.amberAccent.shade100.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amberAccent.shade100.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pending_actions_outlined,
              color: Colors.amberAccent.shade100,
              size: 17,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$stopLabel - visit remaining stops before finishing',
                    key: const ValueKey('ar_journey_route_incomplete_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.amberAccent.shade100,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (missingStopLabel != null)
                    Text(
                      missingStopLabel,
                      key: const ValueKey('ar_journey_next_missing_stop'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            Colors.amberAccent.shade100.withValues(alpha: 0.82),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (canOpenMissingStop) ...[
              const SizedBox(width: 6),
              TextButton.icon(
                key: const ValueKey('ar_journey_next_missing_stop_button'),
                onPressed: () => openMissingStop(missingStop.id),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amberAccent.shade100,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.near_me_outlined, size: 17),
                label: const Text('Go'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _nextMissingStopLabel(
  AnchorMemory? missingStop,
  String? spatialLabel,
) {
  if (missingStop == null) {
    return null;
  }
  final trimmedSpatialLabel = spatialLabel?.trim();
  if (trimmedSpatialLabel == null || trimmedSpatialLabel.isEmpty) {
    return 'Next missing ${missingStop.title}';
  }
  return 'Next missing ${missingStop.title} - $trimmedSpatialLabel';
}

class _TrailCompletionCue extends StatelessWidget {
  const _TrailCompletionCue({required this.stopCount});

  final int stopCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('ar_journey_completion_cue'),
      decoration: BoxDecoration(
        color: Colors.greenAccent.shade100.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.greenAccent.shade100.withValues(alpha: 0.48),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent.shade100,
              size: 17,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'All $stopCount stops reached',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.greenAccent.shade100,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Route complete',
                    key: const ValueKey('ar_journey_route_complete'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.greenAccent.shade100.withValues(alpha: 0.86),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

class _TrailTimelineStop extends StatelessWidget {
  const _TrailTimelineStop({
    required this.stopNumber,
    required this.status,
  });

  final int stopNumber;
  final _TrailTimelineStatus status;

  @override
  Widget build(BuildContext context) {
    final isCurrent = status == _TrailTimelineStatus.current;
    final isCompleted = status == _TrailTimelineStatus.completed;
    final isMissing = status == _TrailTimelineStatus.missing;
    final statusLabel = status.stopLabel(stopNumber);

    return Tooltip(
      message: statusLabel,
      child: Semantics(
        label: statusLabel,
        child: Container(
          key: ValueKey('ar_journey_timeline_${status.key}_stop_$stopNumber'),
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent
                ? Colors.cyanAccent.shade100
                : isCompleted
                    ? Colors.greenAccent.shade100
                    : isMissing
                        ? Colors.amberAccent.shade100
                        : Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCurrent || isCompleted || isMissing
                  ? Colors.transparent
                  : Colors.white38,
            ),
          ),
          child: Text(
            '$stopNumber',
            style: TextStyle(
              color: isCurrent || isCompleted || isMissing
                  ? Colors.black87
                  : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrailTimelineConnector extends StatelessWidget {
  const _TrailTimelineConnector(this.isCompleted);

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 2,
      color: isCompleted
          ? Colors.greenAccent.shade100
          : Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _CaptureReadinessTrend {
  const _CaptureReadinessTrend({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

class _ARCaptureControls extends StatelessWidget {
  const _ARCaptureControls({
    required this.state,
    required this.readinessTrend,
    required this.onSnapshot,
    required this.onRecord,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final ARViewerCaptureState state;
  final _CaptureReadinessTrend? readinessTrend;
  final VoidCallback onSnapshot;
  final VoidCallback onRecord;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isActiveRecording =
        state.recordingState == ARRecordingState.recording;
    final isPaused = state.recordingState == ARRecordingState.paused;
    final canToggleRecord = state.canStartRecording || state.canStopRecording;
    final pauseAction = state.canPauseRecording
        ? onPause
        : state.canResumeRecording
            ? onResume
            : null;

    return DecoratedBox(
      key: const ValueKey('ar_capture_controls'),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Tooltip(
              message: state.errorMessage ?? state.statusLabel,
              child: Icon(
                _captureStatusIcon(state),
                color: _captureStatusColor(state),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.statusLabel,
                    key: const ValueKey('ar_capture_status_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (state.readinessActionLabel != null)
                    Text(
                      state.readinessActionLabel!,
                      key: const ValueKey('ar_capture_readiness_action_label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: state.activeReadiness?.isBlocked == true
                            ? Colors.redAccent.shade100
                            : Colors.amberAccent.shade100,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (state.readinessDetailLabel != null)
                    Text(
                      state.readinessDetailLabel!,
                      key: const ValueKey('ar_capture_readiness_detail_label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: state.activeReadiness?.isBlocked == true
                            ? Colors.redAccent.shade100
                            : Colors.amberAccent.shade100,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (readinessTrend != null)
                    Text(
                      readinessTrend!.label,
                      key: const ValueKey('ar_capture_readiness_trend_label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: readinessTrend!.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (state.hasRecordingProgress)
                    Text(
                      state.recordingProgressLabel,
                      key: const ValueKey(
                        'ar_capture_recording_progress_label',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (state.recordingLiveQualityWarningLabel != null)
                    Text(
                      '${state.recordingLiveQualityWarningLabel} - '
                      '${state.recordingLiveQualityDetailLabel}',
                      key: const ValueKey(
                        'ar_capture_recording_quality_warning_label',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.amberAccent.shade100,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ARCaptureIconButton(
              key: const ValueKey('ar_capture_snapshot_button'),
              tooltip: state.canCaptureSnapshot
                  ? 'Capture AR snapshot'
                  : state.snapshotUnavailableLabel,
              icon: Icons.camera_alt_outlined,
              color: Colors.cyanAccent.shade100,
              onPressed:
                  state.canCaptureSnapshot && !state.isBusy ? onSnapshot : null,
            ),
            const SizedBox(width: 4),
            _ARCaptureIconButton(
              key: const ValueKey('ar_capture_record_button'),
              tooltip: state.canStopRecording
                  ? 'Stop AR screen recording'
                  : state.canStartRecording
                      ? 'Start AR screen recording'
                      : state.recordingUnavailableLabel,
              icon: state.canStopRecording
                  ? Icons.stop_circle_outlined
                  : Icons.fiber_manual_record,
              color: isActiveRecording || isPaused
                  ? Colors.redAccent.shade100
                  : Colors.greenAccent.shade100,
              onPressed: canToggleRecord ? onRecord : null,
            ),
            const SizedBox(width: 4),
            _ARCaptureIconButton(
              key: const ValueKey('ar_capture_pause_button'),
              tooltip: isPaused
                  ? 'Resume AR screen recording'
                  : 'Pause AR screen recording',
              icon: isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.amberAccent.shade100,
              onPressed: pauseAction,
            ),
            const SizedBox(width: 4),
            _ARCaptureIconButton(
              key: const ValueKey('ar_capture_cancel_button'),
              tooltip: 'Discard AR screen recording',
              icon: Icons.close,
              color: Colors.white70,
              onPressed: state.canCancelRecording ? onCancel : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ARCaptureIconButton extends StatelessWidget {
  const _ARCaptureIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      iconSize: 20,
      color: color,
      disabledColor: Colors.white.withValues(alpha: 0.26),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
      ),
      icon: Icon(icon),
    );
  }
}

IconData _captureStatusIcon(ARViewerCaptureState state) {
  if (state.errorMessage != null) {
    return Icons.error_outline;
  }
  if (state.isAttaching) {
    return Icons.hourglass_top;
  }
  if (!state.hasController) {
    return Icons.sensors_off;
  }
  if (state.hasReadinessWarning) {
    return state.activeReadiness?.isBlocked == true
        ? Icons.block
        : Icons.warning_amber_outlined;
  }
  if (state.isCapturingSnapshot) {
    return Icons.camera;
  }
  if (state.isRecordingActionPending ||
      state.recordingState == ARRecordingState.processing) {
    return Icons.sync;
  }
  return switch (state.recordingState) {
    ARRecordingState.recording => Icons.fiber_manual_record,
    ARRecordingState.paused => Icons.pause_circle_outline,
    ARRecordingState.idle => state.latestSnapshot?.succeeded == true
        ? Icons.check_circle_outline
        : Icons.photo_camera_outlined,
    ARRecordingState.processing => Icons.sync,
  };
}

Color _captureStatusColor(ARViewerCaptureState state) {
  if (state.errorMessage != null) {
    return Colors.redAccent.shade100;
  }
  if (!state.hasController) {
    return Colors.white54;
  }
  if (state.hasReadinessWarning) {
    return state.activeReadiness?.isBlocked == true
        ? Colors.redAccent.shade100
        : Colors.amberAccent.shade100;
  }
  return switch (state.recordingState) {
    ARRecordingState.recording => Colors.redAccent.shade100,
    ARRecordingState.paused => Colors.amberAccent.shade100,
    ARRecordingState.processing => Colors.blueAccent.shade100,
    ARRecordingState.idle => state.latestSnapshot?.succeeded == true ||
            state.latestRecording?.succeeded == true
        ? Colors.greenAccent.shade100
        : Colors.cyanAccent.shade100,
  };
}

enum _TrailTimelineStatus {
  completed,
  current,
  missing,
  upcoming;

  String get key {
    return switch (this) {
      _TrailTimelineStatus.completed => 'completed',
      _TrailTimelineStatus.current => 'current',
      _TrailTimelineStatus.missing => 'missing',
      _TrailTimelineStatus.upcoming => 'upcoming',
    };
  }

  String stopLabel(int stopNumber) {
    return switch (this) {
      _TrailTimelineStatus.completed => 'Stop $stopNumber completed',
      _TrailTimelineStatus.current => 'Stop $stopNumber current',
      _TrailTimelineStatus.missing => 'Stop $stopNumber missing before finish',
      _TrailTimelineStatus.upcoming => 'Stop $stopNumber upcoming',
    };
  }
}

class _NextStopDirectionCue extends StatelessWidget {
  const _NextStopDirectionCue({
    required this.step,
    required this.headingDegrees,
  });

  final AnchorJourneyStep step;
  final double headingDegrees;

  @override
  Widget build(BuildContext context) {
    final bearingDegrees = step.nextLegBearingDegrees;
    final directionLabel = step.nextLegDirectionLabel;
    if (bearingDegrees == null || directionLabel == null) {
      return const SizedBox.shrink();
    }

    final relativeDegrees = _relativeBearingDegrees(
      bearingDegrees,
      headingDegrees,
    );

    return DecoratedBox(
      key: const ValueKey('ar_journey_direction_cue'),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.shade100.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.cyanAccent.shade100.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: relativeDegrees * math.pi / 180,
              child: Icon(
                Icons.navigation,
                color: Colors.cyanAccent.shade100,
                size: 17,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${_turnLabel(relativeDegrees)} toward $directionLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.cyanAccent.shade100,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _relativeBearingDegrees(double bearingDegrees, double headingDegrees) {
  return ((bearingDegrees - headingDegrees + 540) % 360) - 180;
}

String _turnLabel(double relativeDegrees) {
  final absoluteDegrees = relativeDegrees.abs();
  if (absoluteDegrees <= 15) {
    return 'Ahead';
  }
  if (absoluteDegrees <= 60) {
    return relativeDegrees >= 0 ? 'Slight right' : 'Slight left';
  }
  if (absoluteDegrees <= 125) {
    return relativeDegrees >= 0 ? 'Turn right' : 'Turn left';
  }
  return 'Behind you';
}

Offset _arRadarOffsetFor({
  required Size size,
  required double radiusFraction,
  required double bearingDegrees,
}) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = (math.min(size.width, size.height) / 2 - 9) * radiusFraction;
  final radians = bearingDegrees * math.pi / 180;
  return center +
      Offset(math.sin(radians) * radius, -math.cos(radians) * radius);
}

double _radarRadiusFraction(
  ARMemoryProjection anchor,
  double radiusMeters,
) {
  return (anchor.projection.horizontalDistanceMeters / radiusMeters)
      .clamp(0.12, 1)
      .toDouble();
}

Color _radarDotColor(ARMemoryProjection anchor, bool isFocused) {
  if (isFocused) {
    return Colors.cyanAccent.shade100;
  }
  if (anchor.memory.needsCalibrationReview) {
    return Colors.redAccent.shade100;
  }
  if (anchor.memory.isPrivate) {
    return Colors.amberAccent;
  }
  if (anchor.projection.isVisible) {
    return Colors.lightBlueAccent;
  }
  return Colors.white54;
}

class _FocusedAnchorPanel extends StatelessWidget {
  const _FocusedAnchorPanel({
    required this.anchor,
    required this.linkedWalls,
    required this.onDetails,
    required this.onCalibrate,
    required this.onOpenWall,
    required this.onRecenter,
  });

  final ARMemoryProjection anchor;
  final List<ARWall> linkedWalls;
  final VoidCallback onDetails;
  final VoidCallback onCalibrate;
  final ValueChanged<ARWall> onOpenWall;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final memory = anchor.memory;
    final projection = anchor.projection;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Focused anchor',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              memory.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${projection.distanceLabel} • ${projection.directionLabel} • '
              '${memory.anchorHealthLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
            if (memory.needsCalibrationReview ||
                memory.captureMetadata.hasManualCorrection) ...[
              const SizedBox(height: 8),
              _FocusedAnchorCalibrationLine(
                memory: memory,
                onCalibrate: onCalibrate,
              ),
            ],
            if (linkedWalls.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Virtual walls',
                key: ValueKey('ar_linked_walls_label'),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final wall in linkedWalls)
                    ActionChip(
                      key: ValueKey('ar_linked_wall_${wall.id}'),
                      avatar: Icon(
                        wall.isPublic ? Icons.public : Icons.group,
                        color: Colors.black87,
                        size: 16,
                      ),
                      label: Text(
                        wall.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => onOpenWall(wall),
                      backgroundColor: Colors.cyanAccent.shade100,
                      labelStyle: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRecenter,
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Recenter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusedAnchorCalibrationLine extends StatelessWidget {
  const _FocusedAnchorCalibrationLine({
    required this.memory,
    required this.onCalibrate,
  });

  final AnchorMemory memory;
  final VoidCallback onCalibrate;

  @override
  Widget build(BuildContext context) {
    final metadata = memory.captureMetadata;
    final hasCorrection = metadata.hasManualCorrection;
    final statusColor = hasCorrection
        ? Colors.greenAccent.shade100
        : Colors.amberAccent.shade100;
    final title = hasCorrection
        ? 'Manual correction active'
        : metadata.calibrationReasonLabel;
    final subtitle = hasCorrection
        ? metadata.manualCorrectionOffsetLabel
        : metadata.calibrationGuidanceLabel;

    return Row(
      key: const ValueKey('focused_anchor_calibration_line'),
      children: [
        Icon(
          hasCorrection ? Icons.check_circle_outline : Icons.warning_amber,
          color: statusColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('focused_anchor_adjust_calibration_button'),
          tooltip: 'Adjust calibration',
          onPressed: onCalibrate,
          icon: const Icon(Icons.tune),
          color: Colors.white,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        ),
      ],
    );
  }
}

Color _qualityColor(JejakuPlacementQuality quality) {
  return switch (quality) {
    JejakuPlacementQuality.stable => Colors.greenAccent.shade100,
    JejakuPlacementQuality.usable => Colors.lightBlueAccent.shade100,
    JejakuPlacementQuality.needsCalibration => Colors.amberAccent.shade100,
    JejakuPlacementQuality.unreliable => Colors.redAccent.shade100,
  };
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    super.key,
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
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: Colors.white,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget pill = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
    final handleTap = onTap;
    if (handleTap != null) {
      pill = Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: handleTap,
            child: pill,
          ),
        ),
      );
    }
    final message = tooltip;
    if (message == null || message.isEmpty) {
      return pill;
    }
    return Tooltip(
      message: message,
      child: pill,
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsIssueTile extends StatelessWidget {
  const _DiagnosticsIssueTile({
    required this.issue,
    this.onTap,
  });

  final ARMemoryCloudAnchorIssue issue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final handleTap = onTap;
    Widget tile = Container(
      key: ValueKey('ar_scene_diagnostics_issue_${issue.memoryId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber,
            color: Colors.redAccent.shade100,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  issue.reasonLabel,
                  style: TextStyle(
                    color: Colors.redAccent.shade100,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      color: Colors.cyanAccent.shade100,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        issue.actionLabel,
                        style: TextStyle(
                          color: Colors.cyanAccent.shade100,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  issue.memoryId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (handleTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.center_focus_strong,
              color: Colors.cyanAccent.shade100,
              size: 18,
            ),
          ],
        ],
      ),
    );
    if (handleTap == null) {
      return tile;
    }
    tile = Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: handleTap,
          child: tile,
        ),
      ),
    );
    return tile;
  }
}

class _ArReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (final radius in [72.0, 140.0, 220.0]) {
      canvas.drawCircle(center, radius, paint);
    }
    canvas.drawLine(
      Offset(center.dx - 26, center.dy),
      Offset(center.dx + 26, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 26),
      Offset(center.dx, center.dy + 26),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
