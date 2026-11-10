//! Visual-inertial-GNSS world fusion.
//!
//! The visual frontend lives in an arbitrary local *map* frame. We:
//!  1. run an ESKF in the ENU *world* frame on IMU + GNSS,
//!  2. pair (map position, raw GNSS ENU position) samples taken at the same instant,
//!  3. solve the map->ENU similarity (Umeyama) and keep refining it as pairs accrue,
//!  4. feed aligned visual poses back into the ESKF (position + orientation).
//!
//! Invariants callers must respect: every timestamp is on one shared monotonic clock;
//! `VisualPose::map_id` changes whenever the frontend's map frame is reset.
pub mod align;
pub mod eskf;

use align::{gravity_yaw_similarity, umeyama, Similarity};
use ar_core::{GnssFix, ImuSample, TrackingState, VisualPose};
use ar_geo::EnuFrame;
use eskf::{Eskf, Noise};
use nalgebra::{Isometry3, UnitQuaternion, Vector3};
use serde::Serialize;

#[derive(Debug, Clone)]
pub struct FusionConfig {
    pub noise: Noise,
    /// Rigid transform camera->IMU body (T_body_cam). Identity if frontend already reports body pose.
    pub t_body_cam: Isometry3<f64>,
    /// Monocular-only frontends have unknown scale; VIO frontends are metric.
    pub estimate_scale: bool,
    /// Minimum spread (m) of the paired trajectory before trusting an alignment.
    pub min_baseline_m: f64,
    pub max_pairs: usize,
    pub visual_pos_sigma: f64,
    pub visual_rot_sigma: f64,
    /// GNSS fixes worse than this (1-sigma horizontal, m) are ignored.
    pub max_gnss_acc_m: f64,
    /// Visual poses with quality below this are ignored entirely.
    pub min_visual_quality: f64,
    /// No visual pose for this long (s, sensor clock) => `Lost`.
    pub lost_after_s: f64,
    /// Use IMU gravity to fix tilt and solve only yaw/translation/scale (falls back to 6-DoF without IMU).
    pub use_gravity: bool,
}
impl Default for FusionConfig {
    fn default() -> Self {
        Self {
            noise: Noise::default(),
            t_body_cam: Isometry3::identity(),
            estimate_scale: false,
            min_baseline_m: 8.0,
            max_pairs: 300,
            visual_pos_sigma: 0.05,
            visual_rot_sigma: 0.02,
            max_gnss_acc_m: 30.0,
            min_visual_quality: 0.2,
            lost_after_s: 1.0,
            use_gravity: true,
        }
    }
}

/// ARCore-Earth-style geospatial pose of the device.
#[derive(Debug, Clone, Copy, Serialize)]
pub struct GeoPose {
    pub lat_deg: f64,
    pub lon_deg: f64,
    pub alt_m: f64,
    /// Camera look direction, degrees clockwise from true north.
    pub heading_deg: f64,
    pub horiz_acc_m: f64,
    pub vert_acc_m: f64,
    pub heading_acc_deg: f64,
}

/// Heading of the camera's look direction (-Z of the sensor frame, Android convention),
/// falling back to the device's +Y when the camera points (nearly) straight up/down.
pub fn heading_deg(q: &UnitQuaternion<f64>) -> f64 {
    let mut fwd = q * Vector3::new(0.0, 0.0, -1.0);
    if fwd.xy().norm() < 0.3 {
        fwd = q * Vector3::y();
    }
    fwd.x.atan2(fwd.y).to_degrees().rem_euclid(360.0)
}

pub struct WorldFusion {
    cfg: FusionConfig,
    enu: Option<EnuFrame>,
    filter: Option<Eskf>,
    last_accel: Option<Vector3<f64>>,
    last_gyro: Vector3<f64>,
    accel_lp: Option<Vector3<f64>>,
    last_imu_t: Option<f64>,
    up_sum: Vector3<f64>,
    up_w: f64,
    pairs: Vec<(Vector3<f64>, Vector3<f64>)>, // (map, enu)
    pairs_since_solve: usize,
    last_visual_map: Option<(f64, Vector3<f64>)>,
    last_visual: Option<(f64, f64)>, // (t, quality)
    latest_t: f64,
    gnss_rejects: u32,
    orient_rejects: u32,
    orient_seeded: bool,
    map_id: Option<u32>,
    map_to_world: Option<Similarity>,
}

