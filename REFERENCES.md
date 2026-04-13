# References — The Cathedral

A complete bibliography of the mathematical results used in the formal
verification. Every theorem, identity, and technique in the Cathedral
traces back to published mathematics listed here.

---

## Core Framework

### The Nyman–Beurling Criterion

- **B. Nyman**, *On the One-Dimensional Translation Group and Semi-Group
  in Certain Function Spaces*, Ph.D. Thesis, Uppsala University, 1950.

- **A. Beurling**, "A closure problem related to the Riemann zeta function,"
  *Proc. Nat. Acad. Sci.*, 41:312–314, 1955.

  > RH is equivalent to the density of dilated fractional parts
  > {θ/x} in L²(0,1). The Cathedral reduces this to a finite matrix problem.

### The Báez-Duarte Strengthening

- **L. Báez-Duarte**, "A strengthening of the Nyman–Beurling criterion
  for the Riemann hypothesis," *J. Atti Accad. Naz. Lincei*, 14:5–11, 2003.

- **L. Báez-Duarte**, "A new necessary and sufficient condition for the
  Riemann hypothesis," 2003. [arXiv:math/0307215](https://arxiv.org/abs/math/0307215)

  > Restricts the Nyman–Beurling basis to h_k(x) = {1/(kx)}, k = 1, 2, …
  > The Gram matrix G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx governs the entire problem.

### The Vasyunin Formula

- **V. I. Vasyunin**, "On a biorthogonal system associated with the Riemann
  hypothesis," *St. Petersburg Math. J.*, 7(3):405–419, 1996.

- **L. Báez-Duarte, M. Balazard, B. Landreau, and É. Saias**, "Étude de
  l'autocorrélation multiplicative de la fonction 'partie fractionnaire',"
  *Ramanujan J.*, 9(1-2):215–240, 2005.

  > The Vasyunin cotangent sum formula gives G(j,k) as a finite, closed-form
  > expression involving gcd, log, and cotangent — eliminating all integrals.
  > This is Axiom 2 (`vasyunin_eq_integral`) in the Cathedral.

---

## Arithmetic Equivalences

### The Robin Inequality

- **G. Robin**, "Grandes valeurs de la fonction somme des diviseurs et
  hypothèse de Riemann," *J. Math. Pures Appl.*, 63:187–213, 1984.

  > RH ⟺ σ(n) < e^γ · n · ln(ln(n)) for all n ≥ 5041.

### The Lagarias Inequality

- **J. C. Lagarias**, "An elementary problem equivalent to the Riemann
  hypothesis," *Amer. Math. Monthly*, 109(6):534–543, 2002.

  > RH ⟺ σ(n) ≤ H_n + exp(H_n) · ln(H_n) for all n ≥ 1.
  > The Cathedral proves this unconditionally for all primes
  > (`lagarias_for_primes`, zero axioms).

---

## Linear Algebra

### The Sherman–Morrison Formula

- **J. Sherman and W. J. Morrison**, "Adjustment of an inverse matrix
  corresponding to a change in one element of a given matrix," *Ann.
  Math. Statist.*, 21(1):124–127, 1950.

  > Used to prove d²_N = 1/(1 + X_N) with zero axioms (`nb_dist_via_witness`).

### The Schur Complement

- **I. Schur**, "Über Potenzreihen, die im Innern des Einheitskreises
  beschränkt sind," *J. Reine Angew. Math.*, 147:205–232, 1917.

  > H_N PD ⟹ C_N = G_N - bb^T PD (Schur complement positivity).
  > Used in `SchurComplement.lean` and `AugmentedGram.lean`.

### Sylvester's Criterion

- **J. J. Sylvester**, "A demonstration of the theorem that every
  homogeneous quadratic polynomial is reducible by real orthogonal
  substitutions to the form of a sum of positive and negative squares,"
  *Phil. Mag.*, 4(23):138–142, 1852.

  > PD ⟺ all leading principal minors positive.
  > Used in `Sylvester.lean` for small-N determinant certificates.

### The Bordered Matrix Theorem

- **R. A. Horn and C. R. Johnson**, *Matrix Analysis*, Cambridge
  University Press, 2nd edition, 2012. (Section 7.7)

  > If H_N = [A, b; b^T, c] and A is PD, then H_N PD ⟺ c - b^T A⁻¹ b > 0.
  > The inductive engine for `augmentedGramMatrix_posDef`.

---

## Analysis

### The Euler–Mascheroni Constant

- **L. Euler**, "De progressionibus harmonicis observationes," *Comment.
  Acad. Sci. Petropol.*, 7:150–161, 1740.

  > γ = lim_{n→∞} (H_n - ln n) ≈ 0.5772156649…
  > Used in `MeanIntegral.lean`: ∫₀¹ {1/(kx)} dx = (ln k + 1 - γ)/k.
  > The series identity Σ_{m=1}^∞ (1/(m+1) - log(1 + 1/(m+1))) = γ
  > is the engine that eliminated `vasyunin_mean_eq_integral`.

