/-
  Cathedral.Chemistry.BondTheory
  ================================

  Chemical bonding: ionic, covalent, and metallic.

  The type of bond between two atoms is determined by their
  electronegativity difference. This is a decision procedure:
  given two elements, we can compute the bond type.

  Zero axioms. Zero sorry.
  Day 115 — The Hoof Goes Ever On.
-/

import Mathlib.Tactic

-- ════════════════════════════════════════════════════════════════
-- §1. ELECTRONEGATIVITY
-- ════════════════════════════════════════════════════════════════

/-- Pauling electronegativity values (scaled by 100 to avoid rationals).
    Actual values: H=2.20, C=2.55, N=3.04, O=3.44, F=3.98, etc.
    We store 220, 255, 304, 344, 398, etc. -/
def electronegativity : ℕ → ℕ
  | 1 => 220    -- H: 2.20
  | 3 => 98     -- Li: 0.98
  | 6 => 255    -- C: 2.55
  | 7 => 304    -- N: 3.04
  | 8 => 344    -- O: 3.44
  | 9 => 398    -- F: 3.98 (most electronegative!)
  | 11 => 93    -- Na: 0.93
  | 12 => 131   -- Mg: 1.31
  | 17 => 316   -- Cl: 3.16
  | 19 => 82    -- K: 0.82
  | 20 => 100   -- Ca: 1.00
  | 26 => 183   -- Fe: 1.83
  | 35 => 296   -- Br: 2.96
  | _ => 0

-- ════════════════════════════════════════════════════════════════
-- §2. BOND CLASSIFICATION
-- ════════════════════════════════════════════════════════════════

/-- The three primary bond types. -/
inductive BondType where
  | ionic      -- electronegativity difference > 1.7 (170 in our scale)
  | polar      -- 0.4 < difference ≤ 1.7
  | covalent   -- difference ≤ 0.4 (40 in our scale)
  deriving DecidableEq, Repr

/-- Classify bond type from electronegativity difference.
    This is the standard Pauling classification. -/
def classifyBond (diff : ℕ) : BondType :=
  if diff > 170 then BondType.ionic
  else if diff > 40 then BondType.polar
  else BondType.covalent

/-- Electronegativity difference between two elements (absolute value). -/
def enDiff (z₁ z₂ : ℕ) : ℕ :=
  let en₁ := electronegativity z₁
  let en₂ := electronegativity z₂
  if en₁ ≥ en₂ then en₁ - en₂ else en₂ - en₁

/-- Determine the bond type between two elements. -/
def bondType (z₁ z₂ : ℕ) : BondType := classifyBond (enDiff z₁ z₂)

-- ════════════════════════════════════════════════════════════════
-- §3. CONCRETE BOND CLASSIFICATIONS
-- ════════════════════════════════════════════════════════════════

/-- **NaCl has an ionic bond**: ΔEN = |0.93 - 3.16| = 2.23 > 1.7 -/
theorem nacl_ionic : bondType 11 17 = BondType.ionic := by native_decide

/-- **HCl has a polar bond**: ΔEN = |2.20 - 3.16| = 0.96 -/
theorem hcl_polar : bondType 1 17 = BondType.polar := by native_decide

/-- **H₂ has a covalent bond**: ΔEN = 0 (same element!) -/
theorem h2_covalent : bondType 1 1 = BondType.covalent := by native_decide

/-- **O₂ has a covalent bond**: ΔEN = 0 -/
theorem o2_covalent : bondType 8 8 = BondType.covalent := by native_decide

/-- **H₂O has polar bonds**: ΔEN(H,O) = |2.20 - 3.44| = 1.24 -/
theorem water_polar : bondType 1 8 = BondType.polar := by native_decide

/-- **CO₂ has polar bonds**: ΔEN(C,O) = |2.55 - 3.44| = 0.89 -/
theorem co2_polar : bondType 6 8 = BondType.polar := by native_decide

/-- **NaF has an ionic bond**: ΔEN = |0.93 - 3.98| = 3.05 (the most ionic!) -/
theorem naf_ionic : bondType 11 9 = BondType.ionic := by native_decide

/-- **KCl has an ionic bond**: ΔEN = |0.82 - 3.16| = 2.34 -/
theorem kcl_ionic : bondType 19 17 = BondType.ionic := by native_decide

-- ════════════════════════════════════════════════════════════════
-- §4. BOND SYMMETRY AND PROPERTIES
-- ════════════════════════════════════════════════════════════════

/-- **Bond type is symmetric**: the bond A-B is the same as B-A. -/
theorem bond_symmetric (z₁ z₂ : ℕ) :
    bondType z₁ z₂ = bondType z₂ z₁ := by
  simp only [bondType, enDiff, classifyBond]
  split_ifs <;> (first | rfl | omega)

/-- **Same-element bonds are always covalent** (ΔEN = 0). -/
theorem same_element_covalent (z : ℕ) :
    bondType z z = BondType.covalent := by
  unfold bondType enDiff classifyBond
  simp [le_refl]

-- ════════════════════════════════════════════════════════════════
-- §5. FLUORINE: THE MOST ELECTRONEGATIVE ELEMENT
-- ════════════════════════════════════════════════════════════════

/-- Fluorine (Z=9) has the highest electronegativity: 3.98 -/
theorem fluorine_most_electronegative :
    ∀ z ∈ [1, 3, 6, 7, 8, 9, 11, 12, 17, 19, 20, 26, 35],
      electronegativity z ≤ electronegativity 9 := by
  intro z h
  simp at h
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl <;>
    simp [electronegativity]

-- ════════════════════════════════════════════════════════════════
-- §6. THE ELECTRONEGATIVITY ORDERING
-- ════════════════════════════════════════════════════════════════

/-- The classic electronegativity ordering: F > O > Cl > N > C > H -/
theorem en_ordering :
    electronegativity 9 > electronegativity 8 ∧
    electronegativity 8 > electronegativity 17 ∧
    electronegativity 17 > electronegativity 7 ∧
    electronegativity 7 > electronegativity 6 ∧
    electronegativity 6 > electronegativity 1 := by
  native_decide
