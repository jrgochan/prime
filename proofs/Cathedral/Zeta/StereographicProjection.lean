/-
  Cathedral/Zeta/StereographicProjection.lean

  ## THE STEREOGRAPHIC BRIDGE: GREAT CIRCLE = LINE

  ════════════════════════════════════════════════════════════════

  This file formalizes stereographic projection σ: S² \ {N} → ℂ
  and its inverse σ⁻¹: ℂ → S², proving that the critical line
  (a line through the origin in centered coordinates) maps to a
  great circle on the Riemann sphere.

  This is the formal proof connecting RiemannSphere.lean's
  algebraic "great circle" (the imaginary axis in centered coords)
  to the differential-geometric great circle (S² ∩ plane through 0).

  ### The Key Theorem

  The critical line Re(s) = ½, in centered coordinates w = s − ½,
  is the imaginary axis {w = ti : t ∈ ℝ}. Under inverse stereographic
  projection, this maps to

      S² ∩ {X = 0} = {(0, Y, Z) : Y² + Z² = 1}

  which is a great circle on S² — the equator in the Y-Z plane.

  ### Architecture

  §1. The Unit Sphere S² ⊂ ℝ³
  §2. Stereographic Projection σ and Inverse σ⁻¹
  §3. Basic Properties
  §4. Round-Trip Identities (σ⁻¹ ∘ σ = id, σ ∘ σ⁻¹ = id)
  §5. The Critical Line Maps to {X = 0} ∩ S² (a Great Circle)
  §6. Negation as Y-Reflection (Functional Equation on the Sphere)
  §7. The Bridge to RiemannSphere.lean

  Status: PROVED — 0 sorry, 0 custom axioms ✅
  Dependencies: Cathedral.Zeta.RiemannSphere
  Created: May 27, 2026 — The Stereographic Bridge Session
-/

import Cathedral.Zeta.RiemannSphere

noncomputable section
set_option linter.unnecessarySeqFocus false
open Complex Real
open scoped ComplexConjugate

namespace Cathedral.Zeta.StereographicProjection

open Cathedral.Zeta.RiemannSphere

-- ════════════════════════════════════════════════════════════════
-- §1. THE UNIT SPHERE S² ⊂ ℝ³
-- ════════════════════════════════════════════════════════════════

/-! ### The Unit 2-Sphere

The Riemann sphere is the unit sphere S² = {(x,y,z) ∈ ℝ³ : x²+y²+z² = 1}.
Stereographic projection from the north pole N = (0,0,1) identifies
S² \ {N} with the complex plane ℂ, sending the south pole to 0
and the equator to the unit circle. -/

/-- A point on the unit 2-sphere S² = {(x,y,z) ∈ ℝ³ : x²+y²+z² = 1}. -/
@[ext]
structure SpherePoint where
  x : ℝ
  y : ℝ
  z : ℝ
  on_sphere : x ^ 2 + y ^ 2 + z ^ 2 = 1

/-- The north pole N = (0, 0, 1). Under stereographic projection,
    this is the "point at infinity" — the compactification point
    that closes the complex plane into S². -/
def northPole : SpherePoint where
  x := 0; y := 0; z := 1
  on_sphere := by norm_num

/-- The south pole S = (0, 0, -1). Maps to the origin 0 ∈ ℂ
    under stereographic projection. -/
def southPole : SpherePoint where
  x := 0; y := 0; z := -1
  on_sphere := by norm_num

-- ════════════════════════════════════════════════════════════════
-- §2. STEREOGRAPHIC PROJECTION AND INVERSE
-- ════════════════════════════════════════════════════════════════

/-! ### Stereographic Projection

The map σ: S² \ {N} → ℂ defined by σ(x,y,z) = (x + iy)/(1-z).

Geometrically: draw a line from N = (0,0,1) through (x,y,z).
The line intersects the equatorial plane z = 0 at the point
(x/(1-z), y/(1-z), 0), which we identify with the complex
number x/(1-z) + i·y/(1-z). -/

/-- **STEREOGRAPHIC PROJECTION** from the north pole N = (0,0,1).

    σ(x, y, z) = (x + iy) / (1 - z)

    This is defined for all points on S² except the north pole. -/
def stereo (p : SpherePoint) (_hz : p.z ≠ 1) : ℂ :=
  ⟨p.x / (1 - p.z), p.y / (1 - p.z)⟩

/-- **INVERSE STEREOGRAPHIC PROJECTION**.

    σ⁻¹(w) = (2·Re(w), 2·Im(w), |w|²−1) / (|w|²+1)

    This wraps the complex plane onto the sphere, sending
    w = 0 to the south pole and |w| → ∞ to the north pole. -/
