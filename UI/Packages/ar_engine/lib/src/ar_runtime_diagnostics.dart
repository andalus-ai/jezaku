import 'package:collection/collection.dart';

import 'ar_diagnostics_timeline.dart';
import 'ar_session_health_assessment.dart';

const _runtimeDiagnosticsEquality = DeepCollectionEquality();

/// Backend runtime diagnostics exposed by the active AR renderer.
///
/// The payload intentionally keeps backend-specific keys in [values] so web,
/// Android, iOS, macOS, and desktop renderers can publish new counters without
/// forcing an API migration. Common web and native renderer keys have
/// convenience getters.
class ARRuntimeDiagnostics {
  ARRuntimeDiagnostics({
    this.source = 'unknown',
    Map<String, Object?> values = const <String, Object?>{},
  }) : values = Map<String, Object?>.unmodifiable(
          _normaliseStringMap(values, dropSource: true),
        );

  const ARRuntimeDiagnostics.empty({this.source = 'none'})
      : values = const <String, Object?>{};

  factory ARRuntimeDiagnostics.fromMap(
    Object? value, {
    String source = 'platform',
  }) {
    if (value is! Map) {
      return ARRuntimeDiagnostics.empty(source: source);
    }
    final resolvedSource = _stringValue(value['source']) ?? source;
    final nestedValues = value['values'];
    final rawValues = nestedValues is Map ? nestedValues : value;
    return ARRuntimeDiagnostics(
      source: resolvedSource,
      values: _normaliseStringMap(rawValues, dropSource: true),
    );
  }

  /// Stable backend identifier, such as `web` or `methodChannel`.
  final String source;

  /// JSON-friendly backend diagnostics values.
  final Map<String, Object?> values;

  /// Returns `true` when the backend did not publish any diagnostics values.
  bool get isEmpty => values.isEmpty;

  /// Returns `true` when at least one diagnostic value is present.
  bool get isNotEmpty => values.isNotEmpty;

  /// Whether the backend considers the AR session active.
  bool get sessionActive => flag('sessionActive');

  /// Native backend identifier, such as `arcore`, `arkit`, or `desktop_camera`.
  String? get backend => stringValue('backend');

  /// Whether the native backend has a running AR session loop.
  bool get sessionRunning => flag('sessionRunning');

  /// Whether session start has been requested but may still be waiting for a
  /// platform view or permission-gated native session.
  bool get startRequested => flag('startRequested');

  /// Whether the platform backend has allocated a native AR session object.
  bool get hasNativeSession => flag('hasNativeSession');

  /// Whether at least one camera frame has reached the backend.
  bool get hasCameraFrame => flag('hasCameraFrame');

  int get anchorCount => counter('anchorCount');

  int get trackedAnchorCount => counter('trackedAnchorCount');

  int get nodeCount => counter('nodeCount');

  int get modelNodeCount => counter('modelNodeCount');

  int get planeCount => counter('planeCount');

  int get trackedPlaneCount => counter('trackedPlaneCount');

  int get imageAnchorCount => counter('imageAnchorCount');

  int get trackedImageAnchorCount => counter('trackedImageAnchorCount');

  int get viewportWidth => counter('viewportWidth');

  int get viewportHeight => counter('viewportHeight');

  bool get depthEnabled => flag('depthEnabled');

  bool get cloudAnchorsEnabled => flag('cloudAnchorsEnabled');

  bool get geospatialEnabled => flag('geospatialEnabled');

  bool get bodyTrackingEnabled => flag('bodyTrackingEnabled');

  /// Whether Three.js was available to the web renderer.
  bool get threeAvailable => flag('threeAvailable');

  /// Whether the web GLTF/GLB loader was available.
  bool get gltfLoaderAvailable => flag('gltfLoaderAvailable');

  /// Whether the web OBJ loader was available.
  bool get objLoaderAvailable => flag('objLoaderAvailable');

  /// Whether the web texture loader was available.
  bool get textureLoaderAvailable => flag('textureLoaderAvailable');

  int get nodesAdded => counter('nodesAdded');

  int get nodesUpdated => counter('nodesUpdated');

  int get nodesRemoved => counter('nodesRemoved');

  int get nodesRendered => counter('nodesRendered');

  int get nodesSkippedMissingThree => counter('nodesSkippedMissingThree');

  int get modelLoadStarted => counter('modelLoadStarted');

  int get modelLoadSucceeded => counter('modelLoadSucceeded');

  int get modelLoadFailed => counter('modelLoadFailed');

  int get modelFallbackUsed => counter('modelFallbackUsed');

  int get modelCacheHits => counter('modelCacheHits');

  int get modelCacheSize => counter('modelCacheSize');

  int get modelStaleCallbacksIgnored => counter('modelStaleCallbacksIgnored');

  int get textureLoadStarted => counter('textureLoadStarted');

  int get textureLoadSucceeded => counter('textureLoadSucceeded');

  int get textureLoadFailed => counter('textureLoadFailed');

  int get textureCacheHits => counter('textureCacheHits');

  int get textureCacheSize => counter('textureCacheSize');

