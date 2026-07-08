//! Cathedral hypothesis probes for semiprime factorization.
//!
//! Each probe tests a specific prediction from the Cathedral proof chain
//! against known factorizations, measuring signal-to-noise ratio.

use crate::keygen::SemiprimeKey;
use cathedral_utils::arith;
use cathedral_utils::eigen;
use cathedral_utils::gram;
use cathedral_utils::spectral;

// ═══════════════════════════════════════════════════════════════
// H1: GCD-Stratum Eigenvector Correlation
//
// The Gram matrix G(j,k) depends on gcd(j,k). Multiples of the
// unknown factors p,q form "lattices" in index space. Do eigenvectors
// of G_M concentrate on these lattices?
// ═══════════════════════════════════════════════════════════════

pub fn h1_gcd_stratum_eigenvector(keys: &[SemiprimeKey]) {
    println!("  [H1] GCD-Stratum Eigenvector Correlation");
    println!("  ─────────────────────────────────────────");

    let mut factor_pr_sum = 0.0;
    let mut random_pr_sum = 0.0;
    let mut count = 0usize;

    for key in keys.iter().take(5) {
        // Probe depth: min(√N, 200) to keep computation manageable
        let m = ((key.n as f64).sqrt() as usize).min(200).max(20);
        if m < 10 {
            continue;
        }

        // Build Gram submatrix (indices 2..m+1)
        let dim = m - 1;
        let mut gram_mat = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in i..dim {
                let g = gram::gram_entry_f64(i + 2, j + 2);
                gram_mat[i * dim + j] = g;
                gram_mat[j * dim + i] = g;
            }
        }

        // Eigendecompose — ground state is eigenvectors[0] (sorted ascending)
        let eig = eigen::eigen_f64(&gram_mat, dim);
        if eig.eigenvalues.is_empty() {
            continue;
        }

        let ground = &eig.eigenvectors[0]; // Vec<f64>

        // Compute weight restricted to multiples of p vs random prime
        let p_weight: f64 = (0..dim)
            .filter(|i| (i + 2) % key.p as usize == 0)
            .map(|i| ground[i] * ground[i])
            .sum();

        // Compare to a random non-factor prime near p
        let rand_p = next_non_factor_prime(key.p, key.n);
        let rand_weight: f64 = (0..dim)
            .filter(|i| (i + 2) % rand_p as usize == 0)
            .map(|i| ground[i] * ground[i])
            .sum();

        let p_count = (0..dim).filter(|i| (i + 2) % key.p as usize == 0).count();
        let r_count = (0..dim).filter(|i| (i + 2) % rand_p as usize == 0).count();

        // Normalize by number of lattice points
        let p_density = if p_count > 0 {
            p_weight / p_count as f64
        } else {
            0.0
        };
        let r_density = if r_count > 0 {
            rand_weight / r_count as f64
        } else {
            0.0
        };

        println!(
            "    N={}: factor p={} density={:.6e}, non-factor p'={} density={:.6e}, ratio={:.3}",
            key.n,
            key.p,
            p_density,
            rand_p,
            r_density,
            if r_density > 0.0 {
                p_density / r_density
            } else {
                f64::INFINITY
            }
        );

        factor_pr_sum += p_density;
        random_pr_sum += r_density;
        count += 1;
    }

    if count > 0 {
        let avg_ratio = (factor_pr_sum / count as f64) / (random_pr_sum / count as f64);
        println!(
            "    ▸ Average factor/non-factor density ratio: {:.4}",
            avg_ratio
        );
        println!(
            "    ▸ Signal: {}\n",
            if avg_ratio > 1.5 {
                "STRONG ⚡"
            } else if avg_ratio > 1.1 {
                "weak 〜"
            } else {
                "null ∅"
            }
        );
    }
}

// ═══════════════════════════════════════════════════════════════
// H2: Optimal Weight Vector Structure
//
// v_opt = G⁻¹b — do the weights at indices p, q stand out?
// The witness vector v_k = -μ(k)·(1 - ln(k)/ln(N)) should have
// distinctive values at the actual factors.
// ═══════════════════════════════════════════════════════════════

