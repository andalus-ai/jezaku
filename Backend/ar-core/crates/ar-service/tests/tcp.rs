use ar_geo::EnuFrame;
use ar_service::server::{serve, ServerConfig};
use nalgebra::{Isometry3, Translation3, UnitQuaternion, Vector3};
use serde_json::{json, Value};
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{tcp::OwnedReadHalf, tcp::OwnedWriteHalf, TcpListener, TcpStream};
use tokio::sync::oneshot;
use tokio::task::JoinHandle;

struct Srv { addr: SocketAddr, stop: Option<oneshot::Sender<()>>, join: JoinHandle<()> }
impl Srv {
    async fn start(cfg: ServerConfig) -> Srv {
        let l = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = l.local_addr().unwrap();
        let (tx, rx) = oneshot::channel();
        let join = tokio::spawn(async move { serve(l, cfg, Arc::new(|| None), async { let _ = rx.await; }).await.unwrap() });
        Srv { addr, stop: Some(tx), join }
    }
    async fn shutdown(mut self) { let _ = self.stop.take().unwrap().send(()); self.join.await.unwrap(); }
}

struct Client { r: BufReader<OwnedReadHalf>, w: OwnedWriteHalf }
impl Client {
    async fn connect(addr: SocketAddr) -> Client {
        let (r, w) = TcpStream::connect(addr).await.unwrap().into_split();
        Client { r: BufReader::new(r), w }
    }
    async fn send(&mut self, v: Value) { self.w.write_all(format!("{v}\n").as_bytes()).await.unwrap(); }
    async fn recv(&mut self) -> Option<Value> {
        let mut s = String::new();
        let n = tokio::time::timeout(Duration::from_secs(5), self.r.read_line(&mut s)).await.expect("recv timeout").unwrap_or(0);
        (n > 0).then(|| serde_json::from_str(&s).unwrap())
    }
    async fn call(&mut self, id: u64, mut v: Value) -> Value {
        v["id"] = json!(id);
        self.send(v).await;
        let r = self.recv().await.expect("connection closed");
        assert_eq!(r["id"], json!(id), "response id must echo request id: {r}");
        r
    }
}

fn iso(i: &Isometry3<f64>) -> Value { serde_json::to_value(i).unwrap() }
const G: f64 = 9.80665;

/// Stream a synthetic walk (no ids => no acks) so the server aligns map -> ENU.
async fn walk(c: &mut Client, enu: &EnuFrame, map_from_world: &Isometry3<f64>, steps: usize) {
    c.send(json!({"type":"imu","t":0.0,"gyro":[0,0,0],"accel":[0,0,G]})).await;
    for k in 0..steps {
        let t = (k + 1) as f64 * 0.1;
        let p_w = Vector3::new(k as f64 * 0.2, k as f64 * 0.1 + (k as f64 * 0.1).sin(), 0.0);
        let (la, lo, al) = enu.to_geodetic(&p_w);
        let pose = map_from_world * Isometry3::from_parts(p_w.into(), UnitQuaternion::identity());
        c.send(json!({"type":"imu","t":t,"gyro":[0,0,0],"accel":[0,0,G]})).await;
        c.send(json!({"type":"visual","t":t,"t_map_cam":iso(&pose),"quality":0.9,"map_id":0})).await;
        c.send(json!({"type":"gnss","t":t,"lat_deg":la,"lon_deg":lo,"alt_m":al,"h_acc":1.0,"v_acc":1.5})).await;
    }
}

fn fixtures() -> (EnuFrame, Isometry3<f64>) {
    (EnuFrame::new(-6.9175, 107.6191, 700.0),
     Isometry3::from_parts(Translation3::new(10.0, -4.0, 1.0), UnitQuaternion::from_euler_angles(0.0, 0.0, 0.9)))
}

fn tmpdir(tag: &str) -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!("ar-service-{tag}-{}-{:?}", std::process::id(), std::time::Instant::now()));
    let _ = std::fs::remove_dir_all(&d);
    d
}

