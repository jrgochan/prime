# Data Pipeline — Three-Tier Architecture

## Overview

```
┌─────────────────────────────────────────────────┐
│                   TIER 1: LIVE                   │
│           WASM Engine (tick_physics)              │
│     Real-time particle simulation, 60fps         │
└───────────────────────┬─────────────────────────┘
                        │
┌───────────────────────┼─────────────────────────┐
│                   TIER 2: PRECOMPUTED            │
│        JSON certificates from Rust experiments    │
│     Loaded on demand, cached in memory            │
└───────────────────────┼─────────────────────────┘
                        │
┌───────────────────────┼─────────────────────────┐
│                   TIER 3: STATIC                 │
│     Proof tree / axiom graph from Lean metadata   │
│     Hardcoded in TypeScript data files            │
└───────────────────────┴─────────────────────────┘
                        │
                        ▼
                  Zustand Store
                        │
                        ▼
                 RendererSelector
```

---

## Tier 1: Live (WASM)

### Description
The existing `core_engine.wasm` drives real-time particle simulations.
Each frame calls `engine.tick_physics()` and reads from the shared
Float32Array buffer. This is the highest-performance tier.

### WASM Strategy: No Changes
The existing WASM binary stays as-is. We do NOT add new modes to it.
New particle-based modes (Stained Glass Rotors, Phase Shattering)
will use the existing WASM engine's output buffer with JS-side
post-processing, or simple JS-based computation.

### Modes Using Tier 1
- Sedenion Cloud, Riemann Spiral, Cornu Spirals, Euler Product
- GUE Random Matrix, Mertens Turbulence, Prime Harmonics
- Zero Landscape, Functional Equation, Cayley-Dickson Tower
- Stained Glass Rotors (new — JS post-processing of WASM output)
- Phase Shattering (new — dual WASM buffers)
- Perron Contour (new — JS-computed curve data)

### Data Flow
```
WASM Engine
    │
    ├── outputBuffer: Float32Array[N*3]  ← ζ(s) output positions
    ├── inputBuffer:  Float32Array[N*3]  ← input space positions
    ├── collapse:     f32                ← collapse metric
    └── lambda:       f32                ← time parameter
```

---

## Tier 2: Precomputed (JSON Certificates)

### Description
The 35 Rust experiments produce JSON certificates with numerical results.
These are loaded on demand when a Tier 2 visualization mode is activated.

### Certificate Registry

```typescript
// data/certificates.ts

export interface CertificateManifest {
  [experimentName: string]: {
    path: string;            // relative to public/data/
    description: string;
    leanConnection: string;  // Which Lean axiom/theorem this validates
    precision: number;       // bits of precision
    maxN: number;           // maximum N tested
  };
}

export const CERTIFICATES: CertificateManifest = {
  "hilbert-spectral": {
    path: "certificates/hilbert-spectral.json",
    description: "Hilbert operator norm convergence to π",
    leanConnection: "Analysis/HilbertInequality.lean",
    precision: 512,
    maxN: 1000,
  },
  "l2-decay": {
    path: "certificates/l2-decay.json",
    description: "L² decay certificate: d²_N · logN bounded",
    leanConnection: "Assembly/MellinCrown.lean",
    precision: 256,
    maxN: 1000,
  },
  "gram-oracle": {
    path: "certificates/gram-oracle.json",
    description: "Rayleigh quotient Q_N/logN → C ≈ 21.65",
    leanConnection: "Vasyunin/GramMatrix.lean",
    precision: 256,
    maxN: 5000,
  },
  // ... more certificates
};
```

### Loading Hook

```typescript
// engine/usePrecomputedData.ts

import { useState, useEffect } from "react";

export function usePrecomputedData(experimentName: string | undefined) {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!experimentName) {
      setData(null);
      return;
    }

    const cached = dataCache.get(experimentName);
    if (cached) {
      setData(cached);
      return;
    }

    setLoading(true);
    fetch(`/data/certificates/${experimentName}.json`)
      .then(r => r.json())
      .then(json => {
        dataCache.set(experimentName, json);
        setData(json);
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false));
  }, [experimentName]);

  return { data, loading, error };
}

// Simple in-memory cache
const dataCache = new Map<string, any>();
```

### Build-Time Certificate Copy

A build script copies selected certificates from `experiments/*/results/`
into `public/data/certificates/`:

```bash
#!/bin/bash
# scripts/copy-certificates.sh

DEST="public/data/certificates"
mkdir -p "$DEST"

EXPERIMENTS=(
  "hilbert-spectral"
  "l2-decay-certificate"
  "gram-oracle"
  "mellin-certificate"
  "abel-bridge"
  "mvt-decomposition"
  "vasyunin-convergence"
  "rotor-spectroscopy"
  "crown-cancellation"
  "gram-matrix"
  "bc-exponent-frontier"
  "pnt-mobius-sums"
  "perron-contour"
)

for exp in "${EXPERIMENTS[@]}"; do
  SRC="../../experiments/$exp/results/certificate.json"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$DEST/$exp.json"
    echo "✓ $exp"
  else
    echo "⚠ $exp — no certificate found"
  fi
done
```

### Certificate Data Shapes

Each experiment produces slightly different JSON. The chart renderer
needs a standard interface:

