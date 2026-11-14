//! Two-view and PnP geometry on normalised image coordinates (pixel / focal, origin at principal point).
//! Pose convention: `T_cw` maps world -> camera, X_c = R X_w + t.
use nalgebra::{Isometry3, Matrix2x3, Matrix3, Matrix3x4, Matrix4, SMatrix, SVector, Translation3, UnitQuaternion, Vector2, Vector3};

pub type V2 = Vector2<f64>;

pub struct Rng(u64);
impl Rng {
    pub fn new(seed: u64) -> Self { Self(seed | 1) }
    pub fn next(&mut self) -> u64 { self.0 ^= self.0 << 13; self.0 ^= self.0 >> 7; self.0 ^= self.0 << 17; self.0 }
    pub fn below(&mut self, n: usize) -> usize { (self.next() % n as u64) as usize }
    fn distinct(&mut self, n: usize, k: usize) -> Vec<usize> {
        let mut v: Vec<usize> = Vec::with_capacity(k);
        while v.len() < k { let i = self.below(n); if !v.contains(&i) { v.push(i); } }
        v
    }
}

pub fn p_matrix(t_cw: &Isometry3<f64>) -> Matrix3x4<f64> {
    t_cw.to_homogeneous().fixed_view::<3, 4>(0, 0).into_owned()
}

// ---------------------------------------------------------------- essential matrix

fn essential_from(x1: &[V2], x2: &[V2], idx: &[usize]) -> Option<Matrix3<f64>> {
    if idx.len() < 8 { return None; }
    let mut ata = SMatrix::<f64, 9, 9>::zeros();
    for &i in idx {
        let (a, b) = (x1[i], x2[i]);
        let r = SVector::<f64, 9>::from_row_slice(&[b.x * a.x, b.x * a.y, b.x, b.y * a.x, b.y * a.y, b.y, a.x, a.y, 1.0]);
        ata += r * r.transpose();
    }
    let eig = ata.symmetric_eigen();
    let v = eig.eigenvectors.column(eig.eigenvalues.imin());
    let e = Matrix3::new(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8]);
    let svd = e.svd(true, true);
    let (u, vt) = (svd.u?, svd.v_t?);
    let s = 0.5 * (svd.singular_values[0] + svd.singular_values[1]);
    Some(u * Matrix3::from_diagonal(&Vector3::new(s, s, 0.0)) * vt)
}

/// Squared Sampson distance (normalised units^2).
pub fn sampson(e: &Matrix3<f64>, a: V2, b: V2) -> f64 {
    let (xa, xb) = (Vector3::new(a.x, a.y, 1.0), Vector3::new(b.x, b.y, 1.0));
    let ex = e * xa;
    let etx = e.transpose() * xb;
    let num = xb.dot(&ex).powi(2);
    let den = ex.x * ex.x + ex.y * ex.y + etx.x * etx.x + etx.y * etx.y;
    if den < 1e-18 { f64::MAX } else { num / den }
}

/// 8-point RANSAC. `thresh` is in normalised units (pixels / focal length).
pub fn essential_ransac(x1: &[V2], x2: &[V2], thresh: f64, iters: usize, rng: &mut Rng) -> Option<(Matrix3<f64>, Vec<bool>)> {
    let n = x1.len();
    if n < 12 || n != x2.len() { return None; }
    let t2 = thresh * thresh;
    let score = |e: &Matrix3<f64>| (0..n).filter(|&i| sampson(e, x1[i], x2[i]) < t2).count();
    let mut best: Option<(Matrix3<f64>, usize)> = None;
    for _ in 0..iters {
        let idx = rng.distinct(n, 8);
        let Some(e) = essential_from(x1, x2, &idx) else { continue };
        let s = score(&e);
        if best.as_ref().map_or(true, |b| s > b.1) { best = Some((e, s)); }
    }
    let (mut e, _) = best?;
    for _ in 0..2 {
        let inl: Vec<usize> = (0..n).filter(|&i| sampson(&e, x1[i], x2[i]) < t2).collect();
        if let Some(e2) = essential_from(x1, x2, &inl) { e = e2; }
    }
    let mask: Vec<bool> = (0..n).map(|i| sampson(&e, x1[i], x2[i]) < t2).collect();
    (mask.iter().filter(|&&m| m).count() >= 12).then_some((e, mask))
}

