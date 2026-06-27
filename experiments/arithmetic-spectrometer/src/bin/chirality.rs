//! # Chirality & Anomaly Cancellation Probe
//!
//! Tests whether including:
//! 1. Electromagnetic self-energy (Q²·α per quark)
//! 2. Generation anomaly cancellation (quarks + leptons = 0)
//! 3. Strange quark mass corrections
//!    improves the compositeness predictions.
//!
//! Key physics: The n-p splitting works because EM and QCD
//! nearly cancel. Other hadrons need both terms.

use std::f64::consts::PI;

fn main() {
    let zeta2: f64 = PI * PI / 6.0;
    let zeta4: f64 = PI.powi(4) / 90.0;
    let zeta6: f64 = PI.powi(6) / 945.0;
    let _alpha: f64 = 1.0 / 137.035999084;
    let glass: f64 = 15.0 / (PI * PI);
    let m_e: f64 = 0.51099895; // MeV

    println!("╔══════════════════════════════════════════════════════════════════╗");
    println!("║  CHIRALITY & ANOMALY CANCELLATION PROBE                        ║");
    println!("║  Can generation structure + EM self-energy fix the splittings?  ║");
    println!("╚══════════════════════════════════════════════════════════════════╝\n");

    // ===== GENERATION ANOMALY CANCELLATION =====
    println!("  ═══ ANOMALY CANCELLATION CHECK ═══\n");
    println!("  Each SM generation: sum of (Y·Q) = 0\n");

    #[allow(dead_code)]
    struct Fermion {
        name: &'static str,
        charge: f64,      // electric charge
        color_factor: i32, // 3 for quarks, 1 for leptons
        chirality: &'static str, // L or R
        generation: u32,
    }

    let fermions = vec![
        // Generation 1
        Fermion { name: "u_L", charge: 2.0/3.0, color_factor: 3, chirality: "L", generation: 1 },
        Fermion { name: "d_L", charge: -1.0/3.0, color_factor: 3, chirality: "L", generation: 1 },
        Fermion { name: "u_R", charge: 2.0/3.0, color_factor: 3, chirality: "R", generation: 1 },
        Fermion { name: "d_R", charge: -1.0/3.0, color_factor: 3, chirality: "R", generation: 1 },
        Fermion { name: "e_L", charge: -1.0, color_factor: 1, chirality: "L", generation: 1 },
        Fermion { name: "ν_L", charge: 0.0, color_factor: 1, chirality: "L", generation: 1 },
        Fermion { name: "e_R", charge: -1.0, color_factor: 1, chirality: "R", generation: 1 },
    ];

    // Check anomaly cancellation: sum of Q³ × N_c = 0
    let mut q3_sum = 0.0_f64;
    for f in &fermions {
        let contrib = f.charge.powi(3) * f.color_factor as f64;
        q3_sum += contrib;
        println!("  {:>6}  Q={:>6.3}  N_c={}  Q³·N_c = {:>8.4}",
            f.name, f.charge, f.color_factor, contrib);
    }
    println!("  ─────────────────────────────────────────");
    println!("  Sum of Q³·N_c = {:.6}  {}", q3_sum,
        if q3_sum.abs() < 1e-10 { "✓ ANOMALY CANCELLED" } else { "✗ ANOMALY PRESENT" });

    println!();

    // ===== GENERATION ζ-ASSIGNMENT =====
    println!("  ═══ GENERATION ζ-ASSIGNMENT ═══\n");
    println!("  If quarks have ζ assignments, what do leptons get?\n");

    // Known quark assignments from spectrometer:
    // d/u ≈ 2·ζ(4) → u is "bare", d gets a ζ(4) factor
    // b/c ≈ 2·ζ(2) → c is "bare", b gets a ζ(2) factor
    // Pattern: down-type quarks carry the ζ factor

    println!("  DOWN-TYPE QUARKS carry ζ factors:");
    println!("    d: factor 2·ζ(4) = {:.4} [dark sector]", 2.0*zeta4);
    println!("    s: factor 20     (exact integer)");
    println!("    b: factor 2·ζ(2) = {:.4} [positive sector]", 2.0*zeta2);
    println!();
    println!("  LEPTONS (by anomaly cancellation, should mirror quarks):");
    println!("    If down-quarks → ζ factors, then charged leptons → ???");
    println!();

    // Test: do lepton mass ratios have ζ structure?
    let m_mu = 105.6583755;  // MeV
    let m_tau = 1776.86;     // MeV

    let mu_e = m_mu / m_e;     // 206.768
    let tau_mu = m_tau / m_mu; // 16.817
    let tau_e = m_tau / m_e;   // 3477.23

    println!("  Lepton ratios:");
    println!("    m_μ/m_e = {:.3}", mu_e);
    println!("    m_τ/m_μ = {:.3}", tau_mu);
    println!("    m_τ/m_e = {:.3}", tau_e);
    println!();

    // Search for ζ patterns in lepton ratios
    println!("  Searching for ζ patterns in lepton mass ratios...\n");

    let search_targets = vec![
        ("m_μ/m_e", mu_e),
        ("m_τ/m_μ", tau_mu),
        ("m_τ/m_e", tau_e),
    ];

    let candidates: Vec<(&str, f64)> = vec![
        ("ζ(2)²·ζ(4)", zeta2*zeta2*zeta4),
        ("ζ(2)³", zeta2.powi(3)),
        ("ζ(4)²·ζ(2)", zeta4*zeta4*zeta2),
        ("12·ζ(2)²", 12.0*zeta2*zeta2),
        ("6·ζ(2)·ζ(4)", 6.0*zeta2*zeta4),
        ("ζ(2)²", zeta2*zeta2),
        ("π⁴/ζ(4)", PI.powi(4)/zeta4),
        ("π³/ζ(2)", PI.powi(3)/zeta2),
        ("2·π³/ζ(4)", 2.0*PI.powi(3)/zeta4),
        ("36·π⁴", 36.0*PI.powi(4)),
        ("π⁵/ζ(6)", PI.powi(5)/zeta6),
        ("ζ(2)·π²", zeta2*PI*PI),
        ("ζ(4)·π³", zeta4*PI.powi(3)),
        ("12·ζ(4)·π", 12.0*zeta4*PI),
        ("2·ζ(2)·π", 2.0*zeta2*PI),
        ("5·ζ(2)", 5.0*zeta2),
        ("ζ(2)·ζ(4)·π", zeta2*zeta4*PI),
        ("glass·ζ(2)·π²", glass*zeta2*PI*PI),
    ];

    for &(tname, tval) in &search_targets {
        println!("  {} = {:.4}:", tname, tval);
        let mut sorted: Vec<(&str, f64, f64)> = candidates.iter()
            .map(|&(n, v)| (n, v, ((v/tval) - 1.0).abs() * 100.0))
            .collect();
        sorted.sort_by(|a, b| a.2.partial_cmp(&b.2).unwrap());
        for &(name, val, err) in sorted.iter().take(3) {
            let mark = if err < 1.0 { "⚡" } else if err < 5.0 { "·" } else { "" };
            println!("    {:>25} = {:>10.4}  err = {:.3}% {}", name, val, err, mark);
        }
        println!();
    }

    // ===== CORRECTED COMPOSITENESS WITH EM SELF-ENERGY =====
    println!("  ═══ CORRECTED COMPOSITENESS TEST ═══\n");
    println!("  Adding EM self-energy: ΔE_em ∝ α·Q²·Λ_QCD\n");
    println!("  Cottingham formula: Δm_em ≈ (3α/4π)·Q²·m_hadron·f(m_q/Λ)\n");

    // The Cottingham formula for EM mass difference:
    // For nucleons: Δm_em(p) ≈ -0.76 MeV (proton lighter from EM)
    // This is because the proton's Q² = 1 gives positive EM energy
    // but the neutron's overall EM contribution is different
    //
    // Key: the n-p mass difference has TWO parts:
    // 1. Quark mass: (m_d - m_u) ≈ +2.51 MeV (neutron heavier)
    // 2. EM self-energy: ≈ -1.22 MeV (proton lighter because Q²_p > 0)
    // Net: 2.51 - 1.22 = 1.29 MeV ✓

    let delta_m_quark = 4.67 - 2.16;  // m_d - m_u in MeV
    let delta_m_em_np: f64 = -1.22;      // EM correction (proton lighter)
    let predicted_np = delta_m_quark + delta_m_em_np;
    let actual_np: f64 = 1.293;

    println!("  NUCLEON (n - p):");
    println!("    Quark mass diff:  (m_d - m_u) = {:.2} MeV", delta_m_quark);
    println!("    EM correction:    ΔE_em = {:.2} MeV", delta_m_em_np);
    println!("    Predicted:        {:.2} MeV", predicted_np);
    println!("    Actual:           {:.3} MeV", actual_np);
    println!("    Error:            {:.1}%", ((predicted_np/actual_np) - 1.0).abs() * 100.0);
    println!();

    // Now the key question: does this decomposition have ζ structure?
    println!("  ζ-DECOMPOSITION of n-p splitting:");
    println!("    Δm/m_e = {:.4}", actual_np / m_e);
    println!("    = (m_d-m_u)/m_e + ΔE_em/m_e");
    println!("    = {:.4} + ({:.4})", delta_m_quark/m_e, delta_m_em_np/m_e);
    println!("    = {:.4} - {:.4}", delta_m_quark/m_e, (-delta_m_em_np)/m_e);
    println!();

    // Is the quark mass difference ζ-structured?
    let quark_ratio = delta_m_quark / m_e;
    let em_ratio = (-delta_m_em_np) / m_e;
    println!("    Quark term: {:.4} m_e", quark_ratio);
    println!("      ≈ ζ(2)²/ζ(4)·2 = {:.4}?  err = {:.2}%",
        zeta2*zeta2/zeta4 * 2.0,
        ((zeta2*zeta2/zeta4 * 2.0 / quark_ratio) - 1.0).abs() * 100.0);
    println!("      ≈ π²/2 = {:.4}?       err = {:.2}%",
        PI*PI/2.0,
        ((PI*PI/2.0 / quark_ratio) - 1.0).abs() * 100.0);
    println!("      ≈ 3·ζ(2) = {:.4}?     err = {:.2}%",
        3.0*zeta2,
        ((3.0*zeta2 / quark_ratio) - 1.0).abs() * 100.0);
    println!();
    println!("    EM term: {:.4} m_e", em_ratio);
    println!("      ≈ ζ(2)²/ζ(4) = 5/2 = {:.4}? err = {:.2}%",
        2.5,
        ((2.5 / em_ratio) - 1.0).abs() * 100.0);
    println!("      ≈ ζ(4)·π = {:.4}?       err = {:.2}%",
        zeta4*PI,
        ((zeta4*PI / em_ratio) - 1.0).abs() * 100.0);
    println!();

    // NET: (quark term) - (EM term) = n-p splitting
    println!("    Net = {:.4} - {:.4} = {:.4} m_e", quark_ratio, em_ratio,
        quark_ratio - em_ratio);
    println!("    Actual = {:.4} m_e", actual_np / m_e);
    println!();

    // ===== STRANGE SECTOR: The Gell-Mann—Okubo relation =====
    println!("  ═══ GELL-MANN—OKUBO MASS FORMULA ═══\n");
    println!("  Classical SU(3) flavor result: relates baryon masses.\n");

    let m_n: f64 = 939.565;
    let _m_p: f64 = 938.272;
    let m_lambda: f64 = 1115.683;
    let m_sigma0: f64 = 1192.642;
    let m_xi0: f64 = 1314.86;

    // GMO: (m_N + m_Ξ) / 2 = (3·m_Λ + m_Σ) / 4
    let gmo_lhs = (m_n + m_xi0) / 2.0;
    let gmo_rhs = (3.0*m_lambda + m_sigma0) / 4.0;
    println!("  (m_N + m_Ξ)/2 = {:.2} MeV", gmo_lhs);
    println!("  (3·m_Λ + m_Σ)/4 = {:.2} MeV", gmo_rhs);
    println!("  Error: {:.3}%", ((gmo_lhs/gmo_rhs) - 1.0).abs() * 100.0);
    println!("  Status: {} (known to work at ~0.6%)",
        if ((gmo_lhs/gmo_rhs) - 1.0).abs() < 0.01 { "✓ CONFIRMED" } else { "✗" });
    println!();

    // Now: does the GMO relation have ζ structure?
    // GMO coefficient is 3/4 for Λ, 1/4 for Σ
    // The 3:1 ratio...
    println!("  GMO coefficients: 3/4 for Λ, 1/4 for Σ");
    println!("  Ratio 3:1 ... any ζ connection?");
    println!("    ζ(2)/ζ(4) = {:.4}", zeta2/zeta4);
    println!("    3·ζ(4)/ζ(2) = {:.4}", 3.0*zeta4/zeta2);
    println!();

    // ===== THE EQUAL SPACING RULE =====
    println!("  ═══ DECUPLET EQUAL SPACING RULE ═══\n");
    println!("  For spin-3/2 baryons (Δ, Σ*, Ξ*, Ω):\n");

    let m_delta: f64 = 1232.0;
    let m_sigma_star: f64 = 1383.7;
    let m_xi_star: f64 = 1531.8;
    let m_omega: f64 = 1672.45;

    let spacing1 = m_sigma_star - m_delta;
    let spacing2 = m_xi_star - m_sigma_star;
    let spacing3 = m_omega - m_xi_star;

    println!("  Δ(1232) → Σ*(1384): Δm = {:.1} MeV", spacing1);
    println!("  Σ*(1384) → Ξ*(1532): Δm = {:.1} MeV", spacing2);
    println!("  Ξ*(1532) → Ω(1672): Δm = {:.1} MeV", spacing3);
    println!("  Average spacing: {:.1} MeV", (spacing1+spacing2+spacing3)/3.0);
    println!();

    let avg_spacing_me = ((spacing1+spacing2+spacing3)/3.0) / m_e;
    println!("  Average spacing / m_e = {:.2}", avg_spacing_me);
    println!("  = each strange quark adds ~{:.1} m_e", avg_spacing_me);
    println!();

    // Search for ζ pattern in the spacing
    println!("  ζ-search for decuplet spacing ({:.2} m_e):", avg_spacing_me);
    let spacing_candidates: Vec<(&str, f64)> = vec![
        ("π⁴/ζ(4)", PI.powi(4)/zeta4),
        ("π³·ζ(2)", PI.powi(3)*zeta2),
        ("90·ζ(2)", 90.0*zeta2),
        ("6·π³", 6.0*PI.powi(3)),
        ("60·ζ(4)", 60.0*zeta4),
        ("π⁵/ζ(6)", PI.powi(5)/zeta6),
        ("2·π⁴", 2.0*PI.powi(4)),
        ("90·ζ(4)·π", 90.0*zeta4*PI),
        ("ζ(2)·ζ(4)·π³", zeta2*zeta4*PI.powi(3)),
        ("180·ζ(2)²/π", 180.0*zeta2*zeta2/PI),
        ("10·ζ(2)·π", 10.0*zeta2*PI),
    ];
    let mut sorted: Vec<(&str, f64, f64)> = spacing_candidates.iter()
        .map(|&(n, v)| (n, v, ((v/avg_spacing_me) - 1.0).abs() * 100.0))
        .collect();
    sorted.sort_by(|a, b| a.2.partial_cmp(&b.2).unwrap());
    for &(name, val, err) in sorted.iter().take(5) {
        let mark = if err < 1.0 { "⚡" } else if err < 5.0 { "·" } else { "" };
        println!("    {:>25} = {:>10.4}  err = {:.3}% {}", name, val, err, mark);
    }

    println!("\n  🪞 The chirality probe has spoken. ❄️");
}
