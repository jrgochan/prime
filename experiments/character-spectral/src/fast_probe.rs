//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL FAST SPECTRAL PROBE — f64 / nalgebra
//!
//!  Hardware-accelerated eigendecomposition for rapid exploration at high N.
//!  Trades MPFR precision for ~100x speed. Level spacing statistics are
//!  insensitive to floating-point precision beyond ~10 digits.
//!
//!  Usage: fast-probe [max_N]  (default 500)
//! ═══════════════════════════════════════════════════════════════════════════

mod characters;
mod fmt;
mod spectral;

use characters::*;
use fmt::*;
use rayon::prelude::*;
use std::fs;
use std::io::Write;
use std::time::Instant;

/// Build Gram matrix entry G(j,k) in f64 using Vasyunin sum.
fn gram_entry_f64(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let inv_jk = 1.0 / (jf * kf);

    fn gcd(a: usize, b: usize) -> usize {
        if b == 0 { a } else { gcd(b, a % b) }
    }

    let lcm_jk = j / gcd(j, k) * k;
    let t_direct = (lcm_jk * 3).max(2_000).min(200_000);

    let mut total = 0.0f64;

    for n in 1..=t_direct {
        let nf = n as f64;
        let a_int = n / j;
        let b_int = n / k;
        let a = a_int as f64;
        let b = b_int as f64;

        let inv_n = 1.0 / nf;
        let ln_term = (1.0 + inv_n).ln();

        let ab_coeff = a / kf + b / jf;

        let ab_frac = if a_int > 0 && b_int > 0 {
            (a * b) / (nf * (nf + 1.0))
        } else {
            0.0
        };

        total += inv_jk - ab_coeff * ln_term + ab_frac;
    }

    // Tail correction
    let d = gcd(j, k) as f64;
    let twelve_jk = 12.0 * jf * kf;
    let tail_mean = 0.25 + d * d / twelve_jk;
    let t_f = t_direct as f64;
    total += tail_mean / t_f;
    total += tail_mean / (2.0 * t_f * t_f);
    total
}

/// Build full Gram matrix in f64, indices 2..=n, fully parallel via rayon.
fn build_gram_f64(n: usize) -> (Vec<f64>, usize) {
    let dim = n - 1;
    let total = dim * (dim + 1) / 2;

    eprintln!(
        "    Building {dim}×{dim} f64 Gram matrix ({total} entries, rayon parallel)..."
    );

    // Compute upper triangle in parallel
    let entries: Vec<((usize, usize), f64)> = (0..dim)
        .into_par_iter()
        .flat_map(|row| {
            (row..dim)
                .map(move |col| {
                    let j = row + 2;
                    let k = col + 2;
                    ((row, col), gram_entry_f64(j, k))
                })
                .collect::<Vec<_>>()
        })
        .collect();

    // Assemble symmetric matrix
    let mut mat = vec![0.0f64; dim * dim];
    for ((r, c), v) in entries {
        mat[r * dim + c] = v;
        mat[c * dim + r] = v;
    }

    (mat, dim)
}

/// Extract eigenvalues using nalgebra's optimized decomposition.
fn eigenvalues_nalgebra(mat: &[f64], dim: usize) -> Vec<f64> {
    if dim == 0 {
        return vec![];
    }
    let m = nalgebra::DMatrix::from_row_slice(dim, dim, mat);
    let eigen = m.symmetric_eigen();
    let mut eigs: Vec<f64> = eigen.eigenvalues.iter().copied().collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}

/// Project to sub-matrix for given index set.
fn project_f64(full_mat: &[f64], full_dim: usize, indices: &[usize]) -> Vec<f64> {
    let sub_dim = indices.len();
    let mut sub = vec![0.0f64; sub_dim * sub_dim];
    for (si, &ki) in indices.iter().enumerate() {
        let ri = ki - 2;
        for (sj, &kj) in indices.iter().enumerate() {
            let rj = kj - 2;
            sub[si * sub_dim + sj] = full_mat[ri * full_dim + rj];
        }
    }
    sub
}

