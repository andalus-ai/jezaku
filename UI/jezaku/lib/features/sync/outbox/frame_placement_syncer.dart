import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/models/placement_offset.dart';
import 'package:jejaku/features/sync/outbox/published_frame_syncer.dart';

/// The one call the placement sync needs from the memory service.
abstract interface class FramePlacementApi {
  Future<void> updatePlacement({
    required String serverMemoryId,
    required String ownerId,
    required double latitude,
    required double longitude,
    double? altitudeMeters,
  });
}

/// Sends where the owner moved a published frame to
/// ([AnchorMemory.needsPlacementSync]).
///
/// The service holds the captured position with the manual correction applied
/// (the same position a frame is published with), so other people see the frame
/// where the owner put it. The service checks the new place like a new publish
/// and may refuse it; the frame then shows "update failed" and the change is
/// tried again on the next pass.
class FramePlacementSyncer extends PublishedFrameSyncer<PlacementOffset> {
  FramePlacementSyncer({
    required FramePlacementApi api,
    required super.memories,
    required super.onSynced,
    required void Function(String memoryId) onRejected,
  }) : super(
          needsSync: (memory) => memory.needsPlacementSync,
          valueOf: (memory) => memory.placementOffset,
          send: (memory, userId, offset) {
            final position = offset.applyTo(
              latitude: memory.latitude,
              longitude: memory.longitude,
            );
            return api.updatePlacement(
              serverMemoryId: memory.serverMemoryId!,
              ownerId: userId,
              latitude: position.latitude,
              longitude: position.longitude,
              altitudeMeters:
                  offset.raiseAltitude(memory.captureMetadata.altitudeMeters),
            );
          },
          onRejected: onRejected,
        );
}
