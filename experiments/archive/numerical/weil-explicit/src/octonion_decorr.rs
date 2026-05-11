#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use nalgebra::{DMatrix, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// OCTONIONIC DECORRELATION OF THE GRAM MATRIX
//
// Key Idea: Map integers to unit octonions via prime factorization.
// The octonionic inner product Re(φ̄(j)·φ(k)) naturally decorrelates
// numbers with different numbers of prime factors (even vs odd Ω).
//
// If this blocks the Liouville cancellation, G^𝕆 could have a LARGER
// and more PROVABLE spectral gap than the real G.
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

/// Octonion: 8-dimensional normed division algebra
#[derive(Clone, Debug)]
struct Oct {
    c: [f64; 8],
}

impl Oct {
    fn new(c: [f64; 8]) -> Self { Self { c } }
    fn real(a: f64) -> Self { Self { c: [a,0.0,0.0,0.0,0.0,0.0,0.0,0.0] } }
    fn basis(i: usize) -> Self {
        let mut c = [0.0; 8];
        c[i] = 1.0;
        Self { c }
    }

    fn norm_sq(&self) -> f64 { self.c.iter().map(|x| x*x).sum() }
    fn norm(&self) -> f64 { self.norm_sq().sqrt() }

    fn conj(&self) -> Self {
        let mut c = self.c;
        for i in 1..8 { c[i] = -c[i]; }
        Self { c }
    }

    fn scale(&self, s: f64) -> Self {
        let mut c = self.c;
        for x in c.iter_mut() { *x *= s; }
        Self { c }
    }

    /// Re(self) = real component
    fn re(&self) -> f64 { self.c[0] }

    /// Octonionic multiplication using the Fano plane
    /// e_i · e_j = ε_{ijk} e_k for the 7 cycles:
    /// (1,2,3), (1,4,5), (1,7,6), (2,4,6), (2,5,7), (3,4,7), (3,6,5)
    fn mul(&self, other: &Self) -> Self {
        let a = &self.c;
        let b = &other.c;
        // Full octonion multiplication
        // Using the standard Cayley table
        let mut c = [0.0; 8];

        // e0 component (real part)
        c[0] = a[0]*b[0] - a[1]*b[1] - a[2]*b[2] - a[3]*b[3]
              - a[4]*b[4] - a[5]*b[5] - a[6]*b[6] - a[7]*b[7];

        // e1 component
        c[1] = a[0]*b[1] + a[1]*b[0] + a[2]*b[3] - a[3]*b[2]
              + a[4]*b[5] - a[5]*b[4] - a[6]*b[7] + a[7]*b[6];

        // e2 component
        c[2] = a[0]*b[2] - a[1]*b[3] + a[2]*b[0] + a[3]*b[1]
              + a[4]*b[6] + a[5]*b[7] - a[6]*b[4] - a[7]*b[5];

        // e3 component
        c[3] = a[0]*b[3] + a[1]*b[2] - a[2]*b[1] + a[3]*b[0]
              + a[4]*b[7] - a[5]*b[6] + a[6]*b[5] - a[7]*b[4];

        // e4 component
        c[4] = a[0]*b[4] - a[1]*b[5] - a[2]*b[6] - a[3]*b[7]
              + a[4]*b[0] + a[5]*b[1] + a[6]*b[2] + a[7]*b[3];

        // e5 component
        c[5] = a[0]*b[5] + a[1]*b[4] - a[2]*b[7] + a[3]*b[6]
              - a[4]*b[1] + a[5]*b[0] - a[6]*b[3] + a[7]*b[2];

        // e6 component
        c[6] = a[0]*b[6] + a[1]*b[7] + a[2]*b[4] - a[3]*b[5]
              - a[4]*b[2] + a[5]*b[3] + a[6]*b[0] - a[7]*b[1];

        // e7 component
        c[7] = a[0]*b[7] - a[1]*b[6] + a[2]*b[5] + a[3]*b[4]
              - a[4]*b[3] - a[5]*b[2] + a[6]*b[1] + a[7]*b[0];

        Self { c }
    }

    /// Octonionic inner product: Re(ā · b)
    fn inner(&self, other: &Self) -> f64 {
        self.conj().mul(other).re()
    }
}

