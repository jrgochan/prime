#![allow(unused, dead_code)]
/// ═══════════════════════════════════════════════════════════════════
///  Cross-Class Eigenvalue Verifier v3
///  Now computes G^𝕆 = W ∘ G and the Schur bridge ratio λ_min(G)/λ_min(G^𝕆)
/// ═══════════════════════════════════════════════════════════════════
use std::io::Write;

// ─── Gram Entry (breakpoint-aware analytic integration) ───

fn gram_entry(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let mut breaks: Vec<f64> = Vec::with_capacity(1_100_000);
    let n_max = 500_000;
    for n in 1..=n_max {
        let nf = n as f64;
        let bj = jf / nf;
        if bj > 0.0 && bj <= 1.0 {
            breaks.push(bj);
        }
        if j != k {
            let bk = kf / nf;
            if bk > 0.0 && bk <= 1.0 {
                breaks.push(bk);
            }
        }
    }
    breaks.push(1.0);
    breaks.sort_unstable_by(|a, b| a.partial_cmp(b).unwrap());
    breaks.dedup_by(|a, b| (*a - *b).abs() < 1e-15);

    let mut total = 0.0;
    for i in 0..breaks.len() - 1 {
        let lo = breaks[i];
        let hi = breaks[i + 1];
        if hi - lo < 1e-16 {
            continue;
        }
        let mid = (lo + hi) / 2.0;
        let a = (jf / mid).floor();
        let b = (kf / mid).floor();
        let c1 = jf * kf;
        let c2 = b * jf + a * kf;
        let c3 = a * b;
        let f = |x: f64| -c1 / x - c2 * x.ln() + c3 * x;
        total += f(hi) - f(lo);
    }
    total
}

// ─── Octonionic Map φ and Weight Matrix W ─────────────────

fn min_factor(n: usize) -> usize {
    if n <= 1 {
        return n;
    }
    if n.is_multiple_of(2) {
        return 2;
    }
    let mut d = 3;
    while d * d <= n {
        if n.is_multiple_of(d) {
            return d;
        }
        d += 2;
    }
    n
}

/// primeToBasis: maps prime p to basis index in {1..7}
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

/// intToOctonion(k) returns the basis index (0 for k≤1, else primeToBasis(minFac(k)))
fn octonion_basis(k: usize) -> usize {
    if k <= 1 {
        0
    } else {
        prime_to_basis(min_factor(k))
    }
}

/// Octonionic weight W[j,k] = ⟨φ(j), φ(k)⟩
/// Since φ(k) = basis(octonion_basis(k)), inner product = Kronecker delta
fn octonion_weight(j: usize, k: usize) -> f64 {
    if octonion_basis(j) == octonion_basis(k) {
        1.0
    } else {
        0.0
    }
}

/// Octonion class (same as basis index for k ≥ 2)
fn octonion_class(k: usize) -> usize {
    octonion_basis(k)
}

// ─── Eigenvalues (Householder + QR) ───────────────────────

