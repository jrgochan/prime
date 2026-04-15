/-
  Cathedral/Vasyunin/Matrix/CovDet3.lean

  **det(C₃) > 0**: The 3×3 covariance matrix has positive determinant.
  
  Proof architecture:
  1. ln(3) > 549/500 (Taylor bound on exp)
  2. At each g-endpoint {1/2, 2/3}:
     a. Base certificate P(q₀) > 0 — 2-variable (l, t) via nlinarith
     b. Divided difference D₁ > 0 — 3-variable (l, q, t) via nlinarith
     c. Decomposition P(q) = P(q₀) + (q-q₀)·D₁ (ring identity)
     d. Assembly: P(q) > 0 for all q ∈ [q₀, 8l/5]
  3. g-interpolation: P quadratic in g with correction C(t) = t(1-8t)/48 > 0
  4. Bridge to vasyuninCovMatrix 3 definition
  
  Zero sorry. Zero axioms. Pure Mathlib.
-/
import Cathedral.Vasyunin.Matrix.GramEvaluations

set_option maxHeartbeats 6400000
noncomputable section
open Real Finset

namespace Cathedral.Vasyunin

-- ═══════════════════════════════════════════════
-- §1. ln(3) > 549/500
-- ═══════════════════════════════════════════════

private theorem exp_549_1000_lt : Real.exp (549/1000 : ℝ) < 1732/1000 := by
  have h := Real.exp_bound' (show (0:ℝ) ≤ 549/1000 by norm_num)
    (show (549:ℝ)/1000 ≤ 1 by norm_num) (show 0 < 5 by norm_num)
  simp only [sum_range_succ, sum_range_zero] at h
  norm_num [Nat.factorial] at h ⊢; linarith

theorem log_three_gt_549_500 : (549 : ℝ) / 500 < Real.log 3 := by
  rw [show (549:ℝ)/500 = Real.log (Real.exp (549/500)) from (Real.log_exp (549/500)).symm]
  exact Real.log_lt_log (by positivity) (by
    rw [show (549:ℝ)/500 = 549/1000 + 549/1000 from by ring, Real.exp_add]
    have h := exp_549_1000_lt
    calc Real.exp (549/1000) * Real.exp (549/1000)
        < 1732/1000 * (1732/1000) := by nlinarith [Real.exp_pos (549/1000 : ℝ)]
      _ = 2999824/1000000 := by norm_num
      _ < 3 := by norm_num)

-- ═══════════════════════════════════════════════
-- §2. covDet3Expr: the 5-variable polynomial
-- ═══════════════════════════════════════════════

/-- det(C₃) as a polynomial of (l, g, q, t) where A = l + q - g.
    Variables: l = ln 2, g = γ, q = ln 3, t = π/(18√3). -/
private def covDet3Expr (l g q t : ℝ) : ℝ :=
  let A := l + q - g
  let G11 := A - 1; let G12 := 3*A/4 - l/4 - 1/2
  let G13 := 2*A/3 - q/3 + t - 1/3; let G22 := A/2 - 1/4
  let G23 := 5*A/12 - (q-l)/12 - t/2 - 1/6; let G33 := A/3 - 1/9
  let b1 := 1 - g; let b2 := (l + 1 - g)/2; let b3 := (q + 1 - g)/3
  let C00 := G11 - b1^2; let C01 := G12 - b1*b2
  let C02 := G13 - b1*b3; let C11 := G22 - b2^2
  let C12 := G23 - b2*b3; let C22 := G33 - b3^2
  C00*(C11*C22 - C12^2) - C01*(C01*C22 - C12*C02) + C02*(C01*C12 - C11*C02)

-- ═══════════════════════════════════════════════
-- §3. g = 2/3 certificates
-- ═══════════════════════════════════════════════

set_option maxHeartbeats 12800000 in
/-- Base: P(l, 2/3, 549/500, t) > 0 for (l, t) in bounds. Margin ≈ 0.0000098. -/
private theorem covDet3_g23_base (l t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3Expr l (2/3) (549/500) t > 0 := by
  unfold covDet3Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             sq_nonneg (t - 157/1566), sq_nonneg (35/346 - t),
             sq_nonneg (l*t - 693/10000),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < t by linarith),
             mul_pos (show (0:ℝ) < t by linarith) (show (0:ℝ) < t by linarith)]

