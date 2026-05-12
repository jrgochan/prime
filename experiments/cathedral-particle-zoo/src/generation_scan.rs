//! ω-Class Generation Scan — Energy decomposition by prime omega class
//!
//! Maps Hardy-Ramanujan's theorem to SM generations:
//!   ω=1 (primes)       → 1st Generation {u, d, e, νₑ}
//!   ω=2 (semiprimes)   → 2nd Generation {c, s, μ, νμ}
//!   ω=3 (3-almost-primes) → 3rd Generation {t, b, τ, ντ}

use cathedral_utils::arith;

/// Per-generation energy decomposition result.
#[derive(Debug, Clone)]
pub struct GenerationResult {
    pub omega: u32,
    pub energy: f64,
    pub abs_energy: f64,
    pub count: usize,
    pub partial_sum: f64,
    pub hr_predicted: f64,    // Hardy-Ramanujan predicted |E_ω|
    pub mass_ratio: f64,      // |E_ω| / |E_1|
}

/// Full generation scan across ω-classes.
#[derive(Debug)]
pub struct GenerationScan {
    pub generations: Vec<GenerationResult>,
    pub total_energy: f64,
    pub hr_amplitude: f64,    // Fitted A in |E_ω| = A·λ^(ω-1)/(ω-1)!
    pub hr_r_squared: f64,
    pub lambda: f64,          // ln(ln(N))
}

impl GenerationScan {
    /// Run the generation scan on a set of coefficients.
    pub fn analyze(coeffs: &[(usize, f64)], b_vec: &[f64], n_max: usize) -> Self {
        let omega_table = arith::small_omega_table(n_max);
        let lambda = (n_max as f64).ln().ln();

        let max_omega = coeffs.iter()
            .map(|(n, _)| omega_table[*n] as usize)
            .max()
            .unwrap_or(0);

        let mut e_omega = vec![0.0f64; max_omega + 1];
        let mut count_omega = vec![0usize; max_omega + 1];

        for (i, &(n, a_n)) in coeffs.iter().enumerate() {
            let b_n = if i < b_vec.len() { b_vec[i] } else { 0.0 };
            let contrib = a_n * b_n;
            let w = omega_table[n] as usize;
            e_omega[w] += contrib;
            count_omega[w] += 1;
        }

        let total_energy: f64 = e_omega.iter().sum();

        // Collect generations with partial sums
        let mut generations = Vec::new();
        let mut partial = 0.0;
        let e1_abs = e_omega.get(1).map(|e| e.abs()).unwrap_or(1.0);

        for w in 1..=max_omega {
            if count_omega[w] == 0 { continue; }
            partial += e_omega[w];
            let abs_e = e_omega[w].abs();
            let hr = lambda.powi((w as i32) - 1) / factorial(w - 1) as f64;
            let mass_ratio = if e1_abs > 1e-30 { abs_e / e1_abs } else { 0.0 };

            generations.push(GenerationResult {
                omega: w as u32,
                energy: e_omega[w],
                abs_energy: abs_e,
                count: count_omega[w],
                partial_sum: partial,
                hr_predicted: hr,
                mass_ratio,
            });
        }

        // Fit Hardy-Ramanujan amplitude A
        let (a_fit, r2) = fit_hr_amplitude(&generations, lambda);

        GenerationScan {
            generations,
            total_energy,
            hr_amplitude: a_fit,
            hr_r_squared: r2,
            lambda,
        }
    }

    /// Display the generation table.
    pub fn display(&self) {
        println!("  ┌───┬──────────────┬────────────┬────────┬──────────────┬──────────┐");
        println!("  │ ω │     E_ω      │    |E_ω|   │  count │  mass ratio  │  SM gen  │");
        println!("  ├───┼──────────────┼────────────┼────────┼──────────────┼──────────┤");

        for g in &self.generations {
            let gen_name = match g.omega {
                1 => "1st (u,d,e,ν)",
                2 => "2nd (c,s,μ,ν)",
                3 => "3rd (t,b,τ,ν)",
                _ => "beyond SM",
            };
            let sign = if g.energy > 0.0 { "+" } else { "-" };
            println!(
                "  │ {} │ {}{:11.6} │ {:10.6} │ {:6} │ {:12.6} │ {:>8} │",
                g.omega, sign, g.energy.abs(), g.abs_energy, g.count,
                g.mass_ratio, gen_name
            );
        }
        println!("  └───┴──────────────┴────────────┴────────┴──────────────┴──────────┘");
        println!();
        println!("  Hardy-Ramanujan fit: A = {:.4}, R² = {:.6}, λ = ln(ln N) = {:.4}",
                 self.hr_amplitude, self.hr_r_squared, self.lambda);
        println!("  Total energy E = bᵀa* = {:.10}", self.total_energy);
    }
}

fn fit_hr_amplitude(gens: &[GenerationResult], lambda: f64) -> (f64, f64) {
    if gens.is_empty() { return (0.0, 0.0); }

    let mut num = 0.0;
    let mut den = 0.0;
    let magnitudes: Vec<f64> = gens.iter().map(|g| g.abs_energy).collect();

    for (i, g) in gens.iter().enumerate() {
        let w = g.omega as i32;
        let hr = lambda.powi(w - 1) / factorial((w - 1) as usize) as f64;
        num += magnitudes[i] * hr;
        den += hr * hr;
    }

    let a = if den > 1e-30 { num / den } else { 0.0 };

    // R²
    let mean = magnitudes.iter().sum::<f64>() / magnitudes.len() as f64;
    let ss_tot: f64 = magnitudes.iter().map(|m| (m - mean).powi(2)).sum();
    let ss_res: f64 = gens.iter().enumerate().map(|(i, g)| {
        let w = g.omega as i32;
        let hr = a * lambda.powi(w - 1) / factorial((w - 1) as usize) as f64;
        (magnitudes[i] - hr).powi(2)
    }).sum();
    let r2 = if ss_tot > 1e-30 { 1.0 - ss_res / ss_tot } else { 0.0 };

    (a, r2)
}

fn factorial(n: usize) -> u64 {
    (1..=n as u64).product::<u64>().max(1)
}
