import 'ar_session_health.dart';

enum ARSessionHealthSeverity {
  good,
  warning,
  blocked,
}

enum ARSessionHealthIssue {
  noCameraFrame,
  staleCameraFrame,
  trackingLimited,
  sessionPaused,
  sessionStopped,
  lowLight,
  noTrackedPlanes,
}

enum ARSessionReadinessLevel {
  ready,
  limited,
  blocked,
}

class ARSessionHealthGuidance {
  const ARSessionHealthGuidance({
    required this.issue,
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  factory ARSessionHealthGuidance.forIssue(ARSessionHealthIssue issue) =>
      switch (issue) {
        ARSessionHealthIssue.noCameraFrame => const ARSessionHealthGuidance(
            issue: ARSessionHealthIssue.noCameraFrame,
            title: 'Camera waiting',
            message: 'Keep the viewer open and allow camera access.',
            actionLabel: 'Check camera',
          ),
        ARSessionHealthIssue.staleCameraFrame => const ARSessionHealthGuidance(
            issue: ARSessionHealthIssue.staleCameraFrame,
            title: 'Camera feed stale',
            message:
                'Move the device slowly; restart AR if the view is frozen.',
            actionLabel: 'Restart if frozen',
          ),
        ARSessionHealthIssue.trackingLimited => const ARSessionHealthGuidance(
            issue: ARSessionHealthIssue.trackingLimited,
            title: 'Tracking limited',
            message:
                'Move slowly and scan textured surfaces until tracking stabilizes.',
            actionLabel: 'Scan area',
          ),
        ARSessionHealthIssue.sessionPaused => const ARSessionHealthGuidance(
            issue: ARSessionHealthIssue.sessionPaused,
            title: 'Session paused',
            message: 'Return to the AR viewer to resume live tracking.',
            actionLabel: 'Resume AR',
          ),
        ARSessionHealthIssue.sessionStopped => const ARSessionHealthGuidance(
            issue: ARSessionHealthIssue.sessionStopped,
            title: 'Session stopped',
            message: 'Restart AR to rebuild tracking.',
            actionLabel: 'Restart AR',
          ),
        ARSessionHealthIssue.lowLight => const ARSessionHealthGuidance(
            issue: ARSessionHealthIssue.lowLight,
            title: 'Low light',
            message:
                'Move to a brighter area or add light before placing anchors.',
            actionLabel: 'Improve light',
          ),
        ARSessionHealthIssue.noTrackedPlanes => const ARSessionHealthGuidance(
            issue: ARSessionHealthIssue.noTrackedPlanes,
            title: 'No planes tracked',
            message: 'Aim at a flat textured surface and sweep slowly.',
            actionLabel: 'Scan surface',
          ),
      };

  factory ARSessionHealthGuidance.fromMap(Map<dynamic, dynamic> map) {
    final issue = _issueFromName(map['issue'] as String?) ??
        ARSessionHealthIssue.noCameraFrame;
    final fallback = ARSessionHealthGuidance.forIssue(issue);
    return ARSessionHealthGuidance(
      issue: issue,
      title: map['title'] as String? ?? fallback.title,
      message: map['message'] as String? ?? fallback.message,
      actionLabel: map['actionLabel'] as String? ?? fallback.actionLabel,
    );
  }

  final ARSessionHealthIssue issue;
  final String title;
  final String message;
  final String actionLabel;

  ARSessionHealthGuidance copyWith({
    ARSessionHealthIssue? issue,
    String? title,
    String? message,
    String? actionLabel,
  }) =>
      ARSessionHealthGuidance(
        issue: issue ?? this.issue,
        title: title ?? this.title,
        message: message ?? this.message,
        actionLabel: actionLabel ?? this.actionLabel,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'issue': issue.name,
        'title': title,
        'message': message,
        'actionLabel': actionLabel,
      };

  @override
  bool operator ==(Object other) =>
      other is ARSessionHealthGuidance &&
      issue == other.issue &&
      title == other.title &&
      message == other.message &&
      actionLabel == other.actionLabel;

  @override
  int get hashCode => Object.hash(issue, title, message, actionLabel);

  @override
  String toString() => 'ARSessionHealthGuidance('
      'issue:$issue actionLabel:$actionLabel)';
}

class ARSessionReadiness {
  const ARSessionReadiness({
    required this.level,
    required this.label,
    required this.detailLabel,
    required this.canPlaceAnchors,
    required this.canCaptureSnapshot,
    required this.canRecord,
    this.primaryIssue,
    this.guidance,
  });

  factory ARSessionReadiness.fromAssessment(
    ARSessionHealthAssessment assessment,
  ) {
    if (assessment.isHealthy) {
      return const ARSessionReadiness(
        level: ARSessionReadinessLevel.ready,
        label: 'AR ready',
        detailLabel: 'Tracking is stable for placement and capture.',
        canPlaceAnchors: true,
        canCaptureSnapshot: true,
        canRecord: true,
      );
    }

    final primaryIssue = assessment.primaryIssue;
    final guidance = assessment.primaryGuidance;
    final isBlocked = assessment.severity == ARSessionHealthSeverity.blocked ||
        assessment.hasIssue(ARSessionHealthIssue.staleCameraFrame) ||
        assessment.hasIssue(ARSessionHealthIssue.sessionPaused);

    return ARSessionReadiness(
      level: isBlocked
          ? ARSessionReadinessLevel.blocked
          : ARSessionReadinessLevel.limited,
      label: guidance?.title ?? assessment.hudLabel,
      detailLabel: guidance?.message ?? assessment.detailLabel,
      canPlaceAnchors: false,
      canCaptureSnapshot: !isBlocked,
      canRecord: !isBlocked,
      primaryIssue: primaryIssue,
      guidance: guidance,
    );
  }

  factory ARSessionReadiness.fromMap(Map<dynamic, dynamic> map) {
    final level = _readinessLevelFromName(map['level'] as String?) ??
        ARSessionReadinessLevel.ready;
    final guidanceMap = map['guidance'];
    final guidance = guidanceMap is Map
        ? ARSessionHealthGuidance.fromMap(
            Map<dynamic, dynamic>.from(guidanceMap),
          )
        : null;
    final hasPrimaryIssue = map.containsKey('primaryIssue');

    return ARSessionReadiness(
      level: level,
      label: map['label'] as String? ?? _readinessDefaultLabel(level, guidance),
      detailLabel: map['detailLabel'] as String? ??
          _readinessDefaultDetailLabel(level, guidance),
      canPlaceAnchors: map['canPlaceAnchors'] as bool? ??
          level == ARSessionReadinessLevel.ready,
      canCaptureSnapshot: map['canCaptureSnapshot'] as bool? ??
          level != ARSessionReadinessLevel.blocked,
      canRecord:
          map['canRecord'] as bool? ?? level != ARSessionReadinessLevel.blocked,
      primaryIssue: hasPrimaryIssue
          ? _issueFromName(map['primaryIssue'] as String?)
          : guidance?.issue,
      guidance: guidance,
    );
  }

  final ARSessionReadinessLevel level;
  final String label;
  final String detailLabel;
  final bool canPlaceAnchors;
  final bool canCaptureSnapshot;
  final bool canRecord;
  final ARSessionHealthIssue? primaryIssue;
  final ARSessionHealthGuidance? guidance;

  bool get isReady => level == ARSessionReadinessLevel.ready;

  bool get isLimited => level == ARSessionReadinessLevel.limited;

  bool get isBlocked => level == ARSessionReadinessLevel.blocked;

  String get levelLabel => switch (level) {
        ARSessionReadinessLevel.ready => 'Ready',
        ARSessionReadinessLevel.limited => 'Limited',
        ARSessionReadinessLevel.blocked => 'Blocked',
      };

  ARSessionReadiness copyWith({
    ARSessionReadinessLevel? level,
    String? label,
    String? detailLabel,
    bool? canPlaceAnchors,
    bool? canCaptureSnapshot,
    bool? canRecord,
    Object? primaryIssue = _unset,
    Object? guidance = _unset,
  }) =>
      ARSessionReadiness(
        level: level ?? this.level,
        label: label ?? this.label,
        detailLabel: detailLabel ?? this.detailLabel,
        canPlaceAnchors: canPlaceAnchors ?? this.canPlaceAnchors,
        canCaptureSnapshot: canCaptureSnapshot ?? this.canCaptureSnapshot,
        canRecord: canRecord ?? this.canRecord,
        primaryIssue: identical(primaryIssue, _unset)
            ? this.primaryIssue
            : primaryIssue as ARSessionHealthIssue?,
        guidance: identical(guidance, _unset)
            ? this.guidance
            : guidance as ARSessionHealthGuidance?,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'level': level.name,
        'label': label,
        'detailLabel': detailLabel,
        'canPlaceAnchors': canPlaceAnchors,
        'canCaptureSnapshot': canCaptureSnapshot,
        'canRecord': canRecord,
        'primaryIssue': primaryIssue?.name,
        'guidance': guidance?.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      other is ARSessionReadiness &&
      level == other.level &&
      label == other.label &&
      detailLabel == other.detailLabel &&
      canPlaceAnchors == other.canPlaceAnchors &&
      canCaptureSnapshot == other.canCaptureSnapshot &&
      canRecord == other.canRecord &&
      primaryIssue == other.primaryIssue &&
      guidance == other.guidance;

  @override
  int get hashCode => Object.hash(
        level,
        label,
        detailLabel,
        canPlaceAnchors,
        canCaptureSnapshot,
        canRecord,
        primaryIssue,
        guidance,
      );

  @override
  String toString() => 'ARSessionReadiness('
      'level:$level label:$label canPlaceAnchors:$canPlaceAnchors)';
}

class ARSessionHealthPolicy {
  const ARSessionHealthPolicy({
    this.staleCameraFrameAfter = const Duration(seconds: 2),
    this.lowLightLuxThreshold,
    this.warnWhenNoTrackedPlanes = false,
  });

  factory ARSessionHealthPolicy.fromMap(Map<dynamic, dynamic> map) =>
      ARSessionHealthPolicy(
        staleCameraFrameAfter: Duration(
          milliseconds: _int(
            map,
            'staleCameraFrameAfterMillis',
            defaultValue: const Duration(seconds: 2).inMilliseconds,
          ),
        ),
        lowLightLuxThreshold: (map['lowLightLuxThreshold'] as num?)?.toDouble(),
        warnWhenNoTrackedPlanes:
            map['warnWhenNoTrackedPlanes'] as bool? ?? false,
      );

  /// Placement-grade runtime health policy for apps that need to decide
  /// whether new anchors can be placed safely.
  ///
  /// Compared with the default policy, this warns on low light and on frames
  /// with no actively tracked planes, which makes [ARSessionReadiness] pause
  /// anchor placement until the session is stable enough.
  static const placementReadiness = ARSessionHealthPolicy(
    lowLightLuxThreshold: 25,
    warnWhenNoTrackedPlanes: true,
  );

  final Duration staleCameraFrameAfter;
  final double? lowLightLuxThreshold;
  final bool warnWhenNoTrackedPlanes;

  ARSessionHealthAssessment assess(ARSessionHealthSnapshot snapshot) {
    final issues = <ARSessionHealthIssue>[];
    switch (snapshot.status) {
      case ARSessionHealthStatus.noCameraFrame:
        issues.add(ARSessionHealthIssue.noCameraFrame);
      case ARSessionHealthStatus.tracking:
        break;
      case ARSessionHealthStatus.limited:
        issues.add(ARSessionHealthIssue.trackingLimited);
      case ARSessionHealthStatus.paused:
        issues.add(ARSessionHealthIssue.sessionPaused);
      case ARSessionHealthStatus.stopped:
        issues.add(ARSessionHealthIssue.sessionStopped);
    }

    if (snapshot.hasCameraFrame &&
        staleCameraFrameAfter > Duration.zero &&
        snapshot.isCameraFrameStale(staleCameraFrameAfter)) {
      issues.add(ARSessionHealthIssue.staleCameraFrame);
    }

    final lowLightThreshold = lowLightLuxThreshold;
    final lux = snapshot.lightEstimateLux;
    if (lowLightThreshold != null && lux != null && lux < lowLightThreshold) {
      issues.add(ARSessionHealthIssue.lowLight);
    }

    if (warnWhenNoTrackedPlanes &&
        snapshot.hasCameraFrame &&
        snapshot.trackedPlaneCount == 0) {
      issues.add(ARSessionHealthIssue.noTrackedPlanes);
    }

    final primaryIssue = _primaryIssue(issues);
    final baseLabel = _baseLabel(snapshot, primaryIssue);
    return ARSessionHealthAssessment(
      snapshot: snapshot,
      severity: _severityFor(issues),
      issues: Set<ARSessionHealthIssue>.unmodifiable(issues),
      hudLabel: _hudLabel(snapshot, primaryIssue),
      statusLabel: _statusLabel(snapshot, baseLabel),
      detailLabel: _detailLabel(snapshot, baseLabel),
    );
  }

  ARSessionHealthPolicy copyWith({
    Duration? staleCameraFrameAfter,
    Object? lowLightLuxThreshold = _unset,
    bool? warnWhenNoTrackedPlanes,
  }) =>
      ARSessionHealthPolicy(
        staleCameraFrameAfter:
            staleCameraFrameAfter ?? this.staleCameraFrameAfter,
        lowLightLuxThreshold: identical(lowLightLuxThreshold, _unset)
            ? this.lowLightLuxThreshold
            : (lowLightLuxThreshold as num?)?.toDouble(),
        warnWhenNoTrackedPlanes:
            warnWhenNoTrackedPlanes ?? this.warnWhenNoTrackedPlanes,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'staleCameraFrameAfterMillis': staleCameraFrameAfter.inMilliseconds,
        'lowLightLuxThreshold': lowLightLuxThreshold,
        'warnWhenNoTrackedPlanes': warnWhenNoTrackedPlanes,
      };

  @override
  bool operator ==(Object other) =>
      other is ARSessionHealthPolicy &&
      staleCameraFrameAfter == other.staleCameraFrameAfter &&
      lowLightLuxThreshold == other.lowLightLuxThreshold &&
      warnWhenNoTrackedPlanes == other.warnWhenNoTrackedPlanes;

  @override
  int get hashCode => Object.hash(
        staleCameraFrameAfter,
        lowLightLuxThreshold,
        warnWhenNoTrackedPlanes,
      );

  @override
  String toString() => 'ARSessionHealthPolicy('
      'staleCameraFrameAfter:$staleCameraFrameAfter '
      'lowLightLuxThreshold:$lowLightLuxThreshold '
      'warnWhenNoTrackedPlanes:$warnWhenNoTrackedPlanes)';
}

class ARSessionHealthAssessment {
  const ARSessionHealthAssessment({
    required this.snapshot,
    required this.severity,
    required this.issues,
    required this.hudLabel,
    required this.statusLabel,
    required this.detailLabel,
  });

  factory ARSessionHealthAssessment.fromMap(Map<dynamic, dynamic> map) {
    final snapshot = ARSessionHealthSnapshot.fromMap(
      Map<dynamic, dynamic>.from(map['snapshot'] as Map<dynamic, dynamic>),
    );
    final fallback = const ARSessionHealthPolicy().assess(snapshot);
    return ARSessionHealthAssessment(
      snapshot: snapshot,
      severity:
          _severityFromName(map['severity'] as String?) ?? fallback.severity,
      issues: Set<ARSessionHealthIssue>.unmodifiable(
        _issuesFromList(map['issues'] as Iterable<dynamic>?) ?? fallback.issues,
      ),
      hudLabel: map['hudLabel'] as String? ?? fallback.hudLabel,
      statusLabel: map['statusLabel'] as String? ?? fallback.statusLabel,
      detailLabel: map['detailLabel'] as String? ?? fallback.detailLabel,
    );
  }

  final ARSessionHealthSnapshot snapshot;
  final ARSessionHealthSeverity severity;
  final Set<ARSessionHealthIssue> issues;
  final String hudLabel;
  final String statusLabel;
  final String detailLabel;

  bool get isHealthy => severity == ARSessionHealthSeverity.good;

  ARSessionHealthIssue? get primaryIssue => _primaryIssue(issues.toList());

  ARSessionReadiness get readiness => ARSessionReadiness.fromAssessment(this);

  bool get canPlaceAnchors => readiness.canPlaceAnchors;

  bool get canCaptureSnapshot => readiness.canCaptureSnapshot;

  bool get canRecord => readiness.canRecord;

  ARSessionHealthGuidance? get primaryGuidance {
    final issue = primaryIssue;
    return issue == null ? null : ARSessionHealthGuidance.forIssue(issue);
  }

  List<ARSessionHealthGuidance> get guidance {
    final sortedIssues = issues.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return List<ARSessionHealthGuidance>.unmodifiable(
      sortedIssues.map(ARSessionHealthGuidance.forIssue),
    );
  }

  bool hasIssue(ARSessionHealthIssue issue) => issues.contains(issue);

  ARSessionHealthAssessment copyWith({
    ARSessionHealthSnapshot? snapshot,
    ARSessionHealthSeverity? severity,
    Set<ARSessionHealthIssue>? issues,
    String? hudLabel,
    String? statusLabel,
    String? detailLabel,
  }) =>
      ARSessionHealthAssessment(
        snapshot: snapshot ?? this.snapshot,
        severity: severity ?? this.severity,
        issues: Set<ARSessionHealthIssue>.unmodifiable(
          issues ?? this.issues,
        ),
        hudLabel: hudLabel ?? this.hudLabel,
        statusLabel: statusLabel ?? this.statusLabel,
        detailLabel: detailLabel ?? this.detailLabel,
      );

  Map<String, dynamic> toMap() {
    final sortedIssues = issues.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return <String, dynamic>{
      'snapshot': snapshot.toMap(),
      'severity': severity.name,
      'issues': sortedIssues.map((issue) => issue.name).toList(),
      'hudLabel': hudLabel,
      'statusLabel': statusLabel,
      'detailLabel': detailLabel,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ARSessionHealthAssessment &&
      snapshot == other.snapshot &&
      severity == other.severity &&
      _setEquals(issues, other.issues) &&
      hudLabel == other.hudLabel &&
      statusLabel == other.statusLabel &&
      detailLabel == other.detailLabel;

  @override
  int get hashCode {
    final sortedIssueIndexes = issues.map((issue) => issue.index).toList()
      ..sort();
    return Object.hash(
      snapshot,
      severity,
      Object.hashAll(sortedIssueIndexes),
      hudLabel,
      statusLabel,
      detailLabel,
    );
  }

  @override
  String toString() => 'ARSessionHealthAssessment('
      'severity:$severity hudLabel:$hudLabel issues:$issues)';
}

ARSessionHealthSeverity? _severityFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final severity in ARSessionHealthSeverity.values) {
    if (severity.name == name) {
      return severity;
    }
  }
  return null;
}

ARSessionReadinessLevel? _readinessLevelFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final level in ARSessionReadinessLevel.values) {
    if (level.name == name) {
      return level;
    }
  }
  return null;
}

ARSessionHealthIssue? _issueFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final issue in ARSessionHealthIssue.values) {
    if (issue.name == name) {
      return issue;
    }
  }
  return null;
}

