//! Metadata computation for HPDF files.
//!
//! Computes spectral invariants, structural statistics, and
//! number-theoretic tables from the raw matrix data during the
//! build process. All results are stored as HDF5 groups/attributes.

use hdf5::Group;
use ndarray::Array1;
use rayon::prelude::*;

use super::helpers::{write_scalar_attr, write_str_attr};
use crate::arith;

// ═══════════════════════════════════════════════════════════════
// STRUCTURAL METADATA — /structure group
// ═══════════════════════════════════════════════════════════════

/// Structural statistics computed from the raw matrix.
pub struct StructuralStats {
    pub diagonal: Vec<f64>,
    pub row_sums: Vec<f64>,
    pub col_norms: Vec<f64>,
    pub diag_min: f64,
    pub diag_max: f64,
    pub trace: f64,
    pub frobenius_norm: f64,
    pub condition_estimate: f64,
    pub off_diag_max: f64,
    /// Gershgorin lower bound on λ_min: min_i (G[i,i] − Σ_{j≠i} |G[i,j]|)
    pub gershgorin_lambda_min: f64,
    /// Gershgorin upper bound on λ_max: max_i (G[i,i] + Σ_{j≠i} |G[i,j]|)
    pub gershgorin_lambda_max: f64,
    /// Average off-diagonal magnitude per row — measures "diffuseness".
    pub off_diag_avg: f64,
    // ---- NEW fields ----
    /// ‖G‖₁ = max col sum of |G| (maximum absolute column sum norm).
    pub matrix_1_norm: f64,
    /// ‖G‖_∞ = max row sum of |G| (maximum absolute row sum norm).
    pub matrix_inf_norm: f64,
    /// min_i (G_ii / Σ_{j≠i} |G_ij|). Values > 1 certify diagonal dominance → PD.
    pub diagonal_dominance_ratio: f64,
    /// Minimum value across the entire matrix.
    pub entry_min: f64,
    /// Maximum value across the entire matrix.
    pub entry_max: f64,
    /// Mean of all unique upper-triangle entries (including diagonal).
    pub entry_mean: f64,
    /// Variance of all unique upper-triangle entries.
    pub entry_variance: f64,
    /// max|G_ij - G_ji| — verifies the matrix is symmetric (should be 0).
    pub symmetry_residual: f64,
    /// Σ G_ii² — second moment of the diagonal, used in spectral moment analysis.
    pub diag_sum_sq: f64,
}

