# UI Reusable Package Catalog

This catalog records the package boundaries and **currently verified implementation** under **UI/Packages/**. Package manifests, exported barrels, source and tests are authoritative; roadmap language is not a statement of shipped behavior.

## Current dependency graph

The checked-in manifests and **UI/jezaku/pubspec.yaml** show these direct relationships:

~~~text
UI/jezaku --runtime--> ar_engine, ar_model_cache, jezaku_ar
UI/jezaku --dev-----> ar_engine_testkit

jezaku_ar --runtime--> ar_engine, ar_model_cache
jezaku_ar --dev-----> ar_engine_testkit

ar_model_cache -----> ar_engine
ar_engine_testkit --> ar_engine
~~~

**ar_engine_testkit** is not a production dependency. There are no circular package dependencies. The app directly depends on the engine and cache as well as the Jejaku integration package.

## Package responsibilities and public surfaces

| Package | Verified responsibility | Main exported API | Test files |
|---|---|---|---:|
| [ar_engine README](../Packages/ar_engine/README.md) | Generic Flutter AR session/platform contract, scene graph, spatial primitives, diagnostics and capture orchestration | **ARController**, **ARWidget**, **ARSessionConfig**, **ARCapabilities**, **ARSceneManager**, **ARNode**, geospatial/cloud/recording/diagnostic types | 28 |
| [ar_engine_testkit README](../Packages/ar_engine_testkit/README.md) | In-memory platform fake and install/restore harness for tests | **TestArEnginePlatform**, **ArEngineTestHarness**, **testCamera()** | 1 |
| [ar_model_cache README](../Packages/ar_model_cache/README.md) | Local/network model asset staging, cache freshness, metadata, integrity inspection/repair and retention | **ARModelAssetCache**, fetcher contracts, cache results/status, freshness/prune/integrity types | 1 |
| [jezaku_ar README](../Packages/jezaku_ar/README.md) | Jejaku memory/geospatial AR integration, memory nodes, placement quality, capture wrapper and cloud-anchor record mapping | **JejakuARCapabilities**, **JejakuGeoAnchor**, **JejakuMemoryARScene**, model preflight, placement/capture/cloud record types | 8 |

## Boundary audit

### ar_engine: generic runtime boundary

The public barrel is product-neutral. It exports generic session, scene, model descriptor, spatial, geospatial, cloud-anchor, capture, diagnostics and platform abstractions. It does not import **jezaku_ar** or **ar_model_cache**. Product memory IDs, privacy metadata, social workflows and backend persistence remain outside the engine.

**Boundary is sound at the Dart package dependency level.** The main gap is platform fidelity: the package registers Android, iOS, Web, macOS and Windows, but these are not equivalent implementations. Android uses ARCore; iOS uses ARKit; Web uses WebXR. macOS has real AVFoundation webcam input but synthetic world pose/plane/hit-test/light data. Windows generates synthetic frames/pose and lacks EventChannel streams and a native capability map; its **isARSupported** value and inherited capability fallback are optimistic. Linux is not registered. See the package README for the feature matrix.

Two public abstractions need particular care:

- **ARCloudAnchorManager** simulates hosting/resolving when the platform returns **null**. The generated ID and identity-pose resolution are not shared or durable cloud anchors. Native cloud hosting is currently Android ARCore only; iOS explicitly reports unsupported.
- **ARScreenRecorder** has native video encoding on Android/iOS/macOS. Its Dart fallback is a frame-capture placeholder with a synthetic path, not playable video. **exportGIF** returns a JPEG frame; audio and automatic Flutter-widget overlay capture are not implemented by the native encoders.

The default **ArEnginePlatform.getCapabilities()** fallback is based only on **isARSupported()** and sets optional flags such as image tracking, light estimation and snapshot capture. It is not a trustworthy optional-feature probe. The WebXR adapter also uses `isSessionSupported('immersive-ar')` as a coarse proxy for optional plane-detection and light-estimation support; those features are requested as optional WebXR features and are not independently verified by its capability map. Production backends should provide an explicit capability map.

### ar_engine_testkit: test-only boundary

The package is marked **publish_to: none**, depends only on **ar_engine**, and is a dev dependency of the app and **jezaku_ar**. It installs a process-global platform fake, records calls, emits fake streams, gates async operations and injects errors. It has no native implementation and does not emulate physical AR. Tests must dispose controllers and restore the global platform in teardown; **restore()** alone does not close fake streams.

### ar_model_cache: asset-policy boundary

The cache depends only on **ar_engine** to reuse **ARModelAsset** and its validation/render-profile types. It owns filesystem copies, manifests, network freshness/revalidation, stale-cache-on-error results, integrity inspection/manifest repair, temporary-file cleanup and caller-driven pruning. It does not render or load Flutter asset bundles: **flutterAsset** and **bundle** descriptors pass through unchanged.

The implementation imports **dart:io**, so this package is not Web compatible. Its caller owns the supplied cache directory; **clear()** recursively deletes that directory. **isResolved** reports cache operation status, not **validationReport.isValid**. FNV-1a 64-bit fingerprints are cache-consistency metadata, not cryptographic verification. There is no automatic prune quota or default auth/retry policy.

### jezaku_ar: product integration boundary

This package correctly holds Jejaku-specific memory identity, title/caption/private metadata, photo-frame presentation, memory-node construction, geospatial projection, placement-quality assessment and cloud-anchor record mapping. It depends downward on **ar_engine** and **ar_model_cache**; the testkit is dev-only. It does not persist cloud-anchor records or enforce privacy/access control.

**jezaku_ar** inherits the cache's **dart:io** limitation, so it cannot currently be built for Flutter Web. Its own SDK constraint says **>=3.3.0**, but runtime dependencies require **>=3.4.0**; the effective minimum is 3.4.0. Native geospatial placement is attempted where supported; the current scene implementation catches any native geospatial error and falls back to local projection without exposing the caught error as a structured placement failure. Its cloud manager returns **null** for unsupported native cloud anchors rather than using the engine's synthetic cloud manager.

## Platform support summary

| Package | Android | iOS | Web | macOS | Windows | Linux |
|---|---|---|---|---|---|---|
| **ar_engine** | ARCore native | ARKit native | WebXR | Webcam + synthetic world state | Synthetic demo only | Not registered |
| **ar_engine_testkit** | Dart tests | Dart tests | Not a browser/native adapter | Dart tests | Dart tests | Dart tests |
| **ar_model_cache** | Filesystem | Filesystem | Unsupported (**dart:io**) | Filesystem | Filesystem | Filesystem |
| **jezaku_ar** | Engine + cache; ARCore Geo/Cloud where supported | Engine + cache; ARKit Geo where supported; no Cloud Anchors | Unsupported through cache dependency | Engine preview + cache | Engine demo + cache | Not a supported engine target |

Platform labels describe source-level compatibility/capability only. They are not a claim that hardware/browser integration has been validated.

## Documentation and metadata findings

The package READMEs and this catalog now distinguish shipped behavior from platform targets and fallback paths. Remaining repository findings are deliberately not changed in this documentation-only update:

1. **ar_engine/pubspec.yaml** still says “production-grade” and describes desktop as webcam plus visual odometry; its homepage/repository/issue URLs still point at **yourorg**.
2. **ar_engine/ios/ar_engine.podspec** says version **0.1.0** while package **pubspec.yaml** says **0.4.0**; the podspec homepage/author are also placeholders.
3. **jezaku_ar/pubspec.yaml** declares Dart **>=3.3.0**, below the **>=3.4.0** constraints of **ar_engine** and **ar_model_cache**.
4. Android's native Cloud Anchor adapter clamps TTL to 1–365 days, while **JejakuMemoryCloudAnchorManager** accepts zero and serializes it as no expiry.
5. **ARRecordingConfig.includeAudio** and **includeUIOverlay** are public options without a verified native audio-track or automatic Flutter-overlay implementation. Dart recording fallback and GIF export are placeholders, as documented above.
6. **JejakuGeoAnchor.isPrivate** is scene metadata/presentation data, not an authorization boundary. The app/backend must filter and protect private coordinates and content.
7. The repository tree contains generated Gradle/cache artifacts under **UI/Packages/ar_engine/android/**; review tracking and ignore rules separately.

## Validation and test coverage

Source-level inspection covered each package's **pubspec.yaml**, public barrel, implementation files, tests and README. Test inventory is 28 files for **ar_engine**, one for **ar_engine_testkit**, one for **ar_model_cache**, and eight for **jezaku_ar**.

The suites cover controller/widget lifecycle and capability resolution; fake-platform gates and cleanup; cache source handling, conditional revalidation, stale fallback, concurrency, integrity and pruning; and Jejaku memory scene, geospatial projection, placement quality, capture, cloud-record and model-preflight behavior.

This audit did not run **dart format**, **flutter analyze**, **flutter test**, Web builds, native builds, or hardware/browser checks. No test or device validation is claimed as passed.