fn print_eig_row(name: &str, dim: usize, eigs: &[f64], elapsed: f64) {
    if eigs.is_empty() {
        println!(
            "  {:<14} │ {:>5} │ {:<14} │ {:<14} │ {:<11} │ {:.1}s",
            name, dim, "N/A", "N/A", "N/A", elapsed
        );
        return;
    }
    let lmin = eigs[0];
    let lmax = eigs[eigs.len() - 1];
    let kappa = if lmin.abs() > 1e-30 {
        lmax / lmin
    } else {
        f64::INFINITY
    };
    println!(
        "  {:<14} │ {:>5} │ {:>14.10} │ {:>14.10} │ {:>11.3e} │ {:.1}s",
        name, dim, lmin, lmax, kappa, elapsed
    );
}

fn save_eigenvalues(path: &str, eigs: &[f64]) {
    let mut f = fs::File::create(path).unwrap();
    writeln!(f, "index\teigenvalue").unwrap();
    for (i, &e) in eigs.iter().enumerate() {
        writeln!(f, "{}\t{:.15e}", i, e).unwrap();
    }
}

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(500);

    header(
        "CATHEDRAL FAST SPECTRAL PROBE (f64/nalgebra)",
        &format!(
            "Hardware-accelerated residue class decomposition · max N = {max_n}"
        ),
        64,
        threads,
    );

    fs::create_dir_all("results").unwrap();

    // Test schedule — can go much higher now
    let all_ns: Vec<usize> = vec![50, 100, 150, 200, 300, 400, 500, 750, 1000]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();

    println!("  {DIM}Test schedule: {all_ns:?}{RESET}");
    println!();

    struct NResult {
        n: usize,
        full_class: &'static str,
        dark_class: &'static str,
        res_classes: [&'static str; 4],
        res_dims: [usize; 4],
    }
    let mut all_results: Vec<NResult> = Vec::new();

    for &n in &all_ns {
        let t_n = Instant::now();

        println!("  {BOLD}{WHITE}═══ N={n} ═══{RESET}");

        // Build Gram matrix (parallel)
        let (full_mat, full_dim) = build_gram_f64(n);

        // Residue class indices
        let res_indices: Vec<Vec<usize>> = RESIDUE_CLASSES
            .iter()
            .map(|&r| residue_indices(n, r))
            .collect();
        let odd_idx = odd_indices(n);
        let even_idx = even_indices(n);

        println!(
            "    dim={full_dim} | k≡1:{} k≡3:{} k≡5:{} k≡7:{} | odd:{} even:{}",
            res_indices[0].len(),
            res_indices[1].len(),
            res_indices[2].len(),
            res_indices[3].len(),
            odd_idx.len(),
            even_idx.len()
        );

        // Eigensolve — FULL (the big one)
        let t_eig = Instant::now();
        let full_eigs = eigenvalues_nalgebra(&full_mat, full_dim);
        let full_t = t_eig.elapsed().as_secs_f64();
        print_eig_row("Full G_N", full_dim, &full_eigs, full_t);
        save_eigenvalues(
            &format!("results/fast_eigenvalues_full_N{n}.tsv"),
            &full_eigs,
        );

        // Eigensolve — residue classes (parallel across classes)
        let res_results: Vec<(Vec<f64>, f64)> = (0..4)
            .into_par_iter()
            .map(|i| {
                let t = Instant::now();
                let sub = project_f64(&full_mat, full_dim, &res_indices[i]);
                let eigs = eigenvalues_nalgebra(&sub, res_indices[i].len());
                (eigs, t.elapsed().as_secs_f64())
            })
            .collect();

        let mut res_eigs: [Vec<f64>; 4] = [vec![], vec![], vec![], vec![]];
        let mut res_dims = [0usize; 4];
        for i in 0..4 {
            print_eig_row(RESIDUE_NAMES[i], res_indices[i].len(), &res_results[i].0, res_results[i].1);
            res_dims[i] = res_indices[i].len();
            res_eigs[i] = res_results[i].0.clone();
        }

        // Eigensolve — odd/even (parallel)
        let (odd_eigs, even_eigs) = rayon::join(
            || {
                let sub = project_f64(&full_mat, full_dim, &odd_idx);
                eigenvalues_nalgebra(&sub, odd_idx.len())
            },
            || {
                let sub = project_f64(&full_mat, full_dim, &even_idx);
                eigenvalues_nalgebra(&sub, even_idx.len())
            },
        );
        print_eig_row("Odd sector", odd_idx.len(), &odd_eigs, 0.0);
        print_eig_row("Dark (even)", even_idx.len(), &even_eigs, 0.0);

        // Level spacing
        println!();
        println!("  {DIM}  channel    │ GOE(β=1) │ Poisson  │ best{RESET}");
        let channels: Vec<(&str, &[f64])> = vec![
            ("Full G_N", &full_eigs),
            (RESIDUE_NAMES[0], &res_eigs[0]),
            (RESIDUE_NAMES[1], &res_eigs[1]),
            (RESIDUE_NAMES[2], &res_eigs[2]),
            (RESIDUE_NAMES[3], &res_eigs[3]),
            ("Odd sector", &odd_eigs),
            ("Dark (even)", &even_eigs),
        ];

        let mut classes = [""; 4];
        let mut full_class = "";
        let mut dark_class = "";

        for (idx, (name, eigs)) in channels.iter().enumerate() {
            let sr = spectral::compute_spacing(eigs);
            let color = if sr.best_class.contains("GOE") {
                GREEN
            } else if sr.best_class.contains("Poisson") {
                YELLOW
            } else {
                WHITE
            };
            println!(
                "  {:<14} │ {:>8.4} │ {:>8.4} │ {color}{}{RESET}",
                name, sr.goe_fit, sr.poisson_fit, sr.best_class
            );
            match idx {
                0 => full_class = sr.best_class,
                1..=4 => classes[idx - 1] = sr.best_class,
                6 => dark_class = sr.best_class,
                _ => {}
            }
        }

        // Cross-channel correlations (compact)
        let rho_17 = spectral::staircase_correlation(&res_eigs[0], &res_eigs[3]);
        let rho_35 = spectral::staircase_correlation(&res_eigs[1], &res_eigs[2]);
        let rho_od = spectral::staircase_correlation(&odd_eigs, &even_eigs);
        println!(
            "    ρ(k≡1,k≡7)={:+.3} ρ(k≡3,k≡5)={:+.3} ρ(odd,dark)={:+.3}",
            rho_17, rho_35, rho_od
        );

        println!(
            "    {DIM}N={n} in {:.1}s{RESET}\n",
            t_n.elapsed().as_secs_f64()
        );

        all_results.push(NResult {
            n,
            full_class,
            dark_class,
            res_classes: classes,
            res_dims,
        });
    }

    // Summary table
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}FAST PROBE SUMMARY — PHASE TRANSITION MAP{RESET}");
    println!("  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}N     │ Full     │ k≡1(8)   │ k≡3(8)   │ k≡5(8)   │ k≡7(8)   │ Dark{RESET}");
    for r in &all_results {
        let fmt_class = |s: &'static str| -> &'static str {
            if s.contains("GOE") {
                "GOE"
            } else if s.contains("Poisson") {
                "Poisson"
            } else if s.is_empty() {
                "N/A"
            } else {
                s
            }
        };
        println!(
            "  {BOLD}{CYAN}║{RESET}  {:<5} │ {:<8} │ {:<8} │ {:<8} │ {:<8} │ {:<8} │ {}",
            r.n,
            fmt_class(r.full_class),
            fmt_class(r.res_classes[0]),
            fmt_class(r.res_classes[1]),
            fmt_class(r.res_classes[2]),
            fmt_class(r.res_classes[3]),
            fmt_class(r.dark_class)
        );
    }
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");

    println!(
        "\n  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads, f64/nalgebra)",
        t0.elapsed().as_secs_f64()
    );
    println!();
}
