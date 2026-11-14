//! tokio TCP transport (newline-delimited JSON).
//!
//! Hardening: optional shared-secret auth (constant-time compare), per-message size cap,
//! idle timeout, connection cap, one writer per named session, graceful shutdown that
//! persists named sessions.
use crate::protocol::*;
use crate::session::Session;
use crate::store::Store;
use crate::validate;
use ar_core::VisualFrontend;
use ar_fusion::FusionConfig;
use futures_util::{SinkExt, StreamExt};
use std::collections::HashSet;
use std::future::Future;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering::Relaxed};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio::io::AsyncWriteExt;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{watch, Semaphore};
use tokio::task::JoinSet;
use tokio::time::{interval, sleep_until, Interval, MissedTickBehavior};
use tokio_util::codec::{Framed, LinesCodec};

pub type FrontendFactory = Arc<dyn Fn() -> Option<Box<dyn VisualFrontend>> + Send + Sync>;

#[derive(Clone)]
pub struct ServerConfig {
    pub max_connections: usize,
    pub idle_timeout: Duration,
    /// Largest accepted line. A 640x480 gray frame is ~410 KB as base64.
    pub max_message_bytes: usize,
    /// If set, clients must `hello` with this token before anything else.
    pub auth_token: Option<String>,
    /// Enables named, resumable sessions.
    pub store_dir: Option<PathBuf>,
    pub fusion: FusionConfig,
    pub drain_timeout: Duration,
    /// Sustained per-connection message rate (messages/s); 0 disables limiting. A phone streaming
    /// 500 Hz IMU + 30 fps video + GNSS is ~600/s, so the default leaves generous headroom.
    pub max_msgs_per_sec: f64,
    /// Token-bucket capacity (allowed burst).
    pub rate_burst: f64,
}
impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            max_connections: 64,
            idle_timeout: Duration::from_secs(60),
            max_message_bytes: 4 << 20,
            auth_token: None,
            store_dir: None,
            fusion: FusionConfig::default(),
            drain_timeout: Duration::from_secs(5),
            max_msgs_per_sec: 3000.0,
            rate_burst: 600.0,
        }
    }
}

#[derive(Default)]
struct Metrics {
    connections_active: AtomicU64,
    connections_total: AtomicU64,
    requests: AtomicU64,
    errors: AtomicU64,
    imu: AtomicU64,
    gnss: AtomicU64,
    visual: AtomicU64,
    frames: AtomicU64,
}

struct Shared {
    cfg: ServerConfig,
    factory: FrontendFactory,
    store: Option<Store>,
    metrics: Metrics,
    active_names: Mutex<HashSet<String>>,
    started: Instant,
}

/// Serve until `shutdown` resolves, then drain connections (saving named sessions).
pub async fn serve(listener: TcpListener, cfg: ServerConfig, factory: FrontendFactory, shutdown: impl Future<Output = ()>) -> std::io::Result<()> {
    let store = cfg.store_dir.clone().map(Store::new).transpose()?;
    let shared = Arc::new(Shared { cfg, factory, store, metrics: Metrics::default(), active_names: Mutex::new(HashSet::new()), started: Instant::now() });
    let permits = Arc::new(Semaphore::new(shared.cfg.max_connections));
    let (stop_tx, stop_rx) = watch::channel(false);
    let mut tasks = JoinSet::new();
    tokio::pin!(shutdown);

    loop {
        tokio::select! {
            _ = &mut shutdown => break,
            Some(_) = tasks.join_next(), if !tasks.is_empty() => {}
            accepted = listener.accept() => {
                let (mut stream, _) = match accepted { Ok(a) => a, Err(_) => continue };
                let Ok(permit) = permits.clone().try_acquire_owned() else {
                    let _ = stream.write_all(b"{\"type\":\"error\",\"code\":\"busy\",\"message\":\"too many connections\"}\n").await;
                    continue;
                };
                let (sh, rx) = (shared.clone(), stop_rx.clone());
                tasks.spawn(async move { let _permit = permit; handle_conn(stream, sh, rx).await });
            }
        }
    }
    let _ = stop_tx.send(true);
    let _ = tokio::time::timeout(shared.cfg.drain_timeout, async { while tasks.join_next().await.is_some() {} }).await;
    tasks.abort_all();
    Ok(())
}

