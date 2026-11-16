import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jejaku/app/navigation/app_routes.dart';
import 'package:jejaku/app/utils/bounded_timers.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/ar_viewer/presentation/ar_capture_readiness_trend.dart';
import 'package:jejaku/features/ar_viewer/presentation/ar_diagnostics_labels.dart';
import 'package:jejaku/features/ar_viewer/presentation/ar_session_report_comparison.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';
import 'package:jejaku/features/ar_viewer/services/ar_model_asset_cache_provider.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_hosting_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_recording_coordinator.dart';
import 'package:jejaku/features/ar_viewer/services/ar_visual_frame_capturer.dart';
import 'package:jejaku/features/ar_viewer/services/cloud_anchor_scheduler.dart';
import 'package:jejaku/features/ar_viewer/services/ar_geospatial_quality_monitor.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:jejaku/features/ar_viewer/services/hanging_frame_hit_selector.dart';
import 'package:jejaku/features/ar_viewer/services/hanging_frame_pose.dart';
import 'package:jejaku/features/ar_viewer/services/native_scene_sync_loop.dart';
import 'package:jejaku/features/ar_viewer/services/native_session_placement_planner.dart';
import 'package:jejaku/features/ar_viewer/services/post_frame_coalescer.dart';
import 'package:jejaku/features/ar_viewer/services/viewer_geo.dart';
import 'package:jejaku/features/ar_viewer/services/viewer_pose_tracker.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_runtime_permission_service.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capture_provider.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jejaku/features/ar_viewer/states/ar_scene_diagnostics_provider.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_placement_quality_chip.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_trail_launch_conflict_dialog.dart';
import 'package:jejaku/features/camera/models/capture_sensor_snapshot.dart';
import 'package:jejaku/features/camera/states/capture_session_provider.dart';
import 'package:jejaku/features/home/models/anchor_journey_step.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/anchor_media_resolver.dart';
import 'package:jejaku/features/home/services/anchor_spatial_journey_service.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/home/widgets/anchor_media_pill.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/services/trail_launch_planner.dart';
import 'package:jejaku/features/trails/states/ar_trail_session_providers.dart';
import 'package:jejaku/features/trails/widgets/ar_trail_snackbars.dart';
import 'package:jejaku/features/virtual_wall/models/ar_wall.dart';
import 'package:jejaku/features/virtual_wall/states/wall_providers.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

part 'ar_viewer_parts/ar_viewer_anchor_widgets.dart';
part 'ar_viewer_parts/ar_viewer_bottom_panel.dart';
part 'ar_viewer_parts/ar_viewer_capture_controls.dart';
part 'ar_viewer_parts/ar_viewer_focus_and_hud.dart';
part 'ar_viewer_parts/ar_viewer_geo_helpers.dart';
part 'ar_viewer_parts/ar_viewer_journey_panel.dart';
part 'ar_viewer_parts/ar_viewer_next_stop_cue.dart';
part 'ar_viewer_parts/ar_viewer_scene_diagnostics_sheet.dart';
part 'ar_viewer_parts/ar_viewer_radar.dart';
part 'ar_viewer_parts/ar_viewer_screen_widget.dart';
part 'ar_viewer_parts/ar_viewer_trail_progress.dart';

