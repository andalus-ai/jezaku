part of '../ar_viewer_screen.dart';

/// Top-of-screen HUD controls, kept out of the (very large) screen state.
///
/// Everything except Back and the Hide/Show UI button is hidden while
/// `_hud.masterVisible` is false.
extension _ARViewerTopBar on _ARViewerScreenState {
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

  void _showHudSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ARHudSettingsSheet(
        initial: _hud,
        onChanged: _applyHudState,
      ),
    );
  }

  /// Back, Hide/Show UI and (when visible) HUD settings.
  Widget _buildTopLeftControls(BuildContext context) {
    return Positioned(
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
          _GlassPillButton(
            key: const ValueKey('ar_hud_visibility_button'),
            label: _hud.masterVisible ? 'Hide UI' : 'Show UI',
            icon: _hud.masterVisible
                ? Icons.fullscreen
                : Icons.fullscreen_exit,
            onPressed: _toggleHudVisibility,
          ),
          if (_hud.masterVisible) ...[
            const SizedBox(width: 8),
            _GlassIconButton(
              key: const ValueKey('ar_hud_settings_button'),
              tooltip: 'HUD settings',
              icon: Icons.tune,
              onPressed: () => _showHudSettingsSheet(context),
            ),
          ],
        ],
      ),
    );
  }

  /// Placement-quality and pose-source chips on their own row.
  Widget _buildStatusChips() {
    return Positioned(
      top: 68,
      left: 16,
      right: 16,
      child: ValueListenableBuilder<JejakuGeospatialAssessment>(
        valueListenable: _placementAssessment,
        builder: (context, assessment, _) {
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ARPlacementQualityChip(
                key: const ValueKey('ar_placement_quality_chip'),
                assessment: assessment,
              ),
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
    );
  }

  /// Recenter and photo-card visibility buttons.
  Widget _buildTopRightControls(List<ARMemoryProjection> activeProjectedAnchors) {
    return Positioned(
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
            tooltip: _hud.isEnabled(ARHudPanel.anchors) ? 'Hide photo cards' : 'Show photo cards',
            icon: _hud.isEnabled(ARHudPanel.anchors)
                ? Icons.image_outlined
                : Icons.hide_image_outlined,
            onPressed: _toggleAnchorCards,
          ),
        ],
      ),
    );
  }
}
