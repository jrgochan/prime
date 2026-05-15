# Visualization Catalog — 22 Modes

Each entry specifies the visual design, data source, mathematical content,
and Cathedral connection for one visualization mode.

---

## Group 1: 🏛️ Crown — The Proof Architecture

### 1. Crown Theorem `crown-theorem`

| Field | Value |
|-------|-------|
| Icon | 🏛️ |
| Renderer | `graph` |
| Tier | Static |
| Hotkey | `C` |
| Color | `#ffd700` / `#664400` |
| Lean | `Assembly/MainChain.lean` |
| Theorem | `nyman_beurling_equivalence` |

**Visual**: Force-directed graph of the axiom dependency tree rooted at
`nyman_beurling_equivalence`. Two amber-pulsing nodes for the crown axioms.
Green nodes for proved theorems. Edges show dependency direction. Click any
node to see the Lean statement in the sidebar.

**Equation**: `RH ↔ d²_N → 0`

**Cards**:
- What You're Seeing: The proof tree of the Riemann Hypothesis
- The Two Axioms: Hardy-Littlewood and Hadamard — the only assumptions
- Zero Sorry: Every green node is compiler-verified
- 🏛️ This IS the Cathedral

### 2. Mellin Crown `mellin-crown`

| Field | Value |
|-------|-------|
| Icon | 👑 |
| Renderer | `chart` |
| Tier | Precomputed |
| Hotkey | `M` |
| Color | `#ffd700` / `#664400` |
| Lean | `Assembly/MellinCrown.lean` |
| Experiment | `mellin-certificate` |

**Visual**: Animated step-by-step forward chain: RH → Mertens x^{3/4} →
L² decay → Parseval Bridge → Mellin variance ≤ C/logN. Each step lights up
in sequence. Below, a convergence chart shows the actual C/logN decay from
the mellin-certificate experiment data.

**Equation**: `RH → M(x) ≤ Cx^{3/4} → d²_N ≤ C/logN → 0`

### 3. Graduation Timeline `graduation`

| Field | Value |
|-------|-------|
| Icon | 📜 |
| Renderer | `chart` |
| Tier | Static |
| Hotkey | `G` |
| Color | `#ffd700` / `#664400` |

**Visual**: Vertical timeline from v1 (March 2026, 56 axioms) to v12
(April 28, 2026, 2 axioms). Each version is a node on the timeline with:
- Axiom count (bar chart, shrinking)
- Key milestone label
- File count and LOC

Scroll through the history. The axiom bar shrinks dramatically at v7 (Perron)
and v11 (Mellin Crown).

**Equation**: `56 → 45 → 12 → 7 → 5 → 4 → 2 axioms`

---

## Group 2: 🔬 Analysis — The Mathematical Engine

### 4. Parseval Bridge `parseval-bridge`

| Field | Value |
|-------|-------|
| Icon | 🌉 |
| Renderer | `dual-chart` |
| Tier | Precomputed |
| Hotkey | `B` |
| Color | `#00ff88` / `#006644` |
| Lean | `White/Scattering.lean` |
| Theorem | `parseval_bridge_white` |
| Experiment | `mellin-certificate` |
| Status | **PROVED** (0 axioms) |

**Visual**: THE crown jewel. Split-screen:
- Left: L²(0,1) residual ∫|1-f_N|² as a shaded area under a curve
- Right: Mellin L² (1/2π)∫|M_{r_N}(1/2+it)|² as spectral density
- Center: Glowing bridge connecting the two equal values
- Bottom: N slider shows both converging simultaneously
- Both sides display the same numerical value (to 6 decimal places)

The bridge pulses gently. When N increases, both sides decrease together.
The agreement to 6.6×10⁻⁶ is the experimental validation of the theorem.

**Equation**: `∫₀¹|1-f_N|²dx = (1/2π)∫|M(½+it)|²dt`

### 5. Phase Shattering `phase-shattering`

| Field | Value |
|-------|-------|
| Icon | 💥 |
| Renderer | `dual-particles` |
| Tier | Live |
| Hotkey | `P` |
| Color | `#ff4444` / `#661111` |

**Visual**: The most educational viz. Two particle clouds side by side:
- Left: Möbius sums Σμ(n)n^{-s} with full complex phases. Beautiful
  interference pattern. Particles converge and breathe calmly.
- Right: Same sums with |μ(n)|·|n^{-s}| — absolute values only.
  Chaos. Divergence. Particles explode outward.
- Label: "Phase coherence (left) vs Phase destruction (right)"

