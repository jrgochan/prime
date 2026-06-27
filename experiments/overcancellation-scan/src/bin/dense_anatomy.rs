#![allow(clippy::needless_range_loop, dead_code, non_snake_case)]
// overcancellation-scan/src/bin/dense_anatomy.rs
//
// ╔═══════════════════════════════════════════════════════════════════════╗
// ║  DENSE ANATOMY v2 — The Complete Probe                               ║
// ║                                                                       ║
// ║  Computes for N = 3..N_MAX (every integer!):                         ║
// ║    • vtGv, vtB₁v, vtL₁v, bᵀv, d², ratio                            ║
// ║    • L₁ decomposition: ratio_term, -eCot, logHarm, rank1            ║
// ║    • Growth rates: vtGv/lnN, vtGv/lnlnN, Δ(vtGv)/Δ(lnN)           ║
// ║    • PNT sums: Σμ/k, Σμ·env/k (Mertens convergence)                ║
// ║    • Double Abel: max|A(M)|, C_inner, TV(inner)                      ║
// ║    • GCD strata, Ramanujan, divisor, Euler φ decompositions          ║
// ║    • ||v||², n_active, coprime/non-coprime L₁                       ║
// ║    • Flags: HCN, prime, prime power                                   ║
// ║                                                                       ║
// ║  Usage: dense-anatomy [N_MAX]  (default 3000)                         ║
// ║  Output: TSV with periodic flush for remote monitoring                ║
// ║  Cathedral — June 3, 2026                                             ║
// ╚═══════════════════════════════════════════════════════════════════════╝

use rayon::prelude::*;
use std::collections::HashMap;
use std::f64::consts::PI;
use std::fs;
use std::io::Write;
use std::time::Instant;

const EULER_GAMMA: f64 = 0.5772156649015329;
const LN_2PI: f64 = 1.8378770664093453;
const COEFF: f64 = LN_2PI - EULER_GAMMA;  // ln(2π) - γ ≈ 1.2606

fn sieve_mobius(n: usize) -> (Vec<i8>, Vec<usize>) {
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
            if i * p > n { break; }
            is_prime[i * p] = false;
            if i % p == 0 { mu[i * p] = 0; break; }
            else { mu[i * p] = -mu[i]; }
        }
    }
    (mu, primes)
}

fn gcd(mut a: usize, mut b: usize) -> usize {
    while b != 0 { let t = b; b = a % b; a = t; } a
}

fn vasyunin_sum(a: usize, b: usize) -> f64 {
    if a <= 1 { return 0.0; }
    let af = a as f64;
    let bf = b as f64;
    let mut total = 0.0;
    for m in 1..a {
        let mf = m as f64;
        let mut frac_part = (mf * bf / af).fract();
        if frac_part < 0.0 { frac_part += 1.0; }
        let angle = PI * mf / af;
        let sin_val = angle.sin();
        if sin_val.abs() < 1e-15 { continue; }
        total += frac_part * angle.cos() / sin_val;
    }
    total
}

fn gram_diagonal(j: usize) -> f64 {
    let jf = j as f64;
    COEFF / jf - 1.0 / (jf * jf)
}

fn gram_offdiag(j: usize, k: usize, pair_sums: &HashMap<(usize, usize), f64>) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let d = gcd(j, k);
    let jp = j / d;
    let kp = k / d;
    let term1 = COEFF / 2.0 * (1.0 / jf + 1.0 / kf);
    let term2 = (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();
    let key = if jp <= kp { (jp, kp) } else { (kp, jp) };
    let ps = pair_sums.get(&key).copied().unwrap_or(0.0);
    let term3 = PI * (d as f64) / (2.0 * jf * kf) * ps;
    let term4 = 1.0 / (jf * kf);
    term1 + term2 - term3 - term4
}

fn b1_entry(j: usize, k: usize) -> f64 {
    let d = gcd(j, k) as f64;
    d * d / (12.0 * j as f64 * k as f64)
}

fn mean_entry(k: usize) -> f64 {
    let kf = k as f64;
    (kf.ln() + 1.0 - EULER_GAMMA) / kf
}

