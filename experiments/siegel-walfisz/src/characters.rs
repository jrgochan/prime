// siegel-walfisz/src/characters.rs
//
// Dirichlet characters mod 8 — the four real characters

/// The four Dirichlet characters mod 8.
/// All are real-valued: χ(k) ∈ {-1, 0, 1}.
///
/// χ₁ = principal (Kronecker symbol (1|k))
/// χ₂ = (2|k) quadratic character
/// χ₃ = (-2|k)
/// χ₄ = (-1|k) = Legendre symbol
pub fn chi8(i: usize, k: usize) -> i64 {
    if k.is_multiple_of(2) {
        return 0; // all characters vanish on even integers
    }
    match i {
        0 => 1, // χ₁: principal character
        1 => {
            // χ₂: (2|k) — depends on k mod 8
            match k % 8 {
                1 | 7 => 1,
                3 | 5 => -1,
                _ => 0,
            }
        }
        2 => {
            // χ₃: (-2|k) — depends on k mod 8
            match k % 8 {
                1 | 3 => 1,
                5 | 7 => -1,
                _ => 0,
            }
        }
        3 => {
            // χ₄: (-1|k) — depends on k mod 4
            match k % 4 {
                1 => 1,
                3 => -1,
                _ => 0,
            }
        }
        _ => panic!("character index must be 0..3"),
    }
}

/// Character names for display
pub fn chi_name(i: usize) -> &'static str {
    match i {
        0 => "χ₁ (principal)",
        1 => "χ₂ (2|·)",
        2 => "χ₃ (-2|·)",
        3 => "χ₄ (-1|·)",
        _ => "?",
    }
}

/// Known exact values of L(1, χ) for the non-principal characters mod 8.
/// L(1, χ₂) = ln(1+√2)/√2 ≈ 0.6232...  (Kronecker symbol (2|·))
/// L(1, χ₃) = π/(2√2) ≈ 1.11072...       (Kronecker symbol (-2|·))
/// L(1, χ₄) = π/4 ≈ 0.78539...            (Leibniz formula, (-1|·))
pub fn l1_exact(i: usize) -> f64 {
    let pi = std::f64::consts::PI;
    let sqrt2 = std::f64::consts::SQRT_2;
    match i {
        1 => (1.0 + sqrt2).ln() / sqrt2, // L(1, χ₂) = ln(1+√2)/√2
        2 => pi / (2.0 * sqrt2),         // L(1, χ₃) = π/(2√2)
        3 => pi / 4.0,                   // L(1, χ₄) = π/4
        _ => f64::INFINITY,              // L(1, χ₁) = ∞ (pole)
    }
}
