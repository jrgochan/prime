"use client";

import { useViewportStore } from "../stores/viewport";
import { VIZ_MAP } from "../content/visualizations";
import { InfoCard } from "./InfoCard";

export function InfoSidebar() {
  const showInfo = useViewportStore((s) => s.showInfo);
  const viewMode = useViewportStore((s) => s.viewMode);

  if (!showInfo) return null;

  const viz = VIZ_MAP[viewMode];

  return (
    <aside className="info-sidebar">
      <h2 className="info-sidebar-title">
        {viz.icon} {viz.label}
      </h2>
      <p className="info-sidebar-desc">{viz.description}</p>
      {viz.cards.map((card, i) => (
        <InfoCard key={card.title} title={card.title} body={card.body} index={i} />
      ))}
      <div className="info-footer">
        <p>
          Part of{" "}
          <a
            href="https://github.com/jrgochan/prime"
            target="_blank"
            rel="noopener noreferrer"
          >
            The Cathedral
          </a>{" "}
          — A Machine-Verified Reduction of the Riemann Hypothesis
        </p>
      </div>
    </aside>
  );
}
