use rayon::prelude::*;

// ══════════════════════════════════════════════════════════
// SIGN STRUCTURE & CANCELLATION ANALYSIS
//
// WHY does the cancellation in gᵀv_min improve with N?
// Hypothesis A: v_min becomes more orthogonal to smooth functions
// Hypothesis B: oscillation period grows → more complete cycles
//
// We measure:
// 1. Sign changes of v_min vs N
// 2. Partial sum CDF: S(K) = Σ_{k≤K} v[k]
// 3. Cancellation ratio at each N
// 4. Correlation of v_min with divisor functions
// ══════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    let jf = j as f64;
    let kf = k as f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

fn lu_decompose(a: &mut Vec<Vec<f64>>) -> Vec<usize> {
    let n = a.len();
    let mut piv: Vec<usize> = (0..n).collect();
    for col in 0..n {
        let mut max_row = col;
        for row in (col+1)..n {
            if a[row][col].abs() > a[max_row][col].abs() { max_row = row; }
        }
        if max_row != col { a.swap(col, max_row); piv.swap(col, max_row); }
        if a[col][col].abs() < 1e-15 { continue; }
        for row in (col+1)..n {
            a[row][col] /= a[col][col];
            let f = a[row][col];
            for j in (col+1)..n { a[row][j] -= f * a[col][j]; }
        }
    }
    piv
}

fn lu_solve(lu: &[Vec<f64>], piv: &[usize], b: &[f64]) -> Vec<f64> {
    let n = b.len();
    let mut x: Vec<f64> = piv.iter().map(|&i| b[i]).collect();
    for i in 1..n { for j in 0..i { let f = lu[i][j]; x[i] -= f * x[j]; } }
    for i in (0..n).rev() {
        for j in (i+1)..n { x[i] -= lu[i][j] * x[j]; }
        x[i] /= lu[i][i];
    }
    x
}

fn smallest_eigenvector(mat: &[Vec<f64>], n_iter: usize) -> (f64, Vec<f64>) {
    let n = mat.len();
    if n == 1 { return (mat[0][0], vec![1.0]); }
    let mut lu = mat.to_vec();
    let piv = lu_decompose(&mut lu);
    let mut v = vec![1.0 / (n as f64).sqrt(); n];
    for _ in 0..n_iter {
        let w = lu_solve(&lu, &piv, &v);
        let norm: f64 = w.iter().map(|x| x*x).sum::<f64>().sqrt();
        if norm < 1e-15 { break; }
        v = w.iter().map(|x| x / norm).collect();
    }
    let sign = if v[0] >= 0.0 { 1.0 } else { -1.0 };
    let v_signed: Vec<f64> = v.iter().map(|x| x * sign).collect();
    let mut w = vec![0.0; n];
    for i in 0..n { for j in 0..n { w[i] += mat[i][j] * v_signed[j]; } }
    let lam: f64 = v_signed.iter().zip(w.iter()).map(|(a, b)| a * b).sum();
    (lam, v_signed)
}

