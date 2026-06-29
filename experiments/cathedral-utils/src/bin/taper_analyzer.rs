#![allow(
    dead_code,
    unused_variables,
    clippy::needless_range_loop,
    clippy::empty_line_after_doc_comments,
    clippy::doc_lazy_continuation
)]
//! ═══════════════════════════════════════════════════════════════════════════
//!  TAPER SUM ANALYZER — Exploration 30
//!
//!  Loads cached HPDF Gram matrices and computes the three taper sums
//!  from TaperDecomposition.lean. Optimized for large N with rayon.
//!
//!  Usage:
//!    cargo run --release --features hpdf --bin taper-analyzer -- <path_to_hpdf>
//!    cargo run --release --features hpdf --bin taper-analyzer -- --all
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::arith;
use cathedral_utils::hpdf::HpdfReader;
use rayon::prelude::*;
use std::path::Path;
use std::time::Instant;

const BOLD: &str = "\x1b[1m";
const RESET: &str = "\x1b[0m";
const GREEN: &str = "\x1b[32m";
const CYAN: &str = "\x1b[36m";
const YELLOW: &str = "\x1b[33m";
const DIM: &str = "\x1b[2m";
const WHITE: &str = "\x1b[97m";
const MAGENTA: &str = "\x1b[35m";

fn mobius_sieve(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    mu[1] = 1;
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            let ip = i * p;
            if ip > n {
                break;
            }
            is_prime[ip] = false;
            if i % p == 0 {
                mu[ip] = 0;
                break;
            } else {
                mu[ip] = -mu[i];
            }
        }
    }
    mu
}

