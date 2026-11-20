# AR Device Demo Lab

This guide defines the device-first workflow for exercising Jejaku's AR functionality without requiring the backend for the core camera and local-capture path.

## Start the AR viewer

From `UI/jezaku`:

```bash
./scripts/run_android_device.sh --ar-offline
```

For build/install/launch without attaching the Flutter VM service:

```bash
./scripts/run_android_device.sh --ar-offline --install-start
```

The `--ar-offline` flag disables FCM and starts the AR viewer as the initial route. It is a developer convenience mode, not a production authentication policy.

## What this mode guarantees

- The normal home-screen route is skipped.
- Firebase Cloud Messaging is disabled for this launch.
- AR camera permission and AR session initialization still run normally.
- Existing AR snapshot and recording controls remain available when the device/backend supports them.

## Important boundaries

Starting directly in the AR viewer does **not** prove that every feature is fully offline. The AR viewer still initializes the app's normal Riverpod providers, location services, local persistence, model cache and scene synchronization code. Some providers or cloud-anchor paths may attempt network access. Cloud-backed memories, remote model downloads, account features and synchronization are not part of this offline test contract.

Do not weaken production authentication or authorization to make device testing work. Any future demo-only auth bypass must be compile-time gated, debug-only, visibly marked, and incapable of being enabled in release builds.

## Device test checklist

### 1. Runtime and permissions

- [ ] Install on a supported physical ARCore device.
- [ ] Grant camera permission.
- [ ] Grant location permission when testing geospatial placement.
- [ ] Confirm camera preview starts and the AR session reports tracking.
- [ ] Background and resume the app; confirm the session recovers or shows an actionable error.
- [ ] Deny camera permission and confirm the permission recovery UI is usable.

### 2. Tracking and placement

- [ ] Scan a textured, well-lit surface.
- [ ] Confirm plane detection and placement readiness diagnostics update.
- [ ] Move slowly around the surface and check pose stability.
- [ ] Test relocalization after briefly pointing the camera away.
- [ ] Confirm unsupported device capabilities are reported rather than silently failing.

### 3. Free-space photo frame rendering

**Placement contract: frames float freely in tracked AR world space. They are not wall-mounted.** A detected plane may be used as an optional placement aid, but plane detection must not be a prerequisite for placing a frame. The user can position a frame at arbitrary reachable height, depth and orientation in front of the camera, including in open air, above furniture, or as part of a floating gallery.

Frames should use a stable world-space pose (position and rotation) so they remain visually anchored while the user walks around them. The placement flow should support preview, confirm, reposition, rotate, scale, select and delete. Where the runtime cannot maintain tracking, show a clear tracking warning rather than silently snapping frames to a wall or floor.

The package currently provides these frame presets through `JejakuHangingPhotoFrameStyle`:

- `classic`
- `thin`
- `darkGallery`
- `floatingGlass`

For each preset, validate front/back material visibility, border proportions, photo recess, depth, transparency where applicable, and behavior at different viewing angles. Test frames at multiple world-space positions and rotations, including positions with no detected plane nearby. A local fixture gallery that creates these frames without account-backed memory records is a follow-up implementation task; the current launcher does not seed sample memories automatically.

#### AR debug log (for wireless debugging that keeps disconnecting)

The viewer has an opt-in debug log. Every line goes to the terminal (`debugPrint`, prefix `[ARDBG]`, visible in `flutter run` and `adb logcat | rg ARDBG`) **and** is appended to a file on the phone, so nothing is lost when the connection drops. The file is capped at 512 KB (plus one rotated copy). Lines contain memory ids, counts and session-relative poses only; no photos, captions, user ids or coordinates.

Turn it on with either:

- `--dart-define=AR_DEBUG_LOG=true` (already set by `scripts/run_demo_android.sh` and `run_android_device.sh --ar-offline`), or
- the **Record AR debug log** switch in the AR diagnostics sheet (tap the "native anchors" chip at the bottom of the viewer).

Get the log back:

- In the app: diagnostics sheet, **Copy debug log**, then paste it where you need it. **Clear** empties it. This always works.
- From a computer after reconnecting: `./scripts/pull_ar_debug_log.sh [output-file]` (reads `/sdcard/Android/data/tech.kayys.jezaku/files/`, falling back to `run-as` on debuggable builds).

What it records, one line each: `session` (native view created), `lifecycle`, `health` (placement readiness and issues, on change), `select` (focused / native / pinned frame ids, on change), `planner` (GPS-placed frame ids, on change), `origin` (viewer moved more than 10 m), `scene` (every native sync: added, updated, removed, active ids, how each frame was placed, `took=` milliseconds), `frame` (hanging-frame capture) and `rehang`.

When frames vanish, look at the `scene` lines around that moment: `removed=[...]` names the frame, and `select`, `origin` and `session` lines just before it show why. Long `took=` values point at lag.

