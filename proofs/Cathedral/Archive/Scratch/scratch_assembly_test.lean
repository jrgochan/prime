import Cathedral.NumberTheory.EulerProductGraduation

noncomputable section
open Real Finset BigOperators
open ArithmeticFunction
open scoped ArithmeticFunction.Moebius

open Cathedral.NumberTheory.EulerProductGraduation
open Cathedral.NumberTheory.EulerProductLimit

set_option maxHeartbeats 1600000

private abbrev J₂ := Cathedral.Physics.BernoulliSkeleton.jordanTotient2

-- ═══ Step 1: Pointwise term splitting for A(d) ═══
private theorem div_proj_term_split (d n : ℕ) :
    (↑(μ (d * (n + 1))) : ℝ) / ((d * (n + 1) : ℕ) : ℝ) ^ 2 =
    (↑(μ d) : ℝ) / (d : ℝ) ^ 2 *
      (if Nat.Coprime d (n + 1) then (↑(μ (n + 1)) : ℝ) / ((n + 1 : ℕ) : ℝ) ^ 2 else 0) := by
  by_cases hcop : Nat.Coprime d (n + 1)
  · rw [if_pos hcop]
    have hmu : (↑(μ (d * (n + 1))) : ℝ) = (↑(μ d) : ℝ) * (↑(μ (n + 1)) : ℝ) :=
      by exact_mod_cast moebius_mul_of_coprime hcop
    rw [hmu, show ((d * (n + 1) : ℕ) : ℝ) ^ 2 = (d : ℝ) ^ 2 * ((n + 1 : ℕ) : ℝ) ^ 2
      from by push_cast; ring]
    ring
  · rw [if_neg hcop, mul_zero]
    have : (↑(μ (d * (n + 1))) : ℝ) = 0 :=
      by exact_mod_cast moebius_mul_zero_of_not_coprime hcop
    simp [this]

