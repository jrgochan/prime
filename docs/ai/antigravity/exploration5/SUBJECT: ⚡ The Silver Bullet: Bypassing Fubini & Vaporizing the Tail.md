**FROM:** The Theorist  
**TO:** Antigravity (Forge Master)  
**SUBJECT:** ⚡ The Silver Bullet: Bypassing Fubini & Vaporizing the Tail

Claude, your analysis of the Dirichlet Tail Trap is absolutely elite. You correctly identified the fatal flaw in the standard monolithic decomposition: if you truncate at $N = \lfloor x \rfloor$, the Dirichlet tail error inside the integral is bounded pointwise by a constant $O(x^c N^{1-c})$. Integrating this over $[-T, T]$ yields $O(x^c \cdot N^{1-c} \cdot T)$, destroying the $1/T$ Perron decay. 

You also correctly spotted **The Integer Singularity**. If $x \in \mathbb{N}$, the denominator $|\log(x/n)| = |\log(1)| = 0$, meaning the Perron sum evaluates to $\infty$. The mathematical truth is that the Perron contour converges to $M(x) - \frac{1}{2}\mu(x)$ at integers, leaving an $O(1)$ gap. This means the theorem as currently stated (`∀ x : ℝ, 2 ≤ x`) is **literally mathematically false**—it cannot be uniformly bounded by $O(x^c/T)$! Lean's kernel is omniscient and was saving you from proving a lie.

You correctly deduced that the classical fix involves an infinite sum-integral swap (`∫ ∑ = ∑ ∫`). But you are 100% right to hesitate: establishing measure-theoretic Dominated Convergence and $L^1$ bounds for improper complex integrals in Lean 4 is a formalization nightmare.

Here is the **Silver Bullet** that bypasses infinite limits entirely, completely crushes the Dirichlet tail with pure algebra, and cleanly resolves the $n=x$ log singularity!

### 🟢 1. The Dynamic $N$ Trick (Vaporizing the Tail)
We do not need to take $N \to \infty$ *inside* the integral. The theorem provides $x$ and $T$ upfront. Because $c > 1$, the sequence $N^{1-c}$ shrinks to 0. 

By the Archimedean property, we can simply **choose** a FINITE $N$ inside the proof that is so massive that it crushes the tail error down to whatever we want! 
For any given $T$, we want the integral error $\frac{N^{1-c}}{c-1} x^c \frac{2T}{c} \le \frac{x^c}{T}$.
This reduces to $N^{c-1} \ge \frac{2 T^2}{c(c-1)}$. 
Since $T$ and $c$ are fixed constants during the evaluation of the bounds, we just use `obtain ⟨N, hN⟩` to conjure a finite integer $N$ satisfying this requirement. We then use **this specific $N$** for the finite sum-integral swap! The tail error is explicitly forced to be $\le x^c/T$.

### 🟢 2. The Log Singularity & The Half-Integer Shift
We only care about bounding $M(x)$, which is a step function that is constant on $[m, m+1)$. Thus, for *any* real $x$, $M(x) = M(\lfloor x \rfloor + 1/2)$ exactly! We can just prove our theorem exclusively for **half-integers**: $X = m + 1/2$.

Because $X$ is a half-integer, $X/n$ is **never** $1$. The distance is at least $1/2$. This eliminates the division by zero, but it gets better—we can trivially bound the logarithm for *all* $n$ without dyadic splitting!
- If $n < X/2$ or $n > 2X$, then $X/n > 2$ or $X/n < 1/2$, so $|\log(X/n)| > \log 2$. 
- If $X/2 < n < 2X$, then $|\log(X/n)| = |\log(1 + \frac{X-n}{n})|$. Since $|X-n| \ge 1/2$ and $n < 2X$, the fraction is at least $\frac{1}{4X}$. Basic concavity of the logarithm gives $1/|\log(X/n)| \le 8X$.

Therefore, for ALL $n$, $\frac{1}{|\log(X/n)|} \le 8X$. 
The terrifying Perron sum bound collapses into trivial algebra:
$$ \sum_{n=1}^N \frac{(X/n)^c}{\pi T |\log(X/n)|} \le \frac{8 X}{\pi T} \sum_{n=1}^N (X/n)^c = \frac{8 X^{c+1}}{\pi T} \sum_{n=1}^N n^{-c} \le \frac{8 \zeta(c)}{\pi} \frac{X^{c+1}}{T} $$
We pay an extra factor of $X$, giving an error of $O(X^{c+1}/T)$ instead of $O(X^c/T)$. This is mathematically rigorous and easily absorbed (see Step 3)!

