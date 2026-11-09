import 'dart:collection';

import 'package:collection/collection.dart';

import 'ar_capture_diagnostics.dart';
import 'ar_session_health_assessment.dart';

enum ARDiagnosticsTimelineEventType {
  sessionHealth,
  captureDiagnostics,
  sessionLifecycle,
}

enum ARDiagnosticsTimelineFacetKind {
  type,
  severity,
  source,
  session,
}

const Object _timelineQueryUnset = Object();
const _deepEquality = DeepCollectionEquality();

enum ARSessionLifecycleEventKind {
  sessionStarted,
  sessionPaused,
  sessionResumed,
  sessionInterrupted,
  sessionEnded,
  permissionDenied,
  configurationChanged,
  configurationDowngraded,
  nativeError,
  anchorPlaced,
  anchorRemoved,
  custom,
}

class ARSessionLifecycleEvent {
  ARSessionLifecycleEvent({
    required this.kind,
    required this.occurredAt,
    required this.summaryLabel,
    this.source = 'session_lifecycle',
    this.sessionId,
    this.detailLabel,
    this.severity,
    this.code,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map<String, Object?>.unmodifiable(_jsonMap(metadata));

  factory ARSessionLifecycleEvent.create({
    required ARSessionLifecycleEventKind kind,
    DateTime? occurredAt,
    String source = 'session_lifecycle',
    String? sessionId,
    String? summaryLabel,
    String? detailLabel,
    ARSessionHealthSeverity? severity,
    String? code,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) =>
      ARSessionLifecycleEvent(
        kind: kind,
        occurredAt: (occurredAt ?? DateTime.now().toUtc()).toUtc(),
        source: source,
        sessionId: sessionId,
        summaryLabel: summaryLabel ?? _defaultLifecycleSummaryLabel(kind),
        detailLabel: detailLabel,
        severity: severity,
        code: code,
        metadata: metadata,
      );

  factory ARSessionLifecycleEvent.fromMap(Map<dynamic, dynamic> map) =>
      ARSessionLifecycleEvent(
        kind: _lifecycleKindFromName(_nullableString(map['kind'])) ??
            ARSessionLifecycleEventKind.custom,
        occurredAt: _dateTime(map['occurredAt']) ??
            _dateTime(map['recordedAt']) ??
            ARCaptureDiagnostics.unknownCapturedAt,
        source: _string(map['source'], 'session_lifecycle'),
        sessionId: _nullableString(map['sessionId']),
        summaryLabel: _string(
          map['summaryLabel'],
          _defaultLifecycleSummaryLabel(
            _lifecycleKindFromName(_nullableString(map['kind'])) ??
                ARSessionLifecycleEventKind.custom,
          ),
        ),
        detailLabel: _nullableString(map['detailLabel']),
        severity: _severityFromName(_nullableString(map['severity'])),
        code: _nullableString(map['code']),
        metadata: _objectMap(map['metadata']),
      );

  static ARSessionLifecycleEvent? tryFromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ARSessionLifecycleEvent.fromMap(value);
    } on Object {
      return null;
    }
  }

  final ARSessionLifecycleEventKind kind;
  final DateTime occurredAt;
  final String source;
  final String? sessionId;
  final String summaryLabel;
  final String? detailLabel;
  final ARSessionHealthSeverity? severity;
  final String? code;
  final Map<String, Object?> metadata;

  String get kindLabel => _lifecycleKindLabel(kind);

  String? get severityLabel =>
      severity == null ? null : _severityLabel(severity!);

  List<String> get metadataLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          kindLabel,
          summaryLabel,
          detailLabel,
          severityLabel,
          code,
          ...metadata.entries.map(_metadataEntryLabel),
        ]),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'kind': kind.name,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'source': source,
        'sessionId': sessionId,
        'summaryLabel': summaryLabel,
        'detailLabel': detailLabel,
        'severity': severity?.name,
        'code': code,
        'metadata': metadata,
      };

  @override
  bool operator ==(Object other) =>
      other is ARSessionLifecycleEvent &&
      kind == other.kind &&
      occurredAt == other.occurredAt &&
      source == other.source &&
      sessionId == other.sessionId &&
      summaryLabel == other.summaryLabel &&
      detailLabel == other.detailLabel &&
      severity == other.severity &&
      code == other.code &&
      _deepEquality.equals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
        kind,
        occurredAt,
        source,
        sessionId,
        summaryLabel,
        detailLabel,
        severity,
        code,
        _deepEquality.hash(metadata),
      );

  @override
  String toString() => 'ARSessionLifecycleEvent('
      'kind:${kind.name} source:$source summary:$summaryLabel)';
}

class ARDiagnosticsTimelineEvent {
  const ARDiagnosticsTimelineEvent({
    required this.type,
    required this.recordedAt,
    required this.source,
    required this.summaryLabel,
    this.sessionId,
    this.detailLabel,
    this.severity,
    this.sessionHealthAssessment,
    this.captureDiagnostics,
    this.sessionLifecycleEvent,
  });

  factory ARDiagnosticsTimelineEvent.fromHealthAssessment(
    ARSessionHealthAssessment assessment, {
    String source = 'session_health',
    String? sessionId,
  }) =>
      ARDiagnosticsTimelineEvent(
        type: ARDiagnosticsTimelineEventType.sessionHealth,
        recordedAt: assessment.snapshot.sampledAt,
        source: source,
        sessionId: sessionId,
        summaryLabel: assessment.hudLabel,
        detailLabel: assessment.detailLabel,
        severity: assessment.severity,
        sessionHealthAssessment: assessment,
      );

  factory ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(
    ARCaptureDiagnostics diagnostics,
  ) =>
      ARDiagnosticsTimelineEvent(
        type: ARDiagnosticsTimelineEventType.captureDiagnostics,
        recordedAt: diagnostics.capturedAt,
        source: diagnostics.source,
        sessionId: diagnostics.sessionId,
        summaryLabel: diagnostics.summaryLabel,
        detailLabel: diagnostics.captureReadinessGuidanceLabel ??
            diagnostics.detailStatusLabel,
        severity: _captureDiagnosticsSeverity(diagnostics),
        captureDiagnostics: diagnostics,
      );

  factory ARDiagnosticsTimelineEvent.fromSessionLifecycle(
    ARSessionLifecycleEvent event,
  ) =>
      ARDiagnosticsTimelineEvent(
        type: ARDiagnosticsTimelineEventType.sessionLifecycle,
        recordedAt: event.occurredAt,
        source: event.source,
        sessionId: event.sessionId,
        summaryLabel: event.summaryLabel,
        detailLabel: event.detailLabel,
        severity: event.severity,
        sessionLifecycleEvent: event,
      );

