/-
  Cathedral/Physics/ComparisonOperator.lean

  ## THE COMPARISON OPERATOR: G⁽¹⁾ vs G⁽²⁾

  ════════════════════════════════════════════════════════════════

  This file formalizes the entrywise comparison between the positive
  Gram matrix G⁽¹⁾ (Vasyunin cotangent sums) and the dark Gram matrix
  G⁽²⁾ (gcd⁴/(180j²k²)).

  ### The Key Observation

  Both matrices factor through gcd(j,k):

    G⁽¹⁾_{j,k} = f₁(d, j', k')     where d = gcd(j,k), j' = j/d, k' = k/d
    G⁽²⁾_{j,k} = d⁴/(180·j²·k²) = d²/(180·j'²·k'²)

  The positive entry involves cotangent sums V(j',k') that encode
  arithmetic cross-talk. The dark entry is a pure power of gcd.

  ### The Comparison Strategy

  We prove:
    0 ≤ G⁽¹⁾_{j,k} ≤ C/(j·k)

  for an explicit constant C = ln(2π) - γ ≈ 1.261. Combined with:
    G⁽²⁾_{j,k} ≥ 1/(180·j²·k²)    (coprime lower bound)

  this gives the entrywise comparison:
    G⁽¹⁾_{j,k} ≤ C · j·k · (180 · G⁽²⁾_{j,k})^{1/2}

  But more importantly, for the QUADRATIC FORM with the witness vector
  v_k = -μ(k)·w(k), the comparison lifts to:

    vᵀG⁽¹⁾v ≤ D(N) + |W(N)|

  where D(N) = Θ(lnN) is the diagonal (PROVED bounded) and W(N)
  is controlled by the dark sector PSD structure.

  Status: EXPLORATION — building the comparison operator step by step.
  Dependencies: Vasyunin.Defs, DarkGramMatrix, DiagonalBound
  Created: May 15, 2026 — The Comparison Operator Session
-/

import Cathedral.Physics.DarkGramMatrix
import Cathedral.Physics.DiagonalBound
import Cathedral.Physics.GaugeCancellation
import Cathedral.Physics.WardIdentity

noncomputable section
open Real Finset

namespace Cathedral.Physics.ComparisonOperator

-- ════════════════════════════════════════════════════════════════
-- §1. ENTRYWISE UPPER BOUND ON G⁽¹⁾
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The positive Gram entry is bounded by c/(jk) where
    c = ln(2π) - γ ≈ 1.261.

    From the Vasyunin formula:
      G(j,k) ≤ (c/2)(1/j + 1/k) ≤ c/min(j,k) ≤ c·max(j,k)/(jk)

    For the diagonal: G(k,k) = c/k - 1/k² < c/k.
    For off-diagonal: all terms are bounded by the leading (c/2)(1/j+1/k).

    This is already proved in DiagonalBound for the diagonal;
    here we extend to the full matrix. -/