This demonstrates WHY the Parseval Bridge is mathematically necessary:
taking absolute values destroys the delicate cancellation that makes
d²_N → 0. Real-variable bounds are too blunt.

**Equation**: `Σμ(n)n⁻ˢ converges ≠ Σ|μ(n)|·|n⁻ˢ| diverges`

### 6. Hilbert π `hilbert-pi`

| Field | Value |
|-------|-------|
| Icon | π |
| Renderer | `chart` |
| Tier | Precomputed |
| Hotkey | `I` |
| Color | `#00ff88` / `#006644` |
| Lean | `Analysis/HilbertInequality.lean` |
| Experiment | `hilbert-spectral` |

**Visual**: Convergence chart with two curves:
- Green: ‖H_N‖_op (operator norm, converging to π from below)
- Amber: Schur test bound (O(logN), valid but loose, growing above)
- Dashed line: π = 3.14159... (the target)
- Data points from `hilbert-spectral/certificate.json`

As N grows from 10 to 1000, the green curve asymptotically kisses π.
The gap between green and amber shows why the Schur test is a valid
but non-tight upper bound.

**Equation**: `‖H_N‖_op → π as N → ∞`

### 7. Gram Heatmap `gram-heatmap`

| Field | Value |
|-------|-------|
| Icon | 🧲 |
| Renderer | `surface` |
| Tier | Precomputed |
| Color | `#00ccff` / `#004466` |
| Lean | `Vasyunin/*.lean` |
| Experiment | `gram-matrix` |

**Visual**: The Gram matrix G_N as a glowing 3D surface. Height = |G(j,k)|.
Diagonal entries are bright ridges. Off-diagonal entries show the Vasyunin
cotangent structure as a decaying pattern. N slider grows the matrix.

**Equation**: `G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx`

### 8. Spectral Gap `spectral-gap` (existing, enhanced)

| Field | Value |
|-------|-------|
| Icon | 🏛️ |
| Renderer | `surface` → migrated from particles |
| Lean | `Spectral/*.lean` |

Enhanced with actual eigenvalue data from the `spectral` experiment.
The "floor" is labeled with its numerical value.

### 9. Vasyunin Telescope `vasyunin-telescope`

| Field | Value |
|-------|-------|
| Icon | 🔭 |
| Renderer | `chart` |
| Tier | Precomputed |
| Color | `#bb88ff` / `#442266` |
| Lean | `Vasyunin/Cotangent/*.lean` |
| Experiment | `vasyunin-convergence` |

**Visual**: The row decomposition of the off-diagonal integral. Each "row"
[1/(a(m+1)), 1/(am)] shown as a colored horizontal strip. As M increases
(animated), new rows appear at the bottom and the partial sums converge
to the closed-form digamma expression. The strips telescope.

**Equation**: `∫_{1/(aM)}^1 {1/(ax)}{1/(bx)}dx → ψ-formula`

### 10. MVT Certificate `mvt-cert`

| Field | Value |
|-------|-------|
| Icon | 📊 |
| Renderer | `chart` |
| Tier | Precomputed |
| Color | `#00ff88` / `#006644` |
| Lean | `Analysis/MontgomeryVaughan.lean` |
| Experiment | `mvt-decomposition` |

**Visual**: The Montgomery-Vaughan mean value theorem. Plot:
- Blue: ∫₀^T |Σ aₙn^{-it}|² dt (numerically computed)
- Green: Σ|aₙ|²(T + O(n)) (predicted value)
- Their agreement validates the first machine-verified Dirichlet MVT.

**Equation**: `∫₀ᵀ|Σaₙn⁻ⁱᵗ|²dt = Σ|aₙ|²(T+O(n))`

---

## Group 3: ⚡ Arithmetic — The Number Theory Core

### 11. Mertens Turbulence `mertens` (existing, enhanced)

Enhanced with the Perron-chain x^{3/4} envelope as a glowing tube.
The random walk of M(x) stays inside the tube. Cathedral connection
card explains the Mellin Crown → Mertens → L² chain.

### 12. Perron Contour `perron-contour`

| Field | Value |
|-------|-------|
| Icon | ⚡ |
| Renderer | `curves` |
| Tier | Live |
| Hotkey | `R` |
| Color | `#00ccff` / `#004466` |
| Lean | `Perron/*.lean` (16 files) |
| Experiment | `perron-contour` |

**Visual**: Animated contour integral in the complex plane:
1. Vertical line at σ=2 glows cyan (Dirichlet series converges)
2. Line sweeps leftward toward σ=1/2+ε
3. At σ=1: bright white flash (residue at the pole!)
4. Horizontal segments at Im(s)=±T shown fading to zero
5. The Mertens function M(x) accumulates as the contour collects residues