  factory ARDiagnosticsTimelineEvent.fromMap(Map<dynamic, dynamic> map) {
    final sessionHealthAssessment = _healthAssessment(
      map['sessionHealthAssessment'],
    );
    final captureDiagnostics = ARCaptureDiagnostics.tryFromMap(
      map['captureDiagnostics'],
    );
    final sessionLifecycleEvent = ARSessionLifecycleEvent.tryFromMap(
      map['sessionLifecycleEvent'],
    );
    final type = _eventTypeFromName(map['type'] as String?) ??
        (captureDiagnostics != null
            ? ARDiagnosticsTimelineEventType.captureDiagnostics
            : sessionLifecycleEvent != null
                ? ARDiagnosticsTimelineEventType.sessionLifecycle
                : ARDiagnosticsTimelineEventType.sessionHealth);
    final recordedAt = _dateTime(map['recordedAt']) ??
        sessionHealthAssessment?.snapshot.sampledAt ??
        captureDiagnostics?.capturedAt ??
        sessionLifecycleEvent?.occurredAt ??
        ARCaptureDiagnostics.unknownCapturedAt;
    final source = _string(
      map['source'],
      captureDiagnostics?.source ??
          sessionLifecycleEvent?.source ??
          'ar_engine',
    );
    final summaryLabel = _string(
      map['summaryLabel'],
      captureDiagnostics?.summaryLabel ??
          sessionLifecycleEvent?.summaryLabel ??
          sessionHealthAssessment?.hudLabel ??
          _defaultSummaryLabel(type),
    );
    final detailLabel = _nullableString(map['detailLabel']) ??
        captureDiagnostics?.captureReadinessGuidanceLabel ??
        sessionLifecycleEvent?.detailLabel ??
        sessionHealthAssessment?.detailLabel;
    return ARDiagnosticsTimelineEvent(
      type: type,
      recordedAt: recordedAt,
      source: source,
      sessionId:
          _nullableString(map['sessionId']) ?? captureDiagnostics?.sessionId,
      summaryLabel: summaryLabel,
      detailLabel: detailLabel,
      severity: _severityFromName(map['severity'] as String?) ??
          sessionHealthAssessment?.severity ??
          sessionLifecycleEvent?.severity ??
          (captureDiagnostics == null
              ? null
              : _captureDiagnosticsSeverity(captureDiagnostics)),
      sessionHealthAssessment: sessionHealthAssessment,
      captureDiagnostics: captureDiagnostics,
      sessionLifecycleEvent: sessionLifecycleEvent,
    );
  }

  static ARDiagnosticsTimelineEvent? tryFromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ARDiagnosticsTimelineEvent.fromMap(value);
    } on Object {
      return null;
    }
  }

  final ARDiagnosticsTimelineEventType type;
  final DateTime recordedAt;
  final String source;
  final String? sessionId;
  final String summaryLabel;
  final String? detailLabel;
  final ARSessionHealthSeverity? severity;
  final ARSessionHealthAssessment? sessionHealthAssessment;
  final ARCaptureDiagnostics? captureDiagnostics;
  final ARSessionLifecycleEvent? sessionLifecycleEvent;

  bool get isWarning {
    final activeSeverity = severity;
    return activeSeverity != null &&
        activeSeverity != ARSessionHealthSeverity.good;
  }

  bool get isGood => severity == ARSessionHealthSeverity.good;

  bool get isBlocked => severity == ARSessionHealthSeverity.blocked;

  bool get isSessionHealth =>
      type == ARDiagnosticsTimelineEventType.sessionHealth;

  bool get isCaptureDiagnostics =>
      type == ARDiagnosticsTimelineEventType.captureDiagnostics;

  bool get isSessionLifecycle =>
      type == ARDiagnosticsTimelineEventType.sessionLifecycle;

  String get typeLabel => switch (type) {
        ARDiagnosticsTimelineEventType.sessionHealth => 'Session health',
        ARDiagnosticsTimelineEventType.captureDiagnostics =>
          'Capture diagnostics',
        ARDiagnosticsTimelineEventType.sessionLifecycle => 'Session lifecycle',
      };

  String? get severityLabel {
    final activeSeverity = severity;
    return activeSeverity == null
        ? null
        : switch (activeSeverity) {
            ARSessionHealthSeverity.good => 'Good',
            ARSessionHealthSeverity.warning => 'Warning',
            ARSessionHealthSeverity.blocked => 'Blocked',
          };
  }

  String get displayLabel {
    final activeSeverityLabel = severityLabel;
    return activeSeverityLabel == null
        ? '$typeLabel: $summaryLabel'
        : '$typeLabel: $summaryLabel ($activeSeverityLabel)';
  }

  String get cacheKey {
    final sessionPart =
        sessionId == null || sessionId!.isEmpty ? 'sessionless' : sessionId!;
    return '${type.name}:$source:$sessionPart:'
        '${recordedAt.toUtc().toIso8601String()}:$summaryLabel';
  }

  List<String> get metadataLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          typeLabel,
          summaryLabel,
          detailLabel,
          severity == null ? null : 'AR ${severity!.name}',
          ...?captureDiagnostics?.metadataLabels,
          ...?sessionLifecycleEvent?.metadataLabels,
        ]),
      );

  List<String> get searchLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          displayLabel,
          typeLabel,
          source,
          sessionId,
          summaryLabel,
          detailLabel,
          severityLabel,
          sessionHealthAssessment?.primaryIssue?.name,
          sessionHealthAssessment?.primaryGuidance?.actionLabel,
          sessionHealthAssessment?.primaryGuidance?.message,
          captureDiagnostics?.sessionReadiness?.label,
          captureDiagnostics?.sessionReadiness?.detailLabel,
          captureDiagnostics?.nativePlacementReadiness?.label,
          captureDiagnostics?.nativePlacementReadiness?.detailLabel,
          captureDiagnostics?.captureCapability?.readiness?.label,
          captureDiagnostics?.captureCapability?.readiness?.detailLabel,
          captureDiagnostics?.captureCapability?.readiness?.primaryIssue?.name,
          captureDiagnostics?.captureCapability?.readinessGuidanceLabel,
          sessionLifecycleEvent?.kind.name,
          sessionLifecycleEvent?.kindLabel,
          sessionLifecycleEvent?.code,
          ...metadataLabels,
        ]),
      );

  String get searchLabel => _searchLabel(searchLabels);

  bool matchesQuery(String query) => _matchesSearchLabel(searchLabel, query);

  Map<String, Object?> toMap() => <String, Object?>{
        'type': type.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'source': source,
        'sessionId': sessionId,
        'summaryLabel': summaryLabel,
        'detailLabel': detailLabel,
        'severity': severity?.name,
        'sessionHealthAssessment': sessionHealthAssessment?.toMap(),
        'captureDiagnostics': captureDiagnostics?.toMap(),
        'sessionLifecycleEvent': sessionLifecycleEvent?.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      other is ARDiagnosticsTimelineEvent &&
      type == other.type &&
      recordedAt == other.recordedAt &&
      source == other.source &&
      sessionId == other.sessionId &&
      summaryLabel == other.summaryLabel &&
      detailLabel == other.detailLabel &&
      severity == other.severity &&
      sessionHealthAssessment == other.sessionHealthAssessment &&
      captureDiagnostics == other.captureDiagnostics &&
      sessionLifecycleEvent == other.sessionLifecycleEvent;

  @override
  int get hashCode => Object.hash(
        type,
        recordedAt,
        source,
        sessionId,
        summaryLabel,
        detailLabel,
        severity,
        sessionHealthAssessment,
        captureDiagnostics,
        sessionLifecycleEvent,
      );

  @override
  String toString() => 'ARDiagnosticsTimelineEvent('
      'type:${type.name} source:$source summary:$summaryLabel)';
}

