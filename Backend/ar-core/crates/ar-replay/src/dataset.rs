//! Dataset loading. Two layouts:
//!  * native: `calib.json`, `imu.csv`, `frames.csv`, optional `gnss.csv` / `truth.csv`
//!  * EuRoC MAV (`mav0/` with cam0, imu0, state_groundtruth_estimate0)
use crate::imageio;
use ar_core::{GnssFix, ImuSample, Intrinsics};
use ar_vo::Distortion;
use nalgebra::{Isometry3, Matrix3, Translation3, UnitQuaternion, Vector3};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

pub struct FrameRef { pub t: f64, pub path: PathBuf }

pub struct Dataset {
    pub name: String,
    pub intrinsics: Intrinsics,
    pub distortion: Distortion,
    /// Camera -> IMU body transform.
    pub t_body_cam: Isometry3<f64>,
    pub estimate_scale: bool,
    pub imu: Vec<ImuSample>,
    pub gnss: Vec<GnssFix>,
    pub frames: Vec<FrameRef>,
    /// Ground-truth *body* positions (any consistent frame; compared after similarity alignment).
    pub truth: Vec<(f64, Vector3<f64>)>,
    /// True if `truth` is expressed in the ENU frame whose origin is the first GNSS fix, so the *fused* world pose
    /// can be scored against it too (otherwise only the similarity-aligned VO trajectory is scored).
    pub truth_is_enu: bool,
}

#[derive(Serialize, Deserialize, Default, Clone, Copy)]
pub struct DistortionFile {
    #[serde(default)] pub k1: f64,
    #[serde(default)] pub k2: f64,
    #[serde(default)] pub p1: f64,
    #[serde(default)] pub p2: f64,
    #[serde(default)] pub k3: f64,
}
impl From<DistortionFile> for Distortion { fn from(d: DistortionFile) -> Self { Distortion { k1: d.k1, k2: d.k2, p1: d.p1, p2: d.p2, k3: d.k3 } } }
impl From<Distortion> for DistortionFile { fn from(d: Distortion) -> Self { DistortionFile { k1: d.k1, k2: d.k2, p1: d.p1, p2: d.p2, k3: d.k3 } } }

fn yes() -> bool { true }

#[derive(Serialize, Deserialize)]
pub struct CalibFile {
    pub intrinsics: Intrinsics,
    #[serde(default)] pub distortion: DistortionFile,
    pub t_body_cam: Isometry3<f64>,
    #[serde(default = "yes")] pub estimate_scale: bool,
    #[serde(default)] pub truth_is_enu: bool,
}

// ---------------------------------------------------------------- csv helpers

fn read_rows(path: &Path) -> Result<Vec<Vec<String>>, String> {
    let text = std::fs::read_to_string(path).map_err(|e| format!("{}: {e}", path.display()))?;
    Ok(text.lines().map(str::trim).filter(|l| !l.is_empty() && !l.starts_with('#')).map(|l| l.split(',').map(|c| c.trim().to_string()).collect()).collect())
}

/// Numeric rows; a single non-numeric header row (first row only) is tolerated.
fn read_numeric(path: &Path, min_cols: usize) -> Result<Vec<Vec<f64>>, String> {
    let mut out = vec![];
    for (i, row) in read_rows(path)?.into_iter().enumerate() {
        let parsed: Result<Vec<f64>, _> = row.iter().map(|c| c.parse::<f64>()).collect();
        match parsed {
            Ok(v) if v.len() >= min_cols => out.push(v),
            Ok(v) => return Err(format!("{}: row {} has {} columns, need {min_cols}", path.display(), i + 1, v.len())),
            Err(_) if i == 0 => continue,
            Err(e) => return Err(format!("{}: row {}: {e}", path.display(), i + 1)),
        }
    }
    Ok(out)
}

fn sorted_by_time<T>(mut v: Vec<T>, t: impl Fn(&T) -> f64) -> Vec<T> { v.sort_by(|a, b| t(a).total_cmp(&t(b))); v }

// ---------------------------------------------------------------- native layout

