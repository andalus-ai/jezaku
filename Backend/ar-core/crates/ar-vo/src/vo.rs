//! Monocular visual odometry: KLT-tracked corners, essential-matrix initialisation, PnP tracking,
//! incremental triangulation. No bundle adjustment, loop closure or relocalisation: on tracking loss
//! the map is discarded and a new one (new `map_id`) is started. Scale is arbitrary (unit initial baseline);
//! downstream fusion must run with `estimate_scale = true`.
use crate::detect::{detect, DetectParams};
use crate::geom::*;
use crate::image::{Gray, Pyramid};
use crate::klt::{track as klt_track, KltParams};
use ar_core::{Intrinsics, TrackingState, Timestamp, VisualFrontend, VisualPose};
use nalgebra::{Isometry3, UnitQuaternion, Vector3};

/// Camera (OpenCV axes: x right, y down, z forward) relative to an Android-style sensor body
/// (x right, y up, z out of the screen) for a back-facing camera: 180 degrees about x.
pub fn t_body_cam_android_back() -> Isometry3<f64> {
    Isometry3::from_parts(Vector3::zeros().into(), UnitQuaternion::from_axis_angle(&Vector3::x_axis(), std::f64::consts::PI))
}

#[derive(Debug, Clone)]
pub struct VoConfig {
    pub max_features: usize,
    pub min_features: usize,
    pub pyramid_levels: usize,
    pub init_min_tracks: usize,
    pub init_min_parallax_px: f64,
    pub init_min_landmarks: usize,
    pub epipolar_thresh_px: f64,
    pub pnp_thresh_px: f64,
    pub min_pnp_inliers: usize,
    pub min_tri_angle_deg: f64,
    pub max_tri_reproj_px: f64,
    /// Landmarks of finished tracks are kept in the point-cloud map if triangulated with at least this angle.
    pub archive_min_angle_deg: f64,
    /// Ring-buffer capacity of the archived point cloud.
    pub archive_capacity: usize,
}
impl Default for VoConfig {
    fn default() -> Self {
        Self {
            max_features: 300, min_features: 150, pyramid_levels: 3, init_min_tracks: 80, init_min_parallax_px: 14.0,
            init_min_landmarks: 40, epipolar_thresh_px: 1.5, pnp_thresh_px: 2.0, min_pnp_inliers: 20,
            min_tri_angle_deg: 1.5, max_tri_reproj_px: 2.0, archive_min_angle_deg: 3.0, archive_capacity: 6000,
        }
    }
}

struct Track {
    px: V2,
    /// Pose (world->camera) and normalised observation at the frame this track was born.
    anchor_pose: Isometry3<f64>,
    anchor_n: V2,
    landmark: Option<Vector3<f64>>,
    lm_angle: f64,
    /// Consecutive PnP-outlier verdicts. One strike only discards the (probably still noisy) landmark.
    strikes: u8,
}

#[derive(PartialEq, Eq)]
enum Phase { NeedFirst, Init, Tracking }

pub struct VoFrontend {
    cfg: VoConfig,
    klt: KltParams,
    det: DetectParams,
    phase: Phase,
    prev: Option<Pyramid>,
    tracks: Vec<Track>,
    t_cw: Isometry3<f64>,
    map_id: u32,
    state: TrackingState,
    rng: Rng,
    /// Point-cloud map: landmarks of tracks that ended (left the view / lost) while well triangulated.
    archive: std::collections::VecDeque<Vector3<f64>>,
}

fn median(mut v: Vec<f64>) -> f64 {
    if v.is_empty() { return 0.0; }
    v.sort_by(|a, b| a.total_cmp(b));
    v[v.len() / 2]
}

impl VoFrontend {
    pub fn new(cfg: VoConfig) -> Self {
        Self { cfg, klt: KltParams::default(), det: DetectParams::default(), phase: Phase::NeedFirst, prev: None, tracks: vec![],
               t_cw: Isometry3::identity(), map_id: 0, state: TrackingState::Initializing, rng: Rng::new(0x1234_5678), archive: Default::default() }
    }

    pub fn map_id(&self) -> u32 { self.map_id }

    /// Diagnostic snapshot: (pixel, has landmark, triangulation angle in degrees, age-strikes).
    pub fn track_snapshot(&self) -> Vec<(V2, bool, f64, u8)> {
        self.tracks.iter().map(|t| (t.px, t.landmark.is_some(), t.lm_angle.to_degrees(), t.strikes)).collect()
    }

    fn norm(i: &Intrinsics, p: &V2) -> V2 { V2::new((p.x - i.cx) / i.fx, (p.y - i.cy) / i.fy) }

