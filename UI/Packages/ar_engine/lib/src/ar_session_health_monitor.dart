import 'dart:async';

import 'ar_anchor.dart';
import 'ar_camera.dart';
import 'ar_capture_diagnostics.dart';
import 'ar_controller.dart';
import 'ar_diagnostics_report.dart';
import 'ar_diagnostics_timeline.dart';
import 'ar_plane.dart';
import 'ar_session_health.dart';
import 'ar_session_health_assessment.dart';

typedef ARSessionHealthClock = DateTime Function();

/// Publishes throttled [ARSessionHealthSnapshot] updates for an active session.
///
/// The monitor observes the controller's existing camera, plane, anchor, and
/// light streams, then samples [ARController.healthSnapshot] at a bounded rate.
class ARSessionHealthMonitor {
  ARSessionHealthMonitor({
    required ARController controller,
    Duration minPublishInterval = const Duration(milliseconds: 500),
    Duration? resampleInterval = const Duration(seconds: 1),
    ARSessionHealthPolicy healthPolicy = const ARSessionHealthPolicy(),
    int timelineCapacity = 32,
    bool includeRuntimeDiagnostics = true,
    ARSessionHealthClock? clock,
  })  : _controller = controller,
        _minPublishInterval = minPublishInterval,
        _resampleInterval = resampleInterval,
        _healthPolicy = healthPolicy,
        _includeRuntimeDiagnostics = includeRuntimeDiagnostics,
        _timeline = ARDiagnosticsTimeline(capacity: timelineCapacity),
        _clock = clock ?? _utcNow {
    _subscriptions
      ..add(
        controller.onCameraUpdate.listen(
          _handleCameraUpdate,
          onError: _snapshots.addError,
        ),
      )
      ..add(
        controller.onPlanesUpdate.listen(
          _handlePlanesUpdate,
          onError: _snapshots.addError,
        ),
      )
      ..add(
        controller.onAnchorUpdate.listen(
          _handleAnchorUpdate,
          onError: _snapshots.addError,
        ),
      )
      ..add(
        controller.onLightEstimate.listen(
          _handleLightUpdate,
          onError: _snapshots.addError,
        ),
      );
    publishNow();
    _startResampleTimer();
  }

  final ARController _controller;
  final Duration _minPublishInterval;
  final Duration? _resampleInterval;
  final ARSessionHealthPolicy _healthPolicy;
  final bool _includeRuntimeDiagnostics;
  final ARDiagnosticsTimeline _timeline;
  final ARSessionHealthClock _clock;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  late final StreamController<ARSessionHealthSnapshot> _snapshots =
      StreamController<ARSessionHealthSnapshot>.broadcast(
    onListen: _replayLatestSnapshot,
  );
  late final StreamController<ARSessionHealthAssessment> _assessments =
      StreamController<ARSessionHealthAssessment>.broadcast(
    onListen: _replayLatestAssessment,
  );
  late final StreamController<ARDiagnosticsTimeline> _timelineChanges =
      StreamController<ARDiagnosticsTimeline>.broadcast(
    onListen: _replayTimelineSnapshot,
  );
  Timer? _pendingPublishTimer;
  Timer? _resampleTimer;
  Future<void>? _runtimeDiagnosticsRefresh;
  ARSessionHealthSnapshot? _latest;
  ARSessionHealthAssessment? _latestAssessment;
  DateTime? _lastPublishedAt;
  final _runtimeLifecycleSignatures = <String>{};
  bool _isDisposed = false;

  Stream<ARSessionHealthSnapshot> get snapshots => _snapshots.stream;

  Stream<ARSessionHealthAssessment> get assessments => _assessments.stream;

  /// Emits whenever the diagnostics timeline changes.
  ///
  /// This stream includes regular session health events and asynchronous
  /// backend runtime diagnostics, such as web renderer model-loader failures.
  Stream<ARDiagnosticsTimeline> get diagnosticsTimelineChanges =>
      _timelineChanges.stream;

  ARSessionHealthSnapshot? get latest => _latest;

  ARSessionHealthAssessment? get latestAssessment => _latestAssessment;

  List<ARDiagnosticsTimelineEvent> get timelineEvents => _timeline.values;

  ARDiagnosticsTimeline get timelineSnapshot =>
      ARDiagnosticsTimeline.fromValues(
        _timeline.values,
        capacity: _timeline.capacity,
      );

  ARDiagnosticsReport toReport({
    DateTime? generatedAt,
    ARDiagnosticsTimelineQuery query = const ARDiagnosticsTimelineQuery(),
    Iterable<ARDiagnosticsTimeline> extraTimelines =
        const <ARDiagnosticsTimeline>[],
    int? timelineCapacity,
    int cachedCaptureCount = 0,
    int syncableCaptureCount = 0,
    ARCaptureDiagnostics? latestCapture,
  }) =>
      ARDiagnosticsReport.fromTimelines(
        <ARDiagnosticsTimeline>[
          timelineSnapshot,
          ...extraTimelines,
        ],
        generatedAt: generatedAt,
        query: query,
        timelineCapacity: timelineCapacity,
        cachedCaptureCount: cachedCaptureCount,
        syncableCaptureCount: syncableCaptureCount,
        latestCapture: latestCapture,
      );

