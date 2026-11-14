//! Anchors.
//!
//! * `World`  – fixed pose in the ENU frame (used before the map is geo-aligned).
//! * `Map`    – attached to the frontend's map: rides along when the map->world alignment is
//!              refined, and becomes `Stopped` when the map is reset (`map_id` change).
//! * `Geo`    – lat/lon/alt + heading; independent of any SLAM map, so it survives restarts.
//!
//! Anchor frame convention for `Geo`: +Z up, +Y along `heading_deg` (clockwise from north).
use ar_fusion::align::Similarity;
use ar_geo::EnuFrame;
use nalgebra::{Isometry3, Translation3, UnitQuaternion, Vector3};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum AnchorSpec {
    World { pose: Isometry3<f64> },
    Map { pose: Isometry3<f64>, map_id: u32 },
    Geo { lat_deg: f64, lon_deg: f64, alt_m: f64, heading_deg: f64 },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnchorRecord {
    pub id: u64,
    #[serde(flatten)]
    pub spec: AnchorSpec,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum AnchorState {
    Tracking,
    /// Waiting on something that may yet arrive (geo alignment / ENU origin).
    Paused,
    /// Permanently lost (its map was reset). Remove and re-create.
    Stopped,
}

/// Everything needed to place anchors in the current world.
#[derive(Clone, Copy)]
pub struct Ctx<'a> {
    pub alignment: Option<&'a Similarity>,
    pub map_id: Option<u32>,
    pub enu: Option<&'a EnuFrame>,
}

#[derive(Debug, Default)]
pub struct AnchorStore {
    records: Vec<AnchorRecord>,
    next_id: u64,
}

pub const MAX_ANCHORS: usize = 4096;

impl AnchorStore {
    pub fn new() -> Self { Self { records: vec![], next_id: 1 } }
    pub fn len(&self) -> usize { self.records.len() }
    pub fn is_empty(&self) -> bool { self.records.is_empty() }
    pub fn records(&self) -> &[AnchorRecord] { &self.records }
    pub fn next_id(&self) -> u64 { self.next_id }

    pub fn restore(records: Vec<AnchorRecord>, next_id: u64) -> Self {
        let max = records.iter().map(|r| r.id).max().unwrap_or(0);
        Self { records, next_id: next_id.max(max + 1).max(1) }
    }

    pub fn add(&mut self, spec: AnchorSpec) -> Result<u64, String> {
        if self.records.len() >= MAX_ANCHORS { return Err(format!("anchor limit ({MAX_ANCHORS}) reached")); }
        let id = self.next_id;
        self.next_id += 1;
        self.records.push(AnchorRecord { id, spec });
        Ok(id)
    }

    /// Create from a pose in the ENU world frame. Once the map is aligned the anchor is attached
    /// to the map (so later alignment refinements move it with the scene); before that it is a
    /// plain world anchor.
    pub fn add_from_world(&mut self, world: Isometry3<f64>, ctx: &Ctx) -> Result<u64, String> {
        let spec = match (ctx.alignment, ctx.map_id) {
            (Some(al), Some(map_id)) => {
                let rot_inv = al.rot.inverse();
                let t = al.inverse_apply(&world.translation.vector);
                let q = UnitQuaternion::from_rotation_matrix(&rot_inv) * world.rotation;
                AnchorSpec::Map { pose: Isometry3::from_parts(Translation3::from(t), q), map_id }
            }
            _ => AnchorSpec::World { pose: world },
        };
        self.add(spec)
    }

    pub fn remove(&mut self, id: u64) -> bool {
        let n = self.records.len();
        self.records.retain(|r| r.id != id);
        self.records.len() < n
    }

    pub fn resolve(rec: &AnchorRecord, ctx: &Ctx) -> (AnchorState, Option<Isometry3<f64>>) {
        match &rec.spec {
            AnchorSpec::World { pose } => (AnchorState::Tracking, Some(*pose)),
            AnchorSpec::Map { pose, map_id } => match (ctx.map_id, ctx.alignment) {
                (Some(cur), _) if cur != *map_id => (AnchorState::Stopped, None),
                (Some(_), Some(al)) => {
                    let t = al.apply(&pose.translation.vector);
                    let q = UnitQuaternion::from_rotation_matrix(&al.rot) * pose.rotation;
                    (AnchorState::Tracking, Some(Isometry3::from_parts(Translation3::from(t), q)))
                }
                _ => (AnchorState::Paused, None),
            },
            AnchorSpec::Geo { lat_deg, lon_deg, alt_m, heading_deg } => match ctx.enu {
                Some(enu) => {
                    let t: Vector3<f64> = enu.to_enu(*lat_deg, *lon_deg, *alt_m);
                    let q = UnitQuaternion::from_axis_angle(&Vector3::z_axis(), -heading_deg.to_radians());
                    (AnchorState::Tracking, Some(Isometry3::from_parts(Translation3::from(t), q)))
                }
                None => (AnchorState::Paused, None),
            },
        }
    }

    /// Map anchors cannot be persisted (the map itself isn't); world + geo anchors can.
    pub fn persistable(&self) -> Vec<AnchorRecord> {
        self.records.iter().filter(|r| !matches!(r.spec, AnchorSpec::Map { .. })).cloned().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use nalgebra::Rotation3;

    #[test]
    fn map_anchor_follows_alignment_and_stops_on_map_reset() {
        let al = Similarity { scale: 1.0, rot: Rotation3::from_euler_angles(0.0, 0.0, 0.5), trans: Vector3::new(5.0, 0.0, 0.0) };
        let enu = EnuFrame::new(0.0, 0.0, 0.0);
        let ctx = Ctx { alignment: Some(&al), map_id: Some(3), enu: Some(&enu) };
        let world = Isometry3::translation(7.0, 2.0, 1.0);
        let mut s = AnchorStore::new();
        let id = s.add_from_world(world, &ctx).unwrap();
        assert!(matches!(s.records()[0].spec, AnchorSpec::Map { map_id: 3, .. }));
        let (st, p) = AnchorStore::resolve(&s.records()[0], &ctx);
        assert_eq!(st, AnchorState::Tracking);
        assert!((p.unwrap().translation.vector - world.translation.vector).norm() < 1e-9);

        // Alignment is refined by +1 m east: the anchor moves with the map.
        let al2 = Similarity { trans: al.trans + Vector3::x(), ..al };
        let (_, p2) = AnchorStore::resolve(&s.records()[0], &Ctx { alignment: Some(&al2), ..ctx });
        assert!((p2.unwrap().translation.vector - (world.translation.vector + Vector3::x())).norm() < 1e-9);

        // Map reset => stopped.
        let (st, p) = AnchorStore::resolve(&s.records()[0], &Ctx { map_id: Some(4), ..ctx });
        assert_eq!((st, p.is_none()), (AnchorState::Stopped, true));
        assert!(s.remove(id) && !s.remove(id));
    }

    #[test]
    fn geo_anchor_heading_and_pause() {
        let mut s = AnchorStore::new();
        s.add(AnchorSpec::Geo { lat_deg: 0.0, lon_deg: 0.0, alt_m: 0.0, heading_deg: 90.0 }).unwrap();
        let none = Ctx { alignment: None, map_id: None, enu: None };
        assert_eq!(AnchorStore::resolve(&s.records()[0], &none).0, AnchorState::Paused);
        let enu = EnuFrame::new(0.0, 0.0, 0.0);
        let (st, p) = AnchorStore::resolve(&s.records()[0], &Ctx { enu: Some(&enu), ..none });
        assert_eq!(st, AnchorState::Tracking);
        let fwd = p.unwrap().rotation * Vector3::y();
        assert!((fwd - Vector3::x()).norm() < 1e-9, "heading 90 => +Y local points east");
    }

    #[test]
    fn only_non_map_anchors_persist_and_ids_never_reused() {
        let mut s = AnchorStore::new();
        s.add(AnchorSpec::Map { pose: Isometry3::identity(), map_id: 0 }).unwrap();
        s.add(AnchorSpec::World { pose: Isometry3::identity() }).unwrap();
        assert_eq!(s.persistable().len(), 1);
        let r = AnchorStore::restore(s.persistable(), 1);
        assert!(r.next_id() > 2, "restored ids must not collide");
    }
}
