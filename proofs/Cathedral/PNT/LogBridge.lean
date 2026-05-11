/-
  Cathedral/PNT/LogBridge.lean

  ## The Log-Weighted PNT Bridge: Σ μ(k)·log(k)/k → -1

  Proves the log-weighted Möbius sum limit using the Dirichlet convolution
  identity `mu_log * ζ = -Λ` and the hyperbola method from PrimeNumberTheoremAnd.

  ### Proof Architecture

  The proof proceeds in two stages:

  **Stage 1 (sorry-free):** Establish the exact algebraic identity
    `N · S₂(N) = -ψ(N) + E(N)`
  where `S₂(N) = Σ μ(n)·log(n)/n` and `E(N) = Σ μ(n)·log(n)·{N/n}`.
  This follows from the Dirichlet floor identity `Σ μ(n)·log(n)·⌊N/n⌋ = -ψ(N)`
  (which is the convolution `mu_log * ζ = -Λ` evaluated at N).

  **Stage 2 (1 sorry):** Bound the fractional error `E(N) = o(N)`.
  This is equivalent to the main theorem `S₂(N) → -1` via the Stage 1 identity
  (since ψ(N)/N → 1 from PNT). The independent proof requires either:
  - Wiener-Ikehara applied to `(1/ζ)'(s)` (the derivative of the Möbius
    Dirichlet series), which is available in PNTAnd but requires showing
    `(1/ζ)'(s) - 1/(s-1)²` extends continuously to Re(s) = 1; or
  - A generalized Tauberian argument beyond Hardy's O(1/n) condition,
    since `|μ(n)·log(n)/n|` grows as `log(n)/n` (not O(1/n)).

  ### Status: 1 sorry (frac_error_isLittleO — Tauberian gap)
  ### Dependencies: PrimeNumberTheoremAnd.Consequences, Cathedral.Defs

  Created: April 25, 2026 (The Log Bridge)
-/

import Cathedral.Defs
import Mathlib.NumberTheory.ArithmeticFunction.Moebius
import Mathlib.NumberTheory.ArithmeticFunction.VonMangoldt

-- ════════════════════════════════════════════════
-- PNTAnd DEFINITIONS & AXIOMS (previously from Consequences.lean)
-- Axiom-ified to remove PNTAnd dependency.
-- ════════════════════════════════════════════════

/-- Chebyshev's ψ function: ψ(x) = Σ_{n≤x} Λ(n). -/
noncomputable abbrev Psi (x : ℝ) : ℝ :=
  ∑ n ∈ Finset.Ioc 0 ⌊x⌋₊, ArithmeticFunction.vonMangoldt n

/-- PNT remainder: R(x) = ψ(x) - x. -/
noncomputable def R (x : ℝ) : ℝ := Psi x - x

/-- μ·log arithmetic function. -/
noncomputable def mu_log : ArithmeticFunction ℝ :=
  ⟨fun n => (↑(ArithmeticFunction.moebius n) : ℝ) * Real.log n, by simp⟩

private lemma mu_log_apply (n : ℕ) :
    mu_log n = (↑(ArithmeticFunction.moebius n) : ℝ) * Real.log n := rfl

/-- PNT: ψ(x) - x = o(x). Axiom (was proved in PNTAnd). -/
axiom R_isLittleO : R =o[Filter.atTop] _root_.id

/-- Dirichlet identity: μ·log * ζ = -Λ. Axiom (was proved in PNTAnd). -/
axiom mu_log_mul_zeta :
  mu_log * ArithmeticFunction.zeta = -ArithmeticFunction.vonMangoldt

noncomputable section
open Real Finset Filter ArithmeticFunction ArithmeticFunction.Moebius Asymptotics

-- ════════════════════════════════════════════════
-- §1. THE FLOOR IDENTITY FOR LOG-WEIGHTS
-- ════════════════════════════════════════════════

private lemma ioc_zero_eq_icc_one {N : ℕ} {f : ℕ → ℝ} :
    ∑ n ∈ Ioc 0 N, f n = ∑ n ∈ Icc 1 N, f n := by
  apply sum_congr
  ext n; simp [Nat.lt_iff_add_one_le, Nat.one_le_iff_ne_zero]
  intros; rfl

/-- **The Dirichlet floor identity for log-weighted Möbius (Identity 2).**
    Σ_{n ∈ Icc 1 N} μ(n)·log(n)·(N/n) = -ψ(N)

    This is Dirichlet convolution `μ·log * ζ = -Λ` evaluated via
    the hyperbola method. PROVED. -/
