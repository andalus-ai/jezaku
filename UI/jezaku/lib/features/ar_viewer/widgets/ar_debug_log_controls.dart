import 'package:flutter/material.dart';
import 'package:jejaku/features/ar_viewer/services/ar_debug_log.dart';

/// Switch, copy and clear controls for the AR debug log.
///
/// Stateless about the log itself: it only reads [log.enabled] and
/// [log.location] and forwards actions, so the screen decides how to copy or
/// clear.
class ARDebugLogControls extends StatefulWidget {
  const ARDebugLogControls({
    super.key,
    required this.log,
    required this.onCopy,
    required this.onClear,
  });

  final ARDebugLog log;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  @override
  State<ARDebugLogControls> createState() => _ARDebugLogControlsState();
}

class _ARDebugLogControlsState extends State<ARDebugLogControls> {
  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final theme = Theme.of(context);
    final location = log.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          key: const ValueKey('ar_debug_log_switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Record AR debug log'),
          subtitle: Text(
            'Prints to the terminal and saves to a file on this phone, so it '
            'survives a dropped debug connection.',
            style: theme.textTheme.bodySmall,
          ),
          value: log.enabled,
          onChanged: (value) => setState(() => log.enabled = value),
        ),
        if (location != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText(
              location,
              key: const ValueKey('ar_debug_log_location'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('ar_debug_log_copy_button'),
                onPressed: widget.onCopy,
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy debug log'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const ValueKey('ar_debug_log_clear_button'),
              onPressed: widget.onClear,
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}
