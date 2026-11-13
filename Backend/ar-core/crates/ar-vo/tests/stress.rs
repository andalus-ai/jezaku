//! Harder-than-ideal conditions. Each scenario reports tracking coverage and scale-aligned ATE.
use ar_core::VisualFrontend;
use ar_fusion::align::umeyama;
use ar_vo::synth::{default_intrinsics, texture, trajectory_at, trajectory_fast_pan, Room};
use ar_vo::{VoConfig, VoFrontend};
use nalgebra::Isometry3;

struct Outcome { poses: usize, frames: usize, maps: usize, ate_pct: f64 }

fn run(frames: usize, mut render: impl FnMut(usize) -> Vec<u8>, truth: impl Fn(f64) -> Isometry3<f64>) -> Outcome {
    let k = default_intrinsics();
    let mut vo = VoFrontend::new(VoConfig::default());
    let (mut est, mut gt, mut ids) = (vec![], vec![], std::collections::BTreeSet::new());
    for f in 0..frames {
        if let Some(vp) = vo.track(f as f64 / 30.0, &render(f), &k) {
            ids.insert(vp.map_id);
            est.push(vp.t_map_cam.translation.vector);
            gt.push(truth(f as f64).translation.vector);
        }
    }
    let (ate_pct, poses) = if est.len() >= 10 {
        let sim = umeyama(&est, &gt, true).unwrap();
        let path: f64 = gt.windows(2).map(|w| (w[1] - w[0]).norm()).sum();
        let rmse = (est.iter().zip(&gt).map(|(e, g)| (sim.apply(e) - g).norm_squared()).sum::<f64>() / est.len() as f64).sqrt();
        (100.0 * rmse / path, est.len())
    } else { (f64::NAN, est.len()) };
    Outcome { poses, frames, maps: ids.len(), ate_pct }
}

/// A textured rectangle sliding across the image, as a person walking through the scene would.
fn add_moving_object(img: &mut [u8], f: usize, w: usize) {
    let (size, x0, y0) = (70usize, (f * 4) % (w + size_const()) as usize, 90usize);
    for dy in 0..size {
        for dx in 0..size {
            let x = x0 as isize + dx as isize - size as isize;
            if x < 0 || x >= w as isize { continue; }
            img[(y0 + dy) * w + x as usize] = texture(dx as f64 / 12.0, dy as f64 / 12.0, 99) as u8;
        }
    }
}
fn size_const() -> usize { 70 }

#[test]
fn moving_object_in_view() {
    let (room, k) = (Room::default(), default_intrinsics());
    let o = run(110, |f| { let mut i = room.render(&k, &trajectory_at(f as f64)); add_moving_object(&mut i, f, 320); i }, trajectory_at);
    eprintln!("moving object: poses {}/{} maps {} ATE {:.2}%", o.poses, o.frames, o.maps, o.ate_pct);
    assert!(o.poses as f64 >= 0.85 * o.frames as f64 && o.maps == 1, "poses {}/{} maps {}", o.poses, o.frames, o.maps);
    assert!(o.ate_pct < 4.0, "ATE {:.2}%", o.ate_pct);
}

#[test]
fn fast_pan() {
    let (room, k) = (Room::default(), default_intrinsics());
    let o = run(110, |f| room.render(&k, &trajectory_fast_pan(f as f64)), trajectory_fast_pan);
    eprintln!("fast pan: poses {}/{} maps {} ATE {:.2}%", o.poses, o.frames, o.maps, o.ate_pct);
    assert!(o.poses as f64 >= 0.8 * o.frames as f64 && o.maps == 1, "poses {}/{} maps {}", o.poses, o.frames, o.maps);
    assert!(o.ate_pct < 5.0, "ATE {:.2}%", o.ate_pct);
}

#[test]
fn motion_blur() {
    let (room, k) = (Room::default(), default_intrinsics());
    // Exposure covers +-0.45 frame of motion on top of the fast pan: average of 4 sub-frame renders.
    let blur = |f: usize| {
        let subs: Vec<Vec<u8>> = [-0.45, -0.15, 0.15, 0.45].iter().map(|d| room.render(&k, &trajectory_fast_pan(f as f64 + d))).collect();
        (0..subs[0].len()).map(|i| (subs.iter().map(|s| s[i] as u32).sum::<u32>() / 4) as u8).collect::<Vec<u8>>()
    };
    let o = run(110, blur, trajectory_fast_pan);
    eprintln!("motion blur: poses {}/{} maps {} ATE {:.2}%", o.poses, o.frames, o.maps, o.ate_pct);
    assert!(o.poses as f64 >= 0.8 * o.frames as f64 && o.maps == 1, "poses {}/{} maps {}", o.poses, o.frames, o.maps);
    assert!(o.ate_pct < 6.0, "ATE {:.2}%", o.ate_pct);
}
