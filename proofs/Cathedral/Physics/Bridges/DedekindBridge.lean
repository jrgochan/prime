/-
  Cathedral/Physics/Bridges/DedekindBridge.lean

  # Dedekind Sums and the Vasyunin-Ramanujan Bridge

  ## Purpose

  Formalize the Dedekind sum s(b,a) and its reciprocity law, then connect
  it to the Ramanujan matrix entry R(j,k) = gcd(j,k)²/(12jk).

  The Dedekind reciprocity law states:

    s(a,b) + s(b,a) = (a² + b² + 1)/(12ab) - 1/4

  This connects DIRECTLY to the Ramanujan entry: the term 1/(12ab)
  equals R(j,k) when a = j/gcd, b = k/gcd are the coprime parts.

  ## The Bridge to the Final Boss

  The Vasyunin Gram matrix G_V has entries involving cotangent sums
  V(a,b), which are related to Dedekind sums s(b,a). The correction
  matrix C - R (where C = G_V - bbᵀ) is controlled by Dedekind sums,
  which in turn encode L-function values at s=1.

  Under RH, the L-function values provide the cancellation needed to
  make vᵀCv = O(1/logN), which is `discrete_riemann_hypothesis` (the sole axiom).

  ## References

  - Dedekind (1892): Original definition and reciprocity law
  - Rademacher & Grosswald (1972): "Dedekind Sums" (monograph)
  - Vasyunin (1995): Connection to Nyman-Beurling L² distance
  - Báez-Duarte (2003): L² convergence rate under RH

  Created: May 19, 2026 — The Dedekind Session 🔑
-/

import Cathedral.Defs
import Cathedral.Physics.Mertens.RamanujanBridge
import Cathedral.Physics.Bridges.DedekindReciprocity

noncomputable section
open Real Finset

namespace Cathedral.Physics.DedekindBridge

-- Infrastructure (sawtooth, dedekindSum, cross-sums, sum formulas, bijections)
-- is provided by Cathedral.Physics.Bridges.DedekindReciprocity


-- ═══════════════════════════════════════════════════════════════════════════
-- FIBER DECOMPOSITION INFRASTRUCTURE
-- ═══════════════════════════════════════════════════════════════════════════

/-- The ceiling correction for fiber j: c_j = ⌈jr/a⌉.
    For j=0: c_j = 1 (by convention, matching the Ico start).
    For j=a-1: c_j = r (from coprimality).
    For generic j: c_j = (jr + a - 1)/a. -/
private noncomputable def fiber_c (a r j : ℕ) : ℕ :=
  if j = 0 then 1
  else if j + 1 = a then r
  else (j * r + a - 1) / a

/-- The Sturmian step for fiber j: ε_j = ⌊(j+1)r/a⌋ - ⌊jr/a⌋ for generic j.
    For j=0: ε_j = 0 (fiber_0 has exactly q elements).
    For j=a-1: ε_j = 0 (last fiber also has exactly q elements).
    For generic 1 ≤ j ≤ a-2: ε_j = (j+1)*r/a - j*r/a. -/
private noncomputable def fiber_eps (a r j : ℕ) : ℕ :=
  if j = 0 then 0
  else if j + 1 = a then 0
  else (j + 1) * r / a - j * r / a

/-- **FIBER MEMBERSHIP**: If j*b ≤ m*a < (j+1)*b then ⌊ma/b⌋ = j. -/
private lemma floor_in_fiber (a b m j : ℕ) (_hb : 0 < b)
    (hlb : j * b ≤ m * a) (hub : m * a < (j + 1) * b) :
    m * a / b = j := by
  rw [Nat.div_eq_of_lt_le] <;> omega

/-- **FIBER CONTIGUITY**: The map m ↦ ⌊ma/b⌋ is non-decreasing on {1,...,b-1}. -/
private lemma floor_div_mono (a b m₁ m₂ : ℕ) (_hb : 0 < b)
    (hle : m₁ ≤ m₂) :
    m₁ * a / b ≤ m₂ * a / b :=
  Nat.div_le_div_right (Nat.mul_le_mul_right a hle)

/-- **ARITHMETIC SUM OVER Ico**: ∑_{m ∈ Ico s (s+n)} m = n·s + n·(n-1)/2 -/
private lemma sum_Ico_arithmetic (s n : ℕ) :
    (∑ m ∈ Finset.Ico s (s + n), (m : ℝ)) =
    (n : ℝ) * (s : ℝ) + (n : ℝ) * ((n : ℝ) - 1) / 2 := by
  induction n with
  | zero => simp
  | succ n ih =>
    rw [show s + (n + 1) = (s + n) + 1 from by omega]
    rw [Finset.sum_Ico_succ_top (by omega : s ≤ s + n)]
    rw [ih]
    push_cast
    ring

set_option maxHeartbeats 400000 in
/-- **FIBER SUM EVALUATION (BerryHoof)**: For coprime (a, b=qa+r), each fiber j has
    ∑_{fiber_j} m = (q + ε_j) · (jq + c_j) + (q + ε_j)·((q + ε_j) - 1)/2

    where c_j = fiber_c a r j and ε_j = fiber_eps a r j.
    The fiber is a contiguous Ico interval of size q + ε_j starting at jq + c_j. -/