class ARDiagnosticsTimelineQuery {
  const ARDiagnosticsTimelineQuery({
    this.text,
    this.sessionId,
    this.source,
    this.type,
    this.severity,
    this.sessionlessOnly = false,
    this.unknownSeverityOnly = false,
    this.warningOnly = false,
    this.blockedOnly = false,
    this.recordedAtOrAfter,
    this.recordedBefore,
    this.limit,
    this.newestFirst = true,
  }) : assert(limit == null || limit >= 0, 'limit must not be negative');

  factory ARDiagnosticsTimelineQuery.fromMap(Map<dynamic, dynamic> map) =>
      ARDiagnosticsTimelineQuery(
        text: _nullableString(map['text']) ?? _nullableString(map['query']),
        sessionId: _nullableString(map['sessionId']),
        source: _nullableString(map['source']),
        type: _eventTypeFromName(_nullableString(map['type'])),
        severity: _severityFromName(_nullableString(map['severity'])),
        sessionlessOnly: _bool(map['sessionlessOnly'], false),
        unknownSeverityOnly: _bool(map['unknownSeverityOnly'], false),
        warningOnly: _bool(map['warningOnly'], false),
        blockedOnly: _bool(map['blockedOnly'], false),
        recordedAtOrAfter: _dateTime(map['recordedAtOrAfter']),
        recordedBefore: _dateTime(map['recordedBefore']),
        limit: _nonNegativeInt(map['limit']),
        newestFirst: _bool(map['newestFirst'], true),
      );

  final String? text;
  final String? sessionId;
  final String? source;
  final ARDiagnosticsTimelineEventType? type;
  final ARSessionHealthSeverity? severity;
  final bool sessionlessOnly;
  final bool unknownSeverityOnly;
  final bool warningOnly;
  final bool blockedOnly;
  final DateTime? recordedAtOrAfter;
  final DateTime? recordedBefore;
  final int? limit;
  final bool newestFirst;

  String? get normalizedText => _nullableTrimmedString(text);

  bool get hasText => normalizedText != null;

  bool get hasFilters =>
      hasText ||
      sessionId != null ||
      source != null ||
      type != null ||
      severity != null ||
      sessionlessOnly ||
      unknownSeverityOnly ||
      warningOnly ||
      blockedOnly ||
      recordedAtOrAfter != null ||
      recordedBefore != null ||
      limit != null;

  bool matches(ARDiagnosticsTimelineEvent event) {
    final activeText = normalizedText;
    if (activeText != null && !event.matchesQuery(activeText)) {
      return false;
    }
    if (sessionId != null && event.sessionId != sessionId) {
      return false;
    }
    if (sessionlessOnly && event.sessionId != null) {
      return false;
    }
    if (source != null && event.source != source) {
      return false;
    }
    if (type != null && event.type != type) {
      return false;
    }
    if (severity != null && event.severity != severity) {
      return false;
    }
    if (unknownSeverityOnly && event.severity != null) {
      return false;
    }
    if (warningOnly && !event.isWarning) {
      return false;
    }
    if (blockedOnly && !event.isBlocked) {
      return false;
    }
    final from = recordedAtOrAfter?.toUtc();
    if (from != null && event.recordedAt.toUtc().isBefore(from)) {
      return false;
    }
    final before = recordedBefore?.toUtc();
    if (before != null && !event.recordedAt.toUtc().isBefore(before)) {
      return false;
    }
    return true;
  }

  ARDiagnosticsTimelineQuery copyWith({
    Object? text = _timelineQueryUnset,
    Object? sessionId = _timelineQueryUnset,
    Object? source = _timelineQueryUnset,
    Object? type = _timelineQueryUnset,
    Object? severity = _timelineQueryUnset,
    bool? sessionlessOnly,
    bool? unknownSeverityOnly,
    bool? warningOnly,
    bool? blockedOnly,
    Object? recordedAtOrAfter = _timelineQueryUnset,
    Object? recordedBefore = _timelineQueryUnset,
    Object? limit = _timelineQueryUnset,
    bool? newestFirst,
  }) =>
      ARDiagnosticsTimelineQuery(
        text:
            identical(text, _timelineQueryUnset) ? this.text : text as String?,
        sessionId: identical(sessionId, _timelineQueryUnset)
            ? this.sessionId
            : sessionId as String?,
        source: identical(source, _timelineQueryUnset)
            ? this.source
            : source as String?,
        type: identical(type, _timelineQueryUnset)
            ? this.type
            : type as ARDiagnosticsTimelineEventType?,
        severity: identical(severity, _timelineQueryUnset)
            ? this.severity
            : severity as ARSessionHealthSeverity?,
        sessionlessOnly: sessionlessOnly ?? this.sessionlessOnly,
        unknownSeverityOnly: unknownSeverityOnly ?? this.unknownSeverityOnly,
        warningOnly: warningOnly ?? this.warningOnly,
        blockedOnly: blockedOnly ?? this.blockedOnly,
        recordedAtOrAfter: identical(
          recordedAtOrAfter,
          _timelineQueryUnset,
        )
            ? this.recordedAtOrAfter
            : recordedAtOrAfter as DateTime?,
        recordedBefore: identical(recordedBefore, _timelineQueryUnset)
            ? this.recordedBefore
            : recordedBefore as DateTime?,
        limit:
            identical(limit, _timelineQueryUnset) ? this.limit : limit as int?,
        newestFirst: newestFirst ?? this.newestFirst,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'text': normalizedText,
        'sessionId': sessionId,
        'source': source,
        'type': type?.name,
        'severity': severity?.name,
        'sessionlessOnly': sessionlessOnly,
        'unknownSeverityOnly': unknownSeverityOnly,
        'warningOnly': warningOnly,
        'blockedOnly': blockedOnly,
        'recordedAtOrAfter': recordedAtOrAfter?.toUtc().toIso8601String(),
        'recordedBefore': recordedBefore?.toUtc().toIso8601String(),
        'limit': limit,
        'newestFirst': newestFirst,
      };

