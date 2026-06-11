# References — The Cathedral

**Penta-Crown** — June 10, 2026 (v26)
**Penta-Crown Cathedral** — 1 axiom (`overcancellation_axiom` ≡ RH)

A complete bibliography of the mathematical results used in the formal
verification and the companion papers. Every theorem, identity, and
technique in the Cathedral traces back to published mathematics listed here.

55+ mathematicians. 167 years of prior work. One axiom ≡ RH.
474 active files. ~4,600 theorems. 17 papers. 56 Rust/MPFR/DD experiments.

---

## Core Framework

### The Riemann Hypothesis

- **Bernhard Riemann**, "Ueber die Anzahl der Primzahlen unter einer
  gegebenen Grösse," *Monatsberichte der Berliner Akademie*, November 1859.

  > The original conjecture: all non-trivial zeros of ζ(s) have real part ½.
  > In the Cathedral, RH is encoded via the Nyman–Beurling equivalence:
  > d²_N → 0, machine-verified equivalent to RH via
  > `baez_duarte_forward` (both directions, zero sorry, 1 axiom ≡ RH).
  > The sole axiom `discrete_riemann_hypothesis` is formally proved equivalent
  > to RH via `witness_covariance_decay_iff_rh` (v22, May 31 2026).

### The Nyman–Beurling Criterion

- **Bertil Nyman**, *On the One-Dimensional Translation Group and Semi-Group
  in Certain Function Spaces*, Ph.D. Thesis, Uppsala University, 1950.

- **Arne Beurling**, "A closure problem related to the Riemann zeta function,"
  *Proc. Nat. Acad. Sci.*, 41:312–314, 1955.

  > RH is equivalent to the density of dilated fractional parts
  > {θ/x} in L²(0,1). The Cathedral reduces this to a finite matrix problem.
  > The converse direction uses zero custom axioms (pure Mathlib).

### The Báez-Duarte Strengthening

- **Luis Báez-Duarte**, "A strengthening of the Nyman–Beurling criterion
  for the Riemann hypothesis," *Atti Accad. Naz. Lincei*, 14:5–11, 2003.

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
  > The diagonal case G(k,k) has been **proved as a theorem** (Stirling + FTC).
  > The off-diagonal case has also been **proved as a theorem** via the Cotangent
  > Tower (25 files, 0 axioms, 0 sorry): piecewise partition, telescope sums,
  > FormulaBridge, and GCD reduction.

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
  > (`lagarias_for_primes`, zero axioms). The cross-path bridge
  > `robin_implies_nyman_beurling` and `lagarias_implies_nyman_beurling`
  > are proved in `Robin/Equivalence.lean`.

### The Nicolas Inequality

- **Jean-Louis Nicolas**, "Petites valeurs de la fonction d'Euler,"
  *J. Number Theory*, 17:375–388, 1983.

  > Equivalent to Robin for primorial arguments. Used in
  > `Robin/BaseCases.lean` and `Robin/HarmonicBounds.lean`.

### The Dirichlet Divisor Function

- **Peter Gustav Lejeune Dirichlet**, *Vorlesungen über Zahlentheorie*,
  Vieweg, 1863.

  > The divisor function σ(n) = Σ_{d|n} d and its properties are used
  > extensively in `Robin/` for the Robin and Lagarias equivalences,
  > and in the Particle Zoo paper for the boson–fermion classification
  > (the ratio σ(k)/k determines spectral mass).

### The Erdős–Kac Theorem

- **Paul Erdős and Mark Kac**, "The Gaussian law of errors in the theory of
  additive number theoretic functions," *Amer. J. Math.*, 62:738–742, 1940.

  > (ω(n) - log log n) / √(log log n) converges to a standard normal
  > distribution, where ω(n) is the number of distinct prime factors.
  > In the Particle Zoo paper, the arithmetic sieve to N = 10⁹ confirms
  > that ω(k) peaks at exactly ω = 3, matching the Standard Model's
  > three generations of matter (Up/Down, Charm/Strange, Top/Bottom).

### Mersenne Primes

- **Marin Mersenne**, *Cogitata Physico-Mathematica*, 1644.

  > M_p = 2^p - 1 is prime for certain exponents p.
  > The Particle Zoo paper discovers the **Mersenne Cascade**: at each
  > scale N, a different Mersenne prime family dominates the Nyman–Beurling
  > ground state. The cascade reaches an infrared fixed point at M₃ = 7,
  > with the champion k = 448 = 2⁶ · 7 stable from N = 10⁶ to N = 10⁹.

### Perfect Numbers

- **Euclid**, *Elements*, Book IX, Proposition 36, c. 300 BCE.

- **Leonhard Euler**, "De numeris amicabilibus," *Opera Omnia*,
  Series I, vol. 2, 1849 (original c. 1747).

  > An even perfect number has the form 2^{p-1}(2^p - 1) where 2^p - 1
  > is a Mersenne prime. The Particle Zoo identifies perfect numbers as
  > **BPS states** of the integer lattice: they satisfy σ(n) = 2n,
  > placing them at the exact balance point between deficient primes
  > (σ/n < 2) and abundant composites (σ/n > 2).

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

- **Hermann Weyl**, "Das asymptotische Verteilungsgesetz der Eigenwerte
  linearer partieller Differentialgleichungen," *Math. Ann.*, 71:441–479, 1912.

