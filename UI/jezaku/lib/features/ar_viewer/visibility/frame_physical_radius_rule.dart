import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';

/// Jezaku is tied to physical presence: a frame can be seen only by someone
/// standing within this many metres of where it hangs. The area follows the
/// viewer, so walking reveals the frames around the new spot.
const double defaultFrameViewRadiusMeters = 20;

class FramePhysicalRadiusRule implements FrameVisibilityRule {
  const FramePhysicalRadiusRule({
    this.radiusMeters = defaultFrameViewRadiusMeters,
  });

  final double radiusMeters;

  @override
  FrameRuleStage get stage => FrameRuleStage.proximity;

  @override
  FrameVisibilityDecision evaluate(
    FrameVisibilityCandidate candidate,
    FrameViewerContext viewer,
  ) {
    final distance = candidate.horizontalDistanceMeters;
    // An unknown distance fails closed rather than revealing the frame.
    final inside = distance.isFinite && distance <= radiusMeters;
    return inside
        ? const FrameVisibilityDecision.visible()
        : const FrameVisibilityDecision.hidden(
            FrameHiddenReason.outsidePhysicalRadius,
          );
  }
}
