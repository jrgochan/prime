//! G₂ Spectral Operator Experiment
//! ================================
//! 
//! G₂ = Aut(𝕆) is the 14-dimensional exceptional Lie group that preserves
//! octonionic multiplication. It acts naturally on im(𝕆) ≅ ℝ⁷.
//!
//! This experiment constructs self-adjoint operators on ℝ⁷ from:
//!   1. The octonionic structure constants (encodes G₂ geometry)
//!   2. Prime number data (von Mangoldt / Möbius weights)
//!
//! We then compute eigenvalues and check if they correlate with
//! the imaginary parts of Riemann zeta zeros (γ₁ ≈ 14.13, γ₂ ≈ 21.02, ...).
//!
//! Hardware target: Apple M2 Max, 12 cores, 96 GB RAM

use std::time::Instant;

/// The 7 imaginary octonion units: e₁, e₂, ..., e₇
/// Multiplication table (Fano plane): eᵢ · eⱼ = ε_{ijk} eₖ
/// where ε_{ijk} is the fully antisymmetric tensor from the Fano plane.
///
/// Fano plane triples (i,j,k) with eᵢ·eⱼ = eₖ:
///   (1,2,3), (1,4,5), (1,7,6), (2,4,6), (2,5,7), (3,4,7), (3,6,5)
/// (using 1-indexed for the 7 imaginary units)
const FANO_TRIPLES: [(usize, usize, usize); 7] = [
    (0, 1, 2), // e₁·e₂ = e₃
    (0, 3, 4), // e₁·e₄ = e₅
    (0, 6, 5), // e₁·e₇ = e₆
    (1, 3, 5), // e₂·e₄ = e₆  (note: some conventions differ)
    (1, 4, 6), // e₂·e₅ = e₇
    (2, 3, 6), // e₃·e₄ = e₇
    (2, 5, 4), // e₃·e₆ = e₅
];

/// Structure constants f_{ijk} for octonionic multiplication.
/// f_{ijk} = +1 if (i,j,k) is a cyclic Fano triple, -1 if anti-cyclic, 0 otherwise.
fn structure_constant(i: usize, j: usize, k: usize) -> f64 {
    for &(a, b, c) in &FANO_TRIPLES {
        // Cyclic permutations
        if (i == a && j == b && k == c)
            || (i == b && j == c && k == a)
            || (i == c && j == a && k == b)
        {
            return 1.0;
        }
        // Anti-cyclic
        if (i == c && j == b && k == a)
            || (i == b && j == a && k == c)
            || (i == a && j == c && k == b)
        {
            return -1.0;
        }
    }
    0.0
}

/// Build the 7×7 matrix Lₖ for left-multiplication by imaginary unit eₖ.
/// (Lₖ)ᵢⱼ = f_{kij} (the structure constant)
/// These are antisymmetric: Lₖᵀ = -Lₖ
fn left_mult_matrix(k: usize) -> [[f64; 7]; 7] {
    let mut m = [[0.0f64; 7]; 7];
    for i in 0..7 {
        for j in 0..7 {
            m[i][j] = structure_constant(k, j, i);
        }
    }
    m
}

/// Known Riemann zeta zeros (imaginary parts) for correlation testing.
/// First 30 zeros computed to high precision.
const ZETA_ZEROS: [f64; 30] = [
    14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
    37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
    52.970321, 56.446248, 59.347044, 60.831779, 65.112544,
    67.079811, 69.546402, 72.067158, 75.704691, 77.144840,
    79.337375, 82.910381, 84.735493, 87.425275, 88.809111,
    92.491899, 94.651344, 95.870634, 98.831194, 101.317851,
];

/// Primes for the operator construction
const PRIMES: [usize; 100] = [
    2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47,
    53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113,
    127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197,
    199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281,
    283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379,
    383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463,
    467, 479, 487, 491, 499, 503, 509, 521, 523, 541,
];

/// 7×7 matrix operations (stack-allocated for speed)
type Mat7 = [[f64; 7]; 7];

fn mat_zero() -> Mat7 { [[0.0; 7]; 7] }