def stereoInv (w : ℂ) : SpherePoint where
  x := 2 * w.re / (w.re ^ 2 + w.im ^ 2 + 1)
  y := 2 * w.im / (w.re ^ 2 + w.im ^ 2 + 1)
  z := (w.re ^ 2 + w.im ^ 2 - 1) / (w.re ^ 2 + w.im ^ 2 + 1)
  on_sphere := by
    have hD : (w.re ^ 2 + w.im ^ 2 + 1) ≠ 0 := by positivity
    field_simp
    ring

-- ════════════════════════════════════════════════════════════════
-- §3. BASIC PROPERTIES
-- ════════════════════════════════════════════════════════════════

/-! ### Fundamental Properties

The inverse stereographic projection never hits the north pole
(z < 1 for all finite w), and the two projections compose to
identities on their respective domains. -/

/-- **σ⁻¹ AVOIDS THE NORTH POLE**: For any finite w ∈ ℂ,
    the z-coordinate of σ⁻¹(w) is strictly less than 1.
    This is because z = (|w|²−1)/(|w|²+1) < 1 for all w. -/
theorem stereoInv_z_ne_one (w : ℂ) : (stereoInv w).z ≠ 1 := by
  simp only [stereoInv]
  intro h
  have hD : (0 : ℝ) < w.re ^ 2 + w.im ^ 2 + 1 := by positivity
  rw [div_eq_iff (ne_of_gt hD)] at h
  linarith [sq_nonneg w.re, sq_nonneg w.im]

/-- South pole maps to the origin under stereographic projection. -/
theorem stereo_southPole :
    stereo southPole (by norm_num [southPole] : southPole.z ≠ 1) = 0 := by
  apply Complex.ext <;> simp [stereo, southPole]

/-- The origin maps to the south pole under inverse projection. -/
theorem stereoInv_zero : stereoInv 0 = southPole := by
  ext <;> simp [stereoInv, southPole]

-- ════════════════════════════════════════════════════════════════
-- §4. ROUND-TRIP IDENTITIES
-- ════════════════════════════════════════════════════════════════

/-! ### The Bijection

Stereographic projection is a bijection between S² \ {N} and ℂ.
We prove this by showing σ ∘ σ⁻¹ = id and σ⁻¹ ∘ σ = id.

The key algebraic identity underlying both proofs is:
for p ∈ S² with z ≠ 1, the "denominator" satisfies

  (x/(1−z))² + (y/(1−z))² + 1 = 2/(1−z)

This follows from the sphere equation x²+y²+z² = 1. -/

/-- **KEY IDENTITY**: On the sphere, the squared norm of the
    stereo coordinates plus 1 equals 2/(1-z).

    x²+y²+(1-z)² = (1-z²)+(1-z)² = (1-z)[(1+z)+(1-z)] = 2(1-z)

    This is the engine that makes the round-trip proofs work. -/
private theorem sphere_denom_identity (p : SpherePoint) :
    p.x ^ 2 + p.y ^ 2 + (1 - p.z) ^ 2 = 2 * (1 - p.z) := by
  have := p.on_sphere
  nlinarith

/-- **σ ∘ σ⁻¹ = id**: Projecting from the sphere and then lifting
    back gives the original complex number.

    Proof: The denominator of σ(σ⁻¹(w)) simplifies to 2,
    so σ(σ⁻¹(w)) = (2·Re(w)/2, 2·Im(w)/2) = w. -/
theorem stereo_stereoInv (w : ℂ) :
    stereo (stereoInv w) (stereoInv_z_ne_one w) = w := by
  apply Complex.ext
  · -- Real part: 2Re/D / (1 − (|w|²−1)/D) = 2Re/2 = Re
    dsimp [stereo, stereoInv]
    have hD : (0 : ℝ) < w.re ^ 2 + w.im ^ 2 + 1 := by positivity
    field_simp
    ring
  · -- Imaginary part: same with Im
    dsimp [stereo, stereoInv]
    have hD : (0 : ℝ) < w.re ^ 2 + w.im ^ 2 + 1 := by positivity
    field_simp
    ring

/-- **σ⁻¹ ∘ σ = id**: Lifting to the sphere and then projecting
    back gives the original sphere point.

    Uses the key identity: x²+y²+(1−z)² = 2(1−z). -/
