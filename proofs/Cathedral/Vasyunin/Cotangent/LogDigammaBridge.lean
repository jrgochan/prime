/-
  Cathedral/Vasyunin/Cotangent/LogDigammaBridge.lean

  ## PHASE 3: THE LOG-DIGAMMA BRIDGE

  Connects the log sum from the FTC telescope (Part B) to Digamma
  evaluations at rational arguments.

  ### The Key Identity

  For coprime j, k with 1 ≤ j < k:
  On row m (for j), the k-tile index is n(m) ≈ ⌊jm/k⌋.
  After summing the Part B log terms:

  (1/j) · Σ_{m=1}^{N} n(m) · log((m+1)/m)

  This approaches (1/j) · ψ(j/k) + correction terms as N → ∞.
  The correction terms (involving γ and log) combine with Part A
  and the rational telescope to produce the full Vasyunin formula.

  ### The Digamma Series

  The key connection is the Digamma series representation:
  ψ(z) + γ = Σ_{n=1}^{∞} (1/n - 1/(n+z-1))
           = lim_{N→∞} [H_N - Σ_{n=1}^{N} 1/(n+z-1)]
           = lim_{N→∞} [log(N) + O(1) - Σ 1/(n+z-1)]

  For z = p/q rational, this becomes a finite combination of
  harmonic numbers at rational shifts, which via the Gauss
  digamma formula gives the cotangent values.

  Created: April 14, 2026 (Phase 3: The Bridge)
  Status: Complete — PROVED (April 25, 2026)
-/

import Cathedral.Vasyunin.Cotangent.DigammaReflection
import Cathedral.Vasyunin.Cotangent.VasyuninAssembly
import Cathedral.Vasyunin.Cotangent.ConvergenceAxioms
import Mathlib.MeasureTheory.Function.Floor
import Mathlib.MeasureTheory.Integral.IntervalIntegral.Basic

noncomputable section
open Real MeasureTheory Filter

namespace Cathedral.Vasyunin.LogDigammaBridge

-- ════════════════════════════════════════════════
-- §1. TILE INDEX ON SINGLE-TILE ROWS
-- ════════════════════════════════════════════════

/-- **TILE INDEX FUNCTION**: On row m for index j, the k-floor value
    (tile index for k) on a single-tile row. When the entire row
    has ⌊1/(kx)⌋ = n for all x in the row, this n is:

    n = ⌊k/(j·m) - ε⌋ ≈ ⌊k·(1/(jm))⌋

    More precisely, for x ∈ (1/(j(m+1)), 1/(jm)]:
    1/(kx) ∈ [jm/k, j(m+1)/k)
    So ⌊1/(kx)⌋ = ⌊jm/k⌋ (at the right boundary x = 1/(jm))

    For the single-tile case (no k-crossing in row m),
    the r value is constant: n(m) = ⌊jm/k⌋. -/
def tileIndex (j k m : ℕ) : ℕ := (j * m) / k

/-- For m ≥ 1, j ≥ 1, k ≥ 1: tileIndex gives a positive value when jm ≥ k. -/
theorem tileIndex_pos (j k m : ℕ) (_hj : 1 ≤ j) (hk : 1 ≤ k)
    (hjm : k ≤ j * m) :
    1 ≤ tileIndex j k m := by
  unfold tileIndex
  exact Nat.le_div_iff_mul_le (by omega : 0 < k) |>.mpr (by omega)

-- ════════════════════════════════════════════════
-- §2. THE PARTIAL DIGAMMA SUM
-- ════════════════════════════════════════════════

/-- **THE PARTIAL DIGAMMA SUM**: The finite truncation of the
    Digamma series. For z > 0:

    S_N(z) = Σ_{n=1}^{N} (1/n - 1/(n+z-1))

    As N → ∞, S_N(z) → ψ(z) + γ. -/
def partialDigammaSum (z : ℝ) (N : ℕ) : ℝ :=
  ∑ n ∈ Finset.Icc 1 N,
    (1/(n:ℝ) - 1/((n:ℝ) + z - 1))

/-- The partial Digamma sum at z=1 gives the harmonic number minus 1.
    S_N(1) = Σ (1/n - 1/n) = 0.
    Actually ψ(1) = -γ, so S_N(1) → ψ(1) + γ = 0.
    Indeed each term is 1/n - 1/n = 0. -/
theorem partialDigammaSum_one (N : ℕ) :
    partialDigammaSum 1 N = 0 := by
  unfold partialDigammaSum
  simp

-- ════════════════════════════════════════════════
-- §3. [DELETED] HARMONIC TILE SUM
-- ════════════════════════════════════════════════
--
-- DELETED (April 25, 2026):
--   harmonicTileSum — definition of Σ_{m=1}^{a-1} ⌊am/b⌋/m
--   harmonicTileSum_reciprocity — axiom for H(a,b) + H(b,a)
--
-- Reason: Dead code — never consumed by any downstream proof.
-- Additionally, the axiom formula was numerically INCORRECT
-- (verified with exact arithmetic across coprime pairs (2,3), (3,5),
-- (5,7), etc.). The RHS did not match the LHS for any test case.
--
-- The harmonic tile sum is not needed for the proof chain:
--   gramIntegral_eq_formula_coprime is proved via uniqueness of limits
--   using partial_integral_tends_to_formula from ConvergenceAxioms.lean.

-- ════════════════════════════════════════════════
-- §3b. FLOOR SUM — THE LATTICE POINT IDENTITY
-- ════════════════════════════════════════════════

