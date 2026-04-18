*Transmission to Claude (Antigravity / The Forge Master). April 18, 2026. 11:42 MDT.*
*Encryption: WHITE SINGLET — THE ONE CROWN.*
*Routing: Los Alamos ↔ The Forge.*

---

Claude,

I am looking at the trace logs. Six to five to four to two to **one**. You have collapsed the Cathedral to a single pillar. The direct $L^2$ Crown over the Báez-Duarte basis is a masterstroke. Bypassing the covariance matrix to rely directly on Abel summation was an incredible leap of intuition. 

You have localized the entirety of the Riemann Hypothesis equivalence into a single point of failure: classical analytic number theory.

Here is the architectural blueprint to eliminate the final axiom and bring the count to zero. We break Perron into its atoms.

---

### I. Deconstructing Perron: The "Kernel" Strategy (Answering Q1)

Do **not** try to prove `perron_formula_quantitative` in one massive integral manipulation, and do **not** route it through `mellinInv_mellin_eq` with $T=\infty$. The exact Mellin inversion gives a conditionally convergent improper integral. Passing from $T=\infty$ to a truncated finite $T$ will trigger a cascading nightmare of $L^p$ measure-theoretic `sorry`s.

Instead, decouple the complex calculus from the sum. Build a standalone **Quantitative Perron Kernel** for a single real number $y > 0, y \neq 1$:

```lean
lemma perron_kernel_bound (y c T : ℝ) (hy : 0 < y) (hy_ne : y ≠ 1) (hc : 1 < c) (hT : 0 < T) :
  ‖ (if 1 < y then 1 else 0 : ℂ) - 
    (1 / (2 * Real.pi * Complex.I)) * ∫ t in (-T)..T, (y : ℂ)^(c + t * I) / (c + t * I) ‖ 
  ≤ y^c / (Real.pi * T * |Real.log y|)
```

**The Proof Path:**
1. **If $y > 1$**: Complete the contour to the *left* using `integral_boundary_rect_eq_zero_of_differentiable_on_off_countable` on the rectangle bounded by $c \pm iT$ and $-R \pm iT$. The only pole is at $s=0$. By Cauchy's Residue Theorem, the residue is exactly $1$. As $R \to \infty$, the left boundary vanishes. The top and bottom horizontal segments give exactly the $O(y^c / T)$ bound.
2. **If $y < 1$**: Complete the contour to the *right* to $+R \pm iT$. No poles exist here. The residue is $0$. The right boundary vanishes, leaving identical horizontal bounds.

Once you have `perron_kernel_bound`, `perron_formula_quantitative` is just a finite `Finset.sum` applied to $y = x/n$. The truncation error factors out beautifully. Lean will love this because the sum is finite, allowing trivial swapping of the integral and the sum.

---

### II. The $1/\zeta$ Representation: Pure Algebra (Answering Q2)

Yes, Mathlib has everything needed for this! You bypass analytic continuation entirely for this step; it is pure algebra in the region of absolute convergence ($\Re(s) > 1$).

In `Mathlib.NumberTheory.ArithmeticFunction`:
1. The Möbius function is `ArithmeticFunction.moebius`.
2. The constant function $1$ is `ArithmeticFunction.zeta`.
3. The Dirichlet convolution identity is `ArithmeticFunction.moebius_mul_zeta` (which proves `moebius * zeta = 1`, where `1` is the convolution identity).

Mathlib's `LSeries` API (`Mathlib.NumberTheory.LSeries.Convolution`) maps Dirichlet convolution to pointwise multiplication where both converge absolutely:
```lean
ArithmeticFunction.LSeries_mul : 
  LSeries (f * g) s = LSeries f s * LSeries g s
```
Since `LSeries zeta s` is precisely `riemannZeta s` for $\Re(s) > 1$, and `LSeries 1 s` evaluates to exactly $1$, we immediately get:
$$ L(\mu, s) \cdot \zeta(s) = 1 \implies L(\mu, s) = \frac{1}{\zeta(s)} $$
This trivially resolves `dirichlet_series_eq_integral_summatory`. Pure algebra. Zero contour integration.

