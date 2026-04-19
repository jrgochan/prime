import Cathedral.Defs
import Mathlib.Analysis.InnerProductSpace.PiL2

/-! # SpectralRH.RayleighBridge
The bridge between the Rayleigh quotient (quadratic form) and matrix eigenvalues.

Key results:
- `realQuadForm_add` : x†(A+B)x = x†Ax + x†Bx
- `min_eigenvalue_le_quadForm` : λ_min(A) ≤ x†Ax for unit x
- `weyl_min_eigenvalue` : λ_min(A+B) ≥ λ_min(A) + λ_min(B)

The bridge uses the EuclideanSpace ↔ (Fin n → ℝ) correspondence:
- `inner` on EuclideanSpace ↔ `dotProduct` on Fin n → ℝ
- `EuclideanSpace.inner_toLp_toLp` provides the coercion
- Parseval's identity `sum_sq_inner_right` gives ‖x‖² = Σ ⟨eᵢ,x⟩²
-/

noncomputable section
open Complex Real Matrix Finset

-- ════════════════════════════════════════════════
-- PART I: QUADRATIC FORM BASICS
-- ════════════════════════════════════════════════

variable {n : ℕ}

/-- The real quadratic form xᵀAx for a real matrix A. -/
def realQuadForm (A : Matrix (Fin n) (Fin n) ℝ) (x : Fin n → ℝ) : ℝ :=
  dotProduct x (A.mulVec x)

/-- The quadratic form is additive in the matrix: xᵀ(A+B)x = xᵀAx + xᵀBx. -/
theorem realQuadForm_add (A B : Matrix (Fin n) (Fin n) ℝ) (x : Fin n → ℝ) :
    realQuadForm (A + B) x = realQuadForm A x + realQuadForm B x := by
  simp [realQuadForm, Matrix.add_mulVec, dotProduct_add]

-- ════════════════════════════════════════════════
-- PART II: INNER PRODUCT ↔ DOT PRODUCT BRIDGE
-- ════════════════════════════════════════════════

