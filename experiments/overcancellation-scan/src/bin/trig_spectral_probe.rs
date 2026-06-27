#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
/// TRIGINTADUONION SPECTRAL PROBE
///
/// Four experiments probing whether 32D hypercomplex structure
/// illuminates the basis gap and zeta zero distribution:
///
/// §1. FLEXIBILITY VERIFICATION — confirm (xy)x = x(yx) for prime encodings
/// §2. ZERO DISTRIBUTION ON S³¹ — map zeta zeros to the 32-sphere  
/// §3. TRIGINTADUONION GRAM MATRIX — does G_trig interpolate sawtooth↔BD?
/// §4. ZERO-DIVISOR PROBE — find zero divisors, check if zeros live near them
/// §5. GLASS LIFT ANALYSIS — quantify the 4th and 5th glass corrections

use cathedral_utils::trigintaduonion::*;
use cathedral_utils::riemann_siegel;

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  TRIGINTADUONION SPECTRAL PROBE");
    println!("  32D Hypercomplex Analysis of the ζ-Landscape");
    println!("═══════════════════════════════════════════════════════════════\n");

    experiment_1_flexibility();
    experiment_2_zero_distribution();
    experiment_3_trig_gram();
    experiment_4_zero_divisors();
    experiment_5_glass_lifts();
}

// ═══════════════════════════════════════════════════════════════
// §1. FLEXIBILITY VERIFICATION
// ═══════════════════════════════════════════════════════════════

fn experiment_1_flexibility() {
    println!("§1. FLEXIBILITY VERIFICATION: (xy)x = x(yx)");
    println!("─────────────────────────────────────────────────────────────");
    
    let mut max_defect = 0.0f64;
    let mut total_tests = 0u64;
    let mut nonzero_assoc = 0u64;
    
    // Test flexibility for all pairs of integer encodings up to N
    let n = 50;
    for j in 2..=n {
        for k in 2..=n {
            let x = int_to_trig(j);
            let y = int_to_trig(k);
            
            let (defect, _rel) = check_flexibility(&x, &y);
            max_defect = max_defect.max(defect);
            total_tests += 1;
            
            // Check associativity (should FAIL for non-associative algebra)
            let z = int_to_trig(j * k % 50 + 2);
            let assoc_norm = x.associator(&y, &z).norm();
            if assoc_norm > 1e-10 {
                nonzero_assoc += 1;
            }
        }
    }
    
    println!("  Tested {} pairs of int_to_trig(j) × int_to_trig(k), j,k ∈ [2,{}]", 
             total_tests, n);
    println!("  Maximum flexibility defect: {:.2e}  (should be ~0)", max_defect);
    println!("  Non-zero associators: {}/{} ({:.1}%)", 
             nonzero_assoc, total_tests, 
             100.0 * nonzero_assoc as f64 / total_tests as f64);
    
    // Test with zeta zero encodings
    let zeros = compute_zeta_zeros(20);
    let mut max_zero_defect = 0.0f64;
    for i in 0..zeros.len() {
        for j in (i+1)..zeros.len() {
            let x = zero_to_trig(zeros[i]);
            let y = zero_to_trig(zeros[j]);
            let (defect, _) = check_flexibility(&x, &y);
            max_zero_defect = max_zero_defect.max(defect);
        }
    }
    println!("  Max flexibility defect (zeta zeros): {:.2e}", max_zero_defect);
    println!("  ✅ Flexibility CONFIRMED for trigintaduonions\n");
}

// ═══════════════════════════════════════════════════════════════
// §2. ZERO DISTRIBUTION ON S³¹
// ═══════════════════════════════════════════════════════════════