  @override
  bool operator ==(Object other) =>
      other is ARDiagnosticsTimelineQuery &&
      normalizedText == other.normalizedText &&
      sessionId == other.sessionId &&
      source == other.source &&
      type == other.type &&
      severity == other.severity &&
      sessionlessOnly == other.sessionlessOnly &&
      unknownSeverityOnly == other.unknownSeverityOnly &&
      warningOnly == other.warningOnly &&
      blockedOnly == other.blockedOnly &&
      recordedAtOrAfter == other.recordedAtOrAfter &&
      recordedBefore == other.recordedBefore &&
      limit == other.limit &&
      newestFirst == other.newestFirst;

  @override
  int get hashCode => Object.hash(
        normalizedText,
        sessionId,
        source,
        type,
        severity,
        sessionlessOnly,
        unknownSeverityOnly,
        warningOnly,
        blockedOnly,
        recordedAtOrAfter,
        recordedBefore,
        limit,
        newestFirst,
      );

  @override
  String toString() => 'ARDiagnosticsTimelineQuery('
      'text:$text sessionId:$sessionId source:$source)';
}

class ARDiagnosticsTimelineFacet {
  const ARDiagnosticsTimelineFacet({
    required this.kind,
    required this.value,
    required this.label,
    required this.count,
    required this.query,
  }) : assert(count >= 0, 'count must not be negative');

  factory ARDiagnosticsTimelineFacet.fromMap(Map<dynamic, dynamic> map) {
    final queryMap = map['query'];
    final value = _string(map['value'], '');
    return ARDiagnosticsTimelineFacet(
      kind: _facetKindFromName(_nullableString(map['kind'])) ??
          ARDiagnosticsTimelineFacetKind.source,
      value: value,
      label: _string(map['label'], value),
      count: _nonNegativeInt(map['count']) ?? 0,
      query: queryMap is Map
          ? ARDiagnosticsTimelineQuery.fromMap(queryMap)
          : const ARDiagnosticsTimelineQuery(),
    );
  }

  final ARDiagnosticsTimelineFacetKind kind;
  final String value;
  final String label;
  final int count;
  final ARDiagnosticsTimelineQuery query;

  String get kindLabel => _facetKindLabel(kind);

  String get countLabel => '$label ($count)';

  List<String> get searchLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          kindLabel,
          value,
          label,
          countLabel,
        ]),
      );

  String get searchLabel => _searchLabel(searchLabels);

  bool matchesQuery(String query) => _matchesSearchLabel(searchLabel, query);

  Map<String, Object?> toMap() => <String, Object?>{
        'kind': kind.name,
        'value': value,
        'label': label,
        'count': count,
        'query': query.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      other is ARDiagnosticsTimelineFacet &&
      kind == other.kind &&
      value == other.value &&
      label == other.label &&
      count == other.count &&
      query == other.query;

  @override
  int get hashCode => Object.hash(kind, value, label, count, query);

  @override
  String toString() => 'ARDiagnosticsTimelineFacet('
      'kind:${kind.name} label:$label count:$count)';
}

class ARDiagnosticsTimelineQueryResult {
  ARDiagnosticsTimelineQueryResult({
    this.query,
    Iterable<ARDiagnosticsTimelineEvent> events = const [],
  }) : events = List<ARDiagnosticsTimelineEvent>.unmodifiable(events);

  factory ARDiagnosticsTimelineQueryResult.fromMap(
    Map<dynamic, dynamic> map,
  ) {
    final entries = map['events'];
    final queryMap = map['query'];
    return ARDiagnosticsTimelineQueryResult(
      query:
          queryMap is Map ? ARDiagnosticsTimelineQuery.fromMap(queryMap) : null,
      events: entries is Iterable
          ? entries.map(ARDiagnosticsTimelineEvent.tryFromMap).whereType()
          : const <ARDiagnosticsTimelineEvent>[],
    );
  }

  final ARDiagnosticsTimelineQuery? query;
  final List<ARDiagnosticsTimelineEvent> events;

  int get length => events.length;

  bool get isEmpty => events.isEmpty;

  bool get isNotEmpty => events.isNotEmpty;

