#![allow(dead_code, clippy::needless_range_loop, clippy::manual_clamp)]
//! Cathedral Spectral Factorization Probe
//!
//! Tests whether Cathedral observables (Gram matrix spectra, GCD strata,
//! Möbius/Liouville charges, Vasyunin cotangent sums, composite anchoring)
//! reveal structural signatures of semiprime factors.
//!
//! HONEST DISCLAIMER: This is a research exploration, not a practical
//! factoring algorithm. The Cathedral proof is about statistical prime
//! distribution (RH ↔ d²_N → 0), not individual factorizations.

mod keygen;
mod probes;

use std::time::Instant;

fn main() {
    println!("═══════════════════════════════════════════════════════════════");
    println!("  CATHEDRAL SPECTRAL FACTORIZATION PROBE v0.1");
    println!("  Testing 6 hypotheses from the Cathedral proof chain");
    println!("═══════════════════════════════════════════════════════════════\n");

    let t0 = Instant::now();

    // Phase 1: Generate test semiprimes at various bit widths
    let test_keys = keygen::generate_test_suite();
    println!("Generated {} test semiprimes across {} bit-width classes\n",
        test_keys.iter().map(|c| c.keys.len()).sum::<usize>(),
        test_keys.len());

    // Phase 2: Run all probes
    for class in &test_keys {
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        println!("  BIT WIDTH: {} bits ({} semiprimes)", class.bits, class.keys.len());
        println!("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

        // H1: GCD-stratum eigenvector correlation
        probes::h1_gcd_stratum_eigenvector(&class.keys);

        // H2: Optimal weight vector at factor indices
        probes::h2_optimal_weight_structure(&class.keys);

        // H3: Vasyunin cotangent sum anomaly
        probes::h3_vasyunin_cotangent_anomaly(&class.keys);

        // H4: Möbius/Liouville local structure
        probes::h4_mobius_local_structure(&class.keys);

        // H5: Composite anchoring inversion
        probes::h5_composite_anchoring(&class.keys);

        // H6: Quadratic form at factor-multiples
        probes::h6_quadratic_form_probe(&class.keys);

        println!();
    }

    println!("═══════════════════════════════════════════════════════════════");
    println!("  Total time: {:.2}s", t0.elapsed().as_secs_f64());
    println!("═══════════════════════════════════════════════════════════════");
}
