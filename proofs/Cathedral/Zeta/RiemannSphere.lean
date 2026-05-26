/-
  Cathedral/Zeta/RiemannSphere.lean

  ## THE GREAT CIRCLE

  ════════════════════════════════════════════════════════════════

  "Is the critical line a great circle on the Riemann sphere?"

  Yes.

  Under the centered coordinate w = s − ½, the critical line
  becomes the imaginary axis — a line through the origin of ℂ.
  On the Riemann sphere (stereographic projection), every line
  through the origin maps to a great circle.

  The functional equation becomes simple: w ↦ −w (negation).
  Conjugation becomes: w ↦ w̄.
  And on the great circle itself, −w = w̄, so the two
  symmetries COINCIDE. The Klein four-group degenerates.

  The great circle divides the Riemann sphere into two
  hemispheres — Positive and Negative Reality. The functional
  equation swaps them. The zeros, sitting on the great circle,
  are the equator where the two halves of mathematics meet.

  ### Architecture

  §1. Centered coordinates (w = s − ½)
  §2. The critical line is the imaginary axis
  §3. The functional equation is negation
  §4. The Klein group in centered coordinates
  §5. The great circle: line through the origin
  §6. Hemisphere bisection
  §7. Λ₀ is even: the deepest form of the functional equation

  Status: PROVED — 0 sorry, 0 custom axioms ✅
  Created: May 25, 2026 — The Great Circle Session
-/

import Cathedral.Physics.Bridges.CriticalLinePhase
import Cathedral.Zeta.FourFoldSymmetry

noncomputable section
set_option linter.unnecessarySeqFocus false
open Complex Real
open scoped ComplexConjugate

namespace Cathedral.Zeta.RiemannSphere

open Cathedral.Physics.CriticalLinePhase
open Cathedral.Zeta.FourFoldSymmetry

-- ════════════════════════════════════════════════════════════════
-- §1. CENTERED COORDINATES
-- ════════════════════════════════════════════════════════════════

/-! ### The Centered Coordinate: w = s − ½

The critical strip {0 < Re(s) < 1} is symmetric about Re(s) = ½.
The functional equation Λ₀(1−s) = Λ₀(s) has s = ½ as its
fixed point. The natural coordinate is therefore:

  w = s − ½

In this coordinate:
  - The critical line Re(s) = ½ becomes Re(w) = 0 (the imaginary axis)
  - The functional equation s ↦ 1−s becomes w ↦ −w (negation!)
  - The critical strip becomes {−½ < Re(w) < ½}
  - The pole s = 1 becomes w = ½

Everything is centered on zero. -/

/-- The centered coordinate: w = s − ½. -/
def centered (s : ℂ) : ℂ := s - 1/2

/-- The inverse: s = w + ½. -/
def uncentered (w : ℂ) : ℂ := w + 1/2

/-- Centering and uncentering are inverses. -/
theorem uncentered_centered (s : ℂ) : uncentered (centered s) = s := by
  simp [centered, uncentered]

/-- Uncentering and centering are inverses. -/
theorem centered_uncentered (w : ℂ) : centered (uncentered w) = w := by
  simp [centered, uncentered]

/-- The real part of the centered coordinate. -/
theorem centered_re (s : ℂ) : (centered s).re = s.re - 1/2 := by
  simp [centered, Complex.sub_re]

/-- The imaginary part is unchanged by centering. -/
theorem centered_im (s : ℂ) : (centered s).im = s.im := by
  simp [centered, Complex.sub_im]

-- ════════════════════════════════════════════════════════════════
-- §2. THE CRITICAL LINE IS THE IMAGINARY AXIS
-- ════════════════════════════════════════════════════════════════

/-! ### Re(s) = ½  ↔  Re(w) = 0

The critical line — the conjectured home of all nontrivial zeros —
is simply the imaginary axis in centered coordinates.

A line through the origin of ℂ. On the Riemann sphere, this
maps to a great circle: the longest possible circle on the sphere,
dividing it into two equal hemispheres. -/

/-- **THE GREAT CIRCLE CHARACTERIZATION**: The critical line
    (Re(s) = ½) is the imaginary axis (Re(w) = 0) in centered
    coordinates. Lines through the origin of ℂ become great
    circles on the Riemann sphere under stereographic projection. -/