    /// Start a fresh map whose origin is the current camera.
    fn seed(&mut self, pyr: &Pyramid, i: &Intrinsics) {
        self.t_cw = Isometry3::identity();
        self.tracks = detect(&pyr.levels[0], &[], self.cfg.max_features, &self.det).into_iter()
            .map(|px| Track { px, anchor_pose: Isometry3::identity(), anchor_n: Self::norm(i, &px), landmark: None, lm_angle: 0.0, strikes: 0 })
            .collect();
    }

    fn restart_map(&mut self, pyr: &Pyramid, i: &Intrinsics) {
        self.map_id = self.map_id.wrapping_add(1);
        self.archive.clear();
        self.seed(pyr, i);
        self.phase = Phase::Init;
    }

    fn try_init(&mut self, pyr: &Pyramid, i: &Intrinsics) {
        if self.tracks.len() < self.cfg.init_min_tracks / 2 { self.seed(pyr, i); return; }
        let par = median(self.tracks.iter().map(|t| (Self::norm(i, &t.px) - t.anchor_n).norm() * i.fx).collect());
        if self.tracks.len() < self.cfg.init_min_tracks || par < self.cfg.init_min_parallax_px { return; }
        let x1: Vec<V2> = self.tracks.iter().map(|t| t.anchor_n).collect();
        let x2: Vec<V2> = self.tracks.iter().map(|t| Self::norm(i, &t.px)).collect();
        let ok = (|| {
            let (e, mask) = essential_ransac(&x1, &x2, self.cfg.epipolar_thresh_px / i.fx, 300, &mut self.rng)?;
            let (rel, pts) = recover_pose(&e, &x1, &x2, &mask)?;
            let r = rel.rotation.to_rotation_matrix().into_inner();
            let min_ang = self.cfg.min_tri_angle_deg.to_radians();
            let mut lm = vec![None; x1.len()];
            let mut n = 0;
            for k in 0..x1.len() {
                let Some(x) = pts[k] else { continue };
                let (r1, r2) = (Vector3::new(x1[k].x, x1[k].y, 1.0).normalize(), (r.transpose() * Vector3::new(x2[k].x, x2[k].y, 1.0)).normalize());
                let ang = r1.dot(&r2).clamp(-1.0, 1.0).acos();
                if ang >= min_ang { lm[k] = Some((x, ang)); n += 1; }
            }
            (n >= self.cfg.init_min_landmarks).then_some((rel, lm, mask))
        })();
        match ok {
            Some((rel, lm, mask)) => {
                self.t_cw = rel;
                let old = std::mem::take(&mut self.tracks);
                for (k, mut t) in old.into_iter().enumerate() {
                    if !mask[k] { continue; }
                    if let Some((x, a)) = lm[k] { t.landmark = Some(x); t.lm_angle = a; }
                    self.tracks.push(t);
                }
                self.phase = Phase::Tracking;
                self.state = TrackingState::Tracking;
            }
            None => if par > 3.0 * self.cfg.init_min_parallax_px { self.seed(pyr, i); }
        }
    }

    /// Triangulate (or improve) landmarks from each track's birth observation to the current frame.
    fn triangulate_tracks(&mut self, i: &Intrinsics) {
        let p2 = p_matrix(&self.t_cw);
        let min_ang = self.cfg.min_tri_angle_deg.to_radians();
        let max_err = self.cfg.max_tri_reproj_px / i.fx;
        let cur_inv = self.t_cw.rotation.inverse();
        for t in &mut self.tracks {
            let n = Self::norm(i, &t.px);
            let ra = t.anchor_pose.rotation.inverse() * Vector3::new(t.anchor_n.x, t.anchor_n.y, 1.0).normalize();
            let rb = cur_inv * Vector3::new(n.x, n.y, 1.0).normalize();
            let ang = ra.dot(&rb).clamp(-1.0, 1.0).acos();
            if ang < min_ang || (t.landmark.is_some() && ang < 1.5 * t.lm_angle) { continue; }
            let Some(x) = triangulate(&p_matrix(&t.anchor_pose), &p2, t.anchor_n, n) else { continue };
            let (ok1, ok2) = (project(&t.anchor_pose, &x), project(&self.t_cw, &x));
            if let (Some(a), Some(b)) = (ok1, ok2) {
                if (a - t.anchor_n).norm() < max_err && (b - n).norm() < max_err && x.norm() < 1e5 {
                    t.landmark = Some(x);
                    t.lm_angle = ang;
                }
            }
        }
    }
}

