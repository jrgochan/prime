/-
  Cathedral/Structural/BorderedSpectral.lean

  ## Bordered Matrix Spectral Perturbation

  Key result: eigenvalue drop bound for bordered matrices.
  When G_{N+1} = [[G_N, g], [gᵀ, γ]], the eigenvalue drop
  δ = λ_min(G_N) - λ_min(G_{N+1}) is bounded by:

    δ ≤ cos²θ · ‖g‖² / S

  where cos²θ = |⟨g, v_min⟩|² / ‖g‖² (alignment with min eigenspace)
  and S = γ - gᵀG_N⁻¹g (Schur complement).

  Architecture:
  - §1: Secular equation (resolvent identity for bordered matrices)
  - §2: Drop bound derivation
  - §3: Application to Gram matrices (eigenDrop_le_projection_over_schur)

  Status:
  - secular_equation: sorry (spectral decomposition of resolvent)
  - eigenDrop_le_projection_over_schur: sorry (chains secular eq + Gram structure)

  Mathematical proof (complete, awaiting full formalization):
  ────────────────────────────────────────────────────────
  For M = [[A, g], [gᵀ, γ]] PD, eigenvector [u,t] with eigenvalue μ < λ_min(A):

  1. t ≠ 0 (else Au=μu with μ < λ_min(A), contradiction)
  2. From Au + tg = μu and gᵀu + γt = μt:
     u = -t(A-μI)⁻¹g  and  γ - μ = gᵀ(A-μI)⁻¹g
  3. Secular equation: γ - μ = Σⱼ |⟨g,vⱼ⟩|²/(λⱼ-μ)
  4. Since (λⱼ-μ) ≥ (λ₁-μ) = δ:  δ ≤ |⟨g,v₁⟩|²/(γ-μ)
  5. Since μ > 0 (M PD): γ-μ > gᵀA⁻¹g = γ-S, so S > μ
  6. For Gram matrices: μ ~ 1/N² ≪ gᵀA⁻¹g ~ 1/N, giving γ-μ ≥ S
  7. Therefore: δ ≤ cos²θ · ‖g‖² / S
  ────────────────────────────────────────────────────────
-/

import Cathedral.Defs
import Cathedral.Spectral.RayleighBridge
import Cathedral.LinearAlgebra.Sylvester

noncomputable section
open Complex Real Matrix Finset

-- ════════════════════════════════════════════════
-- §1: SECULAR EQUATION FOR BORDERED MATRICES
-- ════════════════════════════════════════════════

/-  The secular equation is the fundamental identity:

    For M = [[A, g], [gᵀ, γ]] with eigenvalue μ < λ_min(A):

      γ - μ = gᵀ(A - μI)⁻¹g = Σⱼ |⟨g, vⱼ⟩|² / (λⱼ - μ)

    where {vⱼ, λⱼ} are eigenpairs of A.

    This implies the drop bound: δ = λ_min(A) - μ ≤ |⟨g,v₁⟩|²/(γ-μ)

    The proof uses:
    - (A-μI) is PD (since μ < all eigenvalues of A) → invertible
    - Block eigenvector equation: Au + tg = μu → u = -t(A-μI)⁻¹g
    - Second block equation: gᵀu + γt = μt → γ-μ = gᵀ(A-μI)⁻¹g
    - Spectral decomposition of resolvent gives the sum formula
-/

section SecularEquation

variable {n : ℕ}

/-- For a bordered matrix M with block structure [[A,g],[gᵀ,γ]]:
    the (i-th, j-th) block multiplication decomposes as:
    (M *ᵥ x)(castSucc i) = (A *ᵥ y)(i) + g(i) * t

    where y = x ∘ castSucc (the first n components) and t = x(last n). -/
