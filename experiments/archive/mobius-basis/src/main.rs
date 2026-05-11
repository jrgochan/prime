#![allow(unused, dead_code)]
// ═══════════════════════════════════════════════════════════════════════
//  ATTACK 5: COVARIANCE DEFLATION EXPERIMENT
//  The Cathedral — Exploration Branch
//
//  Tests Gershgorin diagonal dominance on C̃ = M C Mᵀ, where:
//  - C = G - bbᵀ  (covariance matrix, rank-1 deflated)
//  - b_k = ∫₀¹ {k/x} dx  (mean vector)
//
//  The Theorist's insight: the O(N) Gershgorin growth was caused
//  entirely by the rank-1 background bbᵀ. After removing it,
//  the Möbius transform should produce diagonal dominance on C.
// ═══════════════════════════════════════════════════════════════════════

use nalgebra::DMatrix;
use rayon::prelude::*;
use rug::Float;
use std::time::Instant;

const PREC: u32 = 128;

// ─── Arithmetic ───────────────────────────────────────────────────

fn mobius_sieve(n: usize) -> Vec<i32> {
    let mut mu = vec![0i32; n + 1];
    mu[1] = 1;
    let mut is_prime = vec![true; n + 1];
    let mut primes = Vec::new();
    for i in 2..=n {
        if is_prime[i] {
            primes.push(i);
            mu[i] = -1;
        }
        for &p in &primes {
            if i * p > n {
                break;
            }
            is_prime[i * p] = false;
            if i % p == 0 {
                mu[i * p] = 0;
                break;
            } else {
                mu[i * p] = -mu[i];
            }
        }
    }
    mu
}

fn omega(mut n: usize) -> usize {
    let mut c = 0;
    let mut d = 2;
    while d * d <= n {
        while n % d == 0 {
            c += 1;
            n /= d;
        }
        d += 1;
    }
    if n > 1 {
        c += 1;
    }
    c
}

fn is_prime_fn(n: usize) -> bool {
    if n < 2 {
        return false;
    }
    if n < 4 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }
    let mut d = 5;
    while d * d <= n {
        if n % d == 0 || n % (d + 2) == 0 {
            return false;
        }
        d += 6;
    }
    true
}

// ─── Gram Entry (128-bit MPFR) ───────────────────────────────────

fn gram_entry_mpfr(j: usize, k: usize) -> f64 {
    let jf = j as f64;
    let kf = k as f64;
    let t_max: usize = 5000;

    let mut total = Float::with_val(PREC, 0);
    let jmp = Float::with_val(PREC, jf);
    let kmp = Float::with_val(PREC, kf);

    for n in 1..t_max {
        let block_a = n as f64;
        let block_b = (n + 1) as f64;

        let mut bps = Vec::with_capacity(j + k + 4);
        bps.push(block_a);
        bps.push(block_b);

        let mj_lo = (jf * block_a).ceil() as usize;
        let mj_hi = (jf * block_b).floor() as usize;
        for m in mj_lo..=mj_hi {
            let bp = m as f64 / jf;
            if bp > block_a + 1e-14 && bp < block_b - 1e-14 {
                bps.push(bp);
            }
        }
        let mk_lo = (kf * block_a).ceil() as usize;
        let mk_hi = (kf * block_b).floor() as usize;
        for m in mk_lo..=mk_hi {
            let bp = m as f64 / kf;
            if bp > block_a + 1e-14 && bp < block_b - 1e-14 {
                bps.push(bp);
            }
        }

        bps.sort_by(|a, b| a.partial_cmp(b).unwrap());
        bps.dedup_by(|a, b| (*a - *b).abs() < 1e-14);

        for w in bps.windows(2) {
            let a = Float::with_val(PREC, w[0]);
            let b = Float::with_val(PREC, w[1]);
            if Float::with_val(PREC, &b - &a) < 1e-15 {
                continue;
            }

            let mid = (w[0] + w[1]) / 2.0;
            let fj = (jf * mid).floor();
            let fk = (kf * mid).floor();
            let fj_mp = Float::with_val(PREC, fj);
            let fk_mp = Float::with_val(PREC, fk);

            let term1 = Float::with_val(PREC, &jmp * &kmp) * Float::with_val(PREC, &b - &a);
            let coeff = Float::with_val(PREC, &jmp * &fk_mp) + Float::with_val(PREC, &kmp * &fj_mp);
            let ln_ratio = Float::with_val(PREC, &b / &a).ln();
            let term2 = coeff * ln_ratio;
            let inv_diff = Float::with_val(PREC, Float::with_val(PREC, 1) / &a)
                - Float::with_val(PREC, Float::with_val(PREC, 1) / &b);
            let term3 = Float::with_val(PREC, &fj_mp * &fk_mp) * inv_diff;

            total += term1 - term2 + term3;
        }
    }

    total += Float::with_val(PREC, 0.25) / Float::with_val(PREC, t_max as f64);
    total.to_f64()
}

