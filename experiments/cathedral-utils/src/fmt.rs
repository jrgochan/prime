//! Terminal formatting constants — Cathedral standard.
//!
//! ANSI escape codes for consistent, beautiful terminal output
//! across all experiments.

// ═══════════════════════════════════════════════════════════════
// COLORS
// ═══════════════════════════════════════════════════════════════

pub const BOLD: &str = "\x1b[1m";
pub const DIM: &str = "\x1b[2m";
pub const RESET: &str = "\x1b[0m";

pub const RED: &str = "\x1b[31m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const BLUE: &str = "\x1b[34m";
pub const MAGENTA: &str = "\x1b[35m";
pub const CYAN: &str = "\x1b[36m";
pub const WHITE: &str = "\x1b[37m";

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════

/// Check/cross mark for boolean values.
#[inline]
pub fn check(ok: bool) -> &'static str {
    if ok {
        "\x1b[32m✓\x1b[0m"
    } else {
        "\x1b[31m✗\x1b[0m"
    }
}

/// Print a section header in Cathedral style.
pub fn section(title: &str) {
    println!("  {BOLD}{WHITE}═══ {title} ═══{RESET}");
}

/// Print a full experiment header with title, subtitle, precision, and thread count.
pub fn header(title: &str, subtitle: &str, precision: u32, threads: usize) {
    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}{title}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {subtitle}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Precision: {precision}-bit MPFR  ·  Threads: {threads}{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();
}
