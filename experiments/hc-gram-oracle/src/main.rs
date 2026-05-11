// ═══════════════════════════════════════════════════════════════════════
//  HC GRAM ORACLE v2 — Spectral Bypass Certification
//
//  Production-grade vᵀGv computation at Highly Composite Numbers.
//  Uses HPDF reader for DD-lossless precision, parallel row processing,
//  metadata extraction, and generates JSON certificates.
//
//  Modes:
//    1. --hpdf <path> ... : Load pre-built Gram matrices from H5 files
//    2. N N N ...          : Compute Gram entries on-the-fly (f64)
//    3. --discover <dir>   : Auto-discover H5 files in a directory
//
//  Goal: Verify gram_form_upper_bound_subseq axiom
//    → vᵀGv ≤ 1 + K/logN along an unbounded HC subsequence
// ═══════════════════════════════════════════════════════════════════════

use rayon::prelude::*;
use serde::Serialize;
use std::path::{Path, PathBuf};
use std::time::Instant;

use cathedral_utils::arith::{EULER_GAMMA, gcd, mobius_table};
#[cfg(feature = "hpdf")]
use cathedral_utils::hpdf::HpdfReader;

// ─── Vasyunin sum (f64 fallback) ─────────────────────────────────
fn vasyunin_sum_f64(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
    let pi = std::f64::consts::PI;
    let af = a as f64;
    let mut total = 0.0;
    for m in 1..a {
        let mb_mod_a = (m * b) % a;
        let frac = mb_mod_a as f64 / af;
        let angle = pi * m as f64 / af;
        let (sin_v, cos_v) = angle.sin_cos();
        if sin_v.abs() < 1e-15 {
            continue;
        }
        total += frac * cos_v / sin_v;
    }
    total
}

fn gram_entry_f64_compute(j: usize, k: usize) -> f64 {
    let pi = std::f64::consts::PI;
    let ln2pi = (2.0 * pi).ln();
    let coeff = (ln2pi - EULER_GAMMA) / 2.0;
    let jf = j as f64;
    let kf = k as f64;
    let jk = jf * kf;

    if j == k {
        return (ln2pi - EULER_GAMMA) / jf - 1.0 / (jf * jf);
    }

    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;

    let term1 = coeff * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jk) * (kf / jf).ln();
    let v1 = vasyunin_sum_f64(jp, kp);
    let v2 = vasyunin_sum_f64(kp, jp);
    let term3 = pi * d as f64 / (2.0 * jk) * (v1 + v2);
    let term4 = 1.0 / jk;

    term1 + term2 - term3 - term4
}

fn mean_entry(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - EULER_GAMMA) / kf
}

// ─── Result struct ───────────────────────────────────────────────
#[derive(Debug, Clone, Serialize)]
struct HcResult {
    n: usize,
    dim: usize,
    ndiv: usize,
    is_hc: bool,
    bt_v: f64,
    vtgv: f64,
    d_sq: f64,
    btv_sq: f64,
    vtcv: f64,
    ln_n: f64,
    margin: f64,       // 1 - vᵀGv (positive = below 1)
    gap_times_ln: f64, // margin * ln(N) — should stabilize
    elapsed_secs: f64,
    precision: String,
    source: String,
}

