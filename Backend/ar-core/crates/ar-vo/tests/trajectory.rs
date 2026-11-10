use ar_core::{TrackingState, VisualFrontend};
use ar_fusion::align::umeyama;
use ar_vo::synth::{default_intrinsics, trajectory, Room};
use ar_vo::{VoConfig, VoFrontend};
use nalgebra::Vector3;

#[test]
fn tracks_rendered_trajectory_with_low_drift() {
    let (room, k) = (Room::default(), default_intrinsics());
    let mut vo = VoFrontend::new(VoConfig::default());
    let (mut est, mut gt, mut rot_pairs, mut frames, mut map_ids) = (vec![], vec![], vec![], 0, std::collections::HashSet::new());
    for f in 0..100 {
        let truth = trajectory(f);
        let img = room.render(&k, &truth);
        frames += 1;
        if let Some(vp) = vo.track(f as f64 / 30.0, &img, &k) {
            map_ids.insert(vp.map_id);
            est.push(vp.t_map_cam.translation.vector);
            gt.push(truth.translation.vector);
            rot_pairs.push((vp.t_map_cam.rotation, truth.rotation));
        }
    }
    eprintln!("poses {}/{frames}, state {:?}, landmarks {}", est.len(), vo.state(), vo.map_points().len());
    assert_eq!(map_ids.len(), 1, "tracking should never reset on this sequence");
    assert!(est.len() >= 85, "too few poses: {}", est.len());
    assert_eq!(vo.state(), TrackingState::Tracking);

    let sim = umeyama(&est, &gt, true).expect("alignment");
    let path: f64 = gt.windows(2).map(|w| (w[1] - w[0]).norm()).sum();
    let rmse = (est.iter().zip(&gt).map(|(e, g)| (sim.apply(e) - g).norm_squared()).sum::<f64>() / est.len() as f64).sqrt();
    // Relative rotation (first estimated pose as reference) vs ground truth.
    let (e0, g0) = rot_pairs[0];
    let rot_err = rot_pairs.iter().map(|(e, g)| ((e0.inverse() * e).angle_to(&(g0.inverse() * g))).to_degrees()).fold(0.0, f64::max);
    eprintln!("path {path:.2} m, ATE rmse {rmse:.3} m ({:.1}% of path), scale {:.3}, max rot err {rot_err:.2} deg", 100.0 * rmse / path, sim.scale);
    assert!(rmse / path < 0.03, "ATE {:.1}% of path", 100.0 * rmse / path);
    assert!(rot_err < 3.0, "rotation error {rot_err} deg");
    let _ = Vector3::<f64>::zeros();
}

fn noisy(img: &[u8], frame: usize, sigma: f64, gain: f64) -> Vec<u8> {
    img.iter().enumerate().map(|(i, &p)| {
        let mut h = (i as u32).wrapping_mul(2_654_435_761) ^ (frame as u32).wrapping_mul(40_503);
        h ^= h >> 13; h = h.wrapping_mul(0x5bd1_e995); h ^= h >> 15;
        let n = ((h & 0xFFFF) as f64 / 65535.0 - 0.5) * 2.0 * sigma * 1.7; // ~uniform, std ≈ sigma
        (p as f64 * gain + n).clamp(0.0, 255.0) as u8
    }).collect()
}

#[test]
fn survives_sensor_noise_and_exposure_drift() {
    let (room, k) = (Room::default(), default_intrinsics());
    let mut vo = VoFrontend::new(VoConfig::default());
    let (mut est, mut gt) = (vec![], vec![]);
    for f in 0..100 {
        let truth = trajectory(f);
        let gain = 1.0 + 0.12 * (f as f64 * 0.07).sin(); // auto-exposure wobble
        let img = noisy(&room.render(&k, &truth), f, 4.0, gain);
        if let Some(vp) = vo.track(f as f64 / 30.0, &img, &k) {
            est.push(vp.t_map_cam.translation.vector);
            gt.push(truth.translation.vector);
        }
    }
    assert!(est.len() >= 80, "only {} poses under noise", est.len());
    let sim = umeyama(&est, &gt, true).unwrap();
    let path: f64 = gt.windows(2).map(|w| (w[1] - w[0]).norm()).sum();
    let rmse = (est.iter().zip(&gt).map(|(e, g)| (sim.apply(e) - g).norm_squared()).sum::<f64>() / est.len() as f64).sqrt();
    eprintln!("noisy: poses {}, ATE {:.1}% of path", est.len(), 100.0 * rmse / path);
    assert!(rmse / path < 0.06, "ATE {:.1}% of path under noise", 100.0 * rmse / path);
}

#[test]
fn blackout_forces_new_map_then_recovers() {
    let (room, k) = (Room::default(), default_intrinsics());
    let mut vo = VoFrontend::new(VoConfig::default());
    let blank = vec![90u8; (k.width * k.height) as usize]; // lens covered: no features, no flow
    let (mut before, mut after, mut ids) = (0, 0, std::collections::BTreeSet::new());
    for f in 0..130 {
        let img = if (50..56).contains(&f) { blank.clone() } else { room.render(&k, &trajectory(f % 100)) };
        if let Some(vp) = vo.track(f as f64 / 30.0, &img, &k) {
            ids.insert(vp.map_id);
            if f < 50 { before += 1 } else { after += 1 }
        }
    }
    eprintln!("blackout: before {before}, after {after}, map ids {ids:?}");
    assert!(before >= 30, "should track before the blackout");
    assert!(ids.len() >= 2, "a lost map must be abandoned with a new map_id: {ids:?}");
    assert!(after >= 25, "must re-initialise and keep tracking afterwards (got {after})");
}