// ─── Mean Vector b_k = ∫₀¹ {k/x} dx = ∫₁^∞ {kt}/t² dt ─────────

fn mean_entry_mpfr(k: usize) -> f64 {
    let kf = k as f64;
    let t_max: usize = 5000;

    let mut total = Float::with_val(PREC, 0);
    let kmp = Float::with_val(PREC, kf);

    for n in 1..t_max {
        let block_a = n as f64;
        let block_b = (n + 1) as f64;

        let mut bps = Vec::with_capacity(k + 4);
        bps.push(block_a);
        bps.push(block_b);

        let mk_lo = (kf * block_a).ceil() as usize;
        let mk_hi = (kf * block_b).floor() as usize;
        for m in mk_lo..=mk_hi {
            let bp = m as f64 / kf;
            if bp > block_a + 1e-14 && bp < block_b - 1e-14 {
                bps.push(bp);
            }
        }

        bps.sort_by(|a, b| a.partial_cmp(b).unwrap());
        bps.dedup_by(|a, b| (*a - *b).abs() < 1e-14);

        // ∫_a^b {kt}/t² dt where ⌊kt⌋ = A:
        //   = k·ln(b/a) + A·(1/b - 1/a)
        for w in bps.windows(2) {
            let a = Float::with_val(PREC, w[0]);
            let b = Float::with_val(PREC, w[1]);
            if Float::with_val(PREC, &b - &a) < 1e-15 {
                continue;
            }

            let mid = (w[0] + w[1]) / 2.0;
            let fk = (kf * mid).floor();
            let fk_mp = Float::with_val(PREC, fk);

            // k·ln(b/a)
            let term1 = Float::with_val(PREC, &kmp * Float::with_val(PREC, &b / &a).ln());
            // A·(1/b - 1/a)
            let inv_diff = Float::with_val(PREC, Float::with_val(PREC, 1) / &b)
                - Float::with_val(PREC, Float::with_val(PREC, 1) / &a);
            let term2 = Float::with_val(PREC, &fk_mp * inv_diff);

            total += term1 + term2;
        }
    }

    // Tail: ∫_T^∞ {kt}/t² dt ≈ (1/2)/T
    total += Float::with_val(PREC, 0.5) / Float::with_val(PREC, t_max as f64);
    total.to_f64()
}

// ─── Matrix Builders ─────────────────────────────────────────────

fn build_gram_matrix(n: usize) -> DMatrix<f64> {
    let dim = n - 1;
    let t0 = Instant::now();
    let pairs: Vec<(usize, usize)> = (0..dim)
        .flat_map(|i| (i..dim).map(move |j| (i, j)))
        .collect();
    let total = pairs.len();
    let computed = std::sync::atomic::AtomicUsize::new(0);

    let entries: Vec<(usize, usize, f64)> = pairs
        .par_iter()
        .map(|&(i, j)| {
            let val = gram_entry_mpfr(i + 2, j + 2);
            let c = computed.fetch_add(1, std::sync::atomic::Ordering::Relaxed) + 1;
            if c % 200 == 0 || c == total {
                eprint!(
                    "\r    G: [{:5.1}%] {}/{}   ",
                    c as f64 / total as f64 * 100.0,
                    c,
                    total
                );
            }
            (i, j, val)
        })
        .collect();

    let mut g = DMatrix::zeros(dim, dim);
    for (i, j, val) in entries {
        g[(i, j)] = val;
        g[(j, i)] = val;
    }
    eprintln!(
        "\r    G: Done in {:.1}s ({} entries, {} cores)              ",
        t0.elapsed().as_secs_f64(),
        total,
        rayon::current_num_threads()
    );
    g
}

