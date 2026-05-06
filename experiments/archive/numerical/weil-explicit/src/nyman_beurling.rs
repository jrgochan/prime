use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════
// PROJECT HYPERZETA: Nyman-Beurling-Báez-Duarte Criterion
//
// RH ⟺ lim_{N→∞} d_N² = 0
//
// where d_N² measures how well 1 can be approximated by
// integer-dilated fractional parts in L²(0,1).
//
// We compute d_N² via the Gram matrix of inner products,
// which involve values of ζ(s).
// ══════════════════════════════════════════════════════════

// --- Zeta function for real s > 1 ---

fn zeta_real(s: f64, n_terms: usize) -> f64 {
    // Direct summation with Euler-Maclaurin correction
    let mut sum = 0.0;
    for n in 1..=n_terms {
        sum += (n as f64).powf(-s);
    }
    // Euler-Maclaurin remainder: ∫_N^∞ x^{-s} dx = N^{1-s}/(s-1)
    let n = n_terms as f64;
    sum += n.powf(1.0 - s) / (s - 1.0);
    sum += 0.5 * n.powf(-s); // B₁ term
    sum += s / 12.0 * n.powf(-s - 1.0); // B₂ term
    sum
}

// --- Zero-finding (from main engine) ---

fn rs_theta(t: f64) -> f64 {
    let t2 = t / 2.0;
    let mut theta = t2 * (t2 / PI).ln() - t2 - PI / 8.0;
    if t > 10.0 {
        let ti = 1.0 / t;
        theta += ti / 48.0 + 7.0 * ti.powi(3) / 5760.0;
    } else if t > 1.0 {
        theta += 1.0 / (48.0 * t);
    }
    theta
}

fn hardy_z(t: f64) -> f64 {
    let n_max = ((t / (2.0 * PI)).sqrt()).floor() as usize;
    if n_max == 0 { return 0.0; }
    let theta = rs_theta(t);
    let mut sum = 0.0;
    for n in 1..=n_max {
        let nf = n as f64;
        sum += (theta - t * nf.ln()).cos() / nf.sqrt();
    }
    sum *= 2.0;
    let p = ((t / (2.0 * PI)).sqrt()).fract();
    let c0 = (PI / 8.0 * (2.0 * p - 1.0).powi(2)).cos()
        / (PI * 0.5 * (2.0 * p - 1.0)).cos();
    let tau = (t / (2.0 * PI)).sqrt();
    sum += (-1i32).pow(n_max as u32 + 1) as f64 * tau.powf(-0.5) * c0;
    sum
}

fn find_zeros(t_end: f64) -> Vec<f64> {
    let mut zeros = Vec::new();
    let mut t = 14.0;
    let mut z_prev = hardy_z(t);
    while t < t_end {
        let sp = 2.0 * PI / (t / (2.0 * PI)).ln();
        let dt = (sp * 0.25).max(0.01).min(0.5);
        let t_next = t + dt;
        let z_next = hardy_z(t_next);
        if z_prev * z_next < 0.0 {
            let (mut lo, mut hi) = (t, t_next);
            let mut zlo = z_prev;
            for _ in 0..64 {
                let mid = (lo + hi) / 2.0;
                let zm = hardy_z(mid);
                if zlo * zm < 0.0 { hi = mid; } else { lo = mid; zlo = zm; }
            }
            zeros.push((lo + hi) / 2.0);
        }
        t = t_next;
        z_prev = z_next;
    }
    zeros
}

// --- Gram matrix for Nyman-Beurling ---
// Inner product in L²(0,1):
//   ⟨ρ_j, ρ_k⟩ = ∫₀¹ {j/x}·{k/x} dx
// where {y} = y - floor(y) is the fractional part.
// This can be computed as:
//   ⟨ρ_j, ρ_k⟩ = (j·k) · [log(gcd(j,k)²/(j·k)) + 2γ + 1]/(j·k)
//                  ... (complex formula involving harmonic numbers)
// For simplicity, we use numerical integration.

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

/// Compute ⟨ρ_j, ρ_k⟩ = ∫₀¹ {j/x}·{k/x} dx numerically
fn inner_product(j: usize, k: usize, n_points: usize) -> f64 {
    let mut sum = 0.0;
    let dx = 1.0 / n_points as f64;
    for i in 1..n_points { // skip x=0 (singularity)
        let x = i as f64 * dx;
        let fj = frac_part(j as f64 / x);
        let fk = frac_part(k as f64 / x);
        sum += fj * fk;
    }
    sum * dx
}

