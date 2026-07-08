//! Standard Model Particle Table + Arithmetic Mapping
//!
//! Maps SM particles to Cathedral observables using the cathedral-physics.tex dictionary.
//! Includes Gemini's Axion (Dirichlet characters) and W± mass-gap anchor.

use std::fmt;

/// A Standard Model particle with its Cathedral dual.
#[derive(Debug, Clone)]
pub struct Particle {
    pub name: &'static str,
    pub symbol: &'static str,
    pub mass_mev: f64,
    pub spin: &'static str,
    pub generation: u8, // 0 for bosons
    pub category: Category,
    pub cathedral_dual: &'static str,
    pub observable: &'static str,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Category {
    Quark,
    Lepton,
    GaugeBoson,
    ScalarBoson,
    Hypothetical, // Axion, WIMP, etc.
}

impl fmt::Display for Category {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Category::Quark => write!(f, "Quark"),
            Category::Lepton => write!(f, "Lepton"),
            Category::GaugeBoson => write!(f, "Gauge Boson"),
            Category::ScalarBoson => write!(f, "Scalar Boson"),
            Category::Hypothetical => write!(f, "Hypothetical"),
        }
    }
}

/// PDG 2024 particle table with Cathedral duals.
pub fn standard_model_particles() -> Vec<Particle> {
    vec![
        // ═══════ QUARKS (ω → generation) ═══════
        Particle {
            name: "Up",
            symbol: "u",
            mass_mev: 2.16,
            spin: "1/2",
            generation: 1,
            category: Category::Quark,
            cathedral_dual: "Prime contribution to E₁ (ω=1)",
            observable: "prime_energy_fraction",
        },
        Particle {
            name: "Down",
            symbol: "d",
            mass_mev: 4.70,
            spin: "1/2",
            generation: 1,
            category: Category::Quark,
            cathedral_dual: "Prime contribution to E₁ (ω=1), heavier isospin",
            observable: "prime_energy_split",
        },
        Particle {
            name: "Charm",
            symbol: "c",
            mass_mev: 1273.0,
            spin: "1/2",
            generation: 2,
            category: Category::Quark,
            cathedral_dual: "Semiprime contribution to E₂ (ω=2)",
            observable: "semiprime_energy_fraction",
        },
        Particle {
            name: "Strange",
            symbol: "s",
            mass_mev: 93.5,
            spin: "1/2",
            generation: 2,
            category: Category::Quark,
            cathedral_dual: "Semiprime contribution to E₂ (ω=2), lighter isospin",
            observable: "semiprime_energy_split",
        },
        Particle {
            name: "Top",
            symbol: "t",
            mass_mev: 172_570.0,
            spin: "1/2",
            generation: 3,
            category: Category::Quark,
            cathedral_dual: "3-almost-prime contribution to E₃ (ω=3)",
            observable: "three_ap_energy_fraction",
        },
        Particle {
            name: "Bottom",
            symbol: "b",
            mass_mev: 4183.0,
            spin: "1/2",
            generation: 3,
            category: Category::Quark,
            cathedral_dual: "3-almost-prime contribution to E₃ (ω=3), lighter isospin",
            observable: "three_ap_energy_split",
        },
        // ═══════ LEPTONS ═══════
        Particle {
            name: "Electron",
            symbol: "e⁻",
            mass_mev: 0.51099895,
            spin: "1/2",
            generation: 1,
            category: Category::Lepton,
            cathedral_dual: "Diagonal self-energy G(2,2) (lightest prime mode)",
            observable: "diagonal_self_energy_p2",
        },
        Particle {
            name: "Electron Neutrino",
            symbol: "νₑ",
            mass_mev: 0.0000008,
            spin: "1/2",
            generation: 1,
            category: Category::Lepton,
            cathedral_dual: "See-Saw: d²_N via Schur complement C = G - bbᵀ",
            observable: "seesaw_vacuum_energy",
        },
        Particle {
            name: "Muon",
            symbol: "μ⁻",
            mass_mev: 105.658,
            spin: "1/2",
            generation: 2,
            category: Category::Lepton,
            cathedral_dual: "Off-diagonal correlator G(p,q) at semiprimes",
            observable: "off_diagonal_semiprime",
        },
        Particle {
            name: "Muon Neutrino",
            symbol: "νμ",
            mass_mev: 0.17,
            spin: "1/2",
            generation: 2,
            category: Category::Lepton,
            cathedral_dual: "See-Saw: 2nd covariance eigenvalue (tiny, nonzero)",
            observable: "seesaw_cov_eigenvalue_2",
        },
        Particle {
            name: "Tau",
            symbol: "τ⁻",
            mass_mev: 1776.93,
            spin: "1/2",
            generation: 3,
            category: Category::Lepton,
            cathedral_dual: "Cotangent sum amplitude V(a,b) at 3-AP",
            observable: "cotangent_three_ap",
        },
        Particle {
            name: "Tau Neutrino",
            symbol: "ντ",
            mass_mev: 18.2,
            spin: "1/2",
            generation: 3,
            category: Category::Lepton,
            cathedral_dual: "See-Saw: 3rd covariance eigenvalue (tiny, nonzero)",
            observable: "seesaw_cov_eigenvalue_3",
        },
        // ═══════ GAUGE BOSONS ═══════
        Particle {
            name: "Photon",
            symbol: "γ",
            mass_mev: 0.0,
            spin: "1",
            generation: 0,
            category: Category::GaugeBoson,
            cathedral_dual: "1/(jk) Coulomb kernel — massless, long-range",
            observable: "reciprocal_product_trace",
        },
        Particle {
            name: "Gluon",
            symbol: "g",
            mass_mev: 0.0,
            spin: "1",
            generation: 0,
            category: Category::GaugeBoson,
            cathedral_dual: "gcd(j,k)/(jk) color factor — confined, short-range",
            observable: "gcd_weighted_trace",
        },
        Particle {
            name: "W Boson",
            symbol: "W±",
            mass_mev: 80_377.0,
            spin: "1",
            generation: 0,
            category: Category::GaugeBoson,
            cathedral_dual: "Spectral gap λ_min(G) — MASS ANCHOR (Gemini)",
            observable: "spectral_gap",
        },
        Particle {
            name: "Z Boson",
            symbol: "Z⁰",
            mass_mev: 91_188.0,
            spin: "1",
            generation: 0,
            category: Category::GaugeBoson,
            cathedral_dual: "Covariance matrix dominant mode (variance peak)",
            observable: "covariance_dominant_mode",
        },
        // ═══════ SCALAR BOSONS ═══════
        Particle {
            name: "Higgs",
            symbol: "H⁰",
            mass_mev: 125_200.0,
            spin: "0",
            generation: 0,
            category: Category::ScalarBoson,
            cathedral_dual: "γ-renormalization: Euler-Mascheroni mass subtraction",
            observable: "euler_mascheroni_scale",
        },
        // ═══════ HYPOTHETICAL (Gemini's Upgrades) ═══════
        Particle {
            name: "Axion",
            symbol: "a⁰",
            mass_mev: 1e-6, // ~μeV range
            spin: "0",
            generation: 0,
            category: Category::Hypothetical,
            cathedral_dual: "Dirichlet characters χ(n) — restore fract-part parity",
            observable: "dirichlet_character_energy",
        },
    ]
}

