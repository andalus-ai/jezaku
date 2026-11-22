import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

/// Who a frame was shared with. Mirrors the memory service's
/// `public | friends | private` visibility.
enum FrameAudience { private, friends, public }

/// The client model only records private versus not private (non-private
/// frames are public, as the privacy settings describe). When
/// [AnchorMemory] carries the backend's three-way visibility, map it here and
/// nowhere else.
FrameAudience frameAudienceOf(AnchorMemory memory) {
  return memory.isPrivate ? FrameAudience.private : FrameAudience.public;
}

/// A viewer sees public frames, friends' frames and their own frames. The
/// backend remains authoritative; this is the client's defence in depth.
class FrameAudienceRule implements FrameVisibilityRule {
  const FrameAudienceRule();

  @override
  FrameRuleStage get stage => FrameRuleStage.eligibility;

  @override
  FrameVisibilityDecision evaluate(
    FrameVisibilityCandidate candidate,
    FrameViewerContext viewer,
  ) {
    final relation = viewer.relationTo(candidate.memory);
    final allowed = switch (frameAudienceOf(candidate.memory)) {
      FrameAudience.public => true,
      FrameAudience.friends => relation != FrameViewerRelation.none,
      FrameAudience.private => relation == FrameViewerRelation.owner,
    };
    return allowed
        ? const FrameVisibilityDecision.visible()
        : const FrameVisibilityDecision.hidden(FrameHiddenReason.notShared);
  }
}
