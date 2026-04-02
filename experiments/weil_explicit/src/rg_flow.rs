use rayon::prelude::*;
use nalgebra::{DMatrix, SymmetricEigen};

// ══════════════════════════════════════════════════════════════════════
// RENORMALIZATION GROUP FLOW OF THE SPECTRAL GAP
//
// Treat λ_min(G_N) as a "running coupling constant" and compute
// the beta function: β(λ) = N · dλ/dN
//
// Fixed point β(λ*) = 0 at λ* > 0 → spectral gap persists → RH
// Linear β → logarithmic decay (still consistent with RH)
// Nonlinear β with UV fixed point → power-law convergence to gap
//
// Also compute β for G^𝕆 (octonionic) to see if the near-marginal
// behavior (α ≈ -0.02) has curvature.
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 { x - x.floor() }

#[derive(Clone)]
struct Oct { c: [f64; 8] }
impl Oct {
    fn real(a: f64) -> Self { Self { c: [a,0.,0.,0.,0.,0.,0.,0.] } }
    fn basis(i: usize) -> Self { let mut c=[0.;8]; c[i]=1.; Self{c} }
    fn norm(&self) -> f64 { self.c.iter().map(|x| x*x).sum::<f64>().sqrt() }
    fn conj(&self) -> Self { let mut c=self.c; for i in 1..8{c[i]=-c[i];} Self{c} }
    fn scale(&self, s: f64) -> Self { let mut c=self.c; for x in c.iter_mut(){*x*=s;} Self{c} }
    fn re(&self) -> f64 { self.c[0] }
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
    fn inner(&self, o: &Self) -> f64 { self.conj().mul(o).re() }
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
    println!("║  RENORMALIZATION GROUP FLOW — SPECTRAL GAP                     ║");
    println!("║  β(λ) = N · dλ/dN  — looking for fixed points                 ║");
    println!("║  Fixed point β(λ*) = 0 at λ* > 0 ⟹ RH                       ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let n_pts = 200_000; // Reduced for speed at large N

    // Fine-grained N values for smooth beta function — pushed to N=2000
    let ns: Vec<usize> = vec![
        10, 15, 20, 25, 30, 40, 50, 60, 70, 80, 90, 100,
        120, 140, 160, 180, 200, 250, 300, 350, 400, 450, 500,
        600, 700, 800, 1000, 1200, 1500, 2000,
    ];

    println!("═══ Section 1: Spectral gap at each N ═══\n");
    println!("  {:>6} {:>14} {:>14} {:>10} {:>6}",
        "N", "λ_min(G)", "λ_min(G^𝕆)", "ratio", "time");
    println!("  {}", "─".repeat(54));

    let mut data: Vec<(f64, f64, f64)> = Vec::new(); // (N, λ_G, λ_GO)

    for &n in &ns {
        let dim = n - 1;
        let start = std::time::Instant::now();

        let entries: Vec<((usize,usize),f64)> = (0..dim).into_par_iter()
            .flat_map(|i| (i..dim).into_par_iter().map(move |j| {
                ((i,j), gram_entry(i+2,j+2,n_pts))
            })).collect();

        let oct_map: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i+2)).collect();

        let mut g = DMatrix::<f64>::zeros(dim,dim);
        let mut go = DMatrix::<f64>::zeros(dim,dim);
        for ((i,j),v) in &entries {
            let w = oct_map[*i].inner(&oct_map[*j]);
            g[(*i,*j)]=*v; g[(*j,*i)]=*v;
            go[(*i,*j)]=w*v; go[(*j,*i)]=w*v;
        }

        let eg = SymmetricEigen::new(g);
        let eo = SymmetricEigen::new(go);
        let lg = eg.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let lo = eo.eigenvalues.iter().cloned().fold(f64::INFINITY, f64::min);
        let t = start.elapsed().as_secs_f64();

        data.push((n as f64, lg, lo));
        println!("  {:6} {:14.10} {:14.10} {:10.4} {:5.1}s",
            n, lg, lo, lo/lg, t);
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 2: Beta function β(N) = N · dλ/dN
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 2: Beta function β = N · dλ/dN ═══\n");
    println!("  {:>6} {:>14} {:>14} {:>14} {:>14}",
        "N", "β_G", "β_G^𝕆", "α_G (local)", "α_G^𝕆 (local)");
    println!("  {}", "─".repeat(66));

