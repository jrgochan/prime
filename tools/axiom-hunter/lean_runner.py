#!/usr/bin/env python3
"""
lean_runner.py — Compile a single Lean file against the Cathedral .olean cache.

Uses `lake env lean <file>` for fast (~2-5s) single-file compilation
instead of full `lake build` (~minutes).
"""

import subprocess
import tempfile
import time
import os
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional

PROOFS_DIR = Path(__file__).resolve().parent.parent / "proofs"

# Ensure elan/lake is on PATH
ELAN_BIN = Path.home() / ".elan" / "bin"
ENV = os.environ.copy()
if str(ELAN_BIN) not in ENV.get("PATH", ""):
    ENV["PATH"] = f"{ELAN_BIN}:{ENV.get('PATH', '')}"


@dataclass
class CompileResult:
    success: bool
    exit_code: int
    stdout: str
    stderr: str
    elapsed_seconds: float
    error_type: Optional[str] = None
    error_message: Optional[str] = None
    goal_state: Optional[str] = None


def classify_error(stderr: str) -> tuple[Optional[str], Optional[str]]:
    """Classify a Lean compilation error into a category."""
    if not stderr.strip():
        return None, None

    lines = stderr.strip().split("\n")

    for line in lines:
        if "unknown identifier" in line:
            return "unknown_identifier", line
        if "type mismatch" in line:
            return "type_mismatch", line
        if "unsolved goals" in line:
            return "unsolved_goals", line
        if "tactic" in line and "failed" in line:
            return "tactic_failed", line
        if "declaration uses 'sorry'" in line:
            return "has_sorry", line
        if "unknown tactic" in line:
            return "unknown_tactic", line
        if "expected token" in line or "unexpected token" in line:
            return "syntax_error", line
        if "timeout" in line.lower() or "deterministic timeout" in line:
            return "timeout", line
        if "maximum recursion depth" in line:
            return "max_recursion", line

    # Generic
    return "other", lines[0] if lines else ""


def extract_goal_state(stderr: str) -> Optional[str]:
    """Try to extract the goal state from Lean error output."""
    lines = stderr.split("\n")
    in_goal = False
    goal_lines = []
    for line in lines:
        if "unsolved goals" in line or "⊢" in line:
            in_goal = True
        if in_goal:
            goal_lines.append(line)
            if len(goal_lines) > 15:
                break
    return "\n".join(goal_lines) if goal_lines else None


def compile_lean_string(
    lean_code: str,
    timeout_seconds: int = 30,
    filename: str = "Attempt.lean",
) -> CompileResult:
    """
    Write lean_code to a temp file in the proofs dir and compile it.
    Uses `lake env lean` for fast single-file compilation.
    """
    # Write to a scratch file in the proofs directory (so imports work)
    scratch_dir = PROOFS_DIR / "Cathedral" / "Scratch"
    scratch_dir.mkdir(parents=True, exist_ok=True)
    scratch_file = scratch_dir / filename

    try:
        scratch_file.write_text(lean_code, encoding="utf-8")

        t0 = time.time()
        try:
            result = subprocess.run(
                ["lake", "env", "lean", str(scratch_file)],
                cwd=str(PROOFS_DIR),
                capture_output=True,
                text=True,
                timeout=timeout_seconds,
                env=ENV,
            )
            elapsed = time.time() - t0

            error_type, error_msg = classify_error(result.stderr)
            goal_state = extract_goal_state(result.stderr)

            return CompileResult(
                success=(result.returncode == 0),
                exit_code=result.returncode,
                stdout=result.stdout,
                stderr=result.stderr,
                elapsed_seconds=elapsed,
                error_type=error_type,
                error_message=error_msg,
                goal_state=goal_state,
            )

        except subprocess.TimeoutExpired:
            elapsed = time.time() - t0
            return CompileResult(
                success=False,
                exit_code=-1,
                stdout="",
                stderr="TIMEOUT",
                elapsed_seconds=elapsed,
                error_type="timeout",
                error_message=f"Compilation timed out after {timeout_seconds}s",
            )

    finally:
        # Clean up (missing_ok handles race conditions / concurrent cleanup)
        try:
            if scratch_file.exists():
                scratch_file.unlink()
        except (FileNotFoundError, OSError):
            pass  # Already cleaned up — no problem


def compile_lean_file(filepath: Path, timeout_seconds: int = 30) -> CompileResult:
    """Compile an existing Lean file."""
    t0 = time.time()
    try:
        result = subprocess.run(
            ["lake", "env", "lean", str(filepath)],
            cwd=str(PROOFS_DIR),
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
            env=ENV,
        )
        elapsed = time.time() - t0

        error_type, error_msg = classify_error(result.stderr)
        goal_state = extract_goal_state(result.stderr)

        return CompileResult(
            success=(result.returncode == 0),
            exit_code=result.returncode,
            stdout=result.stdout,
            stderr=result.stderr,
            elapsed_seconds=elapsed,
            error_type=error_type,
            error_message=error_msg,
            goal_state=goal_state,
        )
    except subprocess.TimeoutExpired:
        elapsed = time.time() - t0
        return CompileResult(
            success=False,
            exit_code=-1,
            stdout="",
            stderr="TIMEOUT",
            elapsed_seconds=elapsed,
            error_type="timeout",
            error_message=f"Compilation timed out after {timeout_seconds}s",
        )


if __name__ == "__main__":
    # Quick test
    test_code = """
import Mathlib.Analysis.SpecialFunctions.Log.Basic

theorem test_log_pos : Real.log 2 > 0 := by
  exact Real.log_pos (by norm_num : (1 : ℝ) < 2)
"""
    print("Testing lean_runner...")
    result = compile_lean_string(test_code)
    print(f"  Success: {result.success}")
    print(f"  Time: {result.elapsed_seconds:.2f}s")
    if not result.success:
        print(f"  Error: {result.error_type}: {result.error_message}")
        print(f"  Stderr: {result.stderr[:500]}")
    else:
        print("  ✅ Lean runner working!")