pub fn decompose_essential(e: &Matrix3<f64>) -> Option<[(Matrix3<f64>, Vector3<f64>); 4]> {
    let svd = e.svd(true, true);
    let (mut u, mut vt) = (svd.u?, svd.v_t?);
    if u.determinant() < 0.0 { u.column_mut(2).neg_mut(); }
    if vt.determinant() < 0.0 { vt.row_mut(2).neg_mut(); }
    let w = Matrix3::new(0.0, -1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0);
    let (r1, r2) = (u * w * vt, u * w.transpose() * vt);
    let t = u.column(2).into_owned();
    Some([(r1, t), (r1, -t), (r2, t), (r2, -t)])
}

/// Linear (DLT) two-view triangulation with world->camera projection matrices.
pub fn triangulate(p1: &Matrix3x4<f64>, p2: &Matrix3x4<f64>, a: V2, b: V2) -> Option<Vector3<f64>> {
    let m = Matrix4::from_rows(&[
        a.x * p1.row(2) - p1.row(0),
        a.y * p1.row(2) - p1.row(1),
        b.x * p2.row(2) - p2.row(0),
        b.y * p2.row(2) - p2.row(1),
    ]);
    let eig = (m.transpose() * m).symmetric_eigen();
    let v = eig.eigenvectors.column(eig.eigenvalues.imin());
    (v[3].abs() > 1e-12).then(|| Vector3::new(v[0] / v[3], v[1] / v[3], v[2] / v[3])).filter(|x| x.iter().all(|c| c.is_finite()))
}

/// Pick the (R,t) candidate with most points in front of both cameras. Returns pose of camera 2
/// relative to camera 1 (X2 = R X1 + t, |t| = 1) and the triangulated points of inlier correspondences.
pub fn recover_pose(e: &Matrix3<f64>, x1: &[V2], x2: &[V2], inl: &[bool]) -> Option<(Isometry3<f64>, Vec<Option<Vector3<f64>>>)> {
    let p1 = p_matrix(&Isometry3::identity());
    let mut best: Option<(usize, Isometry3<f64>, Vec<Option<Vector3<f64>>>)> = None;
    for (r, t) in decompose_essential(e)? {
        let pose = Isometry3::from_parts(Translation3::from(t), UnitQuaternion::from_matrix(&r));
        let p2 = p_matrix(&pose);
        let mut count = 0;
        let pts: Vec<Option<Vector3<f64>>> = (0..x1.len()).map(|i| {
            if !inl[i] { return None; }
            let x = triangulate(&p1, &p2, x1[i], x2[i])?;
            let z2 = (r * x + t).z;
            (x.z > 1e-9 && z2 > 1e-9).then(|| { count += 1; x })
        }).collect();
        if best.as_ref().map_or(true, |b| count > b.0) { best = Some((count, pose, pts)); }
    }
    let (count, pose, pts) = best?;
    let n_inl = inl.iter().filter(|&&b| b).count();
    (count as f64 >= 0.6 * n_inl as f64 && count >= 12).then_some((pose, pts))
}

// ---------------------------------------------------------------- PnP

pub fn project(t_cw: &Isometry3<f64>, x: &Vector3<f64>) -> Option<V2> {
    let c = t_cw.rotation * x + t_cw.translation.vector;
    (c.z > 1e-6).then(|| V2::new(c.x / c.z, c.y / c.z))
}

