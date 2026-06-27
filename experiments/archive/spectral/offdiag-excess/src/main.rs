#![allow(unused, dead_code)]
//! Off-Diagonal Excess Experiment
//!
//! Studies the aggregate off-diagonal excess: Σ_{i≠j} (G(i,j) - 1/4)
//! to guide the proof of offdiag_excess_sum_le in Cathedral.
//!
//! Five experiments:
//! 1. Aggregate excess ratio Σ/n for various n
//! 2. Gap-decomposed excess: contribution by gap m = |j-k|
//! 3. L² norm of Σ{k/x} (the variance identity)
//! 4. Per-gap covariance convergence C(m) → C_∞(m)
//! 5. GCD structure analysis

mod gram;

use gram::{fract_integral, gram_entry};
use serde::Serialize;
use std::collections::BTreeMap;

#[derive(Serialize)]
struct ExperimentResults {
    /// Experiment 1: Aggregate excess for each N
    aggregate: Vec<AggregateResult>,
    /// Experiment 2: Gap-decomposed excess
    gap_decomposition: Vec<GapDecomposition>,
    /// Experiment 3: L² variance identity
    variance_identity: Vec<VarianceResult>,
    /// Experiment 4: Per-gap covariance
    gap_covariance: Vec<GapCovarianceResult>,
    /// Experiment 5: GCD contribution analysis
    gcd_analysis: Vec<GcdResult>,
}

#[derive(Serialize)]
struct AggregateResult {
    n: usize,
    total_excess: f64,
    ratio_to_n: f64,
    diagonal_sum: f64,
    offdiag_sum: f64,
    gram_sum: f64,
    basis_sum: f64,
    d_squared_upper: f64,
}

#[derive(Serialize)]
struct GapDecomposition {
    n: usize,
    /// Map from gap m to total excess contributed by pairs at distance m
    by_gap: BTreeMap<usize, f64>,
    /// Cumulative excess up to gap m
    cumulative: BTreeMap<usize, f64>,
    /// Number of pairs at each gap
    pair_count: BTreeMap<usize, usize>,
}

#[derive(Serialize)]
struct VarianceResult {
    n: usize,
    /// ∫₀¹ (Σ_{k=2}^{n+1} {k/x})² dx
    l2_norm_sq: f64,
    /// (∫₀¹ Σ_{k=2}^{n+1} {k/x} dx)²
    l1_sq: f64,
    /// Σᵢ ∫₀¹ {(i+2)/x}² dx = Σᵢ G(i+2,i+2) (variance per term)
    sum_variances: f64,
    /// Σ_{i≠j} (G(i,j) - 1/4) = l2_norm_sq - sum_variances - n(n-1)/4
    excess_from_identity: f64,
    /// Ratio l2_norm_sq / n
    l2_ratio: f64,
}

#[derive(Serialize)]
struct GapCovarianceResult {
    gap: usize,
    /// Per-pair average covariance at this gap for each N
    by_n: Vec<(usize, f64)>,
    /// Extrapolated C_∞(m)
    c_inf_est: f64,
    /// 1/(12m²) for comparison
    theory_approx: f64,
}

#[derive(Serialize)]
struct GcdResult {
    n: usize,
    /// Σ_{i≠j} gcd(i+2,j+2)²/((i+2)(j+2)) — the "Ramanujan sum"
    gcd_sum: f64,
    /// Ratio to n
    gcd_ratio: f64,
    /// Excess from coprime pairs only (gcd=1)
    coprime_excess: f64,
    /// Excess from non-coprime pairs
    noncoprime_excess: f64,
}

fn gcd(a: usize, b: usize) -> usize {
    if b == 0 {
        a
    } else {
        gcd(b, a % b)
    }
}

fn run_aggregate(n: usize) -> AggregateResult {
    // Lean: gramMatrix (n+1) uses Fin n indices,
    // gramMatrix (n+1) i j = gramEntry (i.val+1) (j.val+1)
    // So actual gramEntry indices are 1..=n
    let dim = n;

    let mut diag_sum = 0.0;
    let mut offdiag_sum = 0.0;
    let mut total_excess = 0.0;

    for i in 0..dim {
        let j = i + 1; // gramEntry index: i.val + 1
        diag_sum += gram_entry(j, j);
        for ii in 0..dim {
            if ii == i {
                continue;
            }
            let k = ii + 1;
            let g = gram_entry(j, k);
            offdiag_sum += g;
            total_excess += g - 0.25;
        }
    }

    let gram_sum = diag_sum + offdiag_sum;

    // Basis sum B = Σ ∫₀¹ {k/x} dx for k=1..=n
    // (Lean: basisInnerProd N i = ∫ {(i.val+1)/x} dx, i : Fin(N-1))
    let basis_sum: f64 = (0..dim).map(|i| fract_integral(i + 1)).sum();

    // d² upper bound with constant witness c = 2B/Q (approximately)
    // Actually d² = 1 - B²/Q (from optimal constant)
    let d_sq = if gram_sum > 0.0 {
        1.0 - basis_sum * basis_sum / gram_sum
    } else {
        1.0
    };

    AggregateResult {
        n,
        total_excess,
        ratio_to_n: total_excess / n as f64,
        diagonal_sum: diag_sum,
        offdiag_sum,
        gram_sum,
        basis_sum,
        d_squared_upper: d_sq,
    }
}