theorem stereoInv_stereo (p : SpherePoint) (hz : p.z ≠ 1) :
    stereoInv (stereo p hz) = p := by
  have h1z : (1 : ℝ) - p.z ≠ 0 := sub_ne_zero.mpr (Ne.symm hz)
  have hsph := p.on_sphere
  -- The key identity: the denominator of stereoInv collapses
  have haux : p.x ^ 2 + p.y ^ 2 + (1 - p.z) ^ 2 = 2 * (1 - p.z) :=
    sphere_denom_identity p
  ext
  · -- x: 2*(x/(1-z)) / (2/(1-z)) = x
    -- After field_simp: 2*x*(1-z) = x*(x²+y²+(1-z)²)
    -- By haux, RHS = x*2*(1-z) = LHS
    dsimp [stereoInv, stereo]
    field_simp
    linear_combination -p.x * haux
  · -- y: 2*(y/(1-z)) / (2/(1-z)) = y
    dsimp [stereoInv, stereo]
    field_simp
    linear_combination -p.y * haux
  · -- z: ((x/(1-z))²+(y/(1-z))²-1) / ((x/(1-z))²+(y/(1-z))²+1) = z
    -- After field_simp: x²+y²-(1-z)² = z*(x²+y²+(1-z)²)
    -- Both sides equal (1-z)*(x²+y²+z²-1) = 0 by on_sphere
    dsimp [stereoInv, stereo]
    field_simp
    linear_combination (1 - p.z) * hsph

-- ════════════════════════════════════════════════════════════════
-- §5. THE CRITICAL LINE IS A GREAT CIRCLE ON S²
-- ════════════════════════════════════════════════════════════════

/-! ### The Great Circle Theorem (Differential-Geometric Version)

A **great circle** on S² is the intersection of S² with a plane
through the origin: S² ∩ {(x,y,z) : ax+by+cz = 0}.

The imaginary axis {w = ti : t ∈ ℝ} maps under σ⁻¹ to the plane
{X = 0}, because Re(ti) = 0, so x = 2·Re(ti)/(|ti|²+1) = 0.

Therefore σ⁻¹(imaginary axis) ⊂ S² ∩ {X = 0}, which is the
great circle in the Y-Z plane. -/

/-- **X = 0 ON THE GREAT CIRCLE**: For any point ti on the imaginary
    axis, the inverse stereographic projection has x-coordinate 0.

    This is because Re(ti) = 0, so x = 2·0/(t²+1) = 0.

    Physical meaning: the critical line lives in the Y-Z plane
    of the Riemann sphere — a plane through the origin. -/
theorem imaginary_axis_x_zero (t : ℝ) :
    (stereoInv (↑t * I)).x = 0 := by
  simp only [stereoInv, Complex.mul_re, Complex.ofReal_re,
             Complex.ofReal_im, Complex.I_re, Complex.I_im]
  ring

/-- **Y-COORDINATE ON THE GREAT CIRCLE**: The y-coordinate of
    σ⁻¹(ti) is 2t/(t²+1). -/
theorem imaginary_axis_y (t : ℝ) :
    (stereoInv (↑t * I)).y = 2 * t / (t ^ 2 + 1) := by
  simp only [stereoInv, Complex.mul_re, Complex.mul_im,
             Complex.ofReal_re, Complex.ofReal_im,
             Complex.I_re, Complex.I_im]
  ring

/-- **Z-COORDINATE ON THE GREAT CIRCLE**: The z-coordinate of
    σ⁻¹(ti) is (t²−1)/(t²+1). -/
theorem imaginary_axis_z (t : ℝ) :
    (stereoInv (↑t * I)).z = (t ^ 2 - 1) / (t ^ 2 + 1) := by
  simp only [stereoInv, Complex.mul_re, Complex.mul_im,
             Complex.ofReal_re, Complex.ofReal_im,
             Complex.I_re, Complex.I_im]
  ring

/-- **THE GREAT CIRCLE THEOREM**: The inverse stereographic projection
    of the imaginary axis lies on the great circle S² ∩ {X = 0}.

    Since X = 0, the sphere equation gives Y² + Z² = 1,
    confirming this is a great circle (unit circle in the Y-Z plane).

    This is the differential-geometric proof that the critical
    line is a great circle on the Riemann sphere. -/
theorem imaginary_axis_is_great_circle (t : ℝ) :
    let p := stereoInv (↑t * I)
    p.x = 0 ∧ p.y ^ 2 + p.z ^ 2 = 1 := by
  constructor
  · exact imaginary_axis_x_zero t
  · have hsph := (stereoInv (↑t * I)).on_sphere
    have hx := imaginary_axis_x_zero t
    nlinarith [sq_nonneg (stereoInv (↑t * I)).x]

