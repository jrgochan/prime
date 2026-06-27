//! ═══════════════════════════════════════════════════════════════════════════
//!  EXPERIMENT: PARTICLE SIEVE — Divisor-based classification at large N
//!
//!  Since the full Gram matrix is O(N²) in storage, we cannot compute the
//!  ground state directly for N > ~20,000. Instead, this experiment:
//!
//!  1. Sieves all integers up to N for their arithmetic properties:
//!     d(k), σ(k), ω(k), Ω(k), smallest prime factor, largest prime factor
//!
//!  2. Uses the divisor structure to classify each integer as a potential
//!     boson or fermion based on patterns observed at N ≤ 10,000.
//!
//!  3. Identifies "particle families" — clusters of integers sharing
//!     a common factorization pattern.
//!
//!  This runs in O(N log log N) time and O(N) memory, making N=10⁶ trivial.
//!
//!  Usage: particle-sieve [max_N]
//! ═══════════════════════════════════════════════════════════════════════════

use cathedral_utils::fmt::*;
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════════════
// SIEVE OF ARITHMETIC FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════

struct SieveResult {
    n: usize,
    is_prime: Vec<bool>,    // is_prime[k] for k = 0..=n
    smallest_pf: Vec<u32>,  // smallest prime factor
    num_divisors: Vec<u32>, // d(k) = number of divisors
    divisor_sum: Vec<u64>,  // σ(k) = sum of divisors
    omega: Vec<u8>,         // ω(k) = distinct prime factors
    big_omega: Vec<u8>,     // Ω(k) = total prime factors with multiplicity
}

fn arithmetic_sieve(n: usize) -> SieveResult {
    let t0 = Instant::now();

    // ── Phase 0: Allocate arrays ──
    eprintln!(
        "  {DIM}  Allocating {:.1} GB...{RESET}",
        (n + 1) as f64 * (1 + 4 + 8 + 1 + 1) as f64 / 1e9
    );
    let mut is_prime = vec![true; n + 1];
    let mut num_divisors = vec![0u32; n + 1];
    let mut divisor_sum = vec![0u64; n + 1];
    let mut omega = vec![0u8; n + 1];
    let mut big_omega = vec![0u8; n + 1];
    eprintln!(
        "  {DIM}  Allocated ({:.1}s){RESET}",
        t0.elapsed().as_secs_f64()
    );

    is_prime[0] = false;
    is_prime[1] = false;

    // ── Phase 1: Sieve of Eratosthenes + additive ω/Ω sieve ──
    // For each prime p, mark composites AND increment ω/Ω for all multiples.
    // This is O(N log log N) — much faster than trial division at N=1B.
    eprintln!("  {DIM}  Phase 1: Prime sieve + ω/Ω (O(N log log N))...{RESET}");
    let sqrt_n = (n as f64).sqrt() as usize + 1;

    for p in 2..=n {
        if !is_prime[p] {
            continue;
        }

        // p is prime: set its own ω and Ω
        omega[p] = 1;
        big_omega[p] = 1;

        // Mark composites (only need to start at p² for primality)
        if p <= sqrt_n {
            let mut j = p * p;
            while j <= n {
                is_prime[j] = false;
                j += p;
            }
        }

        // Increment ω for all multiples of p (starting at 2p)
        let mut j = 2 * p;
        while j <= n {
            omega[j] += 1;
            j += p;
        }

        // Increment Ω for all multiples of p, p², p³, ...
        let mut pk = p; // p^1, p^2, p^3, ...
        loop {
            // Check overflow before multiplication
            if pk > n / p {
                break;
            } // pk * p would overflow or exceed n
            let next_pk = pk * p;
            if next_pk > n {
                break;
            }
            pk = next_pk;
            let mut j = pk;
            while j <= n {
                big_omega[j] += 1;
                j += pk;
            }
        }

        if p % 10_000_000 == 1 && p > 1 {
            eprint!(
                "\r  {DIM}  Phase 1: p = {} ({:.0}%) {:.1}s{RESET}    ",
                p,
                100.0 * p as f64 / n as f64,
                t0.elapsed().as_secs_f64()
            );
        }
    }

    // Ω: we counted extra powers above; the base count for each prime is
    // done via the omega pass. But Ω = total prime factors with multiplicity.
    // Easier approach: Ω(k) = sum over p|k of v_p(k).
    // The additive sieve above incremented omega[j] once per prime p dividing j,
    // and big_omega[j] once per prime power p^a dividing j (for a >= 2).
    // So big_omega[j] currently has the count of higher powers only.
    // Total Ω = omega + big_omega (omega counts the base, big_omega the extras).
    for k in 2..=n {
        big_omega[k] += omega[k];
    }

    eprintln!(
        "\r  {DIM}  Phase 1 done ({:.1}s){RESET}                    ",
        t0.elapsed().as_secs_f64()
    );

    // ── Phase 2: Divisor sieve for d(k) and σ(k) ──
    // This is O(N log N) — the slowest phase at ~21B ops for N=1B.
    eprintln!("  {DIM}  Phase 2: Divisor sieve d(k), σ(k) (O(N log N))...{RESET}");
    num_divisors[1] = 1;
    divisor_sum[1] = 1;
    let phase2_start = Instant::now();
    for d in 1..=n {
        let mut k = d;
        while k <= n {
            num_divisors[k] += 1;
            divisor_sum[k] += d as u64;
            k += d;
        }
        if d % 10_000_000 == 0 {
            let frac = d as f64 / n as f64;
            let elapsed = phase2_start.elapsed().as_secs_f64();
            let eta = elapsed / frac * (1.0 - frac);
            eprint!(
                "\r  {DIM}  Phase 2: d = {} ({:.0}%) ETA {:.0}s{RESET}    ",
                d,
                frac * 100.0,
                eta
            );
        }
    }
    eprintln!(
        "\r  {DIM}  Phase 2 done ({:.1}s){RESET}                        ",
        t0.elapsed().as_secs_f64()
    );

    SieveResult {
        n,
        is_prime,
        smallest_pf: Vec::new(), // not needed at large N
        num_divisors,
        divisor_sum,
        omega,
        big_omega,
    }
}