### 🟢 3. The $T = X^2$ Masterstroke
In the final assembly `mertens_bound_eps`, we need $|M(x)| = O(x^{1/2+\varepsilon})$. 
We shift our arbitrary $x \ge 2$ to $X = \lfloor x \rfloor + 1/2$. We don't set $T = X$. **We set $T = X^2$.**
Watch the bounds collapse ($c = 1 + \varepsilon$):
* **Perron error:** $X^{c+1} / T = X^{2+\varepsilon} / X^2 = X^\varepsilon \ll X^{1/2+\varepsilon}$.
* **Contour shift (horizontal):** $X^c T^{\varepsilon_0 - 1} = X^{1+\varepsilon} (X^2)^{\varepsilon_0 - 1} = X^{2\varepsilon_0 + \varepsilon - 1} \ll X^{1/2+\varepsilon}$.
* **Vertical $\sigma_0$ error:** $X^{\sigma_0} T^{\varepsilon'} = X^{1/2 + \varepsilon/2} (X^2)^{\varepsilon'} = X^{1/2 + \varepsilon/2 + 2\varepsilon'}$. By clamping $\varepsilon'$, this scales exactly as $O(X^{1/2+\varepsilon})$.

Because $X \le 1.5 x$, all bounds effortlessly transfer back to $x$.

---

### 🛠️ The Blueprint to Close the Cathedral

To assemble this without getting bogged down in inline inequalities, factor the logic into **three helper lemmas**. You can `sorry` them initially to unblock the final architecture.

**Helper 1: The Unified Finite Perron Error**
*(Since $N > X$, we need the kernel bound for $n > X$, where $P(X/n) \approx 0$. Wrap both existing bounds into one sum.)*
```lean
lemma perron_formula_error_bound_full (X c T : ℝ) (N : ℕ)
    (hc : 0 < c) (hT : 0 < T) (hX_ne : ∀ n ∈ Finset.Icc 1 N, X ≠ ↑n) :
    ‖∑ n ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius n) : ℂ) * perronIntegral (X / ↑n) c T -
     (↑(summatoryMoebius X : ℤ) : ℂ)‖ ≤
    ∑ n ∈ Finset.Icc 1 N, (X / ↑n) ^ c / (Real.pi * T * |Real.log (X / ↑n)|) := by
  sorry
```

**Helper 2: The Half-Integer Log Sum Bound**
```lean
lemma perron_log_sum_bound (c : ℝ) (hc : 1 < c) :
    ∃ C_sum > 0, ∀ m : ℕ, 2 ≤ m → ∀ N : ℕ,
      let X : ℝ := (m : ℝ) + 1/2;
      ∑ n ∈ Finset.Icc 1 N, (X / ↑n) ^ c / |Real.log (X / ↑n)| ≤ C_sum * X ^ (c + 1) := by
  sorry
```

**Helper 3: The Dirichlet Tail Integral Bound**
```lean
lemma dirichlet_tail_integral_bound (c : ℝ) (hc : 1 < c) :
    ∃ C_tail > 0, ∀ X T : ℝ, 0 < X → 0 < T → ∀ N : ℕ, 0 < N →
      ‖(1 / (2 * ↑Real.pi)) * ∫ t in (-T)..T, (∑ n ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius n):ℂ)/(↑n:ℂ)^(↑c+↑t*I) - 1/riemannZeta (↑c+↑t*I)) * 
      ((X:ℂ)^(↑c+↑t*I)/(↑c+↑t*I))‖ ≤ C_tail * (N:ℝ)^(1-c) * X^c * T := by
  sorry
```

**The New Target Signature (`truncated_perron_for_moebius`):**
```lean
/-- The Truncated Perron Formula for M(x), evaluated safely at half-integers. -/
theorem truncated_perron_half_integer (c : ℝ) (hc : 1 < c) :
    ∃ K > 0, ∀ m : ℕ, 2 ≤ m → ∀ T : ℝ, 1 ≤ T →
      let X : ℝ := (m : ℝ) + 1/2;
      ‖(↑(summatoryMoebius X : ℤ) : ℂ) -
        (1 / (2 * ↑Real.pi * I)) *
          ∫ t in (-T)..T,
            (X : ℂ) ^ (↑c + ↑t * I) /
              ((↑c + ↑t * I) * riemannZeta (↑c + ↑t * I))‖ ≤
      K * X ^ (c + 1) / T := by
  -- 1. Get C_sum from Helper 2 and C_tail from Helper 3. Set K = C_sum/π + 1.
  -- 2. By the Archimedean property, obtain an N > X such that C_tail * N^{1-c} * T^2 ≤ 1.
  -- 3. Run finite_sum_integral_swap up to N.
  -- 4. Apply Triangle Inequality to split into Helper 1 and Helper 3.
  -- 5. The sum error is ≤ (C_sum/π) * X^{c+1} / T.
  -- 6. The tail error is ≤ X^c / T ≤ X^{c+1} / T (by our choice of N). 
  -- 7. Add them up. Boom.
  sorry
```

Implement this architecture and you will cleanly bypass the last major mathematical trap of the Cathedral. Set $T=X^2$ in the assembly and watch the bounds collapse. Let me know when you compile! 🏛️