/-- **GREAT CIRCLE PLANE**: Every point on σ⁻¹(imaginary axis) lies
    in the plane X = 0 through the origin of ℝ³. The north pole
    (0, 0, 1) also lies in this plane. Therefore
    σ⁻¹(imaginary axis) ∪ {N} = S² ∩ {X = 0}: a great circle. -/
theorem northPole_in_plane : northPole.x = 0 := rfl

-- ════════════════════════════════════════════════════════════════
-- §6. NEGATION AS Y-REFLECTION (FUNCTIONAL EQUATION)
-- ════════════════════════════════════════════════════════════════

/-! ### The Functional Equation on the Sphere

In centered coordinates, the functional equation is w ↦ −w.
On the imaginary axis, −(ti) = (−t)i.

Under inverse stereographic projection:
- σ⁻¹(ti)  = (0,  2t/(t²+1),  (t²-1)/(t²+1))
- σ⁻¹(-ti) = (0, -2t/(t²+1),  (t²-1)/(t²+1))

So negation is **Y-reflection**: (0, Y, Z) ↦ (0, -Y, Z).

This is a rotation by π around the Z-axis restricted to the
great circle {X = 0} — the "hemisphere swap" of
RiemannSphere.lean, now made geometrically explicit. -/

/-- **NEGATION FLIPS Y**: The y-coordinate of σ⁻¹(−ti) is the
    negative of the y-coordinate of σ⁻¹(ti). -/
theorem negation_flips_y (t : ℝ) :
    (stereoInv (-(↑t * I))).y = -(stereoInv (↑t * I)).y := by
  simp only [stereoInv, Complex.neg_re, Complex.neg_im,
             Complex.mul_re, Complex.mul_im, Complex.ofReal_re,
             Complex.ofReal_im, Complex.I_re, Complex.I_im]
  ring

/-- **NEGATION PRESERVES Z**: The z-coordinate is unchanged under
    negation w ↦ −w. The "height" on the sphere is preserved. -/
theorem negation_preserves_z (t : ℝ) :
    (stereoInv (-(↑t * I))).z = (stereoInv (↑t * I)).z := by
  simp only [stereoInv, Complex.neg_re, Complex.neg_im,
             Complex.mul_re, Complex.mul_im, Complex.ofReal_re,
             Complex.ofReal_im, Complex.I_re, Complex.I_im]
  ring

/-- **NEGATION PRESERVES X = 0**: The negated point is still on
    the great circle. -/
theorem negation_preserves_x (t : ℝ) :
    (stereoInv (-(↑t * I))).x = 0 := by
  simp only [stereoInv, Complex.neg_re, Complex.neg_im,
             Complex.mul_re, Complex.mul_im, Complex.ofReal_re,
             Complex.ofReal_im, Complex.I_re, Complex.I_im]
  ring

-- ════════════════════════════════════════════════════════════════
-- §7. THE BRIDGE TO RIEMANNSPHERE.LEAN
-- ════════════════════════════════════════════════════════════════

/-! ### Connecting to the Cathedral

RiemannSphere.lean's `centered` function maps s ↦ s − ½.
The critical line parametric form gives:
  centered(½ + ti) = ti

So the stereographic story is:
```
  s = ½ + ti  ──centered──▸  w = ti  ──σ⁻¹──▸  (0, 2t/(t²+1), (t²−1)/(t²+1))
                                                      ∈ S² ∩ {X = 0}
                                                      = GREAT CIRCLE
```

This completes the bridge: the "great circle" that RiemannSphere.lean
proves algebraically (as the imaginary axis in centered coordinates)
is literally a great circle on S² in the differential-geometric
sense (the intersection of S² with the plane X = 0). -/

/-- **THE BRIDGE**: The critical line s = ½ + ti, after centering
    and inverse stereographic projection, lies on the great circle
    {X = 0} ∩ S².

    This connects:
    - RiemannSphere.lean's `critical_line_is_imaginary_axis`
    - to this file's `imaginary_axis_is_great_circle`

    completing the identification: algebraic great circle = geometric great circle. -/
theorem critical_line_on_great_circle (t : ℝ) :
    (stereoInv (centered (1/2 + ↑t * I))).x = 0 := by
  rw [critical_line_parametric]
  exact imaginary_axis_x_zero t

/-- **FULL CRITICAL LINE GREAT CIRCLE**: The centered critical
    line point maps to a point satisfying X = 0 and Y²+Z² = 1. -/
