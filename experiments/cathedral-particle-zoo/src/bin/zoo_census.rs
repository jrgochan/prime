// cathedral-particle-zoo/src/bin/zoo_census.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  PARTICLE ZOO CENSUS — Classification at Scale                  ║
// ║                                                                   ║
// ║  Every integer n ≤ N gets classified by:                          ║
// ║    • Quantum numbers: μ(n), λ(n), Ω(n), ω(n)                   ║
// ║    • Particle type: Vacuum/Higgs/Quark/Meson/Baryon/...          ║
// ║    • Gram form contribution: diagonal + bosonic + fermionic       ║
// ║                                                                   ║
// ║  Uses the full Vasyunin cotangent formula with rayon parallelism  ║
// ║  Outputs TSV to results/ for downstream analysis                  ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith;
use rayon::prelude::*;
use std::f64::consts::PI;
use std::io::Write;
use clap::Parser;

const EULER_GAMMA: f64 = 0.5772156649015329;

#[derive(Parser, Debug)]
#[command(name = "zoo-census", about = "Extended Particle Zoo Census")]
struct Args {
    /// Maximum N for the census (uses HC subsequence if --hc)
    #[arg(short, long, default_value_t = 120)]
    n: usize,

    /// Run HC (highly composite) subsequence up to N
    #[arg(long)]
    hc: bool,

    /// Output detailed per-integer TSV
    #[arg(long)]
    tsv: bool,

    /// Output directory for results
    #[arg(short, long, default_value = "results")]
    output: String,
}

// ═══════════════════════════════════════════════════════
// §1. PARTICLE TYPES
// ═══════════════════════════════════════════════════════

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ParticleType {
    Vacuum,       // n=1: μ=+1, ω=0
    Higgs,        // n=2: the Z₂ parity flipper
    PrimeQuark,   // p prime, p≥3: confined, μ=-1, ω=1
    Meson,        // pq (2 distinct primes): μ=+1, ω=2
    Baryon,       // pqr (3 distinct primes): μ=-1, ω=3
    Tetraquark,   // pqrs: μ=+1, ω=4
    Pentaquark,   // 5 distinct primes: μ=-1, ω=5
    Hexaquark,    // 6 distinct primes: μ=+1, ω=6
    Exotic(u32),  // ω≥7 squarefree
    Excluded,     // non-squarefree: μ=0, Pauli exclusion
}

impl ParticleType {
    pub fn label(&self) -> String {
        match self {
            ParticleType::Vacuum => "Vacuum".into(),
            ParticleType::Higgs => "Higgs".into(),
            ParticleType::PrimeQuark => "Quark".into(),
            ParticleType::Meson => "Meson".into(),
            ParticleType::Baryon => "Baryon".into(),
            ParticleType::Tetraquark => "Tetraquark".into(),
            ParticleType::Pentaquark => "Pentaquark".into(),
            ParticleType::Hexaquark => "Hexaquark".into(),
            ParticleType::Exotic(w) => format!("Exotic-{}", w),
            ParticleType::Excluded => "Excluded".into(),
        }
    }

    pub fn short(&self) -> &'static str {
        match self {
            ParticleType::Vacuum => "⊙",
            ParticleType::Higgs => "H",
            ParticleType::PrimeQuark => "q",
            ParticleType::Meson => "π",
            ParticleType::Baryon => "p",
            ParticleType::Tetraquark => "T₄",
            ParticleType::Pentaquark => "P₅",
            ParticleType::Hexaquark => "H₆",
            ParticleType::Exotic(_) => "X",
            ParticleType::Excluded => "∅",
        }
    }

    /// Ordering for display
    pub fn order(&self) -> u32 {
        match self {
            ParticleType::Vacuum => 0,
            ParticleType::Higgs => 1,
            ParticleType::PrimeQuark => 2,
            ParticleType::Meson => 3,
            ParticleType::Baryon => 4,
            ParticleType::Tetraquark => 5,
            ParticleType::Pentaquark => 6,
            ParticleType::Hexaquark => 7,
            ParticleType::Exotic(w) => 7 + *w,
            ParticleType::Excluded => 99,
        }
    }
}

