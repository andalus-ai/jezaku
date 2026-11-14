# ar_engine

A **production-grade multi-platform Augmented Reality plugin for Flutter** (v0.4.0).

| Platform | Backend | Min version |
|---|---|---|
| Android | ARCore 1.44 · GLES 3.0 PBR renderer | API 24 (Android 7.0) |
| iOS | ARKit + Metal PBR shaders | iOS 14.0 |
| Web | WebXR Device API (immersive-ar) | Chrome 90+, Edge 90+ |
| Windows | DirectX 11 + webcam visual odometry | Windows 10 |
| macOS | AVCapture + webcam visual odometry | macOS 10.15 |
| Linux | V4L2 + OpenGL software renderer | Ubuntu 20.04 |

---

## Features

### Core AR
- **Plane detection** — horizontal & vertical, polygon boundary, area, perimeter, point-in-polygon test
- **Hit testing** — raycast from screen tap to world surface, distance-sorted results
- **Anchors** — world-locked attachment with metadata field, isTracked/isStopped getters
- **Session config** — live reconfigure, occlusion, LiDAR depth, image targets, iOS native body tracking, geospatial tracking
- **Capabilities** — query optional feature support before enabling depth, occlusion, body tracking, geospatial, cloud anchors, snapshots, or native recording encode
- **Snapshot capture** — JPEG bytes on Android, iOS, web, and macOS webcam sessions
- **Depth sampling** — query native scene depth in meters at normalized screen coordinates when ARCore Depth or ARKit SceneDepth is available
- **Cloud anchors** — host and resolve persistent anchors through ARCore when native support is available, with a deterministic Dart fallback elsewhere
- **Screen recording pipeline** — validated recording config, serializable results, native H.264 encoders, platform encoder hook, and deterministic Dart fallback

### Scene Graph
- **AR nodes** — 7 primitive shapes (cube/sphere/cylinder/capsule/plane/torus/cone), GLTF/GLB/OBJ, visibility flag, render order, full `copyWith`, `fromMap`
- **PBR materials** — baseColor, metallic, roughness, AO, emission intensity+color, opacity, blendMode, 6 texture map slots; `metal()`/`matte()`/`glass()`/`emissive()` factories; `lerp()`
- **Material colors** — `fromARGB`, `fromHex`, `lerp`, `withOpacity`, `*`, `toARGB`, named constructors
- **Lights** — ambient, directional, point, spot, area; shadow maps (resolution+softness); `colorFromTemperature(K)`; `fromMap`/`copyWith`

### Mathematics
- **ARVector3** — full arithmetic, cross/dot, `reflect`, `projectOnto`, `rejectFrom`, `clamp`, `clampLength`, `abs`, `min/max`, `moveTowards`, `lerpUnclamped`, `smoothDamp` (mutable velocity ref), `angleTo`, `signedAngleTo`, component-wise `scale`
- **ARQuaternion** — axisAngle, euler, `lookRotation`, `fromToRotation`, `toEuler`, `rotateTowards`, slerp, `dot`, `angle/axis` getters, `toList`, `==`
- **ARMatrix4** — TRS, lookAt, perspective, orthographic, fromScale, `inverse`, `transposed`, `rotation/scale` getters, `transformPoint`, `transformDirection`
- **ARPose** — `inverse`, `lookAt` factory, `lerp`, `transformedBy`, `copyWith`, `distanceTo`, `isIdentity`, `==`

### Animation
- **Tracks** — `ARTrack<T>` with position, rotation, scale, material color; custom easing per keyframe
- **Curves** — linear, easeIn/Out/InOut, bounceOut, elasticOut, spring (stiffness+damping), stepped
- **Clips** — `moveTo`, `hover`, `spin`, `popIn`, `popOut`, `colorTo`, `colorPulse`; `withDelay()`, `withSpeed()`
- **Player** — `play`, `pause`, `resume`, `stop`, `playAll` (parallel), `playSequence` (Future chain), delay before first tick

### Physics
- **Bodies** — sphere/box/capsule colliders, mass, restitution, friction, linear/angular damping, `kineticEnergy`, `speed`, `reset()`, `wakeUp()`
- **Integration** — semi-implicit Euler, 4 sub-steps, sleep system
- **Constraints** — spring-damper joints (stiffness + damping)
- **Collision** — sphere-sphere, Baumgarte position correction, friction impulse, `relativeSpeed` in `ARCollision`
- **World** — `pause()`/`resume()`, `setGravity()`, `queryBodiesInRadius()`, `bodyCount`, `onCollision` stream

### Measurement
- Distance (direct + path), area (XZ shoelace + 3D cross-product), angle, box volume
- `heightDifference`, `horizontalDistance`, `polygon3DArea`, `perimeter`
- Metric (mm/cm/m/km) and imperial (ft′ in″, ft²/ac) formatting
- `toJSON()` full metrics map, `toSVGPath()` 2D floor-plan SVG
- `addPointAt(ARVector3)` — place points without hit-testing

