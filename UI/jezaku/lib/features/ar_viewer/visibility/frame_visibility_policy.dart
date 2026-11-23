import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_audience_rule.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_moderation_rule.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_physical_radius_rule.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_outcome.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';

/// The single place that decides whether the AR viewer may show a frame.
///
/// Every surface that draws or counts frames (overlays, the native scene, the
/// radar, the list and the HUD) must go through this policy instead of
/// filtering on its own, so a new rule applies everywhere at once.
class FrameVisibilityPolicy {
  const FrameVisibilityPolicy({required this.rules});

  /// Audience, moderation, then the physical radius.
  factory FrameVisibilityPolicy.standard({
    double radiusMeters = defaultFrameViewRadiusMeters,
    double exitMarginMeters = defaultFrameExitMarginMeters,
  }) {
    return FrameVisibilityPolicy(
      rules: [
        const FrameAudienceRule(),
        const FrameModerationRule(),
        FramePhysicalRadiusRule(
          radiusMeters: radiusMeters,
          exitMarginMeters: exitMarginMeters,
        ),
      ],
    );
  }

  final List<FrameVisibilityRule> rules;

  /// The first rule that hides the frame decides; otherwise it is visible.
  /// When [stage] is given only rules of that stage run.
  FrameVisibilityDecision evaluate(
    FrameVisibilityCandidate candidate,
    FrameViewerContext viewer, {
    FrameRuleStage? stage,
  }) {
    for (final rule in rules) {
      if (stage != null && rule.stage != stage) {
        continue;
      }
      final decision = rule.evaluate(candidate, viewer);
      if (!decision.isVisible) {
        return decision;
      }
    }
    return const FrameVisibilityDecision.visible();
  }

  /// Frames this viewer is allowed to see at all, wherever they stand. Used
  /// for guidance toward a frame (such as the next trail stop), never to draw
  /// the frame itself.
  List<ARMemoryProjection> eligible(
    List<ARMemoryProjection> projections,
    FrameViewerContext viewer,
  ) {
    return _filter(projections, viewer, FrameRuleStage.eligibility);
  }

  /// Frames the viewer may see from where they stand: eligible and close
  /// enough. This is the only list the AR viewer draws.
  ///
  /// [previouslyViewableIds] are the frames drawn on the previous pass; they get
  /// the exit margin so a frame at the edge of the radius does not flicker.
  List<ARMemoryProjection> viewable(
    List<ARMemoryProjection> projections,
    FrameViewerContext viewer, {
    Set<String> previouslyViewableIds = const {},
  }) {
    return _filter(projections, viewer, null, previouslyViewableIds);
  }

  /// One pass: eligible frames, drawable frames, and the distance to the
  /// viewer's own nearest frame that is out of range (for a "walk closer" cue).
  FrameVisibilityOutcome resolve(
    List<ARMemoryProjection> projections,
    FrameViewerContext viewer, {
    Set<String> previouslyViewableIds = const {},
  }) {
    final eligibleFrames = eligible(projections, viewer);
    final viewableFrames = viewable(
      eligibleFrames,
      viewer,
      previouslyViewableIds: previouslyViewableIds,
    );
    final viewableIds = {
      for (final projection in viewableFrames) projection.memory.id,
    };
    double? nearest;
    for (final projection in eligibleFrames) {
      if (viewableIds.contains(projection.memory.id) ||
          viewer.relationTo(projection.memory) != FrameViewerRelation.owner) {
        continue;
      }
      final distance = projection.projection.horizontalDistanceMeters;
      if (distance.isFinite && (nearest == null || distance < nearest)) {
        nearest = distance;
      }
    }
    return FrameVisibilityOutcome(
      eligible: eligibleFrames,
      viewable: viewableFrames,
      nearestOwnFrameOutsideRadiusMeters: nearest,
    );
  }

  List<ARMemoryProjection> _filter(
    List<ARMemoryProjection> projections,
    FrameViewerContext viewer,
    FrameRuleStage? stage, [
    Set<String> previouslyViewableIds = const {},
  ]) {
    return [
      for (final projection in projections)
        if (evaluate(
          FrameVisibilityCandidate(
            memory: projection.memory,
            horizontalDistanceMeters:
                projection.projection.horizontalDistanceMeters,
            wasViewable: previouslyViewableIds.contains(projection.memory.id),
          ),
          viewer,
          stage: stage,
        ).isVisible)
          projection,
    ];
  }
}