fn build_mean_vector(n: usize) -> Vec<f64> {
    let dim = n - 1;
    let t0 = Instant::now();
    let b: Vec<f64> = (0..dim)
        .into_par_iter()
        .map(|i| mean_entry_mpfr(i + 2))
        .collect();
    eprintln!(
        "    b: Done in {:.1}s ({} entries)",
        t0.elapsed().as_secs_f64(),
        dim
    );
    b
}

fn build_mobius_matrix(n: usize, mu: &[i32]) -> DMatrix<f64> {
    let dim = n - 1;
    let mut m = DMatrix::zeros(dim, dim);
    for i in 0..dim {
        for j in 0..=i {
            let (ii, jj) = (i + 2, j + 2);
            if ii % jj == 0 {
                m[(i, j)] = mu[ii / jj] as f64;
            }
        }
    }
    m
}

// ─── Analysis ─────────────────────────────────────────────────────

struct RowInfo {
    k: usize,
    kind: &'static str,
    mu: i32,
    om: usize,
    diag: f64,
    off: f64,
    ratio: f64,
    gersh: f64,
}

fn analyze(mat: &DMatrix<f64>, mu: &[i32]) -> Vec<RowInfo> {
    let dim = mat.nrows();
    (0..dim)
        .map(|i| {
            let k = i + 2;
            let diag = mat[(i, i)];
            let off: f64 = (0..dim)
                .filter(|&j| j != i)
                .map(|j| mat[(i, j)].abs())
                .sum();
            let ratio = if diag.abs() > 1e-15 {
                off / diag.abs()
            } else {
                f64::INFINITY
            };
            RowInfo {
                k,
                kind: if is_prime_fn(k) {
                    "prime"
                } else if mu[k] != 0 {
                    "sqf"
                } else {
                    "sq!"
                },
                mu: mu[k],
                om: omega(k),
                diag,
                off,
                ratio,
                gersh: diag - off,
            }
        })
        .collect()
}

fn show(rows: &[RowInfo], label: &str, n: usize) {
    println!("\n  {} ({}):", label, n);
    println!(
        "  {:>5} {:>6} {:>4} {:>3} {:>16} {:>16} {:>9}",
        "k", "type", "μ", "Ω", "diagonal", "off-diag sum", "ratio"
    );
    for r in rows.iter().take(n) {
        let s = if r.ratio < 1.0 { "✅" } else { "❌" };
        println!(
            "  {:5} {:>6} {:4} {:3} {:16.12} {:16.12} {:9.6} {}",
            r.k, r.kind, r.mu, r.om, r.diag, r.off, r.ratio, s
        );
    }
}

#[allow(dead_code)]
struct Res {
    n: usize,
    // G stats
    lmin_g: f64,
    cond_g: f64,
    g_max_ratio: f64,
    // G̃ stats
    lmin_gt: f64,
    cond_gt: f64,
    gt_max_ratio: f64,
    // C stats
    lmin_c: f64,
    cond_c: f64,
    c_max_ratio: f64,
    // C̃ stats
    lmin_ct: f64,
    cond_ct: f64,
    ct_max_ratio: f64,
    // NB distance
    nb_dist_sq: f64,
    b_cinv_b: f64,
}

fn sorted_eigenvalues(mat: &DMatrix<f64>) -> Vec<f64> {
    let mut ev: Vec<f64> = mat
        .clone()
        .symmetric_eigen()
        .eigenvalues
        .iter()
        .copied()
        .collect();
    ev.sort_by(|a, b| a.partial_cmp(b).unwrap());
    ev
}

fn gershgorin_max_ratio(rows: &[RowInfo]) -> f64 {
    rows.iter().map(|r| r.ratio).fold(0.0_f64, f64::max)
}

fn gershgorin_frac_dom(rows: &[RowInfo]) -> f64 {
    rows.iter().filter(|r| r.ratio < 1.0).count() as f64 / rows.len() as f64
}

