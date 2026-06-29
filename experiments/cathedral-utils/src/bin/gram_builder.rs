#![allow(
    dead_code,
    unused_variables,
    clippy::needless_range_loop,
    clippy::empty_line_after_doc_comments,
    clippy::doc_lazy_continuation
)]
//! Standalone Gram matrix builder and cache utility.
//!
//! Usage:
//!   gram-builder <max_n> [--precision <bits|dd>] [--force]
//!
//! Precision modes:
//!   --precision 0     f64 (Kahan summation, fastest, breaks ~N>500)
//!   --precision dd    Double-double (~31 digits, pure Rust, ~5-10x faster than MPFR)
//!   --precision 128   128-bit MPFR (~38 digits)
//!   --precision 256   256-bit MPFR (~77 digits)
//!   --precision 512   512-bit MPFR (~154 digits, default for archival)

use cathedral_utils::cache;
use cathedral_utils::gram;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: gram-builder <max_n> [--precision <bits|dd>] [--force]");
        eprintln!("  max_n:       Maximum N (matrix will be (N-1)×(N-1))");
        eprintln!("  --precision: 'dd' for double-double, or MPFR bits (default: dd)");
        eprintln!("  --force:     Rebuild even if cache exists");
        std::process::exit(1);
    }

    let max_n: usize = args[1].parse().expect("max_n must be a number");
    let force = args.iter().any(|a| a == "--force");

    let prec_str = args
        .iter()
        .position(|a| a == "--precision")
        .and_then(|i| args.get(i + 1))
        .map(|s| s.as_str())
        .unwrap_or("dd");

    let use_dd = prec_str == "dd";
    let precision: u32 = if use_dd {
        106
    } else {
        prec_str.parse().unwrap_or(512)
    };

    let cache_path = cache::gram_cache_path(max_n, precision);

    // Check cache first
    if !force {
        if let Some(cached) = cache::load_gram(&cache_path) {
            println!(
                "  Gram matrix already cached (N={}, dim={}×{})",
                cached.max_n, cached.max_dim, cached.max_dim
            );
            println!("  Use --force to rebuild.");
            return;
        }
    }

    // Build
    let matrix = if use_dd {
        let table_size = (max_n * 5).max(10_000);
        let dd_table = gram::DDLnTable::new(table_size);
        gram::GramMatrix::build_dd(max_n, &dd_table)
    } else if precision > 0 {
        let table_size = (max_n * 5).max(10_000);
        let ln_table = gram::LnTable::with_precision(table_size, precision);
        let matrix = gram::GramMatrix::build(max_n, Some(&ln_table));

        // Validate MPFR vs f64
        for test_n in [50, 100, 200].iter().filter(|&&n| n <= max_n) {
            let (max_err, mean_err) = gram::validate_f64_vs_mpfr(*test_n, &ln_table);
            println!("  N={test_n}: max_rel_err={max_err:.2e}, mean={mean_err:.2e}");
        }
        matrix
    } else {
        gram::GramMatrix::build(max_n, None)
    };

    println!(
        "  Matrix: {}×{}, {} MB",
        matrix.max_dim,
        matrix.max_dim,
        matrix.mem_mb()
    );

    // Cache to disk
    cache::save_gram(&cache_path, &matrix).expect("Failed to save cache");
    println!("  Cached: {}", cache_path.display());
}