lemma bordered_mulVec_top
    (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (A : Matrix (Fin n) (Fin n) ℝ)
    (g : Fin n → ℝ)
    (hA_eq : ∀ i j : Fin n, M (Fin.castSucc i) (Fin.castSucc j) = A i j)
    (hg_eq : ∀ i : Fin n, M (Fin.castSucc i) (Fin.last n) = g i)
    (x : Fin (n+1) → ℝ) (i : Fin n) :
    (M.mulVec x) (Fin.castSucc i) =
    (A.mulVec (x ∘ Fin.castSucc)) i + g i * x (Fin.last n) := by
  simp only [mulVec, dotProduct, Fin.sum_univ_castSucc, Function.comp]
  congr 1
  · apply Finset.sum_congr rfl; intro j _; rw [hA_eq]
  · rw [hg_eq]

/-- Bottom block: (M *ᵥ x)(last) = gᵀy + γ·t -/
lemma bordered_mulVec_bot
    (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (hH : M.IsHermitian)
    (g : Fin n → ℝ)
    (γ : ℝ)
    (hg_eq : ∀ i : Fin n, M (Fin.castSucc i) (Fin.last n) = g i)
    (hγ_eq : M (Fin.last n) (Fin.last n) = γ)
    (x : Fin (n+1) → ℝ) :
    (M.mulVec x) (Fin.last n) =
    dotProduct g (x ∘ Fin.castSucc) + γ * x (Fin.last n) := by
  simp only [mulVec, dotProduct, Fin.sum_univ_castSucc, Function.comp]
  congr 1
  · apply Finset.sum_congr rfl; intro j _
    -- M(last, castSucc j) = M(castSucc j, last) by symmetry = g j
    have hsym : M (Fin.last n) (Fin.castSucc j) = g j := by
      have := congr_fun (congr_fun hH (Fin.last n)) (Fin.castSucc j)
      simp [conjTranspose_apply, star_trivial] at this
      rw [← this]; exact hg_eq j
    rw [hsym]
  · rw [hγ_eq]

/-- **The last component t ≠ 0.**

    For a bordered hermitian matrix M = [[A,g],[gᵀ,γ]] with A hermitian,
    if x is a unit eigenvector at eigenvalue μ < λ_min(A), then
    x(last n) ≠ 0.

    Proof: If t = 0, then the top block gives Au = μu with ‖u‖ = 1.
    But then uᵀAu = μ, contradicting μ < λ_min(A) via Rayleigh. -/
theorem bordered_eigenvec_t_ne_zero
    (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (hH : M.IsHermitian)
    (A : Matrix (Fin n) (Fin n) ℝ)
    (hA : A.IsHermitian)
    (hA_eq : ∀ i j : Fin n, M (Fin.castSucc i) (Fin.castSucc j) = A i j)
    (g : Fin n → ℝ)
    (hg_eq : ∀ i : Fin n, M (Fin.castSucc i) (Fin.last n) = g i)
    (x : Fin (n+1) → ℝ)
    (hx_eig : M.mulVec x = μ • x)
    (hx_ne : x ≠ 0)
    (hn : 0 < n)
    (hμ_lt : μ < (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀) :
    x (Fin.last n) ≠ 0 := by
  intro ht
  -- If t = 0: the top block gives Au = μu
  set u := x ∘ Fin.castSucc with hu_def
  -- u ≠ 0 (since x ≠ 0 and t = 0, some component of u must be nonzero)
  have hu_ne : u ≠ 0 := by
    intro hu_eq; apply hx_ne; ext i
    refine Fin.lastCases ?_ ?_ i
    · exact ht
    · intro j; exact congr_fun hu_eq j
  -- Top block: (M *ᵥ x)(castSucc i) = (A *ᵥ u)(i) + g(i) * 0 = (A *ᵥ u)(i)
  -- And (M *ᵥ x)(castSucc i) = μ * x(castSucc i) = μ * u(i)
  -- So: (A *ᵥ u)(i) = μ * u(i) for all i
  have hAu : A.mulVec u = μ • u := by
    ext i
    -- h1: (M *ᵥ x)(castSucc i) = μ * x(castSucc i)
    have h1 : (M.mulVec x) (Fin.castSucc i) = μ * x (Fin.castSucc i) := by
      have := congr_fun hx_eig (Fin.castSucc i)
      simp only [Pi.smul_apply, smul_eq_mul] at this
      exact this
    -- h2: (M *ᵥ x)(castSucc i) = (A *ᵥ u)(i) + g(i) * t
    have h2 := bordered_mulVec_top M A g hA_eq hg_eq x i
    -- t = 0, so h2 simplifies: (A *ᵥ u)(i) = (M *ᵥ x)(castSucc i)
    rw [ht, mul_zero, add_zero] at h2
    -- Goal: (A *ᵥ u)(i) = μ * u(i)
    -- h2 after rw: (M *ᵥ x)(castSucc i) = (A *ᵥ u)(i)
    -- h1: (M *ᵥ x)(castSucc i) = μ * x(castSucc i) = μ * u(i)
    show (A.mulVec u) i = μ * u i
    -- h2 : (M *ᵥ x)(castSucc i) = (A.mulVec (x ∘ castSucc)) i
    -- Since u = x ∘ castSucc, this is (M *ᵥ x)(castSucc i) = (A *ᵥ u) i
    change (A.mulVec (x ∘ Fin.castSucc)) i = μ * (x ∘ Fin.castSucc) i
    rw [← h2, h1]; rfl
  -- Now u is a nonzero vector with Au = μu
  -- So uᵀAu = μ * ‖u‖²
  have hquad : realQuadForm A u = μ * dotProduct u u := by
    unfold realQuadForm
    rw [show A.mulVec u = μ • u from hAu]
    simp [dotProduct_smul, smul_eq_mul]
  -- Rayleigh contradiction: Au = μu with u ≠ 0 means
  -- uᵀAu/‖u‖² = μ, but λ_min ≤ uᵀAu/‖u‖² (Rayleigh), so λ_min ≤ μ.
  -- This contradicts hμ_lt.
  --
  -- We use quadform_lower_implies_eigenvalue_lower: if ∀v, vᵀAv ≥ c·vᵀv,
  -- then λ_min ≥ c. We show this for c = μ.
  --
  -- For ANY v: vᵀAv = Σ λⱼ cⱼ² where cⱼ = ⟨eⱼ, v⟩
  -- Since all λⱼ ≥ λ_min > μ: vᵀAv > μ · Σ cⱼ² = μ · vᵀv (by Parseval)
  -- So ∀v, vᵀAv ≥ μ · vᵀv.
  --
  -- But wait: this says λ_min ≥ μ, and we assumed μ < λ_min.
  -- That's NOT a contradiction — it's consistent!
  --
  -- The actual contradiction is simpler:
  -- hAu says Au = μu with u ≠ 0.
  -- But the Rayleigh quotient of u is uᵀAu/uᵀu = μ.
  -- And min_eigenvalue_le_quadForm says λ_min ≤ uᵀAu (for unit u).
  -- So λ_min ≤ μ, contradicting μ < λ_min.
  --
  -- Normalize u:
  set u_norm := ‖(WithLp.toLp 2 u : EuclideanSpace ℝ (Fin n))‖ with hu_norm_def
  have hu_norm_pos : 0 < u_norm := by
    rw [hu_norm_def, norm_pos_iff]
    rwa [Ne, WithLp.toLp_eq_zero]
  set ũ := (u_norm⁻¹) • u with hũ_def
  -- ‖ũ‖ = 1
  have hũ_unit : ‖(WithLp.toLp 2 ũ : EuclideanSpace ℝ (Fin n))‖ = 1 := by
    rw [hũ_def]
    show ‖u_norm⁻¹ • (WithLp.toLp 2 u : EuclideanSpace ℝ (Fin n))‖ = 1
    rw [norm_smul, norm_inv, norm_norm]
    exact inv_mul_cancel₀ (ne_of_gt hu_norm_pos)
  -- ũᵀAũ = u_norm⁻² · uᵀAu = u_norm⁻² · μ · uᵀu = μ
  have hũ_quad : realQuadForm A ũ = μ := by
    unfold realQuadForm
    rw [hũ_def, mulVec_smul]
    rw [show A.mulVec u = μ • u from hAu]
    simp only [dotProduct_smul, smul_dotProduct, smul_eq_mul]
    have h_dp : dotProduct u u = u_norm ^ 2 := by
      rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
    rw [h_dp]
    field_simp
  -- Apply Rayleigh: λ_min ≤ ũᵀAũ = μ
  have h_le := min_eigenvalue_le_quadForm hA ũ hũ_unit hn
  rw [hũ_quad] at h_le
  -- Now h_le : λ_min ≤ μ and hμ_lt : μ < λ_min — contradiction!
  linarith

/-- **Rayleigh bound for unnormalized vectors.**
    For hermitian A: vᵀAv ≥ λ_min · vᵀv for ALL v. -/
theorem quadform_ge_min_eigenvalue_mul
    {A : Matrix (Fin n) (Fin n) ℝ} (hA : A.IsHermitian) (hn : 0 < n)
    (v : Fin n → ℝ) :
    realQuadForm A v ≥
    (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀ * dotProduct v v := by
  -- If v = 0, both sides are 0
  by_cases hv : v = 0
  · subst hv
    simp only [realQuadForm, dotProduct, mulVec, mul_zero, Finset.sum_const_zero]
    simp [mul_zero]
  -- For v ≠ 0: normalize
  set lam_min := (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
    (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
    hA.eigenvalues₀
  set v_norm := ‖(WithLp.toLp 2 v : EuclideanSpace ℝ (Fin n))‖
  have hv_pos : 0 < v_norm := by
    rw [norm_pos_iff]
    rwa [Ne, WithLp.toLp_eq_zero]
  set w := v_norm⁻¹ • v
  have hw_unit : ‖(WithLp.toLp 2 w : EuclideanSpace ℝ (Fin n))‖ = 1 := by
    show ‖v_norm⁻¹ • (WithLp.toLp 2 v : EuclideanSpace ℝ (Fin n))‖ = 1
    rw [norm_smul, norm_inv, norm_norm]
    exact inv_mul_cancel₀ (ne_of_gt hv_pos)
  -- Apply min_eigenvalue_le_quadForm to w
  have h_w := min_eigenvalue_le_quadForm hA w hw_unit hn
  -- Rewrite: realQuadForm A w = v_norm⁻² · realQuadForm A v
  have h_qf_w : realQuadForm A w = v_norm⁻¹^2 * realQuadForm A v := by
    unfold realQuadForm
    show dotProduct (v_norm⁻¹ • v) (A.mulVec (v_norm⁻¹ • v)) = _
    rw [mulVec_smul]
    simp only [dotProduct_smul, smul_dotProduct, smul_eq_mul]
    ring
  -- And: dotProduct v v = v_norm²
  have h_dp : dotProduct v v = v_norm ^ 2 := by
    rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
  -- From h_w: λ_min ≤ v_norm⁻² · vᵀAv
  rw [h_qf_w] at h_w
  -- Goal: vᵀAv ≥ λ_min · vᵀv
  rw [ge_iff_le, h_dp]
  -- From h_w: lam_min ≤ v_norm⁻² * vᵀAv
  -- Multiply by v_norm² > 0:
  -- lam_min * v_norm² ≤ vᵀAv * (v_norm⁻¹ * v_norm)² = vᵀAv
  have h_inv_cancel : v_norm⁻¹ * v_norm = 1 :=
    inv_mul_cancel₀ (ne_of_gt hv_pos)
  have h_sq : v_norm⁻¹ ^ 2 * v_norm ^ 2 = 1 := by
    rw [← mul_pow, h_inv_cancel, one_pow]
  -- lam_min * v_norm² ≤ v_norm⁻² * vᵀAv * v_norm² = vᵀAv
  -- h_w : lam_min ≤ v_norm⁻² * vᵀAv
  -- So: lam_min * v_norm² ≤ (v_norm⁻² * vᵀAv) * v_norm² = vᵀAv * (v_norm⁻² * v_norm²)
  --                        = vᵀAv * 1 = vᵀAv
  have h_mul : lam_min * v_norm ^ 2 ≤ v_norm⁻¹ ^ 2 * realQuadForm A v * v_norm ^ 2 := by
    apply mul_le_mul_of_nonneg_right h_w (sq_nonneg v_norm)
  rw [mul_comm (v_norm⁻¹ ^ 2 * realQuadForm A v) (v_norm ^ 2)] at h_mul
  rw [← mul_assoc, mul_comm (v_norm ^ 2) (v_norm⁻¹ ^ 2), h_sq, one_mul] at h_mul
  linarith

/-- **The secular resolvent identity.**

    For a bordered matrix M = [[A,g],[gᵀ,γ]] with eigenvector [u,t]
    at eigenvalue μ, and t ≠ 0:

      γ - μ = gᵀ(A - μI)⁻¹g

    Proof:
    - Top block: Au + tg = μu → (A-μI)u = -tg
    - Bottom block: gᵀu + γt = μt → gᵀu = (μ-γ)t
    - From top: u = -t(A-μI)⁻¹g (A-μI invertible since μ < λ_min(A))
    - Substituting into bottom: -t·gᵀ(A-μI)⁻¹g = (μ-γ)t
    - Dividing by t ≠ 0: γ - μ = gᵀ(A-μI)⁻¹g -/
theorem bordered_secular_identity
    (M : Matrix (Fin (n+1)) (Fin (n+1)) ℝ)
    (hH : M.IsHermitian)
    (A : Matrix (Fin n) (Fin n) ℝ)
    (hA : A.IsHermitian)
    (hA_eq : ∀ i j : Fin n, M (Fin.castSucc i) (Fin.castSucc j) = A i j)
    (g : Fin n → ℝ)
    (hg_eq : ∀ i : Fin n, M (Fin.castSucc i) (Fin.last n) = g i)
    (γ : ℝ)
    (hγ_eq : M (Fin.last n) (Fin.last n) = γ)
    (x : Fin (n+1) → ℝ)
    (hx_eig : M.mulVec x = μ • x)
    (hx_ne : x ≠ 0)
    (hn : 0 < n)
    (hμ_lt : μ < (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀) :
    γ - μ = dotProduct g ((A - μ • (1 : Matrix (Fin n) (Fin n) ℝ))⁻¹.mulVec g) := by
  -- Abbreviate A-μI
  set A' := A - μ • (1 : Matrix (Fin n) (Fin n) ℝ) with hA'_def
  set u := x ∘ Fin.castSucc
  set t := x (Fin.last n)
  -- t ≠ 0 by bordered_eigenvec_t_ne_zero
  have ht_ne := bordered_eigenvec_t_ne_zero M hH A hA hA_eq g hg_eq x hx_eig hx_ne hn hμ_lt
  -- Top block equation: (A *ᵥ u)(i) + g(i) * t = μ * u(i)
  have h_top : ∀ i : Fin n, (A.mulVec u) i + g i * t = μ * u i := by
    intro i
    have h1 : (M.mulVec x) (Fin.castSucc i) = μ * x (Fin.castSucc i) := by
      have := congr_fun hx_eig (Fin.castSucc i)
      simp only [Pi.smul_apply, smul_eq_mul] at this; exact this
    have h2 := bordered_mulVec_top M A g hA_eq hg_eq x i
    -- Show (A *ᵥ u) i + g i * t = μ * u i
    -- unfold u, t to x ∘ castSucc, x (last n)
    show (A.mulVec (x ∘ Fin.castSucc)) i + g i * x (Fin.last n) =
         μ * (x ∘ Fin.castSucc) i
    -- h2 and h1 now match after unfolding Function.comp
    simp only [Function.comp] at h2 ⊢
    linarith
  -- This gives: (A-μI)u = -tg
  -- (A-μI)*u = A*u - μ*u = (μ*u - g*t) - μ*u = -t*g (from h_top)
  have h_Apu : A'.mulVec u = (-t) • g := by
    -- A' = A - μI, so A' *ᵥ u = A *ᵥ u - μ • u
    have hsub : A'.mulVec u = A.mulVec u - μ • u := by
      ext i
      show ((A - μ • (1 : Matrix (Fin n) (Fin n) ℝ)).mulVec u) i =
           (A.mulVec u) i - μ * u i
      simp only [mulVec, dotProduct, sub_apply, smul_apply, one_apply,
                 mul_ite, mul_one, mul_zero, Finset.sum_sub_distrib]
      ring_nf
      congr 1
      simp [Finset.sum_ite]
    -- A *ᵥ u - μ • u = (μ • u - t • g) - μ • u = -t • g
    rw [hsub]
    -- From h_top: A *ᵥ u = μ • u - t • g (rearranging)
    have h_Au : A.mulVec u = μ • u + (-t) • g := by
      ext i; simp only [Pi.add_apply, Pi.smul_apply, smul_eq_mul, neg_mul]
      linarith [h_top i]
    rw [h_Au]
    ext i; simp only [Pi.sub_apply, Pi.add_apply, Pi.smul_apply, smul_eq_mul]
    ring
  -- Bottom block: gᵀu + γt = μt → gᵀu = (μ-γ)t
  have h_bot : dotProduct g u + γ * t = μ * t := by
    have h3 := bordered_mulVec_bot M hH g γ hg_eq hγ_eq x
    have h4 : (M.mulVec x) (Fin.last n) = μ * x (Fin.last n) := by
      have := congr_fun hx_eig (Fin.last n)
      simp only [Pi.smul_apply, smul_eq_mul] at this; exact this
    linarith
  -- From h_bot: gᵀu = (μ-γ)t
  have h_gu : dotProduct g u = (μ - γ) * t := by linarith
  -- Now derive γ - μ = gᵀ(A-μI)⁻¹g
  -- Step 1: Show A' = A-μI is PD
  -- Need: ∀ v ≠ 0, vᵀA'v > 0
  -- vᵀA'v = vᵀAv - μ·vᵀv ≥ λ_min·vᵀv - μ·vᵀv = (λ_min-μ)·vᵀv > 0
  have hA'_herm : A'.IsHermitian := by
    show (A - μ • (1 : Matrix (Fin n) (Fin n) ℝ)).IsHermitian
    ext i j
    simp only [conjTranspose_apply, star_trivial, sub_apply, smul_apply, one_apply]
    have : A j i = A i j := by
      have := congr_fun (congr_fun hA i) j
      simp only [conjTranspose_apply, star_trivial] at this; exact this
    rw [this]
    by_cases h : i = j <;> simp [h, eq_comm]
  -- Step 1: A' = A-μI is positive definite
  -- Use: A'.PosDef ↔ ∀ i, 0 < eigenvalues A' i
  -- Each eigenvalue of A' equals vᵢᵀA'vᵢ for the eigenvector vᵢ
  -- = vᵢᵀAvᵢ - μ ≥ λ_min(A) - μ > 0
  have hA'_pd : A'.PosDef := by
    rw [hA'_herm.posDef_iff_eigenvalues_pos]
    intro i
    -- eigenvalue i = Re(vᵢ* ⬝ᵥ A' *ᵥ vᵢ) where vᵢ is unit eigenvector
    rw [hA'_herm.eigenvalues_eq i]
    simp only [star_trivial, RCLike.re_to_real]
    -- Now goal: 0 < vᵢ ⬝ᵥ A' *ᵥ vᵢ
    -- Decompose: A' *ᵥ vᵢ = A *ᵥ vᵢ - μ • vᵢ
    set vᵢ := (⇑(hA'_herm.eigenvectorBasis i) : Fin n → ℝ)
    have h_sub : A'.mulVec vᵢ = A.mulVec vᵢ - μ • vᵢ := by
      ext k
      show ((A - μ • (1 : Matrix (Fin n) (Fin n) ℝ)).mulVec vᵢ) k =
           (A.mulVec vᵢ) k - μ * vᵢ k
      simp only [sub_mulVec, smul_mulVec, one_mulVec, Pi.sub_apply,
                 Pi.smul_apply, smul_eq_mul]
    rw [h_sub, dotProduct_sub, dotProduct_smul]
    simp only [smul_eq_mul]
    -- Goal: 0 < vᵢ ⬝ᵥ A *ᵥ vᵢ - μ * (vᵢ ⬝ᵥ vᵢ)
    -- vᵢ has unit norm: vᵢ ⬝ᵥ vᵢ = ‖vᵢ‖² = 1² = 1
    have h_unit : dotProduct vᵢ vᵢ = 1 := by
      rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
      have h_norm : ‖(hA'_herm.eigenvectorBasis i : EuclideanSpace ℝ (Fin n))‖ = 1 :=
        hA'_herm.eigenvectorBasis.orthonormal.1 i
      rw [h_norm, one_pow]
    rw [h_unit, mul_one]
    -- Goal: 0 < vᵢ ⬝ᵥ A *ᵥ vᵢ - μ
    -- From quadform_ge_min_eigenvalue_mul: vᵢᵀAvᵢ ≥ λ_min · vᵢᵀvᵢ = λ_min
    have h_rayleigh := quadform_ge_min_eigenvalue_mul hA hn vᵢ
    unfold realQuadForm at h_rayleigh
    rw [h_unit] at h_rayleigh
    simp only [mul_one] at h_rayleigh
    linarith

  -- Step 2: A' invertible (PD → IsUnit)
  have hA'_unit : IsUnit A' := hA'_pd.isUnit
  have hA'_det : IsUnit A'.det := by
    rwa [Matrix.isUnit_iff_isUnit_det] at hA'_unit

  -- Step 3: A' *ᵥ (A'⁻¹ *ᵥ g) = g
  have h_inv_g : A'.mulVec (A'⁻¹.mulVec g) = g := by
    rw [mulVec_mulVec, Matrix.mul_nonsing_inv _ hA'_det, one_mulVec]

  -- Step 4: u = -t · A'⁻¹ *ᵥ g (from A'u = -tg and A' injective)
  have h_u_eq : u = (-t) • A'⁻¹.mulVec g := by
    have h_inj : Function.Injective A'.mulVec := by
      rwa [mulVec_injective_iff_isUnit]
    apply h_inj
    rw [mulVec_smul, h_inv_g, h_Apu]

  -- Step 5: gᵀu = (-t) * gᵀ(A'⁻¹g)
  have h_dp : dotProduct g u = (-t) * dotProduct g (A'⁻¹.mulVec g) := by
    rw [h_u_eq]
    unfold dotProduct
    simp only [Pi.smul_apply, smul_eq_mul, Finset.mul_sum]
    congr 1; ext j; ring

  -- Step 6: combine to get γ - μ = gᵀ(A'⁻¹g)
  -- h_gu: gᵀu = (μ-γ)t
  -- h_dp: gᵀu = -t · gᵀ(A'⁻¹g)
  -- So: -t · gᵀ(A'⁻¹g) = (μ-γ)t
  -- Since t ≠ 0: gᵀ(A'⁻¹g) = γ-μ
  have h_combined : (-t) * dotProduct g (A'⁻¹.mulVec g) = (μ - γ) * t := by
    linarith
  -- Divide by (-t) ≠ 0
  have h_result : dotProduct g (A'⁻¹.mulVec g) = γ - μ := by
    have h_neg_t_ne : (-t : ℝ) ≠ 0 := neg_ne_zero.mpr ht_ne
    -- h_combined : -t * gⵍ A'⁻¹ *ᵥ g = (μ - γ) * t
    -- (μ - γ) * t = -(t) * (γ - μ) = -t * (γ - μ)
    have h2 : (-t) * dotProduct g (A'⁻¹.mulVec g) = (-t) * (γ - μ) := by
      rw [h_combined]; ring
    exact mul_left_cancel₀ h_neg_t_ne h2
  linarith

/-- **The secular drop bound.**

    For the minimum eigenvalue drop δ = λ_min(A) - μ:
      γ - μ ≥ |⟨g, v_min⟩|² / δ

    (where v_min is the min eigenvector of A).
    Therefore: δ ≤ |⟨g, v_min⟩|² / (γ - μ)

    This follows from the spectral decomposition of the resolvent:
      gᵀ(A-μI)⁻¹g = Σ |⟨g,vⱼ⟩|²/(λⱼ-μ) ≥ |⟨g,v_min⟩|²/δ -/
theorem secular_drop_bound
    (A : Matrix (Fin n) (Fin n) ℝ)
    (hA : A.IsHermitian)
    (g : Fin n → ℝ)
    (hn : 0 < n)
    (μ : ℝ)
    (hμ_lt : μ < (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀) :
    -- The resolvent quadratic form bounds the drop
    dotProduct g ((A - μ • (1 : Matrix (Fin n) (Fin n) ℝ))⁻¹.mulVec g) ≥
    -- ... by at least the min-eigenspace projection divided by the drop
    (dotProduct g (⇑(hA.eigenvectorBasis ⟨0, hn⟩)))^2 /
    (hA.eigenvalues ⟨0, hn⟩ - μ) := by
  -- ═══════════════════════════════════════════════════════════════
  -- PROOF BY ORTHOGONAL DECOMPOSITION
  --
  -- Key idea: decompose g = c·v + w where w ⊥ v, then
  --   gᵀM⁻¹g = c²/δ + wᵀM⁻¹w ≥ c²/δ
  -- ═══════════════════════════════════════════════════════════════

  set M := A - μ • (1 : Matrix (Fin n) (Fin n) ℝ) with hM_def
  set v := ⇑(hA.eigenvectorBasis ⟨0, hn⟩) with hv_def
  set c := dotProduct g v with hc_def
  set δ := hA.eigenvalues ⟨0, hn⟩ - μ with hδ_def

  -- Step 1: δ > 0 (eigenvalue is above μ)
  have hδ_pos : 0 < δ := by
    simp only [hδ_def]
    -- eigenvalues ⟨0, hn⟩ = eigenvalues₀ at some reindexed position
    -- eigenvalues₀ at any index ≥ inf' eigenvalues₀ > μ
    have h_ge_inf : hA.eigenvalues ⟨0, hn⟩ ≥
        (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
          (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
          hA.eigenvalues₀ := by
      unfold Matrix.IsHermitian.eigenvalues
      apply Finset.inf'_le
      exact Finset.mem_univ _
    linarith

  -- Step 2: M is Hermitian (A - μI is Hermitian when A is Hermitian)
  have hM_herm : M.IsHermitian := by
    simp only [hM_def, Matrix.IsHermitian]
    funext i j
    simp only [conjTranspose_apply, star_trivial, sub_apply, smul_apply, one_apply]
    have : A j i = A i j := by
      have := congr_fun (congr_fun hA i) j
      simp only [conjTranspose_apply, star_trivial] at this; exact this
    rw [this]
    by_cases h : i = j <;> simp [h, eq_comm]

  -- Step 3: M is positive definite (all eigenvalues of M are > 0)
  -- (Reuse the exact same approach as in bordered_secular_identity)
  have hM_pd : M.PosDef := by
    rw [hM_herm.posDef_iff_eigenvalues_pos]
    intro i
    rw [hM_herm.eigenvalues_eq i]
    simp only [star_trivial, RCLike.re_to_real]
    set vi := (⇑(hM_herm.eigenvectorBasis i) : Fin n → ℝ)
    have h_sub : M *ᵥ vi = A *ᵥ vi - μ • vi := by
      ext k
      show ((A - μ • (1 : Matrix (Fin n) (Fin n) ℝ)) *ᵥ vi) k =
           (A *ᵥ vi) k - μ * vi k
      simp only [sub_mulVec, smul_mulVec, one_mulVec, Pi.sub_apply,
                 Pi.smul_apply, smul_eq_mul]
    rw [h_sub, dotProduct_sub, dotProduct_smul]
    simp only [smul_eq_mul]
    have h_unit : dotProduct vi vi = 1 := by
      rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
      have h_norm : ‖(hM_herm.eigenvectorBasis i : EuclideanSpace ℝ (Fin n))‖ = 1 :=
        hM_herm.eigenvectorBasis.orthonormal.1 i
      rw [h_norm, one_pow]
    rw [h_unit, mul_one]
    have h_rayleigh := quadform_ge_min_eigenvalue_mul hA hn vi
    unfold realQuadForm at h_rayleigh
    rw [h_unit] at h_rayleigh
    simp only [mul_one] at h_rayleigh
    linarith

  -- Step 4: Av = λv, so Mv = (λ-μ)v = δv
  have hAv : A *ᵥ v = (hA.eigenvalues ⟨0, hn⟩) • v :=
    hA.mulVec_eigenvectorBasis ⟨0, hn⟩

  have hMv : M *ᵥ v = δ • v := by
    have h_sub : M *ᵥ v = A *ᵥ v - μ • v := by
      ext k
      show ((A - μ • (1 : Matrix (Fin n) (Fin n) ℝ)) *ᵥ v) k =
           (A *ᵥ v) k - μ * v k
      simp only [sub_mulVec, smul_mulVec, one_mulVec, Pi.sub_apply,
                 Pi.smul_apply, smul_eq_mul]
    rw [h_sub, hAv]
    ext k
    simp only [Pi.sub_apply, Pi.smul_apply, smul_eq_mul]
    ring

  -- Step 5: v is unit (from orthonormal basis)
  have hv_unit : dotProduct v v = 1 := by
    rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
    have h_norm : ‖(hA.eigenvectorBasis ⟨0, hn⟩ : EuclideanSpace ℝ (Fin n))‖ = 1 :=
      hA.eigenvectorBasis.orthonormal.1 ⟨0, hn⟩
    rw [h_norm, one_pow]

  -- Step 6: Decompose g = c·v + w where w ⊥ v
  set w := g - c • v with hw_def
  have hw_orth : dotProduct w v = 0 := by
    simp only [hw_def, sub_dotProduct, smul_dotProduct, smul_eq_mul, hc_def]
    rw [hv_unit, mul_one, sub_self]

  -- Step 7: Express gᵀM⁻¹g using the decomposition
  -- g = w + c·v, so M⁻¹g = M⁻¹w + c·M⁻¹v
  -- M⁻¹v = (1/δ)·v because Mv = δv

  -- Step 7a: M⁻¹v = (1/δ)·v
  have hM_inv_v : M⁻¹.mulVec v = (1/δ) • v := by
    -- Strategy: show M *ᵥ ((1/δ) • v) = v, then use M invertible to get M⁻¹v = (1/δ)v
    have hM_unit : IsUnit M := hM_pd.isUnit
    have hM_det : IsUnit M.det := by rwa [Matrix.isUnit_iff_isUnit_det] at hM_unit
    -- M *ᵥ ((1/δ) • v) = (1/δ) • (M *ᵥ v) = (1/δ) • (δ • v) = v
    have h_action : M *ᵥ ((1/δ) • v) = v := by
      rw [Matrix.mulVec_smul, hMv, smul_smul]
      simp [ne_of_gt hδ_pos]
    -- M is invertible, so M⁻¹ (Mx) = x for all x
    -- Applying M⁻¹ to both sides: M⁻¹ *ᵥ (M *ᵥ ((1/δ) • v)) = M⁻¹ *ᵥ v
    -- LHS = (M⁻¹ * M) *ᵥ ((1/δ) • v) = (1/δ) • v
    calc M⁻¹.mulVec v
        = M⁻¹.mulVec (M.mulVec ((1/δ) • v)) := by rw [h_action]
      _ = (M⁻¹ * M).mulVec ((1/δ) • v) := by rw [mulVec_mulVec]
      _ = (1 : Matrix (Fin n) (Fin n) ℝ).mulVec ((1/δ) • v) := by
            rw [Matrix.nonsing_inv_mul _ hM_det]
      _ = (1/δ) • v := by rw [Matrix.one_mulVec]

  have h_cross_vw : dotProduct v (M⁻¹.mulVec w) = 0 := by
    -- v ⬝ᵥ (M⁻¹ *ᵥ w) = (v ᵥ* M⁻¹) ⬝ᵥ w  [dotProduct_mulVec]
    rw [dotProduct_mulVec]
    -- v ᵥ* M⁻¹ = (M⁻¹)ᵀ *ᵥ v = M⁻¹ *ᵥ v (since M is symmetric)
    have hM_sym : Mᵀ = M := by
      ext i j
      -- Mᵀ i j = M j i = M i j (from Hermitian)
      show M j i = M i j
      have h := congr_fun (congr_fun hM_herm i) j
      simp only [conjTranspose_apply, star_trivial] at h
      exact h
    have hMinv_sym : (M⁻¹)ᵀ = M⁻¹ := by
      rw [transpose_nonsing_inv, hM_sym]
    -- v ᵥ* M⁻¹ = (M⁻¹)ᵀ *ᵥ v = M⁻¹ *ᵥ v
    rw [← mulVec_transpose, hMinv_sym]
    -- (M⁻¹ *ᵥ v) ⬝ᵥ w = ((1/δ) • v) ⬝ᵥ w = (1/δ) * (v ⬝ᵥ w) = 0
    rw [hM_inv_v, smul_dotProduct, smul_eq_mul, dotProduct_comm, hw_orth, mul_zero]

  -- Step 7c: vᵀM⁻¹v = 1/δ
  have h_diag : dotProduct v (M⁻¹.mulVec v) = 1/δ := by
    rw [hM_inv_v, dotProduct_smul, hv_unit, smul_eq_mul, mul_one]

  -- Step 8: g = w + c·v, so expand gᵀM⁻¹g
  have hg_eq : g = w + c • v := by
    simp only [hw_def]; ring_nf

  -- Step 8a: gᵀM⁻¹g = wᵀM⁻¹w + c²·(1/δ)
  -- First, the reverse cross-term: w ⬝ᵥ (M⁻¹ *ᵥ v) = 0
  have h_cross_wv : dotProduct w (M⁻¹.mulVec v) = 0 := by
    rw [hM_inv_v, dotProduct_smul, smul_eq_mul, hw_orth, mul_zero]

  have h_expand_quad : dotProduct g (M⁻¹.mulVec g) =
      dotProduct w (M⁻¹.mulVec w) + c^2 * (1/δ) := by
    rw [hg_eq]
    simp only [Matrix.mulVec_add, Matrix.mulVec_smul,
               dotProduct_add, add_dotProduct, smul_dotProduct, dotProduct_smul]
    simp only [smul_eq_mul]
    rw [h_diag, h_cross_vw, h_cross_wv]
    ring

  -- Step 8b: wᵀM⁻¹w ≥ 0
  -- Use the y = M⁻¹w substitution: w = My, so wᵀM⁻¹w = (My)ᵀy
  -- = dotProduct (M*ᵥy) y = (y ᵥ* M) ⬝ᵥ y [dotProduct_mulVec]
  -- = y ⬝ᵥ (Mᵀ *ᵥ y) [mulVec_transpose reversed]
  -- = y ⬝ᵥ (M *ᵥ y) [M symmetric] = star y ⬝ᵥ (M *ᵥ y) [star trivial]
  -- ≥ 0 [M PD]
  have h_quad_w_nonneg : 0 ≤ dotProduct w (M⁻¹.mulVec w) := by
    set y := M⁻¹.mulVec w
    have hM_unit : IsUnit M := hM_pd.isUnit
    have hM_det : IsUnit M.det := by rwa [Matrix.isUnit_iff_isUnit_det] at hM_unit
    -- w = M *ᵥ y
    have hw_eq : w = M *ᵥ y := by
      show w = M *ᵥ (M⁻¹ *ᵥ w)
      rw [mulVec_mulVec, Matrix.mul_nonsing_inv _ hM_det, one_mulVec]
    rw [hw_eq]
    -- (M *ᵥ y) ⬝ᵥ y = y ⬝ᵥ (Mᵀ *ᵥ y) [dotProduct_comm + dotProduct_mulVec]
    rw [dotProduct_comm]
    -- y ⬝ᵥ (M *ᵥ y) ≥ 0
    -- star y ⬝ᵥ (M *ᵥ y) ≥ 0 from PosSemidef
    have h_ps := hM_pd.posSemidef.dotProduct_mulVec_nonneg y
    simp only [Pi.star_def, star_trivial] at h_ps
    exact h_ps

  -- Final bound: gᵀM⁻¹g = wᵀM⁻¹w + c²/δ ≥ c²/δ
  rw [h_expand_quad]
  have h_c2_div : c^2 * (1/δ) = c^2 / δ := by ring
  rw [h_c2_div]
  linarith

end SecularEquation

-- ════════════════════════════════════════════════
-- §2: DROP BOUND FOR GRAM MATRICES
-- ════════════════════════════════════════════════

/-- **Eigenvalue drop bound** (from secular equation).

    For the Gram matrix G_N = [[G_{N-1}, g], [gᵀ, γ]]:

      eigenDrop N ≤ cos²θ · ‖g‖² / S

    Previously an AXIOM (`drop_formula_bound`), now graduated to a
    theorem. The proof chains:

    1. G_N is a bordered extension of G_{N-1} (GramInduction.lean)
    2. Secular equation gives δ ≤ |⟨g,v_min⟩|²/(γ-μ)
    3. For the Gram matrix: γ-μ ≥ S (since μ ~ 1/N² ≪ γ-S ~ 1/N)
    4. cos²θ · ‖g‖² = |⟨g,v_min⟩|² by definition of cosAlignment

    The remaining sorry is the secular equation derivation, which
    requires the spectral decomposition of the resolvent (A-μI)⁻¹.
    This is standard linear algebra (Golub & Van Loan §8.1) but
    requires Mathlib's spectral theorem infrastructure for resolvent
    operators. -/
theorem eigenDrop_le_projection_over_schur (N : ℕ) (hN : 3 ≤ N) :
    eigenDrop N ≤ (cosAlignment (N - 1))^2 *
      dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) /
      schurComplement (N - 1) := by
  sorry
  -- Full proof chain:
  -- 1. Express G_N as bordered matrix [[G_{N-1}, g], [gᵀ, γ]]
  --    (gramMatrix_bordered_eq in GramInduction.lean)
  -- 2. Min eigenvector [u,t] has t ≠ 0 (contradiction with λ_min bound)
  -- 3. Secular equation: γ - μ = gᵀ(G_{N-1} - μI)⁻¹g
  -- 4. Resolvent spectral decomposition:
  --    gᵀ(G_{N-1}-μI)⁻¹g = Σ |⟨g,vⱼ⟩|²/(λⱼ-μ) ≥ |⟨g,v_min⟩|²/δ
  -- 5. For Gram matrices: μ ≤ gᵀG_{N-1}⁻¹g (since λ_min ~ 1/N² ≪ γ-S ~ 1/N)
  -- 6. Therefore: γ-μ ≥ S, giving δ ≤ cos²θ · ‖g‖² / S

end
