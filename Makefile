# ══════════════════════════════════════════════════════════════
# Project PRIME — Makefile
# Five pillars: Lean 4 Proofs · Rust Experiments · Visualizer · Paper · Platform
# ══════════════════════════════════════════════════════════════

.PHONY: help build clean \
        lean-build lean-clean lean-check lean-audit lean-setup \
        cathedral-archive cathedral-dump cathedral-dump-split cathedral-audit cathedral-check \
        experiments experiments-clean \
        experiment-parity experiment-cross experiment-weil \
        experiment-g2 experiment-gcd experiment-selberg \
        experiment-fourier experiment-quaternion experiment-lambda-eff \
        visualizer visualizer-dev visualizer-build visualizer-parse \
        paper paper-technical paper-overview paper-clean \
        platform-setup platform-build platform-run platform-stop \
        setup-ai ensure-ollama check-env

# ── Directories ──────────────────────────────────────────────
PROOFS_DIR    = proofs
CATHEDRAL_DIR = $(PROOFS_DIR)/Cathedral
LEAN_BUILD    = $(PROOFS_DIR)/.lake/build
EXPERIMENTS   = experiments
VISUALIZER    = visualizer
PYTHON_VENV   = gateway-api/venv/bin/activate
WASM_OUT_DIR  = ../ui-viewport/src/wasm

