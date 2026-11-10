# Changelog

All notable changes to **ar_engine** are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## Unreleased

### Added
- Geospatial quality API: `ARController.getGeospatialStatus()` returns `ARGeospatialStatus` (Earth state, tracking flag, camera `ARGeospatialPose` with horizontal, vertical and heading accuracy), and `ARController.checkVpsAvailability()` returns `ARVpsAvailability`. Android (ARCore) implements both; other backends report unsupported.
- Geospatial anchor API: `ARGeoOrigin`, `ARGeospatialAnchor`, `ARGeospatialProjector`, and `ARController.addGeospatialAnchor()` provide a portable WGS84-to-AR path with native ARCore Earth / ARKit GeoAnchor attempts and local projection fallback.
- Native geospatial session wiring: `geospatialEnabled` maps to ARCore `Config.GeospatialMode` and ARKit `ARGeoTrackingConfiguration`.
- Geospatial anchor metadata now keeps custom fields, WGS84 coordinates, correction offsets, and a `nativeGeospatial` marker across native and fallback placement paths.
- Platform capability discovery: `ARCapabilities`, `ARController.queryCapabilities()`, and `controller.capabilities` expose optional feature support for depth, occlusion, body tracking, geospatial, cloud anchors, snapshots, and related systems.
- Native scene-depth sampling: `ARController.sampleDepth()` and `AROcclusionManager.sampleDepth()` read ARCore Depth16 / ARKit SceneDepth values in meters with `null` fallback on unsupported platforms or frames.
- Cloud anchor platform hooks: `ARController.hostCloudAnchor()`, `ARController.resolveCloudAnchor()`, and `ARCloudAnchorManager` now use native ARCore Cloud Anchor host/resolve callbacks when available, with the previous Dart fallback retained for unsupported backends.
- Recording encoder hook: `ARScreenRecorder` now tries platform `encodeRecording` first, serializes recording config/results, validates unsafe configs, and keeps the deterministic Dart fallback for backends without native encoding.
- macOS snapshot capture: the desktop backend now caches the latest webcam frame and returns JPEG bytes from `captureSnapshot()`, with snapshot support reported through capabilities.
- macOS recording encode: `encodeRecording` now writes captured recorder frames through `AVAssetWriter` as H.264 MP4/MOV files and returns the native output path, duration, frame count, and file size.
- iOS recording encode: the ARKit backend now uses the same `AVAssetWriter` H.264 MP4/MOV path for `ARScreenRecorder` frames.
- Android recording encode: the ARCore backend now writes captured recorder frames through `MediaCodec`/`MediaMuxer` as H.264 MP4 files.
- Recording capabilities now expose `supportsRecordingEncode`, and Android snapshot capture now respects camera-plane row/pixel strides before JPEG encoding.
- iOS native body-tracking bridge: `bodyTrackingEnabled` now selects `ARBodyTrackingConfiguration`, emits `ARBodyAnchor` skeleton joints through anchor metadata, and surfaces unsupported-device errors during init/reconfigure.
- Native source-contract coverage for iOS body tracking and Android's current ARCore session-level limitation.
- Typed session-feature diagnostics: `ARSessionFeature`, `ARCapabilities.unsupportedSessionFeaturesFor()`, and `ARSessionConfigResolution.unsupportedFeatures` / `unsupportedFeatureLabels` expose capability downgrades without forcing apps to duplicate raw string labels.
- `ARSessionConfigResolution` now supports `copyWith()`, `toMap()`, `fromMap()`, equality, and hashing so apps can persist or compare resolved-session diagnostics.
- Runtime session-health snapshots: `ARSessionHealthSnapshot` and `ARController.healthSnapshot()` summarize tracking state, camera/light freshness, cached planes, anchors, and nodes without native API changes.
- Runtime session-health monitor: `ARSessionHealthMonitor` turns controller camera, plane, anchor, and light streams into throttled health snapshots apps can subscribe to directly.
- `ARWidget.onSessionHealthChanged` exposes the same throttled runtime health stream without app code needing to manage a monitor lifecycle.
- `ARSessionHealthPolicy` and `ARSessionHealthAssessment` convert raw runtime snapshots into reusable severity, issue, HUD, status, and detail labels, including stale-camera detection.
- `ARSessionHealthMonitor` and `ARWidget` now periodically resample quiet sessions by default so stale camera-frame assessments surface even when native camera streams stop emitting.
- `ARSessionHealthMonitor.assessments` and `ARWidget.onSessionHealthAssessmentChanged` expose policy-assessed runtime health directly for apps that do not need raw snapshot handling.
- `ARSessionHealthAssessment` now supports `copyWith()`, `toMap()`, `fromMap()`, equality, and hashing so apps can persist and compare assessed runtime health.
- `ARSessionHealthSnapshot.copyWith()` and `ARSessionHealthPolicy` serialization/copy helpers make runtime-health diagnostics easier to replay, persist, and tune.
- `ARSessionHealthGuidance` and assessment guidance getters provide issue-specific recovery hints such as scanning textured surfaces, improving light, or restarting frozen AR.
- `ARSessionReadiness` maps assessed health into ready/limited/blocked placement and capture decisions for apps that need a simple runtime gate.
- `ARSessionHealthGuidance` and `ARSessionReadiness` now support `fromMap()` and `copyWith()` so apps can persist, restore, and locally adapt readiness decisions.
- `ARSessionHealthPolicy.placementReadiness` provides a reusable placement-grade policy for apps that should pause anchor placement under low light or when no planes are tracked.
- `ARSessionHealthAssessment` now exposes direct capture, recording, and anchor-placement gates that mirror its readiness decision.
- `ARCaptureCapability` combines session availability, device capture support, and AR readiness into reusable snapshot/recording gates, recovery action hints, and unavailable/status labels for host apps.
- `ARCaptureDiagnostics` can persist an `ARCaptureCapability` snapshot so cached and synced captures keep the effective capture gate and recovery hint used by the app.
- `ARDiagnosticsTimeline` provides a bounded, serializable health/capture event history, and `ARSessionHealthMonitor` now keeps recent assessed health events for apps that need a session timeline.
- `ARCaptureDiagnosticsMemoryCache.toTimeline()` converts cached capture diagnostics into reusable timeline events, with optional syncable-only filtering.
- `ARDiagnosticsTimeline` now exposes warning/blocked counts, display/status labels, and session/type filters so apps can render timeline summaries without local traversal logic.
- `ARDiagnosticsTimeline` and timeline events now expose reusable search labels and query matching over source, session, severity, summary, guidance, and cached capture metadata.
- `ARDiagnosticsTimelineQuery` provides reusable text, session/source, type/severity, warning/blocked, time-window, ordering, and limit filters for timeline event searches.
- `ARDiagnosticsTimelineQueryResult` wraps filtered timeline events with reusable latest-event lookups, warning/blocked counts, labels, and serialization helpers.
- `ARDiagnosticsTimelineQueryResult` now exposes type, severity, source, and session breakdown maps plus display labels for app-level diagnostics filters and summaries.
- `ARDiagnosticsTimelineFacet` and `ARDiagnosticsTimelineFacetKind` provide render-ready diagnostics facets with reusable drill-down queries, including sessionless and unknown-severity filters.
- `ARSessionLifecycleEvent` and `ARDiagnosticsTimelineEventType.sessionLifecycle` let apps record session starts, pauses, interruptions, permission failures, config changes, native errors, and anchor lifecycle events in the shared diagnostics timeline.
- `ARDiagnosticsReport` bundles capture-cache counts, timeline events, query results, facets, latest warnings, and export-safe maps for app diagnostics handoff flows.
- `ARDiagnosticsReportStore` and `InMemoryARDiagnosticsReportStore` define a dependency-free save/load/clear contract for app diagnostics report persistence.
- `ARCaptureDiagnostics` now exposes reusable summary/search metadata labels and more tolerant scalar parsing so host apps can display cached diagnostics without duplicating raw payload-key logic.
- `ARCaptureDiagnostics.toSyncableMap()` and `ARCaptureDiagnostics.tryNormalizeSyncableMap()` centralize cache/sync payload normalization for host apps.
- `ARCaptureDiagnosticsMemoryCache` now supports snapshot serialization/restoration, bulk inserts, syncable-only exports, and latest-entry queries by session/source.
- `ARCaptureDiagnosticsMemoryCache` now supports predicate, cutoff, and max-age pruning so persisted diagnostics caches can drop stale sessions.

