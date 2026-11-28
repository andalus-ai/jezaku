import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jezaku_ar/jezaku_ar.dart';
import 'package:jejaku/features/ar_viewer/models/ar_memory_scene_diagnostics.dart';
import 'package:jejaku/features/ar_viewer/services/ar_diagnostics_presentation.dart';
import 'package:material_ui/material_ui.dart';

/// What one capability pill in the AR HUD shows.
class ARCapabilityPill {
  const ARCapabilityPill({
    required this.icon,
    required this.label,
    required this.color,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? tooltip;
}

/// The pills that tell the person what this device's AR session can do:
/// where frames are placed (geospatial, local, paused, off), whether screen
/// recording works, and whether some native features were turned off.
///
/// Pure: the same plan, diagnostics and [ColorScheme] always give the same
/// pills, so every state (loading, failed to check, each capability) can be
/// tested without a screen.
abstract final class ARCapabilityPills {
  static List<ARCapabilityPill> forPlan(
    AsyncValue<JejakuARSessionPlan> plan,
    ARMemorySceneDiagnostics sceneDiagnostics,
    ColorScheme colors,
  ) {
    return plan.when(
      data: (plan) => _ready(plan, sceneDiagnostics, colors),
      // The check failed: show what works without native AR rather than
      // nothing.
      error: (_, __) => [
        ARCapabilityPill(
          icon: Icons.map_outlined,
          label: 'Local AR',
          color: colors.primary,
        ),
        ARCapabilityPill(
          icon: Icons.videocam_outlined,
          label: 'No rec',
          color: colors.onSurfaceVariant,
        ),
      ],
      loading: () => [
        ARCapabilityPill(
          icon: Icons.sensors,
          label: 'AR check',
          color: colors.secondary,
        ),
        ARCapabilityPill(
          icon: Icons.videocam_outlined,
          label: 'Rec check',
          color: colors.secondary,
        ),
      ],
    );
  }

  static List<ARCapabilityPill> _ready(
    JejakuARSessionPlan plan,
    ARMemorySceneDiagnostics sceneDiagnostics,
    ColorScheme colors,
  ) {
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
        ? ARDiagnosticsPresentation.sessionHealthColor(
            sceneDiagnostics,
            colors,
          )
        : capabilities.canPlaceMemories
            ? colors.primary
            : colors.onSurfaceVariant;
    final placementTooltip =
        isPlacementPaused ? placementReadiness.detailLabel : null;
    final recordingLabel =
        capabilities.recordingMode == JejakuARRecordingMode.nativeEncode
            ? 'Screen rec'
            : capabilities.recordingMode == JejakuARRecordingMode.dartFallback
                ? 'Screen fallback'
                : 'No rec';
    final recordingTooltip =
        capabilities.recordingMode == JejakuARRecordingMode.nativeEncode
            ? 'Native MP4 screen recording with AR visual overlay'
            : capabilities.recordingMode == JejakuARRecordingMode.dartFallback
                ? 'Dart fallback screen recording with AR visual overlay'
                : null;

    final downgradeLabels = plan.unsupportedFeatureLabels;
    final downgradeTooltip = downgradeLabels.isEmpty
        ? null
        : 'Disabled native features: ${downgradeLabels.join(', ')}';

    return [
      ARCapabilityPill(
        icon: placementIcon,
        label: placementLabel,
        color: placementColor,
        tooltip: placementTooltip,
      ),
      ARCapabilityPill(
        icon: Icons.videocam_outlined,
        label: recordingLabel,
        color: capabilities.canRecord ? colors.primary : colors.onSurfaceVariant,
        tooltip: recordingTooltip,
      ),
      if (plan.hasNativeDowngrades)
        ARCapabilityPill(
          icon: Icons.tune,
          label: 'AR limited',
          color: colors.tertiary,
          tooltip: downgradeTooltip,
        ),
    ];
  }
}