fn precompute_pair_sums(n: usize, mu: &[i8]) -> HashMap<(usize, usize), f64> {
    let mut needed = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for j in 1..n {
        if mu[j] == 0 { continue; }
        for k in 1..n {
            if j == k || mu[k] == 0 { continue; }
            let d = gcd(j, k);
            let a = j / d; let b = k / d;
            let key = if a <= b { (a, b) } else { (b, a) };
            if seen.insert(key) { needed.push(key); }
        }
    }
    needed.par_iter()
        .map(|&(a, b)| ((a, b), vasyunin_sum(a, b) + vasyunin_sum(b, a)))
        .collect()
}

fn num_divisors(n: usize) -> usize {
    let mut count = 0;
    let mut d = 1;
    while d * d <= n {
        if n.is_multiple_of(d) {
            count += 1;
            if d != n / d { count += 1; }
        }
        d += 1;
    }
    count
}

fn is_hcn(n: usize, max_divisors_below: &mut usize) -> bool {
    let nd = num_divisors(n);
    if nd > *max_divisors_below {
        *max_divisors_below = nd;
        true
    } else {
        false
    }
}

fn is_prime_power(n: usize, primes: &[usize]) -> Option<usize> {
    for &p in primes {
        if p > n { break; }
        let mut x = n;
        while x > 1 && x.is_multiple_of(p) { x /= p; }
        if x == 1 { return Some(p); }
    }
    None
}

fn euler_phi(n: usize) -> usize {
    let mut result = n;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m.is_multiple_of(p) {
            while m.is_multiple_of(p) { m /= p; }
            result -= result / p;
        }
        p += 1;
    }
    if m > 1 { result -= result / m; }
    result
}

fn ramanujan_c(q: usize, n: usize, mu: &[i8]) -> f64 {
    let g = gcd(q, n);
    let mut s = 0.0f64;
    let mut d = 1;
    while d * d <= g {
        if g.is_multiple_of(d) {
            if q / d < mu.len() {
                s += (mu[q / d] as f64) * (d as f64);
            }
            let d2 = g / d;
            if d2 != d && q / d2 < mu.len() {
                s += (mu[q / d2] as f64) * (d2 as f64);
            }
        }
        d += 1;
    }
    s
}

struct DenseResult {
    n: usize,
    vtgv: f64,
    vt_b1_v: f64,
    vt_l1_v: f64,
    bt_v: f64,
    d2: f64,
    ratio: f64,  // d²/(2(1-bᵀv))
    // ═══ L₁ DECOMPOSITION (the four pieces from L1Bridge) ═══
    ratio_term: f64,    // Σᵢⱼ vᵢvⱼ · (j-k)/(2jk)·ln(k/j)
    neg_ecot: f64,      // -Σᵢⱼ vᵢvⱼ · π·gcd/(2jk)·(V(a,b)+V(b,a))
    log_harm: f64,      // Σᵢⱼ vᵢvⱼ · COEFF/2·(1/j+1/k)
    rank1: f64,         // Σᵢⱼ vᵢvⱼ · (-1/(jk))
    // ═══ GROWTH DIAGNOSTICS ═══
    vtgv_over_lnN: f64,
    vtgv_over_lnlnN: f64,
    norm_v_sq: f64,     // ||v||²
    n_active: usize,    // # nonzero weights
    // ═══ PNT SUMS (Mertens convergence) ═══
    mertens_sum: f64,       // Σ_{k≤N} μ(k)/k  (→ 0 by PNT)
    mertens_env_sum: f64,   // Σ_{k≤N} μ(k)·env(k)/k  (rank-1 amplitude)
    mertens_log_sum: f64,   // Σ_{k≤N} μ(k)·ln(k)/k  (→ -1 by PNT)
    // ═══ DOUBLE ABEL ═══
    max_partial: f64,
    c_inner: f64,
    tv_outer: f64,
    // ═══ GCD DECOMPOSITION ═══
    coprime_contrib: f64,
    p2_contrib: f64,
    p3_contrib: f64,
    gcd_strata: [f64; 7],  // [diag, gcd=1, gcd=2, gcd=3, gcd=4, gcd=5, gcd≥6]
    ramanujan_sum: f64,
    divisor_weighted: f64,
    euler_phi_sum: f64,
    cancel_efficiency: f64,
    noncop_l1: f64,
    // ═══ RATIO DIAGNOSTICS ═══
    ratio_over_neg: f64,    // ratio_term / |neg_ecot + log_harm + rank1|
    ecot_over_ratio: f64,   // |neg_ecot| / ratio_term
    // Flags
    is_hcn: bool,
    is_prime: bool,
    prime_power_base: Option<usize>,
    elapsed: f64,
}

