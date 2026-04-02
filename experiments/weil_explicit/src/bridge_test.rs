use rayon::prelude::*;
use nalgebra::{DMatrix, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// BRIDGE THEOREM TEST: G = G^𝕆 + G^{cross}
//
// By Weyl's inequality:
//   λ_min(G) ≥ λ_min(G^𝕆) + λ_min(G^{cross})
//
// If λ_min(G^{cross}) ≥ -c where c < λ_min(G^𝕆) ≈ 0.048,
// then λ_min(G) > 0 → RH.
//
// G^{cross}[j,k] = G[j,k] · (1 - W[j,k])
// These are the Gram entries ZEROED OUT by the octonionic weights.
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

#[derive(Clone)]
struct Oct { c: [f64; 8] }

impl Oct {
    fn real(a: f64) -> Self { Self { c: [a,0.0,0.0,0.0,0.0,0.0,0.0,0.0] } }
    fn basis(i: usize) -> Self { let mut c = [0.0;8]; c[i] = 1.0; Self{c} }
    fn norm(&self) -> f64 { self.c.iter().map(|x| x*x).sum::<f64>().sqrt() }
    fn conj(&self) -> Self { let mut c=self.c; for i in 1..8{c[i]=-c[i];} Self{c} }
    fn scale(&self, s: f64) -> Self { let mut c=self.c; for x in c.iter_mut(){*x*=s;} Self{c} }
    fn re(&self) -> f64 { self.c[0] }

    fn mul(&self, o: &Self) -> Self {
        let (a, b) = (&self.c, &o.c);
        Self { c: [
            a[0]*b[0]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]-a[4]*b[4]-a[5]*b[5]-a[6]*b[6]-a[7]*b[7],
            a[0]*b[1]+a[1]*b[0]+a[2]*b[3]-a[3]*b[2]+a[4]*b[5]-a[5]*b[4]-a[6]*b[7]+a[7]*b[6],
            a[0]*b[2]-a[1]*b[3]+a[2]*b[0]+a[3]*b[1]+a[4]*b[6]+a[5]*b[7]-a[6]*b[4]-a[7]*b[5],
            a[0]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[0]+a[4]*b[7]-a[5]*b[6]+a[6]*b[5]-a[7]*b[4],
            a[0]*b[4]-a[1]*b[5]-a[2]*b[6]-a[3]*b[7]+a[4]*b[0]+a[5]*b[1]+a[6]*b[2]+a[7]*b[3],
            a[0]*b[5]+a[1]*b[4]-a[2]*b[7]+a[3]*b[6]-a[4]*b[1]+a[5]*b[0]-a[6]*b[3]+a[7]*b[2],
            a[0]*b[6]+a[1]*b[7]+a[2]*b[4]-a[3]*b[5]-a[4]*b[2]+a[5]*b[3]+a[6]*b[0]-a[7]*b[1],
            a[0]*b[7]-a[1]*b[6]+a[2]*b[5]+a[3]*b[4]-a[4]*b[3]-a[5]*b[2]+a[6]*b[1]+a[7]*b[0],
        ]}
    }

    fn inner(&self, o: &Self) -> f64 { self.conj().mul(o).re() }
}

fn prime_factors(mut n: usize) -> Vec<usize> {
    let mut f = Vec::new();
    let mut p = 2;
    while p*p <= n { while n%p==0 { f.push(p); n/=p; } p+=1; }
    if n > 1 { f.push(n); }
    f
}

fn prime_to_basis(p: usize) -> usize {
    match p { 2=>1, 3=>2, 5=>3, 7=>4, 11=>5, 13=>6, 17=>7, _ => (p%7)+1 }
}

