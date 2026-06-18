# ============================================
# The Cathedral — Makefile
# A Machine-Verified Reduction of the
# Riemann Hypothesis in Lean 4
#
# First time? Run:
#   make check   — see what you need
#   make setup   — install everything
# ============================================

.PHONY: help build papers verify axioms rh cascade crown-audit clock jukebox
.PHONY: hyperzeta hyperzeta-origin hyperzeta-explorer particle-zoo visualizer
.PHONY: check setup setup-lean setup-rust setup-node setup-python setup-latex setup-gmp
.PHONY: experiment-vasyunin experiment-covariance experiment-bd
.PHONY: experiment-gram experiment-abel experiment-all
.PHONY: audit stats clean
.PHONY: lint test fmt ci
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

rh: ## 🌟 Show what axioms the compiler needs for theorem RiemannHypothesis
	@$(ENV) require lean
	@echo ""
	@echo "  🏛️  The Riemann Hypothesis — Axiom Requirements"
	@echo "  ═══════════════════════════════════════════════════"
	@echo ""
	@echo "  Building the Cathedral..."
	@cd proofs && lake build 2>&1 | tail -1
	@echo ""
	@echo "  ┌─────────────────────────────────────────────────┐"
	@echo "  │  PATH 1: Overcancellation (2 PNT axioms)       │"
	@echo "  │  overcancellation_implies_rh                    │"
	@echo "  └─────────────────────────────────────────────────┘"
	@cd proofs && printf '%s\n' \
		'import Cathedral.Assembly.OvercancellationChain' \
		'#print axioms overcancellation_implies_rh' \
		| lake env lean --stdin 2>&1 | grep -v "^warning:" | grep -v "^info:" | grep -v "^Note:" | grep -v "^$$" | sed 's/^/  /' || true
	@echo ""
	@echo "  ┌─────────────────────────────────────────────────┐"
	@echo "  │  PATH 2: Unified Fermionic (1 axiom + 2 PNT)   │"
	@echo "  │  rh_from_unified_fermionic                      │"
	@echo "  └─────────────────────────────────────────────────┘"
	@cd proofs && printf '%s\n' \
		'import Cathedral.Geometry.FermionicLowerBoundGraduation' \
		'#print axioms Cathedral.Geometry.FermionicLowerBoundGraduation.rh_from_unified_fermionic' \
		| lake env lean --stdin 2>&1 | grep -v "^warning:" | grep -v "^info:" | grep -v "^Note:" | grep -v "^$$" | sed 's/^/  /' || true
	@echo ""
	@echo "  ┌─────────────────────────────────────────────────┐"
	@echo "  │  PATH 3: Vacuum Stability (1 wall axiom + PNT) │"
	@echo "  │  VacuumStability.riemann_hypothesis             │"
	@echo "  └─────────────────────────────────────────────────┘"
	@cd proofs && printf '%s\n' \
		'import Cathedral.Geometry.VacuumStability' \
		'#print axioms Cathedral.Geometry.VacuumStability.riemann_hypothesis' \
		| lake env lean --stdin 2>&1 | grep -v "^warning:" | grep -v "^info:" | grep -v "^Note:" | grep -v "^$$" | sed 's/^/  /' || true
	@echo ""
	@echo "  ┌─────────────────────────────────────────────────┐"
	@echo "  │  PATH 4: Nyman-Beurling Equivalence (2 PNT+2)  │"
	@echo "  │  nyman_beurling_equivalence                     │"
	@echo "  └─────────────────────────────────────────────────┘"
	@cd proofs && printf '%s\n' \
		'import Cathedral.Assembly.MainChain' \
		'#print axioms nyman_beurling_equivalence' \
		| lake env lean --stdin 2>&1 | grep -v "^warning:" | grep -v "^info:" | grep -v "^Note:" | grep -v "^$$" | sed 's/^/  /' || true
	@echo ""
	@echo "  ═══════════════════════════════════════════════════"
	@echo "  Lean kernel axioms (always present, non-mathematical):"
	@echo "    propext, Classical.choice, Quot.sound"
	@echo "  ═══════════════════════════════════════════════════"
	@echo ""

papers: ## Build the companion papers
	@$(ENV) require pdflatex
	cd papers/core && pdflatex -interaction=nonstopmode cathedral.tex > /dev/null 2>&1
	cd papers/core && pdflatex -interaction=nonstopmode cathedral-lean.tex > /dev/null 2>&1
	@echo "  ✓ papers/core/cathedral.pdf"
	@echo "  ✓ papers/core/cathedral-lean.pdf"

