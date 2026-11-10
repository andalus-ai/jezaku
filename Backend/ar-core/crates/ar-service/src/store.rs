//! Atomic JSON persistence for resumable sessions (write temp file, fsync, rename).
use crate::anchors::AnchorRecord;
use serde::{Deserialize, Serialize};
use std::io::{self, Write};
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize)]
pub struct Snapshot {
    pub version: u32,
    /// (lat_deg, lon_deg, alt_m) of the ENU origin the anchors were expressed in.
    pub enu_origin: Option<(f64, f64, f64)>,
    pub next_anchor_id: u64,
    pub anchors: Vec<AnchorRecord>,
}

#[derive(Debug, Clone)]
pub struct Store { dir: PathBuf }

impl Store {
    pub fn new(dir: impl Into<PathBuf>) -> io::Result<Self> {
        let dir = dir.into();
        std::fs::create_dir_all(&dir)?;
        Ok(Self { dir })
    }

    fn path(&self, name: &str) -> io::Result<PathBuf> {
        crate::validate::session_name(name).map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?;
        Ok(self.dir.join(format!("{name}.json")))
    }

    pub fn load(&self, name: &str) -> io::Result<Option<Snapshot>> {
        match std::fs::read(self.path(name)?) {
            Ok(b) => serde_json::from_slice(&b).map(Some).map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e)),
            Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(None),
            Err(e) => Err(e),
        }
    }

    pub fn save(&self, name: &str, snap: &Snapshot) -> io::Result<()> {
        let path = self.path(name)?;
        let tmp = path.with_extension("json.tmp");
        {
            let mut f = std::fs::File::create(&tmp)?;
            f.write_all(&serde_json::to_vec_pretty(snap).map_err(io::Error::other)?)?;
            f.sync_all()?;
        }
        std::fs::rename(tmp, path)
    }
}
