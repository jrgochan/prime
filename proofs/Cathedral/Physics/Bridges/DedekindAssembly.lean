/-
  Cathedral/Physics/Bridges/DedekindAssembly.lean

  # Dedekind Sum Assembly — Resolving the Circular Dependency

  ## Purpose

  This file resolves the file-ordering artifact between DedekindReciprocity.lean
  and DedekindBridge.lean. The three-term relation for r ≥ 2 is proved in
  DedekindBridge.lean (via the Brave Berry 🍓), but DedekindReciprocity.lean
  cannot import DedekindBridge (circular dependency).

  This assembly file imports DedekindBridge (which transitively imports
  DedekindReciprocity) and provides the sorry-free versions of:
  - dedekind_three_term
  - dedekind_sum_expand
  - dedekind_reciprocity_law (the full s(a,b)+s(b,a) formula)
  - dedekind_contains_ramanujan
  - ramanujan_from_dedekind

  ## Architecture

  DedekindReciprocity.lean  ──imports──→  DedekindBridge.lean
   (defs, cross-sum, base)                (Brave Berry, Euclidean descent)
         ↓                                      ↓
         └──────────────→  DedekindAssembly.lean ←──┘
                           (sorry-free three_term,
                            full reciprocity law,
                            Ramanujan connection)
-/

import Cathedral.Physics.Bridges.DedekindBridge

namespace Cathedral.Physics.DedekindBridge

open Finset BigOperators

-- ════════════════════════════════════════════════
-- §1. SORRY-FREE THREE-TERM RELATION
-- ════════════════════════════════════════════════

/-- **THREE-TERM RELATION** (sorry-free assembly):

    12·a·b·r·(s(a,b) - s(a,r)) = r·(a²+b²+1) - b·(a²+r²+1)

    where r = b % a. This is the same statement as
    `dedekind_three_term` in DedekindReciprocity.lean,
    but proved sorry-free by importing from DedekindBridge.lean.

    The proof for r = 1 uses cross-sum expansion.
    The proof for r ≥ 2 uses the Brave Berry 🍓 (weighted_floor_base)
    and Euclidean descent (weighted_floor_step). -/
theorem dedekind_three_term_assembled (a b : ℕ) (ha : 1 < a) (hb : 1 < b)
    (hr : 0 < b % a) (hcop : Nat.Coprime a b) :
    12 * (a : ℝ) * b * ((b % a : ℕ) : ℝ) * (dedekindSum a b - dedekindSum a (b % a)) =
    ((b % a : ℕ) : ℝ) * ((a : ℝ)^2 + (b : ℝ)^2 + 1) -
    (b : ℝ) * ((a : ℝ)^2 + ((b % a : ℕ) : ℝ)^2 + 1) :=
  dedekind_three_term_full a b ha hb hr hcop

-- ════════════════════════════════════════════════
-- §2. RECIPROCITY EXPANSION (sorry-free)
-- ════════════════════════════════════════════════

/-- **Coprime mod positivity**: gcd(a,b)=1 and a ≥ 2 implies b%a > 0. -/
private lemma coprime_mod_pos' (a b : ℕ) (ha : 1 < a) (hcop : Nat.Coprime a b) :
    0 < b % a := by
  apply Nat.pos_of_ne_zero; intro h0
  have h1 : a ∣ Nat.gcd a b := dvd_gcd dvd_rfl (Nat.dvd_of_mod_eq_zero h0)
  rw [hcop] at h1; exact absurd (Nat.le_of_dvd one_pos h1) (by omega)

/-- **RECIPROCITY EXPANSION** (Euclidean induction, sorry-free):

    12·a·b·(s(a,b) + s(b,a)) = a² + b² + 1 - 3ab

    Proved by well-founded induction on a+b using the sorry-free
    three-term relation from DedekindBridge.

    - Periodicity: s(b,a) = s(b%a, a) [dedekindSum_mod]
    - Reduction: three-term relation [dedekind_three_term_assembled]
    - Base case: b%a = 1, using dedekindSum_one_right
    - Inductive step: combine three-term with IH, cancel r = b%a -/