```typescript
// Types for chart data extracted from certificates

interface ConvergencePoint {
  N: number;
  value: number;
  logN?: number;
  ratio?: number;
}

interface ConvergenceSeries {
  label: string;
  color: string;
  points: ConvergencePoint[];
  asymptote?: number;        // Horizontal target line
  asymptoteLabel?: string;
}

// Adapter functions per experiment
function adaptHilbertCert(cert: any): ConvergenceSeries[] {
  // Extract operator_norm_convergence data
  return [{
    label: "‖H_N‖_op",
    color: "#00ff88",
    points: cert.norm_data.map((d: any) => ({ N: d.N, value: d.norm })),
    asymptote: Math.PI,
    asymptoteLabel: "π",
  }];
}

function adaptL2DecayCert(cert: any): ConvergenceSeries[] {
  return [
    {
      label: "d²_N",
      color: "#00ccff",
      points: cert.l2_decomposition.map((d: any) => ({
        N: d.N, value: d.d_sq
      })),
    },
    {
      label: "d²_N · logN",
      color: "#ffaa00",
      points: cert.l2_decomposition.map((d: any) => ({
        N: d.N, value: d.d_sq_logN
      })),
      asymptote: 1.0,
      asymptoteLabel: "bounded",
    },
  ];
}
```

---

## Tier 3: Static (Proof Metadata)

### Description
The proof tree, axiom dependency graph, and graduation timeline are
static data compiled from the Cathedral's Lean source. This data
is hardcoded in TypeScript files (not loaded at runtime).

### Proof Graph Data

```typescript
// content/cathedral-map.ts

export interface ProofNode {
  id: string;
  label: string;
  leanFile: string;
  module: string;
  status: "proved" | "axiom" | "sorry" | "kernel";
  group: "crown" | "analysis" | "arithmetic" | "spectral";
  description?: string;
}

export interface ProofEdge {
  from: string;
  to: string;
}

export const CROWN_NODES: ProofNode[] = [
  {
    id: "nyman_beurling_equivalence",
    label: "RH ↔ d²_N → 0",
    leanFile: "Assembly/MainChain.lean",
    module: "Assembly",
    status: "proved",
    group: "crown",
    description: "The crown theorem: Riemann Hypothesis is equivalent to NB distance decay",
  },
  {
    id: "critical_line_mellin_variance",
    label: "Mellin Variance ≤ C/logN",
    leanFile: "Assembly/MellinCrown.lean",
    module: "Assembly",
    status: "axiom",
    group: "crown",
    description: "Hardy-Littlewood mean value bound on critical line",
  },
  {
    id: "rh_zeta_lower_bound_from_zero_counting",
    label: "|ζ(s)| ≥ c|t|⁻ᴬ",
    leanFile: "Cathedral/Zeta/Hadamard.lean",
    module: "Zeta",
    status: "axiom",
    group: "crown",
    description: "Hadamard zero-counting zeta lower bound",
  },
  {
    id: "parseval_bridge_white",
    label: "Parseval Bridge",
    leanFile: "White/Scattering.lean",
    module: "White",
    status: "proved",
    group: "analysis",
    description: "L²(0,1) = Mellin L² on critical line (0 axioms)",
  },
  // ... ~30 more nodes
];

export const CROWN_EDGES: ProofEdge[] = [
  { from: "nyman_beurling_equivalence", to: "critical_line_mellin_variance" },
  { from: "nyman_beurling_equivalence", to: "rh_zeta_lower_bound_from_zero_counting" },
  { from: "nyman_beurling_equivalence", to: "parseval_bridge_white" },
  { from: "nyman_beurling_equivalence", to: "rank1_mellin_separation" },
  // ...
];
```

### Graduation Timeline Data

```typescript
// content/graduation-data.ts

export interface GraduationMilestone {
  version: string;
  date: string;
  crownAxioms: number;
  totalFiles: number;
  totalLOC: number;
  milestone: string;
  details: string;
}

export const GRADUATION_TIMELINE: GraduationMilestone[] = [
  {
    version: "v1", date: "2026-03-27", crownAxioms: 56,
    totalFiles: 40, totalLOC: 8000,
    milestone: "Initial architecture",
    details: "First formalization attempt, 56 axioms scattered across modules",
  },
  // ... v2 through v11
  {
    version: "v12", date: "2026-04-28", crownAxioms: 2,
    totalFiles: 174, totalLOC: 43387,
    milestone: "Crown Graduation",
    details: "Zero sorry, zero warning. MVT machine-verified. 35 experiments at 512-bit MPFR.",
  },
];
```

---

## Store Enhancement

The Zustand store gains a `precomputedData` slice:

```typescript
interface ViewportState {
  // ... existing fields ...

  // NEW: Precomputed data
  precomputedData: Record<string, any>;  // Cached certificates
  dataLoading: boolean;
  dataError: string | null;

  // NEW: Actions
  loadCertificate: (experiment: string) => Promise<void>;
}
```

The store's `setViewMode` action checks if the new mode needs
precomputed data and triggers a load if needed:

```typescript
setViewMode: (viewMode) => {
  const viz = VIZ_MAP[viewMode];
  
  // Load precomputed data if needed
  if (viz.dataTier === "precomputed" && viz.experimentSource) {
    const cached = get().precomputedData[viz.experimentSource];
    if (!cached) {
      get().loadCertificate(viz.experimentSource);
    }
  }
  
  // Tell WASM engine (only for live modes)
  if (viz.dataTier === "live" && viz.wasmMode !== undefined) {
    const system = get().hyperSystem;
    if (system?.engine) {
      system.engine.set_view_mode(viz.wasmMode);
    }
  }
  
  set({ viewMode, paletteOpen: false });
},
```
