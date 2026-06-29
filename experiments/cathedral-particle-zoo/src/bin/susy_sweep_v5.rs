//! SUSY Sweep v5 — Mellin-Fejér Bridge: Critical Line Subconvexity Probe
//!
//! Measures ζ(1/2+it)·D_N(1/2+it) on the critical line to test whether
//! the Möbius structure of the BD weights creates destructive interference
//! with ζ — the "Dirichlet Collapse" hypothesis.
//!
//! New channels (beyond v4):
//!   Channel 1: ∫|M(1/2+it)|²·logN — Mellin residual L² (should be bounded)
//!   Channel 2: ζ·D cancellation efficiency η_ζD
//!   Channel 3: flat vs Fejér L² ratio ρ(N)
//!   Channel 4: subconvexity exponent α(N)
//!   Channel 5: Dirichlet collapse ratio |ζ·D - 1|
//!
//! Usage:
//!   cargo run --release --bin susy-sweep-v5 -- --cache-dir experiments/cache/hpdf
//!   cargo run --release --bin susy-sweep-v5 -- --cache-dir experiments/cache/hpdf --max-n 10000

use clap::Parser;
use std::path::{Path, PathBuf};
use std::time::Instant;

use cathedral_utils::arith;
use cathedral_utils::hpdf::reader::HpdfReader;
use cathedral_utils::riemann_siegel;

#[derive(Parser)]
#[command(name = "susy-sweep-v5")]
struct Cli {
    /// Directory containing gram_N*.h5 files
    #[arg(long, default_value = "experiments/cache/hpdf")]
    cache_dir: String,

    /// Specific N values to process (comma-separated)
    #[arg(long, value_delimiter = ',')]
    n_values: Vec<usize>,

    /// Maximum N to process
    #[arg(long, default_value = "60000")]
    max_n: usize,

    /// Number of t-grid points for critical line integration
    #[arg(long, default_value = "4096")]
    t_grid: usize,

    /// Maximum t for integration (T_max)
    #[arg(long, default_value = "500.0")]
    t_max: f64,

    /// Output TSV file
    #[arg(long, default_value = "susy_sweep_v5.tsv")]
    output: String,

    /// Output JSON certificate
    #[arg(long, default_value = "susy_certificate_v5.json")]
    cert: String,
}

use std::f64::consts::PI;

/// Complex number (simple inline to avoid extra dependency)
#[derive(Clone, Copy, Debug)]
struct C64 {
    re: f64,
    im: f64,
}

impl C64 {
    fn new(re: f64, im: f64) -> Self {
        Self { re, im }
    }
    fn norm_sq(self) -> f64 {
        self.re * self.re + self.im * self.im
    }
    fn norm(self) -> f64 {
        self.norm_sq().sqrt()
    }
    fn conj(self) -> Self {
        Self {
            re: self.re,
            im: -self.im,
        }
    }
}

impl std::ops::Add for C64 {
    type Output = Self;
    fn add(self, rhs: Self) -> Self {
        Self {
            re: self.re + rhs.re,
            im: self.im + rhs.im,
        }
    }
}
impl std::ops::Sub for C64 {
    type Output = Self;
    fn sub(self, rhs: Self) -> Self {
        Self {
            re: self.re - rhs.re,
            im: self.im - rhs.im,
        }
    }
}
impl std::ops::Mul for C64 {
    type Output = Self;
    fn mul(self, rhs: Self) -> Self {
        Self {
            re: self.re * rhs.re - self.im * rhs.im,
            im: self.re * rhs.im + self.im * rhs.re,
        }
    }
}
impl std::ops::Mul<f64> for C64 {
    type Output = Self;
    fn mul(self, rhs: f64) -> Self {
        Self {
            re: self.re * rhs,
            im: self.im * rhs,
        }
    }
}
impl std::ops::Div for C64 {
    type Output = Self;
    fn div(self, rhs: Self) -> Self {
        let d = rhs.norm_sq();
        if d < 1e-300 {
            return Self::new(0.0, 0.0);
        }
        Self {
            re: (self.re * rhs.re + self.im * rhs.im) / d,
            im: (self.im * rhs.re - self.re * rhs.im) / d,
        }
    }
}

/// k^{-s} = exp(-s·ln(k)) for s = σ + it
fn k_pow_neg_s(k: usize, sigma: f64, t: f64) -> C64 {
    let ln_k = (k as f64).ln();
    let mag = (-sigma * ln_k).exp(); // k^{-σ}
    let phase = -t * ln_k; // -t·ln(k)
    C64::new(mag * phase.cos(), mag * phase.sin())
}

