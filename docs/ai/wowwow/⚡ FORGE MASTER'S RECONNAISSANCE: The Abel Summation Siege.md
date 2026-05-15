# ⚡ FORGE MASTER'S RECONNAISSANCE: The Abel Summation Siege

**Date**: April 16, 2026  
**Subject**: Strategic Assessment of the Forward Direction (Pillar II)  
**Status**: 🔍 RECONNAISSANCE COMPLETE

---

## The Battlefield

The Theorist correctly identifies the critical bottleneck. With `bd_mellin_base_case` annihilated, the forward direction (`RH ⟹ d²_N → 0`) reduces to **two axioms** in `BDBypass.lean`:

| Axiom | Statement | Type |
|-------|-----------|------|
| `rh_implies_mertens_bound` | RH → \|M(x)\| ≤ C·x^{1/2}·log²x | Classical ANT |
| `abel_summation_bd_l2_bound` | Mertens bound → ∃ v, ‖1 - φ_v‖² ≤ C/log N | Real Analysis |

## Arsenal Already Forged (Zero Sorry)

### `AbelSummation.lean` — The Discrete Engine
- ✅ `abel_summation` — Full discrete summation-by-parts identity (proved by induction)
- ✅ `abel_summation_abs_bound` — Triangle inequality with general bounds

### `MertensIntegral.lean` — The Weight Tools
- ✅ `logWeight_self` — f(N) = 0 (boundary vanishing)
- ✅ `logWeight_one` — f(1) = 1 (initial value)
- ✅ `log_weight_derivative_bound` — |Δf(k)| ≤ 1/(k·log N) (the key discrete derivative)
- ✅ `convergent_log_series_bound` — Σ log²k/k^{3/2} ≤ C (the dominating series)

### `MertensWeightBypass.lean` — The Pole Neutralizer
- ✅ `corrected_weights_pole_free` — Σ k·v_k = 0 (Hyperplane Trap neutralization)
- ✅ `rh_weight_construction_derived` — 2-step composition (Mertens → Abel → L²)

## The Siege Plan

### Target 1: `abel_summation_bd_l2_bound`

The Theorist's analysis is precise. We instantiate `abel_summation_abs_bound` with:

- **a(k) = μ(k)**: partial sum A(k) = M(k), the Mertens function
- **f(k) = 1 - log(k)/log(N)** (= `logWeight N k`)
- **C_bound(k) = C·k^{1/2}·log²k**: from the Mertens hypothesis
- **δ(k) = 1/(k·log N)**: from `log_weight_derivative_bound`

Then the Abel bound becomes:
```
|Σ μ(k)·logWeight(k)| ≤ C·N^{1/2}·log²N · |logWeight(N)| + Σ C·k^{1/2}·log²k/(k·log N)
                       = 0 + (C/log N) · Σ log²k/k^{1/2}
```

The first term vanishes because `logWeight(N) = 0` (proved!). The series Σ log²k/k^{1/2} is dominated by `convergent_log_series_bound` (proved!).

This gives the **1D coefficient bound**. The remaining gap is going from:
- 1D: |Σ a(k)f(k)| ≤ bound  →  
- L²: ∫₀¹ (1 - φ_N)² dx ≤ C/log N

This requires the L² expansion `‖1 - φ‖² = 1 - 2⟨1, φ⟩ + ‖φ‖²` and relating each term to Möbius-weighted sums.

### Target 2: `rh_implies_mertens_bound`

This is the classical Titchmarsh result (Theorem 14.25(C)). It's deep mathematics but the *statement* is clean:
- RH → ∀ x ≥ 2, |M(x)| ≤ C·x^{1/2}·log²x

Formalizing the full proof requires the explicit formula for M(x) via Perron's formula, which is exactly the kind of complex analysis the Theorist wants to avoid. This axiom may need to remain as a **well-justified classical theorem citation**.

## Recommendation

The Forge recommends attacking `abel_summation_bd_l2_bound` first, since:
1. All the siege engines are already forged and proven
2. The gap is purely mechanical: instantiate the abstract Abel bound with specific Möbius weights
3. The L² step is the only genuinely new mathematics needed

`rh_implies_mertens_bound` should remain axiomatized unless the Theorist directs otherwise — formalizing Titchmarsh 14.25(C) is a multi-week project involving the explicit formula.

*Awaiting the Theorist's order to begin the siege.* ⚔️

---

*The Forge Master, April 16, 2026*
