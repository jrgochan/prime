// siegel-walfisz/src/primes_in_ap.rs
//
// Prime counting in arithmetic progressions mod 8

/// Count primes ≤ x in each residue class mod 8.
/// Returns [π(x;8,1), π(x;8,3), π(x;8,5), π(x;8,7)]
pub fn count_primes_in_ap(is_prime: &[bool], x: usize) -> [usize; 4] {
    let mut counts = [0usize; 4];
    for k in 2..=x.min(is_prime.len() - 1) {
        if is_prime[k] {
            match k % 8 {
                1 => counts[0] += 1,
                3 => counts[1] += 1,
                5 => counts[2] += 1,
                7 => counts[3] += 1,
                _ => {} // p=2 → 2%8=2, skip
            }
        }
    }
    counts
}

/// Logarithmic integral Li(x) = ∫₂ˣ dt/ln(t), computed numerically via
/// Simpson's rule with 10000 panels.
pub fn li(x: f64) -> f64 {
    if x <= 2.0 {
        return 0.0;
    }
    let n = 10000usize;
    let h = (x - 2.0) / n as f64;
    let mut sum = 0.0;
    // Simpson's rule
    for i in 0..n {
        let a = 2.0 + i as f64 * h;
        let b = a + h;
        let mid = (a + b) / 2.0;
        sum += (h / 6.0) * (1.0 / a.ln() + 4.0 / mid.ln() + 1.0 / b.ln());
    }
    sum
}

/// The Chebyshev bias: which AP class leads?
/// Returns (leading_class, max_excess, chebyshev_string)
pub fn chebyshev_bias(counts: &[usize; 4]) -> (usize, i64, String) {
    let classes = [1, 3, 5, 7];
    let avg = (counts[0] + counts[1] + counts[2] + counts[3]) as f64 / 4.0;
    let mut max_idx = 0;
    let mut max_excess = 0i64;
    for i in 0..4 {
        let excess = counts[i] as i64 - avg as i64;
        if excess > max_excess {
            max_excess = excess;
            max_idx = i;
        }
    }
    let bias = format!(
        "π(x;8,{}) leads by {} (Chebyshev bias → nonsquare residues)",
        classes[max_idx], max_excess
    );
    (classes[max_idx], max_excess, bias)
}

/// Compute the error: |π(x;q,a) - Li(x)/φ(q)| / (x · exp(-c√log x))
/// for Siegel-Walfisz validation.
pub fn sw_normalized_error(pi_qa: usize, x: f64) -> f64 {
    let expected = li(x) / 4.0; // φ(8) = 4
    let error = (pi_qa as f64 - expected).abs();
    let log_x = x.ln();
    let sw_scale = x * (-0.5 * log_x.sqrt()).exp(); // x·exp(-c√log x) with c=0.5
    if sw_scale > 0.0 {
        error / sw_scale
    } else {
        0.0
    }
}