private lemma fiber_sum_eval (a r q j : ℕ) (ha : 2 ≤ a) (hr : 2 ≤ r)
    (hr_lt : r < a) (hcop : Nat.Coprime a r) (hj : j < a)
    (hq : 0 < q * a + r) :
    (∑ m ∈ (Finset.Ico 1 (q * a + r)).filter (fun m => m * a / (q * a + r) = j), (m : ℝ)) =
    ((q + fiber_eps a r j : ℕ) : ℝ) * ((j * q + fiber_c a r j : ℕ) : ℝ) +
    ((q + fiber_eps a r j : ℕ) : ℝ) * (((q + fiber_eps a r j : ℕ) : ℝ) - 1) / 2 := by
  set b := q * a + r with hb_def
  have hb_pos : 0 < b := hq
  have ha_pos : 0 < a := by omega
  have hcop_ab : Nat.Coprime a b := by
    unfold Nat.Coprime
    rw [hb_def, show q * a + r = r + a * q from by ring, Nat.gcd_add_mul_left_right]
    exact hcop
  -- Case split on j
  by_cases hj0 : j = 0
  · -- CASE j = 0: fiber = Ico(1, q+1), c=1, ε=0
    subst hj0
    simp only [fiber_c, fiber_eps, ite_true, Nat.add_zero, Nat.zero_mul, Nat.zero_add]
    have h_filter : (Finset.Ico 1 b).filter (fun m => m * a / b = 0) = Finset.Ico 1 (q + 1) := by
      ext m; simp only [Finset.mem_filter, Finset.mem_Ico]; constructor
      · intro ⟨⟨hm1, hmb⟩, hf⟩
        refine ⟨hm1, ?_⟩
        have h1 := Nat.div_add_mod (m * a) b; rw [hf] at h1
        have h2 := Nat.mod_lt (m * a) hb_pos
        nlinarith
      · intro ⟨hm1, hmq1⟩
        refine ⟨⟨hm1, by nlinarith⟩, ?_⟩
        apply Nat.div_eq_of_lt
        show m * a < b; nlinarith
    rw [h_filter, show q + 1 = 1 + q from by omega]; exact sum_Ico_arithmetic 1 q
  · by_cases hjlast : j + 1 = a
    · -- CASE j = a-1: fiber = Ico(jq+r, b), c=r, ε=0
      have : fiber_c a r j = r := by simp [fiber_c, hj0, hjlast]
      have : fiber_eps a r j = 0 := by simp [fiber_eps, hj0, hjlast]
      simp only [‹fiber_c a r j = r›, ‹fiber_eps a r j = 0›, Nat.add_zero]
      have h_filter : (Finset.Ico 1 b).filter (fun m => m * a / b = j) =
          Finset.Ico (j * q + r) b := by
        ext m; simp only [Finset.mem_filter, Finset.mem_Ico]; constructor
        · intro ⟨⟨hm1, hmb⟩, hf⟩
          refine ⟨?_, hmb⟩
          have hlb : j * b ≤ m * a := by
            have := Nat.div_mul_le_self (m * a) b; rw [hf] at this; linarith
          have hndvd : ¬ (a ∣ j * b) := by
            intro hdvd
            have := hcop_ab.dvd_of_dvd_mul_right hdvd
            have := Nat.le_of_dvd (by omega) this; omega
          have hjb_div : j * b / a = j * q + j * r / a := by
            rw [hb_def, show j * (q * a + r) = j * r + j * q * a from by ring]
            rw [Nat.add_mul_div_right _ _ ha_pos]; omega
          have hmod : j * b % a > 0 :=
            Nat.pos_of_ne_zero (fun h => hndvd ⟨j * b / a, by omega⟩)
          have hm_ge : m ≥ j * b / a + 1 := by
            by_contra h_neg; push Not at h_neg
            have hm_le : m ≤ j * b / a := by omega
            have h1 : m * a ≤ j * b / a * a := Nat.mul_le_mul_right a hm_le
            have h2 := Nat.div_add_mod (j * b) a
            nlinarith [Nat.div_mul_le_self (j * b) a]
          have hjr_div : j * r / a = r - 1 := by
            have hj_eq : j = a - 1 := by omega
            subst hj_eq
            have h_decomp : (a - 1) * r = (a - r) + (r - 1) * a := by
              zify [show 1 ≤ a from by omega, show r ≤ a from by omega, show 1 ≤ r from by omega]
              ring
            conv_lhs => rw [h_decomp]
            rw [Nat.add_mul_div_right _ _ ha_pos, Nat.div_eq_of_lt (by omega : a - r < a)]
            simp
          omega
        · intro ⟨hm_lo, hm_hi⟩
          have hj_eq : j = a - 1 := by omega
          refine ⟨⟨by omega, hm_hi⟩, ?_⟩
          subst hj_eq
          rw [Nat.div_eq_of_lt_le] <;> nlinarith
      rw [h_filter, show b = j * q + r + q from by nlinarith]
      exact sum_Ico_arithmetic _ _
    · -- CASE 1 ≤ j ≤ a-2: generic fiber
      have hfc : fiber_c a r j = (j * r + a - 1) / a := by
        simp [fiber_c, hj0, hjlast]
      have hfe : fiber_eps a r j = (j + 1) * r / a - j * r / a := by
        simp [fiber_eps, hj0, hjlast]
      rw [hfc, hfe]
      -- Non-divisibility
      have hndvd_jr : ¬ (a ∣ j * r) := by
        intro hdvd; have := hcop.dvd_of_dvd_mul_right hdvd
        exact absurd (Nat.le_of_dvd (by omega) this) (by omega)
      have hrem_jr_pos : j * r % a > 0 :=
        Nat.pos_of_ne_zero (fun h => hndvd_jr ⟨j * r / a, by omega⟩)
      -- Ceiling: (jr + a - 1) / a = jr/a + 1
      have hc_val : (j * r + a - 1) / a = j * r / a + 1 := by
        set Q := j * r / a with hQ_def
        set R := j * r % a with hR_def
        have h1 : a * Q + R = j * r := Nat.div_add_mod (j * r) a
        have h2 : R < a := Nat.mod_lt (j * r) ha_pos
        -- hrem_jr_pos : R > 0
        change R > 0 at hrem_jr_pos
        -- Goal: (Q * a + R + a - 1) / a = Q + 1
        -- = (R - 1 + (Q + 1) * a) / a
        -- = (R - 1) / a + Q + 1
        -- = 0 + Q + 1
        refine Nat.div_eq_of_lt_le ?lo ?hi
        case lo =>
          -- Goal: (Q + 1) * a ≤ Q * a + R + a - 1
          -- i.e., Q * a + a ≤ Q * a + R + a - 1, i.e., 0 ≤ R - 1
          simp only [show (Q + 1) * a = a * Q + a from by ring]
          omega
        case hi =>
          -- Goal: Q * a + R + a - 1 < (Q + 1 + 1) * a
          -- i.e., Q * a + R + a - 1 < Q * a + 2 * a, i.e., R - 1 < a
          simp only [show (Q + 1 + 1) * a = a * Q + 2 * a from by ring]
          omega
      -- Non-divisibility for j*b and (j+1)*b
      have hndvd_j : ¬ (a ∣ j * b) := by
        intro hdvd; have := hcop_ab.dvd_of_dvd_mul_right hdvd
        exact absurd (Nat.le_of_dvd (by omega) this) (by omega)
      have hndvd_j1 : ¬ (a ∣ (j + 1) * b) := by
        intro hdvd; have := hcop_ab.dvd_of_dvd_mul_right hdvd
        exact absurd (Nat.le_of_dvd (by omega) this) (by omega)
      -- jb/a = jq + jr/a via Euclidean decomposition
      have hjb_div : j * b / a = j * q + j * r / a := by
        rw [hb_def, show j * (q * a + r) = j * r + j * q * a from by ring]
        rw [Nat.add_mul_div_right _ _ ha_pos]; omega
      have hj1b_div : (j + 1) * b / a = (j + 1) * q + (j + 1) * r / a := by
        rw [hb_def, show (j + 1) * (q * a + r) = (j + 1) * r + (j + 1) * q * a from by ring]
        rw [Nat.add_mul_div_right _ _ ha_pos]; omega
      -- Mod positivity for jb and (j+1)b
      have hrem_jb_pos : j * b % a > 0 :=
        Nat.pos_of_ne_zero (fun h => hndvd_j ⟨j * b / a, by omega⟩)
      have hrem_j1b_pos : (j + 1) * b % a > 0 :=
        Nat.pos_of_ne_zero (fun h => hndvd_j1 ⟨(j + 1) * b / a, by omega⟩)
      -- Endpoints
      have h_start : j * q + (j * r + a - 1) / a = j * b / a + 1 := by
        rw [hc_val, hjb_div]; omega
      have hd_le : j * r / a ≤ (j + 1) * r / a := Nat.div_le_div_right (Nat.mul_le_mul_right r (by omega : j ≤ j + 1))
      have h_end : j * q + (j * r + a - 1) / a + (q + ((j + 1) * r / a - j * r / a)) =
          (j + 1) * b / a + 1 := by
        rw [hc_val, hj1b_div]
        have : (j + 1) * q = j * q + q := by ring
        omega
      -- Filter = Ico
      have h_filter : (Finset.Ico 1 b).filter (fun m => m * a / b = j) =
          Finset.Ico (j * q + (j * r + a - 1) / a)
                     (j * q + (j * r + a - 1) / a + (q + ((j + 1) * r / a - j * r / a))) := by
        ext m; simp only [Finset.mem_filter, Finset.mem_Ico]; constructor
        · -- Forward: m*a/b = j → m ∈ Ico
          intro ⟨⟨hm1, hmb⟩, hf⟩
          have hlb : j * b ≤ m * a := by
            have := Nat.div_mul_le_self (m * a) b; rw [hf] at this; linarith
          have hub : m * a < (j + 1) * b := by
            have h1 := Nat.div_add_mod (m * a) b
            have h2 := Nat.mod_lt (m * a) hb_pos; rw [hf] at h1; linarith
          constructor
          · -- Lower bound
            rw [h_start]; by_contra h_neg; push Not at h_neg
            have hle' : m ≤ j * b / a := by omega
            have h1 : m * a ≤ (j * b / a) * a := Nat.mul_le_mul_right a hle'
            have h1' : (j * b / a) * a = a * (j * b / a) := by ring
            have h2 := Nat.div_add_mod (j * b) a; linarith
          · -- Upper bound
            rw [h_end]; by_contra h_neg; push Not at h_neg
            have hge : (j + 1) * b / a + 1 ≤ m := by omega
            have h1 : ((j + 1) * b / a + 1) * a ≤ m * a := Nat.mul_le_mul_right a hge
            have h1' : ((j + 1) * b / a + 1) * a = a * ((j + 1) * b / a) + a := by ring
            have h2 := Nat.div_add_mod ((j + 1) * b) a
            -- Derive: a * ((j+1)*b/a) + a ≤ m*a < (j+1)*b = a*((j+1)*b/a) + (j+1)*b%a
            -- So a < (j+1)*b%a, but (j+1)*b%a < a. Contradiction.
            have h3 := Nat.mod_lt ((j + 1) * b) ha_pos
            linarith
        · -- Backward: m ∈ Ico → m ∈ filter
          intro ⟨hm_lo, hm_hi⟩
          refine ⟨⟨?_, ?_⟩, ?_⟩
          · -- 1 ≤ m
            have hj_ge : 1 ≤ j := by omega
            have hjr_ge : j * r ≥ 2 := by nlinarith
            have hbound : j * r + a - 1 ≥ a := by omega
            have : (j * r + a - 1) / a ≥ 1 := by
              calc (j * r + a - 1) / a ≥ a / a := Nat.div_le_div_right hbound
                _ = 1 := Nat.div_self ha_pos
            omega
          · -- m < b
            rw [h_end] at hm_hi; rw [hj1b_div] at hm_hi
            have hj1_bound : (j + 1) * r / a < r := by
              apply Nat.div_lt_of_lt_mul
              have : (j + 1) < a := by omega
              show (j + 1) * r < a * r
              exact Nat.mul_lt_mul_of_pos_right this (by omega : 0 < r)
            have hexp : (j + 1) * q = j * q + q := by ring
            -- m < (j+1)*q + (j+1)*r/a + 1 ≤ (j+1)*q + r ≤ a*q + r = b
            have hq_bound : (j + 1) * q ≤ a * q := Nat.mul_le_mul_right q (by omega)
            have haq : a * q = q * a := by ring
            omega
          · -- m*a/b = j
            apply floor_in_fiber a b m j hb_pos
            · -- j*b ≤ m*a
              rw [h_start] at hm_lo
              have h1 : (j * b / a + 1) * a ≤ m * a := Nat.mul_le_mul_right a hm_lo
              have h1' : (j * b / a + 1) * a = a * (j * b / a) + a := by ring
              have h2 := Nat.div_add_mod (j * b) a
              have h3 := Nat.mod_lt (j * b) ha_pos
              -- From h1' and h1: a*(j*b/a) + a ≤ m*a
              -- From h2: j*b = a*(j*b/a) + j*b%a
              -- From h3: j*b%a < a ≤ a
              -- So j*b = a*(j*b/a) + j*b%a ≤ a*(j*b/a) + a ≤ m*a
              linarith
            · -- m*a < (j+1)*b
              rw [h_end] at hm_hi
              have hle' : m ≤ (j + 1) * b / a := by omega
              have h1 : m * a ≤ ((j + 1) * b / a) * a := Nat.mul_le_mul_right a hle'
              have h1' : ((j + 1) * b / a) * a = a * ((j + 1) * b / a) := by ring
              have h2 := Nat.div_add_mod ((j + 1) * b) a; linarith
      rw [h_filter, sum_Ico_arithmetic]

-- ═══════════════════════════════════════════════════════════════════════════
-- SECTION 4B: SECOND DIFFERENCE INFRASTRUCTURE
-- ═══════════════════════════════════════════════════════════════════════════

/-- **FIBER QUADRATIC SECOND DIFFERENCE**: Each fiber's sum is quadratic in q,
    so its second difference is the constant 2j + 1.

    fiber_sum(j, q) = (q+ε)(jq+c) + (q+ε)((q+ε)-1)/2

    Δ²(fiber_sum) = fiber_sum(q+2) - 2·fiber_sum(q+1) + fiber_sum(q) = 2j+1 -/