---

## [0.4.0] — 2026-04-12

### Added — New Systems
- **`ARNodeBuilder`** — Fluent builder API for constructing `ARNode` objects with method chaining (`cube()`, `sphere()`, `at()`, `color()`, `metallic()`, `glowing()`, `addChild()`, `tag()`, `build()`, and more)
- **`ARSceneSerializer`** — Full scene import/export: `captureSnapshot()` → `ARSceneSnapshot`, `loadSnapshot()` with anchor-ID remapping, static `diff()` returning `ARSceneDiff` (added/removed/changed node lists)
- **`ARLODManager`** — Distance-based level-of-detail group switching at 10 Hz; `addLODGroup()`, `start()`/`stop()`, `groupCount`/`activeGroupCount`
- **`AREnvironmentProbe`** — IBL cubemap capture with three update modes (once/realtime/onMovement); sky/ground color estimation; `onProbeUpdated` stream; `toAmbientLight()` helper
- **`ARSpatialAudio`** — Positional audio with inverse-square, linear, and logarithmic attenuation models; stereo panning; Doppler shift; `playOneShot()` convenience; `ARSpatialAudioManager` 30 Hz tick loop

### Added — Core AR
- `ARHitTestResult`: `confidence` field, `isOnPlane` getter, `estimatedVerticalPlane` type, `toMap()`, `copyWith()`, `==`/`hashCode`
- `ARAnchor`: native `metadata: Map<String,dynamic>` field (replaces broken extension), `isTracked`/`isStopped` getters, `==`/`hashCode`
- `ARPlane`: `toMap()`, `area` (shoelace), `boundingArea`, `perimeter`, `contains(x,z)` (ray-casting even-odd), `isTracked`, `==`/`hashCode`
- `ARCamera`: `toMap()`, `copyWith()`, `focalLengthX/Y`, `principalPointX/Y`, `imageWidth/Height`, `aspectRatio`, `isTracking`
- `ARSessionConfig`: `copyWith()`, `fromMap()`, `==`/`hashCode`, `occlusionEnabled`, `depthEnabled`, `bodyTrackingEnabled`
- `ARImageTarget`: `copyWith()`, `fromMap()`, `==`/`hashCode`

