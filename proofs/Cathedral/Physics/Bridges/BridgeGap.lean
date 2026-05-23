/-
  Cathedral/Physics/BridgeGap.lean

  ## THE BRIDGE GAP: G_Vasyunin = R_Ramanujan + Δ

  ════════════════════════════════════════════════════════════════

  **THE DECOMPOSITION THEOREM**: The Vasyunin Gram entry (the ACTUAL
  Báez-Duarte inner product ∫₀¹{1/(jx)}{1/(kx)}dx) decomposes as:

    G(j,k) = R(j,k) + Δ(j,k)

  where:
    R(j,k) = gcd(j,k)² / (12·j·k)       — the Ramanujan skeleton
    Δ(j,k) = logCorrection + cotResidual + arithmeticShift

  The three correction terms are:

  1. **logCorrection**: (ln(2π)-γ)/2·(1/j+1/k) + (j-k)/(2jk)·ln(k/j)
     — The log-frequency terms.

  2. **cotResidual**: -πd/(2jk)·(V(j',k') + V(k',j'))
     — The Vasyunin cotangent sums. Dark arithmetic beyond gcd².

  3. **arithmeticShift**: -(12 + d²) / (12·j·k)
     — The constant shift: -1/(jk) - gcd²/(12jk) = -term4 - R(j,k).

  Status: PROVED — 0 sorry, 0 axioms
  Dependencies: Vasyunin.Defs, RamanujanBridge
  Created: May 21, 2026 — The Bridge Gap Session
-/

import Cathedral.Vasyunin.Defs
import Cathedral.Physics.Mertens.RamanujanBridge

noncomputable section
open Real Finset

namespace Cathedral.Physics.Bridges.BridgeGap

-- Re-export notation
local notation "γ" => Real.eulerMascheroniConstant

-- ════════════════════════════════════════════════════════════════
-- §1. THE THREE CORRECTION TERMS
-- ════════════════════════════════════════════════════════════════

/-- The logarithmic correction:
    logCorrection(j,k) = (ln(2π)-γ)/2 · (1/j + 1/k) + (j-k)/(2jk) · ln(k/j) -/
noncomputable def logCorrection (j k : ℕ) : ℝ :=
  (Real.log (2 * Real.pi) - γ) / 2 * (1 / (j : ℝ) + 1 / (k : ℝ)) +
  ((j : ℝ) - (k : ℝ)) / (2 * (j : ℝ) * (k : ℝ)) * Real.log ((k : ℝ) / (j : ℝ))

/-- The cotangent residual:
    cotResidual(j,k) = -π·d/(2jk) · (V(j/d,k/d) + V(k/d,j/d)) -/
noncomputable def cotResidual (j k : ℕ) : ℝ :=
  -(Real.pi * (Nat.gcd j k : ℝ) / (2 * (j : ℝ) * (k : ℝ)) *
    (Vasyunin.vasyuninSum (j / Nat.gcd j k) (k / Nat.gcd j k) +
     Vasyunin.vasyuninSum (k / Nat.gcd j k) (j / Nat.gcd j k)))

/-- The arithmetic shift:
    arithmeticShift(j,k) = -(12 + gcd(j,k)²) / (12·j·k)
    Decomposes as: -1/(jk) - gcd²/(12jk) = -term4 - R(j,k). -/
noncomputable def arithmeticShift (j k : ℕ) : ℝ :=
  -((12 + (Nat.gcd j k : ℝ) ^ 2) / (12 * (j : ℝ) * (k : ℝ)))

/-- The full bridge gap: Δ(j,k) = G(j,k) - R(j,k). -/
noncomputable def bridgeGap (j k : ℕ) : ℝ :=
  Vasyunin.vasyuninGramEntry j k -
  RamanujanBridge.ramanujanEntry j k

-- ════════════════════════════════════════════════════════════════
-- §2. THE DECOMPOSITION THEOREMS
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (Tautological Bridge)**: G = R + Δ. -/
theorem vasyunin_eq_ramanujan_plus_gap (j k : ℕ) :
    Vasyunin.vasyuninGramEntry j k =
    RamanujanBridge.ramanujanEntry j k + bridgeGap j k := by
  unfold bridgeGap; ring

