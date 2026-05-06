/**
 * Cathedral Proof Map — dependency graph data for the Crown Theorem
 * visualization. Each node is a theorem or axiom; edges represent
 * proof dependencies.
 */

import type { VizGroup } from "../engine/types";

export interface ProofNode {
  id: string;
  label: string;
  leanFile: string;
  status: "proved" | "axiom" | "kernel";
  group: VizGroup;
  description: string;
}

export interface ProofEdge {
  from: string;
  to: string;
}

export const CATHEDRAL_NODES: ProofNode[] = [
  // ── Crown ──
  {
    id: "nbe",
    label: "RH ↔ d²_N → 0",
    leanFile: "Assembly/MainChain.lean",
    status: "proved",
    group: "crown",
    description: "Nyman-Beurling equivalence: The Riemann Hypothesis is equivalent to the distance decay in L²(0,1).",
  },
  {
    id: "bd_fwd",
    label: "baez_duarte_forward",
    leanFile: "Assembly/MainChain.lean",
    status: "axiom",
    group: "crown",
    description: "BD forward direction (IMRN 2003): RH ⟹ d²_N → 0. Sole crown axiom of the One-Pillar Cathedral (v16).",
  },

  // ── Analysis ──
  {
    id: "parseval",
    label: "Parseval Bridge",
    leanFile: "White/Scattering.lean",
    status: "proved",
    group: "analysis",
    description: "∫|1-f_N|²dx = (1/2π)∫|M(½+it)|²dt. Proved with 0 axioms.",
  },
  {
    id: "hilbert",
    label: "Hilbert ≤ π",
    leanFile: "Analysis/HilbertInequality.lean",
    status: "proved",
    group: "analysis",
    description: "Schur test: ‖H_N‖_op ≤ π. Used in MVT chain.",
  },
  {
    id: "mvt",
    label: "Montgomery-Vaughan",
    leanFile: "Analysis/MontgomeryVaughan.lean",
    status: "proved",
    group: "analysis",
    description: "Dirichlet mean value theorem. Machine-verified.",
  },
  {
    id: "gram",
    label: "Gram Matrix PD",
    leanFile: "Vasyunin/Matrix/GramPSD.lean",
    status: "proved",
    group: "analysis",
    description: "Gram matrix is positive definite. Uses Abel summation.",
  },
  {
    id: "spectral",
    label: "Spectral Gap ≥ ε",
    leanFile: "Spectral/RayleighBridge.lean",
    status: "proved",
    group: "analysis",
    description: "Uniform lower bound on smallest eigenvalue of G_N.",
  },
  {
    id: "rank1",
    label: "Rank-1 Separation",
    leanFile: "NymanBeurling/Separation.lean",
    status: "proved",
    group: "analysis",
    description: "Decomposition of b_N into rank-1 + remainder.",
  },

  // ── Arithmetic ──
  {
    id: "perron",
    label: "Perron Chain",
    leanFile: "Perron/MertensFromPerron.lean",
    status: "proved",
    group: "arithmetic",
    description: "RH → |M(x)| ≤ Cx^{3/4}. 16-file chain.",
  },
  {
    id: "abel_s1",
    label: "S₁ = Σμ/k → 0",
    leanFile: "AbelTail/Assembly.lean",
    status: "proved",
    group: "arithmetic",
    description: "First PNT moment. Zero axioms.",
  },
  {
    id: "pnt",
    label: "PNT via Selberg",
    leanFile: "PNT/Bridge.lean",
    status: "proved",
    group: "arithmetic",
    description: "Prime Number Theorem via Selberg symmetry formula.",
  },

  // ── Kernel (Lean built-in axioms) ──
  {
    id: "propext",
    label: "propext",
    leanFile: "Lean kernel",
    status: "kernel",
    group: "spectral",
    description: "Propositional extensionality (Lean kernel axiom).",
  },
  {
    id: "quot_mk",
    label: "Quot.mk",
    leanFile: "Lean kernel",
    status: "kernel",
    group: "spectral",
    description: "Quotient type constructor (Lean kernel axiom).",
  },
  {
    id: "choice",
    label: "Classical.choice",
    leanFile: "Lean kernel",
    status: "kernel",
    group: "spectral",
    description: "Axiom of choice (Lean kernel axiom).",
  },
];

export const CATHEDRAL_EDGES: ProofEdge[] = [
  // Crown depends on
  { from: "nbe", to: "bd_fwd" },
  { from: "nbe", to: "parseval" },
  { from: "nbe", to: "rank1" },
  { from: "nbe", to: "spectral" },

  // Analysis chain
  { from: "parseval", to: "mvt" },
  { from: "mvt", to: "hilbert" },
  { from: "rank1", to: "gram" },
  { from: "spectral", to: "gram" },

  // Arithmetic chain
  { from: "nbe", to: "perron" },
  { from: "perron", to: "abel_s1" },
  { from: "abel_s1", to: "pnt" },

  // Kernel dependencies
  { from: "parseval", to: "propext" },
  { from: "gram", to: "choice" },
  { from: "pnt", to: "quot_mk" },
];

/**
 * Layout positions for a nice tree visualization.
 * Computed once and cached.
 */
export function computeGraphLayout(): Map<string, { x: number; y: number }> {
  const positions = new Map<string, { x: number; y: number }>();

  // Manual tree layout (root at top)
  positions.set("nbe", { x: 400, y: 40 });

  // Crown axiom (single)
  positions.set("bd_fwd", { x: 400, y: 140 });

  // Analysis row
  positions.set("parseval", { x: 120, y: 240 });
  positions.set("rank1", { x: 320, y: 240 });
  positions.set("spectral", { x: 480, y: 240 });
  positions.set("perron", { x: 680, y: 240 });

  // Deep analysis
  positions.set("mvt", { x: 80, y: 340 });
  positions.set("hilbert", { x: 80, y: 420 });
  positions.set("gram", { x: 400, y: 340 });

  // Arithmetic
  positions.set("abel_s1", { x: 680, y: 340 });
  positions.set("pnt", { x: 680, y: 420 });

  // Kernel
  positions.set("propext", { x: 160, y: 500 });
  positions.set("choice", { x: 400, y: 500 });
  positions.set("quot_mk", { x: 640, y: 500 });

  return positions;
}
