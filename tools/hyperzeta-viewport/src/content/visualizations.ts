import type { ReactNode } from "react";
import type { ViewMode } from "../engine/types";

export interface EducationalCard {
  title: string;
  body: string;
}

export interface VisualizationMode {
  id: ViewMode;
  label: string;
  shortLabel: string;
  icon: string;
  hotkey: string;
  color: { core: string; edge: string };
  equation: { main: string; sub: string };
  description: string;
  cards: EducationalCard[];
  wasmMode: number;
  usesOutputBuffer: boolean;
}

/**
 * THE VISUALIZATION REGISTRY
 *
 * Adding a new visualization = adding one object here.
 * All UI components (ModeBar, CommandPalette, Sidebar, Shader colors,
 * EquationOverlay) read from this registry automatically.
 */
export const VISUALIZATIONS: VisualizationMode[] = [
  {
    id: "output",
    label: "Sedenion Cloud",
    shortLabel: "ζ(s)",
    icon: "✦",
    hotkey: "1",
    color: { core: "#00ff88", edge: "#006644" },
    equation: { main: "ζ_𝕊(s) = Σₙ₌₁⁸ n⁻ˢ", sub: "s ∈ 𝕊₁₆ · Re(s) = ½" },
    description:
      "The 16D sedenion zeta function projected to 3D. Particles breathe and collapse near zeros.",
    cards: [
      {
        title: "What You're Seeing",
        body: "50,000 points representing a sedenion lattice — a 16-dimensional algebraic structure — projected into 3D. The Rust/WASM engine evolves each point along the critical line of the Riemann zeta function.",
      },
      {
        title: "The Mathematics",
        body: "Each particle represents an input s in 16D with Re(s) = ½. The engine computes the Dirichlet series ζ(s) = Σ n⁻ˢ in full sedenion arithmetic. What you see is the output — the value of ζ(s) — projected via its quaternionic components.",
      },
      {
        title: "Why Particles Collapse",
        body: "When the Collapse Metric drops, particles cluster near the origin. This means ζ(s) ≈ 0 — the simulation has found a zero of zeta on the critical line.",
      },
    ],
    wasmMode: 0,
    usesOutputBuffer: true,
  },
  {
    id: "spiral",
    label: "Riemann Spiral",
    shortLabel: "Spiral",
    icon: "🌀",
    hotkey: "2",
    color: { core: "#00ccff", edge: "#004466" },
    equation: {
      main: "ζ(½+it) → (Re, t, Im)",
      sub: "50-term Dirichlet series",
    },
    description:
      "The iconic zeta spiral. Rings contract to singularities at zeros and expand between them.",
    cards: [
      {
        title: "The Zeta Spiral",
        body: "Each particle samples ζ(½+it) at a unique height t on the critical line. Plotted as (Re(ζ), t, Im(ζ)), rings contract to points at zeros of ζ — where the function crosses zero.",
      },
      {
        title: "The Pinch Points",
        body: "Every contraction is a non-trivial zero: t ≈ 14.13, 21.02, 25.01... These are the zeros the Riemann Hypothesis claims all lie on Re(s) = ½.",
      },
      {
        title: "Winding Rate",
        body: "The loops get tighter as t grows because arg(ζ) increases logarithmically. More zeros appear per unit height, following the density N(T) ~ (T/2π)log(T/2πe).",
      },
    ],
    wasmMode: 0,
    usesOutputBuffer: false,
  },
  {
    id: "partial-sums",
    label: "Cornu Spirals",
    shortLabel: "Cornu",
    icon: "🌸",
    hotkey: "3",
    color: { core: "#ff6bff", edge: "#660066" },
    equation: {
      main: "Sₙ = Σₖ₌₁ᴺ k⁻ˢ",
      sub: "60 terms × 833 curves",
    },
    description:
      "Galaxy of Dirichlet partial sums. Each spiral shows how the series builds toward ζ.",
    cards: [
      {
        title: "Partial Sum Spirals",
        body: "Each curve traces the running sum S₁, S₂, ..., S₆₀ of the Dirichlet series at a specific height t. Each Dirichlet term n⁻ˢ adds a rotating vector, creating a Cornu spiral.",
      },
      {
        title: "Near Zeros",
        body: "At heights where ζ vanishes, all spirals coil inward to the origin — 60 terms conspiring to cancel perfectly. Between zeros, the spirals settle to non-zero limit points.",
      },
      {
        title: "Random Walk Interpretation",
        body: "Each partial sum is a random walk with steps of decreasing magnitude rotating at frequencies log(n). The convergence pattern reveals the deep regularity underlying the primes.",
      },
    ],
    wasmMode: 1,
    usesOutputBuffer: false,
  },
  {
    id: "landscape",
    label: "Zero Landscape",
    shortLabel: "Landscape",
    icon: "🏔️",
    hotkey: "4",
    color: { core: "#ffaa00", edge: "#663300" },
    equation: {
      main: "log|ζ(σ+it)| height field",
      sub: "σ ∈ [0.05, 0.95] · zeros = valleys",
    },
    description:
      "Standing inside the zeta function. Zeros are valleys, the pole at s=1 is a peak.",
    cards: [
      {
        title: "The Terrain",
        body: "A height field where elevation = log|ζ(σ+it)|. The horizontal plane is the (σ, t) domain — the critical strip. Deep valleys are zeros of ζ.",
      },
      {
        title: "The Critical Line",
        body: "The center of the terrain (σ = ½) is the critical line. RH asserts all valleys lie exactly on this central ridge. You can see them align.",
      },
      {
        title: "The Pole",
        body: "Near σ = 1.0, the landscape rises sharply — approaching the pole of ζ at s = 1, where the function diverges to infinity.",
      },
    ],
    wasmMode: 2,
    usesOutputBuffer: false,
  },
  {
    id: "euler-rose",
    label: "Euler Product",
    shortLabel: "Euler",
    icon: "🌹",
    hotkey: "5",
    color: { core: "#ff6b9d", edge: "#660033" },
    equation: {
      main: "∏ₚ (1 − p⁻ˢ)⁻¹",
      sub: "20 primes · convergence",
    },
    description:
      "The multiplicative structure. Watch primes build the zeta function one factor at a time.",
    cards: [
      {
        title: "The Euler Product",
        body: "ζ(s) = ∏ₚ (1 - p⁻ˢ)⁻¹ — each prime p contributes a multiplicative factor. This view shows how the product accumulates through the first 20 primes.",
      },
      {
        title: "Prime Interference",
        body: "Each prime's factor rotates the product by a different angle. At zeros of ζ, these rotations conspire to cancel the entire product — a delicate balance across all primes.",
      },
      {
        title: "Additive vs Multiplicative",
        body: "Compare this with the Cornu view: there, we add terms n⁻ˢ. Here, we multiply factors (1-p⁻ˢ)⁻¹. Both converge to the same function — the bridge between addition and multiplication is the Fundamental Theorem of Arithmetic.",
      },
    ],
    wasmMode: 3,
    usesOutputBuffer: false,
  },
  {
    id: "tower",
    label: "Cayley-Dickson Tower",
    shortLabel: "Tower",
    icon: "🧬",
    hotkey: "6",
    color: { core: "#88ffcc", edge: "#336644" },
    equation: {
      main: "ζ_ℂ · ζ_ℍ · ζ_𝕆 · ζ_𝕊",
      sub: "4 algebraic layers",
    },
    description:
      "Same ζ, four algebraic dimensions. ℂ (2D) → ℍ (4D) → 𝕆 (8D) → 𝕊 (16D).",
    cards: [
      {
        title: "The Tower",
        body: "Four stacked spirals, each computing ζ in a different number system from the Cayley-Dickson construction: Complex (2D), Quaternions (4D), Octonions (8D), Sedenions (16D).",
      },
      {
        title: "Algebraic Consistency",
        body: "All four layers show zeros at the same heights — the zeros of ζ are invariant across algebraic extensions. The structure deepens (wobble increases) but the zeros remain anchored.",
      },
      {
        title: "Non-Associativity",
        body: "Octonions (𝕆) are non-associative, and sedenions (𝕊) are non-alternative. The increasing complexity in higher layers manifests as geometric distortion — but never enough to shift a zero. This is unique to this engine.",
      },
    ],
    wasmMode: 4,
    usesOutputBuffer: false,
  },
];

// Index by ID for O(1) lookup
export const VIZ_MAP = Object.fromEntries(
  VISUALIZATIONS.map((v) => [v.id, v])
) as Record<ViewMode, VisualizationMode>;

// Ordered IDs for prev/next navigation
export const VIZ_ORDER = VISUALIZATIONS.map((v) => v.id);
