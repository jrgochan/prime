//! Production output writers for the Cathedral Particle Zoo v2.
//!
//! Produces:
//! - `summary_N{}.txt`        — Human-readable full analysis report
//! - `certificate_N{}.json`   — Machine-readable JSON certificate
//! - `generation_N{}.tsv`     — ω-class generation decomposition
//! - `coupling_N{}.tsv`       — Arithmetic coupling constants across N
//! - `seesaw_N{}.tsv`         — See-Saw vacuum energy data
//! - `particle_table_N{}.tsv` — SM particle table with predictions

use std::io::Write;

use crate::coupling::ArithmeticCouplings;
use crate::generation_scan::GenerationScan;
use crate::particle_map;
use crate::seesaw::SeeSawAnalysis;

/// A complete analysis result for one N value, ready for serialization.
#[derive(Debug, Clone, serde::Serialize)]
pub struct ZooResult {
    pub n: usize,
    pub dim: usize,
    pub has_dd: bool,
    pub precision: String,

    // Structural
    pub trace: f64,
    pub frobenius: f64,
    pub condition_estimate: f64,
    pub diag_min: f64,
    pub diag_max: f64,
    pub gershgorin_lambda_min: Option<f64>,
    pub gershgorin_lambda_max: Option<f64>,

    // Mertens
    pub mertens_product: f64,

    // Coupling constants
    pub alpha_s: f64,
    pub alpha_em: f64,
    pub harmonic_sum: f64,
    pub zeta_2: f64,

    // See-Saw
    pub d2_n: f64,
    pub b_norm_sq: f64,
    pub lambda_min_diag: f64,
    pub lambda_max_diag: f64,
    pub seesaw_prediction: f64,
    pub seesaw_ratio: f64,
    pub condition_number: f64,

    // Generations
    pub generations: Vec<GenerationEntry>,

