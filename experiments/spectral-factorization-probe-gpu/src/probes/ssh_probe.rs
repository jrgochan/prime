//! SSH Key Spectral Probe
//!
//! Applies all Cathedral spectral hypotheses (H1–H6) to SSH key material.
//!
//! For RSA keys where N fits in u64:
//!   - Full probe suite (H1–H6), identical to random semiprimes.
//!   - This tests whether SSH-generated semiprimes are "harder" or "easier"
//!     to detect spectrally than random ones.
//!
//! For large RSA keys (2048+):
//!   - H3 (Vasyunin) via modular residues — can the cotangent sum
//!     distinguish factors from non-factors even for cryptographic N?
//!   - H4 (Möbius local structure) on mod-reduced values.
//!
//! For ECDSA keys:
//!   - Scalar properties analysis (Hamming weight, entropy).
//!   - Comparison against uniform random distribution.

use crate::probes::GramCache;
use crate::results::*;
use crate::ssh_keys::*;
use serde::Serialize;

// ═══════════════════════════════════════════════════════════════
// SSH PROBE RESULTS
// ═══════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize)]
pub struct SshProbeResult {
    pub key_type: String,  // "RSA-64", "RSA-2048", "ECDSA-P256", etc.
    pub key_bits: u32,
    /// Full probe results for tractable RSA keys
    pub class_result: Option<ClassResult>,
    /// Large-key Vasyunin analysis
    pub large_key_vasyunin: Option<LargeKeyVasyuninResult>,
    /// ECDSA scalar analysis
    pub ecdsa_analysis: Option<EcdsaAnalysisResult>,
}

