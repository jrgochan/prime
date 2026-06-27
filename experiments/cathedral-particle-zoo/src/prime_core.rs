//! Prime Core Conjecture Test
//!
//! Tests whether the "prime core" eigenvectors of the full Gram matrix G_N
//! converge to the eigenvectors of the small-prime subblock G_P.
//!
//! # The Conjecture
//!
//! Let P = {p₁, p₂, ..., pₖ} be the first k primes. Define the prime subblock:
//!
//!     G_P(i,j) = G_N(pᵢ-1, pⱼ-1)   (0-indexed into the dim×dim matrix)
//!
//! **Conjecture**: As N → ∞, there exist O(1) eigenvectors of G_N whose
//! restriction to prime indices converges to the eigenvectors of G_P, with
//! eigenvalues converging to those of G_P.
//!
//! # Test Methodology
//!
//! 1. Extract the prime subblock G_P from the full Gram matrix
//! 2. Eigendecompose G_P (it's ~10×10, instant)
//! 3. For each G_P eigenvector u, find the full eigenvector v that has
//!    maximum overlap |<u, π(v)>|² where π projects v onto prime indices
//! 4. Report eigenvalue agreement and eigenvector overlap

use cathedral_utils::arith;
use cathedral_utils::fmt as cfmt;

/// Result of the prime core test.
#[derive(Debug, Clone, serde::Serialize)]
pub struct PrimeCoreResult {
    pub n: usize,
    pub dim: usize,
    pub k_primes: usize,  // Number of primes used for G_P
    pub primes: Vec<usize>,

    /// G_P eigenvalues (sorted ascending)
    pub gp_eigenvalues: Vec<f64>,

    /// For each G_P eigenvector, the best-matching full eigenvector
    pub matches: Vec<PrimeCoreMatch>,

    /// The sentinel: the G_P eigenvector with highest overlap
    pub sentinel_gp_eigenvalue: f64,
    pub sentinel_full_eigenvalue: f64,
    pub sentinel_overlap: f64,
    pub sentinel_full_purity: f64,
}

/// Match between a G_P eigenvector and a full eigenvector.
#[derive(Debug, Clone, serde::Serialize)]
pub struct PrimeCoreMatch {
    pub gp_index: usize,         // Index in G_P eigenvalues (ascending)
    pub gp_eigenvalue: f64,
    pub gp_eigenvector: Vec<f64>, // k-dimensional

    pub full_index: usize,       // Index in full eigenvalues (ascending)
    pub full_eigenvalue: f64,
    pub overlap: f64,            // |<u, π(v)>|²
    pub eigenvalue_error: f64,   // |λ_GP - λ_full| / λ_GP
    pub full_purity: f64,        // The full eigenvector's purity on primes (P₁)

    /// Components of the full eigenvector on the first k primes
    pub full_prime_components: Vec<f64>,
}

