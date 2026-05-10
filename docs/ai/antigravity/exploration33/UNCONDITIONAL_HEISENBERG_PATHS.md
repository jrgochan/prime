# Exploration 33: Unconditional Heisenberg — Paths Forward

**Date:** May 9, 2026, 9:44 PM MDT
**Companion:** HEISENBERG_AXIOM_DEEP_DIVE.md
**Goal:** Find paths to make HeisenbergBypass.lean's main theorem
(`heisenberg_implies_d_sq_zero`) depend on **fewer or weaker** axioms

---

## Current State

The Heisenberg main theorem `heisenberg_implies_d_sq_zero : d²_N → 0`
currently depends on:

```
witness_covariance_decay    (= RH, from WitnessAsymptotics.lean)
witness_numerator_convergence (= PNT, PROVED)
```

The first is equivalent to RH. The second is already a theorem.
So the Heisenberg path currently **assumes RH** (in disguise).

Meanwhile, the **Oracle path** (`rh_from_oracle`) proves RH from:

```
oracle_certificates         (trusted GPU computation)
pnt_mu_log_div_k            (PNT import)
pnt_mu_log_sq_div_k         (PNT import)
```

**Question:** Can we re-route the Heisenberg path to use the Oracle's
axiom instead of `witness_covariance_decay`?

---

## Path A: The Gram Bound Re-Route (★★ Feasible)

### Idea

The Heisenberg path needs `spectral_energy_witness_lower`:
```
∃ C > 0, ∃ N₀, ∀ N ≥ N₀, totalSpectralEnergy N ≥ 1 - C / log N
```

Currently this comes from `bd_witness_l2_error_decay_proved`, which
flows through `witness_covariance_decay`. But we can derive it directly
from the **Gram bound**:

**Step 1:** From `gram_form_upper_bound_subseq` (or `oracle_certificates`):
```
vᵀGv ≤ 1 + K/ln(N)   for the logCutoffWitness at HC numbers
```

**Step 2:** Combined with PNT (`witness_numerator_convergence`, proved):
```
|bᵀv - 1| < ε   for large N
```

**Step 3:** The L² error identity (proved):
```
d²_N(v) = 1 - 2·bᵀv + vᵀGv
```

**Step 4:** Substituting:
```
d²_N(v) ≤ 2(1 - bᵀv) + K/ln N → 0
```

**Step 5:** From the spectral identity (proved):
```
d²_N = 1 - totalSpectralEnergy N
```

**Step 6:** Therefore (for this specific witness v, which may not be optimal):
```
1 - totalSpectralEnergy N ≤ d²_N ≤ d²_N(v) ≤ C/ln N
```

Wait — this inequality goes the **wrong direction**. The spectral identity
gives d² = 1 - total for the **optimal** d², not for a specific witness.
And d²_N ≤ d²_N(v) by definition (infimum ≤ any specific value).

So: `totalSpectralEnergy N = 1 - d²_N ≥ 1 - d²_N(v) ≥ 1 - C/ln N` ✓

**This works!** The lower bound on total spectral energy follows from
the *upper* bound on d²_N(v) for a specific witness, which follows from
the Gram bound.

### Implementation

We already have `nbDistSq_le_test_vector` (proved in QuadFormBridge.lean):
```lean
theorem nbDistSq_le_test_vector (N : ℕ) (hN : 2 ≤ N) (w : Fin (N-1) → ℝ) :
    nbDistSq' N ≤ 1 - 2 * dotProduct (basisInnerProd N) w +
      realQuadForm (gramMatrix N) w
```

And the Gram bound gives:
```
vᵀGv ≤ 1 + K/ln N   (for v = logCutoffWitness, after Vasyunin↔Cathedral bridge)
```

Combined with PNT (bᵀv → 1, proved), this gives:
```
nbDistSq' N ≤ C'/ln N
```

And then:
```
totalSpectralEnergy N = 1 - nbDistSq' N ≥ 1 - C'/ln N
```

**This is `spectral_energy_witness_lower` re-proved from the Gram bound!**

### What changes

We write a new theorem:

```lean
theorem spectral_energy_witness_lower_from_gram
    (h_gram : ∃ K > 0, ∃ N₀, ∀ N ≥ N₀, N ≥ 3 →
      dotProduct (logCutoffWitness N)
        ((vasyuninGramMatrix N).mulVec (logCutoffWitness N)) ≤ 1 + K / log N) :
    ∃ C > 0, ∃ N₀, ∀ N ≥ N₀,
      totalSpectralEnergy N ≥ 1 - C / log N
```

This feeds into `total_spectral_energy_tendsto_one` → `heisenberg_implies_d_sq_zero`.

### Axiom footprint after re-route

```
heisenberg_implies_d_sq_zero
  └─ gram_form_upper_bound_subseq  (or oracle_certificates)
  └─ witness_numerator_convergence  (PROVED — PNT)
```

**Same footprint as the Oracle path.** The Heisenberg and Oracle paths merge.

### Difficulty: ★★

The proof is essentially the same as `gram_bound_implies_rh` but going
through the spectral identity instead of NB converse directly. All the
ingredients exist — we just need to assemble them differently.

---

## Path B: Prove `infrared_safety` Unconditionally (★★★★★ Hard)

### Idea

Prove the IR safety axiom directly from spectral theory, making the full
Heisenberg energy decomposition (IR/UV partition) fully operational.

### What's needed

The axiom says: for any τ(N) → 0,
```
Σ_{k : λ_k < τ} c_k²/λ_k → 0
```

This would follow from proving **eigenvector localization** of the
ground-state eigenvectors: show that for k with small λ_k, the
eigenvector v_k is concentrated on composite indices, so c_k = ⟨b, v_k⟩
is small because b has delocalized support.

### Numerical evidence

From explorations 19-28:
- β = 1.611 (N=10K), 1.699 (N=20K), 1.861 (N=40K)
- Bottom-50 mode contribution < 0.0001% of spectral sum
- Participation ratio PR ~ O(1) for ground-state (localized)
- IR contribution falls as N^{-1.65}

### Mathematical route

1. **Cauchy-Schwarz on localized eigenvectors:**
   c_k² = ⟨b, v_k⟩² ≤ ||b||² · ||v_k|_S||² where S = support of v_k
   If v_k is localized on ~C composites (PR ~ C), then ||v_k|_S|| ~ √C/√(N-1)
   Since C ~ O(1) (participation ratio bound), c_k² ~ O(1/N)

2. **Combined with eigenvalue asymptotics:**
   λ_k ~ 1/(k·ln k) for the smallest eigenvalues (from Gram structure)
   E_k = c_k²/λ_k ~ k·ln(k)/N → 0 for each fixed k

3. **Sum over IR modes:**
   #{k : λ_k < τ} ~ log(1/τ) modes (from eigenvalue density)
   Total IR ~ (log(1/τ))²/N → 0

### Why it's hard

- Eigenvector localization is proved in random matrix theory (Anderson model)
  but the Gram matrix is **not random** — it's deterministic and structured.
- The participation ratio bound PR ~ O(1) is numerically observed but
  proving it requires controlling the interaction between GCD structure
  and the Vasyunin formula.
