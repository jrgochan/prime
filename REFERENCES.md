# References — The Cathedral

**cathedral-audit** — April 19, 2026

A complete bibliography of the mathematical results used in the formal
verification. Every theorem, identity, and technique in the Cathedral
traces back to published mathematics listed here.

39 mathematicians. 167 years of prior work. Seven crown axioms. 39 total.
78 active files. 644 theorems. 17 companion papers.

---

## Core Framework

### The Riemann Hypothesis

- **Bernhard Riemann**, "Ueber die Anzahl der Primzahlen unter einer
  gegebenen Grösse," *Monatsberichte der Berliner Akademie*, November 1859.

  > The original conjecture: all non-trivial zeros of ζ(s) have real part ½.
  > In the Cathedral, RH is encoded via the Nyman–Beurling equivalence:
  > d²_N → 0, machine-verified equivalent to RH via
  > `nyman_beurling_equivalence` (both directions, zero sorry, 7 crown axioms).

### The Nyman–Beurling Criterion

- **Bertil Nyman**, *On the One-Dimensional Translation Group and Semi-Group
  in Certain Function Spaces*, Ph.D. Thesis, Uppsala University, 1950.

- **Arne Beurling**, "A closure problem related to the Riemann zeta function,"
  *Proc. Nat. Acad. Sci.*, 41:312–314, 1955.

  > RH is equivalent to the density of dilated fractional parts
  > {θ/x} in L²(0,1). The Cathedral reduces this to a finite matrix problem.
  > The converse direction uses axiom `bd_mellin_at_zero`.

### The Báez-Duarte Strengthening

- **Luis Báez-Duarte**, "A strengthening of the Nyman–Beurling criterion
  for the Riemann hypothesis," *J. Atti Accad. Naz. Lincei*, 14:5–11, 2003.

- **Luis Báez-Duarte**, "A new necessary and sufficient condition for the
  Riemann hypothesis," 2003. [arXiv:math/0307215](https://arxiv.org/abs/math/0307215)

  > Restricts the Nyman–Beurling basis to h_k(x) = {1/(kx)}, k = 1, 2, …
  > The Gram matrix G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx governs the entire problem.

### The Vasyunin Formula

- **Vasily I. Vasyunin**, "On a biorthogonal system associated with the Riemann
  hypothesis," *St. Petersburg Math. J.*, 7(3):405–419, 1996.

- **Luis Báez-Duarte, Michel Balazard, Bruno Landreau, and Éric Saias**, "Étude de
  l'autocorrélation multiplicative de la fonction 'partie fractionnaire',"
  *Ramanujan J.*, 9(1-2):215–240, 2005.

  > The Vasyunin cotangent sum formula gives G(j,k) as a finite, closed-form
  > expression involving gcd, log, and cotangent — eliminating all integrals.
  > This is axiom `vasyunin_eq_integral` in the Cathedral.

---

## Arithmetic Number Theory

### The Möbius Function

- **August Ferdinand Möbius**, "Über eine besondere Art von Umkehrung der
  Reihen," *J. Reine Angew. Math.*, 9:105–123, 1832.

  > μ(n) = (-1)^k if n is a product of k distinct primes, 0 otherwise.
  > The log cutoff witness v_k = -μ(k)(1 - ln k/ln N) is central to
  > `witness_covariance_decay` and `witness_numerator_convergence`.

### The Liouville Function

- **Joseph Liouville**, "Sur quelques formules générales qui peuvent être
  utiles dans la théorie des nombres," *J. Math. Pures Appl.*, 2(3):143–152, 1858.

  > λ(n) = (-1)^{Ω(n)} where Ω counts prime factors with multiplicity.
  > The Liouville parity decomposition G = G_even + G_odd (PT-symmetry
  > discovery) is defined in `Defs.lean` and explored in `Spectral/PTSymmetry.lean`.

### The Mertens Function

- **Franz Mertens**, "Über einige asymptotische Gesetze der Zahlentheorie,"
  *J. Reine Angew. Math.*, 77:289–338, 1874.

