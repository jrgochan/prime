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

/-- Bridge: mertensFunction at a nat equals the Icc sum of μ.
    M(k) = Σ_{n=1}^k μ(n) for k ≥ 1. -/
private lemma mertens_eq_icc_sum (k : ℕ) (hk : 1 ≤ k) :
    ((mertensFunction (k : ℝ) : ℤ) : ℝ) =
    (Icc 1 k).sum (fun n => (↑(ArithmeticFunction.moebius n) : ℝ)) := by
  unfold mertensFunction
  push_cast
  congr 1
  ext n
  simp only [Finset.mem_filter, Finset.mem_range, Finset.mem_Icc]
  rw [Nat.floor_natCast]
  constructor
  · rintro ⟨h1, h2, h3⟩
    exact ⟨h3, by exact_mod_cast h2⟩
  · rintro ⟨h1, h2⟩
    exact ⟨by omega, by exact_mod_cast h2, h1⟩

/-- The partial sum over [N+1, k] equals M(k) - M(N). -/
private lemma partial_sum_eq_mertens_diff (N k : ℕ) (hN : 1 ≤ N) (hk : N + 1 ≤ k) :
    (Icc (N+1) k).sum (fun n => (↑(ArithmeticFunction.moebius n) : ℝ)) =
    ((mertensFunction (k:ℝ) : ℤ) : ℝ) - ((mertensFunction (N:ℝ) : ℤ) : ℝ) := by
  rw [mertens_eq_icc_sum k (by omega), mertens_eq_icc_sum N hN]
  rw [show Icc 1 k = Icc 1 N ∪ Icc (N+1) k from by
    ext x; simp [Finset.mem_Icc, Finset.mem_union]; omega]
  rw [Finset.sum_union (by
    rw [Finset.disjoint_left]; intro x hx1 hx2
    simp [Finset.mem_Icc] at hx1 hx2; omega)]
  ring

/-- For any M ≥ N+1 ≥ 3, Abel summation on [N+1, M] gives:
    |S₁(M) - S₁(N)| ≤ C_m·(M^{-1/4} + N^{3/4}/M) + C_m·5·N^{-1/4}

    Proof: Apply abel_summation_abs_bound with:
    - a(k) = μ(k), f(k) = 1/k
    - |A(k)| ≤ C_m·(k^{3/4} + N^{3/4}) via Mertens + triangle
    - |Δf(k)| = 1/(k(k+1))
    Then: boundary ≤ C_m·(M^{-1/4} + N^{3/4}/M)
          interior ≤ C_m·(Σ k^{-5/4} + N^{3/4}·Σ 1/(k(k+1)))
                   ≤ C_m·(4N^{-1/4} + N^{3/4}·1/(N+1))
                   ≤ C_m·5·N^{-1/4} -/