### Beatty Sequences

- **S. Beatty**, "Problem 3173," *Amer. Math. Monthly*, 33:159, 1926.

- **Lord Rayleigh**, "On the determination of the character of the
  fundamental solution of the equation of Laplace's functions," *Proc.
  London Math. Soc.*, 1(1):117–121, 1894.

  > The Beatty sequence ⌊n/j⌋ partitions (0,1] into tiles where
  > ⌊1/(jx)⌋ is constant. Used in `CrossTermFTC.lean` to prove
  > `tile_n_values_bounded` (at most 2 tiles per row when j ≤ k).

### Dedekind Sums and the Reciprocity Law

- **R. Dedekind**, "Erläuterungen zu den Fragmenten XXVIII," in
  *B. Riemann's Gesammelte Mathematische Werke*, 1876.

- **H. Rademacher and E. Grosswald**, *Dedekind Sums*, Mathematical
  Association of America, 1972.

  > The Vasyunin cotangent sum V(a,b) = Σ_{m=1}^{a-1} {mb/a} cot(πm/a)
  > is related to classical Dedekind sums. The reciprocity law for
  > Dedekind sums may provide the skeleton key for eliminating Axiom 2.

### The Digamma Function and Euler's Reflection Formula

- **L. Euler**, *Institutiones Calculi Differentialis*, 1755.

  > ψ(1-x) - ψ(x) = π·cot(πx)
  > This connects the accumulated log terms from the telescoping sum
  > to the cotangent values in the Vasyunin formula. Identified as the
  > potential bridge for Axiom 2 elimination (Season 2 infrastructure).

---

## Sieve Theory

### The Selberg Sieve

- **A. Selberg**, "An elementary proof of the prime-number theorem,"
  *Ann. of Math.*, 50:305–313, 1949.

- **A. Selberg**, "An elementary proof of the prime-number theorem for
  arithmetic progressions," *Canadian J. Math.*, 2:66–78, 1950.

  > The log cutoff witness v_k = -μ(k)(1 - ln k / ln N) is a Selberg-type
  > sieve weight. The L² variational principle independently selects these
  > weights as optimal — the Selberg sieve emerges from pure linear algebra.

---

## The Riemann Hypothesis

- **B. Riemann**, "Ueber die Anzahl der Primzahlen unter einer gegebenen
  Grösse," *Monatsberichte der Berliner Akademie*, November 1859.

  > The original conjecture: all non-trivial zeros of ζ(s) have real part ½.
  > In the Cathedral, this is encoded as Axiom 1 (`log_cutoff_witness_bound`):
  > ∃ c > 0, ∃ N₀, ∀ N ≥ N₀: c · ln(N) ≤ Q_N(v_log).

---

## Formal Verification

### Lean 4 and Mathlib

- **L. de Moura and S. Ullrich**, "The Lean 4 Theorem Prover and
  Programming Language," *CADE-28*, 2021.

- **The Mathlib Community**, "The Lean Mathematical Library,"
  *Proceedings of the 9th ACM SIGPLAN International Conference on
  Certified Programs and Proofs*, 2020.

  > The Cathedral is built in Lean 4 against Mathlib. Key Mathlib
  > dependencies include: `Analysis.SpecificLimits.Basic`
  > (tendsto_harmonic_sub_log), `Analysis.SpecialFunctions.Log.Basic`,
  > `LinearAlgebra.Matrix.PosDef`, `MeasureTheory.Integral.IntervalIntegral`.

---

## How Axioms Map to References

| Cathedral Axiom | Mathematical Source | Reference |
|---|---|---|
| `log_cutoff_witness_bound` | Nyman–Beurling + Selberg sieve | Riemann 1859, Nyman 1950, Selberg 1949 |
| `vasyunin_eq_integral` | Vasyunin cotangent formula | Vasyunin 1996, Báez-Duarte et al. 2005 |
| `arithmetic_rh_equivalences` | Robin + Lagarias equivalences | Robin 1984, Lagarias 2002 |

| Eliminated Axiom | Proof Technique | Reference |
|---|---|---|
| `augmentedSchurComplement_pos` | Factorial Nuke (N! divisibility) | Horn & Johnson 2012 (bordered matrices) |
| `vasyunin_mean_eq_integral` | Euler-Mascheroni series | Euler 1740 |
| `vasyuninGramMatrix_posDef` | Bordered matrix induction | Schur 1917, Horn & Johnson 2012 |
| `variational_lower_bound` | Cauchy–Schwarz in C-inner product | Standard |
| `nb_dist_via_witness` | Sherman–Morrison | Sherman & Morrison 1950 |

---

*Last updated: April 13, 2026*
