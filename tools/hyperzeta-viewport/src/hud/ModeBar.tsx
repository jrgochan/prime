"use client";

import { useCallback } from "react";
import { useViewportStore } from "../stores/viewport";
import {
  VIZ_MAP,
  VIZ_ORDER,
  MODE_GROUPS,
  VISUALIZATIONS,
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
  const zetaTerms = useViewportStore((s) => s.zetaTerms);
  const setZetaTerms = useViewportStore((s) => s.setZetaTerms);

  const handleParticleSlider = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const t = parseFloat(e.target.value);
      const count = Math.round(1000 * Math.pow(500, t));
      setParticleCount(count);
    },
    [setParticleCount]
  );

  const handleTermsSlider = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const t = parseFloat(e.target.value);
      const n = Math.round(4 * Math.pow(50, t));
      setZetaTerms(n);
    },
    [setZetaTerms]
  );

  const cycleSpeed = useCallback(() => {
    const i = SPEEDS.indexOf(speed as (typeof SPEEDS)[number]);
    setSpeed(SPEEDS[(i + 1) % SPEEDS.length]);
  }, [speed, setSpeed]);

  const sliderValue = Math.log(particleCount / 1000) / Math.log(500);
  const termsSliderValue = Math.log(zetaTerms / 4) / Math.log(50);

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
        {/* Playback controls */}
        <div className="dock-group">
          <button
            className={`dock-btn ${paused ? "dock-btn--amber" : ""}`}
            onClick={togglePaused}
            title={paused ? "Resume (Space)" : "Pause (Space)"}
          >
            {paused ? "▶" : "⏸"}
          </button>
          <button
            className="dock-btn dock-btn--speed"
            onClick={cycleSpeed}
            title="Click to cycle speed"
          >
            {speed}×
          </button>
        </div>

        {/* Particle slider */}
        <div className="dock-slider-group">
          <span className="dock-slider-label">Particles</span>
          <input
            type="range"
            min="0"
            max="1"
            step="0.005"
            value={sliderValue}
            onChange={handleParticleSlider}
            className="dock-slider dock-slider--green"
          />
          <span className="dock-slider-value">{formatCount(particleCount)}</span>
        </div>

        {/* Zeta terms slider — tooltip shows what N means for this mode */}
        <div className="dock-slider-group">
          <span className="dock-slider-label dock-slider-label--cyan" title={viz.nSliderLabel || "N terms"}>N</span>
          <input
            type="range"
            min="0"
            max="1"
            step="0.005"
            value={termsSliderValue}
            onChange={handleTermsSlider}
            className="dock-slider dock-slider--cyan"
          />
          <span className="dock-slider-value">{zetaTerms}</span>
        </div>
      </div>

      <div className="mode-bar-center">
        {/* Group tabs */}
        <div className="mode-group-tabs">
          {MODE_GROUPS.map((g) => {
            const isActive = viz.group === g.id;
            return (
              <button
                key={g.id}
                className={`mode-group-tab${isActive ? " active" : ""}`}
                style={isActive ? { color: g.color, borderColor: g.color + "40" } : undefined}
                onClick={() => {
                  // Jump to first mode in this group
                  const first = VISUALIZATIONS.find((v) => v.group === g.id);
                  if (first) setViewMode(first.id);
                }}
                title={g.label}
              >
                {g.icon} {g.label}
              </button>
            );
          })}
        </div>

        {/* Mode navigator */}
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