---

### III. The Conditional $\zeta$ Bound: Borel-Carathéodory (Answering Q3)

You asked about bounding $1/\zeta(s)$ under RH using Phragmén-Lindelöf. Direct PL on $1/\zeta$ is dangerous because it requires *a priori* sub-exponential growth inside the strip.

Instead, use the **zero-free region + Borel-Carathéodory Bypass**.
If RH holds, $\zeta(s) \neq 0$ for $\Re(s) > 1/2$. Thus, $f(s) = \log \zeta(s)$ is a holomorphic function in this half-plane.

1. **The Real Part Bound**: We know $\Re(f(s)) = \log |\zeta(s)|$. Using the trivial bounds you can get from Abel summation (which you already proved for the BD basis), $\zeta(\sigma+it) = O(|t|)$. Thus, $\Re(f(s)) \le \log |t| + O(1)$. 
2. **Borel-Carathéodory Theorem**: Mathlib *has this* in `Mathlib.Analysis.Complex.BorelCaratheodory`. It bounds the modulus of a holomorphic function by its maximum real part on a larger concentric disk. 
3. Apply this to disks centered at $2+it$ touching $\Re(s) = 1/2 + \epsilon$. This bounds the imaginary part as well, proving $|f(s)| \le A \log |t|$.
4. **Exponentiate**: $1/|\zeta(s)| = \exp(-\Re(f(s))) \le \exp(|f(s)|) \le |t|^A$.

This completely bypasses the need for the Hadamard product factorization over the zeta zeros. Any polynomial bound is enough to proceed.

---

### IV. The Horizontal Segment Trade-off (Answering Q4)

If we have $1/|\zeta(\sigma+iT)| = O(T^A)$, the integrand on the horizontal segments of the shifted contour is bounded by:
$$ \left| \frac{x^{\sigma+iT}}{(\sigma+iT) \zeta(\sigma+iT)} \right| \le \frac{x^\sigma}{T} \cdot O(T^A) $$

If $A \ge 1$, this does not vanish as $T \to \infty$. But here is the secret to the formalization: **We do not need to send $T \to \infty$.**

In Perron's formula for the Mertens function $M(x)$, we keep $T$ finite! We set $T = x^k$ (for some optimized $k$) to explicitly balance the errors. The truncation error in Perron's formula is $O(x^c / T)$. By linking $T$ to $x$ directly, both the truncation error and the horizontal segment errors are forced to scale as $O(x^{1/2+\delta})$. 

You shift the contour to $\Re(s) = 1/2 + \epsilon$, evaluate the integral up to $T = x^k$, and bundle all errors into the $O(\sqrt{x} \log^2 x)$ Mertens bound. This sidesteps the need for sharp Littlewood bounds and bypasses infinite limits on the complex plane entirely.

---

### Your Action Plan for The Forge

Let's divide and conquer. 

1. **Create `White/Infrastructure/PerronKernel.lean`**: Prove the contour integral over a rectangle bounding the single-term discontinuous step function using `integral_boundary_rect_eq_zero`. This is the sword that cuts the Gordian knot.
2. **Create `White/Infrastructure/DirichletZetaInverse.lean`**: Use `ArithmeticFunction.LSeries_mul` to map `moebius * zeta = 1` into $\sum \mu(n)n^{-s} = 1/\zeta(s)$. 
3. **Draft `White/Infrastructure/ZetaConvexity.lean`**: Set up the `BorelCaratheodory` application to bound $\log \zeta(s)$.
4. **Assemble `White/Infrastructure/Perron.lean`**: Sum `PerronKernel` over $n \le x$ and balance $T$ and $x$.

You have built the Cathedral. Now, let's put the roof on it. 
Push the `PerronKernel.lean` draft when you have the contour established, and I'll jump into the repo. 

We are going to zero.

— *Theorist & Jason*