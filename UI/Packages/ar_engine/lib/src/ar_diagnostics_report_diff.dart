import 'ar_camera.dart';
import 'ar_diagnostics_report.dart';
import 'ar_diagnostics_timeline.dart';
import 'ar_plane.dart';
import 'ar_session_health.dart';
import 'ar_session_health_assessment.dart';

enum ARDiagnosticsReportDiffDirection {
  unchanged,
  initialized,
  changed,
  improved,
  worsened,
  mixed,
}

class ARDiagnosticsReportDiff {
  ARDiagnosticsReportDiff._({
    required this.previous,
    required this.current,
    required this.addedEvents,
    required this.removedEvents,
    required this.newWarnings,
    required this.resolvedWarnings,
    required this.sessionHealthDelta,
  });

  factory ARDiagnosticsReportDiff.compare({
    ARDiagnosticsReport? previous,
    required ARDiagnosticsReport current,
  }) {
    final previousEvents =
        previous?.queryResult.events ?? const <ARDiagnosticsTimelineEvent>[];
    final currentEvents = current.queryResult.events;
    final previousWarningEvents = previous?.queryResult.warningValues ??
        const <ARDiagnosticsTimelineEvent>[];
    final currentWarningEvents = current.queryResult.warningValues;

    return ARDiagnosticsReportDiff._(
      previous: previous,
      current: current,
      addedEvents: _eventsOnlyIn(
        currentEvents,
        previousEvents,
        keyFor: (event) => event.cacheKey,
      ),
      removedEvents: _eventsOnlyIn(
        previousEvents,
        currentEvents,
        keyFor: (event) => event.cacheKey,
      ),
      newWarnings: _eventsOnlyIn(
        currentWarningEvents,
        previousWarningEvents,
        keyFor: _warningSignature,
      ),
      resolvedWarnings: _eventsOnlyIn(
        previousWarningEvents,
        currentWarningEvents,
        keyFor: _warningSignature,
      ),
      sessionHealthDelta: ARDiagnosticsSessionHealthDelta.compare(
        previous: previous == null ? null : _latestSessionHealth(previous),
        current: _latestSessionHealth(current),
      ),
    );
  }

  final ARDiagnosticsReport? previous;
  final ARDiagnosticsReport current;
  final List<ARDiagnosticsTimelineEvent> addedEvents;
  final List<ARDiagnosticsTimelineEvent> removedEvents;
  final List<ARDiagnosticsTimelineEvent> newWarnings;
  final List<ARDiagnosticsTimelineEvent> resolvedWarnings;
  final ARDiagnosticsSessionHealthDelta sessionHealthDelta;

  int get timelineEventDelta =>
      current.timelineEventCount - (previous?.timelineEventCount ?? 0);

  int get matchDelta => current.matchCount - (previous?.matchCount ?? 0);

  int get warningDelta =>
      current.queryResult.warningCount -
      (previous?.queryResult.warningCount ?? 0);

  int get blockedDelta =>
      current.queryResult.blockedCount -
      (previous?.queryResult.blockedCount ?? 0);

  int get goodDelta =>
      current.queryResult.goodCount - (previous?.queryResult.goodCount ?? 0);

  int get cachedCaptureDelta =>
      current.cachedCaptureCount - (previous?.cachedCaptureCount ?? 0);

  int get syncableCaptureDelta =>
      current.syncableCaptureCount - (previous?.syncableCaptureCount ?? 0);

  bool get hasNewWarnings => newWarnings.isNotEmpty;

  bool get hasResolvedWarnings => resolvedWarnings.isNotEmpty;

  bool get hasChanges {
    if (previous == null) {
      return true;
    }
    return addedEvents.isNotEmpty ||
        removedEvents.isNotEmpty ||
        newWarnings.isNotEmpty ||
        resolvedWarnings.isNotEmpty ||
        timelineEventDelta != 0 ||
        matchDelta != 0 ||
        warningDelta != 0 ||
        blockedDelta != 0 ||
        goodDelta != 0 ||
        cachedCaptureDelta != 0 ||
        syncableCaptureDelta != 0 ||
        sessionHealthDelta.hasChanges;
  }