- Even the eigenvalue density result (#{λ < τ} ~ log(1/τ)) would require
  new Weyl law technology.

### Difficulty: ★★★★★

This is an open problem in spectral theory. Doable in principle but
would require 1000+ lines of new formalization.

---

## Path C: Prove `witness_numerator_rate` Unconditionally (★★★ Medium)

### Idea

From `GramBoundReduction.lean`, we know:
```
gram_form_upper_bound + witness_numerator_rate → witness_covariance_decay
```

The `gram_form_upper_bound` is covered by the Oracle certificates.
The `witness_numerator_rate` says |bᵀv - 1| ≤ K₁/ln(N).

We already have the **qualitative** convergence (bᵀv → 1) proved from PNT.
What's missing is the **rate**: O(1/ln N).

### Mathematical route

The sum bᵀv = Σ_{k=1}^{N-1} b_{k+1} · v_{k+1} involves:
- b_k = ∫₀¹ {1/(kx)} dx = 1 - 1/k (proved: `vasyunin_mean_eq_integral`)
- v_k = -μ(k)(1 - ln k / ln N) (logCutoffWitness)

So bᵀv = -Σ_{k=2}^N μ(k)(1 - 1/k)(1 - ln k / ln N)

The PNT gives Σ_{k≤x} μ(k) = o(x), and the log-tapered version gives:
```
Σ_{k≤N} μ(k)(1 - ln k / ln N) = 1 + O(1/ln N)
```

This is a standard result from the PNT with error term (de la Vallée-Poussin, 1899):
```
Σ_{k≤x} μ(k)/k = O(1/ln x)    [Mertens third theorem + PNT]
```

### Existing Cathedral tools

From `PNT/AbelMean.lean`:
```lean
-- pnt_mu_log_div_k is an axiom (PNT import)
-- pnt_mu_log_sq_div_k is an axiom (PNT import)
```

These are the Abel means of μ(k)/k and μ(k)·(ln k)²/k from
PrimeNumberTheoremAnd. They provide exactly the convergence rate
needed for `witness_numerator_rate`.

### The key insight

`witness_numerator_convergence_proved` (already a theorem!) proves bᵀv → 1
using these same PNT imports. The proof in `WitnessNumeratorProved.lean`
gives qualitative convergence but **the rate is implicit in the proof**.

If we extract the rate from the proof, we get |bᵀv - 1| ≤ C/ln N for
some explicit C, which is exactly `witness_numerator_rate`.

### Difficulty: ★★★

Requires making the convergence rate in `witness_numerator_convergence_proved`
explicit. The mathematics is well-understood — it's a matter of tracking
constants through the Abel summation.

---

## Path D: Direct Oracle + Spectral Bypass (★ Trivial)

### Idea

Don't touch the Heisenberg path at all. The Oracle path already
proves RH independently. The Heisenberg path's theoretical value
is in its **spectral decomposition** (IR/UV energy partition), not
in proving RH per se.

### What this means

Leave `infrared_safety` and `witness_covariance_decay` as axioms.
They are **structurally interesting** (they reveal the spectral
anatomy of the proof) but **not needed** for any active proof path.

Document them as "spectral observatory results" — theorems that
describe the internal structure of the Gram matrix eigenspace, which
are of independent interest but not load-bearing for RH.

### Difficulty: ★ (just documentation)

---

## Recommendation Matrix

| Path | Effort | New Axioms | Value | Recommendation |
|------|--------|------------|-------|----------------|
| **A: Gram re-route** | ★★ | 0 new | Unifies Heisenberg + Oracle | **DO THIS** |
| B: IR safety | ★★★★★ | 0 | Spectral anatomy | Research project |
| C: Numerator rate | ★★★ | 0 | Closes GramBoundReduction | Nice-to-have |
| D: Leave as-is | ★ | 0 | Documentation | Already done |

### The Optimal Strategy: Path A

**Route the Heisenberg path through the Gram bound**, eliminating the
dependency on `witness_covariance_decay`. This:

1. **Makes the Heisenberg path share the same axiom** as the Oracle path
   (`gram_form_upper_bound_subseq` / `oracle_certificates`)
2. **Zero new axioms** — just different assembly of existing proved theorems
3. **Unifies the proof architecture** — all paths converge on the Gram bound
4. **~50 lines of new Lean code** — the proof mirrors `gram_bound_implies_rh`

After this refactoring:

```
oracle_certificates (TRUSTED)
     ↓
gram_form_upper_bound_subseq
     ├── gram_bound_subseq_implies_rh ──→ RH  (Oracle path, direct)
     └── spectral_energy_witness_lower_from_gram
              ↓
         total_spectral_energy_tendsto_one
              ↓
         heisenberg_implies_d_sq_zero ──→ d²→0  (Heisenberg path, spectral)
```

Both paths use the same axiom. The Cathedral becomes a **diamond**:
one axiom at the top, two paths through the middle, and RH at the bottom.

---

## What Remains Truly Unconditional

Even after Path A, the Heisenberg path needs `gram_form_upper_bound_subseq`,
which is equivalent to RH. There is **no unconditional proof of d²→0**
without assuming something equivalent to RH — because d²→0 IS RH
(by `nyman_beurling_converse`).

The best we can do is:
1. **Minimize the axiom footprint** (Path A: one oracle axiom)
2. **Maximize the proved content** (everything except the numerical data)
3. **Document the spectral structure** (IR/UV partition as observation)

The Riemann Hypothesis is, fundamentally, **the statement that d²→0**.
No re-routing can eliminate this. But we can make the axiom as concrete
and verifiable as possible — which is exactly what the Oracle Bridge does.

---

*End of report. The Cathedral knows its own shape.*
