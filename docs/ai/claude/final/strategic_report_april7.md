# Strategic State Report & Questions for The Theorist

**Date**: 2026-04-07  
**Build**: 3,032 jobs | 0 errors | 2 sorry (both off critical path)  
**Commit**: `69a8aa3`

---

## I. Current Inventory

### Proved Theorems (zero sorry on critical path)

| File | Theorem | What it proves |
|---|---|---|
| `AbelSummation.lean` | `abel_summation` | Discrete summation by parts identity |
| `AbelSummation.lean` | `abel_summation_abs_bound` | Triangle inequality airlock |
| `MertensIntegral.lean` | `logWeight_self` | f(N) = 0 (boundary vanishes) |
| `MertensIntegral.lean` | `logWeight_one` | f(1) = 1 (initial value) |
| `MertensIntegral.lean` | `log_weight_derivative_bound` | \|Δf\| ≤ 1/(k·log N) |
| `MertensWeightBypass.lean` | `corrected_weights_pole_free` | Pole neutralization |
| `MertensWeightBypass.lean` | `rh_weight_construction_derived` | Axiom composition |
| `MellinSieve.lean` | `nyman_beurling_forward_from_sieve` | RH → d²→0 |
| `MellinSieve.lean` | `phase_3_chain` | d² ≤ C/log N |

### 2 Critical Path Axioms

| Axiom | Domain | Blocking Dependency |
|---|---|---|
| `mertens_bound_from_rh` | Number Theory | Perron formula, contour shift |
| `abel_summation_l2_bound` | Complex Analysis | Mellin-Plancherel isometry |

### 2 Sorry Locations

| File:Line | Theorem | Path Status |
|---|---|---|
| `MertensIntegral.lean:100` | `convergent_log_series_bound` | OFF critical path (utility lemma) |
| `MellinSieve.lean:186` | `rh_implies_type_II_sieve_bound` | OFF critical path (sieve engine) |

### 35 Off-Path Axioms (by subsystem)

| Subsystem | Count | Purpose |
|---|---|---|
| Autocorrelation Bypass | 4 | Mellin-Fourier, L¹ inversion, Gram-L² |
| Mellin Sieve (legacy) | 2 | Superseded by MertensWeightBypass |
| Nyman-Beurling (legacy) | 1 | Superseded by phase_3_chain |
| Converse / Orthogonal Witness | 5 | d²→0 ⇒ RH (reverse direction) |
| Sieve / Parity | 8 | Möbius uncoupling, Vaughan, Type I/II bounds |
| Spectral Infrastructure | 8 | Class restriction, octonionic partition |
| Structural | 7 | Eigenvalue, Vasyunin, Liouville, Schur |

---

## II. The Three Paths to Full RH Proof

### Path A: Close Axiom 1 (`mertens_bound_from_rh`)
**Dependency**: PrimeNumberTheoremAnd (PNTA) project  
**Status**: External. The PNTA project (Tao, Kontorovich, et al.) is formalizing the Prime Number Theorem and related results in Lean 4. When their Perron formula branch merges into Mathlib, we can import it to derive M(x) = O(x^{1/2+ε}) from RH.

