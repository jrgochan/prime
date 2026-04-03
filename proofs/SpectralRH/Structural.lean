import SpectralRH.Defs
import SpectralRH.RayleighBridge
import Mathlib.MeasureTheory.Function.Floor

/-! # SpectralRH.Structural
Structural properties: interlacing, antitone, positive definiteness, telescoping.
-/

noncomputable section
open Complex Real


/-- **Cauchy Interlacing** (PROVEN): λ_min(G_{N+1}) ≤ λ_min(G_N).

    Proof: For any eigenvector v of G_N with eigenvalue λ, pad to w = (v, 0).
    Then wᵀG_{N+1}w = vᵀG_Nv = λ and ‖w‖ = 1.
    By the Rayleigh bound, λ_min(G_{N+1}) ≤ λ.
    Taking λ = λ_min(G_N) gives the result. -/
theorem eigenvalue_interlacing (N : ℕ) (hN : 2 ≤ N) :
    lambdaMin (N + 1) ≤ lambdaMin N := by
  obtain ⟨n, rfl⟩ : ∃ n, N = n + 1 := ⟨N - 1, by omega⟩
  have hn : 0 < n := by omega
  unfold lambdaMin
  simp only [show n + 1 ≥ 2 from by omega, show n + 2 ≥ 2 from by omega, dite_true]
  -- H_n = gramMatrix_hermitian (n+1) : the small matrix (Fin n × Fin n)
  -- H_n1 = gramMatrix_hermitian (n+2) : the big matrix (Fin (n+1) × Fin (n+1))
  set H_n := gramMatrix_hermitian (n + 1)
  set H_n1 := gramMatrix_hermitian (n + 2)
  -- Goal: inf'(eigenvalues₀ of H_n1) ≤ inf'(eigenvalues₀ of H_n)
  -- Strategy: inf' ≤ every eigenvalue, so it suffices to show
  --   inf'(H_n1) ≤ quadForm G_{n+2} w for some unit w
  -- We pick w = padVector(eigenvector i of H_n) for any i.
  -- Then use: inf'(H_n1) ≤ quadForm G_{n+2} w = quadForm G_{n+1} v = eigenvalue i
  -- and:      eigenvalue i ≥ inf'(H_n) for the right i
  -- Actually simpler: inf' is ≤ every element, and inf'(H_n1) ≤ any Rayleigh quotient.
  -- So: inf'(H_n1) ≤ quadForm(padVector v) = quadForm v = λᵢ for all i
  -- Taking inf over all i: inf'(H_n1) ≤ inf'(H_n).
  apply Finset.le_inf'
  intro j _
  -- Show inf'(H_n1 eigenvalues₀) ≤ H_n.eigenvalues₀ j
  -- eigenvalues₀ j ∈ range(eigenvalues), so ∃ i with eigenvalues i = eigenvalues₀ j
  have h_in_range : H_n.eigenvalues₀ j ∈ Set.range H_n.eigenvalues := by
    unfold Matrix.IsHermitian.eigenvalues
    exact ⟨(Fintype.equivOfCardEq (Fintype.card_fin _)) j,
           congr_arg _ (Equiv.symm_apply_apply _ j)⟩
  obtain ⟨i, hi⟩ := h_in_range
  rw [← hi]
  -- Goal: inf'(H_n1) ≤ H_n.eigenvalues i
  -- = quadForm G_{n+1} (eigenvector i)    [by quadForm_eigenvector]
  -- = quadForm G_{n+2} (padVector(eigenvector i))  [by quadForm_padVector]
  rw [← quadForm_eigenvector H_n i, ← quadForm_padVector]
  -- Goal: inf'(H_n1) ≤ quadForm G_{n+2} (padVector(eigenvector i))
  exact min_eigenvalue_le_quadForm H_n1 _
    (padVector_norm _ (H_n.eigenvectorBasis.orthonormal.1 i))
    (by omega)

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

/-- **fract_eq_sub** (PROVEN): On (n/(n+1), 1) with m ≤ n ≥ 2,
    the fractional part {m/x} = m/x - m.

    Proof: m/(m+1) ≤ n/(n+1) < x < 1 implies m ≤ m/x < m+1, so ⌊m/x⌋ = m.
    Cross-multiplication: m(n+1) ≤ n(m+1) ↔ mn+m ≤ nm+n ↔ m ≤ n. -/
theorem fract_eq_sub {n m : ℕ} (hm : m ≤ n) (hn : 2 ≤ n)
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

/-- **Floor on shifted interval**: On ((n-1)/n, n/(n+1)) with m ≤ n-1 and n ≥ 2,
    the fractional part {m/x} = m/x - m (same floor as the right interval). -/