pub fn load_native(dir: &Path) -> Result<Dataset, String> {
    let calib: CalibFile = serde_json::from_slice(&std::fs::read(dir.join("calib.json")).map_err(|e| format!("calib.json: {e}"))?).map_err(|e| format!("calib.json: {e}"))?;
    let imu = read_numeric(&dir.join("imu.csv"), 7)?.into_iter()
        .map(|r| ImuSample { t: r[0], gyro: Vector3::new(r[1], r[2], r[3]), accel: Vector3::new(r[4], r[5], r[6]) }).collect();
    let gnss = if dir.join("gnss.csv").exists() {
        read_numeric(&dir.join("gnss.csv"), 6)?.into_iter().map(|r| GnssFix { t: r[0], lat_deg: r[1], lon_deg: r[2], alt_m: r[3], h_acc: r[4], v_acc: r[5] }).collect()
    } else { vec![] };
    let mut frames = vec![];
    for (i, row) in read_rows(&dir.join("frames.csv"))?.into_iter().enumerate() {
        let Ok(t) = row[0].parse::<f64>() else { if i == 0 { continue } else { return Err(format!("frames.csv row {}: bad timestamp", i + 1)) } };
        let file = row.get(1).ok_or_else(|| format!("frames.csv row {}: missing filename", i + 1))?;
        frames.push(FrameRef { t, path: dir.join(file) });
    }
    let truth = if dir.join("truth.csv").exists() {
        read_numeric(&dir.join("truth.csv"), 4)?.into_iter().map(|r| (r[0], Vector3::new(r[1], r[2], r[3]))).collect()
    } else { vec![] };
    finish(Dataset {
        name: dir.file_name().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default(),
        intrinsics: calib.intrinsics, distortion: calib.distortion.into(), t_body_cam: calib.t_body_cam, estimate_scale: calib.estimate_scale, truth_is_enu: calib.truth_is_enu,
        imu: sorted_by_time(imu, |s: &ImuSample| s.t), gnss: sorted_by_time(gnss, |g: &GnssFix| g.t),
        frames: sorted_by_time(frames, |f: &FrameRef| f.t), truth: sorted_by_time(truth, |p: &(f64, Vector3<f64>)| p.0),
    })
}

// ---------------------------------------------------------------- EuRoC layout

/// Numbers inside the first `[...]` that follows `key` (searching from `from`); may span lines.
pub fn yaml_list(text: &str, from: usize, key: &str) -> Option<(Vec<f64>, usize)> {
    let k = from + text[from..].find(key)?;
    let open = k + text[k..].find('[')?;
    let close = open + text[open..].find(']')?;
    let nums = text[open + 1..close].split(|c: char| c == ',' || c.is_whitespace()).filter(|t| !t.is_empty()).map(|t| t.parse::<f64>().ok()).collect::<Option<Vec<_>>>()?;
    Some((nums, close))
}

pub struct EurocCalib { pub intrinsics: Intrinsics, pub distortion: Distortion, pub t_body_cam: Isometry3<f64> }

pub fn parse_euroc_sensor_yaml(text: &str) -> Result<EurocCalib, String> {
    let (res, _) = yaml_list(text, 0, "resolution:").ok_or("sensor.yaml: no resolution")?;
    let (k, _) = yaml_list(text, 0, "intrinsics:").ok_or("sensor.yaml: no intrinsics")?;
    let (d, _) = yaml_list(text, 0, "distortion_coefficients:").ok_or("sensor.yaml: no distortion_coefficients")?;
    let tbs = text.find("T_BS:").ok_or("sensor.yaml: no T_BS")?;
    let (m, _) = yaml_list(text, tbs, "data:").ok_or("sensor.yaml: no T_BS data")?;
    if res.len() != 2 || k.len() != 4 || d.len() < 4 || m.len() != 16 { return Err("sensor.yaml: unexpected list lengths".into()); }
    let r = Matrix3::new(m[0], m[1], m[2], m[4], m[5], m[6], m[8], m[9], m[10]);
    Ok(EurocCalib {
        intrinsics: Intrinsics { fx: k[0], fy: k[1], cx: k[2], cy: k[3], width: res[0] as u32, height: res[1] as u32 },
        distortion: Distortion { k1: d[0], k2: d[1], p1: d[2], p2: d[3], k3: 0.0 },
        t_body_cam: Isometry3::from_parts(Translation3::new(m[3], m[7], m[11]), UnitQuaternion::from_matrix(&r)),
    })
}

