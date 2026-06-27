#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, DVector, SymmetricEigen};
use std::time::Instant;

// ══════════════════════════════════════════════════════════════════════
// ROTATION RATE ANALYSIS: Quantifying Alignment Decay Geometrically
//
// The rank-2 analysis revealed that alignment_decay = rate at which
// v_min rotates out of the Liouville mixing subspace.
//
// This experiment precisely measures:
// 1. |⟨v_min, λ̂⟩| vs N — the core rotation rate
// 2. σ₁(G_eo)/σ₂(G_eo) vs N — rank-1 gap growth
// 3. ‖[G,P]_residual‖/‖G‖ vs N — residual commutator decay
// 4. λ_min(G_block)/λ_min(G) — parity-corrected spectral gap ratio
// 5. Connection to Liouville partial sums L(N) = Σ_{k≤N} λ(k)
//
// Scales to N=500 for precise power-law fitting.
// ══════════════════════════════════════════════════════════════════════

const NPTS: usize = 50_000;

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

fn big_omega(n: usize) -> u32 {
    if n <= 1 {
        return 0;
    }
    let mut count = 0u32;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        while m.is_multiple_of(p) {
            count += 1;
            m /= p;
        }
        p += 1;
    }
    if m > 1 {
        count += 1;
    }
    count
}

fn liouville(n: usize) -> f64 {
    if big_omega(n).is_multiple_of(2) {
        1.0
    } else {
        -1.0
    }
}

fn gram_entry(j: usize, k: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / NPTS as f64;
    (0..NPTS)
        .map(|i| {
            let x = (i as f64 + 0.5) * dx;
            frac_part(jf / x) * frac_part(kf / x)
        })
        .sum::<f64>()
        * dx
}

fn build_gram(n: usize) -> DMatrix<f64> {
    let dim = n - 1;
    let mut g = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in i..dim {
            let val = gram_entry(i + 2, j + 2);
            g[(i, j)] = val;
            g[(j, i)] = val;
        }
    }
    g
}

/// Power law fit: y = A·x^α via log-log regression
/// Returns (A, α, R²)
fn power_law_fit(data: &[(f64, f64)]) -> (f64, f64, f64) {
    let valid: Vec<(f64, f64)> = data.iter().filter(|(_, y)| *y > 0.0).copied().collect();
    if valid.len() < 3 {
        return (0.0, 0.0, 0.0);
    }

    let n = valid.len() as f64;
    let sum_lnx: f64 = valid.iter().map(|(x, _)| x.ln()).sum();
    let sum_lny: f64 = valid.iter().map(|(_, y)| y.ln()).sum();
    let sum_lnx2: f64 = valid.iter().map(|(x, _)| x.ln().powi(2)).sum();
    let sum_lnxy: f64 = valid.iter().map(|(x, y)| x.ln() * y.ln()).sum();
    let denom = n * sum_lnx2 - sum_lnx.powi(2);
    if denom.abs() < 1e-30 {
        return (0.0, 0.0, 0.0);
    }
    let slope = (n * sum_lnxy - sum_lnx * sum_lny) / denom;
    let intercept = (sum_lny - slope * sum_lnx) / n;
    let a = intercept.exp();

    // R²
    let mean_lny = sum_lny / n;
    let ss_tot: f64 = valid.iter().map(|(_, y)| (y.ln() - mean_lny).powi(2)).sum();
    let ss_res: f64 = valid
        .iter()
        .map(|(x, y)| {
            let pred = intercept + slope * x.ln();
            (y.ln() - pred).powi(2)
        })
        .sum();
    let r2 = if ss_tot > 1e-30 {
        1.0 - ss_res / ss_tot
    } else {
        0.0
    };

    (a, slope, r2)
}