impl StructuralStats {
    /// Compute all structural statistics from a dim×dim row-major matrix.
    ///
    /// Uses rayon for row-parallel reduction on the O(N²) passes.
    pub fn compute(data: &[f64], dim: usize) -> Self {
        // Per-row statistics computed in parallel
        struct RowStats {
            diag: f64,
            row_sum: f64,
            off_diag_abs_sum: f64, // Σ_{j≠i} |G_ij| (Gershgorin radius)
            frob_sq_contrib: f64,  // G_ii² + 2·Σ_{j>i} G_ij²
            off_max: f64,
            off_sum: f64, // Σ_{j>i} |G_ij| for off-diag avg
            off_count: usize,
            gersh_min: f64,         // G_ii - R_i
            gersh_max: f64,         // G_ii + R_i
            col_abs_sums: Vec<f64>, // |G_ij| for each column j (for 1-norm)
            col_sq_sums: Vec<f64>,  // G_ij² for each column j (for col norms)
            entry_min: f64,
            entry_max: f64,
            entry_sum: f64,     // Σ_{j>=i} G_ij
            entry_sq_sum: f64,  // Σ_{j>=i} G_ij²
            entry_count: usize, // count of unique entries in this row
            sym_residual: f64,  // max|G_ij - G_ji|
        }

        let row_stats: Vec<RowStats> = (0..dim)
            .into_par_iter()
            .map(|i| {
                let diag = data[i * dim + i];
                let mut row_sum = 0.0f64;
                let mut off_abs_sum = 0.0f64;
                let mut frob_sq = diag * diag; // diagonal contribution
                let mut off_max = 0.0f64;
                let mut off_sum = 0.0f64;
                let mut off_count = 0usize;
                let mut col_abs_sums = vec![0.0f64; dim];
                let mut col_sq_sums = vec![0.0f64; dim];
                let mut e_min = diag;
                let mut e_max = diag;
                let mut e_sum = diag;
                let mut e_sq_sum = diag * diag;
                let mut e_count = 1usize; // diagonal
                let mut sym_res = 0.0f64;

                for j in 0..dim {
                    let v = data[i * dim + j];
                    row_sum += v;
                    col_abs_sums[j] = v.abs();
                    col_sq_sums[j] = v * v;

                    if j != i {
                        let a = v.abs();
                        off_abs_sum += a;
                    }

                    if j > i {
                        let a = v.abs();
                        frob_sq += 2.0 * v * v;
                        off_max = off_max.max(a);
                        off_sum += a;
                        off_count += 1;
                        e_min = e_min.min(v);
                        e_max = e_max.max(v);
                        e_sum += v;
                        e_sq_sum += v * v;
                        e_count += 1;

                        // Symmetry check
                        let v_ji = data[j * dim + i];
                        sym_res = sym_res.max((v - v_ji).abs());
                    }
                }

                let gersh_min = diag - off_abs_sum;
                let gersh_max = diag + off_abs_sum;

                RowStats {
                    diag,
                    row_sum,
                    off_diag_abs_sum: off_abs_sum,
                    frob_sq_contrib: frob_sq,
                    off_max,
                    off_sum,
                    off_count,
                    gersh_min,
                    gersh_max,
                    col_abs_sums,
                    col_sq_sums,
                    entry_min: e_min,
                    entry_max: e_max,
                    entry_sum: e_sum,
                    entry_sq_sum: e_sq_sum,
                    entry_count: e_count,
                    sym_residual: sym_res,
                }
            })
            .collect();

        // Reduce
        let mut diagonal = Vec::with_capacity(dim);
        let mut row_sums = Vec::with_capacity(dim);
        let mut diag_min = f64::INFINITY;
        let mut diag_max = f64::NEG_INFINITY;
        let mut trace = 0.0f64;
        let mut frob_sq = 0.0f64;
        let mut off_diag_max = 0.0f64;
        let mut off_sum_total = 0.0f64;
        let mut off_count_total = 0usize;
        let mut gersh_min = f64::INFINITY;
        let mut gersh_max = f64::NEG_INFINITY;
        let mut inf_norm = 0.0f64; // max row sum of |G|
        let mut col_abs_sums = vec![0.0f64; dim];
        let mut col_sq_sums = vec![0.0f64; dim];
        let mut entry_min = f64::INFINITY;
        let mut entry_max = f64::NEG_INFINITY;
        let mut entry_sum = 0.0f64;
        let mut entry_sq_sum = 0.0f64;
        let mut entry_count = 0usize;
        let mut sym_residual = 0.0f64;
        let mut diag_sum_sq = 0.0f64;
        let mut dd_ratio_min = f64::INFINITY;

        for rs in &row_stats {
            diagonal.push(rs.diag);
            row_sums.push(rs.row_sum);
            diag_min = diag_min.min(rs.diag);
            diag_max = diag_max.max(rs.diag);
            trace += rs.diag;
            diag_sum_sq += rs.diag * rs.diag;

            // Each row i contributes G_ii² + 2·Σ_{j>i} G_ij²
            // Summing all rows gives exactly ‖G‖_F².
            frob_sq += rs.frob_sq_contrib;
            off_diag_max = off_diag_max.max(rs.off_max);
            off_sum_total += rs.off_sum;
            off_count_total += rs.off_count;
            gersh_min = gersh_min.min(rs.gersh_min);
            gersh_max = gersh_max.max(rs.gersh_max);

            // ‖G‖_∞ = max_i Σ_j |G_ij|
            let row_abs_sum: f64 = rs.col_abs_sums.iter().sum();
            inf_norm = inf_norm.max(row_abs_sum);

            // Accumulate column sums for ‖G‖₁
            for (j, &v) in rs.col_abs_sums.iter().enumerate() {
                col_abs_sums[j] += v;
            }
            for (j, &v) in rs.col_sq_sums.iter().enumerate() {
                col_sq_sums[j] += v;
            }

            entry_min = entry_min.min(rs.entry_min);
            entry_max = entry_max.max(rs.entry_max);
            entry_sum += rs.entry_sum;
            entry_sq_sum += rs.entry_sq_sum;
            entry_count += rs.entry_count;
            sym_residual = sym_residual.max(rs.sym_residual);

            // Diagonal dominance: G_ii / R_i where R_i = Σ_{j≠i} |G_ij|
            if rs.off_diag_abs_sum > 0.0 {
                dd_ratio_min = dd_ratio_min.min(rs.diag / rs.off_diag_abs_sum);
            }
        }

        //   row i contributes: G_ii²  (diagonal, counted once)
        //                    + 2 * Σ_{j>i} G_ij²  (upper triangle, counted once)
        //   Summing all i: Σ_i G_ii² + 2 * Σ_{i<j} G_ij² = ‖G‖_F²  ✔
        let frobenius_norm = frob_sq.sqrt();

        let condition_estimate = if diag_min > 0.0 {
            diag_max / diag_min
        } else {
            f64::INFINITY
        };
        let off_diag_avg = if off_count_total > 0 {
            off_sum_total / off_count_total as f64
        } else {
            0.0
        };

        // ‖G‖₁ = max_j Σ_i |G_ij|
        let matrix_1_norm = col_abs_sums.iter().cloned().fold(0.0f64, f64::max);

        // Column L2 norms
        let col_norms: Vec<f64> = col_sq_sums.iter().map(|s| s.sqrt()).collect();

        let entry_mean = if entry_count > 0 {
            entry_sum / entry_count as f64
        } else {
            0.0
        };
        let entry_variance = if entry_count > 1 {
            (entry_sq_sum / entry_count as f64) - entry_mean * entry_mean
        } else {
            0.0
        };

        Self {
            diagonal,
            row_sums,
            col_norms,
            diag_min,
            diag_max,
            trace,
            frobenius_norm,
            condition_estimate,
            off_diag_max,
            gershgorin_lambda_min: gersh_min,
            gershgorin_lambda_max: gersh_max,
            off_diag_avg,
            matrix_1_norm,
            matrix_inf_norm: inf_norm,
            diagonal_dominance_ratio: dd_ratio_min,
            entry_min,
            entry_max,
            entry_mean,
            entry_variance,
            symmetry_residual: sym_residual,
            diag_sum_sq,
        }
    }