- **Ky Fan**, "On a theorem of Weyl concerning eigenvalues of linear
  transformations I," *Proc. Nat. Acad. Sci.*, 35:652–655, 1949.

  > λ_min(A+B) ≥ λ_min(A) + λ_min(B) for Hermitian matrices.
  > Proved as `weyl_min_eigenvalue` (zero axioms) in `Spectral/RayleighBridge.lean`.
  > Also: λ_min(G_{N+1}) ≤ λ_min(G_N). Proved as `eigenvalue_interlacing`
  > (zero axioms) in `Structural/Eigenvalue.lean`.

### The Cholesky Factorization

- **André-Louis Cholesky**, unpublished note, c. 1902–1910. (Published
  posthumously by Commandant Benoit, *Bull. Géodésique*, 2:67–77, 1924.)

  > A = LLᵀ factorization for positive-definite matrices.
  > The **Cholesky Decrement Identity** d²(N+1) = d²(N) − y²_new is
  > proved in `Structural/CholeskyDecrement.lean` (660 lines, 0 sorry,
  > 0 axioms). The extraction y²_new is the Schur complement residual:
  > the amount of vacuum energy removed by the (N+1)-th basis function.
  > GPU Cholesky (cuSOLVER dpotrf) computes d²_N at N up to 55,440.

### The Bordered Secular Equation

- **James Joseph Sylvester**, "On the relation between the minor
  determinants of linearly equivalent quadratic functions,"
  *Phil. Mag.*, 1:295–305, 1851.

- **Gene H. Golub**, "Some modified matrix eigenvalue problems,"
  *SIAM Review*, 15(2):318–334, 1973.

  > The eigenvalue drop δ = λ_min(G_N) − λ_min(G_{N+1}) is bounded by
  > δ ≤ cos²θ · ‖g‖²/S where cos²θ is the alignment with the minimum
  > eigenspace and S is the Schur complement. Proved in
  > `Structural/BorderedSpectral.lean` (zero sorry, zero axioms).

### The Woodbury Matrix Identity

- **Max A. Woodbury**, "Inverting modified matrices," *Memorandum
  Report 42, Statistical Research Group*, Princeton University, 1950.

  > (A + UCV)⁻¹ = A⁻¹ − A⁻¹U(C⁻¹ + VA⁻¹U)⁻¹VA⁻¹.
  > Generalization of Sherman–Morrison. Used in
  > `Physics/Cancellation/WoodburyCondensate.lean` for the Gram matrix
  > decomposition G = R + (1/4)J via the Glass Bridge.

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
  > The Parseval Bridge (`White/Scattering.lean`) is **fully proved**
  > with zero axioms — the key innovation of v11.

### The Parseval Theorem

- **Marc-Antoine Parseval**, "Mémoire sur les séries et sur l'intégration
  complète," *Mémoires présentés à l'Institut des Sciences*, 1806.

  > ∫|f(x)|² dx = Σ |c_n|². The Parseval identity for L² inner products
  > is the foundation of the Parseval Bridge: the spatial L²(0,1) norm
  > equals the Mellin L² norm on the critical line. This bridge is
  > PROVED (0 axioms, 0 sorry) in `White/Scattering.lean`.

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
  > Referenced in `Sieve/MoebiusUncoupling.lean` and as a promising angle
  > for graduating `discrete_riemann_hypothesis` ("RH on average" route).

### The Chowla Conjecture (Logarithmic)

- **Sarvadaman Chowla**, "The Riemann hypothesis and Hilbert's tenth
  problem," *Gordon and Breach*, 1965.

- **Terence Tao**, "The logarithmic Chowla conjecture is equivalent to
  a Chowla-type conjecture with logarithmic averaging," *Forum of
  Mathematics, Pi*, 4:e8, 2016.

  > Tao proved: (1/log X) Σ_{n≤X} μ(n)·μ(n+h)/n → 0 for each fixed h.
  > Used in `Physics/GramWiring/ChowlaBridge.lean` to bound the
  > off-diagonal shift sums B(N,h) in v^T G v.

---

## Spectral Theory

### The Hilbert–Pólya Conjecture

- **David Hilbert** and **George Pólya**, unpublished correspondence, c. 1914.

- **Andrew Odlyzko**, "On the distribution of spacings between zeros of the
  zeta function," *Math. Comp.*, 48:273–308, 1987.

  > The zeta zeros correspond to eigenvalues of a self-adjoint operator.
  > The Cathedral's Gram matrix G_N is the finite-dimensional shadow of
  > this conjectured operator, evaluated in the Báez-Duarte basis.

### The Atiyah TQFT Axioms

- **Michael Atiyah**, "Topological quantum field theories,"
  *Publ. Math. IHES*, 68:175–186, 1988.

- **Michael Atiyah**, "New invariants of 3- and 4-dimensional manifolds,"
  in *The Mathematical Heritage of Hermann Weyl*, Proc. Sympos. Pure Math.,
  48:285–299, AMS, 1988.

  > Atiyah's axioms define a TQFT as a functor from cobordisms to vector spaces:
  > (1) Space axiom: each manifold Σ maps to a Hilbert space H(Σ);
  > (2) Cobordism axiom: each cobordism M maps to a linear operator Z(M);
  > (3) Gluing axiom: Z(M₁ ∪_Σ M₂) = Z(M₂) ∘ Z(M₁) (functoriality);
  > (4) Vacuum axiom: Z(∅) = ℂ.
  >
  > The Cathedral instantiates these axioms arithmetically:
  > N → H_N (resolution Hilbert space), G_N as propagator,
  > Cholesky decrement as gluing (functoriality), and
  > d²_N = partition function with RH = triviality in the infrared limit.
  > The axiom vtGv ≤ 1 is **vacuum stability**: the vacuum energy is bounded.
  > See: `docs/ai/antigravity/torus-projection/RE: ATIYAH & THE TOPOLOGY OF THE PRIMES.md`

