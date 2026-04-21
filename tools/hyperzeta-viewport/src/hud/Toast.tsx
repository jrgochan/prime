"use client";

import { useEffect } from "react";
import { useViewportStore } from "../stores/viewport";

export function Toast() {
  const message = useViewportStore((s) => s.toastMessage);
  const visible = useViewportStore((s) => s.toastVisible);
  const hideToast = useViewportStore((s) => s.hideToast);

  useEffect(() => {
    if (!visible) return;
    const timer = setTimeout(hideToast, 4000);
    return () => clearTimeout(timer);
  }, [visible, hideToast]);

  if (!visible) return null;

  return (
    <div className="toast">
      <span className="toast-icon">✦</span>
      <span>{message}</span>
    </div>
  );
}

/**
 * Hook to detect singularity events and trigger toasts.
 * Should be called from the root component.
 */
export function useSingularityDetector() {
  const showToast = useViewportStore((s) => s.showToast);
  const recordSingularity = useViewportStore((s) => s.recordSingularity);
  const setEngineState = useViewportStore((s) => s.setEngineState);

  useEffect(() => {
    // Subscribe to collapse metric changes
    const unsub = useViewportStore.subscribe(
      (s) => ({ collapse: s.collapse, lambda: s.lambda }),
      ({ collapse, lambda }) => {
        if (lambda > 1.0 && collapse < 0.5) {
          recordSingularity();
          showToast(
            "Particles converged — ζ(s) ≈ 0 near the critical line. A spectral singularity!"
          );
          setTimeout(() => setEngineState("running"), 5000);
        }
      },
      { equalityFn: (a, b) => a.collapse === b.collapse }
    );
    return unsub;
  }, [showToast, recordSingularity, setEngineState]);
}
