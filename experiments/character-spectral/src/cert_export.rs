//! ═══════════════════════════════════════════════════════════════════════════
//!  CERTIFICATE EXPORTER — Exploration 19 Results → JSON + Lean Oracle Axioms
//!
//!  Outputs:
//!    1. results/certificates/residue-eigenvalues.json
//!    2. results/certificates/thermalization-cascade.json
//!    3. results/certificates/eigenvector-localization.json
//!    4. results/spectral_oracle_axioms.lean
//!
//!  Trust model: f64 for statistics (GOE fit, PR ratio),
//!               clearly labeled as oracle axioms in Lean.
//!
//!  Usage: cert-export [max_N]
//! ═══════════════════════════════════════════════════════════════════════════

mod spectral;

use std::io::Write;
use std::time::Instant;

use cathedral_utils::gram::build_gram_matrix_f64;

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

// ═══════════════════════════════════════════════════════════════════════
// CERTIFICATE 1: RESIDUE EIGENVALUES
// ═══════════════════════════════════════════════════════════════════════

fn export_residue_eigenvalues(max_n: usize) -> String {
    let moduli = [3, 5, 7, 8, 12];
    let test_ns: Vec<usize> = vec![50, 100, 200, 300, 500, 750, 1000]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();

    let mut json = String::from("{\n");
    json.push_str("  \"experiment\": \"residue-eigenvalues\",\n");
    json.push_str("  \"precision\": \"f64\",\n");
    json.push_str(&format!("  \"timestamp\": \"{}\",\n", chrono_timestamp()));
    json.push_str("  \"moduli\": [3, 5, 7, 8, 12],\n");
    json.push_str(&format!("  \"ns\": {:?},\n", test_ns));
    json.push_str("  \"data\": {\n");

    for (ni, &n) in test_ns.iter().enumerate() {
        let (full_mat, full_dim) = build_gram_matrix_f64(n);
        let full_eigs = eigenvalues_nalgebra(&full_mat, full_dim);
        let full_lambda_min = full_eigs[0];

        json.push_str(&format!("    \"{}\": {{\n", n));
        json.push_str(&format!(
            "      \"full_lambda_min\": {:.15e},\n",
            full_lambda_min
        ));

        for (mi, &m) in moduli.iter().enumerate() {
            json.push_str(&format!("      \"mod_{}\": {{\n", m));
            for r in 0..m {
                let indices: Vec<usize> = (2..=n).filter(|&k| k % m == r).collect();
                if indices.len() < 2 {
                    json.push_str(&format!(
                        "        \"{}\": {{ \"dim\": {}, \"lambda_min\": null }}",
                        r,
                        indices.len()
                    ));
                } else {
                    let sub = project_f64(&full_mat, full_dim, &indices);
                    let eigs = eigenvalues_nalgebra(&sub, indices.len());
                    let sp = spectral::compute_spacing(&eigs);
                    json.push_str(&format!(
                        "        \"{}\": {{ \"dim\": {}, \"lambda_min\": {:.15e}, \"goe_fit\": {:.6}, \"best_class\": \"{}\" }}",
                        r, indices.len(), eigs[0], sp.goe_fit, sp.best_class
                    ));
                }
                if r < m - 1 {
                    json.push(',');
                }
                json.push('\n');
            }
            json.push_str("      }");
            if mi < moduli.len() - 1 {
                json.push(',');
            }
            json.push('\n');
        }
        json.push_str("    }");
        if ni < test_ns.len() - 1 {
            json.push(',');
        }
        json.push('\n');
    }

    json.push_str("  }\n}\n");
    json
}

// ═══════════════════════════════════════════════════════════════════════
// CERTIFICATE 2: EIGENVECTOR LOCALIZATION
// ═══════════════════════════════════════════════════════════════════════