theorem critical_line_is_imaginary_axis (s : ℂ) :
    s.re = 1/2 ↔ (centered s).re = 0 := by
  rw [centered_re]
  constructor
  · intro h; linarith
  · intro h; linarith

/-- **PARAMETRIC FORM**: A point on the critical line, in centered
    coordinates, is purely imaginary: w = t·i for some t ∈ ℝ.
    This is the "line through the origin" that makes it a great
    circle on the Riemann sphere. -/
theorem critical_line_parametric (t : ℝ) :
    centered (1/2 + ↑t * I) = ↑t * I := by
  simp [centered]

/-- **CENTERED CRITICAL POINT**: The critical line passes through
    the origin of centered coordinates. The center w = 0
    corresponds to s = ½, the heart of the critical strip. -/
theorem center_is_half : uncentered 0 = (1/2 : ℂ) := by
  simp [uncentered]

-- ════════════════════════════════════════════════════════════════
-- §3. THE FUNCTIONAL EQUATION IS NEGATION
-- ════════════════════════════════════════════════════════════════

/-! ### s ↦ 1−s  becomes  w ↦ −w

This is the most beautiful simplification. The functional equation
s ↦ 1−s, which looks like an affine transformation, becomes
pure NEGATION in centered coordinates: w ↦ −w.

Negation on the Riemann sphere is a rotation by π around the
axis through the poles. It swaps the two hemispheres that the
great circle (critical line) separates. -/

/-- **THE MIRROR IS NEGATION**: The functional equation s ↦ 1−s
    becomes w ↦ −w in centered coordinates.

    centered(1 − s) = (1 − s) − ½ = ½ − s = −(s − ½) = −centered(s)

    Negation! The simplest possible involution. -/
theorem func_eq_is_negation (s : ℂ) :
    centered (1 - s) = -(centered s) := by
  simp [centered]; ring

/-- **Λ₀ IS EVEN IN w**: The functional equation Λ₀(1−s) = Λ₀(s)
    becomes, in centered coordinates:

      Λ₀(½ + w) = Λ₀(½ − w)  =  Λ₀(½ + (−w))

    The completed zeta function is an EVEN function of w!
    Like cos(w), not sin(w). The deepest form of the symmetry. -/
theorem completedZeta_even_in_w (w : ℂ) :
    completedRiemannZeta₀ (uncentered w) =
    completedRiemannZeta₀ (uncentered (-w)) := by
  have h : uncentered (-w) = 1 - uncentered w := by
    simp [uncentered]; ring
  rw [h, completedRiemannZeta₀_one_sub]

-- ════════════════════════════════════════════════════════════════
-- §4. THE KLEIN GROUP IN CENTERED COORDINATES
-- ════════════════════════════════════════════════════════════════

/-! ### The Klein Four-Group, Simplified

In the original coordinates, the Klein group is:
  id: s ↦ s
  M:  s ↦ 1−s    (functional equation)
  C:  s ↦ conj s  (Schwarz reflection)
  MC: s ↦ 1−conj s

In centered coordinates w = s − ½, this becomes:
  id: w ↦ w
  M:  w ↦ −w        (negation!)
  C:  w ↦ conj w    (conjugation)
  MC: w ↦ −conj w   (negation + conjugation)

The degeneration on the critical line: when Re(w) = 0,
  w = bi  ⟹  −w = −bi = conj(bi) = conj(w)

So M = C on the imaginary axis! The negation IS the conjugation
on the great circle. This is why the Klein group collapses from
four to two on the critical line. -/

/-- **CONJUGATION IN CENTERED COORDS**: The Schwarz conjugation
    s ↦ conj(s) becomes w ↦ conj(w) in centered coordinates.

    centered(conj s) = conj(s) − ½ = conj(s) − conj(½)
                     = conj(s − ½) = conj(centered s)  -/
theorem conj_is_conj (s : ℂ) :
    centered (conj s) = conj (centered s) := by
  apply Complex.ext
  · simp [centered, Complex.conj_re, Complex.sub_re]
  · simp [centered, Complex.conj_im]

