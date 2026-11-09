# jezaku_ar

Jejaku-specific geospatial AR helpers built on top of `ar_engine`.

This package keeps the low-level AR runtime generic while giving the Jejaku app
a focused API for geotagged memory anchors, local ENU projection, and scene
placement.

`JejakuARCapabilities` translates raw `ar_engine` feature support into app-level
decisions: native geospatial placement, local projection fallback, depth cues,
cloud-anchor persistence, snapshot capture, and native versus Dart recording
encode.
Use `planSession()` when the host app wants the ideal config, compatible config,
and downgrade labels together. `preferredSessionConfig()` is still available for
passing an ideal config to `ARWidget`, and `recommendedSessionConfig()` returns
an already-compatible config before it reaches the widget.

`JejakuMemoryARScene` now places memories through `ARController.addGeospatialAnchor`.
That lets Jejaku use native ARCore Earth / ARKit GeoAnchor placement when the
session enables it, while retaining the same deterministic local projection
fallback for development, desktop, and unsupported devices.
When an app has already resolved persisted cloud-anchor records,
`syncMemories(resolvedAnchors: ...)` can attach those memories to the resolved
native anchors first and only fall back to geospatial placement for unresolved
or expired records.

`JejakuMemoryCloudAnchorManager` hosts an already placed memory anchor through
the native cloud-anchor backend and returns a serializable
`JejakuMemoryCloudAnchor` record containing the memory ID, local anchor ID,
cloud ID, and expiry timestamp. Apps can store that record server-side and later
resolve it back into a local tracking anchor when cloud anchors are available.
It can also resolve and attach the matching memory node directly into a
`JejakuMemoryARScene`.

`JejakuARCaptureManager` wraps `ARController` snapshot capture and
`ARScreenRecorder` with app-level capability checks. It reports unsupported,
missing-frame, and native snapshot failures as structured
`JejakuARSnapshotCapture` values, and tags recording results with the active
Jejaku recording mode (`nativeEncode` or `dartFallback`).

`JejakuMemoryModelCachePreflight` prepares 3D model memories before they are
handed to `JejakuMemoryNodeFactory`. It uses `ar_model_cache` to stage local or
network model assets into an app-controlled cache, then writes normalized
`modelAsset`, `modelPath`, `modelSource`, and `modelCache` metadata back onto
the memory anchor. Apps can provide an `ARModelAssetCacheFreshnessPolicy` to
revalidate stale network models while keeping ordinary cache hits offline.
