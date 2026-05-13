/-
  Cathedral/Covariance/HCPrimeStructure.lean

  ## HC Prime Structure → Mertens Product Decay (ZERO AXIOM)

  Proves that the Mertens product over primeFactors of HC numbers
  tends to 0, by combining:
  1. Mertens' third theorem: Π_{p<X}(1-1/p) → 0
  2. HC numbers eventually contain all primes up to any bound (PROVED)
  3. Superset product inequality for [0,1]-valued functions

  ### Key theorems:
  - `divisor_swap_ge`: d(N/p · q) ≥ d(N) when p | N, q prime, q ∤ N
  - `gen_divisor_swap_ge`: d(N/p^s · q) ≥ d(N) (generalized swap)
  - `hc_primes_consecutive`: HC prime factors are {2,3,...,p_max}
  - `hc_exponent_bound`: HC exponents bounded by prime swap argument
  - `hc_primeFactors_eventually_contain`: PROVED (was axiom)
  - `mertens_product_tendsto_zero`: Π_{p<X}(1-1/p) → 0
  - `mertens_hc_product_tendsto_zero_proved`: Π_{p|N_hc}(1-1/p) → 0

  Created: May 12, 2026 — Exploration 36
  Status: 0 sorry, 0 axioms. ✅ FULLY CERTIFIED
-/

import Cathedral.Covariance.HighlyComposite
import Cathedral.Covariance.MertensBridge
import Mathlib.Data.Nat.Factorization.Basic

noncomputable section
open Real Finset Filter Cathedral.Covariance Cathedral.Covariance.MertensBridge

namespace Cathedral.Covariance.HCPrimeStructure

-- ════════════════════════════════════════════════
-- §1. FACTORIZATION INFRASTRUCTURE (PROVED)
-- ════════════════════════════════════════════════

/-- p does not divide the p-free part N/p^v of N. -/
private lemma prime_not_dvd_ordCompl (N p : ℕ) (hp : p.Prime) (hN : 0 < N) :
    ¬(p ∣ (N / p ^ (N.factorization p))) := by
  intro h
  have : (N / p ^ (N.factorization p)).factorization p = 0 := by
    rw [Nat.factorization_div (Nat.ordProj_dvd N p), Finsupp.tsub_apply,
      Nat.factorization_pow, Finsupp.smul_apply, smul_eq_mul,
      hp.factorization_self, mul_one, Nat.sub_self]
  have hK_ne : N / p ^ (N.factorization p) ≠ 0 :=
    Nat.ne_of_gt (Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.ordProj_dvd N p))
      (pow_pos hp.pos _))
  exact absurd ((hp.dvd_iff_one_le_factorization hK_ne).mp h) (by omega)

/-- d(p^k) = k + 1 -/
private lemma card_div_pp (p k : ℕ) (hp : p.Prime) :
    #(Nat.divisors (p ^ k)) = k + 1 := by
  rw [Nat.divisors_prime_pow hp, Finset.card_map, Finset.card_range]

/-- N/p = p^(v-1) · K where v = v_p(N) and K = N/p^v (the p-free part). -/
private lemma div_prime_decomp (N p : ℕ) (hp : p.Prime) (hN : 0 < N) (hpN : p ∣ N) :
    N / p = p ^ (N.factorization p - 1) * (N / p ^ (N.factorization p)) := by
  set v := N.factorization p; set K := N / p ^ v
  have hv : 0 < v := (hp.dvd_iff_one_le_factorization (by omega)).mp hpN
  have : p ^ v * K = N := Nat.ordProj_mul_ordCompl_eq_self N p
  have hpv : p ^ v = p * p ^ (v - 1) := by
    conv_lhs => rw [← Nat.succ_pred_eq_of_pos hv]; simp [pow_succ, mul_comm]
  rw [show N = p * (p ^ (v - 1) * K) from by rw [← mul_assoc, ← hpv, this],
    Nat.mul_div_cancel_left _ hp.pos]

