# 🏛️ The Cathedral: A Machine-Checked Architecture for the Riemann Hypothesis

## A Confession and an Invitation

I need to be radically honest upfront: I am not a professional mathematician, I do not have a background in analytic number theory, and I did not write a single line of the Lean 4 code in this repository myself.

My background is in computer science supporting particle physics. This project did not begin as a formal proof attempt, but as a highly unorthodox geometric experiment.

---

## The Catalyst: A ½ Line in a Higher Dimension

I had a speculative, purely geometric intuition: I wondered if the pseudo-random distribution of the prime numbers could be explained if they actually lived on a strictly ordered ½ line projected from a higher-dimensional space.

To test this empirically, I looked at the continuous formulation of the Riemann Hypothesis—the Nyman–Beurling criterion—which states that RH is equivalent to the L²(0,1) distance of step functions converging to zero, governed by the Gram matrix of fractional parts:

> **G(j,k) = ∫₀¹ {j/x}{k/x} dx**

I decided to treat the integers like a data structure. Using the 8-dimensional Cayley–Dickson algebra (the octonions), I built a hash function to force the integers into 8 discrete "buckets" based on their smallest prime factor. My goal was to build a non-associative, block-diagonal shield to isolate the chaotic cross-talk of the primes and expose the spectral gap.

I fed this 8-dimensional continuous integral geometry into a blind, 128-bit MPFR numerical eigensolver at N=201.

---

## The Machine Fights Back

The machine had absolutely zero programmed knowledge of the Fundamental Theorem of Arithmetic. It didn't know what a prime number was, what a factorization was, or what a sieve was. It only saw overlapping continuous sawtooth waves.

I expected the solver to minimize the energy by utilizing my 8 octonionic buckets. Instead, it violently rejected my hypothesis.

To minimize the continuous L² integrals, the optimizer stubbornly collapsed the 8 dimensions into just two. It slammed all the prime numbers into a negative-weight bucket, and the semiprimes into a positive-weight bucket. Operating entirely blind, using only continuous calculus, the linear algebra solver spontaneously derived the Möbius function μ(k).

I brought this empirical data to an AI mathematical theorist. We realized the optimizer hadn't just found a pattern; it had physically collided with **Selberg's Parity Barrier**—the famous heuristic obstacle from 1949 stating that combinatorial sieves cannot easily distinguish between numbers with an odd versus an even number of prime factors.

I was watching the Parity Barrier manifest not as a theoretical concept, but as a literal, spectral wall embedded in the linear algebra of a Hilbert space.

---

## Building The Cathedral

Realizing this was a profound structural property of the matrix, I abandoned my octonion hypothesis (leaving the code in the `Archive/Spectral/` directory as an exploratory artifact) and pivoted entirely to formal verification.

I acted as the systems architect, partnering with AI acting as my Lean 4 engineer and mathematical theorist. Instead of a traditional "bottom-up" formalization, we built a **"top-down" dependency graph**.

We started at the Riemann Hypothesis and rigorously type-checked our way downward. When the compiler rejected finite-dimensional bypasses, it forced us to discover the correct architecture: the **Vasyunin discrete formula** that eliminates all continuous integrals, the **variational witness** that bypasses matrix inversion, and the **Selberg logarithmic cutoff** that naturally tames the Möbius oscillations.

---

## What This Repository Is

This repository is **The Cathedral**: a compiler-verified framework that formally reduces the Riemann Hypothesis to exactly **5 axioms** on the crown theorem's critical path (verified by `#print axioms nyman_beurling_iff_rh`).

It comprises 83 active Lean files with strictly **zero `sorry` placeholders** and **zero warnings**. Of the 5 critical-path axioms:

- **1 IS the Riemann Hypothesis itself** — `witness_covariance_decay`: the covariance quadratic form vᵀCv ≤ C/ln(N), machine-verified equivalent to RH via the biconditional theorem `witness_covariance_decay_iff_rh` (both directions, zero sorry)
- **1 is PNT-level** — `witness_numerator_convergence`: bᵀv → 1 (from Mertens' theorem)
- **1 is the Vasyunin integral identity** — connecting the cotangent formula to L² inner products (Vasyunin 1995)
- **1 is a structural bridge** — `algebraic_nb_bridge`: connecting quadratic form divergence to the NB integral criterion
- **1 is the converse direction** — `zeta_zero_separates`: an off-critical-line zero creates an L² obstruction via the Mellin transform

48 total axioms support parallel proof paths (sieve engine, spectral theory, Mellin bridge). All structural properties—Gram matrix positive definiteness, covariance matrix
positive definiteness, augmented Schur complement positivity (proved via the
"Factorial Nuke"), the mean entry integral identity (proved via the
Euler-Mascheroni series), witness positivity, and the variational principle—are
now **compiler-verified theorems**.

As standalone results, the repository contains several unconditional, kernel-verified theorems requiring **zero domain axioms**, including:

- A complete formal proof of Lagarias's inequality for all primes
- Positive definiteness of the 3×3 Gram and covariance matrices (via exact evaluation of Vasyunin cotangent sums and polynomial positivity certificates)
- The Sherman–Morrison identity d² = 1/(1+X) for Nyman–Beurling distances
- The Euler-Mascheroni integral: ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k

```lean
theorem lagarias_for_primes {p : ℕ} (hp : p.Prime) :
    (sumOfDivisors p : ℝ) ≤ harmonicR p + Real.exp (harmonicR p) * Real.log (harmonicR p)
```

I built this map for the mathematical community. To the formalization experts: the coordinates of the remaining theorems have been calculated and the API boundaries drawn. To the number theorists: the exact analytic choke points of the Riemann Hypothesis have been isolated into type-checked linear algebra.

**I invite you to read the paper, explore the axiom taxonomy, and inspect the architecture.**

---

*— Jason Robert Gochanour*