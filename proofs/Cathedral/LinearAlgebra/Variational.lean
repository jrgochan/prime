/-
  Cathedral/LinearAlgebra/Variational.lean

  ## The Variational Principle (Abstract)

  For a positive semidefinite Hermitian matrix G with invertible determinant,
  and any vectors b, v:
    d² ≤ 1 - 2bᵀv + vᵀGv  (variational upper bound)

  And in Rayleigh quotient form:
    (bᵀv)² / (vᵀGv) ≤ bᵀG⁻¹b

  Adapted from the archived QuadFormBridge.lean (zero sorry).

  Created: April 10, 2026 (Reintegration)
-/

import Mathlib.LinearAlgebra.Matrix.DotProduct
import Mathlib.LinearAlgebra.Matrix.NonsingularInverse
import Mathlib.LinearAlgebra.Matrix.PosDef
import Mathlib.Data.Matrix.Basic

noncomputable section
open Matrix Finset

namespace Cathedral.Variational

variable {n : ℕ}

-- ════════════════════════════════════════════════
-- PART I: ABSTRACT QUADRATIC FORM TOOLS
-- ════════════════════════════════════════════════

/-- The real quadratic form xᵀAx. -/
def realQuadForm (A : Matrix (Fin n) (Fin n) ℝ) (x : Fin n → ℝ) : ℝ :=
  dotProduct x (A.mulVec x)

-- ════════════════════════════════════════════════
-- PART II: THE VARIATIONAL BOUND (from QuadFormBridge)
-- ════════════════════════════════════════════════

/-- **THE ABSTRACT VARIATIONAL PRINCIPLE.**

    For a positive semidefinite Hermitian matrix G with invertible determinant,
    and ANY test vector v:

      bᵀG⁻¹b ≥ 2·bᵀv - vᵀGv

    Proof: expand (v - G⁻¹b)ᵀG(v - G⁻¹b) ≥ 0.

    Adapted from QuadFormBridge.nbDistSq_le_test_vector (zero sorry). -/
theorem variational_bound
    (G : Matrix (Fin n) (Fin n) ℝ) (b v : Fin n → ℝ)
    (hH : G.IsHermitian) (hPSD : G.PosSemidef)
    (h_unit : IsUnit G.det) :
    realQuadForm G v - 2 * dotProduct b v +
      dotProduct b (G⁻¹.mulVec b) ≥ 0 := by
  set c := G⁻¹.mulVec b with hc_def
  have h_Gc : G.mulVec c = b := by
    rw [hc_def, Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit,
        Matrix.one_mulVec]
  -- Key: (v - c)ᵀ G (v - c) ≥ 0 by PSD
  have h_psd := hPSD.dotProduct_mulVec_nonneg (v - c)
  simp only [star_trivial] at h_psd
  -- Expand: (v-c)ᵀG(v-c) = vᵀGv - 2·vᵀGc + cᵀGc
  have h_expand : dotProduct (v - c) (G.mulVec (v - c)) =
      realQuadForm G v - 2 * dotProduct v (G.mulVec c) +
      realQuadForm G c := by
    unfold realQuadForm
    simp only [Matrix.mulVec_sub, sub_dotProduct, dotProduct_sub]
    have h_sym : dotProduct c (G.mulVec v) = dotProduct v (G.mulVec c) := by
      simp only [dotProduct, Matrix.mulVec] at *
      simp_rw [Finset.mul_sum]
      rw [Finset.sum_comm]
      congr 1; ext j; congr 1; ext i
      have hij : G i j = G j i := by
        have := congr_fun (congr_fun hH i) j
        simp [Matrix.conjTranspose_apply, star_trivial] at this
        exact this.symm
      ring_nf; rw [hij]; ring
    linarith
  -- Substitute Gc = b into the expansion
  rw [h_Gc] at h_expand
  have h_cb : realQuadForm G c = dotProduct b c := by
    unfold realQuadForm; rw [h_Gc]; exact dotProduct_comm c b
  have h_bc : dotProduct b c = dotProduct b (G⁻¹.mulVec b) := by
    rw [hc_def]
  have h_vb : dotProduct v b = dotProduct b v := dotProduct_comm v b
  rw [h_cb, h_bc, h_vb] at h_expand
  linarith