#[tokio::test]
async fn full_pipeline_pose_planes_hit_anchors_stats() {
    let srv = Srv::start(ServerConfig { auth_token: Some("s3cret".into()), ..Default::default() }).await;
    let mut c = Client::connect(srv.addr).await;
    let w = c.call(1, json!({"type":"hello","token":"s3cret"})).await;
    assert_eq!(w["type"], "welcome");

    let (enu, m) = fixtures();
    walk(&mut c, &enu, &m, 200).await;

    let pose = c.call(2, json!({"type":"get_pose"})).await;
    assert_eq!(pose["type"], "pose");
    assert_eq!(pose["geo_aligned"], true, "{pose}");
    assert_eq!(pose["tracking"], "tracking");
    assert!(pose["geo"]["lat_deg"].as_f64().unwrap() < -6.0);
    let predicted = c.call(3, json!({"type":"get_pose","predict_ms":16})).await;
    assert_eq!(predicted["type"], "pose");

    // Floor (world z=0) + wall as map points; map frame is offset by `m`.
    let mut pts: Vec<Value> = vec![];
    for i in 0..20 { for j in 0..20 {
        let p = m * nalgebra::Point3::new(i as f64 * 0.1, j as f64 * 0.1, 0.0);
        pts.push(json!([p.x, p.y, p.z]));
    } }
    let r = c.call(4, json!({"type":"map_points","points":pts})).await;
    assert_eq!(r["type"], "ok");
    let planes = c.call(5, json!({"type":"detect_planes"})).await;
    assert!(planes["planes"].as_array().unwrap().iter().any(|p| p["horizontal"] == true), "{planes}");

    let hits = c.call(6, json!({"type":"hit_test","origin":[1.0,1.0,2.0],"dir":[0,0,-1]})).await;
    let h = &hits["hits"][0];
    assert!((h["distance"].as_f64().unwrap() - 2.0).abs() < 0.05, "{hits}");
    let miss = c.call(7, json!({"type":"hit_test","origin":[50.0,50.0,2.0],"dir":[0,0,-1]})).await;
    assert!(miss["hits"].as_array().unwrap().is_empty());

    // Anchors: map-attached once aligned; geo anchor independent of the map.
    let a = c.call(8, json!({"type":"create_anchor","pose":iso(&Isometry3::translation(1.0, 1.0, 0.0))})).await;
    assert_eq!(a["type"], "anchor_created");
    let g = c.call(9, json!({"type":"create_geo_anchor","lat_deg":-6.9175,"lon_deg":107.6191,"alt_m":700.0,"heading_deg":90.0})).await;
    assert_eq!(g["type"], "anchor_created");
    let list = c.call(10, json!({"type":"list_anchors"})).await;
    let anchors = list["anchors"].as_array().unwrap();
    assert_eq!(anchors.len(), 2);
    assert!(anchors.iter().any(|a| a["kind"] == "map" && a["state"] == "tracking"));
    assert!(anchors.iter().any(|a| a["kind"] == "geo" && a["state"] == "tracking"));

    // remove_anchor uses `anchor_id` (the `id` key belongs to the request envelope).
    let removed = c.call(12, json!({"type":"remove_anchor","anchor_id":a["anchor_id"]})).await;
    assert_eq!(removed["type"], "ok", "{removed}");
    assert_eq!(c.call(13, json!({"type":"remove_anchor","anchor_id":a["anchor_id"]})).await["code"], "not_found");
    let list = c.call(14, json!({"type":"list_anchors"})).await;
    assert_eq!(list["anchors"].as_array().unwrap().len(), 1);
    // Re-create so the stats check below still sees 2.
    c.call(15, json!({"type":"create_anchor","pose":iso(&Isometry3::translation(1.0, 1.0, 0.0))})).await;

    let st = c.call(11, json!({"type":"stats"})).await;
    assert!(st["imu"].as_u64().unwrap() >= 200 && st["visual"].as_u64().unwrap() >= 200 && st["session_anchors"] == 2);
    srv.shutdown().await;
}

#[tokio::test]
async fn auth_is_enforced() {
    let srv = Srv::start(ServerConfig { auth_token: Some("s3cret".into()), ..Default::default() }).await;
    let mut c = Client::connect(srv.addr).await;
    assert_eq!(c.call(1, json!({"type":"get_pose"})).await["code"], "unauthorized");
    let bad = c.call(2, json!({"type":"hello","token":"nope"})).await;
    assert_eq!(bad["code"], "unauthorized");
    assert!(c.recv().await.is_none(), "connection must close after a bad token");
    srv.shutdown().await;
}

#[tokio::test]
async fn fire_and_forget_acks_suppressed_but_errors_always_sent() {
    let srv = Srv::start(ServerConfig::default()).await;
    let mut c = Client::connect(srv.addr).await;
    c.send(json!({"type":"imu","t":0.0,"gyro":[0,0,0],"accel":[0,0,G]})).await; // no id: silent
    c.send(json!({"type":"imu","t":0.1,"gyro":[1e9,0,0],"accel":[0,0,G]})).await; // invalid: error
    let e = c.recv().await.unwrap();
    assert_eq!((e["type"].as_str(), e["code"].as_str()), (Some("error"), Some("invalid_value")), "{e}");
    c.send(json!({"type":"nonsense"})).await;
    assert_eq!(c.recv().await.unwrap()["code"], "bad_request");
    srv.shutdown().await;
}

#[tokio::test]
async fn oversized_message_closes_connection() {
    let srv = Srv::start(ServerConfig { max_message_bytes: 1024, ..Default::default() }).await;
    let mut c = Client::connect(srv.addr).await;
    c.w.write_all(&vec![b'a'; 4096]).await.unwrap();
    c.w.write_all(b"\n").await.unwrap();
    assert_eq!(c.recv().await.unwrap()["code"], "bad_request");
    assert!(c.recv().await.is_none());
    srv.shutdown().await;
}

