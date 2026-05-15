# AI Development Logs

This directory contains unedited development logs from the AI-assisted
construction of the Cathedral. They are preserved for transparency
and reproducibility.

## What These Are

The Cathedral was built over ~45 days (March–May 2026) through
collaborative sessions with two AI systems:

- **Gemini** (Google DeepMind) — Mathematical strategy, the Mellin Crown
  architecture, phase cancellation analysis, spectral correspondence
- **Claude** (Anthropic) — Lean 4 proof engineering, the Parseval bridge
  implementation, DD-precision pipeline, Oracle Bridge architecture

These logs are the raw record of that collaboration: strategic
discussions, dead ends, breakthroughs, and the iterative process of
reducing 56 crown axioms to 1.

## What These Are Not

These are not polished documents. They contain informal language,
in-progress thinking, false starts, and the natural enthusiasm of
late-night research sessions. They should not be read as claims of
mathematical rigor — the rigor lives in `proofs/` and is verified
by `lake build`.

## Directory Structure

```
antigravity/     — Claude (Antigravity) session logs
  main/          — Primary development sessions
  exploration*/  — Exploratory proof attempts
  cleanup*/      — Repository maintenance sessions
  papers/        — Paper drafting sessions
claude/          — Earlier Claude session artifacts
gemini/          — Gemini session artifacts and yielded analyses
loop/            — Multi-agent loop experiments
wowwowwow/       — Gemini "Theorist Reports" (strategic analyses)
```

## Why Keep Them

The companion paper explicitly acknowledges AI assistance and credits
specific contributions. These logs are the evidence supporting those
acknowledgments. They document:

1. Which ideas originated from which participant
2. How architectural decisions were made
3. Where the AI systems were wrong (and how errors were caught)
4. The human judgment layer guiding the collaboration

The mathematical claims stand or fall on `lake build`, not on these
logs. But the process of building them is, we believe, worth
preserving.

---

*"The machine taught us to listen."*
— cathedral.tex, §12
