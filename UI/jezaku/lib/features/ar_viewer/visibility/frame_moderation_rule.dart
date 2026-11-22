import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

/// Frames a moderator hid are never drawn, for anyone.
class FrameModerationRule implements FrameVisibilityRule {
  const FrameModerationRule();

  @override
  FrameRuleStage get stage => FrameRuleStage.eligibility;

  @override
  FrameVisibilityDecision evaluate(
    FrameVisibilityCandidate candidate,
    FrameViewerContext viewer,
  ) {
    return candidate.memory.moderationStatus == AnchorModerationStatus.hidden
        ? const FrameVisibilityDecision.hidden(FrameHiddenReason.moderated)
        : const FrameVisibilityDecision.visible();
  }
}
