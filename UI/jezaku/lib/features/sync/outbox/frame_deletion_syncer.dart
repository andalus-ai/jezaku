import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/sync/outbox/frame_outbox_processor.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:jejaku/features/sync/outbox/pending_deletion_store.dart';

/// The one call the deletion sync needs from the memory service.
abstract interface class FrameDeletionApi {
  Future<void> deleteFrame({required String serverMemoryId});
}

/// Tells the memory service about frames the owner deleted on this device.
///
/// The frame is gone from the device the moment it is deleted, so what is
/// still to be sent is kept as a [PendingDeletion] in a [PendingDeletionStore]
/// until the service has confirmed it. A lost connection, a busy service or a
/// lost sign-in stops the pass; a frame the service no longer has (404) counts
/// as deleted; any other refusal keeps the record and moves on, so nothing is
/// dropped without the service having answered.
class FrameDeletionSyncer {
  FrameDeletionSyncer({
    required FrameDeletionApi api,
    required PendingDeletionStore store,
    DateTime Function()? clock,
  })  : _api = api,
        _store = store,
        _clock = clock ?? DateTime.now;

  final FrameDeletionApi _api;
  final PendingDeletionStore _store;
  final DateTime Function() _clock;

  Future<int>? _running;

  /// How many deletions still wait for the service.
  int get pendingCount => _store.load().length;

  /// Remembers that [serverMemoryId] has to be deleted on the service. Asking
  /// twice for the same frame keeps one record.
  Future<void> record({required String serverMemoryId, String? ownerId}) {
    final waiting = _store.load();
    if (waiting.any((d) => d.serverMemoryId == serverMemoryId)) {
      return Future<void>.value();
    }
    return _store.save([
      ...waiting,
      PendingDeletion(
        serverMemoryId: serverMemoryId,
        ownerId: ownerId,
        deletedAt: _clock().toUtc(),
      ),
    ]);
  }

  /// Sends the deletions of [userId]'s frames and returns how many the service
  /// confirmed. Does nothing without a signed-in user. A call while a pass is
  /// running joins it.
  Future<int> run({required String? userId}) {
    if (userId == null) {
      return Future<int>.value(0);
    }
    return _running ??= _pass(userId).whenComplete(() => _running = null);
  }

  Future<int> _pass(String userId) async {
    var done = 0;
    final due = [
      for (final deletion in _store.load())
        if (deletion.ownerId == null || deletion.ownerId == userId) deletion,
    ];
    for (final deletion in due) {
      try {
        await _api.deleteFrame(serverMemoryId: deletion.serverMemoryId);
      } catch (error) {
        final alreadyGone = error is ApiFailure && error.statusCode == 404;
        if (!alreadyGone) {
          if (FrameOutboxProcessor.classify(error) == OutboxHold.rejected) {
            // The service refuses this one (for example it belongs to someone
            // else). That says nothing about the next one.
            continue;
          }
          return done;
        }
      }
      await _forget(deletion.serverMemoryId);
      done++;
    }
    return done;
  }

  Future<void> _forget(String serverMemoryId) {
    return _store.save([
      for (final deletion in _store.load())
        if (deletion.serverMemoryId != serverMemoryId) deletion,
    ]);
  }
}