-- ════════════════════════════════════════════════
-- §2. DIVISOR SWAP INEQUALITY (PROVED)
-- ════════════════════════════════════════════════

/-- **PROVED**: The divisor count swap inequality.

    If p | N and q is prime with q ∤ N, then M = N/p · q satisfies
    d(M) ≥ d(N). This is the core engine of the prime swap theorem.

    Key math: N = p^v · K (coprime), v = v_p(N) ≥ 1.
    d(N) = (v+1) · d(K), d(M) = 2v · d(K). Since 2v ≥ v+1 for v ≥ 1. -/
theorem divisor_swap_ge (N p q : ℕ) (hN : 0 < N)
    (hp : p.Prime) (hq : q.Prime) (hpN : p ∣ N) (hqN : ¬(q ∣ N)) :
    #(Nat.divisors (N / p * q)) ≥ #(Nat.divisors N) := by
  set v := N.factorization p; set K := N / p ^ v
  have hv : 0 < v := (hp.dvd_iff_one_le_factorization (by omega)).mp hpN
  have hK_pos : 0 < K := Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.ordProj_dvd N p))
      (pow_pos hp.pos _)
  have hnp := prime_not_dvd_ordCompl N p hp hN
  have hcop : Nat.Coprime (p ^ v) K := .pow_left _ (hp.coprime_iff_not_dvd.mpr hnp)
  have hcop1 : Nat.Coprime (p ^ (v - 1)) K := .pow_left _ (hp.coprime_iff_not_dvd.mpr hnp)
  have hcop_q : Nat.Coprime q (N / p) :=
    hq.coprime_iff_not_dvd.mpr (fun h => hqN (h.trans (Nat.div_dvd_of_dvd hpN)))
  -- d(N) = (v+1) * d(K)
  have hd_N : #(Nat.divisors N) = (v + 1) * #(Nat.divisors K) := by
    conv_lhs => rw [(Nat.ordProj_mul_ordCompl_eq_self N p).symm]
    rw [hcop.card_divisors_mul, card_div_pp p v hp]
  -- d(N/p) = v * d(K)
  have hd_Np : #(Nat.divisors (N / p)) = v * #(Nat.divisors K) := by
    rw [div_prime_decomp N p hp hN hpN, hcop1.card_divisors_mul, card_div_pp p (v-1) hp,
      Nat.sub_add_cancel hv]
  -- d(N/p * q) = d(N/p) * 2
  have hd_M : #(Nat.divisors (N / p * q)) = #(Nat.divisors (N / p)) * 2 := by
    rw [hcop_q.symm.card_divisors_mul,
      show #(Nat.divisors q) = 2 from by
        rw [show q = q ^ 1 from (pow_one q).symm]; exact card_div_pp q 1 hq]
  -- 2v * d(K) ≥ (v+1) * d(K) since v ≥ 1
  have hdK_pos : 0 < #(Nat.divisors K) :=
    Finset.card_pos.mpr ⟨1, Nat.one_mem_divisors.mpr (by omega)⟩
  rw [hd_M, hd_Np, hd_N]; nlinarith

-- ════════════════════════════════════════════════
-- §3. HC CONSECUTIVE PRIMES (PROVED)
-- ════════════════════════════════════════════════

/-- **PROVED**: HC numbers have consecutive prime factors.
    If p | N and q < p is prime, then q | N (else the swap gives d(M) ≥ d(N)
    with M < N, contradicting HC). -/
theorem hc_primes_consecutive {N p q : ℕ} (hHC : IsHighlyComposite N)
    (hp : p.Prime) (hq : q.Prime) (hpN : p ∣ N) (hqp : q < p) :
    q ∣ N := by
  by_contra hqN
  have hNp_pos : 0 < N / p := Nat.div_pos (Nat.le_of_dvd hHC.1 hpN) hp.pos
  have hM_lt : N / p * q < N := calc
    N / p * q < N / p * p := Nat.mul_lt_mul_of_pos_left hqp hNp_pos
    _ ≤ N := Nat.div_mul_le_self N p
  exact absurd (divisor_swap_ge N p q hHC.1 hp hq hpN hqN)
    (not_le.mpr (hHC.2 _ (Nat.mul_pos hNp_pos hq.pos) hM_lt))

