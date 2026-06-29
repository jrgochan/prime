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
/// Ramanujan Spectral Probe — Does Parseval capture Möbius cancellation?
///
/// The B₁ skeleton decomposes via J₂(d) (Jordan totient):
///   vᵀA₁v = (1/12) Σ_d J₂(d) · T_d²
///
/// where T_d = Σ_{m: dm≤N} v(dm)/(dm)
///
/// For Möbius weights v(k) = -μ(k)·(1-lnk/lnN):
///   T_d = Σ_{m≤N/d} -μ(dm)·(1-ln(dm)/lnN)/(dm)
///
/// When d is squarefree: μ(dm) = μ(d)·μ(m) for gcd(d,m)=1
///   T_d = (-μ(d)/d) · Σ_{m≤N/d, gcd(m,d)=1} μ(m)·(1-ln(dm)/lnN)/m
///
/// Each T_d is a MERTENS-TYPE SUM! PNT controls these individually.
/// The question: does Σ J₂(d)·T_d² converge, and how fast?

fn mobius_sieve(n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; n + 1];
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

/// Jordan's totient J₂(n) = n² · Π_{p|n} (1 - 1/p²)
fn jordan_j2(n: usize) -> f64 {
    if n == 0 {
        return 0.0;
    }
    let mut result = (n * n) as f64;
    let mut m = n;
    let mut p = 2;
    while p * p <= m {
        if m.is_multiple_of(p) {
            result *= 1.0 - 1.0 / (p * p) as f64;
            while m.is_multiple_of(p) {
                m /= p;
            }
        }
        p += 1;
    }
    if m > 1 {
        result *= 1.0 - 1.0 / (m * m) as f64;
    }
    result
}

