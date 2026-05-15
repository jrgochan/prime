//! # Physical Constants (PDG 2022/2024)
//!
//! All particle masses, coupling constants, and magnetic moments
//! used as targets for the spectrometer search.
//!
//! Sources:
//! - Particle Data Group (PDG) 2022 Review
//! - CODATA 2018 Recommended Values
//! - All masses given in MeV/c² unless noted

use serde::Serialize;

/// A physical constant or particle property to match against.
#[derive(Debug, Clone, Serialize)]
pub struct PhysicalTarget {
    /// Human-readable name
    pub name: &'static str,
    /// Symbol (LaTeX-ish)
    pub symbol: &'static str,
    /// Numerical value (dimensionless ratio or coupling)
    pub value: f64,
    /// Unit description
    pub unit: &'static str,
    /// Category for grouping
    pub category: Category,
    /// Source/reference
    pub source: &'static str,
    /// Uncertainty (if known, as absolute value)
    pub uncertainty: Option<f64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub enum Category {
    Nucleon,
    Lepton,
    Meson,
    Baryon,
    GaugeBoson,
    QuarkRatio,
    Coupling,
    MagneticMoment,
    MassRatio,
}

impl std::fmt::Display for Category {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            Category::Nucleon => write!(f, "NUCLEON"),
            Category::Lepton => write!(f, "LEPTON"),
            Category::Meson => write!(f, "MESON"),
            Category::Baryon => write!(f, "BARYON"),
            Category::GaugeBoson => write!(f, "GAUGE BOSON"),
            Category::QuarkRatio => write!(f, "QUARK RATIO"),
            Category::Coupling => write!(f, "COUPLING"),
            Category::MagneticMoment => write!(f, "MAGNETIC MOMENT"),
            Category::MassRatio => write!(f, "MASS RATIO"),
        }
    }
}

/// Electron mass in MeV (used to convert absolute masses to ratios)
pub const M_ELECTRON_MEV: f64 = 0.51099895000;
/// Proton mass in MeV
pub const M_PROTON_MEV: f64 = 938.27208816;

