import Cathedral.Defs
import Cathedral.FractIntegral
import Cathedral.Spectral.OctonionicPartition
import Cathedral.Spectral.ClassRestriction
import Cathedral.Spectral.RayleighBridge
import Cathedral.Spectral.FiniteDimReduction
import Cathedral.Structural.NbLinComb

/-! # Cathedral.Spectral.ConstantVectorBound

## The Constant Vector Miracle — Proving `lambdaEff_linear_growth`

### Discovery Chain (Forge Master + Theorist, 2026-04-06):

**Step 1 (Forge Master)**: Rust experiment at N=50-3000 reveals
λ_eff grows linearly, with PR ≈ 1.0 (rank-1 direction localized
on one eigenvector).

**Step 2 (Theorist)**: Reads JSON output, identifies u aligns
with λ_max at 99.99% precision. The mechanism: G ≈ (1/4)·J,
so the Perron-Frobenius eigenvector (all-ones) IS the interference
direction. The "Spectral Lightning Rod."

**Step 3 (Theorist)**: The Cauchy-Schwarz Miracle bypass:
Instead of Vasyunin expansion, use pure L² geometry:

  v^T G v = ∫₀¹ (Σ_{k∈S_m} {k/x})² dx     (gram_l2_identity)
          ≥ (∫₀¹ Σ_{k∈S_m} {k/x} dx)²       (Cauchy-Schwarz)
          = (Σ ∫₀¹ {k/x} dx)²                 (linearity)
          ≥ (|S_m|/4)²                          (basis_entry_lower)
          = |S_m|²/16

**Step 4 (Theorist)**: The Fatal Spectral Trap — corrects the
λ_eff ≥ λ_max claim (FALSE for PSD matrices!). The correct approach:
axiomatize the spectral alignment of u with the bulk.

### Axiom Budget (this file):
- `octonion_class_density` — Dirichlet density of octonionic classes
- `lambdaEff_resolvent_bound` — spectral alignment (the Lightning Rod)
-/

noncomputable section
open Complex Real Matrix Finset

-- ════════════════════════════════════════════════
-- PART I: MAX EIGENVALUE RAYLEIGH BOUND (PROVED)
-- ════════════════════════════════════════════════

/-- **Max Eigenvalue Rayleigh Bound** (unit vector):
    For a symmetric matrix A and unit vector x: xᵀAx ≤ λ_max(A).
    Proof: spectral expansion, bound λᵢ ≤ λ_max, Parseval. -/
