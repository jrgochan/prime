/-
  Solution.lean — The Cathedral's Proof

  ════════════════════════════════════════════════════════════════

  This file provides the proof for cathedral_main_theorem
  declared in Challenge.lean.

  The proof imports CathedralDefs (shared definitions) and the
  Cathedral framework, then bridges the definitions.

  Format: leanprover/comparator convention.

  Created: June 23, 2026 — Port 22 Day + 1
  Refactored: June 25, 2026 — comparator compatibility
-/

import CathedralDefs
import Cathedral.Assembly.OvercancellationChain
import Cathedral.Wall

noncomputable section
open Real Matrix Finset Filter ArithmeticFunction Cathedral.Vasyunin

-- ════════════════════════════════════════════════════════════════
-- §1. DEFINITION BRIDGE
-- ════════════════════════════════════════════════════════════════

/-! We show that CathedralDefs definitions are definitionally equal to
    the Cathedral's definitions. Since both define identical computations,
    this follows by rfl. -/

private lemma vasyuninGramEntry_bridge (j k : ℕ) :
    CathedralDefs.vasyuninGramEntry j k = Cathedral.Vasyunin.vasyuninGramEntry j k := by
  unfold CathedralDefs.vasyuninGramEntry Cathedral.Vasyunin.vasyuninGramEntry
  unfold CathedralDefs.vasyuninSum Cathedral.Vasyunin.vasyuninSum
  unfold CathedralDefs.cotFn Cathedral.Vasyunin.cot
  rfl

private lemma vasyuninGramMatrix_bridge (N : ℕ) :
    CathedralDefs.vasyuninGramMatrix N = Cathedral.Vasyunin.vasyuninGramMatrix N := by
  ext i j
  unfold CathedralDefs.vasyuninGramMatrix Cathedral.Vasyunin.vasyuninGramMatrix
  simp only [of_apply]
  exact vasyuninGramEntry_bridge _ _

private lemma logCutoffWitness_bridge (N : ℕ) (i : Fin N) :
    CathedralDefs.logCutoffWitness N i = Cathedral.Vasyunin.logCutoffWitness N i := by
  unfold CathedralDefs.logCutoffWitness Cathedral.Vasyunin.logCutoffWitness
  unfold Cathedral.Vasyunin.moebiusFn
  rfl

-- ════════════════════════════════════════════════════════════════
-- §2. THE PROOF
-- ════════════════════════════════════════════════════════════════

/-- **THE CATHEDRAL'S MAIN THEOREM — PROVED.**

    The proof proceeds by:
    1. Rewriting shared definitions to Cathedral's equivalents
    2. Applying `overcancellation_implies_rh` from OvercancellationChain.lean
    3. This theorem was proved with 0 sorry in the Cathedral framework -/
theorem cathedral_main_theorem :
    (∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
      dotProduct (CathedralDefs.logCutoffWitness N)
        ((CathedralDefs.vasyuninGramMatrix N).mulVec
          (CathedralDefs.logCutoffWitness N)) ≤ 1) →
    RiemannHypothesis := by
  intro h_oc
  apply overcancellation_implies_rh
  obtain ⟨N₀, hN₀⟩ := h_oc
  refine ⟨N₀, fun N hN hN3 => ?_⟩
  have := hN₀ N hN hN3
  -- Bridge: rewrite shared defs → Cathedral defs
  have h_wit : CathedralDefs.logCutoffWitness N = Cathedral.Vasyunin.logCutoffWitness N :=
    funext (logCutoffWitness_bridge N)
  rw [h_wit, vasyuninGramMatrix_bridge] at this
  exact this