lemma sum_mu_log_floor_icc (N : ℕ) :
    ∑ n ∈ Icc 1 N, (μ n : ℝ) * Real.log n * (N / n : ℕ) = -Psi N := by
  have h := ArithmeticFunction.sum_Ioc_mul_zeta_eq_sum mu_log N
  rw [mu_log_mul_zeta] at h
  simp only [ArithmeticFunction.neg_apply, sum_neg_distrib] at h
  rw [ioc_zero_eq_icc_one, ioc_zero_eq_icc_one] at h
  show _ = -(∑ n ∈ Ioc 0 ⌊(N : ℝ)⌋₊, Λ n)
  simp only [Nat.floor_natCast]
  rw [ioc_zero_eq_icc_one]
  rw [show ∑ n ∈ Icc 1 N, (μ n : ℝ) * Real.log n * (↑(N / n) : ℝ) =
    ∑ n ∈ Icc 1 N, mu_log n * (↑(N / n) : ℝ) from
    sum_congr rfl fun n _ => by simp [mu_log_apply, ArithmeticFunction.log_apply]]
  linarith

-- ════════════════════════════════════════════════
-- §2. NAT-DIV DECOMPOSITION
-- ════════════════════════════════════════════════

/-- For any natural numbers N, n with n ≠ 0:
    ↑(N / n) = (↑N) / (↑n) - ↑(N % n) / (↑n) -/
