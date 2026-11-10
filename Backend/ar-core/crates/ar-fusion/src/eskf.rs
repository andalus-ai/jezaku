//! 15-state error-state Kalman filter (Solà, "Quaternion kinematics for the ESKF").
//! State: position, velocity, orientation (body->world), accel bias, gyro bias.
//! World frame is ENU (z up), so gravity is (0,0,-g).
use nalgebra::{Rotation3, SMatrix, SVector, UnitQuaternion, Vector3};

pub type Mat15 = SMatrix<f64, 15, 15>;
const GRAVITY: f64 = 9.80665;

#[derive(Debug, Clone, Copy)]
pub struct Noise {
    pub accel: f64,      // m/s^2/sqrt(Hz)
    pub gyro: f64,       // rad/s/sqrt(Hz)
    pub accel_walk: f64, // m/s^3/sqrt(Hz)
    pub gyro_walk: f64,  // rad/s^2/sqrt(Hz)
}
impl Default for Noise {
    fn default() -> Self {
        // Typical consumer MEMS values.
        Self { accel: 2e-2, gyro: 2e-3, accel_walk: 4e-4, gyro_walk: 4e-5 }
    }
}

#[derive(Debug, Clone)]
pub struct Eskf {
    pub p: Vector3<f64>,
    pub v: Vector3<f64>,
    pub q: UnitQuaternion<f64>,
    pub ba: Vector3<f64>,
    pub bg: Vector3<f64>,
    pub cov: Mat15,
    pub noise: Noise,
    t_last: Option<f64>,
}

impl Eskf {
    pub fn new(p: Vector3<f64>, q: UnitQuaternion<f64>, noise: Noise) -> Self {
        let mut cov = Mat15::zeros();
        for i in 0..3 {
            cov[(i, i)] = 25.0; // 5 m
            cov[(3 + i, 3 + i)] = 1.0;
            cov[(6 + i, 6 + i)] = 0.1;
            cov[(9 + i, 9 + i)] = 0.04;
            cov[(12 + i, 12 + i)] = 1e-4;
        }
        Self { p, v: Vector3::zeros(), q, ba: Vector3::zeros(), bg: Vector3::zeros(), cov, noise, t_last: None }
    }

    /// Roll/pitch from a stationary accelerometer reading; yaw left at 0.
    pub fn level_from_accel(accel: &Vector3<f64>) -> UnitQuaternion<f64> {
        UnitQuaternion::rotation_between(accel, &Vector3::z()).unwrap_or_else(UnitQuaternion::identity)
    }

    pub fn predict(&mut self, t: f64, gyro: Vector3<f64>, accel: Vector3<f64>) {
        let Some(t0) = self.t_last.replace(t) else { return };
        let dt = t - t0;
        if !(1e-6..0.5).contains(&dt) {
            return; // out-of-order or a gap too long to integrate across
        }
        let w = gyro - self.bg;
        let a = accel - self.ba;
        let r = self.q.to_rotation_matrix().into_inner();
        let a_w = r * a + Vector3::new(0.0, 0.0, -GRAVITY);

        self.p += self.v * dt + 0.5 * a_w * dt * dt;
        self.v += a_w * dt;
        self.q *= UnitQuaternion::from_scaled_axis(w * dt);

        let mut f = Mat15::identity();
        f.fixed_view_mut::<3, 3>(0, 3).copy_from(&(nalgebra::Matrix3::identity() * dt));
        f.fixed_view_mut::<3, 3>(3, 6).copy_from(&(-r * a.cross_matrix() * dt));
        f.fixed_view_mut::<3, 3>(3, 9).copy_from(&(-r * dt));
        f.fixed_view_mut::<3, 3>(6, 6)
            .copy_from(Rotation3::from_scaled_axis(-w * dt).matrix());
        f.fixed_view_mut::<3, 3>(6, 12).copy_from(&(-nalgebra::Matrix3::identity() * dt));

        let n = &self.noise;
        let mut q = Mat15::zeros();
        for i in 0..3 {
            q[(3 + i, 3 + i)] = n.accel.powi(2) * dt;
            q[(6 + i, 6 + i)] = n.gyro.powi(2) * dt;
            q[(9 + i, 9 + i)] = n.accel_walk.powi(2) * dt;
            q[(12 + i, 12 + i)] = n.gyro_walk.powi(2) * dt;
        }
        self.cov = f * self.cov * f.transpose() + q;
    }

