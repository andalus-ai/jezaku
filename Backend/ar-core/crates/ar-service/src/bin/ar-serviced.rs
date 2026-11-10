use ar_service::server::{serve, ServerConfig};
use std::{sync::Arc, time::Duration};
use tokio::net::TcpListener;

const USAGE: &str = "ar-serviced [--bind ADDR] [--store-dir DIR] [--max-conn N] [--idle-secs N] [--frontend none|vo]\n  token: set AR_TOKEN in the environment (kept off the command line)";

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let mut cfg = ServerConfig::default();
    let mut bind = "127.0.0.1:7878".to_string();
    let mut use_vo = false;
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        let mut val = || args.next().unwrap_or_else(|| { eprintln!("{USAGE}"); std::process::exit(2) });
        match a.as_str() {
            "--bind" => bind = val(),
            "--store-dir" => cfg.store_dir = Some(val().into()),
            "--max-conn" => cfg.max_connections = val().parse().expect("--max-conn"),
            "--frontend" => use_vo = match val().as_str() { "vo" => true, "none" => false, _ => { eprintln!("{USAGE}"); std::process::exit(2) } },
            "--idle-secs" => cfg.idle_timeout = Duration::from_secs(val().parse().expect("--idle-secs")),
            _ => { eprintln!("{USAGE}"); std::process::exit(2) }
        }
    }
    cfg.auth_token = std::env::var("AR_TOKEN").ok().filter(|t| !t.is_empty());
    if cfg.auth_token.is_none() && !bind.starts_with("127.") && !bind.starts_with("localhost") {
        eprintln!("warning: listening on {bind} without AR_TOKEN set");
    }
    let listener = TcpListener::bind(&bind).await?;
    eprintln!("ar-serviced listening on {} (auth: {}, store: {:?})", listener.local_addr()?, cfg.auth_token.is_some(), cfg.store_dir);
    let factory: ar_service::server::FrontendFactory = if use_vo {
        // Monocular VO has arbitrary scale and reports an OpenCV-axes camera pose; default the
        // body<->camera extrinsic to a back camera on an Android-style sensor frame (clients can
        // override via `hello.t_body_cam`).
        cfg.fusion.estimate_scale = true;
        cfg.fusion.t_body_cam = ar_vo::t_body_cam_android_back();
        Arc::new(|| Some(Box::new(ar_vo::VoFrontend::new(ar_vo::VoConfig::default()))))
    } else {
        Arc::new(|| None)
    };
    eprintln!("frontend: {}", if use_vo { "vo (monocular, built-in)" } else { "none (clients send `visual` poses)" });
    serve(listener, cfg, factory, async { let _ = tokio::signal::ctrl_c().await; }).await
}
