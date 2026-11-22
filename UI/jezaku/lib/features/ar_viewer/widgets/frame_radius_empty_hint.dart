import 'package:material_ui/material_ui.dart';

/// Shown when no frame hangs within the viewer's physical radius. It says
/// nothing about frames elsewhere, so it cannot be used to find them.
class FrameRadiusEmptyHint extends StatelessWidget {
  const FrameRadiusEmptyHint({required this.radiusMeters, super.key});

  final double radiusMeters;

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
                  'No frames within ${radiusMeters.round()} m. '
                  'Walk around; frames appear as you get close.',
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
