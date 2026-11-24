import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/remote_frames/states/remote_frames_controller.dart';

/// Every frame the AR viewer may consider: the user's own (stored on this
/// device) plus other people's frames from the memory service.
///
/// Remote frames are never added to the local store, so they are not part of
/// "My frames", sync or upload. The viewer still runs all of them through the
/// frame visibility policy; nothing here decides who may see what.
final viewerAnchorsProvider = Provider<List<AnchorMemory>>((ref) {
  ref.watch(remoteFramesAutoRefreshProvider);
  final local = ref.watch(nearbyAnchorsProvider);
  final remote = ref.watch(remoteFramesProvider).anchors;
  if (remote.isEmpty) {
    return local;
  }
  final localIds = <String>{for (final memory in local) memory.id};
  return List.unmodifiable([
    ...local,
    for (final memory in remote)
      if (!localIds.contains(memory.id)) memory,
  ]);
});
