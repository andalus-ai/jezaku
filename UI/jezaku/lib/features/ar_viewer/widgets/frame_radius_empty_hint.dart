import 'package:material_ui/material_ui.dart';

/// Shown when no frame hangs within the viewer's physical radius.
///
/// It may point toward the viewer's own nearest frame
/// ([nearestOwnFrameMeters]); it says nothing about other people's frames, so
/// it cannot be used to find them.
class FrameRadiusEmptyHint extends StatelessWidget {
  const FrameRadiusEmptyHint({
    required this.radiusMeters,
    this.nearestOwnFrameMeters,
    super.key,
  });

  final double radiusMeters;
  final double? nearestOwnFrameMeters;

  String get message {
    final nearest = nearestOwnFrameMeters;
    if (nearest != null && nearest.isFinite) {
      return 'No frames within ${radiusMeters.round()} m. Your nearest frame '
          'is ${nearest.round()} m away; walk closer.';
    }
    return 'No frames within ${radiusMeters.round()} m. '
        'Walk around; frames appear as you get close.';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        key: const ValueKey('ar_no_frames_in_radius'),
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.directions_walk, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
