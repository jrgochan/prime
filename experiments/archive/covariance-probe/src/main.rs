#![allow(unused, dead_code)]
/// Covariance Matrix Probe — The Numerical Shadow of the Cathedral
///
/// Computes the Vasyunin covariance matrix C = G - bb^T and measures
/// the Nyman-Beurling distance d²_N = w^T C w for increasing N.
///
/// This is the computational incarnation of `millennium_covariance_cancellation`.
///
/// Usage:
///   cargo run --release
///   cargo run --release -- --max-n 500 --output results/
mod covariance;
mod gram;
mod moebius;
mod output;

use clap::Parser;
use std::path::PathBuf;
use std::time::Instant;

#[derive(Parser, Debug)]
#[command(
    name = "covariance-probe",
    about = "Probe the Vasyunin covariance matrix — the discrete skeleton of RH"
)]
struct Args {
    /// Maximum N to probe
    #[arg(long, default_value = "200")]
    max_n: usize,

    /// Output directory for results
    #[arg(long, default_value = "output")]
    output: PathBuf,

    /// Custom N values to probe (comma-separated, overrides default schedule)
    #[arg(long)]
    probe_ns: Option<String>,

    /// Number of rayon threads (0 = auto)
    #[arg(long, default_value = "0")]
    threads: usize,
}

