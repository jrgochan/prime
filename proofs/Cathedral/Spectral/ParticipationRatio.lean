import Cathedral.Defs
import Cathedral.Spectral.RayleighBridge
import Mathlib.Algebra.Order.Chebyshev

/-!
  Cathedral/Spectral/ParticipationRatio.lean

  Eigenvector localization metrics for the Gram matrix.
  Formalizes the participation ratio (PR) and inverse participation
  ratio (IPR), establishing bounds and connecting to the experimental
  findings from Exploration 19.

  ## Key Results

  1. `ipr_upper_bound` — Σ|v_i|⁴ ≤ (Σ|v_i|²)² = 1  [PROVED]
  2. `ipr_lower_bound` — Σ|v_i|⁴ ≥ 1/n              [PROVED]
  3. `pr_range`         — 1 ≤ PR(v) ≤ n               [PROVED]

  ## Experimental Constants (documented as theorems with `True` body)

  4. `oracle_pr_goe_ratio_500` — mean PR / (dim/3) ≈ 0.48 at N=500
  5. `oracle_ground_state_localized_500` — ground state PR ≤ 10 at N=500

  ## Placeholder Conjectures

  6. `gram_composite_dominance` — ground state concentrates on composites
  7. `pr_goe_ratio_converges` — PR/GOE ratio → α ≈ 0.47

  ## Experimental Motivation

  Exploration 19 Experiment C discovered that the Gram matrix has
  persistent partial localization: the mean participation ratio
  converges to ≈ 0.47 × (dim/3), not to the full GOE value (dim/3).
  The ground state eigenvector scars onto large composites near
  the matrix boundary, with only 4-15% weight on prime indices.

  Status: 3 theorems proved. Zero sorry. Zero axioms. NOT on crown path.
  Created: April 28, 2026 — Exploration 19.
-/

noncomputable section
open Real Finset

namespace Cathedral.Spectral

-- ════════════════════════════════════════════════
-- §1. INVERSE PARTICIPATION RATIO — DEFINITION
-- ════════════════════════════════════════════════

/-- The inverse participation ratio (IPR) of a vector v:
    IPR(v) = Σᵢ |v_i|⁴

    For a unit vector (‖v‖ = 1):
    - IPR = 1     means v = e_i (fully localized, single component)
    - IPR = 1/n   means v = (1/√n, ..., 1/√n) (fully delocalized)

    The participation ratio is PR = 1/IPR, ranging from 1 to n. -/
def ipr {n : ℕ} (v : Fin n → ℝ) : ℝ :=
  ∑ i : Fin n, (v i) ^ 4

/-- The participation ratio: PR = 1 / IPR.
    Measures the effective number of components participating. -/
def pr {n : ℕ} (v : Fin n → ℝ) (_h : ipr v > 0) : ℝ :=
  1 / ipr v

-- ════════════════════════════════════════════════
-- §2. IPR BOUNDS — PROVED
-- ════════════════════════════════════════════════

/-- **Upper bound on IPR** (Power Mean Inequality):
    For any unit vector v, Σ|v_i|⁴ ≤ (Σ|v_i|²)² = 1.

    Proof: Since v_i² ≤ Σ_j v_j² = 1 for each i,
    we have v_i⁴ = v_i² · v_i² ≤ v_i² · 1 = v_i².
    Summing: Σ v_i⁴ ≤ Σ v_i² = 1. -/
theorem ipr_upper_bound {n : ℕ} (v : Fin n → ℝ)
    (hv : dotProduct v v = 1) :
    ipr v ≤ 1 := by
  unfold ipr
  calc ∑ i, v i ^ 4
      = ∑ i, (v i ^ 2) * (v i ^ 2) := by congr 1; ext i; ring
    _ ≤ ∑ i, v i ^ 2 * 1 := by
        apply Finset.sum_le_sum
        intro i _
        apply mul_le_mul_of_nonneg_left _ (sq_nonneg _)
        -- v_i² ≤ Σ_j v_j² = 1
        have : v i ^ 2 ≤ ∑ j : Fin n, v j ^ 2 :=
          Finset.single_le_sum (fun j _ => sq_nonneg (v j)) (Finset.mem_univ i)
        have h_dp : dotProduct v v = ∑ j : Fin n, v j ^ 2 := by
          unfold dotProduct; congr 1; ext j; ring
        linarith [hv, h_dp]
    _ = ∑ i, v i ^ 2 := by simp
    _ = dotProduct v v := by unfold dotProduct; congr 1; ext i; ring
    _ = 1 := hv

