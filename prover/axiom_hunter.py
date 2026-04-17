#!/usr/bin/env python3
"""
axiom_hunter.py — Overnight automated proof search for Cathedral axioms.

Scans all `axiom` declarations in the Cathedral, generates candidate proofs
using multiple strategies, and compiles them against the Lean kernel.

The Lean compiler is the infallible reward signal.

Usage:
    python3 axiom_hunter.py                    # Run all axioms
    python3 axiom_hunter.py --axiom NAME       # Target specific axiom
    python3 axiom_hunter.py --max-hours 8      # Set time limit
    python3 axiom_hunter.py --quick            # Quick test (10 min)
"""

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Optional

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent))

from lean_runner import compile_lean_string, CompileResult
from strategies.tactic_bomb import generate_tactics, count_tactics
from strategies.llm_prover import (
    generate_proof_attempt as llm_generate_proof,
    get_file_context,
    is_ollama_available,
    DEFAULT_MODEL,
)

PROOFS_DIR = Path(__file__).resolve().parent.parent / "proofs"
CATHEDRAL_DIR = PROOFS_DIR / "Cathedral"
RESULTS_DIR = Path(__file__).resolve().parent / "results"
SKIP_DIRS = {"Archive", "Scratch"}

# Axiom declaration pattern
AXIOM_RE = re.compile(
    r"^(axiom)\s+(\w+)\s*(.*?)(?=\n(?:theorem|axiom|def|lemma|noncomputable|instance|abbrev|#|section|namespace|end|open|variable|import|--|/-)|$)",
    re.MULTILINE | re.DOTALL,
)

# Import pattern
IMPORT_RE = re.compile(r"^import\s+([\w.]+)", re.MULTILINE)


@dataclass
class AxiomInfo:
    name: str
    file: str
    line: int
    signature: str  # The full axiom declaration
    imports: list  # Imports from the file


@dataclass
class Attempt:
    axiom_name: str
    strategy: str
    tactic: str
    success: bool
    elapsed: float
    error_type: Optional[str]
    error_message: Optional[str]
    timestamp: str


def scan_axioms() -> list[AxiomInfo]:
    """Scan all Cathedral files for axiom declarations."""
    axioms = []

    for root, dirs, files in os.walk(CATHEDRAL_DIR):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in sorted(files):
            if not f.endswith(".lean"):
                continue
            filepath = Path(root) / f
            text = filepath.read_text(encoding="utf-8", errors="replace")
            rel_path = str(filepath.relative_to(PROOFS_DIR))

            # Get imports
            imports = [m.group(1) for m in IMPORT_RE.finditer(text)]

            # Find axioms
            lines = text.split("\n")
            for i, line in enumerate(lines):
                m = re.match(r"^axiom\s+(\w+)", line)
                if m:
                    name = m.group(1)
                    # Collect the full signature (up to 10 lines)
                    sig_lines = []
                    for j in range(i, min(i + 10, len(lines))):
                        sig_lines.append(lines[j])
                        stripped = lines[j].strip()
                        if stripped.endswith("") and not stripped.startswith("axiom"):
                            break
                        if j > i and (
                            lines[j].startswith("axiom ")
                            or lines[j].startswith("theorem ")
                            or lines[j].startswith("def ")
                            or lines[j].startswith("lemma ")
                            or lines[j].startswith("--")
                            or lines[j].startswith("/-")
                            or lines[j].strip() == ""
                        ):
                            sig_lines.pop()
                            break

                    signature = "\n".join(sig_lines).strip()

                    axioms.append(
                        AxiomInfo(
                            name=name,
                            file=rel_path,
                            line=i + 1,
                            signature=signature,
                            imports=imports,
                        )
                    )

    return axioms


