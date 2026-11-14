//! Wire protocol: one JSON object per line.
//!
//! Request:  `{"id": 7, "type": "get_pose", "predict_ms": 20}`
//! Response: `{"id": 7, "type": "pose", ...}`
//!
//! `id` is optional. Without an `id`, successful responses are suppressed (fire-and-forget
//! streaming of IMU/GNSS/visual data at full rate); errors are always sent.
use crate::anchors::{AnchorSpec, AnchorState};
use ar_core::{GnssFix, ImuSample, Intrinsics, TrackingState, VisualPose};
use ar_fusion::GeoPose;
use nalgebra::Isometry3;
use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: u32 = 1;

#[derive(Debug, Deserialize)]
pub struct Envelope {
    #[serde(default)]
    pub id: Option<u64>,
    #[serde(flatten)]
    pub req: Request,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Request {
    Hello {
        #[serde(default)] session: Option<String>,
        #[serde(default)] token: Option<String>,
        #[serde(default)] intrinsics: Option<Intrinsics>,
        #[serde(default)] t_body_cam: Option<Isometry3<f64>>,
    },
    Imu(ImuSample),
    Gnss(GnssFix),
    Visual(VisualPose),
    /// 8-bit grayscale image, base64, `width*height` bytes. Needs a frontend + hello intrinsics.
    Frame { t: f64, width: u32, height: u32, data: String },
    /// Sparse map points in the frontend's map frame.
    MapPoints { points: Vec<[f64; 3]> },
    GetPose { #[serde(default)] predict_ms: Option<f64> },
    /// Push `pose` messages at `hz` (0 stops).
    Subscribe { hz: f64 },
    CreateAnchor { pose: Isometry3<f64> },
    CreateGeoAnchor { lat_deg: f64, lon_deg: f64, alt_m: f64, #[serde(default)] heading_deg: f64 },
    /// Not named `id`: that key belongs to the envelope.
    RemoveAnchor { anchor_id: u64 },
    ListAnchors,
    DetectPlanes,
    HitTest { origin: [f64; 3], dir: [f64; 3] },
    Save,
    Stats,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode { BadRequest, InvalidValue, NotReady, NotFound, Unauthorized, Unsupported, Conflict, Busy, Internal }

#[derive(Debug, Serialize)]
pub struct PoseDto {
    /// Latest sensor timestamp the estimate includes (null before any sensor data).
    pub t: Option<f64>,
    pub pose: Option<Isometry3<f64>>,
    pub velocity: Option<[f64; 3]>,
    pub pos_sigma_m: Option<f64>,
    pub tracking: TrackingState,
    pub geo_aligned: bool,
    pub map_id: Option<u32>,
    pub geo: Option<GeoPose>,
}

#[derive(Debug, Serialize)]
pub struct AnchorDto {
    pub id: u64,
    pub state: AnchorState,
    pub pose: Option<Isometry3<f64>>,
    #[serde(flatten)]
    pub spec: AnchorSpec,
}

#[derive(Debug, Serialize)]
pub struct PlaneDto { pub id: usize, pub normal: [f64; 3], pub d: f64, pub horizontal: bool, pub inliers: usize, pub center: [f64; 3], pub extent_m: [f64; 2] }

#[derive(Debug, Serialize)]
pub struct HitDto { pub plane_id: usize, pub distance: f64, pub point: [f64; 3], pub normal: [f64; 3], pub horizontal: bool }

#[derive(Debug, Serialize, Default, Clone)]
pub struct StatsDto {
    pub uptime_s: u64,
    pub connections_active: u64,
    pub connections_total: u64,
    pub requests: u64,
    pub errors: u64,
    pub imu: u64,
    pub gnss: u64,
    pub visual: u64,
    pub frames: u64,
    pub session_anchors: usize,
}

#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Response {
    Welcome { protocol: u32, session: Option<String>, restored_anchors: usize, frontend: bool },
    Ok,
    Pose(PoseDto),
    /// Not named `id`: that key belongs to the envelope and would clobber the echoed request id.
    AnchorCreated { anchor_id: u64 },
    Anchors { anchors: Vec<AnchorDto> },
    Planes { planes: Vec<PlaneDto> },
    Hits { hits: Vec<HitDto> },
    Saved { anchors: usize },
    Stats(StatsDto),
    Error { code: ErrorCode, message: String },
}

impl Response {
    pub fn err(code: ErrorCode, message: impl Into<String>) -> Self { Response::Error { code, message: message.into() } }
    pub fn is_ok(&self) -> bool { matches!(self, Response::Ok) }
}

#[derive(Serialize)]
pub struct ResponseEnvelope<'a> {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<u64>,
    #[serde(flatten)]
    pub resp: &'a Response,
}
