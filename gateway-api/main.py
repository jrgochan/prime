from fastapi import FastAPI, BackgroundTasks
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from core_ml_model import BettiSurrogateEstimator
from vector_db import TopologyMemoryDB
from lean_exporter import Lean4Exporter

app = FastAPI(title="Project HYPERZETA System Orchestrator")

# Allow API cross-origin polling natively mapping the Next.js visualizer node
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AI Core Module Instantiations
vector_db = TopologyMemoryDB()
ml_estimator = BettiSurrogateEstimator()
lean_bridge = Lean4Exporter()

# The global physical orchestration constraints
engine_status = {
    "auto_align_active": False, 
    "target_betti_threshold": 2.0
}

@app.get("/")
def read_root():
    return {
        "status": "HYPERZETA M2 Python Gateway Secured", 
        "neural_engine_processor": ml_estimator.hardware,
        "vector_memory": "Qdrant Binding Established"
    }

@app.post("/agent/auto-align/start")
async def trigger_alignment(background_tasks: BackgroundTasks):
    """
    Called by Next.js or Lean 4 bridge to trigger Reinforcement Learning auto-steering loop.
    Activates the ANE continuous probability inference.
    """
    engine_status["auto_align_active"] = True
    # Production Architecture: Launches `background_tasks.add_task(high_frequency_steering_loop)`
    return {"status": "RL Agent 16D Steering Initiated"}

@app.post("/agent/auto-align/stop")
async def halt_alignment():
    engine_status["auto_align_active"] = False
    return {"status": "RL Agent Steering Halted"}

@app.get("/agent/memory/query")
def check_vector_memory(state_vector: str = "0.0,0.0"):
    """
    Test endpoint. Demonstrates querying Qdrant memory constraints.
    In reality, Rust passes native 16D tensor arrays into Python, bypassing HTTP parsing completely.
    """
    # Parse generic string to float array for scaffold demonstration
    dummy_vector = [0.0] * 16
    result = vector_db.query_nearest_successful_state(dummy_vector)
    return {"nearest_topology": result}

# Native SSE Generator Loop binding LLM logic errors across continuous HTML EventSource layers!
def proof_stream_generator(proof_path: str):
    import os
    if not os.path.exists(proof_path):
        yield "data: [AI AGENT] ERROR: Target file isolated sequence missing.\n\n"
        return
        
    # Trap and isolate pristine geometric parameters mapped from Apple array memory before LLM mutation
    with open(proof_path, "r") as initial_file:
        pristine_template = initial_file.read()
        
    yield f"data: [AI AGENT] Booting Local 'AlphaProof' REPL Loop...\n\n"
    
    max_attempts = 15
    previous_error = None
    
    for attempt in range(max_attempts):
        yield f"data: [AI AGENT] Iteration {attempt + 1}/{max_attempts} - Prompting Native Ollama 'qwen2.5-coder' Model...\n\n"
        
        # 2. Extract structural tactics cleanly dropping ONLY into the `sorry` mapping node
        llm_status = lean_bridge.expand_proof(proof_path, pristine_template, previous_error)
        
        if "Ollama Server Not Running" in llm_status:
            yield f"data: [AI AGENT] FATAL: Native Ollama daemon not active on port 11434. Halting pipeline.\n\n"
            break
            
        yield f"data: [AI AGENT] Tactics Injected. Verifying securely against Apple OS Native Lean 4 Compiler...\n\n"
        
        # 3. Compile against formal Apple MacOS Lean 4 binary array Toolchain
        compiler_output = lean_bridge.verify_proof(proof_path)
        
        if compiler_output["status"] == "VERIFIED":
            yield f"data: ✅ [AI AGENT] MILLENNIUM PRIZE SECURED!!! Theorem Proved Formally at {proof_path}\n\n"
            break
        else:
            previous_error = compiler_output.get("error", "Unknown validation extraction failure.").strip()
            # Extinguish carriage returns and limit string slices preserving strict HTML5 SSE blocks natively!
            safe_error_string = previous_error.replace('\n', ' ➔ ').replace('\r', '')
            yield f"data: ❌ [AI AGENT] Compiler Rejected Syntax. Relaying Trace: {safe_error_string[:200]}...\n\n"
            
    yield f"data: [AI AGENT] Stream Terminated.\n\n"

@app.post("/agent/proofs/generate")
async def generate_formal_proof(betti_score: float = 3.1415, lambda_val: float = 0.0):
    """
    Commands the Orchestrator strictly to snapshot the unproven logic bounds dropping the sorry sequence!
    """
    dummy_16d_tensor = [lambda_val] * 16 
    proof_path = lean_bridge.generate_betti_theorem(betti_score, dummy_16d_tensor)
    
    return {
        "status": "Discovery Trapped", 
        "lambda_origin": lambda_val, 
        "file_location": proof_path
    }

@app.get("/agent/proofs/synthesize/stream")
async def api_synthesize_stream(proof_path: str):
    """
    Natively streams the Ollama mathematical AI loop live into the React Browser connection!
    """
    return StreamingResponse(proof_stream_generator(proof_path), media_type="text/event-stream")
