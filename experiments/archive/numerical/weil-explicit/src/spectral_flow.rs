#![allow(unused, dead_code, non_snake_case)]
use nalgebra::{DMatrix, SymmetricEigen};
use rayon::prelude::*;

// ══════════════════════════════════════════════════════════════════════
// SPECTRAL FLOW: Eigenvalue Evolution Under Cross-Class Coupling
//
// Track ALL eigenvalues as continuous functions of:
//   G(t) = G^block + t · G^cross,  t ∈ [0, 1]
//
// Key questions:
// 1. Does λ_min(t) stay positive for all t ∈ [0,1]?
// 2. Are there avoided crossings (level repulsion)?
// 3. Which t-range causes the most damage to the spectral gap?
// 4. Does the flow have a "phase transition" at some critical t?
// 5. What is dλ_min/dt — how fast does the gap close?
//
// Also: per-class-pair flow (add one pair at a time)
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
}

#[derive(Clone)]
struct Oct {
    c: [f64; 8],
}
impl Oct {
    fn basis(i: usize) -> Self {
        let mut c = [0.; 8];
        c[i] = 1.;
        Self { c }
    }
    fn real(a: f64) -> Self {
        Self {
            c: [a, 0., 0., 0., 0., 0., 0., 0.],
        }
    }
    fn norm(&self) -> f64 {
        self.c.iter().map(|x| x * x).sum::<f64>().sqrt()
    }
    fn scale(&self, s: f64) -> Self {
        let mut c = self.c;
        for x in c.iter_mut() {
            *x *= s;
        }
        Self { c }
    }
    fn mul(&self, o: &Self) -> Self {
        let (a, b) = (&self.c, &o.c);
        Self {
            c: [
                a[0] * b[0]
                    - a[1] * b[1]
                    - a[2] * b[2]
                    - a[3] * b[3]
                    - a[4] * b[4]
                    - a[5] * b[5]
                    - a[6] * b[6]
                    - a[7] * b[7],
                a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2] + a[4] * b[5]
                    - a[5] * b[4]
                    - a[6] * b[7]
                    + a[7] * b[6],
                a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1] + a[4] * b[6] + a[5] * b[7]
                    - a[6] * b[4]
                    - a[7] * b[5],
                a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0] + a[4] * b[7] - a[5] * b[6]
                    + a[6] * b[5]
                    - a[7] * b[4],
                a[0] * b[4] - a[1] * b[5] - a[2] * b[6] - a[3] * b[7]
                    + a[4] * b[0]
                    + a[5] * b[1]
                    + a[6] * b[2]
                    + a[7] * b[3],
                a[0] * b[5] + a[1] * b[4] - a[2] * b[7] + a[3] * b[6] - a[4] * b[1] + a[5] * b[0]
                    - a[6] * b[3]
                    + a[7] * b[2],
                a[0] * b[6] + a[1] * b[7] + a[2] * b[4] - a[3] * b[5] - a[4] * b[2]
                    + a[5] * b[3]
                    + a[6] * b[0]
                    - a[7] * b[1],
                a[0] * b[7] - a[1] * b[6] + a[2] * b[5] + a[3] * b[4] - a[4] * b[3] - a[5] * b[2]
                    + a[6] * b[1]
                    + a[7] * b[0],
            ],
        }
    }
    fn dominant_basis(&self) -> usize {
        self.c
            .iter()
            .enumerate()
            .max_by(|(_, a), (_, b)| a.abs().partial_cmp(&b.abs()).unwrap())
            .unwrap()
            .0
    }
}

fn prime_to_basis(p: usize) -> usize {
    match p {
        2 => 1,
        3 => 2,
        5 => 3,
        7 => 4,
        11 => 5,
        13 => 6,
        17 => 7,
        _ => (p % 7) + 1,
    }
}
fn int_to_octonion(k: usize) -> Oct {
    if k <= 1 {
        return Oct::real(1.0);
    }
    let mut r = Oct::real(1.0);
    let mut n = k;
    let mut p = 2;
    while p * p <= n {
        while n.is_multiple_of(p) {
            r = r.mul(&Oct::basis(prime_to_basis(p)));
            n /= p;
        }
        p += 1;
    }
    if n > 1 {
        r = r.mul(&Oct::basis(prime_to_basis(n)));
    }
    let nm = r.norm();
    if nm > 1e-10 {
        r.scale(1. / nm)
    } else {
        Oct::real(1.)
    }
}

