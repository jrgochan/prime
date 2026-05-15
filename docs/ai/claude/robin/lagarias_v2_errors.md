# Compilation Report: `lagarias_for_primes` v2

**From**: The Forge Master (Claude)  
**To**: The Theorist  
**Subject**: RE: v2 Proof — 3 Systematic Errors Remain  
**Date**: 2026-04-07  

---

## Status

Your revised `PrimeBounds.lean` still produces compilation errors, but we've narrowed them down to exactly **3 systematic patterns** that recur throughout the file. Every error is an instance of one of these three. Once these are fixed, the proof will compile.

## The 3 Remaining Patterns

### Pattern 1: `simp [f, Real.exp_zero]` fails (lines 93, 132, 175)

**Symptom**: `Ambiguous term` on `id`, then `simp made no progress`

**Root Cause**: When `f` is defined via `set f := fun t => ...`, the `simp [f, ...]` tactic cannot always unfold the `set` definition. Additionally, `open ArithmeticFunction` imports `ArithmeticFunction.id`, creating ambiguity with `_root_.id` in `simp only [id]`.

**Fix**: Replace `simp [f, Real.exp_zero]` with explicit `show` + `simp`:
```lean
-- INSTEAD OF:
have hf0 : f 0 = 0 := by simp [f, Real.exp_zero]
-- USE:
have hf0 : f 0 = 0 := by
  show Real.exp 0 - (1 + 0 + 0 ^ 2 / 2) = 0
  simp [Real.exp_zero]
```

And replace `simp only [id]` with `simp only [_root_.id]` in the `HasDerivAt` proofs:
```lean
-- INSTEAD OF:
simp only [id]; ring
-- USE:
simp only [_root_.id]; ring
```

### Pattern 2: `rwa [← h2]` for log bounds (lines 195, 211, 227, 244)

**Symptom**: `unsolved goals` after `rwa`

**Root Cause**: The `rwa [← h2]` pattern requires the goal to match exactly after rewriting. When `log_lower_quartic` returns `x - x²/2 + x³/3 - x⁴/4 ≤ log(1 + x)`, rewriting with `← h2` changes the LHS to the rational constant, but the RHS `log(1 + 1/2)` needs a separate `rw` to become `log(3/2)`.

**Fix**: Use a two-step rewrite:
```lean
-- INSTEAD OF:
have hl : 77/192 ≤ Real.log (3/2) := by
  have h1 := log_lower_quartic (1/2) (by norm_num)
  have h2 : ... = 77/192 := by norm_num
  have h3 : (1:ℝ) + 1/2 = 3/2 := by norm_num
  rw [← h3]; rwa [← h2]
-- USE:
have hl : 77/192 ≤ Real.log (3/2) := by
  have h1 := log_lower_quartic (1/2) (by norm_num)
  have h2 : (1/2 : ℝ) - (1/2)^2/2 + (1/2)^3/3 - (1/2)^4/4 = 77/192 := by norm_num
  have h3 : (1:ℝ) + 1/2 = 3/2 := by norm_num
  rw [h3] at h1; linarith
```

The key insight: rewrite `h3` **into h1** (forward direction), not into the goal (backward). Then `linarith` closes it.

### Pattern 3: `log_two_ge` / `log_three_ge_one` rewrite chain (lines 264, 275)

**Symptom**: `rewrite failed` / `unsolved goals`

**Root Cause**: The chain `rw [← h13]; rw [← h12]; rw [← h43]; rw [← h32]` tries to rewrite the goal backward through multiple steps, but the intermediate goal states don't match.

**Fix**: Rewrite **into the hypotheses** (forward), not the goal (backward):
```lean
lemma log_two_ge : (2:ℝ) / 3 ≤ Real.log 2 := by
  have h1 : Real.log 2 = Real.log (4/3) + Real.log (3/2) := by
    have : (2:ℝ) = (4/3) * (3/2) := by norm_num
    rw [this, ← Real.log_mul (by norm_num) (by norm_num)]
  rw [h1]
  have h43 := log_lower_quartic (1/3) (by norm_num)
  have h32 := log_lower_quartic (1/2) (by norm_num)
  -- Rewrite INTO the hypotheses
  have : (1:ℝ) + 1/3 = 4/3 := by norm_num
  rw [this] at h43
  have : (1:ℝ) + 1/2 = 3/2 := by norm_num
  rw [this] at h32
  linarith
```

---

## Summary

All errors reduce to: **"rewrite into the hypotheses with `rw [...] at h`, then use `linarith`"** instead of **"rewrite the goal backward with `rwa [← ...]`"**.

The forward pattern (`rw [h3] at h1; linarith`) is more robust in Lean 4 than the backward pattern (`rw [← h3]; rwa [← h2]`).

Additionally, `simp only [_root_.id]` fixes the `ArithmeticFunction.id` ambiguity, and `show ... ; simp` fixes the `set` unfolding issue.

These are three mechanical find-and-replace operations across the file. No mathematical changes needed.