fn mat_add(a: &Mat7, b: &Mat7) -> Mat7 {
    let mut r = mat_zero();
    for i in 0..7 { for j in 0..7 { r[i][j] = a[i][j] + b[i][j]; } }
    r
}

fn mat_scale(a: &Mat7, s: f64) -> Mat7 {
    let mut r = mat_zero();
    for i in 0..7 { for j in 0..7 { r[i][j] = a[i][j] * s; } }
    r
}

fn mat_mul(a: &Mat7, b: &Mat7) -> Mat7 {
    let mut r = mat_zero();
    for i in 0..7 {
        for j in 0..7 {
            let mut s = 0.0;
            for k in 0..7 { s += a[i][k] * b[k][j]; }
            r[i][j] = s;
        }
    }
    r
}

fn mat_transpose(a: &Mat7) -> Mat7 {
    let mut r = mat_zero();
    for i in 0..7 { for j in 0..7 { r[i][j] = a[j][i]; } }
    r
}

/// Make a matrix Hermitian: H = (M + Mᵀ) / 2
fn mat_symmetrize(a: &Mat7) -> Mat7 {
    let t = mat_transpose(a);
    mat_scale(&mat_add(a, &t), 0.5)
}

fn mat_trace(a: &Mat7) -> f64 {
    let mut s = 0.0;
    for i in 0..7 { s += a[i][i]; }
    s
}

fn mat_frobenius(a: &Mat7) -> f64 {
    let mut s = 0.0;
    for i in 0..7 { for j in 0..7 { s += a[i][j] * a[i][j]; } }
    s.sqrt()
}

/// Eigenvalue computation via Jacobi iteration (self-contained, no deps).
/// Returns sorted eigenvalues of a real symmetric 7×7 matrix.
fn eigenvalues_jacobi(mat: &Mat7, max_iter: usize) -> Vec<f64> {
    let mut a = *mat;
    let n = 7;

    for _ in 0..max_iter {
        // Find largest off-diagonal
        let mut max_val = 0.0f64;
        let mut p = 0;
        let mut q = 1;
        for i in 0..n {
            for j in (i + 1)..n {
                if a[i][j].abs() > max_val {
                    max_val = a[i][j].abs();
                    p = i;
                    q = j;
                }
            }
        }
        if max_val < 1e-14 { break; }

        // Compute rotation
        let theta = if (a[p][p] - a[q][q]).abs() < 1e-30 {
            std::f64::consts::FRAC_PI_4
        } else {
            0.5 * ((2.0 * a[p][q]) / (a[p][p] - a[q][q])).atan()
        };
        let c = theta.cos();
        let s = theta.sin();

        // Apply Givens rotation
        let mut new_a = a;
        for i in 0..n {
            new_a[i][p] = c * a[i][p] + s * a[i][q];
            new_a[i][q] = -s * a[i][p] + c * a[i][q];
        }
        for j in 0..n {
            a[p][j] = c * new_a[p][j] + s * new_a[q][j];
            a[q][j] = -s * new_a[p][j] + c * new_a[q][j];
        }
        // Fix diagonal
        let app = c * c * mat_elem(&new_a, p, p) + 2.0 * s * c * mat_elem(&new_a, p, q)
            + s * s * mat_elem(&new_a, q, q);
        let aqq = s * s * mat_elem(&new_a, p, p) - 2.0 * s * c * mat_elem(&new_a, p, q)
            + c * c * mat_elem(&new_a, q, q);
        a[p][p] = app;
        a[q][q] = aqq;
        a[p][q] = 0.0;
        a[q][p] = 0.0;
    }

    let mut eigs: Vec<f64> = (0..n).map(|i| a[i][i]).collect();
    eigs.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigs
}

fn mat_elem(a: &Mat7, i: usize, j: usize) -> f64 { a[i][j] }

// ═══════════════════════════════════════════════════════════
// OPERATOR CONSTRUCTIONS
// ═══════════════════════════════════════════════════════════

