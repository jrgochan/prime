//! # Search Engine
//!
//! The core matching and auto-correction engine.
//! - Exhaustive comparison of every formula against every target
//! - Auto-correction: for near-misses, search for α-based perturbative
//!   corrections that improve the match
//! - Scoring and ranking

use crate::constants::PhysicalTarget;
use crate::formulas::{Formula, ZetaConstants};
use serde::Serialize;
use std::f64::consts::PI;

/// A match between a formula and a physical target.
#[derive(Debug, Clone, Serialize)]
pub struct Match {
    pub target_name: String,
    pub target_symbol: String,
    pub target_value: f64,
    pub target_category: String,
    pub formula_name: String,
    pub formula_value: f64,
    pub formula_method: String,
    pub error_pct: f64,
    /// Quality tier: Star (<0.01%), Lightning (<0.1%), Dot (<0.5%), None
    pub tier: Tier,
}

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
pub enum Tier {
    Star,
    Lightning,
    Dot,
    None,
}

impl std::fmt::Display for Tier {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Tier::Star => write!(f, "⭐"),
            Tier::Lightning => write!(f, "⚡"),
            Tier::Dot => write!(f, "·"),
            Tier::None => write!(f, ""),
        }
    }
}

fn tier_for(err: f64) -> Tier {
    if err < 0.01 { Tier::Star }
    else if err < 0.1 { Tier::Lightning }
    else if err < 0.5 { Tier::Dot }
    else { Tier::None }
}

/// A correction that improves a near-miss.
#[derive(Debug, Clone, Serialize)]
pub struct Correction {
    pub target_symbol: String,
    pub base_formula: String,
    pub correction_term: String,
    pub corrected_formula: String,
    pub corrected_value: f64,
    pub target_value: f64,
    pub new_error_pct: f64,
    pub old_error_pct: f64,
    pub improvement_factor: f64,
}

/// Run the main search.
pub fn search(
    formulas: &[Formula],
    targets: &[PhysicalTarget],
    max_error_pct: f64,
) -> Vec<Match> {
    let mut matches = Vec::new();

    for target in targets {
        for formula in formulas {
            let err = ((formula.value / target.value) - 1.0).abs() * 100.0;
            if err < max_error_pct {
                matches.push(Match {
                    target_name: target.name.to_string(),
                    target_symbol: target.symbol.to_string(),
                    target_value: target.value,
                    target_category: format!("{}", target.category),
                    formula_name: formula.name.clone(),
                    formula_value: formula.value,
                    formula_method: format!("{:?}", formula.method),
                    error_pct: err,
                    tier: tier_for(err),
                });
            }
        }
    }

    matches.sort_by(|a, b| a.error_pct.partial_cmp(&b.error_pct).unwrap());
    matches
}

/// For near-misses, search for α-based corrections.
pub fn auto_correct(
    formulas: &[Formula],
    targets: &[PhysicalTarget],
    search_window_pct: f64,
    improvement_threshold: f64,
    max_corrected_error: f64,
) -> Vec<Correction> {
    let c = ZetaConstants::new();
    let alpha = c.alpha;
    let zeta2 = c.zetas[0].1;
    let zeta4 = c.zetas[1].1;
    let glass = c.glass;

    let correction_candidates: Vec<(&str, f64)> = vec![
        ("α²/3",       alpha * alpha / 3.0),
        ("α·ζ(2)",     alpha * zeta2),
        ("α·ζ(4)",     alpha * zeta4),
        ("α²·π",       alpha * alpha * PI),
        ("α/π",        alpha / PI),
        ("α²·ζ(2)",    alpha * alpha * zeta2),
        ("α",          alpha),
        ("2α",         2.0 * alpha),
        ("α·π",        alpha * PI),
        ("α²/π",       alpha * alpha / PI),
        ("α·glass",    alpha * glass),
        ("α·ζ(6)",     alpha * c.zetas[2].1),
        ("3α/π",       3.0 * alpha / PI),
        ("α²·ζ(4)",    alpha * alpha * zeta4),
    ];

    let mut corrections = Vec::new();

    for target in targets {
        for formula in formulas {
            let base_err = ((formula.value / target.value) - 1.0).abs() * 100.0;
            // Only look at near-misses that could be improved
            if base_err < 0.001 || base_err > search_window_pct { continue; }

            for &(cname, cval) in &correction_candidates {
                let corrected = formula.value * (1.0 + cval);
                let corr_err = ((corrected / target.value) - 1.0).abs() * 100.0;
                let improvement = base_err / corr_err.max(1e-12);

                if corr_err < max_corrected_error && improvement > improvement_threshold {
                    corrections.push(Correction {
                        target_symbol: target.symbol.to_string(),
                        base_formula: formula.name.clone(),
                        correction_term: cname.to_string(),
                        corrected_formula: format!("{}·(1+{})", formula.name, cname),
                        corrected_value: corrected,
                        target_value: target.value,
                        new_error_pct: corr_err,
                        old_error_pct: base_err,
                        improvement_factor: improvement,
                    });
                }
            }
        }
    }

    corrections.sort_by(|a, b| a.new_error_pct.partial_cmp(&b.new_error_pct).unwrap());
    // Deduplicate (keep best per target)
    let mut seen = std::collections::HashSet::new();
    corrections.retain(|c| {
        let key = format!("{}:{}", c.target_symbol, c.base_formula);
        seen.insert(key)
    });
    corrections
}
