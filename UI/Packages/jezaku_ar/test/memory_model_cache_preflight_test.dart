import 'dart:io';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_model_cache/ar_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

void main() {
  late Directory tempDir;
  late Directory cacheDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'jezaku_model_preflight_test_',
    );
    cacheDir = Directory('${tempDir.path}/model_cache');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  JejakuMemoryModelCachePreflight preflight({
    ARModelAssetByteFetcher fetcher = const HttpARModelAssetByteFetcher(),
    DateTime Function()? now,
    ARModelAssetCacheFreshnessPolicy freshnessPolicy =
        ARModelAssetCacheFreshnessPolicy.none,
  }) {
    return JejakuMemoryModelCachePreflight(
      cache: ARModelAssetCache(
        cacheDirectory: cacheDir,
        fetcher: fetcher,
        now: now ?? () => DateTime.utc(2026, 6, 5, 10),
      ),
      freshnessPolicy: freshnessPolicy,
    );
  }

  test('preflights local model files into cached memory metadata', () async {
    final source = File('${tempDir.path}/courtyard_marker.obj');
    await source.writeAsString('o Courtyard\nv 0 0 0\n');
    final asset = ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
      fallbackSizeMeters: const ARVector3(0.6, 0.4, 0.6),
    );
    final memory = JejakuGeoAnchor(
      id: 'model_memory',
      title: 'Cached marker',
      latitude: -6.9175,
      longitude: 107.6191,
      metadata: <String, Object?>{
        'modelAsset': asset.toMap(),
        'modelFallbackShape': 'sphere',
      },
    );

    final result = await preflight().prepareMemory(memory);
    final prepared = result.preparedMemory;
    final preparedAsset = ARModelAsset.fromMap(
      prepared.metadata['modelAsset'] as Map<dynamic, dynamic>,
    );
    final cacheMetadata =
        prepared.metadata['modelCache'] as Map<String, Object?>;
    final node = const JejakuMemoryNodeFactory().build(prepared);

    expect(result.hasModel, isTrue);
    expect(result.cacheResult?.status, ARModelAssetCacheStatus.cached);
    expect(result.isResolved, isTrue);
    expect(preparedAsset.source, ARModelAssetSource.file);
    expect(preparedAsset.path, startsWith(cacheDir.path));
    expect(prepared.metadata['modelPath'], preparedAsset.path);
    expect(prepared.metadata['modelSource'], 'file');
    expect(prepared.metadata['modelCacheStatus'], 'cached');
    expect(prepared.metadata['modelCacheIsResolved'], isTrue);
    expect(cacheMetadata['sourcePath'], source.path);
    expect(cacheMetadata['resolvedPath'], preparedAsset.path);
    expect(node.isModelNode, isTrue);
    expect(node.modelAsset?.path, preparedAsset.path);
    expect(node.primitiveShape, ARPrimitiveShape.sphere);
    expect(node.metadata['modelCacheStatus'], 'cached');
  });

  test('summarizes mixed model preflight results', () async {
    final source = File('${tempDir.path}/summary_marker.obj');
    await source.writeAsString('o Summary\nv 0 0 0\n');
    final modelMemory = JejakuGeoAnchor(
      id: 'cached_model',
      title: 'Cached marker',
      latitude: -6.9175,
      longitude: 107.6191,
      metadata: <String, Object?>{
        'modelAsset': ARModelAsset.fromPath(
          source.path,
          source: ARModelAssetSource.file,
        ).toMap(),
      },
    );
    final missingMemory = JejakuGeoAnchor(
      id: 'missing_model',
      title: 'Missing marker',
      latitude: -6.9175,
      longitude: 107.6191,
      metadata: <String, Object?>{
        'modelAsset': ARModelAsset.fromPath(
          '${tempDir.path}/missing_summary.obj',
          source: ARModelAssetSource.file,
        ).toMap(),
      },
    );
    const photoMemory = JejakuGeoAnchor(
      id: 'photo_memory',
      title: 'Photo memory',
      latitude: -6.9175,
      longitude: 107.6191,
    );

    final report = await preflight().prepareMemoriesWithReport([
      modelMemory,
      missingMemory,
      photoMemory,
    ]);
    final metadata = report.toMetadata();

    expect(report.memoryCount, 3);
    expect(report.modelCount, 2);
    expect(report.resolvedCount, 1);
    expect(report.unresolvedCount, 1);
    expect(report.cachedCount, 1);
    expect(report.missingSourceCount, 1);
    expect(report.failedCount, 0);
    expect(report.hasFailures, isTrue);
    expect(report.unresolvedMemoryIds, {'missing_model'});
    expect(
      report.summaryLabel,
      '1 of 2 3D models needs cache attention',
    );
    expect(metadata['summaryLabel'], report.summaryLabel);
    expect(metadata['unresolvedMemoryIds'], ['missing_model']);
    expect(metadata['statusCounts'], <String, int>{
      'cached': 1,
      'missingSource': 1,
    });
    expect(metadata['results'], isA<List<Object?>>());
  });

  test('passes through memories without 3D model metadata', () async {
    const memory = JejakuGeoAnchor(
      id: 'photo_memory',
      title: 'Photo memory',
      latitude: -6.9175,
      longitude: 107.6191,
    );

    final result = await preflight().prepareMemory(memory);

    expect(result.hasModel, isFalse);
    expect(result.cacheResult, isNull);
    expect(result.preparedMemory, memory);
    expect(result.statusLabel, 'No 3D model');
  });

  test('keeps original model metadata when local cache source is missing',
      () async {
    final asset = ARModelAsset.fromPath(
      '${tempDir.path}/missing_marker.obj',
      source: ARModelAssetSource.file,
    );
    final memory = JejakuGeoAnchor(
      id: 'missing_model_memory',
      title: 'Missing marker',
      latitude: -6.9175,
      longitude: 107.6191,
      metadata: <String, Object?>{
        'modelAsset': asset.toMap(),
      },
    );

    final result = await preflight().prepareMemory(memory);
    final prepared = result.preparedMemory;
    final cacheMetadata =
        prepared.metadata['modelCache'] as Map<String, Object?>;

    expect(result.cacheResult?.status, ARModelAssetCacheStatus.missingSource);
    expect(result.isResolved, isFalse);
    expect(prepared.metadata['modelPath'], asset.path);
    expect(prepared.metadata['modelSource'], 'file');
    expect(prepared.metadata['modelCacheStatus'], 'missingSource');
    expect(prepared.metadata['modelCacheIsResolved'], isFalse);
    expect(cacheMetadata['errorMessage'], 'Model source file does not exist.');
  });

  test('applies freshness policy to network model preflight', () async {
    var clock = DateTime.utc(2026, 6, 5, 10);
    final fetcher = _FakeConditionalFetcher(
      responses: <String, ARModelAssetFetchResult>{
        'https://cdn.example.test/models/preflight.glb':
            ARModelAssetFetchResult(
          bytes: <int>[1, 2, 3],
          networkMetadata: ARModelAssetNetworkMetadata(
            responseUri: 'https://cdn.example.test/models/preflight.glb',
            eTag: '"preflight-v1"',
            lastModified: DateTime.utc(2026, 6, 5, 9),
            contentLength: 3,
          ),
        ),
      },
      revalidationResponses: <ARModelAssetRevalidationResult>[
        ARModelAssetRevalidationResult.notModified(
          networkMetadata: const ARModelAssetNetworkMetadata(
            eTag: '"preflight-v1"',
          ),
        ),
      ],
    );
    final modelPreflight = preflight(
      fetcher: fetcher,
      now: () => clock,
      freshnessPolicy: const ARModelAssetCacheFreshnessPolicy(
        networkMaxAge: Duration(hours: 1),
      ),
    );
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/preflight.glb',
      source: ARModelAssetSource.network,
    );
    final memory = JejakuGeoAnchor(
      id: 'network_model_memory',
      title: 'Network marker',
      latitude: -6.9175,
      longitude: 107.6191,
      metadata: <String, Object?>{
        'modelAsset': asset.toMap(),
      },
    );

    final first = await modelPreflight.prepareMemory(memory);
    clock = DateTime.utc(2026, 6, 5, 11, 5);
    final second = await modelPreflight.prepareMemory(memory);
    final cacheMetadata =
        second.preparedMemory.metadata['modelCache'] as Map<String, Object?>;
    final resultMetadata = second.toMetadata();
    final report = JejakuMemoryModelPreflightReport(results: [second]);
    final reportMetadata = report.toMetadata();

    expect(first.cacheResult?.status, ARModelAssetCacheStatus.cached);
    expect(second.cacheResult?.status, ARModelAssetCacheStatus.cacheHit);
    expect(second.cacheResult?.wasRevalidated, isTrue);
    expect(second.cacheResult?.networkMetadata?.fetchedAt, clock);
    expect(cacheMetadata['wasRevalidated'], isTrue);
    expect(resultMetadata['wasRevalidated'], isTrue);
    expect(report.revalidatedCount, 1);
    expect(report.revalidatedMemoryIds, {'network_model_memory'});
    expect(report.hasRevalidatedModels, isTrue);
    expect(reportMetadata['revalidatedCount'], 1);
    expect(reportMetadata['revalidatedMemoryIds'], ['network_model_memory']);
    expect(fetcher.fetchCount, 1);
    expect(fetcher.revalidationCount, 1);
    expect(fetcher.revalidationRequests.single.eTag, '"preflight-v1"');
  });

  test('reports stale cache fallback when network preflight refresh fails',
      () async {
    var clock = DateTime.utc(2026, 6, 5, 10);
    final fetcher = _FakeConditionalFetcher(
      responses: <String, ARModelAssetFetchResult>{
        'https://cdn.example.test/models/offline_preflight.glb':
            ARModelAssetFetchResult(
          bytes: <int>[7, 7, 7],
          networkMetadata: ARModelAssetNetworkMetadata(
            responseUri:
                'https://cdn.example.test/models/offline_preflight.glb',
            eTag: '"offline-preflight-v1"',
            lastModified: DateTime.utc(2026, 6, 5, 9),
            contentLength: 3,
          ),
        ),
      },
      revalidationResponses: const <ARModelAssetRevalidationResult>[],
    );
    final modelPreflight = preflight(
      fetcher: fetcher,
      now: () => clock,
      freshnessPolicy: const ARModelAssetCacheFreshnessPolicy(
        networkMaxAge: Duration(hours: 1),
      ),
    );
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/offline_preflight.glb',
      source: ARModelAssetSource.network,
    );
    final memory = JejakuGeoAnchor(
      id: 'offline_model_memory',
      title: 'Offline marker',
      latitude: -6.9175,
      longitude: 107.6191,
      metadata: <String, Object?>{
        'modelAsset': asset.toMap(),
      },
    );

    await modelPreflight.prepareMemory(memory);
    clock = DateTime.utc(2026, 6, 5, 11, 5);
    final result = await modelPreflight.prepareMemory(memory);
    final cacheMetadata =
        result.preparedMemory.metadata['modelCache'] as Map<String, Object?>;
    final resultMetadata = result.toMetadata();
    final report = JejakuMemoryModelPreflightReport(results: [result]);
    final reportMetadata = report.toMetadata();

    expect(result.cacheResult?.status, ARModelAssetCacheStatus.cacheHit);
    expect(result.cacheResult?.usedStaleCacheOnError, isTrue);
    expect(result.cacheResult?.errorMessage, contains('No fake revalidation'));
    expect(cacheMetadata['usedStaleCacheOnError'], isTrue);
    expect(resultMetadata['usedStaleCacheOnError'], isTrue);
    expect(report.staleCacheFallbackCount, 1);
    expect(report.staleCacheFallbackMemoryIds, {'offline_model_memory'});
    expect(report.hasStaleCacheFallbacks, isTrue);
    expect(reportMetadata['staleCacheFallbackCount'], 1);
    expect(reportMetadata['staleCacheFallbackMemoryIds'], [
      'offline_model_memory',
    ]);
    expect(fetcher.fetchCount, 1);
    expect(fetcher.revalidationCount, 1);
  });
}

