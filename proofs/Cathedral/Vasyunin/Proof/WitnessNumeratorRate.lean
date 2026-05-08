/-
  Cathedral/Vasyunin/Proof/WitnessNumeratorRate.lean

  ## Graduation of witness_numerator_rate (Axiom B → Theorem)

  Proves |bᵀv - 1| ≤ K₁/ln(N) from the PNT Abel-Mertens infrastructure.

  This bridges the already-proved `moebius_mean_finite_bound` (in AbelMean.lean,
  which works in the BD basis) to the Vasyunin basis `logCutoffWitness × vasyuninMeanVec`.

  ### Proof Strategy

  The algebraic expansion of bᵀv (proved in WitnessNumeratorProved.lean) gives:
    bᵀv = -(1-γ)·S₁(N-1) - S₂(N-1) + [(1-γ)·S₂(N-1) + S₃(N-1)]/ln(N)

  The PNT Abel-Mertens engine (AbelMean.lean) provides K/ln(N) bounds on each
  sub-sum S₁, S₂+1, S₃+2γ. The triangle inequality assembles these into
  the final K₁/ln(N) bound.

  ### Status
  GRADUATED 🎓 (May 8, 2026 — Exploration 29)

  ### Dependencies
  - pnt_mu_div_k (PNT axiom 1)
  - pnt_mu_log_div_k (PNT axiom 2)
  - pnt_mu_log_sq_div_k (PNT axiom 3)
  - Mertens function bound (via moebius_mean_finite_bound)
-/

import Cathedral.PNT.AbelMean
import Cathedral.Vasyunin.Proof.WitnessNumeratorProved

set_option maxHeartbeats 4800000

noncomputable section
open Real Matrix Finset Filter
open Cathedral.Vasyunin

namespace Cathedral.Vasyunin

-- ════════════════════════════════════════════════
-- §1. DEFINITIONAL BRIDGE: BD Basis ↔ Vasyunin Basis
-- ════════════════════════════════════════════════

/-- The BD dot product Σ bdMoebiusWeight(i) × meanEntry(i) equals
    the Vasyunin dot product bᵀv = dotProduct (vasyuninMeanVec N) (logCutoffWitness N).

    Both compute the same sum:
      Σ_{k=1}^{N-1} [-μ(k)(1 - log(k)/log(N))] × [(log(k) + 1 - γ)/k]

    The BD basis uses Fin(N-1) with bdMoebiusWeight, while the Vasyunin
    basis uses Fin N with logCutoffWitness (where the N-th entry vanishes). -/
private lemma bd_vasyunin_dot_eq (N : ℕ) (hN : 10 ≤ N) :
    ∑ i : Fin (N - 1), bdMoebiusWeight N i *
      ((Real.log ↑(i.val + 1) + 1 - eulerMascheroniConstant) / ↑(i.val + 1)) =
    dotProduct (vasyuninMeanVec N) (logCutoffWitness N) := by
  -- Unfold both sides to raw sums
  unfold dotProduct vasyuninMeanVec logCutoffWitness moebiusFn vasyuninMeanEntry
  unfold bdMoebiusWeight logWeight
  -- The Vasyunin side is Fin N, but the last entry vanishes
  conv_rhs => rw [show N = (N - 1) + 1 from by omega]
  rw [Fin.sum_univ_castSucc]
  -- Kill last term (1 - logN/logN = 0)
  have h_last : (Real.log ↑((Fin.last (N - 1)).val + 1) + 1 - eulerMascheroniConstant) /
      ↑((Fin.last (N - 1)).val + 1) *
      (-(↑(ArithmeticFunction.moebius ((Fin.last (N - 1)).val + 1)) : ℝ) *
        (1 - Real.log ↑((Fin.last (N - 1)).val + 1) /
          Real.log ↑((N - 1) + 1))) = 0 := by
    simp only [Fin.val_last]
    have hN_eq : (N - 1 + 1 : ℕ) = N := by omega
    rw [hN_eq]
    have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
    rw [div_self (Real.log_ne_zero_of_pos_of_ne_one hN_pos
      (by exact_mod_cast (show N ≠ 1 from by omega)))]
    simp
  rw [h_last, add_zero]
  simp only [show (N - 1 + 1 : ℕ) = N from by omega, Fin.val_castSucc]
  -- Each summand is equal
  congr 1; ext i; ring

-- ════════════════════════════════════════════════
-- §2. THE GRADUATION THEOREM
-- ════════════════════════════════════════════════

/-- **THEOREM** (was AXIOM B — now GRADUATED! 🎓)

    |bᵀv - 1| ≤ K₁ / ln(N) for N sufficiently large.

    Proof: Bridges `moebius_mean_finite_bound` from AbelMean.lean
    (which proves the bound in the BD basis) to the Vasyunin basis
    via `bd_vasyunin_dot_eq`.

    Dependencies: pnt_mu_div_k, pnt_mu_log_div_k, pnt_mu_log_sq_div_k,
    Mertens function bound (all via moebius_mean_finite_bound). -/
theorem witness_numerator_rate_proved
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4)) :
    ∃ K₁ : ℝ, K₁ > 0 ∧ ∀ N : ℕ, N ≥ 10 →
      |dotProduct (vasyuninMeanVec N) (logCutoffWitness N) - 1| ≤
        K₁ / Real.log ↑N := by
  -- Get the BD-basis bound from AbelMean.lean
  obtain ⟨K, hK_pos, hK_bound⟩ := moebius_mean_finite_bound C_m hC hMertens
  -- Same K works in the Vasyunin basis
  refine ⟨K, hK_pos, fun N hN => ?_⟩
  -- Bridge: BD sum = Vasyunin dot product
  have h_eq := bd_vasyunin_dot_eq N hN
  -- Rewrite the bound using the bridge
  rw [← h_eq]
  exact hK_bound N hN

end Cathedral.Vasyunin
