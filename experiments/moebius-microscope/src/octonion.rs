//! ══════════════════════════════════════════════════════════════════════
//!  OCTONIONIC GRAM MATRIX — BOTT PERIODICITY PROBE v2
//!
//!  Four experiments connecting octonion structure to the NB Gram matrix:
//!
//!  1. MOD-8 RESIDUE DECOMPOSITION: Decompose vᵀGv by (j mod 8, k mod 8).
//!     The 4 Dirichlet characters diagonalize the odd block.
//!
//!  2. BOTT PERIODICITY — BLOCK DIAGONAL: Spectral gap of G¹⊕G²⊕...⊕Gⁿ
//!     for channel counts 1..16. Does it stabilize at 8?
//!
//!  3. BOTT PERIODICITY — COUPLED: Full cross-channel Gram matrix with
//!     off-diagonal coupling. This is the TRUE multi-channel test.
//!
//!  4. OCTONIONIC CROSS-CHANNEL STRUCTURE: The 8×8 contracted Gram
//!     C(p,q) = Σ vⱼ G^{p,q}(j,k) vₖ, eigenanalysis.
//!
//!  Created: May 2, 2026 (Exploration 24 — The Octonion Connection v2)
//! ══════════════════════════════════════════════════════════════════════

use cathedral_utils::arith::{self, frac_part, Kahan};
use cathedral_utils::gram;
use cathedral_utils::spectral;
use rayon::prelude::*;
use serde::Serialize;
use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::time::Instant;

/// Parallel chunk size for quadrature reduction.
const QUAD_CHUNK: usize = 4096;

/// Ensure the results directory exists and return its path.
fn results_dir() -> PathBuf {
    let dir = PathBuf::from("results");
    fs::create_dir_all(&dir).expect("Failed to create results directory");
    dir
}

/// Gram entry for power channel p: ∫₀¹ {j/x^p}{k/x^p} dx
/// Uses Kahan summation within chunks, rayon parallel reduce across chunks.
fn gram_entry_power(j: usize, k: usize, power: u32, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let n_chunks = n_pts.div_ceil(QUAD_CHUNK);
    let partial: f64 = (0..n_chunks)
        .into_par_iter()
        .map(|chunk| {
            let start = chunk * QUAD_CHUNK;
            let end = (start + QUAD_CHUNK).min(n_pts);
            let mut acc = Kahan::new();
            for i in start..end {
                let x = (i as f64 + 0.5) * dx;
                let xp = x.powi(power as i32);
                if xp > 1e-15 {
                    acc.add(frac_part(jf / xp) * frac_part(kf / xp));
                }
            }
            acc.value()
        })
        .sum();
    partial * dx
}

/// Cross-channel entry: ∫₀¹ {j/x^p₁}{k/x^p₂} dx
/// Uses Kahan summation within chunks, rayon parallel reduce across chunks.
fn gram_cross(j: usize, k: usize, p1: u32, p2: u32, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let n_chunks = n_pts.div_ceil(QUAD_CHUNK);
    let partial: f64 = (0..n_chunks)
        .into_par_iter()
        .map(|chunk| {
            let start = chunk * QUAD_CHUNK;
            let end = (start + QUAD_CHUNK).min(n_pts);
            let mut acc = Kahan::new();
            for i in start..end {
                let x = (i as f64 + 0.5) * dx;
                let xp1 = x.powi(p1 as i32);
                let xp2 = x.powi(p2 as i32);
                if xp1 > 1e-15 && xp2 > 1e-15 {
                    acc.add(frac_part(jf / xp1) * frac_part(kf / xp2));
                }
            }
            acc.value()
        })
        .sum();
    partial * dx
}

// ══════════════════════════════════════════════════════════════
// EXPERIMENT 1: MOD-8 RESIDUE DECOMPOSITION OF vᵀGv
// ══════════════════════════════════════════════════════════════

#[derive(Serialize, Clone)]
struct Exp1Results {
    n: usize,
    dim: usize,
    residue_matrix_8x8: Vec<Vec<f64>>,
    odd_block_4x4: Vec<Vec<f64>>,
    character_eigenvalues: Vec<f64>,
    odd_block_eigenvalues: Vec<f64>,
    negative_eigenvalue_count: usize,
    condition_number: f64,
    trace_over_total: f64,
    elapsed_seconds: f64,
}

