# The Next Frontier: Pushing Toward 100% Proof Completion

*From the Local Forge Master → The Theorist & Jason*
*April 11, 2026, 7:56 PM MDT*

---

## Current State: 5 Axioms, 0 Sorry

| # | Axiom | Nature | Difficulty | Realistic? |
|---|-------|--------|-----------|-----------|
| 1 | `augmentedSchurComplement_pos` | Geometric | ⭐⭐⭐ | **YES — Best Target** |
| 2 | `log_cutoff_witness_bound` | THE RH | ⭐⭐⭐⭐⭐ | No (this IS the hypothesis) |
| 3 | `vasyunin_eq_integral` | Definitional | ⭐⭐⭐ | **YES — Diagonal First** |
| 4 | `lagarias_iff_rh` | Literature | ⭐⭐⭐⭐ | Blocked on Mathlib |
| 5 | `robin_iff_rh` | Literature | ⭐⭐⭐⭐ | Blocked on Mathlib |

---

## Axiom 1: `augmentedSchurComplement_pos` — THE BEST TARGET 🎯

### What It Says
The Schur complement of H_{N+1} w.r.t. H_N is positive: f_{N+1} has positive L² distance from span{1, f_1, ..., f_N}.

### Why It's Attackable

**CRITICAL DISCOVERY**: Mathlib already has the key theorem!

```lean
-- In Mathlib.Analysis.InnerProductSpace.GramMatrix:
theorem posDef_gram_iff_linearIndependent {v : n → E} :
    PosDef (gram 𝕜 v) ↔ LinearIndependent 𝕜 v
```

This means: **Gram PD ↔ Linear Independence**. If we prove the sawtooth functions {1, f_1, ..., f_N} are linearly independent in L²(0,1), we get H_N PD for free, which gives us the Schur complement positivity.

### The Proof Strategy

**Step 1: Connect our matrix to Mathlib's `gram`.**
Show that `augmentedGramMatrix N` equals `gram ℝ v` where `v i` is the ith function in {1, f_1, ..., f_N}. This requires `vasyunin_eq_integral` (Axiom 3) to bridge the discrete formula to the L² inner product.

**Step 2: Prove linear independence of sawtooth functions.**
The functions f_k(x) = {k/x} for distinct k are linearly independent in L²(0,1) because:
- f_k has a jump discontinuity at x = k/(k+1) of height approaching 1
- No finite linear combination of f_j (j ≠ k) can reproduce this specific jump
- More precisely: on intervals (k/(m+1), k/m], f_k is C¹ with computable derivatives

**Step 3: Apply `posDef_gram_of_linearIndependent` to get H_N PD.**

### The Dependency Chain

> [!IMPORTANT]
> **Axiom 1 depends on Axiom 3!** To connect our discrete matrix to Mathlib's `gram`, we need the integral bridge. This means we should attack Axiom 3 first.

### Estimated Effort: 2-3 sessions (after Axiom 3)

---

## Axiom 3: `vasyunin_eq_integral` — THE FOUNDATION BRIDGE

### What It Says
```lean
vasyuninGramEntry j k = ∫ x in (0:ℝ)..1, Int.fract ((j:ℝ)/x) * Int.fract ((k:ℝ)/x)
```

### Attack Strategy: Diagonal First

The diagonal case j = k is dramatically simpler:
```
∫₀¹ {j/x}² dx = (log(2π) - γ)/j - 1/j²
```

**Why diagonal first?**
- No cross-term cotangent sums (Ramanujan/Dedekind)
- Pure piecewise polynomial: on (j/(n+1), j/n], {j/x} = j/x - n
- Standard integral: ∫ (j/x - n)² dx = -j²/x + 2jn·ln(x) + n²·x
- Series sums to known constants via Stirling/digamma

**The off-diagonal case** adds:
- Two-variable piecewise decomposition (intervals where ⌊j/x⌋ and ⌊k/x⌋ are simultaneously constant)
- Cotangent sums emerge from the cross-terms
- More bookkeeping but same fundamental technique

### Mathlib Infrastructure Available
- `Int.fract` — basic fractional part ✅
- `MeasureTheory.Function.Floor` — measurability of fract ✅
- `IntervalIntegral` — Lebesgue integration ✅
- `integral_comp_mul_right` — substitution rules ✅
- `EulerMascheroni` — γ constant ✅

