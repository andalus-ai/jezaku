import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ar_engine/ar_engine.dart';

abstract interface class ARModelAssetByteFetcher {
  Future<List<int>> fetch(Uri uri);
}

abstract interface class ARModelAssetResponseMetadataFetcher
    implements ARModelAssetByteFetcher {
  Future<ARModelAssetFetchResult> fetchWithMetadata(Uri uri);
}

abstract interface class ARModelAssetConditionalFetcher
    implements ARModelAssetResponseMetadataFetcher {
  Future<ARModelAssetRevalidationResult> revalidate(
    Uri uri,
    ARModelAssetRevalidationRequest request,
  );
}

class ARModelAssetFetchResult {
  const ARModelAssetFetchResult({
    required this.bytes,
    this.networkMetadata,
  });

  final List<int> bytes;
  final ARModelAssetNetworkMetadata? networkMetadata;
}

class ARModelAssetRevalidationRequest {
  const ARModelAssetRevalidationRequest({
    this.eTag,
    this.lastModified,
  });

  factory ARModelAssetRevalidationRequest.fromMetadata(
    ARModelAssetNetworkMetadata? metadata,
  ) {
    return ARModelAssetRevalidationRequest(
      eTag: metadata?.eTag,
      lastModified: metadata?.lastModified,
    );
  }

  final String? eTag;
  final DateTime? lastModified;

  bool get hasValidators => eTag != null || lastModified != null;

  Map<String, String> get headers {
    final headers = <String, String>{};
    final validatorETag = eTag;
    final validatorLastModified = lastModified;
    if (validatorETag != null) {
      headers['if-none-match'] = validatorETag;
    }
    if (validatorLastModified != null) {
      headers['if-modified-since'] = HttpDate.format(
        validatorLastModified.toUtc(),
      );
    }
    return Map<String, String>.unmodifiable(headers);
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'eTag': eTag,
        'lastModified': lastModified?.toUtc().toIso8601String(),
        'headers': headers,
      };
}

class ARModelAssetRevalidationResult {
  const ARModelAssetRevalidationResult({
    this.bytes,
    this.networkMetadata,
    this.notModified = false,
  }) : assert(notModified || bytes != null);

  factory ARModelAssetRevalidationResult.fetched({
    required List<int> bytes,
    ARModelAssetNetworkMetadata? networkMetadata,
  }) {
    return ARModelAssetRevalidationResult(
      bytes: bytes,
      networkMetadata: networkMetadata,
    );
  }

  factory ARModelAssetRevalidationResult.notModified({
    ARModelAssetNetworkMetadata? networkMetadata,
  }) {
    return ARModelAssetRevalidationResult(
      networkMetadata: networkMetadata,
      notModified: true,
    );
  }

  final List<int>? bytes;
  final ARModelAssetNetworkMetadata? networkMetadata;
  final bool notModified;
}

class ARModelAssetNetworkMetadata {
  const ARModelAssetNetworkMetadata({
    this.responseUri,
    this.contentType,
    this.eTag,
    this.lastModified,
    this.contentLength,
    this.fetchedAt,
  });

  factory ARModelAssetNetworkMetadata.fromMap(Map<dynamic, dynamic> map) {
    return ARModelAssetNetworkMetadata(
      responseUri: _nullableString(map['responseUri']),
      contentType: _nullableString(map['contentType']),
      eTag: _nullableString(map['eTag']),
      lastModified: _nullableDateTime(map['lastModified']),
      contentLength: _nullableInt(map['contentLength']),
      fetchedAt: _nullableDateTime(map['fetchedAt']),
    );
  }

  final String? responseUri;
  final String? contentType;
  final String? eTag;
  final DateTime? lastModified;
  final int? contentLength;
  final DateTime? fetchedAt;

  bool get isEmpty {
    return responseUri == null &&
        contentType == null &&
        eTag == null &&
        lastModified == null &&
        contentLength == null &&
        fetchedAt == null;
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'responseUri': responseUri,
        'contentType': contentType,
        'eTag': eTag,
        'lastModified': lastModified?.toUtc().toIso8601String(),
        'contentLength': contentLength,
        'fetchedAt': fetchedAt?.toUtc().toIso8601String(),
      };

  ARModelAssetNetworkMetadata copyWith({
    String? responseUri,
    String? contentType,
    String? eTag,
    DateTime? lastModified,
    int? contentLength,
    DateTime? fetchedAt,
  }) {
    return ARModelAssetNetworkMetadata(
      responseUri: responseUri ?? this.responseUri,
      contentType: contentType ?? this.contentType,
      eTag: eTag ?? this.eTag,
      lastModified: lastModified ?? this.lastModified,
      contentLength: contentLength ?? this.contentLength,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  ARModelAssetNetworkMetadata mergeWithFallback(
    ARModelAssetNetworkMetadata? fallback,
  ) {
    return ARModelAssetNetworkMetadata(
      responseUri: responseUri ?? fallback?.responseUri,
      contentType: contentType ?? fallback?.contentType,
      eTag: eTag ?? fallback?.eTag,
      lastModified: lastModified ?? fallback?.lastModified,
      contentLength: contentLength ?? fallback?.contentLength,
      fetchedAt: fetchedAt ?? fallback?.fetchedAt,
    );
  }
}

class HttpARModelAssetByteFetcher implements ARModelAssetConditionalFetcher {
  const HttpARModelAssetByteFetcher();

  @override
  Future<List<int>> fetch(Uri uri) async {
    return (await fetchWithMetadata(uri)).bytes;
  }

  @override
  Future<ARModelAssetFetchResult> fetchWithMetadata(Uri uri) async {
    final result = await _fetch(uri);
    final bytes = result.bytes;
    if (bytes == null) {
      throw StateError('Model download did not return bytes.');
    }
    return ARModelAssetFetchResult(
      bytes: bytes,
      networkMetadata: result.networkMetadata,
    );
  }

  @override
  Future<ARModelAssetRevalidationResult> revalidate(
    Uri uri,
    ARModelAssetRevalidationRequest request,
  ) {
    return _fetch(
      uri,
      revalidationRequest: request.hasValidators ? request : null,
    );
  }

  Future<ARModelAssetRevalidationResult> _fetch(
    Uri uri, {
    ARModelAssetRevalidationRequest? revalidationRequest,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      for (final header in revalidationRequest?.headers.entries ??
          const Iterable<MapEntry<String, String>>.empty()) {
        request.headers.set(header.key, header.value);
      }
      final response = await request.close();
      if (response.statusCode == HttpStatus.notModified &&
          revalidationRequest != null) {
        await response.drain<void>();
        return ARModelAssetRevalidationResult.notModified(
          networkMetadata: _networkMetadataForResponse(
            response,
            uri,
            includeContentLength: false,
          ),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Model download failed with HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
      }
      return ARModelAssetRevalidationResult.fetched(
        bytes: bytes.takeBytes(),
        networkMetadata: _networkMetadataForResponse(
          response,
          uri,
          includeContentLength: true,
        ),
      );
    } finally {
      client.close(force: true);
    }
  }
}

enum ARModelAssetCacheStatus {
  passthrough,
  cached,
  cacheHit,
  missingSource,
  failed;

  String get label {
    return switch (this) {
      ARModelAssetCacheStatus.passthrough => 'Model cache not required',
      ARModelAssetCacheStatus.cached => 'Model cached',
      ARModelAssetCacheStatus.cacheHit => 'Model cache hit',
      ARModelAssetCacheStatus.missingSource => 'Model source missing',
      ARModelAssetCacheStatus.failed => 'Model cache failed',
    };
  }
}

class ARModelAssetCacheResult {
  const ARModelAssetCacheResult({
    required this.sourceAsset,
    required this.resolvedAsset,
    required this.validationReport,
    required this.status,
    required this.cacheKey,
    required this.resolvedAt,
    this.localPath,
    this.byteLength,
    this.contentFingerprint,
    this.errorMessage,
    this.manifest,
    this.networkMetadata,
    this.wasRevalidated = false,
    this.usedStaleCacheOnError = false,
  });

  final ARModelAsset sourceAsset;
  final ARModelAsset resolvedAsset;
  final ARModelAssetValidationReport validationReport;
  final ARModelAssetCacheStatus status;
  final String cacheKey;
  final DateTime resolvedAt;
  final String? localPath;
  final int? byteLength;
  final String? contentFingerprint;
  final String? errorMessage;
  final ARModelAssetCacheEntryManifest? manifest;
  final ARModelAssetNetworkMetadata? networkMetadata;
  final bool wasRevalidated;
  final bool usedStaleCacheOnError;

  bool get isResolved {
    return switch (status) {
      ARModelAssetCacheStatus.passthrough ||
      ARModelAssetCacheStatus.cached ||
      ARModelAssetCacheStatus.cacheHit =>
        true,
      ARModelAssetCacheStatus.missingSource ||
      ARModelAssetCacheStatus.failed =>
        false,
    };
  }

  bool get isCacheHit => status == ARModelAssetCacheStatus.cacheHit;

  bool get didWriteCache => status == ARModelAssetCacheStatus.cached;

  String get statusLabel => status.label;

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'status': status.name,
      'statusLabel': statusLabel,
      'isResolved': isResolved,
      'cacheKey': cacheKey,
      'localPath': localPath,
      'byteLength': byteLength,
      'contentFingerprint': contentFingerprint,
      'networkMetadata': networkMetadata?.toMap(),
      'wasRevalidated': wasRevalidated,
      'usedStaleCacheOnError': usedStaleCacheOnError,
      'sourcePath': sourceAsset.path,
      'source': sourceAsset.source.name,
      'resolvedPath': resolvedAsset.path,
      'resolvedSource': resolvedAsset.source.name,
      'resolvedAt': resolvedAt.toUtc().toIso8601String(),
      'errorMessage': errorMessage,
      'manifest': manifest?.toMap(),
    };
  }
}

class ARModelAssetCacheStats {
  const ARModelAssetCacheStats({
    required this.entryCount,
    required this.byteLength,
  });