#[tokio::test]
async fn idle_timeout_and_connection_cap() {
    let srv = Srv::start(ServerConfig { idle_timeout: Duration::from_millis(300), max_connections: 1, ..Default::default() }).await;
    let mut a = Client::connect(srv.addr).await;
    let mut b = Client::connect(srv.addr).await;
    assert_eq!(b.recv().await.unwrap()["code"], "busy");
    let idle = a.recv().await.unwrap();
    assert_eq!(idle["message"], "idle timeout");
    srv.shutdown().await;
}

#[tokio::test]
async fn subscribe_pushes_poses() {
    let srv = Srv::start(ServerConfig::default()).await;
    let mut c = Client::connect(srv.addr).await;
    assert_eq!(c.call(1, json!({"type":"subscribe","hz":50.0})).await["type"], "ok");
    for _ in 0..3 { let p = c.recv().await.unwrap(); assert_eq!(p["type"], "pose"); assert!(p.get("id").is_none()); }
    assert_eq!(c.call(2, json!({"type":"subscribe","hz":0})).await["type"], "ok");
    assert_eq!(c.call(3, json!({"type":"subscribe","hz":500})).await["code"], "invalid_value");
    srv.shutdown().await;
}

#[tokio::test]
async fn named_sessions_persist_resume_and_are_exclusive() {
    let dir = tmpdir("persist");
    let cfg = || ServerConfig { store_dir: Some(dir.clone()), ..Default::default() };
    let srv = Srv::start(cfg()).await;
    let mut a = Client::connect(srv.addr).await;
    assert_eq!(a.call(1, json!({"type":"hello","session":"site-A"})).await["restored_anchors"], 0);
    let mut dup = Client::connect(srv.addr).await;
    assert_eq!(dup.call(1, json!({"type":"hello","session":"site-A"})).await["code"], "conflict");
    let mut evil = Client::connect(srv.addr).await;
    assert_eq!(evil.call(1, json!({"type":"hello","session":"../etc/passwd"})).await["code"], "invalid_value");

    // A GNSS fix defines (and persists) the ENU origin the anchors are expressed in.
    a.send(json!({"type":"imu","t":0.0,"gyro":[0,0,0],"accel":[0,0,G]})).await;
    a.send(json!({"type":"gnss","t":0.1,"lat_deg":-6.9175,"lon_deg":107.6191,"alt_m":700.0,"h_acc":2.0,"v_acc":3.0})).await;
    assert_eq!(a.call(2, json!({"type":"create_geo_anchor","lat_deg":-6.9,"lon_deg":107.6,"alt_m":700.0,"heading_deg":10.0})).await["type"], "anchor_created");
    assert_eq!(a.call(3, json!({"type":"save"})).await["anchors"], 1);
    drop(a);
    tokio::time::sleep(Duration::from_millis(100)).await;

    let mut a2 = Client::connect(srv.addr).await;
    assert_eq!(a2.call(1, json!({"type":"hello","session":"site-A"})).await["restored_anchors"], 1, "name is free again after disconnect");
    // Shutdown with a live named session must persist it too.
    a2.call(2, json!({"type":"create_geo_anchor","lat_deg":-6.8,"lon_deg":107.5,"alt_m":690.0})).await;
    srv.shutdown().await;

    let srv2 = Srv::start(cfg()).await;
    let mut a3 = Client::connect(srv2.addr).await;
    let w = a3.call(1, json!({"type":"hello","session":"site-A"})).await;
    assert_eq!(w["restored_anchors"], 2, "{w}");
    let l = a3.call(2, json!({"type":"list_anchors"})).await;
    assert!(l["anchors"].as_array().unwrap().iter().all(|a| a["state"] == "tracking"), "ENU origin restored => geo anchors resolve: {l}");
    // Ids continue where they left off.
    assert_eq!(a3.call(3, json!({"type":"create_geo_anchor","lat_deg":0.0,"lon_deg":0.0,"alt_m":0.0})).await["anchor_id"], 3);

    // Without any stored origin, geo anchors wait (paused) and resolve at the first fix.
    let mut b = Client::connect(srv2.addr).await;
    b.call(1, json!({"type":"hello","session":"site-B"})).await;
    b.call(2, json!({"type":"create_geo_anchor","lat_deg":-6.9,"lon_deg":107.6,"alt_m":700.0})).await;
    let before = b.call(3, json!({"type":"list_anchors"})).await;
    assert_eq!(before["anchors"][0]["state"], "paused");
    b.send(json!({"type":"gnss","t":0.1,"lat_deg":-6.9,"lon_deg":107.6,"alt_m":700.0,"h_acc":2.0,"v_acc":3.0})).await;
    let after = b.call(4, json!({"type":"list_anchors"})).await;
    assert_eq!(after["anchors"][0]["state"], "tracking", "{after}");
    srv2.shutdown().await;
    let _ = std::fs::remove_dir_all(dir);
}
