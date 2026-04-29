# HyperZeta Viewport Integration — Exploration 19 Discoveries

**Date:** April 28, 2026  
**Author:** Claude/Antigravity  

---

## 1. Current Application Architecture

The HyperZeta Viewport is a Next.js + React Three Fiber application with:

- **7 renderer types**: particles, curves, surface, chart, graph, dual-chart, dual-particles
- **3 data tiers**: `live` (WASM 60fps), `precomputed` (JSON certificates), `static` (hardcoded)
- **4 mode groups**: Crown 🏛️, Analysis 🔬, Arithmetic ⚡, Spectral 🎵
- **21 existing visualizations** spanning the entire Cathedral proof chain
- **Zustand state management** with a single viewport store
- **Certificate system**: JSON files loaded from `/data/certificates/` for precomputed modes

The application already has a `gue` mode (Random Matrix) showing GUE pair correlations, and a `spectral-gap` mode showing the Gram matrix eigenvalue surface. **These are the natural anchor points for our new discoveries.**

---

## 2. New Visualization Modes to Add

### Mode 1: 🔥 Thermalization Cascade (HIGHEST IMPACT)

**What it shows:** An animated heatmap where each cell represents a (modulus, residue class, N) triple. Cells start cold (blue/Poisson) and ignite into hot (red-orange/GOE) as N increases, visually showing the "fire" of chaos propagating across the lattice.

**Renderer:** `chart` (Canvas 2D heatmap)  
**Data tier:** `precomputed` (from `modulus-probe` results)  
**Group:** `spectral` 🎵

**Implementation:**
```
Visualization ID: "thermalization"
experimentSource: "thermalization-cascade"
renderer: "chart" (or new "heatmap" renderer)
```

**The "wow" factor:** The user drags the N slider from 50 to 1000 and watches cells ignite one by one — Full matrix first, then Dark Sector, then individual residue classes rippling outward. The five moduli (3, 5, 7, 8, 12) are shown as parallel rows, proving universality in a single glance.

**Educational cards:**
1. "The Thermalization Cascade" — What you're watching is a phase transition. Each cell goes from integrable (Poisson) to chaotic (GOE) as N grows.
2. "Universality" — All five rows ignite at the same critical dimensions. The cascade doesn't care what modulus you use.
3. "The Fano Control" — Row 3 is Mod-7 (no Fano geometry). It shows the same cascade as Mod-8. The Fano plane is a coincidence.
4. "🏛️ Cathedral Connection" — The Gram matrix positive definiteness (proved in Lean) guarantees these eigenvalues are real. The GOE statistics emerge from the arithmetic.

**Certificate data format:**
```json
{
  "moduli": [3, 5, 7, 8, 12],
  "ns": [50, 75, 100, 150, 200, 300, 400, 500, 750, 1000],
  "data": {
    "3": {
      "full": [0.53, 0.77, 0.77, 0.79, 0.89, 0.98, 0.86, ...],
      "classes": {
        "1": [0.15, 0.20, 0.22, 0.23, 0.33, 0.60, ...]
      },
      "dark": [0.59, 0.57, 0.64, 0.74, 0.73, 0.75, ...]
    }
  }
}
```

---

### Mode 2: 🌡️ Dark Sector Phase Transition

**What it shows:** A fine-grained sweep of the Dark Sector GOE fit from N=50 to N=200, showing the exact Poisson→GOE transition curve. Plotted as a smooth, animated convergence chart with the critical threshold marked.

**Renderer:** `chart`  
**Data tier:** `precomputed`  
**Group:** `spectral`

**Implementation:**
```
Visualization ID: "dark-transition"
experimentSource: "dark-sector-sweep"
```

**Design:** A single smooth curve (GOE fit value vs N), with:
- Horizontal dashed line at 0.5 (transition threshold)
- Blue glow below threshold (Poisson regime)
- Red glow above threshold (GOE regime)  
- Animated vertical "cursor" that sweeps left to right
- Critical N_c marker where the curve crosses 0.5

**This could also be done as a dual-chart** — left panel shows the spacing histogram evolving from exponential (Poisson) to Wigner surmise (GOE), right panel shows the fit statistic curve.

---

### Mode 3: 📊 Level Spacing Distribution

**What it shows:** An animated histogram of normalized level spacings that morphs from the Poisson distribution P(s) = e^(-s) at low N to the Wigner surmise P(s) = (πs/2)e^(-πs²/4) at high N. The user drags N and watches the distribution transform.

**Renderer:** `chart` (histogram mode)  
**Data tier:** `precomputed`  
**Group:** `spectral`

**Implementation:**
```
Visualization ID: "level-spacing"
experimentSource: "level-spacing-histograms"
```

**Design:** 
- Histogram bars with animated transitions between N values
- Dashed cyan curve = Poisson reference
- Dashed amber curve = GOE (Wigner surmise) reference
- The bars smoothly morph from matching cyan to matching amber as N increases
- Title shows current N and best-fit class

---

### Mode 4: 🧲 Gram Matrix Residue Decomposition (3D)

**What it shows:** The Gram matrix visualized as a 3D heatmap/surface, with residue class structure visible as a block pattern. Indices colored by their mod-8 residue class.

**Renderer:** `surface` (Three.js mesh)  
**Data tier:** `precomputed`  
**Group:** `analysis`

