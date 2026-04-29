import Cathedral.Defs
import Cathedral.Spectral.RayleighBridge

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

  ## Oracle Axioms (from cert-export)

  4. `oracle_pr_goe_ratio_500` — mean PR / (dim/3) ≈ 0.48 at N=500
  5. `oracle_ground_state_pr_bounded` — ground state PR ≤ 10 at N=500

  ## Placeholder (Conjecture)

  6. `gram_composite_dominance` — ground state concentrates on composites

  ## Experimental Motivation

  Exploration 19 Experiment C discovered that the Gram matrix has
  persistent partial localization: the mean participation ratio
  converges to ≈ 0.47 × (dim/3), not to the full GOE value (dim/3).
  The ground state eigenvector scars onto large composites near
  the matrix boundary, with only 4-15% weight on prime indices.

  Status: 3 theorems proved. 2 oracle axioms. 1 placeholder.
  NOT on the crown path.
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
def pr {n : ℕ} (v : Fin n → ℝ) (h : ipr v > 0) : ℝ :=
  1 / ipr v

-- ════════════════════════════════════════════════
-- §2. IPR BOUNDS — PROVED
-- ════════════════════════════════════════════════

/-- **Upper bound on IPR** (Power Mean Inequality):
    For any unit vector v, Σ|v_i|⁴ ≤ (Σ|v_i|²)² = 1.

    Proof: Since |v_i|² ≤ 1 for each i (because ‖v‖ = 1),
    we have |v_i|⁴ = |v_i|² · |v_i|² ≤ |v_i|² · 1 = |v_i|².
    Summing: Σ|v_i|⁴ ≤ Σ|v_i|² = 1. -/
theorem ipr_upper_bound {n : ℕ} (v : Fin n → ℝ)
    (hv : dotProduct v v = 1) :
    ipr v ≤ 1 := by
  unfold ipr
  -- Σ v_i⁴ ≤ Σ v_i² = dotProduct v v = 1
  -- Key: v_i⁴ = (v_i²)² ≤ v_i² · max_j(v_j²) ≤ v_i² · Σ_j v_j² = v_i²
  -- Simpler: v_i⁴ ≤ v_i² when |v_i| ≤ 1 (which follows from ‖v‖=1)
  calc ∑ i, v i ^ 4
      = ∑ i, (v i ^ 2) * (v i ^ 2) := by congr 1; ext i; ring
    _ ≤ ∑ i, v i ^ 2 * 1 := by
        apply Finset.sum_le_sum
        intro i _
        apply mul_le_mul_of_nonneg_left _ (sq_nonneg _)
        -- Need: v_i² ≤ 1, i.e., v_i² ≤ Σ_j v_j²
        rw [← hv]
        exact Finset.single_le_sum (fun j _ => sq_nonneg (v j))
          (Finset.mem_univ i)
    _ = ∑ i, v i ^ 2 := by simp
    _ = dotProduct v v := by unfold dotProduct; congr 1; ext i; ring
    _ = 1 := hv

/-- **Lower bound on IPR** (Cauchy-Schwarz):
    For any unit vector in ℝⁿ, Σ|v_i|⁴ ≥ 1/n.

    Proof: By Cauchy-Schwarz (or power mean inequality),
    (Σ a_i)² ≤ n · Σ a_i² with a_i = v_i².
    So (Σ v_i²)² ≤ n · Σ v_i⁴
    i.e. 1 ≤ n · Σ v_i⁴
    i.e. 1/n ≤ Σ v_i⁴. -/
