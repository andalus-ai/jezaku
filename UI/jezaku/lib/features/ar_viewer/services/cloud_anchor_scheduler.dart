import 'dart:async';

import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_maintenance_policy.dart';
import 'package:jejaku/features/ar_viewer/services/ar_memory_cloud_anchor_retry_policy.dart';
import 'package:jejaku/features/home/models/anchor_memory.dart';

typedef SchedulerTimerFactory = Timer Function(
  Duration delay,
  void Function() callback,
);

/// Decides when the AR viewer should look at its cloud anchors again: a retry
/// with backoff after hosting failures, and a renewal check before stored
/// anchors expire. It owns the timers and the backoff state; what a wake-up
/// actually does is the caller's business ([onRetryDue], [onMaintenanceDue]).
class CloudAnchorScheduler {
  CloudAnchorScheduler({
    required this.onRetryDue,
    required this.onMaintenanceDue,
    this.retryPolicy = const ARMemoryCloudAnchorRetryPolicy(),
    this.maintenancePolicy = const ARMemoryCloudAnchorMaintenancePolicy(),
    DateTime Function()? now,
    SchedulerTimerFactory? timerFactory,
  })  : _now = now ?? (() => DateTime.now().toUtc()),
        _timerFactory = timerFactory ?? Timer.new;

  final void Function() onRetryDue;
  final void Function() onMaintenanceDue;
  final ARMemoryCloudAnchorRetryPolicy retryPolicy;
  final ARMemoryCloudAnchorMaintenancePolicy maintenancePolicy;
  final DateTime Function() _now;
  final SchedulerTimerFactory _timerFactory;

  ARMemoryCloudAnchorRetryState _retryState =
      const ARMemoryCloudAnchorRetryState();
  Timer? _retryTimer;
  DateTime? _maintenanceCheckAt;
  Timer? _maintenanceTimer;

  ARMemoryCloudAnchorRetryState get retryState => _retryState;
  DateTime? get maintenanceCheckAt => _maintenanceCheckAt;
  bool get hasRetryScheduled => _retryTimer?.isActive == true;
  bool get hasMaintenanceScheduled => _maintenanceTimer?.isActive == true;

  /// Schedules a retry for [memoryIds] that failed to host. Returns the
  /// decision taken, or null when the same failures already have a retry
  /// pending (or there are no failures, which clears any pending retry).
  ARMemoryCloudAnchorRetryDecision? scheduleRetry(Set<String> memoryIds) {
    if (memoryIds.isEmpty) {
      cancelRetry();
      return null;
    }
    if (hasRetryScheduled && _retryState.tracksSameFailures(memoryIds)) {
      return null;
    }

    final decision = retryPolicy.next(
      memoryIds: memoryIds,
      current: _retryState,
    );
    if (!decision.shouldRetry) {
      cancelRetry();
      return decision;
    }
    _retryState = decision.state;
    _retryTimer?.cancel();
    _retryTimer = _timerFactory(decision.delay!, () {
      _retryTimer = null;
      onRetryDue();
    });
    return decision;
  }

  void cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryState = const ARMemoryCloudAnchorRetryState();
  }

  /// Plans the next renewal check for [memories]. When some anchors are
  /// already inside their renewal window, [onMaintenanceDue] runs right away;
  /// otherwise a timer is set for the earliest renewal time.
  void scheduleMaintenance(Iterable<AnchorMemory> memories) {
    final now = _now();
    final plan = maintenancePolicy.plan(memories: memories, now: now);
    if (plan.hasDueMemories) {
      cancelMaintenance();
      onMaintenanceDue();
      return;
    }

    final nextCheckAt = plan.nextCheckAt;
    if (nextCheckAt == null) {
      cancelMaintenance();
      return;
    }
    if (hasMaintenanceScheduled && _maintenanceCheckAt == nextCheckAt) {
      return;
    }

    _maintenanceCheckAt = nextCheckAt;
    _maintenanceTimer?.cancel();
    _maintenanceTimer = _timerFactory(plan.delayFrom(now)!, () {
      _maintenanceTimer = null;
      _maintenanceCheckAt = null;
      onMaintenanceDue();
    });
  }

  void cancelMaintenance() {
    _maintenanceTimer?.cancel();
    _maintenanceTimer = null;
    _maintenanceCheckAt = null;
  }

  void cancelAll() {
    cancelRetry();
    cancelMaintenance();
  }
}
