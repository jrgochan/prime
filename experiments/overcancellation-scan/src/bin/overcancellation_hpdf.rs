#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
// overcancellation-scan/src/bin/overcancellation_hpdf.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  OVERCANCELLATION ANATOMY — HPDF-Backed High-N Decomposition    ║
// ║                                                                   ║
// ║  Reads precomputed Gram matrices from HPDF .h5 files and         ║
// ║  decomposes vᵀGv into four components.                           ║
// ║                                                                   ║
// ║  Reports BOTH:                                                    ║
// ║    • k≥2 sector (from HPDF matrix, dim = N-1)                   ║
// ║    • Full k≥1 (k=1 row/column computed analytically)             ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::hpdf::HpdfReader;
use rayon::prelude::*;
use std::f64::consts::PI;
use std::path::PathBuf;

const EULER_GAMMA: f64 = 0.5772156649015329;

fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

/// Vasyunin sum V(a,b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let mut s = 0.0;
    for m in 1..a {
        let angle = PI * m as f64 / af;
        let cot = angle.cos() / angle.sin();
        let frac = ((m * b) as f64 / af).fract();
        s += cot * frac;
    }
    s
}

/// Compute G(1,k) analytically using the Vasyunin formula.
/// For j=1: gcd(1,k) = 1, j'=1, k'=k.
/// G(1,1) = C - 1
/// G(1,k) = (C/2)(1+1/k) + (1-k)/(2k)·ln(k) - π/(2k)·V(k,1) - 1/k
fn gram_entry_k1(k: usize) -> f64 {
    let c = vasyunin_const();
    if k == 1 {
        return c - 1.0;
    }
    let kf = k as f64;
    let term1 = c / 2.0 * (1.0 + 1.0 / kf);
    let term2 = (1.0 - kf) / (2.0 * kf) * kf.ln();
    // V(1,k) = 0 (empty sum), V(k,1) = Σ cot(πm/k)·{m/k}
    let vk1 = vasyunin_sum(k, 1);
    let term3 = PI / (2.0 * kf) * vk1;  // V(1,k)=0, so just V(k,1)
    let term4 = 1.0 / kf;
    term1 + term2 - term3 - term4
}