theorem ipr_lower_bound {n : ℕ} (hn : 0 < n) (v : Fin n → ℝ)
    (hv : dotProduct v v = 1) :
    1 / (n : ℝ) ≤ ipr v := by
  unfold ipr
  -- By Cauchy-Schwarz: (Σ v_i²)² ≤ n · Σ (v_i²)² = n · Σ v_i⁴
  have h_cs : (∑ i : Fin n, v i ^ 2) ^ 2 ≤
      (n : ℝ) * ∑ i : Fin n, (v i ^ 2) ^ 2 := by
    -- This is the Cauchy-Schwarz inequality for the constant function 1
    -- and the function v_i². Specifically: (Σ 1·a_i)² ≤ (Σ 1²)(Σ a_i²)
    have := Finset.inner_mul_le_norm_mul_sq (Finset.univ : Finset (Fin n))
      (fun _ => (1 : ℝ)) (fun i => v i ^ 2)
    simp at this
    linarith
  -- Σ v_i² = dotProduct v v = 1
  have h_sum_sq : ∑ i : Fin n, v i ^ 2 = 1 := by
    rw [← hv]; unfold dotProduct; congr 1; ext i; ring
  -- (v_i²)² = v_i⁴
  have h_pow : ∀ i : Fin n, (v i ^ 2) ^ 2 = v i ^ 4 := by
    intro i; ring
  rw [h_sum_sq] at h_cs; simp at h_cs
  simp_rw [h_pow] at h_cs
  -- h_cs : 1 ≤ n * Σ v_i⁴
  rw [div_le_iff (Nat.cast_pos.mpr hn)]
  linarith

/-- **Participation ratio range**: 1 ≤ PR(v) ≤ n for any unit vector.

    Follows directly from ipr_lower_bound and ipr_upper_bound:
    - 1/n ≤ IPR ≤ 1  ⟹  1 ≤ 1/IPR ≤ n  ⟹  1 ≤ PR ≤ n -/
theorem pr_range {n : ℕ} (hn : 0 < n) (v : Fin n → ℝ)
    (hv : dotProduct v v = 1) (h_pos : 0 < ipr v) :
    1 ≤ pr v h_pos ∧ pr v h_pos ≤ n := by
  unfold pr
  constructor
  · -- 1 ≤ 1/IPR ⟸ IPR ≤ 1
    rw [le_div_iff h_pos, one_mul]
    exact ipr_upper_bound v hv
  · -- 1/IPR ≤ n ⟸ 1/n ≤ IPR
    rw [div_le_iff h_pos]
    have := ipr_lower_bound hn v hv
    rw [div_le_iff (Nat.cast_pos.mpr hn)] at this
    linarith

-- ════════════════════════════════════════════════
-- §3. ORACLE AXIOMS (from cert-export)
-- ════════════════════════════════════════════════

/-- **Oracle (Exploration 19, f64):**
    The mean participation ratio of G_500 is ≈ 80.2,
    while the GOE prediction is dim/3 = 499/3 ≈ 166.3.
    The ratio is 80.2/166.3 ≈ 0.482.

    This ratio converges to ≈ 0.47 as N → ∞, indicating
    the Gram matrix has PERSISTENT PARTIAL LOCALIZATION —
    it is approximately half as delocalized as a full GOE matrix.

    Independently reproducible:
      cd experiments/character-spectral
      cargo run --release --bin cert-export -/
axiom oracle_pr_goe_ratio_500 :
    -- The mean PR / (dim/3) ratio at N=500 is in [0.45, 0.52]
    True  -- Placeholder; the precise statement requires formalizing
          -- the empirical mean PR over all eigenvectors of G_500

/-- **Oracle (Exploration 19, f64):**
    The ground state (λ_min eigenvector) of G_500 has PR ≈ 7.1,
    which is O(1) — it does NOT grow with dim.

    This indicates the ground state is LOCALIZED: it concentrates
    weight on a bounded number of indices regardless of matrix size.

    At N=500, the top 3 weighted indices are:
      k=444 (composite, 0.23), k=441 (composite, 0.21), k=440 (composite, 0.18)
    Total prime weight: only 6.1%. -/
axiom oracle_ground_state_localized_500 :
    -- The ground state PR at N=500 is bounded: PR ≤ 10
    True  -- Placeholder; requires formalizing PR of specific eigenvector

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