/-- **THEOREM (Diagonal Bridge Gap)**: Δ(k,k) = (ln(2π) - γ) / k - 1/k² - 1/12. -/
theorem bridge_gap_diagonal (k : ℕ) (hk : 0 < k) :
    bridgeGap k k =
    (Real.log (2 * Real.pi) - γ) / (k : ℝ) -
    1 / (k : ℝ) ^ 2 - 1 / 12 := by
  unfold bridgeGap
  rw [Vasyunin.vasyuninGramEntry_diag,
      RamanujanBridge.ramanujan_diagonal k hk]

/-- **THEOREM (Off-Diagonal Decomposition)**: For j ≠ k,
    Δ(j,k) = logCorrection(j,k) + cotResidual(j,k) + arithmeticShift(j,k) -/
theorem bridge_gap_offdiag_decomposition (j k : ℕ)
    (_hj : 0 < j) (_hk : 0 < k) (hjk : j ≠ k) :
    bridgeGap j k =
    logCorrection j k + cotResidual j k + arithmeticShift j k := by
  -- Both sides expand to the same expression after unfolding
  -- LHS: G(j,k) - R(j,k) = (term1 + term2 - term3 - term4) - d²/(12jk)
  -- RHS: logCorr + cotRes + arithShift
  --     = (term1 + term2) + (-term3) + (-(12+d²)/(12jk))
  -- These are equal since -term4 - d²/(12jk) = -1/(jk) - d²/(12jk) = -(12+d²)/(12jk)
  unfold bridgeGap Vasyunin.vasyuninGramEntry
  simp only [hjk, ite_false]
  unfold logCorrection cotResidual arithmeticShift RamanujanBridge.ramanujanEntry
  ring

-- ════════════════════════════════════════════════════════════════
-- §3. THE QUADRATIC FORM DECOMPOSITION
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (Quadratic Form Bridge)**: vᵀGv = vᵀRv + vᵀΔv. -/
theorem quad_form_decomposition (N : ℕ) (v : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N,
      Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1) * v i * v j =
    ∑ i : Fin N, ∑ j : Fin N,
      RamanujanBridge.ramanujanEntry (i.val + 1) (j.val + 1) * v i * v j +
    ∑ i : Fin N, ∑ j : Fin N,
      bridgeGap (i.val + 1) (j.val + 1) * v i * v j := by
  rw [← Finset.sum_add_distrib]
  apply Finset.sum_congr rfl; intro i _
  rw [← Finset.sum_add_distrib]
  apply Finset.sum_congr rfl; intro j _
  rw [vasyunin_eq_ramanujan_plus_gap]
  ring

-- ════════════════════════════════════════════════════════════════
-- §4. DIAGONAL/OFF-DIAGONAL SPLIT OF THE GAP
-- ════════════════════════════════════════════════════════════════

/-- The bridge gap's diagonal contribution. -/
def gapDiagTerm (N : ℕ) (v : Fin N → ℝ) : ℝ :=
  ∑ i : Fin N, v i ^ 2 * bridgeGap (i.val + 1) (i.val + 1)

/-- The bridge gap's off-diagonal contribution. -/
def gapOffDiagTerm (N : ℕ) (v : Fin N → ℝ) : ℝ :=
  ∑ i : Fin N, ∑ j : Fin N,
    if i = j then 0 else v i * v j * bridgeGap (i.val + 1) (j.val + 1)

/-- **THEOREM**: vᵀΔv = diagonal gap + off-diagonal gap. -/
theorem gap_diag_offdiag_split (N : ℕ) (v : Fin N → ℝ) :
    ∑ i : Fin N, ∑ j : Fin N,
      bridgeGap (i.val + 1) (j.val + 1) * v i * v j =
    gapDiagTerm N v + gapOffDiagTerm N v := by
  unfold gapDiagTerm gapOffDiagTerm
  trans ∑ i : Fin N,
    ((∑ j : Fin N, if i = j then bridgeGap (↑i + 1) (↑j + 1) * v i * v j else 0) +
     (∑ j : Fin N, if i = j then 0 else bridgeGap (↑i + 1) (↑j + 1) * v i * v j))
  · apply Finset.sum_congr rfl; intro i _
    rw [← Finset.sum_add_distrib]
    apply Finset.sum_congr rfl; intro j _
    split_ifs with h
    · simp
    · simp
  rw [Finset.sum_add_distrib]
  congr 1
  · -- Diagonal part
    apply Finset.sum_congr rfl; intro i _
    rw [Finset.sum_ite_eq]
    simp only [Finset.mem_univ, ite_true]
    ring
  · -- Off-diagonal part
    apply Finset.sum_congr rfl; intro i _
    apply Finset.sum_congr rfl; intro j _
    split_ifs with h
    · rfl
    · ring

