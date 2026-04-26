# Papers — The Cathedral Documentation Suite

24 companion papers covering the Cathedral from every angle:
mathematics, physics, computer science, philosophy, education,
security, policy, and more.

## Directory Structure

```
papers/
├── shared/                      Shared LaTeX preamble
│   └── cathedral-preamble.sty   Common macros, theorem envs, notation
│
├── core/                        Mathematical & technical foundations
│   ├── cathedral.tex            Technical overview (9pp)
│   ├── overview.tex             Quick reference (4pp)
│   ├── cathedral-math.tex       The Mathematics (12pp)
│   ├── cathedral-lean.tex       Lean/ITP lessons (9pp)
│   └── cathedral-foundations.tex Logical foundations (9pp)
│
├── science/                     Scientific perspectives
│   ├── cathedral-physics.tex    Physics dictionary (19pp)
│   ├── cathedral-cs.tex         Computer science (12pp)
│   ├── cathedral-engineering.tex Engineering (8pp)
│   └── cathedral-ai.tex         AI verification (7pp)
│
├── applications/                Impact & applications
│   ├── cathedral-security.tex   Security implications (10pp)
│   ├── cathedral-energy.tex     Energy systems (10pp)
│   ├── cathedral-dualuse.tex    Dual-use risk (10pp)
│   ├── cathedral-futures.tex    Engineering frontiers (12pp)
│   └── cathedral-next.tex       Open horizons (11pp)
│
├── humanities/                  Context & meaning
│   ├── cathedral-philosophy.tex Philosophy of math (10pp)
│   ├── cathedral-history.tex    History of mathematics (7pp)
│   ├── cathedral-education.tex  For educators (6pp)
│   └── cathedral-fun.tex        42 Observations (8pp)
│
├── public/                      Accessible & outreach
│   ├── cathedral-public.tex     General public (7pp)
│   ├── cathedral-letter.tex     Letter from the Builder (6pp)
│   ├── cathedral-press.tex      Press/media guide (5pp)
│   └── cathedral-invitation.tex Open challenge (5pp)
│
└── policy/                      Legal & governance
    ├── cathedral-politics.tex   Policy & governance (9pp)
    └── cathedral-legal.tex      Legal/IP (8pp)
```

## Which Paper Should I Read?

**If you are a…**

| Background | Start with | Then read |
|-----------|------------|-----------|
| Mathematician | `core/overview.tex` (4pp) | `core/cathedral-math.tex` (12pp) |
| Physicist | `science/cathedral-physics.tex` (19pp) | `humanities/cathedral-fun.tex` (8pp) |
| Lean / ITP developer | `core/cathedral-lean.tex` (9pp) | `core/cathedral-foundations.tex` (9pp) |
| CS / proof engineer | `science/cathedral-cs.tex` (12pp) | `science/cathedral-engineering.tex` (8pp) |
| Curious non-specialist | `public/cathedral-public.tex` (7pp) | `public/cathedral-letter.tex` (6pp) |
| Journalist | `public/cathedral-press.tex` (5pp) | `public/cathedral-public.tex` (7pp) |
| Philosopher | `humanities/cathedral-philosophy.tex` (10pp) | `humanities/cathedral-history.tex` (7pp) |
| AI researcher | `science/cathedral-ai.tex` (7pp) | `science/cathedral-cs.tex` (12pp) |
| Security researcher | `applications/cathedral-security.tex` (10pp) | `applications/cathedral-dualuse.tex` (10pp) |
| Just here for fun | `humanities/cathedral-fun.tex` (8pp) | `public/cathedral-letter.tex` (6pp) |

## Building

Requires a LaTeX installation (pdflatex + standard packages) and `latexmk`.

```bash
# Build all 24 papers
./build.sh

# Build one paper (auto-finds the right directory)
./build.sh cathedral-physics

# Build all papers in a group
./build.sh science/

# Watch mode — rebuilds on save, opens Preview
./build.sh watch cathedral-math

# Clean all build artifacts
./build.sh clean
```

The build system uses [latexmk](https://mg.readthedocs.io/latexmk.html) under
the hood (configured via `.latexmkrc`). It automatically determines the number
of compilation passes needed for cross-references and table of contents.

If `latexmk` is not installed: `sudo tlmgr install latexmk`

## Shared Preamble

All papers use `shared/cathedral-preamble.sty` for consistent notation:
- Theorem environments (definition, theorem, lemma, etc.)
- Number set shortcuts (`\ZZ`, `\RR`, `\CC`, `\NN`, `\HH`)
- Operator notation (`\RH`, `\re`, `\im`, `\Tr`, `\lean{}`, `\fract{}`)
- Physics notation (`\bra{}`, `\ket{}`, `\braket{}`)

Paper-specific packages (tikz, listings, setspace, etc.) are loaded
after the shared preamble in each file.

## Paper List

| # | Group | File | Title | Pages |
|---|-------|------|-------|-------|
| 1 | core | `cathedral.tex` | The Cathedral (technical overview) | 9 |
| 2 | core | `overview.tex` | Quick reference | 4 |
| 3 | core | `cathedral-math.tex` | The Mathematics | 12 |
| 4 | core | `cathedral-lean.tex` | Lessons for the Lean Community | 9 |
| 5 | core | `cathedral-foundations.tex` | Logical Foundations | 9 |
| 6 | science | `cathedral-physics.tex` | The Physics of the Primes | 19 |
| 7 | science | `cathedral-cs.tex` | Computer Science Perspective | 12 |
| 8 | science | `cathedral-engineering.tex` | Engineering Perspective | 8 |
| 9 | science | `cathedral-ai.tex` | AI-Assisted Formal Verification | 7 |
| 10 | applications | `cathedral-security.tex` | Security Implications | 10 |
| 11 | applications | `cathedral-energy.tex` | Energy Systems | 10 |
| 12 | applications | `cathedral-dualuse.tex` | Dual-Use Risk Assessment | 10 |
| 13 | applications | `cathedral-futures.tex` | Engineering Frontiers | 12 |
| 14 | applications | `cathedral-next.tex` | Open Horizons | 11 |
| 15 | humanities | `cathedral-philosophy.tex` | Philosophy of Mathematics | 10 |
| 16 | humanities | `cathedral-history.tex` | History of Mathematics | 7 |
| 17 | humanities | `cathedral-education.tex` | For Educators | 6 |
| 18 | humanities | `cathedral-fun.tex` | Forty-Two Observations | 8 |
| 19 | public | `cathedral-public.tex` | For the General Public | 7 |
| 20 | public | `cathedral-letter.tex` | A Letter from the Builder | 6 |
| 21 | public | `cathedral-press.tex` | Press / Media Guide | 5 |
| 22 | public | `cathedral-invitation.tex` | Open Challenge | 5 |
| 23 | policy | `cathedral-politics.tex` | Policy & Governance | 9 |
| 24 | policy | `cathedral-legal.tex` | Legal / IP | 8 |
