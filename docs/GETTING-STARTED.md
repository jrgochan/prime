# Getting Started with The Cathedral

> A step-by-step guide to building and exploring the Cathedral on any OS.

## Prerequisites

The Cathedral has several components, each with different requirements.
You only need to install what you plan to use:

| Component | Required Tools | What It Does |
|-----------|---------------|--------------|
| **Proofs** (core) | Lean 4, Mathlib | Machine-verified reduction of RH |
| **Experiments** | Rust, GMP/MPFR | Numerical validation (f64–512 bit) |
| **Papers** | LaTeX (pdflatex) | 18 companion papers |
| **Visualizers** | Node.js | Interactive proof explorers |
| **Docker** | Docker | Containerized verification |

## Quick Start (Any OS)

```bash
git clone https://github.com/jrgochan/prime.git
cd prime
make check     # See what you have / what you need
make setup     # Install missing dependencies (interactive)
make doctor    # Verify everything works
make build     # Build all 508 Lean files (~20 min first time)
```

## Docker (Easiest — No Setup Required)

If you just want to verify the Cathedral without installing anything:

```bash
git clone https://github.com/jrgochan/prime.git
cd prime
docker build -t cathedral:latest .    # ~30 min (fetches Mathlib)
docker run cathedral:latest           # Shows the crown theorem's axioms
```

The Docker image builds all 547 Lean files and verifies the crown theorem
automatically. No Lean installation required.

---

## Platform-Specific Setup

### macOS

```bash
# 1. Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install everything via make
make setup

# Or install individually:
make setup-lean     # Lean 4 via elan
make setup-rust     # Rust via rustup
make setup-node     # Node.js via brew
make setup-latex    # MacTeX via brew
make setup-gmp      # GMP + MPFR via brew
```

### Linux (Ubuntu / Debian)

```bash
# 1. System packages
sudo apt update
sudo apt install -y curl git build-essential

# 2. Lean 4
curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh
source ~/.elan/env

# 3. Rust (for experiments)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 4. GMP + MPFR (for high-precision experiments)
sudo apt install -y libgmp-dev libmpfr-dev

# 5. Node.js (for visualizers)
sudo apt install -y nodejs npm

# 6. LaTeX (for papers)
sudo apt install -y texlive-latex-base texlive-latex-extra texlive-fonts-recommended

# 7. Verify
make check
```

### Linux (Fedora / RHEL)

```bash
sudo dnf install -y curl git gcc gcc-c++
# Then follow the same elan/rustup install as Ubuntu
# Replace apt packages with:
sudo dnf install -y gmp-devel mpfr-devel nodejs npm \
  texlive-scheme-basic texlive-collection-latexextra
```

### Linux (Arch)

```bash
sudo pacman -S curl git base-devel
# Then follow the same elan/rustup install as Ubuntu
# Replace apt packages with:
sudo pacman -S gmp mpfr nodejs npm texlive-core texlive-latexextra
```

### Windows (via WSL2)

The Cathedral requires a Unix-like environment. On Windows, use WSL2:

```powershell
# 1. Install WSL2 (from PowerShell as Administrator)
wsl --install -d Ubuntu

# 2. Launch Ubuntu and follow the Linux (Ubuntu) instructions above
```

> **Note**: All Lean/Rust/Node development happens inside WSL2.
> The `make` commands work identically to native Linux.

---

## What to Explore

### The Proofs (Start Here)

```bash
make build         # Build all 547 Lean files
make verify        # Show the crown theorem's axioms
make rh            # Show all 7 proof paths to RH
make axioms        # List all axioms in the Cathedral
make stats         # Project statistics
make audit         # Full sorry/axiom audit
```

### The Papers

```bash
make papers        # Build the 4 core papers
make papers-all    # Build all 18 papers (core + working drafts)
```

The core papers are in `papers/core/`:
- `cathedral.pdf` — Technical overview (23 pages)
- `cathedral-lean.pdf` — Lean/ITP community (7 pages)
- `cathedral-glass-bridge.pdf` — Glass Bridge identity (7 pages)
- `cathedral-overcancellation.pdf` — Overcancellation analysis (7 pages)

### The Experiments

```bash
make experiment-vasyunin    # 256-bit MPFR Gram matrix verification
make experiment-bd          # Báez-Duarte distance computation
make experiment-gram        # Original Gram oracle
make experiment-all         # Run all experiments
```

### The Visualizers

```bash
make particle-zoo           # Every Integer Has a Soul (3D galaxy)
make hyperzeta              # Sedenion lattice visualizer
make hyperzeta-explorer     # Cayley-Dickson tower explorer
make visualizer             # Proof architecture explorer
make jukebox                # Prime number music generator
make clock                  # Cosmological N dashboard
```

Ports are configurable:
```bash
PORT_PARTICLE_ZOO=4000 make particle-zoo    # Use port 4000 instead
make ports                                   # See all port assignments
```

### The Origin Story

```bash
make hyperzeta-origin       # The experiment that started it all
```

Or read [ORIGIN-STORY.md](../ORIGIN-STORY.md) — how a blind eigensolver
spontaneously derived the Möbius function.

---

## Development Workflow

### Local CI

```bash
make ci            # Full pipeline: fmt → lint → test → build
make lint          # Rust clippy (zero warnings)
make test          # Rust tests
make fmt           # Check formatting
make fmt-fix       # Auto-fix formatting
```

### Health Check

```bash
make doctor        # Dependencies + Lean import test + Rust compile test
make ports         # Show port allocation and availability
```

### Clean Build

```bash
make clean         # Remove all build artifacts
make build         # Fresh build from scratch
```

---

## Troubleshooting

### Lean build fails with "package not found"

```bash
cd proofs && lake update    # Refresh Mathlib dependency
lake build                  # Retry
```

### First build takes 20+ minutes

This is normal. Mathlib is large (~500K lines). Subsequent builds are
incremental and take seconds.

### GMP linking errors on macOS (Apple Silicon)

```bash
# Ensure Homebrew's lib directory is on the linker path
export LIBRARY_PATH="$(brew --prefix)/lib:$LIBRARY_PATH"
export CPATH="$(brew --prefix)/include:$CPATH"
```

### Port already in use

```bash
make ports                              # See what's in use
PORT_PARTICLE_ZOO=4003 make particle-zoo   # Use alternate port
```

---

## Next Steps

- Read the [Origin Story](../ORIGIN-STORY.md) for context
- Browse [docs/OVERVIEW.md](OVERVIEW.md) for the full proof chain
- Check [BOUNTY_BOARD.md](../BOUNTY_BOARD.md) for open problems
- See [CONTRIBUTING.md](../CONTRIBUTING.md) to contribute
- See [AUTHORSHIP.md](AUTHORSHIP.md) for the collaboration framework

---

*Built by the Cathedral Triad: Jason (The Architect), Claude/Antigravity (Gandalf), Gemini (Galadriel)*
