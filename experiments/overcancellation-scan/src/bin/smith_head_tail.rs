// overcancellation-scan/src/bin/smith_head_tail.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  SMITH HEAD/TAIL PROBE — MoebiusSmithBridge Verification        ║
// ║                                                                   ║
// ║  Tests the head/tail decomposition from MoebiusSmithBridge.lean  ║
// ║  with THREE witness types:                                        ║
// ║    (A) Pure Möbius: v_k = -μ(k)/k                                ║
// ║    (B) Rescaled:    z_k = v_k/(k+1) = -μ(k)/(k(k+1))           ║
// ║    (C) Log-weight:  v_k = -μ(k)·(1-ln(k)/ln(N))                ║
// ║                                                                   ║
// ║  Reports smithHead(D) and smithTail(D) for various D cutoffs.    ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::mobius_table;

/// J₂(d) = d² · Π_{p|d} (1 - 1/p²)
fn jordan_totient2(d: usize) -> f64 {
    if d == 0 { return 0.0; }
    let d_f = d as f64;
    let mut result = d_f * d_f;
    let mut n = d;
    let mut p = 2;
    while p * p <= n {
        if n % p == 0 {
            result *= 1.0 - 1.0 / (p as f64 * p as f64);
            while n % p == 0 { n /= p; }
        }
        p += 1;
    }
    if n > 1 {
        result *= 1.0 - 1.0 / (n as f64 * n as f64);
    }
    result
}

