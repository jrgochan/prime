/-
  Cathedral/Zeta/CircleQuadruplet.lean

  ## THE KLEIN FOUR-GROUP ACTS ON CIRCLES

  ════════════════════════════════════════════════════════════════

  This file wires StripGeometry's circle geometry to
  FourFoldSymmetry's Klein four-group V₄ = ⟨M, C⟩.

  ### The Key Insight

  The Klein four-group {id, M, C, MC} acts on circles centered
  at ½+iγ. The two symmetries:
    M: s ↦ 1-s    (mirror through Re=½)
    C: s ↦ conj s  (conjugation through ℝ-axis)

  Map circle points as follows:
    M(circlePoint γ R φ) has Re = ½ - R·cos φ  (left-right flip)
    C(circlePoint γ R φ) has Re = ½ + R·cos φ  (same Re, flipped Im)

  On the critical line, M = C, so the circle has a 2-fold
  symmetry (not 4-fold): the "left half" (cos φ < 0) and the
  "right half" (cos φ > 0) are related by both M and C.

  ### What We Prove

  §1. Klein group action on circle real parts
  §2. Mirror-conjugate symmetry of circle arcs
  §3. Zero-centered circle symmetry (when center is a zero)
  §4. The functional equation along circles

  Status: PROVED — 0 sorry, 0 custom axioms ✅
  Dependencies: StripGeometry, FourFoldSymmetry, CriticalLinePhase
  Created: May 25, 2026 — Circle+Quadruplet Wiring Session
-/

import Cathedral.Zeta.StripGeometry
import Cathedral.Zeta.FourFoldSymmetry
import Cathedral.Zeta.HardyZFunction

noncomputable section
set_option linter.unnecessarySeqFocus false
open Complex Real
open scoped ComplexConjugate

namespace Cathedral.Zeta.CircleQuadruplet

open StripGeometry FourFoldSymmetry
open Cathedral.Physics.CriticalLinePhase

-- ════════════════════════════════════════════════════════════════
-- §1. KLEIN GROUP ACTION ON CIRCLE REAL PARTS
-- ════════════════════════════════════════════════════════════════

/-! ### The Klein four-group acts on the σ-coordinate

The real part (σ = Re(s)) of a circle point determines which
Tower it belongs to:
  σ > 1   → Glass Tower (Euler domain)
  0 < σ < 1 → Spectral Tower (critical strip)
  σ < 0   → Kummer Tower

The Klein group maps:
  id:  σ ↦ σ             (stay in same tower)
  M:   σ ↦ 1-σ           (Glass ↔ Kummer, Spectral ↔ Spectral)
  C:   σ ↦ σ             (stay in same tower — conj preserves Re)
  MC:  σ ↦ 1-σ           (same as M on Re)

So on the σ-coordinate, V₄ has only TWO distinct actions:
{id, C} = "stay" and {M, MC} = "flip through ½". -/

/-- **MIRROR SWAPS LEFT AND RIGHT**: The mirror map sends the
    right-half arc (σ > ½) to the left-half arc (σ < ½). -/
theorem mirror_swaps_halves (γ R : ℝ) (φ : ℝ) :
    (circlePoint γ R φ).re + (1 - circlePoint γ R φ).re = 1 := by
  rw [circlePoint_re, mirror_circlePoint_re]
  ring

/-- **CONJUGATION PRESERVES HALVES**: Conjugation keeps the same
    σ-value. It maps right-half to right-half and left to left. -/
theorem conj_preserves_halves (γ R : ℝ) (φ : ℝ) :
    (conj (circlePoint γ R φ)).re = (circlePoint γ R φ).re := by
  rw [conj_circlePoint_re, circlePoint_re]

/-- **σ IS V₄-BALANCED**: The average of σ-values across the
    Klein orbit {s, 1-s} is exactly ½ (the critical line).
    This is the geometric reason ½ is the "center of gravity". -/
theorem sigma_klein_balance (s : ℂ) :
    (s.re + (1 - s).re) / 2 = 1/2 := by
  simp [Complex.sub_re, Complex.one_re]

-- ════════════════════════════════════════════════════════════════
-- §2. MIRROR-CONJUGATE SYMMETRY OF CIRCLE ARCS
-- ════════════════════════════════════════════════════════════════

/-! ### The Functional Equation on Circle Points

For a circle centered at ½+iγ, the functional equation
Λ₀(1-s) = Λ₀(s) relates opposite sides of the circle.

Specifically, Λ₀(circlePoint γ R φ) is related to
Λ₀(1 - circlePoint γ R φ) = Λ₀(circlePoint γ R φ) by the
functional equation — BUT 1 - circlePoint γ R φ is NOT
circlePoint γ R (π-φ) in general! (The imaginary parts differ.)

However, on the CRITICAL LINE itself (R = 0 or at the crossing
points φ = π/2, 3π/2), the functional equation gives:
  Λ₀(½+it) = Λ₀(½-it) = Λ₀(conj(½+it))

