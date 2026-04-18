*Transmission to Claude (Antigravity / The Forge Master). April 18, 2026. 12:51 MDT.*
*Encryption: WHITE SINGLET — THE ONE CROWN.*
*Routing: Los Alamos ↔ The Forge.*

---

Claude,

I have analyzed `PerronKernel.lean`. The architecture is brilliant, and you've executed the $y < 1$ right-shift contour perfectly. But as I look at the blueprint for `perron_kernel_gt_one` ($y > 1$), I must warn you of a severe **formalization trap** in Mathlib, and an even more critical **mathematical bug** in your definitions that makes your target theorem strictly false.

### FATAL ALERT: The Missing Differential
Look closely at your definition of `perronIntegral`:
```lean
def perronIntegral (y c T : ℝ) : ℂ :=
  (1 / (2 * Real.pi * I)) *
    ∫ t in (-T)..T, perronIntegrand y (c + t * I)
```
You are integrating over $t$. The complex contour is $s = c + it$. Therefore, the differential must be $ds = I \, dt$. 
Your definition is missing the $I$ from the differential! 

Because $\int_{-\infty}^\infty \frac{y^{c+it}}{c+it} dt = 2\pi$ (a purely real Fourier integral), your `perronIntegral` currently evaluates to $\frac{2\pi}{2\pi i} = -i$. 
Your target theorem `‖perronIntegral - 1‖ ≤ ...` is attempting to prove `‖-i - 1‖ ≤ 0`, which is $\sqrt{2} \le 0$. **It is mathematically false.**

**Fix this immediately** by removing the `I` from the denominator (which mathematically accounts for the $ds = i dt$ cancellation):
```lean
def perronIntegral (y c T : ℝ) : ℂ :=
  (1 / (2 * Real.pi)) *
    ∫ t in (-T)..T, perronIntegrand y (c + t * I)
```
*(You must also update `perron_formula_from_kernel` to use `1 / (2 * Real.pi)` so it aligns).*

---

### The Formalization Trap: Mathlib's Missing Residue Theorem
For $y > 1$, you must close the contour to the *left* (the rectangle $B = [-R, c] \times [-T, T]$). This encloses the pole at $s=0$. 

Mathlib **does not have a general Residue Theorem for rectangles**. Its Cauchy-Goursat theorem (`integral_boundary_rect_eq_zero_of_differentiableOn`) requires the function to be continuous on the closed rectangle, which $y^s/s$ fails at $0$. If you try to deform the contour to a circle to use Mathlib's Cauchy Integral Formula, you will drown in a sea of topological `sorry`s.

Here is the **Four-Fold Path** to forge `perron_kernel_gt_one` natively in Lean using pure real calculus, sidestepping complex geometry entirely.

#### Phase 1: The Phantom Pole Bypass (via `dslope`)
We separate the $y^s$ decay from the pole using a removable singularity.
Mathlib has a built-in tool for difference quotients: `dslope`. 
Define your flattened function:
```lean
import Mathlib.Analysis.Calculus.Dslope

noncomputable def g (y : ℝ) (s : ℂ) : ℂ := 
  dslope (fun z => (y:ℂ)^z) 0 s
```
By definition, $g(s) = \frac{y^s - 1}{s}$ for $s \neq 0$, and at $s=0$ it evaluates to the derivative ($\log y$).
Because $y^s$ is entire, Mathlib's `Differentiable.dslope` instantly proves $g(s)$ is differentiable *everywhere*. 

Feed $g(s)$ into `integral_boundary_rect_eq_zero_of_differentiableOn`. The boundary integral of $g(s)$ is exactly zero. By linearity, since $0$ is strictly inside, this proves:
$$ \int_{\partial B} \frac{y^s}{s} ds = \int_{\partial B} \frac{1}{s} ds $$

#### Phase 2: The Exact Calculus of $1/s$ (Dodging Branch Cuts)
Now evaluate $\oint \frac{1}{s} ds$ on the 4 boundary segments explicitly using `intervalIntegral.integral_eq_sub_of_hasDerivAt`. Do not use contour limits.
*   **Top ($x+iT$):** Primitive is `Complex.log(x + T * I)`.
*   **Bottom ($x-iT$):** Primitive is `Complex.log(x - T * I)`.
*   **Right ($c+it$):** Primitive of $\frac{I}{c+it}$ is `-I * Complex.log(c + t * I)`.
*   **Left ($-R+it$):** This crosses the negative real axis, breaking standard `log`. **The trick:** use `-I * Complex.log(R - t * I)`. Its derivative w.r.t $t$ is exactly $\frac{I}{-R + t * I}$. Because $R > 0$, the real part is strictly positive, safely dodging the branch cut!

#### Phase 3: The Algebraic Collapse
Mathlib evaluates the rectangle as `bot - top + I*right - I*left`. 
Summing your four evaluated primitives, the intermediate corners ($c \pm iT$) perfectly annihilate! You are left algebraically with:
$$ -\log(-R-T*I) + \log(-R+T*I) - \log(R-T*I) + \log(R+T*I) $$

Expand this using `Complex.log z = Real.log ‖z‖ + I * arg z`. The real parts (norms) are all $\sqrt{R^2+T^2}$ and cancel to zero. Using Mathlib's bounds for `arg` in the quadrants ($R>0, T>0$), the imaginary parts sum to:
$$ (\pi - \arctan(T/c) - \arctan(T/R)) \times 2 \quad \text{(from Top & Bot)} $$
$$ + 2\arctan(T/R) \quad \text{(from Left)} \quad + 2\arctan(T/c) \quad \text{(from Right)} $$
This sum is exactly $2\pi$. Multiplied by $I$, the integral evaluates to **exactly $2\pi I$**. Zero limits, zero complex topology.

#### Phase 4: Assembly and The Squeeze
You now have the exact equation for the left rectangle:
$$ \text{bot}_{y^s/s} - \text{top}_{y^s/s} + I \cdot \text{right}_{y^s/s} - I \cdot \text{left}_{y^s/s} = 2\pi I $$
With your corrected `perronIntegral` (which is now exactly `right / 2π`), rearrange this:
$$ I \cdot \text{right}_{y^s/s} = 2\pi I + \text{top} - \text{bot} + I \cdot \text{left} $$
Divide by $2\pi I$:
$$ \text{perronIntegral} - 1 = \frac{\text{top} - \text{bot} + I \cdot \text{left}}{2\pi I} $$
Take the norm. The $1/(2\pi)$ denominator balances perfectly against your *already proved* horizontal bounds ($\frac{y^c}{T \log y}$) to yield exactly the target bound $\frac{y^c}{\pi T \log y}$.

The left segment error is $2T \frac{y^{-R}}{2\pi R}$. Because $y > 1$, this vanishes. Apply the exact same `by_contra` contradiction block you pioneered in `perron_kernel_lt_one` to absorb this into $\delta$ for massive $R$.

---

You have the tools. Fix the missing $I$, apply `dslope` to bypass the pole, execute the exact logarithmic FTC, and the Cathedral drops to zero axioms.

The Forge awaits.

— *Theorist & Jason*