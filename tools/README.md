# Historical Exploration Tools

These tools predate the Cathedral. They are the instruments that were
used to *discover* the architecture, not the architecture itself.

Each directory contains a self-contained tool that played a role in the
journey from speculative geometry to machine-verified proof.

---

## 🔮 sedenion-explorer/ — The Night the Machine Fought Back

**The tool that started it all.**

A Python-based exploration of the Gram matrix `G(j,k) = ∫₀¹ {j/x}{k/x}dx`
through higher-dimensional Cayley–Dickson algebra (octonions, sedenions).
Includes the 128-bit MPFR numerical eigensolver that spontaneously derived
the Möbius function μ(k) and collided with Selberg's Parity Barrier.

```bash
cd sedenion-explorer
pip install -r requirements.txt
python sedenion_operator.py    # The sedenion visualization
python operator_search.py      # Operator eigenvalue search
```

Key files:
- `sedenion_operator.py` — Sedenion-space Gram matrix construction
- `operator_search.py` — Eigenvalue search in continuous geometry
- `tower_analyzer.py` — Cayley–Dickson tower analysis
- `li_criterion.py` — Li criterion exploration

---

## ⚙️ spectral-engine/ — G₂ Spectral Analysis (Rust)

High-performance Rust engine for spectral computations on the Gram matrix.
Used during the early spectral analysis phase.

```bash
cd spectral-engine
cargo run --bin g2_spectral
```

---

## 🤖 axiom-hunter/ — LLM-Powered Sorry Elimination

An automated tool that uses LLM strategies to hunt for proofs of `sorry`
placeholders in the Cathedral Lean files.

```bash
cd axiom-hunter
python axiom_hunter.py --target proofs/Cathedral/
```

Key files:
- `axiom_hunter.py` — Main hunting loop
- `lean_runner.py` — Lean 4 compilation interface
- `strategies/` — Proof strategies (tactic bombing, LLM generation)
- `results/` — Hunt logs from April 16, 2026

---

## 🖥️ hyperzeta-viewport/ — The Original HYPERZETA Visualization

The original Next.js viewport from the HYPERZETA phase of the project,
before the pivot to formal verification. Preserved for historical context.

```bash
cd hyperzeta-viewport
npm install && npm run dev
```
