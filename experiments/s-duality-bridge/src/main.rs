//! # The Arithmetic Mass Spectrometer v4
//!
//! Upgrades:
//! 1. DIMENSIONAL LADDER: ζ(6), ζ(8), ζ(10) + cross-products
//! 2. AUTO-CORRECTION: for near-misses, search α-based corrections
//! 3. FULL PARTICLE ZOO: W, Z, Higgs, baryons, mesons, all quarks
//! 4. π^n/ζ(k) GRID: systematic scan of the spectral lift pattern
//!
//! DISCLAIMER: Exploratory pattern-matching, not physics derivation.

use std::f64::consts::PI;
use std::fmt::Write as FmtWrite;
use std::fs;

fn main() {
    // ===== CONSTANTS =====
    let alpha = 1.0 / 137.035999084;
    let zetas: Vec<(usize, f64)> = vec![
        (2, PI.powi(2) / 6.0),
        (4, PI.powi(4) / 90.0),
        (6, PI.powi(6) / 945.0),
        (8, PI.powi(8) / 9450.0),
        (10, PI.powi(10) / 93555.0),
        (12, PI.powi(12) / 638512875.0 * 691.0),
    ];
    let glass = 15.0 / (PI * PI);

    // ===== BUILD FORMULA LIBRARY =====
    let mut formulas: Vec<(String, f64)> = Vec::new();

    // 1. Powers of π with coefficients
    for n in 1..=12 {
        for &c in &[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0, 15.0,
                     24.0, 30.0, 36.0, 60.0, 90.0, 120.0, 180.0, 360.0] {
            let v = c * PI.powi(n);
            let name = if c == 1.0 { format!("π^{}", n) }
                       else { format!("{}·π^{}", c, n) };
            formulas.push((name, v));
        }
    }

    // 2. ζ(k) with powers and coefficients (DIMENSIONAL LADDER)
    for &(k, zk) in &zetas {
        for pow in 1..=5 {
            let v = zk.powi(pow);
            formulas.push((format!("ζ({})^{}", k, pow), v));
            formulas.push((format!("1/ζ({})^{}", k, pow), 1.0/v));
            for &c in &[2.0, 3.0, 4.0, 5.0, 6.0, 12.0, 24.0, 90.0, 180.0] {
                formulas.push((format!("{}·ζ({})^{}", c, k, pow), c * v));
            }
        }
    }

    // 3. CROSS-PRODUCTS: ζ(j)^a · ζ(k)^b
    for &(j, zj) in &zetas {
        for &(k, zk) in &zetas {
            if k <= j { continue; }
            formulas.push((format!("ζ({})·ζ({})", j, k), zj * zk));
            formulas.push((format!("ζ({})/ζ({})", j, k), zj / zk));
            formulas.push((format!("ζ({})/ζ({})", k, j), zk / zj));
            formulas.push((format!("ζ({})²/ζ({})", j, k), zj*zj / zk));
            formulas.push((format!("ζ({})²/ζ({})", k, j), zk*zk / zj));
        }
    }

    // 4. π^n/ζ(k) GRID (THE SPECTRAL LIFT)
    for n in 1..=12 {
        for &(k, zk) in &zetas {
            formulas.push((format!("π^{}/ζ({})", n, k), PI.powi(n) / zk));
            formulas.push((format!("ζ({})/π^{}", k, n), zk / PI.powi(n)));
            // With small coefficients
            for &c in &[2.0, 3.0, 4.0, 6.0] {
                formulas.push((format!("{}·π^{}/ζ({})", c, n, k), c * PI.powi(n) / zk));
            }
        }
    }

    // 5. Glass combinations
    for pow in 1..=8 {
        formulas.push((format!("glass^{}", pow), glass.powi(pow)));
        formulas.push((format!("π^{}·glass", pow), PI.powi(pow) * glass));
    }

    // 6. Special α-related
    formulas.push(("α".into(), alpha));
    formulas.push(("α²".into(), alpha * alpha));
    formulas.push(("1/α".into(), 1.0 / alpha));
    formulas.push(("α/π".into(), alpha / PI));
    formulas.push(("α²/3".into(), alpha * alpha / 3.0));

    // 7. Corrected formulas from our discoveries
    formulas.push(("6π⁵·(1+α²/3)".into(), 6.0*PI.powi(5) * (1.0 + alpha*alpha/3.0)));
    formulas.push(("(5/2)·(1+α·ζ(2))".into(), 2.5 * (1.0 + alpha*zetas[0].1)));

    // 8. Simple rationals and integers
    for n in 1..=300 { formulas.push((format!("{}", n), n as f64)); }
    for &(a,b) in &[(1,2),(1,3),(1,4),(2,3),(3,2),(3,4),(4,3),(5,2),(5,3),(7,2),(8,3),(22,7)] {
        formulas.push((format!("{}/{}", a, b), a as f64 / b as f64));
    }

    // 9. 1/(n·ζ(k)) for coupling constant matches
    for &(k, zk) in &zetas {
        for &n in &[1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 24.0] {
            formulas.push((format!("1/({}·ζ({}))", n, k), 1.0 / (n * zk)));
        }
    }

    // 10. π^a · ζ(b)^c combos
    for n in 1..=6 {
        for &(k, zk) in &zetas[..3] {
            for pow in 1..=3 {
                formulas.push((format!("π^{}·ζ({})^{}", n, k, pow), PI.powi(n) * zk.powi(pow)));
            }
        }
    }

    // Filter out non-finite and zero
    formulas.retain(|(_, v)| v.is_finite() && *v > 0.0 && *v < 1e12);

    println!("Formula library: {} entries", formulas.len());

    // ===== FULL PARTICLE ZOO =====
    let m_e = 0.51099895;
    let targets: Vec<(&str, &str, f64, &str)> = vec![
        // Leptons (mass ratios to electron)
        ("proton/electron", "m_p/m_e", 1836.15267343, "nucleon"),
        ("neutron/electron", "m_n/m_e", 1838.68366173, "nucleon"),
        ("n-p difference", "(m_n-m_p)/m_e", 2.53098830, "nucleon"),
        ("muon/electron", "m_μ/m_e", 206.7682830, "lepton"),
        ("tau/electron", "m_τ/m_e", 3477.228, "lepton"),
        ("tau/muon", "m_τ/m_μ", 16.8170, "lepton"),

        // Mesons (mass in MeV / m_e)
        ("pion±/electron", "m_π±/m_e", 139.57039 / m_e, "meson"),
        ("pion0/electron", "m_π⁰/m_e", 134.9768 / m_e, "meson"),
        ("kaon±/electron", "m_K±/m_e", 493.677 / m_e, "meson"),
        ("kaon0/electron", "m_K⁰/m_e", 497.611 / m_e, "meson"),
        ("eta/electron", "m_η/m_e", 547.862 / m_e, "meson"),
        ("rho/electron", "m_ρ/m_e", 775.26 / m_e, "meson"),
        ("omega/electron", "m_ω/m_e", 782.66 / m_e, "meson"),
        ("J/psi/electron", "m_J/ψ/m_e", 3096.9 / m_e, "meson"),

        // Gauge bosons
        ("W/electron", "m_W/m_e", 80379.0 / m_e, "boson"),
        ("Z/electron", "m_Z/m_e", 91187.6 / m_e, "boson"),
        ("Higgs/electron", "m_H/m_e", 125250.0 / m_e, "boson"),
        ("W/proton", "m_W/m_p", 80379.0 / 938.272, "ratio"),
        ("Z/proton", "m_Z/m_p", 91187.6 / 938.272, "ratio"),
        ("Higgs/proton", "m_H/m_p", 125250.0 / 938.272, "ratio"),

        // Quark mass ratios (MS-bar at 2 GeV)
        ("down/up", "m_d/m_u", 2.162, "quark"),
        ("strange/down", "m_s/m_d", 20.0, "quark"),
        ("charm/strange", "m_c/m_s", 13.597, "quark"),
        ("bottom/charm", "m_b/m_c", 3.2913, "quark"),
        ("top/bottom", "m_t/m_b", 41.330, "quark"),
        ("strange/up", "m_s/m_u", 43.241, "quark"),
        ("charm/up", "m_c/m_u", 587.96, "quark"),
        ("top/up", "m_t/m_u", 79981.5, "quark"),

        // Coupling constants
        ("fine structure", "α", 0.0072973525693, "coupling"),
        ("strong coupling", "α_s(M_Z)", 0.1179, "coupling"),
        ("Weinberg angle", "sin²θ_W", 0.23122, "coupling"),

        // Magnetic moments
        ("proton g-factor", "g_p", 5.5856947, "moment"),
        ("neutron g-factor", "|g_n|", 3.8260837, "moment"),
        ("|g_n/g_p|", "|g_n/g_p|", 0.68497934, "moment"),

        // Key mass ratios
        ("proton/pion", "m_p/m_π", 6.7226, "ratio"),
        ("proton/neutron", "m_p/m_n", 0.998623, "ratio"),
        ("Koide param", "Q_K", 0.666661, "lepton"),
    ];

    println!("Target list: {} physical constants", targets.len());

    // ===== SEARCH =====
    let mut all_matches: Vec<(String, String, f64, String, f64, f64, String)> = Vec::new();

    for &(tname, tsym, tval, tcat) in &targets {
        for (fname, fval) in &formulas {
            let err = ((fval / tval) - 1.0).abs() * 100.0;
            if err < 2.0 {
                all_matches.push((
                    tname.to_string(), tsym.to_string(), tval,
                    fname.clone(), *fval, err, tcat.to_string()
                ));
            }
        }
    }

    all_matches.sort_by(|a, b| a.5.partial_cmp(&b.5).unwrap());

    // ===== AUTO-CORRECTION SEARCH =====
    // For matches within 5%, try α-corrections
    let mut corrections: Vec<(String, String, f64, String, f64, f64)> = Vec::new();

    for &(tname, tsym, tval, _tcat) in &targets {
        for (fname, fval) in &formulas {
            let base_err = ((fval / tval) - 1.0).abs() * 100.0;
            if base_err > 0.001 && base_err < 5.0 {
                let delta = tval / fval - 1.0;
                // Try correction = 1 + α^a * ζ(k)^b * c
                let correction_candidates: Vec<(&str, f64)> = vec![
                    ("α²/3", alpha*alpha/3.0),
                    ("α·ζ(2)", alpha*zetas[0].1),
                    ("α·ζ(4)", alpha*zetas[1].1),
                    ("α²·π", alpha*alpha*PI),
                    ("α/π", alpha/PI),
                    ("α²·ζ(2)", alpha*alpha*zetas[0].1),
                    ("α", alpha),
                    ("2α", 2.0*alpha),
                    ("α·π", alpha*PI),
                    ("α²/π", alpha*alpha/PI),
                    ("α·glass", alpha*glass),
                ];
                for (cname, cval) in &correction_candidates {
                    let corrected = fval * (1.0 + cval);
                    let corr_err = ((corrected / tval) - 1.0).abs() * 100.0;
                    if corr_err < base_err * 0.1 && corr_err < 0.1 {
                        corrections.push((
                            tsym.to_string(),
                            format!("{}·(1+{})", fname, cname),
                            corrected, format!("{:.6}", tval),
                            corr_err, base_err,
                        ));
                    }
                }
            }
        }
    }
    corrections.sort_by(|a, b| a.4.partial_cmp(&b.4).unwrap());
    corrections.dedup_by(|a, b| a.0 == b.0 && (a.4 - b.4).abs() < 0.0001);

    // ===== π^n/ζ(k) GRID =====
    let mut grid_report = String::new();
    writeln!(grid_report, "## The Spectral Lift Grid: π^n / ζ(k)\n").unwrap();
    writeln!(grid_report, "| n \\ k | ζ(2) | ζ(4) | ζ(6) | ζ(8) | ζ(10) |").unwrap();
    writeln!(grid_report, "|---|---|---|---|---|---|").unwrap();
    for n in 1..=10 {
        let mut row = format!("| π^{} |", n);
        for &(k, zk) in &zetas[..5] {
            let val = PI.powi(n) / zk;
            // Check if this matches any target
            let mut best_match = String::new();
            let mut best_err = 100.0_f64;
            for &(_, tsym, tval, _) in &targets {
                let err = ((val / tval) - 1.0).abs() * 100.0;
                if err < best_err {
                    best_err = err;
                    best_match = tsym.to_string();
                }
            }
            let annotation = if best_err < 0.1 {
                format!(" **≈{}** ⭐", best_match)
            } else if best_err < 1.0 {
                format!(" ≈{}", best_match)
            } else {
                String::new()
            };
            write!(row, " {:.2}{} |", val, annotation).unwrap();
        }
        writeln!(grid_report, "{}", row).unwrap();
    }

    // ===== WRITE REPORT =====
    let mut report = String::new();
    writeln!(report, "# Arithmetic Mass Spectrometer v4: Complete Results\n").unwrap();
    writeln!(report, "**Date:** May 15, 2026, 1:45 AM MDT").unwrap();
    writeln!(report, "**Formula library:** {} entries", formulas.len()).unwrap();
    writeln!(report, "**Targets:** {} physical constants", targets.len()).unwrap();
    writeln!(report, "**Matches (< 2% error):** {}", all_matches.len()).unwrap();
    writeln!(report, "**Auto-corrections found:** {}\n", corrections.len()).unwrap();
    writeln!(report, "---\n").unwrap();

    // Top 30
    writeln!(report, "## TOP 30 MATCHES\n").unwrap();
    writeln!(report, "| Rank | Target | Formula | Value | Actual | Error |").unwrap();
    writeln!(report, "|---|---|---|---|---|---|").unwrap();
    for (i, m) in all_matches.iter().take(30).enumerate() {
        let star = if m.5 < 0.01 { "⭐" } else if m.5 < 0.1 { "⚡" } else if m.5 < 0.5 { "·" } else { "" };
        writeln!(report, "| {} | {} | {} | {:.4} | {:.4} | {:.5}% {} |",
            i+1, m.1, m.3, m.4, m.2, m.5, star).unwrap();
    }

    // Auto-corrections
    writeln!(report, "\n## AUTO-CORRECTED FORMULAS\n").unwrap();
    writeln!(report, "For near-misses, adding α-based corrections:\n").unwrap();
    writeln!(report, "| Target | Corrected Formula | Value | Actual | New Error | Was |").unwrap();
    writeln!(report, "|---|---|---|---|---|---|").unwrap();
    for c in corrections.iter().take(20) {
        writeln!(report, "| {} | {} | {:.6} | {} | {:.5}% | {:.3}% |",
            c.0, c.1, c.2, c.3, c.4, c.5).unwrap();
    }

    // Spectral grid
    writeln!(report, "\n{}", grid_report).unwrap();

    // By category
    for cat in &["nucleon", "lepton", "meson", "boson", "quark", "coupling", "moment", "ratio"] {
        let cat_matches: Vec<&(String,String,f64,String,f64,f64,String)> = all_matches.iter()
            .filter(|m| m.6 == *cat).collect();
        if cat_matches.is_empty() { continue; }
        writeln!(report, "\n## {} MATCHES\n", cat.to_uppercase()).unwrap();
        writeln!(report, "| Target | Formula | Value | Actual | Error |").unwrap();
        writeln!(report, "|---|---|---|---|---|").unwrap();
        for m in cat_matches.iter().take(15) {
            let star = if m.5 < 0.01 { "⭐" } else if m.5 < 0.1 { "⚡" } else { "" };
            writeln!(report, "| {} | {} | {:.6} | {:.6} | {:.5}% {} |",
                m.1, m.3, m.4, m.2, m.5, star).unwrap();
        }
    }

    writeln!(report, "\n---\n").unwrap();
    writeln!(report, "*Generated by the Arithmetic Mass Spectrometer v4* 🪞❄️").unwrap();

    let output_path = "../../docs/ai/antigravity/dark-sector/MASS_SPECTROMETER_v4_RESULTS.md";
    fs::write(output_path, &report).expect("Failed to write report");

    // ===== STDOUT SUMMARY =====
    println!("\n╔══════════════════════════════════════════════════════════════════╗");
    println!("║    ARITHMETIC MASS SPECTROMETER v4: FULL ZOO + CORRECTIONS     ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");
    println!("  {} formulas × {} targets = {} comparisons",
        formulas.len(), targets.len(), formulas.len() * targets.len());
    println!("  Matches within 2%: {}", all_matches.len());
    println!("  Auto-corrections: {}\n", corrections.len());

    println!("  TOP 20 MATCHES:");
    println!("  {:>4} {:>18} {:>30} {:>10}", "Rank", "Target", "Formula", "Error");
    println!("  {}", "-".repeat(68));
    for (i, m) in all_matches.iter().take(20).enumerate() {
        let star = if m.5 < 0.01 { "⭐" } else if m.5 < 0.1 { "⚡" } else { "" };
        println!("  {:>4} {:>18} {:>30} {:>9.5}% {}", i+1, &m.1, &m.3, m.5, star);
    }

    if !corrections.is_empty() {
        println!("\n  AUTO-CORRECTIONS (α-improved):");
        println!("  {:>18} {:>35} {:>9} {:>8}", "Target", "Corrected Formula", "New Err", "Was");
        println!("  {}", "-".repeat(75));
        for c in corrections.iter().take(10) {
            println!("  {:>18} {:>35} {:>8.5}% {:>7.3}%", c.0, c.1, c.4, c.5);
        }
    }

    println!("\n  Report: {}", output_path);
    println!("  🪞 The full zoo has been weighed. ❄️");
}