Set<ARSessionHealthIssue>? _issuesFromList(Iterable<dynamic>? values) {
  if (values == null) {
    return null;
  }
  final issues = <ARSessionHealthIssue>{};
  for (final value in values) {
    final issue = value is String ? _issueFromName(value) : null;
    if (issue != null) {
      issues.add(issue);
    }
  }
  return issues;
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final value in a) {
    if (!b.contains(value)) {
      return false;
    }
  }
  return true;
}

const Object _unset = Object();

String _readinessDefaultLabel(
  ARSessionReadinessLevel level,
  ARSessionHealthGuidance? guidance,
) =>
    guidance?.title ??
    switch (level) {
      ARSessionReadinessLevel.ready => 'AR ready',
      ARSessionReadinessLevel.limited => 'AR limited',
      ARSessionReadinessLevel.blocked => 'AR blocked',
    };

String _readinessDefaultDetailLabel(
  ARSessionReadinessLevel level,
  ARSessionHealthGuidance? guidance,
) =>
    guidance?.message ??
    switch (level) {
      ARSessionReadinessLevel.ready =>
        'Tracking is stable for placement and capture.',
      ARSessionReadinessLevel.limited =>
        'Tracking is limited; placement is paused until AR stabilizes.',
      ARSessionReadinessLevel.blocked =>
        'Tracking is unavailable for placement or capture.',
    };

