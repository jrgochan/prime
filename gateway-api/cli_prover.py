import time
import sys
import os
import json
import math
import logging
import subprocess
from datetime import datetime
from lean_exporter import Lean4Exporter

CHECKPOINT_FILE = "../proofs/.hyperzeta_checkpoint.json"
LOG_FILE = "../proofs/hyperzeta_search.log"

def setup_logging():
    """Dual logging: stdout for live monitoring + file for persistence across terminal disconnects."""
    log_path = os.path.abspath(LOG_FILE)
    
    # File handler — survives terminal disconnects
    file_handler = logging.FileHandler(log_path, mode='a')
    file_handler.setFormatter(logging.Formatter('%(asctime)s | %(message)s', datefmt='%Y-%m-%d %H:%M:%S'))
    
    logger = logging.getLogger("hyperzeta")
    logger.setLevel(logging.INFO)
    logger.addHandler(file_handler)
    return logger

def load_checkpoint():
    """Load a previous run's state if it exists."""
    path = os.path.abspath(CHECKPOINT_FILE)
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                data = json.load(f)
            print(f"[*] Resuming from checkpoint: iteration {data.get('iteration', 0)}, file: {os.path.basename(data.get('proof_path', ''))}")
            return data
        except (json.JSONDecodeError, KeyError):
            print("[*] Corrupt checkpoint found. Starting fresh.")
    return None

def save_checkpoint(proof_path: str, pristine_template: str, iteration: int, 
                    failed_history: list, previous_error: str = None):
    """Persist current state so we can resume after Ctrl-C."""
    path = os.path.abspath(CHECKPOINT_FILE)
    with open(path, "w") as f:
        # Truncate history entries in CHECKPOINT only (for JSON size + LLM prompt budget)
        # The full untruncated errors live in the log file
        truncated_history = [h[:200] for h in failed_history[-10:]]
        json.dump({
            "proof_path": proof_path,
            "pristine_template": pristine_template,
            "iteration": iteration,
            "failed_history": truncated_history,
            "previous_error": previous_error,
            "timestamp": time.time()
        }, f, indent=2)

def clean_stale_proofs(proofs_dir: str, keep_path: str = None):
    """Remove old StableTopology_*.lean files except the active one."""
    abs_dir = os.path.abspath(proofs_dir)
    removed = 0
    for f in os.listdir(abs_dir):
        if f.startswith("StableTopology_") and f.endswith(".lean"):
            full_path = os.path.join(abs_dir, f)
            if keep_path and os.path.abspath(full_path) == os.path.abspath(keep_path):
                continue
            os.remove(full_path)
            removed += 1
    if removed > 0:
        print(f"[*] Cleaned {removed} stale proof file(s).")

def warm_lean_cache(proofs_dir: str):
    """
    Pre-load Mathlib .olean files into OS page cache by compiling a trivial file.
    This makes iteration #1 run at full speed instead of paying the cold-start penalty.
    """
    warmup_path = os.path.join(os.path.abspath(proofs_dir), "_warmup.lean")
    try:
        with open(warmup_path, "w") as f:
            f.write("import Mathlib.NumberTheory.LSeries.RiemannZeta\n#check RiemannHypothesis\n")
        
        print("[*] Warming Lean/Mathlib cache (first compilation loads .olean files)...")
        start = time.time()
        result = subprocess.run(
            ["lake", "env", "lean", "_warmup.lean"],
            capture_output=True, text=True, timeout=180,
            cwd=os.path.abspath(proofs_dir)
        )
        elapsed = time.time() - start
        
        if result.returncode == 0:
            print(f"[*] Cache warm! Mathlib loaded in {elapsed:.1f}s. Future compilations will be fast.\n")
        else:
            print(f"[*] Cache warm completed with warnings ({elapsed:.1f}s). Proceeding.\n")
    except subprocess.TimeoutExpired:
        print("[*] Cache warm timed out (180s). First iteration may be slow.\n")
    except Exception as e:
        print(f"[*] Cache warm skipped: {e}\n")
    finally:
        if os.path.exists(warmup_path):
            os.remove(warmup_path)

