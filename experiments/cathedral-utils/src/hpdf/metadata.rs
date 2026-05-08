//! Metadata computation for HPDF files.
//!
//! Computes spectral invariants, structural statistics, and
//! number-theoretic tables from the raw matrix data during the
//! build process. All results are stored as HDF5 groups/attributes.

use hdf5::Group;
use ndarray::Array1;

use crate::arith;
use super::helpers::{write_str_attr, write_scalar_attr};

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
    /// Gershgorin lower bound on λ_min: min_i (G[i,i] - Σ_{j≠i} |G[i,j]|)
    pub gershgorin_lambda_min: f64,
    /// Gershgorin upper bound on λ_max: max_i (G[i,i] + Σ_{j≠i} |G[i,j]|)
    pub gershgorin_lambda_max: f64,
    /// Average off-diagonal magnitude per row — measures "diffuseness".
    pub off_diag_avg: f64,
}

impl StructuralStats {
    /// Compute all structural statistics from a dim×dim row-major matrix.
    pub fn compute(data: &[f64], dim: usize) -> Self {
        let diagonal: Vec<f64> = (0..dim).map(|i| data[i * dim + i]).collect();
        let diag_min = diagonal.iter().cloned().fold(f64::INFINITY, f64::min);
        let diag_max = diagonal.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let trace: f64 = diagonal.iter().sum();

        let row_sums: Vec<f64> = (0..dim).map(|i| {
            (0..dim).map(|j| data[i * dim + j]).sum()
        }).collect();

        // Column L2 norms
        let col_norms: Vec<f64> = (0..dim).map(|j| {
            let s: f64 = (0..dim).map(|i| {
                let v = data[i * dim + j];
                v * v
            }).sum();
            s.sqrt()
        }).collect();

        // Frobenius norm: sqrt(sum of all entries squared)
        // Since symmetric, ‖G‖_F² = Σ_diag g²_ii + 2·Σ_{i<j} g²_ij
        let mut frob_sq = 0.0f64;
        for i in 0..dim {
            frob_sq += data[i * dim + i] * data[i * dim + i];
            for j in (i + 1)..dim {
                frob_sq += 2.0 * data[i * dim + j] * data[i * dim + j];
            }
        }
        let frobenius_norm = frob_sq.sqrt();

        // Rough condition estimate from diagonal extremes
        let condition_estimate = if diag_min > 0.0 { diag_max / diag_min } else { f64::INFINITY };

        // Off-diagonal statistics
        let mut off_diag_max = 0.0f64;
        let mut off_diag_sum = 0.0f64;
        let mut off_diag_count = 0usize;
        for i in 0..dim {
            for j in (i + 1)..dim {
                let v = data[i * dim + j].abs();
                off_diag_max = off_diag_max.max(v);
                off_diag_sum += v;
                off_diag_count += 1;
            }
        }
        let off_diag_avg = if off_diag_count > 0 { off_diag_sum / off_diag_count as f64 } else { 0.0 };

        // Gershgorin disc bounds:
        //   Each eigenvalue lies in at least one disc [G[i,i] - R_i, G[i,i] + R_i]
        //   where R_i = Σ_{j≠i} |G[i,j]|
        let mut gersh_min = f64::INFINITY;
        let mut gersh_max = f64::NEG_INFINITY;
        for i in 0..dim {
            let mut r_i = 0.0f64;
            for j in 0..dim {
                if j != i { r_i += data[i * dim + j].abs(); }
            }
            gersh_min = gersh_min.min(diagonal[i] - r_i);
            gersh_max = gersh_max.max(diagonal[i] + r_i);
        }

        Self {
            diagonal, row_sums, col_norms,
            diag_min, diag_max, trace,
            frobenius_norm, condition_estimate, off_diag_max,
            gershgorin_lambda_min: gersh_min,
            gershgorin_lambda_max: gersh_max,
            off_diag_avg,
        }
    }

    /// Write structural metadata to an HDF5 group.
    pub fn write_to_group(&self, grp: &Group) -> hdf5::Result<()> {
        // Datasets
        let diag_arr = Array1::from(self.diagonal.clone());
        grp.new_dataset_builder().with_data(&diag_arr).create("diagonal")?;

        let rs_arr = Array1::from(self.row_sums.clone());
        grp.new_dataset_builder().with_data(&rs_arr).create("row_sums")?;

        let cn_arr = Array1::from(self.col_norms.clone());
        grp.new_dataset_builder().with_data(&cn_arr).create("col_norms")?;

        // Scalar attributes
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
        let ds = file.new_dataset_builder()
            .with_data(&b_arr)
            .create("b_vector")?;
        write_scalar_attr(&ds, "norm", self.norm)?;
        write_scalar_attr(&ds, "norm_squared", self.norm_squared)?;
        write_scalar_attr(&ds, "sum", self.sum)?;
        write_scalar_attr(&ds, "max_entry", self.max_entry)?;
        write_scalar_attr(&ds, "min_entry", self.min_entry)?;
        write_str_attr(&ds, "formula",
            "b[k] = (ln(k+2) + 1 - gamma) / (k+2), k=0..dim-1")?;
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
    nt_grp.new_dataset_builder().with_data(&mu_arr).create("mobius")?;

    // Euler totient φ(n)
    let phi = arith::euler_totient(max_n);
    let phi_u32: Vec<u32> = phi.iter().map(|&x| x as u32).collect();
    let phi_arr = Array1::from(phi_u32);
    nt_grp.new_dataset_builder().with_data(&phi_arr).create("totient")?;

    // Prime sieve
    let sieve = arith::sieve_primes(max_n);
    let primes: Vec<u32> = (2..=max_n).filter(|&n| sieve[n]).map(|n| n as u32).collect();
    write_scalar_attr(&nt_grp, "prime_count", primes.len() as u64)?;
    let p_arr = Array1::from(primes);
    nt_grp.new_dataset_builder().with_data(&p_arr).create("primes")?;

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
        if n % d == 0 {
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
        dist_grp.new_dataset_builder()
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
        dist_grp.new_dataset_builder()
            .with_data(&h_arr)
            .create("convergence_history")?;
        write_scalar_attr(&dist_grp, "history_len", hist.len() as u64)?;
    }

    Ok(())
}
