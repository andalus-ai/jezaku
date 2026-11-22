import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/hud/ar_hud_state.dart';

void main() {
  group('ARHudState', () {
    test('default shows every panel except the recording panel', () {
      const state = ARHudState();

      for (final panel in ARHudPanel.values) {
        expect(
          state.isShown(panel),
          panel != ARHudPanel.recording,
          reason: '$panel',
        );
      }
      expect(state.preset, ARHudPreset.defaultView);
    });

    test('every panel can be hidden on its own', () {
      for (final panel in ARHudPanel.values) {
        final on = const ARHudState().withPanel(panel, enabled: true);
        final off = on.withPanel(panel, enabled: false);

        expect(off.isEnabled(panel), isFalse, reason: '$panel');
        expect(off.isShown(panel), isFalse, reason: '$panel');
        for (final other in ARHudPanel.values.where((p) => p != panel)) {
          expect(
            off.isEnabled(other),
            on.isEnabled(other),
            reason: '$panel must not change $other',
          );
        }
      }
    });

    test('changing a panel switches to the manual preset', () {
      final state = const ARHudState().withPanel(
        ARHudPanel.radar,
        enabled: false,
      );

      expect(state.preset, ARHudPreset.manual);
    });

    test('minimal keeps only the essentials', () {
      final state = const ARHudState().withPreset(ARHudPreset.minimal);

      expect(state.isShown(ARHudPanel.anchors), isTrue);
      expect(state.isShown(ARHudPanel.bottomPanel), isTrue);
      expect(state.isShown(ARHudPanel.radar), isFalse);
      expect(state.isShown(ARHudPanel.infoDashboard), isFalse);
      expect(state.isShown(ARHudPanel.statusChips), isFalse);
      expect(state.isShown(ARHudPanel.recording), isFalse);
    });

    test('picking manual keeps the current panels', () {
      final minimal = const ARHudState().withPreset(ARHudPreset.minimal);
      final manual = minimal.withPreset(ARHudPreset.manual);

      expect(manual.preset, ARHudPreset.manual);
      expect(manual.enabled, minimal.enabled);
    });

    test('hiding the whole HUD keeps each panel choice for the restore', () {
      final chosen = const ARHudState().withPanel(
        ARHudPanel.radar,
        enabled: false,
      );
      final hidden = chosen.toggledMaster();

      expect(hidden.masterVisible, isFalse);
      for (final panel in ARHudPanel.values) {
        expect(hidden.isShown(panel), isFalse, reason: '$panel');
      }
      expect(hidden.isEnabled(ARHudPanel.infoDashboard), isTrue);

      final restored = hidden.toggledMaster();
      expect(restored, chosen);
      expect(restored.isShown(ARHudPanel.radar), isFalse);
      expect(restored.isShown(ARHudPanel.infoDashboard), isTrue);
    });

    test('a preset change while the HUD is hidden keeps it hidden', () {
      final hidden = const ARHudState().toggledMaster();

      expect(
        hidden.withPreset(ARHudPreset.minimal).masterVisible,
        isFalse,
      );
    });

    test('every panel has a unique settings switch key', () {
      final keys = {for (final panel in ARHudPanel.values) panel.switchKey};

      expect(keys.length, ARHudPanel.values.length);
    });

    test('states with the same panels are equal', () {
      expect(
        const ARHudState().withPanel(ARHudPanel.radar, enabled: false),
        const ARHudState().withPanel(ARHudPanel.radar, enabled: false),
      );
    });
  });
}
