// siegel-walfisz/src/fmt.rs
//
// Display formatting utilities

/// Format a float with specified decimal places, right-aligned
pub fn fmt_float(x: f64, decimals: usize, width: usize) -> String {
    format!("{:>width$.decimals$}", x, width = width, decimals = decimals)
}

/// Format a usize right-aligned
pub fn fmt_int(x: usize, width: usize) -> String {
    format!("{:>width$}", x, width = width)
}

/// Format a signed integer
pub fn fmt_signed(x: i64, width: usize) -> String {
    format!("{:>+width$}", x, width = width)
}

/// Check mark for pass/fail
pub fn check(ok: bool) -> &'static str {
    if ok { "✓" } else { "✗" }
}

/// Section header
pub fn section(title: &str) {
    println!();
    println!("  ═══ {} ═══", title);
    println!();
}
