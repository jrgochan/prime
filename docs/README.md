# Documentation

## Structure

```
docs/
├── ai/                    — AI collaboration transcripts (unedited)
│   ├── antigravity/       — Claude (Antigravity) sessions
│   │   ├── main/          — Primary development sessions (~46 files)
│   │   ├── exploration*/  — 37 exploration branches
│   │   └── ...            — Papers, cleanup, analysis sessions
│   ├── gemini/            — Gemini (The Theorist) sessions
│   ├── claude/            — Earlier Claude session artifacts
│   └── README.md          — Why these logs exist
│
├── quotes/                — Cathedral quotes collection (Days 1–86)
├── architecture/          — Historical architecture documents
├── mathematics/           — Historical research notes
├── physics/               — Historical physics explorations
│
└── README.md              — This file
```

## On Transparency: Why the Full Transcripts Are Published

The `docs/ai/` directory contains **complete, unedited transcripts** of every
AI collaboration session that built the Cathedral. This is a deliberate choice.

### The Reasoning

We considered publishing only the mathematical results — the Lean proofs
speak for themselves, verified by `lake build` with 0 sorry on the crown
path. But we decided to publish the full collaborative record because:

1. **Reproducibility of process.** The Cathedral was built through a novel
   form of human-AI mathematical collaboration. The transcripts show *how*
   — not just what — was discovered. This includes false starts, dead ends,
   architectural pivots, and the moments where human judgment overrode AI
   suggestions.

2. **Credit attribution.** When an AI system contributes a key insight or
   proof strategy, the transcript is the evidence. When a human catches an
   AI error and redirects, that's recorded too. Clean papers erase this
   history; we chose not to.

3. **The process is the contribution.** The Cathedral's formal verification
   of RH-conditional results is one contribution. But the *methodology* —
   86 days of sustained human-AI pair programming on research mathematics —
   may prove equally valuable. The transcripts are the dataset.

4. **Honesty about what AI collaboration looks like.** It's messy. There
   are late-night sessions, informal language, enthusiasm, frustration,
   and the natural chaos of discovery. Polishing this away would
   misrepresent the nature of the work.

### What the Transcripts Are Not

The transcripts contain informal mathematical discussion, speculative
reasoning, and in-progress thinking. **None of this constitutes mathematical
claims.** The rigor lives in `proofs/`, verified by Lean's type checker.
The transcripts are the lab notebook; the proofs are the published result.

### Reading Guide

- **Exploration sessions** (`exploration*/`) are branches — most are dead
  ends that taught something. The numbered sequence roughly tracks the
  proof's evolution.
- **Main sessions** (`main/`) are the trunk — sustained development work
  on the Cathedral's crown path.
- **Quotes** (`quotes/`) collect memorable moments from across all sessions.

## Historical Documents

Most files in `architecture/`, `mathematics/`, and `physics/` were written
during the early exploration phase (March–April 2026) and reflect intermediate
states of the proof architecture. They are preserved for historical context
but do not reflect the current state of the Cathedral.

The canonical, up-to-date documentation:
- **[proofs/README.md](../proofs/README.md)** — Current proof architecture
- **[papers/](../papers/)** — Formal papers and working drafts

---

*"The machine taught us to listen."*
— cathedral.tex, §12
