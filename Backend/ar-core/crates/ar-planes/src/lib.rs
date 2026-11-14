//! Sequential-RANSAC plane detection over a sparse point cloud (ARCore "plane finding").
use nalgebra::{Point3, Vector3};

#[derive(Debug, Clone)]
pub struct Plane {
    pub normal: Vector3<f64>, // unit, oriented so n.z >= 0 when near-horizontal
    pub d: f64,               // n . p + d = 0
    pub inliers: Vec<usize>,
    pub horizontal: bool,
    /// Inlier centroid and in-plane orthonormal basis (u, v), with inlier extents along each.
    pub center: Vector3<f64>,
    pub u: Vector3<f64>,
    pub v: Vector3<f64>,
    pub u_range: [f64; 2],
    pub v_range: [f64; 2],
}

impl Plane {
    /// Ray/plane hit restricted to the observed patch (inlier bounds + `margin` metres).
    /// Returns the ray parameter t > 0 (distance, if `dir` is unit).
    pub fn intersect(&self, origin: &Vector3<f64>, dir: &Vector3<f64>, margin: f64) -> Option<f64> {
        let denom = self.normal.dot(dir);
        if denom.abs() < 1e-9 { return None; }
        let t = -(self.normal.dot(origin) + self.d) / denom;
        if t <= 0.0 { return None; }
        let rel = origin + dir * t - self.center;
        let (a, b) = (rel.dot(&self.u), rel.dot(&self.v));
        let inside = a >= self.u_range[0] - margin && a <= self.u_range[1] + margin
            && b >= self.v_range[0] - margin && b <= self.v_range[1] + margin;
        inside.then_some(t)
    }
    pub fn extent(&self) -> [f64; 2] { [self.u_range[1] - self.u_range[0], self.v_range[1] - self.v_range[0]] }
}

#[derive(Debug, Clone, Copy)]
pub struct Params {
    pub iterations: usize,
    pub dist_thresh: f64,
    pub min_inliers: usize,
    pub max_planes: usize,
    /// |n.z| above this => horizontal (floor/table), requires z-up (ENU) input.
    pub horizontal_cos: f64,
}
impl Default for Params {
    fn default() -> Self { Self { iterations: 200, dist_thresh: 0.02, min_inliers: 30, max_planes: 6, horizontal_cos: 0.9 } }
}

struct XorShift(u64);
impl XorShift {
    fn next(&mut self) -> u64 { self.0 ^= self.0 << 13; self.0 ^= self.0 >> 7; self.0 ^= self.0 << 17; self.0 }
    fn below(&mut self, n: usize) -> usize { (self.next() % n as u64) as usize }
}

fn fit3(a: &Point3<f64>, b: &Point3<f64>, c: &Point3<f64>) -> Option<(Vector3<f64>, f64)> {
    let n = (b - a).cross(&(c - a));
    let len = n.norm();
    if len < 1e-9 { return None; }
    let n = n / len;
    Some((n, -n.dot(&a.coords)))
}

