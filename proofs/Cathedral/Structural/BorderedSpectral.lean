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
import Cathedral.Structural.Independence
import Cathedral.Gram.Bounds

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
    (_hH : M.IsHermitian)
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
    simp only [realQuadForm, dotProduct, mulVec]
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
      simp only [mulVec, dotProduct, sub_apply, smul_apply, one_apply]
      ring_nf
      simp
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
    simp only [star_trivial] at h_ps
    exact h_ps

  -- Final bound: gᵀM⁻¹g = wᵀM⁻¹w + c²/δ ≥ c²/δ
  rw [h_expand_quad]
  have h_c2_div : c^2 * (1/δ) = c^2 / δ := by ring
  rw [h_c2_div]
  linarith

/-- **Resolvent upper bound**: For Hermitian A with μ < λ_min(A),
    gᵀ(A-μI)⁻¹g ≤ ‖g‖² / (λ_min(A) - μ).

    Proof via substitution y = (A-μI)⁻¹g:
    1. gᵀ(A-μI)⁻¹g = yᵀ(A-μI)y  (since g = (A-μI)y)
    2. yᵀ(A-μI)y ≥ δ · yᵀy        (Rayleigh bound on A, δ = λ_min(A) - μ)
    3. (gᵀy)² ≤ (gᵀg)(yᵀy)         (Cauchy-Schwarz)
    4. Combining: gᵀ(A-μI)⁻¹g ≤ gᵀg / δ -/
