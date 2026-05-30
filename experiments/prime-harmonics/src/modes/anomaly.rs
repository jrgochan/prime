//! # Anomaly Mode: Δ = G - R (Bridge 2 Explorer)
//!
//! Computes the anomaly matrix Δ(j,k) = G(j,k) - R(j,k) where:
//! - R(j,k) = gcd(j,k)² / (12·j·k)  — sawtooth (Ramanujan) Gram
//! - G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)}dx — BD Gram (exact analytical)
//!
//! ## The Analytical Trick
//!
//! Substitute u = 1/x in G(j,k):
//!   G(j,k) = ∫₁^∞ {u/j}·{u/k} · (1/u²) du
//!
//! Between consecutive breakpoints (multiples of j or k), both {u/j}
//! and {u/k} are linear in u, so the integral is elementary:
//!
//!   ∫_{u₁}^{u₂} (u/j - a)(u/k - b)/u² du
//!     = (u₂-u₁)/(jk) - (a/k+b/j)·ln(u₂/u₁) - ab·(1/u₂ - 1/u₁)
//!
//! This gives EXACT values (no quadrature) in O(max(j,k)) per entry.

use std::time::Instant;

/// Compute the exact BD Gram entry G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx
/// using the analytical piecewise-linear integration.
pub fn exact_gram(j: usize, k: usize) -> f64 {
    // After substitution u = 1/x:
    // G(j,k) = ∫₁^∞ {u/j}{u/k}/u² du
    //
    // Breakpoints where {u/j} or {u/k} jumps: u = m·j or u = m·k
    // We integrate from u=1 up to some large M, then add tail bound.

    let jf = j as f64;
    let kf = k as f64;

    // We need breakpoints: all multiples of j and k from 1 upward.
    // The tail ∫_M^∞ {u/j}{u/k}/u² du ≤ ∫_M^∞ 1/(4u²) du = 1/(4M)
    // So choose M large enough. For precision ~1e-14, use M = j*k*100.
    let m_max = (j * k * 100).max(10000);

    // Collect all breakpoints in [1, m_max]
    let mut breakpoints: Vec<f64> = Vec::with_capacity(m_max / j + m_max / k + 2);
    breakpoints.push(1.0);

    // Add multiples of j
    let mut m = 1;
    while m * j <= m_max {
        let bp = (m * j) as f64;
        if bp > 1.0 {
            breakpoints.push(bp);
        }
        m += 1;
    }

    // Add multiples of k
    m = 1;
    while m * k <= m_max {
        let bp = (m * k) as f64;
        if bp > 1.0 {
            breakpoints.push(bp);
        }
        m += 1;
    }

    breakpoints.push(m_max as f64);
    breakpoints.sort_by(|a, b| a.partial_cmp(b).unwrap());
    breakpoints.dedup();

    let mut total = 0.0f64;

    for i in 0..breakpoints.len() - 1 {
        let u1 = breakpoints[i];
        let u2 = breakpoints[i + 1];
        if u2 - u1 < 1e-15 {
            continue;
        }

        // At the midpoint, determine the floor values
        let mid = (u1 + u2) / 2.0;
        let a = (mid / jf).floor(); // floor(u/j) in this interval
        let b = (mid / kf).floor(); // floor(u/k) in this interval

        // Integral of (u/j - a)(u/k - b) / u² from u1 to u2
        // = ∫ [1/(jk) - (a/k + b/j)/u + ab/u²] du
        // = (u2-u1)/(jk) - (a/k + b/j)·ln(u2/u1) - ab·(1/u2 - 1/u1)
        let du = u2 - u1;
        let ln_ratio = (u2 / u1).ln();
        let inv_diff = 1.0 / u2 - 1.0 / u1; // negative

        let piece = du / (jf * kf) - (a / kf + b / jf) * ln_ratio - a * b * inv_diff;

        total += piece;
    }

    // Tail correction: ∫_{M}^∞ {u/j}{u/k}/u² du ≤ 1/(4M)
    // Actually we can be more precise: average value of {x}{y} is 1/4
    // so tail ≈ 1/(4M)
    total += 0.25 / (m_max as f64);

    total
}

/// Sawtooth (Ramanujan) Gram entry: R(j,k) = gcd(j,k)² / (12jk)
fn sawtooth_gram(j: usize, k: usize) -> f64 {
    let g = gcd(j, k);
    (g * g) as f64 / (12.0 * j as f64 * k as f64)
}

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 { a } else { gcd(b, a % b) }
}