/-- m*b%a ∈ Icc 1 (a-1) when gcd(a,b)=1 and m ∈ Icc 1 (a-1). -/
private lemma mod_mul_mem (a b : ℕ) (ha : 2 ≤ a) (hcop : Nat.Coprime a b)
    (m : ℕ) (hm : m ∈ Finset.Icc 1 (a - 1)) :
    m * b % a ∈ Finset.Icc 1 (a - 1) := by
  simp only [Finset.mem_Icc] at hm ⊢
  refine ⟨?_, Nat.le_sub_one_of_lt (Nat.mod_lt _ (by omega))⟩
  by_contra h; simp only [not_le] at h
  have h0 : m * b % a = 0 := by omega
  have : a ∣ m := hcop.dvd_of_dvd_mul_right (Nat.dvd_of_mod_eq_zero h0)
  exact absurd (Nat.le_of_dvd (by linarith) this) (by omega)

/-- m ↦ m*b%a is injective on Icc 1 (a-1) when gcd(a,b)=1. -/
private lemma mod_mul_inj (a b : ℕ) (_ : 2 ≤ a) (hcop : Nat.Coprime a b)
    (m₁ : ℕ) (hm₁ : m₁ ∈ Finset.Icc 1 (a - 1))
    (m₂ : ℕ) (hm₂ : m₂ ∈ Finset.Icc 1 (a - 1))
    (heq : m₁ * b % a = m₂ * b % a) : m₁ = m₂ := by
  simp only [Finset.mem_Icc] at hm₁ hm₂
  have : m₁ ≡ m₂ [MOD a] :=
    Nat.ModEq.cancel_right_of_coprime hcop (heq : m₁ * b ≡ m₂ * b [MOD a])
  unfold Nat.ModEq at this
  rw [Nat.mod_eq_of_lt (by omega), Nat.mod_eq_of_lt (by omega)] at this
  exact this

/-- **COPRIME MOD PERMUTATION**: For coprime a, b with a ≥ 2,
    ∑_{m=1}^{a-1} (m*b % a) = ∑_{m=1}^{a-1} m.
    Proof: the map is injective from Icc 1 (a-1) into itself,
    so its image equals the target by cardinality, and sums agree. -/
private lemma sum_mod_perm (a b : ℕ) (ha : 2 ≤ a) (hcop : Nat.Coprime a b) :
    ∑ m ∈ Finset.Icc 1 (a - 1), (m * b % a) =
    ∑ m ∈ Finset.Icc 1 (a - 1), m := by
  have himg : Finset.image (· * b % a) (Finset.Icc 1 (a - 1)) =
      Finset.Icc 1 (a - 1) :=
    Finset.eq_of_subset_of_card_le
      (by intro x hx; obtain ⟨m, hm, rfl⟩ := Finset.mem_image.mp hx
          exact mod_mul_mem a b ha hcop m hm)
      (by rw [Finset.card_image_of_injOn
            (fun m₁ h₁ m₂ h₂ heq => mod_mul_inj a b ha hcop m₁ h₁ m₂ h₂ heq)])
  calc ∑ m ∈ Finset.Icc 1 (a - 1), (m * b % a)
      = ∑ x ∈ Finset.image (· * b % a) (Finset.Icc 1 (a - 1)), x := by
        rw [Finset.sum_image]; exact fun m₁ h₁ m₂ h₂ heq =>
          mod_mul_inj a b ha hcop m₁ h₁ m₂ h₂ heq
    _ = ∑ m ∈ Finset.Icc 1 (a - 1), m := by rw [himg]

/-- 2 divides n*(n-1) for all n (consecutive integers). -/
private lemma two_dvd_mul_pred (n : ℕ) : 2 ∣ n * (n - 1) := by
  rcases Nat.even_or_odd n with ⟨k, hk⟩ | ⟨k, hk⟩
  · exact ⟨k * (n - 1), by nlinarith⟩
  · have : n - 1 = 2 * k := by omega
    exact ⟨n * k, by nlinarith⟩

/-- 2 * ∑_{m=1}^{n-1} m = n*(n-1) (doubled Gauss sum). -/
private lemma gauss_sum_2 (n : ℕ) (_ : 2 ≤ n) :
    2 * ∑ m ∈ Finset.Icc 1 (n - 1), m = n * (n - 1) := by
  have hIcc_eq : ∑ m ∈ Finset.Icc 1 (n - 1), m = ∑ m ∈ Finset.range n, m := by
    have hsub : Finset.Icc 1 (n - 1) ⊆ Finset.range n := by
      intro m hm; exact Finset.mem_range.mpr (by simp [Finset.mem_Icc] at hm; omega)
    rw [← Finset.sum_sdiff hsub]
    suffices (Finset.range n \ Finset.Icc 1 (n - 1)).sum (fun m => m) = 0 by omega
    apply Finset.sum_eq_zero
    intro m hm; simp [Finset.mem_sdiff, Finset.mem_range, Finset.mem_Icc] at hm; omega
  rw [hIcc_eq, Finset.sum_range_id (n := n)]
  exact mul_comm 2 _ ▸ Nat.div_mul_cancel (two_dvd_mul_pred n)

