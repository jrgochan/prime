//! Terminal formatting constants

pub const BOLD: &str = "\x1b[1m";
pub const DIM: &str = "\x1b[2m";
pub const CYAN: &str = "\x1b[36m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const MAGENTA: &str = "\x1b[35m";
pub const RED: &str = "\x1b[31m";
pub const WHITE: &str = "\x1b[97m";
pub const RESET: &str = "\x1b[0m";

pub fn check(b: bool) -> &'static str {
    if b { "\x1b[32m✓\x1b[0m" } else { "\x1b[31m✗\x1b[0m" }
}

pub fn header(title: &str, subtitle: &str, threads: usize) {
    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}{title}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}{subtitle}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}{threads} threads{RESET}");
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();
}
