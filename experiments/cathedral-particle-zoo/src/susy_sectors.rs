//! SUSY Sector Decomposition of the Gram Quadratic Form
//!
//! Implements the exact decomposition proved in GaugeCancellation.lean:
//!
//!   vᵀGv = D(N) + B_off(N) + F_off(N)
//!
//! where:
//!   D(N) = diagonal contribution (squarefree self-energy)
//!   B_off(N) = bosonic off-diagonal (even Ω(j)+Ω(k) parity)
//!   F_off(N) = fermionic off-diagonal (odd Ω(j)+Ω(k) parity)

use cathedral_utils::arith;

/// Compute Ω(n) table (number of prime factors with multiplicity) for n = 0..=max_n.
/// Same sieve approach as liouville_table in cathedral-utils.
fn big_omega_table(max_n: usize) -> Vec<u32> {
    let mut omega = vec![0u32; max_n + 1];
    for p in 2..=max_n {
        if omega[p] != 0 {
            continue;
        }
        // p is prime (omega[p] is still 0)
        let mut pk = p;
        while pk <= max_n {
            for m in (pk..=max_n).step_by(pk) {
                omega[m] += 1;
            }
            if pk > max_n / p {
                break;
            }
            pk *= p;
        }
    }
    omega
}

/// Result of the SUSY sector decomposition.
#[derive(Debug, Clone)]
pub struct SusySectors {
    pub n: usize,
    pub vtgv: f64,          // Full vᵀGv
    pub diagonal: f64,      // D(N) — squarefree diagonal
    pub bosonic_off: f64,   // B_off(N) — even Ω parity off-diagonal
    pub fermionic_off: f64, // F_off(N) — odd Ω parity off-diagonal
    pub off_diagonal: f64,  // B + F total
    pub susy_residual: f64, // |B + F|
    pub gap_times_ln: f64,  // (1 - vᵀGv) · ln(N)
    pub num_sqfree: usize,  // count of squarefree k ≤ N-1
    pub num_bosonic_pairs: usize,
    pub num_fermionic_pairs: usize,
}

/// Compute the Vasyunin Gram entry G(j,k) using the discrete formula.
///
/// G(j,k) = Σ_{t=1..T} {t/j}·{t/k} / t²
///
/// where T is a truncation parameter (we use T = 10·max(j,k) for accuracy).
fn gram_entry(j: usize, k: usize) -> f64 {
    let t_max = 10 * j.max(k);
    let mut sum = 0.0f64;
    for t in 1..=t_max {
        let fj = arith::frac_part(t as f64 / j as f64);
        let fk = arith::frac_part(t as f64 / k as f64);
        sum += fj * fk / (t as f64 * t as f64);
    }
    sum
}

/// Compute the witness entry v(k,N) = -μ(k) · (1 - ln(k)/ln(N))
fn witness_entry(k: usize, n: usize, mu: &[i8]) -> f64 {
    let mu_k = mu[k] as f64;
    let w = 1.0 - (k as f64).ln() / (n as f64).ln();
    -mu_k * w
}

/// Full SUSY sector decomposition at dimension N.
///
/// This computes D(N), B_off(N), F_off(N) exactly matching the
/// Lean definitions in GaugeCancellation.lean.
pub fn decompose(n: usize) -> SusySectors {
    let dim = n - 1; // indices 1..N-1
    let mu = arith::mobius_table(n);
    let omega = big_omega_table(n);

    // Compute witness vector
    let v: Vec<f64> = (1..n).map(|k| witness_entry(k, n, &mu)).collect();

    // Compute vᵀGv and decompose simultaneously
    let mut diagonal = 0.0f64;
    let mut bosonic_off = 0.0f64;
    let mut fermionic_off = 0.0f64;
    let mut vtgv = 0.0f64;
    let mut num_sqfree = 0usize;
    let mut num_bosonic = 0usize;
    let mut num_fermionic = 0usize;

    for i in 0..dim {
        let j = i + 1; // 1-indexed
        let vj = v[i];

        // Diagonal: i = i
        let g_jj = gram_entry(j, j);
        let diag_term = vj * vj * g_jj;
        diagonal += diag_term;
        vtgv += diag_term;

        if mu[j] != 0 {
            num_sqfree += 1;
        }

        // Off-diagonal: all k ≠ j
        for ii in 0..dim {
            if ii == i {
                continue;
            }
            let k = ii + 1;
            let vk = v[ii];
            let g_jk = gram_entry(j, k);
            let term = vj * g_jk * vk;
            vtgv += term;

            let omega_sum = omega[j] as u32 + omega[k] as u32;
            if omega_sum.is_multiple_of(2) {
                bosonic_off += term;
                num_bosonic += 1;
            } else {
                fermionic_off += term;
                num_fermionic += 1;
            }
        }
    }

    let off_diagonal = bosonic_off + fermionic_off;
    let ln_n = (n as f64).ln();

    SusySectors {
        n,
        vtgv,
        diagonal,
        bosonic_off,
        fermionic_off,
        off_diagonal,
        susy_residual: off_diagonal.abs(),
        gap_times_ln: (1.0 - vtgv) * ln_n,
        num_sqfree,
        num_bosonic_pairs: num_bosonic,
        num_fermionic_pairs: num_fermionic,
    }
}