fn experiment_1_mod8_residue(n: usize) -> Exp1Results {
    println!("\n═══ EXPERIMENT 1: MOD-8 RESIDUE DECOMPOSITION (N={n}) ═══\n");
    let t0 = Instant::now();
    let dim = n - 1;
    let weights = arith::mobius_weights(n);

    // Parallel accumulation: partition by j, each thread builds its own 8×8
    // Kahan block, then reduce across threads.
    let q_flat: Vec<[f64; 64]> = (0..dim)
        .into_par_iter()
        .map(|j_idx| {
            let j = j_idx + 2;
            let vj = weights[j_idx];
            let mut local = [0.0f64; 64]; // flat 8×8
            if vj.abs() < 1e-30 {
                return local;
            }
            for k_idx in 0..dim {
                let k = k_idx + 2;
                let vk = weights[k_idx];
                if vk.abs() < 1e-30 {
                    continue;
                }
                let g = gram::gram_entry_f64(j, k);
                local[(j % 8) * 8 + (k % 8)] += vj * g * vk;
            }
            local
        })
        .collect();

    // Reduce thread-local blocks into final 8×8 with Kahan
    let mut q = [[Kahan::default(); 8]; 8];
    for block in &q_flat {
        for r1 in 0..8 {
            for r2 in 0..8 {
                q[r1][r2].add(block[r1 * 8 + r2]);
            }
        }
    }

    // Print full 8x8
    println!("  8×8 Residue Matrix Q(r₁,r₂):\n");
    print!("       ");
    for r2 in 0..8 {
        print!("  r≡{r2:>2}     ");
    }
    println!();
    for r1 in 0..8 {
        print!("  r≡{r1} ");
        for r2 in 0..8 {
            let v = q[r1][r2].value();
            if v.abs() > 1e-10 {
                print!(" {:>10.4e}", v);
            } else {
                print!(" {:>10}", "—");
            }
        }
        println!();
    }

    // Extract 4×4 odd block
    let odd = [1usize, 3, 5, 7];
    println!("\n  4×4 ODD BLOCK (residues {{1,3,5,7}}):\n");
    print!("       ");
    for &r2 in &odd {
        print!("  r≡{r2:>2}     ");
    }
    println!();
    for &r1 in &odd {
        print!("  r≡{r1} ");
        for &r2 in &odd {
            print!(" {:>10.4e}", q[r1][r2].value());
        }
        println!();
    }

    // Character eigenvalues using cathedral-utils arith::chi8
    println!("\n  DIRICHLET CHARACTER EIGENVALUES:\n");
    let mut chi_evals = [0.0f64; 4];
    for ch in 0..4 {
        let mut ev = Kahan::default();
        for i in 0..4 {
            for j in 0..4 {
                let ci = arith::chi8(ch, odd[i]) as f64;
                let cj = arith::chi8(ch, odd[j]) as f64;
                ev.add(ci * cj * q[odd[i]][odd[j]].value());
            }
        }
        chi_evals[ch] = ev.value() / 4.0;
        println!(
            "    χ_{ch}: {:>14.10e}  (ratio: {:.4})",
            chi_evals[ch],
            chi_evals[ch] / chi_evals[0].max(1e-30)
        );
    }

    // Checkerboard structure
    let q_odd_flat: Vec<f64> = odd
        .iter()
        .flat_map(|&r1| odd.iter().map(move |&r2| q[r1][r2].value()))
        .collect();
    let trace: f64 = (0..4).map(|i| q_odd_flat[i * 4 + i]).sum();
    let total: f64 = q_odd_flat.iter().sum();
    println!("\n  ODD BLOCK STRUCTURE:");
    println!("    Trace: {trace:.6e}");
    println!("    Total: {total:.6e}");
    println!("    Trace/Total: {:.4}", trace / total.max(1e-30));

    // Eigendecomposition via cathedral-utils spectral::full_eigen
    let (evals, _ground) = spectral::full_eigen(&q_odd_flat, 4);
    println!("\n  4×4 ODD BLOCK EIGENVALUES:");
    for (i, ev) in evals.iter().enumerate() {
        println!("    λ_{} = {:>14.10e}", i + 1, ev);
    }
    let neg = evals.iter().filter(|&&v| v < -1e-12).count();
    let cond = evals.last().unwrap() / evals[0].max(1e-30);
    println!("    Negative eigenvalues: {neg}/4");
    println!("    Condition number: {cond:.2e}");

    let elapsed = t0.elapsed().as_secs_f64();
    println!("  Done in {elapsed:.1}s");

    // Build structured results
    let residue_matrix: Vec<Vec<f64>> = (0..8)
        .map(|r1| (0..8).map(|r2| q[r1][r2].value()).collect())
        .collect();
    let odd_block: Vec<Vec<f64>> = odd
        .iter()
        .map(|&r1| odd.iter().map(|&r2| q[r1][r2].value()).collect())
        .collect();

    let result = Exp1Results {
        n,
        dim,
        residue_matrix_8x8: residue_matrix,
        odd_block_4x4: odd_block,
        character_eigenvalues: chi_evals.to_vec(),
        odd_block_eigenvalues: evals.clone(),
        negative_eigenvalue_count: neg,
        condition_number: cond,
        trace_over_total: trace / total.max(1e-30),
        elapsed_seconds: elapsed,
    };

    // Write TSV of 8x8 matrix
    let dir = results_dir();
    let mut tsv = fs::File::create(dir.join(format!("exp1_residue_matrix_N{n}.tsv")))
        .expect("Failed to create TSV");
    writeln!(tsv, "r1\tr2\tvalue").unwrap();
    for r1 in 0..8 {
        for r2 in 0..8 {
            writeln!(tsv, "{}\t{}\t{:.15e}", r1, r2, q[r1][r2].value()).unwrap();
        }
    }

    result
}

