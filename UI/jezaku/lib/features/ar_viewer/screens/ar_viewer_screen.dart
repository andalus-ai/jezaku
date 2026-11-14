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
import 'package:jejaku/features/ar_viewer/services/ar_geospatial_quality_monitor.dart';
import 'package:jejaku/features/ar_viewer/services/ar_scene_diagnostics_export_bundle_store.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_scene_sync_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_runtime_permission_service.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capture_provider.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jejaku/features/ar_viewer/states/ar_scene_diagnostics_provider.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_placement_quality_chip.dart';
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

part 'ar_viewer_parts/ar_viewer_anchor_widgets.dart';
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
  ARGeospatialQualityMonitor? _geospatialQualityMonitor;
  final ValueNotifier<JejakuGeospatialAssessment> _placementAssessment =
      ValueNotifier<JejakuGeospatialAssessment>(
    const JejakuGeospatialAssessment.initial(),
  );
  DateTime? _cloudAnchorMaintenanceCheckAt;
  Timer? _cloudAnchorMaintenanceTimer;
  Timer? _viewerPoseRefreshTimer;
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _positionSubscription;
  final Set<Timer> _boundedTimers = <Timer>{};
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
    WidgetsBinding.instance.addObserver(this);
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

  bool _backgrounded = false;

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
    // Stop GPS/compass streams and the sensor refresh while the app is not
    // visible; they only burn battery.
    _viewerPoseRefreshTimer?.cancel();
    _viewerPoseRefreshTimer = null;
    unawaited(_compassSubscription?.cancel());
    _compassSubscription = null;
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    final controller = _arController;
    if (controller != null && !controller.isDisposed) {
      unawaited(controller.pause().catchError((Object _) {}));
    }
  }

  void _resumeLiveTracking() {
    if (!_backgrounded) {
      return;
    }
    _backgrounded = false;
    if (!mounted) {
      return;
    }
    final controller = _arController;
    if (controller != null && !controller.isDisposed) {
      unawaited(controller.resume().catchError((Object _) {}));
    }
    if (ref.read(arViewerLivePoseTrackingProvider)) {
      _startViewerPoseTracking();
    }
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
    setState(() => _nativeSceneFingerprint = null);
    _scheduleNativeSceneSync();
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

  /// Like [Future.timeout], but the timer is owned by this state and cancelled
  /// in [dispose], so a slow platform call can never leave a timer running
  /// after the screen is gone. After disposal the returned future simply never
  /// completes.
  Future<T> _withinBounds<T>(
    Future<T> operation,
    Duration limit, {
    T Function()? onTimeout,
  }) {
    final completer = Completer<T>();
    late final Timer timer;
    timer = Timer(limit, () {
      _boundedTimers.remove(timer);
      if (completer.isCompleted) {
        return;
      }
      if (onTimeout != null) {
        completer.complete(onTimeout());
      } else {
        completer.completeError(TimeoutException('Timed out', limit));
      }
    });
    _boundedTimers.add(timer);
    operation.then<void>(
      (value) {
        timer.cancel();
        _boundedTimers.remove(timer);
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        timer.cancel();
        _boundedTimers.remove(timer);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    return completer.future;
  }

  Future<void> _startPositionTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    if (!mounted) {
      return;
    }
    try {
      final serviceEnabled = await _withinBounds(
        Geolocator.isLocationServiceEnabled(),
        const Duration(milliseconds: 700),
        onTimeout: () => false,
      );
      if (!mounted || !serviceEnabled) {
        return;
      }
      var permission = await _withinBounds(
        Geolocator.checkPermission(),
        const Duration(milliseconds: 700),
      );
      if (permission == LocationPermission.denied) {
        permission = await _withinBounds(
          Geolocator.requestPermission(),
          const Duration(seconds: 2),
        );
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
    _stopGeospatialQualityMonitor();
    _placementAssessment.dispose();
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
    WidgetsBinding.instance.removeObserver(this);
    _viewerPoseRefreshTimer?.cancel();
    _viewerPoseRefreshTimer = null;
    for (final timer in _boundedTimers) {
      timer.cancel();
    }
    _boundedTimers.clear();
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
                          const SizedBox(width: 8),
                          ValueListenableBuilder<JejakuGeospatialAssessment>(
                            valueListenable: _placementAssessment,
                            builder: (context, assessment, _) {
                              return ARPlacementQualityChip(
                                key: const ValueKey('ar_placement_quality_chip'),
                                assessment: assessment,
                              );
                            },
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
    _startGeospatialQualityMonitor(controller);
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
      final hits = await _withinBounds(
        controller.hitTest(0.5, 0.5),
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
      return await _decodeImage(cameraBytes);
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
      return await picture.toImage(width, height);
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
