import 'package:ar_engine/ar_engine.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/services/ar_runtime_permission_service.dart';
import 'package:jejaku/features/ar_viewer/services/ar_viewer_health_policy.dart';
import 'package:jejaku/features/ar_viewer/states/ar_capability_providers.dart';
import 'package:jejaku/features/ar_viewer/widgets/ar_projection_backdrop.dart';
import 'package:material_ui/material_ui.dart';

/// What fills the AR viewer behind the frames: the native AR camera when it is
/// allowed and running, otherwise an [ARProjectionBackdrop] that says what
/// state it is in (asking for the camera, denied, starting, unavailable).
///
/// The viewer screen owns the session; this widget only decides what to show
/// and reports what the native view tells it through the callbacks.
class ARCameraBackdrop extends ConsumerWidget {
  const ARCameraBackdrop({
    required this.permissions,
    required this.sessionGeneration,
    required this.controller,
    required this.onRetryPermissions,
    required this.onOpenPermissionSettings,
    required this.onRefreshScene,
    required this.onViewCreated,
    required this.onSessionConfigResolved,
    required this.onSessionHealthChanged,
    required this.onSessionHealthAssessmentChanged,
    required this.onSessionDiagnosticsReportChanged,
    super.key,
  });

  /// The answer to "may the app use the camera?", still pending at first.
  final Future<ARRuntimePermissions> permissions;

  /// Changes when the native view has to be rebuilt from scratch.
  final int sessionGeneration;

  /// The running native session, used for the debug overlay.
  final ARController? controller;

  final VoidCallback onRetryPermissions;
  final VoidCallback onOpenPermissionSettings;

  /// Starts the native scene again after the camera failed.
  final VoidCallback onRefreshScene;
  final ARViewCreatedCallback onViewCreated;
  final ARSessionConfigResolvedCallback onSessionConfigResolved;
  final ARSessionHealthChangedCallback onSessionHealthChanged;
  final ARSessionHealthAssessmentChangedCallback
      onSessionHealthAssessmentChanged;
  final ARSessionDiagnosticsReportChangedCallback
      onSessionDiagnosticsReportChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<ARRuntimePermissions>(
      future: permissions,
      builder: (context, permissionSnapshot) {
        final granted = permissionSnapshot.data;
        if (granted == null) {
          return const ARProjectionBackdrop(statusLabel: 'Requesting camera');
        }
        if (!granted.cameraGranted) {
          return ARProjectionBackdrop(
            statusLabel: granted.statusLabel,
            message: granted.guidanceLabel,
            actionLabel:
                granted.shouldOpenSettings ? 'Open settings' : 'Grant access',
            onAction: granted.shouldOpenSettings
                ? onOpenPermissionSettings
                : onRetryPermissions,
          );
        }
        final sessionConfig = ref.watch(arViewerSessionConfigProvider);
        return sessionConfig.when(
          data: (config) => _nativeCamera(config),
          loading: () => const ARProjectionBackdrop(
            statusLabel: 'Preparing AR session',
          ),
          error: (error, _) => ARProjectionBackdrop(
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

  Widget _nativeCamera(ARSessionConfig config) {
    return Stack(
      children: [
        Positioned.fill(
          child: ARWidget(
            key: ValueKey('native_ar_hanging_photo_view_$sessionGeneration'),
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
            loadingWidget: const ARProjectionBackdrop(
              statusLabel: 'Starting AR camera',
            ),
            errorBuilder: (context, error) => ARProjectionBackdrop(
              statusLabel: 'AR camera unavailable',
              message: '$error',
              actionLabel: 'Retry',
              onAction: onRefreshScene,
            ),
            onARViewCreated: onViewCreated,
            onSessionConfigResolved: onSessionConfigResolved,
            onSessionHealthChanged: onSessionHealthChanged,
            onSessionHealthAssessmentChanged: onSessionHealthAssessmentChanged,
            onSessionDiagnosticsReportChanged:
                onSessionDiagnosticsReportChanged,
            sessionHealthPolicy: ARViewerHealthPolicy.viewing,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: ARReticlePainter()),
          ),
        ),
        // Keep the low-level AR engine HUD available during local
        // device validation without exposing diagnostic overlays in
        // release builds or changing normal user interactions.
        if (kDebugMode && controller != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ARDebugOverlay(
                controller: controller!,
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
  }
}
