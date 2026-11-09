import 'dart:collection';

import 'package:collection/collection.dart';

import 'ar_capture_capability.dart';
import 'ar_session_health_assessment.dart';

const _unset = Object();
const _deepEquality = DeepCollectionEquality();
const _featureKeyEquality = SetEquality<String>();

class ARCaptureDiagnostics {
  const ARCaptureDiagnostics({
    required this.capturedAt,
    this.schemaVersion = currentSchemaVersion,
    this.source = 'ar_capture',
    this.sessionId,
    this.sessionStartedAt,
    this.lastSyncedAt,
    this.hudStatusLabel = 'AR pending',
    this.detailStatusLabel = 'AR diagnostics pending',
    this.syncStatusLabel = 'Native sync pending',
    this.sessionHealthStatusLabel = 'No runtime health sample yet',
    this.sessionReadinessLabel = 'AR readiness pending',
    this.nativePlacementStatusLabel = 'Waiting for AR placement readiness',
    this.cloudAnchorStatusLabel = 'Cloud anchors unavailable',
    this.cloudAnchorsEnabled = false,
    this.activeMemoryCount = 0,
    this.sceneChangeCount = 0,
    this.hasNativeSceneFailure = false,
    this.hasCloudAnchorFailures = false,
    this.unsupportedSessionFeatureKeys = const <String>[],
    this.nativeSceneFailureMessage,
    this.sessionReadiness,
    this.nativePlacementReadiness,
    this.sessionHealthAssessment,
    this.captureCapability,
    this.extra = const <String, Object?>{},
  });

  factory ARCaptureDiagnostics.fromMap(Map<dynamic, dynamic> map) {
    final knownKeys = <String>{
      'schemaVersion',
      'capturedAt',
      'source',
      'sessionId',
      'sessionStartedAt',
      'lastSyncedAt',
      'hudStatusLabel',
      'detailStatusLabel',
      'syncStatusLabel',
      'sessionHealthStatusLabel',
      'sessionReadinessLabel',
      'nativePlacementStatusLabel',
      'cloudAnchorStatusLabel',
      'cloudAnchorsEnabled',
      'activeMemoryCount',
      'sceneChangeCount',
      'hasNativeSceneFailure',
      'hasCloudAnchorFailures',
      'unsupportedSessionFeatureKeys',
      'nativeSceneFailureMessage',
      'sessionReadiness',
      'nativePlacementReadiness',
      'sessionHealthAssessment',
      'captureCapability',
    };
    return ARCaptureDiagnostics(
      schemaVersion: _int(map['schemaVersion'], currentSchemaVersion),
      capturedAt: _dateTime(map['capturedAt']) ?? unknownCapturedAt,
      source: _string(map['source'], 'ar_capture'),
      sessionId: _nullableString(map['sessionId']),
      sessionStartedAt: _dateTime(map['sessionStartedAt']),
      lastSyncedAt: _dateTime(map['lastSyncedAt']),
      hudStatusLabel: _string(map['hudStatusLabel'], 'AR pending'),
      detailStatusLabel: _string(
        map['detailStatusLabel'],
        'AR diagnostics pending',
      ),
      syncStatusLabel: _string(map['syncStatusLabel'], 'Native sync pending'),
      sessionHealthStatusLabel: _string(
        map['sessionHealthStatusLabel'],
        'No runtime health sample yet',
      ),
      sessionReadinessLabel: _string(
        map['sessionReadinessLabel'],
        'AR readiness pending',
      ),
      nativePlacementStatusLabel: _string(
        map['nativePlacementStatusLabel'],
        'Waiting for AR placement readiness',
      ),
      cloudAnchorStatusLabel: _string(
        map['cloudAnchorStatusLabel'],
        'Cloud anchors unavailable',
      ),
      cloudAnchorsEnabled: _bool(map['cloudAnchorsEnabled'], false),
      activeMemoryCount: _int(map['activeMemoryCount'], 0),
      sceneChangeCount: _int(map['sceneChangeCount'], 0),
      hasNativeSceneFailure: _bool(map['hasNativeSceneFailure'], false),
      hasCloudAnchorFailures: _bool(map['hasCloudAnchorFailures'], false),
      unsupportedSessionFeatureKeys: _stringList(
        map['unsupportedSessionFeatureKeys'],
      ),
      nativeSceneFailureMessage: _nullableString(
        map['nativeSceneFailureMessage'],
      ),
      sessionReadiness: _readiness(map['sessionReadiness']),
      nativePlacementReadiness: _readiness(map['nativePlacementReadiness']),
      sessionHealthAssessment: _healthAssessment(
        map['sessionHealthAssessment'],
      ),
      captureCapability: _captureCapability(map['captureCapability']),
      extra: <String, Object?>{
        for (final entry in map.entries)
          if (!knownKeys.contains(entry.key.toString()))
            entry.key.toString(): _jsonValue(entry.value),
      },
    );
  }

