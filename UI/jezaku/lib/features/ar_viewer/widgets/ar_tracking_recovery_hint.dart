import 'package:material_ui/material_ui.dart';

/// A small card that tells the person AR tracking is lost and what to do,
/// shown while the live pose is stale.
///
/// [isRelocalizing] picks the wording: the camera is trying to find its place
/// again, or tracking is simply unavailable. [guidance] is the advice for the
/// current reason; [iconColor] follows the pose source colour of the HUD.
class ARTrackingRecoveryHint extends StatelessWidget {
  const ARTrackingRecoveryHint({
    required this.isRelocalizing,
    required this.guidance,
    required this.iconColor,
    super.key,
  });

  final bool isRelocalizing;
  final String guidance;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 224),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isRelocalizing
                ? Colors.orangeAccent.shade100
                : Colors.amberAccent.shade100,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isRelocalizing
                    ? Icons.center_focus_weak
                    : Icons.lightbulb_outline,
                color: iconColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRelocalizing
                          ? 'Recovering AR tracking'
                          : 'AR tracking unavailable',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guidance,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