/// Compute μ(n) (Möbius function)
fn moebius(n: usize) -> i32 {
    if n == 1 {
        return 1;
    }
    let mut temp = n;
    let mut d = 2usize;
    let mut count = 0;
    while d * d <= temp {
        if temp % d == 0 {
            let mut exp = 0;
            while temp % d == 0 {
                temp /= d;
                exp += 1;
            }
            if exp > 1 {
                return 0;
            }
            count += 1;
        }
        d += 1;
    }
    if temp > 1 {
        count += 1;
    }
    if count % 2 == 0 { 1 } else { -1 }
}

/// Fejér-Möbius weight: v_k = -μ(k)(1 - ln(k)/ln(N))
fn fejer_weight(k: usize, n: usize) -> f64 {
    let mu = moebius(k);
    if mu == 0 {
        return 0.0;
    }
    -(mu as f64) * (1.0 - (k as f64).ln() / (n as f64).ln())
}

pub fn run(n_max: usize) {
    eprintln!("🔬 Anomaly Explorer — Bridge 2: Δ = G - R");
    eprintln!("  N_max: {}", n_max);
    eprintln!();

    let start = Instant::now();

    // ═══════════════════════════════════════════════
    // §1. ANOMALY MATRIX ENTRIES
    // ═══════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§1. ANOMALY DIAGONAL: Δ(k,k) = G(k,k) - 1/12");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("{:>6} {:>14} {:>14} {:>14} {:>14}",
             "k", "R(k,k)=1/12", "G(k,k)", "Δ(k,k)", "Δ·12k²");
    println!("{}", "-".repeat(70));

    for k in 2..=n_max.min(50) {
        let r = sawtooth_gram(k, k);
        let g = exact_gram(k, k);
        let delta = g - r;
        let scaled = delta * 12.0 * (k * k) as f64;
        println!("{:>6} {:>14.10} {:>14.10} {:>+14.10} {:>14.6}",
                 k, r, g, delta, scaled);
    }

    println!();

    // ═══════════════════════════════════════════════
    // §2. v^T Δ v / logN — THE KEY OBSERVABLE
    // ═══════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§2. v^T Δ v / log N (RH ↔ this is bounded)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("{:>6} {:>12} {:>12} {:>12} {:>12} {:>12} {:>12}",
             "N", "v^T R v", "v^T G v", "v^T Δ v", "v^TΔv/lnN", "d²_BD", "d²·lnN");
    println!("{}", "-".repeat(85));

    let mut test_ns: Vec<usize> = (5..=n_max.min(50)).collect();
    // Also add some larger multiples if n_max > 50
    if n_max > 50 {
        let mut n = 60;
        while n <= n_max {
            test_ns.push(n);
            n += if n < 200 { 20 } else if n < 500 { 50 } else { 100 };
        }
    }

    for &n in &test_ns {
        let dim = n - 1;

        // Compute weight vector
        let v: Vec<f64> = (2..=n).map(|k| fejer_weight(k, n)).collect();

        // Compute v^T R v, v^T G v, v^T Δ v
        let mut v_r_v = 0.0f64;
        let mut v_g_v = 0.0f64;

        // Also compute b^T v (mean vector for BD)
        // b_k = ∫₀¹ {1/(kx)} dx ≈ 1/2 for large k
        // Exact: b_k = 1 - γ/k - (ln k)/(2k) + ... 
        // But for now compute from G: b_k = G(1,k) ... no, b_k = ∫₀¹ {1/(kx)} dx
        // Actually, ∫₀¹ {1/(kx)} dx = ∫₁^∞ {u/k}/u² du
        // Between breakpoints m·k and (m+1)·k:
        //   {u/k} = u/k - m, so ∫ (u/k - m)/u² du = [ln u/k + m/u]
        // This is computed by exact_gram(1, k) minus the sawtooth part...
        // Actually b_k = G(1,k)/something... let's compute directly.

        let mut b_v = 0.0f64;
        for i in 0..dim {
            let ki = i + 2;
            // b_ki = ∫₀¹ {1/(ki·x)} dx
            // Use the substitution: = ∫₁^∞ {u/ki}/u² du
            let b_i = compute_mean(ki);
            b_v += b_i * v[i];

            for j in 0..dim {
                let kj = j + 2;
                let r_ij = sawtooth_gram(ki, kj);
                let g_ij = exact_gram(ki, kj);

                v_r_v += v[i] * r_ij * v[j];
                v_g_v += v[i] * g_ij * v[j];
            }
        }

        let v_delta_v = v_g_v - v_r_v;
        let log_n = (n as f64).ln();
        let d2_bd = 1.0 - 2.0 * b_v + v_g_v;

        println!("{:>6} {:>12.6} {:>12.6} {:>+12.6} {:>12.6} {:>12.6} {:>12.4}",
                 n, v_r_v, v_g_v, v_delta_v, v_delta_v / log_n,
                 d2_bd, d2_bd * log_n);
    }

    println!();

    // ═══════════════════════════════════════════════
    // §3. SPECTRAL ANALYSIS (for small N)
    // ═══════════════════════════════════════════════
    if n_max <= 100 {
        println!("═══════════════════════════════════════════════════════════════");
        println!("§3. RANK STRUCTURE: How rank-1 is Δ?");
        println!("═══════════════════════════════════════════════════════════════");
        println!();

        for &n in &[10usize, 20, 30, 40, 50].iter().filter(|&&x| x <= n_max).copied().collect::<Vec<_>>() {
            let dim = n - 1;
            // Build Δ matrix (flattened row-major)
            let mut delta_flat: Vec<f64> = vec![0.0; dim * dim];
            for i in 0..dim {
                for j in 0..dim {
                    let g = exact_gram(i + 2, j + 2);
                    let r = sawtooth_gram(i + 2, j + 2);
                    delta_flat[i * dim + j] = g - r;
                }
            }

            // Compute trace and Frobenius norm
            let trace: f64 = (0..dim).map(|i| delta_flat[i * dim + i]).sum();
            let frob: f64 = delta_flat.iter().map(|x| x * x).sum::<f64>().sqrt();

            // Power iteration for top eigenvalue
            let mut u: Vec<f64> = (0..dim).map(|i| 1.0 / (i as f64 + 2.0)).collect();
            let norm: f64 = u.iter().map(|x| x * x).sum::<f64>().sqrt();
            for x in u.iter_mut() { *x /= norm; }

            let mut lambda_top = 0.0f64;
            for _ in 0..100 {
                let mut w = vec![0.0f64; dim];
                for i in 0..dim {
                    for j in 0..dim {
                        w[i] += delta_flat[i * dim + j] * u[j];
                    }
                }
                lambda_top = w.iter().zip(u.iter()).map(|(a, b)| a * b).sum();
                let norm: f64 = w.iter().map(|x| x * x).sum::<f64>().sqrt();
                for (x, wi) in u.iter_mut().zip(w.iter()) {
                    *x = wi / norm;
                }
            }

            // Alignment with Fejér weights
            let v: Vec<f64> = (2..=n).map(|k| fejer_weight(k, n)).collect();
            let v_dot_u: f64 = v.iter().zip(u.iter()).map(|(a, b)| a * b).sum();
            let v_norm: f64 = v.iter().map(|x| x * x).sum::<f64>().sqrt();
            let cos_angle = v_dot_u / v_norm;

            println!("N={:>3}: λ_top={:.6}  trace(Δ)={:.6}  ‖Δ‖_F={:.6}  \
                      λ_top/trace={:.3}",
                     n, lambda_top, trace, frob, lambda_top / trace);
            println!("       cos(v, u_top)={:.6}  |cos|²={:.6}",
                     cos_angle, cos_angle * cos_angle);
            println!("       u_top = [{:.4}, {:.4}, {:.4}, {:.4}, ...]",
                     u[0], u[1], u[2], u[3]);
            println!();
        }
    }

    let elapsed = start.elapsed();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§4. SUMMARY");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  N_max:          {}", n_max);
    println!("  Total time:     {:.2?}", elapsed);
    println!();
    println!("  Bridge 2 Status: Δ = G - R = Archimedean Perturbation");
    println!("  RH ↔ v^T Δ v = O(logN)");
    println!();
}

