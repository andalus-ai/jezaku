import 'package:collection/collection.dart';

import 'ar_capture_diagnostics.dart';
import 'ar_diagnostics_timeline.dart';

const _deepEquality = DeepCollectionEquality();

class ARDiagnosticsReport {
  ARDiagnosticsReport({
    DateTime? generatedAt,
    this.schemaVersion = currentSchemaVersion,
    required this.timeline,
    required this.queryResult,
    this.cachedCaptureCount = 0,
    this.syncableCaptureCount = 0,
    this.latestCapture,
  }) : generatedAt = (generatedAt ?? DateTime.now().toUtc()).toUtc();

  factory ARDiagnosticsReport.fromTimeline(
    ARDiagnosticsTimeline timeline, {
    DateTime? generatedAt,
    ARDiagnosticsTimelineQuery query = const ARDiagnosticsTimelineQuery(),
    int schemaVersion = currentSchemaVersion,
    int cachedCaptureCount = 0,
    int syncableCaptureCount = 0,
    ARCaptureDiagnostics? latestCapture,
  }) =>
      ARDiagnosticsReport(
        generatedAt: generatedAt,
        schemaVersion: schemaVersion,
        timeline: timeline,
        queryResult: timeline.query(query),
        cachedCaptureCount: cachedCaptureCount,
        syncableCaptureCount: syncableCaptureCount,
        latestCapture: latestCapture,
      );

  factory ARDiagnosticsReport.fromTimelines(
    Iterable<ARDiagnosticsTimeline> timelines, {
    DateTime? generatedAt,
    ARDiagnosticsTimelineQuery query = const ARDiagnosticsTimelineQuery(),
    int schemaVersion = currentSchemaVersion,
    int? timelineCapacity,
    int cachedCaptureCount = 0,
    int syncableCaptureCount = 0,
    ARCaptureDiagnostics? latestCapture,
  }) =>
      ARDiagnosticsReport.fromTimeline(
        ARDiagnosticsTimeline.merged(
          timelines,
          capacity: timelineCapacity,
        ),
        generatedAt: generatedAt,
        query: query,
        schemaVersion: schemaVersion,
        cachedCaptureCount: cachedCaptureCount,
        syncableCaptureCount: syncableCaptureCount,
        latestCapture: latestCapture,
      );

  factory ARDiagnosticsReport.fromMap(Map<dynamic, dynamic> map) {
    final timelineMap = _map(map['timeline']);
    final queryMap = _map(map['query']);
    final queryResultMap = _map(map['queryResult']);
    final query = queryMap == null
        ? const ARDiagnosticsTimelineQuery()
        : ARDiagnosticsTimelineQuery.fromMap(queryMap);
    final queryResult = queryResultMap == null
        ? null
        : ARDiagnosticsTimelineQueryResult.fromMap(queryResultMap);
    final timeline = timelineMap == null
        ? ARDiagnosticsTimeline.fromValues(
            queryResult?.events ?? const <ARDiagnosticsTimelineEvent>[],
          )
        : ARDiagnosticsTimeline.fromMap(timelineMap);
    return ARDiagnosticsReport(
      generatedAt: _dateTime(map['generatedAt']),
      schemaVersion: _positiveInt(map['schemaVersion'], currentSchemaVersion),
      timeline: timeline,
      queryResult: queryResult ?? timeline.query(query),
      cachedCaptureCount: _nonNegativeInt(map['cachedCaptureCount']) ?? 0,
      syncableCaptureCount: _nonNegativeInt(map['syncableCaptureCount']) ?? 0,
      latestCapture: ARCaptureDiagnostics.tryFromMap(map['latestCapture']),
    );
  }

  static const currentSchemaVersion = 1;