/// Evaluate ζ(1/2+it) via Hardy Z-function:
///   Z(t) = e^{iθ(t)} · ζ(1/2+it), so ζ(1/2+it) = Z(t) · e^{-iθ(t)}
fn zeta_on_critical_line(t: f64) -> C64 {
    if t.abs() < 1.0 {
        // For very small t, use direct summation (RS not accurate)
        let n_terms = 200;
        let _s = C64::new(0.5, t);
        let mut sum = C64::new(0.0, 0.0);
        for n in 1..=n_terms {
            sum = sum + k_pow_neg_s(n, 0.5, t);
        }
        return sum; // Approximate
    }
    let z = riemann_siegel::hardy_z(t);
    let theta = riemann_siegel::rs_theta(t);
    // ζ(1/2+it) = Z(t) · e^{-iθ(t)}
    C64::new(z * (-theta).cos(), z * (-theta).sin())
}

/// Dirichlet polynomial D_N(s) = Σ_{k=2}^{N} v_k · k^{-s}
/// where v_k = -μ(k) · (1 - ln(k)/ln(N))
fn dirichlet_poly(v: &[f64], sigma: f64, t: f64) -> C64 {
    let mut sum = C64::new(0.0, 0.0);
    for (i, &vi) in v.iter().enumerate() {
        if vi.abs() < 1e-20 {
            continue;
        }
        let k = i + 2; // HPDF convention: index 0 → k=2
        let ks = k_pow_neg_s(k, sigma, t);
        sum = sum + ks * vi;
    }
    sum
}

/// Rational part R_N(s) = 1/s - Σ v_k / (k·(s-1))
fn rational_part(v: &[f64], t: f64) -> C64 {
    let s = C64::new(0.5, t);
    let s_minus_1 = C64::new(-0.5, t);
    let one_over_s = C64::new(1.0, 0.0) / s;
    let mut sum = C64::new(0.0, 0.0);
    for (i, &vi) in v.iter().enumerate() {
        if vi.abs() < 1e-20 {
            continue;
        }
        let k = i + 2;
        let term = C64::new(vi / k as f64, 0.0) / s_minus_1;
        sum = sum + term;
    }
    one_over_s - sum
}

/// sinc²(x) — Fejér kernel
fn fejer_kernel(x: f64) -> f64 {
    if x.abs() < 1e-12 {
        return 1.0;
    }
    let pix = PI * x;
    let s = pix.sin() / pix;
    s * s
}

#[derive(Debug, Clone)]
struct MellinResult {
    n: usize,
    dim: usize,
    vtgv: f64,
    // v5 channels
    mellin_l2_log_n: f64,    // (1/2π)∫|M|²·logN
    zeta_d_product_l2: f64,  // ∫|ζ·D|²
    zeta_l2: f64,            // ∫|ζ/s|²
    d_flat_l2: f64,          // ∫|D|² (flat)
    d_fejer_l2: f64,         // Σ|v_k|² (= Fejér-weighted, exact)
    flat_fejer_ratio: f64,   // I_flat / I_fejer
    zeta_d_cancel: f64,      // η_ζD cancellation efficiency
    dirichlet_collapse: f64, // mean |ζ·D - 1| on critical line
    subconv_alpha: f64,      // empirical sup |ζ·D|/t^{1/4}
    r_l2: f64,               // ∫|R|²
    cross_term_real: f64,    // Re ∫ R·conj(ζD/s)
    t_max_used: f64,
    n_grid: usize,
    elapsed_secs: f64,
}