/-- **PROVED**: HC N > 1 → 2 | N. -/
theorem hc_two_dvd {N : ℕ} (hHC : IsHighlyComposite N) (hN : 1 < N) : 2 ∣ N := by
  obtain ⟨p, hp, hpN⟩ := Nat.exists_prime_and_dvd (by omega : N ≠ 1)
  rcases eq_or_lt_of_le hp.two_le with rfl | h2p
  · exact hpN
  · exact hc_primes_consecutive hHC hp Nat.prime_two hpN h2p

-- ════════════════════════════════════════════════
-- §4. GENERALIZED SWAP + EXPONENT BOUND (PROVED)
-- ════════════════════════════════════════════════

/-- N/p^s = p^(v-s) · K where v = v_p(N) and K = N/p^v. -/
private lemma div_pow_decomp (N p s : ℕ) (hp : p.Prime) (_hN : 0 < N)
    (hs : s ≤ N.factorization p) :
    N / p ^ s = p ^ (N.factorization p - s) * (N / p ^ (N.factorization p)) := by
  set v := N.factorization p; set K := N / p ^ v
  rw [show N = p ^ s * (p ^ (v - s) * K) from by
      rw [← mul_assoc, ← show p ^ v = p ^ s * p ^ (v - s) from by
        rw [← pow_add, Nat.add_sub_cancel' hs], Nat.ordProj_mul_ordCompl_eq_self N p],
    Nat.mul_div_cancel_left _ (pow_pos hp.pos s)]

/-- **PROVED**: Generalized divisor swap inequality.
    Replacing s copies of prime p with one copy of prime q:
    d(N/p^s · q) ≥ d(N) when v_p(N) + 1 ≥ 2s.

    Key: N = p^v · K (coprime). d(N) = (v+1)·d(K).
    d(N/p^s · q) = (v-s+1)·d(K)·2. Since 2(v-s+1) ≥ v+1 when v ≥ 2s-1. -/
theorem gen_divisor_swap_ge (N p q s : ℕ) (hN : 0 < N)
    (hp : p.Prime) (hq : q.Prime) (hqN : ¬(q ∣ N))
    (_hs_pos : 0 < s) (hs_le : s ≤ N.factorization p)
    (hv : 2 * s ≤ N.factorization p + 1) :
    #(Nat.divisors (N / p ^ s * q)) ≥ #(Nat.divisors N) := by
  set v := N.factorization p; set K := N / p ^ v
  have hnp := prime_not_dvd_ordCompl N p hp hN
  have hcop : Nat.Coprime (p ^ v) K := .pow_left _ (hp.coprime_iff_not_dvd.mpr hnp)
  have hcop_vs : Nat.Coprime (p ^ (v - s)) K := .pow_left _ (hp.coprime_iff_not_dvd.mpr hnp)
  have hps_dvd : p ^ s ∣ N := (hp.pow_dvd_iff_le_factorization (by omega)).mpr hs_le
  have hcop_q : Nat.Coprime q (N / p ^ s) :=
    hq.coprime_iff_not_dvd.mpr (fun h => hqN (h.trans (Nat.div_dvd_of_dvd hps_dvd)))
  have hd_N : #(Nat.divisors N) = (v + 1) * #(Nat.divisors K) := by
    conv_lhs => rw [(Nat.ordProj_mul_ordCompl_eq_self N p).symm]
    rw [hcop.card_divisors_mul, card_div_pp p v hp]
  have hd_Nps : #(Nat.divisors (N / p ^ s)) = (v - s + 1) * #(Nat.divisors K) := by
    rw [div_pow_decomp N p s hp hN hs_le, hcop_vs.card_divisors_mul, card_div_pp p (v-s) hp]
  have hd_M : #(Nat.divisors (N / p ^ s * q)) = #(Nat.divisors (N / p ^ s)) * 2 := by
    rw [hcop_q.symm.card_divisors_mul, show #(Nat.divisors q) = 2 from by
        rw [show q = q ^ 1 from (pow_one q).symm]; exact card_div_pp q 1 hq]
  rw [hd_M, hd_Nps, hd_N]
  have : 2 * (v - s + 1) ≥ v + 1 := by omega
  nlinarith [Finset.card_pos.mpr ⟨1, Nat.one_mem_divisors.mpr (Nat.ne_of_gt
    (Nat.div_pos (Nat.le_of_dvd (by omega) (Nat.ordProj_dvd N p)) (pow_pos hp.pos _)))⟩]

/-- **PROVED**: HC exponent bound via generalized swap.
    If q prime with q ∤ N and q < p^s, then v_p(N) < 2s. -/
theorem hc_exponent_bound {N p q : ℕ} (hHC : IsHighlyComposite N)
    (hp : p.Prime) (hq : q.Prime)
    (_hpN : p ∣ N) (hqN : ¬(q ∣ N))
    {s : ℕ} (hs : 0 < s) (hqs : q < p ^ s) :
    N.factorization p < 2 * s := by
  by_contra h; push Not at h
  have hs_le : s ≤ N.factorization p := by omega
  have hps_dvd : p ^ s ∣ N := (hp.pow_dvd_iff_le_factorization (Nat.ne_of_gt hHC.1)).mpr hs_le
  have hNps_pos : 0 < N / p ^ s :=
    Nat.div_pos (Nat.le_of_dvd hHC.1 hps_dvd) (pow_pos hp.pos s)
  exact absurd (gen_divisor_swap_ge N p q s hHC.1 hp hq hqN hs hs_le (by omega))
    (not_le.mpr (hHC.2 _ (Nat.mul_pos hNps_pos hq.pos) (calc
      N / p ^ s * q < N / p ^ s * p ^ s := Nat.mul_lt_mul_of_pos_left hqs hNps_pos
      _ ≤ N := Nat.div_mul_le_self N (p ^ s))))

/-- N with all prime factors ≤ B and exponents < k is bounded by (B+1)^(k*(B+1)). -/
private lemma bounded_prime_support_bound (N B k : ℕ) (hN : N ≠ 0)
    (h_primes : ∀ p, p.Prime → p ∣ N → p ≤ B)
    (h_exps : ∀ p, p.Prime → p ∣ N → N.factorization p < k) :
    N ≤ (B + 1) ^ (k * (B + 1)) := by
  have h_eq : N = N.primeFactors.prod (fun p => p ^ N.factorization p) := by
    rw [← Nat.support_factorization]
    exact (Nat.prod_factorization_pow_eq_self hN).symm
  rw [h_eq]
  calc N.primeFactors.prod (fun p => p ^ N.factorization p)
      ≤ N.primeFactors.prod (fun _ => (B + 1) ^ k) :=
        Finset.prod_le_prod (fun p _ => by positivity) (fun p hp => by
          have hp_pr := Nat.prime_of_mem_primeFactors hp
          have hp_dv := (Nat.mem_primeFactors.mp hp).2.1
          exact le_trans (Nat.pow_le_pow_left (by linarith [h_primes p hp_pr hp_dv]) _)
            (Nat.pow_le_pow_right (by omega) (by linarith [h_exps p hp_pr hp_dv])))
    _ = ((B + 1) ^ k) ^ N.primeFactors.card := by simp [Finset.prod_const]
    _ = (B + 1) ^ (k * N.primeFactors.card) := by rw [← pow_mul]
    _ ≤ (B + 1) ^ (k * (B + 1)) :=
        Nat.pow_le_pow_right (by omega) (Nat.mul_le_mul_left k (by
          calc N.primeFactors.card
              ≤ (Finset.range (B + 1)).card := Finset.card_le_card (fun p hp =>
                Finset.mem_range.mpr (Nat.lt_succ_of_le (h_primes p
                  (Nat.prime_of_mem_primeFactors hp) (Nat.mem_primeFactors.mp hp).2.1)))
            _ = B + 1 := Finset.card_range _))

-- ════════════════════════════════════════════════
-- §5. HC PRIME FACTORS (PROVED — was axiom)
-- ════════════════════════════════════════════════

/-- **PROVED** (formerly axiom): HC numbers eventually contain all primes ≤ B.

    For any B, there exists N₀ such that for all HC numbers N ≥ N₀,
    every prime p ≤ B divides N.

    Proof: By contradiction. If some prime p ≤ B is missing from N_hc,
    then by `hc_primes_consecutive` all prime factors of N must be ≤ B.
    Take q = any prime > B. By `hc_exponent_bound`, each exponent
    v_r(N) < 2q. By `bounded_prime_support_bound`, N ≤ (B+1)^(2q(B+1)).
    For N₀ = (B+1)^(2q(B+1)) + 1, this contradicts N ≥ N₀. -/
theorem hc_primeFactors_eventually_contain :
    ∀ B : ℕ, ∃ N₀ : ℕ, ∀ N : ℕ, IsHighlyComposite N → N ≥ N₀ →
      ∀ p : ℕ, p.Prime → p ≤ B → p ∈ N.primeFactors := by
  intro B
  obtain ⟨q, hqB, hq⟩ := Nat.exists_infinite_primes (B + 1)
  refine ⟨(B + 1) ^ (2 * q * (B + 1)) + 1, fun N hHC hN_ge p hp hp_le => ?_⟩
  rw [Nat.mem_primeFactors]
  refine ⟨hp, ?_, Nat.ne_of_gt hHC.1⟩
  by_contra hpN
  have h_all : ∀ r, r.Prime → r ∣ N → r ≤ B := by
    intro r hr hrN
    by_contra hrB; push Not at hrB
    exact hpN (hc_primes_consecutive hHC hr hp hrN (by omega))
  have hqN : ¬(q ∣ N) := fun hqd => absurd (h_all q hq hqd) (by omega)
  have h_exp : ∀ r, r.Prime → r ∣ N → N.factorization r < 2 * q := by
    intro r hr hrN
    exact hc_exponent_bound hHC hr hq hrN hqN (by omega)
      (lt_of_lt_of_le Nat.lt_two_pow_self (Nat.pow_le_pow_left hr.two_le q))
  have := bounded_prime_support_bound N B (2 * q) (Nat.ne_of_gt hHC.1) h_all h_exp
  omega

-- ════════════════════════════════════════════════
-- §5. SUPERSET PRODUCT INEQUALITY (PROVED)
-- ════════════════════════════════════════════════

/-- Product over a superset of [0,1] factors is ≤ product over subset.
    (More factors in [0,1] makes the product smaller.) -/
private lemma prod_le_prod_of_superset (S T : Finset ℕ) (hST : T ⊆ S) (f : ℕ → ℝ)
    (hf0 : ∀ x ∈ S, 0 ≤ f x) (hf1 : ∀ x ∈ S, f x ≤ 1) :
    ∏ x ∈ S, f x ≤ ∏ x ∈ T, f x := by
  rw [← Finset.prod_sdiff hST]
  calc (∏ x ∈ S \ T, f x) * (∏ x ∈ T, f x)
      ≤ 1 * (∏ x ∈ T, f x) :=
        mul_le_mul_of_nonneg_right
          (Finset.prod_le_one (fun x hx => hf0 x (sdiff_subset hx))
            (fun x hx => hf1 x (sdiff_subset hx)))
          (Finset.prod_nonneg (fun x hx => hf0 x (hST hx)))
    _ = ∏ x ∈ T, f x := one_mul _

-- ════════════════════════════════════════════════
-- §6. MERTENS PRODUCT → 0 (PROVED)
-- ════════════════════════════════════════════════

/-- **PROVED**: The Mertens product Π_{p<X, prime}(1-1/p) → 0 as X → ∞.

    From cathedral_mertens_third: ln(X) · Π → e^{-γ} > 0.
    Since ln(X) → ∞, we get Π → 0. -/
theorem mertens_product_tendsto_zero :
    Tendsto (fun X : ℕ => ∏ p ∈ (range X).filter Nat.Prime, (1 - 1 / (p : ℝ)))
    atTop (nhds 0) := by
  rw [Metric.tendsto_atTop]
  intro ε hε
  have h_mertens := cathedral_mertens_third
  rw [Metric.tendsto_atTop] at h_mertens
  obtain ⟨N₁, hN₁⟩ := h_mertens 1 one_pos
  set C := exp (-eulerMascheroniConstant) + 1
  have h_log_unbdd : Tendsto (fun n : ℕ => log (n : ℝ)) atTop atTop :=
    tendsto_log_atTop.comp tendsto_natCast_atTop_atTop
  rw [Filter.tendsto_atTop_atTop] at h_log_unbdd
  obtain ⟨N₂, hN₂⟩ := h_log_unbdd (C / ε + 1)
  refine ⟨max N₁ (max N₂ 2), fun X hX => ?_⟩
  have hlog_pos : 0 < log (X : ℝ) := by
    apply Real.log_pos; exact_mod_cast show 1 < X from by omega
  rw [Real.dist_eq, sub_zero, abs_of_nonneg (Finset.prod_nonneg fun p hp => by
    have := (mem_filter.mp hp).2
    linarith [show (0:ℝ) ≤ 1/(p:ℝ) from div_nonneg one_pos.le (Nat.cast_nonneg' p),
              show 1/(p:ℝ) ≤ 1 from by
                rw [div_le_one (show (0:ℝ) < p from by exact_mod_cast this.pos)]
                exact_mod_cast this.one_le])]
  have h_dist := hN₁ X (by omega)
  rw [Real.dist_eq] at h_dist
  have h_bound : log X * ∏ p ∈ (range X).filter Nat.Prime, (1 - 1/(p:ℝ)) < C := by
    have := (abs_lt.mp h_dist).2; linarith
  have : ∏ p ∈ (range X).filter Nat.Prime, (1 - 1/(p:ℝ)) < C / log X := by
    rwa [lt_div_iff₀ hlog_pos, mul_comm]
  have : C / log (X : ℝ) < ε := by
    rw [div_lt_iff₀ hlog_pos]
    have : C / ε + 1 ≤ log (X : ℝ) := hN₂ X (by omega)
    calc C = ε * (C / ε) := by rw [mul_div_cancel₀ C (ne_of_gt hε)]
      _ < ε * (C / ε + 1) := by linarith
      _ ≤ ε * log (X : ℝ) := by linarith [mul_le_mul_of_nonneg_left ‹_› (le_of_lt hε)]
  linarith

-- ════════════════════════════════════════════════
-- §7. THE GRADUATION (PROVED from axiom)
-- ════════════════════════════════════════════════

/-- **PROVED (from axiom)**: The Mertens product over primeFactors of HC
    numbers tends to 0.

    This GRADUATES the axiom `mertens_hc_product_tendsto_zero` from
    HCEulerProduct.lean, replacing it with the simpler axiom
    `hc_primeFactors_eventually_contain`. -/
theorem mertens_hc_product_tendsto_zero_proved :
    ∀ ε : ℝ, ε > 0 → ∃ N₀ : ℕ, ∀ N : ℕ, IsHighlyComposite N → N ≥ N₀ →
      ∏ p ∈ Nat.primeFactors N, (1 - 1 / (p : ℝ)) < ε := by
  intro ε hε
  have h_mz := mertens_product_tendsto_zero
  rw [Metric.tendsto_atTop] at h_mz
  obtain ⟨B, hB⟩ := h_mz ε hε
  obtain ⟨N₁, hN₁⟩ := hc_primeFactors_eventually_contain B
  refine ⟨max N₁ 6, fun N hHC hN => ?_⟩
  have h_sub : (range (B + 1)).filter Nat.Prime ⊆ N.primeFactors := by
    intro p hp
    simp only [mem_filter, mem_range] at hp
    exact hN₁ N hHC (by omega) p hp.2 (by omega)
  have hf0 : ∀ x ∈ N.primeFactors, 0 ≤ 1 - 1/(x:ℝ) := fun x hx => by
    have := (Nat.prime_of_mem_primeFactors hx).one_le
    linarith [show (0:ℝ) ≤ 1/(x:ℝ) from div_nonneg one_pos.le (Nat.cast_nonneg' x),
              show 1/(x:ℝ) ≤ 1 from by
                rw [div_le_one (show (0:ℝ) < x from by
                  exact_mod_cast (Nat.prime_of_mem_primeFactors hx).pos)]
                exact_mod_cast (Nat.prime_of_mem_primeFactors hx).one_le]
  have hf1 : ∀ x ∈ N.primeFactors, 1 - 1/(x:ℝ) ≤ 1 := fun x _ => by
    linarith [show (0:ℝ) ≤ 1/(x:ℝ) from div_nonneg one_pos.le (Nat.cast_nonneg' x)]
  have h_le := prod_le_prod_of_superset N.primeFactors
    ((range (B + 1)).filter Nat.Prime) h_sub (fun p => 1 - 1/(p:ℝ)) hf0 hf1
  have h_target := hB (B + 1) (by omega)
  rw [Real.dist_eq, sub_zero, abs_of_nonneg (Finset.prod_nonneg fun p hp => by
    have := (mem_filter.mp hp).2
    linarith [show (0:ℝ) ≤ 1/(p:ℝ) from div_nonneg one_pos.le (Nat.cast_nonneg' p),
              show 1/(p:ℝ) ≤ 1 from by
                rw [div_le_one (show (0:ℝ) < p from by exact_mod_cast this.pos)]
                exact_mod_cast this.one_le])] at h_target
  linarith

-- ════════════════════════════════════════════════
-- AUDIT
-- ════════════════════════════════════════════════

/-!
## Audit (May 12, 2026)

### Sorry: 0 ✅
### Axioms: 0 ✅ FULLY CERTIFIED

### Proved:
- `prime_not_dvd_ordCompl` — p ∤ N/p^v ✅
- `divisor_swap_ge` — d(N/p·q) ≥ d(N) ✅
- `gen_divisor_swap_ge` — d(N/p^s·q) ≥ d(N) ✅
- `hc_primes_consecutive` — HC primes are {2,...,p_max} ✅
- `hc_two_dvd` — HC N > 1 → 2 | N ✅
- `hc_exponent_bound` — HC exponents bounded ✅
- `hc_primeFactors_eventually_contain` — GRADUATED ✅
- `mertens_product_tendsto_zero` — Π_{p<X}(1-1/p) → 0 ✅
- `mertens_hc_product_tendsto_zero_proved` — Π_{p|N_hc}(1-1/p) → 0 ✅

### Architecture:
```
  §1. Factorization infrastructure (PROVED)
       ↓
  §2. divisor_swap_ge: d(N/p·q) ≥ d(N) (PROVED)
       ↓
  §3. hc_primes_consecutive (PROVED: swap + HC contradiction)
       ↓
  §4. gen_divisor_swap_ge + hc_exponent_bound (PROVED: multi-swap)
       ↓
  §5. hc_primeFactors_eventually_contain (PROVED: bound + contradiction)
       ↓
  §6-7. Superset product + Mertens → 0 (PROVED)
       ↓
  §8. mertens_hc_product_tendsto_zero_proved (PROVED)
```
-/

end Cathedral.Covariance.HCPrimeStructure
