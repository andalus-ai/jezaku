//! In-process replay of a recorded dataset through the real service `Session`.
use crate::dataset::{check_first_frame, Dataset};
use crate::eval::{ate_per_map, truth_at, SegmentAte};
use crate::imageio;
use ar_core::{Intrinsics, TrackingState, VisualFrontend, VisualPose};
use ar_fusion::FusionConfig;
use ar_service::protocol::{Request, Response};
use ar_service::Session;
use ar_vo::{Undistorter, VoConfig, VoFrontend};
use nalgebra::Isometry3;
use serde::Serialize;
use std::sync::{Arc, Mutex};
use std::time::Instant;

#[derive(Debug, Clone)]
pub struct ReplayOpts {
    /// Added to every IMU timestamp (positive = IMU clock runs ahead of the camera clock). For sensitivity tests.
    pub imu_offset_s: f64,
    pub max_frames: Option<usize>,
    pub min_baseline_m: f64,
}
impl Default for ReplayOpts { fn default() -> Self { Self { imu_offset_s: 0.0, max_frames: None, min_baseline_m: 8.0 } } }

#[derive(Debug, Serialize)]
pub struct Report {
    pub dataset: String,
    pub duration_s: f64,
    pub frames: usize,
    pub imu_samples: usize,
    pub gnss_fixes: usize,
    pub rejected_sensor_samples: usize,
    pub frame_errors: usize,
    pub vo_poses: usize,
    pub tracking_fraction: f64,
    pub map_resets: usize,
    pub ate: Vec<SegmentAte>,
    pub frame_ms_median: f64,
    pub frame_ms_p95: f64,
    pub frame_ms_max: f64,
    /// data duration / frame-processing time (>= 1 means faster than real time on frame work alone).
    pub realtime_factor: f64,
    pub geo_aligned: bool,
    pub final_tracking: String,
    /// Fused world-pose position error vs truth (metres), over frames after geo-alignment locked.
    /// Only for datasets whose truth is in the GNSS-origin ENU frame.
    pub fused_err_median_m: Option<f64>,
    pub fused_err_p95_m: Option<f64>,
}

type Poses = Arc<Mutex<Vec<(f64, u32, Isometry3<f64>)>>>;

struct Recording { inner: VoFrontend, poses: Poses }
impl VisualFrontend for Recording {
    fn track(&mut self, t: f64, gray: &[u8], intr: &Intrinsics) -> Option<VisualPose> {
        let r = self.inner.track(t, gray, intr);
        if let Some(vp) = &r { self.poses.lock().unwrap().push((vp.t, vp.map_id, vp.t_map_cam)); }
        r
    }
    fn state(&self) -> TrackingState { self.inner.state() }
    fn reset(&mut self) { self.inner.reset() }
    fn map_points(&self) -> Vec<[f64; 3]> { self.inner.map_points() }
}

#[derive(Clone, Copy)]
enum Ev { Imu(usize), Frame(usize), Gnss(usize) }

/// Merge the sensor streams. Ties: IMU, then frame, then GNSS (so fixes pair with the frame just processed).
fn timeline(ds: &Dataset, opts: &ReplayOpts, n_frames: usize) -> Vec<(f64, u8, Ev)> {
    let mut ev: Vec<(f64, u8, Ev)> = Vec::with_capacity(ds.imu.len() + n_frames + ds.gnss.len());
    ev.extend(ds.imu.iter().enumerate().map(|(i, s)| (s.t + opts.imu_offset_s, 0, Ev::Imu(i))));
    ev.extend(ds.frames.iter().take(n_frames).enumerate().map(|(i, f)| (f.t, 1, Ev::Frame(i))));
    ev.extend(ds.gnss.iter().enumerate().map(|(i, g)| (g.t, 2, Ev::Gnss(i))));
    let t_end = ds.frames.get(n_frames.saturating_sub(1)).map_or(f64::MAX, |f| f.t) + 0.05;
    ev.retain(|e| e.0 <= t_end);
    ev.sort_by(|a, b| a.0.total_cmp(&b.0).then(a.1.cmp(&b.1)));
    ev
}

