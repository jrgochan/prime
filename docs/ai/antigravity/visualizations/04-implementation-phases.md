# Implementation Phases — Build Plan

## Phase Summary

| Phase | Focus | Sessions | New Modes | Key Deliverable |
|-------|-------|----------|-----------|-----------------|
| 1 | Architecture Foundation | 2-3 | 0 | Renderer selector + grouped ModeBar |
| 2 | Chart Renderer | 2-3 | 5 | Hilbert π, Abel, BD, MVT, Graduation |
| 3 | Curve Renderer | 2 | 2 | Perron Contour, Enhanced Waves |
| 4 | Dual & Surface | 2 | 3 | Parseval Bridge, Phase Shattering, Gram |
| 5 | Graph & Polish | 1-2 | 2+ | Crown Theorem tree, Stained Glass |

---

## Phase 1: Architecture Foundation

**Goal**: Refactor the rendering system without breaking any existing modes.

### Tasks

- [ ] **Define enhanced types**
  - Add `RendererType`, `dataTier`, `group`, `proof` fields to `VisualizationMode`
  - Add `RendererType` to `ViewMode` type
  - Keep backward compatibility: existing modes get default values

- [ ] **Create RendererSelector component**
  ```
  scene/renderers/RendererSelector.tsx
  ```
  Reads `VIZ_MAP[viewMode].renderer` and renders the appropriate component.
  For `renderer: "particles"` → renders `ParticleRenderer`.
  For `renderer: "chart"` → renders nothing (chart goes in overlay).

- [ ] **Extract ParticleRenderer**
  ```
  scene/renderers/ParticleRenderer.tsx ← scene/LatticeCloud.tsx
  ```
  Move all logic from `LatticeCloud.tsx` into `ParticleRenderer.tsx`.
  Keep `LatticeCloud.tsx` as a thin wrapper that re-exports for compatibility.

- [ ] **Create ChartOverlay container**
  ```
  scene/ChartOverlay.tsx
  ```
  HTML `div` positioned absolutely over the R3F canvas. Only renders
  content when the active mode has `renderer: "chart" | "graph" | "dual-chart"`.

- [ ] **Implement grouped ModeBar**
  - Define `MODE_GROUPS` array in `content/visualizations.ts`
  - Render group tabs at top of ModeBar
  - Arrow keys navigate within group; Tab jumps between groups
  - All existing hotkeys still work

- [ ] **Add ProofBreadcrumb**
  ```
  hud/ProofBreadcrumb.tsx
  ```
  Shows the proof chain for the current mode, e.g.:
  `🏛️ Crown > Assembly/MellinCrown.lean > critical_line_mellin_variance`

- [ ] **Build certificate loader**
  ```
  engine/usePrecomputedData.ts
  ```
  Fetch + cache hook for JSON certificates.

- [ ] **Copy certificates script**
  ```
  scripts/copy-certificates.sh
  ```
  Copies experiment certificates to `public/data/certificates/`.

- [ ] **Verify**: All 11 existing modes render identically through the new
  RendererSelector. Zero regressions.

### Files Changed
```
src/engine/types.ts              — Enhanced ViewMode, RendererType
src/content/visualizations.ts    — Enhanced registry entries, MODE_GROUPS
src/scene/Viewport3D.tsx         — Use RendererSelector
src/scene/renderers/             — New directory
  RendererSelector.tsx           — NEW
  ParticleRenderer.tsx           — Extracted from LatticeCloud
src/scene/ChartOverlay.tsx       — NEW
src/hud/ModeBar.tsx              — Grouped layout
src/hud/ProofBreadcrumb.tsx      — NEW
src/engine/usePrecomputedData.ts — NEW
src/stores/viewport.ts           — precomputedData slice
scripts/copy-certificates.sh     — NEW
```

---

## Phase 2: Chart Renderer + First Chart Modes

**Goal**: Build the Canvas 2D chart renderer and deploy 5 chart-based modes.

### Tasks

- [ ] **Build ChartRenderer**
  ```
  scene/renderers/ChartRenderer.tsx
  ```
  Features:
  - Animated line drawing (left-to-right trace)
  - Multiple series with legend
  - Asymptote lines (dashed)
  - Log/linear axis toggle
  - Data point markers
  - Hover tooltips
  - Responsive sizing
  - Cathedral aesthetic (dark bg, glow lines, monospace)

