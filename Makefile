# ============================================
# The Cathedral — Makefile
# Universal remote control for every aspect
# of the repository.
#
# First time? Run:
#   make check   — see what you need
#   make setup   — install everything
# ============================================

.PHONY: help build papers dashboard visualizer verify axioms cascade dump dump-rh stats clean
.PHONY: check setup setup-lean setup-rust setup-node setup-python setup-latex setup-gmp
.PHONY: experiment-vasyunin experiment-covariance experiment-bd
.PHONY: experiment-gram experiment-abel experiment-all
.PHONY: sedenion axiom-hunt spectral-engine viewport origin
.PHONY: proof-tree audit
.DEFAULT_GOAL := help

ENV := scripts/env.sh

# ────────────────────────────────────────────
# 🏛️  TIER 1: THE CATHEDRAL
# ────────────────────────────────────────────

build: ## Build the Lean 4 proofs (THE main event)
	@$(ENV) require lean
	cd proofs && lake build

verify: ## Verify the crown theorem's axiom foundation
	@$(ENV) require lean
	cd proofs && lake env lean Cathedral/Archive/Scratch/PrintAxioms.lean

axioms: ## List all axioms in the Cathedral
	@echo ""
	@echo "  🏛️  Cathedral Axioms"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@printf "  Total: " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -c '^axiom ' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
	@echo ""
	@find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' \
		-exec grep -Hn '^axiom ' {} \; 2>/dev/null | \
		sed 's|proofs/Cathedral/||' | \
		awk -F: '{printf "  %-50s %s:%s\n", $$3, $$1, $$2}' | \
		sed 's/axiom //' | sort
	@echo ""
	@echo "  Plus Lean kernel: propext, Classical.choice, Quot.sound"
	@echo "  ═══════════════════════════════════════════"
	@echo ""

papers: ## Build all 15 companion papers
	@$(ENV) require pdflatex
	cd papers && ./build.sh

cascade: ## Audit the Oracle Cascade axiom footprint (requires: make build)
	@$(ENV) require lean
	@echo ""
	@echo "  🏛️  Oracle Cascade — Axiom Audit"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@cd proofs && printf '%s\n' \
		'import Cathedral.Assembly.OracleCascade' \
		'#print axioms rh_unconditional' \
		'#print axioms mertens_bound_cascade' \
		'#print axioms l2_error_cascade' \
		'#print axioms oracle_crown' \
		| lake env lean --stdin 2>&1 | grep -v "^warning:" | sed 's/^/  /' || true
	@echo ""
	@echo "  ═══════════════════════════════════════════"
	@echo ""

crown-audit: ## Show all classified axioms by class
	@echo ""
	@echo "  🏛️  Crown Axiom Audit"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@echo "  CROWN AXIOMS (on proof paths to RH):"
	@grep -rn "AXIOM CLASS: CROWN" proofs/Cathedral/ --include="*.lean" | grep -v Archive
	@echo ""
	@echo "  CLASSICAL-PNT AXIOMS (will close with PNTAnd):"
	@grep -rn "AXIOM CLASS: CLASSICAL" proofs/Cathedral/ --include="*.lean" | grep -v Archive
	@echo ""
	@echo "  OFF-CROWN AXIOMS (not on any crown path):"
	@grep -rn "AXIOM CLASS: OFF-CROWN" proofs/Cathedral/ --include="*.lean" | grep -v Archive
	@echo ""
	@echo "  ═══════════════════════════════════════════"
	@echo ""

# ────────────────────────────────────────────
# 🔬  TIER 2: EXPERIMENTS & VISUALIZATION
# ────────────────────────────────────────────

dashboard: ## Launch the Cathedral Dashboard (Next.js)
	@$(ENV) require node
	@if [ ! -d visualizer/node_modules ]; then \
		echo "  Installing dashboard dependencies..."; \
		cd visualizer && npm install; \
	fi
	cd visualizer && npm run dev

visualizer: dashboard ## Alias for dashboard

proof-tree: ## Regenerate proof tree data from Lean sources
	@$(ENV) require python3
	@echo "  Regenerating proof tree from Lean sources..."
	@python3 visualizer/scripts/generate_proof_tree.py
	@echo ""
	@echo "  View at: http://localhost:3000/proof-tree"
	@echo "  (Run 'make dashboard' if the server isn't running)"

