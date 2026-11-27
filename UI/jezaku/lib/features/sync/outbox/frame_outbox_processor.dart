import 'package:jejaku/features/api/api_failure.dart';
import 'package:jejaku/features/sync/outbox/frame_publisher.dart';
import 'package:jejaku/features/sync/outbox/outbox_backoff.dart';
import 'package:jejaku/features/sync/outbox/outbox_entry.dart';
import 'package:jejaku/features/sync/outbox/outbox_store.dart';

/// What one pass over the outbox did.
class OutboxRunSummary {
  const OutboxRunSummary({
    this.published = 0,
    this.stillWaiting = 0,
    this.stoppedBy,
  });

  /// Frames that reached the server in this pass.
  final int published;

  /// Frames still in the outbox afterwards.
  final int stillWaiting;

  /// The problem that ended the pass early (no connection, the service is
  /// busy, or no usable sign-in), or null when it ran through.
  final OutboxHold? stoppedBy;
}

/// Sends frames that were saved on the device to the server, and keeps them
/// safe until that works.
///
/// - A frame is added with [enqueue] when it is captured and stays in the
///   store, across restarts, until the server has it.
/// - Each step (photo uploaded, frame created) is saved as soon as it
///   succeeds, so a dropped connection never costs a second upload or a
///   duplicate frame.
/// - No connection, a busy service and a missing sign-in are *held* and
///   retried; a refusal from the service is held until the user decides.
///
/// Pure of Flutter and of the network stack: the server calls go through a
/// [FramePublisher], the local frames through a [FramePublishJobSource].
class FrameOutboxProcessor {
  FrameOutboxProcessor({
    required OutboxStore store,
    required FramePublisher publisher,
    required FramePublishJobSource jobs,
    required Future<void> Function(String memoryId, String serverMemoryId)
        onPublished,
    DateTime Function()? clock,
  })  : _store = store,
        _publisher = publisher,
        _jobs = jobs,
        _onPublished = onPublished,
        _clock = clock ?? DateTime.now;

  final OutboxStore _store;
  final FramePublisher _publisher;
  final FramePublishJobSource _jobs;
  final Future<void> Function(String memoryId, String serverMemoryId)
      _onPublished;
  final DateTime Function() _clock;

  Future<OutboxRunSummary>? _running;

  /// The frames waiting to be sent, oldest first.
  List<OutboxEntry> get entries => _store.load();

  /// Adds [memoryId] to the outbox. Adding a frame that is already there does
  /// nothing.
  Future<void> enqueue(String memoryId) async {
    final entries = _store.load();
    if (entries.any((entry) => entry.memoryId == memoryId)) {
      return;
    }
    await _store.save(
      <OutboxEntry>[
        ...entries,
        OutboxEntry(memoryId: memoryId, queuedAt: _clock().toUtc()),
      ],
    );
  }

  /// Lets a frame the service refused be tried again, after the user fixed
  /// what was wrong or simply asked.
  Future<void> retry(String memoryId) async {
    await _update(
      memoryId,
      (entry) => entry.copyWith(clearHold: true, attempts: 0),
    );
  }

  /// Stops sending a frame. The frame stays on the device; only the upload is
  /// given up.
  Future<void> discard(String memoryId) async {
    final entries = _store.load();
    await _store.save(
      entries.where((entry) => entry.memoryId != memoryId).toList(),
    );
  }

  /// Sends what is due. Only one pass runs at a time: a second call while one
  /// is running gets the running pass's result.
  ///
  /// [userId] is the signed-in user, or null when nobody is. With [force] the
  /// retry delays are ignored, which is what "sync now" and a regained
  /// connection want.
  Future<OutboxRunSummary> run({
    required String? userId,
    bool force = false,
  }) {
    return _running ??= _run(userId: userId, force: force).whenComplete(() {
      _running = null;
    });
  }

  Future<OutboxRunSummary> _run({
    required String? userId,
    required bool force,
  }) async {
    var published = 0;
    OutboxHold? stoppedBy;

    // Frames whose upload finished earlier but were not acknowledged yet.
    for (final entry in _store.load().where((e) => e.isPublished)) {
      await _acknowledge(entry);
      published++;
    }

    if (userId == null) {
      await _holdAll(OutboxHold.signInRequired);
      return OutboxRunSummary(
        stillWaiting: _store.load().length,
        stoppedBy: OutboxHold.signInRequired,
      );
    }
    // A user is signed in again: frames held only for that are due.
    await _releaseSignInHolds();

    final now = _clock().toUtc();
    final due = _store
        .load()
        .where((entry) => force ? _canRetry(entry) : entry.isDue(now))
        .map((entry) => entry.memoryId)
        .toList();

    for (final memoryId in due) {
      final current = _entryFor(memoryId);
      if (current == null) {
        continue;
      }
      final outcome = await _send(current, userId);
      if (outcome.published) {
        published++;
      }
      if (outcome.stopRun) {
        stoppedBy = outcome.hold;
        break;
      }
    }
    return OutboxRunSummary(
      published: published,
      stillWaiting: _store.load().length,
      stoppedBy: stoppedBy,
    );
  }

  bool _canRetry(OutboxEntry entry) {
    final hold = entry.hold;
    return !entry.isPublished && (hold == null || hold.retries);
  }