fn run_gap_decomposition(n: usize) -> GapDecomposition {
    let dim = n;
    let mut by_gap: BTreeMap<usize, f64> = BTreeMap::new();
    let mut pair_count: BTreeMap<usize, usize> = BTreeMap::new();

    for i in 0..dim {
        let j = i + 1;
        for ii in 0..dim {
            if ii == i {
                continue;
            }
            let k = ii + 1;
            let gap = j.abs_diff(k);
            let excess = gram_entry(j, k) - 0.25;
            *by_gap.entry(gap).or_insert(0.0) += excess;
            *pair_count.entry(gap).or_insert(0) += 1;
        }
    }

    let mut cumulative: BTreeMap<usize, f64> = BTreeMap::new();
    let mut running = 0.0;
    for (&gap, &excess) in &by_gap {
        running += excess;
        cumulative.insert(gap, running);
    }

    GapDecomposition {
        n,
        by_gap,
        cumulative,
        pair_count,
    }
}

fn run_variance_identity(n: usize) -> VarianceResult {
    let dim = n;

    // sum_variances = Σ G(k,k) for k=1..=n
    let sum_variances: f64 = (0..dim).map(|i| gram_entry(i + 1, i + 1)).sum();

    // l2_norm_sq = Σᵢ Σⱼ G(i+1, j+1) = gramSum
    let mut l2_norm_sq = 0.0;
    for i in 0..dim {
        for ii in 0..dim {
            l2_norm_sq += gram_entry(i + 1, ii + 1);
        }
    }

    // l1_sq = (Σ ∫{k/x}dx)²
    let l1: f64 = (0..dim).map(|i| fract_integral(i + 1)).sum();
    let l1_sq = l1 * l1;

    // From variance identity:
    // Σ_{i≠j} G(i,j) = l2_norm_sq - sum_variances
    // Σ_{i≠j} (G(i,j) - 1/4) = (l2_norm_sq - sum_variances) - n(n-1)/4
    let n_pairs = dim * (dim - 1);
    let excess_from_identity = l2_norm_sq - sum_variances - (n_pairs as f64) / 4.0;

    VarianceResult {
        n,
        l2_norm_sq,
        l1_sq,
        sum_variances,
        excess_from_identity,
        l2_ratio: l2_norm_sq / n as f64,
    }
}

fn run_gcd_analysis(n: usize) -> GcdResult {
    let dim = n;
    let mut gcd_sum = 0.0;
    let mut coprime_excess = 0.0;
    let mut noncoprime_excess = 0.0;

    for i in 0..dim {
        let j = i + 1;
        for ii in 0..dim {
            if ii == i {
                continue;
            }
            let k = ii + 1;
            let g = gcd(j, k);
            gcd_sum += (g * g) as f64 / (j as f64 * k as f64);
            let excess = gram_entry(j, k) - 0.25;
            if g == 1 {
                coprime_excess += excess;
            } else {
                noncoprime_excess += excess;
            }
        }
    }

    GcdResult {
        n,
        gcd_sum,
        gcd_ratio: gcd_sum / n as f64,
        coprime_excess,
        noncoprime_excess,
    }
}