pub fn h2_optimal_weight_structure(keys: &[SemiprimeKey]) {
    println!("  [H2] Optimal Weight Vector at Factor Indices");
    println!("  ─────────────────────────────────────────────");

    for key in keys.iter().take(5) {
        let m = ((key.p as usize) * 3).min(500).max(20);
        let mu = arith::mobius_table(m);
        let ln_n = (key.n as f64).ln();

        // Compute witness weights for indices 2..m
        let mut weights: Vec<(usize, f64)> = (2..m)
            .map(|k| {
                let mu_k = if k < mu.len() { mu[k] as f64 } else { 0.0 };
                let w = -mu_k * (1.0 - (k as f64).ln() / ln_n);
                (k, w.abs())
            })
            .collect();

        // Sort by absolute weight (descending)
        weights.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());

        // Find rank of factor p
        let p_rank = weights.iter().position(|(k, _)| *k == key.p as usize);
        let q_in_range = (key.q as usize) < m;
        let q_rank = if q_in_range {
            weights.iter().position(|(k, _)| *k == key.q as usize)
        } else {
            None
        };

        let p_weight = weights
            .iter()
            .find(|(k, _)| *k == key.p as usize)
            .map(|(_, w)| *w)
            .unwrap_or(0.0);
        let median_weight = weights
            .get(weights.len() / 2)
            .map(|(_, w)| *w)
            .unwrap_or(1.0);

        println!(
            "    N={}: p={} rank={}/{}, |w_p|={:.6e}, median={:.6e}, ratio={:.2}{}",
            key.n,
            key.p,
            p_rank.map(|r| r + 1).unwrap_or(0),
            weights.len(),
            p_weight,
            median_weight,
            if median_weight > 0.0 {
                p_weight / median_weight
            } else {
                0.0
            },
            if let Some(qr) = q_rank {
                format!(", q={} rank={}", key.q, qr + 1)
            } else {
                String::new()
            }
        );
    }
    println!();
}

// ═══════════════════════════════════════════════════════════════
// H3: Vasyunin Cotangent Sum Anomaly
//
// V(m, N) = Σ_{j=1}^{m-1} {jN/m} · cot(πj/m)
// When m divides N, {jN/m} = 0 for all j, so V(m,N) = 0 exactly.
// This is trivially detectable — but can we detect it spectrally?
// ═══════════════════════════════════════════════════════════════

pub fn h3_vasyunin_cotangent_anomaly(keys: &[SemiprimeKey]) {
    println!("  [H3] Vasyunin Cotangent Sum Anomaly");
    println!("  ────────────────────────────────────");

    for key in keys.iter().take(3) {
        let scan_limit = ((key.n as f64).sqrt() as u64).min(500);
        let mut anomalies: Vec<(u64, f64)> = Vec::new();
        let mut non_factor_sums: Vec<f64> = Vec::new();

        for m in 2..=scan_limit {
            let v = vasyunin_sum(m, key.n);
            let v_abs = v.abs();

            if key.n % m == 0 {
                anomalies.push((m, v_abs));
            } else {
                non_factor_sums.push(v_abs);
            }
        }

        let median_nf = percentile(&non_factor_sums, 50.0);
        let p90_nf = percentile(&non_factor_sums, 90.0);

        println!("    N={} = {}×{}", key.n, key.p, key.q);
        println!(
            "      Non-factor |V(m,N)| median={:.4e}, p90={:.4e}",
            median_nf, p90_nf
        );
        for (m, v) in &anomalies {
            let label = if *m == key.p {
                " ← FACTOR p"
            } else if *m == key.q {
                " ← FACTOR q"
            } else {
                " (divisor)"
            };
            println!("      V({}, N) = {:.4e}{}", m, v, label);
        }

        // Check: how many non-factors have |V| < min(factor |V|)?
        let min_factor_v = anomalies
            .iter()
            .map(|(_, v)| *v)
            .fold(f64::INFINITY, f64::min);
        let false_positives = non_factor_sums
            .iter()
            .filter(|&&v| v <= min_factor_v * 1.1)
            .count();
        println!(
            "      False positives (|V| ≤ factor level): {}/{}\n",
            false_positives,
            non_factor_sums.len()
        );
    }
}

// ═══════════════════════════════════════════════════════════════
// H4: Möbius/Liouville Local Structure
//
// μ(N) and λ(N) encode the multiplicative structure of N.
// The local Mertens profile near N may reveal factor proximity.
// ═══════════════════════════════════════════════════════════════

