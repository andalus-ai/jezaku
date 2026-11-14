//! WGS84 <-> ECEF <-> local ENU (east, north, up).
use nalgebra::{Matrix3, Vector3};

const A: f64 = 6_378_137.0;
const F: f64 = 1.0 / 298.257_223_563;
const E2: f64 = F * (2.0 - F);

pub fn geodetic_to_ecef(lat_deg: f64, lon_deg: f64, alt: f64) -> Vector3<f64> {
    let (lat, lon) = (lat_deg.to_radians(), lon_deg.to_radians());
    let n = A / (1.0 - E2 * lat.sin().powi(2)).sqrt();
    Vector3::new(
        (n + alt) * lat.cos() * lon.cos(),
        (n + alt) * lat.cos() * lon.sin(),
        (n * (1.0 - E2) + alt) * lat.sin(),
    )
}

pub fn ecef_to_geodetic(p: &Vector3<f64>) -> (f64, f64, f64) {
    let lon = p.y.atan2(p.x);
    let r = p.x.hypot(p.y);
    let mut lat = p.z.atan2(r * (1.0 - E2));
    let mut alt = 0.0;
    for _ in 0..6 {
        let n = A / (1.0 - E2 * lat.sin().powi(2)).sqrt();
        alt = r / lat.cos() - n;
        lat = p.z.atan2(r * (1.0 - E2 * n / (n + alt)));
    }
    (lat.to_degrees(), lon.to_degrees(), alt)
}

/// Local tangent plane anchored at a geodetic origin.
#[derive(Debug, Clone, Copy)]
pub struct EnuFrame {
    origin_geo: (f64, f64, f64),
    origin_ecef: Vector3<f64>,
    r_enu_ecef: Matrix3<f64>,
}

impl EnuFrame {
    pub fn new(lat_deg: f64, lon_deg: f64, alt: f64) -> Self {
        let (lat, lon) = (lat_deg.to_radians(), lon_deg.to_radians());
        let (sl, cl, so, co) = (lat.sin(), lat.cos(), lon.sin(), lon.cos());
        let r = Matrix3::new(
            -so, co, 0.0, //
            -sl * co, -sl * so, cl, //
            cl * co, cl * so, sl,
        );
        Self { origin_geo: (lat_deg, lon_deg, alt), origin_ecef: geodetic_to_ecef(lat_deg, lon_deg, alt), r_enu_ecef: r }
    }
    /// (lat_deg, lon_deg, alt_m) of the ENU origin.
    pub fn origin(&self) -> (f64, f64, f64) { self.origin_geo }
    pub fn to_enu(&self, lat_deg: f64, lon_deg: f64, alt: f64) -> Vector3<f64> {
        self.r_enu_ecef * (geodetic_to_ecef(lat_deg, lon_deg, alt) - self.origin_ecef)
    }
    pub fn to_geodetic(&self, enu: &Vector3<f64>) -> (f64, f64, f64) {
        ecef_to_geodetic(&(self.r_enu_ecef.transpose() * enu + self.origin_ecef))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn roundtrip() {
        let f = EnuFrame::new(-6.9175, 107.6191, 700.0);
        let p = f.to_enu(-6.9170, 107.6200, 702.0);
        let (la, lo, al) = f.to_geodetic(&p);
        assert!((la + 6.9170).abs() < 1e-9 && (lo - 107.6200).abs() < 1e-9 && (al - 702.0).abs() < 1e-4);
    }
    #[test]
    fn north_is_positive_y() {
        let f = EnuFrame::new(0.0, 0.0, 0.0);
        let p = f.to_enu(0.001, 0.0, 0.0);
        assert!(p.y > 100.0 && p.x.abs() < 1e-6);
    }
}