private lemma finite_abel_s1_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₁' M - S₁' N| ≤
      C_m * ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) +
      C_m * 5 * (N : ℝ) ^ (-(1:ℝ)/4) := by
  -- ─── Step 0: Basic positivity ───
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hM_pos : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
  -- ─── Step 1: S₁(M) - S₁(N) = Σ_{k=N+1}^M μ(k)/k ───
  have h_diff : S₁' M - S₁' N =
      (Icc (N+1) M).sum (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)) := by
    unfold S₁'
    rw [show Icc 1 M = Icc 1 N ∪ Icc (N+1) M from by
      ext k; simp [Finset.mem_Icc, Finset.mem_union]; omega]
    rw [Finset.sum_union (by
      rw [Finset.disjoint_left]; intro k hk1 hk2
      simp [Finset.mem_Icc] at hk1 hk2; omega)]
    ring
  -- ─── Step 2: Rewrite as Σ a(k)·f(k) form ───
  have h_mul : ∀ k : ℕ, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ) =
      (↑(ArithmeticFunction.moebius k) : ℝ) * (1 / (k : ℝ)) := by
    intro k; ring
  rw [h_diff, show (Icc (N+1) M).sum (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ)) =
      (Icc (N+1) M).sum (fun k => (↑(ArithmeticFunction.moebius k) : ℝ) * (1 / (k : ℝ))) from
      Finset.sum_congr rfl (fun k _ => h_mul k)]
  -- ─── Step 3: Apply abel_summation_abs_bound ───
  -- a(k) = μ(k), f(k) = 1/k, range [N+1, M]
  -- C_bound(k) = C_m · (k^{3/4} + N^{3/4})
  -- δ(k) = 1/(k(k+1))
  set a := fun k => (↑(ArithmeticFunction.moebius k) : ℝ)
  set f : ℕ → ℝ := fun k => 1 / (k : ℝ)
  set C_bound : ℕ → ℝ := fun k => C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4))
  set δ : ℕ → ℝ := fun k => 1 / ((k : ℝ) * ((k : ℝ) + 1))
  have hAbel := abel_summation_abs_bound a f (N+1) M hM C_bound δ
    -- hA: partial sum bound
    (fun k hk1 hk2 => by
      -- |A(k)| = |Σ_{j=N+1}^k μ(j)|
      -- We need: |partialSum a (N+1) k| ≤ C_m·(k^{3/4} + N^{3/4})
      -- The partialSum is Σ_{N+1}^k μ(j) = M(k) - M(N)
      -- |M(k) - M(N)| ≤ |M(k)| + |M(N)| ≤ C_m·k^{3/4} + C_m·N^{3/4}
      simp only [a, C_bound]
      -- partialSum (fun k => μ(k)) (N+1) k = (Icc (N+1) k).sum μ
      unfold partialSum
      -- Use the bridge: (Icc (N+1) k).sum μ = M(k) - M(N)
      rw [partial_sum_eq_mertens_diff N k (by omega) (by omega)]
      -- |M(k) - M(N)| ≤ |M(k)| + |M(N)|
      have hMk := hMertens (k : ℝ) (by exact_mod_cast show 2 ≤ k by omega)
      have hMN := hMertens (N : ℝ) (by exact_mod_cast hN)
      calc |((mertensFunction (k:ℝ) : ℤ) : ℝ) - ((mertensFunction (N:ℝ) : ℤ) : ℝ)|
          ≤ |((mertensFunction (k:ℝ) : ℤ) : ℝ)| + |((mertensFunction (N:ℝ) : ℤ) : ℝ)| :=
            abs_sub _ _
        _ ≤ C_m * (k : ℝ) ^ ((3:ℝ)/4) + C_m * (N : ℝ) ^ ((3:ℝ)/4) :=
            add_le_add hMk hMN
        _ = C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) := by ring)
    -- hf_mono: |f(k+1) - f(k)| ≤ δ(k)
    (fun k hk1 hk2 => by
      -- |1/(k+1) - 1/k| = 1/(k(k+1))
      simp only [f]
      have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
      have hk1_cast : ((k + 1 : ℕ) : ℝ) = (k : ℝ) + 1 := by push_cast; ring
      rw [hk1_cast]
      rw [show 1 / ((k : ℝ) + 1) - 1 / (k : ℝ) = -(1 / ((k : ℝ) * ((k : ℝ) + 1))) from by
        field_simp; ring]
      rw [abs_neg, abs_of_nonneg (by positivity)])
  -- ─── Step 4: Bound the Abel output ───
  calc |(Icc (N+1) M).sum (fun k => a k * f k)|
      ≤ C_bound M * |f M| + (Ico (N+1) M).sum (fun k => C_bound k * δ k) := hAbel
    _ ≤ C_m * ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) +
        C_m * 5 * (N : ℝ) ^ (-(1:ℝ)/4) := by
      -- Split boundary and interior
      apply add_le_add
      · -- Boundary: C_bound(M)*|f(M)| ≤ C_m*(M^{-1/4} + N^{3/4}/M)
        simp only [C_bound, f]
        rw [abs_of_nonneg (by positivity)]
        have hM_pos' : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
        rw [show C_m * ((M : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) * (1 / (M : ℝ)) =
            C_m * ((M : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) from by ring]
        gcongr
        -- M^{3/4}/M = M^{-1/4}: proved by converting M to M^1 then using rpow_sub
        have h_rpow : (M : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) = (M : ℝ) ^ (-(1:ℝ)/4) := by
          have hM34 : (M : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) ^ (1:ℝ) = (M : ℝ) ^ ((3:ℝ)/4 - 1) :=
            (Real.rpow_sub (by positivity : (0:ℝ) < (M:ℝ)) _ _).symm ▸ rfl
          rw [Real.rpow_one] at hM34
          rw [hM34]
          congr 1; ring
        rw [h_rpow]
      · -- Interior sum ≤ C_m * 5 * N^{-1/4}
        simp only [C_bound, δ]
        -- Step 1: Ico ≤ Icc for nonneg sums
        have h_ico_icc : (Ico (N+1) M).sum (fun k =>
            C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
            (1 / ((k : ℝ) * ((k : ℝ) + 1)))) ≤
          (Icc (N+1) M).sum (fun k =>
            C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
            (1 / ((k : ℝ) * ((k : ℝ) + 1)))) := by
          apply Finset.sum_le_sum_of_subset_of_nonneg Finset.Ico_subset_Icc_self
          intro k _ _
          apply mul_nonneg (mul_nonneg (by linarith) (add_nonneg (by positivity) (by positivity)))
          positivity
        -- Step 2: Factor the Icc sum into two parts
        have h_split : (Icc (N+1) M).sum (fun k =>
            C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
            (1 / ((k : ℝ) * ((k : ℝ) + 1)))) ≤
          C_m * (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4)) +
          C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / ((N : ℝ) + 1)) := by
          -- Split sum: Σ C_m*(k^{3/4}+N^{3/4})/(k(k+1))
          -- = Σ C_m*k^{3/4}/(k(k+1)) + Σ C_m*N^{3/4}/(k(k+1))
          have h_eq : (Icc (N+1) M).sum (fun k =>
              C_m * ((k : ℝ) ^ ((3:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4)) *
              (1 / ((k : ℝ) * ((k : ℝ) + 1)))) =
            (Icc (N+1) M).sum (fun k =>
              C_m * (k : ℝ) ^ ((3:ℝ)/4) / ((k : ℝ) * ((k : ℝ) + 1))) +
            (Icc (N+1) M).sum (fun k =>
              C_m * (N : ℝ) ^ ((3:ℝ)/4) / ((k : ℝ) * ((k : ℝ) + 1))) := by
            rw [← Finset.sum_add_distrib]
            apply Finset.sum_congr rfl; intro k _; ring
          rw [h_eq]
          apply add_le_add
          · -- Part 1: Σ C_m*k^{3/4}/(k(k+1)) ≤ C_m * Σ k^{-5/4}
            rw [Finset.mul_sum]
            apply Finset.sum_le_sum
            intro k hk
            rw [Finset.mem_Icc] at hk
            have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
            -- C_m * k^{3/4}/(k(k+1)) ≤ C_m * k^{-5/4}
            -- Use: k^{3/4}/(k(k+1)) ≤ k^{3/4}/k^2 = k^{-5/4}
            -- since k*(k+1) ≥ k^2 (i.e. k+1 ≥ k)
            have hkk1_ge_k2 : (k : ℝ) ^ 2 ≤ (k : ℝ) * ((k : ℝ) + 1) := by nlinarith
            have hk34_div : C_m * (k : ℝ) ^ ((3:ℝ)/4) / ((k : ℝ) * ((k : ℝ) + 1)) ≤
                C_m * (k : ℝ) ^ ((3:ℝ)/4) / (k : ℝ) ^ 2 := by
              apply div_le_div_of_nonneg_left (by positivity) (by positivity) hkk1_ge_k2
            have hk_rpow : C_m * (k : ℝ) ^ ((3:ℝ)/4) / (k : ℝ) ^ 2 =
                C_m * (k : ℝ) ^ (-(5:ℝ)/4) := by
              -- k^{3/4} / k^2 = k^{3/4} * k^{-2} = k^{3/4-2} = k^{-5/4}
              have h_k2 : (k : ℝ) ^ (2 : ℕ) = (k : ℝ) ^ (2 : ℝ) :=
                (Real.rpow_natCast _ _).symm
              rw [show (k : ℝ) ^ 2 = (k : ℝ) ^ (2 : ℕ) from by norm_num, h_k2]
              rw [div_eq_mul_inv, ← Real.rpow_neg (le_of_lt hk_pos)]
              rw [show C_m * (k : ℝ) ^ ((3:ℝ)/4) * (k : ℝ) ^ (-(2:ℝ)) =
                  C_m * ((k : ℝ) ^ ((3:ℝ)/4) * (k : ℝ) ^ (-(2:ℝ))) from by ring]
              rw [← Real.rpow_add hk_pos]
              norm_num
            linarith
          · -- Part 2: Σ C_m*N^{3/4}/(k(k+1)) ≤ C_m*N^{3/4}/(N+1)
            -- Factor out C_m * N^{3/4}
            have h_factor : (Icc (N+1) M).sum (fun k =>
                C_m * (N : ℝ) ^ ((3:ℝ)/4) / ((k : ℝ) * ((k : ℝ) + 1))) =
              C_m * (N : ℝ) ^ ((3:ℝ)/4) * (Icc (N+1) M).sum (fun k =>
                1 / ((k : ℝ) * ((k : ℝ) + 1))) := by
              rw [Finset.mul_sum]
              apply Finset.sum_congr rfl; intro k _; ring
            rw [h_factor]
            apply mul_le_mul_of_nonneg_left
              (finite_inv_kk1_bound N M (by omega) (by omega)) (by positivity)
        -- Step 3: Apply proved tail bounds
        have h_rpow := finite_rpow_54_tail_bound N M (by omega : 1 ≤ N) (by omega : N + 1 ≤ M)
        have h_N34 : C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / ((N : ℝ) + 1)) ≤
            C_m * 1 * (N : ℝ) ^ (-(1:ℝ)/4) := by
          have hN_pos' : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
          -- N^{3/4} * 1/(N+1) ≤ N^{3/4} * 1/N = N^{3/4-1} = N^{-1/4}
          -- Step: 1/(N+1) ≤ 1/N (since N ≤ N+1 and both positive)
          have h_inv : (1:ℝ) / ((N:ℝ) + 1) ≤ 1 / (N:ℝ) := by
            apply one_div_le_one_div_of_le hN_pos' (by linarith)
          have h_rpow_div : (N : ℝ) ^ ((3:ℝ)/4) / (N : ℝ) = (N : ℝ) ^ (-(1:ℝ)/4) := by
            have : (N : ℝ) ^ ((3:ℝ)/4) / (N : ℝ) =
                (N : ℝ) ^ ((3:ℝ)/4) * (N : ℝ) ^ (-(1:ℝ)) := by
              rw [Real.rpow_neg (le_of_lt hN_pos'), Real.rpow_one, div_eq_mul_inv]
            rw [this, ← Real.rpow_add hN_pos']
            congr 1; ring
          -- Assemble
          have h1 : C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / ((N : ℝ) + 1)) ≤
              C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / (N : ℝ)) :=
            mul_le_mul_of_nonneg_left h_inv (by positivity)
          have h2 : C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / (N : ℝ)) =
              C_m * 1 * (N : ℝ) ^ (-(1:ℝ)/4) := by
            rw [show C_m * (N : ℝ) ^ ((3:ℝ)/4) * (1 / (N : ℝ)) =
                C_m * ((N : ℝ) ^ ((3:ℝ)/4) / (N : ℝ)) from by ring]
            rw [h_rpow_div]; ring
          linarith
        -- Combine: ico ≤ icc ≤ C_m * 4N^{-1/4} + C_m * N^{3/4}/(N+1) ≤ C_m*5*N^{-1/4}
        have h_cm4 : C_m * (Icc (N+1) M).sum (fun k => (k : ℝ) ^ (-(5:ℝ)/4)) ≤
            C_m * (4 * (N : ℝ) ^ (-(1:ℝ)/4)) := by
          apply mul_le_mul_of_nonneg_left h_rpow (by linarith)
        linarith