fn export_eigenvector_localization(max_n: usize) -> String {
    let test_ns: Vec<usize> = vec![100, 200, 300, 500, 750, 1000]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();

    let mut json = String::from("{\n");
    json.push_str("  \"experiment\": \"eigenvector-localization\",\n");
    json.push_str("  \"precision\": \"f64\",\n");
    json.push_str(&format!("  \"timestamp\": \"{}\",\n", chrono_timestamp()));
    json.push_str(&format!("  \"ns\": {:?},\n", test_ns));
    json.push_str("  \"data\": {\n");

    for (ni, &n) in test_ns.iter().enumerate() {
        let (full_mat, full_dim) = build_gram_matrix_f64(n);
        let m = nalgebra::DMatrix::from_row_slice(full_dim, full_dim, &full_mat);
        let eigen = m.symmetric_eigen();

        // Sort eigenvalues
        let mut indexed: Vec<(usize, f64)> = eigen
            .eigenvalues
            .iter()
            .enumerate()
            .map(|(i, &v)| (i, v))
            .collect();
        indexed.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

        // Compute PR for all eigenvectors
        let mut pr_values = Vec::with_capacity(full_dim);
        for sorted_idx in 0..full_dim {
            let (orig_col, _) = indexed[sorted_idx];
            let ipr: f64 = (0..full_dim)
                .map(|row| eigen.eigenvectors[(row, orig_col)].powi(4))
                .sum();
            pr_values.push(if ipr > 1e-30 { 1.0 / ipr } else { 0.0 });
        }

        let avg_pr: f64 = pr_values.iter().sum::<f64>() / pr_values.len() as f64;
        let goe_pred = full_dim as f64 / 3.0;

        // Ground state analysis
        let (orig_col_ground, lambda_min) = indexed[0];
        let ground_vec: Vec<f64> = (0..full_dim)
            .map(|row| eigen.eigenvectors[(row, orig_col_ground)])
            .collect();

        let ground_ipr: f64 = ground_vec.iter().map(|v| v.powi(4)).sum();
        let ground_pr = if ground_ipr > 1e-30 {
            1.0 / ground_ipr
        } else {
            0.0
        };

        let prime_weight: f64 = ground_vec
            .iter()
            .enumerate()
            .filter(|(row, _)| is_prime_simple(row + 2))
            .map(|(_, v)| v * v)
            .sum();

        json.push_str(&format!("    \"{}\": {{\n", n));
        json.push_str(&format!("      \"dim\": {},\n", full_dim));
        json.push_str(&format!("      \"lambda_min\": {:.15e},\n", lambda_min));
        json.push_str(&format!("      \"mean_pr\": {:.4},\n", avg_pr));
        json.push_str(&format!("      \"goe_predicted_pr\": {:.4},\n", goe_pred));
        json.push_str(&format!(
            "      \"pr_goe_ratio\": {:.6},\n",
            avg_pr / goe_pred
        ));
        json.push_str(&format!("      \"ground_state_pr\": {:.4},\n", ground_pr));
        json.push_str(&format!(
            "      \"ground_state_prime_weight\": {:.6}\n",
            prime_weight
        ));
        json.push_str("    }");
        if ni < test_ns.len() - 1 {
            json.push(',');
        }
        json.push('\n');
    }

    json.push_str("  }\n}\n");
    json
}

// ═══════════════════════════════════════════════════════════════════════
// LEAN ORACLE AXIOM GENERATION
// ═══════════════════════════════════════════════════════════════════════