  static const currentSchemaVersion = 1;
  static final unknownCapturedAt = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  static ARCaptureDiagnostics? tryFromMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    try {
      return ARCaptureDiagnostics.fromMap(value);
    } on Object {
      return null;
    }
  }

  static Map<String, Object?>? tryNormalizeSyncableMap(Object? value) {
    final diagnostics = tryFromMap(value);
    return diagnostics?.toSyncableMap();
  }

  final int schemaVersion;
  final DateTime capturedAt;
  final String source;
  final String? sessionId;
  final DateTime? sessionStartedAt;
  final DateTime? lastSyncedAt;
  final String hudStatusLabel;
  final String detailStatusLabel;
  final String syncStatusLabel;
  final String sessionHealthStatusLabel;
  final String sessionReadinessLabel;
  final String nativePlacementStatusLabel;
  final String cloudAnchorStatusLabel;
  final bool cloudAnchorsEnabled;
  final int activeMemoryCount;
  final int sceneChangeCount;
  final bool hasNativeSceneFailure;
  final bool hasCloudAnchorFailures;
  final List<String> unsupportedSessionFeatureKeys;
  final String? nativeSceneFailureMessage;
  final ARSessionReadiness? sessionReadiness;
  final ARSessionReadiness? nativePlacementReadiness;
  final ARSessionHealthAssessment? sessionHealthAssessment;
  final ARCaptureCapability? captureCapability;
  final Map<String, Object?> extra;

  bool get isCurrentSchema => schemaVersion == currentSchemaVersion;

  bool get hasValidCapturedAt => capturedAt != unknownCapturedAt;

  bool get hasValidSource => source.trim().isNotEmpty;

  bool get isSyncable =>
      isCurrentSchema && hasValidCapturedAt && hasValidSource;

  List<String> get validationIssueLabels => <String>[
        if (!isCurrentSchema) 'Unsupported AR diagnostics schema',
        if (!hasValidCapturedAt) 'Missing AR capture timestamp',
        if (!hasValidSource) 'Missing AR diagnostics source',
      ];

  int get unsupportedSessionFeatureCount =>
      unsupportedSessionFeatureKeys.toSet().length;

  String get summaryLabel {
    final hudStatus = hudStatusLabel.trim();
    if (hudStatus.isEmpty || hudStatus == 'AR pending') {
      return 'AR diagnostics attached';
    }
    return 'AR diagnostics: $hudStatus';
  }

  String? get unsupportedSessionFeatureCountLabel {
    final count = unsupportedSessionFeatureCount;
    if (count <= 0) {
      return null;
    }
    return '$count native ${count == 1 ? 'feature' : 'features'} limited';
  }

  String? get captureCapabilityLabel => captureCapability?.idleStatusLabel;

  String? get captureReadinessGuidanceLabel =>
      captureCapability?.readinessGuidanceLabel;

  List<String> get metadataLabels => List<String>.unmodifiable(
        _uniqueLabels(<String?>[
          summaryLabel,
          captureCapabilityLabel,
          captureReadinessGuidanceLabel,
          sessionReadinessLabel,
          nativePlacementStatusLabel,
          sessionHealthStatusLabel,
          syncStatusLabel,
          unsupportedSessionFeatureCountLabel,
          if (hasNativeSceneFailure) 'Native scene sync issue',
          if (hasCloudAnchorFailures) 'Cloud anchor issue',
          ...validationIssueLabels,
        ]),
      );

  String get cacheKey {
    final sessionPart =
        sessionId == null || sessionId!.isEmpty ? 'sessionless' : sessionId!;
    return '$source:$sessionPart:${capturedAt.toUtc().toIso8601String()}';
  }

  ARCaptureDiagnostics copyWith({
    int? schemaVersion,
    DateTime? capturedAt,
    String? source,
    Object? sessionId = _unset,
    Object? sessionStartedAt = _unset,
    Object? lastSyncedAt = _unset,
    String? hudStatusLabel,
    String? detailStatusLabel,
    String? syncStatusLabel,
    String? sessionHealthStatusLabel,
    String? sessionReadinessLabel,
    String? nativePlacementStatusLabel,
    String? cloudAnchorStatusLabel,
    bool? cloudAnchorsEnabled,
    int? activeMemoryCount,
    int? sceneChangeCount,
    bool? hasNativeSceneFailure,
    bool? hasCloudAnchorFailures,
    Iterable<String>? unsupportedSessionFeatureKeys,
    Object? nativeSceneFailureMessage = _unset,
    Object? sessionReadiness = _unset,
    Object? nativePlacementReadiness = _unset,
    Object? sessionHealthAssessment = _unset,
    Object? captureCapability = _unset,
    Map<String, Object?>? extra,
  }) =>
      ARCaptureDiagnostics(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        capturedAt: capturedAt ?? this.capturedAt,
        source: source ?? this.source,
        sessionId: identical(sessionId, _unset)
            ? this.sessionId
            : sessionId as String?,
        sessionStartedAt: identical(sessionStartedAt, _unset)
            ? this.sessionStartedAt
            : sessionStartedAt as DateTime?,
        lastSyncedAt: identical(lastSyncedAt, _unset)
            ? this.lastSyncedAt
            : lastSyncedAt as DateTime?,
        hudStatusLabel: hudStatusLabel ?? this.hudStatusLabel,
        detailStatusLabel: detailStatusLabel ?? this.detailStatusLabel,
        syncStatusLabel: syncStatusLabel ?? this.syncStatusLabel,
        sessionHealthStatusLabel:
            sessionHealthStatusLabel ?? this.sessionHealthStatusLabel,
        sessionReadinessLabel:
            sessionReadinessLabel ?? this.sessionReadinessLabel,
        nativePlacementStatusLabel:
            nativePlacementStatusLabel ?? this.nativePlacementStatusLabel,
        cloudAnchorStatusLabel:
            cloudAnchorStatusLabel ?? this.cloudAnchorStatusLabel,
        cloudAnchorsEnabled: cloudAnchorsEnabled ?? this.cloudAnchorsEnabled,
        activeMemoryCount: activeMemoryCount ?? this.activeMemoryCount,
        sceneChangeCount: sceneChangeCount ?? this.sceneChangeCount,
        hasNativeSceneFailure:
            hasNativeSceneFailure ?? this.hasNativeSceneFailure,
        hasCloudAnchorFailures:
            hasCloudAnchorFailures ?? this.hasCloudAnchorFailures,
        unsupportedSessionFeatureKeys: unsupportedSessionFeatureKeys == null
            ? this.unsupportedSessionFeatureKeys
            : List<String>.unmodifiable(unsupportedSessionFeatureKeys),
        nativeSceneFailureMessage: identical(nativeSceneFailureMessage, _unset)
            ? this.nativeSceneFailureMessage
            : nativeSceneFailureMessage as String?,
        sessionReadiness: identical(sessionReadiness, _unset)
            ? this.sessionReadiness
            : sessionReadiness as ARSessionReadiness?,
        nativePlacementReadiness: identical(nativePlacementReadiness, _unset)
            ? this.nativePlacementReadiness
            : nativePlacementReadiness as ARSessionReadiness?,
        sessionHealthAssessment: identical(sessionHealthAssessment, _unset)
            ? this.sessionHealthAssessment
            : sessionHealthAssessment as ARSessionHealthAssessment?,
        captureCapability: identical(captureCapability, _unset)
            ? this.captureCapability
            : captureCapability as ARCaptureCapability?,
        extra: extra ?? this.extra,
      );

  Map<String, Object?> toMap() {
    final sortedFeatureKeys = unsupportedSessionFeatureKeys.toList()..sort();
    return <String, Object?>{
      ..._jsonMap(extra),
      'schemaVersion': schemaVersion,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      'source': source,
      'sessionId': sessionId,
      'sessionStartedAt': sessionStartedAt?.toUtc().toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
      'hudStatusLabel': hudStatusLabel,
      'detailStatusLabel': detailStatusLabel,
      'syncStatusLabel': syncStatusLabel,
      'sessionHealthStatusLabel': sessionHealthStatusLabel,
      'sessionReadinessLabel': sessionReadinessLabel,
      'nativePlacementStatusLabel': nativePlacementStatusLabel,
      'cloudAnchorStatusLabel': cloudAnchorStatusLabel,
      'cloudAnchorsEnabled': cloudAnchorsEnabled,
      'activeMemoryCount': activeMemoryCount,
      'sceneChangeCount': sceneChangeCount,
      'hasNativeSceneFailure': hasNativeSceneFailure,
      'hasCloudAnchorFailures': hasCloudAnchorFailures,
      'unsupportedSessionFeatureKeys': sortedFeatureKeys,
      'nativeSceneFailureMessage': nativeSceneFailureMessage,
      'sessionReadiness': sessionReadiness?.toMap(),
      'nativePlacementReadiness': nativePlacementReadiness?.toMap(),
      'sessionHealthAssessment': sessionHealthAssessment?.toMap(),
      'captureCapability': captureCapability?.toMap(),
    };
  }

  Map<String, Object?>? toSyncableMap() {
    if (!isSyncable) {
      return null;
    }
    return Map<String, Object?>.unmodifiable(toMap());
  }

  @override
  bool operator ==(Object other) =>
      other is ARCaptureDiagnostics &&
      schemaVersion == other.schemaVersion &&
      capturedAt == other.capturedAt &&
      source == other.source &&
      sessionId == other.sessionId &&
      sessionStartedAt == other.sessionStartedAt &&
      lastSyncedAt == other.lastSyncedAt &&
      hudStatusLabel == other.hudStatusLabel &&
      detailStatusLabel == other.detailStatusLabel &&
      syncStatusLabel == other.syncStatusLabel &&
      sessionHealthStatusLabel == other.sessionHealthStatusLabel &&
      sessionReadinessLabel == other.sessionReadinessLabel &&
      nativePlacementStatusLabel == other.nativePlacementStatusLabel &&
      cloudAnchorStatusLabel == other.cloudAnchorStatusLabel &&
      cloudAnchorsEnabled == other.cloudAnchorsEnabled &&
      activeMemoryCount == other.activeMemoryCount &&
      sceneChangeCount == other.sceneChangeCount &&
      hasNativeSceneFailure == other.hasNativeSceneFailure &&
      hasCloudAnchorFailures == other.hasCloudAnchorFailures &&
      _featureKeyEquality.equals(
        unsupportedSessionFeatureKeys.toSet(),
        other.unsupportedSessionFeatureKeys.toSet(),
      ) &&
      nativeSceneFailureMessage == other.nativeSceneFailureMessage &&
      sessionReadiness == other.sessionReadiness &&
      nativePlacementReadiness == other.nativePlacementReadiness &&
      sessionHealthAssessment == other.sessionHealthAssessment &&
      captureCapability == other.captureCapability &&
      _deepEquality.equals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll([
        schemaVersion,
        capturedAt,
        source,
        sessionId,
        sessionStartedAt,
        lastSyncedAt,
        hudStatusLabel,
        detailStatusLabel,
        syncStatusLabel,
        sessionHealthStatusLabel,
        sessionReadinessLabel,
        nativePlacementStatusLabel,
        cloudAnchorStatusLabel,
        cloudAnchorsEnabled,
        activeMemoryCount,
        sceneChangeCount,
        hasNativeSceneFailure,
        hasCloudAnchorFailures,
        _featureKeyEquality.hash(unsupportedSessionFeatureKeys.toSet()),
        nativeSceneFailureMessage,
        sessionReadiness,
        nativePlacementReadiness,
        sessionHealthAssessment,
        captureCapability,
        _deepEquality.hash(extra),
      ]);
}

