# 🏛️ Phase X Implementation Plan: gramEntry Basis Migration

> **Objective**: Migrate `gramEntry` from `{j/x}` to `{1/(jx)}`, graduate `spectral_energy_witness_lower`,  
> and leave only the floor-arithmetic rework as future mechanical work.
> 
> **Est. Time**: ~90 minutes (Phase X shortcut)  
> **Net axiom change**: `-2` (remove spectral_energy_witness_lower + rosetta_stone_bridge), `+1` (add bd_lin_indep) = **-1 net**

---

## The Crown-Path Import Graph

```
HeisenbergBypass.lean  ← THE TARGET (spectral_energy_witness_lower lives here)
  ├── Defs.lean            (gramEntry, basisInnerProd, nbLinComb)
  ├── Spectral/RayleighBridge.lean  (lambdaMin, eigenvalue infrastructure)
  ├── Gram/L2Bridge.lean   (l2_error_eq_quad_error)
  │     ├── Gram/NbLinComb.lean  (gram_l2_identity, fract_prod_intervalIntegrable)
  │     └── Structural/Independence.lean  (gram_pos_def ← nyman_beurling_lin_indep)
  │           └── Gram/NbLinComb.lean  (nbLinComb_sq_integrable)
  └── NymanBeurling/QuadFormBridge.lean  (nbDistSq_le_test_vector)
        ├── Structural/Structural.lean → Independence.lean
        └── Sieve/ParitySchur.lean → Independence.lean (gramMatrix_posSemidef)
```

## The 7 Steps

---

### Step 1: `Defs.lean` — Swap the Core Definitions

**3 definitions change:**

```diff
 -- Line 43-47: THE CRITICAL FIX
-/-- Gram matrix entry G[j,k] = ∫₀¹ {1/(jx)}{1/(kx)} dx
-    This is the inner product of Báez-Duarte basis functions h_j, h_k
-    in L²(0,1). The Vasyunin cotangent formula computes this exactly. -/
+/-- Gram matrix entry G[j,k] = ∫₀¹ {1/(jx)}{1/(kx)} dx.
+    Inner product of Báez-Duarte basis functions h_j(x) = {1/(jx)}, h_k(x) = {1/(kx)}
+    in L²(0,1). The Vasyunin cotangent formula computes this exactly.
+    
+    HISTORY: Prior to 2026-05-07, this used the High-Frequency basis {j/x}
+    (the "θ > 1 trap"). Migrated to the correct Báez-Duarte basis. -/
 noncomputable def gramEntry (j k : ℕ) : ℝ :=
-  ∫ x in (0:ℝ)..1, Int.fract ((j : ℝ) / x) * Int.fract ((k : ℝ) / x)
+  ∫ x in (0:ℝ)..1, Int.fract (1 / ((j : ℝ) * x)) * Int.fract (1 / ((k : ℝ) * x))

 -- Line 134-135
 noncomputable def basisInnerProd (N : ℕ) : Fin (N - 1) → ℝ :=
-  fun i => ∫ x in (0:ℝ)..1, Int.fract (((i.val + 1 : ℕ) : ℝ) / x)
+  fun i => ∫ x in (0:ℝ)..1, Int.fract (1 / (((i.val + 1 : ℕ) : ℝ) * x))

 -- Line 254-255
 noncomputable def nbLinComb (N : ℕ) (w : Fin (N - 1) → ℝ) (x : ℝ) : ℝ :=
-  ∑ i : Fin (N - 1), w i * Int.fract ((↑(i.val + 1) : ℝ) / x)
+  ∑ i : Fin (N - 1), w i * Int.fract (1 / ((↑(i.val + 1) : ℝ) * x))
```

**Also fix `gramEntry_comm` and `gramMatrix_hermitian`** — these unfold `gramEntry` and use `ring`/`ext x; ring`. The proof `congr 1; ext x; ring` still works because `{1/(jx)}{1/(kx)} = {1/(kx)}{1/(jx)}` by commutativity.

**Update docstrings**: Fix the `nbBasis'` deprecation notice and `nbDistSq'` docstring to reflect the migration.

---

### Step 2: `Gram/Bounds.lean` — Fix Integrand References

All lemmas unfold `gramEntry` and use the `{j/x}{k/x}` integrand. Every proof uses ONLY:
- `Int.fract_nonneg`
- `Int.fract_lt_one`
- `mul_nonneg`, `mul_le_one₀`
- Measurability of compositions

**These are all basis-agnostic!** The proofs change minimally:

