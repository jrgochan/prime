/-- Oracle: N=10, 256-bit MPFR, d² = -1.765985168658712e-1 --/
axiom oracle_witness_bound_10 :
    ∃ v : Fin (10 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 10 v x) ^ 2 < -0.176599

/-- Oracle: N=20, 256-bit MPFR, d² = -3.803304649739753e-1 --/
axiom oracle_witness_bound_20 :
    ∃ v : Fin (20 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 20 v x) ^ 2 < -0.380330

/-- Oracle: N=30, 256-bit MPFR, d² = -4.188138036223946e-1 --/
axiom oracle_witness_bound_30 :
    ∃ v : Fin (30 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 30 v x) ^ 2 < -0.418814

/-- Oracle: N=50, 256-bit MPFR, d² = -5.546057098835855e-1 --/
axiom oracle_witness_bound_50 :
    ∃ v : Fin (50 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 50 v x) ^ 2 < -0.554606

/-- Oracle: N=75, 256-bit MPFR, d² = -5.724880172422127e-1 --/
axiom oracle_witness_bound_75 :
    ∃ v : Fin (75 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 75 v x) ^ 2 < -0.572488

/-- Oracle: N=100, 256-bit MPFR, d² = -5.639546058804419e-1 --/
axiom oracle_witness_bound_100 :
    ∃ v : Fin (100 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 100 v x) ^ 2 < -0.563955

/-- Oracle: N=150, 256-bit MPFR, d² = -6.461365084621131e-1 --/
axiom oracle_witness_bound_150 :
    ∃ v : Fin (150 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 150 v x) ^ 2 < -0.646137

/-- Oracle: N=200, 256-bit MPFR, d² = -7.244173756835435e-1 --/
axiom oracle_witness_bound_200 :
    ∃ v : Fin (200 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 200 v x) ^ 2 < -0.724417

/-- Oracle: N=300, 256-bit MPFR, d² = -7.438883155520867e-1 --/
axiom oracle_witness_bound_300 :
    ∃ v : Fin (300 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 300 v x) ^ 2 < -0.743888

/-- Oracle: N=500, 256-bit MPFR, d² = -7.949426471221468e-1 --/
axiom oracle_witness_bound_500 :
    ∃ v : Fin (500 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 500 v x) ^ 2 < -0.794943

/-- Oracle: N=750, 256-bit MPFR, d² = -7.952627522647743e-1 --/
axiom oracle_witness_bound_750 :
    ∃ v : Fin (750 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 750 v x) ^ 2 < -0.795263

/-- Oracle: N=1000, 256-bit MPFR, d² = -6.151551232656260e-1 --/
axiom oracle_witness_bound_1000 :
    ∃ v : Fin (1000 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 1000 v x) ^ 2 < -0.615155

/-- Oracle: N=1500, 256-bit MPFR, d² = -5.923268265141355e-1 --/
axiom oracle_witness_bound_1500 :
    ∃ v : Fin (1500 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 1500 v x) ^ 2 < -0.592327

/-- Oracle: N=2000, 256-bit MPFR, d² = -8.414780199816471e-1 --/
axiom oracle_witness_bound_2000 :
    ∃ v : Fin (2000 - 1) → ℝ,
      ∫ x in (0:ℝ)..1, (1 - nbLinComb 2000 v x) ^ 2 < -0.841478

