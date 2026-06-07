/-
  Cathedral/Geometry/AbelFilterBound.lean

  ## GRADUATING witnessNormSq_ge_third_unfiltered — FULLY PROVED

  ════════════════════════════════════════════════════════════════

  THE PROOF STRATEGY (Abel Summation + Squarefree Density):

  We need: ||v||² ≥ (1/3) · unfilteredTaperSum N

  where ||v||² = Σ_{k sqfree, k≤N-1} f(k)  and  unfilteredTaperSum = Σ_{k=1}^{N-1} f(k)
  with f(k) = (1 - ln(k)/ln(N))².

  The ABEL IDENTITY gives:
    Σ_{k=1}^M a(k)·f(k) = A(M)·f(M) + Σ_{k=1}^{M-1} A(k)·(f(k) - f(k+1))

  With a(k) = μ(k)², A(k) = Q(k) = #{sqfree ≤ k}, and using Q(k) ≥ k/3:
    Σ μ²·f ≥ (M/3)·f(M) + Σ (k/3)·(f(k)-f(k+1))
           = (1/3)·[M·f(M) + Σ k·(f(k)-f(k+1))]
           = (1/3)·Σ f(k)

  STATUS: FULLY PROVED. Zero axioms. Zero sorry.
  Created: June 6, 2026 — Sub-Axiom Graduation Campaign 🛡️
  Graduated: June 7, 2026 — Both sub-axioms proved 🎓
-/

import Cathedral.Geometry.NormLowerBound
import Cathedral.Geometry.SquarefreeCountBound
import Cathedral.Covariance.GCDSignLaw

set_option maxHeartbeats 3200000

noncomputable section
open Real Finset

namespace Cathedral.Geometry.AbelFilterBound

open Cathedral.Vasyunin
open Cathedral.Geometry.NormLowerBound
open Cathedral.Geometry.BernoulliDiagonal
open Cathedral.Geometry.SquarefreeCountBound
open ArithmeticFunction
open scoped ArithmeticFunction.Moebius

-- ════════════════════════════════════════════════════════════════
-- §0. HELPER LEMMAS
-- ════════════════════════════════════════════════════════════════

/-- Splitting an Icc sum: Σ_{Icc 1 (n+1)} f = Σ_{Icc 1 n} f + f(n+1). -/
private lemma sum_Icc_succ_top {f : ℕ → ℝ} {n : ℕ} :
    ∑ k ∈ Icc 1 (n + 1), f k = (∑ k ∈ Icc 1 n, f k) + f (n + 1) := by
  have h_ins : Icc 1 (n + 1) = insert (n + 1) (Icc 1 n) := by
    ext x; simp only [mem_Icc, mem_insert]; omega
  rw [h_ins, sum_insert (by simp only [mem_Icc]; omega)]
  ring

/-- The squarefree indicator sum over Icc equals sqfreeCount (cast to ℝ). -/
private lemma sqfree_indicator_sum_eq_count (n : ℕ) :
    ∑ k ∈ Icc 1 n, (if Squarefree k then (1 : ℝ) else 0) =
    ↑(NormLowerBound.sqfreeCount n) := by
  unfold NormLowerBound.sqfreeCount
  push_cast; simp [Finset.sum_boole]

/-- sqfreeCount recurrence: Q(n+1) = Q(n) + indicator(n+1). -/
private lemma sqfreeCount_succ (n : ℕ) :
    (NormLowerBound.sqfreeCount (n + 1) : ℝ) =
    ↑(NormLowerBound.sqfreeCount n) +
    if Squarefree (n + 1) then 1 else 0 := by
  unfold NormLowerBound.sqfreeCount
  have h_ins : Icc 1 (n + 1) = insert (n + 1) (Icc 1 n) := by
    ext x; simp only [mem_Icc, mem_insert]; omega
  rw [h_ins, Finset.filter_insert]
  split
  · -- Squarefree case
    have h_nmem : n + 1 ∉ (Icc 1 n).filter Squarefree := by
      simp only [Finset.mem_filter, mem_Icc]; omega
    rw [Finset.card_insert_of_notMem h_nmem]
    push_cast; ring
  · -- Not squarefree case
    simp