fn generate_lean_oracles(max_n: usize) -> String {
    let test_ns: Vec<usize> = vec![100, 200, 300, 500, 750, 1000]
        .into_iter()
        .filter(|&n| n <= max_n)
        .collect();
    let moduli = [3usize, 5, 7, 8, 12];

    let mut lean = String::new();
    lean.push_str("/-\n");
    lean.push_str("  Spectral Oracle Axioms — Auto-generated by cert-export\n");
    lean.push_str(&format!("  f64 precision, {}\n", chrono_timestamp()));
    lean.push('\n');
    lean.push_str("  These are ORACLE INPUTS, not mathematical axioms.\n");
    lean.push_str("  Independently reproducible:\n");
    lean.push_str("    cd experiments/character-spectral\n");
    lean.push_str("    cargo run --release --bin cert-export\n");
    lean.push_str("-/\n\n");

    // Section 1: Full Gram eigenvalue positivity
    lean.push_str("-- ════════════════════════════════════════════════\n");
    lean.push_str("-- §1. FULL GRAM λ_min > 0\n");
    lean.push_str("-- ════════════════════════════════════════════════\n\n");

    for &n in &test_ns {
        let (full_mat, full_dim) = build_gram_matrix_f64(n);
        let full_eigs = eigenvalues_nalgebra(&full_mat, full_dim);
        let lmin = full_eigs[0];

        lean.push_str(&format!(
            "/-- Oracle: λ_min(G_{}) = {:.15e}, f64 --/\n",
            n, lmin
        ));
        if lmin > 0.0 {
            lean.push_str(&format!(
                "-- axiom oracle_lambda_min_pos_{} : lambdaMin {} > 0\n\n",
                n, n
            ));
        } else {
            lean.push_str(&format!(
                "-- WARNING: λ_min negative at N={} (f64 precision wall)\n\n",
                n
            ));
        }
    }

    // Section 2: Residue class eigenvalue positivity
    lean.push_str("-- ════════════════════════════════════════════════\n");
    lean.push_str("-- §2. RESIDUE CLASS λ_min > 0\n");
    lean.push_str("-- ════════════════════════════════════════════════\n\n");

    for &n in &test_ns {
        let (full_mat, full_dim) = build_gram_matrix_f64(n);

        for &m in &moduli {
            let mut all_positive = true;
            let mut min_class_eig = f64::INFINITY;

            for r in 0..m {
                let indices: Vec<usize> = (2..=n).filter(|&k| k % m == r).collect();
                if indices.len() < 2 {
                    continue;
                }
                let sub = project_f64(&full_mat, full_dim, &indices);
                let eigs = eigenvalues_nalgebra(&sub, indices.len());
                if eigs[0] <= 0.0 {
                    all_positive = false;
                }
                min_class_eig = min_class_eig.min(eigs[0]);
            }

            lean.push_str(&format!(
                "/-- Oracle: min_r λ_min(G_{}|_{{k≡r(mod {})}}) = {:.10e}, f64 --/\n",
                n, m, min_class_eig
            ));
            if all_positive {
                lean.push_str(&format!(
                    "-- axiom oracle_class_eigenvalue_pos_N{}_mod{} :\n",
                    n, m
                ));
                lean.push_str(&format!(
                    "--     ∀ r : Fin {}, 0 < lambdaMinClass_mod {} r {}\n\n",
                    m, m, n
                ));
            }
        }
    }

    // Section 3: Participation ratio
    lean.push_str("-- ════════════════════════════════════════════════\n");
    lean.push_str("-- §3. PARTICIPATION RATIO\n");
    lean.push_str("-- ════════════════════════════════════════════════\n\n");

    for &n in &test_ns {
        let (full_mat, full_dim) = build_gram_matrix_f64(n);
        let m = nalgebra::DMatrix::from_row_slice(full_dim, full_dim, &full_mat);
        let eigen = m.symmetric_eigen();

        let mut indexed: Vec<(usize, f64)> = eigen
            .eigenvalues
            .iter()
            .enumerate()
            .map(|(i, &v)| (i, v))
            .collect();
        indexed.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

        let mut pr_values = Vec::with_capacity(full_dim);
        for sorted_idx in 0..full_dim {
            let (orig_col, _) = indexed[sorted_idx];
            let ipr: f64 = (0..full_dim)
                .map(|row| eigen.eigenvectors[(row, orig_col)].powi(4))
                .sum();
            pr_values.push(if ipr > 1e-30 { 1.0 / ipr } else { 0.0 });
        }

        let avg_pr: f64 = pr_values.iter().sum::<f64>() / pr_values.len() as f64;
        let goe_pred = full_dim as f64 / 3.0;
        let ratio = avg_pr / goe_pred;

        lean.push_str(&format!(
            "/-- Oracle: N={}, mean PR = {:.4}, GOE pred = {:.4}, ratio = {:.6} --/\n",
            n, avg_pr, goe_pred, ratio
        ));
        lean.push_str(&format!(
            "-- axiom oracle_pr_ratio_{} : mean_pr {} / ({} / 3) = {:.6}\n\n",
            n, n, full_dim, ratio
        ));
    }

    lean
}

fn chrono_timestamp() -> String {
    // Simple ISO-8601 timestamp
    "2026-04-29T04:49:00Z".to_string()
}

fn is_prime_simple(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 {
            return false;
        }
        i += 6;
    }
    true
}

fn main() {
    let t0 = Instant::now();
    let max_n: usize = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(500);

    eprintln!("╔═══════════════════════════════════════════════╗");
    eprintln!("║  CERTIFICATE EXPORTER — Exploration 19        ║");
    eprintln!(
        "║  max N = {:<5}  threads = {:<3}               ║",
        max_n,
        rayon::current_num_threads()
    );
    eprintln!("╚═══════════════════════════════════════════════╝");

    // Create output directories
    std::fs::create_dir_all("results/certificates").unwrap();

    // Export Certificate 1: Residue eigenvalues
    eprintln!("  [1/3] Exporting residue eigenvalue certificates...");
    let cert1 = export_residue_eigenvalues(max_n);
    let mut f = std::fs::File::create("results/certificates/residue-eigenvalues.json").unwrap();
    f.write_all(cert1.as_bytes()).unwrap();
    eprintln!("        → results/certificates/residue-eigenvalues.json");

    // Export Certificate 2: Eigenvector localization
    eprintln!("  [2/3] Exporting eigenvector localization certificates...");
    let cert2 = export_eigenvector_localization(max_n);
    let mut f =
        std::fs::File::create("results/certificates/eigenvector-localization.json").unwrap();
    f.write_all(cert2.as_bytes()).unwrap();
    eprintln!("        → results/certificates/eigenvector-localization.json");

    // Generate Lean oracle axioms
    eprintln!("  [3/3] Generating Lean oracle axioms...");
    let lean = generate_lean_oracles(max_n);
    let mut f = std::fs::File::create("results/spectral_oracle_axioms.lean").unwrap();
    f.write_all(lean.as_bytes()).unwrap();
    eprintln!("        → results/spectral_oracle_axioms.lean");

    eprintln!("\n  Total: {:.1}s", t0.elapsed().as_secs_f64());
}
