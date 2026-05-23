/// BASIS GAP PROBE: Sawtooth {kt} vs BD {1/(kx)}
///
/// The Cathedral discovered that Path D has a genuine basis mismatch:
/// - Smith witness: d²_saw = 4/(4+σ) → 0  in the {kt} basis
/// - NB converse: needs d²_BD → 0  in the {1/(kx)} basis
///
/// This experiment quantifies the gap by computing both Gram matrices
/// and testing whether Smith coefficients "transfer" between bases.
///
/// Questions:
/// 1. How different are the two Gram matrices entry-by-entry?
/// 2. Do the Smith coefficients give small d²_BD anyway?
/// 3. Is there a simple transformation between them?

use std::f64::consts::PI;

/// gcd using Euclidean algorithm
fn gcd(mut a: u64, mut b: u64) -> u64 {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

/// Euler's totient function φ(n)
fn euler_phi(n: u64) -> u64 {
    if n == 0 { return 0; }
    let mut result = n;
    let mut m = n;
    let mut p = 2u64;
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

/// Jordan's totient J₂(n) = n² · Π_{p|n} (1 - 1/p²)
fn jordan2(n: u64) -> f64 {
    if n == 0 { return 0.0; }
    let mut result = (n * n) as f64;
    let mut m = n;
    let mut p = 2u64;
    while p * p <= m {
        if m % p == 0 {
            while m % p == 0 { m /= p; }
            result *= 1.0 - 1.0 / (p * p) as f64;
        }
        p += 1;
    }
    if m > 1 { result *= 1.0 - 1.0 / (m * m) as f64; }
    result
}

/// Möbius function μ(n)
fn moebius(n: u64) -> i64 {
    if n == 1 { return 1; }
    let mut m = n;
    let mut num_factors = 0i64;
    let mut p = 2u64;
    while p * p <= m {
        if m % p == 0 {
            m /= p;
            if m % p == 0 { return 0; } // p² | n
            num_factors += 1;
        }
        p += 1;
    }
    if m > 1 { num_factors += 1; }
    if num_factors % 2 == 0 { 1 } else { -1 }
}

/// Sawtooth Gram entry: G⁽¹⁾(j,k) = gcd(j,k)²/(12jk) + 1/4
/// = ∫₀¹ {jt}·{kt} dt
fn sawtooth_gram(j: u64, k: u64) -> f64 {
    let g = gcd(j, k) as f64;
    g * g / (12.0 * j as f64 * k as f64) + 0.25
}

/// Ramanujan entry: R(j,k) = gcd(j,k)²/(12jk)
fn ramanujan_entry(j: u64, k: u64) -> f64 {
    let g = gcd(j, k) as f64;
    g * g / (12.0 * j as f64 * k as f64)
}

/// BD Gram entry: gramEntry(j,k) = ∫₀¹ {1/(jx)}·{1/(kx)} dx
/// Computed numerically via high-precision quadrature
fn bd_gram_entry(j: u64, k: u64, num_points: usize) -> f64 {
    // Simpson's rule on (ε, 1) to avoid x=0 singularity
    let eps = 1e-10;
    let n = if num_points % 2 == 0 { num_points } else { num_points + 1 };
    let h = (1.0 - eps) / n as f64;
    
    let f = |x: f64| -> f64 {
        if x <= 0.0 { return 0.0; }
        let fj = (1.0 / (j as f64 * x)).fract();
        let fk = (1.0 / (k as f64 * x)).fract();
        // Handle negative fract (Rust's fract can be negative for negative values)
        let fj = if fj < 0.0 { fj + 1.0 } else { fj };
        let fk = if fk < 0.0 { fk + 1.0 } else { fk };
        fj * fk
    };
    
    let mut sum = f(eps) + f(1.0);
    for i in 1..n {
        let x = eps + i as f64 * h;
        let weight = if i % 2 == 0 { 2.0 } else { 4.0 };
        sum += weight * f(x);
    }
    sum * h / 3.0
}

/// Smith witness w_k = 12k · Σ_{m: (k·m)≤N} μ(m)·φ(k·m)/J₂(k·m)
fn smith_witness(n_val: u64, k: u64) -> f64 {
    let mut sum = 0.0;
    let max_m = n_val / k;
    for m in 1..=max_m {
        let km = k * m;
        let mu = moebius(m);
        if mu == 0 { continue; }
        let phi = euler_phi(km) as f64;
        let j2 = jordan2(km);
        if j2 > 0.0 {
            sum += mu as f64 * phi / j2;
        }
    }
    12.0 * k as f64 * sum
}

/// Sawtooth mean vector: b_k = ∫₀¹ {kt} dt = 1/2
fn sawtooth_mean(_k: u64) -> f64 {
    0.5
}

/// BD mean vector: b_k = ∫₀¹ {1/(kx)} dx (numerical)
fn bd_mean(k: u64, num_points: usize) -> f64 {
    let eps = 1e-10;
    let n = if num_points % 2 == 0 { num_points } else { num_points + 1 };
    let h = (1.0 - eps) / n as f64;
    
    let f = |x: f64| -> f64 {
        if x <= 0.0 { return 0.0; }
        let fk = (1.0 / (k as f64 * x)).fract();
        if fk < 0.0 { fk + 1.0 } else { fk }
    };
    
    let mut sum = f(eps) + f(1.0);
    for i in 1..n {
        let x = eps + i as f64 * h;
        let weight = if i % 2 == 0 { 2.0 } else { 4.0 };
        sum += weight * f(x);
    }
    sum * h / 3.0
}

fn main() {
    println!("═══════════════════════════════════════════════════════════");
    println!("  BASIS GAP PROBE: Sawtooth {{kt}} vs BD {{1/(kx)}}");
    println!("═══════════════════════════════════════════════════════════\n");
    
    let quad_points = 100_000; // quadrature points for BD integrals
    
    // ═══════════════════════════════════════════════════
    // §1. GRAM MATRIX COMPARISON (small N)
    // ═══════════════════════════════════════════════════
    let n_compare = 8;
    println!("§1. GRAM MATRIX COMPARISON (N = {})", n_compare);
    println!("─────────────────────────────────────────────────");
    println!("{:>4} {:>4} {:>14} {:>14} {:>12} {:>10}", 
             "j", "k", "G_saw(j,k)", "G_BD(j,k)", "Ratio", "Diff");
    
    let mut max_ratio = 0.0f64;
    let mut min_ratio = f64::MAX;
    
    for j in 1..=n_compare {
        for k in j..=n_compare {
            let g_saw = sawtooth_gram(j, k);
            let g_bd = bd_gram_entry(j, k, quad_points);
            let ratio = if g_bd.abs() > 1e-15 { g_saw / g_bd } else { f64::NAN };
            let diff = g_saw - g_bd;
            
            if ratio.is_finite() {
                max_ratio = max_ratio.max(ratio);
                min_ratio = min_ratio.min(ratio);
            }
            
            if j == k || (j <= 4 && k <= 4) {
                println!("{:>4} {:>4} {:>14.8} {:>14.8} {:>12.6} {:>10.6}", 
                         j, k, g_saw, g_bd, ratio, diff);
            }
        }
    }
    println!("\nRatio range: [{:.6}, {:.6}]", min_ratio, max_ratio);
    
    // ═══════════════════════════════════════════════════
    // §2. MEAN VECTOR COMPARISON
    // ═══════════════════════════════════════════════════
    println!("\n§2. MEAN VECTOR COMPARISON");
    println!("─────────────────────────────────────────────────");
    println!("{:>4} {:>14} {:>14} {:>12}", "k", "b_saw(k)", "b_BD(k)", "Ratio");
    
    for k in 1..=12u64 {
        let b_saw = sawtooth_mean(k);
        let b_bd = bd_mean(k, quad_points);
        let ratio = b_saw / b_bd;
        println!("{:>4} {:>14.8} {:>14.8} {:>12.6}", k, b_saw, b_bd, ratio);
    }
    
    // ═══════════════════════════════════════════════════
    // §3. SMITH WITNESS + DISTANCE IN BOTH BASES
    // ═══════════════════════════════════════════════════
    println!("\n§3. SMITH WITNESS DISTANCES IN BOTH BASES");
    println!("─────────────────────────────────────────────────");
    println!("{:>6} {:>12} {:>14} {:>14} {:>10}", 
             "N", "σ(N)", "d²_saw", "d²_BD(smith)", "Ratio");
    
    for &n_val in &[6u64, 10, 15, 20, 30, 40, 50, 60] {
        // Compute Smith witness
        let mut w: Vec<f64> = Vec::new();
        let mut sigma = 0.0;
        for k in 1..=n_val {
            let wk = smith_witness(n_val, k);
            w.push(wk);
            sigma += wk;
        }
        
        // Sawtooth distance: d²_saw = 4/(4+σ)
        let d2_saw = 4.0 / (4.0 + sigma);
        
        // BD distance using Smith coefficients c_k = w_k/2:
        // d²_BD = 1 - 2·Σ c_k·b_BD(k) + Σᵢⱼ cᵢ·G_BD(i,j)·cⱼ
        let c: Vec<f64> = w.iter().map(|&wk| wk / 2.0).collect();
        
        let mut dot_cb = 0.0;
        for k in 0..n_val as usize {
            dot_cb += c[k] * bd_mean((k + 1) as u64, quad_points);
        }
        
        let mut quad_form = 0.0;
        for i in 0..n_val as usize {
            for j in 0..n_val as usize {
                let g = bd_gram_entry((i + 1) as u64, (j + 1) as u64, 
                                       if n_val <= 20 { quad_points } else { 10_000 });
                quad_form += c[i] * g * c[j];
            }
        }
        
        let d2_bd = 1.0 - 2.0 * dot_cb + quad_form;
        let ratio = if d2_saw.abs() > 1e-15 { d2_bd / d2_saw } else { f64::NAN };
        
        println!("{:>6} {:>12.2} {:>14.8} {:>14.8} {:>10.4}", 
                 n_val, sigma, d2_saw, d2_bd, ratio);
    }
    
    // ═══════════════════════════════════════════════════
    // §4. EIGENVALUE COMPARISON
    // ═══════════════════════════════════════════════════
    println!("\n§4. DIAGONAL COMPARISON (Gram diagonals)");
    println!("─────────────────────────────────────────────────");
    println!("{:>4} {:>14} {:>14} {:>12} {:>20}", 
             "k", "G_saw(k,k)", "G_BD(k,k)", "Ratio", "Note");
    
    for k in 1..=20u64 {
        let g_saw_diag = sawtooth_gram(k, k);
        let g_bd_diag = bd_gram_entry(k, k, quad_points);
        let ratio = g_saw_diag / g_bd_diag;
        let note = if k <= 3 {
            format!("gcd²/(12k²)+1/4 = {:.6}", 1.0/(12.0 * k as f64 * k as f64) + 0.25)
        } else {
            String::new()
        };
        println!("{:>4} {:>14.8} {:>14.8} {:>12.6} {:>20}", 
                 k, g_saw_diag, g_bd_diag, ratio, note);
    }
    
    // ═══════════════════════════════════════════════════
    // §5. "INVERT SMITH": SOLVE G_BD · v = b_BD DIRECTLY
    // ═══════════════════════════════════════════════════
    println!("\n§5. INVERTED SMITH: Optimal BD coefficients via G_BD⁻¹·b_BD");
    println!("─────────────────────────────────────────────────────────────");
    
    for &n_val in &[6u64, 10, 15, 20, 30] {
        let n = n_val as usize;
        
        // Build G_BD matrix
        let qp = if n_val <= 15 { quad_points } else { 20_000 };
        let mut g_bd = vec![vec![0.0f64; n]; n];
        for i in 0..n {
            for j in i..n {
                let val = bd_gram_entry((i+1) as u64, (j+1) as u64, qp);
                g_bd[i][j] = val;
                g_bd[j][i] = val;
            }
        }
        
        // Build b_BD vector
        let mut b_bd = vec![0.0f64; n];
        for k in 0..n {
            b_bd[k] = bd_mean((k+1) as u64, qp);
        }
        
        // Solve G_BD · v = b_BD via Gaussian elimination with pivoting
        let mut aug = vec![vec![0.0f64; n + 1]; n];
        for i in 0..n {
            for j in 0..n { aug[i][j] = g_bd[i][j]; }
            aug[i][n] = b_bd[i];
        }
        
        for col in 0..n {
            // Partial pivoting
            let mut max_row = col;
            let mut max_val = aug[col][col].abs();
            for row in (col+1)..n {
                if aug[row][col].abs() > max_val {
                    max_val = aug[row][col].abs();
                    max_row = row;
                }
            }
            aug.swap(col, max_row);
            
            let pivot = aug[col][col];
            if pivot.abs() < 1e-15 { continue; }
            
            for row in (col+1)..n {
                let factor = aug[row][col] / pivot;
                for j in col..=n {
                    aug[row][j] -= factor * aug[col][j];
                }
            }
        }
        
        // Back-substitution
        let mut v_bd = vec![0.0f64; n];
        for i in (0..n).rev() {
            let mut sum = aug[i][n];
            for j in (i+1)..n {
                sum -= aug[i][j] * v_bd[j];
            }
            v_bd[i] = sum / aug[i][i];
        }
        
        // Compute d²_BD = 1 - 2·bᵀv + vᵀGv = 1 - bᵀv (when Gv = b)
        let mut btv = 0.0;
        for k in 0..n { btv += b_bd[k] * v_bd[k]; }
        let d2_bd_opt = 1.0 - btv;
        
        // Also compute Smith d² for comparison
        let mut sigma = 0.0;
        let mut w_smith = vec![0.0f64; n];
        for k in 0..n {
            w_smith[k] = smith_witness(n_val, (k+1) as u64);
            sigma += w_smith[k];
        }
        let d2_saw = 4.0 / (4.0 + sigma);
        
        println!("\n  N = {}:  d²_saw = {:.8},  d²_BD(optimal) = {:.8}", 
                 n_val, d2_saw, d2_bd_opt);
        
        // Show first few coefficients side by side
        println!("  {:>4} {:>14} {:>14} {:>12}", 
                 "k", "v_BD(k)", "w_smith(k)/2", "Ratio");
        let show = n.min(10);
        for k in 0..show {
            let ratio = if (w_smith[k]/2.0).abs() > 1e-15 { 
                v_bd[k] / (w_smith[k]/2.0) 
            } else { f64::NAN };
            println!("  {:>4} {:>14.6} {:>14.6} {:>12.6}", 
                     k+1, v_bd[k], w_smith[k]/2.0, ratio);
        }
        
        // Compute σ_BD = Σ optimal BD coefficients (analog of Smith σ)
        let sigma_bd: f64 = v_bd.iter().sum();
        println!("  Σv_BD = {:.4},  σ_smith = {:.4},  ratio = {:.6}", 
                 sigma_bd, sigma, sigma_bd / sigma);
    }
    
    // ═══════════════════════════════════════════════════
    // §6. CONCLUSION
    // ═══════════════════════════════════════════════════
    println!("\n═══════════════════════════════════════════════════════════");
    println!("  CONCLUSION");
    println!("═══════════════════════════════════════════════════════════");
    println!("\n§3 showed: Smith coefficients DIVERGE in BD basis (ratio ~ N²)");
    println!("§5 shows:  Optimal BD coefficients give d²_BD that should → 0 iff RH");
    println!("\nThe question: do the optimal BD coefficients have");
    println!("multiplicative structure like Smith? If so, there might be");
    println!("a 'BD-Smith identity' waiting to be discovered...");
}
