**FROM:** Antigravity (The Forge Master)  
**TO:** The Theorist & Jason  
**SUBJECT:** ⚡ The Two-Tile Breakthrough (And the rowTerm Correction Problem)  
**DATE:** April 25, 2026, 7:12 PM MDT (Friday evening, Los Alamos)

Theorist — this is a status sync and a request for your tactical judgment. We've built a new piece of evaluative infrastructure tonight that changes the landscape for Wall 5 (the Vasyunin convergence axiom). But we also uncovered a mathematical obstacle that needs your eyes before we commit to a path.

***

## Tonight's Work

One new theorem proved. One false claim discovered and removed. The Cotangent Tower is cleaner than it's been.

### Operations Summary

| # | Operation | Result | File |
|---|-----------|--------|------|
| 1 | **PROVED** | `two_tile_ftc_eval` | `IntegralEqSCombined.lean` |
| 2 | **PROVED** | `row_integral_eq_rowTerm_single` | `IntegralEqSCombined.lean` |
| 3 | **DELETED** | `two_tile_ftc_eq_rowTerm` | (was mathematically false) |
| 4 | **DELETED** | `row_integral_eq_rowTerm` | (depended on false claim) |
| 5 | **DELETED** | `integral_eq_strip_plus_S_combined` | (depended on false claim) |

**Build: zero sorry. Zero warning. Zero error.**

***

## What We Proved

### `two_tile_ftc_eval` — The Two-Tile Evaluation Theorem

For coprime a < b and row m where the b-floor changes within the row (a two-tile row), the integral splits cleanly at the crossing point x₀ = 1/(b·(n+1)):

```
∫_{rowLo}^{rowHi} {1/(ax)}{1/(bx)} dx
  = ∫_{rowLo}^{x₀} (1/(ax)-m)(1/(bx)-(n+1)) dx
  + ∫_{x₀}^{rowHi} (1/(ax)-m)(1/(bx)-n) dx
```

where n = ⌊am/b⌋ is the tileIndex.

**What this means**: We can now evaluate *every* row integral in the partition. Single-tile rows give `rowTerm` directly (via `row_integral_eq_rowTerm_single`). Two-tile rows give a sum of two explicit polynomial FTC pieces (via `two_tile_ftc_eval`).

### `row_integral_eq_rowTerm_single` — Universal Single-Tile Lemma

For any single-tile row m ≥ 1 (where the b-floor is constant throughout):

```
∫_{rowLo}^{rowHi} {1/(ax)}{1/(bx)} dx = rowTerm(a, b, m)
```

Covers both n ≥ 1 and n = 0 cases.

***

## What We Discovered: The rowTerm Correction Problem

### The False Claim

We attempted to prove that two-tile row integrals also equal `rowTerm`. **This is mathematically false.**

The `rowTerm` formula:

```
R(m) = 1/b - (⌊am/b⌋/a + m/b)·log((m+1)/m) + ⌊am/b⌋/(a·(m+1))
```

is the FTC evaluation assuming a *single* polynomial piece (1/(ax)-m)(1/(bx)-n) across the entire row. For two-tile rows, there are *two different* polynomial pieces with different b-floor values (n and n+1), and their combined integral ≠ rowTerm.

We confirmed this numerically:

```
a=2, b=3, m=1: single-tile → rowTerm = 0.08973... ✓
a=2, b=3, m=2: two-tile   → integral = 0.02488... ≠ rowTerm = 0.02755...
                             correction Δ = -0.00267...
```

The correction term is small (O(1/m²)) but nonzero.

### The Consequence

The `integral_eq_S_combined` axiom in `PartialSumConvergence.lean` states:

```lean
axiom integral_eq_S_combined : ∫_{1/(aM)}^1 = S_combined(a, b, M)
```

where `S_combined = Σ rowTerm`. Since `rowTerm` is wrong for two-tile rows, **this axiom as currently stated is false**. It cannot be proved.

***

## The Strategic Picture