int _int(
  Map<dynamic, dynamic> map,
  String key, {
  required int defaultValue,
}) =>
    (map[key] as num?)?.toInt() ?? defaultValue;

ARSessionHealthIssue? _primaryIssue(List<ARSessionHealthIssue> issues) {
  for (final issue in const <ARSessionHealthIssue>[
    ARSessionHealthIssue.noCameraFrame,
    ARSessionHealthIssue.sessionStopped,
    ARSessionHealthIssue.staleCameraFrame,
    ARSessionHealthIssue.sessionPaused,
    ARSessionHealthIssue.trackingLimited,
    ARSessionHealthIssue.lowLight,
    ARSessionHealthIssue.noTrackedPlanes,
  ]) {
    if (issues.contains(issue)) {
      return issue;
    }
  }
  return null;
}

ARSessionHealthSeverity _severityFor(List<ARSessionHealthIssue> issues) {
  if (issues.contains(ARSessionHealthIssue.noCameraFrame) ||
      issues.contains(ARSessionHealthIssue.sessionStopped)) {
    return ARSessionHealthSeverity.blocked;
  }
  if (issues.isNotEmpty) {
    return ARSessionHealthSeverity.warning;
  }
  return ARSessionHealthSeverity.good;
}

String _baseLabel(
  ARSessionHealthSnapshot snapshot,
  ARSessionHealthIssue? primaryIssue,
) =>
    switch (primaryIssue) {
      ARSessionHealthIssue.noCameraFrame => snapshot.statusLabel,
      ARSessionHealthIssue.sessionStopped => snapshot.statusLabel,
      ARSessionHealthIssue.staleCameraFrame => 'AR frame stale',
      ARSessionHealthIssue.sessionPaused => snapshot.statusLabel,
      ARSessionHealthIssue.trackingLimited => snapshot.statusLabel,
      ARSessionHealthIssue.lowLight => 'Low light',
      ARSessionHealthIssue.noTrackedPlanes => 'No planes tracked',
      null => snapshot.statusLabel,
    };