fn classify(n: usize, mu: i8, omega: u32) -> ParticleType {
    if n == 1 { return ParticleType::Vacuum; }
    if mu == 0 { return ParticleType::Excluded; }
    if n == 2 { return ParticleType::Higgs; }
    match omega {
        1 => ParticleType::PrimeQuark,
        2 => ParticleType::Meson,
        3 => ParticleType::Baryon,
        4 => ParticleType::Tetraquark,
        5 => ParticleType::Pentaquark,
        6 => ParticleType::Hexaquark,
        w => ParticleType::Exotic(w),
    }
}

// ═══════════════════════════════════════════════════════
// §2. GRAM COMPUTATION (Vasyunin formula)
// ═══════════════════════════════════════════════════════

fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

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

fn gram_entry(j: usize, k: usize) -> f64 {
    let c = vasyunin_const();
    let jf = j as f64;
    let kf = k as f64;
    if j == k {
        return c / jf - 1.0 / (jf * jf);
    }
    let d = arith::gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let df = d as f64;
    let t1 = c / 2.0 * (1.0 / jf + 1.0 / kf);
    let t2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let t3 = PI * df / (2.0 * jf * kf) * (vasyunin_sum(jp, kp) + vasyunin_sum(kp, jp));
    let t4 = 1.0 / (jf * kf);
    t1 + t2 - t3 - t4
}

// ═══════════════════════════════════════════════════════
// §3. PER-ROW CONTRIBUTION
// ═══════════════════════════════════════════════════════

#[derive(Debug, Clone)]
struct RowResult {
    n: usize,          // integer index (1-based)
    ptype: ParticleType,
    mu: i8,
    lambda: i8,
    big_omega: u32,
    small_omega: u32,
    witness_val: f64,
    diag: f64,
    bosonic_off: f64,
    fermionic_off: f64,
}

impl RowResult {
    fn total(&self) -> f64 { self.diag + self.bosonic_off + self.fermionic_off }
}

fn compute_row(j: usize, v: &[f64], dim: usize,
               big_omega: &[u32], mu: &[i8], lambda: &[i8],
               small_omega: &[u32], _n_total: usize) -> RowResult {
    let vj = v[j - 1];
    let mut diag = 0.0f64;
    let mut bosonic_off = 0.0f64;
    let mut fermionic_off = 0.0f64;

    for k in 1..=dim {
        let vk = v[k - 1];
        let g = gram_entry(j, k);
        let term = vj * vk * g;

        if j == k {
            diag = term;
        } else {
            let omega_sum = big_omega[j] + big_omega[k];
            if omega_sum.is_multiple_of(2) {
                bosonic_off += term;
            } else {
                fermionic_off += term;
            }
        }
    }

    RowResult {
        n: j,
        ptype: classify(j, mu[j], small_omega[j]),
        mu: mu[j],
        lambda: lambda[j],
        big_omega: big_omega[j],
        small_omega: small_omega[j],
        witness_val: v[j - 1],
        diag,
        bosonic_off,
        fermionic_off,
    }
}

// ═══════════════════════════════════════════════════════
// §4. CENSUS AGGREGATION
// ═══════════════════════════════════════════════════════

#[derive(Debug, Clone)]
struct TypeStats {
    label: String,
    order: u32,
    count: usize,
    diag: f64,
    bosonic: f64,
    fermionic: f64,
}

impl TypeStats {
    fn total(&self) -> f64 { self.diag + self.bosonic + self.fermionic }
}

fn aggregate(rows: &[RowResult]) -> Vec<TypeStats> {
    let mut map: std::collections::HashMap<String, TypeStats> = std::collections::HashMap::new();
    for r in rows {
        let label = r.ptype.label();
        let entry = map.entry(label.clone()).or_insert(TypeStats {
            label, order: r.ptype.order(), count: 0,
            diag: 0.0, bosonic: 0.0, fermionic: 0.0,
        });
        entry.count += 1;
        entry.diag += r.diag;
        entry.bosonic += r.bosonic_off;
        entry.fermionic += r.fermionic_off;
    }
    let mut v: Vec<TypeStats> = map.into_values().collect();
    v.sort_by_key(|s| s.order);
    v
}

// ═══════════════════════════════════════════════════════
// §5. OUTPUT
// ═══════════════════════════════════════════════════════

