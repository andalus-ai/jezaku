use ar_core::{GnssFix, ImuSample, Intrinsics, VisualPose};
use nalgebra::Isometry3;

fn fin(v: &[f64]) -> bool { v.iter().all(|x| x.is_finite()) }

pub fn isometry(p: &Isometry3<f64>) -> Result<(), String> {
    let t = p.translation.vector;
    let q = p.rotation.as_ref();
    if !fin(&[t.x, t.y, t.z, q.i, q.j, q.k, q.w]) { return Err("pose contains non-finite values".into()); }
    if (q.norm() - 1.0).abs() > 1e-3 { return Err("rotation quaternion is not unit length".into()); }
    if t.norm() > 1e7 { return Err("translation magnitude out of range".into()); }
    Ok(())
}

pub fn imu(s: &ImuSample) -> Result<(), String> {
    if !fin(&[s.t, s.gyro.x, s.gyro.y, s.gyro.z, s.accel.x, s.accel.y, s.accel.z]) { return Err("imu: non-finite value".into()); }
    if s.gyro.norm() > 35.0 { return Err("imu: |gyro| > 35 rad/s".into()); }
    if s.accel.norm() > 160.0 { return Err("imu: |accel| > 160 m/s^2".into()); }
    Ok(())
}

pub fn gnss(g: &GnssFix) -> Result<(), String> {
    if !fin(&[g.t, g.lat_deg, g.lon_deg, g.alt_m, g.h_acc, g.v_acc]) { return Err("gnss: non-finite value".into()); }
    if !(-90.0..=90.0).contains(&g.lat_deg) || !(-180.0..=180.0).contains(&g.lon_deg) { return Err("gnss: lat/lon out of range".into()); }
    if !(-1000.0..=100_000.0).contains(&g.alt_m) { return Err("gnss: altitude out of range".into()); }
    if g.h_acc <= 0.0 || g.v_acc <= 0.0 { return Err("gnss: accuracies must be positive".into()); }
    Ok(())
}

pub fn visual(v: &VisualPose) -> Result<(), String> {
    if !v.t.is_finite() { return Err("visual: non-finite timestamp".into()); }
    if !(0.0..=1.0).contains(&v.quality) { return Err("visual: quality must be within [0,1]".into()); }
    isometry(&v.t_map_cam)
}

pub fn intrinsics(i: &Intrinsics) -> Result<(), String> {
    if !fin(&[i.fx, i.fy, i.cx, i.cy]) || i.fx <= 0.0 || i.fy <= 0.0 { return Err("intrinsics: invalid focal length / principal point".into()); }
    if i.width == 0 || i.height == 0 || (i.width as u64 * i.height as u64) > 16_000_000 { return Err("intrinsics: invalid image size".into()); }
    Ok(())
}

/// Session names become file names: keep them boring.
pub fn session_name(n: &str) -> Result<(), String> {
    if n.is_empty() || n.len() > 64 || !n.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_') {
        return Err("session name must be 1-64 chars of [A-Za-z0-9_-]".into());
    }
    Ok(())
}
