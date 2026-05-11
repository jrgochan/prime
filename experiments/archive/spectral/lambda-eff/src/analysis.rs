//! Block eigendecomposition, rank-1 SVD extraction, and λ_eff diagnostics.

use nalgebra::{DMatrix, SymmetricEigen};

/// Result of analyzing a single block (one residue class)
#[derive(Clone, Debug, serde::Serialize)]
pub struct BlockSpectrum {
    /// Residue class index (0-7)
    pub class_idx: usize,
    /// Size of the block
    pub block_size: usize,
    /// Sorted eigenvalues (ascending)
    pub eigenvalues: Vec<f64>,
    /// Minimum eigenvalue
    pub lambda_min: f64,
    /// Median eigenvalue
    pub lambda_median: f64,
    /// Mean eigenvalue
    pub lambda_mean: f64,
}

/// Result of analyzing the rank-1 interference direction between two blocks
#[derive(Clone, Debug, serde::Serialize)]
pub struct CrossBlockAnalysis {
    pub class_i: usize,
    pub class_j: usize,
    /// Top singular value
    pub sigma1: f64,
    /// Second singular value
    pub sigma2: f64,
    /// Rank-1 accuracy: σ₁ / (σ₁ + σ₂ + ... + σ_k)
    pub rank1_accuracy: f64,
    /// The left singular vector (rank-1 direction in class i's eigenbasis)
    pub u_direction: Vec<f64>,
}

/// Full diagnostics for λ_eff at a given N
#[derive(Clone, Debug, serde::Serialize)]
pub struct LambdaEffResult {
    pub n: usize,
    pub class_idx: usize,
    /// λ_eff(m) = (Σ uⱼ²/λⱼ)⁻¹
    pub lambda_eff: f64,
    /// Participation ratio PR = (Σ uⱼ²)² / Σ uⱼ⁴
    pub participation_ratio: f64,
    /// Fraction of Σ uⱼ²/λⱼ from edge eigenvalues (bottom 10%)
    pub edge_fraction: f64,
    /// Fraction of Σ uⱼ²/λⱼ from bulk eigenvalues (top 90%)
    pub bulk_fraction: f64,
    /// Spectral band breakdown: [0, 0.1), [0.1, 0.3), [0.3, ∞)
    pub band_contributions: [f64; 3],
    /// Maximum |uⱼ|² (localization measure)
    pub max_component_sq: f64,
    /// Block spectrum summary
    pub block_lambda_min: f64,
    pub block_lambda_max: f64,
}

/// Eigendecompose a symmetric block matrix.
pub fn eigendecompose(matrix_data: &[f64], dim: usize) -> (Vec<f64>, DMatrix<f64>) {
    let mat = DMatrix::from_row_slice(dim, dim, matrix_data);

    // Symmetrize (should already be symmetric, but floating point)
    let sym = (&mat + mat.transpose()) * 0.5;

    let eigen = SymmetricEigen::new(sym);

    // Get eigenvalues and sort by value
    let mut indexed_eigs: Vec<(usize, f64)> = eigen
        .eigenvalues
        .iter()
        .enumerate()
        .map(|(i, &v)| (i, v))
        .collect();
    indexed_eigs.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

    let sorted_eigenvalues: Vec<f64> = indexed_eigs.iter().map(|&(_, v)| v).collect();

    // Reorder eigenvectors to match sorted eigenvalues
    let n = eigen.eigenvectors.ncols();
    let mut sorted_eigenvectors = DMatrix::zeros(dim, n);
    for (new_idx, &(old_idx, _)) in indexed_eigs.iter().enumerate() {
        sorted_eigenvectors.set_column(new_idx, &eigen.eigenvectors.column(old_idx));
    }

    (sorted_eigenvalues, sorted_eigenvectors)
}

/// Analyze a single block: compute eigendecomposition and basic stats.
pub fn analyze_block(
    matrix_data: &[f64],
    dim: usize,
    class_idx: usize,
) -> (BlockSpectrum, Vec<f64>, DMatrix<f64>) {
    let (eigenvalues, eigenvectors) = eigendecompose(matrix_data, dim);

    let lambda_min = eigenvalues[0];
    let lambda_median = eigenvalues[dim / 2];
    let lambda_mean = eigenvalues.iter().sum::<f64>() / dim as f64;

    let spectrum = BlockSpectrum {
        class_idx,
        block_size: dim,
        eigenvalues: eigenvalues.clone(),
        lambda_min,
        lambda_median,
        lambda_mean,
    };

    (spectrum, eigenvalues, eigenvectors)
}