- **Franz Mertens**, "Ein Beitrag zur analytischen Zahlentheorie,"
  *J. Reine Angew. Math.*, 78:46–62, 1874.

  > M(x) = Σ_{n≤x} μ(n). The axiom `mertens_bound_from_rh` states
  > RH ⟹ |M(x)| ≤ Cx^{1/2}(log x)². The axioms `mertens_squarefree_sum`,
  > `mertens_tapered_sum`, and `mertens_linear_tapered_sum` encode
  > weighted Mertens sums used in the Bartlett window witness.

### The Robin Inequality

- **Guy Robin**, "Grandes valeurs de la fonction somme des diviseurs et
  hypothèse de Riemann," *J. Math. Pures Appl.*, 63:187–213, 1984.

  > RH ⟺ σ(n) < e^γ · n · ln(ln(n)) for all n ≥ 5041.
  > Formalized in `Robin/Defs.lean` via `arithmetic_rh_equivalences`.

### The Lagarias Inequality

- **Jeffrey C. Lagarias**, "An elementary problem equivalent to the Riemann
  hypothesis," *Amer. Math. Monthly*, 109(6):534–543, 2002.

  > RH ⟺ σ(n) ≤ H_n + exp(H_n) · ln(H_n) for all n ≥ 1.
  > The Cathedral proves this unconditionally for all primes
  > (`lagarias_for_primes`, zero axioms).

### The Dirichlet Divisor Function

- **Peter Gustav Lejeune Dirichlet**, *Vorlesungen über Zahlentheorie*,
  Vieweg, 1863.

  > The divisor function σ(n) = Σ_{d|n} d and its properties are used
  > extensively in `Robin/` for the Robin and Lagarias equivalences.

---

## Linear Algebra

### The Gram Matrix

- **Jørgen Pedersen Gram**, "Om Räkken 1 + 1/(2²) + 1/(3²) + …,"
  *Tidsskrift for Mathematik*, 4(6):1–13, 1884.

  > The Gram matrix G(j,k) = ⟨f_j, f_k⟩ of inner products.
  > The entire Cathedral is built on the Gram matrix of the Báez-Duarte
  > basis: `gramMatrix N` in `Defs.lean`, with 611 references across
  > the codebase.

### The Sherman–Morrison Formula

- **Jack Sherman and Winifred J. Morrison**, "Adjustment of an inverse matrix
  corresponding to a change in one element of a given matrix," *Ann.
  Math. Statist.*, 21(1):124–127, 1950.

  > (A + uvᵀ)⁻¹ = A⁻¹ - A⁻¹uvᵀA⁻¹/(1 + vᵀA⁻¹u).
  > Used to prove d²_N = 1/(1 + X_N) with zero axioms (`nb_dist_via_witness`).
  > Formalized in `LinearAlgebra/ShermanMorrison.lean`.

### The Schur Complement

- **Issai Schur**, "Über Potenzreihen, die im Innern des Einheitskreises
  beschränkt sind," *J. Reine Angew. Math.*, 147:205–232, 1917.

  > H_N PD ⟹ C_N = G_N - bbᵀ PD (Schur complement positivity).
  > Used in `LinearAlgebra/SchurComplement.lean` and `Vasyunin/Augmented/AugmentedGram.lean`.

### Sylvester's Criterion

- **James Joseph Sylvester**, "A demonstration of the theorem that every
  homogeneous quadratic polynomial is reducible by real orthogonal
  substitutions to the form of a sum of positive and negative squares,"
  *Phil. Mag.*, 4(23):138–142, 1852.

  > PD ⟺ all leading principal minors positive.
  > Used in `LinearAlgebra/Sylvester.lean` for small-N determinant certificates.

### The Bordered Matrix Theorem

- **Roger A. Horn and Charles R. Johnson**, *Matrix Analysis*, Cambridge
  University Press, 2nd edition, 2012. (Section 7.7)

  > If H_N = [A, b; bᵀ, c] and A is PD, then H_N PD ⟺ c - bᵀA⁻¹b > 0.
  > The inductive engine for `augmentedGramMatrix_posDef` (the Factorial Nuke).

