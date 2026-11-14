//! Lens distortion (OpenCV radial-tangential "plumb bob") and image undistortion.
use ar_core::Intrinsics;

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct Distortion { pub k1: f64, pub k2: f64, pub p1: f64, pub p2: f64, pub k3: f64 }

impl Distortion {
    pub fn new(k1: f64, k2: f64, p1: f64, p2: f64) -> Self { Self { k1, k2, p1, p2, k3: 0.0 } }
    pub fn is_zero(&self) -> bool { *self == Self::default() }

    /// Ideal normalised coordinates -> distorted normalised coordinates.
    pub fn distort(&self, x: f64, y: f64) -> (f64, f64) {
        let (r2, xy) = (x * x + y * y, x * y);
        let radial = 1.0 + r2 * (self.k1 + r2 * (self.k2 + r2 * self.k3));
        (x * radial + 2.0 * self.p1 * xy + self.p2 * (r2 + 2.0 * x * x),
         y * radial + self.p1 * (r2 + 2.0 * y * y) + 2.0 * self.p2 * xy)
    }

    /// Distorted -> ideal normalised coordinates (fixed-point iteration, as in OpenCV's undistortPoints).
    pub fn undistort(&self, xd: f64, yd: f64) -> (f64, f64) {
        let (mut x, mut y) = (xd, yd);
        for _ in 0..30 {
            let (r2, xy) = (x * x + y * y, x * y);
            let inv = 1.0 / (1.0 + r2 * (self.k1 + r2 * (self.k2 + r2 * self.k3)));
            let dx = 2.0 * self.p1 * xy + self.p2 * (r2 + 2.0 * x * x);
            let dy = self.p1 * (r2 + 2.0 * y * y) + 2.0 * self.p2 * xy;
            let (nx, ny) = ((xd - dx) * inv, (yd - dy) * inv);
            if (nx - x).abs() < 1e-12 && (ny - y).abs() < 1e-12 { return (nx, ny); }
            x = nx; y = ny;
        }
        (x, y)
    }
}

/// Precomputed remap producing a pinhole image with the *same* intrinsics as the input camera.
pub struct Undistorter { w: usize, h: usize, map: Vec<(f32, f32)> }

impl Undistorter {
    pub fn new(k: &Intrinsics, d: &Distortion) -> Self {
        let (w, h) = (k.width as usize, k.height as usize);
        let mut map = Vec::with_capacity(w * h);
        for v in 0..h {
            for u in 0..w {
                let (x, y) = ((u as f64 - k.cx) / k.fx, (v as f64 - k.cy) / k.fy);
                let (xd, yd) = d.distort(x, y);
                map.push(((k.fx * xd + k.cx) as f32, (k.fy * yd + k.cy) as f32));
            }
        }
        Self { w, h, map }
    }

    /// Bilinear remap; samples outside the source are clamped to the border (no artificial edges).
    pub fn apply(&self, src: &[u8]) -> Vec<u8> {
        assert_eq!(src.len(), self.w * self.h, "frame size must match the calibration");
        let at = |x: isize, y: isize| src[(y.clamp(0, self.h as isize - 1) as usize) * self.w + x.clamp(0, self.w as isize - 1) as usize] as f32;
        self.map.iter().map(|&(sx, sy)| {
            let (x0, y0) = (sx.floor(), sy.floor());
            let (fx, fy) = (sx - x0, sy - y0);
            let (xi, yi) = (x0 as isize, y0 as isize);
            let a = at(xi, yi) * (1.0 - fx) + at(xi + 1, yi) * fx;
            let b = at(xi, yi + 1) * (1.0 - fx) + at(xi + 1, yi + 1) * fx;
            (a * (1.0 - fy) + b * fy + 0.5) as u8
        }).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn distort_undistort_roundtrip_with_euroc_like_coefficients() {
        let d = Distortion { k1: -0.28340811, k2: 0.07395907, p1: 0.00019359, p2: 1.76187114e-05, k3: 0.0 };
        for &(x, y) in &[(0.0, 0.0), (0.4, -0.3), (-0.8, 0.5), (0.8, 0.5)] {
            let (xd, yd) = d.distort(x, y);
            let (xu, yu) = d.undistort(xd, yd);
            assert!((xu - x).abs() < 1e-9 && (yu - y).abs() < 1e-9, "({x},{y}) -> ({xu},{yu})");
        }
    }
}