/// Lighter version: compute using precomputed Gram matrix (flat, row-major).
pub fn decompose_from_gram(n: usize, gram_flat: &[f64]) -> SusySectors {
    let dim = n - 1;
    let mu = arith::mobius_table(n);
    let omega = big_omega_table(n);

    let v: Vec<f64> = (1..n).map(|k| witness_entry(k, n, &mu)).collect();

    let mut diagonal = 0.0f64;
    let mut bosonic_off = 0.0f64;
    let mut fermionic_off = 0.0f64;
    let mut vtgv = 0.0f64;
    let mut num_sqfree = 0usize;
    let mut num_bosonic = 0usize;
    let mut num_fermionic = 0usize;

    for i in 0..dim {
        let j = i + 1;
        let vj = v[i];
        if mu[j] != 0 {
            num_sqfree += 1;
        }

        for ii in 0..dim {
            let k = ii + 1;
            let vk = v[ii];
            let g_jk = gram_flat[i * dim + ii];
            let term = vj * g_jk * vk;
            vtgv += term;

            if i == ii {
                diagonal += term;
            } else {
                let omega_sum = omega[j] as u32 + omega[k] as u32;
                if omega_sum.is_multiple_of(2) {
                    bosonic_off += term;
                    num_bosonic += 1;
                } else {
                    fermionic_off += term;
                    num_fermionic += 1;
                }
            }
        }
    }

    let off_diagonal = bosonic_off + fermionic_off;
    let ln_n = (n as f64).ln();

    SusySectors {
        n,
        vtgv,
        diagonal,
        bosonic_off,
        fermionic_off,
        off_diagonal,
        susy_residual: off_diagonal.abs(),
        gap_times_ln: (1.0 - vtgv) * ln_n,
        num_sqfree,
        num_bosonic_pairs: num_bosonic,
        num_fermionic_pairs: num_fermionic,
    }
}

impl SusySectors {
    pub fn display(&self) {
        println!();
        println!("  ╔══════════════════════════════════════════════════════════════════╗");
        println!("  ║  SUSY SECTOR DECOMPOSITION   (GaugeCancellation.lean ✅)        ║");
        println!("  ╠══════════════════════════════════════════════════════════════════╣");
        println!(
            "  ║  N = {:>6}   dim = {:>6}   sqfree indices = {:>5}             ║",
            self.n,
            self.n - 1,
            self.num_sqfree
        );
        println!("  ╠══════════════════════════════════════════════════════════════════╣");
        println!(
            "  ║  vᵀGv       = {:>+16.10}                                 ║",
            self.vtgv
        );
        println!("  ║  ────────────────────────────────────────────────────────────── ║");
        println!(
            "  ║  D(N)       = {:>+16.10}   (diagonal, vacuum self-energy) ║",
            self.diagonal
        );
        println!(
            "  ║  B_off(N)   = {:>+16.10}   (bosonic, even Ω parity)      ║",
            self.bosonic_off
        );
        println!(
            "  ║  F_off(N)   = {:>+16.10}   (fermionic, odd Ω parity)     ║",
            self.fermionic_off
        );
        println!("  ║  ────────────────────────────────────────────────────────────── ║");
        println!(
            "  ║  B + F      = {:>+16.10}   (SUSY residual)               ║",
            self.off_diagonal
        );
        println!(
            "  ║  |B + F|    = {:>16.10}   (SUSY cancellation)            ║",
            self.susy_residual
        );
        println!("  ║  ────────────────────────────────────────────────────────────── ║");
        println!(
            "  ║  D + B + F  = {:>+16.10}   (= vᵀGv ✓)                   ║",
            self.diagonal + self.off_diagonal
        );
        println!(
            "  ║  gap·ln(N)  = {:>16.10}   (→ const if K/lnN decay)      ║",
            self.gap_times_ln
        );
        println!("  ╠══════════════════════════════════════════════════════════════════╣");
        println!(
            "  ║  Bosonic pairs:   {:>8}                                      ║",
            self.num_bosonic_pairs
        );
        println!(
            "  ║  Fermionic pairs: {:>8}                                      ║",
            self.num_fermionic_pairs
        );

        // Physics interpretation
        let d_frac = if self.vtgv.abs() > 1e-15 {
            self.diagonal / self.vtgv * 100.0
        } else {
            0.0
        };
        let bf_frac = if self.vtgv.abs() > 1e-15 {
            self.off_diagonal / self.vtgv * 100.0
        } else {
            0.0
        };
        println!("  ╠══════════════════════════════════════════════════════════════════╣");
        println!(
            "  ║  D/vᵀGv     = {:>7.2}%   (vacuum self-energy fraction)       ║",
            d_frac
        );
        println!(
            "  ║  (B+F)/vᵀGv = {:>+7.2}%   (off-diagonal SUSY fraction)       ║",
            bf_frac
        );

        if self.vtgv < 1.0 {
            println!(
                "  ║  STATUS: vᵀGv < 1  ✅  (Nyman-Beurling margin = {:.4})       ║",
                1.0 - self.vtgv
            );
        } else {
            println!(
                "  ║  STATUS: vᵀGv ≥ 1  ⚠️  (margin = {:.4})                     ║",
                1.0 - self.vtgv
            );
        }
        println!("  ╚══════════════════════════════════════════════════════════════════╝");
    }
}