/-- Möbius squared equals squarefree indicator (for k ≥ 1). -/
private lemma moebius_cast_sq_indicator (k : ℕ) (hk : 1 ≤ k) :
    ((μ k : ℤ) : ℝ) ^ 2 = if Squarefree k then 1 else 0 := by
  by_cases hsf : Squarefree k
  · simp only [hsf, ↓reduceIte]
    exact Cathedral.Covariance.GCDSignLaw.moebius_sq_of_squarefree k hk hsf
  · simp only [hsf, ↓reduceIte]
    rw [ArithmeticFunction.moebius_eq_zero_of_not_squarefree hsf]
    simp

-- ════════════════════════════════════════════════════════════════
-- §1. THE CORE ABEL BOUND (PROVED)
-- ════════════════════════════════════════════════════════════════

/-! ### The Abel computation — Proved by strengthened induction

The mathematical content:

For M = N-1, f(k) = (1-ln(k)/ln(N))², a(k) = μ²(k):

Step 1 (Abel): Σ μ²f = Q(M)f(M) + Σ_{k=1}^{M-1} Q(k)(f(k)-f(k+1))
Step 2 (Q≥k/3):        ≥ (M/3)f(M) + Σ (k/3)(f(k)-f(k+1))
Step 3 (factor 1/3):   = (1/3)[Mf(M) + Σ k(f(k)-f(k+1))]
Step 4 (Abel for 1):   = (1/3) Σ f(k)

Instead of proving the full Abel identity, we use a **strengthened induction**:

Define D(n) = Σ_{Icc 1 n}(sqfree ? f : 0) - Σ_{Icc 1 n} f / 3.

**Strengthened IH**: D(n) ≥ (Q(n) - n/3) · f(n)

Inductive step:
  D(n+1) = D(n) + (w(n+1) - 1/3)·f(n+1)
  ≥ (Q(n) - n/3)·f(n) + (w(n+1) - 1/3)·f(n+1)
  = (Q(n) - n/3)·(f(n) - f(n+1)) + (Q(n+1) - (n+1)/3)·f(n+1)
  ≥ 0 + (Q(n+1) - (n+1)/3)·f(n+1)  ✓

The first term is ≥ 0 because Q(n) ≥ n/3 and f(n) ≥ f(n+1) (antitone).
The second term gives the strengthened IH at n+1. -/

/-- **THE CORE ABEL BOUND** (PROVED): The squarefree-weighted sum of f is at least
    (1/3) of the unweighted sum, for any antitone non-negative f.

    This captures the Abel summation computation:
      Σ μ²(k)·f(k) ≥ (1/3)·Σ f(k)

    using Q(k) ≥ k/3 at each Abel step.

    PROOF: Strengthened induction on the interval length.
    IH: D(n) ≥ (Q(n) - n/3)·f(n), which implies D(n) ≥ 0. -/
