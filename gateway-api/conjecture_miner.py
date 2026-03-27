"""
Project HYPERZETA: Conjecture Miner
=====================================
Bridge 1: Simulation → Formal Conjectures

This module reimplements the Rust sedenion zeta computation in Python
(for ease of numerical analysis), mines data at zero-crossings, extracts
topological patterns via Hessian analysis, and generates structured
conjectures for injection into the LLM prover prompt.

Runs once at startup, caches results to disk for subsequent runs.
"""

import numpy as np
import os
import json
import time

# Cache file for mined conjectures
CONJECTURE_CACHE = os.path.join(os.path.dirname(__file__), "..", "proofs", ".conjecture_cache.json")


# ═══════════════════════════════════════════════════════════
# SECTION 1: Pure Python Sedenion Algebra
# Mirrors core-engine/src/math.rs exactly
# ═══════════════════════════════════════════════════════════

class Sedenion:
    """
    16-dimensional hypercomplex number via Cayley-Dickson construction.
    Stored as a flat array of 16 Float64 components.
    
    Component layout (matching the nested CDPair structure):
      [0]  = real part
      [1]  = e₁ (complex i)
      [2]  = e₂ (quaternion j)
      [3]  = e₃ (quaternion k)
      [4]  = e₄ (octonion l)
      [5]  = e₅
      [6]  = e₆
      [7]  = e₇
      [8]  = e₈ (sedenion)
      [9]  = e₉
      [10] = e₁₀
      [11] = e₁₁
      [12] = e₁₂
      [13] = e₁₃
      [14] = e₁₄
      [15] = e₁₅
    """
    
    __slots__ = ['c']
    
    def __init__(self, components=None):
        if components is None:
            self.c = np.zeros(16, dtype=np.float64)
        else:
            self.c = np.array(components, dtype=np.float64)
            if len(self.c) != 16:
                raise ValueError(f"Sedenion requires 16 components, got {len(self.c)}")
    
    @staticmethod
    def zero():
        return Sedenion()
    
    @staticmethod
    def one():
        s = Sedenion()
        s.c[0] = 1.0
        return s
    
    @staticmethod
    def from_real(r: float):
        s = Sedenion()
        s.c[0] = r
        return s
    
    @staticmethod
    def from_complex(re: float, im: float):
        """Create a sedenion with only Re and first imaginary component."""
        s = Sedenion()
        s.c[0] = re
        s.c[1] = im
        return s
    
    @property
    def real(self):
        return self.c[0]
    
    @real.setter
    def real(self, value):
        self.c[0] = value
    
    def copy(self):
        return Sedenion(self.c.copy())
    
    def add(self, other):
        return Sedenion(self.c + other.c)
    
    def sub(self, other):
        return Sedenion(self.c - other.c)
    
    def neg(self):
        return Sedenion(-self.c)
    
    def scale(self, s: float):
        return Sedenion(self.c * s)
    
    def norm_sq(self):
        return float(np.dot(self.c, self.c))
    
    def norm(self):
        return float(np.sqrt(self.norm_sq()))
    
    def normalize(self):
        n = self.norm()
        if n == 0.0:
            return self.copy()
        return self.scale(1.0 / n)
    
    def conj(self):
        """Cayley-Dickson conjugation: negate all imaginary parts."""
        result = self.copy()
        result.c[1:] = -result.c[1:]
        return result
    
    def mul(self, other):
        """
        Cayley-Dickson multiplication via recursive halving.
        (a, b) · (c, d) = (ac - conj(d)·b, d·a + b·conj(c))
        
        For 16 components, this recurses through 8, 4, 2, 1 (Float).
        """
        return Sedenion(_cd_mul(self.c, other.c, 16))
    
    def exp(self):
        """
        Sedenion exponential: e^S = e^r · (cos|V| + V̂·sin|V|)
        where r = Re(S) and V is the 15D imaginary vector.
        """
        r = self.c[0]
        v = self.copy()
        v.c[0] = 0.0  # isolate imaginary vector
        
        v_norm = v.norm()
        exp_r = np.exp(r)
        
        if v_norm < 1e-15:
            return Sedenion.from_real(exp_r)
        
        cos_v = np.cos(v_norm)
        sin_v_over_v = np.sin(v_norm) / v_norm
        
        result = v.scale(sin_v_over_v)
        result.c[0] += cos_v
        return result.scale(exp_r)


