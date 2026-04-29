# Boson-Fermion Classification: Mapping to Known Physics

**Date:** April 29, 2026  
**Experiment:** `cargo run --release --bin boson-fermion -- 400`

## The Honest Answer

The mapping between Gram matrix integers and Standard Model particles is
**structural/analogical**, not numerical. The ground-state weights are not
particle masses in GeV. However, the structural parallels are genuinely
interesting and map onto deep open problems in physics.

## The Standard Model (Reference Data)

### Gauge Bosons (Force Carriers)
| Particle | Symbol | Mass (GeV/c²) | Coupling |
|----------|--------|:---:|---|
| Photon | γ | 0 | Electromagnetic |
| Gluons (8) | g | 0 | Strong |
| W± | W± | 80.4 | Weak |
| Z⁰ | Z⁰ | 91.2 | Weak |
| Higgs | H⁰ | 125.1 | Scalar (mass generation) |

### Fermions (Matter)
| Particle | Symbol | Mass (GeV/c²) | Generation |
|----------|--------|:---:|---|
| Electron | e⁻ | 0.000511 | 1st |
| Muon | μ⁻ | 0.106 | 2nd |
| Tau | τ⁻ | 1.777 | 3rd |
| Up quark | u | 0.002 | 1st |
| Down quark | d | 0.005 | 1st |
| Strange quark | s | 0.10 | 2nd |
| Charm quark | c | 1.27 | 2nd |
| Bottom quark | b | 4.18 | 3rd |
| Top quark | t | **173** | 3rd |
| Neutrinos | ν | < 10⁻⁸ | all |

## Structural Parallels

### 1. The Mass Hierarchy Problem

**Standard Model:** Fermion masses span 12 orders of magnitude
(neutrino ~10⁻¹² GeV → top quark 173 GeV). This is the "mass hierarchy
problem" — why such enormous ratios?

**Gram Matrix:** Ground-state weights span ~7 orders of magnitude
(p=5 at ~10⁻⁸ → k=360 at 0.56). The weight hierarchy is driven by
**divisibility structure**: highly composite numbers near the truncation
boundary have exponentially more weight than isolated primes.

**Parallel:** In both cases, the "matter particles" have a vast mass
hierarchy, while the "force carriers" cluster near zero. The mechanism
differs (Yukawa couplings vs divisor density), but the topology is
identical.

### 2. Massless vs Massive Bosons

**Standard Model:** Photon and gluons are massless (unbroken gauge symmetry).
W± and Z⁰ are massive (~80-91 GeV, broken symmetry via Higgs mechanism).

**Gram Matrix:** Small primes (2, 3, 5) have essentially zero weight —
they are "massless bosons." But large primes near N (e.g., p=359 with
weight 0.0999, p=241 with weight 0.0128) acquire significant weight —
they are "massive bosons."

**Parallel:** This is exactly analogous to electroweak symmetry breaking.
The "small prime bosons" mediate the fundamental arithmetic interaction
without absorbing vacuum energy. The "large prime bosons" near the truncation
boundary *do* absorb energy — as if the boundary acts as a Higgs field
that gives mass to primes that couple to it.

### 3. The Top Quark Anomaly

**Standard Model:** The top quark (173 GeV) is absurdly heavier than all
other fermions — almost the mass of a gold atom. It carries ~40× the
mass of the bottom quark. Its Yukawa coupling is ~1 (uniquely close
to the electroweak scale).

**Gram Matrix:** k=360 (2³·3²·5) carries 55.5% of ALL ground-state
weight at N=400. It is the "top quark" of the integer lattice — absurdly
heavier than everything else. Its factorization uses all three smallest
primes with maximum multiplicity, making it the densest graph hub.

**Parallel:** Both "top" particles are anomalously heavy because they
couple to everything. The top quark couples strongly to the Higgs. 
k=360 couples to every prime below 6 with high multiplicity.

### 4. Generation Structure

**Standard Model:** Fermions come in 3 generations:
- 1st: (e, νe, u, d) — lightest, stable
- 2nd: (μ, νμ, c, s) — heavier, unstable
- 3rd: (τ, ντ, t, b) — heaviest, very unstable