/-- Divided difference for g=2/3:
    P(q) - P(549/500) = (q - 549/500) · D₁(l, q, t). -/
private def covDet3_g23_divDiff (l q t : ℝ) : ℝ :=
  let q0 := (549:ℝ)/500
  let a4 := (1:ℝ)/144
  let a3 := -(5:ℝ)/144
  let a2 := -l^2/36 - 5*l*t/12 + l/16 + 11*t/36 + 1/36
  let a1 := -l^2*t/6 + l^2/18 + 5*l*t/6 - 11*l/108 - 3*t^2/2 - 11*t/36
  a4*(q^3 + q^2*q0 + q*q0^2 + q0^3) + a3*(q^2 + q*q0 + q0^2) + a2*(q + q0) + a1

/-- Ring identity: P(q) = P(q₀) + (q - q₀)·D₁. -/
private theorem covDet3_g23_decomp (l q t : ℝ) :
    covDet3Expr l (2/3) q t = covDet3Expr l (2/3) (549/500) t +
      (q - 549/500) * covDet3_g23_divDiff l q t := by
  unfold covDet3Expr covDet3_g23_divDiff; ring

set_option maxHeartbeats 12800000 in
/-- D₁ > 0 on the domain. Margin ≈ 0.00177. -/
private theorem covDet3_g23_divDiff_pos (l q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hq_lo : 549/500 ≤ q) (hq_hi : q ≤ 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3_g23_divDiff l q t > 0 := by
  unfold covDet3_g23_divDiff; ring_nf
  nlinarith [sq_nonneg (l - 693/1000), sq_nonneg (q - 11*l/10),
             sq_nonneg (t - 1/10), sq_nonneg (l*t - 7/100),
             sq_nonneg (l*q - 76/100), sq_nonneg (q*t - 11/100),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < q by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < t by linarith),
             mul_pos (show (0:ℝ) < q by linarith) (show (0:ℝ) < t by linarith)]

