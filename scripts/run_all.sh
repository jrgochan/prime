#!/bin/bash
# Project HYPERZETA Local Orchestrator

echo "[HYPERZETA CLUSTER] Initializing Dual-Server Boot sequence..."

# Trap CTRL-C and gracefully kill both the Python background job and the React foreground job
trap "kill 0" SIGINT

echo "=> [1/2] Spinning up FastAPI Core ML Neural Link (Port 8000)..."
cd gateway-api && source venv/bin/activate && uvicorn main:app --reload --port 8000 &
API_PID=$!

echo "=> [2/2] Spinning up Next.js WebGPU Shader Pipe (Port 3000)..."
cd ui-viewport && npm run dev &
UI_PID=$!

echo "------------------------------------------------------"
echo "[✔] HYPERZETA CLUSTER LIVE."
echo "VIEWPORT: http://localhost:3000"
echo "AI ROUTER: http://localhost:8000/docs"
echo "Press Ctrl+C to terminate both."
echo "------------------------------------------------------"

# Wait locks the script here to hold the cluster open
wait $API_PID $UI_PID