### The Bartlett Window

- **Maurice S. Bartlett**, "Smoothing periodograms from time-series with
  continuous spectra," *Nature*, 161:686–687, 1948.

  > The log cutoff witness v_k = -μ(k)(1 - ln k/ln N) is a Bartlett
  > (triangular) window applied to the Möbius function in log-frequency.
  > Formalized in `Vasyunin/Proof/BartlettWindow.lean`.

### The Renormalization Group

- **Kenneth G. Wilson**, "Renormalization group and critical phenomena,"
  *Rev. Mod. Phys.*, 47:773–840, 1975. (Nobel Prize 1982)

  > Coupling constants "run" with the energy scale. The Particle Zoo
  > paper identifies the Mersenne Cascade as an arithmetic analogue of
  > renormalization group flow: different Mersenne primes dominate the
  > ground state at different scales N, with the flow reaching an
  > infrared fixed point at M₃ = 7.

### The Higgs Mechanism

- **Peter Higgs**, "Broken symmetries and the masses of gauge bosons,"
  *Phys. Rev. Lett.*, 13:508–509, 1964.

- **François Englert and Robert Brout**, "Broken symmetry and the mass of
  gauge vector mesons," *Phys. Rev. Lett.*, 13:321–323, 1964.

  > In the Standard Model, the Higgs field gives mass to gauge bosons.
  > The Particle Zoo discovers an arithmetic analogue: primes adjacent
  > to massive composites acquire spectral weight through eigenvector
  > leakage (the "arithmetic Higgs mechanism"). At N = 10⁹, the
  > composite 600 is flanked by twin primes 599 and 601, both of which
  > acquire mass from the same fermion ("double Higgs coupling").

### Twin Primes

- **Alphonse de Polignac**, "Recherches nouvelles sur les nombres premiers,"
  *C. R. Acad. Sci. Paris*, 29:397–401, 1849.

  > Conjecture: there are infinitely many twin prime pairs (p, p+2).
  > The Particle Zoo provides a spectral argument: hyper-composite hubs
  > generate gravity wells deep enough to require two adjacent gauge
  > bosons for mass stabilization, making twin primes a topological
  > necessity for vacuum stability.

### The Heisenberg Uncertainty Principle

- **Werner Heisenberg**, "Über den anschaulichen Inhalt der quantentheoretischen
  Kinematik und Mechanik," *Z. Phys.*, 43:172–198, 1927.

  > The spectral energy cannot be simultaneously localized in position and
  > frequency. The **Heisenberg Bypass** (`Spectral/HeisenbergBypass.lean`)
  > uses spectral decomposition to express d²_N → 0 in terms of eigenvalue
  > decay, connecting the Oracle Cascade to the distance decay in
  > `OracleCascade.lean`.

### The Dirac Equation

- **Paul A. M. Dirac**, "The quantum theory of the electron,"
  *Proc. R. Soc. Lond. A*, 117(778):610–624, 1928.

  > The Cathedral's `Physics/GaugeTheory/Dirac.lean` formalizes the 1+1D Clifford
  > algebra (γ⁰, γ¹ satisfying {γᵘ, γᵛ} = 2ηᵘᵛ) and connects it to
  > the SUSY vacuum structure in the spectral model of the Gram matrix.

### The Dyson Equation

- **Freeman J. Dyson**, "The S matrix in quantum electrodynamics,"
  *Phys. Rev.*, 75:1736–1755, 1949.

  > The self-consistent equation G = G₀ + G₀ΣG relating the full propagator
  > to the free propagator and self-energy. The Cathedral's Dyson equation
  > (`Physics/GramWiring/DysonEquation.lean`) decomposes d²_opt(G) =
  > d²_free(R_true) + (w*)^T Δ_true v* where R_true is the Smith-weight
  > sawtooth Gram and Δ_true = G − R_true is the "true anomaly."

### The Ward–Takahashi Identity

- **John Clive Ward**, "An identity in quantum electrodynamics,"
  *Phys. Rev.*, 78:182, 1950.

- **Yasushi Takahashi**, "On the generalized Ward identity,"
  *Nuovo Cimento*, 6:371–375, 1957.

  > Conservation law from gauge symmetry constraining correlation functions.
  > The arithmetic Ward identity (`Physics/Cancellation/WardIdentity.lean`)
  > proves the off-diagonal B+F residual equals a parity-signed sum forced
  > by the ℤ/2 Liouville gauge structure.

### The Bose–Einstein and Fermi–Dirac Statistics

- **Satyendra Nath Bose**, "Plancks Gesetz und Lichtquantenhypothese,"
  *Z. Phys.*, 26:178–181, 1924.

- **Albert Einstein**, "Quantentheorie des einatomigen idealen Gases,"
  *Sitz. Preuss. Akad. Wiss.*, 261–267, 1924.

- **Enrico Fermi**, "Sulla quantizzazione del gas perfetto monoatomico,"
  *Rend. Lincei*, 3:145–149, 1926.