/// Factorize n into primes (returns list of prime factors with multiplicity)
fn prime_factors(mut n: usize) -> Vec<usize> {
    let mut factors = Vec::new();
    let mut p = 2;
    while p * p <= n {
        while n % p == 0 {
            factors.push(p);
            n /= p;
        }
        p += 1;
    }
    if n > 1 { factors.push(n); }
    factors
}

/// Map prime to octonion basis element (mod 7, into e1..e7)
fn prime_to_basis(p: usize) -> usize {
    // Map first few primes to distinct basis elements
    match p {
        2 => 1, 3 => 2, 5 => 3, 7 => 4,
        11 => 5, 13 => 6, 17 => 7,
        _ => ((p % 7) + 1), // Wrap around for larger primes
    }
}

/// Map integer to unit octonion via multiplicative extension
/// φ(k) = product of basis elements for prime factors
fn int_to_octonion(k: usize) -> Oct {
    if k <= 1 { return Oct::real(1.0); }
    let factors = prime_factors(k);
    let mut result = Oct::real(1.0);
    for &p in &factors {
        let basis_idx = prime_to_basis(p);
        result = result.mul(&Oct::basis(basis_idx));
    }
    // Normalize to unit norm (should already be ~1 for small k)
    let n = result.norm();
    if n > 1e-10 { result.scale(1.0 / n) } else { Oct::real(1.0) }
}

