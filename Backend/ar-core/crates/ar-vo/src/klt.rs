//! Pyramidal Lucas-Kanade tracking with a forward-backward consistency check.
use crate::image::{Gray, Pyramid};
use nalgebra::{Matrix2, Vector2};

#[derive(Debug, Clone, Copy)]
pub struct KltParams {
    pub half_win: i32,
    pub max_iter: usize,
    pub eps: f64,
    /// Minimum eigenvalue of the (per-pixel-normalised) gradient matrix.
    pub min_eig: f64,
    pub fb_thresh: f64,
}
impl Default for KltParams {
    fn default() -> Self { Self { half_win: 7, max_iter: 25, eps: 0.01, min_eig: 1.0, fb_thresh: 1.0 } }
}

fn track_one(prev: &Pyramid, next: &Pyramid, pt: Vector2<f64>, p: &KltParams) -> Option<Vector2<f64>> {
    let n = prev.levels.len().min(next.levels.len());
    let hw = p.half_win;
    let count = ((2 * hw + 1) * (2 * hw + 1)) as usize;
    let mut tpl: Vec<(f32, f32, f32)> = Vec::with_capacity(count);
    let mut g = Vector2::zeros();
    for lvl in (0..n).rev() {
        let (a, b): (&Gray, &Gray) = (&prev.levels[lvl], &next.levels[lvl]);
        let u = pt / (1u32 << lvl) as f64;
        if u.x < 1.0 || u.y < 1.0 || u.x > a.w as f64 - 2.0 || u.y > a.h as f64 - 2.0 { if lvl == 0 { return None; } g *= 2.0; continue; }
        tpl.clear();
        let mut m = Matrix2::zeros();
        for dy in -hw..=hw {
            for dx in -hw..=hw {
                let (x, y) = (u.x + dx as f64, u.y + dy as f64);
                let i = a.sample(x, y);
                let ix = 0.5 * (a.sample(x + 1.0, y) - a.sample(x - 1.0, y));
                let iy = 0.5 * (a.sample(x, y + 1.0) - a.sample(x, y - 1.0));
                tpl.push((i, ix, iy));
                m += Matrix2::new((ix * ix) as f64, (ix * iy) as f64, (ix * iy) as f64, (iy * iy) as f64);
            }
        }
        let tr = m.trace();
        let det = m.determinant();
        let min_eig = 0.5 * (tr - (tr * tr - 4.0 * det).max(0.0).sqrt()) / count as f64;
        if lvl == 0 && min_eig < p.min_eig { return None; }
        let Some(minv) = m.try_inverse() else { if lvl == 0 { return None; } g *= 2.0; continue };
        let mut d = g;
        for _ in 0..p.max_iter {
            let mut bvec = Vector2::zeros();
            let mut k = 0;
            for dy in -hw..=hw {
                for dx in -hw..=hw {
                    let (i, ix, iy) = tpl[k];
                    k += 1;
                    let j = b.sample(u.x + dx as f64 + d.x, u.y + dy as f64 + d.y);
                    let e = (i - j) as f64;
                    bvec += Vector2::new(e * ix as f64, e * iy as f64);
                }
            }
            let delta = minv * bvec;
            d += delta;
            if !d.x.is_finite() || !d.y.is_finite() || d.norm() > 64.0 * (1u32 << lvl) as f64 { return None; }
            if delta.norm() < p.eps { break; }
        }
        g = if lvl > 0 { d * 2.0 } else { d };
    }
    let out = pt + g;
    let b0 = &next.levels[0];
    (out.x >= 2.0 && out.y >= 2.0 && out.x <= b0.w as f64 - 3.0 && out.y <= b0.h as f64 - 3.0).then_some(out)
}

/// Track `pts` from `prev` to `next`. Failed / inconsistent points are `None`.
pub fn track(prev: &Pyramid, next: &Pyramid, pts: &[Vector2<f64>], p: &KltParams) -> Vec<Option<Vector2<f64>>> {
    pts.iter().map(|&pt| {
        let fwd = track_one(prev, next, pt, p)?;
        let back = track_one(next, prev, fwd, p)?;
        ((back - pt).norm() <= p.fb_thresh).then_some(fwd)
    }).collect()
}
