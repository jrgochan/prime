// overcancellation-scan/src/bin/cotres_spectral.rs
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  COTANGENT RESIDUAL — MULTI-FAMILY SPECTRAL ANATOMY             ║
// ║                                                                   ║
// ║  Master Decomposition (certified in Lean 4, 0 sorry):            ║
// ║    vᵀGv = AbelHammer + LogCorr − CotRes                         ║
// ║                                                                   ║
// ║  Tests whether the three-part harmony (84.5% / -15.3% / -30.8%) ║
// ║  holds across ALL weight families, or is Mertens-specific.       ║
// ╚═══════════════════════════════════════════════════════════════════╝

use cathedral_utils::hpdf::HpdfReader;
use rayon::prelude::*;
use std::path::PathBuf;

/// Compute AbelHammer = -(S - σ/2)² + σ²/4
fn abel_hammer(v: &[f64], offset: usize) -> f64 {
    let sigma: f64 = v.iter().sum();
    let s: f64 = v.iter().enumerate().map(|(i, &vi)| vi / (i + offset) as f64).sum();
    -(s - sigma / 2.0).powi(2) + sigma.powi(2) / 4.0
}

/// Compute LogCorr = σ·T₁ − S·T₂
fn log_correction(v: &[f64], offset: usize) -> f64 {
    let sigma: f64 = v.iter().sum();
    let s: f64 = v.iter().enumerate().map(|(i, &vi)| vi / (i + offset) as f64).sum();
    let t1: f64 = v.iter().enumerate().map(|(i, &vi)| {
        let k = (i + offset) as f64;
        vi * k.ln() / k
    }).sum();
    let t2: f64 = v.iter().enumerate().map(|(i, &vi)| {
        let k = (i + offset) as f64;
        vi * k.ln()
    }).sum();
    sigma * t1 - s * t2
}

/// Compute vᵀGv using the HPDF Gram matrix (parallel)
fn vtgv_hpdf(v: &[f64], gram: &[f64], dim: usize) -> f64 {
    (0..dim).into_par_iter().map(|i| {
        let vi = v[i];
        if vi.abs() < 1e-30 { return 0.0; }
        let mut row_sum = 0.0;
        for j in 0..dim {
            row_sum += gram[i * dim + j] * v[j];
        }
        vi * row_sum
    }).sum()
}

/// Weight family definitions
enum WeightFamily {
    Mertens,      // v_k = -μ(k) · w(k) / k   (Fejér-weighted Mertens)
    FejerMobius,  // v_k = -μ(k) · w(k)         (Fejér-weighted Möbius)
    FlatMobius,   // v_k = -μ(k)                 (flat Möbius)
    Harmonic,     // v_k = 1/k
    Uniform,      // v_k = 1
    InvSqrt,      // v_k = 1/√k
}

impl WeightFamily {
    fn name(&self) -> &str {
        match self {
            WeightFamily::Mertens     => "Mertens μ/k·w",
            WeightFamily::FejerMobius => "Fejér-Möbius μ·w",
            WeightFamily::FlatMobius  => "Flat Möbius μ",
            WeightFamily::Harmonic    => "Harmonic 1/k",
            WeightFamily::Uniform     => "Uniform 1",
            WeightFamily::InvSqrt     => "InvSqrt 1/√k",
        }
    }

    fn short(&self) -> &str {
        match self {
            WeightFamily::Mertens     => "MERT",
            WeightFamily::FejerMobius => "FjMö",
            WeightFamily::FlatMobius  => "FLMö",
            WeightFamily::Harmonic    => "HARM",
            WeightFamily::Uniform     => "UNIF",
            WeightFamily::InvSqrt     => "SQRT",
        }
    }

    fn build_weights(&self, mu: &[i8], n: usize, dim: usize) -> Vec<f64> {
        let log_n = (n as f64).ln();
        let mut v = vec![0.0f64; dim];
        for i in 0..dim {
            let k = i + 2;
            if k >= n { break; }
            let kf = k as f64;
            let mu_k = mu[k] as f64;
            let fejer = 1.0 - kf.ln() / log_n;
            v[i] = match self {
                WeightFamily::Mertens     => -mu_k * fejer / kf,
                WeightFamily::FejerMobius => -mu_k * fejer,
                WeightFamily::FlatMobius  => -mu_k,
                WeightFamily::Harmonic    => 1.0 / kf,
                WeightFamily::Uniform     => 1.0,
                WeightFamily::InvSqrt     => 1.0 / kf.sqrt(),
            };
        }
        v
    }
}