impl WorldFusion {
    pub fn new(cfg: FusionConfig) -> Self {
        Self {
            cfg, enu: None, filter: None, last_accel: None, last_gyro: Vector3::zeros(), accel_lp: None, last_imu_t: None, up_sum: Vector3::zeros(), up_w: 0.0, pairs: vec![],
            pairs_since_solve: 0, last_visual_map: None, last_visual: None, latest_t: f64::NEG_INFINITY,
            gnss_rejects: 0, orient_rejects: 0, orient_seeded: false, map_id: None, map_to_world: None,
        }
    }

    pub fn set_t_body_cam(&mut self, t: Isometry3<f64>) { self.cfg.t_body_cam = t; }
    pub fn enu_frame(&self) -> Option<&EnuFrame> { self.enu.as_ref() }
    /// Restore a previously used ENU origin (so persisted world/geo anchors keep their meaning).
    pub fn set_enu_origin(&mut self, lat_deg: f64, lon_deg: f64, alt: f64) {
        if self.enu.is_none() { self.enu = Some(EnuFrame::new(lat_deg, lon_deg, alt)); }
    }
    pub fn alignment(&self) -> Option<&Similarity> { self.map_to_world.as_ref() }
    pub fn map_id(&self) -> Option<u32> { self.map_id }
    pub fn latest_t(&self) -> f64 { self.latest_t }

    pub fn on_imu(&mut self, s: &ImuSample) {
        self.latest_t = self.latest_t.max(s.t);
        self.last_accel = Some(s.accel);
        self.last_gyro = s.gyro;
        // Low-pass the specific force (tau ~0.4 s) so linear acceleration averages out of the gravity estimate.
        let dt = self.last_imu_t.map_or(0.0, |t0| (s.t - t0).clamp(0.0, 0.5));
        self.last_imu_t = Some(s.t);
        let alpha = 1.0 - (-dt / 0.4).exp();
        self.accel_lp = Some(match self.accel_lp { Some(a) => a + (s.accel - a) * alpha, None => s.accel });
        if let Some(f) = self.filter.as_mut() { f.predict(s.t, s.gyro, s.accel); }
    }

    pub fn on_gnss(&mut self, fix: &GnssFix) {
        if fix.h_acc > self.cfg.max_gnss_acc_m { return; }
        self.latest_t = self.latest_t.max(fix.t);
        let enu = *self.enu.get_or_insert_with(|| EnuFrame::new(fix.lat_deg, fix.lon_deg, fix.alt_m));
        let z = enu.to_enu(fix.lat_deg, fix.lon_deg, fix.alt_m);
        let sigma = Vector3::new(fix.h_acc, fix.h_acc, fix.v_acc.max(fix.h_acc));
        if self.filter.is_none() {
            let Some(a) = self.last_accel else { return }; // need gravity direction to init
            self.filter = Some(Eskf::new(z, Eskf::level_from_accel(&a), self.cfg.noise));
        }
        let f = self.filter.as_mut().unwrap();
        if f.update_position(z, sigma) {
            self.gnss_rejects = 0;
        } else {
            self.gnss_rejects += 1;
            if self.gnss_rejects >= 10 {
                // Persistent disagreement: trust the receiver over a diverged filter.
                f.reset_position(z, fix.h_acc.max(1.0));
                self.gnss_rejects = 0;
            }
        }
        if let Some((tv, pm)) = self.last_visual_map {
            if (fix.t - tv).abs() < 0.3 {
                self.pairs.push((pm, z));
                if self.pairs.len() > self.cfg.max_pairs { self.pairs.remove(0); }
                self.pairs_since_solve += 1;
                if self.map_to_world.is_none() || self.pairs_since_solve >= 10 { self.try_align(); }
            }
        }
    }

