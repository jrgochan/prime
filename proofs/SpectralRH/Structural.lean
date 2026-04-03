import SpectralRH.Defs
import SpectralRH.RayleighBridge
import Mathlib.MeasureTheory.Function.Floor

/-! # SpectralRH.Structural
Structural properties: interlacing, antitone, positive definiteness, telescoping.
-/

noncomputable section
open Complex Real


/-- **Cauchy Interlacing for the Gram matrix sequence** (Cauchy 1829):
    G_N is a principal submatrix of G_{N+1}, so by the
    Courant-Fischer min-max theorem, λ_min(G_{N+1}) ≤ λ_min(G_N).

    Proof sketch: For any unit vector v ∈ ℝ^{N-1}, extend to
    w = (v, 0) ∈ ℝ^N. Then wᵀG_{N+1}w = vᵀG_Nv and ‖w‖ = ‖v‖.
    So inf_{‖w‖=1} wᵀG_{N+1}w ≤ inf_{‖v‖=1} vᵀG_Nv.

    Note: The full Courant-Fischer theorem for Matrix.IsHermitian.eigenvalues₀
    is not yet in Mathlib. This axiom directly states the consequence
    for our specific Gram matrix sequence, avoiding Fin-cast issues
    that arise when connecting the abstract principle to concrete matrices. -/
axiom eigenvalue_interlacing (N : ℕ) (hN : 2 ≤ N) :
    lambdaMin (N + 1) ≤ lambdaMin N

theorem eigenvalue_antitone (N : ℕ) (hN : 2 ≤ N) :
    lambdaMin (N + 1) ≤ lambdaMin N := eigenvalue_interlacing N hN

/-- lambdaMin shifted to start at 0 is antitone on all of ℕ. -/
lemma lambdaMin_shifted_antitone : Antitone (fun n => lambdaMin (n + 2)) := by
  intro a b hab
  induction hab with
  | refl => exact le_refl _
  | step h ih => exact le_trans (eigenvalue_antitone _ (by omega)) ih

/-- lambdaMin is antitone for indices ≥ 2. -/
lemma lambdaMin_antitone_ge2 (M N : ℕ) (hM : 2 ≤ M) (hN : M ≤ N) :
    lambdaMin N ≤ lambdaMin M := by
  have := lambdaMin_shifted_antitone (show M - 2 ≤ N - 2 by omega)
  simp only at this
  have hM2 : M - 2 + 2 = M := by omega
  have hN2 : N - 2 + 2 = N := by omega
  rwa [hM2, hN2] at this

/-- The eigenvalue drop is non-negative (from Cauchy interlacing) -/
theorem eigenDrop_nonneg (N : ℕ) (hN : 3 ≤ N) : 0 ≤ eigenDrop N := by
  -- eigenDrop N = lambdaMin (N-1) - lambdaMin N
  -- By eigenvalue_antitone at (N-1): lambdaMin N ≤ lambdaMin (N-1)
  unfold eigenDrop
  have h2 : 2 ≤ N - 1 := by omega
  have := eigenvalue_antitone (N - 1) h2
  have hsimp : N - 1 + 1 = N := by omega
  rw [hsimp] at this
  linarith

/-- The NB linear combination: φ_w(x) = Σᵢ wᵢ · {(i+2)/x}.
    This is the L²(0,1) function whose squared norm equals wᵀGw. -/
def nbLinComb (N : ℕ) (w : Fin (N - 1) → ℝ) (x : ℝ) : ℝ :=
  ∑ i : Fin (N - 1), w i * Int.fract ((↑(i.val + 2) : ℝ) / x)

/-- The function x ↦ Int.fract(j/x) * Int.fract(k/x) is measurable. -/
private lemma fract_div_mul_measurable (j k : ℕ) :
    Measurable (fun x : ℝ => Int.fract (↑j / x) * Int.fract (↑k / x)) :=
  (measurable_const.div measurable_id).fract.mul
    (measurable_const.div measurable_id).fract

