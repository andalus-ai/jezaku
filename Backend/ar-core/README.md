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
| visual frontend | feature tracking / mapping / relocalisation | **next** |

    cargo test --workspace
    AR_TOKEN=secret cargo run -p ar-service --bin ar-serviced -- --bind 127.0.0.1:7878 --store-dir ./sessions

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

## Known limits
- Scale of monocular frontends needs `FusionConfig::estimate_scale = true`; geo-alignment needs ≥~2 m of GNSS-paired motion.
- No TLS, no per-client rate limiting; bind to localhost or front with a TLS proxy. Token auth is a shared secret.
- Visual poses enter the filter loosely coupled; camera–IMU extrinsics are configured, not estimated.
- Fusion/service validated on synthetic data only, not real device sensors.
