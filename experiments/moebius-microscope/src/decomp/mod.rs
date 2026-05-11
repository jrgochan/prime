//! Parallel decomposition engine for the Möbius Cancellation Microscope v3.
//!
//! Architecture (v3 refactor):
//!   - `state`:      Decomp struct and sub-metric structs
//!   - `classify`:   per-term classification kernel (hot inner loop)
//!   - `row`:        RowResult struct, merge logic
//!   - `runners`:    f64 on-the-fly and HPDF parallel engines
//!   - `gpu_runner`: GPU-accelerated engine (cuBLAS bilinear forms)
//!   - `gram`:       Gram bound metric finalization and display
//!   - `taper`:      §5 Taper Cancellation Tracker (U-2L/lnN → 1 analysis)

pub mod classify;
#[cfg(feature = "gpu")]
pub mod gpu_runner;
pub mod gram;
pub mod row;
pub mod runners;
pub mod state;
pub mod taper;

pub use state::Decomp;
