"use client";

import { useEffect } from "react";
import { useViewportStore } from "../stores/viewport";
import { VISUALIZATIONS, VIZ_ORDER } from "../content/visualizations";

// Build hotkey → mode map from registry
const HOTKEY_MAP = new Map(
  VISUALIZATIONS.map((v) => [v.hotkey, v.id])
);

/**
 * Global keyboard shortcuts for the viewport.
 * Hotkeys are read from the Visualization Registry — adding a mode
 * with a hotkey automatically registers it here.
 */
export function useKeyboard() {
  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      // Don't capture if user is typing in an input
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement
      )
        return;

      const store = useViewportStore.getState();

      // ── Registry Hotkeys (1-9, 0, -, =) ──
      const hotkeyMode = HOTKEY_MAP.get(e.key);
      if (hotkeyMode) {
        store.setViewMode(hotkeyMode);
        return;
      }

      switch (e.key) {
        // ── Prev/Next Mode ──
        case "ArrowLeft": {
          if (store.paletteOpen) return;
          const curIdx = VIZ_ORDER.indexOf(store.viewMode);
          const prev =
            VIZ_ORDER[(curIdx - 1 + VIZ_ORDER.length) % VIZ_ORDER.length];
          store.setViewMode(prev);
          break;
        }
        case "ArrowRight": {
          if (store.paletteOpen) return;
          const curIdx2 = VIZ_ORDER.indexOf(store.viewMode);
          const next = VIZ_ORDER[(curIdx2 + 1) % VIZ_ORDER.length];
          store.setViewMode(next);
          break;
        }

        // ── Pause / Resume ──
        case " ":
          e.preventDefault();
          store.togglePaused();
          break;

        // ── HUD Visibility ──
        case "h":
        case "H":
          store.toggleHud();
          break;

        // ── Info Sidebar ──
        case "i":
        case "I":
          store.toggleInfo();
          break;

        // ── Command Palette ──
        case "Tab":
          e.preventDefault();
          store.togglePalette();
          break;

        case "Escape":
          if (store.paletteOpen) store.togglePalette();
          if (store.showHelp) store.toggleHelp();
          break;

        // ── Help ──
        case "?":
          store.toggleHelp();
          break;
      }
    }

    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, []);
}