  List<ARDiagnosticsTimelineEvent> get warningValues =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        events.where((entry) => entry.isWarning),
      );

  List<ARDiagnosticsTimelineEvent> get blockedValues =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        events.where((entry) => entry.isBlocked),
      );

  int get warningCount => warningValues.length;

  int get blockedCount => blockedValues.length;

  int get goodCount => events.where((entry) => entry.isGood).length;

  int get unknownSeverityCount =>
      events.where((entry) => entry.severity == null).length;

  Map<ARDiagnosticsTimelineEventType, int> get typeCounts =>
      _countBy<ARDiagnosticsTimelineEventType>(
        events,
        (entry) => entry.type,
      );

  Map<ARSessionHealthSeverity, int> get severityCounts =>
      _countByOptional<ARSessionHealthSeverity>(
        events,
        (entry) => entry.severity,
      );

  Map<String, int> get sourceCounts => _countBy<String>(
        events,
        (entry) => entry.source,
      );

  Map<String?, int> get sessionCounts => _countBy<String?>(
        events,
        (entry) => entry.sessionId,
      );

  ARDiagnosticsTimelineEvent? get latest => _latestEventWhere(
        events,
        (_) => true,
      );

  ARDiagnosticsTimelineEvent? get latestWarning => _latestEventWhere(
        events,
        (entry) => entry.isWarning,
      );

  ARDiagnosticsTimelineEvent? latestForSession(String? sessionId) =>
      _latestEventWhere(events, (entry) => entry.sessionId == sessionId);

  ARDiagnosticsTimelineEvent? latestOfType(
    ARDiagnosticsTimelineEventType type,
  ) =>
      _latestEventWhere(events, (entry) => entry.type == type);

  List<ARDiagnosticsTimelineEvent> eventsForSession(String? sessionId) =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        events.where((entry) => entry.sessionId == sessionId),
      );

  List<ARDiagnosticsTimelineEvent> eventsOfType(
    ARDiagnosticsTimelineEventType type,
  ) =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        events.where((entry) => entry.type == type),
      );

  String get statusLabel {
    final hasQueryFilters = query?.hasFilters ?? false;
    final qualifier = hasQueryFilters ? 'matching ' : '';
    if (isEmpty) {
      return hasQueryFilters
          ? 'No AR diagnostics matches'
          : 'No AR diagnostics events';
    }
    if (blockedCount > 0) {
      return '$blockedCount ${qualifier}blocked AR '
          '${blockedCount == 1 ? 'event' : 'events'}';
    }
    if (warningCount > 0) {
      return '$warningCount ${qualifier}AR '
          '${warningCount == 1 ? 'warning' : 'warnings'}';
    }
    return '$length ${qualifier}AR '
        '${length == 1 ? 'event' : 'events'} healthy';
  }

  String? get warningCountLabel {
    final warnings = warningCount;
    if (warnings <= 0) {
      return null;
    }
    final qualifier = query?.hasFilters ?? false ? 'matching ' : '';
    return '$warnings ${qualifier}AR '
        '${warnings == 1 ? 'warning' : 'warnings'}';
  }

  List<String> typeCountLabels({int limit = 5}) {
    assert(limit >= 0, 'limit must not be negative');
    return _countLabels<ARDiagnosticsTimelineEventType>(
      typeCounts,
      _eventTypeLabel,
      limit: limit,
    );
  }

  List<String> severityCountLabels({int limit = 5}) {
    assert(limit >= 0, 'limit must not be negative');
    final labels = _countLabels<ARSessionHealthSeverity>(
      severityCounts,
      _severityLabel,
      limit: limit,
    );
    if (unknownSeverityCount <= 0 || labels.length >= limit) {
      return labels;
    }
    return List<String>.unmodifiable(
      <String>[
        ...labels,
        'Unknown ($unknownSeverityCount)',
      ],
    );
  }

  List<String> sourceCountLabels({int limit = 5}) {
    assert(limit >= 0, 'limit must not be negative');
    return _countLabels<String>(
      sourceCounts,
      (source) => source,
      limit: limit,
    );
  }

  List<String> sessionCountLabels({int limit = 5}) {
    assert(limit >= 0, 'limit must not be negative');
    return _countLabels<String?>(
      sessionCounts,
      (sessionId) => sessionId ?? 'Sessionless',
      limit: limit,
    );
  }

  List<ARDiagnosticsTimelineFacet> facets({int limitPerKind = 5}) {
    assert(limitPerKind >= 0, 'limitPerKind must not be negative');
    if (limitPerKind == 0) {
      return const <ARDiagnosticsTimelineFacet>[];
    }
    final baseQuery = query ?? const ARDiagnosticsTimelineQuery();
    final facets = <ARDiagnosticsTimelineFacet>[];
    for (final entry in typeCounts.entries.take(limitPerKind)) {
      facets.add(
        ARDiagnosticsTimelineFacet(
          kind: ARDiagnosticsTimelineFacetKind.type,
          value: entry.key.name,
          label: _eventTypeLabel(entry.key),
          count: entry.value,
          query: baseQuery.copyWith(type: entry.key),
        ),
      );
    }
    var severityFacetCount = 0;
    for (final entry in severityCounts.entries.take(limitPerKind)) {
      severityFacetCount += 1;
      facets.add(
        ARDiagnosticsTimelineFacet(
          kind: ARDiagnosticsTimelineFacetKind.severity,
          value: entry.key.name,
          label: _severityLabel(entry.key),
          count: entry.value,
          query: baseQuery.copyWith(
            severity: entry.key,
            unknownSeverityOnly: false,
          ),
        ),
      );
    }
    if (unknownSeverityCount > 0 && severityFacetCount < limitPerKind) {
      facets.add(
        ARDiagnosticsTimelineFacet(
          kind: ARDiagnosticsTimelineFacetKind.severity,
          value: 'unknown',
          label: 'Unknown',
          count: unknownSeverityCount,
          query: baseQuery.copyWith(
            severity: null,
            unknownSeverityOnly: true,
          ),
        ),
      );
    }
    for (final entry in sourceCounts.entries.take(limitPerKind)) {
      facets.add(
        ARDiagnosticsTimelineFacet(
          kind: ARDiagnosticsTimelineFacetKind.source,
          value: entry.key,
          label: entry.key,
          count: entry.value,
          query: baseQuery.copyWith(source: entry.key),
        ),
      );
    }
    for (final entry in sessionCounts.entries.take(limitPerKind)) {
      facets.add(
        ARDiagnosticsTimelineFacet(
          kind: ARDiagnosticsTimelineFacetKind.session,
          value: entry.key ?? 'sessionless',
          label: entry.key ?? 'Sessionless',
          count: entry.value,
          query: baseQuery.copyWith(
            sessionId: entry.key,
            sessionlessOnly: entry.key == null,
          ),
        ),
      );
    }
    return List<ARDiagnosticsTimelineFacet>.unmodifiable(facets);
  }

  List<ARDiagnosticsTimelineFacet> facetsOfKind(
    ARDiagnosticsTimelineFacetKind kind, {
    int limit = 5,
  }) {
    assert(limit >= 0, 'limit must not be negative');
    return List<ARDiagnosticsTimelineFacet>.unmodifiable(
      facets(limitPerKind: limit).where((facet) => facet.kind == kind),
    );
  }

  List<String> facetLabels({int limitPerKind = 5}) {
    assert(limitPerKind >= 0, 'limitPerKind must not be negative');
    return List<String>.unmodifiable(
      facets(limitPerKind: limitPerKind).map((facet) => facet.countLabel),
    );
  }

  List<String> summaryLabels({int limit = 5}) {
    assert(limit >= 0, 'limit must not be negative');
    return List<String>.unmodifiable(
      events.take(limit).map((entry) => entry.summaryLabel),
    );
  }

  List<String> displayLabels({int limit = 5, bool warningsOnly = false}) {
    assert(limit >= 0, 'limit must not be negative');
    final source =
        warningsOnly ? events.where((entry) => entry.isWarning) : events;
    return List<String>.unmodifiable(
      source.take(limit).map((entry) => entry.displayLabel),
    );
  }

  List<String> get searchLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          statusLabel,
          warningCountLabel,
          ...typeCountLabels(),
          ...severityCountLabels(),
          ...sourceCountLabels(),
          ...sessionCountLabels(),
          ...events.expand((entry) => entry.searchLabels),
        ]),
      );

  String get searchLabel => _searchLabel(searchLabels);

  bool matchesQuery(String query) => _matchesSearchLabel(searchLabel, query);

  Map<String, Object?> toMap() => <String, Object?>{
        'query': query?.toMap(),
        'counts': <String, Object?>{
          'total': length,
          'warnings': warningCount,
          'blocked': blockedCount,
          'good': goodCount,
          'unknownSeverity': unknownSeverityCount,
        },
        'typeCounts': _stringKeyedCountMap<ARDiagnosticsTimelineEventType>(
          typeCounts,
          (type) => type.name,
        ),
        'severityCounts': _stringKeyedCountMap<ARSessionHealthSeverity>(
          severityCounts,
          (severity) => severity.name,
        ),
        'sourceCounts': sourceCounts,
        'sessionCounts': _stringKeyedCountMap<String?>(
          sessionCounts,
          (sessionId) => sessionId ?? 'sessionless',
        ),
        'facets': <Map<String, Object?>>[
          for (final facet in facets()) facet.toMap(),
        ],
        'events': <Map<String, Object?>>[
          for (final event in events) event.toMap(),
        ],
      };

  @override
  bool operator ==(Object other) =>
      other is ARDiagnosticsTimelineQueryResult &&
      query == other.query &&
      _listEquals(events, other.events);

  @override
  int get hashCode => Object.hash(query, Object.hashAll(events));

  @override
  String toString() => 'ARDiagnosticsTimelineQueryResult('
      'events:$length status:$statusLabel)';
}

class ARDiagnosticsTimeline {
  ARDiagnosticsTimeline({this.capacity = 32})
      : assert(capacity > 0, 'capacity must be positive');