/// Analyze a single HPDF file.
fn analyze(path: &Path) {
    let t0 = Instant::now();
    println!("\n  {BOLD}{WHITE}Loading: {RESET}{}", path.display());
    let reader = HpdfReader::open(path).expect("Failed to open HPDF file");
    let dim = reader.dim();
    let max_n = reader.max_n();
    let mem_gb = (dim * dim * 8) as f64 / 1e9;
    println!("  {DIM}dim={dim}, max_N={max_n}, matrix={mem_gb:.1} GB{RESET}");

    let gram = reader.read_gram_full().expect("Failed to read Gram matrix");
    println!(
        "  {GREEN}✓{RESET} Gram loaded ({:.1}s)",
        t0.elapsed().as_secs_f64()
    );

    let mu = mobius_sieve(max_n);
    let log_n = (max_n as f64).ln();

    // ── §1. TAPER SUMS (parallelized by row) ──
    let t1 = Instant::now();

    // Precompute which indices have nonzero μ
    let mu_nonzero: Vec<(usize, f64, f64)> = (2..=max_n)
        .filter(|&k| mu[k] != 0)
        .map(|k| (k, mu[k] as f64, (k as f64).ln()))
        .collect();

    // j=1 row contribution (not in H5)
    let mu1 = mu[1] as f64;
    let mut u_j1 = 0.0f64;
    let mut l_j1 = 0.0f64;
    // j=1,k=1
    let g_11 = cathedral_utils::gram::gram_entry_f64(1, 1);
    u_j1 += mu1 * mu1 * g_11;
    // j=1,k>1 and k=1,j>1 (using symmetry)
    for &(k, mu_k, ln_k) in &mu_nonzero {
        let g_1k = cathedral_utils::gram::gram_entry_f64(1, k);
        u_j1 += 2.0 * mu1 * mu_k * g_1k; // j=1,k + k,j=1
        l_j1 += mu1 * mu_k * ln_k * g_1k; // only k→j direction (ln(1)=0 for j=1)
    }

    // Main sum over j,k ∈ {2,...,max_n} from H5 (parallel over rows)
    struct RowResult {
        u: f64,
        l: f64,
        q: f64,
        vtgv: f64,
    }

    let row_results: Vec<RowResult> = (0..dim)
        .into_par_iter()
        .map(|row| {
            let j = row + 2;
            let mu_j = mu[j] as f64;
            if mu_j == 0.0 {
                return RowResult {
                    u: 0.0,
                    l: 0.0,
                    q: 0.0,
                    vtgv: 0.0,
                };
            }
            let ln_j = (j as f64).ln();
            let w_j = -mu_j * (1.0 - ln_j / log_n);
            let (mut u, mut l, mut q, mut v) = (0.0, 0.0, 0.0, 0.0);
            for col in 0..dim {
                let k = col + 2;
                let mu_k = mu[k] as f64;
                if mu_k == 0.0 {
                    continue;
                }
                let ln_k = (k as f64).ln();
                let w_k = -mu_k * (1.0 - ln_k / log_n);
                let g = gram[row * dim + col];
                let mm = mu_j * mu_k;
                u += mm * g;
                l += mm * ln_j * g;
                q += mm * ln_j * ln_k * g;
                v += w_j * w_k * g;
            }
            RowResult { u, l, q, vtgv: v }
        })
        .collect();

    let mut untapered = u_j1;
    let mut linear = l_j1;
    let mut quad = 0.0f64;
    let mut vtgv = 0.0f64;
    for r in &row_results {
        untapered += r.u;
        linear += r.l;
        quad += r.q;
        vtgv += r.vtgv;
    }

    let reconstructed = untapered - 2.0 / log_n * linear + quad / (log_n * log_n);

    println!(
        "\n  {BOLD}{CYAN}═══ §1. TAPER SUMS ({:.1}s) ═══{RESET}",
        t1.elapsed().as_secs_f64()
    );
    println!("  N={max_n}  ln(N)={log_n:.6}");
    println!("  U(N)       = {MAGENTA}{untapered:.10}{RESET}");
    println!("  L(N)       = {MAGENTA}{linear:.10}{RESET}");
    println!("  L+lnN/2    = {YELLOW}{:.10}{RESET}", linear + log_n / 2.0);
    println!("  Q(N)       = {MAGENTA}{quad:.10}{RESET}");
    println!("  |Q|/lnN    = {YELLOW}{:.10}{RESET}", quad.abs() / log_n);
    println!("  Recon      = {MAGENTA}{reconstructed:.10}{RESET}");
    println!("  vᵀGv       = {MAGENTA}{vtgv:.10}{RESET}");

    // ── §2. POINTWISE BOUNDS (parallel) ──
    let t2 = Instant::now();

    struct PwResult {
        max_g: f64,
        max_g_j: usize,
        max_g_k: usize,
        min_g: f64,
        min_g_j: usize,
        min_g_k: usize,
        max_jkg_all: f64,
        max_jkg_all_j: usize,
        max_jkg_all_k: usize,
        max_jkg_cop: f64,
        max_jkg_cop_j: usize,
        max_jkg_cop_k: usize,
    }

    let pw: Vec<PwResult> = (0..dim)
        .into_par_iter()
        .map(|row| {
            let j = row + 2;
            let mut r = PwResult {
                max_g: f64::NEG_INFINITY,
                max_g_j: 0,
                max_g_k: 0,
                min_g: f64::INFINITY,
                min_g_j: 0,
                min_g_k: 0,
                max_jkg_all: 0.0,
                max_jkg_all_j: 0,
                max_jkg_all_k: 0,
                max_jkg_cop: 0.0,
                max_jkg_cop_j: 0,
                max_jkg_cop_k: 0,
            };
            for col in row..dim {
                let k = col + 2;
                let g = gram[row * dim + col];
                let jkg = (j as f64) * (k as f64) * g;
                if g > r.max_g {
                    r.max_g = g;
                    r.max_g_j = j;
                    r.max_g_k = k;
                }
                if g < r.min_g {
                    r.min_g = g;
                    r.min_g_j = j;
                    r.min_g_k = k;
                }
                if jkg > r.max_jkg_all {
                    r.max_jkg_all = jkg;
                    r.max_jkg_all_j = j;
                    r.max_jkg_all_k = k;
                }
                if j != k && arith::gcd(j, k) == 1 && jkg > r.max_jkg_cop {
                    r.max_jkg_cop = jkg;
                    r.max_jkg_cop_j = j;
                    r.max_jkg_cop_k = k;
                }
            }
            r
        })
        .collect();

    let mut best = PwResult {
        max_g: f64::NEG_INFINITY,
        max_g_j: 0,
        max_g_k: 0,
        min_g: f64::INFINITY,
        min_g_j: 0,
        min_g_k: 0,
        max_jkg_all: 0.0,
        max_jkg_all_j: 0,
        max_jkg_all_k: 0,
        max_jkg_cop: 0.0,
        max_jkg_cop_j: 0,
        max_jkg_cop_k: 0,
    };
    for r in &pw {
        if r.max_g > best.max_g {
            best.max_g = r.max_g;
            best.max_g_j = r.max_g_j;
            best.max_g_k = r.max_g_k;
        }
        if r.min_g < best.min_g {
            best.min_g = r.min_g;
            best.min_g_j = r.min_g_j;
            best.min_g_k = r.min_g_k;
        }
        if r.max_jkg_all > best.max_jkg_all {
            best.max_jkg_all = r.max_jkg_all;
            best.max_jkg_all_j = r.max_jkg_all_j;
            best.max_jkg_all_k = r.max_jkg_all_k;
        }
        if r.max_jkg_cop > best.max_jkg_cop {
            best.max_jkg_cop = r.max_jkg_cop;
            best.max_jkg_cop_j = r.max_jkg_cop_j;
            best.max_jkg_cop_k = r.max_jkg_cop_k;
        }
    }

    println!(
        "\n  {BOLD}{CYAN}═══ §2. POINTWISE BOUNDS ({:.1}s) ═══{RESET}",
        t2.elapsed().as_secs_f64()
    );
    println!(
        "  max G    = {:.10} at ({},{})",
        best.max_g, best.max_g_j, best.max_g_k
    );
    println!(
        "  min G    = {:.10} at ({},{})",
        best.min_g, best.min_g_j, best.min_g_k
    );
    println!(
        "  max jk·G ALL    = {YELLOW}{:.6}{RESET} at ({},{})",
        best.max_jkg_all, best.max_jkg_all_j, best.max_jkg_all_k
    );
    println!(
        "  max jk·G COPRIME= {YELLOW}{:.6}{RESET} at ({},{})",
        best.max_jkg_cop, best.max_jkg_cop_j, best.max_jkg_cop_k
    );

    // Diagonal
    for &k in &[2, 10, 100, 1000, 10000, 50000] {
        if k > max_n {
            break;
        }
        let row = k - 2;
        if row >= dim {
            break;
        }
        let g_kk = gram[row * dim + row];
        println!("  k={:<6} k·G(k,k) = {:.6}", k, (k as f64) * g_kk);
    }

    // ── §3. MÖBIUS COLUMN SUMS (parallel, sampled output) ──
    let t3 = Instant::now();

    struct ColResult {
        j: usize,
        s: f64,
    }
    let cols: Vec<ColResult> = (0..dim)
        .into_par_iter()
        .map(|row| {
            let j = row + 2;
            let mut s = 0.0f64;
            for col in 0..dim {
                let k = col + 2;
                let mu_k = mu[k] as f64;
                if mu_k == 0.0 {
                    continue;
                }
                s += mu_k * gram[row * dim + col];
            }
            ColResult { j, s }
        })
        .collect();

    let mut max_abs_s = 0.0f64;
    let mut max_abs_j = 0usize;
    let mut max_js = 0.0f64;
    let mut max_js_j = 0usize;
    for c in &cols {
        let a = c.s.abs();
        if a > max_abs_s {
            max_abs_s = a;
            max_abs_j = c.j;
        }
        let ja = (c.j as f64) * a;
        if ja > max_js {
            max_js = ja;
            max_js_j = c.j;
        }
    }

    println!(
        "\n  {BOLD}{CYAN}═══ §3. MÖBIUS COLUMN SUMS ({:.1}s) ═══{RESET}",
        t3.elapsed().as_secs_f64()
    );
    // Print a few samples
    for &target_j in &[2, 10, 100, 1000, 5000, 10000, 20000, 50000] {
        if target_j > max_n {
            break;
        }
        let idx = target_j - 2;
        if idx >= cols.len() {
            break;
        }
        let c = &cols[idx];
        println!(
            "  j={:<6} S={:>12.8}  j·|S|={:.4}",
            c.j,
            c.s,
            (c.j as f64) * c.s.abs()
        );
    }
    println!("  max|S|   = {:.8} at j={}", max_abs_s, max_abs_j);
    println!("  max j|S| = {:.4} at j={}", max_js, max_js_j);

    // ── §4. GCD BOUND (sampled for large N) ──
    let t4 = Instant::now();
    let sample_mode = dim > 15000;

    struct BoundResult {
        checked: u64,
        violations: u64,
        worst: f64,
        wj: usize,
        wk: usize,
    }

    let bound_results: Vec<BoundResult> = (0..dim)
        .into_par_iter()
        .map(|row| {
            let j = row + 2;
            // For large matrices, sample every ~10th row
            if sample_mode && row % 10 != 0 {
                return BoundResult {
                    checked: 0,
                    violations: 0,
                    worst: f64::NEG_INFINITY,
                    wj: 0,
                    wk: 0,
                };
            }
            let mut br = BoundResult {
                checked: 0,
                violations: 0,
                worst: f64::NEG_INFINITY,
                wj: 0,
                wk: 0,
            };
            let col_step = if sample_mode { 10 } else { 1 };
            let mut col = row + 1;
            while col < dim {
                let k = col + 2;
                br.checked += 1;
                let g = arith::gcd(j, k) as f64;
                let fj = j as f64;
                let fk = k as f64;
                let bound = 0.25 + g * g / (12.0 * fj * fk) + 1.0 / (4.0 * fk);
                let excess = gram[row * dim + col] - bound;
                if excess > br.worst {
                    br.worst = excess;
                    br.wj = j;
                    br.wk = k;
                }
                if excess > 1e-10 {
                    br.violations += 1;
                }
                col += col_step;
            }
            br
        })
        .collect();

    let mut total_checked = 0u64;
    let mut total_violations = 0u64;
    let mut worst_excess = f64::NEG_INFINITY;
    let mut worst_j = 0;
    let mut worst_k = 0;
    for br in &bound_results {
        total_checked += br.checked;
        total_violations += br.violations;
        if br.worst > worst_excess {
            worst_excess = br.worst;
            worst_j = br.wj;
            worst_k = br.wk;
        }
    }

    println!(
        "\n  {BOLD}{CYAN}═══ §4. GCD BOUND{} ({:.1}s) ═══{RESET}",
        if sample_mode { " (sampled)" } else { "" },
        t4.elapsed().as_secs_f64()
    );
    println!("  Checked:    {total_checked}");
    println!("  Violations: {total_violations}");
    println!(
        "  Worst:      {:.6e} at ({},{})",
        worst_excess, worst_j, worst_k
    );
    if total_violations == 0 {
        println!("  {GREEN}✓ PASS{RESET}");
    }

    // ── CERTIFICATE ──
    println!("\n  {BOLD}{CYAN}╔══════════════════════════════════════════════════════╗{RESET}");
    println!(
        "  {BOLD}{CYAN}║{RESET} {BOLD}CERTIFICATE N={max_n}{RESET}  ({:.1}s total)",
        t0.elapsed().as_secs_f64()
    );
    println!("  {BOLD}{CYAN}╠══════════════════════════════════════════════════════╣{RESET}");
    println!(
        "  {BOLD}{CYAN}║{RESET} U(N)={:.8}  L(N)={:.8}  Q(N)={:.8}",
        untapered, linear, quad
    );
    println!("  {BOLD}{CYAN}║{RESET} |Q|/lnN={YELLOW}{:.6}{RESET}  Recon={MAGENTA}{:.8}{RESET}  vᵀGv={:.8}", quad.abs()/log_n, reconstructed, vtgv);
    println!(
        "  {BOLD}{CYAN}║{RESET} GCD bound: {} ({total_checked} pairs)",
        if total_violations == 0 {
            format!("{GREEN}PASS{RESET}")
        } else {
            format!("FAIL({total_violations})")
        }
    );
    println!("  {BOLD}{CYAN}╚══════════════════════════════════════════════════════╝{RESET}");
}

