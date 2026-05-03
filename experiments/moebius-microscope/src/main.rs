//! ═══════════════════════════════════════════════════════════════
//!  MÖBIUS CANCELLATION MICROSCOPE v2.0
//!  10 decompositions of vᵀGv — parallel row-streaming engine.
//!  Usage: moebius-microscope [N1] [N2] ...
//! ═══════════════════════════════════════════════════════════════

mod decomp;
mod output;

fn main() {
    eprintln!("╔═══════════════════════════════════════════════╗");
    eprintln!("║  MÖBIUS CANCELLATION MICROSCOPE v2.0          ║");
    eprintln!("║  10 decompositions · Parallel · Exploration 24 ║");
    eprintln!("╚═══════════════════════════════════════════════╝");

    let args: Vec<String> = std::env::args().collect();
    let ns: Vec<usize> = if args.len() > 1 {
        args[1..].iter().filter_map(|s| s.parse().ok()).collect()
    } else {
        vec![100, 500]
    };

    let dir = "results";
    std::fs::create_dir_all(dir).unwrap();

    for &n in &ns {
        if n < 10 { eprintln!("  ⚠ Skip N={n}"); continue; }
        let d = decomp::run_microscope(n);
        output::write_all(&d, dir).unwrap();
    }
    eprintln!("\n═══ ALL COMPLETE ═══");
}
