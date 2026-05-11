#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use nalgebra::{DMatrix, DVector, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// LARGE SIEVE & INTERFERENCE MATRIX ANALYSIS
//
// The minimum eigenvector of G is built by combining block eigenvectors
// from different classes. This experiment analyzes:
//
// 1. The interference matrix M[i,j] = ⟨w_i, G^cross w_j⟩
//    (G^cross in the eigenbasis of G^block)
// 2. Class-resolved decomposition of v_min(G)
// 3. Per-class energy distribution
// 4. Effective interference experienced by v_min(G)
// 5. Large sieve structure: is the interference bounded by diagonal?
//
// RH ⟺ for ALL unit v: Σ c_i c_j M[i,j] > -Σ |c_i|² λ_i(G^block)
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
    println!("║  LARGE SIEVE & INTERFERENCE ANALYSIS                           ║");
    println!("║  How cross-class mixing creates the Liouville direction         ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 200_000;

    for &n in &[100, 200, 500, 800] {
        let dim = n - 1;
        let start = std::time::Instant::now();
        println!("═══ N = {} (dim = {}) ═══\n", n, dim);

        // Build classifications
        let phis: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();
        let classes: Vec<usize> = phis.iter().map(|p| p.dominant_basis()).collect();

        // Which class does each BLOCK EIGENVECTOR belong to?
        // Since G^block is block-diagonal, each eigenvector belongs to one class.
        // We determine this from the support of the eigenvector.

        // Build matrices
        let entries: Vec<((usize, usize), f64)> = (0..dim).into_par_iter()
            .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                ((i, j), gram_entry(i + 2, j + 2, n_pts))
            })).collect();

        let mut g_full = DMatrix::<f64>::zeros(dim, dim);
        let mut g_block = DMatrix::<f64>::zeros(dim, dim);
        let mut g_cross = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in &entries {
            g_full[(*i, *j)] = *v;  g_full[(*j, *i)] = *v;
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

        // ── CLASS-RESOLVED DECOMPOSITION OF v_min(G) ──
        // Determine which class each block eigenvector belongs to
        let mut block_evec_class: Vec<usize> = Vec::with_capacity(dim);
        for col in 0..dim {
            let mut class_energy = [0.0f64; 8];
            for row in 0..dim {
                let val = eig_block.eigenvectors[(row, col)];
                class_energy[classes[row]] += val * val;
            }
            let best_class = class_energy.iter().enumerate()
                .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
                .unwrap().0;
            block_evec_class.push(best_class);
        }

        // Expand v_min(G) in block eigenbasis: c_i = ⟨w_i, v_min(G)⟩
        let mut coeffs = DVector::<f64>::zeros(dim);
        for i in 0..dim {
            let mut dot = 0.0;
            for r in 0..dim {
                dot += eig_block.eigenvectors[(r, i)] * eig_full.eigenvectors[(r, min_full_idx)];
            }
            coeffs[i] = dot;
        }

        // Per-class energy of v_min(G)
        let mut class_energy = [0.0f64; 8];
        for i in 0..dim {
            class_energy[block_evec_class[i]] += coeffs[i] * coeffs[i];
        }

        println!("  λ_min(G) = {:.10}", lmin_full);
        println!();
        println!("  Per-class energy of v_min(G) (in block eigenbasis):");
        for m in 0..8 {
            let pct = class_energy[m] * 100.0;
            let bar_len = (pct * 2.0) as usize;
            println!("    S_{}: {:6.2}%  {}", m, pct,
                "█".repeat(bar_len.min(50)));
        }
        let total_energy: f64 = class_energy.iter().sum();
        println!("    Total: {:.6}", total_energy);

        // ── INTERFERENCE MATRIX STRUCTURE ──
        // M[i,j] = ⟨w_i, G^cross w_j⟩ = (W^T G^cross W)[i,j]
        // But M = W^T G^cross W has same spectrum as G^cross.
        // What matters is the CLASS-CLASS BLOCK STRUCTURE of M.

        // M restricted to class pair (m1, m2):
        // M_{m1,m2}[i,j] = ⟨w_i, G^cross w_j⟩ where w_i ∈ class m1, w_j ∈ class m2
        // This tells us how eigenvectors of different blocks interfere.

        // Compute the full M = W^T G^cross W
        let w = &eig_block.eigenvectors;
        let temp = &g_cross * w;
        let m_matrix = w.transpose() * &temp;

        // Analyze M block structure
        println!("\n  Interference matrix M class-class block norms:");
        println!("  {:>4} {:>4} {:>12} {:>10} {:>12}",
            "m1", "m2", "||M_{m1,m2}||_F", "rank-1?", "top_sv");

        let mut total_off_frob_sq = 0.0;
        for m1 in 0..8 {
            for m2 in (m1+1)..8 {
                // Indices of eigenvectors in class m1 and m2
                let idx1: Vec<usize> = (0..dim).filter(|&i| block_evec_class[i] == m1).collect();
                let idx2: Vec<usize> = (0..dim).filter(|&i| block_evec_class[i] == m2).collect();

                if idx1.is_empty() || idx2.is_empty() { continue; }

                // Extract sub-block of M
                let n1 = idx1.len();
                let n2 = idx2.len();
                let mut sub = DMatrix::<f64>::zeros(n1, n2);
                for (ii, &i) in idx1.iter().enumerate() {
                    for (jj, &j) in idx2.iter().enumerate() {
                        sub[(ii, jj)] = m_matrix[(i, j)];
                    }
                }

                let frob: f64 = sub.iter().map(|x| x*x).sum::<f64>().sqrt();
                total_off_frob_sq += frob * frob;

                // SVD to check rank-1 approximation
                let svd = sub.svd(false, false);
                let sv = svd.singular_values;
                let top_sv = sv[0];
                let rank1_frac = top_sv * top_sv / (frob * frob + 1e-30);

                if frob > 0.1 {
                    println!("  {:4} {:4} {:12.6} {:10.2}% {:12.6}",
                        m1, m2, frob, rank1_frac * 100.0, top_sv);
                }
            }
        }

        // ── THE KEY TEST: EFFECTIVE INTERFERENCE ON v_min(G) ──
        // v_min(G) has coefficients c in the block eigenbasis.
        // Its eigenvalue is: λ = Σ |c_i|² λ_i(G^block) + Σ_{i≠j} c_i c_j M[i,j]
        //                      = diagonal_energy + interference

        let mut diag_energy = 0.0;
        let mut interf_energy = 0.0;
        for i in 0..dim {
            diag_energy += coeffs[i] * coeffs[i] * eig_block.eigenvalues[i];
            for j in 0..dim {
                if i != j {
                    interf_energy += coeffs[i] * coeffs[j] * m_matrix[(i, j)];
                }
            }
        }

        println!("\n  Energy decomposition of λ_min(G):");
        println!("    Diagonal (Σ|c|²λ_block):   {:+14.10}", diag_energy);
        println!("    Interference (Σ c_i c_j M): {:+14.10}", interf_energy);
        println!("    Sum = λ_min(G):             {:+14.10}", diag_energy + interf_energy);
        println!("    Actual λ_min(G):            {:+14.10}", lmin_full);
        println!("    Interference / Diagonal:     {:+.6}",
            interf_energy / diag_energy);

        // ── CLASS-PAIR INTERFERENCE CONTRIBUTIONS ──
        // Break the interference by class pairs
        println!("\n  Interference by class pair (which pairs reduce eigenvalue most):");
        let mut pair_interf: Vec<(usize, usize, f64)> = Vec::new();
        for m1 in 0..8 {
            for m2 in (m1+1)..8 {
                let mut contrib = 0.0;
                for i in 0..dim {
                    for j in 0..dim {
                        if block_evec_class[i] == m1 && block_evec_class[j] == m2 {
                            contrib += 2.0 * coeffs[i] * coeffs[j] * m_matrix[(i, j)];
                        }
                    }
                }
                pair_interf.push((m1, m2, contrib));
            }
        }
        pair_interf.sort_by(|a, b| a.2.partial_cmp(&b.2).unwrap());

        for &(m1, m2, contrib) in pair_interf.iter().take(8) {
            println!("    S_{} × S_{}: {:+14.10}  ({:.1}% of interference)",
                m1, m2, contrib, (contrib / interf_energy) * 100.0);
        }
        println!("    ...");
        for &(m1, m2, contrib) in pair_interf.iter().rev().take(3) {
            println!("    S_{} × S_{}: {:+14.10}  ({:.1}% of interference)",
                m1, m2, contrib, (contrib / interf_energy) * 100.0);
        }

        // ── LARGE SIEVE RATIO ──
        // Define R = |interference| / diagonal_energy
        // For RH, we need R < 1 for ALL unit vectors, not just v_min(G).
        // v_min(G) achieves the maximum R (by variational principle).

        let r_ratio = interf_energy.abs() / diag_energy;
        println!("\n  ⭐ Large sieve ratio R = |interference| / diagonal = {:.6}", r_ratio);
        println!("     R < 1 ⟹ λ_min(G) > 0 ⟹ RH");
        println!("     Status: {} (R = {:.4})",
            if r_ratio < 1.0 { "✅ R < 1 — consistent with RH" }
            else { "❌ R ≥ 1 — would violate RH" }, r_ratio);

        // ── WEIGHTED MEAN BLOCK EIGENVALUE ──
        let mean_block_ev: f64 = (0..dim).map(|i|
            coeffs[i] * coeffs[i] * eig_block.eigenvalues[i]
        ).sum::<f64>();

        // Liouville contribution per class
        let mut lio_vec = DVector::<f64>::zeros(dim);
        for i in 0..dim {
            let k = (i + 2) as f64;
            lio_vec[i] = liouville(i + 2) as f64 * k.ln() / k;
        }
        let lio_norm = lio_vec.norm();
        lio_vec /= lio_norm;

        println!("\n  Liouville projection per class:");
        for m in 0..8 {
            let mut lio_class = 0.0;
            for i in 0..dim {
                if classes[i] == m {
                    lio_class += eig_full.eigenvectors[(i, min_full_idx)] * lio_vec[i];
                }
            }
            println!("    S_{}: {:+.6}", m, lio_class);
        }

        let t = start.elapsed().as_secs_f64();
        println!("\n  Time: {:.1}s\n", t);
    }

    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Large sieve analysis complete.                                ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
