import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/frame_audience.dart';

/// A viewer sees public frames, friends' frames and their own frames. The
/// backend remains authoritative; this is the client's defence in depth.
///
/// Friends-only frames need a friend relation: the author's id must be in the
/// viewer's friend list (see `FrameViewerContext.forUser`).
class FrameAudienceRule implements FrameVisibilityRule {
  const FrameAudienceRule();

  @override
  FrameRuleStage get stage => FrameRuleStage.eligibility;

  @override
  FrameVisibilityDecision evaluate(
    FrameVisibilityCandidate candidate,
    FrameViewerContext viewer,
  ) {
    final AnchorMemory memory = candidate.memory;
    final relation = viewer.relationTo(memory);
    final allowed = switch (memory.audience) {
      FrameAudience.public => true,
      FrameAudience.friends => relation != FrameViewerRelation.none,
      FrameAudience.private => relation == FrameViewerRelation.owner,
    };
    return allowed
        ? const FrameVisibilityDecision.visible()
        : const FrameVisibilityDecision.hidden(FrameHiddenReason.notShared);
  }
}
