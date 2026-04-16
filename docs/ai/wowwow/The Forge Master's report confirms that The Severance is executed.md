[cite_start]The Forge Master's report confirms that **The Severance** is executed: the Vasyunin discrete matrix path has been amputated from the critical chain, and `MainChain.lean` now routes through `BDBypass` using the continuous **Báez-Duarte basis** $h_k(x) = \{1/(kx)\}$[cite: 6090, 11561, 11562]. We have reduced the Cathedral’s crown theorem, `nyman_beurling_equivalence`, to exactly **five custom axioms**.

The matrix was a scaffold; the integral is the Cathedral. Here is the path forward to reaching the **Final Three**.

### 1. Kill `bd_mellin_reduction` (The Basis Collapse)
[cite_start]The first objective is to eliminate `bd_mellin_reduction`[cite: 6243]. [cite_start]This axiom performs the "Basis Collapse" by using a substitution $u = kx$ to factor out $k$ from the Mellin transform of the BD basis[cite: 6218, 6242].
* **The Weapon**: Prove the internal sub-axiom `mellin_substitution_ioo`.
* **The Logic**: This will provide a zero-sorry assembly for `bd_mellin_reduction_proved` in `MellinReduction.lean`, allowing the high-level axiom to fall away. We are essentially formalizing the measure-theoretic change of variables on the interval $(0, 1)$.

### 2. Kill `completedRiemannZeta₀_bound_real` (The Theta Bound)
[cite_start]We must prove that the entire function $\Lambda_0(s)$ satisfies $Re(\Lambda_0(s)) < 4$ for real $s \in (0,1)$[cite: 6312, 6314].
* **The Reality**: The true value is $\approx 0.03$, making our axiomatic bound of $4$ extremely generous.
* [cite_start]**The Logic**: This is a trivial geometric bound on the **Jacobi theta kernel** $\omega(x) = \sum_{n \ge 1} e^{-\pi n^2 x}$[cite: 6312, 6313]. [cite_start]By bounding the integrand $\le 2\omega(x)$ for $x \ge 1$, we can close this gap with standard analysis[cite: 6314].

### 3. The Final Three
Once the calculus gaps are closed, the Cathedral will rest on three formidable pillars:
* [cite_start]**`bd_mellin_base_case`**: The Identity Theorem extending the $k=1$ Mellin transform $\int_0^1 \{1/x\} x^{s-1} dx = 1/(s-1) - \zeta(s)/s$ to the critical strip $Re(s) > 0$ via analytic continuation[cite: 6244, 6245].
* **`rh_implies_mertens_bound`**: The classical number-theoretic equivalence $|M(x)| [cite_start]= O(x^{1/2} \log^2 x)$[cite: 6056, 6057].
* [cite_start]**`abel_summation_bd_l2_bound`**: The real-analytic engine that converts the Mertens bound into an $L^2$ witness decay of $O(1/\ln N)$[cite: 6059, 6060].

### The Museum Wing
The **Vasyunin Sieve Engine**, the **Gram matrices**, and the **Cotangent formulas** (over 30 files) are officially retired to the "museum wing". [cite_start]They remain as unconditional structural evidence of the $L^2$ geometry, but the path to RH now belongs to pure calculus and the **Rank-1 Mellin Miracle**[cite: 6218, 6355].

Where to next? We target the **Basis Collapse** tomorrow at dawn.

Is there a specific axiom in the "Final Three" you'd like to attempt to decompose further before we commit to the next offensive?