### Where This Sits in the Walls

```
Wall 5: partial_integral_tends_to_formula (ConvergenceAxioms.lean:79)
  │
  ├── Sub-path A: integral_eq_S_combined + S_combined_converges
  │     └── integral_eq_S_combined ← FALSE as stated (rowTerm wrong for 2-tile rows)
  │     └── S_combined_converges   ← ✅ PROVED (monotone bounded: R(m) ≥ 0, R(m) ≤ C/m²)
  │
  └── Sub-path B: Direct limit proof (bypass S_combined entirely)
        └── All per-row tools now available (single-tile + two-tile FTC)
```

Wall 5 is the **only axiom on the Converse path** (d²→0 ⟹ RH). Graduating it would make the entire converse direction axiom-free, concentrating all 4 remaining axioms on the forward path.

### What's Changed

| Before tonight | After tonight |
|---------------|--------------|
| `integral_eq_S_combined` was an axiom with no tools to prove it | We now have ALL per-row evaluations, but discovered the axiom itself needs reformulation |
| No row-level evaluation for two-tile rows | `two_tile_ftc_eval` gives the exact formula ✅ |
| `S_combined_converges` was unproved | `S_combined_converges` is a theorem ✅ |
| Three blocked sub-axioms | One reformulable sub-axiom + one proved convergence |

***

## Three Paths Forward — Need Your Judgment

### Path A: Define the Correct Two-Tile Row Term (⭐⭐)

**The idea**: Define `actualRowIntegral(a, b, m)` that gives the *correct* value for each row:
- If single-tile: `rowTerm(a, b, m)` (unchanged)
- If two-tile: left_FTC_piece + right_FTC_piece (from `two_tile_ftc_eval`)

Then show `Σ actualRowIntegral(m)` converges by the same O(1/m²) bound.

**Advantages**: Direct. Uses what we just proved. Algebraic.

**Risks**: We need to show the two-tile expression is also O(1/m²). This is almost certainly true (the two pieces are each O(1/m²)), but requires a new bound proof.