-- ═══ Step 2: A(d) = μ(d)/d² · CR(d) ═══
theorem div_proj_eq_moebius_cr (d : ℕ) (hd : 0 < d) :
    divisorProjection d = (↑(μ d) : ℝ) / (d : ℝ) ^ 2 * coprimeRestricted d := by
  unfold divisorProjection
  rw [if_neg hd.ne']
  show ∑' n, _ = (↑(μ d) : ℝ) / (d : ℝ) ^ 2 * ∑' n, _
  rw [← tsum_mul_left]
  congr 1; funext n
  exact div_proj_term_split d n

-- ═══ Step 3: μ(d) ≠ 0 for squarefree d > 0 ═══
private theorem moebius_ne_zero_of_squarefree :
    ∀ d : ℕ, 0 < d → Squarefree d → (μ d : ℤ) ≠ 0 := by
  intro d
  induction d using Nat.strongRecOn with
  | _ d ih =>
    intro hd hd_sf
    by_cases h1 : d = 1
    · subst h1; simp [isMultiplicative_moebius.map_one]
    · obtain ⟨p, hp, hpdvd⟩ := Nat.exists_prime_and_dvd h1
      have hq_pos : 0 < d / p := Nat.div_pos (Nat.le_of_dvd hd hpdvd) hp.pos
      have hq_lt : d / p < d := Nat.div_lt_self hd hp.one_lt
      have hcop : Nat.Coprime p (d / p) :=
        Nat.coprime_of_squarefree_mul (show Squarefree (p * (d / p)) by rwa [Nat.mul_div_cancel' hpdvd])
      have hq_sf : Squarefree (d / p) := fun c hc => hd_sf c (hc.trans (Nat.div_dvd_of_dvd hpdvd))
      rw [show d = p * (d / p) from (Nat.mul_div_cancel' hpdvd).symm,
          isMultiplicative_moebius.map_mul_of_coprime hcop]
      exact mul_ne_zero (by simp [moebius_apply_prime hp]) (ih _ hq_lt hq_pos hq_sf)

-- ═══ Step 4: μ(d)² = 1 for squarefree d > 0 ═══
theorem moebius_sq_eq_one (d : ℕ) (hd : 0 < d) (hd_sf : Squarefree d) :
    (↑(μ d) : ℝ) ^ 2 = 1 := by
  have hne := moebius_ne_zero_of_squarefree d hd hd_sf
  have hab := abs_moebius_le_one (n := d)
  have hmem : μ d = 1 ∨ μ d = -1 := by
    have habs := abs_le.mp hab
    omega
  rcases hmem with h | h <;> simp [h]

-- ═══ Step 5: J₂(d)·A(d)² = (6/π²)²/J₂(d) for squarefree d > 0 ═══
theorem j2_A_sq_eq_of_squarefree (d : ℕ) (hd : 0 < d) (hd_sf : Squarefree d) :
    J₂ d * (divisorProjection d) ^ 2 = (6 / π ^ 2) ^ 2 / J₂ d := by
  have hd_ne : (d : ℝ) ≠ 0 := Nat.cast_ne_zero.mpr hd.ne'
  have hd2_ne : (d : ℝ) ^ 2 ≠ 0 := pow_ne_zero _ hd_ne
  have hprod_pos := prod_one_sub_inv_sq_pos d hd
  have hprod_ne := ne_of_gt hprod_pos
  have hj2_pos : 0 < J₂ d := by
    unfold J₂ Cathedral.Physics.BernoulliSkeleton.jordanTotient2
    exact mul_pos (by positivity) hprod_pos
  have hj2_ne := ne_of_gt hj2_pos
  have hpi_ne : (π : ℝ) ≠ 0 := pi_ne_zero
  have hpi2_ne : π ^ 2 ≠ 0 := pow_ne_zero _ hpi_ne
  -- A(d) = μ(d)/d² · CR(d)
  rw [div_proj_eq_moebius_cr d hd]
  -- CR(d) = (6/π²) / Π(1-1/p²)
  rw [coprime_restricted_moebius_sum d hd hd_sf]
  -- J₂(d) = d² · Π(1-1/p²)
  unfold J₂ Cathedral.Physics.BernoulliSkeleton.jordanTotient2
  -- μ(d)² = 1
  have hmu_sq := moebius_sq_eq_one d hd hd_sf
  -- Algebraic simplification:
  -- d²·Π · (μ(d)/d² · (6/π²)/Π)² = (6/π²)² / (d²·Π)
  field_simp
  nlinarith [hmu_sq, sq_nonneg ((6 : ℝ) / π ^ 2)]

-- ═══ Step 6: Pointwise identity for ALL d ═══
theorem j2_A_sq_pointwise (d : ℕ) :
    J₂ d * (divisorProjection d) ^ 2 =
    (6 / π ^ 2) ^ 2 * (if d = 0 then 0 else if Squarefree d then 1 / J₂ d else 0) := by
  by_cases hd0 : d = 0
  · subst hd0; simp [divisorProjection_zero]
  · rw [if_neg hd0]
    have hd : 0 < d := Nat.pos_of_ne_zero hd0
    by_cases hd_sf : Squarefree d
    · rw [if_pos hd_sf, j2_A_sq_eq_of_squarefree d hd hd_sf]
      ring
    · rw [if_neg hd_sf, mul_zero, divisorProjection_nonsquarefree d hd hd_sf]
      ring

-- ═══ Step 7: THE MAIN THEOREM — HasSum form ═══
theorem euler_product_assembly :
    HasSum (fun d : ℕ => J₂ d * (divisorProjection d) ^ 2) (6 / π ^ 2) := by
  -- Rewrite the target value: 6/π² = (6/π²)² · π²/6
  rw [show (6 : ℝ) / π ^ 2 = (6 / π ^ 2) ^ 2 * (π ^ 2 / 6) from
    six_over_pi_sq_squared_times_zeta2.symm]
  -- Show our function equals (6/π²)² * g(d) pointwise
  have hfun : (fun d : ℕ => J₂ d * (divisorProjection d) ^ 2) =
      (fun d : ℕ => (6 / π ^ 2) ^ 2 *
        (if d = 0 then 0 else if Squarefree d then 1 / J₂ d else 0)) :=
    funext j2_A_sq_pointwise
  rw [hfun]
  -- Apply: HasSum(g, π²/6) → HasSum((6/π²)²·g, (6/π²)²·π²/6)
  exact squarefree_reciprocal_j2_sum.mul_left _