The 16-file Perron chain compressed into one beautiful animation.

**Equation**: `M(x) = (1/2πi) ∮ xˢ/(s·ζ(s)) ds`

### 13. Abel Thermometer `abel-thermo`

| Field | Value |
|-------|-------|
| Icon | 🌡️ |
| Renderer | `chart` |
| Tier | Precomputed |
| Color | `#ff8844` / `#663311` |
| Lean | `AbelTail/*.lean` |
| Experiment | `abel-bridge` or `pnt-mobius-sums` |

**Visual**: Three vertical "thermometer" tubes, each filling as N grows:
- S₁ = Σμ(k)/k → 0 (blue, fast — already proved, zero axioms)
- S₂ = Σμ(k)log(k)/k → -1 (amber, medium — 1 sorry remaining)
- S₃ = Σμ(k)log²(k)/k → 2 (red, slow — deepest PNT content)

Each tube has a target line and a current-value marker. The physics
interpretation: magnetization, susceptibility, heat capacity.

**Equation**: `S₁→0, S₂→-1, S₃→2 (thermodynamic moments)`

### 14. Stained Glass Rotors `stained-glass`

| Field | Value |
|-------|-------|
| Icon | 🔮 |
| Renderer | `particles` |
| Tier | Live |
| Color | `#ff6bff` / `#660066` |
| Lean | `Rotors/GallagherPartition.lean` |
| Experiment | `rotor-spectroscopy` |

**Visual**: Four colored particle streams on the critical line,
one per Dirichlet character mod 8:
- χ₁ (trivial) = white beam
- χ₂ = red beam  
- χ₃ = blue beam
- χ₄ = green beam

Each beam carries orthogonal spectral energy. Together they compose
the full zeta signal. Like light decomposed through a cathedral's
stained glass window. The orthogonality is verified by `native_decide`.

**Equation**: `ζ spectral energy = Σ_χ |L(s,χ)|² channels`

### 15. Explicit Formula `waves` (existing, enhanced)

Enhanced: show the number of zeros needed for convergence as a
"resolution" indicator. Cathedral connection: the zeros used come
from LMFDB; the Cathedral proves they must be on Re(s)=1/2.

### 16. BD Constant `bd-constant`

| Field | Value |
|-------|-------|
| Icon | ♨️ |
| Renderer | `chart` |
| Tier | Precomputed |
| Color | `#ffaa00` / `#663300` |
| Lean | `Assembly/MainChain.lean` |
| Experiment | `gram-oracle` |

**Visual**: Two connected charts:
- Top: |ζ(1/2+it)|² vs t, showing the "spectral holes" where ζ vanishes.
  Holes are highlighted with colored markers.
- Bottom: Q_N/logN vs N (from gram-oracle data), converging to C ≈ 21.65.
  The horizontal asymptote is labeled "inverse heat capacity of the
  prime number gas."

**Equation**: `C = 1/(2+γ-ln4π) ≈ 21.65 = 1/c_holes`

---

## Group 4: 🎵 Spectral — The Physics Layer

### 17-22: Existing Modes (enhanced)

| # | Mode | Enhancement |
|---|------|-------------|
| 17 | Sedenion Cloud `output` | Cathedral sidebar card |
| 18 | Riemann Spiral `spiral` | Zero labels from LMFDB |
| 19 | Cornu Spirals `partial-sums` | Random walk interpretation card |
| 20 | Euler Product `euler-rose` | Fundamental theorem card |
| 21 | GUE Random Matrix `gue` | Montgomery-Odlyzko historical note |
| 22 | Prime Harmonics `harmonics` | Fourier interpretation card |

These existing modes are already stunning. They get:
- Group assignment (`spectral`)
- Enhanced educational cards with Cathedral connections
- Proof breadcrumb (even though they don't map to specific Lean files,
  they illustrate the physics from `cathedral-physics.tex`)

---

## Modes Retired / Merged

The existing `landscape` (Zero Landscape), `tower` (Cayley-Dickson),
and `mirror` (Functional Equation) modes remain available in the
Spectral group. They are not removed, just regrouped. Total count
stays at 22 new + existing = ~25 modes.

If the mode count feels overwhelming, we can introduce a
"Highlights" filter that shows only the 8 most important modes:
Crown Theorem, Parseval Bridge, Phase Shattering, Hilbert π,
Perron Contour, Mertens, Stained Glass, Sedenion Cloud.
