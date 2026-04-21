"use client";

import { useViewportStore } from "../stores/viewport";

const STATUS_TEXT = {
  booting: "Compiling Rust WASM Module…",
  allocating: "Allocating 16D Lattice RAM…",
  running: "Lattice Evolving — Live",
  collapsed: "✦ Spectral Singularity Detected",
} as const;

const STATUS_COLOR = {
  booting: "#ffaa00",
  allocating: "#ffaa00",
  running: "#00ff88",
  collapsed: "#ff6b9d",
} as const;

export function Header() {
  const engineState = useViewportStore((s) => s.engineState);
  const showInfo = useViewportStore((s) => s.showInfo);
  const toggleInfo = useViewportStore((s) => s.toggleInfo);
  const color = STATUS_COLOR[engineState];

  return (
    <header className="viewport-header">
      <div className="header-left">
        <h1 className="title">PROJECT HYPERZETA</h1>
        <div className="status-badge" style={{ borderColor: color }}>
          <span className="status-dot" style={{ backgroundColor: color }} />
          <span style={{ color }}>{STATUS_TEXT[engineState]}</span>
        </div>
      </div>
      <div className="header-right">
        <button
          className="info-toggle"
          onClick={toggleInfo}
          title="Toggle educational info"
        >
          {showInfo ? "✕" : "ℹ"}
        </button>
      </div>
    </header>
  );
}
