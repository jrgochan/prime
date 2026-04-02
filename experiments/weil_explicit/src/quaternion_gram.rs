use rayon::prelude::*;
use nalgebra::{DMatrix, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// QUATERNIONIC GRAM MATRIX SPECTRAL GAP ANALYSIS
//
// Core Hypothesis: Construct a quaternionic Gram matrix G^ℍ using
// "power channels" — the functions {k/x}, {k/x²}, {k/x³}, {k/x⁴}.
//
// In quaternionic quantum mechanics (GSE), eigenvalues come in
// Kramers-degenerate pairs. The question is whether the quaternionic
// matrix has a LARGER spectral gap than the real one.
//
// Key test: Does the Liouville eigenvector (the problematic direction
// in the real case) get "propped up" by the higher power channels?
//
// Connection to RH: The power channels involve ζ(ks) for k=1,2,3,4.
// If the channels are "sufficiently independent," the quaternionic
// spectral gap could be provably positive even when the real one is hard.
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

fn liouville(n: usize) -> i32 {
    let mut val = n;
    let mut omega = 0;
    let mut p = 2;
    while p * p <= val {
        while val % p == 0 { omega += 1; val /= p; }
        p += 1;
    }
    if val > 1 { omega += 1; }
    if omega % 2 == 0 { 1 } else { -1 }
}

/// Gram entry for power channel p: ∫₀¹ {j/x^p}{k/x^p} dx
fn gram_entry_power(j: usize, k: usize, power: u32, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let xp = x.powi(power as i32);
        if xp > 1e-15 {
            sum += frac_part(jf / xp) * frac_part(kf / xp);
        }
    }
    sum * dx
}