    pub fn on_visual(&mut self, vp: &VisualPose) {
        self.latest_t = self.latest_t.max(vp.t);
        match self.map_id {
            Some(id) if id != vp.map_id => {
                // New map frame: old alignment and pairs are meaningless.
                self.map_to_world = None;
                self.pairs.clear();
                self.pairs_since_solve = 0;
                self.last_visual_map = None;
                self.up_sum = Vector3::zeros();
                self.up_w = 0.0;
                self.orient_seeded = false;
                self.orient_rejects = 0;
                self.map_id = Some(vp.map_id);
            }
            None => self.map_id = Some(vp.map_id),
            _ => {}
        }
        self.last_visual = Some((vp.t, vp.quality));
        if vp.quality < self.cfg.min_visual_quality { return; }
        let t_map_body = vp.t_map_cam * self.cfg.t_body_cam.inverse();
        let p_map = t_map_body.translation.vector;
        self.last_visual_map = Some((vp.t, p_map));
        // Gravity direction in the map frame: body "up" (specific force) rotated by visual orientation.
        if let Some(a) = self.accel_lp {
            if (8.8..10.8).contains(&a.norm()) {
                self.up_sum = self.up_sum * 0.995 + (t_map_body.rotation * a).normalize();
                self.up_w = self.up_w * 0.995 + 1.0;
            }
        }

        let (Some(f), Some(al)) = (self.filter.as_mut(), self.map_to_world) else { return };
        let q_w = UnitQuaternion::from_rotation_matrix(&al.rot) * t_map_body.rotation;
        if !self.orient_seeded {
            // First time the world frame is known: take attitude (incl. yaw) from the visual estimate.
            f.reset_orientation(q_w, self.cfg.visual_rot_sigma * 3.0);
            self.orient_seeded = true;
        }
        f.update_position(al.apply(&p_map), Vector3::repeat(self.cfg.visual_pos_sigma / vp.quality.max(0.2)));
        if f.update_orientation(&q_w, self.cfg.visual_rot_sigma) {
            self.orient_rejects = 0;
        } else {
            self.orient_rejects += 1;
            if self.orient_rejects >= 3 {
                f.reset_orientation(q_w, self.cfg.visual_rot_sigma * 3.0); // alignment moved or attitude diverged
                self.orient_rejects = 0;
            }
        }
    }

    fn try_align(&mut self) {
        self.pairs_since_solve = 0;
        let (src, dst): (Vec<_>, Vec<_>) = self.pairs.iter().cloned().unzip();
        if src.len() < 20 { return; }
        let c = dst.iter().sum::<Vector3<f64>>() / dst.len() as f64;
        let spread = (dst.iter().map(|p| (p - c).norm_squared()).sum::<f64>() / dst.len() as f64).sqrt();
        if spread < self.cfg.min_baseline_m * 0.25 { return; }
        let up = (self.cfg.use_gravity && self.up_w >= 10.0 && self.up_sum.norm() / self.up_w > 0.9).then(|| self.up_sum.normalize());
        let sim = match up {
            Some(u) => gravity_yaw_similarity(&src, &dst, &u, self.cfg.estimate_scale),
            None => umeyama(&src, &dst, self.cfg.estimate_scale),
        };
        if let Some(sim) = sim {
            let rms = (src.iter().zip(&dst).map(|(s, d)| (sim.apply(s) - d).norm_squared()).sum::<f64>() / src.len() as f64).sqrt();
            if rms < 5.0 { self.map_to_world = Some(sim); }
        }
    }

    pub fn tracking_at(&self) -> TrackingState {
        match (self.filter.as_ref(), self.last_visual) {
            (None, _) | (_, None) => TrackingState::Initializing,
            (_, Some((t, q))) => {
                if self.latest_t - t > self.cfg.lost_after_s { TrackingState::Lost }
                else if q < 0.6 || self.map_to_world.is_none() { TrackingState::Limited }
                else { TrackingState::Tracking }
            }
        }
    }

    /// Current body pose in ENU world, if the filter is initialised.
    pub fn world_pose(&self) -> Option<Isometry3<f64>> {
        self.filter.as_ref().map(|f| Isometry3::from_parts(f.p.into(), f.q))
    }
    pub fn velocity(&self) -> Option<Vector3<f64>> { self.filter.as_ref().map(|f| f.v) }
    pub fn pos_sigma(&self) -> Option<f64> { self.filter.as_ref().map(|f| f.pos_sigma()) }

    /// Constant-velocity / constant-rate extrapolation `dt` seconds ahead (latency compensation).
    pub fn predict_pose(&self, dt: f64) -> Option<Isometry3<f64>> {
        let f = self.filter.as_ref()?;
        let w = self.last_gyro - f.bg;
        Some(Isometry3::from_parts((f.p + f.v * dt).into(), f.q * UnitQuaternion::from_scaled_axis(w * dt)))
    }

