# Renderer System — Deep Architecture

## The Problem

The current `LatticeCloud.tsx` is a monolithic particle renderer. Every mode
renders as `THREE.Points` with the same shader. This works for the original
11 modes (all particle-based), but new Cathedral visualizations need:

- **Lines/Curves** — Perron contour integrals, convergence traces
- **Surfaces** — Gram matrix heatmaps, spectral gap height fields
- **2D Charts** — Convergence plots, thermometers, timelines
- **Graphs** — Force-directed axiom dependency trees
- **Dual Views** — Split-screen for Parseval Bridge

## The Solution: Renderer Abstraction

### Renderer Types

```typescript
type RendererType =
  | "particles"       // THREE.Points — GPU particle cloud
  | "curves"          // THREE.Line — glowing line geometry
  | "surface"         // THREE.Mesh — displacement-mapped surface
  | "chart"           // HTML Canvas 2D overlay
  | "graph"           // Force-directed graph overlay
  | "dual-chart"      // Split-screen 2D charts
  | "dual-particles"  // Split-screen 3D particle clouds
```

### Component Tree

```
<main className="viewport-root">
  │
  ├── <Viewport3D>                         ← R3F Canvas (always rendered)
  │   └── <RendererSelector mode={viewMode}>
  │       ├── particles  → <ParticleRenderer />
  │       ├── curves     → <CurveRenderer />
  │       ├── surface    → <SurfaceRenderer />
  │       ├── dual-*     → <DualRenderer left={} right={} />
  │       └── chart/graph → null (3D canvas shows ambient background)
  │
  ├── <ChartOverlay>                       ← HTML layer above canvas
  │   ├── chart      → <ChartRenderer />
  │   ├── graph      → <GraphRenderer />
  │   └── dual-chart → <DualChartRenderer />
  │
  ├── <HUD>                                ← Always visible UI
  │   ├── <Header />
  │   ├── <ProofBreadcrumb />              ← NEW
  │   ├── <MetricsPanel />
  │   ├── <EquationOverlay />
  │   └── <ModeBar />                      ← Enhanced with groups
  │
  └── <Overlays>
      ├── <CommandPalette />
      ├── <KeyboardHelp />
      └── <InfoSidebar />
```

### Key Insight: 3D vs 2D Separation

3D modes render inside the React Three Fiber `<Canvas>`.
2D modes render as HTML elements *on top of* the canvas.

When a 2D mode is active, the 3D canvas still renders but shows a subtle
ambient particle field or gradient background — never a blank void. This
gives every mode a sense of depth and life.

---

## Renderer Implementations

### 1. ParticleRenderer (existing → extracted)

```
Source: scene/renderers/ParticleRenderer.tsx
Shader: shaders/lattice.ts (existing)
Data:   WASM engine tick_physics() → Float32Array buffer
Modes:  Sedenion Cloud, Spiral, Cornu, Euler, GUE, Mertens,
        Harmonics, Stained Glass Rotors
```

This is the existing `LatticeCloud.tsx` extracted into the renderer pattern.
No changes to the rendering logic — just wrapped in the renderer interface.

**Uniform interface:**
- `uCoreColor`, `uEdgeColor` — from registry
- `uCollapse` — from engine metrics
- `uTime` — from engine lambda

### 2. CurveRenderer (new)

```
Source: scene/renderers/CurveRenderer.tsx
Shader: shaders/curves.ts (new)
Data:   WASM engine or precomputed arrays
Modes:  Perron Contour, Enhanced Explicit Formula
```

Renders `THREE.Line` or `THREE.LineSegments` with a custom glow shader.
Lines have depth-based fade, additive blending for the glow effect,
and animated dash patterns for "traveling" effects (contour integration).

**Shader features:**
- Glow halo (screen-space width)
- Depth fade (farther = dimmer)
- Animated dash pattern (for contour travel)
- Per-vertex color (for residue highlights)

**Perron Contour specifics:**
- Vertical line at σ=c (Re(s)=c) rendered as a glowing cyan line
- Animated "sweep" from c=2 leftward to c=1/2+ε
- When the contour crosses s=1, a residue flash (bright white pulse)
- Horizontal contour segments at Im(s)=±T fade to zero

### 3. SurfaceRenderer (new)

```
Source: scene/renderers/SurfaceRenderer.tsx
Shader: shaders/surface.ts (new)
Data:   Precomputed 2D arrays (from Rust experiments)
Modes:  Gram Heatmap, Enhanced Spectral Gap, Zero Landscape
```

Renders a `THREE.PlaneGeometry` with vertex displacement for height fields.
Color mapping from a configurable gradient palette.

**Shader features:**
- Vertex displacement: `position.z = heightMap[uv] * scale`
- Color mapping: height → color via gradient texture
- Contour lines: `fract(height * contourFreq) < threshold`
- Wireframe overlay option

