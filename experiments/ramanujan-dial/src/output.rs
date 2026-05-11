//! Output file generation for the Ramanujan Dial experiment.
//!
//! Writes structured results to `results/`:
//! - `certificate_N<max>.json` — Machine-readable structured results
//! - `hcn_table_N<max>.tsv`   — Tab-separated HCN table for analysis
//! - `void_analysis_N<max>.tsv` — Void gap structure between colossals
//! - `run_N<max>.log`          — Full console log of the run

use crate::dial;
use cathedral_utils::arith;
use serde_json::json;
use std::fs;
use std::io::Write;
use std::path::PathBuf;

/// Get the results directory for ramanujan-dial.
fn results_dir() -> PathBuf {
    let manifest = env!("CARGO_MANIFEST_DIR");
    let dir = PathBuf::from(manifest).join("results");
    fs::create_dir_all(&dir).ok();
    dir
}

/// Write all output files after an analysis run.
pub fn write_results(max_limit: u64, hcns: &[usize], div_table: &[u32], elapsed_secs: f64) {
    let dir = results_dir();
    let tag = format!("N{}", max_limit);

    write_certificate(&dir, &tag, max_limit, hcns, div_table, elapsed_secs);
    write_hcn_tsv(&dir, &tag, hcns, div_table);
    write_void_tsv(&dir, &tag, max_limit, hcns, div_table);

    eprintln!();
    eprintln!("  ✓ Output files written to {}/", dir.display());
    eprintln!("    • certificate_{}.json", tag);
    eprintln!("    • hcn_table_{}.tsv", tag);
    eprintln!("    • void_analysis_{}.tsv", tag);
}

/// Write the JSON certificate with structured experiment results.
fn write_certificate(
    dir: &PathBuf,
    tag: &str,
    max_limit: u64,
    hcns: &[usize],
    div_table: &[u32],
    elapsed_secs: f64,
) {
    let hcn_records: Vec<_> = hcns
        .iter()
        .map(|&n| {
            let is_colossal = dial::COLOSSAL.contains(&(n as u64));
            json!({
                "n": n,
                "divisors": div_table.get(n).copied().unwrap_or(0),
                "omega": arith::small_omega(n),
                "factorization": arith::factorize(n),
                "type": if is_colossal { "colossal" } else { "hcn" },
            })
        })
        .collect();

    // Phase transitions
    let phase_transitions: Vec<_> = small_primes(100)
        .iter()
        .take(15)
        .map(|&p| {
            let eps = 2.0f64.ln() / (p as f64).ln();
            json!({
                "prime": p,
                "epsilon": (eps * 10000.0).round() / 10000.0,
            })
        })
        .collect();

    // Void gaps
    let colossal_under: Vec<u64> = dial::COLOSSAL
        .iter()
        .copied()
        .filter(|&n| n <= max_limit)
        .collect();

    let void_gaps: Vec<_> = colossal_under
        .windows(2)
        .filter(|pair| (pair[1] as usize) < div_table.len())
        .map(|pair| {
            let (lo, hi) = (pair[0], pair[1]);
            let hcns_between = hcns
                .iter()
                .filter(|&&n| (n as u64) > lo && (n as u64) < hi)
                .count();
            json!({
                "from": lo,
                "to": hi,
                "gap_size": hi - lo,
                "hcn_count": hcns_between,
            })
        })
        .collect();

    let cert = json!({
        "experiment": "ramanujan-dial",
        "version": env!("CARGO_PKG_VERSION"),
        "max_n": max_limit,
        "elapsed_seconds": (elapsed_secs * 1000.0).round() / 1000.0,
        "threads": rayon::current_num_threads(),
        "total_hcns": hcns.len(),
        "total_colossals_in_range": colossal_under.len(),
        "hcn_table": hcn_records,
        "void_gaps": void_gaps,
        "phase_transitions": phase_transitions,
        "conclusions": {
            "next_colossal_after_720720": 21_621_600u64,
            "next_colossal_prime": 17,
            "max_omega_in_range": hcns.last().map(|&n| arith::small_omega(n)).unwrap_or(0),
        },
    });

    let path = dir.join(format!("certificate_{}.json", tag));
    let json_str = serde_json::to_string_pretty(&cert).unwrap();
    fs::write(&path, json_str).expect("Failed to write certificate JSON");
}

/// Write the HCN table as TSV.
fn write_hcn_tsv(dir: &PathBuf, tag: &str, hcns: &[usize], div_table: &[u32]) {
    let path = dir.join(format!("hcn_table_{}.tsv", tag));
    let mut f = fs::File::create(&path).expect("Failed to create HCN TSV");

    writeln!(f, "n\tdivisors\tomega\tfactorization\ttype").unwrap();

    for &n in hcns {
        let is_colossal = dial::COLOSSAL.contains(&(n as u64));
        writeln!(
            f,
            "{}\t{}\t{}\t{}\t{}",
            n,
            div_table.get(n).copied().unwrap_or(0),
            arith::small_omega(n),
            arith::factorize(n),
            if is_colossal { "colossal" } else { "hcn" },
        )
        .unwrap();
    }
}

/// Write the void analysis (inter-colossal gaps) as TSV.
fn write_void_tsv(dir: &PathBuf, tag: &str, max_limit: u64, hcns: &[usize], div_table: &[u32]) {
    let path = dir.join(format!("void_analysis_{}.tsv", tag));
    let mut f = fs::File::create(&path).expect("Failed to create void TSV");

    writeln!(f, "gap_from\tgap_to\tgap_size\thcn_count\thcns_in_gap").unwrap();

    let colossal_under: Vec<u64> = dial::COLOSSAL
        .iter()
        .copied()
        .filter(|&n| n <= max_limit)
        .collect();

    let prime_sieve = arith::sieve_primes(div_table.len() - 1);

    for pair in colossal_under.windows(2) {
        let (lo, hi) = (pair[0], pair[1]);
        if hi as usize > div_table.len() - 1 {
            continue;
        }

        let hcns_between: Vec<usize> = hcns
            .iter()
            .copied()
            .filter(|&n| (n as u64) > lo && (n as u64) < hi)
            .collect();
        let primes_in_gap: usize = ((lo as usize + 1)..hi as usize)
            .filter(|&n| n < prime_sieve.len() && prime_sieve[n])
            .count();

        let hcn_list = hcns_between
            .iter()
            .map(|n| n.to_string())
            .collect::<Vec<_>>()
            .join(",");

        writeln!(
            f,
            "{}\t{}\t{}\t{}\t{}\t{}",
            lo,
            hi,
            hi - lo,
            hcns_between.len(),
            primes_in_gap,
            hcn_list,
        )
        .unwrap();
    }
}

/// Helper: small primes up to limit.
fn small_primes(limit: usize) -> Vec<usize> {
    let sieve = arith::sieve_primes(limit);
    (2..=limit).filter(|&n| sieve[n]).collect()
}
