//! ANSI formatting utilities — matching crown-cancellation quality

pub const BOLD: &str = "\x1b[1m";
pub const DIM: &str = "\x1b[2m";
pub const RESET: &str = "\x1b[0m";
pub const RED: &str = "\x1b[31m";
pub const GREEN: &str = "\x1b[32m";
pub const YELLOW: &str = "\x1b[33m";
pub const CYAN: &str = "\x1b[36m";
pub const MAGENTA: &str = "\x1b[35m";
pub const WHITE: &str = "\x1b[37m";

pub fn check(ok: bool) -> &'static str {
    if ok { "\x1b[32m✓\x1b[0m" } else { "\x1b[31m✗\x1b[0m" }
}

pub fn elapsed(s: f64) -> String {
    if s < 1.0 { format!("{:.0}ms", s * 1000.0) }
    else if s < 60.0 { format!("{s:.1}s") }
    else if s < 3600.0 { format!("{:.0}m{:.0}s", s / 60.0, s % 60.0) }
    else { format!("{:.1}h", s / 3600.0) }
}

pub fn header(title: &str, subtitle: &str, threads: usize) {
    println!();
    println!("  {BOLD}{CYAN}╔═══════════════════════════════════════════════════════════════════════╗{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {BOLD}{WHITE}{title}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}{subtitle}{RESET}");
    println!("  {BOLD}{CYAN}║{RESET}  {DIM}Threads: {threads} · f64 precision · {}{RESET}",
        chrono::Local::now().format("%Y-%m-%d %H:%M:%S"));
    println!("  {BOLD}{CYAN}╚═══════════════════════════════════════════════════════════════════════╝{RESET}");
    println!();
}