/// Gauss-Newton on reprojection error with Huber weights (normalised units).
pub fn refine_pose(mut t: Isometry3<f64>, pts: &[Vector3<f64>], obs: &[V2], iters: usize, huber: f64) -> Isometry3<f64> {
    for _ in 0..iters {
        let mut h = SMatrix::<f64, 6, 6>::zeros();
        let mut g = SVector::<f64, 6>::zeros();
        for (x, o) in pts.iter().zip(obs) {
            let xc = t.rotation * x + t.translation.vector;
            if xc.z < 1e-6 { continue; }
            let inv = 1.0 / xc.z;
            let r = V2::new(xc.x * inv, xc.y * inv) - o;
            let n = r.norm();
            let w = if n <= huber { 1.0 } else { huber / n };
            let dpi = Matrix2x3::new(inv, 0.0, -xc.x * inv * inv, 0.0, inv, -xc.y * inv * inv);
            let mut j = SMatrix::<f64, 2, 6>::zeros();
            j.fixed_view_mut::<2, 3>(0, 0).copy_from(&dpi);
            j.fixed_view_mut::<2, 3>(0, 3).copy_from(&(-dpi * xc.cross_matrix()));
            h += w * j.transpose() * j;
            g -= w * j.transpose() * r;
        }
        for i in 0..6 { h[(i, i)] += 1e-9; }
        let Some(d) = h.cholesky().map(|c| c.solve(&g)).or_else(|| h.try_inverse().map(|i| i * g)) else { break };
        let dr = UnitQuaternion::from_scaled_axis(Vector3::new(d[3], d[4], d[5]));
        t = Isometry3::from_parts(Translation3::from(dr * t.translation.vector + Vector3::new(d[0], d[1], d[2])), dr * t.rotation);
        if d.norm() < 1e-9 { break; }
    }
    t
}

pub fn pnp_dlt(pts: &[Vector3<f64>], obs: &[V2]) -> Option<Isometry3<f64>> {
    if pts.len() < 6 { return None; }
    let mut ata = SMatrix::<f64, 12, 12>::zeros();
    for (x, o) in pts.iter().zip(obs) {
        let xh = [x.x, x.y, x.z, 1.0];
        let mut r1 = SVector::<f64, 12>::zeros();
        let mut r2 = SVector::<f64, 12>::zeros();
        for k in 0..4 {
            r1[k] = xh[k]; r1[8 + k] = -o.x * xh[k];
            r2[4 + k] = xh[k]; r2[8 + k] = -o.y * xh[k];
        }
        ata += r1 * r1.transpose() + r2 * r2.transpose();
    }
    let eig = ata.symmetric_eigen();
    let p = eig.eigenvectors.column(eig.eigenvalues.imin()).into_owned();
    let mut m = Matrix3::new(p[0], p[1], p[2], p[4], p[5], p[6], p[8], p[9], p[10]);
    let mut t4 = Vector3::new(p[3], p[7], p[11]);
    if m.determinant() < 0.0 { m = -m; t4 = -t4; }
    let svd = m.svd(true, true);
    let (u, vt) = (svd.u?, svd.v_t?);
    let lambda = svd.singular_values.mean();
    if lambda < 1e-12 { return None; }
    let r = u * vt;
    let t = t4 / lambda;
    let pose = Isometry3::from_parts(Translation3::from(t), UnitQuaternion::from_matrix(&r));
    let mean_z = pts.iter().map(|x| (pose.rotation * x + pose.translation.vector).z).sum::<f64>() / pts.len() as f64;
    (mean_z > 0.0).then_some(pose)
}

fn inlier_mask(t: &Isometry3<f64>, pts: &[Vector3<f64>], obs: &[V2], thresh: f64) -> Vec<bool> {
    pts.iter().zip(obs).map(|(x, o)| project(t, x).is_some_and(|p| (p - o).norm() < thresh)).collect()
}

