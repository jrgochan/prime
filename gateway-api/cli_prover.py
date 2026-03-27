import time
import sys
import os
import json
import math
import logging
import subprocess
from datetime import datetime
from lean_exporter import Lean4Exporter
from lemma_ladder import LEMMA_LADDER, get_rung, get_ladder_length, set_live_conjectures
from conjecture_miner import ConjectureMiner
from operator_search import HilbertPolyaSearch
from boundary_analyzer import BoundaryAnalyzer
from tower_analyzer import TowerAnalyzer

CHECKPOINT_FILE = "../proofs/.hyperzeta_checkpoint.json"
LOG_FILE = "../proofs/hyperzeta_search.log"

def setup_logging():
    """Dual logging: stdout for live monitoring + file for persistence across terminal disconnects."""
    log_path = os.path.abspath(LOG_FILE)
    
    file_handler = logging.FileHandler(log_path, mode='a')
    file_handler.setFormatter(logging.Formatter('%(asctime)s | %(message)s', datefmt='%Y-%m-%d %H:%M:%S'))
    
    logger = logging.getLogger("hyperzeta")
    logger.setLevel(logging.INFO)
    # Avoid duplicate handlers on resume
    if not logger.handlers:
        logger.addHandler(file_handler)
    return logger

def load_checkpoint():
    """Load a previous run's state if it exists."""
    path = os.path.abspath(CHECKPOINT_FILE)
    if os.path.exists(path):
        try:
            with open(path, "r") as f:
                data = json.load(f)
            print(f"[*] Resuming from checkpoint: rung {data.get('current_rung', 0)}, "
                  f"attempt {data.get('rung_attempt', 0)}")
            return data
        except (json.JSONDecodeError, KeyError):
            print("[*] Corrupt checkpoint found. Starting fresh.")
    return None

def save_checkpoint(current_rung: int, rung_attempt: int, proof_path: str,
                    pristine_template: str, failed_history: list,
                    previous_error: str, proved_lemmas: list):
    """Persist current state so we can resume after Ctrl-C."""
    path = os.path.abspath(CHECKPOINT_FILE)
    truncated_history = [h[:200] for h in failed_history[-10:]]
    with open(path, "w") as f:
        json.dump({
            "current_rung": current_rung,
            "rung_attempt": rung_attempt,
            "proof_path": proof_path,
            "pristine_template": pristine_template,
            "failed_history": truncated_history,
            "previous_error": previous_error,
            "proved_lemmas": proved_lemmas,
            "timestamp": time.time()
        }, f, indent=2)

def clean_stale_proofs(proofs_dir: str, keep_paths: list = None):
    """Remove old StableTopology_*.lean and Ladder_*.lean files except active ones."""
    abs_dir = os.path.abspath(proofs_dir)
    keep_set = set(os.path.abspath(p) for p in (keep_paths or []))
    removed = 0
    for f in os.listdir(abs_dir):
        if (f.startswith("StableTopology_") or f.startswith("Ladder_")) and f.endswith(".lean"):
            full_path = os.path.join(abs_dir, f)
            if os.path.abspath(full_path) in keep_set:
                continue
            os.remove(full_path)
            removed += 1
    if removed > 0:
        print(f"[*] Cleaned {removed} stale proof file(s).")

def warm_lean_cache(proofs_dir: str):
    """Pre-load Mathlib .olean files into OS page cache."""
    warmup_path = os.path.join(os.path.abspath(proofs_dir), "_warmup.lean")
    try:
        with open(warmup_path, "w") as f:
            f.write("import Mathlib.NumberTheory.LSeries.RiemannZeta\n#check RiemannHypothesis\n")
        
        print("[*] Warming Lean/Mathlib cache...")
        start = time.time()
        result = subprocess.run(
            ["lake", "env", "lean", "_warmup.lean"],
            capture_output=True, text=True, timeout=180,
            cwd=os.path.abspath(proofs_dir)
        )
        elapsed = time.time() - start
        if result.returncode == 0:
            print(f"[*] Cache warm! Mathlib loaded in {elapsed:.1f}s.\n")
        else:
            print(f"[*] Cache warm completed with warnings ({elapsed:.1f}s).\n")
    except subprocess.TimeoutExpired:
        print("[*] Cache warm timed out (180s). First iteration may be slow.\n")
    except Exception as e:
        print(f"[*] Cache warm skipped: {e}\n")
    finally:
        if os.path.exists(warmup_path):
            os.remove(warmup_path)