-- ════════════════════════════════════════════════
-- PART III: CAUCHY-SCHWARZ FOR QUADRATIC FORMS
-- ════════════════════════════════════════════════

/-- **Cauchy-Schwarz for positive semidefinite matrices.**

    (bᵀv)² ≤ (vᵀGv) · (bᵀG⁻¹b)

    Proof: apply PSD to the vector w = (vᵀGv)·G⁻¹b - (bᵀv)·v.
    Then wᵀGw = (vᵀGv)·((vᵀGv)·(bᵀG⁻¹b) - (bᵀv)²) ≥ 0.
    Since vᵀGv > 0, divide to get the result. -/
theorem cauchy_schwarz_quadform
    (G : Matrix (Fin n) (Fin n) ℝ) (b v : Fin n → ℝ)
    (hH : G.IsHermitian) (hPSD : G.PosSemidef)
    (h_unit : IsUnit G.det)
    (hv_pos : realQuadForm G v > 0) :
    (dotProduct b v) ^ 2 ≤
    realQuadForm G v * dotProduct b (G⁻¹.mulVec b) := by
  -- Use the variational bound: vᵀGv - 2bᵀv + bᵀG⁻¹b ≥ 0
  have h_var := variational_bound G b v hH hPSD h_unit
  -- Apply PSD to the scaled vector: (bᵀv)·G⁻¹b - v
  set c := G⁻¹.mulVec b
  have h_Gc : G.mulVec c = b := by
    rw [Matrix.mulVec_mulVec, Matrix.mul_nonsing_inv _ h_unit, Matrix.one_mulVec]
  -- PSD applied to w = (bᵀv)·c - v:
  -- wᵀGw = (bᵀv)²·cᵀGc - 2(bᵀv)·vᵀGc + vᵀGv
  --       = (bᵀv)²·(bᵀG⁻¹b) - 2(bᵀv)² + vᵀGv ≥ 0
  have h_w := hPSD.dotProduct_mulVec_nonneg (dotProduct b v • c - v)
  -- Remove star (trivial for ℝ)
  simp only [star_trivial] at h_w
  -- Manually expand wᵀGw
  -- Need symmetry: cᵀGv = vᵀGc = vᵀb (since Gc = b)
  have h_cGv : dotProduct c (G.mulVec v) = dotProduct v (G.mulVec c) := by
    simp only [dotProduct, Matrix.mulVec] at *
    simp_rw [Finset.mul_sum]
    rw [Finset.sum_comm]
    congr 1; ext j; congr 1; ext i
    have hij : G i j = G j i := by
      have := congr_fun (congr_fun hH i) j
      simp [Matrix.conjTranspose_apply, star_trivial] at this
      exact this.symm
    ring_nf; rw [hij]; ring
  have h_expand_w : dotProduct (dotProduct b v • c - v)
      (G.mulVec (dotProduct b v • c - v)) =
      (dotProduct b v)^2 * dotProduct c b -
      2 * dotProduct b v * dotProduct v b +
      realQuadForm G v := by
    unfold realQuadForm
    simp only [Matrix.mulVec_sub, Matrix.mulVec_smul,
      sub_dotProduct, dotProduct_sub, smul_dotProduct, dotProduct_smul]
    rw [h_Gc, h_cGv, h_Gc]
    ring
  have h_comm : dotProduct v b = dotProduct b v := dotProduct_comm v b
  have h_cb : dotProduct c b = dotProduct b c := dotProduct_comm c b
  rw [h_expand_w] at h_w
  rw [h_comm, h_cb] at h_w
  -- Now h_w : 0 ≤ (bᵀv)²·(bᵀc) - 2(bᵀv)² + vᵀGv
  -- Apply PSD to w = a·c - x·v where a = vᵀGv, x = bᵀv
  -- wᵀGw = a²·cᵀGc - 2ax·vᵀGc + x²·vᵀGv
  --       = a²·B - 2ax² + x²·a  (since Gc=b, so cᵀGc=bᵀc=B, vᵀGc=vᵀb=bᵀv=x)
  --       = a·(aB - x²) ≥ 0
  -- Since a > 0: aB ≥ x²
  have h_w2 := hPSD.dotProduct_mulVec_nonneg
    (realQuadForm G v • c - dotProduct b v • v)
  simp only [star_trivial] at h_w2
  have h_expand_w2 : dotProduct (realQuadForm G v • c - dotProduct b v • v)
      (G.mulVec (realQuadForm G v • c - dotProduct b v • v)) =
      (realQuadForm G v)^2 * dotProduct c b -
      2 * realQuadForm G v * dotProduct b v * dotProduct v b +
      (dotProduct b v)^2 * realQuadForm G v := by
    unfold realQuadForm
    simp only [Matrix.mulVec_sub, Matrix.mulVec_smul,
      sub_dotProduct, dotProduct_sub, smul_dotProduct, dotProduct_smul]
    rw [h_Gc, h_cGv, h_Gc]
    ring
  rw [h_expand_w2, h_comm, h_cb] at h_w2
  -- h_w2 : 0 ≤ a²·B - 2a·x² + x²·a = a·(aB - 2x² + x²) ... wait
  -- Actually: a²B - 2ax² + x²a = a(aB - 2x² + x²) = a(aB - x²)
  -- No: a²B - 2ax·x + x²·a = a(aB - x²)... let me check:
  -- a²B - 2a·x² + x²·a = a²B - 2ax² + ax² = a²B - ax² = a(aB - x²)
  -- So h_w2 : 0 ≤ a(aB - x²)
  -- Since a > 0: aB - x² ≥ 0, so x² ≤ aB. Done!
  nlinarith [hv_pos]

