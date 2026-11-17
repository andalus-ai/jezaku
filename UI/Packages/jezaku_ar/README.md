# jezaku_ar

**jezaku_ar** is the Jejaku-specific integration layer that turns generic AR engine capabilities into geospatial memory placement, model-backed memory nodes, placement-quality assessment, capture helpers and cloud-anchor record workflows.

It is not a generic AR runtime, persistence service, authorization layer or UI widget package.

## Responsibility and public API

~~~dart
import 'package:jezaku_ar/jezaku_ar.dart';
~~~

The barrel exports:

| Area | Principal public types |
|---|---|
| Capability planning | **JejakuARCapabilities**, **JejakuARSessionPlan**, **JejakuARPlacementMode**, **JejakuARRecordingMode**, **JejakuARFallback** |
| Product geospatial model | **JejakuGeoAnchor**, **JejakuGeoOrigin**, **JejakuGeoProjector** |
| Memory scene | **JejakuMemoryARScene**, **JejakuMemoryNodeFactory**, **JejakuPlacedMemory**, **JejakuMemorySceneSyncResult** |
| Model placement/preflight | **JejakuMemoryModelDescriptor**, **JejakuMemoryModelPlacement**, **JejakuMemoryModelCachePreflight**, preflight result/report types |
| Visual helpers | **JejakuHangingPhotoFrameStyle**, placement-quality types, **JejakuViewProjector** and projection result types |
| Capture | **JejakuARCaptureManager**, **JejakuARSnapshotCapture**, **JejakuARRecordingCapture** |
| Cloud-anchor records | **JejakuMemoryCloudAnchor**, **JejakuResolvedMemoryCloudAnchor**, **JejakuMemoryCloudAnchorManager** |

Memory IDs, title/caption, private-memory metadata, photo-frame presentation and memory-node metadata belong here rather than in **ar_engine**.

## Dependencies and platform constraints

Runtime package dependencies are local **ar_engine** and **ar_model_cache**; Flutter is also declared as an SDK dependency. **ar_engine_testkit** is a **dev_dependency** only. There is no backend SDK or persistent store in this package.

**ar_model_cache** imports **dart:io**; consequently **jezaku_ar** is not currently Flutter Web compatible, even though lower-level **ar_engine** includes WebXR. Its effective Dart SDK floor is at least 3.4.0 because both runtime dependencies require **>=3.4.0**, while this package's own **pubspec.yaml** currently declares **>=3.3.0** (metadata mismatch to correct separately).

Native geospatial support is inherited from **ar_engine**:

- Android can use ARCore Earth/Geospatial when device, session configuration, location authorization/services and service availability allow it.
- iOS can use ARKit GeoTracking when supported by device/OS and region, with host-app location authorization.
- When native geospatial is unavailable, the package can project WGS84 coordinates into the current local AR origin and place a normal world anchor. This is a local approximation, not VPS localization or a globally stable cross-device coordinate frame.
- macOS supplies real webcam frames but synthetic world pose/plane/hit-test values; Windows is a synthetic demo backend. A successful Dart API call on those backends is not proof of physically accurate placement.
- Native Cloud Anchor persistence is currently Android ARCore only. The engine reports cloud anchors unsupported on iOS, macOS and Web. This package's cloud-anchor manager does not invent a fallback cloud ID.

Snapshot and video capabilities follow the engine. Android, iOS and macOS have native video encoders. Web and Windows do not. The Dart recording fallback is not a production video file path.

## Capability planning and placement fallback

**JejakuARCapabilities.query()** discovers the engine capability map. **planSession()** keeps preferred config and resolved/recommended config observable, including unsupported features and active fallback labels. Use the resolved config when starting a session:

~~~dart
import 'package:ar_engine/ar_engine.dart';
import 'package:jezaku_ar/jezaku_ar.dart';

Future<void> placeMemory() async {
  final plan = (await JejakuARCapabilities.query()).planSession();
  final session = await ARController.createResolved(plan.recommendedConfig);
  final scene = JejakuMemoryARScene(controller: session.controller);

  const origin = JejakuGeoOrigin(
    latitude: -6.2,
    longitude: 106.8,
  );
  const memory = JejakuGeoAnchor(
    id: 'memory-1',
    latitude: -6.201,
    longitude: 106.801,
    title: 'Example memory',
  );

  try {
    final placed = await scene.placeMemory(
      origin: origin,
      memory: memory,
    );
    // Use placed.anchorId and placed.nodeId to track this scene placement.
  } finally {
    await scene.clear();
    await session.dispose();
  }
}
~~~

**JejakuMemoryARScene** does not own or dispose the controller. It tracks anchors/nodes it places; call **clear()** before disposing the controller when those resources should be removed.

For batches, **syncMemories()** deduplicates by memory ID, adds/updates/removes placements, can attach already-resolved anchors, and accepts **ARSessionReadiness**. When readiness is supplied and placement is blocked, new placements are deferred while obsolete placements are removed. Direct **placeMemory()** does not require a readiness object.

