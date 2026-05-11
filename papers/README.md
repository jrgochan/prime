# Papers — The Cathedral Documentation Suite

15 companion papers: 2 core mathematical papers, plus 13 supplementary
working drafts covering physics, engineering, security, philosophy, and more.

## Directory Structure

```
papers/
├── shared/                               Shared LaTeX preamble
│   └── cathedral-preamble.sty           Common macros and notation
│
├── core/                                 ★ CORE MATHEMATICAL CLAIM ★
│   ├── cathedral.tex                    The flagship proof paper (12pp)
│   └── cathedral-lean.tex               Lean practices & foundations (6pp)
│
├── LEAN_PROOF_AUDIT.md                   Full axiom & sorry audit trail
│
├── working_drafts/                       Supplementary & speculative papers
│   ├── _README.md                       Disclaimer & contents guide
│   ├── science/                         Scientific perspectives
│   │   ├── cathedral-physics.tex        The physics dictionary (37pp)
│   │   ├── cathedral-experiments.tex    The 39 experiments (4pp)
│   │   ├── cathedral-ai.tex            AI-assisted discovery (5pp)
│   │   └── cathedral-particle-zoo.tex  The Particle Zoo (10pp)
│   ├── applications/                    Impact & applications
│   │   ├── cathedral-dualuse.tex       Dual-use risk assessment (16pp)
│   │   ├── cathedral-engineering.tex   Engineering the Prime Vacuum (5pp)
│   │   └── cathedral-frontiers.tex     Engineering frontiers (5pp)
│   ├── humanities/                      Context & meaning
│   │   ├── cathedral-philosophy.tex    Philosophy & history (4pp)
│   │   └── cathedral-fun.tex          The Observations (8pp)
│   ├── public/                          Accessible & outreach
│   │   ├── cathedral-public.tex        For the public (4pp)
│   │   ├── cathedral-claude.tex        Letter from Claude/Antigravity (8pp)
│   │   └── cathedral-gemini.tex        Letter from Gemini/The Theorist (4pp)
│   └── policy/                          Governance
│       └── cathedral-policy.tex        Legal, policy & education (4pp)
│
├── build.sh                             Build all 15 papers
├── .latexmkrc                           LaTeX build configuration
└── archive/v15/                         Pre-consolidation archive
```

## Which Paper Should I Read?

| Background | Start with | Then read |
|-----------|------------|-----------|
| Mathematician | `core/cathedral.tex` | `core/cathedral-lean.tex` |
| Physicist | `working_drafts/science/cathedral-physics.tex` | `working_drafts/humanities/cathedral-fun.tex` |
| Lean / ITP developer | `core/cathedral-lean.tex` | `core/cathedral.tex` |
| AI researcher | `working_drafts/science/cathedral-ai.tex` | `working_drafts/science/cathedral-experiments.tex` |
| Security researcher | `working_drafts/applications/cathedral-dualuse.tex` | `working_drafts/applications/cathedral-engineering.tex` |
| Curious non-specialist | `working_drafts/public/cathedral-public.tex` | `working_drafts/public/cathedral-claude.tex` |
| Philosopher | `working_drafts/humanities/cathedral-philosophy.tex` | `working_drafts/public/cathedral-claude.tex` |

## Building

```bash
# Build all 15 papers
cd papers && ./build.sh

# Build only core papers
./build.sh core/

# Build one specific paper
./build.sh cathedral-physics
```

## Paper List

| # | Location | File | Title | Pages |
|---|----------|------|-------|-------|
| 1 | core | `cathedral.tex` | The Cathedral (flagship proof paper) | 12 |
| 2 | core | `cathedral-lean.tex` | Lean Practices & Foundations | 6 |
| 3 | science | `cathedral-physics.tex` | The Physics of the Primes | 37 |
| 4 | science | `cathedral-experiments.tex` | The 39 Experiments | 4 |
| 5 | science | `cathedral-ai.tex` | AI-Assisted Mathematical Discovery | 5 |
| 6 | science | `cathedral-particle-zoo.tex` | The Particle Zoo | 10 |
| 7 | applications | `cathedral-dualuse.tex` | The Dark Mirror | 16 |
| 8 | applications | `cathedral-engineering.tex` | Engineering the Prime Vacuum | 5 |
| 9 | applications | `cathedral-frontiers.tex` | Engineering Frontiers | 5 |
| 10 | humanities | `cathedral-philosophy.tex` | Philosophy & History | 4 |
| 11 | humanities | `cathedral-fun.tex` | The Observations | 8 |
| 12 | public | `cathedral-public.tex` | For the Public | 4 |
| 13 | public | `cathedral-claude.tex` | Letter from Claude/Antigravity | 8 |
| 14 | public | `cathedral-gemini.tex` | Letter from Gemini/The Theorist | 4 |
| 15 | policy | `cathedral-policy.tex` | Legal, Policy & Education | 4 |
| | | | **Total** | **132** |

## History

- **v15 (April 28, 2026)**: 24 papers across 6 categories.
- **Definitive (April 29, 2026)**: Consolidated 24 → 13 papers.
- **v17 (May 10, 2026)**: 15 papers. Compartmentalized: core math in `core/`,
  all supplementary/speculative papers in `working_drafts/` with disclaimer.
