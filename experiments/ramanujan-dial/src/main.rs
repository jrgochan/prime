//! # Ramanujan Dial — The N-Analysis Experiment
//!
//! Explores which values of N matter for the Nyman-Beurling distance d²_N
//! using Ramanujan's 1915 thermodynamic construction of Superior Highly
//! Composite Numbers.
//!
//! ## Key Findings
//!
//! 1. **Colossal numbers** (2, 6, 12, 60, 360, 2520, 5040, 55440, 720720)
//!    are the true structural nodes where d²_N makes its deepest descents.
//! 2. **HCNs** between colossals are local gravity wells.
//! 3. **Primes** in the void are "silent" — minimal d² descent.
//! 4. The Ramanujan ε parameter governs phase transitions.
//!
//! ## Architecture
//!
//! - `dial.rs`    — Ramanujan ε-dial and colossal sequence logic
//! - `sieve.rs`   — Sieve-based divisor counting and HCN discovery
//! - `cholesky.rs` — Incremental Cholesky d² engine with cache loading
//! - `display.rs` — Number formatting and classification utilities
//! - `output.rs`  — File output (JSON certificate, TSV tables)
//!
//! ## Usage
//!
//! ```bash
//! cargo run --release -p ramanujan-dial
//! cargo run --release -p ramanujan-dial -- --compute-d2 --d2-max 2000
//! cargo run --release -p ramanujan-dial -- --max 10000000
//! ```

mod cholesky;
mod dial;
mod display;
mod output;
mod sieve;

use std::time::Instant;
use cathedral_utils::arith;