/-- For a PSD Hermitian matrix with invertible determinant, xᵀGx > 0 for any x ≠ 0.
    This is the key bridge from PSD + invertible to PosDef behavior on (Fin n → ℝ).
    Proof: xᵀGx = 0 implies Gx = 0 (by PSD polarization), but G invertible means
    Gx = 0 → x = 0, contradicting x ≠ 0. -/
theorem posSemidef_pos_of_ne_zero {n : ℕ} (G : Matrix (Fin n) (Fin n) ℝ)
    (hH : G.IsHermitian) (hPSD : G.PosSemidef) (h_unit : IsUnit G.det)
    (x : Fin n → ℝ) (hx : x ≠ 0) :
    dotProduct x (G.mulVec x) > 0 := by
  have h_nn := hPSD.dotProduct_mulVec_nonneg x
  simp only [star_trivial] at h_nn
  rcases lt_or_eq_of_le h_nn with h_pos | h_eq
  · exact h_pos
  · exfalso
    -- xᵀGx = 0. Show Gx = 0 by showing (Gx)ᵢ = 0 for each i.
    suffices h_Gx : G.mulVec x = 0 by
      have h_isUnit : IsUnit G := G.isUnit_iff_isUnit_det.mpr h_unit
      have h_inj := Matrix.mulVec_injective_of_isUnit h_isUnit
      exact hx (h_inj (by rw [h_Gx, Matrix.mulVec_zero]))
    funext i
    simp only [Pi.zero_apply]
    by_contra h_ne_i
    -- Define standard basis vector explicitly
    let ei : Fin n → ℝ := Pi.single i 1
    -- PSD on (x + t·eᵢ) for all t
    have h_psd_t := fun (t : ℝ) => hPSD.dotProduct_mulVec_nonneg (x + t • ei)
    simp only [star_trivial] at h_psd_t
    -- Expand (x + t·eᵢ)ᵀG(x + t·eᵢ)
    have h_expand : ∀ t : ℝ,
        dotProduct (x + t • ei) (G.mulVec (x + t • ei)) =
        dotProduct x (G.mulVec x) +
        2 * t * dotProduct ei (G.mulVec x) +
        t ^ 2 * dotProduct ei (G.mulVec ei) := by
      intro t
      simp only [Matrix.mulVec_add, Matrix.mulVec_smul,
        add_dotProduct, dotProduct_add, smul_dotProduct, dotProduct_smul]
      have h_comm : dotProduct x (G.mulVec ei) =
          dotProduct ei (G.mulVec x) := by
        simp only [dotProduct, Matrix.mulVec] at *
        simp_rw [Finset.mul_sum]
        rw [Finset.sum_comm]
        congr 1; ext j; congr 1; ext k
        have hkj : G k j = G j k := by
          have := congr_fun (congr_fun hH k) j
          simp [Matrix.conjTranspose_apply, star_trivial] at this
          exact this.symm
        ring_nf; rw [hkj]; ring
      -- After simp: LHS has t*(ei.Gx) + t*(x.Gei + t*(ei.Gei))
      -- Need: = 2*t*(ei.Gx) + t^2*(ei.Gei)
      -- Substitute h_comm: x.Gei = ei.Gx, then expand
      rw [h_comm]; ring
    -- eᵢᵀGx = (Gx)ᵢ
    have h_dot_ei : dotProduct ei (G.mulVec x) = (G.mulVec x) i := by
      unfold dotProduct ei
      rw [Finset.sum_eq_single i]
      · simp [Pi.single]
      · intro j _ hji; simp [Pi.single, hji]
      · intro h; exact absurd (Finset.mem_univ i) h
    -- (Gx)ᵢ ≠ 0
    have h_Gx_ne : (G.mulVec x) i ≠ 0 := h_ne_i
    -- eᵢᵀGeᵢ ≥ 0
    have h_Gii := hPSD.dotProduct_mulVec_nonneg ei
    simp only [star_trivial] at h_Gii
    -- From PSD: ∀ t, 0 + 2t·c + t²·a ≥ 0 (where c = (Gx)ᵢ, a = eᵢᵀGeᵢ)
    set c := (G.mulVec x) i with hc_def
    set a := dotProduct ei (G.mulVec ei) with ha_def
    -- Every t satisfies the bound
    have h_bound : ∀ t : ℝ, 0 ≤ 2 * t * c + t ^ 2 * a := by
      intro t
      have := h_psd_t t
      rw [h_expand t, ← h_eq, h_dot_ei] at this
      linarith
    -- Discriminant argument: if a = 0 then 2tc ≥ 0 for all t → c = 0
    -- If a > 0: min at t = -c/a gives -c²/a ≥ 0 → c = 0
    rcases eq_or_ne a 0 with ha0 | ha_ne
    · -- a = 0: bound is 2tc ≥ 0 for all t
      have h1 := h_bound 1
      have h2 := h_bound (-1)
      rw [ha0] at h1 h2; simp at h1 h2
      have hc_le : c ≤ 0 := by linarith
      have hc_ge : c ≥ 0 := by linarith
      exact h_Gx_ne (le_antisymm hc_le hc_ge)
    · -- a > 0 by PSD
      have ha_pos : a > 0 := lt_of_le_of_ne h_Gii (Ne.symm ha_ne)
      have h_at_min := h_bound (-c / a)
      have h_c_sq : c ^ 2 ≤ 0 := by
        -- multiply h_bound by a and evaluate at t = -c/a
        -- a * (2*(-c/a)*c + (-c/a)² * a) = 2*(-c)*c + c² = -2c² + c² = -c²
        -- Since the original is ≥ 0 and a > 0, we get -c² ≥ 0.
        have h_base := h_at_min
        -- Directly: 0 ≤ 2·(-c/a)·c + (-c/a)²·a
        -- Simplify: (-c/a)²·a = c²/a and 2·(-c/a)·c = -2c²/a
        -- So 0 ≤ -c²/a. Multiply by a > 0: 0 ≤ -c².
        have h_simp : 2 * (-c / a) * c + (-c / a) ^ 2 * a = -(c ^ 2) / a := by
          field_simp; ring
        rw [h_simp] at h_base
        -- h_base : 0 ≤ -(c²)/a, with a > 0
        -- So -(c²)/a ≥ 0, and (-c²)/a = -(c²/a), meaning c²/a ≤ 0
        -- Since a > 0: c² ≤ 0
        have h_neg_div : -(c ^ 2) / a ≥ 0 := h_base
        have h_neg : -(c ^ 2) ≥ 0 := nonneg_of_mul_nonneg_left
          (by rwa [div_eq_mul_inv, mul_comm] at h_neg_div) (inv_pos.mpr ha_pos)
        linarith
      exact h_Gx_ne (by nlinarith [sq_nonneg c])

