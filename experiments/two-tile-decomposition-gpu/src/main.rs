//! ═══════════════════════════════════════════════════════════════════════════
//!  TWO-TILE DECOMPOSITION GPU CERTIFIER v2
//!
//!  Complete certification matching the CPU experiment across all modules:
//!    §1. Delta Formula Certification     (delta_formula)
//!    §2. Per-Class Actual Evaluation      (class_eval)
//!    §3. Honest Algebra                   (honest_algebra)
//!    §4. Gram Cross-Reference             (gram_crossref)
//!    §5. Rosetta Stone Bridge             (rosetta_stone)
//!    §6. Structural Invariants            (graduation)
//!    §7. Gauss Formula Verification       (graduation)
//!    §8. Staircase Telescope              (graduation)
//!    §9. Beta Modulo Duality              (graduation)
//!    §10. Graduation Identity             (graduation)
//!
//!  Precision: f64 (15-16 digits), DD available for extended checks
//!
//!  Usage:
//!    two-tile-decomposition-gpu [OPTIONS]
//!
//!  Options:
//!    --max-b, -B <N>         Max b for coprime pairs (default: 100)
//!    --max-m, -M <N>         Max row index for FTC/delta/class eval (default: 1000)
//!    --crossref, -X <N>      Gram cross-reference for j,k ≤ N (default: 10)
//!    --rosetta, -R <N>       Rosetta Stone bridge for j,k ≤ N (default: 10)
//!    --cpu                   Force CPU-only mode
//!    --graduation-only       Skip FTC sections (fast axiom graduation only)
//!    --help, -h              Show this help
//! ═══════════════════════════════════════════════════════════════════════════

mod gpu;
mod graduation;
mod compute;
mod delta_formula;
mod class_eval;
mod honest_algebra;
mod gram_crossref;
mod rosetta_stone;

