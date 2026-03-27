.PHONY: setup build-wasm build-api dev-ui dev-api clean check-env run-all setup-ai

# Project HYPERZETA Local Environment Logic
PYTHON_VENV = gateway-api/venv/bin/activate
WASM_OUT_DIR = ../ui-viewport/src/wasm

setup: check-env
	@echo "=> [1/3] Setting up Viewport Dependencies..."
	@cd ui-viewport && npm install
	@echo "=> [2/3] Setting up Python API Dependencies..."
	@cd gateway-api && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt maturin
	@echo "=> [3/3] Installing Rust cross-compilation tools..."
	@cargo install wasm-pack
	@echo "=> Setup Complete. Run 'make build-wasm' -> 'make build-api' -> 'make run-all'"

build-wasm:
	@echo "=> Compiling native Rust math engine into WebAssembly module..."
	@cd core-engine && wasm-pack build --target web --out-dir $(WASM_OUT_DIR)

build-api:
	@echo "=> Binding native M2 Rust libraries to Python explicitly via PyO3..."
	@cd core-engine && source ../$(PYTHON_VENV) && maturin develop --release

dev-ui:
	@echo "=> Spinning up Next.js / WebGPU Canvas..."
	@cd ui-viewport && npm run dev

dev-api:
	@echo "=> Spinning up FastAPI AI Router..."
	@cd gateway-api && source venv/bin/activate && uvicorn main:app --reload --port 8000

build-all: build-wasm build-api
	@echo "=> Native compilations successful for WebGPU and Python Gateway."

run-all:
	@echo "=> Deploying Local HYPERZETA Cluster..."
	@bash scripts/run_all.sh

run-infinity:
	@echo "=> Igniting Headless Millennium Search Protocol (40,000 Iteration Bound)..."
	@cd gateway-api && source venv/bin/activate && python cli_prover.py

clean:
	@echo "=> Purging memory artifacts and builds..."
	@cd core-engine && cargo clean
	@rm -rf ui-viewport/.next ui-viewport/node_modules
	@rm -rf gateway-api/venv
	@rm -rf ui-viewport/public/wasm

check-env:
	@bash scripts/setup_env.sh

setup-ai:
	@echo "=> Booting Native Ollama AI Theorem Matrix (Mac OS Local)..."
	@if ! command -v ollama >/dev/null 2>&1; then echo "Ollama not installed! Please run 'brew install ollama' or download from ollama.com."; exit 1; fi
	@echo "=> Utilizing 96GB Unified Memory Limits..."
	@echo "=> Pulling Qwen-2.5-Coder:32b (32 Billion Parameters) into isolated Local Storage..."
	@ollama pull qwen2.5-coder:32b
	@echo "=> Heavy Theorem Prover Model ready for autonomous offline execution!"

setup-mathlib:
	@echo "=> Initializing Lean 4 Mathlib Framework natively on Apple Silicon..."
	@cd proofs && lake update
	@cd proofs && lake exe cache get
	@echo "=> Mathlib4 successfully cached offline into /proofs library bounds!"

stop:
	@echo "=> Terminating Core Project HYPERZETA OS Pipelines..."
	@lsof -ti:8000 | xargs kill -9 2>/dev/null || true
	@lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	@echo "=> Stack successfully shutdown securely."