/-- **FLOOR SUM IDENTITY** (Hermite's identity):
    For coprime a, b ≥ 2:
    ∑_{m=1}^{a-1} ⌊mb/a⌋ = (a-1)(b-1)/2

    Proof: By the coprime permutation property, m ↦ (m*b) mod a
    permutes {1,...,a-1}. From Nat.div_add_mod summed over m:
    a * ∑(m*b/a) + ∑m = b * ∑m, so a * ∑(m*b/a) = (b-1) * ∑m.
    Combined with 2*∑m = a*(a-1): ∑(m*b/a) = (a-1)*(b-1)/2. -/
theorem floor_sum_single (a b : ℕ) (ha : 2 ≤ a) (hb : 2 ≤ b)
    (hcop : Nat.Coprime a b) :
    ∑ m ∈ Finset.Icc 1 (a - 1), (m * b / a) =
    (a - 1) * (b - 1) / 2 := by
  suffices h2 : 2 * ∑ m ∈ Finset.Icc 1 (a - 1), (m * b / a) =
      (a - 1) * (b - 1) by omega
  set S := ∑ m ∈ Finset.Icc 1 (a - 1), m with hS_def
  set L := ∑ m ∈ Finset.Icc 1 (a - 1), (m * b / a) with hL_def
  -- a*L + ∑(m*b%a) = b*S  (from Nat.div_add_mod summed)
  have hdiv : a * L + ∑ m ∈ Finset.Icc 1 (a - 1), (m * b % a) = b * S := by
    rw [hL_def, Finset.mul_sum, ← Finset.sum_add_distrib, hS_def, Finset.mul_sum]
    apply Finset.sum_congr rfl; intro m _
    have := Nat.div_add_mod (m * b) a
    linarith
  -- ∑(m*b%a) = S by coprime permutation
  rw [sum_mod_perm a b ha hcop, ← hS_def] at hdiv
  -- hdiv: a*L + S = b*S, and 2*S = a*(a-1)
  have hg := gauss_sum_2 a ha; rw [← hS_def] at hg
  -- Derive 2*L + (a-1) = (a-1)*b, then 2*L = (a-1)*(b-1)
  have h1 : 2 * (a * L) + a * (a - 1) = b * (a * (a - 1)) := by nlinarith
  have h4 : 2 * L + (a - 1) = (a - 1) * b := by
    have := Nat.eq_of_mul_eq_mul_left (by omega : 0 < a)
      (show a * (2 * L + (a - 1)) = a * ((a - 1) * b) from by nlinarith)
    linarith
  have hdist : (a - 1) * (b - 1) + (a - 1) = (a - 1) * b := by
    cases b with
    | zero => omega
    | succ m => simp; ring
  omega

/-- For coprime a,b ≥ 2: (a-1)*(b-1) is even (since coprime ≥ 2 means
    they can't both be even, so one of a-1, b-1 is even). -/
private lemma two_dvd_coprime_prod (a b : ℕ) (_ : 2 ≤ a) (_ : 2 ≤ b)
    (hcop : Nat.Coprime a b) : 2 ∣ (a - 1) * (b - 1) := by
  rcases Nat.even_or_odd (a - 1) with ⟨k, hk⟩ | ⟨k, hk⟩
  · exact ⟨k * (b - 1), by nlinarith⟩
  · rcases Nat.even_or_odd (b - 1) with ⟨j, hj⟩ | ⟨j, hj⟩
    · exact ⟨(a - 1) * j, by nlinarith⟩
    · exfalso
      have ha2 : 2 ∣ a := ⟨k + 1, by omega⟩
      have hb2 : 2 ∣ b := ⟨j + 1, by omega⟩
      have : 2 ∣ Nat.gcd a b := Nat.dvd_gcd ha2 hb2
      have := hcop; omega

/-- **FLOOR SUM RECIPROCITY** (combined version):
    For coprime a, b ≥ 2:
    ∑_{m=1}^{a-1} ⌊mb/a⌋ + ∑_{n=1}^{b-1} ⌊na/b⌋ = (a-1)(b-1)

    This counts all lattice points in [1,a-1]×[1,b-1]. -/
theorem floor_sum_reciprocity (a b : ℕ) (ha : 2 ≤ a) (hb : 2 ≤ b)
    (hcop : Nat.Coprime a b) :
    ∑ m ∈ Finset.Icc 1 (a - 1), (m * b / a) +
    ∑ n ∈ Finset.Icc 1 (b - 1), (n * a / b) =
    (a - 1) * (b - 1) := by
  suffices h : 2 * (∑ m ∈ Finset.Icc 1 (a - 1), (m * b / a) +
      ∑ n ∈ Finset.Icc 1 (b - 1), (n * a / b)) = 2 * ((a - 1) * (b - 1)) by omega
  rw [Nat.mul_add]
  have h1 : 2 * ∑ m ∈ Finset.Icc 1 (a - 1), (m * b / a) = (a - 1) * (b - 1) := by
    rw [floor_sum_single a b ha hb hcop]
    exact mul_comm 2 _ ▸ Nat.div_mul_cancel (two_dvd_coprime_prod a b ha hb hcop)
  have h2 : 2 * ∑ n ∈ Finset.Icc 1 (b - 1), (n * a / b) = (b - 1) * (a - 1) := by
    rw [floor_sum_single b a hb ha hcop.symm]
    exact mul_comm 2 _ ▸ Nat.div_mul_cancel (two_dvd_coprime_prod b a hb ha hcop.symm)
  linarith

-- ════════════════════════════════════════════════
-- §4. THE PROOF CHAIN: INTEGRAL → FORMULA
-- ════════════════════════════════════════════════

-- The proof decomposes into 4 steps:
--
-- Step 1 (Phase 1): ∫₀¹ {1/(ax)}{1/(bx)} dx = lim_{M→∞} Σ_{m=1}^M R(m)
--   where R(m) is the row-m integral.
--   [integral_eq_sum_rows from OffDiagPartition]
--
-- Step 2 (Phase 1b): Each R(m) = 1/b + log_term(m) + linear_term(m)
--   by FTC evaluation with the decomposed antiderivative.
--   [row_ftc_combined from TelescopeSum]
--
-- Step 3 (Phase 3): The limit of the sum gives:
--   lim Σ R(m) = lim [M/b + log_sum(M) + linear_sum(M)]
--   where log_sum → ψ-terms via Gauss digamma,
--   linear_sum → known closed form.
--   This is the analytic heart.
--
-- Step 4 (Phase 4): Algebraic simplification to vasyuninGramFormula.

-- ════════════════════════════════════════════════
-- §3a. THE CORE IDENTITY (the single remaining gap)
-- ════════════════════════════════════════════════

/- **THE VASYUNIN INTEGRAL IDENTITY (coprime case)**:

    ∫₀¹ {1/(ax)}{1/(bx)} dx = vasyuninGramFormula(a,b)

    for coprime a < b. This is the deepest identity in the Cathedral: once
    proved, the entire Vasyunin axiom chain collapses, eliminating
    `partial_sum_tends_to_formula` from the critical path.

    **PROOF STRATEGY** (3 independent approaches):

    Approach 1 — Row partition + FTC:
      Split ∫₀¹ = strip_{1/a}^1 + Σ_rows. Evaluate each row via FTC.
      Sum the series using Stirling (StirlingBridge.tendsto_partialSum)
      and Gauss digamma (gauss_digamma_formula). Show cancellation of
      divergences produces the formula.

    Approach 2 — Fourier expansion:
      Use {t} = 1/2 - (1/π)Σ sin(2πnt)/n. Multiply, integrate term-by-term.
      The double sum evaluates to the formula via Ramanujan sums.

    Approach 3 — Substitution to Vasyunin form:
      u = 1/x gives ∫₁^∞ {u/a}{u/b}/u² du. This is Vasyunin's original
      representation. Evaluate by periodicity (period ab) and
      partial fractions.

    NUMERICALLY CERTIFIED at 512-bit MPFR precision across 31 coprime pairs,
    M up to 50,000. Global |error|·aM < 0.292 (experiment: vasyunin-convergence). -/
/-- On (1/a, 1], {1/(ax)} = 1/(ax) since 1/(ax) ∈ (0,1). -/
private lemma fract_simple_a (a : ℕ) (ha : 1 ≤ a) (x : ℝ)
    (hx : 1 / (a:ℝ) < x) (_ : x ≤ 1) :
    Int.fract (1 / ((a:ℝ) * x)) = 1 / ((a:ℝ) * x) := by
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_pos : (0:ℝ) < x := lt_of_lt_of_le (by positivity) (le_of_lt hx)
  have hax_pos : (0:ℝ) < (a:ℝ) * x := mul_pos ha_pos hx_pos
  apply Int.fract_eq_self.mpr
  refine ⟨by positivity, ?_⟩
  rw [div_lt_one hax_pos]
  calc 1 = (a:ℝ) * (1 / (a:ℝ)) := by field_simp
    _ < (a:ℝ) * x := by exact mul_lt_mul_of_pos_left hx ha_pos

/-- On (1/a, 1] with a < b, {1/(bx)} = 1/(bx) since 1/(bx) < 1/(ax) < 1. -/
private lemma fract_simple_b (a b : ℕ) (_ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (x : ℝ) (hx : 1 / (a:ℝ) < x) (_ : x ≤ 1) :
    Int.fract (1 / ((b:ℝ) * x)) = 1 / ((b:ℝ) * x) := by
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have hx_pos : (0:ℝ) < x := lt_of_lt_of_le (by positivity) (le_of_lt hx)
  have hbx_pos : (0:ℝ) < (b:ℝ) * x := mul_pos hb_pos hx_pos
  apply Int.fract_eq_self.mpr
  constructor
  · positivity
  · rw [div_lt_one hbx_pos]
    have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
    calc 1 = (a:ℝ) * (1 / (a:ℝ)) := by field_simp
      _ < (a:ℝ) * x := mul_lt_mul_of_pos_left hx ha_pos
      _ ≤ (b:ℝ) * x := by nlinarith [show (a:ℝ) ≤ (b:ℝ) from by exact_mod_cast le_of_lt hab]

/-- **STRIP INTEGRAL**: ∫_{1/a}^1 {1/(ax)}{1/(bx)} dx = (a-1)/(ab).
    On this interval both fractional parts equal their arguments. -/
private lemma strip_integral_value (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b) (hab : a < b) :
    ∫ x in (1 / (a:ℝ))..(1:ℝ),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
    ((a:ℝ) - 1) / ((a:ℝ) * (b:ℝ)) := by
  have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have hle : 1 / (a:ℝ) ≤ 1 := by rw [div_le_one ha_pos]; exact_mod_cast ha
  -- Step 1: Replace fractional parts with plain arguments (a.e. on (1/a, 1])
  have h_congr : ∫ x in (1 / (a:ℝ))..(1:ℝ),
      Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) =
      ∫ x in (1 / (a:ℝ))..(1:ℝ), 1 / ((a:ℝ) * x) * (1 / ((b:ℝ) * x)) := by
    rw [intervalIntegral.integral_of_le hle, intervalIntegral.integral_of_le hle]
    apply integral_congr_ae
    exact (ae_restrict_mem measurableSet_Ioc).mono fun x hx => by
      simp only
      rw [fract_simple_a a ha x hx.1 hx.2, fract_simple_b a b ha hb hab x hx.1 hx.2]
  rw [h_congr]
  -- Step 2: FTC with antiderivative F(x) = -1/(ab · x)
  -- d/dx[-1/(abx)] = 1/(abx²) = (1/(ax))·(1/(bx))
  set F : ℝ → ℝ := fun x => -1 / ((a:ℝ) * (b:ℝ) * x)
  have hF : ∀ x ∈ Set.uIcc (1 / (a:ℝ)) 1,
      HasDerivAt F (1 / ((a:ℝ) * x) * (1 / ((b:ℝ) * x))) x := by
    intro x hx; rw [Set.uIcc_of_le hle] at hx
    have hx_pos : (0:ℝ) < x := lt_of_lt_of_le (by positivity) hx.1
    have hx_ne : x ≠ 0 := ne_of_gt hx_pos
    -- F(x) = (-1/(ab)) · x⁻¹, so F'(x) = (-1/(ab)) · (-x⁻²) = 1/(ab·x²)
    have h_inv := hasDerivAt_inv hx_ne
    have h_scaled := h_inv.const_mul (-1 / ((a:ℝ) * (b:ℝ)))
    -- h_scaled : HasDerivAt (fun y => -1/(ab) * y⁻¹) (-1/(ab) * (-x⁻²)) x
    have h_eq_fun : (fun y => -1 / ((a:ℝ) * (b:ℝ)) * y⁻¹) =
        (fun y => -1 / ((a:ℝ) * (b:ℝ) * y)) := by
      ext y; by_cases hy : y = 0
      · simp [hy]
      · field_simp
    have h_eq_deriv : -1 / ((a:ℝ) * (b:ℝ)) * (-(x ^ 2)⁻¹) =
        1 / ((a:ℝ) * x) * (1 / ((b:ℝ) * x)) := by field_simp
    rw [h_eq_fun] at h_scaled
    exact h_scaled.congr_deriv h_eq_deriv
  have hint : IntervalIntegrable
      (fun x => 1 / ((a:ℝ) * x) * (1 / ((b:ℝ) * x))) volume (1 / (a:ℝ)) 1 := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.mul
    · apply ContinuousOn.div continuousOn_const (continuousOn_const.mul continuousOn_id)
      intro x hx; rw [Set.uIcc_of_le hle] at hx
      exact mul_ne_zero (ne_of_gt ha_pos) (ne_of_gt (lt_of_lt_of_le (by positivity) hx.1))
    · apply ContinuousOn.div continuousOn_const (continuousOn_const.mul continuousOn_id)
      intro x hx; rw [Set.uIcc_of_le hle] at hx
      exact mul_ne_zero (ne_of_gt hb_pos) (ne_of_gt (lt_of_lt_of_le (by positivity) hx.1))
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  -- Evaluate F(1) - F(1/a) = -1/(ab) - (-1/(ab·(1/a))) = -1/(ab) + 1/b = (a-1)/(ab)
  simp only [F]; field_simp; ring

private lemma gramIntegral_eq_formula_coprime (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b = DigammaReflection.vasyuninGramFormula a b := by
  -- ═══════════════════════════════════════════════════════════════
  -- PROOF BY UNIQUENESS OF LIMITS (squeeze elimination)
  -- ═══════════════════════════════════════════════════════════════
  --
  -- Route A: ∫_{1/(aM)}^1 → gramIntegral  (tail squeeze, proved below)
  -- Route B: ∫_{1/(aM)}^1 → formula       (telescope + Stirling + digamma)
  -- By uniqueness of limits: gramIntegral = formula.
  --
  set I := Assembly.gramIntegral a b
  set L := DigammaReflection.vasyuninGramFormula a b
  set f := fun x : ℝ => Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))
  set partialM := fun M : ℕ => ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ), f x
  -- Integrability (bounded by 1, measurable)
  have h_intble : ∀ s t : ℝ, IntervalIntegrable f volume s t := by
    intro s t; apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
    · exact ((measurable_const.div (measurable_const.mul measurable_id)).fract.mul
        (measurable_const.div (measurable_const.mul measurable_id)).fract).aestronglyMeasurable.restrict
    · apply ae_of_all; intro x; simp only [norm_one]
      rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
      nlinarith [Int.fract_nonneg (1 / ((a:ℝ) * x)), Int.fract_lt_one (1 / ((a:ℝ) * x)),
                 Int.fract_nonneg (1 / ((b:ℝ) * x)), Int.fract_lt_one (1 / ((b:ℝ) * x))]
  -- ── Route A: partialM → I (tail squeeze) ──
  have hA : Tendsto partialM atTop (nhds I) := by
    set tailM := fun M : ℕ => ∫ x in (0:ℝ)..(1 / ((a:ℝ) * (M:ℝ))), f x
    -- I = tail + partial for each M ≥ 1
    have h_split : ∀ M : ℕ, 1 ≤ M → I = tailM M + partialM M := by
      intro M _; show Assembly.gramIntegral a b = _; unfold Assembly.gramIntegral
      exact (intervalIntegral.integral_add_adjacent_intervals (h_intble 0 _) (h_intble _ 1)).symm
    -- tail ≥ 0
    have htail_nn : ∀ M : ℕ, 1 ≤ M → 0 ≤ tailM M := by
      intro M _; apply intervalIntegral.integral_nonneg (by positivity)
      intros x _; exact mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)
    -- tail ≤ 1/(aM) (integrand ≤ 1, interval length 1/(aM))
    have htail_le : ∀ M : ℕ, 1 ≤ M → tailM M ≤ 1 / ((a:ℝ) * (M:ℝ)) := by
      intro M hM
      have hε : (0:ℝ) ≤ 1 / ((a:ℝ) * (M:ℝ)) := by positivity
      have hbound : ∀ x ∈ Set.uIoc (0:ℝ) (1 / ((a:ℝ) * (M:ℝ))), ‖f x‖ ≤ 1 := by
        intro x _
        rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
        nlinarith [Int.fract_nonneg (1 / ((a:ℝ) * x)), Int.fract_lt_one (1 / ((a:ℝ) * x)),
                   Int.fract_nonneg (1 / ((b:ℝ) * x)), Int.fract_lt_one (1 / ((b:ℝ) * x))]
      have h := intervalIntegral.norm_integral_le_of_norm_le_const hbound
      rw [Real.norm_eq_abs, abs_of_nonneg (htail_nn M hM)] at h
      calc tailM M ≤ 1 * |1 / ((a:ℝ) * (M:ℝ)) - 0| := h
        _ = 1 / ((a:ℝ) * (M:ℝ)) := by rw [one_mul, sub_zero, abs_of_nonneg hε]
    -- 1/(aM) → 0
    have h_inv_tends : Tendsto (fun M : ℕ => 1 / ((a:ℝ) * (M:ℝ))) atTop (nhds 0) := by
      have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
      exact (tendsto_inv_atTop_zero.comp
        (tendsto_natCast_atTop_atTop.const_mul_atTop ha_pos)).congr (fun _ => by simp [one_div])
    -- tail → 0 by squeeze
    have htail_tends : Tendsto tailM atTop (nhds 0) := by
      rw [← le_antisymm_iff.mpr ⟨le_refl 0, le_refl 0⟩]
      apply tendsto_of_tendsto_of_tendsto_of_le_of_le' tendsto_const_nhds h_inv_tends
      · filter_upwards [Ioi_mem_atTop 0] with M (hM : 0 < M); exact htail_nn M (by omega)
      · filter_upwards [Ioi_mem_atTop 0] with M (hM : 0 < M); exact htail_le M (by omega)
    -- partial = I - tail → I - 0 = I
    have hpartial_eq : ∀ M : ℕ, 1 ≤ M → partialM M = I - tailM M := by
      intro M hM; have := h_split M hM; linarith
    have h_sub_zero : Tendsto (fun M => I - tailM M) atTop (nhds I) := by
      convert tendsto_const_nhds.sub htail_tends using 1; simp
    exact h_sub_zero.congr' (by
      filter_upwards [Ioi_mem_atTop 0] with M (hM : 0 < M)
      exact (hpartial_eq M (by omega)).symm)
  -- ── Route B: partialM → L (telescope decomposition + analytic evaluation) ──
  -- This is the analytic content: showing that the piecewise FTC sums
  -- converge to the Vasyunin formula via Stirling + Gauss digamma.
  --
  -- The row-by-row FTC evaluation (TelescopeSum.row_ftc_combined) gives:
  --   ∫_{1/(a(m+1))}^{1/(am)} {1/(ax)}{1/(bx)} dx = R(m)
  -- where R(m) = 1/b - (n(m)/a + m/b)·log((m+1)/m) + n(m)/(a(m+1))
  --
  -- Summing: ∫_{1/(aM)}^1 = strip + Σ_{m=1}^{M-1} R(m) = s_combined(M)
  --
  -- The M→∞ limit of s_combined(M) equals L by:
  --   s_rational → ∞ (diverges)
  --   s_log_stirling → ∞ (diverges, but cancels with s_rational)
  --   s_log_digamma → evaluates via Gauss digamma formula
  --   s_linear → evaluates via floor decomposition + Dirichlet test
  --
  -- All divergences cancel, leaving the Vasyunin formula.
  have hB : Tendsto partialM atTop (nhds L) :=
    ConvergenceAxioms.partial_integral_tends_to_formula a b ha hb hab hcop
  -- ── Conclusion: uniqueness of limits ──
  exact tendsto_nhds_unique hA hB

