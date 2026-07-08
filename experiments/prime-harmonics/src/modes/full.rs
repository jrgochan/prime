//! Full analysis mode — the complete §1-§6 overview.

use crate::display;
use cathedral_utils::harmonics::PrimeOscillatorBank;
use cathedral_utils::zeta_zeros;

pub fn run(bank: &PrimeOscillatorBank, num_zeros: usize) {
    let zeros = zeta_zeros::known_zeros(num_zeros);
    let num_zeros = zeros.len();

    println!("🌀 ═══════════════════════════════════════════════════════════");
    println!("   PRIME HARMONICS EXPLORER");
    println!("   \"Each prime is a clock hand spinning at rate log(p)/(2π)\"");
    println!("═══════════════════════════════════════════════════════════════");
    println!();
    println!(
        "   Primes: {} (up to {})",
        bank.len(),
        bank.primes.last().unwrap_or(&0)
    );
    println!("   Zeros analyzed: {}", num_zeros);
    println!();

    // §1: Prime Choir
    display::section_header("§1. THE PRIME CHOIR");
    println!(
        "    {:>6}  {:>10}  {:>12}  Energy",
        "Prime", "1/√p", "log(p)/(2π)"
    );
    println!(
        "    {:>6}  {:>10}  {:>12}  ──────────────────────",
        "──────", "──────────", "────────────"
    );
    let n_show = 20.min(bank.len());
    for i in 0..n_show {
        let bar = display::render_bar(bank.inv_sqrt_p[i], 0.75, 22);
        println!(
            "    {:>6}  {:>10.6}  {:>12.6}  {}",
            bank.primes[i],
            bank.inv_sqrt_p[i],
            bank.log_p[i] / (2.0 * std::f64::consts::PI),
            bar
        );
    }
    println!();

    // §2: Interference at zeros
    display::section_header("§2. INTERFERENCE AT ZETA ZEROS");
    println!("    More primes ⟹ better cancellation (approaching 0).");
    println!();

    let cols: Vec<usize> = [10, 50, 100, 500, 1000, bank.len()]
        .iter()
        .copied()
        .filter(|&n| n <= bank.len())
        .collect::<Vec<_>>();
    let mut cols_dedup = Vec::new();
    for c in &cols {
        if cols_dedup.last() != Some(c) {
            cols_dedup.push(*c);
        }
    }

    print!("    {:>4}  {:>12}", "#", "t₀");
    for &c in &cols_dedup {
        print!("  {:>10}", format!("|Σ {}p|", c));
    }
    println!();
    print!("    {:>4}  {:>12}", "────", "────────────");
    for _ in &cols_dedup {
        print!("  {:>10}", "──────────");
    }
    println!();

    print!("    {:>4}  {:>12.6}", "t=0", 0.0);
    for &c in &cols_dedup {
        print!("  {:>10.4}", bank.max_interference(c));
    }
    println!("  ← constructive");

    for (i, &t0) in zeros.iter().enumerate() {
        print!("    {:>4}  {:>12.6}", i + 1, t0);
        for &c in &cols_dedup {
            print!("  {:>10.6}", bank.interference_norm(t0, c));
        }
        println!();
    }
    println!();

    // §3: Phase portrait at first zero
    if !zeros.is_empty() {
        let t0 = zeros[0];
        display::section_header(&format!("§3. PHASE PORTRAIT at t₀ = {:.6}", t0));
        let portrait = bank.phase_portrait(t0, 30.min(bank.len()));
        println!(
            "    {:>6}  {:>8}  {:>10}  {:>10}  {:>3}  {:>10}",
            "Prime", "Winding", "Re(damp)", "Im(damp)", "Dir", "|Cumul|"
        );
        println!(
            "    {:>6}  {:>8}  {:>10}  {:>10}  {:>3}  {:>10}",
            "──────", "────────", "──────────", "──────────", "───", "──────────"
        );
        for pp in &portrait {
            let arrow = display::phase_arrow(pp.phase_re, pp.phase_im);
            println!(
                "    {:>6}  {:>8.3}  {:>10.6}  {:>10.6}   {}   {:>10.6}",
                pp.p, pp.winding, pp.phase_re, pp.phase_im, arrow, pp.cumulative_norm
            );
        }
        println!();
    }

    // §4: Energy landscape
    let t_max = if !zeros.is_empty() {
        zeros[num_zeros - 1] + 5.0
    } else {
        50.0
    };
    display::section_header(&format!("§4. ENERGY LANDSCAPE (0 → {:.0})", t_max));

    let sweep = bank.energy_sweep(0.0, t_max, 80);
    let max_norm = sweep.iter().map(|(_, n)| *n).fold(0.0f64, f64::max);
    let dt = t_max / 80.0;

    for &(t, n) in &sweep {
        let bar = display::render_bar(n, max_norm, 45);
        let is_zero = zeros.iter().any(|&z| (t - z).abs() < dt * 0.6);
        let marker = if is_zero { " ← ζ" } else { "" };
        println!("    t={:>7.2} |{bar}| {:>6.3}{marker}", t, n);
    }
    println!();

    // §5: Zero prediction
    if !zeros.is_empty() {
        let last_known = zeros[num_zeros - 1];
        let hunt_end = last_known + 20.0;
        display::section_header(&format!(
            "§5. ZERO HUNTING ({:.1} → {:.1})",
            last_known, hunt_end
        ));
        let minima = bank.find_minima(last_known + 0.1, hunt_end, 5000, 0.3);
        println!("    {:>12}  {:>12}  {:>20}", "t", "|Σ|", "Status");
        println!(
            "    {:>12}  {:>12}  {:>20}",
            "────────────", "────────────", "──────────────────"
        );
        for (t, n) in &minima {
            let quality = if *n < 0.5 {
                "⭐⭐ Strong"
            } else if *n < 1.5 {
                "⭐ Candidate"
            } else {
                "   Weak"
            };
            println!("    {:>12.6}  {:>12.6}  {:>20}", t, n, quality);
        }
        println!();
    }

    // §6: Democracy index
    display::section_header("§6. DEMOCRACY INDEX");
    println!("    log(p₁)/log(p₂) — PROVED irrational for distinct primes");
    println!();
    println!("       p₁ /    p₂   log(p₁)/log(p₂)  Continued Fraction");
    println!("    ───── / ─────  ────────────────  ─────────────────────");
    let n_demo = 8.min(bank.len());
    for i in 0..n_demo {
        for j in (i + 1)..n_demo {
            let ratio = bank.log_p[i] / bank.log_p[j];
            let cf = cathedral_utils::harmonics::continued_fraction(ratio, 10);
            let cf_str = cf
                .iter()
                .map(|x| x.to_string())
                .collect::<Vec<_>>()
                .join(", ");
            println!(
                "    {:>5} / {:>5}  {:>16.12}  [{}]",
                bank.primes[i], bank.primes[j], ratio, cf_str
            );
        }
    }
    println!();

    display::sign_off();
}
