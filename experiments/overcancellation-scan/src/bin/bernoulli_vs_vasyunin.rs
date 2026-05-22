// overcancellation-scan/src/bin/bernoulli_vs_vasyunin.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  BERNOULLI vs VASYUNIN GRAM FORM COMPARISON                     ║
// ║                                                                   ║
// ║  The Smith probe revealed that vᵀG^(1)v ≈ 24.6 at N=100k        ║
// ║  But the actual Vasyunin Gram form vᵀGv should be < 1            ║
// ║                                                                   ║
// ║  This probe computes BOTH quadratic forms and their difference    ║
// ║  to understand WHERE the overcancellation lives.                  ║
// ║                                                                   ║
// ║  G^(1)(j,k) = ∫₀¹ {jt}{kt}dt = gcd²/(12jk) + 1/4              ║
// ║  G_V(j,k)   = Vasyunin formula (log(2π)-γ, cotangent sums)      ║
// ║  Δ(j,k)     = G_V(j,k) - G^(1)(j,k)  ← the correction kernel   ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::arith::{mobius_table, gcd};
use cathedral_utils::gram::gram_entry_f64;

/// Bernoulli-1 Gram entry: G^(1)(j,k) = ∫₀¹ {jt}{kt}dt
/// = gcd(j,k)²/(12jk) + 1/4
fn bernoulli1_entry(j: usize, k: usize) -> f64 {
    let g = gcd(j, k) as f64;
    let jf = j as f64;
    let kf = k as f64;
    g * g / (12.0 * jf * kf) + 0.25
}

/// Ramanujan entry: R(j,k) = gcd(j,k)²/(12jk)
fn ramanujan_entry(j: usize, k: usize) -> f64 {
    let g = gcd(j, k) as f64;
    let jf = j as f64;
    let kf = k as f64;
    g * g / (12.0 * jf * kf)
}

/// BD log-cutoff weight: w(k, N) = 1 - ln(k)/ln(N)
fn log_weight(k: usize, n: usize) -> f64 {
    if k >= n { return 0.0; }
    1.0 - (k as f64).ln() / (n as f64).ln()
}