clock: ## Open the Cathedral Clock — cosmological N dashboard
	@echo ""
	@echo "  🏛️⏱  Opening The Cathedral Clock..."
	@echo ""
	@open cathedral-clock/index.html 2>/dev/null || \
		xdg-open cathedral-clock/index.html 2>/dev/null || \
		echo "  Open cathedral-clock/index.html in your browser"
	@echo "  ✓ cathedral-clock/index.html"

hyperzeta: ## Launch HyperZeta Viewport — sedenion lattice visualizer (port 3000)
	@echo ""
	@echo "  ✦  Launching Project HyperZeta — Cathedral Viewport..."
	@echo "     150K-particle sedenion lattice · Rust/WASM + Three.js"
	@echo ""
	@if [ -d tools/hyperzeta-viewport/.next ]; then \
		echo "  Starting Next.js server on http://localhost:3000 ..." && \
		cd tools/hyperzeta-viewport && npx next start -p 3000; \
	else \
		echo "  ⚠  No build found. Run: cd tools/hyperzeta-viewport && npm install && npm run build"; \
	fi

hyperzeta-origin: ## Launch HyperZeta Origin — proof-graph explorer (port 3001)
	@echo ""
	@echo "  ✦  Launching Project HyperZeta — Origin Explorer..."
	@echo ""
	@if [ -d tools/hyperzeta-origin/.next ]; then \
		echo "  Starting Next.js server on http://localhost:3001 ..." && \
		cd tools/hyperzeta-origin && npx next start -p 3001; \
	else \
		echo "  ⚠  No build found. Run: cd tools/hyperzeta-origin && npm install && npm run build"; \
	fi

hyperzeta-explorer: ## Launch HyperZeta Explorer — Cayley-Dickson tower visualizer (port 3002)
	@echo ""
	@echo "  ✦  Launching HYPERZETA Explorer — Cayley-Dickson Tower..."
	@echo "     6 modes: Origin · Teardrop · Glass Staircase · Division by Zero · Spectrometer · Prime Democracy"
	@echo ""
	@if [ -d tools/hyperzeta-explorer/node_modules ]; then \
		echo "  Starting Next.js dev server on http://localhost:3002 ..." && \
		cd tools/hyperzeta-explorer && npm run dev; \
	else \
		echo "  Installing dependencies..." && \
		cd tools/hyperzeta-explorer && npm install && npm run dev; \
	fi

particle-zoo: ## Launch Particle Zoo — every integer has a soul (port 3003)
	@echo ""
	@echo "  ⚛️  Launching Particle Zoo — Every Integer Has a Soul..."
	@echo "     55,440 integers classified · Quark-Meson battle · SUSY cancellation"
	@echo ""
	@if [ -d tools/hyperzeta-particle-zoo/node_modules ]; then \
		echo "  Starting Next.js dev server on http://localhost:3003 ..." && \
		cd tools/hyperzeta-particle-zoo && npm run dev; \
	else \
		echo "  Installing dependencies..." && \
		cd tools/hyperzeta-particle-zoo && npm install && npm run dev; \
	fi

visualizer: ## Launch Cathedral Visualizer — proof architecture explorer (port 3004)
	@echo ""
	@echo "  🏛️  Launching Cathedral Visualizer — Proof Architecture Explorer..."
	@echo ""
	@if [ -d visualizer/node_modules ]; then \
		echo "  Starting Next.js dev server on http://localhost:3004 ..." && \
		cd visualizer && npm run dev -- -p 3004; \
	else \
		echo "  Installing dependencies..." && \
		cd visualizer && npm install && npm run dev -- -p 3004; \
	fi


jukebox: ## 🍌🍆 Launch The Fruit Loops Jukebox — prime number music generator
	@echo ""
	@echo "  🍌🍆  Launching The Fruit Loops Jukebox..."
	@echo "     Prime Harmonics · Möbius Drums · Banana Ramp Melody · Zeta Drone"
	@echo ""
	@open tools/jukebox/index.html 2>/dev/null || \
		xdg-open tools/jukebox/index.html 2>/dev/null || \
		echo "  Open tools/jukebox/index.html in your browser"
	@echo "  ✓ tools/jukebox/index.html"
	@echo "  Cathedral Records™ — Build Completed Successfully 🏔️💜"

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
# 🔬  TIER 2: EXPERIMENTS
# ────────────────────────────────────────────

audit: ## Full Cathedral sorry/axiom audit
	@echo ""
	@echo "  🏛️  Cathedral Audit"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@echo "  ── Axioms ──"
	@printf "  Total: " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -c '^axiom ' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
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
# 📦  UTILITIES
# ────────────────────────────────────────────

