use nalgebra::{DMatrix, DVector, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// PT-SYMMETRY INVESTIGATION: THE LIOUVILLE OPERATOR AND THE GRAM MATRIX
//
// Key question: The minimum eigenvector v_min of G_N satisfies
//   v_min[k] ≈ -C · ln(k) · λ(k) / k
// where λ(k) = (-1)^{Ω(k)} is the Liouville function.
//
// This is deeply surprising. WHY does the Gram matrix "know about"
// the Liouville function? We investigate this through the lens
// of PT-symmetry (parity-time symmetry):
//
// Define the PARITY OPERATOR P = diag(λ(2), λ(3), ..., λ(N))
//
// Questions:
// 1. Does G commute with P?  (If [G,P] ≈ 0, eigenvectors have parity)
// 2. What is the spectrum of PGP? (parity-transformed Gram matrix)
// 3. Does the commutator [G,P] have special structure?
// 4. Can we decompose G = G_even + G_odd under P?
// 5. Do higher eigenvectors also have Liouville structure?
// 6. What about the "time" operator T (pointwise complex conjugation)?
//
// Physical analogy: In quantum mechanics, if a Hamiltonian has
// PT-symmetry (even if it's not Hermitian), its spectrum is real.
// The Gram matrix IS Hermitian, but the Liouville parity may
// reveal why it has such structured eigenvectors.
// ══════════════════════════════════════════════════════════════════════

const NPTS: usize = 50_000;

fn frac_part(x: f64) -> f64 { x - x.floor() }

/// Compute Ω(n) = number of prime factors with multiplicity
fn big_omega(n: usize) -> u32 {
    if n <= 1 { return 0; }
    let mut count = 0u32;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        while m % p == 0 {
            count += 1;
            m /= p;
        }
        p += 1;
    }
    if m > 1 { count += 1; }
    count
}

/// Liouville function: λ(n) = (-1)^{Ω(n)}
fn liouville(n: usize) -> f64 {
    if big_omega(n) % 2 == 0 { 1.0 } else { -1.0 }
}

/// Gram matrix entry: G[j,k] = ∫₀¹ {j/x}{k/x} dx
fn gram_entry(j: usize, k: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / NPTS as f64;
    (0..NPTS).map(|i| {
        let x = (i as f64 + 0.5) * dx;
        frac_part(jf / x) * frac_part(kf / x)
    }).sum::<f64>() * dx
}

/// Build the (N-1)×(N-1) Gram matrix for basis {2/x, ..., N/x}
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

/// Build the Liouville parity operator P = diag(λ(2), λ(3), ..., λ(N))
fn build_parity(n: usize) -> DMatrix<f64> {
    let dim = n - 1;
    let mut p = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        p[(i, i)] = liouville(i + 2);
    }
    p
}

/// Frobenius norm of a matrix
fn frobenius_norm(m: &DMatrix<f64>) -> f64 {
    m.iter().map(|x| x * x).sum::<f64>().sqrt()
}

/// Correlation between two vectors
fn correlation(a: &DVector<f64>, b: &DVector<f64>) -> f64 {
    let n = a.len() as f64;
    let mean_a = a.sum() / n;
    let mean_b = b.sum() / n;
    let mut cov = 0.0;
    let mut var_a = 0.0;
    let mut var_b = 0.0;
    for i in 0..a.len() {
        let da = a[i] - mean_a;
        let db = b[i] - mean_b;
        cov += da * db;
        var_a += da * da;
        var_b += db * db;
    }
    if var_a < 1e-30 || var_b < 1e-30 { return 0.0; }
    cov / (var_a.sqrt() * var_b.sqrt())
}

