/-
  Cathedral/Analysis/GammaMultiplication.lean

  ## THE GAUSS MULTIPLICATION FORMULA FOR Γ(z)

  Proves the general multiplication formula:

    ∏_{k=0}^{q-1} Γ(z + k/q) = (2π)^{(q-1)/2} · q^{1/2-qz} · Γ(qz)

  Equivalently, defining:

    multiplicationGamma q s = ∏_{k=0}^{q-1} Γ((s+k)/q) · q^{s-1/2} / (2π)^{(q-1)/2}

  we show multiplicationGamma q s = Γ(s) for all s > 0 and q ≥ 1.

  ### Proof Strategy (The Bohr-Mollerup Maneuver)

  Following the pattern of Mathlib's `doublingGamma_eq_Gamma` (the Legendre
  doubling formula), we verify three properties:

  1. FUNCTIONAL EQUATION: multiplicationGamma q (s+1) = s · multiplicationGamma q s
  2. VALUE AT 1: multiplicationGamma q 1 = 1
  3. LOG-CONVEXITY: log ∘ multiplicationGamma q is convex on (0,∞)

  By `Real.eq_Gamma_of_log_convex` (Bohr-Mollerup uniqueness), this gives
  multiplicationGamma q = Γ on (0,∞).

  ### Downstream Usage

  The logarithmic derivative of this formula yields the DIGAMMA
  MULTIPLICATION FORMULA:

    ψ(qz) = log(q) + (1/q) Σ_{k=0}^{q-1} ψ(z + k/q)

  which is the key ingredient for graduating `gauss_digamma_formula`.

  Created: May 1, 2026 (The Vasyunin Bridge — May Campaign)
  Status: Building...
-/

import Mathlib.Analysis.SpecialFunctions.Gamma.BohrMollerup
import Mathlib.Analysis.SpecialFunctions.Gamma.Beta
import Mathlib.Analysis.SpecialFunctions.Gamma.Digamma
import Mathlib.Analysis.SpecialFunctions.Stirling
import Cathedral.Analysis.GammaProductEval
import Cathedral.Vasyunin.Cotangent.DigammaReflection

noncomputable section
open Real MeasureTheory Filter Finset Stirling BohrMollerup
open scoped Nat ENNReal Topology Real

namespace Cathedral.Analysis.GammaMultiplication

local notation "Γ" => Real.Gamma

-- ════════════════════════════════════════════════
-- §1. THE MULTIPLICATION GAMMA FUNCTION
-- ════════════════════════════════════════════════

/-- **THE MULTIPLICATION GAMMA FUNCTION**:

    For q ≥ 1:
    multiplicationGamma q s = q^{s - 1/2} / (2π)^{(q-1)/2}
                              · ∏_{k=0}^{q-1} Γ((s + k) / q)

    When q = 1, this simplifies to Γ(s).
    When q = 2, this is Mathlib's `Real.doublingGamma`.

    The Gauss multiplication formula states that this equals Γ(s)
    for all s > 0 and q ≥ 1. -/
def multiplicationGamma (q : ℕ) (s : ℝ) : ℝ :=
  (∏ k ∈ range q, Γ ((s + k) / q)) *
  (q : ℝ) ^ (s - 1/2) / (2 * Real.pi) ^ ((q - 1 : ℝ) / 2)

-- ════════════════════════════════════════════════
-- §2. PRELIMINARY LEMMAS
-- ════════════════════════════════════════════════

/-- The product ∏ Γ((s+1+k)/q) relates to ∏ Γ((s+k)/q) via the
    functional equation of Γ. The key identity:
    ∏_{k=0}^{q-1} Γ((s+1+k)/q) = (s/q) · ∏_{k=0}^{q-1} Γ((s+k)/q)

    Proof: When k ranges over {0,...,q-1}, the shift k → k+1 (mod q)
    cycles through the same set. The k=q-1 term contributes Γ((s+q)/q) = Γ(s/q + 1) = (s/q)Γ(s/q),
    and the remaining terms match ∏_{k=1}^{q-1} Γ((s+k)/q). -/
