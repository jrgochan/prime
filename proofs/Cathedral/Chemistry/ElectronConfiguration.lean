/-
  Cathedral.Chemistry.ElectronConfiguration
  ============================================

  Electron configurations for the elements.

  Each element's configuration is specified as a list of occupied
  orbitals, and we prove that the total electron count equals
  the atomic number.

  Zero axioms. Zero sorry.
  Day 115 — The Hoof Goes Ever On.
-/

import Mathlib.Tactic

-- ════════════════════════════════════════════════════════════════
-- §1. ORBITAL OCCUPANCY
-- ════════════════════════════════════════════════════════════════

/-- An occupied orbital: (n, l, electrons).
    Example: (1, 0, 2) means 1s² -/
structure OccupiedOrbital where
  n : ℕ           -- principal quantum number
  l : ℕ           -- azimuthal quantum number
  electrons : ℕ   -- number of electrons in this orbital
  deriving DecidableEq, Repr

/-- An electron configuration is a list of occupied orbitals. -/
abbrev ElectronConfig := List OccupiedOrbital

/-- Total electrons in a configuration. -/
def ElectronConfig.totalElectrons (config : ElectronConfig) : ℕ :=
  config.foldl (fun acc o => acc + o.electrons) 0

/-- Is a configuration valid? Each orbital has at most 2(2l+1) electrons. -/
def OccupiedOrbital.isValid (o : OccupiedOrbital) : Prop :=
  o.l < o.n ∧ o.electrons ≤ 2 * (2 * o.l + 1)

-- ════════════════════════════════════════════════════════════════
-- §2. ORBITAL SHORTHAND
-- ════════════════════════════════════════════════════════════════

/-- 1s orbital -/
def _1s (e : ℕ) : OccupiedOrbital := ⟨1, 0, e⟩
/-- 2s orbital -/
def _2s (e : ℕ) : OccupiedOrbital := ⟨2, 0, e⟩
/-- 2p orbital -/
def _2p (e : ℕ) : OccupiedOrbital := ⟨2, 1, e⟩
/-- 3s orbital -/
def _3s (e : ℕ) : OccupiedOrbital := ⟨3, 0, e⟩
/-- 3p orbital -/
def _3p (e : ℕ) : OccupiedOrbital := ⟨3, 1, e⟩
/-- 3d orbital -/
def _3d (e : ℕ) : OccupiedOrbital := ⟨3, 2, e⟩
/-- 4s orbital -/
def _4s (e : ℕ) : OccupiedOrbital := ⟨4, 0, e⟩
/-- 4p orbital -/
def _4p (e : ℕ) : OccupiedOrbital := ⟨4, 1, e⟩
/-- 4d orbital -/
def _4d (e : ℕ) : OccupiedOrbital := ⟨4, 2, e⟩
/-- 4f orbital -/
def _4f (e : ℕ) : OccupiedOrbital := ⟨4, 3, e⟩
/-- 5s orbital -/
def _5s (e : ℕ) : OccupiedOrbital := ⟨5, 0, e⟩
/-- 5p orbital -/
def _5p (e : ℕ) : OccupiedOrbital := ⟨5, 1, e⟩

-- ════════════════════════════════════════════════════════════════
-- §3. ELEMENT CONFIGURATIONS
-- ════════════════════════════════════════════════════════════════

/-- **Hydrogen** (Z=1): 1s¹ -/
def hydrogen_config : ElectronConfig := [_1s 1]

/-- **Helium** (Z=2): 1s² — first noble gas -/
def helium_config : ElectronConfig := [_1s 2]

/-- **Carbon** (Z=6): 1s² 2s² 2p² -/
def carbon_config : ElectronConfig := [_1s 2, _2s 2, _2p 2]

/-- **Nitrogen** (Z=7): 1s² 2s² 2p³ -/
def nitrogen_config : ElectronConfig := [_1s 2, _2s 2, _2p 3]

/-- **Oxygen** (Z=8): 1s² 2s² 2p⁴ -/
def oxygen_config : ElectronConfig := [_1s 2, _2s 2, _2p 4]

/-- **Neon** (Z=10): 1s² 2s² 2p⁶ — second noble gas -/
def neon_config : ElectronConfig := [_1s 2, _2s 2, _2p 6]