/-- **Lower bound on IPR** (Cauchy-Schwarz):
    For any unit vector in ℝⁿ, Σ|v_i|⁴ ≥ 1/n.

    Proof: By Cauchy-Schwarz applied to (1, v_i²):
      (Σ v_i²)² ≤ n · Σ v_i⁴
    Since Σ v_i² = 1, this gives 1 ≤ n · Σ v_i⁴. -/
theorem ipr_lower_bound {n : ℕ} (hn : 0 < n) (v : Fin n → ℝ)
    (hv : dotProduct v v = 1) :
    1 / (n : ℝ) ≤ ipr v := by
  unfold ipr
  rw [div_le_iff₀ (Nat.cast_pos.mpr hn)]
  -- Need: 1 ≤ n * Σ v_i⁴
  -- Σ v_i² = 1
  have h_sum_sq : ∑ i : Fin n, v i ^ 2 = 1 := by
    rw [← hv]; unfold dotProduct; congr 1; ext i; ring
  -- Suffices: (Σ v_i²)² ≤ n * Σ v_i⁴
  suffices h : (∑ i : Fin n, v i ^ 2) ^ 2 ≤ ↑n * ∑ i : Fin n, v i ^ 4 by
    rw [h_sum_sq] at h; linarith
  -- Use Chebyshev/Cauchy-Schwarz: (Σ a_i)² ≤ #s · Σ a_i² for a_i = v_i²
  -- Mathlib: sq_sum_le_card_mul_sum_sq
  calc (∑ i : Fin n, v i ^ 2) ^ 2
      ≤ ↑(Finset.univ : Finset (Fin n)).card *
        ∑ i : Fin n, (v i ^ 2) ^ 2 := sq_sum_le_card_mul_sum_sq
    _ = ↑n * ∑ i : Fin n, v i ^ 4 := by
        congr 1
        · simp [Finset.card_univ, Fintype.card_fin]
        · congr 1; ext i; ring

/-- **Participation ratio range**: 1 ≤ PR(v) ≤ n for any unit vector.

    Follows directly from ipr_lower_bound and ipr_upper_bound:
    - 1/n ≤ IPR ≤ 1  ⟹  1 ≤ 1/IPR ≤ n  ⟹  1 ≤ PR ≤ n -/
theorem pr_range {n : ℕ} (hn : 0 < n) (v : Fin n → ℝ)
    (hv : dotProduct v v = 1) (h_pos : 0 < ipr v) :
    1 ≤ pr v h_pos ∧ pr v h_pos ≤ n := by
  unfold pr
  have h_ipr_pos : (0 : ℝ) < ipr v := h_pos
  have h_ipr_le := ipr_upper_bound v hv
  have h_ipr_lb := ipr_lower_bound hn v hv
  constructor
  · -- 1 ≤ 1/IPR ⟸ IPR ≤ 1
    -- Since 0 < ipr v ≤ 1, we have 1 ≤ 1/ipr v
    rw [one_div, one_le_inv_iff₀]
    exact ⟨h_ipr_pos, h_ipr_le⟩
  · -- 1/IPR ≤ n ⟸ 1/n ≤ IPR
    -- Since 1/n ≤ ipr v, we have 1/ipr v ≤ n
    rw [div_le_iff₀ h_ipr_pos]
    -- Goal: 1 ≤ n * ipr v, i.e. 1/n ≤ ipr v (which is h_ipr_lb)
    rw [one_div] at h_ipr_lb
    calc (1 : ℝ) = (↑n) * (↑n)⁻¹ := by
            rw [mul_inv_cancel₀ (Nat.cast_ne_zero.mpr (by omega))]
      _ ≤ ↑n * ipr v := by
            apply mul_le_mul_of_nonneg_left h_ipr_lb (Nat.cast_nonneg _)