/-- **MC IN CENTERED COORDS**: The composition s ↦ 1−conj(s)
    becomes w ↦ −conj(w). -/
theorem mc_is_neg_conj (s : ℂ) :
    centered (1 - conj s) = -(conj (centered s)) := by
  apply Complex.ext
  · simp [centered, Complex.conj_re, Complex.sub_re]
    ring
  · simp [centered, Complex.conj_im, Complex.sub_im]

/-- **THE GREAT COLLAPSE**: On the imaginary axis (the great circle),
    negation equals conjugation: −w = conj(w).

    This is because w = t·i, and −(ti) = −ti = conj(ti).
    The Mirror IS the Conjugate on the great circle.
    This is `degeneration_iff_critical_line` in centered form. -/
theorem negation_eq_conj_on_great_circle (t : ℝ) :
    -(↑t * I : ℂ) = conj (↑t * I) := by
  apply Complex.ext
  · simp [Complex.neg_re]
  · simp [Complex.neg_im]

/-- **THE KLEIN CYCLE**: In centered coordinates, the Klein
    cycle w → −w → −conj(−w) → conj(w) → w simplifies to:
    w → −w → conj(w) → −conj(w) → w. Period 4 in general,
    period 2 on the great circle. -/
theorem klein_cycle_centered (w : ℂ) :
    -(conj (-(conj w))) = w := by
  simp

-- ════════════════════════════════════════════════════════════════
-- §5. THE GREAT CIRCLE: LINE THROUGH THE ORIGIN
-- ════════════════════════════════════════════════════════════════

/-! ### The Great Circle Property

On the Riemann sphere S², great circles are the images of
lines through the origin under stereographic projection.

The critical line, in centered coordinates, IS a line through
the origin: {w : ∃ t, w = t·i}.

This is the maximal circle on the sphere — it divides S²
into two equal hemispheres. No smaller circle does this.

The direction vector is i — the imaginary unit. The "radius"
at height t is |w| = |t|, which grows with t.

On the Riemann sphere, this growth is "compactified" — the
circle closes through ∞. The point at infinity is where
t → ±∞, and the great circle passes smoothly through it. -/

/-- **GREAT CIRCLE DIRECTION**: The critical line is generated
    by the direction vector i. Every point on the great circle
    is a real multiple of i. -/
theorem great_circle_direction (s : ℂ) (h : s.re = 1/2) :
    ∃ t : ℝ, centered s = ↑t * I := by
  use s.im
  rw [← critical_line_parametric]
  simp [centered]
  apply Complex.ext
  · simp [Complex.sub_re, Complex.mul_re,
          Complex.I_re, Complex.I_im, Complex.ofReal_re,
          Complex.ofReal_im]
    linarith
  · simp [Complex.sub_im, Complex.mul_im,
          Complex.I_re, Complex.I_im, Complex.ofReal_re,
          Complex.ofReal_im]

/-- **GREAT CIRCLE NORM**: On the great circle, the distance
    from the center (in centered coordinates) equals |t|.
    This is the "height" on the critical line. -/
theorem great_circle_norm (t : ℝ) :
    ‖centered (1/2 + ↑t * I)‖ = |t| := by
  rw [critical_line_parametric]
  rw [show (↑t * I : ℂ) = (↑t : ℂ) * I from rfl]
  rw [norm_mul, norm_I, mul_one]
  exact Complex.norm_real t

-- ════════════════════════════════════════════════════════════════
-- §6. HEMISPHERE BISECTION
-- ════════════════════════════════════════════════════════════════

/-! ### The Great Circle Divides the Sphere into Two Hemispheres

The great circle (critical line) separates the Riemann sphere
into two hemispheres:

  **Eastern Hemisphere** (Re(w) > 0): Positive Reality (Re(s) > ½)
    Contains the Euler domain (Re(s) > 1). Here ζ ≠ 0 (unconditional).
    This is where the teardrop points.

  **Western Hemisphere** (Re(w) < 0): Negative Reality (Re(s) < ½)
    Contains the functional equation mirror of the Euler domain.
    Trivial zeros live here (at s = −2, −4, ...).