  Future<_SendOutcome> _send(OutboxEntry start, String userId) async {
    final job = _jobs.jobFor(start.memoryId, ownerId: userId);
    if (job == null) {
      // The frame was deleted on this device while it waited.
      await discard(start.memoryId);
      return const _SendOutcome();
    }
    var entry = start;
    if (entry.stage == OutboxStage.mediaUploaded && entry.mediaId == null) {
      // A damaged record: upload the photo again rather than get stuck.
      entry = entry.copyWith(stage: OutboxStage.queued);
    }
    try {
      if (entry.stage == OutboxStage.queued) {
        final photo = job.photo;
        if (photo == null) {
          await _replace(entry.copyWith(hold: OutboxHold.unsupported));
          return const _SendOutcome(hold: OutboxHold.unsupported);
        }
        final mediaId = await _publisher.uploadPhoto(photo, ownerId: userId);
        entry = entry.copyWith(
          stage: OutboxStage.mediaUploaded,
          mediaId: mediaId,
          attempts: 0,
          clearHold: true,
        );
        await _replace(entry);
      }

      final mediaId = entry.mediaId!;
      final review = await _publisher.reviewOf(mediaId);
      if (review == MediaReview.rejected) {
        await _replace(entry.copyWith(hold: OutboxHold.rejected));
        return const _SendOutcome(hold: OutboxHold.rejected);
      }
      if (review == MediaReview.pending && job.isPublic) {
        final attempts = entry.attempts + 1;
        await _replace(
          entry.copyWith(
            hold: OutboxHold.awaitingReview,
            attempts: attempts,
            nextAttemptAt: _clock().toUtc().add(
                  OutboxBackoff.delayFor(OutboxHold.awaitingReview, attempts)!,
                ),
          ),
        );
        return const _SendOutcome(hold: OutboxHold.awaitingReview);
      }

      final serverId = await _publisher.createFrame(job, mediaId: mediaId);
      entry = entry.copyWith(
        stage: OutboxStage.published,
        serverMemoryId: serverId,
        attempts: 0,
        clearHold: true,
      );
      await _replace(entry);
      await _acknowledge(entry);
      return const _SendOutcome(published: true);
    } on Object catch (error) {
      final hold = classify(error);
      final attempts = entry.attempts + 1;
      final delay = OutboxBackoff.delayFor(hold, attempts);
      await _replace(
        entry.copyWith(
          hold: hold,
          attempts: attempts,
          nextAttemptAt: delay == null ? null : _clock().toUtc().add(delay),
        ),
      );
      return _SendOutcome(
        hold: hold,
        // The same connection, service or sign-in problem would hit every
        // other frame too, so do not spend their attempts.
        stopRun: hold == OutboxHold.offline ||
            hold == OutboxHold.serverBusy ||
            hold == OutboxHold.signInRequired,
      );
    }
  }

  /// Maps a failed call to the reason the frame has to wait.
  static OutboxHold classify(Object error) {
    if (error is! ApiFailure) {
      // An answer we could not read: keep the frame and try again later.
      return OutboxHold.serverBusy;
    }
    switch (error.reason) {
      case ApiFailureReason.network:
        return OutboxHold.offline;
      case ApiFailureReason.notAllowed:
        // 401: the session is gone. 403: the service understood the request
        // and refuses it for this user or place, which signing in again does
        // not change.
        return error.statusCode == 403
            ? OutboxHold.rejected
            : OutboxHold.signInRequired;
      case ApiFailureReason.server:
        final status = error.statusCode;
        final temporary =
            status == null || status == 408 || status == 429 || status >= 500;
        return temporary ? OutboxHold.serverBusy : OutboxHold.rejected;
    }
  }

  Future<void> _acknowledge(OutboxEntry entry) async {
    final serverId = entry.serverMemoryId;
    if (serverId != null) {
      await _onPublished(entry.memoryId, serverId);
    }
    await discard(entry.memoryId);
  }

  Future<void> _holdAll(OutboxHold hold) async {
    final entries = _store.load();
    if (entries.isEmpty) {
      return;
    }
    // Frames the service refused, or that cannot be uploaded yet, keep the
    // reason they already have; only the ones that were free to go wait.
    bool keepsItsReason(OutboxEntry e) =>
        e.isPublished || (e.hold != null && !e.hold!.retries);
    await _store.save(
      entries
          .map((e) => keepsItsReason(e) ? e : e.copyWith(hold: hold))
          .toList(),
    );
  }

  Future<void> _releaseSignInHolds() async {
    final entries = _store.load();
    if (!entries.any((e) => e.hold == OutboxHold.signInRequired)) {
      return;
    }
    await _store.save(
      entries
          .map(
            (e) => e.hold == OutboxHold.signInRequired
                ? e.copyWith(clearHold: true, attempts: 0)
                : e,
          )
          .toList(),
    );
  }

  OutboxEntry? _entryFor(String memoryId) {
    for (final entry in _store.load()) {
      if (entry.memoryId == memoryId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _replace(OutboxEntry updated) {
    return _update(updated.memoryId, (_) => updated);
  }

  Future<void> _update(
    String memoryId,
    OutboxEntry Function(OutboxEntry entry) change,
  ) async {
    final entries = _store.load();
    await _store.save(
      entries
          .map((entry) => entry.memoryId == memoryId ? change(entry) : entry)
          .toList(),
    );
  }
}

class _SendOutcome {
  const _SendOutcome({this.published = false, this.hold, this.stopRun = false});

  final bool published;
  final OutboxHold? hold;
  final bool stopRun;
}