/-- Assembly: covDet3Expr l (2/3) q t > 0 for all valid (l, q, t). -/
private theorem covDet3_g23_pos (l q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3Expr l (2/3) q t > 0 := by
  rw [covDet3_g23_decomp]
  have h_base := covDet3_g23_base l t hl hl2 ht_lo ht_hi
  have h_diff := covDet3_g23_divDiff_pos l q t hl hl2 (le_of_lt hq_lo) (le_of_lt hq_hi) ht_lo ht_hi
  linarith [mul_pos (show (0:ℝ) < q - 549/500 by linarith) h_diff]

-- ═══════════════════════════════════════════════
-- §4. g = 1/2 certificates
-- ═══════════════════════════════════════════════

set_option maxHeartbeats 12800000 in
private theorem covDet3_g12_base (l t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3Expr l (1/2) (549/500) t > 0 := by
  unfold covDet3Expr; ring_nf
  nlinarith [sq_nonneg (l - 6931/10000), sq_nonneg (7/10 - l),
             sq_nonneg (t - 157/1566), sq_nonneg (35/346 - t),
             sq_nonneg (l*t - 693/10000),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < t by linarith),
             mul_pos (show (0:ℝ) < t by linarith) (show (0:ℝ) < t by linarith)]

private def covDet3_g12_divDiff (l q t : ℝ) : ℝ :=
  let q0 := (549:ℝ)/500
  let a4 := (1:ℝ)/144
  let a3 := -(5:ℝ)/144
  let a2 := -l^2/36 - 5*l*t/12 + l/16 + t/3 + 7/288
  let a1 := -l^2*t/6 + l^2/18 + 3*l*t/4 - 13*l/144 - 3*t^2/2 - 5*t/16
  a4*(q^3 + q^2*q0 + q*q0^2 + q0^3) + a3*(q^2 + q*q0 + q0^2) + a2*(q + q0) + a1

private theorem covDet3_g12_decomp (l q t : ℝ) :
    covDet3Expr l (1/2) q t = covDet3Expr l (1/2) (549/500) t +
      (q - 549/500) * covDet3_g12_divDiff l q t := by
  unfold covDet3Expr covDet3_g12_divDiff; ring

set_option maxHeartbeats 12800000 in
private theorem covDet3_g12_divDiff_pos (l q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hq_lo : 549/500 ≤ q) (hq_hi : q ≤ 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3_g12_divDiff l q t > 0 := by
  unfold covDet3_g12_divDiff; ring_nf
  nlinarith [sq_nonneg (l - 693/1000), sq_nonneg (q - 11*l/10),
             sq_nonneg (t - 1/10), sq_nonneg (l*t - 7/100),
             sq_nonneg (l*q - 76/100), sq_nonneg (q*t - 11/100),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < q by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < t by linarith),
             mul_pos (show (0:ℝ) < q by linarith) (show (0:ℝ) < t by linarith)]

private theorem covDet3_g12_pos (l q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3Expr l (1/2) q t > 0 := by
  rw [covDet3_g12_decomp]
  have h_base := covDet3_g12_base l t hl hl2 ht_lo ht_hi
  have h_diff := covDet3_g12_divDiff_pos l q t hl hl2 (le_of_lt hq_lo) (le_of_lt hq_hi) ht_lo ht_hi
  linarith [mul_pos (show (0:ℝ) < q - 549/500 by linarith) h_diff]

-- ═══════════════════════════════════════════════
-- §5. g-interpolation
-- ═══════════════════════════════════════════════

/-- The g-interpolation correction: C(t) = t(1-8t)/48.
    Positive for t < 1/8 (holds since t < 35/346 < 1/8). -/
private def gCorrTerm_t (t : ℝ) : ℝ := t * (1 - 8*t) / 48

/-- Ring identity: (1/6)·P(g) = (2/3-g)·P(1/2) + (g-1/2)·P(2/3) + (g-1/2)(2/3-g)·C(t). -/
private theorem covDet3_g_interp_id (l g q t : ℝ) :
    (1/6) * covDet3Expr l g q t =
      (2/3 - g) * covDet3Expr l (1/2) q t +
      (g - 1/2) * covDet3Expr l (2/3) q t +
      (g - 1/2) * (2/3 - g) * gCorrTerm_t t := by
  unfold covDet3Expr gCorrTerm_t; ring

/-- **Main theorem**: covDet3Expr l g q t > 0 for all valid parameters. -/
theorem covDet3Expr_pos (l g q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hg_lo : 1/2 ≤ g) (hg_hi : g ≤ 2/3)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    0 < covDet3Expr l g q t := by
  have h12 := covDet3_g12_pos l q t hl hl2 hq_lo hq_hi ht_lo ht_hi
  have h23 := covDet3_g23_pos l q t hl hl2 hq_lo hq_hi ht_lo ht_hi
  have hid := covDet3_g_interp_id l g q t
  have hg1 : 0 ≤ 2/3 - g := by linarith
  have hg2 : 0 ≤ g - 1/2 := by linarith
  have hC : 0 ≤ gCorrTerm_t t := by
    unfold gCorrTerm_t
    apply div_nonneg
    · apply mul_nonneg (by linarith : (0:ℝ) ≤ t)
      linarith [show t < 35/346 from ht_hi, show (35:ℝ)/346 < 1/8 from by norm_num]
    · norm_num
  have h_rhs : 0 < (2/3 - g) * covDet3Expr l (1/2) q t +
                   (g - 1/2) * covDet3Expr l (2/3) q t +
                   (g - 1/2) * (2/3 - g) * gCorrTerm_t t := by
    rcases eq_or_lt_of_le hg_lo with rfl | hg_strict
    · simp; linarith [mul_nonneg hg2 (mul_nonneg hg1 hC)]
    · have : 0 < (g - 1/2) * covDet3Expr l (2/3) q t := mul_pos (by linarith) h23
      linarith [mul_nonneg hg1 (le_of_lt h12), mul_nonneg hg2 (mul_nonneg hg1 hC)]
  linarith

-- ═══════════════════════════════════════════════
-- §6. A-monotonicity: bridge from π=3 to true π
-- ═══════════════════════════════════════════════

/-- Full det(C₃) with A independent: covDet3Full(A, l, g, q, t). -/
def covDet3Full (A l g q t : ℝ) : ℝ :=
  let G11 := A - 1; let G12 := 3*A/4 - l/4 - 1/2
  let G13 := 2*A/3 - q/3 + t - 1/3; let G22 := A/2 - 1/4
  let G23 := 5*A/12 - (q-l)/12 - t/2 - 1/6; let G33 := A/3 - 1/9
  let b1 := 1 - g; let b2 := (l + 1 - g)/2; let b3 := (q + 1 - g)/3
  let C00 := G11 - b1^2; let C01 := G12 - b1*b2
  let C02 := G13 - b1*b3; let C11 := G22 - b2^2
  let C12 := G23 - b2*b3; let C22 := G33 - b3^2
  C00*(C11*C22 - C12^2) - C01*(C01*C22 - C12*C02) + C02*(C01*C12 - C11*C02)

/-- covDet3Expr = covDet3Full at base A = l+q-g. -/
private theorem covDet3_base_eq (l g q t : ℝ) :
    covDet3Full (l+q-g) l g q t = covDet3Expr l g q t := by
  unfold covDet3Full covDet3Expr; ring

/-- Taylor expansion (exact for degree 2):
    P(A₀+δ) = P(A₀) + δ · D(l, g, q, t, δ) where
    D = P'(A₀) + δ · a₂. -/
private def covDet3_taylorSlope (l g q t δ : ℝ) : ℝ :=
  -- P'(A₀) + δ · a₂ where A₀ = l+q-g and a₂ = (l²/36 - lq/36 + q²/144 - t/8)
  let a1_lin := -g*l*t/6 - g*q*t/6 + g*t/4 + l^3/18 - l^2*q/36 + l^2*t/3 - l^2/9 -
                l*q^2/36 - 5*l*q*t/12 + l*q/8 + l*t/12 + q^3/72 - 5*q^2/144 +
                7*q*t/24 - 3*t^2/2
  let a2 := l^2/36 - l*q/36 + q^2/144 - t/8
  a1_lin + δ * a2

/-- Ring identity: P(A₀+δ) = P(A₀) + δ · taylorSlope. -/
private theorem covDet3_taylor_id (l g q t δ : ℝ) :
    covDet3Full (l+q-g+δ) l g q t =
      covDet3Expr l g q t + δ * covDet3_taylorSlope l g q t δ := by
  unfold covDet3Full covDet3Expr covDet3_taylorSlope; ring

-- P'(A₀) at the 4 corners of (g, δ) ∈ {1/2, 2/3} × {0, 1/10}:
-- Each is a 3-variable inequality in (l, q, t) — tractable for nlinarith.

set_option maxHeartbeats 12800000 in
private theorem covDet3_ts_g12_d0 (l q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3_taylorSlope l (1/2) q t 0 > 0 := by
  unfold covDet3_taylorSlope; ring_nf
  nlinarith [sq_nonneg (l - 693/1000), sq_nonneg (q - 11*l/10),
             sq_nonneg (t - 1/10), sq_nonneg (l*t - 7/100),
             sq_nonneg (l*q - 76/100), sq_nonneg (q*t - 11/100),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < q by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < t by linarith),
             mul_pos (show (0:ℝ) < q by linarith) (show (0:ℝ) < t by linarith)]

set_option maxHeartbeats 12800000 in
private theorem covDet3_ts_g23_d0 (l q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3_taylorSlope l (2/3) q t 0 > 0 := by
  unfold covDet3_taylorSlope; ring_nf
  nlinarith [sq_nonneg (l - 693/1000), sq_nonneg (q - 11*l/10),
             sq_nonneg (t - 1/10), sq_nonneg (l*t - 7/100),
             sq_nonneg (l*q - 76/100), sq_nonneg (q*t - 11/100),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < q by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < t by linarith),
             mul_pos (show (0:ℝ) < q by linarith) (show (0:ℝ) < t by linarith)]

set_option maxHeartbeats 12800000 in
private theorem covDet3_ts_g12_d10 (l q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3_taylorSlope l (1/2) q t (1/10) > 0 := by
  unfold covDet3_taylorSlope; ring_nf
  nlinarith [sq_nonneg (l - 693/1000), sq_nonneg (q - 11*l/10),
             sq_nonneg (t - 1/10), sq_nonneg (l*t - 7/100),
             sq_nonneg (l*q - 76/100), sq_nonneg (q*t - 11/100),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < q by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < t by linarith),
             mul_pos (show (0:ℝ) < q by linarith) (show (0:ℝ) < t by linarith)]

set_option maxHeartbeats 12800000 in
private theorem covDet3_ts_g23_d10 (l q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346) :
    covDet3_taylorSlope l (2/3) q t (1/10) > 0 := by
  unfold covDet3_taylorSlope; ring_nf
  nlinarith [sq_nonneg (l - 693/1000), sq_nonneg (q - 11*l/10),
             sq_nonneg (t - 1/10), sq_nonneg (l*t - 7/100),
             sq_nonneg (l*q - 76/100), sq_nonneg (q*t - 11/100),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < l by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < q by linarith),
             mul_pos (show (0:ℝ) < l by linarith) (show (0:ℝ) < t by linarith),
             mul_pos (show (0:ℝ) < q by linarith) (show (0:ℝ) < t by linarith)]

/-- taylorSlope is bilinear in (g, δ), positive at all 4 corners of
    [1/2, 2/3] × [0, 1/10], hence positive on the rectangle. -/
private theorem covDet3_taylorSlope_pos (l g q t δ : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hg_lo : 1/2 ≤ g) (hg_hi : g ≤ 2/3)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346)
    (hd_lo : 0 ≤ δ) (hd_hi : δ ≤ 1/10) :
    covDet3_taylorSlope l g q t δ > 0 := by
  -- Bilinear identity: (1/6)(1/10) f(g,δ) = sum of 4 corner terms
  have h_id : (1/6) * (1/10) * covDet3_taylorSlope l g q t δ =
      (2/3 - g) * (1/10 - δ) * covDet3_taylorSlope l (1/2) q t 0 +
      (g - 1/2) * (1/10 - δ) * covDet3_taylorSlope l (2/3) q t 0 +
      (2/3 - g) * δ * covDet3_taylorSlope l (1/2) q t (1/10) +
      (g - 1/2) * δ * covDet3_taylorSlope l (2/3) q t (1/10) := by
    unfold covDet3_taylorSlope; ring
  have h11 := covDet3_ts_g12_d0 l q t hl hl2 hq_lo hq_hi ht_lo ht_hi
  have h21 := covDet3_ts_g23_d0 l q t hl hl2 hq_lo hq_hi ht_lo ht_hi
  have h12 := covDet3_ts_g12_d10 l q t hl hl2 hq_lo hq_hi ht_lo ht_hi
  have h22 := covDet3_ts_g23_d10 l q t hl hl2 hq_lo hq_hi ht_lo ht_hi
  have hA : 0 ≤ (2/3 - g) * (1/10 - δ) * covDet3_taylorSlope l (1/2) q t 0 :=
    mul_nonneg (mul_nonneg (by linarith) (by linarith)) (le_of_lt h11)
  have hB : 0 ≤ (g - 1/2) * (1/10 - δ) * covDet3_taylorSlope l (2/3) q t 0 :=
    mul_nonneg (mul_nonneg (by linarith) (by linarith)) (le_of_lt h21)
  have hC : 0 ≤ (2/3 - g) * δ * covDet3_taylorSlope l (1/2) q t (1/10) :=
    mul_nonneg (mul_nonneg (by linarith) hd_lo) (le_of_lt h12)
  have hD : 0 ≤ (g - 1/2) * δ * covDet3_taylorSlope l (2/3) q t (1/10) :=
    mul_nonneg (mul_nonneg (by linarith) hd_lo) (le_of_lt h22)
  -- At least one corner has strictly positive weight
  rcases eq_or_lt_of_le hg_lo with rfl | hg_pos
  · rcases eq_or_lt_of_le hd_lo with rfl | hd_pos
    · linarith [mul_pos (mul_pos (show (0:ℝ) < 1/6 by norm_num) (show (0:ℝ) < 1/10 by norm_num)) h11]
    · linarith [mul_pos (mul_pos (show (0:ℝ) < 1/6 by norm_num) hd_pos) h12]
  · rcases eq_or_lt_of_le hd_lo with rfl | hd_pos
    · linarith [mul_pos (mul_pos (by linarith : (0:ℝ) < g - 1/2) (show (0:ℝ) < 1/10 by norm_num)) h21]
    · linarith [mul_pos (mul_pos (by linarith : (0:ℝ) < g - 1/2) hd_pos) h22]

