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
  /** What the N slider controls in this mode (shown in controls label) */
  nSliderLabel?: string;
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
      {
        title: "👁️ Look For",
        body: "Watch the Collapse Metric in the top-right. When it dips sharply, the cloud contracts — you're witnessing a zero. The breathing rhythm reveals the spacing between zeros.",
      },
    ],
    wasmMode: 0,
    usesOutputBuffer: true,
    nSliderLabel: "Dirichlet terms",
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
      sub: "N-term Dirichlet series",
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
      {
        title: "👁️ Look For",
        body: "Count the pinch points — those are zeros. Drag the N slider up to add more Dirichlet terms: the spiral gets sharper and more defined, like tuning a radio signal.",
      },
    ],
    wasmMode: 0,
    usesOutputBuffer: false,
    nSliderLabel: "Dirichlet terms",
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
      sub: "N terms × 833 curves",
    },
    description:
      "Galaxy of Dirichlet partial sums. Each spiral shows how the series builds toward ζ.",
    cards: [
      {
        title: "Partial Sum Spirals",
        body: "Each curve traces the running sum S₁, S₂, ..., Sₙ of the Dirichlet series at a specific height t. Each term n⁻ˢ adds a rotating vector, creating a Cornu spiral.",
      },
      {
        title: "Near Zeros",
        body: "At heights where ζ vanishes, all spirals coil inward to the origin — every term conspiring to cancel perfectly. Between zeros, the spirals settle to non-zero limit points.",
      },
      {
        title: "Random Walk Interpretation",
        body: "Each partial sum is a random walk with steps of decreasing magnitude rotating at frequencies log(n). The convergence pattern reveals the deep regularity underlying the primes.",
      },
      {
        title: "👁️ Look For",
        body: "Increase N to see more terms in each spiral. As N grows, the spirals tighten — the Dirichlet series converges. The 'galaxy center' is ζ(½+it): where all spirals aim.",
      },
    ],
    wasmMode: 1,
    usesOutputBuffer: false,
    nSliderLabel: "terms per spiral",
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
      {
        title: "👁️ Look For",
        body: "Are the valley floors centered on the middle ridge? That's RH in action. Increase N for a higher-resolution terrain. Notice how the pole (right edge) towers over everything.",
      },
    ],
    wasmMode: 2,
    usesOutputBuffer: false,
    nSliderLabel: "Dirichlet terms",
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
      sub: "20 primes · multiplicative structure",
    },
    description:
      "The multiplicative structure. Watch primes build the zeta function one factor at a time.",
    cards: [
      {
        title: "The Euler Product",
        body: "ζ(s) = ∏ₚ (1 − p⁻ˢ)⁻¹ — each prime p contributes a multiplicative factor. This view shows how the product accumulates through the first 20 primes.",
      },
      {
        title: "Additive vs Multiplicative",
        body: "Compare with the Cornu view: there, we add terms n⁻ˢ. Here, we multiply factors (1−p⁻ˢ)⁻¹. Both converge to the same ζ — the bridge between addition and multiplication is the Fundamental Theorem of Arithmetic.",
      },
      {
        title: "Prime Interference",
        body: "Each prime's factor rotates the product by a different angle. At zeros of ζ, these rotations conspire to cancel the entire product — a delicate balance across all primes.",
      },
      {
        title: "👁️ Look For",
        body: "The rose petals have different radii — larger petals come from small primes (2, 3, 5) which contribute the strongest factors. Later primes add fine structure.",
      },
    ],
    wasmMode: 3,
    usesOutputBuffer: false,
    nSliderLabel: "Dirichlet terms",
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
        body: "Four stacked spirals, each computing ζ in a different number system: Complex (2D), Quaternions (4D), Octonions (8D), Sedenions (16D). Each layer adds algebraic dimensions.",
      },
      {
        title: "Algebraic Consistency",
        body: "All four layers show zeros at the same heights — the zeros of ζ are invariant across algebraic extensions. The tower deepens but the zeros remain anchored.",
      },
      {
        title: "Loss of Structure",
        body: "ℂ and ℍ are division algebras (no zero divisors). 𝕆 loses associativity. 𝕊 has zero divisors — elements that multiply to zero. Watch the top layer: its wobble reveals the algebraic chaos.",
      },
      {
        title: "👁️ Look For",
        body: "The bottom spiral (ℂ) is cleanest. Each layer up adds more 'noise' from higher dimensions. But the pinch points (zeros) stay aligned vertically. That's the deep invariant.",
      },
    ],
    wasmMode: 4,
    usesOutputBuffer: false,
    nSliderLabel: "Dirichlet terms",
  },
  {
    id: "waves",
    label: "Explicit Formula",
    shortLabel: "Waves",
    icon: "🌊",
    hotkey: "7",
    color: { core: "#44ddff", edge: "#114455" },
    equation: {
      main: "π(x) ≈ Li(x) − Σᵨ Li(xᵅ)",
      sub: "N zero correction waves (up to 200)",
    },
    description:
      "Watch primes emerge from wave interference. Each zero contributes a correction wave.",
    cards: [
      {
        title: "The Explicit Formula",
        body: "The prime counting function π(x) can be written as a smooth term Li(x) minus a sum over zeros of ζ. Each zero ρ = ½ + iγ contributes an oscillating correction − Li(x^ρ).",
      },
      {
        title: "Wave Superposition",
        body: "Drag the N slider to add more zeros. With 4 zeros, you get a rough outline. With 50, the prime staircase sharpens. At 200, it's razor-sharp. This is the most direct proof that zeros control primes.",
      },
      {
        title: "The Prime Staircase",
        body: "π(x) jumps by 1 at each prime: 2, 3, 5, 7, 11, 13... The smooth curve Li(x) approximates this. The corrections from zeros sculpt the smooth curve into the exact staircase.",
      },
      {
        title: "👁️ Look For",
        body: "Start with N=4: the curve barely hints at primes. Slowly drag to 200: watch the staircase emerge step by step. Each step is a prime number, built from wave interference. This is Riemann's original insight from 1859.",
      },
      {
        title: "🏛️ Cathedral Connection",
        body: "The zeros used here come from the LMFDB database (200 entries). The Cathedral's Lean proofs formalize that these zeros must lie on the critical line — if any zero strayed off Re(s)=½, the staircase would develop impossible errors.",
      },
    ],
    wasmMode: 5,
    usesOutputBuffer: false,
    nSliderLabel: "correction zeros",
  },
  {
    id: "mirror",
    label: "Functional Equation",
    shortLabel: "Mirror",
    icon: "🪞",
    hotkey: "8",
    color: { core: "#bb88ff", edge: "#442266" },
    equation: {
      main: "ζ(s) = χ(s) · ζ(1−s)",
      sub: "Critical line = mirror plane",
    },
    description:
      "The symmetry of ζ. Both sides of the critical strip reflected through σ = ½.",
    cards: [
      {
        title: "The Reflection",
        body: "The functional equation ζ(s) = χ(s)·ζ(1−s) means the left and right halves of the critical strip are mirror images. The critical line σ = ½ is the mirror plane.",
      },
      {
        title: "Why σ = ½?",
        body: "This symmetry is why RH talks about σ = ½ specifically. The equation forces zeros to come in reflected pairs: if ζ(σ+it) = 0, then ζ(1−σ+it) = 0. Unless σ = ½ — then the zero IS its own reflection.",
      },
      {
        title: "The χ Factor",
        body: "χ(s) = 2ˢπˢ⁻¹ sin(πs/2) Γ(1−s) is the gamma factor that mediates the reflection. It never vanishes in the critical strip, so ζ(s)=0 iff ζ(1−s)=0.",
      },
      {
        title: "👁️ Look For",
        body: "The two mirrored curves breathe in sync. Watch how log|ζ| on the left matches ζ on the right, reflected through the center. The mirror plane is where zeros sit.",
      },
    ],
    wasmMode: 6,
    usesOutputBuffer: false,
    nSliderLabel: "Dirichlet terms",
  },
  {
    id: "gue",
    label: "Random Matrix",
    shortLabel: "GUE",
    icon: "🎲",
    hotkey: "9",
    color: { core: "#ffdd44", edge: "#665500" },
    equation: {
      main: "P(s) ∼ GUE pair correlation",
      sub: "Zeta zeros vs random eigenvalues",
    },
    description:
      "The Montgomery-Odlyzko law. Zeta zero spacings match random matrix eigenvalues.",
    cards: [
      {
        title: "Two Clouds",
        body: "Left cloud: spacings between consecutive zeta zeros (from the LMFDB table). Right cloud: eigenvalue spacings from the Gaussian Unitary Ensemble (simulated). They are statistically identical.",
      },
      {
        title: "The Montgomery-Odlyzko Law",
        body: "In 1973, Montgomery showed that zeta zero pair correlations match GUE statistics. Odlyzko confirmed with millions of zeros in 1987. It's the deepest known connection between number theory and quantum physics.",
      },
      {
        title: "A Hidden Quantum System?",
        body: "GUE matrices model quantum systems with time-reversal symmetry breaking. That zeta zeros behave like quantum eigenvalues suggests an undiscovered self-adjoint operator whose spectrum IS the zeros of ζ. The Hilbert-Pólya conjecture made real.",
      },
      {
        title: "👁️ Look For",
        body: "Compare the two clouds: the left has the same statistical 'shape' as the right. This is not random — it's one of the great mysteries of mathematics. The left cloud is pure number theory; the right is pure physics.",
      },
    ],
    wasmMode: 7,
    usesOutputBuffer: false,
  },
  {
    id: "mertens",
    label: "Mertens Turbulence",
    shortLabel: "Mertens",
    icon: "🌪️",
    hotkey: "0",
    color: { core: "#ff8844", edge: "#663311" },
    equation: {
      main: "M(x) = Σ μ(n)",
      sub: "RH ⟺ |M(x)| < x^(½+ε)",
    },
    description:
      "The Mertens function as a turbulent 3D walk. RH keeps it bounded.",
    cards: [
      {
        title: "The Möbius Function",
        body: "μ(n) = (−1)^k if n has k distinct prime factors, 0 if n has a squared factor. It oscillates wildly between −1, 0, and 1 — the multiplicative heart of the primes.",
      },
      {
        title: "Mertens Sum",
        body: "M(x) = Σ_{n≤x} μ(n) wanders like a random walk. The Riemann Hypothesis is EQUIVALENT to |M(x)| < x^(½+ε) — the walk can't stray too far from the origin.",
      },
      {
        title: "Tighter Than Expected",
        body: "Under RH, |M(x)| = O(x^{1/2+ε}). The Cathedral proves that this bound, combined with the Mellin Crown architecture, drives the Nyman-Beurling distance d²_N → 0 — the formal equivalence.",
      },
      {
        title: "👁️ Look For",
        body: "The walk looks chaotic but it's secretly constrained. Watch how the trail never escapes too far — it always curves back. That bounded wandering IS the Riemann Hypothesis, made visible.",
      },
      {
        title: "🏛️ Cathedral Connection",
        body: "The Mertens function connects to the Cathedral through the Mellin transform: the Mellin variance of the BD residual on the critical line (crown axiom 1) controls the covariance of the log-Möbius sums, which in turn bound this random walk.",
      },
    ],
    wasmMode: 8,
    usesOutputBuffer: false,
  },
  {
    id: "spectral-gap",
    label: "Spectral Gap",
    shortLabel: "Gap",
    icon: "🏛️",
    hotkey: "-",
    color: { core: "#66ffaa", edge: "#225533" },
    equation: {
      main: "λ_min(G_N) > 0",
      sub: "Gram matrix · Nyman-Beurling basis",
    },
    description:
      "From the Cathedral proof. The Gram matrix eigenvalue surface — it has a floor.",
    cards: [
      {
        title: "The Spectral Gap",
        body: "The Gram matrix G_N has entries G(j,k) = ⟨h_j, h_k⟩ where h_k(x) = {1/(kx)} is the Báez-Duarte basis. Its smallest eigenvalue λ_min(N) must stay positive as N → ∞.",
      },
      {
        title: "The d² Distance",
        body: "d²_N = 1 − b^T G⁻¹ b is the Nyman-Beurling distance. RH is equivalent to d²_N → 0 as N → ∞. The spectral gap ensures the Gram matrix stays invertible.",
      },
      {
        title: "The Surface",
        body: "Height = log(λ_min) plotted over (N, σ). The surface never touches zero — that floor is the spectral gap that the entire proof chain rests on.",
      },
      {
        title: "👁️ Look For",
        body: "Watch for the glowing floor. It shimmers but never breaks. If this surface ever touched zero, the entire Cathedral proof would collapse. It doesn't.",
      },
      {
        title: "🏛️ Cathedral Connection",
        body: "This IS the Cathedral. The Gram matrix is computed by zeta::nyman_beurling, the eigenvalue structure by the Parseval Bridge, and the two crown axioms (Mellin variance + Hadamard zero bound) ensure the floor is sturdy. What you see is the proof, rendered.",
      },
    ],
    wasmMode: 9,
    usesOutputBuffer: false,
    nSliderLabel: "Dirichlet terms",
  },
  {
    id: "harmonics",
    label: "Prime Harmonics",
    shortLabel: "Harmonics",
    icon: "🎵",
    hotkey: "=",
    color: { core: "#ff99dd", edge: "#662244" },
    equation: {
      main: "Σₚ sin(ln(p) · θ) / √p",
      sub: "15 primes · standing waves on cylinder",
    },
    description:
      "Number theory as music. Each prime is a note at frequency log(p), amplitude 1/√p.",
    cards: [
      {
        title: "Prime Notes",
        body: "Each prime p generates a standing wave at frequency log(p) with amplitude 1/√p. Lower primes are louder; p=2 is the bass note, p=47 is a high harmonic.",
      },
      {
        title: "The Cylinder",
        body: "Waves are wrapped around a cylinder — each ring is one prime's contribution. The vertical stack shows how 15 primes create an increasingly complex resonance pattern through superposition.",
      },
      {
        title: "Fourier Analysis of Primes",
        body: "The Riemann zeta function IS the Fourier transform of the prime distribution. These standing waves are the individual Fourier modes. Where they cancel is where zeros live.",
      },
      {
        title: "👁️ Look For",
        body: "The lowest ring (p=2) oscillates slowly. Higher rings oscillate faster. Where many rings align, the combined amplitude peaks — those peaks correspond to actual prime locations in the number line.",
      },
    ],
    wasmMode: 10,
    usesOutputBuffer: false,
    nSliderLabel: "Dirichlet terms",
  },
];

// Index by ID for O(1) lookup
export const VIZ_MAP = Object.fromEntries(
  VISUALIZATIONS.map((v) => [v.id, v])
) as Record<ViewMode, VisualizationMode>;

// Ordered IDs for prev/next navigation
export const VIZ_ORDER = VISUALIZATIONS.map((v) => v.id);