audit: ## Full Cathedral sorry/axiom audit
	@$(ENV) require python3
	@echo ""
	@echo "  🏛️  Cathedral Audit"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@python3 visualizer/scripts/generate_proof_tree.py
	@echo ""
	@echo "  ── Sorry Details ──"
	@find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/Scratch/*' \
		-exec grep -Hn '^\s*sorry' {} \; 2>/dev/null | \
		sed 's|proofs/Cathedral/||' || echo "  (none)"
	@echo ""
	@echo "  ═══════════════════════════════════════════"

experiment-vasyunin: ## Run 256-bit MPFR Gram matrix verification
	@$(ENV) require cargo
	@$(ENV) require gmp
	cd experiments/vasyunin-integral && cargo run --release

experiment-covariance: ## Run eigenvalue decay analysis
	@$(ENV) require cargo
	cd experiments/covariance-probe && cargo run --release

experiment-bd: ## Run Báez-Duarte distance computation
	@$(ENV) require cargo
	cd experiments/baez-duarte && cargo run --release

experiment-gram: ## Run original Gram oracle
	@$(ENV) require cargo
	cd experiments/gram-oracle && cargo run --release

experiment-abel: ## Run Abel summation verification
	@$(ENV) require cargo
	cd experiments/abel-bridge && cargo run --release

experiment-all: ## Run all experiments sequentially
	@echo "  Running all experiments..."
	@$(MAKE) --no-print-directory experiment-vasyunin
	@$(MAKE) --no-print-directory experiment-covariance
	@$(MAKE) --no-print-directory experiment-bd
	@$(MAKE) --no-print-directory experiment-gram
	@$(MAKE) --no-print-directory experiment-abel
	@echo "  All experiments complete."

# ────────────────────────────────────────────
# 🏗️  TIER 3: HISTORICAL TOOLS
# ────────────────────────────────────────────

sedenion: ## Run the sedenion explorer (origin story)
	@$(ENV) require python3
	cd tools/sedenion-explorer && python3 sedenion_operator.py

axiom-hunt: ## Run the LLM axiom hunter
	@$(ENV) require python3
	cd tools/axiom-hunter && python3 axiom_hunter.py

spectral-engine: ## Run the G₂ spectral engine
	@$(ENV) require cargo
	cd tools/spectral-engine && cargo run --bin g2_spectral

viewport: ## Launch the HyperZeta Viewport (3D visualizer)
	@$(ENV) require node
	@if [ ! -d tools/hyperzeta-viewport/node_modules ]; then \
		echo "  Installing viewport dependencies..."; \
		cd tools/hyperzeta-viewport && npm install; \
	fi
	cd tools/hyperzeta-viewport && npm run dev

origin: ## Launch the original HYPERZETA viewer (March 27, 2026)
	@$(ENV) require node
	@if [ ! -d tools/hyperzeta-origin/node_modules ]; then \
		echo "  Installing origin viewer dependencies..."; \
		cd tools/hyperzeta-origin && npm install; \
	fi
	cd tools/hyperzeta-origin && npm run dev -- --port 3001

# ────────────────────────────────────────────
# 🔍  ENVIRONMENT
# ────────────────────────────────────────────

check: ## Check all dependencies (what do I need?)
	@$(ENV) check

setup: ## Install all missing dependencies (interactive)
	@$(ENV) setup

setup-lean: ## Install Lean 4 via elan
	@$(ENV) setup-lean

setup-rust: ## Install Rust via rustup
	@$(ENV) setup-rust

setup-node: ## Install Node.js
	@$(ENV) setup-node

setup-python: ## Install Python 3
	@$(ENV) setup-python

setup-latex: ## Install LaTeX (pdflatex)
	@$(ENV) setup-latex

setup-gmp: ## Install GMP + MPFR (for high-precision experiments)
	@$(ENV) setup-gmp

# ────────────────────────────────────────────
# 📦  EXPORT & UTILITIES
# ────────────────────────────────────────────

dump: ## Generate balanced 10-part cathedral dump (all active files)
	@$(ENV) require python3
	python3 scripts/cathedral_dump.py --mode all \
		--parts 10 --outdir docs/exports/full --prefix cathedral

dump-rh: ## Generate RH-critical path dump (import-traced, 10 files for Gemini)
	@$(ENV) require python3
	python3 scripts/cathedral_dump.py --mode rh \
		--parts 10 --outdir docs/exports/critical-path \
		--prefix cathedral

stats: ## Show project statistics
	@echo ""
	@echo "  ═══════════════════════════════════════════"
	@echo "  🏛️  The Cathedral — Project Statistics"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@printf "  Active Lean files:  " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' | wc -l | tr -d ' '
	@printf "  Archived files:     " && find proofs/Cathedral -name '*.lean' -path '*/Archive/*' | wc -l | tr -d ' '
	@printf "  LaTeX papers:       " && find papers -name '*.tex' -not -path '*/build/*' | wc -l | tr -d ' '
	@printf "  Total lines:        " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec cat {} + 2>/dev/null | wc -l | tr -d ' '
	@printf "  Experiments:        " && find experiments -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' '
	@echo ""
	@printf "  Axioms:             " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -c '^axiom ' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
	@printf "  Sorries:            " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -c '^\s*sorry$$' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
	@echo ""
	@echo "  ═══════════════════════════════════════════"
	@echo ""

clean: ## Clean build artifacts
	cd proofs && lake clean 2>/dev/null || true
	find experiments -name target -type d -exec rm -rf {} + 2>/dev/null || true
	cd papers && ./build.sh clean 2>/dev/null || true
	@echo "  Build artifacts cleaned."

# ────────────────────────────────────────────
# 📖  HELP
# ────────────────────────────────────────────

help: ## Show this help message
	@echo ""
	@echo "  🏛️  The Cathedral — A Machine-Verified Reduction of the Riemann Hypothesis"
	@echo ""
	@echo "  First time? Run:  ${CYAN}make check${RESET}  then  ${CYAN}make setup${RESET}"
	@echo ""
	@echo "  Usage: make <target>"
	@echo ""
	@echo "  ─── TIER 1: THE CATHEDRAL ───────────────────────────────"
	@grep -E '^(build|verify|axioms|cascade|crown-audit|papers):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── TIER 2: EXPERIMENTS & VISUALIZATION ─────────────────"
	@grep -E '^(dashboard|visualizer|proof-tree|audit|experiment-[a-z]+):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── TIER 3: HISTORICAL TOOLS ────────────────────────────"
	@grep -E '^(sedenion|axiom-hunt|spectral-engine|viewport|origin):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── ENVIRONMENT ─────────────────────────────────────────"
	@grep -E '^(check|setup[a-z-]*):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── UTILITIES ───────────────────────────────────────────"
	@grep -E '^(dump|dump-rh|stats|clean):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
