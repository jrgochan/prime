//! # Cramér Bridge — Exploration 38
//!
//! Computes the Báez-Duarte distance d²(N) for the Möbius log-cutoff witness
//! DIRECTLY in the time domain — no Gram matrix, no cotangent sums.
//!
//! ```text
//!   d² = ∫₀¹ (1 − Σ_{k≤N} v_k {1/(kx)})² dx,     v_k = −μ(k)(1 − ln k / ln N)
//! ```
//!
//! Substituting u = 1/x:  d² = ∫₁^∞ F(u)² du/u²,  F(u) = 1 − Σ v_k {u/k}.
//! On [n, n+1):  F(u) = α_n − A·u, with A = Σ v_k/k and α_n = 1 + Σ_{m≤n} c_m,
//! where c_m = Σ_{k | m, k ≤ N} v_k.
//!
//! ## The Cramér identity (n ≤ N)
//!
//! Since Σ_{k|m} μ(k) log k = −Λ(m), for m ≤ N we get c_m = −[m=1] − Λ(m)/L,
//! hence α_n = −ψ(n)/L and
//!
//! ```text
//!   F(u) = (u − ψ(u))/L − ε·u,     ε = A + 1/L   (PNT-small)
//! ```
//!
//! So for u ≤ N the BD residual IS the Chebyshev error, and
//! d²·L ≈ (1/L)·∫₁ᴺ ((ψ(u) − u)/u)² du  — Cramér's mean square.
//!
//! ## Output columns
//! - `d2*L`        : scaled distance (theory under RH+BCF: → 2+γ−ln4π ≈ 0.0462)
//! - `low*L`       : contribution from u ∈ [1, N+1)
//! - `high*L`      : contribution from u ∈ [N+1, U)
//! - `tail*L`      : estimated ∫_U^∞ (mean F² / U)
//! - `gap*L`       : (1 − bᵀv)·L  (→ 1+γ by PNT)
//! - `margin*L`    : (1 − vᵀGv)·L = 2·gap·L − d²·L  (→ D = γ + ln 4π ≈ 3.1082)
//! - `vGv`         : implied Gram quadratic form
//! - `cramer/L`    : (1/L)·∫₁^{N+1} ((ψ(u) − u)/u)² du
//!
//! Usage: `cramer-bridge [U_FACTOR] [N ...]`  (set CHECKPOINTS=1 for U-convergence)
//!
//! Validated against the Wall.lean HPDF table: vGv(720) = 0.58687 (0.587),
//! vGv(55440) = 0.73671 (0.737). N = 10⁷ runs in ~13 s on a laptop.

use cathedral_utils::arith::mobius_table;
use std::env;
use std::time::Instant;

const GAMMA: f64 = 0.577_215_664_901_532_9;

/// 12-point Gauss–Legendre nodes/weights mapped to [0,1].
fn gl12() -> ([f64; 12], [f64; 12]) {
    let x = [
        0.125_233_408_511_468_9,
        0.367_831_498_998_180_2,
        0.587_317_954_286_617_4,
        0.769_902_674_194_304_7,
        0.904_117_256_370_474_9,
        0.981_560_634_246_719_3,
    ];
    let w = [
        0.249_147_045_813_402_8,
        0.233_492_536_538_354_8,
        0.203_167_426_723_065_9,
        0.160_078_328_543_346_2,
        0.106_939_325_995_318_4,
        0.047_175_336_386_511_8,
    ];
    let mut t = [0.0; 12];
    let mut ww = [0.0; 12];
    for i in 0..6 {
        t[2 * i] = 0.5 * (1.0 - x[i]);
        t[2 * i + 1] = 0.5 * (1.0 + x[i]);
        ww[2 * i] = 0.5 * w[i];
        ww[2 * i + 1] = 0.5 * w[i];
    }
    (t, ww)
}

/// Kahan compensated summation.
struct Kahan {
    s: f64,
    c: f64,
}

impl Kahan {
    fn new() -> Self {
        Kahan { s: 0.0, c: 0.0 }
    }
    fn add(&mut self, x: f64) {
        let y = x - self.c;
        let t = self.s + y;
        self.c = (t - self.s) - y;
        self.s = t;
    }
}