/// Per-connection token bucket, checked *before* JSON parsing so floods stay cheap.
struct Bucket { rate: f64, cap: f64, tokens: f64, last: Instant, strikes: u32 }
impl Bucket {
    fn new(rate: f64, cap: f64) -> Self { Self { rate, cap: cap.max(1.0), tokens: cap.max(1.0), last: Instant::now(), strikes: 0 } }
    /// `Ok(())` if allowed; `Err(true)` if the client has been over the limit for too long (disconnect).
    fn take(&mut self) -> Result<(), bool> {
        if self.rate <= 0.0 { return Ok(()); }
        let now = Instant::now();
        self.tokens = (self.tokens + now.duration_since(self.last).as_secs_f64() * self.rate).min(self.cap);
        self.last = now;
        if self.tokens >= 1.0 { self.tokens -= 1.0; self.strikes = 0; Ok(()) } else { self.strikes += 1; Err(self.strikes >= 200) }
    }
}

fn ct_eq(a: &str, b: &str) -> bool {
    a.len() == b.len() && a.bytes().zip(b.bytes()).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

async fn tick(t: &mut Option<Interval>) {
    match t { Some(i) => { i.tick().await; } None => std::future::pending::<()>().await }
}

type Conn = Framed<TcpStream, LinesCodec>;

async fn send(conn: &mut Conn, id: Option<u64>, resp: &Response, m: &Metrics) -> bool {
    if matches!(resp, Response::Error { .. }) { m.errors.fetch_add(1, Relaxed); }
    let line = serde_json::to_string(&ResponseEnvelope { id, resp }).unwrap_or_else(|_| r#"{"type":"error","code":"internal","message":"serialization failed"}"#.into());
    conn.send(line).await.is_ok()
}

async fn handle_conn(stream: TcpStream, sh: Arc<Shared>, mut stop: watch::Receiver<bool>) {
    let m = &sh.metrics;
    m.connections_total.fetch_add(1, Relaxed);
    m.connections_active.fetch_add(1, Relaxed);
    let _ = stream.set_nodelay(true);
    let mut conn: Conn = Framed::new(stream, LinesCodec::new_with_max_length(sh.cfg.max_message_bytes));
    let mut session = Session::new(sh.cfg.fusion.clone(), (sh.factory)());
    let mut authed = sh.cfg.auth_token.is_none();
    let mut hello_done = false;
    let mut name: Option<String> = None;
    let mut ticker: Option<Interval> = None;
    let mut deadline = tokio::time::Instant::now() + sh.cfg.idle_timeout;
    let mut bucket = Bucket::new(sh.cfg.max_msgs_per_sec, sh.cfg.rate_burst);

    loop {
        tokio::select! {
            _ = stop.changed() => break,
            _ = sleep_until(deadline) => { send(&mut conn, None, &Response::err(ErrorCode::BadRequest, "idle timeout"), m).await; break }
            _ = tick(&mut ticker) => {
                if !send(&mut conn, None, &Response::Pose(session.pose(None)), m).await { break }
            }
            line = conn.next() => {
                let line = match line {
                    None => break,
                    Some(Err(e)) => { send(&mut conn, None, &Response::err(ErrorCode::BadRequest, format!("bad message: {e}")), m).await; break }
                    Some(Ok(l)) => l,
                };
                deadline = tokio::time::Instant::now() + sh.cfg.idle_timeout;
                m.requests.fetch_add(1, Relaxed);
                if let Err(hang_up) = bucket.take() {
                    if !send(&mut conn, None, &Response::err(ErrorCode::Busy, "rate limit exceeded"), m).await || hang_up { break }
                    continue;
                }
                let env: Envelope = match serde_json::from_str(&line) {
                    Ok(e) => e,
                    Err(e) => { if !send(&mut conn, None, &Response::err(ErrorCode::BadRequest, e.to_string()), m).await { break } continue }
                };
                let id = env.id;
                if !authed && !matches!(env.req, Request::Hello { .. }) {
                    if !send(&mut conn, id, &Response::err(ErrorCode::Unauthorized, "send `hello` with a valid token first"), m).await { break }
                    continue;
                }
                match &env.req {
                    Request::Imu(_) => { m.imu.fetch_add(1, Relaxed); }
                    Request::Gnss(_) => { m.gnss.fetch_add(1, Relaxed); }
                    Request::Visual(_) => { m.visual.fetch_add(1, Relaxed); }
                    Request::Frame { .. } => { m.frames.fetch_add(1, Relaxed); }
                    _ => {}
                }
                let resp = match env.req {
                    Request::Hello { session: want, token, intrinsics, t_body_cam } => {
                        if hello_done { Response::err(ErrorCode::BadRequest, "hello already completed") }
                        else if sh.cfg.auth_token.as_deref().is_some_and(|t| !ct_eq(t, token.as_deref().unwrap_or(""))) {
                            send(&mut conn, id, &Response::err(ErrorCode::Unauthorized, "invalid token"), m).await;
                            break; // don't let a client brute-force over one connection
                        } else {
                            authed = true;
                            hello(&sh, &mut session, &mut name, &mut hello_done, want, intrinsics, t_body_cam).await
                        }
                    }
                    Request::Subscribe { hz } => {
                        if !hz.is_finite() || !(0.0..=60.0).contains(&hz) { Response::err(ErrorCode::InvalidValue, "hz must be within [0, 60]") }
                        else if hz == 0.0 { ticker = None; Response::Ok }
                        else {
                            let mut i = interval(Duration::from_secs_f64(1.0 / hz));
                            i.set_missed_tick_behavior(MissedTickBehavior::Skip);
                            ticker = Some(i);
                            Response::Ok
                        }
                    }
                    Request::Save => save(&sh, session.snapshot(), name.as_deref()).await,
                    Request::Stats => Response::Stats(stats(&sh, &session)),
                    // CPU-heavy work (visual odometry, plane RANSAC) must not run on the async executor: it would
                    // stall every other connection. Move the session to the blocking pool and take it back.
                    other if matches!(other, Request::Frame { .. } | Request::DetectPlanes) => {
                        let taken = std::mem::replace(&mut session, Session::new(sh.cfg.fusion.clone(), None));
                        match tokio::task::spawn_blocking(move || { let mut s = taken; let r = s.handle(other); (s, r) }).await {
                            Ok((s, r)) => { session = s; r }
                            Err(_) => {
                                // The worker panicked and took the session with it: tell the client and drop the connection.
                                send(&mut conn, id, &Response::err(ErrorCode::Internal, "internal error while processing request"), m).await;
                                break;
                            }
                        }
                    }
                    other => session.handle(other),
                };
                // Fire-and-forget: no id => no ack for successes.
                if id.is_none() && resp.is_ok() { continue; }
                if !send(&mut conn, id, &resp, m).await { break }
            }
        }
    }

    if name.is_some() { let _ = save(&sh, session.snapshot(), name.as_deref()).await; }
    if let Some(n) = name { sh.active_names.lock().unwrap().remove(&n); }
    m.connections_active.fetch_sub(1, Relaxed);
}

async fn hello(
    sh: &Arc<Shared>, session: &mut Session, name: &mut Option<String>, done: &mut bool,
    want: Option<String>, intrinsics: Option<ar_core::Intrinsics>, t_body_cam: Option<nalgebra::Isometry3<f64>>,
) -> Response {
    if let Err(e) = session.configure(intrinsics, t_body_cam) { return Response::err(ErrorCode::InvalidValue, e); }
    let mut restored = 0;
    if let Some(n) = want {
        if let Err(e) = validate::session_name(&n) { return Response::err(ErrorCode::InvalidValue, e); }
        if !sh.active_names.lock().unwrap().insert(n.clone()) {
            return Response::err(ErrorCode::Conflict, format!("session '{n}' is already connected"));
        }
        *name = Some(n.clone());
        if let Some(store) = sh.store.clone() {
            match tokio::task::spawn_blocking(move || store.load(&n)).await {
                Ok(Ok(Some(snap))) => restored = session.restore(snap),
                Ok(Ok(None)) => {}
                Ok(Err(e)) => return Response::err(ErrorCode::Internal, format!("could not load session: {e}")),
                Err(e) => return Response::err(ErrorCode::Internal, e.to_string()),
            }
        }
    }
    *done = true;
    Response::Welcome { protocol: PROTOCOL_VERSION, session: name.clone(), restored_anchors: restored, frontend: session.has_frontend() }
}

async fn save(sh: &Arc<Shared>, snap: crate::store::Snapshot, name: Option<&str>) -> Response {
    let (Some(store), Some(name)) = (sh.store.clone(), name) else {
        return Response::err(ErrorCode::Unsupported, "saving needs a named session (hello.session) and a server --store-dir");
    };
    let (n, count) = (name.to_owned(), snap.anchors.len());
    match tokio::task::spawn_blocking(move || store.save(&n, &snap)).await {
        Ok(Ok(())) => Response::Saved { anchors: count },
        Ok(Err(e)) => Response::err(ErrorCode::Internal, format!("save failed: {e}")),
        Err(e) => Response::err(ErrorCode::Internal, e.to_string()),
    }
}

fn stats(sh: &Shared, s: &Session) -> StatsDto {
    let m = &sh.metrics;
    StatsDto {
        uptime_s: sh.started.elapsed().as_secs(),
        connections_active: m.connections_active.load(Relaxed),
        connections_total: m.connections_total.load(Relaxed),
        requests: m.requests.load(Relaxed), errors: m.errors.load(Relaxed),
        imu: m.imu.load(Relaxed), gnss: m.gnss.load(Relaxed), visual: m.visual.load(Relaxed), frames: m.frames.load(Relaxed),
        session_anchors: s.anchor_count(),
    }
}
