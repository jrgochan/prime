//! Curve fitting utilities.
//!
//! Linear regression, power-law fits, and logarithmic decay fits
//! for eigenvalue decay analysis.

/// Simple linear regression: y = slope * x + intercept.
///
/// Returns (slope, intercept, r_squared).
pub fn linreg(data: &[(f64, f64)]) -> (f64, f64, f64) {
    let n = data.len() as f64;
    if n < 2.0 {
        return (0.0, 0.0, 0.0);
    }
    let sx: f64 = data.iter().map(|(x, _)| x).sum();
    let sy: f64 = data.iter().map(|(_, y)| y).sum();
    let sxx: f64 = data.iter().map(|(x, _)| x * x).sum();
    let sxy: f64 = data.iter().map(|(x, y)| x * y).sum();
    let denom = n * sxx - sx * sx;
    if denom.abs() < 1e-30 {
        return (0.0, sy / n, 0.0);
    }
    let slope = (n * sxy - sx * sy) / denom;
    let intercept = (sy - slope * sx) / n;

    // R²
    let y_mean = sy / n;
    let ss_tot: f64 = data.iter().map(|(_, y)| (y - y_mean).powi(2)).sum();
    let ss_res: f64 = data
        .iter()
        .map(|(x, y)| (y - slope * x - intercept).powi(2))
        .sum();
    let r2 = if ss_tot > 1e-30 {
        1.0 - ss_res / ss_tot
    } else {
        0.0
    };
    (slope, intercept, r2)
}

/// Power-law fit: val ≈ c · n^(-alpha).
///
/// Fits in log-log space: ln(val) = ln(c) - alpha * ln(n).
/// Returns (c, alpha, r_squared).
pub fn power_law_fit(ns: &[f64], vals: &[f64]) -> (f64, f64, f64) {
    let log_data: Vec<(f64, f64)> = ns
        .iter()
        .zip(vals.iter())
        .filter(|(&n, &v)| n > 0.0 && v > 0.0)
        .map(|(&n, &v)| (n.ln(), v.ln()))
        .collect();
    let (slope, intercept, r2) = linreg(&log_data);
    (intercept.exp(), -slope, r2)
}

/// Logarithmic decay fit: val ≈ c / (ln n)^beta.
///
/// Fits: ln(val) = ln(c) - beta * ln(ln(n)).
/// Returns (c, beta, r_squared).
pub fn log_decay_fit(ns: &[f64], vals: &[f64]) -> (f64, f64, f64) {
    let log_data: Vec<(f64, f64)> = ns
        .iter()
        .zip(vals.iter())
        .filter(|(&n, &v)| n > 1.0 && v > 0.0)
        .map(|(&n, &v)| (n.ln().ln(), v.ln()))
        .collect();
    if log_data.len() < 2 {
        return (0.0, 0.0, 0.0);
    }
    let (slope, intercept, r2) = linreg(&log_data);
    (intercept.exp(), -slope, r2)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_linreg_perfect_line() {
        let data: Vec<(f64, f64)> = (1..=10).map(|i| (i as f64, 2.0 * i as f64 + 1.0)).collect();
        let (slope, intercept, r2) = linreg(&data);
        assert!((slope - 2.0).abs() < 1e-10);
        assert!((intercept - 1.0).abs() < 1e-10);
        assert!((r2 - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_power_law_fit() {
        let ns: Vec<f64> = vec![10.0, 100.0, 1000.0];
        let vals: Vec<f64> = ns.iter().map(|&n| 5.0 * n.powf(-2.0)).collect();
        let (c, alpha, r2) = power_law_fit(&ns, &vals);
        assert!((c - 5.0).abs() < 0.1);
        assert!((alpha - 2.0).abs() < 0.01);
        assert!(r2 > 0.999);
    }
}