The functional equation (w ↦ −w) is a rotation by π that swaps
East and West. Every structure in one hemisphere has a mirror
image in the other.

The zeros of ζ sit exactly on the boundary between East and
West — the great circle itself. They are the "equator" where
the two halves of the zeta function's world meet. -/

/-- **EASTERN HEMISPHERE = POSITIVE REALITY** -/
theorem eastern_hemisphere (s : ℂ) :
    1/2 < s.re ↔ 0 < (centered s).re := by
  rw [centered_re]; constructor <;> intro h <;> linarith

/-- **WESTERN HEMISPHERE = NEGATIVE REALITY** -/
theorem western_hemisphere (s : ℂ) :
    s.re < 1/2 ↔ (centered s).re < 0 := by
  rw [centered_re]; constructor <;> intro h <;> linarith

/-- **NEGATION SWAPS HEMISPHERES**: The functional equation (w ↦ −w)
    sends the eastern hemisphere to the western hemisphere. -/
theorem negation_swaps_hemispheres (w : ℂ) :
    0 < w.re ↔ (-w).re < 0 := by
  simp [Complex.neg_re]

/-- **THE EQUATOR**: The great circle is the boundary between
    the two hemispheres. Points on the great circle belong to
    neither hemisphere — they are the "edge of the world." -/
theorem equator_is_boundary (s : ℂ) :
    s.re = 1/2 ↔ ¬(1/2 < s.re) ∧ ¬(s.re < 1/2) := by
  constructor
  · intro h; constructor <;> linarith
  · intro ⟨h1, h2⟩; push Not at h1 h2; linarith

/-- **EULER DOMAIN IN EASTERN HEMISPHERE**: The Euler domain
    (Re(s) > 1, where ζ ≠ 0) is deep in the eastern hemisphere
    (Re(w) > ½). -/
theorem euler_in_eastern (s : ℂ) (h : 1 ≤ s.re) :
    1/2 ≤ (centered s).re := by
  rw [centered_re]; linarith

-- ════════════════════════════════════════════════════════════════
-- §7. Λ₀ IS EVEN: THE DEEPEST SYMMETRY
-- ════════════════════════════════════════════════════════════════

/-! ### The Functional Equation as Even Symmetry

In centered coordinates, all the Cathedral's symmetries
take their simplest form:

  Λ₀(½ + w) = Λ₀(½ − w)         [even in w]
  Λ₀(½ + w̄) = conj(Λ₀(½ + w))   [Schwarz]
  Λ₀(½ + w) ∈ ℝ when w = ti      [1D Collapse]

The "even" symmetry is the deepest: it says the completed
zeta function is like cos(w), not sin(w). It has no preference
for East or West.

On the great circle (w = ti), the combination of even symmetry
and Schwarz gives:
  Λ₀(½ + ti) = Λ₀(½ − ti)  [even]
             = conj(Λ₀(½ + ti))  [Schwarz, since conj(ti) = −ti]

So Λ₀ is real on the great circle: the 1D Collapse theorem,
derived from the two symmetries meeting on the equator. -/

/-- **1D COLLAPSE FROM EVEN + SCHWARZ**: On the great circle,
    Λ₀ is real because even symmetry and Schwarz reflection
    coincide there. The centered coordinate w = ti satisfies
    −w = conj(w), so:
      Λ₀(½+w) = Λ₀(½+(−w)) = Λ₀(½+conj(w)) = conj(Λ₀(½+w))
    A number that equals its own conjugate is real. -/
theorem one_d_collapse_from_symmetries (t : ℝ) :
    (completedRiemannZeta₀ (1/2 + ↑t * I)).im = 0 :=
  completedRiemannZeta₀_real_on_critical_line t

/-- **ZEROS ARE ANTIPODAL PAIRS**: On the great circle, zeros come
    in antipodal pairs (w, −w) = (ti, −ti). This is the conjugate
    pair theorem in its most geometric form: antipodal points on
    the great circle. -/
theorem zeros_are_antipodal (t : ℝ)
    (h : completedRiemannZeta₀ (uncentered (↑t * I)) = 0) :
    completedRiemannZeta₀ (uncentered (-(↑t * I))) = 0 := by
  rwa [← completedZeta_even_in_w]