/// PnP with an optional pose guess (motion prior). Falls back to DLT-RANSAC.
pub fn pnp_ransac(pts: &[Vector3<f64>], obs: &[V2], guess: Option<&Isometry3<f64>>, thresh: f64, rng: &mut Rng) -> Option<(Isometry3<f64>, Vec<bool>)> {
    let n = pts.len();
    if n < 8 { return None; }
    // Two-stage polish: a first refit on a generous inlier set, then a second on the strict (1x) set only, so
    // points that merely sit near the threshold (e.g. on a moving object) stop pulling the pose.
    let refit = |t: Isometry3<f64>, mask: &[bool], huber: f64| {
        let (p, o): (Vec<_>, Vec<_>) = pts.iter().zip(obs).zip(mask).filter(|(_, &m)| m).map(|((p, o), _)| (*p, *o)).unzip();
        if p.len() >= 6 { refine_pose(t, &p, &o, 10, huber) } else { t }
    };
    let polish = |t: Isometry3<f64>, mask: Vec<bool>| {
        let t = refit(t, &mask, thresh);
        let strict = inlier_mask(&t, pts, obs, thresh);
        let t = refit(t, &strict, thresh * 0.5);
        let m = inlier_mask(&t, pts, obs, thresh);
        (t, m)
    };
    if let Some(g) = guess {
        let t = refine_pose(*g, pts, obs, 15, thresh);
        let (t, m) = polish(t, inlier_mask(&t, pts, obs, thresh * 2.0));
        if m.iter().filter(|&&b| b).count() as f64 >= 0.6 * n as f64 { return Some((t, m)); }
    }
    let mut best: Option<(Isometry3<f64>, usize)> = None;
    for _ in 0..150 {
        let idx = rng.distinct(n, 6);
        let (p, o): (Vec<_>, Vec<_>) = idx.iter().map(|&i| (pts[i], obs[i])).unzip();
        let Some(t) = pnp_dlt(&p, &o) else { continue };
        let c = inlier_mask(&t, pts, obs, thresh).iter().filter(|&&b| b).count();
        if best.as_ref().map_or(true, |b| c > b.1) { best = Some((t, c)); }
    }
    let (t, c) = best?;
    if c < 8 { return None; }
    let (t, m) = polish(t, inlier_mask(&t, pts, obs, thresh));
    (m.iter().filter(|&&b| b).count() >= 8).then_some((t, m))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scene() -> (Vec<Vector3<f64>>, Isometry3<f64>) {
        let mut rng = Rng::new(3);
        let f = |r: &mut Rng| (r.below(2000) as f64 / 1000.0) - 1.0;
        let pts = (0..80).map(|_| Vector3::new(f(&mut rng) * 3.0, f(&mut rng) * 2.0, 4.0 + (f(&mut rng) + 1.0) * 3.0)).collect();
        let pose = Isometry3::from_parts(Translation3::new(0.4, -0.1, 0.2), UnitQuaternion::from_euler_angles(0.05, -0.12, 0.08));
        (pts, pose) // camera 2 pose relative to camera 1 (X2 = R X1 + t)
    }

    #[test]
    fn essential_pipeline_recovers_pose_up_to_scale() {
        let (pts, pose) = scene();
        let id = Isometry3::identity();
        let x1: Vec<V2> = pts.iter().map(|x| project(&id, x).unwrap()).collect();
        let mut x2: Vec<V2> = pts.iter().map(|x| project(&pose, x).unwrap()).collect();
        for i in [3, 17, 40] { x2[i] += V2::new(0.15, -0.1); } // gross outliers
        let mut rng = Rng::new(1);
        let (e, mask) = essential_ransac(&x1, &x2, 0.002, 200, &mut rng).expect("E");
        assert!(mask.iter().filter(|&&m| m).count() >= 75 && !mask[3] && !mask[17] && !mask[40]);
        let (rel, tri) = recover_pose(&e, &x1, &x2, &mask).expect("pose");
        let t_true = pose.translation.vector.normalize();
        assert!((rel.translation.vector - t_true).norm() < 1e-3, "t {:?} vs {:?}", rel.translation.vector, t_true);
        assert!(rel.rotation.angle_to(&pose.rotation) < 1e-3);
        // Depth recovered up to the unit-baseline scale.
        let s = 1.0 / pose.translation.vector.norm();
        let k = (0..80).find(|&i| mask[i]).unwrap();
        assert!((tri[k].unwrap() - pts[k] * s).norm() < 1e-2 * pts[k].norm() * s);
    }

    #[test]
    fn pnp_with_outliers_via_dlt_and_via_guess() {
        let (pts, pose) = scene();
        let mut obs: Vec<V2> = pts.iter().map(|x| project(&pose, x).unwrap()).collect();
        for i in 0..12 { obs[i * 6] += V2::new(0.2, 0.15); }
        let mut rng = Rng::new(9);
        let (t, m) = pnp_ransac(&pts, &obs, None, 0.003, &mut rng).expect("dlt ransac");
        assert!((t.translation.vector - pose.translation.vector).norm() < 1e-3 && t.rotation.angle_to(&pose.rotation) < 1e-3);
        assert!(m.iter().filter(|&&b| !b).count() >= 12);
        let guess = Isometry3::from_parts(Translation3::new(0.37, -0.06, 0.24), UnitQuaternion::from_euler_angles(0.07, -0.10, 0.06));
        let (t2, _) = pnp_ransac(&pts, &obs, Some(&guess), 0.003, &mut rng).expect("guided");
        assert!((t2.translation.vector - pose.translation.vector).norm() < 1e-3);
    }
}
