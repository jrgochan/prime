// hilbert-spectral/src/fmt.rs
//
// Formatting utilities (matches siegel-walfisz quality bar)

pub fn section(title: &str) {
    println!();
    println!("  ═══════════════════════════════════════════════════════════════════════");
    println!("  {}", title);
    println!("  ───────────────────────────────────────────────────────────────────────");
}

pub fn check(ok: bool) -> &'static str {
    if ok { "✓" } else { "✗" }
}