-- ════════════════════════════════════════════════
-- SECTION 4: RANK-1 MATRIX PROPERTIES
-- ════════════════════════════════════════════════

/-- The rank-1 matrix bbᵀ = vecMulVec b b is Hermitian (symmetric over ℝ). -/
theorem vecMulVec_self_hermitian (b : Fin n → ℝ) :
    (vecMulVec b b).IsHermitian := by
  ext i j
  simp [vecMulVec, conjTranspose_apply, star_trivial, mul_comm]

/-- The rank-1 matrix bbᵀ is positive semidefinite.
    Proof: xᵀ(bbᵀ)x = (bᵀx)² ≥ 0. -/
theorem vecMulVec_self_posSemidef (b : Fin n → ℝ) :
    (vecMulVec b b).PosSemidef := by
  refine ⟨vecMulVec_self_hermitian b, fun x => ?_⟩
  simp only [star_trivial, vecMulVec, Matrix.of_apply]
  -- Goal involves Finsupp.sum over (i,j): xᵢ * (bᵢ * bⱼ) * xⱼ
  -- This equals (Σᵢ xᵢ * bᵢ)² ≥ 0
  -- Use dotProduct_mulVec_nonneg-like approach
  -- Actually, let's just compute from mulVec and dotProduct
  have h_eq : x.sum (fun i xi => x.sum (fun j xj =>
      xi * (b i * b j) * xj)) =
      (x.sum (fun i xi => xi * b i)) ^ 2 := by
    simp only [sq, Finsupp.sum_mul, mul_assoc]
    congr 1
    ext i
    simp only [← mul_assoc, Finsupp.mul_sum]
    congr 1
    ext j
    ring
  rw [h_eq]
  exact sq_nonneg _

