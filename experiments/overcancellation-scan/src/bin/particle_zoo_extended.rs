#![allow(dead_code, unused_variables, unused_imports, unused_assignments, clippy::needless_range_loop, clippy::doc_lazy_continuation, non_snake_case, clippy::empty_line_after_doc_comments)]
// overcancellation-scan/src/bin/particle_zoo_extended.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  EXTENDED PARTICLE ZOO — Every Integer Has a Soul               ║
// ║                                                                   ║
// ║  Classifies integers 1..N by:                                     ║
// ║    • Number-theoretic quantum numbers (μ, λ, Ω, ω, squarefree)  ║
// ║    • Particle type (vacuum, Higgs, quark, meson, baryon, ...)    ║
// ║    • Gram form contribution (diagonal + row off-diagonal)        ║
// ║    • SUSY sector (bosonic/fermionic row contribution)            ║
// ║                                                                   ║
// ║  Outputs: TSV for analysis + summary statistics                   ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::{gcd, mobius_table};
use rayon::prelude::*;
use std::f64::consts::PI;

const EULER_GAMMA: f64 = 0.5772156649015329;

fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

// ═══════════════════════════════════════════════════════
// §1. NUMBER-THEORETIC QUANTUM NUMBERS
// ═══════════════════════════════════════════════════════

/// Compute smallest prime factor sieve + full factorization data.
/// Returns (mu, lambda, big_omega, little_omega, is_squarefree, factorization)
struct ArithData {
    mu: Vec<i8>,           // Möbius function
    lambda: Vec<i8>,       // Liouville function (-1)^Ω(n)
    big_omega: Vec<u32>,   // Ω(n) = total prime factors with multiplicity
    little_omega: Vec<u32>, // ω(n) = distinct prime factors
    is_squarefree: Vec<bool>,
    smallest_pf: Vec<usize>, // smallest prime factor
}

fn compute_arith_data(max_n: usize) -> ArithData {
    let mut mu = vec![0i8; max_n + 1];
    let mut lambda = vec![1i8; max_n + 1];
    let mut big_omega = vec![0u32; max_n + 1];
    let mut little_omega = vec![0u32; max_n + 1];
    let mut is_squarefree = vec![true; max_n + 1];
    let mut smallest_pf = vec![0usize; max_n + 1];

    // Use cathedral_utils mobius table for correctness
    let mu_table = mobius_table(max_n + 1);

    // Sieve for factorization data
    let mut remaining = vec![0usize; max_n + 1];
    for i in 0..=max_n { remaining[i] = i; }

    for p in 2..=max_n {
        if smallest_pf[p] != 0 { continue; } // not prime
        // p is prime
        for m in (p..=max_n).step_by(p) {
            if smallest_pf[m] == 0 { smallest_pf[m] = p; }
            little_omega[m] += 1;

            let mut count = 0u32;
            let mut val = m;
            while val % p == 0 {
                val /= p;
                count += 1;
            }
            big_omega[m] += count;
            if count >= 2 {
                is_squarefree[m] = false;
            }
        }
    }

    // Set μ and λ
    mu[1] = 1;
    for n in 1..=max_n {
        mu[n] = mu_table[n];
        lambda[n] = if big_omega[n].is_multiple_of(2) { 1 } else { -1 };
    }

    is_squarefree[0] = false;
    is_squarefree[1] = true;

    ArithData { mu, lambda, big_omega, little_omega, is_squarefree, smallest_pf }
}

// ═══════════════════════════════════════════════════════
// §2. PARTICLE CLASSIFICATION
// ═══════════════════════════════════════════════════════

#[derive(Debug, Clone, Copy, PartialEq)]
enum ParticleType {
    Vacuum,       // n=1: μ=+1, no prime factors
    Higgs,        // n=2: the parity flipper
    PrimeQuark,   // p prime, p≥3: "confined" — μ=-1, ω=1
    Meson,        // pq, two distinct primes: μ=+1, ω=2
    Baryon,       // pqr, three distinct primes: μ=-1, ω=3
    Tetraquark,   // pqrs, four distinct primes: μ=+1, ω=4
    Pentaquark,   // five distinct primes: μ=-1, ω=5
    HigherHadron, // ω≥6 squarefree: exotic bound state
    Excluded,     // non-squarefree: μ=0, Pauli excluded
}

