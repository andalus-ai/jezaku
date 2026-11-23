import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';

/// What the visibility policy decided for one pass over the projected frames.
class FrameVisibilityOutcome {
  const FrameVisibilityOutcome({
    required this.eligible,
    required this.viewable,
    this.nearestOwnFrameOutsideRadiusMeters,
  });

  static const empty = FrameVisibilityOutcome(
    eligible: <ARMemoryProjection>[],
    viewable: <ARMemoryProjection>[],
  );

  /// Frames the viewer may see wherever they stand. Guidance only, never drawn.
  final List<ARMemoryProjection> eligible;

  /// Frames drawn from where the viewer stands.
  final List<ARMemoryProjection> viewable;

  /// Ground distance to the viewer's own closest frame that is out of range,
  /// or null when there is none. Other people's frames are never reported, so
  /// this cannot be used to locate them.
  final double? nearestOwnFrameOutsideRadiusMeters;

  Set<String> get viewableIds => {
        for (final projection in viewable) projection.memory.id,
      };
}
