"use client";

import { useViewportStore } from "../stores/viewport";

export function EquationOverlay() {
  const lambda = useViewportStore((s) => s.lambda);
  const height = (10 + lambda * 2).toFixed(1);

  return (
    <div className="equation-overlay">
      <div className="equation-main">
        ζ<sub>𝕊</sub>(s) = Σ<sub>n=1</sub>
        <sup>8</sup> n<sup>−s</sup>
      </div>
      <div className="equation-params">
        s ∈ 𝕊<sub>16</sub> &nbsp;·&nbsp; Re(s) = ½ &nbsp;·&nbsp; Im(s) ≈{" "}
        {height}
      </div>
    </div>
  );
}