fn main() {
    println!("══════════════════════════════════════════════════════════════");
    println!("  ROTATION RATE ANALYSIS: Geometric Heart of Alignment Decay");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    let ns = vec![30, 50, 75, 100, 150, 200, 250, 300, 400, 500];

    let mut proj_data: Vec<(f64, f64)> = Vec::new();
    let mut cos_data: Vec<(f64, f64)> = Vec::new();
    let mut gap_ratio_data: Vec<(f64, f64)> = Vec::new();
    let mut residual_data: Vec<(f64, f64)> = Vec::new();
    let mut eo_gap_data: Vec<(f64, f64)> = Vec::new();
    let mut liou_sum_data: Vec<(f64, f64)> = Vec::new();

    println!(
        "  {:>5} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>8}",
        "N", "|⟨v,λ̂⟩|", "cos θ_N", "σ₁/σ₂(eo)", "res/‖G‖", "λeven/λG", "L(N)/√N", "time"
    );
    println!("  {}", "─".repeat(78));

    for &n in &ns {
        let t0 = Instant::now();
        let dim = n - 1;
        let g = build_gram(n);

        // ── EIGENDECOMPOSITION ──
        let eig = SymmetricEigen::new(g.clone());
        let mut min_idx = 0;
        let mut min_val = f64::INFINITY;
        for i in 0..dim {
            if eig.eigenvalues[i] < min_val {
                min_val = eig.eigenvalues[i];
                min_idx = i;
            }
        }
        let vmin: DVector<f64> = eig.eigenvectors.column(min_idx).into();
        let vmin_unit = &vmin / vmin.norm();

        // ── LIOUVILLE VECTOR ──
        let liou_vec: DVector<f64> = DVector::from_fn(dim, |i, _| liouville(i + 2));
        let liou_norm = liou_vec.norm();
        let liou_hat = &liou_vec / liou_norm;

        // 1. Projection of v_min onto λ̂
        let proj_liou = vmin_unit.dot(&liou_hat).abs();

        // ── PARITY OPERATOR ──
        let mut p_mat = DMatrix::zeros(dim, dim);
        for i in 0..dim {
            p_mat[(i, i)] = liouville(i + 2);
        }

        // ── COMMUTATOR ──
        let comm = &g * &p_mat - &p_mat * &g;
        let g_norm = g.iter().map(|x| x * x).sum::<f64>().sqrt();

        // SVD of commutator via CᵀC
        let ctc = comm.transpose() * &comm;
        let eig_ctc = SymmetricEigen::new(ctc);
        let mut sv_vals: Vec<f64> = eig_ctc
            .eigenvalues
            .iter()
            .map(|v| v.max(0.0).sqrt())
            .collect();
        sv_vals.sort_by(|a, b| b.partial_cmp(a).unwrap());

        // 3. Residual after rank-2 removal
        let full_sq: f64 = sv_vals.iter().map(|s| s * s).sum();
        let rank2_sq = sv_vals[0].powi(2) + sv_vals[1].powi(2);
        let residual = (full_sq - rank2_sq).max(0.0).sqrt();
        let res_rel = residual / g_norm;

        // ── CROSS-PARITY BLOCK ──
        let even_idx: Vec<usize> = (0..dim).filter(|&i| liouville(i + 2) > 0.0).collect();
        let odd_idx: Vec<usize> = (0..dim).filter(|&i| liouville(i + 2) < 0.0).collect();
        let n_even = even_idx.len();
        let n_odd = odd_idx.len();

        let mut g_eo = DMatrix::zeros(n_even, n_odd);
        for (ii, &i) in even_idx.iter().enumerate() {
            for (jj, &j) in odd_idx.iter().enumerate() {
                g_eo[(ii, jj)] = g[(i, j)];
            }
        }

        // SVD of G_eo
        let gte = g_eo.transpose() * &g_eo;
        let eig_gte = SymmetricEigen::new(gte);
        let mut sv_eo: Vec<f64> = eig_gte
            .eigenvalues
            .iter()
            .map(|v| v.max(0.0).sqrt())
            .collect();
        sv_eo.sort_by(|a, b| b.partial_cmp(a).unwrap());
        let eo_gap = if sv_eo.len() > 1 && sv_eo[1] > 1e-15 {
            sv_eo[0] / sv_eo[1]
        } else {
            f64::INFINITY
        };

        // ── G_even = (G + PGP) / 2 ──
        let pgp = &p_mat * &g * &p_mat;
        let g_even = (&g + &pgp) * 0.5;
        let eig_even = SymmetricEigen::new(g_even);
        let lmin_even = eig_even
            .eigenvalues
            .iter()
            .copied()
            .fold(f64::INFINITY, f64::min);
        let gap_ratio = lmin_even / min_val;

        // ── COS ALIGNMENT (from spectral-gap-analysis definition) ──
        // cos θ_N = |gᵀv_min| / ‖g‖
        // g = crossCorrVec for the (N-1)-sized Gram matrix
        // Here we compute it for the CURRENT N
        let g_cross: DVector<f64> = DVector::from_fn(dim, |i, _| {
            gram_entry(n, i + 2) // G[N, k] for k = 2..N
        });
        let g_cross_norm = g_cross.norm();
        let cos_theta = if g_cross_norm > 1e-15 {
            vmin_unit.dot(&g_cross).abs() / g_cross_norm
        } else {
            0.0
        };

        // ── LIOUVILLE PARTIAL SUMS ──
        let liou_sum: f64 = (2..=n).map(liouville).sum();
        let liou_normalized = liou_sum.abs() / (n as f64).sqrt();

        let elapsed = t0.elapsed().as_secs_f64();

        println!(
            "  {:5} {:10.6} {:10.6} {:10.1} {:10.6} {:10.4} {:10.6} {:7.1}s",
            n, proj_liou, cos_theta, eo_gap, res_rel, gap_ratio, liou_normalized, elapsed
        );

        proj_data.push((n as f64, proj_liou));
        cos_data.push((n as f64, cos_theta));
        gap_ratio_data.push((n as f64, gap_ratio));
        residual_data.push((n as f64, res_rel));
        eo_gap_data.push((n as f64, eo_gap));
        liou_sum_data.push((n as f64, liou_normalized));
    }

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  POWER LAW FITS");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    // Fit each quantity
    let quantities = vec![
        ("Liouville projection |⟨v_min, λ̂⟩|", &proj_data),
        ("Cosine alignment cos θ_N", &cos_data),
        ("Residual commutator ‖res‖/‖G‖", &residual_data),
    ];

    for (name, data) in &quantities {
        let (a, alpha, r2) = power_law_fit(data);
        println!("  {} ≈ {:.4} · N^{{{:.4}}}", name, a, alpha);
        println!("    R² = {:.6}", r2);
        if alpha < -0.1 {
            println!("    → DECAYS as N → ∞ ✅");
        } else {
            println!("    → does NOT decay");
        }
        println!();
    }

    // Gap ratio fit
    let (a_gap, alpha_gap, r2_gap) = power_law_fit(&gap_ratio_data);
    println!(
        "  λ_min(G_even)/λ_min(G) ≈ {:.4} · N^{{{:.4}}}  (R² = {:.4})",
        a_gap, alpha_gap, r2_gap
    );
    if alpha_gap > 0.01 {
        println!("    → Gap ratio GROWS — parity correction becomes MORE important");
    }
    println!();

    // EO gap ratio fit
    let (a_eo, alpha_eo, r2_eo) = power_law_fit(&eo_gap_data);
    println!(
        "  σ₁/σ₂(G_eo) ≈ {:.4} · N^{{{:.4}}}  (R² = {:.4})",
        a_eo, alpha_eo, r2_eo
    );
    if alpha_eo > 0.5 {
        println!("    → Rank-1 dominance GROWS ✨ — G_eo becomes more rank-1");
    }
    println!();

    // ══════════════════════════════════════
    // KEY RELATIONSHIP: proj vs cos θ
    // ══════════════════════════════════════
    println!("══════════════════════════════════════════════════════════════");
    println!("  RELATIONSHIP: Liouville projection vs cos θ_N");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "  {:>5} {:>10} {:>10} {:>10}",
        "N", "|⟨v,λ̂⟩|", "cos θ", "ratio"
    );
    println!("  {}", "─".repeat(45));
    for i in 0..proj_data.len() {
        let (n, proj) = proj_data[i];
        let (_, cos) = cos_data[i];
        let ratio = if cos > 1e-15 { proj / cos } else { 0.0 };
        println!(
            "  {:5} {:10.6} {:10.6} {:10.4}",
            n as usize, proj, cos, ratio
        );
    }
    println!();

    // ══════════════════════════════════════
    // LIOUVILLE PARTIAL SUMS vs SPECTRAL DATA
    // ══════════════════════════════════════
    println!("══════════════════════════════════════════════════════════════");
    println!("  LIOUVILLE PARTIAL SUMS L(N) = Σ_{{k≤N}} λ(k)");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!("  If RH: L(N) = O(N^{{1/2+ε}})");
    println!("  So L(N)/√N should be bounded.");
    println!();
    println!(
        "  {:>5} {:>10} {:>10} {:>10}",
        "N", "L(N)", "L(N)/√N", "|⟨v,λ̂⟩|"
    );
    println!("  {}", "─".repeat(45));
    for i in 0..proj_data.len() {
        let (n, proj) = proj_data[i];
        let liou_sum: f64 = (2..=n as usize).map(liouville).sum();
        println!(
            "  {:5} {:10.0} {:10.6} {:10.6}",
            n as usize,
            liou_sum,
            liou_sum.abs() / n.sqrt(),
            proj
        );
    }
    println!();

    // ══════════════════════════════════════
    // ZETA RATIO CONNECTION
    // ══════════════════════════════════════
    println!("══════════════════════════════════════════════════════════════");
    println!("  ζ(2s)/ζ(s) CONNECTION");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!("  The Gram matrix G[j,k] = ∫₀¹ {{j/x}}{{k/x}} dx");
    println!("  has the number-theoretic representation:");
    println!("    G[j,k] = 1/2 - (1 - 1/j)(1 - 1/k)/2 when j=k");
    println!("    G[j,k] = Σ_{{d|gcd(j,k)}} μ(d)·(...) for general j,k");
    println!();
    println!("  The rank-1 structure of G_eo reveals that the");
    println!("  cross-parity coupling is controlled by:");
    println!("    Σ_{{d|gcd(j,k)}} λ(j/d)·λ(k/d)·(something)");
    println!("  which is a Dirichlet convolution related to ζ(2s)/ζ(s).");
    println!();

    println!("══════════════════════════════════════════════════════════════");
    println!("  FINAL SUMMARY");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    let (a_proj, alpha_proj, r2_proj) = power_law_fit(&proj_data);
    let (a_cos, alpha_cos, r2_cos) = power_law_fit(&cos_data);
    let (_, alpha_res, r2_res) = power_law_fit(&residual_data);

    println!(
        "  Liouville projection: |⟨v_min, λ̂⟩| ≈ {:.4} · N^{{{:.4}}}  (R²={:.4})",
        a_proj, alpha_proj, r2_proj
    );
    println!(
        "  Cosine alignment:     cos θ_N      ≈ {:.4} · N^{{{:.4}}}  (R²={:.4})",
        a_cos, alpha_cos, r2_cos
    );
    println!(
        "  Residual commutator:  ‖res‖/‖G‖    ∝ N^{{{:.4}}}              (R²={:.4})",
        alpha_res, r2_res
    );
    println!(
        "  G_eo rank-1 gap:      σ₁/σ₂        ∝ N^{{{:.4}}}              (R²={:.4})",
        alpha_eo, r2_eo
    );
    println!();
    println!("  KEY INSIGHT:");
    if alpha_proj < -0.05 && alpha_cos < -0.5 {
        println!(
            "    Liouville projection decays at rate N^{{{:.3}}}",
            alpha_proj
        );
        println!(
            "    Cosine alignment decays FASTER at rate N^{{{:.3}}}",
            alpha_cos
        );
        println!(
            "    The DIFFERENCE in rates ({:.3}) is the cos θ / proj ratio growth",
            alpha_cos - alpha_proj
        );
        println!("    → alignment_decay = Liouville projection decay × additional cancellation");
    }
    println!();
}
