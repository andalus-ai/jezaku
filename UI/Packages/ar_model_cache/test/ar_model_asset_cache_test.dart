import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_model_cache/ar_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late Directory cacheDir;
  late DateTime now;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ar_model_cache_test_');
    cacheDir = Directory('${tempDir.path}/models');
    now = DateTime.utc(2026, 6, 5, 9, 30);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ARModelAssetCache cache({ARModelAssetByteFetcher? fetcher}) {
    return ARModelAssetCache(
      cacheDirectory: cacheDir,
      fetcher: fetcher ?? _FakeFetcher(<String, List<int>>{}),
      now: () => now,
    );
  }

  test('fingerprintBytes uses stable FNV-1a 64-bit hashes', () {
    expect(fingerprintBytes(const <int>[]), 'cbf29ce484222325');
    expect(fingerprintBytes(utf8.encode('hello')), 'a430d84680aabd0b');
  });

  test(
    'passes through bundled Flutter assets without writing cache files',
    () async {
      final asset = ARModelAsset.fromPath(
        'assets/models/bundled_marker.obj',
        fallbackSizeMeters: const ARVector3(0.4, 0.3, 0.4),
      );

      final result = await cache().resolve(asset);

      expect(result.status, ARModelAssetCacheStatus.passthrough);
      expect(result.isResolved, isTrue);
      expect(result.resolvedAsset, asset);
      expect(result.localPath, isNull);
      expect(result.validationReport.isValid, isTrue);
      expect(await cacheDir.exists(), isFalse);
    },
  );

  test('copies local file models into a stable cache entry', () async {
    final source = File('${tempDir.path}/imported_marker.obj');
    await source.writeAsString('o Marker\nv 0 0 0\n');
    final asset = ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
      fallbackSizeMeters: const ARVector3(0.6, 0.4, 0.6),
    );
    final store = cache();

    final first = await store.resolve(asset);
    final second = await store.resolve(asset);

    expect(first.status, ARModelAssetCacheStatus.cached);
    expect(first.didWriteCache, isTrue);
    expect(first.resolvedAsset.source, ARModelAssetSource.file);
    expect(first.resolvedAsset.path, startsWith(cacheDir.path));
    expect(first.resolvedAsset.path, endsWith('.obj'));
    expect(first.resolvedAsset.metadata['modelCacheKey'], first.cacheKey);
    expect(
      first.resolvedAsset.metadata['modelCacheContentFingerprint'],
      first.contentFingerprint,
    );
    expect(
      await File(first.resolvedAsset.path).readAsString(),
      source.readAsStringSync(),
    );
    expect(first.manifest?.cacheKey, first.cacheKey);
    expect(first.manifest?.sourcePath, source.path);
    expect(first.manifest?.format, 'obj');
    expect(first.manifest?.byteLength, source.lengthSync());
    expect(first.manifest?.contentFingerprint, first.contentFingerprint);
    expect(first.manifest?.validation['summaryLabel'], 'Model asset ready');
    expect(
      first.manifest?.renderProfile['summaryLabel'],
      'Native mesh on Android and iOS',
    );
    final manifest = await _manifestMap(first);
    expect(manifest['sourcePath'], source.path);
    expect(manifest['resolvedPath'], first.resolvedAsset.path);
    expect(manifest['contentFingerprint'], first.contentFingerprint);
    expect(manifest['sourceByteLength'], source.lengthSync());
    expect(manifest['sourceModifiedAt'], isA<String>());
    expect(manifest['sourceContentFingerprint'], first.contentFingerprint);
    expect(second.status, ARModelAssetCacheStatus.cacheHit);
    expect(second.isCacheHit, isTrue);
    expect(second.resolvedAsset.path, first.resolvedAsset.path);
    expect(
      second.resolvedAsset.metadata['modelCacheContentFingerprint'],
      second.contentFingerprint,
    );

    final stats = await store.inspect();
    expect(stats.entryCount, 1);
    expect(stats.byteLength, source.lengthSync());
    expect(await _manifestFile(first).exists(), isTrue);
  });

  test('atomic cache writes leave no temporary files behind', () async {
    final source = File('${tempDir.path}/atomic_marker.obj');
    await source.writeAsString('old model');
    final asset = ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
    );
    final store = cache();

    await store.resolve(asset);
    expect(await _temporaryFileNames(cacheDir), isEmpty);

    await source.writeAsString('new model');
    await store.resolve(asset, refresh: true);

    expect(await _temporaryFileNames(cacheDir), isEmpty);
    expect((await store.inspect()).entryCount, 1);
  });

  test('ignores interrupted atomic write temporary files', () async {
    await cacheDir.create(recursive: true);
    await File('${cacheDir.path}/model_interrupted.obj.tmp.1')
        .writeAsString('partial model');
    await File('${cacheDir.path}/model_interrupted.manifest.json.tmp.2')
        .writeAsString('{"partial":true}');
    final store = cache();

    final stats = await store.inspect();
    final entries = await store.inspectEntries();
    final report = await store.inspectIntegrity();

    expect(stats.isEmpty, isTrue);
    expect(entries, isEmpty);
    expect(report.isHealthy, isTrue);
  });

  test('cleans model cache temporary files', () async {
    await cacheDir.create(recursive: true);
    final first = File('${cacheDir.path}/model_first.obj.tmp.1');
    final second = File('${cacheDir.path}/model_second.manifest.json.tmp.2');
    await first.writeAsString('partial model');
    await second.writeAsString('partial manifest');
    final store = cache();
    final expectedByteLength = first.lengthSync() + second.lengthSync();

    final result = await store.cleanupTemporaryFiles();

    expect(result.didCleanup, isTrue);
    expect(result.removedFileCount, 2);
    expect(result.removedByteLength, expectedByteLength);
    expect(
      result.removedPaths,
      unorderedEquals(<String>[first.path, second.path]),
    );
    expect(result.skippedFileCount, 0);
    expect(result.summaryLabel, 'Removed 2 model cache temporary files');
    expect(await _temporaryFileNames(cacheDir), isEmpty);
  });

  test('temporary file cleanup respects minimum age', () async {
    await cacheDir.create(recursive: true);
    final oldTemp = File('${cacheDir.path}/model_old.obj.tmp.1');
    final freshTemp = File('${cacheDir.path}/model_fresh.obj.tmp.2');
    await oldTemp.writeAsString('old');
    await freshTemp.writeAsString('fresh');
    await oldTemp.setLastModified(now.subtract(const Duration(hours: 2)));
    await freshTemp.setLastModified(now.subtract(const Duration(minutes: 5)));
    final store = cache();

    final result = await store.cleanupTemporaryFiles(
      minimumAge: const Duration(hours: 1),
    );

    expect(result.removedPaths, [oldTemp.path]);
    expect(await oldTemp.exists(), isFalse);
    expect(await freshTemp.exists(), isTrue);
    expect(await _temporaryFileNames(cacheDir), ['model_fresh.obj.tmp.2']);
  });

  test('temporary file cleanup rejects negative minimum age', () async {
    final store = cache();

    await expectLater(
      store.cleanupTemporaryFiles(
        minimumAge: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );
  });

  test('cache hits refresh cached entry recency', () async {
    final source = File('${tempDir.path}/touch_marker.obj');
    await source.writeAsString('o Touch\nv 0 0 0\n');
    final asset = ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
    );
    final store = cache();
    final first = await store.resolve(asset);
    final cachedFile = File(first.resolvedAsset.path);
    final oldModifiedAt = now.subtract(const Duration(days: 30));
    await cachedFile.setLastModified(oldModifiedAt);
    final initialManifest = await _manifestMap(first);
    expect(initialManifest['createdAt'], initialManifest['lastUsedAt']);

    now = DateTime.utc(2026, 6, 5, 12);
    final second = await store.resolve(asset);
    final touchedModifiedAt = (await cachedFile.lastModified()).toUtc();
    final touchedManifest = await _manifestMap(second);

    expect(second.status, ARModelAssetCacheStatus.cacheHit);
    expect(touchedModifiedAt.isAfter(oldModifiedAt), isTrue);
    expect(
      touchedModifiedAt.difference(now).inSeconds.abs(),
      lessThanOrEqualTo(1),
    );
    expect(touchedManifest['createdAt'], initialManifest['createdAt']);
    expect(touchedManifest['lastUsedAt'], now.toUtc().toIso8601String());
    expect(
      touchedManifest['sourceByteLength'],
      initialManifest['sourceByteLength'],
    );
    expect(
      touchedManifest['sourceModifiedAt'],
      initialManifest['sourceModifiedAt'],
    );
    expect(
      touchedManifest['sourceContentFingerprint'],
      initialManifest['sourceContentFingerprint'],
    );
  });

  test('local file cache hits refresh when source bytes change', () async {
    final source = File('${tempDir.path}/changed_source_marker.obj');
    await source.writeAsString('old model');
    final asset = ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
    );
    final store = cache();

    final first = await store.resolve(asset);
    final firstManifest = await _manifestMap(first);
    await source.writeAsString('new model');
    now = DateTime.utc(2026, 6, 5, 13);
    final second = await store.resolve(asset);
    final secondManifest = await _manifestMap(second);

    expect(first.status, ARModelAssetCacheStatus.cached);
    expect(second.status, ARModelAssetCacheStatus.cached);
    expect(second.didWriteCache, isTrue);
    expect(second.resolvedAsset.path, first.resolvedAsset.path);
    expect(
      await File(second.resolvedAsset.path).readAsString(),
      'new model',
    );
    expect(second.contentFingerprint, isNot(first.contentFingerprint));
    expect(secondManifest['createdAt'], firstManifest['createdAt']);
    expect(secondManifest['lastUsedAt'], now.toUtc().toIso8601String());
    expect(secondManifest['sourceByteLength'], source.lengthSync());
    expect(
      secondManifest['sourceContentFingerprint'],
      second.contentFingerprint,
    );
  });

  test('local file cache hits remain usable when source disappears', () async {
    final source = File('${tempDir.path}/deleted_source_marker.obj');
    await source.writeAsString('cached model');
    final asset = ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
    );
    final store = cache();
    final first = await store.resolve(asset);
    await source.delete();

    final second = await store.resolve(asset);

    expect(second.status, ARModelAssetCacheStatus.cacheHit);
    expect(second.isResolved, isTrue);
    expect(second.resolvedAsset.path, first.resolvedAsset.path);
    expect(
      await File(second.resolvedAsset.path).readAsString(),
      'cached model',
    );
  });

  test('inspects cached model entries with manifest metadata', () async {
    final store = cache();
    now = DateTime.utc(2026, 6, 5, 8);
    final older = await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'entry_older.obj',
      contents: 'older',
    );
    now = DateTime.utc(2026, 6, 5, 9);
    final newer = await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'entry_newer.obj',
      contents: 'newer',
    );

    final entries = await store.inspectEntries();
    final newestEntry = entries.first;

    expect(entries, hasLength(2));
    expect(entries.map((entry) => entry.path), [
      newer.resolvedAsset.path,
      older.resolvedAsset.path,
    ]);
    expect(newestEntry.cacheKey, newer.cacheKey);
    expect(newestEntry.hasManifest, isTrue);
    expect(newestEntry.sourcePath, endsWith('entry_newer.obj'));
    expect(newestEntry.source, 'file');
    expect(newestEntry.format, 'obj');
    expect(newestEntry.lastUsedAt, DateTime.utc(2026, 6, 5, 9));
    expect(newestEntry.createdAt, DateTime.utc(2026, 6, 5, 9));
    expect(newestEntry.toMetadata()['manifest'], isA<Map<String, Object?>>());
  });

  test('repairs missing cache manifests from cached files', () async {
    final store = cache();
    await cacheDir.create(recursive: true);
    final cachedFile = File('${cacheDir.path}/recovered_marker.obj');
    await cachedFile.writeAsString('o Recovered\nv 0 0 0\n');
    final modifiedAt = DateTime.utc(2026, 6, 4, 10, 15);
    await cachedFile.setLastModified(modifiedAt);

    final beforeEntries = await store.inspectEntries();
    expect(beforeEntries, hasLength(1));
    expect(beforeEntries.single.hasManifest, isFalse);

    now = DateTime.utc(2026, 6, 5, 11);
    final result = await store.repairManifests();
    final afterEntries = await store.inspectEntries();
    final manifestFile =
        File('${cacheDir.path}/recovered_marker.manifest.json');
    final manifest = Map<String, Object?>.from(
      jsonDecode(await manifestFile.readAsString()) as Map,
    );

    expect(result.didRepair, isTrue);
    expect(result.repairedEntryCount, 1);
    expect(result.skippedEntryCount, 0);
    expect(result.repairedManifestPaths, [manifestFile.path]);
    expect(result.summaryLabel, 'Repaired 1 model cache manifest');
    expect(afterEntries.single.hasManifest, isTrue);
    expect(afterEntries.single.sourcePath, cachedFile.path);
    expect(afterEntries.single.source, 'file');
    expect(afterEntries.single.format, 'obj');
    expect(afterEntries.single.contentFingerprint, isNotEmpty);
    expect(manifest['sourcePath'], cachedFile.path);
    expect(manifest['resolvedPath'], cachedFile.path);
    expect(manifest['source'], 'file');
    expect(manifest['format'], 'obj');
    expect(manifest['byteLength'], cachedFile.lengthSync());
    expect(
      (manifest['validation'] as Map)['isValid'],
      isTrue,
    );
    expect(
      (manifest['validation'] as Map)['recoveredManifest'],
      isTrue,
    );
  });

  test('repair manifests is a no-op when cached entries are indexed', () async {
    final store = cache();
    await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'indexed_marker.obj',
      contents: 'indexed',
    );

    final result = await store.repairManifests();

    expect(result.didRepair, isFalse);
    expect(result.repairedEntryCount, 0);
    expect(result.skippedEntryCount, 0);
    expect(result.summaryLabel, 'Model cache manifests already healthy');
  });

  test('reports model cache integrity issues', () async {
    final store = cache();
    final fixture = await _seedModelCacheIntegrityIssues(
      store: store,
      tempDir: tempDir,
      cacheDir: cacheDir,
      now: now,
    );

    final report = await store.inspectIntegrity();
    final codes = report.issues.map((issue) => issue.code).toList();
    final metadata = report.toMetadata();

    expect(report.isHealthy, isFalse);
    expect(report.issueCount, 6);
    expect(report.summaryLabel, 'Model cache has 6 integrity issues');
    expect(
      codes,
      containsAll(<ARModelAssetCacheIntegrityIssueCode>[
        ARModelAssetCacheIntegrityIssueCode.byteLengthMismatch,
        ARModelAssetCacheIntegrityIssueCode.contentFingerprintMismatch,
        ARModelAssetCacheIntegrityIssueCode.unsupportedFormat,
        ARModelAssetCacheIntegrityIssueCode.missingManifest,
        ARModelAssetCacheIntegrityIssueCode.orphanManifest,
        ARModelAssetCacheIntegrityIssueCode.manifestMissingFile,
      ]),
    );
    expect(
      report.countCode(ARModelAssetCacheIntegrityIssueCode.missingManifest),
      1,
    );
    expect(metadata['summaryLabel'], report.summaryLabel);
    expect(
      (metadata['issueCounts'] as Map)['contentFingerprintMismatch'],
      1,
    );
    expect(
      report.issues
          .where(
            (issue) =>
                issue.code ==
                ARModelAssetCacheIntegrityIssueCode.byteLengthMismatch,
          )
          .single
          .actual,
      File(fixture.cached.resolvedAsset.path).lengthSync(),
    );
  });

  test('repairs model cache integrity issues', () async {
    final store = cache();
    final fixture = await _seedModelCacheIntegrityIssues(
      store: store,
      tempDir: tempDir,
      cacheDir: cacheDir,
      now: now,
    );

    final result = await store.repairIntegrity();
    final afterReport = await store.inspectIntegrity();
    final repairedTamperedManifest = await _manifestMap(fixture.cached);
    final repairedUnindexedManifest = Map<String, Object?>.from(
      jsonDecode(
        await File('${cacheDir.path}/unindexed.manifest.json').readAsString(),
      ) as Map,
    );

    expect(result.didRepair, isTrue);
    expect(result.isFullyRepaired, isTrue);
    expect(result.beforeReport.issueCount, 6);
    expect(result.afterReport.isHealthy, isTrue);
    expect(result.repairedManifestCount, 2);
    expect(
      result.repairedManifestPaths,
      unorderedEquals(<String>[
        _manifestFile(fixture.cached).path,
        '${cacheDir.path}/unindexed.manifest.json',
      ]),
    );
    expect(result.removedManifestPaths, [fixture.orphanManifestFile.path]);
    expect(result.removedManifestCount, 1);
    expect(result.skippedCount, 0);
    expect(
      result.summaryLabel,
      'Repaired 2 model cache manifests, '
      'Removed 1 stale model cache manifest',
    );
    expect(afterReport.isHealthy, isTrue);
    expect(await fixture.orphanManifestFile.exists(), isFalse);
    expect(repairedTamperedManifest['byteLength'], 7);
    expect(repairedTamperedManifest['format'], 'obj');
    expect(
      repairedTamperedManifest['contentFingerprint'],
      isNot('stale_fingerprint'),
    );
    expect(repairedUnindexedManifest['sourcePath'], fixture.unindexedFile.path);
    expect(
      (result.toMetadata()['afterReport'] as Map)['isHealthy'],
      isTrue,
    );
  });

  test('repair integrity is a no-op for a healthy model cache', () async {
    final store = cache();
    await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'already_healthy_marker.obj',
      contents: 'healthy',
    );

    final result = await store.repairIntegrity();

    expect(result.didRepair, isFalse);
    expect(result.isFullyRepaired, isTrue);
    expect(result.summaryLabel, 'Model cache integrity already healthy');
    expect(result.repairedManifestCount, 0);
    expect(result.removedManifestCount, 0);
  });

  test('reports healthy integrity for indexed model cache', () async {
    final store = cache();
    await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'healthy_marker.obj',
      contents: 'healthy',
    );

    final report = await store.inspectIntegrity();

    expect(report.isHealthy, isTrue);
    expect(report.issueCount, 0);
    expect(report.summaryLabel, 'Model cache healthy');
    expect(report.toMetadata()['isHealthy'], isTrue);
  });

  test('refresh overwrites an existing local cache entry', () async {
    final source = File('${tempDir.path}/refresh_marker.obj');
    await source.writeAsString('old model');
    final asset = ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
      fallbackSizeMeters: const ARVector3(0.6, 0.4, 0.6),
    );
    final store = cache();

    final first = await store.resolve(asset);
    final firstManifest = await _manifestMap(first);
    await source.writeAsString('new model');
    now = DateTime.utc(2026, 6, 5, 10);
    final refreshed = await store.resolve(asset, refresh: true);
    final refreshedManifest = await _manifestMap(refreshed);

    expect(refreshed.status, ARModelAssetCacheStatus.cached);
    expect(refreshed.resolvedAsset.path, first.resolvedAsset.path);
    expect(
      await File(refreshed.resolvedAsset.path).readAsString(),
      'new model',
    );
    expect(refreshed.contentFingerprint, isNot(first.contentFingerprint));
    expect(refreshedManifest['createdAt'], firstManifest['createdAt']);
    expect(refreshedManifest['lastUsedAt'], now.toUtc().toIso8601String());
    expect(
      refreshedManifest['contentFingerprint'],
      refreshed.contentFingerprint,
    );
  });

  test('downloads network models through the injected fetcher', () async {
    final fetcher = _FakeFetcher(<String, List<int>>{
      'https://cdn.example.test/models/sign.glb': <int>[1, 2, 3, 4],
    });
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/sign.glb',
      source: ARModelAssetSource.network,
      fallbackSizeMeters: const ARVector3(0.6, 0.4, 0.6),
    );
    final store = cache(fetcher: fetcher);

    final first = await store.resolve(asset);
    final second = await store.resolve(asset);

    expect(first.status, ARModelAssetCacheStatus.cached);
    expect(first.byteLength, 4);
    expect(first.resolvedAsset.source, ARModelAssetSource.file);
    expect(first.resolvedAsset.path, endsWith('.glb'));
    expect(first.manifest?.source, 'network');
    expect(
      first.manifest?.renderProfile['summaryLabel'],
      contains('Android'),
    );
    expect(fetcher.fetchCount, 1);
    expect(second.status, ARModelAssetCacheStatus.cacheHit);
    expect(fetcher.fetchCount, 1);
  });

  test('persists network response metadata in cache manifests', () async {
    final lastModified = DateTime.utc(2026, 6, 5, 7, 45);
    final fetcher = _FakeMetadataFetcher(<String, ARModelAssetFetchResult>{
      'https://cdn.example.test/models/redirected.glb': ARModelAssetFetchResult(
        bytes: <int>[5, 6, 7],
        networkMetadata: ARModelAssetNetworkMetadata(
          responseUri: 'https://cdn.example.test/resolved/redirected.glb',
          contentType: 'model/gltf-binary',
          eTag: '"model-v1"',
          lastModified: lastModified,
          contentLength: 3,
        ),
      ),
    });
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/redirected.glb',
      source: ARModelAssetSource.network,
      fallbackSizeMeters: const ARVector3(0.6, 0.4, 0.6),
    );
    final store = cache(fetcher: fetcher);

    final first = await store.resolve(asset);
    final second = await store.resolve(asset);
    final manifest = await _manifestMap(first);
    final manifestNetworkMetadata =
        Map<String, Object?>.from(manifest['networkMetadata'] as Map);
    final entries = await store.inspectEntries();
    final resolvedMetadata = Map<String, Object?>.from(
      first.resolvedAsset.metadata['modelCacheNetworkMetadata'] as Map,
    );

    expect(first.status, ARModelAssetCacheStatus.cached);
    expect(
      first.networkMetadata?.responseUri,
      endsWith('/resolved/redirected.glb'),
    );
    expect(first.networkMetadata?.contentType, 'model/gltf-binary');
    expect(first.networkMetadata?.eTag, '"model-v1"');
    expect(first.networkMetadata?.lastModified, lastModified);
    expect(first.networkMetadata?.contentLength, 3);
    expect(resolvedMetadata['eTag'], '"model-v1"');
    expect(
      manifestNetworkMetadata['responseUri'],
      endsWith('/resolved/redirected.glb'),
    );
    expect(manifestNetworkMetadata['contentType'], 'model/gltf-binary');
    expect(manifestNetworkMetadata['eTag'], '"model-v1"');
    expect(
      manifestNetworkMetadata['lastModified'],
      lastModified.toUtc().toIso8601String(),
    );
    expect(manifestNetworkMetadata['contentLength'], 3);
    expect(entries.single.networkMetadata?.eTag, '"model-v1"');
    expect(
      (entries.single.toMetadata()['networkMetadata'] as Map)['contentLength'],
      3,
    );
    expect(second.status, ARModelAssetCacheStatus.cacheHit);
    expect(second.networkMetadata?.eTag, '"model-v1"');
    expect(
      (second.resolvedAsset.metadata['modelCacheNetworkMetadata']
          as Map)['contentType'],
      'model/gltf-binary',
    );
    expect(fetcher.fetchCount, 1);
  });

  test('revalidates network cache refreshes with stored validators', () async {
    final lastModified = DateTime.utc(2026, 6, 5, 7, 45);
    final fetcher = _FakeConditionalFetcher(
      responses: <String, ARModelAssetFetchResult>{
        'https://cdn.example.test/models/revalidate.glb':
            ARModelAssetFetchResult(
          bytes: <int>[5, 6, 7],
          networkMetadata: ARModelAssetNetworkMetadata(
            responseUri: 'https://cdn.example.test/models/revalidate.glb',
            contentType: 'model/gltf-binary',
            eTag: '"model-v1"',
            lastModified: lastModified,
            contentLength: 3,
          ),
        ),
      },
      revalidationResponses: <ARModelAssetRevalidationResult>[
        ARModelAssetRevalidationResult.notModified(
          networkMetadata: const ARModelAssetNetworkMetadata(
            eTag: '"model-v1"',
          ),
        ),
      ],
    );
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/revalidate.glb',
      source: ARModelAssetSource.network,
    );
    final store = cache(fetcher: fetcher);

    final first = await store.resolve(asset);
    final firstManifest = await _manifestMap(first);
    now = DateTime.utc(2026, 6, 5, 9);
    final second = await store.resolve(asset, refresh: true);
    final secondManifest = await _manifestMap(second);

    expect(second.status, ARModelAssetCacheStatus.cacheHit);
    expect(second.isCacheHit, isTrue);
    expect(second.didWriteCache, isFalse);
    expect(second.wasRevalidated, isTrue);
    expect(second.resolvedAsset.path, first.resolvedAsset.path);
    expect(await File(second.resolvedAsset.path).readAsBytes(), <int>[5, 6, 7]);
    expect(second.networkMetadata?.eTag, '"model-v1"');
    expect(second.networkMetadata?.contentType, 'model/gltf-binary');
    expect(second.networkMetadata?.lastModified, lastModified);
    expect(fetcher.fetchCount, 1);
    expect(fetcher.revalidationCount, 1);
    expect(fetcher.revalidationRequests.single.eTag, '"model-v1"');
    expect(fetcher.revalidationRequests.single.lastModified, lastModified);
    expect(
      fetcher.revalidationRequests.single.headers['if-modified-since'],
      isNotEmpty,
    );
    expect(secondManifest['createdAt'], firstManifest['createdAt']);
    expect(secondManifest['lastUsedAt'], now.toUtc().toIso8601String());
    expect(
      (secondManifest['networkMetadata'] as Map)['contentType'],
      'model/gltf-binary',
    );
  });

  test('refresh writes changed network bytes after conditional revalidation',
      () async {
    final lastModified = DateTime.utc(2026, 6, 5, 7, 45);
    final refreshedModified = DateTime.utc(2026, 6, 5, 8, 15);
    final fetcher = _FakeConditionalFetcher(
      responses: <String, ARModelAssetFetchResult>{
        'https://cdn.example.test/models/revalidate_changed.glb':
            ARModelAssetFetchResult(
          bytes: <int>[1, 2, 3],
          networkMetadata: ARModelAssetNetworkMetadata(
            responseUri:
                'https://cdn.example.test/models/revalidate_changed.glb',
            eTag: '"model-v1"',
            lastModified: lastModified,
            contentLength: 3,
          ),
        ),
      },
      revalidationResponses: <ARModelAssetRevalidationResult>[
        ARModelAssetRevalidationResult.fetched(
          bytes: <int>[9, 8, 7, 6],
          networkMetadata: ARModelAssetNetworkMetadata(
            responseUri:
                'https://cdn.example.test/models/revalidate_changed.glb',
            eTag: '"model-v2"',
            lastModified: refreshedModified,
            contentLength: 4,
          ),
        ),
      ],
    );
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/revalidate_changed.glb',
      source: ARModelAssetSource.network,
    );
    final store = cache(fetcher: fetcher);

    final first = await store.resolve(asset);
    now = DateTime.utc(2026, 6, 5, 9, 30);
    final refreshed = await store.resolve(asset, refresh: true);
    final manifest = await _manifestMap(refreshed);

    expect(refreshed.status, ARModelAssetCacheStatus.cached);
    expect(refreshed.wasRevalidated, isTrue);
    expect(refreshed.resolvedAsset.path, first.resolvedAsset.path);
    expect(await File(refreshed.resolvedAsset.path).readAsBytes(), <int>[
      9,
      8,
      7,
      6,
    ]);
    expect(refreshed.contentFingerprint, isNot(first.contentFingerprint));
    expect(refreshed.networkMetadata?.eTag, '"model-v2"');
    expect((manifest['networkMetadata'] as Map)['eTag'], '"model-v2"');
    expect(fetcher.fetchCount, 1);
    expect(fetcher.revalidationCount, 1);
    expect(fetcher.revalidationRequests.single.eTag, '"model-v1"');
  });

  test('freshness policy revalidates stale network cache hits', () async {
    final fetchedAt = now;
    final fetcher = _FakeConditionalFetcher(
      responses: <String, ARModelAssetFetchResult>{
        'https://cdn.example.test/models/stale_policy.glb':
            ARModelAssetFetchResult(
          bytes: <int>[4, 5, 6],
          networkMetadata: ARModelAssetNetworkMetadata(
            responseUri: 'https://cdn.example.test/models/stale_policy.glb',
            eTag: '"model-v1"',
            lastModified: DateTime.utc(2026, 6, 5, 8),
            contentLength: 3,
          ),
        ),
      },
      revalidationResponses: <ARModelAssetRevalidationResult>[
        ARModelAssetRevalidationResult.notModified(
          networkMetadata: const ARModelAssetNetworkMetadata(
            eTag: '"model-v1"',
          ),
        ),
      ],
    );
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/stale_policy.glb',
      source: ARModelAssetSource.network,
    );
    const freshnessPolicy = ARModelAssetCacheFreshnessPolicy(
      networkMaxAge: Duration(hours: 1),
    );
    final store = cache(fetcher: fetcher);

    final first = await store.resolve(asset);
    final firstManifest = await _manifestMap(first);
    now = fetchedAt.add(const Duration(minutes: 30));
    final recentHit = await store.resolve(
      asset,
      freshnessPolicy: freshnessPolicy,
    );
    now = fetchedAt.add(const Duration(hours: 1, minutes: 1));
    final staleHit = await store.resolve(
      asset,
      freshnessPolicy: freshnessPolicy,
    );
    final staleManifest = await _manifestMap(staleHit);

    expect(first.status, ARModelAssetCacheStatus.cached);
    expect(
      (firstManifest['networkMetadata'] as Map)['fetchedAt'],
      fetchedAt.toUtc().toIso8601String(),
    );
    expect(recentHit.status, ARModelAssetCacheStatus.cacheHit);
    expect(recentHit.wasRevalidated, isFalse);
    expect(fetcher.revalidationCount, 1);
    expect(staleHit.status, ARModelAssetCacheStatus.cacheHit);
    expect(staleHit.wasRevalidated, isTrue);
    expect(staleHit.networkMetadata?.fetchedAt, now);
    expect(
      (staleManifest['networkMetadata'] as Map)['fetchedAt'],
      now.toUtc().toIso8601String(),
    );
    expect(
      fetcher.revalidationRequests.single.headers['if-none-match'],
      '"model-v1"',
    );
  });

  test('freshness policy uses stale network cache when revalidation fails',
      () async {
    final fetchedAt = now;
    final fetcher = _FakeConditionalFetcher(
      responses: <String, ARModelAssetFetchResult>{
        'https://cdn.example.test/models/offline_stale.glb':
            ARModelAssetFetchResult(
          bytes: <int>[8, 6, 7, 5],
          networkMetadata: ARModelAssetNetworkMetadata(
            responseUri: 'https://cdn.example.test/models/offline_stale.glb',
            eTag: '"offline-v1"',
            lastModified: DateTime.utc(2026, 6, 5, 8),
            contentLength: 4,
          ),
        ),
      },
      revalidationResponses: const <ARModelAssetRevalidationResult>[],
    );
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/offline_stale.glb',
      source: ARModelAssetSource.network,
    );
    const freshnessPolicy = ARModelAssetCacheFreshnessPolicy(
      networkMaxAge: Duration(hours: 1),
    );
    final store = cache(fetcher: fetcher);

    final first = await store.resolve(asset);
    now = fetchedAt.add(const Duration(hours: 1, minutes: 1));
    final staleFallback = await store.resolve(
      asset,
      freshnessPolicy: freshnessPolicy,
    );
    final metadata = staleFallback.toMetadata();
    final manifest = await _manifestMap(staleFallback);

    expect(first.status, ARModelAssetCacheStatus.cached);
    expect(staleFallback.status, ARModelAssetCacheStatus.cacheHit);
    expect(staleFallback.isResolved, isTrue);
    expect(staleFallback.usedStaleCacheOnError, isTrue);
    expect(staleFallback.wasRevalidated, isFalse);
    expect(staleFallback.errorMessage, contains('No fake revalidation'));
    expect(staleFallback.resolvedAsset.path, first.resolvedAsset.path);
    expect(
      await File(staleFallback.resolvedAsset.path).readAsBytes(),
      <int>[8, 6, 7, 5],
    );
    expect(
      staleFallback.networkMetadata?.fetchedAt,
      fetchedAt,
    );
    expect(metadata['usedStaleCacheOnError'], isTrue);
    expect(metadata['errorMessage'], contains('No fake revalidation'));
    expect(
      (manifest['networkMetadata'] as Map)['fetchedAt'],
      fetchedAt.toUtc().toIso8601String(),
    );
    expect(fetcher.fetchCount, 1);
    expect(fetcher.revalidationCount, 1);
    expect(fetcher.revalidationRequests.single.eTag, '"offline-v1"');
  });

  test('freshness policy rejects negative network max age', () async {
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/negative_policy.glb',
      source: ARModelAssetSource.network,
    );
    final store = cache();

    await expectLater(
      store.resolve(
        asset,
        freshnessPolicy: const ARModelAssetCacheFreshnessPolicy(
          networkMaxAge: Duration(milliseconds: -1),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('serializes concurrent resolves for the same network model', () async {
    final fetcher = _BlockingFetcher(<int>[7, 8, 9]);
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/concurrent.glb',
      source: ARModelAssetSource.network,
    );
    final store = cache(fetcher: fetcher);

    final firstFuture = store.resolve(asset);
    await fetcher.waitForFetch();
    final secondFuture = store.resolve(asset);
    expect(fetcher.fetchCount, 1);

    fetcher.complete();
    final first = await firstFuture;
    final second = await secondFuture;

    expect(first.status, ARModelAssetCacheStatus.cached);
    expect(second.status, ARModelAssetCacheStatus.cacheHit);
    expect(second.resolvedAsset.path, first.resolvedAsset.path);
    expect(fetcher.fetchCount, 1);
  });

  test('serializes concurrent resolves across cache instances', () async {
    final fetcher = _BlockingFetcher(<int>[10, 11, 12]);
    final asset = ARModelAsset.fromPath(
      'https://cdn.example.test/models/shared_lock.glb',
      source: ARModelAssetSource.network,
    );
    final firstStore = cache(fetcher: fetcher);
    final secondStore = cache(fetcher: fetcher);

    final firstFuture = firstStore.resolve(asset);
    await fetcher.waitForFetch();
    final secondFuture = secondStore.resolve(asset);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final fetchCountBeforeRelease = fetcher.fetchCount;

    fetcher.complete();
    final first = await firstFuture;
    final second = await secondFuture;

    expect(fetchCountBeforeRelease, 1);
    expect(first.status, ARModelAssetCacheStatus.cached);
    expect(second.status, ARModelAssetCacheStatus.cacheHit);
    expect(second.resolvedAsset.path, first.resolvedAsset.path);
    expect(fetcher.fetchCount, 1);
  });

  test('continues queued cache operations after a failed operation', () async {
    final store = cache();

    await expectLater(
      store.prune(
        policy: const ARModelAssetCachePrunePolicy(
          maxAge: Duration(days: -1),
        ),
      ),
      throwsArgumentError,
    );
    final result = await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'after_failed_operation.obj',
      contents: 'recovered',
    );

    expect(result.status, ARModelAssetCacheStatus.cached);
    expect((await store.inspect()).entryCount, 1);
  });

  test(
    'reports missing local file sources without creating a cached asset',
    () async {
      final asset = ARModelAsset.fromPath(
        '${tempDir.path}/missing.obj',
        source: ARModelAssetSource.file,
      );

      final result = await cache().resolve(asset);

      expect(result.status, ARModelAssetCacheStatus.missingSource);
      expect(result.isResolved, isFalse);
      expect(result.resolvedAsset, asset);
      expect(result.errorMessage, 'Model source file does not exist.');
      expect(await cacheDir.exists(), isTrue);
      expect((await cache().inspect()).isEmpty, isTrue);
    },
  );

  test('clears cached model entries', () async {
    final source = File('${tempDir.path}/clear_marker.obj');
    await source.writeAsString('cached');
    final asset = ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
    );
    final store = cache();

    await store.resolve(asset);
    expect((await store.inspect()).entryCount, 1);

    await store.clear();

    expect(await cacheDir.exists(), isFalse);
    expect((await store.inspect()).entryCount, 0);
  });

  test('prunes stale cached model entries by age', () async {
    now = DateTime.utc(2026, 5, 26, 9, 30);
    final stale = await _cacheLocalModel(
      store: cache(),
      tempDir: tempDir,
      filename: 'stale_marker.obj',
      contents: 'stale model',
    );
    now = DateTime.utc(2026, 6, 4, 9, 30);
    final fresh = await _cacheLocalModel(
      store: cache(),
      tempDir: tempDir,
      filename: 'fresh_marker.obj',
      contents: 'fresh model',
    );
    now = DateTime.utc(2026, 6, 5, 9, 30);
    final store = cache();

    final result = await store.prune(
      policy: const ARModelAssetCachePrunePolicy(
        maxAge: Duration(days: 7),
      ),
    );

    expect(result.didPrune, isTrue);
    expect(result.removedEntryCount, 1);
    expect(result.removedPaths, [stale.resolvedAsset.path]);
    expect(result.beforeStats.entryCount, 2);
    expect(result.afterStats.entryCount, 1);
    expect(result.summaryLabel, 'Pruned 1 model cache entry');
    expect(await File(stale.resolvedAsset.path).exists(), isFalse);
    expect(await _manifestFile(stale).exists(), isFalse);
    expect(await File(fresh.resolvedAsset.path).exists(), isTrue);
    expect(await _manifestFile(fresh).exists(), isTrue);
  });

  test('prunes oldest cached model entries by count and bytes', () async {
    final store = cache();
    now = DateTime.utc(2026, 6, 2, 9, 30);
    final oldest = await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'oldest_marker.obj',
      contents: '12345678',
    );
    now = DateTime.utc(2026, 6, 3, 9, 30);
    final middle = await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'middle_marker.obj',
      contents: '123456',
    );
    now = DateTime.utc(2026, 6, 4, 9, 30);
    final newest = await _cacheLocalModel(
      store: store,
      tempDir: tempDir,
      filename: 'newest_marker.obj',
      contents: '1234',
    );
    now = DateTime.utc(2026, 6, 5, 9, 30);

    final result = await store.prune(
      policy: const ARModelAssetCachePrunePolicy(
        maxEntries: 2,
        maxBytes: 10,
      ),
    );

    expect(result.removedPaths, [oldest.resolvedAsset.path]);
    expect(result.removedByteLength, 8);
    expect(result.beforeStats.entryCount, 3);
    expect(result.beforeStats.byteLength, 18);
    expect(result.afterStats.entryCount, 2);
    expect(result.afterStats.byteLength, 10);
    expect(await File(oldest.resolvedAsset.path).exists(), isFalse);
    expect(await _manifestFile(oldest).exists(), isFalse);
    expect(await File(middle.resolvedAsset.path).exists(), isTrue);
    expect(await File(newest.resolvedAsset.path).exists(), isTrue);
    expect((await store.inspect()).entryCount, 2);
  });

  test('prune keeps recently hit cached model entries', () async {
    final store = cache();
    final firstSource = File('${tempDir.path}/recent_hit_marker.obj');
    final secondSource = File('${tempDir.path}/older_unused_marker.obj');
    await firstSource.writeAsString('recent');
    await secondSource.writeAsString('unused');
    final firstAsset = ARModelAsset.fromPath(
      firstSource.path,
      source: ARModelAssetSource.file,
    );
    final secondAsset = ARModelAsset.fromPath(
      secondSource.path,
      source: ARModelAssetSource.file,
    );
    final first = await store.resolve(firstAsset);
    final second = await store.resolve(secondAsset);
    await File(first.resolvedAsset.path).setLastModified(
      now.subtract(const Duration(days: 5)),
    );
    await File(second.resolvedAsset.path).setLastModified(
      now.subtract(const Duration(days: 2)),
    );

    now = DateTime.utc(2026, 6, 5, 12);
    final hit = await store.resolve(firstAsset);
    final result = await store.prune(
      policy: const ARModelAssetCachePrunePolicy(maxEntries: 1),
    );

    expect(hit.status, ARModelAssetCacheStatus.cacheHit);
    expect(result.removedPaths, [second.resolvedAsset.path]);
    expect(await File(first.resolvedAsset.path).exists(), isTrue);
    expect(await _manifestFile(first).exists(), isTrue);
    expect(await File(second.resolvedAsset.path).exists(), isFalse);
    expect(await _manifestFile(second).exists(), isFalse);
  });

  test('prune is a no-op for an empty cache', () async {
    final result = await cache().prune(
      policy: const ARModelAssetCachePrunePolicy(maxEntries: 2),
    );

    expect(result.didPrune, isFalse);
    expect(result.beforeStats.isEmpty, isTrue);
    expect(result.afterStats.isEmpty, isTrue);
    expect(
      result.summaryLabel,
      'Model cache already within retention policy',
    );
  });
}

