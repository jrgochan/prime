/-
  AbelTailProof.lean — Scratch file for abel_mertens_tail_raw

  REUSES CATHEDRAL INFRASTRUCTURE:
  - AbelSummation.lean: abel_summation, abel_summation_abs_bound (PROVED)
  - AbelEngine.lean: tendsto_extract_bound, tendsto_universal_bound (PROVED)
  - FractIntegral.lean: HasDerivAt + integral_eq_sub_of_hasDerivAt pattern (BLUEPRINT)
  - MertensIntegral.lean: convergent_log_series_bound, log domination (PROVED)

  THE THEORIST'S 3 BYPASSES:
  A. Shifted Rectangle: k^{-5/4} ≤ ∫_{k-1}^k t^{-5/4} dt = 4·((k-1)^{-1/4} - k^{-1/4})
  B. Casting Firewall: Abstract Mertens ℤ→ℝ coercion once
  C. Antiderivative Hack: F(t) = -4·t^{-1/4}, F'(t) = t^{-5/4}
-/

import Cathedral.Assembly.AbelEngine
import Cathedral.MellinBridge.AbelSummation
import Cathedral.MellinBridge.MertensBound
import Cathedral.MellinBridge.MertensIntegral
import Cathedral.Defs

noncomputable section
open Real Finset BigOperators

-- ════════════════════════════════════════════════
-- §0. CASTING FIREWALL (Bypass B — Theorist directive)
-- Pay the coercion tax ONCE.
-- ════════════════════════════════════════════════

