//! # Arithmetic Mass Spectrometer — CLI
//!
//! Run the complete spectrometer pipeline:
//! 1. Build formula library (dimensional ladder, spectral lift, etc.)
//! 2. Load physical constants (PDG 2022)
//! 3. Exhaustive search with ranking
//! 4. Auto-correction for near-misses
//! 5. Generate reports (markdown + JSON)

use arithmetic_spectrometer::constants;
use arithmetic_spectrometer::engine;
use arithmetic_spectrometer::formulas;
use arithmetic_spectrometer::report;
use std::fs;

fn main() {
    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║    THE ARITHMETIC MASS SPECTROMETER                            ║");
    println!("║    Systematic number-theoretic search across particle physics   ║");
    println!("║    EXPLORATORY — NOT A CLAIM                                   ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    // 1. Build
    let formulas = formulas::build_formulas();
    let targets = constants::build_targets();
    println!("  Formula library:  {} entries", formulas.len());
    println!("  Physical targets: {} constants", targets.len());
    println!("  Total comparisons: {}\n", formulas.len() * targets.len());

    // 2. Search (< 2% error)
    let matches = engine::search(&formulas, &targets, 2.0);
    println!("  Matches (< 2%):   {}", matches.len());

    // 3. Auto-correct (search within 5%, require 10× improvement, max 0.1% corrected error)
    let corrections = engine::auto_correct(&formulas, &targets, 5.0, 10.0, 0.1);
    println!("  Auto-corrections: {}\n", corrections.len());

    // 4. Print top results
    println!("  ══ TOP 25 MATCHES ══\n");
    println!("  {:>4} {:>20} {:>30} {:>10} ", "Rank", "Target", "Formula", "Error");
    println!("  {}", "─".repeat(72));
    for (i, m) in matches.iter().take(25).enumerate() {
        println!("  {:>4} {:>20} {:>30} {:>9.5}% {}",
            i + 1, m.target_symbol, m.formula_name, m.error_pct, m.tier);
    }

    if !corrections.is_empty() {
        println!("\n  ══ AUTO-CORRECTIONS (α-improved) ══\n");
        println!("  {:>20} {:>35} {:>9} {:>8}", "Target", "Corrected Formula", "New Err", "Was");
        println!("  {}", "─".repeat(76));
        for c in corrections.iter().take(15) {
            println!("  {:>20} {:>35} {:>8.5}% {:>7.3}%",
                c.target_symbol, c.corrected_formula, c.new_error_pct, c.old_error_pct);
        }
    }

    // 5. Write reports
    let results_dir = "results";
    fs::create_dir_all(results_dir).ok();

    // Markdown
    let md = report::generate_markdown(&matches, &corrections, &targets, formulas.len());
    let md_path = format!("{}/spectrometer_results.md", results_dir);
    fs::write(&md_path, &md).expect("Failed to write markdown report");
    println!("\n  📄 Markdown report: {}", md_path);

    // JSON
    let json = report::generate_json(&matches, &corrections);
    let json_path = format!("{}/spectrometer_results.json", results_dir);
    fs::write(&json_path, &json).expect("Failed to write JSON data");
    println!("  📊 JSON data:      {}", json_path);

    // Also copy markdown to docs
    let docs_path = "../../docs/ai/antigravity/dark-sector/SPECTROMETER_COMPLETE_RESULTS.md";
    fs::write(docs_path, &md).expect("Failed to write docs report");
    println!("  📋 Docs copy:      {}", docs_path);

    println!("\n  🪞 The spectrometer has spoken. ❄️");
}