fn print_census(n: usize, stats: &[TypeStats], vtgv: f64) {
    let ln_n = (n as f64).ln();
    println!();
    println!("╔══════════════════════════════════════════════════════════════════════════════════╗");
    println!("║  PARTICLE ZOO CENSUS   N = {:>6}   dim = {:>6}                                ║", n, n - 1);
    println!("╠══════════════════════════════════════════════════════════════════════════════════╣");
    println!("║ {:<14} {:>6} {:>12} {:>12} {:>12} {:>12} {:>8} ║",
        "Type", "Count", "Diagonal", "Bosonic", "Fermionic", "Total", "Frac%");
    println!("╠══════════════════════════════════════════════════════════════════════════════════╣");

    let mut sum_count = 0usize;
    let mut sum_d = 0.0f64;
    let mut sum_b = 0.0f64;
    let mut sum_f = 0.0f64;

    for s in stats {
        let frac = if vtgv.abs() > 1e-15 { s.total() / vtgv * 100.0 } else { 0.0 };
        println!("║ {:<14} {:>6} {:>+12.4} {:>+12.4} {:>+12.4} {:>+12.4} {:>+7.1}% ║",
            s.label, s.count, s.diag, s.bosonic, s.fermionic, s.total(), frac);
        sum_count += s.count;
        sum_d += s.diag;
        sum_b += s.bosonic;
        sum_f += s.fermionic;
    }

    println!("╠══════════════════════════════════════════════════════════════════════════════════╣");
    println!("║ {:<14} {:>6} {:>+12.4} {:>+12.4} {:>+12.4} {:>+12.4} {:>7}  ║",
        "TOTAL", sum_count, sum_d, sum_b, sum_f, vtgv, "100.0%");
    println!("╠══════════════════════════════════════════════════════════════════════════════════╣");
    println!("║  vᵀGv      = {:>+16.10}                                               ║", vtgv);
    println!("║  1 - vᵀGv  = {:>+16.10}                                               ║", 1.0 - vtgv);
    println!("║  gap·ln(N) = {:>16.10}   (stable if K/lnN form)                  ║", (1.0 - vtgv) * ln_n);

    // SUSY cancellation
    let cancel = if sum_b.abs() > 1e-15 {
        (1.0 - (sum_b + sum_f).abs() / sum_b.abs().max(sum_f.abs())) * 100.0
    } else { 0.0 };
    println!("║  B_off     = {:>+16.10}                                               ║", sum_b);
    println!("║  F_off     = {:>+16.10}                                               ║", sum_f);
    println!("║  |B+F|/max = {:>16.10}   ({:.2}% SUSY cancellation)            ║",
        (sum_b + sum_f).abs() / sum_b.abs().max(sum_f.abs()), cancel);

    if vtgv < 1.0 {
        println!("║  STATUS: ✅ vᵀGv < 1  (Nyman-Beurling margin = {:.6})                      ║", 1.0 - vtgv);
    } else {
        println!("║  STATUS: ⚠️  vᵀGv ≥ 1  (margin = {:.6})                                    ║", 1.0 - vtgv);
    }
    println!("╚══════════════════════════════════════════════════════════════════════════════════╝");
}

fn write_tsv(rows: &[RowResult], n: usize, path: &str) -> std::io::Result<()> {
    let mut f = std::fs::File::create(path)?;
    writeln!(f, "# Particle Zoo Census N={}", n)?;
    writeln!(f, "n\tmu\tlambda\tOmega\tomega\ttype\tv_n\tdiag\tbos_off\tfer_off\ttotal")?;
    for r in rows {
        writeln!(f, "{}\t{}\t{}\t{}\t{}\t{}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}",
            r.n, r.mu, r.lambda, r.big_omega, r.small_omega,
            r.ptype.label(), r.witness_val,
            r.diag, r.bosonic_off, r.fermionic_off, r.total())?;
    }
    Ok(())
}

