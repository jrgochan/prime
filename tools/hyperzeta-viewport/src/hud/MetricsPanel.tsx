"use client";

import { useViewportStore } from "../stores/viewport";

function MetricBar({
  label,
  value,
  max,
  color,
}: {
  label: string;
  value: number;
  max: number;
  color: string;
}) {
  const pct = Math.min((value / max) * 100, 100);
  return (
    <div className="metric-row">
      <span className="metric-label">{label}</span>
      <div className="metric-bar-track">
        <div
          className="metric-bar-fill"
          style={{ width: `${pct}%`, backgroundColor: color }}
        />
      </div>
      <span className="metric-value">{value.toFixed(3)}</span>
    </div>
  );
}

export function MetricsPanel() {
  const collapse = useViewportStore((s) => s.collapse);
  const lambda = useViewportStore((s) => s.lambda);
  const singularityCount = useViewportStore((s) => s.singularityCount);
  const particleCount = useViewportStore((s) => s.particleCount);

  return (
    <div className="metrics-panel">
      <div className="metrics-title">LIVE TELEMETRY</div>
      <MetricBar
        label="Collapse"
        value={collapse}
        max={2}
        color={collapse < 0.5 ? "#ff6b9d" : "#00ff88"}
      />
      <MetricBar label="λ (time)" value={lambda} max={10} color="#00ccff" />
      <div className="metric-row" style={{ marginTop: "8px" }}>
        <span className="metric-label">Singularities</span>
        <span className="metric-value singularity-count">
          {singularityCount}
        </span>
      </div>
      <div className="metric-row">
        <span className="metric-label">Particles</span>
        <span className="metric-value">{particleCount.toLocaleString()}</span>
      </div>
      <div className="metric-row">
        <span className="metric-label">Engine</span>
        <span className="metric-value">Rust → WASM</span>
      </div>
    </div>
  );
}