### Cauchy–Schwarz Inequality

- **Augustin-Louis Cauchy**, *Cours d'analyse de l'École Royale
  Polytechnique*, 1821.

- **Karl Hermann Amandus Schwarz**, "Über ein die Flächen kleinsten
  Flächeninhalts betreffendes Problem der Variationsrechnung," *Acta Soc.
  Sci. Fenn.*, 15:315–362, 1885.

  > |⟨u,v⟩|² ≤ ⟨u,u⟩·⟨v,v⟩. Used throughout the variational arguments,
  > and specifically in `zeta_zero_separates` for the Mellin obstruction bound.
  > Also used in the Rayleigh quotient lower bound (`variational_lower_bound`).

### The Rayleigh Quotient

- **John William Strutt, 3rd Baron Rayleigh**, *The Theory of Sound*,
  Macmillan, 1877.

  > R(v) = vᵀAv / vᵀv. The variational lower bound Q(v) ≤ X_N is
  > the engine that converts covariance decay into distance decay.
  > Used in `LinearAlgebra/Variational.lean` and `Vasyunin/Proof/Chain.lean`.

### Eigenvalue Interlacing

- **Ky Fan**, "On a theorem of Weyl concerning eigenvalues of linear
  transformations I," *Proc. Nat. Acad. Sci.*, 35:652–655, 1949.

  > λ_min(G_{N+1}) ≤ λ_min(G_N). Proved as `eigenvalue_interlacing`
  > (zero axioms) in `Structural/Eigenvalue.lean`.

---

## Analysis

### The Euler–Mascheroni Constant

- **Leonhard Euler**, "De progressionibus harmonicis observationes," *Comment.
  Acad. Sci. Petropol.*, 7:150–161, 1740.

  > γ = lim_{n→∞} (H_n - ln n) ≈ 0.5772156649…
  > The series identity Σ_{m=1}^∞ (1/(m+1) - log(1 + 1/(m+1))) = γ
  > is the engine that eliminated `vasyunin_mean_eq_integral`.
  > Formalized in `Vasyunin/Augmented/MeanIntegral.lean`.

### The Gauss Digamma Formula

- **Carl Friedrich Gauss**, *Disquisitiones generales circa seriem infinitam*,
  Commentationes Societatis Regiae Scientiarum Gottingensis, 1813.

  > ψ(p/q) = -γ - ln(2q) - (π/2)cot(πp/q) + 2Σ cos(2πkp/q)·ln sin(πk/q).
  > Axiom `gauss_digamma_formula` in `Vasyunin/Cotangent/DigammaReflection.lean`.
  > Connects accumulated log terms from telescoping to the cotangent values.

### Euler's Digamma Reflection

- **Leonhard Euler**, *Institutiones Calculi Differentialis*, 1755.

  > ψ(1-x) - ψ(x) = π·cot(πx).
  > Proved as a theorem in `Vasyunin/Cotangent/DigammaReflection.lean`
  > via `logDeriv` of Mathlib's Gamma reflection Γ(s)Γ(1-s) = π/sin(πs).

### Stirling's Approximation

- **James Stirling**, *Methodus Differentialis*, 1730.

  > ln(n!) = n ln n - n + O(ln n).
  > Used in `Vasyunin/Proof/BartlettWindow.lean` (StirlingBridge) to
  > connect the Mertens tapered sum to the Bartlett window coefficients.

### Abel Summation (Partial Summation)

- **Niels Henrik Abel**, "Untersuchungen über die Reihe …," *J. Reine
  Angew. Math.*, 1:311–339, 1826.

  > Σ_{n=a}^{b} f(n)g(n) = F(b)g(b) - Σ_{n=a}^{b-1} F(n)(g(n+1)-g(n)).
  > Axiom `abel_summation_l2_bound` converts Mertens bound to L² bound.
  > Used in `MellinBridge/MertensWeightBypass.lean`.

### Taylor Series