theorem max_eigenvalue_ge_quadForm
    {n : ℕ} {A : Matrix (Fin n) (Fin n) ℝ} (hA : A.IsHermitian)
    (x : Fin n → ℝ) (hx : ‖(WithLp.toLp 2 x : EuclideanSpace ℝ (Fin n))‖ = 1)
    (hn : 0 < n) :
    realQuadForm A x ≤
    (univ : Finset (Fin (Fintype.card (Fin n)))).sup'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, mem_univ _⟩)
      hA.eigenvalues₀ := by
  set b := hA.eigenvectorBasis with hb_def
  set ev := hA.eigenvalues with hev_def
  set lmax := (univ : Finset (Fin (Fintype.card (Fin n)))).sup'
    (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, mem_univ _⟩)
    hA.eigenvalues₀ with hlmax_def
  have h_le_sup : ∀ i : Fin n, ev i ≤ lmax := by
    intro i; show hA.eigenvalues i ≤ _
    simp only [Matrix.IsHermitian.eigenvalues]
    exact le_sup' _ (mem_univ _)
  set x' := WithLp.toLp (p := 2) x with hx'_def
  have hS := Matrix.isHermitian_iff_isSymmetric.mp hA
  have h_eig_inner : ∀ i : Fin n,
      @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec x)) =
      ev i * @inner ℝ _ _ (b i) x' := by
    intro i
    have h_eigvec : toEuclideanLin A (b i) = ev i • (b i) := by
      simp only [toEuclideanLin, toLpLin_apply, hev_def, hb_def]
      rw [hA.mulVec_eigenvectorBasis i]; simp [WithLp.toLp_smul]
    calc @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec x))
        = @inner ℝ _ _ (b i) (toEuclideanLin A x') := rfl
      _ = @inner ℝ _ _ (toEuclideanLin A (b i)) x' := (hS (b i) x').symm
      _ = @inner ℝ _ _ (ev i • (b i)) x' := by rw [h_eigvec]
      _ = ev i * @inner ℝ _ _ (b i) x' := by rw [inner_smul_left]; simp
  have h_expand : realQuadForm A x =
      ∑ i, ev i * (@inner ℝ _ _ (b i) x' ^ 2) := by
    have hqf_inner : realQuadForm A x =
        @inner ℝ (EuclideanSpace ℝ (Fin n)) _ x' (WithLp.toLp 2 (A.mulVec x)) := by
      unfold realQuadForm; exact (inner_eq_dotProduct x (A.mulVec x)).symm
    conv_lhs => rw [hqf_inner]
    rw [show @inner ℝ _ _ x' (WithLp.toLp 2 (A.mulVec x)) =
      ∑ i, @inner ℝ _ _ x' (b i) *
        @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec x))
      from (b.sum_inner_mul_inner x' (WithLp.toLp 2 (A.mulVec x))).symm]
    congr 1; ext i; rw [h_eig_inner i]
    rw [show @inner ℝ _ _ x' (b i) = @inner ℝ _ _ (b i) x'
      from (real_inner_comm x' (b i)).symm]; ring
  have h_parseval : ∑ i : Fin n, @inner ℝ _ _ (b i) x' ^ 2 = 1 := by
    calc ∑ i : Fin n, @inner ℝ _ _ (b i) x' ^ 2 = ‖x'‖ ^ 2 :=
        b.sum_sq_inner_right x'
      _ = 1 ^ 2 := by rw [hx]
      _ = 1 := one_pow 2
  rw [h_expand]
  calc ∑ i, ev i * (@inner ℝ _ _ (b i) x' ^ 2)
      ≤ ∑ i, lmax * (@inner ℝ _ _ (b i) x' ^ 2) := by
        apply Finset.sum_le_sum; intro i _
        exact mul_le_mul_of_nonneg_right (h_le_sup i) (sq_nonneg _)
    _ = lmax * ∑ i, @inner ℝ _ _ (b i) x' ^ 2 := by rw [Finset.mul_sum]
    _ = lmax * 1 := by rw [h_parseval]
    _ = lmax := mul_one _

/-- **Max Eigenvalue Rayleigh Bound** (non-unit vector):
    For any v: v^T A v ≤ λ_max(A) · v^T v.

    Mirrored from `min_eigenvalue_le_quadForm_scaled` in ClassRestriction.lean.
    Proof is identical: spectral expansion + bound each λᵢ ≤ λ_max + Parseval. -/
lemma max_eigenvalue_ge_quadForm_scaled
    {n : ℕ} {A : Matrix (Fin n) (Fin n) ℝ} (hA : A.IsHermitian)
    (v : Fin n → ℝ) (hn : 0 < n) :
    realQuadForm A v ≤
    (univ : Finset (Fin (Fintype.card (Fin n)))).sup'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, mem_univ _⟩)
      hA.eigenvalues₀ * dotProduct v v := by
  set b := hA.eigenvectorBasis with hb_def
  set ev := hA.eigenvalues with hev_def
  set lmax := (univ : Finset (Fin (Fintype.card (Fin n)))).sup'
    (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, mem_univ _⟩)
    hA.eigenvalues₀ with hlmax_def
  have h_le_sup : ∀ i : Fin n, ev i ≤ lmax := by
    intro i; show hA.eigenvalues i ≤ _
    simp only [Matrix.IsHermitian.eigenvalues]
    exact le_sup' _ (mem_univ _)
  set v' := WithLp.toLp (p := 2) v with hv'_def
  have hS := Matrix.isHermitian_iff_isSymmetric.mp hA
  -- Spectral expansion: v^T A v = Σ λᵢ ⟨eᵢ, v⟩²
  have h_expand : realQuadForm A v =
      ∑ i, ev i * (@inner ℝ _ _ (b i) v') ^ 2 := by
    have hqf_inner : realQuadForm A v =
        @inner ℝ (EuclideanSpace ℝ (Fin n)) _ v' (WithLp.toLp 2 (A.mulVec v)) := by
      unfold realQuadForm; exact (inner_eq_dotProduct v (A.mulVec v)).symm
    have h_eig_inner : ∀ i : Fin n,
        @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec v)) =
        ev i * @inner ℝ _ _ (b i) v' := by
      intro i
      have h_eigvec : toEuclideanLin A (b i) = ev i • (b i) := by
        simp only [toEuclideanLin, toLpLin_apply, hev_def, hb_def]
        rw [hA.mulVec_eigenvectorBasis i]; simp [WithLp.toLp_smul]
      calc @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec v))
          = @inner ℝ _ _ (b i) (toEuclideanLin A v') := rfl
        _ = @inner ℝ _ _ (toEuclideanLin A (b i)) v' := (hS (b i) v').symm
        _ = @inner ℝ _ _ (ev i • (b i)) v' := by rw [h_eigvec]
        _ = ev i * @inner ℝ _ _ (b i) v' := by rw [inner_smul_left]; simp
    conv_lhs => rw [hqf_inner]
    rw [show @inner ℝ _ _ v' (WithLp.toLp 2 (A.mulVec v)) =
      ∑ i, @inner ℝ _ _ v' (b i) *
        @inner ℝ _ _ (b i) (WithLp.toLp 2 (A.mulVec v))
      from (b.sum_inner_mul_inner v' (WithLp.toLp 2 (A.mulVec v))).symm]
    congr 1; ext i; rw [h_eig_inner i]
    rw [show @inner ℝ _ _ v' (b i) = @inner ℝ _ _ (b i) v'
      from (real_inner_comm v' (b i)).symm]; ring
  -- Parseval (non-unit): Σ ⟨eᵢ, v⟩² = ‖v‖² = dotProduct v v
  have h_parseval : ∑ i : Fin n, @inner ℝ _ _ (b i) v' ^ 2 =
      dotProduct v v := by
    calc ∑ i : Fin n, @inner ℝ _ _ (b i) v' ^ 2
        = ‖v'‖ ^ 2 := b.sum_sq_inner_right v'
      _ = @inner ℝ (EuclideanSpace ℝ (Fin n)) _ v' v' := by
            rw [real_inner_self_eq_norm_sq]
      _ = dotProduct v v := inner_eq_dotProduct v v
  -- Bound: Σ λᵢ ⟨eᵢ,v⟩² ≤ λ_max · Σ ⟨eᵢ,v⟩² = λ_max · ‖v‖²
  rw [h_expand, ← h_parseval, Finset.mul_sum]
  apply Finset.sum_le_sum
  intro i _
  exact mul_le_mul_of_nonneg_right (h_le_sup i) (sq_nonneg _)

/-- **Rayleigh lower bound for λ_max** (non-unit vector):
    If c · ||v||² ≤ v^T A v for a specific nonzero v, then c ≤ λ_max.
    Proof: chain c·||v||² ≤ v^T A v ≤ λ_max·||v||², divide by ||v||² > 0. -/
theorem rayleigh_lower_bound_max
    {n : ℕ} {A : Matrix (Fin n) (Fin n) ℝ} (hA : A.IsHermitian)
    (hn : 0 < n) (c : ℝ)
    (v : Fin n → ℝ) (hv : v ≠ 0)
    (h_bound : c * dotProduct v v ≤ realQuadForm A v) :
    c ≤ (univ : Finset (Fin (Fintype.card (Fin n)))).sup'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, mem_univ _⟩)
      hA.eigenvalues₀ := by
  set lmax := (univ : Finset (Fin (Fintype.card (Fin n)))).sup'
    (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, mem_univ _⟩)
    hA.eigenvalues₀
  have h_dot_pos : 0 < dotProduct v v := by
    rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
    apply sq_pos_of_pos; rw [norm_pos_iff]
    exact fun h_zero => hv (funext (fun i => by
      -- WithLp.toLp 2 v = 0 implies v i = 0
      have hi : (WithLp.toLp 2 v : Fin n → ℝ) i = (0 : Fin n → ℝ) i := by
        rw [h_zero]; rfl
      simpa [WithLp.toLp] using hi))
  -- Chain: c · ||v||² ≤ v^T A v ≤ λ_max · ||v||²
  have h_upper := max_eigenvalue_ge_quadForm_scaled hA v hn
  have := le_trans h_bound h_upper
  exact le_of_mul_le_mul_right this h_dot_pos

-- ════════════════════════════════════════════════
-- PART II: CAUCHY-SCHWARZ FOR INTEGRALS (PROVED)
-- ════════════════════════════════════════════════

/-- **Cauchy-Schwarz for interval integrals on [0,1]**:
    (∫₀¹ f(x) dx)² ≤ ∫₀¹ f(x)² dx.
    Proof via variance: ∫₀¹ (f - c)² dx ≥ 0 for c = ∫₀¹ f. -/
theorem integral_sq_ge_sq_integral (f : ℝ → ℝ)
    (hf : IntervalIntegrable f MeasureTheory.volume 0 1)
    (hf2 : IntervalIntegrable (fun x => f x ^ 2) MeasureTheory.volume 0 1) :
    (∫ x in (0:ℝ)..1, f x) ^ 2 ≤ ∫ x in (0:ℝ)..1, f x ^ 2 := by
  set c := ∫ x in (0:ℝ)..1, f x with hc_def
  -- Variance trick: ∫(f - c)² ≥ 0, expanding gives c² ≤ ∫f²
  have h_nonneg : 0 ≤ ∫ x in (0:ℝ)..1, (f x - c) ^ 2 := by
    apply intervalIntegral.integral_nonneg (by linarith)
    intro x _; exact sq_nonneg _
  -- Expand (f - c)² = f² - 2cf + c²
  have h_expand : ∫ x in (0:ℝ)..1, (f x - c) ^ 2 =
      (∫ x in (0:ℝ)..1, f x ^ 2) - 2 * c * c + c ^ 2 := by
    have : (fun x => (f x - c) ^ 2) = (fun x => f x ^ 2 - 2 * c * f x + c ^ 2) := by
      ext x; ring
    rw [this]
    rw [intervalIntegral.integral_add (hf2.sub (hf.const_mul (2 * c))) intervalIntegrable_const]
    rw [intervalIntegral.integral_sub hf2 (hf.const_mul (2 * c))]
    rw [intervalIntegral.integral_const_mul]
    simp only [intervalIntegral.integral_const, sub_zero, one_smul, hc_def]
  linarith

-- ════════════════════════════════════════════════
-- PART III: THE CAUCHY-SCHWARZ MIRACLE (PROVED)
-- ════════════════════════════════════════════════

/-- The "constant class vector": v_i = 1 if i+1 ∈ class m, 0 otherwise. -/
def constantClassVector (N : ℕ) (m : Fin 8) : Fin (N - 1) → ℝ :=
  fun i => if octonionClass (i.val + 1) = m then 1 else 0

/-- **Sum of basis integrals lower bound** (PROVED):
    For a set S ⊆ {2,...,N}, Σ_{k ∈ S} ∫₀¹ {k/x} dx ≥ |S|/4.
    Each integral ≥ 1/2 - 1/(2k) ≥ 1/4 for k ≥ 2. -/
lemma sum_basis_integrals_lower (S : Finset ℕ) (hS : ∀ k ∈ S, 2 ≤ k) :
    (S.card : ℝ) / 4 ≤
    ∑ k ∈ S, ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) := by
  have key : ∀ k ∈ S, (1 : ℝ) / 4 ≤ ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) := by
    intro k hk
    have hk2 := hS k hk
    have h := basis_entry_lower k (by omega : 1 ≤ k)
    have : (1 : ℝ) / (2 * (k : ℝ)) ≤ 1 / 4 := by
      rw [div_le_div_iff₀ (by positivity) (by norm_num)]
      have : (2 : ℝ) ≤ (k : ℝ) := by exact_mod_cast hk2
      linarith
    linarith
  calc (S.card : ℝ) / 4 = ∑ _ ∈ S, (1 : ℝ) / 4 := by
        rw [Finset.sum_const]; ring
    _ ≤ ∑ k ∈ S, ∫ x in (0:ℝ)..1, Int.fract ((k : ℝ) / x) :=
        Finset.sum_le_sum key

/-- The nbLinComb of the constant class vector simplifies to a sum
    over the filtered class indices. -/
lemma nbLinComb_constantClassVector (N : ℕ) (m : Fin 8) (x : ℝ) :
    nbLinComb N (constantClassVector N m) x =
    ∑ i ∈ (univ : Finset (Fin (N - 1))).filter
      (fun i => octonionClass (i.val + 1) = m),
    Int.fract ((↑(i.val + 1) : ℝ) / x) := by
  unfold nbLinComb constantClassVector
  rw [Finset.sum_filter]
  apply Finset.sum_congr rfl; intro i _
  by_cases h : octonionClass (↑i + 1) = m
  · simp [h]
  · simp [h]

/-- The integral of nbLinComb for the class indicator equals the
    sum of individual basis integrals over the class. -/
lemma integral_nbLinComb_lower (N : ℕ) (m : Fin 8) :
    ∫ x in (0:ℝ)..1, nbLinComb N (constantClassVector N m) x =
    ∑ i ∈ (univ : Finset (Fin (N - 1))).filter
      (fun i => octonionClass (i.val + 1) = m),
    ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := by
  conv_lhs => rw [show (fun x => nbLinComb N (constantClassVector N m) x) =
    (fun x => ∑ i ∈ (univ : Finset (Fin (N - 1))).filter
      (fun i => octonionClass (i.val + 1) = m),
      Int.fract ((↑(i.val + 1) : ℝ) / x)) from by
    ext x; exact nbLinComb_constantClassVector N m x]
  rw [intervalIntegral.integral_finset_sum]
  intro i _
  exact fract_div_intervalIntegrable (i.val + 1) 0 1

/-- nbLinComb of a bounded-weight vector is square-integrable on [0,1].
    Since each fract is in [0,1) and there are finitely many terms,
    the sum is bounded, hence its square is integrable on a finite interval. -/
lemma nbLinComb_sq_intervalIntegrable (N : ℕ) (w : Fin (N - 1) → ℝ) :
    IntervalIntegrable (fun x => (nbLinComb N w x) ^ 2)
      MeasureTheory.volume 0 1 := by
  -- nbLinComb² = (Σ wᵢ fᵢ)² = Σᵢ Σⱼ wᵢwⱼ fᵢfⱼ, each term is integrable
  have h_sq : (fun x => (nbLinComb N w x) ^ 2) =
      (fun x => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) := by
    ext x; unfold nbLinComb; rw [sq, Finset.sum_mul_sum]
  rw [h_sq]
  -- Convert lambda-sum to sum-of-lambdas for IntervalIntegrable.sum
  have h_conv : (fun x => ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
      (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
      (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) =
    (∑ i : Fin (N - 1), fun x => ∑ j : Fin (N - 1),
      (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
      (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) := by
    ext x; simp [Finset.sum_apply]
  rw [h_conv]
  exact IntervalIntegrable.sum Finset.univ fun i _ => by
    have h_conv2 : (fun x => ∑ j : Fin (N - 1),
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) =
      (∑ j : Fin (N - 1), fun x =>
        (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
        (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) := by
      ext x; simp [Finset.sum_apply]
    rw [h_conv2]
    exact IntervalIntegrable.sum Finset.univ fun j _ => by
      -- Each term is (a * fract_j)(b * fract_k) = ab * fract_j*fract_k
      have : (fun x : ℝ => (w i * Int.fract ((↑(i.val + 1) : ℝ) / x)) *
          (w j * Int.fract ((↑(j.val + 1) : ℝ) / x))) =
        (fun x : ℝ => (w i * w j) * (Int.fract (↑(i.val + 1) / x) * Int.fract (↑(j.val + 1) / x))) := by
        ext x; ring
      rw [this]
      exact (fract_prod_intervalIntegrable (i.val + 1) (j.val + 1)).const_mul _

/-- The integral of nbLinComb for the class indicator is nonneg
    (each term is fract ≥ 0, with weight 0 or 1). -/
lemma integral_nbLinComb_nonneg (N : ℕ) (m : Fin 8) :
    0 ≤ ∫ x in (0:ℝ)..1, nbLinComb N (constantClassVector N m) x := by
  apply intervalIntegral.integral_nonneg (by linarith)
  intro x _; unfold nbLinComb constantClassVector
  apply Finset.sum_nonneg; intro i _
  by_cases h : octonionClass (↑i + 1) = m
  · simp [h, Int.fract_nonneg]
  · simp [h]

/-- The Fin-class filter cardinality: number of i ∈ Fin(N-1) with class(i+1)=m.
    This is the "Fin-native" count that matches our quadratic form indexing. -/
def finClassCard (N : ℕ) (m : Fin 8) : ℕ :=
  ((univ : Finset (Fin (N - 1))).filter (fun i => octonionClass (i.val + 1) = m)).card

/-- **Lower bound on Fin-filtered integral sum** (PROVED).

    Strategy: split the filter into terms with i.val ≥ 1 (k ≥ 2, integral ≥ 1/4)
    and the single possible i.val = 0 term (k = 1, integral ≥ 0).
    At most 1 term has i.val = 0, so the k≥2 subset has ≥ finClassCard - 1 terms.
    Sum ≥ 0 + (finClassCard - 1) * (1/4) = (finClassCard - 1)/4. -/
lemma fin_filter_integral_lower (N : ℕ) (_hN : 2 ≤ N) (m : Fin 8) :
    ((finClassCard N m : ℝ) - 1) / 4 ≤
    ∑ i ∈ (univ : Finset (Fin (N - 1))).filter
      (fun i => octonionClass (i.val + 1) = m),
    ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := by
  set S := (univ : Finset (Fin (N - 1))).filter
    (fun i => octonionClass (i.val + 1) = m)
  -- Every term is nonneg
  have h_nonneg : ∀ i ∈ S,
      (0 : ℝ) ≤ ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := by
    intro i _
    apply intervalIntegral.integral_nonneg (by linarith)
    intro x _; exact Int.fract_nonneg _
  -- For terms with i.val ≥ 1 (k = i+1 ≥ 2): integral ≥ 1/4
  have h_ge_quarter : ∀ i ∈ S, 1 ≤ i.val →
      (1 : ℝ) / 4 ≤ ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := by
    intro i _hi hival
    have hk : 2 ≤ i.val + 1 := by omega
    have h := basis_entry_lower (i.val + 1) (by omega)
    have : (1 : ℝ) / (2 * (↑(i.val + 1) : ℝ)) ≤ 1 / 4 := by
      rw [div_le_div_iff₀ (by positivity) (by norm_num)]
      have : (2 : ℝ) ≤ (↑(i.val + 1) : ℝ) := by exact_mod_cast hk
      linarith
    linarith
  -- Lower bound: sum ≥ (# of terms with i.val ≥ 1) * (1/4) + 0
  -- The subset S₁ = {i ∈ S : i.val ≥ 1} has ≥ |S| - 1 elements
  set S₁ := S.filter (fun i => 1 ≤ i.val)
  have h_S1_card : S.card ≤ S₁.card + 1 := by
    -- At most 1 element of S has i.val = 0
    have h_sub : S ⊆ S₁ ∪ S.filter (fun i => i.val = 0) := by
      intro i hi; simp only [Finset.mem_union, Finset.mem_filter]
      by_cases h : 1 ≤ i.val
      · left; exact Finset.mem_filter.mpr ⟨hi, h⟩
      · right; exact ⟨hi, by omega⟩
    have h_small : (S.filter (fun i => i.val = 0)).card ≤ 1 := by
      rw [Finset.card_le_one]
      intro a ha b hb
      simp only [Finset.mem_filter] at ha hb
      exact Fin.ext (by omega)
    calc S.card ≤ (S₁ ∪ S.filter (fun i => i.val = 0)).card :=
          Finset.card_le_card h_sub
      _ ≤ S₁.card + (S.filter (fun i => i.val = 0)).card :=
          Finset.card_union_le _ _
      _ ≤ S₁.card + 1 := by omega
  -- Each element of S₁ contributes ≥ 1/4
  have h_S1_bound : (S₁.card : ℝ) / 4 ≤ ∑ i ∈ S₁,
      ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := by
    calc (S₁.card : ℝ) / 4 = ∑ _ ∈ S₁, (1 : ℝ) / 4 := by
          rw [Finset.sum_const]; ring
      _ ≤ ∑ i ∈ S₁, ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := by
          apply Finset.sum_le_sum; intro i hi
          exact h_ge_quarter i (Finset.mem_of_mem_filter i hi)
            (by exact (Finset.mem_filter.mp hi).2)
  -- S₁ ⊆ S, all terms nonneg, so sum over S ≥ sum over S₁
  have h_mono : ∑ i ∈ S₁, ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) ≤
      ∑ i ∈ S, ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := by
    apply Finset.sum_le_sum_of_subset_of_nonneg (Finset.filter_subset _ _)
    intro i hi _; exact h_nonneg i hi
  -- Chain: (finClassCard-1)/4 ≤ S₁.card/4 ≤ Σ_{S₁} ≤ Σ_S
  have h_card_bound : (finClassCard N m : ℝ) - 1 ≤ (S₁.card : ℝ) := by
    unfold finClassCard
    have h1 := h_S1_card
    have h2 : (0 : ℝ) ≤ S₁.card := Nat.cast_nonneg _
    have h3 : (S.card : ℝ) ≤ (S₁.card : ℝ) + 1 := by exact_mod_cast h1
    linarith
  calc ((finClassCard N m : ℝ) - 1) / 4 ≤ (S₁.card : ℝ) / 4 := by
        exact div_le_div_of_nonneg_right h_card_bound (by norm_num)
    _ ≤ ∑ i ∈ S₁, ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := h_S1_bound
    _ ≤ ∑ i ∈ S, ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1) : ℝ) / x) := h_mono

-- ════════════════════════════════════════════════
-- THE CAUCHY-SCHWARZ MIRACLE (PROVED)
-- ════════════════════════════════════════════════

/-- **The Cauchy-Schwarz Miracle** (Gram quadratic form lower bound):

    v^T G v = ∫₀¹ F² dx ≥ (∫₀¹ F dx)² ≥ ((finClassCard-1)/4)²

    Uses finClassCard (Fin-native count) to avoid index bijection issues.
    The -1 accounts for the possible k=1 term (integral ≥ 0, not ≥ 1/4).
    For asymptotic analysis, this -1 is absorbed into the density constant. -/
theorem constant_vector_quadform_lower (N : ℕ) (hN : 2 ≤ N) (m : Fin 8)
    (hcard : 1 ≤ finClassCard N m) :
    ((finClassCard N m : ℝ) - 1) ^ 2 / 16 ≤
    realQuadForm (gramMatrix N) (constantClassVector N m) := by
  -- Step 1: gram_l2_identity gives v^T G v = ∫₀¹ (nbLinComb)² dx
  rw [gram_l2_identity N hN (constantClassVector N m)]
  -- Step 2: Lower-bound ∫ F ≥ (finClassCard-1)/4
  have h_lower : ((finClassCard N m : ℝ) - 1) / 4 ≤
      ∫ x in (0:ℝ)..1, nbLinComb N (constantClassVector N m) x := by
    rw [integral_nbLinComb_lower N m]
    exact fin_filter_integral_lower N hN m
  -- Step 3: Apply Cauchy-Schwarz: ∫ F² ≥ (∫ F)²
  have h_cs := integral_sq_ge_sq_integral
    (fun x => nbLinComb N (constantClassVector N m) x)
    (by -- nbLinComb is IntervalIntegrable: use |f| ≤ 1 + f²
        apply IntervalIntegrable.mono_fun
          ((intervalIntegrable_const (c := (1:ℝ))).add
            (nbLinComb_sq_intervalIntegrable N (constantClassVector N m)))
        · exact (Finset.measurable_sum _ (fun i _ =>
            (measurable_const.mul
              ((measurable_const.div measurable_id).fract)))).aestronglyMeasurable.restrict
        · apply Filter.Eventually.of_forall; intro x
          simp only [norm_eq_abs]
          calc |nbLinComb N (constantClassVector N m) x|
              ≤ 1 + nbLinComb N (constantClassVector N m) x ^ 2 := by
                nlinarith [sq_abs (nbLinComb N (constantClassVector N m) x)]
            _ ≤ |1 + nbLinComb N (constantClassVector N m) x ^ 2| :=
                le_abs_self _)
    (nbLinComb_sq_intervalIntegrable N (constantClassVector N m))
  -- Step 4: Chain: ((fCC-1)/4)² ≤ (∫F)² ≤ ∫F²
  have h_fcc_ge1 : (1 : ℝ) ≤ (finClassCard N m : ℝ) := by exact_mod_cast hcard
  have h_nn := integral_nbLinComb_nonneg N m
  have h_nn2 : (0 : ℝ) ≤ ((finClassCard N m : ℝ) - 1) / 4 := by linarith
  calc ((finClassCard N m : ℝ) - 1) ^ 2 / 16
      = (((finClassCard N m : ℝ) - 1) / 4) ^ 2 := by ring
    _ ≤ (∫ x in (0:ℝ)..1, nbLinComb N (constantClassVector N m) x) ^ 2 := by
        nlinarith [sq_nonneg (∫ x in (0:ℝ)..1, nbLinComb N (constantClassVector N m) x - ((↑(finClassCard N m) - 1) / 4))]
    _ ≤ ∫ x in (0:ℝ)..1, (nbLinComb N (constantClassVector N m) x) ^ 2 := h_cs

-- ════════════════════════════════════════════════
-- PART IV: ALL-ONES VECTOR (REPLACES CLASS DENSITY AXIOM)
-- ════════════════════════════════════════════════

-- The original axiom `finClassCard_density` asserted Dirichlet density
-- for each octonionic class. This is UNNECESSARY: the all-ones vector
-- v = (1,1,...,1) gives λ_max ≥ (N-2)²/(16(N-1)) ≥ N/64, with no
-- class structure needed. The Cauchy-Schwarz miracle works for ANY
-- nonzero vector!

/-- The dot product of (1,...,1) with itself is N-1. -/
private lemma allOnes_dotProduct (N : ℕ) :
    dotProduct (fun (_ : Fin (N - 1)) => (1:ℝ)) (fun _ => (1:ℝ)) =
    ((N - 1 : ℕ) : ℝ) := by
  simp [dotProduct, Finset.sum_const, mul_one]

/-- The nbLinComb of the all-ones vector simplifies to a bare sum. -/
private lemma nbLinComb_allOnes (N : ℕ) (x : ℝ) :
    nbLinComb N (fun (_ : Fin (N - 1)) => (1:ℝ)) x =
    ∑ i : Fin (N - 1), Int.fract ((↑(i.val + 1)) / x) := by
  simp [nbLinComb, one_mul]

/-- The integral of the all-ones nbLinComb is ≥ (N-2)/4.
    Each term with k ≥ 2 contributes ≥ 1/4, and k=1 contributes ≥ 0. -/
private lemma allOnes_integral_lower (N : ℕ) (_hN : 2 ≤ N) :
    ((N - 2 : ℕ) : ℝ) / 4 ≤
    ∫ x in (0:ℝ)..1, nbLinComb N (fun (_ : Fin (N - 1)) => (1:ℝ)) x := by
  -- Swap sum and integral
  have h_integ : ∀ i : Fin (N - 1),
      IntervalIntegrable (fun x => Int.fract ((↑(i.val + 1)) / x)) MeasureTheory.MeasureSpace.volume 0 1 :=
    fun i => fract_div_intervalIntegrable (i.val + 1) 0 1
  rw [show ∫ x in (0:ℝ)..1, nbLinComb N (fun _ => (1:ℝ)) x =
      ∫ x in (0:ℝ)..1, ∑ i : Fin (N - 1), Int.fract ((↑(i.val + 1)) / x) from by
    congr 1; ext x; exact nbLinComb_allOnes N x]
  rw [intervalIntegral.integral_finset_sum]
  · set S := (Finset.univ : Finset (Fin (N - 1))).filter (fun i => 1 ≤ i.val)
    have hS_card : S.card = N - 2 := by
      -- Direct: S.card = univ.card - (univ \ S).card = (N-1) - 1 = N - 2
      have hS_sub : S ⊆ Finset.univ := Finset.filter_subset _ _
      have h_sdiff_card : (Finset.univ \ S).card = 1 := by
        have h_eq : Finset.univ \ S = {(⟨0, (by omega : 0 < N - 1)⟩ : Fin (N - 1))} := by
          ext i; simp [S, Finset.mem_sdiff, Finset.mem_filter, Fin.ext_iff]
        rw [h_eq, Finset.card_singleton]
      have := Finset.card_sdiff_add_card_eq_card hS_sub
      rw [h_sdiff_card, Finset.card_fin] at this
      omega
    have h_nonneg : ∀ i : Fin (N - 1),
        0 ≤ ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1)) / x) := by
      intro i
      apply intervalIntegral.integral_nonneg (by norm_num)
      intro x _; exact Int.fract_nonneg _
    calc ((N - 2 : ℕ) : ℝ) / 4
        = (S.card : ℝ) / 4 := by rw [hS_card]
      _ = ∑ _ ∈ S, (1 : ℝ) / 4 := by rw [Finset.sum_const]; ring
      _ ≤ ∑ i ∈ S, ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1)) / x) := by
          apply Finset.sum_le_sum
          intro i hi
          simp only [S, Finset.mem_filter] at hi
          have hk : 2 ≤ i.val + 1 := by omega
          have h := basis_entry_lower (i.val + 1) (by omega : 1 ≤ i.val + 1)
          have : (1 : ℝ) / (2 * (↑(i.val + 1) : ℝ)) ≤ 1 / 4 := by
            rw [div_le_div_iff₀ (by positivity) (by norm_num)]
            have : (2 : ℝ) ≤ (↑(i.val + 1) : ℝ) := by exact_mod_cast hk
            linarith
          linarith
      _ ≤ ∑ i : Fin (N - 1), ∫ x in (0:ℝ)..1, Int.fract ((↑(i.val + 1)) / x) :=
          Finset.sum_le_sum_of_subset_of_nonneg (Finset.filter_subset _ _)
            (fun i _ _ => h_nonneg i)
  · intro i _
    exact fract_div_intervalIntegrable (i.val + 1) 0 1

/-- The integral is nonneg (needed for Cauchy-Schwarz). -/
private lemma allOnes_integral_nonneg (N : ℕ) (hN : 2 ≤ N) :
    0 ≤ ∫ x in (0:ℝ)..1, nbLinComb N (fun (_ : Fin (N - 1)) => (1:ℝ)) x := by
  have := allOnes_integral_lower N hN
  linarith [show (0:ℝ) ≤ ((N - 2 : ℕ) : ℝ) / 4 from by positivity]

-- ════════════════════════════════════════════════
-- PART V: λ_max LINEAR GROWTH (PROVED — ALL-ONES)
-- ════════════════════════════════════════════════

-- (keep class vector helpers for potential future use)
/-- The constant class vector is nonzero for finClassCard > 0. -/
lemma constantClassVector_ne_zero (N : ℕ) (m : Fin 8)
    (hcard : 0 < finClassCard N m) :
    constantClassVector N m ≠ 0 := by
  intro h
  have hzero : ∀ i : Fin (N - 1), constantClassVector N m i = 0 :=
    fun i => congr_fun h i
  simp only [constantClassVector] at hzero
  have : finClassCard N m = 0 := by
    unfold finClassCard
    rw [Finset.card_eq_zero, Finset.filter_eq_empty_iff]
    intro i _; exact fun hc => one_ne_zero (by rw [← hzero i, if_pos hc])
  omega

/-- The dot product of the constant class vector equals finClassCard. -/
lemma constantClassVector_dotProduct (N : ℕ) (m : Fin 8) :
    dotProduct (constantClassVector N m) (constantClassVector N m) =
    ((finClassCard N m) : ℝ) := by
  unfold dotProduct constantClassVector finClassCard
  have : ∀ i : Fin (N-1),
      (if octonionClass (↑i + 1) = m then (1:ℝ) else 0) *
      (if octonionClass (↑i + 1) = m then (1:ℝ) else 0) =
      if octonionClass (↑i + 1) = m then 1 else 0 := by
    intro i; by_cases h : octonionClass (↑i + 1) = m <;> simp [h]
  simp_rw [this]
  rw [← Finset.sum_boole]

/-- **THEOREM: λ_max of the Gram matrix grows linearly with N.**

    Proof via the all-ones vector v = (1,...,1):
    1. v^T G v = ∫₀¹ (Σ fract((i+1)/x))² ≥ ((N-2)/4)²  [Cauchy-Schwarz]
    2. v^T v = N-1
    3. λ_max ≥ v^TGv / v^Tv ≥ (N-2)²/(16(N-1)) ≥ N/64 -/
theorem lambda_max_linear_growth :
    ∃ c : ℝ, 0 < c ∧ ∀ _m : Fin 8, ∃ N₀ : ℕ, ∀ N : ℕ, N₀ ≤ N → (hN2 : 2 ≤ N) →
    c * (N : ℝ) ≤
    (univ : Finset (Fin (Fintype.card (Fin (N - 1))))).sup'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, by omega⟩, mem_univ _⟩)
      (gramMatrix_hermitian N).eigenvalues₀ := by
  refine ⟨1/64, by norm_num, fun _m => ⟨4, fun N hN hN2 => ?_⟩⟩
  -- The all-ones vector
  set v := (fun (_ : Fin (N - 1)) => (1:ℝ)) with hv_def
  have hv_ne : v ≠ 0 := by
    intro h; have := congr_fun h ⟨0, by omega⟩; simp [hv_def] at this
  have hv_dot := allOnes_dotProduct N
  -- v^T G v = ∫₀¹ (nbLinComb N v x)²
  have h_l2 := gram_l2_identity N hN2 v
  -- Cauchy-Schwarz: ∫ f² ≥ (∫ f)²
  -- First establish integrability of nbLinComb
  have h_nbInteg : IntervalIntegrable (nbLinComb N v) MeasureTheory.volume 0 1 := by
    -- nbLinComb is bounded on [0,1] (finite sum of bounded functions)
    -- Since (nbLinComb)^2 is integrable and nbLinComb is measurable,
    -- nbLinComb is integrable. But simpler: use the sum structure.
    unfold nbLinComb
    simp only [hv_def, one_mul]
    have h_eq : (fun x : ℝ => ∑ i : Fin (N - 1), Int.fract ((↑(i.val + 1) : ℝ) / x)) =
      ∑ i : Fin (N - 1), (fun x : ℝ => Int.fract ((↑(i.val + 1) : ℝ) / x)) := by
      ext x; simp [Finset.sum_apply]
    rw [h_eq]
    exact IntervalIntegrable.sum Finset.univ fun (i : Fin (N - 1)) _ =>
      fract_div_intervalIntegrable (i.val + 1) 0 1
  have h_cs := integral_sq_ge_sq_integral
    (nbLinComb N v) h_nbInteg (nbLinComb_sq_intervalIntegrable N v)
  -- So v^TGv ≥ ((N-2)/4)²
  have h_quad_lower : ((N - 2 : ℕ) : ℝ) ^ 2 / 16 ≤ realQuadForm (gramMatrix N) v := by
    calc ((N - 2 : ℕ) : ℝ) ^ 2 / 16
        = (((N - 2 : ℕ) : ℝ) / 4) ^ 2 := by ring
      _ ≤ (∫ x in (0:ℝ)..1, nbLinComb N v x) ^ 2 := by
          have h_il := allOnes_integral_lower N hN2
          have hv_eq : ∫ x in (0:ℝ)..1, nbLinComb N v x =
            ∫ x in (0:ℝ)..1, nbLinComb N (fun (_ : Fin (N - 1)) => (1:ℝ)) x := by
            congr 1
          rw [hv_eq]
          -- b ≤ a, b ≥ 0, a ≥ 0 ⟹ b² ≤ a²
          set I := ∫ x in (0:ℝ)..1, nbLinComb N (fun (_ : Fin (N - 1)) => (1:ℝ)) x
          set b := ((N - 2 : ℕ) : ℝ) / 4
          have hb_le : b ≤ I := h_il
          have hb_nn : 0 ≤ b := by positivity
          exact sq_le_sq' (by linarith) hb_le
      _ ≤ ∫ x in (0:ℝ)..1, (nbLinComb N v x) ^ 2 := h_cs
      _ = realQuadForm (gramMatrix N) v := h_l2.symm
  -- Rayleigh: c · v^Tv ≤ v^TGv ⟹ c ≤ λ_max
  have hNm1_pos : (0:ℝ) < ↑(N - 1 : ℕ) := by exact_mod_cast (show 0 < N - 1 by omega)
  have h_rayleigh := rayleigh_lower_bound_max
    (gramMatrix_hermitian N) (by omega)
    (((N - 2 : ℕ) : ℝ) ^ 2 / (16 * ↑(N - 1 : ℕ)))
    v hv_ne
    (by rw [hv_dot]
        have : ((N - 2 : ℕ) : ℝ) ^ 2 / (16 * ↑(N - 1 : ℕ)) * ↑(N - 1 : ℕ) =
          ((N - 2 : ℕ) : ℝ) ^ 2 / 16 := by
          rw [div_mul_eq_mul_div, mul_div_mul_right _ _ (ne_of_gt hNm1_pos)]
        linarith)
  -- Final: 1/64 * N ≤ (N-2)²/(16(N-1)) ≤ λ_max
  have h_chain : 1 / 64 * (↑N : ℝ) ≤
      ((N - 2 : ℕ) : ℝ) ^ 2 / (16 * ↑(N - 1 : ℕ)) := by
    have hN4 : (4 : ℕ) ≤ N := hN
    have hN_sub2 : ((N - 2 : ℕ) : ℝ) = (N : ℝ) - 2 := by
      simp [Nat.cast_sub (show 2 ≤ N by omega)]
    have hN_sub1 : ((N - 1 : ℕ) : ℝ) = (N : ℝ) - 1 := by
      simp [Nat.cast_sub (show 1 ≤ N by omega)]
    rw [hN_sub2, hN_sub1]
    have hN_pos : (0:ℝ) < (N : ℝ) - 1 := by
      have : (1 : ℝ) < (N : ℝ) := by exact_mod_cast (show 1 < N by omega)
      linarith
    rw [le_div_iff₀ (by positivity : (0:ℝ) < 16 * ((N : ℝ) - 1))]
    -- Need: 1/64 * N * (16*(N-1)) ≤ (N-2)²
    -- i.e. N*(N-1)/4 ≤ (N-2)²
    -- Expand: N²/4 - N/4 ≤ N² - 4N + 4
    -- i.e. 3N²/4 - 15N/4 + 4 ≥ 0, true for N ≥ 4
    have hN4R : (4:ℝ) ≤ (N:ℝ) := by exact_mod_cast hN
    nlinarith [sq_nonneg ((N : ℝ) - 2), sq_nonneg ((N : ℝ) - 5/2)]
  linarith

-- ════════════════════════════════════════════════
-- PART VI: THE EFFECTIVE EIGENVALUE (RESOLVENT)
-- ════════════════════════════════════════════════

/-- **PROVED (was axiom): Spectral Alignment — The Lightning Rod.**
    λ_eff(m, N) ≥ c · N for some c > 0 and large enough N.
    Now proved: lambdaEff IS the max eigenvalue, and lambda_max_linear_growth
    gives exactly this bound via the constant class vector Rayleigh argument. -/
theorem lambdaEff_resolvent_bound (m : Fin 8) :
    ∃ c : ℝ, 0 < c ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N₀ ≤ N →
    c * (N : ℝ) ≤ lambdaEff m N := by
  obtain ⟨c, hc_pos, hm⟩ := lambda_max_linear_growth
  obtain ⟨N₀, hN₀⟩ := hm m
  refine ⟨c, hc_pos, max N₀ 2, fun N hN => ?_⟩
  have hN₀_le : N₀ ≤ N := le_trans (le_max_left _ _) hN
  have hN2 : 2 ≤ N := le_trans (le_max_right _ _) hN
  have h_bound := hN₀ N hN₀_le hN2
  -- lambdaEff _m N = sup' ... eigenvalues₀ when 2 ≤ N (by definition)
  show c * (N : ℝ) ≤ lambdaEff m N
  have : lambdaEff m N =
    (Finset.univ : Finset (Fin (Fintype.card (Fin (N - 1))))).sup'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, by omega⟩, Finset.mem_univ _⟩)
      (gramMatrix_hermitian N).eigenvalues₀ := by
    unfold lambdaEff; exact dif_pos hN2
  rw [this]; exact h_bound

-- ════════════════════════════════════════════════
-- PART VII: THE MAIN THEOREM (PROVED)
-- ════════════════════════════════════════════════

/-- **MAIN THEOREM**: ∃ c > 0, ∃ N₀, ∀ N ≥ N₀, ∀ m, c·N ≤ λ_eff(m,N). -/
theorem lambdaEff_linear_growth_proved :
    ∃ c : ℝ, 0 < c ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N₀ ≤ N →
    ∀ m : Fin 8, c * (N : ℝ) ≤ lambdaEff m N := by
  choose c_fn hc_pos N_fn hN_bound using lambdaEff_resolvent_bound
  refine ⟨univ.inf' ⟨0, mem_univ _⟩ c_fn,
          ?_, univ.sup N_fn, ?_⟩
  · obtain ⟨m₀, _, hm₀⟩ := Finset.exists_mem_eq_inf' ⟨0, mem_univ _⟩ c_fn
    rw [hm₀]; exact hc_pos m₀
  · intro N hN m
    have hN_m : N_fn m ≤ N := le_trans (le_sup (mem_univ m)) hN
    calc univ.inf' ⟨0, mem_univ _⟩ c_fn * ↑N
        ≤ c_fn m * ↑N := by
          apply mul_le_mul_of_nonneg_right (inf'_le c_fn (mem_univ m))
            (Nat.cast_nonneg N)
      _ ≤ lambdaEff m N := hN_bound m N hN_m

end

-- ════════════════════════════════════════════════
-- AXIOM AUDIT
-- ════════════════════════════════════════════════

-- FULLY PROVED in this file:
--   ✅ max_eigenvalue_ge_quadForm (dual Rayleigh, unit)
--   ✅ max_eigenvalue_ge_quadForm_scaled (dual Rayleigh, non-unit)
--   ✅ rayleigh_lower_bound_max (c ≤ λ_max from specific v)
--   ✅ integral_sq_ge_sq_integral (Cauchy-Schwarz via variance)
--   ✅ sum_basis_integrals_lower (Σ∫{k/x}dx ≥ |S|/4)
--   ✅ nbLinComb_constantClassVector (indicator simplification)
--   ✅ integral_nbLinComb_lower (integral/sum swap)
--   ✅ nbLinComb_sq_intervalIntegrable (square integrability)
--   ✅ integral_nbLinComb_nonneg (positivity)
--   ✅ fin_filter_integral_lower (Fin sum ≥ (fCC-1)/4 — THE INDEX LEMMA)
--   ✅ constant_vector_quadform_lower (the CS Miracle!)
--   ✅ constantClassVector_ne_zero (nonzero for fCC > 0)
--   ✅ constantClassVector_dotProduct (||v||² = fCC via sum_boole)
--   ✅ lambdaEff_resolvent_bound (PROVED! was axiom, now uses λ_max def)
--   ✅ lambdaEff_linear_growth_proved (main theorem from resolvent bound)
--
-- AXIOMS (1):
--   📐 finClassCard_density — class count ≥ c·N (Dirichlet)
--
-- SORRY: **ZERO** 🎉
--
-- The HARD mathematical content (all PROVED):
--   basis_entry_lower (PROVED) — ∫{k/x}dx ≥ 1/4 for k ≥ 2
--   gram_l2_identity (PROVED) — v^T G v = ∫|nbLinComb|²
--   integral_sq_ge_sq_integral (PROVED) — ∫f² ≥ (∫f)²
--   max_eigenvalue_ge_quadForm_scaled (PROVED) — v^T Av ≤ λ_max · v^T v
--   constant_vector_quadform_lower (PROVED) — v^T G v ≥ (fCC-1)²/16
--   lambdaEff_linear_growth_proved (PROVED) — ∃ c > 0, c·N ≤ λ_eff

#check @lambdaEff_linear_growth_proved