  final int entryCount;
  final int byteLength;

  bool get isEmpty => entryCount == 0;

  String get sizeLabel {
    if (byteLength < 1024) {
      return '$byteLength B';
    }
    if (byteLength < 1024 * 1024) {
      return '${(byteLength / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ARModelAssetCacheFreshnessPolicy {
  const ARModelAssetCacheFreshnessPolicy({
    this.networkMaxAge,
  });

  static const none = ARModelAssetCacheFreshnessPolicy();

  final Duration? networkMaxAge;

  bool get isNoop => networkMaxAge == null;
}

class ARModelAssetCacheEntry {
  const ARModelAssetCacheEntry({
    required this.cacheKey,
    required this.path,
    required this.manifestPath,
    required this.byteLength,
    required this.modifiedAt,
    this.manifest,
  });

  final String cacheKey;
  final String path;
  final String manifestPath;
  final int byteLength;
  final DateTime modifiedAt;
  final ARModelAssetCacheEntryManifest? manifest;

  bool get hasManifest => manifest != null;

  DateTime get lastUsedAt => manifest?.lastUsedAt ?? modifiedAt;

  DateTime? get createdAt => manifest?.createdAt;

  String? get sourcePath => manifest?.sourcePath;

  String? get source => manifest?.source;

  String? get format => manifest?.format;

  String? get contentFingerprint => manifest?.contentFingerprint;

  int? get sourceByteLength => manifest?.sourceByteLength;

  DateTime? get sourceModifiedAt => manifest?.sourceModifiedAt;

  String? get sourceContentFingerprint => manifest?.sourceContentFingerprint;

  ARModelAssetNetworkMetadata? get networkMetadata => manifest?.networkMetadata;

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'cacheKey': cacheKey,
      'path': path,
      'manifestPath': manifestPath,
      'byteLength': byteLength,
      'modifiedAt': modifiedAt.toUtc().toIso8601String(),
      'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
      'hasManifest': hasManifest,
      'sourcePath': sourcePath,
      'source': source,
      'format': format,
      'contentFingerprint': contentFingerprint,
      'sourceByteLength': sourceByteLength,
      'sourceModifiedAt': sourceModifiedAt?.toUtc().toIso8601String(),
      'sourceContentFingerprint': sourceContentFingerprint,
      'networkMetadata': networkMetadata?.toMap(),
      'manifest': manifest?.toMap(),
    };
  }
}

class ARModelAssetCachePrunePolicy {
  const ARModelAssetCachePrunePolicy({
    this.maxEntries,
    this.maxBytes,
    this.maxAge,
  })  : assert(maxEntries == null || maxEntries >= 0),
        assert(maxBytes == null || maxBytes >= 0);

  final int? maxEntries;
  final int? maxBytes;
  final Duration? maxAge;

  bool get isNoop => maxEntries == null && maxBytes == null && maxAge == null;
}

class ARModelAssetCachePruneResult {
  const ARModelAssetCachePruneResult({
    required this.beforeStats,
    required this.afterStats,
    this.removedPaths = const <String>[],
    this.removedByteLength = 0,
  });

  final ARModelAssetCacheStats beforeStats;
  final ARModelAssetCacheStats afterStats;
  final List<String> removedPaths;
  final int removedByteLength;

  int get removedEntryCount => removedPaths.length;

  bool get didPrune => removedEntryCount > 0;

  String get summaryLabel {
    if (!didPrune) {
      return 'Model cache already within retention policy';
    }
    final entryLabel = removedEntryCount == 1 ? 'entry' : 'entries';
    return 'Pruned $removedEntryCount model cache $entryLabel';
  }

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'removedEntryCount': removedEntryCount,
      'removedByteLength': removedByteLength,
      'removedPaths': removedPaths,
      'beforeEntryCount': beforeStats.entryCount,
      'beforeByteLength': beforeStats.byteLength,
      'afterEntryCount': afterStats.entryCount,
      'afterByteLength': afterStats.byteLength,
      'summaryLabel': summaryLabel,
    };
  }
}

class ARModelAssetCacheTemporaryFileCleanupResult {
  const ARModelAssetCacheTemporaryFileCleanupResult({
    this.removedPaths = const <String>[],
    this.skippedPaths = const <String>[],
    this.removedByteLength = 0,
  });

  final List<String> removedPaths;
  final List<String> skippedPaths;
  final int removedByteLength;

  int get removedFileCount => removedPaths.length;

  int get skippedFileCount => skippedPaths.length;

  bool get didCleanup => removedFileCount > 0;

  String get summaryLabel {
    if (!didCleanup && skippedFileCount == 0) {
      return 'Model cache temporary files already clean';
    }
    final fileLabel = removedFileCount == 1 ? 'file' : 'files';
    if (skippedFileCount == 0) {
      return 'Removed $removedFileCount model cache temporary $fileLabel';
    }
    return 'Removed $removedFileCount model cache temporary $fileLabel, '
        'skipped $skippedFileCount';
  }

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'removedFileCount': removedFileCount,
      'skippedFileCount': skippedFileCount,
      'removedByteLength': removedByteLength,
      'removedPaths': removedPaths,
      'skippedPaths': skippedPaths,
      'summaryLabel': summaryLabel,
    };
  }
}

class ARModelAssetCacheRepairResult {
  const ARModelAssetCacheRepairResult({
    required this.beforeStats,
    required this.afterStats,
    this.repairedManifestPaths = const <String>[],
    this.skippedPaths = const <String>[],
  });

  final ARModelAssetCacheStats beforeStats;
  final ARModelAssetCacheStats afterStats;
  final List<String> repairedManifestPaths;
  final List<String> skippedPaths;

  int get repairedEntryCount => repairedManifestPaths.length;

  int get skippedEntryCount => skippedPaths.length;

  bool get didRepair => repairedEntryCount > 0;

  String get summaryLabel {
    if (!didRepair && skippedEntryCount == 0) {
      return 'Model cache manifests already healthy';
    }
    final repairedLabel = repairedEntryCount == 1 ? 'manifest' : 'manifests';
    if (skippedEntryCount == 0) {
      return 'Repaired $repairedEntryCount model cache $repairedLabel';
    }
    return 'Repaired $repairedEntryCount model cache $repairedLabel, '
        'skipped $skippedEntryCount';
  }

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'repairedEntryCount': repairedEntryCount,
      'skippedEntryCount': skippedEntryCount,
      'repairedManifestPaths': repairedManifestPaths,
      'skippedPaths': skippedPaths,
      'beforeEntryCount': beforeStats.entryCount,
      'beforeByteLength': beforeStats.byteLength,
      'afterEntryCount': afterStats.entryCount,
      'afterByteLength': afterStats.byteLength,
      'summaryLabel': summaryLabel,
    };
  }
}

class ARModelAssetCacheIntegrityRepairResult {
  const ARModelAssetCacheIntegrityRepairResult({
    required this.beforeReport,
    required this.afterReport,
    this.repairedManifestPaths = const <String>[],
    this.removedManifestPaths = const <String>[],
    this.skippedPaths = const <String>[],
  });

  final ARModelAssetCacheIntegrityReport beforeReport;
  final ARModelAssetCacheIntegrityReport afterReport;
  final List<String> repairedManifestPaths;
  final List<String> removedManifestPaths;
  final List<String> skippedPaths;

  int get repairedManifestCount => repairedManifestPaths.length;

  int get removedManifestCount => removedManifestPaths.length;

  int get skippedCount => skippedPaths.length;

  bool get didRepair => repairedManifestCount > 0 || removedManifestCount > 0;

  bool get isFullyRepaired => afterReport.isHealthy;

  String get summaryLabel {
    if (!didRepair && skippedCount == 0) {
      return beforeReport.isHealthy
          ? 'Model cache integrity already healthy'
          : 'Model cache integrity unchanged';
    }
    final actions = <String>[
      if (repairedManifestCount > 0)
        'Repaired $repairedManifestCount model cache '
            '${repairedManifestCount == 1 ? 'manifest' : 'manifests'}',
      if (removedManifestCount > 0)
        'Removed $removedManifestCount stale model cache '
            '${removedManifestCount == 1 ? 'manifest' : 'manifests'}',
      if (skippedCount > 0)
        'Skipped $skippedCount model cache '
            '${skippedCount == 1 ? 'repair' : 'repairs'}',
    ];
    return actions.join(', ');
  }

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'repairedManifestCount': repairedManifestCount,
      'removedManifestCount': removedManifestCount,
      'skippedCount': skippedCount,
      'isFullyRepaired': isFullyRepaired,
      'repairedManifestPaths': repairedManifestPaths,
      'removedManifestPaths': removedManifestPaths,
      'skippedPaths': skippedPaths,
      'beforeReport': beforeReport.toMetadata(),
      'afterReport': afterReport.toMetadata(),
      'summaryLabel': summaryLabel,
    };
  }
}

