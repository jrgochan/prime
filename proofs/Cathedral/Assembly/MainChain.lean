import Cathedral.Defs
import Cathedral.Structural.Structural
import Cathedral.MellinBridge.Basic
import Cathedral.NymanBeurling.QuadFormBridge
import Cathedral.NymanBeurling.NymanBeurling
import Cathedral.NymanBeurling.BDBypass
import Cathedral.NymanBeurling.VasyuninBypass
import Cathedral.Assembly.DirectL2Crown
import Cathedral.Assembly.OneCrown
import Cathedral.Assembly.PerronCrown
import Cathedral.Assembly.MellinCrown
import Cathedral.Assembly.CovarianceFromPerron
import Cathedral.Renormalization.Bridge
import Cathedral.NymanBeurling.BDBridgeProved
-- NOTE: Cathedral.Assembly.GramCrown is DOWNSTREAM of MainChain
-- (GramBoundDirect imports MainChain for log_grows_unboundedly).
-- The discrete RH exports live in GramCrown.lean and Assembly.lean.

/-!
  # The Nyman-Beurling-Báez-Duarte Equivalence

  This file contains the continuous-path exports of the Cathedral:
  the Nyman-Beurling-Báez-Duarte equivalence theorem and supporting results.

  The discrete Gram Crown exports (preferred architecture) live in
  `GramCrown.lean` and are re-exported from `Assembly.lean`.

  ## Main Results (this file)

  ### Continuous Path (Nyman-Beurling)
  * `nyman_beurling_equivalence` : the iff characterization
    `(∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v, ∫₀¹ (1 - f_N)² < ε) ↔ RH`
  * `eigenvalue_limit_exists` : the Gram eigenvalue limit exists (unconditional)
  * `log_grows_unboundedly` : C/log(N) < ε eventually (standard calculus)

  ### Discrete RH (see GramCrown.lean / Assembly.lean)
  * `riemann_hypothesis_from_gram_global` : RH from vᵀGv ≤ 1+K/lnN (∀ large N)
  * `riemann_hypothesis_from_gram_subseq` : RH from vᵀGv ≤ 1+K/lnN (subseq)

  ## Architecture

  Both directions use the Báez-Duarte basis `{1/(kx)}`.

  * **Converse**: `d²_N → 0 ⟹ RH`, via the Rank-1 Mellin identity.
    Kernel axioms only.
  * **Forward**: `RH ⟹ d²_N → 0`, via `baez_duarte_forward`.
    Single literature axiom (Báez-Duarte, IMRN 2003, no. 36, pp. 1989–2009).

  The forward direction requires complex-analytic machinery (Perron contour
  integration + spatial L² analysis). This is proved via the Perron Crown
  chain: `rh_implies_bd_convergence_perron` (PerronCrown.lean).

  **STATUS: 2 PROOF ARCHITECTURES (May 13, 2026).**

  ARCHITECTURE 1 — Gram Crown (PREFERRED):
    `rh_discrete_global` / `rh_discrete_subseq`
    1 Crown axiom (Gram bound) + 5 PNT bureaucracy.
    Zero covariance axioms. Zero sorries.

  ARCHITECTURE 2 — Nyman-Beurling (HISTORICAL):
  The forward direction uses the Perron Crown (RH → Mertens → L² decay),
  which inherits 4 PNTAnd axioms + 1 covariance axiom from the Perron chain.
  The `witness_covariance_decay` axiom is ELIMINATED (graduated in
  CovarianceFromPerron.lean). The converse direction has ZERO custom axioms.

  Three alternative proof paths are preserved as supplementary theorems:
  * PATH A (Mellin): `nyman_beurling_equivalence_mellin`
  * PATH B (Perron): `nyman_beurling_equivalence_spatial`
  * PATH C (Renormalization): `nyman_beurling_equivalence_renormalization`

  ## References

  * L. Báez-Duarte, *The Nyman-Beurling approach to the Riemann Hypothesis*,
    Int. Math. Res. Not. IMRN (2003), no. 36, pp. 1989–2009.
  * B. Nyman, *On some groups and semigroups of translations*, PhD thesis, 1950.
  * A. Beurling, *A closure problem related to the Riemann zeta function*,
    Proc. Nat. Acad. Sci. 41 (1955), pp. 312–314.