- **Brook Taylor**, *Methodus Incrementorum Directa et Inversa*, 1715.

  > f(x) = Σ f^(n)(a)(x-a)^n / n!.
  > Used in `Robin/Lagarias.lean` for the Taylor truncation of
  > exp(H_p)·ln(H_p) in the Lagarias inequality proof.

### Beatty Sequences

- **Samuel Beatty**, "Problem 3173," *Amer. Math. Monthly*, 33:159, 1926.

  > The Beatty sequence ⌊n/j⌋ partitions (0,1] into tiles where
  > ⌊1/(jx)⌋ is constant. Used in `Vasyunin/Cotangent/CrossTermFTC.lean`
  > to prove `tile_n_values_bounded` (at most 2 tiles per row when j ≤ k).

### Hermite's Floor Sum Identity

- **Charles Hermite**, "Sur quelques conséquences arithmétiques des formules
  de la théorie des fonctions elliptiques," *Bull. Soc. Math. France*,
  3:169–188, 1875.

  > Σ_{m=1}^{a-1} ⌊mb/a⌋ = (a-1)(b-1)/2 for coprime a,b.
  > Proved in `Vasyunin/Cotangent/FloorCoprime.lean` via the Eisenstein
  > maneuver (multiply by 2 to bypass ℕ division).

### The Eisenstein Maneuver

- **Gotthold Eisenstein**, "Geometrischer Beweis des Fundamentaltheorems
  für die quadratischen Reste," *J. Reine Angew. Math.*, 28:246–248, 1844.

  > Lattice-point counting proof of quadratic reciprocity.
  > The Cathedral independently rediscovered Eisenstein's 1844 technique:
  > multiply the floor sum identity by 2 to reduce to ℤ arithmetic,
  > avoiding ℕ division. Eliminates `floor_sum_reciprocity` sorry.

---

## Transform Theory

### The Mellin Transform

- **Hjalmar Mellin**, "Über die fundamentale Wichtigkeit des Satzes von
  Cauchy für die Theorien der Gamma- und der hypergeometrischen Funktionen,"
  *Acta Soc. Sci. Fenn.*, 21:1–115, 1896.

  > M[f](s) = ∫₀^∞ x^{s-1} f(x) dx. Connects the Báez-Duarte basis to
  > zeta: M[{k/·}](s) = -(ζ(s)/s + 1/(s-1))/k^s. Central to
  > `MellinBridge/` and the converse axiom `zeta_zero_separates`.

### The Plancherel Theorem

- **Michel Plancherel**, "Contribution à l'étude de la représentation
  d'une fonction arbitraire par des intégrales définies," *Rend. Circ.
  Mat. Palermo*, 30:289–335, 1910.

  > ‖f‖² = ‖f̂‖². The Mellin-Plancherel identity converts the L²
  > distance ∫|1-f|² into the Gram matrix quadratic form.
  > Axiom `mellin_plancherel_gram` in `MellinBridge/MellinSieve.lean`.

### Fourier Inversion

- **Jean-Baptiste Joseph Fourier**, *Théorie analytique de la chaleur*,
  Firmin Didot, 1822.

  > f(x) = ∫ f̂(ξ)e^{2πixξ} dξ. Axiom `fourier_inversion_autocorrelation`
  > in `MellinBridge/AutocorrelationBypass.lean`.

---

## Sieve Theory

### The Selberg Sieve

- **Atle Selberg**, "An elementary proof of the prime-number theorem,"
  *Ann. of Math.*, 50:305–313, 1949.

- **Atle Selberg**, "An elementary proof of the prime-number theorem for
  arithmetic progressions," *Canadian J. Math.*, 2:66–78, 1950.

  > The log cutoff witness v_k = -μ(k)(1 - ln k / ln N) is a Selberg-type
  > sieve weight. The L² variational principle independently selects these
  > weights as optimal — the Selberg sieve emerges from pure linear algebra.

### Vaughan's Identity

- **Robert C. Vaughan**, "Sommes trigonométriques sur les nombres premiers,"
  *C. R. Acad. Sci. Paris Sér. A*, 285:981–983, 1977.