impl ParticleType {
    fn label(&self) -> &'static str {
        match self {
            ParticleType::Vacuum => "Vacuum",
            ParticleType::Higgs => "Higgs",
            ParticleType::PrimeQuark => "Quark",
            ParticleType::Meson => "Meson",
            ParticleType::Baryon => "Baryon",
            ParticleType::Tetraquark => "Tetraquark",
            ParticleType::Pentaquark => "Pentaquark",
            ParticleType::HigherHadron => "Exotic",
            ParticleType::Excluded => "Excluded",
        }
    }

    fn emoji(&self) -> &'static str {
        match self {
            ParticleType::Vacuum => "⊙",
            ParticleType::Higgs => "H",
            ParticleType::PrimeQuark => "q",
            ParticleType::Meson => "π",
            ParticleType::Baryon => "p",
            ParticleType::Tetraquark => "T",
            ParticleType::Pentaquark => "P",
            ParticleType::HigherHadron => "X",
            ParticleType::Excluded => "∅",
        }
    }
}

fn classify(n: usize, data: &ArithData) -> ParticleType {
    if n == 1 { return ParticleType::Vacuum; }
    if !data.is_squarefree[n] { return ParticleType::Excluded; }
    if n == 2 { return ParticleType::Higgs; }

    match data.little_omega[n] {
        1 => ParticleType::PrimeQuark,
        2 => ParticleType::Meson,
        3 => ParticleType::Baryon,
        4 => ParticleType::Tetraquark,
        5 => ParticleType::Pentaquark,
        _ => ParticleType::HigherHadron,
    }
}

// ═══════════════════════════════════════════════════════
// §3. GRAM FORM CONTRIBUTION PER INTEGER
// ═══════════════════════════════════════════════════════

/// Vasyunin sum V(a,b)
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

/// Full Vasyunin Gram entry
fn gram_entry_full(j: usize, k: usize) -> f64 {
    let c = vasyunin_const();
    let jf = j as f64;
    let kf = k as f64;

    if j == k {
        return c / jf - 1.0 / (jf * jf);
    }

    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let df = d as f64;

    let t1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
    let t2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let t3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
    let t4 = 1.0 / (jf * kf);

    t1 + t2 - t3 - t4
}

/// Compute row j's contribution to vᵀGv, split by SUSY sector
struct RowContrib {
    j: usize,
    diag: f64,
    bosonic_off: f64,
    fermionic_off: f64,
    total: f64,
}

fn compute_row_contrib(j: usize, v: &[f64], n: usize, data: &ArithData) -> RowContrib {
    let vj = v[j - 1];
    let mut diag = 0.0;
    let mut bosonic_off = 0.0;
    let mut fermionic_off = 0.0;

    for k in 1..n {
        let vk = v[k - 1];
        let g = gram_entry_full(j, k);
        let term = vj * vk * g;

        if j == k {
            diag = term;
        } else {
            let omega_sum = data.big_omega[j] + data.big_omega[k];
            if omega_sum.is_multiple_of(2) {
                bosonic_off += term;
            } else {
                fermionic_off += term;
            }
        }
    }

    RowContrib {
        j,
        diag,
        bosonic_off,
        fermionic_off,
        total: diag + bosonic_off + fermionic_off,
    }
}

