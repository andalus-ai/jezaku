# ar_engine

**ar_engine** is the generic Flutter AR runtime package in this repository. It owns the shared session/controller contract, platform bridge, scene primitives, spatial math, and reusable scene helpers. Its public API is product-neutral: no Jejaku memory, account, social, or backend domain model.

This README describes checked-in behavior, not a target-platform roadmap. Plugin registration does not imply equivalent AR fidelity on every target.

## Responsibility and non-goals

**Owns:** session creation/reconfiguration/pause/resume/disposal; capability reporting; camera, plane, anchor, light and hit-test contracts; generic nodes/materials/model descriptors; scene management, animation, physics, measurement, gestures and spatial helpers; generic geospatial/cloud-anchor contracts; snapshots, recording orchestration, diagnostics and health monitoring.

**Does not own:** product-specific memory/geotagging (that belongs in **jezaku_ar**); model download/cache directory policy or retention (that belongs in **ar_model_cache**); backend persistence, user authorization, privacy policy or permission prompts; or a guarantee that every target has physical-camera world tracking.

## Public API

Import the supported barrel:

~~~dart
import 'package:ar_engine/ar_engine.dart';
~~~

The **lib/ar_engine.dart** barrel exports these areas:

| Area | Principal public types |
|---|---|
| Session | **ARWidget**, **ARController**, **ARResolvedSession**, **ARSessionConfig**, **ARCapabilities**, **ARSessionConfigResolution**, **ARSessionFeature** |
| Health/diagnostics | **ARSessionHealthSnapshot**, **ARSessionHealthAssessment**, **ARSessionHealthMonitor**, **ARRuntimeDiagnostics**, diagnostics timeline/report types |
| Scene data | **ARNode**, **ARModelAsset**, **ARModelAssetValidationReport**, **ARAnchor**, **ARPlane**, **ARCamera**, **ARHitTestResult**, **ARLight** |
| Scene orchestration | **ARSceneManager**, **ARSceneEntity** |
| Math | **ARVector3**, **ARQuaternion**, **ARMatrix4**, **ARPose** |
| Spatial systems | **ARGeospatialAnchor**, **ARGeoOrigin**, **ARGeospatialProjector**, **ARGeospatialStatus**, **ARVpsAvailability**, **ARCloudAnchorManager** |
| Rendering helpers | **ARAnimationPlayer**, **ARPhysicsWorld**, **ARMeasurement**, **ARRay**, **ARGestureHandler**, **ARImageTracker**, **ARPortal**, **AROcclusionManager**, **ARBodyTracker** |
| Capture | **ARScreenRecorder**, **ARRecordingConfig**, **ARRecordingResult**, **ARRecordingState** |
| Platform/errors | **ArEnginePlatform**, **ArEngineMethodChannel**, and the **AR*Exception** types |

**lib/ar_engine_web.dart** is the registered web plugin entrypoint, not the application import barrel.

## Dependencies and package relationships

The package depends on Flutter, **plugin_platform_interface**, **web**, **flutter_web_plugins**, **collection**, **meta**, and **mime**. It does not depend on **ar_model_cache**, **ar_engine_testkit**, or **jezaku_ar**.

~~~text
ar_engine_testkit ──test-only──> ar_engine
ar_model_cache ────────────────> ar_engine
jezaku_ar ─────────────────────> ar_engine + ar_model_cache
UI/jezaku ─────────────────────> ar_engine + ar_model_cache + jezaku_ar
~~~

Keep product semantics above this package. **ARModelAsset** is a generic descriptor; it does not make the engine responsible for fetching or retaining bytes.

## Implemented platform support

