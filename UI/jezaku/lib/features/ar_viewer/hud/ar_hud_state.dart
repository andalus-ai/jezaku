import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A part of the AR viewer's heads-up display that the viewer can hide on its
/// own. Add a panel here and it gets a switch in the HUD settings sheet.
enum ARHudPanel {
  /// Photo cards drawn over the camera.
  anchors(
    label: 'Anchor overlays',
    subtitle: 'Photo cards in the camera view',
    icon: Icons.view_in_ar,
    switchKey: 'ar_hud_anchor_switch',
  ),

  /// Camera-relative guide showing where a captured frame will hang.
  aimGuide(
    label: 'Aim guide',
    subtitle: 'Frame outline in the middle of the view',
    icon: Icons.crop_free,
    switchKey: 'ar_hud_aim_switch',
  ),

  /// Placement quality and pose source chips.
  statusChips(
    label: 'Status chips',
    subtitle: 'Placement quality and tracking source',
    icon: Icons.sensors,
    switchKey: 'ar_hud_status_switch',
  ),

  /// Recenter and photo-card buttons at the top right.
  quickTools(
    label: 'Quick tools',
    subtitle: 'Recenter and photo-card buttons',
    icon: Icons.my_location,
    switchKey: 'ar_hud_tools_switch',
  ),

  /// Radar of nearby frames.
  radar(
    label: 'Radar',
    subtitle: 'Frames around you',
    icon: Icons.radar,
    switchKey: 'ar_hud_radar_switch',
  ),

  /// Scene and tracking diagnostics.
  infoDashboard(
    label: 'Info dashboard',
    subtitle: 'Scene and tracking details',
    icon: Icons.space_dashboard_outlined,
    switchKey: 'ar_hud_dashboard_switch',
  ),

  /// Recording controls.
  recording(
    label: 'Recording panel',
    subtitle: 'Hidden by default',
    icon: Icons.video_settings_outlined,
    switchKey: 'ar_hud_recording_switch',
  ),

  /// Focused frame, trail steps, and the Capture and List buttons.
  bottomPanel(
    label: 'Frame and capture panel',
    subtitle: 'Includes Capture, List and trail steps',
    icon: Icons.photo_camera_outlined,
    switchKey: 'ar_hud_bottom_panel_switch',
  );

  const ARHudPanel({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.switchKey,
  });

  final String label;
  final String subtitle;
  final IconData icon;

  /// Key of this panel's switch in the HUD settings sheet.
  final String switchKey;
}

enum ARHudPreset { defaultView, minimal, manual }

/// Which HUD panels are on, and whether the whole HUD is hidden.
///
/// Immutable: every change returns a new state. A panel being "enabled" is the
/// viewer's choice and survives hiding the whole HUD; "shown" is what is
/// actually drawn right now.
@immutable
class ARHudState {
  const ARHudState({
    this.masterVisible = true,
    this.preset = ARHudPreset.defaultView,
    this.enabled = _defaultPanels,
  });

  /// A named layout. [ARHudPreset.manual] keeps nothing, so it is only reached
  /// by changing a panel.
  factory ARHudState.fromPreset(
    ARHudPreset preset, {
    bool masterVisible = true,
  }) {
    return ARHudState(
      masterVisible: masterVisible,
      preset: preset,
      enabled: switch (preset) {
        ARHudPreset.minimal => _minimalPanels,
        ARHudPreset.defaultView || ARHudPreset.manual => _defaultPanels,
      },
    );
  }

  static const Set<ARHudPanel> _defaultPanels = {
    ARHudPanel.anchors,
    ARHudPanel.aimGuide,
    ARHudPanel.statusChips,
    ARHudPanel.quickTools,
    ARHudPanel.radar,
    ARHudPanel.infoDashboard,
    ARHudPanel.bottomPanel,
  };

  static const Set<ARHudPanel> _minimalPanels = {
    ARHudPanel.anchors,
    ARHudPanel.aimGuide,
    ARHudPanel.quickTools,
    ARHudPanel.bottomPanel,
  };

  /// False while the viewer has hidden the whole HUD with Hide UI.
  final bool masterVisible;
  final ARHudPreset preset;

  /// Panels the viewer wants on, independent of [masterVisible].
  final Set<ARHudPanel> enabled;

  /// Whether the viewer chose to have [panel] on.
  bool isEnabled(ARHudPanel panel) => enabled.contains(panel);

  /// Whether [panel] is drawn now: enabled and the HUD is not hidden.
  bool isShown(ARHudPanel panel) => masterVisible && isEnabled(panel);

  ARHudState withPanel(ARHudPanel panel, {required bool enabled}) {
    final next = {...this.enabled};
    if (enabled) {
      next.add(panel);
    } else {
      next.remove(panel);
    }
    return ARHudState(
      masterVisible: masterVisible,
      preset: ARHudPreset.manual,
      enabled: next,
    );
  }

  ARHudState withPreset(ARHudPreset preset) {
    return preset == ARHudPreset.manual
        ? ARHudState(
            masterVisible: masterVisible,
            preset: ARHudPreset.manual,
            enabled: enabled,
          )
        : ARHudState.fromPreset(preset, masterVisible: masterVisible);
  }

  ARHudState toggledMaster() => ARHudState(
        masterVisible: !masterVisible,
        preset: preset,
        enabled: enabled,
      );

  @override
  bool operator ==(Object other) {
    return other is ARHudState &&
        other.masterVisible == masterVisible &&
        other.preset == preset &&
        setEquals(other.enabled, enabled);
  }

  @override
  int get hashCode =>
      Object.hash(masterVisible, preset, Object.hashAllUnordered(enabled));
}
