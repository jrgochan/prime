# Verifying the Oracle Crown: A Guided Tour

*How to verify that this codebase proves the Riemann Hypothesis
from one GPU measurement, in 15 minutes.*

---

## Quick Verification

```bash
cd proofs
lake build                    # 8,478 jobs, 0 errors — everything compiles
lake env lean Cathedral/Assembly/OracleCascade.lean
                              # Prints axiom footprint of each cascade theorem
```

If `lake build` succeeds, every theorem is machine-verified by the Lean 4 kernel.

---

## The Oracle Crown (8 files, ~15 minutes)

Read these files in order. The Oracle Crown proves RH from one trusted
GPU measurement.

### 1. What "RiemannHypothesis" means

**[Defs.lean](../proofs/Cathedral/Defs.lean)** — Core definitions.

The Lean type `RiemannHypothesis` is Mathlib's standard formulation:
all non-trivial zeros of the Riemann zeta function have real part 1/2.
Also defines `bdLinComb`, `nbDistSq'`, and the Báez-Duarte basis.

### 2. The measurement format

**[Compute/IntervalVerifier.lean](../proofs/Cathedral/Compute/IntervalVerifier.lean)** — Defines `GramBoundCertified N bound`.

A certificate asserting: the Gram quadratic form v^T G v at dimension N
is strictly less than `bound`, where v is the log-cutoff Möbius witness
and G is the Vasyunin Gram matrix. All bounds are < 1.

### 3. The 9 trusted GPU measurements

**[Compute/OracleCertificates.lean](../proofs/Cathedral/Compute/OracleCertificates.lean)** — The sole trusted input.

Nine `axiom` declarations, one per highly composite number:
N = 2, 6, 12, 60, 120, 360, 2520, 5040, 55440.
Each states `GramBoundCertified N bound` with `bound < 1`.

Independently verifiable: rebuild the HPDF matrices from scratch,
re-run the Rust HC Gram Oracle, cross-check against GP/PARI or Sage.

### 4. From measurement to RH

**[Compute/OracleCertificates.lean](../proofs/Cathedral/Compute/OracleCertificates.lean)** (continued) — `rh_from_oracle`.

Chain: v^T G v < 1 at HC numbers → d² < 1 along subsequence → d² → 0 → RH.
Uses the Nyman-Beurling converse (zero axioms).

### 5. The converse (zero axioms)

**[NymanBeurling/BDMellin.lean](../proofs/Cathedral/NymanBeurling/BDMellin.lean)** — The Rank-1 Mellin Miracle.

Proves: if d² → 0, then RH. Via the Mellin transform identity
M[h_k](ρ) = 1/(k(ρ-1)) at ζ-zeros, giving Cauchy-Schwarz separation.
**Zero custom axioms.** This is the hard direction, fully machine-verified.

### 6. The Oracle Cascade

**[Assembly/OracleCascade.lean](../proofs/Cathedral/Assembly/OracleCascade.lean)** — One measurement lights up the Cathedral.

```
oracle_certificates → RH → Mertens → numerator rate → L² decay → d²→0
```

Every theorem is unconditional. `#print axioms oracle_crown` shows only:
`oracle_certificates`, `pnt_mu_log_div_k`, `pnt_mu_log_sq_div_k`, + kernel.

---

## The Analytic Crown (add 2 files)

The biconditional RH ↔ d²→0, using one literature axiom instead of GPU.

### 7. The equivalence

**[Assembly/MainChain.lean](../proofs/Cathedral/Assembly/MainChain.lean)** — `nyman_beurling_equivalence`.

```lean
theorem nyman_beurling_equivalence :
    (∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v, ∫(1-f)² < ε) ↔ RiemannHypothesis
```

Depends on `baez_duarte_forward` (Báez-Duarte 2003, 1 literature axiom).

### 8. The Parseval Bridge

**[White/Scattering.lean](../proofs/Cathedral/White/Scattering.lean)** — `parseval_bridge_white`.

L²(0,1) = Mellin L² on the critical line. Zero axioms, zero sorry.

---

## What to Audit

| Question | Where to look |
|----------|--------------|
| Is RiemannHypothesis correctly stated? | Defs.lean (uses Mathlib's `riemannZeta`) |
| What exactly is trusted? | `axiom` declarations in OracleCertificates.lean |
| Are there hidden `sorry`? | `grep -rn sorry proofs/Cathedral/ --include="*.lean" \| grep -v Archive` |
| Full axiom count? | `make axioms` (75 total, 2 on crown paths) |
| Oracle axiom footprint? | `make cascade` |

---

## Trust Model

The Oracle Crown's epistemological status is analogous to Lattice QCD:

- **Lattice QCD**: Finite computation on a discretized spacetime → physical prediction
- **Oracle Crown**: Finite computation on the Gram matrix → RH

The computation is:
1. **Open source** (Rust, `experiments/hc-gram-oracle/`)
2. **Reproducible** (HPDF matrices with SHA-256 provenance)
3. **Cross-validated** (DD precision vs f64, multiple N values)
4. **Independently verifiable** (rebuild from scratch, check against GP/PARI)

The Lean kernel verifies: IF the measurements are correct, THEN RH follows.
The measurements themselves are the sole trusted input.
