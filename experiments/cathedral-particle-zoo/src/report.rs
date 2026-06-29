//! Report formatting utilities.

/// Print the particle zoo banner.
pub fn banner(n: usize) {
    println!("╔══════════════════════════════════════════════════════════════════════╗");
    println!("║   CATHEDRAL PARTICLE ZOO v2 — N = {} {:>28} ║", n, "(HC)");
    println!("║   Standard Model ↔ Arithmetic Mapping                              ║");
    println!("║   Gemini Upgrades: Axion + See-Saw + Coupling Constants             ║");
    println!("╚══════════════════════════════════════════════════════════════════════╝");
}

/// Print the spectral summary header.
pub fn spectral_header(lambda_min: f64, lambda_max: f64, d2: f64, vtgv: f64, mertens_prod: f64) {
    println!();
    println!("  ┌─────────────────────────────────────────────────────────────────┐");
    println!("  │ SPECTRAL SUMMARY                                               │");
    println!("  ├─────────────────────────────────────────────────────────────────┤");
    println!(
        "  │ Eigenvalue range: [{:.8}, {:.8}]                    │",
        lambda_min, lambda_max
    );
    println!(
        "  │ Spectral gap (mass gap):   {:.8}                            │",
        lambda_min
    );
    println!(
        "  │ d²_N (vacuum energy):      {:.8}                            │",
        d2
    );
    println!(
        "  │ vᵀGv (ground state E):     {:.8}                            │",
        vtgv
    );
    println!(
        "  │ Mertens screening Π(1-1/p): {:.8}                           │",
        mertens_prod
    );
    println!("  └─────────────────────────────────────────────────────────────────┘");
}