Status: unit-tested only; not yet exercised on a physical device or on a real file system on Android.

#### Saved-frame visibility and HUD (check on a device)

The viewer places saved frames in the native AR scene using a viewing health policy (`ARViewerHealthPolicy.viewing`). Low light and "no tracked planes" no longer block placement of frames that already have a stored pose; camera, tracking and session-lifecycle problems still do. Capture flows that create new anchors keep the stricter `ARSessionHealthPolicy.placementReadiness`. Frames already placed natively get no 2D card; at most three 2D fallback cards appear for on-screen memories the scene has not placed.

These behaviours are covered by unit tests only. They have **not** been validated on a physical device. Record the result of each check below before treating the issue as fixed.

- [ ] In a dim room and facing a blank wall, saved frames still appear in the camera view and stay put when you walk around them (world-anchored, not screen-fixed).
- [ ] The HUD "native anchors" count matches the number of saved frames in range.
- [ ] At most three 2D fallback cards are shown, and none for frames visible in AR.
- [ ] The "Hide UI" button (top left, next to Back) hides everything except Back and "Show UI": chips, radar, tracking hints, info dashboard, HUD settings, photo-card toggle, aim guide, List and Capture. Tapping "Show UI" restores them. While a recording is running its controls stay visible so it can be stopped.
- [ ] Top-bar buttons no longer overlap the status chips on a narrow phone and at a large text scale.
- [ ] If frames are still missing, collect `adb logcat | grep -E "AR_HANGING_FRAME|AREngine/ARCoreGLRenderer"` and attach it to the issue.

#### Frames across AR sessions (known limitation)

A frame's stored AR pose (`localAnchorPose`) is expressed in the coordinate frame of the native AR session that captured it. It is used only while that same session is running (`LocalPoseValidity`); closing the viewer, or any restart of the native AR view, invalidates it. Frames from earlier sessions fall back to GPS/compass placement, which is inaccurate indoors and is **not** a wall-fixed hanging frame. Cloud Anchors, which would persist poses across sessions, are currently disabled (`_resolvedSessionCloudAnchorsEnabled = false`).

- [ ] Capture and publish a frame, stay in the viewer: it hangs on the wall.
- [ ] The viewer's **Capture** button photographs the live AR view (review dialog, then Publish). It must not open the separate camera screen: that screen competes with ARCore for the camera, which leaves AR stale and, when it cannot get a live frame, saves a generated "JEJAKU SAFE CAPTURE" image instead of a photo. The hung frame must show the photo you just took. If no camera frame is available the viewer says so and saves nothing.
- [ ] Capture a second and third frame without leaving the viewer; AR must stay tracking (no "AR stale").
- [ ] Leave and reopen the viewer: the frame is expected to appear approximate (GPS-placed). Focus it: the focused-anchor card shows "Placed from GPS..." with a **Re-hang here** button.
- [ ] Aim the center of the screen at the wall and tap **Re-hang here**: the frame should snap onto the wall and stay there while you walk around. The prompt disappears for that frame.
- [ ] Re-hang with tracking not ready (cover the camera): a message asks you to move the phone; nothing changes.
- [ ] Close and reopen the viewer: re-hung frames are session-scoped, so the prompt returns (until a persistence backend exists).

### 4. Snapshot and recording

- [ ] Capture an AR snapshot after tracking stabilizes.
- [ ] Confirm the capture result is reported and the output is available to the local capture flow.
- [ ] Start a screen recording, pause, resume and stop it.
- [ ] Confirm elapsed time, frame count and live FPS diagnostics update.
- [ ] Test cancellation and verify a cancelled recording is not presented as a successful export.
- [ ] Repeat with low light and device thermal/load conditions.

### 5. Offline behavior

- [ ] Enable airplane mode after the app is installed.
- [ ] Relaunch with `--ar-offline` and verify the camera/AR session still starts.
- [ ] Confirm cloud-only features degrade with clear diagnostics.
- [ ] Confirm local capture does not require login or a backend response.
- [ ] Re-enable connectivity and verify the app does not silently duplicate local capture records.

## Device and build notes

- Use a physical ARCore-supported Android device; emulator behavior is not representative for camera tracking.
- Keep the device charged and allow thermal stabilization for repeatable performance measurements.
- Record device model, Android version, ARCore version, build mode and test conditions with any bug report.
- Prefer a debug build for diagnostics. Use the install/start path when VM-service attachment is unstable.

## Follow-up implementation

The next Demo Lab increment should add a debug-only local fixture gallery with bundled sample photographs, one in-memory sample per frame preset, free-space world-pose placement controls (not wall-only placement), and a local capture review screen. The fixtures must be isolated from production memory providers and must not create cloud anchors or account records.