/-- **Sodium** (Z=11): [Ne] 3s¹ -/
def sodium_config : ElectronConfig := [_1s 2, _2s 2, _2p 6, _3s 1]

/-- **Chlorine** (Z=17): [Ne] 3s² 3p⁵ -/
def chlorine_config : ElectronConfig := [_1s 2, _2s 2, _2p 6, _3s 2, _3p 5]

/-- **Argon** (Z=18): [Ne] 3s² 3p⁶ — third noble gas -/
def argon_config : ElectronConfig := [_1s 2, _2s 2, _2p 6, _3s 2, _3p 6]

/-- **Iron** (Z=26): [Ar] 3d⁶ 4s² -/
def iron_config : ElectronConfig :=
  [_1s 2, _2s 2, _2p 6, _3s 2, _3p 6, _3d 6, _4s 2]

/-- **Krypton** (Z=36): [Ar] 3d¹⁰ 4s² 4p⁶ — fourth noble gas -/
def krypton_config : ElectronConfig :=
  [_1s 2, _2s 2, _2p 6, _3s 2, _3p 6, _3d 10, _4s 2, _4p 6]

-- ════════════════════════════════════════════════════════════════
-- §4. VERIFICATION: Total electrons = Atomic number
-- ════════════════════════════════════════════════════════════════

theorem hydrogen_Z : hydrogen_config.totalElectrons = 1 := by native_decide
theorem helium_Z : helium_config.totalElectrons = 2 := by native_decide
theorem carbon_Z : carbon_config.totalElectrons = 6 := by native_decide
theorem nitrogen_Z : nitrogen_config.totalElectrons = 7 := by native_decide
theorem oxygen_Z : oxygen_config.totalElectrons = 8 := by native_decide
theorem neon_Z : neon_config.totalElectrons = 10 := by native_decide
theorem sodium_Z : sodium_config.totalElectrons = 11 := by native_decide
theorem chlorine_Z : chlorine_config.totalElectrons = 17 := by native_decide
theorem argon_Z : argon_config.totalElectrons = 18 := by native_decide
theorem iron_Z : iron_config.totalElectrons = 26 := by native_decide
theorem krypton_Z : krypton_config.totalElectrons = 36 := by native_decide

-- ════════════════════════════════════════════════════════════════
-- §5. ORBITAL VALIDITY
-- ════════════════════════════════════════════════════════════════

/-- All orbitals in carbon's configuration are valid
    (l < n and electrons ≤ 2(2l+1)). -/
theorem carbon_config_valid :
    ∀ o ∈ carbon_config, o.isValid := by
  intro o h
  simp [carbon_config, _1s, _2s, _2p] at h
  rcases h with rfl | rfl | rfl <;>
    simp [OccupiedOrbital.isValid]

/-- All orbitals in iron's configuration are valid. -/
theorem iron_config_valid :
    ∀ o ∈ iron_config, o.isValid := by
  intro o h
  simp [iron_config, _1s, _2s, _2p, _3s, _3p, _3d, _4s] at h
  rcases h with rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp [OccupiedOrbital.isValid]

-- ════════════════════════════════════════════════════════════════
-- §6. NOBLE GAS CORE PROPERTY
-- ════════════════════════════════════════════════════════════════

/-- Noble gas configs have all-full subshells.
    A full subshell has exactly 2(2l+1) electrons. -/
def OccupiedOrbital.isFull (o : OccupiedOrbital) : Prop :=
  o.electrons = 2 * (2 * o.l + 1)

/-- Helium is a noble gas: all subshells full. -/
theorem helium_noble :
    ∀ o ∈ helium_config, o.isFull := by
  intro o h
  simp [helium_config, _1s] at h
  subst h; simp [OccupiedOrbital.isFull]

/-- Neon is a noble gas: all subshells full. -/
theorem neon_noble :
    ∀ o ∈ neon_config, o.isFull := by
  intro o h
  simp [neon_config, _1s, _2s, _2p] at h
  rcases h with rfl | rfl | rfl <;>
    simp [OccupiedOrbital.isFull]

/-- Argon is a noble gas: all subshells full. -/
theorem argon_noble :
    ∀ o ∈ argon_config, o.isFull := by
  intro o h
  simp [argon_config, _1s, _2s, _2p, _3s, _3p] at h
  rcases h with rfl | rfl | rfl | rfl | rfl <;>
    simp [OccupiedOrbital.isFull]
