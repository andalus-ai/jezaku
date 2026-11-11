//! Writes a synthetic dataset (rendered frames + physically derived IMU) in the native or EuRoC layout.
use crate::dataset::{CalibFile, DistortionFile};
use crate::imageio;
use ar_geo::EnuFrame;
use ar_vo::synth::{default_intrinsics, trajectory_at, Room};
use ar_vo::{t_body_cam_android_back, Distortion};
use nalgebra::{Isometry3, UnitQuaternion, Vector3};
use std::fmt::Write as _;
use std::path::Path;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Layout { Native, Euroc }

#[derive(Clone, Debug)]
pub struct GenOpts {
    pub frames: usize,
    pub fps: f64,
    pub imu_hz: f64,
    pub distortion: Distortion,
    pub imu_noise: bool,
    pub layout: Layout,
}
impl Default for GenOpts {
    fn default() -> Self { Self { frames: 150, fps: 30.0, imu_hz: 200.0, distortion: Distortion::default(), imu_noise: false, layout: Layout::Native } }
}

const G: f64 = 9.80665;
const ORIGIN: (f64, f64, f64) = (-6.9175, 107.6191, 700.0);
const EUROC_T0_NS: i64 = 1_403_636_579_763_555_584;

fn noise(i: usize, ch: usize) -> f64 {
    let mut h = (i as u32).wrapping_mul(2_654_435_761) ^ (ch as u32).wrapping_mul(0x9E37_79B1);
    h ^= h >> 15; h = h.wrapping_mul(0x2C1B_3C6D); h ^= h >> 12;
    ((h & 0xFFFF) as f64 / 65535.0 - 0.5) * 3.4 // ~unit std
}

