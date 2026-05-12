//! # Cathedral Particle Zoo v2 — Standard Model ↔ Arithmetic Mapping
//!
//! Maps Standard Model particles to arithmetic observables in Gram matrix H5 files.
//!
//! ## Modules
//! - [`particle_map`] — PDG particle table + mass scale calibration + Axion
//! - [`rmt_analysis`] — Random Matrix Theory spectral statistics (GUE/GOE/Poisson)
//! - [`generation_scan`] — ω-class energy decomposition → generation structure
//! - [`coupling`] — Arithmetic coupling constants (α_em, α_s, sin²θ_W)
//! - [`seesaw`] — Neutrino mass via Schur complement (Gemini's See-Saw)
//! - [`spectral_bands`] — Scenario B test: eigenvalue band ratios → SM mass ratios
//! - [`proof_tree`] — Cathedral theorem ↔ physics observable bridge
//! - [`report`] — Rich terminal output formatting

pub mod particle_map;
pub mod rmt_analysis;
pub mod generation_scan;
pub mod coupling;
pub mod seesaw;
pub mod spectral_bands;
pub mod proof_tree;
pub mod report;
pub mod output;