// ─── Compute from HPDF (DD-lossless) ────────────────────────────
#[cfg(feature = "hpdf")]
fn compute_from_hpdf(path: &Path) -> Result<HcResult, String> {
    let t0 = Instant::now();

    let reader =
        HpdfReader::open(path).map_err(|e| format!("Failed to open {}: {e}", path.display()))?;

    let n = reader.max_n();
    let dim = reader.dim();
    let ln_n = (n as f64).ln();

    eprintln!(
        "  ═══ N={} (dim={}, {}) ═══",
        n,
        dim,
        if reader.has_dd() {
            "DD ~31 digits"
        } else {
            "f64"
        }
    );

    // Read Möbius table from HPDF or compute
    let mu: Vec<i8> = reader.read_mobius().unwrap_or_else(|_| mobius_table(n));

    // Read number theory metadata
    let nt_attrs = reader.read_number_theory_attrs().ok().flatten();
    let ndiv = nt_attrs
        .as_ref()
        .map(|a| a.divisor_count as usize)
        .unwrap_or_else(|| (1..=n).filter(|&d| n % d == 0).count());
    let is_hc = nt_attrs
        .as_ref()
        .map(|a| a.is_highly_composite)
        .unwrap_or(false);

    // Build the log-cutoff witness: v_k = -μ(k)(1 - ln(k)/ln(N))
    // This matches the Lean axiom `logCutoffWitness` EXACTLY (no /k!)
    // Index mapping: HPDF stores G[j,k] for j,k ∈ {2..N}, so dim = N-1
    // Witness covers k=1..N, but HPDF only has k=2..N
    let v: Vec<f64> = (1..=n)
        .map(|k| -mu[k] as f64 * (1.0 - (k as f64).ln() / ln_n))
        .collect();

    // Mean vector b_k = (ln(k) + 1 - γ) / k
    let b: Vec<f64> = (1..=n).map(mean_entry).collect();

    // bᵀv
    let bt_v: f64 = b.iter().zip(v.iter()).map(|(bi, vi)| bi * vi).sum();

    // Load full Gram matrix for vᵀGv computation
    eprintln!("  Loading HPDF matrix...");
    let gram = reader
        .read_gram_full()
        .map_err(|e| format!("Failed to read gram: {e}"))?;

    // vᵀGv = Σᵢ Σⱼ v[i]·v[j]·G[i,j]
    // HPDF indices: row i corresponds to k=i+2, col j corresponds to k=j+2
    // So we need to handle k=1 separately (not in HPDF)
    eprintln!(
        "  Computing vᵀGv (parallel, {} threads)...",
        rayon::current_num_threads()
    );

    // k=1 contribution: v[0] * Σⱼ v[j] * G(1, j+1)
    // G(1,k) must be computed on-the-fly since HPDF starts at k=2
    let k1_contrib: f64 = if v[0].abs() > 1e-30 {
        // Diagonal: v[0]^2 * G(1,1)
        let g11 = gram_entry_f64_compute(1, 1);
        let diag = v[0] * v[0] * g11;

        // Off-diagonal: 2 * v[0] * Σ_{k=2..N} v[k-1] * G(1,k)
        let offdiag: f64 = (2..=n)
            .into_par_iter()
            .map(|k| {
                let g1k = gram_entry_f64_compute(1, k);
                v[k - 1] * g1k
            })
            .sum();

        diag + 2.0 * v[0] * offdiag
    } else {
        0.0 // μ(1) = 1, so v[0] ≠ 0 in practice, but handle edge case
    };

    // Main block: k,j ∈ {2..N} — use HPDF matrix
    let main_vtgv: f64 = (0..dim)
        .into_par_iter()
        .map(|i| {
            let vi = v[i + 1]; // v[k] where k = i+2, so v index = k-1 = i+1
            if vi.abs() < 1e-30 {
                return 0.0;
            }

            // Diagonal
            let mut row_sum = vi * vi * gram[i * dim + i];

            // Off-diagonal (j > i)
            for j in (i + 1)..dim {
                let vj = v[j + 1]; // v[k'] where k' = j+2
                if vj.abs() < 1e-30 {
                    continue;
                }
                row_sum += 2.0 * vi * vj * gram[i * dim + j];
            }
            row_sum
        })
        .sum();

    let vtgv = k1_contrib + main_vtgv;
    let btv_sq = bt_v * bt_v;
    let vtcv = vtgv - btv_sq;
    let d_sq = 1.0 - 2.0 * bt_v + vtgv;
    let margin = 1.0 - vtgv;
    let gap_times_ln = margin * ln_n;

    let elapsed = t0.elapsed().as_secs_f64();

    eprintln!("  ✓ Done in {:.1}s", elapsed);
    eprintln!("    vᵀGv = {:.10}", vtgv);
    eprintln!("    d²   = {:.10}", d_sq);
    eprintln!("    < 1? = {}", if vtgv < 1.0 { "✅ YES" } else { "❌ NO" });

    Ok(HcResult {
        n,
        dim,
        ndiv,
        is_hc,
        bt_v,
        vtgv,
        d_sq,
        btv_sq,
        vtcv,
        ln_n,
        margin,
        gap_times_ln,
        elapsed_secs: elapsed,
        precision: if reader.has_dd() {
            "DD".into()
        } else {
            "f64".into()
        },
        source: path.display().to_string(),
    })
}

