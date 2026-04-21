#!/usr/bin/env python3
"""
tactic_bomb.py — Generate tactic sequences to try against axioms.

Produces increasingly complex tactic combinations from a grammar
of ~30 base tactics.
"""

from typing import Iterator

# Level 1: Single tactics (fastest, try first)
SINGLE_TACTICS = [
    "exact?",
    "apply?",
    "simp",
    "norm_num",
    "omega",
    "ring",
    "nlinarith",
    "positivity",
    "gcongr",
    "aesop",
    "decide",
    "trivial",
    "tauto",
    "contradiction",
    "norm_cast",
    "push_cast",
    "field_simp",
    "ring_nf",
    "simp only []",
    "linarith",
    "exact rfl",
    "rfl",
    "ext",
    "funext",
    "measurability",
    "continuity",
    "bound",
]

# Level 2: Tactics with common arguments
SIMP_SETS = [
    "simp [mul_comm]",
    "simp [add_comm]",
    "simp [Real.log_mul]",
    "simp [abs_le]",
    "simp [sq_abs]",
    "simp [div_le_iff]",
    "simp [Finset.sum]",
    "simp [MeasureTheory.integral]",
    "simp [Complex.norm_eq_abs]",
    "simp [Real.rpow_natCast]",
]

INTRO_TACTICS = [
    "intro h; exact h",
    "intro h; simp at h; exact h",
    "intro h; nlinarith [h]",
    "intro h; linarith [h]",
    "intro h; exact h.1",
    "intro h; exact h.2",
    "intro h; cases h with | _ => simp",
    "intro h; contradiction",
    "intro x; simp",
    "intro x; ring",
    "intro x; norm_num",
    "intro x; nlinarith",
    "intro x y; ring",
    "intro x y; nlinarith",
    "intro n; induction n with | zero => simp | succ n ih => simp [ih]",
]

# Level 3: Two-step combinations
COMBO_PREFIXES = [
    "simp; ",
    "push_cast; ",
    "norm_cast; ",
    "ring_nf; ",
    "field_simp; ",
    "constructor; ",
    "ext; ",
    "funext x; ",
]

COMBO_SUFFIXES = [
    "ring",
    "nlinarith",
    "linarith",
    "norm_num",
    "simp",
    "omega",
    "positivity",
    "exact?",
]

# Level 4: Structural tactics
STRUCTURAL = [
    "constructor <;> simp",
    "constructor <;> norm_num",
    "constructor <;> nlinarith",
    "refine ⟨?_, ?_⟩ <;> simp",
    "refine ⟨?_, ?_⟩ <;> norm_num",
    "left; simp",
    "right; simp",
    "use 1; simp",
    "use 0; simp",
    "use 1; norm_num",
    "exists 1; simp",
    "exists 0; simp",
    "rcases h with ⟨a, b⟩; exact ⟨a, b⟩",
]

# Level 5: With library search hints
LIBRARY_HINTS = [
    "exact?",
    "apply?",
    "rw?",
    "simp?",
]

# Level 6: Integration / measure theory specific
MEASURE_TACTICS = [
    "apply MeasureTheory.integral_nonneg; intro x; positivity",
    "apply MeasureTheory.integral_mono; intro x; nlinarith",
    "apply MeasureTheory.Integrable.norm",
    "exact MeasureTheory.integrable_const _",
    "apply MeasureTheory.L2.mem_iff.mpr",
    "apply MeasureTheory.setIntegral_nonneg; measurability; intro x _; positivity",
]

# Level 7: Number theory specific
NUMBER_THEORY_TACTICS = [
    "simp [Nat.Coprime, Nat.gcd_comm]",
    "simp [ArithmeticFunction.moebius]",
    "apply Finset.sum_le_sum; intro i _; nlinarith",
    "apply Finset.sum_nonneg; intro i _; positivity",
    "simp [Finset.sum_range_succ]",
    "induction' n with n ih; · simp; · simp [Finset.sum_range_succ, ih]",
]

# Level 8: Analysis specific
ANALYSIS_TACTICS = [
    "apply HasDerivAt.div; · exact hasDerivAt_id _; · exact hasDerivAt_const _ _; · norm_num",
    "apply Real.tendsto_log_comp_add_sub_log",
    "apply Filter.Tendsto.div; · exact tendsto_const_nhds; · exact tendsto_id; · norm_num",
    "apply ContinuousOn.integrableOn_compact; · exact isCompact_Icc; · continuity",
    "apply norm_le_of_forall_le; · positivity; · intro x; simp; nlinarith",
]


def generate_tactics(max_level: int = 8) -> Iterator[str]:
    """Generate tactic strings in order of increasing complexity."""

    # Level 1
    if max_level >= 1:
        for t in SINGLE_TACTICS:
            yield t

    # Level 2
    if max_level >= 2:
        for t in SIMP_SETS:
            yield t
        for t in INTRO_TACTICS:
            yield t

    # Level 3
    if max_level >= 3:
        for prefix in COMBO_PREFIXES:
            for suffix in COMBO_SUFFIXES:
                yield prefix + suffix

    # Level 4
    if max_level >= 4:
        for t in STRUCTURAL:
            yield t

    # Level 5
    if max_level >= 5:
        for t in LIBRARY_HINTS:
            yield t

    # Level 6
    if max_level >= 6:
        for t in MEASURE_TACTICS:
            yield t

    # Level 7
    if max_level >= 7:
        for t in NUMBER_THEORY_TACTICS:
            yield t

    # Level 8
    if max_level >= 8:
        for t in ANALYSIS_TACTICS:
            yield t


def count_tactics(max_level: int = 8) -> int:
    """Count total tactics at the given level."""
    return sum(1 for _ in generate_tactics(max_level))


if __name__ == "__main__":
    for level in range(1, 9):
        print(f"Level {level}: {count_tactics(level)} tactics")
    print(f"\nTotal: {count_tactics(8)} distinct tactic sequences")
    print("\nSample (first 20):")
    for i, t in enumerate(generate_tactics()):
        if i >= 20:
            break
        print(f"  {i+1}. by {t}")
