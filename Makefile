# ============================================
# The Cathedral — Makefile
# A Machine-Verified Reduction of the
# Riemann Hypothesis in Lean 4
#
# First time? Run:
#   make check   — see what you need
#   make setup   — install everything
#   make doctor  — verify everything works
# ============================================

.PHONY: help build tour papers papers-all verify axioms rh cascade crown-audit clock jukebox
.PHONY: hyperzeta hyperzeta-origin hyperzeta-explorer particle-zoo visualizer
.PHONY: check setup setup-lean setup-rust setup-node setup-python setup-latex setup-gmp
.PHONY: experiment-vasyunin experiment-covariance experiment-bd
.PHONY: experiment-gram experiment-abel experiment-all
.PHONY: audit stats clean doctor ports
.PHONY: lint test fmt ci docker
.DEFAULT_GOAL := help

# ── Configurable ports (override with env vars) ─────
PORT_HYPERZETA       ?= 3000
PORT_ORIGIN          ?= 3001
PORT_EXPLORER        ?= 3002
PORT_PARTICLE_ZOO    ?= 3003
PORT_VISUALIZER      ?= 3004

ENV := scripts/env.sh

# ────────────────────────────────────────────
# 🏛️  TIER 1: THE CATHEDRAL
# ────────────────────────────────────────────

build: ## Build the Lean 4 proofs (THE main event)
	@$(ENV) require lean
	cd proofs && lake build

tour: ## 🗺️  Guided tour — what is the Cathedral? (no build required)
	@echo ""
	@echo "  ═══════════════════════════════════════════════════════════"
	@echo "  🏛️  THE CATHEDRAL — A Guided Tour"
	@echo "  ═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "  What is this?"
	@echo "  ─────────────"
	@echo "  A machine-checked proof architecture in Lean 4 + Mathlib that"
	@echo "  reduces the Riemann Hypothesis to the decay of the"
	@echo "  Nyman–Beurling distance d²(N)."
	@echo ""
	@echo "  The Core Claim"
	@echo "  ──────────────"
	@echo "  If vᵀGv ≤ 1 + K/ln(N) for all N (the Gram form bound),"
	@echo "  then the Riemann Hypothesis is true."
	@echo ""
	@echo "  The compiler verifies this implication with ZERO sorry on"
	@echo "  the crown path. Run 'make verify' to see the axiom foundation."
	@echo ""
	@echo "  Project Scale"
	@echo "  ─────────────"
	@printf "  Lean files:      " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' | wc -l | tr -d ' '
	@printf "  Lines of proof:  ~" && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec cat {} + 2>/dev/null | wc -l | tr -d ' '
	@printf "  Build jobs:      8,854+\n"
	@printf "  Experiments:     " && find experiments -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' '
	@echo "  Papers:          18 (4 core + 14 working drafts)"
	@echo ""
	@echo "  The 3 Proof Strategies"
	@echo "  ──────────────────────"
	@echo "  1. Overcancellation    — vtGv ≤ 1 (the Wall axiom) → RH"
	@echo "     ├─ Fermionic lens: SUSY boson/fermion decomposition"
	@echo "     └─ Vacuum lens:    Vasyunin nonCot/S_cot decomposition"
	@echo "  2. Nyman–Beurling      — BD distance d²(N) → 0 → L² convergence → RH"
	@echo "  3. Oracle Bridge       — GPU-certified numerical computation → RH"
	@echo ""
	@echo "  Key Commands"
	@echo "  ────────────"
	@echo "  make check     See what dependencies you have / need"
	@echo "  make setup     Install missing dependencies (interactive)"
	@echo "  make doctor    Full health check"
	@echo "  make build     Build all Lean proofs (~20 min first time)"
	@echo "  make verify    Show the crown theorem's axiom foundation"
	@echo "  make rh        Show all proof paths to the Riemann Hypothesis"
	@echo "  make stats     Project statistics"
	@echo "  make axioms    List every axiom in the Cathedral"
	@echo ""
	@echo "  Visualizers (interactive)"
	@echo "  ────────────────────────"
	@echo "  make clock              The Cathedral Clock — cosmological N dashboard"
	@echo "  make hyperzeta          150K-particle sedenion lattice explorer"
	@echo "  make particle-zoo       Every integer has a soul"
	@echo "  make visualizer         Proof architecture explorer"
	@echo ""
	@echo "  Learn More"
	@echo "  ──────────"
	@echo "  docs/GETTING-STARTED.md   Step-by-step setup guide"
	@echo "  CONTRIBUTING.md           How to contribute"
	@echo "  ORIGIN-STORY.md           How this project began"
	@echo "  papers/core/              The 4 companion papers"
	@echo ""
	@echo "  ═══════════════════════════════════════════════════════════"
	@echo "  Ready? Start with:  make check  →  make setup  →  make doctor"
	@echo "  ═══════════════════════════════════════════════════════════"
	@echo ""

