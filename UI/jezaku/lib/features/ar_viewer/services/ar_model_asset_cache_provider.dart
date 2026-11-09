import 'dart:io';

import 'package:ar_model_cache/ar_model_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

final arModelAssetCacheRevisionProvider =
    NotifierProvider<ARModelAssetCacheRevision, int>(
  ARModelAssetCacheRevision.new,
);

class ARModelAssetCacheRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state += 1;
  }
}

final arModelAssetCacheProvider = Provider<ARModelAssetCache>((ref) {
  return ARModelAssetCache(
    cacheDirectory: Directory(
      _joinPath(Directory.systemTemp.path, 'jejaku_ar_model_cache'),
    ),
  );
});

final arModelAssetCacheMaintenanceProvider =
    Provider<ARModelAssetCacheMaintenance>((ref) {
  return ARModelAssetCacheMaintenance(ref);
});

final arModelAssetCacheRetentionPolicyProvider =
    Provider<ARModelAssetCachePrunePolicy>((ref) {
  return const ARModelAssetCachePrunePolicy(
    maxAge: Duration(days: 30),
    maxEntries: 128,
    maxBytes: 512 * 1024 * 1024,
  );
});

final arModelAssetCacheFreshnessPolicyProvider =
    Provider<ARModelAssetCacheFreshnessPolicy>((ref) {
  return const ARModelAssetCacheFreshnessPolicy(
    networkMaxAge: Duration(hours: 24),
  );
});

final arModelAssetCacheStartupPruneProvider =
    FutureProvider<ARModelAssetCachePruneResult>((ref) {
  final policy = ref.watch(arModelAssetCacheRetentionPolicyProvider);
  return ref.watch(arModelAssetCacheMaintenanceProvider).prune(policy);
});

final arModelAssetCacheStartupMaintenanceProvider =
    FutureProvider<ARModelAssetCacheStartupMaintenanceResult>((ref) async {
  final maintenance = ref.watch(arModelAssetCacheMaintenanceProvider);
  final policy = ref.watch(arModelAssetCacheRetentionPolicyProvider);
  final temporaryFileCleanup = await maintenance.cleanupTemporaryFiles();
  final integrityRepair = await maintenance.repairIntegrity();
  final prune = await maintenance.prune(policy);
  return ARModelAssetCacheStartupMaintenanceResult(
    temporaryFileCleanup: temporaryFileCleanup,
    integrityRepair: integrityRepair,
    prune: prune,
  );
});

class ARModelAssetCacheStartupMaintenanceResult {
  const ARModelAssetCacheStartupMaintenanceResult({
    required this.temporaryFileCleanup,
    required this.integrityRepair,
    required this.prune,
  });

  final ARModelAssetCacheTemporaryFileCleanupResult temporaryFileCleanup;
  final ARModelAssetCacheIntegrityRepairResult integrityRepair;
  final ARModelAssetCachePruneResult prune;

  bool get didMaintain {
    return temporaryFileCleanup.didCleanup ||
        integrityRepair.didRepair ||
        prune.didPrune;
  }

  String get summaryLabel {
    if (!didMaintain) {
      return 'Model cache already maintained';
    }
    final labels = <String>[
      if (temporaryFileCleanup.didCleanup) temporaryFileCleanup.summaryLabel,
      if (integrityRepair.didRepair) integrityRepair.summaryLabel,
      if (prune.didPrune) prune.summaryLabel,
    ];
    return labels.join(', ');
  }

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'didMaintain': didMaintain,
      'summaryLabel': summaryLabel,
      'temporaryFileCleanup': temporaryFileCleanup.toMetadata(),
      'integrityRepair': integrityRepair.toMetadata(),
      'prune': prune.toMetadata(),
    };
  }
}

class ARModelAssetCacheMaintenance {
  const ARModelAssetCacheMaintenance(this._ref);

  final Ref _ref;

  Future<ARModelAssetCachePruneResult> prune(
    ARModelAssetCachePrunePolicy policy,
  ) async {
    final result = await _ref.read(arModelAssetCacheProvider).prune(
          policy: policy,
        );
    if (result.didPrune) {
      _ref.read(arModelAssetCacheRevisionProvider.notifier).bump();
    }
    return result;
  }

  Future<ARModelAssetCacheRepairResult> repairManifests() async {
    final result = await _ref.read(arModelAssetCacheProvider).repairManifests();
    if (result.didRepair) {
      _ref.read(arModelAssetCacheRevisionProvider.notifier).bump();
    }
    return result;
  }

  Future<ARModelAssetCacheIntegrityRepairResult> repairIntegrity() async {
    final result = await _ref.read(arModelAssetCacheProvider).repairIntegrity();
    if (result.didRepair) {
      _ref.read(arModelAssetCacheRevisionProvider.notifier).bump();
    }
    return result;
  }

  Future<ARModelAssetCacheTemporaryFileCleanupResult> cleanupTemporaryFiles({
    Duration minimumAge = Duration.zero,
  }) async {
    final result = await _ref
        .read(arModelAssetCacheProvider)
        .cleanupTemporaryFiles(minimumAge: minimumAge);
    if (result.didCleanup) {
      _ref.read(arModelAssetCacheRevisionProvider.notifier).bump();
    }
    return result;
  }
}

final arMemoryModelPreflightProvider =
    Provider<JejakuMemoryModelCachePreflight>((ref) {
  return JejakuMemoryModelCachePreflight(
    cache: ref.watch(arModelAssetCacheProvider),
    freshnessPolicy: ref.watch(arModelAssetCacheFreshnessPolicyProvider),
  );
});

final arModelAssetCacheStatsProvider =
    FutureProvider<ARModelAssetCacheStats>((ref) {
  ref.watch(arModelAssetCacheRevisionProvider);
  return ref.watch(arModelAssetCacheProvider).inspect();
});

final arModelAssetCacheEntriesProvider =
    FutureProvider<List<ARModelAssetCacheEntry>>((ref) {
  ref.watch(arModelAssetCacheRevisionProvider);
  return ref.watch(arModelAssetCacheProvider).inspectEntries();
});

final arModelAssetCacheIntegrityProvider =
    FutureProvider<ARModelAssetCacheIntegrityReport>((ref) {
  ref.watch(arModelAssetCacheRevisionProvider);
  return ref.watch(arModelAssetCacheProvider).inspectIntegrity();
});

persistentARModelAssetCacheOverride({
  required Directory rootDirectory,
}) {
  return arModelAssetCacheProvider.overrideWith((ref) {
    return ARModelAssetCache(cacheDirectory: rootDirectory);
  });
}

Directory arModelAssetCacheDirectory(Directory appSupportDirectory) {
  return Directory(_joinPath(appSupportDirectory.path, 'ar_model_cache'));
}

String _joinPath(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) {
    return '$parent$child';
  }
  return '$parent${Platform.pathSeparator}$child';
}