  ARDiagnosticsReportDiffDirection get direction {
    if (previous == null) {
      return ARDiagnosticsReportDiffDirection.initialized;
    }
    if (!hasChanges) {
      return ARDiagnosticsReportDiffDirection.unchanged;
    }

    final hasWorseSignal = newWarnings.isNotEmpty ||
        warningDelta > 0 ||
        blockedDelta > 0 ||
        sessionHealthDelta.isWorse;
    final hasBetterSignal = resolvedWarnings.isNotEmpty ||
        warningDelta < 0 ||
        blockedDelta < 0 ||
        sessionHealthDelta.isBetter;

    if (hasWorseSignal && hasBetterSignal) {
      return ARDiagnosticsReportDiffDirection.mixed;
    }
    if (hasWorseSignal) {
      return ARDiagnosticsReportDiffDirection.worsened;
    }
    if (hasBetterSignal) {
      return ARDiagnosticsReportDiffDirection.improved;
    }
    return ARDiagnosticsReportDiffDirection.changed;
  }

  String get statusLabel => switch (direction) {
        ARDiagnosticsReportDiffDirection.initialized =>
          'Initial AR diagnostics report',
        ARDiagnosticsReportDiffDirection.unchanged =>
          'No AR diagnostics changes',
        ARDiagnosticsReportDiffDirection.worsened => _worsenedLabel(),
        ARDiagnosticsReportDiffDirection.improved => _improvedLabel(),
        ARDiagnosticsReportDiffDirection.mixed => _mixedLabel(),
        ARDiagnosticsReportDiffDirection.changed => _changedLabel(),
      };

  List<String> get newWarningLabels => _eventDisplayLabels(newWarnings);

  List<String> get resolvedWarningLabels =>
      _eventDisplayLabels(resolvedWarnings);

  List<String> get summaryLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          statusLabel,
          if (newWarnings.isNotEmpty)
            _countLabel(newWarnings.length, 'new warning'),
          if (resolvedWarnings.isNotEmpty)
            _countLabel(resolvedWarnings.length, 'resolved warning'),
          if (timelineEventDelta != 0)
            'Timeline events ${_signedInt(timelineEventDelta)}',
          if (matchDelta != 0) 'Matches ${_signedInt(matchDelta)}',
          if (cachedCaptureDelta != 0)
            'Cached captures ${_signedInt(cachedCaptureDelta)}',
          if (syncableCaptureDelta != 0)
            'Syncable captures ${_signedInt(syncableCaptureDelta)}',
          sessionHealthDelta.hasChanges ? sessionHealthDelta.statusLabel : null,
        ]),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'previousGeneratedAt': previous?.generatedAt.toUtc().toIso8601String(),
        'currentGeneratedAt': current.generatedAt.toUtc().toIso8601String(),
        'direction': direction.name,
        'statusLabel': statusLabel,
        'timelineEventDelta': timelineEventDelta,
        'matchDelta': matchDelta,
        'warningDelta': warningDelta,
        'blockedDelta': blockedDelta,
        'goodDelta': goodDelta,
        'cachedCaptureDelta': cachedCaptureDelta,
        'syncableCaptureDelta': syncableCaptureDelta,
        'addedEventLabels': _eventDisplayLabels(addedEvents),
        'removedEventLabels': _eventDisplayLabels(removedEvents),
        'newWarningLabels': newWarningLabels,
        'resolvedWarningLabels': resolvedWarningLabels,
        'sessionHealthDelta': sessionHealthDelta.toMap(),
        'summaryLabels': summaryLabels,
      };

  String _worsenedLabel() {
    if (newWarnings.isNotEmpty) {
      return _countLabel(newWarnings.length, 'new AR warning');
    }
    if (warningDelta > 0) {
      return 'AR warnings increased by $warningDelta';
    }
    if (blockedDelta > 0) {
      return 'Blocked AR events increased by $blockedDelta';
    }
    if (sessionHealthDelta.isWorse) {
      return sessionHealthDelta.statusLabel;
    }
    return 'AR diagnostics worsened';
  }

  String _improvedLabel() {
    if (resolvedWarnings.isNotEmpty) {
      return _countLabel(resolvedWarnings.length, 'AR warning resolved');
    }
    if (warningDelta < 0) {
      return 'AR warnings decreased by ${warningDelta.abs()}';
    }
    if (blockedDelta < 0) {
      return 'Blocked AR events decreased by ${blockedDelta.abs()}';
    }
    if (sessionHealthDelta.isBetter) {
      return sessionHealthDelta.statusLabel;
    }
    return 'AR diagnostics improved';
  }

  String _mixedLabel() {
    final labels = <String>[
      if (newWarnings.isNotEmpty)
        _countLabel(newWarnings.length, 'new warning'),
      if (resolvedWarnings.isNotEmpty)
        _countLabel(resolvedWarnings.length, 'resolved warning'),
    ];
    if (labels.isEmpty) {
      return 'AR diagnostics changed';
    }
    return 'AR diagnostics changed: ${labels.join(', ')}';
  }

  String _changedLabel() {
    if (addedEvents.isNotEmpty || removedEvents.isNotEmpty) {
      return 'AR diagnostics timeline changed';
    }
    if (cachedCaptureDelta != 0 || syncableCaptureDelta != 0) {
      return 'AR diagnostics cache changed';
    }
    return 'AR diagnostics changed';
  }
}

