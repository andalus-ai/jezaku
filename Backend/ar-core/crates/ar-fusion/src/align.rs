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
