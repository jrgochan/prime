/-
  Scratch: Clean approach to the sum bridges.
  Key insight: substitute N = m + 1 where m = N-1,
  then use Fin.sum_univ_castSucc directly.
-/

import Cathedral.Vasyunin.Proof.WitnessConditional
import Cathedral.Assembly.BDBridge
import Cathedral.MellinBridge.BDWeights

set_option maxHeartbeats 3200000

noncomputable section
open Real MeasureTheory Finset BigOperators Matrix Cathedral.Vasyunin

-- ═══════════════════════════════════════════════
-- APPROACH: Work with m = N-1, N = m+1
-- ═══════════════════════════════════════════════

-- Instead of working with N and N-1 (which causes omega issues),
-- parameterize by m and set N = m+1.

/-- Dot product bridge: parameterized by m where N = m+1.
    bᵀv over Fin(m+1) = bᵀv over Fin m when last v-weight is 0. -/
theorem dotProduct_bridge_m (m : ℕ) (hm : 2 ≤ m) :
    dotProduct (vasyuninMeanVec (m + 1)) (logCutoffWitness (m + 1)) =
    dotProduct (fun (i : Fin m) => vasyuninMeanEntry (i.val + 1))
              (bdMoebiusWeight (m + 1)) := by
  unfold dotProduct
  -- Split the Fin(m+1) sum using Fin.sum_univ_castSucc
  rw [Fin.sum_univ_castSucc]
  -- Last term: vasyuninMeanVec (m+1) (Fin.last m) * logCutoffWitness (m+1) (Fin.last m)
  -- = ... * 0 = 0 (by logCutoffWitness_last)
  have h_last : logCutoffWitness (m + 1) (Fin.last m) = 0 := by
    exact logCutoffWitness_last (m + 1) (by omega)
  simp only [h_last, mul_zero, add_zero]
  -- Now both sides are sums over Fin m
  simp only [vasyuninMeanVec, Fin.castSucc, logCutoffWitness, bdMoebiusWeight, logWeight, moebiusFn]
  apply Finset.sum_congr rfl
  intro i _
  congr 2 <;> simp [Fin.castAdd]

-- ═══════════════════════════════════════════════
-- QUAD FORM BRIDGE (similarly)
-- ═══════════════════════════════════════════════

-- realQuadForm G v = Σ_i Σ_j v_i * G_{ij} * v_j
-- = Σ_i v_i * (Σ_j G_{ij} * v_j)
-- = vᵀ · (G · v)
-- = dotProduct v (G.mulVec v)

-- The Fin(m+1) quad form with last weight = 0 equals the Fin m quad form.

-- For the dotProduct version:
-- dotProduct v (G.mulVec v) over Fin(m+1)
-- = Σ_i v_i * (Σ_j G_{ij} * v_j)

-- When v_{m} = 0:
-- - Row i = m: v_m * ... = 0
-- - Column j = m in the inner sum: G_{ij} * v_m = 0
-- So only i,j ∈ {0,..,m-1} contribute.

theorem quadForm_bridge_m (m : ℕ) (hm : 2 ≤ m) :
    dotProduct (logCutoffWitness (m+1)) ((vasyuninGramMatrix (m+1)).mulVec (logCutoffWitness (m+1))) =
    realQuadForm (of fun (i j : Fin m) => vasyuninGramEntry (i.val + 1) (j.val + 1)) (bdMoebiusWeight (m+1)) := by
  unfold dotProduct Matrix.mulVec realQuadForm
  -- Split outer sum: Fin(m+1) → Fin m + last
  rw [Fin.sum_univ_castSucc]
  have h_last : logCutoffWitness (m + 1) (Fin.last m) = 0 :=
    logCutoffWitness_last (m + 1) (by omega)
  -- Last row term: v_{last} * (...) = 0 * (...) = 0
  simp only [h_last, zero_mul, add_zero]
  -- Now for each remaining row i, split the inner sum
  apply Finset.sum_congr rfl
  intro i _
  -- Need: v(castSucc i) * Σ_j G(castSucc i, j) * v(j) = w(i) * Σ_j G'(i,j) * w(j)
  -- Factor: v(castSucc i) = w(i) [weight equiv at castSucc = id on Fin m]
  have h_wt : logCutoffWitness (m + 1) (Fin.castSucc i) = bdMoebiusWeight (m + 1) i := by
    unfold logCutoffWitness bdMoebiusWeight logWeight moebiusFn
    simp [Fin.castSucc, Fin.castAdd]
  rw [h_wt]
  congr 1
  -- Inner sum: Σ_{j ∈ Fin(m+1)} G(castSucc i, j) * v(j)
  --          = Σ_{j ∈ Fin m} G'(i, j) * w(j)
  -- Split the inner Fin(m+1) sum
  unfold dotProduct
  rw [Fin.sum_univ_castSucc]
  simp only [h_last, mul_zero, add_zero]
  apply Finset.sum_congr rfl
  intro j _
  -- G(castSucc i, castSucc j) = G'(i, j) and v(castSucc j) = w(j)
  have h_gram : (vasyuninGramMatrix (m + 1)) (Fin.castSucc i) (Fin.castSucc j) =
      (of fun (a b : Fin m) => vasyuninGramEntry (a.val + 1) (b.val + 1)) i j := by
    simp [vasyuninGramMatrix, Matrix.of_apply, Fin.castSucc, Fin.castAdd]
  have h_wt_j : logCutoffWitness (m + 1) (Fin.castSucc j) = bdMoebiusWeight (m + 1) j := by
    unfold logCutoffWitness bdMoebiusWeight logWeight moebiusFn
    simp [Fin.castSucc, Fin.castAdd]
  rw [h_gram, h_wt_j]

-- ═══════════════════════════════════════════════
-- WRAPPING: Convert back to N form
-- ═══════════════════════════════════════════════

theorem dotProduct_bridge_N (N : ℕ) (hN : 3 ≤ N) :
    dotProduct (vasyuninMeanVec N) (logCutoffWitness N) =
    dotProduct (fun (i : Fin (N - 1)) => vasyuninMeanEntry (i.val + 1))
              (bdMoebiusWeight N) := by
  have hm : N = (N - 1) + 1 := by omega
  have hm2 : 2 ≤ N - 1 := by omega
  conv_lhs => rw [show N = (N-1) + 1 from hm]
  conv_rhs => rw [show N = (N-1) + 1 from hm]
  exact dotProduct_bridge_m (N - 1) hm2

end