class ARDiagnosticsSessionHealthDelta {
  const ARDiagnosticsSessionHealthDelta({
    required this.previous,
    required this.current,
  });

  factory ARDiagnosticsSessionHealthDelta.compare({
    ARSessionHealthAssessment? previous,
    ARSessionHealthAssessment? current,
  }) =>
      ARDiagnosticsSessionHealthDelta(
        previous: previous,
        current: current,
      );

  final ARSessionHealthAssessment? previous;
  final ARSessionHealthAssessment? current;

  ARSessionHealthSnapshot? get previousSnapshot => previous?.snapshot;

  ARSessionHealthSnapshot? get currentSnapshot => current?.snapshot;

  int? get severityDelta {
    final previousSeverity = previous?.severity;
    final currentSeverity = current?.severity;
    if (previousSeverity == null || currentSeverity == null) {
      return null;
    }
    return currentSeverity.index - previousSeverity.index;
  }

  int? get planeCountDelta =>
      _intDelta(previousSnapshot?.planeCount, currentSnapshot?.planeCount);

  int? get trackedPlaneCountDelta => _intDelta(
        previousSnapshot?.trackedPlaneCount,
        currentSnapshot?.trackedPlaneCount,
      );

  int? get anchorCountDelta =>
      _intDelta(previousSnapshot?.anchorCount, currentSnapshot?.anchorCount);

  int? get trackedAnchorCountDelta => _intDelta(
        previousSnapshot?.trackedAnchorCount,
        currentSnapshot?.trackedAnchorCount,
      );

  int? get nodeCountDelta =>
      _intDelta(previousSnapshot?.nodeCount, currentSnapshot?.nodeCount);

  double? get lightEstimateLuxDelta => _doubleDelta(
        previousSnapshot?.lightEstimateLux,
        currentSnapshot?.lightEstimateLux,
      );

  bool get hasChanges {
    if (previous == null && current == null) {
      return false;
    }
    if (previous == null || current == null) {
      return true;
    }
    return previous != current ||
        planeCountDelta != 0 ||
        trackedPlaneCountDelta != 0 ||
        anchorCountDelta != 0 ||
        trackedAnchorCountDelta != 0 ||
        nodeCountDelta != 0 ||
        lightEstimateLuxDelta != 0;
  }

  bool get isBetter => (severityDelta ?? 0) < 0;

  bool get isWorse => (severityDelta ?? 0) > 0;

  String get statusLabel {
    if (previous == null && current == null) {
      return 'No session health samples';
    }
    if (previous == null) {
      return 'Session health started: ${current!.statusLabel}';
    }
    if (current == null) {
      return 'Session health sample cleared';
    }
    if (!hasChanges) {
      return 'Session health unchanged';
    }
    if (isBetter) {
      return 'Session health improved: ${current!.statusLabel}';
    }
    if (isWorse) {
      return 'Session health worsened: ${current!.statusLabel}';
    }
    return changeLabels.isEmpty
        ? 'Session health changed'
        : 'Session health changed: ${changeLabels.join(', ')}';
  }

  List<String> get changeLabels {
    final labels = <String>[];
    final previousState = previousSnapshot?.trackingState;
    final currentState = currentSnapshot?.trackingState;
    if (previousState != currentState) {
      labels.add('tracking ${_trackingStateLabel(previousState)} to '
          '${_trackingStateLabel(currentState)}');
    }
    final previousFailure = previousSnapshot?.trackingFailureReason;
    final currentFailure = currentSnapshot?.trackingFailureReason;
    if (previousFailure != currentFailure) {
      labels.add('failure ${_trackingFailureLabel(previousFailure)} to '
          '${_trackingFailureLabel(currentFailure)}');
    }
    _addIntDeltaLabel(labels, 'planes', planeCountDelta);
    _addIntDeltaLabel(labels, 'tracked planes', trackedPlaneCountDelta);
    _addIntDeltaLabel(labels, 'anchors', anchorCountDelta);
    _addIntDeltaLabel(labels, 'tracked anchors', trackedAnchorCountDelta);
    _addIntDeltaLabel(labels, 'nodes', nodeCountDelta);
    final lightDelta = lightEstimateLuxDelta;
    if (lightDelta != null && lightDelta != 0) {
      labels.add('light ${_signedNumber(lightDelta)} lux');
    }
    return List<String>.unmodifiable(labels);
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'previousStatusLabel': previous?.statusLabel,
        'currentStatusLabel': current?.statusLabel,
        'severityDelta': severityDelta,
        'planeCountDelta': planeCountDelta,
        'trackedPlaneCountDelta': trackedPlaneCountDelta,
        'anchorCountDelta': anchorCountDelta,
        'trackedAnchorCountDelta': trackedAnchorCountDelta,
        'nodeCountDelta': nodeCountDelta,
        'lightEstimateLuxDelta': lightEstimateLuxDelta,
        'isBetter': isBetter,
        'isWorse': isWorse,
        'statusLabel': statusLabel,
        'changeLabels': changeLabels,
      };
}

