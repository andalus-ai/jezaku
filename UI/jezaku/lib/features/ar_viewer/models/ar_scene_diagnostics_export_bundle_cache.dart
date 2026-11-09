import 'dart:collection';

import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';

class ARSceneDiagnosticsExportBundleCache {
  ARSceneDiagnosticsExportBundleCache({
    this.capacity = defaultCapacity,
  }) {
    if (capacity < 1) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be positive');
    }
  }

  factory ARSceneDiagnosticsExportBundleCache.fromMap(
    Map<dynamic, dynamic> map, {
    int? capacity,
  }) {
    final cache = ARSceneDiagnosticsExportBundleCache(
      capacity: capacity ?? _int(map['capacity'], defaultCapacity),
    );
    final entries = map['entries'];
    if (entries is Iterable) {
      cache.putAll(
        entries.map(ARSceneDiagnosticsExportBundle.tryFromMap),
      );
    }
    return cache;
  }

  factory ARSceneDiagnosticsExportBundleCache.fromValues(
    Iterable<ARSceneDiagnosticsExportBundle> values, {
    int capacity = defaultCapacity,
  }) {
    final cache = ARSceneDiagnosticsExportBundleCache(capacity: capacity);
    cache.putAll(values);
    return cache;
  }

  static const int defaultCapacity = 8;

  final int capacity;
  final LinkedHashMap<String, ARSceneDiagnosticsExportBundle> _entries =
      LinkedHashMap<String, ARSceneDiagnosticsExportBundle>();

  bool get isEmpty => _entries.isEmpty;

  bool get isNotEmpty => _entries.isNotEmpty;

  int get length => _entries.length;

  List<ARSceneDiagnosticsExportBundle> get values =>
      List<ARSceneDiagnosticsExportBundle>.unmodifiable(_entries.values);

  ARSceneDiagnosticsExportBundle? get latest =>
      _entries.isEmpty ? null : _entries.values.last;

  void put(ARSceneDiagnosticsExportBundle bundle) {
    if (!bundle.isPersistable) {
      return;
    }
    final key = _cacheKey(bundle);
    _entries.remove(key);
    _entries[key] = bundle;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void putAll(Iterable<ARSceneDiagnosticsExportBundle?> bundles) {
    for (final bundle in bundles) {
      if (bundle != null) {
        put(bundle);
      }
    }
  }

  ARSceneDiagnosticsExportBundle? latestForSession(String? sessionId) {
    return _latestWhere(
      (bundle) => bundle.sceneDiagnostics.sessionId == sessionId,
    );
  }

  int pruneStale({
    required DateTime now,
    required Duration maxAge,
  }) {
    var removedCount = 0;
    final nowUtc = now.toUtc();
    final staleKeys = <String>[
      for (final entry in _entries.entries)
        if (nowUtc.difference(entry.value.exportedAt.toUtc()) > maxAge)
          entry.key,
    ];
    for (final key in staleKeys) {
      _entries.remove(key);
      removedCount++;
    }
    return removedCount;
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'capacity': capacity,
        'entries': <Map<String, Object?>>[
          for (final bundle in _entries.values) bundle.toMap(),
        ],
      };

  ARSceneDiagnosticsExportBundle? _latestWhere(
    bool Function(ARSceneDiagnosticsExportBundle bundle) test,
  ) {
    for (final bundle in _entries.values.toList().reversed) {
      if (test(bundle)) {
        return bundle;
      }
    }
    return null;
  }
}

String _cacheKey(ARSceneDiagnosticsExportBundle bundle) {
  return <String>[
    bundle.exportedAt.toUtc().toIso8601String(),
    bundle.sceneDiagnostics.sessionId ?? '',
    bundle.latestCaptureDiagnostics?.capturedAt.toUtc().toIso8601String() ?? '',
  ].join('|');
}

int _int(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}