fn main() {
    let n_max = 50_000;
    let mu = mobius_sieve(n_max);

    println!("═══════════════════════════════════════════════════════════════");
    println!("RAMANUJAN SPECTRAL PROBE — Parseval + Möbius Cancellation");
    println!("═══════════════════════════════════════════════════════════════");
    println!();

    // ═══ §1: Compute T_d and the Ramanujan spectrum for each N ═══
    println!("═══ §1: Ramanujan Spectrum vᵀA₁v = (1/12) Σ J₂(d)·T_d² ═══");
    println!(
        "{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "N", "vᵀA₁v_exact", "vᵀA₁v_ram", "check", "vᵀGv_num", "d²_N"
    );
    println!("{}", "-".repeat(72));

    for &n in &[50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000] {
        if n > n_max {
            break;
        }
        let ln_n = (n as f64).ln();

        // Build v(k) = -μ(k)·(1-lnk/lnN)
        let mut v = vec![0.0_f64; n + 1];
        for k in 1..n {
            v[k] = -(mu[k] as f64) * (1.0 - (k as f64).ln() / ln_n);
        }

        // Method 1: Direct computation of vᵀA₁v
        let mut vta1v_direct = 0.0_f64;
        for j in 1..n {
            if v[j] == 0.0 {
                continue;
            }
            for k in 1..n {
                if v[k] == 0.0 {
                    continue;
                }
                let g = gcd(j, k);
                vta1v_direct += v[j] * v[k] * (g * g) as f64 / (12.0 * j as f64 * k as f64);
            }
        }

        // Method 2: Ramanujan expansion
        // T_d = Σ_{m: dm≤N-1} v(dm)/(dm)
        let mut ramanujan_sum = 0.0_f64;
        for d in 1..n {
            let j2d = jordan_j2(d);
            let mut t_d = 0.0_f64;
            let mut m = 1;
            while d * m < n {
                let km = d * m;
                t_d += v[km] / km as f64;
                m += 1;
            }
            ramanujan_sum += j2d * t_d * t_d;
        }
        ramanujan_sum /= 12.0;

        let check = (vta1v_direct - ramanujan_sum).abs();

        // Also compute bᵀv and approximate vᵀGv
        let euler_gamma = 0.5772156649015329;
        let mut bv = 0.0;
        for k in 1..n {
            let b_k = ((k as f64).ln() + 1.0 - euler_gamma) / k as f64;
            bv += b_k * v[k];
        }
        let d2_n = 1.0 - 2.0 * bv + vta1v_direct; // approximate (using skeleton only)

        println!(
            "{:>6} {:>12.6} {:>12.6} {:>12.2e} {:>12.6} {:>12.6}",
            n, vta1v_direct, ramanujan_sum, check, vta1v_direct, d2_n
        );
    }

    // ═══ §2: The T_d spectrum — where does the energy live? ═══
    let n = 10000;
    let ln_n = (n as f64).ln();
    let mut v = vec![0.0_f64; n + 1];
    for k in 1..n {
        v[k] = -(mu[k] as f64) * (1.0 - (k as f64).ln() / ln_n);
    }

    println!();
    println!("═══ §2: T_d Spectrum at N={} ═══", n);
    println!(
        "{:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "d", "T_d", "J₂(d)", "J₂·T_d²", "cumul", "% total"
    );
    println!("{}", "-".repeat(72));

    let mut total = 0.0_f64;
    // First pass to get total
    for d in 1..n {
        let j2d = jordan_j2(d);
        let mut t_d = 0.0;
        let mut m = 1;
        while d * m < n {
            t_d += v[d * m] / (d * m) as f64;
            m += 1;
        }
        total += j2d * t_d * t_d;
    }
    total /= 12.0;

    let mut cumul = 0.0;
    let mut printed = 0;
    for d in 1..n {
        let j2d = jordan_j2(d);
        let mut t_d = 0.0;
        let mut m = 1;
        while d * m < n {
            t_d += v[d * m] / (d * m) as f64;
            m += 1;
        }
        let contribution = j2d * t_d * t_d / 12.0;
        cumul += contribution;
        let pct = 100.0 * cumul / total;

        // Print first 20, then every 10th up to 100, then milestones
        if d <= 20 || (d <= 100 && d % 10 == 0) || (d <= 1000 && d % 100 == 0) || d % 1000 == 0 {
            println!(
                "{:>6} {:>12.8} {:>12.1} {:>12.6e} {:>12.6} {:>12.2}%",
                d, t_d, j2d, contribution, cumul, pct
            );
            printed += 1;
        }
    }
    if printed > 0 {
        println!("...");
        println!("  Total vᵀA₁v = {:.8}", total);
    }

    // ═══ §3: T_d as Mertens sums — does PNT explain decay? ═══
    println!();
    println!("═══ §3: T_d as Mertens Sums — PNT Explanation ═══");
    println!();
    println!("T_1 = Σ_{{k<N}} -μ(k)(1-lnk/lnN)/k  = Mertens with log-taper (→ 1 by PNT)");
    println!("T_d = Σ_{{m: dm<N}} -μ(dm)(1-ln(dm)/lnN)/(dm)  = filtered Mertens at scale d");
    println!();

    println!("{:>6} {:>12} {:>12} {:>12}", "d", "T_d", "μ(d)", "|T_d|·d");
    println!("{}", "-".repeat(42));

    for d in 1..=30 {
        let mut t_d = 0.0;
        let mut m = 1;
        while d * m < n {
            t_d += v[d * m] / (d * m) as f64;
            m += 1;
        }
        println!(
            "{:>6} {:>12.8} {:>12} {:>12.6}",
            d,
            t_d,
            mu[d],
            t_d.abs() * d as f64
        );
    }

    // ═══ §4: Key insight — T_1 and bᵀv ═══
    println!();
    println!("═══ §4: T_1 vs bᵀv — The Connection ═══");
    println!();
    let mut t_1 = 0.0;
    let euler_gamma = 0.5772156649015329;
    let mut bv = 0.0;
    for k in 1..n {
        t_1 += v[k] / k as f64;
        let b_k = ((k as f64).ln() + 1.0 - euler_gamma) / k as f64;
        bv += b_k * v[k];
    }
    println!("  T_1 = {:.8} (→ 1 as N→∞, from PNT)", t_1);
    println!("  bᵀv = {:.8} (→ 1 as N→∞, PROVED)", bv);
    println!("  T_1 - 1 = {:.8}", t_1 - 1.0);
    println!("  bᵀv - 1 = {:.8}", bv - 1.0);
    println!();
    println!("  If T_d = O(1/(d·logN)) for d ≥ 2, then:");
    println!("  vᵀA₁v = (1/12)·J₂(1)·T_1² + (1/12)·Σ_{{d≥2}} J₂(d)·T_d²");
    println!("         ≈ (1/12)·1·(1+O(1/logN))² + O(1/logN)");
    println!("         = 1/12 + O(1/logN)");
    println!();

    // Compute the d=1 contribution vs rest
    let t1_contrib = jordan_j2(1) * t_1 * t_1 / 12.0;
    println!(
        "  d=1 contribution:  {:.8} (= J₂(1)·T_1²/12 = T_1²/12)",
        t1_contrib
    );
    println!("  d≥2 contributions: {:.8}", total - t1_contrib);
    println!("  Total vᵀA₁v:      {:.8}", total);
    println!();
    println!(
        "  Ratio d≥2/total:   {:.4}%",
        100.0 * (total - t1_contrib) / total
    );

    println!();
    println!("═══════════════════════════════════════════════════════════════");
}

fn gcd(a: usize, b: usize) -> usize {
    let (mut a, mut b) = (a, b);
    while b > 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}