impl VisualFrontend for VoFrontend {
    fn track(&mut self, t: Timestamp, gray: &[u8], intr: &Intrinsics) -> Option<VisualPose> {
        let g = Gray::from_u8(intr.width as usize, intr.height as usize, gray)?;
        let pyr = Pyramid::build(g, self.cfg.pyramid_levels);

        if self.phase == Phase::NeedFirst {
            self.seed(&pyr, intr);
            self.prev = Some(pyr);
            self.phase = Phase::Init;
            self.state = TrackingState::Initializing;
            return None;
        }
        let prev = self.prev.take()?;
        let pts: Vec<V2> = self.tracks.iter().map(|t| t.px).collect();
        let res = klt_track(&prev, &pyr, &pts, &self.klt);
        let old = std::mem::take(&mut self.tracks);
        let min_ang = self.cfg.archive_min_angle_deg.to_radians();
        for (mut tr, r) in old.into_iter().zip(res) {
            match r {
                Some(p) => { tr.px = p; self.tracks.push(tr); }
                None => if let Some(x) = tr.landmark.filter(|_| tr.lm_angle >= min_ang && tr.strikes == 0) {
                    if self.archive.len() >= self.cfg.archive_capacity { self.archive.pop_front(); }
                    self.archive.push_back(x);
                },
            }
        }

        if self.phase == Phase::Init {
            self.try_init(&pyr, intr);
            self.prev = Some(pyr);
            if self.phase != Phase::Tracking { return None; }
            // The frame that completed initialisation already has a pose.
            return Some(self.output(t, self.tracks.iter().filter(|t| t.landmark.is_some()).count(), self.tracks.len()));
        }

        // Tracking.
        let idx: Vec<usize> = (0..self.tracks.len()).filter(|&k| self.tracks[k].landmark.is_some()).collect();
        let p3: Vec<Vector3<f64>> = idx.iter().map(|&k| self.tracks[k].landmark.unwrap()).collect();
        let obs: Vec<V2> = idx.iter().map(|&k| Self::norm(intr, &self.tracks[k].px)).collect();
        let solved = pnp_ransac(&p3, &obs, Some(&self.t_cw), self.cfg.pnp_thresh_px / intr.fx, &mut self.rng)
            .filter(|(_, m)| m.iter().filter(|&&b| b).count() >= self.cfg.min_pnp_inliers);
        let Some((pose, mask)) = solved else {
            self.state = TrackingState::Lost;
            self.restart_map(&pyr, intr);
            self.prev = Some(pyr);
            return None;
        };
        self.t_cw = pose;
        let inliers = mask.iter().filter(|&&b| b).count();
        // Outlier landmarks are usually just poorly triangulated (near-field, small baseline), not bad tracks:
        // drop the landmark, keep the track so it can be re-triangulated with more parallax; evict repeat offenders.
        for (&k, &ok) in idx.iter().zip(&mask) {
            let t = &mut self.tracks[k];
            if ok { t.strikes = 0; } else { t.strikes += 1; t.landmark = None; t.lm_angle = 0.0; }
        }
        self.tracks.retain(|t| t.strikes < 2);

        self.triangulate_tracks(intr);
        if self.tracks.len() < self.cfg.min_features {
            let occ: Vec<V2> = self.tracks.iter().map(|t| t.px).collect();
            let fresh = detect(&pyr.levels[0], &occ, self.cfg.max_features - self.tracks.len(), &self.det);
            let pose = self.t_cw;
            self.tracks.extend(fresh.into_iter().map(|px| Track { px, anchor_pose: pose, anchor_n: Self::norm(intr, &px), landmark: None, lm_angle: 0.0, strikes: 0 }));
        }
        self.prev = Some(pyr);
        self.state = if inliers < 35 { TrackingState::Limited } else { TrackingState::Tracking };
        Some(self.output(t, inliers, idx.len()))
    }

    fn state(&self) -> TrackingState { self.state }

    fn reset(&mut self) {
        self.map_id = self.map_id.wrapping_add(1);
        self.archive.clear();
        self.phase = Phase::NeedFirst;
        self.tracks.clear();
        self.prev = None;
        self.t_cw = Isometry3::identity();
        self.state = TrackingState::Initializing;
    }

    fn map_points(&self) -> Vec<[f64; 3]> {
        self.archive.iter().copied().chain(self.tracks.iter().filter_map(|t| t.landmark)).map(|p| [p.x, p.y, p.z]).collect()
    }
}

impl VoFrontend {
    fn output(&self, t: Timestamp, inliers: usize, n_lm: usize) -> VisualPose {
        let ratio = if n_lm > 0 { inliers as f64 / n_lm as f64 } else { 0.0 };
        VisualPose { t, t_map_cam: self.t_cw.inverse(), quality: ((inliers as f64 / 40.0).min(1.0) * ratio).clamp(0.0, 1.0), map_id: self.map_id }
    }
}