fn main() {
    println!("\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL TAPER SUM ANALYZER{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Exploration 30 · Taper Decomposition{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════╝{RESET}");

    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 || args[1] == "--help" {
        eprintln!("Usage: taper-analyzer <hpdf_file> [...]");
        eprintln!("       taper-analyzer --all");
        std::process::exit(1);
    }

    if args[1] == "--all" {
        let dirs = ["cache/hpdf", "../cache/hpdf"];
        for d in &dirs {
            let p = Path::new(d);
            if p.exists() {
                scan_dir(p);
                return;
            }
        }
        eprintln!("  No cache/hpdf/ found");
        std::process::exit(1);
    } else {
        for p in &args[1..] {
            analyze(Path::new(p));
        }
    }
}

fn scan_dir(dir: &Path) {
    let mut files: Vec<_> = std::fs::read_dir(dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().map(|x| x == "h5").unwrap_or(false))
        .map(|e| e.path())
        .collect();

    files.sort_by_key(|p| {
        p.file_stem()
            .and_then(|s| s.to_str())
            .and_then(|s| s.strip_prefix("gram_N"))
            .and_then(|s| s.split('_').next())
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(0)
    });

    println!("  Found {} HPDF files in {}", files.len(), dir.display());
    for path in &files {
        analyze(path);
    }
}