/// Mass scale calibration following Gemini's advice:
/// Anchor spectral gap λ_min to W± mass (80,377 MeV).
pub struct MassCalibration {
    pub scale_factor: f64, // MeV per eigenvalue unit
    pub lambda_min: f64,   // Spectral gap
    pub w_mass_mev: f64,   // W± mass = 80,377 MeV
}

impl MassCalibration {
    /// Create calibration from spectral gap (Gemini's anchor).
    pub fn from_spectral_gap(lambda_min: f64) -> Self {
        let w_mass = 80_377.0;
        Self {
            scale_factor: w_mass / lambda_min,
            lambda_min,
            w_mass_mev: w_mass,
        }
    }

    /// Convert an eigenvalue to MeV.
    pub fn to_mev(&self, eigenvalue: f64) -> f64 {
        eigenvalue * self.scale_factor
    }

    /// Key mass ratios to test against SM.
    pub fn key_ratios() -> Vec<(&'static str, f64)> {
        vec![
            ("m_μ / m_e", 206.77),
            ("m_τ / m_e", 3477.2),
            ("m_τ / m_μ", 16.82),
            ("m_W / m_Z", 0.882),
            ("m_H / m_W", 1.558),
            ("m_t / m_u", 79_894.0),
            ("m_b / m_s", 44.74),
            ("m_c / m_u", 589.4),
        ]
    }
}
