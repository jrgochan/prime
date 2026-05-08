//! Certificate generation utilities.
//!
//! Standardized JSON and TSV output for Lean-compatible certificates
//! and experimental data files.

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

/// Get the results directory for the current crate.
///
/// Resolves to `<crate-root>/results/` using `CARGO_MANIFEST_DIR`.
/// Creates the directory if it doesn't exist.
pub fn results_dir() -> PathBuf {
    let manifest = env!("CARGO_MANIFEST_DIR");
    let dir = PathBuf::from(manifest).join("results");
    fs::create_dir_all(&dir).ok();
    dir
}

/// Get the results directory for a named experiment crate.
///
/// Resolves to `experiments/<name>/results/` relative to the workspace root.
pub fn results_dir_for(name: &str) -> PathBuf {
    let manifest = env!("CARGO_MANIFEST_DIR"); // e.g. .../experiments/cathedral-utils
    let workspace = PathBuf::from(manifest)
        .parent().unwrap_or(Path::new("."))  // .../experiments/
        .to_path_buf();
    let dir = workspace.join(name).join("results");
    fs::create_dir_all(&dir).ok();
    dir
}

/// Write a TSV file with headers and rows.
pub fn write_tsv(path: &str, headers: &[&str], rows: &[Vec<String>]) {
    if let Some(parent) = Path::new(path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let mut f = fs::File::create(path).expect("Failed to create TSV file");
    writeln!(f, "{}", headers.join("\t")).unwrap();
    for row in rows {
        writeln!(f, "{}", row.join("\t")).unwrap();
    }
}

/// Write a JSON value to a file with pretty-printing.
pub fn write_json(path: &str, value: &serde_json::Value) {
    if let Some(parent) = Path::new(path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let json = serde_json::to_string_pretty(value).unwrap();
    fs::write(path, json).expect("Failed to write JSON file");
}

/// Print a standardized Cathedral header box.
pub fn cathedral_header(title: &str, subtitle: &str) {
    println!("  \x1b[1m\x1b[36m╔═══════════════════════════════════════════════════════════════════════╗\x1b[0m");
    println!("  \x1b[1m\x1b[36m║\x1b[0m  \x1b[1m\x1b[37m{title}\x1b[0m");
    if !subtitle.is_empty() {
        println!("  \x1b[1m\x1b[36m║\x1b[0m  {subtitle}");
    }
    println!("  \x1b[1m\x1b[36m╚═══════════════════════════════════════════════════════════════════════╝\x1b[0m");
}