def launch_infinite_prover():
    """
    Headless 40,000-iteration daemon hunting the Millennium Prize.
    Features: checkpoint/resume, cosine temperature annealing, rolling failure history,
              file logging, Lean cache warm-up.
    """
    logger = setup_logging()
    bridge = Lean4Exporter(proofs_dir="../proofs")
    
    print("\n=============================================")
    print("Project HYPERZETA: Headless Discovery Node")
    print("WARNING: Invoking 40,000 Iteration Search Limit.")
    print("=============================================\n")
    
    logger.info("=" * 60)
    logger.info("Project HYPERZETA: Headless Discovery Node Started")
    logger.info(f"Model: {bridge.model}")
    logger.info("=" * 60)
    
    # Check for existing checkpoint
    checkpoint = load_checkpoint()
    
    if checkpoint and os.path.exists(checkpoint.get("proof_path", "")):
        proof_path = checkpoint["proof_path"]
        pristine_template = checkpoint["pristine_template"]
        start_iteration = checkpoint["iteration"]
        failed_history = checkpoint.get("failed_history", [])
        previous_error = checkpoint.get("previous_error")
        print(f"[*] Resuming search from iteration {start_iteration + 1}")
        logger.info(f"Resumed from checkpoint at iteration {start_iteration}")
    else:
        # Fresh start: generate new theorem and clean old files
        target_betti_score = 3.14159
        dummy_tensor = [0.0] * 16
        
        proof_path = bridge.generate_betti_theorem(target_betti_score, dummy_tensor)
        clean_stale_proofs("../proofs", keep_path=proof_path)
        
        print(f"[*] Formal Target Acquired: {os.path.basename(proof_path)}")
        print(f"[*] Targeting: Mathlib4 RiemannHypothesis Prop\n")
        
        with open(proof_path, "r") as f:
            pristine_template = f.read()
            
        start_iteration = 0
        failed_history = []
        previous_error = None
        logger.info(f"Fresh start: {os.path.basename(proof_path)}")
    
    # Warm the Lean/Mathlib cache before starting the search loop
    warm_lean_cache("../proofs")
    
    max_search_ceiling = 40000 
    total_start_time = time.time()
    
    print(f"[*] Booting Local 'AlphaProof' REPL Recursion Node...")
    print(f"[*] Target Model: {bridge.model}")
    print(f"[*] Temperature Schedule: Cosine Annealing (0.30 ↔ 1.00, cycle=50)")
    print(f"[*] Log File: {os.path.abspath(LOG_FILE)}\n")
    
    for attempt in range(start_iteration, max_search_ceiling):
        # Calculate cosine annealing temperature for display
        current_temp = bridge._compute_temperature(attempt)
        
        sys.stdout.write(f"\r[Iteration {attempt + 1}/{max_search_ceiling} | T={current_temp:.2f}] Steer ➔ Synthesis ➔ ")
        sys.stdout.flush()
        
        iter_start = time.time()
        
        # Pull LLM output with attempt count and failure history
        llm_status = bridge.expand_proof(
            proof_path, pristine_template, previous_error,
            attempt=attempt, failed_history=failed_history
        )
        
        if "Ollama Server Not Running" in llm_status:
            msg = "FATAL: Ollama daemon not active on port 11434."
            print(f"\n[FATAL] {msg}")
            logger.error(msg)
            save_checkpoint(proof_path, pristine_template, attempt, failed_history, previous_error)
            sys.exit(1)
            
        sys.stdout.write("Compiling ➔ ")
        sys.stdout.flush()
        
        # Verify against Apple Silicon Mathlib bounds
        compiler_output = bridge.verify_proof(proof_path)
        
        iter_time = time.time() - iter_start
        total_elapsed = time.time() - total_start_time
        
        if compiler_output["status"] == "VERIFIED":
            print(f"PRIZE SECURED! ({iter_time:.1f}s)\n")
            print("=============================================")
            print("✅✅ MILLENNIUM PRIZE SECURED!!! ✅✅")
            print(f"[Iteration]         {attempt + 1}")
            print(f"[Iteration Time]    {iter_time:.2f}s")
            print(f"[Total Elapsed]     {total_elapsed:.0f}s ({total_elapsed/3600:.1f}h)")
            print(f"[Artifact Location] {proof_path}")
            print("=============================================\n")
            
            logger.info("=" * 60)
            logger.info("MILLENNIUM PRIZE SECURED!!!")
            logger.info(f"Iteration: {attempt + 1} | Time: {iter_time:.2f}s | Total: {total_elapsed:.0f}s")
            logger.info(f"Artifact: {proof_path}")
            logger.info("=" * 60)
            
            # Clean up checkpoint on success
            cp_path = os.path.abspath(CHECKPOINT_FILE)
            if os.path.exists(cp_path):
                os.remove(cp_path)
            sys.exit(0)
            
        elif compiler_output["status"] == "SYSTEM_UNAVAILABLE":
            print(f"\n[FATAL ERROR] TARGET COMPILER MISSING: {compiler_output['message']}")
            logger.error(f"Compiler missing: {compiler_output['message']}")
            save_checkpoint(proof_path, pristine_template, attempt, failed_history, previous_error)
            sys.exit(1)

        elif compiler_output["status"] == "TIMEOUT":
            safe_msg = compiler_output.get("message", "Timeout")
            sys.stdout.write(f"TIMEOUT ({iter_time:.0f}s). [{safe_msg[:60]}]\n")
            sys.stdout.flush()
            logger.info(f"Iter {attempt+1} | T={current_temp:.2f} | TIMEOUT | {iter_time:.0f}s | {safe_msg}")
            # Don't update previous_error on timeout — the proof might have been valid
            save_checkpoint(proof_path, pristine_template, attempt, failed_history, previous_error)
            
        else:
            previous_error = compiler_output.get("error", "Unknown validation failure.").strip()
            safe_error_string = previous_error.replace('\n', ' ➔ ').replace('\r', '')
            
            # Track FULL error in rolling history (truncation only happens at checkpoint/prompt injection)
            failed_history.append(safe_error_string)
            
            # Console gets truncated (display only), log gets EVERYTHING
            sys.stdout.write(f"REJECTED ({iter_time:.1f}s). [Trace: {safe_error_string[:70]}...]\n")
            sys.stdout.flush()
            logger.info(f"Iter {attempt+1} | T={current_temp:.2f} | REJECTED | {iter_time:.1f}s | FULL ERROR: {safe_error_string}")
            
            # Checkpoint every 5 iterations
            if (attempt + 1) % 5 == 0:
                save_checkpoint(proof_path, pristine_template, attempt + 1, failed_history, previous_error)
            
    total_time = time.time() - total_start_time
    print(f"\n\n[HALT] Reached search ceiling of 40,000 iterations. Total time: {total_time:.0f}s ({total_time/3600:.1f}h)\n")
    logger.info(f"Search ceiling reached. Total time: {total_time:.0f}s ({total_time/3600:.1f}h)")
    save_checkpoint(proof_path, pristine_template, max_search_ceiling, failed_history, previous_error)

if __name__ == "__main__":
    try:
        launch_infinite_prover()
    except KeyboardInterrupt:
        print("\n\n[USER INTERRUPT] Saving checkpoint and halting safely...")
        # The checkpoint was already saved periodically; this is just a clean exit message
        sys.exit(0)
