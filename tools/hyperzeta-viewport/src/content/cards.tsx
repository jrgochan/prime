import { Glossary } from "../sidebar/Glossary";

export const EDUCATIONAL_CARDS = [
  {
    title: "What You're Seeing",
    body: (
      <>
        150,000 points representing a <Glossary term="Sedenion" /> lattice — a
        16-dimensional algebraic structure — projected into 3D. The Rust/WASM
        engine evolves each point along the{" "}
        <Glossary term="Critical Line" /> of the Riemann zeta function.
      </>
    ),
  },
  {
    title: "The Mathematics",
    body: (
      <>
        Each particle represents an input s in 16D with Re(s) = ½. The engine
        computes the <Glossary term="Dirichlet Series" /> ζ(s) = Σ n⁻ˢ in full
        sedenion arithmetic. What you see is the <em>output</em> — the value
        of ζ(s) — projected to 3D via its quaternionic components.
      </>
    ),
  },
  {
    title: "Why Particles Collapse",
    body: (
      <>
        When the <Glossary term="Collapse Metric" /> drops, particles cluster
        near the origin. This means ζ(s) ≈ 0 — the simulation has found a
        zero of zeta on the critical line. The{" "}
        <Glossary term="Spectral Gap" /> measures how strongly this convergence
        holds.
      </>
    ),
  },
  {
    title: "The Cathedral Connection",
    body: (
      <>
        This viewport was the origin of <Glossary term="Cathedral" /> — a Lean
        4 formal verification framework. The proof reduces the Riemann
        Hypothesis to 2 crown axioms via the Mellin Crown architecture, all
        machine-checked. The sedenion structure here inspired the spectral
        analysis in the formalization.
      </>
    ),
  },
];