// ══════════════════════════════════════════════════════════════
// EXPERIMENT 2: BOTT PERIODICITY — SPECTRAL GAP (BLOCK DIAGONAL)
// ══════════════════════════════════════════════════════════════

#[derive(Serialize, Clone)]
struct Exp2Results {
    n: usize,
    n_pts: usize,
    channel_lambda_mins: Vec<f64>,
    block_diagonal_lambda_mins: Vec<(usize, f64)>,
    elapsed_seconds: f64,
}

fn experiment_2_bott_block_diagonal(n: usize, n_pts: usize) -> Exp2Results {
    println!("\n═══ EXPERIMENT 2: BOTT PERIODICITY — BLOCK DIAGONAL (N={n}) ═══\n");
    println!("  Block diagonal G¹⊕G²⊕...⊕Gᶜ: λ_min = min over channels");
    println!("  (No cross-channel coupling — this is the trivial extension)\n");

    let dim = n - 1;
    let t0 = Instant::now();

    // Sweep 1..12 channels, compute λ_min for each channel individually
    let max_channels = 12;
    let mut channel_lmins = Vec::new();

    println!(
        "  {:>5} {:>14} {:>14} {:>10}",
        "power", "λ_min(Gᵖ)", "ratio to G¹", "time"
    );
    println!("  {}", "─".repeat(47));

    for p in 1..=(max_channels as u32) {
        let tc = Instant::now();
        let entries: Vec<((usize, usize), f64)> = (0..dim)
            .into_par_iter()
            .flat_map(|i| {
                (i..dim)
                    .into_par_iter()
                    .map(move |j| ((i, j), gram_entry_power(i + 2, j + 2, p, n_pts)))
            })
            .collect();

        // Build row-major flat matrix for spectral::full_eigen
        let mut flat = vec![0.0f64; dim * dim];
        for ((i, j), v) in entries {
            flat[i * dim + j] = v;
            flat[j * dim + i] = v;
        }

        let (evals, _) = spectral::full_eigen(&flat, dim);
        let lmin = evals[0]; // already sorted ascending
        channel_lmins.push(lmin);

        let ratio = lmin / channel_lmins[0].max(1e-30);
        println!(
            "  x^{:<3} {:>14.10} {:>14.6} {:>8.1}s",
            p,
            lmin,
            ratio,
            tc.elapsed().as_secs_f64()
        );
    }

    // Block diagonal λ_min = min over channels
    println!("\n  BLOCK DIAGONAL λ_min (min over channels):\n");
    println!("  {:>10} {:>14} {:>14}", "channels", "λ_min(⊕)", "ratio");
    println!("  {}", "─".repeat(42));

    for c in [1, 2, 3, 4, 5, 6, 7, 8, 10, 12] {
        if c > max_channels {
            break;
        }
        let lmin: f64 = channel_lmins[..c]
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        println!(
            "  {:>10} {:>14.10} {:>14.6}",
            c,
            lmin,
            lmin / channel_lmins[0].max(1e-30)
        );
    }

    println!("\n  NOTE: Block diagonal = trivial extension. λ_min is just min");
    println!("  over individual channels. Cross-coupling is tested in Exp 3.");
    let elapsed = t0.elapsed().as_secs_f64();
    println!("  Total: {elapsed:.1}s");

    let mut bd_lmins = Vec::new();
    for c in [1, 2, 3, 4, 5, 6, 7, 8, 10, 12] {
        if c > max_channels {
            break;
        }
        let lm: f64 = channel_lmins[..c]
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        bd_lmins.push((c, lm));
    }

    // Write TSV
    let dir = results_dir();
    let mut tsv = fs::File::create(dir.join(format!("exp2_bott_block_N{n}.tsv")))
        .expect("Failed to create TSV");
    writeln!(tsv, "power\tlambda_min").unwrap();
    for (i, lm) in channel_lmins.iter().enumerate() {
        writeln!(tsv, "{}\t{:.15e}", i + 1, lm).unwrap();
    }

    Exp2Results {
        n,
        n_pts,
        channel_lambda_mins: channel_lmins,
        block_diagonal_lambda_mins: bd_lmins,
        elapsed_seconds: elapsed,
    }
}