fn run(n_cut: usize, u_factor: usize) {
    let t0 = Instant::now();
    let l = (n_cut as f64).ln();
    let mu = mobius_table(n_cut);
    let mut v = vec![0.0f64; n_cut + 1];
    let mut ks: Vec<usize> = Vec::new();
    for k in 1..=n_cut {
        if mu[k] != 0 {
            v[k] = -(mu[k] as f64) * (1.0 - (k as f64).ln() / l);
            ks.push(k);
        }
    }

    // A = Σ v_k/k ; gap = 1 − bᵀv with b_k = (ln k + 1 − γ)/k
    let mut a_k = Kahan::new();
    let mut btv = Kahan::new();
    for &k in &ks {
        let kf = k as f64;
        a_k.add(v[k] / kf);
        btv.add(v[k] * (kf.ln() + 1.0 - GAMMA) / kf);
    }
    let a = a_k.s;
    let gap = 1.0 - btv.s;

    let (gt, gw) = gl12();
    let u_max = u_factor * n_cut; // integrate u ∈ [1, u_max)
    let block = n_cut.max(1 << 16);
    let mut c = vec![0.0f64; block];

    let mut b_acc = Kahan::new(); // B_n = Σ_{m≤n} c_m
    let mut d2_low = Kahan::new(); // u ∈ [1, N+1)
    let mut d2_high = Kahan::new(); // u ∈ [N+1, u_max)
    let mut cramer = Kahan::new(); // ∫ (ψ(u) − u)²/u² over [1, N+1)
    let mut ms_tail = Kahan::new(); // ∫ F² over the last half, for the tail estimate
    let half = u_max / 2;
    let mut checkpoints: Vec<(usize, f64)> = Vec::new();

    let mut lo = 1usize;
    while lo < u_max {
        let hi = (lo + block).min(u_max);
        for x in c[..hi - lo].iter_mut() {
            *x = 0.0;
        }
        // Block divisor sieve: c_m = Σ_{k | m, k ≤ N} v_k
        for &k in &ks {
            let mut m = lo.div_ceil(k) * k;
            let vk = v[k];
            while m < hi {
                c[m - lo] += vk;
                m += k;
            }
        }
        for n in lo..hi {
            b_acc.add(c[n - lo]);
            let alpha = 1.0 + b_acc.s;
            let nf = n as f64;
            let beta = alpha - a * nf; // F(n + t) = β − A·t
            let mut seg = 0.0;
            let mut fsq = 0.0;
            for i in 0..12 {
                let t = gt[i];
                let f = beta - a * t;
                let w = nf + t;
                seg += gw[i] * f * f / (w * w);
                fsq += gw[i] * f * f;
            }
            if n <= n_cut {
                d2_low.add(seg);
                let psi = -l * alpha; // Cramér identity: α_n = −ψ(n)/L for n ≤ N
                let mut cs = 0.0;
                for i in 0..12 {
                    let w = nf + gt[i];
                    let e = psi - w;
                    cs += gw[i] * e * e / (w * w);
                }
                cramer.add(cs);
            } else {
                d2_high.add(seg);
            }
            if n >= half {
                ms_tail.add(fsq);
            }
            if n.is_power_of_two() && n > n_cut {
                checkpoints.push((n, d2_low.s + d2_high.s));
            }
        }
        lo = hi;
    }

    let mean_f2 = ms_tail.s / ((u_max - half) as f64);
    let tail_est = mean_f2 / (u_max as f64);
    let d2 = d2_low.s + d2_high.s + tail_est;
    let margin = 2.0 * gap - d2;
    let vgv = 1.0 - margin;
    let eps = a + 1.0 / l;
    println!(
        "N={:>8} L={:.4} | d2={:.7} d2*L={:.5} | low*L={:.5} high*L={:.5} tail*L={:.2e} | \
         gap*L={:.5} margin*L={:.5} vGv={:.5} | cramer/L={:.5} eps*L={:.2e} meanF2={:.3} | {:.1}s",
        n_cut,
        l,
        d2,
        d2 * l,
        d2_low.s * l,
        d2_high.s * l,
        tail_est * l,
        gap * l,
        margin * l,
        vgv,
        cramer.s / l,
        eps * l,
        mean_f2,
        t0.elapsed().as_secs_f64()
    );
    if env::var("CHECKPOINTS").is_ok() {
        for (u, s) in checkpoints {
            println!("    U={:>12}  partial d2*L={:.6}", u, s * l);
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let u_factor: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(64);
    let ns: Vec<usize> = if args.len() > 2 {
        args[2..].iter().filter_map(|s| s.parse().ok()).collect()
    } else {
        vec![720, 2520, 5040, 10080, 20160, 55440]
    };
    for n in ns {
        run(n, u_factor);
    }
}