Future<ARModelAssetCacheResult> _cacheLocalModel({
  required ARModelAssetCache store,
  required Directory tempDir,
  required String filename,
  required String contents,
}) async {
  final source = File('${tempDir.path}/$filename');
  await source.writeAsString(contents);
  return store.resolve(
    ARModelAsset.fromPath(
      source.path,
      source: ARModelAssetSource.file,
    ),
  );
}

Future<_IntegrityIssueFixture> _seedModelCacheIntegrityIssues({
  required ARModelAssetCache store,
  required Directory tempDir,
  required Directory cacheDir,
  required DateTime now,
}) async {
  final cached = await _cacheLocalModel(
    store: store,
    tempDir: tempDir,
    filename: 'tampered_marker.obj',
    contents: 'original',
  );
  final manifestFile = _manifestFile(cached);
  final manifest = await _manifestMap(cached);
  manifest['byteLength'] = 99;
  manifest['contentFingerprint'] = 'stale_fingerprint';
  manifest['format'] = 'custom';
  await manifestFile.writeAsString(jsonEncode(manifest));
  await File(cached.resolvedAsset.path).writeAsString('changed');

  await cacheDir.create(recursive: true);
  final unindexed = File('${cacheDir.path}/unindexed.obj');
  await unindexed.writeAsString('unindexed');
  final orphanManifest = ARModelAssetCacheEntryManifest(
    cacheKey: 'orphan_marker',
    sourcePath: '${tempDir.path}/orphan_source.obj',
    source: ARModelAssetSource.file.name,
    format: ARModelFormat.obj.name,
    resolvedPath: '${cacheDir.path}/missing_cached.obj',
    resolvedSource: ARModelAssetSource.file.name,
    createdAt: now,
    lastUsedAt: now,
  );
  final orphanManifestFile = File(
    '${cacheDir.path}/orphan_marker.manifest.json',
  );
  await orphanManifestFile.writeAsString(jsonEncode(orphanManifest.toMap()));

  return _IntegrityIssueFixture(
    cached: cached,
    unindexedFile: unindexed,
    orphanManifestFile: orphanManifestFile,
  );
}

