/-
  Cathedral/Analysis/CenteredFractBound.lean

  ## BOUNDED PARTIAL SUMS OF CENTERED FRACTIONAL PARTS

  For coprime a, b with 1 ≤ a < b, the centered fractional parts

      f(m) = {am/b} - (b-1)/(2b)

  have bounded partial sums. This is the key number-theoretic input
  that makes the Dirichlet test applicable to the Vasyunin residual.

  Created: April 25, 2026
  Status: COMPLETE — 8 lemmas/theorems, PROVED, 0 axiom
-/

import Cathedral.Analysis.DirichletTest
import Mathlib.Data.ZMod.Basic
import Mathlib.Algebra.Order.Floor.Semifield

noncomputable section
open Filter Finset BigOperators

namespace Cathedral.Analysis.CenteredFractBound

-- ════════════════════════════════════════════════
-- §1. FRACTIONAL PART = MODULAR ARITHMETIC
-- ════════════════════════════════════════════════

/-- The key identity: Int.fract(a*m/b) = (a*m % b) / b (for naturals). -/
lemma fract_nat_div (a m b : ℕ) (hb : 0 < b) :
    Int.fract ((a:ℝ) * (m:ℝ) / (b:ℝ)) = ((a * m % b : ℕ) : ℝ) / (b:ℝ) := by
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr hb
  rw [show (a:ℝ) * (m:ℝ) = ((a * m : ℕ) : ℝ) from by push_cast; ring]
  -- Decompose: (a*m : ℝ)/b = (a*m%b : ℝ)/b + (a*m/b : ℝ)
  have hdecomp : ((a * m : ℕ) : ℝ) / (b:ℝ) =
      ((a * m % b : ℕ) : ℝ) / (b:ℝ) + ((a * m / b : ℕ) : ℝ) := by
    have h : (b * (a * m / b) + a * m % b : ℕ) = a * m := Nat.div_add_mod (a * m) b
    have hreal : ((a * m : ℕ) : ℝ) =
        ((a * m / b : ℕ) : ℝ) * (b:ℝ) + ((a * m % b : ℕ) : ℝ) := by
      have : ((b * (a * m / b) + a * m % b : ℕ) : ℝ) = ((a * m : ℕ) : ℝ) := by
        exact_mod_cast h
      push_cast at this ⊢; linarith
    rw [hreal]; field_simp; ring
  rw [hdecomp]
  have : ((a * m / b : ℕ) : ℝ) = (((a * m / b : ℕ) : ℤ) : ℝ) := by norm_cast
  rw [this]
  rw [Int.fract_add_intCast]
  exact Int.fract_eq_self.mpr ⟨by positivity,
    (div_lt_one hb_pos).mpr (Nat.cast_lt.mpr (Nat.mod_lt (a * m) hb))⟩

-- ════════════════════════════════════════════════
-- §2. THE PERMUTATION PROPERTY
-- ════════════════════════════════════════════════

/-- For coprime a, b, the map m → a*m % b is injective on {0,...,b-1}.
    Key fact: a*m₁ ≡ a*m₂ (mod b) and gcd(a,b) = 1 implies m₁ ≡ m₂ (mod b). -/
lemma mul_mod_injective_range (a b : ℕ) (_hb : 0 < b) (hcop : Nat.Coprime a b) :
    Set.InjOn (fun m => a * m % b) (Finset.range b : Set ℕ) := by
  intro m₁ hm₁ m₂ hm₂ heq
  simp only [Finset.coe_range, Set.mem_Iio] at hm₁ hm₂
  have hmod : a * m₁ ≡ a * m₂ [MOD b] := heq
  have hgcd : Nat.gcd b a = 1 := (Nat.Coprime.symm hcop)
  have hcancel : m₁ ≡ m₂ [MOD b] :=
    Nat.ModEq.cancel_left_of_coprime hgcd hmod
  exact hcancel.eq_of_lt_of_lt hm₁ hm₂

/-- For coprime a, b, mapping m → a*m % b bijects on {0,...,b-1}. -/
lemma mul_mod_image_range (a b : ℕ) (hb : 0 < b) (hcop : Nat.Coprime a b) :
    (Finset.range b).image (fun m => a * m % b) = Finset.range b := by
  apply Finset.eq_of_subset_of_card_le
  · intro x hx
    simp only [Finset.mem_image] at hx
    obtain ⟨m, _, rfl⟩ := hx
    exact Finset.mem_range.mpr (Nat.mod_lt _ hb)
  · have h := Finset.card_image_of_injOn (mul_mod_injective_range a b hb hcop)
    simp only [Finset.card_range] at h ⊢
    omega

