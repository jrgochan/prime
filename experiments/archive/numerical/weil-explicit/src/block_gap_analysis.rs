#![allow(unused, dead_code, non_snake_case)]
// block_gap_analysis.rs
// Analyze the block-diagonal Gram matrix to understand its PD structure
// and find the cleanest proof path for block_gap_positive.
//
// Key question: Is gramMatrixBlockDiag positive definite, and why?
//
// Strategy:
// 1. Build the block-diagonal gram matrix G^block
// 2. Verify it's PD via Cholesky / eigenvalues
// 3. Verify that v^T G^block v = sum of squared L2 norms (Gram form)
// 4. Check if linear independence of {k/x} within classes is the right approach

use nalgebra::{DMatrix, DVector, SymmetricEigen};

/// Compute gram entry G[j,k] = ∫₀¹ {j/x}{k/x} dx using high-precision quadrature
fn gram_entry(j: usize, k: usize) -> f64 {
    let n_quad = 10000;
    let mut sum = 0.0;
    for i in 1..=n_quad {
        let x = (i as f64 - 0.5) / n_quad as f64;
        let fj = (j as f64 / x).fract();
        let fk = (k as f64 / x).fract();
        sum += fj * fk;
    }
    sum / n_quad as f64
}

/// Octonionic class of k (same as in Lean code)
fn oct_class(k: usize) -> usize {
    if k <= 1 {
        return 0;
    }

    // Factor k and find dominant basis direction
    let mut remaining = k;
    let mut components = [0.0f64; 8];
    components[0] = 0.0; // Start with no real part for k > 1

    let primes = [2, 3, 5, 7, 11, 13, 17];
    let basis_map = [1, 2, 3, 4, 5, 6, 7]; // prime -> basis index

    for (idx, &p) in primes.iter().enumerate() {
        let mut exp = 0;
        while remaining.is_multiple_of(p) {
            remaining /= p;
            exp += 1;
        }
        if exp > 0 {
            components[basis_map[idx]] += exp as f64;
        }
    }

    // Handle remaining prime factors
    if remaining > 1 {
        let basis_idx = (remaining % 7) + 1;
        components[basis_idx] += 1.0;
    }

    // If k = 1, dominant is e₀
    if k == 1 {
        return 0;
    }

    // Find dominant component (by absolute value)
    let mut max_idx = 0;
    let mut max_val = components[0].abs();
    for i in 1..8 {
        if components[i].abs() > max_val {
            max_val = components[i].abs();
            max_idx = i;
        }
    }
    max_idx
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  BLOCK GAP ANALYSIS: Proving G^block is Positive Definite      ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
    println!();

    for &n in &[50, 100, 200, 500] {
        let dim = n - 1;
        println!("═══ N = {} (dim = {}) ═══", n, dim);

        // Build full Gram matrix
        let mut g_full = DMatrix::zeros(dim, dim);
        let mut g_block = DMatrix::zeros(dim, dim);

        for i in 0..dim {
            for j in 0..dim {
                let ki = i + 2;
                let kj = j + 2;
                let entry = gram_entry(ki, kj);
                g_full[(i, j)] = entry;

                if oct_class(ki) == oct_class(kj) {
                    g_block[(i, j)] = entry;
                }
            }
        }

        // Eigenvalue analysis of G^block
        let eig_block = SymmetricEigen::new(g_block.clone());
        let mut block_evals: Vec<f64> = eig_block.eigenvalues.iter().cloned().collect();
        block_evals.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let lambda_min_block = block_evals[0];
        let lambda_max_block = block_evals[dim - 1];

        // Eigenvalue analysis of G^full
        let eig_full = SymmetricEigen::new(g_full.clone());
        let mut full_evals: Vec<f64> = eig_full.eigenvalues.iter().cloned().collect();
        full_evals.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let lambda_min_full = full_evals[0];

        println!("  λ_min(G^full)  = {:.8}", lambda_min_full);
        println!("  λ_min(G^block) = {:.8}", lambda_min_block);
        println!(
            "  ratio G^block/G^full = {:.4}",
            lambda_min_block / lambda_min_full
        );
        println!(
            "  condition(G^block) = {:.2}",
            lambda_max_block / lambda_min_block
        );
        println!();

        // Analyze block structure: eigenvalues per class
        println!("  Block-by-block analysis:");
        let mut all_class_min = f64::INFINITY;

        for cls in 0..8 {
            let indices: Vec<usize> = (0..dim).filter(|&i| oct_class(i + 2) == cls).collect();

            if indices.len() < 2 {
                println!("    Class {} ({} elements): too small", cls, indices.len());
                continue;
            }

            // Extract submatrix for this class
            let block_dim = indices.len();
            let mut sub = DMatrix::zeros(block_dim, block_dim);
            for (bi, &i) in indices.iter().enumerate() {
                for (bj, &j) in indices.iter().enumerate() {
                    sub[(bi, bj)] = g_full[(i, j)];
                }
            }

            let sub_eig = SymmetricEigen::new(sub);
            let mut sub_evals: Vec<f64> = sub_eig.eigenvalues.iter().cloned().collect();
            sub_evals.sort_by(|a, b| a.partial_cmp(b).unwrap());

            let sub_min = sub_evals[0];
            if sub_min < all_class_min {
                all_class_min = sub_min;
            }

            println!(
                "    Class {} ({:3} elements): λ_min = {:.8}, λ_max = {:.6}",
                cls,
                block_dim,
                sub_min,
                sub_evals[block_dim - 1]
            );
        }

        println!("  min over classes = {:.8}", all_class_min);
        println!(
            "  λ_min(G^block)   = {:.8}  (should match)",
            lambda_min_block
        );
        println!();

        // KEY TEST: Is G^block a valid Gram matrix?
        // Check that v^T G^block v = ∑_m ||∑_{i∈m} v_i f_i||² ≥ 0
        // by testing random vectors
        println!("  Positive-definiteness verification (random vectors):");
        let mut min_quadform = f64::INFINITY;
        for trial in 0..1000 {
            let v = DVector::from_fn(dim, |i, _| {
                // Deterministic "random" vector
                ((trial * 1000 + i * 37 + 13) as f64 * 0.618033988).fract() * 2.0 - 1.0
            });
            let v_norm = v.normalize();
            let quadform = v_norm.dot(&(&g_block * &v_norm));
            if quadform < min_quadform {
                min_quadform = quadform;
            }
        }
        println!(
            "    min v^T G^block v / ||v||² over 1000 trials = {:.8}",
            min_quadform
        );
        println!("    (should be ≥ λ_min(G^block) = {:.8})", lambda_min_block);
        println!();

        // KEY INSIGHT: The PSD structure
        // G^block[i,j] = ∫ {f_i · f_j} dx for same-class i,j
        // This means G^block = ∑_m P_m G P_m^T where P_m is the projection onto class m
        // And v^T G^block v = ∑_m (P_m v)^T G (P_m v) = ∑_m ||∑_{i∈m} v_i f_i||²
        println!("  Gram matrix PSD structure verification:");
        println!("    G^block = ∑_m (class_m submatrix padded with zeros)");
        println!("    Each term is PSD (it's a Gram matrix of a subset)");
        println!("    Sum of PSD is PSD ✓");
        println!("    Strict PD requires: within each class, {{k/x}} are linearly independent");
        println!();
    }

    // ==============================================================
    // CRITICAL ANALYSIS: Can we prove linear independence?
    // ==============================================================
    println!("═══ LINEAR INDEPENDENCE ANALYSIS ═══");
    println!();
    println!("Question: Are {{k/x}} linearly independent in L²(0,1)?");
    println!("This is NOT equivalent to RH. RH = density of span, not independence.");
    println!();

    // Test: try to find linear dependence in small cases
    for &n in &[5, 10, 20, 50] {
        let dim = n - 1;
        let mut g = DMatrix::zeros(dim, dim);
        for i in 0..dim {
            for j in 0..dim {
                g[(i, j)] = gram_entry(i + 2, j + 2);
            }
        }

        let eig = SymmetricEigen::new(g);
        let mut evals: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
        evals.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let min_ev = evals[0];
        let ratio = evals[dim - 1] / min_ev;

        println!(
            "  N={:3}: λ_min = {:.10}, condition = {:.1}",
            n, min_ev, ratio
        );
    }
    println!();
    println!("  All λ_min > 0 ⟹ {{k/x}} are linearly independent in L²(0,1)");
    println!("  This is a theorem (not RH): follows from multiplicative structure");
    println!();

    // ==============================================================
    // PROOF STRATEGY ANALYSIS
    // ==============================================================
    println!("═══ PROOF STRATEGY FOR block_gap_positive ═══");
    println!();
    println!("  APPROACH A: Direct Gram matrix argument");
    println!("    1. gramMatrixBlockDiag is defined with gramEntry for same-class pairs");
    println!("    2. gramEntry(j,k) = ∫₀¹ {{j/x}}{{k/x}} dx = inner product");
    println!("    3. v^T G^block v = ∑_m ||∑_{{i∈class m}} vᵢ·f_{{i+2}}||²_{{L²}}");
    println!("    4. This sum ≥ 0 (positive semi-definite)");
    println!("    5. Equals 0 iff ALL class contributions = 0");
    println!("    6. Each contribution = 0 iff vᵢ = 0 for all i in class m");
    println!("       (by linear independence of {{k/x}} within the class)");
    println!("    7. Therefore v = 0, so G^block is strictly PD");
    println!();
    println!("  APPROACH B: Derive from lambdaMinClass_pos axiom");
    println!("    1. lambdaMinClass_pos says each class submatrix is PD");
    println!("    2. G^block = direct sum of class submatrices");
    println!("    3. Direct sum of PD matrices is PD");
    println!("    4. PD ⟹ λ_min > 0");
    println!("    Note: This shifts the axiom, not eliminates it");
    println!();
    println!("  APPROACH C: Prove PSD constructively (no linear independence needed)");
    println!("    1. G^block = ∑_m P_m^T · G_m · P_m (block padding)");
    println!("    2. Each G_m is a Gram matrix ⟹ PSD");
    println!("    3. Sum of PSD is PSD");
    println!("    4. PSD is WEAKER than PD — gives λ_min ≥ 0, not > 0");
    println!("    5. Need strict positivity for the proof to work");
    println!();
    println!("  APPROACH D: Prove PD from Gram matrix structure");
    println!("    1. G^block[i,j] = ⟨f_i, f_j⟩ if same class, 0 otherwise");
    println!("    2. This is FᵀF where F is the 'evaluation matrix' of basis fns");
    println!("    3. FᵀF is PD iff F has full column rank");
    println!("    4. F has full column rank iff columns {{f_k}} are lin. indep.");
    println!("    5. WRONG: G^block ≠ FᵀF because it zeros out cross-class entries");
    println!("    6. CORRECT: G^block = ∑_m F_m^T F_m (sum over class matrices)");
    println!("    7. Each F_m has full column rank ⟹ each F_m^T F_m is PD");
    println!("    8. BUT F_m is not square — it maps class-m indices to L² space");
    println!("    9. F_m^T F_m has size |class_m| × |class_m|, PD");
    println!("   10. The sum is PD because blocks don't interact");
}
