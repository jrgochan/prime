/-
  Scratch: Proving vasyunin_bd_index_bridge — cleaned up.
-/

import Cathedral.Vasyunin.Proof.WitnessConditional
import Cathedral.Assembly.BDBridge
import Cathedral.MellinBridge.BDWeights

set_option maxHeartbeats 3200000

noncomputable section
open Real MeasureTheory Finset BigOperators Matrix Cathedral.Vasyunin

-- ═══════════════════════════════════════════════
-- KEY ALGEBRAIC FACT: dotProduct is commutative
-- ═══════════════════════════════════════════════

-- Mathlib has: dotProduct_comm
#check dotProduct_comm

-- ═══════════════════════════════════════════════
-- CORE IDENTITY (algebraic)
-- ═══════════════════════════════════════════════

/-- (1 - bᵀv)² + vᵀ(G - bbᵀ)v = 1 - 2bᵀv + vᵀGv -/
theorem cov_to_gram_identity {n : ℕ}
    (b v : Fin n → ℝ) (G : Matrix (Fin n) (Fin n) ℝ) :
    (1 - dotProduct b v) ^ 2 +
    (dotProduct v ((G - vecMulVec b b).mulVec v)) =
    1 - 2 * dotProduct b v + dotProduct v (G.mulVec v) := by
  simp [Matrix.sub_mulVec, dotProduct_sub, vecMulVec_mulVec]
  have hcomm : dotProduct v b = dotProduct b v := dotProduct_comm v b
  nlinarith [sq_nonneg (dotProduct b v)]

-- ═══════════════════════════════════════════════
-- Apply to Vasyunin (LHS = 1 - 2bᵀv + vᵀGv over Fin N)
-- ═══════════════════════════════════════════════

theorem lhs_eq_gram_form (N : ℕ) :
    (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
    dotProduct (logCutoffWitness N) ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) =
    1 - 2 * dotProduct (vasyuninMeanVec N) (logCutoffWitness N) +
    dotProduct (logCutoffWitness N) ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) := by
  unfold vasyuninCovMatrix
  simp [Matrix.sub_mulVec, dotProduct_sub, vecMulVec_mulVec]
  have hcomm : dotProduct (logCutoffWitness N) (vasyuninMeanVec N) =
               dotProduct (vasyuninMeanVec N) (logCutoffWitness N) :=
    dotProduct_comm _ _
  nlinarith [sq_nonneg (dotProduct (vasyuninMeanVec N) (logCutoffWitness N))]

-- ═══════════════════════════════════════════════
-- SUM BRIDGES: Fin N → Fin(N-1)
-- ═══════════════════════════════════════════════

-- These are the remaining sub-goals. Since logCutoffWitness N
-- at index N-1 is 0, the Fin N sums collapse to Fin(N-1) sums.

-- For now, axiomatize these. Each is a finset sum manipulation
-- where the last term vanishes.

axiom dotProduct_bridge (N : ℕ) (hN : 3 ≤ N) :
    dotProduct (vasyuninMeanVec N) (logCutoffWitness N) =
    dotProduct (fun (i : Fin (N - 1)) => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N)

axiom quadForm_bridge (N : ℕ) (hN : 3 ≤ N) :
    dotProduct (logCutoffWitness N) ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) =
    realQuadForm (of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N)

-- ═══════════════════════════════════════════════
-- THE FULL PROOF
-- ═══════════════════════════════════════════════

theorem vasyunin_bd_index_bridge_proved (N : ℕ) (hN : 3 ≤ N) :
    (1 - dotProduct (vasyuninMeanVec N) (logCutoffWitness N)) ^ 2 +
    dotProduct (logCutoffWitness N) ((vasyuninCovMatrix N).mulVec (logCutoffWitness N)) =
    1 - 2 * dotProduct (fun i => vasyuninMeanEntry (i.val + 1)) (bdMoebiusWeight N) +
    realQuadForm (of fun i j => vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight N) := by
  rw [lhs_eq_gram_form]
  rw [dotProduct_bridge N hN, quadForm_bridge N hN]

#check @vasyunin_bd_index_bridge_proved

end