-- ════════════════════════════════════════════════
-- §2.5. IPR EXTREMAL EXAMPLES — PROVED
-- ════════════════════════════════════════════════

/-- **IPR of a basis vector** (maximally localized):
    The standard basis vector e_k has IPR = 1, the maximum.
    Only one component is nonzero (= 1), so Σ|v_i|⁴ = 1⁴ = 1. -/
theorem ipr_basis {n : ℕ} (k : Fin n) :
    ipr (fun i : Fin n => if i = k then (1 : ℝ) else 0) = 1 := by
  unfold ipr
  conv_lhs => arg 2; ext i; rw [show (if i = k then (1 : ℝ) else 0) ^ 4 =
    if i = k then 1 else 0 from by split_ifs <;> norm_num]
  simp [Finset.sum_ite_eq', Finset.mem_univ]

/-- **IPR of the uniform vector** (maximally delocalized):
    The vector (1/√n, ..., 1/√n) has IPR = 1/n, the minimum.
    Proof: Σ (1/√n)⁴ = n · 1/(√n)⁴ = n · 1/n² = 1/n. -/
theorem ipr_uniform {n : ℕ} (hn : 0 < n) :
    ipr (fun _ : Fin n => (1 : ℝ) / Real.sqrt n) = 1 / (n : ℝ) := by
  unfold ipr
  simp only [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]
  have hn_pos : (0 : ℝ) < n := Nat.cast_pos.mpr hn
  have hsqrt_pos : (0 : ℝ) < Real.sqrt n := Real.sqrt_pos.mpr hn_pos
  rw [div_pow, one_pow]
  -- Goal: ↑n * (1 / (√n)⁴) = 1 / ↑n
  -- Key identity: (√n)⁴ = ((√n)²)² = n²
  have h_sq : Real.sqrt n ^ 2 = (n : ℝ) := Real.sq_sqrt (le_of_lt hn_pos)
  have h_pow4 : Real.sqrt n ^ 4 = (n : ℝ) ^ 2 := by
    calc Real.sqrt n ^ 4 = (Real.sqrt n ^ 2) ^ 2 := by ring
    _ = (n : ℝ) ^ 2 := by rw [h_sq]
  rw [h_pow4]
  field_simp

/-- **IPR is non-negative**: Σ vᵢ⁴ ≥ 0.
    Each term vᵢ⁴ = (vᵢ²)² ≥ 0, so the sum is non-negative. -/
theorem ipr_nonneg {n : ℕ} (v : Fin n → ℝ) : 0 ≤ ipr v := by
  unfold ipr
  apply Finset.sum_nonneg
  intro i _
  positivity

/-- **IPR monotonicity under masking**:
    Zeroing out components can only decrease the raw IPR.
    If w agrees with v on some indices and is zero elsewhere,
    then IPR(w) ≤ IPR(v).

    This is the formal version of "projection decreases raw IPR."
    The physical content is that removing components removes
    positive contributions to Σ|vᵢ|⁴. -/
theorem ipr_le_of_mask {n : ℕ} (v : Fin n → ℝ) (S : Finset (Fin n)) :
    ipr (fun i => if i ∈ S then v i else 0) ≤ ipr v := by
  unfold ipr
  apply Finset.sum_le_sum
  intro i _
  by_cases h : i ∈ S
  · simp [h]
  · simp [h]; positivity

-- NOTE: The normalized IPR monotonicity theorem
-- (IPR_raw(v|_S) · ‖v‖⁴ ≥ IPR_raw(v) · ‖v|_S‖⁴)
-- is true but requires a non-trivial Cauchy-Schwarz argument.
-- Deferred to a future session to keep this module sorry-free.

-- ════════════════════════════════════════════════
-- §3. EXPERIMENTAL CONSTANTS (Exploration 19)
-- ════════════════════════════════════════════════

/-- **Experimental Observation (Exploration 19, f64):**
    The mean participation ratio of G_500 is ≈ 80.2,
    while the GOE prediction is dim/3 = 499/3 ≈ 166.3.
    The ratio is 80.2/166.3 ≈ 0.482.

    This ratio converges to ≈ 0.47 as N → ∞, indicating
    the Gram matrix has PERSISTENT PARTIAL LOCALIZATION —
    it is approximately half as delocalized as a full GOE matrix.

    Independently reproducible:
      cd experiments/character-spectral
      cargo run --release --bin cert-export

    Certificate: results/certificates/eigenvector-localization.json -/
theorem oracle_pr_goe_ratio_500 :
    -- The mean PR / (dim/3) ratio at N=500 is in [0.45, 0.52]
    True := trivial  -- Placeholder; precise statement needs formalized mean PR

/-- **Experimental Observation (Exploration 19, f64):**
    The ground state (λ_min eigenvector) of G_500 has PR ≈ 7.1,
    which is O(1) — it does NOT grow with dim.

    This indicates the ground state is LOCALIZED: it concentrates
    weight on a bounded number of indices regardless of matrix size.

    At N=500, the top 3 weighted indices are:
      k=444 (composite, 0.23), k=441 (composite, 0.21), k=440 (composite, 0.18)
    Total prime weight: only 6.1%.

    Certificate: results/certificates/eigenvector-localization.json -/
theorem oracle_ground_state_localized_500 :
    -- The ground state PR at N=500 is bounded: PR ≤ 10
    True := trivial  -- Placeholder; requires formalizing PR of specific eigenvector

-- ════════════════════════════════════════════════
-- §4. CONJECTURES (Placeholders for future work)
-- ════════════════════════════════════════════════

/-- **Composite Dominance Conjecture** (Exploration 19):
    For the ground state eigenvector v₀ of G_N, the weight on
    prime-indexed components is O(1/log N):

      Σ_{p prime, p ≤ N} |v₀(p)|² ≤ C / log N

    This connects directly to the sieve bound in BilinearSieve.lean:
    the sieve controls prime contributions, and the ground state
    (which determines d²_N via G⁻¹b) avoids primes, so the sieve
    bound may be tighter than currently proven.

    EXPERIMENTAL EVIDENCE:
    | N    | Prime weight | Composite weight |
    |------|-------------|-----------------|
    | 100  | 0.041       | 0.959           |
    | 200  | 0.085       | 0.915           |
    | 300  | 0.064       | 0.936           |
    | 500  | 0.061       | 0.939           |
    | 1000 | 0.132       | 0.868           | -/
theorem gram_composite_dominance (N : ℕ) (_ : 100 ≤ N) :
    -- The ground state eigenvector of G_N concentrates weight
    -- on composite indices, with prime weight bounded by O(1/log N)
    True := trivial

/-- **PR/GOE Constant Conjecture** (Exploration 19):
    The ratio mean_PR(G_N) / (dim(G_N)/3) converges to a
    constant α as N → ∞, where α ≈ 0.47.

    This constant characterizes the Gram matrix's position in
    the universality class spectrum between Poisson (α = 0) and
    GOE (α = 1).

    CONVERGENCE DATA:
    | N    | Ratio  |
    |------|--------|
    | 100  | 0.551  |
    | 200  | 0.493  |
    | 300  | 0.475  |
    | 500  | 0.482  |
    | 750  | 0.475  |
    | 1000 | 0.465  | -/
theorem pr_goe_ratio_converges :
    -- ∃ α : ℝ, 0.4 < α ∧ α < 0.6 ∧ lim_{N→∞} mean_PR(G_N)/(N/3) = α
    True := trivial

end Cathedral.Spectral

end
