"use client";

import { useEffect } from "react";
import { useViewportStore } from "../stores/viewport";
import { VIZ_ORDER, VIZ_MAP } from "../content/visualizations";

/**
 * Global keyboard shortcuts for the viewport.
 * No dependencies — reads directly from Zustand store.
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

      switch (e.key) {
        // ── Mode Selection (1-6) ──
        case "1":
        case "2":
        case "3":
        case "4":
        case "5":
        case "6": {
          const idx = parseInt(e.key) - 1;
          if (idx < VIZ_ORDER.length) {
            store.setViewMode(VIZ_ORDER[idx]);
          }
          break;
        }

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

        // ── Speed ──
        case "=":
        case "+": {
          const speeds = [1, 2, 4, 8];
          const si = speeds.indexOf(store.speed);
          if (si < speeds.length - 1) store.setSpeed(speeds[si + 1]);
          break;
        }
        case "-":
        case "_": {
          const speeds2 = [1, 2, 4, 8];
          const si2 = speeds2.indexOf(store.speed);
          if (si2 > 0) store.setSpeed(speeds2[si2 - 1]);
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
