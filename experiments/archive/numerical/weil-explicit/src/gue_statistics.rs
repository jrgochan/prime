#![allow(unused, dead_code, non_snake_case)]
use rayon::prelude::*;
use std::f64::consts::PI;

// ══════════════════════════════════════════════════════════════════════
// GUE STATISTICS TEST v2 — IMPROVED SPECTRAL UNFOLDING
//
// Key insight from v1: The Gram matrix G_N has extreme spectral dynamic
// range (λ_min ≈ 0.013, λ_max ≈ 75). Raw polynomial unfolding fails.
//
// v2 improvements:
// 1. LOCAL unfolding via kernel density estimation (KDE)
// 2. Analysis of BULK spectrum (dropping edge eigenvalues)
// 3. Analysis of LOG-eigenvalues (natural for multiplicative structure)
// 4. Ratio distribution r_n = s_n/s_{n+1} (unfolding-independent!)
// 5. Pair correlation on bulk-unfolded spectrum
// ══════════════════════════════════════════════════════════════════════

fn frac_part(x: f64) -> f64 {
    x - x.floor()
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

// ══════════════════════════════════════════════════════════════════════
// JACOBI EIGENVALUE ALGORITHM — Cyclic sweep variant
// ══════════════════════════════════════════════════════════════════════

fn jacobi_eigenvalues_cyclic(mat: &[Vec<f64>], max_sweeps: usize, tol: f64) -> Vec<f64> {
    let n = mat.len();
    let mut a: Vec<Vec<f64>> = mat.to_vec();

    for _sweep in 0..max_sweeps {
        let mut max_off = 0.0f64;
        for i in 0..n {
            for j in (i + 1)..n {
                max_off = max_off.max(a[i][j].abs());
            }
        }
        if max_off < tol {
            break;
        }

        for p in 0..n {
            for q in (p + 1)..n {
                if a[p][q].abs() < tol * 0.01 {
                    continue;
                }

                let app = a[p][p];
                let aqq = a[q][q];
                let apq = a[p][q];

                let theta = if (app - aqq).abs() < 1e-30 {
                    PI / 4.0
                } else {
                    0.5 * (2.0 * apq / (app - aqq)).atan()
                };

                let c = theta.cos();
                let s = theta.sin();

                for i in 0..n {
                    if i != p && i != q {
                        let aip = a[i][p];
                        let aiq = a[i][q];
                        a[i][p] = c * aip + s * aiq;
                        a[p][i] = a[i][p];
                        a[i][q] = -s * aip + c * aiq;
                        a[q][i] = a[i][q];
                    }
                }

                a[p][p] = c * c * app + 2.0 * s * c * apq + s * s * aqq;
                a[q][q] = s * s * app - 2.0 * s * c * apq + c * c * aqq;
                a[p][q] = 0.0;
                a[q][p] = 0.0;
            }
        }
    }

    let mut eigenvalues: Vec<f64> = (0..n).map(|i| a[i][i]).collect();
    eigenvalues.sort_by(|a, b| a.partial_cmp(b).unwrap());
    eigenvalues
}

// ══════════════════════════════════════════════════════════════════════
// IMPROVED SPECTRAL UNFOLDING
// ══════════════════════════════════════════════════════════════════════

/// Local unfolding using cumulative staircase with Gaussian smoothing
fn unfold_local(eigenvalues: &[f64], sigma_frac: f64) -> Vec<f64> {
    let n = eigenvalues.len();
    let range = eigenvalues[n - 1] - eigenvalues[0];
    let sigma = range * sigma_frac; // smoothing bandwidth

    let unfolded: Vec<f64> = eigenvalues
        .iter()
        .map(|&e| {
            // Smoothed staircase: N̄(E) = Σ_i Φ((E - E_i)/σ) where Φ is the normal CDF
            let mut count = 0.0;
            for &ei in eigenvalues {
                let z = (e - ei) / sigma;
                // Approximate normal CDF
                count += 0.5 * (1.0 + erf_approx(z / std::f64::consts::SQRT_2));
            }
            count
        })
        .collect();

    unfolded
}

/// Approximate error function
fn erf_approx(x: f64) -> f64 {
    // Abramowitz & Stegun approximation
    let sign = if x >= 0.0 { 1.0 } else { -1.0 };
    let x = x.abs();
    let t = 1.0 / (1.0 + 0.3275911 * x);
    let poly = t
        * (0.254829592
            + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
    sign * (1.0 - poly * (-x * x).exp())
}

/// Unfolding via ECDF (empirical cumulative distribution)
/// Simplest unfolding: ξ_i = N(E_i) where N is interpolated staircase
fn unfold_ecdf(eigenvalues: &[f64]) -> Vec<f64> {
    let n = eigenvalues.len() as f64;
    eigenvalues
        .iter()
        .enumerate()
        .map(|(i, _)| (i as f64 + 0.5) / n * n)
        .collect()
}

// ══════════════════════════════════════════════════════════════════════
// RATIO DISTRIBUTION — UNFOLDING-INDEPENDENT TEST!
// ══════════════════════════════════════════════════════════════════════

/// Compute ratios r_n = min(s_n, s_{n+1}) / max(s_n, s_{n+1})
/// This is unfolding-independent! (Atas et al. 2013)
/// GUE: <r> ≈ 0.5996 (β=2)
/// GOE: <r> ≈ 0.5307 (β=1)
/// GSE: <r> ≈ 0.6744 (β=4)
/// Poisson: <r> ≈ 0.3863
fn compute_ratios(eigenvalues: &[f64]) -> Vec<f64> {
    let n = eigenvalues.len();
    if n < 3 {
        return vec![];
    }

    let mut ratios = Vec::with_capacity(n - 2);
    for i in 0..(n - 2) {
        let s1 = eigenvalues[i + 1] - eigenvalues[i];
        let s2 = eigenvalues[i + 2] - eigenvalues[i + 1];
        if s1 > 1e-15 && s2 > 1e-15 {
            let r = s1.min(s2) / s1.max(s2);
            ratios.push(r);
        }
    }
    ratios
}

/// Surmise for ratio distribution (Atas et al. 2013)
/// GOE (β=1): P(r) = 27/8 · (r+r²)/(1+r+r²)^{5/2}
fn ratio_pdf_goe(r: f64) -> f64 {
    27.0 / 8.0 * (r + r * r) / (1.0 + r + r * r).powf(2.5)
}

/// GUE (β=2): P(r) = 81√3/(4π) · (r+r²)²/(1+r+r²)⁴
fn ratio_pdf_gue(r: f64) -> f64 {
    81.0 * 3.0f64.sqrt() / (4.0 * PI) * (r + r * r).powi(2) / (1.0 + r + r * r).powi(4)
}

/// Poisson: P(r) = 2/(1+r)²
fn ratio_pdf_poisson(r: f64) -> f64 {
    2.0 / (1.0 + r).powi(2)
}

// ══════════════════════════════════════════════════════════════════════
// WIGNER SURMISES
// ══════════════════════════════════════════════════════════════════════

fn wigner_goe(s: f64) -> f64 {
    (PI / 2.0) * s * (-PI * s * s / 4.0).exp()
}

fn wigner_gue(s: f64) -> f64 {
    (32.0 / (PI * PI)) * s * s * (-4.0 * s * s / PI).exp()
}

fn wigner_gse(s: f64) -> f64 {
    let coeff = (2.0f64).powi(18) / ((3.0f64).powi(6) * PI.powi(3));
    coeff * s.powi(4) * (-64.0 * s * s / (9.0 * PI)).exp()
}

fn poisson_pdf(s: f64) -> f64 {
    (-s).exp()
}

fn cdf_gue(s: f64) -> f64 {
    let n = 1000;
    let ds = s / n as f64;
    let mut v = 0.0;
    for i in 0..n {
        v += wigner_gue((i as f64 + 0.5) * ds) * ds;
    }
    v.min(1.0)
}

fn cdf_goe(s: f64) -> f64 {
    let n = 1000;
    let ds = s / n as f64;
    let mut v = 0.0;
    for i in 0..n {
        v += wigner_goe((i as f64 + 0.5) * ds) * ds;
    }
    v.min(1.0)
}

fn cdf_poisson(s: f64) -> f64 {
    1.0 - (-s).exp()
}

fn cdf_gse(s: f64) -> f64 {
    let n = 1000;
    let ds = s / n as f64;
    let mut v = 0.0;
    for i in 0..n {
        v += wigner_gse((i as f64 + 0.5) * ds) * ds;
    }
    v.min(1.0)
}

fn ks_test(spacings: &[f64], cdf_fn: fn(f64) -> f64) -> f64 {
    let n = spacings.len();
    let mut sorted = spacings.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let mut d_max = 0.0f64;
    for (i, &s) in sorted.iter().enumerate() {
        let fn_val = (i + 1) as f64 / n as f64;
        let f_val = cdf_fn(s);
        d_max = d_max.max((fn_val - f_val).abs());
        let fn_prev = i as f64 / n as f64;
        d_max = d_max.max((fn_prev - f_val).abs());
    }
    d_max
}

// ══════════════════════════════════════════════════════════════════════
// MAIN
// ══════════════════════════════════════════════════════════════════════

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  MONTGOMERY-DYSON TEST v2: GUE Statistics of Gram Matrix G_N   ║");
    println!("║  Improved: local unfolding + ratio distribution + bulk focus    ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    let total_start = std::time::Instant::now();
    let test_sizes: Vec<usize> = vec![100, 200, 300];
    let n_pts = 200_000;

    for &max_n in &test_sizes {
        let dim = max_n - 1;
        println!("═══════════════════════════════════════════════════════════════");
        println!("  N = {} ({}×{} Gram matrix)", max_n, dim, dim);
        println!("═══════════════════════════════════════════════════════════════\n");

        // Phase 1: Compute Gram matrix
        let phase_start = std::time::Instant::now();
        print!("  [1/7] Computing Gram matrix... ");
        let gram_upper: Vec<Vec<f64>> = (0..dim)
            .into_par_iter()
            .map(|j| {
                let mut row = vec![0.0; dim];
                for k in j..dim {
                    row[k] = gram_entry(j + 2, k + 2, n_pts);
                }
                row
            })
            .collect();

        let mut gram = vec![vec![0.0; dim]; dim];
        for j in 0..dim {
            for k in j..dim {
                gram[j][k] = gram_upper[j][k];
                gram[k][j] = gram_upper[j][k];
            }
        }
        println!("{:.1}s", phase_start.elapsed().as_secs_f64());

        // Phase 2: Compute ALL eigenvalues
        print!("  [2/7] Computing all {} eigenvalues (Jacobi)... ", dim);
        let eig_start = std::time::Instant::now();
        let eigenvalues = jacobi_eigenvalues_cyclic(&gram, 200, 1e-12);
        println!("{:.1}s", eig_start.elapsed().as_secs_f64());

        println!("        λ_min = {:.10}", eigenvalues[0]);
        println!("        λ_max = {:.10}", eigenvalues[dim - 1]);
        println!(
            "        λ_mean = {:.10}",
            eigenvalues.iter().sum::<f64>() / dim as f64
        );
        println!(
            "        Dynamic range: {:.1}×",
            eigenvalues[dim - 1] / eigenvalues[0]
        );

        // Phase 3: RATIO DISTRIBUTION (unfolding-independent!)
        println!("\n  [3/7] RATIO DISTRIBUTION (unfolding-independent, Atas et al. 2013)\n");

        let ratios = compute_ratios(&eigenvalues);
        let r_mean: f64 = ratios.iter().sum::<f64>() / ratios.len() as f64;

        println!("        ⟨r⟩ = {:.6}", r_mean);
        println!("        GUE (β=2) predicts: 0.5996");
        println!("        GOE (β=1) predicts: 0.5307");
        println!("        GSE (β=4) predicts: 0.6744");
        println!("        Poisson predicts:   0.3863\n");

        // Which is closest?
        let diffs = vec![
            ("GUE (β=2)", (r_mean - 0.5996).abs()),
            ("GOE (β=1)", (r_mean - 0.5307).abs()),
            ("GSE (β=4)", (r_mean - 0.6744).abs()),
            ("Poisson", (r_mean - 0.3863).abs()),
        ];
        let mut sorted_diffs = diffs.clone();
        sorted_diffs.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
        println!(
            "        🏆 Closest to: {} (Δ = {:.6})",
            sorted_diffs[0].0, sorted_diffs[0].1
        );
        println!(
            "           2nd best:   {} (Δ = {:.6})",
            sorted_diffs[1].0, sorted_diffs[1].1
        );

        // Ratio histogram
        let n_bins = 20;
        let mut r_hist = vec![0usize; n_bins];
        for &r in &ratios {
            let bin = (r * n_bins as f64) as usize;
            if bin < n_bins {
                r_hist[bin] += 1;
            }
        }

        println!(
            "\n        {:>6} {:>8} {:>8} {:>8} {:>8} {:>30}",
            "r", "Data", "GUE", "GOE", "Poisson", "Distribution"
        );
        println!("        {}", "─".repeat(80));

        for i in 0..n_bins {
            let r = (i as f64 + 0.5) / n_bins as f64;
            let bw = 1.0 / n_bins as f64;
            let data_val = r_hist[i] as f64 / (ratios.len() as f64 * bw);
            let gue = ratio_pdf_gue(r);
            let goe = ratio_pdf_goe(r);
            let poi = ratio_pdf_poisson(r);

            let bar_len = (data_val * 15.0) as usize;
            let bar: String = "█".repeat(bar_len.min(30));

            println!(
                "        {:6.3} {:8.4} {:8.4} {:8.4} {:8.4}  {}",
                r, data_val, gue, goe, poi, bar
            );
        }

        // Phase 4: BULK analysis — drop 10% from each edge
        println!("\n  [4/7] BULK SPECTRUM ANALYSIS (dropping 10% edges)\n");

        let edge_frac = 0.10;
        let lo = (dim as f64 * edge_frac) as usize;
        let hi = dim - lo;
        let bulk = &eigenvalues[lo..hi];
        println!(
            "        Bulk: eigenvalues [{} .. {}] out of {}",
            lo, hi, dim
        );
        println!(
            "        Bulk range: [{:.6}, {:.6}]",
            bulk[0],
            bulk[bulk.len() - 1]
        );

        // Unfold the bulk using local KDE
        let bulk_unfolded = unfold_local(bulk, 0.05);
        let mut bulk_spacings: Vec<f64> = Vec::new();
        for i in 0..(bulk_unfolded.len() - 1) {
            let s = bulk_unfolded[i + 1] - bulk_unfolded[i];
            if s >= 0.0 {
                bulk_spacings.push(s);
            }
        }
        // Normalize
        let mean_s: f64 = bulk_spacings.iter().sum::<f64>() / bulk_spacings.len() as f64;
        if mean_s > 1e-15 {
            for s in bulk_spacings.iter_mut() {
                *s /= mean_s;
            }
        }

        let bulk_ratios = compute_ratios(bulk);
        let bulk_r_mean: f64 = if !bulk_ratios.is_empty() {
            bulk_ratios.iter().sum::<f64>() / bulk_ratios.len() as f64
        } else {
            0.0
        };

        println!(
            "        Bulk ⟨r⟩ = {:.6} (GUE: 0.5996, GOE: 0.5307, Poisson: 0.3863)",
            bulk_r_mean
        );

        // KS tests on bulk spacings
        let d_gue = ks_test(&bulk_spacings, cdf_gue);
        let d_goe = ks_test(&bulk_spacings, cdf_goe);
        let d_poi = ks_test(&bulk_spacings, cdf_poisson);
        let d_gse = ks_test(&bulk_spacings, cdf_gse);
        let n_eff = bulk_spacings.len() as f64;
        let d_crit = 1.36 / n_eff.sqrt();

        println!("\n        Bulk NNSD KS tests (D_crit = {:.4}):", d_crit);
        println!(
            "          GUE:     D = {:.6} {}",
            d_gue,
            if d_gue < d_crit { "✅" } else { "❌" }
        );
        println!(
            "          GOE:     D = {:.6} {}",
            d_goe,
            if d_goe < d_crit { "✅" } else { "❌" }
        );
        println!(
            "          GSE:     D = {:.6} {}",
            d_gse,
            if d_gse < d_crit { "✅" } else { "❌" }
        );
        println!(
            "          Poisson: D = {:.6} {}",
            d_poi,
            if d_poi < d_crit { "✅" } else { "❌" }
        );

        // Phase 5: LOG-EIGENVALUE analysis
        println!("\n  [5/7] LOG-EIGENVALUE ANALYSIS\n");
        println!("        (Natural for multiplicative structure — Dyson's Brownian motion)");

        let log_eigenvalues: Vec<f64> = eigenvalues
            .iter()
            .filter(|&&e| e > 0.0)
            .map(|&e| e.ln())
            .collect();

        let log_ratios = compute_ratios(&log_eigenvalues);
        let log_r_mean: f64 = if !log_ratios.is_empty() {
            log_ratios.iter().sum::<f64>() / log_ratios.len() as f64
        } else {
            0.0
        };

        println!("        Log-eigenvalue ⟨r⟩ = {:.6}", log_r_mean);
        println!("        GUE: 0.5996, GOE: 0.5307, GSE: 0.6744, Poisson: 0.3863");

        let log_diffs = vec![
            ("GUE (β=2)", (log_r_mean - 0.5996).abs()),
            ("GOE (β=1)", (log_r_mean - 0.5307).abs()),
            ("GSE (β=4)", (log_r_mean - 0.6744).abs()),
            ("Poisson", (log_r_mean - 0.3863).abs()),
        ];
        let mut sorted_log = log_diffs.clone();
        sorted_log.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
        println!(
            "        🏆 Closest to: {} (Δ = {:.6})",
            sorted_log[0].0, sorted_log[0].1
        );

        // Phase 6: DENSITY-OF-STATES analysis
        println!("\n  [6/7] EIGENVALUE DENSITY OF STATES\n");

        let n_dos_bins = 30;
        let e_min = eigenvalues[0];
        let e_max = eigenvalues[dim - 1].min(eigenvalues[0] * 50.0); // cap for visualization
        let bw = (e_max - e_min) / n_dos_bins as f64;
        let mut dos_hist = vec![0usize; n_dos_bins];
        for &e in &eigenvalues {
            if e >= e_min && e <= e_max {
                let bin = ((e - e_min) / bw) as usize;
                if bin < n_dos_bins {
                    dos_hist[bin] += 1;
                }
            }
        }

        println!("        {:>8} {:>6} {:>30}", "Energy", "Count", "Density");
        println!("        {}", "─".repeat(50));
        for i in 0..n_dos_bins {
            let e = e_min + (i as f64 + 0.5) * bw;
            let count = dos_hist[i];
            let bar_len = (count as f64 * 40.0 / dim as f64 * n_dos_bins as f64 / 3.0) as usize;
            let bar: String = "█".repeat(bar_len.min(30));
            println!("        {:8.4} {:6} {}", e, count, bar);
        }

        // Phase 7: LEVEL REPULSION in different spectral regions
        println!("\n  [7/7] LEVEL REPULSION BY SPECTRAL REGION\n");

        let regions = [
            ("Bottom 25%", 0, dim / 4),
            ("Lower mid", dim / 4, dim / 2),
            ("Upper mid", dim / 2, 3 * dim / 4),
            ("Top 25%", 3 * dim / 4, dim),
        ];

        println!(
            "        {:>12} {:>8} {:>10} {:>10} {:>12}",
            "Region", "Size", "⟨r⟩", "Best fit", "β estimate"
        );
        println!("        {}", "─".repeat(60));

        for (name, lo, hi) in &regions {
            if *hi <= *lo + 3 {
                continue;
            }
            let region = &eigenvalues[*lo..*hi];
            let region_ratios = compute_ratios(region);
            if region_ratios.is_empty() {
                continue;
            }

            let rm: f64 = region_ratios.iter().sum::<f64>() / region_ratios.len() as f64;

            let fits = [
                ("GUE", (rm - 0.5996).abs()),
                ("GOE", (rm - 0.5307).abs()),
                ("GSE", (rm - 0.6744).abs()),
                ("Poisson", (rm - 0.3863).abs()),
            ];
            let best = fits
                .iter()
                .min_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
                .unwrap();

            // Estimate β from <r>: β ≈ (2<r> - 1)/(1 - <r>) · 1.27 (rough interpolation)
            // Better: use the inverse of the Surmise relationship
            let beta_est = if rm < 0.4 {
                0.0
            } else if rm < 0.54 {
                (rm - 0.3863) / (0.5307 - 0.3863)
            } else if rm < 0.64 {
                1.0 + (rm - 0.5307) / (0.5996 - 0.5307)
            } else {
                2.0 + 2.0 * (rm - 0.5996) / (0.6744 - 0.5996)
            };

            println!(
                "        {:>12} {:>8} {:>10.6} {:>10} {:>12.3}",
                name,
                hi - lo,
                rm,
                best.0,
                beta_est
            );
        }

        // ═══ FULL NNSD HISTOGRAM (with improved unfolding) ═══
        println!("\n  ═══ FULL NNSD HISTOGRAM (local KDE unfolding) ═══\n");

        let full_unfolded = unfold_local(&eigenvalues, 0.03);
        let mut full_spacings: Vec<f64> = Vec::new();
        for i in 0..(full_unfolded.len() - 1) {
            let s = full_unfolded[i + 1] - full_unfolded[i];
            if s >= 0.0 {
                full_spacings.push(s);
            }
        }
        let mean_fs: f64 = full_spacings.iter().sum::<f64>() / full_spacings.len() as f64;
        if mean_fs > 1e-15 {
            for s in full_spacings.iter_mut() {
                *s /= mean_fs;
            }
        }

        let n_bins = 25;
        let s_max = 4.0;
        let bin_width = s_max / n_bins as f64;
        let mut histogram = vec![0usize; n_bins];
        for &s in &full_spacings {
            let bin = (s / bin_width) as usize;
            if bin < n_bins {
                histogram[bin] += 1;
            }
        }

        println!(
            "  {:>6} {:>8} {:>8} {:>8} {:>8} {:>30}",
            "s", "Data", "GUE", "GOE", "Poisson", ""
        );
        println!("  {}", "─".repeat(80));

        for i in 0..n_bins {
            let s = (i as f64 + 0.5) * bin_width;
            let data_density = histogram[i] as f64 / (full_spacings.len() as f64 * bin_width);
            let gue_val = wigner_gue(s);
            let goe_val = wigner_goe(s);
            let poi_val = poisson_pdf(s);

            let bar_max = 40;
            let bar_len = (data_density * (bar_max as f64) / 1.1) as usize;
            let gue_pos = (gue_val * (bar_max as f64) / 1.1) as usize;

            let mut bars = vec![' '; bar_max];
            for c in 0..bar_len.min(bar_max) {
                bars[c] = '█';
            }
            if gue_pos < bar_max {
                bars[gue_pos] = if gue_pos < bar_len { '◆' } else { '◇' };
            }

            let bar_str: String = bars.iter().collect();

            println!(
                "  {:6.2} {:8.4} {:8.4} {:8.4} {:8.4}  {}",
                s, data_density, gue_val, goe_val, poi_val, bar_str
            );
        }

        // KS on full locally-unfolded spacings
        let fd_gue = ks_test(&full_spacings, cdf_gue);
        let fd_goe = ks_test(&full_spacings, cdf_goe);
        let fd_poi = ks_test(&full_spacings, cdf_poisson);
        let fd_gse = ks_test(&full_spacings, cdf_gse);
        let fd_crit = 1.36 / (full_spacings.len() as f64).sqrt();

        println!("\n  KS tests (local unfolding, D_crit = {:.4}):", fd_crit);
        let mut ks_results = vec![
            ("GUE (β=2)", fd_gue),
            ("GOE (β=1)", fd_goe),
            ("GSE (β=4)", fd_gse),
            ("Poisson", fd_poi),
        ];
        ks_results.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
        for (name, d) in &ks_results {
            println!(
                "    {:<12} D = {:.6} {}",
                name,
                d,
                if *d < fd_crit { "✅" } else { "❌" }
            );
        }

        println!("\n  ═══════════════════════════════════════════════");
        println!("  SUMMARY for N = {}", max_n);
        println!("  ═══════════════════════════════════════════════");
        println!(
            "  Full spectrum  ⟨r⟩ = {:.6} → {}",
            r_mean, sorted_diffs[0].0
        );
        println!("  Bulk (80%)     ⟨r⟩ = {:.6}", bulk_r_mean);
        println!(
            "  Log-eigenvalue ⟨r⟩ = {:.6} → {}",
            log_r_mean, sorted_log[0].0
        );
        println!("  Best NNSD fit: {}", ks_results[0].0);
        println!();
    }

    // ═══ CROSS-N EVOLUTION ═══
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║                    MONTGOMERY-DYSON VERDICT                     ║");
    println!("╠══════════════════════════════════════════════════════════════════╣");
    println!("║                                                                ║");
    println!("║  The RATIO TEST ⟨r⟩ is the gold standard — no unfolding needed.║");
    println!("║                                                                ║");
    println!("║  ⟨r⟩ ≈ 0.386 → Poisson (integrable, no correlations)          ║");
    println!("║  ⟨r⟩ ≈ 0.531 → GOE (time-reversal symmetric)                 ║");
    println!("║  ⟨r⟩ ≈ 0.600 → GUE (broken time-reversal, like ζ zeros)      ║");
    println!("║  ⟨r⟩ ≈ 0.674 → GSE (quaternionic, Kramers degeneracy)        ║");
    println!("║                                                                ║");
    println!("║  Key insight: The Gram matrix eigenvalue statistics reveal     ║");
    println!("║  what kind of quantum system the number-theoretic operator     ║");
    println!("║  belongs to, directly connecting to the Hilbert-Pólya program. ║");
    println!("║                                                                ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");

    println!(
        "\n  Total computation time: {:.1}s\n",
        total_start.elapsed().as_secs_f64()
    );
}