/// Build the complete target list.
pub fn build_targets() -> Vec<PhysicalTarget> {
    let m_e = M_ELECTRON_MEV;
    let m_p = M_PROTON_MEV;

    vec![
        // ===== NUCLEONS =====
        PhysicalTarget {
            name: "proton/electron mass ratio", symbol: "m_p/m_e",
            value: 1836.15267343, unit: "", category: Category::Nucleon,
            source: "CODATA 2018", uncertainty: Some(0.00000011),
        },
        PhysicalTarget {
            name: "neutron/electron mass ratio", symbol: "m_n/m_e",
            value: 1838.68366173, unit: "", category: Category::Nucleon,
            source: "CODATA 2018", uncertainty: Some(0.00000089),
        },
        PhysicalTarget {
            name: "neutron-proton mass difference", symbol: "(m_n-m_p)/m_e",
            value: 2.53098830, unit: "", category: Category::Nucleon,
            source: "CODATA 2018", uncertainty: Some(0.00000012),
        },

        // ===== LEPTONS =====
        PhysicalTarget {
            name: "muon/electron mass ratio", symbol: "m_μ/m_e",
            value: 206.7682830, unit: "", category: Category::Lepton,
            source: "CODATA 2018", uncertainty: Some(0.0000046),
        },
        PhysicalTarget {
            name: "tau/electron mass ratio", symbol: "m_τ/m_e",
            value: 3477.228, unit: "", category: Category::Lepton,
            source: "PDG 2022", uncertainty: Some(0.016),
        },
        PhysicalTarget {
            name: "tau/muon mass ratio", symbol: "m_τ/m_μ",
            value: 16.8170, unit: "", category: Category::MassRatio,
            source: "PDG 2022", uncertainty: Some(0.0001),
        },
        PhysicalTarget {
            name: "Koide parameter", symbol: "Q_K",
            value: 0.666661, unit: "", category: Category::Lepton,
            source: "computed from PDG masses", uncertainty: None,
        },

        // ===== MESONS (mass ratio to electron) =====
        PhysicalTarget {
            name: "charged pion", symbol: "m_π±/m_e",
            value: 139.57039 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "neutral pion", symbol: "m_π⁰/m_e",
            value: 134.9768 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "charged kaon", symbol: "m_K±/m_e",
            value: 493.677 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "neutral kaon", symbol: "m_K⁰/m_e",
            value: 497.611 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "eta meson", symbol: "m_η/m_e",
            value: 547.862 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "rho meson", symbol: "m_ρ/m_e",
            value: 775.26 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "omega meson", symbol: "m_ω/m_e",
            value: 782.66 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "phi meson", symbol: "m_φ/m_e",
            value: 1019.461 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "D meson", symbol: "m_D/m_e",
            value: 1869.66 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "J/psi meson", symbol: "m_J/ψ/m_e",
            value: 3096.9 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "B meson", symbol: "m_B/m_e",
            value: 5279.34 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Upsilon", symbol: "m_Υ/m_e",
            value: 9460.30 / m_e, unit: "", category: Category::Meson,
            source: "PDG 2022", uncertainty: None,
        },

        // ===== BARYONS =====
        PhysicalTarget {
            name: "Lambda baryon", symbol: "m_Λ/m_e",
            value: 1115.683 / m_e, unit: "", category: Category::Baryon,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Sigma+ baryon", symbol: "m_Σ+/m_e",
            value: 1189.37 / m_e, unit: "", category: Category::Baryon,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Xi baryon", symbol: "m_Ξ/m_e",
            value: 1314.86 / m_e, unit: "", category: Category::Baryon,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Omega baryon", symbol: "m_Ω/m_e",
            value: 1672.45 / m_e, unit: "", category: Category::Baryon,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Delta baryon", symbol: "m_Δ/m_e",
            value: 1232.0 / m_e, unit: "", category: Category::Baryon,
            source: "PDG 2022", uncertainty: None,
        },

        // ===== GAUGE BOSONS =====
        PhysicalTarget {
            name: "W boson / electron", symbol: "m_W/m_e",
            value: 80379.0 / m_e, unit: "", category: Category::GaugeBoson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Z boson / electron", symbol: "m_Z/m_e",
            value: 91187.6 / m_e, unit: "", category: Category::GaugeBoson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Higgs boson / electron", symbol: "m_H/m_e",
            value: 125250.0 / m_e, unit: "", category: Category::GaugeBoson,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "W boson / proton", symbol: "m_W/m_p",
            value: 80379.0 / m_p, unit: "", category: Category::MassRatio,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Z boson / proton", symbol: "m_Z/m_p",
            value: 91187.6 / m_p, unit: "", category: Category::MassRatio,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "Higgs boson / proton", symbol: "m_H/m_p",
            value: 125250.0 / m_p, unit: "", category: Category::MassRatio,
            source: "PDG 2022", uncertainty: None,
        },

        // ===== QUARK MASS RATIOS (MS-bar at 2 GeV) =====
        PhysicalTarget {
            name: "down/up quark", symbol: "m_d/m_u",
            value: 2.162, unit: "", category: Category::QuarkRatio,
            source: "PDG 2022 (MS-bar 2 GeV)", uncertainty: Some(0.09),
        },
        PhysicalTarget {
            name: "strange/down quark", symbol: "m_s/m_d",
            value: 20.0, unit: "", category: Category::QuarkRatio,
            source: "PDG 2022", uncertainty: Some(1.0),
        },
        PhysicalTarget {
            name: "charm/strange quark", symbol: "m_c/m_s",
            value: 13.597, unit: "", category: Category::QuarkRatio,
            source: "PDG 2022", uncertainty: Some(0.5),
        },
        PhysicalTarget {
            name: "bottom/charm quark", symbol: "m_b/m_c",
            value: 3.2913, unit: "", category: Category::QuarkRatio,
            source: "PDG 2022", uncertainty: Some(0.03),
        },
        PhysicalTarget {
            name: "top/bottom quark", symbol: "m_t/m_b",
            value: 41.330, unit: "", category: Category::QuarkRatio,
            source: "PDG 2022", uncertainty: Some(0.5),
        },
        PhysicalTarget {
            name: "strange/up quark", symbol: "m_s/m_u",
            value: 43.241, unit: "", category: Category::QuarkRatio,
            source: "PDG 2022", uncertainty: Some(2.0),
        },

        // ===== COUPLING CONSTANTS =====
        PhysicalTarget {
            name: "fine structure constant", symbol: "α",
            value: 0.0072973525693, unit: "", category: Category::Coupling,
            source: "CODATA 2018", uncertainty: Some(0.0000000000011),
        },
        PhysicalTarget {
            name: "strong coupling at M_Z", symbol: "α_s(M_Z)",
            value: 0.1179, unit: "", category: Category::Coupling,
            source: "PDG 2022", uncertainty: Some(0.0010),
        },
        PhysicalTarget {
            name: "Weinberg angle", symbol: "sin²θ_W",
            value: 0.23122, unit: "", category: Category::Coupling,
            source: "PDG 2022 (MS-bar at M_Z)", uncertainty: Some(0.00003),
        },

        // ===== MAGNETIC MOMENTS =====
        PhysicalTarget {
            name: "proton magnetic moment", symbol: "μ_p/μ_N",
            value: 2.7928473446, unit: "nuclear magnetons", category: Category::MagneticMoment,
            source: "CODATA 2018", uncertainty: Some(0.0000000008),
        },
        PhysicalTarget {
            name: "neutron magnetic moment", symbol: "|μ_n/μ_N|",
            value: 1.91304273, unit: "nuclear magnetons", category: Category::MagneticMoment,
            source: "CODATA 2018", uncertainty: Some(0.00000045),
        },
        PhysicalTarget {
            name: "μ_n/μ_p ratio", symbol: "|μ_n/μ_p|",
            value: 0.68497934, unit: "", category: Category::MagneticMoment,
            source: "CODATA 2018", uncertainty: None,
        },

        // ===== KEY MASS RATIOS =====
        PhysicalTarget {
            name: "proton/pion mass ratio", symbol: "m_p/m_π",
            value: m_p / 139.57039, unit: "", category: Category::MassRatio,
            source: "PDG 2022", uncertainty: None,
        },
        PhysicalTarget {
            name: "pion mass splitting", symbol: "(m_π±-m_π⁰)/m_e",
            value: (139.57039 - 134.9768) / m_e, unit: "", category: Category::MassRatio,
            source: "PDG 2022", uncertainty: None,
        },
    ]
}
