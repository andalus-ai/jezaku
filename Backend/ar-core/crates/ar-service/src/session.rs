//! Transport-independent session logic. One `Session` per client connection.
use crate::anchors::{AnchorSpec, AnchorStore, Ctx};
use crate::protocol::*;
use crate::store::Snapshot;
use crate::validate;
use ar_core::{Intrinsics, VisualFrontend};
use ar_fusion::{FusionConfig, WorldFusion};
use ar_planes::{detect, Params, Plane};
use base64::Engine;
use nalgebra::{Isometry3, Point3, Vector3};

pub const MAX_MAP_POINTS: usize = 200_000;
const MAX_PREDICT_MS: f64 = 100.0;

pub struct Session {
    fusion: WorldFusion,
    anchors: AnchorStore,
    planes: Vec<Plane>,
    map_points: Vec<Point3<f64>>,
    frontend: Option<Box<dyn VisualFrontend>>,
    intrinsics: Option<Intrinsics>,
}

impl Session {
    pub fn new(cfg: FusionConfig, frontend: Option<Box<dyn VisualFrontend>>) -> Self {
        Self { fusion: WorldFusion::new(cfg), anchors: AnchorStore::new(), planes: vec![], map_points: vec![], frontend, intrinsics: None }
    }

    pub fn has_frontend(&self) -> bool { self.frontend.is_some() }
    pub fn anchor_count(&self) -> usize { self.anchors.len() }

    pub fn configure(&mut self, intrinsics: Option<Intrinsics>, t_body_cam: Option<Isometry3<f64>>) -> Result<(), String> {
        if let Some(i) = &intrinsics { validate::intrinsics(i)?; }
        if let Some(t) = &t_body_cam { validate::isometry(t)?; }
        if intrinsics.is_some() { self.intrinsics = intrinsics; }
        if let Some(t) = t_body_cam { self.fusion.set_t_body_cam(t); }
        Ok(())
    }

    pub fn restore(&mut self, snap: Snapshot) -> usize {
        if let Some((la, lo, al)) = snap.enu_origin { self.fusion.set_enu_origin(la, lo, al); }
        let n = snap.anchors.len();
        self.anchors = AnchorStore::restore(snap.anchors, snap.next_anchor_id);
        n
    }

    pub fn snapshot(&self) -> Snapshot {
        Snapshot {
            version: 1,
            enu_origin: self.fusion.enu_frame().map(|e| e.origin()),
            next_anchor_id: self.anchors.next_id(),
            anchors: self.anchors.persistable(),
        }
    }