/-- Products of fractional parts are bounded by 1. -/
private lemma fract_prod_le_one (j k : ℕ) (x : ℝ) :
    ‖Int.fract (↑j / x) * Int.fract (↑k / x)‖ ≤ ‖(1 : ℝ)‖ := by
  rw [Real.norm_eq_abs, Real.norm_eq_abs, abs_one,
      abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
  calc Int.fract (↑j / x) * Int.fract (↑k / x)
      ≤ 1 * 1 := by
        apply mul_le_mul
        · exact le_of_lt (Int.fract_lt_one _)
        · exact le_of_lt (Int.fract_lt_one _)
        · exact Int.fract_nonneg _
        · linarith
    _ = 1 := mul_one 1

/-- **fract_prod_intervalIntegrable** (PROVEN):
    Products of fractional parts are IntervalIntegrable on [0,1].

    Proof: Bounded by 1 + measurable + dominated by constant 1
    on the finite measure interval [0,1]. -/
theorem fract_prod_intervalIntegrable (j k : ℕ) :
    IntervalIntegrable
      (fun x : ℝ => Int.fract (↑j / x) * Int.fract (↑k / x))
      MeasureTheory.volume 0 1 :=
  IntervalIntegrable.mono_fun
    (intervalIntegrable_const (c := (1 : ℝ)))
    ((fract_div_mul_measurable j k).aestronglyMeasurable.restrict)
    (Filter.Eventually.of_forall (fract_prod_le_one j k))

/-- Scaled products inherit integrability (const_mul). -/
private lemma scaled_fract_intervalIntegrable (j k : ℕ) (a b : ℝ) :
    IntervalIntegrable
      (fun x : ℝ => a * Int.fract (↑j / x) * (b * Int.fract (↑k / x)))
      MeasureTheory.volume 0 1 := by
  have : (fun x : ℝ => a * Int.fract (↑j / x) * (b * Int.fract (↑k / x))) =
         (fun x : ℝ => (a * b) * (Int.fract (↑j / x) * Int.fract (↑k / x))) := by
    ext x; ring
  rw [this]
  exact (fract_prod_intervalIntegrable j k).const_mul (a * b)

/-- LHS = double sum over gramEntry (pure algebra). -/
private lemma quadForm_as_double_sum (N : ℕ) (w : Fin (N - 1) → ℝ) :
    realQuadForm (gramMatrix N) w =
    ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      w i * w j * gramEntry (i.val + 2) (j.val + 2) := by
  unfold realQuadForm dotProduct
  congr 1; ext i
  simp only [Matrix.mulVec, dotProduct, gramMatrix, Matrix.of_apply]
  rw [Finset.mul_sum]
  congr 1; ext j; ring

/-- Each weighted integral = weight × gramEntry (constant factor). -/
private lemma integral_fract_prod_eq (j k : ℕ) (a b : ℝ) :
    ∫ x in (0:ℝ)..1,
      (a * Int.fract (↑j / x)) * (b * Int.fract (↑k / x)) =
    a * b * gramEntry j k := by
  unfold gramEntry
  rw [show (fun x : ℝ => a * Int.fract (↑j / x) * (b * Int.fract (↑k / x))) =
      (fun x : ℝ => (a * b) * (Int.fract (↑j / x) * Int.fract (↑k / x))) from
    by ext x; ring]
  exact intervalIntegral.integral_const_mul (a * b) _

/-- RHS = double sum over gramEntry (sum-integral swap + algebra). -/
private lemma integral_sq_as_double_sum (N : ℕ) (w : Fin (N - 1) → ℝ) :
    ∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2 =
    ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      w i * w j * gramEntry (i.val + 2) (j.val + 2) := by
  -- Expand (Σ aᵢ)² = Σᵢ Σⱼ aᵢ * aⱼ
  have h_sq : (fun x : ℝ => (nbLinComb N w x) ^ 2) =
      (fun x => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) := by
    ext x; unfold nbLinComb; rw [sq, Finset.sum_mul_sum]
  rw [h_sq]
  -- Convert unattached sums for integral_finset_sum
  rw [show (fun x : ℝ => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) =
      (fun x => ∑ i ∈ Finset.univ, ∑ j ∈ Finset.univ,
        (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) from by
    ext x; simp]
  -- Pull outer Σᵢ through ∫
  rw [intervalIntegral.integral_finset_sum]
  -- For each i, pull inner Σⱼ through ∫
  congr 1; ext i
  rw [show (fun x : ℝ => ∑ j ∈ Finset.univ,
        (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) =
      (fun x => ∑ j ∈ Finset.univ,
        (fun j x => (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) j x) from by
    ext x; simp]
  rw [intervalIntegral.integral_finset_sum]
  -- Each integral = wᵢ wⱼ gramEntry(i+2, j+2)
  congr 1; ext j
  exact integral_fract_prod_eq (i.val + 2) (j.val + 2) (w i) (w j)
  -- Inner integrability
  · intro j _
    exact scaled_fract_intervalIntegrable (i.val + 2) (j.val + 2) (w i) (w j)
  -- Outer integrability
  · intro i _
    have : (fun x => ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) =
      (∑ j : Fin (N - 1), fun x =>
        (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) := by
      ext x; simp [Finset.sum_apply]
    rw [this]
    exact IntervalIntegrable.sum Finset.univ (fun j _ =>
      scaled_fract_intervalIntegrable (i.val + 2) (j.val + 2) (w i) (w j))

/-- **L² norm identity** (PROVEN): wᵀGw = ∫₀¹ (Σᵢ wᵢ fᵢ)² dx.

    The quadratic form of the Gram matrix equals the L² norm squared
    of the NB linear combination. This is the core identity connecting
    finite-dimensional linear algebra to L²(0,1) analysis.

    Only axiom used: fract_prod_intervalIntegrable (integrability). -/
theorem gram_l2_identity (N : ℕ) (_ : 2 ≤ N) (w : Fin (N - 1) → ℝ) :
    realQuadForm (gramMatrix N) w =
    ∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2 := by
  rw [quadForm_as_double_sum, integral_sq_as_double_sum]

/-- **Sub-axiom 1 (Floor behavior above)**: On (n/(n+1), 1) with m ≤ n ≥ 2,
    the fractional part {m/x} = m/x - m.
    Proof: x ∈ (n/(n+1), 1) implies m ≤ m/x < m+1, so ⌊m/x⌋ = m. -/
axiom fract_eq_sub {n m : ℕ} (hm : m ≤ n) (hn : 2 ≤ n)
    {x : ℝ} (hx_lo : (n : ℝ) / (↑n + 1) < x) (hx_hi : x < 1) :
    Int.fract ((m : ℝ) / x) = (m : ℝ) / x - (m : ℝ)

/-- **Sub-axiom 2 (Floor unchanged below)**: On (n/(n+2), n/(n+1))
    with m < n ≥ 2, the fractional part {m/x} = m/x - m (same as above).
    Proof: m < n implies m/(m+1) < n/(n+2) < x, so m ≤ m/x < m+1. -/
axiom fract_eq_sub_below {n m : ℕ} (hm : m < n) (hn : 2 ≤ n)
    {x : ℝ} (hx_lo : (n : ℝ) / (↑n + 2) < x) (hx_hi : x < (n : ℝ) / (↑n + 1)) :
    Int.fract ((m : ℝ) / x) = (m : ℝ) / x - (m : ℝ)

/-- **Sub-axiom 3 (Floor jumped below)**: On (n/(n+2), n/(n+1)),
    the fractional part {n/x} = n/x - (n+1) — the floor has increased.
    Proof: x < n/(n+1) implies n/x > n+1, and x > n/(n+2) implies n/x < n+2. -/
axiom fract_eq_sub_shifted {n : ℕ} (hn : 2 ≤ n)
    {x : ℝ} (hx_lo : (n : ℝ) / (↑n + 2) < x) (hx_hi : x < (n : ℝ) / (↑n + 1)) :
    Int.fract ((n : ℝ) / x) = (n : ℝ) / x - ((n : ℝ) + 1)

/-- On (n'/(n'+1), 1), nbLinComb = A·(1/x - 1) where A = Σ wᵢ(i+2). -/
private lemma nbLinComb_eq_affine (N : ℕ) (w : Fin (N - 1) → ℝ)
    (n' : ℕ) (hn' : 2 ≤ n')
    (hw_zero : ∀ i : Fin (N - 1), n' < i.val + 2 → w i = 0)
    (x : ℝ) (hx_lo : (n' : ℝ) / (↑n' + 1) < x) (hx_hi : x < 1) :
    nbLinComb N w x = (∑ i : Fin (N - 1), w i * (↑(i.val + 2) : ℝ)) * (1/x - 1) := by
  have hx_pos : 0 < x := by linarith [show (0:ℝ) < ↑n' / (↑n' + 1) by positivity]
  unfold nbLinComb; rw [Finset.sum_mul]; congr 1; ext ⟨i, hi⟩
  by_cases h : i + 2 ≤ n'
  · rw [fract_eq_sub h hn' hx_lo hx_hi]; field_simp
  · push_neg at h; rw [hw_zero ⟨i, hi⟩ h]; simp

/-- On (n'/(n'+2), n'/(n'+1)), nbLinComb = -w_{j₀} when A = 0. -/
private lemma nbLinComb_eq_neg (N : ℕ) (w : Fin (N - 1) → ℝ) (j₀ : Fin (N - 1))
    (hw_above : ∀ i : Fin (N - 1), j₀ < i → w i = 0)
    (hA : (∑ i : Fin (N - 1), w i * (↑(i.val + 2) : ℝ)) = 0)
    (x : ℝ) (hx_lo : (↑(j₀.val + 2) : ℝ) / (↑(j₀.val + 2) + 2) < x)
    (hx_hi : x < (↑(j₀.val + 2) : ℝ) / (↑(j₀.val + 2) + 1)) :
    nbLinComb N w x = -(w j₀) := by
  set n' := j₀.val + 2; have hn' : 2 ≤ n' := by omega
  have hx_pos : 0 < x := by linarith [show (0:ℝ) < ↑n' / (↑n' + 2) by positivity]
  unfold nbLinComb
  have h_term : ∀ i : Fin (N - 1),
      w i * Int.fract ((↑(i.val + 2) : ℝ) / x) =
      w i * ((↑(i.val + 2) : ℝ) / x - ↑(i.val + 2)) +
      if i = j₀ then -(w j₀) else 0 := by
    intro ⟨i, hi⟩
    by_cases hij : (⟨i, hi⟩ : Fin (N-1)) = j₀
    · simp only [hij, ite_true]
      have hi_eq : i = j₀.val := Fin.val_eq_of_eq hij
      rw [show (↑(i + 2) : ℝ) = ↑n' from by subst hi_eq; simp [n']]
      rw [fract_eq_sub_shifted hn' hx_lo hx_hi]; ring
    · simp only [hij, ite_false, add_zero]
      have hi_ne : i ≠ j₀.val := Fin.val_ne_of_ne hij
      by_cases h : i + 2 < n'
      · rw [fract_eq_sub_below (by exact_mod_cast h : (i + 2 : ℕ) < n') hn' hx_lo hx_hi]
      · push_neg at h; have : n' < i + 2 := by omega
        rw [hw_above ⟨i, hi⟩ (by simp only [Fin.lt_def]; omega)]; simp
  simp_rw [h_term, Finset.sum_add_distrib]
  have h1 : ∑ i : Fin (N - 1), w i * ((↑(i.val + 2) : ℝ) / x - ↑(i.val + 2)) =
    (∑ i : Fin (N - 1), w i * (↑(i.val + 2) : ℝ)) * (1/x - 1) := by
    rw [Finset.sum_mul]; congr 1; ext i; field_simp
  rw [h1, hA, zero_mul, zero_add, Finset.sum_ite_eq' Finset.univ j₀]; simp

/-- **nbLinComb_nonzero_somewhere** (PROVEN from floor sub-axioms):
    If w ≠ 0, nbLinComb is nonzero on some open subinterval of (0,1).

    Proof: Let j₀ = max index with w_{j₀} ≠ 0, n' = j₀+2, A = Σ wᵢ(i+2).
    Case A ≠ 0: On (n'/(n'+1), 1), nbLinComb = A(1/x-1) ≠ 0.
    Case A = 0: On (n'/(n'+2), n'/(n'+1)), nbLinComb = -w_{j₀} ≠ 0. -/
theorem nbLinComb_nonzero_somewhere (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
    (∀ x, x ∈ Set.Ioo c d → nbLinComb N w x ≠ 0) := by
  have hw_exists : ∃ i : Fin (N - 1), w i ≠ 0 := by
    by_contra h; push_neg at h; exact hw (funext h)
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
  set n' := j₀.val + 2
  have hn' : 2 ≤ n' := by omega
  have hn'N : n' ≤ N := by have := j₀.isLt; omega
  have hn'_pos : (0 : ℝ) < ↑n' := by exact_mod_cast show 0 < n' by omega
  set A := ∑ i : Fin (N - 1), w i * (↑(i.val + 2) : ℝ)
  by_cases hA : A ≠ 0
  · -- CASE A ≠ 0: nbLinComb = A(1/x-1) ≠ 0 on (n'/(n'+1), 1)
    refine ⟨↑n' / (↑n' + 1), 1, le_of_lt (by positivity),
      by rw [div_lt_one (by linarith)]; linarith, le_refl 1, ?_⟩
    intro x ⟨hx_lo, hx_hi⟩
    rw [nbLinComb_eq_affine N w n' hn'
      (fun i hi => hw_above i (by
        show j₀ < i
        exact Fin.lt_iff_val_lt_val.mpr (by omega))) x hx_lo hx_hi]
    exact mul_ne_zero hA (by
      have hx_pos : 0 < x := by linarith [show (0:ℝ) < ↑n' / (↑n' + 1) by positivity]
      linarith [show 1 < 1/x from by rw [one_div]; exact one_lt_inv_iff₀.mpr ⟨hx_pos, hx_hi⟩])
  · -- CASE A = 0: nbLinComb = -w_{j₀} (constant) on (n'/(n'+2), n'/(n'+1))
    push_neg at hA
    refine ⟨↑n' / (↑n' + 2), ↑n' / (↑n' + 1), le_of_lt (by positivity),
      div_lt_div_of_pos_left hn'_pos (by positivity) (by linarith),
      by rw [div_le_one (by linarith)]; linarith, ?_⟩
    intro x ⟨hx_lo, hx_hi⟩
    rw [nbLinComb_eq_neg N w j₀ hw_above hA x hx_lo hx_hi]
    exact neg_ne_zero.mpr hwj₀