fn analyze_dense(n: usize, mu: &[i8], _primes: &[usize]) -> DenseResult {
    let start = Instant::now();
    let dim = n - 1;
    let log_n = (n as f64).ln();

    // Build weights v_j = -μ(j)·(1-lnj/lnN) for j=1..N-1
    let v: Vec<f64> = (0..dim).map(|i| {
        let j = i + 1;
        if mu[j] == 0 { 0.0 }
        else { -(mu[j] as f64) * (1.0 - (j as f64).ln() / log_n) }
    }).collect();

    // Count active weights and compute ||v||²
    let mut norm_v_sq = 0.0f64;
    let mut n_active = 0usize;
    for &vi in &v {
        if vi != 0.0 {
            n_active += 1;
            norm_v_sq += vi * vi;
        }
    }

    // PNT sums
    let mut mertens_sum = 0.0f64;
    let mut mertens_env_sum = 0.0f64;
    let mut mertens_log_sum = 0.0f64;
    for k in 1..n {
        let kf = k as f64;
        let mu_k = mu[k] as f64;
        mertens_sum += mu_k / kf;
        let env = 1.0 - kf.ln() / log_n;
        if env > 0.0 {
            mertens_env_sum += mu_k * env / kf;
        }
        mertens_log_sum += mu_k * kf.ln() / kf;
    }

    // Precompute Vasyunin pair sums
    let pair_sums = precompute_pair_sums(n, mu);

    // Accumulators
    let mut inner = vec![0.0f64; dim];
    let mut vtgv = 0.0f64;
    let mut vt_b1_v = 0.0f64;
    let mut bt_v = 0.0f64;
    let mut coprime_contrib = 0.0f64;
    let mut p2_contrib = 0.0f64;
    let mut p3_contrib = 0.0f64;
    let mut gcd_strata = [0.0f64; 7];
    let mut ramanujan_sum = 0.0f64;
    let mut divisor_weighted = 0.0f64;
    let mut euler_phi_sum = 0.0f64;

    // L₁ decomposition accumulators
    let mut ratio_term = 0.0f64;
    let mut neg_ecot = 0.0f64;
    let mut log_harm = 0.0f64;
    let mut rank1 = 0.0f64;

    // bᵀv
    for i in 0..dim {
        bt_v += mean_entry(i + 1) * v[i];
    }

    // Main double loop
    for k_idx in 0..dim {
        let k = k_idx + 1;
        let kf = k as f64;
        let mut inner_k = 0.0f64;
        for j_idx in 0..dim {
            let j = j_idx + 1;
            let jf = j as f64;
            if v[j_idx] == 0.0 { continue; }
            let g_jk = if j == k {
                gram_diagonal(j)
            } else {
                gram_offdiag(j, k, &pair_sums)
            };
            inner_k += v[j_idx] * g_jk;

            let prod = v[j_idx] * v[k_idx];
            let contrib = prod * g_jk;
            vtgv += contrib;

            let b1_contrib = prod * b1_entry(j, k);
            vt_b1_v += b1_contrib;

            // ═══ L₁ decomposition ═══
            // rank1: -1/(jk)
            rank1 += prod * (-1.0 / (jf * kf));

            if j == k {
                // diagonal: logHarm component = COEFF/j (the 1/j + 1/k = 2/j part)
                log_harm += prod * COEFF / jf;
                // ratio_term = 0 on diagonal (j=k → (j-k)=0)
                // neg_ecot = 0 on diagonal (no cotangent for j=k)
            } else {
                // logHarm: COEFF/2 · (1/j + 1/k)
                log_harm += prod * COEFF / 2.0 * (1.0 / jf + 1.0 / kf);

                // ratio_term: (j-k)/(2jk) · ln(k/j)
                ratio_term += prod * (jf - kf) / (2.0 * jf * kf) * (kf / jf).ln();

                // neg_ecot: -π·gcd/(2jk) · (V(a,b) + V(b,a))
                let d = gcd(j, k);
                let jp = j / d;
                let kp = k / d;
                let key = if jp <= kp { (jp, kp) } else { (kp, jp) };
                let ps = pair_sums.get(&key).copied().unwrap_or(0.0);
                neg_ecot += prod * (-(PI * (d as f64) / (2.0 * jf * kf) * ps));
            }

            // GCD decomposition
            let d = gcd(j, k);
            if j == k {
                gcd_strata[0] += contrib;
            } else {
                match d {
                    1 => { gcd_strata[1] += contrib; coprime_contrib += contrib; }
                    2 => { gcd_strata[2] += contrib; }
                    3 => { gcd_strata[3] += contrib; }
                    4 => { gcd_strata[4] += contrib; }
                    5 => { gcd_strata[5] += contrib; }
                    _ => { gcd_strata[6] += contrib; }
                }
                if j % 2 == 0 && k % 2 == 0 { p2_contrib += contrib; }
                if j % 3 == 0 && k % 3 == 0 { p3_contrib += contrib; }
            }

            let c_val = ramanujan_c(d, 1, mu);
            ramanujan_sum += prod * c_val;
            let nd = num_divisors(d) as f64;
            divisor_weighted += contrib * nd;
            let phi_ratio = if d > 0 { euler_phi(d) as f64 / d as f64 } else { 0.0 };
            euler_phi_sum += contrib * phi_ratio;
        }
        inner[k_idx] = inner_k;
    }

    let vt_l1_v = vtgv - vt_b1_v;
    let d2 = 1.0 - 2.0 * bt_v + vtgv;
    let margin = 2.0 * (1.0 - bt_v);
    let ratio = if margin.abs() > 1e-15 { d2 / margin } else { f64::NAN };
    let cancel_efficiency = if vt_b1_v.abs() > 1e-15 { vt_l1_v.abs() / vt_b1_v } else { 0.0 };
    let noncop_l1 = vt_l1_v - coprime_contrib;

    // Growth diagnostics
    let log_n_val = (n as f64).ln();
    let log_log_n = if log_n_val > 1.0 { log_n_val.ln() } else { 0.01 };
    let vtgv_over_lnN = vtgv / log_n_val;
    let vtgv_over_lnlnN = vtgv / log_log_n;

    // Ratio diagnostics
    let neg_total = neg_ecot.abs() + log_harm.abs() + rank1.abs();
    let ratio_over_neg = if neg_total > 1e-15 { ratio_term / neg_total } else { f64::NAN };
    let ecot_over_ratio = if ratio_term.abs() > 1e-15 { neg_ecot.abs() / ratio_term } else { f64::NAN };

    // Double Abel
    let mut max_partial = 0.0f64;
    let mut partial_sum = 0.0f64;
    for i in 0..dim {
        partial_sum += v[i];
        if partial_sum.abs() > max_partial { max_partial = partial_sum.abs(); }
    }
    let c_inner = inner.iter().map(|x| x.abs()).fold(0.0f64, f64::max);
    let mut tv_outer = 0.0f64;
    for i in 0..dim.saturating_sub(1) {
        tv_outer += (inner[i + 1] - inner[i]).abs();
    }

    let elapsed = start.elapsed().as_secs_f64();

    DenseResult {
        n, vtgv, vt_b1_v, vt_l1_v, bt_v, d2, ratio,
        ratio_term, neg_ecot, log_harm, rank1,
        vtgv_over_lnN, vtgv_over_lnlnN, norm_v_sq, n_active,
        mertens_sum, mertens_env_sum, mertens_log_sum,
        max_partial, c_inner, tv_outer,
        coprime_contrib, p2_contrib, p3_contrib,
        gcd_strata, ramanujan_sum, divisor_weighted, euler_phi_sum,
        cancel_efficiency, noncop_l1,
        ratio_over_neg, ecot_over_ratio,
        is_hcn: false,
        is_prime: mu[n] != 0 && {
            let mut ip = true;
            let mut d = 2;
            while d * d <= n { if n.is_multiple_of(d) { ip = false; break; } d += 1; }
            ip && n > 1
        },
        prime_power_base: None,
        elapsed,
    }
}