When native geospatial placement is preferred, the scene attempts the engine's geospatial operation. If it throws, the current implementation catches any `Object` and falls back to local projection. This keeps the visual path available but does not distinguish unsupported mode from permission, configuration or other native failures; the fallback can also fail, and the original native error is not exposed as a separate structured placement result. Inspect anchor metadata and session diagnostics rather than assuming native GeoTracking succeeded.

**JejakuGeoProjector** delegates to the engine's local geospatial projector. It is an Earth-radius/local tangent-plane approximation intended for nearby scene placement, not survey-grade geodesy or long-distance coordinate transformation. **JejakuPlacementPolicy** assesses supplied geospatial status/accuracy; it does not acquire GPS, compass or AR sensor data. **JejakuViewProjector** projects caller-supplied viewer pose/heading and memory coordinates; it is not a replacement for native camera tracking.

## Memory models and asset preparation

**JejakuMemoryNodeFactory** builds the memory's generic **ARNode**, including hanging photo-frame presentation or a model-backed node when model metadata is present. **JejakuMemoryModelDescriptor** parses model asset, placement, scale, rotation, material and primitive fallback information from memory metadata.

**JejakuMemoryModelCachePreflight** delegates file/network asset preparation to **ARModelAssetCache** and returns prepared memory metadata plus per-memory status. It processes memories sequentially. The cache result's **isResolved** flag is not the same as **validationReport.isValid**; inspect validation before rendering. See the [ar_model_cache README](../ar_model_cache/README.md) for source, freshness, offline and retention semantics.

## Cloud-anchor record workflow

**JejakuMemoryCloudAnchorManager** calls **ARController.hostCloudAnchor()** and **resolveCloudAnchor()** directly. It returns **null** when native hosting/resolution is unsupported or unavailable; native errors propagate. It serializes a **JejakuMemoryCloudAnchor** record with memory ID, local anchor ID, cloud ID and optional expiry. It does not save that record to a server/database, synchronize access or authorize a user. The app must persist and protect **record.toMap()** in its own backend.

The wrapper accepts **ttlDays** from 0 through 365 and treats zero as no expiry in the record, but the current Android ARCore adapter clamps native TTL to 1 through 365 days. Do not use zero to request a permanent Android Cloud Anchor; align this API mismatch before relying on expiry semantics.

**JejakuGeoAnchor.isPrivate** is copied into generic node/anchor metadata and affects presentation metadata. It is not access control, encryption, or a guarantee that coordinates/title/caption are absent from the scene. Filter private memory data before sharing or logging it.

## Capture and recording

**JejakuARCaptureManager** wraps snapshot capture and **ARScreenRecorder**. Snapshot results distinguish unsupported, no-frame and native-error cases. The manager owns its recorder and streams, not the controller; call **dispose()** on the manager separately.

**JejakuARCapabilities.recordingMode** can report **dartFallback** when snapshots exist but native encoding does not. In the current engine, that fallback captures frames but returns a placeholder path rather than playable video. **canRecord** being true in this mode is not a production guarantee. **includeAudio** and automatic Flutter-widget overlay capture are not implemented by the native encoders. Check the backend and validate the output file before exposing share/export.

## Errors and failure modes

- **ttlDays** outside 0–365 throws **RangeError**. Empty cloud IDs are rejected by **ARController**; deserializing a cloud-anchor record requires non-empty `memoryId`, `localAnchorId` and `cloudAnchorId` fields, and an invalid expiry string can throw **FormatException**. **resolveAndPlaceMemory()** throws **ArgumentError** when the record's memory ID does not match the supplied memory.
- **JejakuGeoAnchor** is a value object and does not validate IDs or coordinates at construction. Native geospatial adapters may reject invalid coordinates or unsupported session state; local projection does not provide comprehensive coordinate validation. **JejakuPlacementPolicy** uses assertions for positive accuracy thresholds (debug builds).
- Native session, geospatial, anchor and capture errors can propagate from **ar_engine**. The scene's native geospatial placement path catches any `Object` and attempts local projection; see the fallback caveat above.
- Unsupported cloud-anchor hosting/resolution returns **null**; it does not create a fake cross-device anchor.
- Model preflight represents cache outcomes as **cached**, **cacheHit**, **passthrough**, **missingSource** or **failed**; inspect **errorMessage**, freshness flags and validation reports.
- The package does not request camera/location permissions, check backend authorization or persist product data.

## Tests and known gaps

Eight test files cover capability planning, capture, cloud-anchor record serialization/host/resolve, local geospatial projection, model-cache preflight, memory scene placement/synchronization/rollback, placement-quality assessment and view projection. These are deterministic Dart tests; there are no ARCore/ARKit hardware tests, real backend persistence tests, Web builds or end-to-end network/device tests in this package.

See the [ar_engine README](../ar_engine/README.md) and [UI package catalog](../../docs/package-catalog.md).