-- ════════════════════════════════════════════════
-- §3. SUM OVER ONE PERIOD
-- ════════════════════════════════════════════════

/-- Gauss sum: Σ_{k=0}^{b-1} k = b*(b-1)/2. -/
lemma gauss_sum_range (b : ℕ) :
    (∑ k ∈ Finset.range b, (k:ℝ)) = (b:ℝ) * ((b:ℝ) - 1) / 2 := by
  induction b with
  | zero => simp
  | succ n ih =>
    rw [Finset.sum_range_succ, ih]
    push_cast; ring

/-- The sum of modular residues over one period equals the Gauss sum. -/
lemma sum_mul_mod_eq (a b : ℕ) (hb : 0 < b) (hcop : Nat.Coprime a b) :
    ∑ m ∈ Finset.range b, ((a * m % b : ℕ) : ℝ) =
    ∑ k ∈ Finset.range b, (k:ℝ) := by
  conv_lhs =>
    rw [show ∑ m ∈ Finset.range b, ((a * m % b : ℕ) : ℝ) =
        ∑ m ∈ (Finset.range b).image (fun m => a * m % b), ((m : ℕ) : ℝ) from by
      rw [Finset.sum_image]; intros m₁ hm₁ m₂ hm₂ heq
      exact mul_mod_injective_range a b hb hcop hm₁ hm₂ heq]
  rw [mul_mod_image_range a b hb hcop]

/-- The centered fractional-part sum over one period is zero. -/
theorem centered_period_sum_zero (a b : ℕ) (hb : 0 < b)
    (hcop : Nat.Coprime a b) :
    ∑ m ∈ Finset.range b,
      (Int.fract ((a:ℝ) * (m:ℝ) / (b:ℝ)) - ((b:ℝ) - 1) / (2 * (b:ℝ))) = 0 := by
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr hb
  have hb_ne : (b:ℝ) ≠ 0 := ne_of_gt hb_pos
  simp_rw [fract_nat_div a _ b hb]
  rw [Finset.sum_sub_distrib]
  -- LHS = (Σ (a*m%b)/b) - Σ (b-1)/(2b)
  have h1 : ∑ x ∈ Finset.range b, ((a * x % b : ℕ) : ℝ) / (b:ℝ) =
      (∑ x ∈ Finset.range b, ((a * x % b : ℕ) : ℝ)) / (b:ℝ) :=
    (Finset.sum_div (Finset.range b) (fun x => ((a * x % b : ℕ) : ℝ)) (b:ℝ)).symm
  rw [h1, sum_mul_mod_eq a b hb hcop, gauss_sum_range]
  rw [Finset.sum_const, Finset.card_range]
  -- b • ((b-1)/(2b)) where • is nsmul
  rw [nsmul_eq_mul]
  field_simp; ring

-- ════════════════════════════════════════════════
-- §4. BOUNDED PARTIAL SUMS (THE CROWN)
-- ════════════════════════════════════════════════

/-- Each centered fractional part has absolute value < 1. -/
lemma centered_fract_abs_lt_one (a m b : ℕ) (hb : 1 ≤ b) :
    |Int.fract ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ)) - ((b:ℝ) - 1) / (2 * (b:ℝ))| < 1 := by
  have hb_pos : (0:ℝ) < (b:ℝ) := Nat.cast_pos.mpr (by omega)
  have h1 := Int.fract_nonneg ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ))
  have h2 := Int.fract_lt_one ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ))
  have h3 : 0 ≤ ((b:ℝ) - 1) / (2 * (b:ℝ)) := by
    apply div_nonneg
    · have hb1 : (1:ℝ) ≤ (b:ℝ) := by exact_mod_cast hb
      linarith
    · positivity
  have h4 : ((b:ℝ) - 1) / (2 * (b:ℝ)) < 1 := by
    rw [div_lt_one (show (0:ℝ) < 2 * (b:ℝ) from by positivity)]
    have hb1 : (1:ℝ) ≤ (b:ℝ) := by exact_mod_cast hb
    nlinarith
  rw [abs_lt]; constructor <;> linarith

/-- **THE THEOREM**: Centered fractional-part partial sums are bounded.

    |Σ_{j=0}^{n-1} ({aj/b} - (b-1)/(2b))| ≤ b    for all n -/
