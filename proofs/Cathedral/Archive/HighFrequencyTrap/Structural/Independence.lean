/-
  Cathedral/Structural/Independence.lean

  ## NB linear independence and positive definiteness.

  Proves that the fractional-part functions {k/x} are linearly independent
  in L²(0,1), which implies the Gram matrix is positive definite.

  Core results:
  - fract_eq_sub (floor computation on intervals)
  - nbLinComb_neg_interval (floor jump witness)
  - nbLinComb_nonzero_somewhere (NB is nonzero for w ≠ 0)
  - nyman_beurling_lin_indep (∫ f² > 0)
  - gram_pos_def (wᵀGw > 0)
  - gram_positive_definite (λ_min > 0)
  - gramMatrix_det_ne_zero
-/

import Cathedral.Defs
import Cathedral.Archive.HighFrequencyTrap.Spectral.RayleighBridge
import Cathedral.Archive.HighFrequencyTrap.Structural.NbLinComb

noncomputable section
open Complex Real

-- ════════════════════════════════════════════════
-- FLOOR COMPUTATIONS ON INTERVALS
-- ════════════════════════════════════════════════

/-- On (n/(n+1), 1) with m ≤ n ≥ 1, {m/x} = m/x - m. -/
theorem fract_eq_sub {n m : ℕ} (hm : m ≤ n) (hn : 1 ≤ n)
    {x : ℝ} (hx_lo : (n : ℝ) / (↑n + 1) < x) (hx_hi : x < 1) :
    Int.fract ((m : ℝ) / x) = (m : ℝ) / x - (m : ℝ) := by
  have hx_pos : 0 < x := by linarith [show (0:ℝ) < ↑n / (↑n + 1) by positivity]
  have h1 : (m : ℝ) * x ≤ ↑m := by nlinarith
  have hn_ineq : (↑n : ℝ) < x * (↑n + 1) :=
    (div_lt_iff₀ (by positivity : (0:ℝ) < ↑n + 1)).mp hx_lo
  have hm_cross : (m : ℝ) * (↑n + 1) ≤ ↑n * (↑m + 1) := by
    have : (m : ℝ) ≤ ↑n := by exact_mod_cast hm
    nlinarith
  have h2 : ↑m < (↑m + 1) * x := by nlinarith
  have h_floor : ⌊(m : ℝ) / x⌋ = (m : ℤ) := by
    rw [Int.floor_eq_iff]
    constructor
    · push_cast; rw [le_div_iff₀ hx_pos]; linarith
    · push_cast; rw [div_lt_iff₀ hx_pos]; linarith
  simp only [Int.fract, h_floor]; push_cast; ring