/// Decompose an off-diagonal entry into (term1, term2, term4).
/// term3 is obtained by subtraction: term3 = term1 + term2 - term4 - G(j,k)
fn decompose_cheap(j: usize, k: usize) -> (f64, f64, f64) {
    let c = vasyunin_const();
    let jf = j as f64;
    let kf = k as f64;
    let t1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
    let t2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let t4 = 1.0 / (jf * kf);
    (t1, t2, t4)
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════╗");
    println!("║  OVERCANCELLATION ANATOMY — HPDF-Backed Decomposition       ║");
    println!("╚═══════════════════════════════════════════════════════════════╝");
    println!();

    let c = vasyunin_const();
    println!("C = ln(2π) − γ = {:.6}", c);

    let cache_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent().unwrap()
        .join("cache/hpdf");

    // HC numbers we have HPDF files for
    let hc_ns: Vec<usize> = vec![
        6, 12, 36, 48, 60, 120, 180, 240, 360, 840,
        1260, 1680, 2520, 5040, 7560, 10080, 20160, 27720, 45360, 55440,
    ];

    println!();
    println!("═══ SECTION 1: k≥2 Sector (HPDF matrix only) ═══");
    println!("{:>8} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "N", "vᵀGv_k2", "diag", "term1", "term2", "-term3", "-term4", "‖v‖²_k2", "1-vᵀGv");
    println!("{}", "─".repeat(90));

    let mut results = Vec::new();

    for &n in &hc_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() {
            eprintln!("  [skip] {} not found", path.display());
            continue;
        }

        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("  [skip] N={}: {}", n, e);
                continue;
            }
        };

        let dim = reader.dim(); // N-1
        let max_n = reader.max_n();
        assert_eq!(max_n, n, "HPDF max_n mismatch");

        // Read Möbius function
        let mu_raw = reader.read_mobius().unwrap();

        // Read full Gram matrix
        let gram = reader.read_gram_full().unwrap();

        // Build BD witness vector for k=2..N (HPDF indexing)
        let log_n = (n as f64).ln();
        let mut v2 = vec![0.0f64; dim]; // v[i] for k = i+2
        for i in 0..dim {
            let k = i + 2;
            if k >= n { break; }
            let mu_k = mu_raw[k] as f64;
            let w = 1.0 - (k as f64).ln() / log_n;
            v2[i] = -mu_k * w;
        }

        // ═══ k≥2 sector computation ═══
        // vᵀGv using HPDF matrix (parallel row-vector multiply)
        let vtgv_k2: f64 = (0..dim).into_par_iter().map(|i| {
            let vi = v2[i];
            let mut row_sum = 0.0;
            for j in 0..dim {
                row_sum += v2[j] * gram[i * dim + j];
            }
            vi * row_sum
        }).sum();

        // Wait — that double-counts. Let me fix: vᵀGv = Σ_i v_i * (Gv)_i
        // Actually no, the above is correct: Σ_i v_i * Σ_j G_{ij} v_j
        // But we're computing Σ_i (v_i * Σ_j v_j G_{ij}) which IS vᵀGv. ✓
        // Wait, no. Let me re-check:
        // row_sum = Σ_j v_j * G[i,j]  (this is (Gv)_i)
        // Then we multiply by v_i: v_i * (Gv)_i
        // Sum over i: Σ_i v_i * (Gv)_i = vᵀ(Gv) = vᵀGv ✓
        // But wait, the outer map returns vi * row_sum where row_sum already
        // uses v2[j]. That means the actual computation is:
        // Σ_i v2[i] * Σ_j v2[j] * gram[i*dim+j]
        // Hmm, that would be Σ_i Σ_j v2[i]*v2[j]*G[i,j] = vᵀGv ... no wait.
        // Let me re-read the code.
        // row_sum = Σ_j v2[j] * gram[i*dim+j]  -- this is wrong, it should be
        //   Σ_j gram[i*dim+j] * v2[j]  (matrix-vector product)
        // Then result = Σ_i v2[i] * row_sum = Σ_i v2[i] * Σ_j G[i,j] * v2[j]
        // = Σ_{i,j} v2[i] * G[i,j] * v2[j] = vᵀGv ✓
        // OK, it's correct.

        // Norm squared
        let norm_sq_k2: f64 = v2.iter().map(|x| x*x).sum();

        // Diagonal contribution
        let diag_k2: f64 = (0..dim).map(|i| v2[i] * v2[i] * gram[i * dim + i]).sum();

        // Off-diagonal term decomposition (O(N²), cheap)
        let (mut t1_sum, mut t2_sum, mut t4_sum) = (0.0f64, 0.0f64, 0.0f64);
        for i in 0..dim {
            let j = i + 2; // HPDF k starts at 2
            for ji in 0..dim {
                if ji == i { continue; }
                let k = ji + 2;
                let w = v2[i] * v2[ji];
                let (t1, t2, t4) = decompose_cheap(j, k);
                t1_sum += w * t1;
                t2_sum += w * t2;
                t4_sum += w * t4;
            }
        }

        // -term3 by subtraction: vᵀGv = diag + t1 + t2 - t3 - t4
        // → t3 = diag + t1 + t2 - t4 - vtgv → -t3 = vtgv - diag - t1 - t2 + t4
        let neg_t3 = vtgv_k2 - diag_k2 - t1_sum - t2_sum + t4_sum;

        println!("{:>8} {:>+10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>10.2} {:>+10.4}",
            n, vtgv_k2, diag_k2, t1_sum, t2_sum, neg_t3, -t4_sum, norm_sq_k2, 1.0 - vtgv_k2);

        // Store for k=1 augmentation
        results.push((n, vtgv_k2, diag_k2, t1_sum, t2_sum, neg_t3, t4_sum, norm_sq_k2, v2.clone(), gram, dim, mu_raw));
    }

    // ═══ SECTION 2: Full k≥1 (k=1 row computed analytically) ═══
    println!();
    println!("═══ SECTION 2: Full k≥1 (with k=1 anchor) ═══");
    println!("{:>8} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10} {:>10}",
        "N", "vᵀGv", "diag", "term1", "term2", "-term3", "-term4", "‖v‖²", "1-vᵀGv");
    println!("{}", "─".repeat(90));

    for (n, vtgv_k2, diag_k2, t1_k2, t2_k2, neg_t3_k2, t4_k2, norm_sq_k2, v2, _gram, dim, mu_raw) in &results {
        let n = *n;
        let log_n = (n as f64).ln();

        // k=1 weight: v1 = -μ(1)·(1 - ln(1)/ln(N)) = -1·1 = -1
        let v1: f64 = -(mu_raw[1] as f64) * (1.0 - (1.0f64).ln() / log_n);

        // G(1,1) contribution to diagonal
        let g11 = gram_entry_k1(1);
        let diag_k1 = v1 * v1 * g11;

        // Cross-terms: 2 * v1 * Σ_{k=2..N-1} v_k * G(1,k)
        // (G is symmetric, so row-1 and col-1 both contribute)
        let mut cross_vtgv = 0.0f64;
        let mut cross_t1 = 0.0f64;
        let mut cross_t2 = 0.0f64;
        let mut cross_t4 = 0.0f64;

        for i in 0..*dim {
            let k = i + 2;
            if k >= n { break; }
            let vk = v2[i];
            let g1k = gram_entry_k1(k);

            // Cross contribution to vᵀGv: v1*vk*G(1,k) + vk*v1*G(k,1) = 2*v1*vk*G(1,k)
            cross_vtgv += 2.0 * v1 * vk * g1k;

            // Decompose G(1,k) into cheap terms
            let (t1, t2, t4) = decompose_cheap(1, k);
            cross_t1 += 2.0 * v1 * vk * t1;
            cross_t2 += 2.0 * v1 * vk * t2;
            cross_t4 += 2.0 * v1 * vk * t4;
        }

        // Full vᵀGv = k≥2 sector + k=1 diagonal + cross terms
        let vtgv_full = vtgv_k2 + diag_k1 + cross_vtgv;
        let diag_full = diag_k2 + diag_k1;
        let t1_full = t1_k2 + cross_t1;
        let t2_full = t2_k2 + cross_t2;
        let t4_full = t4_k2 + cross_t4;
        let norm_sq_full = norm_sq_k2 + v1 * v1;

        // -term3 by subtraction
        let neg_t3_full = vtgv_full - diag_full - t1_full - t2_full + t4_full;

        println!("{:>8} {:>+10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>10.2} {:>+10.4}",
            n, vtgv_full, diag_full, t1_full, t2_full, neg_t3_full, -t4_full, norm_sq_full, 1.0 - vtgv_full);
    }

    println!();
    println!("NOTE: G(j,k) = term1 + term2 - term3 - term4 for j≠k");
    println!("  vᵀGv = diag + term1 + term2 - term3 - term4");
    println!("  k=1 anchor: v₁ = -μ(1)·(1-0) = -1, G(1,k) computed via Vasyunin sums");
}
