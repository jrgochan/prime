// cathedral-particle-zoo/src/bin/zoo_census_h5.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  PARTICLE ZOO CENSUS (H5-Backed) — Scale to N=55,440           ║
// ║                                                                   ║
// ║  Reads pre-computed Gram matrices from HPDF .h5 files.           ║
// ║  H5 files index k=2..N. We augment with the k=1 row/column       ║
// ║  (computed from the Vasyunin formula) to get the canonical         ║
// ║  k=1..N-1 Nyman-Beurling form.                                    ║
// ║                                                                   ║
// ║  Result: correct vᵀGv matching the from-scratch computation.      ║
// ╚═══════════════════════════════════════════════════════════════════╝

use clap::Parser;
use rayon::prelude::*;
use std::f64::consts::PI;
use std::io::Write;
use std::path::{Path, PathBuf};

use cathedral_utils::arith;
use cathedral_utils::hpdf::reader::HpdfReader;

const EULER_GAMMA: f64 = 0.5772156649015329;

#[derive(Parser, Debug)]
#[command(name = "zoo-census-h5", about = "Particle Zoo Census from HPDF files")]
struct Args {
    /// Directory containing gram_N*.h5 files
    #[arg(long, default_value = "experiments/cache/hpdf")]
    cache_dir: String,

    /// Maximum N to process
    #[arg(long, default_value = "60000")]
    max_n: usize,

    /// Output directory for results
    #[arg(short, long, default_value = "results/zoo_census")]
    output: String,

    /// Output per-integer TSV detail (large files!)
    #[arg(long)]
    detail: bool,
}

// ═══════════════════════════════════════════════════════
// §1. PARTICLE TYPES
// ═══════════════════════════════════════════════════════

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
enum ParticleType {
    Vacuum,
    Higgs,
    PrimeQuark,
    Meson,
    Baryon,
    Tetraquark,
    Pentaquark,
    Hexaquark,
    Exotic(u32),
    Excluded,
}