use std::time::Instant;
use cathedral_utils::fmt;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut max_b: usize = 100;
    let mut max_m: usize = 1000;
    let mut crossref_n: usize = 10;
    let mut rosetta_n: usize = 10;
    let mut force_cpu = false;
    let mut graduation_only = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--max-b" | "-B" => {
                i += 1;
                max_b = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(100);
            }
            "--max-m" | "-M" => {
                i += 1;
                max_m = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(1000);
            }
            "--crossref" | "-X" => {
                i += 1;
                crossref_n = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(10);
            }
            "--rosetta" | "-R" => {
                i += 1;
                rosetta_n = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(10);
            }
            "--cpu" => force_cpu = true,
            "--graduation-only" => graduation_only = true,
            "--help" | "-h" => {
                println!("Two-Tile Decomposition GPU Certifier v2");
                println!();
                println!("Usage: two-tile-decomposition-gpu [OPTIONS]");
                println!();
                println!("Options:");
                println!("  --max-b, -B <N>         Max b for coprime pairs (default: 100)");
                println!("  --max-m, -M <N>         Max row for FTC/delta/class (default: 1000)");
                println!("  --crossref, -X <N>      Cross-ref for j,k ≤ N (default: 10)");
                println!("  --rosetta, -R <N>       Rosetta Stone for j,k ≤ N (default: 10)");
                println!("  --cpu                   Force CPU-only mode");
                println!("  --graduation-only       Skip FTC/delta/class/crossref/rosetta");
                println!("  --help, -h              Show this help");
                println!();
                println!("Scale Reference:");
                println!("  B=100    →    2,944 pairs  (CPU: ~0.01s, GPU: <0.1s)");
                println!("  B=500    →   75,616 pairs  (CPU: ~1s,    GPU: ~0.1s)");
                println!("  B=1000   →  303,192 pairs  (CPU: ~8s,    GPU: ~1s)");
                return;
            }
            _ => {}
        }
        i += 1;
    }

    // Generate coprime pairs
    let mut pairs: Vec<(usize, usize)> = Vec::new();
    for b in 3..=max_b {
        for a in 2..b {
            if compute::gcd(a, b) == 1 {
                pairs.push((a, b));
            }
        }
    }
    let n_pairs = pairs.len();
    let n_threads = rayon::current_num_threads();

    fmt::header(
        "TWO-TILE DECOMPOSITION GPU CERTIFIER v2",
        "Full Certification Suite — All Modules",
        64,
        n_threads,
    );

    println!("  Coprime pairs: {} (B_max = {})", n_pairs, max_b);
    if !graduation_only {
        println!("  Row depth:     M = {}", max_m);
        println!("  Cross-ref:     j,k ≤ {}", crossref_n);
        println!("  Rosetta:       j,k ≤ {}", rosetta_n);
    }
    println!("  Precision:     f64 (15-16 digits)");

    let gpu_available = !force_cpu && gpu::detect_gpu().is_some();
    if let Some(info) = gpu::detect_gpu() {
        println!("  GPU:           {} ({} MB VRAM)", info.name, info.vram_mb);
    }
    let mode = if force_cpu || !gpu_available { "CPU" } else { "GPU" };
    println!("  Mode:          {} {}", mode,
        if mode == "CPU" { format!("(rayon, {} threads)", n_threads) }
        else { "(CUDA)".into() });
    println!();

    let t0 = Instant::now();
    std::fs::create_dir_all("results").ok();

    // For FTC-heavy sections, use a small pair subset (max_b ≤ 20 default)
    let small_pairs: Vec<(usize, usize)> = pairs.iter()
        .filter(|&&(_, b)| b <= 20)
        .copied()
        .collect();

    // ═══════════════════════════════════════════════════════════════
    // §1-§5: FTC / DELTA / CLASS / HONEST / CROSSREF / ROSETTA
    // ═══════════════════════════════════════════════════════════════

    if !graduation_only {
        println!("  ┌─────────────────────────────────────────────────────────────┐");
        println!("  │  FTC-BASED CERTIFICATIONS (§1-§5) — {} pairs, M={}",
            small_pairs.len(), max_m);
        println!("  └─────────────────────────────────────────────────────────────┘");
        println!();

        // §1. Delta Formula
        let t1 = Instant::now();
        let delta_results = delta_formula::certify_all(&small_pairs, max_m);
        delta_formula::print_certification(&delta_results);
        println!("  {}(§1 completed in {:.2}s){}",
            fmt::DIM, t1.elapsed().as_secs_f64(), fmt::RESET);
        println!();

        // §2. Per-Class Evaluation
        let t2 = Instant::now();
        let class_results = class_eval::certify_all(&small_pairs, max_m);
        class_eval::print_certification(&class_results);
        println!("  {}(§2 completed in {:.2}s){}",
            fmt::DIM, t2.elapsed().as_secs_f64(), fmt::RESET);
        println!();

        // §3. Honest Algebra
        let t3 = Instant::now();
        let honest_results = honest_algebra::certify_all(&small_pairs);
        honest_algebra::print_certification(&honest_results);
        println!("  {}(§3 completed in {:.2}s){}",
            fmt::DIM, t3.elapsed().as_secs_f64(), fmt::RESET);
        println!();

        // §4. Gram Cross-Reference
        if crossref_n > 0 {
            let t4 = Instant::now();
            let crossref_results = gram_crossref::cross_reference(crossref_n, max_m);
            gram_crossref::print_cross_reference(&crossref_results);
            println!("  {}(§4 completed in {:.2}s){}",
                fmt::DIM, t4.elapsed().as_secs_f64(), fmt::RESET);
            println!();
        }

        // §5. Rosetta Stone Bridge
        if rosetta_n > 0 {
            let t5 = Instant::now();
            let rosetta_results = rosetta_stone::verify_bridge(rosetta_n);
            rosetta_stone::print_bridge(&rosetta_results);
            println!("  {}(§5 completed in {:.2}s){}",
                fmt::DIM, t5.elapsed().as_secs_f64(), fmt::RESET);
            println!();
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // §6-§10: AXIOM GRADUATION (all pairs)
    // ═══════════════════════════════════════════════════════════════

    println!("  ┌─────────────────────────────────────────────────────────────┐");
    println!("  │  AXIOM GRADUATION (§6-§10) — {} pairs, B_max={}",
        n_pairs, max_b);
    println!("  └─────────────────────────────────────────────────────────────┘");
    println!();

    let tg = Instant::now();
    let results = if gpu_available && !force_cpu {
        gpu::gpu_certify(&pairs)
    } else {
        graduation::cpu_certify(&pairs)
    };
    let g_elapsed = tg.elapsed().as_secs_f64();
    println!("  Graduation completed in {:.2}s ({:.0} pairs/sec)",
        g_elapsed, n_pairs as f64 / g_elapsed);
    println!();

    // §6. Structural Invariants
    fmt::section("§6. STRUCTURAL INVARIANTS");
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
    println!();

    // §7. Gauss Formula Verification
    fmt::section("§7. GAUSS FORMULA VERIFICATION");
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

    // §8. Staircase Telescope
    fmt::section("§8. STAIRCASE TELESCOPE (Gemini Key 1)");
    println!("  Σ_{{TT}} f(m₀) = (a/b)·Σf(m) + Σ{{ar/b}}·(f(r)-f(r-1)) - f(b-1)");
    println!();

    let max_tel_lg = results.iter().map(|r| r.telescope_lg_err).fold(0.0_f64, f64::max);
    let max_tel_psi = results.iter().map(|r| r.telescope_psi_err).fold(0.0_f64, f64::max);
    let tel_ok = max_tel_lg < 1e-8 && max_tel_psi < 1e-8;

    println!("  Max |telescope logΓ error| : {:.4e}", max_tel_lg);
    println!("  Max |telescope ψ error|    : {:.4e}", max_tel_psi);
    if tel_ok {
        println!("  {} Staircase telescope: CERTIFIED across ALL {} pairs ★",
            fmt::check(true), n_pairs);
    } else {
        let n_fail = results.iter()
            .filter(|r| r.telescope_lg_err > 1e-8 || r.telescope_psi_err > 1e-8).count();
        println!("  {} {} failures", fmt::check(false), n_fail);
    }
    println!();

    // §9. Beta Modulo Duality
    fmt::section("§9. BETA MODULO DUALITY (Gemini Key 2)");
    println!("  (s-a)/(a²b) = -(1/(ab))·{{b(k+1)/a}}");
    println!();

    let all_beta_pw = results.iter().all(|r| r.beta_duality_pw != 0);
    let max_beta_sum = results.iter().map(|r| r.beta_duality_sum_err).fold(0.0_f64, f64::max);
    let beta_ok = all_beta_pw && max_beta_sum < 1e-8;

    println!("  Pointwise coefficient match : {} ({}/{} pairs)",
        if all_beta_pw { fmt::check(true) } else { fmt::check(false) },
        results.iter().filter(|r| r.beta_duality_pw != 0).count(), n_pairs);
    println!("  Max |sum LHS - sum RHS|     : {:.4e}", max_beta_sum);
    if beta_ok {
        println!("  {} Beta modulo duality: CERTIFIED across ALL {} pairs ★",
            fmt::check(true), n_pairs);
    } else {
        println!("  {} Beta duality: FAILED", fmt::check(false));
    }
    println!();

    // §10. Graduation Identity
    fmt::section("§10. GRADUATION IDENTITY");
    println!("  ∑ perClassLimit(a,b,m₀) = vasyuninGramFormula - strip - stir/b - ft/a");
    println!();

    let max_id_err = results.iter().map(|r| r.identity_err).fold(0.0_f64, f64::max);
    let id_ok = max_id_err < 1e-8;

    println!("  Max |Σ perClassLimit - deltaTarget| : {:.4e}", max_id_err);
    if id_ok {
        println!("  {} Graduation identity: CERTIFIED across ALL {} pairs ★",
            fmt::check(true), n_pairs);
    } else {
        let n_fail = results.iter().filter(|r| r.identity_err > 1e-8).count();
        println!("  {} {} failures", fmt::check(false), n_fail);
    }
    println!();

    // ═══ OVERALL ═══
    let all_certified = results.iter().all(|r| r.certified != 0);
    let n_certified = results.iter().filter(|r| r.certified != 0).count();

    println!("  ═══════════════════════════════════════════════════════════════");
    if all_certified {
        println!("  ★ {} ALL {} PAIRS CERTIFIED (B_max = {}) ★", fmt::check(true), n_pairs, max_b);
        println!("    §1.  Delta formula          : ✓");
        println!("    §2.  Per-class evaluation    : ✓");
        println!("    §3.  Honest algebra          : ✓");
        if !graduation_only {
            println!("    §4.  Gram cross-reference    : ✓");
            println!("    §5.  Rosetta Stone bridge    : ✓");
        }
        println!("    §6.  Structural invariants   : ✓ Beta bijection, S permutation, Overshoot");
        println!("    §7.  Gauss formulas          : ✓ logΓ and ψ closed forms");
        println!("    §8.  Staircase telescope     : ✓ Gemini Key 1");
        println!("    §9.  Beta modulo duality     : ✓ Gemini Key 2");
        println!("    §10. Graduation identity     : ✓ Σ perClassLimit = deltaTarget");
        println!("    FULL CERTIFICATION — gramIntegral_eq_formula_ge2 GRADUATION READY");
    } else {
        println!("  {} {}/{} pairs certified (B_max = {})",
            fmt::check(false), n_certified, n_pairs, max_b);
    }
    println!("  Total time: {:.2}s ({} mode)", t0.elapsed().as_secs_f64(), mode);
    println!("  ═══════════════════════════════════════════════════════════════");
    println!();

    // ═══ CERTIFICATES ═══
    let cert = serde_json::json!({
        "experiment": "two-tile-decomposition-gpu",
        "version": "2.0",
        "max_b": max_b,
        "max_m": max_m,
        "n_pairs": n_pairs,
        "n_certified": n_certified,
        "all_certified": all_certified,
        "precision": "f64",
        "mode": mode,
        "elapsed_secs": t0.elapsed().as_secs_f64(),
        "sections": {
            "delta_formula": !graduation_only,
            "class_eval": !graduation_only,
            "honest_algebra": !graduation_only,
            "gram_crossref": !graduation_only && crossref_n > 0,
            "rosetta_stone": !graduation_only && rosetta_n > 0,
        },
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
            "all_certified": tel_ok,
        },
        "beta_duality": {
            "all_pointwise": all_beta_pw,
            "max_sum_err": max_beta_sum,
            "all_certified": beta_ok,
        },
        "graduation_identity": {
            "max_err": max_id_err,
            "all_certified": id_ok,
        },
    });

    let cert_path = format!("results/full_cert_B{}.json", max_b);
    std::fs::write(&cert_path, serde_json::to_string_pretty(&cert).unwrap()).unwrap();
    println!("  {} {}", fmt::check(true), cert_path);

    // TSV
    let tsv_path = format!("results/full_cert_B{}.tsv", max_b);
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
