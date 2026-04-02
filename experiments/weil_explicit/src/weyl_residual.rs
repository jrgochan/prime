use rayon::prelude::*;
use nalgebra::{DMatrix, DVector, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// WEYL BOUND ON RESIDUAL MATRIX
//
// Strategy: decompose G = (G^block + G^cross_rk) + G^cross_res
//   where G^cross_rk = top-k SVD approximation per class pair
//   and   G^cross_res = G^cross - G^cross_rk
//
// By Weyl: λ_min(G) ≥ λ_min(G^block + G^cross_rk) - ||G^cross_res||_op
//
// Test: for what k does ||G^cross_res||_op < λ_min(G^block + G^cross_rk)?
// If such k exists, we have a proof that λ_min(G) > 0!
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

#[derive(Clone)]
struct Oct { c: [f64; 8] }
impl Oct {
    fn basis(i: usize) -> Self { let mut c=[0.;8]; c[i]=1.; Self{c} }
    fn real(a: f64) -> Self { Self{c:[a,0.,0.,0.,0.,0.,0.,0.]} }
    fn norm(&self) -> f64 { self.c.iter().map(|x|x*x).sum::<f64>().sqrt() }
    fn scale(&self, s: f64) -> Self { let mut c=self.c; for x in c.iter_mut(){*x*=s;} Self{c} }
    fn mul(&self, o: &Self) -> Self {
        let (a,b)=(&self.c,&o.c);
        Self{c:[
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
    fn dominant_basis(&self) -> usize {
        self.c.iter().enumerate()
            .max_by(|(_,a),(_,b)| a.abs().partial_cmp(&b.abs()).unwrap())
            .unwrap().0
    }
}

fn prime_to_basis(p: usize) -> usize {
    match p { 2=>1,3=>2,5=>3,7=>4,11=>5,13=>6,17=>7, _=>(p%7)+1 }
}
fn int_to_octonion(k: usize) -> Oct {
    if k<=1 { return Oct::real(1.0); }
    let mut r=Oct::real(1.0); let mut n=k; let mut p=2;
    while p*p<=n { while n%p==0 { r=r.mul(&Oct::basis(prime_to_basis(p))); n/=p; } p+=1; }
    if n>1 { r=r.mul(&Oct::basis(prime_to_basis(n))); }
    let nm=r.norm(); if nm>1e-10{r.scale(1./nm)}else{Oct::real(1.)}
}

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let (jf,kf)=(j as f64,k as f64);
    let dx=1.0/n_pts as f64;
    let mut s=0.0f64;
    for i in 0..n_pts { let x=(i as f64+0.5)*dx; s+=frac_part(jf/x)*frac_part(kf/x); }
    s*dx
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  WEYL BOUND ON RESIDUAL MATRIX                                ║");
    println!("║  G = (G^block + G^cross_rk) + G^cross_res                     ║");
    println!("║  λ_min(G) ≥ λ_min(modified) - ||residual||_op                 ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    for &n in &[200, 500, 1000] {
        let dim = n - 1;
        let n_pts = if n <= 500 { 200_000 } else { 100_000 };
        let start = std::time::Instant::now();

        println!("═══ N = {} (dim = {}) ═══\n", n, dim);

        let phis: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();
        let classes: Vec<usize> = phis.iter().map(|p| p.dominant_basis()).collect();

        let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
            .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                ((i, j), gram_entry(i + 2, j + 2, n_pts))
            })).collect();

        let mut g_full = DMatrix::<f64>::zeros(dim, dim);
        let mut g_block = DMatrix::<f64>::zeros(dim, dim);
        let mut g_cross = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in &entries {
            g_full[(*i, *j)] = *v; g_full[(*j, *i)] = *v;
            if classes[*i] == classes[*j] {
                g_block[(*i, *j)] = *v; g_block[(*j, *i)] = *v;
            } else {
                g_cross[(*i, *j)] = *v; g_cross[(*j, *i)] = *v;
            }
        }

        let eig_full = SymmetricEigen::new(g_full.clone());
        let lmin_full = eig_full.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let lmin_block = SymmetricEigen::new(g_block.clone()).eigenvalues.iter()
            .cloned().fold(f64::INFINITY, f64::min);

        println!("  λ_min(G)       = {:.10}", lmin_full);
        println!("  λ_min(G^block) = {:.10}", lmin_block);
        println!("  ||G^cross||_op = {:.10}",
            SymmetricEigen::new(g_cross.clone()).eigenvalues.iter()
                .map(|x| x.abs()).fold(0.0f64, f64::max));

        // ── For each k = 0, 1, 2, 5, 10, 20, 50: ──
        // Build G^cross_rk (keep top-k SVD per class pair)
        // Compute λ_min(G^block + G^cross_rk) and ||G^cross - G^cross_rk||_op

        let max_k_list: Vec<usize> = vec![0, 1, 2, 3, 5, 10, 20, 50];

        println!("\n  {:>5} {:>14} {:>14} {:>14} {:>10} {:>8}",
            "k", "λ_min(mod)", "||res||_op", "gap=λ-||r||", "proves?", "actual");

        // We work in the ORIGINAL basis. Build the rank-k cross matrix.
        // For each class pair (m1,m2), take the sub-matrix of g_cross,
        // compute SVD, keep top-k, reconstruct.

        for &max_k in &max_k_list {
            if max_k > dim / 2 { break; }

            let mut g_cross_rk = DMatrix::<f64>::zeros(dim, dim);

            for m1 in 0..8 {
                for m2 in (m1+1)..8 {
                    let idx_a: Vec<usize> = (0..dim).filter(|&i| classes[i]==m1).collect();
                    let idx_b: Vec<usize> = (0..dim).filter(|&i| classes[i]==m2).collect();
                    let n_a = idx_a.len();
                    let n_b = idx_b.len();
                    if n_a == 0 || n_b == 0 || max_k == 0 { continue; }

                    // Extract sub-matrix
                    let mut sub = DMatrix::<f64>::zeros(n_a, n_b);
                    for (ii,&i) in idx_a.iter().enumerate() {
                        for (jj,&j) in idx_b.iter().enumerate() {
                            sub[(ii,jj)] = g_cross[(i,j)];
                        }
                    }

                    // SVD and reconstruct top-k
                    let svd = sub.svd(true, true);
                    let k_use = max_k.min(svd.singular_values.len());

                    for k in 0..k_use {
                        let sigma = svd.singular_values[k];
                        if sigma < 1e-12 { break; }

                        let u_k: Vec<f64> = if let Some(ref u) = svd.u {
                            (0..n_a).map(|i| u[(i,k)]).collect()
                        } else { break; };
                        let v_k: Vec<f64> = if let Some(ref vt) = svd.v_t {
                            (0..n_b).map(|j| vt[(k,j)]).collect()
                        } else { break; };

                        // Add σ · u ⊗ v to g_cross_rk (both directions for symmetry)
                        for (ii,&ia) in idx_a.iter().enumerate() {
                            for (jj,&jb) in idx_b.iter().enumerate() {
                                let val = sigma * u_k[ii] * v_k[jj];
                                g_cross_rk[(ia,jb)] += val;
                                g_cross_rk[(jb,ia)] += val;
                            }
                        }
                    }
                }
            }

            // G^cross_res = G^cross - G^cross_rk
            let g_cross_res = &g_cross - &g_cross_rk;

            // Modified matrix = G^block + G^cross_rk
            let g_modified = &g_block + &g_cross_rk;

            // Eigenvalues
            let eig_mod = SymmetricEigen::new(g_modified);
            let lmin_mod = eig_mod.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

            let eig_res = SymmetricEigen::new(g_cross_res);
            let res_op = eig_res.eigenvalues.iter()
                .map(|x| x.abs()).fold(0.0f64, f64::max);

            let gap = lmin_mod - res_op;
            let proves = gap > 0.0;

            println!("  {:5} {:14.10} {:14.10} {:14.10} {:>10} {:8.6}",
                max_k, lmin_mod, res_op, gap,
                if proves {"✅ YES"} else {"❌  no"},
                lmin_full);
        }

        // ── What rank k do we need? Binary search ──
        println!("\n  Binary search for minimum k where Weyl bound proves λ_min > 0:");
        let mut lo = 0usize;
        let mut hi = (dim/2).min(200);
        let mut best_k = hi;

        while lo <= hi {
            let mid = (lo + hi) / 2;

            let mut g_cross_rk = DMatrix::<f64>::zeros(dim, dim);
            for m1 in 0..8 {
                for m2 in (m1+1)..8 {
                    let idx_a: Vec<usize> = (0..dim).filter(|&i| classes[i]==m1).collect();
                    let idx_b: Vec<usize> = (0..dim).filter(|&i| classes[i]==m2).collect();
                    let n_a = idx_a.len();
                    let n_b = idx_b.len();
                    if n_a == 0 || n_b == 0 || mid == 0 { continue; }

                    let mut sub = DMatrix::<f64>::zeros(n_a, n_b);
                    for (ii,&i) in idx_a.iter().enumerate() {
                        for (jj,&j) in idx_b.iter().enumerate() {
                            sub[(ii,jj)] = g_cross[(i,j)];
                        }
                    }

                    let svd = sub.svd(true, true);
                    let k_use = mid.min(svd.singular_values.len());

                    for k in 0..k_use {
                        let sigma = svd.singular_values[k];
                        if sigma < 1e-12 { break; }
                        let u_k: Vec<f64> = if let Some(ref u) = svd.u {
                            (0..n_a).map(|i| u[(i,k)]).collect()
                        } else { break; };
                        let v_k: Vec<f64> = if let Some(ref vt) = svd.v_t {
                            (0..n_b).map(|j| vt[(k,j)]).collect()
                        } else { break; };

                        for (ii,&ia) in idx_a.iter().enumerate() {
                            for (jj,&jb) in idx_b.iter().enumerate() {
                                let val = sigma * u_k[ii] * v_k[jj];
                                g_cross_rk[(ia,jb)] += val;
                                g_cross_rk[(jb,ia)] += val;
                            }
                        }
                    }
                }
            }

            let g_cross_res = &g_cross - &g_cross_rk;
            let g_modified = &g_block + &g_cross_rk;

            let lmin_mod = SymmetricEigen::new(g_modified).eigenvalues.iter()
                .cloned().fold(f64::INFINITY, f64::min);
            let res_op = SymmetricEigen::new(g_cross_res).eigenvalues.iter()
                .map(|x| x.abs()).fold(0.0f64, f64::max);

            if lmin_mod > res_op {
                best_k = mid;
                if mid == 0 { break; }
                hi = mid - 1;
            } else {
                lo = mid + 1;
            }
        }

        println!("  Minimum k for Weyl proof: k = {}\n", best_k);

        let t = start.elapsed().as_secs_f64();
        println!("  Time: {:.1}s\n", t);
    }

    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Weyl residual analysis complete.                              ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
