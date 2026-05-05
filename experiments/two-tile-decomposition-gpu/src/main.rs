//! ═══════════════════════════════════════════════════════════════════════════
//!  TWO-TILE DECOMPOSITION GPU CERTIFIER v1
//!
//!  Certifies the Staircase Telescope (Gemini Key 1) and Beta Modulo
//!  Duality (Gemini Key 2) across ALL coprime pairs (a,b) with
//!  2 ≤ a < b ≤ B_max using GPU-accelerated f64 arithmetic.
//!
//!  Usage:
//!    two-tile-decomposition-gpu [OPTIONS]
//!
//!  Options:
//!    --max-b, -B <N>    Max value of b (default: 100, generates all coprime pairs)
//!    --cpu              Force CPU-only mode (rayon parallelism)
//!    --help, -h         Show this help
//!
//!  Output:
//!    §1. Staircase Telescope — max |error| for logΓ and ψ across all pairs
//!    §2. Beta Modulo Duality — pointwise coefficient match + sum error
//!    §3. Graduation Identity — Σ perClassLimit = deltaTarget
//!    §4. JSON/TSV certificate written to results/
//! ═══════════════════════════════════════════════════════════════════════════

mod gpu;
mod cpu;

use std::time::Instant;
use cathedral_utils::fmt;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut max_b: usize = 100;
    let mut force_cpu = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--max-b" | "-B" => {
                i += 1;
                max_b = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(100);
            }
            "--cpu" => force_cpu = true,
            "--help" | "-h" => {
                println!("Two-Tile Decomposition GPU Certifier v1");
                println!();
                println!("Usage: two-tile-decomposition-gpu [OPTIONS]");
                println!();
                println!("Options:");
                println!("  --max-b, -B <N>    Max value of b (default: 100)");
                println!("  --cpu              Force CPU-only mode");
                println!("  --help, -h         Show this help");
                println!();
                println!("Generates all coprime pairs (a,b) with 2 ≤ a < b ≤ B_max.");
                println!();
                println!("Scale Reference:");
                println!("  B=100    →    2,944 pairs  (CPU: ~7min, GPU: ~2s)");
                println!("  B=500    →   76,117 pairs  (CPU: ~days, GPU: ~30s)");
                println!("  B=1000   →  304,191 pairs  (GPU: ~5min)");
                println!("  B=5000   → 7,599,827 pairs (GPU: ~2hr)");
                return;
            }
            _ => {}
        }
        i += 1;
    }

    // Generate all coprime pairs
    let mut pairs: Vec<(usize, usize)> = Vec::new();
    for b in 3..=max_b {
        for a in 2..b {
            if gcd(a, b) == 1 {
                pairs.push((a, b));
            }
        }
    }
    let n_pairs = pairs.len();

    let n_threads = rayon::current_num_threads();
    fmt::header(
        "TWO-TILE DECOMPOSITION GPU CERTIFIER v1",
        "Skeleton Key Validator — Staircase Telescope + Beta Duality",
        64,  // f64 bits
        n_threads,
    );

    println!("  Coprime pairs: {} (B_max = {})", n_pairs, max_b);
    println!("  Precision: f64 (15-16 digits)");
    println!();

    // Detect GPU
    let gpu_available = !force_cpu && gpu::detect_gpu().is_some();
    if let Some(info) = gpu::detect_gpu() {
        println!("  GPU: {} ({} MB VRAM)", info.name, info.vram_mb);
    }
    if force_cpu || !gpu_available {
        println!("  Mode: CPU-only (rayon, {} threads)", n_threads);
    } else {
        println!("  Mode: GPU (CUDA)");
    }
    println!();

    // ═══ CERTIFY ═══
    let t0 = Instant::now();

    let results = if gpu_available && !force_cpu {
        gpu::gpu_certify(&pairs)
    } else {
        cpu::cpu_certify(&pairs)
    };

    let elapsed = t0.elapsed().as_secs_f64();
    println!("  Certification completed in {:.2}s ({:.0} pairs/sec)",
        elapsed, n_pairs as f64 / elapsed);
    println!();

    // ═══ REPORT ═══
    std::fs::create_dir_all("results").ok();

    // §1. Staircase Telescope
    fmt::section("STAIRCASE TELESCOPE (Gemini Key 1)");
    println!("  Σ_{{TT}} f(m₀) = (a/b)·Σf(m) + Σ{{ar/b}}·(f(r)-f(r-1)) - f(b-1)");
    println!();

    let max_tel_lg = results.iter().map(|r| r.telescope_lg_err).fold(0.0_f64, f64::max);
    let max_tel_psi = results.iter().map(|r| r.telescope_psi_err).fold(0.0_f64, f64::max);
    let tel_failures: Vec<_> = results.iter()
        .filter(|r| r.telescope_lg_err > 1e-8 || r.telescope_psi_err > 1e-8)
        .collect();

    println!("  Max |telescope logΓ error| : {:.4e}", max_tel_lg);
    println!("  Max |telescope ψ error|    : {:.4e}", max_tel_psi);
    if tel_failures.is_empty() {
        println!("  {} Staircase telescope: CERTIFIED across ALL {} pairs ★",
            fmt::check(true), n_pairs);
    } else {
        println!("  {} {} failures:", fmt::check(false), tel_failures.len());
        for r in tel_failures.iter().take(10) {
            println!("    ({},{}) lg_err={:.4e} psi_err={:.4e}",
                r.a, r.b, r.telescope_lg_err, r.telescope_psi_err);
        }
    }
    println!();

    // §2. Beta Modulo Duality
    fmt::section("BETA MODULO DUALITY (Gemini Key 2)");
    println!("  (s-a)/(a²b) = -(1/(ab))·{{b(k+1)/a}}");
    println!();

    let all_beta_pw = results.iter().all(|r| r.beta_duality_pw != 0);
    let max_beta_sum = results.iter().map(|r| r.beta_duality_sum_err).fold(0.0_f64, f64::max);
    let beta_failures: Vec<_> = results.iter()
        .filter(|r| r.beta_duality_pw == 0 || r.beta_duality_sum_err > 1e-8)
        .collect();

    println!("  Pointwise coefficient match : {} ({}/{} pairs)",
        if all_beta_pw { fmt::check(true) } else { fmt::check(false) },
        results.iter().filter(|r| r.beta_duality_pw != 0).count(), n_pairs);
    println!("  Max |sum LHS - sum RHS|     : {:.4e}", max_beta_sum);
    if beta_failures.is_empty() {
        println!("  {} Beta modulo duality: CERTIFIED across ALL {} pairs ★",
            fmt::check(true), n_pairs);
    } else {
        println!("  {} {} failures:", fmt::check(false), beta_failures.len());
        for r in beta_failures.iter().take(10) {
            println!("    ({},{}) pw={} sum_err={:.4e}",
                r.a, r.b, r.beta_duality_pw, r.beta_duality_sum_err);
        }
    }
    println!();

    // §3. Graduation Identity
    fmt::section("GRADUATION IDENTITY");
    println!("  ∑ perClassLimit(a,b,m₀) = vasyuninGramFormula - strip - stir/b - ft/a");
    println!();

    let max_id_err = results.iter().map(|r| r.identity_err).fold(0.0_f64, f64::max);
    let id_failures: Vec<_> = results.iter()
        .filter(|r| r.identity_err > 1e-8)
        .collect();

    println!("  Max |Σ perClassLimit - deltaTarget| : {:.4e}", max_id_err);
    if id_failures.is_empty() {
        println!("  {} Graduation identity: CERTIFIED across ALL {} pairs ★",
            fmt::check(true), n_pairs);
    } else {
        println!("  {} {} failures:", fmt::check(false), id_failures.len());
        for r in id_failures.iter().take(10) {
            println!("    ({},{}) err={:.4e}", r.a, r.b, r.identity_err);
        }
    }
    println!();

    // §4. Overall certification
    let all_certified = results.iter().all(|r| r.certified != 0);
    let n_certified = results.iter().filter(|r| r.certified != 0).count();

    if all_certified {
        println!("  ★ {} ALL {} PAIRS CERTIFIED (B_max = {}) — SKELETON KEYS VALIDATED ★",
            fmt::check(true), n_pairs, max_b);
    } else {
        println!("  {} {}/{} pairs certified (B_max = {})",
            fmt::check(false), n_certified, n_pairs, max_b);
    }
    println!("  Total time: {:.2}s", t0.elapsed().as_secs_f64());
    println!();

    // Write JSON certificate
    let cert = serde_json::json!({
        "experiment": "two-tile-decomposition-gpu",
        "version": "1.0",
        "max_b": max_b,
        "n_pairs": n_pairs,
        "n_certified": n_certified,
        "all_certified": all_certified,
        "precision": "f64",
        "mode": if gpu_available && !force_cpu { "GPU" } else { "CPU" },
        "elapsed_secs": t0.elapsed().as_secs_f64(),
        "staircase_telescope": {
            "max_loggamma_err": max_tel_lg,
            "max_digamma_err": max_tel_psi,
            "all_certified": tel_failures.is_empty(),
        },
        "beta_duality": {
            "all_pointwise": all_beta_pw,
            "max_sum_err": max_beta_sum,
            "all_certified": beta_failures.is_empty(),
        },
        "graduation_identity": {
            "max_err": max_id_err,
            "all_certified": id_failures.is_empty(),
        },
    });

    let cert_path = format!("results/skeleton_keys_B{}.json", max_b);
    std::fs::write(&cert_path, serde_json::to_string_pretty(&cert).unwrap()).unwrap();
    println!("  {} {}", fmt::check(true), cert_path);

    // Write TSV
    let tsv_path = format!("results/skeleton_keys_B{}.tsv", max_b);
    let mut tsv = String::new();
    tsv.push_str("a\tb\tn_tt\ttel_lg_err\ttel_psi_err\tbeta_pw\tbeta_sum_err\tsum_pcl\tdelta_target\tid_err\tcertified\n");
    for r in &results {
        tsv.push_str(&format!("{}\t{}\t{}\t{:.6e}\t{:.6e}\t{}\t{:.6e}\t{:.15e}\t{:.15e}\t{:.6e}\t{}\n",
            r.a, r.b, r.n_two_tile,
            r.telescope_lg_err, r.telescope_psi_err,
            r.beta_duality_pw, r.beta_duality_sum_err,
            r.sum_pcl, r.delta_target, r.identity_err,
            r.certified));
    }
    std::fs::write(&tsv_path, tsv).unwrap();
    println!("  {} {}", fmt::check(true), tsv_path);
    println!();
}

fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}