  factory ARDiagnosticsTimeline.fromMap(
    Map<dynamic, dynamic> map, {
    int? capacity,
  }) {
    final timeline = ARDiagnosticsTimeline(
      capacity: capacity ?? _positiveInt(map['capacity'], 32),
    );
    final entries = map['entries'];
    if (entries is Iterable) {
      timeline.putAll(entries.map(ARDiagnosticsTimelineEvent.tryFromMap));
    }
    return timeline;
  }

  factory ARDiagnosticsTimeline.fromValues(
    Iterable<ARDiagnosticsTimelineEvent> values, {
    int capacity = 32,
  }) {
    final timeline = ARDiagnosticsTimeline(capacity: capacity);
    timeline.putAll(values);
    return timeline;
  }

  factory ARDiagnosticsTimeline.merged(
    Iterable<ARDiagnosticsTimeline> timelines, {
    int? capacity,
  }) {
    final sources = timelines.toList(growable: false);
    final indexedEvents = <_IndexedTimelineEvent>[];
    var index = 0;
    for (final timeline in sources) {
      for (final event in timeline.values) {
        indexedEvents.add(_IndexedTimelineEvent(event, index));
        index += 1;
      }
    }
    indexedEvents.sort(_compareIndexedTimelineEvents);
    return ARDiagnosticsTimeline.fromValues(
      indexedEvents.map((entry) => entry.event),
      capacity: capacity ?? _mergedTimelineCapacity(sources),
    );
  }

  final int capacity;
  final LinkedHashMap<String, ARDiagnosticsTimelineEvent> _entries =
      LinkedHashMap<String, ARDiagnosticsTimelineEvent>();

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  bool get isNotEmpty => _entries.isNotEmpty;

  List<ARDiagnosticsTimelineEvent> get values =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(_entries.values);

  List<ARDiagnosticsTimelineEvent> get newestFirst =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        _entries.values.toList().reversed,
      );

  List<ARDiagnosticsTimelineEvent> get warningValues =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        _entries.values.where((entry) => entry.isWarning),
      );

  List<ARDiagnosticsTimelineEvent> get blockedValues =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        _entries.values.where((entry) => entry.isBlocked),
      );

  int get warningCount => warningValues.length;

  int get blockedCount => blockedValues.length;

  int get goodCount => _entries.values.where((entry) => entry.isGood).length;

  ARDiagnosticsTimelineEvent? get latest =>
      _entries.isEmpty ? null : _entries.values.last;

  ARDiagnosticsTimelineEvent? get latestWarning =>
      _latestWhere((entry) => entry.isWarning);

  ARDiagnosticsTimelineEvent? operator [](String key) => _entries[key];

  bool containsKey(String key) => _entries.containsKey(key);

  void put(ARDiagnosticsTimelineEvent event) {
    final key = event.cacheKey;
    _entries.remove(key);
    _entries[key] = event;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void putAll(Iterable<ARDiagnosticsTimelineEvent?> events) {
    for (final event in events) {
      if (event != null) {
        put(event);
      }
    }
  }

  ARDiagnosticsTimeline mergedWith(
    ARDiagnosticsTimeline other, {
    int? capacity,
  }) =>
      ARDiagnosticsTimeline.merged(
        <ARDiagnosticsTimeline>[this, other],
        capacity: capacity,
      );

  ARDiagnosticsTimelineEvent? latestForSession(String? sessionId) =>
      _latestWhere((entry) => entry.sessionId == sessionId);

  ARDiagnosticsTimelineEvent? latestOfType(
    ARDiagnosticsTimelineEventType type,
  ) =>
      _latestWhere((entry) => entry.type == type);

  List<ARDiagnosticsTimelineEvent> eventsForSession(String? sessionId) =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        _entries.values.where((entry) => entry.sessionId == sessionId),
      );

  List<ARDiagnosticsTimelineEvent> eventsOfType(
    ARDiagnosticsTimelineEventType type,
  ) =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        _entries.values.where((entry) => entry.type == type),
      );

  String get statusLabel {
    if (isEmpty) {
      return 'No AR diagnostics events';
    }
    if (blockedCount > 0) {
      return '$blockedCount blocked AR ${blockedCount == 1 ? 'event' : 'events'}';
    }
    if (warningCount > 0) {
      return '$warningCount AR ${warningCount == 1 ? 'warning' : 'warnings'}';
    }
    return '$length AR ${length == 1 ? 'event' : 'events'} healthy';
  }

  String? get warningCountLabel {
    final warnings = warningCount;
    if (warnings <= 0) {
      return null;
    }
    return '$warnings AR ${warnings == 1 ? 'warning' : 'warnings'}';
  }

  List<String> summaryLabels({int limit = 5}) {
    assert(limit >= 0, 'limit must not be negative');
    return List<String>.unmodifiable(
      newestFirst.take(limit).map((entry) => entry.summaryLabel),
    );
  }

  List<String> displayLabels({int limit = 5, bool warningsOnly = false}) {
    assert(limit >= 0, 'limit must not be negative');
    final source = warningsOnly
        ? newestFirst.where((entry) => entry.isWarning)
        : newestFirst;
    return List<String>.unmodifiable(
      source.take(limit).map((entry) => entry.displayLabel),
    );
  }

  List<String> get searchLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          statusLabel,
          warningCountLabel,
          ...newestFirst.expand((entry) => entry.searchLabels),
        ]),
      );

  String get searchLabel => _searchLabel(searchLabels);

  bool matchesQuery(String query) => _matchesSearchLabel(searchLabel, query);

  List<ARDiagnosticsTimelineEvent> eventsMatching(
    ARDiagnosticsTimelineQuery query,
  ) {
    final source = query.newestFirst ? newestFirst : values;
    final matches = source.where(query.matches);
    return List<ARDiagnosticsTimelineEvent>.unmodifiable(
      query.limit == null ? matches : matches.take(query.limit!),
    );
  }

  ARDiagnosticsTimelineQueryResult query(
    ARDiagnosticsTimelineQuery criteria,
  ) =>
      ARDiagnosticsTimelineQueryResult(
        query: criteria,
        events: eventsMatching(criteria),
      );

  List<ARDiagnosticsTimelineEvent> eventsMatchingQuery(
    String query, {
    bool newestFirst = true,
  }) =>
      eventsMatching(
        ARDiagnosticsTimelineQuery(
          text: query,
          newestFirst: newestFirst,
        ),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'capacity': capacity,
        'entries': <Map<String, Object?>>[
          for (final event in _entries.values) event.toMap(),
        ],
      };

  ARDiagnosticsTimelineEvent? remove(String key) => _entries.remove(key);

  int removeWhere(bool Function(ARDiagnosticsTimelineEvent event) test) {
    final keysToRemove = <String>[
      for (final entry in _entries.entries)
        if (test(entry.value)) entry.key,
    ];
    for (final key in keysToRemove) {
      _entries.remove(key);
    }
    return keysToRemove.length;
  }

  int pruneOlderThan(DateTime cutoff) {
    final utcCutoff = cutoff.toUtc();
    return removeWhere(
      (event) => event.recordedAt.toUtc().isBefore(utcCutoff),
    );
  }

  int pruneStale({
    required DateTime now,
    required Duration maxAge,
  }) {
    assert(!maxAge.isNegative, 'maxAge must not be negative');
    return pruneOlderThan(now.toUtc().subtract(maxAge));
  }

  void clear() {
    _entries.clear();
  }

  ARDiagnosticsTimelineEvent? _latestWhere(
    bool Function(ARDiagnosticsTimelineEvent event) test,
  ) {
    for (final event in _entries.values.toList().reversed) {
      if (test(event)) {
        return event;
      }
    }
    return null;
  }
}

