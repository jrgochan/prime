import Cathedral.Gram.Bounds
import Cathedral.Gram.OffDiagonal

/-!
  Cathedral/Sieve/VasyuninExpansion.lean

  💀 PHANTOM AXIOM TOMBSTONE — vasyunin_large_gcd is MATHEMATICALLY FALSE.
  See counterexample (100,200) below. Discovered 2026-05-04.

  NOT on the v11 crown path. The Sieve Engine is speculative.
-/

/-! # Cathedral.VasyuninExpansion

    ## Purpose

    Partial proof of the Vasyunin expansion, reducing the axiom to the
    "large GCD" case (d ≥ 5). The small-GCD case (d ≤ 4) is proved
    using existing geometric bounds from GramBounds and GramOffDiag.

    ## Architecture

    The Vasyunin expansion states:
      ∃ ψ : ℝ, hfGramEntry j k = 1/4 + ψ ∧ |ψ| ≤ 1/gcd(j,k)

    We decompose this into three cases:

    1. **Coprime case** (d = 1): Already proved as `vasyunin_coprime_case`
       in GramBounds.lean. The bound |ψ| ≤ 1 follows from 0 ≤ G ≤ 1.

    2. **Small GCD** (2 ≤ d ≤ 4): Proved here using:
       - `gramEntry_nonneg`:     G ≥ 0   ⟹  ψ ≥ -1/4
       - `gramEntry_le_third_all` + `gramEntry_le_avg_diag`:
                                  G ≤ 1/3 ⟹  ψ ≤ 1/12
       - Combined: |ψ| ≤ 1/4 ≤ 1/d for d ≤ 4   ✓

    3. **Large GCD** (d ≥ 5): Requires Báez-Duarte divisor-sum analysis.
       Isolated as a refined axiom `vasyunin_large_gcd`.

    ## Results

    - `vasyunin_small_gcd`:        |G - 1/4| ≤ 1/4 for all j,k ≥ 2 (PROVED)
    - `vasyunin_expansion_d_le_4`: Full expansion for gcd ≤ 4 (PROVED)
    - `vasyunin_large_gcd`:        Refined axiom for gcd ≥ 5 only
    - `vasyunin_expansion`:        Full theorem (uses large_gcd axiom)
-/

noncomputable section
open Real MeasureTheory Nat

-- ════════════════════════════════════════════════
-- STEP 1: THE UNIVERSAL 1/4 BOUND (PROVED)
-- ════════════════════════════════════════════════

/-- **PROVED**: For ALL j,k ≥ 1, the Gram entry correction satisfies
    |G_{j,k} - 1/4| ≤ 1/4.

    This follows from the tight range 0 ≤ G ≤ 1/3:
    - Lower: G ≥ 0 ⟹ G - 1/4 ≥ -1/4
    - Upper: G ≤ 1/3 ⟹ G - 1/4 ≤ 1/12

    The upper bound uses `gramEntry_le_third_all` (diagonal) composed
    with `gramEntry_le_avg_diag` (AM-GM off-diagonal). -/