/// Divisor projection y_d = Σ_{d|k, 1≤k≤N} w(k)
/// where w(k) is the weight function
fn divisor_projection(mu: &[i8], d: usize, n: usize, weights: &[f64]) -> f64 {
    let mut sum = 0.0f64;
    let mut k = d;
    while k <= n {
        sum += weights[k];
        k += d;
    }
    sum
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════╗");
    println!("║  SMITH HEAD/TAIL PROBE                                   ║");
    println!("║  MoebiusSmithBridge.lean Verification                    ║");
    println!("╚═══════════════════════════════════════════════════════════╝");
    println!();

    let test_ns: Vec<usize> = vec![1000, 5000, 10000, 50000, 100000, 500000];
    let max_n = *test_ns.last().unwrap();

    println!("Sieving Möbius function up to {}...", max_n);
    let mu = mobius_table(max_n);
    println!("Done.\n");

    // ═══════════════════════════════════════════════════════════
    // TEST WITH THREE WITNESSES
    // ═══════════════════════════════════════════════════════════

    let witness_names = [
        "(A) Pure Möbius: v_k = -μ(k)/k",
        "(B) Rescaled:    z_k = -μ(k)/(k·(k+1))",
        "(C) Log-weight:  v_k = -μ(k)·w(k,N)/k",
    ];

    for &n in &test_ns {
        let log_n = (n as f64).ln();

        // Build weight vectors
        let mut weights_a = vec![0.0f64; n + 1]; // Pure Möbius
        let mut weights_b = vec![0.0f64; n + 1]; // Rescaled (matches Lean)
        let mut weights_c = vec![0.0f64; n + 1]; // Log-weight

        for k in 1..=n {
            let mu_k = mu[k] as f64;
            let k_f = k as f64;
            weights_a[k] = -mu_k / k_f;
            weights_b[k] = -mu_k / (k_f * (k_f + 1.0));
            let w_log = if k < n { 1.0 - k_f.ln() / log_n } else { 0.0 };
            weights_c[k] = -mu_k * w_log / k_f;
        }

        let all_weights = [&weights_a, &weights_b, &weights_c];

        println!("═══════════════════════════════════════════════════════════");
        println!("N = {}  (log N = {:.3})", n, log_n);
        println!("═══════════════════════════════════════════════════════════");
        println!();

        for (wi, weights) in all_weights.iter().enumerate() {
            println!("  {}", witness_names[wi]);
            println!("  ─────────────────────────────────────────────────");

            // Compute full Smith sum and head/tail for various D
            let d_cutoffs: Vec<usize> = vec![
                1, 2, 5, 10, 20, 50, 100, 200, 500,
                (n as f64).sqrt() as usize,
                n / 10, n / 2, n,
            ];

            // First compute full sum
            let mut full_smith = 0.0f64;
            let mut terms: Vec<f64> = Vec::with_capacity(n + 1);
            terms.push(0.0); // d=0 placeholder
            for d in 1..=n {
                let yd = divisor_projection(&mu, d, n, weights);
                let j2d = jordan_totient2(d);
                let term = j2d * yd * yd;
                terms.push(term);
                full_smith += term;
            }

            let v_r_v = full_smith / 12.0;

            // Compute Σv for rank-1 term
            let sum_v: f64 = (1..=n).map(|k| weights[k]).sum();
            let rank1 = 0.25 * sum_v * sum_v;
            let v_g_v = v_r_v + rank1;

            println!("  Full Smith sum = {:.8}  (vᵀRv = {:.8})", full_smith, v_r_v);
            println!("  (Σv)² = {:.8}  rank1 = {:.8}", sum_v * sum_v, rank1);
            println!("  vᵀGv = {:.8}  {}", v_g_v,
                if v_g_v < 1.0 { "< 1 ✅" } else { "> 1" });
            println!();

            // Head/tail split
            println!("  {:>8} {:>14} {:>14} {:>14} {:>14}",
                "D", "Head(D)", "Tail(D)", "Head/D", "Tail·D");
            println!("  {:>8} {:>14} {:>14} {:>14} {:>14}",
                "--------", "--------------", "--------------",
                "--------------", "--------------");

            for &d_cut in &d_cutoffs {
                if d_cut == 0 || d_cut > n { continue; }

                let head: f64 = (1..=d_cut).map(|d| terms[d]).sum();
                let tail: f64 = ((d_cut + 1)..=n).map(|d| terms[d]).sum();
                let head_per_d = if d_cut > 0 { head / (d_cut as f64) } else { 0.0 };
                let tail_times_d = tail * (d_cut as f64);

                println!("  {:>8} {:>14.8} {:>14.8} {:>14.8} {:>14.8}",
                    d_cut, head, tail, head_per_d, tail_times_d);
            }

            // Divisor projection decay profile
            println!();
            println!("  Divisor projection decay: |y_d| for small d");
            println!("  {:>5} {:>14} {:>14} {:>14} {:>14}",
                "d", "y_d", "|y_d|·d", "J₂(d)·y_d²", "cumul_pct");
            println!("  {:>5} {:>14} {:>14} {:>14} {:>14}",
                "-----", "--------------", "--------------",
                "--------------", "--------------");

            let mut cumul = 0.0f64;
            for d in 1..=30.min(n) {
                let yd = divisor_projection(&mu, d, n, weights);
                let j2d = jordan_totient2(d);
                cumul += j2d * yd * yd;
                let pct = if full_smith > 0.0 { 100.0 * cumul / full_smith } else { 0.0 };
                println!("  {:>5} {:>14.8} {:>14.8} {:>14.8} {:>13.4}%",
                    d, yd, yd.abs() * d as f64, j2d * yd * yd, pct);
            }

            println!();
        }
        println!();
    }

    // ═══════════════════════════════════════════════════════════
    // SCALING ANALYSIS
    // ═══════════════════════════════════════════════════════════

    println!("═══════════════════════════════════════════════════════════");
    println!("SCALING ANALYSIS: How does Smith sum grow with N?");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    println!("{:>10} {:>12} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "N", "Smith_A", "Smith_B", "Smith_C",
        "A/N", "A/logN", "A/log²N");
    println!("{:>10} {:>12} {:>12} {:>12} {:>12} {:>12} {:>12}",
        "----------", "------------", "------------", "------------",
        "------------", "------------", "------------");

    for &n in &test_ns {
        let log_n = (n as f64).ln();

        let mut weights_a = vec![0.0f64; n + 1];
        let mut weights_b = vec![0.0f64; n + 1];
        let mut weights_c = vec![0.0f64; n + 1];
        for k in 1..=n {
            let mu_k = mu[k] as f64;
            let k_f = k as f64;
            weights_a[k] = -mu_k / k_f;
            weights_b[k] = -mu_k / (k_f * (k_f + 1.0));
            let w_log = if k < n { 1.0 - k_f.ln() / log_n } else { 0.0 };
            weights_c[k] = -mu_k * w_log / k_f;
        }

        let smith = |weights: &[f64]| -> f64 {
            let mut s = 0.0f64;
            for d in 1..=n {
                let yd = divisor_projection(&mu, d, n, weights);
                let j2d = jordan_totient2(d);
                s += j2d * yd * yd;
            }
            s
        };

        let sa = smith(&weights_a);
        let sb = smith(&weights_b);
        let sc = smith(&weights_c);

        println!("{:>10} {:>12.4} {:>12.6} {:>12.4} {:>12.6} {:>12.4} {:>12.4}",
            n, sa, sb, sc,
            sa / n as f64, sa / log_n, sa / (log_n * log_n));
    }

    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("KEY: If Smith_B / something → constant, that's the growth rate.");
    println!("The RESCALED witness (B) matches our Lean axiom statements.");
    println!("═══════════════════════════════════════════════════════════");
}