- **Robert C. Vaughan**, *The Hardy–Littlewood Method*, Cambridge University
  Press, 2nd edition, 1997.

  > Decomposes sums over Möbius into Type I and Type II bilinear sums.
  > Axioms `vaughan_decomposition`, `type_I_bound`, `type_II_sieve_bound`
  > in `Sieve/MoebiusUncoupling.lean` and `Sieve/BilinearSieve.lean`.

### The Bombieri–Vinogradov Theorem

- **Enrico Bombieri**, "On the large sieve," *Mathematika*, 12:201–225, 1965.

- **Askold Ivanovich Vinogradov**, "The density hypothesis for Dirichlet
  L-series," *Izv. Akad. Nauk SSSR Ser. Mat.*, 29:903–934, 1965.

  > Provides equidistribution of primes in arithmetic progressions on average.
  > Referenced in `Sieve/MoebiusUncoupling.lean` as context for `type_I_bound`.

---

## Spectral Theory

### The Hilbert–Pólya Conjecture

- **David Hilbert** and **George Pólya**, unpublished correspondence, c. 1914.

- **Andrew Odlyzko**, "On the distribution of spacings between zeros of the
  zeta function," *Math. Comp.*, 48:273–308, 1987.

  > The zeta zeros correspond to eigenvalues of a self-adjoint operator.
  > The Cathedral's Gram matrix G_N is the finite-dimensional shadow of
  > this conjectured operator, evaluated in the Báez-Duarte basis.

### The Bartlett Window

- **Maurice S. Bartlett**, "Smoothing periodograms from time-series with
  continuous spectra," *Nature*, 161:686–687, 1948.

  > The log cutoff witness v_k = -μ(k)(1 - ln k/ln N) is a Bartlett
  > (triangular) window applied to the Möbius function in log-frequency.
  > Formalized in `Vasyunin/Proof/BartlettWindow.lean`.

---

## Dedekind Sums

### The Dedekind Sum and Reciprocity

- **Richard Dedekind**, "Erläuterungen zu den Fragmenten XXVIII," in
  *B. Riemann's Gesammelte Mathematische Werke*, 1876.

- **Hans Rademacher and Emil Grosswald**, *Dedekind Sums*, Mathematical
  Association of America, 1972.

  > The Vasyunin cotangent sum V(a,b) = Σ_{m=1}^{a-1} {mb/a} cot(πm/a)
  > is related to classical Dedekind sums. The reciprocity law for
  > Dedekind sums may provide the skeleton key for eliminating
  > `vasyunin_eq_integral`.

---

## Reference Texts

### Analytic Number Theory

- **Henryk Iwaniec and Emmanuel Kowalski**, *Analytic Number Theory*,
  AMS Colloquium Publications, vol. 53, 2004.

  > Comprehensive reference for sieve methods, L-functions, and the
  > techniques underlying the Sieve/ and MellinBridge/ modules.

- **Edward Charles Titchmarsh**, *The Theory of the Riemann Zeta-Function*,
  2nd edition (revised by D. R. Heath-Brown), Oxford University Press, 1986.

  > Standard reference for zeta function theory, Mellin transforms,
  > and the analytic properties used in `zeta_zero_separates`.

- **Godfrey Harold Hardy and John Edensor Littlewood**, "Contributions to
  the theory of the Riemann zeta-function and the theory of the distribution
  of primes," *Acta Math.*, 41:119–196, 1918.

  > Foundational work on the connection between zeta zeros and prime
  > distribution, underlying the PNT-level axiom `witness_numerator_convergence`.

---

## Formal Verification

### Lean 4 and Mathlib

- **Leonardo de Moura and Sebastian Ullrich**, "The Lean 4 Theorem Prover and
  Programming Language," *CADE-28*, 2021.

- **The Mathlib Community**, "The Lean Mathematical Library,"
  *Proceedings of the 9th ACM SIGPLAN International Conference on
  Certified Programs and Proofs*, 2020.

  > The Cathedral is built in Lean 4 against Mathlib. Key Mathlib
  > dependencies include: `Analysis.SpecificLimits.Basic`
  > (`tendsto_harmonic_sub_log`), `Analysis.SpecialFunctions.Log.Basic`,
  > `LinearAlgebra.Matrix.PosDef`, `MeasureTheory.Integral.IntervalIntegral`,
  > `NumberTheory.LSeries.RiemannZeta`.