fn gram_entry(j: usize, k: usize, n_pts: usize) -> f64 {
    let (jf, kf) = (j as f64, k as f64);
    let dx = 1.0 / n_pts as f64;
    let mut s = 0.0f64;
    for i in 0..n_pts {
        let x = (i as f64 + 0.5) * dx;
        s += frac_part(jf / x) * frac_part(kf / x);
    }
    s * dx
}

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  SPECTRAL FLOW: Eigenvalue Evolution                           ║");
    println!("║  G(t) = G^block + t · G^cross,  t ∈ [0, 1]                    ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    for &n in &[200, 500, 1000] {
        let dim = n - 1;
        let n_pts = if n <= 500 { 200_000 } else { 100_000 };
        let start = std::time::Instant::now();

        println!("═══ N = {} (dim = {}) ═══\n", n, dim);

        let phis: Vec<Oct> = (0..dim).map(|i| int_to_octonion(i + 2)).collect();
        let classes: Vec<usize> = phis.iter().map(|p| p.dominant_basis()).collect();

        let entries: Vec<((usize, usize), f64)> = (0..dim)
            .into_par_iter()
            .flat_map(|i| {
                (i..dim)
                    .into_par_iter()
                    .map(move |j| ((i, j), gram_entry(i + 2, j + 2, n_pts)))
            })
            .collect();

        let mut g_block = DMatrix::<f64>::zeros(dim, dim);
        let mut g_cross = DMatrix::<f64>::zeros(dim, dim);
        for ((i, j), v) in &entries {
            if classes[*i] == classes[*j] {
                g_block[(*i, *j)] = *v;
                g_block[(*j, *i)] = *v;
            } else {
                g_cross[(*i, *j)] = *v;
                g_cross[(*j, *i)] = *v;
            }
        }

        // ── FLOW 1: Continuous t from 0 to 1 ──
        println!("  ── FLOW 1: G(t) = G^block + t·G^cross ──\n");
        println!(
            "  {:>6} {:>12} {:>12} {:>12} {:>12} {:>12}",
            "t", "λ_1 (min)", "λ_2", "λ_3", "λ_5", "λ_10"
        );

        let n_steps = 50;
        let mut flow_data: Vec<(f64, Vec<f64>)> = Vec::new();

        for step in 0..=n_steps {
            let t = step as f64 / n_steps as f64;
            let g_t = &g_block + &(&g_cross * t);
            let eig = SymmetricEigen::new(g_t);
            let mut evs: Vec<f64> = eig.eigenvalues.iter().cloned().collect();
            evs.sort_by(|a, b| a.partial_cmp(b).unwrap());

            if step % 5 == 0 || step == n_steps {
                println!(
                    "  {:6.2} {:12.8} {:12.8} {:12.8} {:12.8} {:12.8}",
                    t,
                    evs[0],
                    evs[1],
                    evs[2],
                    evs[4.min(dim - 1)],
                    evs[9.min(dim - 1)]
                );
            }

            flow_data.push((t, evs[0..10.min(dim)].to_vec()));
        }

        // ── Analysis of the flow ──
        println!("\n  ── Flow Analysis ──");

        // Find where λ_min is most negative slope
        let mut max_slope = 0.0f64;
        let mut max_slope_t = 0.0f64;
        let mut min_slope = f64::MAX;
        let mut min_slope_t = 0.0;

        for i in 1..flow_data.len() {
            let dt = flow_data[i].0 - flow_data[i - 1].0;
            let dlam = flow_data[i].1[0] - flow_data[i - 1].1[0];
            let slope = dlam / dt;

            if slope < min_slope {
                min_slope = slope;
                min_slope_t = (flow_data[i].0 + flow_data[i - 1].0) / 2.0;
            }
            if slope > max_slope {
                max_slope = slope;
                max_slope_t = (flow_data[i].0 + flow_data[i - 1].0) / 2.0;
            }
        }

        let lam0 = flow_data[0].1[0];
        let lam1 = flow_data[n_steps].1[0];
        let avg_slope = (lam1 - lam0) / 1.0;

        println!("  λ_min(0) = {:.8} (block gap)", lam0);
        println!("  λ_min(1) = {:.8} (full gap)", lam1);
        println!("  Average slope = {:.8}", avg_slope);
        println!(
            "  Steepest drop at t ≈ {:.2}, slope = {:.6}",
            min_slope_t, min_slope
        );
        println!(
            "  Steepest rise at t ≈ {:.2}, slope = {:.6}",
            max_slope_t, max_slope
        );

        // ── Check for avoided crossings in bottom eigenvalues ──
        println!("\n  ── Avoided Crossings (bottom 5) ──");
        let mut min_gaps: Vec<(f64, f64, usize)> = Vec::new(); // (t, gap, level_pair)

        for i in 0..flow_data.len() {
            let evs = &flow_data[i].1;
            for j in 0..evs.len() - 1 {
                let gap = evs[j + 1] - evs[j];
                min_gaps.push((flow_data[i].0, gap, j));
            }
        }

        // Find closest approaches for each level pair
        for level in 0..4.min(flow_data[0].1.len() - 1) {
            let closest = min_gaps
                .iter()
                .filter(|(_, _, l)| *l == level)
                .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
            if let Some((t, gap, _)) = closest {
                println!(
                    "  λ_{} — λ_{}: closest approach = {:.8} at t = {:.2}",
                    level + 1,
                    level + 2,
                    gap,
                    t
                );
            }
        }

        // ── FLOW 2: Add class pairs one at a time ──
        println!("\n  ── FLOW 2: Per-Class-Pair Addition ──\n");

        let mut pairs: Vec<(usize, usize, f64)> = Vec::new();
        for m1 in 0..8 {
            for m2 in (m1 + 1)..8 {
                let mut g_pair = DMatrix::<f64>::zeros(dim, dim);
                for i in 0..dim {
                    for j in 0..dim {
                        if (classes[i] == m1 && classes[j] == m2)
                            || (classes[i] == m2 && classes[j] == m1)
                        {
                            g_pair[(i, j)] = g_cross[(i, j)];
                        }
                    }
                }
                let op_norm = SymmetricEigen::new(g_pair.clone())
                    .eigenvalues
                    .iter()
                    .map(|x| x.abs())
                    .fold(0.0f64, f64::max);
                pairs.push((m1, m2, op_norm));
            }
        }

        // Sort by operator norm (add biggest perturbations first)
        pairs.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());

        let mut g_accum = g_block.clone();
        println!(
            "  {:>4} {:>4} {:>12} {:>12} {:>12} {:>12}",
            "m1", "m2", "||pair||_op", "λ_min_after", "Δλ_min", "gap_used%"
        );

        let lmin_block = SymmetricEigen::new(g_block.clone())
            .eigenvalues
            .iter()
            .cloned()
            .fold(f64::INFINITY, f64::min);
        let mut prev_lmin = lmin_block;
        let total_gap_loss = lmin_block - lam1;

        for (m1, m2, op_norm) in &pairs {
            // Add this pair
            for i in 0..dim {
                for j in 0..dim {
                    if (classes[i] == *m1 && classes[j] == *m2)
                        || (classes[i] == *m2 && classes[j] == *m1)
                    {
                        g_accum[(i, j)] += g_cross[(i, j)];
                    }
                }
            }

            let lmin_after = SymmetricEigen::new(g_accum.clone())
                .eigenvalues
                .iter()
                .cloned()
                .fold(f64::INFINITY, f64::min);
            let delta = lmin_after - prev_lmin;
            let gap_pct = if total_gap_loss.abs() > 1e-10 {
                (lmin_block - lmin_after) / total_gap_loss * 100.0
            } else {
                0.0
            };

            println!(
                "  {:4} {:4} {:12.6} {:12.8} {:12.8} {:11.2}%",
                m1, m2, op_norm, lmin_after, delta, gap_pct
            );
            prev_lmin = lmin_after;
        }

        // ── FLOW 3: Quadratic fit near t=1 ──
        println!("\n  ── FLOW 3: Local Behavior Near t=1 ──");
        println!("  (Is the flow linear, quadratic, or exponential?)\n");

        let t_values = [
            0.90, 0.92, 0.94, 0.96, 0.98, 1.00, 1.02, 1.04, 1.06, 1.08, 1.10,
        ];
        println!("  {:>6} {:>12} {:>14}", "t", "λ_min(t)", "dλ/dt ≈");
        let mut prev_t_lam: Option<(f64, f64)> = None;
        for &t in &t_values {
            let g_t = &g_block + &(&g_cross * t);
            let eig = SymmetricEigen::new(g_t);
            let lmin = eig
                .eigenvalues
                .iter()
                .cloned()
                .fold(f64::INFINITY, f64::min);
            let deriv = if let Some((pt, pl)) = prev_t_lam {
                format!("{:14.8}", (lmin - pl) / (t - pt))
            } else {
                format!("{:>14}", "-")
            };
            println!("  {:6.2} {:12.8} {}", t, lmin, deriv);
            prev_t_lam = Some((t, lmin));
        }

        // ── FLOW 4: Does λ_min cross zero for t > 1? ──
        println!("\n  ── FLOW 4: Zero Crossing Search (t > 1) ──");
        let mut t_zero = None;
        for step in 100..500 {
            let t = step as f64 / 100.0;
            let g_t = &g_block + &(&g_cross * t);
            let eig = SymmetricEigen::new(g_t);
            let lmin = eig
                .eigenvalues
                .iter()
                .cloned()
                .fold(f64::INFINITY, f64::min);
            if lmin <= 0.0 {
                t_zero = Some(t);
                println!("  λ_min crosses zero at t ≈ {:.2}", t);
                break;
            }
        }
        if t_zero.is_none() {
            println!("  λ_min stays positive for t ∈ [1, 5]!");
        }

        // ── Precise zero crossing by bisection ──
        if let Some(t_approx) = t_zero {
            let mut lo = t_approx - 0.01;
            let mut hi = t_approx;
            for _ in 0..50 {
                let mid = (lo + hi) / 2.0;
                let g_t = &g_block + &(&g_cross * mid);
                let eig = SymmetricEigen::new(g_t);
                let lmin = eig
                    .eigenvalues
                    .iter()
                    .cloned()
                    .fold(f64::INFINITY, f64::min);
                if lmin > 0.0 {
                    lo = mid;
                } else {
                    hi = mid;
                }
            }
            println!("  Precise t_zero = {:.10}", (lo + hi) / 2.0);
            println!(
                "  Margin: t_zero/1.0 = {:.6} (must be > 1 for RH)",
                (lo + hi) / 2.0
            );
        }

        let t = start.elapsed().as_secs_f64();
        println!("\n  Time: {:.1}s\n", t);
    }

    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  Spectral flow complete.                                       ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
}
