/// Generic Flutter AR runtime and platform contract (v0.4.0).
///
/// Registered plugin targets:
/// - Android: ARCore native adapter.
/// - iOS: ARKit native adapter.
/// - Web: WebXR immersive-AR adapter.
/// - macOS: webcam input with synthetic world pose/plane/hit-test data.
/// - Windows: experimental synthetic preview/demo adapter, not physical AR.
///
/// Linux is not registered in this package's Flutter plugin manifest. Target
/// registration does not imply equivalent feature support or tracking fidelity;
/// query capabilities and consult the package README before enabling features.
library ar_engine;

// ── Core session ──────────────────────────────────────────────────────────────
export 'src/ar_controller.dart';
export 'src/ar_widget.dart';
export 'src/ar_session_config.dart';
export 'src/ar_capabilities.dart';
export 'src/ar_session_health.dart';
export 'src/ar_session_health_assessment.dart';
export 'src/ar_session_health_monitor.dart';
export 'src/ar_capture_diagnostics.dart';
export 'src/ar_capture_capability.dart';
export 'src/ar_diagnostics_timeline.dart';
export 'src/ar_diagnostics_report.dart';
export 'src/ar_diagnostics_report_diff.dart';
export 'src/ar_runtime_diagnostics.dart';

// ── Scene entities ────────────────────────────────────────────────────────────
export 'src/ar_model_asset.dart';
export 'src/ar_model_asset_validation.dart';
export 'src/ar_node.dart';
export 'src/ar_anchor.dart';
export 'src/ar_plane.dart';
export 'src/ar_camera.dart';
export 'src/ar_hit_test.dart';
export 'src/ar_light.dart';

// ── High-level scene management ───────────────────────────────────────────────
export 'src/ar_scene_manager.dart';

// ── Math ──────────────────────────────────────────────────────────────────────
export 'src/models/ar_vector3.dart';
export 'src/models/ar_quaternion.dart';
export 'src/models/ar_matrix4.dart';
export 'src/models/ar_pose.dart';

// ── Animation ─────────────────────────────────────────────────────────────────
export 'src/animation/ar_animation.dart';

// ── Physics ───────────────────────────────────────────────────────────────────
export 'src/physics/ar_physics.dart';

// ── Measurement ───────────────────────────────────────────────────────────────
export 'src/ar_measurement.dart';

// ── Ray casting / intersection / frustum culling ──────────────────────────────
export 'src/ar_ray.dart';

// ── Gestures ─────────────────────────────────────────────────────────────────
export 'src/gestures/ar_gesture_handler.dart';

// ── Image tracking ────────────────────────────────────────────────────────────
export 'src/image_tracking/ar_image_tracker.dart';

// ── Portal effects ────────────────────────────────────────────────────────────
export 'src/portal/ar_portal.dart';

// ── Occlusion ────────────────────────────────────────────────────────────────
export 'src/occlusion/ar_occlusion.dart';

// ── Cloud anchors ─────────────────────────────────────────────────────────────
export 'src/cloud_anchors/ar_cloud_anchor.dart';

// ── Geospatial anchors ───────────────────────────────────────────────────────
export 'src/geospatial/ar_geospatial.dart';
export 'src/geospatial/ar_geospatial_status.dart';

// ── Screen recording ─────────────────────────────────────────────────────────
export 'src/recording/ar_screen_recorder.dart';

// ── Utilities ─────────────────────────────────────────────────────────────────
export 'src/utils/ar_lod_manager.dart';
export 'src/utils/ar_environment_probe.dart';
export 'src/utils/ar_spatial_audio.dart';
export 'src/utils/ar_node_builder.dart';
export 'src/utils/ar_scene_serializer.dart';

// ── Body tracking ─────────────────────────────────────────────────────────────
export 'src/ar_body_tracker.dart';

// ── Debug ─────────────────────────────────────────────────────────────────────
export 'src/debug/ar_debug_overlay.dart';
export 'src/debug/ar_mini_map.dart';

// ── Platform interface ────────────────────────────────────────────────────────
export 'src/platform/ar_platform_interface.dart';
export 'src/platform/ar_method_channel.dart';

// ── Exceptions ────────────────────────────────────────────────────────────────
export 'src/exceptions/ar_exceptions.dart';