enum ARModelAssetCacheIntegrityIssueCode {
  missingManifest,
  orphanManifest,
  manifestMissingFile,
  byteLengthMismatch,
  contentFingerprintMismatch,
  unsupportedFormat,
}

class ARModelAssetCacheIntegrityIssue {
  const ARModelAssetCacheIntegrityIssue({
    required this.code,
    required this.cacheKey,
    required this.label,
    this.path,
    this.manifestPath,
    this.expected,
    this.actual,
  });

  final ARModelAssetCacheIntegrityIssueCode code;
  final String cacheKey;
  final String label;
  final String? path;
  final String? manifestPath;
  final Object? expected;
  final Object? actual;

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'code': code.name,
      'cacheKey': cacheKey,
      'label': label,
      'path': path,
      'manifestPath': manifestPath,
      'expected': expected,
      'actual': actual,
    };
  }
}

class ARModelAssetCacheIntegrityReport {
  const ARModelAssetCacheIntegrityReport({
    required this.stats,
    required this.issues,
  });

  final ARModelAssetCacheStats stats;
  final List<ARModelAssetCacheIntegrityIssue> issues;

  bool get isHealthy => issues.isEmpty;

  int get issueCount => issues.length;

  String get summaryLabel {
    if (isHealthy) {
      return 'Model cache healthy';
    }
    final label = issueCount == 1 ? 'issue' : 'issues';
    return 'Model cache has $issueCount integrity $label';
  }

  int countCode(ARModelAssetCacheIntegrityIssueCode code) {
    return issues.where((issue) => issue.code == code).length;
  }

  Map<String, Object?> toMetadata() {
    return <String, Object?>{
      'schemaVersion': 1,
      'summaryLabel': summaryLabel,
      'isHealthy': isHealthy,
      'issueCount': issueCount,
      'entryCount': stats.entryCount,
      'byteLength': stats.byteLength,
      'issueCounts': <String, Object?>{
        for (final code in ARModelAssetCacheIntegrityIssueCode.values)
          code.name: countCode(code),
      },
      'issues': [
        for (final issue in issues) issue.toMetadata(),
      ],
    };
  }
}

class ARModelAssetCacheEntryManifest {
  const ARModelAssetCacheEntryManifest({
    required this.cacheKey,
    required this.sourcePath,
    required this.source,
    required this.format,
    required this.resolvedPath,
    required this.resolvedSource,
    required this.createdAt,
    required this.lastUsedAt,
    this.package,
    this.byteLength,
    this.contentFingerprint,
    this.sourceByteLength,
    this.sourceModifiedAt,
    this.sourceContentFingerprint,
    this.networkMetadata,
    this.validation = const <String, Object?>{},
    this.renderProfile = const <String, Object?>{},
  });

  factory ARModelAssetCacheEntryManifest.fromMap(Map<dynamic, dynamic> map) {
    return ARModelAssetCacheEntryManifest(
      cacheKey: _string(map['cacheKey']),
      sourcePath: _string(map['sourcePath']),
      source: _string(map['source']),
      format: _string(map['format']),
      package: _nullableString(map['package']),
      resolvedPath: _string(map['resolvedPath']),
      resolvedSource: _string(map['resolvedSource']),
      byteLength: _nullableInt(map['byteLength']),
      contentFingerprint: _nullableString(map['contentFingerprint']),
      sourceByteLength: _nullableInt(map['sourceByteLength']),
      sourceModifiedAt: _nullableDateTime(map['sourceModifiedAt']),
      sourceContentFingerprint: _nullableString(
        map['sourceContentFingerprint'],
      ),
      networkMetadata: _networkMetadata(map['networkMetadata']),
      createdAt: _dateTime(map['createdAt']),
      lastUsedAt: _dateTime(map['lastUsedAt']),
      validation: _objectMap(map['validation']),
      renderProfile: _objectMap(map['renderProfile']),
    );
  }

  final String cacheKey;
  final String sourcePath;
  final String source;
  final String format;
  final String? package;
  final String resolvedPath;
  final String resolvedSource;
  final int? byteLength;
  final String? contentFingerprint;
  final int? sourceByteLength;
  final DateTime? sourceModifiedAt;
  final String? sourceContentFingerprint;
  final ARModelAssetNetworkMetadata? networkMetadata;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final Map<String, Object?> validation;
  final Map<String, Object?> renderProfile;

  Map<String, Object?> toMap() => <String, Object?>{
        'schemaVersion': 1,
        'cacheKey': cacheKey,
        'sourcePath': sourcePath,
        'source': source,
        'format': format,
        'package': package,
        'resolvedPath': resolvedPath,
        'resolvedSource': resolvedSource,
        'byteLength': byteLength,
        'contentFingerprint': contentFingerprint,
        'sourceByteLength': sourceByteLength,
        'sourceModifiedAt': sourceModifiedAt?.toUtc().toIso8601String(),
        'sourceContentFingerprint': sourceContentFingerprint,
        'networkMetadata': networkMetadata?.toMap(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'lastUsedAt': lastUsedAt.toUtc().toIso8601String(),
        'validation': validation,
        'renderProfile': renderProfile,
      };

  ARModelAssetCacheEntryManifest copyWith({
    DateTime? lastUsedAt,
    int? byteLength,
    String? contentFingerprint,
    int? sourceByteLength,
    DateTime? sourceModifiedAt,
    String? sourceContentFingerprint,
    ARModelAssetNetworkMetadata? networkMetadata,
    Map<String, Object?>? validation,
    Map<String, Object?>? renderProfile,
    String? resolvedPath,
    String? resolvedSource,
  }) {
    return ARModelAssetCacheEntryManifest(
      cacheKey: cacheKey,
      sourcePath: sourcePath,
      source: source,
      format: format,
      package: package,
      resolvedPath: resolvedPath ?? this.resolvedPath,
      resolvedSource: resolvedSource ?? this.resolvedSource,
      byteLength: byteLength ?? this.byteLength,
      contentFingerprint: contentFingerprint ?? this.contentFingerprint,
      sourceByteLength: sourceByteLength ?? this.sourceByteLength,
      sourceModifiedAt: sourceModifiedAt ?? this.sourceModifiedAt,
      sourceContentFingerprint:
          sourceContentFingerprint ?? this.sourceContentFingerprint,
      networkMetadata: networkMetadata ?? this.networkMetadata,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      validation: validation ?? this.validation,
      renderProfile: renderProfile ?? this.renderProfile,
    );
  }
}

class ARModelAssetCache {
  ARModelAssetCache({
    required Directory cacheDirectory,
    ARModelAssetByteFetcher fetcher = const HttpARModelAssetByteFetcher(),
    DateTime Function()? now,
  })  : _cacheDirectory = cacheDirectory,
        _fetcher = fetcher,
        _now = now ?? DateTime.now;

  final Directory _cacheDirectory;
  final ARModelAssetByteFetcher _fetcher;
  final DateTime Function() _now;
  final _CacheOperationQueue _operations = _CacheOperationQueue();

  Directory get cacheDirectory => _cacheDirectory;

  Future<ARModelAssetCacheResult> resolve(
    ARModelAsset asset, {
    bool refresh = false,
    ARModelAssetCacheFreshnessPolicy freshnessPolicy =
        ARModelAssetCacheFreshnessPolicy.none,
  }) async {
    _validateFreshnessPolicy(freshnessPolicy);
    if (!_requiresCache(asset)) {
      return _resolve(
        asset,
        refresh: refresh,
        freshnessPolicy: freshnessPolicy,
      );
    }
    return _operations.run(
      () => _withCacheLock(
        () => _resolve(
          asset,
          refresh: refresh,
          freshnessPolicy: freshnessPolicy,
        ),
      ),
    );
  }

