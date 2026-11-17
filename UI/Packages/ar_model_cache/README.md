# ar_model_cache

**ar_model_cache** owns model-asset preparation and filesystem cache policy for applications using **ar_engine**. It converts local-file and network model descriptors into app-controlled cached file descriptors and records validation, freshness and integrity metadata.

It does not render models, load Flutter asset bundles, choose the application's cache directory, or provide a browser storage implementation.

## Public API

~~~dart
import 'package:ar_model_cache/ar_model_cache.dart';
~~~

The barrel exports **ARModelAssetCache** and public types in **src/ar_model_asset_cache.dart**, including:

- Fetcher contracts: **ARModelAssetByteFetcher**, response-metadata and conditional-fetcher interfaces, **HttpARModelAssetByteFetcher**, fetch/revalidation result and request types.
- Resolve results: **ARModelAssetCacheResult**, **ARModelAssetCacheStatus**, **ARModelAssetCacheStats**.
- Freshness/retention: **ARModelAssetCacheFreshnessPolicy**, **ARModelAssetCachePrunePolicy**, prune and temporary-file cleanup results.
- Inspection/recovery: entry/manifest types, integrity issue/report types, manifest and integrity repair results.
- **cacheKeyFor()** and **fingerprintBytes()** helpers.

**ARModelAsset** is defined/exported by **ar_engine**; this package reuses that generic descriptor and its validation/render-profile API.

## Dependency direction and platform support

The only non-SDK package dependency is local **ar_engine**; Flutter is also declared as an SDK dependency. There is no dependency on **jezaku_ar** or the testkit. Rendering remains in the engine/consumer; the cache returns an **ARModelAsset** whose source is a local file.

The implementation imports **dart:io** and uses **Directory**, **File**, **HttpClient** and file locks. It requires a Dart VM target with a writable filesystem (for example Android, iOS, macOS, Windows or Linux). It is not Flutter Web compatible. A package that imports **ar_model_cache**, including the current **jezaku_ar** barrel, inherits that web-build limitation even though **ar_engine** has a WebXR backend.

The caller supplies the **Directory**. The package does not depend on **path_provider** and does not decide whether the path is temporary, cache, or application-support storage.

## Source and offline behavior

**resolve()** behaves according to **ARModelAsset.source**:

| Source | Implemented behavior |
|---|---|
| **file** | Copies the source file into the cache directory using an atomic temporary-file write and returns a file-backed **resolvedAsset**. A cache hit checks source size/modified time and, when needed, a content fingerprint. If the original source disappears after a successful cache, the cached copy remains usable. |
| **network** | Downloads bytes through the injected fetcher (default **HttpARModelAssetByteFetcher**) and writes a local cache entry. The default fetcher accepts HTTP 2xx and supports conditional revalidation with ETag/Last-Modified validators. |
| **flutterAsset** | Passes the descriptor through unchanged. The cache does not read the Flutter asset bundle. |
| **bundle** | Passes the descriptor through unchanged. The cache does not unpack or copy a bundle. |

A network cache hit is used without a network request by default. **ARModelAssetCacheFreshnessPolicy.none** has no max age, so a hit remains eligible until the caller sets **refresh: true** or supplies a freshness policy with **networkMaxAge**. When a conditional fetcher and stored validators are available, refresh can use HTTP revalidation; a 304 response retains cached bytes.

If refresh/revalidation fails and a cached network file already exists, the result can remain a cache hit with **usedStaleCacheOnError: true** and an **errorMessage**. This is the explicit offline/stale fallback. If no cached bytes exist, the result is **failed**. Missing local source files are reported as **missingSource**.

The default HTTP fetcher does not add application authentication headers or a product-specific retry policy. Supply a custom fetcher for authenticated endpoints, custom timeouts, transport policy or other headers. Downloads are accumulated in memory before the atomic write; this is not a streaming-to-disk downloader.

## Cache policy, integrity and ownership

- Cache keys are stable for source identity (**path**, source kind, format and package), not a cryptographic content identity. **fingerprintBytes()** uses FNV-1a 64-bit and is for cache consistency, not security verification or trusted artifact signing.
- Each cached file has a JSON manifest with source/resolved paths, format, byte length, content fingerprint, validation/render profile, timestamps and optional HTTP metadata.
- Operations are serialized per cache instance and use a lock file for cooperating cache instances/processes sharing the same directory. File and manifest writes use temporary files followed by rename.
- **inspect()** and **inspectEntries()** report cache contents. **inspectIntegrity()** checks manifests, lengths, fingerprints and supported format metadata. **repairManifests()** and **repairIntegrity()** repair/rebuild metadata or remove orphan manifests; they do not re-download or repair corrupt model bytes.
- **cleanupTemporaryFiles()** removes abandoned temporary write files. **prune()** applies caller-supplied max age, max entries and/or max bytes using least-recently-used ordering. There is no automatic background prune or default size quota.
- **clear()** recursively deletes the supplied cache directory. Give this instance a dedicated directory; do not point it at a directory containing unrelated application files. There is no **dispose()** method or background worker to stop.

**ARModelAssetCacheResult.isResolved** describes cache operation status. It does **not** guarantee **validationReport.isValid**. Check the validation report before passing an asset to a renderer, and inspect warnings such as Android format fallback or iOS conversion requirements.

## Example

Choose a writable app-specific path using the host application's storage policy, then pass that path to the cache:

~~~dart
import 'dart:io';

import 'package:ar_engine/ar_engine.dart';
import 'package:ar_model_cache/ar_model_cache.dart';

Future<ARModelAsset> prepareNetworkModel(String modelUrl, String modelCachePath) async {
  final cache = ARModelAssetCache(
    cacheDirectory: Directory(modelCachePath),
  );

  final result = await cache.resolve(
    ARModelAsset.fromPath(
      modelUrl,
      format: ARModelFormat.obj,
      source: ARModelAssetSource.network,
    ),
    freshnessPolicy: const ARModelAssetCacheFreshnessPolicy(
      networkMaxAge: Duration(days: 1),
    ),
  );

  if (!result.isResolved || !result.validationReport.isValid) {
    throw StateError(
      result.errorMessage ?? result.validationReport.summaryLabel,
    );
  }

  return result.resolvedAsset;
}
~~~

Use **result.resolvedAsset** for the renderer; retain **result.toMetadata()** when the caller needs an audit trail. For a local file, use **ARModelAssetSource.file**. For Flutter assets or bundle descriptors, expect **passthrough** and let the consumer's asset loader handle them.

## Errors and test coverage

Negative freshness/prune/cleanup durations are rejected with **ArgumentError**. Invalid network URLs, HTTP failures and source-read failures are represented as **failed** results when they occur inside resolve; cache-directory creation, locking and maintenance I/O can still throw. Handle both result statuses and thrown filesystem errors.

One comprehensive test file covers local/network sources, atomic writes, temporary-file cleanup, recency, source refresh, HTTP metadata/revalidation, stale-cache fallback, concurrent operations across cache instances, integrity inspection/repair, clear and pruning. Tests use injected fetchers and temporary directories; they do not validate production servers, platform storage quotas or Web support.

See the [ar_engine README](../ar_engine/README.md), [jezaku_ar README](../jezaku_ar/README.md), and [UI package catalog](../../docs/package-catalog.md).