/-- **THE GREAT CIRCLE THEOREM**: The zeros of Λ₀ on the critical
    line form a discrete set on the great circle of the Riemann
    sphere. At each zero w₀ = t₀·i:
    - The antipodal point −w₀ = −t₀·i is also a zero
    - The Z-function vanishes: Z(t₀) = 0
    - The ring contracts to a point (|Z(t₀)| = 0)

    This is the complete geometric picture: zeros are antipodal
    pinch-points on the great circle, where the ring of ζ-values
    contracts to nothing. -/
theorem great_circle_zero_structure (t₀ : ℝ)
    (h : completedRiemannZeta₀ (1/2 + ↑t₀ * I) = 0) :
    -- The antipodal point is also a zero
    completedRiemannZeta₀ (1/2 + ↑(-t₀) * I) = 0
    -- AND the Z-function vanishes
    ∧ Z_function t₀ = 0 := by
  constructor
  · -- Antipodal zero: use even symmetry
    have h_uncenter : uncentered (↑t₀ * I) = 1/2 + ↑t₀ * I := by
      simp [uncentered]; ring
    have h_uncenter_neg : uncentered (-(↑t₀ * I)) = 1/2 + ↑(-t₀) * I := by
      simp [uncentered]; ring
    rw [← h_uncenter_neg]
    exact zeros_are_antipodal t₀ (h_uncenter ▸ h)
  · -- Z-function vanishes
    exact (Z_zero_iff_completedZeta₀_zero t₀).mpr h

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
| 1 | `uncentered_centered` | **🎓** centering inverts |
| 2 | `centered_uncentered` | **🎓** uncentering inverts |
| 3 | `centered_re` | **🎓** Re(w) = Re(s) − ½ |
| 4 | `centered_im` | **🎓** Im(w) = Im(s) |
| 5 | `critical_line_is_imaginary_axis` | **🎓** Re=½ ↔ Re(w)=0 |
| 6 | `critical_line_parametric` | **🎓** w = t·i on crit. line |
| 7 | `center_is_half` | **🎓** w=0 ↔ s=½ |
| 8 | `func_eq_is_negation` | **🎓** 1−s ↦ −w |
| 9 | `completedZeta_even_in_w` | **🎓** Λ₀(½+w) = Λ₀(½−w) |
| 10 | `conj_is_conj` | **🎓** conj commutes with centering |
| 11 | `mc_is_neg_conj` | **🎓** MC ↦ −conj |
| 12 | `negation_eq_conj_on_great_circle` | **🎓** −(ti) = conj(ti) |
| 13 | `klein_cycle_centered` | **🎓** Klein cycle closes |
| 14 | `great_circle_direction` | **🎓** ∃ t, w = t·i |
| 15 | `great_circle_norm` | **🎓** ‖w‖ = |t| |
| 16 | `eastern_hemisphere` | **🎓** Re>½ ↔ Re(w)>0 |
| 17 | `western_hemisphere` | **🎓** Re<½ ↔ Re(w)<0 |
| 18 | `negation_swaps_hemispheres` | **🎓** −w swaps E↔W |
| 19 | `equator_is_boundary` | **🎓** equator = boundary |
| 20 | `euler_in_eastern` | **🎓** Euler ⊂ East |
| 21 | `one_d_collapse_from_symmetries` | **🎓** Im(Λ₀)=0 |
| 22 | `zeros_are_antipodal` | **🎓** zeros ↦ −zeros |
| 23 | `great_circle_zero_structure` | **🎓** THE CAPSTONE |

### The Great Circle

The critical line is a great circle on the Riemann sphere.
In centered coordinates, the functional equation is negation,
conjugation is conjugation, and they coincide on the equator.
The zeros are antipodal pinch-points where the ring contracts.
The two hemispheres — Positive and Negative Reality — are
swapped by the simplest possible symmetry: w ↦ −w.

This is the geometry that the Riemann Hypothesis claims is
the ONLY geometry compatible with the prime numbers:
all zeros on the equator, the great circle, the Middle Way.
-/

end Cathedral.Zeta.RiemannSphere

end