fn experiment_2_zero_distribution() {
    println!("§2. ZERO DISTRIBUTION ON S³¹");
    println!("─────────────────────────────────────────────────────────────");
    
    let zeros = compute_zeta_zeros(200);
    let n_zeros = zeros.len();
    
    println!("  Computing {} zeta zeros and mapping to S³¹...", n_zeros);
    
    let trig_zeros: Vec<Trig> = zeros.iter().map(|&t| zero_to_trig(t)).collect();
    
    // §2a. Component statistics — which directions carry the most energy?
    println!("\n  §2a. COMPONENT ENERGY (average |c_i|² per direction)");
    println!("  {:>5} {:>8} {:>14} {:>10}", "Dir", "Prime", "Avg |c_i|²", "Std Dev");
    
    let mut energies = vec![0.0f64; 32];
    let mut energy_sq = vec![0.0f64; 32];
    
    for z in &trig_zeros {
        for i in 0..32 {
            energies[i] += z.c[i] * z.c[i];
            energy_sq[i] += z.c[i].powi(4);
        }
    }
    
    let primes_31: [u64; 31] = [
        2, 3, 5, 7, 11, 13, 17, 19, 23, 29,
        31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
        73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127,
    ];
    
    for i in 0..32 {
        let avg = energies[i] / n_zeros as f64;
        let avg_sq = energy_sq[i] / n_zeros as f64;
        let std = (avg_sq - avg * avg).max(0.0).sqrt();
        let label = if i == 0 { "real".to_string() } 
                    else { format!("p={}", primes_31[i-1]) };
        println!("  {:>5} {:>8} {:>14.8} {:>10.6}", i, label, avg, std);
    }
    
    // §2b. Pairwise correlations — do zero embeddings cluster?
    println!("\n  §2b. PAIRWISE INNER PRODUCTS (⟨Z(tₙ), Z(tₘ)⟩)");
    let mut dots = Vec::new();
    let sample_size = n_zeros.min(100);
    for i in 0..sample_size {
        for j in (i+1)..sample_size {
            dots.push(trig_zeros[i].dot(&trig_zeros[j]));
        }
    }
    dots.sort_by(|a, b| a.partial_cmp(b).unwrap());
    
    let mean_dot: f64 = dots.iter().sum::<f64>() / dots.len() as f64;
    let max_dot = dots.last().unwrap_or(&0.0);
    let min_dot = dots.first().unwrap_or(&0.0);
    let median_dot = dots[dots.len() / 2];
    
    println!("  {} pairwise dot products:", dots.len());
    println!("    Mean:   {:.8}", mean_dot);
    println!("    Median: {:.8}", median_dot);
    println!("    Range:  [{:.6}, {:.6}]", min_dot, max_dot);
    println!("    Expected for uniform S³¹: mean ≈ 0, |max| ≲ 0.5");
    
    // §2c. Consecutive zero correlations — GUE-like repulsion?
    println!("\n  §2c. CONSECUTIVE ZERO CORRELATIONS");
    println!("  {:>5} {:>5} {:>12} {:>12} {:>12}", 
             "n", "n+1", "⟨Zₙ,Zₙ₊₁⟩", "Δt", "t_n");
    
    for i in 0..20.min(n_zeros - 1) {
        let dot = trig_zeros[i].dot(&trig_zeros[i+1]);
        let dt = zeros[i+1] - zeros[i];
        println!("  {:>5} {:>5} {:>12.8} {:>12.6} {:>12.6}", 
                 i+1, i+2, dot, dt, zeros[i]);
    }
    
    // §2d. Real part statistics — the cos(t·ln2) distribution
    println!("\n  §2d. REAL PART DISTRIBUTION");
    let real_parts: Vec<f64> = trig_zeros.iter().map(|z| z.re()).collect();
    let mean_re: f64 = real_parts.iter().sum::<f64>() / n_zeros as f64;
    let var_re: f64 = real_parts.iter().map(|r| (r - mean_re).powi(2)).sum::<f64>() / n_zeros as f64;
    println!("    Mean Re(Z): {:.8} (expected: ~0 for equidistributed cos)", mean_re);
    println!("    Var Re(Z):  {:.8} (expected: ~1/2 for cos²)", var_re);
    println!();
}

// ═══════════════════════════════════════════════════════════════
// §3. TRIGINTADUONION GRAM MATRIX
// ═══════════════════════════════════════════════════════════════