-- ════════════════════════════════════════════════
-- SECTION 5: SCHUR COMPLEMENT (1×1 BLOCK)
-- ════════════════════════════════════════════════

/-- **The Schur Complement Theorem (1×1 top-left block).**

    If G is positive definite and bᵀG⁻¹b < 1, then
    C = G - bbᵀ is positive definite.

    This provides a reduction path for the PosDef axiom:
    - If G is PD (Gram matrix of L² basis functions)
    - And bᵀG⁻¹b < 1 (i.e., d²_N > 0 via Sherman-Morrison)
    - Then C = G - bbᵀ is PD. ∎

    The proof uses our Cauchy-Schwarz result to show that
    (bᵀx)² ≤ (bᵀG⁻¹b)(xᵀGx), so
    xᵀCx = xᵀGx - (bᵀx)² ≥ (1 - bᵀG⁻¹b)·xᵀGx > 0. -/
theorem schur_complement_posDef
    (G : Matrix (Fin n) (Fin n) ℝ)
    (b : Fin n → ℝ)
    (hG : G.PosDef)
    (h_schur : dotProduct b (G⁻¹.mulVec b) < 1) :
    (G - vecMulVec b b).PosDef := by
  -- Step 1: Hermitian
  have h_herm : (G - vecMulVec b b).IsHermitian :=
    hG.isHermitian.sub (vecMulVec_self_hermitian b)
  -- Step 2: Use of_dotProduct_mulVec_pos
  exact Matrix.PosDef.of_dotProduct_mulVec_pos h_herm fun {x} hx => by
    simp only [star_trivial]
    -- We need: 0 < x ⬝ᵥ (G - bbᵀ) *ᵥ x
    rw [Matrix.sub_mulVec, dotProduct_sub]
    -- x ⬝ᵥ G *ᵥ x > 0 (from G PosDef)
    have h_Gx_pos : 0 < dotProduct x (G.mulVec x) := by
      have := hG.dotProduct_mulVec_pos hx
      simpa [star_trivial] using this
    -- x ⬝ᵥ (bbᵀ) *ᵥ x = (b ⬝ᵥ x)²
    have h_bb_eq : dotProduct x ((vecMulVec b b).mulVec x) =
        (dotProduct b x) ^ 2 := by
      have h_mul : (vecMulVec b b).mulVec x = (dotProduct b x) • b := by
        ext i; simp only [mulVec, vecMulVec, dotProduct, Finset.sum_mul,
          Matrix.of_apply, Pi.smul_apply, smul_eq_mul]
        congr 1; ext j; ring
      rw [h_mul, dotProduct_smul, smul_eq_mul]
      rw [show dotProduct x b = dotProduct b x from by
        simp [dotProduct]; congr 1; ext; exact mul_comm _ _]
      ring
    rw [h_bb_eq]
    -- Cauchy-Schwarz: (b ⬝ᵥ x)² / (x ⬝ᵥ Gx) ≤ b ⬝ᵥ G⁻¹b
    have h_unit : IsUnit G.det :=
      G.isUnit_iff_isUnit_det.mp hG.isUnit
    have h_cs := cauchy_schwarz_quadform G b x
      hG.isHermitian hG.posSemidef h_unit h_Gx_pos
    have h_cs_bound : (dotProduct b x) ^ 2 ≤
        dotProduct b (G⁻¹.mulVec b) * dotProduct x (G.mulVec x) := by
      rw [show dotProduct b (G⁻¹.mulVec b) * dotProduct x (G.mulVec x) =
          realQuadForm G x * dotProduct b (G⁻¹.mulVec b) from mul_comm _ _]
      exact h_cs
    nlinarith

