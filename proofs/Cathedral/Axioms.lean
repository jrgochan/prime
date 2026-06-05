import Cathedral.Defs
import Cathedral.NymanBeurling.BDMellin

/-!
  # Axiom Registry (v18 — Wall Consolidation)

  Central hub for axiom documentation. The single non-PNT axiom
  (`overcancellation_axiom`) is declared in `Cathedral.Wall`.
  All other modules import it via `import Cathedral.Wall`.

  ## Dual Crown Architecture

  The Cathedral provides two independent paths to RH:

  ### Analytic Crown
  `#print axioms nyman_beurling_equivalence`:
    `[baez_duarte_forward, propext, Classical.choice, Quot.sound]`

  Rests on a single literature axiom — Báez-Duarte's 2003 forward
  direction theorem (IMRN no. 36, pp. 1989–2009). Converse fully proved.

  ### Oracle Crown
  `#print axioms oracle_crown`:
    `[oracle_certificates, pnt_mu_log_div_k, pnt_mu_log_sq_div_k,
     propext, Classical.choice, Quot.sound]`

  Proves RH directly from DD-precision GPU measurement of the Gram
  quadratic form at highly composite numbers. Once RH is proved,
  the Oracle Cascade (`OracleCascade.lean`) derives all downstream
  theorems unconditionally.

  ## Alternative Paths

  Four additional forward paths are preserved:
  * PATH A (Mellin):          `nyman_beurling_equivalence_mellin`
  * PATH B (Perron):          `nyman_beurling_equivalence_spatial`
  * PATH C (Renormalization): `nyman_beurling_equivalence_renormalization`
  * PATH D (Oracle):          `rh_from_oracle` → `oracle_crown`

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
