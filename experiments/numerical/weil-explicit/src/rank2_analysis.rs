use nalgebra::{DMatrix, DVector, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// RANK-2 COMMUTATOR DEEP ANALYSIS
//
// The PT-symmetry experiment revealed that [G, P] ≈ rank-2 matrix.
// This experiment extracts and characterizes the two dominant singular
// directions of the commutator to understand:
//
// 1. What arithmetic structure do the mixing vectors encode?
// 2. How does v_min relate to the mixing subspace?
// 3. Does the cross-parity block G_eo have low-rank structure?
// 4. Can we identify the rank-2 perturbation with known functions?
//
// Candidate arithmetic functions to test:
// - Liouville λ(k) = (-1)^{Ω(k)}
// - Möbius μ(k)
// - Von Mangoldt Λ(k)
// - Prime indicator 1_{primes}(k)
// - Euler totient φ(k)/k
// - Divisor function d(k)/k
// - Log-weighted Liouville: λ(k)·ln(k)/k
// ══════════════════════════════════════════════════════════════════════

const NPTS: usize = 50_000;

fn frac_part(x: f64) -> f64 { x - x.floor() }

fn big_omega(n: usize) -> u32 {
    if n <= 1 { return 0; }
    let mut count = 0u32;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        while m % p == 0 { count += 1; m /= p; }
        p += 1;
    }
    if m > 1 { count += 1; }
    count
}

fn liouville(n: usize) -> f64 {
    if big_omega(n) % 2 == 0 { 1.0 } else { -1.0 }
}

fn mobius(n: usize) -> f64 {
    if n <= 1 { return 1.0; }
    let mut m = n;
    let mut p = 2;
    let mut factors = 0;
    while p * p <= m {
        if m % p == 0 {
            factors += 1;
            m /= p;
            if m % p == 0 { return 0.0; } // p² | n
        }
        p += 1;
    }
    if m > 1 { factors += 1; }
    if factors % 2 == 0 { 1.0 } else { -1.0 }
}

fn is_prime(n: usize) -> bool {
    if n < 2 { return false; }
    if n == 2 { return true; }
    if n % 2 == 0 { return false; }
    let mut p = 3;
    while p * p <= n {
        if n % p == 0 { return false; }
        p += 2;
    }
    true
}

fn von_mangoldt(n: usize) -> f64 {
    if n <= 1 { return 0.0; }
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            // check if n = p^k
            while m % p == 0 { m /= p; }
            return if m == 1 { (p as f64).ln() } else { 0.0 };
        }
        p += 1;
    }
    // n is prime
    (n as f64).ln()
}

fn euler_totient(n: usize) -> usize {
    if n <= 1 { return 1; }
    let mut result = n;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m % p == 0 {
            while m % p == 0 { m /= p; }
            result -= result / p;
        }
        p += 1;
    }
    if m > 1 { result -= result / m; }
    result
}

fn num_divisors(n: usize) -> usize {
    if n <= 1 { return 1; }
    let mut count = 1;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        let mut e = 0;
        while m % p == 0 { e += 1; m /= p; }
        count *= e + 1;
        p += 1;
    }
    if m > 1 { count *= 2; }
    count
}

fn gram_entry(j: usize, k: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / NPTS as f64;
    (0..NPTS).map(|i| {
        let x = (i as f64 + 0.5) * dx;
        frac_part(jf / x) * frac_part(kf / x)
    }).sum::<f64>() * dx
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

fn build_parity(n: usize) -> DMatrix<f64> {
    let dim = n - 1;
    let mut p = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        p[(i, i)] = liouville(i + 2);
    }
    p
}

fn correlation(a: &[f64], b: &[f64]) -> f64 {
    let n = a.len() as f64;
    let ma: f64 = a.iter().sum::<f64>() / n;
    let mb: f64 = b.iter().sum::<f64>() / n;
    let cov: f64 = a.iter().zip(b).map(|(x, y)| (x - ma) * (y - mb)).sum();
    let va: f64 = a.iter().map(|x| (x - ma).powi(2)).sum();
    let vb: f64 = b.iter().map(|y| (y - mb).powi(2)).sum();
    if va < 1e-30 || vb < 1e-30 { return 0.0; }
    cov / (va.sqrt() * vb.sqrt())
}

