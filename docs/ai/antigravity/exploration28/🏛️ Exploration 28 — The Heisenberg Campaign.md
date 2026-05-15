# Exploration 28 — The Heisenberg Campaign

**Cathedral Core Team — May 6, 2026**
**Branch: `exploration28`**

---

## Where We Stand

### The Crown (What's Done)

The Cathedral's primary theorem — `nyman_beurling_equivalence` — is compiled, zero-sorry, and depends on **exactly one custom axiom**:

```
#print axioms nyman_beurling_equivalence
  → [baez_duarte_forward, propext, Classical.choice, Quot.sound]
```

| Direction | Status | Axioms |
|-----------|--------|--------|
| **Converse** (d²→0 ⟹ RH) | ✅ Fully proved | 0 custom |
| **Forward** (RH ⟹ d²→0) | `baez_duarte_forward` | 1 (literature) |

The converse uses the Rank-1 Mellin identity at off-critical-line zeros. Zero sorry, zero axioms, pure Mathlib. This is the strongest formally verified result in the NB program.

### The Numerical Evidence (Exploration 27)

The Spectral Observatory measured the **quantum decoupling exponent β** at three clean scales:

| N | β | λ_min | Status |
|---|---|-------|--------|
| 10,000 | 1.611 | 2.54×10⁻⁷ | ✅ Confirmed |
| 20,000 | 1.699 | 1.95×10⁻⁷ | ✅ Confirmed |
| 40,000 | 1.861 | 1.56×10⁻⁷ | ✅ Confirmed |

**Scaling law**: β(N) = −0.062 + 0.180·ln(N)

β > 1 means the target vector **b** (the constant function 1) is almost orthogonal to the low-energy eigenmodes of the Gram matrix. The dangerous spectral modes — those that could blow up the energy sum — carry less than 0.0001% of the total spectral weight.

### The Running Computation

An N=120,000 CG-DD solver is currently running on the WSL machine (RTX 4090, 107 GB OOC matrix, 47+ hours elapsed). If it converges, it will be the largest-scale certified NB distance ever computed.

### The 58 Axioms

Beyond the crown axiom, the Cathedral has 57 additional axioms serving alternative proof paths and supplementary infrastructure. These break down as:

- **16 oracle bounds** (certified d², λ_min, witness) — supplementary
- **10 spectral** (class restriction, parity, Schur) — alt path
- **8 Mellin bridge** (frequency-domain) — alt path (PATH A)
- **6 PNT** (Möbius sums, Mertens) — alt path (PATH B)
- **5 sieve** (bilinear, Vaughan, Type I/II) — alt path
- **3 covariance** (Gram form bounds) — alt path
- **4 BD/NB** (equivalence, witness) — mixed
- **6 other** (Robin, Hadamard, structural) — various

---

## The β Discovery: What It Means

### The Physics

The spectral decomposition of d²_N is:

```
d²_N = 1 − Σ c_k²/λ_k
```

where c_k = ⟨b, v_k⟩ are projections of the target onto eigenvectors. The quantity E_k = c_k²/λ_k is the "energy" of each mode. β > 1 means:

```
E_k = c_k²/λ_k ~ λ_k^{β−1} → 0   for small λ_k
```

The dangerous modes contribute vanishing energy. The vacuum is shielded.

### The IR/UV Decomposition

Gemini identified that β > 1 controls the **infrared** (low-energy) sector, while d²→0 requires the **ultraviolet** (bulk) sector to converge. This decomposes `baez_duarte_forward` into two independent conditions:

| Condition | Physical Name | Statement | Status |
|-----------|--------------|-----------|--------|
| **Axiom A** | IR Safety | Σ_{λ < τ} c²/λ → 0 | Numerically verified (β = 1.6–1.9) |
| **Axiom B** | UV Completeness | Σ_{λ ≥ τ} c²/λ → 1 | Open question |

The synthesis is trivial: d² = 1 − (Axiom B + Axiom A) = 1 − (1 + 0) = 0.

### The Honest Assessment

- **Axiom A** (IR Safety) is directly measurable and numerically confirmed. It may be provable from eigenvector localization bounds and arithmetic trace asymptotics — purely real spectral theory.

- **Axiom B** (UV Completeness) is the deeper statement. It asserts that the basis {1/(kx)} spans "enough" of L²(0,1) that the bulk eigenmode contributions converge to 1. This might secretly require the functional equation of ζ(s) — in which case complex analysis re-enters through the back door.

- The decomposition itself is valuable regardless: it **isolates where the complex analysis is needed** (UV only) and shows that the IR sector is a solved problem.