private lemma prod_gamma_shift (q : ℕ) (hq : 1 ≤ q) (s : ℝ) (hs : s ≠ 0) :
    ∏ k ∈ range q, Γ ((s + 1 + k) / q) =
    (s / q) * ∏ k ∈ range q, Γ ((s + k) / q) := by
  have hq_pos : (0:ℝ) < (q:ℝ) := Nat.cast_pos.mpr (by omega)
  have hq_ne : (q:ℝ) ≠ 0 := ne_of_gt hq_pos
  -- Rewrite (s+1+k)/q = (s+(k+1))/q
  have h_eq : ∀ k : ℕ, (s + 1 + (k:ℝ)) / (q:ℝ) = (s + ((k:ℝ) + 1)) / (q:ℝ) := by
    intro k; congr 1; ring
  simp_rw [h_eq]
  -- Introduce q' with q = q' + 1
  obtain ⟨q', rfl⟩ : ∃ q', q = q' + 1 := ⟨q - 1, by omega⟩
  -- Peel last term from LHS using prod_range_succ
  rw [Finset.prod_range_succ]
  -- The last factor: Γ((s + (↑q' + 1)) / ↑(q' + 1)) = Γ(s/q + 1) = (s/q) · Γ(s/q)
  have h_last : (s + (↑q' + 1)) / (↑(q' + 1) : ℝ) = s / (↑(q' + 1) : ℝ) + 1 := by
    rw [Nat.cast_add, Nat.cast_one]; field_simp
  rw [h_last]
  have hq'_ne : (↑(q' + 1) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  rw [Real.Gamma_add_one (div_ne_zero hs hq'_ne)]
  -- Peel first term from RHS using prod_range_succ'
  rw [Finset.prod_range_succ']
  simp only [Nat.cast_zero, add_zero]
  -- Now LHS = (∏_{k < q'} Γ((s+(k+1))/q)) * (s/q · Γ(s/q))
  -- and RHS = s/q * (Γ(s/q) * ∏_{k < q'} Γ((s+(k+1))/q))
  -- The Γ arguments inside the products may have different normal forms
  -- so we must align them first
  have h_prod_eq : ∏ x ∈ range q', Γ ((s + (↑x + 1)) / ↑(q' + 1)) =
      ∏ x ∈ range q', Γ ((s + ↑(x + 1)) / ↑(q' + 1)) := by
    apply Finset.prod_congr rfl
    intro x _
    congr 1
    push_cast; ring
  rw [h_prod_eq]
  ring

/-- multiplicationGamma q (s+1) = s · multiplicationGamma q s for s ≠ 0. -/
theorem multiplicationGamma_add_one (q : ℕ) (hq : 1 ≤ q) (s : ℝ) (hs : s ≠ 0) :
    multiplicationGamma q (s + 1) = s * multiplicationGamma q s := by
  unfold multiplicationGamma
  -- Key ingredients:
  -- 1. prod_gamma_shift: ∏ Γ((s+1+k)/q) = (s/q) · ∏ Γ((s+k)/q)
  -- 2. q^(s+1-1/2) = q · q^(s-1/2)
  -- Combining: (s/q) · q · ∏ Γ(...) · q^(s-1/2) / C = s · (∏ Γ(...) · q^(s-1/2) / C)
  have hq_pos : (0:ℝ) < q := Nat.cast_pos.mpr (by omega)
  have hq_ne : (q:ℝ) ≠ 0 := ne_of_gt hq_pos
  -- Step 1: Handle the product shift
  have h_prod : ∏ k ∈ range q, Γ ((s + 1 + ↑k) / ↑q) =
      (s / ↑q) * ∏ k ∈ range q, Γ ((s + ↑k) / ↑q) := prod_gamma_shift q hq s hs
  -- Step 2: Handle the power of q
  have h_pow : (q:ℝ) ^ (s + 1 - 1/2) = (q:ℝ) ^ (s - 1/2) * (q:ℝ) := by
    rw [show s + 1 - 1/2 = (s - 1/2) + 1 from by ring, rpow_add hq_pos, rpow_one]
  -- Combine
  rw [h_prod, h_pow]
  -- Goal: (s/q * P) * (q^{s-1/2} * q) / C = s * (P * q^{s-1/2} / C)
  have hC_pos : (0:ℝ) < (2 * Real.pi) ^ (((q:ℝ) - 1) / 2) :=
    rpow_pos_of_pos (by positivity : (0:ℝ) < 2 * Real.pi) _
  field_simp

-- **THE GAMMA PRODUCT AT ONE**: The product identity needed for f(1) = 1.
--
--     ∏_{k=0}^{q-1} Γ((1 + k) / q) = (2π)^{(q-1)/2} / √q
--
--     Proof architecture (Euler limit + Stirling + combinatorial bijection):
--
--     1. COMBINATORIAL: ∑_k BohrMollerup.logGammaSeq((1+k)/q, n) = closed form involving log(n!)
--        and log(((n+1)q)!) via the bijection (k,m) ↦ k+m·q.
--     2. STIRLING DECOMPOSITION: Substitute Stirling's log(n!) expansion to decompose
--        the sum into: Stirling correction + constants + vanishing algebraic term.
--     3. LIMIT EVALUATION: Each component has a known limit:
--        - Stirling correction → (q-1)/2 · log π
--        - Constants = (q-1)/2 · log 2 - 1/2 · log q
--        - Algebraic term → 0
--        Total → (q-1)/2 · log(2π) - 1/2 · log q
--     4. LOG-INJECTIVITY: Since both the product and the target are positive,
--        equality of logs implies equality of values.

-- ── Infrastructure: finite sum of limits ──

private lemma tendsto_finset_sum' {ι : Type*} (S : Finset ι) {f : ι → ℕ → ℝ} {a : ι → ℝ}
    (hf : ∀ k ∈ S, Tendsto (f k) atTop (𝓝 (a k))) :
    Tendsto (fun n => ∑ k ∈ S, f k n) atTop (𝓝 (∑ k ∈ S, a k)) := by
  classical
  induction S using Finset.induction_on with
  | empty => simp only [Finset.sum_empty]; exact tendsto_const_nhds
  | @insert k s' hk ih =>
    simp only [Finset.sum_insert hk]
    exact (hf k (Finset.mem_insert_self k s')).add
      (ih (fun j hj => hf j (Finset.mem_insert_of_mem hj)))

-- ── Infrastructure: weighted log ratio → 0 (from GammaProductEval) ──

private lemma tendsto_weighted_log_ratio (c : ℝ) :
    Tendsto (fun n : ℕ => (c * (n : ℝ) + c + 1/2) *
      (Real.log (n : ℝ) - Real.log ((n : ℝ) + 1)) + c) atTop (nhds 0) :=
  Cathedral.Analysis.GammaProductEval.tendsto_weighted_log_ratio c

-- ── Infrastructure: Stirling correction limit ──

private lemma tendsto_stirling_correction (q : ℕ) (hq : 1 ≤ q) :
    Tendsto (fun n : ℕ => (q : ℝ) * Real.log (Stirling.stirlingSeq n) -
      Real.log (Stirling.stirlingSeq ((n+1)*q))) atTop (𝓝 ((q - 1 : ℝ)/2 * Real.log Real.pi)) := by
  have hlog_sqrt : Tendsto (fun n => Real.log (Stirling.stirlingSeq n))
      atTop (𝓝 (Real.log (√Real.pi))) :=
    (Real.continuousAt_log (sqrt_ne_zero'.mpr pi_pos)).tendsto.comp Stirling.tendsto_stirlingSeq_sqrt_pi
  have htop : Tendsto (fun n : ℕ => (n+1)*q) atTop atTop := by
    apply Filter.tendsto_atTop.mpr; intro b
    filter_upwards [Filter.eventually_ge_atTop b] with n hn
    calc b ≤ n := hn
      _ ≤ n * 1 := by omega
      _ ≤ n * q := Nat.mul_le_mul_left n hq
      _ ≤ (n+1) * q := Nat.mul_le_mul_right q (Nat.le_succ n)
  have h3 := (hlog_sqrt.const_mul (q : ℝ)).sub (hlog_sqrt.comp htop)
  suffices (q : ℝ) * Real.log (√Real.pi) - Real.log (√Real.pi) =
      ((q:ℝ) - 1) / 2 * Real.log Real.pi by rwa [this] at h3
  rw [Real.log_sqrt pi_pos.le]; ring

-- ── Combinatorial: arithmetic sum ──

private lemma sum_arith_over_q (q : ℕ) (hq : 1 ≤ q) :
    ∑ k ∈ range q, ((1 + (k : ℝ)) / (q : ℝ)) = ((q : ℝ) + 1) / 2 :=
  Cathedral.Analysis.GammaProductEval.sum_arith_over_q q hq

-- ── Combinatorial: ∑ log(j+1) = log(N!) ──

private lemma sum_log_eq_log_factorial (N : ℕ) :
    ∑ j ∈ range N, Real.log ((j : ℝ) + 1) = Real.log (N !) := by
  induction N with
  | zero => simp
  | succ n ih =>
    rw [Finset.sum_range_succ, ih, Nat.factorial_succ, Nat.cast_mul, Nat.cast_succ,
        add_comm (Real.log _) (Real.log _)]
    exact (Real.log_mul (by positivity : (↑n + 1 : ℝ) ≠ 0)
      (Nat.cast_ne_zero.mpr (Nat.factorial_ne_zero n))).symm

-- ── Combinatorial: double sum via bijection (k,m) ↦ k+m·q ──

private lemma double_sum_eq_factorial_log (q n : ℕ) (hq : 1 ≤ q) :
    ∑ k ∈ range q, ∑ m ∈ range (n+1), Real.log ((1 : ℝ) + ↑k + ↑m * ↑q) =
    Real.log (((n+1)*q) !) := by
  rw [← sum_log_eq_log_factorial, ← Finset.sum_product']
  apply Finset.sum_nbij (fun (p : ℕ × ℕ) => p.1 + p.2 * q)
  · intro ⟨k, m⟩ hmem
    simp only [Finset.mem_product, Finset.mem_range] at hmem ⊢
    obtain ⟨hk, hm⟩ := hmem
    calc k + m * q < q + m * q := by omega
      _ = (m + 1) * q := by ring
      _ ≤ (n + 1) * q := Nat.mul_le_mul_right q (by omega)
  · intro ⟨k₁, m₁⟩ hk1 ⟨k₂, m₂⟩ hk2 heq
    have hk1' := (Finset.mem_product.mp hk1).1
    have hk2' := (Finset.mem_product.mp hk2).1
    simp only [Finset.mem_range] at hk1' hk2'
    dsimp only at heq
    have hmod : (k₁ + m₁ * q) % q = (k₂ + m₂ * q) % q := by rw [heq]
    rw [Nat.add_mul_mod_self_right, Nat.add_mul_mod_self_right,
        Nat.mod_eq_of_lt hk1', Nat.mod_eq_of_lt hk2'] at hmod
    subst hmod
    have hm : m₁ = m₂ := mul_right_cancel₀ (by omega : q ≠ 0) (by omega)
    subst hm; rfl
  · intro j hj
    simp only [Set.mem_image, Finset.coe_product, Finset.coe_range, Set.mem_prod, Set.mem_Iio]
    refine ⟨(j % q, j / q), ⟨Nat.mod_lt j (by omega),
      (Nat.div_lt_iff_lt_mul (by omega)).mpr (Finset.mem_range.mp hj)⟩, ?_⟩
    exact Nat.mod_add_div' j q
  · intro ⟨k, m⟩ _; congr 1; push_cast; ring

-- ── Combinatorial: double sum log decomposition ──

private lemma double_sum_log_decompose (q n : ℕ) (hq : 1 ≤ q) :
    ∑ k ∈ range q, ∑ m ∈ range (n+1), Real.log ((1 + ↑k) / (↑q : ℝ) + ↑m) =
    Real.log (((n+1)*q) !) - ↑q * (↑n + 1) * Real.log ↑q := by
  have hq_ne : (q : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have h_rw : ∀ k m : ℕ, Real.log ((1 + (k:ℝ)) / (q:ℝ) + (m:ℝ)) =
      Real.log (1 + ↑k + ↑m * ↑q) - Real.log ↑q := by
    intro k m
    have hnum : (0:ℝ) < 1 + ↑k + ↑m * ↑q := by positivity
    rw [show (1+(k:ℝ))/(q:ℝ)+(m:ℝ) = (1+↑k+↑m*↑q)/↑q from by field_simp]
    exact Real.log_div hnum.ne' hq_ne
  simp_rw [h_rw, Finset.sum_sub_distrib, Finset.sum_const, Finset.card_range, nsmul_eq_mul,
           double_sum_eq_factorial_log q n hq]
  push_cast; ring

-- ── The combinatorial identity for logGammaSeq ──

private lemma sum_logGammaSeq_eq (q : ℕ) (hq : 1 ≤ q) (n : ℕ) :
    ∑ k ∈ range q, BohrMollerup.logGammaSeq ((1 + ↑k) / ↑q) n =
    ((q + 1 : ℝ) / 2) * Real.log n + (q : ℝ) * Real.log (n !)
    - Real.log (((n + 1) * q) !) + (q : ℝ) * ((n : ℝ) + 1) * Real.log q := by
  simp only [BohrMollerup.logGammaSeq, Finset.sum_sub_distrib, Finset.sum_add_distrib]
  rw [← Finset.sum_mul, sum_arith_over_q q hq,
      Finset.sum_const, Finset.card_range, nsmul_eq_mul,
      double_sum_log_decompose q n hq]; ring

-- ── Stirling decomposition of logGammaSeq sum ──

private lemma sum_logGammaSeq_decompose (q : ℕ) (hq : 1 ≤ q) (n : ℕ) (hn : 1 ≤ n) :
    ∑ k ∈ range q, BohrMollerup.logGammaSeq ((1 + ↑k) / ↑q) n =
    ((q : ℝ) * Real.log (Stirling.stirlingSeq n) - Real.log (Stirling.stirlingSeq ((n+1)*q)))
    + (((q : ℝ) - 1) / 2 * Real.log 2 - 1/2 * Real.log q)
    + (((q : ℝ) * (n : ℝ) + (q : ℝ) + 1/2) *
       (Real.log n - Real.log ((n : ℝ) + 1)) + (q : ℝ)) := by
  rw [sum_logGammaSeq_eq q hq n]
  have hn_pos : (0 : ℝ) < n := Nat.cast_pos.mpr (by omega)
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  have hn1_pos : (0 : ℝ) < (n : ℝ) + 1 := by positivity
  have hlog_nfac : Real.log (n !) = Real.log (Stirling.stirlingSeq n) +
    1/2 * (Real.log 2 + Real.log n) + (n : ℝ) * (Real.log n - 1) := by
    have := Stirling.log_stirlingSeq_formula n
    rw [Real.log_mul (by positivity : (2:ℝ) ≠ 0) hn_pos.ne',
        Real.log_div hn_pos.ne' (by positivity : rexp 1 ≠ 0), Real.log_exp] at this
    linarith
  have hlog_nqfac : Real.log (((n + 1) * q) !) = Real.log (Stirling.stirlingSeq ((n+1)*q)) +
    1/2 * (Real.log 2 + Real.log ((n:ℝ)+1) + Real.log q) +
    ((n:ℝ)+1) * (q:ℝ) * (Real.log ((n:ℝ)+1) + Real.log q - 1) := by
    have := Stirling.log_stirlingSeq_formula ((n+1)*q)
    have hc1 : (2 : ℝ) * ((↑((n+1)*q) : ℝ)) = 2 * ((n:ℝ)+1) * (q:ℝ) := by push_cast; ring
    have hc2 : ((↑((n+1)*q) : ℝ)) = ((n:ℝ)+1) * (q:ℝ) := by push_cast; ring
    rw [hc1, hc2,
        Real.log_mul (by positivity : 2*((n:ℝ)+1) ≠ 0) hq_pos.ne',
        Real.log_mul (by positivity : (2:ℝ) ≠ 0) hn1_pos.ne',
        Real.log_div (by positivity : ((n:ℝ)+1)*(q:ℝ) ≠ 0) (by positivity : rexp 1 ≠ 0),
        Real.log_mul hn1_pos.ne' hq_pos.ne', Real.log_exp] at this
    linarith
  rw [hlog_nfac, hlog_nqfac]; ring

-- ── Limit: sum of logGammaSeq → ∑ log Γ ──

private lemma tendsto_sum_logGammaSeq (q : ℕ) (hq : 1 ≤ q) :
    Tendsto (fun n => ∑ k ∈ range q, BohrMollerup.logGammaSeq ((1 + ↑k) / ↑q) n)
      atTop (𝓝 (∑ k ∈ range q, Real.log (Γ ((1 + ↑k) / ↑q)))) :=
  tendsto_finset_sum' _ (fun k _ => BohrMollerup.tendsto_log_gamma
    (div_pos (by positivity : (0:ℝ) < 1 + k) (Nat.cast_pos.mpr (by omega))))

-- ── The key limit evaluation ──

/-- **Log-Gamma sum at rational arguments**:
    Σ_{k=0}^{q-1} log Γ((1+k)/q) = (q-1)/2 · log(2π) - 1/2 · log q.
    Derived from the Stirling-based evaluation of logGammaSeq sums. -/
theorem sum_log_gamma_eq_target (q : ℕ) (hq : 1 ≤ q) :
    ∑ k ∈ range q, Real.log (Γ ((1 + ↑k) / ↑q)) =
    ((q : ℝ) - 1) / 2 * Real.log (2 * Real.pi) - 1/2 * Real.log q := by
  have h_target : Tendsto (fun n : ℕ =>
    ((q : ℝ) * Real.log (Stirling.stirlingSeq n) - Real.log (Stirling.stirlingSeq ((n+1)*q)))
    + (((q : ℝ) - 1) / 2 * Real.log 2 - 1/2 * Real.log q)
    + (((q : ℝ) * (n : ℝ) + (q : ℝ) + 1/2) *
       (Real.log n - Real.log ((n : ℝ) + 1)) + (q : ℝ)))
    atTop (𝓝 (((q : ℝ) - 1) / 2 * Real.log (2 * Real.pi) - 1/2 * Real.log q)) := by
    have htarget_eq : ((q : ℝ) - 1) / 2 * Real.log (2 * Real.pi) - 1/2 * Real.log q =
        ((q - 1 : ℝ)/2 * Real.log Real.pi) +
        (((q : ℝ) - 1) / 2 * Real.log 2 - 1/2 * Real.log q) + 0 := by
      rw [Real.log_mul (by positivity : (2:ℝ) ≠ 0) pi_pos.ne']; ring
    rw [htarget_eq]
    exact ((tendsto_stirling_correction q hq).add tendsto_const_nhds).add
      (tendsto_weighted_log_ratio q)
  have h_eq : ∀ᶠ n : ℕ in atTop,
    ∑ k ∈ range q, BohrMollerup.logGammaSeq ((1 + ↑k) / ↑q) n =
    ((q : ℝ) * Real.log (Stirling.stirlingSeq n) - Real.log (Stirling.stirlingSeq ((n+1)*q)))
    + (((q : ℝ) - 1) / 2 * Real.log 2 - 1/2 * Real.log q)
    + (((q : ℝ) * (n : ℝ) + (q : ℝ) + 1/2) *
       (Real.log n - Real.log ((n : ℝ) + 1)) + (q : ℝ)) :=
    Filter.eventually_atTop.mpr ⟨1, fun n hn => sum_logGammaSeq_decompose q hq n hn⟩
  exact tendsto_nhds_unique (tendsto_sum_logGammaSeq q hq)
    (h_target.congr' (Filter.EventuallyEq.symm h_eq))

-- ── THE GAMMA PRODUCT AT ONE (FULLY PROVED) ──

/-- **Gamma product at s=1**: ∏_{k=0}^{q-1} Γ((1+k)/q) = (2π)^{(q-1)/2} / √q. -/
theorem gamma_product_at_one (q : ℕ) (hq : 1 ≤ q) :
    ∏ k ∈ range q, Γ ((1 + ↑k) / ↑q) =
    (2 * Real.pi) ^ (((q:ℝ) - 1) / 2) / (q:ℝ) ^ ((1:ℝ)/2) := by
  have hq_pos : (0:ℝ) < q := Nat.cast_pos.mpr (by omega)
  have hprod_pos : 0 < ∏ k ∈ range q, Γ ((1 + ↑k) / ↑q) :=
    Finset.prod_pos (fun k _ => Real.Gamma_pos_of_pos
      (div_pos (by positivity : (0:ℝ) < 1 + k) hq_pos))
  have htarget_pos : (0:ℝ) < (2 * Real.pi) ^ (((q:ℝ) - 1) / 2) / (q:ℝ) ^ ((1:ℝ)/2) :=
    div_pos (rpow_pos_of_pos (by positivity) _) (rpow_pos_of_pos hq_pos _)
  have hlog_eq : Real.log (∏ k ∈ range q, Γ ((1 + ↑k) / ↑q)) =
      Real.log ((2 * Real.pi) ^ (((q:ℝ) - 1) / 2) / (q:ℝ) ^ ((1:ℝ)/2)) := by
    rw [Real.log_prod (s := range q) (fun k _ => (Real.Gamma_pos_of_pos
          (div_pos (by positivity : (0:ℝ) < 1 + k) hq_pos)).ne'),
        Real.log_div (rpow_pos_of_pos (by positivity) _).ne' (rpow_pos_of_pos hq_pos _).ne',
        Real.log_rpow (by positivity : (0:ℝ) < 2 * Real.pi), Real.log_rpow hq_pos]
    exact sum_log_gamma_eq_target q hq
  exact Real.log_injOn_pos (Set.mem_Ioi.mpr hprod_pos) (Set.mem_Ioi.mpr htarget_pos) hlog_eq

/-- multiplicationGamma q 1 = 1.

    Unfolds the definition and uses `gamma_product_at_one` to evaluate the product.
    The resulting expression simplifies to 1 via:
    (∏ Γ((1+k)/q)) · q^{1/2} / (2π)^{(q-1)/2}
    = ((2π)^{(q-1)/2} / q^{1/2}) · q^{1/2} / (2π)^{(q-1)/2} = 1 -/
theorem multiplicationGamma_one (q : ℕ) (hq : 1 ≤ q) :
    multiplicationGamma q 1 = 1 := by
  unfold multiplicationGamma
  rw [gamma_product_at_one q hq]
  have hq_pos : (0:ℝ) < q := Nat.cast_pos.mpr (by omega)
  have hpi_pos : (0:ℝ) < 2 * Real.pi := by positivity
  have h1 : (0:ℝ) < (2 * Real.pi) ^ (((q:ℝ) - 1) / 2) := rpow_pos_of_pos hpi_pos _
  have h2 : (0:ℝ) < (q:ℝ) ^ ((1:ℝ)/2) := rpow_pos_of_pos hq_pos _
  field_simp
  congr 1; norm_num

/-- Sum of convex functions over a finset is convex. -/
private lemma sum_convexOn {ι : Type*} (S : Finset ι)
    {f : ι → ℝ → ℝ} (hf : ∀ k ∈ S, ConvexOn ℝ (Set.Ioi 0) (f k)) :
    ConvexOn ℝ (Set.Ioi 0) (fun s => ∑ k ∈ S, f k s) := by
  classical
  induction S using Finset.induction_on with
  | empty => simp only [Finset.sum_empty]; exact convexOn_const 0 (convex_Ioi 0)
  | @insert a s' ha ih =>
    have heq : (fun s => ∑ k ∈ insert a s', f k s) = (fun s => f a s + ∑ k ∈ s', f k s) := by
      ext s; exact Finset.sum_insert ha
    rw [heq]
    exact (hf a (Finset.mem_insert_self a s')).add
      (ih (fun k hk => hf k (Finset.mem_insert_of_mem hk)))

/-- Each log(Γ((s+k)/q)) is convex on Ioi 0.
    The affine map s ↦ (s+k)/q maps Ioi 0 into Ioi 0 (for k ≥ 0, q ≥ 1),
    so composing with the log-convex Γ preserves convexity. -/
private lemma logGamma_affine_convex (q : ℕ) (hq : 1 ≤ q) (k : ℕ) :
    ConvexOn ℝ (Set.Ioi 0) (fun s => Real.log (Γ ((s + ↑k) / ↑q))) := by
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  set g : ℝ →ᵃ[ℝ] ℝ := (1/(q:ℝ)) • AffineMap.id ℝ ℝ + AffineMap.const ℝ ℝ ((k:ℝ)/(q:ℝ))
  have hfun : ∀ s, g s = (s + ↑k) / ↑q := by
    intro s
    simp only [g, AffineMap.coe_add, AffineMap.coe_smul, AffineMap.coe_const,
      AffineMap.id_apply, Pi.add_apply, Pi.smul_apply, smul_eq_mul, Function.const_apply]
    ring
  have hfun2 : (fun s => Real.log (Γ ((s + ↑k) / ↑q))) =
      (Real.log ∘ Γ) ∘ g := by ext s; simp only [Function.comp_apply]; rw [hfun]
  rw [hfun2]
  exact (convexOn_log_Gamma.comp_affineMap g).subset
    (fun s (hs : (0:ℝ) < s) => by
      rw [Set.mem_preimage, hfun]; exact div_pos (by positivity) hq_pos)
    (convex_Ioi 0)

/-- An affine function s ↦ a·s + b is convex on any convex set. -/
private lemma convexOn_affine (a b : ℝ) :
    ConvexOn ℝ (Set.Ioi 0) (fun s => a * s + b) :=
  ⟨convex_Ioi 0, fun x _ y _ t₁ t₂ ht₁ ht₂ hab => by
    simp only [smul_eq_mul]
    have : t₁ * (a * x + b) + t₂ * (a * y + b) =
        a * (t₁ * x + t₂ * y) + b * (t₁ + t₂) := by ring
    rw [this, hab, mul_one]⟩

/-- **EqOn decomposition**: log(multiplicationGamma q s) equals a sum of convex
    functions plus an affine function on Ioi 0.

    log(f(s)) = Σ_k log Γ((s+k)/q) + log(q)·s + const -/
private lemma log_multiplicationGamma_eq (q : ℕ) (hq : 1 ≤ q) :
    Set.EqOn (Real.log ∘ multiplicationGamma q)
      (fun s => (∑ k ∈ range q, Real.log (Γ ((s + ↑k) / ↑q))) +
        (Real.log ↑q * s +
          (-(1/2) * Real.log ↑q - ((↑q - 1) / 2) * Real.log (2 * Real.pi))))
      (Set.Ioi 0) := by
  intro s (hs : 0 < s)
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  have hpi_pos : (0 : ℝ) < 2 * Real.pi := by positivity
  have hsk_pos : ∀ k : ℕ, 0 < (s + ↑k) / ↑q := fun k => div_pos (by positivity) hq_pos
  simp only [Function.comp_apply, multiplicationGamma]
  rw [Real.log_div
        (mul_ne_zero
          (Finset.prod_pos (fun k _ => Real.Gamma_pos_of_pos (hsk_pos k))).ne'
          (rpow_pos_of_pos hq_pos _).ne')
        (rpow_pos_of_pos hpi_pos _).ne',
      Real.log_mul
        (Finset.prod_pos (fun k _ => Real.Gamma_pos_of_pos (hsk_pos k))).ne'
        (rpow_pos_of_pos hq_pos _).ne',
      Real.log_rpow hq_pos, Real.log_rpow hpi_pos,
      Real.log_prod (fun k _ => (Real.Gamma_pos_of_pos (hsk_pos k)).ne')]
  ring

/-- log ∘ multiplicationGamma q is convex on (0,∞).

    **Proof**: Decompose log(multiplicationGamma q s) as:
    - Σ_k log Γ((s+k)/q): sum of convex functions (each is log∘Γ composed with
      an affine map s ↦ (s+k)/q, convex by `convexOn_log_Gamma.comp_affineMap`)
    - log(q)·s + const: an affine function (hence convex)

    The sum of convex + affine is convex. Transfer via `ConvexOn.congr`. -/
theorem multiplicationGamma_log_convex (q : ℕ) (hq : 1 ≤ q) :
    ConvexOn ℝ (Set.Ioi 0) (Real.log ∘ multiplicationGamma q) :=
  ((sum_convexOn (range q) (fun k _ => logGamma_affine_convex q hq k)).add
    (convexOn_affine (Real.log ↑q)
      (-(1/2) * Real.log ↑q -
        ((↑q - 1) / 2) * Real.log (2 * Real.pi)))).congr
    (log_multiplicationGamma_eq q hq).symm

/-- multiplicationGamma q s > 0 for s > 0. -/
theorem multiplicationGamma_pos (q : ℕ) (hq : 1 ≤ q) {s : ℝ} (hs : 0 < s) :
    0 < multiplicationGamma q s := by
  unfold multiplicationGamma
  apply div_pos
  · apply mul_pos
    · apply Finset.prod_pos
      intro k _
      exact Real.Gamma_pos_of_pos (by positivity)
    · exact rpow_pos_of_pos (Nat.cast_pos.mpr (by omega)) _
  · exact rpow_pos_of_pos (by positivity : (0:ℝ) < 2 * Real.pi) _

-- ════════════════════════════════════════════════
-- §3. THE MULTIPLICATION FORMULA (MAIN THEOREM)
-- ════════════════════════════════════════════════

/-- **THE GAUSS MULTIPLICATION FORMULA**: For q ≥ 1 and s > 0:

    multiplicationGamma q s = Γ(s)

    Equivalently:

    ∏_{k=0}^{q-1} Γ(s/q + k/q) = (2π)^{(q-1)/2} · q^{1/2-s} · Γ(s)

    PROVED by Bohr-Mollerup uniqueness (`Real.eq_Gamma_of_log_convex`). -/
theorem multiplicationGamma_eq_Gamma (q : ℕ) (hq : 1 ≤ q) {s : ℝ} (hs : 0 < s) :
    multiplicationGamma q s = Γ s := by
  exact Real.eq_Gamma_of_log_convex
    (multiplicationGamma_log_convex q hq)
    (fun {y} hy => multiplicationGamma_add_one q hq y hy.ne')
    (fun {y} hy => multiplicationGamma_pos q hq hy)
    (multiplicationGamma_one q hq)
    hs

/-- **THE PRODUCT FORM**: For q ≥ 1 and s > 0:

    ∏_{k=0}^{q-1} Γ((s + k) / q) = (2π)^{(q-1)/2} · q^{1/2-s} · Γ(s)  -/
theorem gamma_product_formula (q : ℕ) (hq : 1 ≤ q) {s : ℝ} (hs : 0 < s) :
    ∏ k ∈ range q, Γ ((s + k) / q) =
    (2 * Real.pi) ^ (((q:ℝ) - 1) / 2) * (q:ℝ) ^ (1/2 - s) * Γ s := by
  have heq := multiplicationGamma_eq_Gamma q hq hs
  unfold multiplicationGamma at heq
  have hq_pos : (0:ℝ) < q := Nat.cast_pos.mpr (by omega)
  have hpi_pos : (0:ℝ) < 2 * Real.pi := by positivity
  have hdenom_pos : (0:ℝ) < (2 * Real.pi) ^ (((q:ℝ) - 1) / 2) := rpow_pos_of_pos hpi_pos _
  have hpow_pos : (0:ℝ) < (q:ℝ) ^ (s - 1/2) := rpow_pos_of_pos hq_pos _
  rw [show (1:ℝ)/2 - s = -(s - 1/2) from by ring, rpow_neg (le_of_lt hq_pos)]
  rw [div_eq_iff hdenom_pos.ne'] at heq
  -- heq: ∏ * q^{s-1/2} = Γ(s) * (2π)^{...}
  -- Goal: ∏ = (2π)^{...} * (q^{s-1/2})⁻¹ * Γ s
  have h1 : ∏ k ∈ range q, Γ ((s + ↑k) / ↑q) =
      (∏ k ∈ range q, Γ ((s + ↑k) / ↑q)) * ↑q ^ (s - 1 / 2) / ↑q ^ (s - 1 / 2) := by
    rw [mul_div_cancel_right₀ _ (ne_of_gt hpow_pos)]
  rw [h1, heq]
  rw [div_eq_mul_inv]
  ring

-- ════════════════════════════════════════════════
-- §4. THE DIGAMMA MULTIPLICATION FORMULA
-- ════════════════════════════════════════════════

-- ── Infrastructure: positivity for shifted arguments ──

private lemma pos_cast_add_div' (s : ℝ) (hs : 0 < s) (k q : ℕ) (_hq : 1 ≤ q) :
    (0:ℝ) < s + (k:ℝ) / (q:ℝ) := by positivity

private lemma qs_ne_neg_nat (q : ℕ) (hq : 2 ≤ q) (s : ℝ) (hs : 0 < s) :
    ∀ m : ℕ, (q:ℂ) * (s:ℂ) ≠ -(m:ℂ) := by
  intro m h
  have hre := congr_arg Complex.re h
  simp [Complex.ofReal_re, Complex.mul_re, Complex.neg_re, Complex.natCast_re,
        Complex.ofReal_im, Complex.natCast_im] at hre
  -- hre : ↑q * s = -↑m
  have hqs : (0:ℝ) < (q:ℝ) * s := mul_pos (by positivity) hs
  linarith

private lemma sk_ne_neg_nat (q : ℕ) (_hq : 2 ≤ q) (s : ℝ) (hs : 0 < s) (k : ℕ) :
    ∀ m : ℕ, (s:ℂ) + (k:ℂ) / (q:ℂ) ≠ -(m:ℂ) := by
  intro m h; have := congr_arg Complex.re h; simp at this
  have hsub : s + (k:ℝ) / (q:ℝ) = -(m:ℝ) := by exact_mod_cast this
  linarith [pos_cast_add_div' s hs k q (by omega : 1 ≤ q)]

-- ── The periodicity lemma ──

/-- **Core recurrence**: F(s+1) = F(s) where F(s) = ψ(qs) - log q - (1/q)∑ψ(s+k/q).

    ψ(q(s+1)) = ψ(qs) + ∑ 1/(qs+j) and ψ(s+1+k/q) = ψ(s+k/q) + 1/(s+k/q).
    The inverse sums match: (1/q)·1/(s+k/q) = 1/(qs+k). -/
private lemma digamma_mult_periodic (q : ℕ) (hq : 2 ≤ q) (s : ℝ) (hs : 0 < s) :
    Complex.digamma ((q:ℂ) * ((s:ℂ) + 1)) -
    (Complex.log (q:ℂ) + (1 / (q:ℂ)) *
      ∑ k ∈ range q, Complex.digamma (((s:ℂ) + 1) + (k:ℂ) / (q:ℂ))) =
    Complex.digamma ((q:ℂ) * (s:ℂ)) -
    (Complex.log (q:ℂ) + (1 / (q:ℂ)) *
      ∑ k ∈ range q, Complex.digamma ((s:ℂ) + (k:ℂ) / (q:ℂ))) := by
  have hq_ne : (q:ℂ) ≠ 0 := by exact_mod_cast (show (q:ℕ) ≠ 0 by omega)
  -- Step 1: ψ(qs + q) = ψ(qs) + ∑ (qs+j)⁻¹
  have h_lhs : Complex.digamma ((q:ℂ) * ((s:ℂ) + 1)) =
      Complex.digamma ((q:ℂ) * (s:ℂ)) +
      ∑ j ∈ range q, ((q:ℂ) * (s:ℂ) + (j:ℂ))⁻¹ := by
    conv_lhs => rw [show (q:ℂ) * ((s:ℂ) + 1) = (q:ℂ) * (s:ℂ) + (q:ℂ) from by ring]
    exact Cathedral.Vasyunin.DigammaReflection.digamma_add_nat _ (qs_ne_neg_nat q hq s hs) q
  -- Step 2: ψ(s+1+k/q) = ψ(s+k/q) + (s+k/q)⁻¹  for each k
  have h_rhs : ∀ k ∈ range q,
      Complex.digamma (((s:ℂ) + 1) + (k:ℂ) / (q:ℂ)) =
      Complex.digamma ((s:ℂ) + (k:ℂ) / (q:ℂ)) + ((s:ℂ) + (k:ℂ) / (q:ℂ))⁻¹ := by
    intro k _
    conv_lhs => rw [show ((s:ℂ) + 1) + (k:ℂ) / (q:ℂ) = ((s:ℂ) + (k:ℂ) / (q:ℂ)) + 1 from by ring]
    exact Complex.digamma_apply_add_one _ (sk_ne_neg_nat q hq s hs k)
  -- Step 3: The inverse sums match: (1/q) · (s+k/q)⁻¹ = (qs+k)⁻¹
  have h_sums : ∑ j ∈ range q, ((q:ℂ) * (s:ℂ) + (j:ℂ))⁻¹ =
      1 / (q:ℂ) * ∑ k ∈ range q, ((s:ℂ) + (k:ℂ) / (q:ℂ))⁻¹ := by
    rw [Finset.mul_sum]; apply Finset.sum_congr rfl; intro k _; field_simp
  -- Assemble: substitute, expand sums, cancel
  rw [h_lhs, Finset.sum_congr rfl h_rhs, Finset.sum_add_distrib, mul_add, h_sums]
  ring

-- ── Iteration of periodicity ──

private lemma digamma_mult_periodic_nat (q : ℕ) (hq : 2 ≤ q) (s : ℝ) (hs : 0 < s) (N : ℕ) :
    Complex.digamma ((q:ℂ) * ((s:ℂ) + (N:ℂ))) -
    (Complex.log (q:ℂ) + (1 / (q:ℂ)) *
      ∑ k ∈ range q, Complex.digamma (((s:ℂ) + (N:ℂ)) + (k:ℂ) / (q:ℂ))) =
    Complex.digamma ((q:ℂ) * (s:ℂ)) -
    (Complex.log (q:ℂ) + (1 / (q:ℂ)) *
      ∑ k ∈ range q, Complex.digamma ((s:ℂ) + (k:ℂ) / (q:ℂ))) := by
  induction N with
  | zero => simp
  | succ n ih =>
    have hs_n : (0:ℝ) < s + n := by positivity
    -- F(s + (n+1)) = F((s+n) + 1) = F(s+n) = F(s)
    -- Key: ↑(s + ↑n) = ↑s + ↑n in ℂ (by Complex.ofReal_add)
    have heq : ∀ (t : ℝ),
        Complex.digamma ((q:ℂ) * ((t:ℂ))) = Complex.digamma ((q:ℂ) * (t:ℂ)) := fun _ => rfl
    -- First, show (s:ℂ) + ↑(n+1) = ↑(s + ↑n) + 1
    have h_sn1 : (s:ℂ) + (↑(n + 1) : ℂ) = (↑(s + ↑n) : ℂ) + 1 := by push_cast; ring
    -- Rewrite the LHS via h_sn1
    simp_rw [h_sn1]
    -- Now it matches digamma_mult_periodic applied to (s + ↑n)
    rw [digamma_mult_periodic q hq (s + ↑n) hs_n]
    -- Now we need to reconcile ↑(s + ↑n) with ↑s + ↑n
    have h_sn : (↑(s + ↑n) : ℂ) = (s:ℂ) + (↑n : ℂ) := by push_cast; ring
    simp_rw [h_sn]
    exact ih

-- ── Bridge: Complex.digamma at real points ──

/-- The complex digamma at a real point equals the complex cast of the real logDeriv of Gamma.
    This bridges the real product formula to the complex digamma. -/
lemma digamma_ofReal (s : ℝ) (hs : ∀ m : ℕ, s ≠ -(m : ℝ)) :
    Complex.digamma (↑s) = ↑(logDeriv Real.Gamma s) := by
  -- digamma = logDeriv Gamma (complex)
  rw [Complex.digamma_def, logDeriv_apply, logDeriv_apply]
  -- Complex.Gamma ↑s = ↑(Real.Gamma s) by Gamma_ofReal
  rw [Complex.Gamma_ofReal]
  -- Need: deriv Complex.Gamma ↑s = ↑(deriv Real.Gamma s)
  -- This follows from Gamma ∘ ofReal = ofReal ∘ Real.Gamma and chain rule
  have hcplx : ∀ m : ℕ, (s : ℂ) ≠ -(m : ℂ) := by
    intro m; specialize hs m; exact_mod_cast hs
  have hd_complex := Complex.differentiableAt_Gamma (↑s) hcplx
  -- The real derivative of Real.Gamma at s can be computed from the complex derivative
  have h_real_of_complex := hd_complex.hasDerivAt.real_of_complex
  -- h_real_of_complex gives: HasDerivAt (fun x => (Complex.Gamma ↑x).re) (deriv Complex.Gamma ↑s).re s
  -- But (Complex.Gamma ↑x).re = Real.Gamma x by Gamma_ofReal
  have h_eq : (fun x : ℝ => (Complex.Gamma ↑x).re) = Real.Gamma := by
    ext x; simp [Complex.Gamma_ofReal]
  rw [h_eq] at h_real_of_complex
  -- So deriv Real.Gamma s = (deriv Complex.Gamma ↑s).re
  have h_deriv : deriv Real.Gamma s = (deriv Complex.Gamma (↑s)).re :=
    h_real_of_complex.deriv
  -- Also Complex.Gamma ↑s is real-valued, so deriv Complex.Gamma ↑s is real-valued
  -- (the imaginary part of the derivative is zero by Cauchy-Riemann applied to f real-on-reals)
  -- More precisely: deriv Complex.Gamma ↑s = ↑(deriv Real.Gamma s)
  -- because f'(↑s) has .im = 0 when f maps reals to reals
  -- This needs HasDerivAt.ofReal_comp
  have h_ofReal_comp : HasDerivAt (Complex.Gamma ∘ Complex.ofReal) (deriv Complex.Gamma ↑s) s := by
    exact hd_complex.hasDerivAt.comp s (Complex.ofRealCLM.hasDerivAt)
      |>.congr_deriv (by simp [Complex.ofRealCLM_apply])
  have h_gamma_real : Complex.Gamma ∘ Complex.ofReal = Complex.ofReal ∘ Real.Gamma := by
    ext x; simp [Complex.Gamma_ofReal]
  rw [h_gamma_real] at h_ofReal_comp
  -- Now h_ofReal_comp : HasDerivAt (↑· ∘ Real.Gamma) (deriv Complex.Gamma ↑s) s
  -- The derivative of ↑· ∘ f at s is ↑(f'(s)) since ofReal is linear
  have h_ofReal_deriv : HasDerivAt (Complex.ofReal ∘ Real.Gamma)
      (↑(deriv Real.Gamma s)) s := by
    exact (Real.differentiableAt_Gamma hs).hasDerivAt.ofReal_comp
  have h_deriv_eq : deriv Complex.Gamma (↑s) = ↑(deriv Real.Gamma s) :=
    h_ofReal_comp.unique h_ofReal_deriv
  rw [h_deriv_eq]
  push_cast; rfl

-- ── The logDeriv of the product formula ──

-- Helper: the curried family f_k : ℕ → ℝ → ℝ, f_k s = Γ((s + k) / q)
private def gammaShift (q : ℕ) (k : ℕ) : ℝ → ℝ := fun s => Γ ((s + k) / q)

-- Helper: each gammaShift is nonzero for s > 0
private lemma gammaShift_ne_zero (q : ℕ) (hq : 1 ≤ q) (k : ℕ) (_hk : k ∈ range q)
    (s : ℝ) (hs : 0 < s) : gammaShift q k s ≠ 0 := by
  unfold gammaShift
  exact (Gamma_pos_of_pos (by positivity : 0 < (s + k) / q)).ne'

-- Helper: each gammaShift is differentiable at s > 0
private lemma gammaShift_differentiableAt (q : ℕ) (hq : 1 ≤ q) (k : ℕ) (_hk : k ∈ range q)
    (s : ℝ) (hs : 0 < s) : DifferentiableAt ℝ (gammaShift q k) s := by
  unfold gammaShift
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  exact (Real.differentiableAt_Gamma (fun m => by
    have : 0 < (s + ↑k) / ↑q := by positivity
    linarith)).comp s ((differentiableAt_id.add (differentiableAt_const _)).div_const _)

-- Helper: logDeriv_comp for gammaShift gives (1/q) * logDeriv Γ ((s+k)/q)
private lemma logDeriv_gammaShift (q : ℕ) (hq : 1 ≤ q) (k : ℕ) (s : ℝ) (hs : 0 < s) :
    logDeriv (gammaShift q k) s = (1 / (q : ℝ)) * logDeriv Real.Gamma ((s + k) / q) := by
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  simp only [logDeriv_apply]
  -- Goal: deriv (gammaShift q k) s / gammaShift q k s = (1/q) * (deriv Γ ((s+k)/q) / Γ((s+k)/q))
  -- Unfold gammaShift in the value (denominator)
  show deriv (gammaShift q k) s / Γ ((s + ↑k) / ↑q) =
    1 / ↑q * (deriv Γ ((s + ↑k) / ↑q) / Γ ((s + ↑k) / ↑q))
  have hgk_diff : DifferentiableAt ℝ (fun s : ℝ => (s + ↑k) / ↑q) s :=
    (differentiableAt_id.add (differentiableAt_const _)).div_const _
  have hgamma_diff : DifferentiableAt ℝ Γ ((s + ↑k) / ↑q) :=
    Real.differentiableAt_Gamma (fun m => by
      have : 0 < (s + ↑k) / ↑q := by positivity
      linarith)
  have hg_deriv : HasDerivAt (fun s : ℝ => (s + ↑k) / ↑q) (1 / q) s := by
    have h := (hasDerivAt_id s).add (hasDerivAt_const s (k : ℝ))
    convert h.div_const (q : ℝ) using 1; simp
  -- deriv of gammaShift q k = composition derivative
  have hcomp : HasDerivAt (gammaShift q k) (deriv Γ ((s + ↑k) / ↑q) * (1 / ↑q)) s := by
    exact (hgamma_diff.hasDerivAt.comp s hg_deriv)
  rw [hcomp.deriv]
  ring

-- Helper: logDeriv of the "numerator" function h(s) = (∏ gammaShift q k s) * q^{s-1/2}
-- Proved via HasDerivAt to avoid eta-expansion issues with finset_prod API.
private lemma logDeriv_mG_numerator (q : ℕ) (hq : 1 ≤ q) (s : ℝ) (hs : 0 < s) :
    let P := fun s => ∏ k ∈ range q, gammaShift q k s
    let R := fun s => (q : ℝ) ^ (s - 1/2)
    let h := fun s => P s * R s
    logDeriv h s = (∑ k ∈ range q, logDeriv (gammaShift q k) s) + Real.log q := by
  intro P R h
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  have hP_ne : P s ≠ 0 := by
    simp only [P]; rw [Finset.prod_ne_zero_iff]
    intro k hk; exact gammaShift_ne_zero q hq k hk s hs
  have hR_ne : R s ≠ 0 := by
    simp only [R]; exact (rpow_pos_of_pos hq_pos _).ne'
  -- Compute HasDerivAt for R
  have hR_deriv : HasDerivAt R (R s * Real.log q) s := by
    simp only [R]
    have := (hasStrictDerivAt_const_rpow hq_pos (s - 1/2)).hasDerivAt
    have hg : HasDerivAt (fun s : ℝ => s - 1/2) 1 s := by
      have := (hasDerivAt_id s).sub (hasDerivAt_const s (1/2 : ℝ))
      simp only [sub_zero] at this; exact this
    have h := this.comp s hg
    simp only [mul_one] at h; exact h
  -- Compute HasDerivAt for each gammaShift
  have hGS_derivs : ∀ k ∈ range q, HasDerivAt (gammaShift q k)
      (deriv (gammaShift q k) s) s := by
    intro k hk
    exact (gammaShift_differentiableAt q hq k hk s hs).hasDerivAt
  -- Compute HasDerivAt for P = ∏ gammaShift
  have hP_deriv : HasDerivAt P
      (∑ k ∈ range q, (∏ j ∈ (range q).erase k, gammaShift q j s) • deriv (gammaShift q k) s) s := by
    exact HasDerivAt.fun_finset_prod hGS_derivs
  -- Compute HasDerivAt for h = P * R
  have hh_deriv : HasDerivAt h
      ((∑ k ∈ range q, (∏ j ∈ (range q).erase k, gammaShift q j s) • deriv (gammaShift q k) s) *
        R s + P s * (R s * Real.log q)) s := by
    exact hP_deriv.mul hR_deriv
  -- logDeriv h s = deriv h s / h s
  rw [logDeriv_apply, hh_deriv.deriv]
  -- Goal: (sum * R s + P s * (R s * log q)) / (P s * R s) = ∑ logDeriv(gammaShift)(s) + log q
  rw [add_div, mul_div_mul_right _ _ hR_ne]
  congr 1
  · -- ∑ (∏_{j≠k} gammaShift q j s) • deriv(gammaShift q k)(s) / P(s)
    --   = ∑ deriv(gammaShift q k)(s) / gammaShift q k s
    rw [Finset.sum_div]
    apply Finset.sum_congr rfl
    intro k hk
    simp only [logDeriv_apply, smul_eq_mul]
    -- LHS: (∏_{j≠k} f_j) * f'_k / P s
    -- RHS: f'_k / f_k
    -- Use: P s = f_k * ∏_{j≠k} f_j
    have hvals : ∀ k ∈ range q, gammaShift q k s ≠ 0 :=
      fun k hk => gammaShift_ne_zero q hq k hk s hs
    have hP_expand : P s = gammaShift q k s * ∏ j ∈ (range q).erase k, gammaShift q j s :=
      (Finset.mul_prod_erase _ _ hk).symm
    rw [show P s = gammaShift q k s * ∏ j ∈ (range q).erase k, gammaShift q j s from hP_expand]
    rw [mul_comm (∏ j ∈ (range q).erase k, gammaShift q j s) (deriv (gammaShift q k) s)]
    rw [mul_div_mul_right _ _ (Finset.prod_ne_zero_iff.mpr (fun j hj => hvals j (Finset.mem_of_mem_erase hj)))]
  · -- P s * (R s * log q) / h s = log q
    -- h s = P s * R s
    show P s * (R s * Real.log q) / (P s * R s) = Real.log q
    have hPR_ne : P s * R s ≠ 0 := mul_ne_zero hP_ne hR_ne
    field_simp

/-- Differentiate log of both sides of gamma_product_formula to get the
    digamma identity in the real setting: since multiplicationGamma q = Γ,
    their logDerivs agree, giving the identity. -/
private lemma real_logDeriv_gamma_product (q : ℕ) (hq : 1 ≤ q) (s : ℝ) (hs : 0 < s) :
    ∑ k ∈ range q, (1 / (q : ℝ)) * logDeriv Real.Gamma ((s + k) / q) =
    -Real.log q + logDeriv Real.Gamma s := by
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  -- Rewrite sum using logDeriv_gammaShift
  have h_sum_rw : ∀ k ∈ range q, (1 / (q : ℝ)) * logDeriv Real.Gamma ((s + k) / q) =
      logDeriv (gammaShift q k) s := by
    intro k _; rw [logDeriv_gammaShift q hq k s hs]
  rw [Finset.sum_congr rfl h_sum_rw]
  -- Goal: ∑ logDeriv(gammaShift q k)(s) = -log q + logDeriv Γ s
  -- Step 1: logDeriv(mG)(s) = logDeriv(Γ)(s)
  have h_eq_fun : ∀ t : ℝ, 0 < t → multiplicationGamma q t = Γ t :=
    fun t ht => multiplicationGamma_eq_Gamma q hq ht
  have h_logDeriv_eq : logDeriv (multiplicationGamma q) s = logDeriv Real.Gamma s := by
    rw [logDeriv_apply, logDeriv_apply, h_eq_fun s hs]
    congr 1
    exact Filter.EventuallyEq.deriv_eq
      (eventually_of_mem (Ioi_mem_nhds hs) (fun t ht => h_eq_fun t ht))
  -- Step 2: logDeriv(mG)(s) = logDeriv(h)(s) where h = P * R
  -- (since mG = h / const, and logDeriv(f/c) = logDeriv(f) for nonzero constant c)
  have hpi_pos : (0 : ℝ) < 2 * Real.pi := by positivity
  have hconst_ne : (2 * Real.pi) ^ (((q:ℝ) - 1) / 2) ≠ 0 := (rpow_pos_of_pos hpi_pos _).ne'
  have h_mG_logDeriv : logDeriv (multiplicationGamma q) s =
      logDeriv (fun s => (∏ k ∈ range q, gammaShift q k s) * (q : ℝ) ^ (s - 1/2)) s := by
    -- mG = h * c⁻¹ where h = P * R, and c is nonzero constant
    have h_fun_eq : multiplicationGamma q = fun s =>
        ((∏ k ∈ range q, gammaShift q k s) * (q : ℝ) ^ (s - 1/2)) *
        ((2 * Real.pi) ^ (((q:ℝ) - 1) / 2))⁻¹ := by
      ext s; simp only [multiplicationGamma, gammaShift, div_eq_mul_inv]
    rw [h_fun_eq, logDeriv_mul_const _ _ (inv_ne_zero hconst_ne)]
  -- Step 3: logDeriv(h)(s) = ∑ logDeriv(gammaShift)(s) + log q
  have h_expand := logDeriv_mG_numerator q hq s hs
  -- Combine: logDeriv(Γ)(s) = ∑ logDeriv(gammaShift)(s) + log q
  linarith [h_logDeriv_eq, h_mG_logDeriv, h_expand]

-- ── The main theorem ──

/-- **THE DIGAMMA MULTIPLICATION FORMULA**: For q ≥ 2 and s > 0:

    ψ(qs) = log(q) + (1/q) · Σ_{k=0}^{q-1} ψ(s + k/q)

    PROOF: Use the proved real logDeriv identity, then lift to Complex.digamma
    via digamma_ofReal (Complex.Gamma_ofReal + conjugation symmetry). -/
theorem digamma_multiplication (q : ℕ) (hq : 2 ≤ q) (s : ℝ) (hs : 0 < s) :
    Complex.digamma ((q:ℂ) * (s:ℂ)) =
    Complex.log (q:ℂ) + (1 / (q:ℂ)) *
      ∑ k ∈ range q, Complex.digamma ((s:ℂ) + (k:ℂ) / (q:ℂ)) := by
  have hq1 : 1 ≤ q := by omega
  have hq_pos : (0 : ℝ) < q := Nat.cast_pos.mpr (by omega)
  -- Helper: positive real → not a non-positive integer
  have pos_not_neg : ∀ x : ℝ, 0 < x → ∀ m : ℕ, x ≠ -(m : ℝ) := by
    intro x hx m; linarith [show (0:ℝ) ≤ (m:ℝ) from Nat.cast_nonneg m]
  -- ═══════════════════════════════════════════════════
  -- STEP 1: Get the real identity at q*s
  -- ═══════════════════════════════════════════════════
  have h_real := real_logDeriv_gamma_product q hq1 (q * s) (by positivity)
  have h_sum_rw : ∀ k ∈ range q, (1 / (q : ℝ)) * logDeriv Real.Gamma ((q * s + ↑k) / ↑q) =
      (1 / (q : ℝ)) * logDeriv Real.Gamma (s + (k : ℝ) / q) := by
    intro k _; congr 1; field_simp
  rw [Finset.sum_congr rfl h_sum_rw] at h_real
  -- h_real: ∑ (1/q) * logDeriv Γ (s + k/q) = -log q + logDeriv Γ (q*s)
  -- ═══════════════════════════════════════════════════
  -- STEP 2: Lift each digamma to ↑(logDeriv Γ ·)
  -- ═══════════════════════════════════════════════════
  have hqs : 0 < q * s := by positivity
  -- LHS
  have h_lhs : Complex.digamma ((q:ℂ) * (s:ℂ)) =
      ↑(logDeriv Real.Gamma (q * s)) := by
    rw [← Complex.ofReal_natCast, ← Complex.ofReal_mul]
    exact digamma_ofReal (q * s) (pos_not_neg _ hqs)
  -- RHS sum terms
  have h_sum_eq : ∑ k ∈ range q, Complex.digamma ((s:ℂ) + (k:ℂ) / (q:ℂ)) =
      ∑ k ∈ range q, (↑(logDeriv Real.Gamma (s + (k : ℝ) / q)) : ℂ) := by
    apply Finset.sum_congr rfl
    intro k _
    have hsk : 0 < s + (k : ℝ) / q :=
      add_pos_of_pos_of_nonneg hs (div_nonneg (Nat.cast_nonneg k) hq_pos.le)
    have := digamma_ofReal (s + (k : ℝ) / q) (pos_not_neg _ hsk)
    push_cast at this ⊢
    exact this
  -- ═══════════════════════════════════════════════════
  -- STEP 3: Show both sides are equal via ofReal cast
  -- ═══════════════════════════════════════════════════
  rw [h_lhs, h_sum_eq]
  -- Rearrange real identity
  have h_rearranged : logDeriv Real.Gamma (q * s) =
      Real.log q + ∑ k ∈ range q, (1 / (q : ℝ)) * logDeriv Real.Gamma (s + (k : ℝ) / q) := by
    linarith
  rw [h_rearranged]
  -- Goal: ↑(log q + ∑ (1/q * logDeriv Γ (s+k/q))) = Complex.log ↑q + 1/↑q * ∑ ↑(logDeriv Γ (s+k/q))
  rw [Complex.ofReal_add, Complex.ofReal_log hq_pos.le]
  congr 1
  -- Goal: ↑(∑ (1/q * logDeriv Γ ...)) = 1/↑q * ∑ ↑(logDeriv Γ ...)
  -- Step 1: distribute ofReal into sum: ↑(∑ f) = ∑ ↑f
  rw [Complex.ofReal_sum]
  -- Step 2: distribute ofReal into each product: ↑(c*x) = ↑c * ↑x
  simp_rw [Complex.ofReal_mul, Complex.ofReal_div, Complex.ofReal_one, Complex.ofReal_natCast]
  -- Step 3: factor: ∑ (c * f(k)) = c * ∑ f(k)
  rw [← Finset.mul_sum]

-- ════════════════════════════════════════════════
-- §5. DIGAMMA SUM IDENTITIES (Gauss formula graduation)
-- ════════════════════════════════════════════════

-- These theorems were moved here from DigammaReflection.lean to
-- avoid a circular import (this file imports DigammaReflection).
-- Together with digamma_reflection_rational (in DigammaReflection),
-- they replace the former gauss_digamma_formula axiom.

-- Finset reindexing helpers

private lemma sum_range_shift_Icc' (q : ℕ) (f : ℕ → ℂ) :
    ∑ k ∈ range q, f (1 + k) = ∑ m ∈ Icc 1 q, f m := by
  apply sum_bij' (fun k _ => 1 + k) (fun m _ => m - 1) <;> simp_all [mem_range, mem_Icc] <;> omega

private lemma sum_Icc_split_last' (q : ℕ) (hq : 2 ≤ q) (f : ℕ → ℂ) :
    ∑ m ∈ Icc 1 q, f m = ∑ m ∈ Icc 1 (q - 1), f m + f q := by
  have : Icc 1 q = Icc 1 (q - 1) ∪ {q} := by
    ext x; simp [mem_Icc]; omega
  rw [this, sum_union]
  · simp
  · simp [Finset.disjoint_left]; omega

/-- **Digamma sum from multiplication formula**:
    Σ_{k=0}^{q-1} ψ((1+k)/q) = q·(ψ(1) - log q).
    Derived from the digamma multiplication formula at s = 1/q. -/
theorem digamma_sum_from_mult (q : ℕ) (hq : 2 ≤ q) :
    ∑ k ∈ range q, Complex.digamma (((1 + k : ℕ):ℂ) / (q:ℂ)) =
    (q:ℂ) * (Complex.digamma 1 - Complex.log (q:ℂ)) := by
  have hq_ne : (q:ℂ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have h := digamma_multiplication q hq (1/(q:ℝ)) (by positivity)
  have hlhs : (q:ℂ) * (↑((1:ℝ)/(q:ℝ)) : ℂ) = 1 := by
    push_cast; exact mul_div_cancel₀ 1 hq_ne
  rw [hlhs] at h
  have hsum : ∀ k ∈ range q,
      Complex.digamma ((↑((1:ℝ)/(q:ℝ)):ℂ) + (k:ℂ) / (q:ℂ)) =
      Complex.digamma (((1 + k : ℕ):ℂ) / (q:ℂ)) := by
    intro k _; congr 1; push_cast; ring
  rw [sum_congr rfl hsum] at h
  have h1 : Complex.digamma 1 - Complex.log (q:ℂ) =
      (1 / (q:ℂ)) * ∑ k ∈ range q, Complex.digamma (((1 + k : ℕ):ℂ) / (q:ℂ)) := by
    linear_combination h
  calc ∑ k ∈ range q, Complex.digamma (((1 + k : ℕ):ℂ) / (q:ℂ))
      = (q:ℂ) * ((1 / (q:ℂ)) * ∑ k ∈ range q, Complex.digamma (((1 + k : ℕ):ℂ) / (q:ℂ))) := by
        rw [← mul_assoc, mul_one_div_cancel hq_ne, one_mul]
    _ = (q:ℂ) * (Complex.digamma 1 - Complex.log (q:ℂ)) := by rw [h1]

/-- **Digamma sum identity**:
    Σ_{m=1}^{q-1} ψ(m/q) = -(q-1)γ - q·log q.
    Key identity derived from the multiplication formula. -/
theorem digamma_sum_identity (q : ℕ) (hq : 2 ≤ q) :
    ∑ m ∈ Icc 1 (q - 1), Complex.digamma ((m:ℂ) / (q:ℂ)) =
    -((q:ℂ) - 1) * ↑(Real.eulerMascheroniConstant : ℝ) -
    (q:ℂ) * Complex.log (q:ℂ) := by
  have h_sum := digamma_sum_from_mult q hq
  rw [sum_range_shift_Icc' q (fun m => Complex.digamma ((m:ℂ) / (q:ℂ)))] at h_sum
  rw [sum_Icc_split_last' q hq] at h_sum
  have hq_ne : (q:ℂ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have h_last : Complex.digamma ((q:ℂ) / (q:ℂ)) = Complex.digamma 1 := by
    congr 1; exact div_self hq_ne
  rw [h_last, Complex.digamma_one] at h_sum
  linear_combination h_sum

-- ════════════════════════════════════════════════
-- AUDIT (updated May 2, 2026 — ZERO SORRY)
-- ════════════════════════════════════════════════

-- DEFINED:
--   ✅ multiplicationGamma     — The q-multiplication auxiliary function
--
-- PROVED (FULLY PROVED):
--   ✅ prod_gamma_shift              — Product shift identity (combinatorial)
--   ✅ multiplicationGamma_add_one   — Functional equation f(s+1) = s·f(s)
--   ✅ multiplicationGamma_log_convex — log∘f convex on (0,∞)
--   ✅ multiplicationGamma_pos       — Positivity on (0,∞)
--   ✅ gamma_product_at_one          — ∏ Γ((1+k)/q) = (2π)^{(q-1)/2}/√q
--       Proof: Combinatorial bijection + Stirling limit + log-injectivity
--   ✅ multiplicationGamma_one       — f(1) = 1
--   ✅ multiplicationGamma_eq_Gamma  — Main theorem via Bohr-Mollerup
--   ✅ gamma_product_formula         — Explicit product form
--   ✅ logDeriv_gammaShift           — logDeriv composition chain
--   ✅ logDeriv_mG_numerator         — logDeriv of product·power
--   ✅ real_logDeriv_gamma_product   — THE REAL DIGAMMA IDENTITY
--   ✅ digamma_ofReal                — Complex.digamma ↑x = ↑(logDeriv Γ x)
--   ✅ digamma_multiplication        — THE COMPLEX DIGAMMA MULTIPLICATION FORMULA
--   ✅ digamma_sum_from_mult         — Σ ψ((1+k)/q) = q·(ψ(1) - log q)
--   ✅ digamma_sum_identity          — Σ_{m=1}^{q-1} ψ(m/q) = -(q-1)γ - q·log q
--
-- ARCHITECTURE:
--   multiplicationGamma_eq_Gamma uses Real.eq_Gamma_of_log_convex (Bohr-Mollerup)
--   which requires: log-convex ✅ + functional equation ✅ + f(1)=1 ✅ + positivity ✅
--   digamma_multiplication lifts via Complex.Gamma_ofReal (Mathlib) + conjugation
--   digamma_sum_identity + digamma_reflection_rational (DigammaReflection.lean)
--   graduate the former gauss_digamma_formula axiom

end Cathedral.Analysis.GammaMultiplication