  static ARDiagnosticsReport? tryFromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ARDiagnosticsReport.fromMap(value);
    } on Object {
      return null;
    }
  }

  final int schemaVersion;
  final DateTime generatedAt;
  final ARDiagnosticsTimeline timeline;
  final ARDiagnosticsTimelineQueryResult queryResult;
  final int cachedCaptureCount;
  final int syncableCaptureCount;
  final ARCaptureDiagnostics? latestCapture;

  ARDiagnosticsTimelineQuery get query =>
      queryResult.query ?? const ARDiagnosticsTimelineQuery();

  int get timelineEventCount => timeline.length;

  int get matchCount => queryResult.length;

  ARDiagnosticsTimelineEvent? get latestEvent => timeline.latest;

  ARDiagnosticsTimelineEvent? get latestWarning =>
      queryResult.latestWarning ?? timeline.latestWarning;

  List<ARDiagnosticsTimelineFacet> get facets => queryResult.facets();

  String get statusLabel =>
      query.hasFilters ? queryResult.statusLabel : timeline.statusLabel;

  String get cacheStatusLabel {
    if (cachedCaptureCount <= 0) {
      return 'No cached AR captures';
    }
    final captureLabel = cachedCaptureCount == 1 ? 'capture' : 'captures';
    return '$cachedCaptureCount cached AR $captureLabel, '
        '$syncableCaptureCount syncable';
  }

  List<String> get summaryLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          statusLabel,
          cacheStatusLabel,
          timeline.warningCountLabel,
          queryResult.warningCountLabel,
          latestCapture?.summaryLabel,
          latestWarning?.displayLabel,
          ...queryResult.facetLabels(limitPerKind: 3),
        ]),
      );

  Map<String, Object?> toMap({bool syncableOnly = false}) => <String, Object?>{
        'schemaVersion': schemaVersion,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'cachedCaptureCount': cachedCaptureCount,
        'syncableCaptureCount': syncableCaptureCount,
        'statusLabel': statusLabel,
        'cacheStatusLabel': cacheStatusLabel,
        'summaryLabels': summaryLabels,
        'latestCapture': syncableOnly
            ? latestCapture?.toSyncableMap()
            : latestCapture?.toMap(),
        'latestEvent': latestEvent?.toMap(),
        'latestWarning': latestWarning?.toMap(),
        'query': query.toMap(),
        'queryResult': queryResult.toMap(),
        'facets': <Map<String, Object?>>[
          for (final facet in facets) facet.toMap(),
        ],
        'timeline': timeline.toMap(),
      };

  Map<String, Object?> toSyncableMap() =>
      Map<String, Object?>.unmodifiable(toMap(syncableOnly: true));

  @override
  bool operator ==(Object other) =>
      other is ARDiagnosticsReport &&
      schemaVersion == other.schemaVersion &&
      generatedAt == other.generatedAt &&
      cachedCaptureCount == other.cachedCaptureCount &&
      syncableCaptureCount == other.syncableCaptureCount &&
      latestCapture == other.latestCapture &&
      queryResult == other.queryResult &&
      _deepEquality.equals(timeline.toMap(), other.timeline.toMap());

  @override
  int get hashCode => Object.hash(
        schemaVersion,
        generatedAt,
        cachedCaptureCount,
        syncableCaptureCount,
        latestCapture,
        queryResult,
        _deepEquality.hash(timeline.toMap()),
      );

  @override
  String toString() => 'ARDiagnosticsReport('
      'events:$timelineEventCount matches:$matchCount status:$statusLabel)';
}

abstract class ARDiagnosticsReportStore {
  Future<ARDiagnosticsReport?> loadReport();

  Future<void> saveReport(ARDiagnosticsReport report);

  Future<void> clearReport();
}

class InMemoryARDiagnosticsReportStore implements ARDiagnosticsReportStore {
  InMemoryARDiagnosticsReportStore({
    Map<String, Object?>? initialSnapshot,
    this.syncableOnly = false,
  }) : _snapshot = _copySnapshot(initialSnapshot);

  final bool syncableOnly;
  Map<String, Object?>? _snapshot;

  bool get hasReport => _snapshot != null;

  Map<String, Object?>? get snapshot => _copySnapshot(_snapshot);

  @override
  Future<ARDiagnosticsReport?> loadReport() async {
    final activeSnapshot = _snapshot;
    if (activeSnapshot == null) {
      return null;
    }
    final report = ARDiagnosticsReport.tryFromMap(activeSnapshot);
    if (report == null) {
      _snapshot = null;
    }
    return report;
  }

  @override
  Future<void> saveReport(ARDiagnosticsReport report) async {
    _snapshot = _copySnapshot(
      syncableOnly ? report.toSyncableMap() : report.toMap(),
    );
  }

  @override
  Future<void> clearReport() async {
    _snapshot = null;
  }
}

extension ARDiagnosticsTimelineReport on ARDiagnosticsTimeline {
  ARDiagnosticsReport toReport({
    DateTime? generatedAt,
    ARDiagnosticsTimelineQuery query = const ARDiagnosticsTimelineQuery(),
    int cachedCaptureCount = 0,
    int syncableCaptureCount = 0,
    ARCaptureDiagnostics? latestCapture,
  }) =>
      ARDiagnosticsReport.fromTimeline(
        this,
        generatedAt: generatedAt,
        query: query,
        cachedCaptureCount: cachedCaptureCount,
        syncableCaptureCount: syncableCaptureCount,
        latestCapture: latestCapture,
      );
}

extension ARCaptureDiagnosticsMemoryCacheReport
    on ARCaptureDiagnosticsMemoryCache {
  ARDiagnosticsReport toReport({
    DateTime? generatedAt,
    ARDiagnosticsTimelineQuery query = const ARDiagnosticsTimelineQuery(),
    bool syncableOnly = false,
    bool includeLifecycleEvents = false,
    int? timelineCapacity,
  }) {
    final diagnostics = syncableOnly ? syncableValues : values;
    return ARDiagnosticsReport.fromTimeline(
      toTimeline(
        capacity: timelineCapacity,
        syncableOnly: syncableOnly,
        includeLifecycleEvents: includeLifecycleEvents,
      ),
      generatedAt: generatedAt,
      query: query,
      cachedCaptureCount: length,
      syncableCaptureCount: syncableValues.length,
      latestCapture: diagnostics.isEmpty ? null : diagnostics.last,
    );
  }
}

Map<dynamic, dynamic>? _map(Object? value) =>
    value is Map ? Map<dynamic, dynamic>.from(value) : null;

Map<String, Object?>? _copySnapshot(Map<String, Object?>? snapshot) =>
    snapshot == null ? null : Map<String, Object?>.unmodifiable(snapshot);

DateTime? _dateTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

int _positiveInt(Object? value, int fallback) =>
    value is int && value > 0 ? value : fallback;

int? _nonNegativeInt(Object? value) =>
    value is int && value >= 0 ? value : null;

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