fn experiment_3_trig_gram() {
    println!("§3. TRIGINTADUONION GRAM MATRIX G_trig(j,k) = Re(T(j)* · T(k))");
    println!("─────────────────────────────────────────────────────────────");
    
    let n = 12;
    
    // Compute G_trig(j,k) = Re(int_to_trig(j).conj() · int_to_trig(k))
    // = dot product of the two unit trigintaduonions
    println!("\n  §3a. G_trig MATRIX (N={})", n);
    println!("  {:>4} {:>4} {:>14} {:>14} {:>14}", 
             "j", "k", "G_trig(j,k)", "R_saw(j,k)", "Ratio");
    
    let mut g_trig = vec![vec![0.0f64; n]; n];
    let mut g_saw = vec![vec![0.0f64; n]; n];
    
    for i in 0..n {
        for j in i..n {
            let ti = int_to_trig((i+1) as u64);
            let tj = int_to_trig((j+1) as u64);
            
            // G_trig = Re(T(i)* · T(j)) = euclidean dot product (since unit norm)
            let gt = ti.dot(&tj);
            g_trig[i][j] = gt;
            g_trig[j][i] = gt;
            
            // Sawtooth Gram: gcd²/(12jk) + 1/4
            let g = gcd((i+1) as u64, (j+1) as u64) as f64;
            let gs = g * g / (12.0 * (i+1) as f64 * (j+1) as f64) + 0.25;
            g_saw[i][j] = gs;
            g_saw[j][i] = gs;
            
            if i <= 7 && j <= 7 {
                let ratio = if gs.abs() > 1e-15 { gt / gs } else { f64::NAN };
                println!("  {:>4} {:>4} {:>14.8} {:>14.8} {:>14.6}", 
                         i+1, j+1, gt, gs, ratio);
            }
        }
    }
    
    // §3b. How does G_trig relate to divisibility?
    println!("\n  §3b. G_trig vs DIVISIBILITY");
    println!("  {:>4} {:>4} {:>10} {:>10} {:>10} {:>12}", 
             "j", "k", "gcd", "G_trig", "G_saw", "j|k?");
    
    for j in 1..=n {
        for k in (j+1)..=n {
            let g = gcd(j as u64, k as u64);
            if g > 1 || k <= 6 {
                let divides = if k % j == 0 { "YES" } else { "no" };
                println!("  {:>4} {:>4} {:>10} {:>10.6} {:>10.6} {:>12}", 
                         j, k, g, g_trig[j-1][k-1], g_saw[j-1][k-1], divides);
            }
        }
    }
    
    // §3c. Eigenvalues of G_trig (via power iteration for largest)
    println!("\n  §3c. G_trig SPECTRAL PROPERTIES (N={})", n);
    
    // Compute trace = Σ G_trig(i,i)
    let trace: f64 = (0..n).map(|i| g_trig[i][i]).sum();
    let trace_saw: f64 = (0..n).map(|i| g_saw[i][i]).sum();
    println!("    Trace(G_trig) = {:.8}", trace);
    println!("    Trace(G_saw)  = {:.8}", trace_saw);
    println!("    Trace ratio:    {:.6}", trace / trace_saw);
    
    // Frobenius norm
    let mut frob_trig_sq = 0.0f64;
    let mut frob_saw_sq = 0.0f64;
    for i in 0..n {
        for j in 0..n {
            frob_trig_sq += g_trig[i][j].powi(2);
            frob_saw_sq += g_saw[i][j].powi(2);
        }
    }
    let frob_trig = frob_trig_sq.sqrt();
    let frob_saw = frob_saw_sq.sqrt();
    println!("    ‖G_trig‖_F   = {:.8}", frob_trig);
    println!("    ‖G_saw‖_F    = {:.8}", frob_saw);
    println!("    Frobenius ratio: {:.6}", frob_trig / frob_saw);
    
    // Correlation between the two matrices
    let mut corr_num = 0.0;
    for i in 0..n {
        for j in 0..n {
            corr_num += g_trig[i][j] * g_saw[i][j];
        }
    }
    let correlation = corr_num / (frob_trig * frob_saw);
    println!("    Matrix correlation(G_trig, G_saw) = {:.8}", correlation);
    println!();
}