### Added — Mathematics
- `ARVector3`: `reflect()`, `projectOnto()`, `rejectFrom()`, `clamp()`, `clampLength()`, `abs`, `scale()`, `min()`/`max()`, `moveTowards()`, `lerpUnclamped()`, `smoothDamp()` (with `ARVelocityRef`), `angleTo()`, `signedAngleTo()`, `toList()`, direction constants (`down`, `back`, `left`)
- `ARQuaternion`: `fromToRotation()`, `lookRotation()`, `toEuler()`, `rotateTowards()`, `dot()`, `angle`/`axis` getters, `+` operator, `toList()`, `==`/`hashCode`
- `ARMatrix4`: `zero()`, `fromScale()`, `lookAt()`, `perspective()`, `orthographic()`, `inverse`, `transposed`, `rotation`/`scale` getters, `transformPoint()`, `transformDirection()`
- `ARPose`: `inverse`, `lookAt()` factory, `copyWith()`, `distanceTo()`, `isIdentity()`, `==`/`hashCode`

### Added — Animation
- Color track (`ARTrack<ARMaterialColor>`) drives `ARMaterial.baseColor` per tick
- `ARAnimation.colorTo()` — single-shot color tween factory
- `ARAnimation.colorPulse()` — ping-pong color loop factory
- `ARAnimation.popOut()` — scale 1→0 removal animation
- `ARAnimation.withDelay()` / `withSpeed()` modifiers
- `ARAnimationPlayer.playAll()` — launch multiple clips simultaneously
- `ARAnimationPlayer.playSequence()` — chain clips as `Future<String>` that resolves on completion
- Delay handling in tick loop (clips wait `delaySeconds` before first frame)
- Easing curves: `ARCurve.spring`, `ARCurve.stepped`