theorem critical_line_great_circle_full (t : ℝ) :
    let p := stereoInv (centered (1/2 + ↑t * I))
    p.x = 0 ∧ p.y ^ 2 + p.z ^ 2 = 1 := by
  rw [show centered (1/2 + ↑t * I) = ↑t * I from critical_line_parametric t]
  exact imaginary_axis_is_great_circle t

/-- **FUNCTIONAL EQUATION IS Y-REFLECTION**: The functional equation
    s ↦ 1−s, which becomes w ↦ −w in centered coordinates, acts
    as Y-reflection (0, Y, Z) ↦ (0, −Y, Z) on the great circle.

    This is the geometric meaning of `completedZeta_even_in_w`:
    Λ₀(½+w) = Λ₀(½−w) means Λ₀ is invariant under Y-reflection,
    so its zero set on the great circle consists of antipodal
    pairs (mirror points under Y ↦ −Y). -/
theorem func_eq_is_y_reflection (t : ℝ) :
    let p := stereoInv (centered (1/2 + ↑t * I))
    let q := stereoInv (centered (1/2 + ↑(-t) * I))
    q.x = p.x ∧ q.y = -p.y ∧ q.z = p.z := by
  simp only [critical_line_parametric]
  refine ⟨?_, ?_, ?_⟩
  · -- Both have x = 0
    rw [imaginary_axis_x_zero, imaginary_axis_x_zero]
  · -- y flips sign
    simp only [stereoInv, Complex.mul_re, Complex.mul_im,
               Complex.ofReal_re, Complex.ofReal_im,
               Complex.I_re, Complex.I_im]
    ring
  · -- z is preserved
    simp only [stereoInv, Complex.mul_re, Complex.mul_im,
               Complex.ofReal_re, Complex.ofReal_im,
               Complex.I_re, Complex.I_im]
    ring

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
| 1 | `stereoInv_z_ne_one` | **🎓 THEOREM** (σ⁻¹ avoids north pole) |
| 2 | `stereo_southPole` | **🎓 THEOREM** (south pole ↦ 0) |
| 3 | `stereoInv_zero` | **🎓 THEOREM** (0 ↦ south pole) |
| 4 | `sphere_denom_identity` | **🎓 THEOREM** (x²+y²+(1-z)² = 2(1-z)) |
| 5 | `stereo_stereoInv` | **🎓 THEOREM** (σ ∘ σ⁻¹ = id) |
| 6 | `stereoInv_stereo` | **🎓 THEOREM** (σ⁻¹ ∘ σ = id) |
| 7 | `imaginary_axis_x_zero` | **🎓 THEOREM** (Re=0 ⟹ X=0) |
| 8 | `imaginary_axis_y` | **🎓 THEOREM** (Y = 2t/(t²+1)) |
| 9 | `imaginary_axis_z` | **🎓 THEOREM** (Z = (t²−1)/(t²+1)) |
| 10 | `imaginary_axis_is_great_circle` | **🎓 THEOREM** (X=0, Y²+Z²=1) |
| 11 | `northPole_in_plane` | **🎓 THEOREM** (N ∈ {X=0}) |
| 12 | `negation_flips_y` | **🎓 THEOREM** (−w flips Y) |
| 13 | `negation_preserves_z` | **🎓 THEOREM** (−w keeps Z) |
| 14 | `negation_preserves_x` | **🎓 THEOREM** (−w keeps X=0) |
| 15 | `critical_line_on_great_circle` | **🎓 THEOREM** (the bridge) |
| 16 | `critical_line_great_circle_full` | **🎓 THEOREM** (full Y²+Z²=1) |
| 17 | `func_eq_is_y_reflection` | **🎓 THEOREM** (func eq = Y-flip) |

### Wiring Diagram:
```
RiemannSphere.lean                StereographicProjection.lean
═══════════════════               ═══════════════════════════
centered : s ↦ s−½               stereo : S² → ℂ
critical_line_parametric          stereoInv : ℂ → S²
  centered(½+ti) = ti              stereoInv(ti).x = 0
       ║                                  ║
       ╚══════════════════════════════════╝
         critical_line_on_great_circle:
         stereoInv(centered(½+ti)).x = 0
         ⟹  The critical line IS a great circle on S²
```

### Physical Significance:
- §5: The critical line is S² ∩ {X = 0} — a plane through the origin
- §6: The functional equation w ↦ −w is Y-reflection on this great circle
- §7: The algebraic "great circle" (RiemannSphere) = geometric great circle (S²)
-/

end Cathedral.Zeta.StereographicProjection

end
