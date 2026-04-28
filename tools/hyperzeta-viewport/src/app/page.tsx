"use client";

import { useHyperEngine } from "../engine/useHyperEngine";
import { useKeyboard } from "../hud/useKeyboard";
import { Viewport3D } from "../scene/Viewport3D";
import { ChartOverlay } from "../scene/ChartOverlay";
import { Header } from "../hud/Header";
import { ProofBreadcrumb } from "../hud/ProofBreadcrumb";
import { ModeBar } from "../hud/ModeBar";
import { MetricsPanel } from "../hud/MetricsPanel";
import { EquationOverlay } from "../hud/EquationOverlay";
import { CriticalStripMap } from "../hud/CriticalStripMap";
import { CommandPalette } from "../hud/CommandPalette";
import { KeyboardHelp } from "../hud/KeyboardHelp";
import { Toast, useSingularityDetector } from "../hud/Toast";
import { InfoSidebar } from "../sidebar/InfoSidebar";
import { useViewportStore } from "../stores/viewport";

export default function Home() {
  // Boot WASM engine
  useHyperEngine();
  // Global keyboard shortcuts
  useKeyboard();
  // Watch for singularity events
  useSingularityDetector();

  const hudVisible = useViewportStore((s) => s.hudVisible);

  return (
    <main className="viewport-root">
      {/* ── Always visible ── */}
      <Viewport3D />
      <ChartOverlay />
      <Toast />

      {/* ── Zen-mode aware ── */}
      <Header />
      <ProofBreadcrumb />
      {hudVisible && <MetricsPanel />}
      <EquationOverlay />
      {hudVisible && <CriticalStripMap />}

      {/* ── Bottom dock ── */}
      <ModeBar />

      {/* ── Overlays ── */}
      <CommandPalette />
      <KeyboardHelp />
      <InfoSidebar />

      {/* ── Zen mode indicator ── */}
      {!hudVisible && (
        <div className="zen-indicator">
          <span>Zen Mode · Press <kbd>H</kbd> to restore</span>
        </div>
      )}
    </main>
  );
}
