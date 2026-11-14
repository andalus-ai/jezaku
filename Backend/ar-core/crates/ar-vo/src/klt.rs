//! Pyramidal Lucas-Kanade tracking with a forward-backward consistency check.
//!
//! Performance notes: every pixel of a window shares the same fractional offset, so bilinear weights are
//! computed once per window and applied to integer-grid loads; the backward check only refines at full
//! resolution starting from the forward result.
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

/// Fill `buf` with bilinear samples of `img` at (cx+dx, cy+dy) for dx,dy in -r..=r (row-major).
fn window(img: &Gray, cx: f64, cy: f64, r: i32, buf: &mut Vec<f32>) {
    let n = (2 * r + 1) as usize;
    buf.clear();
    let (fx0, fy0) = (cx.floor(), cy.floor());
    let (fx, fy) = ((cx - fx0) as f32, (cy - fy0) as f32);
    let (x0, y0) = (fx0 as isize - r as isize, fy0 as isize - r as isize);
    let (w00, w10, w01, w11) = ((1.0 - fx) * (1.0 - fy), fx * (1.0 - fy), (1.0 - fx) * fy, fx * fy);
    let interior = x0 >= 0 && y0 >= 0 && x0 + n as isize <= img.w as isize - 1 && y0 + n as isize <= img.h as isize - 1;
    if interior {
        let (x0, y0, w) = (x0 as usize, y0 as usize, img.w);
        for j in 0..n {
            let row0 = &img.d[(y0 + j) * w + x0..(y0 + j) * w + x0 + n + 1];
            let row1 = &img.d[(y0 + j + 1) * w + x0..(y0 + j + 1) * w + x0 + n + 1];
            for i in 0..n { buf.push(w00 * row0[i] + w10 * row0[i + 1] + w01 * row1[i] + w11 * row1[i + 1]); }
        }
    } else {
        for j in 0..n as isize {
            for i in 0..n as isize {
                let (x, y) = (x0 + i, y0 + j);
                buf.push(w00 * img.px(x, y) + w10 * img.px(x + 1, y) + w01 * img.px(x, y + 1) + w11 * img.px(x + 1, y + 1));
            }
        }
    }
}

struct Scratch { tpl: Vec<f32>, cur: Vec<f32>, ix: Vec<f32>, iy: Vec<f32> }

/// Refine `d` (flow at this level) for one pyramid level. Returns the updated flow, or None if degenerate.
fn lk_level(a: &Gray, b: &Gray, u: Vector2<f64>, d0: Vector2<f64>, p: &KltParams, sc: &mut Scratch, need_eig: bool) -> Option<Vector2<f64>> {
    let hw = p.half_win;
    let n = (2 * hw + 1) as usize;
    // Template window with a 1-pixel margin for central-difference gradients.
    window(a, u.x, u.y, hw + 1, &mut sc.tpl);
    let m = n + 2;
    sc.ix.clear(); sc.iy.clear();
    let mut g = Matrix2::zeros();
    let mut tpl_c = Vec::with_capacity(n * n);
    for j in 1..=n {
        for i in 1..=n {
            let ix = 0.5 * (sc.tpl[j * m + i + 1] - sc.tpl[j * m + i - 1]);
            let iy = 0.5 * (sc.tpl[(j + 1) * m + i] - sc.tpl[(j - 1) * m + i]);
            sc.ix.push(ix); sc.iy.push(iy); tpl_c.push(sc.tpl[j * m + i]);
            g += Matrix2::new((ix * ix) as f64, (ix * iy) as f64, (ix * iy) as f64, (iy * iy) as f64);
        }
    }
    if need_eig {
        let (tr, det) = (g.trace(), g.determinant());
        let min_eig = 0.5 * (tr - (tr * tr - 4.0 * det).max(0.0).sqrt()) / ((n * n) as f64);
        if min_eig < p.min_eig { return None; }
    }
    let ginv = g.try_inverse()?;
    let mut d = d0;
    for _ in 0..p.max_iter {
        window(b, u.x + d.x, u.y + d.y, hw, &mut sc.cur);
        let (mut bx, mut by) = (0f32, 0f32);
        for k in 0..n * n {
            let e = tpl_c[k] - sc.cur[k];
            bx += e * sc.ix[k];
            by += e * sc.iy[k];
        }
        let delta = ginv * Vector2::new(bx as f64, by as f64);
        d += delta;
        if !d.x.is_finite() || !d.y.is_finite() || d.norm() > 64.0 * (u.norm().max(1.0)) { return None; }
        if delta.norm() < p.eps { break; }
    }
    Some(d)
}

fn in_bounds(img: &Gray, u: Vector2<f64>, margin: f64) -> bool {
    u.x >= margin && u.y >= margin && u.x <= img.w as f64 - 1.0 - margin && u.y <= img.h as f64 - 1.0 - margin
}

/// Full pyramidal track of `pt` from `prev` to `next`.
fn track_pyramid(prev: &Pyramid, next: &Pyramid, pt: Vector2<f64>, p: &KltParams, sc: &mut Scratch) -> Option<Vector2<f64>> {
    let n = prev.levels.len().min(next.levels.len());
    let mut g = Vector2::zeros();
    for lvl in (0..n).rev() {
        let u = pt / (1u32 << lvl) as f64;
        let (a, b) = (&prev.levels[lvl], &next.levels[lvl]);
        if !in_bounds(a, u, 1.0) { if lvl == 0 { return None; } g *= 2.0; continue; }
        match lk_level(a, b, u, g, p, sc, lvl == 0) {
            Some(d) => g = if lvl > 0 { d * 2.0 } else { d },
            None if lvl > 0 => g *= 2.0,
            None => return None,
        }
    }
    let out = pt + g;
    in_bounds(&next.levels[0], out, 2.0).then_some(out)
}

/// Track `pts` from `prev` to `next`. Failed / inconsistent points are `None`.
pub fn track(prev: &Pyramid, next: &Pyramid, pts: &[Vector2<f64>], p: &KltParams) -> Vec<Option<Vector2<f64>>> {
    let mut sc = Scratch { tpl: vec![], cur: vec![], ix: vec![], iy: vec![] };
    pts.iter().map(|&pt| {
        let fwd = track_pyramid(prev, next, pt, p, &mut sc)?;
        // Backward check: start from the forward result and refine at full resolution only.
        if !in_bounds(&next.levels[0], fwd, 1.0) { return None; }
        let back = fwd + lk_level(&next.levels[0], &prev.levels[0], fwd, pt - fwd, p, &mut sc, false)?;
        // lk_level returns flow d such that prev(fwd + d) ~ next(fwd); `back` is where fwd lands in prev.
        ((back - pt).norm() <= p.fb_thresh).then_some(fwd)
    }).collect()
}