    /// Generic update with Mahalanobis gating. Returns false if rejected.
    fn update<const M: usize>(
        &mut self,
        y: SVector<f64, M>,
        h: SMatrix<f64, M, 15>,
        r: SMatrix<f64, M, M>,
        gate_chi2: f64,
    ) -> bool {
        let s = h * self.cov * h.transpose() + r;
        let Some(s_inv) = s.try_inverse() else { return false };
        if (y.transpose() * s_inv * y)[0] > gate_chi2 {
            return false;
        }
        let k = self.cov * h.transpose() * s_inv;
        let dx = k * y;
        let ikh = Mat15::identity() - k * h;
        self.cov = ikh * self.cov * ikh.transpose() + k * r * k.transpose(); // Joseph form
        self.p += dx.fixed_rows::<3>(0);
        self.v += dx.fixed_rows::<3>(3);
        self.q *= UnitQuaternion::from_scaled_axis(Vector3::from(dx.fixed_rows::<3>(6)));
        self.ba += dx.fixed_rows::<3>(9);
        self.bg += dx.fixed_rows::<3>(12);
        true
    }

    /// 3-DoF position fix (GNSS ENU or aligned visual position). chi2 gate: 16.27 = 99.9% @ 3 dof.
    pub fn update_position(&mut self, z: Vector3<f64>, sigma: Vector3<f64>) -> bool {
        let mut h = SMatrix::<f64, 3, 15>::zeros();
        h.fixed_view_mut::<3, 3>(0, 0).fill_with_identity();
        let r = nalgebra::Matrix3::from_diagonal(&sigma.map(|s| s * s));
        self.update(z - self.p, h, r, 16.27)
    }

    /// Full orientation measurement (e.g. from visual tracking), body->world.
    pub fn update_orientation(&mut self, q_meas: &UnitQuaternion<f64>, sigma_rad: f64) -> bool {
        let mut h = SMatrix::<f64, 3, 15>::zeros();
        h.fixed_view_mut::<3, 3>(0, 6).fill_with_identity();
        let y = (self.q.inverse() * q_meas).scaled_axis();
        self.update(y, h, nalgebra::Matrix3::identity() * sigma_rad.powi(2), 16.27)
    }

    /// Hard re-initialise position (used when GNSS and the filter have persistently disagreed).
    pub fn reset_position(&mut self, z: Vector3<f64>, sigma: f64) {
        self.p = z;
        self.v = Vector3::zeros();
        for i in 0..6 {
            for j in 0..15 {
                self.cov[(i, j)] = 0.0;
                self.cov[(j, i)] = 0.0;
            }
        }
        for i in 0..3 {
            self.cov[(i, i)] = sigma * sigma;
            self.cov[(3 + i, 3 + i)] = 1.0;
        }
    }

    /// Hard re-initialise orientation (yaw is unobservable until a visual/geo reference exists, so the
    /// initial guess can be arbitrarily wrong and a Mahalanobis gate would reject the first measurement).
    /// Velocity was integrated through the wrong attitude, so it is reset too.
    pub fn reset_orientation(&mut self, q: UnitQuaternion<f64>, sigma_rad: f64) {
        self.q = q;
        self.v = Vector3::zeros();
        for i in 3..9 {
            for j in 0..15 {
                self.cov[(i, j)] = 0.0;
                self.cov[(j, i)] = 0.0;
            }
        }
        for i in 0..3 {
            self.cov[(3 + i, 3 + i)] = 1.0;
            self.cov[(6 + i, 6 + i)] = sigma_rad * sigma_rad;
        }
    }

    pub fn pos_sigma(&self) -> f64 {
        (self.cov[(0, 0)] + self.cov[(1, 1)] + self.cov[(2, 2)]).sqrt()
    }
}
