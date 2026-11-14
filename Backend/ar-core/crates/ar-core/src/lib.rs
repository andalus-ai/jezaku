//! Shared types: sensor samples, poses, anchors, and the `VisualFrontend` trait
//! that a SLAM/VIO backend (ORB-SLAM3 FFI, a pure-Rust VO, ...) must implement.
use nalgebra::{Isometry3, Vector3};
use serde::{Deserialize, Serialize};

/// Seconds since an arbitrary monotonic epoch.
pub type Timestamp = f64;

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct ImuSample {
    pub t: Timestamp,
    /// rad/s, body frame
    pub gyro: Vector3<f64>,
    /// m/s^2 specific force, body frame
    pub accel: Vector3<f64>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct GnssFix {
    pub t: Timestamp,
    pub lat_deg: f64,
    pub lon_deg: f64,
    pub alt_m: f64,
    /// 1-sigma horizontal accuracy, metres
    pub h_acc: f64,
    /// 1-sigma vertical accuracy, metres
    pub v_acc: f64,
}

/// Pin-hole intrinsics (distortion handled by the frontend).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Intrinsics {
    pub fx: f64,
    pub fy: f64,
    pub cx: f64,
    pub cy: f64,
    pub width: u32,
    pub height: u32,
}

/// Camera pose estimated by a visual frontend in its own (arbitrary, local) map frame.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct VisualPose {
    pub t: Timestamp,
    pub t_map_cam: Isometry3<f64>,
    /// Frontend's self-reported tracking quality in [0,1].
    pub quality: f64,
    /// Identifies the frontend's map. Must change whenever the map frame is reset or
    /// re-initialised, because poses from different maps are not comparable.
    #[serde(default)]
    pub map_id: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrackingState {
    Initializing,
    Tracking,
    Limited,
    Lost,
}

/// Frontend contract. Implementations own feature extraction + map; the service only
/// sees poses. Keeping this a trait is what lets us swap ORB-SLAM3 / OpenVSLAM FFI /
/// a pure-Rust VO without touching fusion or the API surface.
pub trait VisualFrontend: Send {
    /// Feed one grayscale frame (row-major, 8-bit). Returns a pose if tracking.
    fn track(&mut self, t: Timestamp, gray: &[u8], intr: &Intrinsics) -> Option<VisualPose>;
    fn state(&self) -> TrackingState;
    fn reset(&mut self);
    /// Current sparse map points in the frontend's map frame (for plane finding). Optional.
    fn map_points(&self) -> Vec<[f64; 3]> { Vec::new() }
}
