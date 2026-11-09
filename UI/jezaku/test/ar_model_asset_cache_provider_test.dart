import 'dart:convert';
import 'dart:io';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_model_cache/ar_model_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jejaku/features/ar_viewer/services/ar_model_asset_cache_provider.dart';
import 'package:jejaku/features/settings/states/settings_providers.dart';

void main() {
  late Directory tempDir;
  late Directory cacheDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'jejaku_app_model_cache_test_',
    );
    cacheDir = Directory('${tempDir.path}/model_cache');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer container({
    DateTime Function()? now,
    ARModelAssetByteFetcher fetcher = const HttpARModelAssetByteFetcher(),
    ARModelAssetCacheFreshnessPolicy? freshnessPolicy,
    ARModelAssetCachePrunePolicy? retentionPolicy,
  }) {
    return ProviderContainer(
      overrides: [
        arModelAssetCacheProvider.overrideWith((ref) {
          return ARModelAssetCache(
            cacheDirectory: cacheDir,
            fetcher: fetcher,
            now: now,
          );
        }),
        if (freshnessPolicy != null)
          arModelAssetCacheFreshnessPolicyProvider.overrideWithValue(
            freshnessPolicy,
          ),
        if (retentionPolicy != null)
          arModelAssetCacheRetentionPolicyProvider.overrideWithValue(
            retentionPolicy,
          ),
      ],
    );
  }

  ProviderContainer persistentContainer() {
    return ProviderContainer(
      overrides: [
        persistentARModelAssetCacheOverride(rootDirectory: cacheDir),
      ],
    );
  }

  test('persistent override uses the app model cache directory', () {
    final scoped = persistentContainer();
    addTearDown(scoped.dispose);

    final cache = scoped.read(arModelAssetCacheProvider);

    expect(cache.cacheDirectory.path, cacheDir.path);
  });

  test('model preflight provider uses app freshness policy', () {
    final scoped = container(
      freshnessPolicy: const ARModelAssetCacheFreshnessPolicy(
        networkMaxAge: Duration(hours: 2),
      ),
    );
    addTearDown(scoped.dispose);

    final preflight = scoped.read(arMemoryModelPreflightProvider);

    expect(preflight.freshnessPolicy.networkMaxAge, const Duration(hours: 2));
  });

  test('model cache stats refresh after cached files are cleared', () async {
    final scoped = container();
    addTearDown(scoped.dispose);
    final source = File('${tempDir.path}/cached_marker.obj');
    await source.writeAsString('o Cached\nv 0 0 0\n');
    final cache = scoped.read(arModelAssetCacheProvider);
    await cache.resolve(
      ARModelAsset.fromPath(
        source.path,
        source: ARModelAssetSource.file,
      ),
    );

    final firstStats = await scoped.read(
      arModelAssetCacheStatsProvider.future,
    );
    expect(firstStats.entryCount, 1);
    expect(firstStats.byteLength, source.lengthSync());

    scoped.read(appSettingsProvider.notifier).clearCachedMedia();
    await _waitForCacheClear(cache);
    scoped.read(arModelAssetCacheRevisionProvider.notifier).bump();
    final clearedStats = await scoped.refresh(
      arModelAssetCacheStatsProvider.future,
    );

    expect(clearedStats.entryCount, 0);
    expect(clearedStats.byteLength, 0);
  });

  test('model cache maintenance prunes entries and refreshes stats', () async {
    var clock = DateTime.utc(2026, 6, 1);
    final scoped = container(now: () => clock);
    addTearDown(scoped.dispose);
    final cache = scoped.read(arModelAssetCacheProvider);
    final firstSource = File('${tempDir.path}/old_marker.obj');
    final secondSource = File('${tempDir.path}/new_marker.obj');
    await firstSource.writeAsString('old model');
    await secondSource.writeAsString('new model');
    final first = await cache.resolve(
      ARModelAsset.fromPath(
        firstSource.path,
        source: ARModelAssetSource.file,
      ),
    );
    clock = DateTime.utc(2026, 6, 2);
    await cache.resolve(
      ARModelAsset.fromPath(
        secondSource.path,
        source: ARModelAssetSource.file,
      ),
    );
    clock = DateTime.utc(2026, 6, 5);

    final firstStats = await scoped.read(
      arModelAssetCacheStatsProvider.future,
    );
    final pruneResult = await scoped
        .read(arModelAssetCacheMaintenanceProvider)
        .prune(const ARModelAssetCachePrunePolicy(maxEntries: 1));
    final prunedStats = await scoped.refresh(
      arModelAssetCacheStatsProvider.future,
    );

    expect(firstStats.entryCount, 2);
    expect(pruneResult.removedEntryCount, 1);
    expect(pruneResult.removedPaths, [first.resolvedAsset.path]);
    expect(prunedStats.entryCount, 1);
  });

  test('model cache entries provider exposes manifest-backed entries',
      () async {
    var clock = DateTime.utc(2026, 6, 5, 8);
    final scoped = container(now: () => clock);
    addTearDown(scoped.dispose);
    final cache = scoped.read(arModelAssetCacheProvider);
    final firstSource = File('${tempDir.path}/first_entry.obj');
    final secondSource = File('${tempDir.path}/second_entry.obj');
    await firstSource.writeAsString('first model');
    await secondSource.writeAsString('second model');
    await cache.resolve(
      ARModelAsset.fromPath(
        firstSource.path,
        source: ARModelAssetSource.file,
      ),
    );
    clock = DateTime.utc(2026, 6, 5, 9);
    final second = await cache.resolve(
      ARModelAsset.fromPath(
        secondSource.path,
        source: ARModelAssetSource.file,
      ),
    );

    final entries = await scoped.read(
      arModelAssetCacheEntriesProvider.future,
    );

    expect(entries, hasLength(2));
    expect(entries.first.cacheKey, second.cacheKey);
    expect(entries.first.sourcePath, secondSource.path);
    expect(entries.first.hasManifest, isTrue);
    expect(entries.first.lastUsedAt, DateTime.utc(2026, 6, 5, 9));
  });

  test('model cache maintenance repairs manifests and refreshes entries',
      () async {
    final scoped = container();
    addTearDown(scoped.dispose);
    await cacheDir.create(recursive: true);
    final unindexed = File('${cacheDir.path}/unindexed_marker.obj');
    await unindexed.writeAsString('o Unindexed\nv 0 0 0\n');

    final beforeEntries = await scoped.read(
      arModelAssetCacheEntriesProvider.future,
    );
    final repairResult = await scoped
        .read(arModelAssetCacheMaintenanceProvider)
        .repairManifests();
    final afterEntries = await scoped.refresh(
      arModelAssetCacheEntriesProvider.future,
    );

    expect(beforeEntries.single.hasManifest, isFalse);
    expect(repairResult.didRepair, isTrue);
    expect(repairResult.repairedEntryCount, 1);
    expect(afterEntries.single.hasManifest, isTrue);
    expect(afterEntries.single.sourcePath, unindexed.path);
    expect(afterEntries.single.format, 'obj');
  });

  test('model cache integrity provider reports missing manifests', () async {
    final scoped = container();
    addTearDown(scoped.dispose);
    await cacheDir.create(recursive: true);
    final unindexed = File('${cacheDir.path}/integrity_unindexed.obj');
    await unindexed.writeAsString('o Integrity\nv 0 0 0\n');

    final report = await scoped.read(
      arModelAssetCacheIntegrityProvider.future,
    );

    expect(report.isHealthy, isFalse);
    expect(report.issueCount, 1);
    expect(
      report.countCode(ARModelAssetCacheIntegrityIssueCode.missingManifest),
      1,
    );
    expect(report.issues.single.path, unindexed.path);
  });

  test('model cache maintenance repairs integrity and refreshes report',
      () async {
    final scoped = container();
    addTearDown(scoped.dispose);
    final cache = scoped.read(arModelAssetCacheProvider);
    final source = File('${tempDir.path}/stale_integrity_marker.obj');
    await source.writeAsString('o Stale\nv 0 0 0\n');
    final cached = await cache.resolve(
      ARModelAsset.fromPath(
        source.path,
        source: ARModelAssetSource.file,
      ),
    );
    final manifestFile = File(
      '${cacheDir.path}/${cached.cacheKey}.manifest.json',
    );
    final manifest = Map<String, Object?>.from(
      jsonDecode(await manifestFile.readAsString()) as Map,
    );
    manifest['byteLength'] = 1000;
    await manifestFile.writeAsString(jsonEncode(manifest));

    final beforeReport = await scoped.read(
      arModelAssetCacheIntegrityProvider.future,
    );
    final repairResult = await scoped
        .read(arModelAssetCacheMaintenanceProvider)
        .repairIntegrity();
    final afterReport = await scoped.refresh(
      arModelAssetCacheIntegrityProvider.future,
    );

    expect(beforeReport.isHealthy, isFalse);
    expect(repairResult.didRepair, isTrue);
    expect(repairResult.repairedManifestCount, 1);
    expect(afterReport.isHealthy, isTrue);
  });

  test('startup prune applies the app retention policy once watched', () async {
    var clock = DateTime.utc(2026, 5, 1);
    final scoped = container(
      now: () => clock,
      retentionPolicy: const ARModelAssetCachePrunePolicy(
        maxAge: Duration(days: 30),
        maxEntries: 8,
        maxBytes: 1024 * 1024,
      ),
    );
    addTearDown(scoped.dispose);
    final cache = scoped.read(arModelAssetCacheProvider);
    final staleSource = File('${tempDir.path}/stale_marker.obj');
    final freshSource = File('${tempDir.path}/fresh_marker.obj');
    await staleSource.writeAsString('stale model');
    await freshSource.writeAsString('fresh model');
    final stale = await cache.resolve(
      ARModelAsset.fromPath(
        staleSource.path,
        source: ARModelAssetSource.file,
      ),
    );
    clock = DateTime.utc(2026, 6, 4);
    await cache.resolve(
      ARModelAsset.fromPath(
        freshSource.path,
        source: ARModelAssetSource.file,
      ),
    );
    clock = DateTime.utc(2026, 6, 5);

    final pruneResult = await scoped.read(
      arModelAssetCacheStartupPruneProvider.future,
    );
    final stats = await scoped.read(arModelAssetCacheStatsProvider.future);

    expect(pruneResult.removedPaths, [stale.resolvedAsset.path]);
    expect(stats.entryCount, 1);
  });

  test('startup maintenance repairs integrity before retention pruning',
      () async {
    var clock = DateTime.utc(2026, 5, 1);
    final scoped = container(
      now: () => clock,
      retentionPolicy: const ARModelAssetCachePrunePolicy(
        maxAge: Duration(days: 30),
      ),
    );
    addTearDown(scoped.dispose);
    final cache = scoped.read(arModelAssetCacheProvider);
    final staleSource = File('${tempDir.path}/startup_stale_marker.obj');
    final freshSource = File('${tempDir.path}/startup_fresh_marker.obj');
    await staleSource.writeAsString('stale model');
    await freshSource.writeAsString('fresh model');
    final stale = await cache.resolve(
      ARModelAsset.fromPath(
        staleSource.path,
        source: ARModelAssetSource.file,
      ),
    );
    clock = DateTime.utc(2026, 6, 4);
    final fresh = await cache.resolve(
      ARModelAsset.fromPath(
        freshSource.path,
        source: ARModelAssetSource.file,
      ),
    );
    await _tamperManifestByteLength(cacheDir, stale.cacheKey, 1000);
    await _tamperManifestByteLength(cacheDir, fresh.cacheKey, 1000);
    final temporaryFile = File('${cacheDir.path}/startup_partial.obj.tmp.1');
    await temporaryFile.writeAsString('partial model');
    clock = DateTime.utc(2026, 6, 5);

    final result = await scoped.read(
      arModelAssetCacheStartupMaintenanceProvider.future,
    );
    final stats = await scoped.read(arModelAssetCacheStatsProvider.future);
    final report = await scoped.read(arModelAssetCacheIntegrityProvider.future);
    final freshManifest = await _manifestMap(cacheDir, fresh.cacheKey);

    expect(result.didMaintain, isTrue);
    expect(result.temporaryFileCleanup.removedPaths, [temporaryFile.path]);
    expect(result.integrityRepair.repairedManifestCount, 2);
    expect(result.prune.removedPaths, [stale.resolvedAsset.path]);
    expect(
        result.summaryLabel, contains('Removed 1 model cache temporary file'));
    expect(result.summaryLabel, contains('Repaired 2 model cache manifests'));
    expect(result.summaryLabel, contains('Pruned 1 model cache entry'));
    expect(stats.entryCount, 1);
    expect(report.isHealthy, isTrue);
    expect(await temporaryFile.exists(), isFalse);
    expect(freshManifest['byteLength'], freshSource.lengthSync());
  });
}

Future<void> _waitForCacheClear(ARModelAssetCache cache) async {
  for (var attempt = 0; attempt < 10; attempt += 1) {
    final stats = await cache.inspect();
    if (stats.isEmpty) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _tamperManifestByteLength(
  Directory cacheDir,
  String cacheKey,
  int byteLength,
) async {
  final file = File('${cacheDir.path}/$cacheKey.manifest.json');
  final manifest = await _manifestMap(cacheDir, cacheKey);
  manifest['byteLength'] = byteLength;
  await file.writeAsString(jsonEncode(manifest));
}

Future<Map<String, Object?>> _manifestMap(
  Directory cacheDir,
  String cacheKey,
) async {
  return Map<String, Object?>.from(
    jsonDecode(
      await File('${cacheDir.path}/$cacheKey.manifest.json').readAsString(),
    ) as Map,
  );
}
