/-
  Cathedral/NymanBeurling/Antitone.lean

  ## Monotonicity of the Nyman-Beurling Distance

  The NB distance d²_N = inf_v ∫₀¹ (1 - bdLinComb N v)² is non-increasing
  in N, because adding more basis elements can only improve the approximation.

  This enables the **subsequential proof strategy**: if d²_{N_m} → 0 along
  ANY unbounded subsequence N_m → ∞, then d²_N → 0 for all N, and
  therefore RH holds by nyman_beurling_converse.

  ### Key results
  - `bdLinComb_zeroExtend`: zero-padding preserves the linear combination
  - `nb_witness_embed`: any N-witness embeds into M ≥ N with same L² error
  - `nb_subseq_implies_full`: subsequential d²→0 implies full d²→0

  ### Architecture
  ```
  bdLinComb_zeroExtend (PROVED — Finset sum splitting)
       ↓
  nb_witness_embed (PROVED — existential wrapping)
       ↓
  nb_subseq_implies_full (PROVED — squeeze argument)
       ↓
  gram_bound_subseq_implies_rh (THEOREM — feeds nyman_beurling_converse)
  ```

  Status: PROVED target. Zero axioms (uses only Separation.lean infrastructure).
-/

import Cathedral.NymanBeurling.BDMellin
import Cathedral.NymanBeurling.Separation

noncomputable section
open Real MeasureTheory Filter Finset

-- ════════════════════════════════════════════════
-- §1. ZERO-EXTENSION OF WITNESSES
-- ════════════════════════════════════════════════

/-- Zero-extend a witness vector from Fin n to Fin m (n ≤ m).
    The new coordinates are set to 0. -/
def zeroExtendWitness {n m : ℕ} (_h : n ≤ m) (v : Fin n → ℝ) : Fin m → ℝ :=
  fun i => if hi : i.val < n then v ⟨i.val, hi⟩ else 0

/-- The zero extension agrees with the original on the embedded indices. -/
lemma zeroExtendWitness_apply_lt {n m : ℕ} (h : n ≤ m) (v : Fin n → ℝ)
    (i : Fin m) (hi : i.val < n) :
    zeroExtendWitness h v i = v ⟨i.val, hi⟩ := by
  simp [zeroExtendWitness, hi]

/-- The zero extension is zero on the new indices. -/
lemma zeroExtendWitness_apply_ge {n m : ℕ} (h : n ≤ m) (v : Fin n → ℝ)
    (i : Fin m) (hi : ¬ i.val < n) :
    zeroExtendWitness h v i = 0 := by
  simp [zeroExtendWitness, hi]

-- ════════════════════════════════════════════════
-- §2. SUM SPLITTING OVER Fin
-- ════════════════════════════════════════════════

/-- Core lemma: a sum over Fin m of a zero-extended function equals
    the sum over Fin n of the original function.

    ∑_{i : Fin m} (if i < n then f(i) else 0) = ∑_{i : Fin n} f(i)

    Proved by induction on the difference m - n. -/
lemma sum_fin_zeroExtend {n m : ℕ} (h : n ≤ m) (f : Fin n → ℝ) :
    ∑ i : Fin m, (if hi : i.val < n then f ⟨i.val, hi⟩ else 0) =
    ∑ i : Fin n, f i := by
  -- We prove by induction on m
  induction m with
  | zero =>
    have hn : n = 0 := Nat.eq_zero_of_le_zero h
    subst hn; simp
  | succ m ih =>
    rcases Nat.eq_or_lt_of_le h with h_eq | h_lt
    · -- Case n = m + 1: all indices satisfy i.val < n
      subst h_eq
      congr 1; ext i
      simp [i.isLt]
    · -- Case n ≤ m: split off the last index
      have hle : n ≤ m := Nat.lt_succ_iff.mp h_lt
      rw [Fin.sum_univ_castSucc]
      -- The last term: (Fin.last m).val = m ≥ n, so dite gives 0
      have h_last : ¬ (↑(Fin.last m) : ℕ) < n := by
        simp [Fin.val_last]; omega
      rw [dif_neg h_last, add_zero]
      -- Each castSucc term: castSucc preserves .val
      conv_lhs =>
        arg 2; ext i
        rw [show (↑(Fin.castSucc i) : ℕ) = (↑i : ℕ) from Fin.val_castSucc i]
      exact ih hle

-- ════════════════════════════════════════════════
-- §3. BDLINCOMB ZERO-EXTENSION
-- ════════════════════════════════════════════════

/-- **KEY LEMMA**: Zero-extending a witness preserves bdLinComb pointwise.

    If v : Fin(N-1) → ℝ and N ≤ M, then
      bdLinComb M (zeroExtend v) x = bdLinComb N v x

    Proof: the extra basis terms have coefficient 0, so they vanish. -/
theorem bdLinComb_zeroExtend (N M : ℕ) (hNM : N ≤ M) (v : Fin (N - 1) → ℝ) (x : ℝ) :
    bdLinComb M (zeroExtendWitness (Nat.sub_le_sub_right hNM 1) v) x =
    bdLinComb N v x := by
  unfold bdLinComb
  -- Goal: ∑_{i : Fin(M-1)} (zeroExtend v) i * {1/((i+1)x)}
  --     = ∑_{i : Fin(N-1)} v i * {1/((i+1)x)}
  -- Factor: ∑ (if i < N-1 then v(i) else 0) * basis(i)
  --       = ∑ (if i < N-1 then v(i) * basis(i) else 0)
  --       = ∑_{i : Fin(N-1)} v(i) * basis(i)
  have h_rw : ∀ i : Fin (M - 1),
      zeroExtendWitness (Nat.sub_le_sub_right hNM 1) v i *
        Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) =
      if hi : i.val < N - 1
      then v ⟨i.val, hi⟩ * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))
      else 0 := by
    intro i
    simp only [zeroExtendWitness]
    split_ifs with h
    · rfl
    · simp
  rw [show ∑ i : Fin (M - 1),
        zeroExtendWitness (Nat.sub_le_sub_right hNM 1) v i *
          Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)) =
      ∑ i : Fin (M - 1),
        (if hi : i.val < N - 1
         then v ⟨i.val, hi⟩ * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))
         else 0) from
    Finset.sum_congr rfl (fun i _ => h_rw i)]
  -- Now apply sum_fin_zeroExtend with f(i) = v(i) * basis(i)
  exact sum_fin_zeroExtend (Nat.sub_le_sub_right hNM 1)
    (fun i => v i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x)))