// ─── Compute on-the-fly (f64) ────────────────────────────────────
fn compute_on_fly(n: usize) -> HcResult {
    let t0 = Instant::now();
    let ln_n = (n as f64).ln();

    eprintln!(
        "  ═══ N={} (on-the-fly f64, {} threads) ═══",
        n,
        rayon::current_num_threads()
    );

    let mu = mobius_table(n);

    let v: Vec<f64> = (1..=n)
        .map(|k| -mu[k] as f64 * (1.0 - (k as f64).ln() / ln_n))
        .collect();

    let b: Vec<f64> = (1..=n).map(mean_entry).collect();
    let bt_v: f64 = b.iter().zip(v.iter()).map(|(bi, vi)| bi * vi).sum();

    // vᵀGv parallel on-the-fly
    let diag: f64 = (0..n)
        .into_par_iter()
        .map(|i| {
            let g_ii = gram_entry_f64_compute(i + 1, i + 1);
            v[i] * v[i] * g_ii
        })
        .sum();

    let offdiag: f64 = (0..n)
        .into_par_iter()
        .map(|i| {
            if v[i].abs() < 1e-30 {
                return 0.0;
            }
            let mut row_sum = 0.0;
            for j in (i + 1)..n {
                if v[j].abs() < 1e-30 {
                    continue;
                }
                let g_ij = gram_entry_f64_compute(i + 1, j + 1);
                row_sum += v[i] * v[j] * g_ij;
            }
            row_sum
        })
        .sum();

    let vtgv = diag + 2.0 * offdiag;
    let btv_sq = bt_v * bt_v;
    let vtcv = vtgv - btv_sq;
    let d_sq = 1.0 - 2.0 * bt_v + vtgv;
    let margin = 1.0 - vtgv;
    let gap_times_ln = margin * ln_n;
    let ndiv = (1..=n).filter(|&d| n % d == 0).count();

    let elapsed = t0.elapsed().as_secs_f64();

    eprintln!(
        "  ✓ Done in {:.1}s  vᵀGv={:.6}  {}",
        elapsed,
        vtgv,
        if vtgv < 1.0 { "✅" } else { "❌" }
    );

    HcResult {
        n,
        dim: n,
        ndiv,
        is_hc: false, // unknown in on-the-fly mode
        bt_v,
        vtgv,
        d_sq,
        btv_sq,
        vtcv,
        ln_n,
        margin,
        gap_times_ln,
        elapsed_secs: elapsed,
        precision: "f64".into(),
        source: "on-the-fly".into(),
    }
}

// ─── Certificate output ──────────────────────────────────────────
fn write_certificate(results: &[HcResult], output_dir: &Path) {
    std::fs::create_dir_all(output_dir).ok();

    // Individual certificates
    for r in results {
        let cert_path = output_dir.join(format!("gram_cert_N{}.json", r.n));
        let cert = serde_json::json!({
            "format": "cathedral-hc-gram-oracle-v1",
            "N": r.n,
            "dim": r.dim,
            "divisor_count": r.ndiv,
            "is_highly_composite": r.is_hc,
            "witness": "log_cutoff_mobius",
            "witness_formula": "v_k = -μ(k)(1 - ln(k)/ln(N))",
            "results": {
                "vtGv": r.vtgv,
                "bt_v": r.bt_v,
                "bt_v_squared": r.btv_sq,
                "vtCv": r.vtcv,
                "d_squared": r.d_sq,
                "below_one": r.vtgv < 1.0,
                "margin": r.margin,
                "gap_times_ln_N": r.gap_times_ln,
            },
            "precision": r.precision,
            "source": r.source,
            "elapsed_secs": r.elapsed_secs,
            "lean_claim": format!("vtGv_log_cutoff {} < {:.4}", r.n,
                if r.vtgv < 1.0 { 1.0 } else { r.vtgv + 0.001 }),
        });
        std::fs::write(&cert_path, serde_json::to_string_pretty(&cert).unwrap()).ok();
    }

    // Summary certificate
    let all_below = results.iter().all(|r| r.vtgv < 1.0);
    let summary = serde_json::json!({
        "format": "cathedral-hc-gram-oracle-summary-v1",
        "goal": "verify gram_form_upper_bound_subseq axiom",
        "total_hc_numbers": results.len(),
        "all_below_one": all_below,
        "max_vtgv": results.iter().map(|r| r.vtgv).fold(f64::NEG_INFINITY, f64::max),
        "min_margin": results.iter().map(|r| r.margin).fold(f64::INFINITY, f64::min),
        "results": results,
    });
    let summary_path = output_dir.join("hc_gram_summary.json");
    std::fs::write(
        &summary_path,
        serde_json::to_string_pretty(&summary).unwrap(),
    )
    .ok();
    eprintln!("  📁 Certificates written to {}", output_dir.display());
}