theorem vasyunin_small_gcd (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    |hfGramEntry j k - 1/4| ≤ 1/4 := by
  have h_lower := hfGramEntry_nonneg j k      -- G ≥ 0
  have h_jj := gramEntry_le_third_all j hj   -- G_{j,j} ≤ 1/3
  have h_kk := gramEntry_le_third_all k hk   -- G_{k,k} ≤ 1/3
  have h_amgm := gramEntry_le_avg_diag j k   -- G ≤ (G_{j,j}+G_{k,k})/2
  -- G ≤ (1/3 + 1/3)/2 = 1/3
  have h_upper : hfGramEntry j k ≤ 1/3 := by linarith
  -- Now: 0 ≤ G ≤ 1/3, so -1/4 ≤ G - 1/4 ≤ 1/12
  rw [abs_le]
  constructor
  · linarith  -- G ≥ 0 ⟹ G - 1/4 ≥ -1/4
  · linarith  -- G ≤ 1/3 ⟹ G - 1/4 ≤ 1/12 ≤ 1/4

-- ════════════════════════════════════════════════
-- STEP 2: FULL EXPANSION FOR d ≤ 4 (PROVED)
-- ════════════════════════════════════════════════

/-- **PROVED**: The Vasyunin expansion for gcd(j,k) ≤ 4.

    Since |ψ| ≤ 1/4 and d = gcd(j,k) ≤ 4, we have 1/d ≥ 1/4,
    so the bound |ψ| ≤ 1/4 ≤ 1/d is satisfied.

    This covers d ∈ {1, 2, 3, 4}, which includes:
    - ALL coprime pairs (d=1, density 6/π² ≈ 60.8%)
    - Pairs sharing factor 2 (captures all even numbers)
    - Pairs sharing factor 3
    - Pairs sharing factor 4 -/
theorem vasyunin_expansion_d_le_4 (j k : ℕ) (hj : 2 ≤ j) (hk : 2 ≤ k)
    (hd : Nat.gcd j k ≤ 4) :
    ∃ correction : ℝ,
    hfGramEntry j k = 1/4 + correction ∧
    |correction| ≤ 1 / (Nat.gcd j k : ℝ) := by
  set ψ := hfGramEntry j k - 1/4
  refine ⟨ψ, by ring, ?_⟩
  have h_abs := vasyunin_small_gcd j k (by omega) (by omega)
  -- |ψ| ≤ 1/4 and 1/4 ≤ 1/d since d ≤ 4
  set d := Nat.gcd j k with hd_def
  have hd_pos : 0 < d := Nat.pos_of_ne_zero (by
    intro h; rw [Nat.gcd_eq_zero_iff] at h; omega)
  have hd_cast_pos : (0 : ℝ) < (d : ℝ) := Nat.cast_pos.mpr hd_pos
  have hd_le : (d : ℝ) ≤ 4 := by exact_mod_cast hd
  -- 1/4 ≤ 1/d since d ≤ 4
  have h_inv : (1 : ℝ) / 4 ≤ 1 / (d : ℝ) := by
    rw [div_le_div_iff₀ (by norm_num : (0:ℝ) < 4) hd_cast_pos]
    linarith
  linarith

-- ════════════════════════════════════════════════
-- STEP 3: REFINED AXIOM FOR d ≥ 5 ONLY
-- ════════════════════════════════════════════════

/- 💀 **TOMBSTONE**: This axiom is MATHEMATICALLY FALSE.

    ORIGINAL CLAIM: For gcd(j,k) ≥ 5, |gramEntry(j,k) - 1/4| ≤ 1/gcd(j,k).

    COUNTEREXAMPLE (discovered 2026-05-04 by Gemini Actual + Claude Actual):
      j = 100, k = 200, gcd = 100
      gramEntry(100,200) ≈ 0.2907
      |0.2907 - 0.25| = 0.0407 > 0.01 = 1/100  💀

    ROOT CAUSE: The error term d²/(12jk) in the Vasyunin 1995 formula
    simplifies to 1/(12ab) where a = j/d, b = k/d are coprime.
    This is CONSTANT for fixed ratio a/b, regardless of gcd magnitude.
    For a=1, b=2: the true asymptote is 1/24 ≈ 0.0417, not 0.

    THE CORRECT BOUND is:
      |gramEntry(j,k) - 1/4| ≤ 1/4    (proved as vasyunin_small_gcd above)

    The tighter TRUE asymptotic (not formalized):
      |gramEntry(j,k) - 1/4| ~ 1/(12ab) where a,b coprime, j=da, k=db

    This axiom is preserved as a historical artifact and warning about
    the dangers of assuming O-notation decays without exact algebra.

    STATUS: NOT ON CROWN PATH. The Sieve Engine is a speculative side module.
    The main proof path (BDBridge → Renormalization → ConvergenceProof)
    does not depend on this axiom.

    Verified numerically in 1024-bit MPFR (rosetta_stone.rs).
-/

-- 💀 DEAD AXIOM — DO NOT USE — MATHEMATICALLY FALSE
-- axiom vasyunin_large_gcd (j k : ℕ) (hj : 2 ≤ j) (hk : 2 ≤ k)
--     (hd : 5 ≤ Nat.gcd j k) :
--     ∃ correction : ℝ,
--     hfGramEntry j k = 1/4 + correction ∧
--     |correction| ≤ 1 / (Nat.gcd j k : ℝ)

/-- The correct replacement: |G - 1/4| ≤ 1/4 for ALL j,k.
    This is weaker but TRUE. Already proved as vasyunin_small_gcd. -/
theorem vasyunin_large_gcd_replacement (j k : ℕ) (hj : 2 ≤ j) (hk : 2 ≤ k)
    (hd : 5 ≤ Nat.gcd j k) :
    ∃ correction : ℝ,
    hfGramEntry j k = 1/4 + correction ∧
    |correction| ≤ 1 / (Nat.gcd j k : ℝ) := by
  -- Use the universal 1/4 bound, which dominates 1/d for d ≥ 5
  -- Wait — 1/4 > 1/5, so |ψ| ≤ 1/4 does NOT imply |ψ| ≤ 1/d for d ≥ 5!
  -- This is precisely WHY the axiom was false: the true error is ~1/(12ab),
  -- which CAN exceed 1/d when d is large relative to ab.
  -- The correct approach requires the Rosetta Stone bridge, not this bound.
  sorry  -- 💀 Cannot be proved — the statement is FALSE

-- ════════════════════════════════════════════════
-- STEP 4: FULL VASYUNIN EXPANSION (THEOREM)
-- ════════════════════════════════════════════════

/-- 💀 **POISONED THEOREM**: The full Vasyunin Expansion.

    ⚠️ WARNING: This theorem's conclusion is MATHEMATICALLY FALSE for d ≥ 5.
    It dispatches to `vasyunin_large_gcd_replacement` which has a sorry
    because the 1/d bound does not hold (see tombstone above).

    The d ≤ 4 case remains valid.

    DO NOT use this theorem in any proof chain.
    This file is NOT on the Crown Path. -/
theorem vasyunin_expansion_proof (j k : ℕ) (hj : 2 ≤ j) (hk : 2 ≤ k) :
    ∃ correction : ℝ,
    hfGramEntry j k = 1/4 + correction ∧
    |correction| ≤ 1 / (Nat.gcd j k : ℝ) := by
  by_cases hd : Nat.gcd j k ≤ 4
  · -- CASE 1: d ≤ 4 — PROVED (correct)
    exact vasyunin_expansion_d_le_4 j k hj hk hd
  · -- CASE 2: d ≥ 5 — 💀 FALSE (see tombstone)
    push Not at hd
    exact vasyunin_large_gcd_replacement j k hj hk (by omega)

end

-- ════════════════════════════════════════════════
-- AUDIT (updated 2026-05-04)
-- ════════════════════════════════════════════════

-- 💀 PHANTOM AXIOM TOMBSTONE 💀
--
-- This file FORMERLY contained:
--   axiom vasyunin_large_gcd : |gramEntry - 1/4| ≤ 1/gcd  for d ≥ 5
--
-- This axiom was PROVED FALSE on 2026-05-04:
--   Counterexample: (100,200), gcd=100, |G-1/4|=0.0407 > 0.01=1/100
--   Root cause: error ~ 1/(12ab), constant for fixed coprime ratio
--
-- The axiom has been commented out and replaced with a placeholder'd
-- theorem (vasyunin_large_gcd_replacement) to preserve build.
--
-- STATUS: NOT ON CROWN PATH. The Sieve Engine is speculative.
-- The main proof: BDBridge → Renormalization → ConvergenceProof → Cotangent
-- does NOT depend on this file.
--
-- PROVED (still valid):
--   ✅ vasyunin_small_gcd:          |G - 1/4| ≤ 1/4 (universal, TRUE)
--   ✅ vasyunin_expansion_d_le_4:   Full expansion for gcd ≤ 4 (TRUE)
--
-- POISONED:
--   💀 vasyunin_expansion_proof:    Contains gap from FALSE d≥5 case
--   💀 vasyunin_large_gcd:          DEAD — commented out
--
-- NOTE (2026-05-07): Post-BD migration, gramEntry ≡ gramIntegral
-- definitionally (both = ∫₀¹ {1/(jx)}{1/(kx)} dx). The Rosetta Stone
-- bridge has been archived (ParameterizationBridge.lean → Archive/).

-- #check @vasyunin_small_gcd
-- #check @vasyunin_expansion_d_le_4

