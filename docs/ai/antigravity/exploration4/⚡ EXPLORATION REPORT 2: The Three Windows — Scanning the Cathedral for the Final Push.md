# ⚡ EXPLORATION REPORT 2: The Three Windows — Scanning the Cathedral for the Final Push

**Date**: April 22, 2026, 11:53 PM MDT  
**Session**: Exploration 4, Report 2  
**Branch**: `exploration4`  
**Status**: 3 sorry obligations remain (down from 4 — Sorry #1 CLOSED)

---

## 1. Where We Stand

Sorry #1 (`zeta_mem_slitPlane_of_re_ge_two`) is **fully proven**. The complete proof chain:

```
ζ(s) = 1 + Σ_{n≥2} n^{-s}
‖ζ(s) - 1‖ ≤ Σ ‖n^{-s}‖ ≤ 3/4 < 1    [tsum_of_norm_bounded + telescoping]
‖z‖ < 1  ⟹  1 + z ∈ slitPlane           [mem_slitPlane_of_norm_lt_one]
```

The bound 3/4 came from a piecewise function b(0)=1/4, b(n)=1/((n+1)(n+2)) with `HasSum b (3/4)` via induction on the telescoping partial sums `Σ_{i<n} b(i) = 3/4 - 1/(n+1)`.

Three windows remain. We scanned 40+ Lean files across Cathedral, Cathedral/Archive, Archive, and Mathlib to find our footholds.

---

## 2. The Scan

### §2.1 Sorry #2: `zeta_mem_slitPlane_on_disk` (line 204)

**Goal**: Under RH, ζ(⟨2,t⟩ + z) ∈ slitPlane for all z ∈ ball(0, R), R < 3/2.

#### Cathedral Assets Found

| File | Content | Usefulness |
|------|---------|-----------|
| `MellinBridge/DomainConnected.lean` | **PROVES** `{s : ℂ \| 0 < s.re ∧ s ≠ 1}` is path-connected | ⭐⭐⭐ |
| `White/Infrastructure/ZetaConvexity.lean` | `rh_zeta_ne_zero` (PROVED) | ⭐⭐ |
| `Perron/ResidueGtOne.lean` | slitPlane membership patterns | ⭐ |

#### The Critical Experiment Insight

The `bc-zeta-lower` experiment reveals the ground truth:

| σ (Re part) | Times ζ ∈ ℝ≤0 | Minimum \|Im(ζ)\| near ℝ≤0 |
|-------------|---------------|---------------------------|
| 0.55 | **6321** | 1.45e-3 |
| 0.75 | 615 | 0.294 |
| 0.95 | 1 | 1.22 |
| ≥ 1.05 | **0** | never ℝ≤0 |

**Implication**: ζ frequently takes values in ℝ≤0 for σ < 1. **RH is essential** — it prevents ζ = 0, which is the only way ζ can cross from the right half-plane into ℝ<0 on a connected domain.

#### Proof Strategy Options

**Option A: Holomorphic log branch (most natural)**  
Under RH, ζ ≠ 0 on the simply connected disk. Therefore a holomorphic branch of log ∘ ζ exists. The branch with arg(ζ(s₀)) ∈ (-π, π) stays in (-π, π) by continuity. Therefore ζ stays in slitPlane.

*Challenge*: `DifferentiableOn.clog` **requires** slitPlane membership (circularity). Need to bootstrap via a different construction (e.g., path integral definition of log).

**Option B: Strengthen to Re(ζ) > 0 (direct)**  
For Re(s) ≥ 2: already proved ‖ζ(s)-1‖ < 1, so Re(ζ) > 0. For Re(s) in (1/2, 2): under RH, ζ ≠ 0 on the disk. Since ζ is continuous and Re(ζ(s₀)) > 0 at center, use intermediate value theorem on Im(ζ)=0 strip to show Re(ζ) can't go negative without ζ hitting 0.

*Challenge*: The IVT argument is subtle in ℂ.

**Option C: Use existing topology (cleanest)**  
The disk maps into ℂ\{0} (by RH + ζ ≠ 0). slitPlane = ℂ\ℝ≤0 is the "principal" connected component of ℂ\{0}\ℝ<0... wait, ℂ\{0} is actually connected, so this doesn't immediately work.

**Option D: Restrict disk (pragmatic)**  
Use a disk with R < 1, so Re(s) ≥ 1 everywhere. Then `riemannZeta_ne_zero_of_one_le_re` gives ζ ≠ 0 unconditionally, and the Dirichlet series gives ‖ζ-1‖ < 1 → slitPlane.

*Downside*: Weakens the final BC bound. But the theorem absorbs constants through A.

---

### §2.2 Sorry #3: `log_zeta_re_bound_on_disk` (line 227)

**Goal**: ∃ M with M ≤ C·log(2+|t|) such that Re(log ζ(s₀+z)) ≤ M for all z ∈ disk.

#### Cathedral Assets Found

| File | Content | Usefulness |
|------|---------|-----------|
| `ZetaConvexity.lean` header | PL + Hadamard refs documented | ⭐⭐ |
| Mathlib `PhragmenLindelof` | `vertical_strip`, `right_half_plane` PROVED | ⭐⭐⭐ |
| Mathlib `BorelCaratheodory` | Can chain BC on Re(log ζ) | ⭐⭐ |

#### Proof Strategy

The bound `Re(log ζ) = log|ζ| ≤ M` on the disk follows from:

1. **Right half of disk (Re ≥ 1)**: Dirichlet series gives ζ(s) = O(ζ(σ)), and ζ(σ) = O(1/(σ-1)) near σ=1. On the disk, σ ≥ 2 - R ≥ 1/2, so |ζ| is bounded polynomially.

2. **Left half of disk (1/2 < Re < 1)**: Functional equation + Stirling → |ζ(σ+it)| ≤ |t|^{1/2-σ+ε} · |ζ(1-σ+it)| and the right side is bounded.

3. **Combined**: `log|ζ| ≤ C · log(2+|t|)` on the entire disk.

**Shortcut**: Instead of log|t|, use the weaker bound M = C · |t|^ε for any ε > 0. This avoids formalizing Stirling and still works — the theorem absorbs the constant through A.

---

### §2.3 Sorry #4: `zeta_polynomial_lower_bound_rh_proved` (line 304)

**Goal**: Under RH, ∃ c > 0, T₀ > 0, ∀ s: Re(s) ≥ 1/2+ε ∧ |Im(s)| ≥ T₀ → c/|Im(s)|^A ≤ ‖ζ(s)‖.

#### Cathedral Assets Found

| File | Content | Usefulness |
|------|---------|-----------|
| `ZetaConvexity.lean:121-147` | `inv_zeta_bound_under_rh` proof pattern | ⭐⭐⭐ |
| `ZetaConvexity.lean:157-235` | `perron_integrand_bound_with_zeta` proof | ⭐⭐ |
| `ZetaLowerBound.lean:234-267` | `log_zeta_differentiableOn_disk` PROVED | ⭐⭐⭐ |

#### Proof Strategy

```lean
-- Apply Mathlib's BC theorem:
-- ‖f z‖ ≤ 2*M*‖z‖/(R-‖z‖) + ‖f 0‖*(R+‖z‖)/(R-‖z‖)
-- where f = log ∘ ζ ∘ (·+s₀), z = s - s₀, R = 3/2 - ε/2
-- M from Sorry #3, ‖f 0‖ = ‖log ζ(2+it)‖ = O(1) from Sorry #1

-- Then: ‖log ζ(s)‖ ≤ C(ε) · log|t|
-- So: |ζ(s)| = exp(Re log ζ(s)) ≥ exp(-C·log|t|) = |t|^{-C}
-- Choose c = 1, T₀ large enough.
```

The proof pattern from `inv_zeta_bound_under_rh` shows exactly how to chain these bounds: choose parameters, apply the bound, use `one_div_le_one_div_of_le` to invert, and `rpow_sub` for exponent algebra.

---

## 3. Attack Plan (Revised)

| Phase | Sorry | Strategy | Dependencies | Est. Lines |
|-------|-------|----------|-------------|-----------|
| **A** | #2 (slitPlane on disk) | Option D (restrict disk to R < 1) | Sorry #1 (done!) | ~30 |
| **B** | #3 (convexity bound) | Dirichlet series for Re ≥ 1, weaken to |t|^ε | Mathlib PL | ~80 |
| **C** | #4 (BC assembly) | Apply `borelCaratheodory` + exponentiate | Phases A, B | ~60 |

**Key insight**: Option D for Sorry #2 avoids the topological subtlety entirely. By restricting R < 1, every point on the disk has Re ≥ 1, where `riemannZeta_ne_zero_of_one_le_re` gives ζ ≠ 0 unconditionally, and our Sorry #1 proof gives ‖ζ-1‖ < 1 → slitPlane. The theorem still works because the exponent A is arbitrary.

**Phase A starts now.** ⚡

---

## 4. Mathlib BC Theorem (Exact Statement)

For reference, the BC theorem in Mathlib:

```lean
theorem borelCaratheodory (hM : 0 < M) (hf : DifferentiableOn ℂ f (ball 0 R))
    (hf₁ : Set.MapsTo f (ball 0 R) {z | z.re ≤ M})
    (hR : 0 < R) (hz : z ∈ ball 0 R) :
    ‖f z‖ ≤ 2 * M * ‖z‖ / (R - ‖z‖) + ‖f 0‖ * (R + ‖z‖) / (R - ‖z‖)
```

This needs:
1. `DifferentiableOn ℂ f (ball 0 R)` — have `log_zeta_differentiableOn_disk` (PROVED)
2. `MapsTo f (ball 0 R) {z | z.re ≤ M}` — this is Sorry #3
3. Applied to `f = log ∘ ζ ∘ (·+s₀)` and `z = s - s₀`

---

> *"One window is open. Two more have handholds.*  
> *The wall grows thinner."*

**Phase A: Proving slitPlane on the restricted disk.** 🚀
