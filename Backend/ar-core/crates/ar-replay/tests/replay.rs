use ar_replay::dataset::parse_euroc_sensor_yaml;
use ar_replay::gen::{generate, GenOpts, Layout};
use ar_replay::imageio::{load_gray, write_pgm, write_png_gray};
use ar_replay::{load_euroc, load_native, replay, ReplayOpts};
use ar_vo::Distortion;
use std::path::PathBuf;

fn tmp(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("ar-replay-{tag}-{}-{:?}", std::process::id(), std::time::Instant::now()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

// Verbatim layout of EuRoC MAV `cam0/sensor.yaml` (values from the Machine Hall sequences).
const EUROC_YAML: &str = "# General sensor definitions.
sensor_type: camera
comment: VI-Sensor cam0 (MT9M034)

# Sensor extrinsics wrt. the body-frame.
T_BS:
  cols: 4
  rows: 4
  data: [0.0148655429818, -0.999880929698, 0.00414029679422, -0.0216401454975,
         0.999557249008, 0.0149672133247, 0.025715529948, -0.064676986768,
        -0.0257744366974, 0.00375618835797, 0.999660727178, 0.00981073058949,
         0.0, 0.0, 0.0, 1.0]

# Camera specific definitions.
rate_hz: 20
resolution: [752, 480]
camera_model: pinhole
intrinsics: [458.654, 457.296, 367.215, 248.375] #fu, fv, cu, cv
distortion_model: radial-tangential
distortion_coefficients: [-0.28340811, 0.07395907, 0.00019359, 1.76187114e-05]
";

#[test]
fn parses_euroc_sensor_yaml() {
    let c = parse_euroc_sensor_yaml(EUROC_YAML).unwrap();
    assert_eq!((c.intrinsics.width, c.intrinsics.height), (752, 480));
    assert_eq!((c.intrinsics.fx, c.intrinsics.fy, c.intrinsics.cx, c.intrinsics.cy), (458.654, 457.296, 367.215, 248.375));
    assert_eq!((c.distortion.k1, c.distortion.k2, c.distortion.p1, c.distortion.p2), (-0.28340811, 0.07395907, 0.00019359, 1.76187114e-05));
    assert!((c.t_body_cam.translation.vector.x + 0.0216401454975).abs() < 1e-12 && (c.t_body_cam.translation.vector.z - 0.00981073058949).abs() < 1e-12);
    assert!((c.t_body_cam.rotation.to_rotation_matrix()[(0, 1)] + 0.999880929698).abs() < 1e-6, "rotation block read row-major");
    assert!(parse_euroc_sensor_yaml("intrinsics: [1, 2]").is_err(), "incomplete files are rejected, not guessed");
}

#[test]
fn image_io_roundtrips() {
    let d = tmp("img");
    let data: Vec<u8> = (0..24 * 16).map(|i| (i * 7 % 251) as u8).collect();
    write_pgm(&d.join("a.pgm"), 24, 16, &data).unwrap();
    write_png_gray(&d.join("a.png"), 24, 16, &data).unwrap();
    for f in ["a.pgm", "a.png"] {
        let img = load_gray(&d.join(f)).unwrap();
        assert_eq!((img.w, img.h), (24, 16));
        assert_eq!(img.data, data, "{f}");
    }
    // RGB PNG -> luma.
    let rgb: Vec<u8> = (0..4 * 4).flat_map(|_| [200u8, 100, 50]).collect();
    let file = std::io::BufWriter::new(std::fs::File::create(d.join("c.png")).unwrap());
    let mut enc = png::Encoder::new(file, 4, 4);
    enc.set_color(png::ColorType::Rgb);
    enc.set_depth(png::BitDepth::Eight);
    enc.write_header().unwrap().write_image_data(&rgb).unwrap();
    let luma = load_gray(&d.join("c.png")).unwrap();
    assert!(luma.data.iter().all(|&v| v == ((299 * 200 + 587 * 100 + 114 * 50) / 1000) as u8));
    assert!(load_gray(&d.join("missing.png")).is_err() && load_gray(&d.join("x.jpg")).is_err());
    let _ = std::fs::remove_dir_all(d);
}

fn opts(layout: Layout, frames: usize) -> GenOpts {
    GenOpts { frames, layout, distortion: Distortion::new(-0.25, 0.06, 0.002, -0.001), imu_noise: true, ..Default::default() }
}

#[test]
fn native_dataset_end_to_end_with_gnss() {
    let d = tmp("native");
    generate(&d, &opts(Layout::Native, 150)).unwrap();
    let ds = load_native(&d).unwrap();
    assert_eq!((ds.frames.len(), ds.gnss.len() > 20, ds.imu.len() > 900, ds.truth.len()), (150, true, true, 150));
    let r = replay(&ds, &ReplayOpts { min_baseline_m: 3.0, ..Default::default() }).unwrap();
    r.print();
    assert_eq!((r.rejected_sensor_samples, r.frame_errors, r.map_resets), (0, 0, 0), "{r:?}");
    assert!(r.tracking_fraction > 0.9, "tracked {:.0}%", 100.0 * r.tracking_fraction);
    assert!(r.geo_aligned, "GNSS + motion must lock the map to ENU");
    assert_eq!(r.final_tracking, "Tracking");
    let ate = &r.ate[0];
    assert!(ate.percent_of_path < 1.5, "ATE {:.2}% of path", ate.percent_of_path);
    // Truth is in ENU here, so the *fused* world pose is scored too (GNSS jitter is ~0.4 m and the ENU origin is the first, jittered, fix).
    let (med, p95) = (r.fused_err_median_m.expect("fused error reported"), r.fused_err_p95_m.unwrap());
    assert!(med < 0.8 && p95 < 1.5, "fused error median {med:.2} m, p95 {p95:.2} m");
    let _ = std::fs::remove_dir_all(d);
}

#[test]
fn euroc_layout_end_to_end() {
    let d = tmp("euroc");
    generate(&d, &opts(Layout::Euroc, 100)).unwrap();
    let ds = load_euroc(&d).unwrap(); // accepts the parent of mav0/
    assert_eq!((ds.frames.len(), ds.gnss.len()), (100, 0));
    assert!(ds.frames[0].t == 0.0 && (ds.frames[99].t - 99.0 / 30.0).abs() < 1e-6, "epoch-ns timestamps rebased without precision loss");
    assert!((ds.distortion.k1 + 0.25).abs() < 1e-12);
    let r = replay(&ds, &ReplayOpts::default()).unwrap();
    r.print();
    assert_eq!((r.frame_errors, r.map_resets), (0, 0));
    assert!(r.tracking_fraction > 0.9);
    assert!(!r.geo_aligned, "no GNSS in this layout");
    assert!(r.fused_err_median_m.is_none(), "no ENU truth => no fused-pose error is claimed");
    assert!(r.ate[0].percent_of_path < 1.5, "ATE {:.2}%", r.ate[0].percent_of_path);
    let _ = std::fs::remove_dir_all(d);
}

#[test]
fn rejects_bad_datasets_with_clear_errors() {
    let d = tmp("bad");
    generate(&d, &GenOpts { frames: 20, ..Default::default() }).unwrap();
    std::fs::remove_file(d.join("frames/00003.pgm")).unwrap();
    let e = load_native(&d).err().expect("missing image must fail");
    assert!(e.contains("missing image"), "{e}");
    assert!(load_native(&tmp("empty")).is_err());
    let _ = std::fs::remove_dir_all(d);
}
