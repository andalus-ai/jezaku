use ar_core::VisualFrontend;
use ar_fusion::align::umeyama;
use ar_vo::synth::{default_intrinsics, trajectory, Room};
use ar_vo::{Distortion, Undistorter, VoConfig, VoFrontend};

fn ate_pct(undistort: bool, dist: &Distortion) -> (usize, f64, usize) {
    let (room, k) = (Room::default(), default_intrinsics());
    let un = Undistorter::new(&k, dist);
    let mut vo = VoFrontend::new(VoConfig::default());
    let (mut est, mut gt, mut ids) = (vec![], vec![], std::collections::BTreeSet::new());
    for f in 0..100 {
        let tr = trajectory(f);
        let img = room.render_with(&k, dist, &tr);
        let img = if undistort { un.apply(&img) } else { img };
        if let Some(vp) = vo.track(f as f64 / 30.0, &img, &k) { ids.insert(vp.map_id); est.push(vp.t_map_cam.translation.vector); gt.push(tr.translation.vector); }
    }
    if est.len() < 10 { return (est.len(), f64::NAN, ids.len()); }
    let sim = umeyama(&est, &gt, true).unwrap();
    let path: f64 = gt.windows(2).map(|w| (w[1] - w[0]).norm()).sum();
    let rmse = (est.iter().zip(&gt).map(|(e, g)| (sim.apply(e) - g).norm_squared()).sum::<f64>() / est.len() as f64).sqrt();
    (est.len(), 100.0 * rmse / path, ids.len())
}

#[test]
fn undistortion_is_needed_and_works() {
    let d = Distortion { k1: -0.25, k2: 0.06, p1: 0.002, p2: -0.001, k3: 0.0 };
    let (n_raw, raw, maps_raw) = ate_pct(false, &d);
    let (n_fix, fixed, maps_fix) = ate_pct(true, &d);
    let (n_ref, reference, _) = ate_pct(false, &Distortion::default());
    eprintln!("no distortion:        poses {n_ref}, ATE {reference:.2}%");
    eprintln!("distorted, raw:       poses {n_raw}, ATE {raw:.2}%, maps {maps_raw}");
    eprintln!("distorted, undistort: poses {n_fix}, ATE {fixed:.2}%, maps {maps_fix}");
    assert!(maps_fix == 1 && n_fix >= 85, "undistorted run must track cleanly");
    assert!(fixed < 1.5, "undistorted ATE {fixed:.2}%");
    assert!(raw.is_nan() || raw > 2.0 * fixed || maps_raw > 1, "skipping undistortion should visibly hurt (raw {raw:.2}% vs {fixed:.2}%)");
}