#[derive(Debug, Clone, Serialize)]
pub struct LargeKeyVasyuninResult {
    pub modulus_bits: u32,
    pub modulus_hex_prefix: String,
    pub prime1_hex_prefix: String,
    pub prime2_hex_prefix: String,
    /// V(m, N mod m) for small m values — does factor structure leak?
    pub vasyunin_scans: Vec<LargeVasyuninEntry>,
    /// Summary: do known factors show anomalous V-values?
    pub factor_signal_detected: bool,
    pub signal_description: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct LargeVasyuninEntry {
    pub m: u64,
    pub n_mod_m: u64,
    pub v_abs: f64,
    pub is_factor: bool,  // true if m divides N (which it won't for large primes)
    pub is_small_factor_of_p: bool,  // true if m divides p or q
}

#[derive(Debug, Clone, Serialize)]
pub struct EcdsaAnalysisResult {
    pub curve: String,
    pub bits: u32,
    pub scalar_props: ScalarProperties,
    /// How does the private key's Hamming ratio compare to expected 0.5?
    pub hamming_deviation: f64,
    /// Vasyunin scan on the private key scalar (mod-reduced)
    pub scalar_vasyunin: Vec<ScalarVasyuninEntry>,
    pub anomaly_detected: bool,
    pub description: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ScalarVasyuninEntry {
    pub m: u64,
    pub d_mod_m: u64,
    pub v_abs: f64,
}

// ═══════════════════════════════════════════════════════════════
// SSH PROBE ENGINE
// ═══════════════════════════════════════════════════════════════

/// Run all applicable probes against the SSH key suite.
pub fn run_ssh_probes(
    key_set: &SshKeySet,
    cache: &GramCache,
) -> Vec<SshProbeResult> {
    let mut results = Vec::new();

    // ── Phase 1: Tractable RSA keys (full H1–H6 probes) ──
    if !key_set.tractable_semiprimes.is_empty() {
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        println!("  SSH RSA KEYS — FULL SPECTRAL ANALYSIS (tractable)");
        println!("  {} keys with N fitting in u64", key_set.tractable_semiprimes.len());
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

        let t0 = std::time::Instant::now();
        let keys = &key_set.tractable_semiprimes;

        // Run all 6 probes — identical pipeline to random semiprimes
        let h1 = crate::probes::h1_gcd_stratum_eigenvector(keys, cache);
        let h2 = crate::probes::h2_optimal_weight_structure(keys);
        let h3 = crate::probes::h3_vasyunin_cotangent_anomaly(keys);
        let h4 = crate::probes::h4_mobius_local_structure(keys);
        let h5 = crate::probes::h5_composite_anchoring(keys, cache);
        let h6 = crate::probes::h6_quadratic_form_probe(keys, cache);

        let class_result = ClassResult {
            bit_width: 0, // mixed
            num_semiprimes: keys.len(),
            class_time_s: t0.elapsed().as_secs_f64(),
            h1_results: h1,
            h2_results: h2,
            h3_results: h3,
            h4_results: h4,
            h5_results: h5,
            h6_results: h6,
        };

        // Group by bit width for reporting
        for key in keys {
            let bits = key.bits;
            // Check if we already have a result for this bit width
            if !results.iter().any(|r: &SshProbeResult| r.key_type == format!("RSA-{}", bits)) {
                results.push(SshProbeResult {
                    key_type: format!("RSA-{}", bits),
                    key_bits: bits,
                    class_result: Some(class_result.clone()),
                    large_key_vasyunin: None,
                    ecdsa_analysis: None,
                });
                break; // Only need one class result for the whole tractable set
            }
        }

        // If no result was pushed (shouldn't happen), push with generic label
        if results.is_empty() {
            results.push(SshProbeResult {
                key_type: "RSA-small".to_string(),
                key_bits: 0,
                class_result: Some(class_result),
                large_key_vasyunin: None,
                ecdsa_analysis: None,
            });
        }
    }

    // ── Phase 2: Large RSA keys (mod-reduced Vasyunin) ──
    for rsa_key in &key_set.rsa_keys {
        if rsa_key.semiprime.is_some() { continue; } // Already handled above
        if rsa_key.modulus_bytes.is_empty() { continue; }

        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        println!("  SSH RSA-{} — LARGE KEY ANALYSIS", rsa_key.bits);
        println!("  (Mod-reduced Vasyunin scan — does factor structure leak?)\n");

        let result = probe_large_rsa(rsa_key);
        results.push(SshProbeResult {
            key_type: format!("RSA-{}", rsa_key.bits),
            key_bits: rsa_key.bits,
            class_result: None,
            large_key_vasyunin: Some(result),
            ecdsa_analysis: None,
        });
    }

    // ── Phase 3: ECDSA keys (scalar analysis) ──
    for ec_key in &key_set.ecdsa_keys {
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        println!("  SSH ECDSA {} — SCALAR ANALYSIS", ec_key.curve);
        println!("  (Private key entropy + Vasyunin scan on d mod m)\n");

        let result = probe_ecdsa(ec_key);
        results.push(SshProbeResult {
            key_type: format!("ECDSA-{}", ec_key.curve),
            key_bits: ec_key.bits,
            class_result: None,
            large_key_vasyunin: None,
            ecdsa_analysis: Some(result),
        });
    }

    results
}

// ═══════════════════════════════════════════════════════════════
// LARGE RSA KEY PROBE
// ═══════════════════════════════════════════════════════════════

/// Probe a large RSA key using mod-reduced Vasyunin analysis.
///
/// Key insight: V(m, N) only depends on N mod m, so we can compute
/// the Vasyunin sum for any m even when N is 2048+ bits.
/// If the factors p, q leave a detectable residue pattern, this
/// would be a breakthrough (and extremely unlikely).
fn probe_large_rsa(rsa_key: &RsaKeyInfo) -> LargeKeyVasyuninResult {
    let scan_limit = 10_000u64;
    let moduli: Vec<u64> = (2..=scan_limit).collect();

    // Compute N mod m for all m
    let residues = modular_residues(&rsa_key.modulus_bytes, &moduli);

    // Also compute p mod m and q mod m to check if any m divides p or q
    let p_bytes = hex_to_bytes_pub(&rsa_key.prime1_hex);
    let q_bytes = hex_to_bytes_pub(&rsa_key.prime2_hex);

    let mut vasyunin_entries = Vec::new();
    let mut factor_v_values = Vec::new();
    let mut non_factor_v_values = Vec::new();

    for &(m, n_mod_m) in &residues {
        let v = crate::probes::vasyunin_sum(m, n_mod_m);
        let v_abs = v.abs();

        // Check if m divides p or q via modular reduction
        let p_mod_m = mod_reduce_bytes(&p_bytes, m);
        let q_mod_m = mod_reduce_bytes(&q_bytes, m);
        let is_small_factor = p_mod_m == 0 || q_mod_m == 0;
        let is_divisor = n_mod_m == 0;

        if is_divisor || is_small_factor {
            factor_v_values.push(v_abs);
        } else {
            non_factor_v_values.push(v_abs);
        }

        vasyunin_entries.push(LargeVasyuninEntry {
            m,
            n_mod_m,
            v_abs,
            is_factor: is_divisor,
            is_small_factor_of_p: is_small_factor,
        });
    }

    // Sort by V-value to find top anomalies
    vasyunin_entries.sort_by(|a, b| a.v_abs.partial_cmp(&b.v_abs).unwrap());

    // Report top-10 smallest V-values (potential factor signals)
    println!("    Top-10 smallest |V(m, N mod m)| (potential factor signals):");
    for (i, entry) in vasyunin_entries.iter().take(10).enumerate() {
        let flag = if entry.is_factor { " ← DIVISOR" }
            else if entry.is_small_factor_of_p { " ← DIVIDES p or q" }
            else { "" };
        println!("      #{}: m={:6} |V|={:.6e} (N mod m = {}){}", i+1, entry.m, entry.v_abs, entry.n_mod_m, flag);
    }

    // Check if factor-related m values cluster near zero
    let median_nf = if !non_factor_v_values.is_empty() {
        non_factor_v_values.sort_by(|a, b| a.partial_cmp(b).unwrap());
        non_factor_v_values[non_factor_v_values.len() / 2]
    } else { 0.0 };

    let factor_detected = if !factor_v_values.is_empty() {
        let max_factor_v = factor_v_values.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        max_factor_v < median_nf * 0.1  // factors must be well below median
    } else {
        false
    };

    let signal_desc = if factor_detected {
        format!("SIGNAL: Factor-related m values show V-values {:.1}x below median",
            median_nf / factor_v_values.iter().sum::<f64>() * factor_v_values.len() as f64)
    } else {
        format!("NULL: {} factor-related m values found, no anomalous clustering. \
                 Median non-factor |V|={:.4e}", factor_v_values.len(), median_nf)
    };

    println!("    {}\n", signal_desc);

    let mod_prefix = |hex: &str| -> String {
        if hex.len() > 32 { format!("{}...", &hex[..32]) } else { hex.to_string() }
    };

    // Only keep top-20 for JSON output
    vasyunin_entries.truncate(20);

    LargeKeyVasyuninResult {
        modulus_bits: rsa_key.bits,
        modulus_hex_prefix: mod_prefix(&rsa_key.modulus_hex),
        prime1_hex_prefix: mod_prefix(&rsa_key.prime1_hex),
        prime2_hex_prefix: mod_prefix(&rsa_key.prime2_hex),
        vasyunin_scans: vasyunin_entries,
        factor_signal_detected: factor_detected,
        signal_description: signal_desc,
    }
}

// ═══════════════════════════════════════════════════════════════
// ECDSA KEY PROBE
// ═══════════════════════════════════════════════════════════════

/// Probe an ECDSA key's private scalar for spectral anomalies.
///
/// The private key d is supposedly a uniform random scalar in [1, n-1].
/// We check:
/// 1. Hamming weight ratio (should be ~0.5 for uniform random bits)
/// 2. Vasyunin sum V(m, d mod m) for small m — should look like noise
fn probe_ecdsa(ec_key: &EcdsaKeyInfo) -> EcdsaAnalysisResult {
    let props = scalar_properties(&ec_key.private_key_hex);

    let hamming_deviation = (props.hamming_ratio - 0.5).abs();
    println!("    Private key scalar properties:");
    println!("      Hamming weight: {}/{} bits (ratio={:.4}, deviation from 0.5: {:.4})",
        props.hamming_weight, props.total_bits, props.hamming_ratio, hamming_deviation);
    println!("      Trailing zero bits: {}", props.trailing_zero_bits);

    // Vasyunin scan on d mod m
    let d_bytes = hex_to_bytes_pub(&ec_key.private_key_hex);
    let scan_limit = 1000u64;
    let moduli: Vec<u64> = (2..=scan_limit).collect();

    let mut scalar_vasyunin = Vec::new();
    let mut _v_values = Vec::new();

    for &m in &moduli {
        let d_mod_m = mod_reduce_bytes(&d_bytes, m);
        let v = crate::probes::vasyunin_sum(m, d_mod_m);
        let v_abs = v.abs();
        _v_values.push(v_abs);
        scalar_vasyunin.push(ScalarVasyuninEntry { m, d_mod_m, v_abs });
    }

    scalar_vasyunin.sort_by(|a, b| a.v_abs.partial_cmp(&b.v_abs).unwrap());

    // Check for anomalies: any V-values suspiciously close to zero?
    let zeros = scalar_vasyunin.iter().filter(|e| e.v_abs < 1e-10).count();
    let near_zeros = scalar_vasyunin.iter().filter(|e| e.v_abs < 1e-6).count();

    println!("\n    Vasyunin scan V(m, d mod m) for m ∈ [2, {}]:", scan_limit);
    println!("      Exact zeros: {}, near-zeros (<1e-6): {}", zeros, near_zeros);
    println!("      Top-5 smallest |V(m, d mod m)|:");
    for (i, entry) in scalar_vasyunin.iter().take(5).enumerate() {
        println!("        #{}: m={:5} |V|={:.6e} (d mod m = {})", i+1, entry.m, entry.v_abs, entry.d_mod_m);
    }

    // A uniform random scalar should have ~0 exact zeros (extremely rare)
    // If we see multiple zeros, the scalar has unexpected structure
    let anomaly = zeros > 2 || hamming_deviation > 0.1;
    let description = if anomaly {
        format!("ANOMALY: {} Vasyunin zeros, Hamming deviation {:.4}. \
                 Private key scalar shows unexpected arithmetic structure.", zeros, hamming_deviation)
    } else {
        format!("NORMAL: {} zeros, {} near-zeros. Hamming ratio {:.4}. \
                 Scalar appears consistent with uniform random selection.",
                zeros, near_zeros, props.hamming_ratio)
    };
    println!("    {}\n", description);

    // Truncate for JSON
    scalar_vasyunin.truncate(20);

    EcdsaAnalysisResult {
        curve: ec_key.curve.clone(),
        bits: ec_key.bits,
        scalar_props: props,
        hamming_deviation,
        scalar_vasyunin,
        anomaly_detected: anomaly,
        description,
    }
}

// ═══════════════════════════════════════════════════════════════
// SUMMARY PRINTING
// ═══════════════════════════════════════════════════════════════

/// Print a comprehensive summary of all SSH probe results.
pub fn print_ssh_summary(results: &[SshProbeResult]) {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  SSH KEY SPECTRAL ANALYSIS — SUMMARY");
    println!("═══════════════════════════════════════════════════════════════\n");

    for result in results {
        let status = if result.class_result.is_some() {
            "Full H1–H6"
        } else if result.large_key_vasyunin.is_some() {
            "Mod-reduced Vasyunin"
        } else if result.ecdsa_analysis.is_some() {
            "Scalar analysis"
        } else {
            "None"
        };

        print!("  [{}] — {}: ", result.key_type, status);

        if let Some(ref lkv) = result.large_key_vasyunin {
            if lkv.factor_signal_detected {
                println!("⚡ SIGNAL DETECTED");
            } else {
                println!("∅ No factor leakage");
            }
            println!("       {}", lkv.signal_description);
        } else if let Some(ref ecdsa) = result.ecdsa_analysis {
            if ecdsa.anomaly_detected {
                println!("⚠ Anomaly detected");
            } else {
                println!("∅ Normal scalar distribution");
            }
            println!("       Hamming ratio={:.4}, Vasyunin zeros={}",
                ecdsa.scalar_props.hamming_ratio,
                ecdsa.scalar_vasyunin.iter().filter(|e| e.v_abs < 1e-10).count());
        } else if let Some(ref cr) = result.class_result {
            let h1_signal = !cr.h1_results.is_empty() &&
                cr.h1_results.iter().map(|r| r.density_ratio).sum::<f64>() / cr.h1_results.len() as f64 > 1.5;
            if h1_signal {
                println!("⚡ H1 signal in SSH-derived semiprimes");
            } else {
                println!("∅ No special structure vs random semiprimes");
            }
        }
        println!();
    }

    println!("  ╔═══════════════════════════════════════════════════════════╗");
    println!("  ║ SSH KEY SECURITY ASSESSMENT                             ║");
    println!("  ╚═══════════════════════════════════════════════════════════╝");

    let any_signal = results.iter().any(|r| {
        r.large_key_vasyunin.as_ref().map(|v| v.factor_signal_detected).unwrap_or(false)
    });

    if any_signal {
        println!("  ⚠ UNEXPECTED: Factor structure detectable in large RSA keys.");
        println!("    This would be a MAJOR finding — verify carefully!\n");
    } else {
        println!("  ✓ No spectral factor leakage detected in SSH key material.");
        println!("    Cathedral spectral probes do not compromise SSH key security.");
        println!("    This is the EXPECTED result — Nyman-Beurling encodes");
        println!("    collective prime distribution, not individual factorizations.\n");
    }
}

// ═══════════════════════════════════════════════════════════════
// UTILITY
// ═══════════════════════════════════════════════════════════════

/// Convert hex string to bytes (public wrapper for cross-module use).
fn hex_to_bytes_pub(hex: &str) -> Vec<u8> {
    let hex = hex.replace(':', "").replace(' ', "");
    let hex = if hex.len() % 2 == 1 { format!("0{}", hex) } else { hex };
    (0..hex.len())
        .step_by(2)
        .filter_map(|i| u8::from_str_radix(&hex[i..i+2], 16).ok())
        .collect()
}

/// Compute n mod m where n is represented as big-endian bytes.
fn mod_reduce_bytes(bytes: &[u8], m: u64) -> u64 {
    let mut result = 0u64;
    for &byte in bytes {
        result = (result * 256 + byte as u64) % m;
    }
    result
}