    let mut beta_g: Vec<(f64, f64)> = Vec::new();
    let mut beta_go: Vec<(f64, f64)> = Vec::new();

    for i in 1..data.len() {
        let (n1, g1, o1) = data[i-1];
        let (n2, g2, o2) = data[i];
        let n_mid = (n1 + n2) / 2.0;

        // β = N · dλ/dN ≈ N_mid · (λ₂ - λ₁) / (N₂ - N₁)
        let bg = n_mid * (g2 - g1) / (n2 - n1);
        let bo = n_mid * (o2 - o1) / (n2 - n1);

        // Local exponent: α = d(ln λ)/d(ln N)
        let ag = (g2.ln() - g1.ln()) / (n2.ln() - n1.ln());
        let ao = (o2.ln() - o1.ln()) / (n2.ln() - n1.ln());

        let lam_mid_g = (g1 + g2) / 2.0;
        let lam_mid_o = (o1 + o2) / 2.0;

        beta_g.push((lam_mid_g, bg));
        beta_go.push((lam_mid_o, bo));

        println!("  {:6} {:14.10} {:14.10} {:14.6} {:14.6}",
            n_mid as usize, bg, bo, ag, ao);
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 3: β vs λ relationship (looking for fixed points)
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 3: β(λ) relationship — fixed point search ═══\n");

    // Linear fit: β = slope · λ + intercept
    // If intercept ≈ 0, it's pure power law λ ~ N^α
    // If intercept > 0, there's a fixed point at λ* = -intercept/slope

    println!("  G: β vs λ_min");
    println!("  {:>14} {:>14}", "λ_min(G)", "β_G");
    println!("  {}", "─".repeat(30));
    for &(l, b) in &beta_g {
        println!("  {:14.10} {:14.10}", l, b);
    }

    // Linear regression for G
    let n_bg = beta_g.len() as f64;
    let sum_l: f64 = beta_g.iter().map(|(l,_)| l).sum();
    let sum_b: f64 = beta_g.iter().map(|(_,b)| b).sum();
    let sum_ll: f64 = beta_g.iter().map(|(l,_)| l*l).sum();
    let sum_lb: f64 = beta_g.iter().map(|(l,b)| l*b).sum();
    let slope_g = (n_bg * sum_lb - sum_l * sum_b) / (n_bg * sum_ll - sum_l * sum_l);
    let inter_g = (sum_b - slope_g * sum_l) / n_bg;

    println!("\n  Linear fit: β_G = {:.6} · λ + {:.10}", slope_g, inter_g);
    if inter_g.abs() > 1e-6 && slope_g < 0.0 {
        let lam_star = -inter_g / slope_g;
        println!("  Fixed point: λ* = {:.10}", lam_star);
        if lam_star > 0.0 {
            println!("  ⭐ POSITIVE FIXED POINT! λ_min → {:.10} as N → ∞", lam_star);
            println!("     This would imply RH!");
        } else {
            println!("  Fixed point at λ* < 0 — no RH implication.");
        }
    } else {
        println!("  No fixed point (β passes through origin — pure power law)");
    }

    // Same for G^𝕆
    println!("\n  G^𝕆: β vs λ_min");
    println!("  {:>14} {:>14}", "λ_min(G^𝕆)", "β_G^𝕆");
    println!("  {}", "─".repeat(30));
    for &(l, b) in &beta_go {
        println!("  {:14.10} {:14.10}", l, b);
    }

    let sum_l: f64 = beta_go.iter().map(|(l,_)| l).sum();
    let sum_b: f64 = beta_go.iter().map(|(_,b)| b).sum();
    let sum_ll: f64 = beta_go.iter().map(|(l,_)| l*l).sum();
    let sum_lb: f64 = beta_go.iter().map(|(l,b)| l*b).sum();
    let n_bo = beta_go.len() as f64;
    let slope_o = (n_bo * sum_lb - sum_l * sum_b) / (n_bo * sum_ll - sum_l * sum_l);
    let inter_o = (sum_b - slope_o * sum_l) / n_bo;

    println!("\n  Linear fit: β_G^𝕆 = {:.6} · λ + {:.10}", slope_o, inter_o);
    if inter_o.abs() > 1e-6 && slope_o < 0.0 {
        let lam_star = -inter_o / slope_o;
        println!("  Fixed point: λ* = {:.10}", lam_star);
        if lam_star > 0.0 {
            println!("  ⭐ POSITIVE FIXED POINT! G^𝕆 gap → {:.10} as N → ∞", lam_star);
        }
    } else {
        println!("  No clear fixed point.");
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 4: Quadratic fit (nonlinear beta function)
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 4: Nonlinear β(λ) — quadratic fit ═══\n");

    // β = a·λ² + b·λ + c
    // Use last 15 points for stability
    let pts: Vec<(f64,f64)> = beta_g.iter().rev().take(15).rev().cloned().collect();
    if pts.len() >= 3 {
        // Simple quadratic fit via normal equations
        let n = pts.len() as f64;
        let mut sx=0.; let mut sx2=0.; let mut sx3=0.; let mut sx4=0.;
        let mut sy=0.; let mut sxy=0.; let mut sx2y=0.;
        for &(x,y) in &pts {
            sx+=x; sx2+=x*x; sx3+=x*x*x; sx4+=x*x*x*x;
            sy+=y; sxy+=x*y; sx2y+=x*x*y;
        }
        // [n    sx   sx2 ] [c]   [sy  ]
        // [sx   sx2  sx3 ] [b] = [sxy ]
        // [sx2  sx3  sx4 ] [a]   [sx2y]
        // Solve with Cramer's rule or just report coefficients
        let det = n*(sx2*sx4-sx3*sx3) - sx*(sx*sx4-sx3*sx2) + sx2*(sx*sx3-sx2*sx2);
        if det.abs() > 1e-30 {
            let c = (sy*(sx2*sx4-sx3*sx3) - sx*(sxy*sx4-sx2y*sx3) + sx2*(sxy*sx3-sx2y*sx2)) / det;
            let b = (n*(sxy*sx4-sx2y*sx3) - sy*(sx*sx4-sx3*sx2) + sx2*(sx*sx2y-sxy*sx2)) / det;
            let a = (n*(sx2*sx2y-sx3*sxy) - sx*(sx*sx2y-sxy*sx2) + sy*(sx*sx3-sx2*sx2)) / det;

            println!("  β_G(λ) = {:.2}·λ² + {:.4}·λ + {:.10}", a, b, c);

            // Fixed points: β = 0 → a·λ² + b·λ + c = 0
            let disc = b*b - 4.0*a*c;
            if disc >= 0.0 && a.abs() > 1e-10 {
                let r1 = (-b + disc.sqrt()) / (2.0*a);
                let r2 = (-b - disc.sqrt()) / (2.0*a);
                println!("  Fixed points of β_G = 0:");
                println!("    λ*₁ = {:.10}", r1);
                println!("    λ*₂ = {:.10}", r2);
                if r1 > 0.0 || r2 > 0.0 {
                    let fp = if r1 > 0.0 { r1 } else { r2 };
                    println!("  ⭐ POSITIVE FIXED POINT at λ* = {:.10}", fp);

                    // Check stability: β'(λ*) < 0 means stable (IR attractive)
                    let bp = 2.0*a*fp + b;
                    println!("    β'(λ*) = {:.6} → {}",
                        bp, if bp < 0.0 { "STABLE (IR attractive) ✅" } else { "unstable (UV repulsive)" });
                }
            } else if disc < 0.0 {
                println!("  No real fixed points (discriminant < 0)");
                println!("  β never crosses zero — gap decays to 0.");
            }
        }
    }

    // Same for G^𝕆
    let pts_o: Vec<(f64,f64)> = beta_go.iter().rev().take(15).rev().cloned().collect();
    if pts_o.len() >= 3 {
        let n = pts_o.len() as f64;
        let mut sx=0.; let mut sx2=0.; let mut sx3=0.; let mut sx4=0.;
        let mut sy=0.; let mut sxy=0.; let mut sx2y=0.;
        for &(x,y) in &pts_o {
            sx+=x; sx2+=x*x; sx3+=x*x*x; sx4+=x*x*x*x;
            sy+=y; sxy+=x*y; sx2y+=x*x*y;
        }
        let det = n*(sx2*sx4-sx3*sx3) - sx*(sx*sx4-sx3*sx2) + sx2*(sx*sx3-sx2*sx2);
        if det.abs() > 1e-30 {
            let c = (sy*(sx2*sx4-sx3*sx3) - sx*(sxy*sx4-sx2y*sx3) + sx2*(sxy*sx3-sx2y*sx2)) / det;
            let b = (n*(sxy*sx4-sx2y*sx3) - sy*(sx*sx4-sx3*sx2) + sx2*(sx*sx2y-sxy*sx2)) / det;
            let a = (n*(sx2*sx2y-sx3*sxy) - sx*(sx*sx2y-sxy*sx2) + sy*(sx*sx3-sx2*sx2)) / det;

            println!("\n  β_G^𝕆(λ) = {:.2}·λ² + {:.4}·λ + {:.10}", a, b, c);

            let disc = b*b - 4.0*a*c;
            if disc >= 0.0 && a.abs() > 1e-10 {
                let r1 = (-b + disc.sqrt()) / (2.0*a);
                let r2 = (-b - disc.sqrt()) / (2.0*a);
                println!("  Fixed points of β_G^𝕆 = 0:");
                println!("    λ*₁ = {:.10}", r1);
                println!("    λ*₂ = {:.10}", r2);
                if r1 > 0.0 || r2 > 0.0 {
                    let fp = if r1 > 0.0 && r1 < 1.0 { r1 } else if r2 > 0.0 && r2 < 1.0 { r2 } else { r1.max(r2) };
                    println!("  ⭐ POSITIVE FIXED POINT at λ* = {:.10}", fp);
                    let bp = 2.0*a*fp + b;
                    println!("    β'(λ*) = {:.6} → {}",
                        bp, if bp < 0.0 { "STABLE (IR attractive) ✅" } else { "unstable" });
                }
            } else if disc < 0.0 {
                println!("  No real fixed points for G^𝕆.");
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // SECTION 5: Summary and predictions
    // ═══════════════════════════════════════════════════════
    println!("\n═══ Section 5: Asymptotic predictions ═══\n");
    println!("  From power-law fit λ ~ A·N^α:");

    // Fit log(λ) = log(A) + α·log(N) using last 10 points
    let last10: Vec<_> = data.iter().rev().take(10).rev().collect();
    let n_fit = last10.len() as f64;
    let sum_x: f64 = last10.iter().map(|(n,_,_)| n.ln()).sum();
    let sum_y_g: f64 = last10.iter().map(|(_,g,_)| g.ln()).sum();
    let sum_y_o: f64 = last10.iter().map(|(_,_,o)| o.ln()).sum();
    let sum_xx: f64 = last10.iter().map(|(n,_,_)| n.ln()*n.ln()).sum();
    let sum_xy_g: f64 = last10.iter().map(|(n,g,_)| n.ln()*g.ln()).sum();
    let sum_xy_o: f64 = last10.iter().map(|(n,_,o)| n.ln()*o.ln()).sum();

    let alpha_g = (n_fit*sum_xy_g - sum_x*sum_y_g) / (n_fit*sum_xx - sum_x*sum_x);
    let log_a_g = (sum_y_g - alpha_g*sum_x) / n_fit;
    let alpha_o = (n_fit*sum_xy_o - sum_x*sum_y_o) / (n_fit*sum_xx - sum_x*sum_x);
    let log_a_o = (sum_y_o - alpha_o*sum_x) / n_fit;

    println!("  G:   λ_min ≈ {:.6} · N^({:.6})", log_a_g.exp(), alpha_g);
    println!("  G^𝕆: λ_min ≈ {:.6} · N^({:.6})", log_a_o.exp(), alpha_o);

    println!("\n  Predictions:");
    for &n_pred in &[1_000, 5_000, 10_000, 100_000, 1_000_000] {
        let lg = log_a_g.exp() * (n_pred as f64).powf(alpha_g);
        let lo = log_a_o.exp() * (n_pred as f64).powf(alpha_o);
        println!("    N={:>9}: λ_min(G) ≈ {:.8}, λ_min(G^𝕆) ≈ {:.8}, ratio ≈ {:.1}",
            n_pred, lg, lo, lo/lg);
    }

    println!("\n  If alpha > -1: spectral gap -> 0 but sum diverges");
    println!("  If alpha = 0: spectral gap -> const > 0 (strongest form of RH)");
    println!("  If alpha < 0: gap -> 0, but RH only needs gap > 0 for each finite N");

    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Renormalization group flow analysis complete.                  ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