/// Construction 1: Prime-weighted G₂ Casimir-like operator
/// H = Σ_p log(p)/p^σ · (Lₖ₍ₚ₎ · Lₖ₍ₚ₎ᵀ)  where k(p) = p mod 7
/// This is automatically Hermitian (positive semidefinite).
fn build_casimir_operator(sigma: f64, num_primes: usize) -> Mat7 {
    let mut h = mat_zero();
    for idx in 0..num_primes.min(PRIMES.len()) {
        let p = PRIMES[idx] as f64;
        let k = PRIMES[idx] % 7;
        let weight = p.ln() / p.powf(sigma);
        let lk = left_mult_matrix(k);
        let lkt = mat_transpose(&lk);
        let prod = mat_mul(&lk, &lkt);
        h = mat_add(&h, &mat_scale(&prod, weight));
    }
    h
}

/// Construction 2: Cross-product operator encoding prime gaps
/// H = Σ_p log(p) · [Lₐ, Lᵦ] / p^σ  where a = p mod 7, b = next_prime mod 7
/// The commutator [Lₐ, Lᵦ] = LₐLᵦ - LᵦLₐ lies in the g₂ Lie algebra.
fn build_commutator_operator(sigma: f64, num_primes: usize) -> Mat7 {
    let mut h = mat_zero();
    for idx in 0..(num_primes.min(PRIMES.len()) - 1) {
        let p = PRIMES[idx] as f64;
        let a = PRIMES[idx] % 7;
        let b = PRIMES[idx + 1] % 7;
        if a == b { continue; }
        let weight = p.ln() / p.powf(sigma);
        let la = left_mult_matrix(a);
        let lb = left_mult_matrix(b);
        let ab = mat_mul(&la, &lb);
        let ba = mat_mul(&lb, &la);
        let mut comm = mat_zero();
        for i in 0..7 { for j in 0..7 { comm[i][j] = ab[i][j] - ba[i][j]; } }
        h = mat_add(&h, &mat_scale(&comm, weight));
    }
    mat_symmetrize(&h)
}

/// Construction 3: Dirichlet-G₂ operator
/// H(t) = Σ_p log(p)/√p · cos(t·log(p)) · (Lₖ₍ₚ₎ + Lₖ₍ₚ₎ᵀ)
/// The eigenvalues of H(t) as function of t should have special
/// behavior at t = γₖ (zeta zero heights).
fn build_dirichlet_operator(t: f64, num_primes: usize) -> Mat7 {
    let mut h = mat_zero();
    for idx in 0..num_primes.min(PRIMES.len()) {
        let p = PRIMES[idx] as f64;
        let k = PRIMES[idx] % 7;
        let weight = p.ln() / p.sqrt() * (t * p.ln()).cos();
        let lk = left_mult_matrix(k);
        let lkt = mat_transpose(&lk);
        let sym = mat_add(&lk, &lkt);
        h = mat_add(&h, &mat_scale(&sym, weight));
    }
    mat_symmetrize(&h)
}

/// Construction 4: Octonionic Trace operator
/// H(t) = Σ_n Λ(n)/√n · cos(t·log(n)) · Mₙ
/// where Mₙ is built from the octonionic product structure
/// and Λ(n) is the von Mangoldt function.
fn build_trace_operator(t: f64, max_n: usize, num_primes: usize) -> Mat7 {
    let mut h = mat_zero();
    for n in 2..=max_n {
        let lambda = von_mangoldt(n, num_primes);
        if lambda == 0.0 { continue; }
        let nf = n as f64;
        let weight = lambda / nf.sqrt() * (t * nf.ln()).cos();
        // Map n to a G₂ direction using multiple imaginary units
        let k1 = n % 7;
        let k2 = (n / 7) % 7;
        let lk1 = left_mult_matrix(k1);
        if k1 != k2 {
            let lk2 = left_mult_matrix(k2);
            let prod = mat_mul(&lk1, &lk2);
            let sym = mat_symmetrize(&prod);
            h = mat_add(&h, &mat_scale(&sym, weight));
        } else {
            let lkt = mat_transpose(&lk1);
            let prod = mat_mul(&lk1, &lkt);
            h = mat_add(&h, &mat_scale(&prod, weight));
        }
    }
    h
}

