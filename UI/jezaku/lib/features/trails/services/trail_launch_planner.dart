import 'package:jejaku/features/trails/models/ar_trail_session.dart';

/// What the viewer should do when it opens with a requested trail.
sealed class TrailLaunchAction {
  const TrailLaunchAction();
}

/// Continue [session] from [currentMemoryId], keeping stored progress.
class ResumeTrail extends TrailLaunchAction {
  const ResumeTrail(this.session, this.currentMemoryId);

  final ARTrailSession session;
  final String? currentMemoryId;
}

/// Begin [session] fresh at [currentMemoryId].
class StartTrail extends TrailLaunchAction {
  const StartTrail(this.session, this.currentMemoryId);

  final ARTrailSession session;
  final String? currentMemoryId;
}

/// The requested trail is the one already in progress: show it in the viewer
/// and mark it resumed.
class AdoptActiveTrail extends TrailLaunchAction {
  const AdoptActiveTrail(this.progress);

  final ARTrailProgress progress;
}

/// A different trail is in progress; the user must pick.
class AskTrailConflict extends TrailLaunchAction {
  const AskTrailConflict({required this.active, required this.requested});

  final ARTrailProgress active;
  final ARTrailSession requested;
}

/// The user's answer to [AskTrailConflict].
enum TrailLaunchConflictChoice { resumeCurrent, replace, cancel }

/// What to do after the user answered the conflict prompt.
sealed class TrailConflictResolution {
  const TrailConflictResolution();
}

/// Show the in-progress trail in the viewer without touching its progress.
class ShowActiveTrail extends TrailConflictResolution {
  const ShowActiveTrail(this.progress);

  final ARTrailProgress progress;
}

/// Replace the in-progress trail with the requested one.
class ReplaceWithRequested extends TrailConflictResolution {
  const ReplaceWithRequested(this.session, this.currentMemoryId);

  final ARTrailSession session;
  final String? currentMemoryId;
}

/// Leave the viewer.
class AbandonLaunch extends TrailConflictResolution {
  const AbandonLaunch();
}

/// Pure decision logic for opening the AR viewer on a trail. It reads no
/// providers and shows no UI, so every branch can be unit tested.
class TrailLaunchPlanner {
  const TrailLaunchPlanner._();

  /// Returns `null` when [requested] cannot be started.
  static TrailLaunchAction? plan({
    required ARTrailSession requested,
    required ARTrailProgress? active,
    required bool resumeExisting,
    required String? focusedMemoryId,
  }) {
    if (!requested.canStart) {
      return null;
    }
    if (resumeExisting) {
      return ResumeTrail(requested, focusedMemoryId);
    }
    if (active == null || active.isFinished) {
      return StartTrail(requested, focusedMemoryId);
    }
    if (active.session.hasSameRouteAs(requested)) {
      return AdoptActiveTrail(active);
    }
    return AskTrailConflict(active: active, requested: requested);
  }

  /// A dismissed prompt (`null` choice) counts as cancel.
  static TrailConflictResolution resolveConflict({
    required TrailLaunchConflictChoice? choice,
    required ARTrailProgress active,
    required ARTrailSession requested,
    required String? focusedMemoryId,
  }) {
    return switch (choice) {
      TrailLaunchConflictChoice.resumeCurrent => ShowActiveTrail(active),
      TrailLaunchConflictChoice.replace =>
        ReplaceWithRequested(requested, focusedMemoryId),
      TrailLaunchConflictChoice.cancel || null => const AbandonLaunch(),
    };
  }
}
