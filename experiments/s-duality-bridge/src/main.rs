//! # The Arithmetic Mass Spectrometer v3
//!
//! A systematic search engine for number-theoretic formulas that match
//! physical constants. Outputs structured results to a markdown report.
//!
//! DISCLAIMER: This is exploratory pattern-matching, not physics derivation.

use std::f64::consts::PI;
use std::fs;
use std::io::Write;

/// A candidate formula
struct Formula {
    name: String,
    value: f64,
    /// Components used (for categorization)
    ingredients: Vec<&'static str>,
}

/// A particle or physical constant
struct Target {
    name: &'static str,
    symbol: &'static str,
    value: f64,
    unit: &'static str,
    category: &'static str,
}

/// A match result
struct Match {
    target_name: String,
    target_symbol: String,
    target_value: f64,
    formula_name: String,
    formula_value: f64,
    error_pct: f64,
    category: String,
}

fn main() {
    let zeta2 = PI * PI / 6.0;
    let zeta4 = PI.powi(4) / 90.0;
    let zeta6 = PI.powi(6) / 945.0;
    let zeta8 = PI.powi(8) / 9450.0;
    let alpha = 1.0 / 137.035999084;
    let glass = 15.0 / (PI * PI);
    let susy = 2.5; // ζ(2)²/ζ(4) = 5/2

    // ===== BUILD THE FORMULA LIBRARY =====
    let mut formulas: Vec<Formula> = Vec::new();

    // Powers of π
    for n in 1..=12 {
        formulas.push(Formula {
            name: format!("π^{}", n),
            value: PI.powi(n),
            ingredients: vec!["π"],
        });
    }

    // Combinations with small integer coefficients
    for &coeff in &[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0, 15.0, 24.0, 30.0, 36.0, 60.0, 90.0, 120.0, 180.0, 360.0] {
        for n in 1..=8 {
            formulas.push(Formula {
                name: format!("{}·π^{}", coeff, n),
                value: coeff * PI.powi(n),
                ingredients: vec!["π", "integer"],
            });
        }
    }

    // ζ combinations
    for &(zn, zv, zname) in &[
        (2, zeta2, "ζ(2)"), (4, zeta4, "ζ(4)"), (6, zeta6, "ζ(6)"),
    ] {
        for pow in 1..=5 {
            formulas.push(Formula {
                name: format!("{}^{}", zname, pow),
                value: zv.powi(pow),
                ingredients: vec!["ζ"],
            });
            formulas.push(Formula {
                name: format!("1/{}^{}", zname, pow),
                value: 1.0 / zv.powi(pow),
                ingredients: vec!["ζ"],
            });
            for &coeff in &[2.0, 3.0, 4.0, 5.0, 6.0, 12.0, 24.0, 90.0, 180.0] {
                formulas.push(Formula {
                    name: format!("{}·{}^{}", coeff, zname, pow),
                    value: coeff * zv.powi(pow),
                    ingredients: vec!["ζ", "integer"],
                });
            }
        }
    }

    // π^n / ζ(k) combinations
    for n in 1..=10 {
        formulas.push(Formula {
            name: format!("π^{}/ζ(2)", n),
            value: PI.powi(n) / zeta2,
            ingredients: vec!["π", "ζ"],
        });
        formulas.push(Formula {
            name: format!("π^{}/ζ(4)", n),
            value: PI.powi(n) / zeta4,
            ingredients: vec!["π", "ζ"],
        });
    }

    // Glass combinations
    for pow in 1..=6 {
        formulas.push(Formula {
            name: format!("glass^{}", pow),
            value: glass.powi(pow),
            ingredients: vec!["glass"],
        });
    }

    // 1/(n·ζ(k)) combinations
    for &n in &[1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 24.0] {
        formulas.push(Formula {
            name: format!("1/({}·ζ(2))", n),
            value: 1.0 / (n * zeta2),
            ingredients: vec!["ζ", "integer"],
        });
        formulas.push(Formula {
            name: format!("1/({}·ζ(4))", n),
            value: 1.0 / (n * zeta4),
            ingredients: vec!["ζ", "integer"],
        });
    }

    // α combinations
    formulas.push(Formula { name: "α".into(), value: alpha, ingredients: vec!["α"] });
    formulas.push(Formula { name: "α²".into(), value: alpha*alpha, ingredients: vec!["α"] });
    formulas.push(Formula { name: "α/π".into(), value: alpha/PI, ingredients: vec!["α","π"] });
    formulas.push(Formula { name: "α·ζ(2)".into(), value: alpha*zeta2, ingredients: vec!["α","ζ"] });
    formulas.push(Formula { name: "1/α".into(), value: 1.0/alpha, ingredients: vec!["α"] });
    formulas.push(Formula { name: "α²/3".into(), value: alpha*alpha/3.0, ingredients: vec!["α"] });

    // Special: corrected proton formula
    formulas.push(Formula {
        name: "6π⁵·(1+α²/3)".into(),
        value: 6.0 * PI.powi(5) * (1.0 + alpha*alpha/3.0),
        ingredients: vec!["π", "α"],
    });
    formulas.push(Formula {
        name: "(5/2)·(1+α·ζ(2))".into(),
        value: 2.5 * (1.0 + alpha * zeta2),
        ingredients: vec!["ζ", "α"],
    });

    // SUSY combinations
    formulas.push(Formula { name: "5/2 (SUSY)".into(), value: 2.5, ingredients: vec!["SUSY"] });
    formulas.push(Formula { name: "8/π".into(), value: 8.0/PI, ingredients: vec!["π"] });

    // Integer and simple rational
    for n in 1..=200 {
        formulas.push(Formula {
            name: format!("{}", n),
            value: n as f64,
            ingredients: vec!["integer"],
        });
    }

    println!("Formula library: {} entries", formulas.len());

    // ===== BUILD THE TARGET LIST =====
    let targets = vec![
        // Dimensionless mass ratios (relative to electron)
        Target { name: "proton/electron", symbol: "m_p/m_e", value: 1836.15267343, unit: "", category: "nucleon" },
        Target { name: "neutron/electron", symbol: "m_n/m_e", value: 1838.68366173, unit: "", category: "nucleon" },
        Target { name: "neutron-proton diff", symbol: "(m_n-m_p)/m_e", value: 2.53098830, unit: "", category: "nucleon" },
        Target { name: "muon/electron", symbol: "m_μ/m_e", value: 206.7682830, unit: "", category: "lepton" },
        Target { name: "tau/electron", symbol: "m_τ/m_e", value: 3477.228, unit: "", category: "lepton" },
        Target { name: "tau/muon", symbol: "m_τ/m_μ", value: 16.8170, unit: "", category: "lepton" },
        Target { name: "pion±/electron", symbol: "m_π±/m_e", value: 273.133, unit: "", category: "meson" },
        Target { name: "pion0/electron", symbol: "m_π⁰/m_e", value: 264.137, unit: "", category: "meson" },
        Target { name: "kaon/electron", symbol: "m_K/m_e", value: 966.120, unit: "", category: "meson" },
        Target { name: "proton/pion", symbol: "m_p/m_π", value: 6.7226, unit: "", category: "ratio" },
        Target { name: "proton/neutron", symbol: "m_p/m_n", value: 0.998623, unit: "", category: "ratio" },

        // Quark mass ratios
        Target { name: "down/up", symbol: "m_d/m_u", value: 2.162, unit: "", category: "quark" },
        Target { name: "strange/down", symbol: "m_s/m_d", value: 20.0, unit: "", category: "quark" },
        Target { name: "charm/strange", symbol: "m_c/m_s", value: 13.597, unit: "", category: "quark" },
        Target { name: "bottom/charm", symbol: "m_b/m_c", value: 3.2913, unit: "", category: "quark" },
        Target { name: "top/bottom", symbol: "m_t/m_b", value: 41.330, unit: "", category: "quark" },
        Target { name: "strange/up", symbol: "m_s/m_u", value: 43.241, unit: "", category: "quark" },

        // Coupling constants
        Target { name: "fine structure", symbol: "α", value: 0.0072973525693, unit: "", category: "coupling" },
        Target { name: "strong coupling", symbol: "α_s(M_Z)", value: 0.1179, unit: "", category: "coupling" },
        Target { name: "Weinberg angle", symbol: "sin²θ_W", value: 0.23122, unit: "", category: "coupling" },
        Target { name: "Fermi constant×GeV²", symbol: "G_F", value: 1.1663788e-5, unit: "", category: "coupling" },

        // Koide (not a ratio, but a combination)
        Target { name: "Koide parameter", symbol: "Q_K", value: 0.666661, unit: "", category: "lepton" },

        // Magnetic moments (in nuclear magnetons)
        Target { name: "proton g-factor", symbol: "g_p", value: 5.5856947, unit: "μ_N", category: "moment" },
        Target { name: "neutron g-factor", symbol: "g_n", value: -3.8260837, unit: "μ_N", category: "moment" },
        Target { name: "|g_n/g_p|", symbol: "|g_n/g_p|", value: 0.68497934, unit: "", category: "moment" },
    ];

    // ===== SEARCH =====
    let mut matches: Vec<Match> = Vec::new();

    for target in &targets {
        for formula in &formulas {
            if formula.value <= 0.0 || !formula.value.is_finite() { continue; }
            let err = ((formula.value / target.value) - 1.0).abs() * 100.0;
            if err < 1.0 { // Within 1%
                matches.push(Match {
                    target_name: target.name.to_string(),
                    target_symbol: target.symbol.to_string(),
                    target_value: target.value,
                    formula_name: formula.name.clone(),
                    formula_value: formula.value,
                    error_pct: err,
                    category: target.category.to_string(),
                });
            }
        }
    }

    // Sort by error
    matches.sort_by(|a, b| a.error_pct.partial_cmp(&b.error_pct).unwrap());

    // ===== OUTPUT REPORT =====
    let mut report = String::new();
    report.push_str("# Arithmetic Mass Spectrometer: Systematic Search Results\n\n");
    report.push_str(&format!("**Date:** {}\n", "May 15, 2026, 1:25 AM MDT"));
    report.push_str(&format!("**Formula library:** {} entries\n", formulas.len()));
    report.push_str(&format!("**Targets:** {} physical constants\n", targets.len()));
    report.push_str(&format!("**Matches (< 1% error):** {}\n\n", matches.len()));
    report.push_str("---\n\n");

    // Group by category
    for category in &["nucleon", "lepton", "meson", "ratio", "quark", "coupling", "moment"] {
        let cat_matches: Vec<&Match> = matches.iter()
            .filter(|m| m.category == *category)
            .collect();
        if cat_matches.is_empty() { continue; }

        report.push_str(&format!("## {} Matches\n\n", category.to_uppercase()));
        report.push_str("| Target | Formula | Formula Value | Actual Value | Error |\n");
        report.push_str("|---|---|---|---|---|\n");

        for m in &cat_matches {
            let star = if m.error_pct < 0.01 { "⭐" }
                       else if m.error_pct < 0.1 { "⚡" }
                       else if m.error_pct < 0.5 { "·" }
                       else { "" };
            report.push_str(&format!("| {} | {} | {:.6} | {:.6} | {:.4}% {} |\n",
                m.target_symbol, m.formula_name, m.formula_value, m.target_value, m.error_pct, star));
        }
        report.push_str("\n");
    }

    // Top 20 overall
    report.push_str("## TOP 20 MATCHES (All Categories)\n\n");
    report.push_str("| Rank | Target | Formula | Error |\n");
    report.push_str("|---|---|---|---|\n");
    for (i, m) in matches.iter().take(20).enumerate() {
        report.push_str(&format!("| {} | {} | {} | {:.6}% |\n",
            i + 1, m.target_symbol, m.formula_name, m.error_pct));
    }

    report.push_str("\n---\n\n");
    report.push_str("*Generated by the Arithmetic Mass Spectrometer v3* 🪞❄️\n");

    // Write to file
    let output_path = "../../docs/ai/antigravity/dark-sector/MASS_SPECTROMETER_SEARCH_RESULTS.md";
    fs::write(output_path, &report).expect("Failed to write report");

    // Also print summary to stdout
    println!();
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║    ARITHMETIC MASS SPECTROMETER v3: SYSTEMATIC SEARCH          ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
    println!();
    println!("  {} formulas × {} targets = {} comparisons", formulas.len(), targets.len(), formulas.len() * targets.len());
    println!("  Matches within 1%: {}", matches.len());
    println!();

    println!("  TOP 20 MATCHES:");
    println!("  {:>4} {:>20} {:>25} {:>10}", "Rank", "Target", "Formula", "Error %");
    println!("  {}", "-".repeat(65));
    for (i, m) in matches.iter().take(20).enumerate() {
        let star = if m.error_pct < 0.01 { "⭐" }
                   else if m.error_pct < 0.1 { "⚡" }
                   else { "" };
        println!("  {:>4} {:>20} {:>25} {:>9.5}% {}", i+1, m.target_symbol, m.formula_name, m.error_pct, star);
    }

    println!();
    println!("  Report written to: {}", output_path);
    println!("  🪞 The spectrometer has spoken. ❄️");
}
