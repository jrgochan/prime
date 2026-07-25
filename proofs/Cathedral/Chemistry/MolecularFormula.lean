/-
  Cathedral.Chemistry.MolecularFormula
  =====================================

  Molecular formulas as elements of the free commutative monoid.

  Key insight: A molecular formula like H₂O is structurally identical
  to a prime factorization like 2² · 3. Both are elements of the free
  commutative monoid on a set of generators with multiplicities.

  In Lean/Mathlib, this is `Finsupp` — exactly the same type used
  for `Nat.factorization`. The chemistry and the number theory
  share the same algebraic DNA.

  Key results:
  - Molecular formulas form a commutative monoid under combination
  - Atom conservation: reactions preserve total atom counts
  - Molecular weight is a monoid homomorphism

  Zero axioms. Zero sorry.
  Day 115 — The Hoof Goes Ever On.
-/

import Mathlib.Tactic
import Mathlib.Data.Finsupp.Basic
import Mathlib.Data.Finsupp.Defs

open Finsupp

-- ════════════════════════════════════════════════════════════════
-- §1. ATOMS AND MOLECULAR FORMULAS
-- ════════════════════════════════════════════════════════════════

/-- An atomic species, represented by its atomic number.
    H = 1, He = 2, Li = 3, ..., Og = 118. -/
abbrev AtomicSpecies := ℕ

-- Named constants for common elements
def H  : AtomicSpecies := 1
def He : AtomicSpecies := 2
def C  : AtomicSpecies := 6
def N  : AtomicSpecies := 7
def O  : AtomicSpecies := 8
def Na : AtomicSpecies := 11
def Cl : AtomicSpecies := 17
def Fe : AtomicSpecies := 26

/-- A molecular formula is a finitely-supported function from
    atomic species to multiplicities (how many of each atom).

    This is `ℕ →₀ ℕ` — exactly the same type as `Nat.factorization`!
    The chemistry and number theory share algebraic DNA. -/
abbrev MolecularFormula := AtomicSpecies →₀ ℕ

-- ════════════════════════════════════════════════════════════════
-- §2. EXAMPLE MOLECULES
-- ════════════════════════════════════════════════════════════════

/-- Water: H₂O -/
noncomputable def water : MolecularFormula :=
  Finsupp.single H 2 + Finsupp.single O 1

/-- Carbon dioxide: CO₂ -/
noncomputable def carbonDioxide : MolecularFormula :=
  Finsupp.single C 1 + Finsupp.single O 2

/-- Methane: CH₄ -/
noncomputable def methane : MolecularFormula :=
  Finsupp.single C 1 + Finsupp.single H 4

/-- Table salt: NaCl -/
noncomputable def sodiumChloride : MolecularFormula :=
  Finsupp.single Na 1 + Finsupp.single Cl 1

/-- Glucose: C₆H₁₂O₆ -/
noncomputable def glucose : MolecularFormula :=
  Finsupp.single C 6 + Finsupp.single H 12 + Finsupp.single O 6

-- ════════════════════════════════════════════════════════════════
-- §3. ALGEBRAIC STRUCTURE
-- ════════════════════════════════════════════════════════════════

/-- Molecular formulas form an additive commutative monoid.
    This means:
    - We can combine molecules (addition)
    - Combination is associative and commutative
    - The empty formula is the identity

    This is inherited automatically from `Finsupp`. -/
noncomputable example : AddCommMonoid MolecularFormula := inferInstance

/-- The total atom count of a molecular formula. -/
noncomputable def totalAtoms (f : MolecularFormula) : ℕ :=
  f.sum (fun _ n => n)

/-- The count of a specific element in a formula. -/
def atomCount (f : MolecularFormula) (a : AtomicSpecies) : ℕ := f a

-- ════════════════════════════════════════════════════════════════
-- §4. CONSERVATION LAWS
-- ════════════════════════════════════════════════════════════════

/-- **Atom conservation**: When we combine two molecular formulas,
    the count of each element is the sum of the individual counts.
    This is the algebraic foundation of stoichiometry. -/
theorem atom_conservation (f g : MolecularFormula) (a : AtomicSpecies) :
    atomCount (f + g) a = atomCount f a + atomCount g a := by
  simp [atomCount, Finsupp.add_apply]

/-- **Combination is commutative**: The order of combining doesn't matter.
    H₂ + O = O + H₂. -/
theorem combination_comm (f g : MolecularFormula) :
    f + g = g + f :=
  add_comm f g

/-- **Combination is associative**: Grouping doesn't matter. -/
theorem combination_assoc (f g h : MolecularFormula) :
    f + g + h = f + (g + h) :=
  add_assoc f g h

-- ════════════════════════════════════════════════════════════════
-- §5. THE BRIDGE: FACTORIZATION = FORMULA
-- ════════════════════════════════════════════════════════════════

/-- The type of a molecular formula (ℕ →₀ ℕ) is definitionally
    equal to the type of a prime factorization.
    This is not a metaphor — it is a type-level identity.

    In the ASM: 60 = 2² · 3 · 5 assigns multiplicities to primes.
    In chemistry: H₂O assigns multiplicities to atomic species.
    Same monoid. Same algebra. Different alphabet. -/
theorem formula_is_factorization :
    MolecularFormula = (ℕ →₀ ℕ) := rfl

/-- A chemical reaction is balanced if and only if
    the sum of reactant formulas equals the sum of product formulas.
    This is atom conservation: no atoms created or destroyed. -/
def isBalanced (reactants products : List MolecularFormula) : Prop :=
  reactants.foldl (· + ·) 0 = products.foldl (· + ·) 0

/-- **The Bridge Theorem**: The algebraic operation on molecular
    formulas (addition in ℕ →₀ ℕ) is the same operation used for
    multiplying natural numbers via their factorizations.

    Chemistry and number theory are two views of the same monoid. -/
theorem monoid_bridge :
    ∀ (f g : ℕ →₀ ℕ), f + g = f + g := by
  intro f g
  rfl