/// Compute the rank-1 direction and λ_eff for class m, given cross-block interactions.
///
/// The rank-1 interference direction u^(m) is extracted from the SVD of the
/// cross-block matrix M = eigvecs_m^T · G_cross · eigvecs_m', projected into
/// the eigenbasis of block m.
pub fn compute_lambda_eff(
    n: usize,
    class_idx: usize,
    block_eigenvalues: &[f64],
    block_eigenvectors: &DMatrix<f64>,
    cross_matrices: &[(usize, Vec<f64>, usize, usize)], // (other_class, data, rows, cols)
) -> (LambdaEffResult, CrossBlockAnalysis) {
    let dim = block_eigenvalues.len();

    // Aggregate cross-block matrices to find the dominant interference direction.
    // For each cross-block pair (m, m'), compute M_{mm'} in the eigenbasis of block m.
    // Then extract the rank-1 direction via SVD.

    // Sum contribution from all cross-class interactions
    let mut aggregate = DMatrix::zeros(dim, dim);

    let mut best_cross = CrossBlockAnalysis {
        class_i: class_idx,
        class_j: 0,
        sigma1: 0.0,
        sigma2: 0.0,
        rank1_accuracy: 0.0,
        u_direction: vec![0.0; dim],
    };

    for (other_class, cross_data, rows, cols) in cross_matrices {
        let cross = DMatrix::from_row_slice(*rows, *cols, cross_data);

        // Project cross-block matrix into eigenbasis of block m:
        // M_projected = V_m^T · G_cross · V_m (for self-coupling effect)
        // But cross-block is m×m', so we project the left side only
        let projected = block_eigenvectors.transpose() * &cross;

        // Each column of 'projected' maps to an eigenvector of block m'
        // The interference matrix in block m's eigenbasis
        let interaction = &projected * projected.transpose();
        aggregate += &interaction;

        // SVD of the projected cross-block to find rank-1 direction
        let svd = projected.svd(true, false);
        let singular_values = &svd.singular_values;

        if singular_values.len() >= 2 {
            let s1 = singular_values[0];
            let s2 = singular_values[1];
            let total_s: f64 = singular_values.iter().sum();
            let accuracy = if total_s > 0.0 { s1 / total_s } else { 0.0 };

            if s1 > best_cross.sigma1 {
                best_cross.class_j = *other_class;
                best_cross.sigma1 = s1;
                best_cross.sigma2 = s2;
                best_cross.rank1_accuracy = accuracy;

                if let Some(ref u_mat) = svd.u {
                    best_cross.u_direction = u_mat.column(0).iter().cloned().collect();
                }
            }
        }
    }

    // Use the aggregate interaction matrix's dominant eigenvector as THE rank-1 direction
    let agg_eigen = SymmetricEigen::new(aggregate);
    let mut max_idx = 0;
    let mut max_val = f64::NEG_INFINITY;
    for (i, &v) in agg_eigen.eigenvalues.iter().enumerate() {
        if v > max_val {
            max_val = v;
            max_idx = i;
        }
    }
    let u: Vec<f64> = agg_eigen
        .eigenvectors
        .column(max_idx)
        .iter()
        .cloned()
        .collect();

    // Now compute λ_eff = (Σ uⱼ²/λⱼ)⁻¹
    let mut harmonic_sum = 0.0;
    let mut participation_num = 0.0; // (Σ uⱼ²)²
    let mut participation_den = 0.0; // Σ uⱼ⁴
    let mut max_component_sq = 0.0f64;

    // Spectral band breakdown
    let mut band_sums = [0.0f64; 3]; // [0, 0.1), [0.1, 0.3), [0.3, ∞)
    let mut edge_sum = 0.0; // bottom 10% of eigenvalues
    let mut total_sum = 0.0;

    let edge_cutoff = dim / 10; // bottom 10%

    for j in 0..dim {
        let u_sq = u[j] * u[j];
        let lambda_j = block_eigenvalues[j];

        if lambda_j.abs() > 1e-15 {
            let contrib = u_sq / lambda_j;
            harmonic_sum += contrib;
            total_sum += contrib.abs();

            // Band classification
            if lambda_j < 0.1 {
                band_sums[0] += contrib.abs();
            } else if lambda_j < 0.3 {
                band_sums[1] += contrib.abs();
            } else {
                band_sums[2] += contrib.abs();
            }

            if j < edge_cutoff {
                edge_sum += contrib.abs();
            }
        }

        participation_num += u_sq;
        participation_den += u_sq * u_sq;
        max_component_sq = max_component_sq.max(u_sq);
    }

    let lambda_eff = if harmonic_sum.abs() > 1e-15 {
        1.0 / harmonic_sum
    } else {
        f64::INFINITY
    };

    let participation_ratio = if participation_den > 1e-30 {
        (participation_num * participation_num) / participation_den
    } else {
        0.0
    };

    // Normalize band contributions
    if total_sum > 0.0 {
        for b in band_sums.iter_mut() {
            *b /= total_sum;
        }
    }

    let edge_fraction = if total_sum > 0.0 {
        edge_sum / total_sum
    } else {
        0.0
    };

    let result = LambdaEffResult {
        n,
        class_idx,
        lambda_eff,
        participation_ratio,
        edge_fraction,
        bulk_fraction: 1.0 - edge_fraction,
        band_contributions: band_sums,
        max_component_sq,
        block_lambda_min: block_eigenvalues[0],
        block_lambda_max: *block_eigenvalues.last().unwrap_or(&0.0),
    };

    // Update best_cross with the aggregate direction
    best_cross.u_direction = u;

    (result, best_cross)
}
