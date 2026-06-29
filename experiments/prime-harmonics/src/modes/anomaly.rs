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

use rayon::prelude::*;
use std::time::Instant;

/// Compute the exact BD Gram entry G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx
/// using the analytical piecewise-linear integration.
pub fn exact_gram(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;

    // Precision: tail ~ 1/(4M), so M = j*k*100 gives ~1e-6 relative error.
    // For j,k > 100, cap M to avoid excessive breakpoints.
    let m_max = ((j * k).min(100_000)) * 100;
    let m_max = m_max.max(10000).min(50_000_000);

    // Merge breakpoints from multiples of j and k in [1, m_max].
    // Instead of sorting, iterate through multiples in order.
    let mut total = 0.0f64;
    let mut mj = 1usize; // next multiple of j index
    let mut mk = 1usize; // next multiple of k index

    let mut u_prev = 1.0f64;

    loop {
        let next_j = mj * j;
        let next_k = mk * k;

        let next_bp = if next_j <= m_max && next_k <= m_max {
            next_j.min(next_k)
        } else if next_j <= m_max {
            next_j
        } else if next_k <= m_max {
            next_k
        } else {
            break;
        };

        let u_next = next_bp as f64;
        if u_next > u_prev + 1e-15 {
            let mid = (u_prev + u_next) / 2.0;
            let a = (mid / jf).floor();
            let b = (mid / kf).floor();
            let du = u_next - u_prev;
            let ln_ratio = (u_next / u_prev).ln();
            let inv_diff = 1.0 / u_next - 1.0 / u_prev;
            total += du / (jf * kf) - (a / kf + b / jf) * ln_ratio - a * b * inv_diff;
        }

        u_prev = u_next;
        if next_j <= next_k {
            mj += 1;
        }
        if next_k <= next_j {
            mk += 1;
        }
        if next_bp >= m_max {
            break;
        }
    }

    // Tail correction
    total += 0.25 / (m_max as f64);
    total
}

