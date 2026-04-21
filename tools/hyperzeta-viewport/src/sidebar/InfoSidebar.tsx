"use client";

import { useViewportStore } from "../stores/viewport";
import { EDUCATIONAL_CARDS } from "../content/cards";
import { InfoCard } from "./InfoCard";

export function InfoSidebar() {
  const showInfo = useViewportStore((s) => s.showInfo);
  if (!showInfo) return null;

  return (
    <aside className="info-sidebar">
      <h2 className="info-sidebar-title">About This Visualization</h2>
      {EDUCATIONAL_CARDS.map((card, i) => (
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