impl PrimeCoreResult {
    /// Run the prime core conjecture test.
    ///
    /// # Arguments
    /// * `gram_flat` — full Gram matrix (dim×dim, row-major)
    /// * `eigenvalues` — sorted ascending, from full eigendecomposition
    /// * `eigenvectors` — eigenvectors[k] = k-th eigenvector
    /// * `n` — the N value
    /// * `k_primes` — number of primes to use for G_P (default: 10)
    pub fn test(
        gram_flat: &[f64],
        eigenvalues: &[f64],
        eigenvectors: &[Vec<f64>],
        n: usize,
        k_primes: usize,
    ) -> Self {
        let dim = n - 1;

        // Step 1: Identify the first k primes ≤ N
        let prime_sieve = arith::sieve_primes(n);
        let primes: Vec<usize> = (2..=n)
            .filter(|&p| prime_sieve[p])
            .take(k_primes)
            .collect();
        let k = primes.len();

        eprintln!("    [Prime Core] Using {} primes: {:?}", k, primes);

        // Step 2: Extract G_P (k×k subblock)
        // Prime p maps to Gram matrix row/col index p-2 (since matrix is 0-indexed for 2..N)
        let prime_indices: Vec<usize> = primes.iter().map(|&p| p - 2).collect();

        let mut gp_flat = vec![0.0f64; k * k];
        for (i, &pi) in prime_indices.iter().enumerate() {
            for (j, &pj) in prime_indices.iter().enumerate() {
                gp_flat[i * k + j] = gram_flat[pi * dim + pj];
            }
        }

        // Report G_P diagonal
        eprintln!("    [Prime Core] G_P diagonal:");
        for (i, &p) in primes.iter().enumerate() {
            eprintln!("      G({},{}) = {:.10}", p, p, gp_flat[i * k + i]);
        }

        // Step 3: Eigendecompose G_P (instant — it's k×k)
        let gp_result = cathedral_utils::eigen::eigen_f64(&gp_flat, k);
        let gp_eigenvalues = &gp_result.eigenvalues;
        let gp_eigenvectors = &gp_result.eigenvectors;

        eprintln!("    [Prime Core] G_P eigenvalues:");
        for (i, &lambda) in gp_eigenvalues.iter().enumerate() {
            eprintln!("      λ_GP[{}] = {:.10e}", i, lambda);
        }

        // Step 4: For each G_P eigenvector u, find the best-matching full eigenvector
        let mut matches: Vec<PrimeCoreMatch> = Vec::new();

        for gp_idx in 0..k {
            let u = &gp_eigenvectors[gp_idx]; // k-dimensional G_P eigenvector
            let gp_lambda = gp_eigenvalues[gp_idx];

            // For each full eigenvector v, compute:
            //   π(v) = v restricted to prime indices (k-dimensional)
            //   overlap = |<u, π(v)/||π(v)||>|²
            let mut best_overlap = 0.0f64;
            let mut best_full_idx = 0;

            for full_idx in 0..eigenvalues.len() {
                let v = &eigenvectors[full_idx];

                // Extract prime-index components of v
                let pi_v: Vec<f64> = prime_indices.iter().map(|&idx| v[idx]).collect();
                let pi_norm: f64 = pi_v.iter().map(|x| x * x).sum::<f64>().sqrt();

                if pi_norm < 1e-15 { continue; }

                // Normalize π(v)
                let pi_v_norm: Vec<f64> = pi_v.iter().map(|x| x / pi_norm).collect();

                // Inner product |<u, π(v)/||π(v)||>|²
                let dot: f64 = u.iter().zip(pi_v_norm.iter()).map(|(a, b)| a * b).sum();
                let overlap = dot * dot;

                if overlap > best_overlap {
                    best_overlap = overlap;
                    best_full_idx = full_idx;
                }
            }

            // Extract match data
            let best_v = &eigenvectors[best_full_idx];
            let full_prime_components: Vec<f64> = prime_indices
                .iter()
                .map(|&idx| best_v[idx])
                .collect();

            // Compute purity of the full eigenvector on primes
            let prime_weight: f64 = prime_indices
                .iter()
                .map(|&idx| best_v[idx] * best_v[idx])
                .sum();
            let total_weight: f64 = best_v.iter().map(|x| x * x).sum();
            let full_purity = if total_weight > 1e-30 { prime_weight / total_weight } else { 0.0 };

            let eigenvalue_error = if gp_lambda.abs() > 1e-30 {
                (gp_lambda - eigenvalues[best_full_idx]).abs() / gp_lambda.abs()
            } else {
                0.0
            };

            matches.push(PrimeCoreMatch {
                gp_index: gp_idx,
                gp_eigenvalue: gp_lambda,
                gp_eigenvector: u.clone(),
                full_index: best_full_idx,
                full_eigenvalue: eigenvalues[best_full_idx],
                overlap: best_overlap,
                eigenvalue_error,
                full_purity,
                full_prime_components,
            });
        }

        // Find the sentinel (highest overlap)
        let sentinel = matches.iter()
            .max_by(|a, b| a.overlap.partial_cmp(&b.overlap).unwrap())
            .unwrap();

        PrimeCoreResult {
            n,
            dim,
            k_primes: k,
            primes,
            gp_eigenvalues: gp_eigenvalues.clone(),
            sentinel_gp_eigenvalue: sentinel.gp_eigenvalue,
            sentinel_full_eigenvalue: sentinel.full_eigenvalue,
            sentinel_overlap: sentinel.overlap,
            sentinel_full_purity: sentinel.full_purity,
            matches,
        }
    }