private theorem fract_eq_sub_shifted {n m : ℕ} (hm : m + 1 ≤ n) (hn : 2 ≤ n)
    {x : ℝ} (hx_lo : ((n : ℝ) - 1) / ↑n < x) (hx_hi : x < ↑n / (↑n + 1)) :
    Int.fract ((m : ℝ) / x) = (m : ℝ) / x - (m : ℝ) := by
  have hn_pos : (0 : ℝ) < ↑n := by exact_mod_cast show 0 < n by omega
  have hx_pos : 0 < x := by
    have h1 : (1 : ℝ) ≤ ↑n := by exact_mod_cast show 1 ≤ n by omega
    have : (0 : ℝ) ≤ (↑n - 1) / ↑n := div_nonneg (by linarith) (by linarith)
    linarith
  -- Show m ≤ m/x (from x < n/(n+1) < 1)
  have hx_lt_one : x < 1 := by
    calc x < ↑n / (↑n + 1) := hx_hi
    _ < 1 := by rw [div_lt_one (by linarith)]; linarith
  have h_lower : (m : ℝ) ≤ ↑m / x := by
    rw [le_div_iff₀ hx_pos]; nlinarith
  -- Show m/x < m+1 (from x > (n-1)/n and m ≤ n-1)
  have h_upper : (m : ℝ) / x < ↑m + 1 := by
    rw [div_lt_iff₀ hx_pos]
    have hx_lb : (↑n - 1) / ↑n < x := hx_lo
    -- m/x < m+1 ↔ m < (m+1)x ← (m+1)(n-1)/n < (m+1)x
    -- since m ≤ n-1: m(n) ≤ (n-1)n = n² - n, and (m+1)(n-1) = mn - m + n - 1
    -- we need (m+1) * ((n-1)/n) ≤ m, i.e., (m+1)(n-1) ≤ mn
    -- ↔ mn - m + n - 1 ≤ mn ↔ n - 1 ≤ m... NO this is wrong
    -- Actually we need m < (m+1) * x. Since x > (n-1)/n:
    -- (m+1) * x > (m+1)(n-1)/n. Need (m+1)(n-1)/n ≥ m.
    -- Cross: (m+1)(n-1) ≥ mn ↔ mn - m + n - 1 ≥ mn ↔ n - 1 ≥ m. TRUE since m+1 ≤ n.
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

/-- **Floor jump**: On ((n-1)/n, n/(n+1)) with n ≥ 2,
    the fractional part {n/x} = n/x - (n+1) (floor jumps from n to n+1). -/
private theorem fract_eq_sub_jump {n : ℕ} (hn : 2 ≤ n)
    {x : ℝ} (hx_lo : ((n : ℝ) - 1) / ↑n < x) (hx_hi : x < ↑n / (↑n + 1)) :
    Int.fract ((n : ℝ) / x) = (n : ℝ) / x - (↑n + 1) := by
  have hn_pos : (0 : ℝ) < ↑n := by exact_mod_cast show 0 < n by omega
  have hx_pos : 0 < x := by
    have h1 : (1 : ℝ) ≤ ↑n := by exact_mod_cast show 1 ≤ n by omega
    have : (0 : ℝ) ≤ (↑n - 1) / ↑n := div_nonneg (by linarith) (by linarith)
    linarith
  -- Show n+1 ≤ n/x (from x < n/(n+1))
  have h_lower : (n : ℝ) + 1 ≤ ↑n / x := by
    rw [le_div_iff₀ hx_pos]
    -- x < n/(n+1) → x(n+1) < n
    have hn1 : (0 : ℝ) < ↑n + 1 := by linarith
    have : x * (↑n + 1) < ↑n := by
      rwa [lt_div_iff₀ hn1] at hx_hi
    linarith
  -- Show n/x < n+2 (from x > (n-1)/n)
  have h_upper : (n : ℝ) / x < ↑n + 2 := by
    rw [div_lt_iff₀ hx_pos]
    -- Goal: ↑n < (↑n + 2) * x. From x > (n-1)/n: x*↑n > ↑n - 1.
    -- (↑n + 2) * x * ↑n > (↑n + 2)(↑n - 1) = ↑n² + ↑n - 2 ≥ ↑n² for ↑n ≥ 2.
    have hxn : (↑n - 1) < x * ↑n := by
      have := (div_lt_iff₀ hn_pos).mp hx_lo; linarith
    -- Multiply hxn by (n+2) > 0: (n+2)(n-1) < (n+2)*x*n
    -- And (n+2)(n-1) = n²+n-2 ≥ n² for n ≥ 2
    -- Contradiction with (n+2)*x ≤ n (negated goal) → (n+2)*x*n ≤ n²
    have h_prod : (↑n + 2) * (↑n - 1) < (↑n + 2) * (x * ↑n) :=
      mul_lt_mul_of_pos_left hxn (by linarith)
    -- (↑n+2)*(↑n-1) = ↑n²+↑n-2. For ↑n ≥ 2, this is ≥ ↑n².
    -- Also need: if (↑n+2)*x ≤ ↑n then (↑n+2)*x*↑n ≤ ↑n*↑n
    -- This gives n²+n-2 < n², contradiction.
    by_contra h; push_neg at h
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

