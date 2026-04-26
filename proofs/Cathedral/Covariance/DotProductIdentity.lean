/-
  Cathedral/Covariance/DotProductIdentity.lean

  ## Algebraic Identity: 1 - bᵀv = (1-γ)·S₁ + (S₂+1) - [(1-γ)·S₂+S₃]/logN

  Proves the pure algebraic identity connecting the Fin-indexed
  dot product to S₁_at, S₂_at, S₃_at partial sums.
-/

import Cathedral.MellinBridge.BDWeights
import Cathedral.Vasyunin.Augmented.DiagBound
import Cathedral.AbelTail.S1Decay
import Cathedral.AbelTail.S2Decay
import Cathedral.AbelTail.S3Decay
import Cathedral.AbelTail.Engine

noncomputable section
open Real Finset BigOperators ArithmeticFunction

-- ════════════════════════════════════════════════
-- §1. DOT PRODUCT AS ICC SUM
-- ════════════════════════════════════════════════

/-- The dot product unfolds as a sum over Icc, using fin_sum_eq_icc_sum. -/
theorem dotProduct_as_icc (N : ℕ) (hN : 2 ≤ N) :
    dotProduct (fun i : Fin (N - 1) =>
        Cathedral.Vasyunin.vasyuninMeanEntry (i.val + 1))
      (bdMoebiusWeight N) =
    ∑ k ∈ Finset.Icc 1 (N - 1),
      Cathedral.Vasyunin.vasyuninMeanEntry k *
      (-(↑(moebius k) : ℝ) * logWeight N k) := by
  -- dotProduct unfolds to ∑ i, b(i) * v(i)
  simp only [dotProduct]
  -- Each summand: b(i.val+1) * v(N,i) = vasyuninMeanEntry(k) * (-μ(k)·logWeight(N,k))
  have h_eq : ∀ i : Fin (N - 1),
      Cathedral.Vasyunin.vasyuninMeanEntry (i.val + 1) * bdMoebiusWeight N i =
      (fun k => Cathedral.Vasyunin.vasyuninMeanEntry k *
        (-(↑(moebius k) : ℝ) * logWeight N k)) (i.val + 1) := by
    intro i; unfold bdMoebiusWeight; rfl
  simp_rw [h_eq]
  convert fin_sum_eq_icc_sum hN
    (fun k => Cathedral.Vasyunin.vasyuninMeanEntry k *
      (-(↑(moebius k) : ℝ) * logWeight N k)) using 1

-- ════════════════════════════════════════════════
-- §2. FOUR-WAY SUM SPLIT
-- ════════════════════════════════════════════════

/-- Split the dot product sum into S₁, S₂, S₃ components. -/
theorem icc_sum_split (N : ℕ) (_hN : 2 ≤ N)
    (hlogN : Real.log (N : ℝ) ≠ 0) :
    ∑ k ∈ Finset.Icc 1 (N - 1),
      Cathedral.Vasyunin.vasyuninMeanEntry k *
      (-(↑(moebius k) : ℝ) * logWeight N k) =
    -(1 - eulerMascheroniConstant) * S₁_at (N - 1) -
    S₂_at (N - 1) +
    ((1 - eulerMascheroniConstant) * S₂_at (N - 1) +
     S₃_at (N - 1)) / Real.log ↑N := by
  -- Show both sides are single sums over Icc 1 (N-1) with equal summands.
  -- LHS summand: vasyuninMeanEntry(k) * (-μ(k) * logWeight(N,k))
  --            = (logk+1-γ)/k * (-μ(k)*(1-logk/logN))
  -- RHS: -(1-γ)*S₁ - S₂ + [(1-γ)*S₂+S₃]/logN
  --    = Σ [-(1-γ)*μ(k)/k - μ(k)*logk/k + ((1-γ)*μ(k)*logk/k + μ(k)*log²k/k)/logN]
  -- These are equal after field_simp + ring.
  -- Step 1: Convert LHS
  simp_rw [Cathedral.Vasyunin.vasyuninMeanEntry, logWeight]
  -- Step 2: Convert RHS to a single sum
  unfold S₁_at S₂_at S₃_at
  -- The RHS is -(1-γ)*(Σ μ/k) - (Σ μ·logk/k) + ((1-γ)*(Σ μ·logk/k) + (Σ μ·log²k/k))/logN
  -- Combine into Σ [-(1-γ)*μ/k - μ*logk/k + ((1-γ)*μ*logk/k + μ*log²k/k)/logN]
  -- using: a*Σf = Σ(a*f), -Σf = Σ(-f), (Σf+Σg)/c = Σ((f+g)/c)
  suffices h : ∀ k ∈ Icc 1 (N - 1),
      (log ↑k + 1 - eulerMascheroniConstant) / (↑k : ℝ) *
      (-(↑(moebius k) : ℝ) * (1 - log ↑k / log ↑N)) =
    -(1 - eulerMascheroniConstant) * ((↑(moebius k) : ℝ) / ↑k) -
    (↑(moebius k) : ℝ) * log ↑k / ↑k +
    ((1 - eulerMascheroniConstant) * ((↑(moebius k) : ℝ) * log ↑k / ↑k) +
     (↑(moebius k) : ℝ) * log ↑k ^ 2 / ↑k) / log ↑N by
    rw [Finset.sum_congr rfl h]
    -- Factor the four sums back into const*S₁, S₂, const*S₂/logN, S₃/logN
    -- This is pure sum manipulation (Finset.mul_sum, Finset.sum_div, etc.)
    simp only [Finset.sum_add_distrib, Finset.sum_sub_distrib,
               ← Finset.mul_sum, ← Finset.sum_div]
  -- Step 3: Show summand equality
  intro k hk
  rw [Finset.mem_Icc] at hk
  have hk_ne : (k : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  field_simp
  ring

-- ════════════════════════════════════════════════
-- §3. THE MAIN IDENTITY
-- ════════════════════════════════════════════════

/-- **THE KEY IDENTITY**: 1 - bᵀv in terms of S₁, S₂, S₃.

    1 - bᵀv = (1-γ)·S₁_at(N-1) + (S₂_at(N-1) + 1)
               - [(1-γ)·S₂_at(N-1) + S₃_at(N-1)] / logN -/
theorem one_minus_dotProduct_identity (N : ℕ) (hN : 2 ≤ N)
    (hlogN : Real.log (N : ℝ) ≠ 0) :
    1 - dotProduct (fun i : Fin (N - 1) =>
        Cathedral.Vasyunin.vasyuninMeanEntry (i.val + 1))
      (bdMoebiusWeight N) =
    (1 - eulerMascheroniConstant) * S₁_at (N - 1) +
    (S₂_at (N - 1) + 1) -
    ((1 - eulerMascheroniConstant) * S₂_at (N - 1) +
     S₃_at (N - 1)) / Real.log ↑N := by
  rw [dotProduct_as_icc N hN, icc_sum_split N hN hlogN]
  ring

end