fn liouville(n: usize) -> i32 {
    let mut val = n;
    let mut omega = 0;
    let mut p = 2;
    while p * p <= val {
        while val % p == 0 { omega += 1; val /= p; }
        p += 1;
    }
    if val > 1 { omega += 1; }
    if omega % 2 == 0 { 1 } else { -1 }
}

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let dx = 1.0 / n_pts as f64;
    let mut sum = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        sum += frac_part(jf / x) * frac_part(kf / x);
    }
    sum * dx
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  OCTONIONIC DECORRELATION — GRAM MATRIX SPECTRAL GAP           ║");
    println!("║  G^𝕆[j,k] = Re(φ̄(j)·φ(k)) · G[j,k]                        ║");
    println!("║  Does the octonionic weight block Liouville cancellation?       ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 500_000;
    let total_start = std::time::Instant::now();

    // ═══════════════════════════════════════════════════════
    // SECTION 1: Octonionic map properties
    // ═══════════════════════════════════════════════════════
    println!("═══ Section 1: Octonionic map φ(k) ═══\n");
    println!("  {:>5} {:>6} {:>8} {:>10} {:>8} {:>42}",
        "k", "Ω(k)", "λ(k)", "|φ(k)|", "Re(φ)", "φ(k)");
    println!("  {}", "─".repeat(82));

    for k in 2..=30 {
        let phi = int_to_octonion(k);
        let factors = prime_factors(k);
        let omega = factors.len();
        let lio = liouville(k);
        let components: String = phi.c.iter()
            .map(|&x| if x.abs() < 1e-10 { format!("{:5.1}", 0.0) } else { format!("{:5.1}", x) })
            .collect::<Vec<_>>().join(",");
        println!("  {:5} {:6} {:8} {:10.6} {:8.4} [{}]",
            k, omega, lio, phi.norm(), phi.re(), components);
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 2: Octonionic inner products by Ω parity
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 2: Octonionic inner products Re(φ̄(j)·φ(k)) ═══\n");
    println!("  Testing decorrelation between even-Ω and odd-Ω numbers:\n");

    let mut same_parity_sum = 0.0f64;
    let mut diff_parity_sum = 0.0f64;
    let mut same_count = 0;
    let mut diff_count = 0;

    let max_k = 200;
    let phis: Vec<Oct> = (0..=max_k).map(|k| int_to_octonion(k)).collect();
    let omegas: Vec<usize> = (0..=max_k).map(|k| prime_factors(k).len()).collect();

    for j in 2..=max_k {
        for k in (j+1)..=max_k {
            let inner = phis[j].inner(&phis[k]);
            if omegas[j] % 2 == omegas[k] % 2 {
                same_parity_sum += inner.abs();
                same_count += 1;
            } else {
                diff_parity_sum += inner.abs();
                diff_count += 1;
            }
        }
    }

    let avg_same = same_parity_sum / same_count as f64;
    let avg_diff = diff_parity_sum / diff_count as f64;
    println!("  Average |Re(φ̄·φ)| for same Ω-parity:     {:.6} ({} pairs)", avg_same, same_count);
    println!("  Average |Re(φ̄·φ)| for different Ω-parity: {:.6} ({} pairs)", avg_diff, diff_count);
    println!("  Decorrelation ratio (want << 1):           {:.4}", avg_diff / avg_same);

    // Show specific examples
    println!("\n  Examples:");
    println!("  {:>5} {:>5} {:>4} {:>4} {:>12} {:>8}",
        "j", "k", "Ω_j", "Ω_k", "Re(φ̄·φ)", "decorr?");
    println!("  {}", "─".repeat(42));
    let examples = vec![
        (2, 3), (2, 6), (4, 9), (6, 10), (2, 4), (3, 5), (6, 15), (4, 6),
        (30, 42), (12, 18), (2, 30), (3, 70),
    ];
    for (j, k) in examples {
        if j <= max_k && k <= max_k {
            let inner = phis[j].inner(&phis[k]);
            let same = omegas[j] % 2 == omegas[k] % 2;
            println!("  {:5} {:5} {:4} {:4} {:12.6} {:>8}",
                j, k, omegas[j], omegas[k], inner,
                if same { "same" } else { "DIFF ✨" });
        }
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 3: Spectral gap comparison G vs G^𝕆
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 3: Spectral gap — G vs G^𝕆 ═══\n");
    println!("  {:>6} {:>14} {:>14} {:>10} {:>10}",
        "N", "λ_min(G)", "λ_min(G^𝕆)", "ratio", "improved?");
    println!("  {}", "─".repeat(56));

    let mut g_data: Vec<(f64, f64, f64)> = Vec::new(); // (N, lmin_g, lmin_go)

    for &n in &[20, 50, 100, 200, 300, 500, 800] {
        let dim = n - 1;
        let start = std::time::Instant::now();

        // Build G and G^𝕆
        let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
            .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                ((i, j), gram_entry(i + 2, j + 2, n_pts))
            })).collect();

        let oct_map: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();

        let mut g_mat = DMatrix::<f64>::zeros(dim, dim);
        let mut go_mat = DMatrix::<f64>::zeros(dim, dim);

        for ((i, j), g_val) in &entries {
            let weight = oct_map[*i].inner(&oct_map[*j]);
            g_mat[(*i, *j)] = *g_val;
            g_mat[(*j, *i)] = *g_val;
            go_mat[(*i, *j)] = weight * g_val;
            go_mat[(*j, *i)] = weight * g_val;
        }

        let g_eig = SymmetricEigen::new(g_mat);
        let go_eig = SymmetricEigen::new(go_mat);

        let lmin_g = g_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let lmin_go = go_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let neg_go = go_eig.eigenvalues.iter().filter(|&&v| v < -1e-10).count();

        let ratio = lmin_go / lmin_g;
        let improved = lmin_go > lmin_g;
        let t = start.elapsed().as_secs_f64();

        g_data.push((n as f64, lmin_g, lmin_go));

        println!("  {:6} {:14.10} {:14.10} {:10.4} {:>10}  neg={} ({:.1}s)",
            n, lmin_g, lmin_go, ratio,
            if improved { "✅ YES!" } else { "❌ no" }, neg_go, t);
    }

    // Power-law fit: λ_min ≈ A · N^α
    // log(λ) = log(A) + α·log(N)
    println!("\n  ─── Decay Rate Analysis ───");
    if g_data.len() >= 3 {
        let last3: Vec<_> = g_data.iter().rev().take(3).rev().collect();
        // Fit from last 3 points
        let (n1, g1, _) = last3[0];
        let (n3, g3, _) = last3[2];
        let alpha_g = (g3.ln() - g1.ln()) / (n3.ln() - n1.ln());
        let (_, _, o1) = last3[0];
        let (_, _, o3) = last3[2];
        let alpha_o = (o3.ln() - o1.ln()) / (n3.ln() - n1.ln());
        println!("    G   decay exponent:  α ≈ {:.4}  (λ_min ~ N^α)", alpha_g);
        println!("    G^𝕆 decay exponent:  α ≈ {:.4}  (λ_min ~ N^α)", alpha_o);
        println!("    Ratio exponent:      {:.4}", alpha_o - alpha_g);
        if alpha_o > -0.05 {
            println!("    ⭐ G^𝕆 gap appears to STABILIZE (α ≈ 0)!");
        }
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 4: Eigenvector analysis — multiple N
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 4: Liouville correlation of min eigenvector ═══\n");
    println!("  {:>6} {:>14} {:>14}",
        "N", "corr(G)", "corr(G^𝕆)");
    println!("  {}", "─".repeat(36));

    for &n in &[50, 100, 200, 500] {
        let dim = n - 1;

        let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
            .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                ((i, j), gram_entry(i + 2, j + 2, n_pts))
            })).collect();

        let oct_map: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();

        let mut g_mat = DMatrix::<f64>::zeros(dim, dim);
        let mut go_mat = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), g_val) in &entries {
            let weight = oct_map[*i].inner(&oct_map[*j]);
            g_mat[(*i, *j)] = *g_val;
            g_mat[(*j, *i)] = *g_val;
            go_mat[(*i, *j)] = weight * g_val;
            go_mat[(*j, *i)] = weight * g_val;
        }

        let g_eig = SymmetricEigen::new(g_mat);
        let go_eig = SymmetricEigen::new(go_mat);

        // G eigenvector correlation
        let g_min_idx = g_eig.eigenvalues.iter().enumerate()
            .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap()).unwrap().0;
        let g_evec: Vec<f64> = g_eig.eigenvectors.column(g_min_idx).iter().cloned().collect();

        // G^O eigenvector correlation
        let go_min_idx = go_eig.eigenvalues.iter().enumerate()
            .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap()).unwrap().0;
        let go_evec: Vec<f64> = go_eig.eigenvectors.column(go_min_idx).iter().cloned().collect();

        let mut corr_g = (0.0f64, 0.0f64, 0.0f64);
        let mut corr_go = (0.0f64, 0.0f64, 0.0f64);
        for k_idx in 0..dim {
            let k = k_idx + 2;
            let l = liouville(k) as f64 * (k as f64).ln() / k as f64;
            corr_g.0 += g_evec[k_idx] * l;
            corr_g.1 += g_evec[k_idx] * g_evec[k_idx];
            corr_g.2 += l * l;
            corr_go.0 += go_evec[k_idx] * l;
            corr_go.1 += go_evec[k_idx] * go_evec[k_idx];
            corr_go.2 += l * l;
        }
        let cg = corr_g.0 / (corr_g.1.sqrt() * corr_g.2.sqrt());
        let co = corr_go.0 / (corr_go.1.sqrt() * corr_go.2.sqrt());

        println!("  {:6} {:14.6} {:14.6}  {}",
            n, cg, co,
            if co.abs() < cg.abs() { "← decorrelated ✨" } else { "" });
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 5: Weight matrix W analysis
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 5: Weight matrix W properties (N=200) ═══\n");
    {
        let n = 200;
        let dim = n - 1;
        let oct_map: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();

        let mut w_mat = DMatrix::<f64>::zeros(dim, dim);
        let mut zero_count = 0;
        let mut total = 0;
        for i in 0..dim {
            for j in i..dim {
                let w = oct_map[i].inner(&oct_map[j]);
                w_mat[(i, j)] = w;
                w_mat[(j, i)] = w;
                if i != j {
                    total += 1;
                    if w.abs() < 1e-10 { zero_count += 1; }
                }
            }
        }

        let w_eig = SymmetricEigen::new(w_mat);
        let w_min = w_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let w_max = w_eig.eigenvalues.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        let w_neg = w_eig.eigenvalues.iter().filter(|&&v| v < -1e-10).count();

        println!("  Weight matrix W[j,k] = Re(φ̄(j)·φ(k)):");
        println!("    Dimension:         {}×{}", dim, dim);
        println!("    Diagonal:          all 1.0 (W is a correlation matrix)");
        println!("    Zero off-diag:     {}/{} ({:.1}%)", zero_count, total, 100.0 * zero_count as f64 / total as f64);
        println!("    λ_min(W):          {:.6}", w_min);
        println!("    λ_max(W):          {:.6}", w_max);
        println!("    W positive def?    {}", if w_neg == 0 { "✅ YES" } else { "❌ NO" });
        println!("    Neg eigenvalues:   {}/{}", w_neg, dim);

        if w_neg == 0 {
            println!("\n  ⭐ W is PSD! This is essential for the bridge theorem.");
            println!("    By Schur product theorem: G PSD ∧ W PSD → G^𝕆 = W∘G is PSD.");
            println!("    We need the REVERSE: G^𝕆 PSD + W properties → G PSD?");
        }
    }

    println!("\n  Total time: {:.1}s", total_start.elapsed().as_secs_f64());
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Octonionic decorrelation analysis complete.                    ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