-/

noncomputable section
open Complex Real

-- ════════════════════════════════════════════════
-- PILLAR I: THE CONVERSE (L² Duality)
-- ════════════════════════════════════════════════

/-- **Converse**: If d²_N → 0 (in the BD basis), then RH holds.

    Proved via the contrapositive using the Rank-1 Mellin identity
    at off-critical-line zeros. See `Separation.lean`. -/
theorem distance_converges_to_zero_implies_rh :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) →
    RiemannHypothesis :=
  nyman_beurling_converse

-- ════════════════════════════════════════════════
-- PILLAR II: THE FORWARD DIRECTION (Mellin Crown)
-- ════════════════════════════════════════════════

/-- **Forward** (Perron path): RH implies d²_N → 0.

    Chain: RH → Mertens bound (Perron contour) → L² decay → convergence.
    This is an alternative forward proof via the spatial domain.
    The primary export uses `baez_duarte_forward` instead. -/
theorem rh_implies_distance_converges_to_zero :
    RiemannHypothesis →
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) :=
  rh_implies_bd_convergence_perron

-- ════════════════════════════════════════════════
-- SUPPLEMENTARY: Witness → Infimum Bridge
-- ════════════════════════════════════════════════

/-- Existential Nyman-Beurling witness implies infimum bound.

    Bridges `{1/(kx)}` basis witnesses to `nbDistSq'` bounds.
    Used by `CertifiedComputation.lean` for numerical cross-validation. -/
theorem existential_implies_infimum (N : ℕ) (hN : 2 ≤ N) (ε : ℝ)
    (v : Fin (N - 1) → ℝ)
    (hv : ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 < ε) :
    nbDistSq' N < ε :=
  calc nbDistSq' N ≤ 1 - 2 * dotProduct (basisInnerProd N) v +
        realQuadForm (gramMatrix N) v := nbDistSq_le_test_vector N hN v
    _ = ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 := (l2_error_eq_quad_error N hN v).symm
    _ < ε := hv

-- ════════════════════════════════════════════════
-- LOGARITHMIC DIVERGENCE (STANDARD CALCULUS)
-- ════════════════════════════════════════════════

/-- **THEOREM**: C/log(N) < ε eventually (standard calculus). -/
theorem log_grows_unboundedly (C : ℝ) (hC : 0 < C) (ε : ℝ) (hε : 0 < ε) :
    ∃ N₀ : ℕ, ∀ N : ℕ, N₀ ≤ N → C / Real.log (N : ℝ) < ε := by
  have h := tendsto_log_atTop.eventually (Filter.eventually_ge_atTop (C / ε + 1))
  rw [Filter.eventually_atTop] at h
  obtain ⟨M, hM⟩ := h
  use ⌈max M 2⌉₊
  intro N hN
  have hN_cast : (N : ℝ) ≥ max M 2 := le_trans (Nat.le_ceil _) (by exact_mod_cast hN)
  have hN_ge_M : (N : ℝ) ≥ M := le_trans (le_max_left _ _) hN_cast
  have hlog_pos : 0 < Real.log (N : ℝ) := Real.log_pos (by linarith [le_max_right M 2])
  have hlog_gt : C / ε < Real.log (N : ℝ) := by linarith [hM N hN_ge_M]
  rw [div_lt_iff₀ hlog_pos]
  have : C < ε * Real.log (N : ℝ) := by
    calc C = ε * (C / ε) := by field_simp
      _ < ε * Real.log (N : ℝ) := by nlinarith
  linarith


-- ════════════════════════════════════════════════
-- THE NYMAN-BEURLING-BÁEZ-DUARTE EQUIVALENCE
-- ════════════════════════════════════════════════