/// Cross-channel entry: ∫₀¹ {j/x^p₁}{k/x^p₂} dx
fn gram_cross(j: usize, k: usize, p1: u32, p2: u32, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        let xp1 = x.powi(p1 as i32);
        let xp2 = x.powi(p2 as i32);
        if xp1 > 1e-15 && xp2 > 1e-15 {
            sum += frac_part(jf / xp1) * frac_part(kf / xp2);
        }
    }
    sum * dx
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  QUATERNIONIC GRAM MATRIX — POWER CHANNEL ANALYSIS             ║");
    println!("║  G^ℍ[j,k] constructed from {{k/x}}, {{k/x²}}, {{k/x³}}, {{k/x⁴}}    ║");
    println!("║  Does the quaternionic spectral gap exceed the real one?        ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 500_000;
    let total_start = std::time::Instant::now();

    // ═══════════════════════════════════════════════════════
    // SECTION 1: Individual power channel spectra
    // ═══════════════════════════════════════════════════════
    println!("═══ Section 1: Individual channel λ_min ═══\n");
    println!("  {:>6} {:>14} {:>14} {:>14} {:>14}",
        "N", "λ_min(x¹)", "λ_min(x²)", "λ_min(x³)", "λ_min(x⁴)");
    println!("  {}", "─".repeat(68));

    for &n in &[10, 20, 50, 100, 200] {
        let dim = n - 1;
        let mut lmins = vec![];

        for power in 1..=4u32 {
            let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
                .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                    ((i, j), gram_entry_power(i + 2, j + 2, power, n_pts))
                })).collect();

            let mut mat = DMatrix::<f64>::zeros(dim, dim);
            for ((i, j), v) in entries { mat[(i, j)] = v; mat[(j, i)] = v; }

            let eig = SymmetricEigen::new(mat);
            let lmin = eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
            lmins.push(lmin);
        }

        println!("  {:6} {:14.10} {:14.10} {:14.10} {:14.10}",
            n, lmins[0], lmins[1], lmins[2], lmins[3]);
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 2: Eigenvector comparison across channels
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 2: Minimum eigenvector comparison (N=100) ═══\n");
    let n = 100;
    let dim = n - 1;

    let mut evecs = vec![];
    for power in 1..=4u32 {
        let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
            .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                ((i, j), gram_entry_power(i + 2, j + 2, power, n_pts))
            })).collect();

        let mut mat = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in entries { mat[(i, j)] = v; mat[(j, i)] = v; }

        let eig = SymmetricEigen::new(mat);
        let min_idx = eig.eigenvalues.iter().enumerate()
            .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
            .unwrap().0;
        let evec: Vec<f64> = eig.eigenvectors.column(min_idx).iter().cloned().collect();
        evecs.push(evec);
    }

    // Check Liouville correlation in each channel
    println!("  Liouville correlation of minimum eigenvector:\n");
    println!("  {:>8} {:>12} {:>12} {:>12}",
        "channel", "corr(v,λ)", "|corr|", "sign agree%");
    println!("  {}", "─".repeat(48));

    for (ch, evec) in evecs.iter().enumerate() {
        let power = ch + 1;
        let mut dot_vl = 0.0f64;
        let mut norm_v = 0.0f64;
        let mut norm_l = 0.0f64;
        let mut sign_agree = 0usize;
        let mut total = 0usize;

        for k_idx in 0..dim {
            let k = k_idx + 2;
            let v = evec[k_idx];
            let l = liouville(k) as f64 * (k as f64).ln() / k as f64;
            dot_vl += v * l;
            norm_v += v * v;
            norm_l += l * l;
            if v.abs() > 1e-10 && l.abs() > 1e-10 {
                total += 1;
                if v.signum() == l.signum() || v.signum() == -l.signum() {
                    // Check if signs match (up to global flip)
                }
            }
        }
        let corr = dot_vl / (norm_v.sqrt() * norm_l.sqrt());

        // Check sign agreement with global sign flip
        let flip = if corr < 0.0 { -1.0 } else { 1.0 };
        for k_idx in 0..dim {
            let k = k_idx + 2;
            let v = flip * evec[k_idx];
            let l = liouville(k) as f64;
            if v.abs() > 1e-6 {
                total += 1;
                if v.signum() == l.signum() { sign_agree += 1; }
            }
        }

        println!("  x^{:<5} {:12.6} {:12.6} {:>10.1}%",
            power, corr, corr.abs(),
            if total > 0 { 100.0 * sign_agree as f64 / total as f64 } else { 0.0 });
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 3: Direct sum Gram matrix (block diagonal)
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 3: Direct sum vs real Gram matrix ═══\n");
    println!("  The 'quaternionic' Gram matrix as a block structure:\n");
    println!("  {:>6} {:>14} {:>14} {:>14} {:>8}",
        "N", "λ_min(G¹)", "λ_min(G¹⊕G²)", "λ_min(G¹⊕..⊕G⁴)", "boost?");
    println!("  {}", "─".repeat(60));

    for &n in &[20, 50, 100, 200] {
        let dim = n - 1;

        // Build all 4 channel matrices
        let mut channel_mats = vec![];
        for power in 1..=4u32 {
            let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
                .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                    ((i, j), gram_entry_power(i + 2, j + 2, power, n_pts))
                })).collect();

            let mut mat = DMatrix::<f64>::zeros(dim, dim);
            for ((i, j), v) in entries { mat[(i, j)] = v; mat[(j, i)] = v; }
            channel_mats.push(mat);
        }

        // λ_min of channel 1 alone
        let eig1 = SymmetricEigen::new(channel_mats[0].clone());
        let lmin1 = eig1.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

        // λ_min of direct sum G¹⊕G² (2×dim block diagonal)
        let d2 = 2 * dim;
        let mut block2 = DMatrix::<f64>::zeros(d2, d2);
        for i in 0..dim {
            for j in 0..dim {
                block2[(i, j)] = channel_mats[0][(i, j)];
                block2[(dim + i, dim + j)] = channel_mats[1][(i, j)];
            }
        }
        let eig2 = SymmetricEigen::new(block2);
        let lmin2 = eig2.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

        // λ_min of direct sum G¹⊕G²⊕G³⊕G⁴ (4×dim block diagonal)
        let d4 = 4 * dim;
        let mut block4 = DMatrix::<f64>::zeros(d4, d4);
        for ch in 0..4 {
            for i in 0..dim {
                for j in 0..dim {
                    block4[(ch * dim + i, ch * dim + j)] = channel_mats[ch][(i, j)];
                }
            }
        }
        let eig4 = SymmetricEigen::new(block4);
        let lmin4 = eig4.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

        let boost = lmin4 > lmin1;
        println!("  {:6} {:14.10} {:14.10} {:14.10} {:>8}",
            n, lmin1, lmin2, lmin4, if boost { "✅ YES" } else { "❌ no" });
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 4: Cross-channel coupling (true quaternionic)
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 4: Cross-channel coupling (N=100) ═══\n");
    println!("  Full quaternionic matrix with off-diagonal cross-correlations");
    println!("  G^ℍ_{{ij}} includes ∫{{i/x^p}}{{j/x^q}} for all p,q ∈ {{1,2,3,4}}\n");

    let n = 100;
    let dim = n - 1;
    let qdim = 4 * dim; // Full quaternionic dimension

    println!("  Building {}×{} full quaternionic Gram matrix...", qdim, qdim);
    let qstart = std::time::Instant::now();

    let mut qmat = DMatrix::<f64>::zeros(qdim, qdim);
    for p1 in 0..4u32 {
        for p2 in p1..4u32 {
            let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
                .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                    ((i, j), gram_cross(i + 2, j + 2, p1 + 1, p2 + 1, n_pts))
                })).collect();

            for ((i, j), v) in entries {
                // Block (p1, p2) at position (p1*dim + i, p2*dim + j)
                qmat[(p1 as usize * dim + i, p2 as usize * dim + j)] = v;
                qmat[(p2 as usize * dim + j, p1 as usize * dim + i)] = v;
                if i != j {
                    qmat[(p1 as usize * dim + j, p2 as usize * dim + i)] = v;
                    qmat[(p2 as usize * dim + i, p1 as usize * dim + j)] = v;
                }
            }
        }
    }

    println!("  Built in {:.1}s", qstart.elapsed().as_secs_f64());
    println!("  Computing eigenvalues...");

    let qeig = SymmetricEigen::new(qmat);
    let mut qevals: Vec<f64> = qeig.eigenvalues.iter().cloned().collect();
    qevals.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let qmin = qevals[0];
    let qmax = qevals[qevals.len() - 1];
    let neg_count = qevals.iter().filter(|&&v| v < -1e-10).count();

    // Compare to channel-1 only
    let entries1: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
        .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
            ((i, j), gram_entry_power(i + 2, j + 2, 1, n_pts))
        })).collect();
    let mut mat1 = DMatrix::<f64>::zeros(dim, dim);
    for ((i, j), v) in entries1 { mat1[(i, j)] = v; mat1[(j, i)] = v; }
    let eig1 = SymmetricEigen::new(mat1);
    let lmin1 = eig1.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

    println!("\n  Results:");
    println!("    λ_min(G¹) [real channel 1]:   {:.10}", lmin1);
    println!("    λ_min(G^ℍ) [full quaternionic]: {:.10}", qmin);
    println!("    λ_max(G^ℍ):                    {:.4}", qmax);
    println!("    Negative eigenvalues:           {}/{}", neg_count, qevals.len());
    println!("    Is G^ℍ positive definite?       {}", if neg_count == 0 { "✅ YES" } else { "❌ NO" });

    if qmin > lmin1 {
        println!("\n    🎉 QUATERNIONIC GAP IS LARGER: {:.10} > {:.10}", qmin, lmin1);
        println!("    Boost factor: {:.4}×", qmin / lmin1);
    } else {
        println!("\n    ℹ️  Quaternionic gap not larger: {:.10} ≤ {:.10}", qmin, lmin1);
    }

    // 10 smallest eigenvalues
    println!("\n  10 smallest eigenvalues of G^ℍ (N=100):");
    for i in 0..10.min(qevals.len()) {
        // Check for Kramers degeneracy (pairs of nearly equal eigenvalues)
        let kramers = if i + 1 < qevals.len() && (qevals[i] - qevals[i + 1]).abs() < 1e-6 {
            " ← Kramers pair"
        } else if i > 0 && (qevals[i] - qevals[i - 1]).abs() < 1e-6 {
            " ← Kramers pair"
        } else { "" };
        println!("    λ_{} = {:.10}{}", i + 1, qevals[i], kramers);
    }

    // Check for Kramers degeneracy globally
    let mut kramers_pairs = 0;
    let mut i = 0;
    while i + 1 < qevals.len() {
        if (qevals[i] - qevals[i + 1]).abs() < 1e-4 * qevals[i].abs().max(1e-6) {
            kramers_pairs += 1;
            i += 2;
        } else {
            i += 1;
        }
    }
    println!("\n  Kramers-degenerate pairs: {}/{} (expect ~50% for true GSE)",
        kramers_pairs, qevals.len() / 2);

    println!("\n  Total time: {:.1}s", total_start.elapsed().as_secs_f64());
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Quaternionic analysis complete.                               ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