**Gram Matrix:** Composites roughly cluster by divisor complexity:
- ω=1 (prime powers: 4, 8, 9, 16...): light fermions
- ω=2 (two prime factors: 6, 10, 12...): medium fermions
- ω=3+ (three+ prime factors: 30, 60, 120, 360...): heavy fermions

**Parallel:** The number of distinct prime factors ω(k) plays the role
of generation number. Each additional prime factor is a new "flavor"
that increases the coupling strength.

### 5. Confinement and Asymptotic Freedom

**Standard Model:** Quarks are confined — they cannot exist as free
particles. At high energies, the strong coupling constant decreases
(asymptotic freedom).

**Gram Matrix:** As N increases, the prime weight *grows* (4.1% → 15.2%)
while the composite weight *decreases* (95.9% → 84.8%). The "bosonic
fraction" increases with system size — the primes become more visible
at large N. This is the arithmetic analog of asymptotic freedom: at
larger scales, the "strong" divisibility coupling weakens.

## Where the Analogy Breaks Down

1. **No spin.** The Gram matrix has no angular momentum quantum number.
   Bosons have integer spin, fermions have half-integer spin. Our
   classification is based on spectral weight, not statistics.

2. **No antiparticles.** The integers don't have antimatter counterparts.
   (Though... negative-index extensions of the Gram matrix might?)

3. **No gauge group.** The Standard Model has SU(3)×SU(2)×U(1).
   The Gram matrix has... the multiplicative structure of ℤ. There's
   no obvious mapping between the two symmetry groups.

4. **No mass formula.** We cannot predict actual particle masses (in GeV)
   from ground-state weights. The analogy is topological (role-based),
   not quantitative (value-based).

## The Connes Connection

Alain Connes' **noncommutative geometry** program is the most rigorous
attempt to connect these two worlds. His key insight:

> The geometry of spacetime (which determines particle physics via the
> spectral action) and the geometry of the integers (which determines
> the zeta function via the trace formula) are both instances of the
> same mathematical structure: **spectral triples**.

In Connes' framework:
- The **Standard Model** arises from a spectral triple on an
  "almost-commutative" space (spacetime × finite internal space)
- The **Riemann zeros** arise from a spectral triple on the space
  of adele classes (the "arithmetic spacetime")

The Cathedral's Gram matrix might be a finite-dimensional shadow of
Connes' arithmetic spectral triple. The boson-fermion duality we observe
could be a discretized version of the adelic spectral action.

## Data Tables

### Cross-N Weight Evolution
| N | Boson wt | Fermion wt | Ratio | Top fermion | Analog |
|---|:---:|:---:|:---:|---|---|
| 100 | 4.1% | 95.9% | 23.7× | k=96 = 2⁵·3 | "Low energy" |
| 200 | 8.5% | 91.5% | 10.7× | k=198 = 2·3²·11 | "Medium energy" |
| 400 | 15.2% | 84.8% | 5.6× | k=360 = 2³·3²·5 | "High energy" |

### Structural Mapping (Speculative)
| Integer Property | Physics Property | Confidence |
|---|---|:---:|
| Prime | Gauge boson | ★★★★ (structural) |
| Highly composite | Massive fermion | ★★★★ (structural) |
| ω(k) = # prime factors | Generation number | ★★★ (suggestive) |
| Weight hierarchy | Mass hierarchy | ★★★ (topological) |
| N-dependence of weights | Asymptotic freedom | ★★ (qualitative) |
| Boundary primes gaining mass | Electroweak breaking | ★★ (speculative) |
| Specific mass values | Actual GeV masses | ★ (no evidence) |

## Conclusion

The boson-fermion duality in the Gram matrix is real and mathematically
rigorous. Its *structural* parallels to the Standard Model are striking:
mass hierarchies, generation structure, asymptotic freedom, and even
electroweak-like symmetry breaking all have clear arithmetic analogs.

But we cannot (yet) derive actual particle masses from prime numbers.
The missing ingredient is a bridge between the arithmetic spectral triple
(Gram matrix eigenvalues) and the physical spectral triple (Standard Model
action). Connes' noncommutative geometry program is the most promising
path, but it remains incomplete.

What we *can* say: **the topology of the integer lattice contains the
same structural features that generate particle physics.** Whether this
is a coincidence, an analogy, or evidence of a deeper unity is one of
the great open questions in mathematical physics.