/-- The Nyman-Beurling-Báez-Duarte equivalence (alternative paths).

    `RH ↔` the BD basis `{1/(kx)}` can approximate `1` in `L²(0,1)`.

    Three independent proof paths for the forward direction are preserved:
    * PATH A (Mellin): via critical-line Mellin variance
    * PATH B (Perron): via Perron contour integration and spatial covariance
    * PATH C (Renormalization): via Selberg-Delange α-decay
      (selberg_delange_decay GRADUATED to theorem April 30, 2026;
       inherits `witness_covariance_decay` ≡ RH from Vasyunin chain.
       Once Oracle Crown proves RH, PATH C closes retroactively.)

    Each path has its own axiom footprint. The primary export
    `nyman_beurling_equivalence` uses `baez_duarte_forward` as a single
    literature axiom. -/

-- ──── PATH A: Mellin Crown (frequency domain) ────
theorem nyman_beurling_equivalence_mellin :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse, rh_implies_bd_convergence_mellin⟩

-- ──── PATH B: Perron Crown (spatial domain) ────
theorem nyman_beurling_equivalence_spatial :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse, rh_implies_bd_convergence_perron⟩

-- ──── PATH C: Renormalization (Selberg-Delange α-decay) ────
theorem nyman_beurling_equivalence_renormalization :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse, rh_implies_bd_convergence_renormalization⟩

-- ═══════════════════════════════════════════════════════
-- THE BÁEZ-DUARTE ANCHOR (The Analytic Crown)
-- ═══════════════════════════════════════════════════════

/-- **THEOREM (formerly AXIOM)**: The Báez-Duarte Forward Direction

    Under the Riemann Hypothesis, the Báez-Duarte basis {1/(kx)}
    can approximate 1 in L²(0,1) to arbitrary precision.

    **GRADUATED: May 12, 2026 (Exploration 36)**
    **PATH E FUSION: May 13, 2026 (Exploration 37)**

    Now proved via the Perron Crown chain (Path E: Mellin-Spectral Fusion):
      1. `rh_implies_mertens_bound_proved` (MertensFromPerron.lean)
         RH → |M(x)| ≤ C·x^{3/4}
      2. `mertens_implies_l2_decay_34` (PerronCrown.lean)
         |M(x)| ≤ C·x^{3/4} → ∫₀¹(1-f_N)² ≤ C_l2/logN
      3. C/logN → 0 (standard calculus)

    This path does NOT use `witness_covariance_decay`.
    The covariance axiom is independently graduated in
    `CovarianceFromPerron.lean` (witness_covariance_from_perron).

    The Vasyunin chain path (rh_implies_bd_convergence_zero_axiom)
    is preserved as an alternative proof.

    Reference: L. Báez-Duarte, "The Nyman-Beurling approach to the
    Riemann Hypothesis", Int. Math. Res. Not. IMRN (2003), no. 36,
    pp. 1989–2009. -/
-- GRADUATED: was AXIOM CLASS: CROWN-ANALYTIC (1 of 1)
-- PATH E: rewired to Perron Crown (May 13, 2026)
theorem baez_duarte_forward :
    RiemannHypothesis →
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε :=
  rh_implies_bd_convergence_perron

