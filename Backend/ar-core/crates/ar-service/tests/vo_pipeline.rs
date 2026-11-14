//! Whole chain, no mocks: rendered camera frames + IMU + GNSS in; geo-aligned pose, planes and a
//! hit-test out. Ground truth lives in an ENU world (z up), the phone body is Android-style.
use ar_core::Intrinsics;
use ar_fusion::FusionConfig;
use ar_geo::EnuFrame;
use ar_service::protocol::{Request, Response};
use ar_service::Session;
use ar_vo::synth::{default_intrinsics, trajectory, Room};
use ar_vo::{t_body_cam_android_back, VoConfig, VoFrontend};
use base64::Engine;
use nalgebra::{Isometry3, Vector3};

const G: f64 = 9.80665;

#[test]
fn frames_imu_gnss_in_geo_aligned_pose_planes_and_hits_out() {
    let k: Intrinsics = default_intrinsics();
    let room = Room::default();
    let t_body_cam = t_body_cam_android_back();
    let cfg = FusionConfig { estimate_scale: true, t_body_cam, min_baseline_m: 3.0, ..Default::default() };
    let mut s = Session::new(cfg, Some(Box::new(VoFrontend::new(VoConfig::default()))));
    s.configure(Some(k), None).unwrap();

    // GNSS origin = where the walk starts (ENU origin is set by the first fix).
    let origin = (-6.9175, 107.6191, 700.0);
    let enu = EnuFrame::new(origin.0, origin.1, origin.2);
    let start = trajectory(0).translation.vector;
    let mut last_truth = Isometry3::identity();

    for f in 0..150usize {
        let t = f as f64 / 30.0;
        let t_wc = trajectory(f); // camera (OpenCV axes) in the room/ENU frame
        last_truth = t_wc;
        let r_wb = t_wc.rotation * t_body_cam.inverse().rotation; // body orientation in world
        let accel = r_wb.inverse() * Vector3::new(0.0, 0.0, G); // specific force of a (nearly) static body
        assert!(s.handle(Request::Imu(ar_core::ImuSample { t, gyro: Vector3::zeros(), accel })).is_ok());

        let img = room.render(&k, &t_wc);
        let data = base64::engine::general_purpose::STANDARD.encode(&img);
        match s.handle(Request::Frame { t, width: k.width, height: k.height, data }) {
            Response::Ok => {}
            other => panic!("frame {f}: {other:?}"),
        }
        if f % 3 == 0 {
            // GNSS with ~0.4 m of deterministic jitter, expressed relative to the start position.
            let p = t_wc.translation.vector - start + Vector3::new(0.4 * (f as f64 * 1.7).sin(), 0.4 * (f as f64 * 2.3).cos(), 0.2 * (f as f64).sin());
            let (la, lo, al) = enu.to_geodetic(&p);
            assert!(s.handle(Request::Gnss(ar_core::GnssFix { t, lat_deg: la, lon_deg: lo, alt_m: al, h_acc: 1.0, v_acc: 1.5 })).is_ok());
        }
    }

    let Response::Pose(p) = s.handle(Request::GetPose { predict_ms: None }) else { panic!() };
    assert!(p.geo_aligned, "map must lock to ENU from VO + GNSS: {p:?}");
    assert_eq!(format!("{:?}", p.tracking), "Tracking");
    let world = p.pose.expect("pose");
    let truth = last_truth.translation.vector - start;
    let err = (world.translation.vector - truth).norm();
    eprintln!("final position error {err:.2} m, sigma {:?}, geo {:?}", p.pos_sigma_m, p.geo.map(|g| (g.lat_deg, g.lon_deg, g.heading_deg)));
    assert!(err < 1.0, "position error {err:.2} m");
    // Camera looks north (+y) in the scene: heading should be ~0 deg (allow wrap).
    let h = p.geo.unwrap().heading_deg;
    assert!(h.min(360.0 - h) < 20.0, "heading {h}");

    // Planes straight from the frontend's landmarks (nothing uploaded by the client).
    let Response::Planes { planes } = s.handle(Request::DetectPlanes) else { panic!("detect_planes failed") };
    assert!(planes.iter().any(|pl| pl.horizontal), "expected a floor/ceiling plane: {planes:?}");
    assert!(planes.iter().any(|pl| !pl.horizontal), "expected a wall plane");

    // Cast a ray straight down from the camera: should hit the floor ~1.5 m below.
    let o = world.translation.vector;
    let Response::Hits { hits } = s.handle(Request::HitTest { origin: o.into(), dir: [0.0, 0.0, -1.0] }) else { panic!() };
    let floor = hits.iter().find(|h| h.horizontal).expect("floor hit");
    eprintln!("floor hit at {:.2} m (truth 1.5 m, scale-fit dependent)", floor.distance);
    assert!((floor.distance - 1.5).abs() < 0.5, "floor distance {}", floor.distance);
}