### Added — Physics
- `ARPhysicsBody`: `angularVelocity` getter, `speed`, `kineticEnergy`, `reset()`, `wakeUp()`
- `ARPhysicsWorld`: `pause()`/`resume()`, `setGravity(ARVector3)`, `queryBodiesInRadius()`, `bodyCount`
- Baumgarte positional correction in sphere-sphere collision
- Friction impulse with combined friction coefficient

### Added — Gestures
- `ARGestureType.fling` — released after velocity exceeds `flingThreshold`
- `ARGestureEvent.flingVelocity` — normalised screen units/second
- Fling applies world XZ physics impulse via `ARPhysicsWorld` when `autoTransform: true`
- `selectionRadius` parameter on `ARGestureHandler`
- Scale gesture correctly emits `ARGestureType.rotate` vs `ARGestureType.scale`

### Added — Lights
- `ARLight.sun()`, `ambient()`, `point()`, `spot()` factory constructors
- `ARLight.colorFromTemperature(K)` — Tanner Helland algorithm (1000–12000K)
- `ARLight.copyWith()`, `fromMap()`, `==`/`hashCode`
- `castsShadow`, `shadowResolution`, `shadowSoftness` fields
- Area light support (`areaWidth`, `areaHeight`)

### Added — Debug Overlay
- `showEntityCount`, `showLightEstimate`, `showAnchorPositions`, `showNodeBounds` toggle flags
- `_AnchorPainter` — projects anchor positions to screen as rings
- `_NodeBoundsPainter` — screen-space AABB for each visible node
- Euler angle display (`P: Y: R:`) in pose panel

### Added — Measurement
- `ARMeasurementUnit.imperial` — formats as feet′ inches″ / sq ft / acres
- `heightDifference`, `horizontalDistance` computed properties
- `addPointAt(ARVector3)` — place points without hit-testing
- `toJSON()` with full metrics map; `toSVGPath()` SVG floor-plan export
- `label` field on `ARMeasurementPoint`

### Added — Scene Manager
- `updateEntity()` — push node update through all caches + stream
- `setVisibility()` / `toggleVisibility()`
- `batchAdd()` with staggered pop-in delays
- `findEntitiesInRadius()` (sorted by distance), `findEntitiesBy()`, `sortedByDistance()`
- `visibleEntities` getter
- `removeEntity(animateOut: true)` plays pop-out before removing
- `onEntityUpdated` stream
- `animateColor()`, `pulseColor()`, `stopAnimations()` helpers
- `applyImpulse()` / `applyForce()` shortcuts

### Added — Ray Casting
- `ARRay.fromPose()`, `closestPointToPoint()`, `distanceToPoint()`, `isParallelTo()`
- `ARIntersection.rayCapsule()` (cylinder + end-cap spheres)
- `ARRayHit.tag` field; `==`/`hashCode`
- `ARFrustum.testAABB()`, `containsPoint()`

