#![allow(
    dead_code,
    unused_variables,
    unused_imports,
    unused_assignments,
    clippy::needless_range_loop,
    clippy::doc_lazy_continuation,
    non_snake_case,
    clippy::empty_line_after_doc_comments
)]
// overcancellation-scan/src/bin/double_abel_probe.rs
//
// ╔═══════════════════════════════════════════════════════════════════════╗
// ║  DOUBLE ABEL PROBE — Computing the Two Key Constants                ║
// ║                                                                       ║
// ║  For the double Abel bound: |vtGv| ≤ max|A(M)| × (C_inner + TV)    ║
// ║                                                                       ║
// ║  Computes:                                                            ║
// ║    1. max_M |A(M)| — max partial sum of tapered Mertens               ║
// ║    2. C_inner — max_k |inner_k| (inner Abel bound)                    ║
// ║    3. TV(inner) — total variation of inner products                    ║
// ║    4. PRODUCT = max|A| × (C_inner + TV) — THE BOUND                   ║
// ║                                                                       ║
// ║  If PRODUCT ≤ 1, the double Abel CLOSES and vtGv ≤ 1 is provable!    ║
// ║                                                                       ║
// ║  Cathedral — The Double Abel Probe 🔬⚡                                ║
// ║  June 2, 2026                                                         ║
// ╚═══════════════════════════════════════════════════════════════════════╝

use cathedral_utils::hpdf::HpdfReader;
use rayon::prelude::*;
use std::f64::consts::PI;
use std::path::PathBuf;

const EULER_GAMMA: f64 = 0.5772156649015329;

fn sieve_mobius(n: usize) -> Vec<i8> {
    let mut mu = vec![0i8; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n {
                break;
            }
            is_prime[i * p] = false;
            if i % p == 0 {
                mu[i * p] = 0;
                break;
            } else {
                mu[i * p] = -mu[i];
            }
        }
    }
    mu
}

fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 {
        return 0.0;
    }
    let af = a as f64;
    let mut s = 0.0;
    for m in 1..a {
        let angle = PI * m as f64 / af;
        let sin_v = angle.sin();
        if sin_v.abs() < 1e-15 {
            continue;
        }
        let cot = angle.cos() / sin_v;
        let frac = ((m * b) as f64 / af).fract();
        s += cot * frac;
    }
    s
}

