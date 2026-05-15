# Files to Share with Gemini Theorist

## Essential (share these)

1. **This report**: `docs/ai/antigravity/exploration4/perron_moebius_report.md`
2. **Main proof file**: `proofs/Cathedral/White/Infrastructure/Perron/PerronMoebius.lean`
3. **L-series = 1/ζ**: `proofs/Cathedral/White/Infrastructure/DirichletZetaInverse.lean`

## Recommended (for full context)

4. **Perron formula imports**: `proofs/Cathedral/White/Infrastructure/Perron/Formula.lean`
5. **Zeta convexity bounds**: `proofs/Cathedral/White/Infrastructure/ZetaConvexity.lean`
6. **Top-level assembly**: `proofs/Cathedral/Assembly/MertensFromPerron.lean`

## Optional (archive templates)

7. `proofs/Cathedral/Archive/HighFrequencyTrap/MellinBridge/FloorMellin.lean`
8. `proofs/Cathedral/Archive/HighFrequencyTrap/MellinBridge/AbelSummation.lean`

## Key Questions to Highlight

The **single most impactful question** is Q1: closing `rpow_tail_bound` (the integral test
∑_{n>N} 1/n^σ ≤ N^{1-σ}/(σ-1)) cascades through the entire assembly chain.

All the Mathlib pieces exist (`AntitoneOn.sum_le_integral` + `integral_Ioi_rpow_of_lt`),
but connecting them via the K→∞ limit passage is the blocker. Any ideas on the cleanest
Lean 4 proof strategy here would be extremely valuable.

Secondary: Q3 (riemannZeta_conj via Identity Theorem) and Q4 (ContinuousOn at s=1)
are independently interesting.