pub fn generate(dir: &Path, o: &GenOpts) -> Result<(), String> {
    let io = |e: std::io::Error| e.to_string();
    let (room, k) = (Room::default(), default_intrinsics());
    let t_body_cam = t_body_cam_android_back();
    let t_cb = t_body_cam.inverse();
    let start = trajectory_at(0.0).translation.vector;
    let body = |t: f64| -> Isometry3<f64> { trajectory_at(t * o.fps) * t_cb }; // body pose in the room/ENU frame
    let duration = (o.frames - 1) as f64 / o.fps;

    let (root, cam_dir, img_ext): (_, _, &str) = match o.layout {
        Layout::Native => (dir.to_path_buf(), dir.join("frames"), "pgm"),
        Layout::Euroc => (dir.join("mav0"), dir.join("mav0/cam0/data"), "png"),
    };
    std::fs::create_dir_all(&cam_dir).map_err(io)?;

    // ---- frames
    let ts_ns = |t: f64| EUROC_T0_NS + (t * 1e9).round() as i64;
    let mut frames_csv = String::new();
    let mut gt_csv = String::new();
    for f in 0..o.frames {
        let t = f as f64 / o.fps;
        let img = room.render_with(&k, &o.distortion, &trajectory_at(f as f64));
        let (name, row) = match o.layout {
            Layout::Native => (format!("{f:05}.pgm"), format!("{t:.6},frames/{f:05}.pgm\n")),
            Layout::Euroc => (format!("{}.png", ts_ns(t)), format!("{},{}.png\n", ts_ns(t), ts_ns(t))),
        };
        let path = cam_dir.join(&name);
        match img_ext { "pgm" => imageio::write_pgm(&path, k.width as usize, k.height as usize, &img)?, _ => imageio::write_png_gray(&path, k.width as usize, k.height as usize, &img)? }
        frames_csv += &row;
        let (p, q) = (body(t).translation.vector - start, body(t).rotation);
        match o.layout {
            Layout::Native => writeln!(gt_csv, "{t:.6},{:.6},{:.6},{:.6}", p.x, p.y, p.z).unwrap(),
            Layout::Euroc => writeln!(gt_csv, "{},{:.9},{:.9},{:.9},{:.9},{:.9},{:.9},{:.9},0,0,0,0,0,0,0,0,0", ts_ns(t), p.x, p.y, p.z, q.w, q.i, q.j, q.k).unwrap(),
        }
    }

    // ---- IMU from the true motion: a = R^T (a_world + g), w = Log(R(t-h/2)^T R(t+h/2)) / h
    let h = 1.0 / o.imu_hz;
    let n_imu = (duration * o.imu_hz) as usize + 1;
    let mut imu_csv = String::new();
    for i in 0..n_imu {
        let t = i as f64 * h;
        // Differentiate at an interior point: a one-sided difference at t=0 yields a bogus ~v/h acceleration.
        let tc = t.max(h);
        let (p0, p1, p2) = (body(tc - h).translation.vector, body(tc).translation.vector, body(tc + h).translation.vector);
        let a_world = (p0 - 2.0 * p1 + p2) / (h * h);
        let r = body(tc).rotation;
        let w = (body(tc - 0.5 * h).rotation.inverse() * body(tc + 0.5 * h).rotation).scaled_axis() / h;
        let mut a = r.inverse() * (a_world + Vector3::new(0.0, 0.0, G));
        let mut g = w;
        if o.imu_noise { for c in 0..3 { a[c] += 0.02 * noise(i, c); g[c] += 0.002 * noise(i, c + 3); } }
        match o.layout {
            Layout::Native => writeln!(imu_csv, "{t:.6},{:.6},{:.6},{:.6},{:.6},{:.6},{:.6}", g.x, g.y, g.z, a.x, a.y, a.z).unwrap(),
            Layout::Euroc => writeln!(imu_csv, "{},{:.9},{:.9},{:.9},{:.9},{:.9},{:.9}", ts_ns(t), g.x, g.y, g.z, a.x, a.y, a.z).unwrap(),
        }
    }

    // ---- write metadata per layout
    match o.layout {
        Layout::Native => {
            let calib = CalibFile { intrinsics: k, distortion: DistortionFile::from(o.distortion), t_body_cam, estimate_scale: true, truth_is_enu: true };
            std::fs::write(root.join("calib.json"), serde_json::to_vec_pretty(&calib).map_err(|e| e.to_string())?).map_err(io)?;
            std::fs::write(root.join("imu.csv"), format!("t_s,gx,gy,gz,ax,ay,az\n{imu_csv}")).map_err(io)?;
            std::fs::write(root.join("frames.csv"), format!("t_s,file\n{frames_csv}")).map_err(io)?;
            std::fs::write(root.join("truth.csv"), format!("t_s,x,y,z\n{gt_csv}")).map_err(io)?;
            // GNSS at 5 Hz with ~0.4 m of deterministic jitter, expressed in the ENU frame at the start position.
            let enu = EnuFrame::new(ORIGIN.0, ORIGIN.1, ORIGIN.2);
            let mut gnss = String::from("t_s,lat,lon,alt,h_acc,v_acc\n");
            let n = (duration * 5.0) as usize + 1;
            for j in 0..n {
                let t = j as f64 / 5.0;
                let jitter = Vector3::new(0.4 * (j as f64 * 1.7).sin(), 0.4 * (j as f64 * 2.3).cos(), 0.2 * (j as f64).sin());
                let (la, lo, al) = enu.to_geodetic(&(body(t).translation.vector - start + jitter));
                writeln!(gnss, "{t:.6},{la:.9},{lo:.9},{al:.4},1.0,1.5").unwrap();
            }
            std::fs::write(root.join("gnss.csv"), gnss).map_err(io)?;
        }
        Layout::Euroc => {
            let m = t_body_cam.to_homogeneous();
            let rows: Vec<String> = (0..4).map(|r| (0..4).map(|c| format!("{:.12}", m[(r, c)])).collect::<Vec<_>>().join(", ")).collect();
            let d = o.distortion;
            let yaml = format!(
                "sensor_type: camera\ncomment: synthetic (ar-replay gen)\n\n# Sensor extrinsics wrt. the body-frame.\nT_BS:\n  cols: 4\n  rows: 4\n  data: [{},\n         {},\n         {},\n         {}]\n\nrate_hz: {}\nresolution: [{}, {}]\ncamera_model: pinhole\nintrinsics: [{}, {}, {}, {}] #fu, fv, cu, cv\ndistortion_model: radial-tangential\ndistortion_coefficients: [{}, {}, {}, {}]\n",
                rows[0], rows[1], rows[2], rows[3], o.fps, k.width, k.height, k.fx, k.fy, k.cx, k.cy, d.k1, d.k2, d.p1, d.p2);
            std::fs::write(root.join("cam0/sensor.yaml"), yaml).map_err(io)?;
            std::fs::write(root.join("cam0/data.csv"), format!("#timestamp [ns],filename\n{frames_csv}")).map_err(io)?;
            std::fs::create_dir_all(root.join("imu0")).map_err(io)?;
            std::fs::write(root.join("imu0/data.csv"), format!("#timestamp [ns],w_RS_S_x [rad s^-1],w_RS_S_y [rad s^-1],w_RS_S_z [rad s^-1],a_RS_S_x [m s^-2],a_RS_S_y [m s^-2],a_RS_S_z [m s^-2]\n{imu_csv}")).map_err(io)?;
            std::fs::create_dir_all(root.join("state_groundtruth_estimate0")).map_err(io)?;
            std::fs::write(root.join("state_groundtruth_estimate0/data.csv"), format!("#timestamp, p_RS_R_x [m], p_RS_R_y [m], p_RS_R_z [m], q_RS_w [], q_RS_x [], q_RS_y [], q_RS_z [], v_RS_R_x [m s^-1], v_RS_R_y [m s^-1], v_RS_R_z [m s^-1], b_w_RS_S_x [rad s^-1], b_w_RS_S_y [rad s^-1], b_w_RS_S_z [rad s^-1], b_a_RS_S_x [m s^-2], b_a_RS_S_y [m s^-2], b_a_RS_S_z [m s^-2]\n{gt_csv}")).map_err(io)?;
        }
    }
    let _ = UnitQuaternion::<f64>::identity();
    Ok(())
}
