"use client";

import { useCallback } from "react";
import { useViewportStore } from "../stores/viewport";
import {
  VIZ_MAP,
  VIZ_ORDER,
} from "../content/visualizations";

const SPEEDS = [1, 2, 4, 8] as const;

function formatCount(n: number): string {
  if (n >= 1000) return `${(n / 1000).toFixed(0)}K`;
  return n.toString();
}

export function ModeBar() {
  const viewMode = useViewportStore((s) => s.viewMode);
  const setViewMode = useViewportStore((s) => s.setViewMode);
  const speed = useViewportStore((s) => s.speed);
  const setSpeed = useViewportStore((s) => s.setSpeed);
  const paused = useViewportStore((s) => s.paused);
  const togglePaused = useViewportStore((s) => s.togglePaused);
  const togglePalette = useViewportStore((s) => s.togglePalette);
  const hudVisible = useViewportStore((s) => s.hudVisible);
  const particleCount = useViewportStore((s) => s.particleCount);
  const setParticleCount = useViewportStore((s) => s.setParticleCount);

  const handleSlider = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      // Exponential slider: maps 0-1 → 1K-500K
      const t = parseFloat(e.target.value);
      const count = Math.round(1000 * Math.pow(500, t));
      setParticleCount(count);
    },
    [setParticleCount]
  );

  // Reverse: count → slider value (0-1)
  const sliderValue = Math.log(particleCount / 1000) / Math.log(500);

  if (!hudVisible) return null;

  const viz = VIZ_MAP[viewMode];
  const curIdx = VIZ_ORDER.indexOf(viewMode);
  const total = VIZ_ORDER.length;

  const prevMode = () => {
    const prev = VIZ_ORDER[(curIdx - 1 + total) % total];
    setViewMode(prev);
  };

  const nextMode = () => {
    const next = VIZ_ORDER[(curIdx + 1) % total];
    setViewMode(next);
  };

  return (
    <div className="mode-bar">
      <div className="mode-bar-left">
        <button
          className={`mode-bar-btn pause-btn ${paused ? "active" : ""}`}
          onClick={togglePaused}
          title={paused ? "Resume (Space)" : "Pause (Space)"}
        >
          {paused ? "▶" : "⏸"}
        </button>
        <div className="mode-bar-speed">
          {SPEEDS.map((s) => (
            <button
              key={s}
              className={`mode-bar-speed-btn ${speed === s ? "active" : ""}`}
              onClick={() => setSpeed(s)}
              title={`${s}× speed`}
            >
              {s}×
            </button>
          ))}
        </div>
        <div className="mode-bar-particles" title="Particle count">
          <input
            type="range"
            min="0"
            max="1"
            step="0.01"
            value={sliderValue}
            onChange={handleSlider}
            className="particle-slider"
          />
          <span className="particle-label">{formatCount(particleCount)}</span>
        </div>
      </div>

      <div className="mode-bar-center">
        <button className="mode-bar-nav" onClick={prevMode} title="Previous (←)">
          ‹
        </button>
        <button
          className="mode-bar-current"
          onClick={togglePalette}
          title="Open visualizations (Tab)"
          style={{ borderColor: viz.color.core + "40" }}
        >
          <span className="mode-bar-icon">{viz.icon}</span>
          <span className="mode-bar-label" style={{ color: viz.color.core }}>
            {viz.label}
          </span>
          <span className="mode-bar-index">
            {curIdx + 1}/{total}
          </span>
        </button>
        <button className="mode-bar-nav" onClick={nextMode} title="Next (→)">
          ›
        </button>
      </div>

      <div className="mode-bar-right">
        <span className="mode-bar-hint">
          <kbd>Tab</kbd> palette · <kbd>?</kbd> help · <kbd>H</kbd> zen
        </span>
      </div>
    </div>
  );
}
