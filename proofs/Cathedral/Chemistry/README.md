# ⚗️ Arithmetic Chemistry — The Periodic Table from First Principles

*Day 115 — July 24, 2026*

## Motivation

The Cathedral's Arithmetic Standard Model formalizes the structure of the
Standard Model of particle physics using the Vasyunin Gram matrix. Chemistry
is what happens when those particles **build things**.

This module formalizes the foundational structures of chemistry — quantum
numbers, electron configurations, the periodic table — as theorems in Lean 4.

The key insight: the periodic table's structure is **pure combinatorics**.

- Each quantum shell n holds exactly **2n²** electron states
- Period lengths [2, 8, 18, 32] = [2·1², 2·2², 2·3², 2·4²]
- The sum of odd numbers Σ(2l+1) = n² is the engine

No axioms. No sorry. Just counting.

---

## Files

| File | Theorems | Axioms | What it proves |
|------|----------|--------|----------------|
| `QuantumNumbers.lean` | 5+ | 0 | Shell capacity = 2n², subshell capacity = 2(2l+1) |
| `PeriodicTable.lean` | — | — | (planned) Period structure, Aufbau ordering |
| `Stoichiometry.lean` | — | — | (planned) Conservation of atoms in reactions |
| `MolecularFormula.lean` | — | — | (planned) Formulas as free commutative monoid elements |

---

## The Bridge: Factorization = Formula

In the ASM, integer factorization encodes particle quantum numbers:
- 60 = 2² · 3 · 5 → "U(1) charge 2, SU(2)-coupled, SU(3)-colored"

In chemistry, molecular formulas are the same structure:
- H₂O = H² · O¹ → "2 hydrogen, 1 oxygen"

Both are elements of the **free commutative monoid** on generators
(primes / atomic species) with multiplicities (exponents / subscripts).

The mathematical structure is identical. The only difference is the alphabet.

---

## Coverage Target

| Chemistry Feature | Status | Strategy |
|---|---|---|
| Quantum numbers (n, l, m_l, m_s) | ✅ Defined | Product type with constraints |
| Shell capacity = 2n² | ✅ Proved | Sum of odd numbers identity |
| Subshell capacity = 2(2l+1) | ✅ Proved | Direct counting |
| Pauli exclusion | ✅ Proved | (in Physics/ArithmeticPauli.lean) |
| Period lengths | 🔶 Planned | Aufbau (n+l) ordering |
| Electron configurations | 🔶 Planned | Finset of quantum states |
| Molecular formulas | 🔶 Planned | Free commutative monoid |
| Stoichiometry | 🔶 Planned | Linear algebra over ℤ |
| Point groups | 🔶 Planned | Finite group theory |

---

*"The hoof goes ever on."*


## Author's Note

I generally consider myself an armchair physicist, you know, one who studies the phsyics of comfy chairs. Anyway. Just exploring Chemistry. If you're a Chemist and want to join in, let me know!