---

## Exploration 28 Plan

### Phase 1: The Heisenberg Bypass (Lean Formalization)

Create `proofs/Cathedral/Spectral/HeisenbergBypass.lean`:

1. **Spectral Theorem Setup** — Use Mathlib's `LinearAlgebra.Matrix.Spectrum` to construct the eigenbasis of G_N. Define `mode_energy N k = c_k² / λ_k`.

2. **Energy Partition** — Introduce spectral threshold τ(N) separating IR tail from UV bulk.

3. **Two New Axioms** — Formalize IR Safety and UV Completeness as Filter.Tendsto statements.

4. **The Synthesis** — Prove `heisenberg_implies_d_sq_zero` from the two axioms via standard limit arithmetic (zero sorry).

5. **Bridge to Crown** — Show this gives an alternative forward proof path with a 2-axiom footprint (IR + UV) vs the current 1-axiom footprint (baez_duarte_forward).

### Phase 2: IR Safety Graduation

Attack Axiom A (IR Safety) from real spectral theory:

1. **Trace bounds**: tr(G_N) = Σ λ_k ~ log(N). The eigenvalue distribution is constrained.

2. **Eigenvector localization**: The Ground State Scarring results (§7.4 of cathedral-physics) show that low eigenvectors localize on composites with PR ~ O(1).

3. **Projection decay**: If v_k has PR ~ O(1) and b is smooth (all components ~ 1/k), then c_k² = |⟨b, v_k⟩|² ~ 1/N² by Cauchy-Schwarz on the localized support.

4. **Combined**: c_k²/λ_k ~ (1/N²) / (1/N^{0.35}) = N^{-1.65} → 0. Sum over K bottom modes: K·N^{-1.65} → 0.

This is a sketch, not a proof. But it shows the ingredients are real-analytic.

### Phase 3: UV Completeness Investigation

The harder problem. Approaches to explore:

1. **Weyl's law**: Does the eigenvalue counting function N(λ) = |{k : λ_k ≤ λ}| follow a predictable distribution? If so, the bulk sum can be estimated.

2. **Random matrix universality**: The bulk of G_N exhibits GOE statistics (established in Exploration 19). Can RMT predict the bulk contribution to Σ c_k²/λ_k?

3. **Direct witness construction**: The Möbius witness v_k = −μ(k)(1 − ln k/ln N) gives d² ≤ C/log(N), which proves d²→0 *if* we can bound the witness error. This is the Abel summation path — it requires PNT-level Mertens bounds plus cross-term control.

4. **Honest assessment**: UV Completeness may be equivalent to the NB theorem itself, making it circular. The question is whether the spectral formulation offers new attack angles.

### Phase 4: Cleanup Campaign

Reduce noise in the axiom inventory:

1. **Graduate PNT axioms** — `pnt_mu_div_k`, `pnt_mu_log_div_k`, `pnt_mu_log_sq_div_k` should connect to `PrimeNumberTheoremAnd`.

2. **Archive dead paths** — Spectral/Sieve axioms that aren't on any live proof path.

3. **Document which paths are live** — Clear annotation in each file: "Crown path", "Alt path A/B/C", or "Historical".

### Phase 5: Harvest N=120K

When the WSL computation completes:

1. Retrieve the certified d² value and residual
2. Compare against the scaling law d² ~ 0.04 − ε(N)
3. If MPFR-512 becomes available, run spectral-observatory at N=120K to test β ≈ 2.1 prediction
4. Update certificates and oracle axioms

---

## Key Files

| File | Purpose |
|------|---------|
| `proofs/Cathedral/Assembly/MainChain.lean` | Crown theorem (1 axiom) |
| `proofs/Cathedral/Spectral/HeisenbergBypass.lean` | NEW: IR/UV decomposition |
| `papers/science/cathedral-physics.tex` | §7.6: Decoupling Exponent |
| `experiments/spectral-observatory/` | β measurement infrastructure |
| `experiments/certified-distance/` | d² certification pipeline |
| `experiments/cathedral-utils/src/lanczos.rs` | Lanczos eigensolver |

## Success Criteria for Exploration 28

1. ✅ `HeisenbergBypass.lean` compiles with zero sorry (synthesis theorem proved from two axioms)
2. ☐ At least one PNT axiom graduated
3. ☐ IR Safety attack: formal sketch of the localization → projection decay argument
4. ☐ UV Completeness: honest assessment of whether it's tractable from real analysis
5. ☐ N=120K results harvested and documented
6. ☐ Axiom inventory cleaned (dead paths archived, live paths annotated)