pub fn replay(ds: &Dataset, opts: &ReplayOpts) -> Result<Report, String> {
    check_first_frame(ds)?;
    let n_frames = opts.max_frames.map_or(ds.frames.len(), |m| m.min(ds.frames.len()));
    let poses: Poses = Arc::new(Mutex::new(vec![]));
    let cfg = FusionConfig { estimate_scale: ds.estimate_scale, t_body_cam: ds.t_body_cam, min_baseline_m: opts.min_baseline_m, ..Default::default() };
    let mut session = Session::new(cfg, Some(Box::new(Recording { inner: VoFrontend::new(VoConfig::default()), poses: poses.clone() })));
    session.configure(Some(ds.intrinsics), None)?;
    let undistorter = (!ds.distortion.is_zero()).then(|| Undistorter::new(&ds.intrinsics, &ds.distortion));

    let (mut rejected, mut frame_errors, mut frame_ms) = (0usize, 0usize, Vec::<f64>::new());
    let mut fused_err: Vec<f64> = vec![];
    for (_, _, ev) in timeline(ds, opts, n_frames) {
        match ev {
            Ev::Imu(i) => { let mut s = ds.imu[i]; s.t += opts.imu_offset_s; if !session.handle(Request::Imu(s)).is_ok() { rejected += 1; } }
            Ev::Gnss(i) => { if !session.handle(Request::Gnss(ds.gnss[i])).is_ok() { rejected += 1; } }
            Ev::Frame(i) => {
                let img = imageio::load_gray(&ds.frames[i].path)?; // I/O is not part of the timed section
                let t0 = Instant::now();
                let gray = match &undistorter { Some(u) => u.apply(&img.data), None => img.data };
                let resp = session.frame_gray(ds.frames[i].t, img.w as u32, img.h as u32, &gray);
                frame_ms.push(t0.elapsed().as_secs_f64() * 1000.0);
                if matches!(resp, Response::Error { .. }) { frame_errors += 1; }
                if ds.truth_is_enu {
                    let p = session.pose(None);
                    if let (true, Some(w), Some(g)) = (p.geo_aligned, p.pose, truth_at(&ds.truth, ds.frames[i].t)) { fused_err.push((w.translation.vector - g).norm()); }
                }
            }
        }
    }

    let recorded = poses.lock().unwrap().clone();
    let body: Vec<_> = recorded.iter().map(|(t, id, t_map_cam)| (*t, *id, (t_map_cam * ds.t_body_cam.inverse()).translation.vector)).collect();
    let mut map_ids: Vec<u32> = recorded.iter().map(|p| p.1).collect();
    map_ids.sort_unstable();
    map_ids.dedup();

    frame_ms.sort_by(|a, b| a.total_cmp(b));
    let pick = |q: f64| frame_ms.get(((frame_ms.len() as f64 * q) as usize).min(frame_ms.len().saturating_sub(1))).copied().unwrap_or(0.0);
    let duration = ds.frames[n_frames - 1].t - ds.frames[0].t;
    let (geo_aligned, final_tracking) = match session.handle(Request::GetPose { predict_ms: None }) {
        Response::Pose(p) => (p.geo_aligned, format!("{:?}", p.tracking)),
        _ => (false, "unknown".into()),
    };
    Ok(Report {
        dataset: ds.name.clone(), duration_s: duration, frames: n_frames, imu_samples: ds.imu.len(), gnss_fixes: ds.gnss.len(),
        rejected_sensor_samples: rejected, frame_errors, vo_poses: recorded.len(),
        tracking_fraction: recorded.len() as f64 / n_frames as f64,
        map_resets: map_ids.len().saturating_sub(1),
        ate: ate_per_map(&body, &ds.truth, 20),
        frame_ms_median: pick(0.5), frame_ms_p95: pick(0.95), frame_ms_max: frame_ms.last().copied().unwrap_or(0.0),
        realtime_factor: duration / (frame_ms.iter().sum::<f64>() / 1000.0).max(1e-9),
        geo_aligned, final_tracking,
        fused_err_median_m: { fused_err.sort_by(|a, b| a.total_cmp(b)); fused_err.get(fused_err.len() / 2).copied() },
        fused_err_p95_m: fused_err.get((fused_err.len() * 95 / 100).min(fused_err.len().saturating_sub(1))).copied(),
    })
}