private lemma fiber_quad_second_diff (j c ε q : ℕ) :
    (((q + 2 + ε : ℕ) : ℝ) * ((j * (q + 2) + c : ℕ) : ℝ) +
     ((q + 2 + ε : ℕ) : ℝ) * (((q + 2 + ε : ℕ) : ℝ) - 1) / 2) -
    2 * (((q + 1 + ε : ℕ) : ℝ) * ((j * (q + 1) + c : ℕ) : ℝ) +
         ((q + 1 + ε : ℕ) : ℝ) * (((q + 1 + ε : ℕ) : ℝ) - 1) / 2) +
    (((q + ε : ℕ) : ℝ) * ((j * q + c : ℕ) : ℝ) +
     ((q + ε : ℕ) : ℝ) * (((q + ε : ℕ) : ℝ) - 1) / 2) =
    2 * (j : ℝ) + 1 := by
  push_cast
  ring

/-- **SUMMATION IDENTITY**: Σ_{j=0}^{a-1} j(2j+1) = a(a-1)(4a+1)/6 -/
private lemma sum_j_times_2j_plus_1 (a : ℕ) :
    (∑ j ∈ Finset.range a, (j : ℝ) * (2 * (j : ℝ) + 1)) =
    (a : ℝ) * ((a : ℝ) - 1) * (4 * (a : ℝ) + 1) / 6 := by
  induction a with
  | zero => simp
  | succ n ih =>
    rw [Finset.sum_range_succ, ih]
    push_cast
    ring

/-- **WEIGHTED FLOOR SUM FIBER DECOMPOSITION**: The weighted floor sum decomposes
    into fiber contributions: X(a,b) = Σ_{j=0}^{a-1} j · (Σ_{m ∈ fiber_j} m).

    This is the fundamental partition identity connecting the global sum to fibers. -/
private lemma weighted_floor_fiber_decomp (a b : ℕ) (ha : 2 ≤ a) (_hb : 2 ≤ b)
    (_hcop : Nat.Coprime a b) :
    (∑ m ∈ Finset.Ico 1 b, (m : ℝ) * ((m * a / b : ℕ) : ℝ)) =
    ∑ j ∈ Finset.range a, (j : ℝ) *
      (∑ m ∈ (Finset.Ico 1 b).filter (fun m => m * a / b = j), (m : ℝ)) := by
  have hfloor_range : ∀ m ∈ Finset.Ico 1 b, m * a / b ∈ Finset.range a := by
    intro m hm
    simp only [Finset.mem_Ico] at hm
    simp only [Finset.mem_range]
    exact Nat.div_lt_of_lt_mul (by nlinarith)
  have hdecomp := Finset.sum_fiberwise_of_maps_to hfloor_range
      (fun m => (m : ℝ) * ((m * a / b : ℕ) : ℝ))
  rw [← hdecomp]
  -- Now each inner sum has ⌊ma/b⌋ = j for all m in the fiber, so factor out j
  congr 1; ext j
  -- Goal: j * (Σ_{m ∈ fiber_j} m) = Σ_{m ∈ fiber_j} m * ⌊ma/b⌋
  rw [Finset.mul_sum]
  apply Finset.sum_congr rfl
  intro m hm
  -- hm : m ∈ (Finset.Ico 1 b).filter (fun m => m * a / b = j)
  simp only [Finset.mem_filter] at hm
  -- hm.2 : m * a / b = j
  rw [hm.2]
  ring

/-- **CONSTANT SECOND DIFFERENCE**: X(a, (q+2)a+r) - 2X(a, (q+1)a+r) + X(a, qa+r)
    = a(a-1)(4a+1)/6.

    Each fiber j contributes a quadratic-in-q sum, so its second difference is 2j+1.
    Summing j·(2j+1) over j = 0..a-1 gives a(a-1)(4a+1)/6. -/
private lemma constant_second_diff (a r q : ℕ) (ha : 2 ≤ a) (hr : 2 ≤ r)
    (hr_lt : r < a) (hcop : Nat.Coprime a r) :
    (∑ m ∈ Finset.Ico 1 ((q + 2) * a + r), (m : ℝ) * ((m * a / ((q + 2) * a + r) : ℕ) : ℝ)) -
    2 * (∑ m ∈ Finset.Ico 1 ((q + 1) * a + r), (m : ℝ) * ((m * a / ((q + 1) * a + r) : ℕ) : ℝ)) +
    (∑ m ∈ Finset.Ico 1 (q * a + r), (m : ℝ) * ((m * a / (q * a + r) : ℕ) : ℝ)) =
    (a : ℝ) * ((a : ℝ) - 1) * (4 * (a : ℝ) + 1) / 6 := by
  -- Coprimality for each b-value
  have hcop_k : ∀ k, Nat.Coprime a (k * a + r) := by
    intro k; unfold Nat.Coprime
    rw [show k * a + r = r + a * k from by ring, Nat.gcd_add_mul_left_right]
    exact hcop
  -- Decompose each sum using fiber partition
  rw [weighted_floor_fiber_decomp a ((q + 2) * a + r) ha (by omega) (hcop_k (q + 2))]
  rw [weighted_floor_fiber_decomp a ((q + 1) * a + r) ha (by omega) (hcop_k (q + 1))]
  rw [weighted_floor_fiber_decomp a (q * a + r) ha (by omega) (hcop_k q)]
  -- Now goal is: Σ j·fiber₂ - 2·Σ j·fiber₁ + Σ j·fiber₀ = K
  -- For each j, use fiber_sum_eval to get the polynomial form, then use fiber_quad_second_diff
  rw [← sum_j_times_2j_plus_1 a]
  -- Combine: Σf - 2Σg + Σh = Σ(f - 2g + h)
  have h2sum := @Finset.sum_sub_distrib ℕ ℝ (Finset.range a) _
  -- Σ j·fiber₂ - 2·Σ j·fiber₁ + Σ j·fiber₀
  -- = Σ (j·fiber₂ - 2·j·fiber₁) + Σ j·fiber₀
  -- = Σ (j·fiber₂ - 2·j·fiber₁ + j·fiber₀)
  -- For each j, the inner term equals j·(2j+1) by fiber_quad_second_diff
  -- We prove this sufficiency: each j-term of the LHS sum equals j*(2j+1)
  suffices h : ∀ j ∈ Finset.range a,
    (j : ℝ) * (∑ m ∈ (Finset.Ico 1 ((q + 2) * a + r)).filter
        (fun m => m * a / ((q + 2) * a + r) = j), (m : ℝ)) -
    2 * ((j : ℝ) * (∑ m ∈ (Finset.Ico 1 ((q + 1) * a + r)).filter
        (fun m => m * a / ((q + 1) * a + r) = j), (m : ℝ))) +
    (j : ℝ) * (∑ m ∈ (Finset.Ico 1 (q * a + r)).filter
        (fun m => m * a / (q * a + r) = j), (m : ℝ)) =
    (j : ℝ) * (2 * (j : ℝ) + 1) by
    -- Merge: Σf - 2Σg + Σh = Σ(f - 2g + h) by algebraic manipulation
    -- Step 1: Pull 2 inside the sum
    have h2 : (2 : ℝ) * ∑ j ∈ Finset.range a, (j : ℝ) * (∑ m ∈ (Finset.Ico 1 ((q + 1) * a + r)).filter
        (fun m => m * a / ((q + 1) * a + r) = j), (m : ℝ)) =
      ∑ j ∈ Finset.range a, 2 * ((j : ℝ) * (∑ m ∈ (Finset.Ico 1 ((q + 1) * a + r)).filter
        (fun m => m * a / ((q + 1) * a + r) = j), (m : ℝ))) := by
      rw [Finset.mul_sum]
    rw [h2, ← Finset.sum_sub_distrib, ← Finset.sum_add_distrib]
    exact Finset.sum_congr rfl h
  -- Now prove the per-fiber identity
  intro j hj
  simp only [Finset.mem_range] at hj
  -- Use non-existential BerryHoof to get matching c, ε across q values
  rw [fiber_sum_eval a r (q + 2) j ha hr hr_lt hcop hj (by omega)]
  rw [fiber_sum_eval a r (q + 1) j ha hr hr_lt hcop hj (by omega)]
  rw [fiber_sum_eval a r q j ha hr hr_lt hcop hj (by omega)]
  -- Factor out j and apply fiber_quad_second_diff
  set c := fiber_c a r j
  set ε := fiber_eps a r j
  -- Goal: j * f(q+2,c,ε) - 2*(j * f(q+1,c,ε)) + j * f(q,c,ε) = j * (2j+1)
  -- Factor: j * [f(q+2) - 2f(q+1) + f(q)] = j * (2j+1)
  -- This follows from fiber_quad_second_diff: f(q+2) - 2f(q+1) + f(q) = 2j+1
  have hΔ := fiber_quad_second_diff j c ε q
  -- hΔ : f(q+2) - 2*f(q+1) + f(q) = 2j+1
  -- Goal: j * f₂ - 2*(j*f₁) + j*f₀ = j*(2j+1)
  -- = j*(f₂ - 2f₁ + f₀) = j*(2j+1)
  nlinarith


-- **STEPPING LEMMA**: When the denominator increases from b to b+a (with b = qa+r),
--   the weighted floor sum X(a,n) changes by a LINEAR function of q:
--   X(a, b+a) = X(a, b) + c₀(a,r) + c₁(a)·q
--   where c₁(a) = a(a-1)(4a+1)/6 (independent of r!)
--   Proved by induction on q:
--     BASE CASE (q=0): weighted_floor_base (The Nervous Berry 🍓)
--     INDUCTION STEP: constant_second_diff (BerryHoof Trinity 🍓🍓🍓)

set_option maxHeartbeats 1600000 in
/-- **BASE CASE (q=0)**: The Nervous Berry 🍓
    12r·X(a+r) - 12(r+a)·X(r) = P(a+r) where P(n) = a²(4rn-1) - nr(3a+1) + 1. -/