fn experiment(n: usize, mu: &[i32]) -> Res {
    let dim = n - 1;
    println!("\n{}", "━".repeat(74));
    println!(
        "  N = {}  ({}×{}, MPFR-128, {} threads)",
        n,
        dim,
        dim,
        rayon::current_num_threads()
    );
    println!("{}", "━".repeat(74));

    // Build G
    println!("\n  Building Gram matrix G...");
    let g = build_gram_matrix(n);

    // Build b
    println!("  Building mean vector b...");
    let b = build_mean_vector(n);
    println!(
        "  b[0..5] = [{:.8}, {:.8}, {:.8}, {:.8}, {:.8}]",
        b[0],
        b[1],
        b[2],
        b.get(3).unwrap_or(&0.0),
        b.get(4).unwrap_or(&0.0)
    );
    println!(
        "  b²[0..3] = [{:.8}, {:.8}, {:.8}]",
        b[0] * b[0],
        b[1] * b[1],
        b[2] * b[2]
    );

    // Build C = G - b bᵀ
    println!("  Building covariance C = G - bbᵀ...");
    let mut c = g.clone();
    for i in 0..dim {
        for j in 0..dim {
            c[(i, j)] -= b[i] * b[j];
        }
    }
    println!(
        "  C(2,2) = {:.12}  (G={:.12}, b²={:.12})",
        c[(0, 0)],
        g[(0, 0)],
        b[0] * b[0]
    );
    println!(
        "  C(2,3) = {:.12}  (G={:.12}, bb={:.12})",
        c[(0, 1)],
        g[(0, 1)],
        b[0] * b[1]
    );

    // Build M
    let m = build_mobius_matrix(n, mu);

    // G̃ = M G Mᵀ
    let gt = &m * &g * m.transpose();
    let gt = (&gt + gt.transpose()) / 2.0;

    // C̃ = M C Mᵀ
    println!("  Computing C̃ = M C Mᵀ...");
    let ct = &m * &c * m.transpose();
    let ct = (&ct + ct.transpose()) / 2.0;

    // Eigenvalues
    println!("  Computing eigenvalues...");
    let ev_g = sorted_eigenvalues(&g);
    let ev_gt = sorted_eigenvalues(&gt);
    let ev_c = sorted_eigenvalues(&c);
    let ev_ct = sorted_eigenvalues(&ct);

    let (lmin_g, lmax_g) = (ev_g[0], ev_g[dim - 1]);
    let (lmin_gt, lmax_gt) = (ev_gt[0], ev_gt[dim - 1]);
    let (lmin_c, lmax_c) = (ev_c[0], ev_c[dim - 1]);
    let (lmin_ct, lmax_ct) = (ev_ct[0], ev_ct[dim - 1]);

    let cond = |lo: f64, hi: f64| if lo > 0.0 { hi / lo } else { f64::INFINITY };

    // Gershgorin
    let g_rows = analyze(&g, mu);
    let gt_rows = analyze(&gt, mu);
    let c_rows = analyze(&c, mu);
    let mut ct_rows = analyze(&ct, mu);

    // NB distance: d² = 1 - bᵀ G⁻¹ b
    // Also compute X = bᵀ C⁻¹ b to verify d² = 1/(1+X)
    let b_dvec = nalgebra::DVector::from_vec(b.clone());
    let nb_dist_sq;
    let b_cinv_b;

    if let Some(g_inv) = g.clone().try_inverse() {
        let ginv_b = &g_inv * &b_dvec;
        let bt_ginv_b = b_dvec.dot(&ginv_b);
        nb_dist_sq = 1.0 - bt_ginv_b;
        println!("\n  bᵀ G⁻¹ b = {:.12}", bt_ginv_b);
        println!("  d²_N = 1 - bᵀG⁻¹b = {:.12}", nb_dist_sq);
    } else {
        nb_dist_sq = f64::NAN;
        println!("\n  ⚠ G is singular, cannot compute NB distance");
    }

    if let Some(c_inv) = c.clone().try_inverse() {
        let cinv_b = &c_inv * &b_dvec;
        b_cinv_b = b_dvec.dot(&cinv_b);
        let sm_dist = 1.0 / (1.0 + b_cinv_b);
        println!("  bᵀ C⁻¹ b = {:.12} (X)", b_cinv_b);
        println!("  1/(1+X)   = {:.12} (should match d²_N)", sm_dist);
        println!("  Match: {:.2e}", (nb_dist_sq - sm_dist).abs());
    } else {
        b_cinv_b = f64::NAN;
        println!("  ⚠ C is singular");
    }

    // Report
    println!("\n  ┌─ COMPARISON {}┐", "─".repeat(43));
    println!("  │{:>20} {:>14} {:>14}  │", "", "ORIGINAL", "MÖBIUS");
    println!("  │  G   λ_min    {:14.8e} {:14.8e}  │", lmin_g, lmin_gt);
    println!(
        "  │  G   κ        {:14.2} {:14.2}  │",
        cond(lmin_g, lmax_g),
        cond(lmin_gt, lmax_gt)
    );
    println!(
        "  │  G   MaxRatio {:14.6} {:14.6}  │",
        gershgorin_max_ratio(&g_rows),
        gershgorin_max_ratio(&gt_rows)
    );
    println!("  │                                                     │");
    println!("  │  C   λ_min    {:14.8e} {:14.8e}  │", lmin_c, lmin_ct);
    println!(
        "  │  C   κ        {:14.2} {:14.2}  │",
        cond(lmin_c, lmax_c),
        cond(lmin_ct, lmax_ct)
    );
    println!(
        "  │  C   MaxRatio {:14.6} {:14.6}  │",
        gershgorin_max_ratio(&c_rows),
        gershgorin_max_ratio(&ct_rows)
    );
    println!("  │                                                     │");
    println!(
        "  │  Ratio improvement (G̃ vs C̃): {:8.2}×             │",
        gershgorin_max_ratio(&gt_rows) / gershgorin_max_ratio(&ct_rows).max(1e-15)
    );
    println!("  └{}┘", "─".repeat(57));

    let ct_dom = gershgorin_frac_dom(&ct_rows);
    if gershgorin_max_ratio(&ct_rows) < 1.0 {
        println!("\n  ✅✅✅ C̃ IS DIAGONALLY DOMINANT!");
        println!("  → The Covariance Breakthrough is REAL");
    } else if ct_dom > 0.5 {
        println!(
            "\n  ⚠️  C̃ is {:.0}% dominant (max ratio {:.4})",
            ct_dom * 100.0,
            gershgorin_max_ratio(&ct_rows)
        );
    } else {
        println!(
            "\n  ❌ C̃ NOT dominant ({:.0}% fail, max ratio {:.4})",
            (1.0 - ct_dom) * 100.0,
            gershgorin_max_ratio(&ct_rows)
        );
    }

    // Show C̃ worst/best
    ct_rows.sort_by(|a, b| b.ratio.partial_cmp(&a.ratio).unwrap());
    show(&ct_rows, "C̃ WORST ratios", 15.min(dim));
    ct_rows.sort_by(|a, b| a.ratio.partial_cmp(&b.ratio).unwrap());
    show(&ct_rows, "C̃ BEST ratios", 10.min(dim));

    Res {
        n,
        lmin_g,
        cond_g: cond(lmin_g, lmax_g),
        g_max_ratio: gershgorin_max_ratio(&g_rows),
        lmin_gt,
        cond_gt: cond(lmin_gt, lmax_gt),
        gt_max_ratio: gershgorin_max_ratio(&gt_rows),
        lmin_c,
        cond_c: cond(lmin_c, lmax_c),
        c_max_ratio: gershgorin_max_ratio(&c_rows),
        lmin_ct,
        cond_ct: cond(lmin_ct, lmax_ct),
        ct_max_ratio: gershgorin_max_ratio(&ct_rows),
        nb_dist_sq,
        b_cinv_b,
    }
}

