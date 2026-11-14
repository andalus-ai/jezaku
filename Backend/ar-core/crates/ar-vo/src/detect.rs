//! Shi-Tomasi corner detection with grid bucketing and minimum-distance suppression.
use crate::image::Gray;
use nalgebra::Vector2;

#[derive(Debug, Clone, Copy)]
pub struct DetectParams {
    pub cell: usize,
    pub per_cell: usize,
    pub min_dist: f64,
    /// Fraction of the strongest response a corner must reach.
    pub quality: f32,
    pub margin: usize,
}
impl Default for DetectParams {
    fn default() -> Self { Self { cell: 32, per_cell: 6, min_dist: 9.0, quality: 0.02, margin: 12 } }
}

/// Up to `max_new` corners that are at least `min_dist` from `occupied` and from each other.
pub fn detect(img: &Gray, occupied: &[Vector2<f64>], max_new: usize, p: &DetectParams) -> Vec<Vector2<f64>> {
    let (w, h) = (img.w, img.h);
    if w < 2 * p.margin + 8 || h < 2 * p.margin + 8 || max_new == 0 { return vec![]; }
    let mut gx = vec![0f32; w * h];
    let mut gy = vec![0f32; w * h];
    for y in 1..h - 1 {
        for x in 1..w - 1 {
            gx[y * w + x] = 0.5 * (img.d[y * w + x + 1] - img.d[y * w + x - 1]);
            gy[y * w + x] = 0.5 * (img.d[(y + 1) * w + x] - img.d[(y - 1) * w + x]);
        }
    }
    let r = 2usize; // 5x5 window
    let mut resp = vec![0f32; w * h];
    let mut rmax = 0f32;
    for y in p.margin..h - p.margin {
        for x in p.margin..w - p.margin {
            let (mut a, mut b, mut c) = (0f32, 0f32, 0f32);
            for yy in y - r..=y + r {
                for xx in x - r..=x + r {
                    let (ix, iy) = (gx[yy * w + xx], gy[yy * w + xx]);
                    a += ix * ix; b += ix * iy; c += iy * iy;
                }
            }
            let m = 0.5 * ((a + c) - ((a - c) * (a - c) + 4.0 * b * b).sqrt());
            resp[y * w + x] = m;
            rmax = rmax.max(m);
        }
    }
    if rmax <= 0.0 { return vec![]; }
    let thr = rmax * p.quality;
    let mut cands: Vec<(f32, usize, usize)> = vec![];
    for y in p.margin..h - p.margin {
        for x in p.margin..w - p.margin {
            let v = resp[y * w + x];
            if v < thr { continue; }
            let mut is_max = true;
            'n: for dy in -1i32..=1 {
                for dx in -1i32..=1 {
                    if (dx, dy) != (0, 0) && resp[((y as i32 + dy) as usize) * w + (x as i32 + dx) as usize] > v { is_max = false; break 'n; }
                }
            }
            if is_max { cands.push((v, x, y)); }
        }
    }
    cands.sort_by(|a, b| b.0.total_cmp(&a.0));

    let md = p.min_dist;
    let gw = (w as f64 / md).ceil() as usize + 1;
    let gh = (h as f64 / md).ceil() as usize + 1;
    let mut grid: Vec<Vec<Vector2<f64>>> = vec![vec![]; gw * gh];
    let put = |grid: &mut Vec<Vec<Vector2<f64>>>, q: Vector2<f64>| grid[((q.y / md) as usize) * gw + (q.x / md) as usize].push(q);
    for q in occupied { if q.x >= 0.0 && q.y >= 0.0 && (q.x / md) < gw as f64 && (q.y / md) < gh as f64 { put(&mut grid, *q); } }
    let cw = (w + p.cell - 1) / p.cell;
    let mut per_cell = vec![0usize; cw * ((h + p.cell - 1) / p.cell)];
    let mut out = vec![];
    for (_, x, y) in cands {
        if out.len() >= max_new { break; }
        let cell = (y / p.cell) * cw + x / p.cell;
        if per_cell[cell] >= p.per_cell { continue; }
        let q = Vector2::new(x as f64, y as f64);
        let (cx, cy) = ((q.x / md) as usize, (q.y / md) as usize);
        let mut ok = true;
        'g: for gy_ in cy.saturating_sub(1)..=(cy + 1).min(gh - 1) {
            for gx_ in cx.saturating_sub(1)..=(cx + 1).min(gw - 1) {
                if grid[gy_ * gw + gx_].iter().any(|o| (o - q).norm() < md) { ok = false; break 'g; }
            }
        }
        if !ok { continue; }
        put(&mut grid, q);
        per_cell[cell] += 1;
        out.push(q);
    }
    out
}