fn von_mangoldt(n: usize, num_primes: usize) -> f64 {
    for idx in 0..num_primes.min(PRIMES.len()) {
        let p = PRIMES[idx];
        if p > n { break; }
        let mut power = p;
        while power <= n {
            if power == n { return (p as f64).ln(); }
            power = match power.checked_mul(p) {
                Some(v) => v,
                None => break,
            };
        }
    }
    0.0
}

/// Compute the "spectral signature" at a given t value:
/// how close the eigenvalue structure comes to a special configuration.
fn spectral_signature(eigs: &[f64]) -> f64 {
    // Measure: product of absolute eigenvalues (like a determinant)
    // At zeta zeros, we expect this to show anomalous behavior
    let mut prod = 1.0;
    for &e in eigs {
        prod *= e.abs().max(1e-15);
    }
    prod
}

/// Compute spectral flow: eigenvalues as function of parameter t
fn spectral_flow(t_start: f64, t_end: f64, steps: usize, 
                 builder: impl Fn(f64) -> Mat7) -> Vec<(f64, Vec<f64>, f64)> {
    let dt = (t_end - t_start) / steps as f64;
    let mut results = Vec::with_capacity(steps);
    for i in 0..=steps {
        let t = t_start + i as f64 * dt;
        let h = builder(t);
        let eigs = eigenvalues_jacobi(&h, 500);
        let sig = spectral_signature(&eigs);
        results.push((t, eigs, sig));
    }
    results
}