fn main() {
    let args = Args::parse();

    // Configure rayon thread pool
    if args.threads > 0 {
        rayon::ThreadPoolBuilder::new()
            .num_threads(args.threads)
            .build_global()
            .expect("Failed to set thread count");
    }

    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║                   COVARIANCE MATRIX PROBE                       ║");
    println!("║        The Numerical Shadow of the Cathedral                    ║");
    println!("║                                                                 ║");
    println!("║  C = G - bb^T    (Schur complement — skeleton of RH)           ║");
    println!("║  d²_N = w^T·C·w  (Nyman-Beurling distance)                     ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
    println!();

    // Determine N values to probe
    let probe_ns: Vec<usize> = if let Some(ref custom) = args.probe_ns {
        custom
            .split(',')
            .filter_map(|s| s.trim().parse().ok())
            .collect()
    } else {
        // Default schedule: exponential growth
        let mut ns = vec![];
        for &n in &[
            5, 10, 15, 20, 30, 50, 75, 100, 150, 200, 300, 500, 750, 1000,
        ] {
            if n <= args.max_n {
                ns.push(n);
            }
        }
        ns
    };

    let max_n = *probe_ns.iter().max().unwrap_or(&100);

    // Step 1: Sieve Möbius function
    println!("  [1/3] Sieving μ(n) for n ≤ {} ...", max_n);
    let t0 = Instant::now();
    let mu = moebius::sieve_moebius(max_n);
    println!(
        "        ✓ Sieve complete in {:.2}ms. μ(1)={}, μ(2)={}, μ(6)={}",
        t0.elapsed().as_secs_f64() * 1000.0,
        mu[1],
        mu[2],
        mu[6]
    );
    println!();

    // Step 2: Probe each N
    println!("  [2/3] Probing covariance matrix for N ∈ {:?}", probe_ns);
    println!();
    println!(
        "  {:>6}  {:>18}  {:>12}  {:>14}  {:>10}",
        "N", "d²_N", "1/ln(N)", "d²·ln(N)", "time"
    );
    println!(
        "  {:>6}  {:>18}  {:>12}  {:>14}  {:>10}",
        "──────", "──────────────────", "────────────", "──────────────", "──────────"
    );

    let mut results = Vec::new();

    for &n in &probe_ns {
        let t = Instant::now();
        let result = if n > 500 {
            covariance::probe_fast(n, &mu)
        } else {
            covariance::probe(n, &mu)
        };
        let elapsed = t.elapsed();

        println!(
            "  {:>6}  {:>18.12e}  {:>12.8}  {:>14.10}  {:>8.1}ms",
            result.n,
            result.d_squared,
            result.inv_log_n,
            result.ratio,
            elapsed.as_secs_f64() * 1000.0,
        );

        results.push(result);
    }

    println!();

    // Step 3: Write outputs
    println!(
        "  [3/3] Writing output files to {} ...",
        args.output.display()
    );
    output::write_all_outputs(&results, &args.output);

    // Write eigenvalue files for selected N values
    for &n in &probe_ns {
        if (3..=200).contains(&n) {
            let g = covariance::build_gram_matrix(n);
            let b = covariance::build_mean_vector(n);
            let c = covariance::build_covariance(&g, &b);
            let eig = c.symmetric_eigen();
            let eigenvalues: Vec<f64> = eig.eigenvalues.iter().copied().collect();
            output::write_eigenvalue_spectrum(n, &eigenvalues, &args.output);
        }
    }

    println!();

    // Final summary
    println!("═══════════════════════════════════════════════════════════════════");
    println!("  RESULTS SUMMARY");
    println!("═══════════════════════════════════════════════════════════════════");
    println!();

    if results.len() >= 2 {
        let first = results.first().unwrap();
        let last = results.last().unwrap();
        let ratio_change = if first.d_squared > 0.0 {
            last.d_squared / first.d_squared
        } else {
            0.0
        };

        println!(
            "  d²_N decreased by factor {:.2}x from N={} to N={}",
            1.0 / ratio_change,
            first.n,
            last.n
        );

        // Check if d²·ln(N) is roughly constant (RH prediction)
        let ratios: Vec<f64> = results
            .iter()
            .filter(|r| r.n >= 10)
            .map(|r| r.ratio)
            .collect();
        if ratios.len() >= 2 {
            let avg = ratios.iter().sum::<f64>() / ratios.len() as f64;
            let std = (ratios.iter().map(|r| (r - avg).powi(2)).sum::<f64>() / ratios.len() as f64)
                .sqrt();
            println!("  d²·ln(N) mean = {:.8}, std = {:.8}", avg, std);
            println!(
                "  Coefficient of variation: {:.2}%",
                100.0 * std / avg.abs()
            );
        }
    }

    println!();
    println!("  Output files:");
    println!("    📊 {}/decay_data.tsv", args.output.display());
    println!("    📋 {}/summary.json", args.output.display());
    println!("    📝 {}/report.txt", args.output.display());
    println!("    🔬 {}/eigenvalues_N*.tsv", args.output.display());

    // Certificate output (Direction 5.1: Proof-Carrying Computation)
    let cert_dir = args.output.join("certificates");
    std::fs::create_dir_all(&cert_dir).unwrap();
    let cert_path = cert_dir.join("covariance_cert.json");
    let mut cert = std::fs::File::create(&cert_path).unwrap();
    use std::io::Write;
    writeln!(cert, "{{").unwrap();
    writeln!(cert, "  \"experiment\": \"Covariance Matrix Probe\",").unwrap();
    writeln!(
        cert,
        "  \"precision\": \"f64 (see certified.rs for 256-bit)\","
    )
    .unwrap();
    writeln!(cert, "  \"lean_bridge\": {{").unwrap();
    writeln!(
        cert,
        "    \"axiom\": \"millennium_covariance_cancellation\","
    )
    .unwrap();
    writeln!(
        cert,
        "    \"file\": \"Cathedral/Assembly/FinalDragon.lean\","
    )
    .unwrap();
    writeln!(cert, "    \"claim\": \"vᵀCv ≤ K/logN for Möbius witness\"").unwrap();
    writeln!(cert, "  }},").unwrap();
    writeln!(cert, "  \"decay_data\": [").unwrap();
    for (i, r) in results.iter().enumerate() {
        let comma = if i + 1 < results.len() { "," } else { "" };
        writeln!(
            cert,
            "    {{\"N\": {}, \"d_sq\": {:.15e}, \"inv_log_N\": {:.15e}, \"ratio\": {:.10}}}{}",
            r.n, r.d_squared, r.inv_log_n, r.ratio, comma
        )
        .unwrap();
    }
    writeln!(cert, "  ],").unwrap();
    writeln!(cert, "  \"verdicts\": {{").unwrap();
    let d_sq_decreasing = results.windows(2).all(|w| w[1].d_squared <= w[0].d_squared);
    let ratio_stable = {
        let rats: Vec<f64> = results
            .iter()
            .filter(|r| r.n >= 10)
            .map(|r| r.ratio)
            .collect();
        let avg = rats.iter().sum::<f64>() / rats.len() as f64;
        let std = (rats.iter().map(|r| (r - avg).powi(2)).sum::<f64>() / rats.len() as f64).sqrt();
        std / avg.abs() < 0.1
    };
    writeln!(cert, "    \"d_sq_decreasing\": {},", d_sq_decreasing).unwrap();
    writeln!(cert, "    \"ratio_d_sq_logN_stable\": {},", ratio_stable).unwrap();
    writeln!(
        cert,
        "    \"consistent_with_1_over_logN_decay\": {}",
        ratio_stable
    )
    .unwrap();
    writeln!(cert, "  }}").unwrap();
    writeln!(cert, "}}").unwrap();
    println!("    📜 {}", cert_path.display());

    println!();
    println!("  The matrix has spoken. 🏛️");
    println!();
}
