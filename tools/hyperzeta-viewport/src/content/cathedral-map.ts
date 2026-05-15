/**
 * Cathedral Proof Map — dependency graph data for the Crown Theorem
 * visualization. Each node is a theorem or axiom; edges represent
 * proof dependencies.
 *
 * Updated: v16 One-Pillar Cathedral (May 2026)
 * Crown axiom: baez_duarte_forward (sole non-kernel axiom)
 * Axiom footprint: [baez_duarte_forward, propext, Classical.choice, Quot.sound]
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
    description: "Nyman-Beurling equivalence: The Riemann Hypothesis is equivalent to the distance decay in L²(0,1). Zero sorry.",
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
  {
    id: "vasyunin",
    label: "Vasyunin Assembly",
    leanFile: "Vasyunin/Cotangent/VasyuninAssembly.lean",
    status: "proved",
    group: "analysis",
    description: "Vasyunin cotangent closed form via digamma. Zero axioms.",
  },

  // ── Arithmetic ──
  {
    id: "perron",
    label: "Perron Chain",
    leanFile: "Perron/MertensFromPerron.lean",
    status: "proved",
    group: "arithmetic",
    description: "RH → |M(x)| ≤ Cx^{3/4}. 16-file chain. Zero sorry.",
  },
  {
    id: "abel_s1",
    label: "S₁ = Σμ/k → 0",
    leanFile: "AbelTail/Assembly.lean",
    status: "proved",
    group: "arithmetic",
    description: "First PNT moment. Proved via Abel summation engine.",
  },
  {
    id: "mellin",
    label: "Mellin Bridge",
    leanFile: "MellinBridge/MertensBound.lean",
    status: "proved",
    group: "arithmetic",
    description: "Connects Mertens x^{3/4} bound to L² decay via Mellin transform.",
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
    id: "quot_sound",
    label: "Quot.sound",
    leanFile: "Lean kernel",
    status: "kernel",
    group: "spectral",
    description: "Quotient soundness (Lean kernel axiom).",
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
  // Crown depends on the single axiom + analysis chain
  { from: "nbe", to: "bd_fwd" },
  { from: "nbe", to: "parseval" },
  { from: "nbe", to: "rank1" },
  { from: "nbe", to: "spectral" },
  { from: "nbe", to: "perron" },

  // Analysis chain
  { from: "parseval", to: "mvt" },
  { from: "mvt", to: "hilbert" },
  { from: "rank1", to: "gram" },
  { from: "spectral", to: "gram" },
  { from: "gram", to: "vasyunin" },

  // Arithmetic chain
  { from: "perron", to: "mellin" },
  { from: "mellin", to: "abel_s1" },

  // Kernel dependencies (all modules depend on these)
  { from: "parseval", to: "propext" },
  { from: "gram", to: "choice" },
  { from: "abel_s1", to: "quot_sound" },
];

/**
 * Layout positions for a nice tree visualization.
 * Computed once and cached.
 */
export function computeGraphLayout(): Map<string, { x: number; y: number }> {
  const positions = new Map<string, { x: number; y: number }>();

  // Crown (root at top)
  positions.set("nbe", { x: 400, y: 40 });

  // Crown axiom (single pillar)
  positions.set("bd_fwd", { x: 200, y: 140 });

  // Analysis row
  positions.set("parseval", { x: 100, y: 240 });
  positions.set("rank1", { x: 300, y: 240 });
  positions.set("spectral", { x: 480, y: 240 });
  positions.set("perron", { x: 680, y: 240 });

  // Deep analysis
  positions.set("mvt", { x: 60, y: 340 });
  positions.set("hilbert", { x: 60, y: 420 });
  positions.set("gram", { x: 390, y: 340 });
  positions.set("vasyunin", { x: 390, y: 420 });

  // Arithmetic
  positions.set("mellin", { x: 680, y: 340 });
  positions.set("abel_s1", { x: 680, y: 420 });

  // Kernel
  positions.set("propext", { x: 140, y: 520 });
  positions.set("choice", { x: 390, y: 520 });
  positions.set("quot_sound", { x: 640, y: 520 });

  return positions;
}