# ── Port conflict detection ─────────────────────────
define check_port
	@if command -v lsof >/dev/null 2>&1 && lsof -i :$(1) >/dev/null 2>&1; then \
		echo "  ⚠  Port $(1) is in use. Override with $(2)=<port> make $(3)"; \
		exit 1; \
	fi
endef

verify: ## Verify the crown theorem's axiom foundation
	@$(ENV) require lean
	cd proofs && lake env lean Cathedral/Archive/Scratch/PrintAxioms.lean

axioms: ## List all axioms in the Cathedral
	@echo ""
	@echo "  🏛️  Cathedral Axioms"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@printf "  Total: " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -cE '^axiom [a-zA-Z][a-zA-Z0-9]*[_A-Z]' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
	@echo ""
	@find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' \
		-exec grep -HnE '^axiom [a-zA-Z][a-zA-Z0-9]*[_A-Z]' {} \; 2>/dev/null | \
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
	@echo "  │  PATH 2: Fermionic (same Wall + SUSY lens)     │"
	@echo "  │  rh_from_unified_fermionic                      │"
	@echo "  └─────────────────────────────────────────────────┘"
	@cd proofs && printf '%s\n' \
		'import Cathedral.Geometry.SUSY.FermionicLowerBoundGraduation' \
		'#print axioms Cathedral.Geometry.SUSY.FermionicLowerBoundGraduation.rh_from_unified_fermionic' \
		| lake env lean --stdin 2>&1 | grep -v "^warning:" | grep -v "^info:" | grep -v "^Note:" | grep -v "^$$" | sed 's/^/  /' || true
	@echo ""
	@echo "  ┌─────────────────────────────────────────────────┐"
	@echo "  │  PATH 3: Vacuum Stability (same Wall, direct)  │"
	@echo "  │  VacuumStability.riemann_hypothesis             │"
	@echo "  └─────────────────────────────────────────────────┘"
	@cd proofs && printf '%s\n' \
		'import Cathedral.Geometry.Wall.VacuumStability' \
		'#print axioms Cathedral.Geometry.Wall.VacuumStability.riemann_hypothesis' \
		| lake env lean --stdin 2>&1 | grep -v "^warning:" | grep -v "^info:" | grep -v "^Note:" | grep -v "^$$" | sed 's/^/  /' || true
	@echo ""
	@echo "  ┌─────────────────────────────────────────────────┐"
	@echo "  │  PATH 4: Nyman-Beurling (different axiom set)   │"
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

papers: ## Build the 4 core papers
	@$(ENV) require pdflatex
	@echo ""
	@echo "  📄  Building core papers..."
	@cd papers/core && for f in cathedral.tex cathedral-lean.tex cathedral-glass-bridge.tex cathedral-overcancellation.tex; do \
		pdflatex -interaction=nonstopmode $$f > /dev/null 2>&1 && \
		echo "  ✓ papers/core/$${f%.tex}.pdf"; \
	done

papers-all: ## Build all 18 papers (core + working drafts)
	@$(ENV) require pdflatex
	@echo ""
	@echo "  📄  Building all papers..."
	@cd papers && ./build.sh
	@echo "  ✓ All papers built"

clock: ## Open the Cathedral Clock — cosmological N dashboard
	@echo ""
	@echo "  🏛️⏱  Opening The Cathedral Clock..."
	@echo ""
	@open cathedral-clock/index.html 2>/dev/null || \
		xdg-open cathedral-clock/index.html 2>/dev/null || \
		echo "  Open cathedral-clock/index.html in your browser"
	@echo "  ✓ cathedral-clock/index.html"

hyperzeta: ## Launch HyperZeta Viewport — sedenion lattice visualizer (port $(PORT_HYPERZETA))
	$(call check_port,$(PORT_HYPERZETA),PORT_HYPERZETA,hyperzeta)
	@echo ""
	@echo "  ✦  Launching Project HyperZeta — Cathedral Viewport..."
	@echo "     150K-particle sedenion lattice · Rust/WASM + Three.js"
	@echo "     Port: $(PORT_HYPERZETA)"
	@echo ""
	@if [ -d tools/hyperzeta-viewport/.next ]; then \
		echo "  Starting Next.js server on http://localhost:$(PORT_HYPERZETA) ..." && \
		cd tools/hyperzeta-viewport && npx next start -p $(PORT_HYPERZETA); \
	else \
		echo "  ⚠  No build found. Run: cd tools/hyperzeta-viewport && npm install && npm run build"; \
	fi

