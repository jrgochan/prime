//! Cathedral Spectral Factorization Probe — GPU Edition
//!
//! GPU-accelerated version running on RTX 4090.
//! Key improvements over CPU version:
//! - Eigendecomposition via cuSOLVER (100-300x speedup)
//! - HPDF Gram matrix cache (instant load from precomputed H5 files)
//! - Shared GramCache eliminates redundant matrix builds across probes
//! - Certified JSON results output with cross-class analysis
//!
//! HONEST DISCLAIMER: This is a research exploration, not a practical
//! factoring algorithm. The Cathedral proof is about statistical prime
//! distribution (RH ↔ d²_N → 0), not individual factorizations.

mod gpu;
mod keygen;
mod probes;
mod results;

use std::path::{Path, PathBuf};
use std::time::Instant;

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  CATHEDRAL SPECTRAL FACTORIZATION PROBE v0.3 — GPU EDITION");
    println!("  Testing 6 hypotheses with GPU + HPDF-cached spectral engine");
    println!("═══════════════════════════════════════════════════════════════\n");

    // Detect GPU
    let gpu_info = match gpu::detect_gpu() {
        Some(info) => {
            println!("  \x1b[32m✓ GPU detected: {} ({} MB VRAM)\x1b[0m\n", info.name, info.vram_mb);
            info
        }
        None => {
            eprintln!("  ✗ No CUDA GPU detected. This binary requires a GPU.");
            std::process::exit(1);
        }
    };

    let t0 = Instant::now();

    // Initialize HPDF-backed Gram cache
    // Try workspace-relative path first, then absolute fallback
    let hpdf_candidates = [
        PathBuf::from("../cache/hpdf"),
        PathBuf::from("../../cache/hpdf"),
        PathBuf::from(std::env::var("HOME").unwrap_or_default())
            .join("prime/experiments/cache/hpdf"),
    ];
    let hpdf_dir: Option<&Path> = hpdf_candidates.iter()
        .map(|p| p.as_path())
        .find(|p| p.exists());
    let cache = probes::GramCache::new(hpdf_dir);

    // Initialize results writer — outputs to results/ beside the binary
    let results_dir = PathBuf::from("results");
    let writer = results::ResultsWriter::new(&results_dir);

    // Phase 1: Generate test semiprimes
    let test_keys = keygen::generate_test_suite();
    let total_semiprimes: usize = test_keys.iter().map(|c| c.keys.len()).sum();
    let bit_classes: Vec<u32> = test_keys.iter().map(|c| c.bits).collect();

    println!("Generated {} test semiprimes across {} bit-width classes\n",
        total_semiprimes, test_keys.len());

    // Write manifest
    writer.write_manifest(&gpu_info.name, gpu_info.vram_mb, &bit_classes, total_semiprimes);

    // Phase 2: Run all probes per bit-width class, collecting results
    let mut all_class_results = Vec::new();

    for class in &test_keys {
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        println!("  BIT WIDTH: {} bits ({} semiprimes)", class.bits, class.keys.len());
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

        let t_class = Instant::now();

        // H1: GCD-stratum eigenvector correlation (GPU + HPDF cache)
        let h1 = probes::h1_gcd_stratum_eigenvector(&class.keys, &cache);

        // H2: Optimal weight vector (rayon parallel, no Gram needed)
        let h2 = probes::h2_optimal_weight_structure(&class.keys);

        // H3: Vasyunin cotangent sum anomaly (rayon parallel, no Gram needed)
        let h3 = probes::h3_vasyunin_cotangent_anomaly(&class.keys);

        // H4: Möbius/Liouville local structure (no Gram needed)
        let h4 = probes::h4_mobius_local_structure(&class.keys);

        // H5: Composite anchoring (GPU + HPDF cache, shares Gram with H6)
        let h5 = probes::h5_composite_anchoring(&class.keys, &cache);

        // H6: Quadratic form probe (HPDF cache, shares Gram with H5)
        let h6 = probes::h6_quadratic_form_probe(&class.keys, &cache);

        let class_time = t_class.elapsed().as_secs_f64();
        println!("  ▸ Class time: {:.2}s\n", class_time);

        // Bundle class results
        let class_result = results::ClassResult {
            bit_width: class.bits,
            num_semiprimes: class.keys.len(),
            class_time_s: class_time,
            h1_results: h1,
            h2_results: h2,
            h3_results: h3,
            h4_results: h4,
            h5_results: h5,
            h6_results: h6,
        };

        // Write per-class JSON immediately (crash-safe incremental output)
        writer.write_class_result(&class_result);
        all_class_results.push(class_result);
    }

    // Phase 3: Cross-class analysis
    let total_time = t0.elapsed().as_secs_f64();
    let analysis = results::compute_analysis(&all_class_results, &gpu_info.name, total_time);

    // Print analysis summary to console
    println!("═══════════════════════════════════════════════════════════════");
    println!("  ANALYSIS SUMMARY");
    println!("═══════════════════════════════════════════════════════════════\n");
    for v in &analysis.verdicts {
        let icon = match v.signal_strength.as_str() {
            "STRONG" => "⚡",
            "weak" => "〜",
            _ => "∅",
        };
        println!("  [{}] {} — {} {}", v.hypothesis, v.description, v.signal_strength, icon);
        println!("       {}\n", v.verdict);
    }
    println!("  ╔═══════════════════════════════════════════════════════════╗");
    println!("  ║ CONCLUSION                                              ║");
    println!("  ╚═══════════════════════════════════════════════════════════╝");
    println!("  {}\n", analysis.conclusion);

    // Write analysis JSON
    writer.write_analysis(&analysis);

    println!("═══════════════════════════════════════════════════════════════");
    println!("  Total time: {:.2}s (GPU + HPDF-accelerated)", total_time);
    println!("  Results:    {}", writer.output_dir.display());
    println!("═══════════════════════════════════════════════════════════════");
}