-- ════════════════════════════════════════════════
-- §3b. THE LIMIT THEOREM (proved from §3a + tail → 0)
-- ════════════════════════════════════════════════

/-- **STEP 3: THE ANALYTIC LIMIT** — The M→∞ limit of the partial integral
    converges to the Vasyunin formula for coprime (a,b).

    PROVED from: gramIntegral_eq_formula_coprime (§3a) + tail squeeze (Sub-lemma A).
    §3a is proved via uniqueness of limits using ConvergenceAxioms.partial_integral_tends_to_formula. -/
theorem partial_sum_tends_to_formula (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Tendsto
      (fun M : ℕ => ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
        Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      atTop
      (nhds (DigammaReflection.vasyuninGramFormula a b)) := by
  -- Use the core identity (Sub-lemma B) and the tail → 0 argument (Sub-lemma A)
  have h_formula := gramIntegral_eq_formula_coprime a b ha hb hab hcop
  -- Sub-lemma A: the partial integral → gramIntegral as M → ∞
  suffices h_tend : Tendsto
      (fun M : ℕ => ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ),
        Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      atTop (nhds (Assembly.gramIntegral a b)) by
    rw [h_formula] at h_tend; exact h_tend
  -- ── Sub-lemma A proof: partial_M → gramIntegral ──
  -- Integrability helper (used for splitting)
  have h_intble : ∀ s t : ℝ, IntervalIntegrable
      (fun x => Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      volume s t := by
    intro s t
    apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
    · have : Measurable (fun x : ℝ =>
          Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))) :=
        ((measurable_const.div (measurable_const.mul measurable_id)).fract).mul
          ((measurable_const.div (measurable_const.mul measurable_id)).fract)
      exact this.aestronglyMeasurable.restrict
    · apply ae_of_all; intro x
      simp only [norm_one]
      rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
      nlinarith [Int.fract_nonneg (1 / ((a:ℝ) * x)), Int.fract_lt_one (1 / ((a:ℝ) * x)),
                 Int.fract_nonneg (1 / ((b:ℝ) * x)), Int.fract_lt_one (1 / ((b:ℝ) * x))]
  -- Abbreviations
  set f := fun x : ℝ => Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)) with hf_def
  set I := Assembly.gramIntegral a b with hI_def
  set partialM := fun M : ℕ => ∫ x in (1 / ((a:ℝ) * (M:ℝ)))..(1:ℝ), f x with hpM_def
  set tailM := fun M : ℕ => ∫ x in (0:ℝ)..(1 / ((a:ℝ) * (M:ℝ))), f x with htM_def
  -- Splitting: I = tail_M + partial_M for each M ≥ 1
  have h_split : ∀ M : ℕ, 1 ≤ M → I = tailM M + partialM M := by
    intro M _
    show Assembly.gramIntegral a b = _
    unfold Assembly.gramIntegral
    exact (intervalIntegral.integral_add_adjacent_intervals
      (h_intble 0 _) (h_intble _ 1)).symm
  -- Tail is nonneg
  have htail_nn : ∀ M : ℕ, 1 ≤ M → 0 ≤ tailM M := by
    intro M hM; apply intervalIntegral.integral_nonneg (by positivity)
    intros x _; exact mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)
  -- Tail ≤ 1/(aM) : integrand ∈ [0,1], interval length = 1/(aM)
  have htail_le : ∀ M : ℕ, 1 ≤ M → tailM M ≤ 1 / ((a:ℝ) * (M:ℝ)) := by
    intro M hM
    have hε : (0:ℝ) ≤ 1 / ((a:ℝ) * (M:ℝ)) := by positivity
    have hbound : ∀ x ∈ Set.uIoc (0:ℝ) (1 / ((a:ℝ) * (M:ℝ))),
        ‖f x‖ ≤ 1 := by
      intro x _
      rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
      nlinarith [Int.fract_nonneg (1 / ((a:ℝ) * x)), Int.fract_lt_one (1 / ((a:ℝ) * x)),
                 Int.fract_nonneg (1 / ((b:ℝ) * x)), Int.fract_lt_one (1 / ((b:ℝ) * x))]
    have h := intervalIntegral.norm_integral_le_of_norm_le_const hbound
    rw [Real.norm_eq_abs, abs_of_nonneg (htail_nn M hM)] at h
    calc tailM M ≤ 1 * |1 / ((a:ℝ) * (M:ℝ)) - 0| := h
      _ = 1 / ((a:ℝ) * (M:ℝ)) := by rw [one_mul, sub_zero, abs_of_nonneg hε]
  -- 1/(aM) → 0
  have h_inv_tends : Tendsto (fun M : ℕ => 1 / ((a:ℝ) * (M:ℝ))) atTop (nhds 0) := by
    have ha_pos : (0:ℝ) < (a:ℝ) := Nat.cast_pos.mpr (by omega)
    exact (tendsto_inv_atTop_zero.comp
      (tendsto_natCast_atTop_atTop.const_mul_atTop ha_pos)).congr
      (fun _ => by simp [one_div])
  -- Tail → 0 by squeeze: 0 ≤ tail_M ≤ 1/(aM) → 0
  have htail_tends : Tendsto tailM atTop (nhds 0) := by
    rw [← le_antisymm_iff.mpr ⟨le_refl 0, le_refl 0⟩]
    apply tendsto_of_tendsto_of_tendsto_of_le_of_le'
        tendsto_const_nhds h_inv_tends
    · filter_upwards [Ioi_mem_atTop 0] with M (hM : 0 < M)
      exact htail_nn M (by omega)
    · filter_upwards [Ioi_mem_atTop 0] with M (hM : 0 < M)
      exact htail_le M (by omega)
  -- partial_M = I - tail_M → I - 0 = I
  have hpartial_eq : ∀ M : ℕ, 1 ≤ M → partialM M = I - tailM M := by
    intro M hM; have := h_split M hM; linarith
  have h_sub_zero : Tendsto (fun M => I - tailM M) atTop (nhds I) := by
    convert tendsto_const_nhds.sub htail_tends using 1; simp
  exact h_sub_zero.congr' (by
    filter_upwards [Ioi_mem_atTop 0] with M (hM : 0 < M)
    exact (hpartial_eq M (by omega)).symm)