lemma dedekind_sum_expand_assembled (a b : ℕ) (ha : 1 < a) (hb : 1 < b)
    (hcop : Nat.Coprime a b) :
    12 * (a : ℝ) * b * (dedekindSum a b + dedekindSum b a) =
    (a : ℝ) ^ 2 + (b : ℝ) ^ 2 + 1 - 3 * a * b := by
  -- Strong induction on a + b
  suffices key : ∀ n : ℕ, ∀ a b : ℕ, a + b ≤ n → 1 < a → 1 < b → Nat.Coprime a b →
      12 * (a : ℝ) * b * (dedekindSum a b + dedekindSum b a) =
      (a : ℝ) ^ 2 + (b : ℝ) ^ 2 + 1 - 3 * a * b from
    key (a + b) a b le_rfl ha hb hcop
  intro n; induction n using Nat.strongRecOn with
  | ind n ih =>
    intro a b hab ha hb hcop
    -- WLOG b ≥ a: when a > b, swap using symmetry of the statement
    by_cases h_le : a ≤ b
    · -- Case b ≥ a: proceed with Euclidean reduction on b%a
      have hr_pos : 0 < b % a := coprime_mod_pos' a b ha hcop
      have hr_ne : ((b % a : ℕ) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
      have hr_lt_b : b % a < b := lt_of_lt_of_le (Nat.mod_lt b (by omega)) h_le
      -- Step 1: Periodicity s(b,a) = s(b%a, a)
      rw [show dedekindSum b a = dedekindSum (b % a) a from dedekindSum_mod b a ha]
      -- Step 2: Three-term relation (cleared denominators) — SORRY-FREE!
      have h_tt := dedekind_three_term_assembled a b ha hb hr_pos hcop
      by_cases hr1 : b % a = 1
      · -- BASE CASE: b%a = 1
        simp only [hr1, Nat.cast_one] at h_tt ⊢
        have h1 : dedekindSum a 1 = 0 := dedekindSum_one a
        have h2 : dedekindSum 1 a = ((a : ℝ)^2 + 2) / (12 * a) - 1 / 4 :=
          dedekindSum_one_right a ha
        rw [h1] at h_tt; rw [h2]
        have ha_ne : (a : ℝ) ≠ 0 := by positivity
        field_simp; nlinarith
      · -- INDUCTIVE CASE: b%a ≥ 2
        have hr2 : 1 < b % a := by omega
        have hcop' : Nat.Coprime a (b % a) := by
          unfold Nat.Coprime; rw [Nat.gcd_comm, ← Nat.gcd_rec]; exact hcop
        have h_ih := ih (a + b % a) (by omega) a (b % a) (by omega) ha hr2 hcop'
        -- Algebra: multiply IH by b, add three-term, cancel r = b%a
        have h_step : ((b % a : ℕ) : ℝ) * (12 * (a : ℝ) * b *
            (dedekindSum a b + dedekindSum (b % a) a)) =
            ((b % a : ℕ) : ℝ) * ((a : ℝ)^2 + (b : ℝ)^2 + 1 - 3 * a * b) := by
          nlinarith [mul_comm (b : ℝ) (12 * (a : ℝ) * ((b % a : ℕ) : ℝ) *
              (dedekindSum a (b % a) + dedekindSum (b % a) a))]
        exact mul_left_cancel₀ hr_ne h_step
    · -- Case a > b: reduce on the a side instead
      have h_le : b < a := by omega
      -- a > b, so a%b < b, use periodicity on a: s(a,b) = s(a%b, b)
      have ha_pos : 0 < a % b := coprime_mod_pos' b a hb hcop.symm
      have ha_ne : ((a % b : ℕ) : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
      have ha_lt_a : a % b < a := lt_of_lt_of_le (Nat.mod_lt a (by omega)) (le_of_lt h_le)
      rw [show dedekindSum a b = dedekindSum (a % b) b from dedekindSum_mod a b hb]
      have h_tt := dedekind_three_term_assembled b a hb ha
          (coprime_mod_pos' b a hb hcop.symm) hcop.symm
      by_cases ha1 : a % b = 1
      · -- BASE: a%b = 1
        simp only [ha1, Nat.cast_one] at h_tt ⊢
        have h1 : dedekindSum b 1 = 0 := dedekindSum_one b
        have h2 : dedekindSum 1 b = ((b : ℝ)^2 + 2) / (12 * b) - 1 / 4 :=
          dedekindSum_one_right b hb
        rw [h1] at h_tt; rw [h2]
        have hb_ne : (b : ℝ) ≠ 0 := by positivity
        field_simp; nlinarith
      · -- INDUCTIVE: a%b ≥ 2
        have ha2 : 1 < a % b := by omega
        have hcop'' : Nat.Coprime b (a % b) := by
          unfold Nat.Coprime; rw [Nat.gcd_comm, ← Nat.gcd_rec]; exact hcop.symm
        have h_ih := ih (b + a % b) (by omega) b (a % b) (by omega) hb ha2 hcop''
        have h_step : ((a % b : ℕ) : ℝ) * (12 * (a : ℝ) * b *
            (dedekindSum (a % b) b + dedekindSum b a)) =
            ((a % b : ℕ) : ℝ) * ((a : ℝ)^2 + (b : ℝ)^2 + 1 - 3 * a * b) := by
          -- h_tt: 12bar(s(b,a)-s(b,r)) = r(b²+a²+1)-a(b²+r²+1) where r=a%b
          -- h_ih: 12br(s(b,r)+s(r,b)) = b²+r²+1-3br
          -- Need: r*12ab*(s(r,b)+s(b,a)) = r*(a²+b²+1-3ab)
          -- Note s(r,b) = dedekindSum (a%b) b, same as in ih
          nlinarith [mul_comm (a : ℝ) (12 * (b : ℝ) * ((a % b : ℕ) : ℝ) *
              (dedekindSum b (a % b) + dedekindSum (a % b) b))]
        exact mul_left_cancel₀ ha_ne h_step

-- ════════════════════════════════════════════════
-- §3. THE DEDEKIND RECIPROCITY LAW (sorry-free)
-- ════════════════════════════════════════════════

/-- **THE DEDEKIND RECIPROCITY LAW** (sorry-free):

    s(a, b) + s(b, a) = (a² + b² + 1) / (12ab) - 1/4

    for coprime positive integers a, b with a,b ≥ 2.

    PROOF: From dedekind_sum_expand_assembled, dividing by 12ab.

    This is one of the most beautiful identities in number theory.
    It connects the Dedekind sums to the Ramanujan entry:

      1/(12ab) = R(j,k)  when a = j/gcd, b = k/gcd

    REFERENCE: Dedekind (1892), Rademacher & Grosswald (1972)

    GRADUATION DATE: June 10, 2026 — The Brave Berry 🍓 -/
theorem dedekind_reciprocity_assembled (a b : ℕ) (ha : 0 < a) (hb : 0 < b)
    (hcop : Nat.Coprime a b) :
    dedekindSum a b + dedekindSum b a =
    ((a : ℝ) ^ 2 + (b : ℝ) ^ 2 + 1) / (12 * (a : ℝ) * (b : ℝ)) - 1 / 4 := by
  -- Handle edge cases a=1 or b=1
  by_cases ha2 : a = 1
  · subst ha2
    by_cases hb1 : b = 1
    · subst hb1; simp [dedekindSum]; norm_num
    · rw [dedekindSum_one, dedekindSum_one_right b (by omega)]
      simp; ring
  by_cases hb2 : b = 1
  · subst hb2
    by_cases ha1 : a = 1
    · subst ha1; simp [dedekindSum]; norm_num
    · rw [dedekindSum_one, dedekindSum_one_right a (by omega)]
      simp; ring
  -- Main case: a,b ≥ 2
  have ha_ge2 : 1 < a := by omega
  have hb_ge2 : 1 < b := by omega
  have h12ab : 12 * (a : ℝ) * b ≠ 0 := by positivity
  have hexp := dedekind_sum_expand_assembled a b ha_ge2 hb_ge2 hcop
  have : dedekindSum a b + dedekindSum b a =
      ((a : ℝ) ^ 2 + (b : ℝ) ^ 2 + 1 - 3 * a * b) / (12 * a * b) := by
    rw [eq_div_iff h12ab]; linarith
  rw [this]
  rw [sub_div]; congr 1
  have : (3 : ℝ) * ↑a * ↑b / (12 * ↑a * ↑b) = 1 / 4 := by
    field_simp; ring
  exact this

-- ════════════════════════════════════════════════
-- §4. CONNECTION TO RAMANUJAN ENTRY (sorry-free)
-- ════════════════════════════════════════════════

/-- **THEOREM**: The Dedekind reciprocity law contains the Ramanujan entry.

    s(a,b) + s(b,a) + 1/4 = a/(12b) + b/(12a) + 1/(12ab)

    The last term 1/(12ab) = R(j,k) when a,b are the coprime parts
    of j,k (i.e., a = j/gcd(j,k), b = k/gcd(j,k)).

    This is the bridge between the Dedekind world (cotangent sums,
    L-functions) and the Ramanujan world (GCD Fourier modes). -/
theorem dedekind_contains_ramanujan_assembled (a b : ℕ) (ha : 0 < a) (hb : 0 < b)
    (hcop : Nat.Coprime a b) :
    dedekindSum a b + dedekindSum b a + 1 / 4 =
    (a : ℝ) / (12 * b) + (b : ℝ) / (12 * a) + 1 / (12 * (a : ℝ) * (b : ℝ)) := by
  have hrecip := dedekind_reciprocity_assembled a b ha hb hcop
  have h12ab_ne : (12 : ℝ) * a * b ≠ 0 := by positivity
  have hdecomp : ((a : ℝ) ^ 2 + (b : ℝ) ^ 2 + 1) / (12 * (a : ℝ) * (b : ℝ)) =
      (a : ℝ) / (12 * b) + (b : ℝ) / (12 * a) + 1 / (12 * (a : ℝ) * (b : ℝ)) := by
    have ha_pos : (0 : ℝ) < a := by exact_mod_cast ha
    have hb_pos : (0 : ℝ) < b := by exact_mod_cast hb
    have h1 : (a : ℝ) / (12 * b) = (a : ℝ) ^ 2 / (12 * a * b) := by
      rw [sq]; field_simp
    have h2 : (b : ℝ) / (12 * a) = (b : ℝ) ^ 2 / (12 * a * b) := by
      rw [sq]; field_simp
    rw [h1, h2, ← add_div, ← add_div]
  linarith

/-- **COROLLARY**: Extract the Ramanujan entry from Dedekind reciprocity.

    1/(12ab) = s(a,b) + s(b,a) + 1/4 - a/(12b) - b/(12a)

    This expresses the Ramanujan entry R(j,k) (for coprime j,k)
    purely in terms of Dedekind sums and simple reciprocals. -/
theorem ramanujan_from_dedekind_assembled (a b : ℕ) (ha : 0 < a) (hb : 0 < b)
    (hcop : Nat.Coprime a b) :
    1 / (12 * (a : ℝ) * (b : ℝ)) =
    dedekindSum a b + dedekindSum b a + 1 / 4 -
    (a : ℝ) / (12 * b) - (b : ℝ) / (12 * a) := by
  linarith [dedekind_contains_ramanujan_assembled a b ha hb hcop]


end Cathedral.Physics.DedekindBridge
