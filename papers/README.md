# Papers — The Cathedral Documentation Suite

13 companion papers covering the Cathedral from every angle:
mathematics, physics, computer science, philosophy, engineering,
security, policy, and more.

## Directory Structure

```
papers/
├── shared/                         Shared LaTeX preamble
│   └── cathedral-preamble.sty     Common macros and notation
│
├── core/                           Mathematical & technical core
│   ├── cathedral.tex              The proof paper (10pp)
│   └── cathedral-lean.tex         Lean practices + foundations (6pp)
│
├── science/                        Scientific perspectives
│   ├── cathedral-physics.tex      The physics dictionary (28pp)
│   ├── cathedral-experiments.tex  The 38 experiments (3pp)
│   └── cathedral-ai.tex          AI-assisted discovery (4pp)
│
├── applications/                   Impact & applications
│   ├── cathedral-dualuse.tex      The Dark Mirror (14pp)
│   ├── cathedral-engineering.tex  Energy, security, signals (3pp)
│   └── cathedral-frontiers.tex    Open horizons (3pp)
│
├── humanities/                     Context & meaning
│   ├── cathedral-philosophy.tex   Philosophy & history (3pp)
│   └── cathedral-fun.tex          The Observations (8pp)
│
├── public/                         Accessible & outreach
│   ├── cathedral-public.tex       For the public + press (4pp)
│   └── cathedral-letter.tex       A Letter from the Builder (6pp)
│
├── policy/                         Governance
│   └── cathedral-policy.tex       Legal, policy, education (3pp)
│
└── archive/v15/                    Pre-consolidation archive (24 papers)
```

## Which Paper Should I Read?

| Background | Start with | Then read |
|-----------|------------|-----------|
| Mathematician | `core/cathedral.tex` | `core/cathedral-lean.tex` |
| Physicist | `science/cathedral-physics.tex` | `humanities/cathedral-fun.tex` |
| Lean / ITP developer | `core/cathedral-lean.tex` | `core/cathedral.tex` |
| AI researcher | `science/cathedral-ai.tex` | `science/cathedral-experiments.tex` |
| Security researcher | `applications/cathedral-dualuse.tex` | `applications/cathedral-engineering.tex` |
| Curious non-specialist | `public/cathedral-public.tex` | `public/cathedral-letter.tex` |
| Philosopher | `humanities/cathedral-philosophy.tex` | `public/cathedral-letter.tex` |
| Just here for fun | `humanities/cathedral-fun.tex` | `public/cathedral-letter.tex` |

## Building

```bash
# Build one paper
cd papers/core && pdflatex cathedral.tex

# Build all papers
for d in core science applications humanities public policy; do
  cd papers/$d && for f in *.tex; do pdflatex "$f"; done && cd ../..
done
```

## Paper List

| # | Group | File | Title | Pages |
|---|-------|------|-------|-------|
| 1 | core | `cathedral.tex` | The Cathedral (main proof paper) | 10 |
| 2 | core | `cathedral-lean.tex` | Lean Practices & Foundations | 6 |
| 3 | science | `cathedral-physics.tex` | The Physics of the Primes | 28 |
| 4 | science | `cathedral-experiments.tex` | The 38 Experiments | 3 |
| 5 | science | `cathedral-ai.tex` | AI-Assisted Mathematical Discovery | 4 |
| 6 | applications | `cathedral-dualuse.tex` | The Dark Mirror | 14 |
| 7 | applications | `cathedral-engineering.tex` | Engineering Applications | 3 |
| 8 | applications | `cathedral-frontiers.tex` | Open Horizons | 3 |
| 9 | humanities | `cathedral-philosophy.tex` | Philosophy & History | 3 |
| 10 | humanities | `cathedral-fun.tex` | The Observations | 8 |
| 11 | public | `cathedral-public.tex` | For the Public | 4 |
| 12 | public | `cathedral-letter.tex` | A Letter from the Builder | 6 |
| 13 | policy | `cathedral-policy.tex` | Legal, Policy & Education | 3 |
| | | | **Total** | **95** |

## History

- **v15 (April 28, 2026)**: 24 papers across 6 categories.
- **Definitive (April 29, 2026)**: Consolidated 24 → 13 papers.
  All counts verified against codebase ground truth:
  208 active files, 50,623 LOC, 104 axioms (2 on crown), 0 sorry.
