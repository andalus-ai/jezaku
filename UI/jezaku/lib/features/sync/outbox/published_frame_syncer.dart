import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/sync/outbox/frame_outbox_processor.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';

/// Tells the memory service about one kind of change the owner made to frames
/// that are already published (their look, who they are shared with).
///
/// There is no queue: whether a frame still needs it is read from the frame
/// itself ([needsSync]), which is saved on the device, so a change made
/// offline is sent on a later pass and nothing is lost when the app is closed.
///
/// A lost connection, a busy service or a lost sign-in stops the pass, as for
/// the outbox. A frame the service refuses (for example it was removed) is
/// reported through [onRejected] and skipped, which says nothing about the
/// next one.
class PublishedFrameSyncer<T> {
  PublishedFrameSyncer({
    required List<AnchorMemory> Function() memories,
    required bool Function(AnchorMemory memory) needsSync,
    required T Function(AnchorMemory memory) valueOf,
    required Future<void> Function(
      AnchorMemory memory,
      String userId,
      T value,
    ) send,
    required void Function(String memoryId, T value) onSynced,
    void Function(String memoryId)? onRejected,
  })  : _memories = memories,
        _needsSync = needsSync,
        _valueOf = valueOf,
        _send = send,
        _onSynced = onSynced,
        _onRejected = onRejected;

  final List<AnchorMemory> Function() _memories;
  final bool Function(AnchorMemory memory) _needsSync;
  final T Function(AnchorMemory memory) _valueOf;
  final Future<void> Function(AnchorMemory memory, String userId, T value)
      _send;
  final void Function(String memoryId, T value) _onSynced;
  final void Function(String memoryId)? _onRejected;

  Future<int>? _running;

  /// Sends every pending change of [userId]'s frames and returns how many the
  /// service accepted. Does nothing without a signed-in user. A call while a
  /// pass is running joins it.
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
        if (_needsSync(memory) &&
            (memory.ownerId == null || memory.ownerId == userId))
          memory,
    ];
    for (final memory in pending) {
      final value = _valueOf(memory);
      try {
        await _send(memory, userId, value);
      } catch (error) {
        final hold = FrameOutboxProcessor.classify(error);
        if (hold == OutboxHold.rejected) {
          _onRejected?.call(memory.id);
          continue;
        }
        return sent;
      }
      // Marks the value that was sent, so a change made while the call was
      // running still counts as pending.
      _onSynced(memory.id, value);
      sent++;
    }
    return sent;
  }
}