class ARCaptureDiagnosticsMemoryCache {
  ARCaptureDiagnosticsMemoryCache({this.capacity = 32})
      : assert(capacity > 0, 'capacity must be positive');

  factory ARCaptureDiagnosticsMemoryCache.fromMap(
    Map<dynamic, dynamic> map, {
    int? capacity,
  }) {
    final cache = ARCaptureDiagnosticsMemoryCache(
      capacity: capacity ?? _positiveInt(map['capacity'], 32),
    );
    final entries = map['entries'];
    if (entries is Iterable) {
      cache.putAll(entries.map(ARCaptureDiagnostics.tryFromMap));
    }
    return cache;
  }

  factory ARCaptureDiagnosticsMemoryCache.fromValues(
    Iterable<ARCaptureDiagnostics> values, {
    int capacity = 32,
  }) {
    final cache = ARCaptureDiagnosticsMemoryCache(capacity: capacity);
    cache.putAll(values);
    return cache;
  }

  final int capacity;
  final LinkedHashMap<String, ARCaptureDiagnostics> _entries =
      LinkedHashMap<String, ARCaptureDiagnostics>();

  int get length => _entries.length;

  bool get isEmpty => _entries.isEmpty;

  bool get isNotEmpty => _entries.isNotEmpty;

  List<ARCaptureDiagnostics> get values =>
      List<ARCaptureDiagnostics>.unmodifiable(_entries.values);