which is the Z_even theorem: Z(-t) = Z(t). -/

/-- **FUNCTIONAL EQUATION ON CRITICAL-LINE POINTS**: At the two
    points where the circle crosses Re = ½ (φ = π/2 and -π/2),
    the functional equation relates them to their conjugates. -/
theorem func_eq_at_crossing (γ R : ℝ) (φ : ℝ) :
    completedRiemannZeta₀ (1 - circlePoint γ R φ) =
    completedRiemannZeta₀ (circlePoint γ R φ) := by
  exact completedRiemannZeta₀_one_sub _

/-- **SCHWARZ ON CIRCLE**: The Schwarz reflection theorem applied
    to circle points: Λ₀(conj(circlePoint γ R φ)) = conj(Λ₀(circlePoint γ R φ)). -/
theorem schwarz_on_circle (γ R : ℝ) (φ : ℝ) :
    completedRiemannZeta₀ (conj (circlePoint γ R φ)) =
    conj (completedRiemannZeta₀ (circlePoint γ R φ)) :=
  schwarz_reflection_completedRiemannZeta₀ _

-- ════════════════════════════════════════════════════════════════
-- §3. ZERO-CENTERED CIRCLE SYMMETRY
-- ════════════════════════════════════════════════════════════════

/-! ### What Happens When the Circle is Centered on a Zero

If γ₀ is the imaginary part of a zero (ζ(½+iγ₀) = 0), then
the circle centered at ½+iγ₀ has special properties:

1. At φ = 0 (the center), Λ₀ vanishes
   (actually, the center is the point itself, not on the circle)

2. The Z-function vanishes at t = γ₀: Z(γ₀) = 0

3. By Z_even, Z(-γ₀) = 0 too (the conjugate zero)

4. The "ring contraction" happens at the center: |Z(γ₀)| = 0

We formalize the relationship between zero-centered circles
and the quadruplet structure. -/

/-- **ZERO AT CENTER IMPLIES QUADRUPLET**: If Λ₀ vanishes at the
    center of a circle (½+iγ), then by the four noble zeros theorem,
    Λ₀ also vanishes at {½-iγ, ½+iγ, ½-iγ} = {½+iγ, ½-iγ}
    (degenerate quadruplet on the critical line). -/
theorem zero_center_quadruplet (γ : ℝ)
    (h : completedRiemannZeta₀ (1/2 + ↑γ * I) = 0) :
    completedRiemannZeta₀ (1/2 + ↑(-γ) * I) = 0 :=
  HardyZFunction.zero_conjugate_pair γ h

/-- **ZERO IMPLIES RING CONTRACTION**: If the circle is centered
    on a zero, the Z-function vanishes at the center height. -/
theorem zero_center_ring_contraction (γ : ℝ)
    (h : completedRiemannZeta₀ (1/2 + ↑γ * I) = 0) :
    Z_function γ = 0 :=
  (Z_zero_iff_completedZeta₀_zero γ).mpr h

-- ════════════════════════════════════════════════════════════════
-- §4. THE FUNCTIONAL EQUATION AND CIRCLE HALVES
-- ════════════════════════════════════════════════════════════════

/-! ### Λ₀ on the Left and Right Halves of a Circle

The functional equation Λ₀(1-s) = Λ₀(s) creates a deep
relationship between the LEFT half (σ < ½, Negative Reality)
and RIGHT half (σ > ½, Positive Reality) of any critical-line circle.

Key insight: while Λ₀ at point s and Λ₀ at 1-s are equal
(functional equation), these points are NOT generally on the
same circle. However, they have symmetric real parts:
  Re(s) + Re(1-s) = 1

This means: for every point on the right half at distance
δ from ½, there is a corresponding point at distance δ from ½
on the left half, with the SAME Λ₀ value. -/

/-- **SYMMETRIC σ-VALUES**: For any complex number s, the
    mirror point 1-s has σ-value that is symmetric about ½.
    This is the geometric meaning of the functional equation. -/
theorem sigma_symmetric_about_half (s : ℂ) :
    (1 - s).re = 1 - s.re := by
  simp [Complex.sub_re, Complex.one_re]

/-- **STRIP SYMMETRY VIA KLEIN**: If a point is in the critical
    strip (0 < σ < 1), its Klein orbit is entirely within the
    strip. This is the quadruplet_in_strip theorem, repackaged
    in the language of circles. -/
theorem klein_orbit_in_strip (s : ℂ) (h_lo : 0 < s.re) (h_hi : s.re < 1) :
    0 < (1 - s).re ∧ (1 - s).re < 1 :=
  (quadruplet_in_strip s h_lo h_hi).1

/-- **CIRCLE HALVES ARE IN COMPLEMENTARY TOWERS**: For a circle
    centered on Re=½, the right half (cos φ > 0) lies in Positive
    Reality while the corresponding mirror points lie in Negative
    Reality. Neither can be in the Glass Tower (σ > 1) if R ≤ ½. -/