pub fn h4_mobius_local_structure(keys: &[SemiprimeKey]) {
    println!("  [H4] Möbius/Liouville Local Structure");
    println!("  ─────────────────────────────────────");

    for key in keys.iter().take(5) {
        if key.n > 500_000 {
            continue;
        } // Möbius sieve limit

        let n = key.n as usize;
        let window = (n / 10).min(1000).max(50);
        let _lo = if n > window { n - window } else { 2 };
        let hi = (n + window).min(n + 1000);

        let mu = arith::mobius_table(hi);
        let lambda = arith::liouville_table(hi);

        // Compute running Mertens and Liouville sums in window
        let mut m_sum = 0i64;
        let mut l_sum = 0i64;
        let mut m_at_n = 0i64;
        let mut l_at_n = 0i64;

        for k in 1..=hi {
            m_sum += mu[k] as i64;
            l_sum += lambda[k] as i64;
            if k == n {
                m_at_n = m_sum;
                l_at_n = l_sum;
            }
        }

        // Standard Model charges
        let omega_n = arith::big_omega(n);
        let mu_n = mu[n];
        let lambda_n = lambda[n];

        println!("    N={} = {}×{}", key.n, key.p, key.q);
        println!(
            "      μ(N)={}, λ(N)={}, Ω(N)={}, M(N)={}, L(N)={}",
            mu_n, lambda_n, omega_n, m_at_n, l_at_n
        );

        // Local Mertens gradient: M(N+p) - M(N) vs M(N+r) - M(N) for random r
        let m_diff_p = if n + key.p as usize <= hi {
            let mut s = 0i64;
            for k in (n + 1)..=(n + key.p as usize) {
                s += mu[k] as i64;
            }
            Some(s)
        } else {
            None
        };

        let r = next_non_factor_prime(key.p, key.n) as usize;
        let m_diff_r = if n + r <= hi {
            let mut s = 0i64;
            for k in (n + 1)..=(n + r) {
                s += mu[k] as i64;
            }
            Some(s)
        } else {
            None
        };

        if let (Some(dp), Some(dr)) = (m_diff_p, m_diff_r) {
            println!(
                "      ΔM(N→N+p) = {}, ΔM(N→N+{}) = {}, diff = {}",
                dp,
                r,
                dr,
                (dp - dr).abs()
            );
        }

        // Count squarefree integers in [N-p..N+p]
        let p = key.p as usize;
        let sqfree_count = (n.saturating_sub(p)..=(n + p).min(hi))
            .filter(|&k| k > 0 && k < mu.len() && mu[k] != 0)
            .count();
        let expected_sqfree = (2 * p + 1) as f64 * 6.0 / std::f64::consts::PI.powi(2);
        println!(
            "      Squarefree in [N-p, N+p]: {} (expected {:.1}), ratio={:.3}\n",
            sqfree_count,
            expected_sqfree,
            sqfree_count as f64 / expected_sqfree
        );
    }
}

// ═══════════════════════════════════════════════════════════════
// H5: Composite Anchoring Inversion
//
// Cathedral proves ground state eigenvectors concentrate on HC
// numbers and avoid primes. For Gram matrix near N=pq, check
// whether the PR restricted to multiples of candidate divisors
// shows a minimum at the true factors.
// ═══════════════════════════════════════════════════════════════

pub fn h5_composite_anchoring(keys: &[SemiprimeKey]) {
    println!("  [H5] Composite Anchoring / Factor Shadow");
    println!("  ─────────────────────────────────────────");

    for key in keys.iter().take(3) {
        let m = ((key.p as usize) * 2).min(200).max(20);
        let dim = m - 1;

        // Build and eigendecompose Gram matrix
        let mut gram_mat = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in i..dim {
                let g = gram::gram_entry_f64(i + 2, j + 2);
                gram_mat[i * dim + j] = g;
                gram_mat[j * dim + i] = g;
            }
        }

        let eig = eigen::eigen_f64(&gram_mat, dim);
        if eig.eigenvalues.is_empty() {
            continue;
        }

        let ground = &eig.eigenvectors[0]; // ground state
        let full_pr = spectral::participation_ratio(ground);

        // Scan small primes: for each candidate divisor d,
        // compute weight of ground state on multiples of d
        let sieve = arith::sieve_primes(m);
        let mut prime_weights: Vec<(usize, f64, bool)> = Vec::new();

        for d in 2..m {
            if !sieve[d] {
                continue;
            }
            let mult_count = (0..dim).filter(|i| (i + 2) % d == 0).count();
            if mult_count == 0 {
                continue;
            }

            let weight: f64 = (0..dim)
                .filter(|i| (i + 2) % d == 0)
                .map(|i| ground[i] * ground[i])
                .sum();

            let density = weight / mult_count as f64;
            let is_factor = key.n % d as u64 == 0;
            prime_weights.push((d, density, is_factor));
        }

        // Sort by density (ascending — factors should be near bottom if "avoided")
        prime_weights.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

        println!(
            "    N={} = {}×{}, M={}, PR={:.4}",
            key.n, key.p, key.q, m, full_pr
        );
        println!("      Prime divisor density ranking (low = avoided):");
        for (i, (d, density, is_factor)) in prime_weights.iter().take(10).enumerate() {
            println!(
                "        #{}: d={:5} density={:.6e} {}",
                i + 1,
                d,
                density,
                if *is_factor { "← FACTOR" } else { "" }
            );
        }

        // Where do the actual factors rank?
        if let Some(p_rank) = prime_weights
            .iter()
            .position(|(d, _, _)| *d == key.p as usize)
        {
            println!(
                "      Factor p={} rank: {}/{}",
                key.p,
                p_rank + 1,
                prime_weights.len()
            );
        }
        println!();
    }
}