fn main() {
    println!("══════════════════════════════════════════════════════════════");
    println!("  PT-SYMMETRY INVESTIGATION: LIOUVILLE OPERATOR & GRAM MATRIX");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    let ns = vec![50, 100, 200, 300];

    for &n in &ns {
        println!("╔══════════════════════════════════════════════════════════╗");
        println!("║  N = {:4}  (dim = {:3})                                 ║", n, n - 1);
        println!("╚══════════════════════════════════════════════════════════╝");

        let g = build_gram(n);
        let p = build_parity(n);
        let dim = n - 1;

        // ═══════════ 1. COMMUTATOR ANALYSIS ═══════════
        println!("  ── 1. COMMUTATOR [G, P] = GP - PG ──");
        let gp = &g * &p;
        let pg = &p * &g;
        let commutator = &gp - &pg;
        let anticommutator = &gp + &pg;

        let g_norm = frobenius_norm(&g);
        let comm_norm = frobenius_norm(&commutator);
        let anticomm_norm = frobenius_norm(&anticommutator);

        let relative_comm = comm_norm / g_norm;
        println!("     ‖G‖_F         = {:.6}", g_norm);
        println!("     ‖[G,P]‖_F     = {:.6}", comm_norm);
        println!("     ‖{{G,P}}‖_F    = {:.6}", anticomm_norm);
        println!("     ‖[G,P]‖/‖G‖   = {:.6}  {}", relative_comm,
            if relative_comm < 0.1 { "← NEARLY COMMUTES ✨" }
            else if relative_comm < 0.5 { "← partially commutes" }
            else { "← does NOT commute" });
        println!();

        // ═══════════ 2. DECOMPOSITION G = G_even + G_odd ═══════════
        println!("  ── 2. PARITY DECOMPOSITION G = G_even + G_odd ──");
        // G_even = (G + PGP) / 2  (parity-preserving part)
        // G_odd  = (G - PGP) / 2  (parity-breaking part)
        let pgp = &p * &g * &p;
        let g_even = (&g + &pgp) * 0.5;
        let g_odd = (&g - &pgp) * 0.5;

        let even_norm = frobenius_norm(&g_even);
        let odd_norm = frobenius_norm(&g_odd);
        let even_frac = even_norm / g_norm;
        let odd_frac = odd_norm / g_norm;

        println!("     ‖G_even‖/‖G‖  = {:.6}  ({:.1}% of spectral weight)", even_frac, even_frac * 100.0);
        println!("     ‖G_odd‖/‖G‖   = {:.6}  ({:.1}% of spectral weight)", odd_frac, odd_frac * 100.0);
        println!();

        // ═══════════ 3. EIGENVALUE ANALYSIS ═══════════
        println!("  ── 3. SPECTRAL ANALYSIS ──");
        let eig_g = SymmetricEigen::new(g.clone());
        let eig_pgp = SymmetricEigen::new(pgp.clone());
        let eig_even = SymmetricEigen::new(g_even.clone());

        // Sort eigenvalues
        let mut evals_g: Vec<f64> = eig_g.eigenvalues.iter().copied().collect();
        let mut evals_pgp: Vec<f64> = eig_pgp.eigenvalues.iter().copied().collect();
        let mut evals_even: Vec<f64> = eig_even.eigenvalues.iter().copied().collect();
        evals_g.sort_by(|a, b| a.partial_cmp(b).unwrap());
        evals_pgp.sort_by(|a, b| a.partial_cmp(b).unwrap());
        evals_even.sort_by(|a, b| a.partial_cmp(b).unwrap());

        println!("     Spectrum comparison (5 smallest):");
        println!("     {:>12} {:>12} {:>12}", "λ(G)", "λ(PGP)", "λ(G_even)");
        for i in 0..5.min(dim) {
            println!("     {:12.8} {:12.8} {:12.8}",
                evals_g[i], evals_pgp[i], evals_even[i]);
        }
        println!("     λ_min ratio: λ_min(PGP)/λ_min(G) = {:.4}",
            evals_pgp[0] / evals_g[0]);
        println!();

        // ═══════════ 4. EIGENVECTOR PARITY ═══════════
        println!("  ── 4. EIGENVECTOR PARITY UNDER P ──");

        // For each eigenvector v_i of G, compute:
        // - parity = vᵀPv (how much it "is" a Liouville eigenstate)
        // - Pv correlation with v (is v an eigenstate of P?)

        // Sort eigenvectors by eigenvalue
        let mut indices: Vec<usize> = (0..dim).collect();
        indices.sort_by(|&a, &b| {
            eig_g.eigenvalues[a].partial_cmp(&eig_g.eigenvalues[b]).unwrap()
        });

        println!("     {:>5} {:>12} {:>10} {:>10} {:>12}",
            "idx", "eigenvalue", "⟨v,Pv⟩", "|⟨v,Pv⟩|", "Liouville ρ");

        let p_diag: DVector<f64> = DVector::from_fn(dim, |i, _| liouville(i + 2));
        let liou_template: DVector<f64> = DVector::from_fn(dim, |i, _| {
            let k = (i + 2) as f64;
            -liouville(i + 2) * k.ln() / k
        });
        let template_norm = liou_template.norm();
        let liou_unit = &liou_template / template_norm;

        for (rank, &idx) in indices.iter().enumerate().take(10) {
            let v: DVector<f64> = eig_g.eigenvectors.column(idx).into();
            // Make v unit vector (should already be, but normalize)
            let v_norm = v.norm();
            let v_unit = &v / v_norm;

            // Parity expectation: ⟨v, Pv⟩ = Σ λ(k) v[k]²
            let pv = DVector::from_fn(dim, |i, _| p_diag[i] * v_unit[i]);
            let parity = v_unit.dot(&pv);

            // Correlation with Liouville template
            let liou_corr = correlation(&v_unit, &liou_unit);

            println!("     {:5} {:12.8} {:10.6} {:10.6} {:12.6}",
                rank, eig_g.eigenvalues[idx], parity, parity.abs(), liou_corr);
        }
        println!();

        // ═══════════ 5. COMMUTATOR SPECTRUM ═══════════
        println!("  ── 5. COMMUTATOR SPECTRAL ANALYSIS ──");
        // [G,P] is antisymmetric: [G,P]ᵀ = (GP - PG)ᵀ = PG - GP = -[G,P]
        // So its eigenvalues are purely imaginary (or zero).
        // We compute the singular values instead.
        // Actually, [G,P]ᵀ[G,P] is symmetric, so we can get singular values.
        let ctc = commutator.transpose() * &commutator;
        let eig_ctc = SymmetricEigen::new(ctc);
        let mut svals: Vec<f64> = eig_ctc.eigenvalues.iter()
            .map(|v| v.max(0.0).sqrt())
            .collect();
        svals.sort_by(|a, b| b.partial_cmp(a).unwrap());

        println!("     5 largest singular values of [G, P]:");
        for i in 0..5.min(svals.len()) {
            println!("       σ_{} = {:.8}", i + 1, svals[i]);
        }
        let rank_approx = svals.iter().filter(|&&s| s > 1e-10).count();
        println!("     Effective rank of [G,P]: {}/{}", rank_approx, dim);
        println!();

        // ═══════════ 6. LIOUVILLE BLOCK STRUCTURE ═══════════
        println!("  ── 6. LIOUVILLE BLOCK STRUCTURE ──");
        // Split indices into Liouville-even (λ(k)=+1) and Liouville-odd (λ(k)=-1)
        let even_idx: Vec<usize> = (0..dim).filter(|&i| liouville(i + 2) > 0.0).collect();
        let odd_idx: Vec<usize> = (0..dim).filter(|&i| liouville(i + 2) < 0.0).collect();

        println!("     Liouville-even indices (λ=+1): {} values", even_idx.len());
        println!("     Liouville-odd  indices (λ=-1): {} values", odd_idx.len());

        // Compute block norms: G_ee, G_eo, G_oe, G_oo
        let mut norm_ee = 0.0f64;
        let mut norm_eo = 0.0f64;
        let mut norm_oo = 0.0f64;
        let mut entries = 0usize;

        for &i in &even_idx {
            for &j in &even_idx {
                norm_ee += g[(i, j)].powi(2);
            }
            for &j in &odd_idx {
                norm_eo += g[(i, j)].powi(2);
            }
        }
        for &i in &odd_idx {
            for &j in &odd_idx {
                norm_oo += g[(i, j)].powi(2);
            }
        }

        let total_sq = g_norm * g_norm;
        println!("     Block-wise ‖·‖²/‖G‖²:");
        println!("       G_ee (even×even): {:.4}  ({:.1}%)", norm_ee / total_sq, 100.0 * norm_ee / total_sq);
        println!("       G_eo (even×odd):  {:.4}  ({:.1}%)", 2.0 * norm_eo / total_sq, 200.0 * norm_eo / total_sq);
        println!("       G_oo (odd×odd):   {:.4}  ({:.1}%)", norm_oo / total_sq, 100.0 * norm_oo / total_sq);

        // If G is approximately block-diagonal under Liouville parity,
        // then G_eo ≈ 0, and the commutator [G,P] ≈ 0.
        let off_diag_frac = 2.0 * norm_eo / total_sq;
        if off_diag_frac < 0.3 {
            println!("     → G is APPROXIMATELY block-diagonal under Liouville ✨");
        } else {
            println!("     → G has significant cross-parity coupling");
        }
        println!();

        // ═══════════ 7. HIGHER EIGENVECTOR LIOUVILLE CORRELATIONS ═══════════
        println!("  ── 7. ALL EIGENVECTORS: LIOUVILLE SIGN AGREEMENT ──");
        // For each eigenvector, check if sign(v[k]) correlates with λ(k)
        println!("     {:>5} {:>12} {:>10} {:>10}",
            "rank", "eigenvalue", "sign_agree", "parity ⟨v,Pv⟩");

        for (rank, &idx) in indices.iter().enumerate().take(20.min(dim)) {
            let v: DVector<f64> = eig_g.eigenvectors.column(idx).into();
            let v_norm = v.norm();
            let v_unit = &v / v_norm;

            // Sign agreement with Liouville
            let mut agree = 0usize;
            let mut total = 0usize;
            for i in 0..dim {
                if v_unit[i].abs() > 1e-10 {
                    let v_sign = if v_unit[i] > 0.0 { 1.0 } else { -1.0 };
                    let expected = -liouville(i + 2); // v ∝ -λ(k)·...
                    if v_sign * expected > 0.0 { agree += 1; }
                    total += 1;
                }
            }
            let agree_frac = if total > 0 { agree as f64 / total as f64 } else { 0.0 };

            // Parity
            let pv = DVector::from_fn(dim, |i, _| p_diag[i] * v_unit[i]);
            let parity = v_unit.dot(&pv);

            println!("     {:5} {:12.8} {:10.4} {:10.6}",
                rank, eig_g.eigenvalues[idx], agree_frac, parity);
        }

        println!();
    }

    // ═══════════ SCALING ANALYSIS ═══════════
    println!("══════════════════════════════════════════════════════════════");
    println!("  SCALING: How does the commutator relative norm scale with N?");
    println!("══════════════════════════════════════════════════════════════");
    println!();

    let scale_ns = vec![20, 30, 50, 75, 100, 150, 200, 300];
    let mut scale_data: Vec<(f64, f64)> = Vec::new();

    println!("  {:>6} {:>12} {:>12} {:>12} {:>12}",
        "N", "‖[G,P]‖/‖G‖", "‖G_eo‖/‖G‖", "min_parity", "liou_corr");
    println!("  {}", "-".repeat(60));

    for &n in &scale_ns {
        let g = build_gram(n);
        let p = build_parity(n);
        let dim = n - 1;

        let gp = &g * &p;
        let pg = &p * &g;
        let comm = &gp - &pg;
        let g_norm = frobenius_norm(&g);
        let comm_rel = frobenius_norm(&comm) / g_norm;

        // Cross-parity norm
        let even_idx: Vec<usize> = (0..dim).filter(|&i| liouville(i + 2) > 0.0).collect();
        let odd_idx: Vec<usize> = (0..dim).filter(|&i| liouville(i + 2) < 0.0).collect();
        let mut norm_eo = 0.0f64;
        for &i in &even_idx {
            for &j in &odd_idx {
                norm_eo += g[(i, j)].powi(2);
            }
        }
        let eo_rel = (2.0 * norm_eo).sqrt() / g_norm;

        // Min eigenvector parity
        let eig = SymmetricEigen::new(g.clone());
        let mut min_idx = 0;
        let mut min_val = f64::INFINITY;
        for i in 0..dim {
            if eig.eigenvalues[i] < min_val {
                min_val = eig.eigenvalues[i];
                min_idx = i;
            }
        }
        let v: DVector<f64> = eig.eigenvectors.column(min_idx).into();
        let v_unit = &v / v.norm();
        let p_diag: DVector<f64> = DVector::from_fn(dim, |i, _| liouville(i + 2));
        let parity: f64 = (0..dim).map(|i| p_diag[i] * v_unit[i] * v_unit[i]).sum();

        // Liouville correlation
        let liou_template: DVector<f64> = DVector::from_fn(dim, |i, _| {
            let k = (i + 2) as f64;
            -liouville(i + 2) * k.ln() / k
        });
        let liou_unit = &liou_template / liou_template.norm();
        let liou_corr = correlation(&v_unit, &liou_unit);

        scale_data.push((n as f64, comm_rel));

        println!("  {:6} {:12.6} {:12.6} {:12.6} {:12.6}",
            n, comm_rel, eo_rel, parity, liou_corr);
    }

    // Power law fit
    let valid: Vec<(f64, f64)> = scale_data.iter()
        .filter(|(_, y)| *y > 0.0)
        .copied()
        .collect();

    if valid.len() >= 3 {
        let n_pts = valid.len() as f64;
        let sum_lnx: f64 = valid.iter().map(|(x, _)| x.ln()).sum();
        let sum_lny: f64 = valid.iter().map(|(_, y)| y.ln()).sum();
        let sum_lnx2: f64 = valid.iter().map(|(x, _)| x.ln().powi(2)).sum();
        let sum_lnx_lny: f64 = valid.iter().map(|(x, y)| x.ln() * y.ln()).sum();
        let denom = n_pts * sum_lnx2 - sum_lnx.powi(2);
        let slope = (n_pts * sum_lnx_lny - sum_lnx * sum_lny) / denom;
        let intercept = (sum_lny - slope * sum_lnx) / n_pts;
        let a = intercept.exp();

        println!();
        println!("  Power law fit: ‖[G,P]‖/‖G‖ ≈ {:.4} · N^{{{:.3}}}", a, slope);
        if slope < -0.1 {
            println!("  → Commutator VANISHES as N → ∞  ✨ (rate: N^{{{:.3}}})", slope);
            println!("  → G COMMUTES with Liouville parity in the large-N limit!");
        } else if slope.abs() < 0.1 {
            println!("  → Commutator is approximately CONSTANT (no scaling)");
        } else {
            println!("  → Commutator GROWS with N (rate: N^{{{:.3}}})", slope);
        }
    }

    println!();
    println!("══════════════════════════════════════════════════════════════");
    println!("  CONCLUSION");
    println!("══════════════════════════════════════════════════════════════");
    println!();
    println!("  If [G, P] → 0: Liouville is an approximate symmetry of G");
    println!("    → eigenvectors must approximately respect Liouville parity");
    println!("    → alignment_decay follows from cancellation in parity sectors");
    println!("    → THIS WOULD EXPLAIN WHY v_min ∝ λ(k)·ln(k)/k");
    println!();
    println!("  If [G, P] ≠ 0 but structured: the commutator reveals the");
    println!("    mechanism by which arithmetic structure enters the spectrum");
    println!();
}
