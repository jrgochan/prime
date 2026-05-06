/-!
  # Zero-Axiom Forward Direction

  This directory contains the proof of `baez_duarte_forward`:

  `RH → ∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v, ∫₀¹ (1 - f_N)² < ε`

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