String _hudLabel(
  ARSessionHealthSnapshot snapshot,
  ARSessionHealthIssue? primaryIssue,
) =>
    switch (primaryIssue) {
      ARSessionHealthIssue.noCameraFrame => 'No AR frame',
      ARSessionHealthIssue.sessionStopped => 'AR stopped',
      ARSessionHealthIssue.staleCameraFrame => 'AR stale',
      ARSessionHealthIssue.sessionPaused => 'AR paused',
      ARSessionHealthIssue.trackingLimited => 'Tracking limited',
      ARSessionHealthIssue.lowLight => 'Low light',
      ARSessionHealthIssue.noTrackedPlanes => 'No planes',
      null => switch (snapshot.status) {
          ARSessionHealthStatus.tracking => 'Tracking',
          ARSessionHealthStatus.noCameraFrame => 'No AR frame',
          ARSessionHealthStatus.limited => 'Tracking limited',
          ARSessionHealthStatus.paused => 'AR paused',
          ARSessionHealthStatus.stopped => 'AR stopped',
        },
    };

String _statusLabel(ARSessionHealthSnapshot snapshot, String baseLabel) {
  if (!snapshot.hasCameraFrame) {
    return baseLabel;
  }
  return '$baseLabel; ${_trackingCountsLabel(snapshot)}';
}