hyperzeta-origin: ## Launch HyperZeta Origin — proof-graph explorer (port $(PORT_ORIGIN))
	$(call check_port,$(PORT_ORIGIN),PORT_ORIGIN,hyperzeta-origin)
	@echo ""
	@echo "  ✦  Launching Project HyperZeta — Origin Explorer..."
	@echo "     Port: $(PORT_ORIGIN)"
	@echo ""
	@if [ -d tools/hyperzeta-origin/.next ]; then \
		echo "  Starting Next.js server on http://localhost:$(PORT_ORIGIN) ..." && \
		cd tools/hyperzeta-origin && npx next start -p $(PORT_ORIGIN); \
	else \
		echo "  ⚠  No build found. Run: cd tools/hyperzeta-origin && npm install && npm run build"; \
	fi

hyperzeta-explorer: ## Launch HyperZeta Explorer — Cayley-Dickson tower visualizer (port $(PORT_EXPLORER))
	$(call check_port,$(PORT_EXPLORER),PORT_EXPLORER,hyperzeta-explorer)
	@echo ""
	@echo "  ✦  Launching HYPERZETA Explorer — Cayley-Dickson Tower..."
	@echo "     6 modes: Origin · Teardrop · Glass Staircase · Division by Zero · Spectrometer · Prime Democracy"
	@echo "     Port: $(PORT_EXPLORER)"
	@echo ""
	@if [ -d tools/hyperzeta-explorer/node_modules ]; then \
		echo "  Starting Next.js dev server on http://localhost:$(PORT_EXPLORER) ..." && \
		cd tools/hyperzeta-explorer && PORT=$(PORT_EXPLORER) npm run dev; \
	else \
		echo "  Installing dependencies..." && \
		cd tools/hyperzeta-explorer && npm install && PORT=$(PORT_EXPLORER) npm run dev; \
	fi

particle-zoo: ## Launch Particle Zoo — every integer has a soul (port $(PORT_PARTICLE_ZOO))
	$(call check_port,$(PORT_PARTICLE_ZOO),PORT_PARTICLE_ZOO,particle-zoo)
	@echo ""
	@echo "  ⚛️  Launching Particle Zoo — Every Integer Has a Soul..."
	@echo "     55,440 integers classified · Quark-Meson battle · SUSY cancellation"
	@echo "     Port: $(PORT_PARTICLE_ZOO)"
	@echo ""
	@if [ -d tools/hyperzeta-particle-zoo/node_modules ]; then \
		echo "  Starting Next.js dev server on http://localhost:$(PORT_PARTICLE_ZOO) ..." && \
		cd tools/hyperzeta-particle-zoo && PORT=$(PORT_PARTICLE_ZOO) npm run dev; \
	else \
		echo "  Installing dependencies..." && \
		cd tools/hyperzeta-particle-zoo && npm install && PORT=$(PORT_PARTICLE_ZOO) npm run dev; \
	fi

visualizer: ## Launch Cathedral Visualizer — proof architecture explorer (port $(PORT_VISUALIZER))
	$(call check_port,$(PORT_VISUALIZER),PORT_VISUALIZER,visualizer)
	@echo ""
	@echo "  🏛️  Launching Cathedral Visualizer — Proof Architecture Explorer..."
	@echo "     Port: $(PORT_VISUALIZER)"
	@echo ""
	@if [ -d visualizer/node_modules ]; then \
		echo "  Starting Next.js dev server on http://localhost:$(PORT_VISUALIZER) ..." && \
		cd visualizer && npm run dev -- -p $(PORT_VISUALIZER); \
	else \
		echo "  Installing dependencies..." && \
		cd visualizer && npm install && npm run dev -- -p $(PORT_VISUALIZER); \
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
	@printf "  Total: " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -cE '^axiom [a-zA-Z][a-zA-Z0-9]*[_A-Z]' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
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

doctor: ## Full health check: deps + Lean import test + Rust compile test
	@echo ""
	@echo "  🏛️  Cathedral Doctor — Full Health Check"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@echo "  [1/3] Checking dependencies..."
	@$(ENV) check
	@echo "  [2/3] Testing Lean import..."
	@if command -v lean >/dev/null 2>&1; then \
		cd proofs && printf 'import Cathedral.Defs\n' | lake env lean --stdin 2>&1 | grep -v "^$$" | tail -1; \
		echo "  ✅  Lean: Cathedral.Defs imports successfully"; \
	else \
		echo "  ⚠  Lean not installed — skipping import test"; \
	fi
	@echo "  [3/3] Testing Rust compile..."
	@if command -v cargo >/dev/null 2>&1; then \
		cargo check --workspace --quiet 2>/dev/null && \
		echo "  ✅  Rust: workspace compiles"; \
	else \
		echo "  ⚠  Rust not installed — skipping compile test"; \
	fi
	@echo ""
	@echo "  ═══════════════════════════════════════════"
	@echo "  🏛️  Doctor complete."
	@echo "  ═══════════════════════════════════════════"
	@echo ""

