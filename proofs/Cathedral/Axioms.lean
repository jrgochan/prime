import Cathedral.Defs
import Cathedral.NymanBeurling.BDMellin

/-!
  # Axiom Registry

  Central hub for axiom documentation. This file contains no axiom
  declarations — all axioms are declared in their respective modules.

  ## Crown Path

  `#print axioms nyman_beurling_equivalence`:
    `[baez_duarte_forward, propext, Classical.choice, Quot.sound]`

  The Nyman-Beurling-Báez-Duarte equivalence rests on a single literature
  axiom — Báez-Duarte’s 2003 forward direction theorem
  (IMRN no. 36, pp. 1989–2009). The converse is fully proved.

  ## Note on the Forward Direction

  The forward direction (RH ⟹ d²→0) cannot be proved from the Prime
  Number Theorem + Abel summation alone. Under Mertens-type bounds, the
  spatial L² norm `∫(1-f_N)²` diverges. The proof requires complex-analytic
  machinery (Parseval/Mellin identity on the critical line). This is
  encapsulated in `baez_duarte_forward`.

  ## Alternative Paths

  Three alternative proof paths for the forward direction are preserved:
  * PATH A (Mellin):          `nyman_beurling_equivalence_mellin`
  * PATH B (Perron):          `nyman_beurling_equivalence_spatial`
  * PATH C (Renormalization): `nyman_beurling_equivalence_renormalization`

  ## Converse Direction

  `nyman_beurling_converse` has zero custom axioms. Proved via the
  Rank-1 Mellin identity at off-critical-line zeros (BDMellin.lean).
-/

noncomputable section
open Real MeasureTheory

-- ════════════════════════════════════════════════════════
-- TIER 3: ZETA SEPARATION (NOW ON BD BASIS)
-- ════════════════════════════════════════════════════════

/-- If ζ has a non-trivial zero ρ off the critical line, then no real
    linear combination of Báez-Duarte basis functions `{1/(kx)}` can
    approximate `1` in `L²(0,1)` closer than some `δ > 0`.

    Proved via the Rank-1 Mellin identity:
    * `M[h_k](ρ) = 1/(k(ρ-1))` at ζ zeros — rank-1 tensor
    * `|ℓ_ρ(1-f)|² ≥ t²/(|ρ|⁴|ρ-1|²) > 0`
    * Cauchy-Schwarz: `d²_N ≥ (2σ-1) · t²/(|ρ|⁴|ρ-1|²)`

    References: Nyman (1950), Beurling (1955), Báez-Duarte (2003). -/
theorem zeta_zero_separates :
    ∀ ρ : ℂ, riemannZeta ρ = 0 →
    0 < ρ.re → ρ.re < 1 → ρ.re ≠ 1/2 →
    ∃ δ : ℝ, 0 < δ ∧
    ∀ N : ℕ, 2 ≤ N → ∀ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 ≥ δ :=
  zeta_zero_separates_bd

end
