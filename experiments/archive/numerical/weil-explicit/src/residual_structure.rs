#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use nalgebra::{DMatrix, DVector, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// RESIDUAL STRUCTURE ANALYSIS
//
// The rank-1 approximation captures 99.99% of ||M||²_F but only ~3%
// of the bilinear form v_min^T M v_min. WHERE does the other 97% live?
//
// This experiment:
// 1. Decomposes M = rank-1 + residual for each class pair
// 2. Measures bilinear form contribution: rank-1 vs residual
// 3. SVD cascades the residual: is it ALSO rank-1? Rank-2?
// 4. Computes λ_eff for each SVD level — do deeper levels live on
//    smaller eigenvalues?
// 5. Tests if the full interference is a SUM of rank-1 terms,
//    each at a different spectral scale
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
    println!("║  RESIDUAL STRUCTURE: WHERE DOES THE ACTUAL R LIVE?             ║");
    println!("║  Decomposing M into SVD cascade levels                         ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    for &n in &[500, 1000] {
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
        let eig_block = SymmetricEigen::new(g_block.clone());

        let min_full_idx = eig_full.eigenvalues.iter().enumerate()
            .min_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap()).unwrap().0;

        // Block eigenvector class assignment
        let mut block_evec_class: Vec<usize> = Vec::with_capacity(dim);
        for col in 0..dim {
            let mut ce = [0.0f64; 8];
            for row in 0..dim { ce[classes[row]] += eig_block.eigenvectors[(row,col)].powi(2); }
            block_evec_class.push(ce.iter().enumerate()
                .max_by(|a,b| a.1.partial_cmp(b.1).unwrap()).unwrap().0);
        }

        // Expand v_min(G) in block eigenbasis
        let w = &eig_block.eigenvectors;
        let mut coeffs = DVector::<f64>::zeros(dim);
        for i in 0..dim {
            coeffs[i] = (0..dim).map(|r|
                w[(r,i)] * eig_full.eigenvectors[(r,min_full_idx)]
            ).sum();
        }

        // Build M = W^T G^cross W
        let m_matrix = w.transpose() * &(&g_cross * w);

        // Total bilinear form
        let total_bilinear: f64 = (0..dim).map(|i|
            (0..dim).map(|j| coeffs[i] * coeffs[j] * m_matrix[(i,j)]).sum::<f64>()
        ).sum();

        println!("  Total bilinear form v^T M v = {:.10}", total_bilinear);
        println!("  (This is the interference = {:.10})\n", total_bilinear);

        // ── SVD CASCADE for representative pair (0,1) ──
        println!("  ── SVD CASCADE for S_0 × S_1 ──\n");

        let idx0: Vec<usize> = (0..dim).filter(|&i| block_evec_class[i]==0).collect();
        let idx1: Vec<usize> = (0..dim).filter(|&i| block_evec_class[i]==1).collect();
        let n0 = idx0.len();
        let n1 = idx1.len();

        // Extract M_{0,1}
        let mut sub = DMatrix::<f64>::zeros(n0, n1);
        for (ii,&i) in idx0.iter().enumerate() {
            for (jj,&j) in idx1.iter().enumerate() {
                sub[(ii,jj)] = m_matrix[(i,j)];
            }
        }

        // Full SVD
        let svd = sub.clone().svd(true, true);
        let n_sv = svd.singular_values.len();
        let frob_sq: f64 = sub.iter().map(|x| x*x).sum();

        // Coefficients of v_min restricted to classes 0 and 1
        let c0: Vec<f64> = idx0.iter().map(|&i| coeffs[i]).collect();
        let c1: Vec<f64> = idx1.iter().map(|&i| coeffs[i]).collect();

        println!("  {:>5} {:>12} {:>10} {:>12} {:>12} {:>12}",
            "rank", "σ_k", "% Frob", "bilinear_k", "% bilinear", "λ_eff_k");

        let mut cumul_frob = 0.0f64;
        let mut cumul_bilinear = 0.0f64;
        let bilinear_01: f64 = (0..n0).map(|ii| (0..n1).map(|jj|
            c0[ii] * c1[jj] * sub[(ii,jj)]
        ).sum::<f64>()).sum();

        for k in 0..n_sv.min(20) {
            let sigma = svd.singular_values[k];
            if sigma < 1e-12 { break; }

            cumul_frob += sigma * sigma;

            // u_k and v_k
            let u_k: Vec<f64> = if let Some(ref u) = svd.u {
                (0..n0).map(|i| u[(i,k)]).collect()
            } else { break; };
            let v_k: Vec<f64> = if let Some(ref vt) = svd.v_t {
                (0..n1).map(|j| vt[(k,j)]).collect()
            } else { break; };

            // Bilinear contribution: σ_k * (c0·u_k) * (c1·v_k)
            let proj_u: f64 = c0.iter().zip(u_k.iter()).map(|(a,b)| a*b).sum();
            let proj_v: f64 = c1.iter().zip(v_k.iter()).map(|(a,b)| a*b).sum();
            let bilinear_k = sigma * proj_u * proj_v;
            cumul_bilinear += bilinear_k;

            // Effective eigenvalue for this SVD direction
            let inv_leff_u: f64 = (0..n0).map(|ii| {
                u_k[ii] * u_k[ii] / eig_block.eigenvalues[idx0[ii]]
            }).sum();
            let lambda_eff = 1.0 / inv_leff_u;

            let pct_frob = cumul_frob / frob_sq * 100.0;
            let pct_bilinear = if bilinear_01.abs() > 1e-15 {
                cumul_bilinear / bilinear_01 * 100.0
            } else { 0.0 };

            println!("  {:5} {:12.6} {:9.4}% {:12.8} {:11.4}% {:12.6}",
                k+1, sigma, pct_frob, bilinear_k, pct_bilinear, lambda_eff);
        }

        println!("\n  Total pair bilinear = {:.10}", bilinear_01);
        println!("  Accumulated (top 20) = {:.10}", cumul_bilinear);

        // ── AGGREGATE: all class pairs ──
        println!("\n  ── AGGREGATE: bilinear contribution by SVD level ──\n");
        println!("  {:>5} {:>14} {:>14} {:>10}",
            "level", "bilinear_sum", "cumulative", "% of total");

        let mut level_bilinear = vec![0.0f64; 20];
        let mut level_lambda_eff_sum = vec![0.0f64; 20];
        let mut level_count = vec![0usize; 20];

        for m1 in 0..8 {
            for m2 in (m1+1)..8 {
                let idxA: Vec<usize> = (0..dim).filter(|&i| block_evec_class[i]==m1).collect();
                let idxB: Vec<usize> = (0..dim).filter(|&i| block_evec_class[i]==m2).collect();
                let nA = idxA.len();
                let nB = idxB.len();
                if nA == 0 || nB == 0 { continue; }

                let mut blk = DMatrix::<f64>::zeros(nA, nB);
                for (ii,&i) in idxA.iter().enumerate() {
                    for (jj,&j) in idxB.iter().enumerate() {
                        blk[(ii,jj)] = m_matrix[(i,j)];
                    }
                }

                let cA: Vec<f64> = idxA.iter().map(|&i| coeffs[i]).collect();
                let cB: Vec<f64> = idxB.iter().map(|&i| coeffs[i]).collect();

                let svd_blk = blk.svd(true, true);
                let n_sv_blk = svd_blk.singular_values.len();

                for k in 0..n_sv_blk.min(20) {
                    let sigma = svd_blk.singular_values[k];
                    if sigma < 1e-12 { break; }

                    let u_k: Vec<f64> = if let Some(ref u) = svd_blk.u {
                        (0..nA).map(|i| u[(i,k)]).collect()
                    } else { break; };
                    let v_k: Vec<f64> = if let Some(ref vt) = svd_blk.v_t {
                        (0..nB).map(|j| vt[(k,j)]).collect()
                    } else { break; };

                    let proj_u: f64 = cA.iter().zip(u_k.iter()).map(|(a,b)| a*b).sum();
                    let proj_v: f64 = cB.iter().zip(v_k.iter()).map(|(a,b)| a*b).sum();

                    // Both (m1,m2) AND (m2,m1) contribute (M is in both directions)
                    // But we only iterate m1 < m2, so count ×2
                    level_bilinear[k] += 2.0 * sigma * proj_u * proj_v;

                    // λ_eff for this direction
                    let inv_leff: f64 = (0..nA).map(|ii| {
                        u_k[ii] * u_k[ii] / eig_block.eigenvalues[idxA[ii]]
                    }).sum();
                    level_lambda_eff_sum[k] += 1.0 / inv_leff;
                    level_count[k] += 1;
                }
            }
        }

        let mut cumul = 0.0f64;
        for k in 0..20 {
            if level_count[k] == 0 { break; }
            cumul += level_bilinear[k];
            let pct = if total_bilinear.abs() > 1e-15 {
                cumul / total_bilinear * 100.0
            } else { 0.0 };
            let mean_leff = level_lambda_eff_sum[k] / level_count[k] as f64;
            println!("  {:5} {:14.8} {:14.8} {:9.4}%  (mean λ_eff = {:.4})",
                k+1, level_bilinear[k], cumul, pct, mean_leff);
        }

        // ── KEY QUESTION: which block eigenvalues does v_min use? ──
        println!("\n  ── v_min(G) eigenvalue distribution ──");

        // Sort block eigenvalues and group into bins
        let mut ev_coeffs: Vec<(f64, f64)> = (0..dim).map(|i|
            (eig_block.eigenvalues[i], coeffs[i].powi(2))
        ).collect();
        ev_coeffs.sort_by(|a,b| a.0.partial_cmp(&b.0).unwrap());

        let n_bins = 10;
        let bin_size = dim / n_bins;
        println!("  {:>12} {:>12} {:>12} {:>10}",
            "λ_range_low", "λ_range_hi", "energy", "% total");
        for b in 0..n_bins {
            let start_idx = b * bin_size;
            let end_idx = if b == n_bins-1 { dim } else { (b+1)*bin_size };
            let energy: f64 = ev_coeffs[start_idx..end_idx].iter().map(|(_,c)| c).sum();
            let low = ev_coeffs[start_idx].0;
            let hi = ev_coeffs[end_idx-1].0;
            let bar = "█".repeat((energy * 100.0) as usize);
            println!("  {:12.6} {:12.6} {:12.8} {:9.4}%  {}",
                low, hi, energy, energy*100.0, bar);
        }

        let t = start.elapsed().as_secs_f64();
        println!("\n  Time: {:.1}s\n", t);
    }

    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Residual analysis complete.                                   ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