private lemma weighted_floor_base (a r : ℕ) (ha : 2 ≤ a) (hr : 2 ≤ r)
    (hr_lt : r < a) (hcop : Nat.Coprime a r) :
    12 * ((r : ℝ) * (∑ m ∈ Finset.Ico 1 (a + r), (m : ℝ) *
      ((m * a / (a + r) : ℕ) : ℝ)) -
      (r : ℝ) * (∑ m ∈ Finset.Ico 1 r, (m : ℝ) * ((m * a / r : ℕ) : ℝ))) -
    12 * ((a : ℝ) * (∑ m ∈ Finset.Ico 1 r, (m : ℝ) * ((m * a / r : ℕ) : ℝ))) =
    (a : ℝ)^2 * (4 * (r : ℝ) * ((a : ℝ) + (r : ℝ)) - 1) -
      ((a : ℝ) + (r : ℝ)) * (r : ℝ) * (3 * (a : ℝ) + 1) + 1 := by
  -- THE BRAVE BERRY 🍓 — Proved via Dedekind reciprocity (imported from DedekindReciprocity.lean)
  --
  -- Key insight: reciprocity for (a,a+r) and (a,r) both involve s(r,a),
  -- which CANCELS in the subtraction via dedekindSum_mod, leaving a
  -- polynomial identity that closes with nlinarith.
  --
  -- Positivity and coprimality setup
  have ha_pos : (0 : ℝ) < a := by positivity
  have hr_pos : (0 : ℝ) < r := by positivity
  have har_pos : (0 : ℝ) < a + r := by positivity
  have ha_ne : (a : ℝ) ≠ 0 := ne_of_gt ha_pos
  have hr_ne : (r : ℝ) ≠ 0 := ne_of_gt hr_pos
  have har_ne : (a : ℝ) + (r : ℝ) ≠ 0 := ne_of_gt har_pos
  -- Coprimality: gcd(a,r)=1 implies gcd(a, a+r)=1
  have hcop_ar : Nat.Coprime a (a + r) := by
    unfold Nat.Coprime
    rw [Nat.add_comm, Nat.gcd_add_self_right]
    exact hcop
  -- Step 1: Reciprocity for (a, a+r) and (a, r)
  have hrecip_ar := dedekind_reciprocity a (a + r) (by omega) (by omega) hcop_ar
  have hrecip_r := dedekind_reciprocity a r (by omega) (by omega) hcop
  -- Step 2: Periodicity: s(a+r, a) = s(r, a) via s(b,a) = s(b%a, a)
  have hmod_val : (a + r) % a = r := by
    rw [Nat.add_mod, Nat.mod_self, Nat.zero_add, Nat.mod_eq_of_lt (Nat.mod_lt r (by omega)),
        Nat.mod_eq_of_lt hr_lt]
  have hmod : dedekindSum (a + r) a = dedekindSum r a := by
    have h := dedekindSum_mod (a + r) a (by omega)
    rw [hmod_val] at h; exact h
  -- Substitute periodicity into hrecip_ar so s(r,a) appears
  rw [hmod] at hrecip_ar
  -- Step 3: s(a,a+r) - s(a,r) from subtracting the two reciprocity formulas
  -- (s(r,a) cancels because it appears in both)
  have hdiff_s : dedekindSum a (a + r) - dedekindSum a r =
      ((a : ℝ) ^ 2 + ((a : ℝ) + (r : ℝ)) ^ 2 + 1) / (12 * (a : ℝ) * ((a : ℝ) + (r : ℝ))) -
      ((a : ℝ) ^ 2 + (r : ℝ) ^ 2 + 1) / (12 * (a : ℝ) * (r : ℝ)) := by
    -- hrecip_ar: s(a,a+r) + s(r,a) = (a²+(a+r)²+1)/(12a(a+r)) - 1/4
    -- hrecip_r:  s(a,r) + s(r,a) = (a²+r²+1)/(12ar) - 1/4
    -- Subtract: s(a,a+r) - s(a,r) = RHS_ar - RHS_r
    have h1 : dedekindSum a (a + r) - dedekindSum a r =
        (dedekindSum a (a + r) + dedekindSum r a) -
        (dedekindSum a r + dedekindSum r a) := by ring
    rw [h1, hrecip_ar, hrecip_r]; push_cast; ring
  -- Step 4: Clear denominators — multiply both sides by 12ar(a+r)
  have hdiff_cleared : 12 * (a : ℝ) * r * ((a : ℝ) + r) *
      (dedekindSum a (a + r) - dedekindSum a r) =
      (r : ℝ) * ((a : ℝ) ^ 2 + ((a : ℝ) + r) ^ 2 + 1) -
      ((a : ℝ) + r) * ((a : ℝ) ^ 2 + (r : ℝ) ^ 2 + 1) := by
    rw [hdiff_s]; field_simp
  -- Step 5: Cross-sum expansion → relate to weighted floor sums X
  have hcop_ar_symm : Nat.Coprime (a + r) a := hcop_ar.symm
  have hcs_ar := dedekindSum_cross_sum a (a + r) (by omega) hcop_ar_symm
  have hcs_r := dedekindSum_cross_sum a r (by omega) hcop.symm
  have hdecomp_ar := cross_sum_decomp a (a + r)
  have hdecomp_r := cross_sum_decomp a r
  set Xar := ∑ m ∈ Finset.Ico 1 (a + r), (m : ℝ) * ((m * a / (a + r) : ℕ) : ℝ)
  set Xr := ∑ m ∈ Finset.Ico 1 r, (m : ℝ) * ((m * a / r : ℕ) : ℝ)
  set Sar := ∑ m ∈ Finset.Ico 1 (a + r), (m : ℝ) ^ 2
  set Sr := ∑ m ∈ Finset.Ico 1 r, (m : ℝ) ^ 2
  -- Step 6: Evaluate Σm² using sum_Ico_sq_R
  have hSar_val : 6 * Sar = ((a : ℝ) + (r : ℝ) - 1) * ((a : ℝ) + (r : ℝ)) *
      (2 * ((a : ℝ) + (r : ℝ)) - 1) := by
    have h := sum_Ico_sq_R (a + r - 1)
    simp only [show a + r - 1 + 1 = a + r from by omega] at h
    have hcast : ((a + r - 1 : ℕ) : ℝ) = (a : ℝ) + (r : ℝ) - 1 := by
      rw [Nat.cast_sub (by omega : 1 ≤ a + r)]; push_cast; ring
    rw [hcast] at h; linarith
  have hSr_val : 6 * Sr = ((r : ℝ) - 1) * (r : ℝ) * (2 * (r : ℝ) - 1) := by
    have h := sum_Ico_sq_R (r - 1)
    simp only [show r - 1 + 1 = r from by omega] at h
    have hcast : ((r - 1 : ℕ) : ℝ) = (r : ℝ) - 1 := by
      rw [Nat.cast_sub (by omega : 1 ≤ r)]; simp
    rw [hcast] at h; linarith
  -- Step 7: Gaussian elimination to remove dedekindSum variables
  rw [hdecomp_ar] at hcs_ar
  rw [hdecomp_r] at hcs_r
  have har_cast : ((a + r : ℕ) : ℝ) = (a : ℝ) + (r : ℝ) := by push_cast; ring
  push_cast [har_cast] at hcs_ar
  -- hcs_ar: 12(a+r)²·s_ar = 12(a·Sar-(a+r)·Xar) - 3(a+r)²((a+r)-1)
  -- hcs_r:  12r²·s_r = 12(a·Sr-r·Xr) - 3r²(r-1)
  -- hdiff_cleared: 12ar(a+r)·(s_ar-s_r) = P(a,r)
  --
  -- Strategy: r²×hcs_ar - (a+r)²×hcs_r gives h_diff_cs.
  -- Then a×h_diff_cs = r(a+r)×hdiff_cleared eliminates all dedekindSum.
  set s_ar := dedekindSum a (a + r)
  set s_r := dedekindSum a r
  -- r²×hcs_ar and (a+r)²×hcs_r
  have h_diff_cs : 12 * (r : ℝ)^2 * ((a : ℝ) + r)^2 * (s_ar - s_r) =
      (r : ℝ)^2 * (12 * ((a : ℝ) * Sar - ((a : ℝ) + r) * Xar) -
      3 * ((a : ℝ) + r)^2 * (((a : ℝ) + r) - 1)) -
      ((a : ℝ) + r)^2 * (12 * ((a : ℝ) * Sr - (r : ℝ) * Xr) -
      3 * (r : ℝ)^2 * ((r : ℝ) - 1)) := by nlinarith [hcs_ar, hcs_r]
  -- r(a+r)×hdiff_cleared
  have h_diff_recip : 12 * (a : ℝ) * (r : ℝ)^2 * ((a : ℝ) + r)^2 * (s_ar - s_r) =
      (r : ℝ) * ((a : ℝ) + r) * ((r : ℝ) * ((a : ℝ)^2 + ((a : ℝ) + r)^2 + 1) -
      ((a : ℝ) + r) * ((a : ℝ)^2 + (r : ℝ)^2 + 1)) := by
    have := hdiff_cleared
    nlinarith [mul_pos hr_pos har_pos]
  -- a×h_diff_cs = h_diff_recip → eliminates s_ar, s_r!
  have nodedekind :
      (a : ℝ) * ((r : ℝ)^2 * (12 * ((a : ℝ) * Sar - ((a : ℝ) + r) * Xar) -
      3 * ((a : ℝ) + r)^2 * (((a : ℝ) + r) - 1)) -
      ((a : ℝ) + r)^2 * (12 * ((a : ℝ) * Sr - (r : ℝ) * Xr) -
      3 * (r : ℝ)^2 * ((r : ℝ) - 1))) =
      (r : ℝ) * ((a : ℝ) + r) * ((r : ℝ) * ((a : ℝ)^2 + ((a : ℝ) + r)^2 + 1) -
      ((a : ℝ) + r) * ((a : ℝ)^2 + (r : ℝ)^2 + 1)) := by
    nlinarith [h_diff_cs, h_diff_recip]
  -- Step 7e: Scale the Sar and Sr identities to match nodedekind's coefficients.
  -- nodedekind has 12a²r²Sar and 12a²(a+r)²Sr terms.
  -- We compute these explicitly using hSar_val and hSr_val to eliminate Sar and Sr.
  have hS1 : 12 * (a : ℝ)^2 * r^2 * Sar =
      2 * (a : ℝ)^2 * r^2 * (((a : ℝ) + r - 1) * ((a : ℝ) + r) * (2 * ((a : ℝ) + r) - 1)) := by
    have h : Sar = ((a : ℝ) + r - 1) * ((a : ℝ) + r) * (2 * ((a : ℝ) + r) - 1) / 6 := by
      linarith [hSar_val]
    rw [h]; ring
  have hS2 : 12 * (a : ℝ)^2 * ((a : ℝ) + r)^2 * Sr =
      2 * (a : ℝ)^2 * ((a : ℝ) + r)^2 * (((r : ℝ) - 1) * r * (2 * r - 1)) := by
    have h : Sr = ((r : ℝ) - 1) * r * (2 * r - 1) / 6 := by linarith [hSr_val]
    rw [h]; ring
  -- Step 7f: Close the goal via exact polynomial identity.
  -- CAS verification: goal = (nodedekind - hS1 + hS2) / (ar(a+r))
  -- So ar(a+r) * goal = nodedekind - hS1 + hS2  (after ring normalization)
  -- Strategy: multiply goal by ar(a+r), cancel, close with linarith.
  have har_prod_ne : (a : ℝ) * r * ((a : ℝ) + r) ≠ 0 := by positivity
  rw [show (12 : ℝ) * ((r : ℝ) * Xar - (r : ℝ) * Xr) - 12 * ((a : ℝ) * Xr) =
    12 * ((r : ℝ) * Xar - ((a : ℝ) + r) * Xr) from by ring]
  -- Suffice to prove the scaled version
  suffices hmul : (a : ℝ) * r * ((a : ℝ) + r) *
      (12 * ((r : ℝ) * Xar - ((a : ℝ) + r) * Xr)) =
      (a : ℝ) * r * ((a : ℝ) + r) *
      ((a : ℝ)^2 * (4 * r * ((a : ℝ) + r) - 1) -
       ((a : ℝ) + r) * r * (3 * a + 1) + 1) by
    exact mul_left_cancel₀ har_prod_ne hmul
  -- hmul is: 12ar(a+r)(rXar-(a+r)Xr) = ar(a+r)·GOAL_POLY
  -- From nodedekind (expanded): -12ar(a+r)(rXar-(a+r)Xr) + 12a²r²Sar - 12a²(a+r)²Sr - const_terms = RHS
  -- So: 12ar(a+r)(rXar-(a+r)Xr) = 12a²r²Sar - 12a²(a+r)²Sr - const_terms - RHS
  -- = hS1_RHS - hS2_RHS - const_terms - RHS  (using hS1, hS2)
  -- This is linear in everything → linarith closes after ring_nf.
  -- Create the key identity: hmul = nodedekind - hS1 + hS2 + ring_terms
  -- Rearrange nodedekind to solve for the Xar/Xr terms:
  have key : 12 * (a : ℝ) * r * ((a : ℝ) + r) * ((r : ℝ) * Xar - ((a : ℝ) + r) * Xr) =
      12 * (a : ℝ)^2 * r^2 * Sar - 12 * (a : ℝ)^2 * ((a : ℝ) + r)^2 * Sr -
      3 * (a : ℝ) * r^2 * ((a : ℝ) + r)^2 * (((a : ℝ) + r) - 1) +
      3 * (a : ℝ) * ((a : ℝ) + r)^2 * r^2 * ((r : ℝ) - 1) -
      (r : ℝ) * ((a : ℝ) + r) * ((r : ℝ) * ((a : ℝ)^2 + ((a : ℝ) + r)^2 + 1) -
      ((a : ℝ) + r) * ((a : ℝ)^2 + (r : ℝ)^2 + 1)) := by
    nlinarith [nodedekind]
  -- Now substitute hS1 and hS2 into key to eliminate Sar and Sr:
  -- key = hS1_RHS - hS2_RHS - const_poly
  -- = 2a²r²(a+r-1)(a+r)(2(a+r)-1) - 2a²(a+r)²(r-1)r(2r-1) - const_poly
  -- This is pure polynomial in a, r → linarith + ring
  linarith [key, hS1, hS2]