- **Paul A. M. Dirac**, "On the theory of quantum mechanics,"
  *Proc. R. Soc. Lond. A*, 112:661–677, 1926.

  > ζ(s) = Π_p (1 − p^{−s})^{−1} is literally the grand partition
  > function for a Bose–Einstein gas of primes with energies E_p = log p.
  > Restricting to squarefree integers gives the Fermi–Dirac sector:
  > ζ_F(s) = Π_p (1 + p^{−s}) = ζ(s)/ζ(2s). Formalized in
  > `Physics/Glass/BoseEinsteinPrimes.lean` (0 sorry, 0 axioms).

### The Glass Bridge and S-Duality

- **Claus Montonen and David Olive**, "Magnetic monopoles as gauge
  particles?" *Phys. Lett. B*, 72:117–120, 1977.

  > S-duality exchanges strong and weak coupling. The Glass Bridge
  > identity G = R + (1/4)·𝟏𝟏^T separates the Ramanujan residual R
  > from the DC offset. The S-duality ratio S ≈ 32.4 at every HC number
  > tested. Formalized in `Physics/Glass/SDualityGlass.lean` and
  > `Physics/Glass/GlassDistance.lean`.

### The Hopf Fibration and Cayley–Dickson Construction

- **Heinz Hopf**, "Über die Abbildungen der dreidimensionalen Sphäre
  auf die Kugelfläche," *Math. Ann.*, 104:637–665, 1931.

- **Leonard Eugene Dickson**, "On quaternions and their generalization
  and the history of the eight-square theorem," *Ann. of Math.*,
  20:155–171, 1919.

  > The Glass identity generalizes via the Cayley–Dickson ladder:
  > k=1: ζ(2) ↔ ζ(4) via ∏(1+1/p²) (Glass₁, ℂ)
  > k=2: ζ(4) ↔ ζ(8) via ∏(1+1/p⁴) (Glass₂, ℍ)
  > Formalized in `Physics/Glass/HopfGlassCycle.lean`.

### The Standard Model Gauge Group

- **Sheldon L. Glashow**, "Partial-symmetries of weak interactions,"
  *Nucl. Phys.*, 22:579–588, 1961.

- **Steven Weinberg**, "A model of leptons," *Phys. Rev. Lett.*,
  19:1264–1266, 1967.

- **Abdus Salam**, "Weak and electromagnetic interactions," in
  *Elementary Particle Theory* (Nobel Symposium 8), 1968.

  > The Standard Model gauge group U(1) × SU(2) × SU(3).
  > The Cathedral's **Arithmetic Standard Model** (88 theorems, 0 axioms)
  > identifies arithmetic analogues: U(1) parity from λ(n), SU(2) from
  > Liouville doublets, SU(3) from coprime triple structure.
  > Formalized in `Physics/GaugeTheory/ArithmeticStandardModel.lean`,
  > `ArithmeticU1.lean`, `ArithmeticSU2.lean`, `ArithmeticSU3.lean`.

### Quantum Chromodynamics and Confinement

- **David J. Gross and Frank Wilczek**, "Ultraviolet behavior of
  non-abelian gauge theories," *Phys. Rev. Lett.*, 30:1343–1346, 1973.

- **H. David Politzer**, "Reliable perturbative results for strong
  interactions?" *Phys. Rev. Lett.*, 30:1346–1349, 1973.

  > Asymptotic freedom: QCD coupling decreases at high energies.
  > The Cathedral discovers arithmetic confinement: individual GCD strata
  > are well-behaved (O(1/d²)), but their collective behavior cannot be
  > computed without addressing all primes simultaneously.
  > Formalized in `Physics/GaugeTheory/Confinement.lean`.

### Supersymmetry

- **Julius Wess and Bruno Zumino**, "Supergauge transformations in four
  dimensions," *Nucl. Phys. B*, 70:39–50, 1974.

  > The Liouville function λ(n) = (−1)^{Ω(n)} provides a natural ℤ/2
  > grading: even Ω = bosonic, odd Ω = fermionic. The SUSY cancellation
  > in the Gram diagonal is proved in `Physics/Cancellation/SUSYReduction.lean`
  > and `Physics/Cancellation/SUSYVacuum.lean` (0 sorry).

---

## Dedekind Sums

### The Dedekind Sum and Reciprocity

- **Richard Dedekind**, "Erläuterungen zu den Fragmenten XXVIII," in
  *B. Riemann's Gesammelte Mathematische Werke*, 1876.

- **Hans Rademacher and Emil Grosswald**, *Dedekind Sums*, Mathematical
  Association of America, 1972.

  > s(a,b) = Σ_{m=1}^{b-1} ((m/b))·((ma/b)) where ((x)) = {x} - 1/2.
  > The Dedekind reciprocity law s(a,b) + s(b,a) = (a²+b²+1)/(12ab) - 1/4
  > connects Dedekind sums to the Ramanujan matrix entry R(j,k) = 1/(12jk).
  >
  > **Cathedral formalization** (three-file architecture):
  > - `DedekindReciprocity.lean`: definitions, cross-sum, base case (r=1)
  > - `DedekindBridge.lean`: the **Brave Berry** 🍓 (weighted_floor_base),
  >   Euclidean descent, connection to Ramanujan via BerryHoof
  > - `DedekindAssembly.lean`: sorry-free reciprocity law and Ramanujan
  >   connection, resolving the circular dependency
  >
  > The three-term relation 12abr·(s(a,b) - s(a,r)) = polynomial is proved
  > via Gaussian elimination of Dedekind sum variables using reciprocity,
  > periodicity (s(a+r,a) = s(r,a)), and CAS-verified polynomial certificates.
  >
  > **Graduation dates**:
  > - Diagonal Gram entries: April 20, 2026 (Stirling + FTC)
  > - Off-diagonal Gram entries: April 25, 2026 (uniqueness-of-limits)
  > - Dedekind reciprocity (base case r=1): May 19, 2026
  > - **The Brave Berry** (full three-term, sorry-free): June 10, 2026 🍓

