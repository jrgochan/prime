"use client";

import { useViewportStore } from "../stores/viewport";
import type { ViewMode, CameraPreset } from "../engine/types";

const SPEEDS = [1, 2, 4, 8] as const;

const CAMERA_PRESETS: { key: CameraPreset; icon: string; title: string }[] = [
  { key: "orbital", icon: "🔭", title: "Orbital — auto-rotating" },
  { key: "zero-focus", icon: "🎯", title: "Zero focus — close-up on origin" },
  { key: "side", icon: "📐", title: "Side — spiral structure" },
];

const VIEW_MODES: { key: ViewMode; label: string; title: string }[] = [
  { key: "output", label: "ζ(s)", title: "ζ(s) output — shows collapse near zeros" },
  { key: "spiral", label: "Spiral", title: "Riemann zeta spiral — rings contract at zeros" },
  { key: "partial-sums", label: "Cornu", title: "Partial sum spirals — Dirichlet series building up" },
  { key: "landscape", label: "Landscape", title: "Zero landscape — |ζ(σ+it)| height field" },
  { key: "euler-rose", label: "Euler", title: "Euler product — prime factor accumulation" },
  { key: "tower", label: "Tower", title: "Cayley-Dickson tower — ℂ → ℍ → 𝕆 → 𝕊" },
];

export function ControlsPanel() {
  const speed = useViewportStore((s) => s.speed);
  const setSpeed = useViewportStore((s) => s.setSpeed);
  const viewMode = useViewportStore((s) => s.viewMode);
  const setViewMode = useViewportStore((s) => s.setViewMode);
  const cameraPreset = useViewportStore((s) => s.cameraPreset);
  const setCameraPreset = useViewportStore((s) => s.setCameraPreset);

  return (
    <div className="controls-panel">
      <div className="controls-title">CONTROLS</div>

      <div className="control-group">
        <label className="control-label">Speed</label>
        <div className="speed-buttons">
          {SPEEDS.map((s) => (
            <button
              key={s}
              className={`speed-btn ${speed === s ? "active" : ""}`}
              onClick={() => setSpeed(s)}
            >
              {s}×
            </button>
          ))}
        </div>
      </div>

      <div className="control-group">
        <label className="control-label">View</label>
        <div className="view-buttons view-grid">
          {VIEW_MODES.map((m) => (
            <button
              key={m.key}
              className={`view-btn ${viewMode === m.key ? "active" : ""}`}
              onClick={() => setViewMode(m.key)}
              title={m.title}
            >
              {m.label}
            </button>
          ))}
        </div>
      </div>

      <div className="control-group">
        <label className="control-label">Camera</label>
        <div className="camera-buttons">
          {CAMERA_PRESETS.map((p) => (
            <button
              key={p.key}
              className={`cam-btn ${cameraPreset === p.key ? "active" : ""}`}
              onClick={() => setCameraPreset(p.key)}
              title={p.title}
            >
              {p.icon}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
