# Papers — The Cathedral Documentation Suite

23 companion papers covering the Cathedral from every angle:
mathematics, physics, computer science, philosophy, education,
security, policy, and more.

## Which Paper Should I Read?

**If you are a…**

| Background | Start with | Then read |
|-----------|------------|-----------|
| Mathematician | `overview.tex` (4pp) | `cathedral-math.tex` (12pp) |
| Physicist | `cathedral-physics.tex` (10pp) | `cathedral-fun.tex` (8pp) |
| Lean / ITP developer | `cathedral-lean.tex` (9pp) | `cathedral-foundations.tex` (9pp) |
| CS / proof engineer | `cathedral-cs.tex` (12pp) | `cathedral-engineering.tex` (8pp) |
| Curious non-specialist | `cathedral-public.tex` (7pp) | `cathedral-letter.tex` (6pp) |
| Journalist | `cathedral-press.tex` (5pp) | `cathedral-public.tex` (7pp) |
| Philosopher | `cathedral-philosophy.tex` (10pp) | `cathedral-history.tex` (7pp) |
| AI researcher | `cathedral-ai.tex` (7pp) | `cathedral-cs.tex` (12pp) |
| Security researcher | `cathedral-security.tex` (10pp) | `cathedral-dualuse.tex` (10pp) |
| Just here for fun | `cathedral-fun.tex` (8pp) | `cathedral-letter.tex` (6pp) |

## Building

All papers require a LaTeX installation (pdflatex + standard packages).

```bash
./build.sh           # Build all 23 papers
```

Individual papers:
```bash
pdflatex cathedral-physics.tex
pdflatex cathedral-physics.tex   # Run twice for TOC
```

## Paper List

| # | File | Title | Pages |
|---|------|-------|-------|
| 1 | `cathedral.tex` | The Cathedral (technical overview) | 9 |
| 2 | `overview.tex` | Quick reference | 4 |
| 3 | `cathedral-math.tex` | The Mathematics | 12 |
| 4 | `cathedral-physics.tex` | The Physics of the Primes | 10 |
| 5 | `cathedral-public.tex` | For the General Public | 7 |
| 6 | `cathedral-cs.tex` | Computer Science Perspective | 12 |
| 7 | `cathedral-security.tex` | Security Implications | 10 |
| 8 | `cathedral-philosophy.tex` | Philosophy of Mathematics | 10 |
| 9 | `cathedral-ai.tex` | AI-Assisted Formal Verification | 7 |
| 10 | `cathedral-lean.tex` | Lessons for the Lean Community | 9 |
| 11 | `cathedral-foundations.tex` | Logical Foundations | 9 |
| 12 | `cathedral-fun.tex` | Forty-Two Observations | 8 |
| 13 | `cathedral-engineering.tex` | Engineering Perspective | 8 |
| 14 | `cathedral-futures.tex` | Engineering Frontiers | 12 |
| 15 | `cathedral-energy.tex` | Energy Systems | 10 |
| 16 | `cathedral-dualuse.tex` | Dual-Use Risk Assessment | 10 |
| 17 | `cathedral-politics.tex` | Policy & Governance | 9 |
| 18 | `cathedral-education.tex` | For Educators | 6 |
| 19 | `cathedral-history.tex` | History of Mathematics | 7 |
| 20 | `cathedral-invitation.tex` | Open Challenge | 5 |
| 21 | `cathedral-press.tex` | Press / Media | 5 |
| 22 | `cathedral-legal.tex` | Legal / IP | 8 |
| 23 | `cathedral-letter.tex` | A Letter from the Builder | 6 |
