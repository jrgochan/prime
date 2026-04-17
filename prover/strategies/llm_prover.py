#!/usr/bin/env python3
"""
llm_prover.py — Use a local Ollama LLM to generate proof candidates.

Sends axiom signatures + file context to a local LLM, gets back
candidate Lean 4 proofs, compiles them, and iterates on errors.

The core loop:
  Axiom → LLM → Lean code → lake env lean →
    ✅ Success!
    ❌ Error → feed error back to LLM → try again
"""

import json
import re
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional

OLLAMA_URL = "http://localhost:11434/api/chat"
DEFAULT_MODEL = "gemma4:31b"

SYSTEM_PROMPT = """You are an expert Lean 4 proof engineer working with the Mathlib library.
Your task is to prove Lean 4 theorems by providing tactic-mode proofs.

Rules:
1. Output ONLY the tactic proof body (everything after `:= by`)
2. Do NOT include the theorem statement, imports, or any markdown
3. Use standard Mathlib tactics: simp, norm_num, nlinarith, ring, omega, gcongr, positivity, etc.
4. If the goal involves integrals, use MeasureTheory tactics
5. If the goal involves matrices, use LinearAlgebra tactics
6. Keep proofs as simple as possible
7. You may use `have` and `suffices` for intermediate steps
8. You may use `calc` blocks for equational reasoning
9. Always output valid Lean 4 syntax

Example output for "theorem foo : 2 + 2 = 4":
  norm_num

Example output for "theorem bar (n : ℕ) (h : n ≥ 1) : n * n ≥ n":
  nlinarith [sq_nonneg n]
"""


def query_ollama(
    messages: list[dict],
    model: str = DEFAULT_MODEL,
    temperature: float = 0.7,
    max_tokens: int = 2048,
    timeout: int = 300,  # 5 min — gemma4:31b needs room to think
) -> Optional[str]:
    """Send a chat request to Ollama and return the response text."""
    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {
            "temperature": temperature,
            "num_predict": max_tokens,
        },
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_URL,
        data=data,
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            return result.get("message", {}).get("content", "")
    except urllib.error.URLError as e:
        print(f"      ⚠️  Ollama connection failed: {e}")
        return None
    except Exception as e:
        print(f"      ⚠️  Ollama error: {e}")
        return None


def extract_tactic(response: str) -> str:
    """Extract the tactic proof from an LLM response, stripping markdown/noise."""
    if not response:
        return "sorry"

    text = response.strip()

    # Remove markdown code blocks
    text = re.sub(r"```lean4?\s*\n?", "", text)
    text = re.sub(r"```\s*$", "", text, flags=re.MULTILINE)

    # Remove "by" prefix if the LLM included it
    text = text.strip()
    if text.startswith("by\n") or text.startswith("by "):
        text = text[3:].strip()

    # Remove theorem/axiom declarations if LLM included them
    lines = text.split("\n")
    clean_lines = []
    in_proof = False
    for line in lines:
        if line.strip().startswith("theorem ") or line.strip().startswith("axiom "):
            in_proof = False
            continue
        if ":= by" in line:
            in_proof = True
            # Take everything after := by
            after = line.split(":= by", 1)[1].strip()
            if after:
                clean_lines.append(after)
            continue
        if in_proof or not any(
            line.strip().startswith(kw)
            for kw in ["import ", "open ", "set_option ", "namespace ", "section "]
        ):
            clean_lines.append(line)

    text = "\n".join(clean_lines).strip()

    # If empty, fall back
    if not text:
        return "sorry"

    return text


def generate_proof_attempt(
    axiom_name: str,
    axiom_signature: str,
    file_context: str,
    previous_error: Optional[str] = None,
    attempt_num: int = 1,
    model: str = DEFAULT_MODEL,
    temperature: float = 0.7,
) -> Optional[str]:
    """
    Ask the LLM to generate a proof for the given axiom.
    If previous_error is provided, include it for iterative refinement.
    """
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    # Build the user prompt
    prompt_parts = [
        f"Prove the following Lean 4 theorem (attempt #{attempt_num}):\n",
        f"```lean\n{axiom_signature}\n```\n",
    ]

    # Add file context (imports, nearby definitions)
    if file_context:
        prompt_parts.append(
            f"Context from the file (imports and nearby definitions):\n"
            f"```lean\n{file_context[:2000]}\n```\n"
        )

    # Add error feedback for iterative refinement
    if previous_error:
        prompt_parts.append(
            f"My previous attempt failed with this Lean compiler error:\n"
            f"```\n{previous_error[:1000]}\n```\n"
            f"Please fix the proof based on this error message.\n"
        )

    prompt_parts.append(
        "Output ONLY the tactic proof body (after `:= by`). No imports, no theorem statement, no markdown."
    )

    messages.append({"role": "user", "content": "\n".join(prompt_parts)})

    # Increase temperature slightly on retries for diversity
    temp = min(temperature + (attempt_num - 1) * 0.1, 1.2)

    response = query_ollama(messages, model=model, temperature=temp)
    if response is None:
        return None

    return extract_tactic(response)


def get_file_context(filepath: Path, axiom_line: int, window: int = 40) -> str:
    """Get surrounding context from the file for the LLM."""
    if not filepath.exists():
        return ""

    text = filepath.read_text(encoding="utf-8", errors="replace")
    lines = text.split("\n")

    # Get imports
    import_lines = [l for l in lines if l.startswith("import ") or l.startswith("open ")]

    # Get nearby lines (definitions, types)
    start = max(0, axiom_line - window)
    end = min(len(lines), axiom_line + 10)
    nearby = lines[start:end]

    context_parts = import_lines + ["", "-- Nearby context:"] + nearby
    return "\n".join(context_parts)


def is_ollama_available(model: str = DEFAULT_MODEL) -> bool:
    """Check if Ollama is running and the model is available."""
    try:
        payload = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": "Say 'ready'"}],
            "stream": False,
            "options": {"num_predict": 5},
        }).encode("utf-8")

        req = urllib.request.Request(
            OLLAMA_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            return "message" in result
    except Exception:
        return False


if __name__ == "__main__":
    print("🧠 Testing Ollama LLM Prover...")

    if not is_ollama_available():
        print("   ❌ Ollama not available. Start it with: ollama serve")
        print(f"   Then pull a model: ollama pull {DEFAULT_MODEL}")
        exit(1)

    print(f"   ✅ Ollama available (model: {DEFAULT_MODEL})")

    # Test with a simple theorem
    test_sig = "theorem test_add : 2 + 3 = 5"
    print(f"\n   Testing: {test_sig}")

    tactic = generate_proof_attempt(
        axiom_name="test_add",
        axiom_signature=test_sig,
        file_context="import Mathlib.Tactic",
    )
    print(f"   LLM response: by {tactic}")