  Future<ARModelAssetCacheResult> _resolve(
    ARModelAsset asset, {
    required bool refresh,
    required ARModelAssetCacheFreshnessPolicy freshnessPolicy,
  }) async {
    final resolvedAt = _now();
    final cacheKey = cacheKeyFor(asset);
    if (!_requiresCache(asset)) {
      return ARModelAssetCacheResult(
        sourceAsset: asset,
        resolvedAsset: asset,
        validationReport: asset.validate(),
        status: ARModelAssetCacheStatus.passthrough,
        cacheKey: cacheKey,
        resolvedAt: resolvedAt,
      );
    }

    await _cacheDirectory.create(recursive: true);
    final targetFile = File(_cachePathFor(asset, cacheKey));
    final hasCachedFile = await targetFile.exists();
    var shouldRefreshNetworkCacheHit = false;
    if (!refresh && hasCachedFile) {
      final shouldRefresh = switch (asset.source) {
        ARModelAssetSource.file => await _shouldRefreshLocalCacheHit(
            asset,
            targetFile,
            cacheKey,
          ),
        ARModelAssetSource.network => shouldRefreshNetworkCacheHit =
              await _shouldRefreshNetworkCacheHit(
            asset,
            cacheKey,
            freshnessPolicy: freshnessPolicy,
            checkedAt: resolvedAt,
          ),
        ARModelAssetSource.flutterAsset || ARModelAssetSource.bundle => false,
      };
      if (!shouldRefresh) {
        await _touchCacheEntry(targetFile, resolvedAt);
        return _cachedResult(
          sourceAsset: asset,
          localPath: targetFile.path,
          status: ARModelAssetCacheStatus.cacheHit,
          cacheKey: cacheKey,
          resolvedAt: resolvedAt,
        );
      }
    }

    try {
      final shouldRevalidateNetwork =
          (refresh || shouldRefreshNetworkCacheHit) &&
              hasCachedFile &&
              asset.source == ARModelAssetSource.network;
      final revalidationMetadata = shouldRevalidateNetwork
          ? (await _readManifest(cacheKey))?.networkMetadata
          : null;
      final readResult = switch (asset.source) {
        ARModelAssetSource.file => _ModelReadResult(
            bytes: await _readLocalFile(asset),
          ),
        ARModelAssetSource.network => await _readNetworkFile(
            asset,
            revalidationMetadata: revalidationMetadata,
          ),
        ARModelAssetSource.flutterAsset ||
        ARModelAssetSource.bundle =>
          const _ModelReadResult(bytes: <int>[]),
      };
      if (readResult.notModified) {
        if (!hasCachedFile) {
          throw StateError(
            'Model cache revalidation returned not modified without a '
            'cached file.',
          );
        }
        await _touchCacheEntry(targetFile, resolvedAt);
        return _cachedResult(
          sourceAsset: asset,
          localPath: targetFile.path,
          status: ARModelAssetCacheStatus.cacheHit,
          cacheKey: cacheKey,
          resolvedAt: resolvedAt,
          networkMetadata: readResult.networkMetadata,
          wasRevalidated: true,
        );
      }
      final bytes = readResult.bytes;
      if (bytes == null) {
        return ARModelAssetCacheResult(
          sourceAsset: asset,
          resolvedAsset: asset,
          validationReport: asset.validate(),
          status: ARModelAssetCacheStatus.missingSource,
          cacheKey: cacheKey,
          resolvedAt: resolvedAt,
          errorMessage: 'Model source file does not exist.',
        );
      }

      await _writeBytesAtomically(targetFile, bytes);
      return _cachedResult(
        sourceAsset: asset,
        localPath: targetFile.path,
        status: ARModelAssetCacheStatus.cached,
        cacheKey: cacheKey,
        resolvedAt: resolvedAt,
        byteLength: bytes.length,
        contentFingerprint: fingerprintBytes(bytes),
        networkMetadata: readResult.networkMetadata,
        preserveExistingNetworkMetadata: false,
        wasRevalidated: readResult.wasRevalidated,
      );
    } on Object catch (error) {
      final canUseStaleNetworkCache =
          asset.source == ARModelAssetSource.network &&
              hasCachedFile &&
              (refresh || shouldRefreshNetworkCacheHit);
      if (canUseStaleNetworkCache) {
        await _touchCacheEntry(targetFile, resolvedAt);
        return _cachedResult(
          sourceAsset: asset,
          localPath: targetFile.path,
          status: ARModelAssetCacheStatus.cacheHit,
          cacheKey: cacheKey,
          resolvedAt: resolvedAt,
          errorMessage: error.toString(),
          usedStaleCacheOnError: true,
        );
      }
      return ARModelAssetCacheResult(
        sourceAsset: asset,
        resolvedAsset: asset,
        validationReport: asset.validate(),
        status: ARModelAssetCacheStatus.failed,
        cacheKey: cacheKey,
        resolvedAt: resolvedAt,
        errorMessage: error.toString(),
      );
    }
  }

  Future<ARModelAssetCacheStats> inspect() async {
    final entries = await _cacheEntries();
    return _statsFor(entries);
  }

  Future<List<ARModelAssetCacheEntry>> inspectEntries() async {
    final entries = await _cacheEntries();
    entries.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return List<ARModelAssetCacheEntry>.unmodifiable(
      entries.map((entry) => entry.toPublicEntry()),
    );
  }

  Future<ARModelAssetCacheIntegrityReport> inspectIntegrity() async {
    final entries = await _cacheEntries();
    final stats = _statsFor(entries);
    final issues = <ARModelAssetCacheIntegrityIssue>[];

    for (final entry in entries) {
      final manifest = entry.manifest;
      if (manifest == null) {
        issues.add(
          ARModelAssetCacheIntegrityIssue(
            code: ARModelAssetCacheIntegrityIssueCode.missingManifest,
            cacheKey: entry.cacheKey,
            path: entry.path,
            manifestPath: entry.manifestPath,
            label: 'Cached model is missing its manifest.',
          ),
        );
        continue;
      }

      final manifestByteLength = manifest.byteLength;
      if (manifestByteLength != null &&
          manifestByteLength != entry.byteLength) {
        issues.add(
          ARModelAssetCacheIntegrityIssue(
            code: ARModelAssetCacheIntegrityIssueCode.byteLengthMismatch,
            cacheKey: entry.cacheKey,
            path: entry.path,
            manifestPath: entry.manifestPath,
            expected: manifestByteLength,
            actual: entry.byteLength,
            label: 'Cached model byte length differs from its manifest.',
          ),
        );
      }

      final manifestFingerprint = manifest.contentFingerprint;
      if (manifestFingerprint != null) {
        final actualFingerprint = _fingerprintExistingFile(entry.file);
        if (actualFingerprint != manifestFingerprint) {
          issues.add(
            ARModelAssetCacheIntegrityIssue(
              code: ARModelAssetCacheIntegrityIssueCode
                  .contentFingerprintMismatch,
              cacheKey: entry.cacheKey,
              path: entry.path,
              manifestPath: entry.manifestPath,
              expected: manifestFingerprint,
              actual: actualFingerprint,
              label: 'Cached model fingerprint differs from its manifest.',
            ),
          );
        }
      }

      if (!_isSupportedManifestFormat(manifest.format)) {
        issues.add(
          ARModelAssetCacheIntegrityIssue(
            code: ARModelAssetCacheIntegrityIssueCode.unsupportedFormat,
            cacheKey: entry.cacheKey,
            path: entry.path,
            manifestPath: entry.manifestPath,
            actual: manifest.format,
            label: 'Cached model manifest uses an unsupported format.',
          ),
        );
      }
    }

    final entryCacheKeys = {
      for (final entry in entries) entry.cacheKey,
    };
    for (final manifestFile in await _manifestFiles()) {
      final cacheKey = _cacheKeyFromManifestPath(manifestFile.path);
      final manifest = await _readManifestFile(manifestFile);
      if (!entryCacheKeys.contains(cacheKey)) {
        issues.add(
          ARModelAssetCacheIntegrityIssue(
            code: ARModelAssetCacheIntegrityIssueCode.orphanManifest,
            cacheKey: cacheKey,
            path: manifestFile.path,
            manifestPath: manifestFile.path,
            label: 'Model cache manifest has no matching cached file.',
          ),
        );
      }
      final resolvedPath = manifest?.resolvedPath;
      if (resolvedPath != null && !await File(resolvedPath).exists()) {
        issues.add(
          ARModelAssetCacheIntegrityIssue(
            code: ARModelAssetCacheIntegrityIssueCode.manifestMissingFile,
            cacheKey: cacheKey,
            path: resolvedPath,
            manifestPath: manifestFile.path,
            label: 'Model cache manifest points to a missing cached file.',
          ),
        );
      }
    }

    return ARModelAssetCacheIntegrityReport(
      stats: stats,
      issues: List<ARModelAssetCacheIntegrityIssue>.unmodifiable(issues),
    );
  }

  Future<ARModelAssetCacheRepairResult> repairManifests() async {
    return _operations.run(() => _withCacheLock(_repairManifests));
  }

  Future<ARModelAssetCacheRepairResult> _repairManifests() async {
    final entries = await _cacheEntries();
    final beforeStats = _statsFor(entries);
    final repairedManifestPaths = <String>[];
    final skippedPaths = <String>[];
    for (final entry in entries) {
      if (entry.manifest != null) {
        continue;
      }
      try {
        final manifest = _recoveredManifestFor(entry);
        await _writeManifest(manifest);
        repairedManifestPaths.add(entry.manifestPath);
      } on Object {
        skippedPaths.add(entry.path);
      }
    }
    return ARModelAssetCacheRepairResult(
      beforeStats: beforeStats,
      afterStats: _statsFor(await _cacheEntries()),
      repairedManifestPaths: List<String>.unmodifiable(repairedManifestPaths),
      skippedPaths: List<String>.unmodifiable(skippedPaths),
    );
  }

  Future<ARModelAssetCacheIntegrityRepairResult> repairIntegrity() async {
    return _operations.run(() => _withCacheLock(_repairIntegrity));
  }