fn num_divisors(n: usize) -> usize {
    let mut count = 0;
    let mut d = 1;
    while d * d <= n { if n % d == 0 { count += 2; if d * d == n { count -= 1; } } d += 1; }
    count
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  SIGN STRUCTURE & CANCELLATION ANALYSIS");
    println!("═══════════════════════════════════════════════════════════════");

    let n_pts = 200_000;
    let max_n: usize = 1000;
    let start = std::time::Instant::now();

    println!("\n[1/5] Computing {}×{} Gram matrix...", max_n-1, max_n-1);
    let dim = max_n - 1;
    let gram_upper: Vec<Vec<f64>> = (0..dim).into_par_iter().map(|j| {
        let mut row = vec![0.0; dim];
        for k in j..dim { row[k] = gram_entry(j + 2, k + 2, n_pts); }
        row
    }).collect();
    let mut gram = vec![vec![0.0; dim]; dim];
    for j in 0..dim {
        for k in j..dim {
            gram[j][k] = gram_upper[j][k];
            gram[k][j] = gram_upper[j][k];
        }
    }
    println!("  Done in {:.1}s", start.elapsed().as_secs_f64());

    // ────────────────────────────────────────────────────────
    // Phase 2: Sign structure at multiple N
    // ────────────────────────────────────────────────────────
    println!("\n[2/5] Sign change analysis...\n");
    let n_values: Vec<usize> = vec![
        50, 100, 150, 200, 300, 400, 500, 600, 700, 800, 900, 999,
    ];

    println!("  {:>5} {:>8} {:>8} {:>10} {:>10} {:>10} {:>12} {:>10}",
        "N", "#sign_ch", "ratio", "max|S(K)|", "S(N)", "cancel_×",
        "corr(v,d)", "corr(v,μ)");

    for &n in &n_values {
        let d = n - 1;
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let (_, v) = smallest_eigenvector(&sub, 500);

        // Sign changes
        let sign_changes: usize = v.windows(2)
            .filter(|w| w[0] * w[1] < 0.0).count();

        // Partial sums S(K) = Σ_{k≤K} v[k]
        let mut partial_sums = vec![0.0f64; v.len()];
        partial_sums[0] = v[0];
        for i in 1..v.len() { partial_sums[i] = partial_sums[i-1] + v[i]; }

        let max_partial = partial_sums.iter().map(|x| x.abs())
            .fold(0.0f64, f64::max);
        let final_sum = *partial_sums.last().unwrap();

        // Cancellation ratio
        let cancel = if final_sum.abs() > 1e-15 {
            max_partial / final_sum.abs()
        } else { f64::INFINITY };

        // Cross-correlation g and compute gᵀv
        let g: Vec<f64> = (0..d).map(|k| gram[n-1][k]).collect();
        let g_norm: f64 = g.iter().map(|x| x*x).sum::<f64>().sqrt();
        let gv: f64 = g.iter().zip(v.iter()).map(|(a,b)| a*b).sum();

        // gᵀv cancellation: max partial gv / |gv|
        let mut gv_partials = vec![0.0f64; v.len()];
        gv_partials[0] = g[0] * v[0];
        for i in 1..v.len() { gv_partials[i] = gv_partials[i-1] + g[i] * v[i]; }
        let max_gv_partial = gv_partials.iter().map(|x| x.abs())
            .fold(0.0f64, f64::max);
        let gv_cancel = if gv.abs() > 1e-15 {
            max_gv_partial / gv.abs()
        } else { f64::INFINITY };

        // Correlation with divisor function d(k)
        let div_vec: Vec<f64> = (0..d).map(|i| num_divisors(i + 2) as f64).collect();
        let div_mean: f64 = div_vec.iter().sum::<f64>() / d as f64;
        let v_mean: f64 = v.iter().sum::<f64>() / d as f64;
        let cov_dv: f64 = v.iter().zip(div_vec.iter())
            .map(|(vi, di)| (vi - v_mean) * (di - div_mean)).sum::<f64>() / d as f64;
        let std_v: f64 = (v.iter().map(|x| (x - v_mean).powi(2)).sum::<f64>() / d as f64).sqrt();
        let std_d: f64 = (div_vec.iter().map(|x| (x - div_mean).powi(2)).sum::<f64>() / d as f64).sqrt();
        let corr_dv = cov_dv / (std_v * std_d);

        // Correlation with Möbius-like function μ̃(k) = (-1)^{Ω(k)}
        let mu_vec: Vec<f64> = (0..d).map(|i| {
            let k = i + 2;
            let mut omega = 0;
            let mut m = k;
            let mut p = 2;
            while p * p <= m {
                while m % p == 0 { omega += 1; m /= p; }
                p += 1;
            }
            if m > 1 { omega += 1; }
            if omega % 2 == 0 { 1.0 } else { -1.0 }
        }).collect();
        let mu_mean: f64 = mu_vec.iter().sum::<f64>() / d as f64;
        let cov_mv: f64 = v.iter().zip(mu_vec.iter())
            .map(|(vi, mi)| (vi - v_mean) * (mi - mu_mean)).sum::<f64>() / d as f64;
        let std_m: f64 = (mu_vec.iter().map(|x| (x - mu_mean).powi(2)).sum::<f64>() / d as f64).sqrt();
        let corr_mv = cov_mv / (std_v * std_m);

        println!("  {:5} {:8} {:8.4} {:10.4} {:10.6} {:10.0} {:12.6} {:10.6}",
            n, sign_changes, sign_changes as f64 / d as f64,
            max_partial, final_sum, cancel.min(999999.0), corr_dv, corr_mv);
    }

    // ────────────────────────────────────────────────────────
    // Phase 3: Detailed CDF at N=500
    // ────────────────────────────────────────────────────────
    println!("\n[3/5] Partial sum CDF at N=500...\n");

    let n = 500;
    let d = n - 1;
    let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
    let (_, v) = smallest_eigenvector(&sub, 500);
    let g: Vec<f64> = (0..d).map(|k| gram[n-1][k]).collect();

    println!("  {:>5} {:>5} {:>10} {:>10} {:>10} {:>10}",
        "k", "d(k)", "v[k]", "S(k)", "g·v_part", "sign_run");

    let mut partial = 0.0f64;
    let mut gv_partial = 0.0f64;
    let mut run_sign = v[0].signum() as i32;
    let mut run_len = 1;

    for i in 0..d.min(200) {
        let k = i + 2;
        partial += v[i];
        gv_partial += g[i] * v[i];

        let sign = if v[i] >= 0.0 { 1 } else { -1 };
        if sign == run_sign {
            run_len += 1;
        } else {
            run_sign = sign;
            run_len = 1;
        }

        // Print at key values
        if k <= 30 || k % 30 == 0 || k == 60 || k == 120 || k == 180 {
            println!("  {:5} {:5} {:10.6} {:10.6} {:10.6} {:>10}",
                k, num_divisors(k), v[i], partial, gv_partial,
                format!("{}×{}", if run_sign > 0 { "+" } else { "-" }, run_len));
        }
    }

    // ────────────────────────────────────────────────────────
    // Phase 4: v_min correlation with arithmetic functions
    // ────────────────────────────────────────────────────────
    println!("\n[4/5] What arithmetic function does v_min look like?\n");

    for &n in &[200, 500, 999] {
        let d = n - 1;
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let (_, v) = smallest_eigenvector(&sub, 500);

        // Test various arithmetic functions
        let test_fns: Vec<(&str, Vec<f64>)> = vec![
            ("d(k)", (0..d).map(|i| num_divisors(i+2) as f64).collect()),
            ("(-1)^Ω", (0..d).map(|i| {
                let k = i + 2;
                let mut omega = 0; let mut m = k; let mut p = 2;
                while p * p <= m { while m % p == 0 { omega += 1; m /= p; } p += 1; }
                if m > 1 { omega += 1; }
                if omega % 2 == 0 { 1.0 } else { -1.0 }
            }).collect()),
            ("d(k)·(-1)^Ω", (0..d).map(|i| {
                let k = i + 2;
                let dk = num_divisors(k) as f64;
                let mut omega = 0; let mut m = k; let mut p = 2;
                while p * p <= m { while m % p == 0 { omega += 1; m /= p; } p += 1; }
                if m > 1 { omega += 1; }
                dk * if omega % 2 == 0 { 1.0 } else { -1.0 }
            }).collect()),
            ("μ(k)·d(k)/k", (0..d).map(|i| {
                let k = i + 2;
                let dk = num_divisors(k) as f64;
                // Simple Möbius
                let mut m = k; let mut nf = 0; let mut sq = false;
                let mut p = 2;
                while p * p <= m {
                    if m % p == 0 { nf += 1; m /= p;
                        if m % p == 0 { sq = true; break; } }
                    p += 1;
                }
                if m > 1 { nf += 1; }
                let mu = if sq { 0.0 } else if nf % 2 == 0 { 1.0 } else { -1.0 };
                mu * dk / k as f64
            }).collect()),
            ("log(k)·(-1)^Ω/k", (0..d).map(|i| {
                let k = i + 2;
                let mut omega = 0; let mut m = k; let mut p = 2;
                while p * p <= m { while m % p == 0 { omega += 1; m /= p; } p += 1; }
                if m > 1 { omega += 1; }
                let sign = if omega % 2 == 0 { 1.0 } else { -1.0 };
                (k as f64).ln() * sign / k as f64
            }).collect()),
        ];

        println!("  N = {}:", n);
        for (name, f) in &test_fns {
            let f_mean: f64 = f.iter().sum::<f64>() / d as f64;
            let v_mean: f64 = v.iter().sum::<f64>() / d as f64;
            let cov: f64 = v.iter().zip(f.iter())
                .map(|(vi, fi)| (vi - v_mean) * (fi - f_mean)).sum::<f64>();
            let std_v: f64 = v.iter().map(|x| (x - v_mean).powi(2)).sum::<f64>().sqrt();
            let std_f: f64 = f.iter().map(|x| (x - f_mean).powi(2)).sum::<f64>().sqrt();
            let corr = cov / (std_v * std_f);
            println!("    corr(v, {:<20}) = {:8.6}", name, corr);
        }
        println!();
    }

    // ────────────────────────────────────────────────────────
    // Phase 5: Cancellation ratio growth
    // ────────────────────────────────────────────────────────
    println!("[5/5] Cancellation ratio growth...\n");

    println!("  {:>5} {:>12} {:>12} {:>12} {:>12}",
        "N", "|gᵀv|", "max|gv_part|", "cancel_ratio", "cancel/√N");

    let n_fine: Vec<usize> = (2..20).chain((20..=100).step_by(5))
        .chain((100..=max_n).step_by(50)).collect();

    let mut cancel_data: Vec<(f64, f64)> = Vec::new();

    for &n in &n_fine {
        if n < 4 || n > max_n { continue; }
        let d = n - 1;
        if d < 2 { continue; }
        let sub: Vec<Vec<f64>> = gram[..d].iter().map(|r| r[..d].to_vec()).collect();
        let (_, v) = smallest_eigenvector(&sub, 500);
        let g: Vec<f64> = (0..d).map(|k| gram[n-1][k]).collect();
        let gv: f64 = g.iter().zip(v.iter()).map(|(a,b)| a*b).sum();

        let mut gv_partials = vec![0.0f64; v.len()];
        gv_partials[0] = g[0] * v[0];
        for i in 1..v.len() { gv_partials[i] = gv_partials[i-1] + g[i] * v[i]; }
        let max_gv = gv_partials.iter().map(|x| x.abs()).fold(0.0f64, f64::max);

        let cancel = if gv.abs() > 1e-15 { max_gv / gv.abs() } else { 0.0 };

        if n <= 20 || n % 100 == 0 || n == 50 || n == max_n {
            println!("  {:5} {:12.2e} {:12.6} {:12.0} {:12.4}",
                n, gv.abs(), max_gv, cancel, cancel / (n as f64).sqrt());
        }

        if cancel > 0.0 && n >= 20 {
            cancel_data.push((n as f64, cancel));
        }
    }

    // Fit cancellation ratio vs N
    if cancel_data.len() >= 5 {
        let nf = cancel_data.len() as f64;
        let slnx: f64 = cancel_data.iter().map(|(n, _)| n.ln()).sum();
        let slny: f64 = cancel_data.iter().map(|(_, c)| c.ln()).sum();
        let slnx2: f64 = cancel_data.iter().map(|(n, _)| n.ln().powi(2)).sum();
        let slnxy: f64 = cancel_data.iter().map(|(n, c)| n.ln() * c.ln()).sum();
        let slope = (nf * slnxy - slnx * slny) / (nf * slnx2 - slnx * slnx);
        let intercept = (slny - slope * slnx) / nf;
        println!("\n  Fit: cancellation_ratio ∝ N^({:.4})", slope);
        println!("  (If ratio ∝ √N, this confirms the 1/√N random cancellation)");
    }

    println!("\n  Total time: {:.1}s", start.elapsed().as_secs_f64());
    println!("═══════════════════════════════════════════════════════════════");
}