  String? get lastNodeStatus => stringValue('lastNodeStatus');

  String? get lastModelNodeId => stringValue('lastModelNodeId');

  String? get lastModelUrl => stringValue('lastModelUrl');

  String? get lastModelStatus => stringValue('lastModelStatus');

  String? get lastModelError => stringValue('lastModelError');

  DateTime? get lastUpdatedAt => timestamp('lastUpdatedAt');

  /// Returns the raw diagnostic value for [key].
  Object? operator [](String key) => values[key];

  /// Returns a diagnostic counter as an integer, defaulting to zero.
  int counter(String key) => _intValue(values[key]);

  /// Returns a diagnostic flag as a boolean, defaulting to false.
  bool flag(String key) => _boolValue(values[key]);

  /// Returns a diagnostic value as a string when possible.
  String? stringValue(String key) => _stringValue(values[key]);

  /// Returns a diagnostic timestamp when the value is a [DateTime] or ISO-8601.
  DateTime? timestamp(String key) {
    final value = values[key];
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'source': source,
        ...values,
      };

  /// Converts notable runtime states into diagnostics timeline events.
  ///
  /// This keeps renderer problems, such as missing web renderers or failed model
  /// loads, visible in the same report stream as session health and captures.
  List<ARSessionLifecycleEvent> toSessionLifecycleEvents({
    DateTime? occurredAt,
    String? sessionId,
  }) {
    if (isEmpty) return const <ARSessionLifecycleEvent>[];

    final eventAt = (occurredAt ?? lastUpdatedAt ?? DateTime.now()).toUtc();
    final eventSource = source == 'unknown' || source.isEmpty
        ? 'runtime_diagnostics'
        : '${source}_runtime';
    final events = <ARSessionLifecycleEvent>[];
    final attemptedNodeRenders = nodesAdded + nodesUpdated;
    final publishesNativeSessionState = backend != null ||
        values.containsKey('hasNativeSession') ||
        values.containsKey('hasCameraFrame');

    if (publishesNativeSessionState && sessionActive && !hasNativeSession) {
      events.add(
        ARSessionLifecycleEvent.create(
          kind: ARSessionLifecycleEventKind.custom,
          occurredAt: eventAt,
          source: eventSource,
          sessionId: sessionId,
          summaryLabel: 'AR native session unavailable',
          detailLabel:
              'The backend reports an active AR session without a native session object.',
          severity: ARSessionHealthSeverity.blocked,
          code: 'runtime_native_session_unavailable',
          metadata: _runtimeLifecycleMetadata(),
        ),
      );
    }

    if (publishesNativeSessionState && sessionRunning && !hasCameraFrame) {
      events.add(
        ARSessionLifecycleEvent.create(
          kind: ARSessionLifecycleEventKind.custom,
          occurredAt: eventAt,
          source: eventSource,
          sessionId: sessionId,
          summaryLabel: 'AR camera frame unavailable',
          detailLabel:
              'The backend session is running but has not received a camera frame.',
          severity: ARSessionHealthSeverity.warning,
          code: 'runtime_camera_frame_unavailable',
          metadata: _runtimeLifecycleMetadata(),
        ),
      );
    }

    if (!threeAvailable &&
        (attemptedNodeRenders > 0 || nodesSkippedMissingThree > 0)) {
      events.add(
        ARSessionLifecycleEvent.create(
          kind: ARSessionLifecycleEventKind.custom,
          occurredAt: eventAt,
          source: eventSource,
          sessionId: sessionId,
          summaryLabel: 'AR renderer unavailable',
          detailLabel: nodesSkippedMissingThree > 0
              ? '$nodesSkippedMissingThree node render skipped because Three.js was unavailable.'
              : 'Three.js was unavailable when AR nodes were requested.',
          severity: ARSessionHealthSeverity.blocked,
          code: 'runtime_renderer_unavailable',
          metadata: _runtimeLifecycleMetadata(),
        ),
      );
    }

    if (modelLoadFailed > 0) {
      events.add(
        ARSessionLifecycleEvent.create(
          kind: ARSessionLifecycleEventKind.custom,
          occurredAt: eventAt,
          source: eventSource,
          sessionId: sessionId,
          summaryLabel: 'AR model load failed',
          detailLabel: lastModelError ??
              '$modelLoadFailed model load failed; primitive fallback remains visible.',
          severity: ARSessionHealthSeverity.warning,
          code: 'runtime_model_load_failed',
          metadata: _runtimeLifecycleMetadata(),
        ),
      );
    } else if (modelFallbackUsed > 0) {
      events.add(
        ARSessionLifecycleEvent.create(
          kind: ARSessionLifecycleEventKind.custom,
          occurredAt: eventAt,
          source: eventSource,
          sessionId: sessionId,
          summaryLabel: 'AR model fallback in use',
          detailLabel: lastModelStatus == null
              ? '$modelFallbackUsed model fallback used.'
              : '$modelFallbackUsed model fallback used; latest status: $lastModelStatus.',
          severity: ARSessionHealthSeverity.warning,
          code: 'runtime_model_fallback_used',
          metadata: _runtimeLifecycleMetadata(),
        ),
      );
    }

    if (textureLoadFailed > 0) {
      events.add(
        ARSessionLifecycleEvent.create(
          kind: ARSessionLifecycleEventKind.custom,
          occurredAt: eventAt,
          source: eventSource,
          sessionId: sessionId,
          summaryLabel: 'AR texture load failed',
          detailLabel:
              '$textureLoadFailed texture load failed; material fallback remains visible.',
          severity: ARSessionHealthSeverity.warning,
          code: 'runtime_texture_load_failed',
          metadata: _runtimeLifecycleMetadata(),
        ),
      );
    }

    if (modelStaleCallbacksIgnored > 0) {
      events.add(
        ARSessionLifecycleEvent.create(
          kind: ARSessionLifecycleEventKind.custom,
          occurredAt: eventAt,
          source: eventSource,
          sessionId: sessionId,
          summaryLabel: 'Stale AR model callback ignored',
          detailLabel:
              '$modelStaleCallbacksIgnored stale model loader callback ignored safely.',
          severity: ARSessionHealthSeverity.good,
          code: 'runtime_stale_model_callback_ignored',
          metadata: _runtimeLifecycleMetadata(),
        ),
      );
    }

    return List<ARSessionLifecycleEvent>.unmodifiable(events);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARRuntimeDiagnostics &&
          source == other.source &&
          _runtimeDiagnosticsEquality.equals(values, other.values);

  @override
  int get hashCode => Object.hash(
        source,
        _runtimeDiagnosticsEquality.hash(values),
      );

  @override
  String toString() => 'ARRuntimeDiagnostics(${toMap()})';

  Map<String, Object?> _runtimeLifecycleMetadata() => <String, Object?>{
        'runtimeDiagnosticsSource': source,
        'backend': backend,
        'sessionActive': sessionActive,
        'sessionRunning': sessionRunning,
        'startRequested': startRequested,
        'hasNativeSession': hasNativeSession,
        'hasCameraFrame': hasCameraFrame,
        'anchorCount': anchorCount,
        'trackedAnchorCount': trackedAnchorCount,
        'nodeCount': nodeCount,
        'modelNodeCount': modelNodeCount,
        'planeCount': planeCount,
        'trackedPlaneCount': trackedPlaneCount,
        'imageAnchorCount': imageAnchorCount,
        'trackedImageAnchorCount': trackedImageAnchorCount,
        'viewportWidth': viewportWidth,
        'viewportHeight': viewportHeight,
        'depthEnabled': depthEnabled,
        'cloudAnchorsEnabled': cloudAnchorsEnabled,
        'geospatialEnabled': geospatialEnabled,
        'bodyTrackingEnabled': bodyTrackingEnabled,
        'threeAvailable': threeAvailable,
        'gltfLoaderAvailable': gltfLoaderAvailable,
        'objLoaderAvailable': objLoaderAvailable,
        'textureLoaderAvailable': textureLoaderAvailable,
        'nodesAdded': nodesAdded,
        'nodesUpdated': nodesUpdated,
        'nodesRemoved': nodesRemoved,
        'nodesRendered': nodesRendered,
        'nodesSkippedMissingThree': nodesSkippedMissingThree,
        'modelLoadStarted': modelLoadStarted,
        'modelLoadSucceeded': modelLoadSucceeded,
        'modelLoadFailed': modelLoadFailed,
        'modelFallbackUsed': modelFallbackUsed,
        'modelCacheHits': modelCacheHits,
        'modelCacheSize': modelCacheSize,
        'modelStaleCallbacksIgnored': modelStaleCallbacksIgnored,
        'textureLoadStarted': textureLoadStarted,
        'textureLoadSucceeded': textureLoadSucceeded,
        'textureLoadFailed': textureLoadFailed,
        'textureCacheHits': textureCacheHits,
        'textureCacheSize': textureCacheSize,
        'lastNodeStatus': lastNodeStatus,
        'lastModelNodeId': lastModelNodeId,
        'lastModelUrl': lastModelUrl,
        'lastModelStatus': lastModelStatus,
        'lastModelError': lastModelError,
        'lastUpdatedAt': lastUpdatedAt?.toUtc().toIso8601String(),
      };
}

Map<String, Object?> _normaliseStringMap(
  Map<dynamic, dynamic> map, {
  bool dropSource = false,
}) {
  final values = <String, Object?>{};
  for (final entry in map.entries) {
    final key = entry.key;
    if (key is! String || key.isEmpty) continue;
    if (dropSource && key == 'source') continue;
    values[key] = _normaliseDiagnosticValue(entry.value);
  }
  return values;
}

Object? _normaliseDiagnosticValue(Object? value) {
  if (value is Map) return _normaliseStringMap(value);
  if (value is Iterable && value is! String) {
    return value.map(_normaliseDiagnosticValue).toList(growable: false);
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  return value;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalised = value.trim().toLowerCase();
    return normalised == 'true' || normalised == '1' || normalised == 'yes';
  }
  return false;
}

String? _stringValue(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}