class _IntegrityIssueFixture {
  const _IntegrityIssueFixture({
    required this.cached,
    required this.unindexedFile,
    required this.orphanManifestFile,
  });

  final ARModelAssetCacheResult cached;
  final File unindexedFile;
  final File orphanManifestFile;
}

File _manifestFile(ARModelAssetCacheResult result) {
  final localPath = result.localPath;
  if (localPath == null) {
    throw StateError('Cache result has no local path.');
  }
  final directory = File(localPath).parent.path;
  return File('$directory/${result.cacheKey}.manifest.json');
}

Future<Map<String, Object?>> _manifestMap(
  ARModelAssetCacheResult result,
) async {
  return Map<String, Object?>.from(
    jsonDecode(await _manifestFile(result).readAsString()) as Map,
  );
}

Future<List<String>> _temporaryFileNames(Directory directory) async {
  if (!await directory.exists()) {
    return const <String>[];
  }
  final names = <String>[];
  await for (final entity in directory.list()) {
    if (entity is File) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.contains('.tmp.')) {
        names.add(name);
      }
    }
  }
  names.sort();
  return names;
}

class _FakeFetcher implements ARModelAssetByteFetcher {
  _FakeFetcher(this.responses);

  final Map<String, List<int>> responses;
  var _fetchCount = 0;

  int get fetchCount => _fetchCount;

  @override
  Future<List<int>> fetch(Uri uri) async {
    _fetchCount += 1;
    final response = responses[uri.toString()];
    if (response == null) {
      throw StateError('No fake response for $uri');
    }
    return response;
  }
}

class _FakeMetadataFetcher implements ARModelAssetResponseMetadataFetcher {
  _FakeMetadataFetcher(this.responses);

  final Map<String, ARModelAssetFetchResult> responses;
  var _fetchCount = 0;

  int get fetchCount => _fetchCount;

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

class _BlockingFetcher implements ARModelAssetByteFetcher {
  _BlockingFetcher(this.response);

  final List<int> response;
  final _started = Completer<void>();
  final _release = Completer<void>();
  var _fetchCount = 0;

  int get fetchCount => _fetchCount;

  Future<void> waitForFetch() => _started.future;

  void complete() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }

  @override
  Future<List<int>> fetch(Uri uri) async {
    _fetchCount += 1;
    if (!_started.isCompleted) {
      _started.complete();
    }
    await _release.future;
    return response;
  }
}
