"use client";

import { useViewportStore } from "../stores/viewport";
import type { ViewMode } from "../engine/types";

const EQUATIONS: Record<ViewMode, { main: string; sub: string }> = {
  output: {
    main: "ζ_𝕊(s) = Σₙ₌₁⁸ n⁻ˢ",
    sub: "s ∈ 𝕊₁₆ · Re(s) = ½",
  },
  spiral: {
    main: "ζ(½+it) → (Re, t, Im)",
    sub: "50-term Dirichlet series",
  },
  "partial-sums": {
    main: "Sₙ = Σₖ₌₁ᴺ k⁻ˢ",
    sub: "Cornu spirals · 60 terms × 833 curves",
  },
  landscape: {
    main: "log|ζ(σ+it)| height field",
    sub: "σ ∈ [0.05, 0.95] · zeros = valleys",
  },
  "euler-rose": {
    main: "∏ₚ (1 − p⁻ˢ)⁻¹",
    sub: "20 primes · Euler product convergence",
  },
  tower: {
    main: "ζ_ℂ · ζ_ℍ · ζ_𝕆 · ζ_𝕊",
    sub: "Cayley-Dickson tower · 4 layers",
  },
};

export function EquationOverlay() {
  const viewMode = useViewportStore((s) => s.viewMode);
  const lambda = useViewportStore((s) => s.lambda);
  const height = (10 + lambda * 2).toFixed(1);
  const eq = EQUATIONS[viewMode];

  return (
    <div className="equation-overlay">
      <div className="equation-main">{eq.main}</div>
      <div className="equation-params">
        {eq.sub} · Im(s) ≈ {height}
      </div>
    </div>
  );
}