theorem centered_fract_partial_sums_bounded' (a b : ℕ)
    (ha : 1 ≤ a) (hb : 2 ≤ b) (_hab : a < b) (hcop : Nat.Coprime a b) :
    ∀ n : ℕ,
      |DirichletTest.partialSum₀
        (fun m => Int.fract ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ)) - ((b:ℝ) - 1) / (2 * (b:ℝ))) n| ≤ (b:ℝ) := by
  intro n
  simp only [DirichletTest.partialSum₀]
  set f : ℕ → ℝ := fun m =>
    Int.fract ((a:ℝ) * ((m:ℕ):ℝ) / (b:ℝ)) - ((b:ℝ) - 1) / (2 * (b:ℝ))
  have hb_pos : 0 < b := by omega
  -- ── Step 1: f has period b ──
  -- {a(m+b)/b} = {am/b + a} = {am/b} since a ∈ ℤ
  have hperiodic : ∀ m, f (m + b) = f m := by
    intro m
    -- f(m) = {a*m/b} - c, so need {a*(m+b)/b} - c = {a*m/b} - c
    -- which reduces to showing {a*(m+b)/b} = {a*m/b}
    have key : Int.fract ((a:ℝ) * ((↑(m + b) : ℝ)) / (b:ℝ)) =
        Int.fract ((a:ℝ) * (↑m : ℝ) / (b:ℝ)) := by
      have heq : (a:ℝ) * (↑(m + b) : ℝ) / (b:ℝ) = (a:ℝ) * (↑m : ℝ) / (b:ℝ) + ↑(a:ℤ) := by
        push_cast; field_simp
      rw [heq, Int.fract_add_intCast]
    -- f = fract - const, so key implies f(m+b) = f(m)
    exact congr_arg (· - ((b:ℝ) - 1) / (2 * (b:ℝ))) key
  -- ── Step 2: f(k*b + j) = f(j) ──
  have hperiodic_mul : ∀ k j, f (k * b + j) = f j := by
    intro k; induction k with
    | zero => simp
    | succ k ih =>
      intro j
      rw [show (k + 1) * b + j = (k * b + j) + b from by ring]
      rw [hperiodic, ih]
  -- ── Step 3: Sum over one period = 0 ──
  have hperiod_zero : ∑ j ∈ Finset.range b, f j = 0 :=
    centered_period_sum_zero a b hb_pos hcop
  -- ── Step 4: S(q*b) = 0 ──
  have hsum_mult : ∀ k, ∑ j ∈ Finset.range (k * b), f j = 0 := by
    intro k; induction k with
    | zero => simp
    | succ k ih =>
      rw [show (k + 1) * b = k * b + b from by ring, Finset.sum_range_add]
      rw [ih, zero_add]
      have : ∀ j, f (k * b + j) = f j := hperiodic_mul k
      simp_rw [this]
      exact hperiod_zero
  -- ── Step 5: Split n = (n/b)*b + n%b and bound ──
  have hn_eq : n = (n / b) * b + n % b := by
    have h := Nat.div_add_mod n b  -- b * (n / b) + n % b = n
    linarith [mul_comm b (n / b)]
  rw [show n = (n / b) * b + n % b from hn_eq]
  rw [Finset.sum_range_add, hsum_mult (n / b), zero_add]
  -- Bound the remaining n%b < b terms, each with |f| < 1
  have hr_lt : n % b < b := Nat.mod_lt n hb_pos
  calc |∑ j ∈ Finset.range (n % b), f ((n / b) * b + j)|
      ≤ ∑ j ∈ Finset.range (n % b), |f ((n / b) * b + j)| := Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ _j ∈ Finset.range (n % b), (1:ℝ) := by
        apply Finset.sum_le_sum; intro j _
        exact le_of_lt (centered_fract_abs_lt_one a ((n / b) * b + j) b (by omega))
    _ = ((n % b : ℕ) : ℝ) := by
        simp [Finset.card_range]
    _ ≤ (b:ℝ) := by
        exact_mod_cast (Nat.mod_lt n hb_pos).le

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════
-- PROVED (0 axiom):
--   ✅ fract_nat_div                — {am/b} = (am%b)/b
--   ✅ mul_mod_injective_range     — coprime ⇒ injective on range
--   ✅ mul_mod_image_range          — image = range (bijection)
--   ✅ gauss_sum_range              — Σ k = b(b-1)/2
--   ✅ sum_mul_mod_eq               — Σ (am%b) = Σ k
--   ✅ centered_period_sum_zero     — Σ_period (centered fract) = 0
--   ✅ centered_fract_abs_lt_one    — |each term| < 1
--   ✅ centered_fract_partial_sums_bounded' — THE BOUNDED PARTIAL SUMS THEOREM
--
-- Architecture:
--   fract_nat_div → mul_mod perm → Gauss sum → period=0 → |partial sums| ≤ b

end Cathedral.Analysis.CenteredFractBound