/-- **Full det(C₃) > 0** for A ∈ [l+q-g, l+q-g+1/10]. -/
theorem covDet3Full_pos (A l g q t : ℝ)
    (hl : 6931/10000 < l) (hl2 : l < 7/10)
    (hg_lo : 1/2 ≤ g) (hg_hi : g ≤ 2/3)
    (hq_lo : 549/500 < q) (hq_hi : q < 8*l/5)
    (ht_lo : 157/1566 < t) (ht_hi : t < 35/346)
    (hA_lo : l + q - g ≤ A) (hA_hi : A ≤ l + q - g + 1/10) :
    0 < covDet3Full A l g q t := by
  set δ := A - (l + q - g) with hδ_def
  have hδ_nn : 0 ≤ δ := by linarith
  have hδ_hi : δ ≤ 1/10 := by linarith
  have hA_eq : A = l + q - g + δ := by linarith
  rw [hA_eq, covDet3_taylor_id]
  have h_base := covDet3Expr_pos l g q t hl hl2 hg_lo hg_hi hq_lo hq_hi ht_lo ht_hi
  have h_slope := covDet3_taylorSlope_pos l g q t δ hl hl2 hg_lo hg_hi hq_lo hq_hi ht_lo ht_hi hδ_nn hδ_hi
  linarith [mul_nonneg hδ_nn (le_of_lt h_slope)]