// ═══════════════════════════════════════════════════════════════════════
// HIGHLY COMPOSITE NUMBER DETECTION
// ═══════════════════════════════════════════════════════════════════════

fn find_highly_composite(sieve: &SieveResult) -> Vec<usize> {
    let mut hc = Vec::new();
    let mut max_div = 0u32;
    for k in 1..=sieve.n {
        if sieve.num_divisors[k] > max_div {
            max_div = sieve.num_divisors[k];
            hc.push(k);
        }
    }
    hc
}

// ═══════════════════════════════════════════════════════════════════════
// ANALYSIS
// ═══════════════════════════════════════════════════════════════════════

fn analyze(n: usize) {
    let t0 = Instant::now();

    println!(
        "\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}"
    );
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}PARTICLE SIEVE · N = {n}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Computing arithmetic functions via sieve...{RESET}");
    println!(
        "  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}"
    );

    let sieve = arithmetic_sieve(n);
    println!(
        "  {DIM}Sieve complete ({:.2}s){RESET}",
        t0.elapsed().as_secs_f64()
    );

    // Count primes
    let prime_count = (2..=n).filter(|&k| sieve.is_prime[k]).count();
    let composite_count = n - 1 - prime_count;

    println!(
        "  {DIM}Primes ≤ {n}: {prime_count} ({:.2}%){RESET}",
        100.0 * prime_count as f64 / (n - 1) as f64
    );

    // Find highly composite numbers
    let hc = find_highly_composite(&sieve);
    println!("  {DIM}Highly composite numbers: {}{RESET}", hc.len());

    // ─── ω DISTRIBUTION ───
    println!("\n  {BOLD}{WHITE}═══ PRIME FACTOR COUNT DISTRIBUTION ω(k) ═══{RESET}");
    let max_omega = *sieve.omega.iter().max().unwrap_or(&0) as usize;
    let mut omega_counts = vec![0usize; max_omega + 1];
    let mut omega_prime_counts = vec![0usize; max_omega + 1];
    for k in 2..=n {
        let w = sieve.omega[k] as usize;
        omega_counts[w] += 1;
        if sieve.is_prime[k] {
            omega_prime_counts[w] += 1;
        }
    }
    println!("  {DIM}ω  │ count    │ primes   │ composites │ pct{RESET}");
    println!("  {DIM}───┼──────────┼──────────┼────────────┼──────{RESET}");
    for w in 0..=max_omega {
        if omega_counts[w] > 0 {
            let comps = omega_counts[w] - omega_prime_counts[w];
            println!(
                "  {:<2} │ {:<8} │ {:<8} │ {:<10} │ {:.2}%",
                w,
                omega_counts[w],
                omega_prime_counts[w],
                comps,
                100.0 * omega_counts[w] as f64 / (n - 1) as f64
            );
        }
    }

    // ─── GENERATION STRUCTURE ───
    println!("\n  {BOLD}{WHITE}═══ GENERATION STRUCTURE (SM parallel) ═══{RESET}");
    println!("  {DIM}Mapping: ω(k) → SM generation number{RESET}");
    println!();
    println!("  {CYAN}Generation 0{RESET}: Primes (ω=1, prime)  → Gauge bosons");
    println!("    Count: {}", prime_count);
    println!("  {YELLOW}Generation 1{RESET}: Prime powers (ω=1, composite) → 1st gen fermions");
    println!("    Count: {}", omega_counts[1] - prime_count);
    for generation in 2..=max_omega.min(6) {
        let name = match generation {
            2 => "2nd gen fermions",
            3 => "3rd gen fermions",
            4 => "4th gen fermions",
            5 => "5th gen fermions",
            _ => "higher gen",
        };
        println!("  {YELLOW}Generation {generation}{RESET}: ω={generation} composites → {name}");
        println!(
            "    Count: {}",
            omega_counts[generation] - omega_prime_counts[generation]
        );
    }

    // ─── HIGHLY COMPOSITE ANALYSIS ───
    println!("\n  {BOLD}{WHITE}═══ HIGHLY COMPOSITE NUMBERS (potential top quarks) ═══{RESET}");
    println!("  {DIM}rank │ k       │ d(k)  │ σ(k)    │ ω  │ Ω  │ factors{RESET}");
    println!("  {DIM}─────┼─────────┼───────┼─────────┼────┼────┼────────{RESET}");
    for (i, &k) in hc.iter().rev().take(30).enumerate() {
        println!(
            "  {:<4} │ {:<7} │ {:<5} │ {:<7} │ {:<2} │ {:<2} │ {}",
            i + 1,
            k,
            sieve.num_divisors[k],
            sieve.divisor_sum[k],
            sieve.omega[k],
            sieve.big_omega[k],
            factorize(k)
        );
    }

    // ─── SUPERABUNDANT NUMBERS ───
    // These have σ(k)/k > σ(j)/j for all j < k
    let mut superabundant = Vec::new();
    let mut max_ratio = 0.0f64;
    for k in 1..=n {
        let ratio = sieve.divisor_sum[k] as f64 / k as f64;
        if ratio > max_ratio {
            max_ratio = ratio;
            superabundant.push(k);
        }
    }
    println!("\n  {BOLD}{WHITE}═══ SUPERABUNDANT NUMBERS (densest hubs) ═══{RESET}");
    println!("  {DIM}These maximize σ(k)/k — the 'gravitational mass' of the integer{RESET}");
    println!("  {DIM}rank │ k       │ σ(k)/k  │ d(k)  │ ω  │ factors{RESET}");
    println!("  {DIM}─────┼─────────┼─────────┼───────┼────┼────────{RESET}");
    for (i, &k) in superabundant.iter().rev().take(20).enumerate() {
        println!(
            "  {:<4} │ {:<7} │ {:<7.4} │ {:<5} │ {:<2} │ {}",
            i + 1,
            k,
            sieve.divisor_sum[k] as f64 / k as f64,
            sieve.num_divisors[k],
            sieve.omega[k],
            factorize(k)
        );
    }

    // ─── PARTICLE FAMILY ANALYSIS ───
    // For each of the top-20 HC numbers, count their multiples
    println!("\n  {BOLD}{WHITE}═══ PARTICLE FAMILIES (multiplets of HC numbers) ═══{RESET}");
    println!("  {DIM}base │ d(base) │ multiples ≤ N │ ω range │ factors{RESET}");
    println!("  {DIM}─────┼─────────┼───────────────┼─────────┼────────{RESET}");
    for &base in hc.iter().rev().take(15) {
        let mult_count = n / base;
        let omega_min = sieve.omega[base];
        let omega_max = (2..=mult_count)
            .filter(|&m| m * base <= n)
            .map(|m| sieve.omega[m * base])
            .max()
            .unwrap_or(omega_min);
        println!(
            "  {:<4} │ {:<7} │ {:<13} │ {}-{}     │ {}",
            base,
            sieve.num_divisors[base],
            mult_count,
            omega_min,
            omega_max,
            factorize(base)
        );
    }

    // ─── PRIME GAPS NEAR HC NUMBERS ───
    println!("\n  {BOLD}{WHITE}═══ PRIMES NEAR HIGHLY COMPOSITE NUMBERS ═══{RESET}");
    println!("  {DIM}(The 'Higgs mechanism': primes adjacent to HC numbers){RESET}");
    for &hc_k in hc.iter().rev().take(10) {
        // Find nearest prime below and above
        let mut p_below = hc_k - 1;
        while p_below > 1 && !sieve.is_prime[p_below] {
            p_below -= 1;
        }
        let mut p_above = hc_k + 1;
        while p_above <= n && !sieve.is_prime[p_above] {
            p_above += 1;
        }
        let gap_below = hc_k - p_below;
        let gap_above = if p_above <= n { p_above - hc_k } else { 0 };
        println!(
            "  HC={:<7} d={:<4}  nearest primes: {:<7}(gap={}) and {:<7}(gap={})  {}",
            hc_k,
            sieve.num_divisors[hc_k],
            p_below,
            gap_below,
            p_above,
            gap_above,
            factorize(hc_k)
        );
    }

    // ─── OUTPUT FILES ───
    let results_dir = std::path::Path::new("results");
    let _ = std::fs::create_dir_all(results_dir);

    // HC numbers TSV
    let hc_path = results_dir.join(format!("highly_composite_N{n}.tsv"));
    if let Ok(mut f) = std::fs::File::create(&hc_path) {
        use std::io::Write;
        writeln!(
            f,
            "rank\tk\td(k)\tsigma(k)\tsigma_over_k\tomega\tOmega\tfactors"
        )
        .ok();
        for (i, &k) in hc.iter().enumerate() {
            writeln!(
                f,
                "{}\t{}\t{}\t{}\t{:.6}\t{}\t{}\t{}",
                i + 1,
                k,
                sieve.num_divisors[k],
                sieve.divisor_sum[k],
                sieve.divisor_sum[k] as f64 / k as f64,
                sieve.omega[k],
                sieve.big_omega[k],
                factorize(k)
            )
            .ok();
        }
        println!("\n  {GREEN}✓ Wrote {hc_path:?}{RESET}");
    }

    // ω distribution TSV
    let omega_path = results_dir.join(format!("omega_distribution_N{n}.tsv"));
    if let Ok(mut f) = std::fs::File::create(&omega_path) {
        use std::io::Write;
        writeln!(f, "omega\tcount\tprimes\tcomposites\tpercent").ok();
        for w in 0..=max_omega {
            if omega_counts[w] > 0 {
                writeln!(
                    f,
                    "{}\t{}\t{}\t{}\t{:.4}",
                    w,
                    omega_counts[w],
                    omega_prime_counts[w],
                    omega_counts[w] - omega_prime_counts[w],
                    100.0 * omega_counts[w] as f64 / (n - 1) as f64
                )
                .ok();
            }
        }
        println!("  {GREEN}✓ Wrote {omega_path:?}{RESET}");
    }

    // JSON summary
    let json_path = results_dir.join(format!("particle_sieve_N{n}.json"));
    if let Ok(mut f) = std::fs::File::create(&json_path) {
        use std::io::Write;
        let top_hc = hc.last().copied().unwrap_or(0);
        write!(
            f,
            r#"{{
  "experiment": "particle-sieve",
  "N": {n},
  "prime_count": {prime_count},
  "composite_count": {composite_count},
  "prime_density": {:.8},
  "highly_composite_count": {},
  "superabundant_count": {},
  "max_omega": {max_omega},
  "top_highly_composite": {{
    "k": {top_hc},
    "d_k": {},
    "sigma_k": {},
    "omega": {},
    "factors": "{}"
  }},
  "omega_distribution": [{}],
  "elapsed_secs": {:.2}
}}
"#,
            prime_count as f64 / (n - 1) as f64,
            hc.len(),
            superabundant.len(),
            sieve.num_divisors[top_hc],
            sieve.divisor_sum[top_hc],
            sieve.omega[top_hc],
            factorize(top_hc),
            omega_counts
                .iter()
                .enumerate()
                .filter(|(_, c)| **c > 0)
                .map(|(w, c)| format!("{{\"omega\": {w}, \"count\": {c}}}"))
                .collect::<Vec<_>>()
                .join(", "),
            t0.elapsed().as_secs_f64(),
        )
        .ok();
        println!("  {GREEN}✓ Wrote {json_path:?}{RESET}");
    }

    println!(
        "\n  {DIM}Total time: {:.2}s{RESET}",
        t0.elapsed().as_secs_f64()
    );
    println!();
}

fn factorize(mut n: usize) -> String {
    if n <= 1 {
        return n.to_string();
    }
    let mut factors = Vec::new();
    let mut p = 2;
    while p * p <= n {
        if n.is_multiple_of(p) {
            let mut exp = 0;
            while n.is_multiple_of(p) {
                n /= p;
                exp += 1;
            }
            if exp == 1 {
                factors.push(format!("{p}"));
            } else {
                factors.push(format!("{p}^{exp}"));
            }
        }
        p += 1;
    }
    if n > 1 {
        factors.push(format!("{n}"));
    }
    factors.join("·")
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let max_n: usize = args
        .get(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(1_000_000);

    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    println!(
        "\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}"
    );
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}CATHEDRAL PARTICLE SIEVE{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Arithmetic classification · N = {max_n}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}{threads} threads{RESET}");
    println!(
        "  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}"
    );

    analyze(max_n);

    println!(
        "  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.2}s{RESET} ({threads} threads)",
        t0.elapsed().as_secs_f64()
    );
    println!();
}