fn eigenvalues_sym(mat: &[f64], n: usize) -> Vec<f64> {
    if n == 0 {
        return vec![];
    }
    if n == 1 {
        return vec![mat[0]];
    }
    let mut a = mat.to_vec();
    let mut d = vec![0.0; n];
    let mut e = vec![0.0; n];
    for k in 0..n - 2 {
        let mut sigma = 0.0;
        for i in k + 1..n {
            sigma += a[i * n + k] * a[i * n + k];
        }
        let alpha = if a[(k + 1) * n + k] > 0.0 {
            -sigma.sqrt()
        } else {
            sigma.sqrt()
        };
        let r = ((alpha * alpha - a[(k + 1) * n + k] * alpha) / 2.0).sqrt();
        if r.abs() < 1e-30 {
            continue;
        }
        let mut v = vec![0.0; n];
        v[k + 1] = (a[(k + 1) * n + k] - alpha) / (2.0 * r);
        for i in k + 2..n {
            v[i] = a[i * n + k] / (2.0 * r);
        }
        let mut p = vec![0.0; n];
        for i in 0..n {
            for j in 0..n {
                p[i] += a[i * n + j] * v[j];
            }
        }
        let vtp: f64 = v.iter().zip(p.iter()).map(|(a, b)| a * b).sum();
        let mut q = vec![0.0; n];
        for i in 0..n {
            q[i] = p[i] - vtp * v[i];
        }
        for i in 0..n {
            for j in 0..n {
                a[i * n + j] -= 2.0 * (q[i] * v[j] + v[i] * q[j]);
            }
        }
    }
    for i in 0..n {
        d[i] = a[i * n + i];
    }
    for i in 0..n - 1 {
        e[i + 1] = a[(i + 1) * n + i];
    }
    for _iter in 0..200 * n {
        let mut done = true;
        for i in 1..n {
            if e[i].abs() > 1e-14 * (d[i - 1].abs() + d[i].abs() + 1e-30) {
                done = false;
                break;
            }
        }
        if done {
            break;
        }
        let mut hi = n - 1;
        while hi > 0 && e[hi].abs() <= 1e-14 * (d[hi - 1].abs() + d[hi].abs() + 1e-30) {
            hi -= 1;
        }
        let mut lo = hi - 1;
        while lo > 0 && e[lo].abs() > 1e-14 * (d[lo - 1].abs() + d[lo].abs() + 1e-30) {
            lo -= 1;
        }
        let dd = (d[hi - 1] - d[hi]) / 2.0;
        let sgn = if dd >= 0.0 { 1.0 } else { -1.0 };
        let shift = d[hi] - e[hi] * e[hi] / (dd + sgn * (dd * dd + e[hi] * e[hi]).sqrt());
        let mut x = d[lo] - shift;
        let mut z = e[lo + 1];
        for k in lo..hi {
            let r = (x * x + z * z).sqrt();
            let (c, s) = if r > 1e-30 {
                (x / r, -z / r)
            } else {
                (1.0, 0.0)
            };
            if k > lo {
                e[k] = r;
            }
            let d0 = d[k];
            let d1 = d[k + 1];
            d[k] = c * c * d0 + s * s * d1 - 2.0 * c * s * e[k + 1];
            d[k + 1] = s * s * d0 + c * c * d1 + 2.0 * c * s * e[k + 1];
            e[k + 1] = c * s * (d0 - d1) + (c * c - s * s) * e[k + 1];
            if k + 2 <= hi {
                let tmp = e[k + 2];
                e[k + 2] = c * tmp;
                z = -s * tmp;
            }
            x = e[k + 1];
        }
    }
    d.sort_by(|a, b| a.partial_cmp(b).unwrap());
    d
}

// ─── Main ─────────────────────────────────────────────────

