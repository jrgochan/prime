# 🏛️ The Cathedral: A Machine-Checked Architecture for the Riemann Hypothesis

## A Confession and an Invitation

I need to be radically honest upfront: I am not a professional mathematician, I do not have a background in analytic number theory, and I did not write a single line of the Lean 4 code in this repository myself.

My background is in computational systems and high-precision optimization. This project did not begin as a formal proof attempt, but as a highly unorthodox geometric experiment.

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

Realizing this was a profound structural property of the matrix, I abandoned my octonion hypothesis (leaving the code in the `Spectral/` directory as an exploratory artifact) and pivoted entirely to formal verification.

I acted as the systems architect, partnering with AI acting as my Lean 4 engineer and mathematical theorist. Instead of a traditional "bottom-up" formalization, we built a **"top-down" dependency graph**.

We started at the Riemann Hypothesis and rigorously type-checked our way downward. When the strictness of the Lean kernel rejected finite-dimensional Cauchy–Schwarz bounds (exposing what we call the **Hyperplane Trap**), the compiler forced us to architect infinite-dimensional bypasses, such as the Báez-Duarte Orthogonal Witness. When we lacked complex analysis libraries, we routed around them using L¹ Fourier inversion and real-variable Abel summation.

---

## What This Repository Is

This repository is **The Cathedral**: a compiler-verified framework that formally reduces the Riemann Hypothesis to exactly **36 domain-isolated axioms**.

It comprises 45 Lean files and compiles in 3,486 build jobs with strictly zero `sorry` placeholders on the structural proofs. We have successfully isolated the deep analytic number theory (e.g., the Mertens bound, the L² properties of the orthogonal witness) behind precise, type-checked API boundaries.

As a side-effect of this top-down architecture, the repository also contains several unconditional, kernel-verified theorems that require **zero domain axioms**—including a complete formal proof of Lagarias's inequality for all primes:

```lean
theorem lagarias_for_primes {p : ℕ} (hp : p.Prime) :
    (sumOfDivisors p : ℝ) ≤ harmonicR p + Real.exp (harmonicR p) * Real.log (harmonicR p)
```

I built this map for the mathematical community. To the formalization experts: the coordinates of the remaining theorems have been calculated and the API boundaries drawn. To the number theorists: the exact analytic choke points of the Riemann Hypothesis have been isolated into type-checked linear algebra.

**I invite you to read the paper, explore the axiom taxonomy, and inspect the architecture.**

---

*— Jason Robert Gochanour*

*Los Alamos, NM*