-- ════════════════════════════════════════════════
-- SECTION 6: 3×3 SYLVESTER CRITERION
-- ════════════════════════════════════════════════

/-- **3×3 Sylvester criterion via completing the square.**
    For a Hermitian 3×3 matrix M with positive leading minors, M is positive definite.

    Proof: The CTS algebraic identity (verified by `ring`):
      a·det₂·(xᵀMx) = det₂·(a·x₀+b·x₁+c·x₂)²
                      + (det₂·x₁+(ae-bc)·x₂)²
                      + a·det(M)·x₂²

    where a = M(0,0), det₂ = a·M(1,1) - M(0,1)².
    Since a > 0 and det₂ > 0, the LHS shares sign with xᵀMx.
    The RHS is a sum of non-negative terms, each with a positive coefficient.
    If x ≠ 0: x₂ ≠ 0 → third term > 0; or x₂ = 0, x₁ ≠ 0 → second term > 0;
    or x₁ = x₂ = 0, x₀ ≠ 0 → first term > 0. In all cases xᵀMx > 0. -/
theorem sylvester_3x3
    (M : Matrix (Fin 3) (Fin 3) ℝ)
    (hH : M.IsHermitian)
    (h1 : M 0 0 > 0)
    (h2 : M 0 0 * M 1 1 - M 0 1 ^ 2 > 0)
    (h3 : M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
          M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
          M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2) > 0) :
    M.PosDef := by
  have hM10 : M 1 0 = M 0 1 := by
    have := congr_fun (congr_fun hH 1) 0; simp [conjTranspose_apply, star_trivial] at this; exact this.symm
  have hM20 : M 2 0 = M 0 2 := by
    have := congr_fun (congr_fun hH 2) 0; simp [conjTranspose_apply, star_trivial] at this; exact this.symm
  have hM21 : M 2 1 = M 1 2 := by
    have := congr_fun (congr_fun hH 2) 1; simp [conjTranspose_apply, star_trivial] at this; exact this.symm
  exact PosDef.of_dotProduct_mulVec_pos hH fun {x} hx => by
    simp only [star_trivial]
    have h_expand : dotProduct x (M.mulVec x) =
        M 0 0 * x 0 ^ 2 + M 1 1 * x 1 ^ 2 + M 2 2 * x 2 ^ 2 +
        2 * M 0 1 * x 0 * x 1 + 2 * M 0 2 * x 0 * x 2 + 2 * M 1 2 * x 1 * x 2 := by
      simp only [dotProduct, mulVec, Fin.sum_univ_three, Fin.isValue]
      rw [hM10, hM20, hM21]; ring
    rw [h_expand]
    have h_cts :
        M 0 0 * (M 0 0 * M 1 1 - M 0 1 ^ 2) *
          (M 0 0 * x 0 ^ 2 + M 1 1 * x 1 ^ 2 + M 2 2 * x 2 ^ 2 +
          2 * M 0 1 * x 0 * x 1 + 2 * M 0 2 * x 0 * x 2 + 2 * M 1 2 * x 1 * x 2) =
        (M 0 0 * M 1 1 - M 0 1 ^ 2) * (M 0 0 * x 0 + M 0 1 * x 1 + M 0 2 * x 2) ^ 2 +
        ((M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 + (M 0 0 * M 1 2 - M 0 1 * M 0 2) * x 2) ^ 2 +
        M 0 0 * (M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
          M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
          M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2)) * x 2 ^ 2 := by ring
    have had : (0 : ℝ) < M 0 0 * (M 0 0 * M 1 1 - M 0 1 ^ 2) := mul_pos h1 h2
    by_contra h_neg
    push Not at h_neg
    have h_scaled := mul_nonpos_of_nonneg_of_nonpos (le_of_lt had) h_neg
    have h_rhs_le : (M 0 0 * M 1 1 - M 0 1 ^ 2) * (M 0 0 * x 0 + M 0 1 * x 1 + M 0 2 * x 2) ^ 2 +
        ((M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 + (M 0 0 * M 1 2 - M 0 1 * M 0 2) * x 2) ^ 2 +
        M 0 0 * (M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
          M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
          M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2)) * x 2 ^ 2 ≤ 0 := by linarith
    have ht1 : (0 : ℝ) ≤ (M 0 0 * M 1 1 - M 0 1 ^ 2) * (M 0 0 * x 0 + M 0 1 * x 1 + M 0 2 * x 2) ^ 2 :=
      mul_nonneg (le_of_lt h2) (sq_nonneg _)
    have ht2 : (0 : ℝ) ≤ ((M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 + (M 0 0 * M 1 2 - M 0 1 * M 0 2) * x 2) ^ 2 :=
      sq_nonneg _
    have ht3 : (0 : ℝ) ≤ M 0 0 * (M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
        M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
        M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2)) * x 2 ^ 2 :=
      mul_nonneg (mul_nonneg (le_of_lt h1) (le_of_lt h3)) (sq_nonneg _)
    have heq1 : (M 0 0 * M 1 1 - M 0 1 ^ 2) * (M 0 0 * x 0 + M 0 1 * x 1 + M 0 2 * x 2) ^ 2 = 0 := by linarith
    have heq2 : ((M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 + (M 0 0 * M 1 2 - M 0 1 * M 0 2) * x 2) ^ 2 = 0 := by linarith
    have heq3 : M 0 0 * (M 0 0 * (M 1 1 * M 2 2 - M 1 2 ^ 2) -
        M 0 1 * (M 0 1 * M 2 2 - M 1 2 * M 0 2) +
        M 0 2 * (M 0 1 * M 1 2 - M 1 1 * M 0 2)) * x 2 ^ 2 = 0 := by linarith
    have hx2 : x 2 = 0 := by
      by_contra h; exact absurd heq3 (ne_of_gt (mul_pos (mul_pos h1 h3) (sq_pos_of_ne_zero h)))
    have hx1 : x 1 = 0 := by
      rw [hx2, mul_zero, add_zero] at heq2
      have h_sq : (M 0 0 * M 1 1 - M 0 1 ^ 2) * x 1 = 0 := sq_eq_zero_iff.mp heq2
      exact (mul_eq_zero.mp h_sq).resolve_left (ne_of_gt h2)
    have hx0 : x 0 = 0 := by
      rw [hx1, hx2, mul_zero, add_zero, mul_zero, add_zero] at heq1
      have h_sq := (mul_eq_zero.mp heq1).resolve_left (ne_of_gt h2)
      have h_prod : M 0 0 * x 0 = 0 := sq_eq_zero_iff.mp h_sq
      exact (mul_eq_zero.mp h_prod).resolve_left (ne_of_gt h1)
    apply hx; ext i; fin_cases i <;> simp_all

end Cathedral.Variational