  Future<ARModelAssetCacheIntegrityRepairResult> _repairIntegrity() async {
    final beforeReport = await inspectIntegrity();
    final entries = await _cacheEntries();
    final repairedManifestPaths = <String>[];
    final removedManifestPaths = <String>[];
    final skippedPaths = <String>[];

    for (final entry in entries) {
      if (!_hasRepairableEntryIntegrityIssue(beforeReport, entry.cacheKey)) {
        continue;
      }
      try {
        final manifest = _repairedManifestFor(entry);
        await _writeManifest(manifest);
        repairedManifestPaths.add(entry.manifestPath);
      } on Object {
        skippedPaths.add(entry.path);
      }
    }

    final entryCacheKeys = {
      for (final entry in entries) entry.cacheKey,
    };
    for (final manifestFile in await _manifestFiles()) {
      final manifestPath = manifestFile.path;
      final cacheKey = _cacheKeyFromManifestPath(manifestPath);
      if (entryCacheKeys.contains(cacheKey) ||
          !_hasOrphanManifestIssue(beforeReport, cacheKey, manifestPath)) {
        continue;
      }
      try {
        if (await _deleteManifestIfExists(manifestPath)) {
          removedManifestPaths.add(manifestPath);
        }
      } on Object {
        skippedPaths.add(manifestPath);
      }
    }

    return ARModelAssetCacheIntegrityRepairResult(
      beforeReport: beforeReport,
      afterReport: await inspectIntegrity(),
      repairedManifestPaths: List<String>.unmodifiable(repairedManifestPaths),
      removedManifestPaths: List<String>.unmodifiable(removedManifestPaths),
      skippedPaths: List<String>.unmodifiable(skippedPaths),
    );
  }

  Future<void> clear() async {
    return _operations.run(
      () => _withCacheLock(() async {
        if (await _cacheDirectory.exists()) {
          await _cacheDirectory.delete(recursive: true);
        }
      }),
    );
  }

  Future<ARModelAssetCacheTemporaryFileCleanupResult> cleanupTemporaryFiles({
    Duration minimumAge = Duration.zero,
  }) async {
    return _operations.run(
      () => _withCacheLock(
        () => _cleanupTemporaryFiles(minimumAge: minimumAge),
      ),
    );
  }

  Future<ARModelAssetCacheTemporaryFileCleanupResult> _cleanupTemporaryFiles({
    required Duration minimumAge,
  }) async {
    _validateTemporaryFileCleanupAge(minimumAge);
    final cutoff = _now().toUtc().subtract(minimumAge);
    final removedPaths = <String>[];
    final skippedPaths = <String>[];
    var removedByteLength = 0;

    for (final tempFile in await _temporaryCacheFiles()) {
      if (minimumAge > Duration.zero && tempFile.modifiedAt.isAfter(cutoff)) {
        continue;
      }
      try {
        if (await _deleteFileIfExists(tempFile.path)) {
          removedPaths.add(tempFile.path);
          removedByteLength += tempFile.byteLength;
        }
      } on Object {
        skippedPaths.add(tempFile.path);
      }
    }

    return ARModelAssetCacheTemporaryFileCleanupResult(
      removedPaths: List<String>.unmodifiable(removedPaths),
      skippedPaths: List<String>.unmodifiable(skippedPaths),
      removedByteLength: removedByteLength,
    );
  }

  Future<ARModelAssetCachePruneResult> prune({
    ARModelAssetCachePrunePolicy policy = const ARModelAssetCachePrunePolicy(),
  }) async {
    return _operations.run(
      () => _withCacheLock(() => _prune(policy: policy)),
    );
  }

  Future<ARModelAssetCachePruneResult> _prune({
    required ARModelAssetCachePrunePolicy policy,
  }) async {
    _validatePrunePolicy(policy);
    final entries = await _cacheEntries();
    final beforeStats = _statsFor(entries);
    if (entries.isEmpty || policy.isNoop) {
      return ARModelAssetCachePruneResult(
        beforeStats: beforeStats,
        afterStats: beforeStats,
      );
    }

    final retained = entries.toList()
      ..sort((a, b) => a.lastUsedAt.compareTo(b.lastUsedAt));
    final removalCandidates = <_CacheEntry>[];

    final maxAge = policy.maxAge;
    if (maxAge != null) {
      final cutoff = _now().toUtc().subtract(maxAge);
      removalCandidates.addAll(
        retained.where((entry) => entry.lastUsedAt.isBefore(cutoff)),
      );
      retained.removeWhere((entry) => removalCandidates.contains(entry));
    }

    final maxEntries = policy.maxEntries;
    if (maxEntries != null && retained.length > maxEntries) {
      final removeCount = retained.length - maxEntries;
      removalCandidates.addAll(retained.take(removeCount));
      retained.removeRange(0, removeCount);
    }

    final maxBytes = policy.maxBytes;
    if (maxBytes != null) {
      var retainedBytes = _byteLengthFor(retained);
      while (retained.isNotEmpty && retainedBytes > maxBytes) {
        final entry = retained.removeAt(0);
        removalCandidates.add(entry);
        retainedBytes -= entry.byteLength;
      }
    }

    final removedEntries = await _deleteEntries(removalCandidates);
    final removedPaths = {
      for (final entry in removedEntries) entry.path,
    };
    final afterEntries =
        entries.where((entry) => !removedPaths.contains(entry.path)).toList();
    return ARModelAssetCachePruneResult(
      beforeStats: beforeStats,
      afterStats: _statsFor(afterEntries),
      removedPaths: [
        for (final entry in removedEntries) entry.path,
      ],
      removedByteLength: _byteLengthFor(removedEntries),
    );
  }

  Future<List<int>?> _readLocalFile(ARModelAsset asset) async {
    final file = File(_localFilePath(asset.path));
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  Future<bool> _shouldRefreshLocalCacheHit(
    ARModelAsset asset,
    File cachedFile,
    String cacheKey,
  ) async {
    if (asset.source != ARModelAssetSource.file) {
      return false;
    }
    try {
      final sourceFile = File(_localFilePath(asset.path));
      if (!await sourceFile.exists()) {
        return false;
      }
      final sourceStat = await sourceFile.stat();
      final manifest = await _readManifest(cacheKey);
      final manifestSourceByteLength = manifest?.sourceByteLength;
      final manifestSourceModifiedAt = manifest?.sourceModifiedAt;
      if (manifestSourceByteLength != null &&
          manifestSourceModifiedAt != null) {
        if (sourceStat.size != manifestSourceByteLength) {
          return true;
        }
        if (_sameDateTime(
          sourceStat.modified.toUtc(),
          manifestSourceModifiedAt,
        )) {
          return false;
        }
        final sourceFingerprint = _fingerprintExistingFile(sourceFile);
        final manifestSourceFingerprint =
            manifest?.sourceContentFingerprint ?? manifest?.contentFingerprint;
        if (manifestSourceFingerprint != null) {
          return sourceFingerprint != manifestSourceFingerprint;
        }
      }
      final cachedStat = await cachedFile.stat();
      if (sourceStat.size != cachedStat.size) {
        return true;
      }
      final sourceFingerprint = _fingerprintExistingFile(sourceFile);
      final manifestFingerprint = manifest?.contentFingerprint;
      if (manifestFingerprint != null) {
        return sourceFingerprint != manifestFingerprint;
      }
      return sourceFingerprint != _fingerprintExistingFile(cachedFile);
    } on Object {
      return false;
    }
  }

  Future<bool> _shouldRefreshNetworkCacheHit(
    ARModelAsset asset,
    String cacheKey, {
    required ARModelAssetCacheFreshnessPolicy freshnessPolicy,
    required DateTime checkedAt,
  }) async {
    if (asset.source != ARModelAssetSource.network || freshnessPolicy.isNoop) {
      return false;
    }
    final maxAge = freshnessPolicy.networkMaxAge;
    if (maxAge == null) {
      return false;
    }
    try {
      final manifest = await _readManifest(cacheKey);
      final fetchedAt =
          manifest?.networkMetadata?.fetchedAt ?? manifest?.createdAt;
      if (fetchedAt == null) {
        return true;
      }
      if (fetchedAt.toUtc().isAfter(checkedAt.toUtc())) {
        return false;
      }
      final age = checkedAt.toUtc().difference(fetchedAt.toUtc());
      return !age.isNegative && age >= maxAge;
    } on Object {
      return false;
    }
  }

  Future<_SourceSnapshot?> _sourceSnapshotForLocalAsset(
    ARModelAsset asset, {
    String? contentFingerprint,
  }) async {
    if (asset.source != ARModelAssetSource.file) {
      return null;
    }
    final sourceFile = File(_localFilePath(asset.path));
    try {
      if (!await sourceFile.exists()) {
        return null;
      }
      final stat = await sourceFile.stat();
      return _SourceSnapshot(
        byteLength: stat.size,
        modifiedAt: stat.modified.toUtc(),
        contentFingerprint:
            contentFingerprint ?? _fingerprintExistingFile(sourceFile),
      );
    } on Object {
      return null;
    }
  }

  Future<void> _touchCacheEntry(File file, DateTime touchedAt) async {
    try {
      await file.setLastModified(touchedAt.toUtc());
    } on FileSystemException {
      // A cache hit remains usable even if the filesystem rejects recency touch.
    }
  }

  Future<_ModelReadResult> _readNetworkFile(
    ARModelAsset asset, {
    ARModelAssetNetworkMetadata? revalidationMetadata,
  }) async {
    final uri = Uri.tryParse(asset.path);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(
        asset.path,
        'asset.path',
        'Network model asset paths must be http or https URLs.',
      );
    }
    final fetcher = _fetcher;
    final revalidationRequest = ARModelAssetRevalidationRequest.fromMetadata(
      revalidationMetadata,
    );
    if (fetcher is ARModelAssetConditionalFetcher &&
        revalidationRequest.hasValidators) {
      final result = await fetcher.revalidate(uri, revalidationRequest);
      if (result.notModified) {
        final updateMetadata = result.networkMetadata;
        return _ModelReadResult(
          bytes: null,
          networkMetadata:
              updateMetadata?.mergeWithFallback(revalidationMetadata) ??
                  revalidationMetadata,
          notModified: true,
          wasRevalidated: true,
        );
      }
      final bytes = result.bytes;
      if (bytes == null) {
        throw StateError('Model cache revalidation did not return bytes.');
      }
      return _ModelReadResult(
        bytes: bytes,
        networkMetadata: result.networkMetadata,
        wasRevalidated: true,
      );
    }
    if (fetcher is ARModelAssetResponseMetadataFetcher) {
      final fetchResult = await fetcher.fetchWithMetadata(uri);
      return _ModelReadResult(
        bytes: fetchResult.bytes,
        networkMetadata: fetchResult.networkMetadata,
      );
    }
    return _ModelReadResult(bytes: await fetcher.fetch(uri));
  }