### Added — Portal
- `ARPortalConfig.copyWith()`, `==`/`hashCode`
- `openAt(animate: true)` triggers `animateOpen()` immediately
- `openPortals` getter, `getPortal()` by ID

### Added — Recording
- `ARRecordingConfig.copyWith()`, `==`/`hashCode`, `outputFormat` field
- `ARRecordingResult.actualFPS` computed getter
- `ARScreenRecorder.onElapsed` stream, `latestThumbnail`, `exportGIF()`, `cancel()`

### Added — Image Tracking
- **Fixed critical bug**: removed `extension ARAnchorMetadata` that shadowed `ARAnchor.metadata` and always returned `null`, breaking image target detection entirely
- `ARImageTracker.isRunning`, `activeCount`, `targetNames` getters

### Added — Project files
- `analysis_options.yaml` — strict Dart linting (100+ rules)
- `CHANGELOG.md`
- `LICENSE`

### Changed
- `pubspec.yaml` version → `0.4.0`, SDK floor → `>=3.3.0`, added `js: ^0.7.1`, `mime: ^2.0.0`
- `ARNode.fromMap` now handles null `children` gracefully
- Test suite expanded from ~100 to 200+ assertions across 45 groups

---

## [0.3.0] — 2025-12-01

### Added
- `ARSceneManager` — high-level entity orchestrator (placeEntity, explode, connectWithSpring)
- `ARPhysicsWorld` — discrete rigid-body simulation (sphere colliders, spring joints, ground plane)
- `ARAnimationPlayer` — 60 Hz tick loop driving keyframe tracks
- `ARMeasurementTool` / `ARMeasurementSession` — tap-to-measure with 4 modes
- `AROcclusionManager` — environment + human occlusion mode switching
- `ARScreenRecorder` — frame capture pipeline
- `ARPortalManager` — stencil portal lifecycle
- `ARCloudAnchorManager` — host/resolve Google Cloud Anchors
- `ARDebugOverlay` — FPS, tracking badge, plane outlines, performance profiler
- `ARGestureHandler` — tap/drag/pinch/rotate with autoTransform
- `ARImageTracker` — image target anchor attachment
- iOS Metal PBR renderer (`MetalARRenderer`, `ARMetalPlatformView`, `ARMetalViewFactory`)
- Android GLES 3.0 PBR renderer (`PBRObjectRenderer`, shadow maps, `ARCoreGLRenderer`)
- Windows DirectX 11 pixel-buffer texture (`FlutterTextureRegistrar`)
- macOS AVCapture synthetic pose estimation

---

## [0.2.0] — 2025-09-15

### Added
- WebXR backend (`ar_engine_web.dart`) — immersive-ar, hit-test, Three.js nodes
- `ARSessionConfig.reconfigure()` support (live plane detection toggle)
- `ARController.captureSnapshot()` — JPEG bytes on Android and iOS
- `ARController.addAnchorAtPose()` — free-space anchor creation
- Desktop texture registration (`getDesktopTextureId`)
- `ARSpringJoint` constraint for physics world
- `ARNode` children list, renderOrder, isVisible flag
- `ARMaterial` emissive intensity/color, ambientOcclusion, texture map paths

---

## [0.1.0] — 2025-07-01

### Added
- Initial release
- `ARWidget` for all 5 platforms
- `ARController` with node/anchor/plane caches
- Plane detection (horizontal + vertical)
- Hit testing, world anchors
- `ARNode` with primitive shapes and PBR materials
- `ARVector3`, `ARQuaternion`, `ARMatrix4`, `ARPose` math library
- Basic keyframe animation tracks (position, rotation, scale)
- `ARRay` + `ARIntersection` (sphere, box, plane, triangle)
- `ARFrustum` for view-frustum culling
- Android ARCore 1.44 backend
- iOS ARKit backend (SceneKit placeholder replaced with Metal in 0.3.0)
- Method channel + event channel bridge
- 50+ unit tests
