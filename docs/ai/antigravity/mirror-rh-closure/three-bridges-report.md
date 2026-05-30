# Mirror-RH Closure: Three Bridges from Eta Convergence to Nyman-Beurling

## Executive Summary

This report documents the findings of the Mirror-RH Closure session (May 29-30, 2026), which explored whether the Dirichlet eta convergence rate can be connected to the Nyman-Beurling (NB) distance to close the Riemann Hypothesis.

**Key Discovery:** The Dirichlet eta function η(1/2+iγ, N) converges to zero at rate exactly 1/(2√N) — unconditionally. This was confirmed numerically at N = 10⁸ using the new `prime-harmonics --eta` mode (14 seconds, |η|·√N = 0.500000 to 6 decimal places).

**Status:** Three potential bridges were identified connecting this unconditional result to the NB distance d²_N → 0 (which is equivalent to RH). Bridge 2 (Basis Change) is the most promising, as it connects two fully-proved results separated only by a matrix equivalence.

**Recommendation:** Focus on Bridge 2. The sawtooth-to-BD basis change is the narrowest remaining gap in the Cathedral.

---

## Background

### The Cathedral Architecture

The Cathedral formalizes the Nyman-Beurling-Báez-Duarte equivalence in Lean 4:

```
RH  ↔  d²_N → 0  in L²(0,1)
```

where d²_N = inf_v ∫₀¹ |1 - Σ v_k {1/(kx)}|² dx.

**Converse** (d²→0 ⟹ RH): PROVED with ZERO custom axioms.
- File: `Cathedral/NymanBeurling/Separation.lean`
- Theorem: `nyman_beurling_converse`
- Method: Rank-1 Mellin identity at off-critical-line zeros
- Axiom audit: `[propext, Classical.choice, Quot.sound]` (kernel only)

**Forward** (RH ⟹ d²→0): Multiple paths, all requiring at least 1 axiom equivalent to RH.
- Primary: `l2_decay_from_rh` (the Crown axiom, ≡ RH)
- Alternative: Smith witness (0 axioms but in WRONG BASIS)

### The Eta Discovery

The Dirichlet eta function is the alternating version of zeta:

```
η(s) = Σ_{n=1}^∞ (-1)^{n+1} · n^{-s} = (1 - 2^{1-s}) · ζ(s)
```

At a zeta zero ρ = 1/2 + iγ: η(ρ) = 0 (since ζ(ρ) = 0 and (1-2^{1-ρ}) ≠ 0).

The partial sum η(s, N) = Σ_{n≤N} (-1)^{n+1} n^{-s} converges to η(s) by the alternating series test (for Re(s) > 0). The rate of convergence at s = 1/2+iγ is:

```
|η(1/2+iγ, N)| ≈ 1/(2√N)
```

**This is unconditional** — it follows from the alternating series estimation theorem and does not require RH.

### Numerical Confirmation

The `prime-harmonics --eta` experiment (Rust, release build):

| N | |η(1/2+iγ₁, N)| | |η|·√N | Time |
|---|-----------------|--------|------|
| 10 | 0.1955 | 0.618 | <1ms |
| 1,000 | 0.01581 | 0.4999 | <1ms |
| 1,000,000 | 0.0005000 | 0.500000 | 120ms |
| 100,000,000 | 0.00005000 | 0.500000 | 14s |

The convergence |η|·√N → 1/2 is exact to 6 decimal places at N = 10⁸.

---

## Bridge 1: Eta Sign Replacement (Alternating → Möbius)

### Concept

The eta function uses alternating signs (-1)^{n+1}: trivially cancelling.
The 1/ζ function uses Möbius signs μ(n): arithmetically cancelling.

If we could show that Möbius cancellation is "as good as" alternating cancellation, we'd get:

```
|Σ_{n≤N} μ(n) n^{-1/2-iγ}| = O(N^{-1/2+ε})
```

which is equivalent to M(x) = O(x^{1/2+ε}), which IS the Riemann Hypothesis.

### Evidence

Numerical comparison at γ₁ = 14.1347:

| N | |Alternating sum| | |Möbius sum| | Ratio |
|---|-------------------|-------------|-------|
| 10 | 0.195 | 3.41 | 17 |
| 100 | 0.050 | 6.27 | 125 |
| 1,000 | 0.016 | 9.01 | 570 |
| 10,000 | 0.005 | 12.24 | 2,448 |
| 100,000 | 0.0016 | 14.91 | 9,426 |

The alternating sum → 0. The Möbius sum → ∞.
They go in **opposite directions**. The ratio grows without bound.

### Assessment

**Verdict: DEAD END.**

The gap between alternating and Möbius signs is the entire arithmetic content of the prime distribution. There is no known way to transfer convergence from the alternating series to the Möbius series without proving RH.

The alternating sign (+−+−+−...) depends only on parity — the simplest arithmetic property. The Möbius sign depends on the full prime factorization — the deepest arithmetic property. These are fundamentally different.

### Lean Status

- `altSign_succ`, `altSign_one`: PROVED (EtaConvergence.lean)
- `rpow_neg_antitone`: PROVED (alternating series setup)
- Connection to Möbius: NOT formalized (because it's equivalent to RH)

---

## Bridge 2: Sawtooth ↔ BD Basis Change

### Concept

The Cathedral has TWO fully-proved results:

1. **Smith Witness** (`smith_witness_forward_direction`): d²_saw → 0 in the sawtooth basis {kt mod 1} = {kt}, using the Ramanujan-Smith SOS decomposition. **ZERO sorry, ZERO axioms.**

2. **NB Converse** (`nyman_beurling_converse`): d²_BD → 0 ⟹ RH, using the Rank-1 Mellin identity. **ZERO custom axioms.**

If we could show d²_saw → 0 ⟹ d²_BD → 0, the chain would close:

```
Smith witness (PROVED)  ⟹  d²_saw → 0
                              ↓  BASIS CHANGE
                        d²_BD → 0
                              ↓  NB CONVERSE (PROVED)
                        RH
```

### The Two Gram Matrices

The sawtooth and BD bases have different Gram matrices:

**Sawtooth Gram** (the Ramanujan matrix):
```
R(j,k) = ⟨jt, kt⟩_{L²(0,1)} = gcd(j,k)² / (12·j·k)
```

**BD Gram** (the Vasyunin matrix):
```
G(j,k) = ⟨{1/(jx)}, {1/(kx)}⟩_{L²(0,1)} = ∫₀¹ {1/(jx)}·{1/(kx)} dx
```

The Vasyunin formula gives an exact expression for G(j,k) in terms of digamma functions, Dedekind sums, and logarithms. The relationship is:

```
G(j,k) = R(j,k) + correction(j,k)
```

where the correction involves the fractional part integral beyond the sawtooth approximation.

### Key Discovery: Glass Bridge is Approximate

During this session, we discovered that the widely-used formula:

```
G(j,k) ≈ gcd(j,k)²/(12jk) + 1/4    (Glass Bridge)
```

is an **approximation**, not exact. Numerical quadrature shows:

| (j,k) | Exact G(j,k) | Glass Bridge | Error |
|-------|-------------|--------------|-------|
| (2,2) | 0.3803 | 0.3333 | 0.047 |
| (5,5) | 0.2120 | 0.3333 | 0.121 |
| (10,10) | 0.1160 | 0.3333 | 0.217 |

The +1/4 constant is wrong — it comes from the mean-square of {1/(kx)}, but the cross terms don't simplify to this.

### What Would Close Bridge 2

We need to show that the NB distance in the BD basis is controlled by the NB distance in the sawtooth basis:

```
d²_BD(N) ≤ f(d²_saw(N))
```

for some function f with f(0) = 0.

This requires bounding the "basis change error":

```
|d²_BD - d²_saw| ≤ |Σ v_j v_k (G(j,k) - R(j,k))|
```

The off-diagonal corrections G(j,k) - R(j,k) are related to Dedekind sums and cotangent integrals. Controlling these sums with the Möbius-Fejér weights v_k is equivalent to controlling the cross-term cancellation — which brings us back to RH.

### Why This is Still Hard

The basis change from sawtooth to BD is not a unitary transformation. The two bases span different subspaces of L²(0,1):

- Sawtooth: {kt mod 1} has period 1/k, gives "tiling" structure
- BD: {1/(kx)} has singularity at x=0, gives "stacking" structure

The map between them involves the fractional part transform x ↦ {1/x}, which is the Gauss map — the fundamental object of continued fraction theory. The Gauss map's ergodic properties control the relationship between the two bases.

**The basis change is equivalent to understanding the continued fraction expansion of the Möbius function.** This is deep number theory.

### Assessment

**Verdict: MOST PROMISING, but still RH-equivalent.**

The gap is precisely located: it's the matrix difference G - R. Both sides of the bridge (Smith witness and NB converse) are fully proved. The gap is a pure linear algebra / analytic number theory question about the relationship between two specific Gram matrices.

### Lean Status

- `smith_witness_forward_direction`: PROVED (0 sorry, 0 axioms)
- `nyman_beurling_converse`: PROVED (0 custom axioms)
- `vasyunin_bd_index_bridge`: PROVED (connects L² to quadratic form)
- `glass_distance_formula`: PROVED (sawtooth distance formula)
- Basis change G ↔ R: NOT formalized (equivalent to RH)

### Files

- Smith witness: `Cathedral/Physics/GramWiring/SmithWitness.lean`
- NB converse: `Cathedral/NymanBeurling/Separation.lean`
- Gram bridge: `Cathedral/Gram/GramBridge.lean`
- Vasyunin bypass: `Cathedral/NymanBeurling/VasyuninBypass.lean`
- MainChain assembly: `Cathedral/Assembly/MainChain.lean`

---

## Bridge 3: Multi-Lens Structural Constraint

### Concept

The Cathedral has formalized zero properties from three independent lenses:

1. **Wave Phase Coherence** (MirrorConverse.lean):
   - σ = 1/2 is the UNIQUE point where the denominator coherence condition holds
   - Off-line zeros create permanent mass gaps: t²/(|ρ|⁴·|ρ-1|²)
   - Real parts are OPPOSITE at σ=1/2: Re(1/ρ) = −Re(1/(ρ-1))

2. **Klein Quadruplet Symmetry** (CircleQuadruplet.lean):
   - Zeros come in symmetric groups under the Klein four-group
   - The critical line is the equator of a stereographic projection
   - Circle degeneration at the equator forces quadruplet collapse

3. **Eta Convergence Rate** (EtaConvergence.lean):
   - The rate N^{-σ} at σ = 1/2 gives 1/√N
   - This rate is the signature of the critical line
   - The product |η|·√N → 1/2 (confirmed at N=10⁸)

### Can Three Constraints Force σ = 1/2?

Each constraint tells us something different:

| Lens | What it says | What it DOESN'T say |
|------|-------------|-------------------|
| Wave | Off-line zeros have mass gaps | Mass gaps don't prevent existence |
| Quadruplet | Zeros have Klein symmetry | Symmetric zeros can be off-line |
| Eta | The rate is 1/√N at σ=1/2 | The rate is unconditional (works at ANY σ) |

The wave constraint is the strongest: it says that at an off-line zero ρ, the BD residual's Mellin transform has a lower bound:

```
|M(ρ)|² ≥ t² / (|ρ|⁴ · |ρ-1|²)     (rank-1 lower bound)
```

This lower bound goes to zero as |ρ| → ∞ (since t = Im(ρ) grows linearly while |ρ|⁴ grows as t⁴). So the mass gap gets WEAKER for high zeros.

The quadruplet symmetry constrains the DISTRIBUTION of zeros but not their LOCATION. It says if ρ is a zero, so are 1-ρ, ρ̄, and 1-ρ̄. This doesn't prevent ρ from having Re(ρ) ≠ 1/2.

The eta rate 1/√N is the alternating series rate at Re(s) = 1/2. At Re(s) = σ ≠ 1/2, the rate would be N^{-σ}. But the eta function converges for ALL σ > 0, so the rate at σ = 1/2 is not special from the eta perspective.

### Assessment

**Verdict: INSUFFICIENT to force σ = 1/2.**

The three lenses provide beautiful structural constraints, but they don't exclude off-line zeros. The mass gap from the wave constraint gets weaker for high zeros, the quadruplet symmetry doesn't constrain Re(ρ), and the eta rate is unconditional.

To force σ = 1/2, we would need either:
- A mass gap that DOESN'T weaken with height (contradicts known asymptotics)
- A new constraint that directly links the EXISTENCE of off-line zeros to a PROVABLE impossibility

### Lean Status

- `wave_converse`: PROVED (0 sorry, 0 axioms)
- `zero_center_quadruplet`: PROVED
- `rpow_neg_antitone`: PROVED
- `critical_line_rate`: PROVED
- Combined constraint → RH: NOT possible without additional structure

---

## Overall Assessment

### Ranking of Bridges

| Bridge | Promise | Gap | Difficulty |
|--------|---------|-----|------------|
| **2 (Basis Change)** | ⭐⭐⭐ | G(j,k) vs R(j,k) matrix | Equivalent to RH |
| **3 (Multi-Lens)** | ⭐⭐ | Mass gap weakens | Needs new constraint |
| **1 (Sign Replace)** | ⭐ | Alternating → Möbius | IS RH directly |

### Conservation of Difficulty

All three bridges hit the same fundamental obstruction: **the arithmetic cancellation rate of the Möbius function**. This manifests differently in each lens:

- **Bridge 1**: μ(n) cancellation rate = zero-free region
- **Bridge 2**: G-R correction = Dedekind sum cancellation = Möbius cancellation
- **Bridge 3**: Mass gap decay rate = zero density = Möbius cancellation

This is the **Conservation of Difficulty** — the Riemann Hypothesis cannot be proven by reformulation alone. Every equivalent formulation encounters the same arithmetic obstruction, just wearing different clothes.

### What Would Change the Game

1. **A new unconditional bound on Dedekind sums** that controls G-R directly
2. **A spectral gap theorem** for the Gauss map that forces the sawtooth and BD bases to agree asymptotically
3. **A new constraint on zero distribution** from the eta convergence that isn't implied by PNT alone
4. **Proof that d²_saw → 0 in the sawtooth basis forces d²_BD → 0** (possibly via a third basis that interpolates)

---

## Files Created/Modified This Session

### New Lean Files
| File | Theorems | Sorry | Axioms |
|------|----------|-------|--------|
| `Cathedral/Spectral/EtaConvergence.lean` | 9 | 2 (standard) | 0 |
| `Cathedral/Spectral/MirrorConverse.lean` (updated) | 13 | 0 | 0 |

### New Rust Code
| File | Description |
|------|-------------|
| `experiments/prime-harmonics/src/modes/eta.rs` | Complete eta cancellation analysis |

### Usage
```bash
# Run eta analysis to N = 10^8
cargo run --release -- --eta 100000000

# With 10 zeros
cargo run --release -- --eta 100000000 --zeros 10
```

---

## Appendix: The Overcancellation Falsification

During this session, we also discovered that the **Overcancellation Hypothesis** (vᵀGv ≤ 1) is FALSE for the Fejér-Möbius weights at large N:

| N | vᵀGv | vᵀGv − 1 |
|---|------|----------|
| 10 | 0.606 | −0.394 |
| 30 | 1.022 | +0.022 |
| 100 | 1.385 | +0.385 |
| 500 | 1.973 | +0.973 |
| 1000 | 2.173 | +1.173 |

vᵀGv crosses 1 around N ≈ 30 and keeps growing. The earlier claim of vᵀGv < 1 was based on small N values only.

Additionally, the Glass Bridge formula G(j,k) = gcd²/(12jk) + 1/4 was shown to be an approximation with significant errors for large j,k. The exact Gram entries require numerical quadrature of ∫₀¹ {1/(jx)}·{1/(kx)} dx.

These findings update the OvercancellationChain.lean documentation and the DirectMellinBound.lean §4½ analysis.