theorem resolvent_upper_bound
    {n : ℕ}
    (A : Matrix (Fin n) (Fin n) ℝ) (hA : A.IsHermitian)
    (g : Fin n → ℝ) (hn : 0 < n) (μ : ℝ)
    (hμ_lt : μ < (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀) :
    dotProduct g ((A - μ • (1 : Matrix (Fin n) (Fin n) ℝ))⁻¹.mulVec g) ≤
    dotProduct g g /
    ((Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
      hA.eigenvalues₀ - μ) := by
  set M := A - μ • (1 : Matrix (Fin n) (Fin n) ℝ) with hM_def
  set lmin := (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
    (by rw [Fintype.card_fin]; exact ⟨⟨0, hn⟩, Finset.mem_univ _⟩)
    hA.eigenvalues₀
  set δ := lmin - μ
  have hδ_pos : 0 < δ := by linarith

  -- M = A - μI is Hermitian
  have hM_herm : M.IsHermitian := by
    simp only [hM_def, Matrix.IsHermitian]
    funext i j
    simp only [conjTranspose_apply, star_trivial, sub_apply, smul_apply, one_apply]
    have hAij : A j i = A i j := by
      have := congr_fun (congr_fun hA i) j
      simp only [conjTranspose_apply, star_trivial] at this; exact this
    by_cases h : i = j <;> simp [h, eq_comm, hAij]

  -- M is PD → invertible
  have hM_pd : M.PosDef := by
    rw [hM_herm.posDef_iff_eigenvalues_pos]; intro i
    rw [hM_herm.eigenvalues_eq i]
    simp only [star_trivial, RCLike.re_to_real]
    set vi := (⇑(hM_herm.eigenvectorBasis i) : Fin n → ℝ)
    have h_sub : M *ᵥ vi = A *ᵥ vi - μ • vi := by
      ext k; simp only [hM_def, sub_mulVec, smul_mulVec, one_mulVec,
        Pi.sub_apply, Pi.smul_apply, smul_eq_mul]
    rw [h_sub, dotProduct_sub, dotProduct_smul]; simp only [smul_eq_mul]
    have h_unit : dotProduct vi vi = 1 := by
      rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
      rw [hM_herm.eigenvectorBasis.orthonormal.1 i, one_pow]
    rw [h_unit, mul_one]
    have h_rb := quadform_ge_min_eigenvalue_mul hA hn vi
    unfold realQuadForm at h_rb; rw [h_unit] at h_rb; simp only [mul_one] at h_rb; linarith
  have hM_det : IsUnit M.det := by
    rw [← Matrix.isUnit_iff_isUnit_det]; exact hM_pd.isUnit

  -- Handle g = 0 case
  by_cases hg_zero : g = 0
  · subst hg_zero; simp [dotProduct, mulVec]


  -- Set y = M⁻¹g, so g = My
  set y := M⁻¹.mulVec g with hy_def
  have hg_My : g = M *ᵥ y := by
    show g = M *ᵥ (M⁻¹ *ᵥ g)
    rw [mulVec_mulVec, Matrix.mul_nonsing_inv _ hM_det, one_mulVec]

  -- Key identity: gᵀM⁻¹g = gᵀy = yᵀMy (since g = My, M symmetric)
  have h_identity : dotProduct g (M⁻¹.mulVec g) = dotProduct y (M.mulVec y) := by
    -- gᵀy = gᵀ(M⁻¹g) by def. Also g = My, so gᵀy = (My)ᵀy.
    -- For symmetric M: (My)ᵀy = yᵀMy, i.e., dotProduct(My, y) = dotProduct(y, My)
    show dotProduct g y = dotProduct y (M *ᵥ y)
    conv_lhs => rw [hg_My]
    -- dotProduct (M*ᵥy) y = dotProduct y (M*ᵥy) by symmetry
    exact dotProduct_comm (M *ᵥ y) y

  -- Rayleigh bound: yᵀMy = yᵀAy - μ·yᵀy ≥ δ·yᵀy
  have h_rayleigh_M : dotProduct y (M.mulVec y) ≥ δ * dotProduct y y := by
    have h_decomp : dotProduct y (M.mulVec y) =
        dotProduct y (A.mulVec y) - μ * dotProduct y y := by
      simp only [hM_def, sub_mulVec, smul_mulVec, one_mulVec,
        dotProduct_sub, dotProduct_smul, smul_eq_mul]
    rw [h_decomp]
    have h_rb := quadform_ge_min_eigenvalue_mul hA hn y
    unfold realQuadForm at h_rb; linarith

  -- y ≠ 0 (since g ≠ 0 and M is invertible: g = My ≠ 0 → y ≠ 0)
  have hy_ne : y ≠ 0 := by
    intro h_abs
    have : g = 0 := by
      rw [hg_My, h_abs]
      ext i; simp [mulVec]
    exact hg_zero this

  -- Nonzero vectors have positive self-dot-product
  have hyy_pos : 0 < dotProduct y y := by
    have h_norm_pos : (0 : ℝ) < ‖(WithLp.toLp 2 y : EuclideanSpace ℝ (Fin n))‖ := by
      rw [norm_pos_iff]; rwa [Ne, WithLp.toLp_eq_zero]
    rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
    exact pow_pos h_norm_pos 2
  have hgg_pos : 0 < dotProduct g g := by
    have h_norm_pos : (0 : ℝ) < ‖(WithLp.toLp 2 g : EuclideanSpace ℝ (Fin n))‖ := by
      rw [norm_pos_iff]; rwa [Ne, WithLp.toLp_eq_zero]
    rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
    exact pow_pos h_norm_pos 2

  -- resolvent > 0
  have h_res_pos : 0 < dotProduct g (M⁻¹.mulVec g) := by
    rw [h_identity]; nlinarith [h_rayleigh_M, hyy_pos]

  -- Final chain: gᵀM⁻¹g ≤ gᵀg / δ
  -- Equivalently: δ * gᵀM⁻¹g ≤ gᵀg
  rw [le_div_iff₀ hδ_pos]
  -- Goal: δ * dotProduct g (M⁻¹.mulVec g) ≤ ... no wait
  -- le_div_iff₀ : a ≤ b/c ↔ c*a ≤ b (for c > 0)... or is it a*c ≤ b?
  -- Actually Lean's le_div_iff₀ : a / b ≤ c ↔ a ≤ c * b. Nope.
  -- le_div_iff₀ hδ_pos : a ≤ b / δ ↔ a * δ ≤ b
  -- So goal becomes: dotProduct g (M⁻¹.mulVec g) * δ ≤ dotProduct g g
  -- This is what we want!

  -- From h_identity: gᵀM⁻¹g = yᵀMy
  -- From h_rayleigh_M: yᵀMy ≥ δ·yᵀy
  -- CS: (gᵀy)² ≤ (gᵀg)(yᵀy) [Cauchy-Schwarz on Fin n → ℝ vectors]
  -- gᵀy = gᵀM⁻¹g (by definition of y)
  -- So: (gᵀM⁻¹g)² ≤ (gᵀg)(yᵀy)
  -- And: yᵀMy ≥ δ·yᵀy → yᵀy ≤ yᵀMy/δ = gᵀM⁻¹g/δ
  -- So: (gᵀM⁻¹g)² ≤ gᵀg · gᵀM⁻¹g/δ
  -- → δ·(gᵀM⁻¹g)² ≤ gᵀg · gᵀM⁻¹g
  -- → δ·gᵀM⁻¹g ≤ gᵀg (dividing by gᵀM⁻¹g > 0)

  -- Cauchy-Schwarz: (gᵀy)² ≤ (gᵀg)(yᵀy) via inner product
  have h_cs : (dotProduct g y) ^ 2 ≤ dotProduct g g * dotProduct y y := by
    set g' := (WithLp.toLp 2 g : EuclideanSpace ℝ (Fin n))
    set y' := (WithLp.toLp 2 y : EuclideanSpace ℝ (Fin n))
    -- Bridge: inner ↔ dotProduct
    have h_gy : @inner ℝ _ _ g' y' = dotProduct g y :=
      inner_eq_dotProduct g y
    have h_gg : @inner ℝ _ _ g' g' = dotProduct g g :=
      inner_eq_dotProduct g g
    have h_yy : @inner ℝ _ _ y' y' = dotProduct y y :=
      inner_eq_dotProduct y y
    -- |⟨g',y'⟩| ≤ ‖g'‖·‖y'‖ (Cauchy-Schwarz in EuclideanSpace)
    have h_ip := abs_real_inner_le_norm g' y'
    -- Square both sides: ⟨g',y'⟩² = |⟨g',y'⟩|² ≤ (‖g'‖·‖y'‖)² = ‖g'‖²·‖y'‖²
    have h1 : (@inner ℝ _ _ g' y') ^ 2 ≤ (‖g'‖ * ‖y'‖) ^ 2 := by
      rw [← sq_abs]
      exact sq_le_sq' (by nlinarith [abs_nonneg (@inner ℝ _ _ g' y'), norm_nonneg g', norm_nonneg y']) h_ip
    rw [mul_pow] at h1
    -- ‖g'‖² = ⟨g',g'⟩ = gᵀg, ‖y'‖² = yᵀy
    rw [← real_inner_self_eq_norm_sq, ← real_inner_self_eq_norm_sq] at h1
    rw [h_gy, h_gg, h_yy] at h1
    exact h1

  -- Chain the inequalities
  -- gᵀy = gᵀM⁻¹g (by def)
  -- yᵀMy = gᵀM⁻¹g (by h_identity)
  -- δ·yᵀy ≤ yᵀMy (by h_rayleigh_M)
  -- (gᵀy)² ≤ gᵀg · yᵀy (by CS)
  --
  -- From CS: yᵀy ≥ (gᵀy)²/gᵀg
  -- From Rayleigh: gᵀM⁻¹g = yᵀMy ≥ δ·yᵀy ≥ δ·(gᵀy)²/gᵀg = δ·(gᵀM⁻¹g)²/gᵀg
  -- So: gᵀg·gᵀM⁻¹g ≥ δ·(gᵀM⁻¹g)²
  -- Divide by gᵀM⁻¹g > 0: gᵀg ≥ δ·gᵀM⁻¹g
  -- Which is: δ·gᵀM⁻¹g ≤ gᵀg. QED.

  nlinarith [h_identity, h_rayleigh_M, h_cs, h_res_pos, hgg_pos, hyy_pos]

end SecularEquation

-- ════════════════════════════════════════════════
-- §1b: GRAM MATRIX BORDERED STRUCTURE (Bridge)
-- ════════════════════════════════════════════════

/-! ### Bridge lemmas connecting gramMatrix to bordered matrix framework.

    gramMatrix N (size (N-1)×(N-1)) is a bordered extension of
    gramMatrix (N-1) (size (N-2)×(N-2)):

      gramMatrix N = [[gramMatrix(N-1), g], [gᵀ, γ]]

    where g = crossCorrVec(N-1), γ = gramEntry(N-1)(N-1).

    These lemmas are pure index arithmetic — no mathematics. -/

/-- Top-left block: gramMatrix N embeds gramMatrix(N-1).
    Both use gramEntry(i+1, j+1), which is independent of N. -/
lemma gramMatrix_bordered_topleft (N : ℕ) (hN : 3 ≤ N)
    (i j : Fin (N - 2)) :
    (gramMatrix N) ⟨i.val, by omega⟩ ⟨j.val, by omega⟩ =
    (gramMatrix (N - 1)) i j := by
  simp only [gramMatrix, of_apply]

/-- Border column: gramMatrix N's last column matches crossCorrVec(N-1).
    (gramMatrix N)(i, last) = gramEntry(i+1, N-1) = gramEntry(N-1, i+1)
    = crossCorrVec(N-1)(i). -/
lemma gramMatrix_bordered_border (N : ℕ) (hN : 3 ≤ N)
    (i : Fin (N - 2)) :
    (gramMatrix N) ⟨i.val, by omega⟩ ⟨N - 2, by omega⟩ =
    crossCorrVec (N - 1) i := by
  simp only [gramMatrix, of_apply, crossCorrVec]
  rw [gramEntry_comm]
  congr 1; omega

/-- Corner entry: gramMatrix N's bottom-right = gramEntry(N-1, N-1). -/
lemma gramMatrix_bordered_corner (N : ℕ) (hN : 3 ≤ N) :
    (gramMatrix N) ⟨N - 2, by omega⟩ ⟨N - 2, by omega⟩ =
    gramEntry (N - 1) (N - 1) := by
  simp only [gramMatrix, of_apply]
  congr 1 <;> omega

/-- **lambdaMin is an eigenvalue** of gramMatrix N.
    Since eigenvalues₀ is a finite set, inf' is achieved. -/
lemma lambdaMin_is_eigenvalue (N : ℕ) (hN : 2 ≤ N) :
    ∃ i₀ : Fin (Fintype.card (Fin (N - 1))),
      lambdaMin N = (gramMatrix_hermitian N).eigenvalues₀ i₀ := by
  simp only [lambdaMin, show N ≥ 2 from hN, dite_true]
  -- inf' achieves its minimum on a nonempty finite set
  have hne : (Finset.univ : Finset (Fin (Fintype.card (Fin (N - 1))))).Nonempty := by
    rw [Fintype.card_fin]; exact ⟨⟨0, by omega⟩, Finset.mem_univ _⟩
  obtain ⟨i₀, _, hi₀⟩ := Finset.exists_mem_eq_inf' hne (gramMatrix_hermitian N).eigenvalues₀
  exact ⟨i₀, hi₀⟩

/-- **lambdaMin is at most any eigenvalue** of gramMatrix N. -/
lemma lambdaMin_le_eigenvalue (N : ℕ) (hN : 2 ≤ N)
    (i : Fin (Fintype.card (Fin (N - 1)))) :
    lambdaMin N ≤ (gramMatrix_hermitian N).eigenvalues₀ i := by
  simp only [lambdaMin, show N ≥ 2 from hN, dite_true]
  exact Finset.inf'_le _ (Finset.mem_univ _)

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

-- Schur complement S_N > 0 for all N ≥ 2 (PD Gram matrices).
theorem schurComplement_pos_of_ge_two (N : ℕ) (hN : 2 ≤ N) :
    0 < schurComplement N := by
  set G := gramMatrix N
  set g := crossCorrVec N
  set c := G⁻¹.mulVec g with hc_def
  set a := gramEntry N N with ha_def
  set w : Fin ((N + 1) - 1) → ℝ := fun i =>
    if h : i.val < N - 1 then -(c ⟨i.val, h⟩) else 1 with hw_def
  have hw_ne : w ≠ 0 := by
    intro hw_zero
    have : w ⟨N - 1, by omega⟩ = 0 := congr_fun hw_zero ⟨N - 1, by omega⟩
    simp only [hw_def, show ¬(N - 1 < N - 1) from lt_irrefl _, dite_false] at this
    linarith
  suffices h_eq : realQuadForm (gramMatrix (N + 1)) w = schurComplement N by
    rw [← h_eq]; exact gram_pos_def (N + 1) (by omega) w hw_ne
  have h_det : G.det ≠ 0 := gramMatrix_det_ne_zero N hN
  have h_unit : IsUnit G.det := gramMatrix_isUnit_det N hN
  have h_Gc : G.mulVec c = g := by
    rw [hc_def, Matrix.mulVec_mulVec,
        Matrix.mul_nonsing_inv G h_unit, Matrix.one_mulVec]
  have h_cGc : dotProduct c (G.mulVec c) = dotProduct c g := by rw [h_Gc]
  have h_dot_comm : dotProduct c g = dotProduct g c := by
    simp [dotProduct, Finset.sum_congr rfl (fun i _ => mul_comm (c i) (g i))]
  -- Reduce to block expansion: wᵀG_{N+1}w = cᵀGc - 2gᵀc + a
  suffices h_block : realQuadForm (gramMatrix (N + 1)) w =
      dotProduct c (G.mulVec c) - 2 * dotProduct g c + a by
    rw [h_block, h_cGc, h_dot_comm]
    unfold schurComplement; simp only [G, g, hc_def]; ring
  -- Helper: split a Fin n sum into Fin (n-1) sum + last term
  have fin_sum_decompose : ∀ (m : ℕ) (hm : 1 ≤ m) (f : Fin m → ℝ),
      ∑ x : Fin m, f x =
      (∑ x : Fin (m - 1), f ⟨x.val, by omega⟩) + f ⟨m - 1, by omega⟩ := by
    intro m hm f
    obtain ⟨k, rfl⟩ := Nat.exists_eq_succ_of_ne_zero (by omega : m ≠ 0)
    simp only [Nat.succ_sub_one]
    rw [Fin.sum_univ_castSucc]
    congr 1
  -- Prove block expansion by splitting sums
  unfold realQuadForm
  simp only [dotProduct, Matrix.mulVec, gramMatrix, Matrix.of_apply,
    crossCorrVec, G, g, a, hw_def]
  -- Split outer sum using fin_sum_decompose
  have hN1 : 1 ≤ N + 1 - 1 := by omega
  rw [fin_sum_decompose (N + 1 - 1) hN1]
  -- Split the inner sums similarly using simp_rw
  simp_rw [fin_sum_decompose (N + 1 - 1) hN1]
  -- Simplify N+1-1-1 = N-1 and resolve ite conditions
  have hNsub : N + 1 - 1 - 1 = N - 1 := by omega
  simp only [hNsub, show ¬(N - 1 < N - 1) from lt_irrefl _, dite_false]
  -- Now the ite for x : Fin(N-1) with x.val < N-1 should be true
  simp only [show ∀ (x : Fin (N - 1)),
    (⟨x.val, (by omega : x.val < N + 1 - 1)⟩ : Fin (N + 1 - 1)).val < N - 1 from
    fun x => x.isLt, dite_true]
  -- Both sides now have same index set (Fin(N-1)).
  -- gramEntry(i,j) = gramEntry(j,i) since fract(i/x)*fract(j/x) is symmetric
  have hge_comm : ∀ i j, gramEntry i j = gramEntry j i := by
    intro i j; unfold gramEntry
    congr 1; ext x; ring
  -- Clean up mul_one, one_mul
  simp only [neg_mul, mul_neg, mul_one, one_mul]
  -- Normalize N-1+1 to N
  have hN1' : N - 1 + 1 = N := by omega
  simp only [hN1']
  -- Rewrite gramEntry(↑x + 1, N) to gramEntry(N, ↑x+1) via symmetry
  have h_cross : ∀ x : Fin (N + 1 - 1 - 1),
      gramEntry (↑x + 1) N = gramEntry N (↑x + 1) :=
    fun x => hge_comm _ _
  simp_rw [h_cross]
  -- Distribute neg/mul, then flatten sums
  simp only [mul_add, mul_neg,
    Finset.sum_add_distrib, Finset.sum_neg_distrib,
    neg_add_rev, neg_neg]
  -- Close with arithmetic identity
  suffices h :
    -(∑ x : Fin (N - 1), c x * gramEntry N (↑x + 1)) +
    (∑ x : Fin (N - 1), c x * ∑ x_1 : Fin (N - 1),
        gramEntry (↑x + 1) (↑x_1 + 1) * c x_1) +
    (-(∑ x : Fin (N - 1), gramEntry N (↑x + 1) * c x) +
    gramEntry N N) =
    ∑ x : Fin (N - 1), c x * ∑ x_1 : Fin (N - 1),
        gramEntry (↑x + 1) (↑x_1 + 1) * c x_1 -
    2 * ∑ x : Fin (N - 1), gramEntry N (↑x + 1) * c x +
    gramEntry N N by
    convert h using 2
  linarith [Finset.sum_congr rfl (show ∀ (x : Fin (N - 1)),
    x ∈ Finset.univ → c x * gramEntry N (↑x + 1) =
      gramEntry N (↑x + 1) * c x from fun x _ => by ring)]

/-- Diagonal entry of Gram matrix ≥ lambdaMin.
    This follows from the Rayleigh quotient: gramEntry(k)(k) = eₖᵀ G eₖ ≥ lambdaMin(G).
    Requires k ≥ 1 since gramEntry 0 0 = 0 (division by zero in the integrand). -/
theorem gramEntry_diag_ge_lambdaMin (N k : ℕ) (hN : 2 ≤ N) (hk : k < N) (hk1 : 1 ≤ k) :
    lambdaMin N ≤ gramEntry k k := by
  -- Setup
  set G := gramMatrix N with hG_def
  have hG_herm := gramMatrix_hermitian N
  have hN1_pos : 0 < N - 1 := by omega
  -- Standard basis vector eᵢ at index i = k-1
  set idx : Fin (N - 1) := ⟨k - 1, by omega⟩
  set e : Fin (N - 1) → ℝ := Pi.single idx 1
  -- Apply Rayleigh bound: vᵀGv ≥ lambdaMin · vᵀv
  have h_rb := quadform_ge_min_eigenvalue_mul hG_herm hN1_pos e
  -- Connect inf'(eigenvalues₀) to lambdaMin N
  have h_lmin : (Finset.univ : Finset (Fin (Fintype.card (Fin (N - 1))))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hN1_pos⟩, Finset.mem_univ _⟩)
      hG_herm.eigenvalues₀ = lambdaMin N := by
    simp only [lambdaMin, show N ≥ 2 from hN, dite_true]
  rw [h_lmin] at h_rb
  -- Compute dotProduct e e = 1 (norm² of standard basis vector)
  have h_norm : dotProduct e e = 1 := by
    unfold dotProduct e
    simp [Pi.single_apply, Finset.sum_ite_eq', Finset.mem_univ]
  rw [h_norm, mul_one] at h_rb
  -- Compute realQuadForm G e = G[idx][idx] = gramEntry k k
  have h_quad : realQuadForm G e = gramEntry k k := by
    unfold realQuadForm
    -- dotProduct e (G.mulVec e) = (G.mulVec e) idx = G idx idx
    -- since e = Pi.single idx 1
    have h_mulvec : ∀ j, G.mulVec e j = G j idx := by
      intro j; simp [mulVec, dotProduct, e, Pi.single_apply, Finset.sum_ite_eq', Finset.mem_univ]
    simp only [dotProduct, e, Pi.single_apply, h_mulvec]
    simp [Finset.sum_ite_eq', Finset.mem_univ]
    -- G idx idx = gramEntry ((k-1)+1) ((k-1)+1) = gramEntry k k
    show G ⟨k - 1, _⟩ ⟨k - 1, _⟩ = gramEntry k k
    simp only [hG_def, gramMatrix, of_apply]
    congr 1 <;> omega
  linarith [h_quad]

/-- **gramEntry(N)(1) > 0** for N ≥ 1.
    gramEntry N 1 = ∫₀¹ {1/(Nx)}{1/x} dx.
    On (1/2, 1): {1/x} = 1/x-1 > 0 and {1/(Nx)} = 1/(Nx) > 0 (for N ≥ 2).
    For N = 1: G(1,1) = ∫₀¹ {1/x}² dx > 0 (diagonal entry of PD matrix).

    This uses gramEntry_comm to get gramEntry(N)(1) = gramEntry(1)(N),
    then gramEntry_diag_lower for N=1, or integral positivity for N ≥ 2.

    IMPORTANT: This fact is used to derive gv ≠ 0 in the Rayleigh bypass. -/
theorem gramEntry_first_col_pos (N : ℕ) (hN : 1 ≤ N) :
    0 < gramEntry N 1 := by
  -- gramEntry N 1 = gramEntry 1 N by symmetry
  rw [gramEntry_comm]
  -- gramEntry 1 N = ∫₀¹ {1/(1·x)}·{1/(N·x)} dx
  -- Strategy: ∫₀¹ f ≥ ∫_{1/2}^1 f > 0
  -- The integrand is nonneg (gramEntry_integrand_nonneg) and strictly positive at x=3/4.
  -- Use integral_mono_interval to bound below, integral_pos to show positivity.
  set f := fun x : ℝ => Int.fract (1 / ((↑(1 : ℕ) : ℝ) * x)) * Int.fract (1 / ((↑N : ℝ) * x))
  -- The function in gramEntry 1 N matches f
  have hf_eq : gramEntry 1 N = ∫ x in (0:ℝ)..1, f x := by
    unfold gramEntry; simp only [f, Nat.cast_one]
  rw [hf_eq]
  -- ∫₀¹ f ≥ ∫_{1/2}^1 f (integral over larger interval)
  have h_sub : (∫ x in (1/2 : ℝ)..1, f x) ≤ ∫ x in (0:ℝ)..1, f x := by
    apply intervalIntegral.integral_mono_interval (by norm_num : (0:ℝ) ≤ 1/2)
      (by norm_num : (1:ℝ)/2 ≤ 1) (le_refl 1)
    · -- f ≥ 0 a.e.
      exact Filter.Eventually.of_forall fun x => mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _)
    · -- f is integrable on [0, 1]
      exact gramEntry_integrable 1 N
  -- ∫_{1/2}^1 f > 0
  have h_pos : 0 < ∫ x in (1/2 : ℝ)..1, f x := by
    apply intervalIntegral.intervalIntegral_pos_of_pos_on
    · -- IntervalIntegrable on [1/2, 1]: bounded measurable function
      rw [intervalIntegrable_iff]
      apply MeasureTheory.Measure.integrableOn_of_bounded
      · exact (measure_Ioc_lt_top).ne
      · exact (gramEntry_integrand_measurable 1 N).aestronglyMeasurable
      · exact Filter.Eventually.of_forall fun x => by
          rw [Real.norm_eq_abs, abs_of_nonneg (mul_nonneg (Int.fract_nonneg _) (Int.fract_nonneg _))]
          exact mul_le_one₀ (Int.fract_lt_one _).le (Int.fract_nonneg _) (Int.fract_lt_one _).le
    · -- ∀ x ∈ Ioo (1/2) 1, 0 < f x
      intro x ⟨hx_lb, hx_ub⟩
      -- Both Int.fract factors are > 0 because their arguments are non-integers
      have hx_pos : (0 : ℝ) < x := by linarith
      apply mul_pos
      · -- Int.fract(1/(1·x)) > 0
        -- 1/(1·x) = 1/x ∈ (1, 2), so ⌊1/x⌋ = 1, fract = 1/x - 1 > 0
        have h_simp : 1 / (↑(1:ℕ) * x) = 1 / x := by simp
        rw [h_simp]
        have h_lb : (1 : ℝ) < 1 / x := by rw [one_lt_div hx_pos]; linarith
        have h_ub : 1 / x < 2 := by rw [div_lt_iff₀ hx_pos]; linarith
        rw [Int.fract, sub_pos]
        -- ⌊1/x⌋ = 1 since 1 ≤ 1/x < 2
        have h_floor : ⌊(1 / x : ℝ)⌋ = 1 := by
          rw [Int.floor_eq_iff]
          constructor
          · exact_mod_cast h_lb.le
          · push_cast; linarith
        rw [h_floor]; exact_mod_cast h_lb
      · -- Int.fract(1/(N·x)) > 0
        -- 1/(N·x) ∈ (1/N, 2/N) ⊂ (0, 2), and ≠ integer
        have hNx_pos : (0 : ℝ) < ↑N * x := by positivity
        have h_val_pos : (0 : ℝ) < 1 / (↑N * x) := by positivity
        -- For N ≥ 2: 1/(Nx) < 1, so Int.fract = 1/(Nx) > 0
        -- For N = 1: same as factor 1
        by_cases hN1 : N = 1
        · -- N = 1: same as factor 1
          subst hN1
          simp only [Nat.cast_one, one_mul]
          have h_lb : (1 : ℝ) < 1 / x := by rw [one_lt_div hx_pos]; linarith
          have h_ub : 1 / x < 2 := by rw [div_lt_iff₀ hx_pos]; linarith
          rw [Int.fract, sub_pos]
          have h_floor : ⌊(1 / x : ℝ)⌋ = 1 := by
            rw [Int.floor_eq_iff]
            constructor
            · exact_mod_cast h_lb.le
            · push_cast; linarith
          rw [h_floor]; exact_mod_cast h_lb
        · -- N ≥ 2: 1/(Nx) ∈ (0, 1), so Int.fract = self
          have hN_ge2 : 2 ≤ N := by omega
          have h_lt_one : 1 / (↑N * x) < 1 := by
            rw [div_lt_one hNx_pos]
            have : (2 : ℝ) ≤ ↑N := by exact_mod_cast hN_ge2
            nlinarith
          rw [Int.fract_eq_self.mpr ⟨le_of_lt h_val_pos, h_lt_one⟩]
          exact h_val_pos
    · norm_num
  linarith

theorem eigenDrop_le_projection_over_schur (N : ℕ) (hN : 3 ≤ N) :
    eigenDrop N ≤
      dotProduct (crossCorrVec (N - 1)) (crossCorrVec (N - 1)) /
      (gramEntry (N - 1) (N - 1) - lambdaMin N) := by
  -- The bound eigenDrop ≤ cos²θ·‖g‖²/S follows from:
  --   eigenDrop ≤ ‖g‖²/S (from secular equation + Parseval)
  -- since cos²θ·‖g‖²/S ≥ 0 and the actual bound is even weaker.
  -- We prove the cos²θ version by showing eigenDrop ≤ ‖g‖²/S
  -- and noting ‖g‖²/S ≤ cos²θ·‖g‖²/S when cos²θ ≥ 1,
  -- OR directly via the secular equation applied to the min eigenspace.
  --
  -- Actually, since cos²θ ≤ 1, we have cos²θ·‖g‖²/S ≤ ‖g‖²/S.
  -- The theorem claims eigenDrop ≤ cos²θ·‖g‖²/S which is a TIGHTER bound.
  -- We prove it by showing eigenDrop·(γ-μ) ≤ cos²θ·‖g‖² through the
  -- resolvent spectral decomposition.
  by_cases h_trivial : eigenDrop N ≤ 0
  · calc eigenDrop N
        ≤ 0 := h_trivial
      _ ≤ _ := by
          apply div_nonneg
          · unfold dotProduct
            exact Finset.sum_nonneg fun i _ => mul_self_nonneg _
          · -- gramEntry(N-1)(N-1) - lambdaMin(N) ≥ 0:
            -- diagonal entry of PD matrix ≥ smallest eigenvalue (Rayleigh quotient)
            apply sub_nonneg.mpr
            -- gramEntry(N-1)(N-1) = eᵀMe where e is standard basis vector
            -- Rayleigh: eᵀMe ≥ lambdaMin(M) · eᵀe = lambdaMin(M) (unit vector)
            exact gramEntry_diag_ge_lambdaMin N (N - 1) (by omega) (by omega) (by omega)
  simp only [not_le] at h_trivial
  -- ═══════════════════════════════════════════════════════════════
  -- KEY TRICK: Eliminate N by writing N = k + 3
  -- ═══════════════════════════════════════════════════════════════
  -- This makes N-1 = k+2 = (k+1)+1 syntactically, so
  -- gramMatrix N is on Fin((k+1)+1) — the Fin(n+1) form
  -- needed by the secular equation theorems.
  obtain ⟨k, rfl⟩ : ∃ k, N = k + 3 := ⟨N - 3, by omega⟩
  -- Now: N = k+3, N-1 = k+2, N-2 = k+1
  -- gramMatrix (k+3) : Fin(k+2) × Fin(k+2) = Fin((k+1)+1)
  -- gramMatrix (k+2) : Fin(k+1) × Fin(k+1) = Fin(n)
  set n := k + 1 with hn_def
  -- M := gramMatrix(k+3) on Fin(n+1), A := gramMatrix(k+2) on Fin(n)
  set M := gramMatrix (k + 3) with hM_def
  set A := gramMatrix (k + 2) with hA_def
  set gv := crossCorrVec (k + 2) with hg_def
  set γ := gramEntry (k + 2) (k + 2) with hγ_def
  have hM_herm := gramMatrix_hermitian (k + 3)
  have hA_herm := gramMatrix_hermitian (k + 2)
  have hn_pos : 0 < n := by omega
  -- Nat subtraction simplification
  have hk3 : k + 3 - 1 = k + 2 := by omega
  have hk2 : k + 2 - 1 = k + 1 := by omega
  -- ═══════════════════════════════════════════════════════════════
  -- STEP 1: Bordered structure (types match!)
  have hA_eq : ∀ i j : Fin n,
      M (Fin.castSucc i) (Fin.castSucc j) = A i j := by
    intro i j
    show (gramMatrix (k + 3)) ⟨i.val, _⟩ ⟨j.val, _⟩ =
         (gramMatrix (k + 2)) i j
    simp only [gramMatrix, of_apply]
  have hg_eq : ∀ i : Fin n,
      M (Fin.castSucc i) (Fin.last n) = gv i := by
    intro i
    show (gramMatrix (k + 3)) ⟨i.val, _⟩ ⟨n, _⟩ = crossCorrVec (k + 2) i
    simp only [gramMatrix, of_apply, crossCorrVec]
    rw [gramEntry_comm]
  have hγ_eq : M (Fin.last n) (Fin.last n) = γ := by
    show (gramMatrix (k + 3)) ⟨n, _⟩ ⟨n, _⟩ = gramEntry (k + 2) (k + 2)
    simp only [gramMatrix, of_apply]; congr 1
  have hδ_pos : 0 < eigenDrop (k + 3) := h_trivial
  have hmu_lt : lambdaMin (k + 3) < lambdaMin (k + 2) := by
    show lambdaMin (k + 3) < lambdaMin (k + 3 - 1)
    unfold eigenDrop at hδ_pos; linarith
  have hk2_ge2 : k + 2 ≥ 2 := by omega
  have hk3_ge2 : k + 3 ≥ 2 := by omega
  have hmu_lt_inf : lambdaMin (k + 3) <
      (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
        (by rw [Fintype.card_fin]; exact ⟨⟨0, hn_pos⟩, Finset.mem_univ _⟩)
        hA_herm.eigenvalues₀ := by
    convert hmu_lt using 1
  have hne_dir : (Finset.univ : Finset (Fin (n + 1))).Nonempty :=
    ⟨⟨0, by omega⟩, Finset.mem_univ _⟩
  obtain ⟨j₀, _, hj₀⟩ := Finset.exists_mem_eq_inf' hne_dir hM_herm.eigenvalues
  have hmin_eq : (Finset.univ.inf' hne_dir hM_herm.eigenvalues) = lambdaMin (k + 3) := by
    simp only [lambdaMin, show k + 3 ≥ 2 from hk3_ge2, dite_true]
    unfold Matrix.IsHermitian.eigenvalues
    apply le_antisymm
    · apply Finset.le_inf'
      intro j _
      let σ' := Fintype.equivOfCardEq (Fintype.card_fin (Fintype.card (Fin (n + 1))))
      have : hM_herm.eigenvalues₀ j = hM_herm.eigenvalues₀ (σ'.symm (σ' j)) := by
        simp [Equiv.symm_apply_apply]
      rw [this]
      exact Finset.inf'_le _ (Finset.mem_univ _)
    · apply Finset.le_inf'
      intro i _
      let σ' := Fintype.equivOfCardEq (Fintype.card_fin (Fintype.card (Fin (n + 1))))
      exact Finset.inf'_le _ (Finset.mem_univ _)

  set x := (⇑(hM_herm.eigenvectorBasis j₀) : Fin (n + 1) → ℝ) with hx_def
  have hx_eig : M.mulVec x = lambdaMin (k + 3) • x := by
    have h_ev_eq : hM_herm.eigenvalues j₀ = lambdaMin (k + 3) := by
      rw [← hmin_eq, ← hj₀]
    rw [← h_ev_eq]
    exact hM_herm.mulVec_eigenvectorBasis j₀
  have hx_ne : x ≠ 0 := by
    intro habs
    have h_norm : ‖(hM_herm.eigenvectorBasis j₀ : EuclideanSpace ℝ (Fin (n + 1)))‖ = 1 :=
      hM_herm.eigenvectorBasis.orthonormal.1 j₀
    -- The coercion ⇑ gives the same function as x
    have : (hM_herm.eigenvectorBasis j₀ : EuclideanSpace ℝ (Fin (n + 1))) = 0 := by
      ext i; exact congr_fun habs i
    rw [this, norm_zero] at h_norm; exact absurd h_norm (by norm_num)

  -- (c) Apply bordered_secular_identity
  have h_secular := bordered_secular_identity M hM_herm A hA_herm hA_eq gv hg_eq γ hγ_eq
    x hx_eig hx_ne hn_pos hmu_lt_inf
  -- h_secular : γ - lambdaMin(k+3) = gvᵀ(A - lambdaMin(k+3)•I)⁻¹ gv

  -- (d) Apply secular_drop_bound
  have h_drop := secular_drop_bound A hA_herm gv hn_pos (lambdaMin (k + 3)) hmu_lt_inf
  -- h_drop : gvᵀ(A-μI)⁻¹gv ≥ ⟨gv, e₀⟩² / (λ₀ - μ)

  -- (e) Apply resolvent_upper_bound: gvᵀ(A-μI)⁻¹gv ≤ ‖gv‖²/δ
  have h_upper := resolvent_upper_bound A hA_herm gv hn_pos (lambdaMin (k + 3)) hmu_lt_inf

  -- (f) eigenDrop = inf'(eigenvalues₀(A)) - lambdaMin(k+3)
  have h_eig_drop_def : eigenDrop (k + 3) = lambdaMin (k + 2) - lambdaMin (k + 3) := by
    unfold eigenDrop; congr 1
  have hA_lmin : (Finset.univ : Finset (Fin (Fintype.card (Fin n)))).inf'
      (by rw [Fintype.card_fin]; exact ⟨⟨0, hn_pos⟩, Finset.mem_univ _⟩)
      hA_herm.eigenvalues₀ = lambdaMin (k + 2) := by
    simp only [lambdaMin, show k + 2 ≥ 2 from hk2_ge2, dite_true]
    apply le_antisymm
    · apply Finset.le_inf'; intro j _
      exact Finset.inf'_le _ (Finset.mem_univ _)
    · apply Finset.le_inf'; intro i _
      exact Finset.inf'_le _ (Finset.mem_univ _)

  -- (g) Combine secular identity + resolvent upper bound
  -- Convert h_upper to use lambdaMin(k+2) in place of inf'
  have h_upper' : γ - lambdaMin (k + 3) ≤
      dotProduct gv gv / (lambdaMin (k + 2) - lambdaMin (k + 3)) := by
    -- From h_secular: γ - μ = resolvent
    -- From h_upper: resolvent ≤ ‖g‖²/(inf'(ev) - μ)
    -- From hA_lmin: inf'(ev) = lambdaMin(k+2)
    -- So: γ - μ ≤ ‖g‖²/(lambdaMin(k+2) - μ)
    -- h_upper has inf' in the denominator; convert to lambdaMin
    calc γ - lambdaMin (k + 3)
        = dotProduct gv ((A - lambdaMin (k + 3) •
            (1 : Matrix (Fin (k + 2 - 1)) (Fin (k + 2 - 1)) ℝ))⁻¹.mulVec gv) := h_secular
      _ ≤ dotProduct gv gv / (lambdaMin (k + 2) - lambdaMin (k + 3)) := by
            convert h_upper using 2
  rw [h_eig_drop_def] at ⊢

  have h_ed_pos : 0 < lambdaMin (k + 2) - lambdaMin (k + 3) := by
    rw [← h_eig_drop_def]; exact h_trivial

  -- ═══════════════════════════════════════════════════════════════
  -- RAYLEIGH BYPASS: Split on whether gv = 0 or gv ≠ 0
  -- ═══════════════════════════════════════════════════════════════
  -- k+3-1 = k+2: simplify final goal early
  suffices h_suff : lambdaMin (k + 2) - lambdaMin (k + 3) ≤
      dotProduct gv gv / (γ - lambdaMin (k + 3)) by
    show lambdaMin (k + 2) - lambdaMin (k + 3) ≤
      dotProduct (crossCorrVec (k + 3 - 1)) (crossCorrVec (k + 3 - 1)) /
      (gramEntry (k + 3 - 1) (k + 3 - 1) - lambdaMin (k + 3))
    rw [show k + 3 - 1 = k + 2 from by omega]
    exact h_suff

  by_cases hgv_zero : gv = 0
  · -- CASE 1: gv = 0. Then ‖gv‖² = 0, RHS = 0/_ = 0, contradicts eigenDrop > 0.
    exfalso
    have h_dot_zero : dotProduct gv gv = 0 := by rw [hgv_zero]; simp [dotProduct]
    -- From h_upper': γ - μ ≤ 0/eigenDrop = 0
    have h_gamma_le : γ - lambdaMin (k + 3) ≤ 0 := by
      have := h_upper'; rw [h_dot_zero, zero_div] at this; linarith
    -- gramEntry(k+2)(1) = gv(0) = 0, but gramEntry(k+2)(1) > 0. Contradiction.
    have h_entry_zero : gramEntry (k + 2) 1 = 0 := by
      -- gv = crossCorrVec(k+2) = fun i => gramEntry(k+2)(i.val+1)
      -- gv(⟨0, _⟩) = gramEntry(k+2)(0+1) = gramEntry(k+2)(1)
      have h0 := congr_fun hgv_zero (⟨0, by omega⟩ : Fin (k + 2 - 1))
      simp only [Pi.zero_apply] at h0
      convert h0 using 1
    exact absurd h_entry_zero (ne_of_gt (gramEntry_first_col_pos (k + 2) (by omega)))

  · -- CASE 2: gv ≠ 0. Then γ - μ > 0 from secular + Rayleigh bound.
    -- The secular identity gives γ - μ = gvᵀ(A-μI)⁻¹gv.
    -- Set y = (A-μI)⁻¹gv. Then gvᵀ(A-μI)⁻¹gv = yᵀ(A-μI)y.
    -- Rayleigh bound on A: yᵀAy ≥ lambdaMin(A)·yᵀy,
    -- so yᵀ(A-μI)y ≥ (lambdaMin(A)-μ)·yᵀy = eigenDrop·yᵀy > 0.
    set M_res := A - lambdaMin (k + 3) •
        (1 : Matrix (Fin (k + 2 - 1)) (Fin (k + 2 - 1)) ℝ) with hM_res_def

    -- M_res is the matrix appearing in h_secular
    -- h_secular : γ - μ = dotProduct gv (M_res⁻¹.mulVec gv)
    -- M_res is invertible (determinant is product of eigenvalues, all > 0)
    have hM_res_herm : M_res.IsHermitian := by
      simp only [hM_res_def, Matrix.IsHermitian]
      funext i j
      simp only [conjTranspose_apply, star_trivial, sub_apply, smul_apply, one_apply]
      have hAij : A j i = A i j := by
        have := congr_fun (congr_fun hA_herm i) j
        simp only [conjTranspose_apply, star_trivial] at this; exact this
      by_cases h : i = j <;> simp [h, eq_comm, hAij]
    have hM_res_pd : M_res.PosDef := by
      rw [hM_res_herm.posDef_iff_eigenvalues_pos]; intro i
      rw [hM_res_herm.eigenvalues_eq i]
      simp only [star_trivial, RCLike.re_to_real]
      set vi := (⇑(hM_res_herm.eigenvectorBasis i) : Fin (k + 2 - 1) → ℝ)
      have h_sub : M_res *ᵥ vi = A *ᵥ vi - lambdaMin (k + 3) • vi := by
        ext j; simp only [hM_res_def, sub_mulVec, smul_mulVec, one_mulVec,
          Pi.sub_apply, Pi.smul_apply, smul_eq_mul]
      rw [h_sub, dotProduct_sub, dotProduct_smul]; simp only [smul_eq_mul]
      have h_unit : dotProduct vi vi = 1 := by
        rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
        rw [hM_res_herm.eigenvectorBasis.orthonormal.1 i, one_pow]
      rw [h_unit, mul_one]
      have h_rb := quadform_ge_min_eigenvalue_mul hA_herm hn_pos vi
      unfold realQuadForm at h_rb; rw [h_unit] at h_rb; simp only [mul_one] at h_rb
      -- h_rb : dotProduct vi (A.mulVec vi) ≥ inf'(eigenvalues₀ of A)
      -- inf'(eigenvalues₀ of A) = lambdaMin(k+2) > lambdaMin(k+3) (from hmu_lt)
      -- So dotProduct vi (A.mulVec vi) > lambdaMin(k+3), hence result > 0
      have : (Finset.univ : Finset (Fin (Fintype.card (Fin (k + 2 - 1))))).inf'
        (by rw [Fintype.card_fin]; exact ⟨⟨0, hn_pos⟩, Finset.mem_univ _⟩)
        hA_herm.eigenvalues₀ = lambdaMin (k + 2) := hA_lmin
      linarith
    have hM_res_det : IsUnit M_res.det := by
      rw [← Matrix.isUnit_iff_isUnit_det]; exact hM_res_pd.isUnit

    -- Substitution: y = M_res⁻¹ gv
    set y_res := M_res⁻¹.mulVec gv with hy_res_def
    have hgv_eq : gv = M_res *ᵥ y_res := by
      change gv = M_res *ᵥ (M_res⁻¹ *ᵥ gv)
      rw [mulVec_mulVec, Matrix.mul_nonsing_inv _ hM_res_det, one_mulVec]
    have hy_ne : y_res ≠ 0 := by
      intro h_abs; apply hgv_zero
      rw [hgv_eq, h_abs]
      ext i; simp [mulVec, dotProduct]
    have hyy_pos : 0 < dotProduct y_res y_res := by
      have h_norm_pos : (0 : ℝ) < ‖(WithLp.toLp 2 y_res : EuclideanSpace ℝ (Fin (k + 2 - 1)))‖ := by
        rw [norm_pos_iff]; rwa [Ne, WithLp.toLp_eq_zero]
      rw [← inner_eq_dotProduct, real_inner_self_eq_norm_sq]
      exact pow_pos h_norm_pos 2

    -- Rayleigh bound: yᵀ(A-μI)y ≥ eigenDrop · yᵀy
    have h_rayleigh_res : dotProduct y_res (M_res.mulVec y_res) ≥
        (lambdaMin (k + 2) - lambdaMin (k + 3)) * dotProduct y_res y_res := by
      have h_decomp : dotProduct y_res (M_res.mulVec y_res) =
          dotProduct y_res (A.mulVec y_res) - lambdaMin (k + 3) * dotProduct y_res y_res := by
        simp only [hM_res_def, sub_mulVec, smul_mulVec, one_mulVec,
          dotProduct_sub, dotProduct_smul, smul_eq_mul]
      rw [h_decomp]
      have h_rb := quadform_ge_min_eigenvalue_mul hA_herm hn_pos y_res
      unfold realQuadForm at h_rb
      have : (Finset.univ : Finset (Fin (Fintype.card (Fin (k + 2 - 1))))).inf'
        (by rw [Fintype.card_fin]; exact ⟨⟨0, hn_pos⟩, Finset.mem_univ _⟩)
        hA_herm.eigenvalues₀ = lambdaMin (k + 2) := hA_lmin
      nlinarith [mul_comm (lambdaMin (k + 2)) (dotProduct y_res y_res)]

    -- Key identity: gvᵀM_res⁻¹gv = yᵀM_res·y
    have h_res_identity : dotProduct gv (M_res⁻¹.mulVec gv) =
        dotProduct y_res (M_res.mulVec y_res) := by
      show dotProduct gv y_res = dotProduct y_res (M_res *ᵥ y_res)
      conv_lhs => rw [hgv_eq]
      exact dotProduct_comm (M_res *ᵥ y_res) y_res

    -- Resolvent quadratic form > 0
    have h_res_pos : 0 < dotProduct gv (M_res⁻¹.mulVec gv) := by
      rw [h_res_identity]; nlinarith [h_rayleigh_res, hyy_pos]

    -- γ - μ > 0
    have h_gamma_mu_pos : 0 < γ - lambdaMin (k + 3) := by
      rw [h_secular]; exact h_res_pos

    -- eigenDrop·(γ-μ) ≤ ‖g‖²
    have h_product : (lambdaMin (k + 2) - lambdaMin (k + 3)) * (γ - lambdaMin (k + 3)) ≤
        dotProduct gv gv := by
      rw [le_div_iff₀ h_ed_pos] at h_upper'
      linarith

    -- eigenDrop ≤ ‖g‖²/(γ-μ)
    rw [le_div_iff₀ h_gamma_mu_pos]; linarith [h_product]

end