- [ ] **Certificate adapter functions**
  ```
  content/certificate-adapters.ts
  ```
  Per-experiment functions that extract convergence series from
  raw certificate JSON:
  - `adaptHilbertCert()` → ‖H_N‖ → π
  - `adaptL2DecayCert()` → d²_N, d²_N·logN
  - `adaptGramOracleCert()` → Q_N/logN → C ≈ 21.65
  - `adaptAbelCert()` → S₁, S₂, S₃ thermometer data
  - `adaptMVTCert()` → predicted vs actual Dirichlet L²

- [ ] **Deploy: Hilbert π mode** (`hilbert-pi`)
  - Registry entry with proof metadata
  - Loads `hilbert-spectral` certificate
  - Two curves: norm (→π) and Schur bound (→∞)
  - Educational cards

- [ ] **Deploy: Abel Thermometer** (`abel-thermo`)
  - Three vertical "tubes" filling simultaneously
  - Targets: S₁→0, S₂→-1, S₃→2
  - Physics labels: magnetization, susceptibility, heat capacity

- [ ] **Deploy: BD Constant** (`bd-constant`)
  - Dual chart: spectral holes + Rayleigh quotient
  - Q_N/logN → C ≈ 21.65 convergence

- [ ] **Deploy: MVT Certificate** (`mvt-cert`)
  - Predicted vs actual agreement chart
  - Shows the first machine-verified Dirichlet MVT

- [ ] **Deploy: Graduation Timeline** (`graduation`)
  - Vertical timeline v1→v12
  - Axiom count bar chart per version
  - Milestone labels

- [ ] **Verify**: All 5 chart modes render smoothly. Certificate loading
  works. Fallback message shown if certificate missing.

### Files Created
```
src/scene/renderers/ChartRenderer.tsx
src/content/certificate-adapters.ts
public/data/certificates/*.json     — Copied from experiments
```

---

## Phase 3: Curve Renderer + Contour Modes

**Goal**: Build the THREE.Line renderer with glow shaders for curve-based modes.

### Tasks

- [ ] **Build CurveRenderer**
  ```
  scene/renderers/CurveRenderer.tsx
  ```
  Uses `THREE.Line` or `THREE.LineSegments` with a custom shader.
  Features:
  - Screen-space glow halo
  - Depth-based fade
  - Animated dash pattern (traveling contour)
  - Per-vertex color

- [ ] **Create curve shader**
  ```
  scene/shaders/curves.ts
  ```
  GLSL shader for glowing lines with animated dash patterns.

- [ ] **Deploy: Perron Contour** (`perron-contour`)
  - Complex plane visualization
  - Animated vertical line sweeping from σ=2 to σ=1/2
  - Residue flash at s=1
  - Horizontal segments fading at Im(s)=±T
  - JS-computed contour points (no WASM needed)

- [ ] **Enhance: Explicit Formula** (`waves`)
  - Better zero resolution indicator
  - Curve renderer for the smooth Li(x) term
  - Step function overlay for π(x)

- [ ] **Verify**: Line rendering with glow and animation.
  Perron contour animation plays smoothly.

### Files Created
```
src/scene/renderers/CurveRenderer.tsx
src/scene/shaders/curves.ts
```

---

## Phase 4: Dual & Surface Renderers

**Goal**: Build the split-screen and height-field renderers for the
most visually stunning new modes.

### Tasks

- [ ] **Build DualChartRenderer**
  ```
  scene/renderers/DualChartRenderer.tsx
  ```
  Two chart panels side by side with a glowing divider.
  Each panel is a mini ChartRenderer.

- [ ] **Deploy: Parseval Bridge** (`parseval-bridge`) ← THE CROWN JEWEL
  - Left: L²(0,1) integral as shaded area
  - Right: Mellin L² as spectral density
  - Center: glowing bridge connecting equal values
  - N slider: both sides converge simultaneously
  - Agreement displayed to 6 decimal places

- [ ] **Build DualParticleRenderer**
  ```
  scene/renderers/DualParticleRenderer.tsx
  ```
  Two particle clouds side by side. Each gets half the canvas.
  Uses the existing ParticleRenderer internally.

- [ ] **Deploy: Phase Shattering** (`phase-shattering`)
  - Left: Möbius sums with complex phases (converges)
  - Right: Same sums with absolute values (diverges)
  - Labels: "Phase coherence" vs "Phase destruction"
  - JS-computed (not WASM)