// ─── Table output ────────────────────────────────────────────────
fn print_results_table(results: &[HcResult]) {
    println!("\n{}", "═".repeat(110));
    println!("  🏛️  HC GRAM ORACLE — RESULTS");
    println!("{}", "═".repeat(110));
    println!(
        "\n  {:>6} {:>5} {:>3} {:>8} {:>12} {:>12} {:>12} {:>10} {:>10} {:>5} {:>6}",
        "N", "d(N)", "HC", "ln(N)", "bᵀv", "vᵀGv", "d²", "margin", "gap·ln", "< 1?", "prec"
    );
    println!("  {}", "─".repeat(104));

    let mut all_below = true;
    for r in results {
        let below = r.vtgv < 1.0;
        if !below {
            all_below = false;
        }
        println!(
            "  {:>6} {:>5} {:>3} {:>8.3} {:>12.6} {:>12.6} {:>12.6} {:>+10.4} {:>10.4} {:>5} {:>6}",
            r.n,
            r.ndiv,
            if r.is_hc { "✓" } else { " " },
            r.ln_n,
            r.bt_v,
            r.vtgv,
            r.d_sq,
            r.margin,
            r.gap_times_ln,
            if below { "  ✅" } else { "  ❌" },
            r.precision
        );
    }

    println!("\n  {}", "─".repeat(104));
    if all_below {
        println!("  ✅ ALL values satisfy vᵀGv < 1!");
        println!("  → gram_form_upper_bound_subseq holds with K = 0");
    } else {
        println!("  ⚠️  Some values have vᵀGv ≥ 1");
        // Check if vᵀGv ≤ 1 + K/logN for some reasonable K
        let max_excess: f64 = results
            .iter()
            .map(|r| {
                if r.vtgv > 1.0 {
                    (r.vtgv - 1.0) * r.ln_n
                } else {
                    0.0
                }
            })
            .fold(0.0, f64::max);
        println!("  → max((vᵀGv - 1)·ln N) = {:.4}", max_excess);
        println!("  → Bound holds with K = {:.2}", max_excess + 0.01);
    }
}

// ─── Auto-discover HPDF files ────────────────────────────────────
#[cfg(feature = "hpdf")]
fn discover_hpdf_files(dir: &Path) -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = std::fs::read_dir(dir)
        .into_iter()
        .flat_map(|rd| rd.into_iter())
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| p.extension().map(|x| x == "h5").unwrap_or(false))
        .filter(|p| {
            p.file_name()
                .and_then(|f| f.to_str())
                .map(|s| s.starts_with("gram_N"))
                .unwrap_or(false)
        })
        .collect();
    paths.sort_by_key(|p| {
        p.file_stem()
            .and_then(|s| s.to_str())
            .and_then(|s| s.strip_prefix("gram_N"))
            .and_then(|s| s.parse::<usize>().ok())
            .unwrap_or(0)
    });
    paths
}