stats: ## Show project statistics
	@echo ""
	@echo "  ═══════════════════════════════════════════"
	@echo "  🏛️  The Cathedral — Project Statistics"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@printf "  Active Lean files:  " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' | wc -l | tr -d ' '
	@printf "  Archived files:     " && find proofs/Cathedral -name '*.lean' -path '*/Archive/*' | wc -l | tr -d ' '
	@printf "  Total lines:        " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec cat {} + 2>/dev/null | wc -l | tr -d ' '
	@printf "  Experiments:        " && find experiments -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' '
	@echo ""
	@printf "  Axioms:             " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -c '^axiom ' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
	@printf "  Sorries (literal):  " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -c '^\s*sorry$$' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
	@printf "  Sorry files:        " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -l '^\s*sorry$$' {} + 2>/dev/null | wc -l | tr -d ' '
	@echo ""
	@echo "  ═══════════════════════════════════════════"
	@echo ""

clean: ## Clean build artifacts
	cd proofs && lake clean 2>/dev/null || true
	find experiments -name target -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "  Build artifacts cleaned."

lint: ## Run clippy on all active experiments (zero warnings required)
	@$(ENV) require cargo
	@echo ""
	@echo "  🔍  Running cargo clippy (excluding archive)..."
	@echo ""
	@cargo clippy --workspace --all-targets \
		$(shell find experiments/archive -name Cargo.toml -exec grep -h 'name = ' {} \; | awk -F'"' '{printf "--exclude %s ", $$2}') \
		-- -D warnings
	@echo ""
	@echo "  ✅  Clippy: zero warnings"

test: ## Run all Rust tests
	@$(ENV) require cargo
	@echo ""
	@echo "  🧪  Running cargo test..."
	@echo ""
	cargo test
	@echo ""
	@echo "  ✅  All tests passed"

fmt: ## Check Rust formatting (use 'make fmt-fix' to apply)
	@$(ENV) require cargo
	@echo ""
	@echo "  📐  Checking formatting..."
	@echo ""
	cargo fmt --all -- --check
	@echo ""
	@echo "  ✅  Formatting OK"

fmt-fix: ## Auto-fix Rust formatting
	@$(ENV) require cargo
	cargo fmt --all
	@echo "  ✅  Formatting applied"

ci: ## Full CI pipeline: fmt → lint → test → build
	@echo ""
	@echo "  🏛️  Cathedral CI Pipeline"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@echo "  [1/4] Format check..."
	@cargo fmt --all -- --check
	@echo "  ✅  Formatting OK"
	@echo ""
	@echo "  [2/4] Clippy lint..."
	@cargo clippy --workspace --all-targets \
		$(shell find experiments/archive -name Cargo.toml -exec grep -h 'name = ' {} \; | awk -F'"' '{printf "--exclude %s ", $$2}') \
		-- -D warnings
	@echo "  ✅  Clippy clean"
	@echo ""
	@echo "  [3/4] Rust tests..."
	@cargo test --quiet
	@echo "  ✅  Tests passed"
	@echo ""
	@echo "  [4/4] Lean build..."
	@cd proofs && lake build
	@echo "  ✅  Lean build green"
	@echo ""
	@echo "  ═══════════════════════════════════════════"
	@echo "  🏛️  All checks passed. Cathedral is sovereign."
	@echo "  ═══════════════════════════════════════════"
	@echo ""

# ────────────────────────────────────────────
# 📖  HELP
# ────────────────────────────────────────────

help: ## Show this help message
	@echo ""
	@echo "  🏛️  The Cathedral — A Formal Reduction of the Riemann Hypothesis"
	@echo ""
	@echo "  First time? Run:  make check  then  make setup"
	@echo ""
	@echo "  Usage: make <target>"
	@echo ""
	@echo "  ─── THE CATHEDRAL ────────────────────────────────────────"
	@grep -E '^(build|verify|axioms|rh|cascade|crown-audit|papers|clock|jukebox|hyperzeta[a-z-]*|particle-zoo|visualizer):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── EXPERIMENTS & AUDITING ───────────────────────────────"
	@grep -E '^(audit|experiment-[a-z]+|stats):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── ENVIRONMENT ──────────────────────────────────────────"
	@grep -E '^(check|setup[a-z-]*):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── UTILITIES ────────────────────────────────────────────"
	@grep -E '^(lint|test|fmt|fmt-fix|ci|clean|stats):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
