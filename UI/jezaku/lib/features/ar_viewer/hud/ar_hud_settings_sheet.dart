import 'package:flutter/material.dart';
import 'package:jejaku/features/ar_viewer/hud/ar_hud_state.dart';

/// Bottom sheet that switches each AR HUD panel on or off.
///
/// [onChanged] is called with every new state so the viewer updates live while
/// the sheet is open.
class ARHudSettingsSheet extends StatefulWidget {
  const ARHudSettingsSheet({
    required this.initial,
    required this.onChanged,
    super.key,
  });

  final ARHudState initial;
  final ValueChanged<ARHudState> onChanged;

  @override
  State<ARHudSettingsSheet> createState() => _ARHudSettingsSheetState();
}

class _ARHudSettingsSheetState extends State<ARHudSettingsSheet> {
  late ARHudState _state = widget.initial;

  void _update(ARHudState next) {
    setState(() => _state = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
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
            SegmentedButton<ARHudPreset>(
              key: const ValueKey('ar_hud_preset_segments'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ARHudPreset.defaultView,
                  label: Text('Default'),
                ),
                ButtonSegment(
                  value: ARHudPreset.minimal,
                  label: Text('Minimal'),
                ),
                ButtonSegment(
                  value: ARHudPreset.manual,
                  label: Text('Manual'),
                ),
              ],
              selected: {_state.preset},
              onSelectionChanged: (selection) {
                _update(_state.withPreset(selection.first));
              },
            ),
            const SizedBox(height: 8),
            for (final panel in ARHudPanel.values)
              SwitchListTile(
                key: ValueKey(panel.switchKey),
                contentPadding: EdgeInsets.zero,
                secondary: Icon(panel.icon),
                title: Text(panel.label),
                subtitle: Text(panel.subtitle),
                value: _state.isEnabled(panel),
                onChanged: (value) {
                  _update(_state.withPanel(panel, enabled: value));
                },
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('ar_hud_settings_done_button'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