class _FakeConditionalFetcher implements ARModelAssetConditionalFetcher {
  _FakeConditionalFetcher({
    required this.responses,
    required List<ARModelAssetRevalidationResult> revalidationResponses,
  }) : _revalidationResponses = revalidationResponses.toList();

  final Map<String, ARModelAssetFetchResult> responses;
  final List<ARModelAssetRevalidationResult> _revalidationResponses;
  final revalidationRequests = <ARModelAssetRevalidationRequest>[];
  var _fetchCount = 0;
  var _revalidationCount = 0;

  int get fetchCount => _fetchCount;

  int get revalidationCount => _revalidationCount;

  @override
  Future<List<int>> fetch(Uri uri) async {
    return (await fetchWithMetadata(uri)).bytes;
  }

  @override
  Future<ARModelAssetFetchResult> fetchWithMetadata(Uri uri) async {
    _fetchCount += 1;
    final response = responses[uri.toString()];
    if (response == null) {
      throw StateError('No fake response for $uri');
    }
    return response;
  }

  @override
  Future<ARModelAssetRevalidationResult> revalidate(
    Uri uri,
    ARModelAssetRevalidationRequest request,
  ) async {
    _revalidationCount += 1;
    revalidationRequests.add(request);
    if (_revalidationResponses.isEmpty) {
      throw StateError('No fake revalidation response for $uri');
    }
    return _revalidationResponses.removeAt(0);
  }
}