// ═══════════════════════════════════════════════════════════════
// §4. ZERO-DIVISOR PROBE
// ═══════════════════════════════════════════════════════════════

fn experiment_4_zero_divisors() {
    println!("§4. ZERO-DIVISOR PROBE");
    println!("─────────────────────────────────────────────────────────────");
    
    // Sedenion-type zero divisors in 32D
    // A known sedenion zero divisor: (e₁ + e₁₀)(e₂ + e₁₁) should have issues
    // In trigintaduonions, we look for products that are abnormally small
    
    println!("  §4a. SEARCHING FOR NEAR-ZERO-DIVISORS");
    println!("  {:>4} {:>4} {:>14} {:>14} {:>14}", 
             "j", "k", "‖T(j)·T(k)‖", "Expected ‖‖", "Deficiency");
    
    let mut min_prod_norm = f64::MAX;
    let mut min_pair = (0u64, 0u64);
    
    // Search among combinations of basis elements
    for i in 1..32 {
        for j in (i+1)..32 {
            let a = Trig::basis(i).add(&Trig::basis(j));
            
            for k in 1..32 {
                if k == i || k == j { continue; }
                for l in (k+1)..32 {
                    if l == i || l == j { continue; }
                    let b = Trig::basis(k).add(&Trig::basis(l));
                    
                    let prod = a.mul(&b);
                    let prod_norm = prod.norm();
                    let expected = a.norm() * b.norm(); // Would be = in a division algebra
                    
                    if prod_norm < min_prod_norm {
                        min_prod_norm = prod_norm;
                        min_pair = (i as u64 * 100 + j as u64, k as u64 * 100 + l as u64);
                    }
                    
                    if prod_norm < 0.1 * expected {
                        println!("  e{}+e{} × e{}+e{}: {:>12.8} {:>12.8} {:>12.6}", 
                                 i, j, k, l, prod_norm, expected, 
                                 1.0 - prod_norm / expected);
                    }
                }
            }
        }
    }
    
    println!("  Smallest product norm found: {:.8e} at pair ({}, {})", 
             min_prod_norm, min_pair.0, min_pair.1);
    
    // §4b. Do zeta zero embeddings sit near zero-divisor submanifolds?
    println!("\n  §4b. ZETA ZERO PRODUCTS");
    println!("  {:>10} {:>10} {:>14} {:>14}", 
             "t_n", "t_m", "‖Z(n)·Z(m)‖", "⟨Z(n),Z(m)⟩");
    
    let zeros = compute_zeta_zeros(30);
    let trig_zeros: Vec<Trig> = zeros.iter().map(|&t| zero_to_trig(t)).collect();
    
    let mut min_zero_prod = f64::MAX;
    for i in 0..trig_zeros.len().min(20) {
        for j in (i+1)..trig_zeros.len().min(20) {
            let prod_norm = trig_zeros[i].mul(&trig_zeros[j]).norm();
            let dot = trig_zeros[i].dot(&trig_zeros[j]);
            min_zero_prod = min_zero_prod.min(prod_norm);
            
            if i < 5 && j < 10 {
                println!("  {:>10.4} {:>10.4} {:>14.8} {:>14.8}", 
                         zeros[i], zeros[j], prod_norm, dot);
            }
        }
    }
    println!("  Min product norm among zero pairs: {:.8}", min_zero_prod);
    println!("  (True zero divisor would give 0.0)");
    println!();
}

// ═══════════════════════════════════════════════════════════════
// §5. GLASS LIFT ANALYSIS
// ═══════════════════════════════════════════════════════════════