fn int_to_octonion(k: usize) -> Oct {
    if k <= 1 { return Oct::real(1.0); }
    let mut r = Oct::real(1.0);
    for &p in &prime_factors(k) { r = r.mul(&Oct::basis(prime_to_basis(p))); }
    let n = r.norm();
    if n > 1e-10 { r.scale(1.0/n) } else { Oct::real(1.0) }
}

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        s += frac_part(jf/x) * frac_part(kf/x);
    }
    s * dx
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  BRIDGE THEOREM TEST: G = G^𝕆 + G^{{cross}}                    ║");
    println!("║  Weyl: λ_min(G) ≥ λ_min(G^𝕆) + λ_min(G^{{cross}})             ║");
    println!("║  If λ_min(G^{{cross}}) > -λ_min(G^𝕆), then λ_min(G) > 0 → RH  ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 500_000;

    println!("  {:>6} {:>14} {:>14} {:>14} {:>14} {:>8}",
        "N", "λ_min(G)", "λ_min(G^𝕆)", "λ_min(G^×)", "G^𝕆+G^×", "bridge?");
    println!("  {}", "─".repeat(76));

    for &n in &[20, 50, 100, 200, 300, 500, 800] {
        let dim = n - 1;
        let start = std::time::Instant::now();

        let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
            .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                ((i, j), gram_entry(i + 2, j + 2, n_pts))
            })).collect();

        let oct_map: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();

        let mut g_mat = DMatrix::<f64>::zeros(dim, dim);
        let mut go_mat = DMatrix::<f64>::zeros(dim, dim);
        let mut gc_mat = DMatrix::<f64>::zeros(dim, dim); // G^{cross}

        for ((i, j), g_val) in &entries {
            let w = oct_map[*i].inner(&oct_map[*j]);
            g_mat[(*i, *j)] = *g_val;
            g_mat[(*j, *i)] = *g_val;
            go_mat[(*i, *j)] = w * g_val;
            go_mat[(*j, *i)] = w * g_val;
            gc_mat[(*i, *j)] = (1.0 - w) * g_val;
            gc_mat[(*j, *i)] = (1.0 - w) * g_val;
        }

        let g_eig = SymmetricEigen::new(g_mat);
        let go_eig = SymmetricEigen::new(go_mat);
        let gc_eig = SymmetricEigen::new(gc_mat);

        let lmin_g = g_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let lmin_go = go_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let lmin_gc = gc_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

        let weyl_bound = lmin_go + lmin_gc;
        let bridge_holds = lmin_gc > -lmin_go;
        let t = start.elapsed().as_secs_f64();

        println!("  {:6} {:14.10} {:14.10} {:14.10} {:14.10} {:>8} ({:.1}s)",
            n, lmin_g, lmin_go, lmin_gc, weyl_bound,
            if bridge_holds { "✅ YES!" } else { "❌ no" }, t);
    }

    // Detailed analysis at N=300
    println!("\n═══ Detailed Analysis at N=300 ═══\n");
    {
        let n = 300;
        let dim = n - 1;

        let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
            .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                ((i, j), gram_entry(i + 2, j + 2, n_pts))
            })).collect();

        let oct_map: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();

        let mut gc_mat = DMatrix::<f64>::zeros(dim, dim);
        let mut go_mat = DMatrix::<f64>::zeros(dim, dim);
        let mut nonzero_cross = 0;
        let mut total_cross = 0;

        for ((i, j), g_val) in &entries {
            let w = oct_map[*i].inner(&oct_map[*j]);
            go_mat[(*i, *j)] = w * g_val;
            go_mat[(*j, *i)] = w * g_val;
            let cross = (1.0 - w) * g_val;
            gc_mat[(*i, *j)] = cross;
            gc_mat[(*j, *i)] = cross;
            if i != j {
                total_cross += 1;
                if cross.abs() > 1e-12 { nonzero_cross += 1; }
            }
        }

        let gc_eig = SymmetricEigen::new(gc_mat.clone());
        let go_eig = SymmetricEigen::new(go_mat);
        let mut gc_evals: Vec<f64> = gc_eig.eigenvalues.iter().cloned().collect();
        gc_evals.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let neg_count = gc_evals.iter().filter(|&&v| v < -1e-10).count();
        let pos_count = gc_evals.iter().filter(|&&v| v > 1e-10).count();
        let zero_count = dim - neg_count - pos_count;
        let lmin_go = go_eig.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

        println!("  G^{{cross}} spectrum (N=300, dim={}):", dim);
        println!("    Nonzero entries:  {}/{} ({:.1}%)",
            nonzero_cross, total_cross, 100.0 * nonzero_cross as f64 / total_cross as f64);
        println!("    Positive eigs:    {}", pos_count);
        println!("    Zero eigs:        {}", zero_count);
        println!("    Negative eigs:    {}", neg_count);
        println!();

        println!("  10 smallest eigenvalues of G^{{cross}}:");
        for i in 0..10.min(gc_evals.len()) {
            println!("    λ_{} = {:14.10}", i+1, gc_evals[i]);
        }

        println!("\n  10 largest eigenvalues of G^{{cross}}:");
        let len = gc_evals.len();
        for i in (len.saturating_sub(10))..len {
            println!("    λ_{} = {:14.10}", i+1, gc_evals[i]);
        }

        println!("\n  Bridge theorem check:");
        println!("    λ_min(G^𝕆):      {:14.10}", lmin_go);
        println!("    λ_min(G^{{cross}}): {:14.10}", gc_evals[0]);
        println!("    Sum (Weyl lb):   {:14.10}", lmin_go + gc_evals[0]);
        if gc_evals[0] >= -1e-10 {
            println!("    🎉 G^{{cross}} is PSD! Bridge theorem holds trivially!");
            println!("    λ_min(G) ≥ λ_min(G^𝕆) > 0 by Weyl's inequality.");
        } else if gc_evals[0] > -lmin_go {
            println!("    ✅ Bridge theorem holds! |λ_min(G^{{cross}})| < λ_min(G^𝕆)");
            println!("    λ_min(G) ≥ {:.10} > 0", lmin_go + gc_evals[0]);
        } else {
            println!("    ❌ Bridge theorem does NOT hold via simple Weyl.");
            println!("    |λ_min(G^{{cross}})| = {:.6} > λ_min(G^𝕆) = {:.6}",
                gc_evals[0].abs(), lmin_go);
            println!("    The cross-term negative part overwhelms the G^𝕆 gap.");

            // But check: what's the actual relationship?
            // Maybe a tighter bound is possible
            println!("\n  Tighter analysis:");
            println!("    Ratio: |λ_min(G^{{cross}})| / λ_min(G^𝕆) = {:.4}",
                gc_evals[0].abs() / lmin_go);
            println!("    For bridge to work, need this ratio < 1.0");

            // Check if G^{cross} negative eigenvalue direction overlaps
            // with G^𝕆 minimum eigenvalue direction
            let gc_min_idx = gc_eig.eigenvalues.iter().enumerate()
                .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap()).unwrap().0;
            let gc_evec: Vec<f64> = gc_eig.eigenvectors.column(gc_min_idx).iter().cloned().collect();

            let go_min_idx = go_eig.eigenvalues.iter().enumerate()
                .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap()).unwrap().0;
            let go_evec: Vec<f64> = go_eig.eigenvectors.column(go_min_idx).iter().cloned().collect();

            let overlap: f64 = gc_evec.iter().zip(go_evec.iter())
                .map(|(a, b)| a * b).sum();
            println!("    Overlap of G^{{cross}} and G^𝕆 min eigenvectors: {:.6}", overlap.abs());
            println!("    (If small, the negative directions are orthogonal → less cancellation)");
        }
    }

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Bridge theorem analysis complete.                             ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