-- ═══════════════════════════════════════════════
-- §7. Final bridge: vasyuninCovMatrix 3
-- ═══════════════════════════════════════════════

-- Entry-level rewrites for the 3 entries not yet in GramEvaluations
private theorem c02_eq : (vasyuninCovMatrix 3) 0 2 =
    vasyuninGramEntry 1 3 - vasyuninMeanEntry 1 * vasyuninMeanEntry 3 := by
  unfold vasyuninCovMatrix vasyuninGramMatrix vasyuninMeanVec Matrix.vecMulVec
  simp [Matrix.sub_apply, Matrix.of_apply]

private theorem c12_eq : (vasyuninCovMatrix 3) 1 2 =
    vasyuninGramEntry 2 3 - vasyuninMeanEntry 2 * vasyuninMeanEntry 3 := by
  unfold vasyuninCovMatrix vasyuninGramMatrix vasyuninMeanVec Matrix.vecMulVec
  simp [Matrix.sub_apply, Matrix.of_apply]

private theorem c22_eq : (vasyuninCovMatrix 3) 2 2 =
    vasyuninGramEntry 3 3 - vasyuninMeanEntry 3 * vasyuninMeanEntry 3 := by
  unfold vasyuninCovMatrix vasyuninGramMatrix vasyuninMeanVec Matrix.vecMulVec
  simp [Matrix.sub_apply, Matrix.of_apply]