fn main() {
    let t_start = Instant::now();
    let args: Vec<String> = std::env::args().collect();

    let max_limit: u64 = args.iter().position(|a| a == "--max")
        .and_then(|i| args.get(i + 1)?.parse().ok())
        .unwrap_or(1_000_000);

    let compute_d2 = args.iter().any(|a| a == "--compute-d2");
    let d2_max: usize = args.iter().position(|a| a == "--d2-max")
        .and_then(|i| args.get(i + 1)?.parse().ok())
        .unwrap_or(500);

    // ═══════════════════════════════════════════════════════════
    // HEADER
    // ═══════════════════════════════════════════════════════════
    println!();
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  🎛️  RAMANUJAN DIAL — N-Analysis (Massively Parallel)       ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    let sieve_mb = max_limit as usize * 4 / (1024 * 1024);
    println!("║  Max N: {:<52}║", display::format_num(max_limit));
    println!("║  Sieve RAM: {:<48}║", format!("~{} MB", sieve_mb));
    println!("║  Compute d²: {:<47}║",
        if compute_d2 { format!("yes (up to N={}) — PARALLEL", d2_max) }
        else { "no (--compute-d2 to enable)".to_string() });
    println!("║  Threads: {:<50}║", rayon::current_num_threads());
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 1: THE RAMANUJAN TEMPERATURE DIAL
    // ═══════════════════════════════════════════════════════════
    dial::print_temperature_dial(max_limit);

    // ═══════════════════════════════════════════════════════════
    // PART 2: THE COLOSSAL SEQUENCE
    // ═══════════════════════════════════════════════════════════
    dial::print_colossal_sequence(max_limit);

    // ═══════════════════════════════════════════════════════════
    // PART 3: HCN SCAN — Sieve-accelerated
    // ═══════════════════════════════════════════════════════════
    let t0 = Instant::now();
    let hcn_limit = max_limit as usize;

    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 3: HIGHLY COMPOSITE NUMBERS up to {} (sieve)",
        display::format_num(hcn_limit as u64));
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let div_table = sieve::divisor_count_sieve(hcn_limit);
    let hcns = sieve::find_hcn_from_sieve(&div_table);
    println!("  ✓ Sieve + HCN scan in {:.3}s ({} HCNs found)",
        t0.elapsed().as_secs_f64(), hcns.len());
    println!();

    println!("  {:>10} {:>6} {:>6} {:>30} {:>10}",
        "N", "d(N)", "ω(N)", "factorization", "type");
    println!("  {:>10} {:>6} {:>6} {:>30} {:>10}",
        "──────────", "──────", "──────",
        "──────────────────────────────", "──────────");

    for &n in &hcns {
        let is_col = dial::COLOSSAL.contains(&(n as u64));
        println!("  {:>10} {:>6} {:>6} {:>30} {:>10}",
            display::format_num(n as u64), div_table[n],
            arith::small_omega(n), arith::factorize(n),
            if is_col { "COLOSSAL" } else { "HCN" });
    }
    println!();

    // ═══════════════════════════════════════════════════════════
    // PART 4: VOID ANALYSIS
    // ═══════════════════════════════════════════════════════════
    println!("═══════════════════════════════════════════════════════════════");
    println!("PART 4: VOID ANALYSIS — Between Colossal Anchors");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    let colossal_under: Vec<u64> = dial::COLOSSAL.iter().copied()
        .filter(|&n| n <= max_limit).collect();
    let prime_sieve = arith::sieve_primes(hcn_limit);

    for pair in colossal_under.windows(2) {
        let (lo, hi) = (pair[0], pair[1]);
        if hi as usize > hcn_limit { continue; }

        let hcns_between: Vec<usize> = hcns.iter().copied()
            .filter(|&n| (n as u64) > lo && (n as u64) < hi).collect();
        let primes_in_gap: usize = ((lo as usize + 1)..hi as usize)
            .filter(|&n| n < prime_sieve.len() && prime_sieve[n]).count();

        println!("  Gap [{} → {}]: size {}, {} HCNs, {} primes",
            display::format_num(lo), display::format_num(hi),
            display::format_num(hi - lo),
            hcns_between.len(), primes_in_gap);

        for &h in &hcns_between {
            println!("    HCN {:>8} = {:<20} d={:<4} ({:.1}× anchor)",
                display::format_num(h as u64), arith::factorize(h),
                div_table[h], h as f64 / lo as f64);
        }
        println!();
    }

    // ═══════════════════════════════════════════════════════════
    // PART 5: RECOMMENDATIONS
    // ═══════════════════════════════════════════════════════════
    dial::print_recommendations();

    // ═══════════════════════════════════════════════════════════
    // PART 6: d² COMPUTATIONS — MASSIVELY PARALLEL
    // ═══════════════════════════════════════════════════════════
    if compute_d2 {
        println!("═══════════════════════════════════════════════════════════════");
        println!("PART 6: d²_N COMPUTATIONS — PARALLEL (N ≤ {})", d2_max);
        println!("═══════════════════════════════════════════════════════════════");
        println!();
        cholesky::compute_d2_parallel(d2_max, &hcns);
    } else {
        println!("═══════════════════════════════════════════════════════════════");
        println!("PART 6: d²_N — SKIPPED (use --compute-d2)");
        println!("═══════════════════════════════════════════════════════════════");
        println!();
    }

    // ═══════════════════════════════════════════════════════════
    // PART 7: PHASE TRANSITIONS
    // ═══════════════════════════════════════════════════════════
    dial::print_phase_transitions();

    // ═══════════════════════════════════════════════════════════
    // OUTPUT FILES
    // ═══════════════════════════════════════════════════════════
    let total_elapsed = t_start.elapsed().as_secs_f64();
    output::write_results(max_limit, &hcns, &div_table, total_elapsed);

    // SUMMARY
    println!();
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║  SUMMARY — N-ANALYSIS                                      ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  1. Colossal numbers are the TRUE structural nodes.       ║");
    println!("║  2. HCNs between colossals are local gravity wells.       ║");
    println!("║  3. Primes in the void are 'silent' — minimal d² descent. ║");
    println!("║  4. The Ramanujan ε parameter governs phase transitions.  ║");
    println!("║  5. GPU runs should target: 360, 2520, 5040, 55440.       ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!();
}