fn main() {
    println!("══════════════════════════════════════════════════════════════");
    println!("  RANK-2 COMMUTATOR DEEP ANALYSIS");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    let ns = vec![100, 200, 300];

    for &n in &ns {
        let dim = n - 1;
        println!("╔══════════════════════════════════════════════════════════╗");
        println!("║  N = {:4}  (dim = {:3})                                 ║", n, dim);
        println!("╚══════════════════════════════════════════════════════════╝");

        let g = build_gram(n);
        let p = build_parity(n);

        // ═══════════ COMMUTATOR SVD ═══════════
        let comm = &g * &p - &p * &g;

        // [G,P] is antisymmetric, so we compute SVD via [G,P]ᵀ[G,P]
        let ctc = comm.transpose() * &comm;
        let eig_ctc = SymmetricEigen::new(ctc.clone());

        // Sort by singular value (descending)
        let mut sv_indices: Vec<usize> = (0..dim).collect();
        sv_indices.sort_by(|&a, &b|
            eig_ctc.eigenvalues[b].partial_cmp(&eig_ctc.eigenvalues[a]).unwrap());

        let sigma1 = eig_ctc.eigenvalues[sv_indices[0]].max(0.0).sqrt();
        let sigma3 = eig_ctc.eigenvalues[sv_indices[2]].max(0.0).sqrt();

        println!("  ── SINGULAR VALUE SPECTRUM OF [G, P] ──");
        println!("     {:>4} {:>14} {:>10}", "rank", "σ_k", "σ_k/σ_1");
        for i in 0..10.min(dim) {
            let s = eig_ctc.eigenvalues[sv_indices[i]].max(0.0).sqrt();
            println!("     {:4} {:14.8} {:10.6}", i + 1, s, s / sigma1);
        }
        println!("     ...");
        // Show the last few
        for i in (dim - 3)..dim {
            let s = eig_ctc.eigenvalues[sv_indices[i]].max(0.0).sqrt();
            println!("     {:4} {:14.8} {:10.6}", i + 1, s, s / sigma1);
        }
        println!("     Gap ratio σ₁/σ₃ = {:.1}", sigma1 / sigma3);
        println!();

        // ═══════════ EXTRACT DOMINANT MIXING VECTORS ═══════════
        // Right singular vectors of [G,P] = eigenvectors of [G,P]ᵀ[G,P]
        println!("  ── DOMINANT MIXING VECTORS (right singular vectors) ──");

        // Get right singular vectors v₁, v₂ (from CᵀC eigenvectors)
        let v1: Vec<f64> = (0..dim).map(|i| eig_ctc.eigenvectors[(i, sv_indices[0])]).collect();
        let v2: Vec<f64> = (0..dim).map(|i| eig_ctc.eigenvectors[(i, sv_indices[1])]).collect();

        // Also get left singular vectors u₁ = C·v₁/σ₁
        let v1_dv = DVector::from_column_slice(&v1);
        let v2_dv = DVector::from_column_slice(&v2);
        let u1_dv = &comm * &v1_dv / sigma1;
        let u2_dv = &comm * &v2_dv / sigma1;
        let u1: Vec<f64> = u1_dv.iter().copied().collect();
        let u2: Vec<f64> = u2_dv.iter().copied().collect();

        // Build candidate arithmetic vectors
        let mut candidates: Vec<(&str, Vec<f64>)> = Vec::new();

        // 1. Liouville: λ(k)
        candidates.push(("λ(k)", (0..dim).map(|i| liouville(i + 2)).collect()));

        // 2. Weighted Liouville: λ(k)/k
        candidates.push(("λ(k)/k", (0..dim).map(|i| {
            liouville(i + 2) / (i + 2) as f64
        }).collect()));

        // 3. Log-weighted Liouville: λ(k)·ln(k)/k (the v_min template)
        candidates.push(("λ(k)ln(k)/k", (0..dim).map(|i| {
            let k = (i + 2) as f64;
            liouville(i + 2) * k.ln() / k
        }).collect()));

        // 4. Möbius: μ(k)
        candidates.push(("μ(k)", (0..dim).map(|i| mobius(i + 2)).collect()));

        // 5. Möbius weighted: μ(k)/k
        candidates.push(("μ(k)/k", (0..dim).map(|i| {
            mobius(i + 2) / (i + 2) as f64
        }).collect()));

        // 6. Prime indicator
        candidates.push(("1_prime(k)", (0..dim).map(|i| {
            if is_prime(i + 2) { 1.0 } else { 0.0 }
        }).collect()));

        // 7. Von Mangoldt
        candidates.push(("Λ(k)", (0..dim).map(|i| von_mangoldt(i + 2)).collect()));

        // 8. φ(k)/k
        candidates.push(("φ(k)/k", (0..dim).map(|i| {
            euler_totient(i + 2) as f64 / (i + 2) as f64
        }).collect()));

        // 9. d(k)/k (divisor function normalized)
        candidates.push(("d(k)/k", (0..dim).map(|i| {
            num_divisors(i + 2) as f64 / (i + 2) as f64
        }).collect()));

        // 10. Ω(k) (number of prime factors with multiplicity)
        candidates.push(("Ω(k)", (0..dim).map(|i| big_omega(i + 2) as f64).collect()));

        // 11. 1/k (pure decay)
        candidates.push(("1/k", (0..dim).map(|i| 1.0 / (i + 2) as f64).collect()));

        // 12. ln(k)/k
        candidates.push(("ln(k)/k", (0..dim).map(|i| {
            let k = (i + 2) as f64;
            k.ln() / k
        }).collect()));

        // 13. Constant vector (baseline)
        candidates.push(("constant", vec![1.0; dim]));

        println!("     Correlations with arithmetic functions:");
        println!("     {:>15} {:>10} {:>10} {:>10} {:>10}",
            "function", "ρ(v₁)", "ρ(v₂)", "ρ(u₁)", "ρ(u₂)");
        println!("     {}", "-".repeat(55));

        for (name, vec) in &candidates {
            let rv1 = correlation(&v1, vec);
            let rv2 = correlation(&v2, vec);
            let ru1 = correlation(&u1, vec);
            let ru2 = correlation(&u2, vec);
            let max_abs = rv1.abs().max(rv2.abs()).max(ru1.abs()).max(ru2.abs());
            let marker = if max_abs > 0.5 { " ◀━━ STRONG" }
                        else if max_abs > 0.3 { " ◀━ moderate" }
                        else { "" };
            println!("     {:>15} {:10.6} {:10.6} {:10.6} {:10.6}{}",
                name, rv1, rv2, ru1, ru2, marker);
        }
        println!();

        // ═══════════ MIXING VECTOR ENTRIES ═══════════
        println!("  ── TOP ENTRIES OF v₁ (dominant mixing direction) ──");
        let mut v1_abs: Vec<(usize, f64, f64)> = v1.iter().enumerate()
            .map(|(i, &x)| (i + 2, x, x.abs()))
            .collect();
        v1_abs.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());

        println!("     {:>5} {:>10} {:>10} {:>6} {:>6} {:>6}",
            "k", "v₁[k]", "|v₁[k]|", "λ(k)", "μ(k)", "prime?");
        for i in 0..20.min(dim) {
            let (k, val, _) = v1_abs[i];
            println!("     {:5} {:10.6} {:10.6} {:6.0} {:6.0} {:>6}",
                k, val, val.abs(), liouville(k), mobius(k),
                if is_prime(k) { "yes" } else { "" });
        }
        println!();

        // ═══════════ V_MIN PROJECTION ONTO MIXING SUBSPACE ═══════════
        println!("  ── v_min PROJECTION ONTO MIXING SUBSPACE ──");

        let eig_g = SymmetricEigen::new(g.clone());
        let mut min_idx = 0;
        let mut min_val = f64::INFINITY;
        for i in 0..dim {
            if eig_g.eigenvalues[i] < min_val {
                min_val = eig_g.eigenvalues[i];
                min_idx = i;
            }
        }
        let vmin: DVector<f64> = eig_g.eigenvectors.column(min_idx).into();
        let vmin_unit = &vmin / vmin.norm();

        // Project v_min onto span(v₁, v₂)
        let proj1 = vmin_unit.dot(&v1_dv);
        let proj2 = vmin_unit.dot(&v2_dv);
        let proj_norm = (proj1 * proj1 + proj2 * proj2).sqrt();

        println!("     λ_min = {:.8}", min_val);
        println!("     ⟨v_min, v₁⟩ = {:.6}", proj1);
        println!("     ⟨v_min, v₂⟩ = {:.6}", proj2);
        println!("     |proj onto mixing subspace| = {:.6}  ({:.1}%)",
            proj_norm, proj_norm * 100.0);
        println!("     |proj onto complement|      = {:.6}  ({:.1}%)",
            (1.0 - proj_norm * proj_norm).max(0.0).sqrt(),
            (1.0 - proj_norm * proj_norm).max(0.0).sqrt() * 100.0);
        println!();

        // ═══════════ CROSS-PARITY BLOCK SVD ═══════════
        println!("  ── CROSS-PARITY BLOCK G_eo SVD ──");
        let even_idx: Vec<usize> = (0..dim).filter(|&i| liouville(i + 2) > 0.0).collect();
        let odd_idx: Vec<usize> = (0..dim).filter(|&i| liouville(i + 2) < 0.0).collect();

        let n_even = even_idx.len();
        let n_odd = odd_idx.len();

        // Build the cross-parity block
        let mut g_eo = DMatrix::zeros(n_even, n_odd);
        for (ii, &i) in even_idx.iter().enumerate() {
            for (jj, &j) in odd_idx.iter().enumerate() {
                g_eo[(ii, jj)] = g[(i, j)];
            }
        }

        // SVD via eigendecomposition of G_eo^T G_eo
        let gte = g_eo.transpose() * &g_eo;
        let eig_gte = SymmetricEigen::new(gte);
        let mut sv_eo: Vec<f64> = eig_gte.eigenvalues.iter()
            .map(|v| v.max(0.0).sqrt())
            .collect();
        sv_eo.sort_by(|a, b| b.partial_cmp(a).unwrap());

        println!("     G_eo dimensions: {} × {}", n_even, n_odd);
        println!("     10 largest singular values:");
        for i in 0..10.min(sv_eo.len()) {
            let ratio = if i > 0 { sv_eo[0] / sv_eo[i] } else { 1.0 };
            println!("       σ_{} = {:12.8}  (σ₁/σ_{} = {:.2})", i + 1, sv_eo[i], i + 1, ratio);
        }

        // Effective rank at various thresholds
        let g_eo_norm = sv_eo[0];
        for &thresh in &[0.01, 0.001, 0.0001] {
            let rank = sv_eo.iter().filter(|&&s| s > thresh * g_eo_norm).count();
            println!("     Effective rank (threshold {:.0e}·σ₁): {}/{}",
                thresh, rank, sv_eo.len().min(n_even));
        }
        println!();

        // ═══════════ RANK-2 REMOVED ANALYSIS ═══════════
        println!("  ── SPECTRUM AFTER REMOVING RANK-2 COMPONENT ──");
        // Reconstruct [G,P] without top 2 singular values
        // G_corrected = G - rank2_piece/2... actually we want to
        // check if removing the rank-2 from the commutator makes G
        // more block-diagonal.
        //
        // Better: construct G_corrected such that [G_corrected, P] has
        // the top 2 singular values removed.
        //
        // [G,P] = Σ σᵢ uᵢ vᵢᵀ
        // [G,P]_corrected = [G,P] - σ₁u₁v₁ᵀ - σ₂u₂v₂ᵀ
        //
        // If G_c = G - ΔG such that [G_c,P] = [G,P] - rank2:
        // [G_c, P] = [G - ΔG, P] = [G,P] - [ΔG, P]
        // We need [ΔG, P] = σ₁u₁v₁ᵀ + σ₂u₂v₂ᵀ
        // This means ΔG·P - P·ΔG = rank2
        // This is a Sylvester equation, harder to solve directly.
        //
        // Simpler: just report the residual commutator norm
        let sigma2 = eig_ctc.eigenvalues[sv_indices[1]].max(0.0).sqrt();
        let residual_sq: f64 = (2..dim).map(|i|
            eig_ctc.eigenvalues[sv_indices[i]].max(0.0)
        ).sum();
        let residual_norm = residual_sq.sqrt();
        let g_norm = g.iter().map(|x| x * x).sum::<f64>().sqrt();

        println!("     Full ‖[G,P]‖  = {:.6}", (sigma1*sigma1 + sigma2*sigma2 + residual_sq).sqrt());
        println!("     Rank-2 ‖·‖    = {:.6}  ({:.1}% of total)",
            (sigma1*sigma1 + sigma2*sigma2).sqrt(),
            (sigma1*sigma1 + sigma2*sigma2) / (sigma1*sigma1 + sigma2*sigma2 + residual_sq) * 100.0);
        println!("     Residual ‖·‖  = {:.6}  ({:.1}% of total)",
            residual_norm,
            residual_sq / (sigma1*sigma1 + sigma2*sigma2 + residual_sq) * 100.0);
        println!("     Residual/‖G‖  = {:.6}  ← effective commutator after rank-2 removal",
            residual_norm / g_norm);
        println!();

        // ═══════════ LIOUVILLE-WEIGHTED GRAM ANALYSIS ═══════════
        println!("  ── LIOUVILLE-WEIGHTED GRAM ENTRY ANALYSIS ──");
        // Study G[j,k] as a function of λ(j)·λ(k)
        // (same parity: λ(j)λ(k) = +1, different: = -1)
        let mut same_parity_entries = Vec::new();
        let mut diff_parity_entries = Vec::new();
        for i in 0..dim {
            for j in 0..dim {
                if i == j { continue; }
                let li = liouville(i + 2);
                let lj = liouville(j + 2);
                if li * lj > 0.0 {
                    same_parity_entries.push(g[(i, j)]);
                } else {
                    diff_parity_entries.push(g[(i, j)]);
                }
            }
        }

        let same_mean: f64 = same_parity_entries.iter().sum::<f64>() / same_parity_entries.len() as f64;
        let diff_mean: f64 = diff_parity_entries.iter().sum::<f64>() / diff_parity_entries.len() as f64;
        let same_var: f64 = same_parity_entries.iter().map(|x| (x - same_mean).powi(2)).sum::<f64>()
            / same_parity_entries.len() as f64;
        let diff_var: f64 = diff_parity_entries.iter().map(|x| (x - diff_mean).powi(2)).sum::<f64>()
            / diff_parity_entries.len() as f64;

        println!("     Same Liouville parity entries:  mean = {:.8}, std = {:.8}, count = {}",
            same_mean, same_var.sqrt(), same_parity_entries.len());
        println!("     Diff Liouville parity entries:  mean = {:.8}, std = {:.8}, count = {}",
            diff_mean, diff_var.sqrt(), diff_parity_entries.len());
        println!("     Mean difference (same - diff):  {:.8}", same_mean - diff_mean);
        println!("     → {}", if (same_mean - diff_mean).abs() > same_var.sqrt() * 0.1 {
            "Gram entries ARE sensitive to Liouville parity ✨"
        } else {
            "Gram entries show no parity bias"
        });

        println!();
    }

    // ═══════════ FINAL SUMMARY ═══════════
    println!("══════════════════════════════════════════════════════════════");
    println!("  CONCLUSIONS");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!("  1. The rank-2 commutator structure tells us:");
    println!("     - The Gram matrix has an approximate Liouville parity");
    println!("     - Two specific directions break this parity");
    println!("     - These directions encode how arithmetic enters the spectrum");
    println!();
    println!("  2. If the mixing vectors correlate with specific L-functions,");
    println!("     this connects the spectral gap directly to zeta zeros.");
    println!();
    println!("  3. The cross-parity block G_eo may have its own low-rank");
    println!("     structure revealing the mechanism of alignment_decay.");
    println!();
}