fn analyze_critical_line(path: &Path, t_grid: usize, t_max: f64) -> Option<MellinResult> {
    let t0 = Instant::now();

    let reader = HpdfReader::open(path).ok()?;
    let n = reader.max_n();
    let dim = reader.dim();

    // Read Gram matrix for vᵀGv computation
    let gram = reader.read_gram_full().ok()?;
    if gram.len() != dim * dim {
        return None;
    }

    let mu = arith::mobius_table(n);
    let ln_n = (n as f64).ln();

    // Build witness vector v (HPDF convention: k=2..=N)
    let v: Vec<f64> = (0..dim)
        .map(|i| {
            let k = i + 2;
            let mu_k = mu[k] as f64;
            let w = 1.0 - (k as f64).ln() / ln_n;
            -mu_k * w
        })
        .collect();

    // Compute vᵀGv
    let mut vtgv = 0.0f64;
    for i in 0..dim {
        for j in 0..dim {
            vtgv += v[i] * gram[i * dim + j] * v[j];
        }
    }

    // Fejér-weighted L² (exact): Σ|v_k|²
    let d_fejer_l2: f64 = v.iter().map(|x| x * x).sum();

    // === CRITICAL LINE INTEGRATION ===
    // Adaptive t-grid: denser near small t (where ζ has more structure)
    let dt = t_max / t_grid as f64;

    let mut mellin_l2 = 0.0f64;
    let mut zeta_d_l2 = 0.0f64;
    let mut zeta_over_s_l2 = 0.0f64;
    let mut d_flat_l2 = 0.0f64;
    let mut r_l2 = 0.0f64;
    let mut cross_real = 0.0f64;
    let mut collapse_sum = 0.0f64;
    let mut subconv_max = 0.0f64;
    let mut n_points = 0usize;

    // Integration by trapezoidal rule over [dt, t_max]
    // (skip t=0 where ζ has a pole-like behavior in 1/s)
    for ig in 1..=t_grid {
        let t = ig as f64 * dt;
        if t < 0.5 {
            continue;
        } // skip near-origin

        // Evaluate components at s = 1/2 + it
        let zeta = zeta_on_critical_line(t);
        let s = C64::new(0.5, t);
        let zeta_over_s = zeta / s;
        let d_n = dirichlet_poly(&v, 0.5, t);
        let r_n = rational_part(&v, t);

        // M(s) = R + (ζ/s)·D
        let zeta_d = zeta_over_s * d_n;
        let m_s = r_n + zeta_d;

        // Accumulate integrals (trapezoidal weight = dt, factor 2 for symmetry t↔-t)
        let w = 2.0 * dt; // factor 2: integral over (-∞,∞) = 2·∫(0,∞) by symmetry

        mellin_l2 += m_s.norm_sq() * w;
        zeta_d_l2 += zeta_d.norm_sq() * w;
        zeta_over_s_l2 += zeta_over_s.norm_sq() * w;
        d_flat_l2 += d_n.norm_sq() * w;
        r_l2 += r_n.norm_sq() * w;

        // Cross term: Re(R · conj(ζD/s))
        let cross = r_n * zeta_d.conj();
        cross_real += cross.re * w;

        // Dirichlet collapse: |ζ·D - 1| (should be small if D ≈ 1/ζ)
        // Actually ζ(s)/s · D(s) ≈ 1/s if D ≈ 1/ζ, so check |s·ζ·D/s - 1| = |ζ·D/s·s - 1|
        // Simpler: |ζ(s)·D(s)| ≈ 1 if collapse occurs
        let zeta_times_d = zeta * d_n;
        let collapse_val = (zeta_times_d - C64::new(1.0, 0.0)).norm();
        collapse_sum += collapse_val;

        // Subconvexity: |ζ·D| / t^{1/4}
        if t > 10.0 {
            let alpha = zeta_times_d.norm() / t.powf(0.25);
            if alpha > subconv_max {
                subconv_max = alpha;
            }
        }

        n_points += 1;
    }

    // Normalize
    let inv_2pi = 1.0 / (2.0 * PI);
    mellin_l2 *= inv_2pi;

    // Cancellation efficiency: η_ζD = ∫|ζ·D|² / sqrt(∫|ζ/s|² · ∫|D|²)
    let zeta_d_cancel = if zeta_over_s_l2 > 0.0 && d_flat_l2 > 0.0 {
        zeta_d_l2 / (zeta_over_s_l2 * d_flat_l2).sqrt()
    } else {
        0.0
    };

    let flat_fejer_ratio = if d_fejer_l2 > 1e-15 {
        d_flat_l2 / d_fejer_l2
    } else {
        0.0
    };
    let dirichlet_collapse = if n_points > 0 {
        collapse_sum / n_points as f64
    } else {
        0.0
    };

    let elapsed = t0.elapsed().as_secs_f64();

    Some(MellinResult {
        n,
        dim,
        vtgv,
        mellin_l2_log_n: mellin_l2 * ln_n,
        zeta_d_product_l2: zeta_d_l2,
        zeta_l2: zeta_over_s_l2,
        d_flat_l2,
        d_fejer_l2,
        flat_fejer_ratio,
        zeta_d_cancel,
        dirichlet_collapse,
        subconv_alpha: subconv_max,
        r_l2,
        cross_term_real: cross_real,
        t_max_used: t_max,
        n_grid: n_points,
        elapsed_secs: elapsed,
    })
}