def generate_proof_attempt(axiom: AxiomInfo, tactic: str) -> str:
    """Generate a complete Lean file that tries to prove an axiom."""
    # Build imports from the original file
    import_lines = "\n".join(f"import {imp}" for imp in axiom.imports)

    # Convert axiom to theorem with tactic proof
    # Replace "axiom NAME" with "theorem NAME"
    theorem_sig = axiom.signature.replace("axiom ", "theorem ", 1)

    # If the signature doesn't end with := by, add it
    if ":=" not in theorem_sig and "where" not in theorem_sig:
        theorem_sig += " := by"

    # Build the file
    lean_code = f"""{import_lines}

set_option maxHeartbeats 200000

{theorem_sig}
  {tactic}
"""
    return lean_code


def attack_axiom(
    axiom: AxiomInfo,
    max_attempts: int = 100,
    timeout: int = 30,
    log_file=None,
) -> tuple[bool, list[Attempt]]:
    """
    Attack a single axiom with all strategies.
    Returns (success, attempts).
    """
    attempts = []
    print(f"\n{'='*60}")
    print(f"🎯 Targeting: {axiom.name}")
    print(f"   File: {axiom.file}:{axiom.line}")
    print(f"   Sig:  {axiom.signature[:100]}...")
    print(f"{'='*60}")

    attempt_count = 0

    for tactic in generate_tactics(max_level=8):
        if attempt_count >= max_attempts:
            print(f"   ⏸️  Budget exhausted ({max_attempts} attempts)")
            break

        attempt_count += 1
        lean_code = generate_proof_attempt(axiom, tactic)

        # Compile
        result = compile_lean_string(
            lean_code,
            timeout_seconds=timeout,
            filename=f"Hunt_{axiom.name}.lean",
        )

        attempt = Attempt(
            axiom_name=axiom.name,
            strategy="tactic_bomb",
            tactic=tactic,
            success=result.success,
            elapsed=result.elapsed_seconds,
            error_type=result.error_type,
            error_message=result.error_message[:200] if result.error_message else None,
            timestamp=datetime.now().isoformat(),
        )
        attempts.append(attempt)

        # Log to JSONL
        if log_file:
            log_file.write(json.dumps(asdict(attempt)) + "\n")
            log_file.flush()

        # Status indicator
        status = "✅" if result.success else "❌"
        err_info = f" [{result.error_type}]" if result.error_type else ""
        print(
            f"   {status} [{attempt_count:3d}] {tactic[:50]:50s} "
            f"({result.elapsed_seconds:.1f}s){err_info}"
        )

        if result.success:
            print(f"\n   🎉🎉🎉 AXIOM PROVED: {axiom.name} 🎉🎉🎉")
            print(f"   Winning tactic: by {tactic}")
            print(f"   File: {axiom.file}")
            return True, attempts

    return False, attempts