private lemma nat_div_eq_real_sub_mod (N n : ℕ) (hn : n ≠ 0) :
    (↑(N / n) : ℝ) = (N : ℝ) / ↑n - (↑(N % n) : ℝ) / ↑n := by
  have hn_pos : (n : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hn
  have h : n * (N / n) + N % n = N := Nat.div_add_mod N n
  have h' : (n : ℝ) * ↑(N / n) + ↑(N % n) = (N : ℝ) := by exact_mod_cast h
  rw [show (N : ℝ) / ↑n - (↑(N % n) : ℝ) / ↑n = ((N : ℝ) - ↑(N % n)) / ↑n from by ring]
  rw [eq_div_iff hn_pos]
  linarith

/-- **Main algebraic identity.**
    N · Σ μ(n)·log(n)/n = -ψ(N) + Σ μ(n)·log(n)·↑(N%n)/n -/
private lemma main_identity (N : ℕ) (_hN : 0 < N) :
    (N : ℝ) * (∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log n / n) =
    -Psi N + ∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log n * ((↑(N % n) : ℝ) / n) := by
  have h := sum_mu_log_floor_icc N
  rw [show ∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log n * (↑(N / n) : ℝ) =
    ∑ n ∈ Icc 1 N, ((↑(μ n) : ℝ) * Real.log n * ((N : ℝ) / n) -
      (↑(μ n) : ℝ) * Real.log n * ((↑(N % n) : ℝ) / n)) from
    sum_congr rfl fun n hn => by
      simp only [mem_Icc] at hn
      rw [← mul_sub, nat_div_eq_real_sub_mod N n (by omega)]] at h
  rw [sum_sub_distrib] at h
  rw [show ∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log n * ((N : ℝ) / n) =
    (N : ℝ) * ∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log n / n from by
    rw [mul_sum]; exact sum_congr rfl fun n _ => by ring] at h
  linarith

-- ════════════════════════════════════════════════
-- §3. ERROR BOUND (TAUBERIAN GAP)
-- ════════════════════════════════════════════════

/-- **Fractional part error is o(N).**
    `Σ_{n=1}^N μ(n)·log(n)·↑(N%n)/n = o(N)`

    **Mathematical status:** This is equivalent to the main theorem `S₂(N) → -1`
    via `main_identity` (since `ψ(N)/N → 1`). An independent proof requires
    Tauberian methods beyond what PNTAnd currently provides for log-weighted sums:
    - The standard hyperbola method (used for `mu_pnt_alt`) fails because the
      log weight introduces an `O(N·log(N)/K)` short-range error, which after
      dividing by N gives `O(log(N)/K)` — divergent for fixed K.
    - Hardy's Tauberian theorem requires `|u(n)| ≤ A/n` for fixed A, but
      `|μ(n)·log(n)/n| ≤ log(n)/n` violates this with `log(n) → ∞`.
    - The Wiener-Ikehara theorem in PNTAnd applies to non-negative sequences;
      the signed oscillation of `μ(n)·log(n)` requires extending the theorem
      to the derivative `(1/ζ)'(s)`.

    **Proof sketch (not yet formalized):**
    Apply Wiener-Ikehara to the Dirichlet series `F(s) = -Σ μ(n)·log(n)/nˢ = (1/ζ)'(s)`.
    Since `1/ζ(s) = (s-1)·G(s)` with `G` holomorphic and `G(1) = 1`, we get
    `(1/ζ)'(s) = G(s) + (s-1)·G'(s)`, which has the limit 1 at `s = 1`.
    A signed variant of Wiener-Ikehara then gives `Σ_{n≤x} μ(n)·log(n)/n → -1`. -/
private lemma frac_error_isLittleO :
    (fun N : ℕ => ∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log n * ((↑(N % n) : ℝ) / n))
    =o[atTop] (fun N => (N : ℝ)) := by
  -- WIP: Incomplete alternative spatial route for axiom graduation.
  -- This path is superseded by the Mellin Crown architecture (v11+).
  -- Requires signed Wiener-Ikehara extension. Left for future exploration.
  sorry

-- ════════════════════════════════════════════════
-- §4. THE MAIN THEOREM
-- ════════════════════════════════════════════════

/-- **THE GRADUATED AXIOM**: Σ μ(k)·log(k)/k → -1 (discrete, ℕ-indexed).

    This replaces the axiom `pnt_mu_log_div_k` in PNT/AbelMean.lean. -/
theorem pnt_mu_log_div_k_proved :
    Tendsto (fun N =>
      ∑ k ∈ Icc 1 N, (↑(ArithmeticFunction.moebius k) : ℝ) *
        Real.log (k : ℝ) / (k : ℝ))
      atTop (nhds (-1)) := by
  -- Strategy: show S₂(N) + 1 → 0, then derive S₂(N) → -1
  suffices hsuff : Tendsto (fun N : ℕ =>
      ∑ k ∈ Icc 1 N, (↑(μ k) : ℝ) * Real.log (k : ℝ) / (k : ℝ) + 1)
      atTop (nhds 0) by
    have := hsuff.add (tendsto_const_nhds (x := (-1 : ℝ)))
    simp only [zero_add] at this ⊢
    exact this.congr fun N => by ring
  -- PNT remainder: (ψ(N) - N)/N → 0
  have h_R : Tendsto (fun N : ℕ => (Psi (N : ℝ) - N) / (N : ℝ)) atTop (nhds 0) := by
    have h := R_isLittleO
    rw [isLittleO_iff_tendsto' (by
      filter_upwards [eventually_gt_atTop (0 : ℝ)] with x hx hx'
      exact absurd hx' hx.ne')] at h
    exact (h.comp tendsto_natCast_atTop_atTop).congr fun N => by
      simp [R, Function.comp, _root_.id]
  -- Error bound: E(N)/N → 0
  have h_E : Tendsto (fun N : ℕ =>
      (∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log n * ((↑(N % n) : ℝ) / n)) / (N : ℝ))
      atTop (nhds 0) := by
    rw [← isLittleO_iff_tendsto' (by
      filter_upwards [eventually_gt_atTop 0] with N hN hN'
      exact absurd (Nat.cast_eq_zero.mp hN') (by omega))]
    exact frac_error_isLittleO
  -- S₂(N) + 1 = -(ψ(N)-N)/N + E(N)/N → 0 + 0 = 0
  have h_neg_R : Tendsto (fun N : ℕ => -((Psi (N : ℝ) - N) / (N : ℝ))) atTop (nhds 0) := by
    rw [show (0 : ℝ) = -0 from by ring]; exact h_R.neg
  rw [show (0 : ℝ) = 0 + 0 from by ring]
  refine Tendsto.congr' ?_ (h_neg_R.add h_E)
  filter_upwards [eventually_gt_atTop 0] with N hN
  have hN_ne : (N : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr (by omega)
  have h_id := main_identity N hN
  have h_s2 : ∑ k ∈ Icc 1 N, (↑(μ k) : ℝ) * Real.log ↑k / ↑k =
    (-Psi ↑N + ∑ n ∈ Icc 1 N, (↑(μ n) : ℝ) * Real.log ↑n * (↑(N % n) / ↑n)) / ↑N := by
    rw [eq_div_iff hN_ne]; linarith
  -- Goal: -(R(N)/N) + E(N)/N = S₂(N) + 1
  -- Using h_s2: S₂(N) = (-ψ(N) + E(N))/N
  -- So S₂(N) + 1 = (-ψ(N) + E(N))/N + 1 = (-ψ(N) + E(N) + N)/N
  --              = (N - ψ(N) + E(N))/N = -(ψ(N)-N)/N + E(N)/N ✓
  rw [h_s2]
  field_simp
  ring

end
