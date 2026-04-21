"use client";

import { useState } from "react";
import { GLOSSARY } from "../content/glossary";

export function Glossary({ term }: { term: string }) {
  const [show, setShow] = useState(false);
  const def = GLOSSARY[term];
  if (!def) return <span>{term}</span>;

  return (
    <span
      className="glossary-term"
      onMouseEnter={() => setShow(true)}
      onMouseLeave={() => setShow(false)}
    >
      {term}
      {show && <span className="glossary-popup">{def}</span>}
    </span>
  );
}
