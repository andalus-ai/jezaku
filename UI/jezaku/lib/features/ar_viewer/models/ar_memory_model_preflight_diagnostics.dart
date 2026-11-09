import 'package:jezaku_ar/jezaku_ar.dart';

class ARMemoryModelPreflightDiagnostics {
  const ARMemoryModelPreflightDiagnostics({
    this.memoryCount = 0,
    this.modelCount = 0,
    this.resolvedCount = 0,
    this.unresolvedCount = 0,
    this.cachedCount = 0,
    this.cacheHitCount = 0,
    this.passthroughCount = 0,
    this.missingSourceCount = 0,
    this.failedCount = 0,
    this.revalidatedCount = 0,
    this.staleCacheFallbackCount = 0,
    this.summaryLabel = 'No 3D models to prepare',
    this.unresolvedMemoryIds = const <String>{},
    this.revalidatedMemoryIds = const <String>{},
    this.staleCacheFallbackMemoryIds = const <String>{},
    this.statusCounts = const <String, int>{},
  });

  factory ARMemoryModelPreflightDiagnostics.fromReport(
    JejakuMemoryModelPreflightReport report,
  ) {
    return ARMemoryModelPreflightDiagnostics(
      memoryCount: report.memoryCount,
      modelCount: report.modelCount,
      resolvedCount: report.resolvedCount,
      unresolvedCount: report.unresolvedCount,
      cachedCount: report.cachedCount,
      cacheHitCount: report.cacheHitCount,
      passthroughCount: report.passthroughCount,
      missingSourceCount: report.missingSourceCount,
      failedCount: report.failedCount,
      revalidatedCount: report.revalidatedCount,
      staleCacheFallbackCount: report.staleCacheFallbackCount,
      summaryLabel: report.summaryLabel,
      unresolvedMemoryIds: report.unresolvedMemoryIds,
      revalidatedMemoryIds: report.revalidatedMemoryIds,
      staleCacheFallbackMemoryIds: report.staleCacheFallbackMemoryIds,
      statusCounts: report.statusCounts,
    );
  }

  factory ARMemoryModelPreflightDiagnostics.fromMap(Object? value) {
    if (value is! Map) {
      return const ARMemoryModelPreflightDiagnostics();
    }
    return ARMemoryModelPreflightDiagnostics(
      memoryCount: _int(value, 'memoryCount'),
      modelCount: _int(value, 'modelCount'),
      resolvedCount: _int(value, 'resolvedCount'),
      unresolvedCount: _int(value, 'unresolvedCount'),
      cachedCount: _int(value, 'cachedCount'),
      cacheHitCount: _int(value, 'cacheHitCount'),
      passthroughCount: _int(value, 'passthroughCount'),
      missingSourceCount: _int(value, 'missingSourceCount'),
      failedCount: _int(value, 'failedCount'),
      revalidatedCount: _int(value, 'revalidatedCount'),
      staleCacheFallbackCount: _int(value, 'staleCacheFallbackCount'),
      summaryLabel: _string(value['summaryLabel']) ?? 'No 3D models to prepare',
      unresolvedMemoryIds: _stringSet(value['unresolvedMemoryIds']),
      revalidatedMemoryIds: _stringSet(value['revalidatedMemoryIds']),
      staleCacheFallbackMemoryIds:
          _stringSet(value['staleCacheFallbackMemoryIds']),
      statusCounts: _intMap(value['statusCounts']),
    );
  }

  final int memoryCount;
  final int modelCount;
  final int resolvedCount;
  final int unresolvedCount;
  final int cachedCount;
  final int cacheHitCount;
  final int passthroughCount;
  final int missingSourceCount;
  final int failedCount;
  final int revalidatedCount;
  final int staleCacheFallbackCount;
  final String summaryLabel;
  final Set<String> unresolvedMemoryIds;
  final Set<String> revalidatedMemoryIds;
  final Set<String> staleCacheFallbackMemoryIds;
  final Map<String, int> statusCounts;

  bool get hasModels => modelCount > 0;

  bool get hasUnresolvedModels => unresolvedCount > 0;

  bool get hasFailures => missingSourceCount > 0 || failedCount > 0;

  bool get hasRevalidatedModels => revalidatedCount > 0;

  bool get hasStaleCacheFallbacks => staleCacheFallbackCount > 0;

  Map<String, Object?> toMap() => <String, Object?>{
        'memoryCount': memoryCount,
        'modelCount': modelCount,
        'resolvedCount': resolvedCount,
        'unresolvedCount': unresolvedCount,
        'cachedCount': cachedCount,
        'cacheHitCount': cacheHitCount,
        'passthroughCount': passthroughCount,
        'missingSourceCount': missingSourceCount,
        'failedCount': failedCount,
        'revalidatedCount': revalidatedCount,
        'staleCacheFallbackCount': staleCacheFallbackCount,
        'summaryLabel': summaryLabel,
        'unresolvedMemoryIds': unresolvedMemoryIds.toList()..sort(),
        'revalidatedMemoryIds': revalidatedMemoryIds.toList()..sort(),
        'staleCacheFallbackMemoryIds': staleCacheFallbackMemoryIds.toList()
          ..sort(),
        'statusCounts': statusCounts,
      };

  @override
  bool operator ==(Object other) =>
      other is ARMemoryModelPreflightDiagnostics &&
      memoryCount == other.memoryCount &&
      modelCount == other.modelCount &&
      resolvedCount == other.resolvedCount &&
      unresolvedCount == other.unresolvedCount &&
      cachedCount == other.cachedCount &&
      cacheHitCount == other.cacheHitCount &&
      passthroughCount == other.passthroughCount &&
      missingSourceCount == other.missingSourceCount &&
      failedCount == other.failedCount &&
      revalidatedCount == other.revalidatedCount &&
      staleCacheFallbackCount == other.staleCacheFallbackCount &&
      summaryLabel == other.summaryLabel &&
      _setEquals(unresolvedMemoryIds, other.unresolvedMemoryIds) &&
      _setEquals(revalidatedMemoryIds, other.revalidatedMemoryIds) &&
      _setEquals(
        staleCacheFallbackMemoryIds,
        other.staleCacheFallbackMemoryIds,
      ) &&
      _mapEquals(statusCounts, other.statusCounts);

  @override
  int get hashCode => Object.hash(
        memoryCount,
        modelCount,
        resolvedCount,
        unresolvedCount,
        cachedCount,
        cacheHitCount,
        passthroughCount,
        missingSourceCount,
        failedCount,
        revalidatedCount,
        staleCacheFallbackCount,
        summaryLabel,
        _setHash(unresolvedMemoryIds),
        _setHash(revalidatedMemoryIds),
        _setHash(staleCacheFallbackMemoryIds),
        _mapHash(statusCounts),
      );
}

int _int(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

Set<String> _stringSet(Object? value) {
  if (value is! Iterable) {
    return const <String>{};
  }
  return Set<String>.unmodifiable(
    value.whereType<String>().where((item) => item.trim().isNotEmpty),
  );
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) {
    return const <String, int>{};
  }
  return Map<String, int>.unmodifiable(
    value.map(
      (key, value) => MapEntry(
        key.toString(),
        value is num ? value.toInt() : 0,
      ),
    ),
  );
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int _setHash<T>(Set<T> values) =>
    Object.hashAll(values.map((value) => value.hashCode).toList()..sort());

int _mapHash<K, V>(Map<K, V> values) {
  final hashes = [
    for (final entry in values.entries) Object.hash(entry.key, entry.value),
  ]..sort();
  return Object.hashAll(hashes);
}
