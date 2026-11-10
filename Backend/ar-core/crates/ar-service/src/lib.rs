//! ARCore-style session service.
//!
//! * `protocol`  – wire types (NDJSON envelopes, request ids, typed errors)
//! * `validate`  – input sanity checks (finite numbers, unit quaternions, ranges)
//! * `anchors`   – world / map-attached / geospatial anchors with tracking states
//! * `store`     – atomic on-disk persistence of resumable sessions
//! * `session`   – transport-independent logic (fusion, planes, hit-test, anchors)
//! * `server`    – tokio TCP transport: auth, limits, idle timeout, push poses, shutdown
pub mod anchors;
pub mod protocol;
pub mod server;
pub mod session;
pub mod store;
pub mod validate;

pub use protocol::{ErrorCode, Request, Response};
pub use session::Session;