// ═══════════════════════════════════════════════════════════════
// H6: Quadratic Form at Factor-Multiple Indices
//
// d²_N = 1 - 2bᵀv + vᵀGv. How does the quadratic form change
// when we restrict to indices that are multiples of candidate m?
// ═══════════════════════════════════════════════════════════════

pub fn h6_quadratic_form_probe(keys: &[SemiprimeKey]) {
    println!("  [H6] Quadratic Form Restriction Probe");
    println!("  ──────────────────────────────────────");

    for key in keys.iter().take(3) {
        let m = ((key.p as usize) * 2).min(300).max(20);
        let n = key.n as usize;
        if n > 500_000 {
            continue;
        }

        let mu = arith::mobius_table(m);
        let v = cathedral_utils::mertens::witness_vector(m, &mu);
        let b = arith::b_vector(m - 1);

        // Build Gram matrix
        let dim = m - 1;
        let mut gram_mat = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in i..dim {
                let g = gram::gram_entry_f64(i + 2, j + 2);
                gram_mat[i * dim + j] = g;
                gram_mat[j * dim + i] = g;
            }
        }

        // Full d²
        let d2_full = cathedral_utils::mertens::quadratic_form(&gram_mat, &b, &v, dim);

        // Now test: zero out weight at multiples of candidate d and recompute
        let sieve = arith::sieve_primes(m);
        let mut results: Vec<(usize, f64, f64, bool)> = Vec::new();

        for d in 2..m.min(100) {
            if !sieve[d] {
                continue;
            }

            let mut v_masked = v.clone();
            for i in 0..dim {
                if (i + 2) % d == 0 {
                    v_masked[i] = 0.0;
                }
            }
            let d2_masked = cathedral_utils::mertens::quadratic_form(&gram_mat, &b, &v_masked, dim);
            let delta = (d2_masked - d2_full).abs();
            let is_factor = key.n % d as u64 == 0;
            results.push((d, d2_masked, delta, is_factor));
        }

        // Sort by delta (descending — removing factors should change d² most)
        results.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());

        println!(
            "    N={} = {}×{}, d²_full = {:.8}",
            key.n, key.p, key.q, d2_full
        );
        println!("      Top-10 primes by |Δd²| when their multiples are masked:");
        for (i, (d, d2_m, delta, is_factor)) in results.iter().take(10).enumerate() {
            println!(
                "        #{}: p={:5} |Δd²|={:.6e}  d²_masked={:.8} {}",
                i + 1,
                d,
                delta,
                d2_m,
                if *is_factor { "← FACTOR" } else { "" }
            );
        }

        // Factor rank
        if let Some(rank) = results.iter().position(|(d, _, _, _)| *d == key.p as usize) {
            println!(
                "      Factor p={} rank: {}/{}",
                key.p,
                rank + 1,
                results.len()
            );
        }
        println!();
    }
}

// ═══════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════════

/// Vasyunin cotangent sum: V(m, n) = Σ_{j=1}^{m-1} {j·n/m} · cot(π·j/m)
fn vasyunin_sum(m: u64, n: u64) -> f64 {
    if m <= 1 {
        return 0.0;
    }
    let mut sum = 0.0f64;
    for j in 1..m {
        let frac = ((j * (n % m)) % m) as f64 / m as f64; // {j·n/m}
        let cot = 1.0 / (std::f64::consts::PI * j as f64 / m as f64).tan();
        sum += frac * cot;
    }
    sum
}

/// Find the next prime after `start` that does NOT divide `n`.
fn next_non_factor_prime(start: u64, n: u64) -> u64 {
    let mut p = start + 2;
    loop {
        if is_prime_u64(p) && !n.is_multiple_of(p) {
            return p;
        }
        p += if p.is_multiple_of(2) { 1 } else { 2 };
        if p > start + 1000 {
            return start + 1;
        } // fallback
    }
}

fn is_prime_u64(n: u64) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n.is_multiple_of(2) || n.is_multiple_of(3) {
        return false;
    }
    let mut i = 5u64;
    while i * i <= n {
        if n.is_multiple_of(i) || n.is_multiple_of(i + 2) {
            return false;
        }
        i += 6;
    }
    true
}

/// Percentile of a sorted slice.
fn percentile(data: &[f64], pct: f64) -> f64 {
    if data.is_empty() {
        return 0.0;
    }
    let mut sorted = data.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let idx = ((pct / 100.0) * (sorted.len() - 1) as f64) as usize;
    sorted[idx.min(sorted.len() - 1)]
}
