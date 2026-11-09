import 'dart:async';
import 'dart:convert';

import 'package:ar_engine/ar_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _arCaptureDiagnosticsCacheKey = 'jejaku.ar_capture_diagnostics_cache';
const _defaultARCaptureDiagnosticsCacheCapacity = 8;
const _defaultARCaptureDiagnosticsCacheMaxAge = Duration(days: 14);

final arCaptureDiagnosticsCacheStoreProvider =
    Provider<ARCaptureDiagnosticsCacheStore>((ref) {
  return InMemoryARCaptureDiagnosticsCacheStore();
});

final arCaptureDiagnosticsCacheProvider =
    Provider<ARCaptureDiagnosticsMemoryCache>((ref) {
  return ref.watch(arCaptureDiagnosticsCacheStoreProvider).loadCache();
});

abstract class ARCaptureDiagnosticsCacheStore {
  ARCaptureDiagnosticsMemoryCache loadCache();

  void saveCache(ARCaptureDiagnosticsMemoryCache cache);

  void clearCache();
}

class InMemoryARCaptureDiagnosticsCacheStore
    implements ARCaptureDiagnosticsCacheStore {
  InMemoryARCaptureDiagnosticsCacheStore({
    this.capacity = _defaultARCaptureDiagnosticsCacheCapacity,
    this.maxAge = _defaultARCaptureDiagnosticsCacheMaxAge,
    DateTime Function()? now,
  }) : _now = now ?? _utcNow;

  final int capacity;
  final Duration? maxAge;
  final DateTime Function() _now;
  Map<String, Object?>? _snapshot;

  @override
  ARCaptureDiagnosticsMemoryCache loadCache() {
    final cache = _cacheFromSnapshot(
      _snapshot,
      capacity: capacity,
      maxAge: maxAge,
      now: _now(),
    );
    _snapshot = cache.isEmpty ? null : cache.toSyncableMap();
    return cache;
  }

  @override
  void saveCache(ARCaptureDiagnosticsMemoryCache cache) {
    final prunedCache = _cacheFromSnapshot(
      cache.toSyncableMap(),
      capacity: capacity,
      maxAge: maxAge,
      now: _now(),
    );
    _snapshot = prunedCache.isEmpty ? null : prunedCache.toSyncableMap();
  }

  @override
  void clearCache() {
    _snapshot = null;
  }
}

class SharedPreferencesARCaptureDiagnosticsCacheStore
    implements ARCaptureDiagnosticsCacheStore {
  SharedPreferencesARCaptureDiagnosticsCacheStore({
    required SharedPreferences preferences,
    String key = _arCaptureDiagnosticsCacheKey,
    this.capacity = _defaultARCaptureDiagnosticsCacheCapacity,
    this.maxAge = _defaultARCaptureDiagnosticsCacheMaxAge,
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
  ARCaptureDiagnosticsMemoryCache loadCache() {
    final encodedCache = _preferences.getString(_key);
    if (encodedCache == null || encodedCache.trim().isEmpty) {
      return ARCaptureDiagnosticsMemoryCache(capacity: capacity);
    }

    try {
      final decodedCache = jsonDecode(encodedCache);
      if (decodedCache is! Map) {
        clearCache();
        return ARCaptureDiagnosticsMemoryCache(capacity: capacity);
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
      return ARCaptureDiagnosticsMemoryCache(capacity: capacity);
    }
  }

  @override
  void saveCache(ARCaptureDiagnosticsMemoryCache cache) {
    final prunedCache = _cacheFromSnapshot(
      cache.toSyncableMap(),
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
  void clearCache() {
    unawaited(_preferences.remove(_key));
  }

  void _savePrunedCache(ARCaptureDiagnosticsMemoryCache cache) {
    unawaited(
      _preferences.setString(
        _key,
        jsonEncode(cache.toSyncableMap()),
      ),
    );
  }
}

persistentARCaptureDiagnosticsCacheStoreOverride({
  required SharedPreferences preferences,
}) {
  return arCaptureDiagnosticsCacheStoreProvider.overrideWith((ref) {
    return SharedPreferencesARCaptureDiagnosticsCacheStore(
      preferences: preferences,
    );
  });
}

ARCaptureDiagnosticsMemoryCache _cacheFromSnapshot(
  Object? snapshot, {
  required int capacity,
  required Duration? maxAge,
  required DateTime now,
}) {
  if (snapshot is! Map) {
    return ARCaptureDiagnosticsMemoryCache(capacity: capacity);
  }
  final restored = ARCaptureDiagnosticsMemoryCache.fromMap(
    Map<dynamic, dynamic>.from(snapshot),
    capacity: capacity,
  );
  final cache = ARCaptureDiagnosticsMemoryCache.fromValues(
    restored.syncableValues,
    capacity: capacity,
  );
  if (maxAge != null) {
    cache.pruneStale(now: now, maxAge: maxAge);
  }
  return cache;
}

DateTime _utcNow() => DateTime.now().toUtc();
