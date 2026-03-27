.PHONY: setup build-wasm build-api dev-ui dev-api clean check-env run-all

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

clean:
	@echo "=> Purging memory artifacts and builds..."
	@cd core-engine && cargo clean
	@rm -rf ui-viewport/.next ui-viewport/node_modules
	@rm -rf gateway-api/venv
	@rm -rf ui-viewport/public/wasm

check-env:
	@bash scripts/setup_env.sh