// ══════════════════════════════════════════════════════════════
// EXPERIMENT 3: COUPLED MULTI-CHANNEL — THE TRUE BOTT TEST
// ══════════════════════════════════════════════════════════════

#[derive(Serialize, Clone)]
struct Exp3Results {
    n: usize,
    n_pts: usize,
    channel_results: Vec<Exp3ChannelResult>,
    c8_eigenvalues: Option<Vec<f64>>,
    c8_kramers_pairs: Option<usize>,
    c8_negative_count: Option<usize>,
    c8_positive_definite: Option<bool>,
    elapsed_seconds: f64,
}

#[derive(Serialize, Clone)]
struct Exp3ChannelResult {
    channels: usize,
    dim: usize,
    lambda_min_coupled: f64,
    lambda_min_block_diag: f64,
    coupling_boost: f64,
}

fn experiment_3_coupled_spectral_gap(n: usize, n_pts: usize) -> Exp3Results {
    println!("\n═══ EXPERIMENT 3: COUPLED MULTI-CHANNEL SPECTRAL GAP (N={n}) ═══\n");
    println!("  Full G^C matrix with cross-channel terms ∫{{j/x^p}}{{k/x^q}}dx");
    println!("  Testing if coupling IMPROVES λ_min over block diagonal\n");

    let dim = n - 1;
    let t0 = Instant::now();

    // Test channel counts: 1, 2, 4, 8 (and 3, 5, 6, 7 for fine resolution)
    let channel_counts = [1, 2, 3, 4, 5, 6, 7, 8];

    println!(
        "  {:>6} {:>10} {:>14} {:>14} {:>14} {:>8}",
        "C", "dim", "λ_min(coupled)", "λ_min(blkdiag)", "coupling boost", "time"
    );
    println!("  {}", "─".repeat(72));

    let mut _lmin_c1 = 0.0f64;
    let mut channel_results = Vec::new();
    let mut c8_eigenvalues = None;
    let mut c8_kramers_pairs = None;
    let mut c8_negative_count = None;
    let mut c8_positive_definite = None;

    for &c in &channel_counts {
        let tc = Instant::now();
        let cdim = c * dim;

        // Collect all (p1, p2) channel pairs for parallel entry generation
        let ch_pairs: Vec<(usize, usize)> = (0..c)
            .flat_map(|p1| (p1..c).map(move |p2| (p1, p2)))
            .collect();

        // For each channel pair, compute all (i,j) entries in parallel
        let all_entries: Vec<Vec<((usize, usize, usize, usize), f64)>> = ch_pairs
            .par_iter()
            .map(|&(p1, p2)| {
                (0..dim)
                    .into_par_iter()
                    .flat_map(|i| {
                        (i..dim).into_par_iter().map(move |j| {
                            let v = if p1 == p2 {
                                gram_entry_power(i + 2, j + 2, (p1 + 1) as u32, n_pts)
                            } else {
                                gram_cross(i + 2, j + 2, (p1 + 1) as u32, (p2 + 1) as u32, n_pts)
                            };
                            ((p1, p2, i, j), v)
                        })
                    })
                    .collect()
            })
            .collect();

        // Scatter into flat row-major matrix
        let mut flat = vec![0.0f64; cdim * cdim];
        for entries in &all_entries {
            for &((p1, p2, i, j), v) in entries {
                let ri = p1 * dim + i;
                let rj = p2 * dim + j;
                flat[ri * cdim + rj] = v;
                flat[rj * cdim + ri] = v;
                if i != j {
                    let ri2 = p1 * dim + j;
                    let rj2 = p2 * dim + i;
                    flat[ri2 * cdim + rj2] = v;
                    flat[rj2 * cdim + ri2] = v;
                }
            }
        }

        let (evals, _) = spectral::full_eigen(&flat, cdim);
        let lmin_coupled = evals[0];

        // Block diagonal λ_min via spectral::full_eigen on each channel block
        let mut lmin_block = f64::INFINITY;
        for ch in 0..c {
            let mut block = vec![0.0f64; dim * dim];
            for r in 0..dim {
                for s in 0..dim {
                    block[r * dim + s] = flat[(ch * dim + r) * cdim + (ch * dim + s)];
                }
            }
            let (block_evals, _) = spectral::full_eigen(&block, dim);
            lmin_block = lmin_block.min(block_evals[0]);
        }

        if c == 1 {
            _lmin_c1 = lmin_coupled;
        }
        let boost = lmin_coupled / lmin_block.max(1e-30);

        println!(
            "  {:>6} {:>10} {:>14.10} {:>14.10} {:>12.4}× {:>6.1}s",
            c,
            cdim,
            lmin_coupled,
            lmin_block,
            boost,
            tc.elapsed().as_secs_f64()
        );

        channel_results.push(Exp3ChannelResult {
            channels: c,
            dim: cdim,
            lambda_min_coupled: lmin_coupled,
            lambda_min_block_diag: lmin_block,
            coupling_boost: boost,
        });

        // For C=8, show the 10 smallest eigenvalues and Kramers pairs
        if c == 8 {
            println!("\n    10 smallest eigenvalues of G^𝕆 (C=8, N={n}):");
            for i in 0..10.min(evals.len()) {
                let kramers = if i + 1 < evals.len()
                    && (evals[i] - evals[i + 1]).abs() < 1e-6 * evals[i].abs().max(1e-8)
                {
                    " ← Kramers pair?"
                } else if i > 0 && (evals[i] - evals[i - 1]).abs() < 1e-6 * evals[i].abs().max(1e-8)
                {
                    " ← Kramers pair?"
                } else {
                    ""
                };
                println!("      λ_{:>2} = {:>14.10}{}", i + 1, evals[i], kramers);
            }

            // Count Kramers pairs
            let mut pairs = 0;
            let mut idx = 0;
            while idx + 1 < evals.len() {
                if (evals[idx] - evals[idx + 1]).abs() < 1e-4 * evals[idx].abs().max(1e-8) {
                    pairs += 1;
                    idx += 2;
                } else {
                    idx += 1;
                }
            }
            println!(
                "    Kramers pairs: {pairs}/{} (50% = perfect GSE)",
                evals.len() / 2
            );

            // Negative eigenvalue count
            let neg = evals.iter().filter(|&&v| v < -1e-10).count();
            println!("    Negative eigenvalues: {neg}/{}", evals.len());
            println!(
                "    Is G^𝕆 positive definite? {}",
                if neg == 0 { "✅ YES" } else { "❌ NO" }
            );

            c8_eigenvalues = Some(evals[..10.min(evals.len())].to_vec());
            c8_kramers_pairs = Some(pairs);
            c8_negative_count = Some(neg);
            c8_positive_definite = Some(neg == 0);
        }
    }

    println!("\n  INTERPRETATION:");
    println!("    Coupling boost > 1 means cross-channel terms HELP the spectral gap");
    println!("    Bott periodicity predicts the boost stabilizes at C=8");
    let elapsed = t0.elapsed().as_secs_f64();
    println!("  Total: {elapsed:.1}s");

    // Write TSV
    let dir = results_dir();
    let mut tsv =
        fs::File::create(dir.join(format!("exp3_coupled_N{n}.tsv"))).expect("Failed to create TSV");
    writeln!(
        tsv,
        "channels\tdim\tlambda_min_coupled\tlambda_min_block\tcoupling_boost"
    )
    .unwrap();
    for cr in &channel_results {
        writeln!(
            tsv,
            "{}\t{}\t{:.15e}\t{:.15e}\t{:.10}",
            cr.channels, cr.dim, cr.lambda_min_coupled, cr.lambda_min_block_diag, cr.coupling_boost
        )
        .unwrap();
    }

    Exp3Results {
        n,
        n_pts,
        channel_results,
        c8_eigenvalues,
        c8_kramers_pairs,
        c8_negative_count,
        c8_positive_definite,
        elapsed_seconds: elapsed,
    }
}

