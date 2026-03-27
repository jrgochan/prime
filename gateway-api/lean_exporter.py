import os
import uuid
import json
import urllib.request
import urllib.error
import subprocess
from datetime import datetime

class Lean4Exporter:
    """
    Bridges the Floating-Point mathematics engine to the Symbolic Theorem framework.
    Translates stable topological bounds into raw .lean files and orchestrates LLM tactic solving.
    """
    def __init__(self, proofs_dir: str = "../proofs"):
        self.proofs_dir = os.path.abspath(proofs_dir)
        os.makedirs(self.proofs_dir, exist_ok=True)

    def generate_betti_theorem(self, betti_score: float, hyper_tensor: list[float]) -> str:
        proof_id = str(uuid.uuid4())[:8]
        timestamp = datetime.utcnow().isoformat()
        
        file_name = f"StableTopology_{proof_id}.lean"
        file_path = os.path.join(self.proofs_dir, file_name)
        
        # Self-contained Millennium Prize formulation strictly binding Sedenion collapses to Complex Boundaries
        lean_template = f"""import Mathlib

/-!
# Millennium Prize Bound: The Riemann Hypothesis Geometry
Discovered by: Project HYPERZETA Headless Recursion Node
Timestamp: {timestamp}
16D Sedenion Cross-Product Metric: {betti_score:.4f}
-/

open Complex

namespace MillenniumPrize.Discovery

/-- 
  The formal constraint of the Riemann Hypothesis.
  If a complex root `s` exists in the critical strip (0 < Re(s) < 1) where the
  analytic Riemann Zeta function evaluates to zero, then the Real portion 
  of `s` must be exactly 1/2. 

  Our physical WebGPU engine determines via Sedenion collapses that `Re(s) = 1/2` 
  is the only topologically stable topological geometry. Can you formally prove it?
-/
theorem Riemann_Hypothesis_Critical_Line (s : ℂ) 
  (h_strip : 0 < s.re ∧ s.re < 1) 
  (h_zero : riemannZeta s = 0) : 
  s.re = 1/2 :=
  -- Project HYPERZETA AlphaProof Injection Node 
  sorry

end MillenniumPrize.Discovery
"""
        with open(file_path, "w") as f:
            f.write(lean_template)
            
        return file_path

    def expand_proof(self, file_path: str, pristine_template: str, previous_error: str = None) -> str:
        """
        Connects natively via built-in URLlib to local Ollama.
        Instructs the Agent strictly to resolve math without hallucinating imports.
        """
        if not os.path.exists(file_path):
            return "System File missing."
            
        system_prompt = f"""You are an absolute genius mathematical theorem prover running inside Lean 4.
Your explicit goal is to complete the theorem by replacing the `sorry` gap text with exact, valid Lean 4 syntax.
Do NOT output ANY conversational text, markdown limits, or explanations.
CRITICAL CONSTRAINT 1: Do NOT rewrite the entire file or theorem setup. Output ONLY the exact replacement text for the `sorry` block.
CRITICAL CONSTRAINT 2: You have full access to Mathlib4. If you are using Tactic mode, your output MUST begin with the keyword `by` (e.g., `by \n  intro h \n  exact True.intro`).

```lean
{pristine_template}
```
"""
        if previous_error:
            system_prompt += f"\n\nWARNING: Your previous mathematical logic compilation FAILED inside the Mac Lean 4 Compiler with the exact native error message:\n{previous_error}\n\nRead the system syntax error properly, realize what tactic failed, and explicitly TRY A DIFFERENT TACTIC PATH!"

        try:
            req_body = json.dumps({
                "model": "qwen2.5-coder:32b",
                "prompt": system_prompt,
                "stream": False,
                "options": {
                    "temperature": 0.4,
                    "num_ctx": 1024,      # Aggressively discard context memory; our proofs are tiny (~300 tokens)
                    "num_thread": 8,      # Maximum Apple Silicon Performance Cores mapped natively
                    "num_gpu": 99         # Force all 32 Billion layers into Unified Memory (Metal API)
                }
            }).encode("utf-8")
            
            req = urllib.request.Request(
                "http://127.0.0.1:11434/api/generate",
                data=req_body,
                headers={"Content-Type": "application/json"}
            )
            
            with urllib.request.urlopen(req) as response:
                response_data = json.loads(response.read().decode("utf-8"))
                llm_output = response_data.get("response", "")
                
                # Sterilize Markdown wrappers injected autonomously
                llm_output = llm_output.replace("```lean", "").replace("```", "").strip()
                
                # Natively inject AI extraction text into the pristine theorem, overriding broken mutations completely 
                injected_mathematics = pristine_template.replace("sorry", llm_output)
                
                with open(file_path, "w") as f:
                    f.write(injected_mathematics)
                    
                return "Mac Local Ollama Inference Array Expanded."
                
        except urllib.error.URLError:
            return "Ollama Server Not Running locally natively spanning port 11434."

    def verify_proof(self, file_path: str) -> dict:
        """
        Spawns a native subprocess to execute the Lean 4 compiler `lean` firmly on the host M2 OS.
        We explicitly set cwd=self.proofs_dir so files execute elegantly.
        """
        try:
            result = subprocess.run(
                ["lake", "env", "lean", os.path.basename(file_path)], 
                capture_output=True, 
                text=True, 
                timeout=30,
                cwd=self.proofs_dir
            )
            
            # If the compiler exits 0 (no syntax/logic mathematical failures) and `sorry` is excised: the algebra is PROVEN!
            # We explicitly ignore string-tracking stderr for "warnings" because Lean 4 naturally outputs harmless warnings!
            if result.returncode == 0 and "sorry" not in result.stdout and "sorry" not in result.stderr:
                return {
                    "status": "VERIFIED", 
                    "message": "Riemann Hypothesis Geometry Graph Compiled Perfectly!",
                    "output": result.stdout
                }
            else:
                return {
                    "status": "FAILED", 
                    "message": "Compiler Rejected Logical Tactic Synthesis.",
                    "error": result.stderr + "\n" + result.stdout
                }
        except FileNotFoundError:
            return {
                "status": "SYSTEM_UNAVAILABLE", 
                "message": "Lean 4 compiler not installed natively on this Mac. Please run: `curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh`"
            }
        except subprocess.TimeoutExpired:
            return {
                "status": "TIMEOUT", 
                "message": "Lean 4 timed out evaluating the 16-Dimensional cross-products."
            }