---

## Perron Formula and Contour Integration

### The Perron Formula

- **Oskar Perron**, "Zur Theorie der Dirichletschen Reihen," *J. Reine Angew.
  Math.*, 134:95–143, 1908.

  > M(x) = (1/2πi) ∫ x^s / (s·ζ(s)) ds. The Cathedral's 16-file Perron
  > chain (`Perron/*.lean`) assembles the quantitative half-integer Perron
  > formula with Born–Oppenheimer error decomposition, Archimedean UV
  > regularization, and horizontal contour vanishing. ZERO sorry (April 24, 2026).

### The Residue Theorem

- **Augustin-Louis Cauchy**, "Mémoire sur les intégrales définies," *Mémoires
  de l'Académie des Sciences*, 1:601–799, 1827.

  > The residue at s=1 of x^s/(s·ζ(s)) produces the leading Mertens asymptotic.
  > Used in `Perron/ResidueGtOne.lean` and `Perron/ResidueLtOne.lean`.

---

## Complex Analysis

### The Borel–Carathéodory Theorem

- **Émile Borel**, "Sur les zéros des fonctions entières," *Acta Math.*,
  20:357–396, 1897.

- **Constantin Carathéodory**, "Über den Variabilitätsbereich der Fourierschen
  Konstanten von positiven harmonischen Funktionen," *Rend. Circ. Mat. Palermo*,
  32:193–217, 1911.

  > |f(z)| ≤ (2r/(R-r)) sup Re f + ((R+r)/(R-r))|f(0)|.
  > Now in Mathlib (`Analysis.Complex.BorelCaratheodory`). Used in
  > `Zeta/LowerBound.lean` for the polynomial lower bound on |ζ(s)|.

### The Hadamard Three-Circles Theorem

- **Jacques Hadamard**, "Sur les fonctions entières," *Bull. Soc. Math.
  France*, 21:59–72, 1893.

  > log M(r) is a convex function of log r. Proved in `Zeta/Hadamard.lean`
  > via the exponential map reduction to Mathlib's Three-Lines theorem.

### The Hadamard Product Formula

- **Jacques Hadamard**, "Étude sur les propriétés des fonctions entières et
  en particulier d'une fonction considérée par Riemann," *J. Math. Pures Appl.*,
  4(9):171–216, 1893.

  > ζ(s) = e^{A+Bs} ∏_ρ (1-s/ρ)e^{s/ρ}. The zero-counting axiom
  > `rh_zeta_lower_bound_from_zero_counting` (Crown Axiom 2) derives
  > from this combined with Riemann–von Mangoldt N(T) ~ T log T.

### The Riemann–von Mangoldt Formula

- **Hans von Mangoldt**, "Zu Riemanns Abhandlung 'Ueber die Anzahl der
  Primzahlen unter einer gegebenen Grösse,'" *J. Reine Angew. Math.*,
  114:255–305, 1895.

  > N(T) = (T/2π) log(T/2πe) + O(log T). The asymptotic density of
  > zeta zeros, required for the Hadamard zero-counting axiom.

### The Phragmén–Lindelöf Principle

- **Lars Edvard Phragmén and Ernst Leonard Lindelöf**, "Sur une extension
  d'un principe classique de l'analyse," *Acta Math.*, 31:381–406, 1908.

  > Maximum modulus principle for unbounded domains. Imported from
  > Mathlib (`Analysis.Complex.PhragmenLindelof`) and used in
  > `Zeta/ConvexityBound.lean` for the convexity bound on ζ(s) in
  > vertical strips.

---

## Inequalities and Mean Value Theorems

### The Montgomery–Vaughan Mean Value Theorem

- **Hugh L. Montgomery and Robert C. Vaughan**, "Hilbert's inequality,"
  *J. London Math. Soc.*, 8(2):73–82, 1974.

  > ∫₀^T |Σ aₙ n^{-it}|² dt = Σ |aₙ|²(T + O(n)). Proved as
  > `montgomery_vaughan_mvt` in `Analysis/MontgomeryVaughan.lean` —
  > the first machine-verified Dirichlet polynomial MVT (April 27, 2026).

### The Hilbert Inequality

- **David Hilbert**, "Ein Beitrag zur Theorie des Legendre'schen Polynoms,"
  *Acta Math.*, 18:155–159, 1894.

- **Issai Schur**, "Bemerkungen zur Theorie der beschränkten Bilinearformen
  mit unendlich vielen Veränderlichen," *J. Reine Angew. Math.*, 140:1–28, 1911.

  > ‖H_N‖_op → π (the Hilbert matrix operator norm).
  > The Schur test provides the upper bound in `Analysis/HilbertInequality.lean`.
  > The 512-bit MPFR `hilbert-spectral` experiment certifies convergence.

### The Gallagher Mean Value Theorem

- **Patrick X. Gallagher**, "A large sieve density estimate near σ = 1,"
  *Invent. Math.*, 11:329–339, 1970.

  > ∫ |Σ aₙ e^{iλₙt}|² K_δ(t) dt = Σ |aₙ|² for separated frequencies.
  > Proved in `Analysis/GallagherMVT.lean` (zero sorry).