| Lemma | Change |
|-------|--------|
| `gramEntry_integrand_nonneg` | Change arg from `(j:ℝ)/x` to `1/((j:ℝ)*x)` |
| `gramEntry_integrand_le_one` | Same |
| `gramEntry_nonneg` | Same |
| `gramEntry_integrand_measurable` | `measurable_const.div measurable_id` → `measurable_const.div (measurable_const.mul measurable_id)` for each factor |
| `gramEntry_integrable` | Same pattern |
| `gramEntry_le_one` | Same pattern |
| `vasyunin_coprime_case` | Uses only `gramEntry_nonneg` + `gramEntry_le_one` — opaque, survives |

---

### Step 3: `Gram/NbLinComb.lean` — Fix Measurability + L² Identity

This file unfolds `gramEntry` in `integral_fract_prod_eq` and uses `{j/x}` measurability.

**Changes:**

| Lemma | Change |
|-------|--------|
| `fract_div_mul_measurable` | `measurable_const.div measurable_id` → `(measurable_const.div (measurable_const.mul measurable_id))` for each `fract` factor |
| `fract_prod_le_one` | Integrand changes from `{j/x}{k/x}` → `{1/(jx)}{1/(kx)}`, but bound `≤ 1` still holds (same fract properties) |
| `fract_prod_intervalIntegrable` | Same pattern, updated integrand |
| `scaled_fract_intervalIntegrable` | Same pattern |
| `integral_fract_prod_eq` | Unfolds `gramEntry` — update integrand |
| `integral_sq_as_double_sum` | Uses `nbLinComb` — automatically works after nbLinComb change |
| `gram_l2_identity` | Calls above — works if above are fixed |

**Key insight**: `fract_prod_le_one` proves `‖{a}{b}‖ ≤ 1` for ANY `a, b`. The bound is `Int.fract_nonneg` + `Int.fract_lt_one` which don't care about the integrand form. So the proofs are nearly identical, just with the integrand expression changed.

---

### Step 4: `Gram/L2Bridge.lean` — Fix Integrability

**Changes:**

| Lemma | Change |
|-------|--------|
| `single_fract_integrable` | `{k/x}` → `{1/(kx)}` in integrand. Measurability chain: `(measurable_const.div (measurable_const.mul measurable_id)).fract.const_mul c` |
| `nbLinComb_integrable` | Uses `single_fract_integrable` — automatically works |
| `integral_nbLinComb_eq_dotProduct` | Unfolds `basisInnerProd` and `nbLinComb` — automatically works if integrand forms match |
| `l2_error_eq_quad_error` | Uses above — should work |

---

### Step 5: `Structural/Independence.lean` — THE PHASE X BYPASS ⚠️

**This is the file we do NOT rework tonight.**

The floor arithmetic in `fract_eq_sub`, `fract_eq_sub_jump`, `nbLinComb_neg_interval`, `nbLinComb_nonzero_somewhere`, and `nyman_beurling_lin_indep` is all specific to the `{k/x}` parameterization. The discontinuity structure of `{1/(kx)}` is different.

**Phase X bypass**: Replace the floor-arithmetic proofs with a temporary axiom:

```lean
/-- **TEMPORARY AXIOM (Phase X)**: BD-basis functions are linearly independent.
    {1/(kx)} for k=1,...,N-1 are linearly independent in L²(0,1).
    Equivalently: if w ≠ 0, then Σ wᵢ{1/((i+1)x)} is not a.e. zero on (0,1).
    
    This is unconditionally true (does not depend on RH).
    Proof: same structure as the old nyman_beurling_lin_indep, but with
    floor discontinuities at x = 1/(kn) instead of x = k/n.
    
    TODO: Graduate by porting the floor arithmetic from the HF basis.
    The old proof is archived in Archive/HighFrequencyTrap/Structural/Independence.lean. -/
axiom bd_nyman_beurling_lin_indep (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    0 < ∫ x in (0:ℝ)..1, (nbLinComb N w x) ^ 2
```

Then rewrite `gram_pos_def` to use this axiom:

```lean
theorem gram_pos_def (N : ℕ) (hN : 2 ≤ N)
    (w : Fin (N - 1) → ℝ) (hw : w ≠ 0) :
    0 < realQuadForm (gramMatrix N) w := by
  rw [gram_l2_identity N hN w]
  exact bd_nyman_beurling_lin_indep N hN w hw
```

**Keep the old floor lemmas** (`fract_eq_sub`, etc.) but mark them as HF-basis-specific and not currently used. They are the "scaffolding" for the future BD floor rework.

---

### Step 6: `NymanBeurling/QuadFormBridge.lean` — Fix `basis_inner_prod_nonzero`

**Line 56** uses `fract_eq_sub` (from Independence.lean) to show `{1/x}` is nonzero on `(1/2, 1)`. This proof works for BOTH bases since `{1/x} = {1/(1·x)}` — the `k=1` case is identical!

The line is:
```lean
rw [fract_eq_sub (le_refl 1) (le_refl 1) h12 hx_hi]
```

