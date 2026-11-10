//! Umeyama similarity alignment: find s,R,t minimising |dst - (s R src + t)|^2.
use nalgebra::{Matrix3, Rotation3, Vector3};

#[derive(Debug, Clone, Copy)]
pub struct Similarity {
    pub scale: f64,
    pub rot: Rotation3<f64>,
    pub trans: Vector3<f64>,
}
impl Similarity {
    pub fn apply(&self, p: &Vector3<f64>) -> Vector3<f64> {
        self.scale * (self.rot * p) + self.trans
    }
}

impl Similarity {
    /// Inverse of `apply` for a point: world -> map.
    pub fn inverse_apply(&self, p: &Vector3<f64>) -> Vector3<f64> {
        self.rot.inverse() * (p - self.trans) / self.scale
    }
}

/// Gravity-aware alignment: the map's "up" (`up_map`, from IMU + visual orientation) is rotated onto ENU +Z,
/// leaving a 4-DoF problem (yaw, translation, optional scale) that stays well-conditioned for near-planar walks
/// where a full 6-DoF fit cannot observe tilt.
pub fn gravity_yaw_similarity(src: &[Vector3<f64>], dst: &[Vector3<f64>], up_map: &Vector3<f64>, with_scale: bool) -> Option<Similarity> {
    let n = src.len();
    if n < 3 || n != dst.len() { return None; }
    let rg = Rotation3::rotation_between(up_map, &Vector3::z())?;
    let sg: Vec<Vector3<f64>> = src.iter().map(|p| rg * p).collect();
    let nf = n as f64;
    let mu_s = sg.iter().sum::<Vector3<f64>>() / nf;
    let mu_d = dst.iter().sum::<Vector3<f64>>() / nf;
    let (mut dot, mut cross, mut var_xy, mut var) = (0.0, 0.0, 0.0, 0.0);
    for (s, d) in sg.iter().zip(dst) {
        let (a, b) = (s - mu_s, d - mu_d);
        dot += a.x * b.x + a.y * b.y;
        cross += a.x * b.y - a.y * b.x;
        var_xy += a.x * a.x + a.y * a.y;
        var += a.norm_squared();
    }
    if var_xy < 1e-9 { return None; }
    let rz = Rotation3::from_axis_angle(&Vector3::z_axis(), cross.atan2(dot));
    let scale = if with_scale {
        let num: f64 = sg.iter().zip(dst).map(|(s, d)| (d - mu_d).dot(&(rz * (s - mu_s)))).sum();
        num / var
    } else { 1.0 };
    if !(scale.is_finite() && scale > 1e-6) { return None; }
    Some(Similarity { scale, rot: rz * rg, trans: mu_d - scale * (rz * mu_s) })
}

pub fn umeyama(src: &[Vector3<f64>], dst: &[Vector3<f64>], with_scale: bool) -> Option<Similarity> {
    let n = src.len();
    if n < 3 || n != dst.len() {
        return None;
    }
    let nf = n as f64;
    let mu_s = src.iter().sum::<Vector3<f64>>() / nf;
    let mu_d = dst.iter().sum::<Vector3<f64>>() / nf;
    let mut cov = Matrix3::zeros();
    let mut var_s = 0.0;
    for (s, d) in src.iter().zip(dst) {
        let (ds, dd) = (s - mu_s, d - mu_d);
        cov += dd * ds.transpose();
        var_s += ds.norm_squared();
    }
    cov /= nf;
    var_s /= nf;
    if var_s < 1e-12 {
        return None;
    }
    let svd = cov.svd(true, true);
    let (u, vt) = (svd.u?, svd.v_t?);
    let mut s_fix = Matrix3::identity();
    if (u.determinant() * vt.determinant()) < 0.0 {
        s_fix[(2, 2)] = -1.0;
    }
    let r = u * s_fix * vt;
    let scale = if with_scale { (svd.singular_values.component_mul(&s_fix.diagonal())).sum() / var_s } else { 1.0 };
    let rot = Rotation3::from_matrix_unchecked(r);
    Some(Similarity { scale, rot, trans: mu_d - scale * (rot * mu_s) })
}
