# ar_model_cache

Reusable AR model asset cache and preflight helpers for `ar_engine` apps.

The package keeps asset preparation separate from rendering:

- Flutter/bundled assets pass through unchanged.
- Local file models are copied into an app-controlled cache directory.
- Network models are downloaded through an injectable byte fetcher and cached.
  Fetchers can optionally implement response metadata and conditional
  revalidation interfaces so cached `ETag` / `Last-Modified` validators are
  reused on `refresh: true`.
- Apps can opt into TTL-style network freshness with
  `ARModelAssetCacheFreshnessPolicy`; by default, cache hits stay offline.
- Cache hits refresh the cached file recency so retention behaves like LRU.
- Results include a stable cache key, byte count, content fingerprint, resolved
  local `ARModelAsset`, validation report, network revalidation state, and
  serializable cache metadata.
- Cached entries write a `*.manifest.json` sidecar with source metadata,
  network metadata, fingerprint, byte length, created/last-used timestamps,
  validation, and render-profile summaries.
- `inspectEntries()` returns typed cache entries sorted by most recent use,
  including parsed manifest metadata for diagnostics and settings UIs.
- Cache retention can be bounded with `ARModelAssetCache.prune()` using max
  age, max entry count, and max byte policies.

Host apps can use `ARModelAssetCache.resolve()` before handing an
`ARModelAsset` to scene builders or native renderers.