pub fn detect(points: &[Point3<f64>], prm: &Params, seed: u64) -> Vec<Plane> {
    let mut rng = XorShift(seed | 1);
    let mut remaining: Vec<usize> = (0..points.len()).collect();
    let mut out = vec![];
    while out.len() < prm.max_planes && remaining.len() >= prm.min_inliers.max(3) {
        let mut best: Option<(Vector3<f64>, f64, usize)> = None;
        for _ in 0..prm.iterations {
            let (i, j, k) = (rng.below(remaining.len()), rng.below(remaining.len()), rng.below(remaining.len()));
            if i == j || j == k || i == k { continue; }
            let Some((n, d)) = fit3(&points[remaining[i]], &points[remaining[j]], &points[remaining[k]]) else { continue };
            let cnt = remaining.iter().filter(|&&ix| (n.dot(&points[ix].coords) + d).abs() < prm.dist_thresh).count();
            if best.map_or(true, |b| cnt > b.2) { best = Some((n, d, cnt)); }
        }
        let Some((mut n, mut d, cnt)) = best else { break };
        if cnt < prm.min_inliers { break; }
        // Least-squares refit on inliers (centroid + smallest eigenvector of covariance).
        let inl: Vec<usize> = remaining.iter().copied().filter(|&ix| (n.dot(&points[ix].coords) + d).abs() < prm.dist_thresh).collect();
        let c = inl.iter().map(|&i| points[i].coords).sum::<Vector3<f64>>() / inl.len() as f64;
        let cov = inl.iter().fold(nalgebra::Matrix3::zeros(), |m, &i| { let v = points[i].coords - c; m + v * v.transpose() });
        let eig = cov.symmetric_eigen();
        let min_i = eig.eigenvalues.imin();
        n = eig.eigenvectors.column(min_i).into_owned().normalize();
        if n.z < 0.0 { n = -n; }
        d = -n.dot(&c);
        let inliers: Vec<usize> = remaining.iter().copied().filter(|&ix| (n.dot(&points[ix].coords) + d).abs() < prm.dist_thresh).collect();
        remaining.retain(|ix| !inliers.contains(ix));
        let helper = if n.x.abs() < 0.9 { Vector3::x() } else { Vector3::y() };
        let u = n.cross(&helper).normalize();
        let v = n.cross(&u);
        let (mut ur, mut vr) = ([f64::MAX, f64::MIN], [f64::MAX, f64::MIN]);
        let center = inliers.iter().map(|&i| points[i].coords).sum::<Vector3<f64>>() / inliers.len() as f64;
        for &i in &inliers {
            let rel = points[i].coords - center;
            let (a, b) = (rel.dot(&u), rel.dot(&v));
            ur = [ur[0].min(a), ur[1].max(a)];
            vr = [vr[0].min(b), vr[1].max(b)];
        }
        out.push(Plane { normal: n, d, horizontal: n.z.abs() > prm.horizontal_cos, inliers, center, u, v, u_range: ur, v_range: vr });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn finds_floor_and_wall() {
        let mut pts = vec![];
        for i in 0..20 { for j in 0..20 { pts.push(Point3::new(i as f64 * 0.1, j as f64 * 0.1, 0.002 * ((i * j) % 3) as f64)); } } // floor
        for i in 0..15 { for j in 0..15 { pts.push(Point3::new(0.0, i as f64 * 0.1, j as f64 * 0.1 + 0.1)); } } // wall x=0
        for k in 0..20 { pts.push(Point3::new(3.0 + k as f64, 7.0 - k as f64 * 0.3, 2.0 + (k * k % 5) as f64)); } // outliers
        let planes = detect(&pts, &Params::default(), 42);
        assert!(planes.len() >= 2);
        assert!(planes.iter().any(|p| p.horizontal && p.inliers.len() > 350));
        assert!(planes.iter().any(|p| !p.horizontal && p.normal.x.abs() > 0.95));
    }

    #[test]
    fn ray_hits_only_inside_patch() {
        let pts: Vec<_> = (0..20).flat_map(|i| (0..20).map(move |j| Point3::new(i as f64 * 0.1, j as f64 * 0.1, 0.0))).collect();
        let pl = &detect(&pts, &Params::default(), 7)[0];
        let down = Vector3::new(0.0, 0.0, -1.0);
        let t = pl.intersect(&Vector3::new(1.0, 1.0, 2.0), &down, 0.05).unwrap();
        assert!((t - 2.0).abs() < 1e-6);
        assert!(pl.intersect(&Vector3::new(5.0, 5.0, 2.0), &down, 0.05).is_none(), "outside observed patch");
        assert!(pl.intersect(&Vector3::new(1.0, 1.0, 2.0), &Vector3::new(0.0, 0.0, 1.0), 0.05).is_none(), "behind ray");
    }
}
