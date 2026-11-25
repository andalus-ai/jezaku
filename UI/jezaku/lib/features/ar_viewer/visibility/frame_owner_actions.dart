import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_rule.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

/// What the viewer may do to a frame they are looking at, beyond looking.
///
/// Editing tools (change the frame, calibrate, re-hang, open the owner's
/// details) work on the on-device store, so they belong to the frame's owner
/// only. Someone else's frame, a friend's included, is view-only here. Screens
/// ask this class instead of comparing owner ids themselves, so one rule
/// covers every surface.
class FrameOwnerActions {
  const FrameOwnerActions._(this.isOwner);

  factory FrameOwnerActions.of(
    AnchorMemory memory,
    FrameViewerContext viewer,
  ) {
    return FrameOwnerActions._(
      viewer.relationTo(memory) == FrameViewerRelation.owner,
    );
  }

  final bool isOwner;

  bool get canChangeFrame => isOwner;
  bool get canCalibrate => isOwner;
  bool get canRehang => isOwner;
  bool get canOpenDetails => isOwner;
}