fn main() {
    eprintln!("═══════════════════════════════════════════");
    eprintln!("  Off-Diagonal Excess Experiment");
    eprintln!("  Cathedral Spectral RH Project");
    eprintln!("═══════════════════════════════════════════\n");

    let test_sizes = vec![10, 20, 30, 50, 75, 100, 150, 200, 300];
    let gap_sizes = [50, 100, 200];
    let variance_sizes = [10, 20, 50, 100, 200];

    // Experiment 1: Aggregate excess
    eprintln!("▸ Experiment 1: Aggregate excess ratios");
    let aggregate: Vec<AggregateResult> = test_sizes
        .iter()
        .map(|&n| {
            eprint!("  N={:4}... ", n + 1);
            let r = run_aggregate(n);
            eprintln!(
                "excess/n = {:.6}, d² = {:.6}, B = {:.4}, Q = {:.4}",
                r.ratio_to_n, r.d_squared_upper, r.basis_sum, r.gram_sum
            );
            r
        })
        .collect();

    // Experiment 2: Gap decomposition
    eprintln!("\n▸ Experiment 2: Gap decomposition");
    let gap_decomposition: Vec<GapDecomposition> = gap_sizes
        .iter()
        .map(|&n| {
            eprint!("  N={:4}... ", n + 1);
            let r = run_gap_decomposition(n);
            let total: f64 = r.by_gap.values().sum();
            eprintln!("total excess = {:.4}, gaps = {}", total, r.by_gap.len());
            // Print top 10 gaps
            for (&gap, &excess) in r.by_gap.iter().take(8) {
                let count = r.pair_count[&gap];
                eprintln!(
                    "    gap={:3}: excess={:+.6}, pairs={:4}, per_pair={:+.8}",
                    gap,
                    excess,
                    count,
                    excess / count as f64
                );
            }
            r
        })
        .collect();

    // Experiment 3: Variance identity
    eprintln!("\n▸ Experiment 3: L² variance identity");
    let variance_identity: Vec<VarianceResult> = variance_sizes
        .iter()
        .map(|&n| {
            eprint!("  N={:4}... ", n + 1);
            let r = run_variance_identity(n);
            eprintln!(
                "‖Σf‖² = {:.4}, ‖Σf‖²/n = {:.6}, excess = {:.4}",
                r.l2_norm_sq, r.l2_ratio, r.excess_from_identity
            );
            r
        })
        .collect();

    // Experiment 4: Per-gap covariance convergence
    eprintln!("\n▸ Experiment 4: Per-gap covariance convergence");
    let max_gap = 20;
    let cov_sizes = vec![50, 100, 200];
    let mut gap_covariance: Vec<GapCovarianceResult> = Vec::new();
    for gap in 1..=max_gap {
        let mut by_n = Vec::new();
        for &n in &cov_sizes {
            let dim = n;
            if gap >= dim {
                continue;
            }
            let mut total = 0.0;
            let mut count = 0;
            for i in 0..dim {
                let j = i + 1;
                let k_option = if gap <= i { Some(i - gap) } else { None };
                let k_option2 = if i + gap < dim { Some(i + gap) } else { None };
                for k_idx in [k_option, k_option2].iter().flatten() {
                    let k = k_idx + 1;
                    total += gram_entry(j, k) - 0.25;
                    count += 1;
                }
            }
            if count > 0 {
                by_n.push((n, total / count as f64));
            }
        }
        let c_inf_est = if let Some(&(_, last)) = by_n.last() {
            last
        } else {
            0.0
        };
        let theory = 1.0 / (12.0 * (gap as f64) * (gap as f64));
        gap_covariance.push(GapCovarianceResult {
            gap,
            by_n,
            c_inf_est,
            theory_approx: theory,
        });
    }

    eprintln!(
        "  {:>4} {:>12} {:>12} {:>8}",
        "gap", "C_∞(est)", "1/(12m²)", "ratio"
    );
    for gc in &gap_covariance {
        eprintln!(
            "  {:>4} {:>12.8} {:>12.8} {:>8.4}",
            gc.gap,
            gc.c_inf_est,
            gc.theory_approx,
            if gc.theory_approx > 0.0 {
                gc.c_inf_est / gc.theory_approx
            } else {
                0.0
            }
        );
    }

    // Experiment 5: GCD analysis
    eprintln!("\n▸ Experiment 5: GCD structure");
    let gcd_sizes = [50, 100, 200];
    let gcd_analysis: Vec<GcdResult> = gcd_sizes
        .iter()
        .map(|&n| {
            eprint!("  N={:4}... ", n + 1);
            let r = run_gcd_analysis(n);
            eprintln!(
                "gcd_sum/n = {:.6}, coprime_ex = {:.4}, noncoprime_ex = {:.4}",
                r.gcd_ratio, r.coprime_excess, r.noncoprime_excess
            );
            r
        })
        .collect();

    // Write results
    let results = ExperimentResults {
        aggregate,
        gap_decomposition,
        variance_identity,
        gap_covariance,
        gcd_analysis,
    };

    let json = serde_json::to_string_pretty(&results).unwrap();
    let path = "results/offdiag_excess_results.json";
    std::fs::write(path, &json).unwrap();
    eprintln!("\n✅ Results written to {}", path);
}
