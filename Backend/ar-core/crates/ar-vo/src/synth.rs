//! Deterministic synthetic scenes for tests: procedural textures rendered by ray casting.
//! Public so other crates' tests can drive the frontend with ground truth.
use ar_core::Intrinsics;
use nalgebra::{Isometry3, Matrix3, Rotation3, Translation3, UnitQuaternion, Vector3};

fn hash(ix: i32, iy: i32, seed: u32) -> f64 {
    let mut h = (ix as u32).wrapping_mul(0x9E37_79B1) ^ (iy as u32).wrapping_mul(0x85EB_CA77) ^ seed.wrapping_mul(0xC2B2_AE3D);
    h ^= h >> 15; h = h.wrapping_mul(0x2C1B_3C6D); h ^= h >> 12; h = h.wrapping_mul(0x297A_2D39); h ^= h >> 15;
    (h & 0xFFFF) as f64 / 65535.0
}

fn value_noise(x: f64, y: f64, seed: u32) -> f64 {
    let (x0, y0) = (x.floor(), y.floor());
    let (fx, fy) = (x - x0, y - y0);
    let (sx, sy) = (fx * fx * (3.0 - 2.0 * fx), fy * fy * (3.0 - 2.0 * fy));
    let (i, j) = (x0 as i32, y0 as i32);
    let a = hash(i, j, seed) * (1.0 - sx) + hash(i + 1, j, seed) * sx;
    let b = hash(i, j + 1, seed) * (1.0 - sx) + hash(i + 1, j + 1, seed) * sx;
    a * (1.0 - sy) + b * sy
}

/// Multi-octave texture, roughly 0..255. Coordinates in metres.
pub fn texture(a: f64, b: f64, seed: u32) -> f64 {
    let mut v = 0.0;
    let mut amp = 0.5;
    let mut norm = 0.0;
    for (k, f) in [1.5, 3.5, 7.0, 14.0, 28.0].iter().enumerate() {
        v += amp * value_noise(a * f, b * f, seed.wrapping_add(k as u32 * 101));
        norm += amp;
        amp *= 0.75;
    }
    255.0 * (v / norm)
}

/// Pure-translation test image: texture sampled at (x+sx, y+sy) pixels.
pub fn flat(w: usize, h: usize, sx: f64, sy: f64) -> Vec<u8> {
    (0..w * h).map(|i| texture(((i % w) as f64 + sx) / 40.0, ((i / w) as f64 + sy) / 40.0, 7) as u8).collect()
}

/// Axis-aligned room in an ENU world (x east, y north, z up).
pub struct Room { pub half_x: f64, pub back_y: f64, pub height: f64 }
impl Default for Room { fn default() -> Self { Self { half_x: 3.0, back_y: 9.0, height: 3.0 } } }

impl Room {
    /// Render an 8-bit grayscale image seen by a camera with OpenCV axes (x right, y down, z forward).
    pub fn render(&self, k: &Intrinsics, t_wc: &Isometry3<f64>) -> Vec<u8> {
        let o = t_wc.translation.vector;
        let r = t_wc.rotation.to_rotation_matrix().into_inner();
        let mut out = vec![0u8; (k.width * k.height) as usize];
        for v in 0..k.height {
            for u in 0..k.width {
                let dc = Vector3::new((u as f64 - k.cx) / k.fx, (v as f64 - k.cy) / k.fy, 1.0);
                let d = r * dc;
                let mut best = (f64::MAX, 0u32, 0.0, 0.0);
                let mut hit = |t: f64, seed: u32, a: f64, b: f64| if t > 1e-6 && t < best.0 { best = (t, seed, a, b); };
                if d.z.abs() > 1e-12 {
                    for (z, seed) in [(0.0, 1u32), (self.height, 2)] { let t = (z - o.z) / d.z; let p = o + d * t; hit(t, seed, p.x, p.y); }
                }
                if d.x.abs() > 1e-12 {
                    for (x, seed) in [(-self.half_x, 3u32), (self.half_x, 4)] { let t = (x - o.x) / d.x; let p = o + d * t; hit(t, seed, p.y, p.z); }
                }
                if d.y.abs() > 1e-12 { let t = (self.back_y - o.y) / d.y; let p = o + d * t; hit(t, 5, p.x, p.z); }
                out[(v * k.width + u) as usize] = if best.0 < f64::MAX { texture(best.2, best.3, best.1) as u8 } else { 128 };
            }
        }
        out
    }
}

/// Camera (OpenCV axes) looking north (+y) in ENU: cam x = east, cam y = down, cam z = north.
pub fn look_north() -> Rotation3<f64> {
    Rotation3::from_matrix_unchecked(Matrix3::new(1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, 0.0))
}

/// Ground-truth camera pose for frame `k`: lateral swing, steady advance, gentle yaw.
pub fn trajectory(k: usize) -> Isometry3<f64> {
    let kf = k as f64;
    let p = Vector3::new(0.9 * (0.045 * kf).sin(), 0.04 * kf, 1.5 + 0.1 * (0.08 * kf).sin());
    let yaw = 0.15 * (0.03 * kf).sin();
    let r = UnitQuaternion::from_axis_angle(&Vector3::z_axis(), -yaw) * UnitQuaternion::from_rotation_matrix(&look_north());
    Isometry3::from_parts(Translation3::from(p), r)
}

pub fn default_intrinsics() -> Intrinsics { Intrinsics { fx: 300.0, fy: 300.0, cx: 160.0, cy: 120.0, width: 320, height: 240 } }
