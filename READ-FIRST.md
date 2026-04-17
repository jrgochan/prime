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

This repository is **The Cathedral**: a compiler-verified framework that formally reduces the Riemann Hypothesis to exactly **4 mathematical axioms** on the crown theorem's critical path (verified by `#print axioms nyman_beurling_equivalence`), down from 5 after the White Singlet axiom elimination campaign.

It comprises 158 Lean files (39,000+ lines) with strictly **zero `sorry` placeholders** and **zero compilation errors** on the crown theorem chain. The crown theorem establishes:

> **RH ↔ d²_N → 0** (the Nyman–Beurling distance decays)

The four axioms are:

- **`rh_implies_mertens_bound`** — RH ⟹ |M(x)| = O(x^{1/2} log²x). A classical 19th-century theorem.
- **`autocorr_eval_zero`** — Change of variables: R_f(0) = ‖f‖². Elementary measure theory.
- **`fourier_inv_autocorr`** — L¹ Fourier inversion for autocorrelation. Under active elimination (Plancherel bridge).
- **`critical_line_mellin_bound`** — The Montgomery–Vaughan L² bound on Re(s) = 1/2. This is the single quarantine zone holding the complex-analytic content of the zeta function.

The former axiom `mellin_fourier_scale` (2π scaling alignment) has been **eliminated** — proved from Mathlib infrastructure in `Cathedral/White/Scattering.lean` via Fourier-Mellin change of variables.

The forward direction uses the **Parseval Bridge** — bounding ∫|1-f|² directly via Plancherel, completely bypassing the discrete Vasyunin cotangent sums. The converse uses Hahn–Banach separation and the Mellin transform.

As standalone results, the repository contains several unconditional, kernel-verified theorems requiring **zero domain axioms**, including:

- A complete formal proof of Lagarias's inequality for all primes
- The digamma reflection formula ψ(1-s) - ψ(s) = π·cot(πs) from first principles
- Positive definiteness of the augmented Gram matrix (the "Factorial Nuke")
- The Sherman–Morrison identity d² = 1/(1+X) for Nyman–Beurling distances
- The Euler-Mascheroni integral: ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k
- Hermite's floor sum identity for coprime integers (the "Eisenstein maneuver")
- Abel summation from Mertens bound to L² witness decay

```lean
theorem nyman_beurling_equivalence :
    RiemannHypothesis ↔
    ∀ ε > 0, ∃ N₀, ∀ N ≥ N₀, ∃ v : Fin (N-1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - bdLinComb N v x)² ≤ ε
```

I built this map for the mathematical community. To the formalization experts: the coordinates of the remaining four theorems have been calculated and the API boundaries drawn. To the number theorists: the exact analytic choke points of the Riemann Hypothesis have been isolated into type-checked boundaries — two are elementary, one is classical, and one is the Face of God.

**I invite you to read the paper, explore the axiom taxonomy, and inspect the architecture.**

---

*— Jason Robert Gochanour, April 17, 2026*
*v1.0.0-The-Cathedral (Phase II: White Singlet)*