// ═══════════════════════════════════════════════════════
// §4. MAIN — BUILD THE EXTENDED ZOO
// ═══════════════════════════════════════════════════════

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════════╗");
    println!("║  EXTENDED PARTICLE ZOO — Every Integer Has a Soul               ║");
    println!("╚═══════════════════════════════════════════════════════════════════╝");
    println!();

    let n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(120);

    println!("N = {}  (dim = {})", n, n - 1);
    println!();

    // Compute all arithmetic data
    let data = compute_arith_data(n);

    // Build witness vector
    let v: Vec<f64> = (1..n).map(|k| {
        -(data.mu[k] as f64) * (1.0 - (k as f64).ln() / (n as f64).ln())
    }).collect();

    // Compute per-row Gram contributions (parallel)
    eprint!("Computing Gram row contributions...");
    let rows: Vec<RowContrib> = (1..n).into_par_iter()
        .map(|j| compute_row_contrib(j, &v, n, &data))
        .collect();
    eprintln!(" done.");

    // ═══════ Summary statistics by particle type ═══════
    let mut type_counts: std::collections::HashMap<&str, (usize, f64, f64, f64)> =
        std::collections::HashMap::new();

    for j in 1..n {
        let ptype = classify(j, &data);
        let row = &rows[j - 1];
        let entry = type_counts.entry(ptype.label()).or_insert((0, 0.0, 0.0, 0.0));
        entry.0 += 1;
        entry.1 += row.diag;
        entry.2 += row.bosonic_off;
        entry.3 += row.fermionic_off;
    }

    let vtgv: f64 = rows.iter().map(|r| r.total).sum();
    let total_diag: f64 = rows.iter().map(|r| r.diag).sum();
    let total_bos: f64 = rows.iter().map(|r| r.bosonic_off).sum();
    let total_fer: f64 = rows.iter().map(|r| r.fermionic_off).sum();

    // ═══════ Print summary ═══════
    println!("╔══════════════════════════════════════════════════════════════════════════════╗");
    println!("║  PARTICLE TYPE CENSUS                                                      ║");
    println!("╠══════════════════════════════════════════════════════════════════════════════╣");
    println!("║ {:<12} {:>6} {:>12} {:>12} {:>12} {:>12} ║",
        "Type", "Count", "Diagonal", "Bosonic", "Fermionic", "Total");
    println!("╠══════════════════════════════════════════════════════════════════════════════╣");

    let order = ["Vacuum", "Higgs", "Quark", "Meson", "Baryon",
                 "Tetraquark", "Pentaquark", "Exotic", "Excluded"];
    for label in &order {
        if let Some(&(count, d, b, f)) = type_counts.get(label) {
            println!("║ {:<12} {:>6} {:>+12.4} {:>+12.4} {:>+12.4} {:>+12.4} ║",
                label, count, d, b, f, d + b + f);
        }
    }

    println!("╠══════════════════════════════════════════════════════════════════════════════╣");
    println!("║ {:<12} {:>6} {:>+12.4} {:>+12.4} {:>+12.4} {:>+12.4} ║",
        "TOTAL", n - 1, total_diag, total_bos, total_fer, vtgv);
    println!("║                                                                            ║");
    println!("║  vᵀGv = {:.10}   1 - vᵀGv = {:.10}                      ║", vtgv, 1.0 - vtgv);

    if vtgv < 1.0 {
        println!("║  STATUS: ✅ vᵀGv < 1  (Nyman-Beurling margin = {:.6})                   ║", 1.0 - vtgv);
    }
    println!("╚══════════════════════════════════════════════════════════════════════════════╝");

    // ═══════ TSV output ═══════
    println!();
    println!("# TSV: n, mu, lambda, Omega, omega, sqfree, type, v_n, diag, bos_off, fer_off, total");
    println!("n\tmu\tlambda\tOmega\tomega\tsqfree\ttype\tv_n\tdiag\tbos_off\tfer_off\ttotal");
    for j in 1..n {
        let ptype = classify(j, &data);
        let row = &rows[j - 1];
        println!("{}\t{}\t{}\t{}\t{}\t{}\t{}\t{:.8}\t{:.8}\t{:.8}\t{:.8}\t{:.8}",
            j,
            data.mu[j],
            data.lambda[j],
            data.big_omega[j],
            data.little_omega[j],
            if data.is_squarefree[j] { 1 } else { 0 },
            ptype.label(),
            v[j - 1],
            row.diag,
            row.bosonic_off,
            row.fermionic_off,
            row.total,
        );
    }
}
