"use client";

import { useViewportStore } from "../stores/viewport";

const MILESTONES = [
  { at: 0, label: "Random Init" },
  { at: 15, label: "Spiral Forms" },
  { at: 40, label: "Structure" },
  { at: 70, label: "Convergence" },
  { at: 95, label: "Singularity" },
];

export function PhaseTimeline() {
  const lambda = useViewportStore((s) => s.lambda);
  const pct = Math.min((lambda / 10) * 100, 100);

  return (
    <div className="timeline-container">
      <div className="phase-timeline">
        <div className="phase-track">
          <div className="phase-fill" style={{ width: `${pct}%` }} />
          {MILESTONES.map((m) => (
            <div
              key={m.label}
              className={`phase-milestone ${pct >= m.at ? "active" : ""}`}
              style={{ left: `${m.at}%` }}
            >
              <div className="phase-dot" />
              <span className="phase-label">{m.label}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
