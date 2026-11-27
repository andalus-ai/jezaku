import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/auth/states/auth_providers.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';
import 'package:jejaku/features/home/states/anchor_providers.dart';
import 'package:jejaku/features/sync/outbox/frame_outbox_processor.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:jejaku/features/sync/outbox/outbox_presentation.dart';
import 'package:jejaku/features/sync/states/frame_outbox_providers.dart';

/// What the UI knows about the outbox.
class FrameOutboxState {
  const FrameOutboxState({
    this.entries = const <OutboxEntry>[],
    this.running = false,
    this.stoppedBy,
  });

  /// The frames still waiting, oldest first.
  final List<OutboxEntry> entries;

  /// Whether a pass is sending right now.
  final bool running;

  /// Why the last pass ended early (no connection, busy service, no sign-in).
  final OutboxHold? stoppedBy;

  OutboxEntry? entryFor(String memoryId) {
    for (final entry in entries) {
      if (entry.memoryId == memoryId) {
        return entry;
      }
    }
    return null;
  }

  FrameOutboxState copyWith({
    List<OutboxEntry>? entries,
    bool? running,
    OutboxHold? stoppedBy,
    bool clearStoppedBy = false,
  }) {
    return FrameOutboxState(
      entries: entries ?? this.entries,
      running: running ?? this.running,
      stoppedBy: clearStoppedBy ? null : stoppedBy ?? this.stoppedBy,
    );
  }
}

final frameOutboxControllerProvider =
    NotifierProvider<FrameOutboxController, FrameOutboxState>(
  FrameOutboxController.new,
);

/// Runs the outbox for the app: adds captured frames, sends what is due when
/// something changes (sign-in, the app coming back, a new frame, a timer) and
/// keeps the frames' local sync status honest.
///
/// Every method does nothing when this build has no outbox (no memory or
/// media service), so callers never have to check.
class FrameOutboxController extends Notifier<FrameOutboxState> {
  Timer? _timer;

  FrameOutboxProcessor? get _processor =>
      ref.read(frameOutboxProcessorProvider);

  /// Whether frames really are sent to a server by this build.
  bool get isActive => _processor != null;

  @override
  FrameOutboxState build() {
    ref.onDispose(() => _timer?.cancel());
    return FrameOutboxState(
      entries: ref.watch(frameOutboxProcessorProvider)?.entries ?? const [],
    );
  }

  /// Puts a frame in the outbox and sends it if it can be sent now.
  Future<void> enqueue(String memoryId) async {
    final processor = _processor;
    if (processor == null) {
      return;
    }
    await processor.enqueue(memoryId);
    _publishState();
    await syncNow(force: false);
  }

  /// Sends what is waiting. With [force] the retry delays are skipped, which
  /// is right when the person asks or the app has just come back.
  Future<void> syncNow({bool force = true}) async {
    final processor = _processor;
    if (processor == null) {
      return;
    }
    state = state.copyWith(running: true);
    OutboxRunSummary? summary;
    try {
      summary = await processor.run(
        userId: ref.read(signedInUserIdProvider),
        force: force,
      );
    } finally {
      if (ref.mounted) {
        _publishState(running: false, summary: summary);
      }
    }
    // Frames published by this pass may have had their look changed while
    // they were being sent.
    await syncLooks();
  }

  /// Sends look changes of already published frames (see [FrameLookSyncer]).
  Future<void> syncLooks() async {
    final syncer = ref.read(frameLookSyncerProvider);
    if (syncer == null) {
      return;
    }
    await syncer.run(userId: ref.read(signedInUserIdProvider));
  }

  /// Lets a frame the service refused be sent again.
  Future<void> retry(String memoryId) async {
    final processor = _processor;
    if (processor == null) {
      return;
    }
    await processor.retry(memoryId);
    _publishState();
    await syncNow();
  }

  /// Gives up sending a frame. It stays on this device, marked as not sent.
  Future<void> discard(String memoryId) async {
    final processor = _processor;
    if (processor == null) {
      return;
    }
    await processor.discard(memoryId);
    ref.read(nearbyAnchorsProvider.notifier).markMemorySyncFailed(memoryId);
    _publishState();
  }

  /// Called when the signed-in user changes (and once at start): frames saved
  /// before the outbox existed are added, then everything is sent.
  Future<void> onSignedInChanged(String? userId) async {
    final processor = _processor;
    if (processor == null) {
      return;
    }
    if (userId != null) {
      for (final memory in ref.read(nearbyAnchorsProvider)) {
        if (_isLegacyWaiting(memory, userId)) {
          await processor.enqueue(memory.id);
        }
      }
    }
    await syncNow();
  }

  /// A frame still marked "queued" that was saved before the outbox existed
  /// (or while no memory service was configured) and holds a photo-type
  /// attachment.
  bool _isLegacyWaiting(AnchorMemory memory, String userId) {
    if (memory.syncStatus != AnchorSyncStatus.queued ||
        memory.syncReason != AnchorSyncReason.newCapture) {
      return false;
    }
    final owner = memory.ownerId;
    if (owner != null && owner != userId) {
      return false;
    }
    final type = memory.mediaAttachment?.type;
    return type != null &&
        type != AnchorMediaType.arRecording &&
        type != AnchorMediaType.arModel;
  }

  void _publishState({bool? running, OutboxRunSummary? summary}) {
    final processor = _processor;
    if (processor == null || !ref.mounted) {
      return;
    }
    final entries = processor.entries;
    state = FrameOutboxState(
      entries: entries,
      running: running ?? state.running,
      stoppedBy: summary == null ? state.stoppedBy : summary.stoppedBy,
    );
    _mirrorStatusToFrames(entries);
    _scheduleNextPass(entries);
  }

  /// A frame shows "failed" while the service refuses it and "queued" while
  /// it waits; "synced" is only set by the outbox when the server has it.
  void _mirrorStatusToFrames(List<OutboxEntry> entries) {
    final controller = ref.read(nearbyAnchorsProvider.notifier);
    final byId = {
      for (final memory in ref.read(nearbyAnchorsProvider)) memory.id: memory,
    };
    for (final entry in entries) {
      final memory = byId[entry.memoryId];
      if (memory == null || memory.syncStatus == AnchorSyncStatus.synced) {
        continue;
      }
      final wanted = OutboxPresentation.syncStatusFor(entry);
      if (memory.syncStatus == wanted) {
        continue;
      }
      if (wanted == AnchorSyncStatus.failed) {
        controller.markMemorySyncFailed(memory.id);
      } else {
        controller.retryMemorySync(memory.id);
      }
    }
  }

  /// Wakes the outbox when the earliest delayed frame is due, so a frame that
  /// waited for the network is sent without the person doing anything.
  void _scheduleNextPass(List<OutboxEntry> entries) {
    _timer?.cancel();
    _timer = null;
    DateTime? earliest;
    for (final entry in entries) {
      final at = entry.nextAttemptAt;
      final hold = entry.hold;
      if (at == null || hold == null || !hold.retries) {
        continue;
      }
      if (earliest == null || at.isBefore(earliest)) {
        earliest = at;
      }
    }
    if (earliest == null) {
      return;
    }
    var wait = earliest.difference(DateTime.now().toUtc());
    if (wait < const Duration(seconds: 5)) {
      wait = const Duration(seconds: 5);
    }
    _timer = Timer(wait, () {
      if (ref.mounted) {
        unawaited(syncNow(force: false));
      }
    });
  }
}