fn main() {
    let cli = Cli::parse();

    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║  SUSY SWEEP v5 — Mellin-Fejér Bridge: Subconvexity Probe          ║");
    println!("║  Testing Dirichlet Collapse: ζ(s)·D_N(s) ≈ 1 on critical line    ║");
    println!(
        "║  T_max={:.0}  grid={}  channels: Mellin L², η_ζD, collapse     ║",
        cli.t_max, cli.t_grid
    );
    println!("╚══════════════════════════════════════════════════════════════════════╝");

    let cache_dir = Path::new(&cli.cache_dir);
    if !cache_dir.exists() {
        eprintln!("Cache directory not found: {}", cli.cache_dir);
        return;
    }

    let mut h5_files: Vec<(usize, PathBuf)> = std::fs::read_dir(cache_dir)
        .unwrap()
        .filter_map(|e| e.ok())
        .filter_map(|e| {
            let name = e.file_name().to_string_lossy().to_string();
            if name.starts_with("gram_N") && name.ends_with(".h5") && !name.contains("_p") {
                let n_str = name.strip_prefix("gram_N")?.strip_suffix(".h5")?;
                let n: usize = n_str.parse().ok()?;
                if n <= cli.max_n
                    && n >= 6
                    && (cli.n_values.is_empty() || cli.n_values.contains(&n))
                {
                    return Some((n, e.path()));
                }
                None
            } else {
                None
            }
        })
        .collect();

    h5_files.sort_by_key(|(n, _)| *n);

    println!(
        "\n  Found {} HPDF files (N ≤ {})",
        h5_files.len(),
        cli.max_n
    );
    println!(
        "  Processing with T_max={}, {} grid points...\n",
        cli.t_max, cli.t_grid
    );

    let t_total = Instant::now();
    let mut results: Vec<MellinResult> = Vec::new();

    for (n, path) in &h5_files {
        eprint!("  N={:>6} ...", n);
        match analyze_critical_line(path, cli.t_grid, cli.t_max) {
            Some(r) => {
                eprintln!(
                    " |M|²·lnN={:>10.4}  η_ζD={:.6}  collapse={:.6}  ρ={:.2}  α={:.4}  ({:.1}s)",
                    r.mellin_l2_log_n,
                    r.zeta_d_cancel,
                    r.dirichlet_collapse,
                    r.flat_fejer_ratio,
                    r.subconv_alpha,
                    r.elapsed_secs
                );
                results.push(r);
            }
            None => {
                eprintln!(" FAILED");
            }
        }
    }

    let total_time = t_total.elapsed().as_secs_f64();

    if results.is_empty() {
        eprintln!("No results.");
        return;
    }

    // ═══ MAIN RESULTS TABLE ═══
    println!("\n  ╔════════╦════════════╦════════════╦════════════╦════════════╦════════════╦════════════╗");
    println!("  ║   N    ║  |M|²·lnN  ║   η_ζD     ║  collapse  ║  flat/fej  ║  α_subconv ║   vᵀGv     ║");
    println!("  ╠════════╬════════════╬════════════╬════════════╬════════════╬════════════╬════════════╣");
    for r in &results {
        println!(
            "  ║{:>7} ║ {:>10.4} ║ {:>10.6} ║ {:>10.6} ║ {:>10.2} ║ {:>10.4} ║ {:>10.6} ║",
            r.n,
            r.mellin_l2_log_n,
            r.zeta_d_cancel,
            r.dirichlet_collapse,
            r.flat_fejer_ratio,
            r.subconv_alpha,
            r.vtgv
        );
    }
    println!("  ╚════════╩════════════╩════════════╩════════════╩════════════╩════════════╩════════════╝");

    // ═══ COMPONENT DECOMPOSITION ═══
    println!("\n  ╔════════╦════════════╦════════════╦════════════╦════════════╦════════════╗");
    println!("  ║   N    ║  ∫|R|²     ║  ∫|ζ/s|²  ║  ∫|D|²flat ║  Σ|v|²fej  ║  Re∫R·ζD*  ║");
    println!("  ╠════════╬════════════╬════════════╬════════════╬════════════╬════════════╣");
    for r in &results {
        println!(
            "  ║{:>7} ║ {:>10.4} ║ {:>10.4} ║ {:>10.4} ║ {:>10.6} ║ {:>+10.4} ║",
            r.n, r.r_l2, r.zeta_l2, r.d_flat_l2, r.d_fejer_l2, r.cross_term_real
        );
    }
    println!("  ╚════════╩════════════╩════════════╩════════════╩════════════╩════════════╝");

    // ═══ TREND ANALYSIS ═══
    println!("\n  ╔══════════════════════════════════════════════════════════════════════╗");
    println!("  ║  MELLIN-FEJÉR BRIDGE ANALYSIS v5                                   ║");
    println!("  ╠══════════════════════════════════════════════════════════════════════╣");

    if results.len() >= 2 {
        let first = results.iter().find(|r| r.n >= 60).unwrap_or(&results[0]);
        let last = results.last().unwrap();

        let eta_trend = if last.zeta_d_cancel < first.zeta_d_cancel {
            "✅ DECAYS"
        } else {
            "⚠  GROWS "
        };
        let col_trend = if last.dirichlet_collapse < first.dirichlet_collapse {
            "✅ DECAYS"
        } else {
            "⚠  GROWS "
        };
        let ml2_bounded = if last.mellin_l2_log_n < first.mellin_l2_log_n * 2.0 {
            "✅ BOUNDED"
        } else {
            "⚠  GROWS  "
        };

        println!(
            "  ║  η_ζD (cancellation):  {:.6} → {:.6}  {}         ║",
            first.zeta_d_cancel, last.zeta_d_cancel, eta_trend
        );
        println!(
            "  ║  collapse |ζD-1|:      {:.6} → {:.6}  {}         ║",
            first.dirichlet_collapse, last.dirichlet_collapse, col_trend
        );
        println!(
            "  ║  |M|²·logN:            {:.4} → {:.4}      {}         ║",
            first.mellin_l2_log_n, last.mellin_l2_log_n, ml2_bounded
        );
        println!("  ║                                                                    ║");

        // Dirichlet collapse verdict
        let collapse_happens =
            last.dirichlet_collapse < first.dirichlet_collapse && last.dirichlet_collapse < 1.0;
        if collapse_happens {
            println!("  ║  🎯 DIRICHLET COLLAPSE DETECTED: ζ·D → 1 on critical line!       ║");
            println!("  ║     This suggests an unconditional bound may exist.               ║");
        } else {
            println!("  ║  📊 No clear Dirichlet collapse — ζ·D correlation persists.      ║");
            println!("  ║     The hRH gap remains necessary for Route 2.                    ║");
        }
    }
    println!("  ╚══════════════════════════════════════════════════════════════════════╝");

    // ═══ WRITE TSV ═══
    let header = "N\tdim\tvtgv\tmellin_l2_logN\tzeta_d_cancel\tdirichlet_collapse\tflat_fejer_ratio\tsubconv_alpha\tr_l2\tzeta_l2\td_flat_l2\td_fejer_l2\tcross_term_real\tzeta_d_product_l2\tt_max\tn_grid\telapsed\n";
    let mut tsv = String::from(header);
    for r in &results {
        tsv.push_str(&format!("{}\t{}\t{:.15}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.10}\t{:.1}\t{}\t{:.2}\n",
            r.n, r.dim, r.vtgv, r.mellin_l2_log_n, r.zeta_d_cancel,
            r.dirichlet_collapse, r.flat_fejer_ratio, r.subconv_alpha,
            r.r_l2, r.zeta_l2, r.d_flat_l2, r.d_fejer_l2, r.cross_term_real,
            r.zeta_d_product_l2, r.t_max_used, r.n_grid, r.elapsed_secs));
    }
    std::fs::write(&cli.output, &tsv).expect("Failed to write TSV");

    // ═══ WRITE JSON ═══
    let cert = format!(r#"{{
  "experiment": "SUSY Sweep v5 — Mellin-Fejér Subconvexity Probe",
  "format": "cathedral-susy-sweep-v5",
  "timestamp": "{}",
  "parameters": {{ "t_max": {}, "t_grid": {} }},
  "max_N_tested": {},
  "files_processed": {},
  "total_time_secs": {:.2},
  "data": [{}
  ]
}}"#,
        chrono::Utc::now().to_rfc3339(),
        cli.t_max, cli.t_grid,
        results.last().map(|r| r.n).unwrap_or(0),
        results.len(), total_time,
        results.iter().map(|r| {
            format!("\n    {{\"N\": {}, \"vtgv\": {:.10}, \"mellin_l2_logN\": {:.10}, \"zeta_d_cancel\": {:.10}, \"dirichlet_collapse\": {:.10}, \"flat_fejer_ratio\": {:.10}, \"subconv_alpha\": {:.10}, \"r_l2\": {:.10}, \"d_fejer_l2\": {:.10}}}",
                r.n, r.vtgv, r.mellin_l2_log_n, r.zeta_d_cancel,
                r.dirichlet_collapse, r.flat_fejer_ratio, r.subconv_alpha,
                r.r_l2, r.d_fejer_l2)
        }).collect::<Vec<_>>().join(",")
    );
    std::fs::write(&cli.cert, &cert).expect("Failed to write JSON");

    println!("\n  Results: {}", cli.output);
    println!("  Certificate: {}", cli.cert);
    println!("  Total: {:.1}s ({} files)", total_time, results.len());
}