class _ARViewerScreenState extends ConsumerState<ARViewerScreen>
    with WidgetsBindingObserver {
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
  late final CloudAnchorScheduler _cloudAnchorScheduler = CloudAnchorScheduler(
    onRetryDue: _onCloudAnchorRetryDue,
    onMaintenanceDue: _onCloudAnchorMaintenanceDue,
  );
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
  final ARMemoryProjectionCache _memoryProjectionCache =
      ARMemoryProjectionCache();
  final NativeSessionPlacementPlanner _placementPlanner =
      NativeSessionPlacementPlanner();
  late final NativeSceneSyncLoop _sceneSync = NativeSceneSyncLoop(
    isActive: () => mounted,
    canSync: () => _nativeMemoryPlacementAllowed,
    hasScene: () => _nativeMemoryScene != null,
    prepare: _prepareNativeSceneSync,
    onFailure: _publishNativeSceneFailure,
  );
  late final PostFrameCoalescer _diagnosticsReset = PostFrameCoalescer(
    action: () {
      if (mounted) {
        _resetNativeSceneDiagnostics();
      }
    },
  );
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
  ARGeospatialQualityMonitor? _geospatialQualityMonitor;
  final ValueNotifier<JejakuGeospatialAssessment> _placementAssessment =
      ValueNotifier<JejakuGeospatialAssessment>(
    const JejakuGeospatialAssessment.initial(),
  );
  Timer? _viewerPoseRefreshTimer;
  final BoundedTimers _boundedTimers = BoundedTimers();
  late final ViewerPoseTracker _poseTracker = ViewerPoseTracker(
    onHeading: _applyLiveHeading,
    onPosition: _applyLivePosition,
    timers: _boundedTimers,
  );
  StreamSubscription<ARCamera>? _arCameraSubscription;
  ARCamera? _latestARCamera;
  DateTime? _lastARCameraFrameAt;
  DateTime? _lastARHeadingUpdateAt;
  DateTime? _lastOverlayPerformanceLogAt;
  DateTime? _lastFramePerformanceLogAt;
  Duration _lastProjectionBuildDuration = Duration.zero;
  int _frameTimingSampleCount = 0;
  int _frameBuildMicrosTotal = 0;
  int _frameRasterMicrosTotal = 0;
  int _frameTotalMicrosTotal = 0;
  int _frameTotalMicrosMax = 0;

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
    WidgetsBinding.instance.addObserver(this);
    if (kDebugMode) {
      WidgetsBinding.instance.addTimingsCallback(_handleFrameTimings);
    }
    final initialHeading =
        ref.read(captureSessionProvider).previewSnapshot.headingDegrees;
    if (initialHeading.isFinite) {
      _headingDegrees = ViewerGeo.normalizeHeading(initialHeading);
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

  bool _backgrounded = false;
  bool _isResumingARSession = false;
  String? _arResumeError;
  int _arSessionGeneration = 0;

  /// Only `paused` pauses live tracking: `inactive` also fires while a system
  /// permission dialog is showing, and pausing then would fight the prompt.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseLiveTracking();
    } else if (state == AppLifecycleState.resumed) {
      _resumeLiveTracking();
    }
  }

  void _pauseLiveTracking() {
    if (_backgrounded) {
      return;
    }
    _backgrounded = true;
    _viewerPoseRefreshTimer?.cancel();
    _viewerPoseRefreshTimer = null;
    _poseTracker.stop();
    // Do not treat a pre-background camera frame as current tracking.
    _latestARCamera = null;
    _lastARCameraFrameAt = null;
    _lastARHeadingUpdateAt = null;
    if (mounted) {
      setState(() {
        _isResumingARSession = false;
        _arResumeError = null;
      });
    }
    final controller = _arController;
    if (controller != null && !controller.isDisposed) {
      unawaited(controller.pause().catchError((Object _) {}));
    }
  }

  Future<void> _resumeLiveTracking() async {
    if (!_backgrounded || !mounted) {
      return;
    }
    _backgrounded = false;
    setState(() {
      _isResumingARSession = _arController != null;
      _arResumeError = null;
    });

    // Camera permission may have been revoked in system settings.
    final permissions = await _arPermissionService.check();
    if (!mounted) {
      return;
    }
    if (!permissions.cameraGranted) {
      setState(() {
        _arPermissionsFuture = Future<ARRuntimePermissions>.value(permissions);
        _isResumingARSession = false;
      });
      return;
    }

    final controller = _arController;
    if (controller != null && !controller.isDisposed) {
      try {
        await controller.resume();
      } on Object catch (error) {
        if (mounted) {
          setState(() {
            _arResumeError = error.toString();
            _isResumingARSession = false;
          });
        }
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _isResumingARSession = false);
    if (ref.read(arViewerLivePoseTrackingProvider)) {
      _startViewerPoseTracking();
    }
  }

  void _retryARSessionAfterInterruption() {
    if (!mounted) {
      return;
    }
    _stopGeospatialQualityMonitor();
    unawaited(_arCameraSubscription?.cancel());
    _arCameraSubscription = null;
    _scheduleCaptureDetach();
    setState(() {
      _arResumeError = null;
      _isResumingARSession = true;
      _arSessionGeneration++;
      _arController = null;
      _nativeMemoryScene = null;
      _nativeCloudAnchorManager = null;
      _latestARCamera = null;
      _lastARCameraFrameAt = null;
      _latestSessionReadiness = null;
      _nativeMemoryPlacementAllowed = false;
      _sceneSync.invalidate();
    });
    ref.invalidate(arViewerCapabilitiesProvider);
    ref.invalidate(arViewerSessionPlanProvider);
    ref.invalidate(arViewerSessionConfigProvider);
  }

  Duration get _viewerPoseRefreshInterval {
    // Native AR pose is the primary source while tracking is healthy. Sensor
    // polling remains more frequent during startup, relocalization, and GPS
    // fallback, then backs off once fresh AR frames are flowing.
    return _hasFreshARPose()
        ? const Duration(seconds: 8)
        : const Duration(seconds: 3);
  }

  void _scheduleViewerPoseRefresh() {
    _viewerPoseRefreshTimer?.cancel();
    if (!mounted || _backgrounded ||
        !ref.read(arViewerLivePoseTrackingProvider)) {
      _viewerPoseRefreshTimer = null;
      return;
    }
    _viewerPoseRefreshTimer = Timer(
      _viewerPoseRefreshInterval,
      () async {
        await _refreshViewerPoseFromDeviceSensors();
        if (mounted && !_backgrounded) {
          _scheduleViewerPoseRefresh();
        }
      },
    );
  }

  void _startViewerPoseTracking() {
    _scheduleViewerPoseRefresh();
    unawaited(_refreshViewerPoseFromDeviceSensors());
    _poseTracker.startCompass();
    unawaited(_poseTracker.startPosition(isActive: () => mounted));
  }

  void _startGeospatialQualityMonitor(ARController controller) {
    _stopGeospatialQualityMonitor();
    // A new native session starts from scratch; the previous lock is gone.
    _placementAssessment.value = const JejakuGeospatialAssessment.initial();
    final monitor = ARGeospatialQualityMonitor(
      assessment: _placementAssessment,
      readStatus: controller.getGeospatialStatus,
      onFirstPrecise: _upgradeToNativeGeospatialPlacement,
    );
    _geospatialQualityMonitor = monitor;
    monitor.start();
    unawaited(_checkVpsAvailability(controller, monitor));
  }

  void _stopGeospatialQualityMonitor() {
    _geospatialQualityMonitor?.dispose();
    _geospatialQualityMonitor = null;
  }

  /// Asks ARCore once whether VPS exists at the viewer position. The answer
  /// is only context: accuracy estimates decide placement quality.
  Future<void> _checkVpsAvailability(
    ARController controller,
    ARGeospatialQualityMonitor monitor,
  ) async {
    try {
      final origin = _viewerOriginFor(
        ref.read(captureSessionProvider).previewSnapshot,
      );
      final availability = await controller.checkVpsAvailability(
        latitude: origin.latitude,
        longitude: origin.longitude,
      );
      if (mounted && identical(monitor, _geospatialQualityMonitor)) {
        monitor.setVpsAvailability(availability);
      }
    } on Object {
      // VPS availability is optional context; ignore failures.
    }
  }

  /// Native geospatial tracking reached the accuracy thresholds: re-place
  /// memories that were positioned from GPS/compass with native anchors.
  Future<void> _upgradeToNativeGeospatialPlacement() async {
    final scene = _nativeMemoryScene;
    if (!mounted || scene == null) {
      return;
    }
    scene.preferNativeGeospatialAnchors = true;
    setState(_sceneSync.invalidate);
    _sceneSync.schedule();
  }

  void _applyLiveHeading(double headingDegrees) {
    final lastARFrameAt = _lastARCameraFrameAt;
    if (lastARFrameAt != null &&
        DateTime.now().toUtc().difference(lastARFrameAt) <
            const Duration(milliseconds: 900)) {
      return;
    }
    if (!mounted ||
        ViewerGeo.headingDelta(_headingDegrees, headingDegrees).abs() < ViewerGeo.headingNoiseDegrees) {
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
    if (!ViewerGeo.sameOrigin(beforeOrigin, afterOrigin)) {
      setState(_sceneSync.invalidate);
      _sceneSync.schedule();
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
          ViewerGeo.usesDeviceOrientation(snapshot) && snapshot.headingDegrees.isFinite;
      final normalizedHeading = hasDeviceHeading
          ? ViewerGeo.normalizeHeading(snapshot.headingDegrees)
          : _headingDegrees;
      final shouldUpdateHeading = hasDeviceHeading &&
          ViewerGeo.headingDelta(_headingDegrees, normalizedHeading).abs() > ViewerGeo.headingNoiseDegrees;
      final shouldRefreshNativeScene = !ViewerGeo.sameOrigin(
        beforeOrigin,
        afterOrigin,
      );
      if (shouldUpdateHeading || shouldRefreshNativeScene) {
        setState(() {
          if (shouldUpdateHeading) {
            _headingDegrees = normalizedHeading;
          }
          if (shouldRefreshNativeScene) {
            _sceneSync.invalidate();
          }
        });
        if (shouldRefreshNativeScene) {
          _sceneSync.schedule();
        }
      }
    } finally {
      _isRefreshingViewerPose = false;
    }
  }

  JejakuGeoOrigin _viewerOriginFor(CaptureSensorSnapshot snapshot) {
    return ViewerGeo.originFor(snapshot, fallback: _viewerOrigin);
  }

  Future<void> _resolveInitialTrailLaunch(ARTrailSession trailSession) async {
    if (!mounted) {
      return;
    }
    final action = TrailLaunchPlanner.plan(
      requested: trailSession,
      active: ref.read(activeARTrailProgressProvider),
      resumeExisting: widget.resumeExistingProgress,
      focusedMemoryId: _focusedMemoryId,
    );
    if (action == null) {
      return;
    }
    final controller = ref.read(activeARTrailProgressProvider.notifier);
    switch (action) {
      case ResumeTrail(:final session, :final currentMemoryId):
        controller.resume(session, currentMemoryId: currentMemoryId);
        _isResolvingTrailLaunch = false;
      case StartTrail(:final session, :final currentMemoryId):
        controller.start(session, currentMemoryId: currentMemoryId);
        _isResolvingTrailLaunch = false;
      case AdoptActiveTrail(:final progress):
        _resumeProgressInViewer(progress);
        controller.resume(
          progress.session,
          currentMemoryId: progress.currentMemoryId,
        );
      case AskTrailConflict(:final active, :final requested):
        final choice = await showTrailLaunchConflictDialog(
          context: context,
          active: active,
          requested: requested,
        );
        if (!mounted) {
          return;
        }
        await _applyTrailConflictResolution(
          TrailLaunchPlanner.resolveConflict(
            choice: choice,
            active: active,
            requested: requested,
            focusedMemoryId: _focusedMemoryId,
          ),
        );
    }
  }

  Future<void> _applyTrailConflictResolution(
    TrailConflictResolution resolution,
  ) async {
    switch (resolution) {
      case ShowActiveTrail(:final progress):
        _resumeProgressInViewer(progress);
      case ReplaceWithRequested(:final session, :final currentMemoryId):
        ref
            .read(activeARTrailProgressProvider.notifier)
            .start(session, currentMemoryId: currentMemoryId);
        _isResolvingTrailLaunch = false;
      case AbandonLaunch():
        _isResolvingTrailLaunch = false;
        await Navigator.of(context).maybePop();
    }
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
    _stopGeospatialQualityMonitor();
    _placementAssessment.dispose();
    _arController = null;
    _nativeMemoryScene = null;
    _nativeCloudAnchorManager = null;
    _latestARCamera = null;
    _lastARHeadingUpdateAt = null;
    _placementPlanner.clear();
    _memoryProjectionCache.clear();
    if (kDebugMode) {
      WidgetsBinding.instance.removeTimingsCallback(_handleFrameTimings);
    }
    _scheduleCaptureDetach();
    _sceneSync.dispose();
    _diagnosticsReset.reset();
    _cloudAnchorScheduler.cancelMaintenance();
    _cloudAnchorScheduler.cancelRetry();
    WidgetsBinding.instance.removeObserver(this);
    _viewerPoseRefreshTimer?.cancel();
    _viewerPoseRefreshTimer = null;
    _boundedTimers.cancelAll();
    _poseTracker.stop();
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
    final projectionStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    final projectedAnchors = projectAnchorMemories(
      memories: anchors,
      viewerPose: viewerPose,
      onlyInRange: false,
      cache: _memoryProjectionCache,
    );
    projectionStopwatch?.stop();
    _lastProjectionBuildDuration =
        Duration(microseconds: projectionStopwatch?.elapsedMicroseconds ?? 0);
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
                        totalMemoryCount: anchors.length,
                      ),
                    // Camera-relative guide follows the view; the persistent
                    // world pose is resolved from live AR tracking on capture.
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(child: _HangingFrameAimPreview()),
                      ),
                    ),
                    // Subtle edge scrims keep controls and status readable
                    // over bright skies without dimming the center camera view.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x66000000),
                                Color(0x12000000),
                                Color(0x00000000),
                                Color(0x18000000),
                                Color(0x99000000),
                              ],
                              stops: [0, 0.18, 0.48, 0.72, 1],
                            ),
                          ),
                        ),
                      ),
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
                          const SizedBox(width: 8),
                          ValueListenableBuilder<JejakuGeospatialAssessment>(
                            valueListenable: _placementAssessment,
                            builder: (context, assessment, _) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ARPlacementQualityChip(
                                    key: const ValueKey('ar_placement_quality_chip'),
                                    assessment: assessment,
                                  ),
                                  const SizedBox(width: 6),
                                  _HudPill(
                                    key: const ValueKey('ar_pose_source_status'),
                                    icon: _poseSourceIcon(),
                                    label: _poseSourceShortLabel(),
                                    color: _poseSourceColor(Theme.of(context).colorScheme),
                                    tooltip: _poseSourceDetailLabel(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    if ((_isResumingARSession && _arController != null) ||
                        _arResumeError != null)
                      Positioned(
                        key: const ValueKey('ar_session_interruption_panel'),
                        left: 16,
                        right: 16,
                        top: 76,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.86),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _arResumeError == null
                                      ? Colors.white24
                                      : Colors.orangeAccent,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        if (_isResumingARSession)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orangeAccent,
                                            size: 20,
                                          ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _arResumeError == null
                                                ? 'Resuming AR session'
                                                : 'AR session needs to restart',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _arResumeError == null
                                          ? 'The camera may take a moment to relocalize. Keep the app open and slowly scan the area.'
                                          : 'The camera session could not resume. Restart AR to continue. $_arResumeError',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                    if (_arResumeError != null) ...[
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: FilledButton.tonal(
                                          key: const ValueKey('ar_session_restart_button'),
                                          onPressed: _retryARSessionAfterInterruption,
                                          child: const Text('Restart AR'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_arController != null && !_hasFreshARPose())
                      Positioned(
                        key: const ValueKey('ar_tracking_recovery_guidance'),
                        top: 72,
                        right: 16,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 224),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.76),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isRelocalizing()
                                    ? Colors.orangeAccent.shade100
                                    : Colors.amberAccent.shade100,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _isRelocalizing()
                                        ? Icons.center_focus_weak
                                        : Icons.lightbulb_outline,
                                    color: _poseSourceColor(Theme.of(context).colorScheme),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isRelocalizing()
                                              ? 'Recovering AR tracking'
                                              : 'AR tracking unavailable',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _poseRecoveryGuidance(),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                        ),
                        child: SingleChildScrollView(
                          reverse: true,
                          physics: const ClampingScrollPhysics(),
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
                    key: ValueKey('native_ar_hanging_photo_view_$_arSessionGeneration'),
                    // Geospatial stays as resolved against device capabilities
                    // so memories can lock to real-world coordinates. Placement
                    // quality is reported in the HUD; GPS/compass projection
                    // remains the labeled fallback.
                    config: config.copyWith(
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
                // Keep the low-level AR engine HUD available during local
                // device validation without exposing diagnostic overlays in
                // release builds or changing normal user interactions.
                if (kDebugMode && _arController != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ARDebugOverlay(
                        controller: _arController!,
                        showPlanes: true,
                        showFPS: true,
                        showPose: true,
                        showTrackingState: true,
                        showEntityCount: true,
                        showAnchorPositions: true,
                        showLightEstimate: true,
                      ),
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
    setState(() {
      _isResumingARSession = false;
      _arResumeError = null;
    });
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
      _sceneSync.invalidate();
    });
    _placementPlanner.clear();
    _lastARHeadingUpdateAt = null;
    _startGeospatialQualityMonitor(controller);
    _sceneSync.schedule();
  }

  void _handleNativeCameraUpdate(ARCamera camera) {
    final now = DateTime.now().toUtc();
    _lastARCameraFrameAt = now;
    final hadTrackingCamera = _latestARCamera?.isTracking == true;
    _latestARCamera = camera;
    if (!mounted) {
      return;
    }
    if (hadTrackingCamera != camera.isTracking) {
      // Surface tracking loss and recovery immediately without rebuilding on
      // every camera frame. Also adapt sensor polling to the new pose source.
      setState(() {});
      _scheduleViewerPoseRefresh();
    }
    if (!camera.isTracking) {
      return;
    }
    if (!hadTrackingCamera && _nativeMemoryScene != null) {
      _sceneSync.invalidate();
      _sceneSync.schedule();
    }
    final heading = _headingFromARCamera(camera);
    if (heading == null) {
      return;
    }
    final headingDelta = ViewerGeo.headingDelta(_headingDegrees, heading).abs();
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
    return ViewerGeo.normalizeHeading(radians * 180 / math.pi);
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
      _sceneSync.invalidate();
    }
    _diagnosticsController.updateSessionHealthAssessmentForSession(
      _diagnosticsSessionId,
      assessment,
    );
    _captureController.updateAssessment(assessment);
    if (_nativeMemoryScene != null) {
      _nativeMemoryPlacementAllowed = true;
      _sceneSync.schedule();
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
    return _placementPlanner.plan(
      [
        for (final projected in projections)
          PlacementCandidate(
            memoryId: projected.memory.id,
            isInFront: projected.projection.isInFront,
            relativeHeadingDegrees: projected.projection.relativeHeadingDegrees,
            relativePitchDegrees: projected.projection.relativePitchDegrees,
            distanceMeters: projected.projection.distanceMeters,
            horizontalDistanceMeters:
                projected.projection.horizontalDistanceMeters,
            capturedThisSession: _hasSameSessionLocalPose(projected.memory),
          ),
      ],
      camera: _latestARCamera,
      lastFrameAt: _lastARCameraFrameAt,
      focusedMemoryId: _focusedMemoryId,
    );
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
    if (!ViewerGeo.sameOrigin(_latestNativeSceneOrigin, viewerOrigin)) {
      _latestNativeSceneOrigin = viewerOrigin;
      _placementPlanner.clear();
      _sceneSync.invalidate();
    }
    final bool? canStartSession = arCapabilities.when(
      data: (capabilities) {
        final canPersistCloudAnchors = capabilities.canPersistCloudAnchors &&
            _resolvedSessionCloudAnchorsEnabled;
        if (_nativeCloudAnchorsEnabled != canPersistCloudAnchors) {
          _sceneSync.invalidate();
        }
        if (!canPersistCloudAnchors) {
          _cloudAnchorScheduler.cancelMaintenance();
          _cloudAnchorScheduler.cancelRetry();
        }
        _nativeCloudAnchorsEnabled = canPersistCloudAnchors;
        return capabilities.canStartSession;
      },
      error: (_, __) {
        _nativeCloudAnchorsEnabled = false;
        _cloudAnchorScheduler.cancelMaintenance();
        _cloudAnchorScheduler.cancelRetry();
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
        _placementPlanner.clear();
        if (hadNativeSession) {
          _scheduleCaptureDetach();
        }
        _cloudAnchorScheduler.cancelMaintenance();
        _cloudAnchorScheduler.cancelRetry();
        _cloudAnchorHostInFlightMemoryIds.clear();
        _sceneSync.invalidate();
        _scheduleNativeSceneDiagnosticsReset();
      }
      return;
    }
    if (_latestSessionReadiness == null) {
      _nativeMemoryPlacementAllowed = false;
      _cloudAnchorScheduler.cancelMaintenance();
      _cloudAnchorScheduler.cancelRetry();
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
      _cloudAnchorScheduler.cancelMaintenance();
      _cloudAnchorScheduler.cancelRetry();
      if (!_sceneSync.isCurrent(fingerprint)) {
        _sceneSync.schedule();
      }
      return;
    }
    _nativeMemoryPlacementAllowed = true;
    _scheduleCloudAnchorMaintenance();
    if (_sceneSync.isCurrent(fingerprint)) {
      return;
    }
    _sceneSync.schedule();
  }

  bool get _isNativePlacementPaused {
    final readiness = _latestSessionReadiness;
    return readiness != null && !readiness.canPlaceAnchors;
  }

  List<ARMemoryProjection> _nativeSceneVisualProjections(
    List<ARMemoryProjection> anchors,
  ) {
    return selectNativeSceneItems<ARMemoryProjection>(
      anchors,
      idOf: (anchor) => anchor.memory.id,
      isInFront: (anchor) => anchor.projection.isInFront,
      focusedId: _focusedMemoryId,
    );
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

  NativeSceneSyncAttempt? _prepareNativeSceneSync() {
    final scene = _nativeMemoryScene;
    if (scene == null) {
      return null;
    }
    final memories = List<AnchorMemory>.unmodifiable(
      _latestNativeSceneMemories,
    );
    final origin = _latestNativeSceneOrigin;
    final mediaPreviewBytesByMemoryId = _mediaPreviewBytesByMemoryId(memories);
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
    return NativeSceneSyncAttempt(
      fingerprint: fingerprint,
      run: () => _runNativeSceneSync(
        scene: scene,
        memories: memories,
        origin: origin,
        mediaPreviewBytesByMemoryId: mediaPreviewBytesByMemoryId,
        mediaIdsByMemoryId: mediaIdsByMemoryId,
        sessionPlacementsByMemoryId: sessionPlacementsByMemoryId,
      ),
    );
  }

  /// Pushes one snapshot to the native scene. Returns `false` when the screen
  /// went away or the scene was replaced mid-flight.
  Future<bool> _runNativeSceneSync({
    required JejakuMemoryARScene scene,
    required List<AnchorMemory> memories,
    required JejakuGeoOrigin origin,
    required Map<String, Uint8List> mediaPreviewBytesByMemoryId,
    required Map<String, String> mediaIdsByMemoryId,
    required Map<String, ARMemorySessionPlacement>
        sessionPlacementsByMemoryId,
  }) async {
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
      return false;
    }
    final hostingResult = outcome.scene.isPlacementDeferred
        ? const ARMemoryCloudAnchorHostingResult()
        : await _maybeHostCloudAnchors(
            sceneResult: outcome.scene,
            memories: memories,
          );
    if (!mounted || scene != _nativeMemoryScene) {
      return false;
    }
    final retryDecision = outcome.scene.isPlacementDeferred
        ? null
        : _cloudAnchorScheduler.scheduleRetry({
            ...outcome.cloudAnchors.unresolvedMemoryIds,
            ...hostingResult.failedMemoryIds,
          });
    if (outcome.scene.isPlacementDeferred) {
      _cloudAnchorScheduler.cancelRetry();
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
        cloudAnchorRetryAttempt: _cloudAnchorScheduler.retryState.attempt,
        nextCloudAnchorMaintenanceAt: _cloudAnchorScheduler.maintenanceCheckAt,
        sessionStartedAt: _diagnosticsSessionStartedAt,
        unsupportedSessionFeatureKeys: _unsupportedNativeSessionFeatureKeys,
      ),
    );
    return true;
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

  void _resyncNativeScene() {
    _sceneSync.invalidate();
    _sceneSync.schedule();
  }

  void _onCloudAnchorRetryDue() {
    if (!mounted || _nativeMemoryScene == null) {
      return;
    }
    _resyncNativeScene();
  }

  void _onCloudAnchorMaintenanceDue() {
    if (!mounted || !_nativeCloudAnchorsEnabled || _nativeMemoryScene == null) {
      return;
    }
    _resyncNativeScene();
  }

  void _scheduleCloudAnchorMaintenance() {
    if (!_nativeCloudAnchorsEnabled || _nativeMemoryScene == null) {
      _cloudAnchorScheduler.cancelMaintenance();
      return;
    }
    _cloudAnchorScheduler.scheduleMaintenance(_latestNativeSceneMemories);
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

  void _scheduleNativeSceneDiagnosticsReset() => _diagnosticsReset.schedule();

  void _resetNativeSceneDiagnostics() {
    if (!mounted) {
      return;
    }
    _diagnosticsController.resetSession(_diagnosticsSessionId);
  }

  void _refreshNativeScene() {
    _placementPlanner.clear();
    _cloudAnchorScheduler.cancelRetry();
    if (!_sceneSync.refresh()) {
      _resetNativeSceneDiagnostics();
    }
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
    required int totalMemoryCount,
  }) {
    final overlayStopwatch = kDebugMode ? (Stopwatch()..start()) : null;
    // Keep every on-screen anchor and the focused anchor, but bound
    // off-screen bubbles to the eight nearest memories. The radar and list
    // still expose the complete collection; this only limits expensive
    // floating widgets and the collision-avoidance work on a dense map.
    final visibleAnchors = <ARMemoryProjection>[];
    final offScreenAnchors = <ARMemoryProjection>[];
    for (final anchor in anchors) {
      if (anchor.projection.isVisible ||
          anchor.memory.id == focusedMemoryId) {
        visibleAnchors.add(anchor);
      } else {
        offScreenAnchors.add(anchor);
      }
    }
    offScreenAnchors.sort(
      (a, b) => a.projection.distanceMeters.compareTo(
        b.projection.distanceMeters,
      ),
    );
    final orderedAnchors = <ARMemoryProjection>[
      ...visibleAnchors,
      ...offScreenAnchors.take(8),
    ]..sort((a, b) {
        final aFocused = a.memory.id == focusedMemoryId;
        final bFocused = b.memory.id == focusedMemoryId;
        if (aFocused != bFocused) {
          return aFocused ? -1 : 1;
        }
        if (a.projection.isVisible != b.projection.isVisible) {
          return a.projection.isVisible ? -1 : 1;
        }
        final distanceOrder = a.projection.distanceMeters.compareTo(
          b.projection.distanceMeters,
        );
        return distanceOrder != 0
            ? distanceOrder
            : a.memory.id.compareTo(b.memory.id);
      });

    final placedAlignments = <Alignment>[];
    final overlays = <Widget>[];
    for (final anchor in orderedAnchors) {
      final isFocused = anchor.memory.id == focusedMemoryId;
      final base = isFocused
          ? const Alignment(0, -0.1)
          : Alignment(
              anchor.projection.alignmentX,
              anchor.projection.alignmentY,
            );
      final candidates = isFocused
          ? [base]
          : [
              base,
              Alignment(base.x, (base.y - 0.22).clamp(-0.88, 0.88).toDouble()),
              Alignment(base.x, (base.y + 0.22).clamp(-0.88, 0.88).toDouble()),
              Alignment(base.x, (base.y - 0.44).clamp(-0.88, 0.88).toDouble()),
              Alignment(base.x, (base.y + 0.44).clamp(-0.88, 0.88).toDouble()),
            ];
      var selected = candidates.first;
      for (final candidate in candidates) {
        final overlaps = placedAlignments.any((placed) {
          return (candidate.x - placed.x).abs() < 0.62 &&
              (candidate.y - placed.y).abs() < 0.34;
        });
        if (!overlaps) {
          selected = candidate;
          break;
        }
      }
      placedAlignments.add(selected);

      overlays.add(
        Align(
          alignment: selected,
          child: Opacity(
            opacity: isFocused
                ? 1.0
                : anchor.projection.opacity.clamp(0.48, 1.0),
            child: Transform.scale(
              scale: isFocused ? 1.0 : anchor.projection.scale,
              child: _AnchorBubble(
                anchor: anchor,
                isFocused: isFocused,
                stopNumber: trailStopNumbers[anchor.memory.id],
                wallTitles:
                    wallTitlesByMemoryId[anchor.memory.id] ?? const <String>[],
                onTap: () => _recenterOnAnchor(anchor),
              ),
            ),
          ),
        ),
      );
    }
    overlayStopwatch?.stop();
    _logOverlayPerformance(
      totalMemoryCount: totalMemoryCount,
      candidateCount: anchors.length,
      visibleCount: visibleAnchors.length,
      renderedCount: orderedAnchors.length,
      projectionDuration: _lastProjectionBuildDuration,
      overlayDuration: Duration(
        microseconds: overlayStopwatch?.elapsedMicroseconds ?? 0,
      ),
    );
    return overlays;
  }

  void _handleFrameTimings(List<ui.FrameTiming> timings) {
    if (!kDebugMode || timings.isEmpty) {
      return;
    }
    for (final timing in timings) {
      final buildMicros = timing.buildDuration.inMicroseconds;
      final rasterMicros = timing.rasterDuration.inMicroseconds;
      final totalMicros = timing.totalSpan.inMicroseconds;
      _frameTimingSampleCount++;
      _frameBuildMicrosTotal += buildMicros;
      _frameRasterMicrosTotal += rasterMicros;
      _frameTotalMicrosTotal += totalMicros;
      if (totalMicros > _frameTotalMicrosMax) {
        _frameTotalMicrosMax = totalMicros;
      }
    }

    final now = DateTime.now();
    final lastLogAt = _lastFramePerformanceLogAt;
    if (lastLogAt != null &&
        now.difference(lastLogAt) < const Duration(seconds: 5)) {
      return;
    }
    _lastFramePerformanceLogAt = now;
    final samples = _frameTimingSampleCount;
    if (samples == 0) {
      return;
    }
    final averageBuildMs =
        _frameBuildMicrosTotal / samples / 1000;
    final averageRasterMs =
        _frameRasterMicrosTotal / samples / 1000;
    final averageTotalMs =
        _frameTotalMicrosTotal / samples / 1000;
    final maxTotalMs = _frameTotalMicrosMax / 1000;
    debugPrint(
      '[ARViewerPerf] frame samples=$samples '
      'avgBuild=${averageBuildMs.toStringAsFixed(2)}ms '
      'avgRaster=${averageRasterMs.toStringAsFixed(2)}ms '
      'avgTotal=${averageTotalMs.toStringAsFixed(2)}ms '
      'maxTotal=${maxTotalMs.toStringAsFixed(2)}ms',
    );
    _frameTimingSampleCount = 0;
    _frameBuildMicrosTotal = 0;
    _frameRasterMicrosTotal = 0;
    _frameTotalMicrosTotal = 0;
    _frameTotalMicrosMax = 0;
  }

  void _logOverlayPerformance({
    required int totalMemoryCount,
    required int candidateCount,
    required int visibleCount,
    required int renderedCount,
    required Duration projectionDuration,
    required Duration overlayDuration,
  }) {
    if (!kDebugMode) {
      return;
    }
    final now = DateTime.now();
    final lastLogAt = _lastOverlayPerformanceLogAt;
    if (lastLogAt != null &&
        now.difference(lastLogAt) < const Duration(seconds: 5)) {
      return;
    }
    _lastOverlayPerformanceLogAt = now;
    debugPrint(
      '[ARViewerPerf] anchors total=$totalMemoryCount '
      'candidates=$candidateCount visible=$visibleCount '
      'rendered=$renderedCount '
      'projection=${projectionDuration.inMicroseconds}us '
      'overlayCompose=${overlayDuration.inMicroseconds}us',
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
      _sceneSync.invalidate();
    });
    _sceneSync.schedule();
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
        stagedBytes = await _frameCapturer.capturePng();
        stagedAt = DateTime.now().toUtc();
        if (stagedBytes != null) {
          message = 'AR visual snapshot staged for publishing';
        }
      }
      if (!mounted || stagedBytes == null) {
        return;
      }
      final accepted = await _confirmARSnapshot(
        stagedBytes,
        placement: localPose,
      );
      if (!mounted || accepted != true) {
        return;
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
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


  Future<bool?> _confirmARSnapshot(
    Uint8List bytes, {
    required AnchorLocalPose? placement,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final placementLabel = placement == null
            ? 'Placement unavailable — the photo can still be published.'
            : placement.planeId == null
                ? 'Floating in space • about ${placement.distanceMeters.toStringAsFixed(1)} m ahead'
                : 'Near a detected vertical surface • about ${placement.distanceMeters.toStringAsFixed(1)} m away';
        return AlertDialog(
          key: const ValueKey('ar_snapshot_confirmation_dialog'),
          title: const Text('Review AR photo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Image.memory(
                      bytes,
                      key: const ValueKey('ar_snapshot_confirmation_image'),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image_outlined, size: 40)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.view_in_ar, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(placementLabel, style: theme.textTheme.bodyMedium)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'The frame is not wall-bound. It can float at the captured position in your space.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('ar_snapshot_retake_button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Retake'),
            ),
            FilledButton.icon(
              key: const ValueKey('ar_snapshot_use_button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.check),
              label: const Text('Use photo'),
            ),
          ],
        );
      },
    );
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
      final hits = await _boundedTimers.run(
        controller.hitTest(0.5, 0.5),
        const Duration(milliseconds: 700),
      );
      final hit = HangingFrameHitSelector.best(hits);
      final cameraPosition = camera.pose.position;
      final cameraForward = camera.pose.rotation.rotateVector(
        ARVector3.forward,
      );
      // Free-space fallback follows the complete camera ray, including
      // pitch. This lets a frame float above or below eye level instead of
      // being flattened onto the camera's horizontal heading.
      if (cameraForward.lengthSquared < 0.000001) {
        debugPrint(
          '[AR_HANGING_FRAME] capture_pose skipped: '
          'camera forward vector too small '
          'forward=${ARDiagnosticsLabels.vector(cameraForward)}',
        );
        return null;
      }
      final forward = cameraForward.normalized;
      const fallbackDistance = 1.5;
      final fallbackPosition = cameraPosition + forward * fallbackDistance;
      final useSurfacePosition =
          hit != null && HangingFrameHitSelector.isVerticalSurface(hit);
      final position =
          useSurfacePosition ? hit.worldPose.position : fallbackPosition;
      final rotation = HangingFramePose.cameraYawRotation(camera);
      final distance = useSurfacePosition
          ? hit.distance
          : ARVector3.distance(cameraPosition, position);
      debugPrint(
        '[AR_HANGING_FRAME] capture_pose saved '
        'hits=${hits.length} '
        'selected=${HangingFrameHitSelector.describe(hit)} '
        'usedVerticalSurface=$useSurfacePosition '
        'camera=${ARDiagnosticsLabels.vector(cameraPosition)} '
        'forward=${ARDiagnosticsLabels.vector(forward)} '
        'position=${ARDiagnosticsLabels.vector(position)} '
        'rotation=${ARDiagnosticsLabels.quaternion(rotation)} '
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

  late final ARVisualFrameCapturer _frameCapturer = ARVisualFrameCapturer(
    captureOverlay: _captureAROverlayImage,
    captureCameraBytes: () async => _arController?.captureSnapshot(),
  );

  late final ARRecordingCoordinator _recordingCoordinator =
      ARRecordingCoordinator(
    gateway: _captureController,
    config: _screenRecordingConfig,
    frameSource: _frameCapturer.capturePng,
  );

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

  void _showRecordingOutcome(
    ScaffoldMessengerState messenger,
    ARRecordingOutcome outcome,
  ) {
    if (!mounted) {
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(outcome.message)));
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
    _showRecordingOutcome(messenger, await _recordingCoordinator.start());
  }

  Future<void> _pauseARRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    _showRecordingOutcome(messenger, await _recordingCoordinator.pause());
  }

  Future<void> _resumeARRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    _showRecordingOutcome(messenger, await _recordingCoordinator.resume());
  }

  Future<void> _cancelARRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    _showRecordingOutcome(messenger, await _recordingCoordinator.cancel());
  }

  Future<void> _stopARRecording() async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await _recordingCoordinator.stop();
    _showRecordingOutcome(messenger, outcome);
    final staged = outcome.staged;
    if (staged == null) {
      return;
    }
    await _refreshViewerPoseFromDeviceSensors();
    if (!mounted) {
      return;
    }
    final capturedAt = DateTime.now().toUtc();
    ref.read(captureSessionProvider.notifier).stageARRecording(
          capturedAt: capturedAt,
          filePath: staged.filePath,
          duration: staged.duration,
          frameCount: staged.frameCount,
          targetFps: _screenRecordingConfig.fps,
          videoBitrateKbps: _screenRecordingConfig.videoBitrateKbps,
          outputFormat: _screenRecordingConfig.outputFormat,
          includesUIOverlay: _screenRecordingConfig.includeUIOverlay,
          includesAudio: _screenRecordingConfig.includeAudio,
          fileSizeBytes: staged.fileSizeBytes,
          arDiagnostics: _captureDiagnosticsSnapshot(capturedAt),
        );
    await _openPublishAndFocusPublishedMemory();
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
    final latestReportDiff = ARSessionReportComparison.latestDiff(diagnostics);
    final captureReadinessTrend = ARCaptureReadinessTrend.evaluate(
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

  Color _sceneDiagnosticsColor(
    ARMemorySceneDiagnostics diagnostics,
    ColorScheme colors,
  ) {
    if (diagnostics.hasNativeSceneFailure) {
      return colors.error;
    }
    if (diagnostics.hasCloudAnchorFailures) {
      return colors.error;
    }
    if (diagnostics.hasSessionConfigDowngrades) {
      return colors.tertiary;
    }
    if (diagnostics.hasCloudAnchorRetryScheduled) {
      return colors.secondary;
    }
    if (diagnostics.hasSyncedScene) {
      return colors.primary;
    }
    return colors.onSurfaceVariant;
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

  Color _sessionHealthColor(
    ARMemorySceneDiagnostics diagnostics,
    ColorScheme colors,
  ) {
    final assessment = diagnostics.sessionHealthAssessment;
    if (assessment == null) {
      return colors.onSurfaceVariant;
    }
    return switch (assessment.severity) {
      ARSessionHealthSeverity.good => colors.primary,
      ARSessionHealthSeverity.warning => colors.tertiary,
      ARSessionHealthSeverity.blocked => assessment.hasIssue(
          ARSessionHealthIssue.sessionStopped,
        )
            ? colors.error
            : colors.tertiary,
    };
  }

  List<Widget> _capabilityHudPills(
    AsyncValue<JejakuARSessionPlan> arSessionPlan,
    ARMemorySceneDiagnostics sceneDiagnostics,
    ColorScheme colors,
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
            ? _sessionHealthColor(sceneDiagnostics, colors)
            : capabilities.canPlaceMemories
                ? colors.primary
                : colors.onSurfaceVariant;
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
                ? colors.primary
                : colors.onSurfaceVariant,
            tooltip: recordingTooltip,
          ),
          if (plan.hasNativeDowngrades)
            _HudPill(
              icon: Icons.tune,
              label: 'AR limited',
              color: colors.tertiary,
              tooltip: downgradeTooltip,
            ),
        ];
      },
      error: (_, __) => [
        _HudPill(
          icon: Icons.map_outlined,
          label: 'Local AR',
          color: colors.primary,
        ),
        _HudPill(
          icon: Icons.videocam_outlined,
          label: 'No rec',
          color: colors.onSurfaceVariant,
        ),
      ],
      loading: () => [
        _HudPill(
          icon: Icons.sensors,
          label: 'AR check',
          color: colors.secondary,
        ),
        _HudPill(
          icon: Icons.videocam_outlined,
          label: 'Rec check',
          color: colors.secondary,
        ),
      ],
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
    _placementPlanner.forget(anchor.memory.id);
    _sceneSync.invalidate();
    _sceneSync.schedule();
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

  bool _hasFreshARPose() {
    final lastARFrameAt = _lastARCameraFrameAt;
    return _latestARCamera?.isTracking == true &&
        lastARFrameAt != null &&
        DateTime.now().toUtc().difference(lastARFrameAt) <
            const Duration(seconds: 2);
  }

  bool _isRelocalizing() {
    final lastARFrameAt = _lastARCameraFrameAt;
    return _latestARCamera?.isTracking == false &&
        lastARFrameAt != null &&
        DateTime.now().toUtc().difference(lastARFrameAt) <
            const Duration(seconds: 2);
  }

  String _poseSourceShortLabel() {
    if (_hasFreshARPose()) {
      return 'AR tracking';
    }
    if (_isRelocalizing()) {
      return 'Relocalizing · GPS';
    }
    return _lastARCameraFrameAt == null ? 'GPS fallback' : 'AR stale · GPS';
  }

  IconData _poseSourceIcon() {
    if (_hasFreshARPose()) {
      return Icons.view_in_ar;
    }
    if (_isRelocalizing()) {
      return Icons.center_focus_weak;
    }
    return Icons.explore_outlined;
  }

  Color _poseSourceColor(ColorScheme colors) {
    if (_hasFreshARPose()) {
      return colors.primary;
    }
    return _lastARCameraFrameAt == null
        ? colors.tertiary
        : colors.error;
  }

  String _poseRecoveryGuidance() {
    if (_isRelocalizing()) {
      return 'Move the phone slowly. Aim at a well-lit area with distinct '
          'edges or textured surfaces, and avoid blank walls.';
    }
    if (_lastARCameraFrameAt == null) {
      return 'Point the camera at a well-lit area with visible detail. '
          'Compass/GPS is being used until AR tracking starts.';
    }
    return 'AR pose updates are stale. Keep the app in the foreground, '
        'move slowly, and scan nearby surfaces to resume tracking. '
        'Compass/GPS is only an approximate fallback.';
  }

  String _poseSourceDetailLabel() {
    final lastARFrameAt = _lastARCameraFrameAt;
    if (lastARFrameAt == null) {
      return 'Waiting for ARCore camera pose. Heading currently uses compass/GPS fallback.';
    }
    final ageMs = DateTime.now()
        .toUtc()
        .difference(lastARFrameAt)
        .inMilliseconds
        .clamp(0, 9999);
    if (_hasFreshARPose()) {
      return 'ARCore tracking is active. Heading uses the live camera pose.';
    }
    if (_isRelocalizing()) {
      return 'ARCore is trying to relocalize. Heading temporarily uses compass/GPS fallback; keep the camera pointed at a well-lit area with recognizable features.';
    }
    return 'ARCore camera pose is stale (${ageMs} ms). Heading currently uses compass/GPS fallback.';
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
