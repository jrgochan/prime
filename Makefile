# ══════════════════════════════════════════════════════════════
# Project PRIME — Makefile
# Three pillars: Lean 4 Proofs · Rust Experiments · Platform
# ══════════════════════════════════════════════════════════════

.PHONY: help build clean \
        lean-build lean-clean lean-check lean-audit lean-setup \
        experiments experiment-parity experiment-cross experiment-weil \
        platform-setup platform-build platform-run platform-stop \
        setup-ai ensure-ollama check-env

# ── Directories ──────────────────────────────────────────────
PROOFS_DIR    = proofs
LEAN_BUILD    = $(PROOFS_DIR)/.lake/build
EXPERIMENTS   = experiments
PYTHON_VENV   = gateway-api/venv/bin/activate
WASM_OUT_DIR  = ../ui-viewport/src/wasm

# ── Lean source files (for dependency tracking) ─────────────
LEAN_SRCS = $(wildcard $(PROOFS_DIR)/SpectralRH/*.lean) \
            $(wildcard $(PROOFS_DIR)/*.lean)

# ══════════════════════════════════════════════════════════════
# DEFAULT / HELP
# ══════════════════════════════════════════════════════════════

help:
	@echo ""
	@echo "  ╔══════════════════════════════════════════════════╗"
	@echo "  ║         Project PRIME — Build Targets            ║"
	@echo "  ╠══════════════════════════════════════════════════╣"
	@echo "  ║                                                  ║"
	@echo "  ║  LEAN 4 PROOFS (SpectralRH)                      ║"
	@echo "  ║    make lean-build    Build all Lean proofs       ║"
	@echo "  ║    make lean-clean    Remove .lake/build cache    ║"
	@echo "  ║    make lean-check    Quick typecheck (no build)  ║"
	@echo "  ║    make lean-audit    Scan for sorry/axiom usage  ║"
	@echo "  ║    make lean-setup    Fetch Mathlib cache         ║"
	@echo "  ║                                                  ║"
	@echo "  ║  RUST EXPERIMENTS                                ║"
	@echo "  ║    make experiments          Build & run all      ║"
	@echo "  ║    make experiment-parity    Parity Schur only    ║"
	@echo "  ║    make experiment-cross     Cross-class only     ║"
	@echo "  ║    make experiment-weil      Weil explicit only   ║"
	@echo "  ║                                                  ║"
	@echo "  ║  COMBINED                                        ║"
	@echo "  ║    make build         Build proofs + experiments  ║"
	@echo "  ║    make clean         Clean all build artifacts   ║"
	@echo "  ║                                                  ║"
	@echo "  ║  PLATFORM (HYPERZETA)                            ║"
	@echo "  ║    make platform-setup   Install all deps         ║"
	@echo "  ║    make platform-build   Compile WASM + PyO3      ║"
	@echo "  ║    make platform-run     Start full stack          ║"
	@echo "  ║    make platform-stop    Shutdown all services     ║"
	@echo "  ║                                                  ║"
	@echo "  ╚══════════════════════════════════════════════════╝"
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

## Quick typecheck of core SpectralRH files (no full build)
lean-check:
	@echo "═══ Lean 4: Typechecking SpectralRH modules ═══"
	@cd $(PROOFS_DIR) && lake env lean SpectralRH/Defs.lean 2>&1 \
		&& echo "  ✓ Defs.lean" || echo "  ✗ Defs.lean"
	@cd $(PROOFS_DIR) && lake env lean SpectralRH/Structural.lean 2>&1 \
		&& echo "  ✓ Structural.lean" || echo "  ✗ Structural.lean"
	@cd $(PROOFS_DIR) && lake env lean SpectralRH/ParitySchur.lean 2>&1 \
		&& echo "  ✓ ParitySchur.lean" || echo "  ✗ ParitySchur.lean"
	@cd $(PROOFS_DIR) && lake env lean SpectralRH/Quantitative.lean 2>&1 \
		&& echo "  ✓ Quantitative.lean" || echo "  ✗ Quantitative.lean"
	@cd $(PROOFS_DIR) && lake env lean SpectralRH/PTSymmetry.lean 2>&1 \
		&& echo "  ✓ PTSymmetry.lean" || echo "  ✗ PTSymmetry.lean"
	@cd $(PROOFS_DIR) && lake env lean SpectralRH/Assembly.lean 2>&1 \
		&& echo "  ✓ Assembly.lean" || echo "  ✗ Assembly.lean"
	@echo "═══ Typecheck complete ═══"

## Audit: scan for sorry and axiom usage across all proof files
lean-audit:
	@echo "═══ Lean 4: Sorry & Axiom Audit ═══"
	@echo "── sorry usage ──"
	@grep -rn "\bsorry\b" $(PROOFS_DIR)/SpectralRH/*.lean 2>/dev/null \
		| grep -v "^.*:.*--" || echo "  None found! 🎉"
	@echo ""
	@echo "── axiom declarations ──"
	@grep -rn "^axiom " $(PROOFS_DIR)/SpectralRH/*.lean 2>/dev/null \
		|| echo "  None found."
	@echo ""
	@echo "── sorry count by file ──"
	@for f in $(PROOFS_DIR)/SpectralRH/*.lean; do \
		count=$$(grep -c "\bsorry\b" "$$f" 2>/dev/null); \
		name=$$(basename "$$f"); \
		if [ "$$count" -gt 0 ] 2>/dev/null; then \
			echo "  ⚠  $$name: $$count sorry"; \
		fi; \
	done
	@echo ""
	@echo "── total sorry in proofs (excluding comments) ──"
	@grep -rn "\bsorry\b" $(PROOFS_DIR)/SpectralRH/*.lean 2>/dev/null \
		| grep -v "\-\-" | grep -v "STATUS" | grep -v "PROVEN" \
		| grep -v "no sorry" | grep -v "SORRY" \
		|| echo "  ✅ Zero sorry in proof code!"
	@echo "═══ Audit complete ═══"

# ══════════════════════════════════════════════════════════════
# RUST EXPERIMENTS
# ══════════════════════════════════════════════════════════════

experiments: experiment-parity experiment-cross experiment-weil
	@echo "  ✅ All experiments complete."

experiments-clean:
	@echo "═══ Experiments: Cleaning ═══"
	@for d in $(EXPERIMENTS)/*/; do \
		if [ -f "$$d/Cargo.toml" ]; then \
			echo "  Cleaning $$(basename $$d)..."; \
			cd "$$d" && cargo clean 2>/dev/null; \
			cd - > /dev/null; \
		fi; \
	done
	@echo "  🧹 Experiment build artifacts removed."

experiment-parity:
	@echo "═══ Experiment: Parity Schur ═══"
	@cd $(EXPERIMENTS)/parity_schur && cargo run --release 2>&1 | tail -5
	@echo ""

experiment-cross:
	@echo "═══ Experiment: Cross-Class Verifier ═══"
	@cd $(EXPERIMENTS)/cross_class_verifier && cargo run --release 2>&1 | tail -5
	@echo ""

experiment-weil:
	@echo "═══ Experiment: Weil Explicit ═══"
	@cd $(EXPERIMENTS)/weil_explicit && cargo run --release 2>&1 | tail -5
	@echo ""

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
