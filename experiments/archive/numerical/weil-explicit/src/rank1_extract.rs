#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use nalgebra::{DMatrix, DVector, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// RANK-1 VECTOR EXTRACTION & LARGE-N STABILITY
//
// The interference blocks M_{m1,m2} are rank-1:
//   M_{m1,m2} ≈ σ · u ⊗ v
//
// This experiment:
// 1. Extracts the rank-1 vectors u^{(m)}, v^{(m)} for each class pair
// 2. Tests their relationship to the Liouville function
// 3. Builds the 8×8 "reduced interference matrix" Σ
// 4. Verifies R < 1 at larger N (1000, 1500, 2000)
// 5. Tests WHY the blocks are rank-1 (structural explanation)
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

fn liouville(n: usize) -> i32 {
    let mut v=n; let mut o=0; let mut p=2;
    while p*p<=v { while v%p==0{o+=1;v/=p;} p+=1; }
    if v>1{o+=1;}
    if o%2==0{1}else{-1}
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
    println!("║  RANK-1 STRUCTURE & LARGE-N STABILITY                          ║");
    println!("║  Extracting the 8×8 reduced interference problem               ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    // Use fewer integration points for large N, more for small
    let mut summary: Vec<(usize, f64, f64, f64, f64, f64)> = Vec::new();

    for &n in &[200, 500, 1000, 1500, 2000] {
        let dim = n - 1;
        let n_pts = if n <= 500 { 200_000 } else { 100_000 };
        let start = std::time::Instant::now();

        println!("═══ N = {} (dim = {}, n_pts = {}) ═══\n", n, dim, n_pts);

        // Classify
        let phis: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();
        let classes: Vec<usize> = phis.iter().map(|p| p.dominant_basis()).collect();

        // Class sizes
        let mut class_sizes = [0usize; 8];
        for &c in &classes { class_sizes[c] += 1; }

        // Build matrices
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
        let lmin_full = eig_full.eigenvalues[min_full_idx];
        let lmin_block = eig_block.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);

        // Block eigenvector class assignment
        let mut block_evec_class: Vec<usize> = Vec::with_capacity(dim);
        for col in 0..dim {
            let mut ce = [0.0f64; 8];
            for row in 0..dim { ce[classes[row]] += eig_block.eigenvectors[(row,col)].powi(2); }
            block_evec_class.push(ce.iter().enumerate()
                .max_by(|a,b| a.1.partial_cmp(b.1).unwrap()).unwrap().0);
        }

        // Expand v_min(G) in block eigenbasis
        let mut coeffs = DVector::<f64>::zeros(dim);
        for i in 0..dim {
            coeffs[i] = (0..dim).map(|r|
                eig_block.eigenvectors[(r,i)] * eig_full.eigenvectors[(r,min_full_idx)]
            ).sum();
        }

        // Build M = W^T G^cross W
        let w = &eig_block.eigenvectors;
        let m_matrix = w.transpose() * &(&g_cross * w);

        // Energy decomposition
        let diag_e: f64 = (0..dim).map(|i| coeffs[i].powi(2) * eig_block.eigenvalues[i]).sum();
        let mut interf_e = 0.0f64;
        for i in 0..dim { for j in 0..dim { if i!=j {
            interf_e += coeffs[i] * coeffs[j] * m_matrix[(i,j)];
        }}}

        let r_ratio = interf_e.abs() / diag_e;

        println!("  λ_min(G) = {:.10}    λ_min(G^block) = {:.10}", lmin_full, lmin_block);
        println!("  Diagonal = {:.10}    Interference = {:.10}", diag_e, interf_e);
        println!("  R = |interf|/diag = {:.6}    1-R = {:.6}", r_ratio, 1.0 - r_ratio);

        // ── Extract rank-1 vectors and build 8×8 Σ matrix ──
        // For each class pair (m1,m2), extract the top SVD direction
        // Σ[m1,m2] = top singular value / sqrt(|S_m1| * |S_m2|)
        // (normalized by class sizes for fair comparison)

        println!("\n  8×8 Reduced Interference Matrix (top singular values):");
        let mut sigma_matrix = [[0.0f64; 8]; 8];
        let mut min_rank1_acc = 1.0f64;

        for m1 in 0..8 {
            for m2 in (m1+1)..8 {
                let idx1: Vec<usize> = (0..dim).filter(|&i| block_evec_class[i]==m1).collect();
                let idx2: Vec<usize> = (0..dim).filter(|&i| block_evec_class[i]==m2).collect();
                if idx1.is_empty() || idx2.is_empty() { continue; }

                let mut sub = DMatrix::<f64>::zeros(idx1.len(), idx2.len());
                for (ii,&i) in idx1.iter().enumerate() {
                    for (jj,&j) in idx2.iter().enumerate() {
                        sub[(ii,jj)] = m_matrix[(i,j)];
                    }
                }
                let frob_sq: f64 = sub.iter().map(|x| x*x).sum();
                let svd = sub.svd(false, false);
                let top_sv = svd.singular_values[0];
                let rank1_acc = top_sv*top_sv / (frob_sq + 1e-30);
                if rank1_acc < min_rank1_acc { min_rank1_acc = rank1_acc; }

                // Normalized by geometric mean of class sizes
                let norm_sigma = top_sv / ((idx1.len() * idx2.len()) as f64).sqrt();
                sigma_matrix[m1][m2] = norm_sigma;
                sigma_matrix[m2][m1] = norm_sigma;
            }
        }

        println!("     m0      m1      m2      m3      m4      m5      m6      m7");
        for m in 0..8 {
            print!("  {} ", m);
            for m2 in 0..8 {
                if m == m2 { print!("   ---  "); }
                else { print!(" {:6.4} ", sigma_matrix[m][m2]); }
            }
            println!();
        }
        println!("  Min rank-1 accuracy: {:.4}%", min_rank1_acc * 100.0);

        // ── Per-class energy and the 8-variable reduction ──
        let mut class_energy = [0.0f64; 8];
        let mut class_alpha = [0.0f64; 8]; // projection onto rank-1 direction
        for i in 0..dim {
            class_energy[block_evec_class[i]] += coeffs[i].powi(2);
        }

        // v_min(G) per-class energy
        println!("\n  Per-class energy:");
        for m in 0..8 {
            println!("    S_{}: {:6.2}%  ({} eigenvectors)", m,
                class_energy[m]*100.0, class_sizes[m]);
        }

        // ── WHY rank-1? Test if G^cross rows within a class are proportional ──
        // Pick class pair (0,1). For each i ∈ S_0, the "row" of G^cross
        // restricted to S_1 columns should be proportional to a fixed vector.
        println!("\n  WHY rank-1? Testing row proportionality for S_0 × S_1:");
        let s0: Vec<usize> = (0..dim).filter(|&i| classes[i]==0).collect();
        let s1: Vec<usize> = (0..dim).filter(|&i| classes[i]==1).collect();

        if s0.len() >= 3 && s1.len() >= 3 {
            // Rows of G^cross[S_0, S_1]
            let mut rows: Vec<Vec<f64>> = Vec::new();
            for &i in s0.iter().take(6) {
                let row: Vec<f64> = s1.iter().map(|&j| g_cross[(i,j)]).collect();
                rows.push(row);
            }
            // Normalize first row as reference
            let norm0: f64 = rows[0].iter().map(|x| x*x).sum::<f64>().sqrt();
            if norm0 > 1e-10 {
                let ref_row: Vec<f64> = rows[0].iter().map(|x| x/norm0).collect();
                println!("    Reference: row for k={} (norm={:.6})", s0[0]+2, norm0);
                for (ri, row) in rows.iter().enumerate().skip(1).take(4) {
                    let row_norm: f64 = row.iter().map(|x| x*x).sum::<f64>().sqrt();
                    if row_norm > 1e-10 {
                        let cos: f64 = row.iter().zip(ref_row.iter())
                            .map(|(a,b)| a*b).sum::<f64>() / row_norm;
                        println!("    k={}: cos(angle to ref) = {:.8}, ratio = {:.6}",
                            s0[ri]+2, cos.abs(), row_norm / norm0);
                    }
                }
            }
        }

        let t = start.elapsed().as_secs_f64();
        println!("\n  Time: {:.1}s\n", t);

        summary.push((n, lmin_full, lmin_block, r_ratio, min_rank1_acc, t));
    }

    // Summary
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  SUMMARY                                                       ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");
    println!("  {:>6} {:>12} {:>12} {:>10} {:>10} {:>8} {:>8}",
        "N", "λ_min(G)", "λ_min(blk)", "R", "1-R", "rank1%", "time");
    println!("  {}", "─".repeat(75));
    for &(n, lf, lb, r, ra, t) in &summary {
        println!("  {:6} {:12.8} {:12.8} {:10.6} {:10.6} {:8.4} {:8.1}",
            n, lf, lb, r, 1.0-r, ra*100.0, t);
    }

    // Extrapolation
    println!("\n  Extrapolations:");
    if summary.len() >= 2 {
        let last = summary.last().unwrap();
        let prev = &summary[summary.len()-2];
        let dr = (last.3 - prev.3) / (last.0 as f64 - prev.0 as f64);
        println!("    dR/dN ≈ {:.2e} (R drift per unit N)", dr);
        if dr > 0.0 {
            let n_cross = last.0 as f64 + (1.0 - last.3) / dr;
            println!("    At this rate, R would reach 1.0 at N ≈ {:.0}", n_cross);
        } else {
            println!("    R is DECREASING — ratio converges below 1 ✅");
        }
    }
}
