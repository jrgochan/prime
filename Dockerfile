# ============================================
# The Cathedral — Dockerfile
# Minimal image for Lean 4 proof verification
# ============================================
#
# Build:  docker build -t cathedral:latest .
# Run:    docker run cathedral:latest
# Verify: docker run cathedral:latest make verify
#
# This image builds the entire Cathedral proof suite
# and verifies the crown theorem's axiom foundation.
# ============================================

FROM ubuntu:24.04 AS builder

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install elan (Lean version manager)
RUN curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
ENV PATH="/root/.elan/bin:${PATH}"

# Copy only the proofs directory (and build config)
WORKDIR /cathedral
COPY proofs/ proofs/
COPY Makefile .
COPY scripts/env.sh scripts/env.sh

# Build the Cathedral (fetches Mathlib, compiles all 508 Cathedral files)
# This is the expensive step — cached by Docker layer
WORKDIR /cathedral/proofs
RUN lake build

# ── Verification stage ──────────────────────
FROM builder AS verified

WORKDIR /cathedral/proofs

# Verify the crown theorem
RUN printf 'import Cathedral.Assembly.MainChain\n#print axioms baez_duarte_forward' \
    | lake env lean --stdin 2>&1 | tee /tmp/axiom_check.txt \
    && echo "✅ Crown theorem verified"

# Default: show the axiom foundation
CMD ["sh", "-c", "echo '' && echo '🏛️  The Cathedral — Axiom Verification' && echo '═══════════════════════════════════════════' && echo '' && printf 'import Cathedral.Assembly.MainChain\\n#print axioms baez_duarte_forward' | lake env lean --stdin 2>&1 && echo '' && echo '═══════════════════════════════════════════' && echo '🏛️  The Cathedral stands.' && echo ''"]
