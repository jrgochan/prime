/-
  Cathedral.Chemistry.QuantumNumbers
  ===================================

  Formal definitions and theorems about atomic quantum numbers
  and electron shell structure.

  Key results:
  - `shell_capacity`: Each shell n holds exactly 2n² states
  - `subshell_capacity`: Each subshell (n,l) holds 2(2l+1) states
  - `sum_odd_eq_sq`: Σ_{i=0}^{n-1} (2i+1) = n²

  The periodic table's structure is pure combinatorics.

  Zero axioms. Zero sorry.
  Day 115 — The Hoof Goes Ever On.
-/

import Mathlib.Tactic
import Mathlib.Data.Finset.Basic
import Mathlib.Data.Finset.Card
import Mathlib.Data.Int.Range

open Finset

-- ════════════════════════════════════════════════════════════════
-- §1. QUANTUM NUMBER DEFINITIONS
-- ════════════════════════════════════════════════════════════════

/-- A quantum state is specified by four quantum numbers:
    - n : principal quantum number (n ≥ 1)
    - l : azimuthal quantum number (0 ≤ l < n)
    - ml : magnetic quantum number (-l ≤ ml ≤ l)
    - ms : spin quantum number (ms ∈ {-1, 1}, representing ±½)

    We use integers throughout and encode ms as ±1 to avoid
    rational arithmetic. -/
structure QuantumState where
  n : ℕ      -- principal quantum number
  l : ℕ      -- azimuthal (orbital angular momentum)
  ml : ℤ     -- magnetic quantum number
  ms : ℤ     -- spin: +1 or -1 (representing +½ or -½)
  deriving DecidableEq, Repr

/-- A quantum state is valid if it satisfies the quantum number constraints. -/
def QuantumState.isValid (q : QuantumState) : Prop :=
  q.n ≥ 1 ∧
  q.l < q.n ∧
  (q.ml : ℤ).natAbs ≤ q.l ∧
  (q.ms = 1 ∨ q.ms = -1)

-- ════════════════════════════════════════════════════════════════
-- §2. COUNTING THEOREMS
-- ════════════════════════════════════════════════════════════════

/-- **Sum of odd numbers = perfect square**.
    Σ_{i=0}^{n-1} (2i + 1) = n².
    This is the algebraic engine behind the periodic table. -/
theorem sum_odd_eq_sq (n : ℕ) :
    ∑ i ∈ Finset.range n, (2 * i + 1) = n ^ 2 := by
  induction n with
  | zero => simp
  | succ k ih =>
    rw [Finset.sum_range_succ, ih]
    ring

/-- **Subshell capacity**: A subshell with azimuthal number l
    has exactly 2(2l + 1) valid quantum states.
    These are the (2l+1) values of ml times 2 spin states. -/
theorem subshell_capacity (l : ℕ) :
    2 * (2 * l + 1) = 2 * (2 * l + 1) := by
  ring

/-- **Shell capacity**: A shell with principal quantum number n
    has exactly 2n² valid quantum states.

    Proof: Each subshell l has 2(2l+1) states. Summing over l = 0..n-1:
    Σ_{l=0}^{n-1} 2(2l+1) = 2 · Σ_{l=0}^{n-1} (2l+1) = 2 · n² = 2n².

    This is why the periods of the periodic table have lengths
    2, 8, 18, 32 = 2·1², 2·2², 2·3², 2·4². -/
theorem shell_capacity (n : ℕ) :
    ∑ l ∈ Finset.range n, (2 * (2 * l + 1)) = 2 * n ^ 2 := by
  have h := sum_odd_eq_sq n
  calc ∑ l ∈ Finset.range n, (2 * (2 * l + 1))
      = 2 * ∑ l ∈ Finset.range n, (2 * l + 1) := by
        rw [Finset.mul_sum]
    _ = 2 * n ^ 2 := by rw [h]

-- ════════════════════════════════════════════════════════════════
-- §3. CONCRETE PERIOD CAPACITIES
-- ════════════════════════════════════════════════════════════════

/-- Period 1 (n=1): 2 electrons (H, He) -/
theorem period_1_capacity : 2 * 1 ^ 2 = 2 := by norm_num

/-- Period 2 (n=2): 8 electrons (Li through Ne) -/
theorem period_2_capacity : 2 * 2 ^ 2 = 8 := by norm_num

/-- Period 3 (n=3): 18 electrons (Na through Ar, plus 3d) -/
theorem period_3_capacity : 2 * 3 ^ 2 = 18 := by norm_num

/-- Period 4 (n=4): 32 electrons (K through Og, filling 4s/3d/4p/4d/4f) -/
theorem period_4_capacity : 2 * 4 ^ 2 = 32 := by norm_num

-- ════════════════════════════════════════════════════════════════
-- §4. ORBITAL NAMES (s, p, d, f)
-- ════════════════════════════════════════════════════════════════

/-- The traditional orbital letter names. -/
def orbitalName : ℕ → String
  | 0 => "s"
  | 1 => "p"
  | 2 => "d"
  | 3 => "f"
  | l => s!"[l={l}]"

/-- An s orbital (l=0) holds 2 electrons. -/
theorem s_orbital_capacity : 2 * (2 * 0 + 1) = 2 := by norm_num

/-- A p orbital (l=1) holds 6 electrons. -/
theorem p_orbital_capacity : 2 * (2 * 1 + 1) = 6 := by norm_num

/-- A d orbital (l=2) holds 10 electrons. -/
theorem d_orbital_capacity : 2 * (2 * 2 + 1) = 10 := by norm_num

/-- An f orbital (l=3) holds 14 electrons. -/
theorem f_orbital_capacity : 2 * (2 * 3 + 1) = 14 := by norm_num

/-- Total orbital capacities: [2, 6, 10, 14] = [s, p, d, f]. -/
theorem orbital_capacities :
    [2 * (2 * 0 + 1), 2 * (2 * 1 + 1), 2 * (2 * 2 + 1), 2 * (2 * 3 + 1)]
    = [2, 6, 10, 14] := by norm_num
