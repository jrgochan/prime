//! # listen — hearing the zeta zeros through the Cramér bridge
//!
//! Computes Cramér's mean square
//!
//! ```text
//!   J(X) = ∫₁^X ((ψ(u) − u)/u)² du
//! ```
//!
//! exactly (piecewise on unit intervals) for X up to X_MAX, sampling J on a
//! uniform grid in t = log X. By the Cramér bridge, d²(N)·log²N ≈ J(N), so
//! the wiggles of J are the wiggles of the Báez-Duarte distance.
//!
//! Explicit-formula prediction (under RH):
//!
//! ```text
//!   J(X) = C₀·log X + C₁ + Σ_{ρ≠ρ'} X^{i(γ−γ')} / (i(γ−γ')·ρ·ρ̄') + o(1)
//! ```
//!
//! with C₀ = Σ 1/|ρ|² = 2 + γ − ln 4π. The oscillations live at the zero
//! DIFFERENCES γ_j − γ_k (and sums γ_j + γ_k).
//!
//! Usage: `listen [X_MAX] [DT]` → TSV on stdout: t, X, J, (ψ(X) − X)/√X

use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let x_max: usize = args
        .get(1)
        .and_then(|s| s.parse::<f64>().ok())
        .map(|v| v as usize)
        .unwrap_or(1_000_000_000);
    let dt: f64 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(0.002);

    // 12-point Gauss–Legendre on [0,1]
    let xg = [
        0.125_233_408_511_468_9,
        0.367_831_498_998_180_2,
        0.587_317_954_286_617_4,
        0.769_902_674_194_304_7,
        0.904_117_256_370_474_9,
        0.981_560_634_246_719_3,
    ];
    let wg = [
        0.249_147_045_813_402_8,
        0.233_492_536_538_354_8,
        0.203_167_426_723_065_9,
        0.160_078_328_543_346_2,
        0.106_939_325_995_318_4,
        0.047_175_336_386_511_8,
    ];
    let mut gt = [0.0f64; 12];
    let mut gw = [0.0f64; 12];
    for i in 0..6 {
        gt[2 * i] = 0.5 * (1.0 - xg[i]);
        gt[2 * i + 1] = 0.5 * (1.0 + xg[i]);
        gw[2 * i] = 0.5 * wg[i];
        gw[2 * i + 1] = 0.5 * wg[i];
    }

    // Base primes up to sqrt(x_max)
    let root = (x_max as f64).sqrt() as usize + 2;
    let mut is_p = vec![true; root + 1];
    is_p[0] = false;
    is_p[1] = false;
    let mut base: Vec<usize> = Vec::new();
    for p in 2..=root {
        if is_p[p] {
            base.push(p);
            let mut m = p * p;
            while m <= root {
                is_p[m] = false;
                m += p;
            }
        }
    }

    // ψ accumulator (Kahan), J accumulator (Kahan)
    let (mut psi, mut psi_c) = (0.0f64, 0.0f64);
    let (mut jj, mut jj_c) = (0.0f64, 0.0f64);
    let mut next_t = 1.0f64; // first sample at t = 1
    println!("t\tX\tJ\tpsi_err_over_sqrtX");

    let seg = 1usize << 22;
    let mut lam = vec![0.0f64; seg];
    let mut comp = vec![false; seg];
    let mut lo = 1usize;
    while lo < x_max {
        let hi = (lo + seg).min(x_max);
        let len = hi - lo;
        for v in lam[..len].iter_mut() {
            *v = 0.0;
        }
        for v in comp[..len].iter_mut() {
            *v = false;
        }
        // Mark composites in [lo, hi)
        for &p in &base {
            if p * p >= hi {
                break;
            }
            let start = (p * p).max(lo.div_ceil(p) * p);
            let mut m = start;
            while m < hi {
                comp[m - lo] = true;
                m += p;
            }
        }
        // Primes in segment → Λ = log p
        for n in lo.max(2)..hi {
            if !comp[n - lo] {
                lam[n - lo] = (n as f64).ln();
            }
        }
        // Prime powers p^k (k ≥ 2) in segment: Λ = log p
        for &p in &base {
            let lp = (p as f64).ln();
            let mut q = p * p;
            while q < hi {
                if q >= lo {
                    lam[q - lo] = lp;
                }
                match q.checked_mul(p) {
                    Some(v) => q = v,
                    None => break,
                }
            }
        }
        for n in lo..hi {
            // ψ(n) includes Λ(n)
            let y = lam[n - lo] - psi_c;
            let t = psi + y;
            psi_c = (t - psi) - y;
            psi = t;

            let nf = n as f64;
            let delta = psi - nf; // ψ(u) − u = δ − t on [n, n+1)
            let mut s = 0.0;
            for i in 0..12 {
                let e = delta - gt[i];
                let w = nf + gt[i];
                s += gw[i] * e * e / (w * w);
            }
            let y = s - jj_c;
            let t = jj + y;
            jj_c = (t - jj) - y;
            jj = t;

            // Sample at X = n + 1 (J now covers [1, n+1))
            let x = nf + 1.0;
            let tx = x.ln();
            if tx >= next_t {
                println!(
                    "{:.6}\t{}\t{:.12}\t{:.6}",
                    tx,
                    n + 1,
                    jj,
                    (psi - x) / x.sqrt()
                );
                while next_t <= tx {
                    next_t += dt;
                }
            }
        }
        lo = hi;
    }
}
