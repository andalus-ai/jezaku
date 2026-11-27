import 'package:material_ui/material_ui.dart';

/// Shown over the camera while the AR session resumes after an interruption
/// (a phone call, the app in the background), and when it could not resume.
///
/// While resuming it shows a spinner and asks the person to keep scanning;
/// with an [error] it shows what went wrong and a "Restart AR" button.
class ARSessionInterruptionPanel extends StatelessWidget {
  const ARSessionInterruptionPanel({
    required this.isResuming,
    required this.onRestart,
    this.error,
    super.key,
  });

  static const restartButtonKey = ValueKey('ar_session_restart_button');

  final bool isResuming;

  /// Why the session could not resume, or null while it is still trying.
  final String? error;

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: failed ? Colors.orangeAccent : Colors.white24,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (isResuming)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orangeAccent,
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        failed
                            ? 'AR session needs to restart'
                            : 'Resuming AR session',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  failed
                      ? 'The camera session could not resume. Restart AR to '
                          'continue. $error'
                      : 'The camera may take a moment to relocalize. Keep the '
                          'app open and slowly scan the area.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (failed) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      key: restartButtonKey,
                      onPressed: onRestart,
                      child: const Text('Restart AR'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