theorem sqfree_weighted_ge_third_unweighted (M : ℕ) (hM : 1 ≤ M)
    (f : ℕ → ℝ)
    (hf_nn : ∀ k, 1 ≤ k → k ≤ M → 0 ≤ f k)
    (hf_anti : ∀ k, 1 ≤ k → k < M → f (k + 1) ≤ f k) :
    (∑ k ∈ Icc 1 M, f k) / 3 ≤
    ∑ k ∈ Icc 1 M, (if Squarefree k then f k else 0) := by
  -- Strengthen: prove D(n) ≥ (Q(n) - n/3)·f(n) for all 1 ≤ n ≤ M
  suffices h_key : ∀ n : ℕ, 1 ≤ n → n ≤ M →
      ((NormLowerBound.sqfreeCount n : ℝ) - ↑n / 3) * f n ≤
      ∑ k ∈ Icc 1 n, (if Squarefree k then f k else 0) -
      (∑ k ∈ Icc 1 n, f k) / 3 by
    -- Apply at n = M: D(M) ≥ (Q(M) - M/3) · f(M) ≥ 0
    have hD := h_key M hM (Nat.le_refl M)
    have hQ := sqfreeCount_ge_third_real_proved M hM
    have hfM := hf_nn M hM (Nat.le_refl M)
    -- (Q(M) - M/3) ≥ 0 and f(M) ≥ 0, so product ≥ 0, so D(M) ≥ 0
    have h_prod : 0 ≤ ((NormLowerBound.sqfreeCount M : ℝ) - ↑M / 3) * f M :=
      mul_nonneg (by linarith) hfM
    linarith
  -- Prove by induction on n
  intro n hn hnM
  induction n with
  | zero => omega
  | succ m ih =>
    by_cases hm0 : m = 0
    · -- Base case: n = 1 (m = 0)
      subst hm0
      -- Icc 1 1 = {1}
      simp only [Finset.Icc_self, sum_singleton, squarefree_one, ite_true]
      have hQ1 : NormLowerBound.sqfreeCount 1 = 1 := by
        unfold NormLowerBound.sqfreeCount
        simp only [Finset.Icc_self, Finset.filter_singleton, squarefree_one, ite_true,
          Finset.card_singleton]
      rw [hQ1]; push_cast; linarith
    · -- Inductive step: n = m + 1, m ≥ 1
      have hm1 : 1 ≤ m := by omega
      have hmM : m ≤ M := by omega
      have ih_m := ih hm1 hmM
      -- Split sums: Σ_{Icc 1 (m+1)} = Σ_{Icc 1 m} + term(m+1)
      rw [sum_Icc_succ_top, sum_Icc_succ_top]
      -- Set up the key quantities
      set S_w := ∑ k ∈ Icc 1 m, (if Squarefree k then f k else 0)
      set S_f := ∑ k ∈ Icc 1 m, f k
      set w_ind := if Squarefree (m + 1) then (1 : ℝ) else 0
      -- The conditional term: (if Squarefree (m+1) then f(m+1) else 0) = w_ind * f(m+1)
      have hw_eq : (if Squarefree (m + 1) then f (m + 1) else (0 : ℝ)) =
          w_ind * f (m + 1) := by
        simp only [w_ind]; split <;> simp
      rw [hw_eq]
      -- Q(m+1) = Q(m) + w_ind  (cast to ℝ)
      have hQ_succ := sqfreeCount_succ m
      -- excess(m) = Q(m) - m/3 ≥ 0
      have h_excess_nn : 0 ≤ (NormLowerBound.sqfreeCount m : ℝ) - ↑m / 3 := by
        linarith [sqfreeCount_ge_third_real_proved m hm1]
      -- f(m+1) ≤ f(m) (antitone)
      have hf_le : f (m + 1) ≤ f m := hf_anti m hm1 (by omega)
      -- excess(m) * f(m+1) ≤ excess(m) * f(m)  (nonneg * antitone)
      have h_mono : ((NormLowerBound.sqfreeCount m : ℝ) - ↑m / 3) * f (m + 1) ≤
                    ((NormLowerBound.sqfreeCount m : ℝ) - ↑m / 3) * f m :=
        mul_le_mul_of_nonneg_left hf_le h_excess_nn
      -- Chain: excess(m) * f(m+1) ≤ S_w - S_f/3  (via IH)
      have h_chain : ((NormLowerBound.sqfreeCount m : ℝ) - ↑m / 3) * f (m + 1) ≤
          S_w - S_f / 3 := le_trans h_mono ih_m
      -- Goal: (Q(m+1) - (m+1)/3) * f(m+1) ≤ (S_w + w_ind*f(m+1)) - (S_f + f(m+1))/3
      -- Rewrite Q(m+1) using recurrence
      rw [hQ_succ]
      -- After rewrite, LHS = (Q(m) + w_ind - (m+1)/3) * f(m+1)
      --                    = (excess(m) + w_ind - 1/3) * f(m+1)
      -- RHS = S_w + w_ind*f(m+1) - (S_f + f(m+1))/3
      --     = (S_w - S_f/3) + (w_ind - 1/3)*f(m+1)
      -- So need: excess(m)*f(m+1) ≤ S_w - S_f/3
      -- which is exactly h_chain.
      push_cast
      nlinarith [h_chain]

