"use client";

import { useViewportStore } from "../stores/viewport";

const SHORTCUTS = [
  { keys: ["1", "–", "6"], action: "Switch visualization mode" },
  { keys: ["←", "→"], action: "Previous / Next mode" },
  { keys: ["Tab"], action: "Open command palette" },
  { keys: ["Space"], action: "Pause / Resume" },
  { keys: ["+", "−"], action: "Speed up / Slow down" },
  { keys: ["H"], action: "Toggle zen mode (hide HUD)" },
  { keys: ["I"], action: "Toggle info sidebar" },
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
