//! Standalone Gram matrix builder and cache utility.
//!
//! Usage:
//!   gram-builder <max_n> [--precision <bits>] [--force]
//!
//! Builds a Gram matrix for indices {2, ..., max_n}, caches to disk,
//! and validates against MPFR if applicable.

use cathedral_utils::cache;
use cathedral_utils::gram;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: gram-builder <max_n> [--precision <bits>] [--force]");
        eprintln!("  max_n:       Maximum N (matrix will be (N-1)×(N-1))");
        eprintln!("  --precision: MPFR precision bits (default: 512, 0 for f64)");
        eprintln!("  --force:     Rebuild even if cache exists");
        std::process::exit(1);
    }

    let max_n: usize = args[1].parse().expect("max_n must be a number");
    let precision: u32 = args
        .iter()
        .position(|a| a == "--precision")
        .and_then(|i| args.get(i + 1))
        .and_then(|s| s.parse().ok())
        .unwrap_or(512);
    let force = args.iter().any(|a| a == "--force");

    let cache_path = cache::gram_cache_path(max_n, precision);

    // Check cache first
    if !force {
        if let Some(cached) = cache::load_gram(&cache_path) {
            println!("  Gram matrix already cached (N={}, dim={}×{})",
                cached.max_n, cached.max_dim, cached.max_dim);
            println!("  Use --force to rebuild.");
            return;
        }
    }

    // Build
    let ln_table = if precision > 0 {
        let table_size = (max_n * 5).max(10_000);
        Some(gram::LnTable::with_precision(table_size, precision))
    } else {
        None
    };

    let matrix = gram::GramMatrix::build(max_n, ln_table.as_ref());
    println!("  Matrix: {}×{}, {} MB", matrix.max_dim, matrix.max_dim, matrix.mem_mb());

    // Validate if MPFR
    if ln_table.is_some() {
        for test_n in [50, 100, 200].iter().filter(|&&n| n <= max_n) {
            let (max_err, mean_err) = gram::validate_f64_vs_mpfr(*test_n, ln_table.as_ref().unwrap());
            println!("  N={test_n}: max_rel_err={max_err:.2e}, mean={mean_err:.2e}");
        }
    }

    // Cache to disk
    cache::save_gram(&cache_path, &matrix).expect("Failed to save cache");
    println!("  Cached: {}", cache_path.display());
}
