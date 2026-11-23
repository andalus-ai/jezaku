import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/my_frames/models/my_frames_filter.dart';

/// The viewer's own frames, newest first.
///
/// Until the backend feed carries an owner id (roadmap slice 5), every frame
/// in the on-device store is the viewer's own, so this is the whole store.
/// When the owner id lands, this is the one place that narrows the list.
final ownFramesProvider = Provider<List<AnchorMemory>>((ref) {
  return sortFramesNewestFirst(ref.watch(nearbyAnchorsProvider));
});