**Data format:**
```typescript
interface SurfaceData {
  width: number;       // Grid X resolution
  height: number;      // Grid Y resolution
  values: Float32Array; // Row-major height values
  xRange: [number, number]; // Domain range
  yRange: [number, number];
  colorMap: "viridis" | "inferno" | "cathedral"; // Gradient palette
}
```

### 4. ChartRenderer (new)

```
Source: scene/renderers/ChartRenderer.tsx
Shader: none (HTML Canvas 2D)
Data:   Precomputed JSON certificates
Modes:  Hilbert π, Abel Thermometer, BD Constant, MVT Certificate,
        Graduation Timeline, Vasyunin Telescope
```

Pure Canvas 2D rendering for convergence plots and charts. Rendered in the
`<ChartOverlay>` HTML layer above the 3D canvas. Styled to match the HUD
aesthetic (dark background, glowing lines, monospace labels).

**Features:**
- Animated line drawing (trace appears left-to-right)
- Multiple series with per-series colors
- Asymptote markers (dashed horizontal lines for limit values)
- Log/linear axis toggle
- Data point markers at experiment values
- Real-time tooltip on hover

**Design system:**
```css
/* Chart matches the HUD aesthetic */
.chart-container {
  background: rgba(0, 0, 0, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  backdrop-filter: blur(12px);
  font-family: var(--font-geist-mono);
}
```

### 5. GraphRenderer (new)

```
Source: scene/renderers/GraphRenderer.tsx
Shader: none (HTML Canvas 2D or SVG)
Data:   Static proof tree metadata
Modes:  Crown Theorem (axiom dependency graph)
```

Force-directed graph layout for the Cathedral's proof dependency tree.
Nodes represent theorems/axioms; edges represent dependencies.

**Node types:**
- 🟢 Proved theorem (green glow)
- 🟡 Crown axiom (amber pulse)
- 🔴 Sorry (red, dim)
- ⬜ Lean kernel axiom (white, small)

**Interaction:**
- Click a node → sidebar shows Lean theorem statement
- Hover → highlight dependency chain
- Scroll wheel → zoom
- Drag → pan

**Data structure:**
```typescript
interface ProofNode {
  id: string;
  label: string;
  leanFile: string;
  status: "proved" | "axiom" | "sorry" | "kernel";
  group: "crown" | "analysis" | "arithmetic" | "spectral";
}

interface ProofEdge {
  source: string; // depends on
  target: string; // this theorem
}
```

### 6. DualRenderer (new)

```
Source: scene/renderers/DualRenderer.tsx
Data:   Mixed (one side WASM, one side precomputed, or both precomputed)
Modes:  Parseval Bridge, Phase Shattering
```

Split-screen renderer that composes two sub-renderers side by side.
A glowing divider line separates the two halves. Labels above each half.

**Parseval Bridge layout:**
```
┌─────────────────┬─────────────────┐
│  L²(0,1) Space  │  Mellin L² on   │
│                 │  Critical Line   │
│  ∫|1-f_N|²dx   │  (1/2π)∫|M|²dt  │
│                 │                 │
│  [shaded area]  │  [spectral      │
│                 │   density]      │
│     = 0.127     │     = 0.127     │
│                 │                 │
├────── 🌉 ──────┤                 │
│     SAME NUMBER                  │
└─────────────────┴─────────────────┘
```

---

## Shader Files

```
scene/shaders/
├── lattice.ts          # Existing particle shader (untouched)
├── curves.ts           # Glow lines + animated dash
├── surface.ts          # Height field + contour lines
├── bridge.ts           # Parseval bridge glow effect
└── ambient.ts          # Subtle background for 2D mode canvas
```

### Ambient Background Shader

When a 2D mode (chart/graph) is active, the 3D canvas shows a subtle
animated background — slowly drifting particles or a gentle gradient
field — so the app never feels "dead" even without 3D content:

```glsl
// ambient.ts — gentle particle drift
void main() {
  float t = uTime * 0.1;
  float noise = fract(sin(dot(position.xy, vec2(12.9898, 78.233))) * 43758.5453);
  vec3 drift = position + vec3(sin(t + noise), cos(t * 0.7 + noise), 0.0) * 0.5;
  // ... very dim, very slow, very subtle
}
```

---

## Migration Strategy

1. **Extract** `LatticeCloud.tsx` → `renderers/ParticleRenderer.tsx` (no logic change)
2. **Create** `RendererSelector.tsx` that reads `registry[mode].renderer`
3. **Wire** `Viewport3D.tsx` to use `RendererSelector` instead of `LatticeCloud`
4. **Verify** all 11 existing modes render identically
5. **Add** `ChartOverlay` container above the canvas
6. **Build** new renderers one at a time, each with its first mode