def attack_axiom_llm(
    axiom: AxiomInfo,
    model: str = DEFAULT_MODEL,
    max_iterations: int = 10,
    timeout: int = 60,
    log_file=None,
) -> tuple[bool, list[Attempt]]:
    """
    Attack an axiom using the local LLM with iterative error feedback.
    The scoped rifle.
    """
    attempts = []
    print(f"\n{'='*60}")
    print(f"🧠 LLM Targeting: {axiom.name}")
    print(f"   File: {axiom.file}:{axiom.line}")
    print(f"   Model: {model}")
    print(f"{'='*60}")

    # Get file context for the LLM
    file_path = PROOFS_DIR / axiom.file
    context = get_file_context(file_path, axiom.line)

    previous_error = None

    for iteration in range(1, max_iterations + 1):
        # Ask LLM for a proof
        print(f"   🧠 [{iteration:2d}] Querying {model}...", end=" ", flush=True)

        tactic = llm_generate_proof(
            axiom_name=axiom.name,
            axiom_signature=axiom.signature,
            file_context=context,
            previous_error=previous_error,
            attempt_num=iteration,
            model=model,
        )

        if tactic is None:
            print("⚠️  No response")
            continue

        # Show what the LLM generated
        tactic_preview = tactic.replace("\n", " ")[:60]
        print(f"→ {tactic_preview}...")

        # Build and compile
        lean_code = generate_proof_attempt(axiom, tactic)
        result = compile_lean_string(
            lean_code,
            timeout_seconds=timeout,
            filename=f"LLM_{axiom.name}.lean",
        )

        attempt = Attempt(
            axiom_name=axiom.name,
            strategy=f"llm_{model}",
            tactic=tactic[:500],
            success=result.success,
            elapsed=result.elapsed_seconds,
            error_type=result.error_type,
            error_message=result.error_message[:200] if result.error_message else None,
            timestamp=datetime.now().isoformat(),
        )
        attempts.append(attempt)

        if log_file:
            log_file.write(json.dumps(asdict(attempt)) + "\n")
            log_file.flush()

        if result.success:
            print(f"\n   🎉🎉🎉 AXIOM PROVED BY LLM: {axiom.name} 🎉🎉🎉")
            print(f"   Winning proof:\n   by {tactic}")
            return True, attempts

        # Feed error back for next iteration
        status = f"❌ [{result.error_type}]" if result.error_type else "❌"
        print(f"   {status} ({result.elapsed_seconds:.1f}s)")
        previous_error = result.stderr[:1500] if result.stderr else None

    print(f"   ⏸️  LLM budget exhausted ({max_iterations} iterations)")
    return False, attempts


def run_hunt(
    target_axiom: Optional[str] = None,
    max_hours: float = 8.0,
    max_attempts_per_axiom: int = 100,
    timeout_per_attempt: int = 30,
    priority: str = "non-critical",
    model: str = DEFAULT_MODEL,
    max_llm_iterations: int = 10,
    no_llm: bool = False,
):
    """Run the full axiom hunt."""
    start_time = time.time()
    deadline = start_time + max_hours * 3600

    # Check LLM availability
    use_llm = False
    if not no_llm:
        print(f"🧠 Checking Ollama ({model})...")
        if is_ollama_available(model):
            use_llm = True
            print(f"   ✅ LLM available! Will use {model} as primary strategy.")
        else:
            print(f"   ⚠️  Ollama not available. Falling back to tactic bombardment.")
            print(f"   To enable: ollama serve && ollama pull {model}")

    # Scan axioms
    print("🔍 Scanning Cathedral for axioms...")
    all_axioms = scan_axioms()
    print(f"   Found {len(all_axioms)} axioms across {len(set(a.file for a in all_axioms))} files")

    # Filter
    if target_axiom:
        axioms = [a for a in all_axioms if a.name == target_axiom]
        if not axioms:
            print(f"❌ Axiom '{target_axiom}' not found!")
            print(f"   Available: {', '.join(a.name for a in all_axioms[:10])}...")
            return
    else:
        axioms = all_axioms

    # Sort by priority
    CRITICAL_PATH = {
        "rh_implies_mertens_bound",
        "autocorr_eval_zero",
        "fourier_inv_autocorr",
        "mellin_fourier_scale",
        "critical_line_mellin_bound",
    }
    if priority == "critical":
        axioms.sort(key=lambda a: (0 if a.name in CRITICAL_PATH else 1, a.name))
    else:
        # Non-critical first (more likely to succeed)
        axioms.sort(key=lambda a: (1 if a.name in CRITICAL_PATH else 0, a.name))

    # Setup results
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    attempts_file = RESULTS_DIR / f"attempts_{run_id}.jsonl"
    successes = []
    all_attempts = []

    total_tactics = count_tactics(8)
    strategy_desc = f"LLM ({model}) + tactic_bomb" if use_llm else "tactic_bomb only"
    print(f"\n🚀 AXIOM HUNTER — Campaign Beta Automated Search")
    print(f"   Strategy: {strategy_desc}")
    print(f"   Axioms to attack: {len(axioms)}")
    if use_llm:
        print(f"   LLM iterations per axiom: {max_llm_iterations}")
    print(f"   Tactic attempts per axiom: up to {min(max_attempts_per_axiom, total_tactics)}")
    print(f"   Timeout per attempt: {timeout_per_attempt}s")
    print(f"   Max runtime: {max_hours} hours")
    print(f"   Results: {attempts_file}")
    print(f"   Started: {datetime.now().isoformat()}")
    print()

    with open(attempts_file, "w") as log_file:
        for i, axiom in enumerate(axioms):
            # Check deadline
            if time.time() > deadline:
                print(f"\n⏰ Time limit reached ({max_hours} hours)")
                break

            elapsed_hours = (time.time() - start_time) / 3600
            print(f"\n[{i+1}/{len(axioms)}] ({elapsed_hours:.1f}h elapsed)")

            # Strategy 1: LLM (if available)
            if use_llm:
                success, attempts = attack_axiom_llm(
                    axiom,
                    model=model,
                    max_iterations=max_llm_iterations,
                    timeout=timeout_per_attempt,
                    log_file=log_file,
                )
                all_attempts.extend(attempts)
                if success:
                    winning = [a for a in attempts if a.success][0]
                    successes.append(
                        {
                            "axiom": axiom.name,
                            "file": axiom.file,
                            "line": axiom.line,
                            "tactic": winning.tactic,
                            "elapsed": winning.elapsed,
                            "strategy": "llm",
                        }
                    )
                    continue  # Move to next axiom

            # Strategy 2: Tactic bombardment
            success, attempts = attack_axiom(
                axiom,
                max_attempts=max_attempts_per_axiom,
                timeout=timeout_per_attempt,
                log_file=log_file,
            )
            all_attempts.extend(attempts)
            if success:
                winning = [a for a in attempts if a.success][0]
                successes.append(
                    {
                        "axiom": axiom.name,
                        "file": axiom.file,
                        "line": axiom.line,
                        "tactic": winning.tactic,
                        "elapsed": winning.elapsed,
                        "strategy": "tactic_bomb",
                    }
                )

    # Generate report
    total_elapsed = time.time() - start_time
    generate_report(
        run_id, axioms, all_attempts, successes, total_elapsed
    )