/-- Ring identity: the 3×3 covariance determinant (expanded into Gram/mean entries)
    equals covDet3Full(A, l, g, q, t). -/
private theorem covDet3_ring_id : ∀ A l g q t : ℝ,
    (A - 1 - (1 - g) ^ 2) *
      ((A / 2 - 1 / 4 - ((l + 1 - g) / 2) ^ 2) * (A / 3 - 1 / 9 - (q + 1 - g) / 3 * ((q + 1 - g) / 3)) -
        (5 * A / 12 - (q - l) / 12 - t / 2 - 1 / 6 - (l + 1 - g) / 2 * ((q + 1 - g) / 3)) ^ 2) -
    (3 / 4 * A - l / 4 - 1 / 2 - (1 - g) * ((l + 1 - g) / 2)) *
      ((3 / 4 * A - l / 4 - 1 / 2 - (1 - g) * ((l + 1 - g) / 2)) *
          (A / 3 - 1 / 9 - (q + 1 - g) / 3 * ((q + 1 - g) / 3)) -
        (5 * A / 12 - (q - l) / 12 - t / 2 - 1 / 6 - (l + 1 - g) / 2 * ((q + 1 - g) / 3)) *
          (2 * A / 3 - q / 3 + t - 1 / 3 - (1 - g) * ((q + 1 - g) / 3))) +
    (2 * A / 3 - q / 3 + t - 1 / 3 - (1 - g) * ((q + 1 - g) / 3)) *
      ((3 / 4 * A - l / 4 - 1 / 2 - (1 - g) * ((l + 1 - g) / 2)) *
          (5 * A / 12 - (q - l) / 12 - t / 2 - 1 / 6 - (l + 1 - g) / 2 * ((q + 1 - g) / 3)) -
        (A / 2 - 1 / 4 - ((l + 1 - g) / 2) ^ 2) * (2 * A / 3 - q / 3 + t - 1 / 3 - (1 - g) * ((q + 1 - g) / 3)))
    = covDet3Full A l g q t := by intro A l g q t; unfold covDet3Full; ring