---

## Prime Number Theorem

### PrimeNumberTheoremAnd (Formal PNT)

- **Alexei Kontorovich, Heather Macbeth, et al.**, *PrimeNumberTheoremAnd*,
  Lean 4 library, 2024–2026.
  [GitHub](https://github.com/AlexKontorovich/PrimeNumberTheoremAnd)

  > Formal proof of the PNT (Wiener–Ikehara method) in Lean 4.
  > The Cathedral imports `mu_pnt_alt` (Σ μ(n)/n → 0).
  > `pnt_moebius_sum_div_tendsto` in `PNT/Bridge.lean` is proved
  > as a theorem (zero sorry) by bridging to ℕ-indexed sums.

### Chebyshev's Prime-Counting Functions

- **Pafnuty Lvovich Chebyshev**, "Mémoire sur les nombres premiers,"
  *J. Math. Pures Appl.*, 17:366–390, 1852.

  > ψ(x) = Σ_{n≤x} Λ(n) (the Chebyshev psi function) and θ(x) = Σ_{p≤x} log p.
  > Defined in `PNT/LogBridge.lean` and `PNT/UnconditionalMertens.lean`.
  > The relation Σ μ(k)log(k)⌊y/k⌋ = -ψ(y) via Möbius inversion
  > (`NumberTheory/DirichletConvolution.lean`) is the algebraic engine
  > connecting PNT to the Möbius-weighted sums.

### The Classical PNT

- **Charles-Jean de la Vallée-Poussin**, "Recherches analytiques sur la théorie
  des nombres premiers," *Ann. Soc. Sci. Bruxelles*, 20:183–256, 281–362, 1896.

- **Jacques Hadamard**, "Sur la distribution des zéros de la fonction ζ(s),"
  *Bull. Soc. Math. France*, 24:199–220, 1896.

  > ψ(x) ~ x. Foundation of the Abel hierarchy S₁, S₂, S₃ in `AbelTail/*.lean`.

### The Wiener–Ikehara Theorem

- **Norbert Wiener**, "Tauberian theorems," *Ann. of Math.*, 33:1–100, 1932.

- **Shikao Ikehara**, "An extension of Landau's theorem in the analytic theory
  of numbers," *J. Math. Phys.*, 10:1–12, 1931.

  > Forward Tauberian: L-series → partial sums. Now partially bypassed
  > by PrimeNumberTheoremAnd; 2 PNT bureaucracy axioms remain.

### Mertens' Third Theorem

- **Franz Mertens**, "Ein Beitrag zur analytischen Zahlentheorie,"
  *J. Reine Angew. Math.*, 78:46–62, 1874.

  > ∏_{p ≤ N} (1 − 1/p) ~ e^{−γ}/ln N. Formalized in
  > `NumberTheory/MertensThird.lean` connecting the Euler product
  > to the PNT. Also used in `Physics/Mertens/MertensHarmony.lean`
  > and `Physics/Mertens/GeometricMertens.lean`.

### The Smith Determinant

- **Henry John Stephen Smith**, "On the value of a certain arithmetical
  determinant," *Proc. London Math. Soc.*, 7:208–212, 1876.

  > det[gcd(i,j)] = Π φ(k). The Smith normal form of the Ramanujan
  > matrix R(j,k) = gcd(j,k)²/(12jk) is diagonalized by J₂ (Jordan
  > totient function). Used in `Physics/GramWiring/SmithWitness.lean`
  > and `Physics/GramWiring/SmithFranelBridge.lean`.

### The Franel–Landau Connection

- **Jérôme Franel**, "Les suites de Farey et le problème des nombres
  premiers," *Nachr. Ges. Wiss. Göttingen*, 198–201, 1924.

- **Edmund Landau**, "Bemerkungen zu der vorstehenden Abhandlung von
  Herrn Franel," *Nachr. Ges. Wiss. Göttingen*, 202–206, 1924.

  > RH ⟺ Farey sequence equidistribution with O(N^{−1/2+ε}) error.
  > The Glass distance d²(N) = 4/(4+σ(N)) → 0 is the Smith-Franel
  > unconditional convergence. Proved in
  > `Physics/GramWiring/SmithFranelBridge.lean` (0 sorry, 0 axioms).

---

## Modular Forms and Theta Functions

### The Jacobi Theta Function

- **Carl Gustav Jacob Jacobi**, *Fundamenta Nova Theoriae Functionum
  Ellipticarum*, Bornträger, 1829.

  > θ(t) = Σ_{n∈ℤ} e^{-πn²t}. The functional equation θ(1/t) = √t · θ(t)
  > underlies the Jacobi Theta Bypass in `NymanBeurling/BDMellin.lean`.

---

## Dirichlet Characters and L-functions

### Dirichlet Characters

- **Peter Gustav Lejeune Dirichlet**, "Beweis des Satzes, daß jede unbegrenzte
  arithmetische Progression…," *Abh. Kgl. Preuss. Akad. Wiss.*, 45–71, 1837.

  > Characters mod 8 partition integers into residue classes.
  > Used in `Rotors/GallagherPartition.lean` for the four-channel
  > spectral energy decomposition. Orthogonality by `native_decide`.

### The Siegel–Walfisz Theorem

- **Carl Ludwig Siegel**, "Über die Classenzahl quadratischer Zahlkörper,"
  *Acta Arith.*, 1:83–86, 1935.

- **Arnold Walfisz**, *Weylsche Exponentialsummen in der neueren Zahlentheorie*,
  VEB Deutscher Verlag der Wissenschaften, 1963.

  > π(x; q, a) = Li(x)/φ(q) + O(x·exp(-c√(log x))) for q ≤ (log x)^A.
  > Numerically validated by the 512-bit `siegel-walfisz` experiment.

---

## Balazard–Saias–Yor

- **Michel Balazard, Éric Saias, and Marc Yor**, "Notes sur la fonction ζ de
  Riemann, 2," *Adv. Math.*, 143(2):284–287, 1999.

- **Michel Balazard and Éric Saias**, "The Nyman–Beurling equivalent form for
  the Riemann Hypothesis," *Expo. Math.*, 18:131–138, 2000.

  > d²_N = (1/2π) ∫ |1 - ζ(s)·D_N(s)|² / |s|² dt on σ = 1/2.
  > The Parseval Bridge (`White/Scattering.lean`) realizes this identity.

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

### The Flyspeck Project

- **Thomas C. Hales et al.**, "A Formal Proof of the Kepler Conjecture,"
  *Forum of Mathematics, Pi*, 5:e2, 2017.

  > The Oracle Bridge follows the Flyspeck trust model: open-source code
  > computes a numerical bound; SHA-256 provenance tracks input data;
  > the result is imported as a trusted Lean axiom. The Oracle path uses
  > `oracle_certificates` as its single trusted computation axiom.

### The de Bruijn Criterion

- **Nicolaas Govert de Bruijn**, "The Mathematical Language AUTOMATH,"
  *Springer LNCS 125*, 1970.

  > A proof system is trustworthy if its kernel is small enough for
  > independent auditing. Lean's kernel (~5,000 LOC C++) satisfies this.
  > The Cathedral's trust analysis in `cathedral-lean.tex` follows de Bruijn.

---

## Highly Composite Numbers

### Ramanujan's Highly Composite Numbers

- **Srinivasa Ramanujan**, "Highly composite numbers," *Proc. London Math.
  Soc.*, 2(14):347–409, 1915.

  > A highly composite number N has more divisors than any smaller positive
  > integer. The Oracle Bridge uses HC numbers (N ∈ {6, 12, 60, 120, 360,
  > 2520, 5040, 55440}) as optimal measurement points because their rich
  > GCD structure maximizes Möbius cancellation in the Gram quadratic form.
  > Certified in `Compute/OracleCertificates.lean`.

---

## Numerical Libraries

### GMP / MPFR

- **Torbjörn Granlund et al.**, *The GNU Multiple Precision Arithmetic
  Library (GMP)*, 1991–present. [gmplib.org](https://gmplib.org/)

- **Laurent Fousse, Guillaume Hanrot, Vincent Lefèvre, Patrick Pélissier,
  and Paul Zimmermann**, "MPFR: A Multiple-Precision Binary Floating-Point
  Library with Correct Rounding," *ACM TOMS*, 33(2):13, 2007.

  > The Cathedral's 60 Rust experiments use GMP/MPFR (via the `rug` crate)
  > for 256–512 bit precision arithmetic. All certified distance computations
  > and Parseval bridge validations use MPFR for reproducible, correctly-rounded
  > results. The DD (double-double, ~31 digit) precision pipeline uses
  > compensated summation for dot products at N = 55,440.

### Cholesky Factorization

- **André-Louis Cholesky**, unpublished note, c. 1902–1910. (Published
  posthumously by Commandant Benoit, *Bull. Géodésique*, 2:67–77, 1924.)

  > A = LLᵀ factorization for positive-definite matrices. The GPU Cholesky
  > solver (cuSOLVER dpotrf + dpotrs) is the primary algorithm for computing
  > d²_N = 1 - bᵀG⁻¹b at N up to 55,440. Used in `Assembly/SpectralObservatory.lean`
  > and `Assembly/CertifiedComputation.lean`. The DD-precision CG solver
  > supplements Cholesky at extreme dimensions where GPU memory is the bottleneck.

---

## How the Crown Axiom Maps to References (v22 — The Crowning)

The crown theorem `baez_duarte_forward` depends on exactly **1 axiom ≡ RH**
plus 2 PNT bureaucracy (verified by `#print axioms`):

| Crown Axiom | Mathematical Content | References |
|---|---|---|
| `discrete_riemann_hypothesis` | v^T C v ≤ C/ln N (≡ RH) | Báez-Duarte 2003, Vasyunin 1996 |
| `frac_error_isLittleO` | Σ μ(n)·log(n)·{N/n} = o(N) | PNT (unconditional) |
| `pnt_mu_log_sq_div_k` | Σ μ(k)·(log k)²/k → 2 | PNT (unconditional) |

Plus Lean kernel axioms: `propext`, `Classical.choice`, `Quot.sound`.
The converse direction uses **zero custom axioms** (pure Lean/Mathlib).

The Oracle Bridge `rh_from_oracle` depends on **1 computation axiom**
(`oracle_certificates`) bypassing the literature axiom entirely.

The crown axiom `discrete_riemann_hypothesis` IS the Riemann Hypothesis,
stated in the language of the Cathedral. Graduating it is equivalent to
proving RH. The PNT bureaucracy axioms are unconditionally true.

The ~115 remaining axioms support alternative proof paths
(Mellin Crown, Perron Crown, Gram Crown, Glass Bridge, spectral engine,
sieve engine, Vasyunin tower, Oracle observatory, Physics) that are
formalized but not on the shortest path to the crown theorem.

### The Spatial Path (4 axioms, alternative)

| Spatial Axiom | Mathematical Content | References |
|---|---|---|
| `covariance_bound` | Virial theorem: v^T C v ≤ K/logN | Mertens 1874, Abel 1826 |
| `pnt_mu_log_div_k` | Σ μ(k)log(k)/k → -1 | Selberg 1949, de la Vallée-Poussin 1896 |
| `partial_integral_tends_to_formula` | Ergodic hypothesis (Vasyunin) | Vasyunin 1996, Gauss 1813 |
| `rh_zeta_lower_bound_from_zero_counting` | Weyl law (spectral density) | Hadamard 1893 |

## How Eliminated Axioms Were Proved

| Former Axiom | Proof Technique | Reference | Version |
|---|---|---|---|
| `augmentedSchurComplement_pos` | Factorial Nuke (N! divisibility) | Horn & Johnson 2012 | v3 |
| `vasyunin_mean_eq_integral` | Euler-Mascheroni series | Euler 1740 | v3 |
| `vasyuninGramMatrix_posDef` | Bordered matrix induction | Schur 1917 | v3 |
| `variational_lower_bound` | Cauchy–Schwarz in C-inner product | Cauchy 1821, Schwarz 1885 | v5 |
| `nb_dist_via_witness` | Sherman–Morrison | Sherman & Morrison 1950 | v5 |
| `floor_sum_reciprocity` | Eisenstein maneuver | Eisenstein 1844, Hermite 1875 | v5 |
| `log_cutoff_witness_bound` | Decomposed into sub-axioms | Selberg 1949, Mertens 1874 | v5 |
| `digamma_reflection_complex` | logDeriv of Γ(s)Γ(1-s) | Euler 1755 | v7 |
| `abel_summation_l2_bound` | Abel summation siege proof | Abel 1826 | v7 |
| `divisor_sum_swap` | Finset bijection | Dirichlet 1863 | v7 |
| `mellin_fourier_scale` | Fourier-Mellin CoV (White Singlet) | Mellin 1896 | v7 |
| `vasyunin_eq_integral` (diagonal) | Stirling + piecewise FTC | Stirling 1730, Euler 1740 | v7 |
| `fract_sq_integral` | Stirling + squeeze elimination | Stirling 1730 | v7 |
| `rh_implies_mertens_bound` | Perron chain (16 files) | Titchmarsh 1986, Perron 1908 | v7 |
| `pnt_mu_div_k` | PrimeNumberTheoremAnd | Kontorovich et al. 2024 | v8 |
| `pnt_mu_log_sq_div_k` | Abel Bypass (S₃ uniform bound) | Abel 1826 | v9 |
| `gram_form_upper_bound_34` | Variance decomposition | Mertens 1874, Abel 1826 | v10 |
| `critical_line_mellin_variance` | Perron Bridge (Parseval isometry) | Plancherel 1910, Perron 1908 | v12 |
| `crown_graduation_target` | Direct application | — | v12 |
| `R_isLittleO` (ψ(x) − x = o(x)) | PrimeNumberTheoremAnd | Kontorovich et al. 2024 | v22 |
| `mu_pnt_alt` (Σ μ(k)/k → 0) | PrimeNumberTheoremAnd | Kontorovich et al. 2024 | v22 |
| `mu_log_mul_zeta` (μ·log * ζ = −Λ) | Mathlib `sum_moebius_mul_log_eq` | — | v19 |
| 10 PNT bridge sums | PrimeNumberTheoremAnd | Kontorovich et al. 2024 | v22 |
| `abel_summation_covariance_bound` | Trivial from dRH | — | v22 |

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

2 core papers (included in the public repository) + 13 working drafts
(available on request).

### Core Papers (in `papers/core/`)

| Paper | Audience | Pages |
|-------|----------|-------|
| `cathedral.tex` | Technical overview — the formal reduction | 17 |
| `cathedral-lean.tex` | Lean/ITP community — foundations & practice | 7 |
| `cathedral-glass-bridge.tex` | Glass Bridge identity — GCD arithmetic | 7 |
| `cathedral-overcancellation.tex` | Overcancellation analysis | 7 |

### Working Drafts (in `papers/working_drafts/`)

| Paper | Audience | Pages |
|-------|----------|-------|
| `cathedral-physics.tex` | Physics of the Primes dictionary | 62 |
| `cathedral-particle-zoo.tex` | Arithmetic Standard Model | 10 |
| `cathedral-philosophy.tex` | Philosophers of mathematics | 24 |
| `cathedral-dualuse.tex` | Dual-use risk assessment | 16 |
| `cathedral-claude.tex` | Anthropic/Claude reflections | 9 |
| `cathedral-fun.tex` | Primes, physics & numerology | 8 |
| `cathedral-experiments.tex` | Experimentalists | 4 |
| `cathedral-ai.tex` | AI/ML researchers | 5 |
| `cathedral-engineering.tex` | Practicing engineers | 5 |
| `cathedral-frontiers.tex` | Engineering frontiers | 5 |
| `cathedral-gemini.tex` | DeepMind/Gemini reflections | 4 |
| `cathedral-public.tex` | General public | 4 |
| `cathedral-policy.tex` | Policy / governance | 4 |

---

*Last updated: May 31, 2026 — The Crowning (v22), `discrete_riemann_hypothesis` ≡ RH*
