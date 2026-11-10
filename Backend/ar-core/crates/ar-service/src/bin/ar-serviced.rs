use ar_service::server::{serve, ServerConfig};
use std::{sync::Arc, time::Duration};
use tokio::net::TcpListener;

const USAGE: &str = "ar-serviced [--bind ADDR] [--store-dir DIR] [--max-conn N] [--idle-secs N]\n  token: set AR_TOKEN in the environment (kept off the command line)";

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let mut cfg = ServerConfig::default();
    let mut bind = "127.0.0.1:7878".to_string();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        let mut val = || args.next().unwrap_or_else(|| { eprintln!("{USAGE}"); std::process::exit(2) });
        match a.as_str() {
            "--bind" => bind = val(),
            "--store-dir" => cfg.store_dir = Some(val().into()),
            "--max-conn" => cfg.max_connections = val().parse().expect("--max-conn"),
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
    // No visual frontend yet: clients stream `visual` poses. Plug a factory in here later.
    serve(listener, cfg, Arc::new(|| None), async { let _ = tokio::signal::ctrl_c().await; }).await
}