    pub fn geo_pose(&self) -> Option<GeoPose> {
        let (f, enu) = (self.filter.as_ref()?, self.enu.as_ref()?);
        let (lat, lon, alt) = enu.to_geodetic(&f.p);
        let rot_var = (f.cov[(6, 6)] + f.cov[(7, 7)] + f.cov[(8, 8)]) / 3.0;
        Some(GeoPose {
            lat_deg: lat, lon_deg: lon, alt_m: alt, heading_deg: heading_deg(&f.q),
            horiz_acc_m: (f.cov[(0, 0)] + f.cov[(1, 1)]).sqrt(),
            vert_acc_m: f.cov[(2, 2)].sqrt(),
            heading_acc_deg: rot_var.sqrt().to_degrees(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use nalgebra::{Rotation3, Translation3};

    const G: f64 = 9.80665;
    fn level() -> Vector3<f64> { Vector3::new(0.0, 0.0, G) }

    fn walk(fu: &mut WorldFusion, enu: &EnuFrame, map_from_world: &Isometry3<f64>, map_id: u32, t0: f64, steps: usize) -> f64 {
        let mut t = t0;
        for k in 0..steps {
            let p_w = Vector3::new(k as f64 * 0.2, k as f64 * 0.1 + (k as f64 * 0.1).sin(), 0.0);
            let (la, lo, al) = enu.to_geodetic(&p_w);
            t += 0.1;
            fu.on_imu(&ImuSample { t, gyro: Vector3::zeros(), accel: level() });
            let pose_map = map_from_world * Isometry3::from_parts(p_w.into(), UnitQuaternion::identity());
            fu.on_visual(&VisualPose { t, t_map_cam: pose_map, quality: 0.9, map_id });
            fu.on_gnss(&GnssFix { t, lat_deg: la, lon_deg: lo, alt_m: al, h_acc: 1.0, v_acc: 1.5 });
        }
        t
    }

    fn setup() -> (WorldFusion, EnuFrame, Isometry3<f64>) {
        let enu = EnuFrame::new(-6.9175, 107.6191, 700.0);
        let m = Isometry3::from_parts(Translation3::new(10.0, -4.0, 1.0), UnitQuaternion::from_euler_angles(0.0, 0.0, 0.9));
        let mut fu = WorldFusion::new(FusionConfig::default());
        fu.on_imu(&ImuSample { t: 0.0, gyro: Vector3::zeros(), accel: level() });
        (fu, enu, m)
    }

    #[test]
    fn umeyama_recovers_similarity() {
        let rot = Rotation3::from_euler_angles(0.2, -0.4, 1.1);
        let (s, t) = (2.5, Vector3::new(3.0, -1.0, 7.0));
        let src: Vec<_> = (0..30).map(|i| { let x = i as f64; Vector3::new(x.sin() * 5.0, x * 0.3, (x * 0.7).cos()) }).collect();
        let dst: Vec<_> = src.iter().map(|p| s * (rot * p) + t).collect();
        let sim = align::umeyama(&src, &dst, true).unwrap();
        assert!((sim.scale - s).abs() < 1e-9);
        assert!(src.iter().zip(&dst).all(|(a, b)| (sim.apply(a) - b).norm() < 1e-9));
        assert!(src.iter().all(|p| (sim.inverse_apply(&sim.apply(p)) - p).norm() < 1e-9));
    }

    #[test]
    fn stationary_imu_does_not_drift() {
        let mut f = Eskf::new(Vector3::zeros(), UnitQuaternion::identity(), Noise::default());
        for i in 0..2000 { f.predict(i as f64 * 0.005, Vector3::zeros(), level()); }
        assert!(f.p.norm() < 1e-6 && f.v.norm() < 1e-6);
    }

    #[test]
    fn position_updates_shrink_covariance_and_gate_outliers() {
        let mut f = Eskf::new(Vector3::zeros(), UnitQuaternion::identity(), Noise::default());
        let before = f.pos_sigma();
        assert!(f.update_position(Vector3::new(1.0, 2.0, 0.0), Vector3::repeat(1.0)));
        assert!(f.pos_sigma() < before);
        assert!(!f.update_position(Vector3::new(500.0, 0.0, 0.0), Vector3::repeat(1.0)), "outlier must be gated");
    }

    #[test]
    fn end_to_end_alignment_from_walk() {
        let (mut fu, enu, m) = setup();
        walk(&mut fu, &enu, &m, 0, 0.0, 200);
        let al = fu.alignment().expect("alignment should lock");
        assert!((al.rot.euler_angles().2 + 0.9).abs() < 0.05, "yaw {}", al.rot.euler_angles().2);
        assert_eq!(fu.tracking_at(), TrackingState::Tracking);
        assert!(fu.geo_pose().is_some());
    }

    #[test]
    fn gravity_alignment_resolves_tilt_on_a_planar_walk() {
        // A nearly flat walk cannot observe tilt from positions alone; gravity must.
        let enu = EnuFrame::new(-6.9175, 107.6191, 700.0);
        let m = Isometry3::from_parts(Translation3::new(2.0, 5.0, -1.0), UnitQuaternion::from_euler_angles(0.3, -0.2, 0.9));
        let mut fu = WorldFusion::new(FusionConfig::default());
        fu.on_imu(&ImuSample { t: 0.0, gyro: Vector3::zeros(), accel: level() });
        walk(&mut fu, &enu, &m, 0, 0.0, 200);
        let al = fu.alignment().expect("alignment");
        let want = m.rotation.inverse();
        let got = UnitQuaternion::from_rotation_matrix(&al.rot);
        assert!(got.angle_to(&want) < 0.02, "alignment off by {} rad", got.angle_to(&want));
        let p_map = (m * Isometry3::translation(8.0, 4.0, 0.0)).translation.vector;
        assert!((al.apply(&p_map) - Vector3::new(8.0, 4.0, 0.0)).norm() < 0.1);
    }

    #[test]
    fn map_reset_drops_alignment_and_relocks() {
        let (mut fu, enu, m) = setup();
        let t = walk(&mut fu, &enu, &m, 0, 0.0, 200);
        assert!(fu.alignment().is_some());
        // Frontend re-initialises into a different frame.
        let m2 = Isometry3::from_parts(Translation3::new(-30.0, 8.0, 0.0), UnitQuaternion::from_euler_angles(0.0, 0.0, -2.0));
        fu.on_visual(&VisualPose { t: t + 0.1, t_map_cam: m2, quality: 0.9, map_id: 1 });
        assert!(fu.alignment().is_none(), "stale alignment must be dropped on map_id change");
        walk(&mut fu, &enu, &m2, 1, t + 0.1, 200);
        let al = fu.alignment().expect("relock on new map");
        assert!((al.rot.euler_angles().2 - 2.0).abs() < 0.05 || (al.rot.euler_angles().2 + 2.0 - 2.0 * std::f64::consts::PI).abs() < 0.05);
    }

    #[test]
    fn goes_lost_when_visual_stops() {
        let (mut fu, enu, m) = setup();
        let t = walk(&mut fu, &enu, &m, 0, 0.0, 200);
        fu.on_imu(&ImuSample { t: t + 2.0, gyro: Vector3::zeros(), accel: level() });
        assert_eq!(fu.tracking_at(), TrackingState::Lost);
    }

    #[test]
    fn heading_matches_compass() {
        let up = UnitQuaternion::identity(); // camera looks straight down -> falls back to +Y = north
        assert!(heading_deg(&up).abs() < 1e-9);
        let east = UnitQuaternion::from_axis_angle(&Vector3::z_axis(), -std::f64::consts::FRAC_PI_2);
        assert!((heading_deg(&east) - 90.0).abs() < 1e-9);
        // Phone held upright facing north: -Z (camera) must point north => rotate +90deg about X.
        let upright = UnitQuaternion::from_axis_angle(&Vector3::x_axis(), std::f64::consts::FRAC_PI_2);
        assert!(heading_deg(&upright).min(360.0 - heading_deg(&upright)) < 1e-6);
    }

    #[test]
    fn prediction_extrapolates_velocity() {
        let mut f = WorldFusion::new(FusionConfig::default());
        f.on_imu(&ImuSample { t: 0.0, gyro: Vector3::zeros(), accel: level() });
        f.on_gnss(&GnssFix { t: 0.0, lat_deg: 0.0, lon_deg: 0.0, alt_m: 0.0, h_acc: 1.0, v_acc: 1.0 });
        let p0 = f.world_pose().unwrap();
        let p1 = f.predict_pose(0.05).unwrap();
        assert!((p1.translation.vector - p0.translation.vector).norm() < 1e-9); // v == 0
    }
}