/// BD witness vector entry: v(k) = -μ(k) · w(k, N)
fn witness_entry(mu_k: i8, k: usize, n: usize) -> f64 {
    -(mu_k as f64) * log_weight(k, n)
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════╗");
    println!("║  BERNOULLI vs VASYUNIN GRAM FORM COMPARISON              ║");
    println!("║  Where does the overcancellation live?                    ║");
    println!("╚═══════════════════════════════════════════════════════════╝");
    println!();

    // ─── SECTION 1: Entry-level comparison ───
    println!("═══════════════════════════════════════════════════════════");
    println!("§1. GRAM ENTRY COMPARISON: G_V(j,k) vs G^(1)(j,k)");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    println!("{:>5} {:>5} {:>14} {:>14} {:>14} {:>10}",
        "j", "k", "G_Vasyunin", "G_Bernoulli1", "Delta", "ratio");
    println!("{:>5} {:>5} {:>14} {:>14} {:>14} {:>10}",
        "-----", "-----", "--------------", "--------------", "--------------", "----------");

    let pairs: Vec<(usize, usize)> = vec![
        (1,1), (1,2), (1,3), (2,2), (2,3), (3,3),
        (1,5), (2,5), (3,5), (5,5),
        (1,10), (5,10), (10,10),
        (1,20), (10,20), (20,20),
        (1,50), (25,50), (50,50),
    ];

    for &(j, k) in &pairs {
        let g_v = gram_entry_f64(j, k);
        let g_b1 = bernoulli1_entry(j, k);
        let delta = g_v - g_b1;
        let ratio = if g_b1.abs() > 1e-15 { g_v / g_b1 } else { f64::NAN };
        println!("{:>5} {:>5} {:>14.8} {:>14.8} {:>14.8} {:>10.6}",
            j, k, g_v, g_b1, delta, ratio);
    }

    // ─── SECTION 2: Diagonal comparison ───
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§2. DIAGONAL ENTRIES: G_V(k,k) vs G^(1)(k,k)");
    println!("    G_V(k,k) = (ln(2pi)-gamma)/k - 1/k^2");
    println!("    G^(1)(k,k) = 1/(12k^2) + 1/4 = (3k^2+1)/(12k^2)");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    let gamma = 0.5772156649015329;
    let ln2pi = (2.0 * std::f64::consts::PI).ln();
    let c_diag = ln2pi - gamma; // ≈ 1.2645

    println!("{:>5} {:>14} {:>14} {:>14} {:>14}",
        "k", "G_V(k,k)", "G^(1)(k,k)", "Delta", "Delta*k");
    println!("{:>5} {:>14} {:>14} {:>14} {:>14}",
        "-----", "--------------", "--------------", "--------------", "--------------");

    for k in 1..=30 {
        let g_v = gram_entry_f64(k, k);
        let g_b1 = bernoulli1_entry(k, k);
        let delta = g_v - g_b1;
        let delta_k = delta * (k as f64);
        println!("{:>5} {:>14.8} {:>14.8} {:>14.8} {:>14.8}",
            k, g_v, g_b1, delta, delta_k);
    }

    // ─── SECTION 3: Quadratic form comparison ───
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§3. QUADRATIC FORM COMPARISON at BD witness");
    println!("    vᵀG_V v  vs  vᵀG^(1)v  vs  vᵀRv + 1/4*(Σv)^2");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    let test_ns: Vec<usize> = vec![10, 20, 50, 100, 200, 500];
    let max_n = *test_ns.last().unwrap();
    
    println!("Sieving Möbius function up to {}...", max_n);
    let mu = mobius_table(max_n);
    println!("Done.\n");

    println!("{:>6} {:>14} {:>14} {:>14} {:>14} {:>14}",
        "N", "vᵀG_V v", "vᵀG^(1)v", "vᵀRv", "1/4(Σv)^2", "Delta_form");
    println!("{:>6} {:>14} {:>14} {:>14} {:>14} {:>14}",
        "------", "--------------", "--------------", "--------------",
        "--------------", "--------------");

    for &n in &test_ns {
        // Build witness vector v(k) = -μ(k)·w(k,N) for k = 1..N
        let dim = n; // N-dimensional vector using k = 1..N
        let mut v = vec![0.0f64; dim];
        for k in 1..=n {
            if mu[k] != 0 {
                v[k-1] = witness_entry(mu[k], k, n);
            }
        }

        // Compute vᵀG_V v (actual Vasyunin Gram form)
        let mut vtgv_vasyunin = 0.0f64;
        for i in 0..dim {
            for j in 0..dim {
                let g_v = gram_entry_f64(i + 1, j + 1);
                vtgv_vasyunin += g_v * v[i] * v[j];
            }
        }

        // Compute vᵀG^(1)v (Bernoulli-1 form)
        let mut vtgv_b1 = 0.0f64;
        for i in 0..dim {
            for j in 0..dim {
                let g_b1 = bernoulli1_entry(i + 1, j + 1);
                vtgv_b1 += g_b1 * v[i] * v[j];
            }
        }

        // Compute vᵀRv (Ramanujan form)
        let mut vtrv = 0.0f64;
        for i in 0..dim {
            for j in 0..dim {
                let r = ramanujan_entry(i + 1, j + 1);
                vtrv += r * v[i] * v[j];
            }
        }

        // Compute (Σv)²
        let sum_v: f64 = v.iter().sum();
        let rank1 = 0.25 * sum_v * sum_v;

        // Verify glass decomposition: G^(1) = R + 1/4
        // vᵀG^(1)v should equal vᵀRv + 1/4*(Σv)²
        let b1_check = vtrv + rank1;

        let delta_form = vtgv_vasyunin - vtgv_b1;

        println!("{:>6} {:>14.8} {:>14.8} {:>14.8} {:>14.8} {:>14.8}",
            n, vtgv_vasyunin, vtgv_b1, vtrv, rank1, delta_form);
    }

    // ─── SECTION 4: Structure of the correction kernel ───
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§4. THE CORRECTION KERNEL Delta(j,k) = G_V - G^(1)");
    println!("    Structure: how does Delta(j,k) scale?");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    // Examine Delta(j,k) * j * k to see if it has a clean form
    println!("{:>5} {:>5} {:>14} {:>14} {:>14}",
        "j", "k", "Delta(j,k)", "Delta*jk", "Delta*max(j,k)");
    println!("{:>5} {:>5} {:>14} {:>14} {:>14}",
        "-----", "-----", "--------------", "--------------", "--------------");

    for j in 1..=10 {
        for k in j..=10 {
            let g_v = gram_entry_f64(j, k);
            let g_b1 = bernoulli1_entry(j, k);
            let delta = g_v - g_b1;
            let delta_jk = delta * (j as f64) * (k as f64);
            let delta_max = delta * (j.max(k) as f64);
            println!("{:>5} {:>5} {:>14.8} {:>14.8} {:>14.8}",
                j, k, delta, delta_jk, delta_max);
        }
    }

    // ─── SECTION 5: The key ratio ───
    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§5. THE KEY RATIO: vᵀG_V v  /  vᵀG^(1)v");
    println!("    If this ratio → 0, overcancellation lives in Delta");
    println!("═══════════════════════════════════════════════════════════");
    println!();

    println!("{:>6} {:>14} {:>14} {:>14} {:>10}",
        "N", "vᵀG_V v", "vᵀG^(1)v", "Delta_form", "ratio");
    println!("{:>6} {:>14} {:>14} {:>14} {:>10}",
        "------", "--------------", "--------------", "--------------", "----------");

    for &n in &test_ns {
        let mut v = vec![0.0f64; n];
        for k in 1..=n {
            if mu[k] != 0 {
                v[k-1] = witness_entry(mu[k], k, n);
            }
        }

        let mut vtgv_v = 0.0f64;
        let mut vtgv_b1 = 0.0f64;
        for i in 0..n {
            for j in 0..n {
                vtgv_v += gram_entry_f64(i+1, j+1) * v[i] * v[j];
                vtgv_b1 += bernoulli1_entry(i+1, j+1) * v[i] * v[j];
            }
        }

        let delta = vtgv_v - vtgv_b1;
        let ratio = if vtgv_b1.abs() > 1e-15 { vtgv_v / vtgv_b1 } else { f64::NAN };

        println!("{:>6} {:>14.8} {:>14.8} {:>14.8} {:>10.6}",
            n, vtgv_v, vtgv_b1, delta, ratio);
    }

    println!();
    println!("═══════════════════════════════════════════════════════════");
    println!("§6. VERDICT");
    println!("═══════════════════════════════════════════════════════════");
    println!();
    println!("The difference Delta = G_V - G^(1) is where overcancellation");
    println!("lives. If vᵀ(Delta)v ≈ -vᵀG^(1)v, then the Vasyunin kernel");
    println!("kills the Bernoulli-1 growth, giving vᵀG_V v << 1.");
}
