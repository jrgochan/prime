-- Import the three RH-producing assemblies
import Cathedral.Geometry.Wall.VacuumStability
import Cathedral.Assembly.GramCrown
import Cathedral.Geometry.Bernoulli.BernoulliCrown

/-!
  # Cathedral Axiom Audit — Definitive Trace

  This file imports ALL theorem-bearing assemblies and runs
  `#print axioms` on every RH-producing theorem.

  Run: `lake build Cathedral.Audit.AxiomTrace`
  then read the Lean info log for the complete axiom ledger.

  ## Wall Consolidation (June 4, 2026)

  The triplicate wall axiom has been consolidated:
  - **CANONICAL**: `overcancellation_axiom` in `Cathedral.Wall`
  - **ALIASES**: `overcancellation_hypothesis` (GramCrown),
    `vtGv_lt_one` (VacuumStability),
    `overcancellation_axiom_local` (BernoulliCrown)
  - All `#print axioms` traces should now show a single
    `overcancellation_axiom` instead of three separate axioms.

  Created: June 4, 2026 — The Axiom Audit
-/

-- ════════════════════════════════════════════════
-- §1. PRIMARY PATH: VacuumStability
-- ════════════════════════════════════════════════

#print axioms Cathedral.Geometry.Wall.VacuumStability.riemann_hypothesis

-- ════════════════════════════════════════════════
-- §2. PRIMARY PATH: GramCrown (Overcancellation)
-- ════════════════════════════════════════════════

#print axioms riemann_hypothesis_from_gram_global

-- ════════════════════════════════════════════════
-- §3. LEGACY: GramCrown (Direct Gram Bound)
-- ════════════════════════════════════════════════

#print axioms riemann_hypothesis_from_gram_direct

-- ════════════════════════════════════════════════
-- §4. LEGACY: GramCrown (Subsequential)
-- ════════════════════════════════════════════════

#print axioms riemann_hypothesis_from_gram_subseq

-- ════════════════════════════════════════════════
-- §5. OVERCANCELLATION CHAIN (intermediary)
-- ════════════════════════════════════════════════

#print axioms overcancellation_implies_rh

-- ════════════════════════════════════════════════
-- §6. DOT PRODUCT CONVERGENCE (PNT engine)
-- ════════════════════════════════════════════════

#print axioms dot_product_tends_to_zero

-- ════════════════════════════════════════════════
-- §7. NYMAN-BEURLING CONVERSE (the kernel-certified side)
-- ════════════════════════════════════════════════

#print axioms nyman_beurling_converse

-- ════════════════════════════════════════════════
-- §8. BAEZ-DUARTE FORWARD (graduated)
-- ════════════════════════════════════════════════

#print axioms baez_duarte_forward

-- ════════════════════════════════════════════════
-- §9. NB EQUIVALENCE (the iff)
-- ════════════════════════════════════════════════

#print axioms nyman_beurling_equivalence

-- ════════════════════════════════════════════════
-- §10. BERNOULLI CROWN: vtGv_from_bernoulli_decomp
-- ════════════════════════════════════════════════

#print axioms Cathedral.Geometry.Bernoulli.BernoulliCrown.vtGv_from_bernoulli_decomp

-- ════════════════════════════════════════════════
-- §11. SMITH WITNESS (zero-axiom forward)
-- ════════════════════════════════════════════════

#print axioms smith_witness_forward_direction

-- ════════════════════════════════════════════════
-- §12. SPECTRAL ENERGY DIVERGENCE (zero-axiom)
-- ════════════════════════════════════════════════

#print axioms spectral_energy_divergence

-- ════════════════════════════════════════════════
-- §13. PNT SUMS (graduated or axiom?)
-- ════════════════════════════════════════════════

#print axioms pnt_mu_div_k
#print axioms pnt_mu_log_div_k
#print axioms pnt_mu_log_sq_div_k

-- ════════════════════════════════════════════════
-- §14. THE WALL — CONSOLIDATED (June 4, 2026)
-- ════════════════════════════════════════════════

-- BEFORE: Three separate axiom declarations (semantically identical):
--   Cathedral.Geometry.Bernoulli.BernoulliCrown.overcancellation_axiom  (local gramQuadForm)
--   overcancellation_hypothesis                                (GramCrown)
--   Cathedral.Geometry.Wall.VacuumStability.vtGv_lt_one             (VacuumStability)
--
-- AFTER: Single canonical axiom in Cathedral.Wall:
--   overcancellation_axiom : ∃ N₀, ∀ N ≥ N₀, N ≥ 3 → vᵀGv ≤ 1
--
-- The other names are now `def` aliases:
--   overcancellation_hypothesis := overcancellation_axiom
--   vtGv_lt_one := overcancellation_axiom
--   overcancellation_axiom_local := overcancellation_axiom (via unfold)

-- The ONE canonical axiom:
#print axioms overcancellation_axiom

-- Verify aliases resolve to the same canonical axiom:
#print axioms overcancellation_hypothesis
#print axioms Cathedral.Geometry.Wall.VacuumStability.vtGv_lt_one
#print axioms Cathedral.Geometry.Bernoulli.BernoulliCrown.overcancellation_axiom_local