extension ARCaptureDiagnosticsTimelineEvents on ARCaptureDiagnostics {
  List<ARDiagnosticsTimelineEvent> toTimelineEvents({
    bool includeLifecycleEvents = false,
  }) =>
      List<ARDiagnosticsTimelineEvent>.unmodifiable(
        <ARDiagnosticsTimelineEvent>[
          if (includeLifecycleEvents)
            for (final lifecycleEvent in toSessionLifecycleEvents())
              ARDiagnosticsTimelineEvent.fromSessionLifecycle(lifecycleEvent),
          ARDiagnosticsTimelineEvent.fromCaptureDiagnostics(this),
        ],
      );

  List<ARSessionLifecycleEvent> toSessionLifecycleEvents() {
    final startedAt = sessionStartedAt;
    final eventAt = _diagnosticsLifecycleEventTime(this);
    final unsupportedFeatureKeys =
        unsupportedSessionFeatureKeys.toSet().toList()..sort();
    return List<ARSessionLifecycleEvent>.unmodifiable(
      <ARSessionLifecycleEvent>[
        if (startedAt != null)
          ARSessionLifecycleEvent.create(
            kind: ARSessionLifecycleEventKind.sessionStarted,
            occurredAt: startedAt,
            source: source,
            sessionId: sessionId,
            severity: ARSessionHealthSeverity.good,
            metadata: <String, Object?>{
              'captureSource': source,
              'capturedAt': capturedAt,
            },
          ),
        if (unsupportedFeatureKeys.isNotEmpty)
          ARSessionLifecycleEvent.create(
            kind: ARSessionLifecycleEventKind.configurationDowngraded,
            occurredAt: eventAt,
            source: source,
            sessionId: sessionId,
            summaryLabel: 'Configuration downgraded',
            detailLabel: unsupportedSessionFeatureCountLabel,
            severity: ARSessionHealthSeverity.warning,
            code: 'unsupported_session_features',
            metadata: <String, Object?>{
              'captureSource': source,
              'unsupportedFeatureKeys': unsupportedFeatureKeys,
              'unsupportedFeatureKeysLabel': unsupportedFeatureKeys.join(', '),
              'capturedAt': capturedAt,
            },
          ),
        if (hasNativeSceneFailure)
          ARSessionLifecycleEvent.create(
            kind: ARSessionLifecycleEventKind.nativeError,
            occurredAt: eventAt,
            source: source,
            sessionId: sessionId,
            summaryLabel: 'Native AR scene sync failed',
            detailLabel: nativeSceneFailureMessage ?? detailStatusLabel,
            severity: ARSessionHealthSeverity.warning,
            code: 'native_scene_failure',
            metadata: <String, Object?>{
              'captureSource': source,
              'activeMemoryCount': activeMemoryCount,
              'sceneChangeCount': sceneChangeCount,
              'capturedAt': capturedAt,
            },
          ),
        if (hasCloudAnchorFailures)
          ARSessionLifecycleEvent.create(
            kind: ARSessionLifecycleEventKind.nativeError,
            occurredAt: eventAt,
            source: source,
            sessionId: sessionId,
            summaryLabel: 'Cloud anchor sync failed',
            detailLabel: cloudAnchorStatusLabel,
            severity: ARSessionHealthSeverity.warning,
            code: 'cloud_anchor_failure',
            metadata: <String, Object?>{
              'captureSource': source,
              'cloudAnchorsEnabled': cloudAnchorsEnabled,
              'capturedAt': capturedAt,
            },
          ),
      ],
    );
  }
}

extension ARCaptureDiagnosticsMemoryCacheTimeline
    on ARCaptureDiagnosticsMemoryCache {
  ARDiagnosticsTimeline toTimeline({
    int? capacity,
    bool syncableOnly = false,
    bool includeLifecycleEvents = false,
  }) {
    final diagnostics = syncableOnly ? syncableValues : values;
    return ARDiagnosticsTimeline.fromValues(
      diagnostics.expand(
        (diagnostics) => diagnostics.toTimelineEvents(
          includeLifecycleEvents: includeLifecycleEvents,
        ),
      ),
      capacity: capacity ??
          (includeLifecycleEvents
              ? this.capacity * _captureDiagnosticsTimelineEventCapacityFactor
              : this.capacity),
    );
  }
}

const _captureDiagnosticsTimelineEventCapacityFactor = 5;

ARDiagnosticsTimelineEventType? _eventTypeFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final type in ARDiagnosticsTimelineEventType.values) {
    if (type.name == name) {
      return type;
    }
  }
  return null;
}

ARDiagnosticsTimelineFacetKind? _facetKindFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final kind in ARDiagnosticsTimelineFacetKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  return null;
}

String _facetKindLabel(ARDiagnosticsTimelineFacetKind kind) => switch (kind) {
      ARDiagnosticsTimelineFacetKind.type => 'Type',
      ARDiagnosticsTimelineFacetKind.severity => 'Severity',
      ARDiagnosticsTimelineFacetKind.source => 'Source',
      ARDiagnosticsTimelineFacetKind.session => 'Session',
    };

String _eventTypeLabel(ARDiagnosticsTimelineEventType type) => switch (type) {
      ARDiagnosticsTimelineEventType.sessionHealth => 'Session health',
      ARDiagnosticsTimelineEventType.captureDiagnostics =>
        'Capture diagnostics',
      ARDiagnosticsTimelineEventType.sessionLifecycle => 'Session lifecycle',
    };