/// Sawtooth (Ramanujan) Gram entry: R(j,k) = gcd(j,k)² / (12jk)
fn sawtooth_gram(j: usize, k: usize) -> f64 {
    let g = gcd(j, k);
    (g * g) as f64 / (12.0 * j as f64 * k as f64)
}

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 {
        a
    } else {
        gcd(b, a % b)
    }
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
        if temp.is_multiple_of(d) {
            let mut exp = 0;
            while temp.is_multiple_of(d) {
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
    if count % 2 == 0 {
        1
    } else {
        -1
    }
}

/// Fejér-Möbius weight: v_k = -μ(k)(1 - ln(k)/ln(N))
fn fejer_weight(k: usize, n: usize) -> f64 {
    let mu = moebius(k);
    if mu == 0 {
        return 0.0;
    }
    -(mu as f64) * (1.0 - (k as f64).ln() / (n as f64).ln())
}

/// Compute b_k = ∫₀¹ {1/(kx)} dx using analytical piecewise integration.
fn compute_mean(k: usize) -> f64 {
    let kf = k as f64;
    let m_max = k * 1000;
    let mut total = 0.0f64;
    if k > 1 {
        total += (k as f64).ln() / kf;
    }
    for m in 1..(m_max / k) {
        let u1 = (m * k) as f64;
        let u2 = ((m + 1) * k) as f64;
        let mf = m as f64;
        total += (1.0 / kf) * (u2 / u1).ln() + mf * (1.0 / u2 - 1.0 / u1);
    }
    total += 0.5 / (m_max as f64);
    total
}

/// Compute v^T M v where M(j,k) = f(j+2, k+2), SPARSE: skip zero weights.
/// Uses Rayon for row-parallelism.
fn sparse_quad_form(
    v: &[f64],
    nonzero_idx: &[usize], // indices where v[i] != 0
    entry_fn: impl Fn(usize, usize) -> f64 + Sync,
) -> f64 {
    nonzero_idx
        .par_iter()
        .map(|&i| {
            let vi = v[i];
            let ki = i + 2;
            let mut row_sum = 0.0f64;
            for &j in nonzero_idx {
                let kj = j + 2;
                row_sum += v[j] * entry_fn(ki, kj);
            }
            vi * row_sum
        })
        .sum()
}

pub fn run(n_max: usize) {
    eprintln!("🔬 Anomaly Explorer — Bridge 2: Δ = G - R (PARALLEL)");
    eprintln!("  N_max: {}", n_max);
    eprintln!("  Threads: {}", rayon::current_num_threads());
    eprintln!();

    let start = Instant::now();

    // ═══════════════════════════════════════════════
    // §1. ANOMALY DIAGONAL (small sample)
    // ═══════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§1. ANOMALY DIAGONAL: Δ(k,k) = G(k,k) - 1/12");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>6} {:>14} {:>14} {:>14} {:>14}",
        "k", "R(k,k)=1/12", "G(k,k)", "Δ(k,k)", "Δ·12k²"
    );
    println!("{}", "-".repeat(70));

    for k in 2..=n_max.min(50) {
        let r = sawtooth_gram(k, k);
        let g = exact_gram(k, k);
        let delta = g - r;
        let scaled = delta * 12.0 * (k * k) as f64;
        println!(
            "{:>6} {:>14.10} {:>14.10} {:>+14.10} {:>14.6}",
            k, r, g, delta, scaled
        );
    }
    println!();

    // ═══════════════════════════════════════════════
    // §2. v^T Δ v / logN — THE KEY OBSERVABLE (PARALLEL)
    // ═══════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("§2. v^T Δ v / log N (RH ↔ this is bounded)");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "{:>6} {:>12} {:>12} {:>12} {:>12} {:>12} {:>12} {:>8}",
        "N", "v^T R v", "v^T G v", "v^T Δ v", "v^TΔv/lnN", "d²_BD", "d²·lnN", "nnz/N"
    );
    println!("{}", "-".repeat(92));

    let mut test_ns: Vec<usize> = vec![];
    // Dense for small N
    for n in (5..=n_max.min(50)).step_by(1) {
        test_ns.push(n);
    }
    // Coarser for larger N
    if n_max > 50 {
        let mut n = 60;
        while n <= n_max {
            test_ns.push(n);
            n += if n < 200 {
                20
            } else if n < 500 {
                50
            } else {
                100
            };
        }
        if !test_ns.contains(&n_max) {
            test_ns.push(n_max);
        }
    }

    for &n in &test_ns {
        let dim = n - 1;
        let v: Vec<f64> = (2..=n).map(|k| fejer_weight(k, n)).collect();

        // Find nonzero indices (skip μ(k)=0)
        let nonzero_idx: Vec<usize> = (0..dim).filter(|&i| v[i].abs() > 1e-30).collect();
        let nnz = nonzero_idx.len();

        // Compute b^T v
        let b_v: f64 = nonzero_idx
            .par_iter()
            .map(|&i| compute_mean(i + 2) * v[i])
            .sum();

        // Compute v^T R v (sparse, parallel)
        let v_r_v = sparse_quad_form(&v, &nonzero_idx, sawtooth_gram);

        // Compute v^T G v (sparse, parallel — the expensive one)
        let v_g_v = sparse_quad_form(&v, &nonzero_idx, exact_gram);

        let v_delta_v = v_g_v - v_r_v;
        let log_n = (n as f64).ln();
        let d2_bd = 1.0 - 2.0 * b_v + v_g_v;

        println!(
            "{:>6} {:>12.6} {:>12.6} {:>+12.6} {:>12.6} {:>12.6} {:>12.4} {:>7.1}%",
            n,
            v_r_v,
            v_g_v,
            v_delta_v,
            v_delta_v / log_n,
            d2_bd,
            d2_bd * log_n,
            100.0 * nnz as f64 / dim as f64
        );
    }

    println!();

    let elapsed = start.elapsed();
    println!("═══════════════════════════════════════════════════════════════");
    println!("§3. SUMMARY");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!("  N_max:          {}", n_max);
    println!("  Total time:     {:.2?}", elapsed);
    println!();
    println!("  Bridge 2 Status: Δ = G - R = Archimedean Perturbation");
    println!("  RH ↔ v^T Δ v = O(logN)");
    println!();

    println!();
}
