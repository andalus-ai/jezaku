//! Trajectory evaluation: scale-aligned absolute trajectory error (ATE) per map segment.
use ar_fusion::align::umeyama;
use nalgebra::Vector3;
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct SegmentAte {
    pub map_id: u32,
    pub poses: usize,
    pub rmse: f64,
    pub path_length: f64,
    /// rmse / path length, in percent.
    pub percent_of_path: f64,
    /// Fitted map->truth scale (monocular scale is arbitrary).
    pub scale: f64,
}

pub fn truth_at(truth: &[(f64, Vector3<f64>)], t: f64) -> Option<Vector3<f64>> {
    let i = truth.partition_point(|p| p.0 <= t);
    if i == 0 || i >= truth.len() { return None; }
    let (a, b) = (&truth[i - 1], &truth[i]);
    if b.0 - a.0 > 0.5 { return None; } // don't interpolate across gaps
    let w = (t - a.0) / (b.0 - a.0).max(1e-12);
    Some(a.1 * (1.0 - w) + b.1 * w)
}

/// `poses`: (time, map id, body position in the frontend's map frame). One similarity fit per map id.
pub fn ate_per_map(poses: &[(f64, u32, Vector3<f64>)], truth: &[(f64, Vector3<f64>)], min_poses: usize) -> Vec<SegmentAte> {
    let mut ids: Vec<u32> = poses.iter().map(|p| p.1).collect();
    ids.sort_unstable();
    ids.dedup();
    let mut out = vec![];
    for id in ids {
        let (mut est, mut gt) = (vec![], vec![]);
        for p in poses.iter().filter(|p| p.1 == id) {
            if let Some(g) = truth_at(truth, p.0) { est.push(p.2); gt.push(g); }
        }
        if est.len() < min_poses { continue; }
        let Some(sim) = umeyama(&est, &gt, true) else { continue };
        let rmse = (est.iter().zip(&gt).map(|(e, g)| (sim.apply(e) - g).norm_squared()).sum::<f64>() / est.len() as f64).sqrt();
        let path_length: f64 = gt.windows(2).map(|w| (w[1] - w[0]).norm()).sum();
        out.push(SegmentAte { map_id: id, poses: est.len(), rmse, path_length, percent_of_path: 100.0 * rmse / path_length.max(1e-9), scale: sim.scale });
    }
    out
}