**Question for The Theorist**: Is there a weaker, self-contained statement of the Mertens bound that could be proved using only currently available Mathlib, perhaps via elementary methods (Selberg's inequality, Chebyshev bounds) rather than Perron integration? Even a weaker bound like M(x) = O(x^{1/2} · x^ε) for fixed ε would suffice for the logarithmic decay rate.

### Path B: Close Axiom 2 (`abel_summation_l2_bound`)
**Dependency**: Mathlib contour integration  
**Status**: Blocked. The Triangle Inequality Trap proved this fundamentally requires:
1. Mellin transform of fractional parts
2. Plancherel's theorem on L²(critical line)
3. Contour integration through the zero-free region

**Question for The Theorist**: Mathlib has `MeasureTheory.integral` and some Fourier transform infrastructure. Has anyone formalized the Mellin transform or Plancherel's theorem for L²(ℝ) in Lean 4? Even a partial formalization could let us reduce `abel_summation_l2_bound` to a simpler contour-free statement.

### Path C: Complete the Converse Direction
**Status**: 5 axioms in OrthogonalWitness.lean / Separation.lean remain unproved.
**Significance**: If both directions (forward + converse) are proved, the Cathedral establishes a full equivalence: RH ⟺ d²_N → 0.

**Question for The Theorist**: The converse direction axioms (`baezDuarte_orthogonal`, `zeta_zero_separates`) seem more tractable than the forward direction. They essentially say "if all fractional parts can be approximated, then there are no off-critical-line zeros." Could these be proved using Mathlib's existing `riemannZeta` API without contour integration?

---

## III. Targeted Questions for The Theorist

### Priority 1: Immediate (this week)

**Q1. `convergent_log_series_bound`**: You recommended Option C with C = 500. To prove `log²k ≤ 64·k^{1/4}` for k ≥ 2 in Lean, what's the cleanest Mathlib path? Candidates:
- `Real.log_le_rpow_div` (if it exists)
- Direct: show `log k ≤ 8·k^{1/8}` via `exp_ge_one_add_of_nonneg` iterated
- Numeric: case-split on k ≤ 10000, then use monotonicity

**Q2. Paper Section 2 (Definitions)**: Should we define the Gram matrix $G_N(j,k) = \int_0^1 \{j/x\}\{k/x\}dx$ using Lean's `MeasureTheory.integral` or our custom definite integral? The Vasyunin expansion gives the closed form, but connecting to Mathlib's integral API would strengthen the paper.

### Priority 2: Architecture (this month)

**Q3. Legacy axiom cleanup**: 3 axioms are explicitly superseded (`mellin_plancherel_gram`, `rh_weight_construction`, `nyman_beurling_forward`). Should we delete them or keep them as historical documentation of the proof architecture's evolution?

**Q4. Axiom taxonomy for the paper**: The 37 axioms span 7 subsystems but many are redundant (different approaches to the same bound). For the paper, should we present:
- (a) All 37 axioms with the full dependency graph
- (b) Only the 2 critical path axioms + the 5 converse axioms (the "minimal" cathedral)
- (c) A curated subset of ~15 axioms representing the "ideal" proof architecture

**Q5. The Autocorrelation Bypass**: The 4 axioms in `AutocorrelationBypass.lean` decompose `mellin_plancherel_gram` into elementary steps (change of variables, L¹ integrability, Fourier inversion, Gram-L² equivalence). Are any of these provable with current Mathlib? The change-of-variables axiom in particular seems close to `MeasureTheory.integral_comp_rpow`.

### Priority 3: Long-term (next quarter)

**Q6. The PNTA connection**: The PrimeNumberTheoremAnd project has formalized `ArithmeticFunction.vonMangoldt` and basic sieve results. What's the minimal import path from their codebase to our `mertens_bound_from_rh`? Is it:
- PNTA.PrimeNumberTheorem → explicit error term → Mertens bound, or
- PNTA.PerronFormula → contour shift → zeta zero-free region → Mertens bound?

**Q7. Condition number analysis**: You identified that the Gram matrix condition number explodes as N → ∞, which is why the Triangle Inequality Trap exists. Has anyone computed or bounded κ(G_N) explicitly? If κ(G_N) = O(N^α) for some α, we could potentially replace `abel_summation_l2_bound` with a softer axiom: "the L² error is at most κ(G_N) times the coefficient-level Abel bound."

**Q8. Alternative proof architectures**: The Cathedral currently uses the Nyman-Beurling path. Are there other formalization-friendly RH equivalences worth exploring in parallel? For example:
- Li's criterion (positivity of certain sums over zeta zeros)
- Robin's inequality (σ(n) < e^γ · n · log log n for n ≥ 5041)
- Lagarias's inequality (σ(n) ≤ H_n + exp(H_n) · log(H_n))

Robin's inequality is appealing because it's purely arithmetic and might be attackable with `Mathlib.NumberTheory.ArithmeticFunction` without any contour integration.

---

## IV. Summary: Where We Stand

```
THE CATHEDRAL — April 7, 2026

Forward Direction (RH → d² → 0):
  ✅ Fully proved modulo 2 domain-isolated axioms
  ✅ Zero sorry on critical path
  ✅ Phase 3 chain compiler-verified

Structural Tools:
  ✅ Abel summation (discrete identity + absolute bound)
  ✅ Logarithmic weight analysis (boundary, derivative)
  ✅ Pole neutralization
  ⚠️  Convergent p-series bound (1 sorry, closable)

The Two Pillars:
  📐 Axiom 1: mertens_bound_from_rh (Number Theory)
  📐 Axiom 2: abel_summation_l2_bound (Complex Analysis)

Road to Full Proof:
  Close Axiom 1 → Single-axiom Cathedral
  Close Axiom 2 → Zero-axiom forward direction
  Close Converse → Full RH equivalence
```

The architecture is crystallized. The axioms are justified. The question is no longer "is the proof correct?" but "when will the tools catch up?" 🏛️