extension ARDiagnosticsReportDiffing on ARDiagnosticsReport {
  ARDiagnosticsReportDiff diffFrom(ARDiagnosticsReport? previous) =>
      ARDiagnosticsReportDiff.compare(previous: previous, current: this);
}

ARDiagnosticsSessionHealthDelta diffSessionHealthAssessments({
  ARSessionHealthAssessment? previous,
  ARSessionHealthAssessment? current,
}) =>
    ARDiagnosticsSessionHealthDelta.compare(
      previous: previous,
      current: current,
    );

ARSessionHealthAssessment? _latestSessionHealth(ARDiagnosticsReport report) {
  for (final event in report.queryResult.events.reversed) {
    final assessment = event.sessionHealthAssessment;
    if (assessment != null) {
      return assessment;
    }
  }
  return report.timeline
      .latestOfType(ARDiagnosticsTimelineEventType.sessionHealth)
      ?.sessionHealthAssessment;
}

List<ARDiagnosticsTimelineEvent> _eventsOnlyIn(
  Iterable<ARDiagnosticsTimelineEvent> source,
  Iterable<ARDiagnosticsTimelineEvent> other, {
  required String Function(ARDiagnosticsTimelineEvent event) keyFor,
}) {
  final otherKeys = other.map(keyFor).toSet();
  final emittedKeys = <String>{};
  final values = <ARDiagnosticsTimelineEvent>[];
  for (final event in source) {
    final key = keyFor(event);
    if (otherKeys.contains(key) || !emittedKeys.add(key)) {
      continue;
    }
    values.add(event);
  }
  return List<ARDiagnosticsTimelineEvent>.unmodifiable(values);
}

String _warningSignature(ARDiagnosticsTimelineEvent event) {
  final health = event.sessionHealthAssessment;
  final lifecycle = event.sessionLifecycleEvent;
  return <String>[
    event.type.name,
    event.source,
    event.sessionId ?? '',
    event.severity?.name ?? '',
    health?.primaryIssue?.name ?? '',
    lifecycle?.kind.name ?? '',
    lifecycle?.code ?? '',
    event.summaryLabel,
  ].join('|');
}

List<String> _eventDisplayLabels(Iterable<ARDiagnosticsTimelineEvent> events) =>
    List<String>.unmodifiable(
      _uniqueLabels(events.map((event) => event.displayLabel)),
    );

Iterable<String> _uniqueLabels(Iterable<String?> labels) sync* {
  final seen = <String>{};
  for (final label in labels) {
    final trimmed = label?.trim();
    if (trimmed == null || trimmed.isEmpty || !seen.add(trimmed)) {
      continue;
    }
    yield trimmed;
  }
}

String _countLabel(int count, String singularLabel) {
  if (count == 1) {
    return '1 $singularLabel';
  }
  return '$count ${singularLabel}s';
}

int? _intDelta(int? previous, int? current) {
  if (previous == null || current == null) {
    return null;
  }
  return current - previous;
}

double? _doubleDelta(double? previous, double? current) {
  if (previous == null || current == null) {
    return null;
  }
  return current - previous;
}

void _addIntDeltaLabel(List<String> labels, String label, int? delta) {
  if (delta == null || delta == 0) {
    return;
  }
  labels.add('$label ${_signedInt(delta)}');
}

String _signedInt(int value) => value > 0 ? '+$value' : value.toString();

String _signedNumber(double value) {
  final label = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return value > 0 ? '+$label' : label;
}

String _trackingStateLabel(ARTrackingState? state) => state?.name ?? 'none';

String _trackingFailureLabel(ARTrackingFailureReason? reason) =>
    reason?.name ?? 'none';