  List<ARCaptureDiagnostics> get syncableValues =>
      List<ARCaptureDiagnostics>.unmodifiable(
        _entries.values.where((diagnostics) => diagnostics.isSyncable),
      );

  ARCaptureDiagnostics? get latest =>
      _entries.isEmpty ? null : _entries.values.last;

  ARCaptureDiagnostics? operator [](String key) => _entries[key];

  void put(ARCaptureDiagnostics diagnostics) {
    final key = diagnostics.cacheKey;
    _entries.remove(key);
    _entries[key] = diagnostics;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void putAll(Iterable<ARCaptureDiagnostics?> diagnostics) {
    for (final entry in diagnostics) {
      if (entry != null) {
        put(entry);
      }
    }
  }

  bool containsKey(String key) => _entries.containsKey(key);

  ARCaptureDiagnostics? latestForSession(String? sessionId) =>
      _latestWhere((diagnostics) => diagnostics.sessionId == sessionId);

  ARCaptureDiagnostics? latestForSource(String source) =>
      _latestWhere((diagnostics) => diagnostics.source == source);

  Map<String, Object?> toMap({bool syncableOnly = false}) => <String, Object?>{
        'capacity': capacity,
        'entries': <Map<String, Object?>>[
          for (final diagnostics in _entries.values)
            if (!syncableOnly || diagnostics.isSyncable) diagnostics.toMap(),
        ],
      };

  Map<String, Object?> toSyncableMap() => toMap(syncableOnly: true);

  ARCaptureDiagnostics? remove(String key) => _entries.remove(key);

  int removeWhere(bool Function(ARCaptureDiagnostics diagnostics) test) {
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
      (diagnostics) => diagnostics.capturedAt.toUtc().isBefore(utcCutoff),
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

  ARCaptureDiagnostics? _latestWhere(
    bool Function(ARCaptureDiagnostics diagnostics) test,
  ) {
    for (final diagnostics in _entries.values.toList().reversed) {
      if (test(diagnostics)) {
        return diagnostics;
      }
    }
    return null;
  }
}

String _string(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value, int fallback) => value is int ? value : fallback;

int _positiveInt(Object? value, int fallback) =>
    value is int && value > 0 ? value : fallback;

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

DateTime? _dateTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) {
    return const <String>[];
  }
  final strings = value.whereType<String>().toList()..sort();
  return List<String>.unmodifiable(strings);
}

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

ARSessionReadiness? _readiness(Object? value) {
  if (value is! Map) {
    return null;
  }
  return ARSessionReadiness.fromMap(Map<dynamic, dynamic>.from(value));
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

ARCaptureCapability? _captureCapability(Object? value) {
  if (value is! Map) {
    return null;
  }
  try {
    return ARCaptureCapability.fromMap(
      Map<dynamic, dynamic>.from(value),
    );
  } on Object {
    return null;
  }
}

Map<String, Object?> _jsonMap(Map<dynamic, dynamic> value) => <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _jsonValue(entry.value),
    };

Object? _jsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
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