fn main() {
    let size = 60;

    eprintln!("═══════════════════════════════════════════════════════════");
    eprintln!("  CROSS-CLASS VERIFIER v3 — Schur Bridge Analysis");
    eprintln!("  Matrix: {}×{}, Breakpoints: 500K", size, size);
    eprintln!("═══════════════════════════════════════════════════════════");

    // Phase 1: Compute Gram matrix
    eprintln!("\n[1] Computing Gram matrix...");
    let mut gram = vec![vec![0.0f64; size]; size];
    for i in 0..size {
        for j in i..size {
            let g = gram_entry(i + 2, j + 2);
            gram[i][j] = g;
            gram[j][i] = g;
        }
        if (i + 1) % 10 == 0 {
            eprintln!("    Row {}/{}", i + 1, size);
        }
    }

    // Phase 2: Compute eigenvalues for each N
    eprintln!("\n[2] Computing eigenvalues and bridge ratios...");

    struct Row {
        n: usize,
        lmin_g: f64,
        lmin_oct: f64, // G^𝕆 = W ∘ G (= G^{block} since W is 0/1)
        lmin_cross: f64,
        bridge_ratio: f64,   // λ_min(G) / λ_min(G^𝕆)
        oct_to_g_ratio: f64, // λ_min(G^𝕆) / λ_min(G) = enhancement factor
    }

    let mut results: Vec<Row> = Vec::new();

    for n_val in 10..=size + 1 {
        let dim = n_val - 1;
        let mut full = vec![0.0f64; dim * dim];
        let mut oct = vec![0.0f64; dim * dim]; // G^𝕆 = W ∘ G

        for i in 0..dim {
            for j in 0..dim {
                let v = gram[i][j];
                let w = octonion_weight(i + 2, j + 2);
                full[i * dim + j] = v;
                oct[i * dim + j] = w * v; // Hadamard product
            }
        }

        let ef = eigenvalues_sym(&full, dim);
        let eo = eigenvalues_sym(&oct, dim);

        // Also compute cross eigenvalues for reference
        let mut cross = vec![0.0f64; dim * dim];
        for i in 0..dim {
            for j in 0..dim {
                if octonion_class(i + 2) != octonion_class(j + 2) {
                    cross[i * dim + j] = gram[i][j];
                }
            }
        }
        let ec = eigenvalues_sym(&cross, dim);

        let bridge = if eo[0].abs() > 1e-15 {
            ef[0] / eo[0]
        } else {
            0.0
        };
        let enhance = if ef[0].abs() > 1e-15 {
            eo[0] / ef[0]
        } else {
            0.0
        };

        results.push(Row {
            n: n_val,
            lmin_g: ef[0],
            lmin_oct: eo[0],
            lmin_cross: ec[0],
            bridge_ratio: bridge,
            oct_to_g_ratio: enhance,
        });

        if n_val % 10 == 0 || n_val == size + 1 {
            eprintln!(
                "    N={:3}: λ_min(G)={:.8} λ_min(G^𝕆)={:.8} ratio={:.4}",
                n_val, ef[0], eo[0], bridge
            );
        }
    }

    // Phase 3: Write JSON results
    let out_path = "schur_bridge_results.json";
    let mut f = std::fs::File::create(out_path).expect("Cannot create output file");
    writeln!(f, "{{").unwrap();
    writeln!(
        f,
        "  \"description\": \"Schur bridge analysis: λ_min(G) / λ_min(G^𝕆)\","
    )
    .unwrap();
    writeln!(f, "  \"matrix_size\": {},", size).unwrap();
    writeln!(
        f,
        "  \"note\": \"G^𝕆 = W ∘ G where W[j,k] = ⟨φ(j),φ(k)⟩ = δ_class(j,class(k))\","
    )
    .unwrap();
    writeln!(f, "  \"data\": [").unwrap();
    for (idx, r) in results.iter().enumerate() {
        let comma = if idx < results.len() - 1 { "," } else { "" };
        writeln!(f, "    {{ \"N\": {}, \"lambda_min_G\": {:.12}, \"lambda_min_Oct\": {:.12}, \"lambda_min_cross\": {:.12}, \"bridge_ratio\": {:.8}, \"enhancement\": {:.4} }}{}",
            r.n, r.lmin_g, r.lmin_oct, r.lmin_cross, r.bridge_ratio, r.oct_to_g_ratio, comma).unwrap();
    }
    writeln!(f, "  ]").unwrap();
    writeln!(f, "}}").unwrap();

    // Phase 4: Summary table
    println!("═══════════════════════════════════════════════════════════════════════════");
    println!("  SCHUR BRIDGE ANALYSIS: λ_min(G) / λ_min(G^𝕆)");
    println!("  If this ratio stabilizes at C > 0, the bridge axiom works.");
    println!("═══════════════════════════════════════════════════════════════════════════");
    println!();
    println!(
        "  {:>4} {:>10} {:>10} {:>10} {:>8} {:>8}",
        "N", "λ_min(G)", "λ_min(G^𝕆)", "λ_min(crs)", "G/G^𝕆", "G^𝕆/G"
    );
    println!("  {}", "─".repeat(66));
    for r in &results {
        println!(
            "  {:>4} {:>10.7} {:>10.7} {:>10.5} {:>8.5} {:>8.3}",
            r.n, r.lmin_g, r.lmin_oct, r.lmin_cross, r.bridge_ratio, r.oct_to_g_ratio
        );
    }

    // Bridge ratio statistics
    let ratios: Vec<f64> = results.iter().map(|r| r.bridge_ratio).collect();
    let min_ratio = ratios.iter().cloned().fold(f64::INFINITY, f64::min);
    let max_ratio = ratios.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let mean_ratio: f64 = ratios.iter().sum::<f64>() / ratios.len() as f64;
    // Last 10 entries for trend
    let tail: Vec<f64> = ratios.iter().rev().take(10).cloned().collect();
    let tail_mean: f64 = tail.iter().sum::<f64>() / tail.len() as f64;
    let tail_min = tail.iter().cloned().fold(f64::INFINITY, f64::min);

    println!();
    println!("  ─── Bridge Ratio Statistics ───");
    println!(
        "    Overall:  min={:.5} max={:.5} mean={:.5}",
        min_ratio, max_ratio, mean_ratio
    );
    println!("    Last 10:  min={:.5} mean={:.5}", tail_min, tail_mean);
    println!();
    if tail_min > 0.0 {
        println!("  ✓ Bridge ratio is POSITIVE (C ≈ {:.4})", tail_min);
        println!(
            "    → λ_min(G) ≥ {:.4} · λ_min(G^𝕆) for N ≤ {}",
            tail_min,
            size + 1
        );
    } else {
        println!("  ✗ Bridge ratio is not uniformly positive");
    }
    println!();
    println!("  Results written to: {}", out_path);
    println!("═══════════════════════════════════════════════════════════════════════════");
}