impl ParticleType {
    fn label(&self) -> String {
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
    fn order(&self) -> u32 {
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
    if n == 1 {
        return ParticleType::Vacuum;
    }
    if mu == 0 {
        return ParticleType::Excluded;
    }
    if n == 2 {
        return ParticleType::Higgs;
    }
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
// §2. VASYUNIN FORMULA FOR k=1 ROW
// ═══════════════════════════════════════════════════════

fn vasyunin_const() -> f64 {
    (2.0 * PI).ln() - EULER_GAMMA
}

/// Vasyunin sum V(a, b) = Σ_{m=1}^{a-1} cot(πm/a) · {mb/a}
fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
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

/// Compute G(1, k) using the Vasyunin Gram formula.
/// For j=1: gcd(1,k)=1, j'=1, k'=k
///   G(1,1) = C - 1
///   G(1,k) = C/2·(1+1/k) + (1-k)/(2k)·ln(k) - π/(2k)·V(k,1) - 1/k
fn gram_row1(k: usize) -> f64 {
    let c = vasyunin_const();
    if k == 1 {
        return c - 1.0;
    }
    let kf = k as f64;
    let t1 = c / 2.0 * (1.0 + 1.0 / kf);
    let t2 = (1.0 - kf) / (2.0 * kf) * kf.ln();
    // V(1,k) = 0 (empty sum since a=1)
    // V(k,1) = Σ_{m=1}^{k-1} cot(πm/k) · {m/k}
    let vk1 = vasyunin_sum(k, 1);
    let t3 = PI / (2.0 * kf) * vk1; // only V(k,1) since V(1,k)=0
    let t4 = 1.0 / kf;
    t1 + t2 - t3 - t4
}

/// Build the k=1 row: G(1, k) for k = 1, 2, ..., N-1.
/// This is O(N²) total work (each V(k,1) has k-1 terms).
fn build_row1(n: usize) -> Vec<f64> {
    // Parallelize over k
    (1..n).into_par_iter().map(gram_row1).collect()
}

// ═══════════════════════════════════════════════════════
// §3. MATRIX ASSEMBLY: H5 + k=1 ROW/COL
// ═══════════════════════════════════════════════════════

/// Assemble the canonical (N-1)×(N-1) Gram matrix for k=1..N-1
/// from the H5 matrix (k=2..N) plus the computed k=1 row/column.
///
/// Layout of output matrix (dim = N-1):
///   row 0, col 0     = G(1,1)        [computed]
///   row 0, col 1..   = G(1, 2..N-1)  [computed]
///   row 1.., col 0   = G(2..N-1, 1)  [computed, = G(1, 2..N-1) by symmetry]
///   row i, col j (i,j ≥ 1) = G(i+1, j+1) = H5[i-1][j-1]
///
/// H5 matrix is (N-1)×(N-1) for k=2..N. We use rows 0..N-3 and cols 0..N-3
/// (dropping k=N, the last row/col) to get k=2..N-1.
fn assemble_gram(n: usize, h5_gram: &[f64], h5_dim: usize, row1: &[f64]) -> Vec<f64> {
    let dim = n - 1; // k = 1..N-1
    let mut gram = vec![0.0f64; dim * dim];

    // Row 0 / Col 0: the k=1 entries
    for j in 0..dim {
        gram[j] = row1[j]; // row 0
        gram[j * dim] = row1[j]; // col 0 (symmetric)
    }

    // Interior: k=2..N-1 from H5 matrix (H5 rows 0..N-3, cols 0..N-3)
    let interior = dim - 1; // = N-2, indices for k=2..N-1
    for i in 0..interior {
        for j in 0..interior {
            gram[(i + 1) * dim + (j + 1)] = h5_gram[i * h5_dim + j];
        }
    }

    gram
}

// ═══════════════════════════════════════════════════════
// §4. PER-ROW CONTRIBUTION
// ═══════════════════════════════════════════════════════

#[derive(Debug, Clone)]
struct RowResult {
    ptype: ParticleType,
    diag: f64,
    bosonic_off: f64,
    fermionic_off: f64,
}

impl RowResult {
    fn total(&self) -> f64 {
        self.diag + self.bosonic_off + self.fermionic_off
    }
}

/// Compute row i's contribution. Index i → k = i+1 (canonical convention).
fn compute_row(
    i: usize,
    gram: &[f64],
    v: &[f64],
    dim: usize,
    big_omega: &[u32],
    mu: &[i8],
    omega_small: &[u32],
) -> RowResult {
    let vi = v[i];
    let k = i + 1; // canonical: index 0 → k=1
    let mut diag = 0.0f64;
    let mut bosonic_off = 0.0f64;
    let mut fermionic_off = 0.0f64;

    for j in 0..dim {
        let vj = v[j];
        let g = gram[i * dim + j];
        let term = vi * vj * g;
        let kj = j + 1;

        if i == j {
            diag = term;
        } else {
            let omega_sum = big_omega[k] + big_omega[kj];
            if omega_sum.is_multiple_of(2) {
                bosonic_off += term;
            } else {
                fermionic_off += term;
            }
        }
    }

    RowResult {
        ptype: classify(k, mu[k], omega_small[k]),
        diag,
        bosonic_off,
        fermionic_off,
    }
}

// ═══════════════════════════════════════════════════════
// §5. AGGREGATION + OUTPUT
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
    fn total(&self) -> f64 {
        self.diag + self.bosonic + self.fermionic
    }
}

fn aggregate(rows: &[RowResult]) -> Vec<TypeStats> {
    let mut map: std::collections::HashMap<String, TypeStats> = std::collections::HashMap::new();
    for r in rows {
        let label = r.ptype.label();
        let entry = map.entry(label.clone()).or_insert(TypeStats {
            label,
            order: r.ptype.order(),
            count: 0,
            diag: 0.0,
            bosonic: 0.0,
            fermionic: 0.0,
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

fn print_census(n: usize, dim: usize, stats: &[TypeStats], vtgv: f64) {
    let ln_n = (n as f64).ln();
    println!();
    println!(
        "╔══════════════════════════════════════════════════════════════════════════════════╗"
    );
    println!(
        "║  PARTICLE ZOO CENSUS (H5)   N = {:>6}   dim = {:>6}                            ║",
        n, dim
    );
    println!(
        "╠══════════════════════════════════════════════════════════════════════════════════╣"
    );
    println!(
        "║ {:<14} {:>6} {:>12} {:>12} {:>12} {:>12} {:>8} ║",
        "Type", "Count", "Diagonal", "Bosonic", "Fermionic", "Total", "Frac%"
    );
    println!(
        "╠══════════════════════════════════════════════════════════════════════════════════╣"
    );

    let mut sum_d = 0.0f64;
    let mut sum_b = 0.0f64;
    let mut sum_f = 0.0f64;

    for s in stats {
        let frac = if vtgv.abs() > 1e-15 {
            s.total() / vtgv * 100.0
        } else {
            0.0
        };
        println!(
            "║ {:<14} {:>6} {:>+12.4} {:>+12.4} {:>+12.4} {:>+12.4} {:>+7.1}% ║",
            s.label,
            s.count,
            s.diag,
            s.bosonic,
            s.fermionic,
            s.total(),
            frac
        );
        sum_d += s.diag;
        sum_b += s.bosonic;
        sum_f += s.fermionic;
    }

    println!(
        "╠══════════════════════════════════════════════════════════════════════════════════╣"
    );
    println!(
        "║ {:<14} {:>6} {:>+12.4} {:>+12.4} {:>+12.4} {:>+12.4} {:>7}  ║",
        "TOTAL", dim, sum_d, sum_b, sum_f, vtgv, "100.0%"
    );
    println!(
        "╠══════════════════════════════════════════════════════════════════════════════════╣"
    );
    println!(
        "║  vᵀGv      = {:>+16.10}                                               ║",
        vtgv
    );
    println!(
        "║  1 - vᵀGv  = {:>+16.10}                                               ║",
        1.0 - vtgv
    );
    println!(
        "║  gap·ln(N) = {:>16.10}   (stable if K/lnN form)                  ║",
        (1.0 - vtgv) * ln_n
    );
    println!(
        "║  B_off     = {:>+16.10}                                               ║",
        sum_b
    );
    println!(
        "║  F_off     = {:>+16.10}                                               ║",
        sum_f
    );

    let cancel = if sum_b.abs().max(sum_f.abs()) > 1e-15 {
        (1.0 - (sum_b + sum_f).abs() / sum_b.abs().max(sum_f.abs())) * 100.0
    } else {
        0.0
    };
    println!(
        "║  SUSY      = {:>16.10}   ({:.2}% cancellation)                ║",
        (sum_b + sum_f).abs(),
        cancel
    );

    if vtgv < 1.0 {
        println!(
            "║  STATUS: ✅ vᵀGv < 1  (margin = {:.6})                                     ║",
            1.0 - vtgv
        );
    }
    println!(
        "╚══════════════════════════════════════════════════════════════════════════════════╝"
    );
}

fn write_summary_line(stats: &[TypeStats], n: usize, vtgv: f64, path: &str) -> std::io::Result<()> {
    let exists = std::path::Path::new(path).exists();
    let mut f = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)?;

    if !exists {
        writeln!(f, "N\tvtgv\tgap\tgap_ln\tdiag\tbos\tfer\tcancel%\tvacuum\thiggs\tquark\tmeson\tbaryon\ttetra\tpenta\thexa\texcluded")?;
    }

    let get = |label: &str| -> f64 {
        stats
            .iter()
            .find(|s| s.label == label)
            .map(|s| s.total())
            .unwrap_or(0.0)
    };

    let ln_n = (n as f64).ln();
    let d: f64 = stats.iter().map(|s| s.diag).sum();
    let b: f64 = stats.iter().map(|s| s.bosonic).sum();
    let ff: f64 = stats.iter().map(|s| s.fermionic).sum();
    let cancel = if b.abs().max(ff.abs()) > 1e-15 {
        (1.0 - (b + ff).abs() / b.abs().max(ff.abs())) * 100.0
    } else {
        0.0
    };

    writeln!(f, "{}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.2}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}",
        n, vtgv, 1.0 - vtgv, (1.0 - vtgv) * ln_n,
        d, b, ff, cancel,
        get("Vacuum"), get("Higgs"), get("Quark"), get("Meson"),
        get("Baryon"), get("Tetraquark"), get("Pentaquark"), get("Hexaquark"),
        get("Excluded"))?;
    Ok(())
}

// ═══════════════════════════════════════════════════════
// §6. MAIN
// ═══════════════════════════════════════════════════════

fn main() {
    let args = Args::parse();

    println!("╔═══════════════════════════════════════════════════════════════════╗");
    println!("║  PARTICLE ZOO CENSUS (H5) — Canonical k=1..N-1 Indexing        ║");
    println!("╚═══════════════════════════════════════════════════════════════════╝");

    let cache_dir = Path::new(&args.cache_dir);
    if !cache_dir.exists() {
        eprintln!("Cache directory not found: {}", args.cache_dir);
        return;
    }

    // Find all H5 files
    let mut h5_files: Vec<(usize, PathBuf)> = std::fs::read_dir(cache_dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let name = e.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".h5") && !name.contains("_p") {
                let n_str = name.strip_prefix("gram_N")?.strip_suffix(".h5")?;
                let n: usize = n_str.parse().ok()?;
                if n <= args.max_n && n >= 6 {
                    return Some((n, e.path()));
                }
                None
            } else {
                None
            }
        })
        .collect();

    h5_files.sort_by_key(|(n, _)| *n);
    println!(
        "\n  Found {} HPDF files (N ≤ {})\n",
        h5_files.len(),
        args.max_n
    );

    let _ = std::fs::create_dir_all(&args.output);
    let summary_path = format!("{}/zoo_census_h5_summary.tsv", args.output);
    let _ = std::fs::remove_file(&summary_path); // Fresh run

    for (n, path) in &h5_files {
        let n = *n;
        let dim = n - 1; // canonical dimension: k=1..N-1
        eprint!("  N = {:>6} (dim={}) ... ", n, dim);

        let t0 = std::time::Instant::now();

        // Step 1: Read H5 Gram matrix (k=2..N, h5_dim = N-1)
        let reader = match HpdfReader::open(path) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("SKIP ({})", e);
                continue;
            }
        };
        let h5_dim = reader.dim();
        let h5_gram = match reader.read_gram_full() {
            Ok(g) => g,
            Err(e) => {
                eprintln!("SKIP ({})", e);
                continue;
            }
        };
        if h5_gram.len() != h5_dim * h5_dim {
            eprintln!("SKIP (H5 dim mismatch)");
            continue;
        }
        eprint!("H5 loaded ... ");

        // Step 2: Compute k=1 row (G(1,k) for k=1..N-1)
        let row1 = build_row1(n);
        eprint!("row1 done ... ");

        // Step 3: Assemble canonical (N-1)×(N-1) matrix
        let gram = assemble_gram(n, &h5_gram, h5_dim, &row1);
        // Free the H5 matrix to save memory
        drop(h5_gram);
        eprint!("assembled ... ");

        // Step 4: Compute arithmetic data
        let mu = arith::mobius_table(n);
        let omega_small = arith::small_omega_table(n);
        let mut big_omega = vec![0u32; n + 1];
        {
            let is_prime = arith::sieve_primes(n + 1);
            for p in 2..=n {
                if !is_prime[p] {
                    continue;
                }
                let mut pk = p;
                while pk <= n {
                    for m in (pk..=n).step_by(pk) {
                        big_omega[m] += 1;
                    }
                    if pk > n / p {
                        break;
                    }
                    pk *= p;
                }
            }
        }

        // Step 5: Build witness vector (canonical: k=1..N-1)
        let ln_n = (n as f64).ln();
        let v: Vec<f64> = (1..n)
            .map(|k| -(mu[k] as f64) * (1.0 - (k as f64).ln() / ln_n))
            .collect();

        // Step 6: Parallel row computation
        let rows: Vec<RowResult> = (0..dim)
            .into_par_iter()
            .map(|i| compute_row(i, &gram, &v, dim, &big_omega, &mu, &omega_small))
            .collect();

        let vtgv: f64 = rows.iter().map(|r| r.total()).sum();
        let elapsed = t0.elapsed().as_secs_f64();
        eprintln!(
            "vᵀGv = {:.6}  gap = {:.6}  ({:.1}s)",
            vtgv,
            1.0 - vtgv,
            elapsed
        );

        let stats = aggregate(&rows);
        print_census(n, dim, &stats, vtgv);

        if let Err(e) = write_summary_line(&stats, n, vtgv, &summary_path) {
            eprintln!("  Warning: summary write failed: {}", e);
        }
    }

    println!("\n  → Summary: {}", summary_path);
}