The Flutter plugin manifest registers Android, iOS, Web, macOS and Windows. There is no Linux plugin registration or **linux/** implementation.

| Target | Checked-in implementation | Capability and fidelity notes |
|---|---|---|
| Android | ARCore plugin; minimum SDK 24; ARCore dependency 1.44.0 | Native session, camera/plane/anchor streams, hit testing, image tracking, light estimates, snapshots, and MediaCodec/MediaMuxer video encoding. Scene depth and geospatial support are queried per device/session. Human occlusion and body tracking are reported false. Cloud anchors use ARCore but require **cloudAnchorsEnabled**, valid Cloud Anchors API credentials/configuration, and network access. |
| iOS | ARKit plugin; minimum iOS 14 | Native world tracking, planes, hit tests, image tracking and light estimates. Scene depth, person occlusion, body tracking and GeoTracking depend on device/OS support. Snapshots and AVAssetWriter video encoding are implemented. **supportsCloudAnchors** is explicitly false; there is no ARKit cloud-anchor bridge. |
| Web | WebXR **immersive-ar** backend using WebGL2 | Requires browser/device WebXR immersive AR and WebGL2, normally in a secure context. **hit-test** and **local-floor** are requested as required features; plane detection, light estimation and anchors are optional. The current capability map is coarse: it derives world tracking, plane detection, hit testing, light estimation and snapshot support from `immersive-ar` availability rather than independently probing each optional feature. Plane detection and light estimation may still be unavailable. The session requests `hit-test` and `local-floor` as required features, so `isARSupported()` alone does not guarantee that session creation will succeed. No geospatial anchors, cloud anchors, depth, body tracking or native video encoder. Model rendering can use optional Three.js globals/loaders; they are not bundled as a guaranteed renderer. |
| macOS | AppKit view and AVFoundation webcam capture; minimum macOS 10.15 | Webcam frames are real when camera access is granted, but world pose, plane, hit-test and light-estimate data are synthetic/demo values. The backend reports several base capabilities true but is not spatially accurate visual odometry. Snapshot and AVAssetWriter video paths exist. Geospatial, cloud anchors, depth, body tracking and image tracking are false. |
| Windows | Windows plugin and pixel-buffer texture target | Experimental synthetic demo, not physical AR: the frame loop generates a gradient, pose uses sinusoidal drift, and the renderer is a minimal software wireframe renderer. The plugin does not implement camera/plane/anchor/light EventChannel streams or a native capability map. **isARSupported** returns true unconditionally, so the inherited capability map is optimistic. Do not ship as production camera/world tracking. |
| Linux | Not registered | No Linux plugin implementation. A Linux conditional include in Windows C++ source does not constitute a Linux target. |

### Host application requirements

The package does not expose a Dart permission API or permission-rationale UI. Permission behavior differs by adapter; the host app remains responsible for explaining access, supplying platform configuration, handling revocation, and deciding when to retry or reconfigure:

- Android: the plugin manifest contributes **CAMERA** permission and optional ARCore feature metadata, but does not declare location permissions. During `initSession`, the native adapter calls `Activity.requestPermissions` for a missing camera permission and then returns **CAMERA_PERMISSION_DENIED** for that attempt; retry session creation after the user grants it. If geospatial mode was requested without fine/coarse location permission, the adapter requests location permission but disables geospatial for that session. Declare **ACCESS_FINE_LOCATION** and/or **ACCESS_COARSE_LOCATION** in the host manifest when using GeoTracking, then reconfigure or recreate the session after authorization if native geospatial tracking is required. Cloud Anchors need network and the configured ARCore credential (documented manifest key: **com.google.android.ar.API_KEY**).
- iOS: provide **NSCameraUsageDescription** for the ARKit camera prompt. GeoTracking also requires Core Location usage configuration and authorization; the package does not implement a `CLLocationManager` permission flow. Handle ARKit GeoTracking availability/localization state.
- macOS: provide **NSCameraUsageDescription** for AVFoundation webcam access; the operating system handles the camera authorization prompt.
- Web: serve from a secure origin and check browser/device WebXR availability.

The manifest and Info.plist in **UI/jezaku/** are app-specific examples, not automatic configuration for every consumer.

## Lifecycle and resource ownership

- **ARWidget** creates and owns its **ARController**, observes app lifecycle, pauses while inactive/paused, attempts resume (recreating after failure), and disposes the controller when removed.
- With **ARController.create** or **createResolved**, the caller owns the controller and must call **dispose()**. **ARResolvedSession.dispose()** delegates to it.
- Treat Android camera/ARCore as one active session per Flutter engine; do not mount competing viewers.
- **ARSceneManager** owns animation/physics subsystems and stream subscriptions. Prefer **await scene.close()**; **dispose()** schedules close without awaiting it. **close()** does not remove native nodes/anchors, so call **clearAll()** first when those resources should be removed.
- **ARScreenRecorder** owns timers, captured frames and broadcast streams; dispose it after stop/cancel.
- **ARCloudAnchorManager** owns its operation state/streams, not the controller. Dispose manager and controller separately.
- Web reconfiguration ends and restarts the WebXR session.

## Capability checks and fallback behavior

Use **ARController.queryCapabilities()**, **ARController.createResolved(config)**, or **ARWidget(resolveConfigAgainstCapabilities: true)** to filter optional features before session creation. **ARWidget.resolveConfigAgainstCapabilities** defaults to **false**; otherwise the requested config is passed to the backend and unsupported native options can fail during initialization/reconfiguration.

- Android/iOS geospatial tracking is native only when device/platform support and session configuration allow it. The platform interface has a local WGS84-to-session projection fallback. It is tied to the current AR origin, not VPS localization or a globally stable anchor.
- **sampleDepth** returns **null** when depth is unsupported, disabled or unavailable in the current frame.
- Native Cloud Anchor hosting/resolving is currently Android ARCore only. iOS reports unsupported. When the platform returns **null**, generic **ARCloudAnchorManager** simulates a generated local ID and identity-pose resolution after a delay. This is demo/test behavior, not a cloud service or shared cross-device map; never persist it as a real Cloud Anchor.
- Native video encoding exists on Android MediaCodec/MediaMuxer and iOS/macOS AVAssetWriter. Web and Windows have no native encoder. The Dart fallback captures frames but returns a placeholder path, not a playable MP4/MOV. **ARRecordingResult.succeeded** alone does not prove a real file when fallback was used.
- Native encoders write video only. **includeAudio** is not an implemented audio track; **includeUIOverlay** does not capture arbitrary Flutter widgets. Supply a custom **ARRecordingFrameSource** for composited frames. Android writes MP4; iOS/macOS accept MP4 or MOV. **exportGIF** is a placeholder returning the latest JPEG, not an animated GIF.
- Recording buffers frames in memory until encoding. Bound recording duration and move valid temporary/cache output to app-owned durable storage if it must survive cache cleanup.

The default **ArEnginePlatform.getCapabilities()** fallback is derived only from **isARSupported()** and marks several optional features supported. It is not a reliable optional-feature probe. Production backends should override capability discovery; this is especially important for Windows.

## Errors and failure modes

Session creation can throw **ARNotSupportedException**, **ARCameraPermissionException**, or **ARSessionInitException**. Native calls can surface **PlatformException** with backend codes. Invalid coordinates/configuration can throw **ArgumentError** or **RangeError**; use after disposal and invalid recorder/scene state can throw **StateError**. Cloud-anchor and recording operations can return **null** when unsupported or when no frame/result is available. Do not treat null, simulated fallback and native failure as equivalent.

## Minimal controller/scene example

~~~dart
import 'package:ar_engine/ar_engine.dart';

Future<void> placeDemoEntity() async {
  final session = await ARController.createResolved(
    const ARSessionConfig(detectHorizontalPlanes: true),
  );
  final scene = ARSceneManager(session.controller);

  try {
    final hits = await session.controller.hitTest(0.5, 0.5);
    if (hits.isNotEmpty) {
      final entity = await scene.placeEntity(
        node: const ARNode(
          id: 'demo-box',
          primitiveShape: ARPrimitiveShape.cube,
          scale: ARVector3(0.1, 0.1, 0.1),
        ),
        at: hits.first,
      );
      scene.spin(entity.id);
    }
  } finally {
    await scene.clearAll();
    await scene.close();
    await session.dispose();
  }
}
~~~

For widget-driven apps, use **ARWidget** and retain its callback controller only while mounted; do not dispose a controller that **ARWidget** owns.

## Tests and known gaps

There are 28 **\*_test.dart** files under **test/**. They cover controller lifecycle/caches, capability/config resolution, fake method-channel behavior, widget lifecycle, diagnostics/health, geospatial fallback, cloud-anchor manager behavior, recording orchestration and generic scene helpers.

These are Dart/Flutter tests using fakes. No native device integration suites prove ARCore/ARKit tracking, WebXR browser/device behavior, camera permission flows, or macOS/Windows preview fidelity. Hardware/browser validation remains necessary.

## Metadata and maintenance notes

- **pubspec.yaml** still describes desktop as webcam plus visual odometry and points homepage/repository/issue URLs at **yourorg**; those metadata claims are stale.
- The iOS podspec version is **0.1.0**, while Dart package version is **0.4.0**.
- Windows is registered but synthetic; Linux is not registered.
- Generated Gradle/cache artifacts are present under the Android package directory. Review tracking/ignore rules separately; they are not part of this documentation update.

See the [UI package catalog](../../docs/package-catalog.md).