fn gram_entry_k1(k: usize) -> f64 {
    let c = (2.0 * PI).ln() - EULER_GAMMA;
    if k == 1 {
        return c - 1.0;
    }
    let kf = k as f64;
    let t1 = c / 2.0 * (1.0 + 1.0 / kf);
    let t2 = (1.0 - kf) / (2.0 * kf) * kf.ln();
    let vk1 = vasyunin_sum(k, 1);
    let t3 = PI / (2.0 * kf) * vk1;
    let t4 = 1.0 / kf;
    t1 + t2 - t3 - t4
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════════════════╗");
    println!("║  DOUBLE ABEL PROBE — The Two Key Constants                    🔬⚡        ║");
    println!("║  |vtGv| ≤ max|A(M)| × (C_inner + TV_outer)                              ║");
    println!("║  Cathedral — Does the product ≤ 1?                                        ║");
    println!("╚═══════════════════════════════════════════════════════════════════════════╝");
    println!();

    let cache_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .join("cache/hpdf");

    let hc_ns: Vec<usize> = vec![
        60, 120, 240, 360, 840, 1260, 2520, 5040, 7560, 10080, 20160, 27720, 45360, 55440,
    ];

    println!("═══ DOUBLE ABEL CONSTANTS (Fejér-Möbius weights) ═══");
    println!();
    println!(
        "  {:>6} │ {:>10} {:>10} {:>10} {:>10} │ {:>10} {:>10} │ {:>6}",
        "N", "max|A(M)|", "C_inner", "TV_outer", "C+TV", "PRODUCT", "vtGv", "≤1?"
    );
    println!(
        "  {}─┼─{} {} {} {}─┼─{} {}─┼─{}",
        "─".repeat(6),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(6)
    );

    for &n in &hc_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() {
            continue;
        }

        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("  [skip] N={}: {}", n, e);
                continue;
            }
        };

        let dim = reader.dim();
        let mu_raw = reader.read_mobius().unwrap_or_else(|_| sieve_mobius(n));
        let gram = match reader.read_gram_full() {
            Ok(g) => g,
            Err(e) => {
                eprintln!("  [skip] N={}: {}", n, e);
                continue;
            }
        };

        let log_n = (n as f64).ln();

        // Build Fejér-Möbius weight vector for k=2..N
        let mut v2 = vec![0.0f64; dim];
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            let mu_k = mu_raw[k] as f64;
            let w = 1.0 - (k as f64).ln() / log_n;
            v2[i] = -mu_k * w;
        }
        let v1: f64 = -(mu_raw[1] as f64) * 1.0; // k=1: w=1

        // ════════════════════════════════════════════
        // 1. max_M |A(M)| — tapered Mertens partial sums
        // ════════════════════════════════════════════
        // A(M) = Σ_{k=1}^M v_k = v1 + Σ_{k=2}^M v2[k-2]
        let mut max_partial = 0.0f64;
        let mut partial_sum = v1;
        if partial_sum.abs() > max_partial {
            max_partial = partial_sum.abs();
        }
        // Track where max occurs
        let mut max_m = 1usize;
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            partial_sum += v2[i];
            if partial_sum.abs() > max_partial {
                max_partial = partial_sum.abs();
                max_m = k;
            }
        }

        // ════════════════════════════════════════════
        // 2. inner_k = Σ_j v_j · G(j,k) — for all k
        // ════════════════════════════════════════════

        // Inner products for k≥2 (from HPDF matrix, parallel)
        let inner_k2: Vec<f64> = (0..dim)
            .into_par_iter()
            .map(|ki| {
                let mut s = 0.0f64;
                for ji in 0..dim {
                    s += v2[ji] * gram[ji * dim + ki];
                }
                // Add v1 * G(1,k) contribution
                let k = ki + 2;
                if k < n {
                    s += v1 * gram_entry_k1(k);
                }
                s
            })
            .collect();

        // Inner product for k=1
        let mut inner_k1 = v1 * gram_entry_k1(1);
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            inner_k1 += v2[i] * gram_entry_k1(k);
        }

        // Build full inner vector: inner[0] = inner_k1, inner[1..] = inner_k2
        let mut inner = Vec::with_capacity(n);
        inner.push(inner_k1);
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            inner.push(inner_k2[i]);
        }

        // ════════════════════════════════════════════
        // 3. C_inner = max_k |inner_k|
        // ════════════════════════════════════════════
        let c_inner = inner.iter().map(|x| x.abs()).fold(0.0f64, f64::max);

        // ════════════════════════════════════════════
        // 4. TV(inner) = Σ_k |inner_{k+1} - inner_k|
        // ════════════════════════════════════════════
        let mut tv_outer = 0.0f64;
        let mut max_jump = 0.0f64;
        let mut max_jump_k = 0usize;
        for i in 0..inner.len() - 1 {
            let jump = (inner[i + 1] - inner[i]).abs();
            tv_outer += jump;
            if jump > max_jump {
                max_jump = jump;
                max_jump_k = i + 1;
            }
        }

        // ════════════════════════════════════════════
        // 5. vtGv (actual)
        // ════════════════════════════════════════════
        let mut vtgv = v1 * inner_k1;
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            vtgv += v2[i] * inner_k2[i];
        }

        // ════════════════════════════════════════════
        // THE PRODUCT: max|A| × (C_inner + TV)
        // ════════════════════════════════════════════
        let c_plus_tv = c_inner + tv_outer;
        let product = max_partial * c_plus_tv;
        let check = if product <= 1.0 { " ✅" } else { " ❌" };

        println!(
            "  {:>6} │ {:>10.4} {:>10.4} {:>10.4} {:>10.4} │ {:>10.4} {:>10.4} │ {}",
            n, max_partial, c_inner, tv_outer, c_plus_tv, product, vtgv, check
        );

        // Detailed breakdown for select N values
        if n == 2520 || n == 10080 || n == 55440 {
            println!(
                "         │ max|A| at M={}, max jump at k={} (Δ={:.6})",
                max_m, max_jump_k, max_jump
            );
            println!("         │ A(N) = {:.6} (final partial sum)", partial_sum);
            println!(
                "         │ inner[1] = {:.6}, inner[N-1] = {:.6}",
                inner[0],
                inner[inner.len() - 1]
            );
        }
    }

    // ════════════════════════════════════════════
    // Alternative: tight outer Abel (not using TV)
    // ════════════════════════════════════════════
    println!();
    println!("═══ ALTERNATIVE: Outer Abel by Parts (SBP formula) ═══");
    println!();
    println!("  The Abel summation by parts formula gives:");
    println!("  |Σ_k v_k · inner_k| ≤ max|A(M)| × (|inner_last| + TV)");
    println!("  but also:");
    println!("  |Σ_k v_k · inner_k| = |A(N)·inner_N - Σ_k A(k)·Δinner_k|");
    println!("  ≤ |A(N)|·|inner_N| + max|A(M)| × TV");
    println!();
    println!("  Since A(N) → 0 (FejerCesaro), the first term vanishes!");
    println!("  So effectively: |vtGv| ≤ ε(N)·|inner_N| + max|A|·TV");
    println!();

    // Recompute with SBP formula
    println!(
        "  {:>6} │ {:>10} {:>10} {:>10} {:>10} │ {:>10} {:>6}",
        "N", "|A(N)|", "|inner_N|", "max|A|", "TV", "SBP bound", "≤1?"
    );
    println!(
        "  {}─┼─{} {} {} {}─┼─{} {}",
        "─".repeat(6),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(10),
        "─".repeat(6)
    );

    for &n in &hc_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() {
            continue;
        }

        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("  [skip] N={}: {}", n, e);
                continue;
            }
        };

        let dim = reader.dim();
        let mu_raw = reader.read_mobius().unwrap_or_else(|_| sieve_mobius(n));
        let gram = match reader.read_gram_full() {
            Ok(g) => g,
            Err(e) => {
                eprintln!("  [skip] N={}: {}", n, e);
                continue;
            }
        };

        let log_n = (n as f64).ln();

        let mut v2 = vec![0.0f64; dim];
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            v2[i] = -(mu_raw[k] as f64) * (1.0 - (k as f64).ln() / log_n);
        }
        let v1 = -(mu_raw[1] as f64);

        // Partial sums
        let mut max_partial = 0.0f64;
        let mut partial_sum = v1;
        if partial_sum.abs() > max_partial {
            max_partial = partial_sum.abs();
        }
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            partial_sum += v2[i];
            if partial_sum.abs() > max_partial {
                max_partial = partial_sum.abs();
            }
        }
        let a_final = partial_sum.abs();

        // Inner products (parallel)
        let inner_k2: Vec<f64> = (0..dim)
            .into_par_iter()
            .map(|ki| {
                let mut s = 0.0f64;
                for ji in 0..dim {
                    s += v2[ji] * gram[ji * dim + ki];
                }
                let k = ki + 2;
                if k < n {
                    s += v1 * gram_entry_k1(k);
                }
                s
            })
            .collect();

        let mut inner_k1_val = v1 * gram_entry_k1(1);
        for i in 0..dim {
            let k = i + 2;
            if k >= n {
                break;
            }
            inner_k1_val += v2[i] * gram_entry_k1(k);
        }

        let mut inner = Vec::with_capacity(n);
        inner.push(inner_k1_val);
        for val in &inner_k2 {
            inner.push(*val);
        }

        let inner_last = inner.last().copied().unwrap_or(0.0).abs();

        let mut tv = 0.0f64;
        for i in 0..inner.len() - 1 {
            tv += (inner[i + 1] - inner[i]).abs();
        }

        // SBP bound: |A(N)|·|inner_N| + max|A|·TV
        let sbp_bound = a_final * inner_last + max_partial * tv;
        let check = if sbp_bound <= 1.0 { " ✅" } else { " ❌" };

        println!(
            "  {:>6} │ {:>10.6} {:>10.4} {:>10.4} {:>10.4} │ {:>10.4} {}",
            n, a_final, inner_last, max_partial, tv, sbp_bound, check
        );
    }

    println!();
    println!("═══════════════════════════════════════════════════════════════════════════");
    println!("  If PRODUCT ≤ 1: Double Abel CLOSES → vtGv ≤ 1 → RH! 🏰");
    println!("═══════════════════════════════════════════════════════════════════════════");
}