    /// Display the results.
    pub fn display(&self) {
        println!();
        println!("  ┌─────────────────────────────────────────────────────────────────┐");
        println!("  │ PRIME CORE CONJECTURE TEST                                      │");
        println!("  │ G_P subblock ({0}×{0}) vs full G_N ({1}×{1})                    │",
                 self.k_primes, self.dim);
        println!("  ├─────────────────────────────────────────────────────────────────┤");
        println!("  │ Primes used: {:?}", &self.primes[..self.primes.len().min(15)]);
        println!("  ├─────────────────────────────────────────────────────────────────┤");
        println!("  │                                                                 │");

        // Main comparison table
        println!("  │  G_P idx │ λ(G_P)         │ λ(G_N match)   │ λ error  │ overlap  │");
        println!("  │ ─────────┼────────────────┼────────────────┼──────────┼──────────│");

        for m in &self.matches {
            let check = if m.overlap > 0.95 { "★★★" }
                else if m.overlap > 0.80 { "★★ " }
                else if m.overlap > 0.50 { "★  " }
                else { "   " };
            println!("  │  {:>6}  │ {:>13.6e} │ {:>13.6e} │ {:>7.3}% │ {:>7.4}  │ {}",
                     m.gp_index, m.gp_eigenvalue, m.full_eigenvalue,
                     m.eigenvalue_error * 100.0, m.overlap, check);
        }
        println!("  │                                                                 │");

        // Sentinel highlight
        let sentinel = self.matches.iter()
            .max_by(|a, b| a.overlap.partial_cmp(&b.overlap).unwrap())
            .unwrap();
        println!("  ├─────────────────────────────────────────────────────────────────┤");
        println!("  │ SENTINEL (highest overlap):                                     │");
        println!("  │   G_P eigenvalue:  {:.10e}                              │", sentinel.gp_eigenvalue);
        println!("  │   Full eigenvalue: {:.10e}                              │", sentinel.full_eigenvalue);
        println!("  │   Overlap |<u,πv>|²: {:.6}                                   │", sentinel.overlap);
        println!("  │   λ error:         {:.4}%                                      │", sentinel.eigenvalue_error * 100.0);
        println!("  │   Full v purity:   {:.4} (weight on prime indices)             │", sentinel.full_purity);

        // Overall verdict
        let high_overlap_count = self.matches.iter().filter(|m| m.overlap > 0.80).count();
        let good_overlap_count = self.matches.iter().filter(|m| m.overlap > 0.50).count();
        let mean_overlap: f64 = self.matches.iter().map(|m| m.overlap).sum::<f64>() / self.matches.len() as f64;
        let mean_eigenvalue_error: f64 = self.matches.iter().map(|m| m.eigenvalue_error).sum::<f64>() / self.matches.len() as f64;

        println!("  ├─────────────────────────────────────────────────────────────────┤");
        println!("  │ SUMMARY:                                                        │");
        println!("  │   Eigenvectors with overlap > 0.80: {}/{}                       │",
                 high_overlap_count, self.k_primes);
        println!("  │   Eigenvectors with overlap > 0.50: {}/{}                       │",
                 good_overlap_count, self.k_primes);
        println!("  │   Mean overlap:     {:.6}                                      │", mean_overlap);
        println!("  │   Mean λ error:     {:.4}%                                      │", mean_eigenvalue_error * 100.0);

        if high_overlap_count as f64 >= self.k_primes as f64 * 0.5 {
            println!("  │                                                                 │");
            println!("  │   {}{}★★★ CONJECTURE CONFIRMED ★★★{}                              │",
                     cfmt::BOLD, cfmt::GREEN, cfmt::RESET);
            println!("  │   G_N eigenvectors converge to G_P eigenvectors!                │");
        } else if good_overlap_count as f64 >= self.k_primes as f64 * 0.3 {
            println!("  │                                                                 │");
            println!("  │   {}★★ PARTIAL CONFIRMATION ★★{}                                 │",
                     cfmt::YELLOW, cfmt::RESET);
            println!("  │   Some G_P modes are preserved in the full spectrum.            │");
        } else {
            println!("  │                                                                 │");
            println!("  │   {}✗ CONJECTURE NOT SUPPORTED ✗{}                               │",
                     cfmt::RED, cfmt::RESET);
        }

        println!("  └─────────────────────────────────────────────────────────────────┘");

        // Print eigenvector component comparison for the sentinel
        println!();
        cfmt::section("SENTINEL EIGENVECTOR COMPONENT COMPARISON");
        println!("  ┌────────┬───────────────┬───────────────┐");
        println!("  │ prime  │  G_P (u)      │  G_N (πv)     │");
        println!("  ├────────┼───────────────┼───────────────┤");

        // Normalize full prime components for comparison
        let full_norm: f64 = sentinel.full_prime_components
            .iter().map(|x| x * x).sum::<f64>().sqrt();
        for (i, &p) in self.primes.iter().enumerate() {
            let u_comp = sentinel.gp_eigenvector[i];
            let v_comp = if full_norm > 1e-15 {
                sentinel.full_prime_components[i] / full_norm
            } else {
                0.0
            };
            let sign_match = if u_comp * v_comp >= 0.0 { " " } else { "!" };
            println!("  │ {:>5}  │ {:>+12.6} │ {:>+12.6} │{}",
                     p, u_comp, v_comp, sign_match);
        }
        println!("  └────────┴───────────────┴───────────────┘");
    }
}

/// Write prime core results to JSON.
pub fn write_prime_core_json(result: &PrimeCoreResult, dir: &str) -> std::io::Result<()> {
    std::fs::create_dir_all(dir)?;
    let path = format!("{dir}/prime_core_N{}.json", result.n);
    let json_str = serde_json::to_string_pretty(result)
        .map_err(std::io::Error::other)?;
    std::fs::write(&path, json_str)?;
    eprintln!("  ✓ Prime core → {path}");
    Ok(())
}