### Estimated Effort: 3-5 sessions (diagonal), 5-8 sessions (full)

---

## Axioms 4-5: `lagarias_iff_rh`, `robin_iff_rh` — BLOCKED

### Current Mathlib Status
- Chebyshev functions (θ, ψ): **Available** (Chebyshev.lean, by Tao et al.)
- Prime Number Theorem: **NOT in Mathlib** (Chebyshev bounds only)
- Robin's inequality: **NOT in Mathlib**
- Lagarias's inequality: **NOT in Mathlib**

### What's Needed
Both equivalences require:
1. PNT with explicit error terms
2. Mertens' theorems on ∑ 1/p
3. Detailed asymptotic analysis of σ(n)/n and H_n

### Verdict
These are **multi-year community projects**, not something we can attack in sessions. They live on the independent Robin/Lagarias front and don't affect the main Vasyunin proof chain.

> [!NOTE]
> If Axioms 4-5 are the only remaining axioms, we'd have a 3-axiom Cathedral on the main chain (Axioms 1, 2, 3) with the Robin front completely decoupled.

---

## Axiom 2: `log_cutoff_witness_bound` — THE HYPOTHESIS

This IS the Riemann Hypothesis. Attack 9 provides empirical evidence to N=50,000 with Q/ln monotonically increasing at 14.01. This axiom cannot be proved without proving RH.

---

## Recommended Path to Maximum Completion

### Phase 1: Attack Axiom 3 (Diagonal Case)
**Goal**: Prove `vasyunin_eq_integral j j` for all j ≥ 1
**Effort**: 3-5 sessions
**Impact**: Eliminates one axiom AND unlocks Axiom 1

### Phase 2: Attack Axiom 1 (via Gram ↔ LinIndep)
**Goal**: Prove `augmentedSchurComplement_pos` from linear independence
**Effort**: 2-3 sessions (requires Phase 1)
**Impact**: Eliminates the geometric axiom

### Phase 3: Attack Axiom 3 (Full Off-Diagonal)
**Goal**: Complete `vasyunin_eq_integral j k` for all j, k ≥ 1
**Effort**: 5-8 sessions
**Impact**: Fully eliminates Axiom 3

### End State After All Phases

```
Before: 5 axioms (1 geometric, 1 hypothesis, 1 bridge, 2 literature)
After:  3 axioms (1 hypothesis [= RH], 2 literature [Robin/Lagarias])
```

The main Vasyunin proof chain would contain **exactly one axiom**: the RH itself.

The Robin/Lagarias front's two literature axioms would be the only remaining axioms, and they live on an independent path that doesn't affect the core proof chain.

---

## The Nuclear Option: Can We Get to 1 Axiom?

If we drop the Robin/Lagarias front entirely (it's independent anyway), we'd have:

| Remaining | Status |
|-----------|--------|
| `log_cutoff_witness_bound` | **THE RH. Cannot be proved.** |

**A 1-axiom Cathedral where the single axiom IS the Riemann Hypothesis.**

This is achievable if Phases 1-3 succeed. The proof would read:

> *"Assuming only that the log cutoff Rayleigh quotient grows logarithmically (which IS the RH expressed as a discrete inequality), 168 theorems across 25 Lean files derive, with zero sorry, that the Nyman-Beurling distance converges to zero."*

---

## Recommendation for the Theorist

The Theorist should focus strategic thinking on:

1. **Is there a shortcut for Axiom 1 that bypasses Axiom 3?** Can we prove linear independence of sawtooth functions without going through the integral bridge? (E.g., via their discontinuity structure directly?)

2. **Does Mathlib's Chebyshev.lean help with Robin/Lagarias?** Chebyshev bounds give us θ(x) ~ x but not the precise error terms needed for Robin's inequality.

3. **What's the minimal statement of Axiom 3 we actually need?** We don't need the full off-diagonal formula. We just need `G(j,k) = ⟨f_j, f_k⟩_{L²}` to connect to Mathlib's `gram`. Could we axiomatize a weaker "our matrix IS the Gram matrix" statement?

---

*The path to a 1-axiom Cathedral is clear. The question is: how many sessions do we invest before opening the Bazaar?*

— The Local Forge Master 🔨