-- ════════════════════════════════════════════════
-- §5. THE LIMIT ARGUMENT
-- For each N, choose M large enough via PNT
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
  use 1 + 7 * C_m
  constructor
  · linarith
  intro N hN
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have h_eps : (0 : ℝ) < (N : ℝ) ^ (-(1:ℝ)/4) := Real.rpow_pos_of_pos hN_pos _
  -- Step 1: From PNT, get M₀ with |S₁(M)| < N^{-1/4} for M ≥ M₀
  obtain ⟨M₀, hM₀⟩ := tendsto_extract_bound h_eps hPNT₁
  -- Step 2: Choose M = max(N+1, M₀)
  set M := max (N + 1) M₀
  have hM_ge_N1 : N + 1 ≤ M := le_max_left _ _
  have hM_ge_M0 : M₀ ≤ M := le_max_right _ _
  -- Step 3: |S₁(M)| < N^{-1/4}
  have hS1M : |S₁' M| ≤ (N : ℝ) ^ (-(1:ℝ)/4) := by
    have := hM₀ M hM_ge_M0; simp at this; exact this
  -- Step 4: Abel bound
  have hAbel := finite_abel_s1_diff C_m hC hMertens N M hN hM_ge_N1
  -- Step 5: M^{-1/4} ≤ N^{-1/4} and N^{3/4}/M ≤ N^{-1/4}
  have hM_ge_N : (N : ℝ) ≤ (M : ℝ) := by exact_mod_cast (show N ≤ M by omega)
  have hM_pos : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
  have h1 : (M : ℝ) ^ (-(1:ℝ)/4) ≤ (N : ℝ) ^ (-(1:ℝ)/4) :=
    Real.rpow_le_rpow_of_nonpos hN_pos hM_ge_N (show -(1:ℝ)/4 ≤ 0 by norm_num)
  have h2 : (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ) ≤ (N : ℝ) ^ (-(1:ℝ)/4) := by
    rw [div_le_iff₀ hM_pos]
    have h34 : (N : ℝ) ^ ((3:ℝ)/4) = (N : ℝ) ^ (-(1:ℝ)/4) * (N : ℝ) ^ (1:ℝ) := by
      rw [← Real.rpow_add hN_pos]; congr 1; norm_num
    rw [h34, Real.rpow_one]
    exact mul_le_mul_of_nonneg_left hM_ge_N (Real.rpow_nonneg hN_pos.le _)
  -- Step 6: Triangle + combine
  -- |S₁(N)| = |S₁(M) - (S₁(M) - S₁(N))| ≤ |S₁(M)| + |S₁(M) - S₁(N)|
  have h_tri : |S₁' N| ≤ |S₁' M| + |S₁' M - S₁' N| := by
    calc |S₁' N| = |S₁' M + (S₁' N - S₁' M)| := by ring_nf
      _ ≤ |S₁' M| + |S₁' N - S₁' M| := abs_add_le _ _
      _ = |S₁' M| + |S₁' M - S₁' N| := by rw [abs_sub_comm]
  calc |S₁' N| ≤ |S₁' M| + |S₁' M - S₁' N| := h_tri
    _ ≤ (N : ℝ) ^ (-(1:ℝ)/4) +
        (C_m * ((M : ℝ) ^ (-(1:ℝ)/4) + (N : ℝ) ^ ((3:ℝ)/4) / (M : ℝ)) +
         C_m * 5 * (N : ℝ) ^ (-(1:ℝ)/4)) := by linarith
    _ ≤ (1 + 7 * C_m) * (N : ℝ) ^ (-(1:ℝ)/4) := by nlinarith [h_eps]

