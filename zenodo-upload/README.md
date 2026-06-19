# The Cathedral: A Machine-Verified Architecture for the Riemann Hypothesis

**Author:** Jason R. Gochan  
**Date:** June 2026  
**License:** CC BY 4.0

## Overview

The Cathedral is a formally verified mathematical architecture establishing an
equivalence between the Riemann Hypothesis and the positivity of a
Nyman–Beurling L² distance, machine-checked in Lean 4 with Mathlib. The proof
achieves a zero-`sorry` verification with a two-axiom foundation.

## Repository Contents

### Core Papers (Peer-Review Ready)

| File | Pages | Description |
|------|-------|-------------|
| `papers/core/cathedral.pdf` | 23 | Main proof paper: Nyman–Beurling equivalence via L² decay |
| `papers/core/cathedral-lean.pdf` | 7 | Lean 4 formalization details and axiom audit |
| `papers/core/cathedral-glass-bridge.pdf` | 7 | Glass Tower: Euler product via Cayley–Dickson algebras |
| `papers/core/cathedral-overcancellation.pdf` | 7 | Overcancellation identity and Mellin bridge |

### Science Papers

| File | Pages | Description |
|------|-------|-------------|
| `papers/science/cathedral-physics.pdf` | 76 | Physics dictionary: 180+ correspondences between number theory and QFT |
| `papers/science/cathedral-experiments.pdf` | 7 | GPU-accelerated spectral experiments (cuSOLVER, MPFR) |
| `papers/science/cathedral-ai.pdf` | 6 | AI collaboration methodology |
| `papers/science/cathedral-particle-zoo.pdf` | 10 | Arithmetic particle zoo: fermions, bosons, and color confinement |

### Application Papers

| File | Pages | Description |
|------|-------|-------------|
| `papers/applications/cathedral-dualuse.pdf` | 18 | Dual-use analysis and responsible disclosure |
| `papers/applications/cathedral-engineering.pdf` | 11 | Engineering applications |
| `papers/applications/cathedral-frontiers.pdf` | 7 | Research frontiers and open questions |

### Humanities Papers

| File | Pages | Description |
|------|-------|-------------|
| `papers/humanities/cathedral-philosophy.pdf` | 24 | Philosophy of mathematics and formal verification |
| `papers/humanities/cathedral-fun.pdf` | 8 | The Cathedral Kitchen: accessible exposition |

### Mathematics Papers

| File | Pages | Description |
|------|-------|-------------|
| `papers/math/cathedral.pdf` | 9 | Extended mathematical foundations |

### Public-Facing Papers

| File | Pages | Description |
|------|-------|-------------|
| `papers/public/cathedral-public.pdf` | 5 | Public summary |
| `papers/public/cathedral-claude.pdf` | 12 | Claude collaboration report |
| `papers/public/cathedral-gemini.pdf` | 5 | Gemini collaboration report |

### Policy Papers

| File | Pages | Description |
|------|-------|-------------|
| `papers/policy/cathedral-policy.pdf` | 4 | Policy implications |

### Lean 4 Source Code

| File | Description |
|------|-------------|
| `cathedral-lean-proofs.tar.gz` | Complete Lean 4 formalization (618 files, zero `sorry` on crown path) |

## Verification

To verify the Lean proofs:

```bash
tar xzf cathedral-lean-proofs.tar.gz
cd proofs
lake build
```

Requires: Lean 4 (v4.x) and Mathlib.

## Key Results

- **Nyman–Beurling Equivalence**: RH ⟺ d²_N → 0 in L²(0,1)
- **Axiom Foundation**: Two axioms (PNT error rate, Ramanujan sum bound)
- **618 Lean files**, zero `sorry` on the crown path (4 off-crown in exploratory code)
- **180+ physics correspondences** between number theory and quantum field theory
- **Arithmetic Standard Model**: The integers generate a gauge theory with zero free parameters

## Citation

```bibtex
@misc{gochan2026cathedral,
  author = {Gochan, Jason R.},
  title = {The Cathedral: A Machine-Verified Architecture for the Riemann Hypothesis},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.XXXXXXX}
}
```

## Contact

Jason R. Gochan — jrgochan@proton.me
