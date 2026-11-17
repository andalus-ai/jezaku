import 'package:material_ui/material_ui.dart';
import 'package:jejaku/features/trails/models/ar_trail_session.dart';
import 'package:jejaku/features/trails/services/trail_launch_planner.dart';

/// Asks whether to replace the trail in progress with [requested]. Resolves to
/// `null` only if the route is torn down underneath it.
Future<TrailLaunchConflictChoice?> showTrailLaunchConflictDialog({
  required BuildContext context,
  required ARTrailProgress active,
  required ARTrailSession requested,
}) {
  return showDialog<TrailLaunchConflictChoice>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        key: const ValueKey('ar_trail_conflict_dialog'),
        title: const Text('Active trail in progress'),
        content: Text(
          'You are already on "${active.session.title}" at '
          '${active.currentStopLabel} '
          '(${active.progressLabel}). Start '
          '"${requested.title}" instead?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('ar_trail_conflict_cancel_button'),
            onPressed: () => Navigator.of(context).pop(
              TrailLaunchConflictChoice.cancel,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('ar_trail_conflict_replace_button'),
            onPressed: () => Navigator.of(context).pop(
              TrailLaunchConflictChoice.replace,
            ),
            child: const Text('Replace'),
          ),
          FilledButton(
            key: const ValueKey('ar_trail_conflict_resume_button'),
            onPressed: () => Navigator.of(context).pop(
              TrailLaunchConflictChoice.resumeCurrent,
            ),
            child: const Text('Resume current'),
          ),
        ],
      );
    },
  );
}