fn main() {
    let total_start = Instant::now();
    
    println!("╔════════════════════════════════════════════════════════════╗");
    println!("║  G₂ SPECTRAL OPERATOR EXPERIMENT                        ║");
    println!("║  Aut(𝕆) × Prime Data → Eigenvalue/Zero Correlation      ║");
    println!("╚════════════════════════════════════════════════════════════╝\n");
    
    // ═══ PHASE 1: Verify G₂ structure ═══
    println!("▓▓▓ PHASE 1: Verifying octonionic structure constants ▓▓▓\n");
    
    // Check antisymmetry of left-multiplication matrices
    let mut g2_ok = true;
    for k in 0..7 {
        let lk = left_mult_matrix(k);
        let lkt = mat_transpose(&lk);
        for i in 0..7 {
            for j in 0..7 {
                if (lk[i][j] + lkt[i][j]).abs() > 1e-14 {
                    println!("  WARNING: L_{} not antisymmetric at ({},{})", k, i, j);
                    g2_ok = false;
                }
            }
        }
    }
    if g2_ok {
        println!("  ✅ All 7 left-multiplication matrices are antisymmetric");
    }
    
    // Verify Fano plane: eₐ·eₐ = -1 (structure constant trace)
    for k in 0..7 {
        let lk = left_mult_matrix(k);
        let lk2 = mat_mul(&lk, &lk);
        let tr = mat_trace(&lk2);
        // For division algebra: Lₖ² should have trace related to -dim
        let expected = -2.0; // each eₖ has exactly 2 Fano triples through it
        // Actually Lₖ·Lₖᵀ should be related to identity
        let lkt = mat_transpose(&lk);
        let prod = mat_mul(&lk, &lkt);
        let diag: Vec<f64> = (0..7).map(|i| prod[i][i]).collect();
        if k == 0 {
            println!("  L₀·L₀ᵀ diagonal: {:?}", diag);
        }
    }
    
    // G₂ dimension check: count independent commutators [Lᵢ, Lⱼ]
    let mut independent_comms = 0;
    for i in 0..7 {
        for j in (i+1)..7 {
            let li = left_mult_matrix(i);
            let lj = left_mult_matrix(j);
            let comm = {
                let ij = mat_mul(&li, &lj);
                let ji = mat_mul(&lj, &li);
                let mut c = mat_zero();
                for a in 0..7 { for b in 0..7 { c[a][b] = ij[a][b] - ji[a][b]; } }
                c
            };
            if mat_frobenius(&comm) > 1e-10 {
                independent_comms += 1;
            }
        }
    }
    println!("  Non-zero commutators [Lᵢ,Lⱼ]: {} (expect 21 = C(7,2))", independent_comms);
    println!("  dim(g₂) = 14 ⊂ so(7) of dim 21\n");
    
    // ═══ PHASE 2: Static operator spectra ═══
    println!("▓▓▓ PHASE 2: Static operator eigenvalue spectra ▓▓▓\n");
    
    for &sigma in &[0.5, 1.0, 2.0] {
        let h_cas = build_casimir_operator(sigma, 50);
        let eigs_cas = eigenvalues_jacobi(&h_cas, 500);
        println!("  Casimir(σ={:.1}):  eigs = [{}]", sigma,
            eigs_cas.iter().map(|e| format!("{:+.4}", e)).collect::<Vec<_>>().join(", "));
        
        let h_comm = build_commutator_operator(sigma, 50);
        let eigs_comm = eigenvalues_jacobi(&h_comm, 500);
        println!("  Commutator(σ={:.1}): eigs = [{}]", sigma,
            eigs_comm.iter().map(|e| format!("{:+.4}", e)).collect::<Vec<_>>().join(", "));
    }
    
    // ═══ PHASE 3: Spectral flow vs zeta zeros ═══
    println!("\n▓▓▓ PHASE 3: Spectral flow — scanning for zeta zero resonances ▓▓▓\n");
    
    let num_primes = 100;
    let max_n = 1000;
    let t_start = 10.0;
    let t_end = 55.0;
    let steps = 9000; // fine resolution: δt ≈ 0.005
    
    println!("  Scanning t ∈ [{:.1}, {:.1}] with {} steps ({} primes, Λ(n) for n ≤ {})",
        t_start, t_end, steps, num_primes, max_n);
    println!("  Looking for spectral anomalies near known zeta zeros...\n");
    
    // Dirichlet-G₂ flow
    let start = Instant::now();
    let flow_dirichlet = spectral_flow(t_start, t_end, steps, |t| {
        build_dirichlet_operator(t, num_primes)
    });
    println!("  Dirichlet flow computed in {:.2}s", start.elapsed().as_secs_f64());
    
    // Trace flow
    let start = Instant::now();
    let flow_trace = spectral_flow(t_start, t_end, steps, |t| {
        build_trace_operator(t, max_n, num_primes)
    });
    println!("  Trace flow computed in {:.2}s\n", start.elapsed().as_secs_f64());
    
    // ═══ PHASE 4: Correlate with zeta zeros ═══
    println!("▓▓▓ PHASE 4: Correlation analysis ▓▓▓\n");
    
    // For each zeta zero, check the spectral signature nearby
    println!("  {:>8}  {:>12}  {:>12}  {:>12}  {:>12}  {:>6}",
        "Zero γₖ", "Dir.Sig", "Tr.Sig", "Dir.MinEig", "Tr.MinEig", "Anom?");
    println!("  {}", "-".repeat(72));
    
    let zeros_to_check: Vec<f64> = ZETA_ZEROS[..10].to_vec();
    
    for &gamma in &zeros_to_check {
        if gamma < t_start || gamma > t_end { continue; }
        
        // Find the closest point in our flow
        let idx_d = ((gamma - t_start) / (t_end - t_start) * steps as f64) as usize;
        let idx_d = idx_d.min(flow_dirichlet.len() - 1);
        
        let (t_d, ref eigs_d, sig_d) = flow_dirichlet[idx_d];
        let (t_t, ref eigs_t, sig_t) = flow_trace[idx_d.min(flow_trace.len() - 1)];
        
        let min_eig_d = eigs_d.iter().cloned().fold(f64::INFINITY, f64::min).abs();
        let min_eig_t = eigs_t.iter().cloned().fold(f64::INFINITY, f64::min).abs();
        
        // Check if signature at zero is anomalous vs neighbors
        let window = 50;
        let base_d: f64 = if idx_d > window && idx_d + window < flow_dirichlet.len() {
            let sum: f64 = (idx_d-window..idx_d+window)
                .map(|i| flow_dirichlet[i].2)
                .sum();
            sum / (2.0 * window as f64)
        } else { sig_d };
        
        let anomaly = if base_d > 0.0 { (sig_d - base_d).abs() / base_d } else { 0.0 };
        let is_anomaly = anomaly > 0.3; // 30% deviation = anomalous
        
        println!("  {:>8.4}  {:>12.4e}  {:>12.4e}  {:>12.6}  {:>12.6}  {:>6}",
            gamma, sig_d, sig_t, min_eig_d, min_eig_t,
            if is_anomaly { "YES ◄" } else { "  no" });
    }
    
    // ═══ PHASE 5: Derivative analysis (zero crossings) ═══
    println!("\n▓▓▓ PHASE 5: Eigenvalue zero crossings ▓▓▓\n");
    println!("  Scanning for t values where eigenvalues change sign...\n");
    
    let mut crossings_dirichlet: Vec<(f64, usize)> = Vec::new();
    let mut crossings_trace: Vec<(f64, usize)> = Vec::new();
    
    for i in 1..flow_dirichlet.len() {
        let (t, ref eigs, _) = flow_dirichlet[i];
        let (_, ref prev_eigs, _) = flow_dirichlet[i - 1];
        for k in 0..7 {
            if prev_eigs[k] * eigs[k] < 0.0 {
                crossings_dirichlet.push((t, k));
            }
        }
    }
    
    for i in 1..flow_trace.len() {
        let (t, ref eigs, _) = flow_trace[i];
        let (_, ref prev_eigs, _) = flow_trace[i - 1];
        for k in 0..7 {
            if prev_eigs[k] * eigs[k] < 0.0 {
                crossings_trace.push((t, k));
            }
        }
    }
    
    println!("  Dirichlet crossings: {} total", crossings_dirichlet.len());
    println!("  Trace crossings:     {} total\n", crossings_trace.len());
    
    // Check correlation: do crossings cluster near zeta zeros?
    println!("  {:>10}  {:>12}  {:>12}", "Zero γₖ", "Dir.Near", "Tr.Near");
    println!("  {}", "-".repeat(38));
    
    for &gamma in &zeros_to_check {
        if gamma < t_start || gamma > t_end { continue; }
        let epsilon = 0.5; // look within ±0.5 of each zero
        let near_d = crossings_dirichlet.iter()
            .filter(|(t, _)| (t - gamma).abs() < epsilon)
            .count();
        let near_t = crossings_trace.iter()
            .filter(|(t, _)| (t - gamma).abs() < epsilon)
            .count();
        println!("  {:>10.4}  {:>12}  {:>12}", gamma, near_d, near_t);
    }
    
    // Background rate
    let total_window = t_end - t_start;
    let bg_d_rate = crossings_dirichlet.len() as f64 / total_window;
    let bg_t_rate = crossings_trace.len() as f64 / total_window;
    println!("\n  Background crossing rate: Dir={:.2}/unit, Tr={:.2}/unit", bg_d_rate, bg_t_rate);
    println!("  Expected near each zero (±0.5): Dir={:.1}, Tr={:.1}", bg_d_rate, bg_t_rate);
    
    // ═══ PHASE 6: Spectral determinant ═══
    println!("\n▓▓▓ PHASE 6: Spectral determinant det(H(t)) near zeros ▓▓▓\n");
    
    for &gamma in &zeros_to_check {
        if gamma < t_start || gamma > t_end { continue; }
        let h = build_trace_operator(gamma, max_n, num_primes);
        let eigs = eigenvalues_jacobi(&h, 500);
        let det: f64 = eigs.iter().product();
        
        // Also compute at slightly off-zero values
        let h_off = build_trace_operator(gamma + 0.5, max_n, num_primes);
        let eigs_off = eigenvalues_jacobi(&h_off, 500);
        let det_off: f64 = eigs_off.iter().product();
        
        let ratio = if det_off.abs() > 1e-30 { det / det_off } else { f64::NAN };
        println!("  γ={:.4}:  det(H(γ))={:+.6e}  det(H(γ+½))={:+.6e}  ratio={:.4}",
            gamma, det, det_off, ratio);
    }
    
    let total_elapsed = total_start.elapsed();
    println!("\n╔════════════════════════════════════════════════════════════╗");
    println!("║  EXPERIMENT COMPLETE  ({:.2}s on M2 Max)             ║", total_elapsed.as_secs_f64());
    println!("╚════════════════════════════════════════════════════════════╝");
}