    fn ctx(&self) -> Ctx<'_> {
        Ctx { alignment: self.fusion.alignment(), map_id: self.fusion.map_id(), enu: self.fusion.enu_frame() }
    }

    pub fn pose(&self, predict_ms: Option<f64>) -> PoseDto {
        let dt = predict_ms.unwrap_or(0.0).clamp(0.0, MAX_PREDICT_MS) / 1000.0;
        PoseDto {
            t: Some(self.fusion.latest_t()).filter(|t| t.is_finite()),
            pose: if dt > 0.0 { self.fusion.predict_pose(dt) } else { self.fusion.world_pose() },
            velocity: self.fusion.velocity().map(Into::into),
            pos_sigma_m: self.fusion.pos_sigma(),
            tracking: self.fusion.tracking_at(),
            geo_aligned: self.fusion.alignment().is_some(),
            map_id: self.fusion.map_id(),
            geo: self.fusion.geo_pose(),
        }
    }

    pub fn handle(&mut self, req: Request) -> Response {
        use ErrorCode::*;
        let bad = |m: String| Response::err(InvalidValue, m);
        match req {
            Request::Imu(s) => match validate::imu(&s) { Ok(()) => { self.fusion.on_imu(&s); Response::Ok } Err(e) => bad(e) },
            Request::Gnss(g) => match validate::gnss(&g) { Ok(()) => { self.fusion.on_gnss(&g); Response::Ok } Err(e) => bad(e) },
            Request::Visual(v) => match validate::visual(&v) { Ok(()) => { self.fusion.on_visual(&v); Response::Ok } Err(e) => bad(e) },
            Request::Frame { t, width, height, data } => self.frame(t, width, height, &data),
            Request::MapPoints { points } => {
                if points.len() > MAX_MAP_POINTS { return bad(format!("too many map points (max {MAX_MAP_POINTS})")); }
                if points.iter().any(|p| p.iter().any(|x| !x.is_finite())) { return bad("map point is non-finite".into()); }
                self.map_points = points.into_iter().map(|p| Point3::new(p[0], p[1], p[2])).collect();
                Response::Ok
            }
            Request::GetPose { predict_ms } => match predict_ms {
                Some(p) if !p.is_finite() => bad("predict_ms must be finite".into()),
                p => Response::Pose(self.pose(p)),
            },
            Request::CreateAnchor { pose } => {
                if let Err(e) = validate::isometry(&pose) { return bad(e); }
                if self.fusion.world_pose().is_none() { return Response::err(NotReady, "no world estimate yet (need IMU + GNSS)"); }
                let ctx = Ctx { alignment: self.fusion.alignment(), map_id: self.fusion.map_id(), enu: self.fusion.enu_frame() };
                match self.anchors.add_from_world(pose, &ctx) { Ok(anchor_id) => Response::AnchorCreated { anchor_id }, Err(e) => Response::err(Busy, e) }
            }
            Request::CreateGeoAnchor { lat_deg, lon_deg, alt_m, heading_deg } => {
                let ok = [lat_deg, lon_deg, alt_m, heading_deg].iter().all(|x| x.is_finite())
                    && (-90.0..=90.0).contains(&lat_deg) && (-180.0..=180.0).contains(&lon_deg);
                if !ok { return bad("geo anchor: invalid coordinates".into()); }
                match self.anchors.add(AnchorSpec::Geo { lat_deg, lon_deg, alt_m, heading_deg }) { Ok(anchor_id) => Response::AnchorCreated { anchor_id }, Err(e) => Response::err(Busy, e) }
            }
            Request::RemoveAnchor { anchor_id } => if self.anchors.remove(anchor_id) { Response::Ok } else { Response::err(NotFound, format!("no anchor {anchor_id}")) },
            Request::ListAnchors => {
                let ctx = self.ctx();
                let anchors = self.anchors.records().iter().map(|r| {
                    let (state, pose) = AnchorStore::resolve(r, &ctx);
                    AnchorDto { id: r.id, state, pose, spec: r.spec.clone() }
                }).collect();
                Response::Anchors { anchors }
            }
            Request::DetectPlanes => self.detect_planes(),
            Request::HitTest { origin, dir } => self.hit_test(origin, dir),
            // Connection-level requests are handled by the transport.
            Request::Hello { .. } | Request::Subscribe { .. } | Request::Save | Request::Stats => Response::err(Internal, "request must be handled by the transport"),
        }
    }

    fn frame(&mut self, t: f64, width: u32, height: u32, data: &str) -> Response {
        use ErrorCode::*;
        let Some(fe) = self.frontend.as_mut() else {
            return Response::err(Unsupported, "no visual frontend configured; send `visual` poses instead");
        };
        let Some(intr) = self.intrinsics else { return Response::err(NotReady, "send `hello` with intrinsics before frames") };
        if (width, height) != (intr.width, intr.height) { return Response::err(InvalidValue, "frame size does not match intrinsics"); }
        if !t.is_finite() { return Response::err(InvalidValue, "non-finite timestamp"); }
        let Ok(gray) = base64::engine::general_purpose::STANDARD.decode(data) else { return Response::err(InvalidValue, "frame data is not valid base64") };
        if gray.len() != (width as usize) * (height as usize) { return Response::err(InvalidValue, "frame byte length != width*height"); }
        if let Some(vp) = fe.track(t, &gray, &intr) {
            if let Err(e) = validate::visual(&vp) { return Response::err(Internal, format!("frontend produced invalid pose: {e}")); }
            let prev_map = self.fusion.map_id();
            self.fusion.on_visual(&vp);
            if prev_map.is_some() && prev_map != self.fusion.map_id() { self.planes.clear(); } // old planes belong to the abandoned map
        }
        // Keep plane finding fed from the frontend's own map; clients need not upload points.
        let pts = fe.map_points();
        if !pts.is_empty() && pts.len() <= MAX_MAP_POINTS {
            self.map_points = pts.into_iter().map(|p| Point3::new(p[0], p[1], p[2])).collect();
        }
        Response::Ok
    }

    fn detect_planes(&mut self) -> Response {
        let Some(al) = self.fusion.alignment() else {
            return Response::err(ErrorCode::NotReady, "map is not geo-aligned yet (needs GNSS + motion)");
        };
        // Planes are computed in ENU (z up) so "horizontal" is meaningful.
        let world: Vec<_> = self.map_points.iter().map(|p| Point3::from(al.apply(&p.coords))).collect();
        // Triangulation noise grows with depth, so scale the inlier band with the typical point distance
        // (about 1.5%, clamped to 2-12 cm) instead of using a fixed tolerance.
        let cam = self.fusion.world_pose().map(|p| p.translation.vector)
            .or_else(|| (!world.is_empty()).then(|| world.iter().map(|p| p.coords).sum::<Vector3<f64>>() / world.len() as f64))
            .unwrap_or_else(Vector3::zeros);
        let mut dists: Vec<f64> = world.iter().map(|p| (p.coords - cam).norm()).collect();
        dists.sort_by(|a, b| a.total_cmp(b));
        let d_med = dists.get(dists.len() / 2).copied().unwrap_or(1.0);
        let params = Params { dist_thresh: (0.015 * d_med).clamp(0.02, 0.12), iterations: 300, ..Params::default() };
        self.planes = detect(&world, &params, 0x5eed);
        let planes = self.planes.iter().enumerate().map(|(i, p)| PlaneDto {
            id: i, normal: p.normal.into(), d: p.d, horizontal: p.horizontal, inliers: p.inliers.len(),
            center: p.center.into(), extent_m: p.extent(),
        }).collect();
        Response::Planes { planes }
    }

    /// Ray (world/ENU frame) against the planes from the last `detect_planes`, nearest first.
    fn hit_test(&self, origin: [f64; 3], dir: [f64; 3]) -> Response {
        let (o, d) = (Vector3::from(origin), Vector3::from(dir));
        if !o.iter().chain(d.iter()).all(|x| x.is_finite()) || d.norm() < 1e-9 {
            return Response::err(ErrorCode::InvalidValue, "hit_test: origin/dir must be finite and dir non-zero");
        }
        let d = d.normalize();
        let mut hits: Vec<HitDto> = self.planes.iter().enumerate().filter_map(|(i, p)| {
            let t = p.intersect(&o, &d, 0.05)?;
            Some(HitDto { plane_id: i, distance: t, point: (o + d * t).into(), normal: p.normal.into(), horizontal: p.horizontal })
        }).collect();
        hits.sort_by(|a, b| a.distance.total_cmp(&b.distance));
        Response::Hits { hits }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::anchors::AnchorState;
    use ar_core::{ImuSample, TrackingState, VisualPose};

    #[test]
    fn json_roundtrip_validation_and_anchor_lifecycle() {
        let mut s = Session::new(FusionConfig::default(), None);
        let env: Envelope = serde_json::from_str(r#"{"id":1,"type":"imu","t":0.0,"gyro":[0,0,0],"accel":[0,0,9.8]}"#).unwrap();
        assert_eq!(env.id, Some(1));
        assert!(s.handle(env.req).is_ok());
        // Not ready for anchors without a world estimate.
        assert!(matches!(s.handle(Request::CreateAnchor { pose: Isometry3::identity() }), Response::Error { code: ErrorCode::NotReady, .. }));
        // Geo anchors don't need one.
        let Response::AnchorCreated { anchor_id } = s.handle(Request::CreateGeoAnchor { lat_deg: -6.9, lon_deg: 107.6, alt_m: 700.0, heading_deg: 45.0 }) else { panic!() };
        assert!(s.handle(Request::RemoveAnchor { anchor_id }).is_ok());
        assert!(matches!(s.handle(Request::RemoveAnchor { anchor_id }), Response::Error { code: ErrorCode::NotFound, .. }));
        assert!(matches!(s.handle(Request::DetectPlanes), Response::Error { code: ErrorCode::NotReady, .. }));
        // Garbage is rejected, not integrated.
        let bad = ImuSample { t: 1.0, gyro: Vector3::new(f64::NAN, 0.0, 0.0), accel: Vector3::zeros() };
        assert!(matches!(s.handle(Request::Imu(bad)), Response::Error { code: ErrorCode::InvalidValue, .. }));
        let vp = VisualPose { t: 1.0, t_map_cam: Isometry3::identity(), quality: 1.5, map_id: 0 };
        assert!(matches!(s.handle(Request::Visual(vp)), Response::Error { code: ErrorCode::InvalidValue, .. }));
        assert_eq!(s.pose(None).tracking, TrackingState::Initializing);
    }

    #[test]
    fn snapshot_restores_geo_anchors_and_origin() {
        let mut a = Session::new(FusionConfig::default(), None);
        a.fusion.set_enu_origin(-6.9, 107.6, 700.0);
        a.handle(Request::CreateGeoAnchor { lat_deg: -6.9, lon_deg: 107.6, alt_m: 700.0, heading_deg: 0.0 });
        let snap: Snapshot = serde_json::from_str(&serde_json::to_string(&a.snapshot()).unwrap()).unwrap();
        let mut b = Session::new(FusionConfig::default(), None);
        assert_eq!(b.restore(snap), 1);
        let Response::Anchors { anchors } = b.handle(Request::ListAnchors) else { panic!() };
        assert_eq!(anchors[0].state, AnchorState::Tracking);
        assert!(anchors[0].pose.unwrap().translation.vector.norm() < 1e-6, "anchor at the ENU origin");
    }

    struct Scripted(Option<VisualPose>);
    impl VisualFrontend for Scripted {
        fn track(&mut self, _t: f64, g: &[u8], _i: &Intrinsics) -> Option<VisualPose> { assert_eq!(g.len(), 4); self.0.take() }
        fn state(&self) -> ar_core::TrackingState { ar_core::TrackingState::Tracking }
        fn reset(&mut self) {}
    }

    #[test]
    fn frame_path_drives_frontend() {
        let vp = VisualPose { t: 0.5, t_map_cam: Isometry3::identity(), quality: 0.9, map_id: 2 };
        let mut s = Session::new(FusionConfig::default(), Some(Box::new(Scripted(Some(vp)))));
        let frame = |s: &mut Session| s.handle(Request::Frame { t: 0.5, width: 2, height: 2, data: "AAECAw==".into() });
        assert!(matches!(frame(&mut s), Response::Error { code: ErrorCode::NotReady, .. }), "intrinsics required");
        s.configure(Some(Intrinsics { fx: 500.0, fy: 500.0, cx: 1.0, cy: 1.0, width: 2, height: 2 }), None).unwrap();
        assert!(frame(&mut s).is_ok());
        assert_eq!(s.pose(None).map_id, Some(2));
        let r = s.handle(Request::Frame { t: 0.6, width: 2, height: 2, data: "AAEC".into() });
        assert!(matches!(r, Response::Error { code: ErrorCode::InvalidValue, .. }), "length mismatch");
        let mut none = Session::new(FusionConfig::default(), None);
        assert!(matches!(frame(&mut none), Response::Error { code: ErrorCode::Unsupported, .. }));
    }
}