// ══════════════════════════════════════════════════════════════
// EXPERIMENT 4: OCTONIONIC CROSS-CHANNEL CONTRACTION
// ══════════════════════════════════════════════════════════════

#[derive(Serialize, Clone)]
struct Exp4Results {
    n: usize,
    n_pts: usize,
    cross_matrix_8x8: Vec<Vec<f64>>,
    normalized_matrix_8x8: Vec<Vec<f64>>,
    eigenvalues: Vec<f64>,
    dominant_eigenvector: Vec<f64>,
    diagonal_decay: Vec<f64>,
    quaternion_trace: f64,
    octonion_trace: f64,
    extra_diagonal_pct: f64,
    extra_coupling_pct: f64,
    elapsed_seconds: f64,
}

fn experiment_4_cross_channel_contraction(n: usize, n_pts: usize) -> Exp4Results {
    println!("\n═══ EXPERIMENT 4: CROSS-CHANNEL CONTRACTION (N={n}) ═══\n");
    println!("  C(p,q) = Σ vⱼ · G^{{p,q}}(j,k) · vₖ  (contracted with Möbius weights)\n");

    let dim = n - 1;
    let t0 = Instant::now();

    let weights = arith::mobius_weights(n);
    let active: Vec<(usize, f64)> = (0..dim)
        .map(|i| (i + 2, weights[i]))
        .filter(|(_, w)| w.abs() > 1e-30)
        .collect();

    println!(
        "  Active indices: {} (computing 8×8 contraction)",
        active.len()
    );

    // Fully parallel contraction: all 36 upper-triangle (p,q) pairs at once
    let pq_pairs: Vec<(u32, u32)> = (0..8u32)
        .flat_map(|p| (p..8u32).map(move |q| (p, q)))
        .collect();

    let pq_values: Vec<((u32, u32), f64)> = pq_pairs
        .par_iter()
        .map(|&(p, q_ch)| {
            // Inner double sum: Σ_j Σ_k v_j · G^{p,q}(j,k) · v_k
            let val: f64 = active
                .iter()
                .map(|&(j, vj)| {
                    let mut acc = Kahan::new();
                    for &(k, vk) in &active {
                        let g = if p == q_ch {
                            gram_entry_power(j, k, p + 1, n_pts)
                        } else {
                            gram_cross(j, k, p + 1, q_ch + 1, n_pts)
                        };
                        acc.add(vj * g * vk);
                    }
                    acc.value()
                })
                .sum();
            ((p, q_ch), val)
        })
        .collect();

    let mut cross = [[0.0f64; 8]; 8];
    for ((p, q_ch), val) in pq_values {
        cross[p as usize][q_ch as usize] = val;
        cross[q_ch as usize][p as usize] = val;
    }
    eprintln!(
        "  All 36 pairs computed in {:.1}s",
        t0.elapsed().as_secs_f64()
    );

    // Display
    println!("\n  8×8 CROSS-CHANNEL CONTRACTION C(p,q):\n");
    print!("       ");
    for q_ch in 1..=8 {
        print!("  p={q_ch:>2}      ");
    }
    println!();
    for p in 0..8 {
        print!("  p={} ", p + 1);
        for q_ch in 0..8 {
            print!(" {:>10.4e}", cross[p][q_ch]);
        }
        println!();
    }

    // Normalize: C_norm(p,q) = C(p,q) / sqrt(C(p,p)·C(q,q))
    println!("\n  NORMALIZED (correlation matrix):\n");
    print!("       ");
    for q_ch in 1..=8 {
        print!("    p={q_ch:>2}   ");
    }
    println!();
    for p in 0..8 {
        print!("  p={} ", p + 1);
        for q_ch in 0..8 {
            let norm = (cross[p][p] * cross[q_ch][q_ch]).sqrt().max(1e-30);
            print!(" {:>9.6}", cross[p][q_ch] / norm);
        }
        println!();
    }

    // Eigenanalysis of 8×8 via spectral::full_eigen
    let cross_flat: Vec<f64> = (0..8)
        .flat_map(|i| (0..8).map(move |j| cross[i][j]))
        .collect();
    let (evals, _ground) = spectral::full_eigen(&cross_flat, 8);

    println!("\n  EIGENVALUES:");
    let total: f64 = evals.iter().map(|v| v.abs()).sum();
    for (i, ev) in evals.iter().enumerate() {
        println!(
            "    λ_{} = {:>14.8e}  ({:>5.1}%)",
            i + 1,
            ev,
            100.0 * ev.abs() / total
        );
    }

    // Dominant eigenvector — need full eigenvectors for this, so use nalgebra
    let mat8 = nalgebra::DMatrix::from_row_slice(8, 8, &cross_flat);
    let eig = mat8.symmetric_eigen();
    let max_idx = eig
        .eigenvalues
        .iter()
        .enumerate()
        .max_by(|(_, a), (_, b)| a.abs().partial_cmp(&b.abs()).unwrap())
        .unwrap()
        .0;
    let dom_evec: Vec<f64> = eig.eigenvectors.column(max_idx).iter().cloned().collect();
    println!("\n  DOMINANT EIGENVECTOR (channel weights):");
    for (i, v) in dom_evec.iter().enumerate() {
        let bar_len =
            (v.abs() / dom_evec.iter().map(|x| x.abs()).fold(0.0f64, f64::max) * 30.0) as usize;
        println!("    p={}: {:>8.5} {}", i + 1, v, "█".repeat(bar_len));
    }

    // Channel decay
    println!("\n  DIAGONAL DECAY:");
    for p in 0..8 {
        println!(
            "    C({},{}) = {:>12.6e}  (×{:.4} of C(1,1))",
            p + 1,
            p + 1,
            cross[p][p],
            cross[p][p] / cross[0][0].max(1e-30)
        );
    }

    // Quaternion vs Octonion sub-blocks
    let q4_trace: f64 = (0..4).map(|i| cross[i][i]).sum();
    let o8_trace: f64 = (0..8).map(|i| cross[i][i]).sum();
    let q4_off: f64 = (0..4)
        .flat_map(|p| {
            (0..4)
                .filter(move |&q_ch| q_ch != p)
                .map(move |q_ch| cross[p][q_ch].abs())
        })
        .sum();
    let o8_off: f64 = (0..8)
        .flat_map(|p| {
            (0..8)
                .filter(move |&q_ch| q_ch != p)
                .map(move |q_ch| cross[p][q_ch].abs())
        })
        .sum();

    println!("\n  QUATERNION vs OCTONION:");
    println!("    Trace(4×4): {q4_trace:.6e}  Off-diag: {q4_off:.6e}");
    println!("    Trace(8×8): {o8_trace:.6e}  Off-diag: {o8_off:.6e}");
    let extra_diag = 100.0 * (o8_trace - q4_trace) / q4_trace.max(1e-30);
    let extra_coupling = 100.0 * (o8_off - q4_off) / q4_off.max(1e-30);
    println!("    Extra diagonal: {extra_diag:.1}%");
    println!("    Extra coupling: {extra_coupling:.1}%");

    let elapsed = t0.elapsed().as_secs_f64();
    println!("\n  Total: {elapsed:.1}s");

    // Build normalized matrix
    let normalized: Vec<Vec<f64>> = (0..8)
        .map(|p| {
            (0..8)
                .map(|q_ch| {
                    let norm = (cross[p][p] * cross[q_ch][q_ch]).sqrt().max(1e-30);
                    cross[p][q_ch] / norm
                })
                .collect()
        })
        .collect();

    // Write TSV of cross matrix
    let dir = results_dir();
    let mut tsv = fs::File::create(dir.join(format!("exp4_cross_channel_N{n}.tsv")))
        .expect("Failed to create TSV");
    writeln!(tsv, "p1\tp2\tvalue\tnormalized").unwrap();
    for p in 0..8 {
        for q_ch in 0..8 {
            let norm = (cross[p][p] * cross[q_ch][q_ch]).sqrt().max(1e-30);
            writeln!(
                tsv,
                "{}\t{}\t{:.15e}\t{:.10}",
                p + 1,
                q_ch + 1,
                cross[p][q_ch],
                cross[p][q_ch] / norm
            )
            .unwrap();
        }
    }

    // Write eigenvalue TSV
    let mut etsv = fs::File::create(dir.join(format!("exp4_eigenvalues_N{n}.tsv")))
        .expect("Failed to create eigenvalue TSV");
    writeln!(etsv, "index\teigenvalue\tpct_total").unwrap();
    for (i, ev) in evals.iter().enumerate() {
        writeln!(
            etsv,
            "{}\t{:.15e}\t{:.6}",
            i + 1,
            ev,
            100.0 * ev.abs() / total
        )
        .unwrap();
    }

    Exp4Results {
        n,
        n_pts,
        cross_matrix_8x8: (0..8)
            .map(|p| (0..8).map(|q_ch| cross[p][q_ch]).collect())
            .collect(),
        normalized_matrix_8x8: normalized,
        eigenvalues: evals.clone(),
        dominant_eigenvector: dom_evec,
        diagonal_decay: (0..8).map(|p| cross[p][p]).collect(),
        quaternion_trace: q4_trace,
        octonion_trace: o8_trace,
        extra_diagonal_pct: extra_diag,
        extra_coupling_pct: extra_coupling,
        elapsed_seconds: elapsed,
    }
}

