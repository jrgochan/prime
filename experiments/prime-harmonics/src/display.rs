//! Terminal display helpers for the Prime Harmonics Explorer.
//!
//! Phase arrows, bar charts, and formatting utilities.

use std::f64::consts::PI;

/// Map a complex number's phase to a Unicode direction arrow.
///
/// Divides the unit circle into 8 octants:
/// → ↗ ↑ ↖ ← ↙ ↓ ↘
pub fn phase_arrow(re: f64, im: f64) -> &'static str {
    let angle = im.atan2(re);
    let octant = ((angle + PI) / (PI / 4.0)) as usize % 8;
    ["←", "↙", "↓", "↘", "→", "↗", "↑", "↖"][octant]
}

/// Render a value as a Unicode block bar chart.
///
/// `value` is the current value, `max_value` is the full-scale value,
/// and `width` is the number of character cells.
pub fn render_bar(value: f64, max_value: f64, width: usize) -> String {
    if max_value <= 0.0 {
        return " ".repeat(width);
    }
    let filled = (value / max_value * width as f64).min(width as f64).max(0.0) as usize;
    let mut bar: String = "█".repeat(filled);
    let remaining = width.saturating_sub(filled);
    if remaining > 0 {
        let frac = (value / max_value * width as f64) - filled as f64;
        let blocks = [" ", "░", "▒", "▓"];
        bar.push_str(blocks[(frac * 3.0).min(3.0) as usize]);
        bar.push_str(&" ".repeat(remaining.saturating_sub(1)));
    }
    bar
}

/// Section header with box-drawing decoration.
pub fn section_header(title: &str) {
    println!("═══ {} ═══════════════════════════════════════════", title);
}

/// Print the Cathedral sign-off quote.
pub fn sign_off() {
    println!("🌀 ═══════════════════════════════════════════════════════════");
    println!("   \"At t = 0, all hands point east (constructive interference).");
    println!("    At a zeta zero, all hands cancel (destructive interference).");
    println!("    RH = the only damping that allows cancellation is σ = ½.\"");
    println!("               — Cathedral/Spectral/PrimeHarmonics.lean");
    println!("═══════════════════════════════════════════════════════════════");
}