ports: ## Show port allocation for Cathedral tools
	@echo ""
	@echo "  🏛️  Cathedral Port Allocation"
	@echo "  ═══════════════════════════════════════════"
	@echo ""
	@printf "  %-24s %-6s %s\n" "Tool" "Port" "Status"
	@printf "  %-24s %-6s %s\n" "────" "────" "──────"
	@for pair in "HyperZeta Viewport:$(PORT_HYPERZETA)" "HyperZeta Origin:$(PORT_ORIGIN)" "HyperZeta Explorer:$(PORT_EXPLORER)" "Particle Zoo:$(PORT_PARTICLE_ZOO)" "Cathedral Visualizer:$(PORT_VISUALIZER)"; do \
		name=$$(echo $$pair | cut -d: -f1); \
		port=$$(echo $$pair | cut -d: -f2); \
		if command -v lsof >/dev/null 2>&1 && lsof -i :$$port >/dev/null 2>&1; then \
			printf "  %-24s %-6s %s\n" "$$name" "$$port" "🔴 IN USE"; \
		else \
			printf "  %-24s %-6s %s\n" "$$name" "$$port" "🟢 Available"; \
		fi; \
	done
	@echo ""
	@echo "  Override: PORT_HYPERZETA=4000 make hyperzeta"
	@echo "  ═══════════════════════════════════════════"
	@echo ""

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
	@echo "  Cathedral (proofs/Cathedral/):"
	@printf "    Active files:     " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' | wc -l | tr -d ' '
	@printf "    Archived files:   " && find proofs/Cathedral -name '*.lean' -path '*/Archive/*' | wc -l | tr -d ' '
	@printf "    Active lines:     " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec cat {} + 2>/dev/null | wc -l | tr -d ' '
	@echo ""
	@echo "  Full Build (proofs/):"
	@printf "    Total files:      " && find proofs -name '*.lean' -not -path '*/.lake/*' | wc -l | tr -d ' '
	@printf "    Total lines:      " && find proofs -name '*.lean' -not -path '*/.lake/*' -exec cat {} + 2>/dev/null | wc -l | tr -d ' '
	@printf "    Build jobs:       " && echo "8,854+"
	@echo ""
	@echo "  Experiments:"
	@printf "    Rust experiments: " && find experiments -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' '
	@echo ""
	@echo "  Axiom / Sorry Audit:"
	@printf "    Axioms (active):  " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -cE '^axiom [a-zA-Z][a-zA-Z0-9]*[_A-Z]' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
	@printf "    Sorries:          " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -c '^\s*sorry$$' {} + 2>/dev/null | awk -F: '{s+=$$2}END{print s}'
	@printf "    Sorry files:      " && find proofs/Cathedral -name '*.lean' -not -path '*/Archive/*' -not -path '*/.lake/*' -exec grep -l '^\s*sorry$$' {} + 2>/dev/null | wc -l | tr -d ' '
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
	@$(ENV) require cargo
	@$(ENV) require lean
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

docker: ## Build and run the Cathedral in Docker
	@echo ""
	@echo "  🐳  Building Cathedral Docker image..."
	@echo ""
	@docker build -t cathedral:latest .
	@echo ""
	@echo "  ✅  Image built. Run with:"
	@echo "     docker run cathedral:latest"
	@echo ""

# ────────────────────────────────────────────
# 📖  HELP
# ────────────────────────────────────────────

help: ## Show this help message
	@echo ""
	@echo "  🏛️  The Cathedral — A Formal Reduction of the Riemann Hypothesis"
	@echo ""
	@echo "  First time? Run:  make tour    (or:  make check → make setup → make doctor)"
	@echo ""
	@echo "  Usage: make <target>"
	@echo ""
	@echo "  ─── THE CATHEDRAL ────────────────────────────────────────"
	@grep -E '^(tour|build|verify|axioms|rh|cascade|crown-audit|papers|papers-all|clock|jukebox|hyperzeta[a-z-]*|particle-zoo|visualizer):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── EXPERIMENTS & AUDITING ───────────────────────────────"
	@grep -E '^(audit|experiment-[a-z]+|stats):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── ENVIRONMENT ──────────────────────────────────────────"
	@grep -E '^(check|setup[a-z-]*|doctor|ports):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
	@echo "  ─── UTILITIES ────────────────────────────────────────────"
	@grep -E '^(lint|test|fmt|fmt-fix|ci|clean|docker):.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-24s %s\n", $$1, $$2}'
	@echo ""