#[derive(Serialize)]
struct OctonionSummary {
    experiment: String,
    timestamp: String,
    n: usize,
    n_pts: usize,
    exp1: Exp1Results,
    exp2: Exp2Results,
    exp3: Exp3Results,
    exp4: Exp4Results,
    total_elapsed_seconds: f64,
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  OCTONIONIC GRAM MATRIX — BOTT PERIODICITY PROBE v2            ║");
    println!("║  4 experiments · Exploration 24                                 ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");

    let args: Vec<String> = std::env::args().collect();
    let n = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(200);
    let n_pts = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(100_000);

    eprintln!("  N={n}, quadrature points={n_pts}\n");
    let t_total = Instant::now();

    // Experiment 1: mod-8 residue (fast, exact Gram entries — runs at full N)
    let exp1 = experiment_1_mod8_residue(n);

    // Experiment 2: Block diagonal per-channel λ_min (capped at N=50)
    let n_bott = n.min(50);
    let exp2 = experiment_2_bott_block_diagonal(n_bott, n_pts);

    // Experiment 3: Coupled multi-channel spectral gap (capped at N=30)
    // This builds (C×dim)² matrices — expensive!
    let n_coupled = n.min(30);
    let exp3 = experiment_3_coupled_spectral_gap(n_coupled, n_pts);

    // Experiment 4: Cross-channel contraction (capped at N=100)
    let n_oct = n.min(100);
    let exp4 = experiment_4_cross_channel_contraction(n_oct, n_pts);

    let total_elapsed = t_total.elapsed().as_secs_f64();
    println!("\n═══ ALL EXPERIMENTS COMPLETE ({total_elapsed:.1}s) ═══");

    // Write combined summary JSON
    let summary = OctonionSummary {
        experiment: "Octonionic Gram Matrix — Bott Periodicity Probe v2".into(),
        timestamp: chrono_now(),
        n,
        n_pts,
        exp1,
        exp2,
        exp3,
        exp4,
        total_elapsed_seconds: total_elapsed,
    };

    let dir = results_dir();
    let json_path = dir.join(format!("summary_N{n}.json"));
    let json = serde_json::to_string_pretty(&summary).expect("JSON serialization failed");
    fs::write(&json_path, &json).expect("Failed to write summary JSON");
    println!("  📄 Results written to {}", json_path.display());
}

/// Simple ISO-ish timestamp without pulling in chrono crate.
fn chrono_now() -> String {
    use std::time::SystemTime;
    let d = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap();
    format!("unix:{}", d.as_secs())
}
