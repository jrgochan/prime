"use client";

import { useViewportStore } from "../stores/viewport";
import { VIZ_MAP, MODE_GROUPS } from "../content/visualizations";

/**
 * ProofBreadcrumb — shows the Cathedral proof chain for the current mode.
 * Example: 🔬 Analysis › White/Scattering.lean › PROVED
 */
export function ProofBreadcrumb() {
  const viewMode = useViewportStore((s) => s.viewMode);
  const hudVisible = useViewportStore((s) => s.hudVisible);

  if (!hudVisible) return null;

  const viz = VIZ_MAP[viewMode];
  if (!viz) return null;

  const group = MODE_GROUPS.find((g) => g.id === viz.group);
  const proof = viz.proof;

  // Only show breadcrumb for modes with a proof mapping
  if (!group && !proof) return null;

  return (
    <div className="proof-breadcrumb">
      {group && (
        <span
          className="proof-breadcrumb-group"
          style={{ borderColor: group.color + "30" }}
        >
          <span>{group.icon}</span>
          <span style={{ color: group.color }}>{group.label}</span>
        </span>
      )}

      {proof && (
        <>
          <span className="proof-breadcrumb-sep">›</span>
          <span className="proof-breadcrumb-file">{proof.leanFile}</span>
          {proof.theoremName && (
            <>
              <span className="proof-breadcrumb-sep">›</span>
              <span>{proof.theoremName}</span>
            </>
          )}
          <span
            className={`proof-breadcrumb-status proof-breadcrumb-status--${proof.status}`}
          >
            {proof.status.toUpperCase()}
          </span>
        </>
      )}
    </div>
  );
}
