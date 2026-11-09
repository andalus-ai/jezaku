import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle.dart';
import 'package:jejaku/features/ar_viewer/models/ar_scene_diagnostics_export_bundle_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _arSceneDiagnosticsExportBundleCacheKey =
    'jejaku.ar_scene_diagnostics_export_bundle_cache';
const _defaultARSceneDiagnosticsExportBundleCacheCapacity = 8;
const _defaultARSceneDiagnosticsExportBundleCacheMaxAge = Duration(days: 14);

final arSceneDiagnosticsExportBundleCacheStoreProvider =
    Provider<ARSceneDiagnosticsExportBundleCacheStore>((ref) {
  return InMemoryARSceneDiagnosticsExportBundleCacheStore();
});

final arSceneDiagnosticsExportBundleCacheProvider =
    Provider<ARSceneDiagnosticsExportBundleCache>((ref) {
  return ref
      .watch(arSceneDiagnosticsExportBundleCacheStoreProvider)
      .loadCache();
});

abstract class ARSceneDiagnosticsExportBundleCacheStore {
  ARSceneDiagnosticsExportBundleCache loadCache();

  void saveCache(ARSceneDiagnosticsExportBundleCache cache);

  void saveBundle(ARSceneDiagnosticsExportBundle bundle);

  void clearCache();
}

class InMemoryARSceneDiagnosticsExportBundleCacheStore
    implements ARSceneDiagnosticsExportBundleCacheStore {
  InMemoryARSceneDiagnosticsExportBundleCacheStore({
    this.capacity = _defaultARSceneDiagnosticsExportBundleCacheCapacity,
    this.maxAge = _defaultARSceneDiagnosticsExportBundleCacheMaxAge,
    DateTime Function()? now,
  }) : _now = now ?? _utcNow;

  final int capacity;
  final Duration? maxAge;
  final DateTime Function() _now;
  Map<String, Object?>? _snapshot;

  @override
  ARSceneDiagnosticsExportBundleCache loadCache() {
    final cache = _cacheFromSnapshot(
      _snapshot,
      capacity: capacity,
      maxAge: maxAge,
      now: _now(),
    );
    _snapshot = cache.isEmpty ? null : cache.toMap();
    return cache;
  }

  @override
  void saveCache(ARSceneDiagnosticsExportBundleCache cache) {
    final prunedCache = _cacheFromSnapshot(
      cache.toMap(),
      capacity: capacity,
      maxAge: maxAge,
      now: _now(),
    );
    _snapshot = prunedCache.isEmpty ? null : prunedCache.toMap();
  }

  @override
  void saveBundle(ARSceneDiagnosticsExportBundle bundle) {
    final cache = loadCache();
    cache.put(bundle);
    saveCache(cache);
  }

  @override
  void clearCache() {
    _snapshot = null;
  }
}

class SharedPreferencesARSceneDiagnosticsExportBundleCacheStore
    implements ARSceneDiagnosticsExportBundleCacheStore {
  SharedPreferencesARSceneDiagnosticsExportBundleCacheStore({
    required SharedPreferences preferences,
    String key = _arSceneDiagnosticsExportBundleCacheKey,
    this.capacity = _defaultARSceneDiagnosticsExportBundleCacheCapacity,
    this.maxAge = _defaultARSceneDiagnosticsExportBundleCacheMaxAge,
    DateTime Function()? now,
  })  : _now = now ?? _utcNow,
        _preferences = preferences,
        _key = key;

  final SharedPreferences _preferences;
  final String _key;
  final int capacity;
  final Duration? maxAge;
  final DateTime Function() _now;

  @override
  ARSceneDiagnosticsExportBundleCache loadCache() {
    final encodedCache = _preferences.getString(_key);
    if (encodedCache == null || encodedCache.trim().isEmpty) {
      return ARSceneDiagnosticsExportBundleCache(capacity: capacity);
    }

    try {
      final decodedCache = jsonDecode(encodedCache);
      if (decodedCache is! Map) {
        clearCache();
        return ARSceneDiagnosticsExportBundleCache(capacity: capacity);
      }
      final cache = _cacheFromSnapshot(
        decodedCache,
        capacity: capacity,
        maxAge: maxAge,
        now: _now(),
      );
      if (cache.isEmpty) {
        clearCache();
      } else {
        _savePrunedCache(cache);
      }
      return cache;
    } on Object {
      clearCache();
      return ARSceneDiagnosticsExportBundleCache(capacity: capacity);
    }
  }

  @override
  void saveCache(ARSceneDiagnosticsExportBundleCache cache) {
    final prunedCache = _cacheFromSnapshot(
      cache.toMap(),
      capacity: capacity,
      maxAge: maxAge,
      now: _now(),
    );
    if (prunedCache.isEmpty) {
      clearCache();
      return;
    }
    _savePrunedCache(prunedCache);
  }

  @override
  void saveBundle(ARSceneDiagnosticsExportBundle bundle) {
    final cache = loadCache();
    cache.put(bundle);
    saveCache(cache);
  }

  @override
  void clearCache() {
    unawaited(_preferences.remove(_key));
  }

  void _savePrunedCache(ARSceneDiagnosticsExportBundleCache cache) {
    unawaited(
      _preferences.setString(
        _key,
        jsonEncode(cache.toMap()),
      ),
    );
  }
}

persistentARSceneDiagnosticsExportBundleCacheStoreOverride({
  required SharedPreferences preferences,
}) {
  return arSceneDiagnosticsExportBundleCacheStoreProvider.overrideWith((ref) {
    return SharedPreferencesARSceneDiagnosticsExportBundleCacheStore(
      preferences: preferences,
    );
  });
}

ARSceneDiagnosticsExportBundleCache _cacheFromSnapshot(
  Object? snapshot, {
  required int capacity,
  required Duration? maxAge,
  required DateTime now,
}) {
  if (snapshot is! Map) {
    return ARSceneDiagnosticsExportBundleCache(capacity: capacity);
  }
  final cache = ARSceneDiagnosticsExportBundleCache.fromMap(
    Map<dynamic, dynamic>.from(snapshot),
    capacity: capacity,
  );
  if (maxAge != null) {
    cache.pruneStale(now: now, maxAge: maxAge);
  }
  return cache;
}

DateTime _utcNow() => DateTime.now().toUtc();