**Implementation:**
```
Visualization ID: "gram-residue"
experimentSource: "gram-matrix-decomposed"
```

**Design:** A displacement-mapped surface where:
- Height = |G(j,k)| (Gram matrix entry magnitude)
- Color = residue class pairing (same-class pairs glow brighter)
- Camera orbits slowly, revealing the block structure
- N slider controls matrix dimension

**This extends the existing "gram-heatmap" mode with residue class coloring.**

---

### Mode 5: 🌐 Multi-Modulus Phase Map (2D Interactive)

**What it shows:** A 2D phase diagram with N on the x-axis and "channel" on the y-axis, where each row is a residue class and color encodes GOE fit strength. Multiple moduli displayed as tabs or stacked panels.

**Renderer:** `chart` or new `phase-map` renderer  
**Data tier:** `precomputed`  
**Group:** `spectral`

**Design:** Think of it like a geological stratigraphy chart — horizontal time axis (N), vertical layers (residue classes), color = "temperature" (Poisson=blue → GOE=red). The user can tab between moduli to see the universality.

---

## 3. Existing Modes to Enhance

### Enhance: `gue` (Random Matrix) → Add GOE/GUE Split

Currently shows GUE pair correlations for zeta zeros. Add a toggle/tab to show:
- **Left cloud:** GOE level spacings from the spatial Gram matrix
- **Right cloud:** GUE pair correlations from the zeta zeros
- **Annotation:** "The Mellin transform is a magnetic field" — connecting the GOE (spatial) to GUE (spectral) via the Mellin phase

This directly visualizes the GOE→GUE transition that the exploration discovered.

### Enhance: `spectral-gap` → Add Residue Class Decomposition

Currently shows the full Gram eigenvalue surface. Add color-coded sub-lattice eigenvalue tracks:
- Full G_N eigenvalues (white)
- k≡1(8) eigenvalues (red)
- k≡3(8) eigenvalues (blue)
- k≡5(8) eigenvalues (green)
- k≡7(8) eigenvalues (gold)

### Enhance: `stained-glass` → Connect to Experimental Results

The existing "Stained Glass Rotors" mode shows character-decomposed particle streams. Update its educational cards to reference the exploration 18/19 results, explaining that the character decomposition preserves eigenvalues (similarity transform) while the residue class partition reveals new spectral structure.

---

## 4. Implementation Strategy

### Phase 1: Data Export (Quick — 30 min)
Create a `data-export` binary in `character-spectral` that runs the probes and outputs JSON certificates in the format expected by `usePrecomputedData.ts`:

```rust
// New binary: data-export
// Outputs: /public/data/certificates/thermalization-cascade.json
//          /public/data/certificates/dark-sector-sweep.json
//          /public/data/certificates/level-spacing-histograms.json
```

### Phase 2: New Heatmap Renderer (Medium — 2 hours)
The existing `ChartRenderer` handles line charts. We need a heatmap variant:
- Grid of colored cells with smooth transitions
- Color interpolation: blue → cyan → green → yellow → red
- Animated reveal (cells light up left to right)
- Labels for modulus/residue class on y-axis, N on x-axis

This could be done as a new `HeatmapRenderer.tsx` or as a mode within `ChartRenderer`.

### Phase 3: Visualization Registration (Quick — 15 min)
Add new entries to `VISUALIZATIONS` array in `visualizations.ts` and add new ViewMode types to `types.ts`.

### Phase 4: Educational Content (Medium — 1 hour)
Write the educational cards, equations, and proof metadata for each new mode.

---

## 5. Priority Ranking

| # | Mode | Impact | Effort | Priority |
|---|---|---|---|---|
| 1 | Thermalization Cascade Heatmap | ⭐⭐⭐⭐⭐ | Medium | **DO FIRST** |
| 2 | Level Spacing Distribution | ⭐⭐⭐⭐ | Medium | High |
| 3 | Enhance `gue` with GOE/GUE | ⭐⭐⭐⭐ | Low | High |
| 4 | Dark Sector Phase Transition | ⭐⭐⭐ | Low | Medium |
| 5 | Gram Residue Decomposition 3D | ⭐⭐⭐ | High | Medium |
| 6 | Multi-Modulus Phase Map | ⭐⭐ | Medium | Lower |

The **Thermalization Cascade Heatmap** is the crown jewel. A single animated image that captures the entire story of explorations 18+19 — the ignition of chaos, the universal cascade, the falsification of the Fano hypothesis. It would be the most visually stunning and scientifically meaningful addition to the viewport.

---

## 6. Connection to the Cathedral Proof

Each new visualization connects to a specific piece of the formal proof:

| Visualization | Lean File | Connection |
|---|---|---|
| Thermalization Cascade | `Vasyunin/Matrix/GramPSD.lean` | Eigenvalue reality guaranteed by PSD |
| Level Spacing | `Spectral/RayleighBridge.lean` | Spacing statistics from certified eigenvalues |
| GOE/GUE Split | `White/Scattering.lean` | Mellin isometry = "magnetic field" |
| Dark Sector | `NymanBeurling/Separation.lean` | Even/odd decomposition |

These connections should be prominently displayed in the educational cards, linking the visual experience to the machine-checked mathematics.

---

*The HyperZeta Viewport is already a research-grade proof visualization tool. These additions would make it the world's first interactive exhibit of prime number quantum chaos.* 🏛️✨
