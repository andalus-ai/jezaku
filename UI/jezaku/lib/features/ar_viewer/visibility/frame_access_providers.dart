import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_access.dart';
import 'package:jejaku/features/ar_viewer/visibility/frame_visibility_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/viewer_location_provider.dart';
import 'package:jejaku/features/remote_frames/states/viewer_anchors_provider.dart';

/// Which frame, and whether the screen asking was opened on site.
typedef FrameAccessRequest = ({String memoryId, bool alreadyOnSite});

/// Whether a surface outside the AR viewer may open the frame [memoryId] from
/// where the viewer stands. See [FrameAccess].
///
/// A screen that the viewer opened on site (the photo page) passes
/// `alreadyOnSite: true`; a list that links to a frame passes false.
final frameAccessProvider =
    Provider.family<FrameAccess, FrameAccessRequest>((ref, request) {
  AnchorMemory? memory;
  for (final candidate in ref.watch(viewerAnchorsProvider)) {
    if (candidate.id == request.memoryId) {
      memory = candidate;
      break;
    }
  }
  return FrameAccessResolver(
    policy: ref.watch(frameVisibilityPolicyProvider),
  ).resolve(
    memory: memory,
    viewer: ref.watch(frameViewerContextProvider),
    location: ref.watch(viewerLocationProvider),
    alreadyOnSite: request.alreadyOnSite,
  );
});
