import 'package:jejaku/features/home/models/anchor_memory.dart';

/// Why a frame is not shown to the viewer. Kept as data so the UI and
/// diagnostics can react without re-deriving the rule that fired.
enum FrameHiddenReason {
  /// The frame's audience does not include this viewer.
  notShared,

  /// Moderation removed the frame from view.
  moderated,

  /// The viewer is not physically close enough to the frame.
  outsidePhysicalRadius,
}

/// When a rule is evaluated.
///
/// [eligibility] rules do not depend on where the viewer stands, so their
/// result is stable while walking (who may see it). [proximity] rules depend on
/// the viewer's live position (can they see it from here).
enum FrameRuleStage { eligibility, proximity }

/// A frame being judged, with its distance from the viewer on the ground.
class FrameVisibilityCandidate {
  const FrameVisibilityCandidate({
    required this.memory,
    required this.horizontalDistanceMeters,
    this.wasViewable = false,
  });

  final AnchorMemory memory;
  final double horizontalDistanceMeters;

  /// Whether the viewer could see this frame a moment ago. Proximity rules use
  /// it to avoid flicker at the edge of the radius.
  final bool wasViewable;
}

/// Who the viewer is relative to a frame's author.
enum FrameViewerRelation { owner, friend, none }

/// What the rules need to know about the viewer.
class FrameViewerContext {
  const FrameViewerContext({required this.relationTo});

  /// Every memory in the on-device store is the viewer's own: they captured or
  /// published it here. Replace with a context fed by the backend once frames
  /// from other people carry an owner id and the social graph is wired.
  const FrameViewerContext.localStore()
      : relationTo = _ownerOfEverything;

  /// The real graph: frames without an author id were captured on this device
  /// and are the viewer's own; frames by [userId] are their own; frames by a
  /// user in [friendIds] are a friend's; anyone else is a stranger.
  FrameViewerContext.forUser({
    required String? userId,
    Set<String> friendIds = const {},
  }) : relationTo = ((memory) {
          final ownerId = memory.ownerId;
          if (ownerId == null || ownerId == userId) {
            return FrameViewerRelation.owner;
          }
          return friendIds.contains(ownerId)
              ? FrameViewerRelation.friend
              : FrameViewerRelation.none;
        });

  /// Demo and prototyping: anyone who is not the owner counts as a friend, so
  /// friends-only frames show. Production uses the real graph instead.
  FrameViewerContext.everyoneIsAFriend(FrameViewerContext base)
      : relationTo = ((memory) {
          final relation = base.relationTo(memory);
          return relation == FrameViewerRelation.none
              ? FrameViewerRelation.friend
              : relation;
        });

  final FrameViewerRelation Function(AnchorMemory memory) relationTo;

  static FrameViewerRelation _ownerOfEverything(AnchorMemory memory) =>
      FrameViewerRelation.owner;
}

sealed class FrameVisibilityDecision {
  const FrameVisibilityDecision();

  const factory FrameVisibilityDecision.visible() = FrameVisible;
  const factory FrameVisibilityDecision.hidden(FrameHiddenReason reason) =
      FrameHidden;

  bool get isVisible => this is FrameVisible;
}

final class FrameVisible extends FrameVisibilityDecision {
  const FrameVisible();
}

final class FrameHidden extends FrameVisibilityDecision {
  const FrameHidden(this.reason);

  final FrameHiddenReason reason;
}

/// One rule in the frame visibility policy. Add a rule by implementing this
/// and listing it in [FrameVisibilityPolicy]; no screen needs to change.
abstract interface class FrameVisibilityRule {
  FrameRuleStage get stage;

  FrameVisibilityDecision evaluate(
    FrameVisibilityCandidate candidate,
    FrameViewerContext viewer,
  );
}