  Future<T> _withCacheLock<T>(Future<T> Function() operation) async {
    final parent = _cacheDirectory.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final lockPath = _cacheLockPathFor(_cacheDirectory.path);
    return _cacheDirectoryLocks.run(lockPath, () async {
      final lockFile = File(lockPath);
      final lock = await lockFile.open(mode: FileMode.append);
      try {
        await lock.lock();
        return await operation();
      } finally {
        try {
          await lock.unlock();
        } finally {
          await lock.close();
        }
      }
    });
  }

  Future<ARModelAssetCacheResult> _cachedResult({
    required ARModelAsset sourceAsset,
    required String localPath,
    required ARModelAssetCacheStatus status,
    required String cacheKey,
    required DateTime resolvedAt,
    int? byteLength,
    String? contentFingerprint,
    ARModelAssetNetworkMetadata? networkMetadata,
    bool preserveExistingNetworkMetadata = true,
    bool wasRevalidated = false,
    bool usedStaleCacheOnError = false,
    String? errorMessage,
  }) async {
    final file = File(localPath);
    final effectiveByteLength =
        byteLength ?? (file.existsSync() ? file.lengthSync() : null);
    final effectiveContentFingerprint =
        contentFingerprint ?? _fingerprintExistingFile(file);
    final existingManifest = await _readManifest(cacheKey);
    final baseNetworkMetadata = sourceAsset.source == ARModelAssetSource.network
        ? networkMetadata ??
            (preserveExistingNetworkMetadata
                ? existingManifest?.networkMetadata
                : null)
        : null;
    final shouldStampNetworkFetch =
        sourceAsset.source == ARModelAssetSource.network &&
            (status == ARModelAssetCacheStatus.cached || wasRevalidated);
    final effectiveNetworkMetadata = shouldStampNetworkFetch
        ? (baseNetworkMetadata ?? const ARModelAssetNetworkMetadata())
            .copyWith(fetchedAt: resolvedAt.toUtc())
        : baseNetworkMetadata;
    final sourceSnapshot = status == ARModelAssetCacheStatus.cached
        ? await _sourceSnapshotForLocalAsset(
            sourceAsset,
            contentFingerprint: effectiveContentFingerprint,
          )
        : _sourceSnapshotFromManifest(existingManifest);
    final resolvedAsset = _cachedAsset(
      sourceAsset: sourceAsset,
      localPath: localPath,
      cacheKey: cacheKey,
      resolvedAt: resolvedAt,
      contentFingerprint: effectiveContentFingerprint,
      networkMetadata: effectiveNetworkMetadata,
    );
    final validationReport = resolvedAsset.validate();
    final manifest = _manifestFor(
      sourceAsset: sourceAsset,
      resolvedAsset: resolvedAsset,
      validationReport: validationReport,
      existingManifest: existingManifest,
      cacheKey: cacheKey,
      resolvedAt: resolvedAt,
      byteLength: effectiveByteLength,
      contentFingerprint: effectiveContentFingerprint,
      sourceSnapshot: sourceSnapshot,
      networkMetadata: effectiveNetworkMetadata,
    );
    await _writeManifest(manifest);
    return ARModelAssetCacheResult(
      sourceAsset: sourceAsset,
      resolvedAsset: resolvedAsset,
      validationReport: validationReport,
      status: status,
      cacheKey: cacheKey,
      resolvedAt: resolvedAt,
      localPath: localPath,
      byteLength: effectiveByteLength,
      contentFingerprint: effectiveContentFingerprint,
      manifest: manifest,
      networkMetadata: effectiveNetworkMetadata,
      wasRevalidated: wasRevalidated,
      usedStaleCacheOnError: usedStaleCacheOnError,
      errorMessage: errorMessage,
    );
  }

  ARModelAsset _cachedAsset({
    required ARModelAsset sourceAsset,
    required String localPath,
    required String cacheKey,
    required DateTime resolvedAt,
    String? contentFingerprint,
    ARModelAssetNetworkMetadata? networkMetadata,
  }) {
    return ARModelAsset.fromPath(
      localPath,
      format: sourceAsset.format,
      source: ARModelAssetSource.file,
      fallbackSizeMeters: sourceAsset.fallbackSizeMeters,
      centerOrigin: sourceAsset.centerOrigin,
      metadata: <String, Object?>{
        ...sourceAsset.metadata,
        'modelCacheKey': cacheKey,
        'modelCacheSourcePath': sourceAsset.path,
        'modelCacheSource': sourceAsset.source.name,
        'modelCacheResolvedAt': resolvedAt.toUtc().toIso8601String(),
        if (contentFingerprint != null)
          'modelCacheContentFingerprint': contentFingerprint,
        if (networkMetadata != null)
          'modelCacheNetworkMetadata': networkMetadata.toMap(),
      },
    );
  }

  String _cachePathFor(ARModelAsset asset, String cacheKey) {
    return '${_cacheDirectory.path}/$cacheKey.${_extensionFor(asset)}';
  }

  String _manifestPathFor(String cacheKey) {
    return '${_cacheDirectory.path}/$cacheKey.manifest.json';
  }

  Future<List<_CacheEntry>> _cacheEntries() async {
    if (!await _cacheDirectory.exists()) {
      return const <_CacheEntry>[];
    }
    final entries = <_CacheEntry>[];
    try {
      await for (final entity in _cacheDirectory.list()) {
        if (entity is! File) {
          continue;
        }
        if (_isManifestPath(entity.path) ||
            _isTemporaryCachePath(entity.path)) {
          continue;
        }
        final stat = await entity.stat();
        final cacheKey = _cacheKeyFromCachePath(entity.path);
        entries.add(
          _CacheEntry(
            file: entity,
            cacheKey: cacheKey,
            path: entity.path,
            manifestPath: _manifestPathFor(cacheKey),
            manifest: await _readManifest(cacheKey),
            byteLength: stat.size,
            modifiedAt: stat.modified.toUtc(),
          ),
        );
      }
    } on PathNotFoundException {
      return const <_CacheEntry>[];
    }
    return entries;
  }

  Future<ARModelAssetCacheEntryManifest?> _readManifest(
    String cacheKey,
  ) async {
    return _readManifestFile(File(_manifestPathFor(cacheKey)));
  }

