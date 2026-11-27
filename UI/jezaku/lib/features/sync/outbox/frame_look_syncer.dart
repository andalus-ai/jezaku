import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/frame_outbox_processor.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';

/// The one call the look sync needs from the memory service.
abstract interface class FrameLookApi {
  Future<void> updateFrameStyle({
    required String serverMemoryId,
    required String ownerId,
    required String frameStyle,
  });
}

/// Tells the memory service about look changes the owner made to frames that
/// are already published.
///
/// There is no queue: whether a frame still needs it is read from the frame
/// itself ([AnchorMemory.needsFrameLookSync]), which is saved on the device,
/// so a change made offline is sent on a later pass and nothing is lost when
/// the app is closed. A look is cosmetic, so a frame the service refuses is
/// skipped and the pass goes on; a lost connection, a busy service or a lost
/// sign-in stops the pass, as for the outbox.
class FrameLookSyncer {
  FrameLookSyncer({
    required FrameLookApi api,
    required List<AnchorMemory> Function() memories,
    required void Function(String memoryId, String lookId) onSynced,
  })  : _api = api,
        _memories = memories,
        _onSynced = onSynced;

  final FrameLookApi _api;
  final List<AnchorMemory> Function() _memories;
  final void Function(String memoryId, String lookId) _onSynced;

  Future<int>? _running;

  /// Sends every pending look change of [userId]'s frames and returns how many
  /// the service accepted. Does nothing without a signed-in user. A call while
  /// a pass is running joins it.
  Future<int> run({required String? userId}) {
    if (userId == null) {
      return Future<int>.value(0);
    }
    return _running ??= _pass(userId).whenComplete(() => _running = null);
  }

  Future<int> _pass(String userId) async {
    var sent = 0;
    final pending = [
      for (final memory in _memories())
        if (memory.needsFrameLookSync &&
            (memory.ownerId == null || memory.ownerId == userId))
          memory,
    ];
    for (final memory in pending) {
      final serverId = memory.serverMemoryId!;
      final look = memory.frameLookId;
      try {
        await _api.updateFrameStyle(
          serverMemoryId: serverId,
          ownerId: userId,
          frameStyle: look,
        );
      } catch (error) {
        final hold = FrameOutboxProcessor.classify(error);
        if (hold == OutboxHold.rejected) {
          // The service refuses this frame (for example it was removed). That
          // says nothing about the next one.
          continue;
        }
        return sent;
      }
      // Marks the look that was sent, so a change made while the call was
      // running still counts as pending.
      _onSynced(memory.id, look);
      sent++;
    }
    return sent;
  }
}