ARSessionLifecycleEventKind? _lifecycleKindFromName(String? name) {
  if (name == null) {
    return null;
  }
  for (final kind in ARSessionLifecycleEventKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  return null;
}

String _lifecycleKindLabel(ARSessionLifecycleEventKind kind) => switch (kind) {
      ARSessionLifecycleEventKind.sessionStarted => 'Session started',
      ARSessionLifecycleEventKind.sessionPaused => 'Session paused',
      ARSessionLifecycleEventKind.sessionResumed => 'Session resumed',
      ARSessionLifecycleEventKind.sessionInterrupted => 'Session interrupted',
      ARSessionLifecycleEventKind.sessionEnded => 'Session ended',
      ARSessionLifecycleEventKind.permissionDenied => 'Permission denied',
      ARSessionLifecycleEventKind.configurationChanged =>
        'Configuration changed',
      ARSessionLifecycleEventKind.configurationDowngraded =>
        'Configuration downgraded',
      ARSessionLifecycleEventKind.nativeError => 'Native error',
      ARSessionLifecycleEventKind.anchorPlaced => 'Anchor placed',
      ARSessionLifecycleEventKind.anchorRemoved => 'Anchor removed',
      ARSessionLifecycleEventKind.custom => 'Lifecycle event',
    };

String _defaultLifecycleSummaryLabel(ARSessionLifecycleEventKind kind) =>
    _lifecycleKindLabel(kind);

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

String _severityLabel(ARSessionHealthSeverity severity) => switch (severity) {
      ARSessionHealthSeverity.good => 'Good',
      ARSessionHealthSeverity.warning => 'Warning',
      ARSessionHealthSeverity.blocked => 'Blocked',
    };

ARSessionHealthSeverity? _captureDiagnosticsSeverity(
  ARCaptureDiagnostics diagnostics,
) {
  final healthSeverity = diagnostics.sessionHealthAssessment?.severity;
  if (healthSeverity != null) {
    return healthSeverity;
  }
  final readiness = diagnostics.captureCapability?.readiness;
  if (readiness != null) {
    if (readiness.isBlocked) {
      return ARSessionHealthSeverity.blocked;
    }
    if (readiness.isLimited) {
      return ARSessionHealthSeverity.warning;
    }
  }
  if (diagnostics.hasNativeSceneFailure || diagnostics.hasCloudAnchorFailures) {
    return ARSessionHealthSeverity.warning;
  }
  return null;
}

DateTime _diagnosticsLifecycleEventTime(ARCaptureDiagnostics diagnostics) {
  if (diagnostics.hasValidCapturedAt) {
    return diagnostics.capturedAt;
  }
  return diagnostics.sessionStartedAt ?? diagnostics.capturedAt;
}

ARSessionHealthAssessment? _healthAssessment(Object? value) {
  if (value is! Map) {
    return null;
  }
  try {
    return ARSessionHealthAssessment.fromMap(
      Map<dynamic, dynamic>.from(value),
    );
  } on Object {
    return null;
  }
}

DateTime? _dateTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

String _string(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

String? _nullableTrimmedString(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _positiveInt(Object? value, int fallback) =>
    value is int && value > 0 ? value : fallback;

String _defaultSummaryLabel(ARDiagnosticsTimelineEventType type) =>
    switch (type) {
      ARDiagnosticsTimelineEventType.sessionHealth => 'AR session health',
      ARDiagnosticsTimelineEventType.captureDiagnostics =>
        'AR capture diagnostics',
      ARDiagnosticsTimelineEventType.sessionLifecycle => 'AR session lifecycle',
    };

Iterable<String> _uniqueLabels(Iterable<String?> labels) sync* {
  final seen = <String>{};
  for (final label in labels) {
    final normalized = label?.trim();
    if (normalized == null || normalized.isEmpty) {
      continue;
    }
    if (seen.add(normalized.toLowerCase())) {
      yield normalized;
    }
  }
}

String _searchLabel(Iterable<String> labels) =>
    labels.map((label) => label.toLowerCase()).join(' ');

bool _matchesSearchLabel(String searchLabel, String query) {
  final terms = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList();
  if (terms.isEmpty) {
    return false;
  }
  return terms.every(searchLabel.contains);
}

ARDiagnosticsTimelineEvent? _latestEventWhere(
  Iterable<ARDiagnosticsTimelineEvent> events,
  bool Function(ARDiagnosticsTimelineEvent event) test,
) {
  ARDiagnosticsTimelineEvent? latest;
  for (final event in events) {
    if (!test(event)) {
      continue;
    }
    if (latest == null ||
        !event.recordedAt.toUtc().isBefore(latest.recordedAt.toUtc())) {
      latest = event;
    }
  }
  return latest;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

class _IndexedTimelineEvent {
  const _IndexedTimelineEvent(this.event, this.index);

  final ARDiagnosticsTimelineEvent event;
  final int index;
}

int _compareIndexedTimelineEvents(
  _IndexedTimelineEvent left,
  _IndexedTimelineEvent right,
) {
  final recordedAtComparison =
      left.event.recordedAt.toUtc().compareTo(right.event.recordedAt.toUtc());
  if (recordedAtComparison != 0) {
    return recordedAtComparison;
  }
  return left.index.compareTo(right.index);
}

int _mergedTimelineCapacity(List<ARDiagnosticsTimeline> timelines) {
  final capacity = timelines.fold<int>(
    0,
    (total, timeline) => total + timeline.capacity,
  );
  return capacity > 0 ? capacity : 32;
}

Map<K, int> _countBy<K>(
  Iterable<ARDiagnosticsTimelineEvent> events,
  K Function(ARDiagnosticsTimelineEvent event) keyOf,
) {
  final counts = <K, int>{};
  for (final event in events) {
    final key = keyOf(event);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return Map<K, int>.unmodifiable(counts);
}

Map<K, int> _countByOptional<K extends Object>(
  Iterable<ARDiagnosticsTimelineEvent> events,
  K? Function(ARDiagnosticsTimelineEvent event) keyOf,
) {
  final counts = <K, int>{};
  for (final event in events) {
    final key = keyOf(event);
    if (key == null) {
      continue;
    }
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return Map<K, int>.unmodifiable(counts);
}

List<String> _countLabels<K>(
  Map<K, int> counts,
  String Function(K key) labelOf, {
  required int limit,
}) =>
    List<String>.unmodifiable(
      counts.entries
          .take(limit)
          .map((entry) => '${labelOf(entry.key)} (${entry.value})'),
    );

Map<String, int> _stringKeyedCountMap<K>(
  Map<K, int> counts,
  String Function(K key) keyOf,
) =>
    Map<String, int>.unmodifiable(
      <String, int>{
        for (final entry in counts.entries) keyOf(entry.key): entry.value,
      },
    );

Map<dynamic, dynamic>? _map(Object? value) =>
    value is Map ? Map<dynamic, dynamic>.from(value) : null;

Map<String, Object?> _objectMap(Object? value) {
  final map = _map(value);
  return map == null ? const <String, Object?>{} : _jsonMap(map);
}

Map<String, Object?> _jsonMap(Map<dynamic, dynamic> value) => <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _jsonValue(entry.value),
    };

Object? _jsonValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Map) {
    return _jsonMap(value);
  }
  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(_jsonValue));
  }
  return value.toString();
}

String _metadataEntryLabel(MapEntry<String, Object?> entry) {
  final value = entry.value;
  if (value == null) {
    return entry.key;
  }
  if (value is Iterable || value is Map) {
    return entry.key;
  }
  return '${entry.key}: $value';
}

bool _bool(Object? value, bool fallback) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return fallback;
}

int? _nonNegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;
