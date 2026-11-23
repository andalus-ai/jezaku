import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';

/// Jezaku is tied to physical presence: a frame can be seen only by someone
/// standing within this many metres of where it hangs. The area follows the
/// viewer, so walking reveals the frames around the new spot.
const double defaultFrameViewRadiusMeters = 20;

/// A frame the viewer could already see stays visible this much farther out,
/// so GPS jitter at the 20 m edge does not make it blink in and out. A frame
/// that was not visible still needs the viewer to be inside the radius.
const double defaultFrameExitMarginMeters = 5;

class FramePhysicalRadiusRule implements FrameVisibilityRule {
  const FramePhysicalRadiusRule({
    this.radiusMeters = defaultFrameViewRadiusMeters,
    this.exitMarginMeters = defaultFrameExitMarginMeters,
  });

  final double radiusMeters;
  final double exitMarginMeters;

  @override
  FrameRuleStage get stage => FrameRuleStage.proximity;

  @override
  FrameVisibilityDecision evaluate(
    FrameVisibilityCandidate candidate,
    FrameViewerContext viewer,
  ) {
    final distance = candidate.horizontalDistanceMeters;
    // An unknown distance fails closed rather than revealing the frame.
    final limit = candidate.wasViewable
        ? radiusMeters + exitMarginMeters
        : radiusMeters;
    final inside = distance.isFinite && distance <= limit;
    return inside
        ? const FrameVisibilityDecision.visible()
        : const FrameVisibilityDecision.hidden(
            FrameHiddenReason.outsidePhysicalRadius,
          );
  }
}
