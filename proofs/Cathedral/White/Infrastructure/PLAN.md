# White Singlet Infrastructure Plan

## Overview

This plan documents the infrastructure layer required to complete the White Singlet — 
the zero-axiom, compiler-verified proof of the Riemann Hypothesis in Lean 4.

The infrastructure consists of 5 files in `Cathedral/White/Infrastructure/`, each 
containing pure mathematical theorems that belong in Mathlib regardless of our RH project.

## Architecture

```
Cathedral/White/Infrastructure/
├── DirichletSeries.lean      — Abel summation for L-series
├── Perron.lean                — Quantitative Perron's formula
├── ZetaConvexity.lean         — Conditional Lindelöf bound (RH → 1/ζ bound)
├── HilbertInequality.lean     — Schur's Test + Montgomery-Vaughan
└── MontgomeryVaughan.lean     — Mean value theorems for Dirichlet polynomials
```

## Dependency Graph

```
DirichletSeries ──→ Perron ──→ Dynamics.lean (Axiom 1)
                        ↑
              ZetaConvexity ─┘

HilbertInequality ──→ MontgomeryVaughan ──→ Unitarity.lean (Axiom 5)
```

## Mathlib Coverage (Post-Excavation)

| File | Mathlib Coverage | Gap Size | Timeline |
|------|-----------------|----------|----------|
| DirichletSeries | `AbelSummation.lean` (Cathedral) | Medium | Months |
| Perron | `MellinInversion.lean` (foundation) | Hard | 1-2 years |
| ZetaConvexity | `PhragmenLindelof.lean` (PL principle) | Hard | 1-2 years |
| HilbertInequality | ❌ Nothing | **Genuine gap** | 6-12 months |
| MontgomeryVaughan | ❌ Nothing | Hard | 1-2 years |

## Phase I Status (Current Sprint)

### Kinematics.lean — COMPLETE ✅🤍
- [x] `autocorr_eval_zero_proved` — Axiom 2 eliminated
- [x] `flattened_l2_eq_residual_l2` — Jacobian absorption
- [x] `full_integral_eq_halfline` — Integral splitting
- [x] `exp_neg_antitoneOn`, `hasDerivWithinAt_exp_neg`, `exp_neg_image_Ioi`

### Scattering.lean — 2 SORRY remaining
- [x] `mellin_fourier_scale_proved` — Axiom 4 eliminated ✅
- [ ] `fourier_eq_mellin_critical` — Route: `mellin_eq_fourier` from MellinInversion
- [ ] `fourier_inv_autocorr_proved` — Route: `norm_fourier_eq` from LpSpace + L² coercion

## Phase II (Future — Requires Infrastructure)

### Dynamics.lean — Not yet scaffolded
- [ ] `rh_implies_mertens_bound` — Needs Perron + ZetaConvexity

### Unitarity.lean — Not yet scaffolded
- [ ] `critical_line_mellin_bound` — Needs HilbertInequality + MontgomeryVaughan

## Next Actions

1. Close `fourier_eq_mellin_critical` using `mellin_eq_fourier`
2. Close `fourier_inv_autocorr_proved` using `norm_fourier_eq` + L² bridge
3. Open Mathlib GitHub issues for the 5 infrastructure theorems
4. Write paper describing the complete architecture