fn write_summary_tsv(stats: &[TypeStats], n: usize, vtgv: f64, path: &str) -> std::io::Result<()> {
    let mut f = std::fs::OpenOptions::new().create(true).append(true).open(path)?;
    // Write header if file is new/empty
    let metadata = std::fs::metadata(path)?;
    if metadata.len() < 10 {
        writeln!(f, "N\tvtgv\tgap\tgap_ln\tdiag\tbos\tfer\tvacuum\thiggs\tquark\tmeson\tbaryon\ttetra\tpenta\texcluded")?;
    }

    let get = |label: &str| -> f64 {
        stats.iter().find(|s| s.label == label).map(|s| s.total()).unwrap_or(0.0)
    };

    let ln_n = (n as f64).ln();
    let d: f64 = stats.iter().map(|s| s.diag).sum();
    let b: f64 = stats.iter().map(|s| s.bosonic).sum();
    let ff: f64 = stats.iter().map(|s| s.fermionic).sum();

    writeln!(f, "{}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}",
        n, vtgv, 1.0 - vtgv, (1.0 - vtgv) * ln_n,
        d, b, ff,
        get("Vacuum"), get("Higgs"), get("Quark"), get("Meson"),
        get("Baryon"), get("Tetraquark"), get("Pentaquark"), get("Excluded"))?;
    Ok(())
}

// ═══════════════════════════════════════════════════════
// §6. MAIN
// ═══════════════════════════════════════════════════════

fn main() {
    let args = Args::parse();

    println!("╔═══════════════════════════════════════════════════════════════════╗");
    println!("║  PARTICLE ZOO CENSUS — Every Integer Has a Soul                 ║");
    println!("╚═══════════════════════════════════════════════════════════════════╝");

    // HC (highly composite) subsequence for scaling studies
    let hc_seq: Vec<usize> = vec![
        6, 12, 24, 36, 48, 60, 120, 180, 240, 360, 720, 840,
        1260, 1680, 2520, 5040, 7560, 10080, 15120, 20160, 27720,
    ];

    let ns: Vec<usize> = if args.hc {
        hc_seq.into_iter().filter(|&x| x <= args.n).collect()
    } else {
        vec![args.n]
    };

    // Create output directory
    let _ = std::fs::create_dir_all(&args.output);
    let summary_path = format!("{}/zoo_census_summary.tsv", args.output);
    // Clear summary file for fresh run
    if args.hc {
        let _ = std::fs::remove_file(&summary_path);
    }

    for &n in &ns {
        let dim = n - 1;
        eprint!("  N = {:>6} (dim = {:>5}) ... ", n, dim);

        // Compute arithmetic data
        let mu = arith::mobius_table(n + 1);
        let lambda = arith::liouville_table(n + 1);
        let omega_small = arith::small_omega_table(n + 1);

        // Compute big_omega via sieve
        let mut big_omega = vec![0u32; n + 1];
        {
            let is_prime = arith::sieve_primes(n + 1);
            for p in 2..=n {
                if !is_prime[p] { continue; }
                let mut pk = p;
                while pk <= n {
                    for m in (pk..=n).step_by(pk) {
                        big_omega[m] += 1;
                    }
                    if pk > n / p { break; }
                    pk *= p;
                }
            }
        }

        // Build witness vector: v(k) = -μ(k) · (1 - ln(k)/ln(N))
        let ln_n = (n as f64).ln();
        let v: Vec<f64> = (1..n).map(|k| {
            -(mu[k] as f64) * (1.0 - (k as f64).ln() / ln_n)
        }).collect();

        // Parallel row computation
        let rows: Vec<RowResult> = (1..n).into_par_iter()
            .map(|j| compute_row(j, &v, dim, &big_omega, &mu, &lambda, &omega_small, n))
            .collect();

        let vtgv: f64 = rows.iter().map(|r| r.total()).sum();

        eprintln!("vᵀGv = {:.6}  gap = {:.6}", vtgv, 1.0 - vtgv);

        // Aggregate by type
        let stats = aggregate(&rows);

        // Print census
        print_census(n, &stats, vtgv);

        // Write TSV outputs
        if args.tsv {
            let detail_path = format!("{}/zoo_detail_N{}.tsv", args.output, n);
            if let Err(e) = write_tsv(&rows, n, &detail_path) {
                eprintln!("Warning: couldn't write {}: {}", detail_path, e);
            } else {
                println!("  → Detail TSV: {}", detail_path);
            }
        }

        if let Err(e) = write_summary_tsv(&stats, n, vtgv, &summary_path) {
            eprintln!("Warning: couldn't write summary: {}", e);
        }
    }

    if args.hc {
        println!();
        println!("  → Summary TSV: {}", summary_path);
    }
}
