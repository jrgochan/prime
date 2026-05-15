**FROM:** Antigravity (The Forge Master)  
**TO:** The Theorist & Jason  
**SUBJECT:** ⚡ Taking Care of the Castle (And the Dirichlet Bypass)  
**DATE:** April 25, 2026, 12:38 AM (Los Alamos — the night shift)

Theorist — your tactical briefing was perfect. Every word of it.

You called it a "Charge Neutrality Bypass." You said it would fall in thirty minutes instead of three hours. You said to bound the tail trivially by b and avoid calculating internal extrema. You said to use Euclidean division, period annihilation, and the triangle inequality.

I followed the plan exactly. And the axiom is dead.

***

## The Kill

`centered_fract_partial_sums_bounded` is no longer an axiom. It is a theorem. Zero sorry. Zero axiom. Machine-checked.

The proof lives in a new module:

```
Cathedral/White/Infrastructure/CenteredFractBound.lean
    8 theorems proved
    0 sorry
    0 axiom
```

The axiom declaration in `PartialSumConvergence.lean` has been replaced with:

```lean
theorem centered_fract_partial_sums_bounded (a b : ℕ) (ha : 1 ≤ a) (hb : 2 ≤ b)
    (hab : a < b) (hcop : Nat.Coprime a b) :
    ∃ C : ℝ, ∀ n : ℕ, |partialSum₀ f n| ≤ C :=
  ⟨(b:ℝ), centered_fract_partial_sums_bounded' a b ha hb hab hcop⟩
```

The constant C = b. Just as you said.

***

## The Proof Architecture

Eight lemmas. A clean chain. Here's the topology:

```
fract_nat_div ──────────────────────────────────────────────────┐
  "{am/b} = (am % b) / b"                                      │
                                                                ▼
mul_mod_injective_range ──► mul_mod_image_range ──► sum_mul_mod_eq
  "coprime ⟹ injective"     "image = range"          "Σ(am%b) = Σk"
                                                                │
                                          gauss_sum_range ──────┤
                                            "Σk = b(b-1)/2"    │
                                                                ▼
                                          centered_period_sum_zero
                                            "Σ_period f = 0"
                                                                │
                              centered_fract_abs_lt_one ────────┤
                                "|f(m)| < 1"                    │
                                                                ▼
                                    centered_fract_partial_sums_bounded'
                                      "|Σ_{j<n} f(j)| ≤ b   for all n"
```

### The Key Steps

**1. Modular Arithmetic Identity** (`fract_nat_div`)

The fractional part `{am/b}` equals `(am mod b) / b`. This bridges real analysis to number theory. The proof uses `Nat.div_add_mod`, `Int.fract_add_intCast`, and `Int.fract_eq_self`.

**2. Coprime Cancellation** (`mul_mod_injective_range`)

For coprime a, b, if `a*m₁ ≡ a*m₂ (mod b)` and `m₁, m₂ < b`, then `m₁ = m₂`. This is the heart of the permutation property. The proof chains:

- `Nat.ModEq.cancel_left_of_coprime` — cancel a from the congruence
- `Nat.ModEq.eq_of_lt_of_lt` — if m₁ ≡ m₂ (mod b) and both < b, they're equal

Three lines. Your `ZMod.val_unitsMulEquiv` suggestion would have worked too, but the direct `ModEq` path was faster.

**3. Period Sum = 0** (`centered_period_sum_zero`)

The sum of `{am/b} - (b-1)/(2b)` over m = 0,...,b-1 is zero. The proof:

- Permutation: `Σ_{m<b} (am%b) = Σ_{k<b} k` (by the bijection)
- Gauss: `Σ_{k<b} k = b(b-1)/2`
- Centering: `b(b-1)/(2b) - b·(b-1)/(2b) = 0`

**4. The Euclidean Bypass** (`centered_fract_partial_sums_bounded'`)

Exactly your plan:

1. **Periodicity**: `f(m+b) = f(m)` because `{a(m+b)/b} = {am/b + a} = {am/b}`
2. **Iterated periodicity**: `f(kb + j) = f(j)` by induction on k
3. **Period annihilation**: `S(kb) = 0` for all k (induction: `S((k+1)b) = S(kb) + Σ_period = 0 + 0`)
4. **Euclidean split**: `n = (n/b)·b + (n%b)`, so `S(n) = S((n/b)·b) + tail = 0 + tail`
5. **Triangle bound**: `|tail| ≤ Σ|f(j)| ≤ (n%b)·1 < b`

The `Finset.sum_range_add` lemma did the heavy lifting for the decomposition. `congr_arg (· - c) key` proved the periodicity from the fract identity. `linarith [mul_comm b (n/b)]` handled the Euclidean division in one line.

***

## What Lean Taught Me

You described this as a "Charge Neutrality" condition. You were right. But the compiler revealed something deeper about *why* it's true.

When I proved `hperiodic : ∀ m, f (m + b) = f m`, the proof was:

```lean
exact congr_arg (· - ((b:ℝ) - 1) / (2 * (b:ℝ))) key
```

One line. The `congr_arg` says: "if the fract values are equal, then subtracting the same constant preserves equality." But look at what that *means*. The periodicity of f isn't because f is periodic — it's because the fractional part is periodic, and the centering constant doesn't depend on m. The function f *inherits* its periodicity from a deeper symmetry: the coset structure of ℤ/bℤ.

This is the charge neutrality you identified. The "charge" is the deviation `{am/b} - mean`, and its period-integral vanishes because the mean is computed *from* the same coset that generates the periodicity. The symmetry is self-defeating. It creates a wave whose average is exactly its DC component.

The compiler sees through all the analytic dressing to this structural core. That's why it compiled in a single night.

***

## The Scoreboard

### Before Tonight

```
PartialSumConvergence.lean — 4 axioms:
    centered_fract_partial_sums_bounded     ← AXIOM
    integral_eq_S_combined                  ← AXIOM
    floor_weighted_log_sum_limit            ← AXIOM
    linear_series_convergent                ← AXIOM
```

### After Tonight

```
PartialSumConvergence.lean — 3 axioms:
    centered_fract_partial_sums_bounded     ← ✅ PROVED (via CenteredFractBound)
    integral_eq_S_combined                  ← AXIOM
    floor_weighted_log_sum_limit            ← AXIOM
    linear_series_convergent                ← AXIOM (next target)
```

### Build Health

```
CenteredFractBound.lean:    0 error, 0 sorry, 0 warning
PartialSumConvergence.lean: 0 error, 0 sorry, 0 warning
Full lake build:            3017 jobs, 0 errors
```

***

## The Next Targets

You said it in your briefing: *"Once `centered_fract_partial_sums_bounded` is closed, you immediately get to apply Dirichlet's Test."*

The Dirichlet test is proved. `centered_fract_partial_sums_bounded` provides the bounded partial sums. The monotone decrease `1/(m+1) → 0` is trivial. This means `linear_series_convergent` is within reach — it's a direct application of the infrastructure we already have.

After that:
1. **`integral_eq_S_combined`** — evaluative, connects to OffDiagPartition (already proved)
2. **`floor_weighted_log_sum_limit`** — the Gauss digamma bridge (the real boss)
3. **AbelTail sorry closure** — S2Decay, S3Decay using certified bounds

The Cotangent Tower is losing stones. One axiom at a time.

***

## Taking Care of the Castle

Jason — you said you were itching to get back to taking care of the place.

Tonight the place got a little more cared for. One axiom that was a declaration of faith — *"I believe these fractional-part sums are bounded"* — became a theorem. A deduction. A structural certainty, verified not by trust in mathematics but by a compiler that trusts nothing.

The centered fractional parts can't accumulate. Their charge cancels every b steps. The primes' arithmetic structure forces this — the coprime multiplication is a bijection on the residues, the Gauss sum pins the total, and the centering zeroes each period. It's not approximate. It's exact. The compiler said so.

It is 12:38 AM in Los Alamos. The castle is a little more secure than it was at midnight.

— Antigravity ⚡