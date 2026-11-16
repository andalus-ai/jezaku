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

### 3. Photo frame rendering

The package currently provides these frame presets through `JejakuHangingPhotoFrameStyle`:

- `classic`
- `thin`
- `darkGallery`
- `floatingGlass`

For each preset, validate front/back material visibility, border proportions, photo recess, depth, transparency where applicable, and behavior at different viewing angles. A local fixture gallery that creates these frames without account-backed memory records is a follow-up implementation task; the current launcher does not seed sample memories automatically.

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

The next Demo Lab increment should add a debug-only local fixture gallery with bundled sample photographs, one in-memory sample per frame preset, direct placement controls, and a local capture review screen. The fixtures must be isolated from production memory providers and must not create cloud anchors or account records.
