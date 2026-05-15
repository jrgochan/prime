"use client";

import { useViewportStore } from "../stores/viewport";

export function CriticalStripMap() {
  const lambda = useViewportStore((s) => s.lambda);
  const height = 10 + lambda * 2;
  const yPct = Math.min((height / 30) * 100, 100);

  return (
    <div className="minimap">
      <div className="minimap-title">CRITICAL STRIP</div>
      <div className="minimap-strip">
        <div className="minimap-critical-line" />
        <div className="minimap-dot" style={{ bottom: `${yPct}%` }} />
        <div className="minimap-label-left">0</div>
        <div className="minimap-label-right">1</div>
        <div className="minimap-label-re">Re(s)</div>
        <div
          className="minimap-label-im"
          style={{ bottom: `${Math.min(yPct + 3, 90)}%` }}
        >
          t={height.toFixed(1)}
        </div>
      </div>
    </div>
  );
}
