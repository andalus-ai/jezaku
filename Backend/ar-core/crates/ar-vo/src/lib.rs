//! Monocular visual odometry frontend (pure Rust).
pub mod detect;
pub mod geom;
pub mod image;
pub mod klt;
pub mod synth;
pub mod vo;

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
}
