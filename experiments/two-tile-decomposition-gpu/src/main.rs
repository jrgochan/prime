//! ═══════════════════════════════════════════════════════════════════════════
//!  TWO-TILE DECOMPOSITION GPU CERTIFIER v1
//!
//!  Complete certification of ALL Vasyunin proof chain identities at f64
//!  precision, matching the output of the CPU two-tile-decomposition
//!  experiment's axiom graduation module.
//!
//!  Certifications:
//!    §1. Structural invariants (beta bijection, s permutation, overshoot)
//!    §2. Gauss formula verification (logΓ and ψ sums vs closed forms)
//!    §3. Staircase Telescope (Gemini Key 1)
//!    §4. Beta Modulo Duality (Gemini Key 2)
//!    §5. Graduation Identity (Σ perClassLimit = deltaTarget)
//!
//!  Usage:
//!    two-tile-decomposition-gpu [OPTIONS]
//!
//!  Options:
//!    --max-b, -B <N>    Max value of b (default: 100)
//!    --cpu              Force CPU-only mode (rayon parallelism)
//!    --help, -h         Show this help
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
                println!("  B=100    →    2,944 pairs  (CPU: ~0.01s, GPU: <0.1s)");
                println!("  B=500    →   75,616 pairs  (CPU: ~1s,    GPU: ~0.1s)");
                println!("  B=1000   →  303,192 pairs  (CPU: ~8s,    GPU: ~1s)");
                println!("  B=5000   → 7,599,827 pairs (CPU: ~days,  GPU: ~2min)");
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
        "Full Axiom Graduation — Matching CPU Experiment Output",
        64,  // f64 bits
        n_threads,
    );

    println!("  Coprime pairs: {} (B_max = {})", n_pairs, max_b);
    println!("  Precision: f64 (15-16 significant digits)");
    println!();

    // Detect GPU
    let gpu_available = !force_cpu && gpu::detect_gpu().is_some();
    if let Some(info) = gpu::detect_gpu() {
        println!("  GPU: {} ({} MB VRAM)", info.name, info.vram_mb);
    }
    let mode = if force_cpu || !gpu_available { "CPU" } else { "GPU" };
    println!("  Mode: {} {}", mode,
        if mode == "CPU" { format!("(rayon, {} threads)", n_threads) }
        else { "(CUDA)".into() });
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

    std::fs::create_dir_all("results").ok();

    // ═══════════════════════════════════════════════════
    // §1. STRUCTURAL INVARIANTS
    // ═══════════════════════════════════════════════════
    fmt::section("§1. STRUCTURAL INVARIANTS");
    println!();

    let all_beta_bij = results.iter().all(|r| r.beta_bijection != 0);
    let all_s_perm = results.iter().all(|r| r.s_permutation != 0);
    let all_overshoot = results.iter().all(|r| r.overshoot_identity != 0);

    println!("  Beta Bijection (tileIndex → {{0,...,a-2}}) : {} ({}/{})",
        if all_beta_bij { fmt::check(true) } else { fmt::check(false) },
        results.iter().filter(|r| r.beta_bijection != 0).count(), n_pairs);
    println!("  S Permutation (overshoot → {{1,...,a-1}})  : {} ({}/{})",
        if all_s_perm { fmt::check(true) } else { fmt::check(false) },
        results.iter().filter(|r| r.s_permutation != 0).count(), n_pairs);
    println!("  Overshoot Identity (s-a = am₀%b - b)     : {} ({}/{})",
        if all_overshoot { fmt::check(true) } else { fmt::check(false) },
        results.iter().filter(|r| r.overshoot_identity != 0).count(), n_pairs);

    if !all_beta_bij || !all_s_perm || !all_overshoot {
        let failures: Vec<_> = results.iter()
            .filter(|r| r.beta_bijection == 0 || r.s_permutation == 0 || r.overshoot_identity == 0)
            .take(5).collect();
        for r in &failures {
            println!("    FAIL ({},{}) β={} s={} ov={}",
                r.a, r.b, r.beta_bijection, r.s_permutation, r.overshoot_identity);
        }
    }
    println!();

    // ═══════════════════════════════════════════════════
    // §2. GAUSS FORMULA VERIFICATION
    // ═══════════════════════════════════════════════════
    fmt::section("§2. GAUSS FORMULA VERIFICATION");
    println!();

    let max_glg_a = results.iter().map(|r| r.gauss_loggamma_a_err).fold(0.0_f64, f64::max);
    let max_glg_b = results.iter().map(|r| r.gauss_loggamma_b_err).fold(0.0_f64, f64::max);
    let max_gd_a = results.iter().map(|r| r.gauss_digamma_a_err).fold(0.0_f64, f64::max);
    let max_gd_b = results.iter().map(|r| r.gauss_digamma_b_err).fold(0.0_f64, f64::max);

    println!("  Σ logΓ(k/a) vs closed form:");
    println!("    Max |error| (a-grid) : {:.4e}", max_glg_a);
    println!("    Max |error| (b-grid) : {:.4e}", max_glg_b);
    println!("  Σ ψ(k/q) vs closed form:");
    println!("    Max |error| (a-grid) : {:.4e}", max_gd_a);
    println!("    Max |error| (b-grid) : {:.4e}", max_gd_b);

    let gauss_ok = max_glg_a < 1e-8 && max_glg_b < 1e-8
        && max_gd_a < 1e-8 && max_gd_b < 1e-8;
    if gauss_ok {
        println!("  {} Gauss multiplication + digamma: CERTIFIED ★", fmt::check(true));
    } else {
        println!("  {} Gauss formula: FAILED", fmt::check(false));
    }
    println!();

    // ═══════════════════════════════════════════════════
    // §3. STAIRCASE TELESCOPE (Gemini Key 1)
    // ═══════════════════════════════════════════════════
    fmt::section("§3. STAIRCASE TELESCOPE (Gemini Key 1)");
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

    // ═══════════════════════════════════════════════════
    // §4. BETA MODULO DUALITY (Gemini Key 2)
    // ═══════════════════════════════════════════════════
    fmt::section("§4. BETA MODULO DUALITY (Gemini Key 2)");
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

    // ═══════════════════════════════════════════════════
    // §5. GRADUATION IDENTITY
    // ═══════════════════════════════════════════════════
    fmt::section("§5. GRADUATION IDENTITY");
    println!("  ∑ perClassLimit(a,b,m₀) = vasyuninGramFormula - strip - stir/b - ft/a");
    println!();

    let max_id_err = results.iter().map(|r| r.identity_err).fold(0.0_f64, f64::max);
    let id_failures: Vec<_> = results.iter()
        .filter(|r| r.identity_err > 1e-8)
        .collect();

    // Show detail for small sets, summary for large
    if n_pairs <= 200 {
        println!("  {:>5} {:>5}  {:>22}  {:>22}  {:>14}",
            "(a", "b)", "∑ perClassLimit", "deltaTarget", "|error|");
        println!("  {}", "─".repeat(80));
        for r in &results {
            println!("  ({:>2},{:>2})  {:>22.15}  {:>22.15}  {:>14.4e}  {}",
                r.a, r.b, r.sum_pcl, r.delta_target, r.identity_err,
                if r.certified != 0 { fmt::check(true) } else { fmt::check(false) });
        }
        println!();
    }

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

    // ═══════════════════════════════════════════════════
    // OVERALL CERTIFICATION
    // ═══════════════════════════════════════════════════
    let all_certified = results.iter().all(|r| r.certified != 0);
    let n_certified = results.iter().filter(|r| r.certified != 0).count();

    println!("  ═══════════════════════════════════════════════════════════════");
    if all_certified {
        println!("  ★ {} ALL {} PAIRS CERTIFIED (B_max = {}) ★", fmt::check(true), n_pairs, max_b);
        println!("    Structural invariants : ✓ Beta bijection, S permutation, Overshoot identity");
        println!("    Gauss formulas        : ✓ logΓ and ψ closed forms verified");
        println!("    Staircase telescope   : ✓ Gemini Key 1 — Abel sum identity");
        println!("    Beta modulo duality   : ✓ Gemini Key 2 — overshoot reduction");
        println!("    Graduation identity   : ✓ Σ perClassLimit = deltaTarget");
        println!("    SKELETON KEYS VALIDATED — gramIntegral_eq_formula_ge2 GRADUATION READY");
    } else {
        println!("  {} {}/{} pairs certified (B_max = {})",
            fmt::check(false), n_certified, n_pairs, max_b);
    }
    println!("  Total time: {:.2}s ({} mode)", t0.elapsed().as_secs_f64(), mode);
    println!("  ═══════════════════════════════════════════════════════════════");
    println!();

    // ═══ WRITE CERTIFICATES ═══

    // JSON certificate
    let cert = serde_json::json!({
        "experiment": "two-tile-decomposition-gpu",
        "version": "1.0",
        "max_b": max_b,
        "n_pairs": n_pairs,
        "n_certified": n_certified,
        "all_certified": all_certified,
        "precision": "f64",
        "mode": mode,
        "elapsed_secs": t0.elapsed().as_secs_f64(),
        "structural": {
            "beta_bijection": all_beta_bij,
            "s_permutation": all_s_perm,
            "overshoot_identity": all_overshoot,
        },
        "gauss_formulas": {
            "max_loggamma_a_err": max_glg_a,
            "max_loggamma_b_err": max_glg_b,
            "max_digamma_a_err": max_gd_a,
            "max_digamma_b_err": max_gd_b,
            "all_certified": gauss_ok,
        },
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

    // TSV — matches CPU experiment's axiom_graduation.tsv column layout
    let tsv_path = format!("results/skeleton_keys_B{}.tsv", max_b);
    let mut tsv = String::new();
    tsv.push_str("a\tb\tn_two_tile\tbeta_bij\ts_perm\tovershoot_id\t");
    tsv.push_str("gauss_lgA_err\tgauss_lgB_err\tgauss_dA_err\tgauss_dB_err\t");
    tsv.push_str("telescope_lg_err\ttelescope_psi_err\t");
    tsv.push_str("beta_duality_pw\tbeta_duality_sum_err\t");
    tsv.push_str("sum_pcl\tdelta_target\tidentity_err\tcertified\n");
    for r in &results {
        tsv.push_str(&format!("{}\t{}\t{}\t{}\t{}\t{}\t",
            r.a, r.b, r.n_two_tile,
            r.beta_bijection != 0, r.s_permutation != 0, r.overshoot_identity != 0));
        tsv.push_str(&format!("{:.6e}\t{:.6e}\t{:.6e}\t{:.6e}\t",
            r.gauss_loggamma_a_err, r.gauss_loggamma_b_err,
            r.gauss_digamma_a_err, r.gauss_digamma_b_err));
        tsv.push_str(&format!("{:.6e}\t{:.6e}\t",
            r.telescope_lg_err, r.telescope_psi_err));
        tsv.push_str(&format!("{}\t{:.6e}\t",
            r.beta_duality_pw != 0, r.beta_duality_sum_err));
        tsv.push_str(&format!("{:.15e}\t{:.15e}\t{:.6e}\t{}\n",
            r.sum_pcl, r.delta_target, r.identity_err, r.certified != 0));
    }
    std::fs::write(&tsv_path, tsv).unwrap();
    println!("  {} {}", fmt::check(true), tsv_path);
    println!();
}

fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}