-- ════════════════════════════════════════════════
-- §4. WITNESS EMBEDDING (MONOTONICITY)
-- ════════════════════════════════════════════════

/-- **MONOTONICITY**: Any witness at scale N embeds into scale M ≥ N
    with identical L² error.

    Given v : Fin(N-1) → ℝ with ∫(1-f_N)² = E, there exists
    v' : Fin(M-1) → ℝ with ∫(1-f_M)² = E.

    This is the pointwise version of d²_M ≤ d²_N. -/
theorem nb_witness_embed (N M : ℕ) (hNM : N ≤ M) (v : Fin (N - 1) → ℝ) :
    ∃ v' : Fin (M - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb M v' x) ^ 2 =
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 := by
  refine ⟨zeroExtendWitness (Nat.sub_le_sub_right hNM 1) v, ?_⟩
  congr 1; ext x
  rw [bdLinComb_zeroExtend N M hNM v x]

-- ════════════════════════════════════════════════
-- §5. SUBSEQUENTIAL CONVERGENCE → FULL CONVERGENCE
-- ════════════════════════════════════════════════

/-- **SUBSEQUENTIAL CONVERGENCE**: If the L² error is small along
    any unbounded subsequence, it is small for all sufficiently large N.

    This is the key lemma enabling the HC-number proof strategy:
    we only need to verify the Gram bound along highly composite numbers.

    Proof: Given ε > 0, pick m₀ from the subsequence hypothesis.
    For any N ≥ Ns(m₀), embed the Ns(m₀)-witness into Fin(N-1)
    via zero-padding (nb_witness_embed). The L² error is preserved. -/
theorem nb_subseq_implies_full
    (Ns : ℕ → ℕ) (_hTend : Tendsto Ns atTop atTop)
    (h_sub : ∀ ε > 0, ∃ m₀ : ℕ, ∀ m ≥ m₀,
      ∃ v : Fin (Ns m - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb (Ns m) v x) ^ 2 < ε) :
    ∀ ε > 0, ∃ N₀ : ℕ, ∀ N ≥ N₀,
      ∃ v : Fin (N - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x) ^ 2 < ε := by
  intro ε hε
  -- Step 1: Get m₀ from the subsequential hypothesis
  obtain ⟨m₀, hm₀⟩ := h_sub ε hε
  -- Step 2: Set N₀ = Ns(m₀) — any N ≥ N₀ satisfies N ≥ Ns(m₀)
  refine ⟨Ns m₀, fun N hN => ?_⟩
  -- Step 3: Get the witness at Ns(m₀)
  obtain ⟨v, hv⟩ := hm₀ m₀ le_rfl
  -- Step 4: Embed it into scale N ≥ Ns(m₀)
  obtain ⟨v', hv'⟩ := nb_witness_embed (Ns m₀) N hN v
  exact ⟨v', hv' ▸ hv⟩

-- ════════════════════════════════════════════════
-- §6. SUBSEQUENTIAL GRAM BOUND → RH
-- ════════════════════════════════════════════════

/-- **COROLLARY**: Subsequential NB convergence implies RH.

    Chains nb_subseq_implies_full with nyman_beurling_converse. -/
theorem nb_subseq_convergence_implies_rh
    (Ns : ℕ → ℕ) (_hTend : Tendsto Ns atTop atTop)
    (h_sub : ∀ ε > 0, ∃ m₀ : ℕ, ∀ m ≥ m₀,
      ∃ v : Fin (Ns m - 1) → ℝ,
        ∫ x in (0:ℝ)..1, (1 - bdLinComb (Ns m) v x) ^ 2 < ε) :
    RiemannHypothesis :=
  nyman_beurling_converse (nb_subseq_implies_full Ns _hTend h_sub)

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit

### Zero axioms (beyond what Separation.lean uses).

### Key results:
1. `bdLinComb_zeroExtend`: pointwise equality under zero-padding
2. `nb_witness_embed`: existential version (same L² error at larger N)
3. `nb_subseq_implies_full`: subsequential ε-δ implies full ε-δ
4. `nb_subseq_convergence_implies_rh`: chains into NB converse for RH

### Architecture:
```
  bdLinComb_zeroExtend (PROVED — Finset sum splitting)
       ↓
  nb_witness_embed (PROVED — existential wrapping)
       ↓
  nb_subseq_implies_full (PROVED — monotonicity argument)
       ↓
  nb_subseq_convergence_implies_rh (PROVED — chains NB converse)
       ↓
  RiemannHypothesis
```

### Why this matters:
The current axiom (gram_form_upper_bound_direct) requires vᵀGv ≤ 1 + K/lnN
for ALL large N. This file enables weakening it to hold along ANY unbounded
subsequence (e.g., highly composite numbers), where the Möbius witness
achieves better cancellation due to richer GCD structure.
-/

end