/-- Mertens bound in pure ℝ form. -/
private lemma mertens_bound_real
    (C_m : ℝ) (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (k : ℕ) (hk : 2 ≤ k) :
    |((mertensFunction (k : ℝ) : ℤ) : ℝ)| ≤ C_m * (k : ℝ) ^ ((3:ℝ)/4) :=
  hMertens (k : ℝ) (by exact_mod_cast hk)

-- ════════════════════════════════════════════════
-- §1. ANTIDERIVATIVE HACK (Bypass C)
-- F(t) = -4·t^{-1/4}, so F'(t) = t^{-5/4}
-- Pattern from FractIntegral.lean:interval_sub_div_sq (lines 48-87)
-- ════════════════════════════════════════════════

/-- The antiderivative: F(t) = -4·t^{1/4} has derivative t^{-5/4} ÷ something...
    Actually: d/dt(-4·t^{-1/4}) = d/dt(-4·t^{(-1/4)}) = -4·(-1/4)·t^{-5/4} = t^{-5/4}

    For rpow: d/dt(t^p) = p·t^{(p-1)} when t > 0.
    With p = -1/4: d/dt(t^{-1/4}) = (-1/4)·t^{-5/4}.
    So d/dt(-4·t^{-1/4}) = -4·(-1/4)·t^{-5/4} = t^{-5/4}. ✓ -/
private lemma hasDerivAt_neg4_rpow (x : ℝ) (hx : 0 < x) :
    HasDerivAt (fun t => -4 * t ^ (-(1:ℝ)/4)) (x ^ (-(5:ℝ)/4)) x := by
  -- d/dx(-4·x^{-1/4}) = -4·(-1/4)·x^{-5/4} = x^{-5/4}
  have h1 := Real.hasDerivAt_rpow_const (Or.inl (ne_of_gt hx)) (p := -(1:ℝ)/4)
  -- h1 : HasDerivAt (· ^ (-(1:ℝ)/4)) (-(1:ℝ)/4 * x ^ (-(1:ℝ)/4 - 1)) x
  convert h1.const_mul (-4) using 1
  -- Goal: x ^ (-(5:ℝ)/4) = -4 * (-(1:ℝ)/4 * x ^ (-(1:ℝ)/4 - 1))
  have : -(1:ℝ)/4 - 1 = -(5:ℝ)/4 := by ring
  rw [this]; ring

-- ════════════════════════════════════════════════
-- §2. SHIFTED RECTANGLE TRICK (Bypass A)
-- k^{-5/4} ≤ ∫_{k-1}^{k} t^{-5/4} dt = 4·((k-1)^{-1/4} - k^{-1/4})
-- Because t^{-5/4} is decreasing, k^{-5/4} is the MINIMUM on [k-1, k].
-- ════════════════════════════════════════════════

/-- The integral evaluation: ∫_{a}^{b} t^{-5/4} dt = -4·b^{-1/4} + 4·a^{-1/4}.
    Direct from hasDerivAt_neg4_rpow + FTC.
    Pattern: FractIntegral.lean:integral_div_sub_const_on_piece. -/
private lemma integral_rpow_54 (a b : ℝ) (ha : 0 < a) (hab : a ≤ b) :
    ∫ t in a..b, t ^ (-(5:ℝ)/4) =
    -4 * b ^ (-(1:ℝ)/4) + 4 * a ^ (-(1:ℝ)/4) := by
  have hb : 0 < b := lt_of_lt_of_le ha hab
  have hF : ∀ t ∈ Set.uIcc a b, HasDerivAt (fun t => -4 * t ^ (-(1:ℝ)/4))
      (t ^ (-(5:ℝ)/4)) t := by
    intro t ht
    rw [Set.uIcc_of_le hab] at ht
    exact hasDerivAt_neg4_rpow t (lt_of_lt_of_le ha ht.1)
  have hint : IntervalIntegrable (fun t => t ^ (-(5:ℝ)/4)) MeasureTheory.volume a b := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.rpow continuousOn_id continuousOn_const
    intro t ht; left; rw [Set.uIcc_of_le hab] at ht; exact ne_of_gt (lt_of_lt_of_le ha ht.1)
  rw [intervalIntegral.integral_eq_sub_of_hasDerivAt hF hint]
  ring

/-- The rectangle bound: k^{-5/4} ≤ 4·((k-1)^{-1/4} - k^{-1/4}) for k ≥ 2.
    Because t^{-5/4} is decreasing, k^{-5/4} = min value on [k-1, k].

    Uses: ∫_{k-1}^{k} t^{-5/4} dt = 4·((k-1)^{-1/4} - k^{-1/4}) [antiderivative]
          k^{-5/4} ≤ ∫_{k-1}^{k} t^{-5/4} dt  [rectangle bound] -/
private lemma rpow_54_le_integral (k : ℕ) (hk : 2 ≤ k) :
    (k : ℝ) ^ (-(5:ℝ)/4) ≤
    4 * (((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4)) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hkm1_pos : (0 : ℝ) < (k : ℝ) - 1 := by
    have : (2 : ℝ) ≤ (k : ℝ) := Nat.ofNat_le_cast.mpr hk
    linarith
  have hle : (k : ℝ) - 1 ≤ (k : ℝ) := by linarith
  -- Step 1: Evaluate the integral via antiderivative
  have h_int := integral_rpow_54 ((k:ℝ) - 1) (k:ℝ) hkm1_pos hle
  -- h_int : ∫ t in (k-1)..k, t^{-5/4} = -4·k^{-1/4} + 4·(k-1)^{-1/4}
  -- Rearrange: = 4·((k-1)^{-1/4} - k^{-1/4})
  have h_int' : ∫ t in ((k:ℝ) - 1)..(k:ℝ), t ^ (-(5:ℝ)/4) =
      4 * (((k:ℝ) - 1) ^ (-(1:ℝ)/4) - (k:ℝ) ^ (-(1:ℝ)/4)) := by
    rw [h_int]; ring
  -- Step 2: Rectangle bound: k^{-5/4} ≤ ∫_{k-1}^k t^{-5/4} dt
  -- Because t ≤ k on [k-1, k], so t^{-5/4} ≥ k^{-5/4}
  suffices h : (k : ℝ) ^ (-(5:ℝ)/4) ≤ ∫ t in ((k:ℝ) - 1)..(k:ℝ), t ^ (-(5:ℝ)/4) by
    linarith [h_int']
  -- k^{-5/4} = ∫_{k-1}^k k^{-5/4} dt (constant function, interval length 1)
  -- ≤ ∫_{k-1}^k t^{-5/4} dt (since t ≤ k ⇒ t^{-5/4} ≥ k^{-5/4})
  have h_const_eq : ∫ t in ((k:ℝ) - 1)..(k:ℝ), (k : ℝ) ^ (-(5:ℝ)/4) =
      (k : ℝ) ^ (-(5:ℝ)/4) := by
    rw [intervalIntegral.integral_const]; simp [sub_sub_cancel]
  rw [← h_const_eq]
  have hint_rpow : IntervalIntegrable (fun t => t ^ (-(5:ℝ)/4)) MeasureTheory.volume
      ((k:ℝ) - 1) (k:ℝ) := by
    apply ContinuousOn.intervalIntegrable
    apply ContinuousOn.rpow continuousOn_id continuousOn_const
    intro t ht
    left
    rw [Set.uIcc_of_le hle] at ht
    exact ne_of_gt (lt_of_lt_of_le hkm1_pos ht.1)
  apply intervalIntegral.integral_mono_on (by linarith)
    (intervalIntegrable_const) hint_rpow
  intro t ht
  -- ht : t ∈ Set.Icc (k-1) k, so t ≤ k and t ≥ k-1 > 0
  have ht_pos : 0 < t := lt_of_lt_of_le hkm1_pos ht.1
  -- t ≤ k, so t^{-5/4} ≥ k^{-5/4} (rpow reverses for negative exponent)
  exact Real.rpow_le_rpow_of_nonpos ht_pos ht.2 (by norm_num)

/-- Finite telescoping sum: Σ_{k=N+1}^{M} k^{-5/4} ≤ 4·N^{-1/4} for N ≥ 1.
    Each term telescopes via rpow_54_le_integral, then the sum telescopes. -/
private lemma finite_rpow_54_tail_bound (N M : ℕ) (hN : 1 ≤ N) (hNM : N + 1 ≤ M) :
    (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4)) ≤
    4 * (N : ℝ) ^ (-(1:ℝ)/4) := by
  -- Each k^{-5/4} ≤ 4·((k-1)^{-1/4} - k^{-1/4}) for k ≥ 2
  -- Use (k:ℝ)-1 form and bridge via cast lemma
  have hbridge : ∀ k : ℕ, N + 1 ≤ k → k ≤ M →
      (k : ℝ) ^ (-(5:ℝ)/4) ≤
      4 * (((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4)) := by
    intro k hk _
    exact rpow_54_le_integral k (by omega)
  calc (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4))
      ≤ (Icc (N+1) M).sum (fun k =>
        4 * (((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4))) := by
        apply Finset.sum_le_sum
        intro k hk
        rw [Finset.mem_Icc] at hk
        exact hbridge k hk.1 hk.2
    _ = 4 * (Icc (N+1) M).sum (fun k =>
        ((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4)) := by
        rw [← Finset.mul_sum]
    _ ≤ 4 * (N : ℝ) ^ (-(1:ℝ)/4) := by
        -- The sum telescopes: Σ_{k=N+1}^M (f(k-1) - f(k)) = f(N) - f(M)
        apply mul_le_mul_of_nonneg_left _ (by norm_num : (0:ℝ) ≤ 4)
        -- Need: Σ(f(k-1) - f(k)) ≤ N^{-1/4}
        -- The sum telescopes to N^{-1/4} - M^{-1/4} ≤ N^{-1/4}
        -- Prove by induction on the Icc range
        suffices htel : (Icc (N+1) M).sum (fun k =>
            ((k : ℝ) - 1) ^ (-(1:ℝ)/4) - (k : ℝ) ^ (-(1:ℝ)/4)) =
            (N : ℝ) ^ (-(1:ℝ)/4) - (M : ℝ) ^ (-(1:ℝ)/4) by
          rw [htel]
          have : 0 ≤ (M : ℝ) ^ (-(1:ℝ)/4) := by positivity
          linarith
        -- Prove the telescoping identity by induction
        have hle : N + 1 ≤ M := hNM
        -- Induction on the difference M - (N+1)
        obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hle
        induction d with
        | zero =>
          simp [Finset.Icc_self]
        | succ n ih =>
          rw [show N + 1 + (n + 1) = N + 1 + n + 1 from by omega]
          rw [Finset.sum_Icc_succ_top (by omega : N + 1 ≤ N + 1 + n + 1)]
          have ih' := ih (by omega) (fun k hk1 hk2 => hbridge k hk1 (by omega)) (by omega)
          rw [ih']
          push_cast; ring

-- ════════════════════════════════════════════════
-- §3. THE 1/(k(k+1)) TELESCOPING (Already in Cathedral!)
-- Reuses hasSum_telescoping_inv from FractIntegral.lean
-- ════════════════════════════════════════════════


private lemma finset_sum_tele (a d : ℕ) :
    (Icc a (a + d)).sum (fun k => 1 / (k : ℝ) - 1 / ((k : ℝ) + 1)) =
    1 / (a : ℝ) - 1 / (((a + d : ℕ) : ℝ) + 1) := by
  induction d with
  | zero => simp [Finset.Icc_self]
  | succ n ih =>
    rw [show a + (n + 1) = a + n + 1 from by omega,
        Finset.sum_Icc_succ_top (by omega : a ≤ a + n + 1), ih]
    push_cast; ring

/-- Finite telescoping bound: Σ_{k=N+1}^{M} 1/(k(k+1)) ≤ 1/(N+1).
    Uses partial fractions + finite telescoping. -/
private lemma finite_inv_kk1_bound (N M : ℕ) (hN : 1 ≤ N) (hNM : N + 1 ≤ M) :
    (Icc (N+1) M).sum (fun k => 1 / ((k : ℝ) * ((k : ℝ) + 1))) ≤
    1 / ((N : ℝ) + 1) := by
  -- 1/(k(k+1)) = 1/k - 1/(k+1)
  have hrw : (Icc (N+1) M).sum (fun k => 1 / ((k : ℝ) * ((k : ℝ) + 1))) =
      (Icc (N+1) M).sum (fun k => 1 / (k : ℝ) - 1 / ((k : ℝ) + 1)) := by
    apply Finset.sum_congr rfl
    intro k hk; rw [Finset.mem_Icc] at hk
    have : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
    field_simp; ring
  rw [hrw]
  -- Apply telescoping identity
  obtain ⟨d, rfl⟩ := Nat.exists_eq_add_of_le hNM
  rw [finset_sum_tele]
  -- Goal: 1/(↑(N+1)) - 1/(↑(N+1+d)+1) ≤ 1/(↑N + 1)
  -- Cast normalization: ↑(N+1) = ↑N + 1
  have h_cast : (1 : ℝ) / ((N + 1 : ℕ) : ℝ) = 1 / ((N : ℝ) + 1) := by push_cast; ring
  rw [h_cast]
  have h_nn : (0 : ℝ) ≤ 1 / (((N + 1 + d : ℕ) : ℝ) + 1) :=
    div_nonneg one_pos.le (by positivity)
  linarith

-- ════════════════════════════════════════════════
-- §4. THE FINITE ABEL BOUND
-- Uses abel_summation_abs_bound from AbelSummation.lean (PROVED)
-- ════════════════════════════════════════════════

-- S₁ definition (matching FinalDragon.lean)
private def S₁' (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)

/-- For any M ≥ N+1 ≥ 3, Abel summation on [N+1, M] gives:
    |S₁(M) - S₁(N)| ≤ C_m·(M^{-1/4} + N^{3/4}/M) + C_m·5·N^{-1/4}

    Proof: Apply abel_summation_abs_bound with:
    - a(k) = μ(k), f(k) = 1/k
    - A(k) = M(k) - M(N) = partial Mertens from N+1 to k
    - |A(k)| ≤ |M(k)| + |M(N)| ≤ C_m·(k^{3/4} + N^{3/4})
    - |Δf(k)| = 1/(k(k+1))
    Then: boundary ≤ C_m·(M^{-1/4} + N^{3/4}/M)
          interior ≤ C_m·(Σ k^{-5/4} + N^{3/4}·Σ 1/(k(k+1)))
                   ≤ C_m·(4N^{-1/4} + N^{3/4}·1/N) = C_m·5·N^{-1/4} -/
private lemma finite_abel_s1_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₁' M - S₁' N| ≤
      C_m * ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) +
      C_m * 5 * (N : ℝ) ^ (-(1:ℝ)/4) := by
  sorry -- Uses abel_summation_abs_bound

-- ════════════════════════════════════════════════
-- §5. THE LIMIT ARGUMENT
-- For each N, choose M large enough via PNT
-- ════════════════════════════════════════════════

/-- THE MAIN THEOREM for S₁:
    |S₁(N)| ≤ C · N^{-1/4} for N ≥ 2.

    For each N ≥ 2:
    1. From PNT (S₁ → 0), choose M ≥ N+1 with |S₁(M)| < N^{-1/4}
    2. Triangle: |S₁(N)| ≤ |S₁(M)| + |S₁(M)-S₁(N)|
    3. |S₁(M)| < N^{-1/4} (by choice of M)
    4. |S₁(M)-S₁(N)| ≤ C_m·(M^{-1/4}+N^{3/4}/M+5N^{-1/4}) ≤ 7C_m·N^{-1/4}
       (since M ≥ N+1 ≥ N: M^{-1/4} ≤ N^{-1/4}, N^{3/4}/M ≤ N^{-1/4})
    5. Total: |S₁(N)| ≤ (1+7C_m)·N^{-1/4}

    C = 1+7C_m is UNIFORM (independent of the choice of M). -/
private lemma s1_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₁ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
      Filter.atTop (nhds 0)) :
    ∃ C₁ : ℝ, C₁ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₁' N| ≤ C₁ * (N : ℝ) ^ (-(1:ℝ)/4) := by
  -- PROOF SKETCH (all components exist):
  -- 1. tendsto_extract_bound gives M₀ with |S₁(M)| < N^{-1/4} for M ≥ M₀
  -- 2. Choose M = max(N+1, M₀)
  -- 3. finite_abel_s1_diff gives |S₁(M)-S₁(N)| ≤ 7·C_m·N^{-1/4}
  -- 4. rpow_le_rpow_of_nonpos gives M^{-1/4} ≤ N^{-1/4}
  -- 5. rpow_add gives N^{3/4} = N^{-1/4}·N^1 so N^{3/4}/M ≤ N^{-1/4}
  -- 6. Triangle: |S₁(N)| ≤ (1+7C_m)·N^{-1/4}
  sorry

-- ════════════════════════════════════════════════
-- §6. S₂ AND S₃ BOUNDS (Same pattern with log weights)
-- ════════════════════════════════════════════════

-- S₂ and S₃ follow the SAME structure as S₁:
-- |S₂(N)+1| = |S₂(N)-S₂(∞)| ≤ C·N^{-1/4}·logN
-- |S₃(N)+2γ| = |S₃(N)-S₃(∞)| ≤ C·N^{-1/4}·log²N
--
-- The extra log factors come from Abel summation with f(k) = log(k)/k
-- where |Δf| involves log(k)/k² (not just 1/k²).
-- The log domination (MertensIntegral.lean:116): log(k) ≤ 8·k^{1/8}
-- converts these to k^{-9/8} type bounds that converge.
--
-- For now, S₂ and S₃ follow the same template as s1_decay.

end
