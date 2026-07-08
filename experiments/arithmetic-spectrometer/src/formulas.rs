//! # Formula Library Builder
//!
//! Generates the complete library of number-theoretic candidate formulas
//! organized by construction method:
//!
//! 1. **Powers of π** with integer coefficients
//! 2. **Zeta values** ζ(2k) with powers and coefficients (the Dimensional Ladder)
//! 3. **Cross-products** ζ(j)^a / ζ(k)^b
//! 4. **Spectral lift grid** π^n / ζ(k) — the core S-Duality pattern
//! 5. **Glass combinations** (15/π²)^n
//! 6. **α-related** for coupling constant searches
//! 7. **Integer/rational** for exact-match detection

use serde::Serialize;
use std::f64::consts::PI;

/// A candidate number-theoretic formula.
#[derive(Debug, Clone, Serialize)]
pub struct Formula {
    /// Human-readable expression
    pub name: String,
    /// Numerical value
    pub value: f64,
    /// Construction method
    pub method: FormulaMethod,
}

#[derive(Debug, Clone, Copy, Serialize)]
pub enum FormulaMethod {
    PiPower,
    ZetaValue,
    ZetaCross,
    SpectralLift,
    Glass,
    Alpha,
    Corrected,
    IntegerRational,
}

/// The fundamental number-theoretic constants.
pub struct ZetaConstants {
    pub alpha: f64,
    pub glass: f64,
    pub zetas: Vec<(usize, f64, &'static str)>,
}

impl Default for ZetaConstants {
    fn default() -> Self {
        Self::new()
    }
}

impl ZetaConstants {
    pub fn new() -> Self {
        let alpha = 1.0 / 137.035999084;
        Self {
            alpha,
            glass: 15.0 / (PI * PI),
            zetas: vec![
                (2, PI.powi(2) / 6.0, "ζ(2)"),
                (4, PI.powi(4) / 90.0, "ζ(4)"),
                (6, PI.powi(6) / 945.0, "ζ(6)"),
                (8, PI.powi(8) / 9450.0, "ζ(8)"),
                (10, PI.powi(10) / 93555.0, "ζ(10)"),
                (12, 691.0 * PI.powi(12) / 638512875.0, "ζ(12)"),
            ],
        }
    }
}

/// Build the complete formula library.
pub fn build_formulas() -> Vec<Formula> {
    let c = ZetaConstants::new();
    let mut formulas = Vec::new();

    // 1. Powers of π with coefficients
    let coefficients = [
        1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0, 12.0, 15.0, 24.0, 30.0, 36.0, 60.0, 90.0, 120.0,
        180.0, 360.0,
    ];
    for n in 1..=12 {
        for &coeff in &coefficients {
            let v = coeff * PI.powi(n);
            let name = if coeff == 1.0 {
                format!("π^{}", n)
            } else {
                format!("{}·π^{}", coeff, n)
            };
            formulas.push(Formula {
                name,
                value: v,
                method: FormulaMethod::PiPower,
            });
        }
    }

    // 2. Zeta values with powers and coefficients (Dimensional Ladder)
    for &(_, zk, zname) in &c.zetas {
        for pow in 1..=5 {
            formulas.push(Formula {
                name: format!("{}^{}", zname, pow),
                value: zk.powi(pow),
                method: FormulaMethod::ZetaValue,
            });
            formulas.push(Formula {
                name: format!("1/{}^{}", zname, pow),
                value: 1.0 / zk.powi(pow),
                method: FormulaMethod::ZetaValue,
            });
            for &coeff in &[2.0, 3.0, 4.0, 5.0, 6.0, 12.0, 24.0, 90.0, 180.0] {
                formulas.push(Formula {
                    name: format!("{}·{}^{}", coeff, zname, pow),
                    value: coeff * zk.powi(pow),
                    method: FormulaMethod::ZetaValue,
                });
            }
        }
    }

    // 3. Cross-products: ζ(j)^a / ζ(k)^b
    for (i, &(_, zj, jname)) in c.zetas.iter().enumerate() {
        for &(_, zk, kname) in &c.zetas[i + 1..] {
            let combos: Vec<(String, f64)> = vec![
                (format!("{}·{}", jname, kname), zj * zk),
                (format!("{}/{}", jname, kname), zj / zk),
                (format!("{}/{}", kname, jname), zk / zj),
                (format!("{}²/{}", jname, kname), zj * zj / zk),
                (format!("{}²/{}", kname, jname), zk * zk / zj),
                (format!("{}³/{}", jname, kname), zj.powi(3) / zk),
            ];
            for (desc, val) in combos {
                formulas.push(Formula {
                    name: desc,
                    value: val,
                    method: FormulaMethod::ZetaCross,
                });
            }
        }
    }

    // 4. Spectral Lift Grid: π^n / ζ(k) and c·π^n / ζ(k)
    for n in 1..=12 {
        for &(_, zk, zname) in &c.zetas {
            formulas.push(Formula {
                name: format!("π^{}/{}", n, zname),
                value: PI.powi(n) / zk,
                method: FormulaMethod::SpectralLift,
            });
            formulas.push(Formula {
                name: format!("{}·π^{}", zname, n),
                value: zk * PI.powi(n),
                method: FormulaMethod::SpectralLift,
            });
            for &coeff in &[2.0, 3.0, 4.0, 6.0, 12.0] {
                formulas.push(Formula {
                    name: format!("{}·π^{}/{}", coeff, n, zname),
                    value: coeff * PI.powi(n) / zk,
                    method: FormulaMethod::SpectralLift,
                });
            }
        }
    }

    // 5. Glass combinations
    for pow in 1..=8 {
        formulas.push(Formula {
            name: format!("glass^{}", pow),
            value: c.glass.powi(pow),
            method: FormulaMethod::Glass,
        });
        for n in 1..=6 {
            formulas.push(Formula {
                name: format!("π^{}·glass^{}", n, pow),
                value: PI.powi(n) * c.glass.powi(pow),
                method: FormulaMethod::Glass,
            });
        }
    }

    // 6. α-related
    let alpha = c.alpha;
    for &(name, val) in &[
        ("α", alpha),
        ("α²", alpha * alpha),
        ("1/α", 1.0 / alpha),
        ("α/π", alpha / PI),
        ("α²/3", alpha * alpha / 3.0),
        ("α·π", alpha * PI),
        ("α²·π", alpha * alpha * PI),
    ] {
        formulas.push(Formula {
            name: name.to_string(),
            value: val,
            method: FormulaMethod::Alpha,
        });
    }

    // 7. Corrected formulas (our discoveries)
    let zeta2 = c.zetas[0].1;
    formulas.push(Formula {
        name: "6π⁵·(1+α²/3)".to_string(),
        value: 6.0 * PI.powi(5) * (1.0 + alpha * alpha / 3.0),
        method: FormulaMethod::Corrected,
    });
    formulas.push(Formula {
        name: "(5/2)·(1+α·ζ(2))".to_string(),
        value: 2.5 * (1.0 + alpha * zeta2),
        method: FormulaMethod::Corrected,
    });

    // 8. 1/(n·ζ(k)) for coupling constants
    for &(_, zk, zname) in &c.zetas {
        for &n in &[1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 24.0] {
            formulas.push(Formula {
                name: format!("1/({}·{})", n, zname),
                value: 1.0 / (n * zk),
                method: FormulaMethod::ZetaValue,
            });
        }
    }

    // 9. Integers and simple rationals
    for n in 1..=500 {
        formulas.push(Formula {
            name: format!("{}", n),
            value: n as f64,
            method: FormulaMethod::IntegerRational,
        });
    }
    for &(a, b) in &[
        (1, 2),
        (1, 3),
        (1, 4),
        (2, 3),
        (3, 2),
        (3, 4),
        (4, 3),
        (5, 2),
        (5, 3),
        (7, 2),
        (7, 3),
        (8, 3),
        (11, 3),
        (22, 7),
        (5, 4),
        (7, 4),
        (8, 5),
    ] {
        formulas.push(Formula {
            name: format!("{}/{}", a, b),
            value: a as f64 / b as f64,
            method: FormulaMethod::IntegerRational,
        });
    }

    // Filter
    formulas.retain(|f| f.value.is_finite() && f.value > 0.0 && f.value < 1e12);
    formulas
}
