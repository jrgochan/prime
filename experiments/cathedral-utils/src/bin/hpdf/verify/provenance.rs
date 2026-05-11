//! Provenance, lineage, number theory, and distance verification.

use crate::common::*;
use cathedral_utils::hpdf::HpdfReader;

/// Display provenance metadata.
pub fn show_provenance(reader: &HpdfReader) {
    if let Ok(prov) = reader.read_provenance() {
        println!("  {GREEN}✓{RESET} Provenance:");
        println!("    builder    = {}", prov.builder);
        println!("    precision  = {}", prov.precision);
        println!(
            "    sha256     = {}...",
            &prov.source_sha256[..16.min(prov.source_sha256.len())]
        );
        println!("    git_commit = {}", prov.git_commit);
        println!("    hostname   = {}", prov.hostname);
        println!("    build_time = {:.2}s", prov.build_time_secs);
    }
}

/// Display number theory metadata (μ, primes, factorization).
pub fn show_number_theory(reader: &HpdfReader) {
    if let Ok(mu) = reader.read_mobius() {
        println!(
            "  {GREEN}✓{RESET} μ table: {} entries, μ(1)={}, μ(2)={}, μ(4)={}",
            mu.len(),
            mu[1],
            mu[2],
            mu[4]
        );
    }
    if let Ok(primes) = reader.read_primes() {
        println!(
            "  {GREEN}✓{RESET} Primes: {} primes ≤ {}",
            primes.len(),
            reader.max_n()
        );
    }
    if let Ok(Some(nt)) = reader.read_number_theory_attrs() {
        println!(
            "  {GREEN}✓{RESET} N={}: {} (τ={}, σ={}, HC={})",
            reader.max_n(),
            nt.factorization,
            nt.divisor_count,
            nt.divisor_sum,
            nt.is_highly_composite
        );
    }
}

/// Display lineage metadata.
pub fn show_lineage(reader: &HpdfReader) {
    if let Ok(Some(lin)) = reader.read_lineage() {
        println!(
            "  {GREEN}✓{RESET} Lineage: {} (from N={})",
            lin.derivation, lin.parent_max_n
        );
    }
}

/// Display distance results (if present).
pub fn show_distance(reader: &HpdfReader) {
    if let Ok(Some(dist)) = reader.read_distance() {
        println!("  {GREEN}✓{RESET} Distance: d²={:.15e}", dist.d_squared);
        println!(
            "    solver={}, iters={}, residual={:.2e}, converged={}",
            dist.solver, dist.iterations, dist.residual_norm, dist.converged
        );
        if let Some(bt_x) = dist.bt_x {
            println!("    bᵀx={:.15e}  →  1-bᵀx={:.15e}", bt_x, 1.0 - bt_x);
        }
        if let Ok(Some(hist)) = reader.read_convergence_history() {
            println!(
                "    convergence: {} iters, final={:.2e}",
                hist.len(),
                hist.last().unwrap_or(&0.0)
            );
        }
        if let Ok(Some(sol)) = reader.read_solution_vector() {
            println!("    solution_vector: {} entries stored", sol.len());
        }
    }
}