- [ ] **Build SurfaceRenderer**
  ```
  scene/renderers/SurfaceRenderer.tsx
  ```
  `THREE.PlaneGeometry` with vertex displacement.
  Features:
  - Height-mapped colors (viridis/inferno/cathedral)
  - Contour lines via `fract()` in shader
  - Wireframe toggle

- [ ] **Create surface shader**
  ```
  scene/shaders/surface.ts
  ```

- [ ] **Deploy: Gram Heatmap** (`gram-heatmap`)
  - Height = |G(j,k)| from gram-matrix experiment
  - Diagonal ridges, off-diagonal decay
  - N slider grows the visible matrix

- [ ] **Verify**: Split-screen rendering. Surface displacement.
  Parseval Bridge shows equal values on both sides.

### Files Created
```
src/scene/renderers/DualChartRenderer.tsx
src/scene/renderers/DualParticleRenderer.tsx
src/scene/renderers/SurfaceRenderer.tsx
src/scene/shaders/surface.ts
```

---

## Phase 5: Graph Renderer, Final Modes, Polish

**Goal**: Build the proof tree graph renderer and deploy remaining modes.
Polish transitions, loading states, and responsive design.

### Tasks

- [ ] **Build GraphRenderer**
  ```
  scene/renderers/GraphRenderer.tsx
  ```
  Force-directed layout using custom physics simulation.
  Node types: proved (green), axiom (amber), sorry (red), kernel (white).
  Click interaction, hover highlights, zoom/pan.

- [ ] **Create proof graph data**
  ```
  content/cathedral-map.ts
  ```
  Full dependency graph with ~30 nodes and ~50 edges.

- [ ] **Deploy: Crown Theorem** (`crown-theorem`)
  - Interactive axiom dependency graph
  - Root: nyman_beurling_equivalence
  - Two amber-pulsing crown axiom nodes
  - Click any node → sidebar shows Lean statement

- [ ] **Deploy: Stained Glass Rotors** (`stained-glass`)
  - Four colored particle beams (Dirichlet characters mod 8)
  - Uses existing WASM with JS post-processing

- [ ] **Deploy: Vasyunin Telescope** (`vasyunin-telescope`)
  - Animated telescoping sum chart
  - Row strips appearing and converging

- [ ] **Deploy: Mellin Crown** (`mellin-crown`)
  - Step-by-step forward chain animation
  - Each step lights up in sequence

- [ ] **Polish: Transitions**
  - Smooth fade between modes (300ms opacity transition)
  - Loading spinner for certificate fetch
  - Error state: "Certificate not found" with suggestion

- [ ] **Polish: Ambient background**
  ```
  scene/shaders/ambient.ts
  ```
  Subtle particle drift when 2D modes are active.

- [ ] **Polish: Responsive design**
  - Mobile: stacked layout for dual modes
  - Tablet: compressed ModeBar
  - Fullscreen mode

- [ ] **Polish: Mode count management**
  - "Highlights" filter showing top 8 modes
  - "All" view showing all 22+

- [ ] **Final verification**
  - All modes render without console errors
  - `npm run build` succeeds
  - Lighthouse performance audit
  - Screenshot each mode for documentation

### Files Created
```
src/scene/renderers/GraphRenderer.tsx
src/content/cathedral-map.ts
src/scene/shaders/ambient.ts
```

---

## Dependency Graph

```
Phase 1 ──→ Phase 2 ──→ Phase 3
   │                        │
   └──→ Phase 4 ────────────┘
              │
              └──→ Phase 5
```

Phase 1 is the foundation — nothing else can start until it's done.
Phases 2, 3, and 4 can be worked on in any order after Phase 1.
Phase 5 requires all renderers to be available.

---

## Testing Strategy

### Per-Mode Checklist
For each new mode, verify:
- [ ] Mode appears in ModeBar under correct group
- [ ] Hotkey works
- [ ] Equation overlay displays correctly
- [ ] Educational cards render in sidebar
- [ ] Proof breadcrumb shows correct path
- [ ] No console errors
- [ ] Rendering is smooth (60fps for live, responsive for precomputed)
- [ ] N slider (if applicable) changes the visualization
- [ ] Mode transitions cleanly to/from adjacent modes

### Integration Checks
- [ ] All 11 original modes still work identically
- [ ] Command palette (Cmd+K) finds all modes
- [ ] Keyboard navigation (arrows, Tab) works across groups
- [ ] Certificate loading works when experiment data exists
- [ ] Graceful degradation when certificate is missing