/// Compute b_k = ∫₀¹ {1/(kx)} dx using analytical piecewise integration.
fn compute_mean(k: usize) -> f64 {
    // ∫₀¹ {1/(kx)} dx = ∫₁^∞ {u/k}/u² du
    let kf = k as f64;
    let m_max = k * 1000;

    let mut total = 0.0f64;

    // From u=1 to u=k: {u/k} = u/k (since 0 < u/k < 1)
    // ∫₁^k (u/k)/u² du = (1/k)∫₁^k 1/u du = ln(k)/k
    if k > 1 {
        total += (k as f64).ln() / kf;
    }

    // From u=m·k to u=(m+1)·k for m=1,2,...
    // {u/k} = u/k - m
    // ∫ (u/k - m)/u² du = (1/k)ln(u₂/u₁) + m(1/u₂ - 1/u₁)
    for m in 1..(m_max / k) {
        let u1 = (m * k) as f64;
        let u2 = ((m + 1) * k) as f64;
        let mf = m as f64;
        let piece = (1.0 / kf) * (u2 / u1).ln() + mf * (1.0 / u2 - 1.0 / u1);
        total += piece;
    }

    // Tail: ∫_M^∞ {u/k}/u² du ≈ (1/2) · ∫_M^∞ 1/u² du = 1/(2M)
    total += 0.5 / (m_max as f64);

    total
}