    // Number theory
    pub factorization: String,
    pub divisor_count: u64,
    pub is_highly_composite: bool,
    pub prime_count: u64,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct GenerationEntry {
    pub omega: u32,
    pub energy: f64,
    pub abs_energy: f64,
    pub count: usize,
    pub mass_ratio: f64,
    pub sm_generation: String,
}

/// Write all output files for a zoo result.
pub fn write_all(r: &ZooResult, dir: &str) -> std::io::Result<()> {
    std::fs::create_dir_all(dir)?;
    write_summary(r, dir)?;
    write_certificate(r, dir)?;
    write_generations_tsv(r, dir)?;
    write_coupling_tsv(r, dir)?;
    write_seesaw_tsv(r, dir)?;
    write_particle_table_tsv(r, dir)?;
    Ok(())
}

/// Human-readable summary report.
pub fn write_summary(r: &ZooResult, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/summary_N{}.txt", r.n);
    let mut f = std::fs::File::create(&p)?;

    writeln!(f, "═══ CATHEDRAL PARTICLE ZOO v2 — N={} ═══", r.n)?;
    writeln!(f, "Standard Model ↔ Arithmetic Mapping")?;
    writeln!(f, "Gemini Upgrades: Axion · See-Saw · Coupling Constants")?;
    writeln!(f, "Antigravity: HpdfReader · Liquid Argon · Proof Tree")?;
    writeln!(f)?;

    writeln!(f, "FILE METADATA")?;
    writeln!(f, "  N           = {}", r.n)?;
    writeln!(f, "  dim         = {}", r.dim)?;
    writeln!(f, "  Precision   = {}", r.precision)?;
    writeln!(f, "  Has DD      = {}", r.has_dd)?;
    if !r.factorization.is_empty() {
        writeln!(f, "  Factorizn   = {}", r.factorization)?;
    }
    writeln!(f, "  d(N)        = {}", r.divisor_count)?;
    writeln!(f, "  HC?         = {}", r.is_highly_composite)?;
    writeln!(f, "  π(N)        = {}", r.prime_count)?;
    writeln!(f)?;

    writeln!(f, "STRUCTURAL INVARIANTS")?;
    writeln!(f, "  Trace         = {:.15e}", r.trace)?;
    writeln!(f, "  Frobenius     = {:.15e}", r.frobenius)?;
    writeln!(f, "  Condition     = {:.6e}", r.condition_estimate)?;
    writeln!(
        f,
        "  Diag range    = [{:.10}, {:.10}]",
        r.diag_min, r.diag_max
    )?;
    if let Some(g) = r.gershgorin_lambda_min {
        writeln!(
            f,
            "  Gershgorin λ  = [{:.10}, {:.10}]",
            g,
            r.gershgorin_lambda_max.unwrap_or(0.0)
        )?;
    }
    writeln!(f)?;

    writeln!(f, "MERTENS SCREENING")?;
    writeln!(f, "  Π(1-1/p)    = {:.15e}", r.mertens_product)?;
    writeln!(
        f,
        "  e^(-γ)/lnN  = {:.15e}",
        (-cathedral_utils::arith::EULER_GAMMA).exp() / (r.n as f64).ln()
    )?;
    writeln!(f)?;

    writeln!(f, "COUPLING CONSTANTS (Gemini's Formula)")?;
    writeln!(
        f,
        "  α_s         = {:.10}  (H_N/ζ₂_N → asymptotic freedom)",
        r.alpha_s
    )?;
    writeln!(f, "  H_N         = {:.10}  (harmonic sum)", r.harmonic_sum)?;
    writeln!(f, "  ζ₂(N)       = {:.10}  (Basel partial)", r.zeta_2)?;
    writeln!(
        f,
        "  α_em        = {:.10}  (prime energy fraction)",
        r.alpha_em
    )?;
    writeln!(f, "  SM α_em     = {:.10}  (1/137.036)", 1.0 / 137.036)?;
    writeln!(f)?;

    writeln!(f, "SEE-SAW MECHANISM (Gemini)")?;
    writeln!(
        f,
        "  d²_N        = {:.15e}  (vacuum energy = neutrino mass sum)",
        r.d2_n
    )?;
    writeln!(f, "  ‖b‖²        = {:.10}  (Dirac mass²)", r.b_norm_sq)?;
    writeln!(
        f,
        "  λ_max(diag) = {:.10}  (right-handed mass M_R)",
        r.lambda_max_diag
    )?;
    writeln!(f, "  λ_min(diag) = {:.10}  (mass gap)", r.lambda_min_diag)?;
    writeln!(
        f,
        "  κ           = {:.2}  (condition number)",
        r.condition_number
    )?;
    writeln!(
        f,
        "  See-Saw pred = {:.15e}  (‖b‖⁴/λ_max)",
        r.seesaw_prediction
    )?;
    writeln!(f, "  Ratio       = {:.10}", r.seesaw_ratio)?;
    writeln!(f)?;

    writeln!(f, "GENERATION DECOMPOSITION")?;
    writeln!(f, "  ω\tE_ω\t\t\t|E_ω|\t\t\tcount\tmass_ratio\tSM_gen")?;
    for g in &r.generations {
        writeln!(
            f,
            "  {}\t{:.10e}\t{:.10e}\t{}\t{:.8}\t{}",
            g.omega, g.energy, g.abs_energy, g.count, g.mass_ratio, g.sm_generation
        )?;
    }
    writeln!(f)?;

    writeln!(f, "MASS CALIBRATION (W± anchor — Gemini)")?;
    if r.lambda_min_diag > 1e-15 {
        let scale = 80_377.0 / r.lambda_min_diag;
        writeln!(f, "  λ_min = {:.10} → W± = 80377 MeV", r.lambda_min_diag)?;
        writeln!(f, "  Scale = {:.2} MeV/unit", scale)?;
        writeln!(
            f,
            "  λ_max = {:.10} → {:.2} MeV",
            r.lambda_max_diag,
            r.lambda_max_diag * scale
        )?;
    }

    eprintln!("  ✓ Summary → {p}");
    Ok(())
}

/// JSON certificate for machine consumption.
pub fn write_certificate(r: &ZooResult, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/certificate_N{}.json", r.n);
    let json = serde_json::to_string_pretty(r).unwrap();
    std::fs::write(&p, json)?;
    eprintln!("  ✓ Cert → {p}");
    Ok(())
}

/// TSV: generation decomposition.
pub fn write_generations_tsv(r: &ZooResult, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/generation_N{}.tsv", r.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(
        f,
        "omega\tenergy\tabs_energy\tcount\tmass_ratio\tsm_generation"
    )?;
    for g in &r.generations {
        writeln!(
            f,
            "{}\t{:.15e}\t{:.15e}\t{}\t{:.10}\t{}",
            g.omega, g.energy, g.abs_energy, g.count, g.mass_ratio, g.sm_generation
        )?;
    }
    eprintln!("  ✓ Generation → {p}");
    Ok(())
}

/// TSV: coupling constants.
pub fn write_coupling_tsv(r: &ZooResult, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/coupling_N{}.tsv", r.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(f, "N\talpha_s\tH_N\tzeta_2\talpha_em\tSM_alpha_em")?;
    writeln!(
        f,
        "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}",
        r.n,
        r.alpha_s,
        r.harmonic_sum,
        r.zeta_2,
        r.alpha_em,
        1.0 / 137.036
    )?;
    eprintln!("  ✓ Coupling → {p}");
    Ok(())
}

/// TSV: see-saw data.
pub fn write_seesaw_tsv(r: &ZooResult, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/seesaw_N{}.tsv", r.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(
        f,
        "N\td2_N\tb_norm_sq\tlambda_min\tlambda_max\tkappa\tseesaw_pred\tseesaw_ratio"
    )?;
    writeln!(
        f,
        "{}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.15e}\t{:.6}\t{:.15e}\t{:.10}",
        r.n,
        r.d2_n,
        r.b_norm_sq,
        r.lambda_min_diag,
        r.lambda_max_diag,
        r.condition_number,
        r.seesaw_prediction,
        r.seesaw_ratio
    )?;
    eprintln!("  ✓ See-Saw → {p}");
    Ok(())
}

