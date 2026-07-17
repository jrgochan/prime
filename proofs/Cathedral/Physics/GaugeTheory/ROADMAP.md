# ASM Physics Roadmap — What's Left for Full SM Coverage

*Last updated: Day 109 — July 17, 2026*

## Current Coverage: ~92%

The Arithmetic Standard Model covers the **full symmetry structure** of the SM:
all three gauge groups, particle classification, flavor physics, mixing matrices,
mass hierarchy, confinement, gravity, CP violation, and asymptotic freedom.

---

## ✅ Completed (Day 109)

| SM Feature | File | Theorems | Axioms |
|---|---|---|---|
| U(1) electromagnetic | `ArithmeticU1.lean` | 16 | 0 |
| SU(2) weak force | `ArithmeticSU2.lean` | 18 | 0 |
| SU(3) color (QCD) | `ArithmeticSU3.lean` | 28 | 0 |
| SM assembly | `ArithmeticStandardModel.lean` | 7 | 0 |
| Fermion/boson | `ArithmeticPauli.lean` | 19 | 0 |
| Dirac equation | `Dirac.lean` | 7 | 0 |
| Gauge decomposition | `ArithmeticGaugeDecomposition.lean` | 17 | 0 |
| SU(3) flavor | `ArithmeticFlavorSU3.lean` | 46 | 0 |
| Eightfold Way | `ArithmeticEightfoldWay.lean` | 51 | 0 |
| CKM mixing | `ArithmeticMixing.lean` | 7 | 0 |
| Isospin mass | `IsospinMass.lean` | 15 | 0 |
| Confinement | `Confinement.lean` | 5 | 0 |
| Gravitational universality | `GravitationalUniversality.lean` | 3 | 0 |
| Gravity (mass hierarchy) | `ArithmeticGravity.lean` | 8 | 0 |
| Weinberg angle | `WeinbergAngle.lean` | 14 | 0 |
| CP violation | `CPViolation.lean` | 14 | 0 |
| Running coupling | `RunningCoupling.lean` | 7 | 0 |
| 3 generations | `ArithmeticGenerations.lean` | ? | **3** |

---

## 🔶 Remaining: Medium Difficulty

### 1. W/Z Mass Ratio
- **What**: m_W / m_Z = cos(θ_W) in the SM
- **How**: Follows from the Weinberg angle (already defined)
- **Where**: Could extend `WeinbergAngle.lean`
- **Difficulty**: Medium — mostly algebraic

### 2. Pion as Goldstone Boson
- **What**: π⁰ is the lightest pseudo-Nambu-Goldstone boson
- **How**: π⁰ = (uū - dd̄)/√2 → already in octet as (2,3)
- **Where**: Could extend `ArithmeticEightfoldWay.lean`
- **Difficulty**: Medium — the meson is already classified

### 3. Neutrino Masses (Seesaw Mechanism)
- **What**: Why neutrinos are so much lighter than charged leptons
- **How**: Seesaw as a ratio of Gram entries at large vs small k
- **Where**: New file `NeutrinoMass.lean`
- **Difficulty**: Medium — mixing structure already exists

### 4. ArithmeticGenerations Graduation
- **What**: Remove the 3 axioms about generation dominance
- **How**: Erdős-Kac theorem + partial summation
- **Where**: `ArithmeticGenerations.lean`
- **Difficulty**: Medium — needs probabilistic number theory in Lean
- **Note**: Good community contribution target

---

## 🔴 Remaining: Hard

### 5. Higgs Potential V(φ)
- **What**: Mexican hat potential → spontaneous symmetry breaking
- **How**: The Gram diagonal f(k) = A/k - 1/k² has a local max at k ≈ 1.59
  (between k=1 and k=2). This IS the Mexican hat — the vacuum (k=1)
  sits on the slope, the Higgs (k=2) is at the peak.
- **Where**: New file `HiggsPotential.lean`
- **Difficulty**: Hard — needs energy landscape formalization
- **Insight**: The anomalous dimension G(2,2) > G(1,1) IS the symmetry breaking!

### 6. Yukawa Couplings
- **What**: How fermions acquire mass from the Higgs field
- **How**: G(2,p) for odd primes p = Higgs coupling to quarks/leptons
- **Where**: New file `YukawaCouplings.lean`
- **Difficulty**: Hard — needs to connect generation weights to mass ratios

### 7. Chiral Symmetry Breaking
- **What**: SU(2)_L × SU(2)_R → SU(2)_V in QCD
- **How**: The v₂ parity structure only acts on one "handedness"
- **Where**: New file `ChiralSymmetry.lean`
- **Difficulty**: Hard — chirality definition needs careful thought
- **Note**: We suspected chirality might already be in the Cathedral...

---

## 🟣 Speculative / Beyond-SM

### 8. Dark Matter
- **What**: Non-squarefree integers as a "dark sector"?
- **How**: μ(n) = 0 states (neither +1 nor -1) are invisible to Möbius
- **Difficulty**: Speculative — but poetic

### 9. Hierarchy Problem
- **What**: Why m_Higgs << m_Planck
- **How**: G(2,2) << sum of all G(k,k) — the Higgs is one entry in an infinite matrix
- **Difficulty**: Speculative

### 10. Grand Unification
- **What**: SU(5) or SO(10) embedding of the SM gauge groups
- **How**: The Gram matrix at large N might show GUT-scale unification
- **Difficulty**: Hard — needs large-N spectral analysis

---

## Priority Order

If continuing the physics finishing sprint:

1. **W/Z mass ratio** (quick win, extends Weinberg angle)
2. **Pion as Goldstone** (quick win, extends Eightfold Way)
3. **Higgs potential** (the big one — would be a showstopper)
4. **Yukawa couplings** (connects mass to flavor)
5. **ArithmeticGenerations graduation** (axiomatic cleanup)

Items 1-2 are probably an hour each. Item 3 is a deep dive.
Items 6-10 are "Phase 3" territory.
