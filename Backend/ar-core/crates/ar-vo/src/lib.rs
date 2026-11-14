//! Monocular visual odometry frontend (pure Rust).
pub mod detect;
pub mod geom;
pub mod image;
pub mod klt;
pub mod synth;
pub mod undistort;
pub mod vo;

pub use undistort::{Distortion, Undistorter};
pub use vo::{t_body_cam_android_back, VoConfig, VoFrontend};

#[cfg(test)]
mod tests {
    use super::*;
    use image::{Gray, Pyramid};
    use nalgebra::Vector2;

    fn pyr(data: &[u8], w: usize, h: usize) -> Pyramid { Pyramid::build(Gray::from_u8(w, h, data).unwrap(), 3) }

    #[test]
    fn klt_recovers_subpixel_shift_and_rejects_bad_points() {
        let (w, h) = (320, 240);
        let a = synth::flat(w, h, 0.0, 0.0);
        let b = synth::flat(w, h, -3.2, 1.7); // content moves by (+3.2, -1.7)
        let (pa, pb) = (pyr(&a, w, h), pyr(&b, w, h));
        let corners = detect::detect(&pa.levels[0], &[], 200, &detect::DetectParams::default());
        assert!(corners.len() > 60, "found {}", corners.len());
        let tracked = klt::track(&pa, &pb, &corners, &klt::KltParams::default());
        let (mut ok, mut worst) = (0, 0f64);
        for (c, t) in corners.iter().zip(&tracked) {
            if let Some(t) = t { ok += 1; worst = worst.max((t - c - Vector2::new(3.2, -1.7)).norm()); }
        }
        assert!(ok as f64 > 0.9 * corners.len() as f64, "{ok}/{}", corners.len());
        assert!(worst < 0.15, "worst subpixel error {worst}");
    }

    #[test]
    fn detector_respects_min_distance_and_occupied() {
        let img = Gray::from_u8(320, 240, &synth::flat(320, 240, 0.0, 0.0)).unwrap();
        let first = detect::detect(&img, &[], 100, &detect::DetectParams::default());
        let second = detect::detect(&img, &first, 100, &detect::DetectParams::default());
        for (i, a) in first.iter().enumerate() { for b in &first[i + 1..] { assert!((a - b).norm() >= 9.0); } }
        for a in &second { assert!(first.iter().all(|b| (a - b).norm() >= 9.0)); }
    }

    #[test]
    fn klt_forward_backward_check_rejects_corners_whose_content_vanished() {
        let (w, h) = (320usize, 240usize);
        let a = synth::flat(w, h, 0.0, 0.0);
        let mut b = synth::flat(w, h, -2.0, 1.0);
        // Replace a block with unrelated texture (as if something occluded the scene).
        let (bx0, by0, bs) = (120usize, 80usize, 80usize);
        for y in by0..by0 + bs { for x in bx0..bx0 + bs { b[y * w + x] = synth::texture(x as f64 / 9.0, y as f64 / 9.0, 4242) as u8; } }
        let (pa, pb) = (pyr(&a, w, h), pyr(&b, w, h));
        let corners = detect::detect(&pa.levels[0], &[], 300, &detect::DetectParams::default());
        let tracked = klt::track(&pa, &pb, &corners, &klt::KltParams::default());
        let inside = |c: &Vector2<f64>| c.x > (bx0 + 10) as f64 && c.x < (bx0 + bs - 10) as f64 && c.y > (by0 + 10) as f64 && c.y < (by0 + bs - 10) as f64;
        let far = |c: &Vector2<f64>| c.x < (bx0 - 20) as f64 || c.x > (bx0 + bs + 20) as f64 || c.y < (by0 - 20) as f64 || c.y > (by0 + bs + 20) as f64;
        let (mut n_in, mut kept_in, mut n_far, mut kept_far) = (0, 0, 0, 0);
        for (c, t) in corners.iter().zip(&tracked) {
            if inside(c) { n_in += 1; kept_in += t.is_some() as usize; }
            if far(c) { n_far += 1; kept_far += t.is_some() as usize; }
        }
        assert!(n_in >= 8 && n_far >= 50, "scene setup: {n_in} inside, {n_far} far");
        assert!(kept_in as f64 <= 0.25 * n_in as f64, "{kept_in}/{n_in} corners survived inside the replaced block");
        assert!(kept_far as f64 >= 0.9 * n_far as f64, "{kept_far}/{n_far} unaffected corners tracked");
    }
}