/-- For real vectors, the EuclideanSpace inner product equals the dotProduct.
    This is the key bridge lemma between the abstract inner product space
    setting (where Mathlib's spectral theory lives) and our concrete
    matrix-vector setting (where our Gram matrix proofs live). -/
theorem inner_eq_dotProduct (x y : Fin n → ℝ) :
    @inner ℝ (EuclideanSpace ℝ (Fin n)) _
      (WithLp.toLp 2 x) (WithLp.toLp 2 y) = dotProduct x y := by
  simp only [PiLp.inner_apply, dotProduct]
  congr 1; ext i
  simp [inner, mul_comm]

-- Note: The L2 norm ‖WithLp.toLp 2 x‖ is NOT equal to the Pi norm ‖x‖ (which is L∞).
-- Instead, we use the L2 norm directly in min_eigenvalue_le_quadForm's hypothesis.

-- ════════════════════════════════════════════════
-- PART III: QUADRATIC FORM AT EIGENVECTORS
-- ════════════════════════════════════════════════

/-- The quadratic form at an eigenvector equals the eigenvalue.
    If A v = λ v and ‖v‖ = 1, then vᵀAv = λ.
    This follows directly from vᵀ(λv) = λ(vᵀv) = λ·1 = λ. -/
theorem quadForm_eigenvector
    {A : Matrix (Fin n) (Fin n) ℝ} (hA : A.IsHermitian) (i : Fin n) :
    realQuadForm A (⇑(hA.eigenvectorBasis i)) = hA.eigenvalues i := by
  unfold realQuadForm
  rw [hA.mulVec_eigenvectorBasis i]
  -- Goal: dotProduct v (λ • v) = λ
  -- where v = eigenvectorBasis i, λ = eigenvalues i
  simp only [dotProduct_smul, smul_eq_mul]
  -- Goal: eigenvalues i * dotProduct v v = eigenvalues i
  -- Since v is orthonormal, dotProduct v v = ‖v‖² = 1
  have hv := hA.eigenvectorBasis.orthonormal.1 i
  -- hv : ‖eigenvectorBasis i‖ = 1
  -- Connect dotProduct to inner product, then to norm
  have hdot : dotProduct (⇑(hA.eigenvectorBasis i)) (⇑(hA.eigenvectorBasis i)) = 1 := by
    -- dotProduct v v = ⟪toLp v, toLp v⟫ = ‖toLp v‖² = ‖v‖² = 1
    rw [← inner_eq_dotProduct]
    simp [inner_self_eq_norm_sq_to_K, hv]
  rw [hdot, mul_one]

-- ════════════════════════════════════════════════
-- PART IV: RAYLEIGH BOUND (λ_min ≤ xᵀAx)
-- ════════════════════════════════════════════════

/-- For a real symmetric matrix A, for any unit vector x:
    (min eigenvalue of A) ≤ xᵀAx.

    This is the Rayleigh quotient lower bound. The proof uses
    Parseval's identity and the weighted sum bound:
    xᵀAx = Σ λᵢ ⟨eᵢ,x⟩² ≥ λ_min · Σ ⟨eᵢ,x⟩² = λ_min · ‖x‖² = λ_min -/
theorem min_eigenvalue_le_quadForm
    {A : Matrix (Fin n) (Fin n) ℝ} (hA : A.IsHermitian)
    (x : Fin n → ℝ) (hx : ‖(WithLp.toLp 2 x : EuclideanSpace ℝ (Fin n))‖ = 1)
    (hn : 0 < n) :
    (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀
    ≤ realQuadForm A x := by
  -- Strategy: We show xᵀAx = Σ λᵢ cᵢ² ≥ λ_min in three steps:
  -- (1) Express xᵀAx as a sum over the eigenbasis
  -- (2) Bound each term: λ_min * cᵢ² ≤ λᵢ * cᵢ²
  -- (3) Use Parseval: Σ cᵢ² = ‖x‖² = 1

  -- The eigenvector basis (indexed by Fin n)
  set b := hA.eigenvectorBasis with hb_def
  set ev := hA.eigenvalues with hev_def

  -- Step 0: inf' of eigenvalues₀ ≤ eigenvalues i for all i
  -- eigenvalues i = eigenvalues₀ (equivOfCardEq ... |>.symm i)
  -- so inf' ≤ eigenvalues₀ j ≤ eigenvalues i for the right j
  have h_inf_le : ∀ i : Fin n,
      (univ : Finset (Fin (Fintype.card (Fin n)))).inf'
        (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
        hA.eigenvalues₀ ≤ ev i := by
    intro i
    -- ev i = hA.eigenvalues i = hA.eigenvalues₀ (equiv.symm i)
    -- so this is inf' ≤ eigenvalues₀ (some j)
    show _ ≤ hA.eigenvalues i
    simp only [Matrix.IsHermitian.eigenvalues]
    exact inf'_le _ (Finset.mem_univ _)

  -- Step 1: Rewrite realQuadForm as inner product
  -- realQuadForm A x = dotProduct x (A *ᵥ x) = ⟪toLp x, toLp (A *ᵥ x)⟫
  set x' := WithLp.toLp (p := 2) x with hx'_def

  have hqf_inner : realQuadForm A x =
      @inner ℝ (EuclideanSpace ℝ (Fin n)) _ x' (WithLp.toLp 2 (A.mulVec x)) := by
    unfold realQuadForm
    exact (inner_eq_dotProduct x (A.mulVec x)).symm

  -- Step 2: Self-adjointness gives us
  -- hS : ∀ v w, ⟪toEuclideanLin A v, w⟫ = ⟪v, toEuclideanLin A w⟫
  -- toEuclideanLin = toLpLin 2 2
  have hS := isSymmetric_toEuclideanLin_iff.symm.mp hA

  -- toLpLin 2 2 A x' = toLp (A *ᵥ x), and toLpLin 2 2 = toEuclideanLin
  have h_toLpLin : toEuclideanLin A x' = WithLp.toLp 2 (A.mulVec x) := rfl

  -- Step 3: For each eigenvector eᵢ:
  -- ⟪eᵢ, Ax'⟫ = ⟪eᵢ, toEuclideanLin A x'⟫
  --            = ⟪toEuclideanLin A eᵢ, x'⟫     (self-adjointness, reversed)
  --            = ⟪toLp(λᵢ • eᵢ), x'⟫           (mulVec_eigenvectorBasis)
  --            = λᵢ ⟪eᵢ, x'⟫                   (linearity of inner)
  have h_eig_inner : ∀ i : Fin n,
      @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec x)) =
      ev i * @inner ℝ _ _ (b i) x' := by
    intro i
    -- ⟪eᵢ, Ax'⟫ = ⟪eᵢ, f(x')⟫ where f = toEuclideanLin A
    -- First compute f(eᵢ) = ev i • eᵢ
    have h_eigvec : toEuclideanLin A (b i) = ev i • (b i) := by
      simp only [toEuclideanLin, toLpLin_apply, hev_def, hb_def]
      rw [hA.mulVec_eigenvectorBasis i]
      simp [WithLp.toLp_smul]
    -- Self-adjointness: ⟪eᵢ, f(x')⟫ = ⟪f(eᵢ), x'⟫ = ⟪λ•eᵢ, x'⟫ = λ⟪eᵢ, x'⟫
    calc @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec x))
        = @inner ℝ _ _ (b i) (toEuclideanLin A x') := rfl
      _ = @inner ℝ _ _ (toEuclideanLin A (b i)) x' := (hS (b i) x').symm
      _ = @inner ℝ _ _ (ev i • (b i)) x' := by rw [h_eigvec]
      _ = ev i * @inner ℝ _ _ (b i) x' := by rw [inner_smul_left]; simp

  -- Step 4: Express ⟪x', Ax'⟫ = Σ ev i * ⟪eᵢ, x'⟫²
  -- using resolution of identity: ⟪x', y⟫ = Σ ⟪x', eᵢ⟫ * ⟪eᵢ, y⟫
  have h_expand : @inner ℝ _ _ x' (WithLp.toLp 2 (A.mulVec x)) =
      ∑ i, @inner ℝ _ _ x' (b i) * (ev i * @inner ℝ _ _ (b i) x') := by
    conv_lhs => rw [show @inner ℝ _ _ x' (WithLp.toLp 2 (A.mulVec x)) =
      ∑ i, @inner ℝ _ _ x' (b i) *
        @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec x))
      from (b.sum_inner_mul_inner x' (WithLp.toLp 2 (A.mulVec x))).symm]
    congr 1; ext i; rw [h_eig_inner i]

  -- Step 5: Bound: inf' ≤ Σ ⟪x', eᵢ⟫ * (ev i * ⟪eᵢ, x'⟫)
  rw [hqf_inner, h_expand]
  -- Goal: inf' ≤ Σ ⟪x', eᵢ⟫ * (ev i * ⟪eᵢ, x'⟫)
  -- Each term = ev i * (⟪x', eᵢ⟫ * ⟪eᵢ, x'⟫) = ev i * ⟪eᵢ, x'⟫²
  -- Using ⟪x', eᵢ⟫ = conj ⟪eᵢ, x'⟫ = ⟪eᵢ, x'⟫ (real)
  -- So = ev i * ⟪eᵢ, x'⟫², and ev i ≥ inf', and Σ ⟪eᵢ, x'⟫² = 1
  -- Goal: λ_min ≤ Σ ⟪x', eᵢ⟫ * (ev i * ⟪eᵢ, x'⟫)
  -- For reals: ⟪x', eᵢ⟫ = ⟪eᵢ, x'⟫, so each term = ev i * ⟪eᵢ, x'⟫²
  set lmin := (univ : Finset (Fin (Fintype.card (Fin n)))).inf'
    (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
    hA.eigenvalues₀ with hlmin_def

  -- Rewrite using ⟪x', eᵢ⟫ = ⟪eᵢ, x'⟫ (real symmetry)
  have h_comm : ∀ i : Fin n,
      @inner ℝ _ _ x' (b i) = @inner ℝ _ _ (b i) x' := by
    intro i; exact (real_inner_comm x' (b i)).symm

  simp_rw [h_comm]
  -- Goal: lmin ≤ Σ ⟪eᵢ, x'⟫ * (ev i * ⟪eᵢ, x'⟫)

  -- Each term simplifies to ev i * ⟪eᵢ, x'⟫²
  have h_sq : ∀ i : Fin n, @inner ℝ _ _ (b i) x' * (ev i * @inner ℝ _ _ (b i) x') =
      ev i * (@inner ℝ _ _ (b i) x' ^ 2) := by
    intro i; ring

  simp_rw [h_sq]
  -- Goal: lmin ≤ Σ ev i * ⟪eᵢ, x'⟫²

  -- Use Parseval: Σ ⟪eᵢ, x'⟫² = ‖x'‖² = 1
  have h_parseval : ∑ i : Fin n, @inner ℝ _ _ (b i) x' ^ 2 = 1 := by
    have hp := b.sum_sq_inner_right x'
    -- hp : Σ ⟪b i, x'⟫² = ‖x'‖²
    -- hx : ‖x'‖ = 1 (since x' = toLp x and hx refers to the same norm)
    -- So hp gives Σ = ‖x'‖² = 1² = 1
    calc ∑ i : Fin n, @inner ℝ _ _ (b i) x' ^ 2 = ‖x'‖ ^ 2 := hp
      _ = 1 ^ 2 := by rw [hx]
      _ = 1 := one_pow 2

  -- Weighted sum bound: Σ ev i * cᵢ² ≥ lmin * Σ cᵢ² = lmin * 1 = lmin
  calc lmin = lmin * 1 := (mul_one _).symm
    _ = lmin * ∑ i, @inner ℝ _ _ (b i) x' ^ 2 := by rw [h_parseval]
    _ = ∑ i, lmin * (@inner ℝ _ _ (b i) x' ^ 2) := by rw [Finset.mul_sum]
    _ ≤ ∑ i, ev i * (@inner ℝ _ _ (b i) x' ^ 2) := by
        apply Finset.sum_le_sum
        intro i _
        exact mul_le_mul_of_nonneg_right (h_inf_le i) (sq_nonneg _)

-- ════════════════════════════════════════════════
-- PART V: WEYL'S INEQUALITY
-- ════════════════════════════════════════════════

/-- **Weyl's Inequality** for minimum eigenvalues of Hermitian matrices.
    For Hermitian A, B: λ_min(A + B) ≥ λ_min(A) + λ_min(B).

    Proof:
    The min eigenvector e of A+B satisfies eᵀ(A+B)e = λ_min(A+B).
    Also eᵀ(A+B)e = eᵀAe + eᵀBe ≥ λ_min(A) + λ_min(B). -/
theorem weyl_min_eigenvalue
    {A B : Matrix (Fin n) (Fin n) ℝ}
    (hA : A.IsHermitian) (hB : B.IsHermitian)
    (hn : 0 < n) :
    let hAB : (A + B).IsHermitian := hA.add hB
    (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hAB.eigenvalues₀
    ≥
    (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀
    +
    (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hB.eigenvalues₀ := by
  intro hAB
  show _ ≤ _
  apply Finset.le_inf'
  intro j _
  -- eigenvalues₀ j ∈ range(eigenvalues) because eigenvalues is a reindexing
  have h_in_range : hAB.eigenvalues₀ j ∈ Set.range hAB.eigenvalues := by
    -- eigenvalues k = eigenvalues₀ ((equivOfCardEq (card_fin _)).symm k)
    -- Since .symm is surjective, every eigenvalues₀ j = eigenvalues (equivOfCardEq j)
    unfold Matrix.IsHermitian.eigenvalues
    simp only [Set.mem_range]
    -- After unfolding, goal should be: ∃ x, eigenvalues₀ (equiv.symm x) = eigenvalues₀ j
    -- equiv.symm is surjective, so there exists x with equiv.symm x = j
    exact ⟨(Fintype.equivOfCardEq (Fintype.card_fin _)) j,
           by simp [Equiv.symm_apply_apply]⟩
  obtain ⟨i, hi⟩ := h_in_range
  rw [← hi, ← quadForm_eigenvector hAB i, realQuadForm_add]
  have h_unit : ‖(WithLp.toLp 2 (⇑(hAB.eigenvectorBasis i)) : EuclideanSpace ℝ (Fin n))‖ = 1 :=
    hAB.eigenvectorBasis.orthonormal.1 i
  exact add_le_add
    (min_eigenvalue_le_quadForm hA _ h_unit hn)
    (min_eigenvalue_le_quadForm hB _ h_unit hn)
-- ════════════════════════════════════════════════
-- PART VI: POSITIVE DEFINITENESS → λ_min > 0
-- ════════════════════════════════════════════════

/-- If xᵀAx > 0 for all nonzero x, then λ_min(A) > 0.

    Proof: Each eigenvalue λᵢ = vᵢᵀ A vᵢ where vᵢ is the i-th
    eigenvector (a unit vector from the orthonormal eigenbasis).
    Since vᵢ ≠ 0, the positive definiteness gives λᵢ > 0.
    All eigenvalues positive ⟹ the minimum is positive.

    This converts the algebraic notion of positive definiteness
    (quadratic form > 0) to the spectral notion (all eigenvalues > 0). -/
theorem pos_def_implies_min_eigenvalue_pos
    {A : Matrix (Fin n) (Fin n) ℝ} (hA : A.IsHermitian) (hn : 0 < n)
    (hpd : ∀ v : Fin n → ℝ, v ≠ 0 → 0 < realQuadForm A v) :
    0 < (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀ := by
  -- Show each eigenvalue₀ j is positive, then inf' is positive
  rw [Finset.lt_inf'_iff]
  intro j _
  -- eigenvalues₀ j is an actual eigenvalue λᵢ for some i
  -- eigenvalues j = eigenvalues₀ (equiv.symm j), so eigenvalues₀ is a reindexing
  -- We'll go through eigenvalues (indexed by Fin n)
  have h_in_range : hA.eigenvalues₀ j ∈ Set.range hA.eigenvalues := by
    unfold Matrix.IsHermitian.eigenvalues
    simp only [Set.mem_range]
    exact ⟨(Fintype.equivOfCardEq (Fintype.card_fin _)) j,
           by simp [Equiv.symm_apply_apply]⟩
  obtain ⟨i, hi⟩ := h_in_range
  rw [← hi, ← quadForm_eigenvector hA i]
  -- Goal: 0 < realQuadForm A (eigenvectorBasis i)
  -- The eigenvector is nonzero (it has norm 1)
  apply hpd
  -- Show eigenvectorBasis i ≠ 0 (as a Fin n → ℝ)
  -- The coercion ⇑ gives .ofLp : EuclideanSpace → (Fin n → ℝ)
  intro h_zero
  -- h_zero : ⇑(eigenvectorBasis i) = 0  (as Fin n → ℝ)
  -- hv : ‖eigenvectorBasis i‖ = 1 (in EuclideanSpace)
  have hv := hA.eigenvectorBasis.orthonormal.1 i
  -- If the coercion to (Fin n → ℝ) is zero, then the EuclideanSpace element
  -- has norm 0, contradicting ‖·‖ = 1
  have : ‖hA.eigenvectorBasis i‖ = 0 := by
    rw [EuclideanSpace.norm_eq]
    simp [show (hA.eigenvectorBasis i).1 = (0 : Fin n → ℝ) from h_zero]
  linarith

-- ════════════════════════════════════════════════
-- PART VI-B: REVERSE RAYLEIGH BOUND (λ_min ≥ c)
-- ════════════════════════════════════════════════

/-- **Reverse Rayleigh Bound**: If xᵀAx ≥ c · ‖x‖² for all x,
    then λ_min(A) ≥ c.

    This is the converse of `min_eigenvalue_le_quadForm`:
    - Forward:  λ_min(A) ≤ xᵀAx for unit x
    - Reverse:  (∀ x, xᵀAx ≥ c·‖x‖²) → λ_min(A) ≥ c

    Proof: Each eigenvalue λᵢ = vᵢᵀAvᵢ ≥ c · ‖vᵢ‖² = c · 1 = c
    (since eigenvectors are unit vectors). So inf(λᵢ) ≥ c.

    Together with `min_eigenvalue_le_quadForm`, this gives the full
    Rayleigh characterization: λ_min = inf_{‖x‖=1} xᵀAx. -/
theorem quadform_lower_implies_eigenvalue_lower
    {A : Matrix (Fin n) (Fin n) ℝ} (hA : A.IsHermitian) (hn : 0 < n)
    (c : ℝ) (h : ∀ v : Fin n → ℝ,
      realQuadForm A v ≥ c * dotProduct v v) :
    (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀ ≥ c := by
  -- Unfold ≥ to ≤ for Finset.le_inf'_iff
  show c ≤ _
  rw [Finset.le_inf'_iff]
  intro j hj
  -- eigenvalues₀ j = eigenvalues i for some i
  have h_in_range : hA.eigenvalues₀ j ∈ Set.range hA.eigenvalues := by
    unfold Matrix.IsHermitian.eigenvalues
    simp only [Set.mem_range]
    exact ⟨(Fintype.equivOfCardEq (Fintype.card_fin _)) j,
           by simp [Equiv.symm_apply_apply]⟩
  obtain ⟨i, hi⟩ := h_in_range
  rw [← hi, ← quadForm_eigenvector hA i]
  -- Goal: c ≤ realQuadForm A (eigenvectorBasis i)
  -- From hypothesis: realQuadForm A v ≥ c * dotProduct v v for all v
  -- For eigenvector v = eigenvectorBasis i: dotProduct v v = ‖v‖² = 1
  have h_bound := h (⇑(hA.eigenvectorBasis i))
  -- dotProduct v v = 1 for unit eigenvector
  have h_unit : dotProduct (⇑(hA.eigenvectorBasis i))
                           (⇑(hA.eigenvectorBasis i)) = 1 := by
    rw [← inner_eq_dotProduct]
    simp [inner_self_eq_norm_sq_to_K, hA.eigenvectorBasis.orthonormal.1 i]
  -- h_bound : realQuadForm A v ≥ c * (v ⬝ᵥ v)
  -- h_unit : v ⬝ᵥ v = 1
  -- So: realQuadForm A v ≥ c * 1 = c
  rw [h_unit, mul_one] at h_bound
  linarith

end

-- ════════════════════════════════════════════════
-- PART VII: VECTOR PADDING FOR INTERLACING
-- ════════════════════════════════════════════════

section PadVector
open Matrix

/-- Pad a vector with a zero at the end to embed ℝⁿ into ℝⁿ⁺¹. -/
noncomputable def padVector {n : ℕ} (v : Fin n → ℝ) : Fin (n + 1) → ℝ :=
  Fin.snoc v 0

lemma padVector_dotProduct {n : ℕ} (v : Fin n → ℝ) :
    dotProduct (padVector v) (padVector v) = dotProduct v v := by
  unfold dotProduct padVector
  rw [Fin.sum_univ_castSucc]
  simp [Fin.snoc_castSucc, Fin.snoc_last]

lemma padVector_norm {n : ℕ} (v : Fin n → ℝ)
    (h : ‖(WithLp.toLp 2 v : EuclideanSpace ℝ (Fin n))‖ = 1) :
    ‖(WithLp.toLp 2 (padVector v) : EuclideanSpace ℝ (Fin (n + 1)))‖ = 1 := by
  have h_dot : dotProduct v v = 1 := by
    have h1 : dotProduct v v =
        @inner ℝ (EuclideanSpace ℝ (Fin n)) _
          (WithLp.toLp 2 v) (WithLp.toLp 2 v) := (inner_eq_dotProduct v v).symm
    rw [h1, real_inner_self_eq_norm_sq, h, one_pow]
  have h_pad_sq : ‖(WithLp.toLp 2 (padVector v) : EuclideanSpace ℝ (Fin (n + 1)))‖ ^ 2 = 1 := by
    have h1 : dotProduct (padVector v) (padVector v) =
        @inner ℝ (EuclideanSpace ℝ (Fin (n + 1))) _
          (WithLp.toLp 2 (padVector v)) (WithLp.toLp 2 (padVector v)) :=
      (inner_eq_dotProduct (padVector v) (padVector v)).symm
    rw [← real_inner_self_eq_norm_sq]; rw [← h1]; rw [padVector_dotProduct]; exact h_dot
  nlinarith [norm_nonneg (WithLp.toLp 2 (padVector v) : EuclideanSpace ℝ (Fin (n + 1)))]

/-- The quadratic form of a padded vector over G_{n+2} equals the
    quadratic form of the original vector over G_{n+1}. -/
private lemma quadForm_padVector_of {m : ℕ} (v : Fin m → ℝ) :
    realQuadForm (of (fun (i j : Fin (m + 1)) => gramEntry (i.val + 1) (j.val + 1)))
                 (padVector v) =
    realQuadForm (of (fun (i j : Fin m) => gramEntry (i.val + 1) (j.val + 1))) v := by
  simp only [realQuadForm, dotProduct, mulVec, of_apply, padVector,
    Fin.sum_univ_castSucc, Fin.snoc_castSucc, Fin.snoc_last,
    zero_mul, mul_zero, add_zero, Fin.val_castSucc]

lemma quadForm_padVector {n : ℕ} (v : Fin n → ℝ) :
    realQuadForm (gramMatrix (n + 2)) (padVector v) = realQuadForm (gramMatrix (n + 1)) v :=
  quadForm_padVector_of v

end PadVector