/-- **NB floor jump** (PROVEN): When A = Σ wᵢ(i+2) = 0 and j₀ is the
    largest index with w_{j₀} ≠ 0, nbLinComb ≡ -w_{j₀} on an open
    subinterval of (0,1).

    On ((n'-1)/n', n'/(n'+1)) where n' = j₀+2:
    • For i < j₀: ⌊(i+2)/x⌋ = i+2, so {(i+2)/x} = (i+2)/x - (i+2)
    • For i = j₀: ⌊n'/x⌋ = n'+1 (floor jumps!), so {n'/x} = n'/x - (n'+1)
    • For i > j₀: wᵢ = 0
    Summing: nbLinComb = A/x - (A + w_{j₀}) = -w_{j₀} since A = 0. -/
theorem nbLinComb_neg_interval (N : ℕ) (w : Fin (N - 1) → ℝ) (j₀ : Fin (N - 1))
    (hw_above : ∀ i : Fin (N - 1), j₀ < i → w i = 0)
    (hA : (∑ i : Fin (N - 1), w i * (↑(i.val + 2) : ℝ)) = 0) :
    ∃ c d : ℝ, 0 ≤ c ∧ c < d ∧ d ≤ 1 ∧
    ∀ x, x ∈ Set.Ioo c d → nbLinComb N w x = -(w j₀) := by
  set n' := j₀.val + 2
  have hn' : 2 ≤ n' := by omega
  have hn'_pos : (0 : ℝ) < ↑n' := by exact_mod_cast show 0 < n' by omega
  -- The interval: c = (n'-1)/n', d = n'/(n'+1)
  refine ⟨(↑n' - 1) / ↑n', ↑n' / (↑n' + 1),
    div_nonneg (by linarith [show (1:ℝ) ≤ ↑n' from by exact_mod_cast show 1 ≤ n' by omega]) (le_of_lt hn'_pos),
    ?_, ?_, ?_⟩
  · -- c < d: (n'-1)/n' < n'/(n'+1) ↔ (n'-1)(n'+1) < n'² ↔ n'²-1 < n'²
    rw [div_lt_div_iff₀ hn'_pos (show (0:ℝ) < ↑n' + 1 by linarith)]
    nlinarith
  · -- d ≤ 1: n'/(n'+1) ≤ 1
    rw [div_le_one (by linarith : (0:ℝ) < ↑n' + 1)]
    linarith
  · -- Main: nbLinComb = -w_{j₀} on (c, d)
    intro x ⟨hx_lo, hx_hi⟩
    have hx_pos : 0 < x := by
      have : (0 : ℝ) ≤ (↑n' - 1) / ↑n' := div_nonneg
        (by linarith [show (1:ℝ) ≤ ↑n' from by exact_mod_cast show 1 ≤ n' by omega])
        (le_of_lt hn'_pos)
      linarith
    unfold nbLinComb
    -- Split the sum: terms with i < j₀, i = j₀, and i > j₀
    -- For i > j₀: w i = 0, so the term vanishes
    -- Rewrite each term
    have h_term : ∀ i : Fin (N - 1),
        w i * Int.fract ((↑(i.val + 2) : ℝ) / x) =
        if j₀ < i then 0
        else if i = j₀ then w j₀ * ((↑n' : ℝ) / x - (↑n' + 1))
        else w i * ((↑(i.val + 2) : ℝ) / x - ↑(i.val + 2)) := by
      intro i
      by_cases hi_above : j₀ < i
      · simp only [hi_above, ↓reduceIte, hw_above i hi_above, zero_mul]
      · push_neg at hi_above
        simp only [show ¬(j₀ < i) from not_lt.mpr hi_above, ↓reduceIte]
        by_cases hi_eq : i = j₀
        · subst hi_eq; simp only [↓reduceIte]
          congr 1
          exact fract_eq_sub_jump hn' hx_lo hx_hi
        · have hi_lt : i < j₀ := lt_of_le_of_ne hi_above hi_eq
          simp only [hi_eq, ↓reduceIte]
          congr 1
          have hm : i.val + 2 + 1 ≤ n' := by omega
          exact fract_eq_sub_shifted hm hn' hx_lo hx_hi
    simp_rw [h_term]
    -- Rewrite conditional sum as div_sum/x - const_sum
    have h_split : ∀ i : Fin (N - 1),
        (if j₀ < i then (0 : ℝ)
         else if i = j₀ then w j₀ * ((↑n' : ℝ) / x - (↑n' + 1))
         else w i * ((↑(i.val + 2) : ℝ) / x - ↑(i.val + 2))) =
        (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 2)) / x -
        (if j₀ < i then (0 : ℝ) else if i = j₀ then w j₀ * (↑n' + 1)
         else w i * ↑(i.val + 2)) := by
      intro i; split_ifs with h1 h2
      · simp
      · subst h2; field_simp; ring
      · field_simp
    simp_rw [h_split, Finset.sum_sub_distrib]
    -- Now goal: (Σ (if ... else w_i*(i+2))) / x - Σ (if ... else if ... then w_{j₀}(n'+1) else w_i(i+2)) = -w_{j₀}
    have hA_ite : ∑ i : Fin (N - 1), (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 2)) = 0 := by
      trans ∑ i : Fin (N - 1), w i * ↑(i.val + 2)
      · congr 1; ext i; split_ifs with h
        · simp [hw_above i h]
        · rfl
      · exact hA
    -- The first sum is Σ (if ... / x) which involves division inside the summand.
    -- After sum_sub_distrib: goal is (Σ (if j₀<i then 0 else w_i*(i+2))/x) - (Σ ...) = -w_{j₀}
    -- Need to pull the /x outside. Can't use Finset.sum_div directly.
    -- Instead use conv to rewrite the first sum using hA_ite.
    have h_sum_div : (∑ i : Fin (N - 1), (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 2)) / x) = 0 := by
      rw [show (∑ i : Fin (N - 1), (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 2)) / x) =
        (∑ i : Fin (N - 1), (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 2))) / x from
        (Finset.sum_div Finset.univ _ x).symm]
      rw [hA_ite, zero_div]
    rw [h_sum_div, zero_sub, neg_eq_iff_eq_neg, neg_neg]
    have h_each : ∀ i : Fin (N - 1),
        (if j₀ < i then (0 : ℝ) else if i = j₀ then w j₀ * (↑n' + 1)
         else w i * ↑(i.val + 2)) =
        (if j₀ < i then (0 : ℝ) else w i * ↑(i.val + 2)) +
        (if i = j₀ then w j₀ else 0) := by
      intro i; by_cases h1 : j₀ < i
      · simp only [h1, ite_true]
        have : i ≠ j₀ := ne_of_gt h1
        simp [this]
      · push_neg at h1
        simp only [show ¬(j₀ < i) from not_lt.mpr h1, ite_false]
        by_cases h2 : i = j₀
        · subst h2; simp only [ite_true, n']; ring
        · simp [h2]
    simp_rw [h_each, Finset.sum_add_distrib, hA_ite, zero_add,
      Finset.sum_ite_eq', Finset.mem_univ, ite_true]

/-- **nbLinComb_nonzero_somewhere** (PROVEN from sub-axioms):
    If w ≠ 0, nbLinComb is nonzero on some open subinterval of (0,1).

    Proof: Let j₀ = max index with w_{j₀} ≠ 0, n' = j₀+2, A = Σ wᵢ(i+2).
    Case A ≠ 0: On (n'/(n'+1), 1), nbLinComb = A(1/x-1) ≠ 0 (via fract_eq_sub).
    Case A = 0: Via nbLinComb_neg_interval, constant -w_{j₀} ≠ 0 on some interval. -/
theorem nbLinComb_nonzero_somewhere (N : ℕ) (_ : 2 ≤ N)
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
        exact Fin.lt_def.mpr (by omega))) x hx_lo hx_hi]
    exact mul_ne_zero hA (by
      have hx_pos : 0 < x := by linarith [show (0:ℝ) < ↑n' / (↑n' + 1) by positivity]
      linarith [show 1 < 1/x from by rw [one_div]; exact one_lt_inv_iff₀.mpr ⟨hx_pos, hx_hi⟩])
  · -- CASE A = 0: nbLinComb = -w_{j₀} ≠ 0 on some interval
    push_neg at hA
    obtain ⟨c, d, hc, hcd, hd, heq⟩ := nbLinComb_neg_interval N w j₀ hw_above hA
    exact ⟨c, d, hc, hcd, hd, fun x hx => by rw [heq x hx]; exact neg_ne_zero.mpr hwj₀⟩

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
