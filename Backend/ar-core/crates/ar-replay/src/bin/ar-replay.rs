use ar_replay::gen::{generate, GenOpts, Layout};
use ar_replay::{load_euroc, load_native, replay, ReplayOpts};
use ar_vo::Distortion;
use std::path::PathBuf;

const USAGE: &str = "\
ar-replay run <dir> [--euroc] [--imu-offset-ms N] [--min-baseline M] [--max-frames N] [--json]
ar-replay gen <dir> [--euroc] [--frames N] [--distortion] [--imu-noise]

run   replays a dataset through the AR session (VO + fusion) and prints tracking, ATE and timing.
      native layout: calib.json imu.csv frames.csv [gnss.csv] [truth.csv]; --euroc reads a EuRoC MAV folder (mav0/).
gen   writes a synthetic dataset (rendered frames, IMU derived from the true motion) to try the tool end to end.";

fn main() {
    let mut args = std::env::args().skip(1);
    let (Some(cmd), Some(dir)) = (args.next(), args.next()) else { eprintln!("{USAGE}"); std::process::exit(2) };
    let dir = PathBuf::from(dir);
    let (mut euroc, mut json, mut distortion, mut noise) = (false, false, false, false);
    let (mut ropts, mut gopts) = (ReplayOpts::default(), GenOpts::default());
    while let Some(a) = args.next() {
        let mut val = || args.next().unwrap_or_else(|| { eprintln!("{USAGE}"); std::process::exit(2) });
        match a.as_str() {
            "--euroc" => euroc = true,
            "--json" => json = true,
            "--distortion" => distortion = true,
            "--imu-noise" => noise = true,
            "--imu-offset-ms" => ropts.imu_offset_s = val().parse::<f64>().expect("--imu-offset-ms") / 1000.0,
            "--min-baseline" => ropts.min_baseline_m = val().parse().expect("--min-baseline"),
            "--max-frames" => { let n = val().parse().expect("--max-frames"); ropts.max_frames = Some(n); gopts.frames = n }
            "--frames" => gopts.frames = val().parse().expect("--frames"),
            _ => { eprintln!("{USAGE}"); std::process::exit(2) }
        }
    }
    let result = match cmd.as_str() {
        "gen" => {
            gopts.layout = if euroc { Layout::Euroc } else { Layout::Native };
            gopts.imu_noise = noise;
            if distortion { gopts.distortion = Distortion::new(-0.25, 0.06, 0.002, -0.001); }
            generate(&dir, &gopts).map(|_| println!("wrote {} frames to {}", gopts.frames, dir.display()))
        }
        "run" => {
            let ds = if euroc { load_euroc(&dir) } else { load_native(&dir) };
            ds.and_then(|ds| replay(&ds, &ropts)).map(|r| if json { println!("{}", serde_json::to_string_pretty(&r).unwrap()) } else { r.print() })
        }
        _ => { eprintln!("{USAGE}"); std::process::exit(2) }
    };
    if let Err(e) = result { eprintln!("error: {e}"); std::process::exit(1); }
}
