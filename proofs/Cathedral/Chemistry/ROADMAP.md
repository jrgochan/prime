# Chemistry Wing — Gen Chem 101 Formalization Roadmap

> *"I generally consider myself an armchair physicist, you know, one who studies the physics of comfy chairs. Anyway. Just exploring Chemistry."*

## Status: ~60% of Gen Chem 101 Structural Foundations

**Started:** Day 115 (2026-07-24)
**Branch:** `chemistry-foundations`
**Target:** 100% formal verification of General Chemistry I

---

## ✅ Completed

| # | File | Topic | Key Theorems |
|---|---|---|---|
| 1 | `QuantumNumbers.lean` | Atomic Structure | Shell capacity = 2n², orbital capacities [2,6,10,14] |
| 2 | `MolecularFormula.lean` | Molecular Structure | Formulas = factorizations (same `ℕ →₀ ℕ` monoid!) |
| 3 | `PeriodicTable.lean` | Periodic Table | 118 elements, Aufbau order, noble gases, period lengths |
| 4 | `IdealGas.lean` | Gas Laws | PV = nRT, Boyle, Charles, Gay-Lussac, scaling symmetry |
| 5 | `Stoichiometry.lean` | Balanced Equations | 5 reactions verified, Lavoisier conservation, Mr. Ross's Theorem |
| 6 | `ElectronConfiguration.lean` | Electron Configs | 11 elements (H–Kr), orbital validity, noble gas cores |
| 7 | `Valence.lean` | Valence & Octet Rule | Ion charges, charge neutrality (NaCl, MgCl₂, Al₂O₃), reactivity |
| 8 | `BondTheory.lean` | Chemical Bonding | Ionic/polar/covalent classification, electronegativity ordering |

**Total: 8 files. Zero axioms. Zero sorry.**

---

## ❌ Remaining — Gen Chem 101

### Phase 2: Thermodynamics & Equilibrium

#### `Thermodynamics.lean`
- **ΔG = ΔH − TΔS** (the equation that determines whether a reaction happens)
- Hess's Law (enthalpy is path-independent)
- Exothermic vs endothermic classification
- Spontaneity: ΔG < 0 ⟹ spontaneous
- Standard conditions (298 K, 1 atm)
- Concrete examples: combustion of methane, rusting of iron

#### `Equilibrium.lean`
- Equilibrium constant Keq
- Le Chatelier's Principle (qualitative: perturb → system shifts)
- Relationship: ΔG° = −RT ln Keq
- ICE tables as algebraic systems
- Concrete examples: N₂ + 3H₂ ⇌ 2NH₃ (Haber process)

### Phase 3: Acids, Bases, and Solutions

#### `AcidsAndBases.lean`
- pH = −log₁₀[H⁺]
- pOH + pH = 14 (at 25°C)
- Strong acids fully dissociate
- Weak acid equilibrium: Ka
- Henderson-Hasselbalch equation: pH = pKa + log([A⁻]/[HA])
- Buffer systems
- Concrete examples: HCl (strong), CH₃COOH (weak, Ka = 1.8×10⁻⁵)

#### `Solutions.lean`
- Molarity = moles/liter
- Dilution law: M₁V₁ = M₂V₂
- Colligative properties (boiling point elevation, freezing point depression)
- Raoult's Law
- Osmotic pressure: π = MRT

### Phase 4: Kinetics

#### `Kinetics.lean`
- Rate laws: rate = k[A]ⁿ
- Zero/first/second order reactions
- Half-life: t½ = ln(2)/k (first order)
- Arrhenius equation: k = Ae^(−Ea/RT)
- Activation energy
- Catalysts lower Ea (definition + consequences)

### Phase 5: Redox & Electrochemistry

#### `Redox.lean`
- Oxidation states (rules + computation)
- Oxidation = loss of electrons, Reduction = gain
- Half-reaction balancing
- Activity series ordering
- Concrete examples: Zn + Cu²⁺ → Zn²⁺ + Cu

#### `Electrochemistry.lean`
- Nernst equation: E = E° − (RT/nF)ln(Q)
- Standard reduction potentials
- Galvanic vs electrolytic cells
- Faraday's law of electrolysis

### Phase 6: Nuclear Chemistry

#### `NuclearChemistry.lean`
- Radioactive decay types (α, β, γ)
- Mass-energy equivalence: E = mc² (already in Physics!)
- Half-life and decay constant: N(t) = N₀ · e^(−λt)
- Nuclear binding energy
- Mass defect
- Concrete examples: ¹⁴C dating, ²³⁵U fission

---

## 🧬 Beyond Gen Chem: Future Frontiers

### Organic Chemistry
- Functional groups (alcohol, aldehyde, ketone, carboxylic acid, amine, ...)
- IUPAC nomenclature as a decision procedure
- Reaction types (substitution, elimination, addition)
- Chirality and stereochemistry

### Biochemistry / Biology Bridge
- **`DNA.lean`** — Base-pair complementarity (A↔T, G↔C)
- Amino acid structure (20 standard amino acids)
- Protein folding energy landscapes
- Enzyme kinetics (Michaelis-Menten: v = Vmax[S]/(Km + [S]))

---

## Philosophy

> **"Chemistry is physics with more indices."**

Every theorem in this wing is derived from algebra, combinatorics, and the laws already proven in the Physics wing. Chemistry doesn't need new axioms — it needs new notation.

> **"Show your work, or it's a sorry."** — Mr. Ross

> **"It took them only an instant to cut off his head, and one hundred years might not suffice to reproduce its like."** — Lagrange, on Lavoisier

---

*The Hoof Goes Ever On* 🐴⚗️🏛️