-- ════════════════════════════════════════════════════════════════
-- §2. CONNECTING witnessNormSq TO SQUAREFREE-FILTERED TAPER SUM
-- ════════════════════════════════════════════════════════════════

/-- The taper function on [1, N-1] is non-negative (trivially: it's a square). -/
theorem taper_nonneg (N k : ℕ) :
    0 ≤ (1 - Real.log ↑k / Real.log ↑N) ^ 2 :=
  sq_nonneg _

/-- The taper function is antitone on [1, N-1]:
    (1-log(k+1)/logN)² ≤ (1-logk/logN)² when 1 ≤ k < N-1. -/
theorem taper_antitone_range (N : ℕ) (hN : 3 ≤ N)
    (k : ℕ) (hk1 : 1 ≤ k) (hk : k < N - 1) :
    (1 - Real.log ↑(k + 1) / Real.log ↑N) ^ 2 ≤
    (1 - Real.log ↑k / Real.log ↑N) ^ 2 := by
  have hN_pos : (1:ℝ) < ↑N := by exact_mod_cast show 1 < N by omega
  have hlogN : 0 < Real.log ↑N := Real.log_pos hN_pos
  have hk_pos : (0:ℝ) < ↑k := Nat.cast_pos.mpr (by omega)
  -- log k ≤ log (k+1)
  have hlog_le : Real.log ↑k ≤ Real.log ↑(k + 1) := by
    apply Real.log_le_log hk_pos
    push_cast; linarith
  -- 1 - log(k+1)/logN ≤ 1 - logk/logN
  have h_quot : 1 - Real.log ↑(k + 1) / Real.log ↑N ≤
      1 - Real.log ↑k / Real.log ↑N := by
    linarith [div_le_div_of_nonneg_right hlog_le hlogN.le]
  -- 0 ≤ 1 - log(k+1)/logN (since k+1 ≤ N-1 < N)
  have h_nn : 0 ≤ 1 - Real.log ↑(k + 1) / Real.log ↑N := by
    rw [sub_nonneg, div_le_one hlogN]
    apply Real.log_le_log (Nat.cast_pos.mpr (by omega))
    push_cast; exact_mod_cast show k + 1 ≤ N by omega
  exact pow_le_pow_left₀ h_nn h_quot 2

-- ════════════════════════════════════════════════════════════════
-- §3. THE WIRING LEMMA: witnessNormSq ↔ Icc sum (PROVED)
-- ════════════════════════════════════════════════════════════════

/-- Each term of the witness norm equals the squarefree-indicator form. -/
private lemma witness_term_eq_indicator (N : ℕ) (_hN : 3 ≤ N) (i : Fin N) :
    (logCutoffWitness N i) ^ 2 =
    if Squarefree (i.val + 1) then
      (1 - Real.log ↑(i.val + 1) / Real.log ↑N) ^ 2
    else 0 := by
  unfold logCutoffWitness moebiusFn
  -- (-(↑μ(i+1)) * taper)² = μ(i+1)² * taper²
  rw [neg_mul, neg_sq, mul_pow]
  -- μ(i+1)² = if Squarefree (i+1) then 1 else 0
  rw [moebius_cast_sq_indicator (i.val + 1) (by omega)]
  split <;> simp

/-- The k=N term vanishes: (1 - logN/logN)² = 0. -/
private lemma taper_vanish_at_N (N : ℕ) (hN : 3 ≤ N) :
    (1 - Real.log ↑N / Real.log ↑N) ^ 2 = (0 : ℝ) := by
  have hlogN : Real.log ↑N ≠ 0 := by
    have : (1:ℝ) < ↑N := by exact_mod_cast show 1 < N by omega
    exact ne_of_gt (Real.log_pos this)
  rw [div_self hlogN, sub_self, zero_pow (by norm_num : 2 ≠ 0)]

/-- **NORM = SQUAREFREE-FILTERED TAPER SUM (Icc version)** (PROVED).

    witnessNormSq N = Σ_{k ∈ Icc 1 (N-1)} (if squarefree k then f(k) else 0)

    This bridges the Fin N sum (in which v_i = -μ(i+1)·taper(i+1))
    to an Icc 1 (N-1) sum with squarefree indicator.

    The key facts:
    1. v_i² = μ(i+1)² · taper(i+1)² and μ²(k) = 1_{sqfree}(k)
    2. For i = N-1 (k=N): taper = 0 so the k=N term vanishes
    3. Fin N ↔ Icc 1 N with shift k = i+1
    4. The k=N term vanishes, so Icc 1 N = Icc 1 (N-1) + 0

    PROVED. Zero sorry. -/
theorem witnessNormSq_eq_sqfree_Icc (N : ℕ) (hN : 3 ≤ N) :
    witnessNormSq N =
    ∑ k ∈ Icc 1 (N - 1),
      (if Squarefree k then
        (1 - Real.log ↑k / Real.log ↑N) ^ 2
      else 0) := by
  -- Step 1: Rewrite each term using the indicator form
  unfold witnessNormSq
  conv_lhs =>
    arg 2; ext i
    rw [witness_term_eq_indicator N hN i]
  -- Step 2: Define the target function
  set g : ℕ → ℝ := fun k =>
    if Squarefree k then (1 - Real.log ↑k / Real.log ↑N) ^ 2 else 0
  -- Step 3: Reindex Fin N → Icc 1 N via k = i.val + 1
  have h_reindex : ∑ i : Fin N, g (i.val + 1) = ∑ k ∈ Icc 1 N, g k := by
    symm
    refine Finset.sum_bij' (fun k _hk => ⟨k - 1, ?_⟩)
      (fun (i : Fin N) _hi => i.val + 1) ?_ ?_ ?_ ?_ ?_
    · -- k - 1 < N (from k ∈ Icc 1 N)
      have hk := Finset.mem_Icc.mp _hk; omega
    · -- i : Icc → univ
      intro k hk; exact Finset.mem_univ _
    · -- j : univ → Icc
      intro i _
      rw [Finset.mem_Icc]
      have := i.isLt
      exact ⟨Nat.succ_le_succ (Nat.zero_le _), this⟩
    · -- left_inv: j (i k hk) = k
      intro k hk; rw [Finset.mem_Icc] at hk; simp; omega
    · -- right_inv: i (j a ha) = a
      intro i _; ext; simp
    · -- h: f k = g (i k hk) — trivially g k = g (k-1+1) = g k
      intro k hk; rw [Finset.mem_Icc] at hk
      show g k = g (k - 1 + 1)
      congr 1; exact (Nat.sub_add_cancel hk.1).symm
  rw [h_reindex]
  -- Step 4: Split Icc 1 N = Icc 1 (N-1) ∪ {N}, peel off g(N) = 0
  have hN_ge1 : 1 ≤ N := by omega
  have h_split : Icc 1 N = Icc 1 (N - 1) ∪ {N} := by
    ext x; simp only [mem_Icc, mem_union, mem_singleton]; omega
  have h_disj : Disjoint (Icc 1 (N - 1)) {N} := by
    simp only [Finset.disjoint_singleton_right, mem_Icc]; omega
  rw [h_split, sum_union h_disj, sum_singleton]
  -- g(N) = 0 because taper(N) = (1 - logN/logN)² = 0
  have hgN : g N = 0 := by
    simp only [g]
    split
    · exact taper_vanish_at_N N hN
    · rfl
  rw [hgN, add_zero]

-- ════════════════════════════════════════════════════════════════
-- §4. THE GRADUATION
-- ════════════════════════════════════════════════════════════════

/-- **THE GRADUATION**: witnessNormSq ≥ unfilteredTaperSum / 3.

    Chain:
    1. unfilteredTaperSum = Σ_{k ∈ Icc 1 (N-1)} f(k)        [definition]
    2. witnessNormSq = Σ_{k ∈ Icc 1 (N-1)} (sqfree ? f(k) : 0)  [wiring]
    3. sqfree_weighted ≥ unweighted/3                          [Abel + Q≥k/3]

    This replaces the axiom witnessNormSq_ge_third_unfiltered. -/
theorem witnessNormSq_ge_third_unfiltered_proved :
    ∀ N : ℕ, 3 ≤ N →
      unfilteredTaperSum N / 3 ≤ witnessNormSq N := by
  intro N hN
  -- Step 1: Rewrite unfilteredTaperSum (definitionally Icc 1 (N-1))
  unfold unfilteredTaperSum
  -- Step 2: Rewrite witnessNormSq via wiring lemma
  rw [witnessNormSq_eq_sqfree_Icc N hN]
  -- Step 3: Apply the Abel bound
  set f : ℕ → ℝ := fun k => (1 - Real.log ↑k / Real.log ↑N) ^ 2
  have hM : 1 ≤ N - 1 := by omega
  exact sqfree_weighted_ge_third_unweighted (N - 1) hM f
    (fun _ _ _ => taper_nonneg N _)
    (fun k hk1 hk => taper_antitone_range N hN k hk1 hk)

-- ════════════════════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit (June 7, 2026 — Sub-Axiom Graduation: Abel Filter Bound)

### Sorry: 0 ✅
### Custom Axioms: 0 ✅ (previously 2, both graduated)

### Theorems PROVED:
| # | Result | Status | Content |
|---|--------|--------|---------|
| 1 | `sqfree_weighted_ge_third_unweighted` | ✅ 🎓 | Abel + Q≥k/3 (was axiom) |
| 2 | `taper_nonneg` | ✅ | f(k) ≥ 0 (trivially: square) |
| 3 | `taper_antitone_range` | ✅ | f(k+1) ≤ f(k) on [1, N-1] |
| 4 | `witnessNormSq_eq_sqfree_Icc` | ✅ 🎓 | Fin→Icc wiring (was axiom) |
| 5 | `witnessNormSq_ge_third_unfiltered_proved` | ✅ | THE TARGET |

### Helper lemmas:
| # | Lemma | Purpose |
|---|-------|---------|
| 1 | `sum_Icc_succ_top` | Σ_{Icc 1 (n+1)} = Σ_{Icc 1 n} + f(n+1) |
| 2 | `sqfreeCount_succ` | Q(n+1) = Q(n) + indicator(n+1) |
| 3 | `moebius_cast_sq_indicator` | μ(k)² = if Squarefree k then 1 else 0 |
| 4 | `witness_term_eq_indicator` | v_i² = indicator(i+1) · taper² |
| 5 | `taper_vanish_at_N` | (1-logN/logN)² = 0 |

### The Chain (now fully proved):
```
sqfreeCount_ge_third_proved: Q(k) ≥ k/3    [PROVED: SquarefreeCountBound]
    ↓ Strengthened induction (Abel bound)
sqfree_weighted_ge_third_unweighted         [PROVED ✅ 🎓]
    ↓ + witnessNormSq_eq_sqfree_Icc         [PROVED ✅ 🎓]
    ↓ + taper_nonneg, taper_antitone_range  [PROVED]
witnessNormSq_ge_third_unfiltered_proved    [PROVED ✅]
```

### Dependency: moebius_sq_of_squarefree (from GCDSignLaw.lean, PROVED)
-/

end Cathedral.Geometry.AbelFilterBound

end