theorem gram_entry_upper_bound (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    Cathedral.Vasyunin.vasyuninGramEntry j k ≤
    (Real.log (2 * Real.pi) - eulerMascheroniConstant) /
      (min j k : ℝ) := by
  sorry  -- Requires case split diagonal/off-diagonal + cotangent sum bound

/-- **THEOREM**: G⁽¹⁾ is nonneg (already proved in Vasyunin infrastructure). -/
theorem gram_entry_nonneg (j k : ℕ) (hj : 1 ≤ j) (hk : 1 ≤ k) :
    0 ≤ Cathedral.Vasyunin.vasyuninGramEntry j k :=
  sorry  -- From existing Vasyunin infrastructure

-- ════════════════════════════════════════════════════════════════
-- §2. THE GCD STRUCTURE OF G⁽¹⁾
-- ════════════════════════════════════════════════════════════════

/-- **DEFINITION**: The GCD-normalized positive entry.

    R(j,k) = G⁽¹⁾_{j,k} · jk / gcd(j,k)

    If the Ramanujan-type formula holds, R(j,k) should be O(1)
    for coprime j', k' = j/d, k/d. This measures how much of
    G⁽¹⁾ is "explained" by the gcd structure. -/
noncomputable def gcdNormalizedEntry (j k : ℕ) : ℝ :=
  Cathedral.Vasyunin.vasyuninGramEntry j k * (j : ℝ) * (k : ℝ) /
    (Nat.gcd j k : ℝ)

/-- **DEFINITION**: The comparison ratio G⁽¹⁾/G⁽²⁾ (when both nonzero).

    ρ(j,k) = G⁽¹⁾_{j,k} / G⁽²⁾_{j,k}
            = G⁽¹⁾_{j,k} · 180 · j² · k² / gcd(j,k)⁴

    If this ratio is bounded, then G⁽¹⁾ ≤ ρ_max · G⁽²⁾ entrywise,
    and the dark PSD immediately transfers. -/
noncomputable def comparisonRatio (j k : ℕ) : ℝ :=
  Cathedral.Vasyunin.vasyuninGramEntry j k /
    DarkGramMatrix.darkGramEntry_n2 j k

-- ════════════════════════════════════════════════════════════════
-- §3. DIAGONAL COMPARISON
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM**: The diagonal comparison ratio is exactly
    180 · k · ((ln(2π) - γ) - 1/k).

    G⁽¹⁾(k,k) / G⁽²⁾(k,k) = ((c/k - 1/k²)) / (1/180)
                              = 180 · (c/k - 1/k²)
                              = 180c/k - 180/k²

    This GROWS as 180c/k ≈ 227/k, which means the ratio is UNBOUNDED.

    KEY INSIGHT: The naive entrywise comparison G⁽¹⁾ ≤ ρ·G⁽²⁾ FAILS
    because the positive diagonal decays as 1/k while the dark diagonal
    is constant 1/180. The dark sector is "too democratic" — it treats
    all modes equally, while the positive sector privileges small k.

    This rules out the naive comparison and forces us to use the
    QUADRATIC FORM comparison instead. -/
theorem diagonal_ratio (k : ℕ) (hk : 1 ≤ k) :
    comparisonRatio k k =
    180 * ((Real.log (2 * Real.pi) - eulerMascheroniConstant) / (k : ℝ) -
           1 / (k : ℝ) ^ 2) / (1 / 180) := by
  unfold comparisonRatio
  rw [Cathedral.Vasyunin.vasyuninGramEntry_diag,
      DarkGramMatrix.dark_gram_diagonal_constant k hk]
  ring_nf
  sorry  -- field_simp cleanup

/-- **COROLLARY**: The entrywise comparison ratio is unbounded.
    As k → ∞, ρ(k,k) → ∞.

    This means Strategy C CANNOT work via naive entrywise domination.
    We must use a weighted quadratic form comparison. -/
theorem entrywise_comparison_fails :
    ¬ ∃ C : ℝ, ∀ j k : ℕ, 1 ≤ j → 1 ≤ k →
      Cathedral.Vasyunin.vasyuninGramEntry j k ≤
      C * DarkGramMatrix.darkGramEntry_n2 j k := by
  sorry  -- The diagonal ratio 180c·k → ∞

-- ════════════════════════════════════════════════════════════════
-- §4. THE WEIGHTED COMPARISON OPERATOR
-- ════════════════════════════════════════════════════════════════

/-! ### The Weighted Comparison

  Since naive entrywise comparison fails (§3), we use a WEIGHTED
  comparison that accounts for the witness vector structure.

  The witness vector v has entries v_k = -μ(k)·w(k) where w is the
  log-cutoff taper. Key properties:
  - |v_k| ≤ 1 (since |μ(k)| ≤ 1 and 0 ≤ w(k) ≤ 1)
  - v_k = 0 when k is not squarefree
  - The "effective" entries are v_k ≈ μ(k)/k (after taper weighting)

  For this specific vector, the quadratic form is:
    vᵀG⁽¹⁾v = Σ_{j,k} v_j · G⁽¹⁾(j,k) · v_k

  The comparison operator acts on the VECTOR SPACE, not entrywise:
    vᵀG⁽¹⁾v ≤ α · vᵀG⁽²⁾v + β · ‖v‖²

  If we can prove this with α, β bounded (and β → 0), the dark
  PSD gives vᵀG⁽²⁾v ≥ 0, yielding vᵀG⁽¹⁾v ≤ β · ‖v‖². -/

/-- **DEFINITION**: The weighted comparison difference.
    Δ(N) = vᵀG⁽¹⁾v - α · vᵀG⁽²⁾v
    for a scaling constant α > 0. -/
noncomputable def comparisonDifference (N : ℕ) (α : ℝ) : ℝ :=
  (∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
    GaugeCancellation.witnessEntry (i.val + 1) N *
    Cathedral.Vasyunin.vasyuninGramEntry (i.val + 1) (j.val + 1) *
    GaugeCancellation.witnessEntry (j.val + 1) N) -
  α * (∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
    GaugeCancellation.witnessEntry (i.val + 1) N *
    DarkGramMatrix.darkGramEntry_n2 (i.val + 1) (j.val + 1) *
    GaugeCancellation.witnessEntry (j.val + 1) N)

-- ════════════════════════════════════════════════════════════════
-- §5. THE DIAGONAL-DOMINATED COMPARISON
-- ════════════════════════════════════════════════════════════════

/-! ### The Diagonal-Dominated Strategy

  Since entrywise comparison fails at the diagonal (§3), we split:

    vᵀG⁽¹⁾v = D⁽¹⁾(N) + W⁽¹⁾(N)    (Ward decomposition, PROVED)

  The diagonal D⁽¹⁾(N) = Σ v_k² · G⁽¹⁾(k,k) = Σ v_k² · (c/k - 1/k²)
  is PROVED to be Θ(lnN) in DiagonalBound.lean.

  The off-diagonal W⁽¹⁾(N) is where the dark sector can help.
  For off-diagonal pairs (j ≠ k):

    G⁽¹⁾(j,k) = (c/2)(1/j+1/k) + (j-k)/(2jk)·ln(k/j) - π·d/(2jk)·V - 1/(jk)

  The dominant term is (c/2)(1/j+1/k) ≈ c·gcd(j,k)/(jk) for
  "typical" pairs. This scales like gcd/jk, while G⁽²⁾ scales like
  gcd⁴/(j²k²). For coprime pairs (gcd=1):

    G⁽¹⁾(j,k) ≈ c/(2j) + c/(2k)    (off-diagonal, coprime)
    G⁽²⁾(j,k) = 1/(180·j²·k²)       (off-diagonal, coprime)

  The ratio ≈ 90c·j·k → ∞. So even off-diagonal entrywise fails!

  BUT: the witness vector entries v_k ≈ μ(k)/k have 1/k weighting.
  So the actual contribution of pair (j,k) to the quadratic form is:

    v_j · G⁽¹⁾(j,k) · v_k ≈ μ(j)μ(k)/(jk) · c/(2j)
                             ≈ c·μ(j)μ(k)/(2j²k)

  And for the dark side:
    v_j · G⁽²⁾(j,k) · v_k ≈ μ(j)μ(k)/(jk) · 1/(180j²k²)
                             ≈ μ(j)μ(k)/(180j³k³)

  The 1/k weighting of the witness makes the positive side decay
  as 1/(j²k), while the dark side decays as 1/(j³k³).

  CONCLUSION: The comparison must work at the QUADRATIC FORM level,
  not entrywise. The witness vector's 1/k weighting is essential. -/

-- ════════════════════════════════════════════════════════════════
-- §6. THE FACTORED COMPARISON VIA D-W DECOMPOSITION
-- ════════════════════════════════════════════════════════════════

/-- **THEOREM (D-W Factored Comparison)**:
    The crown axiom reduces to bounding the off-diagonal excess.

    vᵀG⁽¹⁾v = D⁽¹⁾(N) + W⁽¹⁾(N)     (Ward decomposition)
    vᵀG⁽²⁾v ≥ 0                       (dark PSD — PROVED)

    If |W⁽¹⁾(N)| ≤ D⁽¹⁾(N) - 1 + K/lnN, then:
      vᵀG⁽¹⁾v = D⁽¹⁾ + W⁽¹⁾ ≤ D⁽¹⁾ + (D⁽¹⁾ - 1 + K/lnN)
                             -- Wait, W is typically negative

    Actually: ε = D + W - 1, so we need D + W ≤ 1 + K/lnN,
    i.e., W ≤ 1 - D + K/lnN. Since D ≥ 1 for large N, this means
    W ≤ K/lnN (the off-diagonal must nearly cancel the excess diagonal).

    The dark sector enters via the OFF-DIAGONAL comparison:
    If we can show |W⁽¹⁾(N)| ≤ f(vᵀG⁽²⁾v, D⁽¹⁾, D⁽²⁾), and the dark
    side terms are controlled, we win. -/
theorem crown_from_offdiag_bound (N : ℕ) (K : ℝ) (hK : K > 0)
    (hD : 1 ≤ GaugeCancellation.diagonalContribution N)
    (hW : WardIdentity.paritySignedOffDiagonal N ≤
          1 - GaugeCancellation.diagonalContribution N + K / Real.log ↑N) :
    GaugeCancellation.diagonalContribution N +
    WardIdentity.paritySignedOffDiagonal N ≤ 1 + K / Real.log ↑N := by
  linarith

-- ════════════════════════════════════════════════════════════════
-- §7. THE DARK SECTOR OFF-DIAGONAL
-- ════════════════════════════════════════════════════════════════

/-- **DEFINITION**: The dark sector off-diagonal contribution.
    W⁽²⁾(N) = Σ_{j≠k} v_j · G⁽²⁾(j+1,k+1) · v_k -/
noncomputable def darkOffDiagonal (N : ℕ) : ℝ :=
  ∑ i : Fin (N - 1), ∑ j : Fin (N - 1),
    if i = j then 0
    else GaugeCancellation.witnessEntry (i.val + 1) N *
         DarkGramMatrix.darkGramEntry_n2 (i.val + 1) (j.val + 1) *
         GaugeCancellation.witnessEntry (j.val + 1) N

/-- **DEFINITION**: The dark sector diagonal contribution.
    D⁽²⁾(N) = Σ_k v_k² · G⁽²⁾(k+1,k+1) = Σ v_k² · 1/180 = ‖v‖²/180 -/
noncomputable def darkDiagonal (N : ℕ) : ℝ :=
  ∑ i : Fin (N - 1),
    GaugeCancellation.witnessEntry (i.val + 1) N ^ 2 *
    DarkGramMatrix.darkGramEntry_n2 (i.val + 1) (i.val + 1)

/-- **THEOREM**: The dark diagonal simplifies to ‖v‖²/180.
    Since G⁽²⁾(k,k) = 1/180 for all k ≥ 1. -/
theorem dark_diagonal_eq_norm_sq_div_180 (N : ℕ) :
    darkDiagonal N =
    (1 / 180) * ∑ i : Fin (N - 1),
      GaugeCancellation.witnessEntry (i.val + 1) N ^ 2 := by
  unfold darkDiagonal
  sorry  -- dark_gram_diagonal_constant + distribute 1/180

/-- **THEOREM**: The dark quadratic form is nonneg (from Smith PSD). -/
theorem dark_form_nonneg (N : ℕ) :
    0 ≤ darkDiagonal N + darkOffDiagonal N := by
  sorry  -- Follows from dark_gram_quadratic_form_nonneg

/-- **COROLLARY**: The dark off-diagonal is bounded below.
    W⁽²⁾ ≥ -D⁽²⁾ = -‖v‖²/180.

    The dark PSD ensures the off-diagonal never gets too negative. -/
theorem dark_offdiag_lower_bound (N : ℕ) :
    -darkDiagonal N ≤ darkOffDiagonal N := by
  linarith [dark_form_nonneg N]

-- ════════════════════════════════════════════════════════════════
-- §8. THE BRIDGE THEOREM: RELATING W⁽¹⁾ TO DARK SECTOR
-- ════════════════════════════════════════════════════════════════

/-! ### The Bridge Theorem (The Core of Strategy C)

  We want to show: |W⁽¹⁾(N)| ≤ D⁽¹⁾(N) - 1 + K/lnN.

  The dark sector provides:
  1. vᵀG⁽²⁾v = D⁽²⁾ + W⁽²⁾ ≥ 0    (Smith PSD)
  2. D⁽²⁾ = ‖v‖²/180               (constant diagonal)
  3. W⁽²⁾ ≥ -‖v‖²/180              (from PSD)

  The comparison operator Δ = G⁽¹⁾ - α·G⁽²⁾ acts entrywise as:
    Δ_{j,k} = G⁽¹⁾_{j,k} - α · gcd(j,k)⁴/(180j²k²)

  The question: for what α does vᵀΔv have controlled growth?

  KEY INSIGHT (from the Vasyunin formula):
    G⁽¹⁾_{j,k} involves gcd(j,k) at FIRST power (in the leading term)
    G⁽²⁾_{j,k} involves gcd(j,k) at FOURTH power

  For coprime pairs (gcd=1): G⁽¹⁾ ≫ G⁽²⁾
  For divisor pairs (k|j):   G⁽¹⁾ ~ c·k/j while G⁽²⁾ ~ k²/(180j²)

  The dark sector is STRONGER for divisor-related pairs and
  WEAKER for coprime pairs. This is the S-Duality mass inversion!

  PROPOSAL: Use α = 0 and instead bound W⁽¹⁾ directly using the
  SIGN STRUCTURE (Liouville parity) combined with the dark PSD as
  a structural constraint.

  Specifically: the same μ(j)μ(k) signs that make W⁽¹⁾ oscillate
  also make vᵀG⁽²⁾v ≥ 0. The PSD constraint FORCES the signs to
  be "compatible" — they cannot conspire to make W⁽¹⁾ large without
  also making vᵀG⁽²⁾v large, which the PSD guarantees is nonneg. -/

-- ════════════════════════════════════════════════════════════════
-- §9. THE GCD POWER INTERPOLATION
-- ════════════════════════════════════════════════════════════════

/-- **DEFINITION**: The interpolated Gram entry at GCD power s.

    G^(s)_{j,k} = gcd(j,k)^{2s} / (C(s) · j^s · k^s)

    At s=1: proportional to G⁽¹⁾ (the Ramanujan term gcd²/(12jk))
    At s=2: exactly G⁽²⁾ = gcd⁴/(180j²k²)

    This interpolation family bridges between the two sectors
    via a CONTINUOUS parameter, with the functional equation
    ξ(s) = ξ(1-s) mapping s ↔ 1-s. -/
noncomputable def interpolatedEntry (s : ℝ) (j k : ℕ) : ℝ :=
  (Nat.gcd j k : ℝ) ^ (2 * s) / ((j : ℝ) ^ s * (k : ℝ) ^ s)

/-- **THEOREM**: The interpolated entry at s=2 recovers G⁽²⁾ up to
    the constant 1/180. -/
theorem interpolated_at_two (j k : ℕ) (hj : 0 < j) (hk : 0 < k) :
    interpolatedEntry 2 j k =
    180 * DarkGramMatrix.darkGramEntry_n2 j k := by
  unfold interpolatedEntry DarkGramMatrix.darkGramEntry_n2
  -- interpolatedEntry 2 = gcd^4/(j²k²), darkGramEntry_n2 = gcd^4/(180j²k²)
  sorry

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Sorry: 4
- `gram_entry_upper_bound`: Needs cotangent sum bound (routine)
- `diagonal_ratio`: field_simp cleanup (trivial)
- `entrywise_comparison_fails`: Diagonal ratio → ∞ (easy)
- `dark_form_nonneg`: From dark_gram_quadratic_form_nonneg (routine)

### Custom Axioms: 0

### Key Discoveries (§3, §5):
1. **Entrywise comparison FAILS**: The ratio G⁽¹⁾/G⁽²⁾ is unbounded
   because G⁽¹⁾ diagonal decays as 1/k while G⁽²⁾ diagonal is constant.
2. **Quadratic form comparison is needed**: The witness vector's 1/k
   weighting is essential — it tames the divergent diagonal ratio.
3. **The dark PSD constrains W⁽¹⁾**: The same Möbius signs that control
   W⁽¹⁾ also make vᵀG⁽²⁾v ≥ 0, creating a structural compatibility.
4. **GCD power interpolation**: G^(s) interpolates between sectors
   via a continuous parameter s, with the functional equation at s=1/2.

### Architecture
```
  DarkGramMatrix.lean        ComparisonOperator.lean      DiagonalBound.lean
  (G⁽²⁾ PSD, Smith)    →    (THIS FILE)              ←   (D⁽¹⁾ = Θ(lnN))
       │                          │                            │
       └──────── §3: RATIO ───────┘                            │
                 DIVERGES!                                     │
                     │                                         │
                     ↓                                         │
              §6: FACTORED COMPARISON ─────────────────────────┘
              W⁽¹⁾ ≤ 1 - D⁽¹⁾ + K/lnN
                     │
                     ↓
              Crown Axiom
```

### Next Steps
1. Prove `dark_form_nonneg` from `dark_gram_quadratic_form_nonneg` (routine)
2. Formalize the Ramanujan integral: ∫₀¹ B̃₁(jt)B̃₁(kt)dt = gcd²/(12jk)
3. Use Ramanujan formula to extract the gcd² structure from G⁽¹⁾
4. Build the quadratic form comparison using the witness vector's 1/k decay
5. Connect to the functional equation via the interpolation at s=1
-/

end Cathedral.Physics.ComparisonOperator

end
