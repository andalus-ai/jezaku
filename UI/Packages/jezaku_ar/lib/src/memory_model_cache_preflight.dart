import 'package:ar_model_cache/ar_model_cache.dart';

import 'geo_anchor.dart';
import 'memory_model_descriptor.dart';

class JejakuMemoryModelPreflightResult {
  const JejakuMemoryModelPreflightResult({
    required this.memory,
    required this.preparedMemory,
    this.descriptor,
    this.cacheResult,
  });

  final JejakuGeoAnchor memory;
  final JejakuGeoAnchor preparedMemory;
  final JejakuMemoryModelDescriptor? descriptor;
  final ARModelAssetCacheResult? cacheResult;

  bool get hasModel => descriptor != null;

  bool get isResolved => cacheResult?.isResolved ?? false;

  String get statusLabel => cacheResult?.statusLabel ?? 'No 3D model';

  String get memoryId => memory.id;

  Map<String, Object?> toMetadata() {
    final cache = cacheResult;
    return <String, Object?>{
      'memoryId': memory.id,
      'hasModel': hasModel,
      'isResolved': isResolved,
      'status': cache?.status.name,
      'statusLabel': statusLabel,
      'sourcePath': cache?.sourceAsset.path,
      'resolvedPath': cache?.resolvedAsset.path,
      'cacheKey': cache?.cacheKey,
      'byteLength': cache?.byteLength,
      'contentFingerprint': cache?.contentFingerprint,
      'networkMetadata': cache?.networkMetadata?.toMap(),
      'wasRevalidated': cache?.wasRevalidated,
      'usedStaleCacheOnError': cache?.usedStaleCacheOnError,
      'errorMessage': cache?.errorMessage,
    };
  }
}

class JejakuMemoryModelPreflightReport {
  const JejakuMemoryModelPreflightReport({
    this.results = const <JejakuMemoryModelPreflightResult>[],
  });

  final List<JejakuMemoryModelPreflightResult> results;

  List<JejakuMemoryModelPreflightResult> get modelResults => [
        for (final result in results)
          if (result.hasModel) result,
      ];

  int get memoryCount => results.length;

  int get modelCount => modelResults.length;

  int get resolvedCount =>
      modelResults.where((result) => result.isResolved).length;

  int get unresolvedCount => modelCount - resolvedCount;

  int get cachedCount => _countStatus(ARModelAssetCacheStatus.cached);

  int get cacheHitCount => _countStatus(ARModelAssetCacheStatus.cacheHit);

  int get passthroughCount => _countStatus(ARModelAssetCacheStatus.passthrough);

  int get missingSourceCount =>
      _countStatus(ARModelAssetCacheStatus.missingSource);

  int get failedCount => _countStatus(ARModelAssetCacheStatus.failed);

  int get revalidatedCount => modelResults
      .where((result) => result.cacheResult?.wasRevalidated ?? false)
      .length;

  int get staleCacheFallbackCount => modelResults
      .where((result) => result.cacheResult?.usedStaleCacheOnError ?? false)
      .length;

  Set<String> get revalidatedMemoryIds => Set<String>.unmodifiable(
        modelResults
            .where((result) => result.cacheResult?.wasRevalidated ?? false)
            .map((result) => result.memoryId),
      );

  Set<String> get staleCacheFallbackMemoryIds => Set<String>.unmodifiable(
        modelResults
            .where(
              (result) => result.cacheResult?.usedStaleCacheOnError ?? false,
            )
            .map((result) => result.memoryId),
      );

  bool get hasModels => modelCount > 0;

  bool get hasUnresolvedModels => unresolvedCount > 0;

  bool get hasFailures => missingSourceCount > 0 || failedCount > 0;

  bool get hasRevalidatedModels => revalidatedCount > 0;

  bool get hasStaleCacheFallbacks => staleCacheFallbackCount > 0;

  Set<String> get unresolvedMemoryIds => Set<String>.unmodifiable(
        modelResults
            .where((result) => !result.isResolved)
            .map((result) => result.memoryId),
      );