/-- On (n'/(n'+1), 1), nbLinComb = A·(1/x - 1) where A = Σ wᵢ(i+1). -/
private lemma nbLinComb_eq_affine (N : ℕ) (w : Fin (N - 1) → ℝ)
    (n' : ℕ) (hn' : 1 ≤ n')
    (hw_zero : ∀ i : Fin (N - 1), n' < i.val + 1 → w i = 0)
    (x : ℝ) (hx_lo : (n' : ℝ) / (↑n' + 1) < x) (hx_hi : x < 1) :
    nbLinComb N w x = (∑ i : Fin (N - 1), w i * (↑(i.val + 1) : ℝ)) * (1/x - 1) := by
  have hx_pos : 0 < x := by linarith [show (0:ℝ) < ↑n' / (↑n' + 1) by positivity]
  unfold nbLinComb; rw [Finset.sum_mul]; congr 1; ext ⟨i, hi⟩
  by_cases h : i + 1 ≤ n'
  · rw [fract_eq_sub h hn' hx_lo hx_hi]; field_simp
  · push Not at h; rw [hw_zero ⟨i, hi⟩ h]; simp

/-- Floor on shifted interval: On ((n-1)/n, n/(n+1)) with m+1 ≤ n, {m/x} = m/x - m. -/
private theorem fract_eq_sub_shifted {n m : ℕ} (hm : m + 1 ≤ n) (hn : 2 ≤ n)
    {x : ℝ} (hx_lo : ((n : ℝ) - 1) / ↑n < x) (hx_hi : x < ↑n / (↑n + 1)) :
    Int.fract ((m : ℝ) / x) = (m : ℝ) / x - (m : ℝ) := by
  have hn_pos : (0 : ℝ) < ↑n := by exact_mod_cast show 0 < n by omega
  have hx_pos : 0 < x := by
    have h1 : (1 : ℝ) ≤ ↑n := by exact_mod_cast show 1 ≤ n by omega
    have : (0 : ℝ) ≤ (↑n - 1) / ↑n := div_nonneg (by linarith) (by linarith)
    linarith
  have hx_lt_one : x < 1 := by
    calc x < ↑n / (↑n + 1) := hx_hi
    _ < 1 := by rw [div_lt_one (by linarith)]; linarith
  have h_lower : (m : ℝ) ≤ ↑m / x := by
    rw [le_div_iff₀ hx_pos]; nlinarith
  have h_upper : (m : ℝ) / x < ↑m + 1 := by
    rw [div_lt_iff₀ hx_pos]
    have hmn : (m : ℝ) ≤ ↑n - 1 := by
      have : (m : ℝ) + 1 ≤ ↑n := by exact_mod_cast hm
      linarith
    nlinarith [(div_lt_iff₀ hn_pos).mp hx_lo]
  have h_floor : ⌊(m : ℝ) / x⌋ = (m : ℤ) := by
    rw [Int.floor_eq_iff]
    constructor
    · push_cast; linarith
    · push_cast; linarith
  simp only [Int.fract, h_floor]; push_cast; ring

/-- Floor jump: On ((n-1)/n, n/(n+1)) with n ≥ 2, {n/x} = n/x - (n+1). -/
private theorem fract_eq_sub_jump {n : ℕ} (hn : 2 ≤ n)
    {x : ℝ} (hx_lo : ((n : ℝ) - 1) / ↑n < x) (hx_hi : x < ↑n / (↑n + 1)) :
    Int.fract ((n : ℝ) / x) = (n : ℝ) / x - (↑n + 1) := by
  have hn_pos : (0 : ℝ) < ↑n := by exact_mod_cast show 0 < n by omega
  have hx_pos : 0 < x := by
    have h1 : (1 : ℝ) ≤ ↑n := by exact_mod_cast show 1 ≤ n by omega
    have : (0 : ℝ) ≤ (↑n - 1) / ↑n := div_nonneg (by linarith) (by linarith)
    linarith
  have h_lower : (n : ℝ) + 1 ≤ ↑n / x := by
    rw [le_div_iff₀ hx_pos]
    have hn1 : (0 : ℝ) < ↑n + 1 := by linarith
    have : x * (↑n + 1) < ↑n := by
      rwa [lt_div_iff₀ hn1] at hx_hi
    linarith
  have h_upper : (n : ℝ) / x < ↑n + 2 := by
    rw [div_lt_iff₀ hx_pos]
    have hxn : (↑n - 1) < x * ↑n := by
      have := (div_lt_iff₀ hn_pos).mp hx_lo; linarith
    have h_prod : (↑n + 2) * (↑n - 1) < (↑n + 2) * (x * ↑n) :=
      mul_lt_mul_of_pos_left hxn (by linarith)
    by_contra h; push Not at h
    have h_mul_n : (↑n + 2) * x * ↑n ≤ ↑n * ↑n :=
      mul_le_mul_of_nonneg_right h (le_of_lt hn_pos)
    have h_assoc : (↑n + 2) * (x * ↑n) = (↑n + 2) * x * ↑n := by ring
    have hn_ge : (2 : ℝ) ≤ ↑n := by exact_mod_cast hn
    nlinarith [h_assoc]
  have h_floor : ⌊(n : ℝ) / x⌋ = (↑n + 1 : ℤ) := by
    rw [Int.floor_eq_iff]
    constructor
    · push_cast; linarith
    · push_cast; linarith
  simp only [Int.fract, h_floor]; push_cast; ring

-- ════════════════════════════════════════════════
-- NB FLOOR JUMP AND LINEAR INDEPENDENCE
-- ════════════════════════════════════════════════

/-- When A = Σ wᵢ(i+1) = 0, nbLinComb ≡ -w_{j₀} on an open subinterval. -/
theorem nbLinComb_neg_interval (N : ℕ) (w : Fin (N - 1) → ℝ) (j₀ : Fin (N - 1))
    (hw_above : ∀ i : Fin (N - 1), j₀ < i → w i = 0)
    (hA : (∑ i : Fin (N - 1), w i * (↑(i.val + 1) : ℝ)) = 0)
    (hwj₀ : w j₀ ≠ 0) :
    ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
    ∀ x, x ∈ Set.Ioo c d → nbLinComb N w x = -(w j₀) := by
  have hj₀_pos : 1 ≤ j₀.val := by
    by_contra h; push Not at h
    have hj₀_zero : j₀.val = 0 := by omega
    have hw_rest : ∀ i : Fin (N - 1), i ≠ j₀ → w i = 0 := by
      intro i hi
      by_cases hlt : j₀ < i
      · exact hw_above i hlt
      · push Not at hlt
        exfalso; apply hi; exact Fin.ext (by omega)
    have : (∑ i : Fin (N - 1), w i * (↑(i.val + 1) : ℝ)) = w j₀ * 1 := by
      have h_terms : ∀ i : Fin (N - 1), w i * (↑(i.val + 1) : ℝ) =
          if i = j₀ then w j₀ * 1 else 0 := by
        intro i; by_cases heq : i = j₀
        · subst heq; simp [hj₀_zero]
        · rw [hw_rest i heq, zero_mul, if_neg heq]
      simp_rw [h_terms]; simp
    rw [this, mul_one] at hA; exact hwj₀ hA
  set n' := j₀.val + 1
  have hn' : 2 ≤ n' := by omega
  have hn'_pos : (0 : ℝ) < ↑n' := by exact_mod_cast show 0 < n' by omega
  refine ⟨(↑n' - 1) / ↑n', ↑n' / (↑n' + 1),
    div_nonneg (by linarith [show (1:ℝ) ≤ ↑n' from by exact_mod_cast show 1 ≤ n' by omega]) (le_of_lt hn'_pos),
    ?_, ?_, ?_⟩
  · rw [div_lt_div_iff₀ hn'_pos (show (0:ℝ) < ↑n' + 1 by linarith)]
    nlinarith
  · rw [div_le_one (by linarith : (0:ℝ) < ↑n' + 1)]
    linarith
  · intro x ⟨hx_lo, hx_hi⟩
    have hx_pos : 0 < x := by
      have : (0 : ℝ) ≤ (↑n' - 1) / ↑n' := div_nonneg
        (by linarith [show (1:ℝ) ≤ ↑n' from by exact_mod_cast show 1 ≤ n' by omega])
        (le_of_lt hn'_pos)
      linarith
    unfold nbLinComb
    have h_term : ∀ i : Fin (N - 1),
        w i * Int.fract ((↑(i.val + 1) : ℝ) / x) =
        if j₀ < i then 0
        else if i = j₀ then w j₀ * ((↑n' : ℝ) / x - (↑n' + 1))
        else w i * ((↑(i.val + 1) : ℝ) / x - ↑(i.val + 1)) := by
      intro i
      by_cases hi_above : j₀ < i
      · simp only [hi_above, ↓reduceIte, hw_above i hi_above, zero_mul]
      · push Not at hi_above
        simp only [show ¬(j₀ < i) from not_lt.mpr hi_above, ↓reduceIte]
        by_cases hi_eq : i = j₀
        · subst hi_eq; simp only [↓reduceIte]
          congr 1
          exact fract_eq_sub_jump hn' hx_lo hx_hi
        · have hi_lt : i < j₀ := lt_of_le_of_ne hi_above hi_eq
          simp only [hi_eq, ↓reduceIte]
          congr 1
          have hm : i.val + 1 + 1 ≤ n' := by omega
          exact fract_eq_sub_shifted hm hn' hx_lo hx_hi
    simp_rw [h_term]
    have h_split : ∀ i : Fin (N - 1),
        (if j₀ < i then (0 : ℝ)
         else if i = j₀ then w j₀ * ((↑n' : ℝ) / x - (↑n' + 1))
         else w i * ((↑(i.val + 1) : ℝ) / x - ↑(i.val + 1))) =
        (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 1)) / x -
        (if j₀ < i then (0 : ℝ) else if i = j₀ then w j₀ * (↑n' + 1)
         else w i * ↑(i.val + 1)) := by
      intro i; split_ifs with h1 h2
      · simp
      · subst h2; field_simp; ring
      · field_simp
    simp_rw [h_split, Finset.sum_sub_distrib]
    have hA_ite : ∑ i : Fin (N - 1), (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 1)) = 0 := by
      trans ∑ i : Fin (N - 1), w i * ↑(i.val + 1)
      · congr 1; ext i; split_ifs with h
        · simp [hw_above i h]
        · rfl
      · exact hA
    have h_sum_div : (∑ i : Fin (N - 1), (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 1)) / x) = 0 := by
      rw [show (∑ i : Fin (N - 1), (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 1)) / x) =
        (∑ i : Fin (N - 1), (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 1))) / x from
        (Finset.sum_div Finset.univ _ x).symm]
      rw [hA_ite, zero_div]
    rw [h_sum_div, zero_sub, neg_eq_iff_eq_neg, neg_neg]
    have h_each : ∀ i : Fin (N - 1),
        (if j₀ < i then (0 : ℝ) else if i = j₀ then w j₀ * (↑n' + 1)
         else w i * ↑(i.val + 1)) =
        (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 1)) +
        (if i = j₀ then w j₀ else 0) := by
      intro i; by_cases h1 : j₀ < i
      · simp only [h1, ite_true]
        have : i ≠ j₀ := ne_of_gt h1
        simp [this]
      · push Not at h1
        simp only [show ¬(j₀ < i) from not_lt.mpr h1, ite_false]
        by_cases h2 : i = j₀
        · subst h2; simp only [ite_true, n']; ring
        · simp [h2]
    simp_rw [h_each, Finset.sum_add_distrib, hA_ite, zero_add,
      Finset.sum_ite_eq', Finset.mem_univ, ite_true]

/-- If w ≠ 0, nbLinComb is nonzero on some open subinterval of (0,1). -/
theorem nbLinComb_nonzero_somewhere (N : ℕ) (_ : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
    (∀ x, x ∈ Set.Ioo c d → nbLinComb N w x ≠ 0) := by
  have hw_exists : ∃ i : Fin (N - 1), w i ≠ 0 := by
    by_contra h; push Not at h; exact hw (funext h)
  let S := Finset.filter (fun i : Fin (N - 1) => w i ≠ 0) Finset.univ
  have hS : S.Nonempty := by
    obtain ⟨i, hi⟩ := hw_exists
    exact ⟨i, Finset.mem_filter.mpr ⟨Finset.mem_univ _, hi⟩⟩
  set j₀ := S.max' hS
  have hwj₀ : w j₀ ≠ 0 := (Finset.mem_filter.mp (Finset.max'_mem S hS)).2
  have hw_above : ∀ i : Fin (N - 1), j₀ < i → w i = 0 := by
    intro i hi; by_contra h
    exact absurd (Finset.le_max' S i (Finset.mem_filter.mpr ⟨Finset.mem_univ _, h⟩))
      (not_le.mpr hi)
  set n' := j₀.val + 1
  have hn' : 1 ≤ n' := by omega
  have hn'_pos : (0 : ℝ) < ↑n' := by exact_mod_cast show 0 < n' by omega
  set A := ∑ i : Fin (N - 1), w i * (↑(i.val + 1) : ℝ)
  by_cases hA : A ≠ 0
  · refine ⟨↑n' / (↑n' + 1), 1, le_of_lt (by positivity),
      by rw [div_lt_one (by linarith)]; linarith, le_refl 1, ?_⟩
    intro x ⟨hx_lo, hx_hi⟩
    rw [nbLinComb_eq_affine N w n' hn'
      (fun i hi => hw_above i (by
        show j₀ < i
        exact Fin.lt_def.mpr (by omega))) x hx_lo hx_hi]
    exact mul_ne_zero hA (by
      have hx_pos : 0 < x := by linarith [show (0:ℝ) < ↑n' / (↑n' + 1) by positivity]
      linarith [show 1 < 1/x from by rw [one_div]; exact one_lt_inv_iff₀.mpr ⟨hx_pos, hx_hi⟩])
  · push Not at hA
    obtain ⟨c, d, hc, hcd, hd, heq⟩ := nbLinComb_neg_interval N w j₀ hw_above hA hwj₀
    exact ⟨c, d, hc, hcd, hd, fun x hx => by rw [heq x hx]; exact neg_ne_zero.mpr hwj₀⟩

-- ════════════════════════════════════════════════
-- INTEGRABILITY AND POSITIVE DEFINITENESS
-- ════════════════════════════════════════════════

/-- nbLinComb² is integrable on [0,1]. -/
theorem nbLinComb_sq_integrable (N : ℕ) (w : Fin (N - 1) → ℝ) :
    IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume 0 1 := by
  have h_sq : (fun x => (nbLinComb N w x) ^ 2) =
      (fun x => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) := by
    ext x; unfold nbLinComb; rw [sq, Finset.sum_mul_sum]
  rw [h_sq]
  have : (fun x : ℝ => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
      (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) =
    (∑ i : Fin (N - 1), ∑ j : Fin (N - 1), fun x =>
      (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
      (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) := by
    ext x; simp [Finset.sum_apply]
  rw [this]
  apply IntervalIntegrable.sum; intro i _
  apply IntervalIntegrable.sum; intro j _
  have : (fun x : ℝ => (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
      (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) =
    (fun x : ℝ => (w i * w j) * (Int.fract ((↑(i.val + 1) : ℝ) / x) *
      Int.fract ((↑(j.val + 1) : ℝ) / x))) := by ext x; ring
  rw [this]
  exact (fract_prod_intervalIntegrable (i.val + 1) (j.val + 1)).const_mul _

/-- **NB linear independence**: ∫₀¹ (Σ wᵢ{(i+1)/x})² dx > 0 for w ≠ 0. -/
theorem nyman_beurling_lin_indep (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    0 < ∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2 := by
  obtain ⟨c, d, hc0, hcd, hd1, hne⟩ := nbLinComb_nonzero_somewhere N hN w hw
  have hpos_sub : ∀ x, x ∈ Set.Ioo c d → 0 < (nbLinComb N w x) ^ 2 :=
    fun x hx => sq_pos_of_ne_zero (hne x hx)
  have hisub : IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume c d :=
    (nbLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le (le_of_lt hcd), Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc hc0 hd1)
  have hint_sub : 0 < ∫ x in c..d, (nbLinComb N w x) ^ 2 :=
    intervalIntegral.intervalIntegral_pos_of_pos_on hisub hpos_sub hcd
  have hi0c : IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume 0 c :=
    (nbLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le hc0, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc le_rfl (hcd.le.trans hd1))
  have hid1 : IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume d 1 :=
    (nbLinComb_sq_integrable N w).mono_set (by
      simp only [Set.uIcc_of_le hd1, Set.uIcc_of_le (zero_le_one)]
      exact Set.Icc_subset_Icc (hc0.trans hcd.le) le_rfl)
  have h_01 : (∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2) =
    (∫ x in (0:ℝ)..c, (nbLinComb N w x) ^ 2) +
    (∫ x in c..d, (nbLinComb N w x) ^ 2) +
    (∫ x in d..1, (nbLinComb N w x) ^ 2) := by
    have h1 := intervalIntegral.integral_add_adjacent_intervals hi0c hisub
    have h2 := intervalIntegral.integral_add_adjacent_intervals (hi0c.trans hisub) hid1
    linarith
  rw [h_01]
  have h1 : 0 ≤ ∫ x in (0:ℝ)..c, (nbLinComb N w x) ^ 2 :=
    intervalIntegral.integral_nonneg hc0 (fun x _ => sq_nonneg _)
  have h2 : 0 ≤ ∫ x in d..1, (nbLinComb N w x) ^ 2 :=
    intervalIntegral.integral_nonneg hd1 (fun x _ => sq_nonneg _)
  linarith

/-- **gram_pos_def**: wᵀGw > 0 for w ≠ 0. -/
theorem gram_pos_def (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    0 < realQuadForm (gramMatrix N) w := by
  rw [gram_l2_identity N hN w]
  exact nyman_beurling_lin_indep N hN w hw

/-- **The Gram matrix is positive definite** for N ≥ 2: λ_min > 0. -/
theorem gram_positive_definite (N : ℕ) (hN : 2 ≤ N) : 0 < lambdaMin N := by
  unfold lambdaMin
  simp only [show N ≥ 2 from hN, dite_true]
  exact pos_def_implies_min_eigenvalue_pos
    (gramMatrix_hermitian N)
    (by omega)
    (fun v hv => gram_pos_def N hN v hv)

theorem lambdaMin_pos (N : ℕ) (hN : 2 ≤ N) : 0 < lambdaMin N :=
  gram_positive_definite N hN

/-- det(G) ≠ 0 for N ≥ 2. -/
theorem gramMatrix_det_ne_zero (N : ℕ) (hN : 2 ≤ N) :
    (gramMatrix N).det ≠ 0 := by
  intro h_zero
  rw [Matrix.exists_mulVec_eq_zero_iff.symm] at h_zero
  obtain ⟨v, hv_ne, hv_ker⟩ := h_zero
  have h_pos := gram_pos_def N hN v hv_ne
  rw [realQuadForm, hv_ker, dotProduct_zero] at h_pos
  exact lt_irrefl 0 h_pos

/-- Global IsUnit seal for the Gram matrix determinant. -/
lemma gramMatrix_isUnit_det (N : ℕ) (hN : 2 ≤ N) :
    IsUnit (gramMatrix N).det :=
  isUnit_iff_ne_zero.mpr (gramMatrix_det_ne_zero N hN)

end