def generate_report(
    run_id: str,
    axioms: list[AxiomInfo],
    attempts: list[Attempt],
    successes: list[dict],
    total_elapsed: float,
):
    """Generate a human-readable report."""
    report_file = RESULTS_DIR / f"report_{run_id}.md"
    successes_file = RESULTS_DIR / f"successes_{run_id}.json"

    # Save successes
    with open(successes_file, "w") as f:
        json.dump(successes, f, indent=2)

    # Error distribution
    error_counts = {}
    for a in attempts:
        if not a.success and a.error_type:
            error_counts[a.error_type] = error_counts.get(a.error_type, 0) + 1

    # Per-axiom summary
    axiom_results = {}
    for a in attempts:
        if a.axiom_name not in axiom_results:
            axiom_results[a.axiom_name] = {
                "total": 0,
                "success": False,
                "errors": {},
                "best_error": None,
            }
        axiom_results[a.axiom_name]["total"] += 1
        if a.success:
            axiom_results[a.axiom_name]["success"] = True
        if a.error_type:
            axiom_results[a.axiom_name]["errors"][a.error_type] = (
                axiom_results[a.axiom_name]["errors"].get(a.error_type, 0) + 1
            )

    hours = total_elapsed / 3600
    minutes = total_elapsed / 60

    report = f"""# 🏹 Axiom Hunter Report — {run_id}

## Summary

| Metric | Value |
|--------|-------|
| **Axioms targeted** | {len(set(a.axiom_name for a in attempts))} |
| **Total attempts** | {len(attempts)} |
| **AXIOMS PROVED** | **{len(successes)}** {"🎉" if successes else ""} |
| **Runtime** | {hours:.1f} hours ({minutes:.0f} min) |
| **Attempts/hour** | {len(attempts) / hours:.0f} |

## {"🎉 Successes!" if successes else "No Successes (Yet)"}

"""

    if successes:
        for s in successes:
            report += f"""### ✅ `{s['axiom']}`
- **File**: `{s['file']}`
- **Winning tactic**: `by {s['tactic']}`
- **Compile time**: {s['elapsed']:.1f}s

"""
    else:
        report += "*No axioms were proved in this run. This is expected — the remaining axioms require deep mathematical infrastructure not yet available in Mathlib.*\n\n"

    report += f"""## Error Distribution

| Error Type | Count | % |
|------------|-------|---|
"""
    total_errors = sum(error_counts.values())
    for err_type, count in sorted(error_counts.items(), key=lambda x: -x[1]):
        pct = (count / total_errors * 100) if total_errors > 0 else 0
        report += f"| `{err_type}` | {count} | {pct:.0f}% |\n"

    report += f"""
## Per-Axiom Results

| Axiom | Attempts | Result | Most Common Error |
|-------|----------|--------|-------------------|
"""
    for name, info in sorted(axiom_results.items()):
        result = "✅ PROVED" if info["success"] else "❌"
        top_err = (
            max(info["errors"].items(), key=lambda x: x[1])[0]
            if info["errors"]
            else "—"
        )
        report += f"| `{name}` | {info['total']} | {result} | `{top_err}` |\n"

    report += f"""
## Configuration

- Strategies: tactic_bomb (levels 1-8)
- Timeout per attempt: 30s
- Max heartbeats: 200000
- Generated: {datetime.now().isoformat()}
"""

    with open(report_file, "w") as f:
        f.write(report)

    print(f"\n{'='*60}")
    print(f"📊 HUNT COMPLETE")
    print(f"   Axioms targeted: {len(set(a.axiom_name for a in attempts))}")
    print(f"   Total attempts: {len(attempts)}")
    print(f"   PROVED: {len(successes)}")
    print(f"   Runtime: {hours:.1f}h")
    print(f"   Report: {report_file}")
    print(f"   Successes: {successes_file}")
    print(f"{'='*60}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cathedral Axiom Hunter")
    parser.add_argument("--axiom", type=str, help="Target a specific axiom")
    parser.add_argument(
        "--max-hours", type=float, default=8.0, help="Maximum runtime in hours"
    )
    parser.add_argument(
        "--max-attempts", type=int, default=100, help="Max attempts per axiom"
    )
    parser.add_argument(
        "--timeout", type=int, default=30, help="Timeout per attempt (seconds)"
    )
    parser.add_argument(
        "--priority",
        choices=["critical", "non-critical"],
        default="non-critical",
        help="Which axioms to prioritize",
    )
    parser.add_argument(
        "--quick", action="store_true", help="Quick test mode (10 min, 3 axioms)"
    )
    parser.add_argument(
        "--model", type=str, default=DEFAULT_MODEL,
        help=f"Ollama model to use (default: {DEFAULT_MODEL})"
    )
    parser.add_argument(
        "--llm-iterations", type=int, default=10,
        help="Max LLM iterations per axiom (default: 10)"
    )
    parser.add_argument(
        "--no-llm", action="store_true",
        help="Disable LLM strategy, use tactic bombardment only"
    )
    args = parser.parse_args()

    if args.quick:
        args.max_hours = 0.17  # 10 minutes
        args.max_attempts = 20
        args.llm_iterations = 3

    run_hunt(
        target_axiom=args.axiom,
        max_hours=args.max_hours,
        max_attempts_per_axiom=args.max_attempts,
        timeout_per_attempt=args.timeout,
        priority=args.priority,
        model=args.model,
        max_llm_iterations=args.llm_iterations,
        no_llm=args.no_llm,
    )
