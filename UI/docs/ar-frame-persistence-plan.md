# AR frame persistence plan

Status: proposal. Stage 1 is implemented; stages 2–4 are not started and have not been validated on a device.

## Problem

A hanging frame's AR pose (`AnchorLocalPose`) is expressed in the coordinate frame of the native AR session that captured it. When the viewer is closed or the AR session restarts, that frame is gone, so the pose is meaningless (`LocalPoseValidity`). Frames from earlier sessions fall back to GPS/compass placement, which is approximate (several metres indoors) and not wall-fixed.

Google Cloud Anchors, which would solve this, are disabled in the app (`_resolvedSessionCloudAnchorsEnabled = false`) and the product direction is to use the project's own `ar-core` backend instead.

## What ar-core can and cannot do today

| Capability | Status |
|---|---|
| Fuse IMU + GNSS + visual poses into an ENU world pose and geo pose | done |
| `geo` anchors (lat/lon/alt/heading) that persist across restarts | done |
| `map` anchors tied to a visual map | lost whenever the map resets, never persisted |
| Visual relocalisation against a stored map | **not available** (README: "No bundle adjustment, loop closure or relocalisation") |
| Reachable from the mobile app | **no**: NDJSON over TCP, not wired to the app or to any Quarkus service |

Consequence: storing frames in ar-core today yields geo anchors only. That is the same accuracy as the current GPS fallback, so it would not make frames hang on the wall across sessions. The missing piece is **visual relocalisation**, which is also Phase 3 of the adopted roadmap (keyframes, bundle adjustment, loop closure, relocalisation).

## Stages

1. **Offline re-hang (done).** Frames without a pose valid in this session show "Re-hang here". The user aims at the wall; a fresh session pose is stored. Works with no backend. Cost: once per frame per session.
2. **Anchor record service (needs a decision on where it lives).** Persist per frame, next to the memory: geo position and heading at hang time, the wall plane (normal, height, extent), hang distance and a confidence. Expose it through the existing `memory` service (HTTP, auth, ownership checks) rather than speaking ar-core's TCP protocol from the phone. Use it to *assist* re-hang: show the expected wall, auto-snap to the nearest detected vertical plane whose normal and height match, and ask for one confirmation tap. Still no visual matching.
3. **Visual keyframe map in ar-core.** Store compact keyframes (feature descriptors and poses) per place as the user hangs frames. Add relocalisation to `ar-vo`/`ar-service`: given a few query frames, return the pose of the device in the stored map. Needs real-device datasets (`ar-replay` currently verified on synthetic data only).
4. **Client integration.** On session start the app streams a few frames (or descriptors) to the relocalisation endpoint, receives a map→session transform and places stored frames automatically. Re-hang remains the fallback when relocalisation fails or confidence is low.

## Design rules

- Keep one interface in the app (for example `FramePoseSource`) with implementations for session pose, assisted re-hang and relocalised pose, so the viewer does not know which one placed a frame.
- Never trust a client-supplied user id on the new endpoints; reuse the auth already in `common`.
- Treat "relocalising", "low confidence" and "unavailable" as first-class states in the UI, with Re-hang as the always-available action.
- Do not claim a persistence stage works until it has been checked on a physical device and the result is recorded in `ar-device-demo-lab.md`.

## Decisions needed

1. Stage 2 storage: extend the `memory` service, or add a dedicated spatial-anchor service?
2. Transport for stage 3/4: a Quarkus gateway in front of `ar-serviced`, or a native HTTP/gRPC endpoint in `ar-service`?
3. Privacy: keyframes show the inside of people's homes. Retention, who can read them, and deletion with the memory must be settled before stage 3.
