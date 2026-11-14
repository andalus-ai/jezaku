//! Grayscale float images and pyramids.
#[derive(Clone)]
pub struct Gray {
    pub w: usize,
    pub h: usize,
    pub d: Vec<f32>,
}

impl Gray {
    pub fn from_u8(w: usize, h: usize, data: &[u8]) -> Option<Self> {
        (w > 0 && h > 0 && data.len() == w * h).then(|| Self { w, h, d: data.iter().map(|&b| b as f32).collect() })
    }

    #[inline]
    pub fn px(&self, x: isize, y: isize) -> f32 {
        let xi = x.clamp(0, self.w as isize - 1) as usize;
        let yi = y.clamp(0, self.h as isize - 1) as usize;
        self.d[yi * self.w + xi]
    }

    /// Bilinear sample with clamped borders.
    #[inline]
    pub fn sample(&self, x: f64, y: f64) -> f32 {
        let (x0, y0) = (x.floor(), y.floor());
        let (fx, fy) = ((x - x0) as f32, (y - y0) as f32);
        let (xi, yi) = (x0 as isize, y0 as isize);
        let a = self.px(xi, yi) * (1.0 - fx) + self.px(xi + 1, yi) * fx;
        let b = self.px(xi, yi + 1) * (1.0 - fx) + self.px(xi + 1, yi + 1) * fx;
        a * (1.0 - fy) + b * fy
    }

    /// 2x2 box downsample.
    pub fn half(&self) -> Gray {
        let (w, h) = ((self.w / 2).max(1), (self.h / 2).max(1));
        let mut d = Vec::with_capacity(w * h);
        for y in 0..h {
            for x in 0..w {
                let (sx, sy) = ((2 * x) as isize, (2 * y) as isize);
                d.push(0.25 * (self.px(sx, sy) + self.px(sx + 1, sy) + self.px(sx, sy + 1) + self.px(sx + 1, sy + 1)));
            }
        }
        Gray { w, h, d }
    }
}

pub struct Pyramid {
    pub levels: Vec<Gray>,
}

impl Pyramid {
    pub fn build(base: Gray, n: usize) -> Self {
        let mut levels = vec![base];
        for _ in 1..n.max(1) {
            let next = levels.last().unwrap().half();
            if next.w < 16 || next.h < 16 { break; }
            levels.push(next);
        }
        Self { levels }
    }
}