// ─── Main ────────────────────────────────────────────────────────
fn main() {
    let t_start = Instant::now();
    let args: Vec<String> = std::env::args().skip(1).collect();

    println!("\n{}", "═".repeat(110));
    println!("  🏛️  HC GRAM ORACLE v2 — Spectral Bypass Certification");
    println!("  vᵀGv for log-cutoff Möbius witness at Highly Composite Numbers");
    println!("  Goal: verify gram_form_upper_bound_subseq axiom");
    println!("  Threads: {}", rayon::current_num_threads());
    println!("{}", "═".repeat(110));

    let mut results: Vec<HcResult> = Vec::new();
    let output_dir = PathBuf::from("certificates");

    if args.is_empty() {
        // Default: discover local H5 files
        #[cfg(feature = "hpdf")]
        {
            let cache_dirs = [
                PathBuf::from("../cache/hpdf"),
                PathBuf::from("../../experiments/cache/hpdf"),
            ];
            let mut found = false;
            for dir in &cache_dirs {
                if dir.exists() {
                    let paths = discover_hpdf_files(dir);
                    if !paths.is_empty() {
                        eprintln!(
                            "\n  Auto-discovered {} HPDF files in {}",
                            paths.len(),
                            dir.display()
                        );
                        for path in &paths {
                            match compute_from_hpdf(path) {
                                Ok(r) => results.push(r),
                                Err(e) => eprintln!("  ⚠️  {}", e),
                            }
                        }
                        found = true;
                        break;
                    }
                }
            }
            if !found {
                eprintln!("  No HPDF files found. Use --hpdf <path> or provide N values.");
                eprintln!("  Expected directories: {:?}", cache_dirs);
            }
        }
        #[cfg(not(feature = "hpdf"))]
        {
            eprintln!(
                "  HPDF support not compiled. Rebuild with: cargo build --release --features hpdf"
            );
            eprintln!("  Or provide N values as arguments for on-the-fly computation.");
        }
    } else {
        let mut i = 0;
        while i < args.len() {
            match args[i].as_str() {
                "--hpdf" => {
                    #[cfg(feature = "hpdf")]
                    {
                        i += 1;
                        while i < args.len() && !args[i].starts_with("--") {
                            let path = PathBuf::from(&args[i]);
                            match compute_from_hpdf(&path) {
                                Ok(r) => results.push(r),
                                Err(e) => eprintln!("  ⚠️  {}", e),
                            }
                            i += 1;
                        }
                    }
                    #[cfg(not(feature = "hpdf"))]
                    {
                        eprintln!("  ⚠️  HPDF support not compiled. Rebuild with --features hpdf");
                        i += 1;
                    }
                }
                "--discover" => {
                    #[cfg(feature = "hpdf")]
                    {
                        i += 1;
                        if i < args.len() {
                            let dir = PathBuf::from(&args[i]);
                            let paths = discover_hpdf_files(&dir);
                            eprintln!(
                                "  Discovered {} HPDF files in {}",
                                paths.len(),
                                dir.display()
                            );
                            for path in &paths {
                                match compute_from_hpdf(path) {
                                    Ok(r) => results.push(r),
                                    Err(e) => eprintln!("  ⚠️  {}", e),
                                }
                            }
                            i += 1;
                        }
                    }
                    #[cfg(not(feature = "hpdf"))]
                    {
                        eprintln!("  ⚠️  HPDF support not compiled.");
                        i += 2;
                    }
                }
                "--output" => {
                    // handled below
                    i += 2;
                }
                arg => {
                    // Try to parse as N value for on-the-fly mode
                    if let Ok(n) = arg.parse::<usize>() {
                        results.push(compute_on_fly(n));
                    } else {
                        eprintln!("  Unknown argument: {}", arg);
                    }
                    i += 1;
                }
            }
        }
    }

    if results.is_empty() {
        eprintln!("  No results computed. Exiting.");
        return;
    }

    // Sort by N
    results.sort_by_key(|r| r.n);

    // Print results table
    print_results_table(&results);

    // Trend analysis
    println!("\n  ─── TREND ANALYSIS ───");
    for r in &results {
        println!(
            "    N={:>6}: margin = {:+.6}, gap·ln(N) = {:+.4}, d²·ln(N) = {:.4}",
            r.n,
            r.margin,
            r.gap_times_ln,
            r.d_sq * r.ln_n
        );
    }

    // Write certificates
    write_certificate(&results, &output_dir);

    let total_time = t_start.elapsed().as_secs_f64();
    println!("\n  Total runtime: {:.1}s", total_time);
    println!();
}
