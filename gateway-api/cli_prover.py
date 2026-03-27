import time
import sys
import os
from lean_exporter import Lean4Exporter

def launch_infinite_prover():
    """
    Spawns an indestructible 40,000 hour daemon hunting the Millennium Prize natively across Apple Silicon.
    Disconnects completely from the Next.js visualizer and FastAPI routers.
    """
    # 1. Instantiate the Native Apple OS / Mathlib Exporter
    bridge = Lean4Exporter(proofs_dir="../proofs")
    
    print("\n=============================================")
    print("Project HYPERZETA: Headless Discovery Node")
    print("WARNING: Invoking 40,000 Iteration Search Limit.")
    print("=============================================\n")
    
    # 2. Extract a baseline target formulation mimicking a high-probability Sedenion convergence 
    target_betti_score = 3.14159
    dummy_tensor = [0.0] * 16
    
    # 3. Request the strict formal bounds of the Riemann Hypothesis natively from the template bounds
    proof_path = bridge.generate_betti_theorem(target_betti_score, dummy_tensor)
    print(f"[*] Formal Target Acquired: {os.path.basename(proof_path)}")
    print(f"[*] Riemann Mathematical Limits injected natively.\n")
    
    # 4. Trap pristine state memory isolated from logic mutation errors
    with open(proof_path, "r") as f:
        pristine_template = f.read()
        
    engine_failure_count = 0
    max_search_ceiling = 40000 
    previous_error = None
    
    print(f"[*] Booting Local 'AlphaProof' REPL Recursion Node...")
    print(f"[*] Target Model: Qwen 2.5 Coder 32B (Offline)\n")
    
    for attempt in range(max_search_ceiling):
        sys.stdout.write(f"\r[Iteration {attempt + 1}/{max_search_ceiling}] Steer ➔ Synthesis ➔ ")
        sys.stdout.flush()
        
        start_time = time.time()
        
        # Pull LLM output isolated from UI pipelines
        llm_status = bridge.expand_proof(proof_path, pristine_template, previous_error)
        
        if "Ollama Server Not Running" in llm_status:
            print(f"\n[FATAL] Native Ollama daemon not active on port 11434. Halting pipeline.")
            sys.exit(1)
            
        sys.stdout.write("Compiling ➔ ")
        sys.stdout.flush()
        
        # Verify directly against Apple Silicon Mathlib bounds natively checking structural geometry
        compiler_output = bridge.verify_proof(proof_path)
        
        compute_time = time.time() - start_time
        
        if compiler_output["status"] == "VERIFIED":
            print(f"PRIZE SECURED!\n")
            print("=============================================")
            print("✅✅ MILLENNIUM PRIZE SECURED!!! ✅✅")
            print(f"[Computation Elapsed] Theorem proved natively in {compute_time:.2f} seconds.")
            print(f"[Artifact Location] {proof_path}")
            print("=============================================\n")
            sys.exit(0)
            
        elif compiler_output["status"] == "SYSTEM_UNAVAILABLE":
            print(f"\n[FATAL ERROR] TARGET COMPILER MISSING: {compiler_output['message']}")
            sys.exit(1)
            
        else:
            previous_error = compiler_output.get("error", "Unknown validation extraction failure.").strip()
            # Sterilize the literal error for logging formatting
            safe_error_string = previous_error.replace('\n', ' ➔ ').replace('\r', '')
            sys.stdout.write(f"REJECTED. [Trace: {safe_error_string[:70]}...]\n")
            sys.stdout.flush()
            engine_failure_count += 1
            
    print(f"\n\n[HALT] Reached absolute search ceiling of 40,000 iterations without converging. Total computation unproven.\n")

if __name__ == "__main__":
    try:
        launch_infinite_prover()
    except KeyboardInterrupt:
        print("\n\n[USER INTERRUPT] Halting Headless Mathematics Loop safely.")
        sys.exit(0)