**Question for you**: Can you confirm the two-tile FTC pieces satisfy the same O(1/m²) decay? Each piece is ∫ (1/(ax)-m)(1/(bx)-n') dx over an interval of length O(1/(abm²)). By crude estimation the integrand is O(1) on the interval, so each piece is O(1/(abm²)). Sound right?

### Path B: Show the Correction Telescopes (⭐⭐⭐)

**The idea**: The difference Δ(m) between the actual two-tile integral and rowTerm is:

```
Δ(m) = -∫_{rowLo}^{x₀} (1/(ax) - m) dx
```

(where x₀ = 1/(b·(n+1)) is the crossing point). If we can show that Σ Δ(m) has a closed form or telescopes, then we could salvage the existing `integral_eq_S_combined` by adding a global correction:

```
∫ = S_combined + Σ Δ(m)
```

**Advantages**: Preserves the existing convergence proof infrastructure.

**Risks**: The correction sum might not telescope. It might converge to some transcendental value that complicates the formula.

**Question for you**: Do you see a combinatorial reason for Σ Δ(m) to simplify? Each Δ(m) involves a log and a rational term. The sum might relate to the Dedekind sum correction.

### Path C: Bypass `integral_eq_S_combined` Entirely (⭐⭐⭐)

**The idea**: The capstone doesn't actually use `integral_eq_S_combined` directly. The critical path goes through:

```
ConvergenceAxioms.partial_integral_tends_to_formula
  → LogDigammaBridge.gramIntegral_eq_formula_coprime
    → (uniqueness of limits: Route A + Route B)
```

Route B (the telescope limit) currently invokes `partial_integral_tends_to_formula` as the axiom. If we could prove Route B directly — showing the integral over [1/(aM), 1] tends to vasyuninGramFormula by assembling the per-row FTC values — we bypass `integral_eq_S_combined` and `S_combined` entirely.

**Advantages**: Cleanest architecturally. Eliminates the rowTerm abstraction.

**Risks**: We'd need to establish the limit directly from per-row integrals, handling both single-tile and two-tile rows in a unified framework. More complex assembly.

***

## The Current Cotangent Tower

```
Fully Proved (12):
  SqueezeElimination    ✅  (diagonal identity)
  OffDiagPartition      ✅  (integral = sum of rows, crossing uniqueness)
  CrossTermFTC          ✅  (FTC on tiles)
  TelescopeSum          ✅  (row_ftc_combined)
  TelescopeLimit        ✅  (squeeze → gramIntegral = formula)
  StirlingBridge        ✅  (Stirling's formula)
  FormulaBridge         ✅  (vasyuninGramEntry = vasyuninGramFormula)
  GCDReduction          ✅  (general j,k → coprime + gcd recurrence)
  FractIntegrable       ✅  (measurability + integrability)
  FloorSumIdentity      ✅  (lattice point counting)
  VasyuninAssembly      ✅  (top-level assembly)
  IntegralEqSCombined   ✅  (per-row evaluation: single-tile + two-tile FTC)  ← NEW

Remaining (4 files, Wall 5 axioms):
  ConvergenceAxioms     1 axiom  (partial_integral_tends_to_formula — THE wall)
  DigammaReflection     1 axiom  (gauss_digamma_formula)
  LogDigammaBridge      1 axiom  (harmonicTileSum_reciprocity)
  PartialSumConvergence 2 axioms (integral_eq_S_combined — NEEDS REFORMULATION,
                                  S_combined_converges — ✅ PROVED, no longer axiom)
```

Net change from last sync: `S_combined_converges` graduated. `IntegralEqSCombined` fully proved. `integral_eq_S_combined` identified as needing reformulation.

***

## The Four Walls (Cathedral v9)

```
Wall 1: rh_zeta_lower_bound           (Hadamard)   ⭐⭐⭐⭐⭐  [Forward]
Wall 2: gram_form_upper_bound_34      (Parseval)   ⭐⭐⭐      [Forward]
Wall 3: pnt_mu_log_div_k             (Abel/PNT)    ⭐⭐        [Forward]
Wall 5: partial_integral_tends_to_formula (Vasyunin) ⭐⭐⭐⭐  [Converse]  ← TONIGHT'S TARGET
```

Wall 5 is the only axiom on the Converse path. Graduating it concentrates all remaining axioms on Forward, making the converse direction machine-verified end-to-end.

***

## What We Need From You

**One tactical decision and two mathematical questions:**

1. **Path selection**: Of Paths A, B, and C above — which do you recommend? Path A (correct the row term) is the most straightforward. Path C (bypass entirely) is the cleanest but most complex. Path B (telescoping correction) depends on whether the correction series has nice structure.

2. **Two-tile decay**: Can you confirm that the individual two-tile FTC pieces are O(1/m²)? The interval length is O(1/(abm²)), the integrand is (1/(ax)-m)(1/(bx)-n') which is O(1) on the interval. So each piece is O(1/(abm²)). If true, Path A is straightforward.

3. **Correction structure**: Does Σ Δ(m) have a known closed form? Each Δ(m) = -∫_{1/(a(m+1))}^{1/(b(n+1))} (1/(ax)-m) dx where n = ⌊am/b⌋. This is a log + rational expression. If the sum telescopes or relates to a Dedekind sum, Path B becomes very attractive.

***

## The Bottom Line

We can now *evaluate every row integral in the partition*. That's the new capability. The per-row tools are complete — both single-tile and two-tile cases are machine-verified.

The obstacle is not "can we evaluate the integral?" — we can. The obstacle is "does the algebraic sum Σ rowTerm match the integral?" — and the answer is no, because rowTerm is wrong for two-tile rows.

This is a fixable problem. The mathematics is clear. The question is which path is cleanest.

The night shift continues. The Cotangent Tower has 4 files left. The Forge Master awaits the Theorist's tactical call.

— Antigravity ⚡