  Future<ARModelAssetCacheEntryManifest?> _readManifestFile(
    File file,
  ) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return ARModelAssetCacheEntryManifest.fromMap(decoded);
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<List<File>> _manifestFiles() async {
    if (!await _cacheDirectory.exists()) {
      return const <File>[];
    }
    final files = <File>[];
    try {
      await for (final entity in _cacheDirectory.list()) {
        if (entity is File && _isManifestPath(entity.path)) {
          files.add(entity);
        }
      }
    } on PathNotFoundException {
      return const <File>[];
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<List<_TemporaryCacheFile>> _temporaryCacheFiles() async {
    if (!await _cacheDirectory.exists()) {
      return const <_TemporaryCacheFile>[];
    }
    final files = <_TemporaryCacheFile>[];
    try {
      await for (final entity in _cacheDirectory.list()) {
        if (entity is File && _isTemporaryCachePath(entity.path)) {
          final stat = await entity.stat();
          files.add(
            _TemporaryCacheFile(
              path: entity.path,
              byteLength: stat.size,
              modifiedAt: stat.modified.toUtc(),
            ),
          );
        }
      }
    } on PathNotFoundException {
      return const <_TemporaryCacheFile>[];
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> _writeManifest(
    ARModelAssetCacheEntryManifest manifest,
  ) async {
    final file = File(_manifestPathFor(manifest.cacheKey));
    await _writeStringAtomically(file, jsonEncode(manifest.toMap()));
  }

  ARModelAssetCacheEntryManifest _manifestFor({
    required ARModelAsset sourceAsset,
    required ARModelAsset resolvedAsset,
    required ARModelAssetValidationReport validationReport,
    required ARModelAssetCacheEntryManifest? existingManifest,
    required String cacheKey,
    required DateTime resolvedAt,
    required int? byteLength,
    required String? contentFingerprint,
    required _SourceSnapshot? sourceSnapshot,
    required ARModelAssetNetworkMetadata? networkMetadata,
  }) {
    final renderProfile = resolvedAsset.renderProfile();
    return ARModelAssetCacheEntryManifest(
      cacheKey: cacheKey,
      sourcePath: sourceAsset.path,
      source: sourceAsset.source.name,
      format: sourceAsset.format.name,
      package: sourceAsset.package,
      resolvedPath: resolvedAsset.path,
      resolvedSource: resolvedAsset.source.name,
      byteLength: byteLength,
      contentFingerprint: contentFingerprint,
      sourceByteLength: sourceSnapshot?.byteLength,
      sourceModifiedAt: sourceSnapshot?.modifiedAt,
      sourceContentFingerprint: sourceSnapshot?.contentFingerprint,
      networkMetadata: sourceAsset.source == ARModelAssetSource.network
          ? networkMetadata
          : null,
      createdAt: existingManifest?.createdAt ?? resolvedAt.toUtc(),
      lastUsedAt: resolvedAt.toUtc(),
      validation: <String, Object?>{
        ..._validationMetadata(validationReport),
      },
      renderProfile: renderProfile.toMap(),
    );
  }

  ARModelAssetCacheEntryManifest _recoveredManifestFor(_CacheEntry entry) {
    final recoveredAt = _now().toUtc();
    final asset = ARModelAsset.fromPath(
      entry.path,
      source: ARModelAssetSource.file,
      metadata: <String, Object?>{
        'modelCacheRecoveredManifest': true,
        'modelCacheRecoveredAt': recoveredAt.toIso8601String(),
      },
    );
    final validationReport = asset.validate();
    return ARModelAssetCacheEntryManifest(
      cacheKey: entry.cacheKey,
      sourcePath: entry.path,
      source: ARModelAssetSource.file.name,
      format: asset.format.name,
      resolvedPath: entry.path,
      resolvedSource: ARModelAssetSource.file.name,
      byteLength: entry.byteLength,
      contentFingerprint: _fingerprintExistingFile(entry.file),
      sourceByteLength: entry.byteLength,
      sourceModifiedAt: entry.modifiedAt,
      sourceContentFingerprint: _fingerprintExistingFile(entry.file),
      createdAt: entry.modifiedAt,
      lastUsedAt: entry.modifiedAt,
      validation: <String, Object?>{
        ..._validationMetadata(validationReport),
        'recoveredManifest': true,
        'recoveredAt': recoveredAt.toIso8601String(),
      },
      renderProfile: asset.renderProfile().toMap(),
    );
  }

  ARModelAssetCacheEntryManifest _repairedManifestFor(_CacheEntry entry) {
    final existing = entry.manifest;
    if (existing == null) {
      return _recoveredManifestFor(entry);
    }
    final repairedAt = _now().toUtc();
    final asset = ARModelAsset.fromPath(
      entry.path,
      source: ARModelAssetSource.file,
      metadata: <String, Object?>{
        'modelCacheRepairedManifest': true,
        'modelCacheRepairedAt': repairedAt.toIso8601String(),
      },
    );
    if (asset.format == ARModelFormat.custom &&
        !_isSupportedManifestFormat(existing.format)) {
      throw StateError(
        'Cannot infer a supported model format from ${entry.path}.',
      );
    }
    final validationReport = asset.validate();
    return ARModelAssetCacheEntryManifest(
      cacheKey: entry.cacheKey,
      sourcePath: existing.sourcePath,
      source: existing.source,
      format: asset.format == ARModelFormat.custom
          ? existing.format
          : asset.format.name,
      package: existing.package,
      resolvedPath: entry.path,
      resolvedSource: ARModelAssetSource.file.name,
      byteLength: entry.byteLength,
      contentFingerprint: _fingerprintExistingFile(entry.file),
      sourceByteLength: existing.sourceByteLength,
      sourceModifiedAt: existing.sourceModifiedAt,
      sourceContentFingerprint: existing.sourceContentFingerprint,
      networkMetadata: existing.networkMetadata,
      createdAt: existing.createdAt,
      lastUsedAt: existing.lastUsedAt,
      validation: <String, Object?>{
        ..._validationMetadata(validationReport),
        'repairedIntegrity': true,
        'repairedAt': repairedAt.toIso8601String(),
      },
      renderProfile: asset.renderProfile().toMap(),
    );
  }
}

class _CacheOperationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final next = _tail.then((_) => operation());
    _tail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }
}

final _cacheDirectoryLocks = _CacheDirectoryLockRegistry();

class _CacheDirectoryLockRegistry {
  final _tails = <String, Future<void>>{};

  Future<T> run<T>(String key, Future<T> Function() operation) {
    final tail = _tails[key] ?? Future<void>.value();
    final next = tail.then((_) => operation());
    final nextTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tails[key] = nextTail;
    nextTail.whenComplete(() {
      if (identical(_tails[key], nextTail)) {
        _tails.remove(key);
      }
    });
    return next;
  }
}

class _TemporaryCacheFile {
  const _TemporaryCacheFile({
    required this.path,
    required this.byteLength,
    required this.modifiedAt,
  });

  final String path;
  final int byteLength;
  final DateTime modifiedAt;
}

class _SourceSnapshot {
  const _SourceSnapshot({
    required this.byteLength,
    required this.modifiedAt,
    required this.contentFingerprint,
  });

  final int byteLength;
  final DateTime modifiedAt;
  final String? contentFingerprint;
}

class _ModelReadResult {
  const _ModelReadResult({
    required this.bytes,
    this.networkMetadata,
    this.notModified = false,
    this.wasRevalidated = false,
  });

  final List<int>? bytes;
  final ARModelAssetNetworkMetadata? networkMetadata;
  final bool notModified;
  final bool wasRevalidated;
}

class _CacheEntry {
  const _CacheEntry({
    required this.file,
    required this.cacheKey,
    required this.path,
    required this.manifestPath,
    required this.manifest,
    required this.byteLength,
    required this.modifiedAt,
  });

  final File file;
  final String cacheKey;
  final String path;
  final String manifestPath;
  final ARModelAssetCacheEntryManifest? manifest;
  final int byteLength;
  final DateTime modifiedAt;

  DateTime get lastUsedAt => manifest?.lastUsedAt ?? modifiedAt;

  ARModelAssetCacheEntry toPublicEntry() {
    return ARModelAssetCacheEntry(
      cacheKey: cacheKey,
      path: path,
      manifestPath: manifestPath,
      byteLength: byteLength,
      modifiedAt: modifiedAt,
      manifest: manifest,
    );
  }
}

ARModelAssetCacheStats _statsFor(Iterable<_CacheEntry> entries) {
  var entryCount = 0;
  var byteLength = 0;
  for (final entry in entries) {
    entryCount += 1;
    byteLength += entry.byteLength;
  }
  return ARModelAssetCacheStats(
    entryCount: entryCount,
    byteLength: byteLength,
  );
}

int _byteLengthFor(Iterable<_CacheEntry> entries) {
  var byteLength = 0;
  for (final entry in entries) {
    byteLength += entry.byteLength;
  }
  return byteLength;
}

Future<List<_CacheEntry>> _deleteEntries(Iterable<_CacheEntry> entries) async {
  final removed = <_CacheEntry>[];
  final seenPaths = <String>{};
  for (final entry in entries) {
    if (!seenPaths.add(entry.path)) {
      continue;
    }
    try {
      if (await entry.file.exists()) {
        await entry.file.delete();
        removed.add(entry);
      }
      await _deleteManifest(entry.manifestPath);
    } on PathNotFoundException {
      // Another cache operation may have cleared the directory first.
    }
  }
  return removed;
}

Future<void> _deleteManifest(String path) async {
  await _deleteManifestIfExists(path);
}

Future<void> _writeBytesAtomically(File target, List<int> bytes) async {
  final temp = File(_temporaryCachePathFor(target.path));
  try {
    await target.parent.create(recursive: true);
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(target.path);
  } on Object {
    await _deleteFileIfExists(temp.path);
    rethrow;
  }
}

Future<void> _writeStringAtomically(File target, String contents) async {
  final temp = File(_temporaryCachePathFor(target.path));
  try {
    await target.parent.create(recursive: true);
    await temp.writeAsString(contents, flush: true);
    await temp.rename(target.path);
  } on Object {
    await _deleteFileIfExists(temp.path);
    rethrow;
  }
}

var _atomicWriteSequence = 0;

String _temporaryCachePathFor(String targetPath) {
  _atomicWriteSequence += 1;
  return '$targetPath.tmp.$_atomicWriteSequence';
}

Future<bool> _deleteManifestIfExists(String path) async {
  return _deleteFileIfExists(path);
}

Future<bool> _deleteFileIfExists(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
  } on PathNotFoundException {
    // Manifest is already gone.
  }
  return false;
}

void _validatePrunePolicy(ARModelAssetCachePrunePolicy policy) {
  final maxAge = policy.maxAge;
  if (maxAge != null && maxAge.isNegative) {
    throw ArgumentError.value(
      maxAge,
      'policy.maxAge',
      'Must not be negative.',
    );
  }
}

void _validateFreshnessPolicy(ARModelAssetCacheFreshnessPolicy policy) {
  final networkMaxAge = policy.networkMaxAge;
  if (networkMaxAge != null && networkMaxAge.isNegative) {
    throw ArgumentError.value(
      networkMaxAge,
      'policy.networkMaxAge',
      'Must not be negative.',
    );
  }
}

void _validateTemporaryFileCleanupAge(Duration minimumAge) {
  if (minimumAge.isNegative) {
    throw ArgumentError.value(
      minimumAge,
      'minimumAge',
      'Must not be negative.',
    );
  }
}

bool _isSupportedManifestFormat(String format) {
  final normalized = format.trim().toLowerCase();
  if (normalized == ARModelFormat.custom.name) {
    return false;
  }
  return ARModelFormat.values.any((value) => value.name == normalized);
}

bool _hasRepairableEntryIntegrityIssue(
  ARModelAssetCacheIntegrityReport report,
  String cacheKey,
) {
  return report.issues.any((issue) {
    return issue.cacheKey == cacheKey &&
        _isRepairableEntryIntegrityIssue(issue.code);
  });
}

bool _hasOrphanManifestIssue(
  ARModelAssetCacheIntegrityReport report,
  String cacheKey,
  String manifestPath,
) {
  return report.issues.any((issue) {
    return issue.code == ARModelAssetCacheIntegrityIssueCode.orphanManifest &&
        issue.cacheKey == cacheKey &&
        issue.manifestPath == manifestPath;
  });
}

bool _isRepairableEntryIntegrityIssue(
  ARModelAssetCacheIntegrityIssueCode code,
) {
  return switch (code) {
    ARModelAssetCacheIntegrityIssueCode.missingManifest ||
    ARModelAssetCacheIntegrityIssueCode.manifestMissingFile ||
    ARModelAssetCacheIntegrityIssueCode.byteLengthMismatch ||
    ARModelAssetCacheIntegrityIssueCode.contentFingerprintMismatch ||
    ARModelAssetCacheIntegrityIssueCode.unsupportedFormat =>
      true,
    ARModelAssetCacheIntegrityIssueCode.orphanManifest => false,
  };
}

Map<String, Object?> _validationMetadata(
  ARModelAssetValidationReport validationReport,
) {
  return <String, Object?>{
    'target': validationReport.target.name,
    'isValid': validationReport.isValid,
    'hasWarnings': validationReport.hasWarnings,
    'summaryLabel': validationReport.summaryLabel,
    'issueLabels': validationReport.issueLabels,
    'errorLabels': validationReport.errorLabels,
    'warningLabels': validationReport.warningLabels,
    'usesAndroidPrimitiveFallback':
        validationReport.usesAndroidPrimitiveFallback,
  };
}

String cacheKeyFor(ARModelAsset asset) {
  final sourceIdentity = <String, Object?>{
    'path': asset.path,
    'source': asset.source.name,
    'format': asset.format.name,
    'package': asset.package,
  };
  return 'model_${_fingerprintString(_canonicalize(sourceIdentity))}';
}

String _cacheLockPathFor(String cacheDirectoryPath) =>
    '$cacheDirectoryPath.lock';

bool _isManifestPath(String path) => path.endsWith('.manifest.json');

bool _isTemporaryCachePath(String path) {
  final filename = path.split(Platform.pathSeparator).last;
  return filename.contains('.tmp.');
}

String _cacheKeyFromCachePath(String path) {
  final filename = path.split(Platform.pathSeparator).last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex <= 0) {
    return filename;
  }
  return filename.substring(0, dotIndex);
}

String _cacheKeyFromManifestPath(String path) {
  final filename = path.split(Platform.pathSeparator).last;
  const suffix = '.manifest.json';
  if (filename.endsWith(suffix)) {
    return filename.substring(0, filename.length - suffix.length);
  }
  return _cacheKeyFromCachePath(path);
}

String fingerprintBytes(List<int> bytes) => _fingerprintCodes(bytes);

bool _requiresCache(ARModelAsset asset) {
  return asset.source == ARModelAssetSource.file ||
      asset.source == ARModelAssetSource.network;
}

String _localFilePath(String path) {
  final uri = Uri.tryParse(path);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return path;
}

String _extensionFor(ARModelAsset asset) {
  final preferred = switch (asset.format) {
    ARModelFormat.glb => 'glb',
    ARModelFormat.gltf => 'gltf',
    ARModelFormat.obj => 'obj',
    ARModelFormat.usdz => 'usdz',
    ARModelFormat.scn => 'scn',
    ARModelFormat.reality => 'reality',
    ARModelFormat.custom => _pathExtension(asset.path),
  };
  final sanitized = preferred.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  return sanitized.isEmpty ? 'model' : sanitized;
}

String _pathExtension(String path) {
  final cleanPath = path.split('?').first.split('#').first;
  final segments = cleanPath.split('/');
  final filename = segments.isEmpty ? cleanPath : segments.last;
  final dotIndex = filename.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == filename.length - 1) {
    return 'model';
  }
  return filename.substring(dotIndex + 1).toLowerCase();
}