impl Report {
    pub fn print(&self) {
        println!("dataset            {}", self.dataset);
        println!("data               {:.1} s, {} frames, {} IMU samples, {} GNSS fixes", self.duration_s, self.frames, self.imu_samples, self.gnss_fixes);
        println!("tracking           {} poses ({:.0}% of frames), {} map reset(s), final state {}", self.vo_poses, 100.0 * self.tracking_fraction, self.map_resets, self.final_tracking);
        println!("geo alignment      {}", if self.geo_aligned { "locked" } else { "not locked (needs GNSS + motion)" });
        for s in &self.ate {
            println!("ATE map {:<3}        {:.2}% of path (rmse {:.3} over {:.2} units, {} poses, scale {:.3})", s.map_id, s.percent_of_path, s.rmse, s.path_length, s.poses, s.scale);
        }
        if self.ate.is_empty() { println!("ATE                n/a (no ground truth overlapping VO poses)"); }
        if let (Some(m), Some(p)) = (self.fused_err_median_m, self.fused_err_p95_m) { println!("fused pose error   median {m:.2} m, p95 {p:.2} m (after geo-alignment locked)"); }
        println!("frame time         median {:.1} ms, p95 {:.1} ms, max {:.1} ms  ({:.1}x real time on frame work)", self.frame_ms_median, self.frame_ms_p95, self.frame_ms_max, self.realtime_factor);
        if self.rejected_sensor_samples + self.frame_errors > 0 { println!("WARNING            {} rejected sensor samples, {} frame errors", self.rejected_sensor_samples, self.frame_errors); }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ar_core::{GnssFix, ImuSample};
    use nalgebra::Vector3;

    #[test]
    fn timeline_orders_ties_imu_frame_gnss_and_applies_offset() {
        let imu = |t| ImuSample { t, gyro: Vector3::zeros(), accel: Vector3::zeros() };
        let ds = Dataset {
            name: "t".into(), intrinsics: Intrinsics { fx: 1.0, fy: 1.0, cx: 0.0, cy: 0.0, width: 1, height: 1 },
            distortion: Default::default(), t_body_cam: Isometry3::identity(), estimate_scale: true, truth_is_enu: false,
            imu: vec![imu(0.0), imu(1.0)], gnss: vec![GnssFix { t: 1.0, lat_deg: 0.0, lon_deg: 0.0, alt_m: 0.0, h_acc: 1.0, v_acc: 1.0 }],
            frames: vec![crate::dataset::FrameRef { t: 0.0, path: "a".into() }, crate::dataset::FrameRef { t: 1.0, path: "b".into() }], truth: vec![],
        };
        let order = |o: &ReplayOpts| timeline(&ds, o, 2).iter().map(|e| match e.2 { Ev::Imu(_) => 'i', Ev::Frame(_) => 'f', Ev::Gnss(_) => 'g' }).collect::<String>();
        // t=0: imu, frame.  t=1: imu, frame, gnss (ties break imu < frame < gnss).
        assert_eq!(order(&ReplayOpts::default()), "ififg");
        // IMU shifted +0.5 s: its samples land at 0.5 and 1.5; the latter is past the end of the camera data and dropped.
        assert_eq!(order(&ReplayOpts { imu_offset_s: 0.5, ..Default::default() }), "fifg");
    }
}