---

## How Critical-Path Axioms Map to References (cathedral-audit)

The crown theorem `nyman_beurling_equivalence` depends on exactly **2 mathematical axioms**
(verified by `#print axioms`):

| Cathedral Axiom | Mathematical Content | References |
|---|---|---|
| `bd_mellin_at_zero` | Analytic continuation of BD Mellin identity to Re(s) > 0 | Báez-Duarte 2003, Mellin 1896 |
| `rh_implies_l2_convergence` | RH ⟹ d²_N → 0 (Báez-Duarte theorem) | Báez-Duarte 2003 |

Plus Lean kernel axioms: `propext`, `Classical.choice`, `Quot.sound`.

The 32 remaining axioms (39 total active) support alternative proof paths
(spectral engine, sieve engine, Vasyunin cotangent formula) that are
formalized but not on the shortest path to the crown theorem.

## How Eliminated Axioms Were Proved

| Former Axiom | Proof Technique | Reference |
|---|---|---|
| `augmentedSchurComplement_pos` | Factorial Nuke (N! divisibility) | Horn & Johnson 2012 |
| `vasyunin_mean_eq_integral` | Euler-Mascheroni series | Euler 1740 |
| `vasyuninGramMatrix_posDef` | Bordered matrix induction | Schur 1917 |
| `variational_lower_bound` | Cauchy–Schwarz in C-inner product | Cauchy 1821, Schwarz 1885 |
| `nb_dist_via_witness` | Sherman–Morrison | Sherman & Morrison 1950 |
| `floor_sum_reciprocity` | Eisenstein maneuver | Eisenstein 1844, Hermite 1875 |
| `log_cutoff_witness_bound` | Decomposed into sub-axioms | Selberg 1949, Mertens 1874 |
| `digamma_reflection_complex` | logDeriv of Γ(s)Γ(1-s) | Euler 1755 |
| `abel_summation_l2_bound` | Abel summation siege proof | Abel 1826 |
| `divisor_sum_swap` | Finset bijection | Dirichlet 1863 |
| `mellin_fourier_scale` | Fourier-Mellin CoV (White Singlet) | Mellin 1896 |

---

## Archived Paths

Two archived paths are preserved as monuments to the formalization process:

- **`Cathedral/Archive/HighFrequencyTrap/`**: The {k/x} basis — computationally
  correct but mathematically insufficient for the RH equivalence.
- **`Cathedral/Archive/DiscreteMirage/`**: The complete Vasyunin cotangent
  decomposition — 14 fully proved telescope theorems, digamma reflection,
  but containing a false `harmonicTileSum_reciprocity` axiom.

---

## Documentation Suite

17 companion papers for 17 audiences:

| Paper | Audience |
|-------|----------|
| `cathedral.tex` | Technical overview |
| `overview.tex` | Quick reference |
| `cathedral-math.tex` | Research mathematicians |
| `cathedral-physics.tex` | Physicists |
| `cathedral-public.tex` | General public |
| `cathedral-cs.tex` | Proof engineers / CS |
| `cathedral-security.tex` | Security researchers |
| `cathedral-philosophy.tex` | Philosophers of mathematics |
| `cathedral-ai.tex` | AI/ML researchers |
| `cathedral-lean.tex` | Lean/ITP community |
| `cathedral-foundations.tex` | Logicians / foundations |
| `cathedral-engineering.tex` | Practicing engineers |
| `cathedral-futures.tex` | Engineering frontiers |
| `cathedral-energy.tex` | Energy systems engineers |
| `cathedral-dualuse.tex` | Dual-use risk assessment |
| `cathedral-politics.tex` | Policy / governance |
| `cathedral-letter.tex` | A letter from the builder |

---

*Last updated: April 19, 2026 — cathedral-audit*
