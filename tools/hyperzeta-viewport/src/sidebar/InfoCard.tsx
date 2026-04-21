"use client";

import type { ReactNode } from "react";

export function InfoCard({
  title,
  body,
  index,
}: {
  title: string;
  body: ReactNode;
  index: number;
}) {
  return (
    <div className="info-card" style={{ animationDelay: `${index * 150}ms` }}>
      <h3>{title}</h3>
      <p>{body}</p>
    </div>
  );
}