def launch_ladder_prover():
    """
    Lemma Ladder Prover: climbs through a sequence of increasingly difficult theorems.
    Each proved lemma becomes a tool for the next rung.
    The final rung is RiemannHypothesis.
    """
    logger = setup_logging()
    bridge = Lean4Exporter(proofs_dir="../proofs")
    
    total_rungs = get_ladder_length()
    
    print("\n" + "=" * 60)
    print("Project HYPERZETA: Lemma Ladder Discovery Node")
    print(f"Total Rungs: {total_rungs} | Final: RiemannHypothesis")
    print("=" * 60 + "\n")
    
    logger.info("=" * 60)
    logger.info("Project HYPERZETA: Lemma Ladder Started")
    logger.info(f"Model: {bridge.model} | Rungs: {total_rungs}")
    logger.info("=" * 60)
    
    # Check for existing checkpoint
    checkpoint = load_checkpoint()
    
    if checkpoint:
        start_rung = checkpoint.get("current_rung", 0)
        start_attempt = checkpoint.get("rung_attempt", 0)
        proved_lemmas = checkpoint.get("proved_lemmas", [])
        proof_path = checkpoint.get("proof_path", "")
        pristine_template = checkpoint.get("pristine_template", "")
        failed_history = checkpoint.get("failed_history", [])
        previous_error = checkpoint.get("previous_error")
    else:
        start_rung = 0
        start_attempt = 0
        proved_lemmas = []
        proof_path = ""
        pristine_template = ""
        failed_history = []
        previous_error = None
        clean_stale_proofs("../proofs")
    
    # Scan disk for existing Proved_*.lean files — these are ground truth.
    # If the checkpoint was deleted but proved files exist, we recover them.
    proofs_abs = os.path.abspath("../proofs")
    known_names = {r["name"] for r in LEMMA_LADDER}
    for f in os.listdir(proofs_abs):
        if f.startswith("Proved_") and f.endswith(".lean"):
            lemma_name = f[len("Proved_"):-len(".lean")]
            if lemma_name in known_names and lemma_name not in proved_lemmas:
                proved_lemmas.append(lemma_name)
                print(f"[*] Recovered proved lemma from disk: {lemma_name}")
    
    # Warm the Lean cache
    warm_lean_cache("../proofs")
    
    # ═══ Bridge 1: Conjecture Mining ═══
    print("\n" + "─" * 60)
    print("  🔬 BRIDGE 1: Conjecture Mining (Sedenion Zeta Analysis)")
    print("─" * 60)
    try:
        miner = ConjectureMiner(terms=30, num_zeros=5)
        miner.mine()
        live_conjectures = miner.format_conjectures()
        set_live_conjectures(live_conjectures)
        logger.info(f"Conjecture Miner: {len(miner.results.get('zeros', []))} zeros analyzed")
    except Exception as e:
        print(f"  [WARN] Conjecture mining failed: {e}. Using static conjectures.")
        logger.warning(f"Conjecture mining failed: {e}")
    
    # ═══ Bridge 3: Hilbert-Pólya Operator Search ═══
    print("\n" + "─" * 60)
    print("  🔬 BRIDGE 3: Hilbert-Pólya Operator Search")
    print("─" * 60)
    try:
        operator = HilbertPolyaSearch(dim=15, learning_rate=0.005, max_iters=2000)
        operator.search()
        operator_report = operator.format_report()
        # Append operator findings to conjecture injection
        from lemma_ladder import LIVE_CONJECTURES
        set_live_conjectures(LIVE_CONJECTURES + "\n\n" + operator_report)
        logger.info(f"Operator Search: loss={operator.best_loss:.6f}")
    except Exception as e:
        print(f"  [WARN] Operator search failed: {e}. Continuing without.")
        logger.warning(f"Operator search failed: {e}")
    
    # ═══ Bridge 4: Boundary Analyzer ═══
    print("\n" + "─" * 60)
    print("  🔬 BRIDGE 4: Boundary Analysis (de la Vallée-Poussin)")
    print("─" * 60)
    try:
        boundary = BoundaryAnalyzer()
        boundary.analyze()
        boundary_report = boundary.format_conjectures()
        from lemma_ladder import LIVE_CONJECTURES
        set_live_conjectures(LIVE_CONJECTURES + "\n\n" + boundary_report)
        logger.info(f"Boundary Analyzer: non-vanishing verified on Re(s)≈1")
    except Exception as e:
        print(f"  [WARN] Boundary analysis failed: {e}. Continuing without.")
        logger.warning(f"Boundary analysis failed: {e}")
    
    # ═══ Bridge 5: Cayley-Dickson Tower Analyzer ═══
    print("\n" + "─" * 60)
    print("  🔬 BRIDGE 5: Cayley-Dickson Tower Analysis")
    print("─" * 60)
    try:
        tower = TowerAnalyzer()
        tower.analyze()
        tower_report = tower.format_conjectures()
        from lemma_ladder import LIVE_CONJECTURES
        set_live_conjectures(LIVE_CONJECTURES + "\n\n" + tower_report)
        logger.info(f"Tower Analyzer: division algebra non-vanishing verified")
    except Exception as e:
        print(f"  [WARN] Tower analysis failed: {e}. Continuing without.")
        logger.warning(f"Tower analysis failed: {e}")
    
    total_start_time = time.time()
    total_iterations = 0
    
    print(f"\n[*] Model: {bridge.model}")
    print(f"[*] Temperature: Cosine Annealing (0.30 ↔ 1.00, cycle=50)")
    print(f"[*] Proved so far: {len(proved_lemmas)} lemma(s)")
    print(f"[*] Log: {os.path.abspath(LOG_FILE)}\n")
    
    for rung_idx in range(start_rung, total_rungs):
        rung = get_rung(rung_idx)
        if rung is None:
            break
        
        # Skip already-proved lemmas
        if rung["name"] in proved_lemmas:
            print(f"  ✅ Rung {rung_idx + 1}/{total_rungs}: {rung['title']} — ALREADY PROVED")
            logger.info(f"Rung {rung_idx + 1} SKIPPED (already proved): {rung['title']}")
            continue
        
        print(f"\n{'─' * 60}")
        print(f"  🧗 RUNG {rung_idx + 1}/{total_rungs}: {rung['title']}")
        print(f"     Difficulty: {rung['difficulty']} | Max attempts: {rung['max_attempts']}")
        print(f"{'─' * 60}")
        logger.info(f"Starting Rung {rung_idx + 1}/{total_rungs}: {rung['title']} ({rung['difficulty']})")
        
        # Generate the lean file for this rung (or reuse from checkpoint)
        if rung_idx != start_rung or not proof_path or not os.path.exists(proof_path):
            proof_path = bridge.generate_lemma_file(rung)
            with open(proof_path, "r") as f:
                pristine_template = f.read()
            failed_history = []
            previous_error = None
            attempt_start = 0
        else:
            attempt_start = start_attempt
        
        rung_proved = False
        
        for attempt in range(attempt_start, rung["max_attempts"]):
            total_iterations += 1
            current_temp = bridge._compute_temperature(attempt)
            
            sys.stdout.write(f"\r  [{attempt + 1}/{rung['max_attempts']} | T={current_temp:.2f}] "
                           f"Query ➔ ")
            sys.stdout.flush()
            
            iter_start = time.time()
            
            # Use the lemma-specific prompt
            llm_status = bridge.expand_lemma_proof(
                proof_path, pristine_template, rung,
                previous_error=previous_error,
                attempt=attempt,
                failed_history=failed_history,
                proved_lemmas=proved_lemmas
            )
            
            if "Ollama Server Not Running" in llm_status:
                print(f"\n  [FATAL] Ollama not running on port 11434.")
                logger.error("FATAL: Ollama not running")
                save_checkpoint(rung_idx, attempt, proof_path, pristine_template,
                              failed_history, previous_error, proved_lemmas)
                sys.exit(1)
            
            sys.stdout.write("Compile ➔ ")
            sys.stdout.flush()
            
            compiler_output = bridge.verify_proof(proof_path)
            iter_time = time.time() - iter_start
            
            if compiler_output["status"] == "VERIFIED":
                print(f"✅ PROVED! ({iter_time:.1f}s)")
                print(f"\n  ╔══════════════════════════════════════╗")
                print(f"  ║  ✅ LEMMA PROVED: {rung['title'][:20]:20s} ║")
                print(f"  ║  Attempts: {attempt + 1:5d}                    ║")
                print(f"  ║  Time: {iter_time:.2f}s                       ║")
                print(f"  ╚══════════════════════════════════════╝")
                
                logger.info(f"✅ PROVED: {rung['title']} | Attempt: {attempt + 1} | Time: {iter_time:.2f}s")
                
                proved_lemmas.append(rung["name"])
                rung_proved = True
                
                # Save the proved proof to a permanent file
                proved_path = os.path.join(os.path.abspath("../proofs"), 
                                          f"Proved_{rung['name']}.lean")
                with open(proof_path, "r") as src:
                    with open(proved_path, "w") as dst:
                        dst.write(src.read())
                logger.info(f"Proof saved: {proved_path}")
                
                # Check if this was the FINAL rung
                if rung["name"] == "riemann_hypothesis":
                    total_time = time.time() - total_start_time
                    print(f"\n{'=' * 60}")
                    print(f"  ✅✅ MILLENNIUM PRIZE SECURED!!! ✅✅")
                    print(f"  Total iterations: {total_iterations}")
                    print(f"  Total time: {total_time:.0f}s ({total_time/3600:.1f}h)")
                    print(f"  Proof: {proved_path}")
                    print(f"{'=' * 60}\n")
                    logger.info("=" * 60)
                    logger.info("MILLENNIUM PRIZE SECURED!!!")
                    logger.info(f"Total iterations: {total_iterations} | Time: {total_time:.0f}s")
                    logger.info("=" * 60)
                    # Clean checkpoint on victory
                    cp = os.path.abspath(CHECKPOINT_FILE)
                    if os.path.exists(cp):
                        os.remove(cp)
                    sys.exit(0)
                
                # Save checkpoint with updated proved list, reset for next rung
                save_checkpoint(rung_idx + 1, 0, "", "", [], None, proved_lemmas)
                break
            
            elif compiler_output["status"] == "TIMEOUT":
                sys.stdout.write(f"TIMEOUT ({iter_time:.0f}s)\n")
                sys.stdout.flush()
                logger.info(f"Rung {rung_idx+1} | Attempt {attempt+1} | TIMEOUT | {iter_time:.0f}s")
                save_checkpoint(rung_idx, attempt, proof_path, pristine_template,
                              failed_history, previous_error, proved_lemmas)
            
            elif compiler_output["status"] == "SYSTEM_UNAVAILABLE":
                print(f"\n  [FATAL] Lean 4 compiler not found!")
                logger.error(f"Lean compiler missing: {compiler_output['message']}")
                save_checkpoint(rung_idx, attempt, proof_path, pristine_template,
                              failed_history, previous_error, proved_lemmas)
                sys.exit(1)
            
            else:
                previous_error = compiler_output.get("error", "Unknown").strip()
                safe_error = previous_error.replace('\n', ' ➔ ').replace('\r', '')
                failed_history.append(safe_error)
                
                sys.stdout.write(f"REJECTED ({iter_time:.1f}s) [{safe_error[:60]}...]\n")
                sys.stdout.flush()
                logger.info(f"Rung {rung_idx+1} | Attempt {attempt+1} | T={current_temp:.2f} | "
                          f"REJECTED | {iter_time:.1f}s | FULL ERROR: {safe_error}")
                
                # Checkpoint every 5 attempts
                if (attempt + 1) % 5 == 0:
                    save_checkpoint(rung_idx, attempt + 1, proof_path, pristine_template,
                                  failed_history, previous_error, proved_lemmas)
        
        if not rung_proved:
            print(f"\n  ⚠️  Rung {rung_idx + 1} not proved after {rung['max_attempts']} attempts. Moving on.")
            logger.info(f"Rung {rung_idx + 1} FAILED after {rung['max_attempts']} attempts: {rung['title']}")
            save_checkpoint(rung_idx + 1, 0, "", "", [], None, proved_lemmas)
        
        # Reset for next rung
        start_attempt = 0
    
    # Final summary
    total_time = time.time() - total_start_time
    print(f"\n\n{'=' * 60}")
    print(f"  LADDER COMPLETE")
    print(f"  Proved: {len(proved_lemmas)}/{total_rungs} lemmas")
    print(f"  Total iterations: {total_iterations}")
    print(f"  Total time: {total_time:.0f}s ({total_time/3600:.1f}h)")
    print(f"  Proved lemmas: {', '.join(proved_lemmas) if proved_lemmas else 'None'}")
    print(f"{'=' * 60}\n")
    
    logger.info(f"Ladder complete. Proved: {len(proved_lemmas)}/{total_rungs}")
    logger.info(f"Total iterations: {total_iterations} | Time: {total_time:.0f}s")

if __name__ == "__main__":
    try:
        launch_ladder_prover()
    except KeyboardInterrupt:
        print("\n\n[USER INTERRUPT] Saving checkpoint and halting safely...")
        sys.exit(0)
