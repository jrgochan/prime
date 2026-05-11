//! ═══════════════════════════════════════════════════════════════════════════
//!  CATHEDRAL MULTI-MODULUS UNIVERSALITY PROBE
//!
//!  Tests whether the Poisson→GOE thermalization cascade is universal
//!  across different arithmetic moduli, or specific to mod-8 (Fano plane).
//!
//!  CRITICAL CONTROL: If mod-7 shows the same cascade as mod-8,
//!  the Fano plane is coincidental. If it differs, it's physics.
//!
//!  Usage: modulus-probe [max_N] [modulus]
//!         modulus-probe 500           (runs all moduli: 3,5,7,8,12)
//!         modulus-probe 500 7         (runs mod-7 only)
//! ═══════════════════════════════════════════════════════════════════════════

mod spectral;

use cathedral_utils::fmt::*;
use rayon::prelude::*;
use std::time::Instant;

use cathedral_utils::gram::build_gram_matrix_f64;

/// Build full Gram matrix in f64, parallel.

/// Eigenvalues via nalgebra.
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

/// Project to sub-matrix.
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

/// Get indices for residue class k ≡ r (mod m), within 2..=n
fn residue_indices(n: usize, modulus: usize, residue: usize) -> Vec<usize> {
    (2..=n).filter(|&k| k % modulus == residue).collect()
}

/// Get odd-class residues for a modulus (those coprime to 2)
fn odd_residues(modulus: usize) -> Vec<usize> {
    (1..modulus).filter(|&r| r % 2 == 1).collect()
}

/// Get even-class residues for a modulus
fn even_residues(modulus: usize) -> Vec<usize> {
    (1..modulus).filter(|&r| r % 2 == 0).collect()
}

/// Run a single modulus sweep and return the phase transition table.
fn run_modulus(modulus: usize, max_n: usize, test_ns: &[usize]) {
    let odd_res = odd_residues(modulus);
    let even_res = even_residues(modulus);
    let num_odd = odd_res.len();
    let num_even = even_res.len();

    println!(
        "\n  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}"
    );
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}MODULUS = {modulus}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Odd residues: {odd_res:?} ({num_odd} classes){RESET}");
    println!(
        "  {BOLD}{CYAN}║{RESET}  {DIM}Even residues: {even_res:?} ({num_even} classes){RESET}"
    );

    if modulus == 8 {
        println!(
            "  {BOLD}{CYAN}║{RESET}  {YELLOW}⚡ Fano plane PG(2,2): 7 points = (Z/2)³\\{{0}} ← BASELINE{RESET}"
        );
    } else if modulus == 7 {
        println!(
            "  {BOLD}{CYAN}║{RESET}  {RED}⚠ NO Fano structure (6 classes ≠ 7 points) ← CONTROL{RESET}"
        );
    }
    println!(
        "  {BOLD}{CYAN}╠═══════════════════════════════════════════════════════════════════════╣{RESET}"
    );

    // Header
    let mut header = format!("  {BOLD}{CYAN}║{RESET}  {DIM}N     │ Full     │ ");
    for &r in &odd_res {
        header.push_str(&format!("k≡{r}({modulus}) │ "));
    }
    header.push_str(&format!("Dark{RESET}"));
    println!("{header}");

    for &n in test_ns {
        if n > max_n {
            continue;
        }

        let t_n = Instant::now();
        let (full_mat, full_dim) = build_gram_matrix_f64(n);

        // Full eigensolve
        let full_eigs = eigenvalues_nalgebra(&full_mat, full_dim);
        let full_sp = spectral::compute_spacing(&full_eigs);

        // Residue class eigensolves (parallel)
        let res_results: Vec<(usize, Vec<f64>)> = odd_res
            .par_iter()
            .map(|&r| {
                let idx = residue_indices(n, modulus, r);
                if idx.len() < 3 {
                    return (r, vec![]);
                }
                let sub = project_f64(&full_mat, full_dim, &idx);
                (r, eigenvalues_nalgebra(&sub, idx.len()))
            })
            .collect();

        // Dark sector (even indices)
        let even_idx: Vec<usize> = (2..=n).filter(|&k| k % 2 == 0).collect();
        let even_sub = project_f64(&full_mat, full_dim, &even_idx);
        let even_eigs = eigenvalues_nalgebra(&even_sub, even_idx.len());
        let even_sp = spectral::compute_spacing(&even_eigs);

        // Format row
        let fmt_class = |sp: &spectral::SpacingResult| -> &'static str {
            if sp.best_class.contains("GOE") {
                "GOE"
            } else if sp.best_class.contains("Poisson") {
                "Poisson"
            } else {
                sp.best_class
            }
        };
        let color = |sp: &spectral::SpacingResult| -> &'static str {
            if sp.best_class.contains("GOE") {
                GREEN
            } else if sp.best_class.contains("Poisson") {
                YELLOW
            } else {
                WHITE
            }
        };

        let mut row = format!(
            "  {BOLD}{CYAN}║{RESET}  {:<5} │ {}{:<8}{RESET} │ ",
            n,
            color(&full_sp),
            fmt_class(&full_sp)
        );

        for (_, eigs) in &res_results {
            if eigs.len() < 3 {
                row.push_str(&format!("{DIM}N/A      {RESET}│ "));
            } else {
                let sp = spectral::compute_spacing(eigs);
                row.push_str(&format!("{}{:<8}{RESET} │ ", color(&sp), fmt_class(&sp)));
            }
        }

        row.push_str(&format!(
            "{}{}{RESET}",
            color(&even_sp),
            fmt_class(&even_sp)
        ));
        println!("{row}");

        // Print timing for larger N
        if n >= 300 {
            eprintln!(
                "    mod-{modulus} N={n} in {:.1}s",
                t_n.elapsed().as_secs_f64()
            );
        }
    }

    println!(
        "  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}"
    );
}

fn main() {
    let t0 = Instant::now();
    let threads = rayon::current_num_threads();

    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(500);

    let single_mod: Option<usize> = std::env::args().nth(2).and_then(|s| s.parse().ok());

    header(
        "CATHEDRAL MULTI-MODULUS UNIVERSALITY PROBE",
        &format!("Fano control experiment · max N = {max_n}"),
        64,
        threads,
    );

    let test_ns: Vec<usize> = vec![50, 75, 100, 150, 200, 300, 400, 500, 750, 1000]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();

    let moduli = match single_mod {
        Some(m) => vec![m],
        None => vec![3, 5, 7, 8, 12],
    };

    println!("  {DIM}Test schedule: {test_ns:?}{RESET}");
    println!("  {DIM}Moduli: {moduli:?}{RESET}");

    for &m in &moduli {
        run_modulus(m, max_n, &test_ns);
    }

    // Summary comparison
    println!("\n  {BOLD}{WHITE}═══ UNIVERSALITY VERDICT ═══{RESET}");
    println!("  {DIM}If all moduli show the same cascade → universal thermodynamics{RESET}");
    println!("  {DIM}If mod-8 differs from mod-7 → Fano plane is physics{RESET}");

    println!(
        "\n  {BOLD}{WHITE}Total:{RESET} {GREEN}{:.1}s{RESET} ({threads} threads, f64/nalgebra)",
        t0.elapsed().as_secs_f64()
    );
    println!();
}
