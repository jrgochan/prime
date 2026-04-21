import { create } from "zustand";
import { subscribeWithSelector } from "zustand/middleware";
import type {
  ViewMode,
  CameraPreset,
  EngineState,
  HyperSystem,
} from "../engine/types";
import { VIEW_MODE_WASM } from "../engine/types";

interface ViewportState {
  // ── Engine ──
  engineState: EngineState;
  hyperSystem: HyperSystem | null;
  collapse: number;
  lambda: number;
  singularityCount: number;

  // ── Controls ──
  speed: number;
  viewMode: ViewMode;
  cameraPreset: CameraPreset;
  showInfo: boolean;

  // ── Toast ──
  toastMessage: string;
  toastVisible: boolean;

  // ── Actions ──
  setEngineState: (state: EngineState) => void;
  setHyperSystem: (system: HyperSystem) => void;
  updateMetrics: (collapse: number, lambda: number) => void;
  recordSingularity: () => void;
  setSpeed: (speed: number) => void;
  setViewMode: (mode: ViewMode) => void;
  setCameraPreset: (preset: CameraPreset) => void;
  toggleInfo: () => void;
  showToast: (message: string) => void;
  hideToast: () => void;
}

export const useViewportStore = create<ViewportState>()(
  subscribeWithSelector((set) => ({
    // ── State ──
    engineState: "booting",
    hyperSystem: null,
    collapse: 1.0,
    lambda: 0.0,
    singularityCount: 0,

    speed: 1,
    viewMode: "output",
    cameraPreset: "orbital",
    showInfo: false,

    toastMessage: "",
    toastVisible: false,

    // ── Actions ──
    setEngineState: (engineState) => set({ engineState }),

    setHyperSystem: (hyperSystem) =>
      set({ hyperSystem, engineState: "running" }),

    updateMetrics: (collapse, lambda) => set({ collapse, lambda }),

    recordSingularity: () =>
      set((state) => ({
        singularityCount: state.singularityCount + 1,
        engineState: "collapsed" as EngineState,
      })),

    setSpeed: (speed) => set({ speed }),
    setViewMode: (viewMode) => {
      // Tell the WASM engine which visualization to compute
      const system = useViewportStore.getState().hyperSystem;
      if (system?.engine && viewMode !== "output") {
        system.engine.set_view_mode(VIEW_MODE_WASM[viewMode]);
      }
      set({ viewMode });
    },
    setCameraPreset: (cameraPreset) => set({ cameraPreset }),
    toggleInfo: () => set((state) => ({ showInfo: !state.showInfo })),

    showToast: (toastMessage) => set({ toastMessage, toastVisible: true }),
    hideToast: () => set({ toastVisible: false }),
  }))
);