set_option maxHeartbeats 51200000 in
/-- **det(C₃) > 0** for the 3×3 covariance matrix.

    Capstone theorem: the determinant of the leading 3×3 submatrix of the
    Vasyunin covariance matrix is strictly positive. -/
theorem covMatrix3_det3_pos :
    (vasyuninCovMatrix 3) 0 0 *
      ((vasyuninCovMatrix 3) 1 1 * (vasyuninCovMatrix 3) 2 2 -
       (vasyuninCovMatrix 3) 1 2 ^ 2) -
    (vasyuninCovMatrix 3) 0 1 *
      ((vasyuninCovMatrix 3) 0 1 * (vasyuninCovMatrix 3) 2 2 -
       (vasyuninCovMatrix 3) 1 2 * (vasyuninCovMatrix 3) 0 2) +
    (vasyuninCovMatrix 3) 0 2 *
      ((vasyuninCovMatrix 3) 0 1 * (vasyuninCovMatrix 3) 1 2 -
       (vasyuninCovMatrix 3) 1 1 * (vasyuninCovMatrix 3) 0 2) > 0 := by
  -- Step 1: Rewrite all 6 covariance entries
  rw [covEntry_00, covEntry_01, covEntry_11, c02_eq, c12_eq, c22_eq]
  rw [vasyuninGramEntry_one_three, vasyuninGramEntry_two_three,
      vasyuninGramEntry_three_three,
      vasyuninMeanEntry_one, vasyuninMeanEntry_two, vasyuninMeanEntry_three]
  rw [Real.log_mul (by norm_num : (2:ℝ) ≠ 0) (ne_of_gt Real.pi_pos)]
  rw [show Real.log (3/2 : ℝ) = Real.log 3 - Real.log 2 from by
    rw [show (3:ℝ)/2 = 3 * 2⁻¹ from by ring,
        Real.log_mul (by norm_num) (by norm_num : (2:ℝ)⁻¹ ≠ 0),
        Real.log_inv]; ring]
  -- Step 2: Set up transcendental variables
  set l := Real.log 2
  set g := Real.eulerMascheroniConstant
  set q := Real.log 3
  set t := Real.pi / (18 * Real.sqrt 3)
  set A := l + Real.log Real.pi - g
  -- Step 3: Normalize π/(36√3) → t/2
  have ht2 : Real.pi / (36 * Real.sqrt 3) = t / 2 := by
    show Real.pi / (36 * Real.sqrt 3) = Real.pi / (18 * Real.sqrt 3) / 2; ring
  rw [ht2]
  -- Step 4: Apply ring identity
  rw [covDet3_ring_id]
  -- Step 5: Apply covDet3Full_pos with transcendental bounds
  exact covDet3Full_pos A l g q t
    (by linarith [Real.log_two_gt_d9])
    log_two_lt_seven_tenths
    (le_of_lt Real.one_half_lt_eulerMascheroniConstant)
    (le_of_lt Real.eulerMascheroniConstant_lt_two_thirds)
    log_three_gt_549_500
    (by -- 5·ln(3) < 8·ln(2) since 3⁵ = 243 < 256 = 2⁸
        have h := Real.log_lt_log (show (0:ℝ) < 3^5 by norm_num) (show (3:ℝ)^5 < 2^8 by norm_num)
        simp only [Real.log_pow] at h; push_cast at h; linarith)
    pi_div_18sqrt3_gt
    pi_div_18sqrt3_lt
    (by linarith [Real.log_le_log (show (0:ℝ) < 3 from by norm_num) (le_of_lt pi_gt_three)])
    (by -- ln(π/3) < 1/10: since π < 3.15, π/3 < 1.05, and exp(1/10) ≥ 1.1 > 1.05
        have h_log_pi3 : Real.log (Real.pi / 3) < 1/10 := by
          rw [show (1:ℝ)/10 = Real.log (Real.exp (1/10)) from (Real.log_exp _).symm]
          exact Real.log_lt_log (by positivity)
            (by linarith [Real.pi_lt_d2, Real.add_one_le_exp (1/10 : ℝ)])
        have h_log_split : Real.log (Real.pi / 3) = Real.log Real.pi - Real.log 3 := by
          rw [show Real.pi / 3 = Real.pi * 3⁻¹ from by ring,
              Real.log_mul (ne_of_gt Real.pi_pos) (by positivity), Real.log_inv]; ring
        linarith)

end Cathedral.Vasyunin

