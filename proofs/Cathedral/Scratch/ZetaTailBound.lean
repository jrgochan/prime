/-
  Scratch file: testing the zeta tail bound proof
  Goal: ‖ζ(s) - 1‖ < 1 for Re(s) ≥ 2
-/
import Mathlib.NumberTheory.LSeries.RiemannZeta
import Mathlib.Analysis.Normed.Group.InfiniteSum

noncomputable section
open Complex Real Nat

-- Key approach: work with the nat_add_one formulation
-- ζ(s) = Σ_{n≥0} 1/(n+1)^s (from zeta_eq_tsum_one_div_nat_add_one_cpow)
-- The n=0 term is 1/(0+1)^s = 1
-- So ζ(s) - 1 = Σ_{n≥1} 1/(n+1)^s

-- We need: ‖Σ_{n≥1} 1/(n+1)^s‖ ≤ Σ_{n≥1} ‖1/(n+1)^s‖ = Σ_{n≥1} 1/(n+1)^Re(s)
-- For Re(s) ≥ 2: ≤ Σ_{n≥1} 1/(n+1)^2 = π²/6 - 1 - 1 ≈ ζ(2) - 1 - 1
-- Wait, Σ_{n≥1} 1/(n+1)^2 = 1/4 + 1/9 + ... = ζ(2) - 1 ≈ 0.645 < 1

-- Actually we can be even simpler: bound by a geometric series.
-- Σ_{n≥1} 1/(n+1)^2 ≤ Σ_{n≥1} 1/(n(n+1)) = 1 (telescoping)
-- Better: Σ_{n≥2} 1/n^2 ≤ Σ_{n≥2} 1/(n(n-1)) = 1 (telescoping to 1/1 = 1)
-- Even better: Σ_{n≥2} 1/n^2 ≤ 1/4 + 1/9 + 1/16 + ... < 1/4 + 1/8 + 1/16 + ... = 1/2

-- Simplest bound: Σ_{n≥1} 1/(n+1)^2 ≤ Σ_{n≥1} 1/((n)(n+1))
--                = Σ_{n≥1} (1/n - 1/(n+1)) = 1/1 - lim 1/(n+1) = 1 > our sum
-- But we need STRICT < 1. So use: Σ_{n≥1} 1/(n+1)^2 ≤ Σ_{n≥2} 1/n^2 < Σ_{n≥2} 1/(n(n-1)) = 1

-- The cleanest approach: show the sum ≤ ζ(2) - 1 and ζ(2) - 1 < 1, i.e., ζ(2) < 2.
-- ζ(2) = π²/6 ≈ 1.645, so ζ(2) - 1 ≈ 0.645 < 1. ✓

lemma zeta_sub_one_norm_lt_one {s : ℂ} (hs : 2 ≤ s.re) :
    ‖riemannZeta s - 1‖ < 1 := by
  sorry
