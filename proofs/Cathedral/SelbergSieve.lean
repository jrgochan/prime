/-
  SpectralRH/SelbergSieve.lean

  ## EXPLORATORY: The Selberg Sieve Approach to moebius_test_bound

  **STATUS**: NOT on critical path. This file explores a Selberg sieve
  decomposition but has a known mathematical gap.

  **THE GAP**: Our basis functions are {2/x},...,{N/x} (starting from k=2).
  The Selberg weight λ₁ = μ(1) = 1 contributes via {1/x}, which is NOT
  in our basis. Without the k=1 term, the Selberg-weighted sum has the
  wrong sign/magnitude for L² approximation of the constant function.

  **FIX STRATEGIES** (for future work):
  1. Extend the basis to include {1/x} (requires refactoring nbLinComb)
  2. Use a modified test vector that compensates for the missing {1/x}
  3. Use an entirely different test vector (e.g., optimal v* = G⁻¹b)

  The decomposition pattern below (axiom → sub-axioms → theorem chain)
  remains a valuable template for future approaches.

  ### Original Architecture (conditional on fixing the test vector)

  moebius_test_bound
    ← moebius_test_bound_from_selberg
      ← selberg_l2_bound
        ← selberg_linear_bound + selberg_quadratic_bound
-/

import Cathedral.Structural
import Mathlib.NumberTheory.ArithmeticFunction.Moebius

noncomputable section
open Real MeasureTheory Set

-- ════════════════════════════════════════════════
-- SECTION 1: SELBERG SIEVE WEIGHTS
-- ════════════════════════════════════════════════

/-- The Selberg sieve weight (linear sieve version).

    λ(d, D) = μ(d) · max(0, 1 - log(d)/log(D))
    for d ≤ D, and 0 otherwise.

    This is the "low-pass windowing function" that smoothly tapers the
    Möbius signal from full strength at d=1 to zero at d=D, avoiding
    the sharp truncation that requires the PNT to control.

    Special cases:
    - d = 0: returns 0 (convention)
    - D ≤ 1: returns 1 if d=1, else 0 (trivial sieve)
    - d > D: returns 0 (beyond sieve level)
    - otherwise: μ(d) · max(0, 1 - log(d)/log(D)) -/
def selbergWeight (d D : ℕ) : ℝ :=
  if d = 0 then 0
  else if D ≤ 1 then (if d = 1 then 1 else 0)
  else if D < d then 0
  else
    -- The Selberg linear sieve weight:
    -- μ(d) cast to ℝ, times the smooth taper
    (↑(ArithmeticFunction.moebius d : ℤ) : ℝ) *
      max 0 (1 - Real.log (d : ℝ) / Real.log (D : ℝ))

/-- The Selberg weight at d=1 is exactly 1.
    Proof: μ(1) = 1, log(1) = 0, so weight = 1 · max(0, 1-0) = 1. -/
theorem selbergWeight_one (D : ℕ) (hD : 1 ≤ D) : selbergWeight 1 D = 1 := by
  unfold selbergWeight
  simp only [show (1 : ℕ) ≠ 0 from Nat.one_ne_zero, ↓reduceIte]
  split
  · -- D ≤ 1 case: d=1 branch gives 1
    simp
  · -- D > 1 case
    rename_i hD1
    push_neg at hD1
    simp only [show ¬ (D < 1) from by omega, ↓reduceIte]
    rw [ArithmeticFunction.moebius_apply_one]
    simp [Real.log_one]

/-- The Selberg weight vanishes beyond the sieve level (for D ≥ 1). -/
theorem selbergWeight_zero_of_gt (d D : ℕ) (hD : 1 ≤ D) (h : D < d) :
    selbergWeight d D = 0 := by
  unfold selbergWeight
  split
  · rfl  -- d = 0 case
  · split
    · -- D ≤ 1 case: D ≥ 1 and D ≤ 1 means D = 1, so d ≥ 2
      rename_i hd0 _
      rw [if_neg (show d ≠ 1 from by omega)]
    · -- D > 1 case: D < d already decided
      rfl

/-- The Selberg test vector: v_i = λ(i+2, D) / (i+2) for i ∈ Fin(N-1).
    This assigns the (smoothed) Selberg weight to each
    basis function {(i+2)/x}. -/