/// TSV: particle table with Cathedral predictions.
pub fn write_particle_table_tsv(r: &ZooResult, dir: &str) -> std::io::Result<()> {
    let p = format!("{dir}/particle_table_N{}.tsv", r.n);
    let mut f = std::fs::File::create(&p)?;
    writeln!(
        f,
        "name\tsymbol\tmass_mev\tcategory\tgeneration\tcathedral_dual\tobservable"
    )?;
    for particle in particle_map::standard_model_particles() {
        writeln!(
            f,
            "{}\t{}\t{:.6}\t{}\t{}\t{}\t{}",
            particle.name,
            particle.symbol,
            particle.mass_mev,
            particle.category,
            particle.generation,
            particle.cathedral_dual,
            particle.observable
        )?;
    }
    eprintln!("  ✓ Particle Table → {p}");
    Ok(())
}

impl ZooResult {
    /// Build a ZooResult from available HPDF reader data.
    #[cfg(feature = "hpdf")]
    pub fn from_hpdf(
        reader: &cathedral_utils::hpdf::reader::HpdfReader,
        couplings: &ArithmeticCouplings,
        seesaw: Option<&SeeSawAnalysis>,
        gen_scan: Option<&GenerationScan>,
    ) -> Self {
        let n = reader.max_n();
        let dim = reader.dim();

        let primes = cathedral_utils::arith::sieve_primes(n);
        let mertens: f64 = (2..=n)
            .filter(|&p| primes[p])
            .map(|p| 1.0 - 1.0 / p as f64)
            .product();

        let ss = reader.read_structural_scalars().ok();
        let nt = reader.read_number_theory_attrs().ok().flatten();
        let dist = reader.read_distance().ok().flatten();

        let generations = gen_scan
            .map(|gs| {
                gs.generations
                    .iter()
                    .map(|g| GenerationEntry {
                        omega: g.omega,
                        energy: g.energy,
                        abs_energy: g.abs_energy,
                        count: g.count,
                        mass_ratio: g.mass_ratio,
                        sm_generation: match g.omega {
                            1 => "1st (u,d,e,ν)".into(),
                            2 => "2nd (c,s,μ,ν)".into(),
                            3 => "3rd (t,b,τ,ν)".into(),
                            _ => format!("beyond SM (ω={})", g.omega),
                        },
                    })
                    .collect()
            })
            .unwrap_or_default();

        ZooResult {
            n,
            dim,
            has_dd: reader.has_dd(),
            precision: if reader.has_dd() {
                "DD (~31 digits)".into()
            } else {
                "f64 (~16 digits)".into()
            },
            trace: ss.as_ref().map(|s| s.trace).unwrap_or(0.0),
            frobenius: ss.as_ref().map(|s| s.frobenius_norm).unwrap_or(0.0),
            condition_estimate: ss.as_ref().map(|s| s.condition_estimate).unwrap_or(0.0),
            diag_min: ss.as_ref().map(|s| s.diag_min).unwrap_or(0.0),
            diag_max: ss.as_ref().map(|s| s.diag_max).unwrap_or(0.0),
            gershgorin_lambda_min: ss.as_ref().and_then(|s| s.gershgorin_lambda_min),
            gershgorin_lambda_max: ss.as_ref().and_then(|s| s.gershgorin_lambda_max),
            mertens_product: mertens,
            alpha_s: couplings.alpha_s,
            alpha_em: couplings.alpha_em,
            harmonic_sum: couplings.harmonic_sum,
            zeta_2: couplings.zeta_2,
            d2_n: seesaw
                .map(|s| s.d2_n)
                .unwrap_or(dist.map(|d| d.d_squared).unwrap_or(0.0)),
            b_norm_sq: seesaw.map(|s| s.b_norm_sq).unwrap_or(0.0),
            lambda_min_diag: seesaw
                .map(|s| s.lambda_min)
                .unwrap_or(ss.as_ref().map(|s| s.diag_min).unwrap_or(0.0)),
            lambda_max_diag: seesaw
                .map(|s| s.lambda_max)
                .unwrap_or(ss.as_ref().map(|s| s.diag_max).unwrap_or(0.0)),
            seesaw_prediction: seesaw.map(|s| s.seesaw_prediction).unwrap_or(0.0),
            seesaw_ratio: seesaw.map(|s| s.seesaw_ratio).unwrap_or(0.0),
            condition_number: seesaw
                .map(|s| s.condition_number)
                .unwrap_or(ss.as_ref().map(|s| s.condition_estimate).unwrap_or(0.0)),
            generations,
            factorization: nt
                .as_ref()
                .map(|n| n.factorization.clone())
                .unwrap_or_default(),
            divisor_count: nt.as_ref().map(|n| n.divisor_count).unwrap_or(0),
            is_highly_composite: nt.as_ref().map(|n| n.is_highly_composite).unwrap_or(false),
            prime_count: nt.as_ref().map(|n| n.prime_count).unwrap_or(0),
        }
    }
}