pub fn load_euroc(dir: &Path) -> Result<Dataset, String> {
    let root = if dir.join("mav0").is_dir() { dir.join("mav0") } else { dir.to_path_buf() };
    let cam = root.join("cam0");
    let calib = parse_euroc_sensor_yaml(&std::fs::read_to_string(cam.join("sensor.yaml")).map_err(|e| format!("cam0/sensor.yaml: {e}"))?)?;

    let ns = |s: &str| s.parse::<i64>().map_err(|e| format!("bad timestamp '{s}': {e}"));
    let frame_rows = read_rows(&cam.join("data.csv"))?;
    let imu_rows = read_rows(&root.join("imu0/data.csv"))?;
    let t0 = frame_rows.iter().chain(&imu_rows).filter_map(|r| r.first().and_then(|s| s.parse::<i64>().ok())).min().ok_or("no timestamps found")?;
    let sec = |n: i64| (n - t0) as f64 * 1e-9; // subtract first: raw epoch-ns exceed f64's exact integer range

    let mut frames = vec![];
    for r in &frame_rows {
        let (Ok(t), Some(file)) = (ns(&r[0]), r.get(1)) else { continue };
        frames.push(FrameRef { t: sec(t), path: cam.join("data").join(file) });
    }
    let mut imu = vec![];
    for r in &imu_rows {
        if r.len() < 7 { continue; }
        let Ok(t) = ns(&r[0]) else { continue };
        let v: Result<Vec<f64>, _> = r[1..7].iter().map(|c| c.parse::<f64>()).collect();
        let v = v.map_err(|e| format!("imu0/data.csv: {e}"))?;
        imu.push(ImuSample { t: sec(t), gyro: Vector3::new(v[0], v[1], v[2]), accel: Vector3::new(v[3], v[4], v[5]) });
    }
    let gt_path = root.join("state_groundtruth_estimate0/data.csv");
    let mut truth = vec![];
    if gt_path.exists() {
        for r in read_rows(&gt_path)? {
            let (Some(t), true) = (r.first().and_then(|s| ns(s).ok()), r.len() >= 4) else { continue };
            let p: Result<Vec<f64>, _> = r[1..4].iter().map(|c| c.parse::<f64>()).collect();
            if let Ok(p) = p { truth.push((sec(t), Vector3::new(p[0], p[1], p[2]))); }
        }
    }
    finish(Dataset {
        name: root.parent().and_then(|p| p.file_name()).map(|s| s.to_string_lossy().into_owned()).unwrap_or_else(|| "euroc".into()),
        intrinsics: calib.intrinsics, distortion: calib.distortion, t_body_cam: calib.t_body_cam, estimate_scale: true, truth_is_enu: false,
        imu: sorted_by_time(imu, |s: &ImuSample| s.t), gnss: vec![],
        frames: sorted_by_time(frames, |f: &FrameRef| f.t), truth: sorted_by_time(truth, |p: &(f64, Vector3<f64>)| p.0),
    })
}

fn finish(ds: Dataset) -> Result<Dataset, String> {
    if ds.frames.is_empty() { return Err("dataset has no frames".into()); }
    if ds.imu.is_empty() { return Err("dataset has no IMU samples".into()); }
    ar_vo_validate(&ds.intrinsics)?;
    if let Some(f) = ds.frames.iter().find(|f| !f.path.exists()) { return Err(format!("missing image {}", f.path.display())); }
    Ok(ds)
}

fn ar_vo_validate(k: &Intrinsics) -> Result<(), String> {
    if k.fx <= 0.0 || k.fy <= 0.0 || k.width == 0 || k.height == 0 { Err("invalid intrinsics".into()) } else { Ok(()) }
}

/// Check the first image against the calibration (catches swapped / cropped / downscaled data early).
pub fn check_first_frame(ds: &Dataset) -> Result<(), String> {
    let img = imageio::load_gray(&ds.frames[0].path)?;
    if (img.w as u32, img.h as u32) != (ds.intrinsics.width, ds.intrinsics.height) {
        return Err(format!("image is {}x{} but calibration says {}x{}", img.w, img.h, ds.intrinsics.width, ds.intrinsics.height));
    }
    Ok(())
}