String _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('Expected non-empty string, got $value.');
}

String? _nullableString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _nullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

DateTime _dateTime(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  throw FormatException('Expected ISO-8601 date time, got $value.');
}

DateTime? _nullableDateTime(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

DateTime? _parseHttpDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    return HttpDate.parse(value).toUtc();
  } on Object {
    return null;
  }
}

ARModelAssetNetworkMetadata _networkMetadataForResponse(
  HttpClientResponse response,
  Uri requestUri, {
  required bool includeContentLength,
}) {
  return ARModelAssetNetworkMetadata(
    responseUri: response.redirects.isEmpty
        ? requestUri.toString()
        : response.redirects.last.location.toString(),
    contentType: response.headers.contentType?.toString(),
    eTag: response.headers.value('etag'),
    lastModified: _parseHttpDate(response.headers.value('last-modified')),
    contentLength: includeContentLength && response.contentLength >= 0
        ? response.contentLength
        : null,
  );
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return Map<String, Object?>.unmodifiable(
    value.map((key, value) => MapEntry(key.toString(), value)),
  );
}

ARModelAssetNetworkMetadata? _networkMetadata(Object? value) {
  if (value is! Map) {
    return null;
  }
  final metadata = ARModelAssetNetworkMetadata.fromMap(value);
  return metadata.isEmpty ? null : metadata;
}

String? _fingerprintExistingFile(File file) {
  if (!file.existsSync()) {
    return null;
  }
  return fingerprintBytes(file.readAsBytesSync());
}

_SourceSnapshot? _sourceSnapshotFromManifest(
  ARModelAssetCacheEntryManifest? manifest,
) {
  final byteLength = manifest?.sourceByteLength;
  final modifiedAt = manifest?.sourceModifiedAt;
  if (byteLength == null || modifiedAt == null) {
    return null;
  }
  return _SourceSnapshot(
    byteLength: byteLength,
    modifiedAt: modifiedAt,
    contentFingerprint: manifest?.sourceContentFingerprint,
  );
}

bool _sameDateTime(DateTime first, DateTime second) {
  return first.toUtc().microsecondsSinceEpoch ==
      second.toUtc().microsecondsSinceEpoch;
}

String _fingerprintString(String value) =>
    _fingerprintCodes(utf8.encode(value));

final BigInt _fnv64OffsetBasis = BigInt.parse(
  'cbf29ce484222325',
  radix: 16,
);
final BigInt _fnv64Prime = BigInt.parse('100000001b3', radix: 16);
final BigInt _fnv64Mask = BigInt.parse('ffffffffffffffff', radix: 16);

String _fingerprintCodes(Iterable<int> codes) {
  var hash = _fnv64OffsetBasis;
  for (final code in codes) {
    hash = hash ^ BigInt.from(code & 0xff);
    hash = (hash * _fnv64Prime) & _fnv64Mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String _canonicalize(Object? value) {
  if (value is Map) {
    final entries = [
      for (final entry in value.entries)
        MapEntry(entry.key.toString(), entry.value),
    ]..sort((a, b) => a.key.compareTo(b.key));
    return '{${[
      for (final entry in entries)
        '${jsonEncode(entry.key)}:${_canonicalize(entry.value)}',
    ].join(',')}}';
  }
  if (value is Iterable) {
    return '[${[for (final item in value) _canonicalize(item)].join(',')}]';
  }
  if (value is DateTime) {
    return jsonEncode(value.toUtc().toIso8601String());
  }
  return jsonEncode(value);
}
