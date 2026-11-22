import 'package:jejaku/features/ar_viewer/models/ar_memory_projection.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_audience_rule.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_moderation_rule.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_physical_radius_rule.dart';
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
  }) {
    return FrameVisibilityPolicy(
      rules: [
        const FrameAudienceRule(),
        const FrameModerationRule(),
        FramePhysicalRadiusRule(radiusMeters: radiusMeters),
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
  List<ARMemoryProjection> viewable(
    List<ARMemoryProjection> projections,
    FrameViewerContext viewer,
  ) {
    return _filter(projections, viewer, null);
  }

  List<ARMemoryProjection> _filter(
    List<ARMemoryProjection> projections,
    FrameViewerContext viewer,
    FrameRuleStage? stage,
  ) {
    return [
      for (final projection in projections)
        if (evaluate(
          FrameVisibilityCandidate(
            memory: projection.memory,
            horizontalDistanceMeters:
                projection.projection.horizontalDistanceMeters,
          ),
          viewer,
          stage: stage,
        ).isVisible)
          projection,
    ];
  }
}