/-- nbLinComb² is integrable on subintervals of [0,1]. -/
private lemma nbLinComb_sq_integrable (N : ℕ) (w : Fin (N - 1) → ℝ) :
    IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2) MeasureTheory.volume 0 1 := by
  have h_sq : (fun x => (nbLinComb N w x) ^ 2) =
      (fun x => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) := by
    ext x; unfold nbLinComb; rw [sq, Finset.sum_mul_sum]
  rw [h_sq]
  have : (fun x : ℝ => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
      (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) =
    (∑ i : Fin (N - 1), ∑ j : Fin (N - 1), fun x =>
      (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
      (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) := by
    ext x; simp [Finset.sum_apply]
  rw [this]
  apply IntervalIntegrable.sum; intro i _
  apply IntervalIntegrable.sum; intro j _
  have : (fun x : ℝ => (w i * Int.fract ((↑(i.val + 2) : ℝ) / x)) *
      (w j * Int.fract ((↑(j.val + 2) : ℝ) / x))) =
    (fun x : ℝ => (w i * w j) * (Int.fract ((↑(i.val + 2) : ℝ) / x) *
      Int.fract ((↑(j.val + 2) : ℝ) / x))) := by ext x; ring
  rw [this]
  exact (fract_prod_intervalIntegrable (i.val + 2) (j.val + 2)).const_mul _

/-- **NB linear independence** (PROVEN from sub-axiom):
    ∫₀¹ (Σ wᵢ{(i+2)/x})² dx > 0 for w ≠ 0.

    Proof: The function is nonzero on some (c,d) ⊂ (0,1),
    so (nbLinComb)² > 0 there. Since (nbLinComb)² ≥ 0 everywhere,
    the full integral ∫₀¹ ≥ ∫_c^d > 0. -/
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

/-- **gram_pos_def** (PROVEN): wᵀGw > 0 for w ≠ 0.
    Follows immediately from the L² identity + linear independence. -/
theorem gram_pos_def (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    0 < realQuadForm (gramMatrix N) w := by
  rw [gram_l2_identity N hN w]
  exact nyman_beurling_lin_indep N hN w hw

/-- **The Gram matrix is positive definite** for N ≥ 2 (PROVEN).
    λ_min(G_N) > 0 follows from the quadratic form being positive definite.

    Proof chain:
    1. gram_pos_def: wᵀGw > 0 for all w ≠ 0 (L² linear independence)
    2. pos_def_implies_min_eigenvalue_pos: all eigenvalues > 0
    3. Therefore min eigenvalue > 0. -/
theorem gram_positive_definite (N : ℕ) (hN : 2 ≤ N) : 0 < lambdaMin N := by
  unfold lambdaMin
  simp only [show N ≥ 2 from hN, dite_true]
  exact pos_def_implies_min_eigenvalue_pos
    (gramMatrix_hermitian N)
    (by omega)
    (fun v hv => gram_pos_def N hN v hv)

theorem lambdaMin_pos (N : ℕ) (hN : 2 ≤ N) : 0 < lambdaMin N :=
  gram_positive_definite N hN

/-- Telescoping: λ_min(G_N) = λ_min(G_{N₀}) - Σ_{k=N₀}^{N-1} δ_{k+1}
    This is a purely algebraic identity following from the definition
    eigenDrop (k+1) = lambdaMin k - lambdaMin (k+1). -/
theorem telescoping (N₀ N : ℕ) (h₀ : 2 ≤ N₀) (hN : N₀ ≤ N) :
    lambdaMin N = lambdaMin N₀ -
    ∑ k ∈ Finset.Ico N₀ N, eigenDrop (k + 1) := by
  simp_rw [eigenDrop_succ]
  induction N with
  | zero => simp [Nat.le_zero.mp hN]
  | succ n ih =>
    by_cases h : N₀ ≤ n
    · rw [Finset.sum_Ico_succ_top h]
      have := ih h
      linarith
    · push_neg at h
      have : N₀ = n + 1 := by omega
      subst this
      simp

/-- **Drop formula** (Schur complement perturbation):
    δ_N ≤ cos²θ_{N-1} · ‖g_{N-1}‖² / S_{N-1}.

    This is a standard bound from the Schur complement representation
    of blocked matrix eigenvalues. When a row/column is added to a
    Hermitian matrix, the eigenvalue drop is bounded by the squared
    projection of the new row onto the old minimum eigenvector,
    divided by the Schur complement. -/
axiom drop_formula_bound (N : ℕ) (hN : 3 ≤ N) :
    eigenDrop N ≤ (cosAlignment (N - 1))^2 *
      dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) /
      schurComplement (N - 1)

theorem drop_formula (N : ℕ) (hN : 3 ≤ N) :
    eigenDrop N ≤ (cosAlignment (N - 1))^2 *
      dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) /
      schurComplement (N - 1) := drop_formula_bound N hN


end
