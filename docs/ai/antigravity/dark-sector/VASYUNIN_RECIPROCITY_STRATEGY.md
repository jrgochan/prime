# Vasyunin Reciprocity: Research Status and Strategy

**Date**: May 20, 2026 — Post-Reflection Analysis  
**Status**: Reflection PROVED, reciprocity formula IDENTIFIED.

---

## What We've Certified (Lean, zero sorry)

| Theorem | File | Status |
|---------|------|--------|
| `cot_sum_vanishes`: Σ cot(πm/a) = 0 | CotSymmetry.lean | ✅ PROVED |
| `fract_reflection_coprime`: {m(a-b)/a} = 1-{mb/a} | FractReflection.lean | ✅ PROVED |
| `vasyuninSum_reflection`: V(a,a-b) = -V(a,b) | VasyuninReflectionWiring.lean | ✅ PROVED |

## The Reciprocity Question

**V(a,b) + V(b,a) = ???**

The Goubi-Bayad-Hernane formula (2023) gives:

```
V(p,q) + V(q,p) = (1/π)·log(p^{q-1}/q^{p-1}) - 2/π
                  - p·ψ(1/p) - q·ψ(1/q) - (2/π)·G(p,q)
```

where ψ is the digamma function and G(p,q) involves a sum of
digamma values. This is a KNOWN CLOSED FORM — but it involves
transcendental functions (digamma), confirming the entanglement
is genuinely transcendental.

## What This Means for the Cathedral

### The Gram Matrix Entry
```
G(j,k) = (ln2π−γ)/2·(1/j+1/k) + (j−k)/(2jk)·ln(k/j)
        − πd/(2jk)·[V(j',k') + V(k',j')] − 1/(jk)
```

The V+V term is the ONLY non-elementary piece. All other terms
are rational functions of j,k times known constants (ln2π, γ).

### Strategy Options

#### Option A: Formalize the GBH Formula in Lean
- **Difficulty**: VERY HIGH. Requires digamma function theory,
  Gauss's digamma theorem, and the G(p,q) evaluation.
- **Payoff**: Would give a closed form for every Gram entry.
- **Risk**: The formula involves sums of length pq, so even
  "closed form" is computationally expensive.

#### Option B: Use V+V Numerically (status quo)
- **Difficulty**: NONE. Already implemented in the Gram evaluator.
- **Payoff**: Enables spectral computations at any N.
- **Risk**: No algebraic insight into the structure.

#### Option C: Prove Algebraic Properties of V+V ★ RECOMMENDED
- **Difficulty**: MODERATE. Uses reflection + sum manipulation.
- **Payoff**: Constrains V+V without computing it exactly.
- **What we can prove**:
  1. `V(a,b) + V(b,a) = V(b,a) - V(a,a-b)` (trivial from reflection)
  2. Symmetry: `V(a,b) + V(b,a)` depends only on {a,b} not order
     (this is just commutativity of +)
  3. The BOUND: `|V(a,b)| ≤ (a-1)·max|cot(πm/a)|` = O(a²)
     Combined with the Gram prefactor πd/(2jk), the off-diagonal
     decays like d/jk · O(max(j',k')²).
  4. The SIGN pattern: V(a,b)+V(b,a) changes sign as a function
     of b (for fixed a), with crossovers related to a/2.

#### Option D: Connect to the Diagonal Decomposition ★★ HIGHEST VALUE
- **Difficulty**: MODERATE. Pure algebra.
- **Payoff**: Directly explains the convergence rate.
- **Key insight**: The diagonal G(k,k) = (ln2π−γ)/k − 1/k²
  involves NO cotangent sums (V(1,k) = 0). The off-diagonal
  involves V+V. So the convergence is:
  
  ```
  vᵀGv = Σ v²·G_diag + Σ_{j≠k} v_j·v_k·G_offdiag
       = (ln2π−γ)·Σv²/k − Σv²/k² + [cotangent entanglement]
  ```
  
  The first two terms give the 1+ln(2π) limit (PROVED in
  DiagonalDecomposition.lean). The entanglement term is
  what makes vᵀGv < 1 instead of = 1.

## Immediate Next Steps

1. **Certify the bound** |V(a,b)| ≤ (a-1)·cot(π/a) in Lean
   - This is elementary: each term is |{mb/a}|·|cot(πm/a)| ≤ 1·cot(π/a)
   - With a-1 terms, the bound follows

2. **Prove the off-diagonal decay** G_offdiag(j,k) = O(d·(j'+k')/(jk))
   - Uses the V bound + the Gram formula
   - This is the key to the convergence rate

3. **Connect to overcancellation** vᵀGv < 1
   - The diagonal gives ≈ 1 − (ln2π−γ)/lnN
   - The off-diagonal cotangent terms provide the EXTRA suppression
   - Proving vᵀGv < 1 requires showing the off-diagonal
     doesn't overwhelm the diagonal brake