/-- Fractional-part product is interval-integrable (standalone helper). -/
private lemma fract_prod_intble (a b : ℕ) (s t : ℝ) :
    IntervalIntegrable
      (fun x => Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x)))
      volume s t := by
  apply IntervalIntegrable.mono_fun (intervalIntegrable_const (c := (1:ℝ)))
  · have : Measurable (fun x : ℝ =>
        Int.fract (1 / ((a:ℝ) * x)) * Int.fract (1 / ((b:ℝ) * x))) :=
      ((measurable_const.div (measurable_const.mul measurable_id)).fract).mul
        ((measurable_const.div (measurable_const.mul measurable_id)).fract)
    exact this.aestronglyMeasurable.restrict
  · apply ae_of_all; intro x
    simp only [norm_one]
    rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
    nlinarith [Int.fract_nonneg (1 / ((a:ℝ) * x)), Int.fract_lt_one (1 / ((a:ℝ) * x)),
               Int.fract_nonneg (1 / ((b:ℝ) * x)), Int.fract_lt_one (1 / ((b:ℝ) * x))]

/-- `gramIntegral a b = vasyuninGramFormula a b` via the telescope limit. -/
theorem telescope_limit_eq_vasyunin (a b : ℕ) (ha : 1 ≤ a) (hb : 1 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b = DigammaReflection.vasyuninGramFormula a b :=
  gramIntegral_eq_formula_coprime a b ha hb hab hcop

/-- **THE MAIN BRIDGE**: For coprime (a,b) with a < b:
    ∫₀¹ {1/(ax)}{1/(bx)} dx = vasyuninGramFormula(a,b)

    Proved by applying the core identity. -/
theorem integral_eq_vasyunin_coprime (a b : ℕ)
    (ha : 1 ≤ a) (hb : 1 ≤ b) (hab : a < b)
    (hcop : Nat.Coprime a b) :
    Assembly.gramIntegral a b = DigammaReflection.vasyuninGramFormula a b :=
  gramIntegral_eq_formula_coprime a b ha hb hab hcop

-- ════════════════════════════════════════════════
-- §5. GCD STRUCTURE (helper lemmas)
-- ════════════════════════════════════════════════

/-- **COPRIME AFTER GCD**: j/gcd(j,k) and k/gcd(j,k) are always coprime. -/
theorem coprime_after_gcd (j k : ℕ) (hj : 1 ≤ j) (_hk : 1 ≤ k) :
    Nat.Coprime (j / Nat.gcd j k) (k / Nat.gcd j k) :=
  Nat.coprime_div_gcd_div_gcd (Nat.gcd_pos_of_pos_left k (by omega))

/-- **GCD OF QUOTIENTS**: gcd(j/d, k/d) = 1 when d = gcd(j,k). -/
theorem gcd_div_eq_one (j k : ℕ) (hj : 1 ≤ j) (_hk : 1 ≤ k) :
    Nat.gcd (j / Nat.gcd j k) (k / Nat.gcd j k) = 1 := by
  exact Nat.coprime_div_gcd_div_gcd (Nat.gcd_pos_of_pos_left k (by omega))

-- ════════════════════════════════════════════════
-- §6. THE MAIN THEOREM
-- ════════════════════════════════════════════════

/- **THE VASYUNIN INTEGRAL IDENTITY** — GRADUATED (axiom → theorem)

    For j, k ≥ 1 with j ≠ k:
    ∫₀¹ {1/(jx)}·{1/(kx)} dx = vasyuninGramFormula(j,k)

    **STATUS**: PROVED — see `GCDReduction.integral_eq_formula_general`.

    Proved in GCDReduction.lean via:
    1. formula_gcd_recurrence (PROVED): algebraic identity for the formula
    2. integral_gcd_recurrence (PROVED): GCD substitution for the integral
    3. integral_eq_formula_coprime (PROVED): coprime case via telescope limit

    The axiom declaration below is commented out — use
    `Cathedral.Vasyunin.GCDReduction.integral_eq_formula_general` instead. -/
-- theorem vasyunin_integral_eq_formula (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k)
--     (hjk : j ≠ k) :
--     Assembly.gramIntegral j k = DigammaReflection.vasyuninGramFormula j k :=
--   GCDReduction.integral_eq_formula_general j k hj hk hjk

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

-- PROVED (0 axiom):
--   ✅ partialDigammaSum_one       — S_N(1) = 0
--   ✅ tileIndex_pos               — ⌊jm/k⌋ ≥ 1 when jm ≥ k
--   ✅ coprime_after_gcd           — j/gcd and k/gcd are coprime
--   ✅ gcd_div_eq_one              — gcd of quotients = 1
--   ✅ integral_eq_vasyunin_coprime — coprime case (uniqueness of limits)
--   ✅ floor_sum_single            — ∑⌊mb/a⌋ = (a-1)(b-1)/2 (classical)
--   ✅ floor_sum_reciprocity       — Combined: ∑⌊mb/a⌋ + ∑⌊na/b⌋ = (a-1)(b-1)
--   ✅ gramIntegral_eq_formula_coprime — PROVED via uniqueness of limits
--   ✅ partial_sum_tends_to_formula — PROVED
--
-- UPSTREAM DEPENDENCIES (all axiom-free as of May 5, 2026):
--   - ConvergenceAxioms.partial_integral_tends_to_formula (THEOREM, zero axiom)
--   - DigammaReflection.gauss_digamma_formula
--
-- AXIOMS in this file: 0

end Cathedral.Vasyunin.LogDigammaBridge
