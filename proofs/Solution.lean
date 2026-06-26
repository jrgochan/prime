/-
  Solution.lean — The Cathedral's Proof

  ════════════════════════════════════════════════════════════════

  This file provides the proof for cathedral_main_theorem
  declared in Challenge.lean.

  The proof imports Challenge.lean (to reuse its definitions)
  and the Cathedral framework (to connect to the formal proof).

  Format: leanprover/comparator convention.
  The theorem type is identical to Challenge.lean because we
  import and reuse Challenge's definitions directly.

  Created: June 23, 2026 — Port 22 Day + 1
  Refactored: June 25, 2026 — comparator compatibility
-/

import Challenge
import Cathedral.Assembly.OvercancellationChain
import Cathedral.Wall

noncomputable section
open Real Matrix Finset Filter ArithmeticFunction Cathedral.Vasyunin

-- ════════════════════════════════════════════════════════════════
-- §1. DEFINITION BRIDGE
-- ════════════════════════════════════════════════════════════════

/-! We show that Challenge's definitions (in CathedralChallenge namespace)
    are definitionally equal to the Cathedral's definitions.
    Since both define identical computations, this follows by rfl. -/

private lemma vasyuninGramEntry_bridge (j k : ℕ) :
    CathedralChallenge.vasyuninGramEntry j k = Cathedral.Vasyunin.vasyuninGramEntry j k := by
  unfold CathedralChallenge.vasyuninGramEntry Cathedral.Vasyunin.vasyuninGramEntry
  unfold CathedralChallenge.vasyuninSum Cathedral.Vasyunin.vasyuninSum
  unfold CathedralChallenge.cotFn Cathedral.Vasyunin.cot
  rfl

private lemma vasyuninGramMatrix_bridge (N : ℕ) :
    CathedralChallenge.vasyuninGramMatrix N = Cathedral.Vasyunin.vasyuninGramMatrix N := by
  ext i j
  unfold CathedralChallenge.vasyuninGramMatrix Cathedral.Vasyunin.vasyuninGramMatrix
  simp only [of_apply]
  exact vasyuninGramEntry_bridge _ _

private lemma logCutoffWitness_bridge (N : ℕ) (i : Fin N) :
    CathedralChallenge.logCutoffWitness N i = Cathedral.Vasyunin.logCutoffWitness N i := by
  unfold CathedralChallenge.logCutoffWitness Cathedral.Vasyunin.logCutoffWitness
  unfold Cathedral.Vasyunin.moebiusFn
  rfl

-- ════════════════════════════════════════════════════════════════
-- §2. THE PROOF
-- ════════════════════════════════════════════════════════════════

/-- **THE CATHEDRAL'S MAIN THEOREM — PROVED.**

    The proof proceeds by:
    1. Rewriting Challenge's definitions to Cathedral's equivalents
    2. Applying `overcancellation_implies_rh` from OvercancellationChain.lean
    3. This theorem was proved with 0 sorry in the Cathedral framework -/
theorem cathedral_main_theorem :
    (∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ → N ≥ 3 →
      dotProduct (CathedralChallenge.logCutoffWitness N)
        ((CathedralChallenge.vasyuninGramMatrix N).mulVec
          (CathedralChallenge.logCutoffWitness N)) ≤ 1) →
    RiemannHypothesis := by
  intro h_oc
  apply overcancellation_implies_rh
  obtain ⟨N₀, hN₀⟩ := h_oc
  refine ⟨N₀, fun N hN hN3 => ?_⟩
  have := hN₀ N hN hN3
  -- Bridge: rewrite Challenge defs → Cathedral defs
  have h_wit : CathedralChallenge.logCutoffWitness N = Cathedral.Vasyunin.logCutoffWitness N :=
    funext (logCutoffWitness_bridge N)
  rw [h_wit, vasyuninGramMatrix_bridge] at this
  exact this
