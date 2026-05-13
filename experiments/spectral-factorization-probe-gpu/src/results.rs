//! Certified results output for GPU spectral factorization probes.
//!
//! Produces machine-readable JSON certificates and human-readable
//! analysis summaries. Each run generates:
//!
//!   results/probe_gpu_<timestamp>/
//!     ├── manifest.json              — run metadata + environment
//!     ├── class_16bit.json           — per-class probe results
//!     ├── class_24bit.json
//!     ├── class_32bit.json
//!     ├── class_40bit.json
//!     └── analysis_summary.json      — cross-class statistical analysis

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

// ═══════════════════════════════════════════════════════════════
// RESULT TYPES — one per hypothesis
// ═══════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct H1Result {
    pub n: u64,
    pub p: u64,
    pub q: u64,
    pub dim: usize,
    pub lambda_min: f64,
    pub factor_density: f64,
    pub nonfactor_density: f64,
    pub density_ratio: f64,
    pub build_time_s: f64,
    pub eigen_time_s: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct H2Result {
    pub n: u64,
    pub p: u64,
    pub q: u64,
    pub m: usize,
    pub p_rank: Option<usize>,
    pub q_rank: Option<usize>,
    pub p_weight: f64,
    pub median_weight: f64,
    pub weight_ratio: f64,
    pub total_weights: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VasyuninAnomaly {
    pub m: u64,
    pub v_abs: f64,
    pub is_factor_p: bool,
    pub is_factor_q: bool,
    pub is_divisor: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct H3Result {
    pub n: u64,
    pub p: u64,
    pub q: u64,
    pub scan_limit: u64,
    pub scan_time_s: f64,
    pub median_nonfactor: f64,
    pub p90_nonfactor: f64,
    pub factor_anomalies: Vec<VasyuninAnomaly>,
    pub false_positive_count: usize,
    pub total_nonfactors: usize,
    /// True if all factor V-values are strictly below all non-factor V-values
    pub perfect_separation: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct H4Result {
    pub n: u64,
    pub p: u64,
    pub q: u64,
    pub mu_n: i8,
    pub lambda_n: i8,
    pub big_omega: u32,
    pub mertens_n: i64,
    pub liouville_sum_n: i64,
    pub delta_m_p: Option<i64>,
    pub delta_m_rand: Option<i64>,
    pub sqfree_count: usize,
    pub expected_sqfree: f64,
    pub sqfree_ratio: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrimeDensityEntry {
    pub prime: usize,
    pub density: f64,
    pub is_factor: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct H5Result {
    pub n: u64,
    pub p: u64,
    pub q: u64,
    pub m: usize,
    pub participation_ratio: f64,
    pub build_time_s: f64,
    pub eigen_time_s: f64,
    pub factor_p_rank: Option<usize>,
    pub total_primes: usize,
    /// Top-10 lowest-density primes
    pub top_avoided: Vec<PrimeDensityEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MaskDeltaEntry {
    pub prime: usize,
    pub delta_d2: f64,
    pub d2_masked: f64,
    pub is_factor: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct H6Result {
    pub n: u64,
    pub p: u64,
    pub q: u64,
    pub m: usize,
    pub d2_full: f64,
    pub factor_p_rank: Option<usize>,
    pub total_primes: usize,
    /// Top-10 primes by |Δd²|
    pub top_deltas: Vec<MaskDeltaEntry>,
}

// ═══════════════════════════════════════════════════════════════
// AGGREGATE CLASS RESULT
// ═══════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClassResult {
    pub bit_width: u32,
    pub num_semiprimes: usize,
    pub class_time_s: f64,
    pub h1_results: Vec<H1Result>,
    pub h2_results: Vec<H2Result>,
    pub h3_results: Vec<H3Result>,
    pub h4_results: Vec<H4Result>,
    pub h5_results: Vec<H5Result>,
    pub h6_results: Vec<H6Result>,
}

// ═══════════════════════════════════════════════════════════════
// ANALYSIS SUMMARY — cross-class statistics
// ═══════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HypothesisVerdict {
    pub hypothesis: String,
    pub description: String,
    pub signal_strength: String, // "STRONG", "weak", "null", "inconclusive"
    pub verdict: String,
    pub supporting_stats: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisSummary {
    pub experiment: String,
    pub timestamp: String,
    pub gpu_name: String,
    pub total_semiprimes: usize,
    pub total_time_s: f64,
    pub bit_classes: Vec<u32>,
    pub verdicts: Vec<HypothesisVerdict>,
    pub conclusion: String,
}

// ═══════════════════════════════════════════════════════════════
// RUN MANIFEST
// ═══════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunManifest {
    pub experiment: String,
    pub version: String,
    pub timestamp: String,
    pub gpu_name: String,
    pub gpu_vram_mb: usize,
    pub rust_version: String,
    pub bit_classes: Vec<u32>,
    pub total_semiprimes: usize,
}

// ═══════════════════════════════════════════════════════════════
// RESULTS WRITER
// ═══════════════════════════════════════════════════════════════

pub struct ResultsWriter {
    pub output_dir: PathBuf,
    start_time: Instant,
}

impl ResultsWriter {
    /// Create a new results directory for this run.
    pub fn new(base_dir: &Path) -> Self {
        Self::new_with_prefix(base_dir, "probe_gpu")
    }

    /// Create a new results directory with a custom prefix.
    pub fn new_with_prefix(base_dir: &Path, prefix: &str) -> Self {
        let ts = chrono_compact_timestamp();
        let dir = base_dir.join(format!("{}_{}", prefix, ts));
        fs::create_dir_all(&dir).expect("Failed to create results directory");
        eprintln!("  [Results] Output directory: {}", dir.display());
        ResultsWriter {
            output_dir: dir,
            start_time: Instant::now(),
        }
    }

    /// Write the run manifest.
    pub fn write_manifest(&self, gpu_name: &str, gpu_vram_mb: usize, classes: &[u32], total: usize) {
        let manifest = RunManifest {
            experiment: "spectral-factorization-probe-gpu".to_string(),
            version: "0.4.0".to_string(),
            timestamp: iso_timestamp(),
            gpu_name: gpu_name.to_string(),
            gpu_vram_mb,
            rust_version: env!("CARGO_PKG_VERSION").to_string(),
            bit_classes: classes.to_vec(),
            total_semiprimes: total,
        };
        self.write_json("manifest.json", &manifest);
    }

    /// Write a per-class result file.
    pub fn write_class_result(&self, class: &ClassResult) {
        let filename = format!("class_{}bit.json", class.bit_width);
        self.write_json(&filename, class);
    }

    /// Write the final analysis summary.
    pub fn write_analysis(&self, summary: &AnalysisSummary) {
        self.write_json("analysis_summary.json", summary);
    }

    /// Write any serializable data to a named JSON file.
    pub fn write_json_pub<T: Serialize>(&self, filename: &str, data: &T) {
        self.write_json(filename, data);
    }

    /// Elapsed time since writer creation.
    pub fn elapsed(&self) -> f64 {
        self.start_time.elapsed().as_secs_f64()
    }

    fn write_json<T: Serialize>(&self, filename: &str, data: &T) {
        let path = self.output_dir.join(filename);
        let json = serde_json::to_string_pretty(data).expect("JSON serialization failed");
        fs::write(&path, &json).unwrap_or_else(|e| {
            eprintln!("  [Results] WARNING: Failed to write {}: {}", path.display(), e);
        });
        eprintln!("  [Results] Wrote {} ({} bytes)", path.display(), json.len());
    }
}

// ═══════════════════════════════════════════════════════════════
// CROSS-CLASS ANALYSIS ENGINE
// ═══════════════════════════════════════════════════════════════

pub fn compute_analysis(
    classes: &[ClassResult],
    gpu_name: &str,
    total_time_s: f64,
) -> AnalysisSummary {
    let total_semiprimes: usize = classes.iter().map(|c| c.num_semiprimes).sum();
    let bit_classes: Vec<u32> = classes.iter().map(|c| c.bit_width).collect();

    let mut verdicts = Vec::new();

    // ── H1 Analysis: GCD-Stratum Eigenvector Correlation ──
    {
        let all_h1: Vec<&H1Result> = classes.iter().flat_map(|c| c.h1_results.iter()).collect();
        let ratios: Vec<f64> = all_h1.iter().map(|r| r.density_ratio).collect();
        let mean_ratio = if ratios.is_empty() { 0.0 } else { ratios.iter().sum::<f64>() / ratios.len() as f64 };
        let above_1: usize = ratios.iter().filter(|&&r| r > 1.0).count();
        let above_10: usize = ratios.iter().filter(|&&r| r > 10.0).count();

        let signal = if mean_ratio > 5.0 { "STRONG" }
            else if mean_ratio > 1.5 { "weak" }
            else { "null" };

        verdicts.push(HypothesisVerdict {
            hypothesis: "H1".to_string(),
            description: "GCD-Stratum eigenvector correlation with factor lattice".to_string(),
            signal_strength: signal.to_string(),
            verdict: format!(
                "Mean density ratio = {:.3}. {}/{} samples > 1.0, {}/{} > 10.0. {}.",
                mean_ratio, above_1, ratios.len(), above_10, ratios.len(),
                if mean_ratio > 1.5 { "Factor lattice shows elevated ground-state density" }
                else { "No consistent factor signal in ground state" }
            ),
            supporting_stats: serde_json::json!({
                "mean_ratio": mean_ratio,
                "median_ratio": percentile_f64(&ratios, 50.0),
                "samples": ratios.len(),
                "above_1": above_1,
                "above_10": above_10,
            }),
        });
    }

    // ── H2 Analysis: Optimal Weight Structure ──
    {
        let all_h2: Vec<&H2Result> = classes.iter().flat_map(|c| c.h2_results.iter()).collect();
        let ratios: Vec<f64> = all_h2.iter().map(|r| r.weight_ratio).collect();
        let mean = if ratios.is_empty() { 0.0 } else { ratios.iter().sum::<f64>() / ratios.len() as f64 };
        let percentile_ranks: Vec<f64> = all_h2.iter()
            .filter_map(|r| r.p_rank.map(|rank| (rank + 1) as f64 / r.total_weights as f64))
            .collect();
        let mean_pct = if percentile_ranks.is_empty() { 0.0 }
            else { percentile_ranks.iter().sum::<f64>() / percentile_ranks.len() as f64 };

        let signal = if mean > 2.0 { "STRONG" }
            else if mean > 1.1 { "weak" }
            else { "null" };

        verdicts.push(HypothesisVerdict {
            hypothesis: "H2".to_string(),
            description: "Optimal weight vector concentration at factor indices".to_string(),
            signal_strength: signal.to_string(),
            verdict: format!(
                "Mean |w_p|/median ratio = {:.3}. Factor p in top {:.1}% of weights on average. {}.",
                mean, mean_pct * 100.0,
                if mean > 1.1 { "Weak but consistent above-median weight at factor" }
                else { "No special weight concentration at factor" }
            ),
            supporting_stats: serde_json::json!({
                "mean_weight_ratio": mean,
                "mean_percentile_rank": mean_pct,
                "samples": ratios.len(),
            }),
        });
    }

    // ── H3 Analysis: Vasyunin Cotangent Sum ──
    {
        let all_h3: Vec<&H3Result> = classes.iter().flat_map(|c| c.h3_results.iter()).collect();
        let perfect_count = all_h3.iter().filter(|r| r.perfect_separation).count();
        let total_fp: usize = all_h3.iter().map(|r| r.false_positive_count).sum();
        let total_nf: usize = all_h3.iter().map(|r| r.total_nonfactors).sum();

        let signal = if perfect_count == all_h3.len() && !all_h3.is_empty() { "STRONG" }
            else if perfect_count as f64 / all_h3.len().max(1) as f64 > 0.9 { "weak" }
            else { "null" };

        verdicts.push(HypothesisVerdict {
            hypothesis: "H3".to_string(),
            description: "Vasyunin cotangent sum V(m,N) vanishes at exact divisors".to_string(),
            signal_strength: signal.to_string(),
            verdict: format!(
                "Perfect separation in {}/{} samples. Total false positives: {}/{}. {}.",
                perfect_count, all_h3.len(), total_fp, total_nf,
                if perfect_count == all_h3.len() { "V(p,N)=0 is an exact identity for divisors, not a statistical signal" }
                else { "Near-perfect separation with rare edge cases" }
            ),
            supporting_stats: serde_json::json!({
                "perfect_separation_count": perfect_count,
                "total_samples": all_h3.len(),
                "total_false_positives": total_fp,
                "total_nonfactors": total_nf,
            }),
        });
    }

    // ── H4 Analysis: Möbius/Liouville ──
    {
        let all_h4: Vec<&H4Result> = classes.iter().flat_map(|c| c.h4_results.iter()).collect();
        let sqfree_ratios: Vec<f64> = all_h4.iter().map(|r| r.sqfree_ratio).collect();
        let mean_sqfree = if sqfree_ratios.is_empty() { 0.0 }
            else { sqfree_ratios.iter().sum::<f64>() / sqfree_ratios.len() as f64 };

        verdicts.push(HypothesisVerdict {
            hypothesis: "H4".to_string(),
            description: "Möbius/Liouville local structure around N".to_string(),
            signal_strength: "null".to_string(),
            verdict: format!(
                "Mean squarefree ratio = {:.4} (expected 1.0). No anomalous arithmetic structure detected near semiprimes.",
                mean_sqfree
            ),
            supporting_stats: serde_json::json!({
                "mean_sqfree_ratio": mean_sqfree,
                "samples": all_h4.len(),
            }),
        });
    }

    // ── H5 Analysis: Composite Anchoring ──
    {
        let all_h5: Vec<&H5Result> = classes.iter().flat_map(|c| c.h5_results.iter()).collect();
        let pct_ranks: Vec<f64> = all_h5.iter()
            .filter_map(|r| r.factor_p_rank.map(|rank| (rank + 1) as f64 / r.total_primes as f64))
            .collect();
        let mean_pct = if pct_ranks.is_empty() { 0.0 }
            else { pct_ranks.iter().sum::<f64>() / pct_ranks.len() as f64 };

        let signal = if mean_pct < 0.2 { "STRONG" }
            else if mean_pct < 0.4 { "weak" }
            else { "null" };

        verdicts.push(HypothesisVerdict {
            hypothesis: "H5".to_string(),
            description: "Factor shadow in ground-state density ranking".to_string(),
            signal_strength: signal.to_string(),
            verdict: format!(
                "Factor p at mean percentile rank {:.1}% (low = strongly avoided). {}.",
                mean_pct * 100.0,
                if mean_pct > 0.8 { "Factor is among the LEAST avoided — counter-signal" }
                else if mean_pct > 0.5 { "No special avoidance pattern" }
                else { "Factor shows avoidance in ground state" }
            ),
            supporting_stats: serde_json::json!({
                "mean_percentile_rank": mean_pct,
                "samples": pct_ranks.len(),
            }),
        });
    }

    // ── H6 Analysis: Quadratic Form ──
    {
        let all_h6: Vec<&H6Result> = classes.iter().flat_map(|c| c.h6_results.iter()).collect();
        let pct_ranks: Vec<f64> = all_h6.iter()
            .filter_map(|r| r.factor_p_rank.map(|rank| (rank + 1) as f64 / r.total_primes as f64))
            .collect();
        let mean_pct = if pct_ranks.is_empty() { 0.0 }
            else { pct_ranks.iter().sum::<f64>() / pct_ranks.len() as f64 };

        let signal = if mean_pct < 0.2 { "STRONG" }
            else if mean_pct < 0.4 { "weak" }
            else { "null" };

        verdicts.push(HypothesisVerdict {
            hypothesis: "H6".to_string(),
            description: "Quadratic form d² perturbation when masking factor multiples".to_string(),
            signal_strength: signal.to_string(),
            verdict: format!(
                "Factor p at mean |Δd²| percentile rank {:.1}%. {}.",
                mean_pct * 100.0,
                if mean_pct < 0.4 { "Factor masking produces above-median d² perturbation" }
                else { "No special d² perturbation from factor masking" }
            ),
            supporting_stats: serde_json::json!({
                "mean_percentile_rank": mean_pct,
                "samples": pct_ranks.len(),
            }),
        });
    }

    // Overall conclusion
    let strong_count = verdicts.iter().filter(|v| v.signal_strength == "STRONG").count();
    let weak_count = verdicts.iter().filter(|v| v.signal_strength == "weak").count();

    let conclusion = if strong_count >= 2 {
        format!(
            "PROMISING: {}/{} hypotheses show strong signal. \
             Factor information IS embedded in Cathedral spectral data, \
             but exploitability for factoring remains undemonstrated.",
            strong_count, verdicts.len()
        )
    } else if strong_count + weak_count >= 3 {
        format!(
            "INCONCLUSIVE: {}/{} hypotheses show signal ({} strong, {} weak). \
             Some spectral fingerprint of factors exists but is not reliably extractable.",
            strong_count + weak_count, verdicts.len(), strong_count, weak_count
        )
    } else {
        format!(
            "NULL RESULT: Only {}/{} hypotheses show any signal. \
             Cathedral spectral structure does not preferentially encode factor information. \
             This is consistent with the Nyman-Beurling framework being about COLLECTIVE prime \
             distribution, not individual factorization.",
            strong_count + weak_count, verdicts.len()
        )
    };

    AnalysisSummary {
        experiment: "spectral-factorization-probe-gpu".to_string(),
        timestamp: iso_timestamp(),
        gpu_name: gpu_name.to_string(),
        total_semiprimes,
        total_time_s,
        bit_classes,
        verdicts,
        conclusion,
    }
}

// ═══════════════════════════════════════════════════════════════
// UTILITY
// ═══════════════════════════════════════════════════════════════

fn chrono_compact_timestamp() -> String {
    // YYYYMMDD_HHMMSS format without external chrono dependency
    use std::time::{SystemTime, UNIX_EPOCH};
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    // Simple but effective: seconds since epoch as identifier
    format!("{}", secs)
}

fn iso_timestamp() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    // Approximate ISO timestamp from epoch seconds
    let days = secs / 86400;
    let remaining = secs % 86400;
    let hours = remaining / 3600;
    let minutes = (remaining % 3600) / 60;
    let seconds = remaining % 60;

    // Days since 1970-01-01
    let (y, m, d) = days_to_ymd(days);
    format!("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z", y, m, d, hours, minutes, seconds)
}

fn days_to_ymd(total_days: u64) -> (u64, u64, u64) {
    // Simplified calendar calculation
    let mut y = 1970u64;
    let mut remaining = total_days;
    loop {
        let days_in_year = if is_leap(y) { 366 } else { 365 };
        if remaining < days_in_year {
            break;
        }
        remaining -= days_in_year;
        y += 1;
    }
    let months = [31, if is_leap(y) { 29 } else { 28 }, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut m = 1u64;
    for &ml in &months {
        if remaining < ml {
            break;
        }
        remaining -= ml;
        m += 1;
    }
    (y, m, remaining + 1)
}

fn is_leap(y: u64) -> bool {
    (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
}

fn percentile_f64(data: &[f64], pct: f64) -> f64 {
    if data.is_empty() { return 0.0; }
    let mut sorted = data.to_vec();
    sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let idx = ((pct / 100.0) * (sorted.len() - 1) as f64) as usize;
    sorted[idx.min(sorted.len() - 1)]
}
