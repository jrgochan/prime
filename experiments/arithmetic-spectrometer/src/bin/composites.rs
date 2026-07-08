//! # Composite Particle Probe
//!
//! Tests whether the ζ-structure of quark masses propagates
//! consistently into hadron masses through QCD composition.
//!
//! Key question: Does swapping u↔d (which changes ζ-sector)
//! produce the correct hadron mass splittings?
//!
//! Physics context:
//! - Quark masses are ~1% of hadron masses
//! - ~99% of hadron mass = QCD binding energy (gluon field)
//! - So ζ-structure matters most for SPLITTINGS between hadrons
//! - Swapping u↔d should produce predictable Δm values

use std::f64::consts::PI;

fn main() {
    let zeta2 = PI * PI / 6.0;
    let zeta4 = PI.powi(4) / 90.0;
    let _zeta6 = PI.powi(6) / 945.0;
    let _alpha = 1.0 / 137.035999084;
    let _glass = 15.0 / (PI * PI);
    let m_e = 0.51099895; // MeV

    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  COMPOSITE PARTICLE PROBE                                      ║");
    println!("║  Does quark ζ-structure propagate into hadron masses?           ║");
    println!("╚══════════════════════════════════════════════════════════════════╝");
    println!();

    // ===== QUARK MASSES (MS-bar at 2 GeV, PDG 2022) =====
    // Note: these have large uncertainties (~10-30%)
    let m_u = 2.16; // MeV
    let m_d = 4.67; // MeV
    let m_s = 93.4; // MeV
    let m_c = 1270.0; // MeV
    let m_b = 4180.0; // MeV
    let m_t = 172_760.0; // MeV

    println!("  ═══ QUARK ζ-ASSIGNMENTS ═══\n");
    println!("  Quark  Mass(MeV)  Known Ratio      ζ-Formula         Error");
    println!("  ─────────────────────────────────────────────────────────────");
    println!(
        "  u      {:.2}       (reference)       -                 -",
        m_u
    );
    println!(
        "  d      {:.2}       m_d/m_u = {:.3}   2·ζ(4) = {:.3}   {:.2}%",
        m_d,
        m_d / m_u,
        2.0 * zeta4,
        ((2.0 * zeta4) / (m_d / m_u) - 1.0).abs() * 100.0
    );
    println!(
        "  s      {:.1}      m_s/m_d = {:.1}    20 (integer)     {:.2}%",
        m_s,
        m_s / m_d,
        ((20.0) / (m_s / m_d) - 1.0).abs() * 100.0
    );
    println!(
        "  c      {:.0}     m_c/m_s = {:.2}  ?                 searching...",
        m_c,
        m_c / m_s
    );
    println!(
        "  b      {:.0}     m_b/m_c = {:.3}   2·ζ(2) = {:.3}   {:.2}%",
        m_b,
        m_b / m_c,
        2.0 * zeta2,
        ((2.0 * zeta2) / (m_b / m_c) - 1.0).abs() * 100.0
    );
    println!(
        "  t      {:.0}  m_t/m_b = {:.2}  ?                 searching...",
        m_t,
        m_t / m_b
    );

    println!();
    println!("  Pattern: d/u ≈ 2·ζ(4) [dark sector]");
    println!("           b/c ≈ 2·ζ(2) [positive sector]");
    println!("  The light quarks use ζ(4), heavy quarks use ζ(2)!");
    println!();

    // ===== HADRON COMPOSITION =====
    println!("  ═══ HADRON COMPOSITION TEST ═══\n");
    println!("  If quarks carry ζ-assignments, do hadron SPLITTINGS obey ζ-rules?\n");

    // Key insight: most of the hadron mass is QCD binding energy,
    // but the DIFFERENCES between hadrons in the same multiplet
    // come from quark mass differences + EM effects.

    #[allow(dead_code)]
    struct Hadron {
        name: &'static str,
        symbol: &'static str,
        quarks: &'static str,
        mass_mev: f64,
        charge: i32,
    }

    let hadrons = vec![
        // Nucleons (spin-1/2 baryons)
        Hadron {
            name: "proton",
            symbol: "p",
            quarks: "uud",
            mass_mev: 938.272,
            charge: 1,
        },
        Hadron {
            name: "neutron",
            symbol: "n",
            quarks: "udd",
            mass_mev: 939.565,
            charge: 0,
        },
        // Sigma baryons
        Hadron {
            name: "Sigma+",
            symbol: "Σ⁺",
            quarks: "uus",
            mass_mev: 1189.37,
            charge: 1,
        },
        Hadron {
            name: "Sigma0",
            symbol: "Σ⁰",
            quarks: "uds",
            mass_mev: 1192.642,
            charge: 0,
        },
        Hadron {
            name: "Sigma-",
            symbol: "Σ⁻",
            quarks: "dds",
            mass_mev: 1197.449,
            charge: -1,
        },
        // Xi baryons
        Hadron {
            name: "Xi0",
            symbol: "Ξ⁰",
            quarks: "uss",
            mass_mev: 1314.86,
            charge: 0,
        },
        Hadron {
            name: "Xi-",
            symbol: "Ξ⁻",
            quarks: "dss",
            mass_mev: 1321.71,
            charge: -1,
        },
        // Delta baryons (spin-3/2)
        Hadron {
            name: "Delta++",
            symbol: "Δ⁺⁺",
            quarks: "uuu",
            mass_mev: 1232.0,
            charge: 2,
        },
        Hadron {
            name: "Delta-",
            symbol: "Δ⁻",
            quarks: "ddd",
            mass_mev: 1232.0,
            charge: -1,
        },
        // Pions (mesons)
        Hadron {
            name: "pion+",
            symbol: "π⁺",
            quarks: "ud̄",
            mass_mev: 139.570,
            charge: 1,
        },
        Hadron {
            name: "pion0",
            symbol: "π⁰",
            quarks: "(uū-dd̄)/√2",
            mass_mev: 134.977,
            charge: 0,
        },
        Hadron {
            name: "pion-",
            symbol: "π⁻",
            quarks: "dū",
            mass_mev: 139.570,
            charge: -1,
        },
        // Kaons
        Hadron {
            name: "kaon+",
            symbol: "K⁺",
            quarks: "us̄",
            mass_mev: 493.677,
            charge: 1,
        },
        Hadron {
            name: "kaon0",
            symbol: "K⁰",
            quarks: "ds̄",
            mass_mev: 497.611,
            charge: 0,
        },
    ];

    // ===== ISOSPIN SPLITTINGS =====
    // These come from u↔d swaps and EM effects
    println!("  ── Isospin Splittings (u ↔ d swaps) ──\n");
    println!(
        "  {:>12} {:>12}  {:>10}  {:>10}  {:>12}",
        "Pair", "Swap", "Δm (MeV)", "Δm/m_e", "ζ-analysis"
    );
    println!("  {}", "─".repeat(65));

    // n - p: swap one u→d
    let delta_np = 939.565 - 938.272;
    let delta_np_me = delta_np / m_e;
    println!(
        "  {:>12} {:>12}  {:>10.3}  {:>10.4}  5/2 = {:.4} ({:.2}%)",
        "n - p",
        "u→d (×1)",
        delta_np,
        delta_np_me,
        2.5,
        ((2.5_f64 / delta_np_me) - 1.0).abs() * 100.0
    );

    // Σ⁻ - Σ⁺: swap two u→d
    let delta_sigma = 1197.449 - 1189.37;
    let delta_sigma_me = delta_sigma / m_e;
    println!(
        "  {:>12} {:>12}  {:>10.3}  {:>10.4}  5 = 2×(5/2)? → {:.4}",
        "Σ⁻ - Σ⁺", "u→d (×2)", delta_sigma, delta_sigma_me, 5.0
    );
    println!(
        "  {:>12} {:>12}  {:>10}  {:>10}  ratio = {:.4} (expect 2.0)",
        "",
        "",
        "",
        "",
        delta_sigma_me / delta_np_me
    );

    // Ξ⁻ - Ξ⁰: swap one u→d
    let delta_xi = 1321.71 - 1314.86;
    let delta_xi_me = delta_xi / m_e;
    println!(
        "  {:>12} {:>12}  {:>10.3}  {:>10.4}  vs n-p: ratio = {:.4}",
        "Ξ⁻ - Ξ⁰",
        "u→d (×1)",
        delta_xi,
        delta_xi_me,
        delta_xi_me / delta_np_me
    );

    // K⁰ - K⁺: swap u→d
    let delta_kaon = 497.611 - 493.677;
    let delta_kaon_me = delta_kaon / m_e;
    println!(
        "  {:>12} {:>12}  {:>10.3}  {:>10.4}  vs n-p: ratio = {:.4}",
        "K⁰ - K⁺",
        "u→d (×1)",
        delta_kaon,
        delta_kaon_me,
        delta_kaon_me / delta_np_me
    );

    // π± - π⁰
    let delta_pion = 139.570 - 134.977;
    let delta_pion_me = delta_pion / m_e;
    println!(
        "  {:>12} {:>12}  {:>10.3}  {:>10.4}  ≈ 9 (integer!) ({:.2}%)",
        "π± - π⁰",
        "EM effect",
        delta_pion,
        delta_pion_me,
        ((9.0_f64 / delta_pion_me) - 1.0).abs() * 100.0
    );

    println!();

    // ===== THE KEY TEST: Is the splitting ALWAYS 5/2 per u→d swap? =====
    println!("  ── THE COMPOSITENESS TEST ──\n");
    println!("  If (m_n - m_p)/m_e ≈ 5/2 per u→d swap,");
    println!("  then Σ⁻ - Σ⁺ (TWO u→d swaps) should be ≈ 5.\n");

    let prediction_sigma = 5.0 * m_e; // predicted Δm
    let actual_sigma = 1197.449 - 1189.37;
    println!("  Σ prediction:  Δm = 5·m_e = {:.3} MeV", prediction_sigma);
    println!("  Σ actual:      Δm = {:.3} MeV", actual_sigma);
    println!(
        "  Error:         {:.2}%",
        ((prediction_sigma / actual_sigma) - 1.0_f64).abs() * 100.0
    );
    println!();

    // Ξ⁻ - Ξ⁰ (one swap, different strange content)
    let prediction_xi = 2.5 * m_e;
    let actual_xi = 1321.71 - 1314.86;
    println!("  Ξ prediction:  Δm = (5/2)·m_e = {:.3} MeV", prediction_xi);
    println!("  Ξ actual:      Δm = {:.3} MeV", actual_xi);
    println!(
        "  Error:         {:.2}%",
        ((prediction_xi / actual_xi) - 1.0_f64).abs() * 100.0
    );
    println!();

    // K⁰ - K⁺ (one swap, meson)
    let prediction_kaon = 2.5 * m_e;
    let actual_kaon = 497.611 - 493.677;
    println!(
        "  K prediction:  Δm = (5/2)·m_e = {:.3} MeV",
        prediction_kaon
    );
    println!("  K actual:      Δm = {:.3} MeV", actual_kaon);
    println!(
        "  Error:         {:.2}%",
        ((prediction_kaon / actual_kaon) - 1.0_f64).abs() * 100.0
    );
    println!();

    // ===== QUARK SECTOR ASSIGNMENT TEST =====
    println!("  ═══ SECTOR ASSIGNMENT TEST ═══\n");
    println!("  Hypothesis: charged particles → ζ(2), neutral → ζ(4)\n");

    // For each hadron, compute mass/m_e and check which ζ sector
    for h in &hadrons {
        let ratio = h.mass_mev / m_e;
        // Check distance to nearest ζ(2)-based formula vs ζ(4)-based
        let d2 = {
            // Try π^n/ζ(2) family
            let mut best = f64::MAX;
            for n in 1..=10 {
                let v = PI.powi(n) / zeta2;
                let err = ((v / ratio) - 1.0).abs();
                if err < best {
                    best = err;
                }
                // with coefficients
                for &c in &[2.0, 3.0, 4.0, 5.0, 6.0, 10.0, 12.0] {
                    let v2 = c * PI.powi(n) / zeta2;
                    let err2 = ((v2 / ratio) - 1.0).abs();
                    if err2 < best {
                        best = err2;
                    }
                }
            }
            best
        };
        let d4 = {
            let mut best = f64::MAX;
            for n in 1..=10 {
                let v = PI.powi(n) / zeta4;
                let err = ((v / ratio) - 1.0).abs();
                if err < best {
                    best = err;
                }
                for &c in &[2.0, 3.0, 4.0, 5.0, 6.0, 10.0, 12.0] {
                    let v2 = c * PI.powi(n) / zeta4;
                    let err2 = ((v2 / ratio) - 1.0).abs();
                    if err2 < best {
                        best = err2;
                    }
                }
            }
            best
        };

        let sector = if d2 < d4 { "ζ(2) +" } else { "ζ(4) ○" };
        let expected = if h.charge != 0 { "charged" } else { "neutral" };
        let consistent = if (h.charge != 0 && d2 < d4) || (h.charge == 0 && d4 < d2) {
            "✓"
        } else {
            "✗"
        };

        println!(
            "  {:>4} {:>5}  Q={:>2}  m/m_e={:>8.1}  nearest: {}  ({})  {}",
            h.symbol, h.quarks, h.charge, ratio, sector, expected, consistent
        );
    }

    println!();
    println!("  ═══ SUMMARY ═══\n");
    println!("  The compositeness test asks: when you swap u↔d in a hadron,");
    println!("  does the mass shift by (5/2)·m_e per swap?");
    println!();
    println!(
        "  n-p:    {:.4} m_e  (expect 2.5)  → {:.2}%",
        delta_np_me,
        ((2.5 / delta_np_me) - 1.0).abs() * 100.0
    );
    println!(
        "  Σ⁻-Σ⁺: {:.4} m_e (expect 5.0)  → {:.2}%",
        delta_sigma_me,
        ((5.0 / delta_sigma_me) - 1.0).abs() * 100.0
    );
    println!(
        "  Ξ⁻-Ξ⁰: {:.4} m_e (expect 2.5)  → {:.2}%",
        delta_xi_me,
        ((2.5 / delta_xi_me) - 1.0).abs() * 100.0
    );
    println!(
        "  K⁰-K⁺: {:.4} m_e (expect 2.5)  → {:.2}%",
        delta_kaon_me,
        ((2.5 / delta_kaon_me) - 1.0).abs() * 100.0
    );
    println!();
    println!("  🪞 Does the composition respect the mirror? ❄️");
}