def selbergTestVec (N D : ℕ) : Fin (N - 1) → ℝ :=
  fun i => selbergWeight (i.val + 1) D / (i.val + 1 : ℝ)

-- ════════════════════════════════════════════════
-- SECTION 2: THE SELBERG L² BOUND
-- ════════════════════════════════════════════════

/-- **Sub-axiom 1 (Mertens' Theorem consequence — 1874, elementary)**:

    The linear term bᵀv with Selberg weights satisfies:
    2 · bᵀv ≥ 1 - C₁/log(N)

    where b = basisInnerProd N, v = selbergTestVec N N.

    Equivalently: 1 - 2·bᵀv ≤ C₁/log(N).

    **Proof strategy**: Each b_k = ∫₀¹ {k/x} dx = 1/2 + O(1/k), and
    Σ(λ_k/k) → 1 by Mertens' theorem (1874). So:
    bᵀv = Σ(λ_k/k)·(1/2 + O(1/k)) = 1/2·Σ(λ_k/k) + O(Σλ_k/k²)
         = 1/2 + O(1/log N).

    This uses only Mertens' theorem — completely elementary. -/
axiom selberg_linear_bound :
    ∃ C₁ : ℝ, 0 < C₁ ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    1 - 2 * dotProduct (basisInnerProd N) (selbergTestVec N N) ≤
      C₁ / Real.log (N : ℝ)

/-- **Sub-axiom 2a (Mertens — 1874, elementary)**:

    The Selberg-weighted Dirichlet sum is O(1/log N):
    |Σ_{k=2}^N λ_k/k| ≤ C₃/log(N)

    **Proof strategy**: By partial summation,
    Σ_{d≤D} μ(d)/d · (1 - log(d)/log(D)) = (1/log D)·Σ μ(d)·log(D/d)/d
    The inner sum is related to 1/ζ'(1) via Mertens' theorem:
    Σ_{d≤x} μ(d)/d · log(x/d) → 1  as x → ∞
    This is WEAKER than the PNT — it follows from Chebyshev bounds.

    Note: The sum here excludes k=1 (matching our Fin(N-1) indexing). -/
axiom selberg_dirichlet_sum :
    ∃ C₃ : ℝ, 0 < C₃ ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    (∑ i : Fin (N - 1), selbergTestVec N N i) ^ 2 ≤
      C₃ / Real.log (N : ℝ)

/-- **Sub-axiom 2b (Gram matrix — analytic)**:

    The Gram quadratic form with Selberg weights is controlled by
    the squared weight sum plus a correction of the same order:

    vᵀGv ≤ C₄ · (Σ|v_i|)² for v = selbergTestVec N N

    **Proof strategy**: Since G_{jk} ≤ 1 (gramEntry_le_one),
    vᵀGv = Σ v_j v_k G_{jk} ≤ Σ |v_j v_k| = (Σ|v_j|)²

    But we actually need a TIGHTER bound using the oscillatory
    structure of the Selberg weights. The key is Vasyunin's expansion:
    G_{jk} ≈ 1/4 + O(gcd(j,k)/(jk)), and the Möbius cancellation
    in the λ_k kills the 1/4 main term, leaving only the correction. -/
axiom gram_selberg_quadform_bound :
    ∃ C₄ : ℝ, 0 < C₄ ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    realQuadForm (gramMatrix N) (selbergTestVec N N) ≤
      C₄ * (∑ i : Fin (N - 1), selbergTestVec N N i) ^ 2 +
      C₄ / Real.log (N : ℝ)

/-- **THEOREM**: selberg_quadratic_bound from sub-axioms.

    Proof: vᵀGv ≤ C₄·(Σv)² + C₄/log(N)
                ≤ C₄·(C₃/log N) + C₄/log(N)
                = C₄(C₃+1)/log(N) -/
theorem selberg_quadratic_bound :
    ∃ C₂ : ℝ, 0 < C₂ ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    realQuadForm (gramMatrix N) (selbergTestVec N N) ≤
      C₂ / Real.log (N : ℝ) := by
  obtain ⟨C₃, hC₃, N₃, hN₃, h_sum⟩ := selberg_dirichlet_sum
  obtain ⟨C₄, hC₄, N₄, hN₄, h_gram⟩ := gram_selberg_quadform_bound
  refine ⟨C₄ * C₃ + C₄, by positivity, max N₃ N₄, by omega, fun N hN => ?_⟩
  have hN3 : N₃ ≤ N := by omega
  have hN4 : N₄ ≤ N := by omega
  have h1 := h_sum N hN3
  have h2 := h_gram N hN4
  have h_combine : C₄ * (C₃ / Real.log (N : ℝ)) + C₄ / Real.log (N : ℝ) =
      (C₄ * C₃ + C₄) / Real.log (N : ℝ) := by ring
  calc realQuadForm (gramMatrix N) (selbergTestVec N N)
      ≤ C₄ * (∑ i : Fin (N - 1), selbergTestVec N N i) ^ 2 +
        C₄ / Real.log (N : ℝ) := h2
    _ ≤ C₄ * (C₃ / Real.log (N : ℝ)) + C₄ / Real.log (N : ℝ) := by
        linarith [mul_le_mul_of_nonneg_left h1 (le_of_lt hC₄)]
    _ = (C₄ * C₃ + C₄) / Real.log (N : ℝ) := h_combine

/-- **THEOREM**: selberg_l2_bound from the linear + quadratic sub-axioms.

    Proof:
    1. l2_error_eq_quad_error: ∫(1-f)² = 1 - 2bᵀv + vᵀGv
    2. selberg_linear_bound:   1 - 2bᵀv ≤ C₁/log(N)
    3. selberg_quadratic_bound: vᵀGv ≤ C₂/log(N)
    4. Sum: ∫(1-f)² ≤ (C₁+C₂)/log(N) -/
theorem selberg_l2_bound :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N →
    ∫ x in (0:ℝ)..1,
      (1 - nbLinComb N (selbergTestVec N N) x) ^ 2 ≤
    C / Real.log (N : ℝ) := by
  -- Get both sub-axiom bounds
  obtain ⟨C₁, hC₁, N₁, hN₁, h_lin⟩ := selberg_linear_bound
  obtain ⟨C₂, hC₂, N₂, hN₂, h_quad⟩ := selberg_quadratic_bound
  -- Use C = C₁ + C₂, N₀ = max N₁ N₂
  refine ⟨C₁ + C₂, by linarith, max N₁ N₂, by omega, fun N hN => ?_⟩
  -- For N ≥ max N₁ N₂, both bounds apply
  have hN1 : N₁ ≤ N := by omega
  have hN2 : N₂ ≤ N := by omega
  have hN_ge2 : 2 ≤ N := by omega
  -- Step 1: Convert integral to matrix form
  rw [l2_error_eq_quad_error N hN_ge2 (selbergTestVec N N)]
  -- Step 2: Bound (1 - 2bᵀv) + vᵀGv ≤ C₁/log(N) + C₂/log(N)
  have h1 := h_lin N hN1
  have h2 := h_quad N hN2
  -- Step 3: C₁/log(N) + C₂/log(N) = (C₁+C₂)/log(N)
  have h_combine : C₁ / Real.log (N : ℝ) + C₂ / Real.log (N : ℝ) =
      (C₁ + C₂) / Real.log (N : ℝ) := by ring
  linarith

-- ════════════════════════════════════════════════
-- SECTION 3: THE BRIDGE THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM**: moebius_test_bound follows from the Selberg L² bound.

    This is the key reduction: the existentially quantified
    moebius_test_bound is satisfied by exhibiting the Selberg
    test vector as our witness.

    The proof is trivial: selberg_l2_bound gives us a SPECIFIC vector
    (the Selberg weights), and moebius_test_bound only asks for the
    EXISTENCE of any vector meeting the bound. -/
theorem moebius_test_bound_from_selberg :
    ∃ C : ℝ, 0 < C ∧ ∃ N₀ : ℕ, 2 ≤ N₀ ∧
    ∀ N : ℕ, N₀ ≤ N → ∃ v : Fin (N - 1) → ℝ,
    ∫ x in (0:ℝ)..1, (1 - nbLinComb N v x) ^ 2 ≤ C / Real.log (N : ℝ) := by
  obtain ⟨C, hC, N₀, hN₀, h_selberg⟩ := selberg_l2_bound
  exact ⟨C, hC, N₀, hN₀, fun N hN =>
    ⟨selbergTestVec N N, h_selberg N hN⟩⟩

end