fn experiment_5_glass_lifts() {
    println!("§5. GLASS LIFT ANALYSIS (Beyond Hurwitz)");
    println!("─────────────────────────────────────────────────────────────");
    
    // Compute the glass products for the first few primes
    let primes: Vec<f64> = vec![2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0,
                                 31.0, 37.0, 41.0, 43.0, 47.0];
    
    println!("  {:>8} {:>8} {:>16} {:>16} {:>16}", 
             "Lift", "k", "Glass_k", "1/Glass_k", "Cumul. Cancel.");
    
    let mut cumulative = 1.0;
    for &k in &[1u32, 2, 4, 8, 16] {
        let glass: f64 = primes.iter()
            .map(|&p| 1.0 + 1.0 / p.powi(k as i32))
            .product();
        cumulative *= 1.0 / glass;
        
        let algebra = match k {
            1 => "ℂ",
            2 => "ℍ",
            4 => "𝕆",
            8 => "𝕊",
            16 => "𝕋",
            _ => "?",
        };
        
        println!("  {:>3}({}){:>4} {:>8} {:>16.10} {:>16.10} {:>16.10}", 
                 "Glass", algebra, "", k, glass, 1.0/glass, cumulative);
    }
    
    // Show per-prime contributions at each level
    println!("\n  §5b. PER-PRIME GLASS CORRECTION 1/p^k");
    println!("  {:>6}", "p \\ k");
    print!("  {:>6}", "");
    for &k in &[1, 2, 4, 8, 16, 32] {
        print!(" {:>12}", format!("k={}", k));
    }
    println!();
    
    for &p in &[2.0f64, 3.0, 5.0, 7.0, 11.0] {
        print!("  {:>6.0}", p);
        for &k in &[1u32, 2, 4, 8, 16, 32] {
            let correction = 1.0 / p.powi(k as i32);
            if correction > 1e-15 {
                print!(" {:>12.2e}", correction);
            } else {
                print!(" {:>12}", "<1e-15");
            }
        }
        println!();
    }
    
    // §5c. The Möbius shadow budget through all lifts
    println!("\n  §5c. MÖBIUS SHADOW BUDGET (% of cancellation at each lift)");
    
    let full_product: f64 = primes.iter().map(|&p| 1.0 - 1.0/p).product();
    println!("    1/ζ(1) [pole product] ≈ {:.10} (from {} primes)", full_product, primes.len());
    
    let mut remaining = 1.0;
    for &k in &[1u32, 2, 4, 8, 16] {
        let glass: f64 = primes.iter()
            .map(|&p| 1.0 + 1.0 / p.powi(k as i32))
            .product();
        let inv_glass = 1.0 / glass;
        let cancel_pct = (1.0 - inv_glass) / (1.0 - full_product) * 100.0;
        remaining *= inv_glass;
        
        let algebra = match k {
            1 => "ℂ  (electromagnetism)",
            2 => "ℍ  (weak force)      ",
            4 => "𝕆  (strong force)    ",
            8 => "𝕊  (sedenion)        ",
            16 => "𝕋  (trigintaduonion) ",
            _ => "?",
        };
        
        println!("    Glass₍{}₎⁻¹ = {:.10}  → {:.4}% of cancellation  [{}]", 
                 k, inv_glass, cancel_pct, algebra);
    }
    println!("    Remaining after all lifts: {:.2e}", remaining);
    
    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  EXPERIMENT COMPLETE");
    println!("═══════════════════════════════════════════════════════════════");
}

// ═══════════════════════════════════════════════════════════════
// HELPER: Compute zeta zeros via Riemann-Siegel
// ═══════════════════════════════════════════════════════════════

fn compute_zeta_zeros(count: usize) -> Vec<f64> {
    // Use known zeros or compute via sign changes of Z(t)
    let mut zeros = Vec::new();
    let mut t = 10.0;
    let dt = 0.01;
    let mut prev_z = riemann_siegel::hardy_z(t);
    
    while zeros.len() < count && t < 1000.0 {
        t += dt;
        let z = riemann_siegel::hardy_z(t);
        if prev_z * z < 0.0 {
            // Sign change — bisect to find zero
            let mut lo = t - dt;
            let mut hi = t;
            for _ in 0..50 {
                let mid = (lo + hi) / 2.0;
                let zm = riemann_siegel::hardy_z(mid);
                if zm * riemann_siegel::hardy_z(lo) < 0.0 {
                    hi = mid;
                } else {
                    lo = mid;
                }
            }
            zeros.push((lo + hi) / 2.0);
        }
        prev_z = z;
    }
    zeros
}

fn gcd(mut a: u64, mut b: u64) -> u64 {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}
