"use client";

import { useViewportStore } from "../stores/viewport";
import { VISUALIZATIONS } from "../content/visualizations";

export function CommandPalette() {
  const open = useViewportStore((s) => s.paletteOpen);
  const viewMode = useViewportStore((s) => s.viewMode);
  const setViewMode = useViewportStore((s) => s.setViewMode);
  const togglePalette = useViewportStore((s) => s.togglePalette);

  if (!open) return null;

  return (
    <div className="palette-backdrop" onClick={togglePalette}>
      <div className="palette-container" onClick={(e) => e.stopPropagation()}>
        <div className="palette-header">
          <span className="palette-title">SELECT VISUALIZATION</span>
          <span className="palette-hint">
            Press <kbd>1</kbd>–<kbd>6</kbd> or click · <kbd>Esc</kbd> to close
          </span>
        </div>
        <div className="palette-grid">
          {VISUALIZATIONS.map((viz) => (
            <button
              key={viz.id}
              className={`palette-card ${viewMode === viz.id ? "active" : ""}`}
              onClick={() => setViewMode(viz.id)}
            >
              <div className="palette-card-icon">{viz.icon}</div>
              <div className="palette-card-body">
                <div className="palette-card-label">{viz.label}</div>
                <div className="palette-card-desc">{viz.description}</div>
              </div>
              <kbd className="palette-card-hotkey">{viz.hotkey}</kbd>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
