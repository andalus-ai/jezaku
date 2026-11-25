import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_policy.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/services/viewer_location.dart';

/// Whether a surface outside the AR viewer (social posts, notifications, the
/// photo page) may open a frame right now.
///
/// Product rule: the owner opens their own frames anywhere; everyone else,
/// friends included, only on site. Away from the frame a surface shows a
/// locked card with the place and distance, never the photo or comments.
sealed class FrameAccess {
  const FrameAccess();

  /// The viewer may open the frame (photo, comments, likes).
  const factory FrameAccess.open() = FrameAccessOpen;

  /// The frame exists for this viewer but they are not on site. [distanceMeters]
  /// is null when it is not known (no location fix, or the frame is not loaded).
  const factory FrameAccess.locked({
    double? distanceMeters,
    String? placeLabel,
  }) = FrameAccessLocked;

  /// The viewer may not see the frame at all (audience or moderation). Shown
  /// like a frame that does not exist, so nothing leaks about it.
  const factory FrameAccess.unavailable() = FrameAccessUnavailable;

  bool get isOpen => this is FrameAccessOpen;
}

final class FrameAccessOpen extends FrameAccess {
  const FrameAccessOpen();
}

final class FrameAccessLocked extends FrameAccess {
  const FrameAccessLocked({this.distanceMeters, this.placeLabel});

  final double? distanceMeters;
  final String? placeLabel;
}

final class FrameAccessUnavailable extends FrameAccess {
  const FrameAccessUnavailable();
}

/// Decides [FrameAccess] through the same policy as the AR viewer, so a rule
/// change applies to every surface at once.
class FrameAccessResolver {
  const FrameAccessResolver({required this.policy});

  final FrameVisibilityPolicy policy;

  /// [memory] is null when the frame is not among the frames this device
  /// knows (for example a post that links a frame far from here): under strict
  /// rules that is locked, never open. [alreadyOnSite] is true for a screen the viewer
  /// opened on site, so GPS jitter at the edge does not lock it mid-visit.
  FrameAccess resolve({
    required AnchorMemory? memory,
    required FrameViewerContext viewer,
    required ViewerLocation location,
    bool alreadyOnSite = false,
  }) {
    if (memory == null) {
      // Demo rules do not enforce the radius, so an unknown frame is left to
      // the viewer, as before. Strict rules fail closed.
      return policy.enforcesRadius
          ? const FrameAccess.locked()
          : const FrameAccess.open();
    }
    if (viewer.relationTo(memory) == FrameViewerRelation.owner) {
      return const FrameAccess.open();
    }
    // Only a live fix is trusted. Without one the distance would come from the
    // frame's text label ("1.2 km" reads as 1.2), which must never open a frame.
    final distance =
        location.isLive ? location.distanceToMemoryMeters(memory) : null;
    final decision = policy.evaluate(
      FrameVisibilityCandidate(
        memory: memory,
        // An unknown distance fails closed.
        horizontalDistanceMeters: distance ?? double.infinity,
        wasViewable: alreadyOnSite,
      ),
      viewer,
    );
    if (decision.isVisible) {
      return const FrameAccess.open();
    }
    final eligible = policy.evaluate(
      FrameVisibilityCandidate(
        memory: memory,
        horizontalDistanceMeters: double.infinity,
      ),
      viewer,
      stage: FrameRuleStage.eligibility,
    );
    if (!eligible.isVisible) {
      return const FrameAccess.unavailable();
    }
    return FrameAccess.locked(
      distanceMeters: distance,
      placeLabel: _placeNameOf(memory),
    );
  }

  static String? _placeNameOf(AnchorMemory memory) {
    final label = memory.locationLabel.trim();
    return label.isEmpty || label == unnamedPlaceLabel ? null : label;
  }
}