fn main() {
    println!("╔═══════════════════════════════════════════════════════════════════╗");
    println!("║  THREE-PART HARMONY — MULTI-FAMILY PROBE                        ║");
    println!("║  Does AbelHammer:LogCorr:CotRes ratio hold for ALL families?    ║");
    println!("╚═══════════════════════════════════════════════════════════════════╝");
    println!();

    let cache_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent().unwrap()
        .join("cache/hpdf");

    // Test at several N values
    let test_ns: Vec<usize> = vec![360, 2520, 10080, 55440];

    let families = vec![
        WeightFamily::Mertens,
        WeightFamily::FejerMobius,
        WeightFamily::FlatMobius,
        WeightFamily::Harmonic,
        WeightFamily::Uniform,
        WeightFamily::InvSqrt,
    ];

    for &n in &test_ns {
        let path = cache_dir.join(format!("gram_N{}.h5", n));
        if !path.exists() {
            eprintln!("  [skip] {} not found", path.display());
            continue;
        }

        let reader = match HpdfReader::open(&path) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("  [skip] N={}: {}", n, e);
                continue;
            }
        };

        let dim = reader.dim();
        let max_n = reader.max_n();
        assert_eq!(max_n, n);

        let gram = reader.read_gram_full().unwrap();
        let mu_raw = reader.read_mobius().unwrap();

        println!("══════════════════════════════════════════════════════════════════");
        println!("  N = {}  (dim = {})", n, dim);
        println!("══════════════════════════════════════════════════════════════════");
        println!("  {:>16} {:>10} {:>10} {:>10} {:>10} {:>8} {:>8} {:>8}",
            "Family", "vᵀGv", "Abel", "LogCorr", "CotRes", "Abel%", "LogC%", "CotR%");
        println!("  {}", "─".repeat(90));

        for family in &families {
            let v = family.build_weights(&mu_raw, n, dim);

            // Skip if v is all zeros
            let norm: f64 = v.iter().map(|x| x*x).sum();
            if norm < 1e-20 { continue; }

            let vtgv = vtgv_hpdf(&v, &gram, dim);
            let abel = abel_hammer(&v, 2);
            let logcorr = log_correction(&v, 2);
            let cotres = abel + logcorr - vtgv;

            if vtgv.abs() < 1e-15 {
                println!("  {:>16} {:>10.4} {:>10.4} {:>10.4} {:>10.4} {:>8} {:>8} {:>8}",
                    family.short(), vtgv, abel, logcorr, cotres, "n/a", "n/a", "n/a");
            } else {
                let abel_pct = 100.0 * abel / vtgv;
                let logc_pct = 100.0 * logcorr / vtgv;
                let cotr_pct = 100.0 * cotres / vtgv;
                println!("  {:>16} {:>10.4} {:>+10.4} {:>+10.4} {:>+10.4} {:>+7.1}% {:>+7.1}% {:>+7.1}%",
                    family.short(), vtgv, abel, logcorr, cotres, abel_pct, logc_pct, cotr_pct);
            }
        }
        println!();
    }

    // ═══ Cross-N summary for each family ═══
    println!("══════════════════════════════════════════════════════════════════════");
    println!("  CROSS-N RATIO STABILITY (Does the harmony hold across N?)");
    println!("══════════════════════════════════════════════════════════════════════");
    println!();

    for family in &families {
        println!("  --- {} ---", family.name());
        println!("  {:>8} {:>10} {:>8} {:>8} {:>8} {:>10}",
            "N", "vᵀGv", "Abel%", "LogC%", "CotR%", "Crown");
        
        for &n in &test_ns {
            let path = cache_dir.join(format!("gram_N{}.h5", n));
            if !path.exists() { continue; }
            let reader = HpdfReader::open(&path).unwrap();
            let dim = reader.dim();
            let gram = reader.read_gram_full().unwrap();
            let mu_raw = reader.read_mobius().unwrap();

            let v = family.build_weights(&mu_raw, n, dim);
            let norm: f64 = v.iter().map(|x| x*x).sum();
            if norm < 1e-20 { continue; }

            let vtgv = vtgv_hpdf(&v, &gram, dim);
            let abel = abel_hammer(&v, 2);
            let logcorr = log_correction(&v, 2);
            let cotres = abel + logcorr - vtgv;
            let crown = 1.0 - vtgv;

            if vtgv.abs() > 1e-15 {
                println!("  {:>8} {:>10.6} {:>+7.1}% {:>+7.1}% {:>+7.1}% {:>+10.6}",
                    n, vtgv,
                    100.0 * abel / vtgv,
                    100.0 * logcorr / vtgv,
                    100.0 * cotres / vtgv,
                    crown);
            }
        }
        println!();
    }

    println!("══════════════════════════════════════════════════════════════════════");
    println!("  VERDICT: Is the three-part harmony universal?");
    println!("══════════════════════════════════════════════════════════════════════");
    println!("  If Abel%/LogC%/CotR% are similar across families → UNIVERSAL");
    println!("  If they differ wildly → family-specific");
    println!();
    println!("  The Saman speaks. 🎶");
}
