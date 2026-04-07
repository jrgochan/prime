//! Gram matrix entry computation — exact piecewise integration.
//! Copied from lambda-eff/src/gram.rs for self-containment.

/// Compute G[j,k] = ∫₀¹ {j/x}{k/x} dx using exact piecewise integration.
pub fn gram_entry(j: usize, k: usize) -> f64 {
    if j == 0 || k == 0 {
        return 0.0;
    }
    let jf = j as f64;
    let kf = k as f64;
    let m_max = (j.max(k)) * 10 + 200;

    let mut breaks: Vec<f64> = Vec::with_capacity(2 * m_max);
    for m in j..=m_max {
        let x = jf / (m as f64);
        if x > 0.0 && x <= 1.0 {
            breaks.push(x);
        }
    }
    for m in k..=m_max {
        let x = kf / (m as f64);
        if x > 0.0 && x <= 1.0 {
            breaks.push(x);
        }
    }
    breaks.push(1.0);
    breaks.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breaks.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    let mut total = 0.0;
    for i in 0..breaks.len() - 1 {
        let x_lo = breaks[i];
        let x_hi = breaks[i + 1];
        if x_hi - x_lo < 1e-18 {
            continue;
        }
        let x_mid = 0.5 * (x_lo + x_hi);
        let a = (jf / x_mid).floor();
        let b = (kf / x_mid).floor();
        let jk = jf * kf;
        let lin_coeff = b * jf + a * kf;
        let const_coeff = a * b;
        let f_hi = -jk / x_hi - lin_coeff * x_hi.ln() + const_coeff * x_hi;
        let f_lo = -jk / x_lo - lin_coeff * x_lo.ln() + const_coeff * x_lo;
        total += f_hi - f_lo;
    }
    total
}

/// Compute ∫₀¹ {j/x} dx using exact piecewise integration.
pub fn fract_integral(j: usize) -> f64 {
    if j == 0 {
        return 0.0;
    }
    let jf = j as f64;
    let m_max = j * 10 + 200;

    let mut breaks: Vec<f64> = Vec::with_capacity(m_max);
    for m in j..=m_max {
        let x = jf / (m as f64);
        if x > 0.0 && x <= 1.0 {
            breaks.push(x);
        }
    }
    breaks.push(1.0);
    breaks.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breaks.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    let mut total = 0.0;
    for i in 0..breaks.len() - 1 {
        let x_lo = breaks[i];
        let x_hi = breaks[i + 1];
        if x_hi - x_lo < 1e-18 {
            continue;
        }
        let x_mid = 0.5 * (x_lo + x_hi);
        let a = (jf / x_mid).floor();
        // ∫ (j/x - a) dx = -j·ln(x) - a·x + C, evaluated [x_lo, x_hi]
        // actually: ∫ {j/x} dx = ∫ (j/x - a) dx = j·ln(x_hi/x_lo) - a·(x_hi - x_lo)
        // Wait, antiderivative of j/x is j·ln(x), antiderivative of a is a·x
        // F(x) = j·ln(x) - a·x
        // but {j/x} = j/x - a, so ∫ (j/x - a) dx = j·ln(x) - a·x
        let f_hi = jf * x_hi.ln() - a * x_hi;
        let f_lo = jf * x_lo.ln() - a * x_lo;
        total += f_hi - f_lo;
    }
    total
}
