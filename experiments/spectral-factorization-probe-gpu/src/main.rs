//! Cathedral Spectral Factorization Probe — GPU Edition
//!
//! GPU-accelerated version running on RTX 4090.
//! Key improvements over CPU version:
//! - Eigendecomposition via cuSOLVER (100-300x speedup)
//! - HPDF Gram matrix cache (instant load from precomputed H5 files)
//! - Shared GramCache eliminates redundant matrix builds across probes
//! - Certified JSON results output with cross-class analysis
//! - SSH key generation & spectral security audit mode
//!
//! HONEST DISCLAIMER: This is a research exploration, not a practical
//! factoring algorithm. The Cathedral proof is about statistical prime
//! distribution (RH ↔ d²_N → 0), not individual factorizations.

mod gpu;
mod keygen;
mod probes;
mod results;
mod ssh_keys;

use std::path::{Path, PathBuf};
use std::time::Instant;

/// Resolve the results directory relative to the binary location.
/// Falls back to CWD-relative if binary path cannot be determined.
fn results_base_dir() -> PathBuf {
    std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."))
        .join("results")
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let ssh_mode = args.iter().any(|a| a == "--ssh-keys" || a == "--ssh");

    if ssh_mode {
        run_ssh_mode();
    } else {
        run_standard_mode();
    }
}

// ═══════════════════════════════════════════════════════════════
// STANDARD MODE — random semiprimes (original pipeline)
// ═══════════════════════════════════════════════════════════════

fn run_standard_mode() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  CATHEDRAL SPECTRAL FACTORIZATION PROBE v0.4 — GPU EDITION");
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
    let hpdf_dir = find_hpdf_dir();
    let cache = probes::GramCache::new(hpdf_dir.as_deref());

    // Initialize results writer — outputs beside the binary
    let results_dir = results_base_dir();
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

// ═══════════════════════════════════════════════════════════════
// SSH KEY MODE — generate + probe SSH key material
// ═══════════════════════════════════════════════════════════════

fn run_ssh_mode() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  CATHEDRAL SSH KEY SPECTRAL SECURITY AUDIT v0.1");
    println!("  Probing RSA + ECDSA keys with Cathedral spectral hypotheses");
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

    // Initialize HPDF-backed Gram cache (for tractable small RSA keys)
    let hpdf_dir = find_hpdf_dir();
    let cache = probes::GramCache::new(hpdf_dir.as_deref());

    // Results directory
    let results_dir = results_base_dir();
    let writer = results::ResultsWriter::new_with_prefix(&results_dir, "ssh_probe");

    // Phase 1: Generate SSH key test suite
    let key_set = ssh_keys::generate_ssh_test_suite(&writer.output_dir);

    // Phase 2: Run probes against key material
    println!("\n═══════════════════════════════════════════════════════════════");
    println!("  RUNNING SPECTRAL PROBES ON SSH KEY MATERIAL");
    println!("═══════════════════════════════════════════════════════════════\n");

    let probe_results = probes::ssh_probe::run_ssh_probes(&key_set, &cache);

    // Phase 3: Summary & output
    probes::ssh_probe::print_ssh_summary(&probe_results);

    // Write JSON results
    writer.write_json_pub("ssh_key_suite.json", &key_set);
    writer.write_json_pub("ssh_probe_results.json", &probe_results);

    // Write individual results per key type
    for result in &probe_results {
        let filename = format!("ssh_probe_{}.json",
            result.key_type.to_lowercase().replace('-', "_"));
        writer.write_json_pub(&filename, result);
    }

    let total_time = t0.elapsed().as_secs_f64();

    // Write summary manifest
    let summary = serde_json::json!({
        "experiment": "cathedral-ssh-key-audit",
        "version": "0.1.0",
        "gpu": gpu_info.name,
        "total_time_s": total_time,
        "rsa_keys_generated": key_set.rsa_keys.len(),
        "ecdsa_keys_generated": key_set.ecdsa_keys.len(),
        "tractable_semiprimes": key_set.tractable_semiprimes.len(),
        "probe_results": probe_results.len(),
        "any_signal_detected": probe_results.iter().any(|r|
            r.large_key_vasyunin.as_ref().map(|v| v.factor_signal_detected).unwrap_or(false)
        ),
    });
    writer.write_json_pub("manifest.json", &summary);

    println!("═══════════════════════════════════════════════════════════════");
    println!("  Total time: {:.2}s", total_time);
    println!("  Results:    {}", writer.output_dir.display());
    println!("═══════════════════════════════════════════════════════════════");
}

// ═══════════════════════════════════════════════════════════════
// SHARED UTILITIES
// ═══════════════════════════════════════════════════════════════

/// Locate the HPDF cache directory.
fn find_hpdf_dir() -> Option<PathBuf> {
    let candidates = [
        PathBuf::from("../cache/hpdf"),
        PathBuf::from("../../cache/hpdf"),
        PathBuf::from(std::env::var("HOME").unwrap_or_default())
            .join("prime/experiments/cache/hpdf"),
    ];
    candidates.into_iter().find(|p| p.exists())
}