  Map<String, int> get statusCounts {
    final counts = <String, int>{};
    for (final result in modelResults) {
      final status = result.cacheResult?.status.name;
      if (status == null) {
        continue;
      }
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return Map<String, int>.unmodifiable(counts);
  }

  String get summaryLabel {
    if (modelCount == 0) {
      return 'No 3D models to prepare';
    }
    final modelLabel = modelCount == 1 ? '3D model' : '3D models';
    if (unresolvedCount > 0) {
      final unresolvedLabel = unresolvedCount == 1 ? 'needs' : 'need';
      return '$unresolvedCount of $modelCount $modelLabel '
          '$unresolvedLabel cache attention';
    }
    if (cachedCount > 0 || cacheHitCount > 0) {
      return '$resolvedCount of $modelCount $modelLabel prepared';
    }
    return '$modelCount $modelLabel ready without cache';
  }

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
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
      'revalidatedMemoryIds': revalidatedMemoryIds.toList()..sort(),
      'hasRevalidatedModels': hasRevalidatedModels,
      'staleCacheFallbackCount': staleCacheFallbackCount,
      'staleCacheFallbackMemoryIds': staleCacheFallbackMemoryIds.toList()
        ..sort(),
      'hasStaleCacheFallbacks': hasStaleCacheFallbacks,
      'hasFailures': hasFailures,
      'summaryLabel': summaryLabel,
      'unresolvedMemoryIds': unresolvedMemoryIds.toList()..sort(),
      'statusCounts': statusCounts,
      'results': [
        for (final result in results) result.toMetadata(),
      ],
    };
  }

  int _countStatus(ARModelAssetCacheStatus status) {
    return modelResults
        .where((result) => result.cacheResult?.status == status)
        .length;
  }
}

class JejakuMemoryModelCachePreflight {
  const JejakuMemoryModelCachePreflight({
    required this.cache,
    this.freshnessPolicy = ARModelAssetCacheFreshnessPolicy.none,
  });

  final ARModelAssetCache cache;
  final ARModelAssetCacheFreshnessPolicy freshnessPolicy;

  Future<JejakuMemoryModelPreflightResult> prepareMemory(
    JejakuGeoAnchor memory, {
    bool refresh = false,
    ARModelAssetCacheFreshnessPolicy? freshnessPolicy,
  }) async {
    final descriptor =
        JejakuMemoryModelDescriptor.tryFromMetadata(memory.metadata);
    if (descriptor == null) {
      return JejakuMemoryModelPreflightResult(
        memory: memory,
        preparedMemory: memory,
      );
    }

    final cacheResult = await cache.resolve(
      descriptor.asset,
      refresh: refresh,
      freshnessPolicy: freshnessPolicy ?? this.freshnessPolicy,
    );
    return JejakuMemoryModelPreflightResult(
      memory: memory,
      preparedMemory: memory.copyWith(
        metadata: _preparedMetadata(
          memory.metadata,
          cacheResult,
        ),
      ),
      descriptor: descriptor,
      cacheResult: cacheResult,
    );
  }

  Future<List<JejakuMemoryModelPreflightResult>> prepareMemories(
    Iterable<JejakuGeoAnchor> memories, {
    bool refresh = false,
    ARModelAssetCacheFreshnessPolicy? freshnessPolicy,
  }) async {
    return (await prepareMemoriesWithReport(
      memories,
      refresh: refresh,
      freshnessPolicy: freshnessPolicy,
    ))
        .results;
  }

  Future<JejakuMemoryModelPreflightReport> prepareMemoriesWithReport(
    Iterable<JejakuGeoAnchor> memories, {
    bool refresh = false,
    ARModelAssetCacheFreshnessPolicy? freshnessPolicy,
  }) async {
    final results = <JejakuMemoryModelPreflightResult>[];
    for (final memory in memories) {
      results.add(
        await prepareMemory(
          memory,
          refresh: refresh,
          freshnessPolicy: freshnessPolicy,
        ),
      );
    }
    return JejakuMemoryModelPreflightReport(
      results: List<JejakuMemoryModelPreflightResult>.unmodifiable(results),
    );
  }

  Map<String, Object?> _preparedMetadata(
    Map<String, Object?> metadata,
    ARModelAssetCacheResult cacheResult,
  ) {
    final asset = cacheResult.isResolved
        ? cacheResult.resolvedAsset
        : cacheResult.sourceAsset;
    final prepared = Map<String, Object?>.from(metadata)
      ..remove('modelPackage')
      ..['modelAsset'] = asset.toMap()
      ..['modelPath'] = asset.path
      ..['modelFormat'] = asset.format.name
      ..['modelSource'] = asset.source.name
      ..['modelCache'] = cacheResult.toMetadata()
      ..['modelCacheStatus'] = cacheResult.status.name
      ..['modelCacheStatusLabel'] = cacheResult.statusLabel
      ..['modelCacheIsResolved'] = cacheResult.isResolved;
    final package = asset.package;
    if (package != null && package.isNotEmpty) {
      prepared['modelPackage'] = package;
    }
    return Map<String, Object?>.unmodifiable(prepared);
  }
}