### Ray Casting
- `ARRay.fromScreen()`, `ARRay.fromPose()`
- `closestPointToPoint()`, `distanceToPoint()`, `isParallelTo()`
- `ARIntersection` — raySphere, rayBox (with normal), rayPlane, rayTriangle (Möller–Trumbore), rayCapsule
- `ARFrustum` — `testSphere()`, `testAABB()`, `containsPoint()`

### Gestures
- Tap, doubleTap, longPress, 1-finger drag (XZ world translation), pinch scale, twist rotate
- `autoTransform: true` applies changes in real-time
- `ARGestureEvent` — entityId, screen point, delta, cumulative scaleFactor & rotationRadians

### Advanced Systems

| System | Description |
|---|---|
| `ARGeospatialAnchor` | WGS84 anchors with native ARCore Earth / ARKit GeoAnchor attempts and deterministic local fallback |
| `ARImageTracker` | Register targets → auto-attach overlay nodes on detection |
| `ARBodyTracker` | iOS ARKit skeleton anchors streamed through `ARAnchor.metadata`; Android requires an external ML Kit/MediaPipe pose bridge |
| `ARCloudAnchorManager` | Host (TTL-aware) and resolve Google Cloud Anchors |
| `ARPortalManager` | Stencil-clipped portals with animated open/close and inner world nodes |
| `AROcclusionManager` | Switch environment / human occlusion modes live |
| `ARScreenRecorder` | Record to MP4, pause/resume, export GIF; `ARRecordingResult` |
| `ARLODManager` | Distance-based geometry LOD group switching at 10 Hz |
| `AREnvironmentProbe` | IBL cubemap capture (once/realtime/onMovement), sky/ground color |
| `ARSpatialAudio` | Positional audio: inverse-square/linear/log attenuation, Doppler, panning |

### Debug
- `ARDebugOverlay` — 8 toggleable layers: planes, FPS, pose+Euler, tracking badge, entity count, light estimate (lux), anchor markers, node bounding boxes
- `ARPerformanceProfiler` — avg FPS, min FPS, p99 frame time

---

## Installation

```yaml
dependencies:
  ar_engine: ^0.4.0
```

### Android

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera.ar" android:required="false" />
<application>
    <meta-data android:name="com.google.ar.core" android:value="optional" />
</application>
```

`android/app/build.gradle`:
```groovy
defaultConfig { minSdkVersion 24 }
```

For Cloud Anchors, add your Maps API key:
```xml
<meta-data android:name="com.google.android.ar.API_KEY" android:value="YOUR_KEY" />
```

### iOS

`ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for Augmented Reality.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is used for AR audio recording.</string>
```

Minimum deployment target: iOS 14.0.

### Web

Optionally expose Three.js for WebGL node rendering. `GLTFLoader` and
`OBJLoader` enable model-backed nodes on web; without them, `ar_engine` keeps
using primitive fallbacks.
```html
<script type="module">
  const threeVersion = '0.160.0';
  const threeBaseUrl = `https://cdn.jsdelivr.net/npm/three@${threeVersion}`;
  const [threeModule, gltfModule, objModule] = await Promise.all([
    import(`${threeBaseUrl}/build/three.module.js`),
    import(`${threeBaseUrl}/examples/jsm/loaders/GLTFLoader.js`),
    import(`${threeBaseUrl}/examples/jsm/loaders/OBJLoader.js`),
  ]);
  window.THREE = threeModule;
  window.THREE.GLTFLoader = gltfModule.GLTFLoader;
  window.THREE.OBJLoader = objModule.OBJLoader;
</script>
```

WebXR requires **HTTPS**. Local testing:
```bash
flutter run -d chrome --web-browser-flag "--enable-features=WebXR,WebXRARModule"
```

---

## Session ownership and lifecycle

The native Android backend currently exposes one active ARCore camera session per
Flutter engine. Treat an `ARWidget` as the exclusive owner of that session:

- Keep only one mounted `ARWidget` for a camera session at a time.
- Dispose the current widget/controller before mounting another AR viewer.
- Do not use multiple independent viewers as if they had isolated cameras or
  scene state; the Android backend rejects a competing initialization with
  `SESSION_ALREADY_ACTIVE`.
- Backgrounding pauses the session. On resume, the plugin reports native
  failures to Flutter so the widget can recreate a reclaimed session.
- Changing `ARSessionConfig` on the owning widget reconfigures its existing
  session; it does not create an independent session.

This is an explicit single-session contract, not multi-viewer support. A future
multi-viewer implementation requires a session broker with ownership tokens,
reference-counted teardown, and well-defined platform-view attachment rules.

---

## Quick Start

```dart
import 'package:ar_engine/ar_engine.dart';