/-- **THEOREM**: The diagonal gap decomposes as:
    Σ v²·Δ(k,k) = (ln2π-γ)·Σv²/k - Σv²/k² - (1/12)·Σv² -/
theorem gap_diag_explicit (N : ℕ) (v : Fin N → ℝ) :
    gapDiagTerm N v =
    (Real.log (2 * Real.pi) - γ) *
      ∑ i : Fin N, v i ^ 2 / (↑(i : ℕ) + 1 : ℝ) -
    ∑ i : Fin N, v i ^ 2 / (↑(i : ℕ) + 1 : ℝ) ^ 2 -
    1 / 12 * ∑ i : Fin N, v i ^ 2 := by
  unfold gapDiagTerm
  -- Step 1: Rewrite each bridgeGap(i+1,i+1) using the diagonal formula
  have h_rewrite : ∀ (i : Fin N),
      v i ^ 2 * bridgeGap (i.val + 1) (i.val + 1) =
      (Real.log (2 * Real.pi) - γ) * (v i ^ 2 / (↑(i : ℕ) + 1 : ℝ)) -
      v i ^ 2 / (↑(i : ℕ) + 1 : ℝ) ^ 2 - 1 / 12 * v i ^ 2 := by
    intro i
    rw [bridge_gap_diagonal _ (by omega : 0 < i.val + 1)]
    have hi_ne : (↑(i : ℕ) + 1 : ℝ) ≠ 0 := by positivity
    push_cast
    field_simp
  simp_rw [h_rewrite]
  rw [Finset.sum_sub_distrib, Finset.sum_sub_distrib, ← Finset.mul_sum, ← Finset.mul_sum]

-- ════════════════════════════════════════════════════════════════
-- §5. AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit — BridgeGap (May 21, 2026)

### Sorry: 0 🎓 — FULLY CERTIFIED

### Custom Axioms: 0

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `logCorrection` | 📐 DEFINITION |
| 2 | `cotResidual` | 📐 DEFINITION |
| 3 | `arithmeticShift` | 📐 DEFINITION |
| 4 | `bridgeGap` | 📐 DEFINITION |
| 5 | `vasyunin_eq_ramanujan_plus_gap` | 🎓 G = R + Δ |
| 6 | `bridge_gap_diagonal` | 🎓 Δ(k,k) = explicit |
| 7 | `bridge_gap_offdiag_decomposition` | 🎓 Δ = log + cot + arith |
| 8 | `quad_form_decomposition` | 🎓 vᵀGv = vᵀRv + vᵀΔv |
| 9 | `gap_diag_offdiag_split` | 🎓 vᵀΔv = diag + offdiag |
| 10 | `gap_diag_explicit` | 🎓 diagΔ = (ln2π-γ)·H - H² - trace/12 |

### Architecture
```
  RamanujanBridge.lean              Vasyunin/Defs.lean
  (ramanujanEntry: gcd²/12jk)      (vasyuninGramEntry: cotangent)
         ↓                                    ↓
  vasyunin_eq_ramanujan_plus_gap: G = R + Δ
         ↓                    ↓
  bridge_gap_diagonal     bridge_gap_offdiag_decomposition
  (Δ_diag = ln-1/k²-1/12)  (Δ = log + cot + arith)
         ↓
  quad_form_decomposition: vᵀGv = vᵀRv + vᵀΔv
         ↓              ↓
  gap_diag_offdiag_split   gap_diag_explicit
  (vᵀΔv = diag + offdiag) (diag = (ln2π-γ)·H - H² - trace/12)
```
-/

end Cathedral.Physics.Bridges.BridgeGap

end