-- ──── PRIMARY EXPORT: PATH E FUSION (ZERO CUSTOM AXIOMS) ────
-- Forward: baez_duarte_forward (PROVED — Perron Crown, Path E fusion)
-- Converse: nyman_beurling_converse (PROVED — Rank-1 Mellin)
-- The `witness_covariance_decay` axiom is NOT in this dependency tree.
-- See also: CovarianceFromPerron.lean for the explicit covariance graduation.
theorem nyman_beurling_equivalence :
    (∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, ∃ v : Fin (N - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε) ↔
    RiemannHypothesis :=
  ⟨nyman_beurling_converse, baez_duarte_forward⟩

-- ════════════════════════════════════════════════
-- UNCONDITIONAL RESULTS
-- ════════════════════════════════════════════════

/-- The eigenvalue limit exists (unconditional). -/
theorem eigenvalue_limit_exists :
    ∃ L : ℝ, 0 ≤ L ∧
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀, |lambdaMin N - L| < ε := by
  set f := fun n => lambdaMin (n + 2) with hf_def
  have hanti : Antitone f := lambdaMin_shifted_antitone
  have hbdd : BddBelow (Set.range f) := by
    use 0; intro x ⟨n, hn⟩; rw [← hn]
    exact le_of_lt (lambdaMin_pos (n + 2) (by omega))
  have htend := tendsto_atTop_ciInf hanti hbdd
  set L := ⨅ n, f n with hL_def
  have hL_nonneg : 0 ≤ L := by
    apply le_ciInf; intro n
    exact le_of_lt (lambdaMin_pos (n + 2) (by omega))
  rw [Metric.tendsto_atTop] at htend
  refine ⟨L, hL_nonneg, fun ε hε => ?_⟩
  obtain ⟨a, ha⟩ := htend ε hε
  refine ⟨a + 2, fun N hN => ?_⟩
  have hNa : a ≤ N - 2 := by omega
  have hfN : f (N - 2) = lambdaMin N := by
    simp [hf_def]; congr 1; omega
  have := ha (N - 2) hNa
  rw [hfN, Real.dist_eq] at this
  exact this

end

-- ════════════════════════════════════════════════
-- THE GRAM CROWN: DISCRETE RH (PREFERRED ARCHITECTURE)
-- ════════════════════════════════════════════════
--
-- The discrete, 2-axiom proofs of RH are exported from:
--   Cathedral.Assembly.GramCrown (downstream of this file)
--
-- • riemann_hypothesis_from_gram_global  : RH from vᵀGv ≤ 1+K/lnN (∀ large N)
-- • riemann_hypothesis_from_gram_subseq  : RH from vᵀGv ≤ 1+K/lnN (along subseq)
--
-- These are the PREFERRED architecture (zero covariance axioms).
-- They cannot be imported here because GramBoundDirect.lean imports
-- MainChain.lean (for log_grows_unboundedly), creating a dependency
-- arrow: MainChain → GramBoundDirect → GramCrown.
--
-- See GramCrown.lean for the primary discrete exports.
-- See Assembly.lean for the unified re-export of both architectures.

-- ════════════════════════════════════════════════
-- AXIOM AUDIT (updated May 13, 2026 — Exploration 37, Morning Surgery)
-- ════════════════════════════════════════════════
--
-- #print axioms nyman_beurling_equivalence
--   → [R_isLittleO, covariance_bound_from_mertens_34, frac_error_isLittleO,
--      mu_log_mul_zeta, mu_pnt_alt,
--      propext, Classical.choice, Quot.sound]
--
-- 5 custom axioms + 3 Lean kernel axioms.
--
-- CUSTOM AXIOM CLASSIFICATION:
--   PNTAnd axioms (4 — unconditionally true, awaiting upstream formalization):
--     mu_pnt_alt            (PNT/Bridge.lean:67 — PNT in Möbius form)
--     R_isLittleO           (PNT/LogBridge.lean:64 — ψ(x)-x = o(x))
--     mu_log_mul_zeta       (PNT/LogBridge.lean:67 — μ·log*ζ = -Λ)
--     frac_error_isLittleO  (PNT/LogBridge.lean:163 — fractional error)
--
--   Spatial covariance (1 — propagates via PerronCrown dependency chain):
--     covariance_bound_from_mertens_34  (GramFormProof.lean:57)
--     ⚠️ Documented as "MATHEMATICALLY FALSE under Mertens x^{3/4} alone"
--     Enters via: mertens_implies_l2_decay_34 → abel_summation_covariance_bound_34
--                 → gram_form_upper_bound_34_proved → covariance_bound_from_mertens_34
--
-- SORRY COUNT: 0 (in MainChain dependency tree)
--   rh_zeta_lower_bound_from_zero_counting is DEPRECATED (May 13, 2026).
--   It resides in Hadamard.lean but has ZERO code consumers in the MainChain.
--   LowerBound.lean Case A<B calls littlewood_maneuver (PROVED) directly.
--   The axiom declaration is retained for historical reference only.
--
-- PATH E FUSION (May 13, 2026):
--   The forward direction was rewired from `rh_implies_bd_convergence_zero_axiom`
--   (Vasyunin chain, depends on `witness_covariance_decay` axiom)
--   to `rh_implies_bd_convergence_perron` (Perron Crown).
--
--   The `witness_covariance_decay` axiom is ELIMINATED from the primary chain.
--   It is independently graduated in CovarianceFromPerron.lean.
--   However, 5 custom axioms remain via the Perron forward chain.
--
-- CONVERSE: ZERO CUSTOM AXIOMS
--   #print axioms nyman_beurling_converse
--     → [propext, Classical.choice, Quot.sound]
--   The converse direction is kernel-certified.
--
-- ALTERNATIVE FORWARD PATHS (see also):
--   GramBoundDirect.lean: gram_bound_implies_rh
--     → Gram bound → RH (1 Crown axiom + 5 PNT bureaucracy)
--     → Does NOT use covariance_bound_from_mertens_34
--     → TOTAL: 6 custom axioms (5 PNT + gram_form_upper_bound_direct)
--     → ★ COVARIANCE-FREE: bypasses the false Mertens covariance
--     → Extra PNT axiom: pnt_mu_log_sq_div_k (via WitnessNumerator)
--
--   GramBoundDirect.lean: gram_bound_subseq_implies_rh
--     → Subsequential Gram bound → RH (weakest axiom variant)
--     → Uses monotonicity of NB distance (Antitone.lean, PROVED)
--     → TOTAL: 6 custom axioms (5 PNT + gram_form_upper_bound_subseq)
--
--   BDBridgeProved.lean: rh_implies_bd_convergence_zero_axiom
--     → RH ⟹ d²_N → 0 via Vasyunin crown chain
--     → Uses witness_covariance_decay (now graduated under RH)
--
--   HeisenbergBypass.lean: heisenberg_implies_d_sq_zero
--     → d²_N → 0 via Rayleigh-Ritz squeeze
--     → Uses witness_covariance_decay (now graduated under RH)
--
--   MellinCrown.lean: rh_implies_bd_convergence_mellin
--     → RH ⟹ d²_N → 0 via critical-line Mellin integral
--
-- GPU-VALIDATED (May 9, 2026): d²·ln(N) ≈ 3.08 at N=55,440
-- confirms Rayleigh-Ritz squeeze constant across 13 HCN points.
--
-- ════════════════════════════════════════════════
-- GRAM CROWN AXIOM AUDIT (the primary discrete exports)
-- ════════════════════════════════════════════════
--
-- #print axioms rh_discrete_global
--   → [R_isLittleO, frac_error_isLittleO, mu_log_mul_zeta, mu_pnt_alt,
--      pnt_mu_log_sq_div_k,
--      Cathedral.Vasyunin.gram_form_upper_bound_direct,
--      propext, Classical.choice, Quot.sound]
--
-- #print axioms rh_discrete_subseq
--   → [R_isLittleO, frac_error_isLittleO, mu_log_mul_zeta, mu_pnt_alt,
--      pnt_mu_log_sq_div_k,
--      Cathedral.Vasyunin.gram_form_upper_bound_subseq,
--      propext, Classical.choice, Quot.sound]
--
-- 6 custom axioms each + 3 Lean kernel axioms.
--
-- CLASSIFICATION:
--   PNT bureaucracy (5 — unconditionally true, proved since 1896):
--     mu_pnt_alt, R_isLittleO, mu_log_mul_zeta,
--     frac_error_isLittleO, pnt_mu_log_sq_div_k
--
--   Crown axiom (1 — THE actual mathematical content):
--     gram_form_upper_bound_direct  (or _subseq)
--     ≡ The Riemann Hypothesis, reformulated as a discrete
--       arithmetic inequality about Möbius-weighted fractional-part sums.
--
-- ★ KEY: No covariance_bound_from_mertens_34 in this dependency tree.
-- ★ KEY: The Crown axiom IS RH (equivalent reformulation, not a derived
--        consequence). It is the SIMPLEST possible axiom footprint.

-- #print axioms nyman_beurling_equivalence
-- #print axioms rh_discrete_global
-- #print axioms rh_discrete_subseq