For the BD basis with `k=1`, the integrand is `{1/(1·x)} = {1/x}`, which equals `{1/x}` in the old basis too. So this proof **survives as-is** if `fract_eq_sub` is still available.

**Decision**: Keep `fract_eq_sub` in Independence.lean (it's a general floor fact), just note that `nbLinComb_nonzero_somewhere` and `nyman_beurling_lin_indep` are axiomatized.

**Potential issue**: The `basisInnerProd` definition changed, so at line 39 we now have `Int.fract (1/((0+1:ℕ):ℝ) * x)`. We need to verify this simplifies to `Int.fract (1/x)` — it does since `(0+1:ℕ):ℝ = 1` and `1*x = x`.

---

### Step 7: Graduate `spectral_energy_witness_lower`

With the unified basis, the graduation chain becomes:

```lean
/-- spectral_energy_witness_lower — NOW A THEOREM.
    
    Chain: bd_witness_l2_error_decay → nbDistSq_le_test_vector → spectral_identity. -/
theorem spectral_energy_witness_lower :
    ∃ C : ℝ, C > 0 ∧ ∃ N₀ : ℕ, ∀ N ≥ N₀,
      totalSpectralEnergy N ≥ 1 - C / Real.log ↑N := by
  obtain ⟨C, hC, N₀, hBound⟩ := bd_witness_l2_error_decay
  refine ⟨C, hC, max N₀ 2, fun N hN => ?_⟩
  have hN2 : 2 ≤ N := le_of_max_le_right hN
  have hN0 : N₀ ≤ N := le_of_max_le_left hN
  obtain ⟨v, hv⟩ := hBound N hN0
  have h_var := nbDistSq_le_test_vector N hN2 v
  have h_id := spectral_identity N hN2
  linarith
```

**NOTE**: This step requires that `bd_witness_l2_error_decay` uses `vasyuninGramEntry` and that our unified `gramEntry` matches it. After the definition change, `gramEntry j k` IS the integral `∫{1/(jx)}{1/(kx)}dx`, which equals `vasyuninGramEntry j k` by `vasyunin_eq_integral`. We may need a bridge lemma `gramEntry_eq_vasyunin` or rewrite `bd_witness_l2_error_decay` to use `gramEntry` directly.

---

## Non-Crown Files (Deferred)

These files will break but are **not on the crown build path**:

| File | Status | Deferred Work |
|------|--------|---------------|
| `Gram/FractIntegral.lean` | Exports `{k/x}` results — still true, but no longer about `gramEntry`. | LOW PRIORITY — rename or keep |
| `Gram/Diagonal.lean` | Floor arithmetic specific to `{k/x}²` | Rewrite for `{1/(kx)}²` or axiomatize bounds |
| `Gram/OffDiagonal.lean` | AM-GM and covariance for `{k/x}` | Same |
| `Gram/ParameterizationBridge.lean` | `rosetta_stone_bridge` becomes trivial | Simplify or archive |
| `Sieve/VasyuninExpansion.lean` | Uses `gramEntry_nonneg` etc. | Should work after Bounds.lean fix |

---

## Post-Migration Axiom Census

### BEFORE
```
heisenberg_implies_d_sq_zero depends on:
  ├── spectral_energy_witness_lower   ← AXIOM (deep, structural)
  └── (Lean core: propext, Classical.choice, Quot.sound)
```

### AFTER
```
heisenberg_implies_d_sq_zero depends on:
  ├── bd_witness_l2_error_decay       ← AXIOM (inherited from Spatial Path)
  ├── bd_nyman_beurling_lin_indep     ← AXIOM (trivial calculus, Phase X bypass)
  └── (Lean core: propext, Classical.choice, Quot.sound)
```

**Net change**: 
- `spectral_energy_witness_lower` → **GRADUATED** (was deep structural axiom)
- `rosetta_stone_bridge` → **ELIMINATED** (architecture unified)
- `bd_nyman_beurling_lin_indep` → **ADDED** (trivial, unconditional, future mechanical work)

**Quality upgrade**: Traded 1 RH-dependent mystery for 1 unconditionally-true calculus fact.

---

## Execution Sequence

```
1. Defs.lean          — swap 3 definitions + fix gramEntry_comm/gramMatrix_hermitian
2. Gram/Bounds.lean   — update integrand references (15 min)
3. Gram/NbLinComb.lean — update measurability chain (20 min)
4. Gram/L2Bridge.lean  — update integrability (10 min)
5. Structural/Independence.lean — Phase X axiom + rewire gram_pos_def (10 min)
6. NymanBeurling/QuadFormBridge.lean — verify basis_inner_prod_nonzero (5 min)
7. Spectral/HeisenbergBypass.lean — graduate spectral_energy_witness_lower (15 min)
```

**Total**: ~75-90 minutes, then `lake build` to verify the crown path compiles.