fn main() {
    // Parse N_MAX from command line (default 3000)
    let args: Vec<String> = std::env::args().collect();
    let n_max: usize = if args.len() > 1 {
        args[1].parse().unwrap_or(3000)
    } else {
        3000
    };

    eprintln!("╔═══════════════════════════════════════════════════════════════════════════╗");
    eprintln!("║  DENSE ANATOMY v2 — Every N from 3 to {:<10}               🔬🏰     ║", n_max);
    eprintln!("║  L₁ decomposition: ratio | -eCot | logHarm | rank1                      ║");
    eprintln!("║  Growth: vtGv/lnN, vtGv/lnlnN, Δslope                                  ║");
    eprintln!("║  PNT: Σμ/k, Σμ·env/k, Σμ·lnk/k                                        ║");
    eprintln!("╚═══════════════════════════════════════════════════════════════════════════╝");
    eprintln!();

    eprintln!("  Sieving Möbius function up to {}...", n_max);
    let sieve_start = Instant::now();
    let (mu, primes) = sieve_mobius(n_max);
    eprintln!("  Sieve complete in {:.2}s. {} primes found.", sieve_start.elapsed().as_secs_f64(), primes.len());

    let results_dir = "experiments/overcancellation-scan/results";
    fs::create_dir_all(results_dir).unwrap();

    let tsv_path = format!("{}/dense_anatomy_v2.tsv", results_dir);
    let mut f = fs::File::create(&tsv_path).unwrap();

    // TSV header — every column we track
    writeln!(f, "N\tvtGv\tvtB1v\tvtL1v\tbtv\td2\tratio\t\
        ratio_term\tneg_ecot\tlog_harm\trank1\t\
        vtGv_lnN\tvtGv_lnlnN\tnorm_v_sq\tn_active\t\
        mertens_sum\tmertens_env\tmertens_log\t\
        max_partial\tc_inner\ttv_outer\tabel_product\t\
        coprime\tp2_contrib\tp3_contrib\t\
        gcd_diag\tgcd_1\tgcd_2\tgcd_3\tgcd_4\tgcd_5\tgcd_6plus\t\
        ramanujan\tdivisor_wt\teuler_phi\t\
        cancel_eff\tnoncop_l1\t\
        ratio_over_neg\tecot_over_ratio\t\
        is_hcn\tis_prime\tprime_power\ttime").unwrap();

    let total_start = Instant::now();
    let mut max_divisors = 0usize;
    let mut prev_vtgv = 0.0f64;
    let mut prev_ln_n = 1.0f64;

    // Console header (to stderr so TSV on stdout stays clean)
    eprintln!("  {:>6} {:>1} {:>8} {:>8} {:>8} {:>7} {:>7} {:>7} {:>7} {:>7} {:>8} {:>8} {:>6}",
        "N", "F", "vtGv", "ratio", "d²", "vtG/lN", "Δslope",
        "ratioT", "-eCot", "logH", "Σμ/k", "Σμe/k", "time");
    eprintln!("  {}", "-".repeat(120));

    for n in 3..=n_max {
        let mut r = analyze_dense(n, &mu, &primes);

        // Set flags
        r.is_hcn = is_hcn(n, &mut max_divisors);
        r.prime_power_base = is_prime_power(n, &primes);

        let abel_product = r.max_partial * (r.c_inner + r.tv_outer);
        let flag = if r.is_hcn { "H" }
            else if r.is_prime { "P" }
            else if r.prime_power_base.is_some() { "Q" }
            else { " " };

        // Incremental slope
        let ln_n = (n as f64).ln();
        let delta_vtgv = r.vtgv - prev_vtgv;
        let delta_ln_n = ln_n - prev_ln_n;
        let slope = if delta_ln_n > 1e-10 { delta_vtgv / delta_ln_n } else { 0.0 };
        prev_vtgv = r.vtgv;
        prev_ln_n = ln_n;

        // Print select rows to console
        let should_print = r.is_hcn || r.is_prime
            || n <= 30 || n % 100 == 0
            || n % 500 == 0
            || n == n_max;

        if should_print {
            eprintln!("  {:>6} {} {:>+8.4} {:>8.4} {:>8.5} {:>7.4} {:>+7.4} {:>+7.3} {:>+7.3} {:>+7.3} {:>+8.5} {:>+8.5} {:>5.1}s",
                n, flag, r.vtgv, r.ratio, r.d2, r.vtgv_over_lnN, slope,
                r.ratio_term, r.neg_ecot, r.log_harm,
                r.mertens_sum, r.mertens_env_sum,
                r.elapsed);
        }

        // Write ALL rows to TSV
        writeln!(f, "{}\t{:.12}\t{:.12}\t{:.12}\t{:.12}\t{:.12}\t{:.12}\t\
            {:.12}\t{:.12}\t{:.12}\t{:.12}\t\
            {:.12}\t{:.12}\t{:.6}\t{}\t\
            {:.12}\t{:.12}\t{:.12}\t\
            {:.12}\t{:.12}\t{:.12}\t{:.12}\t\
            {:.12}\t{:.12}\t{:.12}\t\
            {:.12}\t{:.12}\t{:.12}\t{:.12}\t{:.12}\t{:.12}\t{:.12}\t\
            {:.12}\t{:.12}\t{:.12}\t\
            {:.12}\t{:.12}\t\
            {:.8}\t{:.8}\t\
            {}\t{}\t{}\t{:.3}",
            n, r.vtgv, r.vt_b1_v, r.vt_l1_v, r.bt_v, r.d2, r.ratio,
            r.ratio_term, r.neg_ecot, r.log_harm, r.rank1,
            r.vtgv_over_lnN, r.vtgv_over_lnlnN, r.norm_v_sq, r.n_active,
            r.mertens_sum, r.mertens_env_sum, r.mertens_log_sum,
            r.max_partial, r.c_inner, r.tv_outer, abel_product,
            r.coprime_contrib, r.p2_contrib, r.p3_contrib,
            r.gcd_strata[0], r.gcd_strata[1], r.gcd_strata[2],
            r.gcd_strata[3], r.gcd_strata[4], r.gcd_strata[5], r.gcd_strata[6],
            r.ramanujan_sum, r.divisor_weighted, r.euler_phi_sum,
            r.cancel_efficiency, r.noncop_l1,
            r.ratio_over_neg, r.ecot_over_ratio,
            r.is_hcn, r.is_prime,
            r.prime_power_base.map_or("".to_string(), |p| p.to_string()),
            r.elapsed
        ).unwrap();

        // Flush every 100 rows for remote monitoring
        if n % 100 == 0 {
            f.flush().unwrap();
        }
    }

    f.flush().unwrap();
    let total_elapsed = total_start.elapsed().as_secs_f64();

    eprintln!();
    eprintln!("  Total time: {:.1}s for N=3..{}", total_elapsed, n_max);
    eprintln!("  TSV written to: {}", tsv_path);
    eprintln!();
    eprintln!("  COLUMNS ({}):", 41);
    eprintln!("  Core:     vtGv vtB1v vtL1v btv d2 ratio");
    eprintln!("  L1Bridge: ratio_term neg_ecot log_harm rank1");
    eprintln!("  Growth:   vtGv/lnN vtGv/lnlnN norm_v_sq n_active");
    eprintln!("  PNT:      mertens_sum mertens_env mertens_log");
    eprintln!("  Abel:     max_partial c_inner tv_outer abel_product");
    eprintln!("  GCD:      coprime p2 p3 gcd_diag..gcd_6plus");
    eprintln!("  Spectral: ramanujan divisor_wt euler_phi");
    eprintln!("  Balance:  cancel_eff noncop_l1 ratio_over_neg ecot_over_ratio");
    eprintln!("  Flags:    is_hcn is_prime prime_power");
}