String _detailLabel(ARSessionHealthSnapshot snapshot, String baseLabel) {
  if (!snapshot.hasCameraFrame) {
    return baseLabel;
  }
  final parts = <String>[
    baseLabel,
    _trackingCountsLabel(snapshot),
    '${snapshot.nodeCount} nodes',
  ];
  final cameraAge = snapshot.cameraFrameAge;
  if (cameraAge != null) {
    parts.add('camera ${_formatAge(cameraAge)} ago');
  }
  final lux = snapshot.lightEstimateLux;
  if (lux != null) {
    parts.add('${lux.round()} lux');
  }
  final lightAge = snapshot.lightEstimateAge;
  if (lightAge != null) {
    parts.add('light ${_formatAge(lightAge)} ago');
  }
  return parts.join('; ');
}

String _trackingCountsLabel(ARSessionHealthSnapshot snapshot) =>
    '${snapshot.trackedPlaneCount}/${snapshot.planeCount} planes, '
    '${snapshot.trackedAnchorCount}/${snapshot.anchorCount} anchors';

String _formatAge(Duration age) {
  if (age.inMinutes >= 1) {
    return '${age.inMinutes}m';
  }
  if (age.inSeconds >= 1) {
    return '${age.inSeconds}s';
  }
  return '${age.inMilliseconds}ms';
}
