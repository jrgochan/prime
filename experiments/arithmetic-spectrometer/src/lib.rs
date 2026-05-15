//! # Arithmetic Mass Spectrometer
//!
//! A systematic search engine for number-theoretic formulas
//! that match physical constants.
//!
//! ## Architecture
//!
//! - `constants.rs`  — Physical constants database (PDG 2022)
//! - `formulas.rs`   — Number-theoretic formula library builder
//! - `engine.rs`     — Search engine with auto-correction
//! - `report.rs`     — Output formatters (markdown, JSON)

pub mod constants;
pub mod engine;
pub mod formulas;
pub mod report;