// 1. Display the AR camera
ARWidget(
  config: const ARSessionConfig(detectHorizontalPlanes: true),
  onARViewCreated: (ctrl) {
    _ctrl = ctrl;
    _scene = ARSceneManager(ctrl);
  },
)

// 2. Place an object on tap
final hits = await _ctrl!.hitTest(nx, ny);
final entity = await _scene!.placeEntity(
  node: ARNode(
    id: 'box',
    primitiveShape: ARPrimitiveShape.cube,
    scale: const ARVector3(0.1, 0.1, 0.1),
    material: ARMaterial.metal(),
  ),
  at: hits.first,
);
_scene!.hover(entity.id);   // gentle levitation loop
_scene!.spin(entity.id);    // Y-axis spin loop

// 3. Drop physics bodies
_scene!.physicsWorld.addBody(ARPhysicsBody(
  nodeId: entity.id,
  initialPosition: entity.currentNode.position,
  mass: 0.5, restitution: 0.6,
));

// 4. Animate colors in sequence
await _scene!.animationPlayer.playSequence([
  ARAnimation.colorTo(nodeId: entity.id,
    from: const ARMaterialColor.blue(),
    to:   const ARMaterialColor.red(),
    duration: 0.8),
  ARAnimation.popOut(nodeId: entity.id),
]);

// 5. Capture a snapshot
final jpeg = await _ctrl!.captureSnapshot();
```

---

## Demo App (example/)

Seven runnable demo screens:

| Screen | Features demonstrated |
|---|---|
| Place & Animate | Shape selector, color picker, hover+spin animations |
| Physics Sandbox | Random spawning, spring joints, explosion impulse |
| Measurement | Tap-to-measure, metric/imperial toggle, JSON + SVG export |
| Gesture Interaction | Drag, pinch-scale, twist-rotate with autoTransform |
| Color Animations | colorTo, colorPulse, stopAnimations |
| Snapshot & Record | JPEG preview, MP4 recording with status display |
| Debug Overlay | All 8 debug layers toggled individually |

---

## Architecture

```
lib/
├── ar_engine.dart           # Barrel — exports all 25 public systems
├── ar_engine_web.dart       # WebXR backend (web-only)
└── src/
    ├── ar_controller.dart   # Session + node/anchor/plane caches, getNode()
    ├── ar_widget.dart       # Flutter widget — all 5 platform paths
    ├── ar_anchor.dart       ├── ar_camera.dart  ├── ar_plane.dart
    ├── ar_hit_test.dart     ├── ar_node.dart    ├── ar_light.dart
    ├── ar_session_config.dart  ├── ar_measurement.dart  ├── ar_ray.dart
    ├── ar_scene_manager.dart
    ├── models/              # ARVector3, ARQuaternion, ARMatrix4, ARPose
    ├── animation/           # ARAnimation, ARAnimationPlayer, ARCurve
    ├── physics/             # ARPhysicsBody, ARPhysicsWorld, ARSpringJoint
    ├── gestures/            # ARGestureHandler
    ├── image_tracking/      # ARImageTracker
    ├── portal/              # ARPortalManager
    ├── occlusion/           # AROcclusionManager
    ├── cloud_anchors/       # ARCloudAnchorManager
    ├── recording/           # ARScreenRecorder
    ├── utils/               # ARLODManager, AREnvironmentProbe, ARSpatialAudio
    ├── debug/               # ARDebugOverlay, ARPerformanceProfiler
    ├── platform/            # ArEnginePlatform, ArEngineMethodChannel
    └── exceptions/          # 10 typed AR exception classes

android/    Kotlin · ARCore 1.44 · GLES 3.0 · PBR renderer · shadow maps
ios/        Swift  · ARKit  · Metal PBR shaders · LiDAR depth/body tracking
macos/      Swift  · AVCapture + synthetic pose estimation
windows/    C++    · DirectX 11 · pixel-buffer Flutter texture
test/       150+ unit tests covering all subsystems
example/    7 demo screens
```

---

## Custom Platform Backend

Subclass `ArEnginePlatform` and register before `runApp`:

```dart
class MyARBackend extends ArEnginePlatform {
  @override Future<bool> isARSupported() async => true;
  @override Future<void> initSession(ARSessionConfig c) async { ... }
  @override Future<void> reconfigureSession(ARSessionConfig c) async { ... }
  @override Future<Uint8List?> captureSnapshot() async => null;
  @override Future<ARAnchor> addAnchorAtPose(ARPoseInput p) async { ... }
  // ... all other abstract members
}

void main() {
  ArEnginePlatform.instance = MyARBackend();
  runApp(const MyApp());
}
```

---

## Tests

```bash
flutter test
# verbose:
flutter test --reporter expanded
```

---

## License

MIT
