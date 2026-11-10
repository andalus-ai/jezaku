# rs-ar — an ARCore-style AR service in Rust

Replacement for the unmaintained C++ `openvslam_gps_fusion` fork. Fusion is an explicit, tested
estimator; the visual frontend is a swappable trait; the service exposes an ARCore-like session API.

| crate | role | status |
|---|---|---|
| `ar-core` | sensor/pose types, `VisualFrontend` trait | done |
| `ar-geo` | WGS84 ↔ ECEF ↔ ENU | done |
| `ar-fusion` | 15-state ESKF (IMU+GNSS+visual), continuous map→ENU alignment, map-epoch resets, GNSS-divergence recovery, geo pose + heading, pose prediction | done |
| `ar-planes` | sequential RANSAC planes with patch extents + ray hit-test | done |
| `ar-service` | tokio NDJSON/TCP service: auth, limits, anchors, persistence, push poses, metrics | done |
| `ar-vo` | pure-Rust monocular visual odometry (`VoFrontend`): Shi-Tomasi + pyramidal KLT, essential-matrix init, PnP tracking, incremental triangulation, point-cloud map | done, tested on rendered scenes |

    cargo test --workspace
    AR_TOKEN=secret cargo run --release -p ar-service --bin ar-serviced -- --bind 127.0.0.1:7878 --store-dir ./sessions --frontend vo

`--frontend vo` runs the built-in visual odometry per connection (clients send `hello` with intrinsics, then `frame`s).
Without it, clients stream their own `visual` poses.

Cargo.lock pins `tokio 1.38` / `tokio-util 0.7.11` (built on rustc 1.75); `cargo update` freely on a newer toolchain.

## Protocol (one JSON object per line)
Request `{"id":7,"type":"get_pose","predict_ms":16}` → response `{"id":7,"type":"pose",...}`.
**Without `id`, successful responses are suppressed** (stream IMU/GNSS/visual at full rate); errors are always sent.
Errors: `{"type":"error","code":"unauthorized|invalid_value|bad_request|not_ready|not_found|conflict|busy|unsupported|internal","message":"..."}`.
All timestamps share one monotonic clock (seconds). World frame is ENU (z up).

| request | purpose |
|---|---|
| `hello {session?, token?, intrinsics?, t_body_cam?}` | auth, resume a named session, set camera calibration. Required first if the server has a token |
| `imu {t,gyro,accel}` / `gnss {t,lat_deg,lon_deg,alt_m,h_acc,v_acc}` | sensor stream |
| `visual {t,t_map_cam,quality,map_id}` | frontend pose. **Change `map_id` whenever the map is reset** |
| `frame {t,width,height,data(base64 gray8)}` | runs the server-side frontend (once one is plugged in) |
| `map_points {points}` | sparse map points (frontend map frame) for plane finding |
| `get_pose {predict_ms?}` | world pose, velocity, σ, tracking state, geo pose (lat/lon/alt/heading/accuracy) |
| `subscribe {hz}` | server pushes `pose` messages (0 stops, max 60) |
| `create_anchor {pose}` / `create_geo_anchor {lat_deg,lon_deg,alt_m,heading_deg}` / `remove_anchor {anchor_id}` / `list_anchors` | anchors |
| `detect_planes` / `hit_test {origin,dir}` | planes (ENU) and nearest-first ray hits |
| `save` / `stats` | persist named session / counters |

Anchor semantics: `map` anchors ride along when the alignment is refined and become `stopped` when the map resets;
`geo` anchors are independent of any map and persist across restarts; `world` anchors are fixed ENU poses created
before alignment. States: `tracking`, `paused` (waiting for GNSS origin / alignment), `stopped`.
Map anchors are not persisted (the map isn't); world and geo anchors are, together with the ENU origin.

## Visual frontend (`ar-vo`)
Conventions: input is **undistorted** 8-bit grayscale; poses are camera→map with OpenCV axes (x right, y down, z forward).
The map frame is the first camera of each map and its **scale is arbitrary** (unit initial baseline), so fusion runs with
`estimate_scale = true`. `ar-serviced --frontend vo` defaults the body↔camera extrinsic to a back camera on an
Android-style sensor frame (`t_body_cam_android_back()`); send `hello.t_body_cam` for other devices.
No bundle adjustment, loop closure or relocalisation: on loss the map is dropped and a new `map_id` starts (anchors tied to
the old map become `stopped`, geo anchors are unaffected). Landmarks of finished tracks are kept in a bounded point-cloud
map (ring buffer, 6000 points) which feeds plane detection.
Fusion aligns map→ENU using gravity (IMU + visual attitude) so only yaw/translation/scale come from GNSS; this is what
makes near-planar walks well-conditioned.

Measured on rendered scenes (320x240, known ground truth, scale-aligned): 0.3% ATE of path / 0.6° max rotation error on clean
frames; 0.5% under sensor noise + exposure drift; abandons a blacked-out map with a new `map_id` and re-initialises.
Speed in a release build, single thread: median 26 ms/frame (p95 36 ms) at 320x240. Pose *output* can still run at IMU
rate via `get_pose {predict_ms}` / `subscribe`.

## Known limits
- Geo-alignment needs real motion (default: ~8 m spread of GNSS-paired positions) and decent GNSS (`h_acc` ≤ 30 m); expect alignment error of the order of GNSS noise.
- No TLS, no per-client rate limiting; bind to localhost or front with a TLS proxy. Token auth is a shared secret.
- Visual poses enter the filter loosely coupled; camera–IMU extrinsics are configured, not estimated.
- **Everything is validated on synthetic data only** (procedural textures, noise-free geometry, ideal IMU). Real cameras bring rolling
  shutter, motion blur, lens distortion, auto-exposure, dynamic objects and IMU/camera time offsets; expect to tune and extend.
- VO has no optimisation backend, so drift accumulates on long trajectories; frame time grows ~4x at 640x480 (detector and KLT are
  scalar code: next steps are an integral-image detector, rayon/SIMD KLT).
- Plane finding is a single RANSAC pass over the point cloud (inlier band scales with point distance), not incremental ARCore-style planes.