-- ════════════════════════════════════════════════
-- §6. THE DISCRETE PRODUCT RULE (Theorist directive)
-- S₂ and S₃ bounds via algebraic splitting
-- ════════════════════════════════════════════════

-- S₂ definition (matching FinalDragon.lean)
private def S₂' (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    Real.log (k : ℝ) / (k : ℝ)

/-- THE FORGE: log(1 + 1/k) ≤ 1/k for k ≥ 1.
    From Mathlib: log(x) ≤ x - 1 for x > 0, applied to x = 1+1/k. -/
private lemma log_one_plus_inv_le (k : ℕ) (hk : 1 ≤ k) :
    Real.log (1 + 1/(k : ℝ)) ≤ 1/(k : ℝ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have h1k : (0 : ℝ) < 1 + 1/(k : ℝ) := by positivity
  -- log(x) ≤ x - 1 for x > 0
  have := Real.log_le_sub_one_of_pos h1k
  linarith

/-- THE FORGE: log(k+1) - log(k) ≤ 1/k for k ≥ 1.
    Consequence of log(1+1/k) ≤ 1/k. -/
private lemma log_diff_le_inv (k : ℕ) (hk : 1 ≤ k) :
    Real.log ((k : ℝ) + 1) - Real.log (k : ℝ) ≤ 1/(k : ℝ) := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_ne : ((k : ℝ) + 1) ≠ 0 := by linarith
  have hk_ne : (k : ℝ) ≠ 0 := ne_of_gt hk_pos
  calc Real.log ((k : ℝ) + 1) - Real.log (k : ℝ)
      = Real.log (((k : ℝ) + 1) / (k : ℝ)) := (Real.log_div hk1_ne hk_ne).symm
    _ = Real.log (1 + 1/(k : ℝ)) := by congr 1; field_simp
    _ ≤ 1/(k : ℝ) := log_one_plus_inv_le k hk

/-- THE FORGE: Discrete Product Rule for f₂(k) = log(k)/k.
    |log(k)/k - log(k+1)/(k+1)| ≤ (log(k) + 1)/k² -/
private lemma s2_discrete_diff_bound (k : ℕ) (hk : 2 ≤ k) :
    |Real.log (k : ℝ) / (k : ℝ) - Real.log ((k : ℝ) + 1) / ((k : ℝ) + 1)| ≤
    (Real.log (k : ℝ) + 1) / (k : ℝ) ^ 2 := by
  have hk_pos : (0 : ℝ) < (k : ℝ) := Nat.cast_pos.mpr (by omega)
  have hk1_pos : (0 : ℝ) < (k : ℝ) + 1 := by linarith
  -- Discrete Product Rule: A_k·B_k - A_{k+1}·B_{k+1}
  -- = A_k·(B_k - B_{k+1}) + B_{k+1}·(A_k - A_{k+1})
  -- where A_k = log(k), B_k = 1/k
  have h_split : Real.log (k : ℝ) / (k : ℝ) - Real.log ((k : ℝ) + 1) / ((k : ℝ) + 1) =
      Real.log (k : ℝ) * (1/(k : ℝ) - 1/((k : ℝ) + 1)) +
      1/((k : ℝ) + 1) * (Real.log (k : ℝ) - Real.log ((k : ℝ) + 1)) := by
    field_simp; ring
  rw [h_split]
  -- Triangle inequality
  calc |Real.log (k : ℝ) * (1/(k : ℝ) - 1/((k : ℝ) + 1)) +
       1/((k : ℝ) + 1) * (Real.log (k : ℝ) - Real.log ((k : ℝ) + 1))|
      ≤ |Real.log (k : ℝ) * (1/(k : ℝ) - 1/((k : ℝ) + 1))| +
        |1/((k : ℝ) + 1) * (Real.log (k : ℝ) - Real.log ((k : ℝ) + 1))| :=
          abs_add_le _ _
    _ = Real.log (k : ℝ) * |1/(k : ℝ) - 1/((k : ℝ) + 1)| +
        1/((k : ℝ) + 1) * |Real.log (k : ℝ) - Real.log ((k : ℝ) + 1)| := by
          have hlog_nn : (0:ℝ) ≤ Real.log (k : ℝ) :=
            Real.log_nonneg (by exact_mod_cast show 1 ≤ k by omega)
          have hinv_nn : (0:ℝ) ≤ 1/((k : ℝ) + 1) := by positivity
          rw [abs_mul, abs_of_nonneg hlog_nn, abs_mul, abs_of_nonneg hinv_nn]
    _ ≤ Real.log (k : ℝ) * (1/((k : ℝ) * ((k : ℝ) + 1))) +
        1/((k : ℝ) + 1) * (1/(k : ℝ)) := by
          apply add_le_add
          · apply mul_le_mul_of_nonneg_left _ (Real.log_nonneg (by exact_mod_cast show 1 ≤ k by omega))
            -- |1/k - 1/(k+1)| = 1/(k(k+1))
            rw [show 1/(k : ℝ) - 1/((k : ℝ) + 1) = 1/((k : ℝ) * ((k : ℝ) + 1)) from by
              field_simp; ring]
            rw [abs_of_nonneg (by positivity)]
          · apply mul_le_mul_of_nonneg_left _ (by positivity)
            -- |log(k) - log(k+1)| = log(k+1) - log(k) ≤ 1/k
            have h_log_nn : 0 ≤ Real.log ((k : ℝ) + 1) - Real.log (k : ℝ) :=
              sub_nonneg.mpr (Real.log_le_log hk_pos (by linarith))
            rw [show Real.log (k : ℝ) - Real.log ((k : ℝ) + 1) =
                -(Real.log ((k : ℝ) + 1) - Real.log (k : ℝ)) from by ring,
                abs_neg, abs_of_nonneg h_log_nn]
            exact log_diff_le_inv k (by omega)
    _ ≤ (Real.log (k : ℝ) + 1) / (k : ℝ) ^ 2 := by
          -- LHS = log(k)/(k(k+1)) + 1/(k(k+1))
          -- RHS = (log(k)+1)/k²
          -- Need: (log(k)+1)/(k(k+1)) ≤ (log(k)+1)/k²
          -- i.e. k² ≤ k(k+1), which is nlinarith
          have ha : (0 : ℝ) ≤ Real.log (k : ℝ) + 1 := by
            have : (1 : ℝ) ≤ (k : ℝ) := by exact_mod_cast show 1 ≤ k by omega
            linarith [Real.log_nonneg this]
          have hkk1_pos : (0 : ℝ) < (k : ℝ) * ((k : ℝ) + 1) := by positivity
          have hk2_pos : (0 : ℝ) < (k : ℝ) ^ 2 := by positivity
          have hkk1 : (k : ℝ) ^ 2 ≤ (k : ℝ) * ((k : ℝ) + 1) := by nlinarith
          -- LHS simplifies
          have h_lhs : Real.log (k : ℝ) * (1 / ((k : ℝ) * ((k : ℝ) + 1))) +
              1 / ((k : ℝ) + 1) * (1 / (k : ℝ)) =
              (Real.log (k : ℝ) + 1) / ((k : ℝ) * ((k : ℝ) + 1)) := by
            field_simp
          rw [h_lhs]
          -- Now: (log+1)/(k(k+1)) ≤ (log+1)/k²
          exact div_le_div_of_nonneg_left ha hk2_pos hkk1

-- ════════════════════════════════════════════════
-- §7. LOG-WEIGHTED TAIL SUM BOUND
-- ════════════════════════════════════════════════

/-- THE FORGE: Finite tail bound for log-weighted rpow sum.
    Σ_{k=N}^{M-1} k^{-5/4}·log(k) ≤ (4·log(N)+16)·N^{-1/4}

    Proof sketch (discrete, no integrals):
    Split log(k) = log(N) + (log(k)-log(N)) where log(k)-log(N) = Σ_{j=N}^{k-1} 1/j.
    Swap the double sum. Inner sum bounded by finite_rpow_54_tail_bound.
    The double application collapses to 4·N^{-1/4} for each.

    Alternative (Antiderivative Hack): use F₂(t) = -4t^{-1/4}·log(t) - 16t^{-1/4}
    with F₂'(t) = t^{-5/4}·log(t), then telescope via integral comparison. -/
private lemma finite_rpow_54_log_tail_bound (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    ∑ k ∈ Finset.Ico N M, (k : ℝ) ^ (-(5:ℝ)/4) * Real.log (k : ℝ) ≤
    (4 * Real.log (N : ℝ) + 16) * (N : ℝ) ^ (-(1:ℝ)/4) := by
  sorry -- THE TAIL: requires sum swap or antiderivative hack

/-- THE FORGE: Bound on Σ (log(k)+1)/k² for the N^{3/4} term in S₂.
    Σ_{k=N}^{M-1} (log(k)+1)/k² ≤ 6·log(N)/N for N ≥ 2. -/
private lemma finite_log_inv_sq_bound (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    ∑ k ∈ Finset.Ico N M,
      (Real.log (k : ℝ) + 1) / (k : ℝ) ^ 2 ≤
    6 * Real.log (N : ℝ) / (N : ℝ) := by
  sorry -- THE TAIL: convergent series, integral comparison

-- ════════════════════════════════════════════════
-- §8. S₂ FINITE ABEL DIFFERENCE BOUND
-- ════════════════════════════════════════════════

/-- THE FORGE: finite Abel bound for S₂.
    |S₂(M) - S₂(N)| ≤ C_m·(boundary + interior)
    where interior ≤ C_s2·N^{-1/4}·log(N). -/
private lemma finite_abel_s2_diff
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (N M : ℕ) (hN : 2 ≤ N) (hM : N + 1 ≤ M) :
    |S₂' M - S₂' N| ≤
    C_m * ((M : ℝ) ^ (-(1:ℝ)/4) * Real.log (M : ℝ) +
            (N : ℝ) ^ ((3:ℝ)/4) * Real.log (M : ℝ) / (M : ℝ)) +
    C_m * 30 * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
  sorry -- Uses Abel summation + s2_discrete_diff_bound + tail bounds

-- ════════════════════════════════════════════════
-- §9. S₂ DECAY (LIMIT ARGUMENT)
-- ════════════════════════════════════════════════

/-- THE FORGE: S₂ decay via limit + Abel.
    Same structure as s1_decay but with log(N) factor.
    |S₂(N)+1| ≤ C₂·N^{-1/4}·log(N) for all N ≥ 2. -/
private lemma s2_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1))) :
    ∃ C₂ : ℝ, C₂ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₂' N - (-1)| ≤ C₂ * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
  use 1 + 35 * C_m
  constructor
  · linarith
  intro N hN
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have hlog_pos : 0 < Real.log (N : ℝ) := Real.log_pos (by exact_mod_cast show 1 < N by omega)
  have h_eps : (0 : ℝ) < (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
    exact mul_pos (Real.rpow_pos_of_pos hN_pos _) hlog_pos
  -- Step 1: From PNT₂ (S₂ → -1), get M₀
  obtain ⟨M₀, hM₀⟩ := tendsto_extract_bound h_eps hPNT₂
  -- Step 2: Choose M = max(N+1, M₀)
  set M := max (N + 1) M₀
  have hM_ge_N1 : N + 1 ≤ M := le_max_left _ _
  have hM_ge_M0 : M₀ ≤ M := le_max_right _ _
  -- Step 3: |S₂(M)+1| < N^{-1/4}·log(N)
  have hS2M : |S₂' M - (-1)| ≤ (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
    have h := hM₀ M hM_ge_M0
    simp only [sub_neg_eq_add] at h ⊢
    exact h
  -- Step 4: Abel bound
  have hAbel := finite_abel_s2_diff C_m hC hMertens N M hN hM_ge_N1
  -- Step 5: Boundary terms vanish
  have hM_ge_N : (N : ℝ) ≤ (M : ℝ) := by exact_mod_cast (show N ≤ M by omega)
  have hM_pos : (0 : ℝ) < (M : ℝ) := Nat.cast_pos.mpr (by omega)
  -- M^{-1/4}·log(M) ≤ N^{-1/4}·log(M) and log(M) is finite
  -- For M ≥ N: M^{-1/4} ≤ N^{-1/4}, N^{3/4}·log(M)/M ≤ N^{-1/4}·log(M)
  -- Combined boundary ≤ 2·C_m·N^{-1/4}·log(M)
  -- Since M ≤ some polynomial of N (via M₀), log(M) ≤ C·log(N)
  -- For uniform bound: boundary → 0 as M → ∞ for fixed N
  -- Triangle: |S₂(N)+1| ≤ |S₂(M)+1| + |S₂(M)-S₂(N)|
  -- First term: ≤ N^{-1/4}·log(N) from hS2M
  -- Second term: |S₂(M)-S₂(N)| ≤ Abel bound → boundary vanishes, interior ≤ C·N^{-1/4}·log(N)
  sorry -- Final wiring: triangle + Abel bound ≤ (1+35C_m)·N^{-1/4}·log(N)

-- ════════════════════════════════════════════════
-- §10. S₃ DECAY (Same pattern with log² weights)
-- ════════════════════════════════════════════════

-- S₃ definition (matching FinalDragon.lean)
private def S₃' (M : ℕ) : ℝ :=
  ∑ k ∈ Finset.Icc 1 M, (↑(ArithmeticFunction.moebius k) : ℝ) *
    (Real.log (k : ℝ)) ^ 2 / (k : ℝ)

/-- THE FORGE: S₃ decay via limit + Abel.
    |S₃(N)+2γ| ≤ C₃·N^{-1/4}·log²(N) for all N ≥ 2.
    Identical structure to s2_decay with log² weights.
    Uses Discrete Product Rule for log²(k)/k:
    |Δ(log²(k)/k)| ≤ (log²(k)+2·log(k)+2)/k² -/
private lemma s3_decay
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (L₃ : ℝ) -- The limit (-2γ); generalized to avoid import
    (hPNT₃ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      Filter.atTop (nhds L₃)) :
    ∃ C₃ : ℝ, C₃ > 0 ∧ ∀ N : ℕ, 2 ≤ N →
      |S₃' N - L₃| ≤
        C₃ * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
  sorry -- Same architecture as s2_decay with log² factor

-- ════════════════════════════════════════════════
-- §11. THE ASSEMBLY: abel_mertens_tail_raw AS THEOREM
-- ════════════════════════════════════════════════

/-- THE CROWN: Abel-Mertens tail bound — THEOREM, not axiom.
    Combines s1_decay, s2_decay, s3_decay into a single uniform bound.
    This replaces the axiom `abel_mertens_tail_raw` in FinalDragon.lean. -/
theorem abel_mertens_tail_proved
    (C_m : ℝ) (hC : 0 < C_m)
    (hMertens : ∀ x : ℝ, x ≥ 2 →
      |((mertensFunction x : ℤ) : ℝ)| ≤ C_m * x ^ ((3:ℝ)/4))
    (hPNT₁ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) / (k : ℝ))
      Filter.atTop (nhds 0))
    (hPNT₂ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      Filter.atTop (nhds (-1)))
    (L₃ : ℝ) -- The limit -2γ; generalized for import independence
    (hPNT₃ : Filter.Tendsto (fun N =>
      ∑ k ∈ Finset.Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        (Real.log (k : ℝ)) ^ 2 / (k : ℝ))
      Filter.atTop (nhds L₃)) :
    ∃ C : ℝ, C > 0 ∧ ∀ N : ℕ, 2 ≤ N →
    |S₁' N| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) ∧
    |S₂' N - (-1)| ≤ C * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) ∧
    |S₃' N - L₃| ≤
      C * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
  -- Get individual bounds
  obtain ⟨C₁, hC₁_pos, hC₁⟩ := s1_decay C_m hC hMertens hPNT₁
  obtain ⟨C₂, hC₂_pos, hC₂⟩ := s2_decay C_m hC hMertens hPNT₂
  obtain ⟨C₃, hC₃_pos, hC₃⟩ := s3_decay C_m hC hMertens L₃ hPNT₃
  -- Combine into single C
  use max C₁ (max C₂ C₃)
  refine ⟨by positivity, fun N hN => ?_⟩
  have hN_pos : (0 : ℝ) < (N : ℝ) := Nat.cast_pos.mpr (by omega)
  have h_rpow_pos : 0 < (N : ℝ) ^ (-(1:ℝ)/4) := Real.rpow_pos_of_pos hN_pos _
  have h_rpow_nn : 0 ≤ (N : ℝ) ^ (-(1:ℝ)/4) := h_rpow_pos.le
  have hlog_nn : 0 ≤ Real.log (N : ℝ) :=
    Real.log_nonneg (by exact_mod_cast show 1 ≤ N by omega)
  refine ⟨?_, ?_, ?_⟩
  · -- S₁ bound
    calc |S₁' N| ≤ C₁ * (N : ℝ) ^ (-(1:ℝ)/4) := hC₁ N hN
      _ ≤ max C₁ (max C₂ C₃) * (N : ℝ) ^ (-(1:ℝ)/4) := by
          apply mul_le_mul_of_nonneg_right (le_max_left _ _) h_rpow_nn
  · -- S₂ bound
    calc |S₂' N - (-1)| ≤ C₂ * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := hC₂ N hN
      _ ≤ max C₁ (max C₂ C₃) * (N : ℝ) ^ (-(1:ℝ)/4) * Real.log (N : ℝ) := by
          apply mul_le_mul_of_nonneg_right _ hlog_nn
          apply mul_le_mul_of_nonneg_right _ h_rpow_nn
          exact le_trans (le_max_left C₂ C₃) (le_max_right C₁ _)
  · -- S₃ bound
    calc |S₃' N - L₃|
        ≤ C₃ * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := hC₃ N hN
      _ ≤ max C₁ (max C₂ C₃) * (N : ℝ) ^ (-(1:ℝ)/4) * (Real.log (N : ℝ)) ^ 2 := by
          apply mul_le_mul_of_nonneg_right _ (sq_nonneg _)
          apply mul_le_mul_of_nonneg_right _ h_rpow_nn
          exact le_trans (le_max_right C₂ C₃) (le_max_right C₁ _)

end