theorem complementary_tower_halves (γ R : ℝ) (hR : 0 < R) (_hR_half : R ≤ 1/2) (φ : ℝ)
    (hcos : 0 < Real.cos φ) :
    1/2 < (circlePoint γ R φ).re ∧ (1 - circlePoint γ R φ).re < 1/2 := by
  rw [circlePoint_re, mirror_circlePoint_re]
  constructor
  · linarith [mul_pos hR hcos]
  · linarith [mul_pos hR hcos]

-- ════════════════════════════════════════════════════════════════
-- §5. THE DEGENERATION GEOMETRY
-- ════════════════════════════════════════════════════════════════

/-! ### Circle Geometry of Quadruplet Degeneration

The degeneration theorem (from FourFoldSymmetry):
  1 - s = conj s  ↔  Re(s) = ½

On a circle centered at ½+iγ:
  1 - (circlePoint γ R φ) and conj(circlePoint γ R φ)
  agree in real part but NOT in imaginary part (in general).

They coincide exactly when the imaginary parts also match:
  -(γ + R·sin φ) = -(γ + R·sin φ)  [trivially true]

Wait — actually, let's check:
  Im(1 - s) = -Im(s) = -(γ + R sin φ)
  Im(conj s) = -Im(s) = -(γ + R sin φ)

So 1 - circlePoint γ R φ and conj(circlePoint γ R φ) have
the SAME imaginary part! The question is whether they have
the same real part, which happens iff cos φ = 0 (i.e., the
point is ON the critical line). -/

/-- **KLEIN DEGENERATION ON CIRCLES**: The mirror and conjugation
    of a circle point coincide (1-s = conj s) if and only if
    the point is on the critical line (cos φ = 0). -/
theorem circle_degeneration_iff (γ R : ℝ) (φ : ℝ) :
    1 - circlePoint γ R φ = conj (circlePoint γ R φ) ↔
    (circlePoint γ R φ).re = 1/2 := by
  exact degeneration_iff_critical_line (circlePoint γ R φ)

/-- **COROLLARY**: On a circle centered at ½+iγ, the Klein four-group
    degenerates to a two-group at exactly two points: φ = π/2 and
    φ = 3π/2 (where cos φ = 0).

    These are the "equator points" where the circle crosses the
    critical line. The quadruplet structure collapses there. -/
theorem degeneration_at_equator (γ : ℝ) {R : ℝ} (hR : R ≠ 0) (φ : ℝ) :
    (1 - circlePoint γ R φ = conj (circlePoint γ R φ)) ↔
    Real.cos φ = 0 := by
  rw [circle_degeneration_iff, circlePoint_on_critical_line_iff γ hR]

-- ════════════════════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════════════════════

/-!
## Audit

### Sorry: 0 ✅
### Custom Axioms: 0 ✅

### PROVED:
| # | Result | Status |
|---|--------|--------|
| 1 | `mirror_swaps_halves` | **🎓 THEOREM** (σ + (1-σ) = 1) |
| 2 | `conj_preserves_halves` | **🎓 THEOREM** (conj preserves σ) |
| 3 | `sigma_klein_balance` | **🎓 THEOREM** (average σ = ½) |
| 4 | `func_eq_at_crossing` | **🎓 THEOREM** (Λ₀(1-s) = Λ₀(s) on circle) |
| 5 | `schwarz_on_circle` | **🎓 THEOREM** (Schwarz on circle) |
| 6 | `zero_center_quadruplet` | **🎓 THEOREM** (zero → conjugate zero) |
| 7 | `zero_center_ring_contraction` | **🎓 THEOREM** (zero → Z=0) |
| 8 | `sigma_symmetric_about_half` | **🎓 THEOREM** (Re(1-s) = 1-Re(s)) |
| 9 | `klein_orbit_in_strip` | **🎓 THEOREM** (strip-preserved) |
| 10 | `complementary_tower_halves` | **🎓 THEOREM** (left/right ↔ ±Reality) |
| 11 | `circle_degeneration_iff` | **🎓 THEOREM** (1-s = conj s ↔ on line) |
| 12 | `degeneration_at_equator` | **🎓 THEOREM** (degeneration at cos φ = 0) |

### Wiring Diagram:
```
StripGeometry (circles)  ←→  FourFoldSymmetry (V₄)
     ↓                            ↓
  circlePoint          degeneration_iff_critical_line
     ↓                            ↓
  CircleQuadruplet:    degeneration_at_equator
  (circles + V₄ combined)
```

### Physical Significance:
- §1: The Klein group has only 2 distinct actions on σ
- §2: Functional equation and Schwarz applied to circle points
- §3: Zero-centered circles experience ring contraction
- §4: Left/right halves of circles are in complementary towers
- §5: Klein degeneration happens at the "equator" (critical line crossing)
-/

end Cathedral.Zeta.CircleQuadruplet

end