/-- **STEPPING LEMMA (induction)**: The base case is factored into weighted_floor_base.
    The induction step uses constant_second_diff (BerryHoof Trinity). -/
private lemma weighted_floor_step (a r q : ℕ) (ha : 2 ≤ a) (hr : 2 ≤ r)
    (hr_lt : r < a) (hcop : Nat.Coprime a r) :
    let b := q * a + r
    let b' := (q + 1) * a + r
    -- 12r·(X_{b'} - X_b) - 12a·X_r = (q+1)·P(b') - q·P(b)
    -- This is the irreducible combinatorial core.
    12 * ((r : ℝ) * (∑ m ∈ Finset.Ico 1 b', (m : ℝ) * ((m * a / b' : ℕ) : ℝ)) -
          (r : ℝ) * (∑ m ∈ Finset.Ico 1 b, (m : ℝ) * ((m * a / b : ℕ) : ℝ))) -
    12 * ((a : ℝ) * (∑ m ∈ Finset.Ico 1 r, (m : ℝ) * ((m * a / r : ℕ) : ℝ))) =
    ((q : ℝ) + 1) * ((a : ℝ)^2 * (4 * (r : ℝ) * (b' : ℝ) - 1) -
               (b' : ℝ) * (r : ℝ) * (3 * (a : ℝ) + 1) + 1) -
    (q : ℝ) * ((a : ℝ)^2 * (4 * (r : ℝ) * (b : ℝ) - 1) -
               (b : ℝ) * (r : ℝ) * (3 * (a : ℝ) + 1) + 1) := by
  -- Induction on q
  induction q with
  | zero =>
    -- Base case: q = 0, b = r, b' = a + r
    -- 12r·(X(a+r) - X(r)) - 12a·X(r) = P(a+r)
    simp only [Nat.zero_add, CharP.cast_eq_zero, zero_mul, sub_zero]
    norm_num
    exact weighted_floor_base a r ha hr hr_lt hcop
  | succ n ih =>
    -- Induction step: q = n+1, assuming result for q = n
    -- step(n+1) = step(n) + 12r·Δ²X = step(n) + 12r·K
    -- We need: step(n+1) = (n+2)·P(b_{n+2}) - (n+1)·P(b_{n+1})
    -- By IH:   step(n)   = (n+1)·P(b_{n+1}) - n·P(b_n)
    -- So: step(n+1) - step(n) = (n+2)·P(b_{n+2}) - 2(n+1)·P(b_{n+1}) + n·P(b_n)
    -- And: step(n+1) - step(n) = 12r·(X(b_{n+2}) - 2X(b_{n+1}) + X(b_n)) = 12r·K
    -- These are equal by polynomial identity (push_cast; ring)
    have hΔ := constant_second_diff a r n ha hr hr_lt hcop
    -- The induction step is: goal(n+1) = ih + 12r·hΔ
    -- Expand: LHS(n+1) - LHS(n) = 12r·Δ²X
    -- and RHS(n+1) - RHS(n) = polynomial = 12r·K
    -- Since Δ²X = K (by hΔ), the step follows.
    -- First, unfold the let bindings in ih
    simp only [] at ih
    have : n + 1 + 1 = n + 2 := by omega
    rw [this] at *
    -- Push all ℕ casts to ℝ for polynomial reasoning
    push_cast at ih hΔ ⊢
    nlinarith [mul_self_nonneg (a : ℝ), mul_self_nonneg (r : ℝ),
               mul_comm (a : ℝ) (r : ℝ), mul_comm (n : ℝ) (a : ℝ)]

/-- **WEIGHTED FLOOR SUM EUCLIDEAN IDENTITY**: For coprime a,r with a ≥ 2, r ≥ 2,
    r < a, and b = q*a + r:

    12 · (r · X(a,b) - b · X(a,r)) = q · [a²(4rb-1) - br(3a+1) + 1]

    where X(a,n) = Σ_{m=1}^{n-1} m · ⌊ma/n⌋ is the weighted floor sum.

    This is the irreducible core of the three-term relation, expressing the
    Euclidean step s(a,b) → s(a,r) in terms of floor sums.

    PROOF: By induction on q, using the stepping lemma `weighted_floor_step`.
    Base case q=0: b=r, both sides are 0.
    Step q→q+1: the stepping lemma gives the increment, close with ring.

    Numerically verified for 161 coprime pairs with a+b ≤ 30. -/
private lemma weighted_floor_euclidean (a r q : ℕ) (ha : 2 ≤ a) (hr : 2 ≤ r)
    (hr_lt : r < a) (hcop : Nat.Coprime a r) :
    let b := q * a + r
    12 * ((r : ℝ) * (∑ m ∈ Finset.Ico 1 b, (m : ℝ) * ((m * a / b : ℕ) : ℝ)) -
          (b : ℝ) * (∑ m ∈ Finset.Ico 1 r, (m : ℝ) * ((m * a / r : ℕ) : ℝ))) =
    (q : ℝ) * ((a : ℝ)^2 * (4 * (r : ℝ) * (b : ℝ) - 1) -
               (b : ℝ) * (r : ℝ) * (3 * (a : ℝ) + 1) + 1) := by
  induction q with
  | zero =>
    -- b = 0 * a + r = r, so both sums are over Ico 1 r with the same floor.
    -- LHS = 12 * (r * X_r - r * X_r) = 0
    -- RHS = 0 * (...) = 0
    simp only [zero_mul, zero_add, Nat.cast_zero, zero_mul, sub_self, mul_zero]
  | succ q ih =>
    -- b_new = (q+1)*a+r, b_old = q*a+r
    -- ih and hstep both have `let b := ...` which unfolds to the same thing.
    -- We combine them directly with linarith.
    have hstep := weighted_floor_step a r q ha hr hr_lt hcop
    -- Both ih and hstep use `let b := q * a + r` internally.
    -- The goal uses `let b := (q+1) * a + r`.
    -- Key fact: (q+1)*a + r = (q*a+r) + a at ℕ level.
    -- After let-unfolding, everything matches up to this arithmetic.
    -- ih : 12(r·Xold - bold·Xr) = q·P(bold)
    -- hstep: 12(r·Xnew - r·Xold) - 12a·Xr = (q+1)·P(bnew) - q·P(bold)
    -- where bnew = bold + a
    -- goal: 12(r·Xnew - bnew·Xr) = (q+1)·P(bnew)
    -- = 12r·Xnew - 12bnew·Xr
    -- = 12r(Xnew-Xold) + 12r·Xold - 12(bold+a)·Xr
    -- = 12r(Xnew-Xold) + 12r·Xold - 12bold·Xr - 12a·Xr
    -- = [12r(Xnew-Xold) - 12a·Xr] + 12(r·Xold-bold·Xr)
    -- = hstep + ih
    -- = [(q+1)P(bnew) - qP(bold)] + qP(bold) = (q+1)P(bnew) ✓
    -- Unfold the let b := q*a+r in ih and hstep so linarith can see through
    -- hstep now uses `let b' := (q+1)*a+r` matching the goal's `let b`.
    -- Unfold all lets, push casts, combine with linarith.
    dsimp only at ih hstep ⊢
    push_cast at ih hstep ⊢
    linarith [ih, hstep]

/-- **THREE-TERM RELATION** (cleared denominators): For coprime a,b ≥ 2
    with r = b%a > 0, the Dedekind sum reduction step:

    12·a·b·r · [s(a,b) - s(a,r)] = r·(a²+b²+1) - b·(a²+r²+1)

    This is the irreducible core of Dedekind reciprocity. Combined with
    dedekindSum_mod (periodicity), it enables Euclidean algorithm descent.

    PROOF STRATEGY (identified, implementation pending): Using
    dedekindSum_cross_sum, both sums expand as 12b²·s = 12C - 3b²(b-1).
    The three-term reduces to 12(bX_r - rX_b) = q(a-1)[a+1 - rb(4a+1)]
    where X = Σm·⌊ma/b⌋ and q = b/a. This follows from the Euclidean
    decomposition of the weighted floor sum.

    Numerically verified for all coprime (a,b) with a+b ≤ 100. -/
lemma dedekind_three_term_full (a b : ℕ) (ha : 1 < a) (hb : 1 < b)
    (hr : 0 < b % a) (hcop : Nat.Coprime a b) :
    12 * (a : ℝ) * b * ((b % a : ℕ) : ℝ) * (dedekindSum a b - dedekindSum a (b % a)) =
    ((b % a : ℕ) : ℝ) * ((a : ℝ)^2 + (b : ℝ)^2 + 1) -
    (b : ℝ) * ((a : ℝ)^2 + ((b % a : ℕ) : ℝ)^2 + 1) := by
  -- Case split: r = 1 (base, proved via cross-sum) vs r ≥ 2 (partition, TODO)
  by_cases hr1 : b % a = 1
  · -- BASE CASE: r = 1, b = qa+1
    -- Three-term becomes: 12ab·(s(a,b)-s(a,1)) = (a²+b²+1)-b(a²+2)
    simp only [hr1, Nat.cast_one, mul_one, one_mul, one_pow]
    have h1 : dedekindSum a 1 = 0 := dedekindSum_one a
    rw [h1, sub_zero]
    -- Goal: 12ab·s(a,b) = a²+b²+1-b(a²+2)
    -- From cross_sum: 12b²·s = 12C-3b²(b-1)
    have h_cs := dedekindSum_cross_sum a b hb hcop.symm
    set Cb := ∑ m ∈ Finset.Ico 1 b, (m : ℝ) * ((m * a % b : ℕ) : ℝ) with hCb_def
    -- The cross-sum C for b = qa+1:
    -- 12C = q(qa+1)(3qa²+3a-a²+qa)
    -- Proof: C = aΣm² - bX, and X is computed via bijection + base_div.
    -- The bijection sends m ∈ {1,...,aq} to (j,t) with j < a, 1 ≤ t ≤ q,
    -- via m = jq+t. Then ⌊ma/b⌋ = j [by base_div].
    -- X = Σm⌊ma/b⌋ = Σ_j j·(jq²+q(q+1)/2) = q²Σj² + q(q+1)/2·Σj.
    -- Combined: 12C = 2a(b-1)b(2b-1)-12b[q²a(a-1)(2a-1)/6+q(q+1)a(a-1)/4]
    --         = q(qa+1)(3qa²+3a-a²+qa) [by ring].
    have hdm := Nat.div_add_mod b a  -- a * (b/a) + b%a = b
    rw [hr1] at hdm                    -- a * (b/a) + 1 = b
    set q := b / a                     -- now hdm: a * q + 1 = b
    have hb_eq : b = q * a + 1 := by linarith [mul_comm a q]
    have hC : 12 * Cb = (q : ℝ) * ((q : ℝ) * a + 1) *
        (3 * q * (a : ℝ)^2 + 3 * a - (a : ℝ)^2 + q * a) := by
      -- PROOF: 12C = 12(aΣm² - bX) where X = Σm⌊ma/b⌋.
      -- Step 1: Decompose C = aΣm² - bX
      rw [hCb_def, cross_sum_decomp]
      -- Step 2: Evaluate Σm² using sum_Ico_sq_R
      have ha_q : 1 ≤ q := by nlinarith [hdm]
      have haq_eq : a * q + 1 = b := by linarith [mul_comm a q]
      -- b = qa+1, so b-1 = aq, Ico 1 b = Ico 1 (aq+1)
      have hSq : 6 * (∑ m ∈ Finset.Ico 1 b, (m : ℝ) ^ 2) =
          (↑(a * q) : ℝ) * (↑(a * q) + 1) * (2 * ↑(a * q) + 1) := by
        rw [show b = a * q + 1 from haq_eq.symm]
        exact sum_Ico_sq_R (a * q)
      -- Step 3: Transform floor sum via bijection
      have hX : (∑ m ∈ Finset.Ico 1 b, (m : ℝ) * ((m * a / b : ℕ) : ℝ)) =
          (∑ p ∈ (Finset.range a) ×ˢ (Finset.Ico 1 (q + 1)),
            ((p.1 * q + p.2 : ℕ) : ℝ) * (p.1 : ℝ)) := by
        rw [show b = a * q + 1 from haq_eq.symm]
        -- Goal has a*q+1 in both Ico and denominator. Lemma has a*q+1 in Ico but q*a+1 in denom.
        -- Rewrite just the denominator:
        conv_lhs => arg 2; ext m; rw [show a * q + 1 = q * a + 1 from by ring]
        exact weighted_floor_sum_bij a q (by omega) ha_q
      rw [hX]
      -- Step 4: Expand product sum into iterated sums.
      -- Directly prove the split using sum_product'.
      have hprod : (∑ p ∈ (Finset.range a) ×ˢ (Finset.Ico 1 (q + 1)),
          ((p.1 * q + p.2 : ℕ) : ℝ) * (p.1 : ℝ)) =
          ∑ j ∈ Finset.range a, ∑ t ∈ Finset.Ico 1 (q + 1),
            ((j * q + t : ℕ) : ℝ) * (j : ℝ) :=
        Finset.sum_product' (Finset.range a) (Finset.Ico 1 (q + 1))
          (fun j t => ((j * q + t : ℕ) : ℝ) * (j : ℝ))
      rw [hprod]
      -- Goal now has: Σ_{j ∈ range a} Σ_{t ∈ Ico 1 (q+1)} ((jq+t):ℝ) * (j:ℝ)
      -- = Σ_j (j:ℝ) * Σ_t ((jq+t):ℝ)... but direction reversed.
      -- Actually sum_product' gives: Σ_a Σ_b f(a,b) form.
      -- The inner sum: Σ_{t ∈ Ico 1 (q+1)} ((jq+t):ℝ)·j = j·Σ_t (jq+t)
      -- = j·(jq² + q(q+1)/2)
      -- Use sum formulas for range and Ico to evaluate.
      -- Step 5: Evaluate inner sum and factor
      -- Use sum_range_sq_R and sum_range_id_R for the outer sum.
      -- This is complex; let me use nlinarith with all the sum formulas.
      have hSq_range : 6 * (∑ j ∈ Finset.range a, (j : ℝ) ^ 2) =
          (a : ℝ) * (↑a - 1) * (2 * ↑a - 1) := sum_range_sq_R a
      have hId_range : 2 * (∑ j ∈ Finset.range a, (j : ℝ)) =
          (a : ℝ) * (↑a - 1) := sum_range_id_R a
      -- Inner sum: Σ_{t=1}^q (jq+t) = jq² + q(q+1)/2
      -- In ℝ: 2·Σ_{t=1}^q (jq+t) = 2jq² + q(q+1)
      have hIco_id : 2 * (∑ t ∈ Finset.Ico 1 (q + 1), (t : ℝ)) =
          (q : ℝ) * (↑q + 1) := by
        rw [← Nat.cast_sum]
        have h := Finset.sum_range_id_mul_two (q + 1)
        simp only [Nat.add_sub_cancel] at h
        have h_ins : Finset.range (q + 1) = insert 0 (Finset.Ico 1 (q + 1)) := by
          ext x; simp [Finset.mem_range, Finset.mem_Ico]; omega
        rw [h_ins, Finset.sum_insert (by simp)] at h; simp at h
        norm_cast; linarith
      -- For the final step: 12C = 12a·Σm² - 12b·X
      -- = 2a·(aq)(aq+1)(2aq+1) - 12(qa+1)·X
      -- where 12X = 12·Σ_j (j·inner) and inner evaluation gives:
      -- X = q²Σj² + q(q+1)/2·Σj
      -- 12X = 2q²·a(a-1)(2a-1) + 3q(q+1)·a(a-1)  [from sum formulas]
      -- So 12bX = (qa+1)·[2q²a(a-1)(2a-1) + 3q(q+1)a(a-1)]
      -- And 12C = 2a²q(qa+1)(2qa+1) - (qa+1)a(a-1)(2q²(2a-1)+3q(q+1))
      -- = q(qa+1)(3qa²+3a-a²+qa) [ring verified]
      -- Normalize casts in hSq:
      simp only [Nat.cast_mul] at hSq
      -- Decompose ↑(j*q+t)*↑j → ↑j²*↑q + ↑j*↑t in the goal:
      simp_rw [show ∀ j t : ℕ, ((j * q + t : ℕ) : ℝ) * (j : ℝ) =
        ((j : ℝ)^2 * ↑q + ↑j * ↑t) from fun j t => by push_cast; ring]
      -- Split the inner sum using linearity:
      simp_rw [Finset.sum_add_distrib]
      -- Factor out j-independent terms from inner sums:
      simp_rw [← Finset.mul_sum, ← Finset.sum_mul]
      -- Now the goal has: Σj² * (Σ ↑q) + Σj * Σt = simple sums
      -- Evaluate constant sum: Σ_{t ∈ Ico 1 (q+1)} ↑q = q * q
      have hconst : (∑ _ ∈ Finset.Ico 1 (q + 1), (q : ℝ)) = (q : ℝ) * ↑q := by
        simp [Finset.sum_const, Nat.card_Ico]
      simp_rw [hconst]
      -- Normalize hSq: rewrite b → q*a+1 and push ℕ cast
      rw [hb_eq] at hSq
      -- hSq already normalized by simp [Nat.cast_mul] and rw [hb_eq]
      rw [show b = q * a + 1 from hb_eq]
      push_cast
      -- Set abbreviations for the sums:
      set S := ∑ m ∈ Finset.Ico 1 (q * a + 1), (m : ℝ) ^ 2
      set R := ∑ j ∈ Finset.range a, (j : ℝ) ^ 2
      set I := ∑ j ∈ Finset.range a, (j : ℝ)
      set T := ∑ t ∈ Finset.Ico 1 (q + 1), (t : ℝ)
      -- Now: hSq : 6*S = (q*a)*(q*a+1)*(2*q*a+1)  [approximately, modulo casts]
      --       hSq_range : 6*R = a*(a-1)*(2*a-1)
      --       hId_range : 2*I = a*(a-1)
      --       hIco_id : 2*T = q*(q+1)
      -- Goal: 12*(a*S - (q*a+1)*(R*q*q + I*T)) = q*(q*a+1)*(3*q*a²+3*a-a²+q*a)
      -- This is: 12aS - 12(qa+1)(Rq² + IT) = polynomial
      -- Substituting: S = qa(qa+1)(2qa+1)/6, R = a(a-1)(2a-1)/6, I = a(a-1)/2, T = q(q+1)/2
      -- 12aS = 2a·qa(qa+1)(2qa+1) = 2a²q(qa+1)(2qa+1)
      -- 12(qa+1)(Rq²+IT) = 12(qa+1)(a(a-1)(2a-1)q²/6 + a(a-1)q(q+1)/4)
      --                   = (qa+1)a(a-1)(2q²(2a-1) + 3q(q+1))
      -- Difference = q(qa+1)(3qa²+3a-a²+qa)  [by ring]
      -- Close via nlinarith with cross-product hints:
      -- Strategy: substitute ALL sum values and close with ring.
      -- From hypotheses: S = qa(qa+1)(2qa+1)/6, R = a(a-1)(2a-1)/6, I = a(a-1)/2, T = q(q+1)/2
      -- Goal: 12(aS - (qa+1)(Rq²+IT)) = q(qa+1)(3qa²+3a-a²+qa)
      -- Suffices: prove the goal * 6, i.e. 72(aS-bX) = 6*q*(qa+1)*(3qa²+3a-a²+qa)
      -- where 6*12aS = 72aS = 12a*6S = 12a*qa(qa+1)(2qa+1)
      -- and 6*12bX = 72b(Rq²+IT) = 12b(6Rq²+6IT) = 12b(a(a-1)(2a-1)q² + 3/2*a(a-1)*q(q+1))
      -- Actually, let's work with the field_simp approach:
      -- S = h1.RHS/(2*6), etc. But this introduces division.
      -- Better: work with 12S = 2*h1.RHS/a = 2*qa(qa+1)(2qa+1)
      -- Hmm, this is getting circular.
      --
      -- CLEANEST APPROACH: use suffices to replace the goal with a polynomial identity,
      -- then close with ring.
      suffices hsuff :
          12 * ((a : ℝ) * S - ((q : ℝ) * a + 1) * (R * (q * q) + I * T)) =
          (q : ℝ) * (q * a + 1) * (3 * q * a ^ 2 + 3 * a - a ^ 2 + q * a) by
        linarith
      -- Now substitute S, R using the 6* formulas and I, T using the 2* formulas:
      -- 12aS = 2a * (6S) = 2a * (qa(qa+1)(2qa+1))
      -- 12Rq² = 2q² * (6R) = 2q² * a(a-1)(2a-1)
      -- 12IT = 3 * (4IT) = 3 * (2I)(2T) = 3 * a(a-1) * q(q+1)
      -- 12(qa+1)(Rq²+IT) = (qa+1)(2q²*a(a-1)(2a-1) + 3*a(a-1)*q(q+1))
      -- LHS = (qa+1)(2a²q(2qa+1) - a(a-1)(2q²(2a-1)+3q(q+1)))
      -- Expand: ... = q(qa+1)(3qa²+3a-a²+qa) [ring identity]
      -- We need to express 12*a*S in terms of the 6*S formula:
      have hs6 : 6 * S = (q : ℝ) * a * (q * a + 1) * (2 * (q * a) + 1) := by linarith
      have hr6 : 6 * R = (a : ℝ) * (a - 1) * (2 * a - 1) := hSq_range
      have hi2 : 2 * I = (a : ℝ) * (a - 1) := hId_range
      have ht2 : 2 * T = (q : ℝ) * (q + 1) := hIco_id
      -- We need: 12*(a*S - (qa+1)*(R*q² + I*T))
      -- = 2*a*(6*S) - (qa+1)*(2*q²*(6*R) + 3*(2*I)*(2*T))
      -- But this isn't exactly right — we need to factor 12 into the terms.
      -- 12*a*S = 2*a*(6*S)  ✓
      -- 12*(qa+1)*R*q² = 2*(qa+1)*q²*(6*R)  ✓
      -- 12*(qa+1)*I*T = 3*(qa+1)*(2*I)*(2*T)  ... ✗, 12IT ≠ 3*(2I)(2T) = 12IT ✓!
      -- Actually: 12*I*T = 3*4*I*T = 3*(2I)*(2T). Yes!
      -- So: 12(a*S - (qa+1)(R*q²+I*T)) = 2a(6S) - (qa+1)(2q²(6R) + 3(2I)(2T))
      -- = 2a(6S) - (qa+1)(2q²(6R)) - 3(qa+1)(2I)(2T)
      -- Substitute hs6, hr6, hi2, ht2:
      -- = 2a*qa(qa+1)(2qa+1) - 2(qa+1)q²*a(a-1)(2a-1) - 3(qa+1)*a(a-1)*q(q+1)
      -- = (qa+1)[2a²q(2qa+1) - 2q²a(a-1)(2a-1) - 3a(a-1)q(q+1)]
      -- = q(qa+1)(3qa²+3a-a²+qa) [ring verified]
      -- Express using intermediate variables:
      have key : 12 * ((a : ℝ) * S - ((q : ℝ) * a + 1) * (R * (q * q) + I * T)) =
          2 * (a : ℝ) * (6 * S) -
          2 * ((q : ℝ) * a + 1) * ((q : ℝ) * q) * (6 * R) -
          3 * ((q : ℝ) * a + 1) * (2 * I) * (2 * T) := by ring
      rw [key, hs6, hr6, hi2, ht2]
      ring
    -- Now close algebraically:
    -- From h_cs: 12b²·s = 12Cb - 3b²(b-1)
    -- Need: 12ab·s = a²+b²+1-b(a²+2)
    -- Multiply by b: 12ab²·s = b(a²+b²+1-b(a²+2))
    -- From h_cs·a: a(12b²·s) = a(12Cb-3b²(b-1))
    -- So: 12ab²·s = 12aCb - 3ab²(b-1)
    -- Need: 12aCb - 3ab²(b-1) = b(a²+b²+1-b(a²+2))
    -- This is a ring identity when 12C = polynomial [verified].
    have hb_ne : (b : ℝ) ≠ 0 := by positivity
    suffices h : (b : ℝ) * (12 * (a : ℝ) * b * dedekindSum a b) =
        (b : ℝ) * ((a : ℝ)^2 + (b : ℝ)^2 + 1 - b * ((a : ℝ)^2 + 1 + 1)) by
      exact mul_left_cancel₀ hb_ne h
    -- b · 12ab·s = 12ab²s = a(12Cb-3b²(b-1)) [from h_cs]
    have h_mul : 12 * (a : ℝ) * (b : ℝ)^2 * dedekindSum a b =
        (a : ℝ) * (12 * Cb - 3 * (b : ℝ)^2 * ((b : ℝ) - 1)) := by nlinarith [h_cs]
    -- Substitute b = qa+1 and 12Cb = polynomial, close with ring
    calc (b : ℝ) * (12 * (a : ℝ) * b * dedekindSum a b)
        = 12 * (a : ℝ) * (b : ℝ)^2 * dedekindSum a b := by ring
      _ = (a : ℝ) * (12 * Cb - 3 * (b : ℝ)^2 * ((b : ℝ) - 1)) := h_mul
      _ = (b : ℝ) * ((a : ℝ)^2 + (b : ℝ)^2 + 1 - b * ((a : ℝ)^2 + 1 + 1)) := by
            rw [hC]; push_cast [hb_eq]; ring
  · -- INDUCTIVE CASE: r ≥ 2
    -- Strategy: expand both s(a,b) and s(a,r) via cross-sum, then combine
    -- using cross_sum_decomp + sum-of-squares + weighted_floor_euclidean.
    have hr2 : 1 < b % a := by omega
    -- Set up variables
    set r := b % a with hr_def
    set q := b / a with hq_def
    have hb_eq : b = q * a + r := by
      have h := Nat.div_add_mod b a  -- a * (b / a) + b % a = b
      -- After set: b / a = q, b % a = r, so h : a * q + r = b
      change a * q + r = b at h; linarith [mul_comm a q]
    -- Coprimality: gcd(a,r) = gcd(a, b%a) = gcd(a,b) = 1
    have hcop_r : Nat.Coprime a r := by
      rw [hr_def]; unfold Nat.Coprime; rw [Nat.gcd_comm, ← Nat.gcd_rec]; exact hcop
    -- Positivity

    have hb_ne : (b : ℝ) ≠ 0 := by positivity
    have hr_ne : (r : ℝ) ≠ 0 := by positivity
    have hbr_ne : (b : ℝ) * (r : ℝ) ≠ 0 := mul_ne_zero hb_ne hr_ne
    have hr_lt_a : r < a := Nat.mod_lt b (by omega)
    -- Cross-sum for s(a,b): 12b²·s(a,b) = 12·Cb - 3b²(b-1)
    have h_csb := dedekindSum_cross_sum a b hb hcop.symm
    -- Cross-sum for s(a,r): 12r²·s(a,r) = 12·Cr - 3r²(r-1)
    have h_csr := dedekindSum_cross_sum a r hr2 hcop_r.symm
    -- Set the cross-sums
    set Cb := ∑ m ∈ Finset.Ico 1 b, (m : ℝ) * ((m * a % b : ℕ) : ℝ) with hCb_def
    set Cr := ∑ m ∈ Finset.Ico 1 r, (m : ℝ) * ((m * a % r : ℕ) : ℝ) with hCr_def
    -- Cross-sum decompositions: C = a·Σm² - b·X
    have hdecomp_b := cross_sum_decomp a b
    have hdecomp_r := cross_sum_decomp a r
    -- Set the weighted floor sums
    set Xb := ∑ m ∈ Finset.Ico 1 b, (m : ℝ) * ((m * a / b : ℕ) : ℝ) with hXb_def
    set Xr := ∑ m ∈ Finset.Ico 1 r, (m : ℝ) * ((m * a / r : ℕ) : ℝ) with hXr_def
    -- Set the sum-of-squares
    set Sb := ∑ m ∈ Finset.Ico 1 b, (m : ℝ) ^ 2 with hSb_def
    set Sr := ∑ m ∈ Finset.Ico 1 r, (m : ℝ) ^ 2 with hSr_def
    -- From decompositions:
    have hCb_eq : Cb = (a : ℝ) * Sb - (b : ℝ) * Xb := hdecomp_b
    have hCr_eq : Cr = (a : ℝ) * Sr - (r : ℝ) * Xr := hdecomp_r
    -- Sum-of-squares formulas: 6·Σm² = (n-1)·n·(2n-1)  [for Ico 1 n]
    -- sum_Ico_sq_R gives: 6 * Σ_{Ico 1 (n+1)} m² = n*(n+1)*(2n+1)
    -- For Ico 1 b we need n = b-1: 6*Sb = (b-1)*b*(2b-1)
    have hSb_eq : 6 * Sb = ((b : ℝ) - 1) * b * (2 * b - 1) := by
      have h := sum_Ico_sq_R (b - 1)
      simp only [show b - 1 + 1 = b from by omega] at h
      -- h : 6 * ∑ ... = ↑(b-1) * (↑(b-1)+1) * (2*↑(b-1)+1)
      -- Goal: 6 * Sb = (↑b - 1) * ↑b * (2*↑b - 1)
      -- These are equal since ↑(b-1) = ↑b - 1 for b ≥ 2.
      have hcast : ((b - 1 : ℕ) : ℝ) = (b : ℝ) - 1 := by
        rw [Nat.cast_sub (by omega : 1 ≤ b)]; simp
      rw [hcast] at h; linarith
    have hSr_eq : 6 * Sr = ((r : ℝ) - 1) * r * (2 * r - 1) := by
      have h := sum_Ico_sq_R (r - 1)
      simp only [show r - 1 + 1 = r from by omega] at h
      have hcast : ((r - 1 : ℕ) : ℝ) = (r : ℝ) - 1 := by
        rw [Nat.cast_sub (by omega : 1 ≤ r)]; simp
      rw [hcast] at h; linarith
    -- Key floor-sum identity: 12(r·Xb - b·Xr) = q·[a²(4rb-1) - br(3a+1) + 1]
    have hfloor := weighted_floor_euclidean a r q (by omega) hr2 hr_lt_a hcop_r
    -- In hfloor, b is defined as q*a+r, which matches our b by hb_eq.
    -- We need to verify that the sums in hfloor match our Xb, Xr.
    -- hfloor uses let b := q * a + r, and our b satisfies b = q*a+r.
    have hfloor' : 12 * ((r : ℝ) * Xb - (b : ℝ) * Xr) =
        (q : ℝ) * ((a : ℝ)^2 * (4 * r * b - 1) - (b : ℝ) * r * (3 * a + 1) + 1) := by
      have hb_rw : q * a + r = b := by omega
      simp only [hb_rw] at hfloor; exact hfloor
    -- Now multiply the goal by b*r to clear denominators:
    -- Goal: 12abr(s(a,b)-s(a,r)) = r(a²+b²+1) - b(a²+r²+1)
    -- Suffices: br · LHS = br · RHS, then cancel br.
    suffices hsuff : (b : ℝ) * (r : ℝ) *
        (12 * (a : ℝ) * b * r * (dedekindSum a b - dedekindSum a r)) =
        (b : ℝ) * (r : ℝ) *
        ((r : ℝ) * ((a : ℝ)^2 + (b : ℝ)^2 + 1) -
         (b : ℝ) * ((a : ℝ)^2 + (r : ℝ)^2 + 1)) by
      exact mul_left_cancel₀ hbr_ne hsuff
    -- LHS = br·12abr·(s-s') = 12ab²r²·s(a,b) - 12ab²r²·s(a,r)
    --      = ar²·(12b²·s(a,b)) - ab²·(12r²·s(a,r))
    --      = ar²·(12Cb-3b²(b-1)) - ab²·(12Cr-3r²(r-1))
    -- Express using cross-sums:
    -- Express br·LHS in terms of cross-sums, then substitute and close with ring.
    -- br·12abr·(s-s') = ar²·(12b²s) - ab²·(12r²s')  [by ring]
    -- = ar²·(12Cb-3b²(b-1)) - ab²·(12Cr-3r²(r-1))  [by h_csb, h_csr]
    -- = 12a(r²Cb-b²Cr) - 3ab²r²(b-r)  [simplify]
    -- Substituting Cb = aSb-bXb, Cr = aSr-rXr:
    -- = 12a²(r²Sb-b²Sr) - 12abr(rXb-bXr) - 3ab²r²(b-r)
    -- Using sum-of-squares + floor identity + b-r=qa, close with ring.
    have hbr_eq : (b : ℝ) - (r : ℝ) = (q : ℝ) * (a : ℝ) := by push_cast [hb_eq]; ring
    -- Combine all ingredients: key (ring), h_csb, h_csr, hdecomp_b/r, hSb_eq, hSr_eq,
    -- hfloor', hbr_eq → close with ring.
    -- Step 1: Rewrite LHS using key identity (ring)
    have key : (b : ℝ) * r * (12 * (a : ℝ) * b * r *
        (dedekindSum a b - dedekindSum a r)) =
        (a : ℝ) * r^2 * (12 * (b : ℝ)^2 * dedekindSum a b) -
        (a : ℝ) * b^2 * (12 * (r : ℝ)^2 * dedekindSum a r) := by ring
    rw [key]
    -- Step 2: Substitute cross-sum formulas
    rw [h_csb, h_csr]
    -- Step 3: Substitute cross-sum decompositions
    rw [show Cb = (a : ℝ) * Sb - (b : ℝ) * Xb from hdecomp_b,
        show Cr = (a : ℝ) * Sr - (r : ℝ) * Xr from hdecomp_r]
    -- Step 4: Factor and substitute sum formulas + floor identity + b-r=qa
    -- The goal is now a polynomial identity in Sb, Sr, Xb, Xr, a, b, r.
    -- Express in terms of (6*Sb), (6*Sr), 12*(r*Xb-b*Xr), (b-r):
    have hkey_rw : (a : ℝ) * r^2 *
        (12 * ((a : ℝ) * Sb - (b : ℝ) * Xb) - 3 * b^2 * (b - 1)) -
        (a : ℝ) * b^2 *
        (12 * ((a : ℝ) * Sr - (r : ℝ) * Xr) - 3 * r^2 * (r - 1)) =
        2 * a^2 * (r^2 * (6 * Sb) - b^2 * (6 * Sr)) -
        a * b * r * (12 * (r * Xb - b * Xr)) -
        3 * a * b^2 * r^2 * (b - r) := by ring
    -- After these rewrites, goal is a polynomial in a, b, r, q.
    -- To close with ring, we need b = qa + r substituted:
    have hb_cast : (b : ℝ) = (q : ℝ) * (a : ℝ) + (r : ℝ) := by push_cast [hb_eq]; ring
    rw [hkey_rw, hSb_eq, hSr_eq, hfloor', hbr_eq, hb_cast]
    ring


end Cathedral.Physics.DedekindBridge

end
