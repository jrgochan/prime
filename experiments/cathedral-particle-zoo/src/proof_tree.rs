//! Proof Tree Bridge — Cathedral theorem ↔ physics observable mapping
//!
//! Maps each formally verified theorem to its physics dual,
//! following the cathedral-physics.tex correspondence dictionary.

/// Proof status in the Cathedral.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ProofStatus {
    Proved,
    Axiom,
    ExternalTheorem,
}

impl std::fmt::Display for ProofStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            ProofStatus::Proved => write!(f, "✅ PROVED"),
            ProofStatus::Axiom => write!(f, "⬜ AXIOM"),
            ProofStatus::ExternalTheorem => write!(f, "📖 EXTERNAL"),
        }
    }
}

/// A node in the proof tree with its physics dual.
#[derive(Debug, Clone)]
pub struct ProofNode {
    pub lean_name: &'static str,
    pub physics_name: &'static str,
    pub description: &'static str,
    pub status: ProofStatus,
    pub file: &'static str,
    pub observables: &'static [&'static str],
}

/// The Cathedral-Physics dictionary — proof tree with physics duals.
///
/// Each theorem we proved generates a testable prediction about the
/// spectral data in the H5 files.
pub fn cathedral_physics_dictionary() -> Vec<ProofNode> {
    vec![
        // ═══════ HC PRIME STRUCTURE (ALL PROVED TONIGHT!) ═══════
        ProofNode {
            lean_name: "divisor_swap_ge",
            physics_name: "Crossing Symmetry",
            description: "d(N/p·q) ≥ d(N) — single prime swap",
            status: ProofStatus::Proved,
            file: "HCPrimeStructure.lean",
            observables: &["eigenvalue_interlacing"],
        },
        ProofNode {
            lean_name: "gen_divisor_swap_ge",
            physics_name: "Multi-Particle Crossing",
            description: "d(N/p^s·q) ≥ d(N) — generalized swap",
            status: ProofStatus::Proved,
            file: "HCPrimeStructure.lean",
            observables: &["multi_swap_ratio"],
        },
        ProofNode {
            lean_name: "hc_primes_consecutive",
            physics_name: "Completeness of States",
            description: "HC prime factors = {2,...,p_max} — no spectral gaps",
            status: ProofStatus::Proved,
            file: "HCPrimeStructure.lean",
            observables: &["prime_factor_completeness"],
        },
        ProofNode {
            lean_name: "hc_exponent_bound",
            physics_name: "Ultraviolet Cutoff",
            description: "v_p(N) < 2s — bounded occupation numbers",
            status: ProofStatus::Proved,
            file: "HCPrimeStructure.lean",
            observables: &["max_exponent", "occupation_bound"],
        },
        ProofNode {
            lean_name: "hc_primeFactors_eventually_contain",
            physics_name: "Asymptotic Freedom",
            description: "All primes eventually divide HC — all modes activate",
            status: ProofStatus::Proved, // GRADUATED THIS SESSION!
            file: "HCPrimeStructure.lean",
            observables: &["prime_coverage", "activation_threshold"],
        },
        // ═══════ EULER PRODUCT ═══════
        ProofNode {
            lean_name: "gcdWeighted_euler",
            physics_name: "Color Factor Evaluation",
            description: "Σμ(j)μ(k)·gcd/(jk) = Π(1-1/p) — gluon propagator",
            status: ProofStatus::Proved,
            file: "HCEulerProduct.lean",
            observables: &["gcd_euler_product"],
        },
        ProofNode {
            lean_name: "recipProduct_euler",
            physics_name: "Photon Propagator",
            description: "Σμ(j)μ(k)/(jk) = Π(1-1/p)² — QED vacuum",
            status: ProofStatus::Proved,
            file: "HCEulerProduct.lean",
            observables: &["reciprocal_product_trace"],
        },
        ProofNode {
            lean_name: "mertens_hc_product_tendsto_zero_proved",
            physics_name: "Screening → Confinement",
            description: "Mertens product → 0 at HC numbers",
            status: ProofStatus::Proved,
            file: "HCPrimeStructure.lean",
            observables: &["mertens_product", "screening_rate"],
        },
        // ═══════ MERTENS BRIDGE ═══════
        ProofNode {
            lean_name: "mertens_third_asymptotic",
            physics_name: "Thermodynamic Limit",
            description: "Π(1-1/p) ~ e^{-γ}/ln(x) — Mertens' Third Theorem",
            status: ProofStatus::ExternalTheorem,
            file: "MertensBridge.lean",
            observables: &["mertens_third_fit"],
        },
        // ═══════ GRAM BOUND (NEXT TARGET) ═══════
        ProofNode {
            lean_name: "hc_gram_bound",
            physics_name: "Vacuum Stability",
            description: "vᵀGv ≤ 1 + K/ln(N) — bounded ground state energy",
            status: ProofStatus::Axiom,
            file: "HCGramBridge.lean",
            observables: &["vtgv", "gram_bound_gap"],
        },
        // ═══════ VARIANCE DECOMPOSITION ═══════
        ProofNode {
            lean_name: "vasyuninCovMatrix_decomp",
            physics_name: "See-Saw Mechanism (Gemini)",
            description: "C = G - bbᵀ — Schur complement = neutrino mass generator",
            status: ProofStatus::Proved,
            file: "VasyuninBypass.lean",
            observables: &["seesaw_vacuum_energy", "condition_number"],
        },
        // ═══════ LINEAR ALGEBRA ═══════
        ProofNode {
            lean_name: "gram_psd",
            physics_name: "Positive Vacuum Energy",
            description: "G ≥ 0 — no negative-energy states (no tachyons)",
            status: ProofStatus::Proved,
            file: "GramPSD.lean",
            observables: &["lambda_min_nonneg"],
        },
    ]
}

/// Display the proof tree bridge.
pub fn display_proof_tree() {
    let nodes = cathedral_physics_dictionary();
    let proved = nodes
        .iter()
        .filter(|n| n.status == ProofStatus::Proved)
        .count();
    let total = nodes.len();

    println!("  ┌─────────────────────────────────────────────────────────────────┐");
    println!(
        "  │ PROOF TREE ↔ PHYSICS BRIDGE ({}/{} proved)                  │",
        proved, total
    );
    println!("  ├──────────────────────────┬──────────────────┬──────────────────┤");
    println!("  │ Cathedral Theorem        │ Physics Dual     │ Status           │");
    println!("  ├──────────────────────────┼──────────────────┼──────────────────┤");
    for node in &nodes {
        println!(
            "  │ {:24} │ {:16} │ {:16} │",
            node.lean_name, node.physics_name, node.status
        );
    }
    println!("  └──────────────────────────┴──────────────────┴──────────────────┘");
}
