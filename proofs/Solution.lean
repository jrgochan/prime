/-
  Solution.lean — The Cathedral's Proof

  ════════════════════════════════════════════════════════════════

  This file provides the proof for cathedral_main_theorem
  declared in Challenge.lean.

  The proof imports the full Cathedral framework and connects
  the Cathedral's `overcancellation_implies_rh` theorem to the
  Challenge interface.

  Format: leanprover/comparator convention.

  Created: June 23, 2026 — Port 22 Day + 1
-/

import Cathedral.Assembly.OvercancellationChain
import Cathedral.Wall

noncomputable section
open Real Matrix Finset Filter ArithmeticFunction Cathedral.Vasyunin

-- ════════════════════════════════════════════════════════════════
-- §1. INLINED DEFINITIONS (identical copies from Challenge.lean)
-- ════════════════════════════════════════════════════════════════

-- These must be structurally identical to Challenge.lean's private defs
-- so the comparator can verify type-level equivalence.

private def cotFn (x : ℝ) : ℝ := Real.cos x / Real.sin x

private def vasyuninSum' (a b : ℕ) : ℝ :=
  if a ≤ 1 then 0
  else ∑ m ∈ Ico 1 a,
    Int.fract ((m * b : ℕ) / (a : ℝ)) * cotFn (Real.pi * m / a)

private def vasyuninGramEntry' (j k : ℕ) : ℝ :=
  let d := Nat.gcd j k
  let jp := j / d
  let kp := k / d
  if j = k then
    (Real.log (2 * Real.pi) - eulerMascheroniConstant) / (j : ℝ) - 1 / (j : ℝ) ^ 2
  else
    let jf : ℝ := j
    let kf : ℝ := k
    let term1 := (Real.log (2 * Real.pi) - eulerMascheroniConstant) / 2 * (1 / jf + 1 / kf)
    let term2 := (jf - kf) / (2 * jf * kf) * Real.log (kf / jf)
    let term3 := Real.pi * (d : ℝ) / (2 * jf * kf) *
                 (vasyuninSum' jp kp + vasyuninSum' kp jp)
    let term4 := 1 / (jf * kf)
    term1 + term2 - term3 - term4

private def vasyuninGramMatrix' (N : ℕ) : Matrix (Fin N) (Fin N) ℝ :=
  Matrix.of (fun i j => vasyuninGramEntry' (i.val + 1) (j.val + 1))

private def logCutoffWitness' (N : ℕ) (i : Fin N) : ℝ :=
  -(↑(moebius (i.val + 1)) : ℝ) * (1 - Real.log ↑(i.val + 1) / Real.log ↑N)

-- ════════════════════════════════════════════════════════════════
-- §2. DEFINITION BRIDGE
-- ════════════════════════════════════════════════════════════════

/-! We show that the inlined definitions are definitionally equal to
    the Cathedral's definitions. Since both define identical computations,
    this follows by `rfl` (or unfold + rfl). -/

private lemma vasyuninGramEntry_bridge (j k : ℕ) :
    vasyuninGramEntry' j k = Cathedral.Vasyunin.vasyuninGramEntry j k := by
  unfold vasyuninGramEntry' Cathedral.Vasyunin.vasyuninGramEntry
  unfold vasyuninSum' Cathedral.Vasyunin.vasyuninSum
  unfold cotFn Cathedral.Vasyunin.cot
  rfl

private lemma vasyuninGramMatrix_bridge (N : ℕ) :
    vasyuninGramMatrix' N = Cathedral.Vasyunin.vasyuninGramMatrix N := by
  ext i j
  unfold vasyuninGramMatrix' Cathedral.Vasyunin.vasyuninGramMatrix
  simp only [of_apply]
  exact vasyuninGramEntry_bridge _ _

private lemma logCutoffWitness_bridge (N : ℕ) (i : Fin N) :
    logCutoffWitness' N i = Cathedral.Vasyunin.logCutoffWitness N i := by
  unfold logCutoffWitness' Cathedral.Vasyunin.logCutoffWitness
  unfold Cathedral.Vasyunin.moebiusFn
  rfl

-- ════════════════════════════════════════════════════════════════
-- §3. THE PROOF
-- ════════════════════════════════════════════════════════════════

/-- **THE CATHEDRAL'S MAIN THEOREM — PROVED.**

    The proof proceeds by:
    1. Rewriting the inlined definitions to Cathedral's equivalents
    2. Applying `overcancellation_implies_rh` from OvercancellationChain.lean
    3. This theorem was proved with 0 sorry in the Cathedral framework -/
theorem cathedral_main_theorem :
    (∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
      dotProduct (logCutoffWitness' N)
        ((vasyuninGramMatrix' N).mulVec
          (logCutoffWitness' N)) ≤ 1) →
    RiemannHypothesis := by
  intro h_oc
  apply overcancellation_implies_rh
  obtain ⟨N₀, hN₀⟩ := h_oc
  refine ⟨N₀, fun N hN hN3 => ?_⟩
  have := hN₀ N hN hN3
  -- Bridge: rewrite inlined defs → Cathedral defs
  have h_wit : logCutoffWitness' N = Cathedral.Vasyunin.logCutoffWitness N :=
    funext (logCutoffWitness_bridge N)
  rw [h_wit, vasyuninGramMatrix_bridge] at this
  exact this