# ── Lean source files (for dependency tracking) ─────────────
LEAN_SRCS = $(wildcard $(CATHEDRAL_DIR)/**/*.lean) \
            $(wildcard $(CATHEDRAL_DIR)/*.lean)

# ══════════════════════════════════════════════════════════════
# DEFAULT / HELP
# ══════════════════════════════════════════════════════════════

help:
	@echo ""
	@echo "  ╔══════════════════════════════════════════════════════╗"
	@echo "  ║           Project PRIME — Build Targets              ║"
	@echo "  ╠══════════════════════════════════════════════════════╣"
	@echo "  ║                                                      ║"
	@echo "  ║  LEAN 4 PROOFS                                       ║"
	@echo "  ║    make lean-build      Build all Lean proofs         ║"
	@echo "  ║    make lean-clean      Remove .lake/build cache      ║"
	@echo "  ║    make lean-check      Quick typecheck (Cathedral)   ║"
	@echo "  ║    make lean-audit      Scan for sorry/axiom usage    ║"
	@echo "  ║    make lean-setup      Fetch Mathlib cache           ║"
	@echo "  ║                                                      ║"
	@echo "  ║  CATHEDRAL (RH Proof Chain)                          ║"
	@echo "  ║    make cathedral-dump       Dump .lean → text file     ║"
	@echo "  ║    make cathedral-dump-split  Split dump for Gemini      ║"
	@echo "  ║    make cathedral-archive  Archive .tar.gz            ║"
	@echo "  ║    make cathedral-audit    Sorry & axiom scan         ║"
	@echo "  ║    make cathedral-check    Typecheck all modules      ║"
	@echo "  ║                                                      ║"
	@echo "  ║  RUST EXPERIMENTS                                    ║"
	@echo "  ║    make experiments           Build & run all         ║"
	@echo "  ║    make experiment-parity     Parity Schur analysis   ║"
	@echo "  ║    make experiment-cross      Cross-class verifier    ║"
	@echo "  ║    make experiment-weil       Weil explicit formula   ║"
	@echo "  ║    make experiment-g2         G₂ spectral operator    ║"
	@echo "  ║    make experiment-gcd        GCD sum audit           ║"
	@echo "  ║    make experiment-selberg    Selberg validation      ║"
	@echo "  ║    make experiment-fourier    Spectral Fourier        ║"
	@echo "  ║    make experiment-quaternion Quaternion RH            ║"
	@echo "  ║    make experiment-lambda-eff λ_eff linear growth      ║"
	@echo "  ║    make experiments-clean     Clean all Rust targets   ║"
	@echo "  ║                                                      ║"
	@echo "  ║  VISUALIZER (Cathedral Proof Explorer)               ║"
	@echo "  ║    make visualizer-dev    Start dev server (port 3000)║"
	@echo "  ║    make visualizer-build  Production build            ║"
	@echo "  ║    make visualizer-parse  Re-parse Lean dep graph     ║"
	@echo "  ║                                                      ║"
	@echo "  ║  PAPER                                               ║"
	@echo "  ║    make paper             Build all papers            ║"
	@echo "  ║    make paper-technical   cathedral.tex → pdf         ║"
	@echo "  ║    make paper-overview    overview.tex → pdf          ║"
	@echo "  ║    make paper-clean       Remove LaTeX artifacts      ║"
	@echo "  ║                                                      ║"
	@echo "  ║  COMBINED                                            ║"
	@echo "  ║    make build      Build proofs + experiments         ║"
	@echo "  ║    make clean      Clean all build artifacts          ║"
	@echo "  ║                                                      ║"
	@echo "  ║  PLATFORM (HYPERZETA)                                ║"
	@echo "  ║    make platform-setup   Install all deps             ║"
	@echo "  ║    make platform-build   Compile WASM + PyO3          ║"
	@echo "  ║    make platform-run     Start full stack              ║"
	@echo "  ║    make platform-stop    Shutdown all services         ║"
	@echo "  ║                                                      ║"
	@echo "  ╚══════════════════════════════════════════════════════╝"
	@echo ""

# ══════════════════════════════════════════════════════════════
# COMBINED TARGETS
# ══════════════════════════════════════════════════════════════

build: lean-build experiments
	@echo ""
	@echo "  ✅ All proofs and experiments built successfully."
	@echo ""

clean: lean-clean experiments-clean
	@echo ""
	@echo "  🧹 All build artifacts removed."
	@echo ""

# ══════════════════════════════════════════════════════════════
# LEAN 4 PROOFS
# ══════════════════════════════════════════════════════════════

## Fetch and cache Mathlib (run once or after toolchain update)
lean-setup:
	@echo "═══ Lean 4: Fetching Mathlib cache ═══"
	@cd $(PROOFS_DIR) && lake update
	@cd $(PROOFS_DIR) && lake exe cache get
	@echo "  ✅ Mathlib4 cached."

## Full build of all Lean proof modules
lean-build:
	@echo "═══ Lean 4: Building all proof modules ═══"
	@cd $(PROOFS_DIR) && lake build
	@echo "  ✅ All Lean proofs compiled."

## Remove all compiled Lean artifacts (forces full rebuild)
lean-clean:
	@echo "═══ Lean 4: Cleaning build cache ═══"
	@rm -rf $(LEAN_BUILD)
	@rm -rf $(PROOFS_DIR)/.lake/packages/*/lib
	@echo "  🧹 Lean build cache removed."
	@echo "  💡 Tip: Restart your IDE / Lean server to clear stale diagnostics."

## Quick typecheck of Cathedral proof chain
lean-check:
	@echo "═══ Lean 4: Typechecking Cathedral modules ═══"
	@cd $(PROOFS_DIR) && lake env lean Cathedral/Defs.lean 2>&1 \
		&& echo "  ✓ Cathedral/Defs.lean" || echo "  ✗ Cathedral/Defs.lean"
	@cd $(PROOFS_DIR) && lake env lean Cathedral/Mertens/GramBounds.lean 2>&1 \
		&& echo "  ✓ Mertens/GramBounds.lean" || echo "  ✗ Mertens/GramBounds.lean"
	@cd $(PROOFS_DIR) && lake env lean Cathedral/Mertens/GramSum.lean 2>&1 \
		&& echo "  ✓ Mertens/GramSum.lean" || echo "  ✗ Mertens/GramSum.lean"
	@cd $(PROOFS_DIR) && lake env lean Cathedral/Structural/Structural.lean 2>&1 \
		&& echo "  ✓ Structural/Structural.lean" || echo "  ✗ Structural/Structural.lean"
	@cd $(PROOFS_DIR) && lake env lean Cathedral/Structural/ParitySchur.lean 2>&1 \
		&& echo "  ✓ Structural/ParitySchur.lean" || echo "  ✗ Structural/ParitySchur.lean"
	@cd $(PROOFS_DIR) && lake env lean Cathedral/Assembly/MainChain.lean 2>&1 \
		&& echo "  ✓ Assembly/MainChain.lean" || echo "  ✗ Assembly/MainChain.lean"
	@echo "═══ Typecheck complete ═══"

## Audit: scan for sorry and axiom usage across all proof files
lean-audit:
	@echo "═══ Lean 4: Sorry & Axiom Audit ═══"
	@echo "── sorry usage ──"
	@grep -rn "\bsorry\b" $(CATHEDRAL_DIR)/**/*.lean $(CATHEDRAL_DIR)/*.lean 2>/dev/null \
		| grep -v "^.*:.*--" || echo "  None found! 🎉"
	@echo ""
	@echo "── axiom declarations ──"
	@grep -rn "^axiom " $(CATHEDRAL_DIR)/**/*.lean $(CATHEDRAL_DIR)/*.lean 2>/dev/null \
		|| echo "  None found."
	@echo ""
	@echo "── sorry count by file ──"
	@for f in $$(find $(CATHEDRAL_DIR) -name '*.lean'); do \
		count=$$(grep -c "\bsorry\b" "$$f" 2>/dev/null); \
		name=$$(echo "$$f" | sed 's|$(PROOFS_DIR)/||'); \
		if [ "$$count" -gt 0 ] 2>/dev/null; then \
			echo "  ⚠  $$name: $$count sorry"; \
		fi; \
	done
	@echo ""
	@echo "── axiom count ──"
	@total=$$(grep -rc "^axiom " $(CATHEDRAL_DIR)/**/*.lean $(CATHEDRAL_DIR)/*.lean 2>/dev/null | awk -F: '{s+=$$2} END{print s}'); \
		echo "  Total axioms: $$total"
	@echo ""
	@echo "═══ Audit complete ═══"

# ══════════════════════════════════════════════════════════════
# CATHEDRAL (RH Proof Chain)
# ══════════════════════════════════════════════════════════════

ARCHIVE_NAME = cathedral-archive-$(shell date +%Y%m%d-%H%M%S).tar.gz

## Create a .tar.gz archive of the entire Cathedral lean structure
cathedral-archive:
	@echo "═══ Cathedral: Creating archive ═══"
	@cd $(PROOFS_DIR) && tar czf ../$(ARCHIVE_NAME) \
		--exclude='.lake' \
		--exclude='*.olean' \
		--exclude='*.ilean' \
		--exclude='*.trace' \
		Cathedral/ \
		lakefile.lean \
		lean-toolchain
	@echo "  📦 Archive created: $(ARCHIVE_NAME)"
	@echo "  📊 Size: $$(du -h $(ARCHIVE_NAME) | cut -f1)"
	@echo "  📁 Contents:"
	@tar tzf $(ARCHIVE_NAME) | head -30
	@echo "  ..."
	@echo "  ✅ Cathedral archived."

## Dump all Cathedral .lean files into a single readable text file
## Perfect for sharing with The Theorist / pasting into AI chat
cathedral-dump:
	@echo "═══ Cathedral: Creating text dump ═══"
	@echo "# Cathedral Source Dump" > cathedral-dump.txt
	@echo "# Generated: $$(date)" >> cathedral-dump.txt
	@echo "# Project: prime/proofs/Cathedral" >> cathedral-dump.txt
	@echo "# Proof: Spectral Riemann Hypothesis (2-axiom reduction)" >> cathedral-dump.txt
	@echo "" >> cathedral-dump.txt
	@echo "# Architecture:" >> cathedral-dump.txt
	@echo "#   Cathedral/Defs.lean              - Core definitions" >> cathedral-dump.txt
	@echo "#   Cathedral/Mertens/               - Physics pillar (Gram bounds)" >> cathedral-dump.txt
	@echo "#   Cathedral/Structural/            - Proof structure (Schur, parity)" >> cathedral-dump.txt
	@echo "#   Cathedral/MellinBridge/          - Spectral pillar (Mellin, separation)" >> cathedral-dump.txt
	@echo "#   Cathedral/Quantitative/          - Quantitative estimates" >> cathedral-dump.txt
	@echo "#   Cathedral/Assembly/              - Final RH assembly" >> cathedral-dump.txt
	@echo "#   Cathedral/Spectral/              - Exploratory (off critical path)" >> cathedral-dump.txt
	@echo "#   Cathedral/Robin/                 - Discrete front (Robin/Lagarias)" >> cathedral-dump.txt
	@echo "" >> cathedral-dump.txt
	@find $(CATHEDRAL_DIR) -name "*.lean" -not -path "*/.lake/*" | sort | while read file; do \
		relpath=$$(echo "$$file" | sed 's|$(PROOFS_DIR)/||'); \
		echo "" >> cathedral-dump.txt; \
		echo "════════════════════════════════════════════════" >> cathedral-dump.txt; \
		echo "FILE: $$relpath" >> cathedral-dump.txt; \
		echo "════════════════════════════════════════════════" >> cathedral-dump.txt; \
		echo "" >> cathedral-dump.txt; \
		cat "$$file" >> cathedral-dump.txt; \
		echo "" >> cathedral-dump.txt; \
	done
	@echo "" >> cathedral-dump.txt
	@echo "════════════════════════════════════════════════" >> cathedral-dump.txt
	@echo "FILE: lakefile.lean" >> cathedral-dump.txt
	@echo "════════════════════════════════════════════════" >> cathedral-dump.txt
	@echo "" >> cathedral-dump.txt
	@cat $(PROOFS_DIR)/lakefile.lean >> cathedral-dump.txt
	@echo "  📄 Dump created: cathedral-dump.txt"
	@echo "  📊 Size: $$(du -h cathedral-dump.txt | cut -f1)"
	@echo "  📝 Files included: $$(grep -c '^FILE:' cathedral-dump.txt)"
	@echo "  📐 Lines: $$(wc -l < cathedral-dump.txt | tr -d ' ')"
	@echo "  ✅ Ready to share with The Theorist!"

## Dump Cathedral .lean files into multiple text files (one per component)
## Each file is small enough to upload to Gemini / Claude / ChatGPT
cathedral-dump-split:
	@echo "═══ Cathedral: Creating split dump ═══"
	@mkdir -p cathedral-parts
	@rm -f cathedral-parts/*.txt
	@# Header for each file
	@for component in Core LinearAlgebra VasyuninDefs VasyuninGram VasyuninCov VasyuninTelescope VasyuninBridge Robin; do \
		outfile="cathedral-parts/cathedral-$$component.txt"; \
		echo "# Cathedral Source - $$component" > "$$outfile"; \
		echo "# Generated: $$(date)" >> "$$outfile"; \
		echo "# Project: prime/proofs/Cathedral" >> "$$outfile"; \
		echo "# Proof: Spectral Riemann Hypothesis" >> "$$outfile"; \
		echo "# Build: lake build Cathedral (6 axioms, 1 sorry)" >> "$$outfile"; \
		echo "" >> "$$outfile"; \
	done
	@# Sort files into components
	@find $(CATHEDRAL_DIR) -name "*.lean" -not -path "*/.lake/*" -not -path "*Archive*" | sort | while read file; do \
		relpath=$$(echo "$$file" | sed 's|$(PROOFS_DIR)/||'); \
		component="Core"; \
		case "$$relpath" in \
			*LinearAlgebra*) component="LinearAlgebra" ;; \
			*Vasyunin/Defs*|*Vasyunin/Structural*) component="VasyuninDefs" ;; \
			*Vasyunin/GramEntries*|*Vasyunin/GramEvaluations*|*Vasyunin/GramPSD*|*Vasyunin/AugmentedGram*|*Vasyunin/NbDistPos*|*Vasyunin/GramInduction*) component="VasyuninGram" ;; \
			*Vasyunin/CovEntries*|*Vasyunin/CovDet2*|*Vasyunin/CovDet3*) component="VasyuninCov" ;; \
			*Vasyunin/DigammaReflection*|*Vasyunin/TelescopeSum*|*Vasyunin/LogDigammaBridge*|*Vasyunin/OffDiagPartition*|*Vasyunin/CrossTermFTC*|*Vasyunin/VasyuninAssembly*) component="VasyuninTelescope" ;; \
			*Vasyunin/Witness*|*Vasyunin/Rayleigh*|*Vasyunin/Chain*|*Vasyunin/LinIndep*|*Vasyunin/FractIntegral*|*Vasyunin/NbDistPos2*|*Vasyunin/NbDistPos3*|*Vasyunin/StirlingBridge*|*Vasyunin/IntegralBridge*|*Vasyunin/DiagonalBridge*|*Vasyunin/MeanIntegral*|*Vasyunin/PiecewiseFTC*|*Vasyunin/SqueezeElimination*|*MellinBridge/Vasyunin.lean) component="VasyuninBridge" ;; \
			*MellinBridge*) component="Core" ;; \
			*Robin*) component="Robin" ;; \
			*Defs*) component="Core" ;; \
		esac; \
		outfile="cathedral-parts/cathedral-$$component.txt"; \
		echo "" >> "$$outfile"; \
		echo "================================================================" >> "$$outfile"; \
		echo "FILE: $$relpath" >> "$$outfile"; \
		echo "================================================================" >> "$$outfile"; \
		echo "" >> "$$outfile"; \
		cat "$$file" >> "$$outfile"; \
		echo "" >> "$$outfile"; \
	done
	@# Add lakefile to Core
	@echo "" >> cathedral-parts/cathedral-Core.txt
	@echo "================================================================" >> cathedral-parts/cathedral-Core.txt
	@echo "FILE: lakefile.lean" >> cathedral-parts/cathedral-Core.txt
	@echo "================================================================" >> cathedral-parts/cathedral-Core.txt
	@echo "" >> cathedral-parts/cathedral-Core.txt
	@cat $(PROOFS_DIR)/lakefile.lean >> cathedral-parts/cathedral-Core.txt
	@# Summary
	@echo ""
	@echo "  📁 Files created in cathedral-parts/:"
	@for f in cathedral-parts/*.txt; do \
		name=$$(basename "$$f"); \
		size=$$(du -h "$$f" | cut -f1); \
		lines=$$(wc -l < "$$f" | tr -d ' '); \
		files=$$(grep -c '^FILE:' "$$f" 2>/dev/null || echo 0); \
		echo "     $$name  ($$size, $$lines lines, $$files files)"; \
	done
	@echo ""
	@echo "  ✅ Upload all files to Gemini Deep Think!"

## Audit Cathedral proof chain: sorry count, axiom scan, RH dependencies
cathedral-audit:
	@echo "═══ Cathedral: Proof Chain Audit ═══"
	@echo ""
	@echo "── sorry usage (Mertens/ — should be zero) ──"
	@grep -rn "\bsorry\b" $(CATHEDRAL_DIR)/Mertens/*.lean 2>/dev/null \
		| grep -v "\-\-" || echo "  ✅ Zero sorry in Mertens/!"
	@echo ""
	@echo "── sorry usage (all modules) ──"
	@for d in Mertens Structural MellinBridge Quantitative Assembly Spectral Robin; do \
		count=$$(grep -rc "\bsorry\b" $(CATHEDRAL_DIR)/$$d/*.lean 2>/dev/null | awk -F: '{s+=$$2} END{print s+0}'); \
		if [ "$$count" -gt 0 ]; then \
			echo "  ⚠  $$d/: $$count sorry"; \
		else \
			echo "  ✅ $$d/: 0 sorry"; \
		fi; \
	done
	@echo ""
	@echo "── axiom declarations (critical path) ──"
	@grep -rn "^axiom " $(CATHEDRAL_DIR)/Mertens/*.lean $(CATHEDRAL_DIR)/MellinBridge/*.lean 2>/dev/null \
		|| echo "  None outside critical path."
	@echo ""
	@echo "── axiom declarations (all files) ──"
	@grep -rn "^axiom " $(CATHEDRAL_DIR)/**/*.lean $(CATHEDRAL_DIR)/*.lean 2>/dev/null \
		|| echo "  None found."
	@echo ""
	@echo "═══ Cathedral audit complete ═══"

## Typecheck all Cathedral modules (builds the full proof chain)
cathedral-check:
	@echo "═══ Cathedral: Typechecking all modules ═══"
	@cd $(PROOFS_DIR) && lake build Cathedral.Assembly.MainChain 2>&1 | tail -5
	@echo ""
	@echo "── RH axiom dependencies ──"
	@cd $(PROOFS_DIR) && echo 'import Cathedral.Assembly.MainChain' \
		| lake env lean --stdin 2>&1 | grep -A 10 "depends on axioms"
	@echo ""
	@echo "═══ Cathedral typecheck complete ═══"

# ══════════════════════════════════════════════════════════════
# PAPER
# ══════════════════════════════════════════════════════════════

PAPER_DIR = paper

## Build all papers (technical + overview)
paper: paper-technical paper-overview
	@echo "═══ All papers built ═══"

## Build the technical paper (cathedral.tex → cathedral.pdf)
paper-technical:
	@echo "═══ Building technical paper ═══"
	cd $(PAPER_DIR) && pdflatex -interaction=nonstopmode cathedral.tex
	cd $(PAPER_DIR) && pdflatex -interaction=nonstopmode cathedral.tex
	@echo "  → $(PAPER_DIR)/cathedral.pdf"

## Build the overview paper (overview.tex → overview.pdf)
paper-overview:
	@echo "═══ Building overview paper ═══"
	cd $(PAPER_DIR) && pdflatex -interaction=nonstopmode overview.tex
	cd $(PAPER_DIR) && pdflatex -interaction=nonstopmode overview.tex
	@echo "  → $(PAPER_DIR)/overview.pdf"

## Clean LaTeX build artifacts
paper-clean:
	@echo "Cleaning paper build artifacts..."
	cd $(PAPER_DIR) && rm -f *.aux *.log *.out *.toc *.bbl *.blg \
		*.fdb_latexmk *.fls *.synctex.gz
	@echo "Done."

# ══════════════════════════════════════════════════════════════
# RUST EXPERIMENTS
# ══════════════════════════════════════════════════════════════

## Build and run all Rust experiments
experiments: experiment-parity experiment-g2 experiment-cross \
             experiment-weil experiment-gcd experiment-selberg
	@echo "  ✅ All experiments complete."

## Clean all Rust experiment build artifacts
experiments-clean:
	@echo "═══ Experiments: Cleaning ═══"
	@find $(EXPERIMENTS) -name "Cargo.toml" -exec dirname {} \; | while read d; do \
		echo "  Cleaning $$(basename $$d)..."; \
		cd "$$d" && cargo clean 2>/dev/null; \
		cd - > /dev/null; \
	done
	@echo "  🧹 Experiment build artifacts removed."

# ── Spectral ─────────────────────────────────────────────────

experiment-parity:
	@echo "═══ Experiment: Parity Schur ═══"
	@cd $(EXPERIMENTS)/spectral/parity-schur && cargo run --release 2>&1 | tail -10
	@echo ""

experiment-g2:
	@echo "═══ Experiment: G₂ Spectral Operator ═══"
	@cd $(EXPERIMENTS)/spectral/g2-spectral && cargo run --release 2>&1 | tail -10
	@echo ""

experiment-fourier:
	@echo "═══ Experiment: Spectral Fourier ═══"
	@cd $(EXPERIMENTS)/spectral/spectral-fourier && cargo run --release 2>&1 | tail -10
	@echo ""

experiment-lambda-eff:
	@echo "═══ Experiment: λ_eff Linear Growth ═══"
	@echo "  Modes: validate | medium | high | ultra | <N>"
	@cd $(EXPERIMENTS)/spectral/lambda-eff && cargo run --release -- $(or $(MODE),medium) 2>&1
	@echo ""

# ── Algebraic ────────────────────────────────────────────────

experiment-cross:
	@echo "═══ Experiment: Cross-Class Verifier ═══"
	@cd $(EXPERIMENTS)/algebraic/cross-class-verifier && cargo run --release 2>&1 | tail -10
	@echo ""

experiment-quaternion:
	@echo "═══ Experiment: Quaternion RH ═══"
	@cd $(EXPERIMENTS)/algebraic/quaternion-rh && cargo run --release 2>&1 | tail -10
	@echo ""

# ── Gram Matrix ──────────────────────────────────────────────

experiment-gcd:
	@echo "═══ Experiment: GCD Sum Audit ═══"
	@cd $(EXPERIMENTS)/gram-matrix/gcd-sum-audit && cargo run --release 2>&1 | tail -10
	@echo ""

experiment-selberg:
	@echo "═══ Experiment: Selberg Validation ═══"
	@cd $(EXPERIMENTS)/gram-matrix/selberg-validation && cargo run --release 2>&1 | tail -10
	@echo ""

# ── Numerical ────────────────────────────────────────────────

experiment-weil:
	@echo "═══ Experiment: Weil Explicit Formula ═══"
	@cd $(EXPERIMENTS)/numerical/weil-explicit && cargo run --release 2>&1 | tail -10
	@echo ""

# ══════════════════════════════════════════════════════════════
# VISUALIZER (Cathedral Proof Explorer)
# ══════════════════════════════════════════════════════════════

## Start the visualizer dev server (Next.js on port 3000)
visualizer-dev:
	@echo "═══ Visualizer: Starting dev server ═══"
	@echo "  → http://localhost:3000"
	@cd $(VISUALIZER) && npm run dev

## Build the visualizer for production
visualizer-build:
	@echo "═══ Visualizer: Production build ═══"
	@cd $(VISUALIZER) && npm run build
	@echo "  ✅ Visualizer built."

## Re-parse Lean files to update the proof dependency graph
visualizer-parse:
	@echo "═══ Visualizer: Parsing Lean dependency graph ═══"
	@cd $(VISUALIZER) && node scripts/parse-lean.mjs
	@echo "  ✅ Dependency graph updated."

# ══════════════════════════════════════════════════════════════
# PLATFORM (HYPERZETA) — UI, API, Ollama
# ══════════════════════════════════════════════════════════════

platform-setup: check-env
	@echo "═══ Platform: Setting up dependencies ═══"
	@echo "  [1/3] Viewport (Next.js)..."
	@cd ui-viewport && npm install
	@echo "  [2/3] Gateway API (Python)..."
	@cd gateway-api && python3 -m venv venv \
		&& source venv/bin/activate \
		&& pip install -r requirements.txt maturin
	@echo "  [3/3] Rust → WASM toolchain..."
	@cargo install wasm-pack
	@echo "  ✅ Platform setup complete."

platform-build:
	@echo "═══ Platform: Building WASM + PyO3 ═══"
	@cd core-engine && wasm-pack build --target web --out-dir $(WASM_OUT_DIR)
	@cd core-engine && source ../$(PYTHON_VENV) && maturin develop --release
	@echo "  ✅ Platform build complete."

platform-run: ensure-ollama
	@echo "═══ Platform: Starting full stack ═══"
	@bash scripts/run_all.sh

platform-stop:
	@echo "═══ Platform: Shutting down ═══"
	@lsof -ti:8000 | xargs kill -9 2>/dev/null || true
	@lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	@pkill -x ollama 2>/dev/null || true
	@echo "  ✅ All services stopped."

# ── Utilities ────────────────────────────────────────────────

check-env:
	@bash scripts/setup_env.sh

ensure-ollama:
	@if ! pgrep -x ollama > /dev/null 2>&1; then \
		echo "  Starting Ollama..."; \
		ollama serve > /dev/null 2>&1 & \
		for i in $$(seq 1 15); do \
			if curl -s http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then \
				echo "  Ollama ready!"; \
				break; \
			fi; \
			sleep 1; \
		done; \
	else \
		echo "  Ollama already running."; \
	fi

setup-ai:
	@echo "═══ AI: Pulling Qwen-2.5-Coder:32b ═══"
	@command -v ollama >/dev/null 2>&1 || { echo "Ollama not installed!"; exit 1; }
	@ollama pull qwen2.5-coder:32b
	@echo "  ✅ Model ready."