    /// Write structural metadata to an HDF5 group.
    pub fn write_to_group(&self, grp: &Group) -> hdf5::Result<()> {
        // Datasets
        let diag_arr = Array1::from(self.diagonal.clone());
        grp.new_dataset_builder()
            .with_data(&diag_arr)
            .create("diagonal")?;

        let rs_arr = Array1::from(self.row_sums.clone());
        grp.new_dataset_builder()
            .with_data(&rs_arr)
            .create("row_sums")?;

        let cn_arr = Array1::from(self.col_norms.clone());
        grp.new_dataset_builder()
            .with_data(&cn_arr)
            .create("col_norms")?;

        // Scalar attributes — original
        write_scalar_attr(grp, "diagonal_min", self.diag_min)?;
        write_scalar_attr(grp, "diagonal_max", self.diag_max)?;
        write_scalar_attr(grp, "trace", self.trace)?;
        write_scalar_attr(grp, "frobenius_norm", self.frobenius_norm)?;
        write_scalar_attr(grp, "condition_estimate", self.condition_estimate)?;
        write_scalar_attr(grp, "off_diagonal_max", self.off_diag_max)?;
        write_scalar_attr(grp, "off_diagonal_avg", self.off_diag_avg)?;

        // Gershgorin spectral bounds
        write_scalar_attr(grp, "gershgorin_lambda_min", self.gershgorin_lambda_min)?;
        write_scalar_attr(grp, "gershgorin_lambda_max", self.gershgorin_lambda_max)?;

        // ---- NEW attributes ----
        write_scalar_attr(grp, "matrix_1_norm", self.matrix_1_norm)?;
        write_scalar_attr(grp, "matrix_inf_norm", self.matrix_inf_norm)?;
        write_scalar_attr(
            grp,
            "diagonal_dominance_ratio",
            self.diagonal_dominance_ratio,
        )?;
        write_scalar_attr(grp, "entry_min", self.entry_min)?;
        write_scalar_attr(grp, "entry_max", self.entry_max)?;
        write_scalar_attr(grp, "entry_mean", self.entry_mean)?;
        write_scalar_attr(grp, "entry_variance", self.entry_variance)?;
        write_scalar_attr(grp, "symmetry_residual", self.symmetry_residual)?;
        write_scalar_attr(grp, "diagonal_sum_sq", self.diag_sum_sq)?;

        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════
// B-VECTOR METADATA
// ═══════════════════════════════════════════════════════════════

/// Precomputed b-vector statistics.
pub struct BVectorStats {
    pub b: Vec<f64>,
    pub norm: f64,
    pub norm_squared: f64,
    pub sum: f64,
    pub max_entry: f64,
    pub min_entry: f64,
}

impl BVectorStats {
    pub fn compute(dim: usize) -> Self {
        let b = arith::b_vector(dim);
        let norm_squared: f64 = b.iter().map(|x| x * x).sum();
        let sum: f64 = b.iter().sum();
        let max_entry = b.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let min_entry = b.iter().cloned().fold(f64::INFINITY, f64::min);
        Self {
            b,
            norm: norm_squared.sqrt(),
            norm_squared,
            sum,
            max_entry,
            min_entry,
        }
    }

    /// Write b-vector as a dataset with rich attributes.
    pub fn write_to_file(&self, file: &hdf5::File) -> hdf5::Result<()> {
        let b_arr = Array1::from(self.b.clone());
        let ds = file
            .new_dataset_builder()
            .with_data(&b_arr)
            .create("b_vector")?;
        write_scalar_attr(&ds, "norm", self.norm)?;
        write_scalar_attr(&ds, "norm_squared", self.norm_squared)?;
        write_scalar_attr(&ds, "sum", self.sum)?;
        write_scalar_attr(&ds, "max_entry", self.max_entry)?;
        write_scalar_attr(&ds, "min_entry", self.min_entry)?;
        write_str_attr(
            &ds,
            "formula",
            "b[k] = (ln(k+2) + 1 - gamma) / (k+2), k=0..dim-1",
        )?;
        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════
// NUMBER THEORY TABLES — /number_theory group
// ═══════════════════════════════════════════════════════════════

/// Write number-theoretic tables and N-specific metadata.
pub fn write_number_theory(file: &hdf5::File, max_n: usize) -> hdf5::Result<()> {
    eprintln!("  \x1b[2m  Computing number-theory tables...\x1b[0m");
    let nt_grp = file.create_group("number_theory")?;

    // Möbius function μ(n)
    let mu = arith::mobius_table(max_n);
    let mu_arr = Array1::from(mu);
    nt_grp
        .new_dataset_builder()
        .with_data(&mu_arr)
        .create("mobius")?;

    // Euler totient φ(n)
    let phi = arith::euler_totient(max_n);
    let phi_u32: Vec<u32> = phi.iter().map(|&x| x as u32).collect();
    let phi_arr = Array1::from(phi_u32);
    nt_grp
        .new_dataset_builder()
        .with_data(&phi_arr)
        .create("totient")?;

    // Prime sieve
    let sieve = arith::sieve_primes(max_n);
    let primes: Vec<u32> = (2..=max_n)
        .filter(|&n| sieve[n])
        .map(|n| n as u32)
        .collect();
    write_scalar_attr(&nt_grp, "prime_count", primes.len() as u64)?;
    let p_arr = Array1::from(primes);
    nt_grp
        .new_dataset_builder()
        .with_data(&p_arr)
        .create("primes")?;

    // N-specific properties
    let factorization = arith::factorize(max_n);
    write_str_attr(&nt_grp, "factorization", &factorization)?;
    write_scalar_attr(&nt_grp, "max_n", max_n as u64)?;

    // Divisor count and sum
    let (tau, sigma) = divisor_stats(max_n);
    write_scalar_attr(&nt_grp, "divisor_count", tau as u64)?;
    write_scalar_attr(&nt_grp, "divisor_sum", sigma as u64)?;

    // Is N highly composite?
    let hc = is_highly_composite(max_n);
    write_scalar_attr(&nt_grp, "is_highly_composite", hc as u32)?;

    Ok(())
}

/// Compute τ(n) (number of divisors) and σ(n) (sum of divisors).
fn divisor_stats(n: usize) -> (usize, usize) {
    let mut tau = 0usize;
    let mut sigma = 0usize;
    for d in 1..=n {
        if n.is_multiple_of(d) {
            tau += 1;
            sigma += d;
        }
    }
    (tau, sigma)
}

/// Quick check: is n highly composite (has more divisors than all smaller n)?
fn is_highly_composite(n: usize) -> bool {
    let (tau_n, _) = divisor_stats(n);
    for k in 1..n {
        let (tau_k, _) = divisor_stats(k);
        if tau_k >= tau_n {
            return false;
        }
    }
    true
}

// ═══════════════════════════════════════════════════════════════
// PROVENANCE — /provenance group
// ═══════════════════════════════════════════════════════════════

/// Write enriched provenance metadata.
pub fn write_provenance(
    file: &hdf5::File,
    config_builder: &str,
    config_precision: u32,
    source_sha256: &str,
    build_time_secs: f64,
) -> hdf5::Result<()> {
    let prov_grp = file.create_group("provenance")?;

    write_str_attr(&prov_grp, "timestamp", &super::helpers::unix_timestamp())?;
    write_str_attr(&prov_grp, "builder", config_builder)?;
    write_scalar_attr(&prov_grp, "precision", config_precision)?;
    write_str_attr(&prov_grp, "source_sha256", source_sha256)?;
    write_scalar_attr(&prov_grp, "hpdf_version", super::HPDF_VERSION)?;

    // Enriched provenance
    write_str_attr(&prov_grp, "git_commit", &super::helpers::git_commit_short())?;
    write_str_attr(&prov_grp, "hostname", &super::helpers::hostname())?;
    write_scalar_attr(&prov_grp, "build_time_secs", build_time_secs)?;

    // Rust/OS info
    write_str_attr(&prov_grp, "rust_version", env!("CARGO_PKG_VERSION"))?;
    write_str_attr(&prov_grp, "target_arch", std::env::consts::ARCH)?;
    write_str_attr(&prov_grp, "target_os", std::env::consts::OS)?;

    Ok(())
}

// ═══════════════════════════════════════════════════════════════
// LINEAGE — /lineage group (for submatrix extraction)
// ═══════════════════════════════════════════════════════════════

/// Lineage metadata for files derived from another HPDF.
pub struct LineageInfo {
    /// Path to the parent HPDF file.
    pub parent_path: String,
    /// SHA-256 of the parent file.
    pub parent_sha256: String,
    /// N of the parent file.
    pub parent_max_n: usize,
    /// How this file was derived (e.g., "submatrix_extraction").
    pub derivation: String,
}

/// Write lineage metadata into an HPDF file.
pub fn write_lineage(file: &hdf5::File, lineage: &LineageInfo) -> hdf5::Result<()> {
    let grp = file.create_group("lineage")?;
    write_str_attr(&grp, "parent_path", &lineage.parent_path)?;
    write_str_attr(&grp, "parent_sha256", &lineage.parent_sha256)?;
    write_scalar_attr(&grp, "parent_max_n", lineage.parent_max_n as u64)?;
    write_str_attr(&grp, "derivation", &lineage.derivation)?;
    write_str_attr(&grp, "timestamp", &super::helpers::unix_timestamp())?;
    Ok(())
}

// ═══════════════════════════════════════════════════════════════
// DISTANCE — /distance group (optional, post-solve)
// ═══════════════════════════════════════════════════════════════

/// Certified distance result to write into an HPDF file.
pub struct DistanceResult {
    pub d_squared: f64,
    pub solver: String,
    pub iterations: u64,
    pub residual_norm: f64,
    pub converged: bool,
    /// Optional: the full solution vector x = G⁻¹b.
    pub solution_vector: Option<Vec<f64>>,
    /// Optional: convergence history (residual at each iteration).
    pub convergence_history: Option<Vec<f64>>,
}

/// Stamp a solved distance result into an existing HPDF file.
pub fn stamp_distance(path: &std::path::Path, result: &DistanceResult) -> hdf5::Result<()> {
    let file = hdf5::File::open_rw(path)?;
    let dist_grp = file.create_group("distance")?;

    write_scalar_attr(&dist_grp, "d_squared", result.d_squared)?;
    write_str_attr(&dist_grp, "solver", &result.solver)?;
    write_scalar_attr(&dist_grp, "iterations", result.iterations)?;
    write_scalar_attr(&dist_grp, "residual_norm", result.residual_norm)?;
    write_scalar_attr(&dist_grp, "converged", result.converged as u32)?;
    write_str_attr(&dist_grp, "timestamp", &super::helpers::unix_timestamp())?;

    // Solution vector x = G⁻¹b (allows independent d² verification: d² = 1 - bᵀx)
    if let Some(ref x) = result.solution_vector {
        let x_arr = Array1::from(x.clone());
        dist_grp
            .new_dataset_builder()
            .with_data(&x_arr)
            .create("solution_vector")?;
        write_scalar_attr(&dist_grp, "solution_dim", x.len() as u64)?;

        // Also store bᵀx for quick verification
        // (the reader can independently compute b and check d² = 1 - bᵀx)
        let b = arith::b_vector(x.len());
        let bt_x: f64 = b.iter().zip(x.iter()).map(|(bi, xi)| bi * xi).sum();
        write_scalar_attr(&dist_grp, "bt_x", bt_x)?;
    }

    // Convergence history: residual norm at each iteration
    if let Some(ref hist) = result.convergence_history {
        let h_arr = Array1::from(hist.clone());
        dist_grp
            .new_dataset_builder()
            .with_data(&h_arr)
            .create("convergence_history")?;
        write_scalar_attr(&dist_grp, "history_len", hist.len() as u64)?;
    }

    Ok(())
}

// ═══════════════════════════════════════════════════════════════
// MICROSCOPE — /microscope group (post-analysis diagnostics)
// ═══════════════════════════════════════════════════════════════

/// Microscope diagnostic result to stamp into an HPDF file.
///
/// Contains the full taper decomposition identity, Gram bound analysis,
/// PNT sub-sums, and cross-check residuals from the Möbius Microscope.
pub struct MicroscopeResult {
    /// N value analyzed
    pub n: usize,
    /// Precision label (e.g. "DD", "HPDF-f64", "f64")
    pub precision: String,

    // Gram bound analysis
    pub vtgv: f64,
    pub btv: f64,
    pub btv_sq: f64,
    pub vtcv: f64,
    pub d2n: f64,
    pub gap: f64,          // 1 - vᵀGv
    pub gap_times_ln: f64, // (1-vᵀGv)·lnN

    // Taper decomposition: vᵀGv = U - 2L/lnN + Q/ln²N
    pub u_sum: f64,
    pub l_sum: f64,
    pub q_sum: f64,
    pub r2: f64, // R₂ = U - 2L/lnN
    pub r2_minus_1: f64,
    pub r2_times_ln: f64, // (R₂-1)·lnN → const
    pub q_over_ln2: f64,  // Q/ln²N
    pub c_recon: f64,     // (1-vᵀGv)·lnN

    // Independent vᵀGv reconstruction from f64 Gram entries
    pub vtgv_recon: f64,
    // Cross-check: |U-2L/lnN+Q/ln²N - vᵀGv|
    pub cross_check_delta: f64,

    // PNT sub-sums
    pub s1: f64,      // Σμ/k → 0
    pub s2: f64,      // Σμlnk/k → -1
    pub s3: f64,      // Σμln²k/k → -2γ
    pub mertens: f64, // M(N) = Σμ(k)
    pub mertens_over_sqrt: f64,

    /// Wall-clock time for the analysis (seconds)
    pub elapsed_secs: f64,
}

/// Stamp microscope diagnostic results into an existing HPDF file.
///
/// Creates or replaces a `/microscope` group with the full taper
/// decomposition, Gram bound analysis, and PNT sub-sums. Idempotent:
/// if `/microscope` already exists it is deleted and recreated.
pub fn stamp_microscope(path: &std::path::Path, result: &MicroscopeResult) -> hdf5::Result<()> {
    let file = hdf5::File::open_rw(path)?;

    // Idempotent: remove old group if it exists
    if file.group("microscope").is_ok() {
        file.unlink("microscope")?;
    }

    let grp = file.create_group("microscope")?;
    write_str_attr(&grp, "timestamp", &super::helpers::unix_timestamp())?;
    write_scalar_attr(&grp, "N", result.n as u64)?;
    write_str_attr(&grp, "precision", &result.precision)?;
    write_scalar_attr(&grp, "elapsed_secs", result.elapsed_secs)?;

    // Gram bound analysis
    let gram_grp = grp.create_group("gram_bound")?;
    write_scalar_attr(&gram_grp, "vtGv", result.vtgv)?;
    write_scalar_attr(&gram_grp, "btv", result.btv)?;
    write_scalar_attr(&gram_grp, "btv_sq", result.btv_sq)?;
    write_scalar_attr(&gram_grp, "vtCv", result.vtcv)?;
    write_scalar_attr(&gram_grp, "d2N", result.d2n)?;
    write_scalar_attr(&gram_grp, "gap_1_minus_vtGv", result.gap)?;
    write_scalar_attr(&gram_grp, "gap_times_lnN", result.gap_times_ln)?;

    // Taper decomposition
    let taper_grp = grp.create_group("taper")?;
    write_scalar_attr(&taper_grp, "U", result.u_sum)?;
    write_scalar_attr(&taper_grp, "L", result.l_sum)?;
    write_scalar_attr(&taper_grp, "Q", result.q_sum)?;
    write_scalar_attr(&taper_grp, "R2", result.r2)?;
    write_scalar_attr(&taper_grp, "R2_minus_1", result.r2_minus_1)?;
    write_scalar_attr(&taper_grp, "R2_minus_1_times_lnN", result.r2_times_ln)?;
    write_scalar_attr(&taper_grp, "Q_over_ln2N", result.q_over_ln2)?;
    write_scalar_attr(&taper_grp, "C_recon", result.c_recon)?;
    write_scalar_attr(&taper_grp, "vtGv_recon", result.vtgv_recon)?;
    write_scalar_attr(&taper_grp, "cross_check_delta", result.cross_check_delta)?;

    // PNT sub-sums
    let pnt_grp = grp.create_group("pnt")?;
    write_scalar_attr(&pnt_grp, "S1_mu_over_k", result.s1)?;
    write_scalar_attr(&pnt_grp, "S2_mu_lnk_over_k", result.s2)?;
    write_scalar_attr(&pnt_grp, "S3_mu_ln2k_over_k", result.s3)?;
    write_scalar_attr(&pnt_grp, "mertens", result.mertens)?;
    write_scalar_attr(&pnt_grp, "mertens_over_sqrt", result.mertens_over_sqrt)?;

    Ok(())
}
