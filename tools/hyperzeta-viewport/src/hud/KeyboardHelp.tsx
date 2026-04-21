"use client";

import { useViewportStore } from "../stores/viewport";

const SHORTCUTS = [
  { keys: ["1", "–", "9"], action: "Modes 1–9" },
  { keys: ["0"], action: "Mertens Turbulence" },
  { keys: ["-"], action: "Spectral Gap" },
  { keys: ["="], action: "Prime Harmonics" },
  { keys: ["←", "→"], action: "Cycle modes" },
  { keys: ["Tab"], action: "Command palette" },
  { keys: ["Space"], action: "Pause / Resume" },
  { keys: ["H"], action: "Zen mode (hide HUD)" },
  { keys: ["I"], action: "Info sidebar" },
  { keys: ["?"], action: "This help screen" },
  { keys: ["Esc"], action: "Close overlays" },
];

export function KeyboardHelp() {
  const show = useViewportStore((s) => s.showHelp);
  const toggle = useViewportStore((s) => s.toggleHelp);

  if (!show) return null;

  return (
    <div className="help-backdrop" onClick={toggle}>
      <div className="help-container" onClick={(e) => e.stopPropagation()}>
        <div className="help-title">KEYBOARD SHORTCUTS</div>
        <div className="help-list">
          {SHORTCUTS.map((s, i) => (
            <div key={i} className="help-row">
              <div className="help-keys">
                {s.keys.map((k) => (
                  <kbd key={k} className="help-kbd">
                    {k}
                  </kbd>
                ))}
              </div>
              <span className="help-action">{s.action}</span>
            </div>
          ))}
        </div>
        <div className="help-footer">Press <kbd>?</kbd> or <kbd>Esc</kbd> to close</div>
      </div>
    </div>
  );
}