  void publishNow({DateTime? sampledAt}) {
    if (_isDisposed) {
      return;
    }
    _pendingPublishTimer?.cancel();
    _pendingPublishTimer = null;
    _publish(sampledAt: sampledAt);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _pendingPublishTimer?.cancel();
    _pendingPublishTimer = null;
    _resampleTimer?.cancel();
    _resampleTimer = null;
    await Future.wait<void>(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    _subscriptions.clear();
    await _snapshots.close();
    await _assessments.close();
    await _timelineChanges.close();
  }

  void _handleCameraUpdate(ARCamera _) {
    _schedulePublish();
  }

  void _handlePlanesUpdate(List<ARPlane> _) {
    _schedulePublish();
  }

  void _handleAnchorUpdate(ARAnchor _) {
    _schedulePublish();
  }

  void _handleLightUpdate(double _) {
    _schedulePublish();
  }

  void _startResampleTimer() {
    final interval = _resampleInterval;
    if (interval == null || interval <= Duration.zero) {
      return;
    }
    _resampleTimer = Timer.periodic(interval, (_) {
      if (!_isDisposed) {
        publishNow();
      }
    });
  }

  void _schedulePublish() {
    if (_isDisposed) {
      return;
    }
    final now = _clock().toUtc();
    final lastPublishedAt = _lastPublishedAt;
    if (lastPublishedAt == null ||
        _minPublishInterval <= Duration.zero ||
        now.difference(lastPublishedAt) >= _minPublishInterval) {
      publishNow(sampledAt: now);
      return;
    }
    if (_pendingPublishTimer?.isActive ?? false) {
      return;
    }
    final remaining = _minPublishInterval - now.difference(lastPublishedAt);
    _pendingPublishTimer = Timer(remaining, () {
      _pendingPublishTimer = null;
      publishNow();
    });
  }

  void _publish({DateTime? sampledAt}) {
    try {
      final snapshot = _controller.healthSnapshot(
        sampledAt: sampledAt ?? _clock().toUtc(),
      );
      final assessment = _healthPolicy.assess(snapshot);
      _latest = snapshot;
      _latestAssessment = assessment;
      _timeline.put(
        ARDiagnosticsTimelineEvent.fromHealthAssessment(assessment),
      );
      _emitTimelineChange();
      _scheduleRuntimeDiagnosticsRefresh(snapshot.sampledAt);
      _lastPublishedAt = snapshot.sampledAt;
      if (!_snapshots.isClosed) {
        _snapshots.add(snapshot);
      }
      if (!_assessments.isClosed) {
        _assessments.add(assessment);
      }
    } on Object catch (error, stackTrace) {
      if (!_snapshots.isClosed) {
        _snapshots.addError(error, stackTrace);
      }
      if (!_assessments.isClosed) {
        _assessments.addError(error, stackTrace);
      }
    }
  }

  void _scheduleRuntimeDiagnosticsRefresh(DateTime sampledAt) {
    if (!_includeRuntimeDiagnostics || _runtimeDiagnosticsRefresh != null) {
      return;
    }
    _runtimeDiagnosticsRefresh = _refreshRuntimeDiagnostics(sampledAt)
        .whenComplete(() => _runtimeDiagnosticsRefresh = null);
    unawaited(_runtimeDiagnosticsRefresh);
  }

  Future<void> _refreshRuntimeDiagnostics(DateTime sampledAt) async {
    try {
      final diagnostics = await _controller.runtimeDiagnostics();
      if (_isDisposed || diagnostics.isEmpty) {
        return;
      }
      var inserted = false;
      final events = diagnostics.toSessionLifecycleEvents(
        occurredAt: sampledAt,
      );
      for (final event in events) {
        final signature = _runtimeLifecycleSignature(event);
        if (_runtimeLifecycleSignatures.add(signature)) {
          _timeline.put(ARDiagnosticsTimelineEvent.fromSessionLifecycle(event));
          inserted = true;
        }
      }
      if (inserted) {
        _emitTimelineChange();
      }
    } on StateError {
      // The controller may have been disposed while diagnostics were loading.
    } on Object {
      // Runtime diagnostics are advisory and must not break health reporting.
    }
  }

  void _emitTimelineChange() {
    if (!_timelineChanges.isClosed) {
      _timelineChanges.add(timelineSnapshot);
    }
  }

  void _replayLatestSnapshot() {
    final snapshot = _latest;
    if (snapshot == null) {
      return;
    }
    scheduleMicrotask(() {
      if (!_isDisposed && !_snapshots.isClosed && snapshot == _latest) {
        _snapshots.add(snapshot);
      }
    });
  }

  void _replayLatestAssessment() {
    final assessment = _latestAssessment;
    if (assessment == null) {
      return;
    }
    scheduleMicrotask(() {
      if (!_isDisposed &&
          !_assessments.isClosed &&
          assessment == _latestAssessment) {
        _assessments.add(assessment);
      }
    });
  }

  void _replayTimelineSnapshot() {
    if (_timeline.isEmpty) {
      return;
    }
    final snapshot = timelineSnapshot;
    scheduleMicrotask(() {
      if (!_isDisposed && !_timelineChanges.isClosed) {
        _timelineChanges.add(snapshot);
      }
    });
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

String _runtimeLifecycleSignature(ARSessionLifecycleEvent event) {
  final metadata = event.metadata;
  return <String?>[
    event.code,
    event.summaryLabel,
    event.detailLabel,
    event.severity?.name,
    metadata['nodesSkippedMissingThree']?.toString(),
    metadata['modelLoadFailed']?.toString(),
    metadata['modelFallbackUsed']?.toString(),
    metadata['modelStaleCallbacksIgnored']?.toString(),
    metadata['textureLoadFailed']?.toString(),
    metadata['lastModelStatus']?.toString(),
    metadata['lastModelError']?.toString(),
  ].join('|');
}