/// Compute ⟨1, ρ_k⟩ = ∫₀¹ {k/x} dx
fn inner_with_one(k: usize, n_points: usize) -> f64 {
    let mut sum = 0.0;
    let dx = 1.0 / n_points as f64;
    for i in 1..n_points {
        let x = i as f64 * dx;
        sum += frac_part(k as f64 / x);
    }
    sum * dx
}

/// Solve Ax = b using Gaussian elimination
fn solve_linear(a: &[Vec<f64>], b: &[f64]) -> Option<Vec<f64>> {
    let n = b.len();
    let mut aug: Vec<Vec<f64>> = a.iter().enumerate().map(|(i, row)| {
        let mut r = row.clone();
        r.push(b[i]);
        r
    }).collect();

    for col in 0..n {
        // Pivot
        let mut max_row = col;
        for row in (col+1)..n {
            if aug[row][col].abs() > aug[max_row][col].abs() { max_row = row; }
        }
        aug.swap(col, max_row);
        if aug[col][col].abs() < 1e-15 { return None; }

        for row in (col+1)..n {
            let factor = aug[row][col] / aug[col][col];
            for j in col..=n {
                aug[row][j] -= factor * aug[col][j];
            }
        }
    }

    let mut x = vec![0.0; n];
    for i in (0..n).rev() {
        x[i] = aug[i][n];
        for j in (i+1)..n {
            x[i] -= aug[i][j] * x[j];
        }
        x[i] /= aug[i][i];
    }
    Some(x)
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  PROJECT HYPERZETA: Nyman-Beurling-Báez-Duarte Criterion");
    println!("  RH ⟺ d_N → 0 as N → ∞");
    println!("═══════════════════════════════════════════════════════════════");

    // Phase 1: Find zeros
    let t_max = 50_000.0;
    println!("\n[1/4] Finding zeros up to t = {:.0}...", t_max);
    let start = std::time::Instant::now();
    let zeros = find_zeros(t_max);
    println!("  Found {} zeros in {:.1}s", zeros.len(), start.elapsed().as_secs_f64());

    // Phase 2: Compute the "explicit formula" check
    // ψ(x) = x - Σ_ρ x^ρ/ρ - log(2π) - ...
    println!("\n[2/4] ═══ Explicit Formula Check ═══");
    println!("  How well do zeros predict prime distribution?\n");
    println!("  {:>10}  {:>12}  {:>12}  {:>12}  {:>10}",
        "x", "ψ(x)", "formula", "error", "rel_err%");

    let test_points = [100.0, 500.0, 1000.0, 5000.0, 10000.0, 50000.0, 100000.0];

    for &x in &test_points {
        // Compute actual ψ(x) = Σ_{p^k ≤ x} log p
        let psi_actual = compute_psi(x);

        // Compute explicit formula: x - Σ_ρ x^ρ/ρ
        let mut psi_formula = x;
        for &gamma in &zeros {
            // Each zero ρ = 1/2 + iγ contributes x^ρ/ρ + x^{ρ̄}/ρ̄
            // = 2·Re[x^{1/2+iγ} / (1/2+iγ)]
            let x_half = x.sqrt();
            let log_x = x.ln();
            let cos_part = (gamma * log_x).cos();
            let sin_part = (gamma * log_x).sin();
            // x^{1/2+iγ} = x^{1/2} · (cos(γ·ln x) + i·sin(γ·ln x))
            // 1/(1/2+iγ) = (1/2-iγ)/(1/4+γ²)
            let denom = 0.25 + gamma * gamma;
            let re_contrib = x_half * (0.5 * cos_part + gamma * sin_part) / denom;
            psi_formula -= 2.0 * re_contrib;
        }
        // Subtract log(2π) and trivial zero contribution
        psi_formula -= (2.0 * PI).ln();

        let error = (psi_formula - psi_actual).abs();
        let rel_err = if psi_actual.abs() > 0.1 { error / psi_actual * 100.0 } else { 0.0 };

        println!("  {:10.0}  {:12.2}  {:12.2}  {:12.2}  {:9.3}%",
            x, psi_actual, psi_formula, error, rel_err);
    }

    // Phase 3: Nyman-Beurling distance d_N
    println!("\n[3/4] ═══ Nyman-Beurling Distance d_N² ═══");
    println!("  RH ⟺ d_N → 0\n");

    let n_int = 50_000; // integration points
    let max_n = 30;

    // Precompute inner products
    println!("  Computing Gram matrix (N_max = {}, {} integration points)...", max_n, n_int);
    let start = std::time::Instant::now();

    // ⟨ρ_j, ρ_k⟩ for j,k = 2..max_n
    let dim = max_n - 1; // indices 2..max_n
    let mut gram = vec![vec![0.0; dim]; dim];
    let mut rhs = vec![0.0; dim];

    for j in 0..dim {
        rhs[j] = inner_with_one(j + 2, n_int);
        for k in j..dim {
            let val = inner_product(j + 2, k + 2, n_int);
            gram[j][k] = val;
            gram[k][j] = val;
        }
    }
    let gram_time = start.elapsed();
    println!("  Gram matrix computed in {:.1}s", gram_time.as_secs_f64());

    // ⟨1, 1⟩ = 1
    let one_norm_sq = 1.0;

    println!("\n  {:>4}  {:>14}  {:>14}  {:>12}", "N", "d_N²", "d_N", "converging?");

    let mut prev_d = f64::MAX;
    for n in 2..=max_n {
        let dim_n = n - 1;
        // Extract sub-Gram matrix
        let sub_gram: Vec<Vec<f64>> = gram[..dim_n].iter()
            .map(|row| row[..dim_n].to_vec()).collect();
        let sub_rhs: Vec<f64> = rhs[..dim_n].to_vec();

        // d_N² = ⟨1,1⟩ - ⟨1,ρ⟩ᵀ G⁻¹ ⟨1,ρ⟩
        if let Some(coeffs) = solve_linear(&sub_gram, &sub_rhs) {
            let d_sq = one_norm_sq - coeffs.iter().zip(sub_rhs.iter())
                .map(|(c, r)| c * r).sum::<f64>();
            let d = if d_sq > 0.0 { d_sq.sqrt() } else { 0.0 };
            let converging = if d < prev_d { "↓ yes" } else { "↑ no" };
            println!("  {:4}  {:14.10}  {:14.10}  {:>12}", n, d_sq, d, converging);
            prev_d = d;
        } else {
            println!("  {:4}  {:>14}  {:>14}  {:>12}", n, "SINGULAR", "-", "-");
        }
    }

    // Phase 4: Vasyunin sum (direct zero connection)
    println!("\n[4/4] ═══ Vasyunin Sum ═══");
    println!("  V(T) = Σ_{{|γ|≤T}} 1/(1/4 + γ²)");
    println!("  Under RH: V(T) → 2 + γ_E - log(4π) ≈ 0.0461...\n");

    let target = 2.0 + 0.5772156649 - (4.0 * PI).ln();
    println!("  Target value: {:.10}", target);
    println!();
    println!("  {:>10}  {:>8}  {:>14}  {:>14}  {:>10}",
        "T", "zeros", "V(T)", "|V(T)-target|", "converging?");

    let mut prev_err = f64::MAX;
    let checkpoints = [100.0, 500.0, 1000.0, 5000.0, 10000.0, 20000.0, 30000.0, 40000.0, 50000.0];
    let mut zero_idx = 0;
    let mut vasyunin = 0.0;

    for &t_check in &checkpoints {
        while zero_idx < zeros.len() && zeros[zero_idx] <= t_check {
            let gamma = zeros[zero_idx];
            vasyunin += 1.0 / (0.25 + gamma * gamma);
            zero_idx += 1;
        }
        let err = (vasyunin - target).abs();
        let conv = if err < prev_err { "↓" } else { "↑" };
        println!("  {:10.0}  {:8}  {:14.10}  {:14.10}  {:>10}",
            t_check, zero_idx, vasyunin, err, conv);
        prev_err = err;
    }

    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  Analysis complete. See artifact for interpretation.");
    println!("═══════════════════════════════════════════════════════════════");
}

// --- Helper: compute ψ(x) = Σ_{p^k ≤ x} log(p) via sieve ---
fn compute_psi(x: f64) -> f64 {
    let limit = x as usize;
    if limit < 2 { return 0.0; }

    // Simple sieve of Eratosthenes
    let mut is_prime = vec![true; limit + 1];
    is_prime[0] = false;
    if limit >= 1 { is_prime[1] = false; }
    for i in 2..=((limit as f64).sqrt() as usize) {
        if is_prime[i] {
            for j in (i*i..=limit).step_by(i) {
                is_prime[j] = false;
            }
        }
    }

    let mut psi = 0.0;
    for p in 2..=limit {
        if is_prime[p] {
            let log_p = (p as f64).ln();
            let mut pk = p;
            while pk <= limit {
                psi += log_p;
                if pk > limit / p { break; }
                pk *= p;
            }
        }
    }
    psi
}