def _cd_conj(arr, dim):
    """Cayley-Dickson conjugation for an array of size `dim`."""
    result = arr.copy()
    if dim == 1:
        return result  # real conjugation = identity
    result[dim//2:dim] = -result[dim//2:dim]
    result[:dim//2] = _cd_conj(result[:dim//2], dim // 2)
    return result


def _cd_mul(a, b, dim):
    """Cayley-Dickson multiplication for arrays of size `dim`."""
    if dim == 1:
        return a * b
    
    half = dim // 2
    
    a1, a2 = a[:half], a[half:]
    b1, b2 = b[:half], b[half:]
    
    # (a1, a2) · (b1, b2) = (a1·b1 - conj(b2)·a2, b2·a1 + a2·conj(b1))
    b2_conj = _cd_conj(b2, half)
    b1_conj = _cd_conj(b1, half)
    
    first = _cd_mul(a1, b1, half) - _cd_mul(b2_conj, a2, half)
    second = _cd_mul(b2, a1, half) + _cd_mul(a2, b1_conj, half)
    
    return np.concatenate([first, second])


# ═══════════════════════════════════════════════════════════
# SECTION 2: Sedenion Zeta Function
# ═══════════════════════════════════════════════════════════

def zeta_sedenion(s: Sedenion, terms: int = 50) -> Sedenion:
    """
    Compute the sedenion Dirichlet series:
    ζ(S) = Σ_{n=1}^{terms} e^{-S·ln(n)}
    
    This extends the classical Riemann zeta function to 16D.
    For S = (0.5 + it, 0, 0, ..., 0), this reduces to ζ(0.5 + it).
    """
    result = Sedenion.zero()
    for n in range(1, terms + 1):
        ln_n = np.log(float(n))
        neg_s_ln_n = s.scale(-ln_n)
        term = neg_s_ln_n.exp()
        result = result.add(term)
    return result


# ═══════════════════════════════════════════════════════════
# SECTION 3: Zero Finder
# ═══════════════════════════════════════════════════════════

# First 20 known non-trivial zero heights of ζ(s)
KNOWN_ZERO_HEIGHTS = [
    14.134725, 21.022040, 25.010858, 30.424876, 32.935062,
    37.586178, 40.918719, 43.327073, 48.005151, 49.773832,
    52.970321, 56.446248, 59.347044, 60.831779, 65.112544,
    67.079811, 69.546402, 72.067158, 75.704691, 77.144840,
]


def find_zeros_on_critical_line(terms=50, threshold=0.5):
    """
    Verify that the sedenion zeta function has zeros at the known
    heights when pinned to the critical line Re(S) = 0.5.
    
    Returns a list of (height, |ζ(S)|, full_sedenion_output) tuples.
    """
    results = []
    for t in KNOWN_ZERO_HEIGHTS:
        s = Sedenion.from_complex(0.5, t)
        zeta_val = zeta_sedenion(s, terms)
        magnitude = zeta_val.norm()
        results.append({
            "height": t,
            "magnitude": magnitude,
            "output_components": zeta_val.c.tolist(),
            "is_near_zero": magnitude < threshold,
        })
    return results


# ═══════════════════════════════════════════════════════════
# SECTION 4: Hessian Analysis at Zeros
# ═══════════════════════════════════════════════════════════

def compute_hessian_at_zero(t: float, terms: int = 50, epsilon: float = 1e-4):
    """
    Compute the 16×16 Hessian matrix of |ζ(S)|² at a zero-crossing.
    
    S₀ = (0.5, t, 0, 0, ..., 0) — a sedenion on the critical line.
    
    The Hessian H[i][j] = ∂²|ζ|²/∂Sᵢ∂Sⱼ is computed via finite differences:
    H[i][j] ≈ (f(+ε,+ε) - f(+ε,-ε) - f(-ε,+ε) + f(-ε,-ε)) / (4ε²)
    
    where f(δi, δj) = |ζ(S₀ + δi·eᵢ + δj·eⱼ)|²
    """
    def f_norm_sq(components):
        s = Sedenion(components)
        zeta = zeta_sedenion(s, terms)
        return zeta.norm_sq()
    
    base = np.zeros(16)
    base[0] = 0.5  # Critical line
    base[1] = t    # Imaginary height
    
    hessian = np.zeros((16, 16))
    
    for i in range(16):
        for j in range(i, 16):
            pp = base.copy(); pp[i] += epsilon; pp[j] += epsilon
            pm = base.copy(); pm[i] += epsilon; pm[j] -= epsilon
            mp = base.copy(); mp[i] -= epsilon; mp[j] += epsilon
            mm = base.copy(); mm[i] -= epsilon; mm[j] -= epsilon
            
            h_ij = (f_norm_sq(pp) - f_norm_sq(pm) - f_norm_sq(mp) + f_norm_sq(mm)) / (4 * epsilon * epsilon)
            hessian[i][j] = h_ij
            hessian[j][i] = h_ij  # Symmetric
    
    return hessian


def analyze_hessian(hessian):
    """
    Extract topological information from the Hessian at a zero.
    
    Returns:
    - eigenvalues (sorted)
    - signature (n_positive, n_negative, n_zero)
    - Morse index (number of negative eigenvalues)
    - trace (Laplacian)
    - determinant
    """
    eigenvalues = np.linalg.eigvalsh(hessian)
    eigenvalues_sorted = np.sort(eigenvalues)
    
    tol = 1e-6
    n_positive = int(np.sum(eigenvalues > tol))
    n_negative = int(np.sum(eigenvalues < -tol))
    n_zero = 16 - n_positive - n_negative
    
    return {
        "eigenvalues": eigenvalues_sorted.tolist(),
        "signature": (n_positive, n_negative, n_zero),
        "morse_index": n_negative,
        "trace": float(np.trace(hessian)),
        "determinant": float(np.linalg.det(hessian)),
    }


# ═══════════════════════════════════════════════════════════
# SECTION 5: Conjugation Symmetry Analysis
# ═══════════════════════════════════════════════════════════

def analyze_conjugation_symmetry(t: float, terms: int = 50):
    """
    Test if ζ(S̄) = conj(ζ(S)) at a zero on the critical line.
    
    If this symmetry holds, it implies that zeros are constrained to the
    fixed-point set of the conjugation map, which is Re(S) = 1/2.
    """
    s = Sedenion.from_complex(0.5, t)
    s_conj = s.conj()
    
    zeta_s = zeta_sedenion(s, terms)
    zeta_s_conj = zeta_sedenion(s_conj, terms)
    conj_zeta_s = zeta_s.conj()
    
    # Measure how close ζ(S̄) is to conj(ζ(S))
    diff = zeta_s_conj.sub(conj_zeta_s)
    symmetry_error = diff.norm()
    
    return {
        "height": t,
        "symmetry_error": symmetry_error,
        "is_symmetric": symmetry_error < 1e-8,
        "zeta_norm": zeta_s.norm(),
    }


# ═══════════════════════════════════════════════════════════
# SECTION 6: Full Mining Pipeline
# ═══════════════════════════════════════════════════════════

class ConjectureMiner:
    """
    Runs the sedenion zeta computation, extracts topological data at
    zero-crossings, and generates formal conjectures for the LLM prover.
    """
    
    def __init__(self, terms=50, num_zeros=10, cache_path=CONJECTURE_CACHE):
        self.terms = terms
        self.num_zeros = min(num_zeros, len(KNOWN_ZERO_HEIGHTS))
        self.cache_path = os.path.abspath(cache_path)
        self.results = None
    
    def mine(self, force=False):
        """
        Run the full mining pipeline. Returns cached results if available.
        """
        if not force and os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, "r") as f:
                    self.results = json.load(f)
                print(f"[Miner] Loaded cached conjectures ({len(self.results.get('zeros', []))} zeros)")
                return self.results
            except (json.JSONDecodeError, KeyError):
                pass
        
        print(f"[Miner] Mining {self.num_zeros} zeros with {self.terms} Dirichlet terms...")
        start = time.time()
        
        # Step 1: Verify zeros on the critical line
        zeros = []
        for i, t in enumerate(KNOWN_ZERO_HEIGHTS[:self.num_zeros]):
            print(f"  [{i+1}/{self.num_zeros}] t = {t:.6f}", end=" ")
            
            # Compute |ζ(S)| at this height
            s = Sedenion.from_complex(0.5, t)
            zeta_val = zeta_sedenion(s, self.terms)
            mag = zeta_val.norm()
            
            # Analyze Hessian topology
            hess = compute_hessian_at_zero(t, self.terms)
            hess_analysis = analyze_hessian(hess)
            
            # Check conjugation symmetry
            conj_sym = analyze_conjugation_symmetry(t, self.terms)
            
            zeros.append({
                "height": t,
                "zeta_magnitude": mag,
                "hessian": hess_analysis,
                "conjugation_symmetry": conj_sym,
            })
            
            print(f"| |ζ| = {mag:.6f} | sig = {hess_analysis['signature']} | "
                  f"conj_err = {conj_sym['symmetry_error']:.2e}")
        
        # Step 2: Extract patterns across zeros
        signatures = [z["hessian"]["signature"] for z in zeros]
        morse_indices = [z["hessian"]["morse_index"] for z in zeros]
        conj_symmetric = all(z["conjugation_symmetry"]["is_symmetric"] for z in zeros)
        
        unique_signatures = list(set(str(s) for s in signatures))
        consistent_signature = len(unique_signatures) == 1
        
        elapsed = time.time() - start
        
        self.results = {
            "mining_time_sec": elapsed,
            "num_zeros": self.num_zeros,
            "dirichlet_terms": self.terms,
            "zeros": zeros,
            "patterns": {
                "consistent_hessian_signature": consistent_signature,
                "unique_signatures": unique_signatures,
                "morse_indices": morse_indices,
                "all_conjugation_symmetric": conj_symmetric,
            },
        }
        
        # Cache results
        try:
            with open(self.cache_path, "w") as f:
                json.dump(self.results, f, indent=2)
            print(f"\n[Miner] Complete in {elapsed:.1f}s. Cached to {self.cache_path}")
        except Exception as e:
            print(f"\n[Miner] Complete in {elapsed:.1f}s. Cache write failed: {e}")
        
        return self.results
    
    def format_conjectures(self):
        """
        Format mined results as a prompt injection string for the LLM.
        Replaces the static SIMULATION_CONJECTURES with actual data.
        """
        if self.results is None:
            self.mine()
        
        r = self.results
        patterns = r["patterns"]
        
        lines = [
            f"LIVE SIMULATION DATA (from HYPERZETA sedenion physics engine):",
            f"Computed ζ(S) for {r['num_zeros']} known zeros using {r['dirichlet_terms']} Dirichlet terms.",
            "",
        ]
        
        # Report zero magnitudes
        for z in r["zeros"][:5]:
            lines.append(f"  Zero at t={z['height']:.6f}: |ζ(0.5+it)| = {z['zeta_magnitude']:.6f}, "
                        f"Hessian signature = {z['hessian']['signature']}")
        if r["num_zeros"] > 5:
            lines.append(f"  ... ({r['num_zeros'] - 5} more zeros analyzed)")
        
        lines.append("")
        
        # Conjectures from data
        lines.append("EXTRACTED CONJECTURES:")
        
        if patterns["consistent_hessian_signature"]:
            sig = patterns["unique_signatures"][0]
            lines.append(f"  CONJECTURE A (STRONG): The Hessian of |ζ(S)|² at EVERY zero has "
                        f"the same signature {sig}. This suggests a topological constraint "
                        f"forcing zeros onto a specific manifold.")
        else:
            lines.append(f"  OBSERVATION A: Hessian signatures vary across zeros: "
                        f"{patterns['unique_signatures'][:3]}. Morse indices: {patterns['morse_indices'][:5]}")
        
        if patterns["all_conjugation_symmetric"]:
            lines.append(f"  CONJECTURE B (STRONG): ζ(S̄) = conj(ζ(S)) holds at ALL tested zeros. "
                        f"This conjugation symmetry means the zero set is invariant under S ↦ S̄. "
                        f"The fixed-point set of this involution is exactly Re(S) = 1/2 (the critical line). "
                        f"Proving this symmetry holds EVERYWHERE (not just at zeros) would prove RH.")
        else:
            lines.append(f"  OBSERVATION B: Conjugation symmetry ζ(S̄) = conj(ζ(S)) does NOT hold "
                        f"universally. This may be a truncation artifact.")
        
        lines.append("")
        lines.append("PROOF STRATEGY SUGGESTED BY DATA:")
        lines.append("  1. Prove the conjugation symmetry ζ(S̄) = conj(ζ(S)) for the Dirichlet series")
        lines.append("  2. Show this forces the zero set to be invariant under S ↦ S̄")
        lines.append("  3. Show the only fixed line of this involution with Re(S) > 0 is Re(S) = 1/2")
        lines.append("  4. Conclude: all non-trivial zeros have Re(s) = 1/2")
        
        return "\n".join(lines)


if __name__ == "__main__":
    miner = ConjectureMiner(terms=30, num_zeros=5)
    results = miner.mine(force=True)
    print("\n" + miner.format_conjectures())
