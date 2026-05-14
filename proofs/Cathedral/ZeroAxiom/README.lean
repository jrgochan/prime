/-!
  # Zero-Axiom Forward Direction (Exploratory)

  This directory explores graduating `baez_duarte_forward` to zero custom
  axioms via explicit Dirichlet polynomial approximation.

  ## Status

  **The forward direction is ALREADY PROVED** via the Vasyunin Crown chain:
  * `baez_duarte_forward` (MainChain.lean) — PROVED via `rh_l2_decay_clean`
  * `rh_l2_decay_clean` (DirectMellinBound.lean) — PROVED via
    `gram_quadratic_form_decay` + `moebius_dot_product_approx_one_uniform_34`

  This module's approach (explicit Abel summation + Mertens bound) is an
  **alternative strategy** that is NOT on the active proof path. It is
  preserved for documentation and future research.

  ## Module Contents

  | File | Sorry | Axioms | Status |
  |------|-------|--------|--------|
  | `AbelEngine.lean` | 0 | 0 | ✅ Proved |
  | `FiniteDirichlet.lean` | 0 | 0 | ✅ Proved |
  | `MellinAlgebra.lean` | 0 | 0 | ✅ Proved |
  | `TaperedAbel.lean` | 3 | 0 | ⚠️ Exploratory sorrys (all orphaned) |

  ## Sorrys in TaperedAbel.lean

  All 3 sorrys are **off the active proof path** and do not block any export:

  1. `tapered_truncation_bound_above_34` — Abel summation + Mertens
     instantiation. Needs: interval integral of x^α, Abel summation
     infrastructure for tapered sums.

  2. `mellin_l2_integral_tendsto_zero` — ORPHANED. Superseded by
     `rh_implies_bd_convergence_mellin` (MellinCrown.lean, PROVED).

  3. `fejer_residual_l2_bound` — ORPHANED. Superseded by
     `rh_l2_decay_clean` (DirectMellinBound.lean, PROVED).

  ## Strategy: Finite Dirichlet Polynomial Approximation

  1. Construct explicit BD weights `v_k` from Möbius function
  2. Evaluate Mellin transform of residual using `bd_mellin_reduction_proved`
  3. Bound truncation error via Abel summation + `rh_implies_mertens_bound_proved`
  4. Control vertical growth via `littlewood_maneuver`
  5. Wire through `parseval_bridge_white` for L²(0,1) bound

  ## Dependencies

  * `Cathedral.White.Scattering` (Parseval bridge)
  * `Cathedral.Zeta.LittlewoodManeuver` (polynomial zeta lower bound)
  * `Cathedral.Zeta.DirichletInverse` (L(μ,s) = 1/ζ(s))
  * `Cathedral.Perron.MertensFromPerron` (RH → Mertens bound)
  * `Cathedral.NymanBeurling.BDMellin` (BD Mellin infrastructure)
-/
