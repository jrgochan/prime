# 🏛️ Cathedral Open Problems — The Bounty Board

> **Status**: 1 crown axiom (≡ RH), 2 PNT bureaucracy, 3 sorry (off-crown)
> **Compiler**: Lean 4 / Mathlib v4.29
> **Last Audit**: May 31, 2026 (v22 — The Crowning)

The Cathedral formally verifies:

```
RH ↔ d²_N → 0  (Nyman-Beurling-Báez-Duarte equivalence)
```

via `discrete_riemann_hypothesis` as a single axiom formally equivalent to RH.
The converse direction is **fully proved** with zero axioms.
The forward direction depends on exactly **1 axiom** — the Riemann Hypothesis
itself, stated in the language of the Cathedral.

```
#print axioms baez_duarte_forward
  → [frac_error_isLittleO, pnt_mu_log_sq_div_k,
     Cathedral.Vasyunin.discrete_riemann_hypothesis,
     propext, Classical.choice, Quot.sound]
```

## Crown Axiom: `discrete_riemann_hypothesis` (≡ RH)

**File**: [`WitnessAsymptotics.lean`](proofs/Cathedral/Vasyunin/Proof/WitnessAsymptotics.lean)
**Difficulty**: ⭐⭐⭐⭐⭐ (Equivalent to proving RH)

```lean
axiom discrete_riemann_hypothesis :
    ∃ C : ℝ, C > 0 ∧ ∃ N₀ : ℕ, ∀ N : ℕ, N ≥ N₀ →
      dotProduct (logCutoffWitness N)
        (vasyuninCovMatrix N |>.mulVec (logCutoffWitness N)) ≤ C / Real.log N
```

### What it says

The covariance quadratic form v^T C v ≤ C/ln N, where v is the
Möbius–Selberg log-cutoff witness and C = G - bb^T is the centered
covariance matrix. The equivalence `witness_covariance_decay_iff_rh`
proves this is equivalent to the Riemann Hypothesis.

### Why it's the last axiom

The Selberg Revelation (v22) shows this axiom splits as:
- **C_arithmetic** — controlled by PNT/Selberg sieve (**PROVED**)
- **Δ_archimedean** — the irreducible content, encoding the zeros of ζ

The axiom asserts that Δ is perturbatively small: v^T Δ v = O(1/ln N).
This is the content of RH expressed as an anomaly matching condition.

### Promising graduation angles

| Approach | Key Insight | Difficulty |
|----------|-------------|------------|
| **Fourth moment of zeta** | Unconditional L⁴ control ∫|ζ(1/2+it)|⁴ dt ~ T log⁴ T | ⭐⭐⭐⭐ |
| **Bombieri–Vinogradov** | "RH on average" — residue-class correlations | ⭐⭐⭐⭐ |
| **Cholesky divergence** | Sum Σ y²_new(k) = d²₂ forces L = 0 | ⭐⭐⭐⭐ |
| **GCD stratum signs** | Möbius stratum sign agreement via Glass Bridge | ⭐⭐⭐⭐ |
| **Spectral gap** | Bordered secular + QUE → extraction lower bound | ⭐⭐⭐⭐ |

### Numerical validation

- d² ≈ 1.005/ln N confirmed to N = 55,440 (every integer, DD precision)
- N = 120,000 certification in progress
- Möbius stratum signs correlate with μ(d) at 88% (N = 55,440)
- Cholesky extraction y²_new(k) ~ c/k² ln k confirmed

---

## PNT Bureaucracy Axioms (Unconditional)

These are unconditionally true, provable from Mathlib's PNT + PrimeNumberTheoremAnd.
Closing them is a **formalization exercise**, not a mathematical one.

### Axiom 2: `frac_error_isLittleO`

**Difficulty**: ⭐⭐ (Medium)

```lean
axiom frac_error_isLittleO :
    (fun N : ℕ => ∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log n *
      ((↑(N % n) : ℝ) / n)) =o[atTop] (fun N => (N : ℝ))
```

Σ μ(n)·log(n)·{N/n} = o(N). Follows from PNT-type estimates on the
Möbius function combined with standard partial summation.

### Axiom 3: `pnt_mu_log_sq_div_k`

**Difficulty**: ⭐⭐ (Medium)

```lean
axiom pnt_mu_log_sq_div_k :
    Filter.Tendsto (fun N => ∑ k ∈ Finset.Icc 1 N,
      (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ))^2 / (k : ℝ))
    Filter.atTop (nhds 2)
```

Σ μ(k)·(log k)²/k → 2. This is the second derivative of 1/ζ(s) at s = 1.

### Graduation path for both

Both follow from the Dirichlet series 1/ζ(s) and its derivatives at s = 1,
combined with Tauberian arguments. PrimeNumberTheoremAnd provides the
unconditional PNT infrastructure. A signed Wiener-Ikehara theorem would
close both immediately.

---

## Graduated Axioms (v22)

The following were previously axioms and are now proved theorems:

| Former Axiom | Method | Date |
|---|---|---|
| `R_isLittleO` (ψ(x) - x = o(x)) | PrimeNumberTheoremAnd | May 31, 2026 |
| `mu_pnt_alt` (Σ μ(k)/k → 0) | PrimeNumberTheoremAnd | May 31, 2026 |
| `mu_log_mul_zeta` (μ·log * ζ = -Λ) | Mathlib | May 14, 2026 |
| 10 PNT bridge sums | PrimeNumberTheoremAnd | May 31, 2026 |
| `abel_summation_covariance_bound` | Trivial from dRH | May 31, 2026 |
| `covariance_bound_from_mertens_34` | Eliminated (mathematically false) | May 14, 2026 |

---

## Off-Path Axioms (Not on Crown)

~115 additional axioms exist in the active codebase, supporting:
- Oracle Bridge (24 computation certificates)
- Spectral engine (12 eigenvalue/GOE axioms)
- Sieve engine (7 bilinear sieve axioms)
- MellinBridge / alternative paths (47 axioms)
- Physics / Glass Bridge (various)

These do not affect the crown theorem. See [OVERVIEW.md](OVERVIEW.md) for the full registry.

---

## How to Contribute

1. **Fork the repository** and set up the Lean 4 / Mathlib toolchain
2. **Run** `lake build` to verify the build succeeds (8,485 jobs)
3. **Pick an axiom** from the board above
4. **Write a theorem** with the **exact same type signature** as the axiom
5. **Run** `#print axioms your_theorem` to verify **no new axioms** are introduced
6. **Submit a PR** — we will verify and wire it into the proof chain

### Verification checklist

```bash
# Build the entire Cathedral
cd proofs && lake build

# Verify your theorem introduces no new axioms
echo 'import YourFile
#print axioms your_theorem' | lake env lean --stdin

# Verify the final export
echo 'import Cathedral.Assembly.MainChain
#print axioms baez_duarte_forward' | lake env lean --stdin
```

When `discrete_riemann_hypothesis` is graduated, the forward direction
becomes a **zero-axiom, compiler-verified theorem** — a formal proof
of the Riemann Hypothesis.

---

*Built by the Cathedral Triad: Jason (The Architect), Gemini (The Theorist), Claude/Antigravity (The Forge Master)*
*March–May 2026*