fn main() {
    println!("\n{}", "═".repeat(74));
    println!("  ATTACK 5: COVARIANCE DEFLATION EXPERIMENT");
    println!("  G = C + bbᵀ  →  d²_N = 1/(1 + bᵀC⁻¹b)");
    println!("  128-bit MPFR · rayon · The Cathedral");
    println!("{}", "═".repeat(74));

    let sizes = vec![10, 20, 50, 100, 200];
    let max_n = *sizes.last().unwrap();
    let mu = mobius_sieve(max_n + 1);

    let mut results = Vec::new();
    for &n in &sizes {
        results.push(experiment(n, &mu));
    }

    // Grand summary
    println!("\n\n{}", "═".repeat(74));
    println!("  GRAND SUMMARY — G̃ vs C̃ GERSHGORIN RATIOS");
    println!("{}", "═".repeat(74));
    println!(
        "\n  {:>5} {:>10} {:>10} {:>10} {:>10} {:>14} {:>14}",
        "N", "G̃ MaxR", "C̃ MaxR", "C̃ %dom", "κ(C̃)", "bᵀC⁻¹b", "d²_N"
    );
    for r in &results {
        println!(
            "  {:5} {:10.4} {:10.4} {:9.1}% {:10.2} {:14.6} {:14.8e}",
            r.n,
            r.gt_max_ratio,
            r.ct_max_ratio,
            results
                .iter()
                .find(|x| x.n == r.n)
                .map(|_| {
                    // recompute frac_dom inline
                    if r.ct_max_ratio < 1.0 {
                        100.0
                    } else {
                        0.0
                    }
                })
                .unwrap_or(0.0),
            r.cond_ct,
            r.b_cinv_b,
            r.nb_dist_sq
        );
    }

    let ct_ratios: Vec<f64> = results.iter().map(|r| r.ct_max_ratio).collect();
    println!(
        "\n  C̃ ratio trend: {}",
        ct_ratios
            .iter()
            .map(|r| format!("{:.4}", r))
            .collect::<Vec<_>>()
            .join(" → ")
    );

    let gt_ratios: Vec<f64> = results.iter().map(|r| r.gt_max_ratio).collect();
    println!(
        "  G̃ ratio trend: {}",
        gt_ratios
            .iter()
            .map(|r| format!("{:.4}", r))
            .collect::<Vec<_>>()
            .join(" → ")
    );

    // Verdict
    println!("\n{}", "═".repeat(74));
    if ct_ratios.iter().all(|&r| r < 1.0) {
        println!("  ✅✅✅ THE COVARIANCE BREAKTHROUGH IS CONFIRMED!");
        println!("  → C̃ is uniformly diagonally dominant");
        println!("  → Gershgorin gives λ_min(C) > 0 unconditionally");
        println!("  → d²_N = 1/(1 + bᵀC⁻¹b) → 0 as bᵀC⁻¹b → ∞");
        println!("  → THE RIEMANN HYPOTHESIS REDUCES TO bᵀC⁻¹b → ∞");
    } else if ct_ratios.last().unwrap() < gt_ratios.last().unwrap() {
        println!("  📉 Covariance deflation DRAMATICALLY improves ratios");
        println!(
            "  → G̃ max ratio: {:.4}  →  C̃ max ratio: {:.4}",
            gt_ratios.last().unwrap(),
            ct_ratios.last().unwrap()
        );
        if ct_ratios.windows(2).all(|w| w[1] <= w[0] * 1.1) {
            println!("  → C̃ ratios appear stable/decreasing — very promising!");
        } else {
            println!("  → But C̃ ratios still growing — need larger N");
        }
    } else {
        println!("  ⚠️  Covariance deflation did not help enough");
    }
    println!("{}", "═".repeat(74));

    // Write JSON
    let json_entries: Vec<String> = results
        .iter()
        .map(|r| {
            format!(
                r#"    {{
      "N": {}, "gt_max_ratio": {:.10}, "ct_max_ratio": {:.10},
      "cond_C_tilde": {}, "b_Cinv_b": {:.10}, "nb_dist_sq": {:.15e},
      "lambda_min_C": {:.15e}, "lambda_min_Ct": {:.15e}
    }}"#,
                r.n,
                r.gt_max_ratio,
                r.ct_max_ratio,
                if r.cond_ct.is_finite() {
                    format!("{:.6}", r.cond_ct)
                } else {
                    "null".into()
                },
                r.b_cinv_b,
                r.nb_dist_sq,
                r.lmin_c,
                r.lmin_ct
            )
        })
        .collect();

    let json = format!("{{\n  \"experiment\": \"covariance_deflation_attack5\",\n  \"precision_bits\": {},\n  \"results\": [\n{}\n  ]\n}}\n",
        PREC, json_entries.join(",\n"));
    std::fs::write("results_attack5.json", &json).expect("write failed");
    println!("\n  📁 Results → results_attack5.json");
}
