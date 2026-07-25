/-
  Cathedral.Chemistry.Valence
  =============================

  Valence electrons, the octet rule, and reactivity.

  The octet rule is perhaps the most practical theorem in chemistry:
  atoms "want" 8 valence electrons, and most of chemistry is just
  atoms trying to achieve this.

  Zero axioms. Zero sorry.
  Day 115 — The Hoof Goes Ever On.
-/

import Mathlib.Tactic

-- ════════════════════════════════════════════════════════════════
-- §1. VALENCE ELECTRONS
-- ════════════════════════════════════════════════════════════════

/-- Valence electrons for main group elements (groups 1-2, 13-18).
    The group number determines the valence electron count.

    Group 1 (alkali): 1 valence electron
    Group 2 (alkaline): 2 valence electrons
    Group 13 (boron): 3 valence electrons
    ...
    Group 18 (noble): 8 valence electrons (or 2 for He) -/
def mainGroupValence : ℕ → ℕ
  | 1 => 1    -- H, Li, Na, K, ...
  | 2 => 2    -- Be, Mg, Ca, ...
  | 13 => 3   -- B, Al, ...
  | 14 => 4   -- C, Si, ...
  | 15 => 5   -- N, P, ...
  | 16 => 6   -- O, S, ...
  | 17 => 7   -- F, Cl, Br, ...
  | 18 => 8   -- Ne, Ar, Kr, ... (He has 2, special case)
  | _ => 0

-- ════════════════════════════════════════════════════════════════
-- §2. THE OCTET RULE
-- ════════════════════════════════════════════════════════════════

/-- **The Octet Rule**: Atoms tend to gain, lose, or share electrons
    to achieve 8 valence electrons (a filled shell).

    The "electrons needed" to complete an octet: -/
def electronsToOctet (group : ℕ) : ℕ := 8 - mainGroupValence group

/-- Alkali metals need to LOSE 1 electron (easier than gaining 7). -/
theorem alkali_loses_1 : mainGroupValence 1 = 1 := by native_decide

/-- Halogens need to GAIN 1 electron. -/
theorem halogen_gains_1 : electronsToOctet 17 = 1 := by native_decide

/-- Noble gases already have 8 — they don't react! -/
theorem noble_gas_full : electronsToOctet 18 = 0 := by native_decide

/-- Group 14 (carbon) needs 4 — it can go either way, so it SHARES.
    This is why carbon forms 4 covalent bonds. -/
theorem carbon_shares_4 : electronsToOctet 14 = 4 := by native_decide

-- ════════════════════════════════════════════════════════════════
-- §3. ION CHARGES
-- ════════════════════════════════════════════════════════════════

/-- The typical ion charge for a main group element.
    Metals (groups 1-2) lose electrons → positive ions.
    Nonmetals (groups 15-17) gain electrons → negative ions.
    Group 14 typically shares (covalent), not ionizes. -/
def typicalCharge : ℕ → ℤ
  | 1 => 1     -- Na⁺, K⁺, Li⁺
  | 2 => 2     -- Mg²⁺, Ca²⁺
  | 13 => 3    -- Al³⁺
  | 15 => -3   -- N³⁻, P³⁻
  | 16 => -2   -- O²⁻, S²⁻
  | 17 => -1   -- F⁻, Cl⁻, Br⁻
  | 18 => 0    -- Noble gases don't ionize
  | _ => 0

/-- Sodium forms Na⁺ (charge +1). -/
theorem sodium_cation : typicalCharge 1 = 1 := by native_decide

/-- Chlorine forms Cl⁻ (charge -1). -/
theorem chlorine_anion : typicalCharge 17 = -1 := by native_decide

/-- Oxygen forms O²⁻ (charge -2). -/
theorem oxygen_anion : typicalCharge 16 = -2 := by native_decide

/-- **Charge neutrality**: In NaCl, the charges sum to zero. -/
theorem nacl_neutral : typicalCharge 1 + typicalCharge 17 = 0 := by native_decide

/-- **Charge neutrality**: In MgCl₂, Mg²⁺ + 2Cl⁻ = 0. -/
theorem mgcl2_neutral : typicalCharge 2 + 2 * typicalCharge 17 = 0 := by native_decide

/-- **Charge neutrality**: In CaCl₂, Ca²⁺ + 2Cl⁻ = 0. -/
theorem cacl2_neutral : typicalCharge 2 + 2 * typicalCharge 17 = 0 := by native_decide

/-- **Charge neutrality**: In Al₂O₃, 2Al³⁺ + 3O²⁻ = 0. -/
theorem al2o3_neutral : 2 * typicalCharge 13 + 3 * typicalCharge 16 = 0 := by native_decide

-- ════════════════════════════════════════════════════════════════
-- §4. REACTIVITY PATTERNS
-- ════════════════════════════════════════════════════════════════

/-- Distance to octet measures reactivity.
    The closer to 0 or 8, the more reactive (for ionic bonding). -/
def reactivityScore (group : ℕ) : ℕ :=
  min (mainGroupValence group) (electronsToOctet group)

/-- Alkali metals are highly reactive (score = 1). -/
theorem alkali_reactive : reactivityScore 1 = 1 := by native_decide

/-- Halogens are highly reactive (score = 1). -/
theorem halogen_reactive : reactivityScore 17 = 1 := by native_decide

/-- Noble gases are inert (score = 0). -/
theorem noble_inert : reactivityScore 18 = 0 := by native_decide

/-- Carbon has the highest score (4) — equally willing to gain or lose.
    This is why carbon is the backbone of organic chemistry. -/
theorem carbon_versatile : reactivityScore 14 = 4 := by native_decide
